import os
from fastapi import HTTPException

BASE_UPLOAD_DIR = "/var/www/storyhero/uploads"


def upload_image_bytes(
    file_bytes: bytes,
    path: str,
    content_type: str = "image/jpeg",
) -> str:
    try:
        full_path = os.path.join(BASE_UPLOAD_DIR, path)
        os.makedirs(os.path.dirname(full_path), exist_ok=True)

        with open(full_path, "wb") as f:
            f.write(file_bytes)

        # Публичный URL
        return f"/uploads/{path}"

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка сохранения файла: {str(e)}"
        )
