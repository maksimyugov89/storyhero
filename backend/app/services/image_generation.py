import os
import requests
import base64
from fastapi import HTTPException
from .storage import upload_image


def generate_image(prompt: str, face_image_url: str = None):
    """
    Генерация изображения через OpenRouter FLUX.1-dev.
    prompt — текстовое описание сцены
    face_image_url — не используется (оставлен для совместимости)
    """
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="OPENROUTER_API_KEY не установлен в переменных окружения"
        )
    
    url = "https://openrouter.ai/api/v1/images"
    
    payload = {
        "model": "black-forest-labs/FLUX.1-dev",
        "prompt": prompt,
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
        import uuid
        image_path = f"drafts/{uuid.uuid4()}.jpg"
        
        # Сохраняем в локальное хранилище
        public_url = upload_image(image_bytes, image_path)
        
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации изображения: {str(e)}"
        )

