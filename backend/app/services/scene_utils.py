"""
Утилиты для работы со сценами.
Единые правила определения обложки и других типов сцен.
"""
from typing import Union
from ..models import Scene


def is_cover_scene(scene: Union[Scene, dict, int]) -> bool:
    """
    Определяет, является ли сцена обложкой.
    
    Args:
        scene: Объект Scene, словарь с полями или order (int)
    
    Returns:
        bool: True если это обложка (order == 0)
    """
    if isinstance(scene, int):
        return scene == 0
    
    if isinstance(scene, dict):
        order = scene.get("order", scene.get("scene_order", None))
        if order is not None:
            return order == 0
        # Также проверяем type если есть
        scene_type = scene.get("type", scene.get("scene_type", None))
        if scene_type:
            return scene_type.lower() == "cover"
        return False
    
    # Объект Scene
    if hasattr(scene, "order"):
        return scene.order == 0
    
    if hasattr(scene, "scene_order"):
        return scene.scene_order == 0
    
    if hasattr(scene, "type"):
        return getattr(scene, "type", "").lower() == "cover"
    
    return False


