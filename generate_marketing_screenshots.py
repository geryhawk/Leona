#!/usr/bin/env python3
"""Compose App Store promotional frames from the raw simulator captures.

Reads  Screenshots/AppStore_iPhone_6.9/<lang>/*.png and Screenshots/AppStore_iPad_13/<lang>/*.png
Writes Screenshots/Promo_iPhone_6.9/<lang>/*.png and Screenshots/Promo_iPad_13/<lang>/*.png

Run through Docker (Python is Docker-only on Septeo machines):

    docker run --rm \
      -v "$PWD":/work -w /work \
      -v "$HOME/Library/Fonts":/fonts:ro \
      -e LEONA_FONT_TTC=/fonts/AvenirNext.ttc \
      python:3.12-slim sh -c "pip install -q pillow && python generate_marketing_screenshots.py"

The Leona palette (Thread v2): canvas #F5F3F4, plum #33224A, vermilion #E24E2B,
lilac #8A73C4 (sleep), moss #2F7A5A (diapers/health), night #191223.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW_IPHONE = os.path.join(ROOT, "Screenshots", "AppStore_iPhone_6.9")
RAW_IPAD = os.path.join(ROOT, "Screenshots", "AppStore_iPad_13")
OUT_IPHONE = os.path.join(ROOT, "Screenshots", "Promo_iPhone_6.9")
OUT_IPAD = os.path.join(ROOT, "Screenshots", "Promo_iPad_13")

# Avenir Next.ttc face indices: 0 Bold, 2 Demi Bold, 5 Medium, 7 Regular, 8 Heavy.
FONT_TTC = os.environ.get("LEONA_FONT_TTC", "/System/Library/Fonts/Avenir Next.ttc")
FACE_TITLE = 8
FACE_BADGE = 0
FACE_BODY = 5

CANVAS = (245, 243, 244)
PLUM = (51, 34, 74)
PLUM_DARK = (91, 62, 134)
NIGHT = (25, 18, 35)
VERMILION = (226, 78, 43)
LILAC = (138, 115, 196)
MOSS = (47, 122, 90)
INK = (30, 22, 40)
MUTED = (107, 100, 112)
WHITE = (255, 255, 255)


def tint(color, amount):
    """Mix a colour towards white; amount 0 = colour, 1 = white."""
    return tuple(int(c + (255 - c) * amount) for c in color)


SHOTS = [
    {
        "file": "02_Thread.png",
        "out": "01_Thread.png",
        "accent": VERMILION,
        "background": (CANVAS, tint(VERMILION, 0.88)),
        "blob": tint(VERMILION, 0.72),
        "copy": {
            "en": ("THE THREAD", "Your baby's day,\nas a conversation",
                   "Feeds, sleep, diapers and notes land as messages. Leona keeps the totals."),
            "fr": ("LE FIL", "La journée de bébé,\ncomme une conversation",
                   "Repas, dodos, couches et notes arrivent en messages. Leona tient les comptes."),
        },
    },
    {
        "file": "03_Sleep.png",
        "out": "02_Sleep.png",
        "accent": LILAC,
        "background": (NIGHT, PLUM),
        "blob": PLUM_DARK,
        "title_fill": WHITE,
        "subtitle_fill": (214, 205, 232),
        "badge_fill": LILAC,
        "badge_text_fill": WHITE,
        "border": (255, 255, 255, 70),
        "copy": {
            "en": ("SLEEP", "Sleep, timed\nin one tap",
                   "Start when the eyes close, stop when they open. The night sorts itself out."),
            "fr": ("DODO", "Le dodo,\nchronométré d'un geste",
                   "Lancez quand les yeux se ferment, arrêtez quand ils s'ouvrent. La nuit se range seule."),
        },
    },
    {
        "file": "04_Trends.png",
        "out": "03_Trends.png",
        "accent": VERMILION,
        "background": (CANVAS, tint(LILAC, 0.86)),
        "blob": tint(LILAC, 0.70),
        "copy": {
            "en": ("TRENDS", "See the rhythm\nbehind the days",
                   "Milk per day, nights and naps over 3, 7 or 30 days, with what changed this week."),
            "fr": ("TENDANCES", "Voyez le rythme\nderrière les journées",
                   "Lait par jour, nuits et siestes sur 3, 7 ou 30 jours, et ce qui a changé cette semaine."),
        },
    },
    {
        "file": "05_Growth.png",
        "out": "04_Growth.png",
        "accent": MOSS,
        "background": (CANVAS, tint(MOSS, 0.86)),
        "blob": tint(MOSS, 0.72),
        "copy": {
            "en": ("GROWTH", "WHO curves,\nbuilt right in",
                   "Weight, height and head circumference with the percentile, in plain words."),
            "fr": ("CROISSANCE", "Les courbes OMS,\nintégrées",
                   "Poids, taille et périmètre crânien avec le percentile, en mots simples."),
        },
    },
    {
        "file": "06_Health.png",
        "out": "05_Health.png",
        "accent": VERMILION,
        "background": (CANVAS, tint(VERMILION, 0.90)),
        "blob": tint(VERMILION, 0.76),
        "copy": {
            "en": ("HEALTH", "Every fever,\nevery dose",
                   "Symptoms, temperatures and medication in one record you can show the doctor."),
            "fr": ("SANTÉ", "Chaque fièvre,\nchaque dose",
                   "Symptômes, températures et médicaments dans un dossier à montrer au médecin."),
        },
    },
    {
        "file": "07_Sharing.png",
        "out": "06_Sharing.png",
        "accent": PLUM_DARK,
        "background": (CANVAS, tint(PLUM_DARK, 0.86)),
        "blob": tint(PLUM_DARK, 0.72),
        "copy": {
            "en": ("TOGETHER", "Both parents,\none thread",
                   "Invite your partner with iCloud. Every entry shows who logged it, on every phone."),
            "fr": ("À DEUX", "Deux parents,\nun seul fil",
                   "Invitez votre partenaire via iCloud. Chaque entrée dit qui l'a notée, sur chaque téléphone."),
        },
    },
    {
        "file": "01_Welcome.png",
        "out": "07_Welcome.png",
        "accent": VERMILION,
        "background": (CANVAS, tint(VERMILION, 0.90)),
        "blob": tint(LILAC, 0.78),
        # The welcome conversation sits at the bottom of the screen: show that part.
        "crop_top": 0.34,
        "crop_top_ipad": 0.42,
        "copy": {
            "en": ("30 SECONDS", "Two questions\nand you're in",
                   "A name, a birth date. Units, reminders and sharing wait until you need them."),
            "fr": ("30 SECONDES", "Deux questions\net c'est réglé",
                   "Un prénom, une date de naissance. Unités, rappels et partage attendront."),
        },
    },
]


def load_font(face, size):
    try:
        return ImageFont.truetype(FONT_TTC, size, index=face)
    except OSError:
        try:
            return ImageFont.load_default(size)
        except TypeError:
            return ImageFont.load_default()


def fit_font(draw, text, face, base_size, max_width):
    """Largest font at or below base_size whose widest line fits max_width."""
    size = base_size
    while size > base_size * 0.55:
        font = load_font(face, size)
        widest = max(draw.textlength(line, font=font) for line in text.split("\n"))
        if widest <= max_width:
            return font
        size = int(size * 0.96)
    return load_font(face, size)


def gradient_background(size, top_color, bottom_color):
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(int(top_color[i] + (bottom_color[i] - top_color[i]) * t) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    return image


def add_blob(image, cfg):
    """One soft shape behind the device, in the slide's tint."""
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    width, height = image.size
    draw.ellipse(
        (int(width * 0.08), int(height * 0.42), int(width * 1.12), int(height * 1.10)),
        fill=cfg["blob"] + (170,),
    )
    soft = overlay.filter(ImageFilter.GaussianBlur(radius=int(width * 0.05)))
    image.alpha_composite(soft)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def add_shadow(base, box, radius, opacity):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(box, radius=radius, fill=(20, 14, 30, opacity))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(radius=40)))


