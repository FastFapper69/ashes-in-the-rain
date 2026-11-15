# The gunsmith screen's drawings (art_src 160 revolver closed/open, 161 shotgun closed/open + shells,
# 162 tommy stick/drum, 163 the burst behind). Each sheet holds the two versions one above the other at
# the same size; they are cut out, lined up on their left and top edges, and put on one canvas each so
# the two can be crossfaded in place.
import numpy as np
from PIL import Image
from scipy import ndimage
SRC = '/mnt/user-data/uploads/Ink and Lead/art_src/'
OUT = 'art/ui/gunsmith/'


def pieces(path):
    rgb = np.asarray(Image.open(path).convert('RGB')).astype(float)
    m = ndimage.binary_fill_holes(ndimage.binary_closing(rgb.mean(2) < 232, iterations=4))
    lab, n = ndimage.label(m)
    out = []
    for i in range(1, n + 1):
        mm = lab == i
        if mm.sum() < 400:
            continue
        ys, xs = np.where(mm)
        out.append((mm, xs.min(), ys.min(), xs.max(), ys.max(), mm.sum()))
    return rgb, out


def cut(rgb, mask, box):
    x0, y0, x1, y1 = box
    # paper showing through (trigger guard, the frame's window): the filled shape's white holes go clear
    white = (rgb.min(2) > 246) & mask
    lab, n = ndimage.label(white)
    if n:
        sizes = ndimage.sum(white, lab, range(1, n + 1))
        holes = np.isin(lab, [i + 1 for i in range(n) if sizes[i] > 700])
        mask = mask & ~ndimage.binary_dilation(holes, iterations=1)
    a = ndimage.gaussian_filter(ndimage.binary_erosion(mask, iterations=2).astype(float), 0.8)
    a = np.clip(a * 1.4, 0, 1)
    rgba = np.dstack([rgb, a * 255]).astype(np.uint8)
    return Image.fromarray(rgba).crop(box)


def pair(sheet, names, flip=False, width=1500, extra=None):
    rgb, ps = pieces(SRC + sheet)
    ps.sort(key=lambda p: -p[5])
    guns = sorted(ps[:2], key=lambda p: p[2])   # top, bottom
    # one canvas: the union of both boxes once each is moved onto the top one's left/top corner
    w = max(g[3] - g[1] for g in guns) + 140   # room for the lower one to move onto the upper
    h = max(g[4] - g[2] for g in guns) + 100
    ims = []
    for g in guns:
        im = cut(rgb, g[0], (g[1] - 70, g[2] - 50, g[1] - 70 + w, g[2] - 50 + h))
        ims.append(im)
    # line the lower one up on the upper by the rear half (stock and grip do not change between them)
    A = np.asarray(ims[0])[..., 3].astype(float); B = np.asarray(ims[1])[..., 3].astype(float)   # outlines: the shapes, not the shading
    rear = (slice(w // 2, w) if flip else slice(0, w // 2)) if flip else slice(0, w)
    best = (1e18, 0, 0)
    for dy in range(-30, 31, 2):
        for dx in range(-40, 41, 2):
            Bs = np.roll(np.roll(B, dy, 0), dx, 1)
            d = np.abs(A[40:-40, rear][:, 40:-40] - Bs[40:-40, rear][:, 40:-40]).mean()
            if d < best[0]:
                best = (d, dx, dy)
    for dy in range(best[2] - 2, best[2] + 3):
        for dx in range(best[1] - 2, best[1] + 3):
            Bs = np.roll(np.roll(B, dy, 0), dx, 1)
            d = np.abs(A[40:-40, rear][:, 40:-40] - Bs[40:-40, rear][:, 40:-40]).mean()
            if d < best[0]:
                best = (d, dx, dy)
    print(names[1], 'shifted', best[1], best[2])
    g = guns[1]
    ims[1] = cut(rgb, g[0], (g[1] - 70 - best[1], g[2] - 50 - best[2], g[1] - 70 - best[1] + w, g[2] - 50 - best[2] + h))
    guns[1] = (g[0], g[1] - best[1], g[2] - best[2], g[3], g[4], g[5])
    k = width / w
    for im, name in zip(ims, names):
        im = im.resize((width, int(h * k)), Image.LANCZOS)
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(OUT + name + '.png')
        print(name, im.size)
    if extra:   # the small loose pieces (shells), kept where they lie relative to the lower gun
        g = guns[1]
        small = [p for p in ps[2:] if p[2] > g[2]]
        if small:
            x0 = min(p[1] for p in small) - 8; y0 = min(p[2] for p in small) - 8
            x1 = max(p[3] for p in small) + 8; y1 = max(p[4] for p in small) + 8
            mm = np.zeros_like(small[0][0])
            for p in small:
                mm |= p[0]
            im = cut(rgb, mm, (x0, y0, x1, y1)).resize((int((x1 - x0) * k), int((y1 - y0) * k)), Image.LANCZOS)
            im.save(OUT + extra + '.png')
            # where it sits on the gun canvas
            print(extra, im.size, 'at', round((x0 - (g[1] - 70)) * k), round((y0 - (g[2] - 50)) * k))


pair('160.jpg', ['revolver', 'revolver_open'], flip=True, width=1300)
pair('161.jpg', ['shotgun', 'shotgun_open'], width=1600, extra='shells')
pair('162.jpg', ['tommy', 'tommy_drum'], width=1600)
bg = Image.open(SRC + '163.jpg').convert('RGB').resize((1600, 900), Image.LANCZOS)
bg.save(OUT + 'burst.jpg', quality=88)
