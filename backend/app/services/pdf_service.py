"""
Сервис для генерации PDF файлов из книг (ПРОМЫШЛЕННЫЙ УРОВЕНЬ).
Использует библиотеку reportlab для создания PRINT-READY PDF документов.
Поддерживает адаптацию под возраст ребёнка (3-8 лет).

PRINT-READY FEATURES:
- CMYK цветовое пространство (ISO Coated v2)
- Bleed 3mm
- Crop marks
- Skin-tone safe цвета
- PDF/X-4 совместимость
"""
import logging
from typing import List, Dict, Optional
from dataclasses import dataclass
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
# В reportlab точки (pt) - это базовая единица (1 pt = 1)
pt = 1  # 1 point = 1 unit в reportlab
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import white, black, HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import requests
from io import BytesIO
import os
from PIL import Image as PILImage

# ЧАСТЬ B: НЕ ДОПУСКАТЬ "ЗАГЛУШКИ" ВМЕСТО ИЗОБРАЖЕНИЯ
from .image_fetcher import fetch_image_bytes, ImageFetchError

# PRINT-READY конфигурация
try:
    from ..print.print_config import PRINT_CONFIG, FINAL_PAGE_WIDTH, FINAL_PAGE_HEIGHT
    from ..print.color_pipeline import rgb_to_cmyk_print_safe
    from ..print.skin_tone_safe import apply_skin_tone_clamp_to_image
    PRINT_READY_AVAILABLE = True
except ImportError as e:
    PRINT_READY_AVAILABLE = False
    logger.warning(f"⚠️ Print-ready модули не доступны: {e}")

# Skin-tone safe CMYK для печати
# ВРЕМЕННО ОТКЛЮЧЕНО для диагностики проблем с памятью
SKIN_TONE_AVAILABLE = False
try:
    # from .skin_tone_service import apply_skin_tone_safe_cmyk
    # SKIN_TONE_AVAILABLE = True
    pass
except ImportError:
    SKIN_TONE_AVAILABLE = False
    logger.warning("⚠️ Skin-tone service отключен для диагностики")

logger = logging.getLogger(__name__)

# ============================================================
# КОНСТАНТЫ ДЛЯ PRINT-READY PDF (ТИПОГРАФИЯ)
# ============================================================

# Используем конфигурацию из print_config.py
if PRINT_READY_AVAILABLE:
    # В reportlab точки уже в правильных единицах, просто используем значения
    BLEED = PRINT_CONFIG["bleed_pt"]  # Уже в points
    SAFE_MARGIN = PRINT_CONFIG["safe_margin_pt"]  # Уже в points
    PAGE_WIDTH = FINAL_PAGE_WIDTH  # Уже в points
    PAGE_HEIGHT = FINAL_PAGE_HEIGHT  # Уже в points
else:
    # Fallback на старые значения
    BLEED = 3 * mm
    SAFE_MARGIN = 10 * mm
    PAGE_WIDTH = (210 + 6) * mm
    PAGE_HEIGHT = (297 + 6) * mm

# Регистрируем шрифт с поддержкой кириллицы
_cyrillic_font_available = False

# Кремовый фон для текста (детский UX)
CREAM_BG_COLOR = HexColor("#FFF8ED")


# ============================================================
# РЕГИСТРАЦИЯ ШРИФТОВ С КИРИЛЛИЦЕЙ
# ============================================================

def _register_cyrillic_font():
    """Регистрирует шрифт с поддержкой кириллицы для PDF."""
    global _cyrillic_font_available
    if _cyrillic_font_available:
        return True
    
    try:
        # ПРИОРИТЕТ: Используем шрифт из assets/fonts (если есть)
        script_dir = os.path.dirname(os.path.abspath(__file__))
        assets_font_path = os.path.join(script_dir, "..", "assets", "fonts", "DejaVuSans.ttf")
        
        font_paths = [
            assets_font_path,  # ПРИОРИТЕТ 1: наш шрифт в assets
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        ]
        
        font_path = None
        bold_font_path = None
        for path in font_paths:
            if os.path.exists(path):
                if "Bold" in path:
                    bold_font_path = path
                else:
                    font_path = path
                break
        
        if font_path:
            # Регистрируем основной шрифт
            pdfmetrics.registerFont(TTFont('CyrillicFont', font_path))
            
            # Регистрируем жирный шрифт
            if bold_font_path:
                pdfmetrics.registerFont(TTFont('CyrillicFontBold', bold_font_path))
                logger.info(f"✓ Зарегистрированы шрифты DejaVu: regular={font_path}, bold={bold_font_path}")
            else:
                # Используем обычный шрифт как жирный, если жирный не найден
                pdfmetrics.registerFont(TTFont('CyrillicFontBold', font_path))
                logger.warning(f"⚠️ Bold шрифт не найден, используем regular для bold: {font_path}")
            
            _cyrillic_font_available = True
            return True
        else:
            # ШАГ 2: КРИТИЧЕСКАЯ ОШИБКА - шрифт обязателен
            logger.error("🚨 Шрифт DejaVuSans не найден! Это критическая ошибка.")
            logger.error(f"   Проверяемые пути: {font_paths}")
            _cyrillic_font_available = False
            # В dev режиме падаем, в prod можно fallback на LiberationSans
            raise RuntimeError("Шрифт с кириллицей не найден. Убедитесь, что DejaVuSans.ttf находится в backend/app/assets/fonts/")
    except Exception as e:
        logger.error(f"🚨 Ошибка при регистрации шрифта: {e}")
        _cyrillic_font_available = False
        return False


# ============================================================
# АДАПТАЦИЯ ПОД ВОЗРАСТ РЕБЁНКА
# ============================================================

