"""Cut the pinned index card and the six blood splatters out of art_src/92.jpg."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
white = (a.min(axis=2) > 236)
ink = ~white
mask = ndimage.binary_closing(ink, iterations=4)
lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=10))
objs = ndimage.find_objects(lab)
items = []
for i, sl in enumerate(objs):
    h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
    if h * w > 20000:
        items.append((sl, i + 1))
items.sort(key=lambda t: (t[0][1].start > 1650, round(t[0][0].start / 500), t[0][1].start))
k = 0
for sl, idx in items:
    y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
    crop = a[y0:y1, x0:x1]
    region = (lab[y0:y1, x0:x1] == idx)
    if x1 - x0 > 1000:   # the card: everything inside its outline is solid paper
        solid = ndimage.binary_fill_holes(mask[y0:y1, x0:x1] & region)
        alpha = ndimage.gaussian_filter(solid.astype(np.float32), 1.0)
        name = "index_card"
    else:           # a splatter: how far from white is how much ink
        dist = 1.0 - crop.min(axis=2) / 255.0
        alpha = np.clip((dist - 0.06) / 0.5, 0, 1) * region
        name = "blood_%d" % k
        k += 1
    rgba = np.dstack([crop, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA")
    if name.startswith("blood"):
        img.thumbnail((360, 360), Image.LANCZOS)
    img.save(f"{out}/{name}.png")
    print(name, (x0, y0, x1, y1))
