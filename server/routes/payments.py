from datetime import datetime, timedelta, timezone
from decimal import Decimal
import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import and_, func
from sqlalchemy.orm import Session

from database import get_db
from learning_location_service import get_active_learning_location_or_400
from middleware.auth_middleware import auth_middleware, optional_auth_middleware
from models.booking import Booking
from models.class_ import Class
from models.payment import Payment
from models.teacher_profile import TeacherProfile
from models.user import User
from notification_service import (
    dispatch_due_class_starting_soon_notifications,
    notify_class_cancelled,
    notify_dispute_resolved,
    notify_refund_issued,
    notify_student_tutor_already_confirmed,
    notify_students_tutor_confirmed,
    notify_tutor_payout_updated,
    notify_tutor_minimum_reached,
)
from payment_gateways import (
    PAYOS_PROVIDER,
    PaymentGatewayError,
    ProviderPayoutResult,
    confirm_provider_webhook,
    create_provider_payment_url,
    create_provider_payout,
    default_provider_webhook_url,
    fetch_provider_payout_balance,
    fetch_provider_payout_status,
    fetch_provider_payment_status,
    is_payment_mock_mode_enabled,
    verify_provider_callback,
)
from pydantic_schemas.notification import TutorTeachingConfirmationResponse
from pydantic_schemas.payment import (
    CancelClassRequest,
    ComplaintRequest,
    ConfirmPayOSWebhookRequest,
    ConfirmPayOSWebhookResponse,
    CreateClassPaymentRequest,
    JoinClassPaymentRequest,
    PayOSPayoutBalanceResponse,
    PaymentCallbackRequest,
    PaymentResponse,
    PaymentSummaryResponse,
    PaymentTransactionStatusResponse,
    ResolveComplaintRequest,
    calculate_creation_fee,
    calculate_student_tuition,
)
from topic_service import ensure_topic_record

router = APIRouter()
JOB_SECRET = (os.getenv("JOB_SECRET", "") or "").strip()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _build_class_code(cls: Class) -> str:
    date_part = cls.start_time.strftime("%y%m%d")
    raw_id = "".join(char for char in str(cls.id).upper() if char.isalnum())
    suffix = raw_id[:4].ljust(4, "0")
    return f"CLS-{date_part}-{suffix}"


def _generate_transaction_ref(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:16].upper()}"


def _get_user_or_404(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    return user


def _get_class_or_404(db: Session, class_id: str, for_update: bool = False) -> Class:
    query = db.query(Class).filter(Class.id == class_id)
    if for_update:
        query = query.with_for_update()
    cls = query.first()
    if not cls:
        raise HTTPException(status_code=404, detail="Khong tim thay lop hoc")
    return cls


def _get_payment_by_reference_or_order_id(db: Session, reference: str) -> Optional[Payment]:
    payment = db.query(Payment).filter(Payment.transaction_ref == reference).first()
    if payment:
        return payment
    return db.query(Payment).filter(Payment.provider_order_id == reference).first()


def _get_teacher_profile_or_404(db: Session, teacher_id: str) -> TeacherProfile:
    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher_id).first()
    if not teacher_profile:
        raise HTTPException(status_code=404, detail="Tutor chua co ho so giao vien")
    return teacher_profile


def _require_mock_payment_routes_enabled() -> None:
    if not is_payment_mock_mode_enabled():
        raise HTTPException(status_code=404, detail="Mock payment routes da bi tat trong moi truong nay")


def _serialize_payment(
    payment: Payment,
    cls: Optional[Class] = None,
    booking: Optional[Booking] = None,
    message: Optional[str] = None,
) -> PaymentResponse:
    return PaymentResponse(
        payment_id=payment.id,
        transaction_ref=payment.transaction_ref,
        provider=payment.provider,
        payment_type=payment.payment_type,
        amount=payment.amount,
        status=payment.status,
        redirect_url=payment.redirect_url,
        class_id=payment.class_id,
        booking_id=payment.booking_id,
        class_status=cls.status if cls else None,
        booking_status=booking.status if booking else None,
        escrow_status=booking.escrow_status if booking else None,
        message=message,
        paid_at=payment.paid_at,
    )


def _payment_status_message(payment: Payment) -> str:
    status_messages = {
        "pending": "Dang cho ket qua thanh toan",
        "processing": "Giao dich dang duoc xu ly",
        "paid": "Thanh toan thanh cong",
        "released": "Tien escrow da duoc chuyen cho tutor",
        "refunded": "Giao dich da duoc hoan tien",
        "failed": payment.failure_reason or "Thanh toan that bai",
        "disputed": "Giao dich dang bi khiem giu do co khieu nai",
    }
    return status_messages.get(payment.status, payment.status)


def _sync_transaction_status_with_provider(
    db: Session,
    payment: Payment,
) -> tuple[Payment, Optional[Class], Optional[Booking]]:
    cls = _get_class_or_404(db, payment.class_id) if payment.class_id else None
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first() if payment.booking_id else None

    if payment.provider != PAYOS_PROVIDER:
        return payment, cls, booking

    if payment.status not in {"pending", "processing"}:
        return payment, cls, booking

    provider_order_id = (payment.provider_order_id or "").strip()
    if not provider_order_id:
        return payment, cls, booking

    try:
        gateway_status = fetch_provider_payment_status(PAYOS_PROVIDER, provider_order_id)
    except PaymentGatewayError:
        return payment, cls, booking

    if gateway_status.raw_payload:
        payment.provider_payload = gateway_status.raw_payload

    provider_status = (gateway_status.provider_status or "").upper()
    if provider_status in {"PAID", "CANCELLED", "FAILED", "EXPIRED"}:
        processed_payment = _process_payment_result(
            db=db,
            transaction_ref=gateway_status.transaction_ref,
            is_success=provider_status == "PAID",
            provider_transaction_id=gateway_status.provider_transaction_id,
            message=gateway_status.message,
            raw_payload=gateway_status.raw_payload,
        )
        refreshed_payment = _get_payment_by_reference_or_order_id(
            db,
            processed_payment.transaction_ref,
        )
        if refreshed_payment:
            payment = refreshed_payment
            cls = _get_class_or_404(db, payment.class_id) if payment.class_id else None
            booking = (
                db.query(Booking).filter(Booking.id == payment.booking_id).first()
                if payment.booking_id
                else None
            )
        return payment, cls, booking

    if provider_status == "PROCESSING" and payment.status != "processing":
        payment.status = "processing"
        db.commit()
        db.refresh(payment)

    cls = _get_class_or_404(db, payment.class_id) if payment.class_id else None
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first() if payment.booking_id else None
    return payment, cls, booking


def _serialize_transaction_status(
    payment: Payment,
    cls: Optional[Class] = None,
    booking: Optional[Booking] = None,
) -> PaymentTransactionStatusResponse:
    return PaymentTransactionStatusResponse(
        payment_id=payment.id,
        transaction_ref=payment.transaction_ref,
        payment_type=payment.payment_type,
        provider=payment.provider,
        status=payment.status,
        amount=payment.amount,
        redirect_url=payment.redirect_url,
        booking_id=payment.booking_id,
        class_id=payment.class_id,
        booking_status=booking.status if booking else None,
        escrow_status=booking.escrow_status if booking else None,
        class_status=cls.status if cls else None,
        message=_payment_status_message(payment),
        paid_at=payment.paid_at,
    )


