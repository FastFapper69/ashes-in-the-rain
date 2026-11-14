# Finds the lights in each cutscene panel (art/cut/NN.jpg) so the player can make them live: red neon
# that buzzes and stutters, warm lamps that breathe, fire that flickers. Writes art/cut/lights.json:
# {panel: [[x, y, radius, kind], ...]} with x, y, radius as fractions of the panel's width/height.
import json, glob, os
import numpy as np
from PIL import Image
from scipy import ndimage

OUT = '/home/claude/repo/art/cut/'
FIRE = {70, 77}   # panels where the warm light is flame
res = {}
for path in sorted(glob.glob(OUT + '*.jpg')):
    n = int(os.path.basename(path)[:-4])
    im = Image.open(path).convert('RGB')
    w0, h0 = im.size
    im = im.resize((w0 // 4, h0 // 4))
    a = np.asarray(im).astype(float) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(2), a.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    red = (r > 0.45) & (sat > 0.55) & (g < r * 0.55) & (b < r * 0.55)
    warm = (r > 0.82) & (g > 0.62) & (b < g * 0.85) & (sat > 0.25)
    found = []
    for mask, kind in ((red, 'neon'), (warm, 'fire' if n in FIRE else 'lamp')):
        lab, k = ndimage.label(ndimage.binary_dilation(mask, iterations=2))
        if k == 0:
            continue
        sizes = ndimage.sum(mask, lab, range(1, k + 1))
        for i in np.argsort(sizes)[::-1][:5]:
            if sizes[i] < 25:
                break
            ys, xs = np.where(lab == i + 1)
            cx, cy = xs.mean() / im.width, ys.mean() / im.height
            rad = max(np.ptp(xs) / im.width, np.ptp(ys) / im.height) * 0.5 + 0.02
            found.append([round(cx, 3), round(cy, 3), round(min(rad, 0.25), 3), kind])
    res[str(n)] = found
    print(n, found)
json.dump(res, open(OUT + 'lights.json', 'w'))
