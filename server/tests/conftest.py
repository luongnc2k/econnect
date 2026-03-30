import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import SQLAlchemyError


SERVER_DIR = Path(__file__).resolve().parents[1]
TEST_UPLOAD_ROOT = SERVER_DIR / ".test_uploads"
DEFAULT_TEST_DATABASE_URL = "postgresql+psycopg2://postgres:123456a%40@localhost:5433/econnect_test"

if str(SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(SERVER_DIR))

os.environ["DATABASE_URL"] = os.getenv("ECONNECT_TEST_DATABASE_URL", DEFAULT_TEST_DATABASE_URL)
os.environ["JWT_SECRET"] = os.getenv("JWT_SECRET", "test_jwt_secret_change_me_please_32bytes")
os.environ["ADMIN_CREATE_SECRET"] = os.getenv("ADMIN_CREATE_SECRET", "test-admin-secret")
os.environ["JOB_SECRET"] = os.getenv("JOB_SECRET", "test-job-secret")
os.environ["APP_ENV"] = os.getenv("APP_ENV", "development")
os.environ["STRICT_STARTUP_VALIDATION"] = os.getenv("STRICT_STARTUP_VALIDATION", "false")
os.environ["SERVER_PUBLIC_URL"] = os.getenv("SERVER_PUBLIC_URL", "http://127.0.0.1:8000")
os.environ["STATIC_PUBLIC_URL"] = os.getenv("STATIC_PUBLIC_URL", "http://127.0.0.1:8000")
os.environ["PAYMENT_PUBLIC_BASE_URL"] = os.getenv("PAYMENT_PUBLIC_BASE_URL", "http://127.0.0.1:8000")
os.environ["PAYMENT_GATEWAY_MODE"] = "mock"
os.environ["PAYOS_MOCK_MODE"] = "true"
os.environ["PAYOS_PAYOUT_MOCK_MODE"] = "true"
os.environ["AUTO_INIT_SCHEMA"] = "false"
os.environ["INTERNAL_JOB_RUNNER_ENABLED"] = "false"
os.environ["ALLOW_DIRECT_CLASS_CREATION"] = "false"
os.environ["ALLOW_LEGACY_JWT_SECRET"] = "false"
os.environ["LOCAL_UPLOAD_ROOT"] = str(TEST_UPLOAD_ROOT)
os.environ["NOTIFICATION_WS_POLL_SECONDS"] = os.getenv("NOTIFICATION_WS_POLL_SECONDS", "0.1")
os.environ["NOTIFICATION_WS_HEARTBEAT_SECONDS"] = os.getenv("NOTIFICATION_WS_HEARTBEAT_SECONDS", "0.4")
_REQUIRE_TEST_DATABASE = os.getenv("REQUIRE_TEST_DATABASE", os.getenv("CI", "")).strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}
_TEST_DATABASE_AVAILABLE = True
_TEST_DATABASE_UNAVAILABLE_REASON = ""


def _ensure_test_database_exists(database_url: str) -> None:
    global _TEST_DATABASE_AVAILABLE, _TEST_DATABASE_UNAVAILABLE_REASON
    url = make_url(database_url)
    target_database = url.database
    if not target_database:
        return

    admin_database = "postgres" if target_database != "postgres" else "template1"
    admin_url = url.set(database=admin_database)
    admin_engine = create_engine(
        admin_url,
        isolation_level="AUTOCOMMIT",
        pool_pre_ping=True,
    )

    try:
        try:
            with admin_engine.connect() as connection:
                exists = connection.execute(
                    text("SELECT 1 FROM pg_database WHERE datname = :db_name"),
                    {"db_name": target_database},
                ).scalar()
                if not exists:
                    connection.execute(text(f'CREATE DATABASE "{target_database}"'))
        except SQLAlchemyError as exc:
            _TEST_DATABASE_AVAILABLE = False
            _TEST_DATABASE_UNAVAILABLE_REASON = str(exc)
            if _REQUIRE_TEST_DATABASE:
                raise
    finally:
        admin_engine.dispose()


_ensure_test_database_exists(os.environ["DATABASE_URL"])

from database import SessionLocal, engine
from main import app
from models.base import Base

# Import all models so metadata includes every table used by the app.
from models.booking import Booking  # noqa: F401
from models.class_ import Class  # noqa: F401
from models.learning_location import LearningLocation  # noqa: F401
from models.payment import Payment  # noqa: F401
from models.notification import Notification  # noqa: F401
from models.push_device_token import PushDeviceToken  # noqa: F401
from models.student_profile import StudentProfile  # noqa: F401
from models.teacher_profile import TeacherProfile  # noqa: F401
from models.teacher_specialty import TeacherSpecialty  # noqa: F401
from models.topic import Topic  # noqa: F401
from models.user import User  # noqa: F401


@pytest.fixture(autouse=True)
def reset_database():
    if not _TEST_DATABASE_AVAILABLE:
        pytest.skip(f"Test database is unavailable: {_TEST_DATABASE_UNAVAILABLE_REASON}")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client
