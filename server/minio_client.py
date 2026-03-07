from minio import Minio
from minio.error import S3Error
import uuid
import os

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "localhost:9000")       # server dùng để kết nối MinIO
MINIO_PUBLIC_URL = os.getenv("MINIO_PUBLIC_URL", "http://localhost:9000")  # Flutter dùng để load ảnh
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin123")
MINIO_BUCKET = "class-thumbnails"

client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False,  # True nếu dùng HTTPS
)


def ensure_bucket():
    if not client.bucket_exists(MINIO_BUCKET):
        client.make_bucket(MINIO_BUCKET)
        # Public read policy để Flutter có thể hiển thị ảnh trực tiếp
        policy = f"""{{
            "Version": "2012-10-17",
            "Statement": [{{
                "Effect": "Allow",
                "Principal": {{"AWS": "*"}},
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::{MINIO_BUCKET}/*"
            }}]
        }}"""
        client.set_bucket_policy(MINIO_BUCKET, policy)


def upload_thumbnail(file_data: bytes, content_type: str) -> str:
    """Upload ảnh và trả về URL public."""
    ensure_bucket()

    ext = content_type.split("/")[-1]  # image/jpeg → jpeg
    object_name = f"{uuid.uuid4()}.{ext}"

    import io
    client.put_object(
        MINIO_BUCKET,
        object_name,
        io.BytesIO(file_data),
        length=len(file_data),
        content_type=content_type,
    )

    return f"{MINIO_PUBLIC_URL}/{MINIO_BUCKET}/{object_name}"


def delete_thumbnail(url: str):
    """Xóa ảnh theo URL."""
    try:
        # Tách object_name từ URL
        object_name = url.split(f"/{MINIO_BUCKET}/")[-1]
        client.remove_object(MINIO_BUCKET, object_name)
    except S3Error:
        pass
