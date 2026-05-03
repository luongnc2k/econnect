from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
import json
import uuid
from typing import Any

from sqlalchemy.orm import Session

from models.booking import Booking
from models.class_ import Class
from models.notification import Notification
from push_notification_service import queue_push_notification

NOTIFICATION_TYPE_MINIMUM_REACHED = "minimum_participants_reached"
NOTIFICATION_TYPE_TUTOR_CONFIRMED = "tutor_confirmed_teaching"
NOTIFICATION_TYPE_CLASS_STARTING_SOON = "class_starting_soon"
NOTIFICATION_TYPE_CLASS_CANCELLED = "class_cancelled"
NOTIFICATION_TYPE_REFUND_ISSUED = "refund_issued"
NOTIFICATION_TYPE_PAYOUT_UPDATED = "payout_updated"
NOTIFICATION_TYPE_DISPUTE_RESOLVED = "dispute_resolved"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _build_class_code(cls: Class) -> str:
    date_part = cls.start_time.strftime("%y%m%d")
    raw_id = "".join(char for char in str(cls.id).upper() if char.isalnum())
    suffix = raw_id[:4].ljust(4, "0")
    return f"CLS-{date_part}-{suffix}"


def _format_vnd_amount(amount: Decimal | int | float | str) -> str:
    decimal_value = Decimal(str(amount))
    whole_amount = int(decimal_value.quantize(Decimal("1")))
    return f"{whole_amount:,} VND".replace(",", ".")


def serialize_notification_data(raw_data: str | None) -> dict[str, Any]:
    if not raw_data:
        return {}
    try:
        parsed = json.loads(raw_data)
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


