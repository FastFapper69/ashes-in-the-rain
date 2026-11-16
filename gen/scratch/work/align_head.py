# Align a Gemini "bare head" redraw onto the original head sprite (same canvas), cut its alpha,
# and cut the hat out of the original (pixels that differ, above the brim line).
import sys, cv2, numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
orig_path, bare_path, out_bare, out_hat = sys.argv[1:5]
o = Image.open(orig_path).convert('RGBA'); W, H = o.size
oa = np.asarray(o).astype(np.float32)
b = Image.open(bare_path).convert('RGB')
ba = np.asarray(b)
def key_white(rgb):
    near = rgb.min(axis=2) > 225
    lab, n = ndimage.label(near)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    return ~np.isin(lab, list(edge))
a_ = oa[:, :, 3:4] / 255.0
onw = (oa[:, :, :3] * a_ + 255.0 * (1 - a_)).astype(np.uint8)   # on white, as Gemini saw it
og = cv2.cvtColor(onw, cv2.COLOR_RGB2GRAY)
# lower 45 % of the original: face, ear, jaw (the hat never reaches there)
y0 = int(H * 0.55)
tmpl = og[y0:, :]
bg = cv2.cvtColor(ba, cv2.COLOR_RGB2GRAY)
best = None
for s in np.linspace(0.12, 0.30, 73):
    bs = cv2.resize(bg, (int(bg.shape[1] * s), int(bg.shape[0] * s)), interpolation=cv2.INTER_AREA)
    if bs.shape[0] < tmpl.shape[0] or bs.shape[1] < tmpl.shape[1]:
        continue
    r = cv2.matchTemplate(bs, tmpl, cv2.TM_CCOEFF_NORMED)
    _, mv, _, ml = cv2.minMaxLoc(r)
    if best is None or mv > best[0]:
        best = (mv, s, ml)
mv, s, (mx, my) = best
print('match', round(mv, 3), 'scale', round(s, 4))
bs = cv2.resize(ba, (int(ba.shape[1] * s), int(ba.shape[0] * s)), interpolation=cv2.INTER_AREA)
# the original's (0, y0) sits at (mx, my) in the scaled bare image: original (0,0) at (mx, my - y0)
ox, oy = mx, my - y0
canvas = np.full((H + 400, W, 3), 255, np.uint8)   # room above for hair taller than the hat crown? keep same canvas
crop = np.full((H, W, 3), 255, np.uint8)
for y in range(H):
    sy = y + oy
    if 0 <= sy < bs.shape[0]:
        x0 = max(0, -ox); x1 = min(W, bs.shape[1] - ox)
        crop[y, x0:x1] = bs[sy, x0 + ox:x1 + ox]
alpha = key_white(crop).astype(np.uint8) * 255
al = Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.8))
bare = Image.fromarray(crop).convert('RGBA'); bare.putalpha(al)
bare.save(out_bare)
# the hat: what the original has that the bare head doesn't, in the upper part
oalpha = oa[:, :, 3] > 40
diff = np.abs(oa[:, :, :3] - crop.astype(np.float32)).sum(axis=2) > 45
hsv = cv2.cvtColor(oa[:, :, :3].astype(np.uint8), cv2.COLOR_RGB2HSV)
skin = (hsv[:, :, 1] > 40) & (hsv[:, :, 0] < 30) & (hsv[:, :, 2] > 90)   # warm, light: face and ears, never the hat
hat = oalpha & (diff | ~(alpha > 128)) & ~skin
hat[int(H * 0.62):, :] = False
lab, n = ndimage.label(hat)
if n:
    sizes = ndimage.sum(hat, lab, range(1, n + 1))
    keep = 1 + int(np.argmax(sizes))
    hat = lab == keep
hat = ndimage.binary_opening(hat, iterations=1)
lab, n = ndimage.label(hat)
if n:
    sizes = ndimage.sum(hat, lab, range(1, n + 1))
    hat = lab == 1 + int(np.argmax(sizes))
hat = ndimage.binary_closing(hat, iterations=3)
hat = ndimage.binary_fill_holes(hat)
ha = Image.fromarray((hat * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
hi = Image.fromarray(oa.astype(np.uint8)); hi.putalpha(Image.fromarray(np.minimum(np.asarray(ha), oa[:, :, 3].astype(np.uint8))))
hi.save(out_hat)
