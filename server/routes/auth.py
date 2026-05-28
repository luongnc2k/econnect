import os
from datetime import datetime, timezone
from datetime import timedelta
from typing import Literal, Optional

import httpx
from fastapi import Depends, Header, HTTPException
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session
from pydantic_schemas.user_create import AdminUserCreate, UserCreate
from pydantic_schemas.user_login import UserLogin
from pydantic_schemas.user_response import LoginResponse, UserResponse
from models.student_profile import StudentProfile
from models.teacher_profile import TeacherProfile
from models.user import User
from database import get_db
from fastapi import APIRouter
import uuid
import bcrypt
import jwt

from middleware.auth_middleware import auth_middleware

ADMIN_CREATE_SECRET = os.getenv("ADMIN_CREATE_SECRET", "")
JWT_SECRET = os.getenv("JWT_SECRET", "dev_jwt_secret_change_me_please_32bytes")
GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"


def _allowed_google_audiences() -> set[str]:
    raw = os.getenv("GOOGLE_OAUTH_CLIENT_IDS", "") or ""
    return {item.strip() for item in raw.split(",") if item.strip()}


router = APIRouter()


def _jwt_exp_minutes() -> int:
    raw_value = (os.getenv("JWT_EXPIRE_MINUTES", "10080") or "10080").strip()
    try:
        return max(5, int(raw_value))
    except ValueError:
        return 10080


def _create_access_token(user: User) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "id": user.id,
        "role": user.role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=_jwt_exp_minutes())).timestamp()),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


@router.post("/signup", response_model=UserResponse, status_code=201)
def signup_user(user: UserCreate, db: Session = Depends(get_db)):
    user_db = db.query(User).filter(User.email == user.email).first()
    if user_db:
        raise HTTPException(status_code=400, detail="User with the same email already exists!")

    hashed_pw = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt())
    new_user = User(
        id=str(uuid.uuid4()),
        email=user.email,
        password_hash=hashed_pw,
        full_name=user.full_name,
        role=user.role,
        is_active=True,
    )

    db.add(new_user)
    db.flush()

    if user.role == "teacher":
        teacher_profile = TeacherProfile(
            user_id=new_user.id,
            bank_name=user.bank_name,
            bank_bin=user.bank_bin,
            bank_account_number=user.bank_account_number,
            bank_account_holder=user.bank_account_holder,
        )
        db.add(teacher_profile)
    elif user.role == "student":
        student_profile = StudentProfile(
            user_id=new_user.id,
            bank_name=user.bank_name,
            bank_bin=user.bank_bin,
            bank_account_number=user.bank_account_number,
            bank_account_holder=user.bank_account_holder,
        )
        db.add(student_profile)

    db.commit()
    db.refresh(new_user)
    return new_user


class GoogleLoginRequest(BaseModel):
    id_token: str
    role: Optional[Literal["student", "teacher"]] = None
    allow_signup: bool = False

    @field_validator("id_token")
    @classmethod
    def id_token_not_blank(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("id_token khong duoc rong")
        return normalized


async def _verify_google_id_token(id_token: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                GOOGLE_TOKENINFO_URL, params={"id_token": id_token}
            )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"Khong verify duoc Google token: {exc}")

    if response.status_code != 200:
        raise HTTPException(status_code=401, detail="Google id_token khong hop le")

    payload = response.json()
    if payload.get("aud") is None or payload.get("sub") is None:
        raise HTTPException(status_code=401, detail="Google token thieu truong bat buoc")

    allowed_aud = _allowed_google_audiences()
    if allowed_aud and payload["aud"] not in allowed_aud:
        raise HTTPException(status_code=401, detail="Google client_id khong duoc cap quyen")

    if str(payload.get("email_verified", "false")).lower() != "true":
        raise HTTPException(status_code=401, detail="Google account chua xac thuc email")

    return payload


@router.post("/google", response_model=LoginResponse)
async def login_with_google(body: GoogleLoginRequest, db: Session = Depends(get_db)):
    claims = await _verify_google_id_token(body.id_token)
    google_sub = claims["sub"]
    email = (claims.get("email") or "").strip().lower()
    full_name = (claims.get("name") or "").strip() or email.split("@")[0]
    picture = claims.get("picture")

    user_db = db.query(User).filter(User.google_sub == google_sub).first()
    if user_db is None and email:
        user_db = db.query(User).filter(User.email == email).first()
        if user_db is not None and user_db.google_sub is None:
            user_db.google_sub = google_sub

    if user_db is None:
        if not body.allow_signup:
            raise HTTPException(
                status_code=404,
                detail="Tai khoan Google chua duoc dang ky. Vui long dang ky truoc.",
            )
        if not email:
            raise HTTPException(status_code=400, detail="Google token khong co email")
        role = body.role or "student"
        user_db = User(
            id=str(uuid.uuid4()),
            email=email,
            password_hash=None,
            google_sub=google_sub,
            full_name=full_name,
            avatar_url=picture,
            role=role,
            is_active=True,
        )
        db.add(user_db)
        db.flush()

        if role == "teacher":
            db.add(TeacherProfile(user_id=user_db.id))
        else:
            db.add(StudentProfile(user_id=user_db.id))

    if not user_db.is_active:
        raise HTTPException(status_code=403, detail="Tai khoan da bi khoa")

    if not user_db.avatar_url and picture:
        user_db.avatar_url = picture

    user_db.last_login_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user_db)

    token = _create_access_token(user_db)
    return {"token": token, "user": user_db}


@router.post('/login', response_model=LoginResponse)
def login_user(user: UserLogin, db: Session = Depends(get_db)):
    user_db = db.query(User).filter(User.email == user.email).first()

    if not user_db:
        raise HTTPException(400, 'Email hoac mat khau khong dung')
    if not user_db.is_active:
        raise HTTPException(403, 'Tai khoan da bi khoa')

    is_match = bcrypt.checkpw(user.password.encode(), user_db.password_hash)

    if not is_match:
        raise HTTPException(400, 'Email hoac mat khau khong dung')

    user_db.last_login_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user_db)

    token = _create_access_token(user_db)

    return {'token': token, 'user': user_db}


@router.post("/create-admin", response_model=UserResponse, status_code=201)
def create_admin(
    user: AdminUserCreate,
    x_admin_secret: str = Header(),
    db: Session = Depends(get_db),
):
    if not ADMIN_CREATE_SECRET or x_admin_secret != ADMIN_CREATE_SECRET:
        raise HTTPException(status_code=403, detail="Invalid admin secret")

    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=400, detail="User with the same email already exists!")

    hashed_pw = bcrypt.hashpw(user.password.encode(), bcrypt.gensalt())
    new_user = User(
        id=str(uuid.uuid4()),
        email=user.email,
        password_hash=hashed_pw,
        full_name=user.full_name,
        role="admin",
        is_active=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@router.get('/', response_model=UserResponse)
def current_user_data(db: Session = Depends(get_db), user_dict=Depends(auth_middleware)):
    user = db.query(User).filter(User.id == user_dict['uid']).first()

    if not user:
        raise HTTPException(404, 'User not found!')
    if not user.is_active:
        raise HTTPException(403, 'Tai khoan da bi khoa')

    return user
