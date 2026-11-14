# Level generator for INK & LEAD.
# A map is a run of hand-made chunks (street fights, interiors, fire escapes, arenas), placed one after
# another by a seeded generator to a difficulty curve, then checked (nothing overlaps, every floor can be
# reached, nobody floats) and drawn as a map for review. Output: levels.gd, a GDScript data file.
#
# Run:  python3 gen/levels.py [out.gd]     maps are drawn to /home/claude/sim/map_*.png
import random, sys
from PIL import Image, ImageDraw

# kind: (width, height, wood?)  wood breaks under fire, the rest holds; barrel explodes
BOX = {"crate": (250, 248, True), "drum": (160, 246, False), "crate_long": (330, 176, True), "dumpster": (300, 250, False),
       "barrel": (120, 170, False), "machine": (260, 230, False), "bar": (420, 190, False)}
# the drawn street segments (art/street) and their widths in the world (picture width x 1.9)
SEGMENTS = {"alley": 3028, "bluenote": 3028, "warehouse": 3028, "laundry": 3028, "subway": 3108, "church": 3108, "market": 3038, "deadend": 3038,
            "pier17": 3034, "cranes": 3034, "shipping": 3034, "quay": 3034, "harbor": 3034,
            "platform": 3034, "tunnel": 3034, "yard": 3034}
STREET_POOL = ["alley", "warehouse", "laundry", "subway", "church", "market"]
DOCKS_POOL = ["pier17", "cranes", "shipping", "quay", "harbor"]
UNDER_POOL = ["platform", "tunnel"]
CRANE_CRATE = (0.3863 + 0.0783 / 2)   # where the crate hangs in the crane yard drawing (see main.gd CRANE_CUT)
F1, F2 = -370.0, -740.0   # floor heights: first and second storey
JUMP_REACH = 282.0


class Chunk:
    def __init__(self, width):
        self.w = width
        self.boxes, self.plats, self.ramps, self.rooms, self.lamps = [], [], [], [], []
        self.enemies, self.pickups, self.hints, self.checks = [], [], [], []
        self.stand = None
        self.end = 0.0
        self.street = []
        self.events = []

    def box(self, kind, x): self.boxes.append([kind, x]); return self
    def plat(self, x, y, w, style="catwalk"): self.plats.append([x, y, w, style]); return self
    def ramp(self, x0, y0, x1, y1): self.ramps.append([x0, y0, x1, y1]); return self
    def room(self, x0, x1, style): self.rooms.append([x0, x1, style]); self.checks += [x0 - 60]; return self
    def lamp(self, x, y=-760.0): self.lamps.append([x, y]); return self
    def pick(self, kind, x, y=0.0): self.pickups.append([kind, x, y]); return self
    def hint(self, x, text): self.hints.append([x, text]); return self
    def event(self, *ev): self.events.append(list(ev)); return self

    def foe(self, x, y=0.0, kind="post", trig=None, frm=None, delay=0.0, run=False):
        self.enemies.append({"x": x, "y": y, "kind": kind, "trig": trig, "from": frm, "delay": delay, "run": run}); return self

    def runner(self, x, trig, frm, kind="post", delay=0.0, y=0.0):
        return self.foe(x, y, kind, trig, frm, delay, True)


