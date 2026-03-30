from collections import defaultdict
from datetime import datetime, timezone
import os
from typing import Optional
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from database import get_db
from learning_location_service import get_active_learning_location_or_400
from middleware.auth_middleware import auth_middleware
from models.booking import Booking
from models.class_ import Class
from models.learning_location import LearningLocation
from models.teacher_profile import TeacherProfile
from models.topic import Topic
from models.tutor_review import TutorReview
from models.user import User
from notification_service import dispatch_due_class_starting_soon_notifications
from pydantic_schemas.class_create import ClassCreate
from pydantic_schemas.class_response import (
    ClassDetailResponse,
    ClassResponse,
    EnrolledStudentBrief,
    StudentClassBookingStatusResponse,
    TeacherBrief,
)
from pydantic_schemas.payment import calculate_creation_fee
from pydantic_schemas.tutor_review import (
    StudentTutorReviewStatusResponse,
    TutorReviewRequest,
    TutorReviewResponse,
)
from topic_service import ensure_topic_record, resolve_class_topic_label

router = APIRouter()
ECONNECT_HOTLINE = "0335837165"


def _allow_direct_class_creation() -> bool:
    raw_value = os.getenv("ALLOW_DIRECT_CLASS_CREATION", "")
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _build_class_code(cls: Class) -> str:
    date_part = cls.start_time.strftime("%y%m%d")
    raw_id = "".join(char for char in str(cls.id).upper() if char.isalnum())
    suffix = raw_id[:4].ljust(4, "0")
    return f"CLS-{date_part}-{suffix}"


def _serialize_tutor_review(review: TutorReview) -> TutorReviewResponse:
    return TutorReviewResponse(
        id=review.id,
        class_id=review.class_id,
        booking_id=review.booking_id,
        teacher_id=review.teacher_id,
        student_id=review.student_id,
        rating=review.rating,
        comment=review.comment,
        created_at=review.created_at,
        updated_at=review.updated_at,
    )


def _refresh_teacher_review_stats(db: Session, teacher_id: str) -> None:
    teacher_profile = (
        db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher_id).first()
    )
    if not teacher_profile:
        return

    count = (
        db.query(func.count(TutorReview.id))
        .filter(TutorReview.teacher_id == teacher_id)
        .scalar()
    ) or 0
    average = (
        db.query(func.avg(TutorReview.rating))
        .filter(TutorReview.teacher_id == teacher_id)
        .scalar()
    )

    teacher_profile.total_reviews = int(count)
    teacher_profile.rating_avg = round(float(average or 0), 1)


def _find_student_booking_for_review(
    db: Session,
    *,
    class_id: str,
    student_id: str,
) -> Booking | None:
    return (
        db.query(Booking)
        .filter(
            Booking.class_id == class_id,
            Booking.student_id == student_id,
            Booking.status.in_(["confirmed", "completed"]),
            Booking.payment_status == "paid",
        )
        .first()
    )


def _build_student_tutor_review_status_response(
    db: Session,
    *,
    cls: Class,
    student_id: str,
) -> StudentTutorReviewStatusResponse:
    booking = _find_student_booking_for_review(
        db,
        class_id=cls.id,
        student_id=student_id,
    )
    review = (
        db.query(TutorReview)
        .filter(TutorReview.class_id == cls.id, TutorReview.student_id == student_id)
        .first()
    )

    if booking is None:
        return StudentTutorReviewStatusResponse(
            class_id=cls.id,
            can_review=False,
            already_reviewed=review is not None,
            hotline=ECONNECT_HOTLINE,
            reason="Bạn cần đăng ký và thanh toán buổi học này trước khi đánh giá tutor.",
            review=_serialize_tutor_review(review) if review else None,
        )

    if cls.end_time > datetime.now(timezone.utc):
        return StudentTutorReviewStatusResponse(
            class_id=cls.id,
            can_review=False,
            already_reviewed=review is not None,
            hotline=ECONNECT_HOTLINE,
            reason="Bạn chỉ có thể đánh giá tutor sau khi buổi học kết thúc.",
            review=_serialize_tutor_review(review) if review else None,
        )

    return StudentTutorReviewStatusResponse(
        class_id=cls.id,
        can_review=True,
        already_reviewed=review is not None,
        hotline=ECONNECT_HOTLINE,
        reason=None,
        review=_serialize_tutor_review(review) if review else None,
    )


