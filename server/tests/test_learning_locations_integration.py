from datetime import datetime, timedelta, timezone

from learning_location_service import DEFAULT_LEARNING_LOCATIONS
from tests.helpers import auth_headers, create_admin_user, login_user, signup_user


def test_tutor_sees_all_active_learning_locations(client, db_session):
    admin_payload, admin_response = create_admin_user(client)
    assert admin_response.status_code == 201

    admin_login_response = login_user(
        client,
        email=admin_payload["email"],
        password=admin_payload["password"],
    )
    assert admin_login_response.status_code == 200
    admin_token = admin_login_response.json()["token"]

    create_response = client.post(
        "/locations",
        headers=auth_headers(admin_token),
        json={
            "name": "Toong Tràng Thi",
            "address": "8 Tràng Thi, Hoàn Kiếm, Hà Nội",
            "notes": "Phòng họp nhỏ phù hợp lớp 4-6 học viên",
        },
    )
    assert create_response.status_code == 201
    created_body = create_response.json()
    assert created_body["name"] == "Toong Tràng Thi"
    assert created_body["is_active"] is True

    tutor_payload, tutor_signup_response = signup_user(client, role="teacher")
    assert tutor_signup_response.status_code == 201

    tutor_login_response = login_user(
        client,
        email=tutor_payload["email"],
        password=tutor_payload["password"],
    )
    assert tutor_login_response.status_code == 200
    tutor_token = tutor_login_response.json()["token"]

    list_response = client.get(
        "/locations",
        headers=auth_headers(tutor_token),
    )
    assert list_response.status_code == 200

    locations = list_response.json()
    location_ids = {item["id"] for item in locations}
    assert created_body["id"] in location_ids
    for default_location in DEFAULT_LEARNING_LOCATIONS:
        assert default_location["id"] in location_ids

    admin_list_response = client.get(
        "/locations",
        headers=auth_headers(admin_token),
    )
    assert admin_list_response.status_code == 200
    admin_location_ids = {item["id"] for item in admin_list_response.json()}
    assert created_body["id"] in admin_location_ids


def test_class_creation_request_rejects_inactive_learning_location(client, db_session):
    admin_payload, admin_response = create_admin_user(client, email="admin.locations@example.com")
    assert admin_response.status_code == 201

    admin_login_response = login_user(
        client,
        email=admin_payload["email"],
        password=admin_payload["password"],
    )
    assert admin_login_response.status_code == 200
    admin_token = admin_login_response.json()["token"]

    create_response = client.post(
        "/locations",
        headers=auth_headers(admin_token),
        json={
            "name": "Phòng học bị tắt",
            "address": "1 Test Street",
        },
    )
    assert create_response.status_code == 201
    location_id = create_response.json()["id"]

    deactivate_response = client.patch(
        f"/locations/{location_id}",
        headers=auth_headers(admin_token),
        json={"is_active": False},
    )
    assert deactivate_response.status_code == 200
    assert deactivate_response.json()["is_active"] is False

    teacher_payload, teacher_signup_response = signup_user(client, role="teacher")
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    assert teacher_login_response.status_code == 200
    teacher_token = teacher_login_response.json()["token"]

    start_time = datetime.now(timezone.utc) + timedelta(days=1)
    end_time = start_time + timedelta(hours=2)
    request_response = client.post(
        "/payments/class-creation/request",
        headers=auth_headers(teacher_token),
        json={
            "class_payload": {
                "topic": "Business English",
                "title": "Should Fail With Inactive Location",
                "description": "Test class",
                "level": "intermediate",
                "location_id": location_id,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
                "min_participants": 1,
                "max_participants": 2,
                "price": "200000",
            }
        },
    )

    assert request_response.status_code == 400
    assert request_response.json()["detail"] == "Địa điểm học không hợp lệ hoặc không còn được áp dụng"