def _render_payment_status_page(
    *,
    title: str,
    message: str,
    transaction_ref: str,
    status: str,
    provider_order_id: Optional[str] = None,
) -> str:
    provider_order_html = (
        f"<p><strong>Provider order:</strong> {provider_order_id}</p>" if provider_order_id else ""
    )
    return f"""
<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{title}</title>
</head>
<body style="font-family: Arial, sans-serif; padding: 24px; background: #f5f7fb;">
  <div style="max-width: 560px; margin: 40px auto; background: white; border-radius: 16px; padding: 24px; box-shadow: 0 10px 40px rgba(19, 35, 72, 0.12);">
    <h1 style="margin-top: 0;">{title}</h1>
    <p>{message}</p>
    <p><strong>Transaction:</strong> {transaction_ref}</p>
    {provider_order_html}
    <p><strong>Status:</strong> {status}</p>
  </div>
</body>
</html>
"""


def _resolve_teacher_bank_bin(teacher_profile: TeacherProfile) -> Optional[str]:
    if teacher_profile.bank_bin and teacher_profile.bank_bin.strip():
        return teacher_profile.bank_bin.strip()
    bank_name = (teacher_profile.bank_name or "").strip()
    if bank_name.isdigit():
        return bank_name
    return None


def _require_teacher_payout_destination(teacher_profile: TeacherProfile) -> tuple[str, str]:
    bank_bin = _resolve_teacher_bank_bin(teacher_profile)
    account_number = (teacher_profile.bank_account_number or "").strip()

    missing_fields = []
    if not bank_bin:
        missing_fields.append("bank_bin")
    if not account_number:
        missing_fields.append("bank_account_number")

    if missing_fields:
        raise PaymentGatewayError(
            "Tutor chua cap nhat day du thong tin payout payOS: "
            + ", ".join(missing_fields)
        )

    return bank_bin, account_number


def _build_payout_description(cls: Class) -> str:
    return f"Payout {_build_class_code(cls)}"[:25]


def _ensure_class_ready_for_payout(cls: Class, *, now: datetime) -> None:
    if cls.status not in {"scheduled", "completed"}:
        raise HTTPException(status_code=400, detail="Lop hoc chua o trang thai co the payout")
    if cls.end_time > now - timedelta(hours=2):
        raise HTTPException(status_code=400, detail="Chua qua 2 gio sau khi lop ket thuc")
    if cls.has_active_dispute:
        raise HTTPException(status_code=400, detail="Lop hoc dang co khieu nai, chua the payout")


def _mark_bookings_released(
    booking_rows: list[tuple[Booking, Payment]],
    *,
    released_at: datetime,
) -> Decimal:
    released_amount = Decimal("0")
    for booking, payment in booking_rows:
        booking.status = "completed"
        booking.escrow_status = "released"
        payment.status = "released"
        payment.released_at = released_at
        released_amount += Decimal(payment.amount)
    return released_amount


def _serialize_payout_balance_response(
    account_number: str,
    account_name: str,
    currency: str,
    balance: Decimal,
) -> PayOSPayoutBalanceResponse:
    return PayOSPayoutBalanceResponse(
        account_number=account_number,
        account_name=account_name,
        currency=currency,
        balance=balance,
    )


def _sync_class_participants(db: Session, class_id: str) -> int:
    active_count = (
        db.query(func.count(Booking.id))
        .filter(Booking.class_id == class_id, Booking.status.in_(["confirmed", "completed"]))
        .scalar()
    ) or 0
    cls = _get_class_or_404(db, class_id)
    cls.current_participants = active_count
    return active_count


def _count_open_disputes(db: Session, class_id: str) -> int:
    return (
        db.query(func.count(Booking.id))
        .filter(Booking.class_id == class_id, Booking.complaint_status == "open")
        .scalar()
    ) or 0


def _active_student_ids_for_class(db: Session, class_id: str) -> list[str]:
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


def _mark_minimum_participants_reached(db: Session, cls: Class) -> None:
    if cls.minimum_participants_reached or cls.current_participants < cls.min_participants:
        return

    cls.minimum_participants_reached = True
    cls.minimum_participants_reached_at = _now()
    if cls.tutor_confirmation_status == "waiting_minimum":
        cls.tutor_confirmation_status = "pending"

    notify_tutor_minimum_reached(db, cls=cls)


def _create_refund_payment(
    db: Session,
    *,
    payer_user_id: str,
    payee_user_id: str,
    class_id: Optional[str],
    booking_id: Optional[str],
    amount: Decimal,
    provider: str,
    reason: str,
) -> Payment:
    refund = Payment(
        id=str(uuid.uuid4()),
        booking_id=booking_id,
        class_id=class_id,
        payer_user_id=payer_user_id,
        payee_user_id=payee_user_id,
        payment_type="refund",
        provider=provider,
        amount=amount,
        status="refunded",
        transaction_ref=_generate_transaction_ref("REF"),
        provider_payload=reason,
        refunded_at=_now(),
    )
    db.add(refund)
    return refund


def _refund_booking(
    db: Session,
    booking: Booking,
    payment: Payment,
    reason: str,
    *,
    cls: Optional[Class] = None,
) -> None:
    booking.status = "refunded"
    booking.payment_status = "refunded"
    booking.escrow_status = "refunded"
    booking.cancelled_at = _now()
    booking.cancel_reason = reason

    payment.status = "refunded"
    payment.refunded_at = _now()
    payment.failure_reason = reason

    _create_refund_payment(
        db,
        payer_user_id=payment.payer_user_id,
        payee_user_id=booking.student_id,
        class_id=booking.class_id,
        booking_id=booking.id,
        amount=payment.amount,
        provider=payment.provider,
        reason=reason,
    )

    target_class = cls or _get_class_or_404(db, booking.class_id)
    notify_refund_issued(
        db,
        cls=target_class,
        student_user_id=booking.student_id,
        amount=Decimal(payment.amount),
        reason=reason,
        booking_id=booking.id,
    )


def _require_role(user: User, allowed_roles: set[str]) -> None:
    if user.role not in allowed_roles:
        raise HTTPException(status_code=403, detail="Ban khong co quyen thuc hien thao tac nay")


def _require_payment_access(user: User, payment: Payment) -> None:
    if user.role == "admin":
        return
    if user.id in {payment.payer_user_id, payment.payee_user_id}:
        return
    raise HTTPException(status_code=403, detail="Ban khong co quyen xem giao dich nay")


def _require_class_summary_access(db: Session, user: User, cls: Class) -> None:
    if user.role == "admin":
        return
    if user.role == "teacher" and cls.teacher_id == user.id:
        return
    raise HTTPException(status_code=403, detail="Ban khong co quyen xem tong quan thanh toan cua lop nay")


