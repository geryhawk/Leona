#!/usr/bin/env python3
"""
Leona — App Store marketing screenshots v4.
Soft, warm, empathetic design for parents.
Realistic iPhone/iPad mockups. Round, beautiful typography.
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import os, math, random

BASE = "/Users/chahine/Projects/Leona/Screenshots"
IPHONE_DIR = os.path.join(BASE, "iPhone")
IPAD_DIR = os.path.join(BASE, "iPad")
OUT_IPHONE_67 = os.path.join(BASE, "Marketing_iPhone_6.7")
OUT_IPHONE_65 = os.path.join(BASE, "Marketing_iPhone_6.5")
OUT_IPAD_13 = os.path.join(BASE, "Marketing_iPad_13")
OUT_IPAD_129 = os.path.join(BASE, "Marketing_iPad_12.9")
for d in [OUT_IPHONE_67, OUT_IPHONE_65, OUT_IPAD_13, OUT_IPAD_129]:
    os.makedirs(d, exist_ok=True)

# Apple App Store Connect accepted dimensions:
# iPhone 6.7": 1284×2778
# iPhone 6.5": 1242×2688
# iPad 13":    2048×2732
# iPad 12.9":  2064×2752
IPHONE_67_CANVAS = (1284, 2778)
IPHONE_65_CANVAS = (1242, 2688)
IPAD_13_CANVAS = (2048, 2732)
IPAD_129_CANVAS = (2064, 2752)

# Warm rounded font — Georgia Bold for headlines, Avenir Next rounded for subtitles
FONT_HEADLINE = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
FONT_SUBTITLE = "/System/Library/Fonts/Avenir Next.ttc"

SCREENS = [
    {
        "file": "01_Onboarding.png",
        "out": "01_Welcome.png",
        "headline": "Your baby's\nfirst companion",
        "subtitle": "Every feeding, every nap, every smile",
        "colors": [(255, 230, 240), (255, 190, 215), (250, 150, 190)],
        "tilt": 3,
    },
    {
        "file": "02_Dashboard.png",
        "out": "02_Dashboard.png",
        "headline": "Everything you\nneed, one tap away",
        "subtitle": "Feedings · Sleep · Diapers · Notes",
        "colors": [(220, 235, 255), (180, 210, 255), (140, 175, 240)],
        "tilt": -2.5,
    },
    {
        "file": "03_Statistics.png",
        "out": "03_Statistics.png",
        "headline": "Understand your\nbaby's rhythm",
        "subtitle": "Beautiful charts that make sense",
        "colors": [(220, 245, 225), (170, 225, 185), (120, 200, 150)],
        "tilt": 3,
    },
    {
        "file": "04_Growth.png",
        "out": "04_Growth.png",
        "headline": "Watch them\ngrow, every day",
        "subtitle": "WHO growth charts included",
        "colors": [(255, 240, 220), (255, 215, 175), (250, 190, 130)],
        "tilt": -3,
    },
    {
        "file": "05_Health.png",
        "out": "05_Health.png",
        "headline": "Peace of mind\nfor every parent",
        "subtitle": "Vaccines, illnesses, medications",
        "colors": [(240, 230, 255), (215, 195, 250), (185, 160, 235)],
        "tilt": 2.5,
    },
    {
        "file": "06_Settings.png",
        "out": "06_Settings.png",
        "headline": "Made with love,\njust for you",
        "subtitle": "Themes · iCloud sync · Your way",
        "colors": [(225, 245, 250), (185, 225, 240), (145, 200, 225)],
        "tilt": -2.5,
    },
]


def load_headline_font(size):
    try:
        return ImageFont.truetype(FONT_HEADLINE, size)
    except:
        return ImageFont.load_default()

def load_subtitle_font(size):
    try:
        return ImageFont.truetype(FONT_SUBTITLE, size, index=1)  # Medium
    except:
        return ImageFont.load_default()


def lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def create_soft_gradient(size, colors):
    """Smooth vertical gradient with soft transitions."""
    w, h = size
    img = Image.new("RGBA", size)
    draw = ImageDraw.Draw(img)
    n = len(colors)
    for y in range(h):
        # Smooth eased interpolation
        t = y / h
        t_eased = t * t * (3 - 2 * t)  # smoothstep
        pos = t_eased * (n - 1)
        idx = min(int(pos), n - 2)
        frac = pos - idx
        c = lerp(colors[idx], colors[idx + 1], frac)
        draw.line([(0, y), (w, y)], fill=c + (255,))
    return img


def draw_soft_circle(canvas, cx, cy, radius, color, blur_amount=None):
    """Draw a soft glowing circle."""
    if blur_amount is None:
        blur_amount = radius * 0.5
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse(
        [(cx - radius, cy - radius), (cx + radius, cy + radius)],
        fill=color
    )
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur_amount))
    return Image.alpha_composite(canvas, overlay)


def draw_soft_shapes(canvas, cw, ch, base_colors):
    """Draw soft, warm, organic background shapes."""
    # Large soft circles for depth and warmth
    mid = base_colors[1]

    # Soft glow top-left
    c1 = (min(mid[0]+30, 255), min(mid[1]+30, 255), min(mid[2]+30, 255), 50)
    canvas = draw_soft_circle(canvas, int(cw * 0.15), int(ch * 0.08), int(cw * 0.5), c1)

    # Soft glow bottom-right
    c2 = (max(mid[0]-20, 0), max(mid[1]-20, 0), max(mid[2]-20, 0), 35)
    canvas = draw_soft_circle(canvas, int(cw * 0.85), int(ch * 0.7), int(cw * 0.4), c2)

    # Tiny floating circles (like bubbles — soft, childlike)
    random.seed(42)
    overlay = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for _ in range(8):
        bx = random.randint(int(cw * 0.05), int(cw * 0.95))
        by = random.randint(int(ch * 0.02), int(ch * 0.32))
        br = random.randint(int(cw * 0.01), int(cw * 0.025))
        opacity = random.randint(25, 50)
        bc = (255, 255, 255, opacity)
        od.ellipse([(bx-br, by-br), (bx+br, by+br)], fill=bc)
    # Blur them slightly for softness
    overlay = overlay.filter(ImageFilter.GaussianBlur(8))
    canvas = Image.alpha_composite(canvas, overlay)

    return canvas


# ─── REALISTIC DEVICE MOCKUPS ───

def build_iphone_frame(screenshot, frame_w):
    """
    Pixel-accurate iPhone 15 Pro Max mockup.
    Real proportions: 77.6mm × 159.9mm → ratio ~0.485
    Screen: 1290×2796 in a body with ~3mm bezels, 60px corner radius at screen level.
    """
    sw, sh = screenshot.size

    # Frame geometry
    bezel = max(int(frame_w * 0.022), 5)  # Thin bezels
    inner_w = frame_w - bezel * 2
    scale = inner_w / sw
    inner_h = int(sh * scale)
    frame_h = inner_h + bezel * 2

    corner_outer = int(frame_w * 0.082)  # iPhone 15 PM has ~60px radius at 1290 scale
    corner_inner = corner_outer - bezel

    # Full frame RGBA
    frame = Image.new("RGBA", (frame_w + 8, frame_h + 8), (0, 0, 0, 0))  # +8 for side buttons
    draw = ImageDraw.Draw(frame)

    ox, oy = 4, 4  # offset for side buttons

    # ── Titanium body gradient (realistic metal look) ──
    # Draw multiple layers for depth
    # Outer body
    draw.rounded_rectangle(
        [(ox, oy), (ox + frame_w - 1, oy + frame_h - 1)],
        radius=corner_outer,
        fill=(42, 42, 47, 255)
    )

    # Subtle inner edge (chamfer effect)
    draw.rounded_rectangle(
        [(ox + 1, oy + 1), (ox + frame_w - 2, oy + frame_h - 2)],
        radius=corner_outer - 1,
        fill=(55, 55, 60, 255)
    )
    draw.rounded_rectangle(
        [(ox + 2, oy + 2), (ox + frame_w - 3, oy + frame_h - 3)],
        radius=corner_outer - 2,
        fill=(42, 42, 47, 255)
    )

    # ── Screen area ──
    screen_scaled = screenshot.resize((inner_w, inner_h), Image.LANCZOS).convert("RGBA")

    # Create rounded mask for screen
    mask = Image.new("L", (inner_w, inner_h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([(0, 0), (inner_w - 1, inner_h - 1)], radius=corner_inner, fill=255)
    screen_scaled.putalpha(mask)

    frame.paste(screen_scaled, (ox + bezel, oy + bezel), screen_scaled)

    # ── Dynamic Island ──
    di_w = int(frame_w * 0.23)
    di_h = int(frame_w * 0.052)
    di_r = di_h // 2
    di_x = ox + (frame_w - di_w) // 2
    di_y = oy + bezel + int(inner_h * 0.005) + 2
    draw.rounded_rectangle(
        [(di_x, di_y), (di_x + di_w, di_y + di_h)],
        radius=di_r,
        fill=(5, 5, 5, 255)
    )
    # Camera lens dot inside Dynamic Island
    lens_r = int(di_h * 0.22)
    lens_x = di_x + di_w - int(di_w * 0.28)
    lens_y = di_y + di_h // 2
    draw.ellipse([(lens_x - lens_r, lens_y - lens_r), (lens_x + lens_r, lens_y + lens_r)],
                 fill=(15, 15, 20, 255))
    # Tiny lens reflection
    refl_r = max(lens_r // 3, 1)
    draw.ellipse([(lens_x - refl_r + 1, lens_y - refl_r - 1),
                  (lens_x + refl_r + 1, lens_y + refl_r - 1)],
                 fill=(30, 30, 45, 255))

    # ── Side buttons ──
    # Power button — right side
    btn_thickness = 4
    btn_h = int(frame_h * 0.048)
    btn_y = int(frame_h * 0.23)
    draw.rounded_rectangle(
        [(ox + frame_w - 1, oy + btn_y), (ox + frame_w + btn_thickness, oy + btn_y + btn_h)],
        radius=2,
        fill=(50, 50, 55, 255)
    )

    # Volume up — left side
    vol_h = int(frame_h * 0.033)
    vol_y1 = int(frame_h * 0.19)
    draw.rounded_rectangle(
        [(ox - btn_thickness, oy + vol_y1), (ox + 1, oy + vol_y1 + vol_h)],
        radius=2,
        fill=(50, 50, 55, 255)
    )
    # Volume down
    vol_y2 = vol_y1 + vol_h + int(frame_h * 0.012)
    draw.rounded_rectangle(
        [(ox - btn_thickness, oy + vol_y2), (ox + 1, oy + vol_y2 + vol_h)],
        radius=2,
        fill=(50, 50, 55, 255)
    )
    # Action button (smaller, above volume)
    act_h = int(frame_h * 0.018)
    act_y = vol_y1 - int(frame_h * 0.03)
    draw.rounded_rectangle(
        [(ox - btn_thickness, oy + act_y), (ox + 1, oy + act_y + act_h)],
        radius=2,
        fill=(50, 50, 55, 255)
    )

    # ── Highlight edge (top-left reflection for realism) ──
    highlight = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    # Top edge shine
    hd.rounded_rectangle(
        [(ox, oy), (ox + frame_w - 1, oy + frame_h - 1)],
        radius=corner_outer,
        outline=(255, 255, 255, 18),
        width=1
    )
    frame = Image.alpha_composite(frame, highlight)

    return frame


def build_ipad_frame(screenshot, frame_w):
    """
    Realistic iPad Pro (M4) mockup.
    Ultra-thin bezels, squared aluminum edges, landscape camera on portrait top.
    """
    sw, sh = screenshot.size

    bezel = max(int(frame_w * 0.018), 5)
    inner_w = frame_w - bezel * 2
    scale = inner_w / sw
    inner_h = int(sh * scale)
    frame_h = inner_h + bezel * 2

    corner_outer = int(frame_w * 0.028)
    corner_inner = max(corner_outer - bezel, 2)

    frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)

    # Body — space black aluminum
    draw.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=corner_outer,
        fill=(38, 38, 42, 255)
    )
    # Chamfer
    draw.rounded_rectangle(
        [(1, 1), (frame_w - 2, frame_h - 2)],
        radius=corner_outer - 1,
        fill=(52, 52, 56, 255)
    )
    draw.rounded_rectangle(
        [(2, 2), (frame_w - 3, frame_h - 3)],
        radius=corner_outer - 2,
        fill=(38, 38, 42, 255)
    )

    # Screen
    screen_scaled = screenshot.resize((inner_w, inner_h), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (inner_w, inner_h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([(0, 0), (inner_w - 1, inner_h - 1)], radius=corner_inner, fill=255)
    screen_scaled.putalpha(mask)
    frame.paste(screen_scaled, (bezel, bezel), screen_scaled)

    # Front camera (top center, tiny)
    cam_r = max(int(frame_w * 0.004), 2)
    cam_x = frame_w // 2
    cam_y = bezel // 2 + 1
    draw.ellipse([(cam_x-cam_r, cam_y-cam_r), (cam_x+cam_r, cam_y+cam_r)],
                 fill=(25, 25, 30, 255))

    # Edge highlight
    highlight = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(highlight)
    hd.rounded_rectangle(
        [(0, 0), (frame_w - 1, frame_h - 1)],
        radius=corner_outer,
        outline=(255, 255, 255, 15),
        width=1
    )
    frame = Image.alpha_composite(frame, highlight)

    return frame


def make_device_shadow(device, canvas_size, pos, offset=(15, 20), blur_r=50, opacity=50):
    """Realistic soft shadow behind device."""
    shadow_layer = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    # Extract alpha from device
    _, _, _, a = device.split()
    shadow_base = Image.new("RGBA", device.size, (0, 0, 0, opacity))
    shadow_base.putalpha(a)

    sx = pos[0] + offset[0]
    sy = pos[1] + offset[1]
    shadow_layer.paste(shadow_base, (sx, sy), shadow_base)
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(blur_r))
    return shadow_layer


def generate(screen, input_dir, output_dir, canvas_size, device_type):
    cw, ch = canvas_size

    src = os.path.join(input_dir, screen["file"])
    if not os.path.exists(src):
        print(f"  ⚠ Missing: {src}")
        return

    screenshot = Image.open(src).convert("RGBA")

    # 1. Soft gradient background
    canvas = create_soft_gradient(canvas_size, screen["colors"])

    # 2. Soft organic shapes
    canvas = draw_soft_shapes(canvas, cw, ch, screen["colors"])

    # 3. Build device mockup
    if device_type == "iphone":
        dev_w = int(cw * 0.55)
        device = build_iphone_frame(screenshot, dev_w)
    else:
        dev_w = int(cw * 0.62)
        device = build_ipad_frame(screenshot, dev_w)

    # 4. Rotate for dynamism
    tilt = screen["tilt"]
    rotated = device.rotate(tilt, expand=True, resample=Image.BICUBIC)

    # 5. Position: centered, lower third
    rw, rh = rotated.size
    dx = (cw - rw) // 2
    dy = int(ch * 0.365)

    # 6. Shadow
    shadow = make_device_shadow(rotated, canvas_size, (dx, dy),
                                 offset=(12, 16), blur_r=45, opacity=45)
    canvas = Image.alpha_composite(canvas, shadow)

    # 7. Paste device
    canvas.paste(rotated, (dx, dy), rotated)

    # 8. Text — warm, rounded, empathetic
    draw = ImageDraw.Draw(canvas)

    headline_size = int(cw * 0.085)
    sub_size = int(cw * 0.034)

    font_h = load_headline_font(headline_size)
    font_s = load_subtitle_font(sub_size)

    headline = screen["headline"]
    subtitle = screen["subtitle"]

    # Draw headline — multi-line, centered
    lines = headline.split("\n")
    line_h = int(headline_size * 1.2)
    total_h = line_h * len(lines)
    start_y = int(ch * 0.045)

    # Text color: dark warm gray (not pure black, feels softer)
    text_color = (55, 45, 55, 255)
    shadow_color = (255, 255, 255, 90)

    for i, line in enumerate(lines):
        bb = draw.textbbox((0, 0), line, font=font_h)
        tw = bb[2] - bb[0]
        tx = (cw - tw) // 2
        ty = start_y + i * line_h

        # Soft white glow behind text for readability
        draw.text((tx, ty + 2), line, fill=shadow_color, font=font_h)
        draw.text((tx, ty), line, fill=text_color, font=font_h)

    # Subtitle
    sub_y = start_y + len(lines) * line_h + int(ch * 0.012)
    bb_s = draw.textbbox((0, 0), subtitle, font=font_s)
    tw_s = bb_s[2] - bb_s[0]
    tx_s = (cw - tw_s) // 2
    sub_color = (80, 70, 80, 180)
    draw.text((tx_s, sub_y), subtitle, fill=sub_color, font=font_s)

    # Small soft dot separator
    dot_y = sub_y + int(sub_size * 1.8)
    dot_r = 4
    dot_x = cw // 2
    for offset in [-20, 0, 20]:
        draw.ellipse(
            [(dot_x + offset - dot_r, dot_y - dot_r),
             (dot_x + offset + dot_r, dot_y + dot_r)],
            fill=text_color[:3] + (40,)
        )

    # Save
    final = canvas.convert("RGB")
    final.save(os.path.join(output_dir, screen["out"]), "PNG")
    print(f"  ✓ {screen['out']}")


def main():
    print("=== Leona — Beautiful Marketing Screenshots v4 ===\n")

    print("iPhone 6.7\" (1284×2778):")
    for s in SCREENS:
        generate(s, IPHONE_DIR, OUT_IPHONE_67, IPHONE_67_CANVAS, "iphone")

    print("\niPhone 6.5\" (1242×2688):")
    for s in SCREENS:
        generate(s, IPHONE_DIR, OUT_IPHONE_65, IPHONE_65_CANVAS, "iphone")

    print("\niPad Pro 13\" (2048×2732):")
    for s in SCREENS:
        generate(s, IPAD_DIR, OUT_IPAD_13, IPAD_13_CANVAS, "ipad")

    print("\niPad Pro 12.9\" (2064×2752):")
    for s in SCREENS:
        generate(s, IPAD_DIR, OUT_IPAD_129, IPAD_129_CANVAS, "ipad")

    print(f"\n✅ Done!")
    print(f"  iPhone 6.7\" → {OUT_IPHONE_67}")
    print(f"  iPhone 6.5\" → {OUT_IPHONE_65}")
    print(f"  iPad 13\"    → {OUT_IPAD_13}")
    print(f"  iPad 12.9\"  → {OUT_IPAD_129}")


if __name__ == "__main__":
    main()
