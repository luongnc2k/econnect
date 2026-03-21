from models.user import User
from tests.helpers import DEFAULT_PASSWORD, auth_headers, login_user, seed_user, signup_user


def test_signup_login_and_current_user_do_not_expose_password_hash(client):
    signup_payload, signup_response = signup_user(
        client,
        role="student",
        full_name="Student Integration",
    )

    assert signup_response.status_code == 201
    signup_body = signup_response.json()
    assert signup_body["email"] == signup_payload["email"]
    assert signup_body["role"] == "student"
    assert "password_hash" not in signup_body

    login_response = login_user(
        client,
        email=signup_payload["email"],
        password=signup_payload["password"],
    )
    assert login_response.status_code == 200

    login_body = login_response.json()
    assert login_body["token"]
    assert login_body["user"]["email"] == signup_payload["email"]
    assert "password_hash" not in login_body["user"]

    current_response = client.get(
        "/auth/",
        headers=auth_headers(login_body["token"]),
    )
    assert current_response.status_code == 200
    current_body = current_response.json()
    assert current_body["email"] == signup_payload["email"]
    assert "password_hash" not in current_body


def test_login_rejects_inactive_user(client, db_session):
    inactive_user = seed_user(
        db_session,
        role="student",
        email="inactive.user@example.com",
        password=DEFAULT_PASSWORD,
        is_active=False,
    )

    response = client.post(
        "/auth/login",
        json={
            "email": inactive_user.email,
            "password": DEFAULT_PASSWORD,
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Tai khoan da bi khoa"

    db_user = db_session.query(User).filter(User.email == inactive_user.email).first()
    assert db_user is not None
    assert db_user.is_active is False


def test_login_uses_generic_error_for_unknown_email(client):
    response = client.post(
        "/auth/login",
        json={
            "email": "unknown@example.com",
            "password": DEFAULT_PASSWORD,
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Email hoac mat khau khong dung"
