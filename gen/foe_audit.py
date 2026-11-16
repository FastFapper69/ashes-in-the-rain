# How the men stand in every map (2026-11-16): on which floor, with or without cover between them and
# the way Frank comes, how far apart, how many at once. Run from gen/: python3 foe_audit.py
import importlib.util, sys
spec = importlib.util.spec_from_file_location("lv", "levels.py")
lv = importlib.util.module_from_spec(spec); spec.loader.exec_module(lv)
tot = {"n": 0, "open": 0, "covered": 0, "runner": 0, "upper": 0}
for ch in lv.CAMPAIGN:
    for mp in ch["maps"]:
        if "seed" not in mp:
            continue
        m = lv.build(mp)
        rows = []
        foes = sorted(m.enemies, key=lambda e: e["x"])
        op = cov = run = up = 0
        for e in foes:
            if e["run"]:
                run += 1; continue
            if e["y"] < -10:
                up += 1; continue
            # cover: a box on the street whose right edge is 30..300 px to his left (Frank comes from the left)
            c = any(len(b) == 2 and 30 < e["x"] - (b[1] + lv.BOX[b[0]][0]) < 300 and lv.BOX[b[0]][1] > 200 for b in m.boxes)
            cov += c; op += (not c)
        gaps = [round(b["x"] - a["x"]) for a, b in zip(foes, foes[1:]) if not a["run"] and not b["run"]]
        tight = sum(1 for g in gaps if g < 250)
        print(f'{mp["name"]:15} men {len(foes):3}  open {op:2}  cover {cov:2}  upper {up:2}  runners {run:2}  gaps<250: {tight}')
        tot["n"] += len(foes); tot["open"] += op; tot["covered"] += cov; tot["runner"] += run; tot["upper"] += up
print(tot)
