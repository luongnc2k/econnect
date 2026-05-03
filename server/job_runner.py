import asyncio
import logging
import os
from contextlib import suppress
from typing import Callable

from database import SessionLocal
from routes.payments import (
    JOB_SECRET,
    cancel_underfilled_classes,
    notify_classes_starting_soon,
    release_eligible_payouts,
    sync_payout_statuses,
)

logger = logging.getLogger(__name__)

_DEFAULT_INTERVAL_SECONDS = 60
_MIN_INTERVAL_SECONDS = 5


def _env_flag(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def internal_job_runner_enabled() -> bool:
    return _env_flag("INTERNAL_JOB_RUNNER_ENABLED", False)


def internal_job_runner_interval_seconds() -> int:
    raw_value = (os.getenv("INTERNAL_JOB_RUNNER_INTERVAL_SECONDS", "") or "").strip()
    if not raw_value:
        return _DEFAULT_INTERVAL_SECONDS

    try:
        interval = int(raw_value)
    except ValueError:
        logger.warning(
            "Invalid INTERNAL_JOB_RUNNER_INTERVAL_SECONDS=%r. Falling back to %s seconds.",
            raw_value,
            _DEFAULT_INTERVAL_SECONDS,
        )
        return _DEFAULT_INTERVAL_SECONDS

    if interval < _MIN_INTERVAL_SECONDS:
        logger.warning(
            "INTERNAL_JOB_RUNNER_INTERVAL_SECONDS=%s is too low. Clamping to %s seconds.",
            interval,
            _MIN_INTERVAL_SECONDS,
        )
        return _MIN_INTERVAL_SECONDS

    return interval


def _run_job(
    name: str,
    handler: Callable,
) -> dict[str, object]:
    if not JOB_SECRET:
        logger.warning("Skipping internal job runner task %s because JOB_SECRET is empty.", name)
        return {"skipped": True, "reason": "missing_job_secret"}

    db = SessionLocal()
    try:
        result = handler(
            db=db,
            user_dict=None,
            x_job_secret=JOB_SECRET,
        )
        logger.info("Internal job runner completed %s: %s", name, result)
        return {"skipped": False, "result": result}
    except Exception as exc:  # pragma: no cover - defensive background path
        db.rollback()
        logger.exception("Internal job runner failed while executing %s", name)
        return {"skipped": False, "error": str(exc)}
    finally:
        db.close()


def run_scheduled_jobs_once() -> dict[str, dict[str, object]]:
    return {
        "notify_classes_starting_soon": _run_job(
            "notify_classes_starting_soon",
            notify_classes_starting_soon,
        ),
        "cancel_underfilled_classes": _run_job(
            "cancel_underfilled_classes",
            cancel_underfilled_classes,
        ),
        "release_eligible_payouts": _run_job(
            "release_eligible_payouts",
            release_eligible_payouts,
        ),
        "sync_payout_statuses": _run_job(
            "sync_payout_statuses",
            sync_payout_statuses,
        ),
    }


async def run_internal_job_runner(stop_event: asyncio.Event) -> None:
    interval_seconds = internal_job_runner_interval_seconds()
    logger.info(
        "Internal job runner started with interval=%s seconds.",
        interval_seconds,
    )

    try:
        while not stop_event.is_set():
            await asyncio.to_thread(run_scheduled_jobs_once)
            try:
                await asyncio.wait_for(stop_event.wait(), timeout=interval_seconds)
            except TimeoutError:
                continue
    except asyncio.CancelledError:  # pragma: no cover - shutdown path
        logger.info("Internal job runner cancelled.")
        raise
    finally:
        with suppress(Exception):
            stop_event.set()
        logger.info("Internal job runner stopped.")
