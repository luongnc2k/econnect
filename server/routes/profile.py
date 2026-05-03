from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.student_profile import StudentProfile
from models.teacher_profile import TeacherProfile
from models.user import User
from payment_gateways import (
    PAYOS_PROVIDER,
    PaymentGatewayError,
    verify_provider_payout_destination,
)
from pydantic_schemas.profile import (
    FeaturedTeacherResponse,
    ProfileUpdateRequest,
    PayoutBankAccountVerificationRequest,
    PayoutBankAccountVerificationResponse,
)

router = APIRouter()

_BANK_ACCOUNT_FIELDS = {
    "bank_name",
    "bank_bin",
    "bank_account_number",
    "bank_account_holder",
}


def _map_payout_bank_verification_error_detail(exc: PaymentGatewayError) -> str:
    message = str(exc)
    normalized = message.lower()
    ip_not_allowed_markers = (
        "dia chi ip khong duoc phep truy cap he thong",
        "địa chỉ ip không được phép truy cập hệ thống",
        "ip may chu hien tai chua duoc them vao kenh chuyen tien",
        "ip máy chủ hiện tại chưa được thêm vào kênh chuyển tiền",
    )
    if any(marker in normalized for marker in ip_not_allowed_markers):
        return (
            "payOS từ chối kiểm tra vì IP máy chủ hiện tại chưa được thêm vào "
            "Kênh chuyển tiền > Quản lý IP. Nếu bạn đang chạy local/ngrok, hãy đổi "
            "PAYOS_PAYOUT_MOCK_MODE=true trong server/.env rồi restart backend. "
            "Nếu muốn kiểm tra thật, hãy thêm public outbound IP của backend vào my.payos.vn. "
            "Nếu máy local ưu tiên IPv6 và bạn chỉ allowlist IPv4, hãy bật thêm "
            "PAYOS_PAYOUT_FORCE_IPV4=true."
        )
    return f"Không thể kiểm tra tài khoản ngân hàng lúc này: {message}"


def _serialize_profile(
    user: User,
    student_profile: StudentProfile | None,
    teacher_profile: TeacherProfile | None,
    *,
    include_private_user_fields: bool = True,
    include_sensitive_bank_fields: bool = False,
) -> dict:
    data = {
        "id": user.id,
        "email": user.email if include_private_user_fields else "",
        "full_name": user.full_name,
        "phone": user.phone if include_private_user_fields else None,
        "avatar_url": user.avatar_url,
        "role": user.role,
        "is_active": user.is_active,
        "last_login_at": (
            user.last_login_at.isoformat()
            if include_private_user_fields and user.last_login_at
            else None
        ),
        "created_at": (
            user.created_at.isoformat()
            if include_private_user_fields and user.created_at
            else None
        ),
        "updated_at": (
            user.updated_at.isoformat()
            if include_private_user_fields and user.updated_at
            else None
        ),
    }

    if user.role == "student":
        goals = student_profile.learning_goals if student_profile else []
        data.update(
            {
                "english_level": student_profile.english_level if student_profile else None,
                "learning_goal": goals[0] if goals else None,
                "bank_name": (
                    student_profile.bank_name
                    if student_profile and include_sensitive_bank_fields
                    else None
                ),
                "bank_bin": (
                    student_profile.bank_bin
                    if student_profile and include_sensitive_bank_fields
                    else None
                ),
                "bank_account_number": (
                    student_profile.bank_account_number
                    if student_profile and include_sensitive_bank_fields
                    else None
                ),
                "bank_account_holder": (
                    student_profile.bank_account_holder
                    if student_profile and include_sensitive_bank_fields
                    else None
                ),
                "total_lessons": student_profile.total_classes_attended if student_profile else 0,
                "average_score": None,
            }
        )
    elif user.role == "teacher":
        data.update(
            {
                "specialization": teacher_profile.native_language if teacher_profile else None,
                "bank_name": teacher_profile.bank_name if teacher_profile and include_sensitive_bank_fields else None,
                "bank_bin": teacher_profile.bank_bin if teacher_profile and include_sensitive_bank_fields else None,
                "bank_account_number": (
                    teacher_profile.bank_account_number
                    if teacher_profile and include_sensitive_bank_fields
                    else None
                ),
                "bank_account_holder": (
                    teacher_profile.bank_account_holder
                    if teacher_profile and include_sensitive_bank_fields
                    else None
                ),
                "years_of_experience": teacher_profile.years_experience if teacher_profile else 0,
                "rating": float(teacher_profile.rating_avg) if teacher_profile else 0.0,
                "total_students": teacher_profile.total_sessions if teacher_profile else 0,
                "bio": teacher_profile.bio if teacher_profile else None,
                "hourly_rate": None,
                "certifications": list(teacher_profile.certifications or []) if teacher_profile else [],
                "verification_docs": (
                    list(teacher_profile.verification_docs or [])
                    if teacher_profile and include_sensitive_bank_fields
                    else []
                ),
            }
        )

    return data


