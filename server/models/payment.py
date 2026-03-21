from sqlalchemy import Column, DateTime, Numeric, TEXT, ForeignKey
from sqlalchemy.sql import func

from models.base import Base


class Payment(Base):
    __tablename__ = "payments"

    id = Column(TEXT, primary_key=True)
    booking_id = Column(TEXT, ForeignKey("bookings.id"), nullable=True)
    class_id = Column(TEXT, ForeignKey("classes.id"), nullable=True)
    payer_user_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    payee_user_id = Column(TEXT, ForeignKey("users.id"), nullable=True)
    payment_type = Column(TEXT, nullable=False)  # class_creation | tuition | refund | payout
    provider = Column(TEXT, nullable=False)  # payos | system
    method = Column(TEXT, nullable=True)
    amount = Column(Numeric(10, 0), nullable=False)
    currency = Column(TEXT, default="VND", nullable=False)
    status = Column(TEXT, default="pending", nullable=False)  # pending | processing | paid | refunded | failed | released | disputed | cancelled
    transaction_ref = Column(TEXT, unique=True, nullable=False)
    provider_order_id = Column(TEXT, nullable=True)
    provider_payload = Column(TEXT, nullable=True)
    redirect_url = Column(TEXT, nullable=True)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    refunded_at = Column(DateTime(timezone=True), nullable=True)
    released_at = Column(DateTime(timezone=True), nullable=True)
    failure_reason = Column(TEXT, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
