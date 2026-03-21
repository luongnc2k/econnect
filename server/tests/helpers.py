import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

import bcrypt
from sqlalchemy.orm import Session

from models.booking import Booking
from models.class_ import Class
from models.payment import Payment
from models.teacher_profile import TeacherProfile
from models.topic import Topic
from models.user import User
from pydantic_schemas.payment import calculate_creation_fee, calculate_student_tuition


DEFAULT_PASSWORD = "Password123!"


def auth_headers(token: str) -> dict[str, str]:
    return {"x-auth-token": token}


def signup_user(
    client,
    *,
    role: str,
    email: str | None = None,
    full_name: str | None = None,
    password: str = DEFAULT_PASSWORD,
):
    payload = {
        "email": email or f"{role}.{uuid.uuid4().hex[:10]}@example.com",
        "password": password,
        "full_name": full_name or f"{role.title()} User",
        "role": role,
    }
    response = client.post("/auth/signup", json=payload)
    return payload, response


def login_user(client, *, email: str, password: str = DEFAULT_PASSWORD):
    return client.post(
        "/auth/login",
        json={
            "email": email,
            "password": password,
        },
    )


def create_admin_user(
    client,
    *,
    email: str | None = None,
    full_name: str = "Admin User",
    password: str = DEFAULT_PASSWORD,
    admin_secret: str = "test-admin-secret",
):
    payload = {
        "email": email or f"admin.{uuid.uuid4().hex[:10]}@example.com",
        "password": password,
        "full_name": full_name,
        "role": "admin",
    }
    response = client.post(
        "/auth/create-admin",
        json=payload,
        headers={"x-admin-secret": admin_secret},
    )
    return payload, response


def seed_user(
    db: Session,
    *,
    role: str,
    email: str | None = None,
    full_name: str | None = None,
    password: str = DEFAULT_PASSWORD,
    is_active: bool = True,
) -> User:
    user = User(
        id=str(uuid.uuid4()),
        email=email or f"{role}.{uuid.uuid4().hex[:10]}@example.com",
        password_hash=bcrypt.hashpw(password.encode(), bcrypt.gensalt()),
        full_name=full_name or f"{role.title()} Seed",
        role=role,
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def create_topic(db: Session, *, name: str = "English Conversation") -> Topic:
    suffix = uuid.uuid4().hex[:8]
    topic = Topic(
        id=str(uuid.uuid4()),
        name=name,
        slug=f"{name.lower().replace(' ', '-')}-{suffix}",
        description=f"Topic {name}",
        icon="book",
        is_active=True,
    )
    db.add(topic)
    db.commit()
    db.refresh(topic)
    return topic


def seed_teacher_profile(
    db: Session,
    *,
    teacher_id: str,
    bank_name: str = "ACB",
    bank_bin: str = "970416",
    bank_account_number: str = "0123456789",
    bank_account_holder: str = "Teacher Seed",
) -> TeacherProfile:
    teacher_profile = TeacherProfile(
        user_id=teacher_id,
        native_language="English",
        bio="Experienced tutor",
        bank_name=bank_name,
        bank_bin=bank_bin,
        bank_account_number=bank_account_number,
        bank_account_holder=bank_account_holder,
        certifications=["TESOL"],
        years_experience=5,
        verification_docs=["https://example.com/doc.pdf"],
    )
    db.add(teacher_profile)
    db.commit()
    db.refresh(teacher_profile)
    return teacher_profile


def seed_paid_class_with_held_booking(
    db: Session,
    *,
    teacher: User | None = None,
    student: User | None = None,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    class_status: str = "scheduled",
    tutor_payout_status: str = "pending",
    amount: Decimal = Decimal("200000"),
) -> dict[str, object]:
    teacher = teacher or seed_user(db, role="teacher")
    student = student or seed_user(db, role="student")
    topic = create_topic(db)
    seed_teacher_profile(db, teacher_id=teacher.id, bank_account_holder=teacher.full_name)

    now = datetime.now(timezone.utc)
    actual_start_time = start_time or (now - timedelta(hours=3))
    actual_end_time = end_time or (now - timedelta(hours=2, minutes=30))
    tuition_amount = calculate_student_tuition(amount, 1)

    cls = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        title="Production Readiness Class",
        description="Payout-ready class",
        level="intermediate",
        location_name="Online",
        location_address="Zoom",
        start_time=actual_start_time,
        end_time=actual_end_time,
        min_participants=1,
        max_participants=1,
        current_participants=1,
        price=amount,
        creation_fee_amount=calculate_creation_fee(amount),
        creation_payment_status="paid",
        creation_payment_reference=f"CRF-{uuid.uuid4().hex[:10].upper()}",
        status=class_status,
        tutor_payout_status=tutor_payout_status,
        tutor_payout_amount=Decimal("0"),
        has_active_dispute=False,
    )
    db.add(cls)
    db.flush()

    booking = Booking(
        id=str(uuid.uuid4()),
        class_id=cls.id,
        student_id=student.id,
        status="confirmed",
        payment_status="paid",
        payment_method="payos",
        payment_reference=f"TUI-{uuid.uuid4().hex[:10].upper()}",
        tuition_amount=tuition_amount,
        escrow_status="held",
        escrow_held_at=actual_end_time - timedelta(minutes=15),
    )
    db.add(booking)
    db.flush()

    tuition_payment = Payment(
        id=str(uuid.uuid4()),
        booking_id=booking.id,
        class_id=cls.id,
        payer_user_id=student.id,
        payee_user_id=teacher.id,
        payment_type="tuition",
        provider="payos",
        amount=tuition_amount,
        status="paid",
        transaction_ref=booking.payment_reference,
        provider_order_id=booking.payment_reference,
        paid_at=actual_end_time - timedelta(minutes=15),
    )
    db.add(tuition_payment)
    db.commit()

    db.refresh(cls)
    db.refresh(booking)
    db.refresh(tuition_payment)

    return {
        "teacher": teacher,
        "student": student,
        "topic": topic,
        "class": cls,
        "booking": booking,
        "tuition_payment": tuition_payment,
    }