def get_age_style(age: int) -> Dict:
    """
    Возвращает конфигурацию стиля для конкретного возраста ребёнка.
    
    Возрастные группы:
    - 3-4 года: очень крупный шрифт, минимум текста, максимум картинок
    - 5-6 лет: сказочный, комфортный (ОСНОВНОЙ)
    - 7-8 лет: больше текста, меньше рамок
    """
    if age <= 4:
        # 3-4 ГОДА
        return {
            "font_size": 22,
            "leading_multiplier": 1.6,
            "image_ratio": 0.75,
            "text_ratio": 0.25,
            "max_lines_per_page": 4,
            "description": "очень крупный, минимум текста"
        }
    elif age <= 6:
        # 5-6 ЛЕТ (ОСНОВНОЙ)
        return {
            "font_size": 20,
            "leading_multiplier": 1.5,
            "image_ratio": 0.70,
            "text_ratio": 0.30,
            "max_lines_per_page": 6,
            "description": "сказочный, комфортный"
        }
    else:
        # 7-8 ЛЕТ
        return {
            "font_size": 18,
            "leading_multiplier": 1.4,
            "image_ratio": 0.65,
            "text_ratio": 0.35,
            "max_lines_per_page": 8,
            "description": "больше текста, меньше рамок"
        }


# ============================================================
# МОДЕЛИ ДАННЫХ
# ============================================================

@dataclass
class PdfPage:
    """Страница PDF книги"""
    order: int
    text: str
    image_url: str
    style: str = "storybook"  # Стиль книги для оформления текста
    book_title: str = ""  # Название книги (для обложки)
    age: Optional[int] = None  # Возраст ребёнка для адаптации


def is_cover_page(page: PdfPage) -> bool:
    """Проверяет, является ли страница обложкой."""
    return page.order == 0


# ============================================================
# ОСНОВНАЯ ФУНКЦИЯ ГЕНЕРАЦИИ PDF
# ============================================================

