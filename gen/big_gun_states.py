"""The big guns' upgrade states for the gunsmith (2026-11-21, QUEUE §2, rule 28): every view of the shotgun
and the tommy gun shows its parts as they are now. Gemini redrew one part on a copy of the gun on green
(art_src 329 shotgun extended tube, 330 tommy Cutts compensator, 331 tommy drum); each redraw is registered
onto the original drawing (scale + shift, matched on the part of the gun that did not change) and ONLY the
changed part's region is copied in, so the rest of the gun stays pixel-identical between states.

  py -3 gen/big_gun_states.py [--src <art_src dir>]

Writes art/ui/gunsmith/<gun>_<state>.png:
  shotgun_short / shotgun_long, shotgun_open_short / shotgun_open_long
  tommy_stick_plain / tommy_stick_comp / tommy_drum_plain / tommy_drum_comp
and _shots/big_gun_states.png (all of them stacked, to look at)."""
import os, sys
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(ROOT), "Ashes in the Rain", "art_src")
if "--src" in sys.argv:
    SRC = sys.argv[sys.argv.index("--src") + 1]
GS = os.path.join(ROOT, "art", "ui", "gunsmith")


def key(path):
    """Gemini's flat green out: RGBA with the green spill taken off the edges."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g - np.maximum(r, b)).clip(0, 255)
    alpha = (255 - (green - 40).clip(0, 120) * 255 // 120).astype(np.uint8)
    rgb = a.copy()
    rgb[..., 1] = np.where(g > np.maximum(r, b), np.maximum(r, b), g)
    return np.dstack([rgb.astype(np.uint8), alpha])


def place(img, size, s, dx, dy):
    """img scaled by s and shifted by (dx, dy) onto a transparent canvas of size."""
    h, w = img.shape[:2]
    im = Image.fromarray(img, "RGBA").resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.paste(im, (int(round(dx)), int(round(dy))))
    return np.asarray(out)


def register(orig, red, anchor):
    """Best scale and shift of red onto orig, scored by alpha agreement inside the anchor box (x0, y0, x1, y1)."""
    H, W = orig.shape[:2]
    oa = orig[..., 3].astype(float) / 255.0
    x0, y0, x1, y1 = anchor
    s0 = W / red.shape[1]
    best = None
    for s in np.linspace(s0 * 0.94, s0 * 1.06, 25):
        sm = np.asarray(Image.fromarray(red[..., 3]).resize((round(red.shape[1] * s), round(red.shape[0] * s)))).astype(float) / 255.0
        for dy in range(-40, 41, 4):
            for dx in range(-60, 61, 4):
                cand = np.zeros((H, W))
                ys, xs = max(0, dy), max(0, dx)
                ye, xe = min(H, dy + sm.shape[0]), min(W, dx + sm.shape[1])
                if ye <= ys or xe <= xs:
                    continue
                cand[ys:ye, xs:xe] = sm[ys - dy:ye - dy, xs - dx:xe - dx]
                err = np.abs(cand[y0:y1, x0:x1] - oa[y0:y1, x0:x1]).mean()
                if best is None or err < best[0]:
                    best = (err, s, dx, dy)
    # refine by single pixels round the best
    err, s, dx, dy = best
    for s2 in np.linspace(s * 0.995, s * 1.005, 5):
        sm = np.asarray(Image.fromarray(red[..., 3]).resize((round(red.shape[1] * s2), round(red.shape[0] * s2)))).astype(float) / 255.0
        for ddy in range(-4, 5):
            for ddx in range(-4, 5):
                ny, nx = dy + ddy, dx + ddx
                cand = np.zeros((H, W))
                ys, xs = max(0, ny), max(0, nx)
                ye, xe = min(H, ny + sm.shape[0]), min(W, nx + sm.shape[1])
                cand[ys:ye, xs:xe] = sm[ys - ny:ye - ny, xs - nx:xe - nx]
                e = np.abs(cand[y0:y1, x0:x1] - oa[y0:y1, x0:x1]).mean()
                if e < best[0]:
                    best = (e, s2, nx, ny)
    return best


def splice(base, part, box, feather=10):
    """base with part's pixels inside box (x0, y0, x1, y1), the left/right edges of the box feathered."""
    out = base.astype(float).copy()
    H, W = base.shape[:2]
    x0, y0, x1, y1 = box
    m = np.zeros((H, W))
    m[y0:y1, x0:x1] = 1.0
    if feather:
        for k in range(feather):
            f = (k + 1) / (feather + 1)
            if x0 + k < W:
                m[y0:y1, x0 + k] = f
            if x1 - 1 - k >= 0 and x1 < W:
                m[y0:y1, x1 - 1 - k] = f
    m = m[..., None]
    # premultiplied mix, so the cut-out's edges do not darken
    pa, ba = part[..., 3:4] / 255.0, out[..., 3:4] / 255.0
    a = pa * m + ba * (1 - m)
    rgb = (part[..., :3] * pa * m + out[..., :3] * ba * (1 - m)) / np.maximum(a, 1e-6)
    return np.dstack([rgb, a * 255.0]).clip(0, 255).astype(np.uint8)


