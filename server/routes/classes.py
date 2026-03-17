from collections import defaultdict
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
from models.booking import Booking
from pydantic_schemas.class_create import ClassCreate
from pydantic_schemas.class_response import ClassDetailResponse, ClassResponse, EnrolledStudentBrief, TeacherBrief, TopicBrief

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


@router.get("/income")
def get_income_stats(
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict['uid']).first()
    if not teacher or teacher.role != 'teacher':
        raise HTTPException(status_code=403, detail="Chỉ giáo viên mới có thể xem thu nhập")

    now = datetime.now(timezone.utc)
    this_month = now.month
    this_year = now.year
    last_month = this_month - 1 if this_month > 1 else 12
    last_month_year = this_year if this_month > 1 else this_year - 1

    # All confirmed/completed bookings for this teacher's classes
    rows = (
        db.query(Booking, Class)
        .join(Class, Booking.class_id == Class.id)
        .filter(
            Class.teacher_id == teacher.id,
            Booking.status.in_(['confirmed', 'completed']),
        )
        .all()
    )

    total_income = 0.0
    this_month_income = 0.0
    last_month_income = 0.0
    monthly: dict = defaultdict(float)

    for booking, cls in rows:
        price = float(cls.price)
        total_income += price

        booked_at = booking.booked_at
        key = f"{booked_at.year}-{str(booked_at.month).zfill(2)}"
        monthly[key] += price

        if booked_at.year == this_year and booked_at.month == this_month:
            this_month_income += price
        if booked_at.year == last_month_year and booked_at.month == last_month:
            last_month_income += price

    # Build last 6 months breakdown (oldest → newest)
    breakdown = []
    for i in range(5, -1, -1):
        m = now.month - i
        y = now.year
        while m <= 0:
            m += 12
            y -= 1
        key = f"{y}-{str(m).zfill(2)}"
        breakdown.append({"month": key, "income": monthly.get(key, 0.0)})

    completed_classes = (
        db.query(Class)
        .filter(Class.teacher_id == teacher.id, Class.start_time <= now)
        .count()
    )

    return {
        "total_income": total_income,
        "this_month_income": this_month_income,
        "last_month_income": last_month_income,
        "completed_classes": completed_classes,
        "monthly_breakdown": breakdown,
    }


@router.get("/my", response_model=list[ClassResponse])
def get_my_classes(
    past: bool = Query(default=False, description="True = lớp đã dạy, False = lớp sắp dạy"),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict['uid']).first()
    if not teacher or teacher.role != 'teacher':
        raise HTTPException(status_code=403, detail="Chỉ giáo viên mới có thể xem lớp của mình")

    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()
    now = datetime.now(timezone.utc)

    query = (
        db.query(Class, Topic)
        .join(Topic, Class.topic_id == Topic.id)
        .filter(Class.teacher_id == teacher.id)
    )

    if past:
        query = query.filter(Class.start_time <= now)
        query = query.order_by(Class.start_time.desc())
    else:
        query = query.filter(Class.start_time > now, Class.status == 'scheduled')
        query = query.order_by(Class.start_time.asc())

    rows = query.all()
    return [
        _to_class_response(cls, tp, teacher, teacher_profile)
        for cls, tp in rows
    ]


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


@router.get("/{class_id}", response_model=ClassDetailResponse)
def get_class_detail(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict['uid']).first()
    if not teacher or teacher.role != 'teacher':
        raise HTTPException(status_code=403, detail="Chỉ giáo viên mới có thể xem chi tiết lớp")

    cls = db.query(Class).filter(Class.id == class_id, Class.teacher_id == teacher.id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Không tìm thấy lớp học")

    tp = db.query(Topic).filter(Topic.id == cls.topic_id).first()
    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()

    bookings = (
        db.query(Booking, User)
        .join(User, Booking.student_id == User.id)
        .filter(Booking.class_id == class_id, Booking.status != 'cancelled')
        .order_by(Booking.booked_at.asc())
        .all()
    )

    enrolled = [
        EnrolledStudentBrief(
            id=student.id,
            full_name=student.full_name,
            avatar_url=student.avatar_url,
            status=booking.status,
            booked_at=booking.booked_at,
        )
        for booking, student in bookings
    ]

    base = _to_class_response(cls, tp, teacher, teacher_profile)
    return ClassDetailResponse(**base.model_dump(), enrolled_students=enrolled)


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
        min_participants=body.min_participants,
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

    return _to_class_response(new_class, topic, teacher, teacher_profile)
