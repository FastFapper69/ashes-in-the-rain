"""The night street's neon signs (QUEUE_doma §12: THE BLUE NOTE's landmark, a street full of neon). art_src 266: five signs on
black, each on a wall bracket at its top left. Cut apart into art/props/sign_<name>.png (the sign, black keyed out) and
sign_<name>_glow.png (only its lit tubes, for the additive glow and the light it throws).
Run: py gen/neon_signs.py
"""
import os
import numpy as np
from PIL import Image, ImageFilter
from paths import SRC, REPO

BOXES = {   # picture px (x0, x1, y0, y1), found by labelling the non-black blobs
    "hotel": (93, 524, 103, 1260), "bar": (609, 1144, 452, 820), "dancing": (1238, 1984, 452, 824),
    "cafe": (2074, 2621, 452, 813), "liquors": (2697, 3054, 104, 1248),
}
src = np.asarray(Image.open(SRC + "266.jpg").convert("RGB")).astype(np.float32)
for name, (x0, x1, y0, y1) in BOXES.items():
    rgb = src[y0:y1, x0:x1]
    v = rgb.max(2)
    alpha = np.clip((v - 14.0) / 30.0, 0.0, 1.0)                      # the black around it goes
    sat = v - rgb.min(2)
    tube = np.clip((v - 150.0) / 80.0, 0.0, 1.0) * np.clip(sat / 60.0 + (v > 235), 0.0, 1.0)   # bright and coloured: the tubes
    out = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(os.path.join(REPO, "art", "props", f"sign_{name}.png"))
    g = Image.fromarray((tube * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(3))
    g = np.maximum(np.asarray(g).astype(np.float32) / 255.0, tube)
    glow = np.dstack([np.full_like(g, 255), np.full_like(g, 255), np.full_like(g, 255), g * 255]).astype(np.uint8)
    Image.fromarray(glow, "RGBA").save(os.path.join(REPO, "art", "props", f"sign_{name}_glow.png"))
    print(name, out.shape[1], "x", out.shape[0])
