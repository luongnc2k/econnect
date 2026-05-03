"""
Seed script — chạy một lần để tạo dữ liệu mẫu.
Usage: python seed.py
"""
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt

from database import SessionLocal
from learning_location_service import DEFAULT_LEARNING_LOCATIONS
from models.base import Base
from models.learning_location import LearningLocation
from models.user import User
from models.topic import Topic
from models.teacher_profile import TeacherProfile
from models.teacher_specialty import TeacherSpecialty
from models.class_ import Class
from pydantic_schemas.payment import calculate_creation_fee

# ── helpers ──────────────────────────────────────────────────────────────────

def _id() -> str:
    return str(uuid.uuid4())

def _hash(pw: str) -> bytes:
    return bcrypt.hashpw(pw.encode(), bcrypt.gensalt())

def _future(days: int = 0, hour: int = 9, minute: int = 0) -> datetime:
    now = datetime.now(timezone.utc)
    base = now + timedelta(days=days)
    return base.replace(hour=hour, minute=minute, second=0, microsecond=0)

# ── seed ─────────────────────────────────────────────────────────────────────

def seed():
    db = SessionLocal()
    try:
        # ── Topics ───────────────────────────────────────────────────────────
        topics_data = [
            {
                "name": "Giao tiếp",
                "slug": "giao-tiep",
                "icon": "💬",
                "description": "Luyện phản xạ giao tiếp, nói tự nhiên và xử lý các tình huống hằng ngày.",
            },
            {
                "name": "IELTS",
                "slug": "ielts",
                "icon": "📝",
                "description": "Phù hợp với lớp luyện IELTS theo mục tiêu điểm và kỹ năng cụ thể.",
            },
            {
                "name": "Business",
                "slug": "business",
                "icon": "💼",
                "description": "Tập trung vào tiếng Anh công việc như họp, email, thuyết trình và phỏng vấn.",
            },
            {
                "name": "Phát âm",
                "slug": "phat-am",
                "icon": "🎤",
                "description": "Luyện phát âm, trọng âm, ngữ điệu và sửa các lỗi nói phổ biến.",
            },
            {
                "name": "Cơ bản",
                "slug": "co-ban",
                "icon": "📚",
                "description": "Dành cho người mới bắt đầu muốn xây nền tảng từ vựng và mẫu câu cơ bản.",
            },
        ]
        topics = {}
        for t in topics_data:
            existing = db.query(Topic).filter(Topic.slug == t["slug"]).first()
            if not existing:
                topic = Topic(id=_id(), is_active=True, **t)
                db.add(topic)
                db.flush()
                topics[t["slug"]] = topic
            else:
                existing.name = t["name"]
                existing.description = t["description"]
                existing.icon = t["icon"]
                existing.is_active = True
                topics[t["slug"]] = existing

        learning_locations_data = DEFAULT_LEARNING_LOCATIONS
        default_locations_by_id = {
            location["id"]: location for location in learning_locations_data
        }
        for location_data in learning_locations_data:
            existing_location = (
                db.query(LearningLocation)
                .filter(LearningLocation.id == location_data["id"])
                .first()
            )
            if not existing_location:
                db.add(
                    LearningLocation(
                        is_active=True,
                        **location_data,
                    )
                )
            else:
                existing_location.name = location_data["name"]
                existing_location.address = location_data["address"]
                existing_location.notes = location_data["notes"]
                existing_location.is_active = True

        # ── Teachers ──────────────────────────────────────────────────────────

        teachers_data = [
            {
                "email": "alexander@example.com",
                "full_name": "Alexander Ng",
                "profile": {
                    "bio": "Native English speaker, 8 years teaching Business English.",
                    "nationality": "Singapore",
                    "native_language": "English",
                    "bank_name": "Vietcombank",
                    "bank_bin": "970436",
                    "bank_account_number": "0011002233445",
                    "bank_account_holder": "ALEXANDER NG",
                    "years_experience": 8,
                    "rating_avg": 4.8,
                    "total_sessions": 150,
                    "total_reviews": 120,
                    "is_verified": True,
                },
                "specialties": ["business", "giao-tiep"],
            },
            {
                "email": "sarah@example.com",
                "full_name": "Sarah Johnson",
                "profile": {
                    "bio": "IELTS examiner with 10 years of experience.",
                    "nationality": "UK",
                    "native_language": "English",
                    "bank_name": "Techcombank",
                    "bank_bin": "970407",
                    "bank_account_number": "1903004455667",
                    "bank_account_holder": "SARAH JOHNSON",
                    "years_experience": 10,
                    "rating_avg": 4.9,
                    "total_sessions": 230,
                    "total_reviews": 200,
                    "is_verified": True,
                },
                "specialties": ["ielts", "giao-tiep"],
            },
        ]

        teacher_users = {}
        for t in teachers_data:
            existing = db.query(User).filter(User.email == t["email"]).first()
            if existing:
                teacher_users[t["email"]] = existing
                continue

            user = User(
                id=_id(),
                email=t["email"],
                password_hash=_hash("password123"),
                full_name=t["full_name"],
                role="teacher",
                is_active=True,
            )
            db.add(user)
            db.flush()

            profile = TeacherProfile(user_id=user.id, **t["profile"])
            db.add(profile)

            for slug in t["specialties"]:
                specialty = TeacherSpecialty(
                    teacher_id=user.id,
                    topic_id=topics[slug].id,
                )
                db.add(specialty)

            teacher_users[t["email"]] = user

        # ── Classes ───────────────────────────────────────────────────────────
        
        classes_data = [
            {
                "teacher_email": "alexander@example.com",
                "topic_slug": "business",
                "title": "Luyện nói Business English",
                "description": (
                    "Buổi luyện tập giao tiếp tiếng Anh trong môi trường kinh doanh. "
                    "Thảo luận case study thực tế, roleplay tình huống thương lượng và thuyết trình."
                ),
                "level": "intermediate",
                "location_name": default_locations_by_id["hn-cafe-highlands-cau-giay"]["name"],
                "location_address": default_locations_by_id["hn-cafe-highlands-cau-giay"]["address"],
                "start_time": _future(days=0, hour=18, minute=30),
                "end_time":   _future(days=0, hour=20, minute=0),
                "max_participants": 6,
                "current_participants": 3,
                "price": 120000,
                "creation_fee_amount": calculate_creation_fee(120000),
                "creation_payment_status": "paid",
                "status": "scheduled",
                "tutor_payout_status": "pending",
                "tutor_payout_amount": 0,
            },
            {
                "teacher_email": "sarah@example.com",
                "topic_slug": "ielts",
                "title": "IELTS Speaking Practice",
                "description": (
                    "Luyện tập kỹ năng nói IELTS theo format thực tế. "
                    "Tập trung vào Part 2 và Part 3, phản hồi chi tiết từ giảng viên có kinh nghiệm."
                ),
                "level": "advanced",
                "location_name": default_locations_by_id["hn-cafe-the-coffee-house-hoan-kiem"]["name"],
                "location_address": default_locations_by_id["hn-cafe-the-coffee-house-hoan-kiem"]["address"],
                "start_time": _future(days=1, hour=9, minute=0),
                "end_time":   _future(days=1, hour=10, minute=30),
                "max_participants": 6,
                "current_participants": 4,
                "price": 150000,
                "creation_fee_amount": calculate_creation_fee(150000),
                "creation_payment_status": "paid",
                "status": "scheduled",
                "tutor_payout_status": "pending",
                "tutor_payout_amount": 0,
            },
            {
                "teacher_email": "alexander@example.com",
                "topic_slug": "giao-tiep",
                "title": "Free Talk — Chủ đề Du lịch",
                "description": "Trò chuyện tự do về chủ đề du lịch, mở rộng vốn từ và phản xạ giao tiếp.",
                "level": "beginner",
                "location_name": default_locations_by_id["hn-cafe-cong-trieu-viet-vuong"]["name"],
                "location_address": default_locations_by_id["hn-cafe-cong-trieu-viet-vuong"]["address"],
                "start_time": _future(days=2, hour=10, minute=0),
                "end_time":   _future(days=2, hour=11, minute=30),
                "max_participants": 8,
                "current_participants": 1,
                "price": 90000,
                "creation_fee_amount": calculate_creation_fee(90000),
                "creation_payment_status": "paid",
                "status": "scheduled",
                "tutor_payout_status": "pending",
                "tutor_payout_amount": 0,
            },
            {
                "teacher_email": "sarah@example.com",
                "topic_slug": "phat-am",
                "title": "Pronunciation Bootcamp",
                "description": "Sửa phát âm các âm khó, luyện trọng âm từ và ngữ điệu câu.",
                "level": "intermediate",
                "location_name": default_locations_by_id["hn-cafe-cong-trieu-viet-vuong"]["name"],
                "location_address": default_locations_by_id["hn-cafe-cong-trieu-viet-vuong"]["address"],
                "start_time": _future(days=3, hour=14, minute=0),
                "end_time":   _future(days=3, hour=15, minute=30),
                "max_participants": 5,
                "current_participants": 0,
                "price": 100000,
                "creation_fee_amount": calculate_creation_fee(100000),
                "creation_payment_status": "paid",
                "status": "scheduled",
                "tutor_payout_status": "pending",
                "tutor_payout_amount": 0,
            },
        ]

        for c in classes_data:
            teacher = teacher_users[c.pop("teacher_email")]
            topic = topics[c.pop("topic_slug")]
            existing = db.query(Class).filter(
                Class.teacher_id == teacher.id,
                Class.title == c["title"],
            ).first()
            if not existing:
                cls = Class(
                    id=_id(),
                    teacher_id=teacher.id,
                    topic_id=topic.id,
                    topic=topic.name,
                    **c,
                )
                db.add(cls)
            else:
                existing.topic_id = topic.id
                existing.topic = topic.name

        db.commit()
        print("✓ Seed completed.")

    except Exception as e:
        db.rollback()
        print(f"✗ Seed failed: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed()
