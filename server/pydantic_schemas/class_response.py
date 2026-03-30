from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class TeacherBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    avatar_url: Optional[str] = None
    rating_avg: Optional[Decimal] = None
    total_sessions: Optional[int] = None
    total_reviews: Optional[int] = None


class ClassResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    class_code: str
    title: str
    description: Optional[str] = None
    level: str
    location_name: str
    location_address: Optional[str] = None
    location_notes: Optional[str] = None
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
    topic: str
    teacher: TeacherBrief


class EnrolledStudentBrief(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    full_name: str
    avatar_url: Optional[str] = None
    status: str
    booked_at: datetime


class ClassDetailResponse(ClassResponse):
    enrolled_students: list[EnrolledStudentBrief] = Field(default_factory=list)


class StudentClassBookingStatusResponse(BaseModel):
    class_id: str
    has_booking: bool = False
    is_registered: bool = False
    booking_id: Optional[str] = None
    booking_status: Optional[str] = None
    payment_status: Optional[str] = None
    escrow_status: Optional[str] = None
    payment_reference: Optional[str] = None
    tuition_amount: Optional[Decimal] = None
    booked_at: Optional[datetime] = None
