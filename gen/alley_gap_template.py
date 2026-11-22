"""The modular city's alley gap (QUEUE §21): the mouth of a narrow alley between two module buildings, seen from the
street at the game's grid (GAP x 2400 world px: the front corners at the picture's edges, roof cornice line at the top).
Grey template for Gemini; the sky between the walls is to come back flat green (keyed out in the game).
Run: py gen/alley_gap_template.py -> gen/templates/alley_gap_template.png"""
from PIL import Image, ImageDraw

GAP, H = 1350, 2400           # world px (9:16)
K = 1152 / GAP
im = Image.new("RGB", (int(GAP * K), int(H * K)), (0, 255, 0))
d = ImageDraw.Draw(im)
P = lambda pts: [(x * K, y * K) for x, y in pts]
back = (430, GAP - 430)        # the far end of the alley
d.polygon(P([(0, 0), (back[0], 640), (back[0], 2060), (0, H)]), fill=(118, 118, 118))            # left side wall
d.polygon(P([(GAP, 0), (back[1], 640), (back[1], 2060), (GAP, H)]), fill=(132, 132, 132))        # right side wall
d.rectangle(P([(back[0], 900), (back[1], 2060)]), fill=(95, 95, 95))                               # a back building
d.rectangle(P([(back[0] + 40, 1640), (back[1] - 40, 2060)]), fill=(70, 70, 70))                    # its yard gate
d.polygon(P([(0, H), (back[0], 2060), (back[1], 2060), (GAP, H)]), fill=(80, 80, 80))             # wet cobbles
for k in range(3):                                                                                 # windows on the walls
    for side in (0, 1):
        y = 520 + k * 520
        x0, x1 = (60, 200) if side == 0 else (GAP - 200, GAP - 60)
        d.polygon(P([(x0, y), (x1, y + 60), (x1, y + 330), (x0, y + 360)] if side == 0 else [(x0, y + 60), (x1, y), (x1, y + 360), (x0, y + 330)]), fill=(50, 50, 50))
im.save(__file__.replace("alley_gap_template.py", "templates/alley_gap_template.png"))
print(im.size)
