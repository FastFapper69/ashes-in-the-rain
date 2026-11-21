"""The rooming house in cross-section (BACK STREETS, 21. 11., QUEUE §18 P14): the tenement kit's pieces redrawn by Gemini
as a different building (art_src 340-345: the same picture, padded to 3168x1344 with black, "keep every position - change
only the surfaces"). Each redraw is registered back onto its tenement piece (scale + shift, matched on the edges of the
whole picture) and cut to the piece's rows, so the stairs openings, doors, the flat's window and the walked boards stay
where the game has them. The flat's burst-window state is the new flat with the window hole taken from tenement_flat_open.

  py -3 gen/rooming_art.py            -> art/section/rooming_*.png and _shots/rooming_check.png (old | new edges)"""
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(ROOT), "Ashes in the Rain", "art_src")
SEC = os.path.join(ROOT, "art", "section")
PAD = 116                     # the black band added above (and below) each 1112-row piece for Gemini
PIECES = {340: "stairs_a", 341: "stairs_b", 342: "entry", 343: "facade_ground", 344: "facade", 345: "flat"}


def edges(img, k=4):
    g = img.convert("L").resize((img.width // k, img.height // k), Image.LANCZOS).filter(ImageFilter.FIND_EDGES)
    a = np.asarray(g).astype(float)
    return (a - a.mean()) / (a.std() + 1e-6)


def register(orig, red):
    """Scale s and shift (dx, dy) (full px) of red onto orig, by edge correlation on a quarter-size grid."""
    eo = edges(orig)
    best = None
    for s in np.linspace(0.985, 1.015, 13):
        rs = red.resize((round(red.width * s), round(red.height * s)), Image.LANCZOS)
        er = edges(rs)
        H, W = eo.shape
        for dy in range(-10, 11):
            for dx in range(-10, 11):
                ys0, xs0 = max(0, dy), max(0, dx)
                ye, xe = min(H, dy + er.shape[0]), min(W, dx + er.shape[1])
                if ye - ys0 < H * 0.8 or xe - xs0 < W * 0.8:
                    continue
                a = eo[ys0:ye, xs0:xe]
                b = er[ys0 - dy:ye - dy, xs0 - dx:xe - dx]
                c = float((a * b).mean())
                if best is None or c > best[0]:
                    best = (c, s, dx * 4, dy * 4)
    c, s, dx, dy = best
    # refine by single pixels at full size round the best (rows and columns only near the strong lines)
    eo_f = edges(orig, 2)
    rs = red.resize((round(red.width * s), round(red.height * s)), Image.LANCZOS)
    er_f = edges(rs, 2)
    H, W = eo_f.shape
    best2 = None
    for ddy in range(-3, 4):
        for ddx in range(-3, 4):
            ny, nx = dy // 2 + ddy, dx // 2 + ddx
            ys0, xs0 = max(0, ny), max(0, nx)
            ye, xe = min(H, ny + er_f.shape[0]), min(W, nx + er_f.shape[1])
            a = eo_f[ys0:ye, xs0:xe]
            b = er_f[ys0 - ny:ye - ny, xs0 - nx:xe - nx]
            cc = float((a * b).mean())
            if best2 is None or cc > best2[0]:
                best2 = (cc, nx * 2, ny * 2)
    return s, best2[1], best2[2], c


def place(red, s, dx, dy, size):
    rs = red.resize((round(red.width * s), round(red.height * s)), Image.LANCZOS)
    out = Image.new("RGB", size, (0, 0, 0))
    out.paste(rs, (dx, dy))
    return out


sheets = []
for num, name in PIECES.items():
    old = Image.open(os.path.join(SEC, "tenement_%s.png" % name)).convert("RGB")
    padded = Image.new("RGB", (3168, 1112 + 2 * PAD), (0, 0, 0))
    padded.paste(old, (0, PAD))
    red = Image.open(os.path.join(SRC, "%d.jpg" % num)).convert("RGB").resize((3168, 1344), Image.LANCZOS)
    s, dx, dy, c = register(padded, red)
    new = place(red, s, dx, dy, padded.size).crop((0, PAD, 3168, PAD + 1112))
    # a margin the shift left uncovered takes the old piece's pixels (only ever a few px at an edge)
    n, o = np.asarray(new).copy(), np.asarray(old)
    hole = n.sum(2) == 0
    n[hole] = o[hole]
    new = Image.fromarray(n)
    new.save(os.path.join(SEC, "rooming_%s.png" % name))
    print("%-14s art_src %d  scale %.4f  shift %d,%d  corr %.3f" % (name, num, s, dx, dy, c))
    sheets.append((name, old, new))

# the flat with its window burst: the new flat, the window hole (where tenement_flat and _flat_open differ) from the open one
fo = np.asarray(Image.open(os.path.join(SEC, "tenement_flat_open.png")).convert("RGB")).astype(int)
fc = np.asarray(Image.open(os.path.join(SEC, "tenement_flat.png")).convert("RGB")).astype(int)
nf = np.asarray(Image.open(os.path.join(SEC, "rooming_flat.png")).convert("RGB")).copy()
diff = np.abs(fo - fc).sum(2) > 40
ys, xs = np.nonzero(diff)
box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
nf[box[1]:box[3], box[0]:box[2]] = fo[box[1]:box[3], box[0]:box[2]]
Image.fromarray(nf).save(os.path.join(SEC, "rooming_flat_open.png"))
print("flat_open: window box", box)

# check sheet: each piece's edges, old in red, new in green (yellow where they agree)
rows = []
for name, old, new in sheets:
    eo, en = edges(old, 4), edges(new, 4)
    rgb = np.zeros(eo.shape + (3,), np.uint8)
    rgb[..., 0] = np.clip(eo * 60, 0, 255)
    rgb[..., 1] = np.clip(en * 60, 0, 255)
    rows.append(Image.fromarray(rgb))
W = rows[0].width
sheet = Image.new("RGB", (W, sum(r.height + 6 for r in rows)))
y = 0
for r in rows:
    sheet.paste(r, (0, y)); y += r.height + 6
os.makedirs(os.path.join(ROOT, "_shots"), exist_ok=True)
sheet.save(os.path.join(ROOT, "_shots", "rooming_check.png"))
print("sheet _shots/rooming_check.png")
