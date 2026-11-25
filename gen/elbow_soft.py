"""(user 25. 11.: "why does the elbow look like a puppet again") Frank's forearm drawing starts with a thick inked round cap,
which drew a black ring across the upper arm at every bend - two puppet pieces. The forearm now starts AT the elbow joint,
fading in over a short band; the upper arm's own rounded end (under it) is the elbow.
usage: py -3 gen/elbow_soft.py <png> ax ay bx by <t from> <t to>   (alpha 0 before t from, 1 after t to; the inked source is
kept in art/_src/<figure>/ the first time - outside the build - and every run starts from it)."""
import sys, os, shutil
import numpy as np
from PIL import Image
p = sys.argv[1]
a = np.array([float(sys.argv[2]), float(sys.argv[3])]); b = np.array([float(sys.argv[4]), float(sys.argv[5])])
t0, t1 = float(sys.argv[6]), float(sys.argv[7])
fig, name = os.path.split(p)
srcdir = os.path.join(os.path.dirname(fig), "_src", os.path.basename(fig))
os.makedirs(srcdir, exist_ok=True)
keep = os.path.join(srcdir, name)
if not os.path.exists(keep):
    shutil.copy(p, keep)
for src, dst in ((keep, p), (keep.replace(".png", "_n.png"), p.replace(".png", "_n.png"))):
    if src != keep and not os.path.exists(src):
        if not os.path.exists(dst):
            continue
        shutil.copy(dst, src)
    im = np.array(Image.open(src).convert("RGBA")).astype(float)
    h, w = im.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    u = (b - a) / np.dot(b - a, b - a)
    pr = (xx - a[0]) * u[0] + (yy - a[1]) * u[1]
    s = np.clip((pr - t0) / (t1 - t0), 0, 1); s = s * s * (3 - 2 * s)
    im[..., 3] *= s
    Image.fromarray(im.clip(0, 255).astype(np.uint8)).save(dst)
    print("faded", dst)
