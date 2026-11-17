"""Audit every map (campaign + sandbox) for the user's standing rules (knowledge §1, 10, 15, 19) and seams:

  RULES (from levels.gd): nothing hangs or stands without a reason
    - a swing rope hangs from a crane (docks / yard maps) or a painted hoist pulley (its anchor y is set)
    - a ladder / climbing rope reaches a floor at its top; a zip line starts on a floor
    - a room lamp is inside a room; every floor is a known style
  SEAMS (from the street drawings): where one drawing ends and the next begins, the two edges are compared in
    world space (both scaled and lifted as main.gd does). Something painted right up to an edge that the next
    drawing does not continue (smoke cut off, a lit window halved, a wall begun mid-air) shows as a big change
    across the seam. Each seam gets a score; the worst are listed, and with --shots the game photographs them
    (one --test=look per map) into _shots/audit/ with a contact sheet to look at.

Run from the repo root:  py -3 gen/tests/audit_maps.py [--shots] [--top N]
Exit code 1 when a rule is broken (seams are only ranked: they need eyes).
"""
import os, re, sys, glob, subprocess, shutil
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import kit as KITCAT
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
if __name__ == "__main__":
    os.chdir(ROOT)
G = os.environ.get("G", os.path.join(os.path.expanduser("~"), "Downloads", "Godot_v4.7.2-stable_win64_console.exe"))


# ---- levels.gd as Python data ------------------------------------------------------------------------------
def load_levels():
    src = open("levels.gd", encoding="utf-8").read()
    src = "\n".join(l for l in src.splitlines() if not l.lstrip().startswith("#"))
    def lit(name):
        i = src.index(f"const {name} := ") + len(f"const {name} := ")
        depth, j = 0, i
        while True:
            c = src[j]
            if c in "[{(": depth += 1
            elif c in "]})": depth -= 1
            j += 1
            if depth == 0: break
        t = src[i:j]
        t = re.sub(r"Color\(([^)]*)\)", r"[\1]", t).replace("true", "True").replace("false", "False").replace("null", "None")
        return eval(t)
    return lit("CAMPAIGN"), lit("SANDBOX")


def main_consts():
    """The numbers main.gd places the street drawings with."""
    m = open(os.path.join(ROOT, "main.gd"), encoding="utf-8").read()
    def dict_of(name):
        i = m.index(f"const {name} := {{"); j = m.index("}", i)
        return {k: float(v) for k, v in re.findall(r'"(\w+)": ([0-9.]+)', m[i:j])}
    def kit():
        i = m.index("const SEGMENT_KIT := {"); j = m.index("}", i)
        return dict(re.findall(r'"(\w+)": "(\w+)"', m[i:j]))
    num = lambda n: float(re.search(rf"const {n} := ([0-9.]+)", m).group(1))
    return {"trim": dict_of("SEGMENT_TRIM"), "size": dict_of("SEGMENT_SIZE"), "kit": kit(),
            "floor": dict_of("SEGMENT_FLOOR") if "const SEGMENT_FLOOR := {" in m else {},
            "WALL_SCALE": num("WALL_SCALE"), "SEGMENT_BASE": num("SEGMENT_BASE"), "WALL_LIFT": num("WALL_LIFT")}


# ---- rules -------------------------------------------------------------------------------------------------
CRANE_MAPS = ("docks", "pier", "crane", "santa", "cargo", "harbor", "yard")
def rules(title, mp):
    errs = []
    name = mp["name"]
    floors = mp.get("floors", [])
    rooms = mp.get("rooms", [])
    def floor_at(x, y, tol=60.0):
        return any(abs(f[1] - y) < tol and f[0] - 40 <= x <= f[0] + f[2] + 40 for f in floors) or \
               any(abs(r[1] - y) < tol and min(r[0], r[2]) - 40 <= x <= max(r[0], r[2]) + 40 for r in mp.get("ramps", [])) or \
               (mp.get("roof") and abs(mp["roof"]["y"] - y) < tol and mp["roof"]["x0"] - 40 <= x <= mp["roof"]["x1"] + 40)
    for ro in mp.get("ropes", []):
        kind, x, y0 = ro[0], ro[1], ro[2]
        if kind == "swing":
            crane = any(k in (name + " " + title).lower() for k in CRANE_MAPS)
            if y0 == 0.0 and not crane:
                errs.append(f"swing rope at {x:.0f} hangs from nothing (no crane here, no hoist anchor)")
        elif kind in ("ladder", "climb"):
            top = y0 if y0 else ro[4]
            if not floor_at(x, top, 120.0) and not floor_at(x, ro[4], 120.0):
                errs.append(f"{kind} at {x:.0f} reaches no floor at its top ({top:.0f})")
        elif kind == "zip":
            if not floor_at(x, y0, 200.0):
                errs.append(f"zip line at {x:.0f} starts on no floor")
    for l in mp.get("lamps", []):
        if not any(r[0] <= l[0] <= r[1] for r in rooms):
            errs.append(f"room lamp at {l[0]:.0f} hangs outside any room")
    errs += joins(mp)
    return errs


