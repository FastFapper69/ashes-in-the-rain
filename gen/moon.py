# A full moon in ink and wash: pale disc, soft grey seas, a dark rim line.
import numpy as np
from PIL import Image, ImageFilter
from paths import REPO
N = 384
y, x = np.mgrid[0:N, 0:N] / N * 2 - 1
r = np.sqrt(x * x + y * y)
rng = np.random.default_rng(1947)
noise = np.zeros((N, N))
for scale, amp in ((6, 0.5), (14, 0.3), (40, 0.2)):
    small = rng.random((scale, scale))
    noise += np.asarray(Image.fromarray((small * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)) / 255 * amp
seas = np.clip((noise - 0.55) * 3, 0, 1)
shade = 0.93 - 0.28 * seas - 0.12 * r ** 3
col = np.stack([shade * 240, shade * 236, shade * 222], 2)
rim = np.clip(1 - np.abs(r - 0.955) / 0.02, 0, 1)
col = col * (1 - rim[..., None] * 0.7)
alpha = np.clip((0.975 - r) / 0.01, 0, 1)
img = Image.fromarray(np.dstack([col, alpha * 255]).astype(np.uint8), 'RGBA')
img.save(REPO + 'art/bg/moon.png')
