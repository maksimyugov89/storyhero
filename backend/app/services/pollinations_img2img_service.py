"""
Сервис для генерации изображений через Pollinations.ai с использованием img2img (image-to-image).
Использует reference изображение для сохранения лица ребёнка.
"""
import logging
import os
import time
import asyncio
from typing import Optional, Tuple
import httpx
import urllib.parse
from fastapi import HTTPException

from .storage import get_server_base_url

logger = logging.getLogger(__name__)

# Pollinations.ai API
POLLINATIONS_IMG2IMG_BASE_URL = "https://image.pollinations.ai/prompt"
DEFAULT_STRENGTH = 0.25  # Сила влияния reference изображения (0.0 - 1.0)
DEFAULT_MAX_RETRIES = 3
DEFAULT_BACKOFF = 2.0  # секунды


def build_prompt(base_prompt: str, strict_identity: bool = True, is_cover: bool = False) -> str:
    """
    Построить промпт с жёсткими инструкциями для сохранения лица.
    Для обложки также очищает промпт от инструкций о тексте.
    
    Args:
        base_prompt: Базовый промпт для генерации
        strict_identity: Если True, добавляет строгие инструкции о сохранении лица
        is_cover: Флаг, что это промпт для обложки
    
    Returns:
        str: Улучшенный промпт
    """
    # Для обложки очищаем промпт от инструкций о тексте
    if is_cover:
        from .prompt_sanitizer import strip_title_instructions
        base_prompt = strip_title_instructions(base_prompt)
        logger.info(f"🧼 Cover prompt sanitized in build_prompt (img2img)")
    
    if strict_identity:
        identity_instructions = (
            "CRITICAL: Use the EXACT SAME child face as shown in the reference image. "
            "Do NOT change facial features, eye color, hair color, or facial proportions. "
            "The face must match the reference image with 100% accuracy. "
            "Same eyes, same nose, same mouth, same overall facial structure. "
            "Only change the background, clothing, and scene elements, but keep the face identical."
        )
        return f"{base_prompt}. {identity_instructions}"
    return base_prompt


