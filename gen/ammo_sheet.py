"""The gunsmith's rounds (art_src 271: on flat green - a speedloader with six .38s, a cartridge, a fired case), keyed and
cut apart into art/ui/gunsmith/speedloader.png, round.png, case.png.  Run: py gen/ammo_sheet.py"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC, REPO

a = np.asarray(Image.open(SRC + "271.jpg").convert("RGB")).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
green = np.clip((g - np.maximum(r, b) - 40.0) / 50.0, 0.0, 1.0)
alpha = 1.0 - green
spill = (g > np.maximum(r, b)) & (alpha > 0)
a[..., 1] = np.where(spill, np.maximum(r, b) * 0.6 + g * 0.4 * (1 - green), g)   # (no green rim)
lab, n = ndimage.label(ndimage.binary_opening(alpha > 0.5, iterations=2))
objs = sorted([o for o in ndimage.find_objects(lab) if (o[0].stop - o[0].start) * (o[1].stop - o[1].start) > 4000], key=lambda o: o[1].start)
names = ["speedloader", "round", "case"]
for name, o in zip(names, objs):
    y0, y1, x0, x1 = o[0].start - 4, o[0].stop + 4, o[1].start - 4, o[1].stop + 4
    out = np.dstack([a[y0:y1, x0:x1], alpha[y0:y1, x0:x1] * 255]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(REPO, "art", "ui", "gunsmith", name + ".png"))
    print(name, x1 - x0, y1 - y0)
