import io
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Sequence

import requests
from PIL import Image as PILImage

from reportlab.lib.pagesizes import A4
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class PdfPage:
    order: int
    text: str
    image_url: Optional[str] = None


def _fetch_image_bytes(url: str, timeout: int = 30) -> Optional[bytes]:
    try:
        r = requests.get(url, timeout=timeout)
        if r.status_code != 200 or not r.content:
            logger.warning(f"⚠️ PDF: не удалось скачать изображение (HTTP {r.status_code}) {url}")
            return None
        return r.content
    except Exception as e:
        logger.warning(f"⚠️ PDF: ошибка скачивания изображения {url}: {e}")
        return None


def _normalize_image_for_pdf(image_bytes: bytes) -> Optional[ImageReader]:
    """
    ReportLab лучше всего работает с RGB JPEG/PNG.
    """
    try:
        img = PILImage.open(io.BytesIO(image_bytes))
        if img.mode not in ("RGB", "RGBA"):
            img = img.convert("RGB")
        elif img.mode == "RGBA":
            # Убираем альфу на белый фон
            bg = PILImage.new("RGB", img.size, (255, 255, 255))
            bg.paste(img, mask=img.split()[-1])
            img = bg
        out = io.BytesIO()
        img.save(out, format="JPEG", quality=92)
        out.seek(0)
        return ImageReader(out)
    except Exception as e:
        logger.warning(f"⚠️ PDF: не удалось декодировать/нормализовать изображение: {e}")
        return None


def render_book_pdf(
    output_path: Path,
    title: str,
    pages: Sequence[PdfPage],
) -> None:
    """
    Генерирует PDF на диске.
    - 1 страница = 1 сцена (картинка сверху, текст снизу)
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    page_w, page_h = A4
    margin = 36  # 0.5 inch
    image_h = page_h * 0.55
    text_top_y = page_h - margin - image_h - 12

    c = canvas.Canvas(str(output_path), pagesize=A4)
    c.setTitle(title or "StoryHero Book")

    for idx, p in enumerate(pages, 1):
        # Заголовок/номер
        c.setFont("Helvetica-Bold", 14)
        c.drawString(margin, page_h - margin + 4 - 18, f"{title or 'StoryHero'} — {p.order}")

        # Изображение
        if p.image_url:
            img_bytes = _fetch_image_bytes(p.image_url)
            if img_bytes:
                img_reader = _normalize_image_for_pdf(img_bytes)
                if img_reader:
                    # Вписываем по ширине, ограничиваем по высоте image_h
                    img_w = page_w - 2 * margin
                    c.drawImage(
                        img_reader,
                        margin,
                        page_h - margin - image_h,
                        width=img_w,
                        height=image_h,
                        preserveAspectRatio=True,
                        anchor="c",
                        mask="auto",
                    )

        # Текст
        c.setFont("Helvetica", 12)
        text = (p.text or "").strip()
        if not text:
            text = " "

        text_obj = c.beginText(margin, text_top_y)
        text_obj.setLeading(16)
        max_width = page_w - 2 * margin

        # простой перенос строк
        for paragraph in text.split("\n"):
            words = paragraph.split()
            line = ""
            for w in words:
                trial = (line + " " + w).strip()
                if c.stringWidth(trial, "Helvetica", 12) <= max_width:
                    line = trial
                else:
                    text_obj.textLine(line or w)
                    line = w
            if line:
                text_obj.textLine(line)
            text_obj.textLine("")  # пустая строка между параграфами

        c.drawText(text_obj)
        c.showPage()

    c.save()


