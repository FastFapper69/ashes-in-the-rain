"""art/mocap/*.json (gen/mocap/side.py) -> mocap_data.gd: the cycles as a GDScript constant (a .json would not be exported)."""
import json, glob, os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
cyc = {}
for f in sorted(glob.glob(os.path.join(R, "art", "mocap", "*.json"))):
    d = json.load(open(f))
    n = os.path.basename(f)[:-5]
    cyc[n] = {"seconds": d["seconds"], "travel": d["travel"], "arm": d["arm"], "src": d["src"],
              "phases": [[p["hip_y"], p["ankle_f"][0] - p["hipx_f"], p["ankle_f"][1], p["ankle_b"][0] - p["hipx_b"], p["ankle_b"][1],
                          p["torso"], p["head"], p["hand_f"][0], p["hand_f"][1], p["hand_b"][0], p["hand_b"][1]] for p in d["phases"]]}
out = ['extends RefCounted', '## Motion capture cycles seen from the side (gen/mocap: Blender bvh_joints.py -> side.py -> to_gd.py), CMU mocap database.',
       '## A phase: [hip height, near ankle x, y, far ankle x, y (from each leg\'s hip; y from the ground), torso, head (rad from',
       '## vertical, + forward), near wrist x, y, far wrist x, y (from the shoulder)]; lengths in the subject\'s legs (hip to ankle).',
       'const CYCLES := ' + json.dumps(cyc)]
open(os.path.join(R, "mocap_data.gd"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("mocap_data.gd", {k: len(v["phases"]) for k, v in cyc.items()})