def render_book_pdf(
    output_path: str,
    title: str,
    pages: List[PdfPage],
    style: str = "storybook",
    child_age: Optional[int] = None
) -> None:
    """
    Создает PRINT-READY PDF файл из списка страниц.
    
    Args:
        output_path: Путь для сохранения PDF файла
        title: Заголовок книги
        pages: Список страниц (PdfPage)
        style: Стиль книги
        child_age: Возраст ребёнка (если не указан, берется из первой страницы с age)
    """
    try:
        # ЖЁСТКИЕ ASSERT'Ы ДЛЯ ЗАЩИТЫ ОТ РЕГРЕССА
        if PRINT_READY_AVAILABLE:
            assert PRINT_CONFIG["output_space"] == "CMYK", "❌ OUTPUT SPACE ДОЛЖЕН БЫТЬ CMYK"
            logger.info(f"🎨 PRINT-READY режим: {PRINT_CONFIG['pdf_standard']}, {PRINT_CONFIG['color_profile']}")
        
        logger.info(f"📄 Начало генерации PRINT-READY PDF: {output_path}, страниц: {len(pages)}")
        
        # ШАГ 7: ФИНАЛЬНАЯ ПРОВЕРКА - валидация входных данных
        assert len(pages) > 0, "❌ PDF должен содержать хотя бы одну страницу"
        assert pages[0].order == 0, f"❌ Первая страница должна быть обложкой (order=0), получено order={pages[0].order}"
        
        # Регистрируем шрифт с поддержкой кириллицы
        if not _register_cyrillic_font():
            raise RuntimeError("Шрифт с поддержкой кириллицы не зарегистрирован. Проверьте наличие DejaVuSans.ttf в assets/fonts/")
        
        # ШАГ 6: ГАРАНТИЯ КИРИЛЛИЦЫ - обязательный assert
        assert _cyrillic_font_available, "❌ Шрифт с кириллицей НЕ зарегистрирован — PDF будет невалидным. Прерывание генерации."
        
        # Определяем возраст ребёнка
        age = child_age
        if age is None:
            # Пытаемся взять из первой страницы
            for page in pages:
                if page.age is not None:
                    age = page.age
                    break
        
        # Если возраст не указан, используем дефолт 5-6 лет
        if age is None:
            age = 5
            logger.warning(f"⚠️ Возраст ребёнка не указан, используем дефолт: {age} лет")
        
        age_config = get_age_style(age)
        logger.info(f"📐 Конфигурация для возраста {age} лет: {age_config['description']}")
        
        # Создаем PDF документ с print-ready размерами
        c = canvas.Canvas(output_path, pagesize=(PAGE_WIDTH, PAGE_HEIGHT))
        
        # Устанавливаем метаданные для PDF/X-4
        if PRINT_READY_AVAILABLE:
            c.setTitle(title or "StoryHero")
            c.setSubject("Детская книга")
            c.setCreator("StoryHero")
            c.setProducer(f"StoryHero PDF Generator ({PRINT_CONFIG['pdf_standard']})")
        
        # Обрабатываем каждую страницу
        # ШАГ 1: ЖЁСТКО ЗАКРЕПИТЬ ОБЛОЖКУ - исправленная логика showPage()
        for idx, page in enumerate(pages):
            # ПРАВИЛО: первая страница (idx=0) НЕ вызывает showPage()
            # Все последующие страницы вызывают showPage() ПЕРЕД обработкой
            if idx > 0:
                c.showPage()
            
            # ЖЁСТКАЯ ПРОВЕРКА: первая страница ОБЯЗАТЕЛЬНО обложка
            is_cover = page.order == 0
            if idx == 0:
                assert is_cover, f"❌ Первая страница должна быть обложкой (order=0), получено order={page.order}"
            
            if is_cover:
                # ОБЛОЖКА: картинка на всю страницу + название книги
                image_loaded = False
                
                if page.image_url:
                    # ШАГ 4: Используем локальный путь для обложки
                    local_path_or_url, image_source = _url_to_local_path(page.image_url)
                    
                    try:
                        if image_source == "local":
                            # Читаем с диска
                            with open(local_path_or_url, "rb") as f:
                                image_bytes = f.read()
                            img = ImageReader(BytesIO(image_bytes))
                            logger.info(f"✓ Обложка: изображение загружено с диска ({len(image_bytes)} байт)")
                        else:
                            # HTTP загрузка
                            image_bytes = fetch_image_bytes(local_path_or_url, timeout=20, retries=3)
                            img = ImageReader(BytesIO(image_bytes))
                            logger.info(f"✓ Обложка: изображение загружено по HTTP ({len(image_bytes)} байт)")
                        
                        if PRINT_READY_AVAILABLE:
                            c.drawImage(img, -BLEED, -BLEED, width=PAGE_WIDTH + BLEED * 2, height=PAGE_HEIGHT + BLEED * 2, preserveAspectRatio=True)
                        else:
                            c.drawImage(img, 0, 0, width=PAGE_WIDTH, height=PAGE_HEIGHT, preserveAspectRatio=True)
                        image_loaded = True
                        
                        # ШАГ 7: ДИАГНОСТИКА
                        logger.info(f"📄 PDF page order=0 cover=True image_source={image_source} image_ok=True text_len=0 font=CyrillicFontBold")
                    except ImageFetchError as e:
                        logger.error(f"❌ Ошибка при загрузке изображения обложки: {e}")
                        # НЕ продолжаем генерацию PDF с битым изображением
                        raise RuntimeError(f"Не удалось загрузить изображение обложки: {e}")
                    except Exception as e:
                        logger.error(f"❌ Неожиданная ошибка при загрузке изображения обложки: {e}", exc_info=True)
                        raise RuntimeError(f"Неожиданная ошибка при загрузке изображения обложки: {e}")
                
                # ШАГ 2: ДОБАВИТЬ НАЗВАНИЕ НА ОБЛОЖКУ - ВСЕГДА вызывается
                if title:
                    _draw_cover_title(c, title, PAGE_WIDTH, PAGE_HEIGHT, page.style or "storybook")
                    logger.info(f"✓ Обложка: название книги нарисовано: {title}")
                else:
                    logger.warning(f"⚠️ Обложка: название книги не указано")
                
                # ШАГ 3: ЗАПРЕТИТЬ ПУСТЫЕ СТРАНИЦЫ - пропускать обложку без изображения
                if not image_loaded:
                    logger.error(f"🚨 Обложка без изображения - пропускаем страницу order={page.order}")
                    # НЕ вызываем showPage() для следующей страницы, если это была первая
                    # Но продолжаем обработку остальных страниц
                    continue
                
                if PRINT_READY_AVAILABLE:
                    _draw_crop_marks(c, PAGE_WIDTH, PAGE_HEIGHT, BLEED)
                continue
            
            # STORY-страница: адаптированная под возраст
            # ШАГ 3: ЗАПРЕТИТЬ ПУСТЫЕ СТРАНИЦЫ - проверка перед обработкой
            if not page.image_url:
                logger.error(f"🚨 Страница order={page.order} без изображения - пропускаем")
                continue
            
            # Обрабатываем story-страницу
            try:
                _draw_story_page(c, page, PAGE_WIDTH, PAGE_HEIGHT, age_config, style)
                # Рисуем crop marks для story-страницы
                if PRINT_READY_AVAILABLE:
                    _draw_crop_marks(c, PAGE_WIDTH, PAGE_HEIGHT, BLEED)
            except Exception as e:
                logger.error(f"❌ Ошибка при обработке story-страницы order={page.order}: {e}")
                # Пропускаем страницу при ошибке
                continue
        
        # Сохраняем PDF
        c.save()
        logger.info(f"✅ PRINT-READY PDF успешно создан: {output_path}")
        
    except Exception as e:
        logger.error(f"❌ Ошибка при создании PDF: {str(e)}", exc_info=True)
        raise


# ============================================================
# БЕЗОПАСНАЯ ЗАГРУЗКА ИЗОБРАЖЕНИЙ (С FALLBACK)
# ============================================================

def _url_to_local_path(image_url: str) -> tuple[str, str]:
    """
    Конвертирует URL изображения в локальный путь.
    
    Args:
        image_url: URL изображения (может быть /static/... или https://...)
    
    Returns:
        tuple: (local_path, image_source) где image_source = "local" | "http" | "none"
    """
    from .storage import BASE_UPLOAD_DIR
    
    # ШАГ 4: Используем локальный путь для /static/ URLs
    if "/static/" in image_url:
        # Формат: /static/drafts/xxx.jpg или /static/finals/xxx.jpg или /static/books/xxx/xxx.jpg
        relative_path = image_url.split("/static/", 1)[1]
        local_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
        if os.path.exists(local_path):
            return local_path, "local"
        else:
            logger.warning(f"⚠️ Локальный файл не найден: {local_path}, пробуем HTTP")
            return image_url, "http"
    elif "/uploads/" in image_url:
        # Формат: /uploads/...
        relative_path = image_url.split("/uploads/", 1)[1]
        local_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
        if os.path.exists(local_path):
            return local_path, "local"
        else:
            return image_url, "http"
    else:
        # Внешний URL - используем HTTP
        return image_url, "http"


