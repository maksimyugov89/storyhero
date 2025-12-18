"""
Роутер для работы с оплатой книг
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from uuid import UUID
import logging

from ..db import get_db
from ..models import Book
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/payments", tags=["payments"])


# ==================== Pydantic Models ====================

class PaymentCreateRequest(BaseModel):
    book_id: str


class PaymentCreateResponse(BaseModel):
    payment_url: Optional[str] = None  # None для демо-режима
    payment_id: str


class PaymentConfirmRequest(BaseModel):
    book_id: str


class PaymentConfirmResponse(BaseModel):
    status: str
    is_paid: bool


class PaymentStatusResponse(BaseModel):
    is_paid: bool
    pdf_url: Optional[str] = None


# ==================== Endpoints ====================

@router.post("/create", response_model=PaymentCreateResponse)
async def create_payment(
    data: PaymentCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создание платежа для книги.
    В демо-режиме возвращает payment_url=None.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(data.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    # Проверяем существование книги и принадлежность пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Проверяем, не оплачена ли уже
    if book.is_paid:
        raise HTTPException(status_code=400, detail="Книга уже оплачена")
    
    # В демо-режиме возвращаем payment_url=None
    # В продакшене здесь будет интеграция с платёжной системой (ЮKassa, Stripe и т.д.)
    logger.info(f"[Payments] Создание платежа для книги {book_uuid}, пользователь {user_id}")
    
    # Генерируем payment_id (в продакшене это будет ID от платёжной системы)
    import uuid
    payment_id = str(uuid.uuid4())
    
    return PaymentCreateResponse(
        payment_url=None,  # В демо-режиме нет URL
        payment_id=payment_id
    )


@router.post("/confirm", response_model=PaymentConfirmResponse)
async def confirm_payment(
    data: PaymentConfirmRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Подтверждение оплаты (webhook от платёжной системы или демо-режим).
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(data.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    # Находим книгу
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Проверяем, не оплачена ли уже
    if book.is_paid:
        logger.info(f"[Payments] Книга {book_uuid} уже оплачена")
        return PaymentConfirmResponse(status="success", is_paid=True)
    
    # Устанавливаем статус оплаты
    book.is_paid = True
    db.commit()
    
    logger.info(f"[Payments] ✓ Оплата подтверждена для книги {book_uuid}, пользователь {user_id}")
    
    return PaymentConfirmResponse(status="success", is_paid=True)


@router.get("/status/{book_id}", response_model=PaymentStatusResponse)
async def get_payment_status(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Проверка статуса оплаты книги.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Находим книгу
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Возвращаем статус и PDF URL (если оплачена и есть PDF)
    pdf_url = book.final_pdf_url if book.is_paid else None
    
    return PaymentStatusResponse(
        is_paid=book.is_paid or False,
        pdf_url=pdf_url
    )