async def generate_img2img(
    prompt: str,
    reference_image_url: str,
    strength: float = DEFAULT_STRENGTH,
    seed: Optional[int] = None,
    max_retries: int = DEFAULT_MAX_RETRIES
) -> bytes:
    """
    Сгенерировать изображение через Pollinations.ai img2img.
    
    Args:
        prompt: Текстовый промпт для генерации
        reference_image_url: URL reference изображения (публичный URL)
        strength: Сила влияния reference изображения (0.0 - 1.0)
        seed: Случайный seed для генерации (опционально)
        max_retries: Максимальное количество попыток при ошибке
    
    Returns:
        bytes: Байты сгенерированного изображения (JPEG/PNG)
    
    Raises:
        HTTPException: Если генерация не удалась после всех попыток
    """
    # Pollinations.ai поддерживает img2img через параметр image в URL
    # Формат: https://image.pollinations.ai/prompt/{prompt}?image={reference_url}&strength={strength}
    
    last_error = None
    for attempt in range(max_retries + 1):
        try:
            # Кодируем промпт
            encoded_prompt = urllib.parse.quote(prompt, safe='')
            
            # Формируем URL
            params = {
                "width": 1024,
                "height": 1024,
                "model": "flux",
                "nologo": "true",
                "enhance": "true",
                "image": reference_image_url,  # Reference изображение
                "strength": str(strength),  # Сила влияния
            }
            
            if seed:
                params["seed"] = str(seed)
            else:
                import random
                params["seed"] = str(random.randint(1, 1000000))
            
            # Формируем полный URL
            query_string = urllib.parse.urlencode(params)
            api_url = f"{POLLINATIONS_IMG2IMG_BASE_URL}/{encoded_prompt}?{query_string}"
            
            logger.info(
                f"🔄 Запрос к Pollinations.ai img2img (попытка {attempt + 1}/{max_retries + 1}): "
                f"strength={strength}, seed={params.get('seed')}"
            )
            
            # Отправляем GET запрос с таймаутом
            timeout = httpx.Timeout(300.0, connect=10.0, read=300.0)  # 5 минут
            
            async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
                logger.info(f"📤 Отправка запроса в Pollinations.ai img2img API...")
                resp = await client.get(api_url)
                
                if resp.status_code == 503:
                    # Сервис временно недоступен
                    if attempt < max_retries:
                        wait_time = DEFAULT_BACKOFF * (2 ** attempt)
                        logger.warning(f"⚠️ Pollinations.ai недоступен (503), повтор через {wait_time:.1f}с...")
                        await asyncio.sleep(wait_time)
                        continue
                    else:
                        raise HTTPException(
                            status_code=503,
                            detail="Pollinations.ai временно недоступен"
                        )
                
                if resp.status_code == 429:
                    # Rate limit
                    if attempt < max_retries:
                        wait_time = DEFAULT_BACKOFF * (2 ** attempt)
                        logger.warning(f"⚠️ Rate limit (429), повтор через {wait_time:.1f}с...")
                        await asyncio.sleep(wait_time)
                        continue
                    else:
                        raise HTTPException(
                            status_code=429,
                            detail="Превышен лимит запросов к Pollinations.ai"
                        )
                
                if resp.status_code != 200:
                    error_msg = f"Pollinations.ai вернул статус {resp.status_code}"
                    if attempt < max_retries:
                        logger.warning(f"⚠️ {error_msg}, повтор через {DEFAULT_BACKOFF * (2 ** attempt):.1f}с...")
                        await asyncio.sleep(DEFAULT_BACKOFF * (2 ** attempt))
                        continue
                    else:
                        raise HTTPException(
                            status_code=500,
                            detail=error_msg
                        )
                
                # Проверяем, что это изображение
                content_type = resp.headers.get("content-type", "")
                if not content_type.startswith("image/"):
                    raise HTTPException(
                        status_code=500,
                        detail=f"Pollinations.ai вернул не изображение: {content_type}"
                    )
                
                image_bytes = resp.content
                if not image_bytes or len(image_bytes) == 0:
                    raise HTTPException(
                        status_code=500,
                        detail="Pollinations.ai вернул пустое изображение"
                    )
                
                logger.info(f"✅ Изображение успешно сгенерировано через Pollinations.ai img2img, размер: {len(image_bytes)} байт")
                return image_bytes
                
        except httpx.TimeoutException:
            last_error = "Таймаут при запросе к Pollinations.ai"
            if attempt < max_retries:
                wait_time = DEFAULT_BACKOFF * (2 ** attempt)
                logger.warning(f"⚠️ {last_error}, повтор через {wait_time:.1f}с...")
                await asyncio.sleep(wait_time)
                continue
        except httpx.RequestError as e:
            last_error = f"Ошибка сети при запросе к Pollinations.ai: {str(e)}"
            if attempt < max_retries:
                wait_time = DEFAULT_BACKOFF * (2 ** attempt)
                logger.warning(f"⚠️ {last_error}, повтор через {wait_time:.1f}с...")
                await asyncio.sleep(wait_time)
                continue
        except HTTPException:
            raise
        except Exception as e:
            last_error = f"Неожиданная ошибка: {str(e)}"
            logger.error(f"❌ {last_error}", exc_info=True)
            if attempt < max_retries:
                wait_time = DEFAULT_BACKOFF * (2 ** attempt)
                logger.warning(f"⚠️ Повтор через {wait_time:.1f}с...")
                await asyncio.sleep(wait_time)
                continue
    
    # Все попытки исчерпаны
    raise HTTPException(
        status_code=500,
        detail=f"Не удалось сгенерировать изображение после {max_retries + 1} попыток. Последняя ошибка: {last_error}"
    )


