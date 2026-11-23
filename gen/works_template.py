"""(QUEUE §22) The layout Gemini draws the works hall over (art_src 354): the building across the alley in cross-section,
3000 x 2464 world px at half size - the ground floor, the first gallery on the left (where he comes in through the front
window, 0..1400 at -700), the second on the right (1700..3000 at -1400), the iron ladder up to it (x 1760), the roof
(sawtooth skylights) over it all. main.gd WORKS_*, gen/levels.py city_block use the same numbers."""
from PIL import Image, ImageDraw
import os
W, H, K = 3000, 2464, 0.5
im = Image.new("RGB", (int(W * K), int(H * K)), (150, 150, 150))
d = ImageDraw.Draw(im)
y = lambda wy: (H + wy) * K
x = lambda wx: wx * K
d.rectangle((0, 0, x(W), y(-2100)), fill=(20, 20, 20))                       # the roof's cut
d.rectangle((0, y(0), x(W), y(0) + 40), fill=(20, 20, 20))                   # the floor slab
for a, b, fy in ((0, 1400, -700), (1700, 3000, -1400)):                       # the galleries: deck, its cut edge, railing
    d.rectangle((x(a), y(fy), x(b), y(fy) + 28), fill=(30, 30, 30))
    d.line((x(a), y(fy) - 50, x(b), y(fy) - 50), fill=(30, 30, 30), width=5)
    for px in range(int(x(a)), int(x(b)), 40):
        d.line((px, y(fy), px, y(fy) - 50), fill=(30, 30, 30), width=3)
for lx in (1760,):                                                            # the ladder, floor to the upper gallery
    d.line((x(lx) - 20, y(0), x(lx) - 20, y(-1400) - 60), fill=(30, 30, 30), width=5)
    d.line((x(lx) + 20, y(0), x(lx) + 20, y(-1400) - 60), fill=(30, 30, 30), width=5)
    for ry in range(-1400, 0, 60):
        d.line((x(lx) - 20, y(ry), x(lx) + 20, y(ry)), fill=(30, 30, 30), width=3)
for cx in (450, 1100):                                                        # posts under the first gallery
    d.rectangle((x(cx) - 10, y(-700), x(cx) + 10, y(0)), fill=(60, 60, 60))
for cx in (2200, 2800):                                                       # posts under the second
    d.rectangle((x(cx) - 10, y(-1400), x(cx) + 10, y(0)), fill=(60, 60, 60))
out = os.path.join(os.path.dirname(__file__), "templates", "works_layout.png")
im.save(out)
print(out, im.size)
