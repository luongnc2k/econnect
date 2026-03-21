from decimal import Decimal

from models.booking import Booking
from models.class_ import Class
from models.notification import Notification
from models.payment import Payment
from notification_service import serialize_notification_data
from tests.helpers import (
    seed_paid_class_with_held_booking,
    seed_paid_class_with_held_bookings,
    seed_processing_payout,
)


def test_release_eligible_payouts_requires_job_secret_and_releases_held_escrow(client, db_session):
    seeded = seed_paid_class_with_held_booking(db_session)

    unauthorized_response = client.post("/payments/jobs/release-eligible-payouts")
    assert unauthorized_response.status_code == 401

    response = client.post(
        "/payments/jobs/release-eligible-payouts",
        headers={"x-job-secret": "test-job-secret"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["released"][0]["class_id"] == seeded["class"].id
    assert body["released"][0]["status"] == "paid"

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == seeded["class"].id).first()
    booking = db_session.query(Booking).filter(Booking.id == seeded["booking"].id).first()
    tuition_payment = (
        db_session.query(Payment)
        .filter(Payment.id == seeded["tuition_payment"].id)
        .first()
    )
    payout_payment = (
        db_session.query(Payment)
        .filter(Payment.class_id == seeded["class"].id, Payment.payment_type == "payout")
        .first()
    )

    assert cls is not None
    assert booking is not None
    assert tuition_payment is not None
    assert payout_payment is not None
    assert cls.status == "completed"
    assert cls.tutor_payout_status == "paid"
    assert booking.status == "completed"
    assert booking.escrow_status == "released"
    assert tuition_payment.status == "released"
    assert payout_payment.status == "released"

    payout_notifications = (
        db_session.query(Notification)
        .filter(
            Notification.user_id == seeded["teacher"].id,
            Notification.type == "payout_updated",
        )
        .all()
    )
    assert len(payout_notifications) == 1
    payout_data = serialize_notification_data(payout_notifications[0].data)
    assert payout_data["class_id"] == seeded["class"].id
    assert payout_data["payout_status"] == "paid"


def test_sync_payout_statuses_updates_processing_payouts(client, db_session):
    seeded = seed_processing_payout(db_session)

    response = client.post(
        "/payments/jobs/sync-payout-statuses",
        headers={"x-job-secret": "test-job-secret"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1
    assert body["synced"][0]["class_id"] == seeded["class"].id
    assert body["synced"][0]["status"] == "paid"

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == seeded["class"].id).first()
    booking = db_session.query(Booking).filter(Booking.id == seeded["booking"].id).first()
    tuition_payment = (
        db_session.query(Payment)
        .filter(Payment.id == seeded["tuition_payment"].id)
        .first()
    )
    payout_payment = (
        db_session.query(Payment)
        .filter(Payment.id == seeded["payout_payment"].id)
        .first()
    )

    assert cls is not None
    assert booking is not None
    assert tuition_payment is not None
    assert payout_payment is not None
    assert cls.tutor_payout_status == "paid"
    assert booking.escrow_status == "released"
    assert tuition_payment.status == "released"
    assert payout_payment.status == "released"


def test_release_eligible_payouts_uses_only_current_paid_student_tuition_total(client, db_session):
    seeded = seed_paid_class_with_held_bookings(
        db_session,
        student_count=2,
        add_failed_historical_payment=True,
    )

    response = client.post(
        "/payments/jobs/release-eligible-payouts",
        headers={"x-job-secret": "test-job-secret"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["count"] == 1

    expected_total = sum(
        (Decimal(payment.amount) for payment in seeded["tuition_payments"]),
        Decimal("0"),
    )
    assert body["released"][0]["class_id"] == seeded["class"].id
    assert Decimal(body["released"][0]["amount"]) == expected_total
    assert body["released"][0]["status"] == "paid"

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == seeded["class"].id).first()
    payout_payment = (
        db_session.query(Payment)
        .filter(Payment.class_id == seeded["class"].id, Payment.payment_type == "payout")
        .first()
    )
    historical_failed_payment = (
        db_session.query(Payment)
        .filter(Payment.id == seeded["historical_failed_payment"].id)
        .first()
    )
    released_tuition_payments = (
        db_session.query(Payment)
        .filter(
            Payment.class_id == seeded["class"].id,
            Payment.payment_type == "tuition",
            Payment.status == "released",
        )
        .all()
    )

    assert cls is not None
    assert payout_payment is not None
    assert historical_failed_payment is not None
    assert cls.tutor_payout_amount == expected_total
    assert Decimal(payout_payment.amount) == expected_total
    assert historical_failed_payment.status == "failed"
    assert len(released_tuition_payments) == 2
