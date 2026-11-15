# The harbor drawing's far view had a grey fog sky under the white one; only the white was cut out, so a
# hard straight edge showed where the painted fog met the game's sky (seen jumping). The fog joined to
# that edge is faded out over FADE pixels, so the far view melts into the sky.  Run after process_art.
import numpy as np
from PIL import Image
from scipy import ndimage
P = 'art/street/harbor.png'
FADE = 140
im = np.asarray(Image.open(P).convert('RGBA')).astype(float)
a = im[..., 3]
H, W = a.shape
# the straight edge: the first opaque row in each column of the view, where many columns agree
top = np.array([(a[:, x] > 128).argmax() for x in range(W)])
vals, counts = np.unique(top[int(W * 0.6):], return_counts=True)
edge = int(vals[np.argmax(counts)])
cols = np.where(np.abs(top - edge) <= 1)[0]
print('edge row', edge, 'columns', cols.min(), cols.max(), len(cols))
lum = ndimage.gaussian_filter(im[..., :3].mean(2), 2.0)
sat = im[..., :3].max(2) - im[..., :3].min(2)
ref = float(np.median(lum[edge + 3, cols]))   # the fog's own grey, just under the edge
band = np.zeros_like(a, bool)
band[edge - 2:edge + FADE, cols.min() - 160:cols.max() + 60] = True
smooth = (np.abs(lum - ref) < 34.0) & (sat < 35) & band & (a > 40)
lab, n = ndimage.label(smooth)
seeds = set(np.unique(lab[edge + 1, cols])) - {0}
fog = np.isin(lab, list(seeds))
fog = ndimage.binary_closing(fog, iterations=2) & band
ramp = np.clip((np.arange(H) - edge + 2) / FADE, 0.0, 1.0)[:, None]
newa = np.where(fog, a * ramp, a)
newa = ndimage.gaussian_filter(newa, 1.0) * (newa > 0) + 0.0
im[..., 3] = np.minimum(a, np.maximum(newa, np.where(fog, 0, a)))
Image.fromarray(im.astype(np.uint8)).save(P)
print('fog px', int(fog.sum()))
# the hairline the first cut left along the edge: those few rows go too, except where a pole runs on down
im = np.asarray(Image.open(P).convert('RGBA')).astype(float)
lum0 = im[..., :3].mean(2)
for x in range(cols.min() - 160, cols.max() + 60):
    pole = lum0[edge + 20, x] < 70 and lum0[edge + 40, x] < 70 and im[edge + 30, x, 3] > 200
    if not pole:
        for y in range(edge - 3, edge + 6):
            im[y, x, 3] *= min(1.0, max(0.0, (y - edge - 2) / 8.0))
Image.fromarray(im.astype(np.uint8)).save(P)
# left of the fog, the shadowed side of the near shed was cut straight across by the same edge: fade it too
im = np.asarray(Image.open(P).convert('RGBA')).astype(float)
for x in range(cols.min() - 160, cols.min()):
    for y in range(edge - 2, edge + FADE):
        if im[y, x, :3].mean() < 75:
            im[y, x, 3] *= min(1.0, max(0.0, (y - edge) / FADE))
Image.fromarray(im.astype(np.uint8)).save(P)
