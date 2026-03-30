import asyncio
import base64
import os
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from database import SessionLocal, get_db
from middleware.auth_middleware import auth_middleware, build_auth_context_from_token
from models.class_ import Class
from models.notification import Notification
from models.push_device_token import PushDeviceToken
from models.user import User
from notification_service import (
    dispatch_due_class_starting_soon_notifications,
    serialize_notification_data,
)
from pydantic_schemas.notification import (
    NotificationPageResponse,
    NotificationResponse,
    PushTokenRegisterRequest,
    PushTokenResponse,
    PushTokenUnregisterRequest,
    NotificationUnreadCountResponse,
)

router = APIRouter()
_NOTIFICATION_WS_POLL_SECONDS = max(
    2.0,
    float((os.getenv("NOTIFICATION_WS_POLL_SECONDS", "") or "5").strip() or "5"),
)
_NOTIFICATION_WS_HEARTBEAT_SECONDS = max(
    _NOTIFICATION_WS_POLL_SECONDS,
    float((os.getenv("NOTIFICATION_WS_HEARTBEAT_SECONDS", "") or "25").strip() or "25"),
)
_LEGACY_UNDERFILLED_REASON_PATTERN = re.compile(
    r"Khong du hoc vien toi thieu truoc ([0-9]+(?:\.[0-9]+)?) gio"
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _get_user_or_404(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    return user


def _build_class_code(cls: Class) -> str:
    date_part = cls.start_time.strftime("%y%m%d")
    raw_id = "".join(char for char in str(cls.id).upper() if char.isalnum())
    suffix = raw_id[:4].ljust(4, "0")
    return f"CLS-{date_part}-{suffix}"


def _format_vnd_amount(amount: Any) -> str:
    try:
        decimal_value = Decimal(str(amount or 0))
        whole_amount = int(decimal_value.quantize(Decimal("1")))
    except (ArithmeticError, TypeError, ValueError):
        return f"{amount or 0} VND"
    return f"{whole_amount:,} VND".replace(",", ".")


def _normalize_notification_text(text: str | None) -> str:
    normalized = (text or "").strip()
    if not normalized:
        return ""

    normalized = _LEGACY_UNDERFILLED_REASON_PATTERN.sub(
        lambda match: f"Không đủ học viên tối thiểu trước {match.group(1)} giờ",
        normalized,
    )

    replacements = {
        "Tutor chua cap nhat day du thong tin payout payOS: bank_bin": (
            "Tutor chưa cập nhật đầy đủ thông tin payout payOS: bank_bin"
        ),
        "Tutor chu dong huy lop": "Tutor chủ động hủy lớp",
        "Lop hoc bi huy": "Lớp học bị hủy",
    }

    for legacy, clean in replacements.items():
        normalized = normalized.replace(legacy, clean)

    return normalized


def _normalize_notification_payload(
    notification: Notification,
    data: dict[str, Any],
) -> tuple[str, str, dict[str, Any]]:
    normalized_data = dict(data)
    for key in ("cancellation_reason", "refund_reason", "message"):
        value = normalized_data.get(key)
        if isinstance(value, str):
            normalized_data[key] = _normalize_notification_text(value)

    if (
        notification.type == "refund_issued"
        and normalized_data.get("refund_scope") == "class_creation_fee"
        and normalized_data.get("refund_status") == "legacy_recorded"
    ):
        class_title = str(normalized_data.get("class_title") or "").strip()
        class_segment = f" cho lớp '{class_title}'" if class_title else ""
        title = "Đã ghi nhận hoàn phí tạo lớp"
        body = (
            "Hệ thống đã ghi nhận khoản hoàn phí tạo lớp "
            f"{_format_vnd_amount(normalized_data.get('refund_amount'))}"
            f"{class_segment}. "
            "Khoản này chưa đồng nghĩa tiền đã về tài khoản ngân hàng của tutor."
        )
        return title, body, normalized_data

    return (
        _normalize_notification_text(notification.title),
        _normalize_notification_text(notification.body),
        normalized_data,
    )


def _notification_class_codes(db: Session, notifications: list[Notification]) -> dict[str, str]:
    class_ids = []
    for notification in notifications:
        data = serialize_notification_data(notification.data)
        class_id = data.get("class_id")
        if isinstance(class_id, str) and class_id and class_id not in class_ids:
            class_ids.append(class_id)

    if not class_ids:
        return {}

    classes = db.query(Class).filter(Class.id.in_(class_ids)).all()
    return {cls.id: _build_class_code(cls) for cls in classes}


def _serialize_notification(
    notification: Notification,
    *,
    class_codes: dict[str, str] | None = None,
) -> NotificationResponse:
    data = serialize_notification_data(notification.data)
    class_id = data.get("class_id")
    if (
        class_codes
        and isinstance(class_id, str)
        and class_id
        and not data.get("class_code")
        and class_id in class_codes
    ):
        data = {**data, "class_code": class_codes[class_id]}

    title, body, data = _normalize_notification_payload(notification, data)

    return NotificationResponse(
        id=notification.id,
        type=notification.type,
        title=title,
        body=body,
        data=data,
        is_read=notification.is_read,
        created_at=notification.created_at,
        read_at=notification.read_at,
    )


def _build_notifications_query(
    db: Session,
    *,
    user_id: str,
    notification_type: str | None = None,
    unread_only: bool = False,
):
    query = db.query(Notification).filter(Notification.user_id == user_id)
    if notification_type:
        query = query.filter(Notification.type == notification_type)
    if unread_only:
        query = query.filter(Notification.is_read.is_(False))
    return query


def _encode_cursor(created_at: datetime, notification_id: str) -> str:
    raw_value = f"{created_at.astimezone(timezone.utc).isoformat()}::{notification_id}"
    return base64.urlsafe_b64encode(raw_value.encode("utf-8")).decode("utf-8")


def _decode_cursor(cursor: str) -> tuple[datetime, str]:
    try:
        raw_value = base64.urlsafe_b64decode(cursor.encode("utf-8")).decode("utf-8")
        created_at_raw, notification_id = raw_value.split("::", 1)
        created_at = datetime.fromisoformat(created_at_raw)
    except (ValueError, UnicodeDecodeError):
        raise HTTPException(status_code=400, detail="Cursor không hợp lệ")

    if created_at.tzinfo is None:
        created_at = created_at.replace(tzinfo=timezone.utc)
    return created_at.astimezone(timezone.utc), notification_id


def _notification_state_signature(db: Session, user_id: str) -> tuple[str | None, str | None, int]:
    latest_notification = (
        db.query(Notification)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .first()
    )
    unread_count = (
        db.query(func.count(Notification.id))
        .filter(Notification.user_id == user_id, Notification.is_read.is_(False))
        .scalar()
    ) or 0
    return (
        latest_notification.id if latest_notification else None,
        latest_notification.created_at.astimezone(timezone.utc).isoformat()
        if latest_notification and latest_notification.created_at
        else None,
        int(unread_count),
    )


def _dispatch_due_reminders_for_user(db: Session, user_id: str) -> None:
    notified = dispatch_due_class_starting_soon_notifications(db, target_user_id=user_id)
    if notified:
        db.commit()
    else:
        db.rollback()


@router.get("/unread-count", response_model=NotificationUnreadCountResponse)
def get_unread_notification_count(
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    _dispatch_due_reminders_for_user(db, user.id)
    unread_count = (
        db.query(func.count(Notification.id))
        .filter(Notification.user_id == user.id, Notification.is_read.is_(False))
        .scalar()
    ) or 0
    return NotificationUnreadCountResponse(unread_count=int(unread_count))


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    notification_type: str | None = Query(default=None, alias="type"),
    unread_only: bool = Query(default=False),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    _dispatch_due_reminders_for_user(db, user.id)
    notifications = (
        _build_notifications_query(
            db,
            user_id=user.id,
            notification_type=notification_type,
            unread_only=unread_only,
        )
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    class_codes = _notification_class_codes(db, notifications)
    return [
        _serialize_notification(notification, class_codes=class_codes)
        for notification in notifications
    ]


@router.get("/cursor", response_model=NotificationPageResponse)
def list_notifications_with_cursor(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    notification_type: str | None = Query(default=None, alias="type"),
    unread_only: bool = Query(default=False),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    _dispatch_due_reminders_for_user(db, user.id)

    query = _build_notifications_query(
        db,
        user_id=user.id,
        notification_type=notification_type,
        unread_only=unread_only,
    )
    if cursor:
        cursor_created_at, cursor_id = _decode_cursor(cursor)
        query = query.filter(
            or_(
                Notification.created_at < cursor_created_at,
                and_(
                    Notification.created_at == cursor_created_at,
                    Notification.id < cursor_id,
                ),
            )
        )

    rows = (
        query
        .order_by(Notification.created_at.desc(), Notification.id.desc())
        .limit(limit + 1)
        .all()
    )
    has_more = len(rows) > limit
    notifications = rows[:limit]
    class_codes = _notification_class_codes(db, notifications)
    next_cursor = None
    if has_more and notifications:
        last_notification = notifications[-1]
        next_cursor = _encode_cursor(last_notification.created_at, last_notification.id)

    return NotificationPageResponse(
        items=[
            _serialize_notification(notification, class_codes=class_codes)
            for notification in notifications
        ],
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.websocket("/ws")
async def notifications_websocket(websocket: WebSocket):
    token = websocket.query_params.get("token") or websocket.headers.get("x-auth-token")
    if not token:
        await websocket.close(code=4401, reason="Missing auth token")
        return

    try:
        auth_context = build_auth_context_from_token(token)
    except HTTPException:
        await websocket.close(code=4401, reason="Invalid auth token")
        return

    await websocket.accept()
    user_id = auth_context["uid"]
    last_signature: tuple[str | None, str | None, int] | None = None
    last_heartbeat_at: datetime | None = None

    try:
        while True:
            db = SessionLocal()
            try:
                _get_user_or_404(db, user_id)
                notified = dispatch_due_class_starting_soon_notifications(
                    db,
                    target_user_id=user_id,
                )
                if notified:
                    db.commit()
                else:
                    db.rollback()
                signature = _notification_state_signature(db, user_id)
            finally:
                db.close()

            if signature != last_signature:
                await websocket.send_json(
                    {
                        "type": "notifications_changed",
                        "unread_count": signature[2],
                        "latest_notification_id": signature[0],
                    }
                )
                last_signature = signature
                last_heartbeat_at = _now()
            elif (
                last_heartbeat_at is None
                or (_now() - last_heartbeat_at).total_seconds() >= _NOTIFICATION_WS_HEARTBEAT_SECONDS
            ):
                await websocket.send_json({"type": "heartbeat"})
                last_heartbeat_at = _now()

            await asyncio.sleep(_NOTIFICATION_WS_POLL_SECONDS)
    except WebSocketDisconnect:
        return


@router.post("/push-tokens", response_model=PushTokenResponse)
def register_push_token(
    payload: PushTokenRegisterRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    token = payload.token.strip()
    platform = payload.platform.strip().lower() or "unknown"
    device_label = payload.device_label.strip() if payload.device_label else None

    device_token = db.query(PushDeviceToken).filter(PushDeviceToken.token == token).first()
    if not device_token:
        device_token = PushDeviceToken(
            id=str(uuid.uuid4()),
            token=token,
            user_id=user.id,
        )
        db.add(device_token)

    device_token.user_id = user.id
    device_token.platform = platform
    device_token.device_label = device_label
    device_token.is_active = True
    device_token.last_seen_at = _now()
    db.commit()
    db.refresh(device_token)

    return PushTokenResponse(
        id=device_token.id,
        platform=device_token.platform,
        device_label=device_token.device_label,
        is_active=device_token.is_active,
        last_seen_at=device_token.last_seen_at,
        message="Da dang ky FCM token thanh cong",
    )


@router.post("/push-tokens/unregister", response_model=PushTokenResponse)
def unregister_push_token(
    payload: PushTokenUnregisterRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    token = payload.token.strip()
    device_token = (
        db.query(PushDeviceToken)
        .filter(
            PushDeviceToken.token == token,
            PushDeviceToken.user_id == user.id,
        )
        .first()
    )

    if not device_token:
        return PushTokenResponse(
            id="",
            platform="unknown",
            device_label=None,
            is_active=False,
            last_seen_at=None,
            message="FCM token chua duoc dang ky cho tai khoan nay",
        )

    device_token.is_active = False
    device_token.last_seen_at = _now()
    db.commit()
    db.refresh(device_token)

    return PushTokenResponse(
        id=device_token.id,
        platform=device_token.platform,
        device_label=device_token.device_label,
        is_active=device_token.is_active,
        last_seen_at=device_token.last_seen_at,
        message="Da huy dang ky FCM token",
    )


@router.post("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_as_read(
    notification_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    notification = (
        db.query(Notification)
        .filter(Notification.id == notification_id, Notification.user_id == user.id)
        .first()
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo")

    notification.is_read = True
    notification.read_at = notification.read_at or _now()
    db.commit()
    db.refresh(notification)
    class_codes = _notification_class_codes(db, [notification])
    return _serialize_notification(notification, class_codes=class_codes)
