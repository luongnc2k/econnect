from contextlib import asynccontextmanager
import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from models.base import Base
from database import engine
from routes import auth, upload, classes, profile, users, payments, notifications, locations

# Import all models so Base.metadata knows about them
from models.user import User
from models.topic import Topic
from models.teacher_profile import TeacherProfile
from models.student_profile import StudentProfile
from models.teacher_specialty import TeacherSpecialty
from models.class_ import Class
from models.learning_location import LearningLocation
from models.booking import Booking
from models.payment import Payment
from models.notification import Notification
from models.push_device_token import PushDeviceToken
from runtime_checks import (
    app_environment,
    database_ready,
    runtime_summary,
    validate_runtime_configuration,
)
from schema_sync import sync_schema


def _env_flag(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _cors_origins() -> list[str]:
    raw_value = (os.getenv("CORS_ALLOW_ORIGINS", "") or "").strip()
    if raw_value:
        if raw_value == "*":
            return ["*"]
        return [origin.strip() for origin in raw_value.split(",") if origin.strip()]
    return [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ]


cors_origins = _cors_origins()


def _cors_origin_regex() -> str | None:
    raw_value = (os.getenv("CORS_ALLOW_ORIGIN_REGEX", "") or "").strip()
    if raw_value:
        return raw_value
    if app_environment() == "development":
        return r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$"
    return None


cors_origin_regex = _cors_origin_regex()
allow_credentials = cors_origins != ["*"]


@asynccontextmanager
async def lifespan(_: FastAPI):
    validate_runtime_configuration(cors_origins)
    if _env_flag("AUTO_INIT_SCHEMA", True):
        Base.metadata.create_all(bind=engine)
        sync_schema(engine)
    yield


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=cors_origin_regex,
    allow_credentials=allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth")
app.include_router(upload.router, prefix="/upload")
app.include_router(classes.router, prefix="/classes")
app.include_router(profile.router, prefix="/profile")
app.include_router(users.router, prefix="/users")
app.include_router(payments.router, prefix="/payments")
app.include_router(notifications.router, prefix="/notifications")
app.include_router(locations.router, prefix="/locations")

uploads_dir = Path(os.getenv("LOCAL_UPLOAD_ROOT", "uploads"))
uploads_dir.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=uploads_dir), name="static")


@app.get("/health/live")
def health_live() -> dict[str, object]:
    return {"status": "ok", **runtime_summary()}


@app.get("/health/ready")
def health_ready() -> dict[str, object]:
    db_ok, db_detail = database_ready(engine)
    if not db_ok:
        raise HTTPException(
            status_code=503,
            detail={
                "status": "degraded",
                "checks": {
                    "database": db_detail,
                },
                **runtime_summary(),
            },
        )
    return {
        "status": "ready",
        "checks": {
            "database": "ok",
        },
        **runtime_summary(),
    }
