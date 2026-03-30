import logging
import os
from urllib.parse import urlparse

from sqlalchemy import text
from sqlalchemy.engine import Engine


logger = logging.getLogger(__name__)
DEFAULT_DEV_JWT_SECRET = "dev_jwt_secret_change_me_please_32bytes"
DEFAULT_CANCEL_UNDERFILLED_CLASSES_HOURS = 4.0
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


def _payment_gateway_mode() -> str:
    return _env("PAYMENT_GATEWAY_MODE", "mock").lower() or "mock"


def payos_payment_mock_mode_enabled() -> bool:
    return _env_flag("PAYOS_MOCK_MODE", _payment_gateway_mode() == "mock")


def payos_payout_mock_mode_enabled() -> bool:
    return _env_flag("PAYOS_PAYOUT_MOCK_MODE", _payment_gateway_mode() == "mock")


def payos_payout_force_ipv4_enabled() -> bool:
    return _env_flag("PAYOS_PAYOUT_FORCE_IPV4", _env_flag("PAYOS_FORCE_IPV4", False))


def cancel_underfilled_classes_hours() -> float:
    raw_value = _env(
        "CANCEL_UNDERFILLED_CLASSES_HOURS",
        str(DEFAULT_CANCEL_UNDERFILLED_CLASSES_HOURS),
    )
    try:
        parsed = float(raw_value)
    except ValueError:
        logger.warning(
            "Invalid CANCEL_UNDERFILLED_CLASSES_HOURS=%r. Falling back to %s hours.",
            raw_value,
            DEFAULT_CANCEL_UNDERFILLED_CLASSES_HOURS,
        )
        return DEFAULT_CANCEL_UNDERFILLED_CLASSES_HOURS

    if parsed <= 0:
        logger.warning(
            "CANCEL_UNDERFILLED_CLASSES_HOURS=%r must be > 0. Falling back to %s hours.",
            raw_value,
            DEFAULT_CANCEL_UNDERFILLED_CLASSES_HOURS,
        )
        return DEFAULT_CANCEL_UNDERFILLED_CLASSES_HOURS

    return parsed


def payos_payout_real_mode_startup_notice() -> str | None:
    if _payment_gateway_mode() == "mock" or payos_payout_mock_mode_enabled():
        return None
    if payos_payout_force_ipv4_enabled():
        return (
            "payOS payout real mode dang bat va backend se ep ket noi payout qua IPv4 "
            "vi PAYOS_PAYOUT_FORCE_IPV4=true. Hay dam bao IPv4 public outbound cua backend "
            "da duoc them vao my.payos.vn > Kenh chuyen tien > Quan ly IP."
        )
    return (
        "payOS tu choi kiem tra vi IP may chu hien tai chua duoc them vao "
        "Kenh chuyen tien > Quan ly IP. Neu ban dang chay local/ngrok, hay doi "
        "PAYOS_PAYOUT_MOCK_MODE=true trong server/.env roi restart backend. "
        "Neu muon kiem tra that, hay them public outbound IP cua backend vao my.payos.vn. "
        "Neu may local uu tien IPv6 va ban chi allowlist IPv4, hay bat them "
        "PAYOS_PAYOUT_FORCE_IPV4=true."
    )


def log_startup_notices() -> None:
    payout_notice = payos_payout_real_mode_startup_notice()
    if payout_notice:
        if payos_payout_force_ipv4_enabled():
            logger.info("Startup notice: %s", payout_notice)
        else:
            logger.warning("Startup notice: %s", payout_notice)


def runtime_summary() -> dict[str, object]:
    internal_job_runner_enabled = _env_flag("INTERNAL_JOB_RUNNER_ENABLED", False)
    payment_gateway_mode = _payment_gateway_mode()
    return {
        "app_env": app_environment(),
        "payment_gateway_mode": payment_gateway_mode,
        "payos_mock_mode": payos_payment_mock_mode_enabled(),
        "payos_payout_mock_mode": payos_payout_mock_mode_enabled(),
        "payos_payout_force_ipv4": payos_payout_force_ipv4_enabled(),
        "strict_startup_validation": strict_startup_validation_enabled(),
        "auto_init_schema": _env_flag("AUTO_INIT_SCHEMA", True),
        "internal_job_runner_enabled": internal_job_runner_enabled,
        "internal_job_runner_interval_seconds": _env(
            "INTERNAL_JOB_RUNNER_INTERVAL_SECONDS",
            "60",
        ),
        "cancel_underfilled_classes_hours": cancel_underfilled_classes_hours(),
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
    payment_gateway_mode = _payment_gateway_mode()
    payment_public_base_url = _env("PAYMENT_PUBLIC_BASE_URL")
    payment_mock_mode = payos_payment_mock_mode_enabled()
    payout_mock_mode = payos_payout_mock_mode_enabled()
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
