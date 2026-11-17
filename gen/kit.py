"""The street kit: ONE catalogue of the street drawings and the things to play with on them (user 16. 11.: "a smart
modular system for building levels and adding interactive things"). gen/levels.py builds maps from it and writes
kit.gd from it, which main.gd and props.gd read – the generator and the game can never disagree.

Adding a street piece:
  1. Gemini: the drawing without its thing(s), and the thing(s) on flat green (see knowledge ch03 "Gemini prompt lessons").
  2. gen/process_art.py STREET entry (the clean drawing), gen/street_props.py cuts the things off the green sheet.
  3. One entry here: drawing size, edges, and its props (kind, box in the drawing's pixels, anchor).
  4. py -3 gen/levels.py levels.gd  ->  kit.gd too; then the audit (gen/tests/audit_maps.py) and the bot.

Adding a KIND of thing: its behaviour in props.gd (one function per kind) + a line in KINDS below.

Pixels are the processed street drawing's (3168x1344 unless said). `edge` names what both sides end in: drawings
with the same edge join seamlessly in any order (the audit checks the rest by eye).
"""

# What each kind of thing is (behaviour lives in props.gd under the same name):
#   shot   – Frank's bullet sets it off (hazard: a man is placed by it)
#   floor  – stood on; "bounce" throws a falling man back up
#   depth  – how far in front of the wall it stands (parallax share of the camera's offset)
KINDS = {
    # (depth: things fixed to the wall do not slide against it – the user found it odd; free-standing ones barely)
    "awning":    {"shot": False, "floor": "awning", "depth": 0.0},
    "hydrant":   {"shot": True,  "floor": None,     "depth": 0.012},
    "kegs":      {"shot": True,  "floor": None,     "depth": 0.012},
    "steampipe": {"shot": True,  "floor": None,     "depth": 0.0},
    "windlass":  {"shot": True,  "floor": None,     "depth": 0.01},   # free-standing (levels "things"), docks
    "trolley":   {"shot": True,  "floor": None,     "depth": 0.0},    # free-standing: a trolley pole over a puddle (ch III)
    "thirdrail": {"shot": True,  "floor": None,     "depth": 0.0},    # free-standing: the subway's third rail and its junction box (ch III)
}

