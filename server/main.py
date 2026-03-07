from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from models.base import Base
from database import engine
from routes import auth, upload, classes, topics

# Import all models so Base.metadata knows about them
from models.user import User
from models.topic import Topic
from models.teacher_profile import TeacherProfile
from models.student_profile import StudentProfile
from models.teacher_specialty import TeacherSpecialty
from models.class_ import Class
from models.booking import Booking

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth")
app.include_router(upload.router, prefix="/upload")
app.include_router(classes.router, prefix="/classes")
app.include_router(topics.router, prefix="/topics")

# Base.metadata.drop_all(bind=engine)
Base.metadata.create_all(bind=engine)