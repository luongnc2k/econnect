import uuid
from decimal import Decimal
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy import func
from sqlalchemy.orm import Session

from database import get_db
from learning_location_service import default_learning_location_ids
from middleware.auth_middleware import auth_middleware
from models.learning_location import LearningLocation
from models.user import User

router = APIRouter()


def _normalize_required_text(value: object) -> str:
    if value is None:
        raise ValueError("Truong bat buoc")
    normalized = " ".join(str(value).strip().split())
    if not normalized:
        raise ValueError("Khong duoc de trong")
    return normalized


def _normalize_optional_text(value: object) -> Optional[str]:
    if value is None:
        return None
    normalized = " ".join(str(value).strip().split())
    return normalized or None


class LearningLocationCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    address: str = Field(min_length=1, max_length=255)
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    notes: Optional[str] = Field(default=None, max_length=500)
    is_active: bool = True

    @field_validator("name", "address", mode="before")
    @classmethod
    def normalize_required_text(cls, value: object) -> str:
        return _normalize_required_text(value)

    @field_validator("notes", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: object) -> Optional[str]:
        return _normalize_optional_text(value)


class LearningLocationUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    address: Optional[str] = Field(default=None, min_length=1, max_length=255)
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    notes: Optional[str] = Field(default=None, max_length=500)
    is_active: Optional[bool] = None

    @field_validator("name", "address", mode="before")
    @classmethod
    def normalize_required_text(cls, value: object) -> Optional[str]:
        if value is None:
            return None
        return _normalize_required_text(value)

    @field_validator("notes", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: object) -> Optional[str]:
        return _normalize_optional_text(value)


class LearningLocationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    address: str
    latitude: Optional[Decimal] = None
    longitude: Optional[Decimal] = None
    notes: Optional[str] = None
    is_active: bool


def _get_user_or_404(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Khong tim thay nguoi dung")
    return user


def _require_admin(user: User) -> None:
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Chi admin moi co the quan ly dia diem hoc")


def _location_duplicate_exists(
    db: Session,
    *,
    name: str,
    address: str,
    exclude_id: Optional[str] = None,
) -> bool:
    query = db.query(LearningLocation).filter(
        func.lower(LearningLocation.name) == name.lower(),
        func.lower(LearningLocation.address) == address.lower(),
    )
    if exclude_id:
        query = query.filter(LearningLocation.id != exclude_id)
    return query.first() is not None


@router.get("", response_model=list[LearningLocationResponse])
def list_learning_locations(
    include_inactive: bool = Query(default=False),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    query = db.query(LearningLocation)
    default_ids = default_learning_location_ids()

    if user.role != "admin":
        rows = (
            query.filter(
                LearningLocation.is_active.is_(True),
                LearningLocation.id.in_(default_ids),
            )
            .all()
        )
        rows_by_id = {row.id: row for row in rows}
        return [rows_by_id[location_id] for location_id in default_ids if location_id in rows_by_id]

    if not include_inactive:
        query = query.filter(LearningLocation.is_active.is_(True))
    return query.order_by(LearningLocation.name.asc(), LearningLocation.address.asc()).all()


@router.post("", response_model=LearningLocationResponse, status_code=201)
def create_learning_location(
    body: LearningLocationCreate,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    _require_admin(user)

    if _location_duplicate_exists(db, name=body.name, address=body.address):
        raise HTTPException(status_code=400, detail="Dia diem hoc nay da ton tai")

    location = LearningLocation(
        id=str(uuid.uuid4()),
        name=body.name,
        address=body.address,
        latitude=body.latitude,
        longitude=body.longitude,
        notes=body.notes,
        is_active=body.is_active,
    )
    db.add(location)
    db.commit()
    db.refresh(location)
    return location


@router.patch("/{location_id}", response_model=LearningLocationResponse)
def update_learning_location(
    location_id: str,
    body: LearningLocationUpdate,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = _get_user_or_404(db, user_dict["uid"])
    _require_admin(user)

    location = db.query(LearningLocation).filter(LearningLocation.id == location_id).first()
    if not location:
        raise HTTPException(status_code=404, detail="Khong tim thay dia diem hoc")

    payload = body.model_dump(exclude_unset=True)
    next_name = payload.get("name", location.name)
    next_address = payload.get("address", location.address)
    if _location_duplicate_exists(
        db,
        name=next_name,
        address=next_address,
        exclude_id=location.id,
    ):
        raise HTTPException(status_code=400, detail="Dia diem hoc nay da ton tai")

    for field, value in payload.items():
        setattr(location, field, value)

    db.commit()
    db.refresh(location)
    return location
