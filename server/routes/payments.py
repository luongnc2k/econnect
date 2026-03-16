from datetime import datetime, timedelta, timezone
from decimal import Decimal
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.booking import Booking
from models.class_ import Class
from models.payment import Payment
from models.topic import Topic
from models.user import User
from payment_gateways import (
    PaymentGatewayError,
    create_provider_payment_url,
    verify_provider_callback,
)
from pydantic_schemas.payment import (
    CancelClassRequest,
    ComplaintRequest,
    CreateClassPaymentRequest,
    JoinClassPaymentRequest,
    PaymentCallbackRequest,
    PaymentResponse,
    PaymentSummaryResponse,
    PaymentTransactionStatusResponse,
    ResolveComplaintRequest,
    calculate_creation_fee,
    calculate_student_tuition,
)

router = APIRouter()


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
        raise HTTPException(status_code=404, detail="Khong tim thay nguoi dung")
    return user


def _get_class_or_404(db: Session, class_id: str, for_update: bool = False) -> Class:
    query = db.query(Class).filter(Class.id == class_id)
    if for_update:
        query = query.with_for_update()
    cls = query.first()
    if not cls:
        raise HTTPException(status_code=404, detail="Khong tim thay lop hoc")
    return cls


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
        "paid": "Thanh toan thanh cong",
        "released": "Tien escrow da duoc chuyen cho tutor",
        "refunded": "Giao dich da duoc hoan tien",
        "failed": payment.failure_reason or "Thanh toan that bai",
        "disputed": "Giao dich dang bi khiem giu do co khieu nai",
    }
    return status_messages.get(payment.status, payment.status)


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


def _refund_booking(db: Session, booking: Booking, payment: Payment, reason: str) -> None:
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


def _require_role(user: User, allowed_roles: set[str]) -> None:
    if user.role not in allowed_roles:
        raise HTTPException(status_code=403, detail="Ban khong co quyen thuc hien thao tac nay")


def _process_payment_result(
    *,
    db: Session,
    transaction_ref: str,
    is_success: bool,
    provider_transaction_id: Optional[str] = None,
    message: Optional[str] = None,
    raw_payload: Optional[str] = None,
) -> PaymentResponse:
    payment = db.query(Payment).filter(Payment.transaction_ref == transaction_ref).first()
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
            _refund_booking(db, locked_booking, payment, "Lop hoc khong con san sang de dang ky")
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Da hoan tien do lop hoc khong kha dung")

        if locked_class.creation_payment_status != "paid":
            _refund_booking(db, locked_booking, payment, "Lop hoc chua hoan tat phi tao nhom")
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Da hoan tien do lop hoc chua kich hoat")

        if locked_class.current_participants >= locked_class.max_participants:
            _refund_booking(db, locked_booking, payment, "Lop da het cho, tu dong hoan tien oversell")
            db.commit()
            return _serialize_payment(payment, cls=locked_class, booking=locked_booking, message="Oversell: giao dich nay duoc hoan tien tu dong")

        locked_class.current_participants += 1
        locked_booking.status = "confirmed"
        locked_booking.payment_status = "paid"
        locked_booking.escrow_status = "held"
        locked_booking.escrow_held_at = payment.paid_at
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
    topic = db.query(Topic).filter(Topic.id == class_data.topic_id, Topic.is_active == True).first()
    if not topic:
        raise HTTPException(status_code=404, detail="Topic khong ton tai")

    creation_fee = calculate_creation_fee(class_data.price)
    new_class = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        title=class_data.title,
        description=class_data.description,
        level=class_data.level,
        location_name=class_data.location_name,
        location_address=class_data.location_address,
        latitude=class_data.latitude,
        longitude=class_data.longitude,
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
    )

    payment = Payment(
        id=str(uuid.uuid4()),
        class_id=new_class.id,
        payer_user_id=teacher.id,
        payee_user_id=None,
        payment_type="class_creation",
        provider=body.provider,
        amount=creation_fee,
        status="pending",
        transaction_ref=_generate_transaction_ref("CRF"),
        provider_payload=class_data.model_dump_json(),
    )

    try:
        provider_result = create_provider_payment_url(
            provider=body.provider,
            transaction_ref=payment.transaction_ref,
            amount=creation_fee,
            order_info=f"Thanh toan phi tao lop {class_data.title}",
            extra_data={"class_id": new_class.id, "payment_type": "class_creation"},
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
    body: JoinClassPaymentRequest,
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
        booking.payment_method = body.provider
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
            payment_method=body.provider,
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
        provider=body.provider,
        amount=tuition,
        status="pending",
        transaction_ref=_generate_transaction_ref("TUI"),
    )

    try:
        provider_result = create_provider_payment_url(
            provider=body.provider,
            transaction_ref=payment.transaction_ref,
            amount=tuition,
            order_info=f"Thanh toan hoc phi lop {cls.title}",
            extra_data={"class_id": cls.id, "booking_id": booking.id, "payment_type": "tuition"},
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
    _: dict = Depends(auth_middleware),
):
    payment = db.query(Payment).filter(Payment.transaction_ref == transaction_ref).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Khong tim thay giao dich")

    cls = _get_class_or_404(db, payment.class_id) if payment.class_id else None
    booking = db.query(Booking).filter(Booking.id == payment.booking_id).first() if payment.booking_id else None
    return _serialize_transaction_status(payment, cls=cls, booking=booking)


