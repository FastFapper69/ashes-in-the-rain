# The nightmare (2026-11-15): Pier 17's warehouse on fire, three drawings (art_src 131-133) that join
# post to post: each keeps the timber post down its left edge and loses the one on its right, so the
# next drawing's own post stands at the join. The painted fire gets a glow layer of its own (fire_*_lit)
# that the game makes flicker, and the flame sheet (134) is cut into six hand-inked flames.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from paths import SRC, REPO
OUT = REPO + 'art/'
RIGHT_POST = 100
for name, f in [('fire_a', '131.png'), ('fire_b', '132.png'), ('fire_c', '133.png')]:
    rgb = np.asarray(Image.open(SRC + f).convert('RGB'))[:, :-RIGHT_POST]
    h, w = rgb.shape[:2]
    Image.fromarray(np.dstack([rgb, np.full((h, w), 255, np.uint8)])).save(OUT + f'street/{name}.png')
    a = rgb.astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    fire = np.clip((r - b - 60) / 70, 0, 1) * np.clip((r - 150) / 70, 0, 1)
    fire = ndimage.grey_opening(fire, size=(3, 3))
    glow = np.asarray(Image.fromarray((fire * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float) / 255
    glow = np.maximum(fire, glow * 0.9)
    lit = Image.fromarray(np.dstack([a, glow * 255]).astype(np.uint8), 'RGBA')
    lit.resize((w // 2, h // 2), Image.LANCZOS).save(OUT + f'street/{name}_lit.png')
    solid = Image.new('L', (w // 2, h // 2), 255)
    Image.merge('RGBA', [solid] * 4).save(OUT + f'street/{name}_solid.png')
    # where the painted fire burns (for live flames over it): column-wise share of fire near the floor
    print(name, (w, h), 'fire share', round(float((fire > 0.5).mean()), 3))