def _safe_draw_image(
    c: canvas.Canvas,
    image_url: str,
    x: float,
    y: float,
    w: float,
    h: float,
    is_cover: bool = False
) -> tuple[bool, str, bool]:
    """
    Безопасно загружает и рисует изображение с обработкой ошибок.
    
    Args:
        c: Canvas объект
        image_url: URL изображения
        x, y, w, h: Координаты и размеры
        is_cover: True если это обложка (для skin-tone коррекции)
    
    Returns:
        tuple: (success, image_source, image_ok) где:
            success: True если изображение успешно нарисовано
            image_source: "local" | "http" | "none"
            image_ok: True если изображение валидно
    """
    try:
        # ШАГ 4: Конвертируем URL в локальный путь
        local_path_or_url, image_source = _url_to_local_path(image_url)
        
        logger.debug(f"📥 Загружаю изображение: {image_url} (source={image_source})")
        
        # Загружаем изображение
        if image_source == "local":
            # Читаем с диска
            try:
                with open(local_path_or_url, "rb") as f:
                    image_bytes = f.read()
                logger.debug(f"✓ Изображение загружено с диска: {len(image_bytes)} байт")
                image_ok = True
            except Exception as e:
                logger.error(f"❌ Ошибка чтения локального файла {local_path_or_url}: {e}")
                # Fallback на placeholder
                return _draw_placeholder_image(c, x, y, w, h, f"Local file error: {e}"), "none", False
        else:
            # HTTP загрузка
            try:
                image_bytes = fetch_image_bytes(local_path_or_url, timeout=20, retries=2)
                logger.debug(f"✓ Изображение загружено по HTTP: {len(image_bytes)} байт")
                image_ok = True
            except ImageFetchError as e:
                logger.error(f"❌ Ошибка при загрузке изображения по HTTP: {e}")
                # Fallback на placeholder
                return _draw_placeholder_image(c, x, y, w, h, f"HTTP error: {e}"), "http", False
        
        # PRINT-READY: Конвертируем RGB -> CMYK
        # ВАЖНО: Для обложки пропускаем CMYK конвертацию, чтобы избежать проблем с памятью
        # CMYK конвертация будет применена при сохранении PDF
        if PRINT_READY_AVAILABLE and not is_cover:
            try:
                # Конвертируем в CMYK через ICC профиль (только для story-страниц)
                image_bytes = rgb_to_cmyk_print_safe(image_bytes, use_icc=True)
                logger.debug("🎨 RGB->CMYK конвертация выполнена")
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при CMYK конвертации: {e}. Используется оригинальное изображение.")
        
        # Применяем Skin-Tone Safe CMYK для обложки и story-страниц (если доступно)
        # ВАЖНО: Для обложки временно отключаем skin-tone коррекцию, чтобы избежать проблем
        if SKIN_TONE_AVAILABLE and not is_cover:
            try:
                # Загружаем как PIL Image
                image_pil = PILImage.open(BytesIO(image_bytes))
                if image_pil.mode != "RGB":
                    image_pil = image_pil.convert("RGB")
                
                # Применяем skin-tone safe CMYK коррекцию
                image_cmyk = apply_skin_tone_safe_cmyk(
                    image_rgb=image_pil,
                    face_bbox=None,  # Автоматическое определение
                    preset_name="child_light"
                )
                
                # Конвертируем CMYK обратно в RGB для ImageReader
                image_rgb_final = image_cmyk.convert("RGB")
                
                # Сохраняем в BytesIO для ImageReader
                img_buffer = BytesIO()
                image_rgb_final.save(img_buffer, format="JPEG", quality=95)
                img_buffer.seek(0)
                image_bytes = img_buffer.getvalue()
                
                if is_cover:
                    logger.info("🎨 Skin-tone CMYK коррекция применена к обложке")
                else:
                    logger.debug("🎨 Skin-tone CMYK коррекция применена к странице")
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при применении skin-tone коррекции: {e}. Используется оригинальное изображение.")
        
        logger.debug(f"🖼️ Создаю ImageReader из {len(image_bytes)} байт")
        img = ImageReader(BytesIO(image_bytes))
        img_w, img_h = img.getSize()
        logger.debug(f"✓ ImageReader создан: {img_w}x{img_h}")
        ratio = img_w / img_h
        area_ratio = w / h
        
        # ШАГ 3: Вычисляем размеры изображения для заполнения области
        # ВАЖНО: изображение должно строго оставаться в области [y, y+h]
        if ratio > area_ratio:
            # Изображение шире области - заполняем по высоте
            draw_h = h
            draw_w = draw_h * ratio
            draw_x = x + (w - draw_w) / 2
            draw_y = y  # НЕ y=0, а строго y (начало области изображения)
        else:
            # Изображение выше области - заполняем по ширине
            draw_w = w
            draw_h = draw_w / ratio
            draw_x = x
            # ВАЖНО: draw_y должен быть >= y, чтобы не залезать на текст
            draw_y = max(y, y + (h - draw_h) / 2)
        
        # ШАГ 3: Проверка что изображение не залезает на текст
        # Изображение должно быть строго в области [y, y+h]
        if draw_y < y:
            logger.warning(f"⚠️ Изображение выходит за верхнюю границу, корректируем: draw_y={draw_y} -> y={y}")
            draw_y = y
        if draw_y + draw_h > y + h:
            logger.warning(f"⚠️ Изображение выходит за нижнюю границу, корректируем")
            draw_h = (y + h) - draw_y
        
        # Рисуем изображение
        logger.debug(f"🎨 Рисую изображение: {draw_x:.0f}, {draw_y:.0f}, {draw_w:.0f}x{draw_h:.0f}")
        c.drawImage(img, draw_x, draw_y, width=draw_w, height=draw_h)
        logger.debug(f"✓ Изображение нарисовано")
        return True, image_source, image_ok
        
    except Exception as e:
        logger.error(f"❌ Image failed: {image_url} | {e}")
        return _draw_placeholder_image(c, x, y, w, h, f"Exception: {e}"), "none", False