def chunk(name, hard):
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
    elif name == "gauntlet":
        c = Chunk(2100).box("crate", 0).box("crate", 760).box("crate", 1500).foe(450).foe(1210, kind="shotgun" if hard > 0.6 else "post").foe(1950)
    elif name == "rush":
        n = 3 if hard > 0.6 else 2
        c = Chunk(1500).box("crate", 250)
        for i in range(n):
            c.runner(1000 + i * 260, 0, 2600 + i * 300, kind="shotgun" if i == 2 else "post")
    elif name == "catwalk":
        c = Chunk(1800).box("crate_long", 0).plat(400, F1, 1180).foe(900, F1).foe(1500)
        if hard > 0.5: c.foe(1250, F1)
    elif name == "high_ground":
        c = Chunk(2000).box("crate_long", 0).box("drum", 1450).plat(380, F1, 1180).foe(800, F1).foe(1300, F1, kind="tommy" if hard > 0.6 else "post").foe(1780)
    elif name == "fire_escape":   # up the iron stairs two storeys, fighting on every landing, then a drop
        c = (Chunk(2900).ramp(150, 0, 650, F1).plat(650, F1, 950, "escape").ramp(1600, F1, 2100, F2).plat(2100, F2, 700, "escape")
             .foe(1300, F1).foe(1900, 0.0).foe(2650, F2, kind="tommy" if hard > 0.4 else "post").foe(2300, 0.0, kind="shotgun" if hard > 0.6 else "post")
             .pick("flask", 2500, F2))
    elif name == "laundry":   # an interior: machines for cover, steam, a shotgunner in the back
        c = (Chunk(2700).room(0, 2700, "laundry").box("machine", 500).box("machine", 1300).box("machine", 2050)
             .lamp(400).lamp(1250).lamp(2150).foe(1000).foe(1750, kind="shotgun").foe(2450).pick("flask", 1180))
    elif name == "warehouse_arena":   # a locked room: waves through both doors
        c = (Chunk(2400).room(0, 2400, "warehouse").box("crate", 500).box("barrel", 1150).box("crate", 1650).lamp(700).lamp(1700)
             .runner(2050, 300, 2900).runner(2250, 300, 3100)
             .runner(300, 300, -900, delay=5.0).runner(1400, 300, 3000, kind="tommy", delay=9.0)
             .runner(150, 300, -1100, kind="shotgun", delay=13.0).pick("tommy", 1000))
    elif name == "tenement":   # a stairwell: up a flight, along the landing, back down
        c = (Chunk(2300).room(0, 2300, "tenement").ramp(250, 0, 750, F1).plat(750, F1, 800, "floor").ramp(1550, F1, 2050, 0.0)
             .lamp(1150, -900).foe(1200, F1).foe(1000, 0.0, kind="shotgun" if hard > 0.5 else "post").foe(2200, 0.0).pick("flask", 1150, F1))
    elif name == "club":   # the Blue Note: the bar for cover, tables, a stage at the back
        c = (Chunk(2600).room(0, 2600, "club").box("bar", 400).box("crate_long", 1300).box("barrel", 1900).lamp(500).lamp(1400).lamp(2300)
             .foe(1050).foe(1700, kind="shotgun").foe(2400, kind="tommy").runner(1100, 900, -800, delay=2.0))
    # ---- the docks -------------------------------------------------------------------------------
    elif name == "dock_crates":   # cargo waiting on the quay, and them behind it
        c = Chunk(1700).box("crate_long", 0).box("crate", 700).box("drum", 1350).foe(500).foe(1150).foe(1650, kind="tommy" if hard > 0.5 else "post")
    elif name == "car_ambush":   # a sedan pulls up ahead and three of them pile out behind it
        c = Chunk(2700).box("crate", 0).foe(700).event("car", 350, 2000, 1, 3)
    elif name == "searchlight_yard":   # a searchlight on a pole sweeps the yard: in it, they do not miss
        c = (Chunk(2300).box("crate", 200).box("crate_long", 1150).foe(750).foe(1650).foe(2150, kind="shotgun" if hard > 0.5 else "post")
             .event("searchlight", 1150, -1350, 0))
    elif name == "blackout":   # the power goes: only muzzle flashes, and they cannot see him either
        c = (Chunk(2100).box("dumpster", 300).box("crate", 1350).foe(950).foe(1850, kind="tommy").runner(1150, 400, 3200)
             .event("blackout", 120, 10))
    elif name == "hold":   # below decks on the Santa Lucia: crates lashed down, lamps swinging
        c = (Chunk(2700).room(0, 2700, "hold").box("crate", 450).box("crate_long", 1250).box("drum", 2000).lamp(500).lamp(1400).lamp(2250)
             .foe(1000).foe(1850, kind="shotgun").foe(2450, kind="tommy" if hard > 0.5 else "post").pick("flask", 860))
    elif name == "office":   # the harbor master's: filing cabinets and a counter for cover
        c = (Chunk(2400).room(0, 2400, "office").box("crate_long", 500).box("machine", 1500).lamp(600).lamp(1700)
             .foe(1150).foe(2000, kind="shotgun").foe(2300).pick("flask", 1000))
    # ---- underground --------------------------------------------------------------------------------
    elif name == "train_platform":   # along the tracks under the platform edge; a train roars by on the far rails
        c = (Chunk(2400).box("drum", 250).box("crate_long", 1100).foe(700).foe(1650, kind="shotgun" if hard > 0.5 else "post").foe(2250)
             .event("train_pass", 300))
    elif name == "cityhall":   # the closed station: chandeliers, boarded booths, rain through the skylight
        c = (Chunk(2600).room(0, 2600, "cityhall").box("crate", 500).box("machine", 1500).lamp(700).lamp(1800)
             .foe(1100).foe(2000, kind="tommy" if hard > 0.4 else "post").foe(2450).pick("flask", 900))
    elif name == "catacombs":   # the speakeasy in the sewer vaults: the bar and the tables for cover
        c = (Chunk(2800).room(0, 2800, "catacombs").box("crate", 400).box("crate_long", 1300).box("drum", 2200).lamp(500).lamp(1500).lamp(2400)
             .foe(900).foe(1850, kind="shotgun").foe(2600, kind="tommy" if hard > 0.5 else "post"))
    elif name == "roof_vents":   # on top of the moving train: the vent housings are all the cover there is
        c = Chunk(2000).foe(950).foe(1850, kind="tommy" if hard > 0.5 else "post")
    elif name == "roof_rush":   # they climb up from the cars behind and in front
        c = Chunk(1800).foe(300).runner(1200, 100, 2900).runner(1500, 200, 3200, kind="shotgun").runner(-200, 600, -1400)
    elif name == "breather":
        c = Chunk(700)
    elif name == "pistols_cache":   # a dead man's guns on the pavement
        c = Chunk(900).pick("pistols", 450)
    if c is None:
        raise ValueError(name)
    return c


