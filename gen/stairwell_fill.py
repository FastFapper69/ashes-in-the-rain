"""The stairs openings in the tenement's hallway pieces (user 19. 11.: "the black spot is crap and ugly"): Gemini redrew
each piece with a dimly lit stairwell inside the doorway (art_src 327 for tenement_stairs_a, 328 for tenement_stairs_b).
Only the inside of the doorway is taken from it: the new picture is registered onto the piece (scale and shift, on the
wall left of the doorway), the doorway's frame found in the piece, and its inside copied in - the frame, the walls
and the floor strip stay the piece's own pixels.  Run: python gen/stairwell_fill.py <piece> <art_src n> [x0 x1]"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
name, n = sys.argv[1], int(sys.argv[2])
path = os.path.join(ROOT, "art", "section", name + ".png")
old = Image.open(path).convert("RGB")
W, H = old.size
raw = Image.open(SRC + "%d.jpg" % n).convert("RGB")
A = np.asarray(old.convert("L")).astype(float)
# the doorway: the big black area inside the hallway, between the ceiling and the floor
dark = A < 18
dark[:240] = False
dark[1090:] = False
if len(sys.argv) > 4:   # where to look for it
    xa, xb = int(sys.argv[3]), int(sys.argv[4])
    dark[:, :xa] = False
    dark[:, xb:] = False
lab, k = ndimage.label(dark)
sizes = ndimage.sum(dark, lab, range(1, k + 1))
big = int(np.argmax(sizes)) + 1
ys, xs = np.where(lab == big)
top, left = ys.min(), xs.min()
# its right edge: along a row a little under its top, past the black, where the frame/wallpaper starts again
row = top + 40
x = xs[ys == row].max() if (ys == row).any() else xs.max()
while x < W - 1 and not (A[row, x] > 110 and A[row, x + 1] > 110):
    x += 1
right = x
print(name, "doorway", left, top, right)
# register the new picture on the wall left of the doorway (and above it)
f = 4
Al = np.asarray(old.convert("L").resize((W // f, H // f))).astype(float)
best = None
for s in np.arange(0.95, 1.051, 0.005):
    bw, bh = int(W * s), int(raw.height * W * s / raw.width)
    B = np.asarray(raw.convert("L").resize((bw // f, bh // f))).astype(float)
    for dy in range(-14, 15):
        for dx in range(-14, 15):
            ys_ = np.arange(220 // f, min(H - 40, top + 600) // f); xs_ = np.arange(max(60, left - 900) // f, max(left - 30, 200) // f)
            by, bx = ys_ - dy, xs_ - dx
            if by.min() < 0 or bx.min() < 0 or by.max() >= B.shape[0] or bx.max() >= B.shape[1]:
                continue
            e = np.abs(Al[np.ix_(ys_, xs_)] - B[np.ix_(by, bx)]).mean()
            if best is None or e < best[0]:
                best = (e, s, dx, dy)
e, s, dx, dy = best
print("registered: err %.1f scale %.3f shift %d %d" % (e, s, dx * f, dy * f))
nb = raw.resize((int(W * s), int(raw.height * W * s / raw.width)), Image.LANCZOS)
reg = Image.new("RGB", (W, H)); reg.paste(nb, (dx * f, dy * f))
o = np.asarray(old).copy(); r = np.asarray(reg)
m = 6   # (inside the frame's ink)
o[top + m:1096, left + m:right - m] = r[top + m:1096, left + m:right - m]
Image.fromarray(o).save(path)
