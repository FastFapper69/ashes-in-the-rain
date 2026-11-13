# Cuts the foreground strip (art/bg/fore.png) into separate props so each map can scatter them
# in its own order, and draws a cast-iron street lamp to stand among them (a near-black silhouette
# in game, so plain shapes are enough; its lantern gets a glow in the engine).
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = '/home/claude/repo/art/fore/'
src = Image.open('/home/claude/repo/art/bg/fore.png')
BOXES = {'sign': (100, 448), 'car': (500, 1775), 'bollard': (1815, 1940), 'hydrant': (1990, 2206), 'railing': (2245, 2812), 'trash': (2858, 3115)}
for name, (x0, x1) in BOXES.items():
    crop = src.crop((x0, 0, x1, 1296))
    bb = crop.getbbox()
    crop = crop.crop((0, bb[1], crop.width, 1296))
    crop.save(OUT + name + '.png')
    print(name, crop.size)

# street lamp: plinth, fluted post, scroll arm, lantern
W, H = 420, 1290
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
ink = (34, 32, 31, 255)
cx = W // 2
d.rounded_rectangle([cx - 62, H - 150, cx + 62, H], 10, fill=ink)        # plinth
d.polygon([(cx - 48, H - 150), (cx + 48, H - 150), (cx + 30, H - 260), (cx - 30, H - 260)], fill=ink)
d.rectangle([cx - 17, 210, cx + 17, H - 255], fill=ink)                   # post
for y in range(300, H - 300, 180):                                         # collars
    d.rounded_rectangle([cx - 25, y, cx + 25, y + 18], 6, fill=ink)
d.ellipse([cx - 30, 190, cx + 30, 240], fill=ink)
d.polygon([(cx - 70, 70), (cx + 70, 70), (cx + 52, 180), (cx - 52, 180)], fill=(34, 32, 31, 120))  # glass, half see-through
d.polygon([(cx - 92, 70), (cx + 92, 70), (cx, 0)], fill=ink)                # cap
d.rectangle([cx - 60, 176, cx + 60, 196], fill=ink)
for x in (cx - 70, cx, cx + 70):
    d.line([(x, 70), (x * 0.85 + cx * 0.15 if x != cx else cx, 180)], fill=ink, width=7)
d.arc([cx - 120, 230, cx - 10, 340], 180, 330, fill=ink, width=10)         # scrolls under the lantern
d.arc([cx + 10, 230, cx + 120, 340], 210, 360, fill=ink, width=10)
img.save(OUT + 'lamp.png')
print('lamp', img.size)
