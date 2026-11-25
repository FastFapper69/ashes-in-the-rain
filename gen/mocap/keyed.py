"""Moves no recording has (user 24. 11.: "the dive, the slide, the cover look awful next to the mocap - a sheet with more
in-betweens?"): a sheet of key poses set as JOINT ANGLES, turned into the same frames as a captured clip (side.py clip),
so the puppet plays them the same way. Angles in degrees from vertical, + forward (a thigh at +90 points straight ahead);
knee / elbow = how far it is bent. The hips' height is found, not set: the body is lowered until something touches the
floor (a heel, a knee, the seat, the back, a hand), unless the key says "lift" (in the air). Between the keys a
Catmull-Rom spline, 40 frames per move: the in-betweens.
    py -3 gen/mocap/keyed.py        -> art/mocap/clips/<move>.json (then gen/mocap/to_gd.py)"""
import json, math, os

TH, SH = 0.494, 0.506   # thigh, shin in leg lengths (the puppet's 0.4215 / 0.4318)
UA, FA = 0.391, 0.321   # upper arm, forearm (0.3336 / 0.2738)
TORSO = 0.61            # hips to the base of the neck (0.52 m)
SHOULDER = 0.52         # hips to the shoulder along the torso
# what may touch the floor, as heights over the "ankle level" floor of the clips (the ankle sits 0.105 legs above the stones)
FLOOR = {"ankle": 0.0, "knee": -0.035, "hip": 0.035, "back": 0.05, "hand": -0.07}


def leg(a, k):
    a, k = math.radians(a), math.radians(k)
    knee = (TH * math.sin(a), -TH * math.cos(a))
    s = a - k
    return knee, (knee[0] + SH * math.sin(s), knee[1] - SH * math.cos(s))


def plant(hy, x):
    """a foot set down on the floor at x (from the hips) under hips hy high: the knee found forward (two-bone IK)."""
    d = math.hypot(x, hy)
    d = min(d, TH + SH - 1e-4)
    c = max(-1.0, min(1.0, (TH * TH + d * d - SH * SH) / (2 * TH * d)))
    base = math.atan2(x, -hy)   # hip -> ankle, from straight down
    a = base + math.acos(c)     # the thigh turned forward of that line: the knee in front
    knee = (TH * math.sin(a), -TH * math.cos(a))
    return knee, (x, -hy)


def arm(a, e):
    a, e = math.radians(a), math.radians(e)
    el = (UA * math.sin(a), -UA * math.cos(a))
    s = a + e
    return (el[0] + FA * math.sin(s), el[1] - FA * math.cos(s))


def pose(k):
    """k: fa, fb (thigh, knee) of the near / far leg; torso, head (deg); hf, hb (upper arm, elbow) or None; lift."""
    # a leg is either angles ("fa"/"fb": thigh, knee) or a planted foot ("pf"/"pb": x from the hips, with "hy" the hips)
    kf, af = plant(k["hy"], k["pf"]) if "pf" in k else leg(*k["fa"])
    kb, ab = plant(k["hy"], k["pb"]) if "pb" in k else leg(*k["fb"])
    t = math.radians(k["torso"])
    sh = (SHOULDER * math.sin(t), SHOULDER * math.cos(t))
    neck = (TORSO * math.sin(t), TORSO * math.cos(t))
    hf = arm(*k["hf"]) if k.get("hf") else (0.1, -0.6)
    hb = arm(*k["hb"]) if k.get("hb") else (0.05, -0.62)
    # lowest points against the floor -> the hips' height
    need = [FLOOR["ankle"] - af[1], FLOOR["ankle"] - ab[1], FLOOR["knee"] - kf[1], FLOOR["knee"] - kb[1], FLOOR["hip"]]
    for f in (0.3, 0.6, 1.0):   # the back, along the torso
        need.append(FLOOR["back"] - min(0.0, neck[1] * f))
    for h in (hf, hb):
        need.append(FLOOR["hand"] - (sh[1] + h[1]))
    hip_y = 1.0 if k.get("air") else (k["hy"] if "hy" in k else max(need) + k.get("lift", 0.0))   # in the air the game sets the height: legs from the hips
    # (12th: "hx", how far the hips have moved from where the feet stood, + forward - a fall goes down over the feet)
    return [hip_y, af[0], hip_y + af[1], ab[0], hip_y + ab[1], t, math.radians(k.get("head", k["torso"] * 0.5)), hf[0], hf[1], hb[0], hb[1],
            k.get("hx", 0.0)]


def spline(keys, n=40):
    ts = [k[0] for k in keys]
    ps = [pose(k[1]) for k in keys]
    out = []
    for i in range(n):
        u = i / (n - 1)
        j = max(0, min(len(ts) - 2, max(x for x in range(len(ts)) if ts[x] <= u + 1e-9)))
        v = (u - ts[j]) / (ts[j + 1] - ts[j])
        p0, p1, p2, p3 = ps[max(0, j - 1)], ps[j], ps[j + 1], ps[min(len(ps) - 1, j + 2)]
        out.append([round(0.5 * (2 * b + (-a + c) * v + (2 * a - 5 * b + 4 * c - d) * v * v + (-a + 3 * b - 3 * c + d) * v ** 3), 4)
                    for a, b, c, d in zip(p0, p1, p2, p3)])
    return out


