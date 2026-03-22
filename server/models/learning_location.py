from sqlalchemy import Boolean, Column, DateTime, Numeric, TEXT, VARCHAR
from sqlalchemy.sql import func

from models.base import Base


class LearningLocation(Base):
    __tablename__ = "learning_locations"

    id = Column(TEXT, primary_key=True)
    name = Column(VARCHAR(150), nullable=False)
    address = Column(TEXT, nullable=False)
    latitude = Column(Numeric(10, 8), nullable=True)
    longitude = Column(Numeric(10, 7), nullable=True)
    notes = Column(TEXT, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
