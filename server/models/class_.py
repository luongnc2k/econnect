from sqlalchemy import Column, DateTime, Numeric, SmallInteger, TEXT, VARCHAR, ForeignKey
from sqlalchemy.sql import func
from models.base import Base


class Class(Base):
    __tablename__ = "classes"

    id = Column(TEXT, primary_key=True)
    teacher_id = Column(TEXT, ForeignKey("users.id"), nullable=False)
    topic_id = Column(TEXT, ForeignKey("topics.id"), nullable=False)
    title = Column(VARCHAR(200), nullable=False)
    description = Column(TEXT, nullable=True)
    level = Column(TEXT, nullable=False)  # beginner | intermediate | advanced
    location_name = Column(VARCHAR(200), nullable=False)
    location_address = Column(TEXT, nullable=True)
    latitude = Column(Numeric(10, 8), nullable=True)
    longitude = Column(Numeric(10, 7), nullable=True)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=False)
    min_participants = Column(SmallInteger, default=1, nullable=False)
    max_participants = Column(SmallInteger, nullable=False)
    current_participants = Column(SmallInteger, default=0, nullable=False)
    price = Column(Numeric(10, 0), nullable=False)
    thumbnail_url = Column(TEXT, nullable=True)
    status = Column(TEXT, default="scheduled", nullable=False)  # scheduled | ongoing | completed | cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
