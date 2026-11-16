# Coat skirt drawings for the run and the leap (art_src 159: run | leap | swing, on white).
# Each is cut out, scaled so its belt is as wide as skirt.png's, the belt's middle at x=W/2, y=10.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
import sys
from paths import SRC
sys.path.insert(0, 'gen')
SRC = SRC + '159.jpg'
OUT = 'art/detective/'
src = Image.open(SRC).convert('RGB')
rgb = np.asarray(src).astype(float)
lum = rgb.mean(2)
mask = ndimage.binary_fill_holes(ndimage.binary_closing(lum < 235, iterations=3))
lab, n = ndimage.label(mask)
SKIRT_TOP = 362.0   # skirt.png: belt row width in pixels
for name, pick_x, squash in [('skirt_run', 600, 0.84), ('skirt_air', 1280, 1.0)]:   # the run drawing is drawn long: shortened to the hanging coat's length
    ys, xs = np.where(mask)
    # the component under this column near the top
    col = lab[:, pick_x]
    b = np.bincount(col[col > 0]).argmax()
    m = lab == b
    ys, xs = np.where(m)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    top = np.where(m[y0 + 10])[0]
    width = top.max() - top.min()
    mid = (top.max() + top.min()) / 2.0
    # alpha: inside the shape, anti-aliased at the outline by how dark the paper is just outside
    soft = ndimage.gaussian_filter(ndimage.binary_erosion(m, iterations=2).astype(float), 0.8)   # no paper rim
    alpha = np.clip(soft * 1.4, 0, 1)
    alpha[:y0 + 2] = 0   # cut straight at the belt
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    half = int(max(mid - x0, x1 - mid)) + 4
    box = (int(mid - half), y0 - 8, int(mid + half), y1 + 4)
    im = Image.fromarray(rgba).crop(box)
    k = SKIRT_TOP / width
    im = im.resize((int(im.width * k), int(im.height * k * squash)), Image.LANCZOS)
    im.save(OUT + name + '.png')
    print(name, im.size, 'belt mid x', im.width / 2, 'belt y', round(8 * k * squash, 1))
# normal maps: gen/enemies.py normal_map() run on both files
