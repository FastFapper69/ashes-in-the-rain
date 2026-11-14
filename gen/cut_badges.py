"""Cut the six round HUD badges (art_src/90.jpg) into separate transparent PNGs."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
ink = a.mean(axis=2) < 200          # anything that is not the white page
ink = ndimage.binary_fill_holes(ndimage.binary_closing(ink, iterations=6))
lab, n = ndimage.label(ink)
blobs = []
for i, sl in enumerate(ndimage.find_objects(lab)):
    h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
    if h > 200 and w > 200:
        blobs.append((sl[0].start, sl[1].start, h, w, i + 1))
blobs.sort(key=lambda b: (round(b[0] / 300), b[1]))
names = ["dive", "jump", "pause", "minus", "plus", "blank"]
SIZE = 256
for name, (y, x, h, w, idx) in zip(names, blobs):
    cy, cx = y + h / 2, x + w / 2
    r = max(h, w) / 2
    box = (int(cx - r - 4), int(cy - r - 4), int(cx + r + 4), int(cy + r + 4))
    crop = im.crop(box).convert("RGBA")
    m = (lab[box[1]:box[3], box[0]:box[2]] == idx)
    m = ndimage.binary_fill_holes(m)
    alpha = ndimage.gaussian_filter(m.astype(np.float32), 1.2)
    arr = np.asarray(crop).copy()
    arr[..., 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(arr).resize((SIZE, SIZE), Image.LANCZOS).save(f"{out}/badge_{name}.png")
    print(name, box)
