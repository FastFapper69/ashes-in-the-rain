"""(rule 33, playground) The layout Gemini draws the diner's inside over (art_src 355): the walk-up's shop behind its
front, two bays (2000 x 764 world px at 0.75) - the ceiling slab, the floor line (his feet: world y -30), the door at
the right end of the shopfront (main.gd CITY_DOORS walkup). main.gd _build_works ("shop") lays it the same size."""
from PIL import Image, ImageDraw
import os
W, H, K = 2000, 764, 0.75
im = Image.new("RGB", (int(W * K), int(H * K)), (150, 150, 150))
d = ImageDraw.Draw(im)
d.rectangle((0, 0, W * K, 40 * K), fill=(20, 20, 20))                      # the slab over it
d.rectangle((0, (H - 30) * K, W * K, H * K), fill=(60, 60, 60))           # the floor he stands on
d.line((0, (H - 30) * K, W * K, (H - 30) * K), fill=(10, 10, 10), width=4)
dx = (1000 + 796) * K                                                      # the street door, seen from inside (its back)
d.rectangle((dx - 116 * K, 233 * K, dx + 116 * K, (H - 30) * K), outline=(10, 10, 10), width=4)
out = os.path.join(os.path.dirname(__file__), "templates", "shop_layout.png")
im.save(out)
print(out, im.size)
