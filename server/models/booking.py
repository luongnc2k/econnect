from sqlalchemy import Column, DateTime, TEXT, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from models.base import Base


class Booking(Base):
    __tablename__ = "bookings"

    id = Column(TEXT, primary_key=True)
    class_id = Column(TEXT, ForeignKey("classes.id"), nullable=False)
    student_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    status = Column(TEXT, default="pending", nullable=False)  # pending | confirmed | completed | cancelled | no_show
    booked_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    cancel_reason = Column(TEXT, nullable=True)

    __table_args__ = (
        UniqueConstraint("class_id", "student_id", name="uq_booking_class_student"),
    )
