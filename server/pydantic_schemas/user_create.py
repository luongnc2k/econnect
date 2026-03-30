import re
import unicodedata
from typing import Literal, Optional

from pydantic import BaseModel, field_validator


def _normalize_optional_string(value: object) -> Optional[str]:
    if value is None:
        return None
    normalized = str(value).strip()
    return normalized or None


def _normalize_bank_account_holder(value: object) -> Optional[str]:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None

    no_accent = unicodedata.normalize("NFD", normalized)
    no_accent = "".join(
        char for char in no_accent if unicodedata.category(char) != "Mn"
    )
    no_accent = no_accent.replace("đ", "d").replace("Đ", "D")
    collapsed = re.sub(r"\s+", " ", no_accent).strip()
    return collapsed.upper() or None


class UserCreate(BaseModel):
    full_name: str
    email: str
    password: str
    role: Literal['student', 'teacher']
    bank_name: Optional[str] = None
    bank_bin: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_account_holder: Optional[str] = None

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

    @field_validator(
        "bank_name",
        "bank_bin",
        "bank_account_number",
        mode="before",
    )
    @classmethod
    def normalize_bank_fields(cls, value: object) -> Optional[str]:
        return _normalize_optional_string(value)

    @field_validator("bank_account_holder", mode="before")
    @classmethod
    def normalize_bank_account_holder(cls, value: object) -> Optional[str]:
        return _normalize_bank_account_holder(value)

    @field_validator("bank_bin")
    @classmethod
    def validate_bank_bin(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        if not value.isdigit():
            raise ValueError("bank_bin chi duoc chua chu so")
        if len(value) < 3 or len(value) > 20:
            raise ValueError("bank_bin phai dai tu 3 den 20 chu so")
        return value
