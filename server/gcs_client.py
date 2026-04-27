import io
import os
from pathlib import Path
import uuid

from google.cloud import storage

GCS_PROJECT = os.getenv("GCS_PROJECT")
APP_ENV = (os.getenv("APP_ENV", "development") or "development").strip().lower()
SERVER_PUBLIC_URL = (os.getenv("SERVER_PUBLIC_URL", "http://127.0.0.1:8000") or "").rstrip("/")
STATIC_PUBLIC_URL = (os.getenv("STATIC_PUBLIC_URL", "") or "").rstrip("/")
LOCAL_UPLOAD_ROOT = Path(os.getenv("LOCAL_UPLOAD_ROOT", "uploads"))

BUCKET_THUMBNAILS = "econnect-class-thumbnails"
BUCKET_AVATARS = "econnect-user-avatars"
BUCKET_TEACHER_DOCS = "econnect-teacher-docs"
BUCKET_CLASS_MATERIALS = "econnect-class-materials"

LOCAL_FOLDERS = {
    BUCKET_THUMBNAILS: "class-thumbnails",
    BUCKET_AVATARS: "user-avatars",
    BUCKET_TEACHER_DOCS: "teacher-docs",
    BUCKET_CLASS_MATERIALS: "class-materials",
}

_client: storage.Client | None = None


def _storage_client() -> storage.Client:
    global _client
    if _client is None:
        _client = storage.Client(project=GCS_PROJECT)
    return _client


def _extension_from_content_type(content_type: str) -> str:
    return {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
        "application/pdf": "pdf",
        "application/msword": "doc",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
    }.get(content_type, content_type.split("/")[-1])


def _local_upload(bucket_name: str, file_data: bytes, content_type: str) -> str:
    folder = LOCAL_FOLDERS[bucket_name]
    ext = _extension_from_content_type(content_type)
    object_name = f"{uuid.uuid4()}.{ext}"
    target_dir = LOCAL_UPLOAD_ROOT / folder
    target_dir.mkdir(parents=True, exist_ok=True)
    (target_dir / object_name).write_bytes(file_data)

    public_base_url = STATIC_PUBLIC_URL or SERVER_PUBLIC_URL
    return f"{public_base_url}/static/{folder}/{object_name}"


def _should_use_local_storage() -> bool:
    return APP_ENV != "production" and os.getenv("GCS_FORCE_REMOTE", "").lower() not in {
        "1",
        "true",
        "yes",
        "on",
    }


def _upload(bucket_name: str, file_data: bytes, content_type: str) -> str:
    if _should_use_local_storage():
        return _local_upload(bucket_name, file_data, content_type)

    ext = _extension_from_content_type(content_type)
    object_name = f"{uuid.uuid4()}.{ext}"
    bucket = _storage_client().bucket(bucket_name)
    blob = bucket.blob(object_name)
    blob.upload_from_file(io.BytesIO(file_data), content_type=content_type)
    return f"https://storage.googleapis.com/{bucket_name}/{object_name}"


def _delete(bucket_name: str, url: str) -> None:
    if _should_use_local_storage():
        return

    try:
        object_name = url.split(f"/{bucket_name}/")[-1]
        blob = _storage_client().bucket(bucket_name).blob(object_name)
        blob.delete()
    except Exception:
        pass


def upload_thumbnail(file_data: bytes, content_type: str) -> str:
    return _upload(BUCKET_THUMBNAILS, file_data, content_type)


def delete_thumbnail(url: str) -> None:
    _delete(BUCKET_THUMBNAILS, url)


def upload_avatar(file_data: bytes, content_type: str) -> str:
    return _upload(BUCKET_AVATARS, file_data, content_type)


def delete_avatar(url: str) -> None:
    _delete(BUCKET_AVATARS, url)


def upload_teacher_document(file_data: bytes, content_type: str) -> str:
    return _upload(BUCKET_TEACHER_DOCS, file_data, content_type)


def delete_teacher_document(url: str) -> None:
    _delete(BUCKET_TEACHER_DOCS, url)


def upload_class_material(file_data: bytes, content_type: str) -> str:
    return _upload(BUCKET_CLASS_MATERIALS, file_data, content_type)


def delete_class_material(url: str) -> None:
    _delete(BUCKET_CLASS_MATERIALS, url)
