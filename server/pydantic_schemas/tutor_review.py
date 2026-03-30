import re
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator


def _normalize_optional_comment(value: object) -> Optional[str]:
    if value is None:
        return None
    normalized = str(value).strip()
    return normalized or None


def _word_count(value: str) -> int:
    return len(re.findall(r"\S+", value))


class TutorReviewRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    rating: int = Field(ge=0, le=5)
    comment: Optional[str] = None

    @field_validator("comment", mode="before")
    @classmethod
    def normalize_comment(cls, value: object) -> Optional[str]:
        return _normalize_optional_comment(value)

    @field_validator("comment")
    @classmethod
    def validate_comment_length(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        if _word_count(value) > 100:
            raise ValueError("comment khong duoc vuot qua 100 tu")
        return value


class TutorReviewResponse(BaseModel):
    id: str
    class_id: str
    booking_id: str
    teacher_id: str
    student_id: str
    rating: int
    comment: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class StudentTutorReviewStatusResponse(BaseModel):
    class_id: str
    can_review: bool = False
    already_reviewed: bool = False
    hotline: str
    reason: Optional[str] = None
    review: Optional[TutorReviewResponse] = None
