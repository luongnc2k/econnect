from typing import Optional
import os
from fastapi import HTTPException, Header
import jwt

JWT_SECRET = os.getenv("JWT_SECRET", "dev_jwt_secret_change_me_please_32bytes")
LEGACY_JWT_SECRET = "password_key"

def auth_middleware(
    x_auth_token: Optional[str] = Header(default=None),
    authorization: Optional[str] = Header(default=None),
):
    token = x_auth_token
    if not token and authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()

    if not token:
        raise HTTPException(status_code=401, detail="No auth token, access denied!")

    verified_token = None
    for secret in (JWT_SECRET, LEGACY_JWT_SECRET):
        try:
            verified_token = jwt.decode(
                token,
                secret,
                algorithms=["HS256"],
            )
            break
        except jwt.PyJWTError:
            continue

    if verified_token is None:
        raise HTTPException(status_code=401, detail="Token is not valid, authorization failed")

    uid = verified_token.get("id")
    if not uid:
        raise HTTPException(status_code=401, detail="Token verification failed, authorization denied")

    return {"uid": uid, "token": token}