def create_notification(
    db: Session,
    *,
    user_id: str,
    notification_type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> Notification:
    notification = Notification(
        id=str(uuid.uuid4()),
        user_id=user_id,
        type=notification_type,
        title=title,
        body=body,
        data=json.dumps(data or {}, ensure_ascii=False),
        is_read=False,
    )
    db.add(notification)
    queue_push_notification(
        db,
        user_id=user_id,
        notification_id=notification.id,
        notification_type=notification_type,
        title=title,
        body=body,
        data=data,
    )
    return notification


def _class_notification_data(cls: Class) -> dict[str, Any]:
    return {
        "class_id": cls.id,
        "class_code": _build_class_code(cls),
        "class_title": cls.title,
        "location_name": cls.location_name,
        "location_address": cls.location_address,
        "start_time": cls.start_time.isoformat(),
        "end_time": cls.end_time.isoformat(),
    }


def notify_tutor_minimum_reached(db: Session, *, cls: Class) -> Notification:
    data = _class_notification_data(cls)
    data.update(
        {
            "current_participants": cls.current_participants,
            "min_participants": cls.min_participants,
            "max_participants": cls.max_participants,
            "tutor_confirmation_status": cls.tutor_confirmation_status,
        }
    )
    return create_notification(
        db,
        user_id=cls.teacher_id,
        notification_type=NOTIFICATION_TYPE_MINIMUM_REACHED,
        title="Lớp đã đủ số học viên tối thiểu",
        body=(
            f"Lớp '{cls.title}' đã đạt ngưỡng tối thiểu {cls.min_participants} học viên. "
            "Hãy xác nhận dạy để hệ thống thông báo buổi học sẽ diễn ra."
        ),
        data=data,
    )


def notify_class_starting_soon(
    db: Session,
    *,
    cls: Class,
    student_user_ids: list[str],
) -> None:
    tutor_data = _class_notification_data(cls)
    tutor_data["recipient_role"] = "teacher"
    create_notification(
        db,
        user_id=cls.teacher_id,
        notification_type=NOTIFICATION_TYPE_CLASS_STARTING_SOON,
        title="Lớp học sắp diễn ra trong 1 giờ",
        body=(
            f"Lớp '{cls.title}' sắp bắt đầu trong khoảng 1 giờ nữa. "
            "Hãy chuẩn bị cho buổi học."
        ),
        data=tutor_data,
    )

    for student_user_id in student_user_ids:
        student_data = _class_notification_data(cls)
        student_data["recipient_role"] = "student"
        create_notification(
            db,
            user_id=student_user_id,
            notification_type=NOTIFICATION_TYPE_CLASS_STARTING_SOON,
            title="Lịch học sắp diễn ra trong 1 giờ",
            body=(
                f"Lớp '{cls.title}' sắp bắt đầu trong khoảng 1 giờ nữa. "
                "Hãy sẵn sàng tham gia buổi học."
            ),
            data=student_data,
        )


def _active_student_user_ids(db: Session, class_id: str) -> list[str]:
    rows = (
        db.query(Booking.student_id)
        .filter(
            Booking.class_id == class_id,
            Booking.status.in_(["confirmed", "completed"]),
            Booking.payment_status == "paid",
        )
        .all()
    )
    return [student_id for student_id, in rows]


def dispatch_due_class_starting_soon_notifications(
    db: Session,
    *,
    now: datetime | None = None,
    target_user_id: str | None = None,
) -> list[dict[str, Any]]:
    current_time = now or _now()
    deadline = current_time + timedelta(hours=1)
    upcoming_classes = (
        db.query(Class)
        .filter(
            Class.status == "scheduled",
            Class.start_time <= deadline,
            Class.start_time > current_time,
            Class.starting_soon_notified_at.is_(None),
        )
        .order_by(Class.start_time.asc())
        .with_for_update(skip_locked=True)
        .all()
    )

    notified: list[dict[str, Any]] = []
    for cls in upcoming_classes:
        student_user_ids = _active_student_user_ids(db, cls.id)
        if (
            target_user_id is not None
            and cls.teacher_id != target_user_id
            and target_user_id not in student_user_ids
        ):
            continue

        active_count = len(student_user_ids)
        if active_count < cls.min_participants:
            continue

        notify_class_starting_soon(db, cls=cls, student_user_ids=student_user_ids)
        cls.current_participants = active_count
        cls.minimum_participants_reached = True
        cls.minimum_participants_reached_at = cls.minimum_participants_reached_at or current_time
        if cls.tutor_confirmation_status == "waiting_minimum":
            cls.tutor_confirmation_status = "pending"
        cls.starting_soon_notified_at = current_time
        notified.append(
            {
                "class_id": cls.id,
                "student_count": len(student_user_ids),
                "recipient_count": len(student_user_ids) + 1,
            }
        )

    return notified


def notify_class_cancelled(
    db: Session,
    *,
    cls: Class,
    student_user_ids: list[str],
    reason: str,
    cancelled_by: str,
    notify_teacher: bool = False,
) -> None:
    base_data = _class_notification_data(cls)
    base_data.update(
        {
            "cancellation_reason": reason,
            "cancelled_by": cancelled_by,
        }
    )

    if notify_teacher:
        teacher_data = {**base_data, "recipient_role": "teacher"}
        create_notification(
            db,
            user_id=cls.teacher_id,
            notification_type=NOTIFICATION_TYPE_CLASS_CANCELLED,
            title="Lớp học đã bị hủy",
            body=(
                f"Lớp '{cls.title}' đã bị hủy. "
                f"Lý do: {reason}."
            ),
            data=teacher_data,
        )

    for student_user_id in student_user_ids:
        student_data = {**base_data, "recipient_role": "student"}
        create_notification(
            db,
            user_id=student_user_id,
            notification_type=NOTIFICATION_TYPE_CLASS_CANCELLED,
            title="Lớp học đã bị hủy",
            body=(
                f"Lớp '{cls.title}' đã bị hủy. "
                f"Lý do: {reason}."
            ),
            data=student_data,
        )


def notify_refund_issued(
    db: Session,
    *,
    cls: Class,
    student_user_id: str,
    amount: Decimal,
    reason: str,
    booking_id: str | None = None,
    refund_status: str = "released",
    transaction_ref: str | None = None,
    provider_order_id: str | None = None,
    message: str | None = None,
) -> Notification:
    data = _class_notification_data(cls)
    data.update(
        {
            "recipient_role": "student",
            "booking_id": booking_id,
            "refund_amount": str(amount),
            "refund_reason": reason,
            "refund_status": refund_status,
            "transaction_ref": transaction_ref,
            "provider_order_id": provider_order_id,
            "message": message,
        }
    )
    if refund_status == "released":
        title = "Học phí đã được hoàn"
        body = (
            f"Hệ thống đã chuyển khoản {_format_vnd_amount(amount)} cho lớp '{cls.title}'. "
            f"Lý do: {reason}."
        )
    elif refund_status == "failed":
        title = "Hoàn tiền học phí chưa thực hiện được"
        body = (
            f"Hệ thống chưa thể chuyển khoản hoàn tiền {_format_vnd_amount(amount)} "
            f"cho lớp '{cls.title}'. Lý do: {message or reason}."
        )
    else:
        title = "Hoàn tiền học phí đang được xử lý"
        body = (
            f"Hệ thống đã tạo yêu cầu hoàn tiền {_format_vnd_amount(amount)} "
            f"cho lớp '{cls.title}'. Vui lòng chờ ngân hàng xử lý."
        )

    return create_notification(
        db,
        user_id=student_user_id,
        notification_type=NOTIFICATION_TYPE_REFUND_ISSUED,
        title=title,
        body=body,
        data=data,
    )


def notify_tutor_creation_fee_refund_updated(
    db: Session,
    *,
    cls: Class,
    amount: Decimal,
    reason: str,
    refund_status: str,
    transaction_ref: str | None = None,
    provider_order_id: str | None = None,
    message: str | None = None,
) -> Notification:
    data = _class_notification_data(cls)
    data.update(
        {
            "recipient_role": "teacher",
            "refund_scope": "class_creation_fee",
            "refund_amount": str(amount),
            "refund_reason": reason,
            "refund_status": refund_status,
            "transaction_ref": transaction_ref,
            "provider_order_id": provider_order_id,
            "message": message,
        }
    )

    title_map = {
        "refund_processing": "Hoàn phí tạo lớp đang được xử lý",
        "refunded": "Hoàn phí tạo lớp đã hoàn tất",
        "refund_failed": "Hoàn phí tạo lớp thất bại",
    }
    title = title_map.get(refund_status, "Cập nhật hoàn phí tạo lớp")

    if refund_status == "refunded":
        body = (
            f"Hệ thống đã hoàn tất lệnh chuyển khoản hoàn phí tạo lớp "
            f"{_format_vnd_amount(amount)} cho lớp '{cls.title}'."
        )
    elif refund_status == "refund_failed":
        detail = message or "payOS chưa thể hoàn tất lệnh chi hoàn phí này."
        body = (
            f"Hệ thống chưa thể hoàn tất lệnh chuyển khoản hoàn phí tạo lớp "
            f"{_format_vnd_amount(amount)} cho lớp '{cls.title}'. "
            f"Lý do: {detail}"
        )
    else:
        detail = message or "payOS đang xử lý lệnh chuyển khoản hoàn phí này."
        body = (
            f"Hệ thống đã tạo lệnh chuyển khoản hoàn phí tạo lớp "
            f"{_format_vnd_amount(amount)} cho lớp '{cls.title}'. "
            f"{detail}"
        )

    return create_notification(
        db,
        user_id=cls.teacher_id,
        notification_type=NOTIFICATION_TYPE_REFUND_ISSUED,
        title=title,
        body=body,
        data=data,
    )


def notify_tutor_payout_updated(
    db: Session,
    *,
    cls: Class,
    amount: Decimal,
    payout_status: str,
    transaction_ref: str | None = None,
    provider_order_id: str | None = None,
    message: str | None = None,
) -> Notification:
    data = _class_notification_data(cls)
    data.update(
        {
            "recipient_role": "teacher",
            "payout_amount": str(amount),
            "payout_status": payout_status,
            "transaction_ref": transaction_ref,
            "provider_order_id": provider_order_id,
            "message": message,
        }
    )

    title_map = {
        "paid": "Payout đã hoàn tất",
        "processing": "Payout đang xử lý",
        "failed": "Payout thất bại",
    }
    body_map = {
        "paid": (
            f"Hệ thống đã chuyển {_format_vnd_amount(amount)} payout cho lớp '{cls.title}'."
        ),
        "processing": (
            f"Hệ thống đã tạo lệnh payout {_format_vnd_amount(amount)} cho lớp '{cls.title}' "
            "và đang chờ đối tác xử lý."
        ),
        "failed": (
            f"Payout {_format_vnd_amount(amount)} cho lớp '{cls.title}' gặp lỗi. "
            f"{message or 'Vui lòng kiểm tra và thử lại sau.'}"
        ),
    }

    return create_notification(
        db,
        user_id=cls.teacher_id,
        notification_type=NOTIFICATION_TYPE_PAYOUT_UPDATED,
        title=title_map.get(payout_status, "Trạng thái payout đã thay đổi"),
        body=body_map.get(
            payout_status,
            f"Trạng thái payout của lớp '{cls.title}' đã cập nhật thành '{payout_status}'.",
        ),
        data=data,
    )


def notify_dispute_resolved(
    db: Session,
    *,
    cls: Class,
    recipient_user_id: str,
    recipient_role: str,
    is_valid: bool,
    note: str | None = None,
) -> Notification:
    resolution = "valid" if is_valid else "rejected"
    data = _class_notification_data(cls)
    data.update(
        {
            "recipient_role": recipient_role,
            "dispute_resolution": resolution,
            "resolution_note": note,
        }
    )

    title = "Khiếu nại đã được xử lý"
    if recipient_role == "student":
        body = (
            f"Khiếu nại của lớp '{cls.title}' đã được chấp nhận. "
            "Hệ thống sẽ xử lý hoàn tiền theo kết quả xác minh."
            if is_valid
            else f"Khiếu nại của lớp '{cls.title}' đã bị từ chối. "
            "Escrow của booking hợp lệ sẽ được giữ nguyên."
        )
    else:
        body = (
            f"Khiếu nại của lớp '{cls.title}' đã được chấp nhận. "
            "Payout sẽ được điều chỉnh theo kết quả xử lý."
            if is_valid
            else f"Khiếu nại của lớp '{cls.title}' đã bị từ chối. "
            "Lớp có thể tiếp tục payout khi đủ điều kiện."
        )

    if note:
        body = f"{body} Ghi chú: {note}."

    return create_notification(
        db,
        user_id=recipient_user_id,
        notification_type=NOTIFICATION_TYPE_DISPUTE_RESOLVED,
        title=title,
        body=body,
        data=data,
    )


def notify_students_tutor_confirmed(
    db: Session,
    *,
    cls: Class,
    student_user_ids: list[str],
) -> None:
    for student_user_id in student_user_ids:
        data = _class_notification_data(cls)
        data["tutor_confirmation_status"] = cls.tutor_confirmation_status
        create_notification(
            db,
            user_id=student_user_id,
            notification_type=NOTIFICATION_TYPE_TUTOR_CONFIRMED,
            title="Tutor đã xác nhận dạy",
            body=(
                f"Tutor đã xác nhận dạy lớp '{cls.title}'. "
                "Buổi học sẽ được diễn ra như kế hoạch."
            ),
            data=data,
        )


def notify_student_tutor_already_confirmed(
    db: Session,
    *,
    cls: Class,
    student_user_id: str,
) -> Notification:
    data = _class_notification_data(cls)
    data["tutor_confirmation_status"] = cls.tutor_confirmation_status
    return create_notification(
        db,
        user_id=student_user_id,
        notification_type=NOTIFICATION_TYPE_TUTOR_CONFIRMED,
        title="Tutor đã xác nhận dạy",
        body=(
            f"Bạn đã đăng ký thành công lớp '{cls.title}'. "
            "Tutor đã xác nhận dạy và buổi học sẽ được diễn ra."
        ),
        data=data,
    )
