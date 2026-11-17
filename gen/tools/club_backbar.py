"""The club room (art_src 245) without the low cabinet under the bottle shelves (user 17. 11.: "a bit of the bar is left
on the wall" - behind the new counter it read as a second bar). Where it showed above the counter (drawing y 862-1075),
the wall's own wainscot from right of it (x 792-904) is laid across, mirrored every other tile, edges feathered; below
that the counter (art/props/bar_counter.png) stands in front. Writes art_src 245b.png; gen/process_art.py ROOMS reads it."""
import os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from paths import SRC

a = np.asarray(Image.open(os.path.join(SRC, "245.jpg")).convert("RGB")).astype(float)
X0, X1, Y0, Y1 = 138, 762, 862, 1075
strip = a[Y0:Y1, 792:904]
tiles, flip = [], False
while sum(t.shape[1] for t in tiles) < X1 - X0:
    tiles.append(strip[:, ::-1] if flip else strip)
    flip = not flip
fill = np.concatenate(tiles, axis=1)[:, :X1 - X0]
h, w = fill.shape[:2]
yy, xx = np.mgrid[:h, :w]
m = np.minimum(np.minimum(xx, w - 1 - xx) / 14.0, np.minimum(yy, h - 1 - yy) / 6.0).clip(0, 1)[..., None]
m[:6] = np.maximum(m[:6], 0)   # (the top edge meets the shelf's ledge: keep the ledge line)
a[Y0:Y1, X0:X1] = a[Y0:Y1, X0:X1] * (1 - m) + fill * m
Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(os.path.join(SRC, "245b.png"))
print("245b.png")
