"""
Конфигурация для PRINT-READY PDF генерации.
Параметры для профессиональной печати (Offset / Digital).
"""
# Константа: 1 мм = 2.83464567 pt (PostScript points)
MM = 2.83464567  # pt in 1 mm

PRINT_CONFIG = {
    # Размер страницы A4
    "page_size": "A4",
    "width_pt": 595.28,  # A4 width in points
    "height_pt": 841.89,  # A4 height in points
    
    # BLEED (вылеты) - стандарт 3 мм
    "bleed_mm": 3,
    "bleed_pt": 3 * MM,  # ~8.5 pt
    
    # SAFE ZONE (безопасная зона для текста)
    "safe_margin_mm": 10,
    "safe_margin_pt": 10 * MM,  # ~28.3 pt
    
    # COLOR PROFILE
    "color_profile": "ISO Coated v2 (ECI)",
    "output_space": "CMYK",
    
    # PDF STANDARD
    "pdf_standard": "PDF/X-4",
    
    # CROP MARKS
    "crop_mark_length_pt": 15,  # Длина crop marks
    "crop_mark_width_pt": 0.5,  # Толщина линий crop marks
}

# Финальный размер страницы с bleed
FINAL_PAGE_WIDTH = PRINT_CONFIG["width_pt"] + PRINT_CONFIG["bleed_pt"] * 2
FINAL_PAGE_HEIGHT = PRINT_CONFIG["height_pt"] + PRINT_CONFIG["bleed_pt"] * 2

