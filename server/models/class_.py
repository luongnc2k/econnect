from sqlalchemy import Boolean, Column, DateTime, Numeric, SmallInteger, TEXT, VARCHAR, ForeignKey
from sqlalchemy.sql import func
from models.base import Base


class Class(Base):
    __tablename__ = "classes"

    id = Column(TEXT, primary_key=True)
    teacher_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    topic_id = Column(TEXT, ForeignKey("topics.id"), nullable=False)
    topic = Column(VARCHAR(100), nullable=False, default="")
    title = Column(VARCHAR(200), nullable=False)
    description = Column(TEXT, nullable=True)
    level = Column(TEXT, nullable=False)  # beginner | intermediate | advanced
    location_name = Column(VARCHAR(200), nullable=False)
    location_address = Column(TEXT, nullable=True)
    location_notes = Column(TEXT, nullable=True)
    latitude = Column(Numeric(10, 8), nullable=True)
    longitude = Column(Numeric(10, 7), nullable=True)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=False)
    min_participants = Column(SmallInteger, default=1, nullable=False)
    max_participants = Column(SmallInteger, nullable=False)
    current_participants = Column(SmallInteger, default=0, nullable=False)
    price = Column(Numeric(10, 0), nullable=False)
    creation_fee_amount = Column(Numeric(10, 0), nullable=False)
    creation_payment_status = Column(
        TEXT,
        default="unpaid",
        nullable=False,
    )  # unpaid | pending | paid | refund_processing | refunded | refund_failed
    creation_payment_reference = Column(TEXT, nullable=True)
    creation_paid_at = Column(DateTime(timezone=True), nullable=True)
    thumbnail_url = Column(TEXT, nullable=True)
    status = Column(TEXT, default="draft", nullable=False)  # draft | scheduled | ongoing | completed | cancelled
    cancellation_reason = Column(TEXT, nullable=True)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    tutor_payout_status = Column(TEXT, default="pending", nullable=False)  # pending | processing | on_hold | paid | withheld | failed
    tutor_payout_amount = Column(Numeric(10, 0), default=0, nullable=False)
    tutor_paid_at = Column(DateTime(timezone=True), nullable=True)
    complaint_deadline = Column(DateTime(timezone=True), nullable=True)
    has_active_dispute = Column(Boolean, default=False, nullable=False)
    minimum_participants_reached = Column(Boolean, default=False, nullable=False)
    minimum_participants_reached_at = Column(DateTime(timezone=True), nullable=True)
    tutor_confirmation_status = Column(TEXT, default="waiting_minimum", nullable=False)  # waiting_minimum | pending | confirmed
    tutor_confirmed_at = Column(DateTime(timezone=True), nullable=True)
    starting_soon_notified_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
