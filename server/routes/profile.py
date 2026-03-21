from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.student_profile import StudentProfile
from models.teacher_profile import TeacherProfile
from models.user import User
from pydantic_schemas.profile import ProfileUpdateRequest

router = APIRouter()


def _serialize_profile(
    user: User,
    student_profile: StudentProfile | None,
    teacher_profile: TeacherProfile | None,
    *,
    include_private_user_fields: bool = True,
    include_sensitive_teacher_fields: bool = False,
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
                "total_lessons": student_profile.total_classes_attended if student_profile else 0,
                "average_score": None,
            }
        )
    elif user.role == "teacher":
        data.update(
            {
                "specialization": teacher_profile.native_language if teacher_profile else None,
                "bank_name": teacher_profile.bank_name if teacher_profile and include_sensitive_teacher_fields else None,
                "bank_bin": teacher_profile.bank_bin if teacher_profile and include_sensitive_teacher_fields else None,
                "bank_account_number": (
                    teacher_profile.bank_account_number
                    if teacher_profile and include_sensitive_teacher_fields
                    else None
                ),
                "bank_account_holder": (
                    teacher_profile.bank_account_holder
                    if teacher_profile and include_sensitive_teacher_fields
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
                    if teacher_profile and include_sensitive_teacher_fields
                    else []
                ),
            }
        )

    return data


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
        include_sensitive_teacher_fields=user.role == "teacher",
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
        include_sensitive_teacher_fields=requester.role == "admin" or requester.id == user.id,
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
        include_sensitive_teacher_fields=user.role == "teacher",
    )
