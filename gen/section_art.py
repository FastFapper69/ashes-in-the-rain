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
}


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
