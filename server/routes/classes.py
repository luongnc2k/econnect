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
from pydantic_schemas.payment import calculate_creation_fee

router = APIRouter()


def _build_class_code(cls: Class) -> str:
    date_part = cls.start_time.strftime("%y%m%d")
    raw_id = "".join(char for char in str(cls.id).upper() if char.isalnum())
    suffix = raw_id[:4].ljust(4, "0")
    return f"CLS-{date_part}-{suffix}"


def _to_class_response(
    cls: Class,
    tp: Topic,
    teacher_user: User,
    teacher_profile: Optional[TeacherProfile],
) -> ClassResponse:
    return ClassResponse(
        id=cls.id,
        class_code=_build_class_code(cls),
        title=cls.title,
        description=cls.description,
        level=cls.level,
        location_name=cls.location_name,
        location_address=cls.location_address,
        start_time=cls.start_time,
        end_time=cls.end_time,
        min_participants=cls.min_participants,
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


@router.get("/upcoming", response_model=list[ClassResponse])
def get_upcoming_classes(
    topic: Optional[str] = Query(default=None, description="Filter by topic slug"),
    q: Optional[str] = Query(default=None, description="Search by class title or class code"),
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

    rows = query.order_by(Class.start_time.asc()).all()

    keyword = (q or "").strip().lower()

    results = []
    for cls, tp, teacher_user, teacher_profile in rows:
        class_code = _build_class_code(cls)
        if keyword and keyword not in cls.title.lower() and keyword not in class_code.lower():
            continue
        results.append(_to_class_response(cls, tp, teacher_user, teacher_profile))

    return results[:20]


@router.get("/by-code/{class_code}", response_model=ClassResponse)
def get_class_by_code(
    class_code: str,
    db: Session = Depends(get_db),
    _: dict = Depends(auth_middleware),
):
    normalized_code = class_code.strip().upper()
    if not normalized_code:
        raise HTTPException(status_code=400, detail="Ma lop khong hop le")

    now = datetime.now(timezone.utc)
    rows = (
        db.query(Class, Topic, User, TeacherProfile)
        .join(Topic, Class.topic_id == Topic.id)
        .join(User, Class.teacher_id == User.id)
        .outerjoin(TeacherProfile, TeacherProfile.user_id == User.id)
        .filter(Class.start_time > now)
        .filter(Class.status == "scheduled")
        .order_by(Class.start_time.asc())
        .all()
    )

    for cls, tp, teacher_user, teacher_profile in rows:
        if _build_class_code(cls).upper() == normalized_code:
            return _to_class_response(cls, tp, teacher_user, teacher_profile)

    raise HTTPException(status_code=404, detail="Khong tim thay lop hoc voi ma nay")


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

    creation_fee = calculate_creation_fee(body.price)

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
        min_participants=body.min_participants,
        max_participants=body.max_participants,
        current_participants=0,
        price=body.price,
        creation_fee_amount=creation_fee,
        creation_payment_status="paid",
        thumbnail_url=body.thumbnail_url,
        status="scheduled",
        tutor_payout_status="pending",
        tutor_payout_amount=0,
    )

    db.add(new_class)
    db.commit()
    db.refresh(new_class)

    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()

    return _to_class_response(new_class, topic, teacher, teacher_profile)
