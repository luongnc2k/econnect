from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from middleware.auth_middleware import auth_middleware
from minio_client import upload_thumbnail

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_SIZE_BYTES = 5 * 1024 * 1024  # 5MB


@router.post("/thumbnail")
async def upload_class_thumbnail(
    file: UploadFile = File(...),
    user: dict = Depends(auth_middleware),
):
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận JPEG, PNG, WebP")

    data = await file.read()

    if len(data) > MAX_SIZE_BYTES:
        raise HTTPException(status_code=400, detail="File quá lớn (tối đa 5MB)")

    url = upload_thumbnail(data, file.content_type)
    return {"url": url}
