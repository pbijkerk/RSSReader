#!/usr/bin/env python3
"""Generate a 1024x1024 RSS Reader app icon.
   Renders at 4× (4096×4096) then down-scales with LANCZOS for crisp AA."""

import math
from PIL import Image, ImageDraw, ImageFilter

FINAL = 1024
SCALE = 4
S     = FINAL * SCALE   # 4096

OUT = ("/Users/peterbijkerk/Documents/Claude projecten/RSSReader/"
       "RSSReader/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

# ── Canvas ────────────────────────────────────────────────────────────────────
img  = Image.new("RGBA", (S, S), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# ── 1. Background gradient ────────────────────────────────────────────────────
TOP = (14,  28,  62)
MID = (18,  52, 105)
BOT = ( 8,  16,  36)

for y in range(S):
    t = y / S
    if t < 0.5:
        f = t * 2
        c = tuple(int(TOP[i] + (MID[i]-TOP[i]) * f) for i in range(3))
    else:
        f = (t - 0.5) * 2
        c = tuple(int(MID[i] + (BOT[i]-MID[i]) * f) for i in range(3))
    draw.line([(0, y), (S, y)], fill=(*c, 255))

# iOS rounded-rect mask  (radius ≈ 22.5 % of side)
CORNER = int(S * 0.225)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([(0,0),(S-1,S-1)], radius=CORNER, fill=255)
img.putalpha(mask)

# ── 2. Radial glow ────────────────────────────────────────────────────────────
glow = Image.new("RGBA", (S, S), (0,0,0,0))
gcx, gcy = S // 2, int(S * 0.43)
gd = ImageDraw.Draw(glow)
for r in range(int(S * 0.62), 0, -8):
    a = int(26 * (1 - r / (S * 0.62)))
    gd.ellipse([(gcx-r, gcy-r),(gcx+r, gcy+r)], fill=(80,150,255,a))
glow = glow.filter(ImageFilter.GaussianBlur(radius=S // 26))
img = Image.alpha_composite(img, glow)
draw = ImageDraw.Draw(img)

# ── 3. RSS waves ──────────────────────────────────────────────────────────────
# All params in 4096 space  (÷4 to get 1024 equivalents)
OX,  OY   = 1010, 3310      # origin: lower-left  (252, 828 in 1024)
DOT_R     = 218             # dot radius           (54 in 1024)
LW        = 300             # stroke width         (75 in 1024)
RADII     = [740, 1490, 2240]  # wave radii        (185, 372, 560 in 1024)
A_START   = 237             # arc start angle (degrees, PIL clockwise)
A_END     = 352             # arc end angle

WHITE = (255, 255, 255, 252)

# Dot
draw.ellipse([(OX-DOT_R, OY-DOT_R),(OX+DOT_R, OY+DOT_R)], fill=WHITE)

# Arcs — PIL's arc() natively handles the math; supersampling gives clean AA
for R in RADII:
    bbox = [(OX-R, OY-R), (OX+R, OY+R)]
    draw.arc(bbox, start=A_START, end=A_END, fill=WHITE, width=LW)

# ── 4. Subtle top-edge shimmer ────────────────────────────────────────────────
shine = Image.new("RGBA", (S, S), (0,0,0,0))
sd    = ImageDraw.Draw(shine)
fade  = int(S * 0.38)
for y in range(fade):
    a = int(18 * (1 - y / fade))
    sd.line([(0,y),(S,y)], fill=(255,255,255,a))
img = Image.alpha_composite(img, shine)

# ── 5. Re-apply mask ──────────────────────────────────────────────────────────
img.putalpha(mask)

# ── 6. Downscale 4096 → 1024 with LANCZOS ────────────────────────────────────
final = img.resize((FINAL, FINAL), Image.LANCZOS)

# ── 7. Save as RGB PNG (Xcode doesn't need transparency on app icons) ─────────
bg = Image.new("RGB", (FINAL, FINAL), (0,0,0))
bg.paste(final, mask=final.split()[3])
bg.save(OUT, "PNG")
print(f"Icon saved → {OUT}")
