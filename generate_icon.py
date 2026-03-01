#!/usr/bin/env python3
"""
PulseDen App Icon Generator — Heart with Pulse 💓
Generates a 1024x1024 PNG and saves it to the Xcode assets folder.
A dark background with a teal heart and white ECG pulse line.
"""

from PIL import Image, ImageDraw, ImageFilter
import math, os

SIZE = 1024
OUT = os.path.join(
    os.path.dirname(__file__),
    "PulseDen/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
)

# ── helpers ──────────────────────────────────────────────────────────────────

def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB tuples."""
    t = max(0, min(1, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(len(c1)))

def draw_ellipse_shadow(img, bbox, color, blur=20):
    """Draw a soft shadow ellipse."""
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(bbox, fill=color)
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=blur))
    return Image.alpha_composite(img, shadow)

def draw_curved_line(draw, points, fill, width):
    """Draw a smooth curved line through a series of points."""
    for i in range(len(points) - 1):
        draw.line([points[i], points[i+1]], fill=fill, width=width)

# ── 1. background (warm mint/teal radial gradient) ──────────────────────────

bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 255))
bg_pix = bg.load()

# Radial gradient: centre bright mint → edges deeper teal
cx, cy = SIZE // 2, SIZE // 2 + 30  # slightly lower centre for warmth
for y in range(SIZE):
    for x in range(SIZE):
        dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        t = min(dist / 580, 1.0)
        # bright warm mint → rich teal
        c = lerp_color((142, 226, 198), (32, 108, 104), t)
        bg_pix[x, y] = (*c, 255)

# ── 2. subtle background glow behind head ────────────────────────────────────

glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([260, 230, 764, 780], fill=(255, 255, 255, 50))
glow = glow.filter(ImageFilter.GaussianBlur(radius=80))
bg = Image.alpha_composite(bg, glow)

# ── 3. head shadow (soft drop shadow below head) ────────────────────────────

bg = draw_ellipse_shadow(bg, [300, 360, 724, 810], (20, 70, 65, 90), blur=35)

# ── 4. head shape (friendly egg/bean) ───────────────────────────────────────

head_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hd = ImageDraw.Draw(head_layer)

# Main head — slightly wider at bottom, like a friendly egg
# Using an ellipse for the main shape
HEAD_CX, HEAD_CY = 512, 530
HEAD_RX, HEAD_RY = 195, 230

# Draw head as filled ellipse
head_bbox = [HEAD_CX - HEAD_RX, HEAD_CY - HEAD_RY, HEAD_CX + HEAD_RX, HEAD_CY + HEAD_RY]
hd.ellipse(head_bbox, fill=(255, 228, 196, 255))  # warm peach

# Subtle head gradient: lighter at top, slightly warmer at bottom
head_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hg_pix = head_grad.load()
for y in range(HEAD_CY - HEAD_RY, HEAD_CY + HEAD_RY + 1):
    t = (y - (HEAD_CY - HEAD_RY)) / (2 * HEAD_RY)
    c = lerp_color((255, 238, 215), (245, 205, 170), t)
    for x in range(SIZE):
        hg_pix[x, y] = (*c, 255)

# Mask the gradient to head shape
head_mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(head_mask).ellipse(head_bbox, fill=255)
head_mask_soft = head_mask.filter(ImageFilter.GaussianBlur(radius=2))

head_with_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
head_with_grad.paste(head_grad, mask=head_mask_soft)

bg = Image.alpha_composite(bg, head_with_grad)

# ── 5. ears (small semicircles on sides) ─────────────────────────────────────

ears = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ed = ImageDraw.Draw(ears)

# Left ear
ear_r = 38
left_ear_cx = HEAD_CX - HEAD_RX + 10
left_ear_cy = HEAD_CY - 20
ed.ellipse([left_ear_cx - ear_r, left_ear_cy - ear_r,
            left_ear_cx + ear_r, left_ear_cy + ear_r],
           fill=(248, 210, 178, 255))

# Right ear
right_ear_cx = HEAD_CX + HEAD_RX - 10
right_ear_cy = HEAD_CY - 20
ed.ellipse([right_ear_cx - ear_r, right_ear_cy - ear_r,
            right_ear_cx + ear_r, right_ear_cy + ear_r],
           fill=(248, 210, 178, 255))

# Put ears behind head by compositing ears first, then head on top
bg = Image.alpha_composite(bg, ears)

# Redraw head on top of ears
bg = Image.alpha_composite(bg, head_with_grad)

# ── 6. face features ────────────────────────────────────────────────────────

face = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fd = ImageDraw.Draw(face)

# Eyes — friendly round dots
EYE_Y = HEAD_CY - 30
EYE_SPREAD = 68
EYE_R = 22

# Left eye
fd.ellipse([HEAD_CX - EYE_SPREAD - EYE_R, EYE_Y - EYE_R,
            HEAD_CX - EYE_SPREAD + EYE_R, EYE_Y + EYE_R],
           fill=(60, 60, 70, 255))

# Right eye
fd.ellipse([HEAD_CX + EYE_SPREAD - EYE_R, EYE_Y - EYE_R,
            HEAD_CX + EYE_SPREAD + EYE_R, EYE_Y + EYE_R],
           fill=(60, 60, 70, 255))

# Eye highlights (little white dots for life)
EH_R = 8
EH_OFF = 7
fd.ellipse([HEAD_CX - EYE_SPREAD - EH_OFF - EH_R + 4, EYE_Y - EH_OFF - EH_R,
            HEAD_CX - EYE_SPREAD - EH_OFF + EH_R + 4, EYE_Y - EH_OFF + EH_R],
           fill=(255, 255, 255, 220))
fd.ellipse([HEAD_CX + EYE_SPREAD - EH_OFF - EH_R + 4, EYE_Y - EH_OFF - EH_R,
            HEAD_CX + EYE_SPREAD - EH_OFF + EH_R + 4, EYE_Y - EH_OFF + EH_R],
           fill=(255, 255, 255, 220))

# Mouth — a happy little smile arc
MOUTH_Y = HEAD_CY + 45
MOUTH_W = 55
fd.arc([HEAD_CX - MOUTH_W, MOUTH_Y - 30, HEAD_CX + MOUTH_W, MOUTH_Y + 30],
       start=10, end=170, fill=(90, 60, 50, 255), width=7)

# Blush cheeks — cute pink circles
CHEEK_Y = HEAD_CY + 15
CHEEK_SPREAD = 105
CHEEK_R = 32

cheeks = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
cd = ImageDraw.Draw(cheeks)
cd.ellipse([HEAD_CX - CHEEK_SPREAD - CHEEK_R, CHEEK_Y - CHEEK_R,
            HEAD_CX - CHEEK_SPREAD + CHEEK_R, CHEEK_Y + CHEEK_R],
           fill=(255, 140, 140, 70))
cd.ellipse([HEAD_CX + CHEEK_SPREAD - CHEEK_R, CHEEK_Y - CHEEK_R,
            HEAD_CX + CHEEK_SPREAD + CHEEK_R, CHEEK_Y + CHEEK_R],
           fill=(255, 140, 140, 70))
cheeks = cheeks.filter(ImageFilter.GaussianBlur(radius=10))

bg = Image.alpha_composite(bg, face)
bg = Image.alpha_composite(bg, cheeks)

# ── 7. sprout! 🌱 ──────────────────────────────────────────────────────────

sprout_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(sprout_layer)

# Stem — slightly curved, growing from top of head
STEM_BASE_X = HEAD_CX + 5
STEM_BASE_Y = HEAD_CY - HEAD_RY + 25
STEM_TOP_X = HEAD_CX + 12
STEM_TOP_Y = HEAD_CY - HEAD_RY - 115

# Draw stem as a series of line segments (gentle curve)
stem_points = []
num_seg = 20
for i in range(num_seg + 1):
    t = i / num_seg
    # Slight S-curve
    x = STEM_BASE_X + (STEM_TOP_X - STEM_BASE_X) * t + math.sin(t * math.pi) * 12
    y = STEM_BASE_Y + (STEM_TOP_Y - STEM_BASE_Y) * t
    stem_points.append((x, y))

# Draw stem with slight taper
for i in range(len(stem_points) - 1):
    t = i / len(stem_points)
    width = int(lerp_color((10,), (5,), t)[0])
    color = lerp_color((60, 160, 80), (90, 195, 95), t)
    sd.line([stem_points[i], stem_points[i+1]], fill=(*color, 255), width=max(width, 4))

# Left leaf — teardrop shape using polygon
LEAF_Y = STEM_TOP_Y + 40
LEAF_X = STEM_BASE_X + math.sin(0.4 * math.pi) * 12 - 5

# Left leaf polygon points
left_leaf = [
    (LEAF_X, LEAF_Y),
    (LEAF_X - 25, LEAF_Y - 40),
    (LEAF_X - 52, LEAF_Y - 65),
    (LEAF_X - 55, LEAF_Y - 55),
    (LEAF_X - 45, LEAF_Y - 35),
    (LEAF_X - 15, LEAF_Y - 8),
    (LEAF_X, LEAF_Y),
]
sd.polygon(left_leaf, fill=(75, 190, 90, 255))

# Right leaf — slightly higher and bigger (main leaf)
LEAF2_Y = STEM_TOP_Y + 15
LEAF2_X = STEM_TOP_X + math.sin(0.7 * math.pi) * 12 + 5

right_leaf = [
    (LEAF2_X, LEAF2_Y),
    (LEAF2_X + 30, LEAF2_Y - 45),
    (LEAF2_X + 60, LEAF2_Y - 75),
    (LEAF2_X + 63, LEAF2_Y - 62),
    (LEAF2_X + 50, LEAF2_Y - 38),
    (LEAF2_X + 18, LEAF2_Y - 5),
    (LEAF2_X, LEAF2_Y),
]
sd.polygon(right_leaf, fill=(85, 200, 100, 255))

# Top tiny leaf / bud at the very tip
BUD_X = STEM_TOP_X + math.sin(math.pi) * 12
BUD_Y = STEM_TOP_Y

tiny_leaf = [
    (BUD_X, BUD_Y + 8),
    (BUD_X - 12, BUD_Y - 18),
    (BUD_X, BUD_Y - 30),
    (BUD_X + 14, BUD_Y - 18),
    (BUD_X, BUD_Y + 8),
]
sd.polygon(tiny_leaf, fill=(100, 210, 115, 255))

# Leaf veins (subtle lighter lines)
vein_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
vd = ImageDraw.Draw(vein_layer)

# Left leaf vein
vd.line([(LEAF_X - 2, LEAF_Y - 5), (LEAF_X - 35, LEAF_Y - 45)],
        fill=(120, 220, 130, 100), width=2)
# Right leaf vein
vd.line([(LEAF2_X + 3, LEAF2_Y - 5), (LEAF2_X + 42, LEAF2_Y - 50)],
        fill=(130, 230, 140, 100), width=2)

sprout_layer = Image.alpha_composite(sprout_layer, vein_layer)

# Soft shadow under sprout base
sprout_shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ssd = ImageDraw.Draw(sprout_shadow)
ssd.ellipse([STEM_BASE_X - 20, STEM_BASE_Y - 6, STEM_BASE_X + 20, STEM_BASE_Y + 6],
            fill=(40, 90, 70, 60))
sprout_shadow = sprout_shadow.filter(ImageFilter.GaussianBlur(radius=6))

bg = Image.alpha_composite(bg, sprout_shadow)
bg = Image.alpha_composite(bg, sprout_layer)

# ── 8. top highlight (soft white glow at top-left for depth) ────────────────

highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
hld = ImageDraw.Draw(highlight)
hld.ellipse([340, 310, 480, 420], fill=(255, 255, 255, 40))
highlight = highlight.filter(ImageFilter.GaussianBlur(radius=30))
bg = Image.alpha_composite(bg, highlight)

# ── save ────────────────────────────────────────────────────────────────────

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bg.save(OUT, "PNG")
print(f"✅  Icon saved → {OUT}")