def build(mp):
    rng = random.Random(mp["seed"])
    x = 1900.0   # the first of them out of sight of the start
    out = Chunk(0)
    picks = list(mp["fixed"])
    n = len(picks)
    for i, name in enumerate(picks):
        hard = mp["start"] + (mp["end"] - mp["start"]) * i / max(1, n - 1)
        c = chunk(name, hard)
        for k, bx in c.boxes: out.boxes.append([k, x + bx])
        for px, py, pw, st in c.plats: out.plats.append([x + px, py, pw, st])
        for a, b, cc, d in c.ramps: out.ramps.append([x + a, b, x + cc, d])
        for a, b, st in c.rooms: out.rooms.append([x + a, x + b, st])
        for lx, ly in c.lamps: out.lamps.append([x + lx, ly])
        for k, px, py in c.pickups: out.pickups.append([k, x + px, py])
        for hx, t in c.hints: out.hints.append([x + hx, t])
        for ev in c.events:
            ev = list(ev)
            if ev[0] == "car": ev[1] += x; ev[2] += x
            elif ev[0] == "blackout": ev[1] += x
            elif ev[0] in ("searchlight", "train_pass"): ev[1] += x
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
    if extra:
        extra(out, x)
    elif mp.get("boss"):
        if mp.get("boss_room"):   # the fight in a room of its own
            out.rooms.append([x - 200, x + 2700, mp["boss_room"]])
            out.lamps += [[x + 400, -760.0], [x + 1400, -760.0], [x + 2300, -760.0]]
        out.boxes += [["crate", x + 300], ["crate_long" if mp.get("boss_room") else "dumpster", x + 1500]]
        out.enemies += [{"x": x + 1050, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False},
                        {"x": x + 2050, "y": 0.0, "kind": "boss", "trig": None, "from": None, "delay": 0.0, "run": False}]
        out.checks.append(x - 100)
        out.end = x + 2300
    else:
        out.boxes += [["crate", x], ["crate", x + 380]]
        out.enemies += [{"x": x + 800, "y": 0.0, "kind": "post", "trig": None, "from": None, "delay": 0.0, "run": False},
                        {"x": x + 1100, "y": 0.0, "kind": "tommy", "trig": x - 200, "from": x + 2600, "delay": 0.0, "run": True}]
        out.end = x + 1600
    if mp.get("diary"):   # a page of Eddie's notebook, left on top of a crate partway along: a climb off the road
        cands = sorted([b for b in out.boxes if b[0] in ("crate", "crate_long", "dumpster", "machine", "drum") and 2500 < b[1] < out.end - 2500], key=lambda b: b[1])
        if cands:
            b = cands[min(len(cands) - 1, mp.get("page", len(cands) // 2))]
            out.pickups.append(["page", b[1] + BOX[b[0]][0] / 2, -BOX[b[0]][1]])
        else:   # nothing to climb: it lies where the fight is thickest, halfway along
            out.pickups.append(["page", out.end * 0.55, 0.0])
    out.checks = sorted(set(round(c) for c in out.checks if 800 < c < out.end - 500))
    out.street = street(mp, out, rng)
    for e in mp.get("events", []):
        out.events.append(list(e))
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


def street(mp, m, rng):
    """The run of drawn segments under the map: the map's own feature segment early on, no segment twice
    in a row, and (in the prologue) the dead-end alley under the last stand."""
    seq, x = [], -3000.0
    pool = [s for s in mp.get("pool", STREET_POOL) if s != mp.get("feature")] or [mp["feature"]]
    last = None
    i = 0
    while x < m.end + 2500:
        if i == 1 and mp.get("feature"):
            name = mp["feature"]
        elif m.stand and "deadend" not in [q[0] for q in seq] and x + SEGMENTS["deadend"] * 1.9 > m.stand + 1000:
            name = "deadend"
        else:   # each segment once before any comes back
            used = [q[0] for q in seq]
            fresh = [s for s in pool if s not in used]
            name = rng.choice(fresh if fresh else ([s for s in pool if s != last] or pool))
        seq.append([name, x])
        last = name
        x += SEGMENTS[name] * 1.9
        i += 1
    return seq


def last_stand(out, x):   # the prologue's end: a dead-end alley and more of them than Eddie has bullets
    out.boxes += [["crate", x + 200], ["dumpster", x + 1150]]
    out.hints.append([x, "NOWHERE LEFT TO RUN"])
    out.stand = x + 600
    out.end = x + 1700


def check(m):
    errs = []
    bs = sorted(m.boxes, key=lambda b: b[1])
    for a, b in zip(bs, bs[1:]):
        if a[1] + BOX[a[0]][0] > b[1] - 1:
            errs.append(f"boxes overlap at {a[1]:.0f}")
    floors = [(p[0], p[0] + p[2], p[1]) for p in m.plats]
    for px, py, pw, st in m.plats:
        # reachable: a ramp ends on it, or something within jumping reach stands under its near end
        ok = any(abs(r[3] - py) < 1 and px - 20 <= r[2] <= px + pw + 20 for r in m.ramps)
        ok = ok or any(abs(r[1] - py) < 1 and px - 20 <= r[0] <= px + pw + 20 for r in m.ramps)
        ok = ok or any(b[1] <= px + 60 and b[1] + BOX[b[0]][0] >= px - 500 and BOX[b[0]][1] + JUMP_REACH > -py for b in bs)
        if not ok:
            errs.append(f"floor at {px:.0f},{py:.0f} cannot be reached")
    for en in m.enemies:
        if en["y"] < 0 and not any(a <= en["x"] <= b and abs(y - en["y"]) < 1 for a, b, y in floors):
            errs.append(f"enemy at {en['x']:.0f} floats")
        if en["y"] == 0 and any(b[1] - 40 < en["x"] < b[1] + BOX[b[0]][0] + 40 for b in bs):
            errs.append(f"enemy at {en['x']:.0f} stands in a box")
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
    im = Image.new("RGB", (W, 300), (30, 30, 34)); d = ImageDraw.Draw(im)
    gy = 250; vy = lambda y: gy + y * k * 2.4
    for a, b, st in m.rooms:
        d.rectangle([a * k, vy(-1000), b * k, gy], fill=(52, 44, 40))
    d.line([(0, gy), (W, gy)], fill=(120, 120, 120), width=2)
    for kind, bx in m.boxes:
        w, h, wood = BOX[kind]
        d.rectangle([bx * k, vy(-h), (bx + w) * k, gy], fill=(200, 40, 40) if kind == "barrel" else ((150, 110, 60) if wood else (110, 110, 120)))
    for px, py, pw, st in m.plats:
        d.rectangle([px * k, vy(py) - 2, (px + pw) * k, vy(py) + 1], fill=(190, 190, 210))
    for a, b, c, e in m.ramps:
        d.line([(a * k, vy(b)), (c * k, vy(e))], fill=(190, 190, 210), width=2)
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


PROLOGUE = {"name": "THE LAST NOTE", "seed": 1, "feature": "bluenote", "start": 0.0, "end": 0.2, "extra": last_stand,
    "fixed": ["breather", "crate_cover", "drum_duo", "barrel_trap", "rush"],
    "hints": [[200, "DRAG THE STICK TO MOVE"], [1500, "TAP ANYWHERE TO SHOOT THERE"], [2700, "PULL THE STICK DOWN TO HIDE BEHIND COVER"],
              [4300, "THE RUNNING MAN BUTTON DIVES OVER CRATES"], [6100, "SHOOT THE RED BARREL"], [7900, "TAP THE STOPWATCH TO SLOW TIME"]],
    "intro": ["December 17th, 1947. Eddie Doyle had a meeting behind the Blue Note.", "He was early. He was always early."],
    "outro": ["His pencil found the notebook one last time. One word: FRANK.", "Eddie Doyle bled out in this alley at ten past two.", "Somebody had to call me. Somebody always does."]}

CAMPAIGN = [
  {"title": "PROLOGUE", "name": "EDDIE DOYLE", "ready": True, "hero": "eddie", "ambient": [0.2, 0.21, 0.27], "rain": 1.2, "maps": [PROLOGUE]},
  {"title": "CHAPTER I", "name": "RAIN ON HELL'S KITCHEN", "ready": True, "hero": "frank", "ambient": [0.2, 0.21, 0.27], "rain": 1.0, "maps": [
    {"name": "THE ALLEY", "seed": 101, "feature": "alley", "start": 0.0, "end": 0.35,
     "fixed": ["crate_cover", "drum_duo", "dumpster_alley", "breather", "barrel_trap", "crate_cover", "pistols_cache", "ambush_behind", "gauntlet"],
     "intro": ["The shooters hadn't gone far. Rain doesn't wash a trail away that fast.", "Neither does whiskey. I'd tried."],
     "diary": "Nov 3. Rosie showed me Tommy's photo again. Eleven men burned in '39 and the papers called it bad wiring. Bad wiring doesn't lock doors from the outside.",
     "outro": ["The shooters ran east. So did I."]},
    {"name": "BACK STREETS", "seed": 102, "start": 0.2, "end": 0.5,
     "fixed": ["dumpster_alley", "crate_cover", "fire_escape", "ambush_behind", "barrel_trap", "breather", "catwalk", "car_ambush", "drum_duo"],
     "intro": ["Hell's Kitchen doesn't sleep. It just lies there with its eyes open."],
     "diary": "Nov 11. Pulled the Pier 17 file from records. Half of it is missing. The half that's left smells like money.",
     "outro": ["One of them talked before he stopped talking. A laundry on Tenth Avenue."]},
    {"name": "THE LAUNDRY", "seed": 103, "feature": "laundry", "start": 0.35, "end": 0.6,
     "fixed": ["crate_cover", "barrel_trap", "laundry", "blackout", "breather", "warehouse_arena", "fire_escape", "rush"],
     "intro": ["Steam, starch and gun oil.", "Nobody washes shirts at three in the morning."],
     "diary": "Nov 20. Insurance paid out $400,000 to a company owned by a company owned by a church charity. The Saint's charity.",
     "outro": ["A receipt in the back room, signed M. T.", "The back door led up. They always lead up."]},
    {"name": "TENEMENTS", "seed": 104, "start": 0.45, "end": 0.7,
     "fixed": ["tenement", "ambush_behind", "fire_escape", "car_ambush", "breather", "high_ground", "barrel_trap", "tenement", "gauntlet"],
     "intro": ["Iron stairs, wet as a liar's palm."],
     "diary": "Dec 9. Found the patrolman who signed the report. I wish I hadn't. I need to hear it from him before I take it upstairs.",
     "outro": ["Below me the neon said JAZZ.", "Mickey Teague owned the Blue Note. Somebody else owned Mickey."]},
    {"name": "THE BLUE NOTE", "seed": 105, "feature": "bluenote", "start": 0.6, "end": 0.85, "boss": "teague",
     "fixed": ["crate_cover", "barrel_trap", "club", "breather", "warehouse_arena", "rush"],
     "intro": ["Mickey 'Canvas' Teague. Forty fights, and he lost every one he was paid to lose.", "Tonight nobody was paying."],
     "diary": "Dec 17. Meeting a guy from the Blue Note tonight. Says he'll sell me the name of who paid. If I'm wrong about this, I'll buy Frank a drink and tell him everything.",
     "outro": ["Mickey went down on cue, like always. He asked me to feed his birds. Then: ask your boss.", "Eddie's girl came down off the stage with his notebook. I didn't open it. Not then."]},
  ]},
  {"title": "CHAPTER II", "name": "THE DOCKS", "ready": True, "hero": "frank", "ambient": [0.16, 0.18, 0.25], "rain": 1.5, "maps": [
    {"name": "PIER 17", "seed": 201, "feature": "pier17", "pool": DOCKS_POOL, "start": 0.45, "end": 0.7, "ash": 1.0, "embers": 0.6,
     "fixed": ["dock_crates", "crate_cover", "car_ambush", "breather", "barrel_trap", "searchlight_yard", "pistols_cache", "gauntlet"],
     "events": [["burn", "shipping"]],
     "intro": ["Pier 17. Eight years cold, and it still smelled of smoke.", "Somebody had lit a fresh fire to keep it company."],
     "diary": "Nov 24. Went down to Pier 17 at night. You can still see where the doors were chained. Nobody chains a door to keep a fire in by accident.",
     "outro": ["Vail Shipping burned like a confession nobody would ever read.", "Kessler's men fell back to the cranes."]},
    {"name": "THE CRANES", "seed": 202, "feature": "cranes", "pool": DOCKS_POOL, "start": 0.5, "end": 0.75, "ash": 0.8, "embers": 0.3,
     "fixed": ["crate_cover", "searchlight_yard", "high_ground", "blackout", "dock_crates", "rush", "catwalk", "drum_duo"],
     "intro": ["The cranes stood over the yard with their heads bowed, like men at a wake."],
     "diary": "Nov 29. A crane man named Sully told me Kessler had the keys that night. Sully drinks. Sully also cried when he said it.",
     "outro": ["A dock rat with a broken arm told me the rest for a dollar.", "The Santa Lucia. Kessler kept his ledgers aboard."]},
    {"name": "SANTA LUCIA", "seed": 203, "feature": "quay", "pool": DOCKS_POOL, "start": 0.55, "end": 0.8, "ash": 0.7, "embers": 0.2,
     "fixed": ["dock_crates", "car_ambush", "catwalk", "hold", "breather", "blackout", "gauntlet"],
     "intro": ["The Santa Lucia. Registered in Panama, owned in Manhattan, prayed for on Sundays."],
     "diary": "Dec 2. The Santa Lucia sails under the Saint's flag. Its manifest for August '39 lists eleven crates of 'machine parts'. Eleven.",
     "outro": ["The ledger had a page torn out. The stub said August 1939."]},
    {"name": "CARGO HOLD", "seed": 204, "feature": "shipping", "pool": DOCKS_POOL, "start": 0.6, "end": 0.85, "ash": 0.8, "embers": 0.3,
     "fixed": ["hold", "rush", "dock_crates", "hold", "warehouse_arena", "searchlight_yard"],
     "intro": ["Down in the hold the rain sounded like applause for somebody else."],
     "diary": "Dec 5. Frank asked me why I keep at this. I said a reporter's job is to write down what everybody already knows. He didn't laugh.",
     "outro": ["Kessler ran for the harbor office. Men like him always run toward their paperwork."]},
    {"name": "HARBOR MASTER", "seed": 205, "feature": "harbor", "pool": DOCKS_POOL, "start": 0.65, "end": 0.9, "boss": "kessler", "ash": 1.0, "embers": 0.5,
     "fixed": ["dock_crates", "car_ambush", "office", "breather", "searchlight_yard", "rush"],
     "intro": ["Bruno Kessler. Dock master since '38. He hadn't closed a door in eight years."],
     "diary": "Dec 12. If anything happens to me, the report is in the harbor office, second drawer. Frank, if you're reading this, then you already know that I know.",
     "outro": ["Kessler gave me a key on a chain. It had been warm against his chest for eight years.", "In the second drawer, the report. At the bottom, a name I knew better than my own."]},
  ]},
  {"title": "CHAPTER III", "name": "UNDERGROUND", "ready": False, "hero": "frank", "ambient": [0.17, 0.16, 0.2], "rain": 0.0, "maps": [
    {"name": "14TH STREET", "seed": 301, "feature": "platform", "pool": UNDER_POOL, "under": True, "cops": True, "start": 0.5, "end": 0.75, "ash": 0.2,
     "fixed": ["train_platform", "crate_cover", "rush", "breather", "train_platform", "drum_duo", "gauntlet"],
     "intro": ["The cuffs came off on the third stair. Thirty years of falling down stairs teaches a man something."],
     "diary": "Dec 13. Rourke called me into his office and asked about my 'little crusade'. He offered me a drink. He has never once offered me a drink.",
     "outro": ["Briggs's men knew the stations. I knew the tunnels. Eddie and I used to cut through them on bad nights."]},
    {"name": "THE TUNNELS", "seed": 302, "feature": "tunnel", "pool": UNDER_POOL, "under": True, "cops": True, "start": 0.55, "end": 0.8, "ash": 0.15,
     "fixed": ["blackout", "drum_duo", "train_platform", "cityhall", "ambush_behind", "blackout", "rush", "gauntlet"],
     "intro": ["Down here the dark has a sound. It sounds like trains that never come."],
     "diary": "Dec 14. Found a fireman's helmet in a pawnshop on Ninth. Engine 54. Same company as Frank's old man. The pawnbroker said a cop sold it. Years ago.",
     "outro": ["Briggs was counting his shells out loud somewhere behind me. A man who counts like that has never missed."]},
    {"name": "TRAIN YARD", "seed": 303, "feature": "yard", "pool": ["yard"], "cops": True, "rain": 1.6, "start": 0.55, "end": 0.8, "ash": 0.4,
     "fixed": ["drum_duo", "car_ambush", "searchlight_yard", "breather", "crate_cover", "blackout", "gauntlet"],
     "intro": ["The yard was the only way out that didn't have a badge standing in it."],
     "diary": "Dec 15. 1931. A tenement on West 47th burned with nine families inside. Engine 54 got there first. One fireman went in for the kids and didn't come out. Patrick Malone.",
     "outro": ["The last train out of the yard was an empty one. I've never been so glad of an empty thing."]},
    {"name": "THE LAST TRAIN", "seed": 304, "feature": "tunnel", "pool": ["tunnel"], "under": True, "cops": True, "moving": 2600, "start": 0.55, "end": 0.85, "ash": 0.0,
     "fixed": ["roof_vents", "breather", "roof_rush", "roof_vents", "breather", "roof_rush", "roof_vents"],
     "intro": ["They caught up with me on the roof of the express. Fifty feet of tunnel to every second, and the girders hang low."],
     "hints": [[2400, "RED LIGHT: A GIRDER. GET DOWN."]],
     "diary": "Dec 16. The fire marshal's 1931 report has a witness: a fireman who ran out before the roof came down. Declan Rourke. He was the first man out.",
     "outro": ["The train ran out of tunnel under the old Bowery. Under that, the Catacombs."]},
    {"name": "THE CATACOMBS", "seed": 305, "feature": "platform", "pool": UNDER_POOL, "under": True, "cops": True, "start": 0.6, "end": 0.9, "ash": 0.3,
     "boss": "briggs", "boss_room": "catacombs",
     "fixed": ["crate_cover", "catacombs", "breather", "train_platform", "rush", "catacombs"],
     "intro": ["Lieutenant Harlan Briggs. Four Bronze Stars and not one bent dollar. The only honest man who ever hunted me."],
     "diary": "Dec 17, morning. Tonight I'll know. If it's who I think it is, Frank, I'm sorry. Not for finding it. For it being you.",
     "outro": ["Briggs had found the other half of the truth in Rourke's desk. He gave it to me like a man handing back a wallet."]},
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
            bx = ", ".join(f'["{b[0]}", {f(b[1])}, {f(BOX[b[0]][0])}, {f(BOX[b[0]][1])}]' for b in m.boxes)
            fl = ", ".join(f'[{f(p[0])}, {f(p[1])}, {f(p[2])}, "{p[3]}"]' for p in m.plats)
            rp = ", ".join(f'[{f(r[0])}, {f(r[1])}, {f(r[2])}, {f(r[3])}]' for r in m.ramps)
            rm = ", ".join(f'[{f(r[0])}, {f(r[1])}, "{r[2]}"]' for r in m.rooms)
            lp = ", ".join(f'[{f(l[0])}, {f(l[1])}]' for l in m.lamps)
            pk = ", ".join(f'["{p[0]}", {f(p[1])}, {f(p[2])}]' for p in m.pickups)
            hn = ", ".join(f'[{f(h[0])}, {q(h[1])}]' for h in m.hints)
            ck = ", ".join(f(c) for c in m.checks)
            st = ", ".join(f'["{g[0]}", {f(g[1])}]' for g in m.street)
            out.append("\t\t{" + f'"name": {q(lv["name"])}, "end": {f(m.end)}, "boss": {q(lv.get("boss", ""))}, "stand": {f(m.stand if m.stand else -1)},')
            out.append("\t\t\t\"intro\": [" + ", ".join(q(t) for t in lv["intro"]) + "], \"outro\": [" + ", ".join(q(t) for t in lv["outro"]) + "],")
            out.append(f'\t\t\t"diary": {q(lv.get("diary", ""))}, "ash": {lv.get("ash", 0.3)}, "embers": {lv.get("embers", 0.0)},')
            if "rain" in lv: out.append(f'\t\t\t"rain": {lv["rain"]},')
            if lv.get("under"): out.append('\t\t\t"under": true,')
            if lv.get("moving"): out.append(f'\t\t\t"moving": {lv["moving"]},')
            if lv.get("cops"): out.append('\t\t\t"cops": true,')
            evs = ", ".join("[" + ", ".join(q(v) if isinstance(v, str) else f(v) for v in ev) + "]" for ev in m.events)
            out.append(f'\t\t\t"events": [{evs}],')
            out.append(f'\t\t\t"hints": [{hn}],')
            out.append(f'\t\t\t"boxes": [{bx}],')
            out.append(f'\t\t\t"floors": [{fl}],')
            out.append(f'\t\t\t"ramps": [{rp}],')
            out.append(f'\t\t\t"rooms": [{rm}],')
            out.append(f'\t\t\t"lamps": [{lp}],')
            out.append(f'\t\t\t"pickups": [{pk}],')
            out.append(f'\t\t\t"checkpoints": [{ck}],')
            out.append(f'\t\t\t"street": [{st}],')
            out.append(f'\t\t\t"enemies": [{en}]}},')
        out.append("\t]},")
    out.append("]")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    campaign = []
    n = 0
    bad = False
    for ch in CAMPAIGN:
        maps = []
        for mp in ch["maps"]:
            if not ch["ready"]:
                maps.append({"name": mp["name"]}); continue
            m = build(mp)
            m.hints = [[h[0], h[1]] for h in mp.get("hints", [])] + m.hints
            errs = check(m)
            bad = bad or bool(errs)
            print(f'{ch["title"]:12} {mp["name"]:15} {int(m.end):6} px  {len(m.enemies):3} enemies  {len(m.checks)} checkpoints  ' + ("ERRORS: " + "; ".join(errs) if errs else "ok"))
            n += 1
            draw(m, mp["name"], f"/home/claude/sim/map_{n:02d}.png")
            lv = dict(mp); lv["m"] = m
            maps.append(lv)
        c = dict(ch); c["maps"] = maps
        campaign.append(c)
    open(sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/outputs/godot2/levels.gd", "w").write(gd(campaign))
    sys.exit(1 if bad else 0)
