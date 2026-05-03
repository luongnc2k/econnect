from sqlalchemy import Boolean, Column, DateTime, ForeignKey, TEXT, VARCHAR
from sqlalchemy.sql import func

from models.base import Base


class PushDeviceToken(Base):
    __tablename__ = "push_device_tokens"

    id = Column(TEXT, primary_key=True)
    user_id = Column(TEXT, ForeignKey("users.id"), nullable=False, index=True)
    token = Column(TEXT, nullable=False, unique=True)
    platform = Column(VARCHAR(20), nullable=False, default="unknown")
    device_label = Column(VARCHAR(120), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    last_seen_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
