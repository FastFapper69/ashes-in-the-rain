"""Soften straight horizontal cut lines where a street drawing's keyed-out sky meets painted haze.
For each column the first opaque row from the top is found; a run of >= MIN_RUN columns whose first
opaque row is the same (+-2 px) and whose pixel there is light haze (not ink) is a cut line: those
columns get an alpha ramp over RAMP px below it, leaving dark ink (poles, wires, roofs) solid.
Run: python3 gen/tools/feather_sky.py art/street/harbor.png [...]  (writes in place)."""
import sys
import numpy as np
from PIL import Image
MIN_RUN, RAMP = 120, 150
for path in sys.argv[1:]:
    im = Image.open(path).convert('RGBA'); a = np.asarray(im).astype(np.float32)
    H, W = a.shape[:2]
    alpha = a[..., 3]; lum = a[..., :3].mean(axis=2)
    up = np.vstack([np.zeros((1, W)), alpha[:-1]])
    jump = (up < 30) & (alpha > 200) & (lum > 70)   # light haze starting right under keyed-out sky
    jump[: int(H * 0.08)] = False
    jump[int(H * 0.7):] = False
    fixed = 0
    done = np.zeros(W, bool)
    for y in range(H):
        row = jump[y]
        if row.sum() < MIN_RUN:
            continue
        x = 0
        while x < W:
            if not row[x]:
                x += 1; continue
            x1 = x; gap = 0
            while x1 + 1 < W and (row[x1 + 1] or gap < 4):
                gap = 0 if row[x1 + 1] else gap + 1
                x1 += 1
            if x1 - x + 1 >= MIN_RUN:
                for xx in range(x, x1 + 1):
                    if done[xx] or not row[xx]:
                        continue
                    done[xx] = True
                    for k in range(RAMP):
                        yy = y + k
                        if yy >= H: break
                        if lum[yy, xx] < 55:
                            continue
                        t = k / RAMP
                        alpha[yy, xx] *= t * t * (3 - 2 * t)
                    fixed += 1
            x = x1 + 1
    # light leftovers of the keyed sky above the cut (white specks) go too
    if fixed:
        a[..., 3] = alpha
        Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(path)
    print(path, 'feathered columns:', fixed)
