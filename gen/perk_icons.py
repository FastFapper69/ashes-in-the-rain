# Five perk icons (2026-11-16) drawn in one row on flat green (art_src 194), cut apart into
# art/ui/instincts/icon_<name>.png in the size of the other icons (longest side 360).
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC, REPO
a = np.asarray(Image.open(SRC + '194.jpg').convert('RGB')).astype(float)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
alpha = 1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1)
spill = np.maximum(g - np.maximum(r, b), 0)
a[..., 1] -= spill * (1 - alpha * 0.5)
cols = (alpha > 0.5).sum(0) > 0
lab, n = ndimage.label(ndimage.binary_closing(cols, iterations=25))
names = ['tough1', 'tough2', 'tough3', 'heavy', 'twoguns']
spans = ndimage.find_objects(lab)
print(n, [(s[0].start, s[0].stop) for s in spans])
assert n == 5
for name, sl in zip(names, spans):
    x0, x1 = sl[0].start, sl[0].stop
    m = alpha[:, x0:x1]
    ys = np.where((m > 0.5).sum(1) > 0)[0]
    y0, y1 = ys[0], ys[-1] + 1
    rgba = np.dstack([np.clip(a[y0:y1, x0:x1], 0, 255), m[y0:y1] * 255]).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    k = 360 / max(im.size)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    im.save(REPO + f'art/ui/instincts/icon_{name}.png')
    print(name, im.size)
