"""The ironwork, cut from the iron sheet (art_src/85.jpg via gen/cut_props.py) and baked at the game's
own scale (1 px = 1 world unit), so nothing is stretched:
  iron_land_<n>.png  a fire-escape landing bolted to a wall: its railing keeps its post spacing
  iron_walk.png      the same deck on riveted legs, for the docks where there is no wall to hang it on
  iron_flight.png    one storey of stairs
Rows above SPLIT are the deck and railing (drawn in front of people), below it brackets or legs.
main.gd IRON_* and gen/levels.py LAND_W must match the numbers printed here."""
from PIL import Image
P = 'art/props/'
K = 0.9                      # a railing comes to a man's waist
DECK, SPLIT = 215, 262       # source rows: where feet stand on the grating; under the deck's front beam
L = Image.open('art/_src/iron_landing.png').convert('RGBA')
LEFT, MID0, MID1, RIGHT = 244, 244, 467, 578
def scaled(im): return im.resize((round(im.width * K), round(im.height * K)), Image.LANCZOS)
lands = []
for n in range(4):
    w = LEFT + n * (MID1 - MID0) + (L.width - RIGHT)
    out = Image.new('RGBA', (w, L.height), (0, 0, 0, 0))
    out.paste(L.crop((0, 0, LEFT, L.height)), (0, 0))
    for k in range(n):
        out.paste(L.crop((MID0, 0, MID1, L.height)), (LEFT + k * (MID1 - MID0), 0))
    out.paste(L.crop((RIGHT, 0, L.width, L.height)), (w - (L.width - RIGHT), 0))
    s = scaled(out); s.save(P + 'iron_land_%d.png' % n); lands.append(s)
    print('land', n, s.size)
print('deck row', DECK * K, 'split row', round(SPLIT * K))
# the walkway on legs: the longest deck, the gantry's legs under each end
RISE = 370
G = Image.open('art/_src/iron_gantry.png').convert('RGBA')
legs = G.crop((0, 330, G.width, G.height))
deck = lands[3].crop((0, 0, lands[3].width, round(SPLIT * K)))
leg_h = RISE - (round(SPLIT * K) - round(DECK * K))
k2 = leg_h / legs.height
legs = legs.resize((round(legs.width * k2), leg_h), Image.LANCZOS)
walk = Image.new('RGBA', (deck.width, deck.height + leg_h), (0, 0, 0, 0))
walk.alpha_composite(legs, (30, deck.height)); walk.alpha_composite(legs, (deck.width - legs.width - 30, deck.height))
walk.alpha_composite(deck, (0, 0))
walk.save(P + 'iron_walk.png'); print('walk', walk.size)
# the flight: from the lowest tread up one storey along the tread line
S = Image.open('art/_src/iron_stairs.png').convert('RGBA')
X0, Y0, X1, Y1 = 55.0, 930.0, 520.0, 270.0
rise = RISE / K; run = rise * (X1 - X0) / (Y0 - Y1)
xt, yt = X0 + run, Y0 - rise
box = (0, int(yt - 200), int(xt + 125), int(Y0 + 4))
F = S.crop(box)
px = F.load()
for y in range(F.height):       # the flight stops at the landing: nothing of it goes on above the deck
    for x in range(F.width):
        if x + box[0] > xt + 4 and y + box[1] < yt - 8:
            px[x, y] = (0, 0, 0, 0)
F = scaled(F); F.save(P + 'iron_flight.png')
print('flight', F.size, 'foot', ((X0 - box[0]) * K, (Y0 - box[1]) * K), 'run', run * K)
