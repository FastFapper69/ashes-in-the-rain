"""THE DREAM's burning posts in the foreground (user 18. 11.: "they must come from the bottom of the screen, never seen
to start in the middle of nothing"): art_src 318 (Gemini, the charred post on flat green, running out of the top and
bottom of the picture) -> art/fore/dream_post.png, cut to the post's own width, rows kept whole top to bottom."""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from paths import SRC
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "fore", "dream_post.png")
a = np.asarray(Image.open(SRC + "318.jpg").convert("RGB")).astype(float)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
green = (g > 150) & (g > r + 60) & (g > b + 60)
a[..., 1] = np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2]) + 12)   # no green fringe
alpha = ndimage.gaussian_filter((~green).astype(float), 0.8)
cols = np.where((~green).mean(0) > 0.02)[0]
x0, x1 = max(0, cols.min() - 4), min(a.shape[1], cols.max() + 5)
im = Image.fromarray(np.dstack([a, alpha * 255]).astype(np.uint8)[:, x0:x1])
im = im.resize((im.width * 1400 // im.height, 1400), Image.LANCZOS)   # (it is shown out of focus: no need for more)
im.save(OUT)
print("dream_post", im.size)
