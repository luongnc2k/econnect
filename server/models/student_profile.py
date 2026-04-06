from sqlalchemy import Column, DateTime, Integer, TEXT
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.sql import func
from models.base import Base


class StudentProfile(Base):
    __tablename__ = "student_profiles"

    user_id = Column(TEXT, primary_key=True)
    english_level = Column(TEXT, nullable=True)  # beginner | intermediate | advanced
    learning_goals = Column(ARRAY(TEXT), nullable=True)
    bio = Column(TEXT, nullable=True)
    total_classes_attended = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
