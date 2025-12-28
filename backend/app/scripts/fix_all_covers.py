#!/usr/bin/env python3
"""
Скрипт для исправления всех обложек книг с некорректными промптами.
Перегенерирует финальные изображения обложек с исправленным промптом.
"""

import sys
import asyncio
import logging
import os
from pathlib import Path

# Добавляем корневую директорию в путь
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from app.db import SessionLocal
from app.models import Book, Child, Scene, Image, ThemeStyle
from app.services.image_pipeline import generate_final_image
from app.routers.children import _get_child_photos_urls
from app.services.storage import BASE_UPLOAD_DIR
from app.services.prompt_sanitizer import build_cover_prompt

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


async def fix_cover_for_book(book: Book, db: SessionLocal) -> bool:
    """
    Исправляет обложку для одной книги.
    
    Returns:
        bool: True если успешно, False если ошибка
    """
    try:
        logger.info(f"📚 Обработка книги: {book.title} (ID: {book.id})")
        
        # Получаем ребенка
        child = db.query(Child).filter(Child.id == book.child_id).first()
        if not child:
            logger.error(f"❌ Ребенок не найден для книги {book.id}")
            return False
        
        # Получаем стиль
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book.id).first()
        final_style = theme_style.final_style if theme_style else 'pixar'
        
        # Получаем фотографии ребенка
        child_photos = _get_child_photos_urls(child.id)
        
        # Получаем сцену обложки
        scene = db.query(Scene).filter(
            Scene.book_id == book.id,
            Scene.order == 0
        ).first()
        
        if not scene or not scene.image_prompt:
            logger.warning(f"⚠️ Обложка не найдена для книги {book.id}")
            return False
        
        logger.info(f"📝 Исходный промпт (первые 200 символов): {scene.image_prompt[:200]}...")
        
        # Строим исправленный промпт
        enhanced_prompt = build_cover_prompt(
            base_style=final_style,
            scene_prompt=scene.image_prompt or '',
            age_emphasis=''  # НЕ передаем - попадает в изображение!
        )
        
        logger.info(f"✅ Исправленный промпт (первые 200 символов): {enhanced_prompt[:200]}...")
        
        # Проверяем, что в промпте нет запрещенных фраз
        main_prompt = enhanced_prompt.split('no text, no letters')[0] if 'no text, no letters' in enhanced_prompt else enhanced_prompt
        forbidden_phrases = ['pixar style', '5-year-old', 'years old', 'named Sofya', 'child character must', 'IMPORTANT', 'StoryHero']
        found_forbidden = [phrase for phrase in forbidden_phrases if phrase.lower() in main_prompt.lower()]
        
        if found_forbidden:
            logger.warning(f"⚠️ В промпте найдены запрещенные фразы: {found_forbidden}")
            logger.warning(f"   Промпт: {enhanced_prompt}")
        else:
            logger.info(f"✅ Промпт чист от запрещенных фраз")
        
        # Получаем пути к фотографиям
        child_photo_paths_list = []
        if child_photos:
            for photo_url in child_photos:
                if isinstance(photo_url, str) and '/static/' in photo_url:
                    relative_path = photo_url.split('/static/', 1)[1]
                    photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
                    if os.path.exists(photo_path):
                        child_photo_paths_list.append(photo_path)
        
        logger.info(f"📸 Найдено фотографий ребенка: {len(child_photo_paths_list)}")
        
        # Генерируем финальное изображение
        child_id_for_face = child.id if child and child.id else None
        
        logger.info(f"🎨 Генерация финального изображения обложки...")
        final_url = await asyncio.wait_for(
            generate_final_image(
                enhanced_prompt,
                face_url=child.face_url or '',
                child_photo_path=None,
                child_photo_paths=child_photo_paths_list if child_photo_paths_list else None,
                style=final_style,
                book_title=book.title,
                child_id=child_id_for_face,
                use_child_face=True
            ),
            timeout=1800.0
        )
        
        logger.info(f"✅ Финальное изображение сгенерировано: {final_url}")
        
        # Обновляем или создаем запись изображения
        image_record = db.query(Image).filter(
            Image.book_id == book.id,
            Image.scene_order == 0
        ).first()
        
        if image_record:
            old_url = image_record.final_url
            image_record.final_url = final_url
            logger.info(f"📝 Обновлена запись Image (старый URL: {old_url})")
        else:
            image_record = Image(
                book_id=book.id,
                scene_order=0,
                final_url=final_url
            )
            db.add(image_record)
            logger.info(f"📝 Создана новая запись Image")
        
        db.commit()
        logger.info(f"✅ Обложка исправлена для книги: {book.title}")
        return True
        
    except asyncio.TimeoutError:
        logger.error(f"❌ Таймаут при генерации изображения для книги {book.id}")
        return False
    except Exception as e:
        logger.error(f"❌ Ошибка при исправлении обложки для книги {book.id}: {e}", exc_info=True)
        db.rollback()
        return False


