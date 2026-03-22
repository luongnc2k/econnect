from notification_service import serialize_notification_data
from models.class_ import Class
from models.notification import Notification
from models.push_device_token import PushDeviceToken
from datetime import datetime, timedelta, timezone

from tests.helpers import (
    auth_headers,
    create_learning_location,
    login_user,
    seed_paid_class_with_held_bookings,
    seed_user,
    signup_user,
)


def _signup_and_login(client, *, role: str, full_name: str) -> tuple[dict, str]:
    payload, signup_response = signup_user(
        client,
        role=role,
        full_name=full_name,
    )
    assert signup_response.status_code == 201

    login_response = login_user(
        client,
        email=payload["email"],
        password=payload["password"],
    )
    assert login_response.status_code == 200
    return payload, login_response.json()["token"]


def test_minimum_participants_reached_notifies_tutor_and_tutor_confirmation_notifies_students(
    client,
    db_session,
):
    _, teacher_token = _signup_and_login(client, role="teacher", full_name="Teacher Notify")
    location = create_learning_location(
        db_session,
        name="Notification Room",
        address="Google Meet",
    )
    start_time = datetime.now(timezone.utc) + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)
    creation_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Notification English",
                "title": "Minimum Participant Notification",
                "description": "Test confirmation flow",
                "level": "intermediate",
                "location_id": location.id,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "min_participants": 2,
                "max_participants": 4,
                "price": "200000",
                "thumbnail_url": "https://example.com/thumb.jpg",
            }
        },
    )
    assert creation_response.status_code == 201
    creation_body = creation_response.json()

    activation_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": creation_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-CREATION-001",
        },
    )
    assert activation_response.status_code == 200

    student1_payload, student1_token = _signup_and_login(client, role="student", full_name="Student One")
    student2_payload, student2_token = _signup_and_login(client, role="student", full_name="Student Two")

    join_one_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/join/request",
        headers=auth_headers(student1_token),
        json={},
    )
    assert join_one_response.status_code == 201
    join_one_body = join_one_response.json()

    complete_one_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": join_one_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-TUITION-001",
        },
    )
    assert complete_one_response.status_code == 200

    tutor_notifications_before_min = client.get(
        "/notifications",
        headers=auth_headers(teacher_token),
    )
    assert tutor_notifications_before_min.status_code == 200
    assert tutor_notifications_before_min.json() == []

    join_two_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/join/request",
        headers=auth_headers(student2_token),
        json={},
    )
    assert join_two_response.status_code == 201
    join_two_body = join_two_response.json()

    complete_two_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": join_two_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-TUITION-002",
        },
    )
    assert complete_two_response.status_code == 200

    tutor_notifications_response = client.get(
        "/notifications",
        headers=auth_headers(teacher_token),
    )
    assert tutor_notifications_response.status_code == 200
    tutor_notifications = tutor_notifications_response.json()
    assert len(tutor_notifications) == 1
    assert tutor_notifications[0]["type"] == "minimum_participants_reached"
    assert tutor_notifications[0]["data"]["class_id"] == creation_body["class_id"]
    assert tutor_notifications[0]["data"]["class_code"].startswith("CLS-")
    assert tutor_notifications[0]["data"]["min_participants"] == 2
    assert tutor_notifications[0]["data"]["current_participants"] == 2

    tutor_unread_count_response = client.get(
        "/notifications/unread-count",
        headers=auth_headers(teacher_token),
    )
    assert tutor_unread_count_response.status_code == 200
    assert tutor_unread_count_response.json()["unread_count"] == 1

    filtered_notifications_response = client.get(
        "/notifications",
        params={"type": "minimum_participants_reached", "unread_only": "true", "limit": 1, "offset": 0},
        headers=auth_headers(teacher_token),
    )
    assert filtered_notifications_response.status_code == 200
    filtered_notifications = filtered_notifications_response.json()
    assert len(filtered_notifications) == 1
    assert filtered_notifications[0]["type"] == "minimum_participants_reached"

    summary_response = client.get(
        f"/payments/classes/{creation_body['class_id']}/summary",
        headers=auth_headers(teacher_token),
    )
    assert summary_response.status_code == 200
    summary_body = summary_response.json()
    assert summary_body["min_participants"] == 2
    assert summary_body["max_participants"] == 4
    assert summary_body["minimum_participants_reached"] is True
    assert summary_body["tutor_confirmation_status"] == "pending"

    confirm_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/confirm-teaching",
        headers=auth_headers(teacher_token),
    )
    assert confirm_response.status_code == 200
    confirm_body = confirm_response.json()
    assert confirm_body["tutor_confirmation_status"] == "confirmed"
    assert confirm_body["minimum_participants_reached"] is True
    assert confirm_body["notified_students"] == 2

    student_one_notifications_response = client.get(
        "/notifications",
        headers=auth_headers(student1_token),
    )
    assert student_one_notifications_response.status_code == 200
    student_one_notifications = student_one_notifications_response.json()
    assert len(student_one_notifications) == 1
    assert student_one_notifications[0]["type"] == "tutor_confirmed_teaching"
    assert student_one_notifications[0]["data"]["class_id"] == creation_body["class_id"]

    student_two_notifications_response = client.get(
        "/notifications",
        headers=auth_headers(student2_token),
    )
    assert student_two_notifications_response.status_code == 200
    student_two_notifications = student_two_notifications_response.json()
    assert len(student_two_notifications) == 1
    assert student_two_notifications[0]["type"] == "tutor_confirmed_teaching"

    student3_payload, student3_token = _signup_and_login(client, role="student", full_name="Student Three")
    assert student1_payload["email"] != student2_payload["email"]
    assert student3_payload["email"] not in {student1_payload["email"], student2_payload["email"]}

    join_three_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/join/request",
        headers=auth_headers(student3_token),
        json={},
    )
    assert join_three_response.status_code == 201
    join_three_body = join_three_response.json()

    complete_three_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": join_three_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-TUITION-003",
        },
    )
    assert complete_three_response.status_code == 200

    student_three_notifications_response = client.get(
        "/notifications",
        headers=auth_headers(student3_token),
    )
    assert student_three_notifications_response.status_code == 200
    student_three_notifications = student_three_notifications_response.json()
    assert len(student_three_notifications) == 1
    assert student_three_notifications[0]["type"] == "tutor_confirmed_teaching"
    assert student_three_notifications[0]["data"]["class_id"] == creation_body["class_id"]


