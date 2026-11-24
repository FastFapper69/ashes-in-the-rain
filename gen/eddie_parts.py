"""Eddie Doyle's own body (postavy/plan-novych-postav.md, pilot; user approved design art_src 362): the parts sheet
art_src 363 cut (char_cut.py) and laid out for the rig -> art/eddie2/{head,torso,uarm,farm,leg}.png + _n normals.
The joints of each picture are in main.gd _eddie2_cfg (pixels of these files)."""
import os
import numpy as np
from PIL import Image
from scipy import ndimage
from char_cut import pieces
from outfits import normal_map
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "eddie2")
os.makedirs(OUT, exist_ok=True)
P = pieces(363)   # biggest first: 0 torso, 1 leg, 2 upper arm, 3 bent arm, 4 head, 5 forearm open hand, 6 hat, 7 fist
def save(name, im):
    p = os.path.join(OUT, name + ".png")
    im.save(p); normal_map(p); print(name, im.size)
# torso: the armhole is a hole in the drawing - the coat's dark inside behind the sleeve
t = np.asarray(P[0][2]).copy()
solid = t[..., 3] > 128
hole = ndimage.binary_fill_holes(solid) & ~solid
hole = ndimage.binary_dilation(hole, iterations=3)
t[hole & (t[..., 3] < 250)] = (30, 29, 36, 255)
# (user 24. 11.: "the sweater's collar is almost black, it reads as the head cut off - a little lighter") the sweater
# between the lapels and the black inside of the raised collar lifted to a dark grey; the ink lines stay
lab, n = ndimage.label(hole)
for i in range(1, n + 1):
    if ndimage.center_of_mass(lab == i)[1] > 280:
        t[(lab == i) & (t[..., 3] > 0)] = (66, 68, 80, 255)
lum = t[..., :3].astype(int).sum(axis=2)
fill = ndimage.binary_dilation(ndimage.binary_erosion((lum < 75) & solid, iterations=5), iterations=6) & (lum < 110) & solid
fill[240:] = False
soft = ndimage.gaussian_filter(fill.astype(float), 2.0)[..., None]
t[..., :3] = (t[..., :3] * (1 - soft) + np.array([58, 56, 62]) * soft).astype(np.uint8)
save("torso", Image.fromarray(t))
# head with the hat on: the hat levelled a little and set on the hairline
head, hat = P[4][2], P[6][2].rotate(-9, expand=True, resample=Image.BICUBIC)
hat = hat.resize((int(hat.width * 1.0), int(hat.height * 1.0)), Image.LANCZOS)
PADX, PADY = 70, 110
c = Image.new("RGBA", (head.width + PADX + 90, head.height + PADY), (0, 0, 0, 0))
c.alpha_composite(head, (PADX, PADY))
c.alpha_composite(hat, (PADX - 52, PADY - 118))
save("head", c)
save("uarm", P[2][2])
# forearm with the fist: the bent arm below its elbow
f = np.asarray(P[3][2]).copy()
yy, xx = np.mgrid[:f.shape[0], :f.shape[1]]
f[(xx < 205) & (yy < 255)] = 0
ys, xs = np.where(f[..., 3] > 20)
print("farm crop", xs.min(), ys.min())
save("farm", Image.fromarray(f[ys.min():, xs.min():]))
# leg: the hip joint on row 6 %, the ankle on 89 %, the axis 36 % across (puppet.gd LEG_*)
leg = P[1][2]
HIP_Y, ANKLE_Y, AXIS_X = 110, 1120, 150
H = int(round((ANKLE_Y - HIP_Y) / 0.83)); top = HIP_Y - int(round(0.06 * H)); W = int(round(AXIS_X / 0.36))
c = Image.new("RGBA", (max(W, leg.width), H), (0, 0, 0, 0))
c.alpha_composite(leg, (0, -top))
save("leg", c)
