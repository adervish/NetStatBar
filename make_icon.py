#!/usr/bin/env python3
"""Generate the NetStatBar app icon — WiFi Pulse concept.
1024×1024 PNG: deep blue gradient bg, white WiFi arcs, white EKG heartbeat line.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
CORNER = 220          # rounded rect corner radius (App Store style)
CX, CY = 512, 590    # WiFi arc origin (lower-center)
RADII = [155, 285, 415]
ARC_HALF_DEG = 62    # half-sweep of each arc in degrees
LINE_WIDTH = 52       # arc stroke width
DOT_R = 38           # center dot radius

# ── 1. Background ────────────────────────────────────────────────────────────
bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
grad = Image.new("RGBA", (SIZE, SIZE))
draw_grad = ImageDraw.Draw(grad)
# vertical gradient: top = deep indigo, bottom = royal blue
for y in range(SIZE):
    t = y / SIZE
    r = int(18  + t * (25  - 18))
    g = int(32  + t * (75  - 32))
    b = int(120 + t * (160 - 120))
    draw_grad.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

# rounded rect mask
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE-1, SIZE-1], radius=CORNER, fill=255)
bg.paste(grad, mask=mask)

# subtle inner glow — lighter circle in center
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([SIZE//2-340, SIZE//2-340, SIZE//2+340, SIZE//2+340],
                              fill=(80, 120, 255, 40))
glow = glow.filter(ImageFilter.GaussianBlur(120))
bg = Image.alpha_composite(bg, glow)

# ── 2. WiFi arcs ─────────────────────────────────────────────────────────────
# Draw each arc as a thick stroke by layering concentric circles clipped to
# an annulus, then masked to the sweep angle.
def draw_arc(img, cx, cy, r, half_deg, lw, color):
    """Draw a single arc stroke at (cx,cy) with radius r."""
    # bounding box of the full circle
    bb = [cx - r, cy - r, cx + r, cy + r]
    tmp = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    # Pillow arc: 0° = 3 o'clock, goes clockwise
    # WiFi arcs open upward: we want 180+half_deg to 360-half_deg
    start_angle = 180 + half_deg
    end_angle   = 360 - half_deg
    d.arc(bb, start=start_angle, end=end_angle, fill=color, width=lw)
    img.alpha_composite(tmp)

wifi_color = (255, 255, 255, 230)
canvas = bg.copy()
for r in RADII:
    draw_arc(canvas, CX, CY, r, ARC_HALF_DEG, LINE_WIDTH, wifi_color)

# center dot
d2 = ImageDraw.Draw(canvas)
d2.ellipse([CX-DOT_R, CY-DOT_R, CX+DOT_R, CY+DOT_R], fill=(255, 255, 255, 230))

# ── 3. EKG heartbeat line ────────────────────────────────────────────────────
# Runs horizontally through ~the second arc, spikes up through the third arc.
EKG_Y   = 430          # baseline Y
SPIKE_X = CX           # spike centered on icon
LW_EKG  = 18

# Key x positions
x0  = 90              # far left
x1  = SPIKE_X - 200  # start of pre-blip
x2  = SPIKE_X - 145  # small blip top
x3  = SPIKE_X - 95   # back to baseline
x4  = SPIKE_X - 25   # drop before spike
x5  = SPIKE_X + 0    # spike peak (top)
x6  = SPIKE_X + 50   # spike valley
x7  = SPIKE_X + 100  # back to baseline
x8  = SPIKE_X + 160  # end of post blip
x9  = SIZE - 90      # far right

SPIKE_TOP = EKG_Y - 290   # how high the main spike goes
BLIP_TOP  = EKG_Y - 55    # small pre-blip
VALLEY    = EKG_Y + 65    # valley after spike

pts = [
    (x0, EKG_Y),
    (x1, EKG_Y),
    (x2, BLIP_TOP),
    (x3, EKG_Y),
    (x4, EKG_Y),
    (x5, SPIKE_TOP),
    (x6, VALLEY),
    (x7, EKG_Y),
    (x8, EKG_Y),
    (x9, EKG_Y),
]

# Glow layer (wider, semi-transparent cyan)
ekg_glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(ekg_glow).line(pts, fill=(140, 220, 255, 80), width=LW_EKG + 28, joint="curve")
ekg_glow = ekg_glow.filter(ImageFilter.GaussianBlur(10))
canvas = Image.alpha_composite(canvas, ekg_glow)

# Main line
ImageDraw.Draw(canvas).line(pts, fill=(255, 255, 255, 245), width=LW_EKG, joint="curve")

# ── 4. Clip to rounded rect and save ─────────────────────────────────────────
final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
final.paste(canvas, mask=mask)
final.save("icon-1024.png")
print("Saved icon-1024.png")