async def fix_all_covers():
    """
    Исправляет все обложки книг.
    Сначала обрабатывает книги БЕЗ финальных обложек (приоритет),
    затем перегенерирует книги С финальными обложками.
    """
    db = SessionLocal()
    try:
        # ПРИОРИТЕТ 1: Книги БЕЗ финальных обложек
        books_without_final = db.query(Book).join(Scene).filter(
            Scene.order == 0,
            Scene.image_prompt.isnot(None),
            Scene.image_prompt != ''
        ).outerjoin(Image, (Image.book_id == Book.id) & (Image.scene_order == 0)).filter(
            (Image.final_url.is_(None)) | (Image.final_url == '')
        ).distinct().all()
        
        # ПРИОРИТЕТ 2: Книги С финальными обложками (для перегенерации)
        books_with_final = db.query(Book).join(Scene).join(Image).filter(
            Scene.order == 0,
            Scene.image_prompt.isnot(None),
            Scene.image_prompt != '',
            Image.scene_order == 0,
            Image.final_url.isnot(None),
            Image.final_url != ''
        ).distinct().all()
        
        total_books = len(books_without_final) + len(books_with_final)
        logger.info(f"📚 Найдено книг БЕЗ финальных обложек: {len(books_without_final)}")
        logger.info(f"📚 Найдено книг С финальными обложками: {len(books_with_final)}")
        logger.info(f"📚 Всего книг для обработки: {total_books}")
        
        if total_books == 0:
            logger.info("✅ Книг с обложками не найдено")
            return
        
        success_count = 0
        error_count = 0
        
        # Обрабатываем книги БЕЗ финальных обложек (приоритет)
        if books_without_final:
            logger.info(f"\\n{'='*80}")
            logger.info(f"🎯 ПРИОРИТЕТ 1: Обработка книг БЕЗ финальных обложек ({len(books_without_final)} книг)")
            logger.info(f"{'='*80}")
            
            for i, book in enumerate(books_without_final, 1):
                logger.info(f"\\n{'='*80}")
                logger.info(f"📖 Книга {i}/{len(books_without_final)}: {book.title}")
                logger.info(f"{'='*80}")
                
                try:
                    success = await fix_cover_for_book(book, db)
                    
                    if success:
                        success_count += 1
                    else:
                        error_count += 1
                except Exception as e:
                    logger.error(f"❌ Критическая ошибка при обработке книги {book.id}: {e}", exc_info=True)
                    error_count += 1
                
                # Небольшая задержка между книгами
                if i < len(books_without_final):
                    await asyncio.sleep(2)
        
        # Обрабатываем книги С финальными обложками (перегенерация)
        if books_with_final:
            logger.info(f"\\n{'='*80}")
            logger.info(f"🔄 ПРИОРИТЕТ 2: Перегенерация обложек для книг С финальными обложками ({len(books_with_final)} книг)")
            logger.info(f"{'='*80}")
            
            for i, book in enumerate(books_with_final, 1):
                logger.info(f"\\n{'='*80}")
                logger.info(f"📖 Книга {i}/{len(books_with_final)}: {book.title}")
                logger.info(f"{'='*80}")
                
                try:
                    success = await fix_cover_for_book(book, db)
                    
                    if success:
                        success_count += 1
                    else:
                        error_count += 1
                except Exception as e:
                    logger.error(f"❌ Критическая ошибка при обработке книги {book.id}: {e}", exc_info=True)
                    error_count += 1
                
                # Небольшая задержка между книгами
                if i < len(books_with_final):
                    await asyncio.sleep(2)
        
        logger.info(f"\\n{'='*80}")
        logger.info(f"🎉 ИСПРАВЛЕНИЕ ЗАВЕРШЕНО")
        logger.info(f"{'='*80}")
        logger.info(f"✅ Успешно исправлено: {success_count}/{total_books}")
        logger.info(f"❌ Ошибок: {error_count}/{total_books}")
        logger.info(f"{'='*80}")
        
    finally:
        db.close()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Если передан book_id, исправляем только эту книгу
        book_id = sys.argv[1]
        db = SessionLocal()
        try:
            from uuid import UUID
            book_uuid = UUID(book_id)
            book = db.query(Book).filter(Book.id == book_uuid).first()
            if book:
                asyncio.run(fix_cover_for_book(book, db))
            else:
                logger.error(f"❌ Книга с ID {book_id} не найдена")
        finally:
            db.close()
    else:
        # Исправляем все книги
        asyncio.run(fix_all_covers())

