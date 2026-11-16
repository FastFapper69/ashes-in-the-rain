import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from seg import rgba
U = '/mnt/user-data/uploads/'; OUT = '/home/claude/proto/assets/'
F = 512
def crop(img, box, erase=()):
    a = img.copy()
    for (x0, y0, x1, y1) in erase: a[y0:y1, x0:x1, 3] = 0
    c = a[box[1]:box[3], box[0]:box[2]]
    ys, xs = np.nonzero(c[:, :, 3] > 40)
    c = c[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return Image.fromarray(c, 'RGBA')
def scaled(im, s): return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
def put_feet(sheet, col, row, im, s):
    im = scaled(im, s); a = np.asarray(im)[:, :, 3]
    low = a[int(a.shape[0] * 0.72):]; xs = np.nonzero(low > 40)[1]; cx = (xs.min() + xs.max()) / 2   # stand on the middle of the feet
    x = round(col * F + 256 - cx); y = row * F + 452 - im.height
    cell = Image.new('RGBA', (F, F), (0, 0, 0, 0)); cell.alpha_composite(im, (max(0, x - col * F), max(0, y - row * F)), (max(0, col * F - x), 0))
    sheet.alpha_composite(cell, (col * F, row * F))
def put_centre(sheet, col, row, im, s, bottom=None):
    im = scaled(im, s)
    if im.width > F - 4: im = scaled(im, (F - 4) / im.width)
    x = (F - im.width) // 2; y = (F - im.height) // 2 if bottom is None else bottom - im.height
    sheet.alpha_composite(im, (col * F + x, row * F + y))

# ---------- player ----------
P = rgba(U + '546a48a8-image.jpg'); S = 0.85
aim = crop(P, (100, 597, 524, 1014)); run = [crop(P, (497, 74, 843, 504)), crop(P, (843, 76, 1200, 501)), crop(P, (1180, 77, 1560, 503))]
jump = crop(P, (545, 541, 872, 1002)); fall = crop(P, (862, 565, 1252, 1004))
dive1 = crop(P, (1285, 636, 1870, 925), erase=[(1590, 780, 2576, 1000), (1285, 540, 2576, 636)])
dive2 = crop(P, (1890, 640, 2576, 880), erase=[(1890, 540, 2576, 640), (1890, 870, 2576, 1000), (2150, 640, 2330, 690), (2380, 640, 2576, 700), (2300, 790, 2576, 880)])
slide = crop(P, (2030, 217, 2504, 502))
sheet = Image.new('RGBA', (8 * F, 4 * F), (0, 0, 0, 0))
for i in range(4): put_feet(sheet, i, 0, aim, S)
for i, k in enumerate([0, 1, 2, 1, 0, 1, 2, 1]): put_feet(sheet, i, 1, run[k], S)
for i in range(2): put_feet(sheet, i, 2, jump, S); put_feet(sheet, i + 2, 2, fall, S)
for i in range(6): put_centre(sheet, i, 3, dive1, 0.82)
for i in (6, 7): put_centre(sheet, i, 3, slide, S, bottom=316)
sheet.save(OUT + 'player_sheet.png'); sheet.resize((1024, 512)).save('chk_player.png')

# ---------- enemies ----------
E = rgba(U + 'e16b423b-image.jpg')
tommy = crop(E, (104, 88, 445, 510)); walk = [crop(E, (1000, 88, 1251, 508)), crop(E, (1259, 82, 1547, 510))]
shotgun = crop(E, (1010, 590, 1338, 1003)); tumble = crop(E, (2083, 57, 2469, 385)); lying = crop(E, (2024, 395, 2440, 515))
sheet = Image.new('RGBA', (8 * F, 6 * F), (0, 0, 0, 0))
for r0, stand, runs in ((0, tommy, walk), (3, shotgun, [shotgun, shotgun])):
    for i in range(4): put_feet(sheet, i, r0, stand, S)
    for i in range(8): put_feet(sheet, i, r0 + 1, runs[(i // 2) % 2], S)
    for i in range(2): put_feet(sheet, i, r0 + 2, runs[0], S)
    for i in (2, 3): put_centre(sheet, i, r0 + 2, tumble, S)
    for i in (4, 5): put_centre(sheet, i, r0 + 2, lying, S)
sheet.save(OUT + 'enemy_sheet.png'); sheet.resize((1024, 768)).save('chk_enemy.png')

# ---------- props: the crate. Its front face lands on the 256 px square at (32, 96) ----------
props = Image.new('RGBA', (1024, 384), (0, 0, 0, 0))
props.alpha_composite(Image.fromarray(E[1091:1403, 114:449], 'RGBA'), (22, 37)); props.save(OUT + 'props_sheet.png')

# ---------- backgrounds ----------
B = np.asarray(Image.open(U + '12235e62-image.jpg').convert('RGB'))
def strip(box, w, cut_sky):
    c = B[box[1]:box[3], box[0]:box[2]].astype(np.int16)
    a = np.full(c.shape[:2], 255, np.uint8)
    if cut_sky:
        near = c.min(axis=2) >= 232; lab, n = ndi.label(near)
        sizes = ndi.sum(near, lab, range(1, n + 1)); top = set(np.unique(lab[0])) - {0}
        a[np.isin(lab, list(top) + [i + 1 for i, z in enumerate(sizes) if z > 250])] = 0   # sky showing through gaps and between wires
        a = ndi.minimum_filter(a, 3)
    im = Image.fromarray(np.dstack([c.astype(np.uint8), a]), 'RGBA')
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
far = Image.new('RGBA', (4096, 1366), (16, 16, 19, 255)); s = strip((118, 134, 2458, 362), 4096, False)
top = np.asarray(s)[2:6].mean(axis=(0, 1)).astype(int); far.paste(tuple(int(v) for v in top[:3]) + (255,), (0, 0, 4096, 345)); far.alpha_composite(s, (0, 341)); far.save(OUT + 'bg_manhattan_far.png')
mid = Image.new('RGBA', (4096, 1366), (0, 0, 0, 0)); s = strip((118, 458, 2458, 714), 4096, True)
mid.alpha_composite(s, (0, 540)); mid.paste((12, 12, 14, 255), (0, 540 + s.height - 2, 4096, 1366)); mid.save(OUT + 'bg_rooftop_mid.png')
wall = Image.new('RGBA', (4096, 910), (0, 0, 0, 0)); s = strip((118, 802, 2458, 1056), 4096, True)
y0 = 800 - s.height; wall.alpha_composite(s, (0, y0))
wall.paste((20, 21, 24, 255), (0, 800, 4096, 850)); wall.paste((234, 230, 223, 255), (0, 846, 4096, 849)); wall.paste((8, 8, 10, 255), (0, 849, 4096, 910)); wall.paste((8, 8, 10, 255), (0, 796, 4096, 801))
wall.save(OUT + 'bg_street_wall.png')
for n in ('bg_manhattan_far', 'bg_rooftop_mid', 'bg_street_wall'): print(n, Image.open(OUT + n + '.png').size)

# ---------- ground: a thick, textured street slab cut from the rooftop strip (stone top, brick face) ----------
wall = Image.open(OUT + 'bg_street_wall.png').convert('RGBA')
def band(box, h, y):
    t = Image.fromarray(B[box[1]:box[3], box[0]:box[2]], 'RGB').convert('RGBA'); t = t.resize((round(t.width * h / t.height * 0.6), h), Image.LANCZOS)
    x, k = 0, 0
    while x < 4096:
        wall.paste(t if k % 2 == 0 else t.transpose(Image.FLIP_LEFT_RIGHT), (x, y)); x += t.width; k += 1
band((1190, 1244, 1550, 1290), 50, 800)      # the surface people stand on: 10.55 m to 11.2 m
band((770, 1318, 1180, 1392), 60, 850)      # the face of the slab below it
wall.paste((8, 8, 10, 255), (0, 795, 4096, 801)); wall.paste((234, 230, 223, 255), (0, 847, 4096, 850)); wall.paste((8, 8, 10, 255), (0, 850, 4096, 854))
wall.save(OUT + 'bg_street_wall.png'); wall.crop((0, 600, 1400, 910)).save('chk_ground.png')

# ---------- effects ----------
X = rgba(U + 'de41547e-image.jpg')
parts = {'blam': (103, 95, 502, 377), 'krakoom': (508, 97, 923, 382), 'rat': (935, 102, 1416, 246), 'clink': (1432, 90, 1723, 250),
         'flash': (192, 453, 436, 633), 'casing': (511, 601, 617, 713), 'star': (1098, 556, 1257, 731), 'splat': (1711, 458, 1939, 718), 'drip': (1944, 462, 2223, 650)}
fx = Image.new('RGBA', (2048, 512), (0, 0, 0, 0)); x = y = rowh = 0; table = {}
for k, b in parts.items():
    im = crop(X, b)
    if x + im.width > 2048: x = 0; y += rowh + 4; rowh = 0
    fx.alpha_composite(im, (x, y)); table[k] = [x, y, im.width, im.height]; x += im.width + 4; rowh = max(rowh, im.height)
fx.save(OUT + 'fx_sheet.png'); fx.resize((1024, 256)).save('chk_fx.png')
import json; open('/home/claude/proto/src/fx_table.js', 'w').write('// where each effect sits on assets/fx_sheet.png: [x, y, w, h]\nconst FXR = ' + json.dumps(table) + ';\n'); print(table)
