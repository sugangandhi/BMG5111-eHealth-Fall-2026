"""
PDF overlay and rendering.
- render_pdf_pages: render original PDF pages as images
- overlay_fields: search for field labels in the PDF and write AI values next to them
- overlay_fields_on_image: same but for scanned image uploads
"""
import io
import base64

import fitz  # PyMuPDF
from PIL import Image, ImageDraw, ImageFont


# Confidence → fill colour (RGB 0-1 for PyMuPDF)
_BG = {
    "HIGH":   (0.82, 0.98, 0.82),   # green
    "MEDIUM": (1.00, 0.97, 0.75),   # yellow
    "LOW":    (1.00, 0.88, 0.78),   # orange
}
_BORDER = {
    "HIGH":   (0.20, 0.65, 0.20),
    "MEDIUM": (0.80, 0.60, 0.00),
    "LOW":    (0.85, 0.35, 0.10),
}


def _img_to_b64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def render_pdf_pages(pdf_bytes: bytes, dpi: int = 150) -> list[str]:
    """Return each page of a PDF as a base64 PNG string."""
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    out = []
    for page in doc:
        pix = page.get_pixmap(dpi=72)
        out.append(base64.b64encode(pix.tobytes("png")).decode())
    doc.close()
    return out


def overlay_fields(pdf_bytes: bytes, filled_fields: list[dict]) -> tuple[bytes, list[str]]:
    """
    Searches each page for the field label text, then draws the AI value
    next to it in a colour-coded box.
    Returns (filled_pdf_bytes, list_of_filled_page_images_base64).
    """
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")

    for field in filled_fields:
        value = (field.get("value") or "").strip()
        conf  = field.get("confidence", "LOW")
        label = (field.get("label") or field.get("key") or "").strip()

        if not value or not label or value.lower() in ("missing", "null", "none", "n/a"):
            continue

        bg     = _BG.get(conf, _BG["LOW"])
        border = _BORDER.get(conf, _BORDER["LOW"])
        display = value[:55] + ("…" if len(value) > 55 else "")

        for page in doc:
            # Try full label, then first 4 words, then first 2 words
            rects = page.search_for(label)
            if not rects:
                rects = page.search_for(" ".join(label.split()[:4]))
            if not rects:
                rects = page.search_for(" ".join(label.split()[:2]))
            if not rects and field.get("key"):
                rects = page.search_for(field.get("key").replace("_", " "))
            
            # Heuristic fallback for common medical abbreviations hallucinated by AI
            if not rects:
                lbl = label.lower()
                if "dob" in lbl or "birth" in lbl:
                    rects = page.search_for("DOB")
                elif "name" in lbl:
                    rects = page.search_for("Name")
                elif "reason" in lbl or "why" in lbl:
                    rects = page.search_for("Reason")
                elif "sign" in lbl:
                    rects = page.search_for("Signature")

            if not rects:
                continue

            r = rects[0]
            pw = page.rect.width

            # Place value to the right; fall back below if near edge
            x0 = r.x1 + 6
            y0 = r.y0
            x1 = min(x0 + 190, pw - 8)
            y1 = r.y1

            if x1 - x0 < 40:
                x0 = r.x0
                y0 = r.y1 + 3
                x1 = min(x0 + 190, pw - 8)
                y1 = y0 + (r.y1 - r.y0) + 2

            box = fitz.Rect(x0, y0, x1, y1)
            page.draw_rect(box, color=border, fill=bg, width=0.6)

            fontsize = max(7, min(9, (y1 - y0) * 0.72))
            page.insert_text(
                (x0 + 2, y1 - 2),
                display,
                fontsize=fontsize,
                color=(0.0, 0.15, 0.55),
            )
            break   # one label → one insertion

    out = io.BytesIO()
    doc.save(out)
    filled_bytes = out.getvalue()
    doc.close()

    # Re-render filled pages as images
    doc2 = fitz.open(stream=filled_bytes, filetype="pdf")
    pages_b64 = []
    for page in doc2:
        pix = page.get_pixmap(dpi=72)
        pages_b64.append(base64.b64encode(pix.tobytes("png")).decode())
    doc2.close()

    return filled_bytes, pages_b64


def overlay_fields_on_image(img_bytes: bytes, filled_fields: list[dict]) -> tuple[bytes, list[str]]:
    """
    For uploaded images (fax scans). Draws labelled value boxes using PIL.
    Positions are approximate (stacked down the right margin) since we can't
    do text search on a raw image.
    Returns (filled_png_bytes, [single_page_b64]).
    """
    img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    draw = ImageDraw.Draw(img, "RGBA")

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
        font_sm = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11)
    except Exception:
        font = font_sm = ImageFont.load_default()

    _PIL_BG = {
        "HIGH":   (180, 255, 180, 200),
        "MEDIUM": (255, 250, 160, 200),
        "LOW":    (255, 210, 170, 200),
    }

    y_cursor = 30
    x_right  = img.width - 280

    for field in filled_fields:
        value = (field.get("value") or "").strip()
        conf  = field.get("confidence", "LOW")
        label = (field.get("label") or "").strip()

        if not value or not label or value.lower() in ("missing", "null", "none", "n/a"):
            continue

        bg = _PIL_BG.get(conf, _PIL_BG["LOW"])
        short_label = label[:30] + ("…" if len(label) > 30 else "")
        short_val   = value[:40] + ("…" if len(value) > 40 else "")

        box_h = 38
        box = [x_right, y_cursor, img.width - 10, y_cursor + box_h]
        draw.rectangle(box, fill=bg, outline=(80, 120, 80), width=1)
        draw.text((x_right + 4, y_cursor + 2),  short_label, font=font_sm, fill=(60, 60, 60))
        draw.text((x_right + 4, y_cursor + 18), short_val,   font=font,    fill=(0, 30, 120))

        y_cursor += box_h + 4
        if y_cursor > img.height - 50:
            break

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    filled_bytes = buf.getvalue()
    return filled_bytes, [base64.b64encode(filled_bytes).decode()]