# ---- joins (rule 25, user 17. 11.: "I can't go from a window into an open alley") -------------------------------
ROW = ("tenrow_a", "tenrow_b", "tenrow_c", "tenrow_d", "hk_tailor", "hk_grocery", "hk_saloon", "hk_laundry",
       "front_laundry", "front_warehouse", "front_club", "front_tenement")   # row houses a house in cross-section may stand among
def joins(mp):
    """How the spaces join: a house in cross-section stands in a row of houses like it (never pasted on a shop
    street, an alley or a quay); its flat's window opens onto that house's own fire escape; an interior (seen
    only from inside, a dip through black at its doorway) never overlaps a house or another interior."""
    errs = []
    st = mp.get("street", [])
    for (a, xa, *ca), (b, xb, *cb) in zip(st, st[1:]):   # edge contracts (QUEUE §10.2): neighbours meet on the same kind of edge
        if not ca and not cb and not KITCAT.joins(a, b):   # (a drawing cut under a building front ends at the front's party wall)
            errs.append(f"join at {xb:.0f}: {a} ends in {KITCAT.EDGES[a][1]}, {b} begins with {KITCAT.EDGES[b][0]}")
    def drawing_at(x):
        here = [g[0] for g in st if g[1] + (g[2] if len(g) > 3 else 0.0) <= x]
        return here[-1] if here else None
    secs = mp.get("sections", [])
    plain = [r for r in mp.get("rooms", []) if not str(r[2]).startswith("section_")]
    for x0, x1, n, style in secs:
        for x in (x0 - 600, x0, (x0 + x1) / 2, x1, x1 + 600):
            d = drawing_at(x)
            if d not in ROW:
                errs.append(f"house {style} at {x0:.0f}-{x1:.0f}: beside it at {x:.0f} the street is '{d}', not a row of houses")
                break
        for r in plain:
            if r[0] < x1 + 300 and r[1] > x0 - 300:
                errs.append(f"interior {r[2]} at {r[0]:.0f}-{r[1]:.0f} overlaps the house at {x0:.0f}-{x1:.0f}")
    for f in mp.get("flats", []):   # [door x, storey y, door h, window in, window out, sill, lintel]
        win_out, y = f[4], f[1]
        esc = [p for p in mp.get("floors", []) if p[3] == "fescape" and abs(p[0] - win_out) < 400]
        if not esc:
            errs.append(f"flat window at {win_out:.0f} (storey {y:.0f}) opens onto no fire escape of its own house")
    for n, x0, *_ in st:   # nothing standing in front of a kit piece's door, gate or painted thing
        p = KITCAT.PIECES.get(n)
        for a, b in (p or {}).get("clear", []):
            ca, cb = x0 + a * 1.9 * p["size"], x0 + b * 1.9 * p["size"]
            for bx in mp.get("boxes", []):
                if (len(bx) < 5 or bx[4] == 0.0) and bx[1] < cb and bx[1] + bx[2] > ca:
                    errs.append(f"{bx[0]} at {bx[1]:.0f} stands in front of {n}'s clear ground {ca:.0f}-{cb:.0f}")
    for r in plain:   # no fight across an interior's door (research ch15: transitions only without enemies on)
        for door in (r[0], r[1]):
            for e in mp.get("enemies", []):
                if e["y"] == 0.0 and not (r[0] < e["x"] < r[1]) and 0 < abs(e["x"] - door) < 690:
                    errs.append(f"{e['kind']} at {e['x']:.0f} waits {abs(e['x'] - door):.0f} from the door of {r[2]} at {door:.0f}")
    for a, b in zip(sorted(plain), sorted(plain)[1:]):
        if b[0] < a[1] + 300:
            errs.append(f"interiors {a[2]} and {b[2]} at {a[1]:.0f}/{b[0]:.0f} run into each other")
    return errs


