"""
Сервис для применения Skin-Tone Safe CMYK коррекции к зоне лица ребёнка.
Предотвращает серость, зелёные тени и кирпичный оттенок при печати.
"""
import logging
import numpy as np
from PIL import Image, ImageFilter
from typing import Tuple, Optional
import cv2

from .cmyk_presets import get_preset, DEFAULT_PRESET
from .face_service import _get_face_analyzer

logger = logging.getLogger(__name__)

# ICC профиль для CMYK конвертации (ISO Coated v2 ECI)
ICC_PROFILE_PATH = None  # Будет установлен при первом использовании


def _get_icc_profile_path() -> Optional[str]:
    """
    Возвращает путь к ICC профилю ISO Coated v2 ECI.
    Если профиль не найден, возвращает None (используется стандартная конвертация).
    """
    global ICC_PROFILE_PATH
    
    if ICC_PROFILE_PATH is not None:
        return ICC_PROFILE_PATH
    
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    icc_path = os.path.join(script_dir, "..", "assets", "icc", "ISOcoated_v2_300_eci.icc")
    
    if os.path.exists(icc_path):
        ICC_PROFILE_PATH = icc_path
        logger.info(f"✓ ICC профиль найден: {icc_path}")
        return icc_path
    else:
        logger.warning(f"⚠️ ICC профиль не найден: {icc_path}. Используется стандартная CMYK конвертация.")
        ICC_PROFILE_PATH = ""  # Пустая строка означает "не найден"
        return None


def _expand_bbox(bbox: Tuple[int, int, int, int], width: int, height: int, 
                 expand_w: float = 0.12, expand_h: float = 0.18) -> Tuple[int, int, int, int]:
    """
    Расширяет bounding box для захвата щёк и лба.
    
    Args:
        bbox: (x1, y1, x2, y2) - координаты лица
        width: Ширина изображения
        height: Высота изображения
        expand_w: Коэффициент расширения по ширине (12%)
        expand_h: Коэффициент расширения по высоте (18%)
    
    Returns:
        Tuple[int, int, int, int]: Расширенный bbox
    """
    x1, y1, x2, y2 = bbox
    
    # Вычисляем размеры bbox
    bbox_w = x2 - x1
    bbox_h = y2 - y1
    
    # Расширяем
    expand_w_px = int(bbox_w * expand_w)
    expand_h_px = int(bbox_h * expand_h)
    
    # Новые координаты
    new_x1 = max(0, x1 - expand_w_px)
    new_y1 = max(0, y1 - expand_h_px)
    new_x2 = min(width, x2 + expand_w_px)
    new_y2 = min(height, y2 + expand_h_px)
    
    return (new_x1, new_y1, new_x2, new_y2)


def _create_soft_mask(bbox: Tuple[int, int, int, int], width: int, height: int, 
                      blur_radius: int = 16) -> np.ndarray:
    """
    Создаёт мягкую маску для зоны лица с Gaussian blur.
    
    Args:
        bbox: (x1, y1, x2, y2) - координаты лица
        width: Ширина изображения
        height: Высота изображения
        blur_radius: Радиус размытия (12-20px)
    
    Returns:
        np.ndarray: Маска (0-255, float32)
    """
    x1, y1, x2, y2 = bbox
    
    # Создаём бинарную маску
    mask = np.zeros((height, width), dtype=np.float32)
    mask[y1:y2, x1:x2] = 1.0
    
    # Применяем Gaussian blur для мягких краёв
    mask_pil = Image.fromarray((mask * 255).astype(np.uint8))
    mask_blurred = mask_pil.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    mask_soft = np.array(mask_blurred, dtype=np.float32) / 255.0
    
    return mask_soft


