"""Where the figure jerks (user 25. 11.: "make every blend smoother"): reads the --jointlog lines of a test run and finds
the frames where a joint's SPEED changes faster than a body can change it (a snap, a skipped frame, a kink at a
hand-over). Positions are in metres (the puppet's own frame), angles in radians.
    py -3 gen/tests/rungd.py ... -- --test=dive --chapter=0 --fwd --jointlog > log.txt ; py -3 gen/tests/jerk.py log.txt [top]
Prints the worst frames: time, the move key, which joint, its change of speed (m/s per frame, rad/s per frame)."""
import sys
CH = ["hip.x", "hip.y", "foot_f.x", "foot_f.y", "foot_b.x", "foot_b.y", "hand_n.x", "hand_n.y", "hand_f.x", "hand_f.y", "lean", "look"]
# what a frame's change of speed may be before it reads as a snap (m/s, rad/s) - a running foot swings hard
LIMIT = {"hip": 1.6, "foot": 4.5, "hand": 3.5, "lean": 9.0, "look": 9.0}
rows = []
for line in open(sys.argv[1], encoding="utf-8", errors="ignore"):
    if line.startswith("JL "):
        p = line.split()
        rows.append((float(p[1]), p[2], [float(x) for x in p[3:15]]))
top = int(sys.argv[2]) if len(sys.argv) > 2 else 25
out = []
for i in range(2, len(rows)):
    (t0, _, a), (t1, _, b), (t2, key, c) = rows[i - 2], rows[i - 1], rows[i]
    d1, d2 = t1 - t0, t2 - t1
    if d1 <= 0 or d2 <= 0 or d1 > 0.2 or d2 > 0.2:
        continue
    for j, name in enumerate(CH):
        v1 = (b[j] - a[j]) / d1
        v2 = (c[j] - b[j]) / d2
        if name in ("lean", "look"):
            import math
            w = lambda x: (x + math.pi) % (2 * math.pi) - math.pi
            v1, v2 = w(b[j] - a[j]) / d1, w(c[j] - b[j]) / d2
        dv = abs(v2 - v1)
        lim = LIMIT[name.split(".")[0].split("_")[0]]
        if dv > lim:
            out.append((dv / lim, t2, key, name, dv))
out.sort(reverse=True)
print("frames", len(rows), "snaps", len(out))
for r, t, key, name, dv in out[:top]:
    print("%.3f  x%.1f  %-28s %-9s dv %.2f" % (t, r, key, name, dv))
