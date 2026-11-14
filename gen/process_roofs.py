# The rooftops and the climb up to them (2026-11-14): two roof backdrops seen from the street side,
# with their flat painted sky cut out so the game's own sky shows, and the scaffolding bay and the
# ladder drawn on magenta, keyed out and cut to tile.
#
# Run:  python3 gen/process_roofs.py
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = '/mnt/user-data/uploads/Ink and Lead/art_src/'
OUT = '/home/claude/repo/art/'
ROOFS = {'roof_a': '107.png', 'roof_b': '108.png'}


def sky_cut(rgb):
    """The painted sky: the smooth bluish field joined to the top edge. It fades lighter towards the
    skyline, so it is grown over smooth pixels (no ink edge between them) rather than by one colour."""
    a = rgb.astype(float)
    lum = ndimage.gaussian_filter(a.mean(2), 1.5)
    grad = np.hypot(ndimage.sobel(lum, 0), ndimage.sobel(lum, 1))
    blue = (a[..., 2] > a[..., 0] + 12) & (a.max(2) < 175)
    smooth = (grad < 26.0) & blue
    lab, n = ndimage.label(smooth)
    top = set(np.unique(lab[:8])) - {0}
    sky = np.isin(lab, list(top))
    sky = ndimage.binary_closing(sky, iterations=3) & blue
    sky = ndimage.binary_opening(sky, iterations=2)
    sky[:6] |= sky[6]          # the opening eats the sky along the picture's edges: a faint frame in the game
    sky[:, :6] |= sky[:, 6:7]
    sky[:, -6:] |= sky[:, -7:-6]
    alpha = np.where(sky, 0, 255).astype(np.uint8)
    return np.asarray(Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8)))


def key_magenta(rgb):
    a = rgb.astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = np.clip(((np.minimum(r, b) - g) - 70.0) / 60.0, 0, 1)   # 1 where it is the backdrop
    alpha = (1.0 - mag)
    alpha = ndimage.grey_erosion(alpha, size=(3, 3))
    out = a.copy()   # no pink fringe on the ink edge
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1.0 - alpha)
    out[..., 0] -= spill * 0.7
    out[..., 2] -= spill * 0.7
    return np.clip(out, 0, 255).astype(np.uint8), (alpha * 255).astype(np.uint8)


for name, f in ROOFS.items():
    rgb = np.asarray(Image.open(SRC + f).convert('RGB'))
    al = sky_cut(rgb)
    Image.fromarray(np.dstack([rgb, al])).save(OUT + f'street/{name}.png')
    print(name, rgb.shape, 'sky', round(float((al < 128).mean()), 3))

# one bay of scaffolding: posts 118..1952 high, the deck walked on at row 845
rgb, al = key_magenta(np.asarray(Image.open(SRC + '109.png').convert('RGB')))
box = (150, 110, 1915, 1960)
Image.fromarray(np.dstack([rgb, al])).crop(box).save(OUT + 'props/scaffold.png')
print('scaffold', box, 'deck row in crop', 845 - box[1])

# the ladder: Gemini set the rungs too close for a man's stride, so a tile is spliced from one rung
# and three lengths of the bare rails below it: one rung every 396 rows, the tile repeats seamlessly
rgb, al = key_magenta(np.asarray(Image.open(SRC + '110.png').convert('RGB')))
pic = np.dstack([rgb, al])[:, 440:1100]
rung = pic[360:420]
gap = pic[425:530]
tile = np.concatenate([rung, gap, gap, gap[::-1]], axis=0)
Image.fromarray(tile).save(OUT + 'props/ladder.png')
print('ladder tile', tile.shape)
