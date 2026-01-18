"""
Сервис для очистки промптов от инструкций о тексте/названии для обложек.
Обеспечивает, что в промпт для генерации обложки НЕ попадают инструкции о тексте.
"""
import logging
import re
from typing import Optional

logger = logging.getLogger(__name__)

# Список запрещенных слов/фраз для обложки
FORBIDDEN_TEXT_KEYWORDS = [
    "title", "text", "letters", "words", "writing", "written", "drawn",
    "cyrillic", "logo", "watermark", "signature", "typography", "font",
    "lettering", "inscription", "caption", "label", "heading"
]

# Паттерны для удаления инструкций о тексте
TEXT_INSTRUCTION_PATTERNS = [
    r"The title '[^']+' \(in Russian Cyrillic letters\) MUST be written/drawn[^.]*\.",
    r"The title '[^']+' MUST be written/drawn[^.]*\.",
    r"The title '[^']+' should be[^.]*\.",
    r"The title should be[^.]*\.",
    r"The title text should be[^.]*\.",
    r"Style the title like[^.]*\.",
    r"title.*MUST.*written",
    r"title.*MUST.*drawn",
    r"title.*should.*large",
    r"title.*should.*bold",
    r"title.*should.*letters",
    r"title.*text.*readable",
    r"title.*artwork",
    r"comic book covers.*title",
    r"written.*cover",
    r"drawn.*cover",
    r"text.*cover",
    r"letters.*cover",
    r"include.*title",
    r"add.*title",
    r"write.*title",
    r"draw.*title",
    r"display.*title",
    r"show.*title",
    r"feature.*title",
    r"with.*title",
    r"containing.*title",
    r"having.*title",
    r"title.*in.*russian",
    r"title.*in.*cyrillic",
    r"russian.*title",
    r"cyrillic.*title",
    r"book.*title",
    r"cover.*title",
]


def strip_title_instructions(prompt: str) -> str:
    """
    Удаляет все инструкции о тексте/названии из промпта.
    
    Args:
        prompt: Исходный промпт (может содержать инструкции о тексте)
    
    Returns:
        str: Очищенный промпт без инструкций о тексте
    """
    if not prompt:
        return prompt
    
    original_length = len(prompt)
    cleaned = prompt
    
    # Удаляем паттерны через regex
    for pattern in TEXT_INSTRUCTION_PATTERNS:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE | re.DOTALL)
    
    # Удаляем предложения, содержащие запрещенные ключевые слова
    sentences = re.split(r'[.!?]\s+', cleaned)
    filtered_sentences = []
    
    for sentence in sentences:
        sentence_lower = sentence.lower()
        # Проверяем, содержит ли предложение запрещенные слова
        has_forbidden = any(keyword in sentence_lower for keyword in FORBIDDEN_TEXT_KEYWORDS)
        
        # Также проверяем комбинации слов
        has_title_instruction = (
            "title" in sentence_lower and (
                "must" in sentence_lower or
                "should" in sentence_lower or
                "write" in sentence_lower or
                "draw" in sentence_lower or
                "include" in sentence_lower or
                "add" in sentence_lower
            )
        )
        
        if not has_forbidden and not has_title_instruction:
            filtered_sentences.append(sentence)
    
    cleaned = '. '.join(filtered_sentences)
    
    # Убираем двойные пробелы, точки и запятые
    cleaned = re.sub(r'\s+', ' ', cleaned)
    cleaned = re.sub(r'\.\s*\.', '.', cleaned)
    cleaned = re.sub(r',\s*,', ',', cleaned)
    cleaned = cleaned.strip()
    
    # Убираем дублирование "Book cover illustration"
    if cleaned.count('Book cover illustration') > 1:
        parts = cleaned.split('Book cover illustration')
        cleaned = 'Book cover illustration' + ' '.join(parts[1:])
    
    new_length = len(cleaned)
    if original_length != new_length:
        logger.info(
            f"🧼 Prompt sanitized: removed title instructions "
            f"(len before={original_length}, len after={new_length})"
        )
    
    return cleaned


