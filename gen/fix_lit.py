"""After gen/clean_signs.py repaints a sign, carry the change into the street's lit layer (half size):
the lit layer is the painting as the lamp shows it, so it would still show the old lettering.
Inside each edited box: new_lit = clean painting x (old lit / old painting), the lamp's own gain.
usage: fix_lit.py name original_painting.png"""
import sys
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, "gen")
from clean_signs import EDITS

name, orig = sys.argv[1], sys.argv[2]
lit_img = Image.open(f"art/street/{name}_lit.png").convert("RGBA")
k = lit_img.width / Image.open(orig).width
small = lambda p: np.asarray(Image.open(p).convert("RGB").resize(lit_img.size, Image.LANCZOS), np.float32)
old_p = small(orig)
new_p = small(f"art/street/{name}.png")
lit = np.asarray(lit_img, np.float32).copy()
blur = lambda a: np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)), np.float32)
gain = blur(lit[..., :3]) / np.maximum(blur(old_p), 8.0)
for e in EDITS[name]:
	x0, y0, x1, y1 = [int(round(v * k)) for v in e[1]]
	x0, y0, x1, y1 = x0 - 2, y0 - 2, x1 + 2, y1 + 2
	lit[y0:y1, x0:x1, :3] = np.clip(new_p[y0:y1, x0:x1] * gain[y0:y1, x0:x1], 0, 255)
Image.fromarray(lit.astype(np.uint8), "RGBA").save(f"art/street/{name}_lit.png")
print("fixed lit", name)
