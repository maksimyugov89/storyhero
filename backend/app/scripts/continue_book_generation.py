#!/usr/bin/env python3
"""
Скрипт для продолжения генерации книги с текущего этапа.
Используется когда задача была прервана или контейнер перезапустился.
"""

import sys
import asyncio
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from sqlalchemy.orm import Session
from app.db import SessionLocal
from app.models import Book, Scene, Image, ThemeStyle, Child
from app.routers.books import generate_full_book_task
from app.routers.children import _get_child_photos_urls
from app.routers.text import _create_text_internal, CreateTextRequest
from app.routers.image_prompts import _create_image_prompts_internal, CreateImagePromptsRequest
from app.routers.style import _select_style_internal, SelectStyleRequest
from app.routers.images import _generate_draft_images_internal, ImageRequest
from app.routers.final_images import _generate_final_images_internal
from app.services.pdf_service import PdfPage, render_book_pdf
from app.services.storage import BASE_UPLOAD_DIR, get_server_base_url
from uuid import UUID
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def continue_book_generation(book_id: str):
    """Продолжает генерацию книги с текущего этапа."""
    db: Session = SessionLocal()
    
    try:
        book_uuid = UUID(book_id)
        book = db.query(Book).filter(Book.id == book_uuid).first()
        
        if not book:
            logger.error(f"❌ Книга {book_id} не найдена")
            return 1
        
        logger.info(f"📚 Продолжение генерации книги: {book.title}")
        logger.info(f"📊 Текущий статус: {book.status}")
        
        # Получаем данные ребенка
        child = db.query(Child).filter(Child.id == book.child_id).first()
        if not child:
            logger.error(f"❌ Ребенок с id={book.child_id} не найден")
            return 1
        
        # Получаем фотографии ребенка
        child_photos = []
        try:
            child_photos = _get_child_photos_urls(child.id)
            logger.info(f"📸 Получено {len(child_photos)} фотографий")
        except Exception as e:
            logger.warning(f"⚠️ Ошибка получения фото: {e}")
        
        # Проверяем текущее состояние
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        images = db.query(Image).filter(Image.book_id == book_uuid).all()
        
        logger.info(f"📖 Сцен: {len(scenes)}")
        logger.info(f"🖼️  Изображений: {len(images)}")
        
        # Определяем, с какого этапа продолжать
        has_text = any(scene.text for scene in scenes)
        has_prompts = any(scene.image_prompt for scene in scenes)
        has_style = theme_style is not None
        has_draft_images = any(img.draft_url for img in images)
        has_final_images = any(img.final_url for img in images)
        
        logger.info("=" * 80)
        logger.info("📊 Анализ текущего состояния:")
        logger.info(f"   ✓ Текст: {'Да' if has_text else 'Нет'}")
        logger.info(f"   ✓ Промпты: {'Да' if has_prompts else 'Нет'}")
        logger.info(f"   ✓ Стиль: {'Да' if has_style else 'Нет'}")
        logger.info(f"   ✓ Черновые изображения: {'Да' if has_draft_images else 'Нет'}")
        logger.info(f"   ✓ Финальные изображения: {'Да' if has_final_images else 'Нет'}")
        logger.info("=" * 80)
        
        # Продолжаем с нужного этапа
        if not has_text:
            logger.info("✍️ Шаг 3: Создание текста...")
            text_request = CreateTextRequest(book_id=book_id)
            await _create_text_internal(text_request, db, child.user_id)
            logger.info("✅ Текст создан")
        
        if not has_prompts:
            logger.info("🖼️ Шаг 4: Создание промптов...")
            prompts_request = CreateImagePromptsRequest(book_id=book_id)
            await _create_image_prompts_internal(prompts_request, db, child.user_id)
            logger.info("✅ Промпты созданы")
        
        if not has_style:
            logger.info("🎨 Шаг 5: Выбор стиля...")
            style_request = SelectStyleRequest(book_id=book_id, mode="manual", style="watercolor")
            await _select_style_internal(style_request, db, child.user_id)
            logger.info("✅ Стиль выбран")
        
        if not has_draft_images:
            logger.info("🖼️ Шаг 6: Генерация черновых изображений...")
            image_request = ImageRequest(book_id=book_id, face_url=child.face_url or "")
            await _generate_draft_images_internal(image_request, db, child.user_id, final_style="watercolor", task_id=None)
            logger.info("✅ Черновые изображения созданы")
        
        if not has_final_images:
            logger.info("🎨 Шаг 7: Генерация финальных изображений...")
            await _generate_final_images_internal(
                book_id=book_id,
                db=db,
                current_user_id=child.user_id,
                final_style="watercolor",
                face_url=child.face_url or "",
                task_id=None,
                child_photos=child_photos
            )
            logger.info("✅ Финальные изображения созданы")
        
        # Шаг 8: Генерация PDF
        logger.info("📄 Шаг 8: Генерация PDF...")
        
        # Получаем стиль книги
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        book_style = theme_style.final_style if theme_style else "watercolor"
        
        # Получаем ВСЕ сцены (включая обложку order=0)
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        
        # Создаем список страниц для PDF
        pages = []
        final_images_data = []
        
        for scene in scenes:
            image_record = db.query(Image).filter(
                Image.book_id == book_uuid,
                Image.scene_order == scene.order
            ).first()
            
            # Используем финальное изображение, если есть, иначе черновое
            image_url = None
            if image_record:
                image_url = image_record.final_url or image_record.draft_url
                if image_url:
                    final_images_data.append({
                        "order": scene.order,
                        "image_url": image_url
                    })
            
            # Добавляем страницу, если есть изображение (финальное или черновое)
            if image_url:
                pages.append(PdfPage(
                    order=scene.order,
                    text=scene.text or scene.short_summary or "",
                    image_url=image_url,
                    style=book_style,
                    book_title=book.title if scene.order == 0 else ""  # Название книги только для обложки
                ))
            else:
                logger.warning(f"⚠️ Сцена order={scene.order} не имеет изображения, пропускаем")
        
        # Генерируем PDF
        if pages:
            pdf_dir = Path(BASE_UPLOAD_DIR) / "books" / str(book_uuid)
            pdf_dir.mkdir(parents=True, exist_ok=True)
            pdf_path = pdf_dir / "final.pdf"
            
            # Генерируем PDF
            await asyncio.to_thread(render_book_pdf, str(pdf_path), book.title or "StoryHero", pages, book_style)
            
            # Получаем публичный URL
            base_url = get_server_base_url()
            pdf_url = f"{base_url}/static/books/{book_uuid}/final.pdf"
            
            # Сохраняем в БД
            book.final_pdf_url = pdf_url
            book.images_final = {"images": final_images_data}
            book.status = "completed"
            db.commit()
            
            logger.info(f"✅ PDF создан: {pdf_url}")
        else:
            logger.warning("⚠️ Нет изображений для создания PDF")
        
        logger.info("=" * 80)
        logger.info("✅ ГЕНЕРАЦИЯ КНИГИ ЗАВЕРШЕНА!")
        logger.info("=" * 80)
        logger.info(f"📚 Book ID: {book_id}")
        logger.info(f"📄 PDF URL: {book.final_pdf_url}")
        logger.info("=" * 80)
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Ошибка: {e}", exc_info=True)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    BOOK_ID = "8734aaf6-c0c7-4fb5-bc17-6ec68a0b9a76"
    exit_code = asyncio.run(continue_book_generation(BOOK_ID))
    sys.exit(exit_code)

