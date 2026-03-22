from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Literal, Optional
from decimal import Decimal


class ClassCreate(BaseModel):
    topic: str = Field(min_length=1, max_length=100)
    title: str = Field(min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=300)
    level: Literal['beginner', 'intermediate', 'advanced']
    location_id: str = Field(min_length=1)
    start_time: datetime
    end_time: datetime
    min_participants: int = 1
    max_participants: int
    price: Decimal
    thumbnail_url: Optional[str] = None

    @field_validator('min_participants')
    @classmethod
    def min_participants_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError('min_participants phải lớn hơn 0')
        return v

    @field_validator('max_participants')
    @classmethod
    def max_participants_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError('max_participants phải lớn hơn 0')
        return v

    @field_validator('max_participants')
    @classmethod
    def max_gte_min(cls, v: int, info) -> int:
        min_p = info.data.get('min_participants', 1)
        if v < min_p:
            raise ValueError('max_participants phải >= min_participants')
        return v

    @field_validator('price')
    @classmethod
    def price_non_negative(cls, v: Decimal) -> Decimal:
        if v < 0:
            raise ValueError('price không được âm')
        return v

    @field_validator('end_time')
    @classmethod
    def end_after_start(cls, v: datetime, info) -> datetime:
        start = info.data.get('start_time')
        if start and v <= start:
            raise ValueError('end_time phải sau start_time')
        return v
    @field_validator('topic', 'title', 'location_id', mode='before')
    @classmethod
    def required_text_not_blank(cls, value: object) -> str:
        if value is None:
            raise ValueError('truong bat buoc')
        normalized = str(value).strip()
        if not normalized:
            raise ValueError('khong duoc de trong')
        return normalized

    @field_validator('description', 'thumbnail_url', mode='before')
    @classmethod
    def optional_text_trimmed(cls, value: object) -> Optional[str]:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None
