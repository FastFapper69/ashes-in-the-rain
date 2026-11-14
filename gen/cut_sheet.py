"""Cut the police report sheet (art_src/93.jpg) off its white page: transparent outside the paper."""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
white = a.min(axis=2) > 238
lab, n = ndimage.label(white)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
outside = np.isin(lab, list(edge))
paper = ~outside
paper = ndimage.binary_opening(paper, iterations=2)
alpha = ndimage.gaussian_filter(paper.astype(np.float32), 0.8)
ys, xs = np.where(paper)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
rgba = np.dstack([a, alpha * 255]).astype(np.uint8)[y0:y1, x0:x1]
img = Image.fromarray(rgba, "RGBA")
img = img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
img.save(dst)
print(img.size, (x0, y0, x1, y1))
