"""
Стили книги (free/premium) и утилиты для проверки доступа.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy.orm import Session

from ..models import Subscription


# 5 бесплатных стилей
FREE_STYLES = [
    "classic",     # Классический
    "cartoon",     # Мультяшный
    "fairytale",   # Сказочный
    "watercolor",  # Акварельный
    "pencil",      # Карандашный
]

# 20 премиум стилей
PREMIUM_STYLES = [
    "disney",
    "pixar",
    "ghibli",
    "dreamworks",
    "oil_painting",
    "impressionism",
    "pastel",
    "gouache",
    "digital_art",
    "fantasy",
    "adventure",
    "space",
    "underwater",
    "forest",
    "winter",
    "cute",
    "funny",
    "educational",
    "retro",
    "pop_art",
]

ALL_STYLES = FREE_STYLES + PREMIUM_STYLES

# Алиасы для обратной совместимости со старым клиентом/кодом
STYLE_ALIASES = {
    "storybook": "classic",
}


def normalize_style(style: Optional[str]) -> str:
    """
    Приводит стиль к каноническому значению с учётом алиасов.
    """
    s = (style or "").strip()
    if not s:
        return "classic"
    s = s.lower()
    return STYLE_ALIASES.get(s, s)


def is_style_known(style: str) -> bool:
    """
    Проверяет, что стиль входит в список доступных (после normalize_style).
    """
    return style in ALL_STYLES


def is_premium_style(style: str) -> bool:
    return style in PREMIUM_STYLES


def get_active_subscription(
    db: Session,
    user_id: str,
) -> Optional[Subscription]:
    """
    Возвращает активную подписку пользователя, если она есть и не истекла.
    """
    now = datetime.now(timezone.utc)
    return db.query(Subscription).filter(
        Subscription.user_id == user_id,
        Subscription.is_active.is_(True),
        Subscription.expires_at.isnot(None),
        Subscription.expires_at > now,
    ).first()


def deactivate_if_expired(db: Session, user_id: str) -> int:
    """
    Деактивирует подписку пользователя, если она истекла, но осталась is_active=True.
    Возвращает количество деактивированных записей (0/1).
    """
    now = datetime.now(timezone.utc)
    expired = db.query(Subscription).filter(
        Subscription.user_id == user_id,
        Subscription.is_active.is_(True),
        Subscription.expires_at.isnot(None),
        Subscription.expires_at <= now,
    ).all()
    if not expired:
        return 0
    for s in expired:
        s.is_active = False
    db.commit()
    return len(expired)


def check_style_access(db: Session, user_id: str, style: str) -> bool:
    """
    True если стиль бесплатный или у пользователя есть активная подписка.
    """
    if style in FREE_STYLES:
        return True
    return get_active_subscription(db, user_id) is not None


