"""hk_tailor's fire escape as a layer of its own (QUEUE §11, rule 27: climbable things stand out of the wall).
The fire escape: built in Blender from the game's own numbers (gen/blender/fire_escape.py, box BOX in the street
drawing's px), repainted by Gemini in the street's ink style keeping every edge (art_src 280, on green) -> keyed into
art/props/hk_fescape.png. The wall behind it: art_src 276 (Gemini: the street without the fire escape) registered onto
233 and laid in over the fire escape's box, feathered -> art_src 279.jpg (process_art hk_tailor uses it).
Run: py gen/fire_escape_layer.py   then   py gen/process_art.py hk_tailor"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC, REPO

BOX = (1880, 250, 2360, 930)   # = gen/blender/fire_escape.py BOX (processed px, 3168 x 1344)


def gray(im):
    return np.asarray(im.convert("L")).astype(np.float32)


def register(mov, ref_g, region, ks=(0.97, 0.975, 0.98, 0.985, 0.99, 0.995, 1.0)):
    x0, y0, x1, y1 = region
    best = None
    for k in ks:
        m = np.asarray(Image.fromarray(mov.astype(np.uint8)).resize((int(mov.shape[1] * k), int(mov.shape[0] * k)), Image.BILINEAR)).astype(np.float32)
        for dy in range(-60, 61, 2):
            for dx in range(-60, 61, 2):
                sy, sx = y0 - dy, x0 - dx
                if sy < 0 or sx < 0 or sy + (y1 - y0) > m.shape[0] or sx + (x1 - x0) > m.shape[1]:
                    continue
                e = float(np.abs(ref_g[y0:y1:3, x0:x1:3] - m[sy:sy + (y1 - y0):3, sx:sx + (x1 - x0):3]).mean())
                if best is None or e < best[0]:
                    best = (e, k, dx, dy)
    return best


# the layer
a = np.asarray(Image.open(SRC + "280.jpg").convert("RGB").resize(((BOX[2] - BOX[0]) * 2, (BOX[3] - BOX[1]) * 2), Image.LANCZOS)).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
alpha = 1.0 - np.clip((g - np.maximum(r, b) - 30.0) / 60.0, 0.0, 1.0)
alpha = ndimage.grey_opening(alpha, size=(2, 2))
a[..., 1] = np.minimum(g, np.maximum(r, b))   # (no green left in the iron or its hatching)
Image.fromarray(np.dstack([a, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(REPO, "art", "props", "hk_fescape.png"))

# the wall behind it
street = Image.open(SRC + "233.jpg").convert("RGB")
W, H = street.size
sx, sy = W / 3168.0, H / 1344.0
reg = (int(1700 * sx), int(150 * sy), int(2600 * sx), int(1050 * sy))
clean = Image.open(SRC + "276.jpg").convert("RGB")
e, k, dx, dy = register(gray(clean), gray(street), reg)
print("276 onto 233: err", round(e, 1), "k", k, "dx", dx, "dy", dy)
cs = clean.resize((int(clean.width * k), int(clean.height * k)), Image.LANCZOS)
on = Image.new("RGB", (W, H))
on.paste(cs, (dx, dy))
m = np.zeros((H, W), np.float32)
m[int((BOX[1] - 25) * sy):int((BOX[3] + 25) * sy), int((BOX[0] - 30) * sx):int((BOX[2] + 30) * sx)] = 1.0
m = ndimage.gaussian_filter(m, 14.0)
out = np.asarray(street).astype(np.float32) * (1 - m[..., None]) + np.asarray(on).astype(np.float32) * m[..., None]
Image.fromarray(out.clip(0, 255).astype(np.uint8)).save(SRC + "279.jpg", quality=95)
print("ok")
