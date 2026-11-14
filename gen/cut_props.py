"""Cut a Gemini prop sheet (props side by side on white) into separate transparent PNGs.
usage: cut_props.py sheet.jpg name1 name2 ... -> art/props/<name>.png, left to right."""
import sys, numpy as np
from PIL import Image, ImageFilter

# Gemini sometimes leaves a smear touching a prop: the part of the cut to keep (x0, y0, x1, y1, 0..1)
KEEP = {"cable_spool": (0.2, 0.0, 1.0, 1.0)}


def cut(sheet, names, out_dir):
    im = Image.open(sheet).convert('RGB')
    a = np.asarray(im).astype(float)
    # how far from paper white: the props are inked, the paper is near 255 everywhere
    d = 255 - a.min(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)
    ink = np.clip((np.maximum(d, sat * 1.5) - 14) / 30, 0, 1)
    solid = Image.fromarray((ink * 255).astype('uint8')).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(5))
    mask = np.asarray(solid) > 40
    # fill each prop's interior: anything enclosed by ink counts as the prop (white sheets, linen)
    from scipy import ndimage
    filled = ndimage.binary_fill_holes(mask)
    holes, nh = ndimage.label(filled & ~mask)
    bright = a.min(axis=2)
    for h in range(1, nh + 1):   # a hole of bare paper (under a table, between legs) stays see-through
        px = bright[holes == h]
        if px.mean() > 236 and px.std() < 12:
            filled[holes == h] = False
    mask = filled
    lab, n = ndimage.label(mask)
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    keep = [i + 1 for i in np.argsort(sizes)[::-1][:len(names)]]
    boxes = []
    for k in keep:
        ys, xs = np.where(lab == k)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, k))
    boxes.sort()
    alpha_full = np.clip(ink * 1.4, 0, 1)
    for (x0, y0, x1, y1, k), name in zip(boxes, names):
        region = ndimage.binary_dilation(lab == k, iterations=3) & (ndimage.binary_dilation(mask, iterations=3))
        al = np.where(region, np.maximum(alpha_full, ndimage.binary_erosion(region, iterations=6)), 0)
        al = np.asarray(Image.fromarray((al * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(0.8)))
        blobs, nb = ndimage.label(ndimage.binary_opening(al > 150, iterations=7))   # only the prop itself, no stray scraps beside it
        if nb > 1:
            big = 1 + int(np.argmax(ndimage.sum(np.ones_like(al), blobs, range(1, nb + 1))))
            al = np.where(ndimage.binary_dilation(blobs == big, iterations=9), al, 0).astype('uint8')
        rgba = np.dstack([a.astype('uint8'), al])
        crop = Image.fromarray(rgba, 'RGBA').crop((x0, y0, x1, y1))
        if name in KEEP:
            kx0, ky0, kx1, ky1 = KEEP[name]
            w, h = crop.size
            crop = crop.crop((int(kx0 * w), int(ky0 * h), int(kx1 * w), int(ky1 * h)))
        crop = crop.crop(crop.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox())
        crop.save(f'{out_dir}/{name}.png')
        print(name, crop.size)

if __name__ == '__main__':
    cut(sys.argv[1], sys.argv[2:], 'art/props')
