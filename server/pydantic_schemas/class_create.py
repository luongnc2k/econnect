from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import Literal, Optional
from decimal import Decimal


class ClassCreate(BaseModel):
    topic_id: str
    title: str
    description: Optional[str] = None
    level: Literal['beginner', 'intermediate', 'advanced']
    location_name: str
    location_address: Optional[str] = None
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    start_time: datetime
    end_time: datetime
    max_participants: int
    price: Decimal
    thumbnail_url: Optional[str] = None

    @field_validator('max_participants')
    @classmethod
    def max_participants_positive(cls, v: int) -> int:
        if v < 1:
            raise ValueError('max_participants phải lớn hơn 0')
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
