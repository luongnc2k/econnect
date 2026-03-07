from pydantic import BaseModel
from datetime import datetime
from typing import Optional
from decimal import Decimal


class TopicBrief(BaseModel):
    id: str
    name: str
    slug: str
    icon: Optional[str] = None

    class Config:
        from_attributes = True


class TeacherBrief(BaseModel):
    id: str
    full_name: str
    avatar_url: Optional[str] = None
    rating_avg: Optional[Decimal] = None
    total_sessions: Optional[int] = None

    class Config:
        from_attributes = True


class ClassResponse(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    level: str
    location_name: str
    location_address: Optional[str] = None
    start_time: datetime
    end_time: datetime
    max_participants: int
    current_participants: int
    price: Decimal
    thumbnail_url: Optional[str] = None
    status: str
    topic: TopicBrief
    teacher: TeacherBrief

    class Config:
        from_attributes = True