# The chapter I modular street (art_src 228-236): the same dark party wall down both edges.
PIECES = {
    "hk_tailor": {
        "size": 0.8, "edge": "partywall",
        "props": [{"kind": "awning", "box": (975, 752, 1732, 958), "anchor": "top", "walk_y": 914}],
        # the fire escape beside it, all painted: its landings, the stairs between them, the drop ladder (its foot
        # hangs ~590 px over the pavement: reached with a jump). Up it, then off a landing onto the awning: it
        # throws him up for a slowed beat in the air.
        "floors": [(1909, 2321, 693, "drawn"), (1909, 2321, 389, "drawn")],
        "ramps": [(2013, 693, 2239, 390)],
        "ladders": [(2020, 693, 902)],   # x, the landing it reaches, its foot
        # a washing line from the top landing to the pulley on the next house's window (the stunt list: a washing line
        # as a rope): he rides it down like a zip line, tearing the laundry off. (x, y) of its start on the landing's
        # floor, (x, y) of the pulley.
        "lines": [(2316, 318, 2822, 532, 389)],   # rail post top, the window's left jamb, the landing it is ridden from
        # men up on the fire escape: they only fire at a Frank on their own landing (the floor rule), so the way to
        # them is the ladder or a bounce off the awning; the awning is how you get the drop on them
        "men": [(2230, 389, "post"), (1960, 693, "shotgun")],
        "clear": [(975, 1732), (1890, 2330)],
    },
    "hk_grocery": {
        "size": 0.8, "edge": "partywall",
        "props": [{"kind": "hydrant", "box": (1805, 1112, 1922, 1302), "anchor": "foot"}],
        "clear": [(1760, 1970)],
    },
    "hk_saloon": {
        "size": 0.8, "edge": "partywall",
        "props": [{"kind": "kegs", "box": (1082, 985, 1328, 1262), "anchor": "foot"}],
        "clear": [(1060, 1700)],
    },
    "hk_laundry": {
        "size": 0.8, "edge": "partywall",
        "props": [{"kind": "steampipe", "box": (1588, 1000, 2158, 1292), "anchor": "foot"}],
        "clear": [(1560, 2190)],
    },
    # interiors' building fronts (QUEUE §10.3, 17. 11., Blender template + Gemini): an interior of `front` style stands
    # behind it, its street door at the room's left end and its side door at its right end (gen/levels.py places the
    # front so); nothing stands in front of either door
    "front_laundry": {"size": 0.8, "edge": "partywall", "front": "laundry", "doors": [696, 2472], "props": [],
                      "clear": [(600, 790), (2380, 2570)]},
    "front_warehouse": {"size": 0.8, "edge": "partywall", "front": "warehouse", "doors": [795, 2373], "props": [],
                        "clear": [(670, 920), (2250, 2500)]},
    # (Gemini moves a door a little to line it up with the windows: the doors here are where it painted them; the
    # front is placed on the middle between them, so each door is within ~60 world px of the room's end)
    "front_club": {"size": 0.8, "edge": "partywall", "front": "club", "doors": [806, 2440], "props": [],
                   "clear": [(690, 920), (2330, 2550)]},
    "front_tenement": {"size": 0.8, "edge": "partywall", "front": "tenement", "doors": [870, 2305], "props": [],
                       "clear": [(740, 1000), (2175, 2435)]},
}
# Edge types (QUEUE_doma §10.2, research ch15 "edge contracts"): what each street drawing's VISIBLE left and right edge
# ends in (after main.gd trims its frame). Two drawings may stand side by side only where the right edge of the first
# and the left edge of the second are the same type; a firewall pier (art/street/pier.png) is stood over a join only
# between two party walls - never in front of open sky or water. Classified 17. 11. from the edges themselves (sky at
# the edge, the family: underground girders, the dream's timbers, the yard's fences) and checked on _shots/s9/edges.png.
#   party_wall  a building's side, shared with the next building (the pier covers the join)
#   girder      the subway's riveted iron columns          timber   the burning warehouse's posts (the dream)
#   fence       the train yard's fence and poles           water    the open harbour beyond a quay's end
#   open_lot    open ground and sky between buildings
EDGES = {
    "alley": ("party_wall", "party_wall"), "alley_b": ("open_lot", "open_lot"), "bluenote": ("party_wall", "party_wall"),
    "church": ("party_wall", "party_wall"), "church_b": ("party_wall", "party_wall"), "cranes": ("water", "party_wall"),
    "deadend": ("party_wall", "party_wall"), "harbor": ("water", "water"),
    "hk_grocery": ("party_wall", "party_wall"), "hk_laundry": ("party_wall", "party_wall"), "hk_saloon": ("party_wall", "party_wall"),
    "hk_tailor": ("party_wall", "party_wall"), "laundry": ("party_wall", "party_wall"), "laundry_b": ("party_wall", "party_wall"),
    "market": ("party_wall", "party_wall"), "market_b": ("party_wall", "party_wall"), "market_c": ("party_wall", "party_wall"),
    "pier17": ("water", "party_wall"), "pier17_b": ("water", "party_wall"), "quay": ("water", "party_wall"), "quay_b": ("water", "water"),
    "sheds": ("party_wall", "party_wall"), "sheds_b": ("water", "water"), "shipping": ("party_wall", "water"),
    "shipping_b": ("party_wall", "party_wall"), "subway": ("party_wall", "party_wall"), "subway_b": ("party_wall", "party_wall"),
    "tenrow_a": ("party_wall", "party_wall"), "tenrow_b": ("party_wall", "party_wall"), "tenrow_c": ("party_wall", "party_wall"),
    "tenrow_d": ("party_wall", "party_wall"), "warehouse": ("party_wall", "party_wall"), "warehouse_b": ("open_lot", "party_wall"),
    "warehouse_c": ("party_wall", "party_wall"), "yard": ("fence", "fence"), "yard_b": ("fence", "fence"), "yard_c": ("fence", "fence"),
}
EDGES["front_laundry"] = EDGES["front_warehouse"] = EDGES["front_club"] = EDGES["front_tenement"] = ("party_wall", "party_wall")
for _n in ("arches", "arches_b", "bowery", "platform", "pump", "signal", "signal_b", "station14", "tunnel", "tunnel_b", "tunnel_c",
           "tunnel_lo", "tunnel_lo_b", "walkway", "walkway_b"):
    EDGES[_n] = ("girder", "girder")
for _n in ("fire_a", "fire_b", "fire_c", "fire_d", "fire_e", "fire_f", "fire_g"):
    EDGES[_n] = ("timber", "timber")


def joins(a, b):
    """May drawing b stand right of drawing a? (unknown drawings: yes, the audit lists them)"""
    if a not in EDGES or b not in EDGES:
        return True
    return EDGES[a][1] == EDGES[b][0]


