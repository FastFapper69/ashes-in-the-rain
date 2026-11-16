# The searchlight (art/props/searchlight.png) in two layers on the same canvas (2026-11-16): the drum
# that tilts on its axle, and everything that stays put (the mast, the yoke and its arms, the cable).
# Under the yoke's near arm the drum is painted in (inpainted) so it has no hole when it turns.
import numpy as np
import cv2
from PIL import Image, ImageDraw
src = Image.open('art/props/searchlight.png').convert('RGBA')
a = np.asarray(src).copy()
h, w = a.shape[:2]
arm_img = Image.new('L', (w, h), 0)
ImageDraw.Draw(arm_img).polygon([(190, 108), (221, 108), (221, 140), (215, 236), (215, 252), (183, 252), (186, 140), (186, 115)], fill=255)
arm = np.asarray(arm_img) > 0
yy, xx = np.mgrid[0:h, 0:w]
drum = (yy < 250) & ~((xx < 102) & (yy > 222)) & ~((xx > 222) & (yy > 195))
# the drum layer: its own pixels, and under the arm the body painted in from around it
rgb = np.ascontiguousarray(a[..., :3][..., ::-1])
hole = (arm & (yy < 236)).astype(np.uint8) * 255
# cloned from the drum just left of the arm (its hatching and rust), the seams softened by inpainting
filled = np.roll(a[..., :3], 40, axis=1)
seam = (cv2.dilate(hole, np.ones((5, 5), np.uint8)) - cv2.erode(hole, np.ones((5, 5), np.uint8)))
filled = np.where(seam[..., None] > 0, cv2.inpaint(rgb, hole, 5, cv2.INPAINT_TELEA)[..., ::-1], filled)
d = a.copy()
d[..., :3] = np.where(hole[..., None] > 0, filled, a[..., :3])
d[..., 3] = np.where(drum, np.where(hole > 0, 255, a[..., 3]), 0)
p = a.copy()
p[..., 3] = np.where(drum & ~arm, 0, a[..., 3])
Image.fromarray(d).save('art/props/searchlight_drum.png')
Image.fromarray(p).save('art/props/searchlight_post.png')
