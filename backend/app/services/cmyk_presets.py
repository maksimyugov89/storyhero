"""
CMYK presets для безопасной печати детской кожи.
Предотвращает серость, зелёные тени и кирпичный оттенок.
"""

SKIN_TONE_PRESETS = {
    "child_light": {
        "C": (0, 6),      # Cyan: минимум 0%, максимум 6%
        "M": (12, 22),    # Magenta: минимум 12%, максимум 22%
        "Y": (18, 32),    # Yellow: минимум 18%, максимум 32%
        "K": (0, 4),      # Black: минимум 0%, максимум 4%
        "description": "Светлая детская кожа (3-6 лет, европейский тип)"
    },
    "child_medium": {
        "C": (5, 10),     # Cyan: минимум 5%, максимум 10%
        "M": (22, 35),    # Magenta: минимум 22%, максимум 35%
        "Y": (30, 45),    # Yellow: минимум 30%, максимум 45%
        "K": (3, 8),      # Black: минимум 3%, максимум 8%
        "description": "Средняя детская кожа (5-8 лет, смешанный тип)"
    },
    "child_dark": {
        "C": (8, 15),     # Cyan: минимум 8%, максимум 15%
        "M": (30, 45),    # Magenta: минимум 30%, максимум 45%
        "Y": (40, 55),    # Yellow: минимум 40%, максимум 55%
        "K": (5, 12),     # Black: минимум 5%, максимум 12%
        "description": "Тёмная детская кожа (5-8 лет, африканский/азиатский тип)"
    },
}

# Preset по умолчанию
DEFAULT_PRESET = "child_light"

def get_preset(preset_name: str = None) -> dict:
    """
    Возвращает preset для детской кожи.
    
    Args:
        preset_name: Имя preset'а (по умолчанию "child_light")
    
    Returns:
        dict: Словарь с диапазонами CMYK
    """
    if preset_name is None:
        preset_name = DEFAULT_PRESET
    
    if preset_name not in SKIN_TONE_PRESETS:
        raise ValueError(f"Unknown preset: {preset_name}. Available: {list(SKIN_TONE_PRESETS.keys())}")
    
    return SKIN_TONE_PRESETS[preset_name]

