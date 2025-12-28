"""
Тестовый скрипт для проверки Skin-Tone Safe CMYK pipeline.
Проверяет:
- Лицо без серости
- Нет зелёных теней
- CMYK значения в пределах preset'а
"""
import logging
import sys
import os
from pathlib import Path

# Добавляем путь к app
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.skin_tone_service import apply_skin_tone_safe_cmyk
from app.services.cmyk_presets import get_preset, DEFAULT_PRESET
from PIL import Image
import numpy as np

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def test_skin_tone_cmyk(image_path: str, preset_name: str = DEFAULT_PRESET):
    """
    Тестирует skin-tone safe CMYK коррекцию на изображении.
    
    Args:
        image_path: Путь к тестовому изображению
        preset_name: Имя preset'а для использования
    """
    logger.info(f"🧪 Тестирование Skin-Tone Safe CMYK на изображении: {image_path}")
    
    if not os.path.exists(image_path):
        logger.error(f"❌ Изображение не найдено: {image_path}")
        return False
    
    # Загружаем изображение
    try:
        image_rgb = Image.open(image_path)
        if image_rgb.mode != "RGB":
            image_rgb = image_rgb.convert("RGB")
        logger.info(f"✓ Изображение загружено: {image_rgb.size}, mode={image_rgb.mode}")
    except Exception as e:
        logger.error(f"❌ Ошибка при загрузке изображения: {e}")
        return False
    
    # Применяем skin-tone safe CMYK коррекцию
    try:
        image_cmyk = apply_skin_tone_safe_cmyk(
            image_rgb=image_rgb,
            face_bbox=None,  # Автоматическое определение
            preset_name=preset_name
        )
        logger.info(f"✓ Skin-tone коррекция применена, результат: {image_cmyk.size}, mode={image_cmyk.mode}")
    except Exception as e:
        logger.error(f"❌ Ошибка при применении skin-tone коррекции: {e}", exc_info=True)
        return False
    
    # Проверяем CMYK значения в зоне лица
    preset = get_preset(preset_name)
    cmyk_array = np.array(image_cmyk, dtype=np.float32)
    
    # Находим зону с максимальными значениями (предполагаем, что это лицо)
    # В реальности нужно использовать bbox от InsightFace, но для теста используем центр
    h, w = cmyk_array.shape[:2]
    center_y, center_x = h // 2, w // 2
    face_zone_size = min(h, w) // 4
    
    face_zone = cmyk_array[
        center_y - face_zone_size:center_y + face_zone_size,
        center_x - face_zone_size:center_x + face_zone_size
    ]
    
    # Проверяем диапазоны CMYK
    c_min, c_max = preset["C"]
    m_min, m_max = preset["M"]
    y_min, y_max = preset["Y"]
    k_min, k_max = preset["K"]
    
    c_values = face_zone[:, :, 0]
    m_values = face_zone[:, :, 1]
    y_values = face_zone[:, :, 2]
    k_values = face_zone[:, :, 3]
    
    c_mean = np.mean(c_values)
    m_mean = np.mean(m_values)
    y_mean = np.mean(y_values)
    k_mean = np.mean(k_values)
    
    c_max_val = np.max(c_values)
    m_max_val = np.max(m_values)
    y_max_val = np.max(y_values)
    k_max_val = np.max(k_values)
    
    logger.info(f"📊 CMYK статистика в зоне лица:")
    logger.info(f"   C: mean={c_mean:.1f}, max={c_max_val:.1f} (preset: {c_min}-{c_max})")
    logger.info(f"   M: mean={m_mean:.1f}, max={m_max_val:.1f} (preset: {m_min}-{m_max})")
    logger.info(f"   Y: mean={y_mean:.1f}, max={y_max_val:.1f} (preset: {y_min}-{y_max})")
    logger.info(f"   K: mean={k_mean:.1f}, max={k_max_val:.1f} (preset: {k_min}-{k_max})")
    
    # Проверяем, что значения в пределах preset'а (с небольшим допуском)
    checks_passed = True
    
    if c_max_val > c_max + 5:
        logger.warning(f"⚠️ C превышает preset: {c_max_val:.1f} > {c_max}")
        checks_passed = False
    
    if m_max_val > m_max + 5:
        logger.warning(f"⚠️ M превышает preset: {m_max_val:.1f} > {m_max}")
        checks_passed = False
    
    if y_max_val > y_max + 5:
        logger.warning(f"⚠️ Y превышает preset: {y_max_val:.1f} > {y_max}")
        checks_passed = False
    
    if k_max_val > k_max + 5:
        logger.warning(f"⚠️ K превышает preset: {k_max_val:.1f} > {k_max}")
        checks_passed = False
    
    # Проверяем на серость (высокий K при низких C/M/Y)
    gray_pixels = np.sum((k_values > 10) & (c_values < 5) & (m_values < 15))
    total_pixels = k_values.size
    gray_ratio = gray_pixels / total_pixels if total_pixels > 0 else 0
    
    if gray_ratio > 0.1:
        logger.warning(f"⚠️ Обнаружена серость в зоне лица: {gray_ratio*100:.1f}% пикселей")
        checks_passed = False
    else:
        logger.info(f"✓ Серость в норме: {gray_ratio*100:.1f}% пикселей")
    
    # Проверяем на зелёные тени (высокий C при низких M/Y)
    green_pixels = np.sum((c_values > 8) & (m_values < 10) & (y_values < 15))
    green_ratio = green_pixels / total_pixels if total_pixels > 0 else 0
    
    if green_ratio > 0.1:
        logger.warning(f"⚠️ Обнаружены зелёные тени: {green_ratio*100:.1f}% пикселей")
        checks_passed = False
    else:
        logger.info(f"✓ Зелёные тени отсутствуют: {green_ratio*100:.1f}% пикселей")
    
    if checks_passed:
        logger.info("✅ Все проверки пройдены! Skin-tone safe CMYK коррекция работает корректно.")
    else:
        logger.warning("⚠️ Некоторые проверки не пройдены. Рекомендуется проверить preset и изображение.")
    
    return checks_passed


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Тестирование Skin-Tone Safe CMYK pipeline")
    parser.add_argument("image_path", help="Путь к тестовому изображению")
    parser.add_argument("--preset", default=DEFAULT_PRESET, 
                       choices=["child_light", "child_medium", "child_dark"],
                       help="Preset для использования")
    
    args = parser.parse_args()
    
    success = test_skin_tone_cmyk(args.image_path, args.preset)
    sys.exit(0 if success else 1)

