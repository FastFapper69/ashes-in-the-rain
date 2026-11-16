"""The tenement in cross-section (knowledge ch05, gen/QUEUE_doma.md §5): Gemini pieces from art_src cut to one
storey each, all the same size, so main.gd _build_sections can stack and join them.

Each piece is drawn 3168x1344 with the black cut of the slab above near its top and the black cut of its own floor
at the bottom. The storey kept is from the top of the slab above (where the storey above stands) down to where
its own floor turns black: SEC_ROWS rows, the boards walked on SEC_WALK rows above its bottom. Pieces whose slab
sits a few rows off are shifted onto the same rows, never stretched.

Run from the repo root: python gen/section_art.py [art_src dir]
"""
import os, sys
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Documents", "MobileGames", "Ink and Lead", "art_src")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "section")
SEC_ROWS = 1112          # one storey, top of the slab above to the top of its own black floor cut (a multiple of 4)
PIECES = {               # art_src number: name (main.gd SEC_KIT)
    212: "tenement_stairs_a",   # hallway with the stairs opening (doors 2A 2B)
    213: "tenement_hall_a",     # hallway, three doors, payphone
    214: "tenement_end",        # the building's outer wall on the left (no text: mirrored for the right end)
    215: "tenement_entry",      # ground floor, the street door through the left outer wall
    216: "tenement_stairs_b",   # hallway with the stairs opening left of middle
    217: "tenement_ladder",     # top storey: the ladder to the roof hatch, the outer wall on the right
    218: "tenement_facade",     # one storey of the front, seen from the street
    219: "tenement_facade_ground",   # the ground floor front, the street door on the left
    223: "tenement_flat",       # (220 had a solid partition: redrawn) an apartment kitchen: partition wall with the doorway on the left, the outer wall
}                               # cut through on the right with the window opening (door kick, window jump)


def slab_top(a):
    """First row of the black slab cut near the top (the floor of the storey above)."""
    m = np.median(a[:, 200:a.shape[1] - 200], axis=1)
    for r in range(40, 400):
        if m[r] < 20 and m[r + 20] < 20:
            return r
    raise ValueError("no slab")


os.makedirs(OUT, exist_ok=True)
for n, name in PIECES.items():
    p = os.path.join(SRC, f"{n}.jpg")
    if not os.path.exists(p):
        print("missing", p)
        continue
    im = Image.open(p).convert("RGB")
    assert im.size == (3168, 1344), (n, im.size)
    a = np.asarray(im.convert("L")).astype(float)
    top = slab_top(a) if not name.startswith("tenement_facade") else 118
    im.crop((0, top, 3168, top + SEC_ROWS)).save(os.path.join(OUT, name + ".png"))
    print(f"{n} -> {name}.png  slab at {top}")


# art_src 221: the two-state pieces on Gemini's flat green, four in a row: the flat's door seen edge-on whole and
# kicked in, the window's sash seen edge-on glazed and shattered. Keyed and cut apart at the green gaps; kept at
# the pieces' own scale (main.gd scales them like the storeys).
from scipy import ndimage
p = os.path.join(SRC, "221.png")   # (the 1024 px preview: Gemini served a broken full-size file)
if os.path.exists(p):
    a = np.asarray(Image.open(p).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] -= np.maximum(g - np.maximum(r, b), 0) * (1 - alpha * 0.5)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    cols = np.where(alpha.max(0) > 0.5)[0]
    runs, s0, prev = [], None, None
    for x in cols:
        if s0 is None: s0 = x
        elif x > prev + 25: runs.append((s0, prev)); s0 = x
        prev = x
    runs.append((s0, prev))
    names = ["flat_door", "flat_door_broken", "flat_glass", "flat_glass_broken"]
    assert len(runs) == 4, runs
    for (x0, x1), nm in zip(runs, names):
        im = Image.fromarray(rgba[:, x0 - 4:x1 + 5], "RGBA")
        im = im.crop(im.getbbox())
        im.save(os.path.join(OUT, nm + ".png"))
        print("221 ->", nm, im.size)


# art_src 222: the fire escape on the building's right side, seen side-on. Cut from the wall's outer face (x 570) and
# the top landing's deck (row 440, level with the roof) down to the street (row 2436): its landings then fall on the
# storeys at main.gd ESC_K = 1.0526 (gen/levels.py esc()).
p = os.path.join(SRC, "222.jpg")
if os.path.exists(p):
    im = Image.open(p).convert("RGB").crop((570, 440, 1536, 2436))
    im = im.crop((0, 0, im.width - im.width % 4, im.height - im.height % 4))
    im.save(os.path.join(OUT, "tenement_escape.png"))
    print("222 -> tenement_escape.png", im.size)
