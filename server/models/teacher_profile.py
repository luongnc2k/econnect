from sqlalchemy import Boolean, Column, DateTime, Integer, Numeric, SmallInteger, TEXT, VARCHAR
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func
from models.base import Base


class TeacherProfile(Base):
    __tablename__ = "teacher_profiles"

    user_id = Column(TEXT, primary_key=True)
    bio = Column(TEXT, nullable=True)
    nationality = Column(VARCHAR(50), nullable=True)
    native_language = Column(VARCHAR(50), nullable=True)
    bank_name = Column(VARCHAR(100), nullable=True)
    bank_account_number = Column(VARCHAR(50), nullable=True)
    bank_account_holder = Column(VARCHAR(100), nullable=True)
    certifications = Column(ARRAY(TEXT), nullable=True)
    years_experience = Column(SmallInteger, nullable=True)
    rating_avg = Column(Numeric(2, 1), default=0.0, nullable=False)
    total_sessions = Column(Integer, default=0, nullable=False)
    total_reviews = Column(Integer, default=0, nullable=False)
    is_verified = Column(Boolean, default=False, nullable=False)
    verification_docs = Column(ARRAY(TEXT), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
