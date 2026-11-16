import sys, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
def rgba(path):
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.int16)
    mn = im.min(axis=2)
    near = mn >= 236                        # paper-white background
    lab, n = ndi.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border))
    # enclosed pockets of pure white (between limbs) are background too
    strict = mn >= 249
    l2, n2 = ndi.label(strict & ~bg)
    sizes = ndi.sum(strict & ~bg, l2, range(1, n2 + 1))
    big = [i + 1 for i, s in enumerate(sizes) if s > 500]
    bg |= np.isin(l2, big)
    a = np.where(bg, 0, 255).astype(np.uint8)
    a = np.minimum(a, np.clip((250 - mn) * 12, 0, 255)).astype(np.uint8)   # soften the fringe
    return np.dstack([im.astype(np.uint8), a])
def boxes(img, grow=9, minarea=6000):
    m = ndi.binary_dilation(img[:, :, 3] > 40, iterations=grow)
    lab, n = ndi.label(m)
    out = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        area = (lab[sl] == i + 1).sum()
        if area >= minarea: out.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop, i + 1))
    return sorted(out, key=lambda b: (round(b[1] / 300), b[0])), lab
if __name__ == '__main__':
    for k, p in enumerate(sys.argv[1:]):
        img = rgba(p); bx, lab = boxes(img)
        dbg = Image.fromarray(img).convert('RGBA'); bgc = Image.new('RGBA', dbg.size, (90, 140, 200, 255)); bgc.alpha_composite(dbg)
        d = ImageDraw.Draw(bgc)
        for j, b in enumerate(bx): d.rectangle(b[:4], outline=(255, 255, 0), width=4); d.text((b[0] + 6, b[1] + 6), str(j), fill=(255, 255, 0), font_size=44)
        bgc.resize((bgc.width // 2, bgc.height // 2)).save(f'dbg{k}.png'); print(p, dbg.size, [(j,) + b[:4] for j, b in enumerate(bx)])