def add_no_text_policy(prompt: str) -> str:
    """
    Добавляет строгий запрет на любой текст в конец промпта.
    
    Args:
        prompt: Промпт для обложки
    
    Returns:
        str: Промпт с добавленным запретом на текст
    """
    no_text_policy = (
        "ABSOLUTELY NO TEXT. NO LETTERS. NO WORDS. NO NUMBERS. NO LOGOS. "
        "NO WATERMARKS. NO SIGNATURES. NO WRITING. NO TYPOGRAPHY. NO LETTERING. "
        "PURE ILLUSTRATION ONLY. Clean cover art, illustration only, no typography."
    )
    
    # Добавляем только если еще не добавлено
    if "NO TEXT" not in prompt.upper() and "NO LETTERS" not in prompt.upper():
        return f"{prompt}. {no_text_policy}"
    
    return prompt


def build_cover_prompt(base_style: str, scene_prompt: str, age_emphasis: str = "") -> str:
    """
    Строит финальный промпт для обложки без упоминаний текста.
    КРИТИЧНО: Промпт должен быть максимально простым и чистым, без лишних слов!
    
    Args:
        base_style: Базовый стиль (например, "watercolor", "marvel", "dc", "anime")
        scene_prompt: Промпт сцены из БД (может содержать инструкции о тексте)
        age_emphasis: Дополнительные инструкции о возрасте ребенка
    
    Returns:
        str: Финальный промпт для обложки без упоминаний текста
    """
    # Для новых премиум стилей (marvel, dc, anime) используем специальные промпты
    if base_style in ['marvel', 'dc', 'anime']:
        from .style_prompts import get_style_prompt_for_cover
        clean_scene_prompt = strip_title_instructions(scene_prompt)
        return get_style_prompt_for_cover(base_style, clean_scene_prompt, age_emphasis)
    # Сначала очищаем scene_prompt от инструкций о тексте
    clean_scene_prompt = strip_title_instructions(scene_prompt)
    
    # КРИТИЧНО: Убираем ВСЕ упоминания о стиле, возрасте и других метаданных из промпта
    # Они попадают в изображение как текст!
    
    # Извлекаем только визуальное описание из clean_scene_prompt
    # КРИТИЧНО: Убираем ВСЕ метаданные, которые могут попасть в изображение как текст!
    visual_description = clean_scene_prompt
    
    # Убираем все упоминания стиля
    visual_description = re.sub(r'\b(pixar|watercolor|storybook|classic|realistic|disney)\s+style\b', '', visual_description, flags=re.IGNORECASE)
    
    # Убираем все упоминания возраста - КРИТИЧНО: "5-year-old" попадает в изображение!
    visual_description = re.sub(r'\b\d+\s*-\s*year\s*-\s*old\b', '', visual_description, flags=re.IGNORECASE)
    visual_description = re.sub(r'\b\d+\s*years?\s*old\b', '', visual_description, flags=re.IGNORECASE)
    visual_description = re.sub(r'\baged\s+\d+\b', '', visual_description, flags=re.IGNORECASE)
    visual_description = re.sub(r'\b(child character must look exactly|child proportions|large head|short legs|small hands|chubby cheeks|big eyes)\b[^.]*\.?', '', visual_description, flags=re.IGNORECASE)
    
    # Убираем имена персонажей - они тоже могут попасть в изображение
    visual_description = re.sub(r'\bnamed\s+\w+\b', '', visual_description, flags=re.IGNORECASE)
    visual_description = re.sub(r'\b(Sofya|Sophia|Sofia)\b', 'child', visual_description, flags=re.IGNORECASE)
    
    # Убираем местоимения - они могут попасть в изображение
    # Заменяем "She/He" на "The child", но потом убираем дублирование
    visual_description = re.sub(r'\b(She|He)\s+', 'The child ', visual_description, flags=re.IGNORECASE)
    visual_description = re.sub(r'\b(Her|His)\s+', 'The child\'s ', visual_description, flags=re.IGNORECASE)
    
    # Убираем дублирование "The child" - если есть "A child" и "The child", оставляем только одно
    visual_description = re.sub(r'\bA\s+child\s+.*?\bThe\s+child\s+', 'A child ', visual_description, flags=re.IGNORECASE)
    visual_description = re.sub(r'\bThe\s+child\s+.*?\bThe\s+child\s+', 'The child ', visual_description, flags=re.IGNORECASE)
    
    # Убираем "IMPORTANT"
    visual_description = re.sub(r'\bIMPORTANT\s*:\s*', '', visual_description, flags=re.IGNORECASE)
    
    # Убираем "Book cover illustration" - это тоже может попасть в изображение
    visual_description = re.sub(r'\bBook cover illustration\b[^.]*\.?', '', visual_description, flags=re.IGNORECASE)
    
    # Очищаем от двойных пробелов и точек
    visual_description = re.sub(r'\s+', ' ', visual_description)
    visual_description = re.sub(r'\.\s*\.', '.', visual_description)
    visual_description = visual_description.strip()
    
    # Исправляем начало промпта - если начинается с "with", "and" - добавляем "A child"
    if visual_description and visual_description.lower().startswith(('with ', 'and ')):
        visual_description = f"A child {visual_description}"
    
    # Собираем МИНИМАЛЬНЫЙ промпт - только визуальное описание
    # НЕ добавляем стиль, возраст, метаданные - они попадают в изображение!
    parts = []
    
    # Только визуальное описание сцены
    if visual_description:
        parts.append(visual_description)
    
    # Добавляем ТОЛЬКО негативные ограничения в конце
    # НЕ добавляем позитивные инструкции - они попадают в изображение!
    # КРИТИЧНО: Усиливаем негативные промпты против текста и артефактов
    negative_only = (
        "no text, no letters, no words, no numbers, no logos, no watermarks, "
        "no signatures, no writing, no typography, no lettering, "
        "no black bars, no horizontal bars, no bottom bars, no frames, no borders, "
        "no placeholder text, no zeros, no digits, no sequences, "
        "no prompts, no instructions, no style labels, no age labels, "
        "no 'pixar style', no 'years old', no 'child character', "
        "illustration only, clean art, pure visual, no text elements"
    )
    
    # Формируем финальный промпт: визуальное описание + негативные ограничения
    if parts:
        final_prompt = f"{' '.join(parts)}. {negative_only}"
    else:
        # Если нет визуального описания, используем минимальный промпт
        final_prompt = f"children book cover illustration, vibrant colors, perfect composition. {negative_only}"
    
    # Финальная очистка
    final_prompt = re.sub(r'\s+', ' ', final_prompt)
    final_prompt = final_prompt.strip()
    
    logger.info(f"🧼 Cover prompt built: length={len(final_prompt)}, preview={final_prompt[:150]}...")
    
    return final_prompt


