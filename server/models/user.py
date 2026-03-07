from sqlalchemy import Boolean, Column, DateTime, LargeBinary, TEXT, VARCHAR
from sqlalchemy.sql import func

from models.base import Base


class User(Base):
    __tablename__ = "users"

    id = Column(TEXT, primary_key=True)
    email = Column(VARCHAR(255), unique=True, index=True, nullable=False)
    password_hash = Column(LargeBinary, nullable=False)
    full_name = Column(VARCHAR(100), nullable=False)
    phone = Column(VARCHAR(20), nullable=True)
    avatar_url = Column(TEXT, nullable=True)
    role = Column(VARCHAR(20), nullable=False)  # 'student' | 'teacher' | 'admin'
    is_active = Column(Boolean, default=True, nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
