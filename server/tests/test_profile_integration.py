from models.teacher_profile import TeacherProfile
from tests.helpers import auth_headers, login_user, signup_user


def test_teacher_profile_update_uses_typed_schema_and_hides_sensitive_fields_from_others(client, db_session):
    teacher_payload, teacher_signup_response = signup_user(
        client,
        role="teacher",
        full_name="Teacher Original",
    )
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    teacher_token = teacher_login_response.json()["token"]

    update_response = client.put(
        "/profile/me",
        headers=auth_headers(teacher_token),
        json={
            "full_name": "  Teacher Updated  ",
            "bio": "  Specializes in IELTS speaking  ",
            "years_of_experience": "6",
            "specialization": " English ",
            "bank_name": " ACB ",
            "bank_bin": "970416",
            "bank_account_number": " 0123456789 ",
            "bank_account_holder": " Teacher Updated ",
            "certifications": "TESOL, IELTS",
            "verification_docs": ["https://example.com/doc-1.pdf", "  "],
            "rating": 5,
            "total_students": 999,
            "token": "client-side-only",
        },
    )

    assert update_response.status_code == 200
    body = update_response.json()
    assert body["full_name"] == "Teacher Updated"
    assert body["bio"] == "Specializes in IELTS speaking"
    assert body["years_of_experience"] == 6
    assert body["specialization"] == "English"
    assert body["bank_bin"] == "970416"
    assert body["bank_account_number"] == "0123456789"
    assert body["certifications"] == ["TESOL", "IELTS"]
    assert body["verification_docs"] == ["https://example.com/doc-1.pdf"]

    teacher_profile = (
        db_session.query(TeacherProfile)
        .filter(TeacherProfile.user_id == body["id"])
        .first()
    )
    assert teacher_profile is not None
    assert teacher_profile.native_language == "English"
    assert teacher_profile.years_experience == 6
    assert teacher_profile.certifications == ["TESOL", "IELTS"]

    student_payload, student_signup_response = signup_user(client, role="student")
    assert student_signup_response.status_code == 201
    student_login_response = login_user(
        client,
        email=student_payload["email"],
        password=student_payload["password"],
    )
    student_token = student_login_response.json()["token"]

    public_response = client.get(
        f"/profile/{body['id']}",
        headers=auth_headers(student_token),
    )
    assert public_response.status_code == 200
    public_body = public_response.json()
    assert public_body["email"] == ""
    assert public_body["phone"] is None
    assert public_body["last_login_at"] is None
    assert public_body["created_at"] is None
    assert public_body["bank_name"] is None
    assert public_body["bank_bin"] is None
    assert public_body["bank_account_number"] is None
    assert public_body["bank_account_holder"] is None
    assert public_body["verification_docs"] == []


def test_profile_update_rejects_invalid_years_of_experience(client):
    teacher_payload, teacher_signup_response = signup_user(client, role="teacher")
    assert teacher_signup_response.status_code == 201

    teacher_login_response = login_user(
        client,
        email=teacher_payload["email"],
        password=teacher_payload["password"],
    )
    teacher_token = teacher_login_response.json()["token"]

    response = client.put(
        "/profile/me",
        headers=auth_headers(teacher_token),
        json={"years_of_experience": "abc"},
    )

    assert response.status_code == 422
    assert any(
        "years_of_experience khong hop le" in error["msg"]
        for error in response.json()["detail"]
    )
