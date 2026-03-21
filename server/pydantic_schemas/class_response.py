from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional
from decimal import Decimal


class TopicBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    slug: str
    icon: Optional[str] = None


class TeacherBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    avatar_url: Optional[str] = None
    rating_avg: Optional[Decimal] = None
    total_sessions: Optional[int] = None


class ClassResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    class_code: str
    title: str
    description: Optional[str] = None
    level: str
    location_name: str
    location_address: Optional[str] = None
    start_time: datetime
    end_time: datetime
    min_participants: int
    max_participants: int
    current_participants: int
    minimum_participants_reached: bool = False
    tutor_confirmation_status: str = "waiting_minimum"
    tutor_confirmed_at: Optional[datetime] = None
    price: Decimal
    thumbnail_url: Optional[str] = None
    status: str
    topic: TopicBrief
    teacher: TeacherBrief
