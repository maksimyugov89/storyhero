#!/usr/bin/env python3
"""
Скрипт для генерации PDF файла для последней книги.
"""
import sys
import asyncio
from pathlib import Path

sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Scene, Image, ThemeStyle, Child
from app.services.pdf_service import PdfPage, render_book_pdf
from app.services.storage import BASE_UPLOAD_DIR, get_server_base_url
from sqlalchemy import desc
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def generate_pdf(book_id: str = None):
    """Генерирует PDF для книги.
    
    Args:
        book_id: UUID книги (опционально). Если не указан, используется последняя книга.
    """
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
        logger.info(f"   Статус: {book.status}")
        
        # Получаем стиль книги
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book.id).first()
        book_style = theme_style.final_style if theme_style else "pixar"
        
        logger.info(f"🎨 Стиль: {book_style}")
        
        # Получаем ребёнка для возраста
        child = db.query(Child).filter(Child.id == book.child_id).first()
        child_age = child.age if child else None
        
        logger.info(f"👶 Ребенок: {child.name if child else 'не найден'}, возраст: {child_age} лет")
        
        # Получаем все сцены
        all_scenes = db.query(Scene).filter(Scene.book_id == book.id).order_by(Scene.order).all()
        logger.info(f"📖 Всего сцен в БД: {len(all_scenes)}")
        
        # ЧАСТЬ A: ЖЁСТКИЙ КОНТРОЛЬ КОЛИЧЕСТВА СТРАНИЦ
        # Определяем requested_pages из количества сцен (без обложки)
        # Обложка (order=0) всегда включается, далее только сцены с 1 <= order <= requested_pages
        story_scenes = [s for s in all_scenes if s.order > 0]
        requested_pages = len(story_scenes)  # Количество сцен без обложки
        
        # Если в БД больше сцен, чем должно быть - обрезаем
        # Максимум 20 страниц (без обложки) по бизнес-правилам
        if requested_pages > 20:
            logger.warning(f"⚠️ В БД больше 20 сцен ({requested_pages}), обрезаем до 20")
            requested_pages = 20
        
        # ШАГ 1: ЖЁСТКАЯ ФИЛЬТРАЦИЯ СЦЕН - убрать дубликаты, строго по order
        # Обложка (order=0) - всегда одна
        cover_scene = [s for s in all_scenes if s.order == 0]
        if len(cover_scene) > 1:
            logger.warning(f"⚠️ Найдено {len(cover_scene)} обложек, берём первую")
            cover_scene = [cover_scene[0]]
        elif len(cover_scene) == 0:
            logger.error("❌ Обложка (order=0) не найдена!")
            cover_scene = []
        
        # Story сцены: строго 1 <= order <= requested_pages, без дубликатов
        story_scenes_dict = {}
        for s in story_scenes:
            if s.order is None:
                logger.warning(f"⚠️ Сцена с order=None пропущена: {s.id}")
                continue
            if 1 <= s.order <= requested_pages:
                # Убираем дубликаты - берём первую сцену с таким order
                if s.order not in story_scenes_dict:
                    story_scenes_dict[s.order] = s
                else:
                    logger.warning(f"⚠️ Дубликат order={s.order}, пропускаем сцену {s.id}")
        
        filtered_story_scenes = sorted(story_scenes_dict.values(), key=lambda x: x.order)
        
        scenes = cover_scene + filtered_story_scenes
        expected_pages = requested_pages + 1  # обложка + story страницы
        
        logger.info(f"📄 PDF build: requested_pages={requested_pages} expected={expected_pages} scenes_selected={len(scenes)}")
        logger.info(f"   Обложка: {len(cover_scene)}, Story сцены: {len(filtered_story_scenes)}")
        logger.info(f"   Orders: {[s.order for s in scenes]}")
        
        if len(filtered_story_scenes) < requested_pages:
            logger.warning(f"⚠️ Недостаточно сцен: ожидается {requested_pages}, найдено {len(filtered_story_scenes)}")
        
        # Создаем список страниц для PDF
        pages = []
        final_images_data = []
        
        for scene in scenes:
            # Получаем изображение для сцены (приоритет: final_url, затем draft_url)
            images = db.query(Image).filter(Image.book_id == book.id).all()
            scene_images = [img for img in images if img.scene_order == scene.order]
            
            image_url = None
            # Сначала ищем финальное изображение
            final_img = [img for img in scene_images if img.final_url]
            if final_img:
                image_url = final_img[0].final_url
                logger.info(f"   ✓ Сцена {scene.order}: финальное изображение найдено")
            else:
                # Если финального нет, используем черновое
                draft_img = [img for img in scene_images if img.draft_url]
                if draft_img:
                    image_url = draft_img[0].draft_url
                    logger.warning(f"   ⚠️ Сцена {scene.order}: используется черновое изображение (финальное отсутствует)")
                else:
                    logger.error(f"   ❌ Сцена {scene.order}: изображение не найдено (ни финальное, ни черновое)")
            
            if image_url:
                final_images_data.append({
                    "order": scene.order,
                    "image_url": image_url
                })
            
            # Добавляем страницу в PDF (только если есть изображение)
            if image_url:
                # КРИТИЧНО: Используем scene.text, но с МАКСИМАЛЬНО АГРЕССИВНОЙ фильтрацией промптов
                # Для обложки (order=0) текст игнорируется - название рисуется программно
                scene_text = ""
                if scene.order != 0:  # Не обложка
                    scene_text = scene.text or ""
                    
                    # МАКСИМАЛЬНО АГРЕССИВНАЯ фильтрация промптов на этапе создания pages
                    prompt_markers = [
                        "Visual style", "IMPORTANT", "child character must be",
                        "child character must", "must be", "Book cover illustration",
                        "StoryHero", "pixar", "IMPORTANT:", "The child character",
                        "visual style", "important", "storyhero", "StoryHero",
                        "child character", "character must", "must loo", "must look"
                    ]
                    
                    text_lower = scene_text.lower()
                    contains_prompt = any(marker.lower() in text_lower for marker in prompt_markers)
                    
                    # Дополнительная проверка: если текст содержит "StoryHero" или начинается с английских слов
                    if not contains_prompt:
                        if "storyhero" in text_lower or scene_text.strip().startswith(("Visual", "IMPORTANT", "The", "A ", "An ")):
                            contains_prompt = True
                    
                    # КРИТИЧНО: Если обнаружен промпт - ВСЕГДА используем short_summary или пропускаем текст
                    if contains_prompt:
                        scene_text = scene.short_summary or ""
                        logger.warning(f"⚠️ Сцена {scene.order}: ПРОМПТ ОБНАРУЖЕН в text, используем short_summary или пропускаем")
                        if not scene_text:
                            logger.error(f"❌ Сцена {scene.order}: ПРОМПТ обнаружен, но short_summary отсутствует - текст будет пропущен")
                    elif len(scene_text.strip()) < 30:
                        # Если текст слишком короткий, тоже используем short_summary
                        scene_text = scene.short_summary or ""
                
                pages.append(PdfPage(
                    order=scene.order,
                    text=scene_text,
                    image_url=image_url,
                    style=book_style,
                    age=child_age
                ))
        
        actual_pages = len(pages)
        logger.info(f"📄 Страниц для PDF: {actual_pages} (ожидается {expected_pages})")
        
        # ЖЁСТКИЙ ASSERT: количество страниц должно совпадать
        if actual_pages != expected_pages:
            error_msg = f"❌ PDF pages mismatch: expected {expected_pages} (requested_pages={requested_pages} + 1 cover), got {actual_pages}"
            logger.error(error_msg)
            logger.error(f"   Orders в PDF: {[p.order for p in pages]}")
            raise RuntimeError(error_msg)
        
        if not pages:
            logger.error("❌ Нет изображений для создания PDF")
            return 1
        
        # Генерируем PDF
        logger.info("=" * 70)
        logger.info("📄 Начало генерации PDF...")
        logger.info("=" * 70)
        
        pdf_dir = Path(BASE_UPLOAD_DIR) / "books" / str(book.id)
        pdf_dir.mkdir(parents=True, exist_ok=True)
        pdf_path = pdf_dir / "final.pdf"
        
        # Генерируем PDF напрямую (упрощенная версия для надежности)
        from reportlab.pdfgen import canvas
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.utils import ImageReader
        from io import BytesIO
        import requests
        
        logger.info("📄 Создаю PDF напрямую (упрощенная версия)...")
        c = canvas.Canvas(str(pdf_path), pagesize=A4)
        
        # Регистрируем шрифт с поддержкой кириллицы для всего PDF
        from reportlab.pdfbase import pdfmetrics
        from reportlab.pdfbase.ttfonts import TTFont
        import os
        
        font_path = "/app/app/assets/fonts/DejaVuSans.ttf"
        bold_font_path = "/app/app/assets/fonts/DejaVuSans-Bold.ttf"
        cyrillic_font_available = False
        cyrillic_bold_font_available = False
        
        if os.path.exists(font_path):
            try:
                pdfmetrics.registerFont(TTFont('CyrillicFont', font_path))
                cyrillic_font_available = True
                logger.info("✓ Шрифт с кириллицей зарегистрирован")
            except Exception as e:
                logger.error(f"❌ Ошибка регистрации шрифта: {e}")
        
        if os.path.exists(bold_font_path):
            try:
                pdfmetrics.registerFont(TTFont('CyrillicFontBold', bold_font_path))
                cyrillic_bold_font_available = True
                logger.info("✓ Жирный шрифт с кириллицей зарегистрирован")
            except Exception as e:
                logger.error(f"❌ Ошибка регистрации жирного шрифта: {e}")
        
        if not cyrillic_font_available:
            logger.error("❌ КРИТИЧЕСКАЯ ОШИБКА: Шрифт с кириллицей не зарегистрирован!")
            raise RuntimeError("Шрифт с кириллицей не зарегистрирован - PDF будет невалидным")
        
        for idx, page in enumerate(pages):
            # ПРАВИЛО: первая страница (idx=0) НЕ вызывает showPage()
            if idx > 0:
                c.showPage()
            
            logger.info(f"  Обрабатываю страницу {page.order}...")
            
            if page.image_url:
                try:
                    response = requests.get(page.image_url, timeout=10)
                    response.raise_for_status()
                    img = ImageReader(BytesIO(response.content))
                    
                    if page.order == 0:
                        # Обложка: изображение на ВСЮ страницу БЕЗ отступов
                        # КРИТИЧНО: Название должно быть встроено в изображение через add_title_to_cover
                        page_height = 841.89
                        page_width = 595.28
                        
                        # КРИТИЧНО: preserveAspectRatio=False для обложки - заполняем всю страницу
                        # Это гарантирует, что обложка будет на всю страницу без отступов
                        c.drawImage(img, 0, 0, width=page_width, height=page_height, preserveAspectRatio=False)
                        
                        # Проверяем, есть ли название в изображении
                        # Если нет - добавляем программно (fallback)
                        # Но сначала проверяем, что изображение действительно содержит название
                        logger.info(f"    Обложка нарисована на всю страницу (название должно быть встроено в изображение)")
                    else:
                        # Story страница: изображение в верхних 3/4, текст в нижних 1/4
                        # A4: 595.28 x 841.89 pt
                        page_height = 841.89
                        page_width = 595.28
                        text_area_height = page_height * 0.25  # Нижняя 1/4 часть
                        image_area_y0 = text_area_height  # Изображение начинается с 25% высоты
                        image_area_height = page_height - image_area_y0  # Верхние 75%
                        
                        # Рисуем изображение в верхних 3/4
                        c.drawImage(img, 0, image_area_y0, width=page_width, height=image_area_height, preserveAspectRatio=True)
                        
                        # Получаем текст сцены и фильтруем промпты
                        scene_text = page.text or ""
                        
                        # КРИТИЧЕСКИ ВАЖНО: АГРЕССИВНАЯ фильтрация промптов и артефактов
                        prompt_markers = [
                            "Visual style", "IMPORTANT", "child character must be",
                            "child character must", "must be", "Book cover illustration",
                            "A sunny bedroom where", "At the entrance of a magical forest",
                            "Sophia, a 5-year-old", "A 5-year-old child named",
                            "with chubby cheeks", "StoryHero", "pixar", "IMPORTANT:",
                            "The child character", "character must", "visual style",
                            "book cover", "illustration", "style:", "pixar style",
                            "must", "character", "child", "style"
                        ]
                        
                        # Проверяем, содержит ли текст промпты (регистронезависимо)
                        text_lower = scene_text.lower()
                        contains_prompt = any(marker.lower() in text_lower for marker in prompt_markers)
                        
                        # Дополнительная проверка: если текст начинается с английских слов (часто промпты)
                        if scene_text and not contains_prompt:
                            first_words = scene_text.split()[:5]
                            english_start = any(
                                word.lower() in ["visual", "important", "the", "a", "an", "book", "cover", "illustration", "style", "child", "character", "must"]
                                for word in first_words
                            )
                            if english_start:
                                contains_prompt = True
                                logger.warning(f"    ⚠️ Сцена {page.order}: текст начинается с английских слов (возможно промпт)")
                        
                        # КРИТИЧНО: Если обнаружен промпт - ВСЕГДА используем short_summary или ПРОПУСКАЕМ текст
                        if contains_prompt:
                            # Получаем short_summary из сцены
                            scene_obj = db.query(Scene).filter(
                                Scene.book_id == book.id,
                                Scene.order == page.order
                            ).first()
                            
                            if scene_obj and scene_obj.short_summary:
                                scene_text = scene_obj.short_summary
                                logger.error(f"    ❌ Сцена {page.order}: ПРОМПТ ОБНАРУЖЕН! Использован short_summary вместо text")
                            else:
                                scene_text = ""  # Если нет short_summary, пропускаем текст
                                logger.error(f"    ❌ Сцена {page.order}: ПРОМПТ ОБНАРУЖЕН! Текст содержит промпты, но short_summary отсутствует - текст ПРОПУЩЕН")
                        
                        # Если текст слишком короткий, тоже используем short_summary
                        elif len(scene_text.strip()) < 30:
                            scene_obj = db.query(Scene).filter(
                                Scene.book_id == book.id,
                                Scene.order == page.order
                            ).first()
                            
                            if scene_obj and scene_obj.short_summary:
                                scene_text = scene_obj.short_summary
                                logger.info(f"    ℹ️ Сцена {page.order}: текст слишком короткий, использован short_summary")
                            else:
                                scene_text = ""
                        
                        # Дополнительная проверка: если текст содержит не-кириллические символы (китайские, хинди и т.д.)
                        # Проверяем, что текст в основном на русском
                        if scene_text:
                            cyrillic_chars = sum(1 for c in scene_text if '\u0400' <= c <= '\u04FF')
                            total_chars = len([c for c in scene_text if c.isalpha()])
                            if total_chars > 0:
                                cyrillic_ratio = cyrillic_chars / total_chars
                                if cyrillic_ratio < 0.5:  # Меньше 50% кириллицы
                                    # Используем short_summary
                                    scene_obj = db.query(Scene).filter(
                                        Scene.book_id == book.id,
                                        Scene.order == page.order
                                    ).first()
                                    if scene_obj and scene_obj.short_summary:
                                        scene_text = scene_obj.short_summary
                                        logger.warning(f"    ⚠️ Сцена {page.order}: текст не на русском ({cyrillic_ratio*100:.1f}% кириллицы), использован short_summary")
                                    else:
                                        scene_text = ""
                                        logger.warning(f"    ⚠️ Сцена {page.order}: текст не на русском, но short_summary отсутствует - текст пропущен")
                        
                        # ФИНАЛЬНАЯ ПРОВЕРКА: если после всех фильтров текст всё ещё содержит промпты, очищаем его
                        if scene_text:
                            text_lower_final = scene_text.lower()
                            if any(marker.lower() in text_lower_final for marker in prompt_markers):
                                logger.error(f"    ❌ Сцена {page.order}: ПРОМПТ ВСЁ ЕЩЁ ОБНАРУЖЕН ПОСЛЕ ФИЛЬТРАЦИИ! Пропускаем текст.")
                                scene_text = ""
                        
                        # Рисуем текст в нижней 1/4 части
                        if scene_text:
                            from reportlab.lib.colors import black
                            from reportlab.pdfbase import pdfmetrics
                            from reportlab.pdfbase.ttfonts import TTFont
                            import os
                            
                            # Регистрируем шрифт с поддержкой кириллицы
                            font_path = "/app/app/assets/fonts/DejaVuSans.ttf"
                            cyrillic_font_available = False
                            if os.path.exists(font_path):
                                try:
                                    pdfmetrics.registerFont(TTFont('CyrillicFont', font_path))
                                    font_name = 'CyrillicFont'
                                    cyrillic_font_available = True
                                except Exception as e:
                                    logger.error(f"    ❌ Ошибка регистрации шрифта: {e}")
                                    font_name = 'Helvetica'
                            else:
                                logger.error(f"    ❌ Шрифт не найден: {font_path}")
                                font_name = 'Helvetica'
                            
                            if not cyrillic_font_available:
                                logger.error(f"    ❌ КРИТИЧЕСКАЯ ОШИБКА: Шрифт с кириллицей не зарегистрирован!")
                            
                            c.setFillColor(black)
                            
                            # Динамический размер шрифта с переносом текста
                            font_size = 16
                            max_width = page_width - 50  # Отступы слева и справа по 25pt
                            padding_x = 25
                            padding_y = 15
                            
                            # Пробуем разные размеры шрифта
                            for test_size in [16, 14, 12, 10]:
                                c.setFont(font_name, test_size)
                                words = scene_text.split()
                                lines = []
                                current_line = ""
                                
                                for word in words:
                                    test_line = current_line + " " + word if current_line else word
                                    if c.stringWidth(test_line, font_name, test_size) <= max_width:
                                        current_line = test_line
                                    else:
                                        if current_line:
                                            lines.append(current_line)
                                        current_line = word
                                
                                if current_line:
                                    lines.append(current_line)
                                
                                # Проверяем, помещается ли текст в text_area_height
                                line_height = test_size * 1.3
                                total_height = len(lines) * line_height + padding_y * 2
                                
                                if total_height <= text_area_height:
                                    font_size = test_size
                                    break
                            
                            # Если всё равно не помещается, обрезаем строки
                            if total_height > text_area_height:
                                max_lines = int((text_area_height - padding_y * 2) / line_height)
                                lines = lines[:max_lines]
                                if len(lines) > 0:
                                    lines[-1] = lines[-1][:50] + "..."  # Обрезаем последнюю строку
                            
                            c.setFont(font_name, font_size)
                            
                            # Центрируем текст вертикально в нижней 1/4 части
                            total_text_height = len(lines) * line_height
                            start_y = (text_area_height - total_text_height) / 2 + padding_y
                            
                            # Рисуем текст
                            y = start_y
                            for line in lines:
                                text_width = c.stringWidth(line, font_name, font_size)
                                x = (page_width - text_width) / 2  # Центрируем горизонтально
                                c.drawString(x, y, line)
                                y += line_height
                            
                            logger.info(f"    📝 Текст нарисован: {len(lines)} строк, размер шрифта {font_size}")
                        else:
                            logger.warning(f"    ⚠️ Сцена {page.order}: текст отсутствует или отфильтрован")
                        
                        logger.info(f"    Story страница нарисована")
                except Exception as e:
                    logger.error(f"    ❌ Ошибка при обработке страницы {page.order}: {e}")
        
        c.save()
        logger.info(f"✅ PDF сохранен: {pdf_path}")
        
        logger.info(f"✅ PDF создан: {pdf_path}")
        
        # Получаем публичный URL
        base_url = get_server_base_url()
        pdf_url = f"{base_url}/static/books/{book.id}/final.pdf"
        
        # Сохраняем в БД
        book.final_pdf_url = pdf_url
        book.images_final = {"images": final_images_data}
        # НЕ меняем статус здесь - он будет установлен в эндпоинте финализации
        # book.status = "completed"  # Убрано - статус устанавливается в finalize_book
        db.commit()
        
        logger.info("=" * 70)
        logger.info("🎉 PDF ФАЙЛ УСПЕШНО СОЗДАН!")
        logger.info("=" * 70)
        logger.info(f"📄 URL: {pdf_url}")
        logger.info(f"🌐 Полный URL: https://storyhero.ru{pdf_url if pdf_url.startswith('/') else '/' + pdf_url}")
        logger.info("=" * 70)
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации PDF: {e}", exc_info=True)
        db.rollback()
        return 1
        
    finally:
        db.close()


if __name__ == "__main__":
    try:
        # Поддерживаем book_id как аргумент командной строки
        book_id = sys.argv[1] if len(sys.argv) > 1 else None
        if book_id:
            logger.info(f"📚 Генерация PDF для книги: {book_id}")
        exit_code = asyncio.run(generate_pdf(book_id))
        sys.exit(exit_code)
    except KeyboardInterrupt:
        logger.info("\n⚠️ Генерация PDF прервана пользователем")
        sys.exit(1)
    except Exception as e:
        logger.error(f"❌ Критическая ошибка: {e}", exc_info=True)
        sys.exit(1)

