"""(playground station 5, roofs) Layouts Gemini draws over:
- templates/roof_layout.png: the roof seen from the street over a 3-bay front (3000 x 600 world at 0.5): the roof line at
  the bottom (= the cornice's top, where he walks), the things on the roof behind it, green sky (keyed out).
- templates/escape_layout.png: a fire escape on one bay of a 3-storey front, seen front-on (1000 x 2464 world at 0.5):
  landings at the upper storeys' floors (-764, -1464, -2164 world), stairs between them, a drop ladder under the lowest,
  a gooseneck ladder over the cornice to the roof (-2464). main.gd / gen/levels.py ESC_FRONT_* use the same numbers."""
from PIL import Image, ImageDraw
import os
OUT = os.path.join(os.path.dirname(__file__), "templates")
K = 0.5
im = Image.new("RGB", (int(3000 * K), int(600 * K)), (0, 255, 0))
d = ImageDraw.Draw(im)
d.rectangle((0, 600 * K - 12, 3000 * K, 600 * K), fill=(40, 40, 40))     # the roof line (cornice top)
im.save(os.path.join(OUT, "roof_layout.png"))
H = 2464
y = lambda wy: (H + wy) * K
im = Image.new("RGB", (int(1000 * K), int(H * K)), (0, 255, 0))
d = ImageDraw.Draw(im)
d.rectangle((0, 0, 1000 * K, 300 * K), fill=(120, 110, 100))              # the cornice
for ly in (-764, -1464, -2164):                                           # the landings, out over the pavement
    d.rectangle((100 * K, y(ly) - 6, 900 * K, y(ly) + 6), fill=(30, 30, 30))
    d.line((100 * K, y(ly) - 70, 900 * K, y(ly) - 70), fill=(30, 30, 30), width=3)
for a, b in ((-764, -1464), (-1464, -2164)):                              # the stairs, up to the right each flight
    d.line((250 * K, y(a), 750 * K, y(b)), fill=(30, 30, 30), width=8)
d.line((800 * K, y(-764), 800 * K, y(-380)), fill=(30, 30, 30), width=6)  # the drop ladder (hangs, slides down)
d.line((850 * K, y(-2164), 850 * K, y(-2464) - 40), fill=(30, 30, 30), width=6)   # the gooseneck over the cornice
im.save(os.path.join(OUT, "escape_layout.png"))
print("ok")
