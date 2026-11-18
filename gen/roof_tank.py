"""TENEMENTS' rooftop hazard (QUEUE §15 H, chapter I audit 18. 11.: "rooftop enemies behave like street thugs"): the water
tower painted on roof_a (art_src 107) - its TANK cut into its own layer (the steel legs stay painted, they survive),
the wall under it from Gemini's same roof without the tower (art_src 308, only the tank's area, feathered);
art_src 309: Gemini's six frames of the tank bursting (on green) -> art/props/roof_tank_anim.png, registered on the tank.
  art/street/roof_a.png       (the roof with the tank area as sky - process_roofs.py's output edited here)
  art/props/roof_tank.png     the tank as painted
Run after gen/process_roofs.py."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
X0, X1, Y0, Y1 = 950, 1270, 135, 525   # the tank's box on roof_a (px)
a = np.asarray(Image.open(SRC + "107.png").convert("RGB")).astype(float)
reg = a[Y0:Y1, X0:X1]
m = (reg[..., 0] - reg[..., 2] > -2) | (reg.mean(axis=2) < 34)
m = ndimage.binary_fill_holes(ndimage.binary_closing(ndimage.binary_opening(m, iterations=1), iterations=4))
yy, xx = np.mgrid[:m.shape[0], :m.shape[1]]
m &= (xx >= 18) & (yy <= 352)          # (not the downpipe at its side, not the platform under it)
lab, n = ndimage.label(m)
m = lab == (np.argmax(ndimage.sum(m, lab, range(1, n + 1))) + 1)
al = ndimage.gaussian_filter(m.astype(float), 0.7)
Image.fromarray(np.dstack([reg, al * 255]).astype(np.uint8)).save(os.path.join(ROOT, "art", "props", "roof_tank.png"))
if "--ref" in sys.argv:
    g = Image.new("RGB", (X1 - X0, Y1 - Y0), (0, 255, 0)); t = Image.open(os.path.join(ROOT, "art", "props", "roof_tank.png"))
    g.paste(t, (0, 0), t); g.save(sys.argv[sys.argv.index("--ref") + 1])
# the roof drawing: the tank's pixels replaced by Gemini's sky behind it (308, aligned 1 px)
b = np.asarray(Image.open(SRC + "308.jpg").convert("RGB").resize((3168, 1344), Image.LANCZOS)).astype(float)
b = np.roll(b, -1, axis=1)
roof = np.asarray(Image.open(os.path.join(ROOT, "art", "street", "roof_a.png"))).astype(float)
w = np.zeros(roof.shape[:2]); w[Y0:Y1, X0:X1] = ndimage.gaussian_filter(ndimage.binary_dilation(m, iterations=6).astype(float), 3)
roof[..., :3] = roof[..., :3] * (1 - w[..., None]) + b * w[..., None]
roof[..., 3] = np.maximum(roof[..., 3], w * 0)   # (the sky behind stays the game's: process_roofs keyed it)
sky = (b[..., 2] > b[..., 0] + 12) & (b.max(axis=2) < 175)
roof[..., 3] = np.where((w > 0.5) & sky, 0, roof[..., 3])
Image.fromarray(roof.astype(np.uint8)).save(os.path.join(ROOT, "art", "street", "roof_a.png"))
print("tank", m.shape, round(float(m.mean()), 3))

# ---- the bursting animation (art_src 309: Gemini drew 7 frames in an uneven grid; frames 1,2,3,5,6,7 used) ----
s = np.asarray(Image.open(SRC + "309.jpg").convert("RGB")).astype(float)
r, g, bb = s[..., 0], s[..., 1], s[..., 2]
green = (g > 150) & (g > r + 60) & (g > bb + 60)
alpha = ndimage.gaussian_filter((~green).astype(float), 0.6)
fg = ndimage.binary_opening(~green, iterations=1)
s[..., 1] = np.minimum(s[..., 1], np.maximum(s[..., 0], s[..., 2]) + 12)   # (green spill off the edges)
TIPS = [(287, 6), (1006, 10), (1722, 8), (2427, 12), (364, 780), (1166, 780), (2318, 780)]   # cone tips, measured
RIGHT = [228, 230, 232, 224, 217, 221, 213]                                                 # tip -> body's right edge
USE = [0, 1, 2, 4, 5, 6]
lab, n = ndimage.label(ndimage.binary_dilation(fg, iterations=2))
cents = ndimage.center_of_mass(fg, lab, range(1, n + 1))
owner = {}
for i, (cy, cx) in enumerate(cents):
    row = [k for k, t in enumerate(TIPS) if (t[1] < 700) == (cy < 760)]
    owner[i + 1] = min(row, key=lambda k: abs(TIPS[k][0] - cx))
CW, CH, TX = 1100, 780, 380   # a cell, and where the tip sits in it
cells = []
for k in USE:
    mine = np.isin(lab, [c for c, o in owner.items() if o == k]) & fg
    rgba = np.dstack([s, np.where(mine, alpha, 0) * 255]).astype(np.uint8)
    tx, ty = TIPS[k]
    sc = 228.0 / RIGHT[k]
    box = (tx - int(TX / sc), ty, tx + int((CW - TX) / sc), ty + int(CH / sc))
    piece = Image.fromarray(rgba).crop(box).resize((CW, CH), Image.LANCZOS)
    cells.append(piece)
strip = Image.new("RGBA", (CW * 6, CH), (0, 0, 0, 0))
for i, c in enumerate(cells):
    strip.paste(c, (i * CW, 0))
strip = strip.resize((CW * 6 // 2, CH // 2), Image.LANCZOS)   # (no more pixels than the game shows)
strip.save(os.path.join(ROOT, "art", "props", "roof_tank_anim.png"))
t = np.asarray(Image.open(os.path.join(ROOT, "art", "props", "roof_tank.png")))[..., 3] > 128
ys, xs = np.where(t)
tip_x = xs[ys == ys.min()].mean()
print("cut tank: tip", tip_x, ys.min(), "body right", xs.max() - tip_x, "-> anim cell (half size)", CW // 2, CH // 2, "tip at", TX // 2)
