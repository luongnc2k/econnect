import logging
import os
from urllib.parse import urlparse

from sqlalchemy import text
from sqlalchemy.engine import Engine


logger = logging.getLogger(__name__)
DEFAULT_DEV_JWT_SECRET = "dev_jwt_secret_change_me_please_32bytes"
LOCAL_HOSTS = {"localhost", "127.0.0.1", "0.0.0.0"}
PLACEHOLDER_PREFIXES = (
    "change_this",
    "your_",
    "example",
    "replace_me",
)


def _env(name: str, default: str = "") -> str:
    return (os.getenv(name, default) or "").strip()


def _env_flag(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def app_environment() -> str:
    normalized = _env("APP_ENV", "development").lower()
    return normalized or "development"


def is_production_environment() -> bool:
    return app_environment() == "production"


def strict_startup_validation_enabled() -> bool:
    return _env_flag("STRICT_STARTUP_VALIDATION", is_production_environment())


def runtime_summary() -> dict[str, object]:
    return {
        "app_env": app_environment(),
        "payment_gateway_mode": _env("PAYMENT_GATEWAY_MODE", "mock").lower() or "mock",
        "strict_startup_validation": strict_startup_validation_enabled(),
        "auto_init_schema": _env_flag("AUTO_INIT_SCHEMA", True),
    }


def _looks_like_placeholder(value: str) -> bool:
    normalized = value.strip().lower()
    if not normalized:
        return True
    return any(normalized.startswith(prefix) for prefix in PLACEHOLDER_PREFIXES)


def _validate_public_url(name: str, value: str, *, require_https: bool) -> list[str]:
    if not value:
        return [f"{name} chua duoc cau hinh"]

    parsed = urlparse(value)
    errors = []
    if parsed.scheme not in {"http", "https"}:
        errors.append(f"{name} phai bat dau bang http:// hoac https://")
    if not parsed.netloc:
        errors.append(f"{name} khong hop le")
    if parsed.hostname in LOCAL_HOSTS:
        errors.append(f"{name} khong duoc tro toi localhost trong production")
    if require_https and parsed.scheme != "https":
        errors.append(f"{name} phai dung HTTPS trong production")
    return errors


def _validate_required_envs(names: list[str]) -> list[str]:
    missing: list[str] = []
    for name in names:
        value = _env(name)
        if _looks_like_placeholder(value):
            missing.append(name)
    return missing


def validate_runtime_configuration(cors_origins: list[str]) -> None:
    env_name = app_environment()
    strict_validation = strict_startup_validation_enabled()
    should_warn = env_name != "development"
    issues: list[str] = []
    warnings: list[str] = []

    jwt_secret = _env("JWT_SECRET", DEFAULT_DEV_JWT_SECRET)
    admin_create_secret = _env("ADMIN_CREATE_SECRET")
    job_secret = _env("JOB_SECRET")
    payment_gateway_mode = _env("PAYMENT_GATEWAY_MODE", "mock").lower() or "mock"
    payment_public_base_url = _env("PAYMENT_PUBLIC_BASE_URL")
    payment_mock_mode = _env_flag("PAYOS_MOCK_MODE", payment_gateway_mode == "mock")
    payout_mock_mode = _env_flag("PAYOS_PAYOUT_MOCK_MODE", payment_gateway_mode == "mock")
    server_public_url = _env("SERVER_PUBLIC_URL")
    static_public_url = _env("STATIC_PUBLIC_URL")

    if jwt_secret == DEFAULT_DEV_JWT_SECRET or len(jwt_secret) < 32:
        if env_name == "production":
            issues.append("JWT_SECRET dang dung gia tri mac dinh hoac qua ngan")
        elif should_warn:
            warnings.append("JWT_SECRET dang dung gia tri mac dinh hoac qua ngan")

    for secret_name, secret_value in {
        "ADMIN_CREATE_SECRET": admin_create_secret,
        "JOB_SECRET": job_secret,
    }.items():
        if _looks_like_placeholder(secret_value):
            if env_name == "production":
                issues.append(f"{secret_name} chua duoc doi khoi gia tri mau")
            elif should_warn:
                warnings.append(f"{secret_name} chua duoc doi khoi gia tri mau")

    if payment_gateway_mode == "mock":
        if env_name == "production":
            issues.append("PAYMENT_GATEWAY_MODE dang o mock")
        elif should_warn:
            warnings.append("PAYMENT_GATEWAY_MODE dang o mock")

    if payment_gateway_mode != "mock" and not payment_mock_mode:
        missing_payment_envs = _validate_required_envs(
            ["PAYOS_CLIENT_ID", "PAYOS_API_KEY", "PAYOS_CHECKSUM_KEY"]
        )
        if missing_payment_envs:
            message = "Thieu cau hinh payOS payment: " + ", ".join(missing_payment_envs)
            if env_name == "production":
                issues.append(message)
            elif should_warn:
                warnings.append(message)

    if payment_gateway_mode != "mock" and not payout_mock_mode:
        missing_payout_envs = _validate_required_envs(
            ["PAYOS_PAYOUT_CLIENT_ID", "PAYOS_PAYOUT_API_KEY", "PAYOS_PAYOUT_CHECKSUM_KEY"]
        )
        if missing_payout_envs:
            message = "Thieu cau hinh payOS payout rieng: " + ", ".join(missing_payout_envs)
            if env_name == "production":
                issues.append(message)
            elif should_warn:
                warnings.append(message)

    if cors_origins == ["*"]:
        if env_name == "production":
            issues.append("CORS_ALLOW_ORIGINS dang mo toan bo (*)")
        elif should_warn:
            warnings.append("CORS_ALLOW_ORIGINS dang mo toan bo (*)")

    if _env_flag("AUTO_INIT_SCHEMA", True):
        if env_name == "production":
            issues.append("AUTO_INIT_SCHEMA dang bat; production nen dung migration co kiem soat")
        elif should_warn:
            warnings.append("AUTO_INIT_SCHEMA dang bat; production nen dung migration co kiem soat")

    if env_name == "production":
        issues.extend(
            _validate_public_url(
                "PAYMENT_PUBLIC_BASE_URL",
                payment_public_base_url,
                require_https=True,
            )
        )
        if server_public_url:
            issues.extend(
                _validate_public_url(
                    "SERVER_PUBLIC_URL",
                    server_public_url,
                    require_https=True,
                )
            )
        if static_public_url:
            issues.extend(
                _validate_public_url(
                    "STATIC_PUBLIC_URL",
                    static_public_url,
                    require_https=True,
                )
            )

    for warning in warnings:
        logger.warning("Runtime configuration warning: %s", warning)

    if issues:
        message = "; ".join(issues)
        if strict_validation:
            raise RuntimeError(f"Runtime configuration invalid: {message}")
        logger.warning("Runtime configuration issues ignored because strict validation is off: %s", message)


def database_ready(engine: Engine) -> tuple[bool, str]:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True, "ok"
    except Exception as exc:  # pragma: no cover - defensive production path
        logger.exception("Database readiness check failed")
        return False, str(exc)