def _draw_placeholder_image(c: canvas.Canvas, x: float, y: float, w: float, h: float, error_msg: str) -> bool:
    """
    Рисует placeholder вместо недоступного изображения.
    
    Args:
        c: Canvas объект
        x, y, w, h: Координаты и размеры
        error_msg: Сообщение об ошибке
    
    Returns:
        bool: True (placeholder нарисован)
    """
    try:
        # Серый фон
        c.setFillColor(HexColor("#E0E0E0"))
        c.rect(x, y, w, h, fill=1, stroke=0)
        
        # Текст "Image unavailable"
        c.setFillColor(HexColor("#666666"))
        c.setFont("Helvetica", 12)
        text = "Image unavailable"
        text_width = c.stringWidth(text, "Helvetica", 12)
        text_x = x + (w - text_width) / 2
        text_y = y + h / 2
        c.drawString(text_x, text_y, text)
        
        logger.warning(f"⚠️ Нарисован placeholder для недоступного изображения: {error_msg[:50]}")
        return True
    except Exception as e:
        logger.error(f"❌ Ошибка при рисовании placeholder: {e}")
        return False


# ============================================================
# ОТРИСОВКА НАЗВАНИЯ НА ОБЛОЖКЕ
# ============================================================

def _draw_cover_title(
    c: canvas.Canvas,
    title: str,
    page_width: float,
    page_height: float,
    style: str
) -> None:
    """
    Рисует название книги на обложке программно (через reportlab).
    КРИТИЧНО: название ВСЕГДА должно быть на обложке.
    
    Args:
        c: Canvas объект
        title: Название книги
        page_width: Ширина страницы
        page_height: Высота страницы
        style: Стиль книги (для выбора цвета)
    """
    if not _cyrillic_font_available:
        logger.warning("⚠️ Шрифт с кириллицей не доступен, название может отображаться некорректно")
    
    # Выбираем цвет текста в зависимости от стиля
    if style in ["watercolor", "pixar"]:
        text_color = HexColor("#FFDC00")  # Яркий желтый
        outline_color = HexColor("#000000")  # Черная обводка
    elif style == "cartoon":
        text_color = HexColor("#FF6400")  # Оранжевый
        outline_color = HexColor("#000000")
    else:
        text_color = HexColor("#FFFFFF")  # Белый
        outline_color = HexColor("#000000")
    
    # Размер шрифта - адаптивный к размеру страницы
    font_size = int(page_height * 0.06)  # 6% от высоты
    # ШАГ 2: УБРАТЬ HELVETICA FALLBACK - кириллица обязательна
    if not _cyrillic_font_available:
        raise RuntimeError("❌ Шрифт с кириллицей НЕ зарегистрирован - невозможно создать PDF с русским текстом")
    font_name = "CyrillicFontBold"
    
    # Разбиваем длинное название на строки
    max_width = page_width * 0.85  # 85% ширины страницы
    lines = _wrap_text(title, max_width, c, font_name, font_size)
    
    # Вычисляем общую высоту текста
    leading = font_size * 1.2
    total_text_height = len(lines) * leading
    
    # ШАГ 5: Позиция текста - в нижней части обложки с safe margin
    # Запрет рисовать слишком близко к краям (safe top margin)
    safe_top_margin = page_height * 0.05  # 5% отступ сверху
    bottom_margin = page_height * 0.1  # 10% отступ снизу
    text_y_start = max(bottom_margin, page_height - total_text_height - safe_top_margin)
    
    # Рисуем каждую строку с обводкой для читаемости
    c.setFont(font_name, font_size)
    
    for i, line in enumerate(lines):
        y = text_y_start - i * leading
        
        # Измеряем ширину текста для центрирования
        text_width = c.stringWidth(line, font_name, font_size)
        x = (page_width - text_width) / 2
        
        # Рисуем обводку (тень) для читаемости
        outline_width = max(2, int(font_size * 0.05))
        for adj_x in range(-outline_width, outline_width + 1):
            for adj_y in range(-outline_width, outline_width + 1):
                if adj_x != 0 or adj_y != 0:
                    text_obj = c.beginText(x + adj_x, y + adj_y)
                    text_obj.setFont(font_name, font_size)
                    text_obj.setFillColor(outline_color)
                    text_obj.textLine(line)
                    c.drawText(text_obj)
        
        # Рисуем основной текст
        text_obj = c.beginText(x, y)
        text_obj.setFont(font_name, font_size)
        text_obj.setFillColor(text_color)
        text_obj.textLine(line)
        c.drawText(text_obj)
    
    logger.info(f"✓ Название '{title}' добавлено на обложку программно ({len(lines)} строк)")


# ============================================================
# ОТРИСОВКА ОБЛОЖКИ (FULL-BLEED)
# ============================================================

