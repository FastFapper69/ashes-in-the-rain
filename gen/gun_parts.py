"""The gunsmith's side guns in parts, worn and new (2026-11-16): art_src 201/202 (revolver new/worn) and
203/204 (Beretta new/worn), the worn one an edit of the same drawing so the two line up. Every pixel of
the gun belongs to one part (one map for both states), so the pieces tile exactly: the gunsmith shows
each part worn until its upgrade is fitted, then the new one.
Writes art/ui/gunsmith/parts/<gun>_<part>_<new|worn>.png and prints the offsets for menu.gd SMITH_PIECES."""
import numpy as np
from PIL import Image, ImageDraw
import os, json
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1300 / 2752   # the drawings are shown at the size of the old gunsmith art (1300 wide)


def key(a):
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    green = (g - np.maximum(r, b)).clip(0, 255)
    alpha = (255 - (green - 40).clip(0, 120) * 255 // 120).astype(np.uint8)
    rgb = a[..., :3].copy()
    spill = g > np.maximum(r, b)   # take the green out of the edge pixels
    rgb[..., 1] = np.where(spill, np.maximum(r, b), g).astype(np.uint8)
    return rgb, alpha


def poly(size, pts):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).polygon([tuple(p) for p in pts], fill=255)
    return np.asarray(m) > 0


GUNS = {
    "revolver": {"new": 201, "worn": 202, "parts": ["frame", "cylinder", "barrel", "grip"]},
    "beretta": {"new": 203, "worn": 204, "parts": ["frame", "slide", "grip", "plate"]},
}


def labels(gun, new, worn, alpha):
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w]
    lab = np.zeros((h, w), np.uint8)   # 0 = frame
    if gun == "revolver":
        lab[(xx >= 1040) & (xx <= 1560) & (yy >= 185) & (yy <= 600)] = 1
        lab[xx > 1730] = 2
        g = poly((w, h), [[180, 1400], [240, 1120], [340, 860], [480, 660], [660, 640], [700, 800], [660, 940], [620, 1120], [640, 1420]])
        lab[g] = 3
    else:
        s = poly((w, h), [[400, 60], [2520, 60], [2520, 410], [2220, 410], [2200, 390], [1040, 400], [1000, 430], [460, 430]])
        lab[s] = 1
        r, gg, b = [new[..., k].astype(int) for k in range(3)]
        wood = (r > b + 25) & (r > gg) & (xx < 1060) & (yy > 400) & (yy < 1310)
        lab[wood] = 2
        lab[yy > 1310] = 3
    return lab


out = {}
for gun, d in GUNS.items():
    new = np.asarray(Image.open(os.path.join(ROOT, 'art_src/%d_%s_new.png' % (d["new"], gun[:3]))).convert('RGB'))
    worn = np.asarray(Image.open(os.path.join(ROOT, 'art_src/%d_%s_worn.png' % (d["worn"], gun[:3]))).convert('RGB'))
    rn, an = key(new)
    rw, aw = key(worn)
    lab = labels(gun, new, worn, np.maximum(an, aw))
    for k, part in enumerate(d["parts"]):
        m = lab == k
        ys, xs = np.nonzero(m & (np.maximum(an, aw) > 8))   # one box for both states: they swap in place
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        for state, rgb, a in (("new", rn, an), ("worn", rw, aw)):
            alpha = np.where(m, a, 0).astype(np.uint8)
            im = Image.fromarray(np.dstack([rgb, alpha])[y0:y1, x0:x1], 'RGBA')
            im = im.resize((max(4, round(im.width * S / 4) * 4), max(4, round(im.height * S / 4) * 4)), Image.LANCZOS)
            im.save(os.path.join(ROOT, 'art/ui/gunsmith/parts/%s_%s_%s.png' % (gun, part, state)))
            if state == "new":
                out.setdefault(gun, {})[part] = [round(x0 * S, 1), round(y0 * S, 1)]
    full = Image.fromarray(np.dstack([rn, an]), 'RGBA').resize((1300, round(1536 * S)), Image.LANCZOS)
    print(gun, "drawing", full.size)
print(json.dumps(out))
