#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os
import textwrap

ROOT = "/Users/chahine/Projects/Leona"
RAW_IPHONE = os.path.join(ROOT, "Screenshots", "AppStore_iPhone_6.9")
RAW_IPAD = os.path.join(ROOT, "Screenshots", "AppStore_iPad_13")
OUT_IPHONE = os.path.join(ROOT, "Screenshots", "Promo_iPhone_6.9")
OUT_IPAD = os.path.join(ROOT, "Screenshots", "Promo_iPad_13")

for directory in [OUT_IPHONE, OUT_IPAD]:
    os.makedirs(directory, exist_ok=True)

TITLE_FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
BODY_FONT = "/System/Library/Fonts/Avenir Next.ttc"

SHOTS = [
    {
        "file": "02_Dashboard.png",
        "out": "01_Dashboard.png",
        "badge": "DAILY VIEW",
        "title": "Everything your day\nneeds in one place",
        "subtitle": "Feedings, naps, diapers, notes and smart reminders at a glance.",
        "background": ((255, 244, 240), (255, 227, 221)),
        "accent": (245, 117, 112),
        "blob": (255, 196, 186),
    },
    {
        "file": "03_Sleep.png",
        "out": "02_Sleep.png",
        "badge": "SLEEP",
        "title": "A calmer way\nto track sleep",
        "subtitle": "Start a session in one tap and keep the whole routine clear.",
        "background": ((28, 28, 78), (72, 60, 147)),
        "accent": (160, 143, 255),
        "blob": (120, 110, 255),
        "title_fill": (255, 255, 255),
        "subtitle_fill": (228, 228, 248),
        "badge_fill": (255, 255, 255),
        "badge_text_fill": (60, 54, 136),
        "screenshot_scale_phone": 0.76,
        "screenshot_scale_ipad": 0.80,
    },
    {
        "file": "05_Statistics.png",
        "out": "03_Statistics.png",
        "badge": "INSIGHTS",
        "title": "See the patterns\nbehind the chaos",
        "subtitle": "Totals, averages and charts that make your baby's rhythm obvious.",
        "background": ((255, 248, 243), (255, 232, 226)),
        "accent": (255, 128, 104),
        "blob": (255, 202, 188),
    },
    {
        "file": "06_Growth.png",
        "out": "04_Growth.png",
        "badge": "GROWTH",
        "title": "WHO charts,\nbuilt right in",
        "subtitle": "Track weight, height and head circumference with clear percentiles.",
        "background": ((240, 252, 248), (224, 245, 238)),
        "accent": (83, 192, 149),
        "blob": (181, 233, 209),
    },
    {
        "file": "07_Health.png",
        "out": "05_Health.png",
        "badge": "HEALTH",
        "title": "Keep every health\nmoment organized",
        "subtitle": "Symptoms, temperature and past records stay simple to review.",
        "background": ((255, 246, 244), (255, 235, 233)),
        "accent": (255, 126, 112),
        "blob": (255, 206, 196),
    },
    {
        "file": "08_Sharing.png",
        "out": "06_Sharing.png",
        "badge": "SHARING",
        "title": "Stay in sync\nwith your partner",
        "subtitle": "One shared history, automatic updates, both parents always aligned.",
        "background": ((246, 244, 255), (233, 237, 255)),
        "accent": (123, 135, 255),
        "blob": (199, 208, 255),
        "screenshot_scale_phone": 0.72,
        "screenshot_scale_ipad": 0.66,
        "screenshot_top_phone": 0.40,
        "screenshot_top_ipad": 0.40,
    },
]


def load_font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def gradient_background(size, top_color, bottom_color):
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(height - 1, 1)
        color = tuple(int(top_color[i] + (bottom_color[i] - top_color[i]) * t) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    return image


def add_blobs(image, cfg):
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    width, height = image.size
    blob = cfg["blob"] + (150,)
    accent = cfg["accent"] + (85,)

    draw.ellipse((-int(width * 0.10), -int(height * 0.02), int(width * 0.44), int(height * 0.34)), fill=blob)
    draw.ellipse((int(width * 0.58), int(height * 0.04), int(width * 1.02), int(height * 0.38)), fill=accent)
    draw.ellipse((int(width * 0.25), int(height * 0.78), int(width * 0.88), int(height * 1.18)), fill=blob)

    soft = overlay.filter(ImageFilter.GaussianBlur(radius=int(width * 0.03)))
    image.alpha_composite(soft)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def add_shadow(base, box, radius, opacity):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(box, radius=radius, fill=(18, 20, 30, opacity))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=32))
    base.alpha_composite(shadow)


def wrap_text(draw, text, font, max_width):
    words = text.split()
    lines = []
    current = []
    for word in words:
        candidate = " ".join(current + [word])
        if draw.textlength(candidate, font=font) <= max_width or not current:
            current.append(word)
        else:
            lines.append(" ".join(current))
            current = [word]
    if current:
        lines.append(" ".join(current))
    return "\n".join(lines)


