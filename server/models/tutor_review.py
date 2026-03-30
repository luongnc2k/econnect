from sqlalchemy import Column, DateTime, ForeignKey, SmallInteger, TEXT, UniqueConstraint
from sqlalchemy.sql import func

from models.base import Base


class TutorReview(Base):
    __tablename__ = "tutor_reviews"

    id = Column(TEXT, primary_key=True)
    class_id = Column(TEXT, ForeignKey("classes.id"), nullable=False)
    booking_id = Column(TEXT, ForeignKey("bookings.id"), nullable=False, unique=True)
    teacher_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    student_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    rating = Column(SmallInteger, nullable=False)
    comment = Column(TEXT, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("class_id", "student_id", name="uq_tutor_reviews_class_student"),
    )
