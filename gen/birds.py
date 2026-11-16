# Cuts the Gemini pigeon sheet (art_src/36.png) into single frames with the white taken out.
# Order on the sheet: stand, peck, walk, crouch, wings up | wings up, glide, wings up, flat glide.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
from paths import SRC, REPO
src = np.asarray(Image.open(SRC + '36.png').convert('RGB')).astype(int)
ink = src.min(2) < 225
lab, n = ndimage.label(ndimage.binary_dilation(ink, iterations=12))
boxes = [b for b in ndimage.find_objects(lab) if (b[0].stop - b[0].start) * (b[1].stop - b[1].start) > 20000]
boxes.sort(key=lambda b: (b[0].start > src.shape[0] * 0.45, b[1].start))
NAMES = ['stand', 'peck', 'walk', 'crouch', 'up1', 'up2', 'glide', 'up3', 'flat']
for name, b in zip(NAMES, boxes):
    rgb = src[b].astype(np.uint8)
    white = np.clip((rgb.min(2).astype(float) - 200) / 40, 0, 1)   # soft key on the white paper
    a = ((1 - white) * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([rgb, a]), 'RGBA')
    im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
    im.save(REPO + f'art/birds/{name}.png')
    print(name, im.size)
