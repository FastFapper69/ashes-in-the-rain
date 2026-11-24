"""Cut a character's parts sheet (Gemini, flat green) into separate RGBA pieces (postavy/plan-novych-postav.md step 2).
usage: py -3 gen/char_cut.py <art_src number> <out dir>   -> out/raw_<k>.png, biggest first, and their boxes on the sheet"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC
def key(im):
    a = np.asarray(im.convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = (g > 110) & (g > r + 45) & (g > b + 45)
    a[..., 1] = np.minimum(g, np.maximum(r, b) + 12)   # the green fringe off the edges
    return a, ~green
def pieces(n):
    a, solid = key(Image.open(SRC + "%03d.jpg" % n))
    solid = ndimage.binary_opening(solid, iterations=2)
    lab, k = ndimage.label(solid)
    out = []
    for i in range(1, k + 1):
        m = lab == i
        if m.sum() < 4000:
            continue
        ys, xs = np.where(m)
        box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        al = ndimage.gaussian_filter(m.astype(float), 0.7)[box[1]:box[3], box[0]:box[2]]
        rgba = np.dstack([a[box[1]:box[3], box[0]:box[2]], al * 255]).clip(0, 255).astype(np.uint8)
        out.append((m.sum(), box, Image.fromarray(rgba), m[box[1]:box[3], box[0]:box[2]]))
    return sorted(out, key=lambda p: -p[0])
if __name__ == "__main__":
    os.makedirs(sys.argv[2], exist_ok=True)
    for k, (area, box, im, m) in enumerate(pieces(int(sys.argv[1]))):
        im.save(os.path.join(sys.argv[2], "raw_%d.png" % k))
        print(k, area, box, im.size)
