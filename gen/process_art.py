# Turns the Gemini pictures in art_src into game art: street segments with the white sky cut out,
# the repeated pair of water towers removed, the right-hand pilaster trimmed (so neighbours share one),
# plus a glow layer of the lit windows and signs (drawn additively, so they shine through the night);
# interiors copied in as room back walls.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = '/mnt/user-data/uploads/Ink and Lead/art_src/'
OUT = '/home/claude/repo/art/'
# segment name: (file, right pilaster to trim, has the tower pair at top left)
STREET = {
    'alley': ('20.jpg', 140, True), 'bluenote': ('21.png', 140, True), 'warehouse': ('23.png', 140, True),
    'laundry': ('24.png', 140, True), 'subway': ('25.png', 60, True), 'church': ('26.png', 60, False),
    'market': ('27.png', 130, False), 'deadend': ('28.png', 130, False),
}
# neon and lit signs on the segments: (x0, x1, y0, y1) as fractions of the drawing, and 'letters'
# (only the bright strokes glow) or 'wash' (the whole board is lit by lamps on it)
NEONS = {
    'bluenote': [(0.232, 0.258, 0.335, 0.57, 'letters'), (0.128, 0.264, 0.565, 0.648, 'letters')],
    'warehouse': [(0.718, 0.822, 0.582, 0.668, 'letters')],
    'church': [(0.688, 0.727, 0.385, 0.705, 'letters'), (0.608, 0.737, 0.035, 0.285, 'wash')],
    'market': [(0.378, 0.422, 0.055, 0.55, 'letters'), (0.318, 0.512, 0.535, 0.64, 'letters')],
    'deadend': [(0.528, 0.582, 0.455, 0.675, 'letters')],   # the rooftop JAZZ stays dead
    'subway': [(0.045, 0.107, 0.56, 0.63, 'letters'), (0.198, 0.228, 0.57, 0.63, 'letters')],
}
ROOMS = {'laundry': '29.png', 'warehouse': '30.png', 'tenement': '31.png', 'club': '32.png', 'cellar': '33.png'}


def sky_alpha(rgb):
    a = rgb.astype(int)
    white = (a.min(2) > 222) & ((a.max(2) - a.min(2)) < 22)
    lab, n = ndimage.label(white)
    top = set(np.unique(lab[0])) - {0}
    sky = np.isin(lab, list(top))
    sky = ndimage.binary_opening(sky, iterations=1)
    alpha = np.where(sky, 0, 255).astype(np.uint8)
    # soften the cut by a pixel so the ink line keeps its edge but no white halo remains
    alpha = np.asarray(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7)))
    return alpha


def remove_towers(rgb, alpha):
    h, w = alpha.shape
    x0, x1 = 150, 700
    roof = 0
    for y in range(int(h * 0.4)):
        if (alpha[y, x0:x1] > 128).mean() > 0.85:
            roof = y
            break
    alpha[:max(0, roof - 2), x0:x1] = 0
    return roof


def lit_layer(rgb, alpha):
    """Warm lit windows and lamps: amber, bright, clearly warmer than the grey ink around them.
    Kept at half size (it is only a soft glow) to spare the phone's memory."""
    a = rgb.astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    warm = np.clip((r - b - 45) / 60, 0, 1) * np.clip((r - 120) / 80, 0, 1) * (alpha > 128)
    warm = ndimage.grey_opening(warm, size=(3, 3))          # drop single stray pixels in the brickwork
    glow = np.asarray(Image.fromarray((warm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.5))).astype(float) / 255
    glow = np.maximum(warm, glow * 0.8)
    col = np.dstack([a, glow * 255]).astype(np.uint8)
    im = Image.fromarray(col, 'RGBA')
    return im.resize((im.width // 2, im.height // 2), Image.LANCZOS), float((warm > 0.5).mean())


def neon_mask(rgb, box, mode):
    """The strokes of a sign that light up, plus a soft bloom round them, cut to the sign's box."""
    h, w = rgb.shape[:2]
    x0, x1, y0, y1 = int(box[0] * w), int(box[1] * w), int(box[2] * h), int(box[3] * h)
    reg = rgb[y0:y1, x0:x1].astype(float)
    v = reg.max(2)
    if mode == 'wash':
        m = np.clip((v - 60) / 140, 0, 1) * 0.6
    else:
        lo, hi = np.percentile(v, 62), np.percentile(v, 97)
        m = np.clip((v - lo) / max(hi - lo, 1), 0, 1) ** 1.5
    pad = 24
    big = np.zeros((m.shape[0] + 2 * pad, m.shape[1] + 2 * pad))
    big[pad:-pad, pad:-pad] = m
    bloom = np.asarray(Image.fromarray((big * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9))).astype(float) / 255
    out = np.clip(np.maximum(big, bloom * 1.4), 0, 1)
    a = (out * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([np.full_like(a, 255)] * 3 + [a]), 'RGBA')
    return im, (x0 - pad, y0 - pad)


for name, (f, trim, towers) in STREET.items():
    rgb = np.asarray(Image.open(SRC + f).convert('RGB'))
    alpha = sky_alpha(rgb).copy()
    roof = remove_towers(rgb, alpha) if towers else -1
    rgb, alpha = rgb[:, :rgb.shape[1] - trim], alpha[:, :alpha.shape[1] - trim]
    im = Image.fromarray(np.dstack([rgb, alpha]))
    im.save(OUT + f'street/{name}.png')
    lit, frac = lit_layer(rgb, alpha)
    lit.save(OUT + f'street/{name}_lit.png')
    for k, box in enumerate(NEONS.get(name, [])):
        nm, at = neon_mask(rgb, box, box[4])
        nm.save(OUT + f'street/{name}_neon{k}.png')
        print('  neon', k, nm.size, 'at', at)
    print(name, im.size, 'roof', roof, 'sky', round(float((alpha < 128).mean()), 3), 'lit', round(frac, 4))

for style, f in ROOMS.items():
    Image.open(SRC + f).convert('RGB').save(OUT + f'rooms/{style}.png')
    print('room', style)
