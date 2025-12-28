#!/usr/bin/env python3
"""
Прямой запуск генерации финальных изображений для книги.
"""

import sys
import asyncio
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.db import SessionLocal
from app.models import Book, Child
from app.routers.final_images import _generate_final_images_internal
from app.routers.children import _get_child_photos_urls
from uuid import UUID
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

BOOK_ID = "8734aaf6-c0c7-4fb5-bc17-6ec68a0b9a76"

async def main():
    db = SessionLocal()
    try:
        book_uuid = UUID(BOOK_ID)
        book = db.query(Book).filter(Book.id == book_uuid).first()
        if not book:
            logger.error(f"❌ Книга {BOOK_ID} не найдена")
            return 1
        
        child = db.query(Child).filter(Child.id == book.child_id).first()
        if not child:
            logger.error(f"❌ Ребенок не найден")
            return 1
        
        logger.info(f"📚 Книга: {book.title}")
        logger.info(f"👤 Ребенок: {child.name}")
        
        # Получаем фотографии
        child_photos = _get_child_photos_urls(child.id)
        logger.info(f"📸 Получено {len(child_photos)} фотографий")
        
        # Запускаем генерацию финальных изображений
        logger.info("🎨 Запуск генерации финальных изображений...")
        result = await _generate_final_images_internal(
            book_id=BOOK_ID,
            db=db,
            current_user_id=str(book.user_id),
            final_style="watercolor",
            face_url=child.face_url or "",
            task_id=None,
            child_photos=child_photos
        )
        
        logger.info(f"✅ Генерация завершена: {len(result.get('images', []))} изображений")
        return 0
        
    except Exception as e:
        logger.error(f"❌ Ошибка: {e}", exc_info=True)
        return 1
    finally:
        db.close()

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

