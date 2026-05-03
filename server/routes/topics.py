import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session
from typing import Optional

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.topic import Topic
from models.user import User

router = APIRouter()


class TopicCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    slug: str = Field(min_length=1, max_length=100)
    description: Optional[str] = None
    icon: Optional[str] = None

    @field_validator("name", "slug", mode="before")
    @classmethod
    def normalize_required_text(cls, value: object) -> str:
        if value is None:
            raise ValueError("Truong bat buoc")
        normalized = str(value).strip()
        if not normalized:
            raise ValueError("Khong duoc de trong")
        return normalized

    @field_validator("description", "icon", mode="before")
    @classmethod
    def normalize_optional_text(cls, value: object) -> Optional[str]:
        if value is None:
            return None
        normalized = str(value).strip()
        return normalized or None


class TopicResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    slug: str
    description: Optional[str] = None
    icon: Optional[str] = None
    is_active: bool


@router.get("", response_model=list[TopicResponse])
def list_topics(db: Session = Depends(get_db)):
    return db.query(Topic).filter(Topic.is_active == True).order_by(Topic.name).all()


@router.post("", response_model=TopicResponse, status_code=201)
def create_topic(
    body: TopicCreate,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    user = db.query(User).filter(User.id == user_dict['uid']).first()
    if not user or user.role != 'admin':
        raise HTTPException(status_code=403, detail="Chỉ admin mới có thể tạo topic")

    existing = db.query(Topic).filter(Topic.slug == body.slug).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Slug '{body.slug}' đã tồn tại")

    topic = Topic(
        id=str(uuid.uuid4()),
        name=body.name,
        slug=body.slug,
        description=body.description,
        icon=body.icon,
        is_active=True,
    )
    db.add(topic)
    db.commit()
    db.refresh(topic)
    return topic
