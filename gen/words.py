# Cuts the Gemini lettering sheet (art_src/37.png) into single comic words. The white paper is
# taken out only where it reaches the sheet's edge, so cream letters and enclosed bits stay.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
src = np.asarray(Image.open('/mnt/user-data/uploads/Ink and Lead/art_src/37.png').convert('RGB')).astype(int)
h, w = src.shape[:2]
paper = (src.min(2) > 238) & ((src.max(2) - src.min(2)) < 18)
lab, n = ndimage.label(paper)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
outside = np.isin(lab, list(edge))
alpha = np.where(outside, 0, 255).astype(np.uint8)
alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.8)))
blobs, m = ndimage.label(ndimage.binary_dilation(~outside, iterations=6))
parts = [(k + 1, sl, ((sl[0].start + sl[0].stop) / 2, (sl[1].start + sl[1].stop) / 2), (sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start))
         for k, sl in enumerate(ndimage.find_objects(blobs))]
big = [p for p in parts if p[3] > 40000]
groups = {i: [b[:2]] for i, b in enumerate(big)}
for lid, sl, c, a in parts:   # bits of glass, splinters and dust go with the nearest word
    if a > 40000:
        continue
    j = min(range(len(big)), key=lambda i: (big[i][2][0] - c[0]) ** 2 + (big[i][2][1] - c[1]) ** 2)
    if ((big[j][2][0] - c[0]) ** 2 + (big[j][2][1] - c[1]) ** 2) ** 0.5 < 380:
        groups[j].append((lid, sl))
words = []
groups_by_main = {m[0][0]: m for m in groups.values()}
for i, members in groups.items():
    y0 = min(s_[0].start for _, s_ in members); y1 = max(s_[0].stop for _, s_ in members)
    x0 = min(s_[1].start for _, s_ in members); x1 = max(s_[1].stop for _, s_ in members)
    sl = (slice(y0, y1), slice(x0, x1))
    keep = np.isin(blobs[sl], [lid for lid, _ in members])   # only this word's own pieces
    cy, cx = big[i][2][0] / h, big[i][2][1] / w
    words.append((cy, cx, sl, keep, members[0][0]))
NAMES = {  # by where each sits on the sheet (row, column)
    (0, 0): 'pow', (0, 1): 'bam', (0, 2): 'crack', (1, 0): 'wham', (1, 1): 'click', (1, 2): 'kachak',
    (2, 1): 'smash', (2, 2): 'crash2', (3, 0): 'crash', (3, 1): 'thud', (3, 2): 'zing'}
for cy, cx, sl, keep, main_id in words:
    key = (min(3, int(cy * 4)), min(2, int(cx * 3)))
    name = NAMES.get(key, f'x{key}')
    if name in ('click', 'kachak'):   # no flying bits of their own: only pieces level with the word
        main_sl = next(s_ for lid, s_ in groups_by_main[main_id] if lid == main_id)
        ids = [lid for lid, s_ in groups_by_main[main_id] if s_[0].start < main_sl[0].stop - 10 and s_[0].stop > main_sl[0].start + 10]
        keep = np.isin(blobs[sl], ids)
    rgba = np.dstack([src[sl], np.where(keep, alpha[sl], 0)]).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    bb = Image.fromarray(rgba[..., 3]).getbbox(); im = im.crop(bb)
    im.save(f'/home/claude/repo/art/fx/word_{name}.png')
    print(name, key, im.size)
