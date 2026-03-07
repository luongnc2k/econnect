import io
import os
import uuid

from minio import Minio
from minio.error import S3Error

MINIO_ENDPOINT   = os.getenv("MINIO_ENDPOINT",   "localhost:9000")
MINIO_PUBLIC_URL = os.getenv("MINIO_PUBLIC_URL",  "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY",  "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY",  "minioadmin123")

BUCKET_THUMBNAILS = "class-thumbnails"
BUCKET_AVATARS    = "user-avatars"

client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False,
)


def _ensure_bucket(bucket: str) -> None:
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
        policy = f"""{{
            "Version": "2012-10-17",
            "Statement": [{{
                "Effect": "Allow",
                "Principal": {{"AWS": "*"}},
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::{bucket}/*"
            }}]
        }}"""
        client.set_bucket_policy(bucket, policy)


def _upload(bucket: str, file_data: bytes, content_type: str) -> str:
    _ensure_bucket(bucket)
    ext = content_type.split("/")[-1]
    object_name = f"{uuid.uuid4()}.{ext}"
    client.put_object(
        bucket,
        object_name,
        io.BytesIO(file_data),
        length=len(file_data),
        content_type=content_type,
    )
    return f"{MINIO_PUBLIC_URL}/{bucket}/{object_name}"


def _delete(bucket: str, url: str) -> None:
    try:
        object_name = url.split(f"/{bucket}/")[-1]
        client.remove_object(bucket, object_name)
    except S3Error:
        pass


# ── Public API ────────────────────────────────────────────────────────────────

def upload_thumbnail(file_data: bytes, content_type: str) -> str:
    return _upload(BUCKET_THUMBNAILS, file_data, content_type)


def delete_thumbnail(url: str) -> None:
    _delete(BUCKET_THUMBNAILS, url)


def upload_avatar(file_data: bytes, content_type: str) -> str:
    return _upload(BUCKET_AVATARS, file_data, content_type)


def delete_avatar(url: str) -> None:
    _delete(BUCKET_AVATARS, url)