def _to_class_response(
    cls: Class,
    teacher_user: User,
    teacher_profile: Optional[TeacherProfile],
    *,
    topic_name: str,
    location_notes_lookup: Optional[dict[tuple[str, str], str]] = None,
) -> ClassResponse:
    location_notes = cls.location_notes
    if (location_notes is None or not location_notes.strip()) and location_notes_lookup:
        location_notes = location_notes_lookup.get(
            _location_lookup_key(cls.location_name, cls.location_address)
        )

    return ClassResponse(
        id=cls.id,
        class_code=_build_class_code(cls),
        title=cls.title,
        description=cls.description,
        level=cls.level,
        location_name=cls.location_name,
        location_address=cls.location_address,
        location_notes=location_notes,
        start_time=cls.start_time,
        end_time=cls.end_time,
        min_participants=cls.min_participants,
        max_participants=cls.max_participants,
        current_participants=cls.current_participants,
        minimum_participants_reached=cls.minimum_participants_reached,
        tutor_confirmation_status=cls.tutor_confirmation_status,
        tutor_confirmed_at=cls.tutor_confirmed_at,
        price=cls.price,
        thumbnail_url=cls.thumbnail_url,
        status=cls.status,
        topic=topic_name,
        teacher=TeacherBrief(
            id=teacher_user.id,
            full_name=teacher_user.full_name,
            avatar_url=teacher_user.avatar_url,
            rating_avg=teacher_profile.rating_avg if teacher_profile else None,
            total_sessions=teacher_profile.total_sessions if teacher_profile else None,
            total_reviews=teacher_profile.total_reviews if teacher_profile else None,
        ),
    )


def _topic_filter_expression(raw_topic: str):
    normalized = raw_topic.strip().lower()
    return or_(
        func.lower(Class.topic).contains(normalized),
        func.lower(func.coalesce(Topic.name, "")).contains(normalized),
    )


def _location_lookup_key(
    location_name: Optional[str],
    location_address: Optional[str],
) -> tuple[str, str]:
    return (
        (location_name or "").strip().lower(),
        (location_address or "").strip().lower(),
    )


def _build_location_notes_lookup(
    db: Session,
    classes: list[Class],
) -> Optional[dict[tuple[str, str], str]]:
    needs_fallback = any(not (cls.location_notes or "").strip() for cls in classes)
    if not needs_fallback:
        return None

    lookup: dict[tuple[str, str], str] = {}
    rows = (
        db.query(LearningLocation)
        .filter(
            LearningLocation.is_active.is_(True),
            LearningLocation.notes.is_not(None),
        )
        .all()
    )
    for location in rows:
        notes = (location.notes or "").strip()
        if not notes:
            continue
        lookup.setdefault(
            _location_lookup_key(location.name, location.address),
            location.notes,
        )
    return lookup or None


def _build_student_booking_status_response(
    db: Session,
    *,
    cls: Class,
    student_id: str,
) -> StudentClassBookingStatusResponse:
    booking = (
        db.query(Booking)
        .filter(Booking.class_id == cls.id, Booking.student_id == student_id)
        .first()
    )
    is_registered = bool(
        booking
        and booking.status in {"confirmed", "completed"}
        and booking.payment_status == "paid"
    )
    return StudentClassBookingStatusResponse(
        class_id=cls.id,
        has_booking=booking is not None,
        is_registered=is_registered,
        booking_id=booking.id if booking else None,
        booking_status=booking.status if booking else None,
        payment_status=booking.payment_status if booking else None,
        escrow_status=booking.escrow_status if booking else None,
        payment_reference=booking.payment_reference if booking else None,
        tuition_amount=booking.tuition_amount if booking else None,
        booked_at=booking.booked_at if booking else None,
    )


