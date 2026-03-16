import hashlib
import hmac
import json
import os
from base64 import b64encode
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Any, Optional
from urllib.parse import urlencode
from urllib.request import Request, urlopen


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


class PaymentGatewayError(Exception):
    pass


def _env(name: str, default: Optional[str] = None) -> Optional[str]:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


def _hmac_sha256(secret: str, raw: str) -> str:
    return hmac.new(secret.encode("utf-8"), raw.encode("utf-8"), hashlib.sha256).hexdigest()


def _base_url() -> str:
    return _env("PAYMENT_PUBLIC_BASE_URL", "http://localhost:8000") or "http://localhost:8000"


def _json_dumps(value: Any) -> str:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def _is_mock_mode(provider: str) -> bool:
    global_flag = (_env("PAYMENT_GATEWAY_MODE", "mock") or "mock").lower()
    provider_flag = (_env(f"{provider.upper()}_MOCK_MODE", "") or "").lower()
    if provider_flag in {"1", "true", "yes", "mock"}:
        return True
    return global_flag == "mock"


def create_provider_payment_url(
    *,
    provider: str,
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
    extra_data: dict[str, Any],
) -> ProviderCreateResult:
    normalized_provider = provider.lower()
    if _is_mock_mode(normalized_provider):
        return _create_mock_payment(normalized_provider, transaction_ref, amount, order_info, extra_data)
    if normalized_provider == "momo":
        return _create_momo_payment(transaction_ref, amount, order_info, extra_data)
    if normalized_provider == "vnpay":
        return _create_vnpay_payment(transaction_ref, amount, order_info)
    raise PaymentGatewayError(f"Provider khong duoc ho tro: {provider}")


def verify_provider_callback(provider: str, payload: dict[str, Any]) -> ProviderVerificationResult:
    normalized_provider = provider.lower()
    if normalized_provider == "mock":
        return _verify_mock_callback(payload)
    if normalized_provider == "momo":
        return _verify_momo_callback(payload)
    if normalized_provider == "vnpay":
        return _verify_vnpay_callback(payload)
    raise PaymentGatewayError(f"Provider khong duoc ho tro: {provider}")


def _create_mock_payment(
    provider: str,
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
    extra_data: dict[str, Any],
) -> ProviderCreateResult:
    query = urlencode({
        "provider": provider,
        "amount": int(amount),
        "orderInfo": order_info,
    })
    redirect_url = f"{_base_url().rstrip('/')}/payments/mock/checkout/{transaction_ref}?{query}"
    return ProviderCreateResult(
        provider=provider,
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
    )


