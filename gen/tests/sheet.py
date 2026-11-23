"""Every picture in _shots/ newer than a minute (or matching a regex) on one contact sheet, _shots/sheet.png, each
cell labelled with its name - one image to look at instead of a dozen. usage: py gen/tests/sheet.py [regex] [cols]"""
import glob, os, re, sys, time
from PIL import Image, ImageDraw
pat = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else None
cols = int(sys.argv[2]) if len(sys.argv) > 2 else 3
root = os.path.join(os.path.dirname(__file__), "..", "..", "_shots")
files = sorted(p for p in glob.glob(os.path.join(root, "*.png")) if not p.endswith("sheet.png")
               and (re.search(pat, os.path.basename(p)) if pat else time.time() - os.path.getmtime(p) < 60))
if not files:
    print("sheet: no pictures"); sys.exit(0)
files = files[:24]
w = 1560 // cols
ims = []
for p in files:
    im = Image.open(p).convert("RGB")
    ims.append((os.path.basename(p)[:-4], im.resize((w, int(w * im.height / im.width)))))
h = max(im.height for _, im in ims)
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(ims):
    x, y = (i % cols) * w, (i // cols) * h
    sheet.paste(im, (x, y))
    d.rectangle((x, y, x + 8 * len(n) + 8, y + 16), fill=(0, 0, 0))
    d.text((x + 4, y + 2), n, fill=(255, 220, 80))
out = os.path.join(root, "sheet.png")
sheet.save(out)
print("sheet:", os.path.abspath(out), len(ims), "pictures")
