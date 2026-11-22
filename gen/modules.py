"""The modular city's art (QUEUE §21, rule 31), from Gemini's drawings in art_src:
  347 brick tenement front, 348 limestone front, 350 soot-black walk-up (arched windows, a diner), 351 pale brick (3 bays x 3 storeys + cornice on gen/module_template.py's grid:
      3000 x 2400 world px; cut in the game by main.gd CITY_* on the same grid)  -> art/city/brick.png, stone.png
  349 the alley between two of them (gen/alley_gap_template.py), its sky keyed out          -> art/city/alley_gap.png
  346 a side-wall fire escape seen edge-on, keyed, cut at the wall (x 72)                     -> art/city/escape_side.png
      (decks at rows 524 / 1756 of the drawing = 452 / 1684 here, 733 px deep; main.gd CITY_ESC_*)
Run: py gen/modules.py"""
import numpy as np
from PIL import Image
from paths import SRC, REPO

OUT = REPO + "art/city/"


def key(a):
    """Flat green out: alpha from how green a pixel is, the green spill taken off the edges."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = 1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1)
    a = a.copy()
    a[..., 1] = np.minimum(g, np.maximum(r, b) + 12)
    return np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)


def fit4(im):
    return im.crop((0, 0, im.width - im.width % 4, im.height - im.height % 4))


for src, name in (("347.jpg", "brick"), ("348.jpg", "stone"), ("350.jpg", "walkup"), ("351.jpg", "pale")):
    im = fit4(Image.open(SRC + src).convert("RGB"))
    im.save(OUT + name + ".png")
    print(src, "->", name, im.size)
a = np.asarray(Image.open(SRC + "349.jpg").convert("RGB")).astype(np.float32)
im = fit4(Image.fromarray(key(a), "RGBA"))
im.save(OUT + "alley_gap.png")
print("349 -> alley_gap", im.size)
a = np.asarray(Image.open(SRC + "346.jpg").convert("RGB")).astype(np.float32)[:, 72:]
im = fit4(Image.fromarray(key(a), "RGBA"))
im = im.crop((0, 0, 760, im.height))   # (all of the iron: 733 px out from the wall)
im.save(OUT + "escape_side.png")
print("346 -> escape_side", im.size)
