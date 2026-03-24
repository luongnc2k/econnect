from datetime import datetime, timedelta, timezone
from decimal import Decimal
import uuid

from models.booking import Booking
from models.class_ import Class
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
