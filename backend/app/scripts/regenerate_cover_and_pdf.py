#!/usr/bin/env python3
"""
Скрипт для перегенерации обложки последней книги и создания PDF.
Использует новый двухэтапный пайплайн для максимального сходства лица.
"""
import asyncio
import sys
import os
sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Scene, Image, ThemeStyle, Child
from app.services.image_pipeline import generate_final_image
from app.services.pdf_service import PdfPage, render_book_pdf
from app.services.scene_utils import is_cover_scene
from app.services.prompt_sanitizer import build_cover_prompt
from sqlalchemy import desc
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def regenerate_cover_and_pdf():
    """Перегенерирует обложку последней книги и создает PDF."""
    db = SessionLocal()
    try:
        # Находим последнюю книгу
        last_book = db.query(Book).order_by(desc(Book.created_at)).first()
        if not last_book:
            logger.error("❌ Книги не найдены в БД")
            return
        
        logger.info(f"📚 Найдена последняя книга: {last_book.id}")
        logger.info(f"   Название: {last_book.title}")
        logger.info(f"   Child ID: {last_book.child_id}")
        
        # Получаем обложку (order=0)
        cover_scene = db.query(Scene).filter(
            Scene.book_id == last_book.id,
            Scene.order == 0
        ).first()
        
        if not cover_scene:
            logger.error("❌ Обложка (order=0) не найдена")
            return
        
        if not cover_scene.image_prompt:
            logger.error("❌ У обложки нет image_prompt")
            return
        
        logger.info(f"✓ Обложка найдена, есть image_prompt")
        
        # Получаем стиль
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == last_book.id).first()
        if not theme_style:
            logger.error("❌ Стиль для книги не найден")
            return
        
        final_style = theme_style.final_style
        logger.info(f"✓ Стиль: {final_style}")
        
        # Получаем child для face profile
        child = None
        child_id = None
        if last_book.child_id:
            child = db.query(Child).filter(Child.id == last_book.child_id).first()
            if child:
                child_id = child.id
                logger.info(f"✓ Ребёнок найден: {child.name}, возраст {child.age}")
        
        # Формируем промпт для обложки
        age_emphasis = ""
        if child and child.age:
            age_emphasis = f"IMPORTANT: The child character must look exactly {child.age} years old with child proportions: large head relative to body, short legs, small hands, chubby cheeks, big eyes. "
        
        enhanced_prompt = build_cover_prompt(
            base_style=final_style,
            scene_prompt=cover_scene.image_prompt or "",
            age_emphasis=age_emphasis
        )
        
        logger.info(f"🎨 Генерация обложки с двухэтапным пайплайном...")
        logger.info(f"   Промпт: {enhanced_prompt[:150]}...")
        
        # Генерируем обложку
        final_url = await generate_final_image(
            prompt=enhanced_prompt,
            face_url=None,  # Не используем старый face_url
            child_photo_path=None,
            child_photo_paths=None,
            style=final_style,
            book_title=last_book.title,
            child_id=child_id,
            use_child_face=True  # Используем face profile
        )
        
        logger.info(f"✓ Обложка сгенерирована: {final_url}")
        
        # Обновляем запись в БД
        image_record = db.query(Image).filter(
            Image.book_id == last_book.id,
            Image.scene_order == 0
        ).first()
        
        if image_record:
            image_record.final_url = final_url
            image_record.style = final_style
        else:
            image_record = Image(
                book_id=last_book.id,
                scene_order=0,
                final_url=final_url,
                style=final_style
            )
            db.add(image_record)
        
        db.commit()
        logger.info(f"✓ Обложка сохранена в БД")
        
        # Генерируем PDF
        logger.info(f"📄 Генерация PDF файла...")
        
        # Получаем все сцены с финальными изображениями
        scenes = db.query(Scene).filter(
            Scene.book_id == last_book.id
        ).order_by(Scene.order).all()
        
        images = db.query(Image).filter(
            Image.book_id == last_book.id
        ).all()
        
        image_dict = {img.scene_order: img for img in images}
        
        pages = []
        for scene in scenes:
            if scene.order == 0:  # Обложка
                img = image_dict.get(0)
                if img and img.final_url:
                    pages.append(PdfPage(
                        order=0,
                        image_url=img.final_url,
                        text="",  # Обложка без текста
                        style=img.style or final_style,
                        book_title=last_book.title
                    ))
            else:
                img = image_dict.get(scene.order)
                if img and img.final_url:
                    pages.append(PdfPage(
                        order=scene.order,
                        image_url=img.final_url,
                        text=scene.text or "",
                        style=img.style or final_style
                    ))
        
        if not pages:
            logger.error("❌ Нет страниц для PDF")
            return
        
        logger.info(f"✓ Подготовлено {len(pages)} страниц для PDF")
        
        # Создаем PDF
        from app.services.storage import BASE_UPLOAD_DIR
        pdf_dir = os.path.join(BASE_UPLOAD_DIR, "pdfs")
        os.makedirs(pdf_dir, exist_ok=True)
        
        pdf_filename = f"{last_book.id}.pdf"
        pdf_path = os.path.join(pdf_dir, pdf_filename)
        
        await asyncio.to_thread(
            render_book_pdf,
            pdf_path,
            last_book.title or "StoryHero",
            pages,
            final_style
        )
        
        logger.info(f"✅ PDF файл создан: {pdf_path}")
        
        # Формируем публичный URL
        from app.services.storage import get_server_base_url
        base_url = get_server_base_url()
        if ":8000" in base_url:
            base_url = base_url.replace(":8000", "")
        
        pdf_url = f"{base_url}/static/pdfs/{pdf_filename}"
        logger.info(f"✅ PDF доступен по URL: {pdf_url}")
        print(f"\n🎉 ГОТОВО!")
        print(f"📚 Книга: {last_book.title}")
        print(f"📄 PDF файл: {pdf_url}")
        print(f"📁 Локальный путь: {pdf_path}")
        
    except Exception as e:
        logger.error(f"❌ Ошибка: {str(e)}", exc_info=True)
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(regenerate_cover_and_pdf())