async def generate_with_verification(
    prompt: str,
    reference_image_url: str,
    mean_embedding_bytes: bytes,
    strength: float = DEFAULT_STRENGTH,
    max_retries: int = DEFAULT_MAX_RETRIES,
    similarity_threshold: float = 0.60,
    seed: Optional[int] = None,
    is_cover: bool = False,
    reference_image_path: Optional[str] = None
) -> Tuple[bytes, dict]:
    """
    Сгенерировать изображение с верификацией лица и автоматической перегенерацией при плохом совпадении.
    
    Для ОБЛОЖКИ (is_cover=True) использует двухэтапный пайплайн:
    1) Pollinations img2img (reference.png)
    2) POST face swap через InsightFace
    3) Верификация similarity
    4) Выбор ЛУЧШЕГО результата
    
    Args:
        prompt: Текстовый промпт
        reference_image_url: URL reference изображения
        mean_embedding_bytes: bytes (embedding из БД)
        strength: Сила влияния reference изображения
        max_retries: Максимальное количество попыток генерации
        similarity_threshold: Порог similarity для верификации
        seed: Начальный seed (опционально)
        is_cover: Флаг, что это обложка (использует двухэтапный пайплайн)
        reference_image_path: Путь к reference.png для face swap (только для обложки)
    
    Returns:
        Tuple[bytes, dict]:
            - bytes: Лучшее сгенерированное изображение
            - dict: метаданные (face_similarity, face_verified, attempts, best_similarity)
    """
    from .face_service import verify_face
    import asyncio
    import random
    
    best_image = None
    best_similarity = 0.0
    attempts = 0
    
    current_seed = seed if seed else random.randint(1, 1000000)
    
    # Для обложки используем двухэтапный пайплайн: img2img + face swap
    if is_cover and reference_image_path:
        logger.info(f"🎯 ДВУХЭТАПНЫЙ ПАЙПЛАЙН для ОБЛОЖКИ: img2img + face swap + верификация")
        
        for attempt_num in range(max_retries):
            attempts += 1
            logger.info(f"🔁 Попытка {attempt_num + 1}/{max_retries} для обложки (seed={current_seed})")
            
            try:
                # ЭТАП 1: Генерируем изображение через img2img
                generated_bytes = await generate_img2img(
                    prompt=prompt,
                    reference_image_url=reference_image_url,
                    strength=strength,
                    seed=current_seed,
                    max_retries=1
                )
                
                # ЭТАП 2: Применяем face swap с reference.png
                from .face_swap_service import apply_face_swap_with_reference
                swapped_bytes = await apply_face_swap_with_reference(
                    generated_image_bytes=generated_bytes,
                    reference_image_path=reference_image_path
                )
                
                # ЭТАП 3: Верифицируем лицо после face swap
                verified, similarity = verify_face(
                    mean_embedding_bytes=mean_embedding_bytes,
                    generated_img_bytes=swapped_bytes,
                    threshold=similarity_threshold
                )
                
                # Сохраняем лучшее изображение (максимальная similarity)
                if similarity > best_similarity:
                    best_similarity = similarity
                    best_image = swapped_bytes
                    logger.info(f"🏆 Новое лучшее изображение: similarity={similarity:.3f} (было {best_similarity:.3f})")
                
                logger.info(
                    f"🔁 Попытка {attempt_num + 1}: similarity={similarity:.3f}, "
                    f"threshold={similarity_threshold}, verified={verified}, "
                    f"best={best_similarity:.3f}"
                )
                
                # Если верификация успешна, продолжаем искать лучшее (но можем вернуть раньше если очень хорошо)
                if verified and similarity >= 0.90:  # Если очень высокое сходство, можно вернуть раньше
                    logger.info(f"✅ Отличное сходство {similarity:.3f} >= 0.90, возвращаем результат")
                    return swapped_bytes, {
                        "face_similarity": similarity,
                        "face_verified": True,
                        "attempts": attempt_num + 1,
                        "best_similarity": similarity,
                        "face_swap_applied": True
                    }
                
                # Если не последняя попытка, меняем seed для следующей генерации
                if attempt_num < max_retries - 1:
                    current_seed = random.randint(1, 1000000)
                    await asyncio.sleep(1.0)  # Небольшая задержка между попытками
            
            except Exception as e:
                logger.error(f"❌ Ошибка при попытке {attempt_num + 1} для обложки: {e}", exc_info=True)
                if attempt_num < max_retries - 1:
                    current_seed = random.randint(1, 1000000)
                    await asyncio.sleep(1.0)
                continue
        
        # Все попытки завершены, возвращаем лучшее изображение
        if best_image is None:
            raise HTTPException(
                status_code=422,
                detail=f"Не удалось сгенерировать обложку с приемлемым сходством лица после {max_retries} попыток"
            )
        
        # Определяем, прошла ли верификация для лучшего изображения
        final_verified = best_similarity >= similarity_threshold
        
        if final_verified:
            logger.info(f"🏆 Лучшее изображение обложки выбрано: similarity={best_similarity:.3f} (verified={final_verified})")
        else:
            logger.warning(
                f"⚠️ Лучшее изображение обложки: similarity={best_similarity:.3f} "
                f"(threshold={similarity_threshold}, verified={final_verified})"
            )
        
        return best_image, {
            "face_similarity": best_similarity,
            "face_verified": final_verified,
            "attempts": attempts,
            "best_similarity": best_similarity,
            "face_swap_applied": True
        }
    
    # Для остальных сцен - обычная логика (без face swap)
    logger.info(f"📄 Обычный пайплайн для не-обложки")
    
    for attempt_num in range(max_retries):
        attempts += 1
        logger.info(f"🔄 Попытка генерации {attempt_num + 1}/{max_retries} (seed={current_seed})")
        
        try:
            # Генерируем изображение
            generated_bytes = await generate_img2img(
                prompt=prompt,
                reference_image_url=reference_image_url,
                strength=strength,
                seed=current_seed,
                max_retries=1  # Внутри уже есть retry логика
            )
            
            # Верифицируем лицо
            verified, similarity = verify_face(
                mean_embedding_bytes=mean_embedding_bytes,
                generated_img_bytes=generated_bytes,
                threshold=similarity_threshold
            )
            
            # Сохраняем лучшее изображение
            if similarity > best_similarity:
                best_similarity = similarity
                best_image = generated_bytes
            
            logger.info(
                f"✓ Попытка {attempt_num + 1}: similarity={similarity:.3f}, "
                f"threshold={similarity_threshold}, verified={verified}"
            )
            
            # Если верификация успешна, возвращаем результат
            if verified:
                logger.info(f"✅ Face verification успешна после {attempt_num + 1} попыток")
                return generated_bytes, {
                    "face_similarity": similarity,
                    "face_verified": True,
                    "attempts": attempt_num + 1,
                    "best_similarity": similarity,
                    "face_swap_applied": False
                }
            
            # Если не последняя попытка, меняем seed для следующей генерации
            if attempt_num < max_retries - 1:
                current_seed = random.randint(1, 1000000)
                await asyncio.sleep(1.0)  # Небольшая задержка между попытками
        
        except Exception as e:
            logger.error(f"❌ Ошибка при попытке {attempt_num + 1}: {e}", exc_info=True)
            if attempt_num < max_retries - 1:
                current_seed = random.randint(1, 1000000)
                await asyncio.sleep(1.0)
            continue
    
    # Все попытки провалились, возвращаем лучшее изображение
    if best_image is None:
        raise HTTPException(
            status_code=422,
            detail=f"Не удалось сгенерировать изображение с приемлемым сходством лица после {max_retries} попыток"
        )
    
    logger.warning(
        f"⚠️ Face verification не прошла после {max_retries} попыток. "
        f"Возвращаем лучшее изображение (similarity={best_similarity:.3f})"
    )
    
    return best_image, {
        "face_similarity": best_similarity,
        "face_verified": False,
        "attempts": attempts,
        "best_similarity": best_similarity,
        "face_swap_applied": False
    }