def sanitize_scene_prompt(prompt: str, style: str = None, age_emphasis: str = None) -> str:
    """
    Очищает промпт для обычной сцены (не обложки) от метаданных,
    которые могут попасть в изображение как текст.
    
    КРИТИЧНО: Pollinations.ai рендерит текст из промпта на изображении!
    Убираем: "Visual style:", "IMPORTANT:", имена, возраст в явном виде, метаданные.
    
    Args:
        prompt: Исходный промпт сцены
        style: Стиль изображения (добавляется в конец, а не в начало)
        age_emphasis: Акцент на возрасте (будет переформулирован)
    
    Returns:
        str: Очищенный промпт
    """
    if not prompt:
        return prompt
    
    cleaned = prompt
    
    # 1. Убираем "Visual style:" и подобные префиксы - они рендерятся как текст!
    cleaned = re.sub(r'^Visual\s+style\s*:\s*', '', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\bVisual\s+style\s*:\s*', '', cleaned, flags=re.IGNORECASE)
    
    # 2. Убираем "IMPORTANT:" - это рендерится как текст!
    cleaned = re.sub(r'\bIMPORTANT\s*:\s*', '', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\bКРИТИЧНО\s*:\s*', '', cleaned, flags=re.IGNORECASE)
    
    # 3. Убираем явные указания возраста - они рендерятся как текст!
    # "5-year-old", "5 years old", "aged 5", "ребенок 5 лет"
    cleaned = re.sub(r'\b\d+\s*-\s*year\s*-\s*old\b', 'young child', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\b\d+\s*years?\s*old\b', 'young child', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\baged\s+\d+\b', 'young child', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\bребенок\s+\d+\s*лет\b', 'ребенок', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\b\d+\s*лет\b', '', cleaned, flags=re.IGNORECASE)
    
    # 4. Убираем инструкции о пропорциях - они рендерятся как текст!
    patterns_to_remove = [
        r'The child character must look exactly[^.]*\.',
        r'child proportions[^.]*\.',
        r'large head relative to body[^.]*\.',
        r'short legs, small hands[^.]*\.',
        r'chubby cheeks, big eyes[^.]*\.',
        r'with child proportions[^.]*\.',
        r'child must look[^.]*\.',
    ]
    for pattern in patterns_to_remove:
        cleaned = re.sub(pattern, '', cleaned, flags=re.IGNORECASE)
    
    # 5. Убираем имена персонажей - они могут рендериться как текст
    # Заменяем конкретные имена на "the child"
    common_names = ['Sofya', 'Sophia', 'Sofia', 'Masha', 'Маша', 'Софья', 'София', 'Dasha', 'Даша', 'Anya', 'Аня']
    for name in common_names:
        cleaned = re.sub(rf'\b{name}\b', 'the child', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'\bnamed\s+\w+\b', '', cleaned, flags=re.IGNORECASE)
    
    # 6. Убираем "StoryHero" - это бренд, не должен быть в промпте
    cleaned = re.sub(r'\bStoryHero\b', '', cleaned, flags=re.IGNORECASE)
    
    # 7. Убираем двойные пробелы и лишние точки
    cleaned = re.sub(r'\s+', ' ', cleaned)
    cleaned = re.sub(r'\.\s*\.', '.', cleaned)
    cleaned = re.sub(r',\s*,', ',', cleaned)
    cleaned = cleaned.strip()
    
    # 8. Добавляем стиль в конец (не в начало!) - так меньше шансов, что он попадет в изображение
    if style and style not in cleaned.lower():
        cleaned = f"{cleaned}, {style} style illustration"
    
    # 9. Добавляем негативный промпт против текста
    negative = "no text, no letters, no words, no watermarks"
    if negative not in cleaned.lower():
        cleaned = f"{cleaned}. {negative}"
    
    logger.info(f"🧼 Scene prompt sanitized: len={len(cleaned)}, preview={cleaned[:100]}...")
    
    return cleaned


def assert_no_text(prompt: str, is_cover: bool = True) -> None:
    """
    Проверяет, что промпт не содержит инструкций о тексте.
    Вызывает исключение, если найдены запрещенные слова.
    
    Args:
        prompt: Промпт для проверки
        is_cover: Флаг, что это промпт для обложки
    
    Raises:
        HTTPException: Если промпт содержит инструкции о тексте
    """
    if not is_cover:
        return  # Проверяем только для обложки
    
    prompt_lower = prompt.lower()
    
    # ИСКЛЮЧЕНИЯ: Разрешенные фразы, которые НЕ являются инструкциями о тексте
    allowed_phrases = [
        "book cover illustration",  # Это описание стиля, не инструкция
        "cover art",  # Это описание стиля
        "cover illustration",  # Это описание стиля
        "no text",  # Это запрет на текст, не инструкция добавить текст
        "no letters",  # Это запрет
        "no writing",  # Это запрет
        "no typography",  # Это запрет
    ]
    
    # Проверяем наличие запрещенных слов в контексте инструкций
    forbidden_found = []
    
    for keyword in FORBIDDEN_TEXT_KEYWORDS:
        if keyword in prompt_lower:
            # Проверяем, не является ли это частью разрешенной фразы
            is_allowed = any(allowed_phrase in prompt_lower for allowed_phrase in allowed_phrases if keyword in allowed_phrase)
            if is_allowed:
                continue  # Пропускаем, это разрешенная фраза
            
            # Проверяем контекст - это может быть просто описание стиля
            # Но если есть "must", "should", "write", "draw" рядом - это инструкция
            keyword_index = prompt_lower.find(keyword)
            context_start = max(0, keyword_index - 50)
            context_end = min(len(prompt_lower), keyword_index + len(keyword) + 50)
            context = prompt_lower[context_start:context_end]
            
            # КРИТИЧНО: Проверяем, что это действительно инструкция, а не просто описание
            instruction_words = ["must", "should", "write", "drawn", "include", "add", "display", "show", "feature"]
            has_instruction = any(word in context for word in instruction_words)
            
            # Дополнительная проверка: если это "title" в контексте "book title" или "cover title" - это может быть инструкция
            # Но если это просто "book cover illustration" - это не инструкция
            if has_instruction and not ("book cover illustration" in context or "cover art" in context):
                forbidden_found.append(keyword)
    
    if forbidden_found:
        error_msg = (
            f"Cover prompt still contains text instructions! "
            f"Found forbidden keywords: {', '.join(forbidden_found)}. "
            f"Prompt preview: {prompt[:200]}..."
        )
        logger.error(f"❌ {error_msg}")
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=error_msg
        )
    
    logger.debug(f"✓ Cover prompt verified: no text instructions found")


