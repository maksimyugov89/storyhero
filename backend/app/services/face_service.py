"""
Сервис для создания и верификации face profile ребёнка.
Использует InsightFace для извлечения embeddings и создания reference изображения.
"""
import logging
import os
from typing import List, Tuple, Optional
import cv2
import numpy as np
from PIL import Image
import insightface
from fastapi import HTTPException

from .storage import BASE_UPLOAD_DIR, get_server_base_url

logger = logging.getLogger(__name__)

# Глобальная переменная для модели (singleton)
_face_analyzer = None


def _get_face_analyzer():
    """Получить или создать экземпляр FaceAnalyzer (singleton)."""
    global _face_analyzer
    if _face_analyzer is None:
        try:
            # Используем buffalo_l для лучшего качества (как указано в требованиях)
            model = insightface.app.FaceAnalysis(name='buffalo_l', providers=['CPUExecutionProvider'])
            model.prepare(ctx_id=0, det_size=(640, 640))
            _face_analyzer = model
            logger.info("✓ Модель InsightFace FaceAnalysis (buffalo_l) загружена для face profile")
        except Exception as e:
            logger.error(f"❌ Ошибка при загрузке модели InsightFace: {str(e)}")
            raise HTTPException(
                status_code=500,
                detail=f"Не удалось загрузить модель InsightFace: {str(e)}"
            )
    return _face_analyzer


def load_images_from_uploads(paths: List[str]) -> List[np.ndarray]:
    """
    Загрузить изображения из путей (локальных файлов или URL).
    
    Args:
        paths: Список путей к изображениям (локальные пути или URL)
    
    Returns:
        List[np.ndarray]: Список изображений в формате BGR (для OpenCV)
    
    Raises:
        HTTPException: Если не удалось загрузить изображения
    """
    images = []
    for path in paths:
        try:
            # Если это URL, извлекаем локальный путь
            if "/static/" in path or "/uploads/" in path:
                # Формат: /static/children/{child_id}/filename.jpg или /uploads/...
                relative_path = path.split("/static/", 1)[-1] if "/static/" in path else path.split("/uploads/", 1)[-1]
                local_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
            else:
                local_path = path
            
            if not os.path.exists(local_path):
                logger.warning(f"⚠️ Файл не найден: {local_path}")
                continue
            
            # Загружаем изображение
            img = cv2.imread(local_path)
            if img is None:
                logger.warning(f"⚠️ Не удалось загрузить изображение: {local_path}")
                continue
            
            images.append(img)
            logger.debug(f"✓ Загружено изображение: {local_path}, размер: {img.shape}")
        except Exception as e:
            logger.warning(f"⚠️ Ошибка при загрузке {path}: {e}")
            continue
    
    if not images:
        raise HTTPException(
            status_code=400,
            detail="Не удалось загрузить ни одного изображения"
        )
    
    return images


def detect_best_face(img: np.ndarray) -> Tuple[np.ndarray, np.ndarray, float]:
    """
    Обнаружить лучшее лицо на изображении.
    
    Args:
        img: Изображение в формате BGR
    
    Returns:
        Tuple[embedding, face_crop, det_score]:
            - embedding: numpy array float32 (512 dim)
            - face_crop: обрезанное изображение лица
            - det_score: confidence score детекции
    
    Raises:
        HTTPException: Если лицо не найдено
    """
    analyzer = _get_face_analyzer()
    
    # Детекция лиц
    faces = analyzer.get(img)
    
    if not faces or len(faces) == 0:
        raise HTTPException(
            status_code=400,
            detail="Лицо не обнаружено на изображении"
        )
    
    # Выбираем лицо с максимальной площадью bbox или максимальным det_score
    best_face = max(faces, key=lambda f: f.bbox[2] * f.bbox[3] if len(f.bbox) >= 4 else f.det_score)
    
    embedding = best_face.embedding.astype(np.float32)
    det_score = best_face.det_score
    
    # Обрезаем лицо
    bbox = best_face.bbox.astype(int)
    x1, y1, x2, y2 = bbox[0], bbox[1], bbox[2], bbox[3]
    
    # Добавляем небольшой отступ
    padding = 20
    h, w = img.shape[:2]
    x1 = max(0, x1 - padding)
    y1 = max(0, y1 - padding)
    x2 = min(w, x2 + padding)
    y2 = min(h, y2 + padding)
    
    face_crop = img[y1:y2, x1:x2]
    
    logger.debug(f"✓ Обнаружено лицо: bbox=({x1},{y1},{x2},{y2}), score={det_score:.3f}")
    
    return embedding, face_crop, det_score