def _create_momo_payment(
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
    extra_data: dict[str, Any],
) -> ProviderCreateResult:
    partner_code = _env("MOMO_PARTNER_CODE")
    access_key = _env("MOMO_ACCESS_KEY")
    secret_key = _env("MOMO_SECRET_KEY")
    endpoint = _env("MOMO_API_URL", "https://test-payment.momo.vn/v2/gateway/api/create")
    redirect_base = f"{_base_url().rstrip('/')}/payments/providers/momo/return"
    ipn_url = f"{_base_url().rstrip('/')}/payments/providers/momo/ipn"

    if not all([partner_code, access_key, secret_key]):
        raise PaymentGatewayError("Thieu cau hinh MoMo: MOMO_PARTNER_CODE, MOMO_ACCESS_KEY, MOMO_SECRET_KEY")

    request_id = transaction_ref
    extra_data_b64 = b64encode(_json_dumps(extra_data).encode("utf-8")).decode("utf-8")
    raw_signature = (
        f"accessKey={access_key}&amount={int(amount)}&extraData={extra_data_b64}"
        f"&ipnUrl={ipn_url}&orderId={transaction_ref}&orderInfo={order_info}"
        f"&partnerCode={partner_code}&redirectUrl={redirect_base}"
        f"&requestId={request_id}&requestType=captureWallet"
    )
    signature = _hmac_sha256(secret_key, raw_signature)
    payload = {
        "partnerCode": partner_code,
        "partnerName": _env("MOMO_PARTNER_NAME", "EConnect"),
        "storeId": _env("MOMO_STORE_ID", "EConnectStore"),
        "requestId": request_id,
        "amount": int(amount),
        "orderId": transaction_ref,
        "orderInfo": order_info,
        "redirectUrl": redirect_base,
        "ipnUrl": ipn_url,
        "lang": "vi",
        "requestType": "captureWallet",
        "autoCapture": True,
        "extraData": extra_data_b64,
        "signature": signature,
    }

    req = Request(
        endpoint,
        data=_json_dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(req, timeout=30) as resp:
            response_data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        raise PaymentGatewayError(f"Khong tao duoc payment URL MoMo: {exc}") from exc

    if int(response_data.get("resultCode", -1)) != 0 or not response_data.get("payUrl"):
        raise PaymentGatewayError(response_data.get("message") or "MoMo khong tra ve payUrl hop le")

    return ProviderCreateResult(
        provider="momo",
        redirect_url=response_data["payUrl"],
        provider_order_id=str(response_data.get("orderId") or transaction_ref),
        provider_payload=_json_dumps(response_data),
    )


def _verify_momo_callback(payload: dict[str, Any]) -> ProviderVerificationResult:
    secret_key = _env("MOMO_SECRET_KEY")
    access_key = _env("MOMO_ACCESS_KEY")
    partner_code = _env("MOMO_PARTNER_CODE")
    if not all([secret_key, access_key, partner_code]):
        raise PaymentGatewayError("Thieu cau hinh MoMo de verify callback")

    fields = {
        "accessKey": access_key,
        "amount": str(payload.get("amount", "")),
        "extraData": str(payload.get("extraData", "")),
        "message": str(payload.get("message", "")),
        "orderId": str(payload.get("orderId", "")),
        "orderInfo": str(payload.get("orderInfo", "")),
        "orderType": str(payload.get("orderType", "")),
        "partnerCode": partner_code,
        "payType": str(payload.get("payType", "")),
        "requestId": str(payload.get("requestId", "")),
        "responseTime": str(payload.get("responseTime", "")),
        "resultCode": str(payload.get("resultCode", "")),
        "transId": str(payload.get("transId", "")),
    }
    signature_order = [
        "accessKey",
        "amount",
        "extraData",
        "message",
        "orderId",
        "orderInfo",
        "orderType",
        "partnerCode",
        "payType",
        "requestId",
        "responseTime",
        "resultCode",
        "transId",
    ]
    raw_signature = "&".join(f"{key}={fields[key]}" for key in signature_order)
    expected_signature = _hmac_sha256(secret_key, raw_signature)
    actual_signature = str(payload.get("signature", ""))
    if expected_signature != actual_signature:
        raise PaymentGatewayError("Chu ky callback MoMo khong hop le")

    result_code = int(payload.get("resultCode", -1))
    return ProviderVerificationResult(
        transaction_ref=str(payload.get("orderId", "")),
        is_success=result_code == 0,
        provider_transaction_id=str(payload.get("transId", "")) or None,
        raw_payload=_json_dumps(payload),
        message=str(payload.get("message", "")) or None,
    )


def _create_vnpay_payment(
    transaction_ref: str,
    amount: Decimal,
    order_info: str,
) -> ProviderCreateResult:
    tmn_code = _env("VNPAY_TMN_CODE")
    hash_secret = _env("VNPAY_HASH_SECRET")
    endpoint = _env("VNPAY_PAYMENT_URL", "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html")
    return_url = f"{_base_url().rstrip('/')}/payments/providers/vnpay/return"

    if not all([tmn_code, hash_secret]):
        raise PaymentGatewayError("Thieu cau hinh VNPAY: VNPAY_TMN_CODE, VNPAY_HASH_SECRET")

    params = {
        "vnp_Version": _env("VNPAY_VERSION", "2.1.0"),
        "vnp_Command": "pay",
        "vnp_TmnCode": tmn_code,
        "vnp_Amount": str(int(amount) * 100),
        "vnp_CurrCode": "VND",
        "vnp_TxnRef": transaction_ref,
        "vnp_OrderInfo": order_info,
        "vnp_OrderType": _env("VNPAY_ORDER_TYPE", "other"),
        "vnp_Locale": "vn",
        "vnp_ReturnUrl": return_url,
        "vnp_IpAddr": _env("VNPAY_IP_ADDR", "127.0.0.1"),
        "vnp_CreateDate": datetime.utcnow().strftime("%Y%m%d%H%M%S"),
    }
    params = {key: value for key, value in params.items() if value}
    sorted_params = dict(sorted(params.items()))
    query_string = urlencode(sorted_params)
    secure_hash = hmac.new(hash_secret.encode("utf-8"), query_string.encode("utf-8"), hashlib.sha512).hexdigest()
    redirect_url = f"{endpoint}?{query_string}&vnp_SecureHash={secure_hash}"

    return ProviderCreateResult(
        provider="vnpay",
        redirect_url=redirect_url,
        provider_order_id=transaction_ref,
        provider_payload=_json_dumps(sorted_params),
    )


def _verify_vnpay_callback(payload: dict[str, Any]) -> ProviderVerificationResult:
    hash_secret = _env("VNPAY_HASH_SECRET")
    if not hash_secret:
        raise PaymentGatewayError("Thieu cau hinh VNPAY_HASH_SECRET de verify callback")

    input_data = {
        key: str(value)
        for key, value in payload.items()
        if key.startswith("vnp_") and key not in {"vnp_SecureHash", "vnp_SecureHashType"}
    }
    sorted_params = dict(sorted(input_data.items()))
    query_string = urlencode(sorted_params)
    expected_hash = hmac.new(hash_secret.encode("utf-8"), query_string.encode("utf-8"), hashlib.sha512).hexdigest()
    actual_hash = str(payload.get("vnp_SecureHash", ""))
    if expected_hash.lower() != actual_hash.lower():
        raise PaymentGatewayError("Chu ky callback VNPAY khong hop le")

    response_code = str(payload.get("vnp_ResponseCode", ""))
    return ProviderVerificationResult(
        transaction_ref=str(payload.get("vnp_TxnRef", "")),
        is_success=response_code == "00",
        provider_transaction_id=str(payload.get("vnp_TransactionNo", "")) or None,
        raw_payload=_json_dumps(payload),
        message=str(payload.get("vnp_OrderInfo", "")) or None,
    )
