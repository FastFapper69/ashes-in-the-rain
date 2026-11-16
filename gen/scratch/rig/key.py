import numpy as np
from scipy import ndimage as ndi
from PIL import Image
from scipy import ndimage as ndi
SRC = '/mnt/user-data/uploads/Ink and Lead/art_src/'
def keyed(name):
    im = np.asarray(Image.open(SRC + name).convert('RGB')).astype(np.float32)
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mag = np.minimum(r, b) - g                    # how magenta a pixel is
    a = np.clip((150 - mag) / 70, 0, 1)           # 1 = subject, 0 = background
    # despill: pull the pink fringe back towards grey
    # despill: wherever red and blue both stand above green, the pink is the background showing through; pull it to grey
    edge = ndi.binary_dilation(a < 0.99, iterations=3)
    spill = np.clip(np.minimum(r, b) - g, 0, None) * edge
    out = im.copy(); out[..., 0] -= spill; out[..., 2] -= spill
    return np.dstack([np.clip(out, 0, 255), a * 255]).astype(np.uint8)
def parts(img, ymax=None, minarea=4000):
    m = img[..., 3] > 128
    if ymax: m[ymax:] = False
    lab, n = ndi.label(m); out = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        if (lab[sl] == i + 1).sum() >= minarea: out.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop, i + 1))
    return sorted(out), lab
def cut(img, lab, box):
    x0, y0, x1, y1, i = box; c = img[y0:y1, x0:x1].copy(); c[..., 3] = np.where(lab[y0:y1, x0:x1] == i, c[..., 3], 0); return Image.fromarray(c, 'RGBA')
if __name__ == '__main__':
    for n, ym in (('04.jpg', 950), ('01.jpg', None), ('06.jpg', None), ('05.jpg', 1080)):
        img = keyed(n); bx, lab = parts(img, ym); print(n, [b[:4] for b in bx])
