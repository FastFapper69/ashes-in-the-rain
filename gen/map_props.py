# Set pieces drawn for the maps (2026-11-16), keyed out of Gemini's flat green:
#   art_src 192 -> art/props/el_span.png   one span of the elevated railway over Back Streets
#   art_src 193 -> art/props/sheets.png    four bed sheets on a line, in the laundry
import numpy as np
from PIL import Image
from scipy import ndimage
SRC = '/mnt/user-data/uploads/Ink and Lead/art_src/'
OUT = '/home/claude/repo/art/props/'


def key(f, out, max_w):
    a = np.asarray(Image.open(SRC + f).convert('RGB')).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    green = np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1)   # how far a pixel is the backdrop
    alpha = 1 - green
    alpha = ndimage.grey_opening(alpha, size=(3, 3))
    # take the green out of the edges that remain
    spill = np.maximum(g - np.maximum(r, b), 0)
    a[..., 1] -= spill * (1 - alpha * 0.5)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    im = Image.fromarray(rgba, 'RGBA')
    bb = im.getbbox()
    im = im.crop(bb)
    if im.width > max_w:
        im = im.resize((max_w, int(im.height * max_w / im.width)), Image.LANCZOS)
    im.save(OUT + out)
    print(out, im.size, 'bbox', bb)


key('192.jpg', 'el_span.png', 2048)
key('193.jpg', 'sheets.png', 2048)


# art_src 195 -> art/props/girder.png: the steel girder across the last train's tunnel, end-on, on its hanger
key('195.jpg', 'girder.png', 1536)