@router.get("/featured-teachers", response_model=list[FeaturedTeacherResponse])
def get_featured_teachers(
    limit: int = Query(default=5, ge=1, le=10),
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    requester = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not requester:
        raise HTTPException(status_code=404, detail="User not found")

    rows = (
        db.query(User, TeacherProfile)
        .join(TeacherProfile, TeacherProfile.user_id == User.id)
        .filter(
            User.role == "teacher",
            User.is_active.is_(True),
            or_(
                func.coalesce(TeacherProfile.rating_avg, 0) > 0,
                func.coalesce(TeacherProfile.total_sessions, 0) > 0,
                func.coalesce(TeacherProfile.total_reviews, 0) > 0,
            ),
        )
        .order_by(
            func.coalesce(TeacherProfile.rating_avg, 0).desc(),
            func.coalesce(TeacherProfile.total_sessions, 0).desc(),
            func.coalesce(TeacherProfile.total_reviews, 0).desc(),
            User.full_name.asc(),
        )
        .limit(limit)
        .all()
    )

    return [
        FeaturedTeacherResponse(
            id=user.id,
            full_name=user.full_name,
            avatar_url=user.avatar_url,
            specialization=teacher_profile.native_language,
            rating=float(teacher_profile.rating_avg or 0),
            total_sessions=int(teacher_profile.total_sessions or 0),
            total_reviews=int(teacher_profile.total_reviews or 0),
        )
        for user, teacher_profile in rows
    ]


@router.get("/me")
def get_my_profile(
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    student_profile = None
    teacher_profile = None
    if user.role == "student":
        student_profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    elif user.role == "teacher":
        teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()

    return _serialize_profile(
        user,
        student_profile,
        teacher_profile,
        include_private_user_fields=True,
        include_sensitive_bank_fields=user.role in {"teacher", "student"},
    )


@router.get("/{user_id}")
def get_user_profile(
    user_id: str,
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    requester = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not requester:
        raise HTTPException(status_code=404, detail="User not found")

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    student_profile = None
    teacher_profile = None
    if user.role == "student":
        student_profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    elif user.role == "teacher":
        teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()

    return _serialize_profile(
        user,
        student_profile,
        teacher_profile,
        include_private_user_fields=requester.role == "admin" or requester.id == user.id,
        include_sensitive_bank_fields=requester.role == "admin" or requester.id == user.id,
    )


@router.put("/me")
def update_my_profile(
    payload: ProfileUpdateRequest,
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    payload_data = payload.model_dump(exclude_unset=True)

    if "full_name" in payload_data:
        user.full_name = payload_data.get("full_name") or user.full_name
    if "phone" in payload_data:
        user.phone = payload_data.get("phone")
    if "avatar_url" in payload_data:
        user.avatar_url = payload_data.get("avatar_url")

    student_profile = None
    teacher_profile = None

    if user.role == "student":
        student_profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
        if not student_profile:
            student_profile = StudentProfile(user_id=user.id)
            db.add(student_profile)

        if "english_level" in payload_data:
            student_profile.english_level = payload_data.get("english_level")
        if "learning_goal" in payload_data:
            learning_goal = payload_data.get("learning_goal")
            student_profile.learning_goals = [learning_goal] if learning_goal else []
        if "bank_name" in payload_data:
            student_profile.bank_name = payload_data.get("bank_name")
        if "bank_bin" in payload_data:
            student_profile.bank_bin = payload_data.get("bank_bin")
        if "bank_account_number" in payload_data:
            student_profile.bank_account_number = payload_data.get("bank_account_number")
        if "bank_account_holder" in payload_data:
            student_profile.bank_account_holder = payload_data.get("bank_account_holder")

        if _BANK_ACCOUNT_FIELDS.intersection(payload_data):
            bank_bin = (student_profile.bank_bin or "").strip()
            bank_account_number = (student_profile.bank_account_number or "").strip()
            if (bank_bin or bank_account_number) and (not bank_bin or not bank_account_number):
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "Thong tin ngan hang chua day du. "
                        "Can nhap ca bank_bin va bank_account_number."
                    ),
                )

    elif user.role == "teacher":
        teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()
        if not teacher_profile:
            teacher_profile = TeacherProfile(user_id=user.id)
            db.add(teacher_profile)

        if "bio" in payload_data:
            teacher_profile.bio = payload_data.get("bio")
        if "years_of_experience" in payload_data:
            teacher_profile.years_experience = payload_data.get("years_of_experience")
        if "specialization" in payload_data:
            teacher_profile.native_language = payload_data.get("specialization")
        if "bank_name" in payload_data:
            teacher_profile.bank_name = payload_data.get("bank_name")
        if "bank_bin" in payload_data:
            teacher_profile.bank_bin = payload_data.get("bank_bin")
        if "bank_account_number" in payload_data:
            teacher_profile.bank_account_number = payload_data.get("bank_account_number")
        if "bank_account_holder" in payload_data:
            teacher_profile.bank_account_holder = payload_data.get("bank_account_holder")
        if "certifications" in payload_data:
            teacher_profile.certifications = payload_data.get("certifications") or []
        if "verification_docs" in payload_data:
            teacher_profile.verification_docs = payload_data.get("verification_docs") or []

        if _BANK_ACCOUNT_FIELDS.intersection(payload_data):
            bank_bin = (teacher_profile.bank_bin or "").strip()
            bank_account_number = (teacher_profile.bank_account_number or "").strip()
            if (bank_bin or bank_account_number) and (not bank_bin or not bank_account_number):
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "Thong tin ngan hang nhan payout chua day du. "
                        "Can nhap ca bank_bin va bank_account_number."
                    ),
                )

    db.commit()
    db.refresh(user)
    if student_profile:
        db.refresh(student_profile)
    if teacher_profile:
        db.refresh(teacher_profile)

    return _serialize_profile(
        user,
        student_profile,
        teacher_profile,
        include_private_user_fields=True,
        include_sensitive_bank_fields=user.role in {"teacher", "student"},
    )


@router.post(
    "/me/payout-bank-account/verify",
    response_model=PayoutBankAccountVerificationResponse,
)
def verify_my_payout_bank_account(
    payload: PayoutBankAccountVerificationRequest,
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role not in {"teacher", "student"}:
        raise HTTPException(
            status_code=403,
            detail="Chi hoc vien hoac tutor moi duoc kiem tra tai khoan ngan hang",
        )

    try:
        result = verify_provider_payout_destination(
            provider=PAYOS_PROVIDER,
            to_bin=payload.bank_bin,
            to_account_number=payload.bank_account_number,
        )
    except PaymentGatewayError as exc:
        raise HTTPException(
            status_code=502,
            detail=_map_payout_bank_verification_error_detail(exc),
        ) from exc

    return PayoutBankAccountVerificationResponse(
        provider=result.provider,
        is_valid=result.is_valid,
        message=result.message or (
            "payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay"
            if result.is_valid
            else "payOS bao khong the hoan tat buoc kiem tra so bo tai khoan nhan tien nay"
        ),
        estimate_credit=result.estimate_credit,
    )
