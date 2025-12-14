import os
import json
import requests
from functools import lru_cache
from typing import Dict, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

import jwt
from jwt import PyJWKClient, InvalidTokenError

SUPABASE_URL = os.getenv("SUPABASE_URL")
if not SUPABASE_URL:
    raise RuntimeError("SUPABASE_URL is not set")

JWKS_URL = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"

# Проверяем оба варианта имени переменной для совместимости
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")

# JWKS требует apikey → используем service role или anon key
API_KEY_FOR_JWKS = SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY
if not API_KEY_FOR_JWKS:
    raise RuntimeError("No Supabase API key found (service role or anon)")

bearer = HTTPBearer(auto_error=False)


@lru_cache()
def get_jwks_client() -> PyJWKClient:
    return PyJWKClient(JWKS_URL, headers={"apikey": API_KEY_FOR_JWKS})


async def verify_supabase_token(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> Dict[str, Any]:

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization token missing",
        )

    token = credentials.credentials
    jwks_client = get_jwks_client()

    try:
        signing_key = jwks_client.get_signing_key_from_jwt(token).key
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load JWKS: {exc}",
        )

    try:
        payload = jwt.decode(
            token,
            signing_key,
            algorithms=["ES256"],
            audience="authenticated",
            options={"verify_aud": True},
        )
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid JWT: {exc}",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing user ID (sub)",
        )

    return {
        "id": user_id,
        "email": payload.get("email"),
        "user_metadata": payload.get("user_metadata") or {},
        "app_metadata": payload.get("app_metadata") or {},
    }
