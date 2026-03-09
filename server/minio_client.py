import io
import os
import uuid
from pathlib import Path
from urllib.parse import urlparse

import urllib3
from minio import Minio
from minio.error import S3Error

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")
MINIO_PUBLIC_URL = os.getenv("MINIO_PUBLIC_URL", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin123")
SERVER_PUBLIC_URL = os.getenv("SERVER_PUBLIC_URL", "http://127.0.0.1:8000")
UPLOAD_ROOT = Path(os.getenv("LOCAL_UPLOAD_ROOT", "uploads"))
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)

BUCKET_THUMBNAILS = "class-thumbnails"
BUCKET_AVATARS = "user-avatars"

client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False,
    http_client=urllib3.PoolManager(
        timeout=urllib3.Timeout(connect=2.0, read=5.0),
        retries=urllib3.Retry(
            total=0,
            connect=0,
            read=0,
            redirect=0,
            status=0,
        ),
    ),
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


def _local_upload(folder: str, file_data: bytes, content_type: str) -> str:
    ext = content_type.split("/")[-1]
    object_name = f"{uuid.uuid4()}.{ext}"
    target_dir = UPLOAD_ROOT / folder
    target_dir.mkdir(parents=True, exist_ok=True)
    target_path = target_dir / object_name
    target_path.write_bytes(file_data)
    return f"{SERVER_PUBLIC_URL}/static/{folder}/{object_name}"


def _delete(bucket: str, url: str) -> None:
    try:
        object_name = url.split(f"/{bucket}/")[-1]
        client.remove_object(bucket, object_name)
    except S3Error:
        pass


def _local_delete(url: str) -> None:
    try:
        parsed = urlparse(url)
        if not parsed.path.startswith("/static/"):
            return
        relative_path = parsed.path.removeprefix("/static/")
        target_path = UPLOAD_ROOT / relative_path
        if target_path.exists() and target_path.is_file():
            target_path.unlink()
    except OSError:
        pass


def upload_thumbnail(file_data: bytes, content_type: str) -> str:
    try:
        return _upload(BUCKET_THUMBNAILS, file_data, content_type)
    except Exception:
        return _local_upload(BUCKET_THUMBNAILS, file_data, content_type)


def delete_thumbnail(url: str) -> None:
    if f"/{BUCKET_THUMBNAILS}/" in url:
        _delete(BUCKET_THUMBNAILS, url)
    else:
        _local_delete(url)


def upload_avatar(file_data: bytes, content_type: str) -> str:
    try:
        return _upload(BUCKET_AVATARS, file_data, content_type)
    except Exception:
        return _local_upload(BUCKET_AVATARS, file_data, content_type)


def delete_avatar(url: str) -> None:
    if f"/{BUCKET_AVATARS}/" in url:
        _delete(BUCKET_AVATARS, url)
    else:
        _local_delete(url)
