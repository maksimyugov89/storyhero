"""
Таблица цен для печатных книг StoryHero
"""

# Цены на печать книг (в рублях)
PRINT_PRICES = {
    "A5 (Маленькая)": {
        10: {"Мягкий переплёт": 950, "Твёрдый переплёт": 1900},
        20: {"Мягкий переплёт": 1350, "Твёрдый переплёт": 2300},
    },
    "B5 (Средняя)": {
        10: {"Мягкий переплёт": 1200, "Твёрдый переплёт": 2400},
        20: {"Мягкий переплёт": 1700, "Твёрдый переплёт": 2900},
    },
    "A4 (Большая)": {
        10: {"Мягкий переплёт": 1600, "Твёрдый переплёт": 3100},
        20: {"Мягкий переплёт": 2200, "Твёрдый переплёт": 3800},
    },
}

# Цены на упаковку (в рублях)
PACKAGING_PRICES = {
    "Простая упаковка": 0,
    "Подарочная упаковка": 250,
}

# Допустимые значения
VALID_SIZES = list(PRINT_PRICES.keys())
VALID_PAGES = [10, 20]
VALID_BINDINGS = ["Мягкий переплёт", "Твёрдый переплёт"]
VALID_PACKAGINGS = list(PACKAGING_PRICES.keys())


def validate_price(size: str, pages: int, binding: str, packaging: str, submitted_price: int) -> bool:
    """
    Валидация цены на бэкенде.
    Возвращает True если цена корректна, False если нет.
    """
    # Проверяем допустимость параметров
    if size not in VALID_SIZES:
        return False
    if pages not in VALID_PAGES:
        return False
    if binding not in VALID_BINDINGS:
        return False
    if packaging not in VALID_PACKAGINGS:
        return False
    
    # Вычисляем ожидаемую цену
    base_price = PRINT_PRICES.get(size, {}).get(pages, {}).get(binding, 0)
    packaging_price = PACKAGING_PRICES.get(packaging, 0)
    expected_price = base_price + packaging_price
    
    # Сравниваем с переданной ценой
    return submitted_price == expected_price


def calculate_price(size: str, pages: int, binding: str, packaging: str) -> int:
    """
    Вычисляет цену заказа по параметрам.
    Возвращает 0 если параметры некорректны.
    """
    base_price = PRINT_PRICES.get(size, {}).get(pages, {}).get(binding, 0)
    packaging_price = PACKAGING_PRICES.get(packaging, 0)
    return base_price + packaging_price

