"""Layout sheet for a new character's parts (postavy/plan-novych-postav.md, step 2): grey shapes on pure green, each
part straight and upright, in strict profile facing right. Gemini redraws the approved design sheet's figure INTO these
shapes (it keeps a layout), gen/char_cut.py cuts them back out by BOX. Sizes: 1000 px = 1 m, a man 1.78 m.
usage: py -3 gen/char_template.py out.png"""
import sys
from PIL import Image, ImageDraw
W, H = 2752, 1536
G = (0, 255, 0)
GREY = (150, 150, 150)
# name: (x, y, w, h) of the part's box on the sheet
BOX = {"leg": (90, 250, 360, 1080), "torso": (560, 330, 520, 800), "head": (1190, 120, 440, 470),
       "uarm": (1740, 150, 230, 440), "farm": (2070, 120, 250, 520), "farm_open": (2420, 120, 250, 540),
       "hat": (1190, 760, 440, 200)}
def sheet(out):
    s = Image.new("RGB", (W, H), G)
    d = ImageDraw.Draw(s)
    x, y, w, h = BOX["leg"]          # a straight leg: hip at the top, the shoe pointing right
    d.rounded_rectangle((x + 40, y, x + 230, y + h - 60), 70, fill=GREY)
    d.rounded_rectangle((x + 40, y + h - 120, x + w, y + h), 45, fill=GREY)
    x, y, w, h = BOX["torso"]        # coat from the turned-up collar to the hem at the hip, no arms, no head
    d.rounded_rectangle((x + 70, y + 110, x + w - 40, y + h), 90, fill=GREY)
    d.polygon([(x + 150, y + 130), (x + 170, y), (x + 330, y + 20), (x + 380, y + 150)], fill=GREY)
    x, y, w, h = BOX["head"]         # bare head in profile with the neck
    d.ellipse((x + 70, y + 20, x + 370, y + 360), fill=GREY)
    d.rectangle((x + 150, y + 300, x + 290, y + h), fill=GREY)
    x, y, w, h = BOX["hat"]          # the hat alone
    d.ellipse((x, y + 110, x + w, y + h), fill=GREY)
    d.rounded_rectangle((x + 90, y, x + 350, y + 160), 40, fill=GREY)
    for n in ("uarm", "farm", "farm_open"):   # sleeves hanging straight down; the forearms end in a hand
        x, y, w, h = BOX[n]
        d.rounded_rectangle((x + 40, y, x + w - 40, y + h), 75, fill=GREY)
    s.save(out)
if __name__ == "__main__":
    sheet(sys.argv[1])