def _require_admin_or_job_secret(
    db: Session,
    *,
    user_dict: Optional[dict],
    x_job_secret: Optional[str],
) -> None:
    if user_dict is not None:
        user = _get_user_or_404(db, user_dict["uid"])
        _require_role(user, {"admin"})
        return

    if JOB_SECRET and x_job_secret == JOB_SECRET:
        return

    if JOB_SECRET:
        raise HTTPException(status_code=401, detail="Can x-job-secret hop le hoac token admin")
    raise HTTPException(status_code=401, detail="Can token admin de goi job endpoint")


def _process_payment_result(
    *,
    db: Session,
    transaction_ref: str,
    is_success: bool,
    provider_transaction_id: Optional[str] = None,
    message: Optional[str] = None,
    raw_payload: Optional[str] = None,
) -> PaymentResponse:
    payment = _get_payment_by_reference_or_order_id(db, transaction_ref)
    if not payment:
        raise HTTPException(status_code=404, detail="Khong tim thay giao dich")

    cls = _get_class_or_404(db, payment.class_id) if payment.class_id else None
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first() if payment.booking_id else None

    if raw_payload:
        payment.provider_payload = raw_payload

    if payment.status in {"paid", "refunded", "failed", "released"}:
        db.commit()
        return _serialize_payment(payment, cls=cls, booking=booking, message="Giao dich da duoc xu ly truoc do")

    if not is_success:
        payment.status = "failed"
        payment.failure_reason = message or "PSP thong bao giao dich that bai"
        if payment.payment_type == "class_creation" and cls:
            cls.creation_payment_status = "unpaid"
        if booking:
            booking.status = "cancelled"
            booking.payment_status = "failed"
            booking.cancelled_at = _now()
            booking.cancel_reason = payment.failure_reason
        db.commit()
        return _serialize_payment(payment, cls=cls, booking=booking, message="Thanh toan that bai")

    payment.status = "paid"
    if provider_transaction_id and not payment.provider_order_id:
        payment.provider_order_id = provider_transaction_id
    payment.paid_at = _now()

    if payment.payment_type == "class_creation":
        if not cls:
            raise HTTPException(status_code=500, detail="Lop hoc lien ket khong ton tai")
        cls.creation_payment_status = "paid"
        cls.creation_paid_at = payment.paid_at
        cls.status = "scheduled"
        cls.creation_payment_reference = payment.transaction_ref
        db.commit()
        db.refresh(cls)
        db.refresh(payment)
        return _serialize_payment(payment, cls=cls, message="Thanh toan thanh cong, lop hoc da duoc tao")

    if payment.payment_type == "tuition":
        if not booking or not cls:
            raise HTTPException(status_code=500, detail="Booking thanh toan khong hop le")

        locked_class = _get_class_or_404(db, cls.id, for_update=True)
        locked_booking = db.query(Booking).filter(Booking.id == booking.id).with_for_update().first()
        if not locked_booking:
            raise HTTPException(status_code=500, detail="Booking khong ton tai")

        if locked_booking.status in {"confirmed", "completed", "refunded"}:
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Booking da o trang thai cuoi")

        if locked_class.status != "scheduled":
            _refund_booking(
                db,
                locked_booking,
                payment,
                "Lop hoc khong con san sang de dang ky",
                cls=locked_class,
            )
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Da hoan tien do lop hoc khong kha dung")

        if locked_class.creation_payment_status != "paid":
            _refund_booking(
                db,
                locked_booking,
                payment,
                "Lop hoc chua hoan tat phi tao nhom",
                cls=locked_class,
            )
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Da hoan tien do lop hoc chua kich hoat")

        if locked_class.current_participants >= locked_class.max_participants:
            _refund_booking(
                db,
                locked_booking,
                payment,
                "Lop da het cho, tu dong hoan tien oversell",
                cls=locked_class,
            )
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Oversell: giao dich nay duoc hoan tien tu dong")

        locked_class.current_participants += 1
        locked_booking.status = "confirmed"
        locked_booking.payment_status = "paid"
        locked_booking.escrow_status = "held"
        locked_booking.escrow_held_at = payment.paid_at
        _mark_minimum_participants_reached(db, locked_class)
        if locked_class.tutor_confirmation_status == "confirmed":
            notify_student_tutor_already_confirmed(
                db,
                cls=locked_class,
                student_user_id=locked_booking.student_id,
            )
        db.commit()
        db.refresh(locked_class)
        db.refresh(locked_booking)
        db.refresh(payment)
        return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Thanh toan thanh cong, slot da duoc giu")

    raise HTTPException(status_code=400, detail="Loai giao dich khong duoc ho tro cho callback")


@router.post("/class-creation/request", response_model=PaymentResponse, status_code=201)
def create_class_payment_request(
    body: CreateClassPaymentRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = _get_user_or_404(db, user_dict["uid"])
    _require_role(teacher, {"teacher"})

    class_data = body.class_payload
    resolved_topic = ensure_topic_record(db, class_data.topic)
    selected_location = get_active_learning_location_or_400(db, class_data.location_id)

    creation_fee = calculate_creation_fee(class_data.price)
    new_class = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=resolved_topic.id,
        topic=resolved_topic.name,
        title=class_data.title,
        description=class_data.description,
        level=class_data.level,
        location_name=selected_location.name,
        location_address=selected_location.address,
        location_notes=selected_location.notes,
        latitude=selected_location.latitude,
        longitude=selected_location.longitude,
        start_time=class_data.start_time,
        end_time=class_data.end_time,
        min_participants=class_data.min_participants,
        max_participants=class_data.max_participants,
        current_participants=0,
        price=class_data.price,
        creation_fee_amount=creation_fee,
        creation_payment_status="pending",
        thumbnail_url=class_data.thumbnail_url,
        status="draft",
        tutor_payout_status="pending",
        tutor_payout_amount=Decimal("0"),
        minimum_participants_reached=False,
        tutor_confirmation_status="waiting_minimum",
    )

    payment = Payment(
        id=str(uuid.uuid4()),
        class_id=new_class.id,
        payer_user_id=teacher.id,
        payee_user_id=None,
        payment_type="class_creation",
        provider=PAYOS_PROVIDER,
        amount=creation_fee,
        status="pending",
        transaction_ref=_generate_transaction_ref("CRF"),
        provider_payload=class_data.model_dump_json(),
    )

    try:
        provider_result = create_provider_payment_url(
            provider=PAYOS_PROVIDER,
            transaction_ref=payment.transaction_ref,
            amount=creation_fee,
            order_info=f"Thanh toan phi tao lop {class_data.title}",
            extra_data={
                "class_id": new_class.id,
                "payment_type": "class_creation",
                "buyer_name": teacher.full_name,
                "buyer_email": teacher.email,
                "buyer_phone": teacher.phone,
            },
        )
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    payment.redirect_url = provider_result.redirect_url
    payment.provider_order_id = provider_result.provider_order_id
    payment.provider_payload = provider_result.provider_payload or payment.provider_payload
    new_class.creation_payment_reference = payment.transaction_ref

    db.add(new_class)
    db.add(payment)
    db.commit()
    db.refresh(payment)
    db.refresh(new_class)

    return _serialize_payment(payment, cls=new_class, message="Thanh toan phi tao lop de kich hoat lop hoc")


