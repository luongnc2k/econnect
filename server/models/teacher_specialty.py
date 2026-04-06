from sqlalchemy import Column, TEXT, ForeignKey
from models.base import Base


class TeacherSpecialty(Base):
    __tablename__ = "teacher_specialties"

    teacher_id = Column(TEXT, ForeignKey("users.id"), primary_key=True)
    topic_id = Column(TEXT, ForeignKey("topics.id"), primary_key=True)
