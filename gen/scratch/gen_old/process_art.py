# Turns the Gemini pictures in art_src into game art: street segments with the white sky cut out,
# the repeated pair of water towers removed, the right-hand pilaster trimmed (so neighbours share one),
# plus a normal map for the lamplight; interiors copied in as room back walls.
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


def normal_map(rgb):
    lum = np.asarray(Image.fromarray(rgb).convert('L').filter(ImageFilter.GaussianBlur(1.5))).astype(float) / 255.0
    gy, gx = np.gradient(lum)
    s = 6.0
    nx, ny, nz = -gx * s, -gy * s, np.ones_like(lum)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([(nx / l + 1) * 127.5, (ny / l + 1) * 127.5, (nz / l + 1) * 127.5], 2).astype(np.uint8)
    return Image.fromarray(n)


for name, (f, trim, towers) in STREET.items():
    rgb = np.asarray(Image.open(SRC + f).convert('RGB'))
    alpha = sky_alpha(rgb).copy()
    roof = remove_towers(rgb, alpha) if towers else -1
    rgb, alpha = rgb[:, :rgb.shape[1] - trim], alpha[:, :alpha.shape[1] - trim]
    im = Image.fromarray(np.dstack([rgb, alpha]))
    im.save(OUT + f'street/{name}.png')
    normal_map(rgb).save(OUT + f'street/{name}_n.png')
    print(name, im.size, 'roof', roof, 'sky', round(float((alpha < 128).mean()), 3))

for style, f in ROOMS.items():
    Image.open(SRC + f).convert('RGB').save(OUT + f'rooms/{style}.png')
    print('room', style)
