# Turns the Gemini pictures in art_src into game art: street segments with the white sky cut out,
# the repeated pair of water towers removed, the right-hand pilaster trimmed (so neighbours share one),
# plus a glow layer of the lit windows and signs (drawn additively, so they shine through the night);
# interiors copied in as room back walls.
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

import os
from paths import SRC   # (art_src, with a trailing slash)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'art') + os.sep
# segment name: (file, right pilaster to trim, has the tower pair at top left)
STREET = {
    'alley': ('20.jpg', 140, True), 'bluenote': ('21.png', 140, True), 'warehouse': ('23.png', 140, True),
    'laundry': ('24.png', 140, True), 'subway': ('25.png', 60, True), 'church': ('26.png', 60, False),
    'market': ('27.png', 130, False), 'deadend': ('28.png', 130, False),
    # chapter II, the docks: a frame down both edges, trimmed off both (the left one in main.gd)
    'pier17': ('42.png', 134, False), 'cranes': ('43.png', 134, False), 'shipping': ('44.png', 134, False),
    'quay': ('45.png', 134, False), 'harbor': ('46.png', 134, False),
    # chapter III, underground: the subway, its tunnels, and the train yard up in the rain
    'platform': ('66.png', 134, False), 'tunnel': ('67.png', 134, False), 'yard': ('68.png', 134, False),
    # the modular kits (2026-11-14): flat side-on, both edges the same joint, nothing runs into the depth over the floor
    'station14': ('103.png', 134, False), 'bowery': ('104.png', 134, False), 'walkway': ('105.png', 134, False),
    'pump': ('106.png', 134, False), 'tunnel_lo': ('67.png', 134, False),
    'signal': ('115.png', 134, False), 'arches': ('116.png', 134, False),
    # chapter I, under the rooftops: the facade fills the picture to a straight cornice along its top edge
    'tenrow_a': ('111.png', 125, False), 'tenrow_b': ('112.png', 125, False),
    'tenrow_c': ('119.png', 125, False), 'tenrow_d': ('120.png', 125, False),
    'sheds': ('122.png', 125, False),
    # variants of the kits (art_src 164-168): same floor, rails, edges and lamps, other details
    # (a variant must differ from its kit over at least a quarter of the picture above the floor: 164, 166, 168
    # were too close and were redrawn as 172, 175, 173; ch II: 174, 176, 177, 178 replaced 169-171)
    'walkway_b': ('172.jpg', 134, False), 'signal_b': ('165.jpg', 134, False), 'arches_b': ('175.jpg', 134, False),
    'yard_b': ('167.jpg', 134, False), 'tunnel_b': ('173.jpg', 134, False), 'tunnel_lo_b': ('173.jpg', 134, False),
    'sheds_b': ('177.jpg', 125, False), 'pier17_b': ('176.jpg', 134, False), 'shipping_b': ('174.jpg', 134, False), 'quay_b': ('178.jpg', 134, False),
    'laundry_b': ('179.jpg', 140, False), 'alley_b': ('180.jpg', 140, False), 'warehouse_b': ('181.jpg', 140, False),
    'church_b': ('182.jpg', 60, False), 'subway_b': ('183.jpg', 60, False), 'market_b': ('184.jpg', 130, False), 'market_c': ('185.jpg', 130, False),
    # a third of the two chapter III maps that had only two drawings (2026-11-15)
    'yard_c': ('190.jpg', 134, False), 'tunnel_c': ('191.jpg', 134, False),
    # chapter I modular street kit (2026-11-16): flat fronts, the same dark party wall down both edges (any order joins),
    # each with something to play with: an awning beside a fire escape, a hydrant, beer barrels, a steam pipe
    'hk_tailor': ('233.jpg', 0, False), 'hk_grocery': ('234.jpg', 0, False), 'hk_saloon': ('235.jpg', 0, False), 'hk_laundry': ('236.jpg', 0, False),   # (228-231 with the things painted in; these without them: gen/street_props.py)
}
KIT = {'yard_c': 'yard', 'tunnel_c': 'tunnel', 'walkway_b': 'walkway', 'signal_b': 'signal', 'arches_b': 'arches', 'yard_b': 'yard', 'tunnel_b': 'tunnel', 'tunnel_lo_b': 'tunnel_lo',
       'sheds_b': 'sheds', 'pier17_b': 'pier17', 'shipping_b': 'shipping', 'quay_b': 'quay',
       'laundry_b': 'laundry', 'alley_b': 'alley', 'warehouse_b': 'warehouse', 'church_b': 'church', 'subway_b': 'subway', 'market_b': 'market', 'market_c': 'market'}
