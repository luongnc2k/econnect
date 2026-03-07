from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
import uuid
import os

from database import get_db
from models.profile_model import Profile
from pydantic_schemas.profile_schema import (
    ProfileCreate,
    ProfileUpdate,
    ProfileResponse
)

router = APIRouter(prefix="/profiles", tags=["profiles"])

# Create a new profile
@router.post("/", response_model=ProfileResponse)
def create_profile(profile: ProfileCreate, db: Session = Depends(get_db)):

    new_profile = Profile(
        full_name=profile.full_name,
        dob=profile.dob,
        education=profile.education,
        job=profile.job,
        nationality=profile.nationality,
        bio=profile.bio,
        role=profile.role,
    )

    db.add(new_profile)
    db.commit()
    db.refresh(new_profile)

    return new_profile

# Get my profile
@router.get("/me", response_model=ProfileResponse)
def get_my_profile(user_id: str, db: Session = Depends(get_db)):

    profile = db.query(Profile).filter(
        Profile.user_id == user_id # Ở production user_id sẽ lấy từ JWT middleware
    ).first()

    if not profile:
        raise HTTPException(404, "Profile not found")

    return profile

# Update my profile
@router.put("/me", response_model=ProfileResponse)
def update_profile(
    data: ProfileUpdate,
    user_id: str,
    db: Session = Depends(get_db)
):

    profile = db.query(Profile).filter(
        Profile.user_id == user_id
    ).first()

    if not profile:
        raise HTTPException(404, "Profile not found")

    for key, value in data.dict(exclude_unset=True).items():
        setattr(profile, key, value)

    db.commit()
    db.refresh(profile)

    return profile

# GEt profile by id (public profile)
@router.get("/{profile_id}", response_model=ProfileResponse)
def get_profile(profile_id: str, db: Session = Depends(get_db)):
    profile = db.query(Profile).filter(
        Profile.id == profile_id
    ).first()

    if not profile:
        raise HTTPException(404, "Profile not found")

    return profile

# Get tutors list
@router.get("/tutors/list")
def get_tutors(db: Session = Depends(get_db)):

    tutors = db.query(Profile).filter(
        Profile.role == "tutor"
    ).all()

    return tutors

# Upload avatar
UPLOAD_FOLDER = "uploads/avatars"

@router.post("/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    user_id: str = "test_user",  # sau này lấy từ JWT
    db: Session = Depends(get_db)
):

    if not os.path.exists(UPLOAD_FOLDER):
        os.makedirs(UPLOAD_FOLDER)

    file_extension = file.filename.split(".")[-1]
    filename = f"{uuid.uuid4()}.{file_extension}"

    file_path = os.path.join(UPLOAD_FOLDER, filename)

    with open(file_path, "wb") as buffer:
        buffer.write(await file.read())

    avatar_url = f"/uploads/avatars/{filename}"

    profile = db.query(Profile).filter(
        Profile.user_id == user_id
    ).first()

    if profile:
        profile.avatar_url = avatar_url
        db.commit()

    return {
        "message": "Avatar uploaded",
        "avatar_url": avatar_url
    }