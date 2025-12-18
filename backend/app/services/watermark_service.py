"""
Сервис для добавления водяных знаков и защиты от скриншотов
"""
import os
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
import logging

logger = logging.getLogger(__name__)


def add_watermark(image_bytes: bytes, text: str = "STORYHERO", opacity: int = 100) -> bytes:
    """
    Добавляет водяной знак к изображению
    
    Args:
        image_bytes: Байты изображения
        text: Текст водяного знака
        opacity: Прозрачность (0-255)
    
    Returns:
        bytes: Байты изображения с водяным знаком
    """
    try:
        # Открываем изображение
        image = Image.open(BytesIO(image_bytes))
        
        # Конвертируем в RGBA если нужно
        if image.mode != 'RGBA':
            image = image.convert('RGBA')
        
        # Создаем слой для водяного знака
        watermark = Image.new('RGBA', image.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(watermark)
        
        # Пытаемся загрузить шрифт, если не получается - используем стандартный
        try:
            font_size = max(image.width, image.height) // 20
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", font_size)
        except:
            font = ImageFont.load_default()
        
        # Получаем размер текста
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        # Позиционируем водяной знак по центру
        x = (image.width - text_width) // 2
        y = (image.height - text_height) // 2
        
        # Рисуем текст с прозрачностью
        draw.text((x, y), text, font=font, fill=(255, 255, 255, opacity))
        
        # Накладываем водяной знак на изображение
        watermarked = Image.alpha_composite(image, watermark)
        
        # Конвертируем обратно в RGB для JPEG
        if watermarked.mode == 'RGBA':
            rgb_image = Image.new('RGB', watermarked.size, (255, 255, 255))
            rgb_image.paste(watermarked, mask=watermarked.split()[3])
            watermarked = rgb_image
        
        # Сохраняем в байты
        output = BytesIO()
        watermarked.save(output, format='JPEG', quality=85)
        output.seek(0)
        
        return output.getvalue()
        
    except Exception as e:
        logger.error(f"❌ Ошибка при добавлении водяного знака: {str(e)}", exc_info=True)
        # В случае ошибки возвращаем оригинальное изображение
        return image_bytes


def reduce_quality_for_preview(image_bytes: bytes, max_size: int = 800, quality: int = 60) -> bytes:
    """
    Снижает качество изображения для preview (защита от скриншотов)
    
    Args:
        image_bytes: Байты изображения
        max_size: Максимальный размер по большей стороне
        quality: Качество JPEG (1-100)
    
    Returns:
        bytes: Байты изображения с пониженным качеством
    """
    try:
        # Открываем изображение
        image = Image.open(BytesIO(image_bytes))
        
        # Изменяем размер если нужно
        if max(image.width, image.height) > max_size:
            ratio = max_size / max(image.width, image.height)
            new_width = int(image.width * ratio)
            new_height = int(image.height * ratio)
            image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Конвертируем в RGB если нужно
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Сохраняем с пониженным качеством
        output = BytesIO()
        image.save(output, format='JPEG', quality=quality, optimize=True)
        output.seek(0)
        
        return output.getvalue()
        
    except Exception as e:
        logger.error(f"❌ Ошибка при снижении качества: {str(e)}", exc_info=True)
        # В случае ошибки возвращаем оригинальное изображение
        return image_bytes


def create_preview_image(image_bytes: bytes, add_watermark: bool = True) -> bytes:
    """
    Создает preview версию изображения с защитой от скриншотов
    
    Args:
        image_bytes: Байты оригинального изображения
        add_watermark: Добавлять ли водяной знак
    
    Returns:
        bytes: Байты preview изображения
    """
    try:
        # Сначала снижаем качество
        preview = reduce_quality_for_preview(image_bytes, max_size=800, quality=60)
        
        # Затем добавляем водяной знак если нужно
        if add_watermark:
            preview = add_watermark(preview, text="STORYHERO PREVIEW", opacity=80)
        
        return preview
        
    except Exception as e:
        logger.error(f"❌ Ошибка при создании preview: {str(e)}", exc_info=True)
        return image_bytes

