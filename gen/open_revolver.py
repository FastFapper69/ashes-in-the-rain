"""The open revolver, worn, loaded and empty (user 17. 11.: the open gun was clean while the closed one was rusty, and
the dark discs over the chambers looked bad). art_src 272 (empty) and 273 (loaded): Gemini edits of
art/ui/gunsmith/revolver_open.png, white background, drawn at another size. Keyed (white out) and registered onto the
original open drawing (scale + offset found by matching the silhouettes), written as
art/ui/gunsmith/revolver_open_worn.png and revolver_open_empty.png, 1300x678 like the original.
Run: py gen/open_revolver.py"""
import os
import numpy as np
from PIL import Image
from paths import SRC, REPO

ref = Image.open(os.path.join(REPO, "art/ui/gunsmith/revolver_open.png")).convert("RGBA")
W, H = ref.size
ref_m = np.asarray(ref)[..., 3] > 128


def key_white(im):
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    v = a.min(2)
    alpha = np.clip((250.0 - v) / 22.0, 0.0, 1.0)   # near-white goes, ink and steel stay
    return np.dstack([a, alpha * 255]).astype(np.uint8)


def bbox(m):
    ys, xs = np.nonzero(m)
    return xs.min(), ys.min(), xs.max(), ys.max()


for src, out in [("272.jpg", "revolver_open_empty.png"), ("273.jpg", "revolver_open_worn.png")]:
    rgba = key_white(Image.open(SRC + src))
    m = rgba[..., 3] > 128
    # the gun's silhouette bounds in both: scale and offset to line them up
    rx0, ry0, rx1, ry1 = bbox(ref_m)
    sx0, sy0, sx1, sy1 = bbox(m)
    k = ((rx1 - rx0) / (sx1 - sx0) + (ry1 - ry0) / (sy1 - sy0)) / 2.0
    im = Image.fromarray(rgba, "RGBA")
    im = im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(im, (int(round(rx0 - sx0 * k)), int(round(ry0 - sy0 * k))))
    canvas.save(os.path.join(REPO, "art/ui/gunsmith", out))
    got = np.asarray(canvas)[..., 3] > 128
    iou = (got & ref_m).sum() / max(1, (got | ref_m).sum())
    print(out, "scale", round(k, 4), "overlap", round(float(iou), 3))
