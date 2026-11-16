# Cuts the Gemini sheet of police heads (art_src/71.png) into puppet heads like the mobsters' (enemies.py):
# each head cut off just under the chin, at the top of the uniform collar, 378 px tall.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
import sys
from paths import SRC, REPO
sys.argv = ['x']
OUT = REPO + 'art/'
src = np.asarray(Image.open(SRC + '71.png').convert('RGB')).astype(int)
H, W = src.shape[:2]
paper = (src.min(2) > 200) & ((src.max(2) - src.min(2)) < 30)
lab, n = ndimage.label(paper)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
out = np.isin(lab, list(edge))
a = np.where(out, 0, 255).astype(np.uint8)
a = np.asarray(Image.fromarray(a).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.7)))
cut_y = int(H * 0.675)   # the chin line across the sheet; below it collars and captions
blobs, m = ndimage.label(ndimage.binary_dilation(~out[:cut_y], iterations=10))
parts = []
for k, sl in enumerate(ndimage.find_objects(blobs)):
    if (sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start) < 60000:
        continue
    keep = blobs[sl] == k + 1
    alpha = np.where(keep, a[:cut_y][sl], 0).astype(np.uint8)
    im = Image.fromarray(np.dstack([src[:cut_y][sl], alpha]).astype(np.uint8), 'RGBA')
    im = im.crop(Image.fromarray(alpha).getbbox())
    parts.append((sl[1].start, im))
parts.sort(key=lambda p: p[0])
for name, (x, im) in zip(['patrol', 'rain', 'sergeant', 'briggs'], parts):
    im = im.resize((im.width * 360 // im.height, 360), Image.LANCZOS)
    im.save(OUT + f'police/heads/{name}.png')
    al = np.asarray(im)[..., 3] > 128
    cols = np.where(al[im.height - 15])[0]
    print(name, im.size, 'neck x', round(float(cols.mean()), 1))
    imn = Image.open(OUT + f'police/heads/{name}.png')
    d = ndimage.distance_transform_edt(np.asarray(imn)[..., 3] > 128)
    h = ndimage.gaussian_filter(np.sqrt(np.clip(d / 28.0, 0, 1)) * 28.0, 2.0) + np.asarray(imn.convert('L').filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255.0 * 6.0
    gy, gx = np.gradient(h)
    nm = np.dstack([-gx, -gy, np.ones_like(h) * 1.2]); nm /= np.linalg.norm(nm, axis=2, keepdims=True)
    Image.fromarray(((nm + 1) * 127.5).clip(0, 255).astype(np.uint8)).save(OUT + f'police/heads/{name}_n.png')
