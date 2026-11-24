"""Motion capture seen from the side, for the cut-out puppet (user 24. 11.: "I want to see the mocap Blender version").
joints JSON (gen/mocap/bvh_joints.py, Blender) -> the figure's side view: forward = the way the body faces on average,
up = up; the NEAR side (the one the camera sees, the puppet's "f") is the left of a man facing screen-right.
    py -3 gen/mocap/side.py look <joints.json> <out.png> [from to step]      a stick figure strip to look at
    py -3 gen/mocap/side.py cycle <joints.json> <name> [from to]             one stride -> art/mocap/<name>.json
A cycle: from one near-foot strike to the next (the foot's lowest, slowest moment), resampled to N phases. Every length is
in units of the subject's own leg (hip to ankle, straight), so the game scales it by the figure's leg; the ground under
the stride is the lowest ankle of the clip."""
import sys, json, math, os
import numpy as np

N = 48


def load(p):
    d = json.load(open(p))
    keys = list(d["frames"][0].keys())
    a = {k: np.array([f[k] for f in d["frames"]], dtype=float) for k in keys}
    return d, a


def frame_axes(a):
    """forward (horizontal unit vector), from the hips' travel if they travel, else from the way the toes point."""
    h = a["hips"][:, :2]
    travel = h[-1] - h[0]
    if np.linalg.norm(travel) > 0.5 * leg_len(a):
        f = travel
    else:
        f = ((a["l_toe"] - a["l_ankle"]) + (a["r_toe"] - a["r_ankle"]))[:, :2].mean(axis=0)
    return f / np.linalg.norm(f)


def leg_len(a):
    return float(np.median(np.linalg.norm(a["l_knee"] - a["l_hip"], axis=1) + np.linalg.norm(a["l_ankle"] - a["l_knee"], axis=1)))


def side(a, fwd):
    """every joint -> (x forward, y up) in leg units, x from the hips' own x each frame, y from the ground."""
    L = leg_len(a)
    ground = min(a["l_ankle"][:, 2].min(), a["r_ankle"][:, 2].min())
    out = {}
    hx = a["hips"][:, :2] @ fwd
    for k, v in a.items():
        out[k] = np.stack([(v[:, :2] @ fwd - hx) / L, (v[:, 2] - ground) / L], axis=1)
    out["_travel"] = hx / L
    # which side is near: for a man facing +fwd seen with up = up and forward = screen right, the camera is on his left
    # when left = fwd x up ... check with the hip joints: the left hip's offset sideways
    lat = np.array([-fwd[1], fwd[0]])   # left of forward
    left_near = float(np.mean((a["l_hip"][:, :2] - a["r_hip"][:, :2]) @ lat)) > 0.0
    return out, L, left_near


def strikes(s, foot):
    """frames where a foot lands: the ankle comes down to near its lowest and stops falling."""
    y = s[foot + "_ankle"][:, 1]
    low = np.percentile(y, 15)
    idx = []
    for i in range(2, len(y) - 2):
        if y[i - 2] > y[i] <= y[i + 1] and y[i] < low + 0.05 and (y[i - 2] - y[i]) > 0.002:
            if not idx or i - idx[-1] > 20:
                idx.append(i)
    return idx


def look(path, png, a0=0, a1=None, step=10):
    from PIL import Image, ImageDraw
    d, a = load(path)
    fwd = frame_axes(a)
    s, L, left_near = side(a, fwd)
    n = len(a["hips"])
    a1 = n if a1 is None else min(a1, n)
    fr = list(range(a0, a1, step))
    W, H = 150, 260
    im = Image.new("RGB", (W * len(fr), H), (235, 230, 220))
    dr = ImageDraw.Draw(im)
    near = "l" if left_near else "r"
    far = "r" if left_near else "l"
    for i, f in enumerate(fr):
        ox = i * W + W // 2
        P = lambda k: (ox + s[k][f][0] * 100, H - 20 - s[k][f][1] * 100)
        dr.line([(i * W, H - 20), (i * W + W, H - 20)], fill=(150, 150, 150))
        for side_, col in ((far, (150, 150, 200)), (near, (20, 20, 20))):
            dr.line([P(side_ + "_hip"), P(side_ + "_knee"), P(side_ + "_ankle"), P(side_ + "_ball"), P(side_ + "_toe")], fill=col, width=3)
            dr.line([P(side_ + "_shoulder"), P(side_ + "_elbow"), P(side_ + "_wrist"), P(side_ + "_hand")], fill=col, width=3)
        dr.line([P("hips"), P("chest"), P("neck"), P("head"), P("head_top")], fill=(120, 30, 30), width=3)
        dr.text((i * W + 3, 3), str(f), fill=(0, 0, 0))
    im.save(png)
    print("near side:", near, "frames", n, "leg", round(L, 3), "strikes l", strikes(s, "l"), "r", strikes(s, "r"))


