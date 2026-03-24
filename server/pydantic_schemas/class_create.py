from datetime import datetime, timezone
from decimal import Decimal
from typing import Literal, Optional

from pydantic import BaseModel, Field, field_validator


class ClassCreate(BaseModel):
    topic: str = Field(min_length=1, max_length=100)
    title: str = Field(min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=300)
    level: Literal["beginner", "intermediate", "advanced"]
    location_id: str = Field(min_length=1)
    start_time: datetime
    end_time: datetime
    min_participants: int = 1
    max_participants: int
    price: Decimal
    thumbnail_url: Optional[str] = None

    @field_validator("min_participants")
    @classmethod
    def min_participants_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError("min_participants phai lon hon 0")
        return v

    @field_validator("max_participants")
    @classmethod
    def max_participants_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError("max_participants phai lon hon 0")
        return v

    @field_validator("max_participants")
    @classmethod
    def max_gte_min(cls, v: int, info) -> int:
        min_p = info.data.get("min_participants", 1)
        if v < min_p:
            raise ValueError("max_participants phai >= min_participants")
        return v

    @field_validator("price")
    @classmethod
    def price_non_negative(cls, v: Decimal) -> Decimal:
        if v < 0:
            raise ValueError("price khong duoc am")
        return v

    @field_validator("start_time")
    @classmethod
    def start_after_now(cls, v: datetime) -> datetime:
        normalized = (
            v.astimezone(timezone.utc) if v.tzinfo else v.replace(tzinfo=timezone.utc)
        )
        if normalized <= datetime.now(timezone.utc):
            raise ValueError("start_time phai sau thoi diem hien tai")
        return v

    @field_validator("end_time")
    @classmethod
    def end_after_start(cls, v: datetime, info) -> datetime:
        start = info.data.get("start_time")
        if start and v <= start:
            raise ValueError("end_time phai sau start_time")
        return v

    @field_validator("topic", "title", "location_id", mode="before")
    @classmethod
    def required_text_not_blank(cls, value: object) -> str:
        if value is None:
            raise ValueError("truong bat buoc")
        normalized = str(value).strip()
        if not normalized:
            raise ValueError("khong duoc de trong")
        return normalized

    @field_validator("description", "thumbnail_url", mode="before")
    @classmethod
    def optional_text_trimmed(cls, value: object) -> Optional[str]:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None
