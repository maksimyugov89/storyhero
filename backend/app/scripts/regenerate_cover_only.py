"""
Скрипт для перегенерации только обложки (order=0) с программным добавлением названия.
"""
import sys
sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Image, Scene, Child
from app.routers.final_images import _generate_final_images_internal
from app.routers.children import _get_child_photos_urls
from uuid import UUID
import asyncio
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    db = SessionLocal()
    try:
        book_id = '8734aaf6-c0c7-4fb5-bc17-6ec68a0b9a76'
        book_uuid = UUID(book_id)
        book = db.query(Book).filter(Book.id == book_uuid).first()
        
        if not book:
            logger.error(f"❌ Книга {book_id} не найдена")
            return
        
        child = db.query(Child).filter(Child.id == book.child_id).first()
        
        # Получаем только обложку (order=0)
        cover_scene = db.query(Scene).filter(
            Scene.book_id == book_uuid,
            Scene.order == 0
        ).first()
        
        if not cover_scene:
            logger.error("❌ Обложка (order=0) не найдена")
            return
        
        # Удаляем старое финальное изображение обложки, если есть
        old_image = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_id == cover_scene.id,
            Image.final_url.isnot(None)
        ).first()
        
        if old_image:
            logger.info(f"🗑️ Удаление старого финального изображения обложки")
            old_image.final_url = None
            db.commit()
        
        # Получаем все фотографии ребенка
        child_photos = _get_child_photos_urls(child.id) if child else []
        logger.info(f'📸 Получено {len(child_photos)} фотографий для face swap')
        
        # Получаем стиль из ThemeStyle
        from app.models import ThemeStyle
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        final_style = theme_style.final_style if theme_style else 'watercolor'
        
        logger.info(f'🎨 Стиль: {final_style}')
        logger.info('🔄 Перегенерация обложки...')
        
        # Генерируем только обложку через image_pipeline
        from app.services.image_pipeline import generate_final_image
        
        # Формируем промпт
        age_emphasis = f"IMPORTANT: The child character must look exactly {child.age} years old with child proportions: large head relative to body, short legs, small hands, chubby cheeks, big eyes. " if child and child.age else ""
        enhanced_prompt = f"Visual style: {final_style}. {age_emphasis}Book cover illustration. {cover_scene.image_prompt}"
        
        # Конвертируем URL фотографий в пути
        child_photo_paths_list = []
        if child_photos:
            from app.services.storage import BASE_UPLOAD_DIR
            import os
            for photo_url in child_photos:
                if isinstance(photo_url, str) and "/static/" in photo_url:
                    relative_path = photo_url.split("/static/", 1)[1]
                    photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
                    if os.path.exists(photo_path):
                        child_photo_paths_list.append(photo_path)
        
        logger.info(f"🎭 Использование {len(child_photo_paths_list)} фотографий для face swap")
        
        # Генерируем изображение
        result = await generate_final_image(
            prompt=enhanced_prompt,
            scene_id=cover_scene.id,
            book_id=book_id,
            child_photo_paths=child_photo_paths_list,
            style=final_style
        )
        
        if result and result.get('final_url'):
            logger.info(f"✅ Обложка успешно перегенерирована: {result['final_url']}")
        else:
            logger.error("❌ Ошибка при генерации обложки")
            
    except Exception as e:
        logger.error(f"❌ Ошибка: {e}", exc_info=True)
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(main())

