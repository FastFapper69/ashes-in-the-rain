"""Interiors longer than one building front (QUEUE §14 the laundry, 18. 11. the Blue Note): the front drawing is cut in two
and Gemini's middle stretch of the same building set between (processed by process_art.py as <front>_mid, full width):
  <front>_l = <front> [0, CUT)   its street door
  <front>_mid = <front>_mid [MID0, MID0 + MIDW)   no doors
  <front>_r = <front> [CUT, 3168)   its side door
Door to door = (CUT - d0 + MIDW + d1 - CUT) * 1.52 = the hall's length (gen/levels.py). Each part is its own street drawing
with its _lit and _solid layers (both stored at half size). The full-width middle is kept outside the game (art_src/derived)."""
import os, sys
from PIL import Image
from paths import SRC
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ST = os.path.join(ROOT, "art", "street")
FULL = os.path.join(SRC, "derived")
FRONTS = {"front_laundry": (2330, 110, 2888), "front_club": (2310, 264, 2639)}   # CUT, MID0, MIDW
def crop(src, dst, x0, x1, full=False):
    for suf, k in (("", 1), ("_lit", 2), ("_solid", 2)):
        im = Image.open(os.path.join(FULL if full else ST, src + suf + ".png"))
        im.crop((x0 // k, 0, x1 // k, im.height)).save(os.path.join(ST, dst + suf + ".png"))
for f in (sys.argv[1:] or FRONTS):
    cut, m0, mw = FRONTS[f]
    mid = os.path.join(ST, f + "_mid.png")
    if Image.open(mid).width == 3168:   # (process_art just wrote it at full width: kept outside as _full)
        os.makedirs(FULL, exist_ok=True)
        for suf in ("", "_lit", "_solid"):
            Image.open(os.path.join(ST, f + "_mid" + suf + ".png")).save(os.path.join(FULL, f + "_mid_full" + suf + ".png"))
    crop(f, f + "_l", 0, cut)
    crop(f + "_mid_full", f + "_mid", m0, m0 + mw, full=True)
    crop(f, f + "_r", cut, 3168)
    print(f, "parts", cut, mw, 3168 - cut)
