from pydantic import BaseModel
from typing import Optional
from datetime import date


class ProfileCreate(BaseModel):
    full_name: str
    dob: date
    education: str
    job: str
    nationality: str
    role: str
    bio: Optional[str] = None


class ProfileUpdate(BaseModel):
    full_name: Optional[str]
    education: Optional[str]
    job: Optional[str]
    nationality: Optional[str]
    bio: Optional[str]


class ProfileResponse(BaseModel):
    id: str
    full_name: str
    education: str
    job: str
    nationality: str
    role: str

    class Config:
        from_attributes = True

class AvatarUploadResponse(BaseModel):
    avatar_url: str

