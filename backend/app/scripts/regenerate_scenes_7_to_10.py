#!/usr/bin/env python3
"""
Скрипт для перегенерации финальных изображений для конкретных сцен (order 7-10).
"""
import sys
import asyncio

sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Child, Scene, Image, ThemeStyle
from app.services.image_pipeline import generate_final_image
from app.routers.children import _get_child_photos_urls
from app.services.scene_utils import is_cover_scene
from app.services.prompt_sanitizer import build_cover_prompt
import logging
from pathlib import Path
import os

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def regenerate_scenes_7_to_10(book_id: str):
    """Перегенерирует финальные изображения для сцен с order 7-10."""
    db = SessionLocal()
    
    try:
        # Получаем книгу по ID
        from uuid import UUID
        book_uuid = UUID(book_id)
        book = db.query(Book).filter(Book.id == book_uuid).first()
        
        if not book:
            logger.error(f"❌ Книга с id={book_id} не найдена в БД")
            return 1
        
        logger.info(f"📚 Книга: {book.title}")
        logger.info(f"   ID: {book.id}")
        
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
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book.id).first()
        final_style = theme_style.final_style if theme_style else "pixar"
        
        logger.info(f"🎨 Стиль: {final_style}")
        logger.info("=" * 70)
        logger.info("🔄 Начало перегенерации изображений для сцен 7-10...")
        logger.info("=" * 70)
        
        # Получаем сцены с order 7-10
        scenes_to_regenerate = db.query(Scene).filter(
            Scene.book_id == book.id,
            Scene.order >= 7,
            Scene.order <= 10
        ).order_by(Scene.order).all()
        
        if not scenes_to_regenerate:
            logger.error("❌ Сцены с order 7-10 не найдены")
            return 1
        
        logger.info(f"📖 Найдено сцен для перегенерации: {len(scenes_to_regenerate)}")
        
        # Формируем промпт с финальным стилем
        age_emphasis = f"IMPORTANT: The child character must look exactly {child.age} years old with child proportions: large head relative to body, short legs, small hands, chubby cheeks, big eyes. " if child and child.age else ""
        
        # Конвертируем все URL фотографий в пути к файлам
        child_photo_paths_list = []
        if child_photos:
            from app.services.storage import BASE_UPLOAD_DIR
            for photo_url in child_photos:
                if isinstance(photo_url, str) and "/static/" in photo_url:
                    relative_path = photo_url.split("/static/", 1)[1]
                    photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
                    if os.path.exists(photo_path):
                        child_photo_paths_list.append(photo_path)
                        logger.info(f"✓ Добавлена фотография для face swap: {photo_path}")
                    else:
                        logger.warning(f"⚠️ Файл фотографии не найден: {photo_path}")
        
        # Перегенерируем каждую сцену
        for scene in scenes_to_regenerate:
            logger.info(f"")
            logger.info(f"🖼️ Перегенерация сцены order={scene.order}...")
            
            if not scene.image_prompt:
                logger.warning(f"⚠️ Сцена {scene.order} не имеет image_prompt, пропускаем")
                continue
            
            # Формируем промпт
            enhanced_prompt = f"Visual style: {final_style}. {age_emphasis}{scene.image_prompt}"
            
            # Генерируем финальное изображение
            try:
                child_id_for_face = child.id if child and child.id else None
                
                final_url = await asyncio.wait_for(
                    generate_final_image(
                        enhanced_prompt,
                        face_url=child.face_url or "",
                        child_photo_path=None,
                        child_photo_paths=child_photo_paths_list if child_photo_paths_list else None,
                        style=final_style,
                        book_title=None,  # Не обложка
                        child_id=child_id_for_face,
                        use_child_face=True
                    ),
                    timeout=1800.0  # 30 минут
                )
                
                logger.info(f"✓ Финальное изображение сгенерировано для сцены order={scene.order}: {final_url}")
                
                # Удаляем старую запись Image, если она существует
                old_images = db.query(Image).filter(
                    Image.book_id == book.id,
                    Image.scene_order == scene.order
                ).all()
                
                for old_img in old_images:
                    db.delete(old_img)
                    logger.info(f"🗑️ Удалена старая запись Image для сцены order={scene.order}")
                
                # Создаём новую запись с новым URL
                new_image = Image(
                    book_id=book.id,
                    scene_order=scene.order,
                    final_url=final_url
                )
                db.add(new_image)
                logger.info(f"✓ Создана новая запись Image для сцены order={scene.order} с URL: {final_url}")
                
                db.commit()
                logger.info(f"✅ БД обновлена для сцены order={scene.order}")
                
            except asyncio.TimeoutError:
                logger.error(f"❌ Таймаут при генерации изображения для сцены order={scene.order}")
                continue
            except Exception as e:
                logger.error(f"❌ Ошибка при генерации изображения для сцены order={scene.order}: {e}", exc_info=True)
                continue
        
        logger.info("")
        logger.info("=" * 70)
        logger.info("✅ ПЕРЕГЕНЕРАЦИЯ ИЗОБРАЖЕНИЙ ЗАВЕРШЕНА!")
        logger.info("=" * 70)
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Критическая ошибка: {e}", exc_info=True)
        db.rollback()
        return 1
        
    finally:
        db.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        logger.error("❌ Использование: python3 regenerate_scenes_7_to_10.py <book_id>")
        sys.exit(1)
    
    book_id = sys.argv[1]
    
    try:
        exit_code = asyncio.run(regenerate_scenes_7_to_10(book_id))
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("\n⚠️ Перегенерация прервана пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)