# measured on the whole picture, before the right frame comes off: scaled to the trimmed one below
FULL = 3168.0
def _sc(r, trim=134): k = FULL / (FULL - trim); return (r[0] * k, r[1], r[2] * k, r[3])
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
# the deep views (see SEGMENT_DEEP in main.gd): their lit windows are left to the drawing, since
# that part slides against the wall and a fixed glow would come apart from it
DEEP = {'alley': [(0.465, 0.22, 0.11, 0.64)], 'bluenote': [(0.665, 0.3, 0.16, 0.38)], 'warehouse': [(0.45, 0.32, 0.2, 0.56)],
        'laundry': [(0.455, 0.32, 0.1, 0.54)], 'subway': [(0.5, 0.25, 0.095, 0.63)], 'church': [(0.432, 0.4, 0.125, 0.4)],
        'market': [(0.54, 0.42, 0.13, 0.46)], 'deadend': [(0.485, 0.4, 0.07, 0.46)],
        'pier17': [_sc((0.45, 0.25, 0.24, 0.63))], 'cranes': [_sc((0.42, 0.42, 0.19, 0.48))], 'shipping': [_sc((0.47, 0.3, 0.075, 0.6))],
        'quay': [_sc((0.16, 0.52, 0.14, 0.34))], 'harbor': [_sc((0.68, 0.4, 0.24, 0.46))],
        'platform': [_sc((0.1, 0.31, 0.13, 0.38))], 'tunnel': [_sc((0.79, 0.33, 0.12, 0.38))], 'yard': [_sc((0.47, 0.45, 0.13, 0.3))]}
# parts of a drawing taken out of it to come alive in the game (the crate on the crane's chains)
CUT = {'cranes': [_sc((0.37, 0.2, 0.075, 0.255))]}
ROOMS = {'laundry': '29.png', 'warehouse': '30.png', 'tenement': '31.png', 'club': '245.jpg', 'hold': '47.png', 'office': '48.png', 'catacombs': '69.png', 'cityhall': '73.png'}


def sky_alpha(rgb, pockets=False):
    a = rgb.astype(int)
    white = (a.min(2) > 222) & ((a.max(2) - a.min(2)) < 22)
    lab, n = ndimage.label(white)
    top = set(np.unique(lab[0])) - {0}
    if pockets:   # sky shut in by rigging, wires and broken roofs: any big white patch high up
        h = rgb.shape[0]
        idx = np.arange(1, n + 1)
        size = ndimage.sum(white, lab, idx)
        cy = ndimage.mean(np.broadcast_to(np.arange(h)[:, None], white.shape), lab, idx)
        top |= {int(i) for i, sz, y in zip(idx, size, cy) if sz > 400 and y < h * 0.62}
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


