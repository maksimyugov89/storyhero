"""
Skin-tone safe CMYK preset для детских книг.
Защищает от серых, зелёных и кирпичных оттенков кожи.
"""
import logging
from typing import Tuple

logger = logging.getLogger(__name__)


def clamp_skin_tones(c: float, m: float, y: float, k: float) -> Tuple[float, float, float, float]:
    """
    Skin-tone safe CMYK preset для детей.
    Ограничивает значения CMYK в безопасных пределах для естественной кожи.
    
    Args:
        c, m, y, k: CMYK значения (0-1.0 или 0-100)
    
    Returns:
        Tuple[float, float, float, float]: Ограниченные CMYK значения
    """
    # Нормализуем значения к диапазону 0-1.0 если они в диапазоне 0-100
    if c > 1.0 or m > 1.0 or y > 1.0 or k > 1.0:
        c, m, y, k = c / 100.0, m / 100.0, y / 100.0, k / 100.0
    
    # Безопасные диапазоны для детской кожи (light preset)
    # C: минимум 0, максимум 0.35 (35%) - убирает зелёные оттенки
    # M: минимум 0.25, максимум 0.55 (55%) - естественный румянец
    # Y: минимум 0.25, максимум 0.65 (65%) - тёплый оттенок
    # K: минимум 0, максимум 0.15 (15%) - убирает серость
    
    c_clamped = min(max(c, 0.0), 0.35)
    m_clamped = min(max(m, 0.25), 0.55)
    y_clamped = min(max(y, 0.25), 0.65)
    k_clamped = min(max(k, 0.0), 0.15)
    
    return c_clamped, m_clamped, y_clamped, k_clamped


def apply_skin_tone_clamp_to_image(image_cmyk, face_bbox=None):
    """
    Применяет skin-tone clamp к изображению в зоне лица.
    
    Args:
        image_cmyk: PIL Image в режиме CMYK
        face_bbox: Tuple[int, int, int, int] - координаты лица (x1, y1, x2, y2)
    
    Returns:
        PIL.Image: Изображение с применённым clamp
    """
    import numpy as np
    from PIL import ImageFilter
    
    if image_cmyk.mode != "CMYK":
        raise ValueError("Изображение должно быть в режиме CMYK")
    
    if face_bbox is None:
        logger.warning("⚠️ Face bbox не указан, пропускаем skin-tone clamp")
        return image_cmyk
    
    x1, y1, x2, y2 = face_bbox
    width, height = image_cmyk.size
    
    # Расширяем bbox для захвата щёк и лба
    expand_w = int((x2 - x1) * 0.12)  # +12% по ширине
    expand_h = int((y2 - y1) * 0.18)  # +18% по высоте
    
    x1 = max(0, x1 - expand_w)
    y1 = max(0, y1 - expand_h)
    x2 = min(width, x2 + expand_w)
    y2 = min(height, y2 + expand_h)
    
    # Конвертируем в numpy для обработки
    img_array = np.array(image_cmyk).astype(float) / 255.0
    
    # Создаём мягкую маску (Gaussian blur)
    from PIL import Image as PILImage, ImageDraw
    mask = PILImage.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([x1, y1, x2, y2], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=16))
    mask_array = np.array(mask) / 255.0
    
    # Применяем clamp только в зоне лица
    clamped_count = 0
    for y in range(y1, y2):
        for x in range(x1, x2):
            alpha = mask_array[y, x]
            if alpha > 0:
                c, m, y_val, k = img_array[y, x]
                c_clamped, m_clamped, y_clamped, k_clamped = clamp_skin_tones(c, m, y_val, k)
                
                # Смешиваем с оригиналом через маску
                img_array[y, x, 0] = c * (1 - alpha) + c_clamped * alpha
                img_array[y, x, 1] = m * (1 - alpha) + m_clamped * alpha
                img_array[y, x, 2] = y_val * (1 - alpha) + y_clamped * alpha
                img_array[y, x, 3] = k * (1 - alpha) + k_clamped * alpha
                
                if c != c_clamped or m != m_clamped or y_val != y_clamped or k != k_clamped:
                    clamped_count += 1
    
    # Конвертируем обратно в PIL Image
    img_array_uint8 = np.clip(img_array * 255, 0, 255).astype(np.uint8)
    result = PILImage.fromarray(img_array_uint8, mode="CMYK")
    
    if clamped_count > 0:
        logger.info(f"🎨 Skin-tone clamp применён: {clamped_count} пикселей обработано")
    
    return result

