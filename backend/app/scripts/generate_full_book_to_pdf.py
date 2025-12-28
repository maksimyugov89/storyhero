#!/usr/bin/env python3
"""
Скрипт для запуска полного цикла генерации книги до готового PDF файла.
Работает напрямую с БД и сервисами, без HTTP API.
"""
import asyncio
import logging
import sys
import os

# Добавляем путь к app (как в других скриптах)
sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Child, Book
from app.routers.books import generate_full_book_task
from app.services.storage import get_server_base_url

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def main():
    """Главная функция."""
    logger.info("🚀 Запуск полного цикла генерации книги до PDF...")
    logger.info("=" * 60)
    
    db = SessionLocal()
    
    try:
        # 1. Получаем первого ребёнка
        child = db.query(Child).first()
        
        if not child:
            logger.error("❌ Нет доступных детей в БД. Создайте профиль ребёнка сначала.")
            return
        
        logger.info(f"👶 Используется ребёнок: {child.name} (ID: {child.id}, возраст: {child.age} лет)")
        
        # 2. Получаем фотографии ребёнка
        from app.routers.children import _get_child_photos_urls
        try:
            child_photos = _get_child_photos_urls(child.id)
            logger.info(f"📸 Получено {len(child_photos)} фотографий ребёнка")
        except Exception as e:
            logger.warning(f"⚠️ Не удалось получить фотографии: {e}")
            child_photos = []
        
        # 3. Параметры генерации
        style = "pixar"
        num_pages = 10  # 10 страниц + обложка
        theme = "приключения в волшебном лесу с друзьями"
        user_id = child.user_id or "test_user"
        
        logger.info(f"📚 Параметры генерации:")
        logger.info(f"   Стиль: {style}")
        logger.info(f"   Страниц: {num_pages}")
        logger.info(f"   Тема: {theme}")
        
        # 4. Запускаем генерацию книги
        logger.info("=" * 60)
        logger.info("🎨 Начало генерации книги...")
        logger.info("=" * 60)
        
        try:
            await generate_full_book_task(
                name=child.name,
                age=child.age,
                interests=child.interests or [],
                fears=child.fears or [],
                personality=child.personality or "",
                moral=child.moral or "",
                face_url=child.face_url or "",
                style=style,
                user_id=user_id,
                db=db,
                child_id=child.id,
                task_id=None,
                num_pages=num_pages,
                child_photos=child_photos,
                theme=theme
            )
            
            # 5. Получаем созданную книгу
            book = db.query(Book).filter(Book.child_id == child.id).order_by(Book.created_at.desc()).first()
            
            if book:
                logger.info("=" * 60)
                logger.info("✅ ГЕНЕРАЦИЯ ЗАВЕРШЕНА!")
                logger.info("=" * 60)
                logger.info(f"📚 Книга: {book.title}")
                logger.info(f"   ID: {book.id}")
                logger.info(f"   Статус: {book.status}")
                
                if book.final_pdf_url:
                    base_url = get_server_base_url()
                    pdf_url = book.final_pdf_url
                    if not pdf_url.startswith("http"):
                        pdf_url = f"{base_url}{pdf_url}" if pdf_url.startswith("/") else f"{base_url}/{pdf_url}"
                    
                    logger.info(f"📄 PDF файл готов!")
                    logger.info(f"   URL: {pdf_url}")
                    
                    # Локальный путь
                    if "/static/" in pdf_url or "/uploads/" in pdf_url:
                        relative_path = pdf_url.split("/static/", 1)[-1] if "/static/" in pdf_url else pdf_url.split("/uploads/", 1)[-1]
                        from app.services.storage import BASE_UPLOAD_DIR
                        local_path = f"{BASE_UPLOAD_DIR}/{relative_path}"
                        logger.info(f"   Локальный путь: {local_path}")
                else:
                    logger.warning("⚠️ PDF URL не найден. Возможно, PDF ещё генерируется.")
            else:
                logger.error("❌ Книга не найдена после генерации")
                
        except Exception as e:
            logger.error(f"❌ Ошибка при генерации книги: {e}", exc_info=True)
            raise
            
    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(main())
