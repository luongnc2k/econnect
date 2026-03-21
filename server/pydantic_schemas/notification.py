from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class NotificationResponse(BaseModel):
    id: str
    type: str
    title: str
    body: str
    data: dict[str, Any] = Field(default_factory=dict)
    is_read: bool
    created_at: datetime
    read_at: Optional[datetime] = None


class NotificationUnreadCountResponse(BaseModel):
    unread_count: int


class NotificationPageResponse(BaseModel):
    items: list[NotificationResponse] = Field(default_factory=list)
    next_cursor: Optional[str] = None
    has_more: bool = False


class PushTokenRegisterRequest(BaseModel):
    token: str = Field(min_length=16)
    platform: str = Field(default="unknown", min_length=2, max_length=20)
    device_label: Optional[str] = Field(default=None, max_length=120)


class PushTokenResponse(BaseModel):
    id: str
    platform: str
    device_label: Optional[str] = None
    is_active: bool
    last_seen_at: Optional[datetime] = None
    message: str


class PushTokenUnregisterRequest(BaseModel):
    token: str = Field(min_length=16)


class TutorTeachingConfirmationResponse(BaseModel):
    class_id: str
    tutor_confirmation_status: str
    minimum_participants_reached: bool
    tutor_confirmed_at: Optional[datetime] = None
    notified_students: int
    message: str