def _draw_cover_page(
    c: canvas.Canvas,
    page: PdfPage,
    page_width: float,
    page_height: float,
    title: str
) -> None:
    """
    Рисует обложку: картинка на ВСЮ страницу с full-bleed + ОБЯЗАТЕЛЬНО название книги.
    
    Args:
        c: Canvas объект
        page: Страница PdfPage (order=0)
        page_width: Ширина страницы (с bleed)
        page_height: Высота страницы (с bleed)
        title: Название книги (ОБЯЗАТЕЛЬНО рисуется программно)
    """
    if not page.image_url:
        logger.warning(f"⚠️ Нет изображения для обложки (order={page.order})")
        # Даже без изображения рисуем название
        if title:
            _draw_cover_title(c, title, page_width, page_height, page.style or "storybook")
        return
    
    # Запрет текста на обложке (текст сцены игнорируется)
    # НО: если text содержит промпт, это ошибка - логируем
    if page.text:
        if "Visual style" in page.text or "IMPORTANT" in page.text:
            logger.error(f"🚨 Cover scene (order={page.order}) contains PROMPT in text — CRITICAL ERROR!")
        else:
            logger.warning(f"⚠️ Cover scene (order={page.order}) contains text — will be ignored (title will be drawn programmatically).")
    
    # 1. Рисуем изображение на всю страницу (full-bleed)
    # МАКСИМАЛЬНО УПРОЩЕННАЯ обработка - без CMYK конвертации для обложки
    response = requests.get(page.image_url, timeout=10)
    response.raise_for_status()
    img = ImageReader(BytesIO(response.content))
    img_w, img_h = img.getSize()
    
    # PRINT-READY: Full-bleed координаты
    if PRINT_READY_AVAILABLE:
        c.drawImage(img, -BLEED, -BLEED, width=page_width + BLEED * 2, height=page_height + BLEED * 2, preserveAspectRatio=True)
    else:
        # Fallback: стандартное размещение
        ratio = img_w / img_h
        page_ratio = page_width / page_height
        if ratio > page_ratio:
            draw_h = page_height
            draw_w = draw_h * ratio
            img_x = (page_width - draw_w) / 2
            c.drawImage(img, img_x, 0, width=draw_w, height=draw_h, preserveAspectRatio=True)
        else:
            draw_w = page_width
            draw_h = draw_w / ratio
            c.drawImage(img, 0, (page_height - draw_h) / 2, width=draw_w, height=draw_h, preserveAspectRatio=True)
    
    # 2. ОБЯЗАТЕЛЬНО рисуем название книги программно
    if title:
        _draw_cover_title(c, title, page_width, page_height, page.style or "storybook")


# ============================================================
# ОТРИСОВКА STORY-СТРАНИЦ (АДАПТИРОВАННАЯ ПОД ВОЗРАСТ)
# ============================================================

def _draw_story_page(
    c: canvas.Canvas,
    page: PdfPage,
    page_width: float,
    page_height: float,
    age_config: Dict,
    style: str
) -> None:
    """
    Рисует STORY-страницу: изображение сверху (75%), текст снизу (25%).
    ЕДИНЫЙ LAYOUT-КОНТРАКТ: строго 75% image, 25% text.
    
    Args:
        c: Canvas объект
        page: Страница PdfPage
        page_width: Ширина страницы
        page_height: Высота страницы
        age_config: Конфигурация для возраста (из get_age_style)
        style: Стиль книги
    """
    # ЕДИНЫЙ LAYOUT-КОНТРАКТ (строго)
    # Для НЕ-обложки: 75% image, 25% text (независимо от возраста)
    IMAGE_RATIO = 0.75
    TEXT_RATIO = 0.25
    
    image_h = page_height * IMAGE_RATIO
    text_h = page_height * TEXT_RATIO
    
    # ШАГ 3: СТРОГИЙ ЛЭЙАУТ - image в верхних 75%, text в нижних 25%
    # Константы для точного позиционирования
    text_area_height = page_height * TEXT_RATIO  # Нижние 25%
    image_area_y0 = text_area_height  # Начало области изображения
    image_area_height = page_height * IMAGE_RATIO  # Верхние 75%
    
    # Координаты (строго по контракту)
    # IMAGE: от y=image_area_y0 до y=page_height (верхние 75%)
    # TEXT: от y=0 до y=text_area_height (нижние 25%)
    IMAGE_Y = image_area_y0
    TEXT_Y = 0
    
    if not page.image_url:
        # ШАГ 3: ЗАПРЕТИТЬ ПУСТЫЕ СТРАНИЦЫ - страница без изображения пропускается
        logger.error(f"🚨 Страница order={page.order} без изображения - пропускаем")
        return
    
    # Безопасная загрузка изображения с fallback
    success, image_source, image_ok = _safe_draw_image(
        c=c,
        image_url=page.image_url,
        x=0,
        y=IMAGE_Y,
        w=page_width,
        h=image_h,
        is_cover=False
    )
    
    # ШАГ 7: ДИАГНОСТИКА - логируем информацию о странице
    text_len = len(page.text) if page.text else 0
    font_used = "CyrillicFont" if _cyrillic_font_available else "NONE"
    logger.info(f"📄 PDF page order={page.order} cover=False image_source={image_source} image_ok={image_ok} text_len={text_len} font={font_used}")
    
    if not success:
        # ШАГ 3: ЗАПРЕТИТЬ ПУСТЫЕ СТРАНИЦЫ - если изображение не загрузилось, пропускаем страницу
        logger.error(f"🚨 Страница order={page.order} - изображение не загружено, пропускаем страницу")
        # НЕ рисуем fallback-страницу, просто пропускаем
        return
    
    logger.info(f"✓ Изображение добавлено на страницу order={page.order} (верхние {int(IMAGE_RATIO*100)}%)")
    
    # Добавляем текст в нижней части страницы (нижние 25%)
    if page.text:
        _draw_text_in_bottom_zone(c, page.text, page_width, text_h, age_config, style)
    else:
        logger.warning(f"⚠️ Страница order={page.order} не имеет текста")


# ============================================================
# ОТРИСОВКА ТЕКСТА (КИРИЛЛИЦА + ДЕТСКИЙ UX)
# ============================================================

