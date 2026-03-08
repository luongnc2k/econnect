from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from minio_client import delete_avatar, upload_avatar, upload_thumbnail
from models.user import User

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_THUMBNAIL  = 5 * 1024 * 1024  # 5MB
MAX_AVATAR     = 2 * 1024 * 1024  # 2MB


@router.post("/thumbnail")
async def upload_class_thumbnail(
    file: UploadFile = File(...),
    user: dict = Depends(auth_middleware),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận JPEG, PNG, WebP")

    data = await file.read()
    if len(data) > MAX_THUMBNAIL:
        raise HTTPException(status_code=400, detail="File quá lớn (tối đa 5MB)")

    url = upload_thumbnail(data, file.content_type)
    return {"url": url}


@router.post("/avatar")
async def upload_user_avatar(
    file: UploadFile = File(...),
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận JPEG, PNG, WebP")

    data = await file.read()
    if len(data) > MAX_AVATAR:
        raise HTTPException(status_code=400, detail="File quá lớn (tối đa 2MB)")

    user = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User không tồn tại")

    # Xoá avatar cũ nếu có
    if user.avatar_url:
        delete_avatar(user.avatar_url)

    url = upload_avatar(data, file.content_type)
    user.avatar_url = url
    db.commit()

    return {"url": url}
