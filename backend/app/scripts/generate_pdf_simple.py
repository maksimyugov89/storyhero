#!/usr/bin/env python3
"""
Упрощенный скрипт для генерации PDF файла (обходит проблемные места).
"""
import sys
import asyncio
from pathlib import Path

sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Scene, Image, ThemeStyle, Child
from app.services.storage import BASE_UPLOAD_DIR, get_server_base_url
from sqlalchemy import desc
import logging
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import black
from io import BytesIO
import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def generate_pdf_simple(book_id: str = None):
    """Генерирует PDF для книги (упрощенная версия)."""
    db = SessionLocal()
    
    try:
        # Получаем книгу по ID или последнюю
        if book_id:
            from uuid import UUID
            try:
                book_uuid = UUID(book_id)
                book = db.query(Book).filter(Book.id == book_uuid).first()
            except ValueError:
                logger.error(f"❌ Неверный формат book_id: {book_id}")
                return 1
        else:
            book = db.query(Book).order_by(desc(Book.created_at)).first()
        
        if not book:
            logger.error("❌ Книга не найдена в БД")
            return 1
        
        logger.info(f"📚 Книга: {book.title}")
        logger.info(f"   ID: {book.id}")
        
        # Получаем все сцены
        scenes = db.query(Scene).filter(Scene.book_id == book.id).order_by(Scene.order).all()
        images = db.query(Image).filter(Image.book_id == book.id).all()
        
        logger.info(f"📖 Сцен: {len(scenes)}, Изображений: {len(images)}")
        
        # Создаем PDF
        pdf_dir = Path(BASE_UPLOAD_DIR) / "books" / str(book.id)
        pdf_dir.mkdir(parents=True, exist_ok=True)
        pdf_path = pdf_dir / "final.pdf"
        
        logger.info(f"📄 Создаю PDF: {pdf_path}")
        
        # ШАГ 7: ФИНАЛЬНАЯ ПРОВЕРКА - валидация входных данных
        assert len(scenes) > 0, "❌ PDF должен содержать хотя бы одну страницу"
        assert scenes[0].order == 0, f"❌ Первая страница должна быть обложкой (order=0), получено order={scenes[0].order}"
        
        c = canvas.Canvas(str(pdf_path), pagesize=A4)
        
        # Регистрируем шрифт с поддержкой кириллицы
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        import os
        
        font_path = "/app/app/assets/fonts/DejaVuSans.ttf"
        cyrillic_font_available = False
        if os.path.exists(font_path):
            try:
                pdfmetrics.registerFont(TTFont('DejaVu', font_path))
                cyrillic_font_available = True
                logger.info("✓ Шрифт с кириллицей зарегистрирован")
            except Exception as e:
                logger.error(f"❌ Ошибка регистрации шрифта: {e}")
        
        # ШАГ 6: ГАРАНТИЯ КИРИЛЛИЦЫ - обязательный assert
        assert cyrillic_font_available, "❌ Шрифт с кириллицей НЕ зарегистрирован — PDF будет невалидным. Прерывание генерации."
        
        # Обрабатываем каждую страницу
        # ШАГ 1: ЖЁСТКО ЗАКРЕПИТЬ ОБЛОЖКУ - исправленная логика showPage()
        for idx, scene in enumerate(scenes):
            # ПРАВИЛО: первая страница (idx=0) НЕ вызывает showPage()
            if idx > 0:
                c.showPage()
            
            logger.info(f"  Страница {scene.order}...")
            
            # Находим изображение
            scene_images = [img for img in images if img.scene_order == scene.order]
            final_img = [img for img in scene_images if img.final_url]
            image_url = final_img[0].final_url if final_img else None
            
            if image_url:
                try:
                    response = requests.get(image_url, timeout=10)
                    response.raise_for_status()
                    img = ImageReader(BytesIO(response.content))
                    
                    if scene.order == 0:
                        # Обложка: изображение + название книги
                        c.drawImage(img, 0, 0, width=595, height=842, preserveAspectRatio=True)
                        
                        # Рисуем название книги на обложке
                        if book.title:
                            from reportlab.lib.colors import white
                            from reportlab.pdfbase import pdfmetrics
                            from reportlab.pdfbase.ttfonts import TTFont
                            import os
                            
                            # Регистрируем шрифт с поддержкой кириллицы
                            font_path = "/app/app/assets/fonts/DejaVuSans.ttf"
                            if os.path.exists(font_path):
                                try:
                                    pdfmetrics.registerFont(TTFont('DejaVu', font_path))
                                    font_name = 'DejaVu'
                                except:
                                    font_name = 'Helvetica-Bold'
                            else:
                                font_name = 'Helvetica-Bold'
                            
                            # Рисуем название книги
                            c.setFillColor(white)
                            c.setFont(font_name, 36)
                            title = book.title
                            
                            # Разбиваем название на строки
                            words = title.split()
                            lines = []
                            current_line = ""
                            for word in words:
                                test_line = current_line + " " + word if current_line else word
                                if c.stringWidth(test_line, font_name, 36) < 500:
                                    current_line = test_line
                                else:
                                    if current_line:
                                        lines.append(current_line)
                                    current_line = word
                            if current_line:
                                lines.append(current_line)
                            
                            # Рисуем название по центру
                            y = 700
                            for line in lines:
                                text_width = c.stringWidth(line, font_name, 36)
                                x = (595 - text_width) / 2
                                c.drawString(x, y, line)
                                y -= 45
                        
                        logger.info(f"    Обложка нарисована")
                    else:
                        # Story страница: изображение + текст сцены
                        c.drawImage(img, 0, 210, width=595, height=632, preserveAspectRatio=True)
                        
                        # Используем текст сцены, но проверяем, что это не промпт
                        scene_text = scene.text or ""
                        
                        # Фильтруем промпты: если текст содержит маркеры промпта, используем short_summary
                        prompt_markers = [
                            "Visual style", "IMPORTANT", "child character must be",
                            "Book cover illustration", "A sunny bedroom where",
                            "At the entrance of a magical forest", "Sophia, a 5-year-old",
                            "A 5-year-old child named", "with chubby cheeks"
                        ]
                        
                        if any(marker in scene_text for marker in prompt_markers):
                            # Это промпт, используем short_summary
                            scene_text = scene.short_summary or ""
                            if not scene_text:
                                # Если short_summary тоже нет, пропускаем текст
                                scene_text = ""
                            logger.warning(f"    ⚠️ Сцена {scene.order} содержит промпт, используем short_summary")
                        
                        # Дополнительная проверка: если текст слишком короткий или похож на промпт, используем short_summary
                        if scene_text and len(scene_text) < 50 and scene.short_summary and len(scene.short_summary) > 50:
                            scene_text = scene.short_summary
                            logger.info(f"    ℹ️ Сцена {scene.order}: текст слишком короткий, используем short_summary")
                        
                        if scene_text:
                            # Используем шрифт с поддержкой кириллицы
                            from reportlab.pdfbase import pdfmetrics
                            from reportlab.pdfbase.ttfonts import TTFont
                            import os
                            
                            font_path = "/app/app/assets/fonts/DejaVuSans.ttf"
                            if os.path.exists(font_path):
                                try:
                                    pdfmetrics.registerFont(TTFont('DejaVu', font_path))
                                    font_name = 'DejaVu'
                                except:
                                    font_name = 'Helvetica'
                            else:
                                font_name = 'Helvetica'
                            
                            c.setFillColor(black)
                            c.setFont(font_name, 12)
                            
                            # Разбиваем текст на строки
                            words = scene_text.split()
                            lines = []
                            current_line = ""
                            for word in words:
                                if len(current_line + " " + word) < 80:
                                    current_line += " " + word if current_line else word
                                else:
                                    if current_line:
                                        lines.append(current_line)
                                    current_line = word
                            if current_line:
                                lines.append(current_line)
                            
                            # Рисуем текст
                            y = 50
                            for line in lines[:10]:  # Максимум 10 строк
                                c.drawString(50, y, line)
                                y += 15
                        
                        logger.info(f"    Story страница нарисована")
                except Exception as e:
                    logger.error(f"    ❌ Ошибка при обработке страницы {scene.order}: {e}")
        
        c.save()
        logger.info(f"✅ PDF сохранен")
        
        if pdf_path.exists():
            size = pdf_path.stat().st_size
            logger.info(f"✅ PDF файл создан: {size:,} байт")
            
            # Обновляем БД
            base_url = get_server_base_url()
            pdf_url = f"{base_url}/static/books/{book.id}/final.pdf"
            book.final_pdf_url = pdf_url
            book.status = "completed"
            db.commit()
            
            logger.info("=" * 70)
            logger.info("🎉 PDF ФАЙЛ УСПЕШНО СОЗДАН!")
            logger.info("=" * 70)
            logger.info(f"📄 URL: {pdf_url}")
            return 0
        else:
            logger.error("❌ PDF не создан")
            return 1
            
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации PDF: {e}", exc_info=True)
        db.rollback()
        return 1
        
    finally:
        db.close()


if __name__ == "__main__":
    try:
        book_id = sys.argv[1] if len(sys.argv) > 1 else None
        if book_id:
            logger.info(f"📚 Генерация PDF для книги: {book_id}")
        exit_code = asyncio.run(generate_pdf_simple(book_id))
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("\n⚠️ Генерация PDF прервана пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)

