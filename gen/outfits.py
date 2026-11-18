"""Mobster outfits per kind (audit 18. 11.: "shotgunners, tommy gunners and bosses share the same silhouette; you cannot
read the threat at a glance"). The plain suit's parts (art/mobster: torso, uarm, farm, leg) are laid on one green sheet
(--sheet), Gemini redraws the sheet in the same shapes as another outfit (art_src), and this cuts each part back out,
registered onto the original part's frame (its alpha box), so the rig's joints stay where they are:
  art/mobster/<outfit>/{torso,uarm,farm,leg}.png (+ _n normals; the head comes from the kind's face as before)."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MOB = os.path.join(ROOT, "art", "mobster")
W, H = 1790, 1000
BOXES = {"torso": (40, 130), "uarm": (540, 120), "farm": (760, 100), "leg": (1300, 0)}   # top-left of each part on the sheet
OUTFITS = {"torpedo": "312.jpg", "docker": "313.jpg", "patrolman": "314.jpg", "boss": "315.jpg"}
def sheet(out):
    s = Image.new("RGB", (W, H), (0, 255, 0))
    for n, (x, y) in BOXES.items():
        p = Image.open(os.path.join(MOB, n + ".png")).convert("RGBA")
        s.paste(p, (x, y), p)
    s.save(out)
def normal_map(path):   # (= gen/enemies.py normal_map: that script cannot be imported, it rebuilds the heads when run)
    from PIL import ImageFilter
    im = Image.open(path)
    a = np.asarray(im)[..., 3] > 128
    d = ndimage.distance_transform_edt(a)
    h = np.sqrt(np.clip(d / 28.0, 0, 1)) * 28.0
    lum = np.asarray(im.convert("L").filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255.0
    h = ndimage.gaussian_filter(h, 2.0) + lum * 6.0
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h) * 1.2])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    Image.fromarray(((n + 1) * 127.5).clip(0, 255).astype(np.uint8)).save(path.replace(".png", "_n.png"))


def cut(name, f):
    a = np.asarray(Image.open(SRC + f).convert("RGB").resize((W, H), Image.LANCZOS)).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > 140) & (g > r + 50) & (g > b + 50)
    a[..., 1] = np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2]) + 14)
    alpha = ndimage.gaussian_filter((~green).astype(float), 0.6)
    lab, n = ndimage.label(ndimage.binary_opening(~green, iterations=2))
    os.makedirs(os.path.join(MOB, name), exist_ok=True)
    for part, (x, y) in BOXES.items():
        orig = Image.open(os.path.join(MOB, part + ".png")).convert("RGBA")
        ow, oh = orig.size
        # the component(s) under the part's own box on the sheet
        reg = np.zeros_like(green); reg[max(0, y - 40):y + oh + 40, max(0, x - 40):x + ow + 40] = True
        ids = [i for i in np.unique(lab[reg & (lab > 0)]) if ((lab == i) & reg).sum() > 0.5 * (lab == i).sum()]
        m = np.isin(lab, ids)
        ys, xs = np.where(m)
        crop = np.dstack([a, np.where(m, alpha, 0) * 255]).astype(np.uint8)[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        oa = np.asarray(orig)[..., 3] > 20
        oys, oxs = np.where(oa)
        bw, bh = oxs.max() - oxs.min() + 1, oys.max() - oys.min() + 1
        piece = Image.fromarray(crop).resize((bw, bh), Image.LANCZOS)   # onto the original's alpha box exactly
        outp = Image.new("RGBA", (ow, oh), (0, 0, 0, 0))
        outp.paste(piece, (oxs.min(), oys.min()))
        path = os.path.join(MOB, name, part + ".png")
        outp.save(path)
        normal_map(path)
    print(name, "parts cut")
if __name__ == "__main__":
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1])
    else:
        for k, f in OUTFITS.items():
            if os.path.exists(SRC + f) and (len(sys.argv) < 2 or k in sys.argv[1:]):
                cut(k, f)
