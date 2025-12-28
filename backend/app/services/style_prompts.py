"""
Сервис для получения промптов стилей для генерации изображений.
Содержит специфичные промпты для каждого стиля, адаптированные для детской аудитории.
"""
import logging
from typing import Optional

logger = logging.getLogger(__name__)


def get_style_prompt(style_id: str, scene_description: str, is_cover: bool = False) -> str:
    """
    Возвращает промпт для генерации изображения с учетом стиля.
    
    Args:
        style_id: ID стиля (marvel, dc, anime, и т.д.)
        scene_description: Описание сцены из промпта
        is_cover: Флаг, что это промпт для обложки
    
    Returns:
        str: Промпт с примененным стилем
    """
    # Базовые промпты для новых премиум стилей
    style_prompts = {
        'marvel': (
            f"{scene_description}, in Marvel comics style, dynamic action poses, bold colors, "
            f"comic book illustration, superhero aesthetic, dramatic lighting, vibrant palette, "
            f"detailed character design, comic book panel style, Marvel Cinematic Universe inspired, "
            f"cinematic composition, heroic poses, energy effects, comic book shading, "
            f"child-friendly, safe and appropriate for children, no violence, no scary elements, "
            f"colorful and exciting, age-appropriate superhero style"
        ),
        
        'dc': (
            f"{scene_description}, in DC Comics style, dark and moody atmosphere with bright highlights, "
            f"dramatic shadows, bold character design, comic book illustration, child-friendly DC style, "
            f"safe and appropriate for children, colorful but with dramatic lighting, heroic poses, "
            f"cinematic composition, gothic aesthetic adapted for children, deep colors, "
            f"detailed artwork, DC Universe inspired, sophisticated color palette, "
            f"no violence, no scary elements, age-appropriate"
        ),
        
        'anime': (
            f"{scene_description}, in anime style, Japanese animation aesthetic, expressive large eyes, "
            f"vibrant colors, clean line art, detailed backgrounds, kawaii elements, "
            f"Studio Ghibli inspired, soft shading, bright and cheerful atmosphere, "
            f"child-friendly anime style, safe and appropriate for children, dynamic poses, "
            f"manga illustration style, detailed character design, anime art style, "
            f"no violence, no scary elements, age-appropriate"
        ),
    }
    
    # Если стиль не найден в специальных промптах, возвращаем базовое описание
    if style_id not in style_prompts:
        # Для остальных стилей просто добавляем стиль к описанию
        return f"{scene_description}, {style_id} style, child-friendly, safe and appropriate for children"
    
    return style_prompts[style_id]


def get_style_prompt_for_cover(style_id: str, scene_description: str, age_emphasis: str = "") -> str:
    """
    Возвращает промпт для генерации обложки с учетом стиля.
    Для обложек промпты должны быть более чистыми, без лишних инструкций.
    
    Args:
        style_id: ID стиля (marvel, dc, anime, и т.д.)
        scene_description: Описание сцены из промпта
        age_emphasis: Акцент на возрасте ребенка (опционально)
    
    Returns:
        str: Промпт для обложки с примененным стилем
    """
    # Для обложек используем более чистые промпты
    cover_style_prompts = {
        'marvel': (
            f"{scene_description}, Marvel comics style, dynamic action pose, bold vibrant colors, "
            f"comic book illustration, superhero aesthetic, dramatic lighting, heroic composition, "
            f"energy effects, child-friendly Marvel style, safe and appropriate for children, "
            f"colorful and exciting"
        ),
        
        'dc': (
            f"{scene_description}, DC Comics style, dark and moody atmosphere with bright highlights, "
            f"dramatic shadows, bold character design, comic book illustration, child-friendly DC style, "
            f"safe and appropriate for children, colorful but with dramatic lighting, heroic poses"
        ),
        
        'anime': (
            f"{scene_description}, anime style, Japanese animation aesthetic, expressive large eyes, "
            f"vibrant colors, clean line art, detailed backgrounds, kawaii elements, "
            f"Studio Ghibli inspired, soft shading, bright and cheerful atmosphere, "
            f"child-friendly anime style, safe and appropriate for children"
        ),
    }
    
    # Если стиль не найден, используем базовое описание
    if style_id not in cover_style_prompts:
        base_prompt = f"{scene_description}, {style_id} style"
        if age_emphasis:
            base_prompt = f"{age_emphasis}{base_prompt}"
        return base_prompt
    
    prompt = cover_style_prompts[style_id]
    if age_emphasis:
        prompt = f"{age_emphasis}{prompt}"
    
    return prompt