MOVES = {
    # the shootdodge in the air (along the game's air_v -1 leaving .. 1 coming down): laid out head first, the legs long
    # behind and a little apart, knees soft; at the top they scissor; coming down the knees bend and the trailing foot
    # reaches for the stones; the free arm out ahead and a little low for balance. Chin UP (head ~30 deg): lying flat the
    # gun arm reaches forward at the height of his face - a head bowed with the body hid behind the arm and the hat
    "flight": [
        (0.0, {"air": True, "fa": (-25, 35), "fb": (-55, 20), "torso": 62, "head": 25, "hb": (115, 25)}),
        (0.3, {"air": True, "fa": (-62, 22), "fb": (-88, 12), "torso": 78, "head": 28, "hb": (100, 20)}),
        (0.55, {"air": True, "fa": (-78, 15), "fb": (-98, 28), "torso": 84, "head": 30, "hb": (95, 15)}),
        (0.8, {"air": True, "fa": (-85, 30), "fb": (-75, 45), "torso": 86, "head": 32, "hb": (75, 30)}),
        (1.0, {"air": True, "fa": (-88, 40), "fb": (-65, 60), "torso": 88, "head": 35, "hb": (45, 40)}),
    ],
    # feet first along the wet stones (0.55 s): down off the stride onto the far hip, the near leg reaching out ahead, the
    # far one folded under him, leaning back on the free hand; then the folded leg drives him up into a run
    "slide": [
        (0.0, {"fa": (32, 25), "fb": (-22, 70), "torso": 14, "head": 6, "hb": (-30, 80), "lift": 0.0}),
        (0.12, {"fa": (55, 15), "fb": (5, 105), "torso": 2, "head": 0, "hb": (-35, 25)}),
        (0.26, {"fa": (80, 6), "fb": (35, 150), "torso": -38, "head": -8, "hb": (-45, 10)}),
        (0.45, {"fa": (84, 4), "fb": (38, 152), "torso": -44, "head": -10, "hb": (-50, 8)}),
        (0.66, {"fa": (82, 8), "fb": (40, 150), "torso": -40, "head": -8, "hb": (-48, 10)}),
        (0.8, {"fa": (70, 45), "fb": (25, 140), "torso": -10, "head": 0, "hb": (-30, 20)}),
        (0.9, {"fa": (55, 75), "fb": (-10, 110), "torso": 18, "head": 8, "hb": (-40, 60)}),
        (1.0, {"fa": (35, 60), "fb": (-15, 75), "torso": 20, "head": 8, "hb": (-25, 80)}),
    ],
    # a bullet in the body (along main.gd's flinch 1 -> 0, ~0.45 s): the shoulders and the head snap back over hips that
    # go forward, the knees give; the back foot steps back to catch him, and a short step brings it home again
    # (first try 25. 11. read as a walking stride: both feet must stay PLANTED - "pf"/"pb", the knees found by IK)
    "hit": [
        (0.0, {"hy": 0.99, "pf": -0.19, "pb": 0.16, "torso": 2, "head": 0, "hb": (10, 20)}),
        (0.14, {"hy": 0.96, "pf": -0.2, "pb": 0.14, "torso": -20, "head": -26, "hb": (45, 60)}),
        (0.32, {"hy": 0.95, "fa": (-28, 18), "pb": 0.12, "torso": -15, "head": -12, "hb": (35, 50)}),
        (0.5, {"hy": 0.93, "pf": -0.42, "pb": 0.12, "torso": -4, "head": 0, "hb": (20, 35)}),
        (0.72, {"hy": 0.95, "pf": -0.4, "pb": 0.13, "torso": 4, "head": 4, "hb": (12, 25)}),
        (0.87, {"hy": 0.96, "fa": (-16, 30), "pb": 0.15, "torso": 3, "head": 2, "hb": (10, 20)}),
        (1.0, {"hy": 0.99, "pf": -0.19, "pb": 0.16, "torso": 2, "head": 0, "hb": (10, 20)}),
    ],
    # a bullet in the leg: the feet stay where they stood, the hips drop back over the hurt (near) leg so its knee folds
    # forward deepest, the good one straighter; he bows over it, the free hand to the thigh (a lifted foot read as a stride), he folds over toward the wound, the free hand to the thigh;
    # then he straightens, both feet where they were
    "hit_leg": [
        (0.0, {"hy": 0.99, "pf": -0.19, "pb": 0.16, "torso": 2, "head": 0, "hb": (10, 20)}),
        (0.16, {"hy": 0.86, "pf": -0.1, "pb": 0.25, "torso": 16, "head": 10, "hb": (5, 25)}),
        (0.42, {"hy": 0.76, "pf": -0.04, "pb": 0.31, "torso": 24, "head": 14, "hb": (-8, 15)}),
        (0.72, {"hy": 0.9, "pf": -0.13, "pb": 0.22, "torso": 10, "head": 5, "hb": (20, 45)}),
        (1.0, {"hy": 0.99, "pf": -0.19, "pb": 0.16, "torso": 2, "head": 0, "hb": (10, 20)}),
    ],
    # shot dead, falling back (25. 11.: the whole figure turned stiff as a plank, both arms flung over his face): the
    # head snaps back, the knees give, he sits down over his heels and goes onto his back, the arms thrown out low and
    # then flopping out past his head; the feet stay where he stood (hx: the hips go back a whole leg)
    "die_back": [
        (0.0, {"hy": 0.99, "hx": 0.0, "pf": -0.19, "pb": 0.16, "torso": 2, "head": 0, "hf": (80, 10), "hb": (10, 20)}),
        (0.15, {"hy": 0.95, "hx": -0.03, "pf": -0.16, "pb": 0.19, "torso": -20, "head": -38, "hf": (65, 35), "hb": (35, 40)}),
        (0.35, {"hy": 0.75, "hx": -0.12, "pf": -0.07, "pb": 0.28, "torso": -30, "head": -32, "hf": (45, 45), "hb": (30, 50)}),
        (0.55, {"hy": 0.45, "hx": -0.35, "pf": 0.35, "pb": 0.5, "torso": -55, "head": -38, "hf": (70, 30), "hb": (60, 40)}),
        (0.75, {"hx": -0.75, "fa": (110, 80), "fb": (100, 72), "torso": -82, "head": -70, "hf": (120, 20), "hb": (100, 35)}),
        (0.88, {"hx": -0.95, "fa": (95, 40), "fb": (88, 45), "torso": -90, "head": -98, "hf": (110, 20), "hb": (95, 30)}),
        (1.0, {"hx": -1.0, "fa": (88, 5), "fb": (84, 14), "torso": -90, "head": -92, "hf": (84, 10), "hb": (75, 25)}),
    ],
    # shot dead, folding forward (crouched, a leg, or one time in three): the knees go, down onto them a beat, the hands
    # come forward too late, onto his face; the hips go forward a whole leg over the planted feet
    "die_front": [
        (0.0, {"hy": 0.99, "hx": 0.0, "pf": -0.19, "pb": 0.16, "torso": 2, "head": 0, "hf": (80, 10), "hb": (10, 20)}),
        (0.2, {"hy": 0.8, "hx": 0.05, "pf": -0.24, "pb": 0.11, "torso": 22, "head": 30, "hf": (35, 30), "hb": (10, 20)}),
        (0.42, {"hx": 0.27, "fa": (5, 95), "fb": (18, 100), "torso": 28, "head": 32, "hf": (20, 15), "hb": (15, 15)}),
        (0.62, {"hx": 0.55, "fa": (-40, 80), "fb": (-30, 90), "torso": 58, "head": 52, "hf": (60, 15), "hb": (55, 15)}),
        (0.8, {"hx": 0.8, "fa": (-70, 30), "fb": (-62, 45), "torso": 86, "head": 84, "hf": (95, 25), "hb": (85, 20)}),
        (1.0, {"hx": 1.0, "fa": (-88, 5), "fb": (-84, 18), "torso": 92, "head": 88, "hf": (86, 4), "hb": (86, 10)}),
    ],
    # up off the stones after the dive, face down, head toward where he flew (the gun hand stays on the aim): a push-up,
    # the knees drawn under, one foot planted, up
    "getup": [
        (0.0, {"fa": (-95, 5), "fb": (-92, 10), "torso": 92, "head": 70, "hb": (8, 25)}),
        (0.2, {"fa": (-90, 30), "fb": (-85, 45), "torso": 80, "head": 55, "hb": (12, 10)}),
        (0.42, {"fa": (-30, 125), "fb": (-40, 140), "torso": 62, "head": 35, "hb": (15, 5)}),
        (0.62, {"fa": (75, 95), "fb": (-15, 135), "torso": 42, "head": 20, "hb": (20, 30)}),
        (0.82, {"fa": (55, 85), "fb": (-5, 100), "torso": 28, "head": 12, "hb": (10, 40)}),
        (1.0, {"fa": (35, 60), "fb": (-10, 70), "torso": 18, "head": 8, "hb": (-10, 50)}),
    ],
}

if __name__ == "__main__":
    dst = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "mocap", "clips")
    os.makedirs(dst, exist_ok=True)
    for name, keys in MOVES.items():
        ph = spline(keys)
        json.dump({"src": "keyed (gen/mocap/keyed.py)", "frames": [0, len(ph)], "seconds": 0.0, "arm": round(UA + FA, 4), "phases": ph},
                  open(os.path.join(dst, name + ".json"), "w"))
        print(name, len(ph), "hips", [p[0] for p in ph[::8]])
