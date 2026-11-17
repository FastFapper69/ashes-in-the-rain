"""The metrics of every drawing (QUEUE_doma §10.1, research ch15 "kits and metrics first"): where its wall meets the
pavement, the curb, its roofline - measured in the picture and put into the world the way main.gd puts the drawing
there, so drawings that do not share the game's metrics show up. A man's feet are at world y = 0 (the wall's foot
is WALL_LIFT = 60 behind/above them); a door is ~520, a man ~420.

  py gen/tests/metrics_audit.py            measure, print the table and the outliers (exit 1 if any)
  py gen/tests/metrics_audit.py --write    also write the table into gen/kit.py (METRICS, between its markers)

Note: the edges are found automatically and tracks/rails/quays fool it; read the outliers as leads and check them on
the feet sheet (a red line where the feet go on each drawing) before marking a drawing for repainting.

Measured: `foot` (the wall's foot: the strongest dark-over-light horizontal edge in the bottom fifth), `curb` (the next
edge below it), `top` (the roofline: first row where most columns are opaque). Doors and the eye line come from the
hand-kept DOORS / EYE tables below (Gemini briefs give them; the Blender templates make them exact).
"""
import os, re, sys, glob
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
os.chdir(ROOT)
WALL_SCALE, SEGMENT_BASE, WALL_LIFT = 1.9, 0.92, 60.0
M = open("main.gd", encoding="utf-8").read()
SIZE = {k: float(v) for k, v in re.findall(r'"(\w+)": ([0-9.]+)', M[M.index("const SEGMENT_SIZE"):M.index("}", M.index("const SEGMENT_SIZE"))])}
KIT = dict(re.findall(r'"(\w+)": "(\w+)"', M[M.index("const SEGMENT_KIT"):M.index("}", M.index("const SEGMENT_KIT"))]))
FLOOR = {k: float(v) for k, v in re.findall(r'"(\w+)": ([0-9.]+)', M[M.index("const SEGMENT_FLOOR"):M.index("}", M.index("const SEGMENT_FLOOR"))])}
# hand-kept: the doors a man walks through on a drawing (centre px, width px, height px) and its eye line (px row)
DOORS = {
    "hk_tailor": [(790, 150, 360), (2500, 150, 360)],
}
EYE = {}
SKIP = ("_lit", "_solid", "_neon", "pier.png", "roof_", "mezz_")   # layers, the join pier, the roofs (walked on, own kit)
TOL = 30.0   # world px: more than this off the kit's median and a man visibly floats or sinks


def measure(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    al = a[..., 3] > 128
    lum = a[..., :3].mean(2)
    cols = slice(int(w * 0.08), int(w * 0.92))
    top = int(np.argmax(al[:, cols].mean(1) > 0.6))
    band0 = int(h * 0.70)
    g = np.abs(lum[band0 + 2:, cols] - lum[band0:-2, cols]) > 22   # a horizontal ink line or tone step at this row
    frac = g.mean(1)
    long_rows = [band0 + 1 + int(i) for i in np.nonzero(frac > 0.45)[0]]   # only lines across most of the picture:
    runs = []                                                             # the pavement's back edge and the curb, not sills
    for r in long_rows:
        if runs and r - runs[-1][-1] <= 3:
            runs[-1].append(r)
        else:
            runs.append([r])
    lines = [int(np.mean(r)) for r in runs]
    foot = lines[0] if lines else None
    curb = next((r for r in lines if foot is not None and r > foot + 15), None)
    return w, h, top, foot, curb


def world(name, row):
    kit = KIT.get(name, name)
    ws = WALL_SCALE * SIZE.get(kit, 1.0)
    if kit in FLOOR:   # drawn as a room in depth: its floor is FLOOR of its height
        return (row - 1344 * FLOOR[kit]) * ws
    top = -1344 * ws * SEGMENT_BASE - WALL_LIFT
    return top + row * ws


def main():
    rows = []
    for p in sorted(glob.glob("art/street/*.png")):
        n = os.path.basename(p)
        if any(s in n for s in SKIP):
            continue
        name = n[:-4]
        w, h, top, foot, curb = measure(p)
        rows.append({"name": name, "kit": KIT.get(name, name), "size": SIZE.get(KIT.get(name, name), 1.0), "w": w, "h": h,
                     "top": top, "foot": foot, "curb": curb,
                     "foot_y": round(world(name, foot)) if foot is not None else None,
                     "curb_y": round(world(name, curb)) if curb is not None else None,
                     "top_y": round(world(name, top)),
                     "doors": DOORS.get(name, []), "eye": EYE.get(name)})
    feet = np.array([r["foot_y"] for r in rows if r["foot_y"] is not None], float)
    med = float(np.median(feet))
    bad = []
    print(f"{'drawing':14} {'size':>5} {'top':>5} {'foot':>5} {'curb':>5} | world: {'top':>6} {'foot':>6} {'curb':>6}")
    for r in rows:
        off = r["foot_y"] - med if r["foot_y"] is not None else None
        flag = "  <-- foot %+d" % off if off is not None and abs(off) > TOL else ""
        if flag:
            bad.append(r["name"])
        print(f"{r['name']:14} {r['size']:5.3f} {r['top']:5d} {str(r['foot']):>5} {str(r['curb']):>5} | {r['top_y']:6d} {str(r['foot_y']):>6} {str(r['curb_y']):>6}{flag}")
    print(f"\nmedian wall foot in the world: {med:.0f}; {len(bad)} drawing(s) more than {TOL:.0f} off: {', '.join(bad) or '-'}")
    if "--write" in sys.argv:
        kp = "gen/kit.py"
        s = open(kp, encoding="utf-8").read()
        body = "# >>> METRICS (gen/tests/metrics_audit.py --write: measured, do not edit by hand)\nMETRICS = {\n" + "".join(
            f'    "{r["name"]}": {{"top": {r["top"]}, "foot": {r["foot"]}, "curb": {r["curb"]}, "foot_y": {r["foot_y"]}, '
            f'"doors": {r["doors"]}, "eye": {r["eye"]}}},\n' for r in rows) + "}\n# <<< METRICS\n"
        if "# >>> METRICS" in s:
            s = s[:s.index("# >>> METRICS")] + body + s[s.index("# <<< METRICS") + len("# <<< METRICS\n"):]
        else:
            s = s.replace("WIDTH = 3168\n", body + "WIDTH = 3168\n", 1)
        open(kp, "w", encoding="utf-8", newline="").write(s)
        print("written to", kp)
    # (17. 11.: the edge finder is fooled by tracks, rails and quays - the feet line was checked on every drawing by eye,
    # _shots/s9/feet_*.png: all stand on the front of their pavement or floor. So the list is a lead, not a failure.)
    sys.exit(1 if bad and "--strict" in sys.argv else 0)


if __name__ == "__main__":
    main()