@router.post("/classes/{class_id}/join/request", response_model=PaymentResponse, status_code=201)
def create_join_payment_request(
    class_id: str,
    _: JoinClassPaymentRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    student = _get_user_or_404(db, user_dict["uid"])
    _require_role(student, {"student"})

    cls = _get_class_or_404(db, class_id)
    if cls.status != "scheduled" or cls.creation_payment_status != "paid":
        raise HTTPException(status_code=400, detail="Lop hoc chua san sang de dang ky")
    if cls.start_time <= _now():
        raise HTTPException(status_code=400, detail="Lop hoc da bat dau, khong the dang ky moi")
    if cls.teacher_id == student.id:
        raise HTTPException(status_code=400, detail="Tutor khong the tu dang ky lop cua minh")

    existing_booking = db.query(Booking).filter(Booking.class_id == class_id, Booking.student_id == student.id).first()
    if existing_booking and existing_booking.status in {"confirmed", "completed", "payment_pending"}:
        raise HTTPException(status_code=409, detail="Hoc vien da co giao dich dang xu ly voi lop nay")

    tuition = calculate_student_tuition(cls.price, cls.max_participants)
    if existing_booking:
        booking = existing_booking
        booking.status = "payment_pending"
        booking.payment_status = "pending"
        booking.payment_method = PAYOS_PROVIDER
        booking.tuition_amount = tuition
        booking.escrow_status = "pending"
        booking.cancelled_at = None
        booking.cancel_reason = None
    else:
        booking = Booking(
            id=str(uuid.uuid4()),
            class_id=cls.id,
            student_id=student.id,
            status="payment_pending",
            payment_status="pending",
            payment_method=PAYOS_PROVIDER,
            tuition_amount=tuition,
            escrow_status="pending",
        )
    payment = Payment(
        id=str(uuid.uuid4()),
        booking_id=booking.id,
        class_id=cls.id,
        payer_user_id=student.id,
        payee_user_id=cls.teacher_id,
        payment_type="tuition",
        provider=PAYOS_PROVIDER,
        amount=tuition,
        status="pending",
        transaction_ref=_generate_transaction_ref("TUI"),
    )

    try:
        provider_result = create_provider_payment_url(
            provider=PAYOS_PROVIDER,
            transaction_ref=payment.transaction_ref,
            amount=tuition,
            order_info=f"Thanh toan hoc phi lop {cls.title}",
            extra_data={
                "class_id": cls.id,
                "booking_id": booking.id,
                "payment_type": "tuition",
                "buyer_name": student.full_name,
                "buyer_email": student.email,
                "buyer_phone": student.phone,
            },
        )
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    payment.redirect_url = provider_result.redirect_url
    payment.provider_order_id = provider_result.provider_order_id
    payment.provider_payload = provider_result.provider_payload
    booking.payment_reference = payment.transaction_ref

    db.add(booking)
    db.add(payment)
    db.commit()
    db.refresh(payment)
    db.refresh(booking)

    return _serialize_payment(payment, cls=cls, booking=booking, message="Thanh toan hoc phi, tien se duoc giu escrow")


@router.post("/callback", response_model=PaymentResponse)
def handle_payment_callback(
    body: PaymentCallbackRequest,
    db: Session = Depends(get_db),
):
    _require_mock_payment_routes_enabled()
    return _process_payment_result(
        db=db,
        transaction_ref=body.transaction_ref,
        is_success=body.status == "success",
        provider_transaction_id=body.provider_transaction_id,
        message=body.failure_reason,
    )


@router.get("/transactions/{transaction_ref}", response_model=PaymentTransactionStatusResponse)
def get_transaction_status(
    transaction_ref: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    payment = db.query(Payment).filter(Payment.transaction_ref == transaction_ref).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Khong tim thay giao dich")

    user = _get_user_or_404(db, user_dict["uid"])
    _require_payment_access(user, payment)
    payment, cls, booking = _sync_transaction_status_with_provider(db, payment)
    return _serialize_transaction_status(payment, cls=cls, booking=booking)


@router.get("/mock/checkout/{transaction_ref}", response_class=HTMLResponse)
def mock_checkout_page(
    transaction_ref: str,
    provider: str,
    amount: int,
    orderInfo: str,
):
    _require_mock_payment_routes_enabled()
    safe_order_info = orderInfo.replace("<", "&lt;").replace(">", "&gt;")
    return f"""
<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Mock {provider.upper()} Checkout</title>
  <style>
    body {{ font-family: Arial, sans-serif; background: #f5f7fb; color: #172033; padding: 24px; }}
    .card {{ max-width: 560px; margin: 40px auto; background: white; border-radius: 16px; padding: 24px; box-shadow: 0 10px 40px rgba(19, 35, 72, 0.12); }}
    .badge {{ display: inline-block; padding: 6px 10px; border-radius: 999px; background: #e8efff; color: #1d4ed8; font-weight: 700; }}
    h1 {{ margin: 16px 0 12px; }}
    p {{ color: #4b5563; line-height: 1.6; }}
    .row {{ display: flex; justify-content: space-between; margin: 10px 0; }}
    .actions {{ display: flex; gap: 12px; margin-top: 24px; }}
    a {{ text-decoration: none; text-align: center; padding: 14px 18px; border-radius: 12px; font-weight: 700; flex: 1; }}
    .success {{ background: #111827; color: white; }}
    .fail {{ background: #fee2e2; color: #b91c1c; }}
  </style>
</head>
<body>
  <div class="card">
    <span class="badge">Mock {provider.upper()}</span>
    <h1>Gia lap cong thanh toan</h1>
    <p>Trang nay duoc dung de test end-to-end khi chua co sandbox credential hoac callback cong khai.</p>
    <div class="row"><strong>Transaction</strong><span>{transaction_ref}</span></div>
    <div class="row"><strong>So tien</strong><span>{amount} VND</span></div>
    <div class="row"><strong>Noi dung</strong><span>{safe_order_info}</span></div>
    <div class="actions">
      <a class="success" href="/payments/mock/complete/{transaction_ref}?status=success&provider={provider}">Thanh toan thanh cong</a>
      <a class="fail" href="/payments/mock/complete/{transaction_ref}?status=failed&provider={provider}">Thanh toan that bai</a>
    </div>
  </div>
</body>
</html>
"""


@router.get("/mock/complete/{transaction_ref}", response_class=HTMLResponse)
def mock_complete_payment(
    transaction_ref: str,
    provider: str,
    status: str,
    db: Session = Depends(get_db),
):
    _require_mock_payment_routes_enabled()
    result = verify_provider_callback(
        "mock",
        {
            "transaction_ref": transaction_ref,
            "status": status,
            "provider_transaction_id": f"{provider.upper()}-MOCK-{uuid.uuid4().hex[:10]}",
            "message": "Mock PSP completed",
        },
    )
    payment_result = _process_payment_result(
        db=db,
        transaction_ref=result.transaction_ref,
        is_success=result.is_success,
        provider_transaction_id=result.provider_transaction_id,
        message=result.message,
        raw_payload=result.raw_payload,
    )
    return _render_payment_status_page(
        title=payment_result.message or "Ket qua thanh toan",
        message="Ban co the quay lai app. Ung dung se tu dong poll va cap nhat trang thai.",
        transaction_ref=payment_result.transaction_ref,
        status=payment_result.status,
    )


@router.get("/providers/payos/return", response_class=HTMLResponse)
async def payos_return(
    request: Request,
    db: Session = Depends(get_db),
):
    provider_order_id = request.query_params.get("orderCode") or request.query_params.get("order_code")
    if not provider_order_id:
        raise HTTPException(status_code=400, detail="Thieu orderCode tu payOS")

    payment = _get_payment_by_reference_or_order_id(db, provider_order_id)
    if not payment:
        raise HTTPException(status_code=404, detail="Khong tim thay giao dich payOS")

    cls = _get_class_or_404(db, payment.class_id) if payment.class_id else None
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first() if payment.booking_id else None

    if payment.status in {"paid", "released", "refunded", "failed"}:
        current_status = _serialize_transaction_status(payment, cls=cls, booking=booking)
        return _render_payment_status_page(
            title=current_status.message or "Trang thai giao dich",
            message="Ban co the quay lai app. Ung dung se tiep tuc poll trang thai giao dich.",
            transaction_ref=current_status.transaction_ref,
            status=current_status.status,
            provider_order_id=payment.provider_order_id,
        )

    try:
        gateway_status = fetch_provider_payment_status("payos", provider_order_id)
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if gateway_status.provider_status in {"PAID", "CANCELLED", "FAILED", "EXPIRED"}:
        payment_result = _process_payment_result(
            db=db,
            transaction_ref=gateway_status.transaction_ref,
            is_success=gateway_status.provider_status == "PAID",
            provider_transaction_id=gateway_status.provider_transaction_id,
            message=gateway_status.message,
            raw_payload=gateway_status.raw_payload,
        )
        return _render_payment_status_page(
            title=payment_result.message or "Ket qua thanh toan",
            message="Ban co the quay lai app. Ung dung se tu dong cap nhat trang thai moi nhat.",
            transaction_ref=payment_result.transaction_ref,
            status=payment_result.status,
            provider_order_id=payment.provider_order_id,
        )

    return _render_payment_status_page(
        title="Dang cho payOS xac nhan",
        message="Ban co the quay lai app. Backend dang cho webhook hoac trang thai cuoi tu payOS.",
        transaction_ref=payment.transaction_ref,
        status=payment.status,
        provider_order_id=payment.provider_order_id,
    )


@router.post("/providers/payos/webhook")
async def payos_webhook(
    request: Request,
    db: Session = Depends(get_db),
):
    raw_payload = await request.body()
    try:
        result = verify_provider_callback("payos", raw_payload)
    except PaymentGatewayError as exc:
        return {"code": "01", "desc": str(exc)}

    if not _get_payment_by_reference_or_order_id(db, result.transaction_ref):
        return {"code": "00", "desc": "Webhook hop le, khong co giao dich noi bo can xu ly"}

    try:
        _process_payment_result(
            db=db,
            transaction_ref=result.transaction_ref,
            is_success=result.is_success,
            provider_transaction_id=result.provider_transaction_id,
            message=result.message,
            raw_payload=result.raw_payload,
        )
    except HTTPException as exc:
        return {"code": str(exc.status_code), "desc": exc.detail}

    return {"code": "00", "desc": "Success"}


@router.post("/providers/payos/confirm-webhook", response_model=ConfirmPayOSWebhookResponse)
def confirm_payos_webhook(
    body: ConfirmPayOSWebhookRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    admin = _get_user_or_404(db, user_dict["uid"])
    _require_role(admin, {"admin"})

    webhook_url = body.webhook_url or default_provider_webhook_url("payos")
    try:
        confirmation = confirm_provider_webhook("payos", webhook_url)
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return ConfirmPayOSWebhookResponse(
        webhook_url=confirmation.webhook_url,
        account_name=confirmation.account_name,
        account_number=confirmation.account_number,
        name=confirmation.name,
        short_name=confirmation.short_name,
    )


@router.get("/providers/payos/payout-account/balance", response_model=PayOSPayoutBalanceResponse)
def get_payos_payout_balance(
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    admin = _get_user_or_404(db, user_dict["uid"])
    _require_role(admin, {"admin"})

    try:
        balance = fetch_provider_payout_balance(PAYOS_PROVIDER)
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return _serialize_payout_balance_response(
        account_number=balance.account_number,
        account_name=balance.account_name,
        currency=balance.currency,
        balance=balance.balance,
    )


@router.post("/classes/{class_id}/retry-payout")
def retry_class_payout(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    admin = _get_user_or_404(db, user_dict["uid"])
    _require_role(admin, {"admin"})

    now = _now()
    cls = _get_class_or_404(db, class_id, for_update=True)
    _ensure_class_ready_for_payout(cls, now=now)

    booking_rows = _held_booking_rows_for_class(db, cls.id)
    if not booking_rows:
        if cls.tutor_payout_status == "paid":
            return {
                "class_id": cls.id,
                "status": cls.tutor_payout_status,
                "amount": str(cls.tutor_payout_amount),
                "provider_order_id": None,
                "message": "Payout đã hoàn tất trước đó",
            }
        raise HTTPException(status_code=400, detail="Khong co escrow dang giu de retry payout")

    existing_payout = _active_payout_payment_for_class(db, cls.id)
    if existing_payout and existing_payout.status == "processing":
        payout_result = _sync_existing_payout(
            db=db,
            cls=cls,
            payout_payment=existing_payout,
            processed_at=now,
        )
        db.commit()
        return {
            "class_id": cls.id,
            "status": cls.tutor_payout_status,
            "amount": str(cls.tutor_payout_amount),
            "provider_order_id": existing_payout.provider_order_id,
            "provider_status": payout_result.provider_status,
            "message": "Da dong bo lai trang thai payout dang xu ly",
        }

    if existing_payout and existing_payout.status == "released":
        db.commit()
        return {
            "class_id": cls.id,
            "status": cls.tutor_payout_status,
            "amount": str(cls.tutor_payout_amount),
            "provider_order_id": existing_payout.provider_order_id,
            "message": "Payout đã hoàn tất trước đó",
        }

    cls.tutor_payout_status = "pending"
    payout_payment = _create_payout_attempt(
        db=db,
        cls=cls,
        booking_rows=booking_rows,
        processed_at=now,
    )
    db.commit()

    return {
        "class_id": cls.id,
        "status": cls.tutor_payout_status,
        "amount": str(cls.tutor_payout_amount),
        "provider_order_id": payout_payment.provider_order_id,
        "message": "Da tao lai lenh payout qua payOS",
    }


@router.post("/classes/{class_id}/cancel", response_model=PaymentSummaryResponse)
def cancel_class_by_tutor(
    class_id: str,
    body: CancelClassRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    tutor = _get_user_or_404(db, user_dict["uid"])
    _require_role(tutor, {"teacher"})
    cls = _get_class_or_404(db, class_id, for_update=True)

    if cls.teacher_id != tutor.id:
        raise HTTPException(status_code=403, detail="Ban khong so huu lop hoc nay")
    if cls.status == "cancelled":
        return _build_class_payment_summary(db, class_id)

    cls.status = "cancelled"
    cls.cancelled_at = _now()
    cls.cancellation_reason = body.reason or "Tutor chu dong huy lop"

    booking_rows = (
        db.query(Booking, Payment)
        .join(Payment, Payment.booking_id == Booking.id)
        .filter(Booking.class_id == class_id, Payment.payment_type == "tuition", Payment.status == "paid")
        .all()
    )
    student_user_ids = list({booking.student_id for booking, _ in booking_rows})
    for booking, payment in booking_rows:
        _refund_booking(db, booking, payment, cls.cancellation_reason, cls=cls)

    cls.current_participants = 0
    cls.tutor_payout_status = "withheld"
    cls.tutor_payout_amount = Decimal("0")
    notify_class_cancelled(
        db,
        cls=cls,
        student_user_ids=student_user_ids,
        reason=cls.cancellation_reason,
        cancelled_by="teacher",
    )
    db.commit()

    return _build_class_payment_summary(db, class_id)


@router.post("/bookings/{booking_id}/complaints", response_model=PaymentSummaryResponse)
def create_complaint(
    booking_id: str,
    body: ComplaintRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    student = _get_user_or_404(db, user_dict["uid"])
    _require_role(student, {"student"})

    booking = db.query(Booking).filter(Booking.id == booking_id).with_for_update().first()
    if not booking:
        raise HTTPException(status_code=404, detail="Khong tim thay booking")
    if booking.student_id != student.id:
        raise HTTPException(status_code=403, detail="Ban khong the khieu nai booking nay")

    cls = _get_class_or_404(db, booking.class_id, for_update=True)
    complaint_deadline = cls.end_time + timedelta(hours=2)
    if _now() > complaint_deadline:
        raise HTTPException(status_code=400, detail="Da qua han 2 gio de gui khieu nai")
    if booking.escrow_status not in {"held", "disputed"}:
        raise HTTPException(status_code=400, detail="Booking nay khong o trang thai co the khieu nai")

    booking.complaint_status = "open"
    booking.complaint_reason = body.reason
    booking.complaint_opened_at = _now()
    booking.escrow_status = "disputed"
    cls.has_active_dispute = True
    cls.tutor_payout_status = "on_hold"
    cls.complaint_deadline = complaint_deadline

    payment = db.query(Payment).filter(Payment.booking_id == booking.id, Payment.payment_type == "tuition").first()
    if payment and payment.status == "paid":
        payment.status = "disputed"

    db.commit()
    return _build_class_payment_summary(db, cls.id)


@router.post("/complaints/resolve", response_model=PaymentSummaryResponse)
def resolve_complaint(
    body: ResolveComplaintRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    admin = _get_user_or_404(db, user_dict["uid"])
    _require_role(admin, {"admin"})

    booking = db.query(Booking).filter(Booking.id == body.booking_id).with_for_update().first()
    if not booking:
        raise HTTPException(status_code=404, detail="Khong tim thay booking")
    if booking.complaint_status != "open":
        raise HTTPException(status_code=400, detail="Booking nay khong co khieu nai dang mo")

    cls = _get_class_or_404(db, booking.class_id, for_update=True)
    payment = db.query(Payment).filter(Payment.booking_id == booking.id, Payment.payment_type == "tuition").first()

    if body.is_valid:
        booking.complaint_status = "resolved_valid"
        booking.complaint_reason = body.note or booking.complaint_reason
        if payment:
            _refund_booking(
                db,
                booking,
                payment,
                body.note or "Admin xac nhan khieu nai hop le",
                cls=cls,
            )
        cls.tutor_payout_status = "withheld"
    else:
        booking.complaint_status = "resolved_rejected"
        booking.complaint_reason = body.note or booking.complaint_reason
        booking.escrow_status = "held"
        if payment and payment.status == "disputed":
            payment.status = "paid"

    open_disputes = _count_open_disputes(db, cls.id)
    cls.has_active_dispute = open_disputes > 0
    if open_disputes == 0 and cls.tutor_payout_status == "on_hold":
        cls.has_active_dispute = False
        cls.tutor_payout_status = "pending"

    _sync_class_participants(db, cls.id)
    resolution_note = body.note or booking.complaint_reason
    notify_dispute_resolved(
        db,
        cls=cls,
        recipient_user_id=booking.student_id,
        recipient_role="student",
        is_valid=body.is_valid,
        note=resolution_note,
    )
    notify_dispute_resolved(
        db,
        cls=cls,
        recipient_user_id=cls.teacher_id,
        recipient_role="teacher",
        is_valid=body.is_valid,
        note=resolution_note,
    )
    db.commit()
    return _build_class_payment_summary(db, cls.id)


def _active_payout_payment_for_class(db: Session, class_id: str) -> Optional[Payment]:
    return (
        db.query(Payment)
        .filter(
            Payment.class_id == class_id,
            Payment.payment_type == "payout",
            Payment.provider == PAYOS_PROVIDER,
            Payment.status.in_(["pending", "processing", "released"]),
        )
        .order_by(Payment.created_at.desc())
        .first()
    )


def _processing_payout_rows(db: Session) -> list[tuple[Payment, Class]]:
    return (
        db.query(Payment, Class)
        .join(Class, Class.id == Payment.class_id)
        .filter(
            Payment.payment_type == "payout",
            Payment.provider == PAYOS_PROVIDER,
            Payment.status == "processing",
        )
        .all()
    )


def _held_booking_rows_for_class(db: Session, class_id: str) -> list[tuple[Booking, Payment]]:
    return (
        db.query(Booking, Payment)
        .join(
            Payment,
            and_(
                Payment.booking_id == Booking.id,
                Payment.transaction_ref == Booking.payment_reference,
            ),
        )
        .filter(
            Booking.class_id == class_id,
            Booking.status.in_(["confirmed", "completed"]),
            Booking.payment_status == "paid",
            Booking.escrow_status == "held",
            Payment.payment_type == "tuition",
            Payment.status == "paid",
        )
        .all()
    )


def _build_payout_payment(
    *,
    cls: Class,
    transaction_ref: str,
    amount: Decimal,
    payout_result: ProviderPayoutResult,
    processed_at: datetime,
) -> Payment:
    payout_payment = Payment(
        id=str(uuid.uuid4()),
        class_id=cls.id,
        payer_user_id=cls.teacher_id,
        payee_user_id=cls.teacher_id,
        booking_id=None,
        payment_type="payout",
        provider=PAYOS_PROVIDER,
        amount=amount,
        status=payout_result.local_status,
        transaction_ref=transaction_ref,
        provider_order_id=payout_result.provider_order_id,
        provider_payload=payout_result.raw_payload,
        failure_reason=payout_result.message if payout_result.local_status == "failed" else None,
    )
    if payout_result.local_status == "released":
        payout_payment.released_at = processed_at
    return payout_payment


def _apply_class_payout_state(
    *,
    cls: Class,
    booking_rows: list[tuple[Booking, Payment]],
    payout_payment: Payment,
    payout_result: ProviderPayoutResult,
    processed_at: datetime,
) -> None:
    cls.status = "completed"
    cls.complaint_deadline = cls.end_time + timedelta(hours=2)
    cls.tutor_payout_amount = Decimal(payout_payment.amount)

    if payout_result.local_status == "released":
        released_amount = _mark_bookings_released(booking_rows, released_at=processed_at)
        cls.tutor_payout_status = "paid"
        cls.tutor_payout_amount = released_amount
        cls.tutor_paid_at = processed_at
        payout_payment.released_at = processed_at
        payout_payment.failure_reason = None
    elif payout_result.local_status == "failed":
        cls.tutor_payout_status = "failed"
        cls.tutor_paid_at = None
        payout_payment.failure_reason = payout_result.message
    else:
        cls.tutor_payout_status = "processing"
        cls.tutor_paid_at = None
        payout_payment.failure_reason = None


def _create_payout_attempt(
    *,
    db: Session,
    cls: Class,
    booking_rows: list[tuple[Booking, Payment]],
    processed_at: datetime,
) -> Payment:
    teacher_profile = _get_teacher_profile_or_404(db, cls.teacher_id)
    bank_bin, bank_account_number = _require_teacher_payout_destination(teacher_profile)
    payout_amount = sum((Decimal(payment.amount) for _, payment in booking_rows), Decimal("0"))
    transaction_ref = _generate_transaction_ref("OUT")

    payout_result = create_provider_payout(
        provider=PAYOS_PROVIDER,
        reference_id=transaction_ref,
        amount=payout_amount,
        description=_build_payout_description(cls),
        to_bin=bank_bin,
        to_account_number=bank_account_number,
    )

    payout_payment = _build_payout_payment(
        cls=cls,
        transaction_ref=transaction_ref,
        amount=payout_amount,
        payout_result=payout_result,
        processed_at=processed_at,
    )
    _apply_class_payout_state(
        cls=cls,
        booking_rows=booking_rows,
        payout_payment=payout_payment,
        payout_result=payout_result,
        processed_at=processed_at,
    )
    db.add(payout_payment)
    notify_tutor_payout_updated(
        db,
        cls=cls,
        amount=payout_amount,
        payout_status=cls.tutor_payout_status,
        transaction_ref=transaction_ref,
        provider_order_id=payout_result.provider_order_id,
        message=payout_result.message,
    )
    return payout_payment


def _sync_existing_payout(
    *,
    db: Session,
    cls: Class,
    payout_payment: Payment,
    processed_at: datetime,
) -> ProviderPayoutResult:
    if not payout_payment.provider_order_id:
        raise PaymentGatewayError("Lenh chi payOS khong co provider_order_id de dong bo")

    previous_status = payout_payment.status
    payout_result = fetch_provider_payout_status(PAYOS_PROVIDER, payout_payment.provider_order_id)
    payout_payment.provider_payload = payout_result.raw_payload
    payout_payment.failure_reason = payout_result.message if payout_result.local_status == "failed" else None
    payout_payment.status = payout_result.local_status

    if payout_result.local_status == "released":
        booking_rows = _held_booking_rows_for_class(db, cls.id)
        _apply_class_payout_state(
            cls=cls,
            booking_rows=booking_rows,
            payout_payment=payout_payment,
            payout_result=payout_result,
            processed_at=processed_at,
        )
    elif payout_result.local_status == "failed":
        cls.tutor_payout_status = "failed"
        cls.tutor_payout_amount = Decimal(payout_payment.amount)
        cls.tutor_paid_at = None
    else:
        cls.tutor_payout_status = "processing"
        cls.tutor_payout_amount = Decimal(payout_payment.amount)
        cls.tutor_paid_at = None

    if payout_result.local_status != previous_status:
        notify_tutor_payout_updated(
            db,
            cls=cls,
            amount=Decimal(payout_payment.amount),
            payout_status=cls.tutor_payout_status,
            transaction_ref=payout_payment.transaction_ref,
            provider_order_id=payout_payment.provider_order_id,
            message=payout_result.message,
        )

    return payout_result


def _build_class_payment_summary(db: Session, class_id: str) -> PaymentSummaryResponse:
    cls = _get_class_or_404(db, class_id)
    total_escrow_held = (
        db.query(func.coalesce(func.sum(Booking.tuition_amount), 0))
        .filter(Booking.class_id == class_id, Booking.escrow_status.in_(["held", "disputed"]))
        .scalar()
    ) or 0
    return PaymentSummaryResponse(
        class_id=cls.id,
        class_status=cls.status,
        creation_payment_status=cls.creation_payment_status,
        creation_fee_amount=cls.creation_fee_amount,
        min_participants=cls.min_participants,
        max_participants=cls.max_participants,
        current_participants=cls.current_participants,
        minimum_participants_reached=cls.minimum_participants_reached,
        tutor_confirmation_status=cls.tutor_confirmation_status,
        tutor_confirmed_at=cls.tutor_confirmed_at,
        tutor_payout_status=cls.tutor_payout_status,
        tutor_payout_amount=cls.tutor_payout_amount,
        total_escrow_held=Decimal(total_escrow_held),
        active_disputes=_count_open_disputes(db, class_id),
    )


@router.get("/classes/{class_id}/summary", response_model=PaymentSummaryResponse)
def get_class_payment_summary(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    cls = _get_class_or_404(db, class_id)
    user = _get_user_or_404(db, user_dict["uid"])
    _require_class_summary_access(db, user, cls)
    notified = dispatch_due_class_starting_soon_notifications(db, target_user_id=user.id)
    if notified:
        db.commit()
    else:
        db.rollback()
    return _build_class_payment_summary(db, class_id)


@router.get("/classes/by-code/{class_code}/summary", response_model=PaymentSummaryResponse)
def get_class_payment_summary_by_code(
    class_code: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    normalized_code = class_code.strip().upper()
    if not normalized_code:
        raise HTTPException(status_code=400, detail="Mã lớp không hợp lệ")

    user = _get_user_or_404(db, user_dict["uid"])
    classes = db.query(Class).all()
    for cls in classes:
        if _build_class_code(cls).upper() == normalized_code:
            _require_class_summary_access(db, user, cls)
            notified = dispatch_due_class_starting_soon_notifications(db, target_user_id=user.id)
            if notified:
                db.commit()
            else:
                db.rollback()
            return _build_class_payment_summary(db, cls.id)

    raise HTTPException(status_code=404, detail="Khong tim thay lop hoc voi ma nay")


@router.post("/classes/{class_id}/confirm-teaching", response_model=TutorTeachingConfirmationResponse)
def confirm_class_teaching(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    tutor = _get_user_or_404(db, user_dict["uid"])
    _require_role(tutor, {"teacher"})

    cls = _get_class_or_404(db, class_id, for_update=True)
    if cls.teacher_id != tutor.id:
        raise HTTPException(status_code=403, detail="Ban khong so huu lop hoc nay")
    if cls.status != "scheduled":
        raise HTTPException(status_code=400, detail="Chi co the xac nhan day voi lop dang scheduled")
    if not cls.minimum_participants_reached or cls.current_participants < cls.min_participants:
        raise HTTPException(status_code=400, detail="Lop hoc chua dat nguong hoc vien toi thieu")
    if cls.tutor_confirmation_status == "confirmed":
        return TutorTeachingConfirmationResponse(
            class_id=cls.id,
            tutor_confirmation_status=cls.tutor_confirmation_status,
            minimum_participants_reached=cls.minimum_participants_reached,
            tutor_confirmed_at=cls.tutor_confirmed_at,
            notified_students=0,
            message="Tutor đã xác nhận dạy từ trước",
        )

    cls.tutor_confirmation_status = "confirmed"
    cls.tutor_confirmed_at = _now()
    student_user_ids = _active_student_ids_for_class(db, cls.id)
    notify_students_tutor_confirmed(db, cls=cls, student_user_ids=student_user_ids)

    db.commit()
    return TutorTeachingConfirmationResponse(
        class_id=cls.id,
        tutor_confirmation_status=cls.tutor_confirmation_status,
        minimum_participants_reached=cls.minimum_participants_reached,
        tutor_confirmed_at=cls.tutor_confirmed_at,
        notified_students=len(student_user_ids),
        message="Đã xác nhận dạy và gửi thông báo cho học viên đã đăng ký",
    )


@router.post("/jobs/notify-classes-starting-soon")
def notify_classes_starting_soon(
    db: Session = Depends(get_db),
    user_dict: Optional[dict] = Depends(optional_auth_middleware),
    x_job_secret: Optional[str] = Header(default=None),
):
    _require_admin_or_job_secret(db, user_dict=user_dict, x_job_secret=x_job_secret)
    notified = dispatch_due_class_starting_soon_notifications(db, now=_now())
    db.commit()
    return {"notified": notified, "count": len(notified)}


@router.post("/jobs/cancel-underfilled-classes")
def cancel_underfilled_classes(
    db: Session = Depends(get_db),
    user_dict: Optional[dict] = Depends(optional_auth_middleware),
    x_job_secret: Optional[str] = Header(default=None),
):
    _require_admin_or_job_secret(db, user_dict=user_dict, x_job_secret=x_job_secret)
    now = _now()
    deadline = now + timedelta(hours=4)
    classes = (
        db.query(Class)
        .filter(Class.status == "scheduled", Class.start_time <= deadline, Class.start_time > now)
        .all()
    )

    cancelled = []
    for cls in classes:
        active_count = _sync_class_participants(db, cls.id)
        if active_count >= cls.min_participants:
            continue

        cls.status = "cancelled"
        cls.cancelled_at = now
        cls.cancellation_reason = "Khong du hoc vien toi thieu truoc 4 gio"

        booking_rows = (
            db.query(Booking, Payment)
            .join(Payment, Payment.booking_id == Booking.id)
            .filter(Booking.class_id == cls.id, Payment.payment_type == "tuition", Payment.status == "paid")
            .all()
        )
        student_user_ids = list({booking.student_id for booking, _ in booking_rows})
        for booking, payment in booking_rows:
            _refund_booking(db, booking, payment, cls.cancellation_reason, cls=cls)

        if cls.current_participants == 0 and cls.creation_payment_status == "paid":
            cls.creation_payment_status = "refunded"
            _create_refund_payment(
                db,
                payer_user_id=cls.teacher_id,
                payee_user_id=cls.teacher_id,
                class_id=cls.id,
                booking_id=None,
                amount=cls.creation_fee_amount,
                provider="system",
                reason="Hoan phi tao nhom do lop bi huy va chua co hoc vien",
            )

        cls.current_participants = 0
        cls.tutor_payout_status = "withheld"
        notify_class_cancelled(
            db,
            cls=cls,
            student_user_ids=student_user_ids,
            reason=cls.cancellation_reason,
            cancelled_by="system",
            notify_teacher=True,
        )
        cancelled.append(cls.id)

    db.commit()
    return {"cancelled_class_ids": cancelled, "count": len(cancelled)}


@router.post("/jobs/release-eligible-payouts")
def release_eligible_payouts(
    db: Session = Depends(get_db),
    user_dict: Optional[dict] = Depends(optional_auth_middleware),
    x_job_secret: Optional[str] = Header(default=None),
):
    _require_admin_or_job_secret(db, user_dict=user_dict, x_job_secret=x_job_secret)
    now = _now()
    eligible_classes = (
        db.query(Class)
        .filter(
            Class.status.in_(["scheduled", "completed"]),
            Class.end_time <= now - timedelta(hours=2),
            Class.has_active_dispute.is_(False),
        )
        .all()
    )

    released = []
    for cls in eligible_classes:
        if cls.tutor_payout_status not in {"pending", "processing"}:
            continue

        existing_payout = _active_payout_payment_for_class(db, cls.id)
        if existing_payout and existing_payout.status == "processing":
            released.append(
                {
                    "class_id": cls.id,
                    "status": "processing",
                    "amount": str(existing_payout.amount),
                }
            )
            continue

        booking_rows = _held_booking_rows_for_class(db, cls.id)
        if not booking_rows:
            if cls.status == "scheduled":
                cls.status = "completed"
            continue

        if existing_payout and existing_payout.status == "released":
            continue

        try:
            payout_payment = _create_payout_attempt(
                db=db,
                cls=cls,
                booking_rows=booking_rows,
                processed_at=now,
            )
            released.append(
                {
                    "class_id": cls.id,
                    "status": cls.tutor_payout_status,
                    "amount": str(cls.tutor_payout_amount),
                    "provider_order_id": payout_payment.provider_order_id,
                }
            )
        except (HTTPException, PaymentGatewayError) as exc:
            payout_amount = sum((Decimal(payment.amount) for _, payment in booking_rows), Decimal("0"))
            cls.status = "completed"
            cls.tutor_payout_status = "failed"
            cls.tutor_payout_amount = payout_amount
            cls.tutor_paid_at = None
            notify_tutor_payout_updated(
                db,
                cls=cls,
                amount=payout_amount,
                payout_status=cls.tutor_payout_status,
                message=exc.detail if isinstance(exc, HTTPException) else str(exc),
            )
            released.append(
                {
                    "class_id": cls.id,
                    "status": "failed",
                    "amount": str(payout_amount),
                    "error": exc.detail if isinstance(exc, HTTPException) else str(exc),
                }
            )

    db.commit()
    return {"released": released, "count": len(released)}


@router.post("/jobs/sync-payout-statuses")
def sync_payout_statuses(
    db: Session = Depends(get_db),
    user_dict: Optional[dict] = Depends(optional_auth_middleware),
    x_job_secret: Optional[str] = Header(default=None),
):
    _require_admin_or_job_secret(db, user_dict=user_dict, x_job_secret=x_job_secret)
    now = _now()
    synced = []

    for payout_payment, cls in _processing_payout_rows(db):
        try:
            payout_result = _sync_existing_payout(
                db=db,
                cls=cls,
                payout_payment=payout_payment,
                processed_at=now,
            )
            synced.append(
                {
                    "class_id": cls.id,
                    "payout_id": payout_payment.id,
                    "status": cls.tutor_payout_status,
                    "provider_status": payout_result.provider_status,
                }
            )
        except PaymentGatewayError as exc:
            synced.append(
                {
                    "class_id": cls.id,
                    "payout_id": payout_payment.id,
                    "status": "error",
                    "error": str(exc),
                }
            )

    db.commit()
    return {"synced": synced, "count": len(synced)}
