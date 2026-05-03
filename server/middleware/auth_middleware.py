import os
from typing import Optional

from fastapi import HTTPException, Header
import jwt

JWT_SECRET = os.getenv("JWT_SECRET", "dev_jwt_secret_change_me_please_32bytes")
LEGACY_JWT_SECRET = "password_key"


def _env_flag(name: str, default: bool = False) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default
    return raw_value.strip().lower() in {"1", "true", "yes", "on"}


def _extract_token(
    x_auth_token: Optional[str] = None,
    authorization: Optional[str] = None,
) -> Optional[str]:
    token = x_auth_token
    if not token and authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
    return token or None


def _candidate_secrets() -> list[str]:
    secrets = [JWT_SECRET]
    if _env_flag("ALLOW_LEGACY_JWT_SECRET", False):
        secrets.append(LEGACY_JWT_SECRET)
    return secrets


def _decode_token_payload(token: str) -> dict:
    expired_error = False
    for secret in _candidate_secrets():
        try:
            return jwt.decode(token, secret, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            expired_error = True
        except jwt.PyJWTError:
            continue

    if expired_error:
        raise HTTPException(status_code=401, detail="Token da het han, vui long dang nhap lai")
    raise HTTPException(status_code=401, detail="Token is not valid, authorization failed")


def _build_auth_context(token: str) -> dict:
    verified_token = _decode_token_payload(token)
    uid = verified_token.get("id")
    if not uid:
        raise HTTPException(status_code=401, detail="Token verification failed, authorization denied")
    return {"uid": uid, "token": token, "claims": verified_token}


def auth_middleware(
    x_auth_token: Optional[str] = Header(default=None),
    authorization: Optional[str] = Header(default=None),
):
    token = _extract_token(x_auth_token=x_auth_token, authorization=authorization)
    if not token:
        raise HTTPException(status_code=401, detail="No auth token, access denied!")

    return _build_auth_context(token)


def build_auth_context_from_token(token: str) -> dict:
    return _build_auth_context(token)


def optional_auth_middleware(
    x_auth_token: Optional[str] = Header(default=None),
    authorization: Optional[str] = Header(default=None),
):
    token = _extract_token(x_auth_token=x_auth_token, authorization=authorization)
    if not token:
        return None
    return _build_auth_context(token)
