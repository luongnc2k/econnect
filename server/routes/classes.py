from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.class_ import Class
from models.topic import Topic
from models.user import User
from models.teacher_profile import TeacherProfile
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
