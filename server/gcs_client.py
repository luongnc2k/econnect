import io
import os
import uuid

from google.cloud import storage

GCS_PROJECT = os.getenv("GCS_PROJECT")

BUCKET_THUMBNAILS = "econnect-class-thumbnails"
BUCKET_AVATARS = "econnect-user-avatars"
BUCKET_TEACHER_DOCS = "econnect-teacher-docs"

_client = storage.Client(project=GCS_PROJECT)


def _upload(bucket_name: str, file_data: bytes, content_type: str) -> str:
    ext = content_type.split("/")[-1]
    object_name = f"{uuid.uuid4()}.{ext}"
    bucket = _client.bucket(bucket_name)
    blob = bucket.blob(object_name)
    blob.upload_from_file(io.BytesIO(file_data), content_type=content_type)
    return f"https://storage.googleapis.com/{bucket_name}/{object_name}"


def _delete(bucket_name: str, url: str) -> None:
    try:
        object_name = url.split(f"/{bucket_name}/")[-1]
        blob = _client.bucket(bucket_name).blob(object_name)
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