def paste_screenshot(base, screenshot, cfg, is_ipad):
    width, height = base.size
    scale_key = "screenshot_scale_ipad" if is_ipad else "screenshot_scale_phone"
    top_key = "screenshot_top_ipad" if is_ipad else "screenshot_top_phone"

    screenshot_scale = cfg.get(scale_key, 0.84 if is_ipad else 0.82)
    screenshot_top = cfg.get(top_key, 0.35 if is_ipad else 0.36)
    target_width = int(width * screenshot_scale)
    target_height = int(screenshot.height * (target_width / screenshot.width))
    screenshot = screenshot.resize((target_width, target_height), Image.LANCZOS).convert("RGBA")

    radius = int(width * 0.045)
    mask = rounded_mask(screenshot.size, radius)
    screenshot.putalpha(mask)

    x = (width - target_width) // 2
    y = int(height * screenshot_top)
    add_shadow(base, (x + 18, y + 26, x + target_width + 18, y + target_height + 26), radius, 88)
    base.paste(screenshot, (x, y), screenshot)

    border = Image.new("RGBA", base.size, (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rounded_rectangle(
        (x, y, x + target_width, y + target_height),
        radius=radius,
        outline=(255, 255, 255, 120),
        width=2,
    )
    base.alpha_composite(border)


def compose(canvas_size, screenshot_path, output_path, cfg, is_ipad):
    base = gradient_background(canvas_size, cfg["background"][0], cfg["background"][1]).convert("RGBA")
    add_blobs(base, cfg)
    draw = ImageDraw.Draw(base)
    width, height = canvas_size

    title_fill = cfg.get("title_fill", (24, 25, 32))
    subtitle_fill = cfg.get("subtitle_fill", (92, 96, 110))
    badge_fill = cfg.get("badge_fill", cfg["accent"])
    badge_text_fill = cfg.get("badge_text_fill", (255, 255, 255))

    margin = int(width * 0.07)
    badge_font = load_font(BODY_FONT, int(width * (0.034 if is_ipad else 0.040)))
    title_font = load_font(TITLE_FONT, int(width * (0.072 if is_ipad else 0.090)))
    subtitle_font = load_font(BODY_FONT, int(width * (0.032 if is_ipad else 0.038)))

    badge_text = cfg["badge"]
    badge_padding_x = int(width * 0.028)
    badge_padding_y = int(width * 0.016)
    badge_box = draw.textbbox((0, 0), badge_text, font=badge_font)
    badge_width = badge_box[2] - badge_box[0] + badge_padding_x * 2
    badge_height = badge_box[3] - badge_box[1] + badge_padding_y * 2
    badge_y = int(height * 0.07)

    draw.rounded_rectangle(
        (margin, badge_y, margin + badge_width, badge_y + badge_height),
        radius=badge_height // 2,
        fill=badge_fill,
    )
    draw.text(
        (margin + badge_padding_x, badge_y + badge_padding_y - 2),
        badge_text,
        font=badge_font,
        fill=badge_text_fill,
    )

    title_y = badge_y + badge_height + int(height * 0.04)
    draw.multiline_text(
        (margin, title_y),
        cfg["title"],
        font=title_font,
        fill=title_fill,
        spacing=int(width * 0.01),
    )

    title_box = draw.multiline_textbbox(
        (margin, title_y),
        cfg["title"],
        font=title_font,
        spacing=int(width * 0.01),
    )
    subtitle_y = title_box[3] + int(height * 0.018)
    subtitle = wrap_text(draw, cfg["subtitle"], subtitle_font, int(width * 0.84))
    draw.multiline_text(
        (margin, subtitle_y),
        subtitle,
        font=subtitle_font,
        fill=subtitle_fill,
        spacing=int(width * 0.008),
    )

    screenshot = Image.open(screenshot_path)
    paste_screenshot(base, screenshot, cfg, is_ipad=is_ipad)

    base.convert("RGB").save(output_path, quality=95)


def generate_family(source_dir, output_dir, is_ipad):
    canvas = (2064, 2752) if is_ipad else (1320, 2868)
    for cfg in SHOTS:
        compose(
            canvas_size=canvas,
            screenshot_path=os.path.join(source_dir, cfg["file"]),
            output_path=os.path.join(output_dir, cfg["out"]),
            cfg=cfg,
            is_ipad=is_ipad,
        )


if __name__ == "__main__":
    generate_family(RAW_IPHONE, OUT_IPHONE, is_ipad=False)
    generate_family(RAW_IPAD, OUT_IPAD, is_ipad=True)
    print(f"Created promotional iPhone screenshots in {OUT_IPHONE}")
    print(f"Created promotional iPad screenshots in {OUT_IPAD}")