# ---- seams -------------------------------------------------------------------------------------------------
_img = {}
def drawing(art):
    if art not in _img:
        p = os.path.join(ROOT, "art", "street", f"{art}.png")
        _img[art] = np.asarray(Image.open(p).convert("RGB")).astype(np.float32) / 255.0 if os.path.exists(p) else None
    return _img[art]


def edge_world(art, C, side, rows):
    """The drawing's left or right edge (a 40 px band) sampled at world rows `rows` (None where it has nothing)."""
    im = drawing(art)
    if im is None:
        return None
    kit = C["kit"].get(art, art)
    ws = C["WALL_SCALE"] * C["size"].get(kit, 1.0)
    h, w = im.shape[:2]
    trim = C["trim"].get(kit, 0.0)
    top = -h * ws * (C["floor"].get(kit, C["SEGMENT_BASE"])) - (0.0 if kit in C["floor"] else C["WALL_LIFT"])
    band = im[:, int(trim) + 2:int(trim) + 42] if side == "left" else im[:, w - 42:w - 2]
    out = np.full((len(rows), 3), np.nan, np.float32)
    for i, y in enumerate(rows):
        r = int((y - top) / ws)
        if 0 <= r < h:
            out[i] = band[r].mean(0)
    return out


def seams(mp, C):
    st = mp.get("street", [])
    rows = np.arange(-2400.0, -20.0, 8.0)
    res = []
    for (a, xa, *ca), (b, xb, *cb) in zip(st, st[1:]):
        if ca or cb:
            continue   # (a cut under a building front: no seam of two drawings' edges)
        ea, eb = edge_world(a, C, "right", rows), edge_world(b, C, "left", rows)
        if ea is None or eb is None:
            continue
        both = ~np.isnan(ea[:, 0]) & ~np.isnan(eb[:, 0])
        if both.sum() < 10:
            continue
        d = np.abs(ea[both] - eb[both]).mean(1)
        # bright soft things (smoke, glow, lit windows) cut off: brighter on one side than the other
        lum_a, lum_b = ea[both].mean(1), eb[both].mean(1)
        cut = np.maximum(lum_a - lum_b, lum_b - lum_a)
        score = float(np.percentile(d, 90) * 0.6 + np.percentile(cut, 95) * 0.4)
        # one side painted where the other has nothing (a wall begun in mid-air / the sky)
        only = int((np.isnan(ea[:, 0]) != np.isnan(eb[:, 0])).sum())
        res.append({"x": xb, "a": a, "b": b, "score": score + only * 0.002, "only": only})
    return res


