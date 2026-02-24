from typing import Optional
from fastapi import HTTPException, Header
import jwt

def auth_middleware(x_auth_token: Optional[str] = Header(default=None)):
    if not x_auth_token:
        raise HTTPException(status_code=401, detail="No auth token, access denied!")

    try:
        verified_token = jwt.decode(
            x_auth_token,
            "password_key",
            algorithms=["HS256"],
        )
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Token is not valid, authorization failed")

    uid = verified_token.get("id")
    if not uid:
        raise HTTPException(status_code=401, detail="Token verification failed, authorization denied")

    return {"uid": uid, "token": x_auth_token}