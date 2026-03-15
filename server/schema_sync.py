from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def sync_schema(engine: Engine) -> None:
    _ensure_teacher_profile_bank_columns(engine)


def _ensure_teacher_profile_bank_columns(engine: Engine) -> None:
    inspector = inspect(engine)
    table_name = "teacher_profiles"

    if table_name not in inspector.get_table_names():
        return

    existing_columns = {column["name"] for column in inspector.get_columns(table_name)}
    missing_columns = {
        "bank_name": "VARCHAR(100)",
        "bank_account_number": "VARCHAR(50)",
        "bank_account_holder": "VARCHAR(100)",
    }

    statements = [
        f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}"
        for column_name, column_type in missing_columns.items()
        if column_name not in existing_columns
    ]

    if not statements:
        return

    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
