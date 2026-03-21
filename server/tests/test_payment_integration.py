from datetime import datetime, timedelta, timezone

from models.booking import Booking
from models.class_ import Class
from tests.helpers import auth_headers, create_topic, login_user, signup_user


def test_payment_flow_creates_class_confirms_tuition_and_restricts_transaction_access(client, db_session):
    teacher_payload, teacher_signup_response = signup_user(
        client,
        role="teacher",
        full_name="Teacher Payment",
    )
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    teacher_token = teacher_login_response.json()["token"]
    topic = create_topic(db_session, name="Business English")

    start_time = datetime.now(timezone.utc) + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)
    creation_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic_id": topic.id,
                "title": "Production Payment Flow",
                "description": "Test class",
                "level": "intermediate",
                "location_name": "Online",
                "location_address": "Google Meet",
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "min_participants": 1,
                "max_participants": 2,
                "price": "200000",
                "thumbnail_url": "https://example.com/thumb.jpg",
            }
        },
    )

    assert creation_response.status_code == 201
    creation_body = creation_response.json()
    assert creation_body["payment_type"] == "class_creation"
    assert creation_body["status"] == "pending"
    assert creation_body["class_status"] == "draft"

    activation_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": creation_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-CREATION-001",
        },
    )
    assert activation_response.status_code == 200
    assert activation_response.json()["status"] == "paid"
    assert activation_response.json()["class_status"] == "scheduled"

    student_payload, student_signup_response = signup_user(
        client,
        role="student",
        full_name="Student Payment",
    )
    assert student_signup_response.status_code == 201
    student_login_response = login_user(
        client,
        email=student_payload["email"],
        password=student_payload["password"],
    )
    student_token = student_login_response.json()["token"]

    join_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/join/request",
        headers=auth_headers(student_token),
        json={},
    )
    assert join_response.status_code == 201
    join_body = join_response.json()
    assert join_body["payment_type"] == "tuition"
    assert join_body["status"] == "pending"

    outsider_payload, outsider_signup_response = signup_user(client, role="student")
    assert outsider_signup_response.status_code == 201
    outsider_login_response = login_user(
        client,
        email=outsider_payload["email"],
        password=outsider_payload["password"],
    )
    outsider_token = outsider_login_response.json()["token"]

    forbidden_response = client.get(
        f"/payments/transactions/{join_body['transaction_ref']}",
        headers=auth_headers(outsider_token),
    )
    assert forbidden_response.status_code == 403
    assert forbidden_response.json()["detail"] == "Ban khong co quyen xem giao dich nay"

    complete_tuition_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": join_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-TUITION-001",
        },
    )
    assert complete_tuition_response.status_code == 200
    complete_body = complete_tuition_response.json()
    assert complete_body["status"] == "paid"
    assert complete_body["booking_status"] == "confirmed"
    assert complete_body["escrow_status"] == "held"

    owner_status_response = client.get(
        f"/payments/transactions/{join_body['transaction_ref']}",
        headers=auth_headers(student_token),
    )
    assert owner_status_response.status_code == 200
    owner_status_body = owner_status_response.json()
    assert owner_status_body["status"] == "paid"
    assert owner_status_body["escrow_status"] == "held"

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == creation_body["class_id"]).first()
    booking = db_session.query(Booking).filter(Booking.id == join_body["booking_id"]).first()
    assert cls is not None
    assert booking is not None
    assert cls.current_participants == 1
    assert booking.status == "confirmed"
    assert booking.escrow_status == "held"
