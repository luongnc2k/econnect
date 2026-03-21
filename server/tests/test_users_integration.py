from tests.helpers import auth_headers, login_user, seed_user


def test_user_search_hides_real_contact_information(client, db_session):
    requester = seed_user(
        db_session,
        role="student",
        email="requester@example.com",
    )
    target = seed_user(
        db_session,
        role="teacher",
        email="teacher.public@example.com",
        full_name="Teacher Public",
    )
    target.phone = "0909999999"
    db_session.commit()

    login_response = login_user(
        client,
        email=requester.email,
    )
    token = login_response.json()["token"]

    response = client.get(
        "/users/search",
        params={"q": "Teacher"},
        headers=auth_headers(token),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["id"] == target.id
    assert body[0]["full_name"] == "Teacher Public"
    assert body[0]["role"] == "teacher"
    assert body[0]["email"] == "Ho so tutor cong khai"
    assert "phone" not in body[0]
