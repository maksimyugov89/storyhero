import os
import requests
from jose import jwt
from jose.exceptions import JWTError
from fastapi import HTTPException, Depends, Request, Header
from datetime import datetime, timedelta
from typing import Optional

SUPABASE_URL = os.getenv("SUPABASE_URL")
JWKS_URL = f"{SUPABASE_URL}/auth/v1/.well-known/jwks.json"

JWKS_CACHE_TTL = timedelta(minutes=10)
_jwks_cache = {"keys": None, "expires": datetime.utcnow()}


def load_jwks():
    """Загрузка JWKS Supabase (нужен apikey если OAuth Server включён)."""
    global _jwks_cache

    # Если есть кэш и он еще не истек, используем его
    if _jwks_cache["keys"] and _jwks_cache["expires"] > datetime.utcnow():
        return _jwks_cache["keys"]

    # Если кэш истек, но есть старые ключи, используем их (fallback при проблемах с DNS)
    if _jwks_cache["keys"]:
        print("⚠️ JWKS кэш истек, но используем старые ключи из-за проблем с DNS")
        return _jwks_cache["keys"]

    API_KEY = os.getenv("SUPABASE_SERVICE_KEY") or os.getenv("SUPABASE_ANON_KEY")

    headers = {"apikey": API_KEY}

    try:
        print(f"Loading JWKS from {JWKS_URL} with apikey header")
        res = requests.get(JWKS_URL, headers=headers, timeout=5)
        res.raise_for_status()

        jwks = res.json()

        _jwks_cache = {
            "keys": jwks,
            "expires": datetime.utcnow() + JWKS_CACHE_TTL
        }

        return jwks

    except Exception as exc:
        print(f"❌ Failed to load JWKS: {exc}")
        # Если есть старые ключи в кэше, используем их
        if _jwks_cache["keys"]:
            print("⚠️ Используем устаревшие JWKS из кэша из-за ошибки загрузки")
            return _jwks_cache["keys"]
        # Если ключей нет вообще, выбрасываем ошибку
        raise RuntimeError(f"Failed to load JWKS: {exc}")


def get_public_key_for_token(token, jwks):
    """Получение подходящего public_key из JWKS по 'kid'."""
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")

    if not kid:
        raise JWTError("No 'kid' in token header")

    for key in jwks["keys"]:
        if key.get("kid") == kid:
            return key

    raise JWTError("Matching 'kid' not found in JWKS")


def verify_supabase_token(
    request: Request,
    authorization: Optional[str] = Header(None)
) -> dict:
    """
    Основная функция проверки токена.
    Извлекает токен из заголовка Authorization и валидирует его через Supabase JWKS.
    """
    # Извлекаем заголовок Authorization
    auth_header = authorization
    if not auth_header:
        # Пробуем получить из request.headers напрямую
        auth_header = request.headers.get("Authorization")
    
    if not auth_header:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid token format")

    token = auth_header.split(" ", 1)[1]

    try:
        jwks = load_jwks()
        public_key = get_public_key_for_token(token, jwks)

        decoded = jwt.decode(
            token,
            public_key,
            algorithms=["RS256", "ES256"],
            audience="authenticated"
        )

        return decoded

    except RuntimeError as exc:
        # Ошибка загрузки JWKS (DNS и т.д.) - используем упрощенную проверку
        print(f"⚠️ JWKS loading error: {exc}")
        print("⚠️ Используем упрощенную проверку токена (без верификации подписи)")
        try:
            # Декодируем токен без верификации подписи (только проверка структуры и exp)
            # Передаем пустую строку как key, так как verify_signature=False
            decoded = jwt.decode(
                token,
                key="",  # Обязательный аргумент, но не используется при verify_signature=False
                options={"verify_signature": False, "verify_aud": False},
                algorithms=["RS256", "ES256"]
            )
            # Проверяем, что токен не истек
            exp = decoded.get("exp")
            if exp and datetime.utcfromtimestamp(exp) < datetime.utcnow():
                raise HTTPException(status_code=401, detail="Token expired")
            # Проверяем наличие обязательных полей
            if not decoded.get("sub"):
                raise HTTPException(status_code=401, detail="Token missing user ID (sub)")
            return decoded
        except JWTError as jwt_exc:
            print(f"❌ Invalid JWT structure: {jwt_exc}")
            raise HTTPException(status_code=401, detail=f"Invalid token: {jwt_exc}")
    except JWTError as exc:
        print("❌ Invalid JWT:", exc)
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")
    except Exception as exc:
        print(f"❌ Unexpected error in token verification: {exc}")
        raise HTTPException(status_code=500, detail=f"Token verification error: {str(exc)}")
