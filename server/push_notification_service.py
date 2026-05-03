from __future__ import annotations

from datetime import datetime, timezone
import json
import logging
import os
from typing import Any

from sqlalchemy import event
from sqlalchemy.orm import Session

from database import SessionLocal
from models.push_device_token import PushDeviceToken

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except ImportError:  # pragma: no cover - optional dependency in local/dev environments
    firebase_admin = None
    credentials = None
    messaging = None


logger = logging.getLogger(__name__)
_PENDING_PUSHES_KEY = "pending_push_notifications"
_INVALID_TOKEN_MARKERS = (
    "registration-token-not-registered",
    "unregistered",
    "requested entity was not found",
    "invalid registration token",
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _configured_service_account_path() -> str | None:
    raw_value = (os.getenv("FCM_SERVICE_ACCOUNT_PATH", "") or "").strip()
    return raw_value or None


def _configured_service_account_json() -> dict[str, Any] | None:
    raw_value = (os.getenv("FCM_SERVICE_ACCOUNT_JSON", "") or "").strip()
    if not raw_value:
        return None
    try:
        parsed = json.loads(raw_value)
    except json.JSONDecodeError:
        logger.warning("FCM_SERVICE_ACCOUNT_JSON khong phai JSON hop le; bo qua FCM")
        return None
    return parsed if isinstance(parsed, dict) else None


def _firebase_credentials():
    if credentials is None:
        return None

    service_account_path = _configured_service_account_path()
    if service_account_path:
        try:
            return credentials.Certificate(service_account_path)
        except Exception:
            logger.exception("Khong the doc FCM service account tu duong dan da cau hinh")
            return None

    service_account_json = _configured_service_account_json()
    if service_account_json:
        try:
            return credentials.Certificate(service_account_json)
        except Exception:
            logger.exception("Khong the tao FCM credential tu FCM_SERVICE_ACCOUNT_JSON")
            return None

    return None


def fcm_is_enabled() -> bool:
    return firebase_admin is not None and _firebase_credentials() is not None


def _firebase_app():
    if not fcm_is_enabled():
        return None

    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    firebase_credentials = _firebase_credentials()
    if firebase_credentials is None:
        return None

    try:
        return firebase_admin.initialize_app(firebase_credentials)
    except ValueError:
        return firebase_admin.get_app()


def queue_push_notification(
    db: Session,
    *,
    user_id: str,
    notification_id: str,
    notification_type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> None:
    pending_pushes = db.info.setdefault(_PENDING_PUSHES_KEY, [])
    payload = {
        "user_id": user_id,
        "notification_id": notification_id,
        "notification_type": notification_type,
        "title": title,
        "body": body,
        "data": data or {},
    }
    pending_pushes.append(payload)


def _normalize_push_data(payload: dict[str, Any]) -> dict[str, str]:
    raw_data = payload.get("data") or {}
    normalized = {
        "notification_id": str(payload["notification_id"]),
        "notification_type": str(payload["notification_type"]),
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
    }

    for key in (
        "class_id",
        "class_code",
        "class_title",
        "recipient_role",
        "tutor_confirmation_status",
        "start_time",
    ):
        value = raw_data.get(key)
        if value is not None and str(value).strip():
            normalized[key] = str(value)

    return normalized


def _should_deactivate_token(exc: Exception) -> bool:
    message = str(exc).lower()
    return any(marker in message for marker in _INVALID_TOKEN_MARKERS)


def _send_queued_pushes(payloads: list[dict[str, Any]]) -> None:
    firebase_app = _firebase_app()
    if firebase_app is None or messaging is None:
        return

    session = SessionLocal()
    try:
        for payload in payloads:
            tokens = (
                session.query(PushDeviceToken)
                .filter(
                    PushDeviceToken.user_id == payload["user_id"],
                    PushDeviceToken.is_active.is_(True),
                )
                .all()
            )
            if not tokens:
                continue

            message_data = _normalize_push_data(payload)
            invalid_token_ids: list[str] = []
            last_seen_at = _now()

            for device_token in tokens:
                try:
                    messaging.send(
                        messaging.Message(
                            token=device_token.token,
                            notification=messaging.Notification(
                                title=payload["title"],
                                body=payload["body"],
                            ),
                            data=message_data,
                        ),
                        app=firebase_app,
                    )
                    device_token.last_seen_at = last_seen_at
                except Exception as exc:  # pragma: no cover - depends on external FCM runtime
                    logger.warning(
                        "Khong gui duoc FCM cho user %s: %s",
                        payload["user_id"],
                        exc,
                    )
                    if _should_deactivate_token(exc):
                        invalid_token_ids.append(device_token.id)

            if invalid_token_ids:
                (
                    session.query(PushDeviceToken)
                    .filter(PushDeviceToken.id.in_(invalid_token_ids))
                    .update({"is_active": False}, synchronize_session=False)
                )

        session.commit()
    except Exception:  # pragma: no cover - defensive logging around external transport
        session.rollback()
        logger.exception("Khong the hoan tat luong gui FCM")
    finally:
        session.close()


@event.listens_for(Session, "after_commit")
def _flush_pending_pushes(session: Session) -> None:  # pragma: no cover - covered indirectly
    pending_pushes = session.info.pop(_PENDING_PUSHES_KEY, [])
    if not pending_pushes:
        return
    _send_queued_pushes(pending_pushes)


@event.listens_for(Session, "after_rollback")
def _clear_pending_pushes(session: Session) -> None:  # pragma: no cover - covered indirectly
    session.info.pop(_PENDING_PUSHES_KEY, None)