@router.get("/mock/checkout/{transaction_ref}", response_class=HTMLResponse)
def mock_checkout_page(
    transaction_ref: str,
    provider: str,
    amount: int,
    orderInfo: str,
):
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
    return f"""
<!doctype html>
<html lang="vi">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" /></head>
<body style="font-family: Arial, sans-serif; padding: 24px; background: #f5f7fb;">
  <div style="max-width: 560px; margin: 40px auto; background: white; border-radius: 16px; padding: 24px; box-shadow: 0 10px 40px rgba(19, 35, 72, 0.12);">
    <h1 style="margin-top: 0;">{payment_result.message}</h1>
    <p>Ban co the quay lai app. Ung dung se tu dong poll va cap nhat trang thai.</p>
    <p><strong>Transaction:</strong> {payment_result.transaction_ref}</p>
    <p><strong>Status:</strong> {payment_result.status}</p>
  </div>
</body>
</html>
"""


@router.api_route("/providers/momo/return", methods=["GET", "POST"])
async def momo_return(
    request: Request,
    db: Session = Depends(get_db),
):
    payload = dict(request.query_params)
    if request.method == "POST":
        payload.update(await request.json())

    try:
        result = verify_provider_callback("momo", payload)
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return _process_payment_result(
        db=db,
        transaction_ref=result.transaction_ref,
        is_success=result.is_success,
        provider_transaction_id=result.provider_transaction_id,
        message=result.message,
        raw_payload=result.raw_payload,
    )


@router.post("/providers/momo/ipn")
async def momo_ipn(
    request: Request,
    db: Session = Depends(get_db),
):
    payload = await request.json()
    try:
        result = verify_provider_callback("momo", payload)
        _process_payment_result(
            db=db,
            transaction_ref=result.transaction_ref,
            is_success=result.is_success,
            provider_transaction_id=result.provider_transaction_id,
            message=result.message,
            raw_payload=result.raw_payload,
        )
    except HTTPException as exc:
        return {"resultCode": exc.status_code, "message": exc.detail}
    except PaymentGatewayError as exc:
        return {"resultCode": 400, "message": str(exc)}

    return {"resultCode": 0, "message": "Success"}