def _clamp_cmyk_pixel(c: float, m: float, y: float, k: float, preset: dict) -> Tuple[float, float, float, float]:
    """
    Ограничивает CMYK значения пикселя по preset'у.
    
    Args:
        c, m, y, k: CMYK значения (0-100)
        preset: Preset с диапазонами CMYK
    
    Returns:
        Tuple[float, float, float, float]: Ограниченные CMYK значения
    """
    c_min, c_max = preset["C"]
    m_min, m_max = preset["M"]
    y_min, y_max = preset["Y"]
    k_min, k_max = preset["K"]
    
    c_clamped = np.clip(c, c_min, c_max)
    m_clamped = np.clip(m, m_min, m_max)
    y_clamped = np.clip(y, y_min, y_max)
    k_clamped = np.clip(k, k_min, k_max)
    
    # Логируем если было ограничение
    if c != c_clamped or m != m_clamped or y != y_clamped or k != k_clamped:
        logger.debug(f"⚠️ CMYK clamped: C={c:.1f}→{c_clamped:.1f}, M={m:.1f}→{m_clamped:.1f}, "
                    f"Y={y:.1f}→{y_clamped:.1f}, K={k:.1f}→{k_clamped:.1f}")
    
    return c_clamped, m_clamped, y_clamped, k_clamped


