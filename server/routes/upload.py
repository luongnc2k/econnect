import logging

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from database import get_db
from middleware.auth_middleware import auth_middleware
from minio_client import delete_avatar, upload_avatar, upload_thumbnail
from models.user import User

router = APIRouter()
logger = logging.getLogger(__name__)

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
CONTENT_TYPE_ALIASES = {"image/jpg": "image/jpeg"}
EXTENSION_TO_CONTENT_TYPE = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}
MAX_THUMBNAIL = 5 * 1024 * 1024  # 5MB
MAX_AVATAR = 5 * 1024 * 1024  # 5MB


def _normalize_content_type(content_type: str | None) -> str | None:
    if not content_type:
        return None
    lowered = content_type.lower().strip()
    return CONTENT_TYPE_ALIASES.get(lowered, lowered)


def _resolve_content_type(file: UploadFile) -> str | None:
    content_type = _normalize_content_type(file.content_type)
    if content_type and content_type != "application/octet-stream":
        return content_type

    filename = (file.filename or "").lower().strip()
    if "." not in filename:
        return content_type

    ext = filename.rsplit(".", 1)[-1]
    return EXTENSION_TO_CONTENT_TYPE.get(ext, content_type)


@router.post("/thumbnail")
async def upload_class_thumbnail(
    file: UploadFile = File(...),
    user: dict = Depends(auth_middleware),
):
    content_type = _resolve_content_type(file)
    if content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image content_type: {file.content_type}",
        )

    data = await file.read()
    if len(data) > MAX_THUMBNAIL:
        raise HTTPException(
            status_code=400,
            detail=f"File too large: {len(data)} bytes (max {MAX_THUMBNAIL} bytes)",
        )

    try:
        url = upload_thumbnail(data, content_type)
    except Exception:
        logger.exception("Failed to upload thumbnail to object storage")
        raise HTTPException(
            status_code=503,
            detail="Dich vu luu tru tam thoi khong kha dung",
        )

    return {"url": url}


@router.post("/avatar")
async def upload_user_avatar(
    file: UploadFile = File(...),
    user_dict: dict = Depends(auth_middleware),
    db: Session = Depends(get_db),
):
    content_type = _resolve_content_type(file)
    if content_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image content_type: {file.content_type}",
        )

    data = await file.read()
    if len(data) > MAX_AVATAR:
        raise HTTPException(
            status_code=400,
            detail=f"File too large: {len(data)} bytes (max {MAX_AVATAR} bytes)",
        )

    user = db.query(User).filter(User.id == user_dict["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    old_avatar_url = user.avatar_url
    try:
        url = upload_avatar(data, content_type)
    except Exception:
        logger.exception("Failed to upload avatar to object storage")
        raise HTTPException(
            status_code=503,
            detail="Dich vu luu tru tam thoi khong kha dung",
        )

    user.avatar_url = url
    db.commit()

    if old_avatar_url:
        delete_avatar(old_avatar_url)

    return {"url": url}