def test_notify_classes_starting_soon_notifies_tutor_and_students_once(client, db_session):
    now = datetime.now(timezone.utc)
    seeded = seed_paid_class_with_held_bookings(
        db_session,
        student_count=2,
        start_time=now + timedelta(minutes=50),
        end_time=now + timedelta(hours=2, minutes=50),
    )

    response = client.post(
        "/payments/jobs/notify-classes-starting-soon",
        headers={"x-job-secret": "test-job-secret"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["notified"][0]["class_id"] == seeded["class"].id
    assert body["notified"][0]["student_count"] == 2
    assert body["notified"][0]["recipient_count"] == 3

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == seeded["class"].id).first()
    assert cls is not None
    assert cls.starting_soon_notified_at is not None

    teacher_notifications = (
        db_session.query(Notification)
        .filter(
            Notification.user_id == seeded["teacher"].id,
            Notification.type == "class_starting_soon",
        )
        .all()
    )
    assert len(teacher_notifications) == 1
    teacher_data = serialize_notification_data(teacher_notifications[0].data)
    assert teacher_data["class_id"] == seeded["class"].id
    assert teacher_data["class_code"].startswith("CLS-")
    assert teacher_data["recipient_role"] == "teacher"

    student_ids = [student.id for student in seeded["students"]]
    student_notifications = (
        db_session.query(Notification)
        .filter(
            Notification.user_id.in_(student_ids),
            Notification.type == "class_starting_soon",
        )
        .all()
    )
    assert len(student_notifications) == 2
    for notification in student_notifications:
        data = serialize_notification_data(notification.data)
        assert data["class_id"] == seeded["class"].id
        assert data["recipient_role"] == "student"

    second_response = client.post(
        "/payments/jobs/notify-classes-starting-soon",
        headers={"x-job-secret": "test-job-secret"},
    )
    assert second_response.status_code == 200
    assert second_response.json()["count"] == 0


def test_tutor_cancel_class_creates_cancelled_and_refund_notifications(client, db_session):
    _, teacher_token = _signup_and_login(client, role="teacher", full_name="Teacher Cancel Flow")
    location = create_learning_location(
        db_session,
        name="Cancelled Class Room",
        address="Google Meet",
    )
    start_time = datetime.now(timezone.utc) + timedelta(days=2)
    end_time = start_time + timedelta(hours=2)
    creation_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Cancelled Class Topic",
                "title": "Cancelled Class Notification",
                "description": "Test cancel flow",
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

    activation_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": creation_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-CREATION-CANCEL-001",
        },
    )
    assert activation_response.status_code == 200

    _, student_token = _signup_and_login(client, role="student", full_name="Student Cancel Flow")
    join_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/join/request",
        headers=auth_headers(student_token),
        json={},
    )
    assert join_response.status_code == 201
    join_body = join_response.json()

    complete_response = client.post(
        "/payments/callback",
        json={
            "transaction_ref": join_body["transaction_ref"],
            "status": "success",
            "provider_transaction_id": "MOCK-TUITION-CANCEL-001",
        },
    )
    assert complete_response.status_code == 200

    cancel_response = client.post(
        f"/payments/classes/{creation_body['class_id']}/cancel",
        headers=auth_headers(teacher_token),
        json={"reason": "Tutor co viec dot xuat"},
    )
    assert cancel_response.status_code == 200
    assert cancel_response.json()["class_status"] == "cancelled"

    student_notifications_response = client.get(
        "/notifications",
        headers=auth_headers(student_token),
    )
    assert student_notifications_response.status_code == 200
    notifications = student_notifications_response.json()
    notification_types = {item["type"] for item in notifications}
    assert "class_cancelled" in notification_types
    assert "refund_issued" in notification_types

    cancelled_notification = next(
        item for item in notifications if item["type"] == "class_cancelled"
    )
    refund_notification = next(
        item for item in notifications if item["type"] == "refund_issued"
    )
    assert cancelled_notification["data"]["class_id"] == creation_body["class_id"]
    assert cancelled_notification["data"]["cancellation_reason"] == "Tutor co viec dot xuat"
    assert refund_notification["data"]["class_id"] == creation_body["class_id"]
    assert refund_notification["data"]["refund_reason"] == "Tutor co viec dot xuat"