# >>> METRICS (gen/tests/metrics_audit.py --write: measured, do not edit by hand)
METRICS = {
    "alley": {"top": 194, "foot": 1126, "curb": 1237, "foot_y": -270, "doors": [], "eye": None},
    "alley_b": {"top": 383, "foot": 1271, "curb": 1290, "foot_y": 6, "doors": [], "eye": None},
    "arches": {"top": 0, "foot": 1004, "curb": 1021, "foot_y": -290, "doors": [], "eye": None},
    "arches_b": {"top": 0, "foot": 1006, "curb": 1022, "foot_y": -288, "doors": [], "eye": None},
    "bluenote": {"top": 245, "foot": 1226, "curb": 1274, "foot_y": -80, "doors": [], "eye": None},
    "bowery": {"top": 0, "foot": 1053, "curb": 1076, "foot_y": -241, "doors": [], "eye": None},
    "church": {"top": 256, "foot": 1204, "curb": 1233, "foot_y": -122, "doors": [], "eye": None},
    "church_b": {"top": 184, "foot": 1209, "curb": 1228, "foot_y": -112, "doors": [], "eye": None},
    "cranes": {"top": 671, "foot": 1204, "curb": 1266, "foot_y": -122, "doors": [], "eye": None},
    "deadend": {"top": 217, "foot": 1019, "curb": 1266, "foot_y": -391, "doors": [], "eye": None},
    "fire_a": {"top": 0, "foot": 1159, "curb": 1182, "foot_y": -66, "doors": [], "eye": None},
    "fire_b": {"top": 0, "foot": 1315, "curb": 1353, "foot_y": 113, "doors": [], "eye": None},
    "fire_c": {"top": 0, "foot": 1159, "curb": 1175, "foot_y": -66, "doors": [], "eye": None},
    "fire_d": {"top": 0, "foot": 1146, "curb": 1168, "foot_y": -81, "doors": [], "eye": None},
    "fire_e": {"top": 0, "foot": 1345, "curb": 1412, "foot_y": 148, "doors": [], "eye": None},
    "fire_f": {"top": 0, "foot": 1145, "curb": 1176, "foot_y": -82, "doors": [], "eye": None},
    "fire_g": {"top": 0, "foot": 1251, "curb": 1277, "foot_y": 40, "doors": [], "eye": None},
    "harbor": {"top": 659, "foot": 1203, "curb": 1243, "foot_y": -124, "doors": [], "eye": None},
    "hk_grocery": {"top": 52, "foot": 1247, "curb": 1305, "foot_y": -44, "doors": [], "eye": None},
    "hk_laundry": {"top": 116, "foot": 1153, "curb": 1249, "foot_y": -187, "doors": [], "eye": None},
    "hk_saloon": {"top": 275, "foot": 1310, "curb": None, "foot_y": 52, "doors": [], "eye": None},
    "hk_tailor": {"top": 54, "foot": 1156, "curb": 1262, "foot_y": -182, "doors": [(790, 150, 360), (2500, 150, 360)], "eye": None},
    "laundry": {"top": 189, "foot": 1167, "curb": 1210, "foot_y": -192, "doors": [], "eye": None},
    "laundry_b": {"top": 384, "foot": 1211, "curb": 1274, "foot_y": -108, "doors": [], "eye": None},
    "market": {"top": 284, "foot": 1155, "curb": 1266, "foot_y": -215, "doors": [], "eye": None},
    "market_b": {"top": 410, "foot": 1205, "curb": 1266, "foot_y": -120, "doors": [], "eye": None},
    "market_c": {"top": 255, "foot": 961, "curb": 987, "foot_y": -583, "doors": [], "eye": None},
    "pier17": {"top": 267, "foot": 1208, "curb": 1246, "foot_y": -114, "doors": [], "eye": None},
    "pier17_b": {"top": 508, "foot": 1115, "curb": 1151, "foot_y": -291, "doors": [], "eye": None},
    "platform": {"top": 0, "foot": 1035, "curb": 1069, "foot_y": -443, "doors": [], "eye": None},
    "pump": {"top": 0, "foot": 1184, "curb": 1249, "foot_y": -160, "doors": [], "eye": None},
    "quay": {"top": 434, "foot": 1126, "curb": 1164, "foot_y": -270, "doors": [], "eye": None},
    "quay_b": {"top": 676, "foot": 1126, "curb": 1164, "foot_y": -270, "doors": [], "eye": None},
    "sheds": {"top": 200, "foot": 1016, "curb": 1047, "foot_y": -290, "doors": [], "eye": None},
    "sheds_b": {"top": 324, "foot": 1019, "curb": 1047, "foot_y": -287, "doors": [], "eye": None},
    "shipping": {"top": 190, "foot": 1117, "curb": 1144, "foot_y": -287, "doors": [], "eye": None},
    "shipping_b": {"top": 361, "foot": 1206, "curb": 1257, "foot_y": -118, "doors": [], "eye": None},
    "signal": {"top": 0, "foot": 1004, "curb": 1021, "foot_y": -290, "doors": [], "eye": None},
    "signal_b": {"top": 0, "foot": 1004, "curb": 1021, "foot_y": -290, "doors": [], "eye": None},
    "station14": {"top": 0, "foot": 1053, "curb": 1076, "foot_y": -241, "doors": [], "eye": None},
    "subway": {"top": 229, "foot": 1204, "curb": 1271, "foot_y": -122, "doors": [], "eye": None},
    "subway_b": {"top": 145, "foot": 1204, "curb": 1245, "foot_y": -122, "doors": [], "eye": None},
    "tenrow_a": {"top": 49, "foot": 1146, "curb": 1267, "foot_y": -176, "doors": [], "eye": None},
    "tenrow_b": {"top": 51, "foot": 1141, "curb": 1252, "foot_y": -182, "doors": [], "eye": None},
    "tenrow_c": {"top": 50, "foot": 1154, "curb": 1259, "foot_y": -166, "doors": [], "eye": None},
    "tenrow_d": {"top": 50, "foot": 1059, "curb": 1258, "foot_y": -288, "doors": [], "eye": None},
    "tunnel": {"top": 0, "foot": 1012, "curb": 1034, "foot_y": -487, "doors": [], "eye": None},
    "tunnel_b": {"top": 0, "foot": 1083, "curb": 1105, "foot_y": -352, "doors": [], "eye": None},
    "tunnel_c": {"top": 0, "foot": 959, "curb": 1012, "foot_y": -587, "doors": [], "eye": None},
    "tunnel_lo": {"top": 0, "foot": 1012, "curb": 1034, "foot_y": -282, "doors": [], "eye": None},
    "tunnel_lo_b": {"top": 0, "foot": 1083, "curb": 1105, "foot_y": -212, "doors": [], "eye": None},
    "walkway": {"top": 0, "foot": 980, "curb": 1004, "foot_y": -313, "doors": [], "eye": None},
    "walkway_b": {"top": 0, "foot": 958, "curb": 975, "foot_y": -335, "doors": [], "eye": None},
    "warehouse": {"top": 222, "foot": 1115, "curb": 1225, "foot_y": -291, "doors": [], "eye": None},
    "warehouse_b": {"top": 638, "foot": 967, "curb": 1207, "foot_y": -572, "doors": [], "eye": None},
    "warehouse_c": {"top": 0, "foot": 1115, "curb": 1225, "foot_y": -291, "doors": [], "eye": None},
    "yard": {"top": 317, "foot": 965, "curb": 1148, "foot_y": -576, "doors": [], "eye": None},
    "yard_b": {"top": 307, "foot": 970, "curb": 1025, "foot_y": -566, "doors": [], "eye": None},
    "yard_c": {"top": 312, "foot": 1082, "curb": 1149, "foot_y": -354, "doors": [], "eye": None},
}
# <<< METRICS
WIDTH = 3168
TOP = lambda size: -1344 * 1.9 * size * 0.92 - 60.0   # main.gd: a drawing's top in the world (WALL_SCALE, SEGMENT_BASE, WALL_LIFT)


def gd():
    """kit.gd: the same catalogue for the game."""
    def v(x):
        if isinstance(x, bool): return "true" if x else "false"
        if x is None: return "null"
        if isinstance(x, str): return f'"{x}"'
        if isinstance(x, (int, float)): return f"{float(x)}"
        if isinstance(x, (list, tuple)): return "[" + ", ".join(v(i) for i in x) + "]"
        if isinstance(x, dict): return "{" + ", ".join(f'"{k}": {v(i)}' for k, i in x.items()) + "}"
        raise TypeError(x)
    return ("# Generated by gen/levels.py from gen/kit.py: do not edit by hand.\nextends RefCounted\n\n"
            f"const KINDS := {v(KINDS)}\nconst PIECES := {v(PIECES)}\nconst EDGES := {v(EDGES)}\n")
