# Level generator for INK & LEAD.
# A level is a run of hand-made encounter chunks, picked and spaced by a seeded generator to a
# difficulty curve, then checked (nothing overlaps, every catwalk can be climbed, every mobster
# stands on something) and drawn as a map for review. Output: levels.gd, a GDScript data file.
import random, json, sys
from PIL import Image, ImageDraw, ImageFont

BOX = {"crate": (250, 248), "drum": (160, 246), "crate_long": (330, 176), "dumpster": (300, 250)}
CAT_Y = -370.0
JUMP_REACH = 282.0   # how high his feet rise in a jump (JUMP_SPEED^2 / 2g)

# Each chunk: width, boxes [kind, x], catwalks [x, w], enemies {x, y, kind, trig, from}.
# x is relative to the chunk start. kind: post = stands and fights (takes cover if a box is just in
# front of him); runner = runs in when the detective passes trig, from `from` (relative x), to x.
def chunk(name, rng, hard):
    E = lambda x, y=0.0, kind="post", trig=None, frm=None: {"x": x, "y": y, "kind": kind, "trig": trig, "from": frm}
    if name == "crate_cover":
        return 1300, [["crate", 0]], [], [E(450), E(1100)] if hard > 0.4 else [E(450)]
    if name == "drum_duo":
        return 1500, [["drum", 200], ["crate", 900]], [], [E(560), E(1350)]
    if name == "catwalk":
        e = [E(900, CAT_Y), E(1500)]
        if hard > 0.5:
            e.append(E(1250, CAT_Y))
        return 1800, [["crate_long", 0]], [[400, 1180]], e
    if name == "dumpster_alley":
        return 1600, [["dumpster", 300]], [], [E(820), E(1400, kind="runner", trig=150, frm=1400 + 1500)]
    if name == "ambush_behind":   # an open stretch: two of them come running up from behind
        return 1500, [["crate", 1100]], [], [E(-350, kind="runner", trig=700, frm=-1500), E(-150, kind="runner", trig=760, frm=-1700)]
    if name == "gauntlet":
        return 2100, [["crate", 0], ["crate", 760], ["crate", 1500]], [], [E(450), E(1210), E(1950)]
    if name == "rush":   # a wave runs at him down the street; one crate to hold behind
        n = 3 if hard > 0.6 else 2
        return 1500, [["crate", 250]], [], [E(1000 + i * 260, kind="runner", trig=0, frm=2600 + i * 300) for i in range(n)]
    if name == "high_ground":   # a catwalk with two of them on it and one crouched under the end of it
        return 2000, [["crate_long", 0], ["drum", 1450]], [[380, 1180]], [E(800, CAT_Y), E(1300, CAT_Y), E(1780)]
    if name == "breather":
        return 700, [], [], []
    raise ValueError(name)

EASY = ["crate_cover", "drum_duo", "catwalk", "dumpster_alley"]
MID = EASY + ["ambush_behind", "gauntlet", "rush", "high_ground"]

