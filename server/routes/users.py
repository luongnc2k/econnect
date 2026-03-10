from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.user import User

router = APIRouter()


@router.get("/search")
def search_users(
    q: str = Query(min_length=1, description="Search by full name or phone"),
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    keyword = q.strip()
    if not keyword:
        return []

    rows = (
        db.query(User)
        .filter(User.id != user_dict["uid"])
        .filter(
            or_(
                User.full_name.ilike(f"%{keyword}%"),
                User.phone.ilike(f"%{keyword}%"),
            )
        )
        .order_by(User.full_name.asc())
        .limit(20)
        .all()
    )

    return [
        {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "phone": user.phone,
            "avatar_url": user.avatar_url,
            "role": user.role,
            "is_active": user.is_active,
        }
        for user in rows
    ]
