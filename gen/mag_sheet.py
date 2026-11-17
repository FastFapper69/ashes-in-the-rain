"""The Beretta's magazines for the gunsmith (art_src 274 on flat green: a full magazine, an extended one, a 9mm round),
keyed and cut into art/ui/gunsmith/mag.png, mag_long.png, round9.png.  Run: py gen/mag_sheet.py"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC, REPO

a = np.asarray(Image.open(SRC + "274.jpg").convert("RGB")).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
green = np.clip((g - np.maximum(r, b) - 40.0) / 50.0, 0.0, 1.0)
alpha = 1.0 - green
spill = (g > np.maximum(r, b)) & (alpha > 0)
a[..., 1] = np.where(spill, np.maximum(r, b), g)
lab, n = ndimage.label(ndimage.binary_opening(alpha > 0.5, iterations=2))
objs = sorted([o for o in ndimage.find_objects(lab) if (o[0].stop - o[0].start) * (o[1].stop - o[1].start) > 4000], key=lambda o: o[1].start)
for name, o in zip(["mag", "mag_long", "round9"], objs):
    y0, y1, x0, x1 = max(0, o[0].start - 4), o[0].stop + 4, max(0, o[1].start - 4), o[1].stop + 4
    keep = (lab[y0:y1, x0:x1] == lab[o[0].start:o[0].stop, o[1].start:o[1].stop].max()) | (alpha[y0:y1, x0:x1] < 0.5)
    out = np.dstack([a[y0:y1, x0:x1], alpha[y0:y1, x0:x1] * 255]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(REPO, "art", "ui", "gunsmith", name + ".png"))
    print(name, x1 - x0, y1 - y0)
