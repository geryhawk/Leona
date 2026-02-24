#!/usr/bin/env python3
"""
Leona App Store Screenshot Generator v3
Full-bleed design — content fills the entire screen.
Marketing headline at top, rich simulated app UI below.
"""

from PIL import Image, ImageDraw, ImageFont
import os, math, random

IPHONE = (1290, 2796)
IPAD   = (2048, 2732)

OUT_IP = "/Users/chahine/Projects/Leona/Screenshots/iPhone"
OUT_PD = "/Users/chahine/Projects/Leona/Screenshots/iPad"
ICON   = "/Users/chahine/Projects/Leona/Leona/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# ── Colors ───────────────────────────────────────────────
PINK       = (220, 132, 163)
PINK_DARK  = (177, 92, 122)
PINK_LIGHT = (242, 200, 216)
BLUE       = (102, 153, 217)
PURPLE     = (153, 102, 204)
ORANGE     = (242, 153, 77)
GREEN      = (87, 179, 135)
CYAN       = (80, 190, 210)
INDIGO     = (100, 100, 200)
WHITE      = (255, 255, 255)
BLACK      = (0, 0, 0)
T1         = (25, 25, 30)
T2         = (130, 130, 140)
NIGHT      = (18, 18, 40)

os.makedirs(OUT_IP, exist_ok=True)
os.makedirs(OUT_PD, exist_ok=True)

def S(val, scale):
    return int(val * scale)

# ── Drawing helpers ──────────────────────────────────────

def gradient(draw, rect, c1, c2, steps=300):
    x0, y0, x1, y1 = rect
    h = y1 - y0
    for i in range(steps):
        t = i / steps
        c = tuple(int(c1[j] + (c2[j] - c1[j]) * t) for j in range(3))
        sy = y0 + int(h * i / steps)
        ey = y0 + int(h * (i + 1) / steps)
        draw.rectangle([x0, sy, x1, ey], fill=c)

def gradient3(draw, rect, c1, c2, c3, steps=300):
    """Three-color vertical gradient."""
    x0, y0, x1, y1 = rect
    h = y1 - y0
    for i in range(steps):
        t = i / steps
        if t < 0.5:
            t2 = t * 2
            c = tuple(int(c1[j] + (c2[j] - c1[j]) * t2) for j in range(3))
        else:
            t2 = (t - 0.5) * 2
            c = tuple(int(c2[j] + (c3[j] - c2[j]) * t2) for j in range(3))
        sy = y0 + int(h * i / steps)
        ey = y0 + int(h * (i + 1) / steps)
        draw.rectangle([x0, sy, x1, ey], fill=c)

def rrect(draw, rect, r, fill=None, outline=None, ow=0):
    draw.rounded_rectangle(list(rect), radius=r, fill=fill, outline=outline, width=ow)

def circ(draw, cx, cy, r, fill):
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=fill)

def font(size, bold=False):
    paths = [
        f"/System/Library/Fonts/SFPro{'Display' if size > 24 else 'Text'}-{'Bold' if bold else 'Regular'}.otf",
        f"/System/Library/Fonts/SF-Pro{'Display' if size > 24 else 'Text'}-{'Bold' if bold else 'Regular'}.otf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
    ]
    for p in paths:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, size)
            except: continue
    return ImageFont.load_default()