def build_face_profile(image_paths: List[str], child_id: int) -> dict:
    """
    Создать face profile из нескольких фотографий ребёнка.
    
    Args:
        image_paths: Список путей к фотографиям
        child_id: ID ребёнка
    
    Returns:
        dict с ключами:
            - mean_embedding_bytes: bytes (сериализованный numpy array)
            - reference_rel_path: str (относительный путь к reference.png)
            - reference_public_url: str (публичный URL)
            - valid_faces: int (количество валидных лиц)
            - used_faces: int (количество использованных лиц)
    
    Raises:
        HTTPException: Если недостаточно валидных лиц (минимум 3 из 5)
    """
    logger.info(f"🔄 Создание face profile для child_id={child_id} из {len(image_paths)} фотографий")
    
    # Загружаем изображения
    images = load_images_from_uploads(image_paths)
    logger.info(f"✓ Загружено {len(images)} изображений")
    
    # Извлекаем embeddings и выбираем лучшее лицо
    embeddings = []
    best_face_crop = None
    best_score = 0.0
    
    valid_faces = 0
    for i, img in enumerate(images):
        try:
            embedding, face_crop, det_score = detect_best_face(img)
            embeddings.append(embedding)
            valid_faces += 1
            
            # Выбираем лучшее лицо для reference (максимальный det_score)
            if det_score > best_score:
                best_score = det_score
                best_face_crop = face_crop
            
            logger.debug(f"✓ Лицо {i+1}: embedding shape={embedding.shape}, score={det_score:.3f}")
        except HTTPException as e:
            logger.warning(f"⚠️ Пропущено изображение {i+1}: {e.detail}")
            continue
        except Exception as e:
            logger.warning(f"⚠️ Ошибка при обработке изображения {i+1}: {e}")
            continue
    
    # Проверяем минимальное количество валидных лиц
    MIN_VALID_FACES = 3
    if valid_faces < MIN_VALID_FACES:
        raise HTTPException(
            status_code=400,
            detail=f"Недостаточно валидных лиц: найдено {valid_faces}, требуется минимум {MIN_VALID_FACES}"
        )
    
    # Усредняем embeddings
    if len(embeddings) == 0:
        raise HTTPException(status_code=400, detail="Не удалось извлечь ни одного embedding")
    
    mean_embedding = np.mean(embeddings, axis=0).astype(np.float32)
    logger.info(f"✓ Усреднено {len(embeddings)} embeddings, финальный shape={mean_embedding.shape}")
    
    # Сохраняем embedding как bytes
    mean_embedding_bytes = mean_embedding.tobytes()
    
    # Создаём reference изображение 512x512
    if best_face_crop is None:
        raise HTTPException(status_code=400, detail="Не удалось получить reference изображение")
    
    # Конвертируем BGR в RGB для PIL
    face_rgb = cv2.cvtColor(best_face_crop, cv2.COLOR_BGR2RGB)
    face_pil = Image.fromarray(face_rgb)
    
    # Resize до 512x512 с сохранением пропорций и центрированием
    face_pil.thumbnail((512, 512), Image.Resampling.LANCZOS)
    
    # Создаём квадратное изображение 512x512 с центрированием
    reference_img = Image.new('RGB', (512, 512), (255, 255, 255))
    x_offset = (512 - face_pil.width) // 2
    y_offset = (512 - face_pil.height) // 2
    reference_img.paste(face_pil, (x_offset, y_offset))
    
    # Сохраняем reference.png
    faces_dir = os.path.join(BASE_UPLOAD_DIR, "faces", str(child_id))
    os.makedirs(faces_dir, exist_ok=True)
    
    reference_path = os.path.join(faces_dir, "reference.png")
    reference_img.save(reference_path, "PNG")
    logger.info(f"✓ Reference изображение сохранено: {reference_path}")
    
    # Формируем относительный путь и публичный URL
    reference_rel_path = f"faces/{child_id}/reference.png"
    base_url = get_server_base_url()
    if ":8000" in base_url:
        base_url = base_url.replace(":8000", "")
    reference_public_url = f"{base_url}/static/{reference_rel_path}"
    
    return {
        "mean_embedding_bytes": mean_embedding_bytes,
        "reference_rel_path": reference_rel_path,
        "reference_public_url": reference_public_url,
        "valid_faces": valid_faces,
        "used_faces": len(embeddings)
    }


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    """
    Вычислить cosine similarity между двумя embeddings.
    
    Args:
        a: numpy array (embedding)
        b: numpy array (embedding)
    
    Returns:
        float: cosine similarity (0.0 - 1.0)
    """
    # Нормализуем векторы
    a_norm = a / (np.linalg.norm(a) + 1e-8)
    b_norm = b / (np.linalg.norm(b) + 1e-8)
    
    # Cosine similarity
    similarity = np.dot(a_norm, b_norm)
    return float(similarity)


def verify_face(mean_embedding_bytes: bytes, generated_img_bytes: bytes, threshold: float = 0.60) -> Tuple[bool, float]:
    """
    Верифицировать лицо на сгенерированном изображении.
    
    Args:
        mean_embedding_bytes: bytes (сериализованный embedding из БД)
        generated_img_bytes: bytes (сгенерированное изображение)
        threshold: порог similarity (по умолчанию 0.60)
    
    Returns:
        Tuple[verified: bool, similarity: float]
    """
    try:
        # Восстанавливаем embedding из bytes
        # Buffalo_l создаёт embedding размером 512 float32 = 2048 bytes
        mean_embedding = np.frombuffer(mean_embedding_bytes, dtype=np.float32)
        if len(mean_embedding) != 512:
            logger.warning(f"⚠️ Неожиданный размер embedding: {len(mean_embedding)}, ожидается 512")
        
        # Загружаем сгенерированное изображение
        nparr = np.frombuffer(generated_img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if img is None:
            logger.warning("⚠️ Не удалось декодировать сгенерированное изображение")
            return False, 0.0
        
        # Извлекаем embedding из сгенерированного изображения
        try:
            generated_embedding, _, _ = detect_best_face(img)
        except HTTPException:
            logger.warning("⚠️ Лицо не обнаружено на сгенерированном изображении")
            return False, 0.0
        
        # Вычисляем similarity
        similarity = cosine_similarity(mean_embedding, generated_embedding)
        verified = similarity >= threshold
        
        logger.info(f"✓ Face verification: similarity={similarity:.3f}, threshold={threshold}, verified={verified}")
        
        return verified, similarity
    except Exception as e:
        logger.error(f"❌ Ошибка при верификации лица: {e}", exc_info=True)
        return False, 0.0