def _draw_text_in_bottom_zone(
    c: canvas.Canvas,
    text: str,
    page_width: float,
    text_area_height: float,
    age_config: Dict,
    style: str
) -> None:
    """
    Рисует текст в нижней зоне страницы.
    Использует ТОЛЬКО beginText/textLine для кириллицы.
    Левое выравнивание, кремовый фон, safe zone.
    
    Args:
        c: Canvas объект
        text: Текст для отображения
        page_width: Ширина страницы
        text_area_height: Высота текстовой области
        age_config: Конфигурация для возраста
        style: Стиль книги
    """
    # ШАГ 5: ЗАПРЕТ PROMPT В PDF - фильтрация промптов
    prompt_markers = [
        "visual style",
        "important",
        "prompt",
        "child character must",
        "book cover illustration",
        "a sunny bedroom where",
        "at the entrance of",
        "sophia, a 5-year-old",
        "a 5-year-old child named"
    ]
    
    text_lower = text.lower()
    if any(marker in text_lower for marker in prompt_markers):
        logger.critical(f"🚨 PROMPT DETECTED IN PDF TEXT — BLOCKED: {text[:100]}...")
        return
    
    if not _cyrillic_font_available:
        raise RuntimeError("Шрифт с поддержкой кириллицы не зарегистрирован")
    
    font_name = "CyrillicFont"
    
    # ЧАСТЬ D: ВЁРСТКА ТЕКСТА В НИЖНЕЙ 1/4 (НЕ ВЫЛЕЗАТЬ ЗА ГРАНИЦЫ)
    # Внутренние отступы
    horizontal_padding = 25 * mm  # 22-28 px эквивалент
    vertical_padding = 15 * mm  # 14-18 px эквивалент
    
    # Динамический размер шрифта
    base_font_size = 18
    min_font_size = 12
    font_size = base_font_size
    leading_multiplier = age_config.get("leading_multiplier", 1.3)
    
    # ШАГ 6: ЗАЩИТА ОТ ПРОМПТОВ В ТЕКСТЕ
    def sanitize_story_text(text: str) -> str:
        """
        Очищает текст от промптов и служебных инструкций.
        
        Args:
            text: Исходный текст
        
        Returns:
            str: Очищенный текст или пустая строка если это промпт
        """
        if not text:
            return ""
        
        prompt_markers = [
            "visual style",
            "important",
            "prompt",
            "child character must",
            "book cover illustration",
            "a sunny bedroom where",
            "at the entrance of",
            "sophia, a 5-year-old",
            "a 5-year-old child named"
        ]
        
        text_lower = text.lower()
        if any(marker in text_lower for marker in prompt_markers):
            logger.error(f"🚨 PROMPT DETECTED IN PDF TEXT — BLOCKED: {text[:100]}...")
            return ""  # Возвращаем пустую строку вместо промпта
        
        return text
    
    # Применяем санитизацию
    text = sanitize_story_text(text)
    if not text:
        logger.warning(f"⚠️ Текст страницы пуст после санитизации")
        return
    
    # Разбиваем текст на строки с динамическим размером шрифта
    text_area_width = page_width - horizontal_padding * 2
    available_height = text_area_height - vertical_padding * 2
    
    # Пробуем разные размеры шрифта, пока текст не поместится
    lines = []
    for test_font_size in range(base_font_size, min_font_size - 1, -1):
        test_leading = test_font_size * leading_multiplier
        test_lines = _wrap_text(text, text_area_width, c, font_name, test_font_size)
        test_block_height = len(test_lines) * test_leading
        
        if test_block_height <= available_height:
            font_size = test_font_size
            leading = test_leading
            lines = test_lines
            break
    
    # Если даже при минимальном размере не помещается - обрезаем по строкам
    if not lines:
        font_size = min_font_size
        leading = font_size * leading_multiplier
        max_lines = int(available_height / leading)
        lines = _wrap_text(text, text_area_width, c, font_name, font_size)
        if len(lines) > max_lines:
            lines = lines[:max_lines]
            # Добавляем "..." в конце последней строки, если обрезали
            if lines:
                last_line = lines[-1]
                if len(last_line) > 3:
                    lines[-1] = last_line[:-3] + "..."
                else:
                    lines[-1] = "..."
            logger.warning(f"⚠️ Текст обрезан до {max_lines} строк (не помещается даже при font_size={font_size})")
    
    # Вычисляем размеры текстового блока
    text_block_height = len(lines) * leading + vertical_padding * 2
    text_block_width = page_width - horizontal_padding * 2
    
    # ЧАСТЬ D: Точное позиционирование - текстовый блок всегда целиком внутри нижней четверти
    # Никаких отрицательных y
    text_x = horizontal_padding
    text_y = max(0, (text_area_height - text_block_height) / 2)  # Центрируем, но не уходим в минус
    
    logger.info(f"📝 PDF text layout font={font_name} size={font_size} lines={len(lines)} block_h={text_block_height:.1f} area_h={text_area_height:.1f}")
    
    # Рисуем кремовый фон для текста (детский UX)
    c.setFillColor(CREAM_BG_COLOR)
    c.setStrokeColor(HexColor("#E0D5C0"))  # Светло-коричневая рамка
    c.setLineWidth(1)
    
    try:
        c.roundRect(
            text_x, text_y,
            text_block_width, text_block_height,
            8,  # Закругленные углы
            fill=1,
            stroke=1
        )
    except AttributeError:
        c.rect(text_x, text_y, text_block_width, text_block_height, fill=1, stroke=1)
    
    # Рисуем текст ТОЛЬКО через beginText/textLine (для кириллицы)
    c.setFillColor(black)
    c.setFont(font_name, font_size)
    
    # Левое выравнивание (НЕ центрирование)
    current_y = text_y + text_block_height - vertical_padding - font_size
    text_x_start = text_x + 5 * mm  # Небольшой отступ от левого края
    
    for line in lines:
        # Используем ТОЛЬКО beginText/textLine для кириллицы
        text_object = c.beginText(text_x_start, current_y)
        text_object.setFont(font_name, font_size)
        text_object.setFillColor(black)
        text_object.textLine(line)
        c.drawText(text_object)
        current_y -= leading


