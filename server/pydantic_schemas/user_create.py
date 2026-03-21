from pydantic import BaseModel, field_validator
from typing import Literal


class UserCreate(BaseModel):
    full_name: str
    email: str
    password: str
    role: Literal['student', 'teacher']

    @field_validator("full_name")
    @classmethod
    def full_name_not_blank(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 2:
            raise ValueError("full_name phai co it nhat 2 ky tu")
        return normalized

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str) -> str:
        normalized = value.strip().lower()
        if "@" not in normalized or "." not in normalized.split("@")[-1]:
            raise ValueError("email khong hop le")
        return normalized

    @field_validator("password")
    @classmethod
    def password_min_length(cls, value: str) -> str:
        if len(value) < 8:
            raise ValueError("password phai co it nhat 8 ky tu")
        return value
