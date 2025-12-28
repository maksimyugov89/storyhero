from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from typing import Optional
from ..db import get_db
from ..models.user import User
from .security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login", auto_error=False)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """
    Получает текущего пользователя из JWT токена.
    Получает текущего пользователя из JWT токена.
    Возвращает dict для совместимости со старым кодом.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Не удалось подтвердить учетные данные",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # Явно проверяем, что токен пришёл
    if not token:
        raise credentials_exception

    # Декодируем токен
    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception
    
    # Извлекаем user_id из токена
    user_id: Optional[str] = payload.get("sub")
    if user_id is None:
        raise credentials_exception
    
    # Получаем пользователя из БД
    try:
        from uuid import UUID
        user_uuid = UUID(user_id)
        user = db.query(User).filter(User.id == user_uuid).first()
    except (ValueError, TypeError):
        raise credentials_exception
    
    if user is None:
        raise credentials_exception
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Пользователь неактивен"
        )
    
    # Возвращаем dict для совместимости со старым кодом
    return {
        "id": str(user.id),
        "sub": str(user.id),  # Для совместимости
        "email": user.email
    }


def get_current_user_id(
    current_user: dict = Depends(get_current_user)
) -> str:
    """Возвращает ID текущего пользователя как строку"""
    return current_user.get("sub") or current_user.get("id")

