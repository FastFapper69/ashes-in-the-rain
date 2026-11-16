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

# 2026-11-16, the rest of the map set pieces (mapfx.gd):
key('196.jpg', 'neon_hotel.png', 900)      # the HOTEL sign over the alley
key('197.jpg', 'boxcars.png', 2048)        # three freight cars for the train yard's far track
key('198.jpg', 'rat.png', 400)             # a rat running left
key('199.jpg', 'sewer_water.png', 2048)    # the catacombs' water, a band seen side-on
key('200.jpg', 'wave.png', 1200)           # a wave breaking over the harbor quay


def neon_glow():
    # the lit tubes only: the hot pink of the drawing, for the additive glow that goes dark when it falls
    a = np.asarray(Image.open(OUT + 'neon_hotel.png')).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip((r - g - 60) / 60, 0, 1) * np.clip((r - 150) / 60, 0, 1) * (a[..., 3] / 255)
    rgba = np.dstack([np.full_like(r, 255), np.full_like(r, 120), np.full_like(r, 170), m * 200]).astype(np.uint8)
    Image.fromarray(rgba, 'RGBA').save(OUT + 'neon_hotel_glow.png')


neon_glow()
# (the water: Gemini drew a second, greener band under the first; keep the top one only)
_w = Image.open(OUT + 'sewer_water.png')
_w = _w.crop((0, 0, _w.width, 327))
_w.crop(_w.getbbox()).save(OUT + 'sewer_water.png')

# every set piece cut to a size in multiples of 4, so gen/basis_imports.py can make it Basis (not sheets.png)
for _n in ['el_span', 'girder', 'neon_hotel', 'neon_hotel_glow', 'boxcars', 'wave', 'sewer_water', 'rat']:
    _im = Image.open(OUT + _n + '.png')
    _im.crop((0, 0, _im.width - _im.width % 4, _im.height - _im.height % 4)).save(OUT + _n + '.png')
