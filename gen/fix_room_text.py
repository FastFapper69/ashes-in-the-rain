"""Real names on the tenement hallway's door plates (QUEUE_doma §9 c: the plates under 3A, 3B, 3C were AI glyph soup,
knowledge rule 1). Reads the room drawing from art_src (gen/process_art.py ROOMS) and writes art/rooms/<style>.png
with each plate wiped to its card colour and a name written on it in a hand.
Run after process_art.py (which copies the room drawings in):  py gen/fix_room_text.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from paths import SRC, REPO

FIXES = {
    "tenement": ("31.png", [   # plate inside (x0, y0, x1, y1) in the drawing's px, the name, its size, its tilt
        ((506, 677, 589, 711), "O'Hara", 26, -2.0),
        ((1088, 682, 1124, 713), "Russo", 15, -4.0),
        ((2478, 675, 2564, 710), "Duffy", 26, -1.0),
    ]),
}
FONT = REPO + "fonts/ReenieBeanie.ttf"

for style, (src, plates) in FIXES.items():
    im = Image.open(SRC + src).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    for (x0, y0, x1, y1), name, size, tilt in plates:
        card = a[y0:y1, x0:x1].reshape(-1, 3)
        light = card[card.mean(1) > np.percentile(card.mean(1), 60)].mean(0)   # the card itself, not the ink on it
        noise = np.random.default_rng(x0).normal(0.0, 4.0, (y1 - y0, x1 - x0, 1))
        a[y0:y1, x0:x1] = np.clip(light + noise, 0, 255)
        im = Image.fromarray(a.astype(np.uint8))
        # the name, written on a layer of its own, tilted with the plate, a little soft like the ink round it
        layer = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        f = ImageFont.truetype(FONT, size)
        w = d.textlength(name, font=f)
        d.text(((x1 - x0 - w) / 2, (y1 - y0) / 2 - size * 0.62), name, font=f, fill=(34, 30, 28, 235))
        layer = layer.rotate(tilt, resample=Image.BICUBIC).filter(ImageFilter.GaussianBlur(0.35))
        im.paste(layer, (x0, y0), layer)
        a = np.asarray(im).astype(np.float32)
    out = os.path.join(REPO, "art", "rooms", style + ".png")
    im.save(out)
    print("plates", style, "->", out)
