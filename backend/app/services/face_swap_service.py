"""
Сервис для применения face swap к изображениям через InsightFace.
Использует InsightFace для замены лица на сгенерированных изображениях.
КРИТИЧЕСКИ ВАЖНО: Использует ВСЕ фотографии ребёнка (до 5) для создания идеального сходства!
"""
import logging
import os
from typing import Optional, List
import cv2
import numpy as np
import insightface
from fastapi import HTTPException

logger = logging.getLogger(__name__)

# Глобальные переменные для моделей (ленивая загрузка)
_face_analyzer = None
_face_swapper = None


def _get_face_analyzer():
    """Получить или создать экземпляр FaceAnalyzer (ленивая загрузка)."""
    global _face_analyzer
    if _face_analyzer is None:
        try:
            # Используем более легкую модель buffalo_s вместо buffalo_l для экономии памяти
            # buffalo_s занимает ~50MB вместо ~275MB у buffalo_l
            model = insightface.app.FaceAnalysis(name='buffalo_s', providers=['CPUExecutionProvider'])
            model.prepare(ctx_id=0, det_size=(640, 640))
            _face_analyzer = model
            logger.info("✓ Модель InsightFace FaceAnalysis (buffalo_s) загружена")
        except Exception as e:
            logger.error(f"❌ Ошибка при загрузке модели InsightFace: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Не удалось загрузить модель face swap: {str(e)}"
            )
    return _face_analyzer


def _get_face_swapper():
    """Получить или создать экземпляр FaceSwapper (ленивая загрузка)."""
    global _face_swapper
    if _face_swapper is None:
        try:
            # Пытаемся загрузить модель для face swap
            # Используем прямую ссылку на модель для более надежной загрузки
            import urllib.request
            import tempfile
            import zipfile
            
            model_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'models')
            os.makedirs(model_dir, exist_ok=True)
            model_path = os.path.join(model_dir, 'inswapper_128.onnx')
            
            # Если модель уже есть, используем её
            if os.path.exists(model_path):
                logger.info(f"✓ Используем существующую модель: {model_path}")
                model = insightface.model_zoo.get_model(model_path)
            else:
                # Пытаемся скачать модель
                logger.info("📥 Загрузка модели FaceSwapper...")
                model = insightface.model_zoo.get_model('inswapper_128.onnx', download=True, download_zip=True, root=model_dir)
            
            _face_swapper = model
            logger.info("✓ Модель InsightFace FaceSwapper загружена")
        except Exception as e:
            logger.warning(f"⚠️ Не удалось загрузить FaceSwapper, face swap будет пропущен: {str(e)}")
            logger.warning(f"⚠️ Детали ошибки: {type(e).__name__}: {str(e)}")
            _face_swapper = None
    return _face_swapper


async def apply_face_swap_with_reference(
    generated_image_bytes: bytes,
    reference_image_path: str
) -> bytes:
    """
    Применяет face swap к сгенерированному изображению используя reference.png из face profile.
    Оптимизировано для обложки с максимальным сходством.
    
    Args:
        generated_image_bytes: Байты сгенерированного изображения
        reference_image_path: Путь к reference.png (из face profile)
    
    Returns:
        bytes: Байты изображения с применённым face swap
    """
    try:
        # Загружаем модели
        face_analyzer = _get_face_analyzer()
        face_swapper = _get_face_swapper()
        
        if face_swapper is None:
            logger.warning("⚠️ FaceSwapper недоступен, возвращаем оригинальное изображение")
            return generated_image_bytes
        
        if not os.path.exists(reference_image_path):
            logger.warning(f"⚠️ Reference изображение не найдено: {reference_image_path}")
            return generated_image_bytes
        
        # Загружаем reference изображение
        reference_image = cv2.imread(reference_image_path)
        if reference_image is None:
            logger.warning(f"⚠️ Не удалось загрузить reference изображение: {reference_image_path}")
            return generated_image_bytes
        
        # Находим лицо на reference изображении
        reference_faces = face_analyzer.get(reference_image)
        if not reference_faces or len(reference_faces) == 0:
            logger.warning(f"⚠️ Лицо не найдено на reference изображении: {reference_image_path}")
            return generated_image_bytes
        
        source_face = reference_faces[0]  # Используем первое найденное лицо
        logger.info(f"✓ Лицо найдено на reference изображении: {reference_image_path}")
        
        # Загружаем сгенерированное изображение
        generated_image_array = np.frombuffer(generated_image_bytes, np.uint8)
        generated_image = cv2.imdecode(generated_image_array, cv2.IMREAD_COLOR)
        
        if generated_image is None:
            logger.warning(f"⚠️ Не удалось декодировать сгенерированное изображение")
            return generated_image_bytes
        
        # Находим лица на сгенерированном изображении
        target_faces = face_analyzer.get(generated_image)
        if not target_faces or len(target_faces) == 0:
            logger.warning(f"⚠️ Лицо не найдено на сгенерированном изображении")
            return generated_image_bytes
        
        # Применяем face swap к каждому найденному лицу
        for target_face in target_faces:
            try:
                generated_image = face_swapper.get(generated_image, target_face, source_face, paste_back=True)
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при применении face swap: {str(e)}")
                continue
        
        # Конвертируем обратно в байты
        _, encoded_image = cv2.imencode('.jpg', generated_image, [cv2.IMWRITE_JPEG_QUALITY, 95])
        result_bytes = encoded_image.tobytes()
        
        # Освобождаем память
        del generated_image
        del generated_image_array
        del encoded_image
        del reference_image
        
        logger.info(f"✓ Face swap применён успешно с reference изображением")
        return result_bytes
        
    except Exception as e:
        logger.error(f"❌ Ошибка при применении face swap с reference: {str(e)}", exc_info=True)
        # В случае ошибки возвращаем оригинальное изображение
        return generated_image_bytes


