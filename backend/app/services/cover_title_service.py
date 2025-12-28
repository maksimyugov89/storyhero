"""
Сервис для добавления названия книги на обложку.
Гарантирует читаемость через автоматический выбор цвета по контрасту, подложку и обводку.
"""
import logging
from typing import Tuple, Optional
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
import os

logger = logging.getLogger(__name__)


def get_average_brightness(image: Image.Image, region: Optional[Tuple[int, int, int, int]] = None) -> float:
    """
    Вычисляет среднюю яркость области изображения.
    
    Args:
        image: PIL Image
        region: (x0, y0, x1, y1) или None для всего изображения
    
    Returns:
        float: Средняя яркость от 0 (чёрный) до 255 (белый)
    """
    if region:
        cropped = image.crop(region)
    else:
        cropped = image
    
    # Конвертируем в grayscale если нужно
    if cropped.mode != "L":
        cropped = cropped.convert("L")
    
    # Вычисляем среднюю яркость
    pixels = list(cropped.getdata())
    if not pixels:
        return 128.0  # Средняя яркость по умолчанию
    
    return sum(pixels) / len(pixels)


def choose_text_color(image: Image.Image, title_region: Tuple[int, int, int, int]) -> Tuple[str, str]:
    """
    Выбирает цвет текста и обводки на основе яркости области под названием.
    
    Args:
        image: PIL Image обложки
        title_region: (x0, y0, x1, y1) область, где будет название
    
    Returns:
        Tuple[str, str]: (цвет_текста, цвет_обводки) в формате "#RRGGBB"
    """
    brightness = get_average_brightness(image, title_region)
    
    # Если яркость высокая (>128) - текст тёмный, если низкая - светлый
    if brightness > 128:
        text_color = "#000000"  # Чёрный
        outline_color = "#FFFFFF"  # Белая обводка
        contrast_mode = "dark_text"
    else:
        text_color = "#FFFFFF"  # Белый
        outline_color = "#000000"  # Чёрная обводка
        contrast_mode = "light_text"
    
    logger.debug(f"🎨 Выбран цвет текста: {text_color} (brightness={brightness:.1f}, mode={contrast_mode})")
    return text_color, outline_color


def add_title_to_cover(
    cover_image_bytes: bytes,
    title: str,
    output_path: Optional[str] = None
) -> bytes:
    """
    Добавляет название книги на обложку с автоматическим выбором цвета, подложкой и обводкой.
    
    Args:
        cover_image_bytes: Байты изображения обложки
        title: Название книги
        output_path: Путь для сохранения (опционально)
    
    Returns:
        bytes: Байты изображения обложки с названием
    """
    try:
        # Открываем изображение
        img = Image.open(BytesIO(cover_image_bytes))
        if img.mode != "RGB":
            img = img.convert("RGB")
        
        width, height = img.size
        
        # Область для названия: верхние 25% изображения
        title_region = (0, int(height * 0.75), width, height)
        
        # Выбираем цвет текста по контрасту
        text_color, outline_color = choose_text_color(img, title_region)
        
        # Создаём ImageDraw для рисования
        draw = ImageDraw.Draw(img)
        
        # Загружаем шрифт (если доступен)
        font_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)),
            "assets", "fonts", "DejaVuSans-Bold.ttf"
        )
        
        # Адаптивный размер шрифта (6% от высоты изображения)
        font_size = int(height * 0.06)
        
        if os.path.exists(font_path):
            try:
                font = ImageFont.truetype(font_path, font_size)
            except Exception as e:
                logger.warning(f"⚠️ Ошибка загрузки шрифта {font_path}: {e}. Используется дефолтный.")
                font = ImageFont.load_default()
        else:
            logger.warning(f"⚠️ Шрифт не найден: {font_path}. Используется дефолтный.")
            font = ImageFont.load_default()
        
        # Разбиваем название на строки (максимум 2-3 строки)
        words = title.split()
        lines = []
        current_line = ""
        max_width = width * 0.85  # 85% ширины
        
        for word in words:
            test_line = current_line + " " + word if current_line else word
            # Приблизительная ширина текста
            bbox = draw.textbbox((0, 0), test_line, font=font)
            text_width = bbox[2] - bbox[0]
            
            if text_width < max_width and len(lines) < 2:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word
                if len(lines) >= 2:
                    break
        
        if current_line and len(lines) < 3:
            lines.append(current_line)
        
        # Вычисляем размеры текстового блока
        line_heights = []
        for line in lines:
            bbox = draw.textbbox((0, 0), line, font=font)
            line_heights.append(bbox[3] - bbox[1])
        
        total_text_height = sum(line_heights) + (len(lines) - 1) * int(height * 0.02)  # Интервал между строками
        text_block_height = total_text_height + int(height * 0.04)  # Отступы
        text_block_width = int(width * 0.9)  # 90% ширины
        
        # Позиция текстового блока: по центру горизонтально, в верхней части вертикально
        text_x = (width - text_block_width) / 2
        text_y = height * 0.75  # Начинаем с 75% высоты (верхние 25% для текста)
        
        # Рисуем подложку (rounded rect) с alpha
        # Создаём временный слой для подложки с прозрачностью
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        overlay_draw = ImageDraw.Draw(overlay)
        
        # Подложка: чёрная с alpha 0.85-0.92
        alpha = 230  # ~0.9
        overlay_draw.rounded_rectangle(
            [(text_x, text_y), (text_x + text_block_width, text_y + text_block_height)],
            radius=int(height * 0.01),
            fill=(0, 0, 0, alpha)
        )
        
        # Накладываем подложку на изображение
        img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
        draw = ImageDraw.Draw(img)
        
        # Рисуем текст с обводкой (тень/обводка 2-3 px)
        stroke_width = max(2, int(height * 0.003))  # 2-3 px в зависимости от размера
        
        # Позиция первой строки
        current_y = text_y + int(height * 0.02)
        
        for i, line in enumerate(lines):
            # Центрируем каждую строку
            bbox = draw.textbbox((0, 0), line, font=font)
            line_width = bbox[2] - bbox[0]
            line_x = (width - line_width) / 2
            
            # Рисуем обводку (тень) - несколько раз для эффекта
            for dx in [-stroke_width, 0, stroke_width]:
                for dy in [-stroke_width, 0, stroke_width]:
                    if dx != 0 or dy != 0:
                        draw.text(
                            (line_x + dx, current_y + dy),
                            line,
                            font=font,
                            fill=outline_color
                        )
            
            # Рисуем основной текст
            draw.text(
                (line_x, current_y),
                line,
                font=font,
                fill=text_color
            )
            
            current_y += line_heights[i] + int(height * 0.02)
        
        logger.info(f"📝 Cover title applied: lines={len(lines)} font_size={font_size} contrast_mode={'dark' if text_color == '#000000' else 'light'}")
        
        # Сохраняем результат
        output = BytesIO()
        img.save(output, format="JPEG", quality=95, optimize=True)
        result_bytes = output.getvalue()
        
        # Сохраняем на диск, если указан путь
        if output_path:
            with open(output_path, "wb") as f:
                f.write(result_bytes)
            logger.info(f"✅ Обложка с названием сохранена: {output_path}")
        
        return result_bytes
        
    except Exception as e:
        logger.error(f"❌ Ошибка при добавлении названия на обложку: {e}", exc_info=True)
        # Возвращаем оригинал при ошибке
        return cover_image_bytes