@router.get("/providers/vnpay/return")
async def vnpay_return(
    request: Request,
    db: Session = Depends(get_db),
):
    payload = dict(request.query_params)
    try:
        result = verify_provider_callback("vnpay", payload)
    except PaymentGatewayError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return _process_payment_result(
        db=db,
        transaction_ref=result.transaction_ref,
        is_success=result.is_success,
        provider_transaction_id=result.provider_transaction_id,
        message=result.message,
        raw_payload=result.raw_payload,
    )


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
    for booking, payment in booking_rows:
        _refund_booking(db, booking, payment, cls.cancellation_reason)

    cls.current_participants = 0
    cls.tutor_payout_status = "withheld"
    cls.tutor_payout_amount = Decimal("0")
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
            _refund_booking(db, booking, payment, body.note or "Admin xac nhan khieu nai hop le")
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
    db.commit()
    return _build_class_payment_summary(db, cls.id)


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
        current_participants=cls.current_participants,
        tutor_payout_status=cls.tutor_payout_status,
        tutor_payout_amount=cls.tutor_payout_amount,
        total_escrow_held=Decimal(total_escrow_held),
        active_disputes=_count_open_disputes(db, class_id),
    )


@router.get("/classes/{class_id}/summary", response_model=PaymentSummaryResponse)
def get_class_payment_summary(
    class_id: str,
    db: Session = Depends(get_db),
    _: dict = Depends(auth_middleware),
):
    return _build_class_payment_summary(db, class_id)


@router.get("/classes/by-code/{class_code}/summary", response_model=PaymentSummaryResponse)
def get_class_payment_summary_by_code(
    class_code: str,
    db: Session = Depends(get_db),
    _: dict = Depends(auth_middleware),
):
    normalized_code = class_code.strip().upper()
    if not normalized_code:
        raise HTTPException(status_code=400, detail="Ma lop khong hop le")

    classes = db.query(Class).all()
    for cls in classes:
        if _build_class_code(cls).upper() == normalized_code:
            return _build_class_payment_summary(db, cls.id)

    raise HTTPException(status_code=404, detail="Khong tim thay lop hoc voi ma nay")


@router.post("/jobs/cancel-underfilled-classes")
def cancel_underfilled_classes(
    db: Session = Depends(get_db),
):
    now = _now()
    deadline = now + timedelta(hours=4)
    classes = (
        db.query(Class)
        .filter(Class.status == "scheduled", Class.start_time <= deadline, Class.start_time > now)
        .all()
    )

    cancelled = []
    for cls in classes:
        if cls.current_participants >= cls.min_participants:
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
        for booking, payment in booking_rows:
            _refund_booking(db, booking, payment, cls.cancellation_reason)

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
        cancelled.append(cls.id)

    db.commit()
    return {"cancelled_class_ids": cancelled, "count": len(cancelled)}


@router.post("/jobs/release-eligible-payouts")
def release_eligible_payouts(
    db: Session = Depends(get_db),
):
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
        booking_rows = (
            db.query(Booking, Payment)
            .join(Payment, Payment.booking_id == Booking.id)
            .filter(Booking.class_id == cls.id, Booking.escrow_status == "held", Payment.payment_type == "tuition")
            .all()
        )
        if not booking_rows:
            if cls.status == "scheduled":
                cls.status = "completed"
            continue

        released_amount = Decimal("0")
        for booking, payment in booking_rows:
            booking.status = "completed"
            booking.escrow_status = "released"
            payment.status = "released"
            payment.released_at = now
            released_amount += Decimal(payment.amount)

        payout = Payment(
            id=str(uuid.uuid4()),
            class_id=cls.id,
            payer_user_id="system",
            payee_user_id=cls.teacher_id,
            booking_id=None,
            payment_type="payout",
            provider="system",
            amount=released_amount,
            status="released",
            transaction_ref=_generate_transaction_ref("OUT"),
            released_at=now,
        )
        db.add(payout)

        cls.status = "completed"
        cls.complaint_deadline = cls.end_time + timedelta(hours=2)
        cls.tutor_payout_status = "paid"
        cls.tutor_payout_amount = released_amount
        cls.tutor_paid_at = now
        released.append({"class_id": cls.id, "amount": str(released_amount)})

    db.commit()
    return {"released": released, "count": len(released)}
