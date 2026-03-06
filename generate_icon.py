#!/usr/bin/env python3
"""
GrogyBot App Icon Generator — Golden Robot Mascot 🤖
Generates a 1024x1024 PNG with transparent background
and saves it to the Xcode assets folder.
"""

from PIL import Image, ImageDraw, ImageFilter
import math, os

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__),
    "GrogyBot/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)

# ── helpers ──────────────────────────────────────────────────────────────────

def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB(A) tuples."""
    t = max(0, min(1, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))

def soft_ellipse(img, bbox, fill, blur=0):
    """Draw an ellipse, optionally with soft edges."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(bbox, fill=fill)
    if blur > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(radius=blur))
    return Image.alpha_composite(img, layer)

def rounded_rect(draw, bbox, radius, fill, outline=None, width=0):
    """Draw a rounded rectangle."""
    x0, y0, x1, y1 = bbox
    r = min(radius, (x1 - x0) // 2, (y1 - y0) // 2)
    draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
    draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
    draw.pieslice([x0, y0, x0 + 2*r, y0 + 2*r], 180, 270, fill=fill)
    draw.pieslice([x1 - 2*r, y0, x1, y0 + 2*r], 270, 360, fill=fill)
    draw.pieslice([x0, y1 - 2*r, x0 + 2*r, y1], 90, 180, fill=fill)
    draw.pieslice([x1 - 2*r, y1 - 2*r, x1, y1], 0, 90, fill=fill)
    if outline and width > 0:
        draw.arc([x0, y0, x0 + 2*r, y0 + 2*r], 180, 270, fill=outline, width=width)
        draw.arc([x1 - 2*r, y0, x1, y0 + 2*r], 270, 360, fill=outline, width=width)
        draw.arc([x0, y1 - 2*r, x0 + 2*r, y1], 90, 180, fill=outline, width=width)
        draw.arc([x1 - 2*r, y1 - 2*r, x1, y1], 0, 90, fill=outline, width=width)
        draw.line([x0 + r, y0, x1 - r, y0], fill=outline, width=width)
        draw.line([x0 + r, y1, x1 - r, y1], fill=outline, width=width)
        draw.line([x0, y0 + r, x0, y1 - r], fill=outline, width=width)
        draw.line([x1, y0 + r, x1, y1 - r], fill=outline, width=width)

# ── colour palette ───────────────────────────────────────────────────────────

GOLD_LIGHT   = (245, 210, 120)    # highlight gold
GOLD_MID     = (218, 175, 75)     # main body gold
GOLD_DARK    = (180, 140, 50)     # shadow gold
GOLD_DEEP    = (140, 105, 35)     # deep shadow
BRONZE       = (165, 120, 50)     # darker accents
BLUE_GLOW    = (80, 180, 255)     # eye glow
BLUE_BRIGHT  = (130, 210, 255)    # eye highlight
BLUE_DEEP    = (30, 100, 200)     # eye depth
DARK_METAL   = (60, 50, 35)       # dark metal accents
CREAM        = (255, 240, 200)    # light highlights

CX, CY = SIZE // 2, SIZE // 2 + 20  # centre of robot, slightly below canvas centre

# ── 1. transparent background ────────────────────────────────────────────────

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# ── 2. antenna ───────────────────────────────────────────────────────────────

antenna = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ad = ImageDraw.Draw(antenna)

# Antenna stick
ANT_BASE_Y = CY - 250
ANT_TOP_Y  = CY - 380
ANT_X      = CX
ad.line([(ANT_X, ANT_BASE_Y), (ANT_X, ANT_TOP_Y)], fill=(*GOLD_DARK, 255), width=10)
# Slight highlight on left side of antenna stick
ad.line([(ANT_X - 3, ANT_BASE_Y), (ANT_X - 3, ANT_TOP_Y)], fill=(*GOLD_LIGHT, 120), width=3)

# Antenna ball (glowing)
ANT_BALL_R = 28
ad.ellipse([ANT_X - ANT_BALL_R, ANT_TOP_Y - ANT_BALL_R,
            ANT_X + ANT_BALL_R, ANT_TOP_Y + ANT_BALL_R],
           fill=(*BLUE_GLOW, 255))
# Glow around antenna ball
ant_glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(ant_glow).ellipse([ANT_X - ANT_BALL_R - 25, ANT_TOP_Y - ANT_BALL_R - 25,
                                   ANT_X + ANT_BALL_R + 25, ANT_TOP_Y + ANT_BALL_R + 25],
                                  fill=(*BLUE_GLOW, 60))
ant_glow = ant_glow.filter(ImageFilter.GaussianBlur(radius=15))
img = Image.alpha_composite(img, ant_glow)
# Highlight on ball
ad.ellipse([ANT_X - 10, ANT_TOP_Y - 16, ANT_X + 4, ANT_TOP_Y - 4],
           fill=(*BLUE_BRIGHT, 200))

img = Image.alpha_composite(img, antenna)

# ── 3. ears (side receivers) ─────────────────────────────────────────────────

ears_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
erd = ImageDraw.Draw(ears_layer)

EAR_W = 45
EAR_H = 90
EAR_Y = CY - 60

# Left ear
rounded_rect(erd, [CX - 230 - EAR_W, EAR_Y - EAR_H//2,
                    CX - 230, EAR_Y + EAR_H//2],
             radius=18, fill=(*GOLD_DARK, 255))
# Ear highlight
rounded_rect(erd, [CX - 230 - EAR_W + 6, EAR_Y - EAR_H//2 + 6,
                    CX - 230 - 6, EAR_Y - EAR_H//2 + 30],
             radius=10, fill=(*GOLD_LIGHT, 100))
# Ear detail lines
for i in range(3):
    ly = EAR_Y - 15 + i * 18
    erd.line([(CX - 230 - EAR_W + 12, ly), (CX - 230 - 12, ly)],
             fill=(*BRONZE, 180), width=3)

# Right ear
rounded_rect(erd, [CX + 230, EAR_Y - EAR_H//2,
                    CX + 230 + EAR_W, EAR_Y + EAR_H//2],
             radius=18, fill=(*GOLD_DARK, 255))
# Ear highlight
rounded_rect(erd, [CX + 230 + 6, EAR_Y - EAR_H//2 + 6,
                    CX + 230 + EAR_W - 6, EAR_Y - EAR_H//2 + 30],
             radius=10, fill=(*GOLD_LIGHT, 100))
# Ear detail lines
for i in range(3):
    ly = EAR_Y - 15 + i * 18
    erd.line([(CX + 230 + 12, ly), (CX + 230 + EAR_W - 12, ly)],
             fill=(*BRONZE, 180), width=3)

img = Image.alpha_composite(img, ears_layer)

# ── 4. head (main rounded rectangle) ────────────────────────────────────────

HEAD_W = 230   # half-width
HEAD_H = 210   # half-height
HEAD_R = 80    # corner radius

# Head gradient — golden, brighter at top-left
head_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hd = ImageDraw.Draw(head_layer)

# Main head shape
rounded_rect(hd, [CX - HEAD_W, CY - HEAD_H, CX + HEAD_W, CY + HEAD_H],
             radius=HEAD_R, fill=(*GOLD_MID, 255))

# Gradient overlay: top is lighter, bottom is darker
head_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hg_pix = head_grad.load()
for y in range(CY - HEAD_H, CY + HEAD_H + 1):
    t = (y - (CY - HEAD_H)) / (2 * HEAD_H)
    c = lerp_color(GOLD_LIGHT, GOLD_DARK, t)
    for x in range(CX - HEAD_W, CX + HEAD_W + 1):
        hg_pix[x, y] = (*c, 120)

# Mask gradient to head shape
head_mask = Image.new("L", (SIZE, SIZE), 0)
hm_draw = ImageDraw.Draw(head_mask)
rounded_rect(hm_draw, [CX - HEAD_W, CY - HEAD_H, CX + HEAD_W, CY + HEAD_H],
             radius=HEAD_R, fill=255)

head_grad_masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
head_grad_masked.paste(head_grad, mask=head_mask)

img = Image.alpha_composite(img, head_layer)
img = Image.alpha_composite(img, head_grad_masked)

# Head outline (subtle darker border)
head_outline = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ho_draw = ImageDraw.Draw(head_outline)
rounded_rect(ho_draw, [CX - HEAD_W, CY - HEAD_H, CX + HEAD_W, CY + HEAD_H],
             radius=HEAD_R, fill=None, outline=(*GOLD_DEEP, 100), width=4)
img = Image.alpha_composite(img, head_outline)

# ── 5. forehead plate / brow ridge ──────────────────────────────────────────

brow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bd = ImageDraw.Draw(brow)

BROW_Y = CY - 95
rounded_rect(bd, [CX - 185, BROW_Y - 35, CX + 185, BROW_Y + 35],
             radius=25, fill=(*GOLD_DARK, 180))
# Brow highlight strip
rounded_rect(bd, [CX - 170, BROW_Y - 25, CX + 170, BROW_Y - 8],
             radius=12, fill=(*GOLD_LIGHT, 80))

img = Image.alpha_composite(img, brow)

# ── 6. eyes (blue glowing) ──────────────────────────────────────────────────

EYE_Y = CY - 30
EYE_SPREAD = 105
EYE_RX = 55
EYE_RY = 55

# Eye sockets (dark recesses)
eye_sock = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
esd = ImageDraw.Draw(eye_sock)

for side in [-1, 1]:
    ex = CX + side * EYE_SPREAD
    # Dark socket
    esd.ellipse([ex - EYE_RX - 8, EYE_Y - EYE_RY - 8,
                 ex + EYE_RX + 8, EYE_Y + EYE_RY + 8],
                fill=(*DARK_METAL, 220))

img = Image.alpha_composite(img, eye_sock)

# Eye glow (soft blue glow behind eyes)
for side in [-1, 1]:
    ex = CX + side * EYE_SPREAD
    glow_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    gd.ellipse([ex - EYE_RX - 20, EYE_Y - EYE_RY - 20,
                ex + EYE_RX + 20, EYE_Y + EYE_RY + 20],
               fill=(*BLUE_GLOW, 50))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=15))
    img = Image.alpha_composite(img, glow_layer)

# Eyes themselves
eyes_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
eyd = ImageDraw.Draw(eyes_layer)

for side in [-1, 1]:
    ex = CX + side * EYE_SPREAD

    # Main eye (bright blue)
    eyd.ellipse([ex - EYE_RX, EYE_Y - EYE_RY,
                 ex + EYE_RX, EYE_Y + EYE_RY],
                fill=(*BLUE_GLOW, 255))

    # Deeper blue ring at edge
    eyd.ellipse([ex - EYE_RX + 5, EYE_Y - EYE_RY + 5,
                 ex + EYE_RX - 5, EYE_Y + EYE_RY - 5],
                fill=(*BLUE_BRIGHT, 200))

    # Pupil (darker centre)
    PUPIL_R = 22
    eyd.ellipse([ex - PUPIL_R, EYE_Y - PUPIL_R,
                 ex + PUPIL_R, EYE_Y + PUPIL_R],
                fill=(*BLUE_DEEP, 255))

    # Bright highlight (top-left reflection)
    HL_R = 14
    hl_x = ex - 18
    hl_y = EYE_Y - 18
    eyd.ellipse([hl_x - HL_R, hl_y - HL_R, hl_x + HL_R, hl_y + HL_R],
                fill=(255, 255, 255, 220))

    # Small secondary highlight
    hl2_r = 7
    hl2_x = ex + 14
    hl2_y = EYE_Y + 12
    eyd.ellipse([hl2_x - hl2_r, hl2_y - hl2_r, hl2_x + hl2_r, hl2_y + hl2_r],
                fill=(255, 255, 255, 140))

img = Image.alpha_composite(img, eyes_layer)

# ── 7. mouth area (grille / speaker) ─────────────────────────────────────────

mouth = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
md = ImageDraw.Draw(mouth)

MOUTH_Y = CY + 95
MOUTH_W = 100
MOUTH_H = 50

# Mouth plate background
rounded_rect(md, [CX - MOUTH_W, MOUTH_Y - MOUTH_H, CX + MOUTH_W, MOUTH_Y + MOUTH_H],
             radius=25, fill=(*GOLD_DEEP, 220))

# Horizontal grille lines (speaker effect)
for i in range(5):
    ly = MOUTH_Y - 32 + i * 16
    md.line([(CX - MOUTH_W + 20, ly), (CX + MOUTH_W - 20, ly)],
            fill=(*DARK_METAL, 200), width=4)
    # Highlight below each line
    md.line([(CX - MOUTH_W + 20, ly + 3), (CX + MOUTH_W - 20, ly + 3)],
            fill=(*GOLD_MID, 60), width=2)

img = Image.alpha_composite(img, mouth)

# ── 8. cheek vents / details ────────────────────────────────────────────────

details = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
dd = ImageDraw.Draw(details)

# Small decorative circles on cheeks
for side in [-1, 1]:
    cx_dot = CX + side * 175
    cy_dot = CY + 50
    # Outer ring
    dd.ellipse([cx_dot - 20, cy_dot - 20, cx_dot + 20, cy_dot + 20],
               fill=(*GOLD_DEEP, 200))
    # Inner circle
    dd.ellipse([cx_dot - 12, cy_dot - 12, cx_dot + 12, cy_dot + 12],
               fill=(*GOLD_DARK, 255))
    # Screw head highlight
    dd.ellipse([cx_dot - 5, cy_dot - 8, cx_dot + 2, cy_dot - 2],
               fill=(*GOLD_LIGHT, 150))

img = Image.alpha_composite(img, details)

# ── 9. neck / chin area ─────────────────────────────────────────────────────

neck = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
nd = ImageDraw.Draw(neck)

# Simple neck connector
NECK_W = 80
NECK_TOP = CY + HEAD_H - 10
NECK_BOT = CY + HEAD_H + 55

rounded_rect(nd, [CX - NECK_W, NECK_TOP, CX + NECK_W, NECK_BOT],
             radius=15, fill=(*GOLD_DARK, 255))
# Neck segment lines
for i in range(3):
    ny = NECK_TOP + 12 + i * 14
    nd.line([(CX - NECK_W + 10, ny), (CX + NECK_W - 10, ny)],
            fill=(*BRONZE, 150), width=2)

img = Image.alpha_composite(img, neck)

# ── 10. body / torso (upper portion visible) ────────────────────────────────

body = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bod = ImageDraw.Draw(body)

BODY_TOP = NECK_BOT - 5
BODY_BOT = min(CY + HEAD_H + 220, SIZE - 30)
BODY_W = 200

rounded_rect(bod, [CX - BODY_W, BODY_TOP, CX + BODY_W, BODY_BOT],
             radius=40, fill=(*GOLD_MID, 255))

# Body gradient
body_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bg_pix = body_grad.load()
for y in range(BODY_TOP, BODY_BOT + 1):
    t = (y - BODY_TOP) / max(1, BODY_BOT - BODY_TOP)
    c = lerp_color(GOLD_MID, GOLD_DARK, t)
    for x in range(CX - BODY_W, CX + BODY_W + 1):
        bg_pix[x, y] = (*c, 100)

body_mask = Image.new("L", (SIZE, SIZE), 0)
bm_draw = ImageDraw.Draw(body_mask)
rounded_rect(bm_draw, [CX - BODY_W, BODY_TOP, CX + BODY_W, BODY_BOT],
             radius=40, fill=255)
body_grad_masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
body_grad_masked.paste(body_grad, mask=body_mask)

img = Image.alpha_composite(img, body)
img = Image.alpha_composite(img, body_grad_masked)

# Chest plate / power core
CORE_Y = BODY_TOP + 70
CORE_R = 35
# Dark socket
bod2 = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bd2 = ImageDraw.Draw(bod2)
bd2.ellipse([CX - CORE_R - 5, CORE_Y - CORE_R - 5,
             CX + CORE_R + 5, CORE_Y + CORE_R + 5],
            fill=(*DARK_METAL, 200))
# Glowing core
bd2.ellipse([CX - CORE_R, CORE_Y - CORE_R,
             CX + CORE_R, CORE_Y + CORE_R],
            fill=(*BLUE_GLOW, 220))
# Core glow
core_glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(core_glow).ellipse([CX - CORE_R - 15, CORE_Y - CORE_R - 15,
                                    CX + CORE_R + 15, CORE_Y + CORE_R + 15],
                                   fill=(*BLUE_GLOW, 40))
core_glow = core_glow.filter(ImageFilter.GaussianBlur(radius=12))
img = Image.alpha_composite(img, core_glow)
img = Image.alpha_composite(img, bod2)

# Core highlight
core_hl = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
chd = ImageDraw.Draw(core_hl)
chd.ellipse([CX - 12, CORE_Y - 18, CX + 6, CORE_Y - 4],
            fill=(255, 255, 255, 180))
img = Image.alpha_composite(img, core_hl)

# ── 11. shoulder joints ─────────────────────────────────────────────────────

shoulders = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shd = ImageDraw.Draw(shoulders)

for side in [-1, 1]:
    sx = CX + side * (BODY_W - 10)
    sy = BODY_TOP + 35
    SR = 30
    shd.ellipse([sx - SR, sy - SR, sx + SR, sy + SR],
                fill=(*GOLD_DARK, 255))
    shd.ellipse([sx - SR + 6, sy - SR + 6, sx + SR - 6, sy + SR - 6],
                fill=(*GOLD_MID, 255))
    # Highlight
    shd.ellipse([sx - 10, sy - 14, sx + 4, sy - 2],
                fill=(*GOLD_LIGHT, 120))

img = Image.alpha_composite(img, shoulders)

# ── 12. top highlight (specular reflection on head) ──────────────────────────

spec = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
spd = ImageDraw.Draw(spec)
# Large soft highlight on top-left of head
spd.ellipse([CX - 160, CY - HEAD_H + 15, CX - 20, CY - HEAD_H + 100],
            fill=(*CREAM, 60))
spec = spec.filter(ImageFilter.GaussianBlur(radius=25))

# Mask to head only
spec_masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
spec_masked.paste(spec, mask=head_mask)
img = Image.alpha_composite(img, spec_masked)

# ── 13. subtle ambient occlusion (darker edges) ─────────────────────────────

# Darken the bottom edge of the head slightly
ao = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ao_draw = ImageDraw.Draw(ao)
ao_draw.ellipse([CX - HEAD_W + 30, CY + HEAD_H - 80,
                 CX + HEAD_W - 30, CY + HEAD_H + 20],
                fill=(0, 0, 0, 30))
ao = ao.filter(ImageFilter.GaussianBlur(radius=20))
ao_masked = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ao_masked.paste(ao, mask=head_mask)
img = Image.alpha_composite(img, ao_masked)

# ── save ─────────────────────────────────────────────────────────────────────

os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT, "PNG")
print(f"✅  Robot icon saved → {OUT}")
