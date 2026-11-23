"""(23. 11., user: "the divide of the buildings at the roofs") The party wall between two module fronts, front-on: a brick
pier 160 wide from the pavement to a stone coping 60 over the roofs (3-storey roof -2464), over their joint.
Layout (300 x 1300 at 0.5 = 600 x 2600 world; the pier in the middle) -> art_src 359."""
from PIL import Image, ImageDraw
import os
K = 0.5
im = Image.new("RGB", (int(600 * K), int(2600 * K)), (0, 255, 0))
d = ImageDraw.Draw(im)
d.rectangle((220 * K, 76 * K, 380 * K, 2600 * K), fill=(130, 70, 60))     # the pier: from 60 over the roof down
d.rectangle((205 * K, 60 * K, 395 * K, 100 * K), fill=(170, 165, 150))    # its coping
im.save(os.path.join(os.path.dirname(__file__), "templates", "party_layout.png"))