@router.get("/income")
def get_income_stats(
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not teacher or teacher.role != "teacher":
        raise HTTPException(status_code=403, detail="Chi giao vien moi co the xem thu nhap")

    now = datetime.now(timezone.utc)
    this_month = now.month
    this_year = now.year
    last_month = this_month - 1 if this_month > 1 else 12
    last_month_year = this_year if this_month > 1 else this_year - 1

    rows = (
        db.query(Booking, Class)
        .join(Class, Booking.class_id == Class.id)
        .filter(
            Class.teacher_id == teacher.id,
            Booking.status.in_(["confirmed", "completed"]),
        )
        .all()
    )

    total_income = 0.0
    this_month_income = 0.0
    last_month_income = 0.0
    monthly: dict[str, float] = defaultdict(float)

    for booking, cls in rows:
        income_amount = float(booking.tuition_amount)
        total_income += income_amount

        booked_at = booking.booked_at
        key = f"{booked_at.year}-{str(booked_at.month).zfill(2)}"
        monthly[key] += income_amount

        if booked_at.year == this_year and booked_at.month == this_month:
            this_month_income += income_amount
        if booked_at.year == last_month_year and booked_at.month == last_month:
            last_month_income += income_amount

    breakdown = []
    for i in range(5, -1, -1):
        month = now.month - i
        year = now.year
        while month <= 0:
            month += 12
            year -= 1
        key = f"{year}-{str(month).zfill(2)}"
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
    past: bool = Query(default=False, description="True = lop da day, False = lop sap day"),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not teacher or teacher.role != "teacher":
        raise HTTPException(status_code=403, detail="Chi giao vien moi co the xem lop cua minh")

    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()
    now = datetime.now(timezone.utc)

    query = (
        db.query(Class, Topic)
        .outerjoin(Topic, Class.topic_id == Topic.id)
        .filter(Class.teacher_id == teacher.id)
    )

    if past:
        query = query.filter(Class.start_time <= now).order_by(Class.start_time.desc())
    else:
        query = query.filter(
            Class.start_time > now,
            Class.status == "scheduled",
        ).order_by(Class.start_time.asc())

    rows = query.all()
    location_notes_lookup = _build_location_notes_lookup(
        db,
        [cls for cls, _ in rows],
    )
    return [
        _to_class_response(
            cls,
            teacher,
            teacher_profile,
            topic_name=resolve_class_topic_label(cls, topic=tp),
            location_notes_lookup=location_notes_lookup,
        )
        for cls, tp in rows
    ]


@router.get("/upcoming", response_model=list[ClassResponse])
def get_upcoming_classes(
    topic: Optional[str] = Query(default=None, description="Filter by topic text"),
    q: Optional[str] = Query(default=None, description="Search by class title or class code"),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    notified = dispatch_due_class_starting_soon_notifications(db, target_user_id=user_dict["uid"])
    if notified:
        db.commit()
    else:
        db.rollback()

    now = datetime.now(timezone.utc)
    query = (
        db.query(Class, Topic, User, TeacherProfile)
        .outerjoin(Topic, Class.topic_id == Topic.id)
        .join(User, Class.teacher_id == User.id)
        .outerjoin(TeacherProfile, TeacherProfile.user_id == User.id)
        .filter(Class.start_time > now, Class.status == "scheduled")
    )

    if topic and topic.strip():
        query = query.filter(_topic_filter_expression(topic))

    rows = query.order_by(Class.start_time.asc()).all()
    keyword = (q or "").strip().lower()
    location_notes_lookup = _build_location_notes_lookup(
        db,
        [cls for cls, *_ in rows],
    )

    results = []
    for cls, tp, teacher_user, teacher_profile in rows:
        class_code = _build_class_code(cls)
        topic_name_display = resolve_class_topic_label(cls, topic=tp)
        topic_name = topic_name_display.lower()
        if (
            keyword
            and keyword not in cls.title.lower()
            and keyword not in class_code.lower()
            and keyword not in topic_name
        ):
            continue
        results.append(
            _to_class_response(
                cls,
                teacher_user,
                teacher_profile,
                topic_name=topic_name_display,
                location_notes_lookup=location_notes_lookup,
            )
        )

    return results[:20]


@router.get("/registered", response_model=list[ClassResponse])
def get_registered_classes(
    past: bool = Query(default=False, description="True = lop da hoc, False = lop sap hoc"),
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    student = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not student or student.role != "student":
        raise HTTPException(status_code=403, detail="Chi hoc vien moi co the xem lich hoc cua minh")

    now = datetime.now(timezone.utc)
    query = (
        db.query(Class, Topic, User, TeacherProfile)
        .join(Booking, Booking.class_id == Class.id)
        .outerjoin(Topic, Class.topic_id == Topic.id)
        .join(User, Class.teacher_id == User.id)
        .outerjoin(TeacherProfile, TeacherProfile.user_id == User.id)
        .filter(
            Booking.student_id == student.id,
            Booking.status.in_(["confirmed", "completed"]),
            Booking.payment_status == "paid",
        )
    )

    if past:
        query = query.filter(Class.start_time <= now).order_by(Class.start_time.desc())
    else:
        query = query.filter(Class.start_time > now).order_by(Class.start_time.asc())

    rows = query.all()
    location_notes_lookup = _build_location_notes_lookup(
        db,
        [cls for cls, *_ in rows],
    )
    return [
        _to_class_response(
            cls,
            teacher_user,
            teacher_profile,
            topic_name=resolve_class_topic_label(cls, topic=tp),
            location_notes_lookup=location_notes_lookup,
        )
        for cls, tp, teacher_user, teacher_profile in rows
    ]


@router.get("/by-code/{class_code}", response_model=ClassResponse)
def get_class_by_code(
    class_code: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    notified = dispatch_due_class_starting_soon_notifications(db, target_user_id=user_dict["uid"])
    if notified:
        db.commit()
    else:
        db.rollback()

    normalized_code = class_code.strip().upper()
    if not normalized_code:
        raise HTTPException(status_code=400, detail="Ma lop khong hop le")

    now = datetime.now(timezone.utc)
    rows = (
        db.query(Class, Topic, User, TeacherProfile)
        .outerjoin(Topic, Class.topic_id == Topic.id)
        .join(User, Class.teacher_id == User.id)
        .outerjoin(TeacherProfile, TeacherProfile.user_id == User.id)
        .filter(Class.start_time > now, Class.status == "scheduled")
        .order_by(Class.start_time.asc())
        .all()
    )

    for cls, tp, teacher_user, teacher_profile in rows:
        if _build_class_code(cls).upper() == normalized_code:
            location_notes_lookup = _build_location_notes_lookup(db, [cls])
            return _to_class_response(
                cls,
                teacher_user,
                teacher_profile,
                topic_name=resolve_class_topic_label(cls, topic=tp),
                location_notes_lookup=location_notes_lookup,
            )

    raise HTTPException(status_code=404, detail="Khong tim thay lop hoc voi ma nay")


@router.get("/{class_id}/my-booking-status", response_model=StudentClassBookingStatusResponse)
def get_my_class_booking_status(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    student = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not student or student.role != "student":
        raise HTTPException(status_code=403, detail="Chi hoc vien moi co the xem trang thai dang ky cua minh")

    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Khong tim thay lop hoc")

    return _build_student_booking_status_response(
        db,
        cls=cls,
        student_id=student.id,
    )


@router.get(
    "/{class_id}/my-tutor-review",
    response_model=StudentTutorReviewStatusResponse,
)
def get_my_tutor_review(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    student = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not student or student.role != "student":
        raise HTTPException(
            status_code=403,
            detail="Chi hoc vien moi co the xem trang thai danh gia tutor cua minh",
        )

    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Khong tim thay lop hoc")

    return _build_student_tutor_review_status_response(
        db,
        cls=cls,
        student_id=student.id,
    )


@router.put(
    "/{class_id}/my-tutor-review",
    response_model=StudentTutorReviewStatusResponse,
)
def upsert_my_tutor_review(
    class_id: str,
    payload: TutorReviewRequest,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    student = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not student or student.role != "student":
        raise HTTPException(
            status_code=403,
            detail="Chi hoc vien moi co the gui danh gia tutor",
        )

    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Khong tim thay lop hoc")

    booking = _find_student_booking_for_review(
        db,
        class_id=cls.id,
        student_id=student.id,
    )
    if booking is None:
        raise HTTPException(
            status_code=400,
            detail="Ban chi co the danh gia tutor cho buoi hoc da dang ky va thanh toan",
        )
    if cls.end_time > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=400,
            detail="Buoi hoc chua ket thuc, chua the gui danh gia tutor",
        )

    review = (
        db.query(TutorReview)
        .filter(TutorReview.booking_id == booking.id)
        .first()
    )
    if not review:
        review = TutorReview(
            id=str(uuid.uuid4()),
            class_id=cls.id,
            booking_id=booking.id,
            teacher_id=cls.teacher_id,
            student_id=student.id,
            rating=payload.rating,
            comment=payload.comment,
        )
        db.add(review)
    else:
        review.rating = payload.rating
        review.comment = payload.comment

    db.flush()
    _refresh_teacher_review_stats(db, cls.teacher_id)
    db.commit()
    db.refresh(review)

    teacher_profile = (
        db.query(TeacherProfile).filter(TeacherProfile.user_id == cls.teacher_id).first()
    )
    if teacher_profile:
        db.refresh(teacher_profile)

    return _build_student_tutor_review_status_response(
        db,
        cls=cls,
        student_id=student.id,
    )


@router.get("/{class_id}", response_model=ClassDetailResponse)
def get_class_detail(
    class_id: str,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    teacher = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not teacher or teacher.role != "teacher":
        raise HTTPException(status_code=403, detail="Chi giao vien moi co the xem chi tiet lop")

    row = (
        db.query(Class, Topic)
        .outerjoin(Topic, Class.topic_id == Topic.id)
        .filter(Class.id == class_id, Class.teacher_id == teacher.id)
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Khong tim thay lop hoc")

    cls, topic = row
    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()

    bookings = (
        db.query(Booking, User)
        .join(User, Booking.student_id == User.id)
        .filter(Booking.class_id == class_id, Booking.status != "cancelled")
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

    base = _to_class_response(
        cls,
        teacher,
        teacher_profile,
        topic_name=resolve_class_topic_label(cls, topic=topic),
        location_notes_lookup=_build_location_notes_lookup(db, [cls]),
    )
    return ClassDetailResponse(**base.model_dump(), enrolled_students=enrolled)


@router.post("", response_model=ClassResponse, status_code=201)
def create_class(
    body: ClassCreate,
    db: Session = Depends(get_db),
    user_dict: dict = Depends(auth_middleware),
):
    if not _allow_direct_class_creation():
        raise HTTPException(
            status_code=410,
            detail="Direct class creation da bi tat. Hay su dung POST /payments/class-creation/request",
        )

    teacher = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not teacher or teacher.role != "teacher":
        raise HTTPException(status_code=403, detail="Chi giao vien moi co the tao lop hoc")

    resolved_topic = ensure_topic_record(db, body.topic)
    selected_location = get_active_learning_location_or_400(db, body.location_id)
    creation_fee = calculate_creation_fee(body.price)

    new_class = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=resolved_topic.id,
        topic=resolved_topic.name,
        title=body.title,
        description=body.description,
        level=body.level,
        location_name=selected_location.name,
        location_address=selected_location.address,
        location_notes=selected_location.notes,
        latitude=selected_location.latitude,
        longitude=selected_location.longitude,
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
        minimum_participants_reached=False,
        tutor_confirmation_status="waiting_minimum",
    )

    db.add(new_class)
    db.commit()
    db.refresh(new_class)

    teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == teacher.id).first()
    return _to_class_response(
        new_class,
        teacher,
        teacher_profile,
        topic_name=resolve_class_topic_label(new_class, topic=resolved_topic),
    )
