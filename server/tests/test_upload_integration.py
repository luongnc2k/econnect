from tests.helpers import auth_headers, login_user, signup_user


def _teacher_token(client) -> str:
    payload, signup_response = signup_user(
        client,
        role="teacher",
        full_name="Teacher Material",
        with_bank_account=True,
    )
    assert signup_response.status_code == 201
    login_response = login_user(client, email=payload["email"], password=payload["password"])
    assert login_response.status_code == 200
    return login_response.json()["token"]


def test_teacher_can_upload_pdf_class_material(client):
    token = _teacher_token(client)

    response = client.post(
        "/upload/class-material",
        headers=auth_headers(token),
        files={
            "file": (
                "lesson.pdf",
                b"%PDF-1.4\n% lesson material\n",
                "application/pdf",
            )
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["file_name"] == "lesson.pdf"
    assert body["url"].endswith(".pdf")
    assert "/static/class-materials/" in body["url"]


def test_class_material_rejects_unsupported_format(client):
    token = _teacher_token(client)

    response = client.post(
        "/upload/class-material",
        headers=auth_headers(token),
        files={
            "file": (
                "lesson.txt",
                b"plain text",
                "text/plain",
            )
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Chi ho tro tai lieu dinh dang PDF, DOC hoac DOCX"


def test_class_material_rejects_file_not_smaller_than_3mb(client):
    token = _teacher_token(client)
    exactly_3mb_pdf = b"%PDF-" + (b"x" * ((3 * 1024 * 1024) - 5))

    response = client.post(
        "/upload/class-material",
        headers=auth_headers(token),
        files={
            "file": (
                "oversized.pdf",
                exactly_3mb_pdf,
                "application/pdf",
            )
        },
    )

    assert response.status_code == 400
    assert "File too large" in response.json()["detail"]