ONLY = sys.argv[1:]
for name, (f, trim, towers) in STREET.items():
    if ONLY and name not in ONLY:
        continue
    rgb = np.asarray(Image.open(SRC + f).convert('RGB'))
    if rgb.shape[:2] != (1344, 3168):   # Gemini sometimes hands back another aspect: stretched back onto the kit's frame
        rgb = np.asarray(Image.fromarray(rgb).resize((3168, 1344), Image.LANCZOS))
    alpha = sky_alpha(rgb, f in ('42.png', '43.png', '44.png', '45.png', '46.png', '68.png', '167.jpg', '190.jpg', '174.jpg', '176.jpg', '178.jpg')).copy()
    roof = remove_towers(rgb, alpha) if towers else -1
    rgb, alpha = rgb[:, :rgb.shape[1] - trim], alpha[:, :alpha.shape[1] - trim]
    for (x, y, w, h) in CUT.get(name, []):
        hh, ww = alpha.shape
        sl = (slice(int(y * hh), int((y + h) * hh)), slice(int(x * ww), int((x + w) * ww)))
        piece = np.dstack([rgb[sl], alpha[sl]])
        Image.fromarray(piece).save(OUT + f'props/{name}_cut.png')
        alpha[sl] = 0
    im = Image.fromarray(np.dstack([rgb, alpha]))
    im.save(OUT + f'street/{name}.png')
    keep = alpha.copy()
    hh, ww = keep.shape
    for (x, y, w, h) in DEEP.get(name, []):
        keep[int(y * hh):int((y + h) * hh), int(x * ww):int((x + w) * ww)] = 0
    lit, frac = lit_layer(rgb, keep)
    lit.save(OUT + f'street/{name}_lit.png')
    for k, box in enumerate(NEONS.get(name, [])):
        nm, at = neon_mask(rgb, box, box[4])
        nm.save(OUT + f'street/{name}_neon{k}.png')
        print('  neon', k, nm.size, 'at', at)
    print(name, im.size, 'roof', roof, 'sky', round(float((alpha < 128).mean()), 3), 'lit', round(frac, 4))

for style, f in ROOMS.items():
    if ONLY and style not in ONLY:
        continue
    Image.open(SRC + f).convert('RGB').save(OUT + f'rooms/{style}.png')
    print('room', style)


# a brick pier cut from the alley drawing's own left edge: stood over every join between two
# drawings, so they meet at a firewall instead of a seam
_a = Image.open(OUT + 'street/alley.png').convert('RGBA')
_al = np.asarray(_a)[..., 3]
_top = int(np.argmax((_al[:, 10:110] > 128).mean(1) > 0.9))
_a.crop((6, _top, 118, _a.height)).save(OUT + 'street/pier.png')


# where blood can land on each drawing: the walls, not the sky between roofs, not the deep views
# (they slide), and inside railings and fences only on the dark iron itself. Half size, alpha only.
FENCES = {
    'church': [(0.0, 0.72, 0.42, 0.18), (0.6, 0.78, 0.38, 0.12)], 'subway': [(0.49, 0.68, 0.12, 0.2), (0.6, 0.78, 0.38, 0.11)],
    'bluenote': [(0.65, 0.6, 0.15, 0.29)], 'laundry': [(0.875, 0.66, 0.08, 0.24)], 'deadend': [(0.47, 0.6, 0.09, 0.3), (0.85, 0.6, 0.11, 0.3)],
    'market': [(0.5, 0.7, 0.16, 0.2)], 'warehouse': [(0.43, 0.62, 0.25, 0.28)], 'alley': [],
    'pier17': [_sc((0.045, 0.72, 0.40, 0.18))], 'harbor': [_sc((0.045, 0.55, 0.2, 0.33))],
    'yard': [_sc((0.77, 0.55, 0.18, 0.25))],
}
for name in STREET:
    if ONLY and name not in ONLY:
        continue
    im = Image.open(OUT + f'street/{name}.png').convert('RGBA')
    a = np.asarray(im).astype(float)
    hh, ww = a.shape[:2]
    solid = (a[..., 3] > 128).astype(np.uint8) * 255
    lum = a[..., :3].mean(2)
    for (x, y, w, h) in FENCES.get(name, FENCES.get(KIT.get(name, ''), [])):
        sl = (slice(int(y * hh), int((y + h) * hh)), slice(int(x * ww), int((x + w) * ww)))
        solid[sl] = np.where(lum[sl] < 45, 255, 0)
    for (x, y, w, h) in DEEP.get(name, []):
        solid[int(y * hh):int((y + h) * hh), int(x * ww):int((x + w) * ww)] = 0
    m = Image.fromarray(solid).resize((ww // 2, hh // 2), Image.BILINEAR)
    Image.merge('RGBA', [Image.new('L', m.size, 255)] * 3 + [m]).save(OUT + f'street/{name}_solid.png')
print('solid masks')
