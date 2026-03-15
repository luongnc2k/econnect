from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.student_profile import StudentProfile
from models.teacher_profile import TeacherProfile
from models.user import User

router = APIRouter()


def _serialize_profile(
    user: User,
    student_profile: StudentProfile | None,
    teacher_profile: TeacherProfile | None,
) -> dict:
    data = {
        "id": user.id,
        "email": user.email,
        "full_name": user.full_name,
        "phone": user.phone,
        "avatar_url": user.avatar_url,
        "role": user.role,
        "is_active": user.is_active,
        "last_login_at": user.last_login_at.isoformat() if user.last_login_at else None,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "updated_at": user.updated_at.isoformat() if user.updated_at else None,
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
                "bank_name": teacher_profile.bank_name if teacher_profile else None,
                "bank_account_number": teacher_profile.bank_account_number if teacher_profile else None,
                "bank_account_holder": teacher_profile.bank_account_holder if teacher_profile else None,
                "years_of_experience": teacher_profile.years_experience if teacher_profile else 0,
                "rating": float(teacher_profile.rating_avg) if teacher_profile else 0.0,
                "total_students": teacher_profile.total_sessions if teacher_profile else 0,
                "bio": teacher_profile.bio if teacher_profile else None,
                "hourly_rate": None,
                "certifications": list(teacher_profile.certifications or []) if teacher_profile else [],
                "verification_docs": list(teacher_profile.verification_docs or []) if teacher_profile else [],
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

    return _serialize_profile(user, student_profile, teacher_profile)


@router.get("/{user_id}")
def get_user_profile(
    user_id: str,
    _: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    student_profile = None
    teacher_profile = None
    if user.role == "student":
        student_profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
    elif user.role == "teacher":
        teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()

    return _serialize_profile(user, student_profile, teacher_profile)


@router.put("/me")
def update_my_profile(
    payload: dict,
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if "full_name" in payload:
        user.full_name = (payload.get("full_name") or "").strip() or user.full_name
    if "phone" in payload:
        user.phone = payload.get("phone")
    if "avatar_url" in payload:
        user.avatar_url = payload.get("avatar_url")

    student_profile = None
    teacher_profile = None

    if user.role == "student":
        student_profile = db.query(StudentProfile).filter(StudentProfile.user_id == user.id).first()
        if not student_profile:
            student_profile = StudentProfile(user_id=user.id)
            db.add(student_profile)

        if "english_level" in payload:
            student_profile.english_level = payload.get("english_level")
        if "learning_goal" in payload:
            learning_goal = payload.get("learning_goal")
            student_profile.learning_goals = [learning_goal] if learning_goal else []

    elif user.role == "teacher":
        teacher_profile = db.query(TeacherProfile).filter(TeacherProfile.user_id == user.id).first()
        if not teacher_profile:
            teacher_profile = TeacherProfile(user_id=user.id)
            db.add(teacher_profile)

        if "bio" in payload:
            teacher_profile.bio = payload.get("bio")
        if "years_of_experience" in payload:
            years = payload.get("years_of_experience")
            teacher_profile.years_experience = int(years) if years is not None else None
        if "specialization" in payload:
            teacher_profile.native_language = payload.get("specialization")
        if "bank_name" in payload:
            teacher_profile.bank_name = (payload.get("bank_name") or "").strip() or None
        if "bank_account_number" in payload:
            teacher_profile.bank_account_number = (payload.get("bank_account_number") or "").strip() or None
        if "bank_account_holder" in payload:
            teacher_profile.bank_account_holder = (payload.get("bank_account_holder") or "").strip() or None
        if "certifications" in payload:
            certifications = payload.get("certifications")
            if isinstance(certifications, list):
                teacher_profile.certifications = [str(item).strip() for item in certifications if str(item).strip()]
            elif isinstance(certifications, str):
                teacher_profile.certifications = [
                    item.strip()
                    for item in certifications.split(",")
                    if item.strip()
                ]
            else:
                teacher_profile.certifications = []
        if "verification_docs" in payload:
            docs = payload.get("verification_docs")
            if isinstance(docs, list):
                teacher_profile.verification_docs = [str(item).strip() for item in docs if str(item).strip()]

    db.commit()
    db.refresh(user)
    if student_profile:
        db.refresh(student_profile)
    if teacher_profile:
        db.refresh(teacher_profile)

    return _serialize_profile(user, student_profile, teacher_profile)