def seed_paid_class_with_held_bookings(
    db: Session,
    *,
    teacher: User | None = None,
    student_count: int = 2,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    class_status: str = "scheduled",
    tutor_payout_status: str = "pending",
    amount: Decimal = Decimal("200000"),
    add_failed_historical_payment: bool = False,
) -> dict[str, object]:
    if student_count < 1:
        raise ValueError("student_count phai lon hon hoac bang 1")

    teacher = teacher or seed_user(db, role="teacher")
    topic = create_topic(db)
    seed_teacher_profile(db, teacher_id=teacher.id, bank_account_holder=teacher.full_name)

    now = datetime.now(timezone.utc)
    actual_start_time = start_time or (now - timedelta(hours=3))
    actual_end_time = end_time or (now - timedelta(hours=2, minutes=30))
    max_participants = student_count
    tuition_amount = calculate_student_tuition(amount, max_participants)

    cls = Class(
        id=str(uuid.uuid4()),
        teacher_id=teacher.id,
        topic_id=topic.id,
        title="Production Readiness Class",
        description="Payout-ready class",
        level="intermediate",
        location_name="Online",
        location_address="Zoom",
        start_time=actual_start_time,
        end_time=actual_end_time,
        min_participants=1,
        max_participants=max_participants,
        current_participants=student_count,
        price=amount,
        creation_fee_amount=calculate_creation_fee(amount),
        creation_payment_status="paid",
        creation_payment_reference=f"CRF-{uuid.uuid4().hex[:10].upper()}",
        status=class_status,
        tutor_payout_status=tutor_payout_status,
        tutor_payout_amount=Decimal("0"),
        has_active_dispute=False,
    )
    db.add(cls)
    db.flush()

    students: list[User] = []
    bookings: list[Booking] = []
    tuition_payments: list[Payment] = []

    for index in range(student_count):
        student = seed_user(db, role="student", full_name=f"Student Seed {index + 1}")
        booking = Booking(
            id=str(uuid.uuid4()),
            class_id=cls.id,
            student_id=student.id,
            status="confirmed",
            payment_status="paid",
            payment_method="payos",
            payment_reference=f"TUI-{uuid.uuid4().hex[:10].upper()}",
            tuition_amount=tuition_amount,
            escrow_status="held",
            escrow_held_at=actual_end_time - timedelta(minutes=15),
        )
        db.add(booking)
        db.flush()

        tuition_payment = Payment(
            id=str(uuid.uuid4()),
            booking_id=booking.id,
            class_id=cls.id,
            payer_user_id=student.id,
            payee_user_id=teacher.id,
            payment_type="tuition",
            provider="payos",
            amount=tuition_amount,
            status="paid",
            transaction_ref=booking.payment_reference,
            provider_order_id=booking.payment_reference,
            paid_at=actual_end_time - timedelta(minutes=15),
        )
        db.add(tuition_payment)

        students.append(student)
        bookings.append(booking)
        tuition_payments.append(tuition_payment)

    historical_failed_payment = None
    if add_failed_historical_payment:
        historical_failed_payment = Payment(
            id=str(uuid.uuid4()),
            booking_id=bookings[0].id,
            class_id=cls.id,
            payer_user_id=students[0].id,
            payee_user_id=teacher.id,
            payment_type="tuition",
            provider="payos",
            amount=tuition_amount,
            status="failed",
            transaction_ref=f"TUI-FAILED-{uuid.uuid4().hex[:8].upper()}",
            provider_order_id=f"FAILED-{uuid.uuid4().hex[:8].upper()}",
            failure_reason="Historical failed payment",
        )
        db.add(historical_failed_payment)

    db.commit()

    db.refresh(cls)
    for booking in bookings:
        db.refresh(booking)
    for tuition_payment in tuition_payments:
        db.refresh(tuition_payment)
    if historical_failed_payment:
        db.refresh(historical_failed_payment)

    return {
        "teacher": teacher,
        "students": students,
        "topic": topic,
        "class": cls,
        "bookings": bookings,
        "tuition_payments": tuition_payments,
        "historical_failed_payment": historical_failed_payment,
        "tuition_amount": tuition_amount,
    }


def seed_processing_payout(db: Session) -> dict[str, object]:
    seeded = seed_paid_class_with_held_booking(db, tutor_payout_status="processing")
    cls = seeded["class"]
    tuition_payment = seeded["tuition_payment"]
    teacher = seeded["teacher"]

    payout_payment = Payment(
        id=str(uuid.uuid4()),
        class_id=cls.id,
        payer_user_id="system",
        payee_user_id=teacher.id,
        booking_id=None,
        payment_type="payout",
        provider="payos",
        amount=tuition_payment.amount,
        status="processing",
        transaction_ref=f"OUT-{uuid.uuid4().hex[:10].upper()}",
        provider_order_id="mock-payout-out-processing",
    )
    cls.tutor_payout_amount = Decimal(tuition_payment.amount)
    db.add(payout_payment)
    db.commit()
    db.refresh(cls)
    db.refresh(payout_payment)

    seeded["payout_payment"] = payout_payment
    return seeded