# The campaign: chapters of five maps that tell one story. Each map: its chunks are picked from
# `pool` (or given exactly in `fixed`), difficulty runs from `start` to `end`, `boss` ends it with a
# boss fight. intro / outro: the detective's narration, shown as comic captions.
CAMPAIGN = [
  {"title": "CHAPTER I", "name": "RAIN ON HELL'S KITCHEN", "ready": True, "ambient": [0.2, 0.21, 0.27], "rain": 1.0, "maps": [
    {"name": "THE ALLEY", "seed": 101, "fixed": ["crate_cover", "drum_duo", "breather", "crate_cover"], "start": 0.0, "end": 0.3,
     "intro": ["Eddie Doyle bled out in this alley at ten past two.", "The rain was already washing him away."],
     "outro": ["The shooters ran east. So did I."]},
    {"name": "BACK STREETS", "seed": 102, "fixed": ["dumpster_alley", "crate_cover", "ambush_behind", "drum_duo"], "start": 0.2, "end": 0.45,
     "intro": ["Hell's Kitchen doesn't sleep. It just lies there with its eyes open."],
     "outro": ["One of them talked before he stopped talking. A laundry on Tenth Avenue."]},
    {"name": "THE LAUNDRY", "seed": 103, "fixed": ["gauntlet", "breather", "dumpster_alley", "rush"], "start": 0.35, "end": 0.6,
     "intro": ["Steam, starch and gun oil.", "Nobody washes shirts at three in the morning."],
     "outro": ["The back door led up. They always lead up."]},
    {"name": "FIRE ESCAPES", "seed": 104, "fixed": ["catwalk", "ambush_behind", "high_ground", "breather", "catwalk"], "start": 0.45, "end": 0.7,
     "intro": ["Iron stairs, wet as a liar's palm."],
     "outro": ["Below me the neon said JAZZ.", "Sal Russo liked his music loud and his witnesses quiet."]},
    {"name": "THE BLUE NOTE", "seed": 105, "fixed": ["crate_cover", "rush", "breather"], "start": 0.6, "end": 0.8, "boss": "sal",
     "intro": ["Sal 'Knuckles' Russo. Moretti's hammer.", "Tonight the hammer was going to meet a nail."],
     "outro": ["Sal coughed up two words before the end: the docks.", "Moretti's shipment was coming in tonight."]},
  ]},
  {"title": "CHAPTER II", "name": "THE DOCKS", "ready": False, "ambient": [0.16, 0.18, 0.25], "rain": 1.5, "maps": [
    {"name": "PIER 17"}, {"name": "WAREHOUSE ROW"}, {"name": "THE CRANES"}, {"name": "CARGO DECK"}, {"name": "HARBOR MASTER"}]},
  {"title": "CHAPTER III", "name": "UNDERGROUND", "ready": False, "ambient": [0.18, 0.17, 0.2], "rain": 0.0, "maps": [
    {"name": "THE PLATFORM"}, {"name": "THE TUNNELS"}, {"name": "TRAIN YARD"}, {"name": "THE LAST TRAIN"}, {"name": "THE SPEAKEASY"}]},
  {"title": "CHAPTER IV", "name": "THE SAINT'S TOWER", "ready": False, "ambient": [0.23, 0.19, 0.21], "rain": 1.8, "maps": [
    {"name": "ROOFTOPS"}, {"name": "HOTEL LOBBY"}, {"name": "ELEVATOR SHAFT"}, {"name": "PENTHOUSE"}, {"name": "THE SPIRE"}]},
]


def build(mp):
    rng = random.Random(mp["seed"])
    x = 1300.0   # a quiet start
    boxes, cats, enemies = [], [], []
    picks = mp["fixed"]
    n = len(picks)
    for i, name in enumerate(picks):
        hard = mp["start"] + (mp["end"] - mp["start"]) * i / max(1, n - 1)
        w, b, c, e = chunk(name, rng, hard)
        for k, bx in b:
            boxes.append([k, x + bx])
        for cx, cw in c:
            cats.append([x + cx, CAT_Y, cw])
        for en in e:
            en = dict(en); en["x"] += x
            if en["trig"] is not None: en["trig"] += x
            if en["from"] is not None: en["from"] += x
            enemies.append(en)
        x += w + rng.uniform(450, 800)
    if mp.get("boss"):   # the boss holds the end of the street behind two crates, his men run in to help
        boxes += [["crate", x + 300], ["dumpster", x + 1500]]
        enemies += [{"x": x + 1050, "y": 0.0, "kind": "post", "trig": None, "from": None},
                    {"x": x + 2050, "y": 0.0, "kind": "boss", "trig": None, "from": None}]
        end = x + 2300
    else:   # a last stand behind the final crates
        boxes += [["crate", x], ["crate", x + 380]]
        enemies += [{"x": x + 800, "y": 0.0, "kind": "post", "trig": None, "from": None},
                    {"x": x + 1100, "y": 0.0, "kind": "runner", "trig": x - 200, "from": x + 2600}]
        end = x + 1600
    return {"name": mp["name"], "end": end, "boss": mp.get("boss", ""), "intro": mp["intro"], "outro": mp["outro"],
            "boxes": [[k, bx, BOX[k][0], BOX[k][1]] for k, bx in boxes], "catwalks": cats, "enemies": enemies, "picks": picks}


def check(lv):
    errs = []
    bs = sorted(lv["boxes"], key=lambda b: b[1])
    for a, b in zip(bs, bs[1:]):
        if a[1] + a[2] > b[1] - 1:
            errs.append(f"boxes overlap at {a[1]}")
    for cx, cy, cw in lv["catwalks"]:
        # a step within reach under its left end: something low enough to stand on and jump up from
        ok = any(b[1] <= cx + 60 and b[1] + b[2] >= cx - 500 and b[3] + JUMP_REACH > -cy for b in bs)
        if not ok:
            errs.append(f"catwalk at {cx} cannot be climbed")
    for en in lv["enemies"]:
        if en["y"] < 0 and not any(cx < en["x"] < cx + cw for cx, cy, cw in lv["catwalks"]):
            errs.append(f"enemy at {en['x']} floats")
        if en["y"] == 0 and any(b[1] - 40 < en["x"] < b[1] + b[2] + 40 for b in bs):
            errs.append(f"enemy at {en['x']} stands in a box")
    return errs


