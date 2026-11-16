import numpy as np
from PIL import Image
from scipy import ndimage as ndi
G = '/mnt/user-data/outputs/godot2/'
FLIP_G = False   # False: green = up (OpenGL style). Flipped if the test shows light coming from the wrong side.

def encode(hx, hy, s):
    # hx, hy: height gradient in image space (y down). normal = (-hx, -hy, 1) in image space; green stores "up".
    nx, ny_down, nz = -hx * s, -hy * s, np.ones_like(hx)
    l = np.sqrt(nx * nx + ny_down * ny_down + nz * nz)
    nx, ny_down, nz = nx / l, ny_down / l, nz / l
    gy = ny_down if FLIP_G else -ny_down
    return np.dstack([(nx * 0.5 + 0.5), (gy * 0.5 + 0.5), (nz * 0.5 + 0.5)])

def figure_normal(path, R=38.0, detail=0.35):
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32)
    a = im[..., 3] / 255.0
    inside = a > 0.5
    d = ndi.distance_transform_edt(inside)
    t = np.clip(d / R, 0, 1); h = np.sqrt(1 - (1 - t) ** 2) * R * 0.6           # rounded "pillow": steep at the edge, flat inside
    lum = (0.3 * im[..., 0] + 0.59 * im[..., 1] + 0.11 * im[..., 2]) / 255.0
    h = h + ndi.gaussian_filter(lum, 1.5) * detail * 12                          # ink lines read as grooves, folds catch the light
    h = ndi.gaussian_filter(h, 1.0)
    hy, hx = np.gradient(h)
    n = encode(hx, hy, 1.0)
    out = np.dstack([n * 255, im[..., 3:4]]).astype(np.uint8)
    out[..., :3][~inside] = (128, 128, 255)
    Image.fromarray(out, 'RGBA').save(path[:-4] + '_n.png')

def wall_normal(path, s=6.0):
    im = np.asarray(Image.open(path).convert('RGBA')).astype(np.float32)
    lum = (0.3 * im[..., 0] + 0.59 * im[..., 1] + 0.11 * im[..., 2]) / 255.0
    h = ndi.gaussian_filter(lum, 2.0)
    hy, hx = np.gradient(h)
    n = encode(hx, hy, s * 10)
    Image.fromarray(np.dstack([n * 255, im[..., 3:4]]).astype(np.uint8), 'RGBA').save(path[:-4] + '_n.png')

import glob
for p in glob.glob(G + 'art/detective/*.png') + glob.glob(G + 'art/mobster/*.png'):
    if not p.endswith('_n.png'): figure_normal(p)
wall_normal(G + 'art/bg/wall.png')

# lit windows: the glass and curtains inside chosen window frames glow; the ink of the frame stays dark
wall = np.asarray(Image.open(G + 'art/bg/wall.png').convert('RGBA')).astype(np.float32)
WINDOWS = [(70, 1066, 198, 1190), (774, 812, 848, 938), (1460, 572, 1530, 694), (2335, 332, 2403, 450), (2500, 810, 2558, 938)]
ov = np.zeros_like(wall)
for (x0, y0, x1, y1) in WINDOWS:
    c = wall[y0:y1, x0:x1]; lum = (0.3 * c[..., 0] + 0.59 * c[..., 1] + 0.11 * c[..., 2])
    k = np.clip((lum - 35) / 40, 0, 1)                    # ink lines stay out
    warm = np.array([255, 196, 110], np.float32); hot = np.array([255, 236, 190], np.float32)
    t = np.clip(lum / 220, 0, 1)[..., None]
    col = warm * (1 - t) + hot * t                        # backlit curtains read paler than open glass
    ov[y0:y1, x0:x1, :3] = col; ov[y0:y1, x0:x1, 3] = k * 235
Image.fromarray(ov.astype(np.uint8), 'RGBA').save(G + 'art/bg/wall_lit.png')
print('windows', WINDOWS)

# light textures. White, colour comes from the light. Hard edges with a few pixels of feather, no airbrush.
def cone(w=512, h=512, top=0.06, feather=5, near=1.0, far=0.62):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    half = (top + (1 - top) * (y / h)) * w / 2
    edge = np.clip((half - np.abs(x - w / 2)) / feather, 0, 1)
    fall = near + (far - near) * (y / h)
    v = edge * fall
    v *= np.clip(y / 6, 0, 1)
    img = np.dstack([np.full_like(v, 255)] * 3 + [v * 255]).astype(np.uint8)
    return Image.fromarray(img, 'RGBA')
cone().save(G + 'art/light_cone.png')
def blob(w=256, h=256, feather=0.18):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    v = np.clip((1 - r) / feather, 0, 1) * (1 - 0.5 * r)
    return Image.fromarray(np.dstack([np.full_like(v, 255)] * 3 + [v * 255]).astype(np.uint8), 'RGBA')
blob().save(G + 'art/light_blob.png')
print('ok')
