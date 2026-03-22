from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine

from learning_location_service import DEFAULT_LEARNING_LOCATIONS


def sync_schema(engine: Engine) -> None:
    _ensure_learning_locations_table(engine)
    _ensure_default_learning_locations(engine)
    _ensure_teacher_profile_bank_columns(engine)
    _ensure_class_topic_column(engine)
    _ensure_class_payment_columns(engine)
    _ensure_booking_payment_columns(engine)
    _ensure_payment_columns(engine)
    _ensure_notifications_table(engine)
    _ensure_push_device_tokens_table(engine)


def _ensure_teacher_profile_bank_columns(engine: Engine) -> None:
    table_name = "teacher_profiles"
    missing_columns = {
        "bank_name": "VARCHAR(100)",
        "bank_bin": "VARCHAR(20)",
        "bank_account_number": "VARCHAR(50)",
        "bank_account_holder": "VARCHAR(100)",
    }
    _ensure_columns(engine, table_name, missing_columns)


def _ensure_class_topic_column(engine: Engine) -> None:
    _ensure_columns(
        engine,
        "classes",
        {
            "topic": "VARCHAR(100) NOT NULL DEFAULT ''",
        },
    )

    inspector = inspect(engine)
    if "classes" not in inspector.get_table_names() or "topics" not in inspector.get_table_names():
        return

    with engine.begin() as connection:
        connection.execute(
            text(
                """
                UPDATE classes
                SET topic = topics.name
                FROM topics
                WHERE classes.topic_id = topics.id
                  AND COALESCE(classes.topic, '') = ''
                """
            )
        )


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
            "minimum_participants_reached": "BOOLEAN NOT NULL DEFAULT FALSE",
            "minimum_participants_reached_at": "TIMESTAMPTZ",
            "tutor_confirmation_status": "TEXT NOT NULL DEFAULT 'waiting_minimum'",
            "tutor_confirmed_at": "TIMESTAMPTZ",
            "starting_soon_notified_at": "TIMESTAMPTZ",
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


def _ensure_notifications_table(engine: Engine) -> None:
    inspector = inspect(engine)
    if "notifications" in inspector.get_table_names():
        _ensure_columns(
            engine,
            "notifications",
            {
                "type": "TEXT NOT NULL DEFAULT 'system'",
                "title": "TEXT NOT NULL DEFAULT ''",
                "body": "TEXT NOT NULL DEFAULT ''",
                "data": "TEXT",
                "is_read": "BOOLEAN NOT NULL DEFAULT FALSE",
                "read_at": "TIMESTAMPTZ",
                "created_at": "TIMESTAMPTZ NOT NULL DEFAULT NOW()",
            },
        )
        return

    create_table_statement = """
    CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        data TEXT,
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        read_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """

    with engine.begin() as connection:
        connection.execute(text(create_table_statement))


def _ensure_push_device_tokens_table(engine: Engine) -> None:
    inspector = inspect(engine)
    if "push_device_tokens" in inspector.get_table_names():
        _ensure_columns(
            engine,
            "push_device_tokens",
            {
                "platform": "VARCHAR(20) NOT NULL DEFAULT 'unknown'",
                "device_label": "VARCHAR(120)",
                "is_active": "BOOLEAN NOT NULL DEFAULT TRUE",
                "last_seen_at": "TIMESTAMPTZ",
                "created_at": "TIMESTAMPTZ NOT NULL DEFAULT NOW()",
                "updated_at": "TIMESTAMPTZ NOT NULL DEFAULT NOW()",
            },
        )
        return

    create_table_statement = """
    CREATE TABLE push_device_tokens (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        token TEXT NOT NULL UNIQUE,
        platform VARCHAR(20) NOT NULL DEFAULT 'unknown',
        device_label VARCHAR(120),
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        last_seen_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """

    with engine.begin() as connection:
        connection.execute(text(create_table_statement))


def _ensure_learning_locations_table(engine: Engine) -> None:
    inspector = inspect(engine)
    if "learning_locations" in inspector.get_table_names():
        _ensure_columns(
            engine,
            "learning_locations",
            {
                "latitude": "NUMERIC(10, 8)",
                "longitude": "NUMERIC(10, 7)",
                "notes": "TEXT",
                "is_active": "BOOLEAN NOT NULL DEFAULT TRUE",
                "created_at": "TIMESTAMPTZ NOT NULL DEFAULT NOW()",
                "updated_at": "TIMESTAMPTZ NOT NULL DEFAULT NOW()",
            },
        )
        return

    create_table_statement = """
    CREATE TABLE learning_locations (
        id TEXT PRIMARY KEY,
        name VARCHAR(150) NOT NULL,
        address TEXT NOT NULL,
        latitude NUMERIC(10, 8),
        longitude NUMERIC(10, 7),
        notes TEXT,
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
    """

    with engine.begin() as connection:
        connection.execute(text(create_table_statement))


def _ensure_default_learning_locations(engine: Engine) -> None:
    inspector = inspect(engine)
    if "learning_locations" not in inspector.get_table_names():
        return

    with engine.begin() as connection:
        for location in DEFAULT_LEARNING_LOCATIONS:
            exists = connection.execute(
                text("SELECT 1 FROM learning_locations WHERE id = :id"),
                {"id": location["id"]},
            ).scalar()
            if exists:
                connection.execute(
                    text(
                        """
                        UPDATE learning_locations
                        SET name = :name,
                            address = :address,
                            notes = :notes,
                            is_active = TRUE
                        WHERE id = :id
                        """
                    ),
                    location,
                )
                continue

            connection.execute(
                text(
                    """
                    INSERT INTO learning_locations (
                        id,
                        name,
                        address,
                        notes,
                        is_active
                    ) VALUES (
                        :id,
                        :name,
                        :address,
                        :notes,
                        TRUE
                    )
                    """
                ),
                location,
            )
