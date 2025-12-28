#!/usr/bin/env python3
"""
Скрипт для генерации финальных изображений для последней книги.
"""
import sys
import asyncio

sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Child
from app.routers.final_images import _generate_final_images_internal
from app.routers.children import _get_child_photos_urls
from sqlalchemy import desc
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def generate_final_images():
    """Генерирует финальные изображения для последней книги."""
    db = SessionLocal()
    
    try:
        # Получаем последнюю книгу
        book = db.query(Book).order_by(desc(Book.created_at)).first()
        
        if not book:
            logger.error("❌ Книги не найдены в БД")
            return 1
        
        logger.info(f"📚 Книга: {book.title}")
        logger.info(f"   ID: {book.id}")
        logger.info(f"   Статус: {book.status}")
        
        # Получаем данные ребенка
        child = db.query(Child).filter(Child.id == book.child_id).first()
        if not child:
            logger.error(f"❌ Ребенок с id={book.child_id} не найден")
            return 1
        
        logger.info(f"👶 Ребенок: {child.name}, возраст: {child.age} лет")
        
        # Получаем фотографии ребенка
        child_photos = []
        try:
            child_photos = _get_child_photos_urls(child.id)
            logger.info(f"📸 Получено {len(child_photos)} фотографий")
        except Exception as e:
            logger.warning(f"⚠️ Ошибка получения фото: {e}")
            child_photos = []
        
        # Получаем стиль книги
        from app.models import ThemeStyle
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book.id).first()
        final_style = theme_style.final_style if theme_style else "pixar"
        
        logger.info(f"🎨 Стиль: {final_style}")
        logger.info("=" * 70)
        logger.info("🎨 Начало генерации финальных изображений...")
        logger.info("=" * 70)
        
        # Генерируем финальные изображения
        try:
            result = await _generate_final_images_internal(
                book_id=str(book.id),
                db=db,
                current_user_id=child.user_id or "test_user",
                final_style=final_style,
                face_url=child.face_url or "",
                task_id=None,
                child_photos=child_photos
            )
            
            logger.info("=" * 70)
            logger.info("✅ ГЕНЕРАЦИЯ ФИНАЛЬНЫХ ИЗОБРАЖЕНИЙ ЗАВЕРШЕНА!")
            logger.info("=" * 70)
            logger.info(f"📊 Сгенерировано изображений: {len(result.get('images', []))}")
            
            return 0
            
        except Exception as e:
            logger.error(f"❌ Ошибка при генерации финальных изображений: {e}", exc_info=True)
            return 1
            
    finally:
        db.close()


if __name__ == "__main__":
    try:
        exit_code = asyncio.run(generate_final_images())
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("\n⚠️ Генерация прервана пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)

