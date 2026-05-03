from fastapi import APIRouter, Depends, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from models.user import User
from pydantic_schemas.user_search import PublicUserSearchResult

router = APIRouter()


def _public_search_subtitle(user: User) -> str:
    if user.role == "teacher":
        return "Ho so tutor cong khai"
    if user.role == "admin":
        return "Ho so admin cong khai"
    return "Ho so hoc vien cong khai"


@router.get("/search", response_model=list[PublicUserSearchResult])
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
            "email": _public_search_subtitle(user),
            "full_name": user.full_name,
            "avatar_url": user.avatar_url,
            "role": user.role,
        }
        for user in rows
    ]
