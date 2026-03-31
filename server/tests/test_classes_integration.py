from datetime import datetime, timedelta, timezone
from decimal import Decimal
import uuid

from models.booking import Booking
from models.class_ import Class
from models.teacher_profile import TeacherProfile
from models.tutor_review import TutorReview
from tests.helpers import (
    auth_headers,
    create_learning_location,
    create_topic,
    login_user,
    seed_paid_class_with_held_booking,
    seed_teacher_profile,
    seed_user,
)


def test_income_stats_sum_student_tuition_amount_not_total_class_price_per_booking(
    client,
    db_session,
):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Income")
    login_response = login_user(client, email=teacher.email)
    assert login_response.status_code == 200
    teacher_token = login_response.json()["token"]

    topic = create_topic(db_session, name="Income Topic")
    location = create_learning_location(
        db_session,
        name="Income Room",
        address="Google Meet",
    )
    seed_teacher_profile(
        db_session,
        teacher_id=teacher.id,
        bank_account_holder=teacher.full_name,
    )

    now = datetime.now(timezone.utc)
    start_time = now + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)

    cls = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        topic=topic.name,
        title="Income Check Class",
        description="Income check",
        level="intermediate",
        location_name=location.name,
        location_address=location.address,
        start_time=start_time,
        end_time=end_time,
        min_participants=1,
        max_participants=4,
        current_participants=2,
        price=Decimal("200000"),
        creation_fee_amount=Decimal("20000"),
        creation_payment_status="paid",
        creation_payment_reference=f"CRF-{uuid.uuid4().hex[:10].upper()}",
        status="scheduled",
        tutor_payout_status="pending",
        tutor_payout_amount=Decimal("0"),
        has_active_dispute=False,
    )
    db_session.add(cls)
    db_session.flush()

    for index in range(2):
        student = seed_user(
            db_session,
            role="student",
            full_name=f"Income Student {index + 1}",
        )
        booking = Booking(
            id=str(uuid.uuid4()),
            class_id=cls.id,
            student_id=student.id,
            status="confirmed",
            payment_status="paid",
            payment_method="payos",
            payment_reference=f"TUI-{uuid.uuid4().hex[:10].upper()}",
            tuition_amount=Decimal("50000"),
            escrow_status="held",
        )
        db_session.add(booking)

    db_session.commit()

    response = client.get(
        "/classes/income",
        headers=auth_headers(teacher_token),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["total_income"] == 100000.0
    assert body["this_month_income"] in {0.0, 100000.0}


def test_get_class_by_code_fills_legacy_location_notes_from_learning_locations(
    client,
    db_session,
):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Legacy Location")
    student = seed_user(db_session, role="student", full_name="Student Legacy Location")
    login_response = login_user(client, email=student.email)
    assert login_response.status_code == 200
    student_token = login_response.json()["token"]

    topic = create_topic(db_session, name="Legacy Topic")
    location = create_learning_location(
        db_session,
        name="Legacy Study Room",
        address="12 Nguyen Hue, Quan 1, TP.HCM",
        notes="Len tang 2, bao le tan ma lop de duoc huong dan.",
    )

    start_time = datetime.now(timezone.utc) + timedelta(days=2)
    end_time = start_time + timedelta(hours=2)
    cls = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        topic=topic.name,
        title="Legacy Location Class",
        description="Backfill location notes for older classes",
        level="intermediate",
        location_name=location.name,
        location_address=location.address,
        location_notes=None,
        start_time=start_time,
        end_time=end_time,
        min_participants=1,
        max_participants=4,
        current_participants=0,
        price=Decimal("240000"),
        creation_fee_amount=Decimal("24000"),
        creation_payment_status="paid",
        creation_payment_reference=f"CRF-{uuid.uuid4().hex[:10].upper()}",
        status="scheduled",
        tutor_payout_status="pending",
        tutor_payout_amount=Decimal("0"),
        has_active_dispute=False,
    )
    db_session.add(cls)
    db_session.commit()

    class_code = (
        f"CLS-{cls.start_time.strftime('%y%m%d')}-"
        f"{''.join(char for char in cls.id.upper() if char.isalnum())[:4].ljust(4, '0')}"
    )
    response = client.get(
        f"/classes/by-code/{class_code}",
        headers=auth_headers(student_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert body["location_name"] == "Legacy Study Room"
    assert body["location_address"] == "12 Nguyen Hue, Quan 1, TP.HCM"
    assert body["location_notes"] == "Len tang 2, bao le tan ma lop de duoc huong dan."


def test_student_can_reopen_past_class_by_code_when_include_past_is_enabled(
    client,
    db_session,
):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Past Class")
    student = seed_user(db_session, role="student", full_name="Student Past Class")
    login_response = login_user(client, email=student.email)
    assert login_response.status_code == 200
    student_token = login_response.json()["token"]

    topic = create_topic(db_session, name="Past Review Topic")
    location = create_learning_location(
        db_session,
        name="Past Review Room",
        address="99 Nguyen Dinh Chieu, TP.HCM",
    )

    start_time = datetime.now(timezone.utc) - timedelta(days=1, hours=2)
    end_time = datetime.now(timezone.utc) - timedelta(days=1)
    cls = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        topic=topic.name,
        title="Past Review Class",
        description="Ended class that can still be reopened for review",
        level="intermediate",
        location_name=location.name,
        location_address=location.address,
        location_notes=location.notes,
        start_time=start_time,
        end_time=end_time,
        min_participants=1,
        max_participants=4,
        current_participants=1,
        price=Decimal("240000"),
        creation_fee_amount=Decimal("24000"),
        creation_payment_status="paid",
        creation_payment_reference=f"CRF-{uuid.uuid4().hex[:10].upper()}",
        status="completed",
        tutor_payout_status="pending",
        tutor_payout_amount=Decimal("0"),
        has_active_dispute=False,
    )
    db_session.add(cls)
    db_session.flush()

    booking = Booking(
        id=str(uuid.uuid4()),
        class_id=cls.id,
        student_id=student.id,
        status="completed",
        payment_status="paid",
        payment_method="payos",
        payment_reference=f"TUI-{uuid.uuid4().hex[:10].upper()}",
        tuition_amount=Decimal("60000"),
        escrow_status="released",
    )
    db_session.add(booking)
    db_session.commit()

    class_code = (
        f"CLS-{cls.start_time.strftime('%y%m%d')}-"
        f"{''.join(char for char in cls.id.upper() if char.isalnum())[:4].ljust(4, '0')}"
    )

    default_response = client.get(
        f"/classes/by-code/{class_code}",
        headers=auth_headers(student_token),
    )
    assert default_response.status_code == 404

    include_past_response = client.get(
        f"/classes/by-code/{class_code}?include_past=true",
        headers=auth_headers(student_token),
    )
    assert include_past_response.status_code == 200
    body = include_past_response.json()
    assert body["id"] == cls.id
    assert body["title"] == "Past Review Class"
    assert body["status"] == "completed"
    assert body["teacher"]["id"] == teacher.id


def test_student_registered_classes_returns_upcoming_and_past_classes(
    client,
    db_session,
):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Student Schedule")
    student = seed_user(db_session, role="student", full_name="Student Schedule")

    now = datetime.now(timezone.utc)
    upcoming_seed = seed_paid_class_with_held_booking(
        db_session,
        teacher=teacher,
        student=student,
        start_time=now + timedelta(days=2),
        end_time=now + timedelta(days=2, hours=2),
        class_status="scheduled",
    )
    past_seed = seed_paid_class_with_held_booking(
        db_session,
        teacher=teacher,
        student=student,
        start_time=now - timedelta(days=2, hours=2),
        end_time=now - timedelta(days=2),
        class_status="completed",
    )

    upcoming_class = db_session.query(Class).filter(Class.id == upcoming_seed["class"].id).first()
    past_class = db_session.query(Class).filter(Class.id == past_seed["class"].id).first()
    assert upcoming_class is not None
    assert past_class is not None
    upcoming_class.title = "Upcoming Registered Class"
    past_class.title = "Past Registered Class"
    db_session.commit()

    login_response = login_user(client, email=student.email)
    assert login_response.status_code == 200
    student_token = login_response.json()["token"]

    upcoming_response = client.get(
        "/classes/registered",
        headers=auth_headers(student_token),
    )
    assert upcoming_response.status_code == 200
    upcoming_body = upcoming_response.json()
    assert len(upcoming_body) == 1
    assert upcoming_body[0]["id"] == upcoming_class.id
    assert upcoming_body[0]["title"] == "Upcoming Registered Class"
    assert upcoming_body[0]["teacher"]["id"] == teacher.id

    past_response = client.get(
        "/classes/registered?past=true",
        headers=auth_headers(student_token),
    )
    assert past_response.status_code == 200
    past_body = past_response.json()
    assert len(past_body) == 1
    assert past_body[0]["id"] == past_class.id
    assert past_body[0]["title"] == "Past Registered Class"
    assert past_body[0]["teacher"]["full_name"] == teacher.full_name


def test_student_can_submit_tutor_review_and_teacher_rating_is_updated(
    client,
    db_session,
):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Review")
    student = seed_user(db_session, role="student", full_name="Student Review")

    seeded = seed_paid_class_with_held_booking(
        db_session,
        teacher=teacher,
        student=student,
        start_time=datetime.now(timezone.utc) - timedelta(days=1, hours=2),
        end_time=datetime.now(timezone.utc) - timedelta(days=1),
        class_status="completed",
    )
    cls = seeded["class"]

    login_response = login_user(client, email=student.email)
    assert login_response.status_code == 200
    student_token = login_response.json()["token"]

    status_response = client.get(
        f"/classes/{cls.id}/my-tutor-review",
        headers=auth_headers(student_token),
    )
    assert status_response.status_code == 200
    assert status_response.json() == {
        "class_id": cls.id,
        "can_review": True,
        "already_reviewed": False,
        "hotline": "0335837165",
        "reason": None,
        "review": None,
    }

    create_response = client.put(
        f"/classes/{cls.id}/my-tutor-review",
        headers=auth_headers(student_token),
        json={
            "rating": 5,
            "comment": "Tutor dạy rất dễ hiểu và hỗ trợ nhiệt tình.",
        },
    )
    assert create_response.status_code == 200
    body = create_response.json()
    assert body["can_review"] is False
    assert body["already_reviewed"] is True
    assert body["hotline"] == "0335837165"
    assert body["review"]["rating"] == 5
    assert body["review"]["comment"] == "Tutor dạy rất dễ hiểu và hỗ trợ nhiệt tình."

    review = (
        db_session.query(TutorReview)
        .filter(TutorReview.class_id == cls.id, TutorReview.student_id == student.id)
        .first()
    )
    assert review is not None
    assert review.rating == 5

    teacher_profile = (
        db_session.query(TeacherProfile)
        .filter(TeacherProfile.user_id == teacher.id)
        .first()
    )
    assert teacher_profile is not None
    assert float(teacher_profile.rating_avg) == 5.0
    assert teacher_profile.total_reviews == 1

    update_response = client.put(
        f"/classes/{cls.id}/my-tutor-review",
        headers=auth_headers(student_token),
        json={
            "rating": 3,
            "comment": "Đã cập nhật nhận xét sau khi học thêm.",
        },
    )
    assert update_response.status_code == 400
    assert (
        update_response.json()["detail"]
        == "Bạn đã gửi đánh giá cho buổi học này."
    )

    db_session.expire_all()
    refreshed_profile = (
        db_session.query(TeacherProfile)
        .filter(TeacherProfile.user_id == teacher.id)
        .first()
    )
    assert refreshed_profile is not None
    assert float(refreshed_profile.rating_avg) == 5.0
    assert refreshed_profile.total_reviews == 1


def test_student_tutor_review_rejects_comment_longer_than_100_words(
    client,
    db_session,
):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Long Comment")
    student = seed_user(db_session, role="student", full_name="Student Long Comment")
    seeded = seed_paid_class_with_held_booking(
        db_session,
        teacher=teacher,
        student=student,
        start_time=datetime.now(timezone.utc) - timedelta(days=1, hours=2),
        end_time=datetime.now(timezone.utc) - timedelta(days=1),
        class_status="completed",
    )
    cls = seeded["class"]

    login_response = login_user(client, email=student.email)
    assert login_response.status_code == 200
    student_token = login_response.json()["token"]

    long_comment = " ".join(f"tu{i}" for i in range(101))
    response = client.put(
        f"/classes/{cls.id}/my-tutor-review",
        headers=auth_headers(student_token),
        json={"rating": 4, "comment": long_comment},
    )

    assert response.status_code == 422
    assert any(
        "comment khong duoc vuot qua 100 tu" in error["msg"]
        for error in response.json()["detail"]
    )