def draw(lv, path):
    W = 2400; k = W / (lv["end"] + 600)
    im = Image.new("RGB", (W, 260), (30, 30, 34)); d = ImageDraw.Draw(im)
    gy = 200
    d.line([(0, gy), (W, gy)], fill=(120, 120, 120), width=2)
    for k_, bx, bw, bh in lv["boxes"]:
        d.rectangle([bx * k, gy - bh * k * 2, (bx + bw) * k, gy], fill=(150, 110, 60))
    for cx, cy, cw in lv["catwalks"]:
        d.rectangle([cx * k, gy + cy * k * 2 - 3, (cx + cw) * k, gy + cy * k * 2], fill=(180, 180, 200))
    for en in lv["enemies"]:
        ex, ey = en["x"] * k, gy + en["y"] * k * 2
        col = (220, 40, 40) if en["kind"] == "post" else (255, 160, 40)
        d.rectangle([ex - 4, ey - 60 * k * 2 * 3, ex + 4, ey], fill=col)
        if en["kind"] == "runner":
            d.line([(en["from"] * k, ey - 30), (ex, ey - 30)], fill=col, width=1)
            d.line([(en["trig"] * k, gy + 10), (en["trig"] * k, gy + 40)], fill=(255, 220, 80), width=2)
    d.line([(lv["end"] * k, 20), (lv["end"] * k, gy)], fill=(80, 220, 80), width=3)
    d.text((8, 6), f'{lv["name"]}   length {int(lv["end"])} px   enemies {len(lv["enemies"])}   ' + " > ".join(lv["picks"]), fill=(230, 230, 230))
    im.save(path)


def q(t): return '"' + t.replace('"', '\\"') + '"'


def gd(campaign):
    out = ["# Generated by gen/levels.py: do not edit by hand, change the generator and run it again.",
           "# CAMPAIGN: chapters (title, name, ready, ambient night colour, rain amount, maps). A map: name, end (x of",
           "# the finish), boss, intro/outro narration, boxes [kind, x, width, height], catwalks [x, y, width],",
           "# enemies {x, y, kind, trig, from}: post stands his ground; runner runs in from `from` to `x` once the",
           "# detective passes `trig`; boss is the chapter's last fight.",
           "extends RefCounted", "", "const CAMPAIGN := ["]
    for ch in campaign:
        out.append("\t{" + f'"title": {q(ch["title"])}, "name": {q(ch["name"])}, "ready": {"true" if ch["ready"] else "false"}, '
                   f'"ambient": Color({ch["ambient"][0]}, {ch["ambient"][1]}, {ch["ambient"][2]}), "rain": {ch["rain"]}, "maps": [')
        for lv in ch["maps"]:
            if "end" not in lv:
                out.append("\t\t{" + f'"name": {q(lv["name"])}' + "},")
                continue
            en = ", ".join("{" + f'"x": {e["x"]:.0f}.0, "y": {e["y"]:.0f}.0, "kind": "{e["kind"]}", "trig": {e["trig"] if e["trig"] is not None else -1.0:.0f}.0, "from": {e["from"] if e["from"] is not None else 0.0:.0f}.0' + "}" for e in lv["enemies"])
            bx = ", ".join(f'["{b[0]}", {b[1]:.0f}.0, {b[2]:.0f}.0, {b[3]:.0f}.0]' for b in lv["boxes"])
            ct = ", ".join(f'[{c[0]:.0f}.0, {c[1]:.0f}.0, {c[2]:.0f}.0]' for c in lv["catwalks"])
            out.append("\t\t{" + f'"name": {q(lv["name"])}, "end": {lv["end"]:.0f}.0, "boss": {q(lv["boss"])},')
            out.append("\t\t\t\"intro\": [" + ", ".join(q(t) for t in lv["intro"]) + "], \"outro\": [" + ", ".join(q(t) for t in lv["outro"]) + "],")
            out.append(f'\t\t\t"boxes": [{bx}],')
            out.append(f'\t\t\t"catwalks": [{ct}],')
            out.append(f'\t\t\t"enemies": [{en}]}},')
        out.append("\t]},")
    out.append("]")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    campaign = []
    n = 0
    for ch in CAMPAIGN:
        maps = []
        for mp in ch["maps"]:
            if not ch["ready"]:
                maps.append({"name": mp["name"]}); continue
            lv = build(mp)
            errs = check(lv)
            print(ch["title"], lv["name"], int(lv["end"]), len(lv["enemies"]), "enemies", "ERRORS:" if errs else "ok", errs)
            n += 1
            draw(lv, f"/home/claude/sim/map{n}.png")
            maps.append(lv)
        c = dict(ch); c["maps"] = maps
        campaign.append(c)
    open(sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/outputs/godot2/levels.gd", "w").write(gd(campaign))
