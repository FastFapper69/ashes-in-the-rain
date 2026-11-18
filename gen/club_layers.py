"""The big Blue Note (user 18. 11.: "make the club bigger like the laundry, so it makes sense and is not small"):
  art_src 302/303 -> art/rooms/club_bar.png + club_bar_gallery.png   (entrance, back bar, the stairs up to the gallery)
  art_src 304/305 -> art/rooms/club_hall.png + club_hall_gallery.png (dance hall, the gallery with its booths)
                     art/rooms/club_chandelier.png (the chandelier alone, the boss fight's hazard: main.gd _chandelier)
Gemini drew each with and without; the layer = the 'with' picture where it differs, inside the thing's own shapes.
The bar room's gallery came out 55 px higher than the hall's: its layer (with the stairs) moves down as a whole."""
import os
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from paths import SRC
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "rooms")
FLOOR = 1250
SHIFT_A = 55
def load(f): return np.asarray(Image.open(SRC + f).convert("RGB")).astype(float)
def diff(a, b): return ndimage.binary_dilation(ndimage.gaussian_filter(np.abs(a - b).max(axis=2), 1.2) > 26, iterations=2)
def poly(shape, pts):
    im = Image.new("L", (shape[1], shape[0]), 0); ImageDraw.Draw(im).polygon(pts, fill=1); return np.asarray(im) > 0
def clean(m, minsize=500):
    m = ndimage.binary_closing(m, iterations=2)
    lab, n = ndimage.label(m); sz = ndimage.sum(m, lab, range(1, n + 1))
    return np.isin(lab, np.where(sz > minsize)[0] + 1)
def save(a, m, name, shift=0):
    al = ndimage.gaussian_filter(m.astype(float), 0.8) * 255
    lay = np.dstack([a, al])
    if shift:
        lay = np.roll(lay, shift, axis=0); lay[:shift, :, 3] = 0
    lay[FLOOR + 6:, :, 3] = 0
    Image.fromarray(lay.astype(np.uint8)).save(os.path.join(OUT, name))
a, b = load("302.jpg"), load("303.jpg")
d = diff(a, b); H, W = d.shape
lum = a.mean(axis=2)
# the flight with its handrail and the panelling under it, the gallery's end and its post: whole shapes (the layer moves)
m = poly(d.shape, [(1990, 1135), (2140, 1140), (2700, 690), (2700, 430), (2020, 870), (1985, 900)])
m |= poly(d.shape, [(2640, 380), (3055, 380), (3055, 690), (2640, 690)])
m |= poly(d.shape, [(2675, 680), (2750, 680), (2750, FLOOR), (2675, FLOOR)])
save(a, m, "club_bar_gallery.png", SHIFT_A)
# (18. 11.: the bar to dive onto and skid along is the game's own counter, art/props/bar_counter.png, in front of the back
# bar) the painted counter and stools out: art_src 307 is 303 without them; only its bar area is taken (Gemini moved other
# bits a little), feathered into 303
c = load("307.jpg")
yy, xx = np.mgrid[:H, :W]
w = np.clip(np.minimum.reduce([(xx - 960) / 40.0, (2080 - xx) / 40.0, (yy - 760) / 40.0, (1270 - yy) / 40.0]), 0, 1)[..., None]
b = b * (1 - w) + c * w
Image.fromarray(b.astype(np.uint8)).save(os.path.join(OUT, "club_bar.png"))
a, b = load("304.jpg"), load("305.jpg")
d = diff(a, b)
ch = poly(d.shape, [(1300, 0), (1870, 0), (1870, 500), (1300, 500)])
band = poly(d.shape, [(95, 160), (3065, 160), (3065, 730), (95, 730)]) & ~ch   # the balustrade, the booths behind it, the deck
gal = ndimage.binary_fill_holes(ndimage.binary_closing(d & band, iterations=6)) & band
for x0, x1 in ((576, 644), (1552, 1616), (2524, 2596)):                         # its three columns
    gal |= poly(d.shape, [(x0, 724), (x1, 724), (x1, FLOOR), (x0, FLOOR)])
save(a, clean(gal), "club_hall_gallery.png")
lum = a.mean(axis=2)
strong = (ndimage.gaussian_filter(np.abs(a - b).max(axis=2), 1.0) > 55) & ((lum < 95) | (lum > 205))   # ink and crystal, not the glow
lab, n = ndimage.label(ndimage.binary_closing(strong & ch, iterations=3))
cm = lab == (np.argmax(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))) + 1)
cm = ndimage.binary_fill_holes(ndimage.binary_closing(cm, iterations=4)) & ndimage.binary_dilation(strong, iterations=4)
yy, xx = np.mgrid[:cm.shape[0], :cm.shape[1]]
cm &= ~((yy < 300) & ((xx < 1545) | (xx > 1610)))                    # (no bits of the beams it hangs from)
cm |= (yy >= 30) & (yy < 300) & (xx >= 1566) & (xx <= 1598)          # its chain, up to the beam (rule 19)
ys, xs = np.where(cm)
box = (int(xs.min()) - 4, 0, int(xs.max()) + 5, int(ys.max()) + 5)
lay = np.dstack([a, ndimage.gaussian_filter(cm.astype(float), 0.8) * 255]).astype(np.uint8)
Image.fromarray(lay).crop(box).save(os.path.join(OUT, "club_chandelier.png"))
print("chandelier box (px of the hall):", box)
Image.fromarray(b.astype(np.uint8)).save(os.path.join(OUT, "club_hall.png"))
