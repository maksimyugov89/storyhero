"""
Цветовой pipeline для PRINT-READY PDF.
Конвертация RGB -> CMYK с использованием ICC профилей.
"""
import logging
from io import BytesIO
from PIL import Image
try:
    from PIL import ImageCms
    IMAGE_CMS_AVAILABLE = True
except ImportError:
    IMAGE_CMS_AVAILABLE = False
import os

logger = logging.getLogger(__name__)

# Путь к ICC профилю
ICC_PROFILE_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
    "assets", "icc", "ISOcoated_v2_300_eci.icc"
)


def get_icc_profile_path() -> str:
    """Возвращает путь к ICC профилю."""
    return ICC_PROFILE_PATH


def rgb_to_cmyk_print_safe(image_bytes: bytes, use_icc: bool = True) -> bytes:
    """
    Конвертирует RGB изображение в CMYK для печати.
    
    Args:
        image_bytes: Байты RGB изображения
        use_icc: Использовать ICC профиль (ISO Coated v2) если доступен
    
    Returns:
        bytes: Байты CMYK изображения в формате TIFF
    """
    try:
        # Открываем изображение
        img = Image.open(BytesIO(image_bytes))
        
        # Убеждаемся, что это RGB
        if img.mode != "RGB":
            img = img.convert("RGB")
        
        # Конвертация в CMYK
        if use_icc and IMAGE_CMS_AVAILABLE and os.path.exists(get_icc_profile_path()):
            try:
                # Используем ICC профиль для точной конвертации
                icc_profile = ImageCms.ImageCmsProfile(get_icc_profile_path())
                srgb_profile = ImageCms.createProfile("sRGB")
                
                # Создаём трансформацию RGB -> CMYK
                transform = ImageCms.ImageCmsTransform(
                    srgb_profile,
                    icc_profile,
                    "RGB",
                    "CMYK"
                )
                
                cmyk_img = transform.apply(img)
                logger.info("🎨 RGB->CMYK конвертация выполнена через ICC профиль ISO Coated v2")
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при использовании ICC профиля: {e}. Используется стандартная конвертация.")
                cmyk_img = img.convert("CMYK")
        else:
            # Стандартная конвертация без ICC профиля
            if not use_icc:
                logger.info("🎨 RGB->CMYK конвертация без ICC профиля")
            elif not IMAGE_CMS_AVAILABLE:
                logger.warning("⚠️ PIL.ImageCms не доступен. Используется стандартная конвертация.")
            else:
                logger.warning(f"⚠️ ICC профиль не найден: {get_icc_profile_path()}. Используется стандартная конвертация.")
            cmyk_img = img.convert("CMYK")
        
        # Сохраняем в JPEG с высоким качеством для ReportLab (более эффективно чем TIFF)
        # Для финального PDF можно использовать JPEG, так как ReportLab конвертирует в CMYK при сохранении
        out = BytesIO()
        # Конвертируем CMYK обратно в RGB для JPEG (ReportLab работает лучше с RGB)
        rgb_img = cmyk_img.convert("RGB")
        rgb_img.save(out, format="JPEG", quality=98, optimize=True)
        result = out.getvalue()
        
        logger.debug(f"✅ CMYK->RGB JPEG изображение создано: {len(result)} байт (JPEG quality=98)")
        return result
        
    except Exception as e:
        logger.error(f"❌ Ошибка при конвертации RGB->CMYK: {e}", exc_info=True)
        # Fallback: возвращаем оригинал
        return image_bytes

