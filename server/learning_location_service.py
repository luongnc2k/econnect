from fastapi import HTTPException
from sqlalchemy.orm import Session

from models.learning_location import LearningLocation


DEFAULT_LEARNING_LOCATIONS = (
    {
        "id": "hn-cafe-highlands-cau-giay",
        "name": "Highlands Coffee Cầu Giấy",
        "address": "56 Dịch Vọng Hậu, Cầu Giấy, Hà Nội",
        "notes": "Phù hợp lớp 4-6 học viên, không gian yên tĩnh vào buổi tối.",
    },
    {
        "id": "hn-cafe-the-coffee-house-hoan-kiem",
        "name": "The Coffee House Hoàn Kiếm",
        "address": "24 Đinh Tiên Hoàng, Hoàn Kiếm, Hà Nội",
        "notes": "Thuận tiện cho lớp cuối tuần ở khu vực trung tâm.",
    },
    {
        "id": "hn-cafe-cong-trieu-viet-vuong",
        "name": "Cộng Cà Phê Triệu Việt Vương",
        "address": "28 Triệu Việt Vương, Hai Bà Trưng, Hà Nội",
        "notes": "Hợp với lớp giao tiếp nhóm nhỏ 3-5 học viên.",
    },
)

DEFAULT_LEARNING_LOCATION_IDS = tuple(item["id"] for item in DEFAULT_LEARNING_LOCATIONS)


def default_learning_location_ids() -> tuple[str, ...]:
    return DEFAULT_LEARNING_LOCATION_IDS


def get_active_learning_location_or_400(db: Session, location_id: str) -> LearningLocation:
    location = db.query(LearningLocation).filter(LearningLocation.id == location_id).first()
    if not location or not location.is_active:
        raise HTTPException(
            status_code=400,
            detail="Địa điểm học không hợp lệ hoặc không còn được áp dụng",
        )
    return location