async def apply_face_swap(
    generated_image_bytes: bytes, 
    child_photo_path: Optional[str] = None,
    child_photo_paths: Optional[List[str]] = None
) -> bytes:
    """
    Применяет face swap к сгенерированному изображению.
    Использует ВСЕ фотографии ребёнка для создания лучшего сходства.
    
    Args:
        generated_image_bytes: Байты сгенерированного изображения
        child_photo_path: Путь к файлу фотографии ребёнка (для обратной совместимости)
        child_photo_paths: Список путей к фотографиям ребёнка (предпочтительно, до 5 фото)
    
    Returns:
        bytes: Байты изображения с применённым face swap
    """
    try:
        # Загружаем модели
        face_analyzer = _get_face_analyzer()
        face_swapper = _get_face_swapper()
        
        if face_swapper is None:
            logger.warning("⚠️ FaceSwapper недоступен, возвращаем оригинальное изображение")
            return generated_image_bytes
        
        # Собираем все доступные фотографии
        all_photo_paths = []
        if child_photo_paths:
            all_photo_paths.extend(child_photo_paths)
        if child_photo_path and child_photo_path not in all_photo_paths:
            all_photo_paths.append(child_photo_path)
        
        if not all_photo_paths:
            logger.warning("⚠️ Нет фотографий ребёнка для face swap")
            return generated_image_bytes
        
        # Ограничиваем до 5 фотографий для лучшей производительности
        all_photo_paths = all_photo_paths[:5]
        logger.info(f"🎭 Использование {len(all_photo_paths)} фотографий ребёнка для face swap")
        
        # Собираем лица со всех фотографий
        all_faces = []
        for photo_path in all_photo_paths:
            if not os.path.exists(photo_path):
                logger.warning(f"⚠️ Файл фотографии ребёнка не найден: {photo_path}")
                continue
            
            child_image = cv2.imread(photo_path)
            if child_image is None:
                logger.warning(f"⚠️ Не удалось загрузить изображение ребёнка: {photo_path}")
                continue
            
            # Находим лицо на фото ребёнка
            child_faces = face_analyzer.get(child_image)
            if child_faces and len(child_faces) > 0:
                all_faces.append(child_faces[0])  # Используем первое найденное лицо
                logger.info(f"✓ Лицо найдено на фото: {photo_path}")
            else:
                logger.warning(f"⚠️ Лицо не найдено на фото ребёнка: {photo_path}")
            
            # Освобождаем память после обработки каждого изображения
            del child_image
        
        if not all_faces:
            logger.warning("⚠️ Не удалось найти лицо ни на одной фотографии ребёнка")
            return generated_image_bytes
        
        # Используем лучшее лицо (первое найденное) или можно усреднить
        # Для лучшего сходства используем лицо с наибольшим размером (наиболее детализированное)
        best_face = max(all_faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        source_face = best_face
        logger.info(f"✓ Используется лучшее лицо из {len(all_faces)} найденных лиц")
        
        # Освобождаем память от списка всех лиц (оставляем только лучшее)
        del all_faces
        
        # Загружаем сгенерированное изображение
        generated_image_array = np.frombuffer(generated_image_bytes, np.uint8)
        generated_image = cv2.imdecode(generated_image_array, cv2.IMREAD_COLOR)
        
        if generated_image is None:
            logger.warning(f"⚠️ Не удалось декодировать сгенерированное изображение")
            return generated_image_bytes
        
        # Находим лица на сгенерированном изображении
        target_faces = face_analyzer.get(generated_image)
        if not target_faces or len(target_faces) == 0:
            logger.warning(f"⚠️ Лицо не найдено на сгенерированном изображении")
            return generated_image_bytes
        
        # Применяем face swap к каждому найденному лицу
        for target_face in target_faces:
            try:
                generated_image = face_swapper.get(generated_image, target_face, source_face, paste_back=True)
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при применении face swap: {str(e)}")
                continue
        
        # Конвертируем обратно в байты
        _, encoded_image = cv2.imencode('.jpg', generated_image, [cv2.IMWRITE_JPEG_QUALITY, 95])
        result_bytes = encoded_image.tobytes()
        
        # Освобождаем память от изображений
        del generated_image
        del generated_image_array
        del encoded_image
        
        logger.info(f"✓ Face swap применён успешно")
        return result_bytes
        
    except Exception as e:
        logger.error(f"❌ Ошибка при применении face swap: {str(e)}", exc_info=True)
        # В случае ошибки возвращаем оригинальное изображение
        return generated_image_bytes
