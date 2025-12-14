import os
import requests
import base64
import uuid
from fastapi import HTTPException
from .storage import upload_image


async def generate_final_image(prompt: str, face_url: str = None, style: str = "storybook") -> dict:
    """
    Генерация финального изображения через OpenRouter FLUX.1-dev с применением стиля
    
    Args:
        prompt: Текстовое описание сцены
        face_url: URL изображения лица (не используется, оставлен для совместимости)
        style: Стиль (storybook, cartoon, pixar, disney, watercolor)
    
    Returns:
        Словарь с image_url и style
    """
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENROUTER_API_KEY не установлен в переменных окружения"
        )
    
    # Добавляем стиль к промпту
    style_prompts = {
        "storybook": "storybook illustration style, soft colors, warm lighting, friendly characters",
        "cartoon": "cartoon style, bright colors, bold lines, animated look",
        "pixar": "Pixar animation style, 3D rendered, vibrant colors, cinematic lighting",
        "disney": "Disney animation style, classic illustration, magical atmosphere, detailed",
        "watercolor": "watercolor painting style, soft brushstrokes, artistic, dreamy"
    }
    
    style_prompt = style_prompts.get(style, style_prompts["storybook"])
    enhanced_prompt = f"{prompt}, {style_prompt}"
    
    url = "https://openrouter.ai/api/v1/images"
    
    payload = {
        "model": "black-forest-labs/FLUX.1-dev",
        "prompt": enhanced_prompt,
        "size": "1024x1024",
        "response_format": "b64_json"
    }
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost",
        "X-Title": "StoryHero"
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=240)
        
        if response.status_code != 200:
            error_detail = response.text
            try:
                error_json = response.json()
                error_detail = error_json.get("error", {}).get("message", error_detail)
            except:
                pass
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Ошибка OpenRouter API: {error_detail}"
            )
        
        json_resp = response.json()
        
        # Получаем Base64 изображение
        b64_image = json_resp.get("data", [{}])[0].get("b64_json")
        if not b64_image:
            raise HTTPException(
                status_code=500,
                detail="Ответ API не содержит b64_json"
            )
        
        # Декодируем Base64 в байты
        image_bytes = base64.b64decode(b64_image)
        
        # Генерируем уникальный путь для сохранения
        image_path = f"final/{uuid.uuid4()}.jpg"
        
        # Сохраняем в локальное хранилище
        public_url = upload_image(image_bytes, image_path)
        
        return {
            "image_url": public_url,
            "style": style
        }
        
    except HTTPException:
        raise
    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="Timeout при генерации изображения")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка при генерации финального изображения: {str(e)}")

