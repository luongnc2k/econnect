from datetime import datetime, timezone
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.class_ import Class
from models.topic import Topic
from models.user import User
from models.teacher_profile import TeacherProfile
from pydantic_schemas.class_create import ClassCreate
from pydantic_schemas.class_response import ClassResponse, TeacherBrief, TopicBrief

router = APIRouter()


@router.get("/upcoming", response_model=list[ClassResponse])
def get_upcoming_classes(
    topic: Optional[str] = Query(default=None, description="Filter by topic slug"),
    db: Session = Depends(get_db),
    _: dict = Depends(auth_middleware),
):
    now = datetime.now(timezone.utc)

    query = (
        db.query(Class, Topic, User, TeacherProfile)
        .join(Topic, Class.topic_id == Topic.id)
        .join(User, Class.teacher_id == User.id)
        .outerjoin(TeacherProfile, TeacherProfile.user_id == User.id)
        .filter(Class.start_time > now)
        .filter(Class.status == "scheduled")
    )

    if topic:
        query = query.filter(Topic.slug == topic)

    rows = query.order_by(Class.start_time.asc()).limit(10).all()

    results = []
    for cls, tp, teacher_user, teacher_profile in rows:
        results.append(
            ClassResponse(
                id=cls.id,
                title=cls.title,
                description=cls.description,
                level=cls.level,
                location_name=cls.location_name,
                location_address=cls.location_address,
                start_time=cls.start_time,
                end_time=cls.end_time,
                max_participants=cls.max_participants,
                current_participants=cls.current_participants,
                price=cls.price,
                thumbnail_url=cls.thumbnail_url,
                status=cls.status,
                topic=TopicBrief(
                    id=tp.id,
                    name=tp.name,
                    slug=tp.slug,
                    icon=tp.icon,
                ),
                teacher=TeacherBrief(
                    id=teacher_user.id,
                    full_name=teacher_user.full_name,
                    avatar_url=teacher_user.avatar_url,
                    rating_avg=teacher_profile.rating_avg if teacher_profile else None,
                    total_sessions=teacher_profile.total_sessions if teacher_profile else None,
                ),
            )
        )

    return results


@router.post("", response_model=ClassResponse, status_code=201)
def create_class(
    body: ClassCreate,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict['uid']).first()
    if not teacher or teacher.role != 'teacher':
        raise HTTPException(status_code=403, detail="Chỉ giáo viên mới có thể tạo lớp học")

    topic = db.query(Topic).filter(Topic.id == body.topic_id, Topic.is_active == True).first()
    if not topic:
        raise HTTPException(status_code=404, detail="Topic không tồn tại")

    new_class = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        title=body.title,
        description=body.description,
        level=body.level,
        location_name=body.location_name,
        location_address=body.location_address,
        latitude=body.latitude,
        longitude=body.longitude,
        start_time=body.start_time,
        end_time=body.end_time,
        max_participants=body.max_participants,
        current_participants=0,
        price=body.price,
        thumbnail_url=body.thumbnail_url,
        status="scheduled",
    )

    db.add(new_class)
    db.commit()
    db.refresh(new_class)

    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()

    return ClassResponse(
        id=new_class.id,
        title=new_class.title,
        description=new_class.description,
        level=new_class.level,
        location_name=new_class.location_name,
        location_address=new_class.location_address,
        start_time=new_class.start_time,
        end_time=new_class.end_time,
        max_participants=new_class.max_participants,
        current_participants=new_class.current_participants,
        price=new_class.price,
        thumbnail_url=new_class.thumbnail_url,
        status=new_class.status,
        topic=TopicBrief(id=topic.id, name=topic.name, slug=topic.slug, icon=topic.icon),
        teacher=TeacherBrief(
            id=teacher.id,
            full_name=teacher.full_name,
            avatar_url=teacher.avatar_url,
            rating_avg=teacher_profile.rating_avg if teacher_profile else None,
            total_sessions=teacher_profile.total_sessions if teacher_profile else None,
        ),
    )
