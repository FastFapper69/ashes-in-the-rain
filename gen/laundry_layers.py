"""The big laundry hall's new parts (QUEUE §14, user 18. 11.: "a much bigger room, traversal, more enemies").
Gemini drew each part twice - with its steel catwalk and without it (asked for the same picture with the catwalk taken
off) - and the catwalk layer is the 'with' picture where it differs from the 'without', inside the catwalk's own shapes
(railing band: only the dark iron, so what hangs behind stays on the wall; the deck; the posts; the ladder). Rule 27:
what he climbs and walks on is its own layer, a little in front of the wall.
  art_src 285/286 -> art/rooms/laundry_mid.png + laundry_mid_catwalk.png (boiler and drying room; ladder up)
  art_src 288/289 -> art/rooms/laundry_end.png + laundry_end_catwalk.png (sorting room; the foreman's office stays painted)
The middle part's catwalk was drawn 144 px higher than the end part's: its layer is moved down as a whole (a pure
translation of its own layer, rule 24) so the deck runs on at one height (row 722), cut at the floor."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DECK_Y = 722          # the deck's walking surface, drawing px, both parts (after the shift)
FLOOR = 1240          # the hall floor's front edge


def cut(with_f, without_f, parts, shift=0):
    a = np.asarray(Image.open(SRC + with_f).convert("RGB")).astype(float)
    b = np.asarray(Image.open(SRC + without_f).convert("RGB")).astype(float)
    H, W = a.shape[:2]
    diff = ndimage.binary_dilation(ndimage.gaussian_filter(np.abs(a - b).max(axis=2), 1.2) > 24, iterations=2)
    luma = a.mean(axis=2)
    yy, xx = np.mgrid[:H, :W]
    m = np.zeros((H, W), bool)
    for kind, (x0, y0, x1, y1) in parts:
        r = (xx >= x0) & (xx < x1) & (yy >= y0) & (yy < y1)
        m |= r & (luma < 120) if kind == "rail" else r
    m &= diff
    m = ndimage.binary_closing(m, iterations=2)
    lab, n = ndimage.label(m)
    sz = ndimage.sum(m, lab, range(1, n + 1))
    m = np.isin(lab, np.where(sz > 400)[0] + 1)
    alpha = ndimage.gaussian_filter(m.astype(float), 0.8)
    lay = np.dstack([a, alpha * 255])
    if shift:
        lay = np.roll(lay, shift, axis=0)
        lay[:shift, :, 3] = 0
    lay[FLOOR + 6:, :, 3] = 0   # never below the floor's front edge
    return Image.fromarray(lay.astype(np.uint8)), Image.fromarray(b.astype(np.uint8))


MID = [("rail", (300, 405, 2895, 582)), ("deck", (290, 576, 2895, 648)),
       ("post", (296, 600, 352, FLOOR)), ("post", (1104, 600, 1176, FLOOR)), ("post", (1946, 600, 2026, FLOOR)),
       ("post", (2656, 600, 2716, FLOOR)), ("post", (2796, 600, 2866, FLOOR)), ("ladder", (420, 560, 540, FLOOR))]
END = [("rail", (0, 550, 1500, 726)), ("deck", (0, 712, 1500, 760)),
       ("post", (440, 740, 540, FLOOR)), ("post", (600, 740, 690, FLOOR)), ("post", (1380, 740, 1460, FLOOR))]
out = os.path.join(ROOT, "art", "rooms")
lay, wall = cut("285.jpg", "286.jpg", MID, shift=DECK_Y - 578)
lay.save(os.path.join(out, "laundry_mid_catwalk.png")); wall.save(os.path.join(out, "laundry_mid.png"))
lay, wall = cut("288.jpg", "289.jpg", END)
lay.save(os.path.join(out, "laundry_end_catwalk.png")); wall.save(os.path.join(out, "laundry_end.png"))
if "--check" in sys.argv:
    s = Image.new("RGB", (1584, 1344))
    for i, n in enumerate(("laundry_mid", "laundry_end")):
        w = Image.open(os.path.join(out, n + ".png")).convert("RGB")
        l = Image.open(os.path.join(out, n + "_catwalk.png"))
        w.paste(l, (0, 0), l)
        s.paste(w.resize((1584, 672)), (0, i * 672))
    s.save(os.path.join(ROOT, "_shots", "catwalk_check.jpg"))
print("laundry layers done")
