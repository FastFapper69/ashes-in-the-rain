# Cuts the Gemini weapon sheet (art_src/39.png) into the four guns, paper keyed out.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from paths import SRC, REPO
src = np.asarray(Image.open(SRC + '39.png').convert('RGB')).astype(int)
h, w = src.shape[:2]
paper = (src.min(2) > 225) & ((src.max(2) - src.min(2)) < 20)
lab, n = ndimage.label(paper)
edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
out = np.isin(lab, list(edge))
holes = paper & ~out
sizes = ndimage.sum(np.ones_like(lab), lab, index=np.arange(n + 1))
out |= holes & (sizes[lab] > 400)   # the trigger guard and other see-through gaps
a = np.where(out, 0, 255).astype(np.uint8)
a = np.asarray(Image.fromarray(a).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.7)))
CELLS = {'revolver': (0, 0), 'pistol': (0, 1), 'tommy': (1, 0), 'shotgun': (1, 1)}
for name, (r, c) in CELLS.items():
    sl = (slice(r * h // 2, (r + 1) * h // 2), slice(c * w // 2, (c + 1) * w // 2))
    im = Image.fromarray(np.dstack([src[sl], a[sl]]).astype(np.uint8), 'RGBA')
    im = im.crop(Image.fromarray(a[sl]).getbbox())
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    im.save(REPO + f'art/guns/{name}.png')
    print(name, im.size)
