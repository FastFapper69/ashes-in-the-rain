"""(user 25. 11.: "he does not hold the gun right, finger off the trigger") the forearm without its fist, for the hand
that grips the gun (art/guns/<gun>_hand.png, art_src 364/365): everything past the cuff line is cut away.
usage: py -3 gen/grip_cuff.py <art dir> ax ay bx by t   -> <dir>/farm_grip.png (+ _n when there is a normal map)"""
import sys, os
import numpy as np
from PIL import Image
d = sys.argv[1]
a = np.array([float(sys.argv[2]), float(sys.argv[3])]); b = np.array([float(sys.argv[4]), float(sys.argv[5])]); t = float(sys.argv[6])
for name in ("farm", "farm_n"):
    p = os.path.join(d, name + ".png")
    if not os.path.exists(p):
        continue
    im = np.array(Image.open(p).convert("RGBA"))
    h, w = im.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    u = (b - a) / np.dot(b - a, b - a)
    proj = (xx - a[0]) * u[0] + (yy - a[1]) * u[1]
    fade = np.clip((t - proj) / 0.015, 0.0, 1.0)   # a soft edge one or two pixels wide, hidden inside the bare wrist
    im[..., 3] = (im[..., 3] * fade).astype(np.uint8)
    Image.fromarray(im).save(os.path.join(d, name.replace("farm", "farm_grip") + ".png"))
    print("saved", name, "cut at", a + (b - a) * t)
