import json
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, Optional
from urllib.parse import urlencode


PAYOS_PROVIDER = "payos"


@dataclass
class ProviderCreateResult:
    provider: str
    redirect_url: str
    provider_order_id: Optional[str] = None
    provider_payload: Optional[str] = None


@dataclass
class ProviderVerificationResult:
    transaction_ref: str
    is_success: bool
    provider_transaction_id: Optional[str] = None
    raw_payload: Optional[str] = None
    message: Optional[str] = None
    provider_status: Optional[str] = None


@dataclass
class ProviderWebhookConfirmationResult:
    webhook_url: str
    account_name: str
    account_number: str
    name: str
    short_name: str


@dataclass
class ProviderPayoutResult:
    provider: str
    provider_order_id: Optional[str]
    provider_transaction_id: Optional[str]
    local_status: str
    payout_status: str
    provider_status: Optional[str] = None
    raw_payload: Optional[str] = None
    message: Optional[str] = None


@dataclass
class ProviderPayoutBalanceResult:
    account_number: str
    account_name: str
    currency: str
    balance: Decimal


class PaymentGatewayError(Exception):
    pass


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


def _base_url() -> str:
    return _env("PAYMENT_PUBLIC_BASE_URL", "http://localhost:8000") or "http://localhost:8000"


