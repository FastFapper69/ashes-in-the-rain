"""The big laundry's street front (QUEUE §14): front_laundry cut between its shop window and its side door, Gemini's
middle stretch of the same building (art_src 290, processed by process_art.py as front_laundry_mid) set between:
  front_laundry_l   = front_laundry [0, CUT)            its street door at 696
  front_laundry_mid = 290           [MID0, MID0 + MIDW) no doors, drainpipes at both cuts
  front_laundry_r   = front_laundry [CUT, 3168)         its side door at 2472 - CUT
Door to door: (CUT - 696 + MIDW + 2472 - CUT) * 1.52 = the hall's length (gen/levels.py LAUNDRY_W). Each part is its
own street drawing (with its _lit and _solid layers, both stored at half size), so main.gd shows exactly that part."""
import os
from PIL import Image
from paths import SRC
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ST = os.path.join(ROOT, "art", "street")
CUT, MID0, MIDW = 2330, 110, 2888
FULL = os.path.join(SRC, "derived")   # (outside the game: Godot would import it)
def crop(src, dst, x0, x1):
    for suf, k in (("", 1), ("_lit", 2), ("_solid", 2)):
        im = Image.open(os.path.join(FULL if src.endswith("_full") else ST, src + suf + ".png"))
        im.crop((x0 // k, 0, x1 // k, im.height)).save(os.path.join(ST, dst + suf + ".png"))
if os.path.getsize(os.path.join(ST, "front_laundry_mid.png")) > 0 and Image.open(os.path.join(ST, "front_laundry_mid.png")).width == 3168:
    # (process_art just wrote front_laundry_mid at full width: kept outside as _full, the part cut from it)
    os.makedirs(FULL, exist_ok=True)
    for suf in ("", "_lit", "_solid"):
        Image.open(os.path.join(ST, "front_laundry_mid" + suf + ".png")).save(os.path.join(FULL, "front_laundry_mid_full" + suf + ".png"))
crop("front_laundry", "front_laundry_l", 0, CUT)
crop("front_laundry_mid_full", "front_laundry_mid", MID0, MID0 + MIDW)
crop("front_laundry", "front_laundry_r", CUT, 3168)
print("doors apart", (CUT - 696 + MIDW + 2472 - CUT) * 1.52)
