import os
from datetime import datetime, timezone
from datetime import timedelta

from fastapi import Depends, Header, HTTPException
from sqlalchemy.orm import Session
from pydantic_schemas.user_create import UserCreate
from pydantic_schemas.user_login import UserLogin
from pydantic_schemas.user_response import LoginResponse, UserResponse
from models.user import User
from database import get_db
from fastapi import APIRouter
import uuid
import bcrypt
import jwt

from middleware.auth_middleware import auth_middleware

ADMIN_CREATE_SECRET = os.getenv("ADMIN_CREATE_SECRET", "")
JWT_SECRET = os.getenv("JWT_SECRET", "dev_jwt_secret_change_me_please_32bytes")


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
    db.commit()
    db.refresh(new_user)
    return new_user


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
    user: UserCreate,
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