def apply_skin_tone_safe_cmyk(
    image_rgb: Image.Image,
    face_bbox: Optional[Tuple[int, int, int, int]] = None,
    preset_name: str = DEFAULT_PRESET
) -> Image.Image:
    """
    Применяет Skin-Tone Safe CMYK коррекцию к зоне лица ребёнка.
    
    Args:
        image_rgb: RGB изображение (PIL.Image)
        face_bbox: Bounding box лица (x1, y1, x2, y2). Если None, определяется автоматически.
        preset_name: Имя preset'а для детской кожи (по умолчанию "child_light")
    
    Returns:
        Image.Image: CMYK изображение с коррекцией зоны лица
    """
    if image_rgb.mode != "RGB":
        image_rgb = image_rgb.convert("RGB")
    
    width, height = image_rgb.size
    
    # Определяем bbox лица, если не передан
    if face_bbox is None:
        # Конвертируем PIL в numpy для InsightFace
        img_np = np.array(image_rgb)
        img_bgr = cv2.cvtColor(img_np, cv2.COLOR_RGB2BGR)
        
        # Обнаруживаем лицо
        analyzer = _get_face_analyzer()
        faces = analyzer.get(img_bgr)
        
        if not faces:
            logger.warning("⚠️ Лицо не обнаружено, пропускаем skin-tone коррекцию")
            # Конвертируем в CMYK без коррекции
            return _convert_rgb_to_cmyk(image_rgb)
        
        # Берём первое (лучшее) лицо
        best_face = faces[0]
        bbox = best_face.bbox.astype(int)
        face_bbox = (bbox[0], bbox[1], bbox[2], bbox[3])
        logger.info(f"✓ Лицо обнаружено автоматически: bbox={face_bbox}")
    
    # Расширяем bbox для захвата щёк и лба
    expanded_bbox = _expand_bbox(face_bbox, width, height)
    logger.info(f"✓ Bbox расширен: {face_bbox} → {expanded_bbox}")
    
    # Получаем preset
    preset = get_preset(preset_name)
    logger.info(f"✓ Используется preset: {preset_name} - {preset.get('description', '')}")
    
    # Конвертируем RGB → CMYK
    image_cmyk = _convert_rgb_to_cmyk(image_rgb)
    
    # Создаём мягкую маску для зоны лица
    mask = _create_soft_mask(expanded_bbox, width, height, blur_radius=16)
    
    # Применяем коррекцию ТОЛЬКО к зоне лица
    cmyk_array = np.array(image_cmyk, dtype=np.float32)
    
    x1, y1, x2, y2 = expanded_bbox
    clamped_count = 0
    
    for y in range(y1, min(y2, height)):
        for x in range(x1, min(x2, width)):
            # Получаем вес маски для этого пикселя
            mask_weight = mask[y, x]
            
            if mask_weight > 0.01:  # Только если пиксель в зоне лица
                # Получаем CMYK значения
                c, m, y_val, k = cmyk_array[y, x]
                
                # Ограничиваем по preset'у
                c_clamped, m_clamped, y_clamped, k_clamped = _clamp_cmyk_pixel(
                    c, m, y_val, k, preset
                )
                
                # Применяем с учётом веса маски (плавный переход)
                if mask_weight < 1.0:
                    # Плавный переход на краях маски
                    cmyk_array[y, x, 0] = c * (1 - mask_weight) + c_clamped * mask_weight
                    cmyk_array[y, x, 1] = m * (1 - mask_weight) + m_clamped * mask_weight
                    cmyk_array[y, x, 2] = y_val * (1 - mask_weight) + y_clamped * mask_weight
                    cmyk_array[y, x, 3] = k * (1 - mask_weight) + k_clamped * mask_weight
                else:
                    # Полное применение в центре маски
                    cmyk_array[y, x, 0] = c_clamped
                    cmyk_array[y, x, 1] = m_clamped
                    cmyk_array[y, x, 2] = y_clamped
                    cmyk_array[y, x, 3] = k_clamped
                
                if c != c_clamped or m != m_clamped or y_val != y_clamped or k != k_clamped:
                    clamped_count += 1
    
    # Защита от регресса: проверяем, что значения безопасны
    if clamped_count > 0:
        max_c = np.max(cmyk_array[y1:y2, x1:x2, 0])
        max_k = np.max(cmyk_array[y1:y2, x1:x2, 3])
        # Проверяем, что значения в безопасных пределах (с запасом для preset'ов)
        # child_light: C max=6, K max=4; child_medium: C max=10, K max=8; child_dark: C max=15, K max=12
        # Используем максимальный предел из всех preset'ов + запас
        if max_c > 20 or max_k > 15:
            logger.error(f"🚨 КРИТИЧНО: Обнаружены небезопасные CMYK значения в зоне лица: C={max_c:.1f}, K={max_k:.1f}")
            raise ValueError(f"Unsafe CMYK skin values detected: C={max_c:.1f}, K={max_k:.1f}")
        elif max_c > 15 or max_k > 12:
            logger.warning(f"⚠️ Обнаружены высокие CMYK значения в зоне лица: C={max_c:.1f}, K={max_k:.1f}")
    
    # Конвертируем обратно в PIL Image
    cmyk_array_uint8 = np.clip(cmyk_array, 0, 255).astype(np.uint8)
    image_cmyk_corrected = Image.fromarray(cmyk_array_uint8, mode="CMYK")
    
    logger.info(f"🎨 Skin-tone CMYK applied: preset={preset_name}, bbox={expanded_bbox}, "
               f"clamped_pixels={clamped_count}")
    
    return image_cmyk_corrected


def _convert_rgb_to_cmyk(image_rgb: Image.Image) -> Image.Image:
    """
    Конвертирует RGB изображение в CMYK с использованием ICC профиля (если доступен).
    
    Args:
        image_rgb: RGB изображение (PIL.Image)
    
    Returns:
        Image.Image: CMYK изображение
    """
    icc_path = _get_icc_profile_path()
    
    if icc_path:
        # Используем ICC профиль для точной конвертации
        try:
            # Конвертируем через ICC профиль
            image_cmyk = image_rgb.convert("CMYK", icc_profile=icc_path)
            logger.debug("✓ RGB → CMYK конвертация через ICC профиль")
            return image_cmyk
        except Exception as e:
            logger.warning(f"⚠️ Ошибка при использовании ICC профиля: {e}. Используется стандартная конвертация.")
    
    # Стандартная конвертация (без ICC профиля)
    image_cmyk = image_rgb.convert("CMYK")
    logger.debug("✓ RGB → CMYK конвертация (стандартная)")
    return image_cmyk

