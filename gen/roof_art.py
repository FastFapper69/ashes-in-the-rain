"""(playground station 5, roofs) art_src 357 (the roof strip over gen/roof_templates.py, its botched water tower on the
right cut off) -> art/city/roof_strip.png; art_src 358 (a front fire escape on one bay, front-on; its own cornice keyed
out but for the gooseneck through it - the front's cornice is the module's) -> art/city/escape_front.png.
Measured on 358 (fractions of its height, the drawing = 2464 world): decks .68 / .405 / .20, drop ladder to .847,
flights (.28,.68)->(.72,.405) and (.28,.405)->(.62,.20), gooseneck x .79 (main.gd / gen/levels.py ESCF_*)."""
import numpy as np
from PIL import Image
from paths import SRC, REPO


def key(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = 1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1)
    a = a.copy()
    a[..., 1] = np.minimum(g, np.maximum(r, b) + 12)
    return np.clip(a, 0, 255), alpha


a = np.asarray(Image.open(SRC + "357.jpg").convert("RGB")).astype(np.float32)
a = a[:, :int(a.shape[1] * 0.735)]                       # (to the chimney before the water tower)
rgb, al = key(a)
im = Image.fromarray(np.dstack([rgb, al * 255]).astype(np.uint8), "RGBA")
im = im.resize((im.width // 2 // 4 * 4, im.height // 2 // 4 * 4), Image.LANCZOS)
im.save(REPO + "art/city/roof_strip.png")
print("roof_strip", im.size)
a = np.asarray(Image.open(SRC + "358.jpg").convert("RGB")).astype(np.float32)
rgb, al = key(a)
H, W = al.shape
y0, y1 = int(H * 0.045), int(H * 0.13)                    # its cornice band
keep = np.zeros(W, bool)
keep[int(W * 0.735):int(W * 0.855)] = True                  # (the gooseneck goes up through it)
al[y0:y1, ~keep] = 0
P = 120                                                   # in its column the ladder as it is just under the band, repeated up
x0, x1 = int(W * 0.735), int(W * 0.855)                   # (the stone behind it is the module's cornice, not this one)
src_rgb, src_al = rgb[y1:y1 + P, x0:x1].copy(), al[y1:y1 + P, x0:x1].copy()
for y in range(y1 - P, y0 - P, -P):
    a0 = max(y, y0)
    rgb[a0:y + P, x0:x1] = src_rgb[a0 - y:]
    al[a0:y + P, x0:x1] = src_al[a0 - y:]
im = Image.fromarray(np.dstack([rgb, al * 255]).astype(np.uint8), "RGBA")
im = im.resize((W // 2 // 4 * 4, H // 2 // 4 * 4), Image.LANCZOS)
im.save(REPO + "art/city/escape_front.png")
print("escape_front", im.size)

# (23. 11., user: the joint of two fronts at the roofs) art_src 359: a brick party-wall pier with its coping and a
# downpipe, front-on, over gen/templates_party.py (600 x 2600 world; its coping's top 120 under the picture's top...
# the picture's top = the roof - 120) -> art/city/party_wall.png
a = np.asarray(Image.open(SRC + "359.jpg").convert("RGB")).astype(np.float32)
rgb, al = key(a)
im = Image.fromarray(np.dstack([rgb, al * 255]).astype(np.uint8), "RGBA")
im = im.resize((im.width // 2 // 4 * 4, im.height // 2 // 4 * 4), Image.LANCZOS)
im.save(REPO + "art/city/party_wall.png")
print("party_wall", im.size)
