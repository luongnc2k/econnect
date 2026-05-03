from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from typing import Literal, Optional

from pydantic import BaseModel, field_validator

from pydantic_schemas.class_create import ClassCreate


def calculate_creation_fee(session_price: Decimal) -> Decimal:
    return (session_price * Decimal("0.10")).quantize(Decimal("1"), rounding=ROUND_HALF_UP)


def calculate_student_tuition(session_price: Decimal, max_participants: int) -> Decimal:
    return (session_price / Decimal(max_participants)).quantize(
        Decimal("1"),
        rounding=ROUND_HALF_UP,
    )


class CreateClassPaymentRequest(BaseModel):
    class_payload: ClassCreate


class JoinClassPaymentRequest(BaseModel):
    pass


class PaymentCallbackRequest(BaseModel):
    transaction_ref: str
    status: Literal["success", "failed"]
    provider_transaction_id: Optional[str] = None
    failure_reason: Optional[str] = None


class CancelClassRequest(BaseModel):
    reason: Optional[str] = None


class ComplaintRequest(BaseModel):
    reason: str

    @field_validator("reason")
    @classmethod
    def reason_not_blank(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("reason khong duoc de trong")
        return normalized


class ResolveComplaintRequest(BaseModel):
    booking_id: str
    is_valid: bool
    note: Optional[str] = None


class ConfirmPayOSWebhookRequest(BaseModel):
    webhook_url: Optional[str] = None

    @field_validator("webhook_url")
    @classmethod
    def normalize_webhook_url(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class ConfirmPayOSWebhookResponse(BaseModel):
    webhook_url: str
    account_name: str
    account_number: str
    name: str
    short_name: str


class PayOSPayoutBalanceResponse(BaseModel):
    account_number: str
    account_name: str
    currency: str
    balance: Decimal


class PaymentResponse(BaseModel):
    payment_id: str
    transaction_ref: str
    provider: str
    payment_type: str
    amount: Decimal
    status: str
    redirect_url: Optional[str] = None
    class_id: Optional[str] = None
    booking_id: Optional[str] = None
    class_status: Optional[str] = None
    booking_status: Optional[str] = None
    escrow_status: Optional[str] = None
    message: Optional[str] = None
    paid_at: Optional[datetime] = None


class PaymentSummaryResponse(BaseModel):
    class_id: str
    class_status: str
    creation_payment_status: str
    creation_fee_amount: Decimal
    min_participants: int
    max_participants: int
    current_participants: int
    minimum_participants_reached: bool
    tutor_confirmation_status: str
    tutor_confirmed_at: Optional[datetime] = None
    tutor_payout_status: str
    tutor_payout_amount: Decimal
    total_escrow_held: Decimal
    active_disputes: int


class PaymentTransactionStatusResponse(BaseModel):
    payment_id: str
    transaction_ref: str
    payment_type: str
    provider: str
    status: str
    amount: Decimal
    redirect_url: Optional[str] = None
    booking_id: Optional[str] = None
    class_id: Optional[str] = None
    booking_status: Optional[str] = None
    escrow_status: Optional[str] = None
    class_status: Optional[str] = None
    message: Optional[str] = None
    paid_at: Optional[datetime] = None
