"""Photograph every join between kinds of space (QUEUE_doma §9.3): each interior's two ends and each house's street door,
from outside and from inside, on every map and trial map, at 1560 and 1280 wide. One contact sheet per width:
_shots/joins/sheet_<width>.png (a row per join: outside | inside).

Run from the repo root:  py gen/tests/joins_shots.py [--width 1560] [--only <map name>]
"""
import os, sys, glob, shutil, subprocess
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_maps as A

G = A.G
OUT = "_shots/joins"


def joins(mp):
    """[(label, x outside, x inside)] for the map's interiors and houses."""
    js = []
    for r in mp.get("rooms", []):
        if str(r[2]).startswith("section_"):
            continue
        js.append((f"{r[2]} in", r[0] - 260, r[0] + 260))
        js.append((f"{r[2]} out", r[1] + 260, r[1] - 260))
    for x0, x1, n, st in mp.get("sections", []):
        js.append((f"house {st} door", x0 - 260, x0 + 260))
    return js


def main():
    os.chdir(A.ROOT)
    widths = [int(sys.argv[sys.argv.index("--width") + 1])] if "--width" in sys.argv else [1560, 1280]
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    campaign, sandbox = A.load_levels()
    maps = [(f"--chapter={ci}", f"--map={mi}", mp) for ci, ch in enumerate(campaign) for mi, mp in enumerate(ch["maps"]) if "street" in mp]
    sb = [m for ch in sandbox for m in ch.get("maps", [ch])]
    maps += [(f"--sandbox={mi}", "", mp) for mi, mp in enumerate(sb) if "street" in mp]
    os.makedirs(OUT, exist_ok=True)
    for wd in widths:
        rows = []
        for a1, a2, mp in maps:
            if only and mp["name"] != only:
                continue
            js = joins(mp)
            if not js:
                continue
            xs = [x for _, xo, xi in js for x in (xo, xi)]
            for f in glob.glob("_shots/look_*.png"):
                os.remove(f)
            args = [sys.executable, "gen/tests/rungd.py", "--idle", "25", "--max", str(40 + 3 * len(xs)), "--", G, "--path", ".",
                    "--rendering-driver", "opengl3", "--resolution", f"{wd}x720", "--fixed-fps", "30", "--",
                    "--test=look:" + ",".join(f"{x:.0f}" for x in xs), a1] + ([a2] if a2 else [])
            subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            for k, (label, xo, xi) in enumerate(js):
                pair = []
                for j in (2 * k, 2 * k + 1):
                    p = f"_shots/look_{j}.png"
                    pair.append(Image.open(p).convert("RGB").resize((wd // 3, 240)) if os.path.exists(p) else Image.new("RGB", (wd // 3, 240)))
                rows.append((f"{mp['name']}  {label}  x {xo:.0f} | {xi:.0f}", pair))
            print(wd, mp["name"], len(js), "joins")
        if not rows:
            continue
        tw = wd // 3
        sheet = Image.new("RGB", (tw * 2 + 10, 262 * len(rows)), "white")
        for i, (lab, pair) in enumerate(rows):
            for k, t in enumerate(pair):
                sheet.paste(t, (k * (tw + 10), i * 262 + 20))
            ImageDraw.Draw(sheet).text((4, i * 262 + 4), lab, fill=(200, 0, 0))
        sheet.save(f"{OUT}/sheet_{wd}.png")
        print("sheet", os.path.abspath(f"{OUT}/sheet_{wd}.png"), len(rows), "joins")


if __name__ == "__main__":
    main()
