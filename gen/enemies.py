# Cuts the Gemini sheets into puppet parts: four mobster heads (art_src/41.png) and two straight
# legs (art_src/40.png) that are bent as meshes in the game, so knees are not separate pieces.
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

def cut(path):
    src = np.asarray(Image.open(path).convert('RGB')).astype(int)
    paper = (src.min(2) > 228) & ((src.max(2) - src.min(2)) < 18)
    lab, n = ndimage.label(paper)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    out = np.isin(lab, list(edge))
    a = np.where(out, 0, 255).astype(np.uint8)
    a = np.asarray(Image.fromarray(a).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.7)))
    blobs, m = ndimage.label(ndimage.binary_dilation(~out, iterations=10))
    parts = []
    for k, sl in enumerate(ndimage.find_objects(blobs)):
        if (sl[0].stop - sl[0].start) * (sl[1].stop - sl[1].start) < 40000:
            continue
        keep = blobs[sl] == k + 1
        im = Image.fromarray(np.dstack([src[sl], np.where(keep, a[sl], 0)]).astype(np.uint8), 'RGBA')
        im = im.crop(Image.fromarray(np.where(keep, a[sl], 0).astype(np.uint8)).getbbox())
        parts.append((sl[1].start, im))
    parts.sort(key=lambda p: p[0])
    return [p[1] for p in parts]

OUT = '/home/claude/repo/art/'
for name, im in zip(['fedora', 'homburg', 'cap', 'boxer'], cut('/mnt/user-data/uploads/Ink and Lead/art_src/41.png')):
    im = im.resize((im.width * 378 // im.height, 378), Image.LANCZOS)   # the height of the first mobster head
    im.save(OUT + f'mobster/heads/{name}.png')
    a = np.asarray(im)[..., 3] > 128
    cols = np.where(a[im.height - 15])[0]
    print(name, im.size, 'neck x', round(float(cols.mean()), 1))
for name, im in zip(['mobster/leg', 'detective/leg'], cut('/mnt/user-data/uploads/Ink and Lead/art_src/40.png')):
    im = im.resize((im.width * 1000 // im.height, 1000), Image.LANCZOS)
    im.save(OUT + name + '.png'); print(name, im.size)


# normal maps like the other parts: a soft dome from the silhouette, a little relief from the ink
def normal_map(path):
    im = Image.open(path)
    a = np.asarray(im)[..., 3] > 128
    d = ndimage.distance_transform_edt(a)
    h = np.sqrt(np.clip(d / 28.0, 0, 1)) * 28.0
    lum = np.asarray(im.convert('L').filter(ImageFilter.GaussianBlur(1.2))).astype(float) / 255.0
    h = ndimage.gaussian_filter(h, 2.0) + lum * 6.0
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h) * 1.2])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    rgb = ((n + 1) * 127.5).clip(0, 255).astype(np.uint8)
    Image.fromarray(rgb).save(path.replace('.png', '_n.png'))

for f in ['mobster/heads/fedora', 'mobster/heads/homburg', 'mobster/heads/cap', 'mobster/heads/boxer', 'mobster/leg', 'detective/leg']:
    normal_map(OUT + f + '.png')
print('normals done')