# ---- shots of the worst seams ------------------------------------------------------------------------------
def shoot(jobs):
    out = "_shots/audit"
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    tiles = []
    for (title, mi, sb, name), xs in jobs.items():
        args = [G, "--path", ".", "--resolution", "1560x720", "--fixed-fps", "30", "--",
                "--test=look:" + ",".join(f"{x:.0f}" for x, _ in xs), "--center"]
        args += [f"--sandbox={mi}"] if sb else [f"--chapter={title}", f"--map={mi}"]
        for f in glob.glob("_shots/look_*.png"):
            os.remove(f)
        subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60 + 3 * len(xs))
        for k, (x, label) in enumerate(xs):
            p = f"_shots/look_{k}.png"
            if os.path.exists(p):
                dst = f"{out}/{name.replace(' ', '_')}_{x:.0f}.png"
                shutil.move(p, dst)
                tiles.append((dst, f"{name} x {x:.0f}  {label}"))
    if tiles:
        W, H = 780, 360
        sheet = Image.new("RGB", (W * 2, H * ((len(tiles) + 1) // 2)), "white")
        for i, (p, lab) in enumerate(tiles):
            t = Image.open(p).convert("RGB").resize((W, H))
            d = ImageDraw.Draw(t)
            d.line([(W // 2, 0), (W // 2, H)], fill=(255, 0, 0), width=1)   # the seam (camera centred near it)
            d.rectangle([0, H - 18, W, H], fill=(0, 0, 0)); d.text((4, H - 16), lab, fill=(255, 255, 0))
            sheet.paste(t, ((i % 2) * W, (i // 2) * H))
        sheet.save(f"{out}/sheet.png")
        print("contact sheet:", os.path.abspath(f"{out}/sheet.png"))


def main():
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 12
    campaign, sandbox = load_levels()
    C = main_consts()
    bad, all_seams = 0, []
    maps = [(ci, mi, False, ch["title"], mp) for ci, ch in enumerate(campaign) for mi, mp in enumerate(ch["maps"]) if "street" in mp]
    sb_maps = [m for ch in sandbox for m in ch.get("maps", [ch])]   # (SANDBOX is one case of trial maps)
    maps += [(0, mi, True, "SANDBOX", mp) for mi, mp in enumerate(sb_maps) if "street" in mp]
    for ci, mi, sb, title, mp in maps:
        errs = rules(title, mp)
        for e in errs:
            print(f"RULE  {title} / {mp['name']}: {e}")
        bad += len(errs)
        for s in seams(mp, C):
            all_seams.append((s["score"], ci, mi, sb, mp["name"], s))
    all_seams.sort(key=lambda t: -t[0])
    print(f"\n{len(all_seams)} seams; the {top} worst (score, map, x, left | right drawing):")
    jobs = {}
    for sc, ci, mi, sb, name, s in all_seams[:top]:
        print(f"SEAM  {sc:.3f}  {name:16} x {s['x']:8.0f}  {s['a']} | {s['b']}" + (f"  (one side bare over {s['only']} rows)" if s["only"] else ""))
        jobs.setdefault((ci, mi, sb, name), []).append((s["x"], f"{s['a']} | {s['b']}  {sc:.2f}"))
    if "--shots" in sys.argv:
        shoot(jobs)
    print(f"\n{bad} rule problem(s)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__" and "--strips" not in sys.argv:
    main()


# ---- a strip of each map: the whole street end to end, for judging the run of drawings and the pace ----------
def strips():
    """py -3 gen/tests/audit_maps.py --strips : one picture per map in _shots/audit/strip_<map>.png, a shot every
    ~3200 px along the street (the camera at the pavement), with the drawing's name and what happens there."""
    campaign, sandbox = load_levels()
    os.makedirs("_shots/audit", exist_ok=True)
    for ci, ch in enumerate(campaign):
        for mi, mp in enumerate(ch["maps"]):
            if "street" not in mp:
                continue
            xs = list(np.arange(800.0, mp["end"], 3200.0))
            for f in glob.glob("_shots/look_*.png"):
                os.remove(f)
            subprocess.run([G, "--path", ".", "--resolution", "1560x720", "--fixed-fps", "30", "--",
                            "--test=look:" + ",".join(f"{x:.0f}" for x in xs), f"--chapter={ci}", f"--map={mi}", "--center"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=200)
            tiles = []
            for k, x in enumerate(xs):
                p = f"_shots/look_{k}.png"
                if not os.path.exists(p):
                    continue
                seg = [s[0] for s in mp["street"] if s[1] <= x][-1:] or ["?"]
                foes = sum(1 for e in mp.get("enemies", []) if abs(e["x"] - x) < 1600)
                room = next((r[2] for r in mp.get("rooms", []) if r[0] <= x <= r[1]), "")
                t = Image.open(p).convert("RGB").resize((520, 240))
                d = ImageDraw.Draw(t)
                d.rectangle([0, 222, 520, 240], fill=(0, 0, 0))
                d.text((4, 224), f"x {x:.0f}  {seg[0]}  {room}  men {foes}", fill=(255, 255, 0))
                tiles.append(t)
            if tiles:
                cols = 4
                sheet = Image.new("RGB", (520 * cols, 240 * ((len(tiles) + cols - 1) // cols)), "white")
                for i, t in enumerate(tiles):
                    sheet.paste(t, ((i % cols) * 520, (i // cols) * 240))
                name = mp["name"].replace(" ", "_").replace("'", "")
                sheet.save(f"_shots/audit/strip_{ci}_{mi}_{name}.png")
                print("strip", ci, mi, mp["name"], len(tiles))


if __name__ == "__main__" and "--strips" in sys.argv:
    strips()