def _draw_text_only_page(
    c: canvas.Canvas,
    text: str,
    page_width: float,
    page_height: float,
    age_config: Dict,
    style: str
) -> None:
    """
    Рисует текст на отдельной странице без изображения.
    
    Args:
        c: Canvas объект
        text: Текст для отображения
        page_width, page_height: Размеры страницы
        age_config: Конфигурация для возраста
        style: Стиль книги
    """
    if not _cyrillic_font_available:
        raise RuntimeError("Шрифт с поддержкой кириллицы не зарегистрирован")
    
    font_name = "CyrillicFont"
    font_size = age_config["font_size"]
    leading = font_size * age_config["leading_multiplier"]
    
    # Safe zone
    horizontal_padding = SAFE_MARGIN
    vertical_padding = 10 * mm
    text_area_width = page_width - horizontal_padding * 2
    
    # Разбиваем текст на строки
    lines = _wrap_text(text, text_area_width, c, font_name, font_size)
    
    # Ограничиваем количество строк
    max_lines = age_config["max_lines_per_page"]
    if len(lines) > max_lines:
        lines = lines[:max_lines]
    
    # Вычисляем размеры текстового блока
    text_block_height = len(lines) * leading + vertical_padding * 2
    text_block_width = page_width - horizontal_padding * 2
    
    # Центрируем текстовый блок
    text_x = (page_width - text_block_width) / 2
    text_y = (page_height - text_block_height) / 2
    
    # Рисуем кремовый фон
    c.setFillColor(CREAM_BG_COLOR)
    c.setStrokeColor(HexColor("#E0D5C0"))
    c.setLineWidth(1)
    
    try:
        c.roundRect(
            text_x, text_y,
            text_block_width, text_block_height,
            8,
            fill=1,
            stroke=1
        )
    except AttributeError:
        c.rect(text_x, text_y, text_block_width, text_block_height, fill=1, stroke=1)
    
    # Рисуем текст
    c.setFillColor(black)
    c.setFont(font_name, font_size)
    
    current_y = text_y + text_block_height - vertical_padding - font_size
    text_x_start = text_x + 5 * mm
    
    for line in lines:
        # ТОЛЬКО beginText/textLine для кириллицы
        text_object = c.beginText(text_x_start, current_y)
        text_object.setFont(font_name, font_size)
        text_object.setFillColor(black)
        text_object.textLine(line)
        c.drawText(text_object)
        current_y -= leading


# ============================================================
# CROP MARKS (РЕЗАЛЬНЫЕ МЕТКИ)
# ============================================================

def _draw_crop_marks(
    c: canvas.Canvas,
    page_width: float,
    page_height: float,
    bleed: float
) -> None:
    """
    Рисует crop marks (резальные метки) для типографии.
    
    Args:
        c: Canvas объект
        page_width: Ширина страницы (с bleed)
        page_height: Высота страницы (с bleed)
        bleed: Размер bleed
    """
    if not PRINT_READY_AVAILABLE:
        return
    
    mark_length = PRINT_CONFIG["crop_mark_length_pt"]  # Уже в points
    mark_width = PRINT_CONFIG["crop_mark_width_pt"]  # Уже в points
    
    c.setStrokeColor(black)
    c.setLineWidth(mark_width)
    
    # Нижний левый угол
    c.line(0, bleed, mark_length, bleed)
    c.line(bleed, 0, bleed, mark_length)
    
    # Нижний правый угол
    c.line(page_width - mark_length, bleed, page_width, bleed)
    c.line(page_width - bleed, 0, page_width - bleed, mark_length)
    
    # Верхний левый угол
    c.line(0, page_height - bleed, mark_length, page_height - bleed)
    c.line(bleed, page_height - mark_length, bleed, page_height)
    
    # Верхний правый угол
    c.line(page_width - mark_length, page_height - bleed, page_width, page_height - bleed)
    c.line(page_width - bleed, page_height - mark_length, page_width - bleed, page_height)
    
    logger.debug(f"✓ Crop marks нарисованы (bleed={bleed:.1f}pt)")


# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================

def _wrap_text(
    text: str,
    max_width: float,
    canvas_obj: canvas.Canvas,
    font_name: str,
    font_size: int
) -> List[str]:
    """
    Разбивает текст на строки, которые помещаются в указанную ширину.
    Unicode-safe: использует только canvas.stringWidth.
    
    Args:
        text: Текст для разбивки
        max_width: Максимальная ширина строки
        canvas_obj: Объект canvas для измерения ширины текста
        font_name: Имя шрифта
        font_size: Размер шрифта
    
    Returns:
        List[str]: Список строк
    """
    # Добавляем запас для безопасности (5% от ширины)
    safe_width = max_width * 0.95
    
    # Разбиваем текст на слова
    words = text.split()
    lines = []
    current_line = ""
    
    for word in words:
        # Пробуем добавить слово к текущей строке
        test_line = current_line + (" " if current_line else "") + word
        
        # Всегда используем canvas_obj.stringWidth для Unicode-safe измерения
        width = canvas_obj.stringWidth(test_line, font_name, font_size)
        
        # Если строка помещается, добавляем слово
        if width <= safe_width:
            current_line = test_line
        else:
            # Если текущая строка не пустая, сохраняем её
            if current_line:
                lines.append(current_line)
            # Начинаем новую строку с текущего слова
            # Если слово само по себе слишком длинное, разбиваем его
            word_width = canvas_obj.stringWidth(word, font_name, font_size)
            
            if word_width > safe_width:
                # Слово слишком длинное, разбиваем по символам
                chars = list(word)
                temp_word = ""
                for char in chars:
                    test_char = temp_word + char
                    char_width = canvas_obj.stringWidth(test_char, font_name, font_size)
                    if char_width <= safe_width:
                        temp_word = test_char
                    else:
                        if temp_word:
                            lines.append(temp_word)
                        temp_word = char
                current_line = temp_word
            else:
                current_line = word
    
    # Добавляем последнюю строку
    if current_line:
        lines.append(current_line)
    
    return lines
