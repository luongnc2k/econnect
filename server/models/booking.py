from sqlalchemy import Column, DateTime, Numeric, TEXT, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from models.base import Base


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(TEXT, primary_key=True)
    class_id = Column(TEXT, ForeignKey("classes.id"), nullable=False)
    student_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    status = Column(TEXT, default="payment_pending", nullable=False)  # payment_pending | confirmed | completed | cancelled | refunded | no_show
    payment_status = Column(TEXT, default="pending", nullable=False)  # pending | paid | refunded | failed
    payment_reference = Column(TEXT, nullable=True)
    payment_method = Column(TEXT, nullable=True)
    tuition_amount = Column(Numeric(10, 0), nullable=False)
    escrow_status = Column(TEXT, default="pending", nullable=False)  # pending | held | released | refunded | disputed
    escrow_held_at = Column(DateTime(timezone=True), nullable=True)
    complaint_status = Column(TEXT, default="none", nullable=False)  # none | open | resolved_valid | resolved_rejected
    complaint_reason = Column(TEXT, nullable=True)
    complaint_opened_at = Column(DateTime(timezone=True), nullable=True)
    booked_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    cancel_reason = Column(TEXT, nullable=True)

    __table_args__ = (
        UniqueConstraint("class_id", "student_id", name="uq_booking_class_student"),
    )