def load(name):
    return np.asarray(Image.open(os.path.join(GS, name + ".png")).convert("RGBA"))


def fit(orig, art_no, anchor, label):
    red = key(os.path.join(SRC, "%d.jpg" % art_no))
    err, s, dx, dy = register(orig, red, anchor)
    print("%s: art_src %d scale %.4f shift %d,%d  error %.4f" % (label, art_no, s, dx, dy, err))
    return place(red, (orig.shape[1], orig.shape[0]), s, dx, dy)


def save(a, name):
    Image.fromarray(a, "RGBA").save(os.path.join(GS, name + ".png"))
    return a


outs = []
# --- the shotgun: the tube from the forend's front end to the muzzle (both drawings, closed and open)
# BOXES (px of the 1600 x 366 drawings) are the region taken from the redraw; ANCHORS the unchanged barrel
# (the open drawing's forend ends further forward: its cut is past both forend ends, on the plain tube,
# and the redraw is matched on the tube there so the tube runs on without a step)
SG = {"shotgun": [(900, 20, 1330, 100), (1318, 78, 1600, 220)],
      "shotgun_open": [(1050, 20, 1345, 170), (1345, 80, 1600, 220)]}
for base_name, (anchor, box) in SG.items():
    orig = load(base_name)
    red = fit(orig, 329, anchor, base_name)
    outs.append(save(orig.copy(), base_name + "_short"))
    outs.append(save(splice(orig, red, box), base_name + "_long"))
TOMMY_PAD = 110
# --- the tommy gun: the muzzle (compensator) and the magazine well (stick or drum), on tommy.png's frame
if os.path.exists(os.path.join(SRC, "330.jpg")) and os.path.exists(os.path.join(SRC, "331.jpg")):
    orig = load("tommy")
    orig = np.vstack([orig, np.zeros((TOMMY_PAD, orig.shape[1], 4), np.uint8)])   # (room below for the drum)
    comp = fit(orig, 330, (420, 30, 1300, 140), "tommy comp")
    drum = fit(orig, 331, (420, 30, 1300, 140), "tommy drum")
    MUZZLE = (1330, 20, 1600, 130)
    MAG = (800, 90, 1010, 413 + TOMMY_PAD)
    plain = orig.copy()
    # (the drum's region: the stick magazine is taken out of the base first, then the drum goes in)
    def with_drum(a):
        clear = a.copy()
        x0, y0, x1, y1 = MAG
        clear[y0:y1, x0:x1] = drum[y0:y1, x0:x1]
        return clear
    outs.append(save(plain, "tommy_stick_plain"))
    outs.append(save(splice(plain, comp, MUZZLE), "tommy_stick_comp"))
    outs.append(save(with_drum(plain), "tommy_drum_plain"))
    outs.append(save(splice(with_drum(plain), comp, MUZZLE), "tommy_drum_comp"))

# the contact sheet
W = max(o.shape[1] for o in outs)
sheet = Image.new("RGB", (W, sum(o.shape[0] + 10 for o in outs)), (235, 228, 214))
y = 0
for o in outs:
    sheet.paste(Image.fromarray(o, "RGBA"), (0, y), Image.fromarray(o, "RGBA"))
    y += o.shape[0] + 10
os.makedirs(os.path.join(ROOT, "_shots"), exist_ok=True)
sheet.save(os.path.join(ROOT, "_shots", "big_gun_states.png"))
print("sheet _shots/big_gun_states.png")
