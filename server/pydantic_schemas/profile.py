import re
import unicodedata
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator


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


def _normalize_string_list(value: object) -> Optional[list[str]]:
    if value is None:
        return None
    if isinstance(value, str):
        items = value.split(",")
    elif isinstance(value, list):
        items = value
    else:
        raise ValueError("Gia tri danh sach khong hop le")

    normalized_items = [str(item).strip() for item in items if str(item).strip()]
    return normalized_items


_ENGLISH_LEVEL_ALIASES = {
    "a1": "beginner",
    "a2": "beginner",
    "beginner": "beginner",
    "elementary": "beginner",
    "b1": "intermediate",
    "b2": "intermediate",
    "intermediate": "intermediate",
    "upper-intermediate": "intermediate",
    "upper intermediate": "intermediate",
    "c1": "advanced",
    "c2": "advanced",
    "advanced": "advanced",
    "proficient": "advanced",
}


def _normalize_english_level(value: object) -> Optional[str]:
    normalized = _normalize_optional_string(value)
    if normalized is None:
        return None

    canonical = _ENGLISH_LEVEL_ALIASES.get(normalized.lower())
    if canonical is None:
        raise ValueError(
            "english_level phai la beginner, intermediate, advanced hoac muc CEFR tuong ung"
        )
    return canonical


class ProfileUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    full_name: Optional[str] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None

    english_level: Optional[str] = None
    learning_goal: Optional[str] = None

    bio: Optional[str] = None
    years_of_experience: Optional[int] = None
    specialization: Optional[str] = None
    bank_name: Optional[str] = None
    bank_bin: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_account_holder: Optional[str] = None
    certifications: Optional[list[str]] = None
    verification_docs: Optional[list[str]] = None

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, value: Optional[str]) -> Optional[str]:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("full_name khong duoc de trong")
        if len(normalized) < 2:
            raise ValueError("full_name phai co it nhat 2 ky tu")
        return normalized

    @field_validator(
        "phone",
        "avatar_url",
        "learning_goal",
        "bio",
        "specialization",
        "bank_name",
        "bank_bin",
        "bank_account_number",
        mode="before",
    )
    @classmethod
    def normalize_optional_strings(cls, value: object) -> Optional[str]:
        return _normalize_optional_string(value)

    @field_validator("bank_account_holder", mode="before")
    @classmethod
    def normalize_bank_account_holder(cls, value: object) -> Optional[str]:
        return _normalize_bank_account_holder(value)

    @field_validator("english_level", mode="before")
    @classmethod
    def normalize_english_level(cls, value: object) -> Optional[str]:
        return _normalize_english_level(value)

    @field_validator("years_of_experience", mode="before")
    @classmethod
    def normalize_years_of_experience(cls, value: object) -> Optional[int]:
        if value is None:
            return None
        if isinstance(value, str):
            normalized = value.strip()
            if not normalized:
                return None
            value = normalized

        try:
            years = int(value)
        except (TypeError, ValueError) as exc:
            raise ValueError("years_of_experience khong hop le") from exc

        if years < 0 or years > 80:
            raise ValueError("years_of_experience phai nam trong khoang 0-80")

        return years

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

    @field_validator("certifications", "verification_docs", mode="before")
    @classmethod
    def normalize_string_lists(cls, value: object) -> Optional[list[str]]:
        return _normalize_string_list(value)


class PayoutBankAccountVerificationRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    bank_bin: str
    bank_account_number: str

    @field_validator("bank_bin", "bank_account_number", mode="before")
    @classmethod
    def normalize_required_strings(cls, value: object) -> str:
        normalized = _normalize_optional_string(value)
        if normalized is None:
            raise ValueError("Gia tri khong duoc de trong")
        return normalized

    @field_validator("bank_bin")
    @classmethod
    def validate_required_bank_bin(cls, value: str) -> str:
        if not value.isdigit():
            raise ValueError("bank_bin chi duoc chua chu so")
        if len(value) < 3 or len(value) > 20:
            raise ValueError("bank_bin phai dai tu 3 den 20 chu so")
        return value

    @field_validator("bank_account_number")
    @classmethod
    def validate_bank_account_number(cls, value: str) -> str:
        if not value.isdigit():
            raise ValueError("bank_account_number chi duoc chua chu so")
        if len(value) < 6 or len(value) > 30:
            raise ValueError("bank_account_number phai dai tu 6 den 30 chu so")
        return value


class PayoutBankAccountVerificationResponse(BaseModel):
    provider: str
    is_valid: bool
    message: str
    estimate_credit: Optional[int] = None


class FeaturedTeacherResponse(BaseModel):
    id: str
    full_name: str
    avatar_url: Optional[str] = None
    specialization: Optional[str] = None
    rating: float = 0.0
    total_sessions: int = 0
    total_reviews: int = 0
