from models.booking import Booking
from models.class_ import Class
from models.payment import Payment
from tests.helpers import seed_paid_class_with_held_booking

from job_runner import run_scheduled_jobs_once


def test_internal_job_runner_releases_due_payouts(db_session):
    seeded = seed_paid_class_with_held_booking(db_session)

    result = run_scheduled_jobs_once()

    release_result = result["release_eligible_payouts"]
    assert release_result["skipped"] is False
    assert release_result["result"]["count"] == 1
    assert release_result["result"]["released"][0]["class_id"] == seeded["class"].id
    assert release_result["result"]["released"][0]["status"] == "paid"

    db_session.expire_all()
    cls = db_session.query(Class).filter(Class.id == seeded["class"].id).first()
    booking = db_session.query(Booking).filter(Booking.id == seeded["booking"].id).first()
    payout_payment = (
        db_session.query(Payment)
        .filter(Payment.class_id == seeded["class"].id, Payment.payment_type == "payout")
        .first()
    )

    assert cls is not None
    assert booking is not None
    assert payout_payment is not None
    assert cls.status == "completed"
    assert cls.tutor_payout_status == "paid"
    assert booking.escrow_status == "released"
    assert payout_payment.status == "released"
