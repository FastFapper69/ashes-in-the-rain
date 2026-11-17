# Level generator for INK & LEAD.
# A map is a run of hand-made chunks (street fights, interiors, fire escapes, arenas), placed one after
# another by a seeded generator to a difficulty curve, then checked (nothing overlaps, every floor can be
# reached, nobody floats) and drawn as a map for review. Output: levels.gd, a GDScript data file.
#
# Run:  python3 gen/levels.py [out.gd]     maps are drawn to $ASHES_SIM or _shots/sim/map_*.png
import os, random, sys
SIM = os.environ.get("ASHES_SIM", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_shots", "sim"))   # the map drawings (git-ignored)
REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
from PIL import Image, ImageDraw

# kind: (width, height, wood?)  wood breaks under fire, the rest holds; barrel explodes
BOX = {"crate": (250, 248, True), "drum": (160, 246, False), "crate_long": (330, 176, True), "dumpster": (300, 250, False),
       "barrel": (120, 170, False), "machine": (260, 230, False), "bar": (420, 190, False),
       "stack": (330, 393, False)}   # a crate set on a long crate on the quay: too tall to jump, the rope goes over it
# the drawn street segments (art/street) and their widths in the world (picture width x 1.9)
SEGMENTS = {"alley": 3028, "bluenote": 3028, "warehouse": 3028, "laundry": 3028, "subway": 3108, "church": 3108, "market": 3038, "deadend": 3038,
            "pier17": 3034, "cranes": 3034, "shipping": 3034, "quay": 3034, "harbor": 3034,
            "platform": 3034, "tunnel": 3034, "yard": 3034, "station14": 3034,
            "tenrow_a": 3043, "tenrow_b": 3043, "tenrow_c": 3043, "tenrow_d": 3043,
            "bowery": 3034, "walkway": 3034, "pump": 3034, "tunnel_lo": 3034,
            "signal": 3034, "arches": 3034, "sheds": 3043,
            "fire_a": 2652, "fire_b": 2652, "fire_c": 2652}
# the subway drawings came out at twice a man's size (doors 2.5 men high, the far platform at his head):
# shown at half, the wall above them runs on into the dark of the ceiling
SUB = 0.52
SEG_SIZE = {"deadend": 0.8, "tenrow_a": 0.675, "tenrow_b": 0.675, "tenrow_c": 0.675, "tenrow_d": 0.675, "station14": SUB, "walkway": SUB, "bowery": SUB, "tunnel_lo": SUB,
            "signal": SUB, "arches": SUB, "sheds": 0.55, "fire_a": 0.605, "fire_b": 0.605, "fire_c": 0.605}
UNDER_ROOF = ["tenrow_a", "tenrow_c", "tenrow_b", "tenrow_d"]   # the facades under the rooftops: their cornice meets the roof drawings   # shown smaller: see main.gd SEGMENT_SIZE
STREET_POOL = ["hk_tailor", "hk_grocery", "hk_saloon", "hk_laundry",   # (the kit: gen/kit.py)
               "alley_mouth", "warehouse", "laundry", "subway", "church_row", "market_row",   # (chapter I on one kit, 17. 11.: alley/alley_b -> alley_mouth,
               "warehouse_b", "laundry_b", "subway_b"]                      # market/_b/_c -> market_row, church/_b -> church_row)
DOCKS_POOL = ["pier17", "cranes", "shipping", "quay", "sheds", "pier17_b", "shipping_b", "quay_b", "sheds_b"]   # (the harbor with its lighthouse: only the Harbor Master's own)
# variants (2026-11-15): the same kit redrawn with other details over the same floor, rails, edges and lamps,
# so a map does not show one drawing again and again; everything about them but the picture is the kit's
KIT = {"walkway_b": "walkway", "signal_b": "signal", "arches_b": "arches", "tunnel_lo_b": "tunnel_lo",
       "yard_b": "yard", "tunnel_b": "tunnel", "sheds_b": "sheds", "pier17_b": "pier17", "shipping_b": "shipping", "quay_b": "quay",
       "laundry_b": "laundry", "alley_b": "alley", "warehouse_b": "warehouse", "warehouse_c": "warehouse", "church_b": "church", "subway_b": "subway", "market_b": "market", "market_c": "market", "yard_c": "yard", "tunnel_c": "tunnel",
       # the dream's rooms gone wrong (gen/process_dream.py): the burning warehouse's own cut and floor
       "fire_d": "fire_a", "fire_e": "fire_b", "fire_f": "fire_c", "fire_g": "fire_a"}
for _v, _k in KIT.items():
    SEGMENTS[_v] = SEGMENTS[_k]
    if _k in SEG_SIZE:
        SEG_SIZE[_v] = SEG_SIZE[_k]
UNDER_POOL = ["walkway", "tunnel_lo", "signal", "arches", "walkway_b", "signal_b", "arches_b", "tunnel_lo_b"]   # the pump room (art_src 106) is drawn at four times a man: not used
TRACKLESS = {"pump", "arches", "arches_b"}   # (the arches have a handcar standing on the rails)   # no rails in the drawing: a passing train may not be in sight of it
CRANE_CRATE = (0.3863 + 0.0783 / 2)   # where the crate hangs in the crane yard drawing (see main.gd CRANE_CUT)
F1, F2 = -370.0, -740.0   # floor heights: first and second storey
JUMP_REACH = 282.0
LAND_W = [547, 748, 949, 1149]   # the baked fire-escape landings (gen/iron.py)
STAIR_RUN = 261                  # one storey of the iron stairs
# The rooftops (2026-11-14): a scaffold of four storeys climbed by ladders up to the roofs, then back
# along them the other way. The roof drawings (art/street/roof_*.png) are shown at half the street's
# scale, their walked line at ROOF_Y: low enough that their cornice hides the tops of the facades.
ROOF_Y = -1794.0
STOREY = ROOF_Y / 4.0
SCAF_BAY = 769.0          # one bay of scaffolding (main.gd _scaffold)
ROOF_PIC = 3168 * 0.95    # a roof drawing in the world
ROOF_STUB = 190 * 0.95    # the firewall at its right edge, left off where the next roof joins on
# An upper floor a map climbs to and walks back along: its drawings, their scale (world px per picture px),
# the walked line as a share of the picture's height, the stub at the right edge left off at a join,
# the floor's height, what stands past both ends, and where the way out is (share of the far drawing).
KITS = {
    # the roof over a building seen in cross-section (2026-11-16): three storeys of SEC_H, the roof on the third
    "troof": {"scale": 0.95, "line": 0.828, "stub": 190, "y": -2100.0, "deco": None, "goal": None, "under": True},
    "roof": {"scale": 0.95, "line": 0.828, "stub": 190, "y": ROOF_Y, "deco": None, "goal": None, "under": True},
    # the mezzanine over the platforms: the subway drawings at their half size; its floor on their ceiling
    "mezz": {"scale": 1.9 * 0.52, "line": 0.94, "stub": 134, "y": -1318.0, "deco": "mezz_a", "goal": 0.55, "under": False},
}
# the station stairs (art/props/station_stairs.png, art_src 118): treads from (168, 1258) up to the
# landing at (2352, 255) in the picture; drawn so they rise exactly onto the mezzanine
STAIR_FOOT = (168.0, 1258.0)
STAIR_TOP = (2352.0, 255.0)
# A building in cross-section ("řez domem", 2026-11-16): its front wall cut away, the storeys stacked and the
# way up zigzags: in at the street door, right along the ground floor, the stairs up, left along the first
# floor, the stairs up, right along the second, the ladder to the roof hatch, then the roof back left.
# A storey is SEC_H (a man is ~420 px, a door ~520).
# The stairs are in the BACK wall (user's choice 16. 11.): an opening with the flight going up into the dark;
# he goes in, the camera follows him up a storey, he comes out of the opening above at the same x. A flight
# drawn side-on cannot zigzag (the next storey would walk over it). Stand-in: the stairs painted in
# art/rooms/tenement.png; main.gd _build_sections puts them where these doors are.
SEC_H = 700.0
# The tenement kit (gen/section_art.py, main.gd SEC_KIT_*): two pieces of 3168 px at 700/1112 make a storey;
# x0 is the street door in the facade, 510 px into the first piece. Where its pieces paint them:
SEC_W = 3370.0           # x0 to the building's outer face on the right (the end walls' and the flat's brick)
SEC_STAIRS_A = 2592.0    # the opening in tenement_stairs_a (second piece, ground and first floor)
SEC_STAIRS_B = 371.0     # the opening in tenement_stairs_b (first piece, first and second floor)
SEC_LADDER = 2935.0      # the ladder to the roof hatch in tenement_ladder (not used while the top floor ends in the flat)
# The flat at the right end of the top storey (tenement_flat, art_src 223) and the fire escape outside it (art_src 222):
# kick in its door under the partition's lintel, out of its window onto the escape, up the escape to the roof.
SEC_FLAT_DOOR = 1778.0   # the doorway under the lintel (door leaf 476 high)
SEC_WIN = (3195.0, 3340.0)   # the window through the outer wall: inner face, outer face; sill 178, lintel 501 above the floor
ESC_K = 1.0526           # the escape drawing's pixels to the world (its landings fall on the storeys)
def esc(px): return SEC_WIN[1] + (px - 570.0) * ESC_K   # its picture's x (570 = the wall's outer face) in the chunk
SEC_CLEAR = [(-60.0, 300.0), (1767.0, 2000.0), (2259.0, 2692.0), (2963.0, 3200.0)]   # ground floor, from x0: the street
#   door's open leaf, door 2A, the stairs opening, door 2B
TRIM = {"alley": 134, "bluenote": 134, "warehouse": 133, "laundry": 133, "subway": 53, "church": 58, "market": 58, "deadend": 58,
        "sheds": 112, "tenrow_a": 0, "tenrow_b": 0, "tenrow_c": 0, "tenrow_d": 0, "fire_a": 0, "fire_b": 0, "fire_c": 0}   # = main.gd SEGMENT_TRIM (by kit; else 132)
_MASKS = {}


def facade(street, xa, xb, ya, yb):
    """How much of that stretch of the street is solid wall in the drawings (0..1): a fire escape is
    bolted to a building, never hung in front of the sky or an alley's mouth."""
    import numpy as np
    tot = n = 0.0
    for i, (name, x0) in enumerate(street):
        w = SEGMENTS[name]; trim = TRIM.get(KIT.get(name, name), 132); sx = w / (w - trim)
        x1 = x0 + w * 1.9
        a, b = max(xa, x0), min(xb, x1)
        if b <= a: continue
        if name not in _MASKS:
            _MASKS[name] = np.asarray(Image.open(os.path.join(REPO, "art", "street", f"{name}_solid.png")))[..., 3] > 128
        m = _MASKS[name]
        cx = lambda wx: int(((wx - x0) / (1.9 * sx) + trim) / 2)
        cy = lambda wy: int(((wy + 1344 * 1.9 * 0.92 + 60) / 1.9) / 2)
        cut = m[max(0, cy(ya)):max(1, cy(yb)), max(0, cx(a)):max(1, cx(b))]
        if cut.size:
            tot += cut.mean() * (b - a); n += (b - a)
    return tot / n if n else 0.0


class Chunk:
    def __init__(self, width):
        self.w = width
        self.boxes, self.plats, self.ramps, self.rooms, self.lamps = [], [], [], [], []
        self.enemies, self.pickups, self.hints, self.checks = [], [], [], []
        self.stand = None
        self.end = 0.0
        self.street = []
        self.events = []
        self.iron = []
        self.ropes = []
        self.scaf = False
        self.up_end = None     # where the floor above starts, past the top of the way up
        self.roof = None       # [x0, x1] of the walked roof, its drawings [[name, x0]], the goal x
        self.roof_checks = []
        self.sections = []     # buildings in cross-section: [x0, x1, storeys, style]
        self.xy_checks = []    # checkpoints up in a building: [x, y]
        self.stairdoors = []   # the stairs in a building's back wall: [x, storey y, the y they lead to]
        self.hoists = []       # where a swing rope is wanted from a warehouse hoist (hoist_ropes)
        self.kits = []         # (x, piece): a street-kit drawing wanted with its things at x (kit_pieces)
        self.things = []       # [kind, x]: a free-standing thing to shoot (props.gd place: windlass...), its foot on the street
        self.flats = []        # a flat to kick into and jump out of: [door x, storey y, door h, window x0, x1, sill, lintel]

    def thing(self, kind, x): self.things.append([kind, x]); return self
    def box(self, kind, x, y=0.0): self.boxes.append([kind, x, y] if y else [kind, x]); return self
    def plat(self, x, y, w, style="catwalk"): self.plats.append([x, y, w, style]); return self
    def ramp(self, x0, y0, x1, y1): self.ramps.append([x0, y0, x1, y1]); return self
    def room(self, x0, x1, style): self.rooms.append([x0, x1, style]); self.checks += [x0 - 60]; return self
    def lamp(self, x, y=-760.0): self.lamps.append([x, y]); return self
    def pick(self, kind, x, y=0.0): self.pickups.append([kind, x, y]); return self
    def hint(self, x, text): self.hints.append([x, text]); return self
    # Ropes (main.gd _ropes): "climb" from a landing's rail at (x, y0) down to the street; "zip" a cable from the
    # roof that passes over a landing at (x0, y0) and is made fast at the street at (x1, 0); "swing" a rope from a
    # crane jib out of the picture, hanging at x.
    def rope(self, kind, x0, y0=0.0, x1=0.0, y1=0.0): self.ropes.append([kind, x0, y0, x1, y1]); return self
    def event(self, *ev): self.events.append(list(ev)); return self

    def foe(self, x, y=0.0, kind="post", trig=None, frm=None, delay=0.0, run=False):
        self.enemies.append({"x": x, "y": y, "kind": kind, "trig": trig, "from": frm, "delay": delay, "run": run}); return self

    def runner(self, x, trig, frm, kind="post", delay=0.0, y=0.0):
        return self.foe(x, y, kind, trig, frm, delay, True)


# ---- rooms: how they are furnished (2026-11-16) -------------------------------------------------
# Every interior is furnished anew where it stands (no two rooms of a kind alike), by these rules:
# - nothing in front of a door, an arch, a passage or a ladder painted in the room (ROOM_CLEAR, in the
#   drawing's own pixels: main.gd _build_room shows it at ROOM_SCALE, centred, never repeated: past its width the room is dark);
# - a step clear of the way in and the far wall; a man's width at least between two things;
# - never the same thing twice side by side, at most one of the big machines, a red barrel only where
#   fuel is kept (BARREL_OK);
# - the men stand behind the cover, on its far side from the door (Frank comes in from the left).
ROOM_PIC_W, ROOM_SCALE = 3168, 0.75
ROOM_CLEAR = {"laundry": [(1630, 1915), (1975, 2345)],   # the EXIT door, the doorway to the back
              "warehouse": [(1750, 2395)],                # the loading bay with the truck
              "club": [(90, 1317), (1380, 1810)],         # the bar counter (BAR_PX), the arch to the back (art_src 245)
              "hold": [(1670, 1925)],                     # the ladder up to the hatch
              "office": [(90, 230)],                      # the door
              "cityhall": [(1230, 1830)],                 # the two tunnel mouths
              "catacombs": [(2230, 2960)],                # the stage under the arch
              "tenement": [(970, 1370), (1770, 2210)]}    # the open door of 3B, the stairs
ROOM_KINDS = {"laundry": ["machine", "crate", "crate_long", "drum"], "warehouse": ["crate", "crate_long", "barrel", "drum"],
              "club": ["crate", "crate_long"], "hold": ["crate", "crate_long", "drum", "barrel"],
              "office": ["crate_long", "machine", "crate"], "cityhall": ["crate", "machine", "crate_long"],
              "catacombs": ["crate", "crate_long"], "tenement": ["crate", "crate_long"]}
BIG = ("machine",)


# The Blue Note's bar counter (art/props/bar_counter.png, main.gd draws it for a floor of style "bar"): in front of the
# room drawing's back bar, drawing px BAR_PX; its top (24 % down the sprite) is the floor, BAR_TOP above the boards.
BAR_PX = (90, 1317)
BAR_TOP = 175.0   # (low enough to jump onto: a plain jump lifts his feet ~200; the drawing is stretched along to fit)
def bar_floor(x0, w):
    pic = ROOM_PIC_W * ROOM_SCALE
    off = (w - pic) / 2
    a, b = BAR_PX[0] * ROOM_SCALE + off, BAR_PX[1] * ROOM_SCALE + off
    return [x0 + a, -BAR_TOP, b - a, "bar"]


def _room_src(style, w, x):
    """Where room-x x falls in the room's drawing (its own pixels)."""
    pic = ROOM_PIC_W * ROOM_SCALE
    if w > pic:   # wider than its drawing: the drawing in the middle, dark at both ends (never repeated)
        return (x - (w - pic) / 2) / ROOM_SCALE
    off = (ROOM_PIC_W - w / ROOM_SCALE) / 2
    return off + x / ROOM_SCALE


def _room_free(style, w, a, b):
    for k in range(int(a), int(b) + 1, 20):
        sx = _room_src(style, w, k)
        if any(c0 - 60 <= sx <= c1 + 60 for c0, c1 in ROOM_CLEAR.get(style, [])):
            return False
    return True


def furnish(c, style, rng, foes, flask=False):
    w = c.rooms[0][1] - c.rooms[0][0]
    kinds = ROOM_KINDS[style]
    put, last, x = [], None, rng.uniform(430, 600)
    while True:
        opts = [k for k in kinds if k != last and not (k in BIG and any(p[0] == k for p in put))
                and not (k == "barrel" and any(p[0] == "barrel" for p in put))]
        kind = rng.choice(opts)
        bw = BOX[kind][0]
        tries = 0
        while not _room_free(style, w, x, x + bw) and tries < 60:
            x += 40; tries += 1
        if x + bw > w - 380:
            break
        put.append((kind, x))
        last = kind
        x += bw + rng.uniform(430, 680)
    if put and put[0][0] == "barrel":   # the first thing in the door is cover, not a bomb at his elbow
        nxt = put[1][0] if len(put) > 1 else None
        put[0] = ([k for k in kinds if k not in ("barrel", nxt) and k not in BIG] or ["crate"])[0], put[0][1]
    for kind, bx in put:
        c.box(kind, bx)
    # the men: each behind a piece of cover, from the second on (the first is Frank's); the rest at the back
    spots = [bx + BOX[k][0] + rng.uniform(110, 170) for k, bx in put[1:]] + [bx + BOX[k][0] + 130 for k, bx in put[:1]]
    for i, kind in enumerate(foes):
        x = spots[i] if i < len(spots) else w - 250 - 300 * (i - len(spots))
        if any(bx - 60 < x < bx + BOX[k][0] + 60 for k, bx in put):
            x = w - 220
        c.foe(min(x, w - 200), kind=kind)
    if flask:   # a flask on the floor between the first two pieces
        a = put[0][1] + BOX[put[0][0]][0] + 60 if put else 600
        c.pick("flask", a)


def chunk(name, hard, rng=None):
    rng = rng or random.Random(7)
    c = None
    if name == "crate_cover":
        c = Chunk(1300).box("crate", 0).foe(450)
        if hard > 0.4: c.foe(1100)
    elif name == "drum_duo":
        c = Chunk(1500).box("drum", 200).box("crate", 900).foe(560).foe(1350, kind="tommy" if hard > 0.6 else "post")
    elif name == "barrel_trap":   # three of them gathered round a red barrel: one shot
        c = Chunk(1600).box("crate", 0).box("barrel", 760).foe(620).foe(940).foe(1050)
        if hard > 0.5: c.foe(1450, kind="tommy")
    elif name == "dumpster_alley":
        c = Chunk(1600).box("dumpster", 300).foe(820).runner(1400, 150, 2900)
    elif name == "ambush_behind":
        c = Chunk(1500).box("crate", 1100).runner(-350, 700, -1500).runner(-150, 760, -1700, kind="shotgun" if hard > 0.5 else "post")
    elif name == "gauntlet":   # three pieces of cover in a row, not three of the same
        k1 = rng.choice(["crate_long", "drum"]); k2 = rng.choice([k for k in ("crate", "dumpster", "crate_long") if k != k1])
        c = Chunk(2100).box("crate", 0).box(k1, 760).box(k2, 1500).foe(450).foe(1210, kind="shotgun" if hard > 0.6 else "post").foe(1950)
    elif name == "rush":
        n = 3 if hard > 0.6 else 2
        c = Chunk(1500).box("crate", 250)
        for i in range(n):
            c.runner(1000 + i * 260, 0, 2600 + i * 300, kind="shotgun" if i == 2 else "post")
    elif name == "catwalk":   # up the long crate onto the walkway, then down its cable into them
        c = (Chunk(2900).box("crate_long", 0).plat(400, F1, LAND_W[3]).foe(900, F1).foe(1500)
             .rope("zip", 400 + LAND_W[3] - 60, F1, 400 + LAND_W[3] + 1000, 0.0).foe(2300))   # (its mast and winch: main.gd _add_rope)
        if hard > 0.5: c.foe(1250, F1)
    elif name == "high_ground":
        c = (Chunk(2200).box("crate_long", 0).box("drum", 1450).plat(380, F1, LAND_W[3]).foe(800, F1).foe(1300, F1, kind="tommy" if hard > 0.6 else "post").foe(1780)
             .rope("ladder", 380 + LAND_W[3] - 70, F1, 0, 0.0))   # (a ladder up the trestle: a rope knotted to its rail hung there for no reason)
    elif name == "fire_escape":   # the tailor's painted fire escape (gen/kit.py hk_tailor): up the drop ladder,
        # men on both landings (the kit's "men"), the awning beside it throws him up to the top one. The game no
        # longer builds a fire escape of its own in front of a drawing (user 17. 11.: it never fitted the picture).
        c = (Chunk(4800).foe(1900, 0.0).foe(3700, 0.0, kind="tommy" if hard > 0.5 else "post"))
        if hard > 0.6: c.foe(4200, 0.0, kind="shotgun")
        c.kits.append((2400.0, "hk_tailor"))   # its fire escape here (kit_pieces)
        c.hint(1200, "JUMP AT THE LADDER TO CLIMB IT")
    elif name == "scaffold":   # a building under repair: four storeys of planks, a ladder up each, the zigzag to the roof
        w = SCAF_BAY * 2
        c = Chunk(w + 400)
        for k in (1, 2, 3):
            c.plat(0, STOREY * k, w, "scaffold")
        c.rope("ladder", 150, STOREY, 0, 0.0).rope("ladder", w - 150, STOREY * 2, 0, STOREY)
        c.rope("ladder", 150, STOREY * 3, 0, STOREY * 2).rope("ladder", w - 150, ROOF_Y, 0, STOREY * 3)
        c.foe(1050, STOREY).foe(600, STOREY * 2, kind="tommy" if hard > 0.5 else "post").foe(1100, STOREY * 3)
        c.foe(w + 250)
        c.hint(-500, "JUMP AT A LADDER TO CLIMB IT")
        c.scaf = True
        c.up_end = w + 250.0
    elif name == "section":   # a tenement cut open: three storeys, the stairs zigzag up, the hatch to the roof
        w = SEC_W
        c = Chunk(w + 1000)
        c.sections.append([0.0, w, 3, "tenement"])
        for k in (1, 2):
            c.plat(0.0, -SEC_H * k, w, "section")
        r, l = SEC_STAIRS_A, SEC_STAIRS_B
        c.stairdoors += [[r, 0.0, -SEC_H], [r, -SEC_H, 0.0],                   # ground floor: up at the right
                         [l, -SEC_H, -SEC_H * 2], [l, -SEC_H * 2, -SEC_H]]     # first floor: up at the left
        # second floor: along to the flat, kick in its door, out of the window onto the fire escape, up it to the roof
        c.flats.append([SEC_FLAT_DOOR, -SEC_H * 2, 476.0, SEC_WIN[0], SEC_WIN[1], 178.0, 501.0])
        e0 = esc(570.0)
        for k in (1, 2, 3):                                                  # the escape's three landings
            c.plat(e0, -SEC_H * k, esc(1160.0) - e0, "fescape")   # (the deck's drawn outer end, under the railing)
        c.ramps.append([esc(820.0), -SEC_H, esc(1050.0), -SEC_H * 2, "fescape"])      # its flights, as drawn
        c.ramps.append([esc(790.0), -SEC_H * 2, esc(1050.0), -SEC_H * 3, "fescape"])
        c.foe(1200).foe(2100, kind="shotgun" if hard > 0.6 else "post")
        c.foe(1800, -SEC_H).foe(1000 + 450, -SEC_H, kind="tommy" if hard > 0.5 else "post")   # never at the head of the stairs:
        c.foe(1250, -SEC_H * 2)                                                                 # 750+ from where he comes out
        c.foe(2350, -SEC_H * 2).foe(2850, -SEC_H * 2, kind="shotgun" if hard > 0.4 else "post")  # in the flat, behind the door
        c.xy_checks += [[esc(700.0), -SEC_H * 2]]
        c.xy_checks += [[r, -SEC_H], [l, -SEC_H * 2]]
        c.checks += [-60.0]
        c.hint(-400, "INSIDE, UP THE STAIRS")
        c.up_end = esc(1050.0)   # the roof reaches out to where the fire escape's top flight arrives
    elif name == "stunts":   # SANDBOX STUNTS: the new moves in a few seconds - one storey, the flat right by the door,
        w = SEC_W            # kick its door in (a man behind it), out of its window to the street, the rope behind
        c = Chunk(w + 2600)
        c.sections.append([0.0, w, 1, "tenement_stunt"])
        c.flats.append([SEC_FLAT_DOOR, 0.0, 476.0, SEC_WIN[0], SEC_WIN[1], 178.0, 501.0])
        c.foe(SEC_FLAT_DOOR + 180).foe(2800, kind="shotgun")
        c.checks += [-60.0]
        c.hint(-400, "RUN AT THE DOOR")
    elif name == "lab":   # SANDBOX LAB: a long empty street for the street kit's things, set by the LAB's fixed street
        c = Chunk(25500)
        c.hint(300, "TEST LAB")
        c.box("stack", 1300).hint(800, "JUMP INTO THE STACK, JUMP AGAIN TO KICK OFF IT")   # the wall kick (ch II stunt)
        c.thing("windlass", 8500).foe(9150).hint(7900, "SHOOT THE WINDLASS")   # the docks' anchor windlass (ch II hazard)
        c.thing("trolley", 14600).foe(15300).hint(14000, "SHOOT THE INSULATOR")   # the trolley wire into a puddle (ch III hazard)
        c.thing("thirdrail", 22300).foe(23000).hint(21700, "SHOOT THE JUNCTION BOX")   # the third rail (ch III hazard)
        c.hoists.append(19400)   # the hoist rope: the warehouse near the end of the lab street (before the flat)
    elif name == "stairs_up":   # the end of the platform: the stairs up to the mezzanine, the way out
        k = -KITS["mezz"]["y"] / (STAIR_FOOT[1] - STAIR_TOP[1])
        run = (STAIR_TOP[0] - STAIR_FOOT[0]) * k
        c = Chunk(run + 900).foe(300).foe(run * 0.35, kind="shotgun" if hard > 0.5 else "post")
        c.ramps.append([0.0, 0.0, run, KITS["mezz"]["y"], "station"])
        c.up_end = run + 300.0
    elif name == "laundry":   # an interior: machines for cover, steam, a shotgunner in the back
        c = Chunk(2700).room(0, 2700, "laundry").lamp(400).lamp(1250).lamp(2150)
        furnish(c, "laundry", rng, ["post", "shotgun", "post"], flask=True)
    elif name == "warehouse_arena":   # a locked room: waves through both doors
        c = (Chunk(2400).room(0, 2400, "warehouse").lamp(700).lamp(1700)
             .runner(2050, 300, 2900).runner(2250, 300, 3100)
             .runner(300, 300, -900, delay=5.0).runner(1400, 300, 3000, kind="tommy", delay=9.0)
             .runner(150, 300, -1100, kind="shotgun", delay=13.0).pick("tommy", 1000))
        furnish(c, "warehouse", rng, [])
    elif name == "tenement":   # the third-floor hallway: the drawing has no landing, so the fight is on its boards
        c = Chunk(2300).room(0, 2300, "tenement")
        furnish(c, "tenement", rng, ["post", "shotgun" if hard > 0.5 else "post", "post"], flask=True)
    elif name == "club":   # the Blue Note: the bar for cover, tables, a stage at the back
        c = Chunk(2600).room(0, 2600, "club").lamp(500).lamp(1400).lamp(2300).runner(1100, 900, -800, delay=2.0)
        c.plats.append(bar_floor(0, 2600))   # the bar counter along the back bar: dive onto it and skid its length
        furnish(c, "club", rng, ["post", "shotgun", "tommy"])
    # ---- the docks -------------------------------------------------------------------------------
    elif name == "live_wire":   # a trolley pole over a puddle, two of them standing in it (ch III hazard, art_src 242)
        c = Chunk(2300).box("crate", 0).thing("trolley", 700).foe(1100).foe(1450, kind="tommy" if hard > 0.5 else "post").foe(2150)
    elif name == "dock_crates":   # cargo waiting on the quay, and them behind it
        # the anchor windlass (ch II hazard, art_src 241): shot, its brake snaps and the chain lashes out to the right
        c = Chunk(1700).box("crate_long", 0).box("crate", 700).thing("windlass", 1180).foe(500).foe(1100).foe(1700, kind="tommy" if hard > 0.5 else "post")
    elif name == "car_ambush":   # a sedan pulls up ahead and three of them pile out behind it
        c = Chunk(2700).box("crate", 0).foe(700).event("car", 350, 2000, 1, 3)
    elif name == "searchlight_yard":   # a searchlight on a pole sweeps the yard: in it, they do not miss
        c = (Chunk(2300).box("crate", 200).box("crate_long", 1150).foe(750).foe(1650).foe(2150, kind="shotgun" if hard > 0.5 else "post")
             .event("searchlight", 1150, -820, 28))
    elif name == "blackout":   # the power goes: only muzzle flashes, and they cannot see him either
        c = (Chunk(2100).box("dumpster", 300).box("crate", 1350).foe(950).foe(1850, kind="tommy").runner(1150, 400, 3200)
             .event("blackout", 120, 10))
    elif name == "hold":   # below decks on the Santa Lucia: crates lashed down, lamps swinging
        c = Chunk(2700).room(0, 2700, "hold").lamp(500).lamp(1400).lamp(2250)
        furnish(c, "hold", rng, ["post", "shotgun", "tommy" if hard > 0.5 else "post"], flask=True)
    elif name == "office":   # the harbor master's: filing cabinets and a counter for cover
        c = Chunk(2400).room(0, 2400, "office").lamp(600).lamp(1700)
        furnish(c, "office", rng, ["post", "shotgun", "post"], flask=True)
    elif name == "crane_swing":   # a wall of cargo too tall to climb: a crane's rope hangs before it, and them behind it
        c = (Chunk(2400).rope("swing", 380).box("stack", 900).box("crate", 1330)
             .foe(1950).foe(2300, kind="shotgun" if hard > 0.5 else "post")
             .hint(-100, "JUMP FOR THE CRANE ROPE"))
    # ---- underground --------------------------------------------------------------------------------
    elif name == "train_platform":   # along the tracks under the platform edge; a train roars by on the far rails
        c = (Chunk(2400).box("drum", 250).box("crate_long", 1100).foe(700).foe(1650, kind="shotgun" if hard > 0.5 else "post").foe(2250)
             .event("train_pass", 300).thing("thirdrail", 1480))   # the third rail behind the two by the far end (ch III hazard, art_src 244)
    elif name == "cityhall":   # the closed station: chandeliers, boarded booths, rain through the skylight
        c = Chunk(2600).room(0, 2600, "cityhall").lamp(700).lamp(1800)
        furnish(c, "cityhall", rng, ["post", "tommy" if hard > 0.4 else "post", "post"], flask=True)
    elif name == "catacombs":   # the speakeasy in the sewer vaults: the bar and the tables for cover
        c = Chunk(2800).room(0, 2800, "catacombs").lamp(500).lamp(1500).lamp(2400)
        furnish(c, "catacombs", rng, ["post", "shotgun", "tommy" if hard > 0.5 else "post"])
    elif name == "roof_vents":   # on top of the moving train: the vent housings are all the cover there is
        c = Chunk(2000).foe(950).foe(1850, kind="tommy" if hard > 0.5 else "post")
    elif name == "roof_rush":   # they climb up from the cars behind and in front
        c = Chunk(1800).foe(300).runner(1200, 100, 2900).runner(1500, 200, 3200, kind="shotgun").runner(-200, 600, -1400)
    elif name == "breather":
        c = Chunk(700)
    # the nightmare (2026-11-15): Pier 17's warehouse burning in 1939. The men are shadows of the ones who
    # set it; the fire itself does the rest: beams come down out of the roof, the floor burns in strips.
    elif name == "arsonists":
        c = Chunk(1500).box("crate", 200).foe(800).foe(1300, kind="shotgun" if hard > 0.5 else "post")
    elif name == "beam_fall":   # the roof creaks, dust comes down, then a burning truss across the floor
        c = Chunk(1400).event("beam", 700).box("drum", 1150)
    elif name == "blaze":   # a strip of burning floor: over it, not through it
        c = Chunk(1300).event("blaze", 450, 380).foe(1100)
    elif name == "smoke_men":   # out of the smoke, from both sides
        c = Chunk(1600).box("crate", 600).runner(1300, 200, 2600).runner(-200, 500, -1400)
    elif name == "loop":   # the dream starts over: the same room, worse
        c = Chunk(600).event("loop", 300)
    elif name == "pistols_cache":   # a dead man's guns on the pavement
        c = Chunk(900).pick("pistols", 450)
    if c is None:
        raise ValueError(name)
    return c


def build(mp):
    """Built again with the ironwork moved along until every fire escape hangs on solid wall."""
    nudge = {}
    plain = dict(mp, plain=True)   # the layout is found on the kits alone, so the variants never move a fight
    for tries in range(60):
        m = _build(plain, nudge)
        bad = [i for i, xa, xb, ya, yb in m.iron if facade(m.street, xa, xb, ya, yb) < 0.93]
        if not bad or mp.get("pool") is DOCKS_POOL:
            break
        nudge[bad[0]] = nudge.get(bad[0], 0) + 160
    else:
        print("  no wall found for the ironwork of", mp["name"])
        return m
    # the same map with the variants among the drawings; where a fire escape would hang in front of a
    # variant's sky, the kit's own drawing (same width, so nothing moves) goes back under it
    v = _build(mp, nudge)
    for _ in range(20):
        bad = [(xa, xb) for i, xa, xb, ya, yb in v.iron if facade(v.street, xa, xb, ya, yb) < 0.93]
        if not bad or mp.get("pool") is DOCKS_POOL:
            break
        xa, xb = bad[0]
        pool = mp.get("pool", STREET_POOL)
        for k, (name, x0) in enumerate(v.street):
            if name in KIT and x0 < xb and x0 + SEGMENTS[name] * 1.9 * SEG_SIZE.get(name, 1.0) > xa:
                # another drawing of the same width (so nothing moves) with wall where the iron hangs:
                # the least used, never next to its own kit; the kit itself if nothing else holds
                used = [q[0] for q in v.street]
                nb = [v.street[j][0] for j in (k - 1, k + 1) if 0 <= j < len(v.street)]
                cands = [c for c in pool if SEGMENTS[c] == SEGMENTS[name] and SEG_SIZE.get(c, 1.0) == SEG_SIZE.get(name, 1.0)
                         and KIT.get(c, c) not in [KIT.get(n, n) for n in nb]]
                ok = []
                for c in sorted(cands, key=lambda c: used.count(c)):
                    trial = [list(q) for q in v.street]
                    trial[k] = [c, x0]
                    if facade(trial, xa, xb, *[(ya, yb) for i, a2, b2, ya, yb in v.iron if (a2, b2) == (xa, xb)][0]) >= 0.93:
                        ok.append(c)
                        break
                v.street[k] = [ok[0] if ok else KIT[name], x0]
        if [(xa2, xb2) for i, xa2, xb2, ya, yb in v.iron if facade(v.street, xa2, xb2, ya, yb) < 0.93] == bad:
            break
    place_fronts(v)
    door_clear(v)   # (again: the kit and the cover moved men about after the first time)
    return v


def seg_w(name):
    return SEGMENTS[name] * 1.9 * SEG_SIZE.get(name, 1.0)


def front_spans(m):
    """Where place_fronts will lay the interiors' fronts: [(x0, x1)] in the world."""
    out = []
    for p_name, p in KIT_CAT.PIECES.items():
        if not p.get("front"):
            continue
        k = 1.9 * p["size"]
        d0, d1 = p["doors"]
        for r in m.rooms:
            if str(r[2]) == p["front"]:
                fx = (r[0] + r[1]) / 2 - (d0 + d1) / 2 * k
                out.append((fx, fx + seg_w(p_name)))
    return out


def place_fronts(m):
    """Every interior with a drawn building front gets it in the street (QUEUE §10.3, research ch15 "thresholds"): the
    front stands so its street door is at the room's left end and its side door at its right end. It is laid over the
    street as it is - nothing moves: the drawings under it are cut where it begins and ends ([name, x, from, to]: the
    part of the drawing shown, world px from its x), and one wholly under it is left out. A front that would cover a
    kit piece's things (an awning, a fire escape) is not placed (the dip through black stays) and is reported."""
    FRONT_OF = {p["front"]: n for n, p in KIT_CAT.PIECES.items() if p.get("front")}   # interior style -> its building front
    for r in sorted([r for r in m.rooms if str(r[2]) in FRONT_OF], key=lambda r: r[0]):
        f = FRONT_OF[r[2]]
        k = 1.9 * KIT_CAT.PIECES[f]["size"]
        d0, d1 = KIT_CAT.PIECES[f]["doors"]
        fx = (r[0] + r[1]) / 2 - (d0 + d1) / 2 * k   # the middle between its doors on the room's middle
        fw = seg_w(f)
        hit = False
        for seg in m.street:
            p = KIT_CAT.PIECES.get(seg[0], {})
            for pr in p.get("props", []) + [{"box": (a, 0, b, 0)} for a, b, *_ in p.get("floors", [])]:
                a, b = seg[1] + pr["box"][0] * 1.9 * p["size"], seg[1] + pr["box"][2] * 1.9 * p["size"]
                if a < fx + fw and fx < b:
                    hit = True
        if hit:
            print(f"  front {f} at {fx:.0f} would cover a kit piece's things: left out")
            continue
        out = []
        for seg in m.street:
            name, x0 = seg[0], seg[1]
            a, b = (seg[2], seg[3]) if len(seg) > 3 else (0.0, seg_w(name))
            lo, hi = x0 + a, x0 + b                      # the part of it shown so far
            if hi <= fx or lo >= fx + fw:
                out.append(seg)
                continue
            if lo < fx:                                  # its left part, up to the front
                out.append([name, x0, a, fx - x0])
            if hi > fx + fw:                             # its right part, after the front
                out.append([name, x0, fx + fw - x0, b])
        out.append([f, fx])
        m.street[:] = sorted(out, key=lambda s: s[1] + (s[2] if len(s) > 3 else 0.0))
        # never the old drawing of the same kind right beside it (an old laundry next to the new one): a drawing of the
        # same width and size takes its place, so nothing moves (kit pieces and the hoisted warehouse stay: things hang on them)
        same = {"laundry": ("laundry",), "warehouse": ("warehouse",), "club": ("bluenote",), "tenement": ()}[r[2]]
        i = next(n for n, g in enumerate(m.street) if g[0] == f and g[1] == fx)
        for j in (i - 1, i + 1):
            if not 0 <= j < len(m.street):
                continue
            g = m.street[j]
            if KIT.get(g[0], g[0]) not in same or g[0] == "warehouse_c" or g[0] in KIT_CAT.PIECES:
                continue
            near = [m.street[n][0] for n in (j - 1, j + 1) if 0 <= n < len(m.street)]
            cands = [c for c in ("warehouse", "warehouse_b", "laundry", "laundry_b", "subway", "subway_b")   # (not the ones the kit retired, nor the Blue Note: a place in the story)
                     if KIT.get(c, c) not in same and c not in near and c in SEGMENTS or KIT.get(c) in SEGMENTS]
            cands = [c for c in cands if KIT.get(c, c) not in same and c not in near
                     and seg_w(KIT.get(c, c)) == seg_w(KIT.get(g[0], g[0]))]
            if cands:
                used = [q[0] for q in m.street]
                m.street[j] = [min(cands, key=lambda c: used.count(c))] + list(g[1:])


def _build(mp, nudge):
    rng = random.Random(mp["seed"])
    x = 1900.0   # the first of them out of sight of the start
    out = Chunk(0)
    picks = list(mp["fixed"])
    n = len(picks)
    for i, name in enumerate(picks):
        hard = mp["start"] + (mp["end"] - mp["start"]) * i / max(1, n - 1)
        c = chunk(name, hard, random.Random(mp["seed"] * 101 + i * 13))
        x += nudge.get(i, 0)
        if c.plats and not c.rooms:
            if mp.get("pool") is DOCKS_POOL:   # no wall on the quay: the walkway stands on its own legs
                c.plats = [[px, py, pw, "gantry"] for px, py, pw, st in c.plats]
            xs = [p[0] for p in c.plats] + [r[0] for r in c.ramps]
            top = -1400.0 if c.scaf else min(p[1] for p in c.plats) - 300
            out.iron.append((i, x + min(xs) - 40, x + max(p[0] + p[2] for p in c.plats) + 40, top, -150.0))
        if c.scaf:
            out.scaf_x = x
        if c.up_end is not None:
            out.up_end = x + c.up_end
        for b in c.boxes: out.boxes.append([b[0], x + b[1]] + b[2:])
        for px, py, pw, st in c.plats: out.plats.append([x + px, py, pw, st])
        for rp_ in c.ramps: out.ramps.append([x + rp_[0], rp_[1], x + rp_[2], rp_[3]] + list(rp_[4:]))
        for a, b, st in c.rooms: out.rooms.append([x + a, x + b, st])
        for a, b, n, st in c.sections: out.sections.append([x + a, x + b, n, st])
        for cx, cy in c.xy_checks: out.xy_checks.append([x + cx, cy])
        for sx, sy, ty in c.stairdoors: out.stairdoors.append([x + sx, sy, ty])
        for hx in c.hoists: out.hoists.append(x + hx)
        for kx, kp in c.kits: out.kits.append((x + kx, kp))
        for tk, tx in c.things: out.things.append([tk, x + tx])
        for fl in c.flats: out.flats.append([x + fl[0], fl[1], fl[2], x + fl[3], x + fl[4], fl[5], fl[6]])
        for lx, ly in c.lamps: out.lamps.append([x + lx, ly])
        for k, px, py in c.pickups: out.pickups.append([k, x + px, py])
        for k, a, b, cc, d, *rest in c.ropes: out.ropes.append([k, x + a, b, x + cc if k in ("zip", "wash") else cc, d] + rest)
        for hx, t in c.hints: out.hints.append([x + hx, t])
        for ev in c.events:
            ev = list(ev)
            if ev[0] == "car": ev[1] += x; ev[2] += x
            elif ev[0] == "blackout": ev[1] += x
            elif ev[0] in ("searchlight", "train_pass", "beam", "blaze", "loop"): ev[1] += x
            out.events.append(ev)
        out.checks += [x + cx for cx in c.checks]
        for en in c.enemies:
            en = dict(en); en["x"] += x
            if en["trig"] is not None: en["trig"] += x
            if en["from"] is not None: en["from"] += x
            out.enemies.append(en)
        if c.rooms:   # a checkpoint on the way out of every room
            out.checks.append(x + c.w + 40)
        elif i > 0 and i % 3 == 0:
            out.checks.append(x - 100)
        x += c.w + rng.uniform(450, 750)
    extra = mp.get("extra")
    if mp.get("dream"):   # the chained doors at the far end (street() puts them under the finish)
        out.end = x + 900
    elif mp.get("roof"):
        roofs(out, mp, x, hard)
    elif extra:
        extra(out, x)
    elif mp.get("boss"):
        if mp.get("boss_room"):   # the fight in a room of its own
            out.rooms.append([x - 200, x + 2700, mp["boss_room"]])
            out.lamps += [[x + 400, -760.0], [x + 1400, -760.0], [x + 2300, -760.0]]
            if mp["boss_room"] == "club":   # the bar counter along the back bar: dive onto it and skid its length
                out.plats.append(bar_floor(x - 200, 2900))
        first, second = ("crate", "crate_long") if mp.get("boss_room") == "club" else ("crate", "crate_long" if mp.get("boss_room") else "dumpster")
        a, b = x + 300, x + 1500
        if mp.get("boss_room"):   # nothing in front of the room's doors (ROOM_CLEAR): along to the nearest clear floor
            st, r0, rw = mp["boss_room"], x - 200, 2900
            for d in range(0, 900, 20):
                if _room_free(st, rw, a - d - r0, a - d - r0 + BOX[first][0]) and a - d - r0 > 300:
                    a -= d; break
            for d in range(0, 900, 20):
                if _room_free(st, rw, b - d - r0, b - d - r0 + BOX[second][0]):
                    b -= d; break
        out.boxes += [[second, b]] if mp.get("boss_room") == "club" else [[first, a], [second, b]]   # (in the club the bar counter is the cover by the door)
        out.enemies += [{"x": x + 1050, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False},
                        {"x": x + 2050, "y": 0.0, "kind": "boss", "trig": None, "from": None, "delay": 0.0, "run": False}]
        out.checks.append(x - 100)
        out.end = x + 2300
    else:
        out.boxes += [["crate", x], ["drum", x + 560]]
        out.enemies += [{"x": x + 880, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False},
                        {"x": x + 1100, "y": 0.0, "kind": "tommy", "trig": x - 200, "from": x + 2600, "delay": 0.0, "run": True}]
        out.end = x + 1600
    if mp.get("diary"):   # a page of Eddie's notebook, nailed to the wall just before a crate partway along, at hand from the road
        cands = sorted([b for b in out.boxes if len(b) == 2 and b[0] in ("crate", "crate_long", "dumpster", "machine", "drum") and 2500 < b[1] < out.end - 2500], key=lambda b: b[1])
        if cands:
            b = cands[min(len(cands) - 1, mp.get("page", len(cands) // 2))]
            out.pickups.append(["page", b[1] - 140.0, 0.0])
        else:   # nothing to climb: it lies where the fight is thickest, halfway along
            out.pickups.append(["page", out.end * 0.55, 0.0])
    out.checks = sorted(set(round(c) for c in out.checks if 800 < c < out.end - 500))
    door_clear(out)
    out.street = street(mp, out, rng)
    kit_pieces(out)
    hoist_ropes(out)
    street_props(out)
    for b in out.boxes:
        if b[0] == "barrel" and not barrel_ok(place_at(out, b[1])) and not mp.get("keep_barrel"):
            b[0] = "drum"
            b[1] -= (BOX["drum"][0] - BOX["barrel"][0]) / 2
            for en in out.enemies:
                if en["y"] == 0.0 and b[1] - 50 < en["x"] < b[1] + BOX["drum"][0] + 50:
                    en["x"] = b[1] + BOX["drum"][0] + 60
    for e in mp.get("events", []):
        out.events.append(list(e))
    cover_men(out, mp)
    for e in out.enemies:   # (after the kit moved things about) nobody left standing inside a crate
        inside = lambda x: any(len(o) == 2 and o[1] - 50 < x < o[1] + BOX[o[0]][0] + 50 for o in out.boxes)
        if e["y"] == 0.0 and inside(e["x"]):
            e["x"] = next(x for d in range(40, 3000, 40) for x in (e["x"] + d, e["x"] - d) if not inside(x))
    for name, sx in out.street:   # two of them keep watch under every crane's hanging crate
        if name != "cranes":
            continue
        cx = sx + (CRANE_CRATE * SEGMENTS[name] - 132) * (SEGMENTS[name] / (SEGMENTS[name] - 132)) * 1.9
        for dx in (-110, 140):
            ex = cx + dx
            if 1500 < ex < out.end - 1500 and not any(b[1] - 60 < ex < b[1] + BOX[b[0]][0] + 60 for b in out.boxes) \
                    and not any(abs(en["x"] - ex) < 120 for en in out.enemies):
                out.enemies.append({"x": ex, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False})
    return out


def place_at(m, x):
    """What x is in: 'room:<style>' or the street drawing under it."""
    for a, b, st in m.rooms:
        if a <= x < b:
            return "room:" + st
    best = None
    for name, sx in m.street:
        if sx <= x:
            best = name
    return best


def check_props(m):
    """The rules for cover (2026-11-16), for every map now and every map to come."""
    errs = []
    by = lambda b: b[2] if len(b) > 2 else 0.0
    bs = sorted([b for b in m.boxes if by(b) == 0.0], key=lambda b: b[1])
    for a, b in zip(bs, bs[1:]):
        gap = b[1] - (a[1] + BOX[a[0]][0])
        if 0 < gap < 260 and "stack" not in (a[0], b[0]):
            errs.append(f"{a[0]} and {b[0]} at {a[1]:.0f}: {gap:.0f} apart, no room for a man between, not a pile either")
    for a, b, c in zip(bs, bs[1:], bs[2:]):
        if a[0] == b[0] == c[0] and c[1] - a[1] < 2600:
            errs.append(f"three {a[0]}s in a row at {a[1]:.0f}")
    for b in bs:
        if b[0] == "barrel" and not barrel_ok(place_at(m, b[1])):
            errs.append(f"red barrel at {b[1]:.0f} in {place_at(m, b[1])}: no fuel kept there")
    for a, b, st in m.rooms:
        inside = [q for q in bs if a <= q[1] < b]
        for q in inside:
            if not _room_free(st, b - a, q[1] - a, q[1] - a + BOX[q[0]][0]):
                errs.append(f"{q[0]} at {q[1]:.0f} stands in front of a door in the {st}")
        for p, q in zip(inside, inside[1:]):
            if p[0] == q[0]:
                errs.append(f"two {p[0]}s side by side in the {st} at {p[1]:.0f}")
    return errs


THING_W = 1300   # = props.gd THING_W (the widest: the third rail; the trolley pole 960, the windlass 520)
def cover_men(m, mp):
    """Men who wait for Frank in the open street would just be targets (2026-11-16): about half of them
    get something to stand behind, a crate or a drum on their side of the fight, a step in front of
    them (Frank comes from the left). Two men never stand shoulder to shoulder. Not in rooms (their
    furniture is drawn), on the roofs, the moving train or in the dream."""
    if mp.get("dream") or mp.get("moving"):
        return
    rng = random.Random(mp["seed"] * 7 + 3)
    by = lambda b: b[2] if len(b) > 2 else 0.0
    in_room = lambda x: any(a - 300 < x < b + 300 for a, b, st in m.rooms)
    def covered(x):   # (a free-standing thing - the windlass - is his cover too, and nothing is put in front of it)
        return (any(by(b) == 0.0 and 30 < x - (b[1] + BOX[b[0]][0]) < 300 and BOX[b[0]][1] > 200 for b in m.boxes)
                or any(-100 < x - (t[1] + THING_W) < 300 for t in m.things))
    foes = sorted([e for e in m.enemies if not e["run"] and e["y"] == 0.0 and e["kind"] in ("post", "tommy", "shotgun")], key=lambda e: e["x"])
    for a, b in zip(foes, foes[1:]):   # shoulder to shoulder: the second steps back
        if b["x"] - a["x"] < 250 and not in_room(b["x"]):
            b["x"] = a["x"] + 260
    for e in foes:
        if e["kind"] == "shotgun" or covered(e["x"]) or in_room(e["x"]) or e["x"] < 1700 or e["x"] > m.end - 900:
            continue   # (a shotgunner comes in; he does not hide)
        if rng.random() > 0.6:
            continue
        first = "crate" if rng.random() < 0.6 else "drum"
        near = [b[0] for b in m.boxes if by(b) == 0.0 and abs(b[1] - e["x"]) < 2600]
        if near.count(first) >= 1:   # not the same thing again next to its own kind
            first = "drum" if first == "crate" else "crate"
        for kind, off in [(first, 140), (first, 200), ("drum" if first == "crate" else "crate", 140)]:
            w = BOX[kind][0]
            bx = e["x"] - off - w
            left = [b for b in m.boxes if by(b) == 0.0 and b[1] < bx]
            right = [b for b in m.boxes if by(b) == 0.0 and b[1] > bx]
            two_l = [b[0] for b in sorted(left, key=lambda b: b[1])[-2:]]
            two_r = [b[0] for b in sorted(right, key=lambda b: b[1])[:2]]
            if two_l == [kind, kind] or two_r == [kind, kind] or (two_l[-1:] == [kind] and two_r[:1] == [kind]):
                continue   # a third of the same in a row
            if any(bx < t[1] + THING_W + 80 and bx + w > t[1] - 80 for t in m.things):
                continue
            if _cover_spot(m, e, bx, w, by):
                m.boxes.append([kind, bx])
                break
    m.boxes.sort(key=lambda b: (by(b), b[1]))


def _cover_spot(m, e, bx, w, by):
    lo, hi = bx - 270, bx + w + 270   # a man's width clear of anything else on the ground
    for n, x0, *_ in m.street:   # nothing in front of a kit piece's door, gate or painted thing
        p = KIT_CAT.PIECES.get(n)
        if p and any(x0 + a * 1.9 * p["size"] - 120 < bx + w and bx < x0 + b * 1.9 * p["size"] + 120 for a, b in p.get("clear", [])):
            return False
    for a, b, n, st in m.sections:   # nothing in front of a door or the stairs painted in the building's ground floor
        if any(a + c0 - 60 < bx + w and bx < a + c1 + 60 for c0, c1 in SEC_CLEAR):
            return False
    if any(by(b) == 0.0 and b[1] < hi and b[1] + BOX[b[0]][0] > lo for b in m.boxes):
        return False
    if any(o is not e and bx - 120 < o["x"] < bx + w + 120 and o["y"] == 0.0 for o in m.enemies):
        return False
    if any(bx - 300 < x < bx + w + 300 for r in m.ramps for x in (r[0], r[2])):
        return False
    if any(bx - 150 < px < bx + w + 150 for k, px, py in m.pickups) or any(bx - 250 < c < bx + w + 250 for c in m.checks):
        return False
    if any(px - 100 < bx + w and bx < px + pw + 100 and py > -700 for px, py, pw, st in m.plats):
        return False   # (nothing under a low walkway: it would block the way up)
    if any(ev[0] == "car" and abs(ev[2] - bx) < 700 for ev in m.events):
        return False
    return True


# A red barrel is fuel: it stands where fuel is kept (yards, warehouses, docks, tunnels, a back alley's
# garage, the club's boiler oil by its back door), never outside a church, a laundry, a club or a market, nor in a hallway or an office.
BARREL_OK = {"alley", "warehouse", "deadend", "bluenote", "pier17", "cranes", "shipping", "quay", "sheds", "harbor",
             "tunnel", "yard", "walkway", "tunnel_lo", "signal", "arches", "pump", "room:warehouse", "room:hold"}


def barrel_ok(place):
    return place is not None and (place in BARREL_OK or KIT.get(place, place) in BARREL_OK)


# A swing rope in the streets hangs from something drawn (user, 16. 11.: "a rope in the middle of the street is
# cheap"): the warehouse's hoist (art/street/warehouse_c.png = warehouse with its painted rope and hook taken
# out, gen/tools/hoist_street.py; the game hangs its swinging rope from the painted pulley). A chunk asks for one
# with m.hoists.append(x): the warehouse segment nearest x becomes warehouse_c and the rope, the cargo wall it
# swings over and the man behind it go where its pulley is. In the docks the crane's rope stays (crane_swing).
HOIST_PX = (698.0, 618.0)   # the pulley wheel's bottom in the warehouse drawing's pixels
# The street kit (gen/kit.py: the one catalogue the game reads too, as kit.gd): for each kit piece in the street,
# nothing stands in front of its things (cover moved to free sidewalk or dropped), its floors (an awning, a fire
# escape's landings) are added, and a man is stood by each hazard (one Frank's bullet sets off).
import kit as KIT_CAT
for _n, _p in KIT_CAT.PIECES.items():
    SEGMENTS[_n] = KIT_CAT.WIDTH
    SEG_SIZE[_n] = _p["size"]
    TRIM[_n] = 0
def street_props(m):
    every = [(x0 + a * 1.9 * KIT_CAT.PIECES[n]["size"] - 120, x0 + b * 1.9 * KIT_CAT.PIECES[n]["size"] + 120)   # every piece's
             for n, x0, *_ in m.street if n in KIT_CAT.PIECES for a, b in KIT_CAT.PIECES[n].get("clear", [])]   # clear ground
    for name, x0 in m.street:
        piece = KIT_CAT.PIECES.get(name)
        if not piece:
            continue
        k = 1.9 * piece["size"]
        wx = lambda px: x0 + px * k
        top = KIT_CAT.TOP(piece["size"])
        blocked = [(wx(a) - 120, wx(b) + 120) for a, b in piece.get("clear", [])]
        def free(x, w, me):
            if any(a < x + w and x < b for a, b in every):   # (a crate moved off one piece's clear ground never onto another's)
                return False
            if any(r[0] - 250 < x + w and x < r[1] + 250 for r in m.rooms):
                return False   # (not in front of a room's door either)
            if any(o is not me and len(o) == 2 and o[1] - 270 < x + w and x < o[1] + BOX[o[0]][0] + 270 for o in m.boxes):
                return False
            return not any(e["y"] == 0.0 and x - 90 < e["x"] < x + w + 90 for e in m.enemies)
        for bx in list(m.boxes):
            if len(bx) != 2 or not any(a < bx[1] + BOX[bx[0]][0] and bx[1] < b for a, b in blocked):
                continue
            w = BOX[bx[0]][0]
            spot = next((x for d in range(0, 2400, 60) for x in (bx[1] + d, bx[1] - d) if free(x, w, bx)), None)
            if spot is None:
                m.boxes.remove(bx)
            else:
                bx[1] = spot
        in_box = lambda x: any(len(o) == 2 and o[1] - 60 < x < o[1] + BOX[o[0]][0] + 60 for o in m.boxes)
        for e in m.enemies:   # nobody standing inside a painted thing (or, moved, inside a crate) either
            if e["y"] == 0.0 and any(a < e["x"] < b for a, b in blocked):
                e["x"] = next(x for d in range(0, 3000, 40) for x in (e["x"] + d, e["x"] - d)
                              if not any(a < x < b for a, b in blocked) and not in_box(x))
        for pr in piece["props"]:
            kd = KIT_CAT.KINDS[pr["kind"]]
            x_a, y_a, x_b, y_b = pr["box"]
            if kd["floor"]:
                m.plats.append([wx(x_a + 15), top + pr.get("walk_y", y_a) * k, (x_b - x_a - 30) * k, kd["floor"]])
                if kd["floor"] == "awning" and 1500 < wx(x_a) < m.end - 800:   # a crate below its near end: the way up onto it
                    near = [o for o in m.boxes if len(o) == 2 and wx(x_a) - 700 < o[1] < wx(x_a) + 200]
                    if not near:
                        cx = next((x for d in range(0, 900, 40) for x in (wx(x_a) - 330 - d,) if free(x, BOX["crate"][0], None)), None)
                        if cx is not None:
                            m.boxes.append(["crate", cx])
            if kd["shot"]:
                hx = wx((x_a + x_b) / 2)
                if not any(abs(e["x"] - hx) < 500 and e["y"] == 0.0 for e in m.enemies) and 1500 < hx < m.end - 1500:
                    ex = next(x for d in range(0, 2000, 40) for x in (wx(x_b) + 200 + d, wx(x_a) - 200 - d)
                              if not any(a < x < b for a, b in blocked) and not in_box(x))
                    m.enemies.append({"x": ex, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False})
        for a, b, y, style in piece.get("floors", []):
            m.plats.append([wx(a), top + y * k, (b - a) * k, style])
        for xa, ya, xb, yb in piece.get("ramps", []):
            m.ramps.append([wx(xa), top + ya * k, wx(xb), top + yb * k, "fescape"])   # (painted: not drawn by the game)
        for mx, my, kind in piece.get("men", []):
            if not 1500 < wx(mx) < m.end - 800:
                continue   # (a piece past the finish is only scenery: nobody up there)
            m.enemies.append({"x": wx(mx), "y": top + my * k, "kind": kind, "trig": None, "from": None, "delay": 0.0, "run": False})
        for lx, ly, foot in piece.get("ladders", []):
            m.ropes.append(["ladder", wx(lx), top + ly * k, 0.0, top + foot * k, "drawn"])
        for xa, ya, xb, yb, fl in piece.get("lines", []):
            m.ropes.append(["wash", wx(xa), top + ya * k, wx(xb), top + yb * k, top + fl * k])


def kit_pieces(m):
    """A chunk's wanted street-kit drawing (m.kits: (x, piece)): the segment under x becomes that piece, placed so
    its things' middle falls at x; the segments after it move by the difference, so the drawings still meet."""
    for want, piece in m.kits:
        p = KIT_CAT.PIECES[piece]
        k = 1.9 * p["size"]
        xs = [a for a, b in p.get("clear", [])] + [b for a, b in p.get("clear", [])]
        mid = (min(xs) + max(xs)) / 2 * k if xs else KIT_CAT.WIDTH * k / 2
        i = next((n for n, seg in enumerate(m.street) if seg[1] + mid >= want - 900), None)
        if i is None:
            raise ValueError(f"no street under the kit piece {piece} near {want:.0f}")
        if any(0 <= n < len(m.street) and m.street[n][0] == piece for n in (i - 1, i, i + 1)):
            continue   # it is there already, or next door: never the same drawing twice in a row
        old = SEGMENTS[m.street[i][0]] * 1.9 * SEG_SIZE.get(m.street[i][0], 1.0)
        m.street[i][0] = piece
        delta = KIT_CAT.WIDTH * k - old
        for seg in m.street[i + 1:]:
            seg[1] += delta


def hoist_ropes(m):
    k = 1.9 * SEG_SIZE.get("warehouse", 1.0)
    off = (HOIST_PX[0] - TRIM["warehouse"]) * k * SEGMENTS["warehouse"] / (SEGMENTS["warehouse"] - TRIM["warehouse"])
    for want in m.hoists:
        # the first segment whose pulley would fall at or past the wanted x becomes the hoisted warehouse; the
        # segments after it move by the difference in width, so the drawings still meet edge to edge
        i = next((n for n, seg in enumerate(m.street) if seg[1] + off >= want - 600), None)
        if i is None:
            raise ValueError(f"no street under the hoist rope near {want:.0f}")
        old = SEGMENTS[m.street[i][0]] * 1.9 * SEG_SIZE.get(m.street[i][0], 1.0)
        m.street[i][0] = "warehouse_c"
        delta = SEGMENTS["warehouse"] * k - old
        for seg in m.street[i + 1:]:
            seg[1] += delta
        x = m.street[i][1] + off
        y = -1344 * 1.9 * 0.92 - 60.0 + HOIST_PX[1] * 1.9   # (main.gd: the drawing's top, WALL_SCALE, SEGMENT_BASE, WALL_LIFT)
        m.ropes.append(["swing", x, y, 0.0, 0.0])
        m.boxes[:] = [o for o in m.boxes if not (len(o) == 2 and x + 220 < o[1] + BOX[o[0]][0] and o[1] < x + 520 + BOX["stack"][0] + 300)]
        m.boxes.append(["stack", x + 520])
        m.enemies.append({"x": x + 1300, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False})
        m.end = max(m.end, x + 1900)


# How well two street drawings join (gen/tests/audit_maps.py measures the same: the right edge of one against the
# left edge of the next in world space; 0 = seamless, ~0.9 = a hard cut such as a wall against open sky).
SEAM_OK = 0.6
_SEAMS = {}
def seam_score(a, b):
    if (a, b) not in _SEAMS:
        import importlib.util, numpy as np
        spec = importlib.util.spec_from_file_location("audit_maps", os.path.join(REPO, "gen", "tests", "audit_maps.py"))
        A = importlib.util.module_from_spec(spec)
        cwd = os.getcwd(); spec.loader.exec_module(A); os.chdir(cwd)
        C = A.main_consts.__wrapped__() if hasattr(A.main_consts, "__wrapped__") else _main_consts(A)
        rows = np.arange(-2400.0, -20.0, 8.0)
        ea, eb = A.edge_world(a, C, "right", rows), A.edge_world(b, C, "left", rows)
        if ea is None or eb is None:
            _SEAMS[(a, b)] = 0.5
        else:
            both = ~np.isnan(ea[:, 0]) & ~np.isnan(eb[:, 0])
            d = np.abs(ea[both] - eb[both]).mean(1)
            lum = np.abs(ea[both].mean(1) - eb[both].mean(1))
            only = int((np.isnan(ea[:, 0]) != np.isnan(eb[:, 0])).sum())
            _SEAMS[(a, b)] = float(np.percentile(d, 90) * 0.6 + np.percentile(lum, 95) * 0.4 + only * 0.002)
    return _SEAMS[(a, b)]


_C = None
def _main_consts(A):
    global _C
    if _C is None:
        cwd = os.getcwd(); os.chdir(REPO); _C = A.main_consts(); os.chdir(cwd)
    return _C


DOOR_CLEAR = 700.0   # (research ch15: a change of scene only when no fight is on) nobody waits in the street this close to an interior's door
def door_clear(m):
    """No fight across the dip through black at an interior's door: a man standing in the street within DOOR_CLEAR of
    a door steps back along the street, away from it (he still covers the way there)."""
    plain = [r for r in m.rooms if not str(r[2]).startswith("section_")]
    for e in m.enemies:
        if e["y"] != 0.0:
            continue
        for a, b, st in plain:
            if a < e["x"] < b:
                break
            for door, away in ((a, -1.0), (b, 1.0)):
                if 0 < abs(e["x"] - door) < DOOR_CLEAR and (e["x"] - door) * away > 0:
                    e["x"] = door + away * DOOR_CLEAR
                    if e.get("from") is not None and abs(e["from"] - door) < DOOR_CLEAR:
                        e["from"] = door + away * (DOOR_CLEAR + 200.0)


def street(mp, m, rng):
    """The run of drawn segments under the map: the map's own feature segment early on, no segment twice
    in a row, and (in the prologue) the dead-end alley under the last stand."""
    seq, x = [], -3000.0
    near_house = lambda x, w: any(x < a + 2400 and x + w > a - 2400 for a, b, n, st in m.sections) or         any(x < b + 2600 and x + w > a - 600 for a, b, n, st in m.sections)
    if mp.get("street_fixed"):   # a test map: the drawings in the given order (then round again), nothing chosen
        names, i, k_row = mp["street_fixed"], 0, 0
        roof_a = m.roof[2][0][1] - 4000 if m.roof else None
        roof_b = m.roof[2][-1][1] + ROOF_PIC if m.roof else None
        while x < m.end + 2500:
            name = names[i % len(names)]
            row_w = SEGMENTS[UNDER_ROOF[0]] * 1.9 * SEG_SIZE[UNDER_ROOF[0]]
            if near_house(x, row_w) or (m.roof and m.kit["under"] and x + row_w > roof_a and x < roof_b):
                name = UNDER_ROOF[k_row % len(UNDER_ROOF)]   # a house in cross-section stands in a row of houses like it
                k_row += 1
            else:
                i += 1
            seq.append([name, x])
            x += SEGMENTS[name] * 1.9 * SEG_SIZE.get(name, 1.0)
        return seq
    if mp.get("dream"):   # the same two rooms over and over, then the far wall with the chained doors
        k = 0
        while True:
            w = SEGMENTS["fire_c"] * 1.9 * SEG_SIZE["fire_c"]
            if x + w * 1.5 > m.end:
                seq.append(["fire_c", x])
                m.end = x + w * 0.42   # he stops in front of the doors
                seq.append(["fire_a", x + w])   # (beyond them, out of reach, more of the same)
                return seq
            # the same two rooms at first; after each time it starts over they are rooms gone wrong
            name = (["fire_a", "fire_b", "fire_a", "fire_b", "fire_d", "fire_b", "fire_e", "fire_f", "fire_g"] + ["fire_e", "fire_g"] * 9)[k]
            seq.append([name, x])
            x += SEGMENTS[name] * 1.9 * SEG_SIZE[name]
            k += 1
    pool = [s for s in mp.get("pool", STREET_POOL) if s != mp.get("feature") and not (mp.get("plain") and s in KIT)] or [mp["feature"]]
    if len(pool) < 2:   # a map of one kit and its variant: the feature takes its turns too
        pool = [s for s in mp.get("pool", STREET_POOL) if not (mp.get("plain") and s in KIT)]
    last = None
    i = 0
    roof_a = m.roof[2][0][1] - 4000 if m.roof else None
    roof_b = m.roof[2][-1][1] + ROOF_PIC if m.roof else None
    k_roof = 0
    while x < m.end + 2500:
        nxt = x + SEGMENTS[UNDER_ROOF[0]] * 1.9 * SEG_SIZE[UNDER_ROOF[0]]
        if (m.roof and m.kit["under"] and nxt > roof_a and x < roof_b) or near_house(x, nxt - x):   # under the roofs (and round a house in cross-section): only the facades that reach up to them
            name = UNDER_ROOF[k_roof % len(UNDER_ROOF)]
            k_roof += 1
        elif i == 1 and mp.get("feature"):
            name = mp["feature"]
        elif m.roof and not m.kit["under"] and x < m.up_end - 1800 < x + SEGMENTS[mp["feature"]] * 1.9 * SEG_SIZE.get(mp["feature"], 1.0):
            name = mp["feature"]   # the stairs up to the mezzanine go up from a station platform
        elif m.stand and "deadend" not in [q[0] for q in seq] and x + SEGMENTS["deadend"] * 1.9 * SEG_SIZE["deadend"] > m.stand + 1000:
            name = "deadend"
        else:   # each segment once before any comes back
            used = [q[0] for q in seq]
            trains = [e[1] for e in m.events if e[0] == "train_pass"]
            ok = lambda s: s not in TRACKLESS or not any(x - 3500 < t < x + SEGMENTS[s] * 1.9 + 1000 for t in trains)
            cand = [s for s in pool if ok(s)] or pool
            cand = [s for s in cand if s != last] or cand   # never the same twice in a row
            cand = [s for s in cand if KIT.get(s, s) != KIT.get(last, last)] or cand   # nor a kit next to its own variant
            if last is not None:   # only a drawing whose left edge is the same kind as the last one's right edge (gen/kit.py EDGES)
                cand = [s for s in cand if KIT_CAT.joins(last, s)] or cand
            # where an interior's front will be laid (place_fronts), no kit piece with things to play with: the front would hide them
            fronts = front_spans(m)
            busy = lambda s: s in KIT_CAT.PIECES and (KIT_CAT.PIECES[s]["props"] or KIT_CAT.PIECES[s].get("floors"))
            cand = [s for s in cand if not (busy(s) and any(a < x + seg_w(s) and x < b for a, b in fronts))] or cand
            if i == 0:   # nor the one the feature is about to show next to it
                cand = [s for s in cand if s != mp.get("feature")] or cand
                if mp.get("feature"):   # and its right edge must meet the feature's left one (he starts right by that join)
                    best = min(seam_score(s, mp["feature"]) for s in cand)
                    cand = [s for s in cand if seam_score(s, mp["feature"]) < max(SEAM_OK, best + 0.05)]
            w_here = lambda s: SEGMENTS[s] * 1.9 * SEG_SIZE.get(s, 1.0)
            fuel = [b[1] for b in m.boxes if b[0] == "barrel" and not any(a <= b[1] < c for a, c, st in m.rooms)]
            if any(x <= f < x + w_here(cand[0]) for f in fuel):   # a red barrel here: a place where fuel is kept
                cand = [s for s in cand if barrel_ok(s)] or cand
            cand = sorted(cand, key=lambda s: used.count(s))   # and the least used first
            least = [s for s in cand if used.count(s) == used.count(cand[0])]
            # the joins must look right (user 16. 11.: a wall begun mid-air, smoke cut off at a drawing's end):
            # among the least used, those whose left edge meets the last one's right edge; if none does, the
            # best-fitting of all the candidates (a little reuse beats a hard cut)
            if last is not None:
                fit = [s for s in cand if seam_score(last, s) < SEAM_OK]   # of those that join well, the least used
                if fit:
                    least = [s for s in fit if used.count(s) == min(used.count(q) for q in fit)]
                    # (a drawing already in this map counts by its kit too: a variant beats the same picture again)
                    least = [s for s in least if used.count(KIT.get(s, s)) + sum(used.count(v) for v, k in KIT.items() if k == KIT.get(s, s)) ==
                             min(used.count(KIT.get(q, q)) + sum(used.count(v) for v, k in KIT.items() if k == KIT.get(q, q)) for q in least)] or least
                else:
                    best = min(seam_score(last, s) for s in cand)
                    least = [s for s in cand if seam_score(last, s) <= best + 0.05]
            name = rng.choice(least)
        seq.append([name, x])
        last = name
        x += SEGMENTS[name] * 1.9 * SEG_SIZE.get(name, 1.0)
        i += 1
    return seq


def roofs(out, mp, x, hard):
    """Up the scaffold and back the other way along the roofs: tar barrels and builders' crates for cover,
    and them coming out of the stairwell doors ahead. The map ends at the firewall at the far end."""
    kit = KITS[mp.get("kit", "roof")]
    ROOF_Y = kit["y"]
    pic_w = 3168 * kit["scale"]
    stub = kit["stub"] * kit["scale"]
    r1 = out.up_end                             # the floor's near end, just past the top of the way up
    pics = []
    x0 = r1 + 150.0 - pic_w                     # the far right drawing's left edge post stands at the near end
    names = mp.get("roofs", ["roof_a", "roof_b"])
    other = lambda n: kit["deco"] or ("roof_a" if n == "roof_b" else "roof_b")
    pics.append([other(names[0]), x0 + pic_w - stub])   # past both ends: more of the same, out of reach
    for k, name in enumerate(names):
        pics.insert(0, [name, x0])
        if k + 1 < len(names):
            x0 -= pic_w - stub
    pics.insert(0, [other(names[-1]), x0 - (pic_w - stub)])
    r0 = x0 + stub
    out.kit = kit
    out.plats.append([r0, ROOF_Y, r1 - r0, "roof"])
    out.roof = [r0, r1, pics, x0 + pic_w * kit["goal"] if kit["goal"] else r0 + 450.0]
    L = r1 - r0
    # cover, and a man behind each piece of it (he faces the detective coming from the right)
    for f, box, kind in ((0.14, "drum", "post"), (0.36, "crate", "tommy" if hard > 0.5 else "post"),
                         (0.57, "drum", "post"), (0.8, "crate_long", "shotgun")):
        bx = r1 - L * f
        out.boxes.append([box, bx, ROOF_Y])
        out.enemies.append({"x": bx - 170, "y": ROOF_Y, "kind": kind, "trig": None, "from": None, "delay": 0.0, "run": False})
    # out of the stairwell door at the far end once he is halfway along
    out.enemies.append({"x": r1 - L * 0.7, "y": ROOF_Y, "kind": "post", "trig": r1 - L * 0.4, "from": r0 + 300, "delay": 0.0, "run": True})
    out.roof_checks = [r1 - L * 0.5]
    out.end = r1 + 400.0


def last_stand(out, x):   # the prologue's end: a dead-end alley and more of them than Eddie has bullets
    out.boxes += [["crate", x + 200], ["dumpster", x + 1150]]
    out.hints.append([x, "NOWHERE LEFT TO RUN"])
    out.stand = x + 600
    out.end = x + 1700


def check(m):
    errs = check_props(m)
    by = lambda b: b[2] if len(b) > 2 else 0.0
    bs = sorted([b for b in m.boxes if by(b) == 0.0], key=lambda b: b[1])   # on the street
    hi = [b for b in m.boxes if by(b) != 0.0]                                  # up on a floor or the roof
    for group in (bs, sorted(hi, key=lambda b: (by(b), b[1]))):
        for a, b in zip(group, group[1:]):
            if by(a) == by(b) and a[1] + BOX[a[0]][0] > b[1] - 1:
                errs.append(f"boxes overlap at {a[1]:.0f}")
    floors = [(p[0], p[0] + p[2], p[1]) for p in m.plats]
    for b in hi:
        if not any(a - 1 <= b[1] and b[1] + BOX[b[0]][0] <= c + 1 and abs(y - by(b)) < 1 for a, c, y in floors):
            errs.append(f"box at {b[1]:.0f},{by(b):.0f} floats")
    for px, py, pw, st in m.plats:
        if st in ("awning", "drawn") or (st == "bar" and -py < 190):
            continue   # the street kit's awning and fire escape: reached by jumping off the awning; a bar counter: a jump
        # reachable: a ramp ends on it, a ladder comes up onto it, or something within jumping reach stands under its near end
        ok = any(abs(r[3] - py) < 1 and px - 20 <= r[2] <= px + pw + 20 for r in m.ramps)
        ok = ok or any(abs(r[1] - py) < 1 and px - 20 <= r[0] <= px + pw + 20 for r in m.ramps)
        ok = ok or any(k == "ladder" and abs(y0 - py) < 1 and px <= x <= px + pw for k, x, y0, x1, y1, *_ in m.ropes)
        ok = ok or any(abs(ty - py) < 1 and px <= sx <= px + pw for sx, sy, ty in m.stairdoors)   # the stairs in the back wall come out on it
        ok = ok or any(b[1] <= px + 60 and b[1] + BOX[b[0]][0] >= px - 500 and BOX[b[0]][1] + JUMP_REACH > -py for b in bs)
        if not ok:
            errs.append(f"floor at {px:.0f},{py:.0f} cannot be reached")
    for k, x, y0, x1, y1, *rest in m.ropes:   # a ladder stands on something and leans on something (a fire escape's drop ladder hangs)
        if k == "ladder" and y1 < 0 and rest[:1] != ["drawn"] and not any(a <= x <= c and abs(y - y1) < 1 for a, c, y in floors):
            errs.append(f"ladder at {x:.0f} stands on air")
    for en in m.enemies:
        if en["y"] < 0 and not any(a <= en["x"] <= b and abs(y - en["y"]) < 1 for a, b, y in floors):
            errs.append(f"enemy at {en['x']:.0f} floats")
        if any(abs(by(b) - en["y"]) < 1 and b[1] - 40 < en["x"] < b[1] + BOX[b[0]][0] + 40 for b in m.boxes):
            errs.append(f"enemy at {en['x']:.0f},{en['y']:.0f} stands in a box")
    for ev in m.events:
        if ev[0] == "car" and any(b[1] < ev[2] + 440 and b[1] + BOX[b[0]][0] > ev[2] - 440 for b in bs):
            errs.append(f"car at {ev[2]:.0f} stops on a box")
    for r in m.ramps:   # nothing may stand on the ramp's foot
        foot = r[0] if r[1] == 0 else (r[2] if r[3] == 0 else None)
        if foot is not None and any(b[1] - 80 < foot < b[1] + BOX[b[0]][0] + 80 for b in bs):
            errs.append(f"ramp foot at {foot:.0f} blocked")
    return errs


def draw(m, name, path):
    W = 3000; k = W / (m.end + 600)
    H = 300 if not m.roof else 300 + int(-m.kit["y"] * k * 2.4)
    im = Image.new("RGB", (W, H), (30, 30, 34)); d = ImageDraw.Draw(im)
    gy = H - 50; vy = lambda y: gy + y * k * 2.4
    for a, b, st in m.rooms:
        d.rectangle([a * k, vy(-1000), b * k, gy], fill=(52, 44, 40))
    d.line([(0, gy), (W, gy)], fill=(120, 120, 120), width=2)
    for b in m.boxes:
        kind, bx = b[0], b[1]; base = b[2] if len(b) > 2 else 0.0
        w, h, wood = BOX[kind]
        d.rectangle([bx * k, vy(base - h), (bx + w) * k, vy(base)], fill=(200, 40, 40) if kind == "barrel" else ((150, 110, 60) if wood else (110, 110, 120)))
    for px, py, pw, st in m.plats:
        d.rectangle([px * k, vy(py) - 2, (px + pw) * k, vy(py) + 1], fill=(190, 190, 210))
    for a, b, c, e, *_ in m.ramps:
        d.line([(a * k, vy(b)), (c * k, vy(e))], fill=(190, 190, 210), width=2)
    for kd, x, y0, x1, y1, *_ in m.ropes:
        if kd == "ladder":
            d.line([(x * k, vy(y0)), (x * k, vy(y1))], fill=(200, 160, 90), width=2)
    if m.roof:
        d.line([(m.roof[3] * k, vy(m.kit["y"]) - 40), (m.roof[3] * k, vy(m.kit["y"]))], fill=(80, 220, 80), width=3)
    for kind, px, py in m.pickups:
        d.ellipse([px * k - 4, vy(py) - 14, px * k + 4, vy(py) - 6], fill=(80, 200, 255))
    for en in m.enemies:
        ex, ey = en["x"] * k, vy(en["y"])
        col = {"post": (220, 40, 40), "tommy": (255, 90, 200), "shotgun": (255, 230, 60), "boss": (255, 255, 255)}[en["kind"]]
        d.rectangle([ex - 3, ey - 24, ex + 3, ey], fill=col, outline=(255, 160, 40) if en["run"] else None)
        if en["run"]:
            d.line([(en["from"] * k, ey - 12), (ex, ey - 12)], fill=(255, 160, 40), width=1)
    for c in m.checks:
        d.line([(c * k, gy + 8), (c * k, gy + 30)], fill=(80, 220, 80), width=2)
    if m.stand:
        d.line([(m.stand * k, 20), (m.stand * k, gy)], fill=(255, 80, 80), width=2)
    d.line([(m.end * k, 20), (m.end * k, gy)], fill=(80, 220, 80), width=3)
    d.text((8, 6), f'{name}   length {int(m.end)} px   enemies {len(m.enemies)}   checkpoints {len(m.checks)}', fill=(230, 230, 230))
    im.save(path)


PROLOGUE = {"name": "THE LAST NOTE", "seed": 1, "feature": "bluenote", "pool": ["alley", "warehouse", "laundry", "subway", "church", "market"], "start": 0.0, "end": 0.2, "extra": last_stand,
    "fixed": ["breather", "crate_cover", "drum_duo", "barrel_trap", "rush"],
    "hints": [[200, "DRAG THE STICK TO MOVE"], [1500, "TAP ANYWHERE TO SHOOT THERE"], [2700, "PULL THE STICK DOWN TO HIDE BEHIND COVER"],
              [4300, "THE RUNNING MAN BUTTON DIVES OVER CRATES"], [6100, "SHOOT THE RED BARREL"], [7900, "TAP THE STOPWATCH TO SLOW TIME"]],
    "intro": ["They came out of the rain at both ends of the street.", "Eddie had six rounds and a long way to the Blue Note."],
    "outro": ["His pencil found the notebook one last time. One word: FRANK.", "Eddie Doyle bled out in that alley a little before two.", "At ten past, somebody called me. Somebody always does."]}

CAMPAIGN = [
  {"title": "PROLOGUE", "name": "EDDIE DOYLE", "ready": True, "hero": "eddie", "ambient": [0.2, 0.21, 0.27], "rain": 1.2, "maps": [PROLOGUE]},
  {"title": "CHAPTER I", "name": "RAIN ON HELL'S KITCHEN", "ready": True, "hero": "frank", "ambient": [0.2, 0.21, 0.27], "rain": 1.0, "maps": [
    {"name": "THE ALLEY", "seed": 101, "neon_drop": True, "feature": "alley_mouth", "start": 0.0, "end": 0.35,
     "fixed": ["crate_cover", "drum_duo", "dumpster_alley", "fire_escape", "barrel_trap", "crate_cover", "pistols_cache", "ambush_behind", "gauntlet"],
     "intro": ["The shooters hadn't gone far. Rain doesn't wash a trail away that fast.", "Eddie had left a trail too: pages torn from his diary, nailed up where only I would look."],
     "diary": "Nov 3. Rosie showed me Tommy's photo again. Eleven men burned in '39 and the papers called it bad wiring. Bad wiring doesn't lock doors from the outside.",
     "outro": ["The shooters ran east. So did I."]},
    {"name": "BACK STREETS", "seed": 102, "start": 0.2, "end": 0.5, "el": True,
     "fixed": ["dumpster_alley", "crate_cover", "fire_escape", "ambush_behind", "barrel_trap", "breather", "catwalk", "car_ambush", "drum_duo"],
     "intro": ["Hell's Kitchen doesn't sleep. It just lies there with its eyes open."],
     "diary": "Nov 11. Pulled the Pier 17 file from records. Half of it is missing. The half that's left smells like money.",
     "outro": ["One of them talked before he stopped talking. A laundry on Tenth Avenue."]},
    {"name": "THE LAUNDRY", "seed": 103, "feature": "laundry", "start": 0.35, "end": 0.6,
     "fixed": ["crate_cover", "barrel_trap", "laundry", "blackout", "breather", "warehouse_arena", "fire_escape", "rush"],
     "intro": ["Steam, starch and gun oil.", "Nobody washes shirts at three in the morning."],
     "diary": "Nov 20. Insurance paid out $400,000 to a company owned by a company owned by a church charity. The Saint's charity.",
     "outro": ["A receipt in the back room, signed M. T.", "The back door led up. They always lead up."]},
    {"name": "TENEMENTS", "seed": 104, "start": 0.45, "end": 0.7, "storm": True,
     "fixed": ["tenement", "ambush_behind", "fire_escape", "car_ambush", "breather", "barrel_trap", "tenement", "gauntlet", "scaffold"],
     "roof": True, "roofs": ["roof_b", "roof_a"],
     "intro": ["Iron stairs, wet as a liar's palm."],
     "diary": "Dec 9. The precinct log says who walked the Pier 17 beat that night. I wish I hadn't read it. I need to hear it from him before I take it upstairs.",
     "outro": ["Below me the neon said JAZZ.", "Mickey Teague owned the Blue Note. Somebody else owned Mickey."]},
    {"name": "THE BLUE NOTE", "seed": 105, "feature": "bluenote", "start": 0.6, "end": 0.85, "boss": "teague", "boss_room": "club",
     "fixed": ["crate_cover", "fire_escape", "breather", "warehouse_arena", "rush"],
     "intro": ["Mickey 'Canvas' Teague. Forty fights, and he lost every one he was paid to lose.", "Tonight nobody was paying."],
     "diary": "Dec 17. Meeting a guy from the Blue Note tonight. Says he'll sell me the name of who paid. If I'm wrong about this, I'll buy Frank a drink and tell him everything.",
     "outro": ["Mickey went down on cue, like always. They'd told him to take care of Eddie, and he never could say no. Then: ask your boss.", "Eddie's girl came down off the stage with his diary. I didn't open it. Not then."]},
    # between the chapters: the dream Frank has had every night for eight years (2026-11-15)
    {"name": "THE DREAM", "seed": 106, "feature": "fire_a", "dream": True, "under": True, "rain": 0.0, "start": 0.55, "end": 0.8, "ash": 1.0, "embers": 1.0,
     "fixed": ["arsonists", "beam_fall", "blaze", "loop", "smoke_men", "beam_fall", "arsonists", "blaze", "loop", "beam_fall", "smoke_men", "blaze", "arsonists"],
     "intro": ["I slept an hour in the car outside the Blue Note. Long enough for the dream.", "It's always the same one. I've had it every night for eight years."],
     "outro": ["The knocking stopped at eleven. It always stops before I reach the doors.", "I woke up in the car with smoke in my mouth that no dream had put there. Four in the morning. Eddie's diary on the seat beside me."]},
  ]},
  {"title": "CHAPTER II", "name": "THE DOCKS", "ready": True, "hero": "frank", "ambient": [0.16, 0.18, 0.25], "rain": 1.5, "maps": [
    {"name": "PIER 17", "seed": 201, "feature": "pier17", "pool": DOCKS_POOL, "fog": True, "start": 0.45, "end": 0.7, "ash": 1.0, "embers": 0.6,
     "fixed": ["dock_crates", "crane_swing", "car_ambush", "breather", "barrel_trap", "searchlight_yard", "pistols_cache", "gauntlet"],
     "events": [["burn", "shipping"]],
     "intro": ["Pier 17. Eight years cold, and it still smelled of smoke.", "Somebody had lit a fresh fire to keep it company."],
     "diary": "Nov 24. Went down to Pier 17 at night. You can still see where the doors were chained. Nobody chains a door to keep a fire in by accident.",
     "outro": ["Vail Shipping burned like a confession nobody would ever read. Cornelius Vail owned it. The papers called him the Saint.", "Kessler's men fell back to the cranes."]},
    {"name": "THE CRANES", "seed": 202, "feature": "cranes", "pool": DOCKS_POOL, "start": 0.5, "end": 0.75, "ash": 0.8, "embers": 0.3,
     "fixed": ["crate_cover", "searchlight_yard", "high_ground", "crane_swing", "dock_crates", "rush", "catwalk", "drum_duo"],
     "intro": ["The cranes stood over the yard with their heads bowed, like men at a wake."],
     "diary": "Nov 29. A crane man named Sully told me Kessler had the keys that night. Sully drinks. Sully also cried when he said it.",
     "outro": ["A dock rat with a broken arm told me the rest for a dollar.", "The Santa Lucia. Kessler kept his ledgers aboard."]},
    {"name": "SANTA LUCIA", "seed": 203, "rock": True, "feature": "quay", "pool": DOCKS_POOL, "start": 0.55, "end": 0.8, "ash": 0.7, "embers": 0.2,
     "fixed": ["dock_crates", "crane_swing", "catwalk", "hold", "breather", "blackout", "gauntlet"],
     "intro": ["The Santa Lucia. Registered in Panama, owned in Manhattan, prayed for on Sundays."],
     "diary": "Dec 2. The Santa Lucia sails under the Saint's flag. Its manifest for August '39 lists eleven crates of 'machine parts'. Eleven.",
     "outro": ["The ledger had a page torn out. The stub said August 1939."]},
    {"name": "CARGO HOLD", "seed": 204, "rock": True, "feature": "shipping", "pool": DOCKS_POOL, "start": 0.6, "end": 0.85, "ash": 0.8, "embers": 0.3,
     "fixed": ["hold", "crane_swing", "dock_crates", "hold", "warehouse_arena", "searchlight_yard"],
     "intro": ["Down in the hold the rain sounded like applause for somebody else."],
     "diary": "Dec 5. Frank asked me why I keep at this. I said a reporter's job is to write down what everybody already knows. He didn't laugh.",
     "outro": ["Kessler ran for the harbor office. Men like him always run toward their paperwork."]},
    {"name": "HARBOR MASTER", "seed": 205, "sea": True, "feature": "harbor", "pool": DOCKS_POOL, "start": 0.65, "end": 0.9, "boss": "kessler", "boss_room": "office", "ash": 1.0, "embers": 0.5,
     "fixed": ["dock_crates", "crane_swing", "breather", "searchlight_yard", "rush"],
     "intro": ["Bruno Kessler. Dock master since '38. He hadn't closed a door in eight years."],
     "diary": "Dec 12. If anything happens to me, the report is in the harbor office, second drawer. Frank, if you're reading this, then you already know that I know.",
     "outro": ["Kessler gave me a key on a chain. It had been warm against his chest for eight years.", "In the second drawer, the report. At the bottom, a name I knew better than my own."]},
    # between chapters II and III: in the back of Rourke's car Frank is seventeen again (2026-11-15)
    {"name": "1931", "seed": 206, "feature": "laundry", "memory": True, "pool": ["laundry", "market", "alley", "market_b", "alley_b"], "rain": 0.0,
     "start": 0.5, "end": 0.75, "ash": 1.0, "embers": 1.0,
     "fixed": ["smoke_men", "blaze", "arsonists", "breather", "blaze", "smoke_men", "arsonists", "blaze", "smoke_men"],
     "events": [["burn", "laundry"], ["burn", "market"]],
     "intro": ["I've told this one to myself so many times I can't tell any more which parts are true.", "In the version I tell, I get past the firemen."],
     "outro": ["My father brought out three of the Kowalczyk kids. He went back up for the fourth. The roof came down at ten past two.", "Declan Rourke held me back by the collar. He smelled of smoke and of something else. Kerosene. I was seventeen. I didn't know what it meant."]},
  ]},
  {"title": "CHAPTER III", "name": "UNDERGROUND", "ready": True, "hero": "frank", "ambient": [0.17, 0.16, 0.2], "rain": 0.0, "maps": [
    {"name": "14TH STREET", "seed": 301, "feature": "station14", "pool": UNDER_POOL, "under": True, "cops": True, "start": 0.5, "end": 0.75, "ash": 0.2,
     "fixed": ["train_platform", "crate_cover", "rush", "breather", "train_platform", "drum_duo", "stairs_up"],
     "roof": True, "kit": "mezz", "roofs": ["mezz_a", "mezz_b"],
     "intro": ["The cuffs came off on the third stair. Thirty years of falling down stairs teaches a man something."],
     "diary": "Dec 13. Rourke called me into his office and asked about my 'little crusade'. He offered me a drink. He has never once offered me a drink.",
     "outro": ["Briggs's men knew the stations. I knew the tunnels. Eddie and I used to cut through them on bad nights."]},
    {"name": "THE TUNNELS", "seed": 302, "steam": True, "rats": True, "feature": "tunnel_lo", "pool": UNDER_POOL, "under": True, "cops": True, "start": 0.55, "end": 0.8, "ash": 0.15,
     "fixed": ["blackout", "drum_duo", "train_platform", "cityhall", "ambush_behind", "blackout", "rush", "gauntlet"],
     "intro": ["Down here the dark has a sound. It sounds like trains that never come."],
     "diary": "Dec 14. Found a fireman's helmet in a pawnshop on Ninth. Engine 54. Same company as Frank's old man. The pawnbroker said a cop sold it. Years ago.",
     "outro": ["Briggs was counting his shells out loud somewhere behind me. A man who counts like that has never missed."]},
    {"name": "TRAIN YARD", "seed": 303, "freight": True, "feature": "yard", "pool": ["yard", "yard_b", "yard_c"], "cops": True, "rain": 1.6, "start": 0.55, "end": 0.8, "ash": 0.4,
     "fixed": ["drum_duo", "car_ambush", "searchlight_yard", "crane_swing", "crate_cover", "live_wire", "blackout", "gauntlet"],
     "intro": ["The yard was the only way out that didn't have a badge standing in it."],
     "diary": "Dec 15. 1931. A tenement on West 47th burned with nine families inside. Engine 54 got there first. One fireman went in for the kids and didn't come out. Patrick Malone.",
     "outro": ["The last train out of the yard was an empty one. I've never been so glad of an empty thing."]},
    {"name": "THE LAST TRAIN", "seed": 304, "feature": "tunnel", "pool": ["tunnel", "tunnel_b", "tunnel_c"], "under": True, "cops": True, "moving": 2600, "start": 0.55, "end": 0.85, "ash": 0.0,
     "fixed": ["roof_vents", "breather", "roof_rush", "roof_vents", "breather", "roof_rush", "roof_vents"],
     "intro": ["They caught up with me on the roof of the express. Fifty feet of tunnel to every second, and the girders hang low."],
     "hints": [[2400, "RED LIGHT: A GIRDER. GET DOWN."]],
     "diary": "Dec 16. The fire marshal's 1931 report has a witness: a fireman who ran out before the roof came down. Declan Rourke. He was the first man out.",
     "outro": ["The train ran out of tunnel under the old Bowery. Under that, the Catacombs."]},
    {"name": "THE CATACOMBS", "seed": 305, "flood": True, "rats": True, "feature": "bowery", "pool": UNDER_POOL, "under": True, "cops": True, "start": 0.6, "end": 0.9, "ash": 0.3,
     "boss": "briggs", "boss_room": "catacombs",
     "fixed": ["crate_cover", "catacombs", "breather", "train_platform", "rush", "catacombs"],
     "intro": ["Lieutenant Harlan Briggs. Four Bronze Stars and not one bent dollar. The only honest man who ever hunted me."],
     "diary": "Dec 17, morning. Tonight I'll know. If it's who I think it is, Frank, I'm sorry. Not for finding it. For it being you.",
     "outro": ["The Catacombs went quiet. Somewhere above us the rain was coming down harder."]},
  ]},
  {"title": "CHAPTER IV", "name": "THE SAINT'S TOWER", "ready": False, "hero": "frank", "ambient": [0.23, 0.19, 0.21], "rain": 1.8, "maps": [
    {"name": "ROOFTOPS"}, {"name": "THE BALL"}, {"name": "ELEVATOR SHAFT"}, {"name": "PENTHOUSE"}, {"name": "THE SPIRE"}]},
]


def q(t): return '"' + t.replace('"', '\\"') + '"'
def f(v): return f"{float(v):.1f}"


def gd(campaign):
    out = ["# Generated by gen/levels.py: do not edit by hand, change the generator and run it again.",
           "# CAMPAIGN: chapters (title, name, ready, hero, ambient night colour, rain amount, maps). A map:",
           "# name, end (x of the finish), boss, stand (x where the prologue's last stand starts, or -1),",
           "# intro/outro narration, hints [x, text], boxes [kind, x, width, height], floors [x, y, width, style],",
           "# ramps [x0, y0, x1, y1], rooms [x0, x1, style], lamps [x, y] (inside rooms), pickups [kind, x, y],",
           "# checkpoints [x], enemies {x, y, kind, trig, from, delay, run}: kind post / tommy / shotgun / boss;",
           "# run = he waits off-screen at `from` and runs in to `x` once the hero passes `trig` (+ delay seconds).",
           "extends RefCounted", "", "const CAMPAIGN := ["]
    for ch in campaign:
        out.append("\t{" + f'"title": {q(ch["title"])}, "name": {q(ch["name"])}, "ready": {"true" if ch["ready"] else "false"}, "hero": {q(ch["hero"])}, '
                   f'"ambient": Color({ch["ambient"][0]}, {ch["ambient"][1]}, {ch["ambient"][2]}), "rain": {ch["rain"]}, "maps": [')
        for lv in ch["maps"]:
            if "m" not in lv:
                out.append("\t\t{" + f'"name": {q(lv["name"])}' + "},")
                continue
            m = lv["m"]
            en = ", ".join("{" + f'"x": {f(e["x"])}, "y": {f(e["y"])}, "kind": "{e["kind"]}", "trig": {f(e["trig"] if e["trig"] is not None else -1)}, '
                           f'"from": {f(e["from"] if e["from"] is not None else 0)}, "delay": {f(e["delay"])}, "run": {"true" if e["run"] else "false"}' + "}" for e in m.enemies)
            bx = ", ".join(f'["{b[0]}", {f(b[1])}, {f(BOX[b[0]][0])}, {f(BOX[b[0]][1])}, {f(b[2] if len(b) > 2 else 0.0)}]' for b in m.boxes)
            fl = ", ".join(f'[{f(p[0])}, {f(p[1])}, {f(p[2])}, "{p[3]}"]' for p in m.plats)
            rp = ", ".join(f'[{f(r[0])}, {f(r[1])}, {f(r[2])}, {f(r[3])}' + (f', "{r[4]}"]' if len(r) > 4 else ']') for r in m.ramps)
            rm = ", ".join([f'[{f(r[0])}, {f(r[1])}, "{r[2]}"]' for r in m.rooms] +
                           [f'[{f(a)}, {f(b)}, "section_{st}", {f(-SEC_H * (k + 1))}, {f(-SEC_H * k + 40)}]'   # a room per storey
                            for a, b, n, st in m.sections for k in range(n)])
            sc = ", ".join(f'[{f(a)}, {f(b)}, {n}, "{st}"]' for a, b, n, st in m.sections)
            xc = ", ".join(f'[{f(cx)}, {f(cy)}]' for cx, cy in m.xy_checks)
            sd = ", ".join(f'[{f(sx)}, {f(sy)}, {f(ty)}]' for sx, sy, ty in m.stairdoors)
            fz = ", ".join("[" + ", ".join(f(v) for v in fl) + "]" for fl in m.flats)
            lp = ", ".join(f'[{f(l[0])}, {f(l[1])}]' for l in m.lamps)
            pk = ", ".join(f'["{p[0]}", {f(p[1])}, {f(p[2])}]' for p in m.pickups)
            th = ", ".join(f'["{t[0]}", {f(t[1])}]' for t in m.things)
            hn = ", ".join(f'[{f(h[0])}, {q(h[1])}]' for h in m.hints)
            ck = ", ".join(f(c) for c in m.checks)
            ro = ", ".join(f'["{r[0]}", {f(r[1])}, {f(r[2])}, {f(r[3])}, {f(r[4])}' + ((f', "{r[5]}"' if isinstance(r[5], str) else f', {f(r[5])}') if len(r) > 5 else "") + "]" for r in m.ropes)
            st = ", ".join(f'["{g[0]}", {f(g[1])}' + (f', {f(g[2])}, {f(g[3])}' if len(g) > 3 else "") + "]" for g in m.street)
            out.append("\t\t{" + f'"name": {q(lv["name"])}, "end": {f(m.end)}, "boss": {q(lv.get("boss", ""))}, "stand": {f(m.stand if m.stand else -1)},')
            out.append("\t\t\t\"intro\": [" + ", ".join(q(t) for t in lv["intro"]) + "], \"outro\": [" + ", ".join(q(t) for t in lv["outro"]) + "],")
            out.append(f'\t\t\t"diary": {q(lv.get("diary", ""))}, "ash": {lv.get("ash", 0.3)}, "embers": {lv.get("embers", 0.0)},')
            if "rain" in lv: out.append(f'\t\t\t"rain": {lv["rain"]},')
            if lv.get("under"): out.append('\t\t\t"under": true,')
            if lv.get("dream"): out.append('\t\t\t"dream": true,')
            if lv.get("memory"): out.append('\t\t\t"memory": true,')
            if lv.get("el"): out.append('\t\t\t"el": true,')
            if lv.get("fog"): out.append('\t\t\t"fog": true,')
            for flag in ["storm", "rock", "steam", "sea", "rats", "flood", "neon_drop", "freight"]:
                if lv.get(flag): out.append('\t\t\t"%s": true,' % flag)
            if lv.get("moving"): out.append(f'\t\t\t"moving": {lv["moving"]},')
            if lv.get("cops"): out.append('\t\t\t"cops": true,')
            if m.roof:
                rp_ = ", ".join(f'["{g[0]}", {f(g[1])}]' for g in m.roof[2])
                out.append(f'\t\t\t"roof": {{"x0": {f(m.roof[0])}, "x1": {f(m.roof[1])}, "y": {f(m.kit["y"])}, "goal": {f(m.roof[3])}, '
                           f'"scale": {m.kit["scale"]:.4f}, "line": {m.kit["line"]:.4f}, "stub": {f(m.kit["stub"])}, '
                           f'"pics": [{rp_}], "checks": [{", ".join(f(c) for c in m.roof_checks)}]}},')
            evs = ", ".join("[" + ", ".join(q(v) if isinstance(v, str) else f(v) for v in ev) + "]" for ev in m.events)
            out.append(f'\t\t\t"events": [{evs}],')
            out.append(f'\t\t\t"hints": [{hn}],')
            out.append(f'\t\t\t"boxes": [{bx}],')
            out.append(f'\t\t\t"floors": [{fl}],')
            out.append(f'\t\t\t"ramps": [{rp}],')
            out.append(f'\t\t\t"ropes": [{ro}],')
            out.append(f'\t\t\t"rooms": [{rm}],')
            out.append(f'\t\t\t"lamps": [{lp}],')
            out.append(f'\t\t\t"pickups": [{pk}],')
            out.append(f'\t\t\t"things": [{th}],')
            out.append(f'\t\t\t"checkpoints": [{ck}],')
            if m.sections:
                out.append(f'\t\t\t"sections": [{sc}], "section_h": {f(SEC_H)}, "xy_checks": [{xc}], "stairdoors": [{sd}], "flats": [{fz}],')
            out.append(f'\t\t\t"street": [{st}],')
            out.append(f'\t\t\t"enemies": [{en}]}},')
        out.append("\t]},")
    out.append("]")
    return "\n".join(out) + "\n"


SANDBOX = [
    # the building in cross-section (stand-in drawings until the tenement kit is drawn, gen/QUEUE_doma.md §5)
    {"name": "SECTION", "seed": 901, "start": 0.45, "end": 0.6, "fixed": ["breather", "section"],
     "roof": True, "kit": "troof", "roofs": ["roof_b", "roof_a"], "intro": [], "outro": []},
    # the stunts alone, for a quick look and a quick bot: door kick, window jump, rope swing (--sandbox=1)
    # THE TEST LAB (--sandbox=1, user 16. 11.: one map where every new mechanic is, right from the start):
    # the street kit's awning + fire escape, hydrant, kegs, steam pipe, the hoist rope, then the flat (door kick,
    # window). Few men: only those the kit stands by its hazards and the flat's two. Add each new thing here.
    {"name": "TEST LAB", "seed": 902, "start": 0.3, "end": 0.3, "fixed": ["lab", "laundry", "club", "section"], "intro": [], "outro": [],
     "roof": True, "kit": "troof", "roofs": ["roof_b", "roof_a"],   # (rule 25, 17. 11.: the flat is in a whole house: in at
     # its street door, up its stairs, the door kick and the window onto its own fire escape, up to its roof)
     "street_fixed": ["hk_laundry", "hk_tailor", "hk_grocery", "hk_saloon", "hk_laundry", "warehouse", "alley_mouth", "market"]},
]

SEEN = set()   # a rope hint is shown once in the whole story, on the first map that has that rope

if __name__ == "__main__":
    campaign = []
    n = 0
    bad = False
    for ch in CAMPAIGN:
        maps = []
        for mp in ch["maps"]:
            if "seed" not in mp:   # written up, not yet built: a name in the case file
                maps.append({"name": mp["name"]}); continue
            m = build(mp)
            m.hints = [[h[0], h[1]] for h in mp.get("hints", [])] + [h for h in m.hints if h[1] not in SEEN]
            SEEN.update(h[1] for h in m.hints)
            errs = check(m)
            bad = bad or bool(errs)
            print(f'{ch["title"]:12} {mp["name"]:15} {int(m.end):6} px  {len(m.enemies):3} enemies  {len(m.checks)} checkpoints  ' + ("ERRORS: " + "; ".join(errs) if errs else "ok"))
            n += 1
            draw(m, mp["name"], os.path.join(SIM, f"map_{n:02d}.png"))
            lv = dict(mp); lv["m"] = m
            maps.append(lv)
        c = dict(ch); c["maps"] = maps
        campaign.append(c)
    # Maps for trying a new system before any chapter has it (--sandbox=N): never in the case file
    sand = []
    for mp in SANDBOX:
        m = build(mp)
        errs = check(m)
        print(f'SANDBOX      {mp["name"]:15} {int(m.end):6} px  {len(m.enemies):3} enemies  ' + ("ERRORS: " + "; ".join(errs) if errs else "ok"))
        lv = dict(mp); lv["m"] = m
        sand.append(lv)
    box = gd([{"title": "SANDBOX", "name": "SANDBOX", "ready": False, "hero": "frank", "ambient": [0.2, 0.21, 0.27], "rain": 1.0, "maps": sand}])
    box = box[box.index("const CAMPAIGN := [") + len("const CAMPAIGN := ["):].rstrip().rstrip("]")
    open(os.path.join(REPO, "kit.gd"), "w", encoding="utf-8", newline=chr(10)).write(KIT_CAT.gd())
    open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "levels.gd"), "w").write(
        gd(campaign) + "\n# Trial maps (--sandbox=N): a new system on its own map, never in the case file.\nconst SANDBOX := [" + box + "]\n")
    sys.exit(1 if bad else 0)
