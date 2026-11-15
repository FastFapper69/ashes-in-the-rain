# The nightmare gets worse (2026-11-15): four more rooms of the burning warehouse, each the old room
# gone wrong (art_src 186 handprints and the melted clock, 187 stairs into the void, 188 the wall of
# chained doors, 189 the harbour and the burning front page, whose garbled masthead is painted out and
# re-lettered "The Evening Ledger" here). Same cut as gen/process_fire.py, plus the fire spots the game
# burns live flames over (printed for main.gd FIRE_SPOTS).
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from scipy import ndimage
SRC = '/mnt/user-data/uploads/Ink and Lead/art_src/'
OUT = '/home/claude/repo/art/'
RIGHT_POST = 100


def masthead(im):
    arr = np.asarray(im).copy()
    x0, y0 = 1000, 350
    P = np.array([(x0 + a, y0 + b) for a, b in [(222, 88), (558, 126), (556, 208), (216, 168)]], np.int32)
    reg = np.zeros(arr.shape[:2], np.uint8)
    cv2.fillPoly(reg, [P], 255)
    ink = ((arr.mean(axis=2) < 150) & (reg > 0)).astype(np.uint8) * 255
    ink = cv2.dilate(ink, np.ones((5, 5), np.uint8))
    fixed = cv2.inpaint(arr[..., ::-1].copy(), ink, 9, cv2.INPAINT_TELEA)[..., ::-1].astype(float)
    W, H = 800, 160
    t = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(t)
    f = ImageFont.truetype('/usr/share/texmf/fonts/opentype/public/tex-gyre/texgyrebonum-bold.otf', 70)
    txt = 'The Evening Ledger'
    bb = d.textbbox((0, 0), txt, font=f)
    tw = bb[2] - bb[0]
    d.text(((W - tw) // 2, 40), txt, font=f, fill=255)
    s = 340 / tw
    t = t.resize((int(W * s), int(H * s)), Image.LANCZOS).rotate(-6.5, resample=Image.BICUBIC, expand=True)
    t = t.filter(ImageFilter.GaussianBlur(0.6))
    L = Image.new('L', im.size, 0)
    L.paste(t, (x0 + 392 - t.width // 2, y0 + 148 - t.height // 2))
    k = np.asarray(L).astype(float)[..., None] / 255 * 0.93
    return Image.fromarray((fixed * (1 - k) + np.array([28, 20, 16.]) * k).astype(np.uint8))


for name, f in [('fire_d', '186.jpg'), ('fire_e', '187.jpg'), ('fire_f', '188.jpg'), ('fire_g', '189.jpg')]:
    im = Image.open(SRC + f).convert('RGB')
    if im.size != (2752, 1536):
        im = im.resize((2752, 1536), Image.LANCZOS)
    if name == 'fire_g':
        im = masthead(im)
    rgb = np.asarray(im)[:, :-RIGHT_POST]
    h, w = rgb.shape[:2]
    Image.fromarray(np.dstack([rgb, np.full((h, w), 255, np.uint8)])).save(OUT + f'street/{name}.png')
    a = rgb.astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    fire = np.clip((r - b - 60) / 70, 0, 1) * np.clip((r - 150) / 70, 0, 1)
    fire = ndimage.grey_opening(fire, size=(3, 3))
    glow = np.asarray(Image.fromarray((fire * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(float) / 255
    glow = np.maximum(fire, glow * 0.9)
    Image.fromarray(np.dstack([a, glow * 255]).astype(np.uint8), 'RGBA').resize((w // 2, h // 2), Image.LANCZOS).save(OUT + f'street/{name}_lit.png')
    solid = Image.new('L', (w // 2, h // 2), 255)
    Image.merge('RGBA', [solid] * 4).save(OUT + f'street/{name}_solid.png')
    m = ndimage.binary_closing(fire > 0.45, iterations=12)   # one fire is one blob
    lab, n = ndimage.label(m)
    spots = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        area = int((lab[sl] == i + 1).sum())
        if area < 9000:
            continue
        y0, y1, x0, x1 = sl[0].start, sl[0].stop, sl[1].start, sl[1].stop
        spots.append((area, [round((x0 + x1) / 2 / w, 3), round(y1 / h, 3), round((y1 - y0) / h, 3), round((x1 - x0) / w, 3)]))
    spots = [s for _, s in sorted(spots, key=lambda t: -t[0])[:8]]
    print(f'\t"{name}": {spots},')
