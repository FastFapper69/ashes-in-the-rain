"""The modular city's facade template (QUEUE §21, rule 31): a grey front 3 bays x 3 storeys + cornice at the game's grid
(bay BAY world px, storey STOREY, cornice CORNICE), drawn flat so Gemini paints a building EXACTLY on it. Pasted into
Gemini with a style reference (via the Windows clipboard). The painted sheet is cut on the same grid (gen/modules.py).
Run: py gen/module_template.py [ground: stoop|shop] -> gen/templates/module_template_<ground>.png"""
import sys
from PIL import Image, ImageDraw

BAY, STOREY, CORNICE = 1000, 700, 300        # world px (BAY ~ main.gd SEC_KIT_W * 700 / 1112 / 2 = 997)
W, H = 3 * BAY, CORNICE + 3 * STOREY          # 3000 x 2400 = 5:4
K = 2000 / W                                  # template px per world px
PIL_W = 70                                    # a pilaster between bays (the outer corners: 90)
WIN = (300, 440, 150)                         # upper window: width, height, sill over the storey's floor
GROUND = sys.argv[1] if len(sys.argv) > 1 else "stoop"

im = Image.new("RGB", (int(W * K), int(H * K)), (128, 128, 128))
d = ImageDraw.Draw(im)
R = lambda x0, y0, x1, y1, c: d.rectangle([x0 * K, y0 * K, x1 * K - 1, y1 * K - 1], fill=c)
R(0, 0, W, CORNICE, (150, 150, 150))                      # the cornice: a deep band, brackets under it
for i in range(13):
    bx = 60 + i * (W - 120) / 12
    R(bx - 18, CORNICE - 110, bx + 18, CORNICE, (175, 175, 175))
R(0, CORNICE - 140, W, CORNICE - 110, (175, 175, 175))
for s in range(3):                                         # string courses at each storey's top
    top = CORNICE + s * STOREY
    R(0, top, W, top + 36, (165, 165, 165))
for b in range(4):                                         # pilasters on the bay edges
    w = 90 if b in (0, 3) else PIL_W
    x = b * BAY
    R(max(0, x - w / 2) if 0 < b < 3 else (0 if b == 0 else W - w), CORNICE, min(W, x + w / 2) if 0 < b < 3 else (w if b == 0 else W), H, (150, 150, 150))
for s in range(2):                                         # the two upper storeys: one window per bay
    bottom = CORNICE + (s + 1) * STOREY
    for b in range(3):
        cx = b * BAY + BAY / 2
        R(cx - WIN[0] / 2 - 20, bottom - WIN[2] - WIN[1] - 30, cx + WIN[0] / 2 + 20, bottom - WIN[2] - WIN[1], (170, 170, 170))   # lintel
        R(cx - WIN[0] / 2, bottom - WIN[2] - WIN[1], cx + WIN[0] / 2, bottom - WIN[2], (45, 45, 45))
        R(cx - WIN[0] / 2 - 25, bottom - WIN[2], cx + WIN[0] / 2 + 25, bottom - WIN[2] + 25, (170, 170, 170))                   # sill
gtop = CORNICE + 2 * STOREY
if GROUND == "stoop":   # a street door up three steps, two windows
    R(BAY / 2 - 150, H - 640, BAY / 2 + 150, H - 90, (35, 35, 35))   # (a door 1.3 men tall)
    for k in range(3):
        R(BAY / 2 - 220 + k * 25, H - 90 + k * 30, BAY / 2 + 220 - k * 25, H - 60 + k * 30, (110, 110, 110))
    for b in (1, 2):
        cx = b * BAY + BAY / 2
        R(cx - WIN[0] / 2, H - 560, cx + WIN[0] / 2, H - 150, (45, 45, 45))
        R(cx - WIN[0] / 2 - 25, H - 150, cx + WIN[0] / 2 + 25, H - 125, (170, 170, 170))
elif GROUND == "warehouse":   # (QUEUE §23 station 8) a warehouse: a wide sliding loading door in the middle bay, over it on the
    # first floor a loading door with a hoist beam and its pulley above (the game hangs its swing rope from the wheel:
    # HOIST below), a small door and a window in the side bays
    R(BAY + 150, H - 600, 2 * BAY - 150, H, (35, 35, 35))                       # the sliding door
    R(BAY + 120, H - 640, 2 * BAY - 120, H - 600, (175, 175, 175))              # its rail
    R(BAY / 2 - 130, H - 560, BAY / 2 + 130, H, (35, 35, 35))                   # a side door
    cx = 2 * BAY + BAY / 2
    R(cx - WIN[0] / 2, H - 560, cx + WIN[0] / 2, H - 150, (45, 45, 45))
    f1 = CORNICE + 2 * STOREY                                                   # the first floor's floor line
    R(BAY + 60, f1 - STOREY + 40, 2 * BAY - 60, f1, (128, 128, 128))            # (plain wall where the grid drew a window)
    R(BAY + 300, f1 - 480, 2 * BAY - 300, f1, (30, 30, 30))                     # the loading door (over the window drawn there)
    R(BAY + 270, f1 - 30, 2 * BAY - 270, f1 + 10, (175, 175, 175))              # its sill
    R(BAY + 465, f1 - 640, BAY + 535, f1 - 590, (200, 200, 200))                # the hoist beam's end
    d.ellipse([(BAY + 455) * K, (f1 - 590) * K, (BAY + 545) * K, (f1 - 500) * K], fill=(215, 215, 215), outline=(20, 20, 20), width=3)   # the pulley wheel
else:                   # a shop front across two bays (sign band, big window, door), a plain window in the third
    R(60, gtop + 70, 2 * BAY - 60, gtop + 190, (95, 95, 95))
    R(80, gtop + 220, 2 * BAY - 330, H - 60, (50, 50, 50))
    R(2 * BAY - 330, gtop + 200, 2 * BAY - 80, H, (35, 35, 35))
    cx = 2 * BAY + BAY / 2
    R(cx - WIN[0] / 2, H - 560, cx + WIN[0] / 2, H - 150, (45, 45, 45))
im.save(__file__.replace("module_template.py", "templates/module_template_%s.png" % GROUND))
print(im.size)
