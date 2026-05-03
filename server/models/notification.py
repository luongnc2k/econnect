from sqlalchemy import Boolean, Column, DateTime, ForeignKey, TEXT
from sqlalchemy.sql import func

from models.base import Base


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(TEXT, primary_key=True)
    user_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    type = Column(TEXT, nullable=False)
    title = Column(TEXT, nullable=False)
    body = Column(TEXT, nullable=False)
    data = Column(TEXT, nullable=True)
    is_read = Column(Boolean, default=False, nullable=False)
    read_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
