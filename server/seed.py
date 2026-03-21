"""
Seed script — chạy một lần để tạo dữ liệu mẫu.
Usage: python seed.py
"""
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt

from database import SessionLocal
from models.base import Base
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
            {"name": "Giao tiếp", "slug": "giao-tiep", "icon": "💬"},
            {"name": "IELTS",     "slug": "ielts",      "icon": "📝"},
            {"name": "Business",  "slug": "business",   "icon": "💼"},
            {"name": "Phát âm",   "slug": "phat-am",    "icon": "🎤"},
            {"name": "Cơ bản",    "slug": "co-ban",     "icon": "📚"},
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
                topics[t["slug"]] = existing

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
                "location_name": "HighLand Coffee Cầu Giấy",
                "location_address": "56 Dịch Vọng Hậu, Cầu Giấy, Hà Nội",
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
                "location_name": "The Coffee House Hoàn Kiếm",
                "location_address": "24 Đinh Tiên Hoàng, Hoàn Kiếm, Hà Nội",
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
                "location_name": "Starbucks Láng Hạ",
                "location_address": "187 Láng Hạ, Đống Đa, Hà Nội",
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
                "location_name": "Cộng Cà Phê Triệu Việt Vương",
                "location_address": "28 Triệu Việt Vương, Hai Bà Trưng, Hà Nội",
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
                    **c,
                )
                db.add(cls)

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
