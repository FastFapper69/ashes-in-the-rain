"""Where the cover stands and what it stands in front of: barrels, repeats, spacing, rooms (2026-11-16)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import levels as lv

def seg_at(m, x):
    for name, sx in m.street:
        if sx <= x < sx + lv.SEGMENTS.get(name, 3034) * lv.SEG_SIZE.get(name, 1.0) / (lv.SEG_SIZE.get(name, 1.0)):
            return name
    return "?"

def where(m, x):
    for a, b, st in m.rooms:
        if a <= x < b: return "room:" + st
    best = None
    for name, sx in m.street:
        if sx <= x: best = name
    return best

for ch in lv.CAMPAIGN:
    for mp in ch["maps"]:
        if "seed" not in mp: continue
        m = lv.build(mp)
        st = sorted([b for b in m.boxes if (b[2] if len(b) > 2 else 0.0) == 0.0], key=lambda b: b[1])
        out = []
        for b in st:
            if b[0] == "barrel": out.append(f"BARREL@{int(b[1])}:{where(m, b[1])}")
        for a, b in zip(st, st[1:]):
            gap = b[1] - (a[1] + lv.BOX[a[0]][0])
            if gap < 300: out.append(f"tight {a[0]}->{b[0]} gap {int(gap)} @{int(a[1])} {where(m, a[1])}")
        print(mp["name"], "|", "; ".join(out))
