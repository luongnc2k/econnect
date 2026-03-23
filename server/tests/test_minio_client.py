from pathlib import Path
from urllib.parse import urlparse

import minio_client


def _assert_local_upload_written(tmp_path: Path, public_url: str) -> None:
    parsed = urlparse(public_url)
    relative_path = parsed.path.removeprefix("/static/")
    target_path = tmp_path / relative_path
    assert target_path.exists()
    assert target_path.read_bytes() == b"test-image"


def test_local_upload_prefers_static_public_url(tmp_path, monkeypatch):
    monkeypatch.setattr(minio_client, "UPLOAD_ROOT", tmp_path)
    monkeypatch.setattr(minio_client, "STATIC_PUBLIC_URL", "http://assets.local:8000")
    monkeypatch.setattr(minio_client, "SERVER_PUBLIC_URL", "https://payos-callback.example.com")

    public_url = minio_client._local_upload(
        minio_client.BUCKET_THUMBNAILS,
        b"test-image",
        "image/png",
    )

    assert public_url.startswith("http://assets.local:8000/static/class-thumbnails/")
    _assert_local_upload_written(tmp_path, public_url)


def test_local_upload_falls_back_to_server_public_url(tmp_path, monkeypatch):
    monkeypatch.setattr(minio_client, "UPLOAD_ROOT", tmp_path)
    monkeypatch.setattr(minio_client, "STATIC_PUBLIC_URL", "")
    monkeypatch.setattr(minio_client, "SERVER_PUBLIC_URL", "http://127.0.0.1:8000")

    public_url = minio_client._local_upload(
        minio_client.BUCKET_TEACHER_DOCS,
        b"test-image",
        "image/jpeg",
    )

    assert public_url.startswith("http://127.0.0.1:8000/static/teacher-docs/")
    _assert_local_upload_written(tmp_path, public_url)
