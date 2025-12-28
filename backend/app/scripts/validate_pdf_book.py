#!/usr/bin/env python3
"""
Скрипт для валидации PDF книги.
Проверяет количество страниц, наличие изображений, статус fetch и байты заголовков.
"""
import sys
import asyncio
from pathlib import Path
from uuid import UUID

sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Scene, Image
from app.services.storage import BASE_UPLOAD_DIR
from app.services.image_fetcher import fetch_image_bytes, ImageFetchError
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def validate_pdf_book(book_id: str):
    """Валидирует PDF для книги."""
    db = SessionLocal()
    
    try:
        book_uuid = UUID(book_id)
        book = db.query(Book).filter(Book.id == book_uuid).first()
        
        if not book:
            logger.error(f"❌ Книга {book_id} не найдена")
            return 1
        
        logger.info(f"📚 Книга: {book.title}")
        logger.info(f"   ID: {book.id}")
        logger.info(f"   Статус: {book.status}")
        
        # Получаем все сцены
        all_scenes = db.query(Scene).filter(Scene.book_id == book.id).order_by(Scene.order).all()
        story_scenes = [s for s in all_scenes if s.order > 0]
        requested_pages = len(story_scenes)
        
        logger.info(f"📄 requested_pages: {requested_pages}")
        logger.info(f"   Всего сцен в БД: {len(all_scenes)}")
        logger.info(f"   Story сцен: {len(story_scenes)}")
        
        # Проверяем PDF файл
        pdf_path = Path(BASE_UPLOAD_DIR) / "books" / str(book.id) / "final.pdf"
        if not pdf_path.exists():
            logger.error(f"❌ PDF файл не найден: {pdf_path}")
            return 1
        
        pdf_size = pdf_path.stat().st_size
        logger.info(f"📄 PDF файл: {pdf_size:,} байт")
        
        # Получаем изображения
        images = db.query(Image).filter(Image.book_id == book.id).all()
        
        # Проверяем каждую сцену
        logger.info("\n" + "=" * 70)
        logger.info("Проверка сцен:")
        logger.info("=" * 70)
        
        orders_in_pdf = []
        for scene in all_scenes:
            if scene.order > requested_pages:
                continue  # Пропускаем лишние сцены
            
            scene_images = [img for img in images if img.scene_order == scene.order]
            final_img = [img for img in scene_images if img.final_url]
            draft_img = [img for img in scene_images if img.draft_url]
            
            image_url = final_img[0].final_url if final_img else (draft_img[0].draft_url if draft_img else None)
            
            if image_url:
                orders_in_pdf.append(scene.order)
                
                # Проверяем fetch статус
                try:
                    image_bytes = fetch_image_bytes(image_url, timeout=10, retries=1)
                    header = image_bytes[:20].hex()
                    status = "✅ OK"
                except ImageFetchError as e:
                    status = f"❌ FAIL: {str(e)[:50]}"
                    header = "N/A"
                except Exception as e:
                    status = f"❌ ERROR: {str(e)[:50]}"
                    header = "N/A"
                
                logger.info(f"   Сцена {scene.order:2d}: {status}")
                logger.info(f"      URL: {image_url[:80]}...")
                logger.info(f"      Header: {header}")
            else:
                logger.warning(f"   Сцена {scene.order:2d}: ⚠️ Нет изображения")
        
        logger.info("\n" + "=" * 70)
        logger.info(f"Итоги:")
        logger.info(f"   requested_pages: {requested_pages}")
        logger.info(f"   expected_pages: {requested_pages + 1} (обложка + story)")
        logger.info(f"   orders в PDF: {orders_in_pdf}")
        logger.info(f"   actual_pages: {len(orders_in_pdf)}")
        
        if len(orders_in_pdf) != requested_pages + 1:
            logger.error(f"❌ Несоответствие: expected {requested_pages + 1}, got {len(orders_in_pdf)}")
            return 1
        
        logger.info("✅ Валидация пройдена")
        return 0
        
    except Exception as e:
        logger.error(f"❌ Ошибка при валидации: {e}", exc_info=True)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        logger.error("Использование: python validate_pdf_book.py <book_id>")
        sys.exit(1)
    
    book_id = sys.argv[1]
    exit_code = validate_pdf_book(book_id)
    sys.exit(exit_code)

