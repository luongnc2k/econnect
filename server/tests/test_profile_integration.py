from payment_gateways import PaymentGatewayError, ProviderPayoutDestinationVerificationResult
from routes import profile as profile_routes
from models.student_profile import StudentProfile
from models.teacher_profile import TeacherProfile
from tests.helpers import auth_headers, login_user, seed_user, signup_user


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
            "bank_account_holder": "  Trần Đăng Khoa  ",
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
    assert body["bank_account_holder"] == "TRAN DANG KHOA"
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
    assert teacher_profile.bank_account_holder == "TRAN DANG KHOA"
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


def test_featured_teachers_returns_top_5_ordered_by_rating_then_sessions(
    client,
    db_session,
):
    viewer = seed_user(db_session, role="student", full_name="Student Viewer")
    viewer_login_response = login_user(client, email=viewer.email)
    assert viewer_login_response.status_code == 200
    viewer_token = viewer_login_response.json()["token"]

    teacher_specs = [
        ("Teacher Alpha", 5.0, 80, 20, "IELTS"),
        ("Teacher Beta", 4.9, 150, 50, "Business English"),
        ("Teacher Gamma", 4.9, 90, 40, "TOEIC"),
        ("Teacher Delta", 4.8, 220, 70, "Speaking"),
        ("Teacher Epsilon", 4.7, 180, 35, "Grammar"),
        ("Teacher Zeta", 4.6, 300, 90, "Communication"),
    ]

    for full_name, rating, total_sessions, total_reviews, specialization in teacher_specs:
        teacher = seed_user(db_session, role="teacher", full_name=full_name)
        teacher_profile = TeacherProfile(
            user_id=teacher.id,
            native_language=specialization,
            bio="Featured teacher",
            years_experience=5,
            rating_avg=rating,
            total_sessions=total_sessions,
            total_reviews=total_reviews,
        )
        db_session.add(teacher_profile)

    db_session.commit()

    response = client.get(
        "/profile/featured-teachers",
        headers=auth_headers(viewer_token),
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 5
    assert [teacher["full_name"] for teacher in body] == [
        "Teacher Alpha",
        "Teacher Beta",
        "Teacher Gamma",
        "Teacher Delta",
        "Teacher Epsilon",
    ]
    assert body[0]["rating"] == 5.0
    assert body[1]["total_sessions"] == 150
    assert body[2]["total_sessions"] == 90
    assert body[0]["specialization"] == "IELTS"


def test_student_profile_update_supports_bank_account_and_hides_it_from_others(
    client,
    db_session,
):
    student_payload, student_signup_response = signup_user(
        client,
        role="student",
        full_name="Student Original",
    )
    assert student_signup_response.status_code == 201

    student_login_response = login_user(
        client,
        email=student_payload["email"],
        password=student_payload["password"],
    )
    student_token = student_login_response.json()["token"]

    update_response = client.put(
        "/profile/me",
        headers=auth_headers(student_token),
        json={
            "full_name": "  Student Updated  ",
            "english_level": " intermediate ",
            "learning_goal": "  Giao tiếp tự tin  ",
            "bank_name": " BIDV ",
            "bank_bin": "970418",
            "bank_account_number": " 1234567890 ",
            "bank_account_holder": "  Trần Đăng Khoa  ",
        },
    )

    assert update_response.status_code == 200
    body = update_response.json()
    assert body["full_name"] == "Student Updated"
    assert body["english_level"] == "intermediate"
    assert body["learning_goal"] == "Giao tiếp tự tin"
    assert body["bank_name"] == "BIDV"
    assert body["bank_bin"] == "970418"
    assert body["bank_account_number"] == "1234567890"
    assert body["bank_account_holder"] == "TRAN DANG KHOA"

    student_profile = (
        db_session.query(StudentProfile)
        .filter(StudentProfile.user_id == body["id"])
        .first()
    )
    assert student_profile is not None
    assert student_profile.bank_name == "BIDV"
    assert student_profile.bank_bin == "970418"
    assert student_profile.bank_account_number == "1234567890"
    assert student_profile.bank_account_holder == "TRAN DANG KHOA"

    other_student_payload, other_student_signup_response = signup_user(
        client,
        role="student",
        full_name="Other Student",
    )
    assert other_student_signup_response.status_code == 201
    other_student_login_response = login_user(
        client,
        email=other_student_payload["email"],
        password=other_student_payload["password"],
    )
    other_student_token = other_student_login_response.json()["token"]

    public_response = client.get(
        f"/profile/{body['id']}",
        headers=auth_headers(other_student_token),
    )
    assert public_response.status_code == 200
    public_body = public_response.json()
    assert public_body["bank_name"] is None
    assert public_body["bank_bin"] is None
    assert public_body["bank_account_number"] is None
    assert public_body["bank_account_holder"] is None


def test_student_profile_update_accepts_cefr_english_level_values(
    client,
    db_session,
):
    student_payload, student_signup_response = signup_user(
        client,
        role="student",
        full_name="Student CEFR",
    )
    assert student_signup_response.status_code == 201

    student_login_response = login_user(
        client,
        email=student_payload["email"],
        password=student_payload["password"],
    )
    student_token = student_login_response.json()["token"]

    update_response = client.put(
        "/profile/me",
        headers=auth_headers(student_token),
        json={
            "english_level": " A2 ",
            "bank_name": " BIDV ",
            "bank_bin": "970418",
            "bank_account_number": " 1234567890 ",
            "bank_account_holder": "  Tran Dang Khoa  ",
        },
    )

    assert update_response.status_code == 200
    body = update_response.json()
    assert body["english_level"] == "beginner"
    assert body["bank_name"] == "BIDV"
    assert body["bank_bin"] == "970418"
    assert body["bank_account_number"] == "1234567890"
    assert body["bank_account_holder"] == "TRAN DANG KHOA"

    student_profile = (
        db_session.query(StudentProfile)
        .filter(StudentProfile.user_id == body["id"])
        .first()
    )
    assert student_profile is not None
    assert student_profile.english_level == "beginner"


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


def test_teacher_profile_update_requires_complete_payout_bank_fields(client, db_session):
    teacher = seed_user(
        db_session,
        role="teacher",
        full_name="Teacher Legacy Missing Bank",
    )

    teacher_login_response = login_user(
        client,
        email=teacher.email,
    )
    teacher_token = teacher_login_response.json()["token"]

    response = client.put(
        "/profile/me",
        headers=auth_headers(teacher_token),
        json={
            "bank_name": "MBB",
            "bank_account_number": "11223344455",
        },
    )

    assert response.status_code == 400
    assert (
        response.json()["detail"]
        == "Thong tin ngan hang nhan payout chua day du. Can nhap ca bank_bin va bank_account_number."
    )


def test_teacher_can_verify_payout_bank_account_destination(client, db_session, monkeypatch):
    teacher = seed_user(
        db_session,
        role="teacher",
        full_name="Teacher Verify Bank",
    )

    teacher_login_response = login_user(
        client,
        email=teacher.email,
    )
    teacher_token = teacher_login_response.json()["token"]

    def _fake_verify_provider_payout_destination(*, provider: str, to_bin: str, to_account_number: str):
        assert provider == "payos"
        assert to_bin == "970418"
        assert to_account_number == "1234567890"
        return ProviderPayoutDestinationVerificationResult(
            provider=provider,
            is_valid=True,
            message="payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay",
            estimate_credit=0,
        )

    monkeypatch.setattr(
        profile_routes,
        "verify_provider_payout_destination",
        _fake_verify_provider_payout_destination,
    )

    response = client.post(
        "/profile/me/payout-bank-account/verify",
        headers=auth_headers(teacher_token),
        json={
            "bank_bin": "970418",
            "bank_account_number": "1234567890",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "provider": "payos",
        "is_valid": True,
        "message": "payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay",
        "estimate_credit": 0,
    }


def test_student_can_verify_bank_account_destination(client, db_session, monkeypatch):
    student = seed_user(
        db_session,
        role="student",
        full_name="Student Verify Bank",
    )

    student_login_response = login_user(
        client,
        email=student.email,
    )
    student_token = student_login_response.json()["token"]

    def _fake_verify_provider_payout_destination(*, provider: str, to_bin: str, to_account_number: str):
        assert provider == "payos"
        assert to_bin == "970418"
        assert to_account_number == "1234567890"
        return ProviderPayoutDestinationVerificationResult(
            provider=provider,
            is_valid=True,
            message="payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay",
            estimate_credit=0,
        )

    monkeypatch.setattr(
        profile_routes,
        "verify_provider_payout_destination",
        _fake_verify_provider_payout_destination,
    )

    response = client.post(
        "/profile/me/payout-bank-account/verify",
        headers=auth_headers(student_token),
        json={
            "bank_bin": "970418",
            "bank_account_number": "1234567890",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "provider": "payos",
        "is_valid": True,
        "message": "payOS khong tra loi khi kiem tra so bo tai khoan nhan tien nay",
        "estimate_credit": 0,
    }


def test_teacher_verify_payout_bank_account_returns_invalid_result(client, db_session, monkeypatch):
    teacher = seed_user(
        db_session,
        role="teacher",
        full_name="Teacher Invalid Bank",
    )

    teacher_login_response = login_user(
        client,
        email=teacher.email,
    )
    teacher_token = teacher_login_response.json()["token"]

    def _fake_verify_provider_payout_destination(*, provider: str, to_bin: str, to_account_number: str):
        return ProviderPayoutDestinationVerificationResult(
            provider=provider,
            is_valid=False,
            message="payOS bao khong the hoan tat buoc kiem tra so bo tai khoan nhan tien: Invalid destination account",
        )

    monkeypatch.setattr(
        profile_routes,
        "verify_provider_payout_destination",
        _fake_verify_provider_payout_destination,
    )

    response = client.post(
        "/profile/me/payout-bank-account/verify",
        headers=auth_headers(teacher_token),
        json={
            "bank_bin": "970418",
            "bank_account_number": "9999999999",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "provider": "payos",
        "is_valid": False,
        "message": "payOS bao khong the hoan tat buoc kiem tra so bo tai khoan nhan tien: Invalid destination account",
        "estimate_credit": None,
    }


def test_teacher_verify_payout_bank_account_returns_actionable_ip_error(
    client,
    db_session,
    monkeypatch,
):
    teacher = seed_user(
        db_session,
        role="teacher",
        full_name="Teacher IP Restricted",
    )

    teacher_login_response = login_user(
        client,
        email=teacher.email,
    )
    teacher_token = teacher_login_response.json()["token"]

    def _fake_verify_provider_payout_destination(*, provider: str, to_bin: str, to_account_number: str):
        raise PaymentGatewayError(
            "Khong the xac thuc tai khoan ngan hang payOS: Dia chi IP khong duoc phep truy cap he thong"
        )

    monkeypatch.setattr(
        profile_routes,
        "verify_provider_payout_destination",
        _fake_verify_provider_payout_destination,
    )

    response = client.post(
        "/profile/me/payout-bank-account/verify",
        headers=auth_headers(teacher_token),
        json={
            "bank_bin": "970418",
            "bank_account_number": "1234567890",
        },
    )

    assert response.status_code == 502
    assert response.json()["detail"] == (
        "payOS từ chối kiểm tra vì IP máy chủ hiện tại chưa được thêm vào "
        "Kênh chuyển tiền > Quản lý IP. Nếu bạn đang chạy local/ngrok, hãy đổi "
        "PAYOS_PAYOUT_MOCK_MODE=true trong server/.env rồi restart backend. "
        "Nếu muốn kiểm tra thật, hãy thêm public outbound IP của backend vào my.payos.vn."
    )
