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
        notes="Lên tầng 2, báo lễ tân mã lớp để được hướng dẫn.",
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
    assert body["location_notes"] == "Lên tầng 2, báo lễ tân mã lớp để được hướng dẫn."
