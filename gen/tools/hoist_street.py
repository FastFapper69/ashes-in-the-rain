"""art/street/warehouse_c.png: the warehouse street with its hoist's hanging rope and hook taken out (the game hangs
its own swinging rope from the painted pulley, gen/levels.py HOIST). Gemini removed them (art_src 226, only its
1024 px preview could be fetched): the patch is taken from it only where the rope and hook were (a tight mask
under the pulley), so the rest stays the original drawing pixel for pixel. Run from the repo root."""
import os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
SRC = os.path.join(os.path.expanduser("~"), "Documents", "MobileGames", "Ink and Lead", "art_src", "226.png")
o = Image.open("art/street/warehouse.png").convert("RGB")
e = Image.open(SRC).convert("RGB").resize(o.size, Image.LANCZOS).filter(ImageFilter.UnsharpMask(2, 80, 2))
a = np.asarray(o).astype(float)
b = np.asarray(e).astype(float)
la, lb = a.mean(2), b.mean(2)
m = np.zeros(la.shape, bool)
y0, y1, x0, x1 = 618, 792, 650, 750          # under the pulley: the hanging rope and the hook
m[y0:y1, x0:x1] = (la[y0:y1, x0:x1] < lb[y0:y1, x0:x1] - 35)   # dark in the original, gone in the edit
m = ndimage.binary_dilation(m, iterations=3)
# (the preview's pixels are too soft to paste: they only say WHERE the rope and hook were; the hole is filled from
# the original drawing around it, so it stays sharp)
import cv2
out = cv2.inpaint(np.asarray(o)[..., ::-1].copy(), m.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA)[..., ::-1]
Image.fromarray(out).save("art/street/warehouse_c.png")
import shutil   # its lit windows and blood mask are the warehouse's own (nothing there moved)
for layer in ("_lit", "_solid"):
    shutil.copy(f"art/street/warehouse{layer}.png", f"art/street/warehouse_c{layer}.png")
print("patched px", int(m.sum()))
