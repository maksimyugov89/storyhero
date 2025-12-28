#!/usr/bin/env python3
"""
Скрипт для запуска полной генерации книги до создания PDF.
Использует прямые вызовы функций без API.
"""

import sys
import asyncio
from pathlib import Path

# Добавляем корень проекта в путь
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from sqlalchemy.orm import Session
from app.db import SessionLocal
from app.models import Child, Book
from app.routers.books import generate_full_book_task
from app.routers.children import _get_child_photos_urls
import logging

# Настройка логирования
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def main():
    """Главная функция для запуска генерации книги."""
    db: Session = SessionLocal()
    
    try:
        # Получаем первого ребенка из базы данных
        child = db.query(Child).first()
        
        if not child:
            logger.error("❌ В базе данных нет детей. Создайте ребенка сначала.")
            return 1
        
        logger.info(f"📖 Найден ребенок: {child.name}, возраст: {child.age}, ID: {child.id}")
        logger.info(f"📖 Интересы: {child.interests}")
        logger.info(f"📖 Характер: {child.personality}")
        
        # Получаем фотографии ребенка
        child_photos = []
        try:
            child_photos = _get_child_photos_urls(child.id)
            logger.info(f"📸 Получено {len(child_photos)} фотографий ребенка")
        except Exception as e:
            logger.warning(f"⚠️ Не удалось получить фотографии: {str(e)}")
        
        # Параметры для генерации книги
        user_id = child.user_id
        face_url = child.face_url or ""
        style = "fairytale"  # Можно изменить на другой стиль
        num_pages = 10  # Можно изменить на 20
        theme = "Приключение в волшебном лесу"  # Тема книги
        
        logger.info("=" * 80)
        logger.info("🚀 ЗАПУСК ГЕНЕРАЦИИ КНИГИ")
        logger.info("=" * 80)
        logger.info(f"Ребенок: {child.name} (ID: {child.id})")
        logger.info(f"Стиль: {style}")
        logger.info(f"Количество страниц: {num_pages}")
        logger.info(f"Тема: {theme}")
        logger.info(f"Фотографий для face swap: {len(child_photos)}")
        logger.info("=" * 80)
        
        # Запускаем генерацию книги
        result = await generate_full_book_task(
            name=child.name,
            age=child.age,
            interests=child.interests or [],
            fears=child.fears or [],
            personality=child.personality or "",
            moral=child.moral or "",
            face_url=face_url,
            style=style,
            user_id=user_id,
            db=db,
            child_id=child.id,
            task_id=None,  # Без отслеживания через задачи
            num_pages=num_pages,
            child_photos=child_photos,
            theme=theme
        )
        
        logger.info("=" * 80)
        logger.info("✅ ГЕНЕРАЦИЯ КНИГИ ЗАВЕРШЕНА!")
        logger.info("=" * 80)
        logger.info(f"Результат: {result}")
        
        # Получаем созданную книгу
        if result.get("book_id"):
            book = db.query(Book).filter(Book.id == result["book_id"]).first()
            if book:
                logger.info(f"📚 Книга создана: {book.title}")
                logger.info(f"📄 PDF URL: {book.final_pdf_url}")
                logger.info(f"📊 Статус: {book.status}")
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации книги: {str(e)}", exc_info=True)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

