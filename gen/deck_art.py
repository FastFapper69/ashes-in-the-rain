"""The Santa Lucia's deck drawings (art_src 333-335, QUEUE §18, 21. 11.) after gen/process_art.py: Gemini painted a warm
glow round the deck lanterns out into the white sky, and the sky key leaves that halo as a pale disc. The halo is
taken out with the sky: inside a box round each lantern, bright pixels joined to the sky go transparent (the lantern's
glass is shut in by its ink frame, so it stays). The game lights the lantern itself (rule 6).

  py -3 gen/deck_art.py            (run after: py -3 gen/process_art.py deck_a deck_b deck_c)"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANTERNS = {"deck_a": [(2600, 463)], "deck_b": [(2213, 438)]}   # drawing px (trimmed picture), the lantern's glass
R = 300

for name, spots in LANTERNS.items():
    path = os.path.join(ROOT, "art", "street", name + ".png")
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    lum = a[..., :3].astype(float).mean(2)
    sky = a[..., 3] < 128
    for cx, cy in spots:
        y0, y1, x0, x1 = max(0, cy - R), cy + 170, max(0, cx - R), cx + R   # (not down into the skyline)
        sub_l, sub_s = lum[y0:y1, x0:x1], sky[y0:y1, x0:x1]
        cand = (sub_l > 110) | sub_s
        lab, n = ndimage.label(cand)
        keep = set(np.unique(lab[sub_s])) - {0}
        halo = np.isin(lab, list(keep)) & ~sub_s
        halo = ndimage.binary_dilation(halo, iterations=7) & (sub_l > 55) & ~sub_s   # (and its last pale rim)
        a[y0:y1, x0:x1, 3][halo] = 0
        soft = (a[y0:y1, x0:x1, 3] < 200) & (sub_l > 55)   # the sky key's soft edge round where the halo was
        a[y0:y1, x0:x1, 3][soft] = 0
        print(name, (cx, cy), "halo px", int(halo.sum()))
    Image.fromarray(a).save(path)
