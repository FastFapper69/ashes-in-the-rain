"""(22. 11., user: "the door upstairs - its angle and its animation make no sense: look at the tilt of the wall with the
door and the wall with the window") The wall between the hallway and the flat, turned the way the flat's window wall is
(Gemini's redraw of tenement_flat, art_src 353): cut out of it, to the kit's scale, as a strip laid over the flat's
drawing at PARTITION_X (main.gd) - its doorway's far jamb on the old hinge (px 570)."""
from PIL import Image
import os, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\super\Documents\MobileGames\Ashes in the Rain\art_src\353.jpg"
K = (1096.0 - 103.0) / (1139.0 - 104.0)   # the redraw's floor and ceiling onto the kit's
X0, X1 = 766, 1372                          # the post on the hallway's side ... just past the corner at the back wall
im = Image.open(SRC).convert("RGBA")
im = im.crop((X0, 0, X1, im.height))
im = im.resize((round(im.width * K), round(im.height * K)), Image.LANCZOS)
out = Image.new("RGBA", (im.width, 1112), (0, 0, 0, 255))
out.paste(im, (0, 103 - round(104 * K)))
px = out.load()
F = 12                                      # past the corner it fades into the flat's own wall
for x in range(out.width - F, out.width):
    a = int(255 * (out.width - 1 - x) / F)
    for y in range(1112):
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, a)
out.save(os.path.join(os.path.dirname(__file__), "..", "art", "section", "tenement_partition.png"))
print(out.size)