def test_cancel_underfilled_classes_uses_active_bookings_instead_of_stale_cached_count(
    client,
    db_session,
):
    now = datetime.now(timezone.utc)
    seeded = seed_paid_class_with_held_bookings(
        db_session,
        student_count=2,
        start_time=now + timedelta(hours=2),
        end_time=now + timedelta(hours=4),
    )

    cls = seeded["class"]
    bookings = seeded["bookings"]
    payments = seeded["tuition_payments"]

    cls.min_participants = 2
    cls.current_participants = 2
    bookings[1].status = "refunded"
    bookings[1].payment_status = "refunded"
    bookings[1].escrow_status = "refunded"
    payments[1].status = "refunded"
    db_session.commit()

    response = client.post(
        "/payments/jobs/cancel-underfilled-classes",
        headers={"x-job-secret": "test-job-secret"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert cls.id in body["cancelled_class_ids"]

    db_session.expire_all()
    refreshed_class = db_session.query(Class).filter(Class.id == cls.id).first()
    assert refreshed_class is not None
    assert refreshed_class.status == "cancelled"
    assert refreshed_class.current_participants == 0


def test_notifications_cursor_endpoint_returns_stable_pages(client, db_session):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Cursor Flow")
    login_response = login_user(client, email=teacher.email)
    assert login_response.status_code == 200
    token = login_response.json()["token"]

    first = Notification(
        id="notif-cursor-001",
        user_id=teacher.id,
        type="payout_updated",
        title="Newest",
        body="Newest notification",
        is_read=False,
        created_at=datetime.now(timezone.utc),
    )
    second = Notification(
        id="notif-cursor-002",
        user_id=teacher.id,
        type="refund_issued",
        title="Second",
        body="Second notification",
        is_read=False,
        created_at=datetime.now(timezone.utc) - timedelta(minutes=1),
    )
    third = Notification(
        id="notif-cursor-003",
        user_id=teacher.id,
        type="class_cancelled",
        title="Third",
        body="Third notification",
        is_read=False,
        created_at=datetime.now(timezone.utc) - timedelta(minutes=2),
    )
    db_session.add_all([first, second, third])
    db_session.commit()

    first_page_response = client.get(
        "/notifications/cursor",
        params={"limit": 2},
        headers=auth_headers(token),
    )
    assert first_page_response.status_code == 200
    first_page = first_page_response.json()
    assert first_page["has_more"] is True
    assert first_page["next_cursor"]
    assert [item["id"] for item in first_page["items"]] == [
        "notif-cursor-001",
        "notif-cursor-002",
    ]

    second_page_response = client.get(
        "/notifications/cursor",
        params={"limit": 2, "cursor": first_page["next_cursor"]},
        headers=auth_headers(token),
    )
    assert second_page_response.status_code == 200
    second_page = second_page_response.json()
    assert second_page["has_more"] is False
    assert second_page["next_cursor"] is None
    assert [item["id"] for item in second_page["items"]] == ["notif-cursor-003"]


def test_push_token_register_and_unregister_flow(client, db_session):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Push Token")
    login_response = login_user(client, email=teacher.email)
    assert login_response.status_code == 200
    token = login_response.json()["token"]

    register_response = client.post(
        "/notifications/push-tokens",
        headers=auth_headers(token),
        json={
            "token": "fcm-test-token-001-abcdefghijklmnopqrstuvwxyz",
            "platform": "android",
            "device_label": "Pixel Test",
        },
    )
    assert register_response.status_code == 200
    assert register_response.json()["is_active"] is True

    stored_token = (
        db_session.query(PushDeviceToken)
        .filter(PushDeviceToken.token == "fcm-test-token-001-abcdefghijklmnopqrstuvwxyz")
        .first()
    )
    assert stored_token is not None
    assert stored_token.user_id == teacher.id
    assert stored_token.platform == "android"
    assert stored_token.is_active is True

    unregister_response = client.post(
        "/notifications/push-tokens/unregister",
        headers=auth_headers(token),
        json={"token": "fcm-test-token-001-abcdefghijklmnopqrstuvwxyz"},
    )
    assert unregister_response.status_code == 200
    assert unregister_response.json()["is_active"] is False

    db_session.refresh(stored_token)
    assert stored_token.is_active is False


def test_notifications_read_routes_dispatch_due_starting_soon_reminders_without_job(client, db_session):
    now = datetime.now(timezone.utc)
    seeded = seed_paid_class_with_held_bookings(
        db_session,
        student_count=2,
        start_time=now + timedelta(minutes=45),
        end_time=now + timedelta(hours=2, minutes=45),
    )

    teacher_login = login_user(client, email=seeded["teacher"].email)
    assert teacher_login.status_code == 200
    teacher_token = teacher_login.json()["token"]

    response = client.get(
        "/notifications",
        headers=auth_headers(teacher_token),
    )
    assert response.status_code == 200
    notifications = response.json()
    assert len(notifications) == 1
    assert notifications[0]["type"] == "class_starting_soon"
    assert notifications[0]["data"]["class_id"] == seeded["class"].id

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == seeded["class"].id).first()
    assert cls is not None
    assert cls.starting_soon_notified_at is not None


def test_notifications_websocket_emits_change_event(client, db_session):
    teacher = seed_user(db_session, role="teacher", full_name="Teacher Live Flow")
    login_response = login_user(client, email=teacher.email)
    assert login_response.status_code == 200
    token = login_response.json()["token"]

    with client.websocket_connect(f"/notifications/ws?token={token}") as websocket:
        initial_event = websocket.receive_json()
        assert initial_event["type"] in {"notifications_changed", "heartbeat"}

        db_session.add(
            Notification(
                id="notif-live-001",
                user_id=teacher.id,
                type="payout_updated",
                title="Realtime notification",
                body="Realtime body",
                is_read=False,
                created_at=datetime.now(timezone.utc),
            )
        )
        db_session.commit()

        changed_event = None
        for _ in range(5):
            event = websocket.receive_json()
            if event["type"] == "notifications_changed" and event["unread_count"] == 1:
                changed_event = event
                break

        assert changed_event is not None
        assert changed_event["latest_notification_id"] == "notif-live-001"
