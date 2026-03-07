from sqlalchemy import Column, String, Date, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from fastapi import UploadFile, File   
import os
import uuid

from models.base import Base

class Profile(Base):
    __tablename__ = "profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    user_id = Column(UUID(as_uuid=True), unique=True)

    full_name = Column(String(100))
    dob = Column(Date)

    education = Column(String(255))
    job = Column(String(255))
    nationality = Column(String(100))

    bio = Column(Text)
    avatar_url = Column(String)

    role = Column(String)  # student | tutor

    certificates = Column(Text)
    degrees = Column(Text)

    experience_years = Column(Integer)