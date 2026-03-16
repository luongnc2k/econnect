from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def sync_schema(engine: Engine) -> None:
    _ensure_teacher_profile_bank_columns(engine)
    _ensure_class_payment_columns(engine)
    _ensure_booking_payment_columns(engine)
    _ensure_payment_columns(engine)


def _ensure_teacher_profile_bank_columns(engine: Engine) -> None:
    table_name = "teacher_profiles"
    missing_columns = {
        "bank_name": "VARCHAR(100)",
        "bank_account_number": "VARCHAR(50)",
        "bank_account_holder": "VARCHAR(100)",
    }
    _ensure_columns(engine, table_name, missing_columns)


def _ensure_class_payment_columns(engine: Engine) -> None:
    _ensure_columns(
        engine,
        "classes",
        {
            "creation_fee_amount": "NUMERIC(10, 0) NOT NULL DEFAULT 0",
            "creation_payment_status": "TEXT NOT NULL DEFAULT 'unpaid'",
            "creation_payment_reference": "TEXT",
            "creation_paid_at": "TIMESTAMPTZ",
            "cancellation_reason": "TEXT",
            "cancelled_at": "TIMESTAMPTZ",
            "tutor_payout_status": "TEXT NOT NULL DEFAULT 'pending'",
            "tutor_payout_amount": "NUMERIC(10, 0) NOT NULL DEFAULT 0",
            "tutor_paid_at": "TIMESTAMPTZ",
            "complaint_deadline": "TIMESTAMPTZ",
            "has_active_dispute": "BOOLEAN NOT NULL DEFAULT FALSE",
        },
    )


def _ensure_booking_payment_columns(engine: Engine) -> None:
    _ensure_columns(
        engine,
        "bookings",
        {
            "payment_status": "TEXT NOT NULL DEFAULT 'pending'",
            "payment_reference": "TEXT",
            "payment_method": "TEXT",
            "tuition_amount": "NUMERIC(10, 0) NOT NULL DEFAULT 0",
            "escrow_status": "TEXT NOT NULL DEFAULT 'pending'",
            "escrow_held_at": "TIMESTAMPTZ",
            "complaint_status": "TEXT NOT NULL DEFAULT 'none'",
            "complaint_reason": "TEXT",
            "complaint_opened_at": "TIMESTAMPTZ",
        },
    )


def _ensure_payment_columns(engine: Engine) -> None:
    _ensure_columns(
        engine,
        "payments",
        {
            "class_id": "TEXT",
            "payer_user_id": "TEXT",
            "payee_user_id": "TEXT",
            "payment_type": "TEXT",
            "provider": "TEXT",
            "currency": "TEXT NOT NULL DEFAULT 'VND'",
            "provider_order_id": "TEXT",
            "provider_payload": "TEXT",
            "redirect_url": "TEXT",
            "refunded_at": "TIMESTAMPTZ",
            "released_at": "TIMESTAMPTZ",
            "failure_reason": "TEXT",
        },
    )


def _ensure_columns(engine: Engine, table_name: str, columns: dict[str, str]) -> None:
    inspector = inspect(engine)
    if table_name not in inspector.get_table_names():
        return

    existing_columns = {column["name"] for column in inspector.get_columns(table_name)}
    statements = [
        f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"
        for column_name, column_type in columns.items()
        if column_name not in existing_columns
    ]

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
