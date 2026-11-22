"""(22. 11., user: "no black space at the bottom, more work with the foreground") The road under the kerb, from Gemini's
strip (art_src 352: wet cobbles, a gutter with a drain grate, a tram rail, a manhole): its own kerb cut off (ours is the
slab's), darker toward the bottom, half size. Laid mirrored tile by tile (main.gd _build_road), so its ends always meet."""
from PIL import Image
import os, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\super\Documents\MobileGames\Ashes in the Rain\art_src\352.jpg"
TOP = 168   # under the drawing's own kerb: from the gutter down
im = Image.open(SRC).convert("RGB")
im = im.crop((0, TOP, im.width, im.height))
im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
px = im.load()
for y in range(im.height):
    k = 1.0 - 0.75 * max(0.0, (y / im.height - 0.45) / 0.55) ** 1.5
    for x in range(im.width):
        r, g, b = px[x, y]
        px[x, y] = (int(r * k), int(g * k), int(b * k))
im.save(os.path.join(os.path.dirname(__file__), "..", "art", "props", "road_cobbles.png"))
print(im.size)
