"""Telemetry pictures (task 8, research ch14): where players die along each map, and how far they get.

The rows come from Supabase public.ashes_events (anon may only insert; READ ONLY through the Supabase MCP, no key in the
repo). In a Claude session run
    select kind, map, x, y, build, session, data from ashes_events where kind <> 'test' order by id
and save the result as JSON (a list of rows) to _shots/events.json, then:
    py -3 gen/tools/heatmap.py [_shots/events.json]
Out: _shots/heatmap.png - one strip per map (map order of the campaign): deaths as a heat band along its length
(x in world px, 0 .. the map's end from levels.gd), map_done and quit counts at the side; and the funnel: how many
sessions reached / finished each map.
"""
import json, os, re, sys
from collections import defaultdict
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from paths import REPO


def map_lengths():
    """name -> its end x, in the campaign's order (levels.gd)."""
    src = open(os.path.join(REPO, "levels.gd"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'"name": "([^"]+)"[^\n]*?"end": ([0-9.]+)', src):
        out.setdefault(m.group(1), float(m.group(2)))
    return out


def main(path):
    rows = json.load(open(path, encoding="utf-8"))
    ends = map_lengths()
    deaths, done, quits, reached = defaultdict(list), defaultdict(int), defaultdict(int), defaultdict(set)
    for r in rows:
        m = r.get("map") or "?"
        reached[m].add(r.get("session"))
        if r["kind"] == "death":
            deaths[m].append(float(r.get("x") or 0.0))
        elif r["kind"] == "map_done":
            done[m] += 1
        elif r["kind"] == "quit":
            quits[m] += 1
    names = [n for n in ends if n in reached] + sorted(n for n in reached if n not in ends)
    W, ROW, LEFT = 1400, 46, 210
    img = Image.new("RGB", (W, 40 + ROW * max(1, len(names))), (24, 22, 20))
    d = ImageDraw.Draw(img)
    d.text((10, 10), f"deaths along each map  ({len(rows)} events, {len({r.get('session') for r in rows})} sessions)", fill=(230, 220, 200))
    for i, n in enumerate(names):
        y = 40 + i * ROW
        end = ends.get(n, max(deaths[n] + [1.0]))
        hist, _ = np.histogram(deaths[n], bins=120, range=(0, end))
        top = max(1, hist.max())
        for k, v in enumerate(hist):
            x0 = LEFT + k * (W - LEFT - 160) / 120
            heat = v / top
            d.rectangle([x0, y + 6, x0 + (W - LEFT - 160) / 120, y + ROW - 10],
                        fill=(int(60 + 190 * heat), int(50 + 40 * (1 - heat)), int(40 * (1 - heat))))
        d.text((10, y + 14), n[:24], fill=(230, 220, 200))
        d.text((W - 150, y + 2), f"died {len(deaths[n])}", fill=(220, 120, 100))
        d.text((W - 150, y + 15), f"done {done[n]}  quit {quits[n]}", fill=(180, 200, 170))
        d.text((W - 150, y + 28), f"players {len(reached[n])}", fill=(160, 160, 160))
    out = os.path.join(REPO, "_shots", "heatmap.png")
    img.save(out)
    print("funnel (players reaching each map -> finishing it):")
    for n in names:
        print(f"  {n:24s} {len(reached[n]):4d} -> {done[n]:4d}   deaths {len(deaths[n])}  quits {quits[n]}")
    print(out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "_shots", "events.json"))