def center_text(draw, text, y, w, f, fill):
    bb = draw.textbbox((0,0), text, font=f)
    tw = bb[2] - bb[0]
    draw.text(((w - tw) // 2, y), text, font=f, fill=fill)

def right_text(draw, text, x_right, y, f, fill):
    bb = draw.textbbox((0,0), text, font=f)
    tw = bb[2] - bb[0]
    draw.text((x_right - tw, y), text, font=f, fill=fill)

def paste_icon(img, x, y, sz):
    try:
        ic = Image.open(ICON).convert("RGBA").resize((sz, sz), Image.LANCZOS)
        mask = Image.new("L", (sz, sz), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sz, sz], radius=int(sz*0.22), fill=255)
        img.paste(ic, (x, y), mask)
    except: pass

def draw_activity_row(draw, margin, w, s, y, name, detail, time, col, row_h=None):
    """Draw a single activity row. Returns the height used."""
    rh = row_h or S(100, s)
    rrect(draw, (margin, y, w - margin, y + rh - S(8,s)), S(16, s), fill=WHITE)
    circ(draw, margin + S(45, s), y + rh // 2 - S(4,s), S(20, s), fill=col + (45,))
    circ(draw, margin + S(45, s), y + rh // 2 - S(4,s), S(11, s), fill=col)
    draw.text((margin + S(82, s), y + S(18, s)), name, font=font(S(28, s), True), fill=T1)
    draw.text((margin + S(82, s), y + S(52, s)), detail, font=font(S(22, s)), fill=T2)
    right_text(draw, time, w - margin - S(20, s), y + S(32, s), font(S(22, s)), T2)
    return rh

def draw_summary_cards(draw, margin, w, s, y, items, card_h=None):
    """Draw 3 summary stat cards in a row. Returns height used."""
    ch = card_h or S(210, s)
    cw = (w - margin * 2 - S(40, s)) // 3
    for j, (val, label, col) in enumerate(items):
        cx = margin + j * (cw + S(20, s))
        rrect(draw, (cx, y, cx + cw, y + ch), S(24, s), fill=WHITE)
        circ(draw, cx + cw // 2, y + S(55, s), S(30, s), fill=col + (40,))
        circ(draw, cx + cw // 2, y + S(55, s), S(18, s), fill=col)
        vf = font(S(46, s), True)
        bb = draw.textbbox((0,0), val, font=vf)
        draw.text((cx + (cw - bb[2]+bb[0])//2, y + S(105, s)), val, font=vf, fill=T1)
        lf = font(S(22, s))
        bb = draw.textbbox((0,0), label, font=lf)
        draw.text((cx + (cw - bb[2]+bb[0])//2, y + S(160, s)), label, font=lf, fill=T2)
    return ch


# ── Screenshot 1: Welcome / Hero ─────────────────────────

def shot1(size, path):
    w, h = size
    s = w / 1290
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    gradient3(draw, (0,0,w,h), (252,235,243), (240,235,252), (248,238,248))

    # Decorative circles
    overlay = Image.new("RGBA", size, (0,0,0,0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([S(-80,s), S(100,s), S(350,s), S(530,s)], fill=PINK_LIGHT+(50,))
    od.ellipse([S(900,s), S(150,s), S(1450,s), S(700,s)], fill=BLUE+(25,))
    od.ellipse([S(400,s), S(2200,s), S(1100,s), S(2900,s)], fill=PURPLE+(18,))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)

    margin = S(80, s)
    # App icon
    ic_sz = S(200, s)
    paste_icon(img, (w - ic_sz) // 2, S(200, s), ic_sz)
    draw = ImageDraw.Draw(img)

    # App name + tagline
    center_text(draw, "Leona", S(440, s), w, font(S(90, s), True), PINK_DARK)
    center_text(draw, "The Parents' Companion", S(555, s), w, font(S(38, s)), T2)

    # Feature cards
    features = [
        ("Track Sleep Patterns", "Know exactly when and how long baby sleeps", INDIGO),
        ("Monitor Every Feeding", "Breast, formula, solids — all in one place", ORANGE),
        ("Growth Charts", "WHO percentiles built right in", GREEN),
        ("Share with Partner", "Real-time sync via iCloud", BLUE),
    ]
    card_h = S(115, s)
    gap = S(18, s)
    start_y = S(680, s)
    for i, (title, sub, col) in enumerate(features):
        cy = start_y + i * (card_h + gap)
        rrect(draw, (margin, cy, w - margin, cy + card_h), S(22, s), fill=WHITE)
        # Color accent bar
        rrect(draw, (margin, cy + S(10,s), margin + S(7, s), cy + card_h - S(10,s)), S(3, s), fill=col)
        # Icon dot
        circ(draw, margin + S(52, s), cy + card_h // 2, S(26, s), fill=col + (30,))
        circ(draw, margin + S(52, s), cy + card_h // 2, S(16, s), fill=col)
        draw.text((margin + S(95, s), cy + S(22, s)), title, font=font(S(30, s), True), fill=T1)
        draw.text((margin + S(95, s), cy + S(62, s)), sub, font=font(S(22, s)), fill=T2)

    # Dashboard preview section
    prev_y = S(1310, s)
    center_text(draw, "Your daily dashboard", prev_y, w, font(S(34, s), True), T1)
    prev_y += S(65, s)

    # Summary cards
    ch = draw_summary_cards(draw, margin, w, s, prev_y,
        [("5", "Feedings", ORANGE), ("9h 20m", "Sleep", INDIGO), ("6", "Diapers", CYAN)],
        card_h=S(190, s))
    prev_y += ch + S(30, s)

    # Activity list
    acts = [
        ("Breastfeeding", "15 min \u2022 Left breast", "10:30 AM", PINK),
        ("Formula", "120 ml", "9:15 AM", ORANGE),
        ("Sleep", "2h 10m \u2022 Nap", "7:00 AM", INDIGO),
        ("Diaper Change", "Pee + Poop", "6:45 AM", CYAN),
        ("Mom's Milk", "90 ml", "5:30 AM", PURPLE),
        ("Solid Food", "Banana, 45g", "4:00 AM", GREEN),
        ("Note", "First smile today!", "3:15 AM", T2),
    ]
    for name, detail, time, col in acts:
        if prev_y + S(95,s) > h - S(20,s): break
        rh = draw_activity_row(draw, margin, w, s, prev_y, name, detail, time, col, S(95, s))
        prev_y += rh

    img.save(path, quality=95)


# ── Screenshot 2: Dashboard ──────────────────────────────

def shot2(size, path):
    w, h = size
    s = w / 1290
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    gradient3(draw, (0,0,w,h), (255, 240, 245), (252, 242, 255), (242, 238, 255))

    margin = S(80, s)
    y = S(100, s)

    # Title
    center_text(draw, "Track Every", y, w, font(S(78, s), True), T1)
    y += S(95, s)
    center_text(draw, "Moment", y, w, font(S(78, s), True), PINK_DARK)
    y += S(100, s)
    center_text(draw, "Feedings, sleep & diapers at a glance", y, w, font(S(32, s)), T2)
    y += S(80, s)

    # Baby header card
    rrect(draw, (margin, y, w - margin, y + S(110, s)), S(20, s), fill=WHITE)
    circ(draw, margin + S(50, s), y + S(55, s), S(32, s), fill=PINK_LIGHT)
    draw.text((margin + S(95, s), y + S(22, s)), "Emma", font=font(S(32, s), True), fill=T1)
    draw.text((margin + S(95, s), y + S(60, s)), "3 months, 12 days", font=font(S(22, s)), fill=T2)
    y += S(140, s)

    # Today's Summary
    draw.text((margin, y), "Today's Summary", font=font(S(30, s), True), fill=T1)
    y += S(50, s)
    ch = draw_summary_cards(draw, margin, w, s, y,
        [("5", "Feedings", ORANGE), ("9h 20m", "Sleep", INDIGO), ("6", "Diapers", CYAN)])
    y += ch + S(35, s)

    # Quick Actions - proper pills with text
    draw.text((margin, y), "Quick Actions", font=font(S(30, s), True), fill=T1)
    y += S(50, s)
    actions = [
        ("Breast", PINK, "\u2764"), ("Formula", ORANGE, "\u2B50"),
        ("Pumped", PURPLE, "\u25CF"), ("Solids", GREEN, "\u25CF"),
        ("Sleep", INDIGO, "\u263E"), ("Diaper", CYAN, "\u25CF"),
        ("Growth", BLUE, "\u2191"), ("Note", (160,160,165), "\u270E"),
    ]
    cols = 4
    aw = (w - margin * 2 - S(36, s)) // cols
    ah = S(85, s)
    for i, (name, col, ico) in enumerate(actions):
        row, column = divmod(i, cols)
        ax = margin + column * (aw + S(12, s))
        ay = y + row * (ah + S(12, s))
        rrect(draw, (ax, ay, ax + aw, ay + ah), S(16, s), fill=col + (20,))
        nf = font(S(22, s), True)
        bb = draw.textbbox((0,0), name, font=nf)
        tw = bb[2] - bb[0]
        draw.text((ax + (aw - tw) // 2, ay + S(28, s)), name, font=nf, fill=col)
    y += 2 * (ah + S(12, s)) + S(30, s)

    # Activity list
    draw.text((margin, y), "Recent Activities", font=font(S(30, s), True), fill=T1)
    y += S(50, s)
    acts = [
        ("Breastfeeding", "15 min \u2022 Left breast", "10:30 AM", PINK),
        ("Formula", "120 ml", "9:15 AM", ORANGE),
        ("Sleep", "2h 10m \u2022 Nap", "7:00 AM", INDIGO),
        ("Diaper Change", "Pee + Poop", "6:45 AM", CYAN),
        ("Mom's Milk", "90 ml", "5:30 AM", PURPLE),
        ("Solid Food", "Banana, 45g", "4:00 AM", GREEN),
        ("Breastfeeding", "12 min \u2022 Right breast", "2:30 AM", PINK),
        ("Sleep", "3h 15m \u2022 Night", "11:00 PM", INDIGO),
        ("Diaper Change", "Pee", "10:30 PM", CYAN),
        ("Formula", "90 ml", "9:45 PM", ORANGE),
    ]
    for name, detail, time, col in acts:
        if y + S(95,s) > h - S(20,s): break
        rh = draw_activity_row(draw, margin, w, s, y, name, detail, time, col, S(95, s))
        y += rh

    img.save(path, quality=95)


# ── Screenshot 3: Growth Charts ──────────────────────────

def shot3(size, path):
    w, h = size
    s = w / 1290
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    gradient3(draw, (0,0,w,h), (235, 250, 242), (240, 248, 255), (235, 240, 255))

    margin = S(80, s)
    y = S(100, s)

    center_text(draw, "Watch Them", y, w, font(S(78, s), True), T1)
    y += S(95, s)
    center_text(draw, "Grow", y, w, font(S(78, s), True), GREEN)
    y += S(100, s)
    center_text(draw, "WHO percentile charts built right in", y, w, font(S(32, s)), T2)
    y += S(80, s)

    # Measurement cards
    pills = [("6.2 kg", "Weight", BLUE, "P62"), ("64 cm", "Height", GREEN, "P55"), ("42 cm", "Head", PURPLE, "P48")]
    pw = (w - margin * 2 - S(30, s)) // 3
    ph = S(155, s)
    for j, (val, label, col, perc) in enumerate(pills):
        px = margin + j * (pw + S(15, s))
        rrect(draw, (px, y, px + pw, y + ph), S(20, s), fill=WHITE)
        draw.text((px + S(18, s), y + S(14, s)), label, font=font(S(22, s)), fill=T2)
        draw.text((px + S(18, s), y + S(44, s)), val, font=font(S(36, s), True), fill=col)
        # Percentile badge
        badge_w = S(65, s)
        badge_h = S(28, s)
        bx = px + S(18, s)
        by = y + S(100, s)
        rrect(draw, (bx, by, bx + badge_w, by + badge_h), S(14, s), fill=GREEN + (30,))
        pf = font(S(18, s), True)
        bb = draw.textbbox((0,0), perc, font=pf)
        draw.text((bx + (badge_w - bb[2]+bb[0])//2, by + S(3, s)), perc, font=pf, fill=GREEN)
    y += ph + S(30, s)

    # Chart type segmented control
    tabs = ["Weight", "Height", "Head"]
    seg_w = w - margin * 2
    seg_h = S(52, s)
    rrect(draw, (margin, y, margin + seg_w, y + seg_h), S(14, s), fill=(230, 235, 240))
    tab_w = seg_w // 3
    for j, tab in enumerate(tabs):
        tx = margin + j * tab_w
        if j == 0:
            rrect(draw, (tx + S(4,s), y + S(4,s), tx + tab_w - S(4,s), y + seg_h - S(4,s)), S(12,s), fill=WHITE)
            tf = font(S(24,s), True)
            tcol = BLUE
        else:
            tf = font(S(24,s))
            tcol = T2
        bb = draw.textbbox((0,0), tab, font=tf)
        draw.text((tx + (tab_w - bb[2]+bb[0])//2, y + S(12,s)), tab, font=tf, fill=tcol)
    y += seg_h + S(30, s)

    # Chart area
    chart_x = margin + S(60, s)
    chart_w = w - margin * 2 - S(80, s)
    chart_h = S(650, s)

    # Percentile band background
    overlay = Image.new("RGBA", size, (0,0,0,0))
    od = ImageDraw.Draw(overlay)
    od.rounded_rectangle([chart_x, y, chart_x + chart_w, y + chart_h], radius=S(12,s), fill=GREEN + (18,))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)

    # Grid lines
    for i in range(6):
        gy = y + i * (chart_h // 5)
        draw.line([(chart_x, gy), (chart_x + chart_w, gy)], fill=GREEN+(40,), width=1)

    # Y-axis labels
    y_labels = ["10 kg", "8 kg", "6 kg", "4 kg", "2 kg", "0"]
    af = font(S(18, s))
    for i, yl in enumerate(y_labels):
        ly = y + i * (chart_h // 5) - S(10, s)
        draw.text((margin, ly), yl, font=af, fill=T2)

    # X-axis
    x_labels = ["0", "3", "6", "9", "12"]
    for i, xl in enumerate(x_labels):
        lx = chart_x + i * (chart_w // 4)
        draw.text((lx - S(5,s), y + chart_h + S(10, s)), xl, font=af, fill=T2)
    draw.text((chart_x + chart_w // 2 - S(60,s), y + chart_h + S(38,s)), "Age (months)", font=font(S(20,s)), fill=T2)

    # P97 / P50 / P3 dashed lines
    for pct, pct_y_frac, label in [(0.25, "P97"), (0.5, "P50"), (0.78, "P3")]:
        line_y = y + int(pct * chart_h)
        for dx in range(0, chart_w, 18):
            draw.line([(chart_x+dx, line_y), (chart_x+dx+9, line_y)], fill=GREEN+(80,), width=1)
        draw.text((chart_x + chart_w + S(8,s), line_y - S(10,s)), label, font=font(S(16,s)), fill=GREEN)

    # Growth curve
    pts = []
    for i in range(30):
        t = i / 29
        px = chart_x + int(t * chart_w)
        # Curve from ~3kg to ~8.5kg mapped onto chart
        weight = 3.0 + 5.5 * (1 - math.exp(-2.5 * t))
        py = y + chart_h - int(((weight - 0) / 10.0) * chart_h)
        pts.append((px, py))
    for i in range(len(pts)-1):
        draw.line([pts[i], pts[i+1]], fill=BLUE, width=S(5,s))
    for px, py in pts[::6]:
        circ(draw, px, py, S(9, s), fill=BLUE)
        circ(draw, px, py, S(4, s), fill=WHITE)

    y += chart_h + S(65, s)

    # Legend
    circ(draw, margin + S(15,s), y + S(10,s), S(8,s), fill=BLUE)
    draw.text((margin + S(35,s), y - S(2,s)), "Emma", font=font(S(24,s), True), fill=T1)
    draw.line([(margin + S(140,s), y+S(10,s)), (margin + S(190,s), y+S(10,s))], fill=GREEN, width=2)
    draw.text((margin + S(205,s), y - S(2,s)), "P50 median", font=font(S(22,s)), fill=T2)
    y += S(45, s)
    rrect(draw, (margin, y, margin + S(28,s), y + S(20,s)), S(4,s), fill=GREEN+(30,))
    draw.text((margin + S(42,s), y - S(2,s)), "P3\u2013P97 normal range", font=font(S(22,s)), fill=T2)

    y += S(60, s)

    # Additional: Recent measurements table
    draw.text((margin, y), "Recent Measurements", font=font(S(30, s), True), fill=T1)
    y += S(50, s)
    measurements = [
        ("Today", "6.2 kg", "64 cm", "42 cm"),
        ("2 weeks ago", "5.9 kg", "63 cm", "41.5 cm"),
        ("1 month ago", "5.5 kg", "61.5 cm", "41 cm"),
        ("2 months ago", "4.8 kg", "58 cm", "40 cm"),
    ]
    # Header
    hf = font(S(22, s), True)
    col_w = (w - margin * 2) // 4
    for j, hdr in enumerate(["Date", "Weight", "Height", "Head"]):
        draw.text((margin + j * col_w + S(10,s), y), hdr, font=hf, fill=T2)
    y += S(40, s)
    draw.line([(margin, y), (w - margin, y)], fill=(220,220,225), width=1)
    y += S(10, s)
    rf = font(S(22, s))
    for date, wt, ht, hd in measurements:
        if y + S(50,s) > h - S(20,s): break
        rrect(draw, (margin, y, w - margin, y + S(48, s)), S(10, s), fill=WHITE)
        vals = [date, wt, ht, hd]
        cols_c = [T1, BLUE, GREEN, PURPLE]
        for j, (v, vc) in enumerate(zip(vals, cols_c)):
            draw.text((margin + j * col_w + S(10,s), y + S(12,s)), v, font=rf, fill=vc)
        y += S(55, s)

    img.save(path, quality=95)


# ── Screenshot 4: Statistics ─────────────────────────────

def shot4(size, path):
    w, h = size
    s = w / 1290
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    gradient3(draw, (0,0,w,h), (255, 244, 235), (255, 248, 245), (240, 236, 255))

    margin = S(80, s)
    y = S(100, s)

    center_text(draw, "Insightful", y, w, font(S(78, s), True), T1)
    y += S(95, s)
    center_text(draw, "Statistics", y, w, font(S(78, s), True), ORANGE)
    y += S(100, s)
    center_text(draw, "Patterns and trends at your fingertips", y, w, font(S(32, s)), T2)
    y += S(75, s)

    # Period segmented control
    seg_w = w - margin * 2
    seg_h = S(50, s)
    rrect(draw, (margin, y, margin + seg_w, y + seg_h), S(14, s), fill=(240, 235, 230))
    periods = ["Today", "3 Days", "7 Days", "30 Days"]
    ppw = seg_w // len(periods)
    for j, p in enumerate(periods):
        px = margin + j * ppw
        if j == 2:
            rrect(draw, (px + S(4,s), y + S(4,s), px + ppw - S(4,s), y + seg_h - S(4,s)), S(12,s), fill=WHITE)
            pf = font(S(22,s), True)
            col = ORANGE
        else:
            pf = font(S(22,s))
            col = T2
        bb = draw.textbbox((0,0), p, font=pf)
        draw.text((px + (ppw - bb[2]+bb[0])//2, y + S(13,s)), p, font=pf, fill=col)
    y += seg_h + S(25, s)

    # Category segmented control
    rrect(draw, (margin, y, margin + seg_w, y + seg_h), S(14, s), fill=(240, 235, 230))
    cats = [("Feeding", ORANGE), ("Sleep", INDIGO), ("Diaper", CYAN)]
    ctw = seg_w // 3
    for j, (name, col) in enumerate(cats):
        cx = margin + j * ctw
        if j == 0:
            rrect(draw, (cx + S(4,s), y + S(4,s), cx + ctw - S(4,s), y + seg_h - S(4,s)), S(12,s), fill=WHITE)
            cf = font(S(22,s), True)
            c = col
        else:
            cf = font(S(22,s))
            c = T2
        bb = draw.textbbox((0,0), name, font=cf)
        draw.text((cx + (ctw - bb[2]+bb[0])//2, y + S(13,s)), name, font=cf, fill=c)
    y += seg_h + S(30, s)

    # Stat cards 2x2
    card_w = (w - margin * 2 - S(20, s)) // 2
    card_h = S(165, s)
    gap = S(20, s)
    stats = [
        ("28", "Total Feedings", ORANGE),
        ("12", "Breastfeeding", PINK),
        ("1.4 L", "Formula Total", ORANGE),
        ("2h 45m", "Avg. Interval", BLUE),
    ]
    for i, (val, label, col) in enumerate(stats):
        row, column = divmod(i, 2)
        cx = margin + column * (card_w + gap)
        cy = y + row * (card_h + gap)
        rrect(draw, (cx, cy, cx + card_w, cy + card_h), S(20, s), fill=WHITE)
        circ(draw, cx + S(35,s), cy + S(35,s), S(18,s), fill=col+(35,))
        circ(draw, cx + S(35,s), cy + S(35,s), S(10,s), fill=col)
        draw.text((cx + S(25,s), cy + S(60,s)), val, font=font(S(40,s), True), fill=T1)
        draw.text((cx + S(25,s), cy + S(115,s)), label, font=font(S(22,s)), fill=T2)
    y += 2 * (card_h + gap) + S(20, s)

    # Feeding bar chart
    draw.text((margin, y), "Weekly Feeding Breakdown", font=font(S(28, s), True), fill=T1)
    y += S(45, s)
    ch_h = S(380, s)
    rrect(draw, (margin, y, w - margin, y + ch_h), S(20, s), fill=WHITE)

    # Grid lines
    for i in range(5):
        gy = y + S(25,s) + i * ((ch_h - S(75,s)) // 4)
        draw.line([(margin + S(20,s), gy), (w - margin - S(20,s), gy)], fill=(242,242,242), width=1)

    days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    bar_w = S(50, s)
    inner_w = w - margin * 2 - S(40, s)
    bar_gap = (inner_w - 7 * bar_w) // 8
    colors = [ORANGE, PINK, PURPLE, GREEN]
    random.seed(42)
    for d in range(7):
        bx = margin + S(20,s) + bar_gap + d * (bar_w + bar_gap)
        bottom = y + ch_h - S(50,s)
        heights = [random.uniform(80, 160), random.uniform(25, 70), random.uniform(12, 45), random.uniform(8, 30)]
        for seg_i, seg_h_val in enumerate(heights):
            sh = int(seg_h_val * s)
            if sh > 0:
                top = bottom - sh
                if seg_i == len(heights) - 1:
                    rrect(draw, (bx, top, bx + bar_w, bottom), S(6,s), fill=colors[seg_i])
                else:
                    draw.rectangle([bx, top, bx + bar_w, bottom], fill=colors[seg_i])
                bottom = top
        df = font(S(16,s))
        bb = draw.textbbox((0,0), days[d], font=df)
        draw.text((bx + (bar_w - bb[2]+bb[0])//2, y + ch_h - S(32,s)), days[d], font=df, fill=T2)
    y += ch_h + S(25, s)

    # Legend
    legend = [("Formula", ORANGE), ("Breast", PINK), ("Pumped", PURPLE), ("Solids", GREEN)]
    lx = margin
    for name, col in legend:
        circ(draw, lx + S(10,s), y + S(10,s), S(8,s), fill=col)
        draw.text((lx + S(25,s), y - S(2,s)), name, font=font(S(20,s)), fill=T2)
        lx += S(170, s)
    y += S(55, s)

    # Additional stat: sleep summary
    draw.text((margin, y), "Sleep Overview (7 days)", font=font(S(28, s), True), fill=T1)
    y += S(45, s)
    sleep_stats = [
        ("Avg. Night", "8h 45m", INDIGO),
        ("Avg. Naps", "2h 30m", BLUE),
        ("Total", "78h 15m", PURPLE),
    ]
    sw = (w - margin * 2 - S(30, s)) // 3
    sh_card = S(120, s)
    for j, (label, val, col) in enumerate(sleep_stats):
        sx = margin + j * (sw + S(15, s))
        rrect(draw, (sx, y, sx + sw, y + sh_card), S(16, s), fill=col + (15,))
        draw.text((sx + S(15,s), y + S(15,s)), label, font=font(S(20,s)), fill=T2)
        draw.text((sx + S(15,s), y + S(55,s)), val, font=font(S(34,s), True), fill=col)
    y += sh_card + S(30, s)

    # Diaper summary
    draw.text((margin, y), "Diaper Count (7 days)", font=font(S(28, s), True), fill=T1)
    y += S(45, s)
    diaper_stats = [("Wet", "24", CYAN), ("Dirty", "14", ORANGE), ("Mixed", "8", GREEN)]
    for j, (label, val, col) in enumerate(diaper_stats):
        sx = margin + j * (sw + S(15, s))
        if y + sh_card > h - S(20,s): break
        rrect(draw, (sx, y, sx + sw, y + sh_card), S(16, s), fill=col + (15,))
        draw.text((sx + S(15,s), y + S(15,s)), label, font=font(S(20,s)), fill=T2)
        draw.text((sx + S(15,s), y + S(55,s)), val, font=font(S(34,s), True), fill=col)

    img.save(path, quality=95)


# ── Screenshot 5: Night Mode ─────────────────────────────

def shot5(size, path):
    w, h = size
    s = w / 1290
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    gradient(draw, (0,0,w,h), (12, 12, 35), (25, 20, 55))

    # Stars
    random.seed(42)
    for _ in range(180):
        sx = random.randint(0, w)
        sy = random.randint(0, h)
        sr = random.uniform(1, 3) * s
        a = random.randint(80, 255)
        circ(draw, sx, sy, sr, fill=(200+random.randint(0,55), 200+random.randint(0,55), 255))

    margin = S(80, s)
    y = S(140, s)

    center_text(draw, "Sweet Dreams", y, w, font(S(78, s), True), (220, 220, 245))
    y += S(95, s)
    center_text(draw, "Mode", y, w, font(S(78, s), True), (160, 160, 230))
    y += S(100, s)
    center_text(draw, "Ambient night sky while baby sleeps", y, w, font(S(32, s)), (130, 130, 175))
    y += S(130, s)

    # Moon with glow
    moon_x, moon_y = w // 2, y + S(80, s)
    overlay = Image.new("RGBA", size, (0,0,0,0))
    od = ImageDraw.Draw(overlay)
    for r in range(S(140,s), S(20,s), -S(4,s)):
        a = max(2, 30 - r // S(5,s))
        od.ellipse([moon_x-r, moon_y-r, moon_x+r, moon_y+r], fill=(180,180,255,a))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)

    circ(draw, moon_x, moon_y, S(60, s), fill=(220, 220, 240))
    circ(draw, moon_x + S(20,s), moon_y - S(14,s), S(52, s), fill=(18, 18, 40))
    y = moon_y + S(130, s)

    # Timer
    center_text(draw, "02:34:17", y, w, font(S(110, s)), (220, 220, 245))
    y += S(135, s)
    center_text(draw, "Sleeping peacefully...", y, w, font(S(32, s)), (140, 140, 190))
    y += S(100, s)

    # Info card
    card_w = S(550, s)
    cx = (w - card_w) // 2
    rrect(draw, (cx, y, cx + card_w, y + S(130, s)), S(22, s), fill=(30, 30, 60))
    rrect(draw, (cx, y, cx + card_w, y + S(130, s)), S(22, s), outline=(60,60,100), ow=1)
    draw.text((cx + S(30,s), y + S(18,s)), "Fell asleep at", font=font(S(22,s)), fill=(120,120,165))
    draw.text((cx + S(30,s), y + S(58,s)), "9:26 PM", font=font(S(36,s), True), fill=(210,210,240))
    right_text(draw, "Night sleep", cx + card_w - S(30,s), y + S(18,s), font(S(22,s)), (120,120,165))
    right_text(draw, "Since 2h 34m", cx + card_w - S(30,s), y + S(58,s), font(S(28,s), True), (180,180,215))
    y += S(175, s)

    # Wake up button
    btn_w = S(420, s)
    bx = (w - btn_w) // 2
    rrect(draw, (bx, y, bx + btn_w, y + S(80, s)), S(40, s), fill=INDIGO)
    center_text(draw, "Wake Up", y + S(20, s), w, font(S(30, s), True), WHITE)
    y += S(145, s)

    # Tonight's summary
    center_text(draw, "Tonight's Summary", y, w, font(S(30, s), True), (190, 190, 220))
    y += S(60, s)

    tonight_w = S(450, s)
    tonight_items = [
        ("Total sleep", "6h 42m", INDIGO),
        ("Awakenings", "2", PURPLE),
        ("Longest stretch", "3h 15m", BLUE),
    ]
    for label, val, col in tonight_items:
        if y + S(80,s) > h - S(150,s): break
        ix = (w - tonight_w) // 2
        rrect(draw, (ix, y, ix + tonight_w, y + S(70, s)), S(16, s), fill=(30, 30, 60))
        rrect(draw, (ix, y, ix + tonight_w, y + S(70, s)), S(16, s), outline=(50,50,80), ow=1)
        draw.text((ix + S(20,s), y + S(20,s)), label, font=font(S(24,s)), fill=(140,140,180))
        right_text(draw, val, ix + tonight_w - S(20,s), y + S(18,s), font(S(28,s), True), col)
        y += S(85, s)

    y += S(30, s)

    # Bottom tagline
    center_text(draw, "The app transforms into a calming", y, w, font(S(26, s)), (110, 110, 155))
    y += S(40, s)
    center_text(draw, "night sky while your baby sleeps", y, w, font(S(26, s)), (110, 110, 155))
    y += S(65, s)

    # Privacy note at bottom
    center_text(draw, "Screen dims automatically \u2022 No blue light", y, w, font(S(22, s)), (90, 90, 130))

    img.save(path, quality=95)


# ── Screenshot 6: Partner Sharing ────────────────────────

def shot6(size, path):
    w, h = size
    s = w / 1290
    img = Image.new("RGB", size)
    draw = ImageDraw.Draw(img)
    gradient3(draw, (0,0,w,h), (232, 240, 255), (242, 238, 252), (248, 240, 250))

    margin = S(80, s)
    y = S(100, s)

    center_text(draw, "Share with", y, w, font(S(78, s), True), T1)
    y += S(95, s)
    center_text(draw, "Your Partner", y, w, font(S(78, s), True), BLUE)
    y += S(100, s)
    center_text(draw, "Both parents, always in sync via iCloud", y, w, font(S(32, s)), T2)
    y += S(80, s)

    # Two "screens" side by side
    gap = S(40, s)
    scr_w = (w - margin * 2 - gap) // 2
    scr_h = S(850, s)
    left_x = margin
    right_x = margin + scr_w + gap

    for side_label, sx_start, badge_col, badge_text_col in [
        ("Mom", left_x, PINK, PINK_DARK),
        ("Dad", right_x, BLUE, (50,80,160)),
    ]:
        # Screen card
        rrect(draw, (sx_start, y, sx_start + scr_w, y + scr_h), S(24, s), fill=WHITE)

        sy = y + S(20, s)
        draw.text((sx_start + S(20,s), sy), "Home", font=font(S(24,s), True), fill=T1)
        # Badge
        bw = S(72, s)
        bh = S(28, s)
        rrect(draw, (sx_start + scr_w - bw - S(12,s), sy, sx_start + scr_w - S(12,s), sy + bh), S(14,s), fill=badge_col+(35,))
        bf = font(S(16,s), True)
        bb = draw.textbbox((0,0), side_label, font=bf)
        draw.text((sx_start + scr_w - bw - S(12,s) + (bw - bb[2]+bb[0])//2, sy + S(4,s)), side_label, font=bf, fill=badge_text_col)

        sy += S(50, s)
        # Mini summary cards
        mcw = (scr_w - S(40,s)) // 3
        mch = S(120, s)
        for j, (val, lbl, col) in enumerate([("5", "Meals", ORANGE), ("8h", "Sleep", INDIGO), ("4", "Diapers", CYAN)]):
            mx = sx_start + S(12,s) + j * (mcw + S(8,s))
            rrect(draw, (mx, sy, mx + mcw, sy + mch), S(12,s), fill=(248,248,252))
            circ(draw, mx + mcw//2, sy + S(28,s), S(14,s), fill=col)
            vf = font(S(24,s), True)
            bb = draw.textbbox((0,0), val, font=vf)
            draw.text((mx + (mcw-bb[2]+bb[0])//2, sy + S(52,s)), val, font=vf, fill=T1)
            lf = font(S(14,s))
            bb = draw.textbbox((0,0), lbl, font=lf)
            draw.text((mx + (mcw-bb[2]+bb[0])//2, sy + S(82,s)), lbl, font=lf, fill=T2)

        sy += mch + S(15, s)
        # Activity rows
        mini_acts = [
            ("Breastfeed", "15 min \u2022 Left", "10:30 AM", PINK),
            ("Formula", "120 ml", "9:15 AM", ORANGE),
            ("Sleep", "2h 10m", "7:00 AM", INDIGO),
            ("Diaper", "Pee + Poop", "6:45 AM", CYAN),
            ("Mom's Milk", "90 ml", "5:30 AM", PURPLE),
            ("Solid Food", "Banana", "4:00 AM", GREEN),
        ]
        rh = S(65, s)
        for name, detail, time, col in mini_acts:
            if sy + rh > y + scr_h - S(10,s): break
            rrect(draw, (sx_start + S(12,s), sy, sx_start + scr_w - S(12,s), sy + rh - S(5,s)), S(10,s), fill=(248,248,252))
            circ(draw, sx_start + S(30,s), sy + rh//2 - S(3,s), S(9,s), fill=col)
            draw.text((sx_start + S(48,s), sy + S(8,s)), name, font=font(S(18,s), True), fill=T1)
            draw.text((sx_start + S(48,s), sy + S(32,s)), detail, font=font(S(14,s)), fill=T2)
            right_text(draw, time, sx_start + scr_w - S(20,s), sy + S(16,s), font(S(14,s)), T2)
            sy += rh

    # Sync icon between the two screens
    sync_x = w // 2
    sync_y = y + scr_h // 2
    overlay = Image.new("RGBA", size, (0,0,0,0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([sync_x - S(38,s), sync_y - S(38,s), sync_x + S(38,s), sync_y + S(38,s)], fill=BLUE+(70,))
    od.ellipse([sync_x - S(26,s), sync_y - S(26,s), sync_x + S(26,s), sync_y + S(26,s)], fill=BLUE+(200,))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)
    center_text(draw, "\u21C4", sync_y - S(15,s), w, font(S(30,s), True), WHITE)

    y += scr_h + S(40, s)
    center_text(draw, "Same data, real-time sync", y, w, font(S(34, s), True), T1)
    y += S(50, s)
    center_text(draw, "No account needed \u2022 Just iCloud", y, w, font(S(28, s)), T2)
    y += S(65, s)

    # Privacy card
    rrect(draw, (margin, y, w - margin, y + S(85, s)), S(16, s), fill=WHITE)
    draw.text((margin + S(25,s), y + S(12,s)), "\U0001F512  Your data stays private", font=font(S(26,s), True), fill=T1)
    draw.text((margin + S(25,s), y + S(48,s)), "Stored only in your personal iCloud \u2022 No third parties", font=font(S(20,s)), fill=T2)
    y += S(110, s)

    # How it works section
    if y + S(250, s) < h - S(20, s):
        center_text(draw, "How it works", y, w, font(S(30, s), True), T1)
        y += S(55, s)
        steps = [
            ("1", "Enable iCloud sync in Settings", BLUE),
            ("2", "Invite your partner from the Share menu", PURPLE),
            ("3", "Both see the same data in real-time", GREEN),
        ]
        for num, text, col in steps:
            if y + S(65, s) > h - S(20,s): break
            rrect(draw, (margin, y, w - margin, y + S(60, s)), S(14, s), fill=col + (12,))
            circ(draw, margin + S(35, s), y + S(30, s), S(18, s), fill=col)
            nf = font(S(22, s), True)
            bb = draw.textbbox((0,0), num, font=nf)
            draw.text((margin + S(35, s) - bb[2]//2, y + S(18, s)), num, font=nf, fill=WHITE)
            draw.text((margin + S(70, s), y + S(17, s)), text, font=font(S(24, s)), fill=T1)
            y += S(72, s)

    img.save(path, quality=95)


# ── Main ─────────────────────────────────────────────────

def main():
    shots = [
        (shot1, "01_Welcome"),
        (shot2, "02_Dashboard"),
        (shot3, "03_Growth"),
        (shot4, "04_Statistics"),
        (shot5, "05_NightMode"),
        (shot6, "06_Sharing"),
    ]
    for fn, name in shots:
        for label, sz, out in [("iPhone", IPHONE, OUT_IP), ("iPad", IPAD, OUT_PD)]:
            p = os.path.join(out, f"{name}.png")
            print(f"  {label}: {name}...")
            fn(sz, p)
    print("\nDone!")

if __name__ == "__main__":
    main()
