"""
Сервис для Face Swap с использованием InsightFace
"""
import os
import cv2
import numpy as np
from pathlib import Path
from fastapi import HTTPException
import logging

logger = logging.getLogger(__name__)

# Глобальные переменные для моделей
_face_analysis = None
_face_swapper = None

MODELS_DIR = Path("/app/models_insightface")
INSWAPPER_MODEL_PATH = MODELS_DIR / "inswapper_128.onnx"


def _download_model_if_needed():
    """Скачивает модель inswapper_128.onnx, если её нет"""
    if INSWAPPER_MODEL_PATH.exists():
        logger.info(f"✓ Модель inswapper уже существует: {INSWAPPER_MODEL_PATH}")
        return
    
    logger.info("Загрузка модели inswapper_128.onnx...")
    try:
        import urllib.request
        model_url = "https://github.com/facefusion/facefusion-assets/releases/download/models/inswapper_128.onnx"
        
        MODELS_DIR.mkdir(parents=True, exist_ok=True)
        
        urllib.request.urlretrieve(model_url, str(INSWAPPER_MODEL_PATH))
        logger.info(f"✓ Модель загружена: {INSWAPPER_MODEL_PATH}")
    except Exception as e:
        logger.error(f"✗ Ошибка при загрузке модели: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Не удалось загрузить модель InsightFace: {str(e)}"
        )


def _init_models():
    """Инициализирует модели InsightFace"""
    global _face_analysis, _face_swapper
    
    if _face_analysis is not None and _face_swapper is not None:
        return
    
    try:
        import insightface
        
        # Инициализируем FaceAnalysis
        logger.info("Инициализация InsightFace FaceAnalysis...")
        _face_analysis = insightface.app.FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
        _face_analysis.prepare(ctx_id=-1, det_size=(640, 640))
        logger.info("✓ FaceAnalysis инициализирован")
        
        # Скачиваем и загружаем модель inswapper
        _download_model_if_needed()
        
        # Инициализируем FaceSwapper
        logger.info("Инициализация FaceSwapper...")
        _face_swapper = insightface.model_zoo.get_model(str(INSWAPPER_MODEL_PATH), providers=['CPUExecutionProvider'])
        logger.info("✓ FaceSwapper инициализирован")
        
    except ImportError:
        raise HTTPException(
            status_code=500,
            detail="InsightFace не установлен. Установите: pip install insightface"
        )
    except Exception as e:
        logger.error(f"✗ Ошибка при инициализации InsightFace: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при инициализации InsightFace: {str(e)}"
        )


def apply_face_swap(source_img_bytes: bytes, target_img_bytes: bytes) -> bytes:
    """
    Применяет face swap: заменяет лицо на target изображении лицом из source изображения.
    
    Args:
        source_img_bytes: Байты изображения с лицом ребёнка (source)
        target_img_bytes: Байты изображения для замены лица (target)
    
    Returns:
        bytes: Байты результирующего изображения (JPEG)
    """
    # Инициализируем модели при первом вызове
    _init_models()
    
    try:
        # Декодируем изображения из байтов
        source_np = np.frombuffer(source_img_bytes, np.uint8)
        source_img = cv2.imdecode(source_np, cv2.IMREAD_COLOR)
        
        target_np = np.frombuffer(target_img_bytes, np.uint8)
        target_img = cv2.imdecode(target_np, cv2.IMREAD_COLOR)
        
        if source_img is None:
            raise HTTPException(status_code=400, detail="Не удалось декодировать source изображение")
        if target_img is None:
            raise HTTPException(status_code=400, detail="Не удалось декодировать target изображение")
        
        # Находим лица на обоих изображениях
        source_faces = _face_analysis.get(source_img)
        target_faces = _face_analysis.get(target_img)
        
        if len(source_faces) == 0:
            raise HTTPException(status_code=400, detail="Лицо не найдено на source изображении")
        if len(target_faces) == 0:
            raise HTTPException(status_code=400, detail="Лицо не найдено на target изображении")
        
        # Используем первое найденное лицо
        source_face = source_faces[0]
        target_face = target_faces[0]
        
        # Применяем face swap
        result_img = _face_swapper.get(target_img, target_face, source_face, paste_back=True)
        
        # Кодируем результат в JPEG
        _, encoded_img = cv2.imencode('.jpg', result_img, [cv2.IMWRITE_JPEG_QUALITY, 95])
        
        return encoded_img.tobytes()
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Ошибка при применении face swap: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при применении face swap: {str(e)}"
        )

