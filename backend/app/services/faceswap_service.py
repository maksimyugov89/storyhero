"""
Сервис для Face Swap с использованием InsightFace
"""
import os
import cv2
import numpy as np
from pathlib import Path
from fastapi import HTTPException
import logging
import requests

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
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    
    # Список альтернативных URL для загрузки модели (пробуем разные источники)
    # ПРИОРИТЕТ: Рабочий URL из facefusion-assets models-3.0.0 (возвращает 302 редирект)
    model_urls = [
        # РАБОЧИЙ URL из facefusion-assets (models-3.0.0) - ПРИОРИТЕТ #1
        "https://github.com/facefusion/facefusion-assets/releases/download/models-3.0.0/inswapper_128.onnx",
        # Альтернативные версии (на случай если основной недоступен)
        "https://github.com/facefusion/facefusion-assets/releases/download/v2.1.0/inswapper_128.onnx",
        "https://github.com/facefusion/facefusion-assets/releases/download/v2.0.0/inswapper_128.onnx",
        "https://github.com/facefusion/facefusion-assets/releases/download/models/inswapper_128.onnx",
        # HuggingFace (может требовать токен)
        "https://huggingface.co/deepinsight/inswapper/resolve/main/inswapper_128.onnx",
        # Прямая ссылка из репозитория InsightFace
        "https://github.com/deepinsight/insightface/releases/download/v0.7.3/inswapper_128.onnx",
    ]
    
    import urllib.request
    import urllib.error
    import requests
    
    last_error = None
    
    # Сначала пробуем через requests (лучше работает с редиректами и заголовками)
    for model_url in model_urls:
        try:
            logger.info(f"Попытка загрузки с {model_url}...")
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                'Accept': '*/*',
                'Accept-Language': 'en-US,en;q=0.9',
                'Referer': 'https://huggingface.co/' if 'huggingface' in model_url else 'https://github.com/'
            }
            
            response = requests.get(model_url, headers=headers, timeout=60, stream=True, allow_redirects=True)
            
            if response.status_code == 200:
                content_length = response.headers.get('Content-Length')
                if content_length:
                    logger.info(f"Размер модели: {int(content_length) / 1024 / 1024:.2f} MB")
                
                # Загружаем файл по частям
                total_size = 0
                with open(str(INSWAPPER_MODEL_PATH), 'wb') as f:
                    for chunk in response.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)
                            total_size += len(chunk)
                
                # Проверяем, что файл загружен полностью (модель ~500MB)
                if INSWAPPER_MODEL_PATH.exists():
                    file_size = INSWAPPER_MODEL_PATH.stat().st_size
                    # Модель должна быть около 500MB, проверяем минимум 100MB
                    if file_size > 100 * 1024 * 1024:
                        logger.info(f"✓ Модель загружена полностью: {INSWAPPER_MODEL_PATH} ({file_size / 1024 / 1024:.2f} MB)")
                        return
                    else:
                        if INSWAPPER_MODEL_PATH.exists():
                            INSWAPPER_MODEL_PATH.unlink()
                        raise Exception(f"Файл загружен не полностью: {file_size / 1024 / 1024:.2f} MB (ожидается ~500MB)")
                else:
                    raise Exception("Файл не был создан")
            else:
                last_error = f"HTTP {response.status_code}: {response.reason}"
                logger.warning(f"✗ Не удалось загрузить с {model_url}: {last_error}")
                continue
        except requests.exceptions.RequestException as e:
            last_error = f"Request error: {str(e)}"
            logger.warning(f"✗ Ошибка при загрузке с {model_url}: {last_error}")
            continue
        except Exception as e:
            last_error = str(e)
            logger.warning(f"✗ Ошибка при загрузке с {model_url}: {last_error}")
            continue
    
    # Если requests не сработал, пробуем urllib как fallback
    logger.info("Пробуем загрузку через urllib...")
    for model_url in model_urls:
        try:
            logger.info(f"Попытка загрузки через urllib с {model_url}...")
            req = urllib.request.Request(model_url)
            req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
            req.add_header('Accept', '*/*')
            
            with urllib.request.urlopen(req, timeout=60) as response:
                if response.status == 200:
                    content_length = response.headers.get('Content-Length')
                    if content_length:
                        logger.info(f"Размер модели: {int(content_length) / 1024 / 1024:.2f} MB")
                    
                    with open(str(INSWAPPER_MODEL_PATH), 'wb') as f:
                        while True:
                            chunk = response.read(8192)
                            if not chunk:
                                break
                            f.write(chunk)
                    
                    if INSWAPPER_MODEL_PATH.exists() and INSWAPPER_MODEL_PATH.stat().st_size > 1000:
                        logger.info(f"✓ Модель загружена через urllib: {INSWAPPER_MODEL_PATH}")
                        return
        except Exception as e:
            last_error = str(e)
            continue
    
    # Если все URL не сработали, пробуем использовать InsightFace для автоматической загрузки
    try:
        logger.info("Попытка автоматической загрузки через InsightFace...")
        import insightface
        # InsightFace может автоматически загрузить модель в ~/.insightface/models/
        # Пробуем использовать встроенный механизм model_zoo
        try:
            # Пытаемся загрузить модель через InsightFace (он может скачать автоматически)
            temp_swapper = insightface.model_zoo.get_model('inswapper_128.onnx', download=True, download_zip=False)
            # Если успешно, копируем путь модели
            if hasattr(temp_swapper, 'model_path') and Path(temp_swapper.model_path).exists():
                import shutil
                shutil.copy2(temp_swapper.model_path, INSWAPPER_MODEL_PATH)
                logger.info(f"✓ Модель загружена через InsightFace и скопирована: {INSWAPPER_MODEL_PATH}")
                return
        except:
            pass
        
        # Альтернатива: проверяем стандартный путь InsightFace
        insightface_model_path = Path.home() / ".insightface" / "models" / "inswapper_128.onnx"
        if insightface_model_path.exists():
            logger.info(f"✓ Модель найдена в {insightface_model_path}, копируем...")
            import shutil
            shutil.copy2(insightface_model_path, INSWAPPER_MODEL_PATH)
            logger.info(f"✓ Модель скопирована: {INSWAPPER_MODEL_PATH}")
            return
    except Exception as e:
        logger.warning(f"✗ Не удалось использовать InsightFace для загрузки: {str(e)}")
    
    # Если ничего не помогло, выбрасываем ошибку
    error_msg = f"Не удалось загрузить модель inswapper_128.onnx ни с одного источника. Последняя ошибка: {last_error}"
    logger.error(f"✗ {error_msg}")
    raise HTTPException(
        status_code=500,
        detail=error_msg
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
        
        # Скачиваем и загружаем модель inswapper (КРИТИЧЕСКИ ВАЖНО!)
        try:
            _download_model_if_needed()
        except HTTPException as e:
            # Если не удалось загрузить модель - это КРИТИЧЕСКАЯ ошибка для приложения
            error_msg = f"КРИТИЧЕСКАЯ ОШИБКА: Не удалось загрузить модель inswapper для face swap: {e.detail}"
            logger.error(f"❌ {error_msg}")
            logger.error("❌ Face swap - это основная функция приложения! Без него книга не будет персонализирована!")
            # НЕ продолжаем работу без модели - это критично!
            raise HTTPException(
                status_code=500,
                detail=error_msg + " Пожалуйста, проверьте подключение к интернету и доступность источников моделей."
            )
        
        # Инициализируем FaceSwapper только если модель загружена
        if INSWAPPER_MODEL_PATH.exists():
            logger.info("Инициализация FaceSwapper...")
            _face_swapper = insightface.model_zoo.get_model(str(INSWAPPER_MODEL_PATH), providers=['CPUExecutionProvider'])
            logger.info("✓ FaceSwapper инициализирован")
        else:
            logger.warning("⚠ Модель inswapper не найдена, FaceSwapper не будет инициализирован")
            _face_swapper = None
        
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


def detect_face_in_image(image_bytes: bytes) -> bool:
    """
    Проверяет, есть ли лицо на изображении.
    Используется для пост-проверки сгенерированных изображений.
    
    Args:
        image_bytes: Байты изображения для проверки
    
    Returns:
        bool: True если лицо найдено, False если нет
    """
    # Инициализируем модели при первом вызове
    _init_models()
    
    if _face_analysis is None:
        logger.warning("⚠ FaceAnalysis не инициализирован, пропускаем проверку")
        return True  # Если нет анализа - считаем что лицо есть (fallback)
    
    try:
        # Декодируем изображение
        img_np = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(img_np, cv2.IMREAD_COLOR)
        
        if img is None:
            logger.warning("⚠ Не удалось декодировать изображение для проверки лица")
            return False
        
        # Ищем лица
        faces = _face_analysis.get(img)
        
        if len(faces) > 0:
            # Дополнительно проверяем размер и качество найденного лица
            face = faces[0]
            bbox = face.bbox
            face_width = bbox[2] - bbox[0]
            face_height = bbox[3] - bbox[1]
            img_height, img_width = img.shape[:2]
            
            # Лицо должно занимать минимум 5% от размера изображения
            face_area_ratio = (face_width * face_height) / (img_width * img_height)
            
            if face_area_ratio >= 0.05:
                logger.info(f"✓ Лицо найдено, размер: {face_width:.0f}x{face_height:.0f}px ({face_area_ratio*100:.1f}% изображения)")
                return True
            else:
                logger.warning(f"⚠ Лицо слишком маленькое: {face_area_ratio*100:.1f}% изображения (нужно минимум 5%)")
                return False
        
        logger.warning("⚠ Лицо не найдено на изображении")
        return False
        
    except Exception as e:
        logger.error(f"✗ Ошибка при проверке лица: {str(e)}")
        return False


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
    
    # Проверяем, что FaceSwapper доступен
    if _face_swapper is None:
        raise HTTPException(
            status_code=503,
            detail="Face swap недоступен: модель inswapper не загружена. Используйте оригинальное изображение."
        )
    
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

