"""art/bg/sky.png: the drawing's low band had blurred city lights (orange bokeh) and a painted moon. From the
street the rooftops hide them; from a roof (the camera higher) they showed as ghost glows over the skyline,
doubled by the mirrored sky under it, and the painted moon made a second ring beside the game's own moon.
The low band is blended into a wide horizontal blur of itself (same tone and gradient, no spots); the painted
moon is inpainted. Run once from the repo root (keeps the original as art_src backup is git history)."""
import sys
import numpy as np, cv2
from PIL import Image

p = "art/bg/sky.png"
im = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
h, w, _ = im.shape
TOP, FULL = int(sys.argv[1]) if len(sys.argv) > 1 else 1120, int(sys.argv[2]) if len(sys.argv) > 2 else 1230
soft = cv2.GaussianBlur(im, (0, 0), sigmaX=220, sigmaY=12, borderType=cv2.BORDER_REFLECT)
k = np.clip((np.arange(h) - TOP) / float(FULL - TOP), 0.0, 1.0)
k = (k * k * (3 - 2 * k))[:, None, None]
out = im * (1 - k) + soft * k
Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(p)
print("cleaned rows", TOP, "-", h)