def cycle(path, name, a0=None, a1=None):
    d, a = load(path)
    fwd = frame_axes(a)
    s, L, left_near = side(a, fwd)
    near, far = ("l", "r") if left_near else ("r", "l")
    st = strikes(s, near)
    if a0 is None:
        if len(st) >= 2:
            a0, a1 = st[0], st[1]
        else:   # one near strike only: a far foot's stride, turned so phase 0 is still the near foot landing
            sf = strikes(s, far)
            a0, a1 = sf[0], sf[1]
    ft = d["frame_time"]
    out = {"src": d["src"], "frames": [a0, a1], "seconds": round((a1 - a0) * ft, 4),
           "travel": round(float(s["_travel"][a1] - s["_travel"][a0]), 4), "phases": []}
    for i in range(N):
        t = a0 + (a1 - a0) * i / N
        j = int(math.floor(t)); u = t - j
        g = lambda k: s[k][j] * (1 - u) + s[k][min(j + 1, len(s[k]) - 1)] * u
        ang = lambda p, q: math.atan2(g(q)[0] - g(p)[0], g(q)[1] - g(p)[1])   # from vertical, + = leaning forward
        sh_n, sh_f = g(near + "_shoulder"), g(far + "_shoulder")
        ph = {
            "hip_y": round(float((g(near + "_hip")[1] + g(far + "_hip")[1]) / 2), 4),
            "ankle_f": [round(float(x), 4) for x in g(near + "_ankle") - [0, 0]],
            "ankle_b": [round(float(x), 4) for x in g(far + "_ankle")],
            "hipx_f": round(float(g(near + "_hip")[0]), 4), "hipx_b": round(float(g(far + "_hip")[0]), 4),
            "torso": round(ang("hips", "neck"), 4),
            "head": round(ang("neck", "head_top"), 4),
            "hand_f": [round(float(x), 4) for x in g(near + "_wrist") - sh_n],
            "hand_b": [round(float(x), 4) for x in g(far + "_wrist") - sh_f],
        }
        out["phases"].append(ph)
    # the ground under the stride: the lowest ankle WITHIN it (the clip's lowest was its standing start: he floated)
    g0 = min(min(q["ankle_f"][1], q["ankle_b"][1]) for q in out["phases"])
    for q in out["phases"]:
        q["hip_y"] = round(q["hip_y"] - g0, 4)
        q["ankle_f"][1] = round(q["ankle_f"][1] - g0, 4)
        q["ankle_b"][1] = round(q["ankle_b"][1] - g0, 4)
    inside = [k for k in st if a0 <= k < a1]
    if inside and inside[0] != a0:   # phase 0 = the near foot landing
        r = int(round((inside[0] - a0) / (a1 - a0) * N)) % N
        out["phases"] = out["phases"][r:] + out["phases"][:r]
    arm = float(np.median(np.linalg.norm(a[near + "_elbow"] - a[near + "_shoulder"], axis=1) + np.linalg.norm(a[near + "_wrist"] - a[near + "_elbow"], axis=1)))
    out["arm"] = round(arm / L, 4)   # the subject's arm in leg units: the game scales hands by its own arm instead
    dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "mocap")
    os.makedirs(dst, exist_ok=True)
    json.dump(out, open(os.path.join(dst, name + ".json"), "w"), indent=0)
    print("cycle", name, "frames", a0, a1, "seconds", out["seconds"], "travel", out["travel"], "near", near)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "look":
        r = [int(x) for x in sys.argv[4:7]] if len(sys.argv) > 4 else []
        look(sys.argv[2], sys.argv[3], *r)
    elif cmd == "cycle":
        r = [int(x) for x in sys.argv[4:6]] if len(sys.argv) > 4 else []
        cycle(sys.argv[2], sys.argv[3], *r)


def clip(path, name, a0, a1, n=40):
    """a one-off move (a leap, a roll): frames a0..a1 resampled to n. Heights from the floor of the clip (its standing ankle
    level, as the cycles); angles unwrapped so a roll turns all the way round."""
    d, a = load(path)
    fwd = frame_axes(a)
    s, L, left_near = side(a, fwd)
    near, far = ("l", "r") if left_near else ("r", "l")
    floor = float(np.percentile(np.minimum(s["l_ankle"][:, 1], s["r_ankle"][:, 1]), 5))
    def ang(p, q):
        v = s[q] - s[p]
        return np.unwrap(np.arctan2(v[:, 0], v[:, 1]))
    torso, head = ang("hips", "neck"), ang("neck", "head_top")
    out = {"src": d["src"], "frames": [a0, a1], "seconds": round((a1 - a0) * d["frame_time"], 4), "phases": []}
    for i in range(n):
        t = a0 + (a1 - a0) * i / (n - 1)
        j = min(int(t), len(torso) - 2); u = t - j
        g = lambda arr: arr[j] * (1 - u) + arr[j + 1] * u
        hy = float((g(s[near + "_hip"])[1] + g(s[far + "_hip"])[1]) / 2 - floor)
        out["phases"].append([round(x, 4) for x in [
            hy, float(g(s[near + "_ankle"])[0] - g(s[near + "_hip"])[0]), float(g(s[near + "_ankle"])[1] - floor),
            float(g(s[far + "_ankle"])[0] - g(s[far + "_hip"])[0]), float(g(s[far + "_ankle"])[1] - floor),
            float(g(torso)), float(g(head)),
            float((g(s[near + "_wrist"]) - g(s[near + "_shoulder"]))[0]), float((g(s[near + "_wrist"]) - g(s[near + "_shoulder"]))[1]),
            float((g(s[far + "_wrist"]) - g(s[far + "_shoulder"]))[0]), float((g(s[far + "_wrist"]) - g(s[far + "_shoulder"]))[1])]])
    arm = float(np.median(np.linalg.norm(a[near + "_elbow"] - a[near + "_shoulder"], axis=1) + np.linalg.norm(a[near + "_wrist"] - a[near + "_elbow"], axis=1)))
    out["arm"] = round(arm / L, 4)
    dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "mocap", "clips")
    os.makedirs(dst, exist_ok=True)
    json.dump(out, open(os.path.join(dst, name + ".json"), "w"))
    print("clip", name, a0, a1, "floor", round(floor, 3), "torso", round(float(torso[a0]), 2), "->", round(float(torso[a1]), 2))


if __name__ == "__main__" and sys.argv[1] == "clip":
    clip(sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5]))
