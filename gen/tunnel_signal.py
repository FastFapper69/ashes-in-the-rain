"""The tunnel signal the last train passes before a low girder (2026-11-21, QUEUE §16 C, rule 6: the red warning
light has its own drawn source). art_src 332 (Gemini, on green) -> art/props/tunnel_signal.png (keyed, 40 %).
Its red lens centre in the output's pixels is printed for setpieces.gd SIGNAL_LENS."""
import os
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(os.path.dirname(ROOT), "Ashes in the Rain", "art_src", "332.jpg")
a = np.asarray(Image.open(SRC).convert("RGB")).astype(int)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
green = (g - np.maximum(r, b)).clip(0, 255)
alpha = (255 - (green - 40).clip(0, 120) * 255 // 120).astype(np.uint8)
rgb = a.copy()
rgb[..., 1] = np.where(g > np.maximum(r, b), np.maximum(r, b), g)
im = Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA")
box = im.getbbox()
im = im.crop(box)
S = 0.4
im = im.resize((round(im.width * S), round(im.height * S)), Image.LANCZOS)
im.save(os.path.join(ROOT, "art", "props", "tunnel_signal.png"))
lens = ((977 - box[0]) * S, (1185 - box[1]) * S)   # the red lens's centre in the drawing (px of art_src 332)
print("size", im.size, "red lens", lens, "radius", round(190 * S))
