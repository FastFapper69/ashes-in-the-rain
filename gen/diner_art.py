"""(rule 33, playground) The diner: art_src 355 (its inside over gen/shop_template.py) -> art/section/shop_hall.png;
art_src 356 (a table knocked on its side, on green) keyed -> art/props/table.png (cover the men put up in there)."""
import numpy as np
from PIL import Image
from paths import SRC, REPO
im = Image.open(SRC + "355.jpg").convert("RGB")
im.crop((0, 0, im.width - im.width % 4, im.height - im.height % 4)).save(REPO + "art/section/shop_hall.png")
a = np.asarray(Image.open(SRC + "356.jpg").convert("RGB")).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
alpha = 1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1)
a[..., 1] = np.minimum(g, np.maximum(r, b) + 12)
t = Image.fromarray(np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
t = t.crop(t.getbbox())
t = t.resize((t.width // 2, t.height // 2), Image.LANCZOS)
t.save(REPO + "art/props/table.png")
print("table", t.size)