def wrap_text(draw, text, font, max_width):
    lines, current = [], []
    for word in text.split():
        candidate = " ".join(current + [word])
        if draw.textlength(candidate, font=font) <= max_width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return "\n".join(lines)


def paste_screenshot(base, screenshot, cfg, is_ipad, top_y):
    width, height = base.size
    scale = 0.86 if is_ipad else 0.84
    target_width = int(width * scale)
    target_height = int(screenshot.height * (target_width / screenshot.width))
    screenshot = screenshot.resize((target_width, target_height), Image.LANCZOS).convert("RGBA")

    radius = int(target_width * (0.045 if is_ipad else 0.11))
    screenshot.putalpha(rounded_mask(screenshot.size, radius))

    x = (width - target_width) // 2
    y = top_y
    add_shadow(base, (x + 10, y + 40, x + target_width + 10, y + target_height + 40), radius, 110)
    base.paste(screenshot, (x, y), screenshot)

    border = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (x, y, x + target_width, y + target_height),
        radius=radius,
        outline=cfg.get("border", (255, 255, 255, 160)),
        width=3,
    )
    base.alpha_composite(border)


def compose(canvas_size, screenshot_path, output_path, cfg, lang, is_ipad):
    top, bottom = cfg["background"]
    base = gradient_background(canvas_size, top, bottom).convert("RGBA")
    add_blob(base, cfg)
    draw = ImageDraw.Draw(base)
    width, height = canvas_size

    badge_text, title, subtitle_text = cfg["copy"][lang]
    title_fill = cfg.get("title_fill", PLUM)
    subtitle_fill = cfg.get("subtitle_fill", MUTED)
    badge_fill = cfg.get("badge_fill", cfg["accent"])
    badge_text_fill = cfg.get("badge_text_fill", WHITE)

    margin = int(width * 0.075)
    badge_font = load_font(FACE_BADGE, int(width * (0.026 if is_ipad else 0.034)))
    # The title never runs past the right margin: long lines shrink the whole title.
    title_font = fit_font(draw, title, FACE_TITLE, int(width * (0.066 if is_ipad else 0.088)), width - 2 * margin)
    subtitle_font = load_font(FACE_BODY, int(width * (0.028 if is_ipad else 0.037)))

    # Badge pill
    pad_x = int(width * 0.024)
    pad_y = int(width * 0.012)
    bbox = draw.textbbox((0, 0), badge_text, font=badge_font)
    badge_w = bbox[2] - bbox[0] + pad_x * 2
    badge_h = bbox[3] - bbox[1] + pad_y * 2
    badge_y = int(height * 0.06)
    draw.rounded_rectangle((margin, badge_y, margin + badge_w, badge_y + badge_h), radius=badge_h // 2, fill=badge_fill)
    draw.text((margin + pad_x - bbox[0], badge_y + pad_y - bbox[1]), badge_text, font=badge_font, fill=badge_text_fill)

    # Title
    title_y = badge_y + badge_h + int(height * 0.028)
    spacing = int(width * 0.004)
    draw.multiline_text((margin, title_y), title, font=title_font, fill=title_fill, spacing=spacing)
    title_box = draw.multiline_textbbox((margin, title_y), title, font=title_font, spacing=spacing)

    # Subtitle
    subtitle_y = title_box[3] + int(height * 0.016)
    subtitle = wrap_text(draw, subtitle_text, subtitle_font, int(width * 0.85))
    draw.multiline_text((margin, subtitle_y), subtitle, font=subtitle_font, fill=subtitle_fill, spacing=int(width * 0.006))
    subtitle_box = draw.multiline_textbbox((margin, subtitle_y), subtitle, font=subtitle_font, spacing=int(width * 0.006))

    # Device capture, anchored below the copy
    screenshot = Image.open(screenshot_path)
    crop_top = cfg.get("crop_top_ipad" if is_ipad else "crop_top")
    if crop_top:
        screenshot = screenshot.crop((0, int(screenshot.height * crop_top), screenshot.width, screenshot.height))
    top_y = subtitle_box[3] + int(height * 0.035)
    paste_screenshot(base, screenshot, cfg, is_ipad=is_ipad, top_y=top_y)

    base.convert("RGB").save(output_path, quality=95)


def generate_family(source_root, output_root, is_ipad):
    canvas = (2064, 2752) if is_ipad else (1320, 2868)
    made = 0
    for lang in sorted(d for d in os.listdir(source_root) if os.path.isdir(os.path.join(source_root, d))):
        source_dir = os.path.join(source_root, lang)
        output_dir = os.path.join(output_root, lang)
        os.makedirs(output_dir, exist_ok=True)
        for cfg in SHOTS:
            if lang not in cfg["copy"]:
                continue
            source = os.path.join(source_dir, cfg["file"])
            if not os.path.exists(source):
                print(f"skip {lang}/{cfg['file']}: missing", file=sys.stderr)
                continue
            compose(canvas, source, os.path.join(output_dir, cfg["out"]), cfg, lang, is_ipad)
            made += 1
    return made


if __name__ == "__main__":
    n_phone = generate_family(RAW_IPHONE, OUT_IPHONE, is_ipad=False)
    n_pad = generate_family(RAW_IPAD, OUT_IPAD, is_ipad=True)
    print(f"Created {n_phone} iPhone frames in {OUT_IPHONE}")
    print(f"Created {n_pad} iPad frames in {OUT_IPAD}")