def _json_dumps(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def _normalize_provider(provider: str) -> str:
    normalized_provider = provider.lower().strip()
    if normalized_provider != PAYOS_PROVIDER:
        raise PaymentGatewayError(f"Provider khong duoc ho tro: {provider}")
    return normalized_provider


def _is_mock_mode() -> bool:
    global_flag = (_env("PAYMENT_GATEWAY_MODE", "mock") or "mock").lower()
    provider_flag = (_env("PAYOS_MOCK_MODE", "") or "").lower()
    if provider_flag in {"1", "true", "yes", "mock"}:
        return True
    return global_flag == "mock"


def _is_payout_mock_mode() -> bool:
    global_flag = (_env("PAYMENT_GATEWAY_MODE", "mock") or "mock").lower()
    provider_flag = (_env("PAYOS_PAYOUT_MOCK_MODE", "") or "").lower()
    if provider_flag in {"1", "true", "yes", "mock"}:
        return True
    return global_flag == "mock"


def is_payment_mock_mode_enabled() -> bool:
    return _is_mock_mode()


def is_payout_mock_mode_enabled() -> bool:
    return _is_payout_mock_mode()


def create_provider_payment_url(
    *,
    provider: str,
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
    extra_data: dict[str, Any],
) -> ProviderCreateResult:
    _normalize_provider(provider)
    if _is_mock_mode():
        return _create_mock_payment(transaction_ref, amount, order_info, extra_data)
    return _create_payos_payment(transaction_ref, amount, order_info, extra_data)


def verify_provider_callback(provider: str, payload: Any) -> ProviderVerificationResult:
    normalized_provider = provider.lower().strip()
    if normalized_provider == "mock":
        return _verify_mock_callback(payload)
    _normalize_provider(normalized_provider)
    return _verify_payos_callback(payload)


def fetch_provider_payment_status(provider: str, provider_order_id: str) -> ProviderVerificationResult:
    _normalize_provider(provider)
    return _fetch_payos_payment_status(provider_order_id)


def confirm_provider_webhook(provider: str, webhook_url: str) -> ProviderWebhookConfirmationResult:
    _normalize_provider(provider)
    return _confirm_payos_webhook(webhook_url)


def default_provider_webhook_url(provider: str) -> str:
    _normalize_provider(provider)
    return _payos_webhook_url()


def create_provider_payout(
    *,
    provider: str,
    reference_id: str,
    amount: Decimal,
    description: str,
    to_bin: str,
    to_account_number: str,
) -> ProviderPayoutResult:
    _normalize_provider(provider)
    if _is_payout_mock_mode():
        return _create_mock_payout(
            reference_id=reference_id,
            amount=amount,
            description=description,
            to_bin=to_bin,
            to_account_number=to_account_number,
        )
    return _create_payos_payout(
        reference_id=reference_id,
        amount=amount,
        description=description,
        to_bin=to_bin,
        to_account_number=to_account_number,
    )


def fetch_provider_payout_status(provider: str, provider_order_id: str) -> ProviderPayoutResult:
    _normalize_provider(provider)
    if _is_payout_mock_mode():
        return _get_mock_payout_status(provider_order_id)
    return _fetch_payos_payout_status(provider_order_id)


def fetch_provider_payout_balance(provider: str) -> ProviderPayoutBalanceResult:
    _normalize_provider(provider)
    if _is_payout_mock_mode():
        return ProviderPayoutBalanceResult(
            account_number="0000000000",
            account_name="PAYOS MOCK PAYOUT",
            currency="VND",
            balance=Decimal("999999999"),
        )
    return _fetch_payos_payout_balance()


def _create_mock_payment(
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
    extra_data: dict[str, Any],
) -> ProviderCreateResult:
    query = urlencode(
        {
            "provider": PAYOS_PROVIDER,
            "amount": int(amount),
            "orderInfo": order_info,
        }
    )
    redirect_url = f"{_base_url().rstrip('/')}/payments/mock/checkout/{transaction_ref}?{query}"
    return ProviderCreateResult(
        provider=PAYOS_PROVIDER,
        redirect_url=redirect_url,
        provider_order_id=transaction_ref,
        provider_payload=_json_dumps({"mock": True, "extraData": extra_data}),
    )


def _verify_mock_callback(payload: dict[str, Any]) -> ProviderVerificationResult:
    return ProviderVerificationResult(
        transaction_ref=str(payload.get("transaction_ref", "")),
        is_success=str(payload.get("status", "")).lower() == "success",
        provider_transaction_id=str(payload.get("provider_transaction_id", "")) or None,
        raw_payload=_json_dumps(payload),
        message=str(payload.get("message", "")) or None,
        provider_status=str(payload.get("status", "")).upper() or None,
    )


def _load_payos_sdk():
    try:
        from payos import PayOS

        return PayOS
    except ImportError as exc:
        raise PaymentGatewayError(
            "Chua cai dat SDK payos. Hay chay pip install -r server/requirements.txt"
        ) from exc


def _coalesce_env(*names: str) -> Optional[str]:
    for name in names:
        value = _env(name)
        if value:
            return value
    return None


def _require_env_value(*names: str, error_label: str) -> str:
    value = _coalesce_env(*names)
    if value:
        return value
    joined_names = ", ".join(names)
    raise PaymentGatewayError(f"Thieu cau hinh payOS {error_label}: {joined_names}")


def _build_payos_client(
    *,
    client_id_envs: tuple[str, ...],
    api_key_envs: tuple[str, ...],
    checksum_key_envs: tuple[str, ...],
    partner_code_envs: tuple[str, ...] = (),
    base_url_envs: tuple[str, ...] = (),
    timeout_envs: tuple[str, ...] = (),
    max_retries_envs: tuple[str, ...] = (),
    error_label: str,
):
    PayOS = _load_payos_sdk()

    client_kwargs: dict[str, Any] = {}
    client_id = _require_env_value(*client_id_envs, error_label=f"{error_label} client_id")
    api_key = _require_env_value(*api_key_envs, error_label=f"{error_label} api_key")
    checksum_key = _require_env_value(
        *checksum_key_envs,
        error_label=f"{error_label} checksum_key",
    )
    partner_code = _coalesce_env(*partner_code_envs) if partner_code_envs else None
    base_url = _coalesce_env(*base_url_envs) if base_url_envs else None
    timeout = _coalesce_env(*timeout_envs) if timeout_envs else None
    max_retries = _coalesce_env(*max_retries_envs) if max_retries_envs else None

    if partner_code:
        client_kwargs["partner_code"] = partner_code
    if base_url:
        client_kwargs["base_url"] = base_url
    if timeout:
        client_kwargs["timeout"] = float(timeout)
    if max_retries:
        client_kwargs["max_retries"] = int(max_retries)

    try:
        return PayOS(
            client_id=client_id,
            api_key=api_key,
            checksum_key=checksum_key,
            **client_kwargs,
        )
    except Exception as exc:
        raise PaymentGatewayError(f"Khong the khoi tao payOS {error_label}: {exc}") from exc


def _build_payos_payment_client():
    return _build_payos_client(
        client_id_envs=("PAYOS_CLIENT_ID",),
        api_key_envs=("PAYOS_API_KEY",),
        checksum_key_envs=("PAYOS_CHECKSUM_KEY",),
        partner_code_envs=("PAYOS_PARTNER_CODE",),
        base_url_envs=("PAYOS_BASE_URL",),
        timeout_envs=("PAYOS_TIMEOUT",),
        max_retries_envs=("PAYOS_MAX_RETRIES",),
        error_label="payment client",
    )


def _build_payos_payout_client():
    return _build_payos_client(
        client_id_envs=("PAYOS_PAYOUT_CLIENT_ID",),
        api_key_envs=("PAYOS_PAYOUT_API_KEY",),
        checksum_key_envs=("PAYOS_PAYOUT_CHECKSUM_KEY",),
        partner_code_envs=("PAYOS_PAYOUT_PARTNER_CODE", "PAYOS_PARTNER_CODE"),
        base_url_envs=("PAYOS_PAYOUT_BASE_URL", "PAYOS_BASE_URL"),
        timeout_envs=("PAYOS_PAYOUT_TIMEOUT", "PAYOS_TIMEOUT"),
        max_retries_envs=("PAYOS_PAYOUT_MAX_RETRIES", "PAYOS_MAX_RETRIES"),
        error_label="payout client",
    )


def _generate_payos_order_code() -> int:
    epoch_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    random_suffix = int.from_bytes(os.urandom(2), "big") % 1000
    return epoch_ms * 1000 + random_suffix


def _payos_return_url() -> str:
    return f"{_base_url().rstrip('/')}/payments/providers/payos/return"


def _payos_webhook_url() -> str:
    return f"{_base_url().rstrip('/')}/payments/providers/payos/webhook"


def _build_payos_description(order_code: int) -> str:
    return f"EC{str(order_code)[-7:]}"


def _normalize_payos_item_name(order_info: str) -> str:
    normalized = " ".join(order_info.split())
    return normalized[:80] or "EConnect payment"


def _create_payos_payment(
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
    extra_data: dict[str, Any],
) -> ProviderCreateResult:
    try:
        from payos.types import CreatePaymentLinkRequest, ItemData
    except ImportError as exc:
        raise PaymentGatewayError(
            "Chua cai dat SDK payos. Hay chay pip install -r server/requirements.txt"
        ) from exc

    order_code = _generate_payos_order_code()
    expires_at = int((datetime.now(timezone.utc) + timedelta(minutes=15)).timestamp())
    item_name = _normalize_payos_item_name(order_info)
    buyer_name = str(extra_data.get("buyer_name", "")).strip() or None
    buyer_email = str(extra_data.get("buyer_email", "")).strip() or None
    buyer_phone = str(extra_data.get("buyer_phone", "")).strip() or None

    request_body = CreatePaymentLinkRequest(
        order_code=order_code,
        amount=int(amount),
        description=_build_payos_description(order_code),
        cancel_url=_payos_return_url(),
        return_url=_payos_return_url(),
        items=[ItemData(name=item_name, quantity=1, price=int(amount), unit="order")],
        buyer_name=buyer_name,
        buyer_email=buyer_email,
        buyer_phone=buyer_phone,
        expired_at=expires_at,
    )

    try:
        with _build_payos_payment_client() as client:
            response = client.payment_requests.create(payment_data=request_body)
    except Exception as exc:
        raise PaymentGatewayError(f"Khong tao duoc payment link payOS: {exc}") from exc

    payload = response.model_dump_camel_case()
    payload["transactionRef"] = transaction_ref
    payload["webhookUrl"] = _payos_webhook_url()

    return ProviderCreateResult(
        provider=PAYOS_PROVIDER,
        redirect_url=response.checkout_url,
        provider_order_id=str(response.order_code),
        provider_payload=_json_dumps(payload),
    )


def _verify_payos_callback(payload: Any) -> ProviderVerificationResult:
    try:
        with _build_payos_payment_client() as client:
            webhook_data = client.webhooks.verify(payload)
    except Exception as exc:
        raise PaymentGatewayError(f"Khong verify duoc webhook payOS: {exc}") from exc

    provider_transaction_id = webhook_data.reference or webhook_data.payment_link_id or None
    return ProviderVerificationResult(
        transaction_ref=str(webhook_data.order_code),
        is_success=webhook_data.code == "00",
        provider_transaction_id=provider_transaction_id,
        raw_payload=_json_dumps(webhook_data.model_dump_camel_case()),
        message=webhook_data.desc,
        provider_status="PAID" if webhook_data.code == "00" else "FAILED",
    )


def _fetch_payos_payment_status(provider_order_id: str) -> ProviderVerificationResult:
    try:
        order_code = int(str(provider_order_id).strip())
    except ValueError as exc:
        raise PaymentGatewayError("payOS order code khong hop le") from exc

    try:
        with _build_payos_payment_client() as client:
            payment_link = client.payment_requests.get(order_code)
    except Exception as exc:
        raise PaymentGatewayError(f"Khong lay duoc trang thai payOS: {exc}") from exc

    status_messages = {
        "PENDING": "Dang cho nguoi dung thanh toan tren payOS",
        "PROCESSING": "Giao dich dang duoc payOS xu ly",
        "PAID": "payOS da ghi nhan thanh toan thanh cong",
        "CANCELLED": "Nguoi dung da huy giao dich tren payOS",
        "FAILED": "payOS thong bao giao dich that bai",
        "EXPIRED": "Link thanh toan payOS da het han",
        "UNDERPAID": "Khoan chuyen khoan vao payOS chua du so tien",
    }
    provider_transaction_id = payment_link.transactions[-1].reference if payment_link.transactions else payment_link.id

    return ProviderVerificationResult(
        transaction_ref=str(payment_link.order_code),
        is_success=payment_link.status == "PAID",
        provider_transaction_id=provider_transaction_id,
        raw_payload=_json_dumps(payment_link.model_dump_camel_case()),
        message=status_messages.get(payment_link.status, payment_link.status),
        provider_status=payment_link.status,
    )


def _confirm_payos_webhook(webhook_url: str) -> ProviderWebhookConfirmationResult:
    try:
        with _build_payos_payment_client() as client:
            result = client.webhooks.confirm(webhook_url)
    except Exception as exc:
        raise PaymentGatewayError(f"Khong confirm duoc webhook payOS: {exc}") from exc

    return ProviderWebhookConfirmationResult(
        webhook_url=result.webhook_url,
        account_name=result.account_name,
        account_number=result.account_number,
        name=result.name,
        short_name=result.short_name,
    )


def _mock_payout_id(reference_id: str) -> str:
    return f"mock-payout-{reference_id.lower()}"


def _build_mock_payout_payload(
    *,
    payout_id: str,
    reference_id: str,
    amount: Decimal,
    description: str,
    to_bin: str,
    to_account_number: str,
    approval_state: str,
    transaction_state: str,
) -> dict[str, Any]:
    return {
        "id": payout_id,
        "referenceId": reference_id,
        "approvalState": approval_state,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "transactions": [
            {
                "id": f"{payout_id}-tx",
                "referenceId": reference_id,
                "amount": int(amount),
                "description": description,
                "toBin": to_bin,
                "toAccountNumber": to_account_number,
                "toAccountName": None,
                "reference": f"MOCK-{reference_id}",
                "transactionDatetime": datetime.now(timezone.utc).isoformat(),
                "errorMessage": None,
                "errorCode": None,
                "state": transaction_state,
            }
        ],
    }


def _payout_status_message(approval_state: Optional[str], transaction_state: Optional[str]) -> str:
    if approval_state == "COMPLETED" or transaction_state == "SUCCEEDED":
        return "payOS da chuyen tien thanh cong cho tutor"
    if approval_state in {"FAILED", "REJECTED", "CANCELLED"} or transaction_state in {
        "FAILED",
        "CANCELLED",
        "REVERSED",
    }:
        return "payOS khong the hoan tat lenh chi cho tutor"
    return "Lenh chi payOS dang duoc xu ly"


def _map_payos_payout(payout: Any) -> ProviderPayoutResult:
    first_transaction = payout.transactions[0] if getattr(payout, "transactions", None) else None
    approval_state = getattr(payout, "approval_state", None)
    transaction_state = getattr(first_transaction, "state", None)
    provider_status = approval_state or transaction_state
    if approval_state and transaction_state:
        provider_status = f"{approval_state}:{transaction_state}"

    if approval_state == "COMPLETED" or transaction_state == "SUCCEEDED":
        local_status = "released"
        payout_status = "paid"
    elif approval_state in {"FAILED", "REJECTED", "CANCELLED"} or transaction_state in {
        "FAILED",
        "CANCELLED",
        "REVERSED",
    }:
        local_status = "failed"
        payout_status = "failed"
    else:
        local_status = "processing"
        payout_status = "processing"

    return ProviderPayoutResult(
        provider=PAYOS_PROVIDER,
        provider_order_id=str(getattr(payout, "id", "") or "") or None,
        provider_transaction_id=getattr(first_transaction, "reference", None),
        local_status=local_status,
        payout_status=payout_status,
        provider_status=provider_status,
        raw_payload=_json_dumps(payout.model_dump_camel_case()),
        message=getattr(first_transaction, "error_message", None)
        or _payout_status_message(approval_state, transaction_state),
    )


def _create_mock_payout(
    *,
    reference_id: str,
    amount: Decimal,
    description: str,
    to_bin: str,
    to_account_number: str,
) -> ProviderPayoutResult:
    payout_id = _mock_payout_id(reference_id)
    payload = _build_mock_payout_payload(
        payout_id=payout_id,
        reference_id=reference_id,
        amount=amount,
        description=description,
        to_bin=to_bin,
        to_account_number=to_account_number,
        approval_state="COMPLETED",
        transaction_state="SUCCEEDED",
    )
    return ProviderPayoutResult(
        provider=PAYOS_PROVIDER,
        provider_order_id=payout_id,
        provider_transaction_id=f"MOCK-{reference_id}",
        local_status="released",
        payout_status="paid",
        provider_status="COMPLETED:SUCCEEDED",
        raw_payload=_json_dumps(payload),
        message="Mock payout da duoc danh dau thanh cong",
    )


def _get_mock_payout_status(provider_order_id: str) -> ProviderPayoutResult:
    reference_id = provider_order_id.removeprefix("mock-payout-").upper()
    payload = _build_mock_payout_payload(
        payout_id=provider_order_id,
        reference_id=reference_id,
        amount=Decimal("0"),
        description="Mock payout",
        to_bin="970000",
        to_account_number="0000000000",
        approval_state="COMPLETED",
        transaction_state="SUCCEEDED",
    )
    return ProviderPayoutResult(
        provider=PAYOS_PROVIDER,
        provider_order_id=provider_order_id,
        provider_transaction_id=f"MOCK-{reference_id}",
        local_status="released",
        payout_status="paid",
        provider_status="COMPLETED:SUCCEEDED",
        raw_payload=_json_dumps(payload),
        message="Mock payout da duoc danh dau thanh cong",
    )


def _create_payos_payout(
    *,
    reference_id: str,
    amount: Decimal,
    description: str,
    to_bin: str,
    to_account_number: str,
) -> ProviderPayoutResult:
    try:
        from payos.types import PayoutRequest
    except ImportError as exc:
        raise PaymentGatewayError(
            "Chua cai dat SDK payos. Hay chay pip install -r server/requirements.txt"
        ) from exc

    payout_data = PayoutRequest(
        reference_id=reference_id,
        amount=int(amount),
        description=description,
        to_bin=to_bin,
        to_account_number=to_account_number,
    )

    try:
        with _build_payos_payout_client() as client:
            payout = client.payouts.create(
                payout_data=payout_data,
                idempotency_key=reference_id,
            )
    except Exception as exc:
        raise PaymentGatewayError(f"Khong tao duoc payout payOS: {exc}") from exc

    return _map_payos_payout(payout)


def _fetch_payos_payout_status(provider_order_id: str) -> ProviderPayoutResult:
    try:
        with _build_payos_payout_client() as client:
            payout = client.payouts.get(provider_order_id)
    except Exception as exc:
        raise PaymentGatewayError(f"Khong lay duoc trang thai payout payOS: {exc}") from exc

    return _map_payos_payout(payout)


def _fetch_payos_payout_balance() -> ProviderPayoutBalanceResult:
    try:
        with _build_payos_payout_client() as client:
            balance_info = client.payouts_account.balance()
    except Exception as exc:
        raise PaymentGatewayError(f"Khong lay duoc so du payout payOS: {exc}") from exc

    return ProviderPayoutBalanceResult(
        account_number=balance_info.account_number,
        account_name=balance_info.account_name,
        currency=balance_info.currency,
        balance=Decimal(balance_info.balance),
    )
