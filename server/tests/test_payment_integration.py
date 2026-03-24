from datetime import datetime, timedelta, timezone
from decimal import Decimal

from payment_gateways import ProviderVerificationResult
from models.booking import Booking
from models.class_ import Class
from models.payment import Payment
from routes import payments as payments_routes
from tests.helpers import auth_headers, create_learning_location, login_user, signup_user


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
    location = create_learning_location(
        db_session,
        name="Online Payment Room",
        address="Google Meet",
        notes="Phòng online, học viên kiểm tra mic trước 10 phút.",
    )
    start_time = datetime.now(timezone.utc) + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)
    creation_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Business English",
                "title": "Production Payment Flow",
                "description": "Test class",
                "level": "intermediate",
                "location_id": location.id,
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
    assert Decimal(str(join_body["amount"])) == Decimal("100000")

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
    assert Decimal(str(complete_body["amount"])) == Decimal("100000")

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
    payment = db_session.query(Payment).filter(Payment.id == join_body["payment_id"]).first()
    assert cls is not None
    assert booking is not None
    assert payment is not None
    assert cls.current_participants == 1
    assert cls.location_name == "Online Payment Room"
    assert cls.location_address == "Google Meet"
    assert cls.location_notes == "Phòng online, học viên kiểm tra mic trước 10 phút."
    assert booking.status == "confirmed"
    assert booking.escrow_status == "held"
    assert Decimal(booking.tuition_amount) == Decimal("100000")
    assert Decimal(payment.amount) == Decimal("100000")

    class_code = (
        f"CLS-{cls.start_time.strftime('%y%m%d')}-"
        f"{''.join(char for char in cls.id.upper() if char.isalnum())[:4].ljust(4, '0')}"
    )
    class_detail_response = client.get(
        f"/classes/by-code/{class_code}",
        headers=auth_headers(student_token),
    )
    assert class_detail_response.status_code == 200
    class_detail_body = class_detail_response.json()
    assert class_detail_body["location_name"] == "Online Payment Room"
    assert class_detail_body["location_address"] == "Google Meet"
    assert (
        class_detail_body["location_notes"]
        == "Phòng online, học viên kiểm tra mic trước 10 phút."
    )


def test_class_creation_request_rejects_title_longer_than_100_characters(client, db_session):
    teacher_payload, teacher_signup_response = signup_user(
        client,
        role="teacher",
        full_name="Teacher Title Limit",
    )
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    teacher_token = teacher_login_response.json()["token"]
    location = create_learning_location(
        db_session,
        name="Online Title Limit",
        address="Google Meet",
    )
    start_time = datetime.now(timezone.utc) + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)
    response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Topic Title Limit",
                "title": "A" * 101,
                "description": "Test class",
                "level": "intermediate",
                "location_id": location.id,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "min_participants": 1,
                "max_participants": 2,
                "price": "200000",
            }
        },
    )

    assert response.status_code == 422
    assert any(
        error["loc"][-1] == "title" and "at most 100 characters" in error["msg"]
        for error in response.json()["detail"]
    )


def test_transaction_status_syncs_pending_creation_payment_from_payos(
    client,
    db_session,
    monkeypatch,
):
    teacher_payload, teacher_signup_response = signup_user(
        client,
        role="teacher",
        full_name="Teacher Sync Payment",
    )
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    teacher_token = teacher_login_response.json()["token"]

    location = create_learning_location(
        db_session,
        name="Sync Payment Room",
        address="Google Meet",
    )
    start_time = datetime.now(timezone.utc) + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)

    creation_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Business English",
                "title": "Provider Sync Class",
                "description": "Test class",
                "level": "intermediate",
                "location_id": location.id,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "min_participants": 1,
                "max_participants": 2,
                "price": "200000",
            }
        },
    )

    assert creation_response.status_code == 201
    creation_body = creation_response.json()

    payment = db_session.query(Payment).filter(Payment.id == creation_body["payment_id"]).first()
    assert payment is not None
    payment.provider_order_id = "987654321"
    db_session.commit()

    def _fake_fetch_provider_payment_status(provider: str, provider_order_id: str):
        assert provider == "payos"
        assert provider_order_id == "987654321"
        return ProviderVerificationResult(
            transaction_ref="987654321",
            is_success=True,
            provider_transaction_id="PAYOS-TXN-001",
            raw_payload='{"status":"PAID"}',
            message="payOS da ghi nhan thanh toan thanh cong",
            provider_status="PAID",
        )

    monkeypatch.setattr(
        payments_routes,
        "fetch_provider_payment_status",
        _fake_fetch_provider_payment_status,
    )

    status_response = client.get(
        f"/payments/transactions/{creation_body['transaction_ref']}",
        headers=auth_headers(teacher_token),
    )

    assert status_response.status_code == 200
    status_body = status_response.json()
    assert status_body["status"] == "paid"
    assert status_body["class_status"] == "scheduled"

    db_session.expire_all()
    synced_class = db_session.query(Class).filter(Class.id == creation_body["class_id"]).first()
    synced_payment = db_session.query(Payment).filter(Payment.id == creation_body["payment_id"]).first()
    assert synced_class is not None
    assert synced_payment is not None
    assert synced_class.creation_payment_status == "paid"
    assert synced_class.status == "scheduled"
    assert synced_payment.status == "paid"


def test_class_creation_payment_rejects_past_start_time(client, db_session):
    teacher_payload, teacher_signup_response = signup_user(
        client,
        role="teacher",
        full_name="Teacher Past Time",
    )
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    teacher_token = teacher_login_response.json()["token"]

    location = create_learning_location(
        db_session,
        name="Past Time Room",
        address="Google Meet",
        notes="Khong cho tao lop trong qua khu.",
    )
    start_time = datetime.now(timezone.utc) - timedelta(hours=1)
    end_time = datetime.now(timezone.utc) + timedelta(hours=1)

    creation_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Past Time",
                "title": "Past Start Time Class",
                "description": "Should be rejected",
                "level": "intermediate",
                "location_id": location.id,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "min_participants": 1,
                "max_participants": 2,
                "price": "200000",
            }
        },
    )

    assert creation_response.status_code == 422
    assert "start_time" in creation_response.text
