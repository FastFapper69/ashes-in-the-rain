extends Node2D
# The test level: the detective fights his way down a night street past six mobsters.
# A / D walk, the mouse aims. No game rules yet.
# For the first seconds of every run the detective walks and aims by himself and the game saves
# two pictures into _shots/, so the result can be checked without anyone taking a screenshot.

const PuppetScript = preload("res://puppet.gd")
const AtmosphereScript = preload("res://atmosphere.gd")
const FxScript = preload("res://fx.gd")
const SfxScript = preload("res://sfx.gd")
const HudScript = preload("res://hud.gd")
const PPM := 200.0
const WALL_SCALE := 1.9         # sized so a doorway on the wall drawing is a little taller than a man
const WALL_LIFT := 60.0         # the wall stands at the back of the pavement
const FIG := 1.18   # figures are drawn 18 % bigger than at first (Gemini audit, the user agreed); cover props and the jump grew with them
const SHOULDER := Vector2(0.0, -1.45 * 200.0 * FIG)

# Night: everything a light does not reach sinks to this colour.
const AMBIENT := Color(0.2, 0.21, 0.27)
const LAMP_COLOR := Color(0.95, 0.74, 0.5)
const WINDOW_COLOR := Color(1.0, 0.78, 0.5)
# Lamps on the wall drawing, in its own pixels: over the two front doors and under the shop awnings.
const LAMPS_PX := [Vector2(335.0, 1040.0), Vector2(1933.0, 1040.0), Vector2(1300.0, 1012.0), Vector2(2850.0, 1012.0)]
# Lit windows, in wall pixels (same rectangles as art/bg/wall_lit.png).
const WINDOWS_PX := [Rect2(70, 1066, 128, 124), Rect2(774, 812, 74, 126), Rect2(1460, 572, 70, 122), Rect2(2335, 332, 68, 118), Rect2(2500, 810, 58, 128)]
const WINDOW_LIGHTS := [0, 4]   # only the low windows throw light down to the street; the light limit per item is 16
# Neon signs on the wall, in wall pixels (centre) and their colour.
const NEONS := [["res://art/props/neon_jazz.png", Vector2(515.0, 880.0), Color(1.0, 0.25, 0.22)], ["res://art/props/neon_hotel.png", Vector2(2600.0, 880.0), Color(1.0, 0.68, 0.25)]]
const LAMP_BULB := Vector2(452.0, 470.0)   # bottom of the bulb on art/props/lamp_wall.png
const SLAB_SCALE := 0.42
const SLAB_REGION_X := Vector2(250.0, 975.0)   # the part of slab_sidewalk.png that tiles without gaps
const MASK_LIT := 1      # things lights fall on
const MASK_UNLIT := 2    # foreground silhouettes: they stay black
const ZOOM := 0.45
# The test level. Solid things he has to jump over and can hide behind: [drawing, left edge, width, height].
# Cover is as tall as a crouching man (about 250 px = 1.25 m), so it hides him and he can still jump it.
# The fire-escape catwalk: he can jump up onto it from the long crate and drop off its ends.
# Where the mobsters stand: x, and the height of what they stand on.
# A mobster with cover close in front of him crouches behind it and pops up to shoot.
const DUCK_DROP := 116.0 * FIG   # how much lower the chest is when crouched, px
const Levels = preload("res://levels.gd")   # the chapters, made by gen/levels.py
const RUNNER_SPEED := 560.0
const MenuScript = preload("res://menu.gd")
const Instincts = preload("res://instincts.gd")
const CutsceneScript = preload("res://cutscene.gd")
const DiaryScript = preload("res://diary.gd")
const SetpiecesScript = preload("res://setpieces.gd")
const MapFxScript = preload("res://mapfx.gd")
const Barks = preload("res://barks.gd")
const LoadingScript = preload("res://loading.gd")
const PauseScript = preload("res://pause.gd")
const SettingsScript = preload("res://settings.gd")
var _shake_on := true
var _assist := true
const FLAME_FRAMES := 8
var _flames: Array = []
var _flame_mat: CanvasItemMaterial
static var ARGS: PackedStringArray = OS.get_cmdline_user_args()   # (audit 22. 11.) read once: it was asked 50 times, some every frame per man
static var _erased := false   # test: the erase went through, this is the title after it
var _cones: bool = "--cones" in ARGS   # test comparisons: inked light cones
static var _retry := false     # the scene reloads for a retry after death: everything fast
static var _card_up := false   # a title card is covering the screen across the reload: lift it once built
var sets   # setpieces.gd: cars, blackouts, searchlights, fires, the crane's crate
var mapfx   # mapfx.gd: the El, the laundry's sheets, the fog on Pier 17
var _in_cut := false
var _fight_t := 0.0   # seconds the fight music holds on after the last enemy in reach
var _was_fight := false
## What a man let go says on his way out: one statement a map, the other half of Eddie's notebook.
## Frank only gets it by letting someone live (menu.gd: testimony, counted as evidence for the end).
const TESTIMONY := {
	"1:0": "\"The reporter? Mickey said scare him. Somebody else said more than that.\"",
	"1:1": "\"We wasn't the first ones in that alley. A cop's car was parked at the end. Lights off.\"",
	"1:2": "\"The laundry don't wash shirts. It washes money for the Saint. Mickey just signs.\"",
	"1:3": "\"Mickey's scared, Frank. Scared of a man downtown with a cough.\"",
	"1:4": "\"The girl? Leave her be. She's the only one Eddie told everything.\"",
	"2:0": "\"Kessler wears a key round his neck on a chain. Eight years he never took it off. Not even to wash.\"",
	"2:1": "\"Sully ain't a drunk. Sully saw the chains. Then he started drinking.\"",
	"2:2": "\"Eleven crates went on the Santa Lucia that night. They didn't weigh like machine parts.\"",
	"2:3": "\"The hold's got a second manifest. The real one. Kessler's too scared to burn it.\"",
	"2:4": "\"Kessler takes his orders from a captain. Not a ship's captain.\"",
	"3:0": "\"Briggs ain't on the take. That's what scares the others.\"",
	"3:1": "\"They told us you shot the reporter. Briggs didn't buy it. Rourke made him.\"",
	"3:2": "\"Rourke's got a file on you in his desk. Only half of it. He keeps the other half on him.\"",
	"3:3": "\"The trains run late tonight because somebody paid them to. Somebody wants you in the tunnels.\"",
	"3:4": "\"The Saint's throwing a ball Christmas Eve. Rourke's the guest of honour.\"",
}
## The witness of a map (QUEUE §18, rule 30, 2026-11-21): the map is a chase after the one man who knows where Frank
## goes next. He carries no gun and runs on ahead as Frank comes; at the end of the street he is cornered and gives
## up. Let go, he talks (the lead, and it counts as mercy); shot, Frank finds the lead on him - the story goes on
## either way, but only mercy hears it from his mouth. [name, where he waits (share of the map), what he says
## running, what he tells, what Frank finds on him dead]
const WITNESS := {
	"1:1": ["SAMMY BLUE", 0.8, ["NOT ME, MALONE!", "I DON'T KNOW NOTHING!", "LEAVE ME OUTTA THIS!"],
		["He talked with his hands still up.", "\"Tenth Avenue. A laundry. Mickey's laundry. They count the money there at night.\""],
		["Sammy Blue didn't talk. His pockets did.", "A claim ticket from a laundry on Tenth Avenue."]],
	"2:1": ["SULLY", 0.5, ["I DIDN'T SEE NOTHING!", "I JUST RUN THE CRANE!", "NOT AGAIN, NOT AGAIN!"],
		["Sully stopped shaking long enough to say it.", "\"The Santa Lucia. Kessler keeps the books aboard. He never lets 'em off the ship.\""],
		["Sully had a pay slip in his coat. Vail Shipping.", "Signed for by the master of the Santa Lucia."]],
}
const CUTS := {"0:0": "eddie", "1:2": "interlude", "1:4": "teague", "2:4": "kessler", "3:4": "briggs"}   # the cutscene after a map ("chapter:map")
const CUTS_BEFORE := {"0:0": "opening", "1:5": "dream", "2:0": "docks", "2:1": "cranes", "2:2": "lucia", "2:3": "hold", "2:4": "harbor", "2:5": "memory", "3:0": "underground"}   # and before one, the first time it is played
const BOSS_HP := 16
const BOSS_NAMES := {"teague": "MICKEY 'CANVAS' TEAGUE", "kessler": "BRUNO KESSLER", "briggs": "LT. HARLAN BRIGGS"}
const BOSS_FACES := {"teague": "boxer", "kessler": "cap", "briggs": "briggs"}
# chapter III: Frank's own department hunting him. Police heads (art/police/heads), and the dark blue of the uniform.
const COP_HEADS := {"patrol": 131.5, "rain": 143.5, "sergeant": 126.5, "briggs": 123.5}
const COP_FACES := {"post": ["patrol", "rain", "sergeant"], "tommy": ["sergeant", "patrol"], "shotgun": ["rain", "patrol"], "boss": ["briggs"],
		"shield": ["rain", "patrol"], "sniper": ["sergeant"]}
const COP_TINT := Color(0.74, 0.8, 1.0)
const ChoiceScript = preload("res://choice.gd")
const LowRes = preload("res://lowres.gd")
const Packs = preload("res://packs.gd")
static var _booted := false
# which chapter and map are being played, and whether the case file (menu) is open; static, so they
# survive the scene reload that starts each map
static var chapter := 0
static var map := 0
static var in_menu := true
var boss: Dictionary = {}
var level: Dictionary
var level_end := 0.0
var cam_start := 0.0
var catwalks: Array[Rect2] = []   # floors above the street: catwalks, fire-escape landings, landings indoors
var catwalk_style: Array[String] = []   # what each is (gen/levels.py floors): an awning throws a falling man back up
var _last_floor_style := ""
var catwalk_solid: Array[bool] = []   # a roof: no dropping through it to the street six storeys down
var _box_sets := {}   # with rooftops: the crates of the street and those of the roof, swapped in as he climbs
var _box_up := false
var roof := {}   # the map's rooftops, when it climbs to them: x0, x1, y (walked line), goal, pics, checks
var ramps: Array = []          # flights of stairs: [x0, y0, x1, y1]
var rooms: Array = []          # interiors: [x0, x1, style]
var box_info: Array = []       # one per box, same order: {kind, sprite, hp, wood}
var lamp_info: Array = []      # one per lamp, same order as lamps: {nodes, light, on}
var pickups: Array = []        # {kind, node}
var weapon := "revolver"
var ammo := 0

var stats := {"kills": 0, "heads": 0, "slow": 0, "hits": 0, "time": 0.0, "executed": 0, "spared": 0, "score": 0, "air": 0, "best_combo": 0, "let_go": [], "shot_up": []}
var _combo := 0          # kills in a row, each within COMBO_GAP of the last
var _combo_t := 0.0      # time left to keep the streak going
var _bounce_t := 0.0
var _q_held := false
var _speed_t := 0.0
var _hit_at := Vector2.INF
var _ground_y := 0.0   # where Frank last stood: his floor   # the last bullet's point of impact     # a ricochet is still in flight: a kill now is a trick shot
const COMBO_GAP := 2.5
var _streak_told := false
const COMBO_MAX := 5
const STAR_2 := 2.5   # score against par (100 a man) for the second star
const STAR_3 := 4.5   # and the third
var _last_kind := "ground"     # what _floor_at last stood him on: ground, box or floor
var _drop_t := 0.0             # seconds he falls through the landing he stood on (stick pulled down)
var _drop_y := 0.0
var _drop_tap := 0.0           # a first pull down on a landing: a second within this time drops through
var _hurt_t := 0.0             # a moment of grace after a hit: a shotgun blast counts once
var _room := ""
var _hint_i := 0
var _check_i := 0
var _stand := false
var _stand_opened := false
var _gate_said := -99.0
var _line_said := -99.0
var _stand_prev := 0.0
var _move_dir := 0.0   # the stick or keys this frame
# The chained iron gate at the right of the prologue's dead end (art/street/deadend.png, its left post at
# 2620 px of the drawing, the segment at x 8658.4, trim 58, scale 1.9 x 0.8): Eddie's back is to it.
var STAND_GATE_X := 0.0   # set from the level's dead-end drawing (gen/levels.py stand_at_gate puts the stand by it)
func _stand_gate_x() -> float:
	for seg in level.get("street", []):
		if String(seg[0]) == "deadend":
			return float(seg[1]) + (2620.0 - 58.0) * 1.52 * 3038.0 / (3038.0 - 58.0)
	return float(level.get("stand", 0.0)) + 530.0
var _stand_t := 0.0
var _stand_spawn := 0.0
var _shake := 0.0
static var checkpoint := -1.0   # where a death sends him back to on this map; -1 = the start
static var checkpoint_y := 0.0   # and how high: up on the roof he comes back on the roof
# which map the checkpoint belongs to (user 17. 11.: "the fifth map loaded oddly, then crashed" - the crash report showed him
# put down at the old map's checkpoint near the new map's end, the map at once cleared and the boss cut started: the old
# scene still ran ~2 s after the travel reset and set its checkpoint again). A checkpoint from another map is dropped.
static var checkpoint_map := ""
static var _ground_cp := -1.0   # the last checkpoint down in the street, kept while he is up on the roof
## (audit 21. 11.) what he had done by the checkpoint: the scene reload after a death would forget it, but the men behind
## the checkpoint are not put back - so mercy, executions, kills, XP and the big guns he carried come back with him
static var _cp_keep := {}
static var _cut_seen := ""     # the before-map comic already played for this map (a death before the first checkpoint: not again)
# the guns (range = life x BULLET_SPEED 4200: a side gun about one screen, 2600 px; the shotgun two
# thirds of one, its pellets spreading; 2026-11-16, they used to cross the whole map): seconds between shots, rounds when picked up, pellets per shot, spread (radians), how long a
# bullet flies, the kick of the arm, the sound
const WEAPONS := {
	"revolver": {"mag": 6, "reload": 0.85, "cool": 0.2, "ammo": 0, "pellets": 1, "spread": 0.0, "life": 0.62, "kick": 0.2, "sound": "shot_player", "name": "REVOLVER"},
	"pistols": {"mag": 14, "reload": 0.95, "cool": 0.11, "ammo": 42, "pellets": 1, "spread": 0.025, "life": 0.55, "kick": 0.12, "sound": "shot_enemy", "name": "TWO PISTOLS"},
	"tommy": {"mag": 30, "reload": 1.2, "cool": 0.085, "ammo": 60, "pellets": 1, "spread": 0.05, "life": 0.6, "kick": 0.08, "sound": "shot_tommy", "name": "TOMMY GUN"},
	"shotgun": {"mag": 5, "reload": 1.1, "cool": 0.7, "ammo": 10, "pellets": 6, "spread": 0.15, "life": 0.42, "kick": 0.35, "sound": "shot_shotgun", "name": "SHOTGUN"},
	"rifle": {"mag": 5, "reload": 1.6, "cool": 1.0, "ammo": 0, "pellets": 1, "spread": 0.0, "life": 1.8, "kick": 0.4, "sound": "shot_shotgun", "name": "RIFLE"},   # the marksman's: never Frank's
}
# The side gun, as he chose it at the gunsmith (2026-11-16): one or two revolvers or Berettas, each its
# own feel. dmg = body damage (a man takes mob_hp; a head shot always kills). In code the side gun is
# always the weapon "revolver"; `side` says which it is.
const SIDE_STATS := {
	"revolver": [{"mag": 6, "reload": 0.7, "cool": 0.22, "spread": 0.0, "dmg": 1.5, "kick": 0.24, "sound": "shot_player", "name": "REVOLVER"},
			{"mag": 12, "reload": 1.35, "cool": 0.14, "spread": 0.03, "dmg": 1.0, "kick": 0.2, "sound": "shot_player", "name": "TWO REVOLVERS"}],
	"beretta": [{"mag": 8, "life": 0.55, "reload": 0.6, "cool": 0.16, "spread": 0.012, "dmg": 1.0, "kick": 0.12, "sound": "shot_enemy", "name": "BERETTA"},
			{"mag": 16, "life": 0.5, "reload": 1.1, "cool": 0.1, "spread": 0.07, "dmg": 0.75, "kick": 0.1, "sound": "shot_enemy", "name": "TWO BERETTAS"}],
}
# the side gun's cards by what they do: [the revolver's effect, the Beretta's]
const SIDE_FX := {"fast": ["fasthands", "b_fast"], "dmg": ["heavy", "b_hot"], "steady": ["steady", "b_steady"], "last": ["lastround", ""], "mag": ["", "b_mag"]}
var side := "revolver"


## A gun's numbers: the side gun's from SIDE_STATS, the others from WEAPONS.
func _w(kind: String) -> Dictionary:
	if kind != "revolver":
		return WEAPONS[kind]
	var w: Dictionary = WEAPONS["revolver"].duplicate()
	w.merge(SIDE_STATS[side][1 if player != null and player.dual else 0], true)
	return w


## A side-gun card (SIDE_FX) for the gun he carries.
func _sperk(what: String) -> bool:
	var fx: String = SIDE_FX[what][0 if side == "revolver" else 1]
	return fx != "" and _perk(fx)


const WOOD := ["crate", "crate_long", "kegs", "barrel", "milk_crates", "fruit_cart", "bench", "cable_spool", "linen_table", "desk", "court_bench", "newsstand", "paper_bundles"]
# How far down each drawing its top surface is, the line a man stands on: the drawings are seen a
# little from above, so the top of the picture is the far edge of the lid, not where feet go. The
# side-view redraws (art_src/94 and 95: everything a man can stand on but the bench, the linen table,
# the wash tub, the newsstand and the fruit cart) have flat tops.
const TOP_INSET := {"crate": 0.01, "crate_long": 0.07, "drum": 0.01, "dumpster": 0.04, "washer": 0.01, "laundry_cart": 0.12,
	"trash_can": 0.08, "sacks": 0.06, "barrel": 0.01,
	"linen_table": 0.3, "wash_tub": 0.2, "bench": 0.02, "newsstand": 0.05, "paper_bundles": 0.03, "cable_spool": 0.0, "fruit_cart": 0.03,
	"kegs": 0.0, "stack": 0.01, "milk_crates": 0.17, "mailbox": 0.02, "desk": 0.03, "filing": 0.01, "safe": 0.01, "court_bench": 0.02}
## The lamps painted into each interior, as fractions of its drawing, and their colour. A room's
## light comes from these and only these: a soft glow on the bulb and a round, soft pool of light
## round it (never a hard-edged cone), on the drawing and on everyone in it.
const ROOM_PENDANTS := {   # [x, hook y, bulb y] on the painting: enamel lamps on cords from its ceiling beam
	"warehouse": [[0.31, 0.155, 0.36], [0.665, 0.155, 0.33]],
}
const ROOM_BULBS := {   # [x, y, colour, size]: measured on each painting at the glass itself
	"yard": [[0.594, 0.212, "warm", "small"]],
	"tenement": [[0.499, 0.266, "warm", "big"]],
	"laundry": [[0.249, 0.263, "warm", "big"], [0.495, 0.411, "warm", "small"], [0.763, 0.182, "warm", "big"], [0.794, 0.313, "warm", "small"]],
	"warehouse": [[0.652, 0.471, "warm", "small"], [0.432, 0.25, "sky", "big"], [0.651, 0.25, "sky", "big"], [0.888, 0.25, "sky", "big"]],
	"club": [[0.536, 0.173, "spot", "big"], [0.461, 0.66, "warm", "small"], [0.528, 0.589, "warm", "small"], [0.591, 0.614, "warm", "small"], [0.609, 0.662, "warm", "small"]],
	"hold": [[0.511, 0.325, "warm", "big"]],
	"office": [[0.541, 0.54, "green", "small"]],
	"purser": [[0.617, 0.47, "green", "small"]],   # (QUEUE §18, 21. 11.) the Santa Lucia's purser's desk lamp
	"vail": [[0.675, 0.63, "candle", "big"], [0.755, 0.34, "candle", "big"]],   # Vail Shipping's files on fire, the burning post
	"cityhall": [[0.801, 0.308, "warm", "big"], [0.5, 0.12, "sky", "big"]],
	"catacombs": [[0.392, 0.325, "warm", "small"], [0.412, 0.379, "warm", "small"], [0.587, 0.382, "warm", "small"], [0.604, 0.337, "warm", "small"],
			[0.07, 0.53, "candle", "small"], [0.25, 0.53, "candle", "small"]],
}
const BULB_COLORS := {"warm": Color(1.0, 0.72, 0.4), "sky": Color(0.75, 0.82, 0.95), "spot": Color(1.0, 0.92, 0.75),
	"green": Color(0.75, 0.95, 0.6), "candle": Color(1.0, 0.6, 0.3)}
# What stands in for each kind of cover where: a laundry has washers and carts, a subway benches and
# newsstands, an office desks and a safe. Collision stays the kind's box; the drawing keeps its own
# proportions, standing on the ground in the middle of it. One of the list, picked by where it stands.
const PROP_SETS := {
	"laundry": {"crate": ["crate", "laundry_cart"]},
	"room:catacombs": {"crate": ["kegs"], "crate_long": ["kegs"]},   # a speakeasy: beer kegs, not dock crates
	"subway": {"crate": ["paper_bundles", "crate"], "crate_long": ["bench"], "drum": ["mailbox"]},
	"platform": {"crate": ["paper_bundles", "crate"], "crate_long": ["bench"]},
	"tunnel": {"crate": ["cable_spool", "crate"]}, "tunnel_lo": {"crate": ["cable_spool", "crate"]}, "walkway": {"crate": ["cable_spool", "crate"]}, "signal": {"crate": ["cable_spool", "crate"]}, "arches": {"crate": ["cable_spool", "crate"]}, "yard": {"crate": ["cable_spool", "crate"]},
	"market": {"crate": ["milk_crates", "crate", "sacks"], "drum": ["mailbox", "drum", "barrel"]},
	"bluenote": {"crate": ["kegs", "milk_crates", "crate"]}, "alley": {"crate": ["crate", "milk_crates", "trash_can"]},
	"church": {"crate": ["crate", "paper_bundles"], "drum": ["mailbox"]}, "deadend": {"crate": ["crate", "trash_can"], "drum": ["drum", "barrel"]},
	"warehouse": {"crate": ["crate", "cable_spool"]}, "harbor": {"crate": ["crate", "cable_spool", "kegs"]},
	"quay": {"crate": ["crate", "sacks"], "drum": ["barrel", "drum"]}, "pier17": {"crate": ["crate", "cable_spool"]}, "shipping": {"crate": ["crate", "sacks"], "drum": ["drum", "barrel"]},
	"room:laundry": {"machine": ["washer"], "crate": ["laundry_cart"], "crate_long": ["linen_table"], "drum": ["wash_tub"]},
	"room:tenement": {"crate": ["milk_crates", "paper_bundles"], "crate_long": ["court_bench"]},
	"room:club": {"crate_long": ["kegs"], "crate": ["kegs"]},   # no shipping crates in a nightclub: beer kegs by the bar
	"room:office": {"crate_long": ["desk"], "machine": ["filing"], "crate": ["safe"]},
	"room:cityhall": {"crate": ["paper_bundles"], "machine": ["paper_bundles"], "crate_long": ["court_bench"]},

}
# How tall each thing really is next to a man (he is 400 high): the height of the surface he could
# stand on. The drawing is scaled to that and nothing else, and the cover is exactly the drawing.
const PROP_H := {"washer": 258.0, "laundry_cart": 215.0, "linen_table": 195.0, "wash_tub": 190.0, "bench": 200.0,
	"paper_bundles": 170.0, "cable_spool": 250.0, "kegs": 250.0, "milk_crates": 200.0, "mailbox": 250.0, "desk": 175.0,
	"filing": 255.0, "safe": 245.0, "court_bench": 215.0, "trash_can": 175.0, "sacks": 140.0, "barrel": 215.0}
const IRON_LAND_W := [547.0, 748.0, 949.0, 1149.0]
const IRON_DECK := 193.5    # down the landing drawing to where feet stand
const IRON_SPLIT := 236.0   # below this row: brackets and legs
const IRON_FOOT := Vector2(49.5, 550.8)   # the lowest tread in the flight drawing
const INDOOR_ONLY := ["washer", "wash_tub", "linen_table", "desk", "filing", "safe", "court_bench"]
const OUTDOOR_ONLY := ["mailbox", "fruit_cart", "dumpster", "hydrant", "bench"]
const BOX_ART := {"barrel": ["drum_red", Color(1.7, 1.55, 1.55)], "machine": ["dumpster", Color(0.7, 0.72, 0.78)], "bar": ["crate_long", Color(0.45, 0.32, 0.26)]}
const ENEMY_MAG := {"shade": 99, "post": 6, "tommy": 3, "shotgun": 4, "boss": 5, "sniper": 5, "shield": 6, "dynamite": 99, "hook": 99}   # shots (a tommy gunner's: bursts) before a reload
const ENEMY_TINT := {"post": Color(1, 1, 1), "tommy": Color(1, 1, 1), "shotgun": Color(1, 1, 1), "boss": Color(1, 1, 1)}   # (their clothes tell them apart now)
var ambient := AMBIENT
const SIGHT := 2100.0   # a mobster starts shooting once the detective is this close
# The automatic pictures: when (seconds of game time) and under what name.
const SHOTS := [[6.45, "duck"], [6.95, "duck_walk_a"], [7.15, "duck_walk_b"], [1.2, "stand"], [2.0, "run_a"], [2.11, "run_b"], [2.22, "run_c"], [2.8, "run"], [2.95, "dive"], [3.08, "roll_a"], [3.2, "roll_b"], [3.32, "roll_c"], [3.6, "up"], [4.45, "slide_a"], [4.7, "slide_b"], [5.35, "jump"], [5.62, "land_a"], [5.72, "land_b"]]
const BULLET_SPEED := 4200.0
const PLAYER_HP := 5
const MOBSTER_HP := 3
const GRAVITY := 3000.0
const JUMP_SPEED := 1300.0 * 1.0863   # sqrt(FIG): clears the (bigger) cover with the same room to spare
const RUN_SPEED := 640.0
const RUN_ACCEL := 4200.0   # he gets up to speed and stops over a few steps, not in one frame
const DIVE_SPEED := Vector2(1250.0, -900.0)
const VAULT_MAX := 270.0 * FIG   # a dive carries him over anything up to this tall instead of stopping dead
const DIVE_LAND := 125.0   # lying flat, the figure's origin sits this far below the pavement line
const SLOW_SCALE := 0.3   # how fast time runs while it is slowed
const CAM_Y_BASE := -508.0     # puts the pavement about four fifths of the way down the screen
## Feedback round 17. 11. (user: "turn them all on"): the pavement higher on the screen, clear of the thumb buttons;
## the backgrounds pushed back (BG_DIM); a light contour round the figures (puppet.gd). --oldlook shows the old one.
static var LOOK2 := not ARGS.has("--oldlook")
static var CAM_Y: float = CAM_Y_BASE + (150.0 if LOOK2 else 0.0)
const BG_DIM := 0.86
const CAM_LEAD := 400.0   # the camera looks ahead of the detective
const HIGH_LOOK_DOWN := 420.0   # and how far it looks down (px at the street zoom)
var _high := 0.0
const HIGH_WIDE := 0.2    # how much wider the camera pulls up high outside (fire escape, washing line): the street below shows
# Layers behind the street, nearest last: texture, how much they follow the camera (1 = not at all
# displaced, i.e. infinitely far), top edge in world units, scale, brightness, blur.
const DEPTH := [["res://art/bg/far.png", 0.85, -1560.0, 0.8, 0.18, 2.5, -25], ["res://art/bg/mid.png", 0.6, -1500.0, 0.7, 0.14, 1.5, -20]]

const LEGS := {
	"thigh": {"a": Vector2(86.5, 62.5), "b": Vector2(172.9, 418.5), "ppm": 1000},
	"shin": {"a": Vector2(80.6, 56.9), "b": Vector2(100.8, 543.5), "ppm": 1000},
}
var DETECTIVE := {
	"dir": "res://art/detective/", "weapon": "revolver", "leg_tex": "res://art/mobster/leg.png",
	# where things attach, in the torso drawing's pixels: the armholes, the bottom of the collar, the belt
	"on_torso": {"shoulder": Vector2(100.0, 225.0), "far_shoulder": Vector2(400.0, 240.0), "head": Vector2(272.0, 168.0), "belt": Vector2(262.0, 596.0)},
	"parts": {
		"head": {"a": Vector2(178.1, 390.6), "b": Vector2(178.1, 84.0), "ppm": 1100},
		# the drawing is used down to the belt only; below it the skirt takes over
		"torso": {"a": Vector2(239.0, 683.3), "b": Vector2(265.5, 65.7), "ppm": 1100, "region": Rect2(0.0, 0.0, 531.0, 627.0)},
		"uarm": {"a": Vector2(116.8, 65.1), "b": Vector2(131.4, 390.6), "ppm": 1100},
		"farm": {"a": Vector2(92.5, 77.4), "b": Vector2(266.4, 412.8), "ppm": 1100},
		# the coat below the belt, from the parts sheet: one panel that hangs over the legs
		"skirt": {"a": Vector2(250.0, 10.0), "b": Vector2(250.0, 850.0), "ppm": 1180},
		# pieces of the torso drawing laid on top again: the belt buckle, which hangs below the cut,
		# and the back wing of the collar over the top of the sleeve
		"collar_front": Rect2(350.0, 620.0, 65.0, 25.0),
		"collar_back": Rect2(150.0, 20.0, 85.0, 195.0),
		"thigh": LEGS["thigh"], "shin": LEGS["shin"],
	},
}
var MOBSTER := {
	"dir": "res://art/mobster/", "weapon": "pistol", "leg_tex": "res://art/mobster/leg.png",
	"on_torso": {"shoulder": Vector2(75.0, 125.0), "far_shoulder": Vector2(300.0, 130.0), "head": Vector2(207.0, 62.0), "belt": Vector2(216.0, 673.2)},
	"parts": {
		"head": {"a": Vector2(165.6, 351.5), "b": Vector2(165.6, 75.6), "ppm": 1000},
		"torso": {"a": Vector2(216.0, 673.2), "b": Vector2(207.4, 52.4), "ppm": 1000},
		"uarm": {"a": Vector2(92.6, 52.8), "b": Vector2(80.1, 283.8), "ppm": 1000},
		"farm": {"a": Vector2(50.5, 44.8), "b": Vector2(219.8, 276.0), "ppm": 1000},
		"thigh": LEGS["thigh"], "shin": LEGS["shin"],
	},
}

var player
var enemies: Array = []        # one entry per mobster: node, hp, cool, aim_off, alive
var boxes: Array[Rect2] = []
var cleared := false
var cam: Camera2D
var _hat_rain: Array = []   # rain splashing on his hat and shoulders, dripping off the brim
var _sky_mat: ShaderMaterial
var _flash := 0.0
var _lightning_t := randf_range(20.0, 45.0)
var _menu_x := 0.0   # where the camera rests behind the title
var _lead := CAM_LEAD   # how far ahead of the detective the camera looks; swings to the side he aims at
var _look := 1.0
var _face := 1.0   # the way he last walked: where he looks when nobody is about
var fore: Node2D
var depth: Array[Node2D] = []   # the far and mid layers, moved with the camera in _process
var depth_follow: Array[float] = []
var lamps: Array[Vector2] = []   # world positions of every lamp, for the cast shadows
var atmo
var steps: CPUParticles2D
var fx
var sfx
var _slowed_was := false
var _ghost_t := 0.0   # game seconds to the next afterimage
var hud
var max_hp := PLAYER_HP       # Eddie's, or Frank's for this point of the story (see _set_difficulty)
var mob_hp := MOBSTER_HP       # body hits a mobster takes; a head shot always kills
var hp := PLAYER_HP
var fire_cool := 0.0
var _last_hit := Vector2.ZERO   # where the last bullet struck a crate: it bursts outward from there
var mag := 6               # rounds in the gun; ammo is what is left to load (the revolver never runs out)
var reloading := 0.0       # seconds left of a reload
var _idle_fire := 0.0      # seconds since the last shot: a gun not quite full is topped up after a while
var _clicked := false      # dry-fired on this empty gun already: the next tap reloads instead
var slow_on := false           # toggled by the stopwatch button
var slow_left := 1.0           # 1 = full meter
var move_state := "ground"     # ground, jump, dive, roll, slide, flip, vault; on a rope: climb, zip, swing
var fall := 0.0                # vertical speed, pixels per second, down is positive
var run := 0.0                 # horizontal running speed, eased towards what the player asks for
var slide_left := 0.0          # seconds of slide remaining
var roll_done := 0.0           # 0..1 through the tumble
var _slow_cancelled := false   # slowed time switched off during this dive: it stays off until he lands
var _vaulted := false          # this dive has already vaulted off a crate
var _flip_way := 1.0
var dive_rolls := false        # this dive ends in a roll instead of a flat landing
var _stop_t := 0.0            # real seconds of an impact freeze or a final-shot slow motion still to run
var _stop_scale := 1.0        # how slow time runs during it
var _slow_base := false       # slowed time proper (the stopwatch or a dive), not an impact freeze
var _jump_buf := 0.0          # a jump pressed a moment too early still counts when he lands
var _dive_buf := 0.0          # (audit 22. 11.) the dive button tapped while he rolls or gets up: it still goes
var _dive_near: Array = []    # the crates near enough for the dive's launch simulation (not every crate on the map)
var _stunt_at := {}           # (audit 22. 11.) when each kind of stunt last gave its free slowed time
var _unpaused_frame := -1     # the frame Esc closed the pause card: the same press must not open it again
var _wall_t := 0.0            # in the air against a tall crate's side a moment ago: a jump now kicks off it (a stunt)
var _wall_away := 0.0         # which way off it
var _sprint := 0.0            # how long the stick has been held hard one way: only a committed run vaults
var _sprint_side := 0.0
var _coyote := 0.0            # and one pressed a moment after he stepped off an edge
var _step_half := 0
var _w_was := false
var _spawn_x := INF
var _spawn_wait := 0.0
var _ai_t := 0.0             # game time for the enemy AI (slows with slowed time)
var _shots_at := {}          # enemy id -> when he last fired: at most two of them shoot at once
var _hits_at: Array = []     # when the detective was hit lately: the encounter eases off if it is going badly
var _cover_t := 0.0          # how long the detective has sat behind cover
var _flank_called := false
var _behind_at := -99.0        # when a man was last sent round behind the detective (_send_round)
var _crate_shooters := 0       # men shooting at his crate this frame (no more than two at once)
var _crate_called := false
var _aic := -1
var _bark_t := -9.0          # when a mobster last shouted something (barks.gd): one voice at a time
var _bark_last := {}
var _bark_at := {}           # when each kind was last heard
var _bark_recent := []       # the last lines heard: not again soon
var _cry_t := -9.0           # the last dying man's cry
const BARK_GAP := {"empty": 18.0, "spot": 5.0, "reload": 7.0, "cover": 6.0, "taunt": 14.0, "crate": 10.0, "flank": 8.0}         # the last line used of each kind, so none comes twice running
var _names := []             # the names given out on this map
var _mercy: Array = []
var _sandbox := -1            # --sandbox=N: a trial map from levels.gd SANDBOX
static var _url_sandbox := -2   # the page's ?sandbox=N (-2: not read yet, -1: none or left for the title)
var sections: Array = []      # buildings in cross-section: [x0, x1, storeys, style] (levels.gd "sections")
var section_h := 700.0
var _bot_esc_up := false      # the test bot on a fire escape: turned back to the foot of the flight
var _free_slow := 0.0         # real seconds of slowed time a stunt gives for free (door kick 1.2 s, swing 1 s)
var _flat_art: Array = []     # [storey y, the flat's drawing, its kit]: <kit>_flat_open replaces it when the window goes
var _flats: Array = []        # the flats to kick into and jump out of (gen/levels.py flats)
var _stairdoors: Array = []   # the stairs in a building's back wall: [x, storey y, the y they lead to]
var _sd: Dictionary = {}       # on those stairs: where from, the door, where to, how long
var _storey_since := 0.0      # _ai_t when Frank came onto his storey of a building (the men on the stairs wait for it)
var _storey_was := -1
var _steps_above := 0.0       # s left of the camera looking up at steps on the storey above
var _door_armed := true       # (the works door lets him out: not in the moment he came in by it)
var _up_spent := false        # (the stick's push already used: for a door; let go of it first)
var _up_held := false         # the stick up / the up arrow (ladders)
var _bot_down := false        # (the bot, QUEUE §22) on his way back down from the works' high gallery
var _sec_art: Array = []      # per building: its storeys' drawings, seen only from inside
var _xy_checks: Array = []        # --test=mercy: its two men
var _taught_run := false      # the lesson about giving up, once per run in the tests
var _fallen := []            # [name, x, time] of the men shot on this map, for the last one to call for
var _taunt_t := 0.0
var _prop_groups := []   # (--test=props)   # (--test=aicover: the crate he hides behind)
var _grace := 3.0             # seconds after a start or a checkpoint before anybody may fire
var _vault := {}              # the speed vault in progress: from, to, top, t
var glide := 0.0               # horizontal speed of a dive
var over := false              # the detective is down
var _time := 0.0
var _env: Environment
var _probe := 0.0
var _auto := ""   # a scripted test run from the command line; empty in normal play
var _at := 0.0
var _auto_done := 0
var _bot_fight := 0.0
var _dive_at := 1380.0
var _bot_x := 0.0
var _tour: Array = []
var _bot_back := 0.0
var _bot_stuck := 0.0
var _bot_log := 0.0
var _snap := 0
var _slow_look := 0.0   # 0 normal .. 1 the screen is in its slowed-time look
var _show_fps := false
var _dt := -1.0   # the clock of the self-running demo; below 0 = not running. F9 starts it.
var _demo_step := 0
var _demo_duck := false
var _tt := -1.0   # clock of the F11 cover test; below 0 = not running
const TEST_FIRE := [1.6, 2.1, 2.6, 3.1, 3.6]
const TEST_SHOTS := [[1.2, "cover_duck"], [1.68, "cover_pop"], [3.9, "stain"], [4.6, "enemy_a"], [5.1, "enemy_b"], [5.6, "enemy_c"], [6.1, "enemy_d"]]
var _tt_done := 0
var _duck_was := false        # the crouch key was down last frame: a fresh press while running slides
var _pop := 0.0               # seconds the detective stays risen out of his crouch to shoot
var _test_aim := Vector2.INF   # the ricochet test aims here
var _aim_point := Vector2.INF   # where the detective aims, in the world, this frame
var _fire_buf := 0.0          # a tap that came while the gun was still cycling: fired as soon as it is ready
var _death_t := -1.0          # real seconds since the detective went down
var _queued_shot := false     # fire as soon as he has risen far enough to clear his cover
var _shots_done := 0


## One sheet of paper over everything on the screen, menus and HUD included: fine fibres and grain
## multiplied in, so the street, the buttons and the cards all look printed on the same newsprint.
const PRINT_SHADER := """
shader_type canvas_item;
render_mode blend_mul, unshaded;
uniform float grain = 0.07;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = FRAGCOORD.xy;
	float speck = hash(floor(p * 0.5) + floor(TIME * 8.0) * 13.0);   // fine grain, alive like film
	float fibre = noise(vec2(p.x * 0.02, p.y * 0.35));                 // long paper fibres
	float blot = noise(p * 0.004);                                     // uneven ink take-up
	float v = 1.0 - grain * (speck * 0.6 + fibre * 0.5 + blot * 0.5);
	COLOR = vec4(vec3(v) * vec3(1.0, 0.99, 0.965), 1.0);
}
"""


func _add_print_sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = PRINT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	layer.add_child(r)
	add_child(layer)


## The pack with this part of the story's drawings: fetched next to the page (or read from --packs=
## on a desktop test), then the scene starts again with it. A paper caption says what is happening.
## (audit 22. 11.) The bytes go into the file as they come, so the page holds the pack once and not twice
## (HTTPRequest kept the whole body and the file beside it: ~180 MB for pack a on a phone); a failure says
## so and offers TRY AGAIN or BACK TO THE TITLE, instead of retrying blind for ever.
func _fetch_pack() -> void:
	set_process(false)
	set_physics_process(false)
	var layer := CanvasLayer.new()
	layer.layer = 41
	add_child(layer)
	var view := get_viewport().get_visible_rect().size
	var Paper = load("res://paper.gd")
	var font: Font = load("res://fonts/ComicNeue-BoldItalic.woff")
	var box := Control.new()
	layer.add_child(box)
	var say := func(text: String) -> void:
		for c in box.get_children():
			c.queue_free()
		var cap: Control = Paper.caption(text, font, 26, 640.0)
		cap.position = Vector2((view.x - cap.size.x) * 0.5, view.y - 48.0 - cap.size.y)
		box.add_child(cap)
	var src := Packs.url(chapter, map)
	crumb("fetch pack %s from %s %s" % [Packs.group(chapter, map), src, _mem_line()])
	var failed := func() -> void:   # the caption and two ways on
		say.call("THE CASE FILE WOULDN'T OPEN. CHECK THE CONNECTION.")
		var head := FontVariation.new()
		head.base_font = load("res://fonts/Oswald.ttf")
		head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		var row := [["TRY AGAIN", func() -> void:
				box.queue_free()
				layer.queue_free()
				_fetch_pack()],
			["BACK TO THE TITLE", func() -> void:
				in_menu = true
				get_tree().reload_current_scene()]]
		var w := 300.0
		var cap: Control = box.get_child(box.get_child_count() - 1)
		var y := cap.position.y - 32.0 - 72.0   # (above the caption, with air)
		for k in row.size():
			var b: Control = Paper.button("tape", Vector2(w, 72.0), row[k][1], func(_n: String) -> void: pass)
			Paper.write(b, String(row[k][0]), head, 26, Paper.INK)
			b.position = Vector2(view.x * 0.5 + (-w - 8.0 if k == 0 else 8.0), y)
			box.add_child(b)
		if "--test=packfail" in ARGS:
			get_tree().create_timer(1.0).timeout.connect(func() -> void:
				await _shot("packfail")
				get_tree().quit())
	if not OS.has_feature("web"):
		if not "--test=packfail" in ARGS and Packs.mount(src, chapter, map):
			get_tree().reload_current_scene.call_deferred()
		else:
			push_warning("pack missing: " + src)
			failed.call()
		return
	say.call("OPENING THE CASE FILE...")
	var file := "/tmp/ashes_pack_%s.pck" % Packs.group(chapter, map)   # in the page's memory only: user:// would be stored in the browser and loaded back at every start
	var fa := FileAccess.open(file, FileAccess.WRITE)
	if fa == null:   # no /tmp here: the browser's own storage then
		file = "user://pack_%s.pck" % Packs.group(chapter, map)
		fa = FileAccess.open(file, FileAccess.WRITE)
	var abs_url := String(JavaScriptBridge.eval("new URL(%s, location.href).href" % JSON.stringify(src), true))
	var err := await _pull(abs_url, fa, func(pc: int) -> void: say.call("OPENING THE CASE FILE... %d %%" % pc))
	if fa != null:
		fa.close()
	if err == "" and Packs.mount(file, chapter, map):
		crumb("pack %s mounted %s" % [Packs.group(chapter, map), _mem_line()])
		get_tree().reload_current_scene()
	else:
		crumb("pack fetch failed: %s, open err %d" % [err if err != "" else "mount", FileAccess.get_open_error()])
		DirAccess.remove_absolute(file)
		failed.call()


## A file over HTTP straight into fa, a few MB a frame (HTTPClient: the web's fetch, the browser has
## already unpacked what GitHub sent gzipped). Returns "" or what went wrong.
func _pull(url: String, fa: FileAccess, progress: Callable) -> String:
	if fa == null:
		return "no file"
	var tls := url.begins_with("https://")
	var rest := url.substr(8 if tls else 7)
	var cut := rest.find("/")
	var host := rest.substr(0, cut)
	var path := rest.substr(cut)
	var port := -1
	if host.contains(":"):
		port = int(host.get_slice(":", 1))
		host = host.get_slice(":", 0)
	var http := HTTPClient.new()
	http.read_chunk_size = 1024 * 1024
	if http.connect_to_host(("https://" if tls else "http://") + host, port) != OK:
		return "connect"
	var t0 := Time.get_ticks_msec()
	while http.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		http.poll()
		await get_tree().process_frame
		if Time.get_ticks_msec() - t0 > 20000:
			return "connect timeout"
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return "connect status %d" % http.get_status()
	if http.request(HTTPClient.METHOD_GET, path, []) != OK:
		return "request"
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		await get_tree().process_frame
	if not http.has_response() or http.get_response_code() != 200:
		return "code %d status %d" % [http.get_response_code(), http.get_status()]
	var total := http.get_response_body_length()   # (the gzipped size from GitHub, or -1: the per cent is a guide)
	var got := 0
	var last := Time.get_ticks_msec()
	var shown := -1
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var frame := 0
		while frame < 8 * 1024 * 1024:   # several chunks a frame: 64 KB a frame took 17 s for 68 MB
			var chunk := http.read_response_body_chunk()
			if chunk.is_empty():
				break
			fa.store_buffer(chunk)
			got += chunk.size()
			frame += chunk.size()
			last = Time.get_ticks_msec()
		if total > 0 and mini(99, 100 * got / total) != shown:
			shown = mini(99, 100 * got / total)
			progress.call(shown)
		if Time.get_ticks_msec() - last > 30000:   # nothing for half a minute: the line is gone
			return "stalled at %d bytes" % got
		await get_tree().process_frame
	if http.get_status() != HTTPClient.STATUS_CONNECTED and http.get_status() != HTTPClient.STATUS_DISCONNECTED:
		return "body status %d" % http.get_status()
	if got == 0 or (total > 0 and got < total):
		return "short %d of %d" % [got, total]
	crumb("pack %d bytes in %d ms" % [got, Time.get_ticks_msec() - t0])
	return ""


## A line for the crash report (web only): what the game was doing, kept in the browser's storage so
## the next load can send it home if this page gets killed (see web/crash.js beside the deploy script).
## Startup timing (--timing): how long each part of building the page took.
static var _tm_last := 0
func _tm(what: String) -> void:
	if "--timing" in ARGS:
		var now := Time.get_ticks_msec()
		print("TIMING %-14s %5d ms  (at %d)" % [what, now - _tm_last, now])
		_tm_last = now


static func crumb(text: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ashesCrumb&&window.ashesCrumb(%s)" % JSON.stringify(text), true)


## Anonymous play data (crash.js ashesEvent -> public.ashes_events): where players die, what they finish.
## Only the real game on the web: never the tests, the title or a trial map. The setting is read by crash.js.
func _event(kind: String, data = null) -> void:
	if not OS.has_feature("web") or _auto != "" or in_menu or _sandbox >= 0 or player == null:
		return
	JavaScriptBridge.eval("window.ashesEvent&&window.ashesEvent(%s,%s,%d,%d,%s)" % [JSON.stringify(kind),
		JSON.stringify("%d:%d" % [chapter, map]), int(player.position.x), int(player.position.y), JSON.stringify(data)], true)


## A short buzz in the hand (crash.js ashesBuzz: Android vibrates, iPhone ticks on the next touch).
func _buzz(ms: int) -> void:
	if OS.has_feature("web") and _auto == "" and not in_menu:
		JavaScriptBridge.eval("window.ashesBuzz&&window.ashesBuzz(%d)" % ms, true)


func _mem_line() -> String:
	var heap := -1
	if OS.has_feature("web"):
		heap = int(JavaScriptBridge.eval("window.ashesMem?ashesMem():-1", true))
	return ("heap=%dMB " % heap) + "%s %d:%d x=%d static=%dMB peak=%dMB tex=%dMB buf=%dMB fps=%d nodes=%d cut=%s lowfail=%d" % ["menu" if in_menu else "map", chapter, map,
		int(player.position.x) if player != null else -1, OS.get_static_memory_usage() / 1048576, OS.get_static_memory_peak_usage() / 1048576,
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576, int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)) / 1048576,
		Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _in_cut, LowRes.failed]


func _ready() -> void:
	if _auto_arg() == "hops": print("READY ", chapter, ":", map)
	(func() -> void: crumb("ready " + _mem_line())).call_deferred()
	_add_print_sheet()
	for arg in ARGS:
		if arg.begins_with("--chapter="):
			chapter = int(arg.trim_prefix("--chapter="))
		if arg.begins_with("--map="):
			map = int(arg.trim_prefix("--map="))
		if arg.begins_with("--sandbox="):   # a trial map (levels.gd SANDBOX): played as chapter I
			_sandbox = int(arg.trim_prefix("--sandbox="))
			chapter = 1
		if arg.begins_with("--test="):
			in_menu = arg == "--test=menu" or arg == "--test=whatsnew" or arg == "--test=instincts" or arg == "--test=gunsmith" or arg == "--test=titleset" or arg == "--test=erase" or arg == "--test=neon" or arg == "--test=paperkit" or arg.begins_with("--test=ui")
	var picked := false
	for arg in ARGS:
		picked = picked or arg.begins_with("--chapter=")
	if OS.has_feature("web") and _url_sandbox == -2:   # (QUEUE §21) ...?sandbox=N on the web: a trial map (the pilot block)
		var q := str(JavaScriptBridge.eval("location.search", true))   # straight away; restarts stay on it, QUIT TO TITLE leaves it
		_url_sandbox = int(q.substr(q.find("sandbox=") + 8).get_slice("&", 0)) if q.find("sandbox=") >= 0 else -1
		if _url_sandbox >= 0:
			in_menu = false
	if _url_sandbox >= 0:
		if in_menu:
			_url_sandbox = -1
		else:
			_sandbox = _url_sandbox
			chapter = 1
			map = 0
			picked = true
	if not _booted:   # a fresh page asked for by the last one (another part of the story): straight back to it
		_booted = true
		var r := Packs.take_resume()
		if r.x >= 0:
			picked = true
			chapter = r.x
			in_menu = r.y < 0
			if r.y >= 0:
				map = r.y
				_saved_cp()   # (a fresh page for another part of the story: the statics are gone)
	if in_menu and not picked:   # the title stands in the street where the story has got to
		var p := MenuScript.progress()
		if p[0] >= 0 and Levels.CAMPAIGN[p[0]]["ready"]:
			chapter = p[0]
			map = p[1]
		else:
			chapter = Levels.CAMPAIGN.size() - 1
			while chapter > 0 and not Levels.CAMPAIGN[chapter]["ready"]:
				chapter -= 1
			map = Levels.CAMPAIGN[chapter]["maps"].size() - 1
	if "--test=curve" in ARGS:   # prints the difficulty curve over the whole story
		_print_curve()
		set_process(false)
		set_physics_process(false)
		get_tree().quit()
		return
	# The title must not wait on a chapter's drawings (2026-11-16: a cold start fetched up to 68 MB more
	# before the menu showed). When they are not on the page yet, it stands in a street made only of
	# drawings the base pack holds (the 1931 tenement row, without its fire); the chapter's pack comes
	# when a map is picked.
	var stand_in := false
	if in_menu and not Packs.has(chapter, map):
		stand_in = true
		chapter = 2
		for k in Levels.CAMPAIGN[2]["maps"].size():
			if String(Levels.CAMPAIGN[2]["maps"][k]["name"]) == "1931":
				map = k
	if not stand_in and not Packs.has(chapter, map):   # this part of the story's drawings are not on the page yet
		if Packs.needs_fresh_page(chapter, map):
			crumb("fresh page for %d:%d (pack %s held)" % [chapter, map, Packs.mounted])
			set_process(false)
			set_physics_process(false)
			set_process_input(false)
			set_process_unhandled_input(false)
			Packs.fresh_page(chapter, -1 if in_menu else map)
		else:
			set_process_input(false)
			set_process_unhandled_input(false)
			_fetch_pack()
		return
	if "--test=packfail" in ARGS and not in_menu:   # the caption and buttons of a failed pack
		_fetch_pack()
		return
	var ch: Dictionary = Levels.CAMPAIGN[chapter]
	level = ch["maps"][map]
	if _sandbox >= 0:
		level = Levels.SANDBOX[0]["maps"][_sandbox]
	if stand_in:
		level = level.duplicate()
		level["events"] = []
		level["memory"] = false
		level["embers"] = 0.0
	if in_menu:   # the title covers the street (_hide_world): build only its first stretch, nobody in it
		level = level.duplicate()
		level["street"] = (level["street"] as Array).slice(0, 2)
		level["enemies"] = []
		level["pickups"] = []
		level["rooms"] = []
		level["events"] = []
		for k in ["sections", "flats", "stairdoors", "ropes"]:   # (audit 22. 11.) no house in cross-section held in memory under the title
			if level.has(k):
				level[k] = []
	level_end = level["end"]
	_set_difficulty(String(ch["hero"]))
	rooms = level["rooms"]
	if _auto_arg() != "" or checkpoint_map != "%d:%d" % [chapter, map]:
		checkpoint = -1.0
		checkpoint_y = 0.0
		_ground_cp = -1.0
	if checkpoint < 0.0 or String(_cp_keep.get("map", "")) != "%d:%d" % [chapter, map]:
		_cp_keep = {}
	if in_menu:
		_cut_seen = ""
	checkpoint_map = "%d:%d" % [chapter, map]
	for arg in ARGS:   # (test) as if he came back from a death at this checkpoint: --cp=x,y
		if arg.begins_with("--cp="):
			var v := arg.substr(5).split(",")
			checkpoint = float(v[0])
			checkpoint_y = float(v[1]) if v.size() > 1 else 0.0
	ambient = ch["ambient"]
	atmo = AtmosphereScript.new()
	add_child(atmo)
	_tm("atmo")
	sfx = SfxScript.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS   # before the street: its signs, lamps and steam put their sounds in it
	add_child(sfx)
	_tm("sfx")
	_build_street()
	_build_exit()
	_tm("street")
	roof = level.get("roof", {})
	_build_roofs()
	_build_light()
	_tm("roofs+light")
	_build_level()
	_tm("level")
	if not level.get("under", false):   # no pigeons down in the subway
		_place_flocks()
	_tm("flocks")
	player = PuppetScript.new()
	player.cfg = DETECTIVE
	side = "revolver" if String(Levels.CAMPAIGN[chapter]["hero"]) == "eddie" else Instincts.side()
	player.side = side
	player.dual = String(Levels.CAMPAIGN[chapter]["hero"]) != "eddie" and Instincts.side_two()
	if ch["hero"] == "eddie" and not in_menu:   # Eddie (the title always shows Frank: it is his story)
		player.cfg = _eddie_cfg()
	player.night = _undo_night(1.0)
	add_child(player)
	_tm("player")
	mag = _mag_size("revolver")
	if player.dual:
		player.set_weapon("revolver")   # the second revolver into the far hand
	if ch["hero"] == "eddie" and not in_menu:   # his navy pea coat, short at the hip, not Frank's long tan trench
		for part in ["torso", "skirt", "uarm_f", "uarm_b", "collar_front", "collar_back"]:
			if player._spr.has(part):
				player._spr[part].modulate *= Color(0.34, 0.4, 0.58)
		for part in ["farm_f", "farm_b"]:
			if player._spr.has(part):
				player._spr[part].modulate *= Color(0.55, 0.6, 0.75)
		if player._skirt_mesh:
			player._skirt_mesh.modulate *= Color(0.34, 0.4, 0.58)
	if checkpoint > 0.0 and not in_menu:
		player.position = Vector2(checkpoint, _floor_at(checkpoint, checkpoint_y - 10.0 if checkpoint_y < 0.0 else -1.0))
		if ARGS.has("--log-sets"): print("RESPAWN AT ", player.position)
		cam_start = player.position.x
	elif level.has("start_xy") and not in_menu:   # (TENEMENTS, 18. 11.: he starts where THE LAUNDRY left him - in the flat upstairs)
		var sxy: Array = level["start_xy"]
		player.position = Vector2(float(sxy[0]), float(sxy[1]))
		_ground_y = float(sxy[1])
		cam_start = player.position.x
		if level.has("break_in"):   # the men on the stairs break the flat's door in behind him
			get_tree().create_timer(float(level["break_in"]), false).timeout.connect(func() -> void:
				var f := _flat_at_storey(float(sxy[1]), float(sxy[0]))
				if not f.is_empty() and not f["open"] and not over:
					_kick_door(f, false)
					_say_near(f))
	sets = SetpiecesScript.new()
	add_child(sets)
	sets.setup(self)
	_tm("sets")
	_event.call_deferred("start", {"from": "checkpoint" if checkpoint > 0.0 else "top"})
	if _card_up:   # the card that covered the load comes off now the street is built
		_card_up = false
		for n in get_tree().root.get_children():
			if n.get_script() == LoadingScript:
				n.queue_free()
		var lift = LoadingScript.new()
		lift.chapter = chapter
		lift.map = map
		lift.to_menu = in_menu
		lift.lifting = true
		lift.quick = _retry
		_retry = false
		add_child(lift)

	fore = Node2D.new()   # foreground silhouettes, nearer than the action, so they slide past faster
	fore.z_index = 10
	add_child(fore)
	_scatter_fore()
	_tm("fore")
	# (the telephone wires sagging across the top of the frame are gone, user 17. 11.: with the camera going up the fire
	# escapes they cut across the facades, hung from nothing)

	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.ignore_rotation = false   # it leans a little into the aim
	cam.position = Vector2(cam_start + CAM_LEAD, CAM_Y)
	add_child(cam)
	cam.make_current()
	_build_depth()
	atmo.add_rain(cam, _undo_night(0.7), -WALL_LIFT + 18.0 - CAM_Y)
	var rain: float = _rain()
	atmo.rain_far.amount = maxi(1, int(atmo.rain_far.amount * rain))
	atmo.rain_near.amount = maxi(1, int(atmo.rain_near.amount * rain))
	if rain <= 0.0:   # underground: no rain, only the drip
		atmo.rain_far.emitting = false
		atmo.rain_near.emitting = false
	_tm("cam+depth+rain")
	atmo.add_post(self)
	atmo.set_ash(MenuScript.guilt() / 10.0)
	atmo.set_lift(0.2)   # the darkest darks opened a little: walls in the dark keep their lines (the user: a fifth of the trial)
	for a in ARGS:
		if a.begins_with("--lift="):
			atmo.set_lift(float(a.trim_prefix("--lift=")))
	if level.get("dream", false):   # (not in the street memories: there it turns every lit shop window orange)
		atmo.set_fire_keep(1.0)
		atmo.set_dream(0.55)
		_dream_vfx.call_deferred()
	# the ash thickens with what Frank has done: men shot with their hands up stay in the air
	# (the dream, 18. 11.: the ash thickens the way his guilt does - made at its thickest, setpieces fades it in, _tick_guilt_ash)
	atmo.add_ash(cam, MenuScript.ash_level() if in_menu else (1.5 if level.get("dream", false) else minf(1.2, float(level.get("ash", 0.3)) + MenuScript.guilt() * 0.06)), float(level.get("embers", 0.0)))
	steps = atmo.add_steps(player, _undo_night(0.6))
	if rain > 0.0:
		_hat_rain = atmo.add_hat_rain(self, _undo_night(0.7))
	fx = FxScript.new()
	fx.night = _undo_night(1.0)
	fx.hit_test = _bullet_hit
	fx.clash = _bullets_clash
	add_child(fx)
	fx.sound = sfx
	fx.listener = player
	fx.wall_at = _wall_at
	_tm("cam+atmo")
	mapfx = MapFxScript.new()
	add_child(mapfx)
	mapfx.setup(self)
	fx.pass_test = mapfx.bullet_pass
	fx.stain_host = _stain_host
	hud = HudScript.new()
	add_child(hud)
	hud.set_segments(max_hp)
	if String(Levels.CAMPAIGN[chapter]["hero"]) == "eddie":   # the prologue is Eddie's: his picture in the corner
		hud.set_portrait("res://art/ui/portrait_eddie.png")
	hud.voice = sfx.voice
	if not in_menu and chapter > 0:   # Frank's conscience on his portrait (not Eddie's in the prologue)
		hud.set_conscience(_guilt_now() / 10.0, _pages_held())
	var big := Instincts.big()
	if not in_menu and map == 0 and checkpoint < 0.0 and big != "" and String(Levels.CAMPAIGN[chapter]["hero"]) != "eddie" \
			and Instincts.gun_open(big, chapter) and _auto in ["", "play"]:   # the big gun he took along: in the coat, few rounds
		var n: int = int(Instincts.BIG_START[big])
		_bag[big] = {"mag": mini(n, _mag_size(big)), "ammo": maxi(0, n - _mag_size(big))}
		hud.toast("%s IN THE COAT: %d ROUNDS" % [String(WEAPONS[big]["name"]), n])
	if not in_menu and checkpoint > 0.0 and not _cp_keep.is_empty():
		stats = (_cp_keep["stats"] as Dictionary).duplicate(true)
		_xp_run = int(_cp_keep["xp"])
		var kept: Dictionary = (_cp_keep["bag"] as Dictionary).duplicate(true)
		kept.erase("revolver")   # the side gun comes back loaded, in his hand
		for k in kept:
			_bag[k] = kept[k]
	if not in_menu:
		_show_guns()
	hud.target_at = _man_under
	_shake_on = bool(MenuScript.setting("shake"))
	_assist = bool(MenuScript.setting("assist"))
	if in_menu:
		hud.visible = false
		var menu = MenuScript.new()
		menu.play = _start_map
		menu.restart = func() -> void:   # a new start: the title over the prologue's street
			checkpoint = -1.0
			checkpoint_y = 0.0
			in_menu = true
			chapter = 0
			map = 0
			_travel(false)   # through black, the old title let go first (a straight reload held both: the phone killed the page)
		menu.sound = func(n: String) -> void: sfx.play(n, -8.0 if n == "type" else -4.0, INF, 0.15)
		add_child(menu)
		_tm("menu")
		_hide_world.call_deferred()
		player.set_state(0.0, Vector2(1.0, 0.0), 0.0)
		# the camera rests on the map's main street, the hero standing under the lights on the right
		var segs: Array = level.get("street", [])
		if segs.size() > 1:
			_menu_x = float(segs[1][1]) + 1500.0
		else:
			_menu_x = cam_start + 2000.0
		player.position = Vector2(_menu_x + 700.0, _floor_at(_menu_x + 700.0, -2000.0))
		for k in 30:   # facing back up the street, the gun hanging at his side
			player.set_state(0.0, Vector2(-0.3, 1.0), 0.1)
		cam.position = Vector2(_menu_x, CAM_Y)
	elif checkpoint > 0.0:
		hud.toast("CHECKPOINT")
	elif _auto_arg() == "" and CUTS_BEFORE.has("%d:%d" % [chapter, map]) and not MenuScript.is_done(chapter, map) \
			and _cut_seen != "%d:%d" % [chapter, map]:
		_cut_seen = "%d:%d" % [chapter, map]
		get_tree().paused = true   # the story first, the street holds still under it
		_play_cut(CUTS_BEFORE["%d:%d" % [chapter, map]], func() -> void:
			get_tree().paused = false
			hud.release_all()
			_in_cut = false
			hud.visible = true
			hud.title("%s  ·  %d / %d" % [String(ch["title"]), map + 1, ch["maps"].size()], String(level["name"]))
			_intro_pan()
			get_tree().create_timer(3.6).timeout.connect(hud.caption.bind(level["intro"])))
	elif _auto_arg() == "" or _auto_arg() == "play" or _auto_arg() == "intro":
		hud.title("%s  ·  %d / %d" % [String(ch["title"]), map + 1, ch["maps"].size()], String(level["name"]))
		_intro_pan()
		get_tree().create_timer(3.6).timeout.connect(hud.caption.bind(level["intro"]))
	if not OS.has_feature("web"):
		DirAccess.make_dir_recursive_absolute("res://_shots")
	for arg in ARGS:
		if arg.begins_with("--test="):
			_auto = arg.trim_prefix("--test=")
			if _auto.begins_with("dive:"):   # --test=dive:1300 taps the dive button at that x
				_dive_at = float(_auto.get_slice(":", 1))
				_auto = "dive"
	if "--newgame" in ARGS and in_menu and not _card_up:   # debug: erase, then start the story as a player would
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			MenuScript.erase_progress()
			_start_map(0, 0))
	if "--newgame" in ARGS and not in_menu:
		get_tree().create_timer(6.0, true, false, true).timeout.connect(func() -> void:
			print("NEWGAME ALIVE ", chapter, ":", map, " in_cut ", _in_cut)
			get_tree().quit())
	if _auto == "probe":   # --test=probe: what the renderer's texture memory is made of, freeing one kind of node at a time
		get_tree().create_timer(4.0, true, false, true).timeout.connect(func() -> void:
			var mb := func() -> int: return int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576
			print("PROBE start ", mb.call())
			for n in get_tree().root.find_children("*", "", true, false):
				n.set_process(false)
				n.set_physics_process(false)
			set_process(false)
			for kind in ["PointLight2D", "CanvasGroup", "GPUParticles2D", "CPUParticles2D", "Label", "TextureRect", "Polygon2D", "Line2D", "Sprite2D", "Control"]:
				for n in get_tree().root.find_children("*", kind, true, false):
					n.queue_free()
				for k in 4:
					await get_tree().process_frame
				print("PROBE after freeing ", kind, ": ", mb.call())
			_stream.clear()
			for k in 4:
				await get_tree().process_frame
			print("PROBE after stream clear: ", mb.call())
			var counts := {}
			for n in get_tree().root.find_children("*", "", true, false):
				counts[n.get_class()] = counts.get(n.get_class(), 0) + 1
			print("PROBE left nodes ", counts)
			for c in get_children():
				var before: int = mb.call()
				var nm := "%s(%s)" % [c.name, c.get_script().resource_path.get_file() if c.get_script() else c.get_class()]
				c.free()
				for k in 3:
					await get_tree().process_frame
				if before - int(mb.call()) > 0:
					print("PROBE child ", nm, " held ", before - int(mb.call()), " MB")
			print("PROBE after freeing all children: ", mb.call())
			get_tree().quit())
	if _auto == "endcut":   # --test=endcut: the map is won as a player would win it, its comic plays, the next map loads; memory every half second
		get_tree().create_timer(4.0, true, false, true).timeout.connect(func() -> void:
			_auto = ""
			_measure_from = Time.get_ticks_msec()
			_map_cleared())
	if _auto == "hops":   # --test=hops: map after map through reloads, printing the memory each time
		get_tree().create_timer(4.0, true, false, true).timeout.connect(func() -> void:
			print("HOP %d:%d  static %d MB (peak %d)  textures %d MB  video %d MB" % [chapter, map,
				OS.get_static_memory_usage() / 1048576, OS.get_static_memory_peak_usage() / 1048576,
				int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576,
				int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576])
			if true:
				var seen := {}
				for n in find_children("*", "", true, false):
					var texs: Array = []
					for prop in ["texture", "normal_texture"]:
						if prop in n and n.get(prop) is Texture2D:
							texs.append(n.get(prop))
					for t in texs:
						if t is CanvasTexture:
							texs.append((t as CanvasTexture).diffuse_texture)
							texs.append((t as CanvasTexture).normal_texture)
							continue
						if t != null and not seen.has(t.get_rid()):
							seen[t.get_rid()] = [t.get_width() * t.get_height() * 4, t.resource_path, t.get_width(), t.get_height()]
				var arr: Array = seen.values()
				arr.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
				var tot := 0
				for t in arr: tot += int(t[0])
				print("  scene textures ", arr.size(), " total MB ", tot / 1048576, "  paper baked ", load("res://paper.gd")._baked.size())
				for t in arr.slice(0, 30): print("   ", int(t[0]) / 1048576, " MB ", t[2], "x", t[3], " ", t[1])
			map += 1
			if map >= (Levels.CAMPAIGN[chapter]["maps"] as Array).size():
				chapter += 1
				map = 0
			if not Levels.CAMPAIGN[chapter]["ready"]:
				get_tree().quit()
				return
			_travel(true))
	if _auto == "pause":   # --test=pause: the pause card, then its settings (the controls hidden under it)
		get_tree().create_timer(1.0, true, false, true).timeout.connect(_pause)
		get_tree().create_timer(2.0, true, false, true).timeout.connect(_shot.bind("pause"))
		get_tree().create_timer(2.2, true, false, true).timeout.connect(func() -> void:
			for c in get_children():
				if c.get_script() == PauseScript:
					c._settings())
		get_tree().create_timer(3.0, true, false, true).timeout.connect(_shot.bind("settings"))
		get_tree().create_timer(3.2, true, false, true).timeout.connect(get_tree().quit)
		_auto = "cut:pause"
	elif _auto == "tally":   # --test=tally: a streak's label and the map's tally card with its outro
		get_tree().create_timer(1.0, true, false, true).timeout.connect(func() -> void:
			stats.merge({"kills": 9, "heads": 4, "slow": 6, "air": 3, "best_combo": 4, "score": 3150, "hits": 1, "time": 151.0}, true)
			hud.caption(level["outro"])
			hud.combo(4, 1600, "HEAD SHOT IN THE AIR")
			_rate())
		get_tree().create_timer(1.6, true, false, true).timeout.connect(_shot.bind("tally"))
		get_tree().create_timer(2.6, true, false, true).timeout.connect(get_tree().quit)
		_auto = "cut:tally"
	elif _auto == "card":   # --test=card: the title card between maps
		var l = LoadingScript.new()
		l.chapter = chapter
		l.map = map
		add_child(l)
		get_tree().create_timer(3.0, true, false, true).timeout.connect(_shot.bind("card"))
		get_tree().create_timer(3.2, true, false, true).timeout.connect(get_tree().quit)
		_auto = "cut:card"
	elif _auto == "choice":   # --test=choice: the question at the end of chapter III
		get_tree().create_timer(1.0, true, false, true).timeout.connect(func() -> void:
			var c = ChoiceScript.new()
			c.question = "Briggs is on his knees. He counted every shell. He never once called you a murderer."
			c.options = ["LET HIM LIVE", "FINISH IT"]
			c.done = func(_i: int) -> void: hud.modal(false)
			hud.modal(true)
			add_child(c))
		get_tree().create_timer(2.6, true, false, true).timeout.connect(_shot.bind("choice"))
		get_tree().create_timer(2.6, true, false, true).timeout.connect(func() -> void: hud.caption(["The shooters hadn't gone far. Rain doesn't wash a trail away that fast.", "Neither does whiskey. I'd tried."]))
		get_tree().create_timer(5.0, true, false, true).timeout.connect(func() -> void:
			for c in get_children():
				if c.get_script() == ChoiceScript:
					c.queue_free()
			get_tree().paused = false)
		get_tree().create_timer(6.2, true, false, true).timeout.connect(_shot.bind("caption"))
		get_tree().create_timer(6.5, true, false, true).timeout.connect(get_tree().quit)
		_auto = "cut:choice"
	elif _auto == "page":   # --test=page: the map's notebook page, read
		get_tree().create_timer(1.0, true, false, true).timeout.connect(_read_page)
		get_tree().create_timer(3.0, true, false, true).timeout.connect(_shot.bind("page"))
		get_tree().create_timer(3.6, true, false, true).timeout.connect(get_tree().quit)
		_auto = "cut:page"   # nothing else to run
	elif _auto.begins_with("voice:"):   # --test=voice:prologue plays it at its real pace, logging each line's voice
		_play_cut(_auto.trim_prefix("voice:"), get_tree().quit, false)
	elif _auto.begins_with("cut:"):   # --test=cut:eddie plays that cutscene and saves a picture of each panel
		_play_cut(_auto.trim_prefix("cut:"), get_tree().quit, true)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for n in find_children("*", "Light2D", true, false):
		n.add_to_group("lights")
	for n in find_children("*", "Sprite2D", true, false):
		if n.material is ShaderMaterial:
			n.add_to_group("blurred")
	_collect_stream()
	_warm_text()


## Every font size the fight is lettered in (a mobster's shout, the "!" over his hat, the combo and
## how-to captions, the boss's name, LEVEL N, the gun line) drawn once while the map opens, at 1 %
## opacity for two frames: the letters are rasterised now, not in the first shootout. On the phone the
## first shout of a map cost ~100 ms and 4-5 MB of glyph textures in the middle of the fight. It has to
## be drawn on screen (off screen the renderer skips it and nothing is rasterised). The fonts are held
## for the whole session so their glyphs outlive the scene reload between maps.
static var _kept_fonts := {}
const WARM_TEXT := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?'.,:;-+%&()"
func _warm_text() -> void:
	if not _kept_fonts.has("comic"):
		_kept_fonts["comic"] = load("res://fonts/ComicNeue-BoldItalic.woff")
		var head := FontVariation.new()
		head.base_font = load("res://fonts/Oswald.ttf")
		head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
		_kept_fonts["oswald"] = head
	var comic: Font = _kept_fonts["comic"]
	var oswald: Font = _kept_fonts["oswald"]
	# [font (null = the theme's), size, outline]: as main.gd _say/_mark and hud.gd letter them
	var specs := [[comic, 72, 12], [comic, 110, 14], [comic, 22, 0], [comic, 24, 0], [null, 30, 10], [null, 34, 8],
			[null, 92, 18], [null, 26, 8], [oswald, 64, 0], [oswald, 34, 10]]
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var y := 0.0
	for sp in specs:
		var l := Label.new()
		l.text = WARM_TEXT
		if sp[0] != null:
			l.add_theme_font_override("font", sp[0])
		l.add_theme_font_size_override("font_size", sp[1])
		if sp[2] > 0:
			l.add_theme_constant_override("outline_size", sp[2])
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.position = Vector2(8.0, y)
		l.modulate.a = 0.01
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(l)
		y = fmod(y + 60.0, 600.0)
	# the caption paper the combo and the hints are printed on, at one line's height: filtered once now
	load("res://paper.gd").make("panel", Vector2(220.0, 47.0))
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	layer.queue_free()


func _build_street() -> void:
	if float(level.get("moving", 0.0)) > 0.0:   # the last train: setpieces.gd pours the tunnel past instead
		return
	if level.has("street") and level["street"].size() > 0:
		_build_segments()
		if level.get("washing", false):   # the alley district (QUEUE §12): washing lines from window to window up the plain fronts
			var plain := ["row_house", "apartment", "pawn_house", "factory", "warehouse_row"]
			var top := -1344.0 * 1.52 * SEGMENT_BASE - WALL_LIFT
			for seg in level["street"]:
				if not String(seg[0]) in plain or seg.size() > 2:
					continue
				var x0 := float(seg[1])
				for fl in [[530.0, int(x0 / 97.0) % 2]]:   # (the second floor's windows - in the picture - and which window it starts at)
					var k0: int = fl[1]
					while k0 + 3 < 12:
						var c0 := 294.0 + 236.0 * k0 + 59.0 + 14.0        # the right jamb of one window
						var c1 := 294.0 + 236.0 * (k0 + 3) - 59.0 - 14.0  # the left jamb of the one three along
						var a := Vector2(x0 + c0 * 1.52, top + (fl[0] + 140.0) * 1.52)   # (at the sills: the laundry hangs in the picture, over their heads)
						var b := Vector2(x0 + c1 * 1.52, a.y)
						var mid := (a.x + b.x) * 0.5
						if _room_at(mid) == "" and not _under_front(mid, "") and _front_spans.all(func(sp: Vector2) -> bool: return mid < sp.x - 300.0 or mid > sp.y + 300.0):
							_washing_line(a, b)
						k0 += 4
		if level.get("neon_street", false):   # the night street round the club (QUEUE §12): neon signs on brackets over the doors
			var signs := [["hotel", Color(1.0, 0.22, 0.16)], ["bar", Color(0.6, 0.8, 1.0)], ["dancing", Color(1.0, 0.42, 0.8)],
				["cafe", Color(0.35, 1.0, 0.5)], ["liquors", Color(1.0, 0.7, 0.3)]]
			var keep := _sign_scale
			_sign_scale = 0.62
			var sx := 1400.0
			var k := 0
			var halo_tex := _soft_glow()
			while sx < level_end - 600.0:
				var ok := _room_at(sx) == "" and not _under_front(sx, "")
				for sp in _front_spans:
					if sx > sp.x - 300.0 and sx < sp.y + 300.0:
						ok = false
				for seg in level["street"]:   # (the Blue Note's own drawing has its own neon; the dance hall its marquee, the hotel
					# its canopy - user 18. 11. look: a CAFE sign over the dance hall's poster case made no sense)
					if String(seg[0]) in ["bluenote_row", "dance_hall", "hotel_front"] and sx > float(seg[1]) - 200.0 and sx < float(seg[1]) + 3168.0 * 1.52 + 200.0:
						ok = false
				if ok:
					var nm: String = signs[k % signs.size()][0]
					_sign_scale = 0.46 if nm in ["hotel", "liquors"] else 0.6   # (the tall ones smaller: their top stays in the picture)
					var tex: Texture2D = load("res://art/props/sign_%s.png" % nm)
					var size := tex.get_size() * _sign_scale
					var tl := Vector2(sx, -650.0 - size.y)
					var base := Sprite2D.new()   # the enamel box and its bracket, lit by the night like the wall
					base.texture = tex
					base.centered = false
					base.scale = Vector2.ONE * _sign_scale
					base.position = tl
					base.z_index = -9
					base.modulate = Color(0.78, 0.78, 0.78)   # (the painted tubes are bright already: the box at night tone)
					add_child(base)
					_add_sign("res://art/props/sign_%s_glow.png" % nm, tl, signs[k % signs.size()][1], "buzz" if k % 3 == 1 else "steady", halo_tex, false, 0.25)
					if not neons.is_empty() and neons[neons.size() - 1]["light"] != null:
						(neons[neons.size() - 1]["light"] as PointLight2D).energy *= 0.55   # (a soft wash on the wall, not a blot)
					k += 1
					sx += 1500.0 + float((k * 397) % 700)
				else:
					sx += 300.0
			_sign_scale = keep
		if level.get("steam", false) and not level.get("under", false):   # the steam district (QUEUE §12): a grate every block, each breathing
			var gx := 700.0
			while gx < level_end - 300.0:
				var free := _room_at(gx) == "" and not _under_front(gx, "")
				for sp in _front_spans:
					if gx > sp.x - 200.0 and gx < sp.y + 200.0:
						free = false
				if free and manholes.all(func(m: float) -> bool: return absf(m - gx) > 900.0):
					_manhole(gx, Color.WHITE * SEGMENT_MOON)
					atmo.add_steam(self, Vector2(gx, -20.0))
				gx += 1700.0
		for th in level.get("things", []):   # free-standing things to shoot (gen/levels.py Chunk.thing), toned like the drawing behind
			var like: Sprite2D = null
			for fc in _facades:
				if float(th[1]) >= float(fc[0]) and float(th[1]) < float(fc[1]):
					like = fc[2]
			props.place(String(th[0]), float(th[1]), null if level.has("city") else like)   # (the city: the far drawings are blurred)
		return
	var wall_tex: Texture2D = load("res://art/bg/wall2.png")
	var wall_n: Texture2D = load("res://art/bg/wall2_n.png")
	var lit_tex: Texture2D = load("res://art/bg/wall2_lit.png")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo_tex := _soft_glow()
	var cone_tex: Texture2D = load("res://art/light_cone_soft.png")
	var wall_w := wall_tex.get_width() * WALL_SCALE
	for i in range(-1, int(ceil((level_end + 2500.0) / wall_w)) + 1):   # copies of the street to past the end of the level
		var origin := Vector2(i * wall_w - wall_w * 0.5, -wall_tex.get_height() * WALL_SCALE - WALL_LIFT)
		var tex := CanvasTexture.new()   # the normal map lets lamplight rake across the brickwork
		tex.diffuse_texture = wall_tex
		tex.normal_texture = wall_n
		var w := Sprite2D.new()
		w.texture = tex
		w.centered = false
		w.scale = Vector2.ONE * WALL_SCALE
		w.position = origin
		w.z_index = -10
		w.material = atmo.blur_material(1.4)   # the wall sits a step behind the action: a touch soft
		add_child(w)
		atmo.add_mist(self, origin.x, wall_w, -WALL_LIFT, _undo_night(0.8))
		atmo.add_steam(self, Vector2(origin.x + 700.0 * WALL_SCALE, -20.0))
		atmo.add_steam(self, Vector2(origin.x + 2300.0 * WALL_SCALE, -20.0))
		# windows with a light on behind them. CanvasModulate darkens every item, unshaded or not,
		# so their colour is pushed up by the inverse of the night to come out at full strength.
		var glow := Sprite2D.new()
		glow.texture = lit_tex
		glow.centered = false
		glow.scale = Vector2.ONE * WALL_SCALE
		glow.position = origin
		glow.material = unshaded
		glow.modulate = _undo_night(1.0)
		glow.z_index = -9
		add_child(glow)
		for n in NEONS:
			_add_neon(n[0], origin + (n[1] as Vector2) * WALL_SCALE, n[2], unshaded)
			var glint := Sprite2D.new()   # and the neon's colour on the wet stone below it
			glint.texture = halo_tex
			glint.scale = Vector2(1.2, 0.14)
			glint.position = Vector2(origin.x + (n[1] as Vector2).x * WALL_SCALE, -30.0)
			glint.material = additive
			glint.modulate = _undo_night(0.22) * (n[2] as Color)
			glint.z_index = -7
			add_child(glint)
		for px in LAMPS_PX:
			var at: Vector2 = origin + (px as Vector2) * WALL_SCALE
			if _room_at(at.x) != "":
				continue
			lamps.append(at)
			var rec := {"nodes": [], "light": null, "on": true}
			lamp_info.append(rec)
			rec["hum"] = sfx.add_loop("lamp_hum", at.x, -26.0, 450.0, at.y)
			var fix := Sprite2D.new()   # the lamp itself, hung on the wall
			fix.texture = load("res://art/props/lamp_wall.png")
			fix.centered = false
			fix.scale = Vector2.ONE * 0.2
			fix.offset = -LAMP_BULB
			fix.position = at
			fix.z_index = -7
			add_child(fix)
			var beam := Sprite2D.new()   # the cone of lamplight itself, visible in the rain
			beam.texture = cone_tex
			beam.scale = Vector2.ONE * 1.35
			beam.position = at + Vector2(0.0, 256.0 * 1.35)
			beam.material = additive
			beam.modulate = Color(0.0, 0.0, 0.0)   # switched off: the plain lamp glow read better
			if _cones:
				beam.texture = load("res://art/light_cone_ink.png")
				beam.modulate = _undo_night(0.22) * LAMP_COLOR
			beam.z_index = -6
			add_child(beam)
			rec["nodes"].append(beam)
			var halo := Sprite2D.new()   # a small warm glow right at the bulb, nothing more
			halo.texture = halo_tex
			halo.scale = Vector2.ONE * 1.0   # tight round the glass: a wide soft disc reads as a blob, not light
			halo.position = at + Vector2(0.0, -8.0)
			halo.material = additive
			halo.modulate = _undo_night(0.4) * Color(1.0, 0.68, 0.32)
			halo.z_index = -6
			add_child(halo)
			rec["nodes"].append(halo)
			for wet_scale in [Vector2(1.7, 0.13), Vector2(0.55, 0.3)]:   # the lamp mirrored in the wet pavement
				var wet := Sprite2D.new()
				wet.texture = halo_tex
				wet.scale = wet_scale
				wet.position = Vector2(at.x, -30.0)
				wet.material = additive
				wet.modulate = _undo_night(0.2) * Color(1.0, 0.72, 0.4)
				wet.z_index = -7
				add_child(wet)
				rec["nodes"].append(wet)
			var bulb := Sprite2D.new()   # the glass glows
			bulb.texture = load("res://art/light_blob.png")
			bulb.scale = Vector2.ONE * 0.11
			bulb.position = at + Vector2(0.0, -8.0)
			bulb.material = unshaded
			bulb.modulate = _undo_night(0.8) * Color(1.0, 0.85, 0.6)
			bulb.z_index = -6
			add_child(bulb)
			rec["nodes"].append(bulb)
		for wi in WINDOW_LIGHTS:
			var rr: Rect2 = WINDOWS_PX[wi]
			_add_window_light(origin + (rr.position + rr.size * Vector2(0.5, 1.0)) * WALL_SCALE, rr.size.x * WALL_SCALE)
		_pavement(origin.x, wall_w)


## Where the wall lamps hang on each drawn street segment (fractions of its width), where a facade stands at that height.
# The lamps of each street drawing, in its pixels: [x, y of the bulb, kind(, mirrored)].
# "painted": the drawing already has the lamp; only its light is added. The others hang a drawn lamp
# (art/props/lamp_<kind>.png, art_src 141) where a real one would be: over a shop sign, over a door,
# on bare wall between windows; never on a window, a fire escape or a sign.
const SEGMENT_LIGHTS := {
	# the interiors' fronts (17. 11.): a lamp over each street door - a gooseneck over the shop and warehouse doors,
	# the club's own painted lamp by its door, a lantern on a stoop's pediment
	"front_laundry": [[696, 812, "goose"]], "front_laundry_l": [[696, 812, "goose"]], "front_warehouse": [[795, 760, "goose"], [2373, 760, "goose", true]],
	"front_club": [[630, 930, "painted"]], "front_club_l": [[630, 930, "painted"]], "subway_entrance": [[1272, 690, "painted"], [1884, 690, "painted"]], "front_tenement": [[870, 760, "goose"], [2305, 760, "goose", true]],
	"laundry": [[2110, 748, "painted"], [455, 735, "goose"], [985, 735, "goose", true]],
	"bluenote": [[1262, 880, "painted"], [284, 852, "lantern"], [2877, 833, "goose", true]],
	"alley": [[507, 908, "painted"], [2034, 766, "goose"], [2365, 766, "goose", true]],
	"warehouse": [[435, 568, "goose"], [1003, 568, "goose", true]],
	"subway": [[185, 796, "painted"], [307, 812, "painted"], [670, 796, "painted"], [874, 748, "goose"], [1166, 748, "goose", true], [1535, 800, "cage"]],
	"church": [[2298, 948, "painted"]],
	"market": [[247, 779, "goose"], [513, 779, "goose", true], [797, 779, "goose"]],
	"deadend": [[361, 735, "painted"], [1291, 795, "cage"]],
	"pier17": [[2939, 891, "painted"], [2399, 862, "cage"]],
	"cranes": [[1991, 827, "painted"], [2939, 884, "painted"]],
	"shipping": [[1574, 777, "painted"], [550, 895, "cage"], [1005, 895, "cage"], [2048, 815, "goose"]],
	"quay": [[2095, 429, "painted"]],
	"harbor": [[1071, 828, "cage"]],
	"platform": [[1583, 372, "painted"], [2892, 305, "painted"]],
	"tunnel": [[997, 559, "painted"], [1126, 446, "painted"], [1716, 408, "painted"], [2357, 398, "painted"], [2986, 389, "painted"]],
}
const LAMP_KINDS := {   # the drawn lamps: where the bulb is on the drawing, and how big they hang
	"goose": [Vector2(351, 500), 0.24], "cage": [Vector2(256, 310), 0.2], "lantern": [Vector2(176, 241), 0.24]}
# the signs that light up on each drawing: top-left of the glow picture (pixels of the drawing),
# colour, and how it burns: steady, buzz (now and then a stutter) or dying (out as often as on)
const SEGMENT_NEONS := {
	"bluenote_row": [[Vector2(1545 - 24, 190 - 24), Color(0.45, 0.75, 1.0), "buzz", false, 0.3]],   # (neon_mask pads 24; the painted tubes are already bright: a light touch)
	"bluenote": [[Vector2(678, 426), Color(1.0, 0.22, 0.18), "buzz"], [Vector2(363, 735), Color(0.42, 0.5, 0.62), "steady"]],
	"warehouse": [[Vector2(2150, 758), Color(1.0, 0.2, 0.2), "dying"]],
	"subway": [[Vector2(115, 728), Color(1.0, 0.8, 0.5), "steady"], [Vector2(591, 742), Color(1.0, 0.8, 0.5), "steady"]],
	"church": [[Vector2(2114, 493), Color(1.0, 0.28, 0.22), "buzz"], [Vector2(1865, 23), Color(1.0, 0.85, 0.6), "steady", true]],
	"market": [[Vector2(1124, 49), Color(1.0, 0.7, 0.32), "steady"], [Vector2(942, 695), Color(1.0, 0.8, 0.45), "buzz"]],
	"deadend": [[Vector2(1580, 587), Color(1.0, 0.25, 0.25), "dying"]],
}
var neons: Array = []
const NEON_LIGHT := 0.35   # the colour a sign throws on figures near it; the drawings already carry their own glow
var flocks: Array = []   # pigeons on the pavement: {birds: [{node, state, t, vel, frame}], scared}
const BIRD_FLAP := ["up1", "glide", "up2", "flat", "up3", "glide"]
var _bird_tex := {}
var moonlight: DirectionalLight2D   # stronger up on the roofs, under the open sky   # {nodes, light, mode, next, on}
# Where each drawing looks deep into the city (an alley, a street running away, an arch onto the
# harbour), as fractions of the picture. That part is drawn again over the facade and slides against
# it as the camera moves, most in the middle and not at all at its edges: the far end of the view
# moves slower than the wall, so it reads as depth. Blood does not splash onto these.
const SEGMENT_DEEP := {
	"subway_entrance": [Rect2(0.445, 0.6, 0.113, 0.33)],
	"alley_mouth": [Rect2(0.425, 0.22, 0.155, 0.71)],
	"alley": [Rect2(0.465, 0.22, 0.11, 0.64)], "bluenote": [Rect2(0.665, 0.3, 0.16, 0.38)],
	"warehouse": [Rect2(0.45, 0.32, 0.2, 0.56)], "laundry": [Rect2(0.455, 0.32, 0.1, 0.54)],
	"subway": [Rect2(0.5, 0.25, 0.095, 0.63)], "church": [Rect2(0.432, 0.4, 0.125, 0.4)],
	"market": [Rect2(0.54, 0.42, 0.13, 0.46)], "deadend": [Rect2(0.485, 0.4, 0.07, 0.46)],
	"pier17": [Rect2(0.4699, 0.25, 0.2506, 0.63)], "cranes": [Rect2(0.4385, 0.42, 0.1984, 0.48)], "shipping": [Rect2(0.4908, 0.3, 0.0783, 0.6)], "quay": [Rect2(0.1671, 0.52, 0.1462, 0.34)], "harbor": [Rect2(0.71, 0.4, 0.2506, 0.46)],
	"platform": [Rect2(0.1044, 0.31, 0.1357, 0.38)], "tunnel": [Rect2(0.8249, 0.33, 0.1253, 0.38)], "tunnel_lo": [Rect2(0.8249, 0.33, 0.1253, 0.38)], "yard": [Rect2(0.4908, 0.45, 0.1357, 0.3)],
}
const CRANE_CUT := Rect2(0.3863, 0.2, 0.0783, 0.255)   # the hanging crate taken out of the crane yard drawing (setpieces.gd)
var deeps: Array = []   # {world, center, art}: the deep openings in the street drawings (they stand still, rule 24)
var _deep_rects: Array[Rect2] = []
var _facades: Array = []   # [x0, x1, sprite] of each street drawing (a free-standing thing takes the tone of the one behind it)
var _stain_hosts: Array = []   # [x0, x1, node]: the masks blood on each drawing is clipped to   # the same in world space, for the blood
const SEGMENT_TRIM := {"alley": 134.0, "bluenote": 134.0, "warehouse": 133.0, "laundry": 133.0, "subway": 53.0, "church": 58.0, "market": 58.0, "deadend": 58.0,
		"pier17": 132.0, "cranes": 132.0, "shipping": 132.0, "quay": 132.0, "harbor": 132.0, "sheds": 112.0,
		"platform": 132.0, "tunnel": 132.0, "yard": 132.0, "station14": 132.0,
		"bowery": 132.0, "walkway": 132.0, "pump": 132.0, "tunnel_lo": 132.0, "signal": 132.0, "arches": 132.0}
# evens out how light each drawing came out, so neighbours do not jump in brightness
const SEGMENT_GAIN := {"front_club_l": 1.3, "front_club_mid": 1.3, "front_club_r": 1.3, "front_laundry": 1.3, "front_laundry_l": 1.3, "front_laundry_mid": 1.18, "front_laundry_r": 1.3, "front_warehouse": 1.35, "front_club": 1.3, "front_tenement": 1.3, "front_yard": 1.3,   # (the fronts: to their neighbours' tone, by eye 17. 11.)
	"alley": 0.92, "bluenote": 0.98, "warehouse": 0.9, "laundry": 1.02, "subway": 1.07, "church": 1.0, "market": 1.05, "deadend": 1.1,
		"pier17": 0.86, "cranes": 0.91, "shipping": 0.96, "quay": 0.91, "harbor": 0.86,
		"platform": 0.95, "tunnel": 1.12, "yard": 0.85, "station14": 0.9,
		"bowery": 0.92, "walkway": 1.0, "pump": 0.95, "tunnel_lo": 1.12, "signal": 1.0, "arches": 1.0}
# A drawing whose doors and bins came out too big for a man is shown smaller (gen/levels.py SEG_SIZE).
# variants of a kit (gen/levels.py KIT, art_src 164-168): their own picture, the kit's everything else
const SEGMENT_KIT := {"walkway_b": "walkway", "signal_b": "signal", "arches_b": "arches", "tunnel_lo_b": "tunnel_lo",
	"yard_b": "yard", "tunnel_b": "tunnel", "sheds_b": "sheds", "sheds_c": "sheds", "sheds_d": "sheds", "pier17_b": "pier17", "shipping_b": "shipping", "quay_b": "quay",
	"deck_a": "sheds", "deck_b": "sheds", "deck_c": "sheds",   # (QUEUE §18, 21. 11.) the Santa Lucia's deck
	"laundry_b": "laundry", "alley_b": "alley", "alley_fire": "alley", "warehouse_b": "warehouse", "warehouse_c": "warehouse", "church_b": "church", "subway_b": "subway", "market_b": "market", "market_c": "market", "yard_c": "yard", "tunnel_c": "tunnel",
	"fire_d": "fire_a", "fire_e": "fire_b", "fire_f": "fire_c", "fire_g": "fire_a"}
const SEGMENT_SIZE := {"alley_mouth": 0.8, "market_row": 0.8, "church_row": 0.8, "subway_entrance": 0.8, "warehouse_row": 0.8, "bluenote_row": 0.8, "row_house": 0.8, "front_yard": 0.8, "apartment": 0.8, "factory": 0.8, "pawn_house": 0.8, "diner_house": 0.8, "alley_wash": 0.8, "stable_row": 0.8, "rear_walkup": 0.8, "el_garage": 0.8, "rooming_house": 0.8, "boiler_works": 0.8, "machine_shop": 0.8, "brownstones": 0.8, "bay_tenement": 0.8, "hotel_front": 0.8, "dance_hall": 0.8, "front_club_l": 0.8, "front_club_mid": 0.8, "front_club_r": 0.8, "front_laundry": 0.8, "front_laundry_l": 0.8, "front_laundry_mid": 0.8, "front_laundry_r": 0.8, "front_warehouse": 0.8, "front_club": 0.8, "front_tenement": 0.8, "hk_tailor": 0.8, "hk_grocery": 0.8, "hk_saloon": 0.8, "hk_laundry": 0.8, "deadend": 0.8, "tenrow_a": 0.675, "tenrow_b": 0.675, "tenrow_c": 0.675, "tenrow_d": 0.675, "station14": 0.52, "walkway": 0.52, "bowery": 0.52, "tunnel_lo": 0.52,
	"signal": 0.52, "arches": 0.52, "sheds": 0.55, "fire_a": 0.605, "fire_b": 0.605, "fire_c": 0.605}
# A drawing whose floor runs into the depth: where on it a man's feet go, as a share of its height (the
# street drawings stand at the back of the pavement at SEGMENT_BASE instead).
const SEGMENT_FLOOR := {"fire_a": 0.905, "fire_b": 0.905, "fire_c": 0.905}
var _sign_scale := WALL_SCALE
const SEC_STAND_LEFT := 1800.0                  # stand-in hallway (art/rooms/tenement.png): the left end, up to the downpipe
const SEC_STAND_CORE := Vector2(740.0, 1800.0)   # its middle, repeated: from past 3A to the downpipe (no end wall in it)
const SEC_STAND_WALL := Vector2(740.0, 990.0)    # bare wallpaper between 3A and 3B
const SEC_STAND_STAIRS := Vector2(1800.0, 2240.0)   # its stairs in the back wall (gen/levels.py SEC_DOOR_*)
const SEC_STAND_RIGHT := 1800.0                 # its far end from the downpipe: stairs, 3C, the window wall
const SEC_DISSOLVE := 0.6  # s: the facade dissolving from the door when he steps in (story doc, tab "Řez domem a kamera")
const SEC_DIM := 0.38      # a storey of a building in cross-section he is not on: sunk back, still readable
const ROOM_BASE := 0.95     # an interior's painting under the night grade, before its lamps' pools
const SEGMENT_MOON := 1.6   # how much brighter than the bare night the drawn streets are kept
const SEGMENT_BASE := 0.92
const GROUND_STOREY := -900.0   # above this height a street room is not where he is (a roof over it)
const ROOM_SCALE := 0.75   # interiors: see _build_room
const ROOM_SCALES := {"laundry": 0.8523, "club": 0.8523}   # (17. 11.: the industrial laundry hall, drums taller than a man)
# where steam bursts out of a drawn pipe in a room (fractions of the drawing): mapfx, while he is in there
const ROOM_VENTS := {"laundry": [Vector2(0.328, 0.235), Vector2(0.436, 0.455), Vector2(0.975, 0.56)]}
# The big laundry (QUEUE §14, user 18. 11.): its drawings one after another [picture, from px, to px, catwalk layer]
# (= gen/levels.py LAUNDRY_PARTS; cut on painted iron columns; gen/laundry_layers.py cuts the layers)
const ROOM_PARTS := {"laundry": [["laundry", 0.0, 2880.0, ""], ["laundry_mid", 40.0, 3100.0, "laundry_mid_catwalk"],
	["laundry_end", 790.0, 3168.0, "laundry_end_catwalk"]],
	# the big Blue Note (user 18. 11.): the bar room and its stairs, the dance hall's gallery, the stage (= gen/levels.py CLUB_PARTS)
	"club": [["club_bar", 0.0, 3050.0, "club_bar_gallery"], ["club_hall", 0.0, 3168.0, "club_hall_gallery"], ["club", 1765.0, 3168.0, ""]],
	# below decks on the Santa Lucia (QUEUE §18, 21. 11.; = gen/levels.py BELOW_PARTS): the hold, the engine room, the passage
	"hold": [["hold", 0.0, 3088.0, ""], ["engine", 0.0, 3168.0, ""], ["tween", 0.0, 3168.0, ""]]}
const CHANDELIER_BOX := Rect2(1418.0, 0.0, 307.0, 463.0)   # where gen/club_layers.py cut the chandelier from the hall (px)
const ROOM_PART_BULBS := {   # [x, y, colour, size] on each part's picture, at the glass
	"engine": [[0.109, 0.35, "warm", "small"], [0.616, 0.43, "warm", "small"], [0.69, 0.145, "warm", "small"]],
	"tween": [[0.26, 0.355, "warm", "small"], [0.80, 0.36, "warm", "small"]],
	"laundry_mid": [[0.240, 0.198, "warm", "big"], [0.776, 0.198, "warm", "big"]],
	"laundry_end": [[0.647, 0.236, "warm", "big"], [0.584, 0.585, "warm", "small"], [0.931, 0.193, "warm", "big"]],
	"club_bar": [[0.033, 0.397, "warm", "small"], [0.369, 0.44, "warm", "small"], [0.629, 0.44, "warm", "small"],
		[0.4, 0.38, "warm", "small"], [0.491, 0.38, "warm", "small"], [0.594, 0.38, "warm", "small"]],
	"club_hall": [[0.18, 0.352, "warm", "small"], [0.348, 0.354, "warm", "small"], [0.676, 0.356, "warm", "small"], [0.831, 0.353, "warm", "small"]]}
const ROOM_PART_VENTS := {"laundry_mid": [Vector2(0.316, 0.469), Vector2(0.773, 0.461)]}   # the boilers' valves
var room_vents: Array = []   # [room x0, x1, world point]: every interior's painted steam pipes (mapfx _tick_room_vents)
const ROOM_ZOOM := 0.58    # indoors the camera comes in closer: a room is small, the people in it are not
var _veils: Array = []   # [x0, x1, node]: the dark over each interior seen from afar
var _room_tops: Array = []   # [x0, x1, y of the ceiling] of each interior   # the facades meet the pavement this far down each drawing


## The street kit's things to play with: props.gd (behaviour) reading kit.gd (gen/kit.py: what is where).
var props: Node2D
const KitData = preload("res://kit.gd")   # (gen/kit.py: the edge types of the street drawings)


func _build_segments() -> void:
	props = preload("res://props.gd").new()
	props.game = self
	add_child(props)
	pass   # (seam shades tried 16. 11.: over open sky they read as a black pole - the street order fixes the joins instead)
	var halo_tex := _soft_glow()
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# interiors' building fronts (gen/levels.py place_fronts): laid over the street as it is, a layer above the drawings
	# under them; what those drawings have in front of the front's span (lamps, signs, steam) is left out
	_front_spans.clear()
	for seg in level["street"]:
		if String(seg[0]).begins_with("front_"):
			var fw: float = float(KitData.PIECES.get(String(seg[0]), {}).get("w", 3168.0)) * WALL_SCALE * float(SEGMENT_SIZE.get(String(seg[0]), 1.0))
			_front_spans.append(Vector2(float(seg[1]), float(seg[1]) + fw))
	var built := {}
	for seg in level["street"]:
		if built.has("%s@%s" % [seg[0], seg[1]]):
			continue   # (a drawing cut in two by a front: its two parts are the one drawing, under the front)
		built["%s@%s" % [seg[0], seg[1]]] = true
		var art := String(seg[0])   # the picture; a variant (SEGMENT_KIT) is its kit in everything else
		var seg_name := String(SEGMENT_KIT.get(art, art))
		var ws: float = WALL_SCALE * float(SEGMENT_SIZE.get(seg_name, 1.0))
		_sign_scale = ws
		var x0 := float(seg[1])
		var diffuse: Texture2D = BigTex.get_tex("res://art/street/" + art + ".png")
		var w := Sprite2D.new()   # no normal map: lamplight falls on the drawing as it is, like the moonlit wash
		w.texture = diffuse
		w.centered = false
		# the dark frame Gemini draws down each picture's left edge is left out, and the rest stretched a
		# few per cent to fill the same width, so neighbouring drawings meet building to building
		var trim: float = SEGMENT_TRIM.get(seg_name, 0.0)
		var sx := diffuse.get_width() / (diffuse.get_width() - trim)
		w.region_enabled = true
		w.region_rect = Rect2(trim, 0.0, diffuse.get_width() - trim, diffuse.get_height())
		w.scale = Vector2(ws * sx, ws)
		var seg_w := diffuse.get_width() * ws
		if level.has("city"):   # (rule 31) the modular city's fronts stand on the back of the pavement: of the drawings only
			_pavement(x0, seg_w)  # their slabs here; the drawings themselves are the city far behind, over the roofs
			w.scale *= CITY_FAR_SCALE
			w.z_index = -25
			w.material = atmo.blur_material(2.2)
			w.modulate = Color(CITY_FAR_TONE, CITY_FAR_TONE, CITY_FAR_TONE * 1.06, 1.0)
			w.light_mask = 0
			add_child(w)
			_city_far.append([w, x0, -diffuse.get_height() * ws * SEGMENT_BASE - WALL_LIFT])
			continue
		w.position = Vector2(x0, -diffuse.get_height() * ws * SEGMENT_BASE - WALL_LIFT)
		var floored: bool = SEGMENT_FLOOR.has(seg_name)
		if floored:   # its own floor under his feet: no pavement in front of it
			w.position.y = -diffuse.get_height() * ws * float(SEGMENT_FLOOR[seg_name])
		w.z_index = -6 if art.begins_with("front_") else -10   # (a front over the drawings, their lamps and glow under it)
		if art.begins_with("front_") and not floored:
			# (user 17. 11.: "suddenly a completely different pavement") a front stops at the back of the pavement: the
			# street's own slabs (_pavement, under the front) run on in front of it like everywhere else
			var foot_row := (-WALL_LIFT - 4.0 - w.position.y) / ws
			w.region_rect.size.y = foot_row
		w.material = atmo.blur_material(1.4)
		w.modulate = Color.WHITE * SEGMENT_MOON * float(SEGMENT_GAIN.get(seg_name, 1.0)) * (BG_DIM if LOOK2 else 1.0)   # a moonlit wash, so the drawing reads between the lamps
		add_child(w)
		props.build(art, w, ws, sx, trim)   # (the kit's things: once the drawing stands where it goes)
		_facades.append([x0, x0 + diffuse.get_width() * ws, w])
		if level.get("under", false) and float(SEGMENT_SIZE.get(seg_name, 1.0)) < 0.6:
			# a subway drawing at a man's scale is lower than the screen: its vault goes on up, the top of
			# the drawing mirrored over it and sinking into the dark, so no edge shows when he jumps
			var up := Sprite2D.new()
			up.texture = diffuse
			up.centered = false
			up.region_enabled = true
			var band := diffuse.get_height() * 0.3
			up.region_rect = Rect2(trim, 0.0, diffuse.get_width() - trim, band)
			up.flip_v = true
			up.scale = w.scale
			up.position = w.position - Vector2(0.0, band * ws)
			up.z_index = -10
			up.material = w.material
			up.modulate = w.modulate * Color(0.45, 0.45, 0.45)
			add_child(up)
		for r in SEGMENT_DEEP.get(art, []):   # (a variant's picture is its own: deep views, fires, signs and lamps by `art`)
			_add_deep(diffuse, w, r as Rect2, trim, art)
		var glow := Sprite2D.new()   # its lit windows and signs, pushed through the night at full strength
		glow.texture = BigTex.get_tex("res://art/street/" + art + "_lit.png")
		glow.centered = false
		glow.region_enabled = true   # the glow layer is stored at half size
		glow.region_rect = Rect2(trim * 0.5, 0.0, glow.texture.get_width() - trim * 0.5, glow.texture.get_height())
		glow.scale = Vector2(ws * 2.0 * sx, ws * 2.0)
		glow.position = w.position
		if art.begins_with("front_") and not floored:
			glow.region_rect.size.y = w.region_rect.size.y * 0.5
		glow.material = additive
		glow.modulate = _undo_night(0.55)   # added on top of the drawing: big lit shopfronts would burn out at more
		glow.z_index = -5 if art.begins_with("front_") else -9   # (a front's own lit windows over the front)
		add_child(glow)
		var host := Sprite2D.new()   # blood lands only on what is solid in the drawing: see _stain_host
		host.texture = BigTex.get_tex("res://art/street/" + art + "_solid.png")
		host.centered = false
		host.region_enabled = true
		host.region_rect = Rect2(trim * 0.5, 0.0, host.texture.get_width() - trim * 0.5, host.texture.get_height())
		host.scale = glow.scale
		host.position = w.position
		host.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		host.z_index = -5 if art.begins_with("front_") else -9
		host.light_mask = 0
		add_child(host)
		_stain_hosts.append([w.position.x, w.position.x + seg_w, host])
		if floored:
			_rect(Rect2(x0, w.position.y + diffuse.get_height() * ws - 2.0, seg_w, 900.0), Color(0.04, 0.03, 0.03))
			if art.begins_with("fire"):
				_fire_life(w, glow, art, ws)
		else:
			atmo.add_mist(self, x0, seg_w, -WALL_LIFT, _undo_night(0.8))
			var mh := x0 + seg_w * 0.45
			var piece: Dictionary = KitData.PIECES.get(art, {})
			for c in piece.get("clear", []):   # never in front of a kit piece's door or gate: the steam would hide it
				var ca: float = x0 + float(c[0]) * ws - 250.0
				var cb: float = x0 + float(c[1]) * ws + 250.0
				if mh > ca and mh < cb:
					mh = ca if mh - ca < cb - mh else cb
			if not _under_front(mh, art):
				_manhole(mh, w.modulate)   # (the steam comes out of something: knowledge rule 22)
				atmo.add_steam(self, Vector2(mh, -20.0))
				sfx.add_loop("steam", mh, -20.0, 600.0, -20.0)
		var signs: Array = SEGMENT_NEONS.get(art, [])
		for k in signs.size():
			var p0: Vector2 = signs[k][0]
			if _under_front(w.position.x + (p0.x - trim) * sx * ws, art):
				continue
			_add_sign("res://art/street/%s_neon%d.png" % [art, k], w.position + Vector2((p0.x - trim) * sx, p0.y) * ws, signs[k][1], String(signs[k][2]), halo_tex, signs[k].size() > 3 and bool(signs[k][3]), float(signs[k][4]) if signs[k].size() > 4 else 1.0)
		for f in SEGMENT_LIGHTS.get(art, []):
			if float(f[0]) < trim:   # cut off with the drawing's trimmed edge
				continue
			var at: Vector2 = w.position + Vector2((float(f[0]) - trim) * sx, float(f[1])) * ws
			if (_room_at(at.x) != "" and not art.begins_with("front_")) or _under_front(at.x, art):   # (a front's lamps hang outside, over its doors)
				continue
			var kind := String(f[2])
			lamps.append(at)
			var rec := {"nodes": [], "light": null, "on": true, "glass": 0.0}
			lamp_info.append(rec)
			rec["hum"] = sfx.add_loop("lamp_hum", at.x, -26.0, 450.0, at.y)
			if kind == "painted":   # the drawing's own lamp: its light only, and a painted lamp can't be shot dark
				rec["fixed"] = true
			else:
				var fix := Sprite2D.new()
				var spec: Array = LAMP_KINDS[kind]
				fix.texture = LowRes.tex("res://art/props/lamp_%s.png" % kind, 0.5)
				fix.centered = false
				fix.scale = Vector2.ONE * float(spec[1])
				fix.flip_h = f.size() > 3 and bool(f[3])
				var bulb_px: Vector2 = spec[0]
				if fix.flip_h:
					bulb_px.x = fix.texture.get_width() - bulb_px.x
				fix.offset = -bulb_px
				fix.position = at
				fix.modulate = Color(0.5, 0.48, 0.46)   # dark wet iron, like the painted ironwork round it
				fix.z_index = -4 if art.begins_with("front_") else -7
				add_child(fix)   # not in rec["nodes"]: shot out, the lamp stays on the wall, dark
			if _cones:   # (comparison) an inked cone of light down from the lamp
				var cone := Sprite2D.new()
				cone.texture = load("res://art/light_cone_ink.png")
				cone.centered = false
				cone.offset = Vector2(-256.0, 0.0)
				cone.scale = Vector2(1.1, 1.5)
				cone.position = at + Vector2(0.0, 6.0)
				cone.material = additive
				cone.modulate = _undo_night(0.22) * LAMP_COLOR
				cone.z_index = -6
				add_child(cone)
				rec["nodes"].append(cone)
			var halo := Sprite2D.new()
			halo.texture = halo_tex
			halo.scale = Vector2.ONE * 1.0   # tight round the glass: a wide soft disc reads as a blob, not light
			halo.position = at + Vector2(0.0, -8.0)
			halo.material = additive
			halo.modulate = _undo_night(0.4) * Color(1.0, 0.68, 0.32)
			halo.z_index = -3 if art.begins_with("front_") else -6
			add_child(halo)
			rec["nodes"].append(halo)
			for wet_scale in [Vector2(1.7, 0.13), Vector2(0.55, 0.3)]:
				var wet := Sprite2D.new()
				wet.texture = halo_tex
				wet.scale = wet_scale
				wet.position = Vector2(at.x, -30.0)
				wet.material = additive
				wet.modulate = _undo_night(0.2) * Color(1.0, 0.72, 0.4)
				wet.z_index = -4 if art.begins_with("front_") else -7
				add_child(wet)
				rec["nodes"].append(wet)
			if kind == "painted":
				continue
			var bulb := Sprite2D.new()
			bulb.texture = load("res://art/light_blob.png")
			bulb.scale = Vector2.ONE * 0.11
			bulb.position = at + Vector2(0.0, -8.0)
			bulb.material = unshaded
			bulb.modulate = _undo_night(0.8) * Color(1.0, 0.85, 0.6)
			bulb.z_index = -3 if art.begins_with("front_") else -6
			add_child(bulb)
			rec["nodes"].append(bulb)
		if not floored:
			_pavement(x0, seg_w)
		var prev_art: String = String(level["street"][level["street"].find(seg) - 1][0]) if seg != level["street"][0] else ""
		var walls: bool = KitData.EDGES.get(prev_art, ["party_wall", "party_wall"])[1] == "party_wall" and KitData.EDGES.get(art, ["party_wall", "party_wall"])[0] == "party_wall"
		if art.begins_with("front_"):   # its doors: warm light from inside spilling out of the doorway onto the wet stones (you go in here)
			for dpx in KitData.PIECES[art].get("doors", []):
				var dx: float = x0 + float(dpx) * ws
				var dw: float = (230.0 if art == "front_warehouse" else 150.0) * ws * 0.8   # the doorway lit from inside, in its own shape:
				var dh: float = (400.0 if art == "front_warehouse" else 360.0) * ws         # bright at the threshold, fading up the door
				var foot: float = -1344.0 * ws * SEGMENT_BASE - WALL_LIFT + 1250.0 * ws
				var spill := Polygon2D.new()
				spill.polygon = PackedVector2Array([Vector2(dx - dw * 0.5, foot - dh), Vector2(dx + dw * 0.5, foot - dh), Vector2(dx + dw * 0.5, foot), Vector2(dx - dw * 0.5, foot)])
				var warm := _undo_night(0.15) * Color(1.0, 0.76, 0.46)
				spill.vertex_colors = PackedColorArray([Color(warm, 0.0), Color(warm, 0.0), warm, warm])
				spill.material = additive
				spill.z_index = -5
				add_child(spill)
				var pool := Sprite2D.new()   # and its light on the pavement before it
				pool.texture = halo_tex
				pool.position = Vector2(dx, -18.0)
				pool.scale = Vector2(2.2, 0.16)
				pool.material = additive
				pool.modulate = _undo_night(0.2) * Color(1.0, 0.78, 0.5)
				pool.z_index = -5
				add_child(pool)
				var dl := _lamp_light(Vector2(dx, -200.0))   # on whoever stands in it
				dl.energy *= 0.6
				dl.color = Color(1.0, 0.8, 0.55)
		if art.begins_with("front_"):   # a front laid over the street: a firewall pier at both its ends (the drawings under it are cut there)
			for px in [x0, x0 + seg_w]:
				if _front_joint(px):   # (a front in parts, the big laundry's: one building, no pier between its parts)
					continue
				var fp := Sprite2D.new()
				fp.texture = BigTex.get_tex("res://art/street/pier.png")
				fp.centered = false
				fp.scale = Vector2.ONE * ws   # (at the front's own scale, its foot at the back of the pavement: not down over the slabs)
				fp.position = Vector2(px - fp.texture.get_width() * ws * 0.5, -WALL_LIFT - 4.0 - fp.texture.get_height() * ws)
				fp.modulate = Color.WHITE * SEGMENT_MOON * 0.85 * (BG_DIM if LOOK2 else 1.0)
				fp.material = w.material
				fp.z_index = -5
				add_child(fp)
		var behind_escape := false   # (user 22. 11.) behind a house's fire escape its back wall covers the join: no black column up past it
		for c in level["floors"]:
			if String(c[3]) == "fescape" and x0 > float(c[0]) - 50.0 and x0 < float(c[0]) + float(c[2]) + ESC_PIER_HIDE:
				behind_escape = true
		if seg != level["street"][0] and not floored and walls and not _front_joint(x0) and not behind_escape:   # a firewall pier over the join with the drawing before (only between two buildings' walls: never in front of open sky or water)
			var pier := Sprite2D.new()
			pier.texture = BigTex.get_tex("res://art/street/pier.png")
			pier.centered = false
			pier.scale = Vector2.ONE * WALL_SCALE
			pier.position = Vector2(x0 - pier.texture.get_width() * WALL_SCALE * 0.5, -WALL_LIFT - (diffuse.get_height() * SEGMENT_BASE - (diffuse.get_height() - pier.texture.get_height())) * WALL_SCALE)
			pier.modulate = w.modulate * 0.85
			pier.material = w.material
			pier.z_index = -10
			add_child(pier)


## Is x where two parts of one front meet (front_laundry_l | _mid | _r)?
func _front_joint(x: float) -> bool:
	var n := 0
	for seg in level["street"]:
		var art := String(seg[0])
		if not (art.begins_with("front_laundry_") or art.begins_with("front_club_")):
			continue
		var w: float = float(KitData.PIECES[art].get("w", 3168.0)) * WALL_SCALE * float(SEGMENT_SIZE.get(art, 1.0))
		if absf(float(seg[1]) - x) < 2.0 or absf(float(seg[1]) + w - x) < 2.0:
			n += 1
	return n >= 2


## The Blue Note's chandelier (user 18. 11., the big club): its own layer on its chain from the beam, lit, a lamp to the
## aim - a shot drops it: it crashes onto the dance floor and takes down whoever stands under it.
var _chandeliers: Array = []
func _chandelier(at: Vector2, rs: float) -> void:
	var sp := Sprite2D.new()
	sp.texture = load("res://art/rooms/club_chandelier.png")
	sp.centered = false
	sp.scale = Vector2.ONE * rs
	sp.position = at
	sp.light_mask = 0
	sp.modulate = Color.WHITE * ROOM_BASE * 1.08
	sp.z_index = -4
	add_child(sp)
	var glass := at + Vector2(CHANDELIER_BOX.size.x * 0.5, CHANDELIER_BOX.size.y * 0.72) * rs
	var p := _lamp_light(glass)
	lamps.append(glass)
	lamp_info.append({"nodes": [], "light": p, "on": true, "glass": 0.0, "r": 90.0, "chandelier": sp})   # (not in "nodes": an out lamp hides those)
	_chandeliers.append(sp)


func _drop_chandelier(sp: Sprite2D) -> void:
	if sp.has_meta("down"):
		return
	sp.set_meta("down", true)
	var h := sp.texture.get_height() * sp.scale.y
	var land := Vector2(sp.position.x, -h + 30.0)
	var tw := sp.create_tween()
	tw.tween_property(sp, "position", land, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var foot := Vector2(sp.position.x + sp.texture.get_width() * sp.scale.x * 0.5, 0.0)
		_impact(0.12, 0.05)
		_shake = maxf(_shake, 0.5)
		sfx.play("glass", 2.0, foot.x, 0.05)
		_word(["crash", "smash"], foot + Vector2(0.0, -360.0), 0.25)
		for k in 14:
			fx.chip(foot + Vector2(randf_range(-160.0, 160.0), randf_range(-60.0, 0.0)))
		fx.dust(foot, 0.6)
		for e in enemies:
			if e["alive"] and absf(float(e["node"].position.y)) < 10.0 and absf(float(e["node"].position.x) - foot.x) < 230.0:
				_knock_down(e, 700.0 * signf(float(e["node"].position.x) - foot.x + 0.01))
		sp.rotation = 0.06
		sp.z_index = 1   # (in front of the kegs it smashed onto, a wreck on the boards)
		sp.scale.y *= 0.7
		sp.position.y = 24.0 - sp.texture.get_height() * sp.scale.y
		sp.modulate = Color.WHITE * ROOM_BASE * 0.8)


## The way out of a street map (QUEUE §15 E): a drawn doorway at the map's end (gen/levels.py exit_door), lit warm from
## inside like the interiors' doors; when the last man is down it brightens, breathes and a line says where to go.
var _exit_nodes: Array = []
var _exit_told := false
func _build_exit() -> void:
	var x: float = float(level.get("exit", -1.0))
	if x < 0.0:
		return
	var ws := WALL_SCALE * 0.8
	var foot: float = -1344.0 * ws * SEGMENT_BASE - WALL_LIFT + 1250.0 * ws
	var dw := 150.0 * ws * 0.8
	var dh := 360.0 * ws
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var spill := Polygon2D.new()
	spill.polygon = PackedVector2Array([Vector2(x - dw * 0.5, foot - dh), Vector2(x + dw * 0.5, foot - dh), Vector2(x + dw * 0.5, foot), Vector2(x - dw * 0.5, foot)])
	var warm := _undo_night(0.18) * Color(1.0, 0.76, 0.46)
	spill.vertex_colors = PackedColorArray([Color(warm, 0.0), Color(warm, 0.0), warm, warm])
	spill.material = add
	spill.z_index = -4
	add_child(spill)
	var pool := Sprite2D.new()
	pool.texture = _soft_glow()
	pool.position = Vector2(x, -18.0)
	pool.scale = Vector2(2.6, 0.18)
	pool.material = add
	pool.modulate = _undo_night(0.22) * Color(1.0, 0.78, 0.5)
	pool.z_index = -4
	add_child(pool)
	_exit_nodes = [spill, pool]


func _tick_exit(_delta: float) -> void:
	if _exit_nodes.is_empty() or cleared:
		return
	var open := _all_down()
	var k := (0.75 + 0.25 * sin(_time * 3.0)) * 1.8 if open else 1.0
	for n in _exit_nodes:
		(n as CanvasItem).self_modulate = Color(k, k, k, 1.0)
	if open and not _exit_told and absf(level_end - player.position.x) < 4000.0:
		_exit_told = true
		hud.hint("THE DOOR AT THE END OF THE STREET")


## The street drawing at x ("" past the street).
func street_piece_at(x: float) -> String:
	var name := ""
	for seg in level.get("street", []):
		var a := float(seg[1]) + (float(seg[2]) if (seg as Array).size() > 3 else 0.0)
		var w: float = float(KitData.PIECES.get(String(seg[0]), {}).get("w", 3168.0)) * WALL_SCALE * float(SEGMENT_SIZE.get(String(seg[0]), 1.0))
		var b := float(seg[1]) + (float(seg[3]) if (seg as Array).size() > 3 else w)
		if x >= a and x < b:
			name = String(seg[0])   # (a front laid over the street comes later in the list: it wins)
	return name


var _front_spans: Array[Vector2] = []
## Is x under a building front laid over the street (and the thing at x is not the front's own)?
func _under_front(x: float, art: String) -> bool:
	if art.begins_with("front_"):
		return false
	for sp in _front_spans:
		if x > sp.x - 40.0 and x < sp.y + 40.0:
			return true
	return false


## A deep opening in a street drawing (an alley, a passage, a platform's far end). It stands still with its wall
## exactly as painted (user 17. 11., rule 24: the stretch, then the perspective slide were both rejected - no
## shear, no slide, no lift). Kept only so blood never lands in the air over it and the deep test finds it.
func _add_deep(tex: Texture2D, facade: Sprite2D, r: Rect2, trim: float, seg_name := "") -> void:
	var size := Vector2(tex.get_size())
	var px := Rect2(r.position * size, r.size * size)
	var world := Rect2(facade.position + (px.position - Vector2(trim, 0.0)) * facade.scale, px.size * facade.scale)
	_deep_rects.append(world)
	deeps.append({"world": world, "center": world.get_center(), "art": seg_name})


## The drawing under a point, whose solid parts a stain there is clipped to (null: none).
func _stain_host(p: Vector2) -> Node2D:
	for h in _stain_hosts:
		if p.x >= float(h[0]) and p.x < float(h[1]):
			return h[2]
	return null


## Blood only lands on a wall, not in the air over an alley.
func _wall_at(p: Vector2) -> bool:
	for r in _deep_rects:
		if r.grow(-20.0).has_point(p):
			return false
	return true


## A sign on a drawn street that burns in the dark: its strokes glow in their colour, a haze hangs
## round it, it throws coloured light on whoever passes and shines in the wet pavement below.
func _add_sign(path: String, top_left: Vector2, col: Color, mode: String, halo_tex: Texture2D, wash := false, gain := 1.0) -> void:
	var tex: Texture2D = load(path)
	var size := tex.get_size() * _sign_scale
	var mid := top_left + size * 0.5
	if _room_at(mid.x) != "":
		return
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var rec := {"nodes": [], "light": null, "mode": mode, "next": randf_range(0.5, 4.0), "on": true}
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# the tubes: painted over in their own colour (so a red sign reads red, not pink), then a white-hot
	# core added on top. A lamp-lit billboard only gets the added light.
	for layer in ([1] if wash else [0, 1]):
		var glow := Sprite2D.new()
		glow.texture = tex
		glow.centered = false
		glow.position = top_left
		glow.scale = Vector2.ONE * _sign_scale   # (the drawing's own scale: a kit piece is 0.8 of WALL_SCALE)
		glow.material = unshaded if layer == 0 else additive
		glow.modulate = Color(col * gain, 1.0) if layer == 0 else _undo_night((0.35 if wash else 0.22) * gain) * col.lerp(Color.WHITE, 0.55)
		glow.z_index = -9
		add_child(glow)
		rec["nodes"].append(glow)
	var haze := Sprite2D.new()
	haze.texture = halo_tex
	haze.position = mid
	haze.scale = Vector2(size.x, size.y) / 256.0 * 2.2 + Vector2.ONE * 1.2
	haze.material = additive
	haze.modulate = _undo_night(0.07 * gain) * col
	haze.z_index = -8
	add_child(haze)
	rec["nodes"].append(haze)
	var wet := Sprite2D.new()   # its colour smeared on the wet stone
	wet.texture = halo_tex
	wet.position = Vector2(mid.x, -30.0)
	wet.scale = Vector2(maxf(size.x / 256.0 * 2.4, 1.2), 0.14)
	wet.material = additive
	wet.modulate = _undo_night(0.16) * col
	wet.z_index = -7
	add_child(wet)
	rec["nodes"].append(wet)
	var l := PointLight2D.new()
	l.texture = load("res://art/light_blob.png")
	l.texture_scale = clampf(maxf(size.x, size.y) / 256.0 * 2.5, 4.0, 9.0)
	l.position = Vector2(mid.x, maxf(mid.y, -900.0))
	l.color = col
	l.energy = NEON_LIGHT
	l.height = 120.0
	l.range_item_cull_mask = MASK_LIT
	add_child(l)
	rec["light"] = l
	rec["hum"] = sfx.add_loop("neon_hum", mid.x, -16.0, 500.0, mid.y)
	neons.append(rec)


## Neon is never quite steady: a low hum in its brightness, a stutter now and then, and the old
## ones die and catch again.
func _tick_neons(delta: float) -> void:
	for rec in neons:
		rec["next"] = float(rec["next"]) - delta
		var hum := 1.0 + sin(_time * 50.0 + float(rec["next"])) * 0.03
		if rec["next"] <= 0.0:
			match String(rec["mode"]):
				"buzz":
					rec["on"] = not rec["on"]
					rec["next"] = randf_range(0.03, 0.09) if not rec["on"] or randf() < 0.6 else randf_range(3.0, 9.0)
				"dying":
					rec["on"] = not rec["on"]
					if rec["on"]:
						sfx.play("zap", -16.0, rec["light"].position.x, 0.2)
					rec["next"] = randf_range(0.05, 1.4) if not rec["on"] else randf_range(0.08, 2.5)
				_:
					rec["next"] = 99.0
		var k := hum if rec["on"] else 0.0
		rec["hum"]["on"] = rec["on"]
		for n in rec["nodes"]:
			n.self_modulate.a = k
		rec["light"].energy = NEON_LIGHT * k


## Things standing right by the camera, out of focus: bollards, a hydrant, a parked car, a lamp
## whose lantern blooms into a soft disc. Each map deals them in its own order and spacing.
## (22. 11., user: "no black space at the bottom, more work with the foreground") Under the kerb the drawn road (Gemini,
## gen/road.py: wet cobbles, the gutter, a rail, a manhole), mirrored tile by tile; at the very bottom of the picture the
## near pavement, out of focus, on the foreground's own layer: what stands in front stands on it.
const ROAD_SCALE := 1.4           # road_cobbles.png's px in the world (a cobble about a hand and a half of the figure)
const ROAD_TONE := 0.64
const FORE_NEAR_Y := 345.0        # the near pavement's far edge
const FORE_BASE := 395.0          # where the things in front stand on it
const FORE_NEAR_TONE := 0.3
func _build_road() -> void:
	var tex: Texture2D = load("res://art/props/road_cobbles.png")
	var y0 := -WALL_LIFT - 12.0 + 286.0 * SLAB_SCALE - 6.0   # just under the slab's kerb
	var w := tex.get_width() * ROAD_SCALE
	var i := 0
	var x := -6000.0
	while x < level_end + 6000.0:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.flip_h = i % 2 == 1
		s.scale = Vector2.ONE * ROAD_SCALE
		s.position = Vector2(x, y0)
		s.z_index = -8
		s.light_mask = 0
		s.modulate = Color(ROAD_TONE, ROAD_TONE, ROAD_TONE, 1.0)
		add_child(s)
		x += w - 1.0
		i += 1
	var slab: Texture2D = load("res://art/props/slab_sidewalk.png")
	var region := Rect2(SLAB_REGION_X.x, 0.0, SLAB_REGION_X.y - SLAB_REGION_X.x, 112.0)   # its top only: the kerb faces the road
	var soft: Material = atmo.blur_material(3.0)
	var back := Polygon2D.new()   # the pavement on toward the lens
	back.polygon = PackedVector2Array([Vector2(-9000.0, FORE_NEAR_Y + 60.0), Vector2(level_end * 1.4 + 9000.0, FORE_NEAR_Y + 60.0),
			Vector2(level_end * 1.4 + 9000.0, FORE_NEAR_Y + 1600.0), Vector2(-9000.0, FORE_NEAR_Y + 1600.0)])
	back.color = Color(0.1, 0.1, 0.105)
	fore.add_child(back)
	x = -9000.0
	while x < level_end * 1.4 + 9000.0:
		var s := Sprite2D.new()
		s.texture = slab
		s.centered = false
		s.region_enabled = true
		s.region_rect = region
		s.position = Vector2(x, FORE_NEAR_Y)
		s.light_mask = MASK_UNLIT
		s.modulate = Color(FORE_NEAR_TONE, FORE_NEAR_TONE, FORE_NEAR_TONE * 1.05, 1.0)
		s.material = soft
		fore.add_child(s)
		x += region.size.x - 2.0


const FORE_PROPS := {"bollard": 2.0, "hydrant": 2.0, "lamp": 2.0, "railing": 1.0}   # only what stands at a kerb; no cars or crates sliding past the lens
func _scatter_fore() -> void:
	if not level.has("city"):
		return   # (user 17. 11.: hydrant and lamp silhouettes stuck in an empty grey strip in front: nothing stands without a
		# ground of its own - knowledge rule 22. 22. 11.: in the modular city the drawn road and the near pavement are
		# that ground - _build_road.)
	_build_road()
	if level.get("under", false):   # no hydrants and lamp posts down in the subway
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 1000 + map * 17 + 5
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo := _soft_glow()
	var names: Array = FORE_PROPS.keys()
	var weights := PackedFloat32Array(FORE_PROPS.values())
	var last := ""
	var x := -3000.0 + rng.randf_range(0.0, 1500.0)
	while x < level_end * 1.4 + 3000.0:
		var pick: String = names[rng.rand_weighted(weights)]
		if pick == last:
			continue
		last = pick
		var tex: Texture2D = load("res://art/fore/" + pick + ".png")
		var sc := 0.62 * rng.randf_range(0.92, 1.08)
		var f := Sprite2D.new()
		f.texture = tex
		f.centered = false
		f.flip_h = rng.randf() < 0.5 and pick != "sign"
		f.modulate = Color(0.1, 0.1, 0.11)
		f.light_mask = MASK_UNLIT
		f.scale = Vector2.ONE * sc
		f.position = Vector2(x, FORE_BASE - tex.get_height() * sc)
		f.material = atmo.blur_material(5.0)   # nearer than the focus: soft
		fore.add_child(f)
		if pick == "lamp":   # its lantern, out of focus, blooms into a disc of warm light
			var head := f.position + Vector2(210.0, 125.0) * sc
			for k in 2:
				var g := Sprite2D.new()
				g.texture = halo
				g.position = head
				g.scale = Vector2.ONE * (2.6 if k == 0 else 0.9)
				g.material = additive
				g.modulate = _undo_night(0.22 if k == 0 else 0.55) * Color(1.0, 0.7, 0.38)
				fore.add_child(g)
		x += tex.get_width() * sc + rng.randf_range(1500.0, 3600.0)


## Pigeons pecking about on the pavement here and there. The detective walking up, a shot, or
## an explosion sends the whole flock up and over the roofs in a clatter of wings.
## How hard it rains on this map: the chapter's rain, unless the map is under a roof of its own.
func _rain() -> float:
	return float(level.get("rain", Levels.CAMPAIGN[chapter]["rain"]))


func _place_flocks() -> void:
	for n in ["stand", "peck", "walk", "crouch"] + BIRD_FLAP:
		_bird_tex[n] = load("res://art/birds/" + n + ".png")
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 777 + map * 31 + 3
	var x := cam_start + rng.randf_range(1800.0, 3200.0)
	while x < level_end - 800.0:
		var clear := _room_at(x) == ""
		for b in boxes:
			if absf(b.get_center().x - x) < 500.0:
				clear = false
		if clear:
			var flock := {"birds": [], "scared": false}
			for k in rng.randi_range(5, 9):
				var bird := Sprite2D.new()
				bird.texture = _bird_tex["stand"]
				bird.centered = false
				bird.scale = Vector2.ONE * rng.randf_range(0.33, 0.39)
				bird.position = Vector2(x + rng.randf_range(-320.0, 320.0), rng.randf_range(-40.0, -8.0))
				bird.flip_h = rng.randf() < 0.5
				bird.z_index = -2
				bird.modulate = Color(0.95, 0.95, 1.0)
				add_child(bird)
				flock["birds"].append({"node": bird, "state": "idle", "t": rng.randf_range(0.0, 1.5), "vel": Vector2.ZERO, "frame": 0.0})
				_bird_pose(flock["birds"][-1], "stand")
			flocks.append(flock)
			x += rng.randf_range(5500.0, 9500.0)
		else:
			x += 600.0


func _bird_pose(b: Dictionary, pose: String) -> void:
	var n: Sprite2D = b["node"]
	var tex: Texture2D = _bird_tex[pose]
	n.texture = tex
	n.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())   # the node sits at its feet, whatever the pose


func _scare_birds(at: Vector2, radius: float) -> void:
	for flock in flocks:
		if flock["scared"] or flock["birds"].is_empty():
			continue
		var first: Sprite2D = flock["birds"][0]["node"]
		if absf(first.position.x - at.x) > radius:
			continue
		flock["scared"] = true
		sfx.play("flutter", -3.0, first.position.x, 0.1)
		for b in flock["birds"]:
			b["state"] = "startle"
			b["t"] = randf_range(0.0, 0.3)   # not all at once: the nearest go first, the rest follow
			var away := signf(b["node"].position.x - at.x)
			b["vel"] = Vector2((away if away != 0.0 else 1.0) * randf_range(350.0, 750.0), -randf_range(650.0, 1050.0))
			_bird_pose(b, "crouch")


func _tick_birds(delta: float) -> void:
	for flock in flocks:
		if flock["birds"].is_empty():
			continue
		if not flock["scared"]:   # cooing now and then while they peck
			flock["coo"] = float(flock.get("coo", randf_range(1.0, 4.0))) - delta
			if flock["coo"] <= 0.0:
				flock["coo"] = randf_range(2.0, 6.0)
				sfx.play("coo", -10.0, flock["birds"][0]["node"].position.x, 0.12)
		if not flock["scared"] and absf(flock["birds"][0]["node"].position.x - player.position.x) < (700.0 if absf(run) > 500.0 else 330.0) \
				and player.position.y > -200.0:
			_scare_birds(player.position, 2000.0)
		var i: int = flock["birds"].size() - 1
		while i >= 0:
			var b: Dictionary = flock["birds"][i]
			var n: Sprite2D = b["node"]
			b["t"] = float(b["t"]) - delta
			match String(b["state"]):
				"idle":   # peck, look up, take a few steps
					if b["t"] <= 0.0:
						var pose: String = ["stand", "peck", "peck", "walk"][randi() % 4]
						_bird_pose(b, pose)
						if pose == "walk":
							if randf() < 0.3:
								n.flip_h = not n.flip_h
							n.position.x += (-1.0 if n.flip_h else 1.0) * randf_range(10.0, 30.0)
						b["t"] = randf_range(0.3, 1.4)
				"startle":
					if b["t"] <= 0.0:
						b["state"] = "fly"
						n.flip_h = b["vel"].x < 0.0
				"fly":   # beat hard, climb and bank away; the wings slow down with time itself
					var vel: Vector2 = b["vel"]
					vel.y -= 260.0 * delta
					vel.x *= 1.0 + 0.4 * delta
					b["vel"] = vel
					n.position += vel * delta
					b["frame"] = float(b["frame"]) + delta * 15.0
					_bird_pose(b, BIRD_FLAP[int(b["frame"]) % BIRD_FLAP.size()])
					n.rotation = clampf(vel.angle() + (PI if n.flip_h else 0.0), -0.5, 0.5) * 0.4
					if b["t"] < -4.0:
						n.queue_free()
						flock["birds"].remove_at(i)
			i -= 1


## Music that follows the fight, four stems in step (sfx.STEMS: base, lead, tension, fight):
## a quiet street gets the tune; men somewhere ahead who have not seen him yet, the low drone;
## a fight, the drums and brass, harder the more guns are in it; on his last hit the tune drops out
## and the drone comes back under the drums; a boss gets everything; the end of a fight lands on a
## soft chord. Rain is heard only where it falls, and through the walls indoors.
func _tick_music() -> void:
	if _in_cut:   # the cutscene sets its own music and sound
		return
	if level.get("dream", false):
		_tick_dream_sound()
		return
	sfx.melody = "jazz"
	sfx.rain_want = 0.0 if level.get("under", false) else _rain()
	sfx.indoor = move_toward(sfx.indoor, 1.0 if _room_at(player.position.x, player.position.y) != "" else 0.0, get_process_delta_time() * 2.0)
	var near := 0
	var lurking := false
	var boss_on := false
	for e in enemies:
		if not e["alive"] or e["state"] in ["wait", "give"]:
			continue
		var dx: float = absf(e["node"].position.x - player.position.x)
		if e["seen"] and dx < 2300.0:
			near += 1
			boss_on = boss_on or e["boss"]
		elif dx < 3400.0:
			lurking = true
	if near > 0:
		_fight_t = 5.0
	elif _fight_t > 1.2:   # the last one down: the fight lets go quickly
		_fight_t = 1.2
	_fight_t = maxf(0.0, _fight_t - get_process_delta_time())
	if _fight_t > 0.0:
		_was_fight = true
	elif _was_fight:
		_was_fight = false
		if not over:
			sfx.play("resolve", -9.0, INF, 0.0)
	var last := hp <= 1 and diff_step >= 0
	if over:
		sfx.music_want = [-80.0, -80.0, -80.0, -80.0]
	elif boss_on:
		sfx.music_want = [-13.0, -16.0, -20.0, -8.0]
	elif _fight_t > 0.0:
		sfx.music_want = [-14.0, -80.0 if last else -18.0, -15.0 if last else -26.0, -12.0 if near < 3 else -9.0]
	elif lurking:
		sfx.music_want = [-17.0, -80.0, -17.0, -80.0]
	else:
		sfx.music_want = [-18.0, -20.0, -80.0, -80.0]


## The dream's sound: its own piece instead of the jazz (Alon Peretz - Fire and Ice), the whole building
## roaring underneath, and every few seconds it groans, a beam gives, glass bursts, near a fire he can see.
func _tick_dream_sound() -> void:
	if not _dream_music_on:
		_dream_music_on = true
		sfx.melody_from_start("dream_fire")
		sfx.fire_bed(-11.0)
	sfx.melody = "dream_fire"
	sfx.rain_want = 0.0
	var fighting := false
	for e in enemies:
		if e["alive"] and e["seen"] and absf(e["node"].position.x - player.position.x) < 2300.0:
			fighting = true
	# calm keeps the piece on its own; in a fight the tension stem comes in under it
	sfx.music_want = [-80.0, -80.0, -80.0, -80.0] if over else [-80.0, -8.0, -24.0 if fighting else -80.0, -80.0]
	_dream_event_t -= get_process_delta_time()
	if _dream_event_t <= 0.0 and not over and not _dream_fires.is_empty():
		_dream_event_t = randf_range(4.0, 9.0)
		var near: Array = []
		for f in _dream_fires:
			if absf((f as Vector2).x - player.position.x) < 1500.0:
				near.append(f)
		if near.is_empty():
			return
		var at: Vector2 = near.pick_random()
		var what: String = ["collapse", "beams", "beams", "glass", "creak", "wood_break"].pick_random()
		sfx.play(what, -4.0 if what in ["collapse", "beams"] else -8.0, at.x, 0.08)
		if what == "collapse":   # a ceiling coming down: the ground shakes and sparks fly up from it
			_shake = maxf(_shake, 0.08)
			atmo.jolt(0.6)
			for k in 5:
				fx.spark(at + Vector2(randf_range(-160.0, 160.0), randf_range(-260.0, -40.0)))


## In the Catacombs' rising water (mapfx.gd flood) everybody on the floor wades: up to a third slower.
func _wading(y: float) -> float:
	if mapfx == null or mapfx.flood <= 0.0 or y < -40.0:
		return 1.0
	return 1.0 - 0.35 * clampf(mapfx.flood / mapfx.FLOOD_TOP, 0.0, 1.0)


## The sky: clouds drifting, and now and then lightning far off, the thunder a moment later.
func _tick_sky(delta: float) -> void:
	if _sky_mat == null:
		return
	_lightning_t -= delta
	if _lightning_t <= 0.0 and _rain() > 0.0:
		_lightning_t = randf_range(35.0, 90.0)
		var tw := create_tween()   # a double flicker, the second brighter
		tw.tween_property(self, "_flash", 0.6, 0.05)
		tw.tween_property(self, "_flash", 0.1, 0.08)
		tw.tween_property(self, "_flash", 1.0, 0.04)
		tw.tween_property(self, "_flash", 0.0, 0.5)
		get_tree().create_timer(randf_range(1.2, 3.0), false).timeout.connect(func() -> void: sfx.play("thunder", -8.0, INF, 0.15))
	_sky_mat.set_shader_parameter("drift", _time * 0.0025 + cam.position.x * 0.000004)
	_sky_mat.set_shader_parameter("flash", _flash)
	if moonlight:
		moonlight.energy += _flash * 1.4


## Keep the rain on his hat and shoulders where they are this frame; none indoors or lying down.
func _tick_hat_rain() -> void:
	if _hat_rain.is_empty():
		return
	var top: Vector2 = player.head_top()
	var on: bool = _room == "" and player.dive < 0.4 and not over
	_hat_rain[0].global_position = top
	_hat_rain[0].emitting = on
	_hat_rain[1].global_position = player.shoulder_top()
	_hat_rain[1].emitting = on
	_hat_rain[2].global_position = top + Vector2(player.scale.x * 52.0, 22.0)   # the front of the brim
	_hat_rain[2].emitting = on


## A round glow that fades out smoothly to nothing at its edge (light_blob.png ends in a hard rim).
## A soft ink pool on the pavement under something standing on it, a little wider than its foot:
## without it a crate or a drum looks pasted onto the street instead of resting on it.
var _shadow_tex: Texture2D
func _ground_shadow(cx: float, w: float, y := 0.0) -> void:
	if _shadow_tex == null:
		_shadow_tex = load("res://art/fx_pool.png")   # a soft round pool of ink (generated pictures drew nothing here)
	var sh := Sprite2D.new()
	sh.texture = _shadow_tex
	sh.scale = Vector2(w * 1.18 / 128.0, 40.0 / 128.0)
	sh.position = Vector2(cx, y - 4.0)
	sh.z_index = -3
	add_child(sh)
	var core := Sprite2D.new()   # and a tight dark line where it actually touches the ground
	core.texture = _shadow_tex
	core.scale = Vector2(w * 0.95 / 128.0, 14.0 / 128.0)
	core.position = Vector2(cx, y - 2.0)
	core.modulate = Color(1, 1, 1, 0.9)
	core.z_index = -3
	add_child(core)


func _soft_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.2, 0.35, 0.5, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.11), Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Sky, far skyline and the roofs one block back, seen over the low buildings of the street.
## None of them takes lamplight (light_mask 0); the night still darkens them, so each is lifted
## to the brightness it should keep. Copies alternate with mirrored ones so the seams match.
func _build_depth() -> void:
	if level.get("under", false):   # underground: no sky over the tunnel ceilings, nor a moon
		return
	var sky_tex: Texture2D = LowRes.tex("res://art/bg/sky.png", 0.5)   # a soft sky, a quarter of the memory
	var sky := Sprite2D.new()   # infinitely far: it hangs off the camera and never slides
	sky.texture = sky_tex
	sky.centered = false
	sky.scale = Vector2.ONE * 1.1
	# the pale band low in the drawing sits right behind the rooftops, so the skyline stands dark against it
	sky.position = Vector2(-sky_tex.get_width() * 1.1 * 0.5, -1838.0)
	sky.modulate = _undo_night(0.4)
	sky.light_mask = 0
	sky.z_index = -30
	var sky_sh := Shader.new()   # the clouds in the drawing drift slowly with the wind
	sky_sh.code = """
shader_type canvas_item;
uniform float drift = 0.0;
uniform float flash = 0.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
	vec2 uv = vec2(UV.x + drift, UV.y);
	vec4 c = texture(TEXTURE, uv) * 0.4 + texture(TEXTURE, uv + vec2(px.x, 0.0)) * 0.15 + texture(TEXTURE, uv - vec2(px.x, 0.0)) * 0.15
			+ texture(TEXTURE, uv + vec2(0.0, px.y)) * 0.15 + texture(TEXTURE, uv - vec2(0.0, px.y)) * 0.15;
	COLOR = c * COLOR * (1.0 + flash * 2.5);
}
"""
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sky_sh
	sky.material = _sky_mat
	sky.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	cam.add_child(sky)
	# the same sky again, upside down, under it: when he jumps off a crate the camera rises and the
	# street drops on the screen; without this a black band opened between the sky and the roofs
	var under := sky.duplicate() as Sprite2D
	under.flip_v = true
	under.position.y = sky.position.y + sky_tex.get_height() * 1.1 - 2.0
	under.material = _sky_mat
	cam.add_child(under)
	_sky_nodes = [sky, under]
	# the moon: just over the roofs, seen through the gaps between buildings and from the rooftops
	var moon_tex: Texture2D = load("res://art/bg/moon.png")
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var moon_at := Vector2(980.0, -560.0)
	var glow := Sprite2D.new()
	glow.texture = _soft_glow()
	glow.scale = Vector2.ONE * 4.2
	glow.position = moon_at
	glow.material = additive
	glow.modulate = _undo_night(0.16) * Color(0.75, 0.82, 1.0)
	glow.z_index = -29
	glow.light_mask = 0
	cam.add_child(glow)
	var disc := Sprite2D.new()
	disc.texture = moon_tex
	disc.scale = Vector2.ONE * 0.75
	disc.position = moon_at
	disc.modulate = _undo_night(0.82)
	disc.light_mask = 0
	disc.z_index = -29
	disc.material = atmo.blur_material(1.0)
	cam.add_child(disc)
	var lit := Sprite2D.new()   # its own light on top: over the pale haze low in the sky (seen from a roof) it must
	lit.texture = moon_tex      # still be the brightest thing there, not a faint ring of its outline
	lit.scale = disc.scale
	lit.position = moon_at
	lit.material = additive
	lit.modulate = _undo_night(0.3)
	lit.light_mask = 0
	lit.z_index = -29
	cam.add_child(lit)
	for d in ([] if level.has("street") else DEPTH):   # the drawn streets carry their own distance
		var layer := Node2D.new()
		add_child(layer)
		depth.append(layer)
		depth_follow.append(d[1])
		var t: Texture2D = load(d[0])
		var w: float = t.get_width() * d[3]
		for i in range(-4, 5):
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.flip_h = i % 2 != 0
			s.scale = Vector2.ONE * d[3]
			s.position = Vector2(i * w, d[2])
			s.modulate = _undo_night(d[4])
			s.light_mask = 0
			s.z_index = d[6]
			s.material = atmo.blur_material(d[5])
			layer.add_child(s)


func _undo_night(strength: float) -> Color:
	return Color(strength / ambient.r, strength / ambient.g, strength / ambient.b)


func _add_neon(path: String, at: Vector2, col: Color, unshaded: Material) -> void:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.scale = Vector2.ONE * 0.3
	s.position = at
	s.material = unshaded
	s.modulate = _undo_night(0.9)
	s.z_index = -7
	add_child(s)
	var p := PointLight2D.new()   # the tubes colour the wall around them
	p.texture = load("res://art/light_blob.png")
	p.texture_scale = 2.6
	p.position = at
	p.color = col
	p.energy = 0.5
	p.height = 60.0
	p.range_item_cull_mask = MASK_LIT
	add_child(p)


## Drawn sidewalk slabs laid end to end: the stone top people walk on, the kerb face, then the dark road.
func _pavement(x0: float, w: float) -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = load("res://art/props/slab_sidewalk.png")
	tex.normal_texture = load("res://art/props/slab_sidewalk_n.png")
	# only the middle of the drawing: its ends are bevelled and would leave gaps between slabs
	var region := Rect2(SLAB_REGION_X.x, 0.0, SLAB_REGION_X.y - SLAB_REGION_X.x, tex.diffuse_texture.get_height())
	var sw: float = region.size.x * SLAB_SCALE
	var sh: float = region.size.y * SLAB_SCALE
	_rect(Rect2(x0, -WALL_LIFT - 12.0, w, sh), Color(0.05, 0.05, 0.06))   # dark backing in case a seam opens
	var x := x0
	while x < x0 + w:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.region_rect = region
		s.scale = Vector2.ONE * SLAB_SCALE
		s.position = Vector2(x, -WALL_LIFT - 12.0)
		s.z_index = -8
		add_child(s)
		x += sw - 2.0
	_rect(Rect2(x0, -WALL_LIFT - 12.0 + sh - 4.0, w, 900.0), Color(0.05, 0.05, 0.06))


func _rect(r: Rect2, c: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y)])
	p.color = c
	p.z_index = -8
	add_child(p)


func _build_light() -> void:
	var dark := CanvasModulate.new()
	dark.color = ambient
	add_child(dark)

	var moon := DirectionalLight2D.new()   # cold light from above and behind: a thin edge on everything
	moon.color = Color(0.55, 0.63, 0.9)
	moon.energy = 0.35
	moon.height = 0.35
	moon.rotation_degrees = 35.0
	moon.range_item_cull_mask = MASK_LIT
	add_child(moon)
	moonlight = moon

	for i in lamps.size():
		lamp_info[i]["light"] = _lamp_light(lamps[i])

	var env := Environment.new()   # glow: the lamps and windows bleed a little into the dark
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.75
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env


## A lamp's light: a soft pool spreading down from the bulb whose half-lit rim breaks into diagonal
## hatching, the way an inker draws light falling off; never a solid cone pasted over the bricks.
func _lamp_light(at: Vector2) -> PointLight2D:
	var p := PointLight2D.new()
	p.texture = load("res://art/light_pool.png")
	p.texture_scale = 1.35
	p.position = at + Vector2(0.0, 256.0 * 1.35)
	p.color = LAMP_COLOR
	p.energy = 1.3
	p.height = 160.0
	p.range_item_cull_mask = MASK_LIT
	add_child(p)
	return p


func _add_window_light(bottom_center: Vector2, width: float) -> void:
	var p := PointLight2D.new()   # warm spill from a lit window onto its sill and whoever passes under it
	p.texture = load("res://art/light_blob.png")
	p.texture_scale = width * 3.2 / 256.0
	p.position = bottom_center + Vector2(0.0, width * 0.2)
	p.color = WINDOW_COLOR
	p.energy = 0.55
	p.height = 120.0
	p.range_item_cull_mask = MASK_LIT
	add_child(p)


var _after_tally := Callable()   # what a tap on the cleared map's tally card does: on to the next map or its comic
var _tally_ms := 0
func _input(event: InputEvent) -> void:
	if not _after_tally.is_valid() or not cleared or Time.get_ticks_msec() - _tally_ms < 1500:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]):
		get_viewport().set_input_as_handled()
		_after_tally.call()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_0:
		_show_fps = not _show_fps
	if not OS.is_debug_build():   # (audit 22. 11.) the web build is a release: F9 healed him, F11 put him at 1350 px
		_input_play(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:   # switches for finding what costs time
		match event.physical_keycode:
			KEY_1:
				atmo.post_layer.visible = not atmo.post_layer.visible
				print("post ", atmo.post_layer.visible)
			KEY_2:
				_env.glow_enabled = not _env.glow_enabled
				print("glow ", _env.glow_enabled)
			KEY_3:
				atmo.rain_far.visible = not atmo.rain_far.visible
				atmo.rain_near.visible = atmo.rain_far.visible
				atmo.splashes.visible = atmo.rain_far.visible
				print("rain ", atmo.rain_far.visible)
			KEY_4:
				var on := true
				for n in get_tree().get_nodes_in_group("lights"):
					n.enabled = not n.enabled
					on = n.enabled
				print("lights ", on)
			KEY_5:
				for n in get_tree().get_nodes_in_group("blurred"):
					n.set_meta("m", n.material if n.material else n.get_meta("m"))
					n.material = null if n.material else n.get_meta("m")
				print("blur toggled")
			KEY_6:
				fore.visible = not fore.visible
				for d in depth:
					d.visible = fore.visible
				print("layers ", fore.visible)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		_snap += 1
		_shot("play_%d" % _snap)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		_tt = 0.0   # cover test: crouch behind the first crate, pop up and shoot, then watch a mobster use cover
		_tt_done = 0
		player.position = Vector2(1350.0, 0.0)
		cam.position.x = player.position.x + _lead
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F9:
		hp = max_hp
		hud.set_health(1.0)
		_dt = 0.0   # run the demo of every move and save pictures of it into _shots/
		_demo_step = 0
		player.position = Vector2(-6500.0, 0.0)   # an empty stretch of street, away from the mobsters
		cam.position.x = player.position.x + _lead
		_shots_done = 0
	_input_play(event)


func _input_play(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# On a phone a tap also arrives as a click (emulated from the touch), and the first one can come before the
		# touch itself (a thumb on the stick fired a shot at the stick). A real mouse fires (a touchscreen laptop:
		# audit 22. 11.; hud.touch_seen goes back to false when the mouse is used).
		if not hud.touch_seen and event.device != InputEvent.DEVICE_ID_EMULATION:
			hud.fire_tapped = true


## The big drawings (streets, rooms) are held only near the camera: a whole map of them at once was
## over 300 MB of textures, and a phone's browser kills the page well before that. Each drawing is let
## go once the camera is far from every sprite using it, and loaded back before it comes into view.
var _stream: Array = []   # {path, sprites, x0, x1, tex}
var _stream_t := 0.0
var _world_off := false
var _swingers: Array = []   # hanging lamps on their cords (see _pendant)   # the title hides the street: its drawings are let go
const STREAM_LOAD := 1100.0   # beyond the screen's edge: load from here (a phone holds two or three drawings, not five)
const STREAM_DROP := 2200.0   # and let go past here

func _collect_stream() -> void:
	var by_path := {}
	for n in find_children("*", "", true, false):
		if not (n is Sprite2D or n is Polygon2D):
			continue
		var tex: Texture2D = n.texture
		if tex == null or (tex.resource_path == "" and not tex is BigTex):
			continue
		var path := String((tex as BigTex).path) if tex is BigTex else tex.resource_path
		if not (path.begins_with("res://art/street/") or path.begins_with("res://art/rooms/")):
			continue
		if tex.get_width() * tex.get_height() < 600000:
			continue
		var r: Rect2
		if n is Sprite2D:
			r = (n as Sprite2D).get_global_transform() * (n as Sprite2D).get_rect()
		else:
			var pts: PackedVector2Array = (n as Polygon2D).get_global_transform() * (n as Polygon2D).polygon
			if pts.is_empty():
				continue
			r = Rect2(pts[0], Vector2.ZERO)
			for q in pts:
				r = r.expand(q)
		if not by_path.has(path):
			by_path[path] = {"path": path, "sprites": [], "x0": INF, "x1": -INF, "tex": tex}
		var e: Dictionary = by_path[path]
		e["sprites"].append(n)
		e["x0"] = minf(e["x0"], r.position.x)
		e["x1"] = maxf(e["x1"], r.end.x)
	_stream = by_path.values()
	_stream_tick(true)


func _stream_tick(first := false) -> void:
	if _world_off or _in_cut:   # under the title or a story page the street is not seen: hold none of it
		for e in _stream:
			if e["tex"] != null:
				e["tex"] = null
				for sp in e["sprites"]:
					if is_instance_valid(sp):
						sp.texture = null
		return
	var half: float = get_viewport().get_visible_rect().size.x * 0.5 / maxf(0.2, cam.zoom.x)
	var cx: float = cam.position.x
	for e in _stream:
		var gap: float = maxf(float(e["x0"]) - (cx + half), (cx - half) - float(e["x1"]))
		if e["tex"] == null and gap < STREAM_LOAD:
			var t: Texture2D = BigTex.get_tex(String(e["path"]))
			e["tex"] = t
			for sp in e["sprites"]:
				if is_instance_valid(sp):
					sp.texture = t
		elif e["tex"] != null and gap > STREAM_DROP:
			e["tex"] = null
			for sp in e["sprites"]:
				if is_instance_valid(sp):
					sp.texture = null
	if first and _auto == "hops":
		var held := 0
		for e in _stream:
			if e["tex"] != null: held += 1
		print("  stream: holding %d of %d drawings" % [held, _stream.size()])


static var _measure_from := -1
static var _dumped_cut := false
static var _dumped_play := false
var _measure_t := 0.0
var _beat_t := 2.0
var _worst_dt := 0.0
var _hitches := 0
var _tex_was := 0
var _nodes_was := 0
func _process(delta: float) -> void:
	delta = minf(delta, 0.1 * Engine.time_scale)   # (audit 22. 11.) back from a stall or a hidden tab: no leap through walls
	if _time > 1.0 and Engine.get_process_frames() % 15 == 0 and _can_pause():
		var ws := DisplayServer.window_get_size()
		if ws.y > ws.x * 1.1:   # the phone turned upright
			_pause()
	_time += delta
	var real_dt := delta / maxf(Engine.time_scale, 0.05)
	_beat_t -= real_dt
	_worst_dt = maxf(_worst_dt, real_dt)
	var tex_now := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576
	var nodes_now := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if real_dt > 0.09 and _hitches < 12 and _time > 3.0:   # a frame long enough to feel: what changed in it
		_hitches += 1
		crumb("hitch %dms tex %+dMB nodes %+d cut=%s slow=%s" % [int(real_dt * 1000.0), tex_now - _tex_was, nodes_now - _nodes_was, _in_cut, slow_on])
	_tex_was = tex_now
	_nodes_was = nodes_now
	if _beat_t <= 0.0:
		_beat_t = 5.0
		crumb("beat worst_frame=%dms %s" % [int(_worst_dt * 1000.0), _mem_line()])   # the longest frame of the last five seconds: the lag
		if OS.has_feature("web") and _auto == "" and not in_menu and _sandbox < 0 and player != null:   # where a quit happens
			JavaScriptBridge.eval("window.ashesWhere&&window.ashesWhere('%d:%d',%d)" % [chapter, map, int(player.position.x)], true)
		_worst_dt = 0.0
	if _measure_from >= 0:
		_measure_t -= delta
		if _measure_t <= 0.0:
			_measure_t = 0.5
			print("MEM t=%.1f static %d MB peak %d  textures %d MB  in_cut %s card %s" % [(Time.get_ticks_msec() - _measure_from) / 1000.0, OS.get_static_memory_usage() / 1048576, OS.get_static_memory_peak_usage() / 1048576, int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576, _in_cut, _card_up])
		if (_in_cut and not _dumped_cut) or (not _dumped_play and Time.get_ticks_msec() - _measure_from < 1000):
			if _in_cut and _time > 0.0:
				_dumped_cut = true
				print("DUMP in cut")
			else:
				_dumped_play = true
				print("DUMP playing")
			_dump_textures()
		if Time.get_ticks_msec() - _measure_from > 30000:
			get_tree().quit()
	if not _flames.is_empty():
		_tick_flames(delta)
	if not _flying_guns.is_empty():
		_tick_flying_guns(delta)
	if not _swingers.is_empty():
		_tick_swingers(delta)
	_stream_t -= delta
	if _stream_t <= 0.0 and not _stream.is_empty():
		_stream_t = 0.2
		_stream_tick()
	if not _fire_glows.is_empty():
		_tick_fire(_time)
	if atmo and atmo.splashes:
		atmo.set_ground(cam, -WALL_LIFT + 18.0)
	if in_menu:   # the title over the street: the rain, the signs, the birds, a slow drift of the camera
		sfx.listener_x = cam.position.x
		sfx.music_want = [-9.0, -7.0, -80.0, -80.0]
		if sfx.melody != "dusk":
			sfx.melody = "dusk"
			sfx.melody_soon("dusk")
		sfx.rain_want = _rain()
		cam.position.x = _menu_x + sin(_time * 0.09) * 160.0
		cam.position.y = CAM_Y + sin(_time * 0.13) * 20.0
		fore.position.x = -cam.position.x * 0.35
		for i in depth.size():
			depth[i].position.x = cam.position.x * depth_follow[i]
		if _auto == "paperkit":   # every paper at the sizes the screens use, on a dark ground
			_at += delta
			if _auto_done == 0 and _at > 0.5:
				_auto_done = 1
				var Paper = load("res://paper.gd")
				var lay := CanvasLayer.new()
				lay.layer = 90
				add_child(lay)
				var bg := ColorRect.new()
				bg.color = Color(0.12, 0.12, 0.13)
				bg.size = get_viewport().get_visible_rect().size
				lay.add_child(bg)
				var f := FontVariation.new()
				f.base_font = load("res://fonts/Oswald.ttf")
				var x := 20.0
				for spec in [["panel", Vector2(200, 300)], ["panel", Vector2(520, 96)], ["panel", Vector2(700, 470)], ["panel", Vector2(60, 56)]]:
					var b: Control = Paper.sheet(spec[0], spec[1])
					b.position = Vector2(x, 20.0)
					lay.add_child(b)
					Paper.write(b, "LOREM IPSUM DOLOR", f, 22, Paper.INK)
					x += spec[1].x + 20.0
				x = 20.0
				for spec in [["tape", Vector2(220, 60)], ["tape", Vector2(400, 60)], ["strip", Vector2(300, 56)], ["tag", Vector2(240, 100)], ["folder", Vector2(150, 194)], ["clip", Vector2(330, 182)]]:
					var b: Control = Paper.sheet(spec[0], spec[1])
					b.position = Vector2(x, 520.0)
					lay.add_child(b)
					Paper.write(b, "BACK", f, 26, Paper.INK)
					x += spec[1].x + 16.0
			if _at > 1.5 and _auto_done == 1:
				_auto_done = 2
				_shot("paperkit")
			if _at > 1.7:
				get_tree().quit()
		if _auto == "neon":   # the painted neon lit, then cut out
			_at += delta
			for c in get_children():
				if "_neon" in c and not (c._neon as Dictionary).is_empty():
					if _at < 5.5:
						c._neon["next"] = 99.0
					elif _auto_done == 1:
						c._neon["dip"] = 0.36
			if _at > 5.0 and _auto_done == 0:
				_auto_done = 1
				_shot("neon_on")
			if _at > 5.53 and _auto_done == 1:
				_auto_done = 2
				_shot("neon_off")
			if _at > 5.8:
				get_tree().quit()
		if _auto == "erase":   # the title's settings card, ERASE ALL tapped twice, then the new title
			_at += delta
			if _erased and _at > 5.0 and _auto_done == 0:
				_auto_done = 1
				print("ERASE TITLE ALIVE in_menu ", in_menu, " ", chapter, ":", map, " card_up ", _card_up)
				_shot("erased")
				get_tree().quit()
			if not _erased and _at > 3.0 and _auto_done == 0:
				_auto_done = 1
				print("ERASE: opening settings")
				for c in get_children():
					if c.has_method("_open_settings"):
						c._open_settings()
						for st in c.get_children():
							if "erase" in st and st.erase is Callable and st.erase.is_valid():
								_erased = true
								print("ERASE: tapping erase")
								st.queue_free()
								st.erase.call()
		if _auto == "titleset":   # the settings card from the title, with the erase line armed
			_at += delta
			if _at > 6.6 and _auto_done == 0:
				_auto_done = 1
				for c in get_children():
					if c.has_method("_open_settings"):
						c._open_settings()
			if _at > 6.9 and _auto_done == 1:
				_auto_done = 2
				_shot("titleset")
			if _at > 7.1:
				get_tree().quit()
		if _auto == "instincts":   # Frank's board in the case file (with --leads=N, --progress=N)
			_at += delta
			if _at > 6.6 and _auto_done == 0:
				_auto_done = 1
				for b in Instincts.BRANCHES:   # a clean board, then what --pin=lead0,time1,... asks for
					Instincts.unpin(b, 0)
				for arg in ARGS:
					if arg.begins_with("--pin="):
						for k in arg.trim_prefix("--pin=").split(","):
							Instincts.pin(k.rstrip("0123456789"), int(k.right(1)))
				for c in get_children():
					if c.has_method("_instincts"):
						c._instincts()
						for arg in ARGS:
							if arg.begins_with("--detail="):   # one card picked up: --detail=lead4
								var k := arg.trim_prefix("--detail=")
								c._card_detail(k.rstrip("0123456789"), int(k.right(1)))
			if _at > 6.9 and _auto_done == 1:
				_auto_done = 2
				_shot("instincts")
			if _at > 7.1:
				get_tree().quit()
		if _auto == "gunsmith":   # --test=gunsmith --gun=gun|shotgun|tommy --pick=N (--progress, --xp): the screen as it works
			_at += delta
			if _at > 6.6 and _auto_done == 0:
				_auto_done = 1
				var g := "gun"
				var pk := 0
				for arg in ARGS:
					if arg.begins_with("--gun="): g = arg.trim_prefix("--gun=")
					if arg.begins_with("--pick="): pk = int(arg.trim_prefix("--pick="))
				for b in Instincts.BRANCHES:
					Instincts.unpin(b, 0)
				for arg in ARGS:
					if arg.begins_with("--pin="):
						for k in arg.trim_prefix("--pin=").split(","):
							Instincts.pin(k.rstrip("0123456789"), int(k.right(1)))
				for c in get_children():
					if c.has_method("_gunsmith"):
						c._gunsmith(g, pk)
			if "--mash" in ARGS and _at > 7.0 and _at < 9.0 and fmod(_at, 0.2) < 0.04:   # quick taps across the cards
				for c in get_children():
					if c.has_method("_gunsmith"):
						c._gunsmith("", int(_at * 5.0) % 4)
			if "--buy" in ARGS and _at > 7.0 and _auto_done == 2:
				for c in get_children():
					if c.has_method("_smith_buy"):
						c._smith_buy()
			for k in 6:
				if _at > 6.6 + [0.3, 0.62, 0.9, 1.2, 1.5, 2.9][k] and _auto_done == k + 1:
					_auto_done = k + 2
					_shot("smith_%d" % k)
			if _at > (11.0 if "--mash" in ARGS else 9.8):
				get_tree().quit()
		if _auto == "whatsnew":   # --test=whatsnew: the title, then the WHAT'S NEW card
			_at += delta
			if _at > 6.5 and _auto_done == 0:
				_auto_done = 1
				for c in get_children():
					if c.has_method("_open_whatsnew"):
						c._open_whatsnew()
			if _at > 7.2 and _auto_done == 1:
				_auto_done = 2
				_shot("whatsnew")
			if _at > 7.5:
				get_tree().quit()
		if _auto == "menu":
			_at += delta
			if _at > 6.5 and _auto_done == 0:   # once the title is up and Frank's line typed out
				_auto_done = 1
				_shot("menu")
			if _at > 6.6 and _auto_done == 1:
				_auto_done = 3
				for c in get_children():
					if c.has_method("_case_file"):
						for a in ARGS:   # (test) another chapter's page: --casepage=N
							if a.begins_with("--casepage="):
								c._chapter = int(a.trim_prefix("--casepage="))
						c._case_file()
			if _at > 6.85 and _auto_done == 3:
				_auto_done = 2
				_shot("casefile")
			if _at > 7.1:
				get_tree().quit()
		return
	if _auto != "" and not _auto.begins_with("cut:") and not _auto.begins_with("voice:") and _auto != "hops":
		_auto_step(delta)
	if _auto == "poses":
		return
	_probe += delta / Engine.time_scale
	if _probe > 2.0 and _show_fps:   # key 0 switches the readout on
		_probe = 0.0
		var vp := get_viewport().get_viewport_rid()
		print("fps ", Engine.get_frames_per_second(), "  script ms ", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), "  gpu ms ", snappedf(RenderingServer.viewport_get_measured_render_time_gpu(vp), 0.1), "  cpu-render ms ", snappedf(RenderingServer.viewport_get_measured_render_time_cpu(vp), 0.1), "  draws ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  window ", get_window().size)
	var real := delta / Engine.time_scale   # the slow-time meter runs on the wall clock
	_last_round_t = maxf(0.0, _last_round_t - delta)
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	dir = clampf(dir + hud.move, -1.0, 1.0)
	_move_dir = dir
	var chest: Vector2 = player.position + SHOULDER + Vector2(0.0, DUCK_DROP * player.duck)
	var aim: Vector2 = get_global_mouse_position() - chest
	var touch: bool = hud.touch_seen   # a phone from the first frame (hud._ready), the mouse once it moves
	if touch and hud.aim_left > 0.0:   # on a phone: a finger on the screen is where he shoots
		aim = get_viewport().get_canvas_transform().affine_inverse() * hud.aim_at - chest
	elif touch:   # no finger: he keeps his gun on a mobster he can see, the way he is going
		if dir != 0.0:
			_face = signf(dir)
		var near = _nearest_enemy(_face if dir != 0.0 else 0.0) if _assist else null
		if near != null:
			aim = near.position + SHOULDER + Vector2(0.0, DUCK_DROP * near.duck) - chest
		else:
			aim = Vector2(_face, 0.0)   # nobody about: he looks the way he last went, not always right
	if _dt >= 0.0:
		_dt += delta
	var demo: bool = _dt >= 0.0 and _dt < 7.4 and dir == 0.0   # self-running start for the automatic pictures
	if demo:
		aim = Vector2(1.0, 0.0)
		if _dt > 1.6 and (_dt < 5.9 or _dt > 6.6):
			dir = 1.0
			aim = Vector2(1.0, -0.12)
		_demo_duck = _dt > 5.9
	if _tt >= 0.0:
		_tt += delta
		var target = _nearest_enemy()
		aim = Vector2(1.0, 0.0) if target == null else (target.position + SHOULDER + Vector2(0.0, DUCK_DROP * target.duck) - chest)
		dir = 0.0
		_demo_duck = _tt < 1.5
		for i in TEST_FIRE.size():
			if _tt_done & (1 << i) == 0 and _tt > float(TEST_FIRE[i]):
				_tt_done |= 1 << i
				hud.fire_tapped = true
		for i in TEST_SHOTS.size():
			if _tt_done & (1 << (i + 8)) == 0 and _tt > float(TEST_SHOTS[i][0]):
				_tt_done |= 1 << (i + 8)
				_shot(TEST_SHOTS[i][1])
		if _tt > 4.0 and player.position.x < 2750.0:   # on to the mobster behind the drum
			player.position.x = 2750.0
			cam.position.x = player.position.x + _lead
		if _tt > 6.4:
			_tt = -1.0
			_demo_duck = false
	if over:
		dir = 0.0
	if demo:   # the demo throws one of each move, so the pictures show them all
		if _demo_step == 0 and _dt > 2.55:
			_demo_step = 1
			hud.dive_tapped = false
			_start_dive(1.0, 1.0, DIVE_SPEED.y, true)
		elif _demo_step == 1 and _dt > 4.3 and move_state == "ground":
			_demo_step = 2
			hud.dive_tapped = true   # out of a run this is a slide
		elif _demo_step == 2 and _dt > 5.2 and move_state == "ground":
			_demo_step = 3
			hud.jump_tapped = true
	elif _tt < 0.0:
		_demo_duck = false
	if _auto == "play":   # the test bot aims at the nearest mobster
		var target = _nearest_enemy()
		if target != null:
			aim = target.position + SHOULDER + Vector2(0.0, DUCK_DROP * target.duck) - chest
	if _auto in ["ricochet", "dive"] and _test_aim != Vector2.INF:
		aim = _test_aim - chest
	_aim_point = chest + aim
	dir = _move(dir, aim, delta)
	if not over:
		player.set_state(dir, aim, delta)
	steps.emitting = (absf(dir) > 0.3 or absf(glide) > 180.0) and move_state == "ground"
	var foot := int(floor(player._phase * 2.0))
	if steps.emitting and player.duck < 0.5 and absf(glide) < 180.0 and foot != _step_half:   # a footfall each time a foot comes down
		sfx.play("step1" if foot == 0 else "step2", -6.0 if _room == "" else -8.0, INF, 0.06)
	_step_half = foot

	fire_cool = maxf(0.0, fire_cool - delta)
	_fire_buf = maxf(0.0, _fire_buf - delta)
	if demo and _dt > 0.95 and _dt < 1.1 and fire_cool == 0.0:
		hud.fire_tapped = true
	if hud.aim_held and fire_cool == 0.0 and not over:   # a finger held on the street keeps firing
		hud.fire_tapped = true
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_combo_t = maxf(0.0, _combo_t - delta)
	_bounce_t = maxf(0.0, _bounce_t - delta)
	if hud.fire_tapped and fire_cool > 0.0:   # tapped a moment too early: kept, not lost
		_fire_buf = 0.2
	_tick_reload(delta)
	if move_state in ["climb", "swing", "stairs"]:   # both hands on the rope (on the stairs in the wall: out of sight)
		hud.fire_tapped = false
		_fire_buf = 0.0
	if (hud.fire_tapped or _fire_buf > 0.0) and fire_cool == 0.0 and not over and not _queued_shot and mag <= 0:
		_fire_buf = 0.0   # the hammer falls on an empty chamber
		fire_cool = 0.35
		if reloading <= 0.0:
			_dry_fire()
	elif (hud.fire_tapped or _fire_buf > 0.0) and fire_cool == 0.0 and not over and not _queued_shot and reloading <= 0.0:
		_fire_buf = 0.0
		if player.duck > 0.3:   # crouched behind cover: he rises over it first, then fires
			_queued_shot = true
			_pop = 0.25
		else:
			if touch and hud.aim_left > 0.0:
				player.snap_aim(aim)
			_fire(player, true)
			_pop = 0.15
		fire_cool = float(_w(weapon)["cool"])
	hud.fire_tapped = false
	if not _queued_shot:   # the time risen out of cover counts from the shot, not from the tap
		_pop = maxf(0.0, _pop - delta)
	if _queued_shot and (mag <= 0 or reloading > 0.0):
		_queued_shot = false
	if _queued_shot and player.duck < 0.12:
		_queued_shot = false
		if touch and hud.aim_left > 0.0:
			player.snap_aim(aim)
		_fire(player, true)
		_pop = 0.15

	# Nobody fires at a man who has only just arrived. The count does not run under the title card,
	# and it does not start until he has moved or fired himself (or stood there a good while).
	if _spawn_x == INF:
		_spawn_x = player.position.x
		_spawn_wait = 6.0
	if not _card_up:
		if _spawn_wait > 0.0:
			_spawn_wait -= delta / Engine.time_scale
			if absf(player.position.x - _spawn_x) > 140.0 or (_spawn_wait < 5.6 and _idle_fire < 0.2) or _spawn_wait <= 0.0:
				_spawn_wait = 0.0
				_grace = 1.6
		else:
			_grace = maxf(0.0, _grace - delta)
	if (hud.pause_tapped or (Input.is_action_just_pressed("ui_cancel") and Engine.get_process_frames() > _unpaused_frame + 1)) \
			and not over and not cleared and not _in_cut:
		hud.pause_tapped = false
		_pause()
	hud.pause_tapped = false
	_swap_boxes()
	_tick_pipe(delta)
	_enemies(delta)
	_pickups()
	_map_events(delta)
	sets.tick(delta)
	mapfx.tick(delta)
	_tick_exit(delta)
	if level.has("goal"):   # (rule 30, 18. 11.) a map won by getting somewhere: the flat he runs into, the crowd behind him
		var gl: Array = level["goal"]
		var settled := _witness_settled(delta)   # (ticks every frame: the 2.6 s run from when he was dealt with)
		if not cleared and not over and player.position.x > float(gl[0]) and absf(player.position.y - float(gl[1])) < 80.0 \
				and settled:
			_map_cleared()
	elif not cleared and not over and roof.is_empty() and player.position.x > level_end and _all_down():
		_map_cleared()
	elif not cleared and not over and not roof.is_empty() and player.position.x < float(roof["goal"]) \
			and player.position.y < float(roof["y"]) + 60.0 and _roof_clear():
		_map_cleared()
	_slow_time(real)
	atmo.blow_ash(_time)
	_tick_neons(delta)
	_tick_birds(delta)
	_tick_hat_rain()
	_tick_aim_line()
	_tick_sections(real)
	moonlight.energy = lerpf(0.35, 0.62, clampf(-player.position.y / 650.0, 0.0, 1.0))
	_tick_sky(delta)
	_tick_music()
	_afterimages(delta, absf(dir))
	_slow_look = lerpf(_slow_look, 1.0 if _slow_base else 0.0, 1.0 - exp(-10.0 * real))
	atmo.set_slow(_slow_look)
	sfx.slow = _slow_look
	sfx.listener_x = player.position.x
	var half: Vector2 = get_viewport().get_visible_rect().size / cam.zoom * 0.5
	sfx.view = Rect2(cam.get_screen_center_position() - half, half * 2.0)
	fx.slow = _slow_look
	_cast_shadow(player)
	for e in enemies:
		if e["alive"] and e["state"] != "wait":
			_cast_shadow(e["node"])
	# The camera looks the way he aims: when the fight turns round behind him it swings over, slowly,
	# to give him room on that side. It leans a touch into the aim, trails him softly and does not
	# bob with jumps.
	var aim_n := aim.normalized() if aim.length() > 1.0 else Vector2(signf(_lead), 0.0)
	if not over:   # the camera looks where he faces: where he aims, or where he runs when nothing's aimed at
		if touch and hud.aim_left <= 0.0 and dir != 0.0 and _nearest_enemy(signf(dir)) == null:
			_look = signf(dir)
		elif absf(aim.x) > 20.0:
			_look = signf(aim.x)
	_lead = lerpf(_lead, CAM_LEAD * _look, 1.0 - exp(-3.6 * real))
	if move_state == "ground":
		_ground_y = player.position.y
	var want_zoom := ROOM_ZOOM if _room != "" else ZOOM
	if not roof.is_empty() and player.position.x > float(roof["x0"]) - 1600.0 and player.position.x < float(roof["x1"]) + 1600.0:
		# where there is a floor above the street, closer in: only the floor he is on fills the picture
		want_zoom = maxf(want_zoom, get_viewport().get_visible_rect().size.y / (absf(float(roof["y"])) * 0.92))
	var in_sec := _section_at(player.position) >= 0
	if in_sec:   # in a building: the street's zoom, the storey he stands on held where the pavement is
		want_zoom = ZOOM
	else:
		var ri := _plain_room_at(player.position)
		if ri >= 0:   # a room narrower than the screen: just close enough that its walls are the screen's edges
			want_zoom = maxf(want_zoom, (get_viewport().get_visible_rect().size.x + 60.0) / (float(_room_art[ri][1]) - float(_room_art[ri][0])))
	var rim := clampf((0.85 - Engine.time_scale) / 0.5, 0.0, 1.0) if not over else 0.0
	player.set_rim(rim if _alcove < 0.0 else 0.0)   # (rule 33: no bright contour in a dark doorway)
	for e in enemies:   # (chapter I audit 18. 11.: black coats lost in dark doorways) a faint rim always, the full one in slowed time
		if e["alive"] and is_instance_valid(e["node"]):
			e["node"].set_rim(maxf(rim, 0.35))
			if e["type"] == "shade":
				_shade_eyes(e["node"])
	var on_roofs: bool = not roof.is_empty() and player.position.x > float(roof["x0"]) - 1600.0 and player.position.x < float(roof["x1"]) + 1600.0
	var high := 0.0 if in_sec or _room != "" or on_roofs else smoothstep(-450.0, -1100.0, player.position.y)
	_high = lerpf(_high, high, 1.0 - exp(-3.0 * real))
	want_zoom *= 1.0 - HIGH_WIDE * high   # (user 22. 11.) up a fire escape or on a line over the street: pulled back to see down
	if wide_shot > 0.0:   # a set piece bigger than the picture (the El's train over the street): the camera pulls back for it
		want_zoom *= 1.0 - 0.28 * wide_shot
	if Engine.time_scale < 0.8 and not over:   # (audit 17. 11.) slowed time leans in a little: the moment fills the picture
		want_zoom *= 1.0 + 0.08 * clampf((0.8 - Engine.time_scale) / 0.5, 0.0, 1.0)
	cam.zoom = Vector2.ONE * lerpf(cam.zoom.x, want_zoom, 1.0 - exp(-3.0 * real))
	var cc := cam.get_screen_center_position() if _city_far.size() > 0 else Vector2.ZERO
	for fa in _city_far:   # (rule 31) the old street drawings as the city far behind: smaller, slower, over the roofs
		(fa[0] as Sprite2D).position = Vector2(cc.x + (float(fa[1]) - cc.x) * CITY_FAR_SCALE, cc.y + (float(fa[2]) - cc.y) * CITY_FAR_SCALE - CITY_FAR_LIFT)
	for sk in _sky_nodes:   # (the sky hangs off the camera: pulled back wider than the street zoom, it widens with it)
		if is_instance_valid(sk):
			var sks := sk as Sprite2D
			sks.scale.x = 1.1 * maxf(1.0, ZOOM / cam.zoom.x)
			sks.position.x = -sks.texture.get_width() * sks.scale.x * 0.5
	var near := ZOOM / cam.zoom.x   # the pavement stays four fifths down the screen at any zoom
	fore.modulate.a = move_toward(fore.modulate.a, 0.0 if _room != "" or player.position.y < -900.0 else 1.0, real * 3.0)   # no street furniture indoors, nor up on the scaffold
	var sec_y := _ground_y if not (move_state == "climb" and _works(_section_at(player.position))) else minf(_ground_y, player.position.y + 120.0)   # (user 23. 11.) up the works' ladder: the camera climbs with him
	var want_y := CAM_Y * near + (sec_y if in_sec else _cam_rise(_snap_y(player.position.y))) + clampf(aim_n.y, -0.6, 0.6) * 90.0 * near 			- (120.0 if _steps_above > 0.0 else 0.0)   # steps on the storey above: the camera looks up at them
	want_y += HIGH_LOOK_DOWN * _high * near   # (user 22. 11.) up high outside the camera looks down: where he will land shows
	var want_x: float = player.position.x + _lead
	if _pan_t > 0.0:   # the map's opening: the camera eases in onto him from a little way off (_intro_pan)
		_pan_t -= real
		if absf(_move_dir) > 0.3 or move_state != "ground":   # (stick or keys: audit 22. 11.)
			_pan_t = minf(_pan_t, 0.5)
		var w := smoothstep(0.0, INTRO_LEN, _pan_t)
		want_x += INTRO_FROM.x * w
		want_y += INTRO_FROM.y * w
	if _cue_t > 0.0:   # cue focus: drawn toward what matters for a moment, never off him
		_cue_t -= real
		var k := _cue_w * clampf(_cue_t / 0.5, 0.0, 1.0) * clampf((_cue_len - _cue_t) / 0.35, 0.0, 1.0)
		want_x = lerpf(want_x, _cue_at.x, k)
		want_y = lerpf(want_y, _cue_at.y, k * 0.5)
	want_x = _room_cam_x(want_x)
	want_y = _room_cam_y(want_y)
	cam.position = Vector2(lerpf(cam.position.x, want_x, 1.0 - exp(-5.5 * real)),
			lerpf(cam.position.y, want_y, 1.0 - exp(-3.0 * real)))
	var held := _room_cam_x(cam.position.x)   # (through the door the room is simply there: never a glimpse past its walls)
	if held != cam.position.x and _plain_room_at(player.position) != _cam_room:
		cam.position.x = held
	_cam_room = _plain_room_at(player.position)
	if _cam_snap:   # a hard cut (out through a window): the camera is simply there
		_cam_snap = false
		cam.position = Vector2(want_x, want_y)
	if _auto == "tops" and not boxes.is_empty():   # the test frames each crate close up
		var tb: Rect2 = boxes[mini(int(_at / 1.2) / 2, boxes.size() - 1)]
		cam.position = Vector2(tb.get_center().x, tb.position.y - 120.0)
		cam.zoom = Vector2.ONE * 1.1
	var tilt := clampf(aim_n.y, -0.7, 0.7) * _look * 0.012 + clampf(run / 1400.0, -1.0, 1.0) * 0.006
	cam.rotation = lerpf(cam.rotation, 0.0 if over else tilt, 1.0 - exp(-2.0 * real))
	if _shake > 0.0:   # an explosion shakes the picture
		_shake = maxf(0.0, _shake - real)
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 60.0 * _shake * (1.0 if _shake_on else 0.0)
	else:
		cam.offset = Vector2.ZERO
	fore.position.x = -cam.position.x * 0.35
	if props:
		props.tick(real)
	for i in depth.size():
		depth[i].position.x = cam.position.x * depth_follow[i]
	if _dt >= 0.0:
		for i in SHOTS.size():
			if _shots_done & (1 << i) == 0 and _dt > float(SHOTS[i][0]):
				_shots_done |= 1 << i
				if SHOTS[i][1] == "stand":
					_fire(player, true)
				_shot(SHOTS[i][1])


## Scripted checks, run headless-with-a-screen on the build machine. Each saves pictures and quits.
var _film_i := 0
func _auto_step(delta: float) -> void:
	_at += delta
	for a in ARGS:   # --film=start,step,count: a strip of frames of any test, for review (film_00..)
		if a.begins_with("--film="):
			var f := a.trim_prefix("--film=").split(",")
			if _film_i < int(f[2]) and _at >= float(f[0]) + float(f[1]) * _film_i:
				_shot("film_%02d" % _film_i)
				_film_i += 1
	var shots: Array = []
	if _auto == "dive":   # run at the first crate with the stick and tap the dive button right in front of it
		if _at < 0.05:
			player.position.x = 900.0
			cam.position.x = player.position.x + _lead
		hud.move = 1.0 if _at < 2.2 else 0.0
		if ARGS.has("--fwd"):   # aimed ahead, the way he dives (the usual case on the phone)
			_test_aim = player.position + Vector2(1400.0, -250.0)
		if player.position.x > _dive_at and _auto_done & 1 == 0:
			_auto_done |= 1
			_at = 1.0
			hud.dive_tapped = true
		if _auto_done & 1 == 0:
			_at = minf(_at, 0.9)
		shots = [[1.06, "dive_1"], [1.14, "dive_2"], [1.22, "dive_3"], [1.32, "dive_4"], [1.5, "dive_5"], [2.0, "dive_6"]]
	elif _auto == "play":   # a bot plays the chapter: walks right, stops to fight, jumps what blocks it
		var near = _nearest_enemy()
		if near != null and _section_at(player.position) >= 0 and absf(near.position.y - player.position.y) > 200.0:
			near = null   # in a building: a man on another storey is not this storey's fight
		var fight: bool = near != null and absf(near.position.x - player.position.x) < 1500.0
		_bot_fight = _bot_fight + delta if fight else 0.0
		if _bot_fight > 8.0:   # a man dug in behind cover: walk up on him, as a player would
			fight = absf(near.position.x - player.position.x) < (420.0 if _bot_fight < 16.0 else 120.0)   # and at last over his cover
		hud.move = 0.0 if fight else 1.0
		if not fight and _section_dir() != 0.0:   # up through a building: each storey the other way
			hud.move = _section_dir()
			var bf := _flat_at_storey(_ground_y)
			if not bf.is_empty() and not bf["open"] and move_state == "ground" and player.position.x > float(bf["hinge"]) - float(bf["span"]) - FLAT_KICK_FROM:
				hud.dive_tapped = true   # the bot kicks the shut door in, as a player would: a dive into it
			if not bf.is_empty() and bf["open"] and move_state == "ground" and player.position.x > float(bf["wx0"]) - 330.0 and _section_at(player.position) >= 0:
				hud.dive_tapped = true   # out of the window
			for d in _stairdoors:   # and up the stairs in the back wall when he gets to them
				if absf(float(d[1]) - player.position.y) < 12.0 and float(d[2]) < float(d[1]) and move_state == "ground":
					var dx: float = float(d[0]) - player.position.x
					if absf(dx) < 900.0 and signf(dx) == signf(_section_dir()) or absf(dx) < 60.0:
						hud.move = 0.0 if absf(dx) < 40.0 else signf(dx)
						if absf(dx) < 60.0:
							hud.jump_tapped = true
		if move_state == "ground" and player.position.y > -10.0:
			_bot_esc_up = false   # (back on the street: the next fire escape is climbed from its own foot)
		if not fight and move_state == "ground" and _section_at(player.position) < 0 and player.position.y < -600.0:
			for rp in ramps:   # on the fire escape: back to the foot of the flight going up, then up it
				if rp.size() > 4 and String(rp[4]) == "fescape" and absf(float(rp[1]) - player.position.y) < 12.0:
					var foot := float(rp[0])
					if player.position.x > foot + 20.0 and not _bot_esc_up:
						hud.move = -1.0
					else:
						_bot_esc_up = true
						hud.move = 1.0
			if roof.is_empty() or player.position.y > float(roof["y"]) + 8.0:
				pass
			else:
				_bot_esc_up = false
		if not fight and move_state == "ground" and player.position.y < -300.0 and _section_at(player.position) < 0:
			for e in enemies:   # up on a fire escape: toward a man still higher (its stairs run up to the right)
				if e["alive"] and float(e["node"].position.y) < player.position.y - 200.0 and absf(float(e["node"].position.x) - player.position.x) < 900.0:
					hud.move = 1.0
		var lad = _bot_ladder()
		if lad == null and move_state == "jump" and _bot_lad != null and _plain_room_at(player.position) >= 0:
			lad = _bot_lad   # (over a crate on the way back to a room's ladder: still going there)
		_bot_lad = lad
		hud.up = lad != null or move_state == "climb" or _bot_esc_up or (move_state != "ground" and not _works(_section_at(player.position)))   # (23. 11.: ladders only with the stick up)
		var up_to_them: bool = lad != null and near != null and _plain_room_at(player.position) >= 0 and absf(near.position.y - player.position.y) > 200.0   # (indoors, men up on a catwalk: up its ladder, the big laundry)
		if lad != null and (not fight or up_to_them or player.position.y < -10.0 and absf(near.position.y - player.position.y) > 60.0):
			var lx: float = (lad["a"] as Vector2).x
			hud.move = 0.0 if absf(lx - player.position.x) < 30.0 else signf(lx - player.position.x)
			if absf(lx - player.position.x) < 50.0 and move_state == "ground":
				hud.up = true   # (23. 11.) the stick up at its foot: onto it (a jump would only hop)
		elif not roof.is_empty() and player.position.y < float(roof["y"]) + 8.0 and not fight and move_state == "ground":
			hud.move = -1.0   # along the roof the other way (once up on it, not on the last stair)
		var wk := _section_at(player.position)
		if _works(wk) and not fight:   # (QUEUE §22) the works: up on a gallery at its far wall, back along it and down to the floor
			if player.position.y < -60.0 and player.position.x > float((sections[wk] as Array)[1]) - 400.0 and move_state == "ground":
				_bot_down = true
			if _bot_down and player.position.y < -60.0:   # along it to its end, then straight down past the low one
				hud.move = -1.0 if move_state == "ground" and player.position.y < -1050.0 else 0.0
				hud.jump_tapped = false
			else:
				_bot_down = false
		if _bot_back > 0.0:   # missed the crane rope: back off and take a run at it again
			_bot_back -= delta
			hud.move = -1.0
		if near != null and absf(near.position.x - player.position.x) < 1900.0:
			hud.fire_tapped = true
		hud.duck = false   # (audit 18. 11., QUEUE §16 F) on the last train: down flat under a girder, as a player does on the red lamp
		if sets != null and sets._speed > 0.0 and move_state == "ground":
			for bl in sets._beams_live:
				var gx: float = (bl[0] as Node2D).position.x - player.position.x
				if gx > -80.0 and gx < 1100.0:
					hud.duck = true
					hud.fire_tapped = false   # (a shot from down there pops him up into it - nor one tapped a moment ago)
					_fire_buf = 0.0
					_queued_shot = false
					hud.move = 0.0   # (still: running into it, a duck is a slide, and a slide comes up again)
		if sets != null and move_state == "jump":
			for g in sets.gaps:   # (and the stick held on over it: let go in the air and he drops in)
				if player.position.x > g.x - 300.0 and player.position.x < g.y + 40.0:
					hud.move = 1.0
		if sets != null and move_state == "ground" and not hud.duck:
			for g in sets.gaps:   # the last train's open couplings: a run at the edge and a jump over (a standing jump falls short)
				var to_gap: float = g.x - player.position.x
				if to_gap > -10.0 and to_gap < 260.0:
					hud.move = 1.0
					hud.fire_tapped = false
					_fire_buf = 0.0
					_queued_shot = false
					if to_gap < 70.0:
						hud.jump_tapped = true
						print("BOT gap jump at ", int(player.position.x))
		if hud.move != 0.0 and move_state == "ground":
			for r in _ropes:   # a crane rope before a wall of cargo: jump for it (not when he is on his way up a ladder)
				if r["kind"] == "swing" and lad == null and player.position.x > (r["a"] as Vector2).x - 110.0 and player.position.x < (r["a"] as Vector2).x - 40.0:
					hud.jump_tapped = true
					print("BOT swing at ", int(player.position.x))
			_bot_stuck = _bot_stuck + delta if (player.position.x - _bot_x) * signf(hud.move) < 1.0 else 0.0
			if _bot_stuck > 1.5:
				for r in _ropes:
					var rx: float = (r["a"] as Vector2).x
					if r["kind"] == "swing" and player.position.x > rx - 40.0 and player.position.x < rx + 900.0:
						_bot_back = 0.25 + (player.position.x - rx + 300.0) / 450.0
						_bot_stuck = 0.0
			if _bot_stuck > 0.3 and not hud.duck:
				hud.jump_tapped = true
				print("BOT jump at ", int(player.position.x))
				_bot_stuck = 0.0
		if hud.move != 0.0 and move_state == "jump" and _wall_t > 0.0 and fall > -200.0:   # against a tall stack in the air: kick up off it
			hud.jump_tapped = true
		var wk2 := _section_at(player.position)
		if _works(wk2) and not fight and player.position.y > -60.0 and not _works_out:   # (QUEUE §22) all down: out by its street door
			var left_in := false
			for e in enemies:
				if e["alive"] and _section_at(e["node"].position) == wk2:
					left_in = true
			if not left_in:
				var dx: float = float((sections[wk2] as Array)[0]) + WORKS_DOOR + 200.0 - player.position.x
				hud.move = signf(dx)   # (out through its door: just walking through it)
		_bot_x = player.position.x
		if ARGS.has("--trace") and fmod(_at, 0.25) < delta:
			print("TRACE t %.2f x %d y %d st %s move %.0f ground %d fight %s lad %s near %s" % [_at, int(player.position.x), int(player.position.y), move_state, hud.move, int(_ground_y), fight, lad != null, str(near.position) if near != null else "-"])
		_bot_log += delta
		if _bot_log > 10.0:
			_bot_log = 0.0
			var left := 0
			for e in enemies:
				left += 1 if e["alive"] else 0
			print("BOT t ", int(_at), " x ", int(player.position.x), " y ", int(player.position.y), " / ", int(level_end), " mobsters left ", left, " move ", move_state, " hp ", hp, " in_cut ", _in_cut, " over ", over)
			var near_e := []
			for e in enemies:
				if e["alive"] and absf(e["node"].position.x - player.position.x) < 1600.0:
					near_e.append("%s/%s@%d" % [e.get("boss", false), e["state"], int(e["node"].position.x)])
			print("BOT near ", near_e)
		if DisplayServer.get_name() != "headless":   # with a screen: a few pictures of the chapter in play, then stop
			var film := ARGS.has("--film")   # a strip of frames, every 0.15 s from 6 s
			if film:
				var f0 := 6.0   # --film-at=T: the strip from T seconds, a frame every --film-step (0.15 s)
				var fs := 0.15
				for arg in ARGS:
					if arg.begins_with("--film-at="):
						f0 = float(arg.trim_prefix("--film-at="))
					if arg.begins_with("--film-step="):
						fs = float(arg.trim_prefix("--film-step="))
				var k := int((_at - f0) / fs)
				if k >= 0 and k < 24 and _auto_done & (1 << k) == 0:
					_auto_done |= 1 << k
					_shot("film_%02d" % k)
				if _at > f0 + fs * 24.0 + 0.2:
					get_tree().quit()
			else:
				for i in 4:
					if _auto_done & (1 << i) == 0 and _at > [1.5, 9.0, 15.0, 21.0][i]:
						_auto_done |= 1 << i
						_shot("play_%d" % i)
				if _at > 21.5:
					get_tree().quit()
		if _at > 600.0:
			print("BOT TIMEOUT at x ", int(player.position.x))
			for e in enemies:
				if e["alive"]:
					print("  left: ", int(e["node"].position.x), " ", e["state"], " y ", int(e["node"].position.y))
			get_tree().quit()
		return
	elif _auto.begins_with("clip:"):   # --test=clip:<name> --sandbox=1: Frank plays one move-sheet clip (puppet.gd CLIPS), frame by frame, in the air
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			player.position = Vector2(1200.0, -260.0)
			move_state = "jump"   # (held where he is, every frame)
			_grace = 99.0
			for e in enemies:
				e["node"].position.x += 60000.0
		player.position = Vector2(1200.0, -260.0)
		fall = 0.0
		cam.position = player.position + Vector2(0.0, -150.0)
		cam.zoom = Vector2.ONE * 0.85
		var cl := _auto.trim_prefix("clip:")
		var ln := float(player.CLIPS[cl]["len"])
		if _at > 0.3 and _auto_done & (1 << 20) == 0:
			_auto_done |= 1 << 20
			player.play_clip(cl, 1.0)
		var kf := int((_at - 0.3) / (ln / 7.0))
		if kf >= 0 and kf < 8 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			_shot("clip_%d" % kf)
		if _at > 0.4 + ln * 1.2:
			get_tree().quit()
		return
	elif _auto == "intro":   # --test=intro --chapter=c --map=m: the opening look along the way up, four frames
		if _at < 0.05:
			print("INTRO for ", snappedf(_pan_t, 0.1), " from x ", int(player.position.x))
		shots = [[0.1, "intro_1"], [0.8, "intro_2"], [1.6, "intro_3"], [3.0, "intro_4"]]
		if _at > 3.2:
			get_tree().quit()
	elif _auto == "barslide":   # --test=barslide --sandbox=1: on the club's bar counter, a dive along it, frames
		var bar := Rect2()
		for k in catwalks.size():
			if catwalk_style[k] == "bar":
				bar = catwalks[k]
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			player.position = Vector2(bar.position.x + 30.0, bar.position.y)
			move_state = "ground"
			_grace = 99.0
		hud.move = 1.0 if _at > 0.5 and _at < 0.75 else 0.0
		if _at > 0.6 and _auto_done & (1 << 20) == 0:
			_auto_done |= 1 << 20
			hud.dive_tapped = true
		var kf := int((_at - 0.5) / 0.1)
		if kf >= 0 and kf < 20 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			_shot("film_%02d" % kf)
			print("BAR ", kf, " ", move_state, " x ", int(player.position.x - bar.position.x), " y ", int(player.position.y), " glide ", int(glide))
		if _at > 2.4:
			get_tree().quit()
		return
	elif _auto == "awnjump":   # --test=awnjump --sandbox=1: from the crate (stack) before the awning: a jump onto it, the throw, frames
		var bi := -1
		for k in boxes.size():
			if boxes[k].position.x > 2000.0 and boxes[k].position.x < 4000.0:
				bi = k
		if _auto_done & (1 << 21) == 0 and bi >= 0:
			_auto_done |= 1 << 21
			player.position = Vector2(boxes[bi].end.x - 40.0, boxes[bi].position.y)
			_ground_y = player.position.y
			_grace = 99.0
		hud.move = 1.0 if _at > 0.5 else 0.0
		if _at > 0.55 and _auto_done & (1 << 20) == 0:
			_auto_done |= 1 << 20
			hud.jump_tapped = true
		var kf := int((_at - 0.5) / 0.15)
		if kf >= 0 and kf < 20 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			print("AWNJ ", kf, " ", move_state, " ", Vector2i(player.position), " fall ", int(fall))
			_shot("film_%02d" % kf)
		if _at > 3.0:
			get_tree().quit()
		return
	elif _auto.begins_with("wash"):   # --test=wash --sandbox=1: from the fire escape's top landing a jump onto the washing line, the ride, frames
		var wr: Dictionary = {}   # (--test=wash:alley: the one across the alley mouth - the longest)
		for r in _ropes:
			if r.has("laundry") and (wr.is_empty() or (_auto.ends_with(":alley") and (r["b"] as Vector2).distance_to(r["a"]) > (wr["b"] as Vector2).distance_to(wr["a"]))):
				wr = r
		if _auto_done & (1 << 21) == 0 and not wr.is_empty():
			_auto_done |= 1 << 21
			player.position = Vector2((wr["a"] as Vector2).x + (60.0 if level.has("city") else -90.0), float(wr["top"]))   # (the city: the line starts at the window, he stands on the landing)
			_ground_y = player.position.y
			_grace = 99.0
		hud.move = 0.6 if _at > 0.5 and _at < 0.9 else 0.0
		if _at > 0.55 and _auto_done & (1 << 20) == 0:
			_auto_done |= 1 << 20
			hud.jump_tapped = true
		var kf := int((_at - 0.5) / 0.12)
		if kf >= 0 and kf < 20 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			_shot("film_%02d" % kf)
			print("WASH ", kf, " ", move_state, " ", Vector2i(player.position))
		if _at > 3.2:
			get_tree().quit()
		return
	elif _auto.begins_with("wallkick"):   # --test=wallkick[:up] --sandbox=1: a run at the lab's crate stack, a jump into it, a jump off it (:up = onto it), frames
		var bx := -1.0
		for k in boxes.size():
			if box_info[k]["kind"] == "stack":
				bx = boxes[k].position.x
				break
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			player.position = Vector2(bx - 520.0, 0.0)
			_grace = 99.0
		hud.move = 1.0 if _at > 0.3 and (_at < 1.2 or _auto.ends_with(":up")) else 0.0
		if bx - player.position.x < 330.0 and _auto_done & (1 << 20) == 0:
			_auto_done |= 1 << 20
			hud.jump_tapped = true
		if _wall_t > 0.0 and _auto_done & (1 << 19) == 0:
			_auto_done |= 1 << 19
			hud.jump_tapped = true
			print("WALLKICK at y ", int(player.position.y))
		var kf := int((_at - 0.6) / 0.1)
		if kf >= 0 and kf < 20 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			_shot("film_%02d" % kf)
		if _at > 2.4:
			print("WALLKICK end x ", int(player.position.x - bx), " state ", move_state)
			get_tree().quit()
		return
	elif _auto.begins_with("walkfrom:"):   # --test=walkfrom:x[:up]: from x on the pavement along to the right (:up = the stick up), the men away, frames
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			_grace = 99.0
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
			player.position = Vector2(float(_auto.split(":")[1]), 0.0)
			_ground_y = 0.0
			_works_px = player.position.x
		hud.move = 1.0 if _at > 0.6 else 0.0
		hud.up = _auto.ends_with(":up") and _at > 0.6
		var kw := int(_at / 0.4)
		if kw < 20 and _auto_done & (1 << kw) == 0 and _at > 0.6:
			_auto_done |= 1 << kw
			_shot("walk_%02d" % kw)
			print("WALK x ", int(player.position.x), " y ", int(player.position.y), " ", move_state, " out ", _works_out)
		if _at > 4.4:
			get_tree().quit()
		return
	elif _auto.begins_with("alcove"):   # --test=alcove[:shoot] (the playground): the last doorway, in with the stick up, the men up the street; :shoot - out, a shot, back
		var ax := 0.0
		for a2 in _alcoves:
			if absf(float(a2["x"]) - _alc_want()) < absf(ax - _alc_want()):
				ax = float(a2["x"])
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			player.position = Vector2(ax - 250.0, 0.0)
			_ground_y = 0.0
		hud.move = 1.0 if _at > 0.5 and _at < 0.75 else 0.0
		hud.up = _at > 0.8 and _at < 1.0
		if ":shoot" in _auto and _at > 3.0 and _at < 3.1:
			hud.fire_tapped = true
		var ka := int(_at / 0.5)
		if ka < 14 and _auto_done & (1 << ka) == 0 and _at > 0.6:
			_auto_done |= 1 << ka
			_shot("alcove_%02d" % ka)
			var seen := 0
			for e in enemies:
				if e["alive"] and e["seen"] and absf(e["node"].position.x - ax) < 2500.0:
					seen += 1
			print("ALCOVE x ", int(player.position.x), " in ", _alcove, " seen ", seen, " hp ", hp, " covered ", _player_covered(1.0))
		if _at > 6.5:
			get_tree().quit()
		return
	elif _auto == "doorkick":   # --test=doorkick (a map with a flat): the shut door, a run at it, the kick, frames
		var f0: Dictionary = _flats[0]
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			_grace = 99.0
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
			player.position = Vector2(float(f0["hinge"]) - 620.0, float(f0["y"]))
			_ground_y = player.position.y
			move_state = "ground"
		hud.move = 1.0 if _at > 0.9 else 0.0
		if _at > 1.3 and not f0["open"]:
			_kick_door(f0)
		var kd := int(_at / 0.15)
		if kd < 20 and _auto_done & (1 << kd) == 0 and _at > 0.6:
			_auto_done |= 1 << kd
			_shot("door_%02d" % kd)
		if _at > 3.0:
			get_tree().quit()
		return
	elif _auto.begins_with("propshot"):   # --test=propshot:x,y : Frank a step left of x, a bullet into the street thing at (x, y), frames
		var at := _auto.trim_prefix("propshot:").split(",")
		if _auto_done & (1 << 21) == 0:   # (a flag, not _at: the first frame after loading can be long)
			_auto_done |= 1 << 21
			player.position = Vector2(float(at[0]) + (700.0 if float(at[1]) < -1000.0 else -700.0), 0.0)   # (up on the roofs he comes from the right)
			if float(at[1]) < -1000.0:
				player.position.y = _floor_at(player.position.x, -3000.0)
				_ground_y = player.position.y
			_grace = 99.0
			for e in enemies:
				e["seen"] = false
		if _at > 0.5 and _auto_done & (1 << 20) == 0:
			_auto_done |= 1 << 20
			for it in props.items:   # where the street things stand (their rect centres: the x,y to aim at)
				print("PROP ", it["kind"], " ", Vector2i((it["rect"] as Rect2).get_center()))
			props.shot(Vector2(float(at[0]), float(at[1])))
		var kf := int((_at - 0.4) / 0.12)
		if kf >= 0 and kf < 20 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			_shot("film_%02d" % kf)
		if _at > 2.6:
			get_tree().quit()
		return
	elif _auto.begins_with("winexit"):   # --test=winexit:x (in a room with ROOM_EXIT_WINDOW): walk into the glass, then jump through it
		var wx := float(_auto.trim_prefix("winexit:"))
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			player.position = Vector2(wx, 0.0)
			_ground_y = 0.0
			_grace = 99.0
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
		hud.move = 1.0 if _at > 0.4 else 0.0
		if _at > 1.5 and _at < 1.55:
			_jump_buf = 0.15
		for k in 16:
			if _at > 1.5 + k * 0.09 and _auto_done & (1 << k) == 0:
				_auto_done |= 1 << k
				print("WIN t ", snappedf(_at, 0.01), " x ", int(player.position.x), " y ", int(player.position.y), " ", move_state, " room ", _room)
				_shot("win_%d" % k)
		if _at > 3.0:
			get_tree().quit()
		return
	elif _auto.begins_with("flatwin"):   # --test=flatwin[:k] (a map with flats): in the k-th flat, run at its window and jump through
		if _flats.is_empty():
			print("FLATWIN no flats on this map")
			get_tree().quit()
			return
		var fwi: Dictionary = _flats[int(_auto.trim_prefix("flatwin:")) if _auto.contains(":") else 0]
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			fwi["open"] = true
			player.position = Vector2(float(fwi["wx0"]) - 700.0, float(fwi["y"]))
			_ground_y = player.position.y
			_grace = 99.0
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
		hud.move = 1.0 if _at > 0.4 else 0.0
		if player.position.x > float(fwi["wx0"]) - 330.0 and _auto_done & (1 << 22) == 0:
			_auto_done |= 1 << 22
			_jump_buf = 0.15
		var kw := int((_at - 0.8) / 0.12)
		if kw >= 0 and kw < 20 and _auto_done & (1 << kw) == 0:
			_auto_done |= 1 << kw
			print("FLATWIN t ", snappedf(_at, 0.01), " x ", int(player.position.x), " y ", int(player.position.y), " ", move_state, " broken ", fwi["broken"], " wx0 ", int(fwi["wx0"]))
			if kw % 3 == 0: _shot("flatwin_%02d" % kw)
		if _at > 3.4:
			get_tree().quit()
		return
	elif _auto.begins_with("awning"):   # --test=awning:x,y (a fire escape landing): off it to the left onto the awning
		var at := _auto.trim_prefix("awning:").split(",")
		if _auto_done & (1 << 21) == 0:
			_auto_done |= 1 << 21
			player.position = Vector2(float(at[0]), float(at[1]))
			_ground_y = player.position.y
			_grace = 99.0
		hud.move = -1.0 if _at > 0.6 and _at < 1.6 else 0.0
		var kf := int((_at - 0.8) / 0.15)
		if kf >= 0 and kf < 20 and _auto_done & (1 << kf) == 0:
			_auto_done |= 1 << kf
			print("AWNING t ", snappedf(_at, 0.01), " y ", int(player.position.y), " fall ", int(fall), " ", move_state, " ts ", Engine.time_scale)
			_shot("film_%02d" % kf)
		if _at > 4.0:
			get_tree().quit()
		return
	elif _auto == "tour":   # visit the map's set pieces and take a picture of each: stairs, a landing, a room, a barrel going up
		if _tour.is_empty():
			if ramps.size() > 0:
				var r: Array = ramps[0]
				_tour.append(["stairs", lerpf(r[0], r[2], 0.7)])
			for c in catwalks:
				if c.position.y < -500.0:
					_tour.append(["landing", c.position.x + c.size.x * 0.5])
					break
			for r in rooms:
				_tour.append(["room_" + String(r[2]), lerpf(float(r[0]), float(r[1]), 0.45)])
			for k in boxes.size():
				if box_info[k]["kind"] == "barrel":
					_tour.append(["barrel", boxes[k].position.x - 650.0, k])
					break
			_tour.append(["end", level_end])
		var step := int(_at / 1.3)
		if step < _tour.size():
			var spot: Array = _tour[step]
			var t := fmod(_at, 1.3)
			if t < 0.05:
				player.position = Vector2(spot[1], _floor_at(spot[1], -3000.0))
				move_state = "ground"
				cam.position = Vector2(player.position.x + _lead, CAM_Y + clampf(player.position.y * 0.45, -330.0, 0.0))
			if spot[0] == "barrel" and t > 0.5 and _auto_done & (1 << 20) == 0:
				_auto_done |= 1 << 20
				for k in boxes.size():
					if box_info[k]["kind"] == "barrel":
						_explode(boxes[k].get_center(), k)
						break
			if t > (0.62 if spot[0] == "barrel" else 1.1) and _auto_done & (1 << step) == 0:
				_auto_done |= 1 << step
				_shot("tour_%d_%s" % [step, spot[0]])
		else:
			get_tree().quit()
		return
	elif _auto == "stand":   # the prologue's last stand, to its end
		if _at < 0.05:
			player.position.x = float(level["stand"]) + 60.0
			cam.position.x = player.position.x + _lead
		hud.move = 1.0 if _at < 0.5 else 0.0
		var near = _nearest_enemy()
		if near != null and int(_at * 10) % 3 == 0:
			hud.fire_tapped = true
		if _at > 3.2 and hp > 1:
			hp = 1
		shots = [[2.8, "stand_1"], [5.0, "stand_2"], [9.5, "stand_3"]]
		for i in shots.size():
			if _auto_done & (1 << (i + 8)) == 0 and _at > float(shots[i][0]):
				_auto_done |= 1 << (i + 8)
				_shot(shots[i][1])
		if _at > 10.0:
			get_tree().quit()
		return
	elif _auto == "caption":
		if _auto_done & 1 == 0 and _at > 0.2:
			_auto_done |= 1
			hud.caption(level["outro"] if chapter == 0 else level["intro"])
			hud.boss_bar("MICKEY 'CANVAS' TEAGUE", 0.7)
		shots = [[4.5, "caption"]]
	elif _auto == "lineup":   # --test=lineup: every kind of man side by side in the street, Frank at the left (outfits, 18. 11.)
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0 and _at > 0.3:
			_auto_done |= 1
			for e in enemies:
				e["alive"] = false
				e["node"].visible = false
			player.position = Vector2(2000.0, 0.0)
			var kinds := ["post", "tommy", "shotgun", "boss"]
			for i in kinds.size():
				var e := _add_enemy(Vector2(2450.0 + i * 330.0, 0.0), kinds[i], "post", 2450.0 + i * 330.0)
				e["cool"] = 999.0
				e["timer"] = 999.0
				e["role"] = "post"
			cam.position.x = 2700.0
		if _at > 0.3:
			cam.position.x = 2700.0
		if _at > 0.4 and ARGS.has("--shieldoff"):   # (Briggs's shield torn off, QUEUE §16 D)
			for e in enemies:
				if e["alive"] and e["boss"] and e.has("shield"):
					_shield_off(e)
		shots = [[0.9, "lineup"], [1.4, "lineup_b"]]
		if _at > 1.6:
			get_tree().quit()
	elif _auto == "hud":   # the HUD plate in its worst case: two guns, an empty gun, a long narration and a hint
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0 and _at > 0.4:
			_auto_done |= 1
			hud.set_guns("revolver", "tommy")
			hud.hint("Tap the rounds to reload.")
			hud.caption(["The rain came down like it had a grudge against the whole city.", "I knew the feeling.", "Somebody in this street had a gun and a reason."])
		if _at > 0.4:
			mag = 0   # the gun empty: the plate's TAP TO RELOAD must stay clear of the gun card
		shots = [[1.6, "hud_1"], [4.6, "hud_2"], [6.7, "hud_3"], [11.0, "hud_4"]]
		if _at > 11.4:
			get_tree().quit()
	elif _auto == "stains":   # eight hits along the wall, then look at them once the runs have crept down
		var sx0: float = 1150.0
		for seg in level["street"]:   # in front of the church railings, if this map has them
			if String(seg[0]) == "church":
				sx0 = float(seg[1]) + 900.0
		if _at < 0.05:
			player.position.x = sx0
			cam.position.x = player.position.x + _lead
		if _at > 0.3 and _auto_done & 1 == 0:
			_auto_done |= 1
			for i in 14:
				fx.blood(Vector2(sx0 - 200.0 + i * 150.0, -200.0 - (i % 4) * 90.0), Vector2(1.0 if i % 2 == 0 else -1.0, 0.0))
		shots = [[0.5, "stains_1"], [2.2, "stains_2"]]
	elif _auto.begins_with("deep"):   # --test=deep[:art]: the camera left of, on and right of a deep view (that drawing's, else the first): it must not move against its wall
		var want := _auto.trim_prefix("deep").trim_prefix(":")   # (deep:all - every deep view on the map, three shots each)
		var cx: float = deeps[0]["center"].x if not deeps.is_empty() else 3000.0
		var j := mini(int(_at / 3.0), maxi(deeps.size() - 1, 0)) if want == "all" else 0
		if want == "all" and not deeps.is_empty():
			cx = deeps[j]["center"].x
		else:
			for dp in deeps:
				if want == "" or String(dp["art"]) == want:
					cx = dp["center"].x
					break
		var k := int(fmod(_at, 3.0))
		player.position.x = cx + [-700.0, 0.0, 700.0][k]
		cam.position.x = player.position.x + 200.0
		_grace = 99.0
		if want == "all":
			for d in deeps.size():
				for kk in 3:
					shots.append([d * 3.0 + kk + 0.9, "deep_%d_%s_%d" % [d, deeps[d]["art"], kk + 1]])
		else:
			shots = [[0.9, "deep_1"], [1.9, "deep_2"], [2.9, "deep_3"]]
	elif _auto == "vault":   # running at a low crate: the speed vault over it, frame by frame
		var bi := -1
		for k in boxes.size():
			if box_info[k]["wood"] and boxes[k].size.y < 270.0:
				bi = k
				break
		if _at < 0.05 and bi >= 0:
			for e in enemies:
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
			player.position.x = boxes[bi].position.x - 900.0
			cam.position.x = player.position.x + _lead
		hud.move = 1.0 if _at < 2.2 else 0.0
		hp = max_hp
		shots = [[0.9, "vault_1"], [1.0, "vault_2"], [1.1, "vault_3"], [1.2, "vault_4"], [1.3, "vault_5"], [1.4, "vault_6"], [1.5, "vault_7"], [1.6, "vault_8"]]
	elif _auto == "bullets":   # a close look at shots in flight, at speed and in slowed time
		if _auto_done & 1 == 0:
			_auto_done |= 1
			hud.visible = false
			for e in enemies:
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
		var chest: Vector2 = player.position + SHOULDER
		for k in [[0.5, 2], [1.5, 8]]:
			if _at > k[0] and _auto_done & k[1] == 0:
				_auto_done |= k[1]
				fx.shoot(chest + Vector2(90.0, 0.0), Vector2(BULLET_SPEED, -40.0), true)
				fx.shoot(chest + Vector2(1500.0, -30.0), Vector2(-BULLET_SPEED, 30.0), false)
		if _at > 1.2 and _auto_done & 4 == 0:
			_auto_done |= 4
			slow_on = true
			slow_left = 1.0
		shots = [[0.56, "bullets_1"], [1.62, "bullets_2"], [1.8, "bullets_3"]]
	elif _auto == "reload":   # the revolver emptied and loaded again, close up
		if _auto_done & 1 == 0:
			_auto_done |= 1
			for e in enemies:
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
			hud.visible = false
		cam.zoom = Vector2.ONE * 1.1
		cam.rotation = 0.0
		cam.position = player.position + Vector2(60.0, -330.0)
		if _at > 0.4 and _auto_done & 2 == 0:
			_auto_done |= 2
			mag = 0
			_start_reload()
		shots = [[0.55, "reload_1"], [0.75, "reload_2"], [1.0, "reload_3"], [1.12, "reload_4"]]
	elif _auto == "wound":   # a mobster shot in the chest and the thigh, close up: the hits must show
		var e: Dictionary = enemies[0]
		var m = e["node"]
		if _auto_done & 1 == 0:
			_auto_done |= 1
			for o in enemies.slice(1):
				o["node"].position.x += 60000.0
			e["state"] = "post"
			e["hp"] = 99
			m.visible = true
			m.position = Vector2(1400.0, 0.0)
			player.position.x = 600.0
			hud.visible = false
		cam.zoom = Vector2.ONE * 1.0
		cam.rotation = 0.0
		cam.position = m.position + Vector2(0.0, -320.0)
		hp = max_hp
		if _at > 0.5 and _auto_done & 2 == 0:
			_auto_done |= 2
			var tb: Array = m._bones["torso"]
			_bullet_hit(m.to_global((tb[0] + tb[1]) * 0.5), true)
		if _at > 0.62 and _auto_done & 4 == 0:
			_auto_done |= 4
			_shot("wound_1")
		if _at > 1.1 and _auto_done & 8 == 0:
			_auto_done |= 8
			var lb: Array = m._bones["thigh_f"] if m._bones.has("thigh_f") else m._bones["torso"]
			_bullet_hit(m.to_global(lb[0].lerp(lb[1], 0.6)), true)
		if _at > 1.22 and _auto_done & 16 == 0:
			_auto_done |= 16
			_shot("wound_2")
		if _at > 2.6 and _auto_done & 32 == 0:
			_auto_done |= 32
			_shot("wound_3")
		if _at > 2.8:
			get_tree().quit()
		return
	elif _auto == "crane":   # the crate on the crane's chains: shot down onto the two under it
		var c: Dictionary = sets._crates[0]
		if _at < 0.05 or _auto_done & 1 == 0:
			_auto_done |= 1
			player.position.x = c["sprite"].position.x - 900.0
			cam.position.x = player.position.x + _lead
		hp = max_hp
		if _at > 1.0 and _auto_done & 2 == 0:
			_auto_done |= 2
			sets.bullet((c["chains"] as Rect2).get_center())
		if _at > 1.35 and _auto_done & 4 == 0:
			_auto_done |= 4
			_shot("crane_1")
		if _at > 2.6 and _auto_done & 8 == 0:
			_auto_done |= 8
			_shot("crane_2")
		if _at > 2.9:
			get_tree().quit()
		return
	elif _auto == "tops":   # stand on every bit of cover in turn, then lean on its side, and take a picture of each
		hud.visible = false
		var k := int(_at / 1.2)
		var idx := k / 2
		if idx >= boxes.size() or idx >= 14:
			get_tree().quit()
			return
		hp = max_hp
		for e in enemies:
			e["node"].visible = false
			e["alive"] = false
		var b: Rect2 = boxes[idx]
		if _auto_done & (1 << k) == 0:
			_auto_done |= 1 << k
			move_state = "ground"
			player.position = Vector2(b.get_center().x, b.position.y - 2.0) if k % 2 == 0 else Vector2(b.position.x - 40.0, 0.0)
			fall = 0.0
		cam.position = Vector2(b.get_center().x, b.position.y - 150.0)
		cam.zoom = Vector2.ONE * 1.1
		if fmod(_at, 1.2) > 1.0 and _auto_done & (1 << (k + 32)) == 0:
			_auto_done |= 1 << (k + 32)
			print("tops ", idx, " ", box_info[idx]["kind"], " ", b, " feet ", player.position)
			_shot("tops_%02d" % k)
	elif _auto.begins_with("bulbs:"):   # --test=bulbs:x: stand in a room, picture, shoot out its bulbs, picture
		var x := float(_auto.trim_prefix("bulbs:"))
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0:
			_auto_done |= 1
			player.position = Vector2(x, 0.0)
			for e in enemies:
				e["alive"] = false
				e["node"].visible = false
		cam.position.x = player.position.x + _lead
		if _at > 1.5 and _auto_done & 2 == 0:
			_auto_done |= 2
			_shot("bulbs_0")
		if _at > 1.8 and _auto_done & 8 == 0:
			_auto_done |= 8
			for i in lamps.size():
				if lamp_info[i].has("off") and absf(lamps[i].x - x) < 1400.0:
					_lamp_out(i)
		if _at > 3.0 and _auto_done & 4 == 0:
			_auto_done |= 4
			_shot("bulbs_1")
			get_tree().quit()
		return
	elif _auto.begins_with("fall:"):   # --test=fall:x[,player]: everyone near x dies, one of each fall, pictures
		var parts := _auto.trim_prefix("fall:").split(",")
		var x := float(parts[0])
		hp = max_hp
		_grace = 99.0
		cam.position.x = x
		if _auto_done & 1 == 0:
			_auto_done |= 1
			player.position = Vector2(x - 900.0, 0.0)
		if _at > 1.0 and _auto_done & 2 == 0:
			_auto_done |= 2
			var hows := ["head", "blast", "leg", "", "head", ""]
			var k := 0
			for e in enemies:
				if e["alive"] and e["state"] != "wait" and absf(e["node"].position.x - x) < 1300.0:
					e["node"].visible = true
					print("FALL ", hows[k % hows.size()], " from ", e["node"].position)
					_kill(e, hows[k % hows.size()] == "head", true, "thigh_f" if hows[k % hows.size()] == "leg" else ("blast" if hows[k % hows.size()] == "blast" else "torso"))
					k += 1
			if parts.size() > 1:
				player.position = Vector2(x, _floor_at(x, -2000.0))
				hp = 1
				_player_down()
		for i in 3:
			if _at > 1.15 + i * 0.25 and _auto_done & (4 << i) == 0:
				_auto_done |= 4 << i
				_shot("fall_%d" % i)
		if _at > 2.9:
			for bi in boxes.size():
				if absf(boxes[bi].get_center().x - x) < 1600.0:
					print("BOX ", box_info[bi]["kind"], " ", boxes[bi])
			for e in enemies:
				if not e["alive"] and absf(e["node"].position.x - x) < 1600.0:
					print("LIES at ", e["node"].position, " rot ", snappedf(e["node"].rotation, 0.01), " floor ", _floor_at(e["node"].position.x, e["node"].position.y + 40.0))
			cam.zoom = Vector2.ONE * 0.62
			cam.position = Vector2(x, -300.0)
			_shot("fall_end")
			get_tree().quit()
		return
	elif _auto.begins_with("pin:"):   # --test=pin:i: crouch behind cover box i and stay there; log what the squad does
		var b: Rect2 = boxes[int(_auto.trim_prefix("pin:"))]
		_grace = 0.0
		if _auto_done & 1 == 0:
			_auto_done |= 1
			player.position = Vector2(b.position.x - 70.0, 0.0)
			move_state = "ground"
		player.position.x = b.position.x - 70.0
		player.duck = 1.0
		_demo_duck = true
		hp = max_hp
		cam.position.x = player.position.x + 500.0
		for i in 6:
			if _at > 2.0 + i * 2.2 and _auto_done & (2 << i) == 0:
				_auto_done |= 2 << i
				var st := []
				for e in enemies:
					if e["alive"] and absf(e["node"].position.x - player.position.x) < 2200.0:
						st.append("%s/%s@%d" % [e["role"], e["state"], int(e["node"].position.x)])
				print("PIN t=", snappedf(_at, 0.1), " hits ", stats["hits"], " cover ", snappedf(_cover_t, 0.1), " ", st)
				_shot("pin_%d" % i)
		if _at > 15.0:
			get_tree().quit()
		return
	elif _auto == "fxsheet":   # --test=fxsheet: each new effect on an empty street, a picture of each
		hp = max_hp
		_grace = 99.0
		if _at < 0.05:
			for e in enemies:
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
		var c: Vector2 = player.position + Vector2(300.0, -200.0)
		var steps := [[0.6, "muzzle"], [0.9, "shotgun"], [1.2, "spark"], [1.5, "smoke"], [2.4, "dust"], [2.8, "blast"], [5.0, "blood"], [5.6, "bullet"]]
		for i in steps.size():
			var bit := 1 << (1 + i)
			if _at > float(steps[i][0]) and _auto_done & bit == 0:
				_auto_done |= bit
				match String(steps[i][1]):
					"muzzle": fx.muzzle(c, Vector2.RIGHT, "")
					"shotgun": fx.muzzle(c + Vector2(0, 120), Vector2.RIGHT, "shotgun")
					"spark":
						for k in 3: fx.spark(c + Vector2(200.0 + k * 150.0, 100.0))
					"smoke": fx.smoke(c, Vector2(60, -90), 0.5, 1.2)
					"dust": fx.dust(player.position + Vector2(300.0, 0.0), 0.6)
					"blast": fx.blast(c + Vector2(500.0, 100.0))
					"blood": fx.blood(c + Vector2(300.0, 0.0), Vector2.RIGHT, true)
					"bullet":
						Engine.time_scale = 0.15
						fx.shoot(c, Vector2(2600.0, 0.0), true)
			for dt in [0.04, 0.35]:
				var b2 := 1 << (10 + i * 2 + (0 if dt < 0.1 else 1))
				if _at > float(steps[i][0]) + dt and _auto_done & b2 == 0:
					_auto_done |= b2
					_shot("fx_%s_%d" % [steps[i][1], 0 if dt < 0.1 else 1])
		if _at > 6.1:
			get_tree().quit()
	elif _auto == "coatdive":   # --test=coatdive: a dive out of a run, then standing again: the coat must be back
		hp = max_hp
		_grace = 99.0
		if _at < 0.05:
			for e in enemies:
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
		hud.move = 1.0 if _at < 1.2 else 0.0
		if _at > 0.6 and _auto_done & 1 == 0:
			_auto_done |= 1
			hud.jump_tapped = true
		if _at > 0.75 and _auto_done & 2 == 0:
			_auto_done |= 2
			hud.dive_tapped = true
		for i in 6:
			var bit := 1 << (2 + i)
			if _at > 0.9 + i * 0.6 and _auto_done & bit == 0:
				_auto_done |= bit
				print("COAT t=", snappedf(_at, 0.1), " mesh ", player._skirt_mesh.visible, " a ", snappedf(player._skirt_mesh.self_modulate.a, 0.01), " dive ", snappedf(player.dive, 0.01))
				_shot("coat_%d" % i)
		if _at > 4.4:
			get_tree().quit()
	elif _auto == "jumpseq":   # --test=jumpseq: a running jump, a picture every tenth of a second
		hp = max_hp
		_grace = 99.0
		if _at < 0.05:
			for e in enemies:
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
		hud.move = 1.0 if _at < 2.6 else 0.0
		if _at > 0.8 and _auto_done & 1 == 0:
			_auto_done |= 1
			hud.jump_tapped = true
		for i in 12:
			var bit := 1 << (1 + i)
			if _at > 0.8 + i * 0.09 and _auto_done & bit == 0:
				_auto_done |= bit
				_shot("jump_%02d" % i)
		if _at > 2.0:
			get_tree().quit()
	elif _auto == "bag":   # --test=bag: a shotgun and a tommy picked up, then switched to: the HUD each time
		hp = max_hp
		_grace = 99.0
		for e in enemies:
			e["alive"] = false
			e["node"].visible = false
		var steps := [[0.8, "shotgun"], [1.4, "tommy"], [2.0, "switch"], [2.6, "switch"], [3.2, "switch"]]
		for i in steps.size():
			var bit := 1 << (1 + i)
			if _at > float(steps[i][0]) and _auto_done & bit == 0:
				_auto_done |= bit
				if steps[i][1] == "switch":
					if i == 4:
						_swap_offer = null   # walked off the dropped gun: a plain change between the two he carries
					_switch_gun()
				else:
					_add_pickup(String(steps[i][1]), player.position)
					_pickups()
			if _at > float(steps[i][0]) + 0.4 and _auto_done & (bit << 8) == 0:
				_auto_done |= bit << 8
				_shot("bag_%d" % i)
			if steps[i][1] == "switch":   # the change itself, a picture every 0.07 s
				for k in 5:
					var kb := 1 << (20 + (i - 2) * 5 + k)
					if _at > float(steps[i][0]) + 0.035 + k * 0.07 and _auto_done & kb == 0:
						_auto_done |= kb
						_shot("swap_%d_%d" % [i, k])
		if _at > 4.0:
			print("BAG weapon ", weapon, " bag ", _bag.keys())
			get_tree().quit()
	elif _auto == "aicover":   # he crouches behind a crate in front of a group: do they shoot the crate, go round?
		hp = max_hp
		if _aic < 0 and _at > 0.3 and _at < 0.4:
			var best := -1
			for i in boxes.size():
				if not box_info[i].get("wood", false) or boxes[i].end.y < -5.0 or boxes[i].position.x < 2500.0:
					continue
				var n := 0
				for e in enemies:
					var dx: float = e["node"].position.x - boxes[i].end.x
					if e["state"] == "post" and dx > 150.0 and dx < 2100.0 and e["node"].position.y == 0.0:
						n += 1
				if n >= 3:
					best = i
					break
			if best >= 0:
				player.position.x = boxes[best].position.x - 60.0
				_aic = best
				var put := [450.0, 800.0, 1150.0]
				var k := 0
				for e in enemies:   # a group of three on the far side of his crate, and nobody else near
					if absf(e["node"].position.x - player.position.x) > 3000.0 or e["node"].position.y != 0.0:
						continue
					if k < 3 and e["type"] == "post" and e["state"] == "post":
						e["node"].position.x = boxes[best].end.x + put[k]
						e["goal"] = e["node"].position.x
						e["cover"] = _has_cover(e["node"].position)
						k += 1
					else:
						e["node"].position.x = 99999.0 + e["id"] * 400.0
						e["state"] = "wait"
						e["trig"] = 999999.0
				print("AICOVER crate at ", int(boxes[best].position.x), " hp ", box_info[best]["hp"])
		hud.duck = _aic >= 0
		_grace = 0.0
		if fmod(_at, 1.0) < 0.034:
			var states := []
			for e in enemies:
				if e["alive"] and absf(e["node"].position.x - player.position.x) < 2200.0:
					states.append("%s:%s@%d" % [e["type"], e["state"], int(e["node"].position.x)])
			var hpx: String = str(box_info[_aic]["hp"]) if _aic >= 0 and _aic < box_info.size() else "gone"
			print("AICOVER t ", int(_at), " cover_t ", snappedf(_cover_t, 0.1), " crate ", hpx, " hp ", hp, " ", states)
		shots = [[3.0, "aic_0"], [5.5, "aic_1"], [8.6, "aic_2"], [9.6, "aic_3"]]
		if _at > 10.0:
			get_tree().quit()
	elif _auto in ["el", "fog", "oncoming", "sheets", "girder", "storm", "rock", "steam", "rats", "neon", "freight", "sea", "flood", "neondrop", "levelup", "searchlight"]:   # the map set pieces (mapfx.gd, setpieces.gd), pictured as they happen
		hp = max_hp
		_grace = 99.0
		if _at < 0.05:
			if _auto == "el":
				mapfx._el_t = 0.3
				if ARGS.has("--indoors") and not rooms.is_empty():   # the train goes over a room: no pull-back in there
					player.position.x = float(rooms[0][0]) + 400.0   # (not on a diary page: reading pauses the test)
			elif _auto == "fog":
				mapfx._fog_phase = 2
				mapfx._fog_t = 99.0
				mapfx.fog = 1.0
			elif _auto == "searchlight" and not sets._beams.is_empty():
				player.position.x = (sets._beams[0]["swivel"] as Vector2).x - 250.0
				for e in enemies:
					e["node"].position.x += 90000.0
					e["goal"] = e["node"].position.x
			elif _auto == "levelup":
				hud.level_up(8)
			elif _auto == "storm":
				mapfx._storm_t = 0.3
			elif _auto == "steam":
				mapfx._steam_t = 0.3
			elif _auto == "freight":
				mapfx._freight_t = 0.3
			elif _auto == "sea":
				mapfx._wave_t = 0.6
			elif _auto == "flood":
				mapfx._flood_t = 200.0
			elif _auto == "neondrop" and not mapfx._neon.is_empty():
				player.position.x = (mapfx._neon["root"] as Node2D).position.x - 700.0
			elif _auto == "girder":
				sets._beam_t = 2.0   # (the signal first, then its girder)
				sets._oncoming_t = 99.0
			elif _auto == "oncoming":
				sets._oncoming_t = 2.0
				sets._beam_t = 99.0
			elif _auto == "sheets" and not rooms.is_empty():
				for r in rooms:
					if String(r[2]) == "laundry":
						player.position.x = float(r[0]) + 1700.0   # beyond the sheets, the men behind them
						for e in enemies:
							if absf(e["node"].position.x - (float(r[0]) + 1300.0)) > 650.0:
								e["alive"] = false
								e["node"].visible = false
						break
		if _auto == "sheets" and ARGS.has("--drop") and _at > 0.8 and _at < 3.4 and not mapfx._sheets.is_empty():
			# --drop: a row of shots across the first sheet (its foot comes down), then seven into the next (it comes off its pegs)
			var kk := int((_at - 0.8) / 0.1)
			if kk != _drop_k:
				_drop_k = kk
				var sr: Rect2 = mapfx._sheets[0]["rect"]
				var uu := Vector2(160.0 + kk * 26.0, 470.0) if kk < 16 else Vector2(700.0 + (kk - 16) * 40.0, 300.0 + (kk % 3) * 120.0)
				if kk < 26:
					mag = 6   # (the test never reloads)
					reloading = 0.0
					_aim_point = sr.position + uu * mapfx.SHEET_SCALE
					player.scale.x = -absf(player.scale.x)
					_fire(player, true)
		elif _auto == "sheets" and _at > 0.8 and _at < 1.6 and fmod(_at, 0.25) < 0.04:   # a few shots through the sheets
			if not mapfx._sheets.is_empty():
				var sr: Rect2 = mapfx._sheets[0]["rect"]
				_aim_point = sr.get_center() + Vector2(140.0 + randf_range(-50.0, 50.0), randf_range(-90.0, 40.0))   # (through the middle of the nearest sheet)
				player.scale.x = -absf(player.scale.x)
			_fire(player, true)
		shots = {"el": [[1.6, "el_0"], [2.4, "el_1"], [3.2, "el_2"]], "fog": [[1.2, "fog_0"], [2.5, "fog_1"]],
			"oncoming": [[1.2, "onc_0"], [2.3, "onc_1"], [2.7, "onc_2"], [3.3, "onc_3"]], "sheets": [[0.6, "sheets_0"], [1.05, "sheets_m"], [2.0, "sheets_1"], [2.7, "sheets_2"], [3.3, "sheets_3"], [3.7, "sheets_4"], [5.0, "sheets_5"]],
			"girder": [[0.55, "signal_0"], [0.8, "signal_1"], [1.05, "signal_2"], [2.5, "girder_0"], [2.9, "girder_1"], [3.3, "girder_2"]],
			"storm": [[0.36, "storm_0"], [0.42, "storm_1"], [0.5, "storm_2"], [0.75, "storm_3"]], "rock": [[1.0, "rock_0"], [4.0, "rock_1"]], "steam": [[1.2, "steam_0"], [2.4, "steam_1"]],
			"rats": [[0.5, "rats_0"], [1.0, "rats_1"]], "freight": [[3.0, "freight_0"], [5.0, "freight_1"]], "sea": [[0.95, "sea_0"], [1.3, "sea_1"]],
			"flood": [[1.0, "flood_0"]], "neondrop": [[0.95, "neon_0"], [1.5, "neon_1"], [2.6, "neon_2"]], "levelup": [[0.6, "levelup_0"], [2.2, "levelup_1"]],
			"searchlight": [[0.4, "sl_0"], [1.3, "sl_1"], [2.2, "sl_2"], [2.9, "sl_3"]]}[_auto]
		if _auto == "neondrop" and _at > 1.0 and _at < 1.05 and not mapfx._neon.is_empty():
			mapfx._neon_drop()
	elif _auto == "hat":   # the nearest mobster with a hat: a bullet through the hat (found by hat_hit), pictures as it flies and lands
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0 and _at > 1.0:
			_auto_done |= 1
			var first = null
			for e in enemies:
				if e["state"] == "post" and e["node"].position.y == 0.0 and e["node"].hat_path() != "" and (first == null or e["node"].position.x < first["node"].position.x):
					first = e
			player.position = Vector2(first["node"].position.x - 700.0, 0.0)
			for e in enemies:
				if e != first:
					e["alive"] = false
					e["node"].visible = false
			var hs: Sprite2D = first["node"]._spr["head"]
			var hit := Vector2.INF
			for k in 200:   # walk up from the head's centre until the hat is there
				var p: Vector2 = hs.global_position + Vector2(0.0, -2.0 * k)
				if first["node"].hat_hit(p):
					hit = p
					break
			print("HAT hit point ", hit, " head ", first["node"].cfg.get("head_tex"), " tex ", hs.texture.get_size(), " off ", hs.offset, " gp ", hs.global_position, " gs ", hs.global_scale)
			for k in [0, 40, 80, 120, 160]:
				var p2: Vector2 = hs.global_position + Vector2(0.0, -2.0 * k)
				print("  k ", k, " part ", first["node"].hit_part(p2), " local ", hs.to_local(p2) - hs.offset)
			if hit != Vector2.INF:
				_hat_off(first, hit)
		cam.position.x = player.position.x + 350.0
		var htimes := [1.08, 1.3, 1.6, 2.4, 3.2]
		for i in htimes.size():
			var bit := 1 << (1 + i)
			if _at > htimes[i] and _auto_done & bit == 0:
				_auto_done |= bit
				_shot("hat_%d" % i)
		if _at > 3.4:
			get_tree().quit()
	elif _auto == "disarm":   # the nearest mobster's gun shot out of his hand: pictures as it flies and lands
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0 and _at > 1.0:
			_auto_done |= 1
			var first = null
			for e in enemies:
				if e["state"] == "post" and e["node"].position.y == 0.0 and (first == null or e["node"].position.x < first["node"].position.x):
					first = e
			player.position = Vector2(first["node"].position.x - 700.0, 0.0)
			for e in enemies:
				if e != first:
					e["alive"] = false
					e["node"].visible = false
			first["seen"] = true
			_disarm(first, first["node"]._gun.global_position)
		cam.position.x = player.position.x + 350.0
		var dtimes := [1.08, 1.25, 1.5, 2.2, 3.4]
		for i in dtimes.size():
			var bit := 1 << (1 + i)
			if _at > dtimes[i] and _auto_done & bit == 0:
				_auto_done |= bit
				_shot("disarm_%d" % i)
		if _at > 3.6:
			get_tree().quit()
	elif _auto == "give":   # the nearest mobster gives up: pictures as he raises his hands and as he backs off
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0:
			_auto_done |= 1
			var first = null
			for e in enemies:
				if e["state"] == "post" and e["node"].position.y == 0.0 and (first == null or e["node"].position.x < first["node"].position.x):
					first = e
			player.position = Vector2(first["node"].position.x - 700.0, 0.0)
			for e in enemies:
				if e != first:
					e["alive"] = false
					e["node"].visible = false
			first["seen"] = true
			first["hp"] = 1
			_give_up(first, 0.3)
		cam.position.x = player.position.x + 350.0
		var times := [1.2, 2.2, 3.4, 8.0]
		for i in times.size():
			var bit := 1 << (1 + i)
			if _at > times[i] and _auto_done & bit == 0:
				_auto_done |= bit
				_shot("give_%d" % i)
		if _at > 8.4:
			print("GIVE spared ", stats["spared"], " all down ", _all_down())
			get_tree().quit()
		return
	elif _auto == "mercy":   # --test=mercy: one man shot with his hands up while another sees it, the other let go, the card
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0:
			_auto_done |= 1
			var posts: Array = enemies.filter(func(e): return e["state"] == "post" and e["node"].position.y == 0.0)
			posts.sort_custom(func(a, b): return a["node"].position.x < b["node"].position.x)
			_mercy = [posts[0], posts[1]]
			player.position = Vector2(posts[0]["node"].position.x - 700.0, 0.0)
			posts[1]["node"].position.x = posts[0]["node"].position.x + 520.0
			for e in enemies:
				if e != posts[0] and e != posts[1]:
					e["alive"] = false
					e["node"].visible = false
			for e in _mercy:
				e["seen"] = true
				e["hp"] = 1
			_give_up(_mercy[0], 0.2)
		cam.position.x = player.position.x + 450.0
		var a: Dictionary = _mercy[0]
		if _at > 2.0 and _auto_done & 2 == 0:
			_auto_done |= 2
			var pos: Vector2 = a["node"].position + Vector2(0.0, -300.0)
			stats["executed"] += 1
			_executed(a, pos)
			a["hp"] = 0
			_kill(a, false, true, "chest")
		if _at > 3.6 and _auto_done & 4 == 0:
			_auto_done |= 4
			_give_up(_mercy[1], 0.2)
		var times := [2.25, 2.9, 4.6, 7.9, 9.4]
		for i in times.size():
			var bit := 1 << (4 + i)
			if _at > times[i] and _auto_done & bit == 0:
				_auto_done |= bit
				_shot("mercy_%d" % i)
		if _at > 8.6 and _auto_done & (1 << 12) == 0:
			_auto_done |= 1 << 12
			_rate()
		if _at > 10.0:
			print("MERCY spared ", stats["spared"], " executed ", stats["executed"], " ", stats["let_go"], stats["shot_up"])
			get_tree().quit()
		return
	elif _auto.begins_with("men:"):   # --test=men:hook / dynamite / sniper / shield / load: one of the chapter's men at work
		var what := _auto.trim_prefix("men:")
		if _auto_done & 1 == 0:
			_auto_done |= 1
			for e in enemies:
				e["alive"] = false
				e["node"].visible = false
			var x0 := 4200.0
			while _has_cover(Vector2(x0, 0.0)) or _room_at(x0) != "" or _has_cover(Vector2(x0 + 900.0, 0.0)):
				x0 += 300.0
			player.position = Vector2(x0, 0.0)
			if what == "load":
				var e2 := _add_enemy(Vector2(x0 + 800.0, 0.0), "post", "post", x0 + 800.0)
				e2["seen"] = true
				e2["cool"] = 99.0
				_place_loads()
			else:
				var e := _add_enemy(Vector2(x0 + (500.0 if what == "hook" else 900.0), 0.0), what, "post", x0 + 900.0)
				e["seen"] = true
				e["cool"] = 0.4
				if what == "shield":
					e["cool"] = 99.0
		_grace = 0.0
		hp = max_hp
		cam.position.x = player.position.x + 420.0
		if what == "load" and _at > 1.5 and _auto_done & 2 == 0:
			_auto_done |= 2
			for ld in _loads:
				_load_hit(Vector2(float(ld["x"]), float(ld["top"]) - 300.0))
		var times := [0.6, 1.0, 1.35, 1.7, 2.2, 3.0]
		for i in times.size():
			var bit := 1 << (2 + i)
			if _at > times[i] and _auto_done & bit == 0:
				_auto_done |= bit
				_shot("men_%s_%d" % [what, i])
		if _at > 3.2:
			print("MEN ", what, " hp ", hp, "/", max_hp, " sticks ", _sticks.size(), " loads ", _loads.size(), " boxes ", boxes.size())
			get_tree().quit()
		return
	elif _auto == "ricochet":   # aim at the nearest steel box in slowed time: the line, then the shot off it
		hp = max_hp
		_grace = 99.0
		if _auto_done & 1 == 0:
			_auto_done |= 1
			var best := -1
			for i in boxes.size():
				if not box_info[i]["wood"] and box_info[i]["kind"] != "barrel" and boxes[i].position.x > 2600.0 and (best < 0 or boxes[i].position.x < boxes[best].position.x):
					best = i
			_kick_target = best
			player.position = Vector2(boxes[best].position.x - 520.0, 0.0)
			for e in enemies:
				e["alive"] = false
				e["node"].visible = false
			slow_on = true
		var bx: Rect2 = boxes[int(_kick_target)]
		slow_on = true
		slow_left = 1.0
		_test_aim = Vector2(bx.position.x + 4.0, bx.position.y + 30.0)
		cam.position.x = player.position.x + 420.0
		if _at > 1.4 and _auto_done & 2 == 0:
			_auto_done |= 2
			_shot("ricochet_line")
			_fire(player, true)
		if _at > 1.75 and _auto_done & 4 == 0:
			_auto_done |= 4
			_shot("ricochet_shot")
		if _at > 2.0:
			print("RICOCHET box ", box_info[int(_kick_target)]["kind"], " ", boxes[int(_kick_target)], " player ", player.position, " line ", _aim_line.visible if _aim_line else false, " pts ", _aim_line.points.size() if _aim_line else 0, " ts ", Engine.time_scale, " diff ", diff_step, " ch ", chapter, " over ", over, " rel ", reloading)
			get_tree().quit()
		return
	elif _auto.begins_with("rope:"):   # --test=rope:climb / zip / swing: the first rope of that kind, used, in pictures
		var what := _auto.trim_prefix("rope:")
		var r = null
		for ro in _ropes:
			if ro["kind"] == what and r == null:
				r = ro
		if r == null:
			print("ROPE none of kind ", what)
			get_tree().quit()
			return
		_grace = 99.0
		hp = max_hp
		if _auto_done & 1 == 0:
			_auto_done |= 1
			for e in enemies:
				e["alive"] = false
				e["node"].visible = false
			var a: Vector2 = r["a"]
			if what == "climb":
				player.position = Vector2(a.x - 150.0, 0.0)
			elif what == "zip":
				player.position = Vector2(a.x - 260.0, float(r["top"]))
			else:
				player.position = Vector2(a.x - 800.0, 0.0)
			move_state = "ground"
			print("ROPE start ", player.position, " rope ", r["a"], " ", r["b"], " hang_top ", player.hang_top)
		hud.move = 1.0 if (what != "climb" or _at < 0.3) else 0.0
		if what == "climb" and _at > 0.35 and _auto_done & 2 == 0:
			_auto_done |= 2
			hud.jump_tapped = true
		if what == "swing" and move_state == "ground" and player.position.x > (r["a"] as Vector2).x - 110.0 and player.position.x < (r["a"] as Vector2).x - 40.0:
			hud.jump_tapped = true
		cam.position.x = player.position.x + 200.0
		var times := [0.5, 0.8, 1.1, 1.4, 1.7, 2.0, 2.4, 2.8, 3.4]
		for i in times.size():
			var bit := 1 << (2 + i)
			if _at > times[i] and _auto_done & bit == 0:
				_auto_done |= bit
				print("ROPE t ", times[i], " ", move_state, " at ", Vector2i(player.position), " rot ", snappedf(player.rotation, 0.01))
				_shot("rope_%s_%d" % [what, i])
		if _at > 3.6:
			get_tree().quit()
		return
	elif _auto == "kick":   # a dive into the nearest mobster: the kick, him on his back, what he does next
		hp = max_hp
		_grace = 99.0
		var first = null
		for e in enemies:
			if e["alive"] and (first == null or e["node"].position.x < first["node"].position.x) and e["node"].position.y == 0.0 and e["state"] == "post":
				first = e
		if _auto_done & 1 == 0:
			_auto_done |= 1
			player.position = Vector2(first["node"].position.x - 520.0, 0.0)
			for e in enemies:
				if e != first:
					e["alive"] = false
					e["node"].visible = false
			first["seen"] = true
			first["cool"] = 99.0
			_kick_target = first
		cam.position.x = player.position.x + 350.0
		if _at > 1.0 and _auto_done & 2 == 0:
			_auto_done |= 2
			_start_dive(1.0, 1.0, DIVE_SPEED.y, true)
		var times := [1.18, 1.5, 2.4, 3.9, 5.6]
		for i in times.size():
			var bit := 1 << (2 + i)
			if _at > times[i] and _auto_done & bit == 0:
				_auto_done |= bit
				print("KICK t ", times[i], " state ", _kick_target["state"], " x ", int(_kick_target["node"].position.x), " slide ", snappedf(_kick_target["node"].slide, 0.01))
				_shot("kick_%d" % i)
		if _at > 5.9:
			get_tree().quit()
		return
	elif _auto == "pipe":   # walk up on the nearest mobster: the pipe, frame by frame, and what he does after
		hp = max_hp
		_grace = 99.0
		var first = null
		for e in enemies:
			if e["alive"] and (first == null or e["node"].position.x < first["node"].position.x) and e["node"].position.y == 0.0 and e["state"] == "post" and not e.has("shield") \
					and not _has_cover(e["node"].position) and not _has_cover(e["node"].position - Vector2(400.0, 0.0)):
				first = e
		if _auto_done & 1 == 0:
			_auto_done |= 1
			player.position = Vector2(first["node"].position.x - 215.0, 0.0)
			for e in enemies:
				if e != first:
					e["alive"] = false
					e["node"].visible = false
			first["seen"] = true
			first["cool"] = 99.0
			_kick_target = first
		cam.position.x = player.position.x + 300.0
		hud.move = 1.0 if _pipe_t < 0.0 and _pipe_cool == 0.0 else 0.0
		var times := [0.0, 0.1, 0.17, 0.24, 0.31, 0.4, 1.0, 3.6]
		if _pipe_t >= 0.0 and _auto_done & 2 == 0:
			_auto_done |= 2
			_kick_at = _at
		if _auto_done & 2:
			for i in times.size():
				var bit := 1 << (3 + i)
				if _at > _kick_at + times[i] and _auto_done & bit == 0:
					_auto_done |= bit
					print("PIPE t ", times[i], " state ", _kick_target["state"])
					_shot("pipe_%d" % i)
		if _at > 7.0:
			get_tree().quit()
		return
	elif _auto.begins_with("look:"):   # --test=look:x1,x2,...: stand at each x for a moment, take a picture
		var xs := _auto.trim_prefix("look:").split(",")
		var k := int(_at / 2.6)
		if k >= xs.size():
			get_tree().quit()
			return
		hp = max_hp
		if _auto_done & (1 << (k + 16)) == 0:
			_auto_done |= 1 << (k + 16)
			if k == 0 and ARGS.has("--inner"):   # one hit from the end: the voice in his head
				_inner_voice()
			if k == 0 and ARGS.has("--shootlights"):   # every searchlight and hanging lamp in sight shot out
				get_tree().create_timer(0.8, false).timeout.connect(func() -> void:
					for b in sets._beams:
						sets.shoot_light(b["pivot"] + Vector2(0.0, 6.0))
					for i in lamps.size():
						if lamp_info[i]["on"] and absf(lamps[i].x - player.position.x) < 1500.0:
							_lamp_out(i))
			if k == 0 and ARGS.has("--boom"):   # the nearest red barrel goes up
				get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
					for bi in boxes.size():
						if box_info[bi]["kind"] == "barrel" and absf(boxes[bi].get_center().x - player.position.x) < 1600.0:
							_explode(boxes[bi].get_center(), bi)
							break)
			if k == 0 and ARGS.has("--smoke"):   # Kessler's canister, a second before the shot
				sets.smoke(Vector2(float(xs[0].split("@")[0]) + 700.0, 0.0))
			var at: PackedStringArray = xs[k].split("@")   # x@y: standing on whatever floor is under that height
			var feet := float(at[1]) if at.size() > 1 else -2000.0
			player.position = Vector2(float(at[0]), _floor_at(float(at[0]), feet))
			cam.position = Vector2(player.position.x + (0.0 if ARGS.has("--center") else _lead), CAM_Y + _cam_rise(player.position.y))
		if ARGS.has("--skydebug") and fmod(_at, 2.6) > 2.2 and _auto_done & (1 << (k + 8)) == 0:
			_auto_done |= 1 << (k + 8)
			var view := get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect()
			var sky_band := Rect2(view.position, Vector2(view.size.x, view.size.y * 0.4))
			for n in get_tree().root.find_children("*", "Sprite2D", true, false):
				var sp := n as Sprite2D
				if not sp.is_visible_in_tree() or sp.texture == null:
					continue
				var r := sp.get_global_transform() * sp.get_rect()
				if r.intersects(sky_band):
					print("SKY ", sp.get_path(), " ", sp.texture.resource_path, " z ", sp.z_index, " mod ", sp.modulate, " mat ", sp.material)
		for arg in ARGS:   # --probe=x,y: every visible drawing over that world point (what covers it)
			if arg.begins_with("--probe=") and fmod(_at, 2.6) > 2.2 and _auto_done & (1 << (k + 24)) == 0:
				_auto_done |= 1 << (k + 24)
				var pt := Vector2(float(arg.split("=")[1].split(",")[0]), float(arg.split("=")[1].split(",")[1]))
				for n in get_tree().root.find_children("*", "CanvasItem", true, false):
					var ci := n as CanvasItem
					if not ci.is_visible_in_tree():
						continue
					var hit := false
					if ci is Sprite2D and (ci as Sprite2D).texture != null:
						hit = (ci.get_global_transform() * (ci as Sprite2D).get_rect()).has_point(pt)
					elif ci is Polygon2D:
						hit = Geometry2D.is_point_in_polygon(ci.get_global_transform().affine_inverse() * pt, (ci as Polygon2D).polygon)
					if hit:
						var rr := (ci.get_global_transform() * (ci as Sprite2D).get_rect()) if ci is Sprite2D else Rect2()
						print("PROBE ", ci.get_path(), " ", ci.get_class(), " z ", ci.z_index, " mod ", ci.modulate, " ", (ci as Sprite2D).texture.resource_path if ci is Sprite2D else str((ci as Polygon2D).color), " rect ", rr, " poly ", (ci as Polygon2D).polygon if ci is Polygon2D else PackedVector2Array())
		if ARGS.has("--center"):   # gen/tests/audit_maps.py: the seam right in the middle
			cam.position.x = float(xs[k].split("@")[0])
		if ARGS.has("--high"):   # the camera as high as a jump off a stack takes it
			cam.position.y = CAM_Y - 330.0
		if fmod(_at, 2.6) > 2.3 and _auto_done & (1 << k) == 0:
			_auto_done |= 1 << k
			_shot("look_%d" % k)
		return
	elif _auto == "props":   # every group of cover on the map, seen wide: does it make sense where it stands?
		hud.visible = false
		if _at < 0.05:
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
			_prop_groups = []
			var xs := []
			for bx in boxes:
				if bx.end.y > -5.0:
					xs.append(bx.get_center().x)
			xs.sort()
			for x in xs:
				if _prop_groups.is_empty() or x - float(_prop_groups[-1]) > 1900.0:
					_prop_groups.append(x)
		var k := int(_at / 0.5)
		if k < _prop_groups.size():
			var x: float = float(_prop_groups[k]) + 700.0
			player.position = Vector2(x - 900.0, _floor_at(x - 900.0, -3000.0))
			move_state = "ground"
			cam.position = Vector2(x, CAM_Y - 150.0)
			cam.zoom = Vector2.ONE * 0.62
			if fmod(_at, 0.5) > 0.4 and _auto_done & (1 << k) == 0:
				_auto_done |= 1 << k
				_shot("props_%d_%d_%02d_%d" % [chapter, map, k, int(x)])
		else:
			get_tree().quit()
		return
	elif _auto == "rooms":   # each drawing of the street as he walks through it, one picture each, enemies away
		var segs: Array = level["street"]
		var k := int(_at / 1.2)
		if _at < 0.05:
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
		if k < segs.size():
			var x: float = float(segs[k][1]) + 1500.0
			player.position = Vector2(x, _floor_at(x, -3000.0))
			move_state = "ground"
			cam.position = Vector2(player.position.x + _lead, CAM_Y)
			if fmod(_at, 1.2) > 1.0 and _auto_done & (1 << k) == 0:
				_auto_done |= 1 << k
				_shot("room_%d_%s" % [k, String(segs[k][0])])
		else:
			get_tree().quit()
		return
	elif _auto == "cityview" or _auto == "citywalk":   # (QUEUE §21) the modular city: zoomed out over the whole block, one
		# picture every 4000 px / walked along the street at the play zoom, the men away, a picture every 1.2 s
		if _auto_done & (1 << 30) == 0:
			_auto_done |= 1 << 30
			_grace = 999.0
			for e in enemies:
				e["node"].position.x += 90000.0
				e["goal"] = e["node"].position.x
		if _auto == "cityview":
			hud.visible = false
			var k := int(_at / 0.6)
			var x := -2000.0 + k * 4000.0
			if x > level_end + 2000.0:
				get_tree().quit()
				return
			player.position.x = x
			cam.position = Vector2(x, -1250.0)
			cam.zoom = Vector2.ONE * 0.26
			if fmod(_at, 0.6) > 0.5 and _auto_done & (1 << k) == 0:
				_auto_done |= 1 << k
				_shot("cityview_%02d" % k)
			return
		hud.move = 1.0
		var kw := int(_at / 1.2)
		if _auto_done & (1 << kw) == 0 and _at > 0.5:
			_auto_done |= 1 << kw
			_shot("citywalk_%02d" % kw)
			print("CITYWALK x ", int(player.position.x), " end ", int(level_end), " ", move_state)
		if player.position.x > level_end - 300.0 or _at > 22.0:
			get_tree().quit()
		return
	elif _auto == "seams":   # the joins between street drawings, zoomed out, no HUD, one picture each
		hud.visible = false
		var segs: Array = level["street"]
		var k := int(_at / 0.6)
		if k < segs.size() - 1:
			var x: float = float(segs[k + 1][1])
			player.position.x = x - 1600.0
			cam.position = Vector2(x, CAM_Y - 260.0)
			cam.zoom = Vector2.ONE * 0.24
			if fmod(_at, 0.6) > 0.5 and _auto_done & (1 << k) == 0:
				_auto_done |= 1 << k
				_shot("seam_%d" % k)
		else:
			get_tree().quit()
		return
	elif _auto == "stunt":   # slowed time, a dive into a crate: the kick off it, the back flip, the landing
		var bi := -1
		for k in boxes.size():
			if box_info[k]["wood"] and boxes[k].size.y < 320.0:
				bi = k
				break
		if _at < 0.05 and bi >= 0:
			for e in enemies:   # an empty street for the picture
				e["node"].position.x += 60000.0
				e["goal"] = e["node"].position.x
			player.position.x = boxes[bi].position.x - 380.0
			cam.position.x = player.position.x + _lead
			slow_left = 1.0
			slow_on = true
		if _at > 0.5 and _auto_done & 1 == 0:
			_auto_done |= 1
			hud.dive_tapped = true
			hud.move = 1.0
		if _at > 0.6:
			hud.move = 0.0
		shots = [[0.62, "stunt_1"], [0.75, "stunt_2"], [0.9, "stunt_3"], [1.05, "stunt_4"], [1.2, "stunt_5"], [1.4, "stunt_6"], [1.65, "stunt_7"], [2.0, "stunt_8"]]
	elif _auto == "poses":   # the detective close up in each of his poses, and a mobster, for a look at the drawings
		const POSES := [["stand", Vector2(1, 0)], ["aim_up", Vector2(1, -1)], ["aim_back", Vector2(-1, -0.15)], ["run", Vector2(1, 0)],
				["duck", Vector2(1, 0)], ["jump", Vector2(1, 0.2)], ["dive", Vector2(1, 0.1)], ["slide", Vector2(1, -0.1)]]
		const GUNS_SEEN := ["revolver", "pistols", "tommy", "shotgun", "tommy", "revolver", "shotgun", "pistols"]
		var k := mini(int(_at / 0.8), POSES.size() - 1)
		var pose: String = POSES[k][0]
		hud.visible = false
		player.position = Vector2(-6500.0, 0.0)
		cam.zoom = Vector2.ONE * 1.25
		cam.rotation = 0.0
		cam.position = player.position + Vector2(0.0, -300.0)
		player.duck = 1.0 if pose == "duck" else 0.0
		player.air = 1.0 if pose == "jump" else 0.0
		player.dive = 1.0 if pose == "dive" else 0.0
		player.slide = 1.0 if pose == "slide" else 0.0
		player.slide_side = 1.0
		player.dive_side = 1.0
		player.position.y = -260.0 if pose in ["jump", "dive"] else 0.0
		cam.position = player.position + Vector2(210.0, -300.0 if pose not in ["jump", "dive"] else -420.0)
		if player.weapon != GUNS_SEEN[k]:
			player.set_weapon(GUNS_SEEN[k])
		if not enemies.is_empty():   # a mobster beside him in the same pose, for comparison
			var mob = enemies[0]["node"]
			enemies[0]["state"] = "wait"
			mob.visible = true
			mob.position = player.position + Vector2(420.0, 0.0)
			mob.duck = player.duck
			mob.air = player.air
			mob.dive = player.dive
			mob.slide = player.slide
			mob.set_state(-1.0 if pose == "run" else 0.0, Vector2(-POSES[k][1].x, POSES[k][1].y), delta)
		player.set_state(1.0 if pose == "run" else 0.0, POSES[k][1], delta)
		if fmod(_at, 0.8) > 0.7 and _auto_done & (1 << k) == 0:
			_auto_done |= 1 << k
			_shot("pose_%d_%s" % [k, pose])
		if _at > POSES.size() * 0.8 + 0.2:
			get_tree().quit()
	elif _auto == "kit":   # a crate shot apart, a gun run dry, the reload and the HUD rounds
		var wi := -1
		for k in boxes.size():
			if box_info[k]["wood"]:
				wi = k
				break
		if _at < 0.05 and wi >= 0:
			player.position.x = boxes[wi].get_center().x - 900.0
			cam.position.x = player.position.x + _lead
		if _at > 0.8 and _auto_done & 1 == 0 and wi >= 0:
			_auto_done |= 1
			for k in 12:
				if wi < boxes.size() and box_info[wi]["wood"]:
					_hit_box(wi, boxes[wi].get_center() + Vector2(-40.0, -30.0))
		if _at > 2.0 and _auto_done & 2 == 0:
			_auto_done |= 2
			mag = 1
			hud.fire_tapped = true
		if _at > 2.5 and _auto_done & 4 == 0:
			_auto_done |= 4
			hud.fire_tapped = true
		shots = [[0.84, "kit_1"], [0.95, "kit_2"], [1.2, "kit_3"], [1.9, "kit_4"], [2.55, "kit_5"], [2.9, "kit_6"], [3.6, "kit_7"]]
	elif _auto == "life":   # the living street: a flock, a shot that scares it, a hit, a muzzle flash, a neon sign
		var fx0: float = flocks[0]["birds"][0]["node"].position.x if not flocks.is_empty() else 3000.0
		if _at < 0.05:
			player.position.x = fx0 - 1000.0
			cam.position.x = player.position.x + _lead
		if _at > 1.0 and _auto_done & 1 == 0:
			_auto_done |= 1
			_fire(player, true)
		if _at > 2.2 and _auto_done & 2 == 0:
			_auto_done |= 2
			fx.blood(player.position + Vector2(700.0, -300.0), Vector2(1.0, -0.1), true)
		if _at > 2.6 and _auto_done & 4 == 0:
			_auto_done |= 4
			_fire(player, true)
		if _at > 3.0 and _auto_done & 8 == 0:
			_auto_done |= 8
			for seg in level["street"]:
				if String(seg[0]) in ["bluenote", "bluenote_row"]:
					player.position.x = float(seg[1]) + 800.0
					cam.position.x = player.position.x + _lead
					break
		shots = [[0.8, "life_1"], [1.2, "life_2"], [1.6, "life_3"], [2.24, "life_4"], [2.4, "life_5"], [2.64, "life_6"], [3.6, "life_7"], [4.4, "life_8"]]
	elif _auto == "death":   # two mobsters go down, one standing and one behind his drum, then the detective
		if _at < 0.05:
			player.position.x = 2300.0
			cam.position.x = player.position.x + _lead
		if _at > 0.6 and _auto_done & 1 == 0:
			_auto_done |= 1
			for i in 2:   # (through the real kill now: the gun out of his hand, the hat off a head shot)
				var en: Dictionary = enemies[i]
				fx.blood(en["node"].position + Vector2(0.0, -300.0), Vector2(1.0, 0.0))
				_kill(en, i == 0, false, "head" if i == 0 else "torso")
		if _at > 2.2 and _auto_done & 2 == 0:
			_auto_done |= 2
			_player_down()
		shots = [[0.68, "death_1"], [0.78, "death_2"], [0.9, "death_3"], [1.3, "death_4"], [2.5, "death_5"], [3.4, "death_6"], [4.4, "death_7"], [5.6, "death_8"]]
	elif _auto == "touch":   # tap on the first mobster, then hold a finger above him
		if _at < 0.05:
			player.position.x = 1700.0
			cam.position.x = player.position.x + _lead
		var target: Vector2 = get_viewport().get_canvas_transform() * (enemies[0]["node"].position + Vector2(0.0, -300.0))
		if _at > 1.0 and _auto_done & 1 == 0:
			_auto_done |= 1
			_touch(target, true)
		if _at > 1.1 and _auto_done & 2 == 0:
			_auto_done |= 2
			_touch(target, false)
		if _at > 1.6 and _auto_done & 4 == 0:
			_auto_done |= 4
			_touch(target + Vector2(0.0, -120.0), true)
		if _at > 2.4 and _auto_done & 8 == 0:
			_auto_done |= 8
			_touch(target + Vector2(0.0, -120.0), false)
		shots = [[0.9, "touch_0"], [1.08, "touch_1"], [1.8, "touch_2"], [2.2, "touch_3"]]
	for i in shots.size():
		if _auto_done & (1 << (i + 8)) == 0 and _at > float(shots[i][0]):
			_auto_done |= 1 << (i + 8)
			_shot(shots[i][1])
	var end_t := 6.0 if _auto == "death" else 3.0
	if not shots.is_empty():   # stay until the last picture has been taken
		end_t = maxf(end_t, float(shots[-1][0]) + 0.4)
	if _auto == "poses":
		end_t = 6.6
	if _auto in ["fxsheet", "coatdive", "bag", "aicover"]:
		end_t = 999.0   # it quits itself after the last effect
	if _auto == "tops":
		end_t = 999.0   # it quits itself after the last crate
	if _at > end_t:
		get_tree().quit()


func _touch(at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 1
	t.position = at
	t.pressed = down
	Input.parse_input_event(t)


## Running, jumping, diving, sliding and rolling. Returns how fast the legs should run, -1..1.
## (rule 33, user 23. 11.) A doorway in a front: he steps back into it out of the street, darker; from the street they
## do not see him there unless close, and their rounds hit the door frame - until he leans out to shoot (ALCOVE_EXPOSE).
const ALCOVE_REACH := 110.0
const ALCOVE_EXPOSE := 0.7      # s after his shot that he is out of the doorway for them
const ALCOVE_SEEN := 380.0      # closer than this a man in the street sees him in it
const ALCOVE_TONE := 0.5
var _alcove := -1.0             # the doorway's x he stands in, or -1
var _alcove_y := 0.0            # its threshold
var _alcove_at: Dictionary = {}
var _alcove_shot := -9.0
func _enter_alcove(al: Dictionary) -> void:
	_alcove_at = al
	_alcove = float(al["x"])
	_alcove_y = float(al["sill"])
	(al["dark"] as CanvasItem).visible = true   # the door goes in
	run = 0.0
	glide = 0.0
	_up_spent = true
	player.modulate = Color(ALCOVE_TONE, ALCOVE_TONE, ALCOVE_TONE * 1.05, 1.0)
	player.rim_line = Vector3(0.16, 0.16, 0.17)   # (no cream contour round him in the dark of the doorway)
	player._rim = -1.0
	player.set_rim(0.0)
	sfx.play("door", -8.0, _alcove, 0.05)


func _leave_alcove() -> void:
	_alcove = -1.0
	player.position = Vector2(player.position.x, 0.0)   # (down the steps onto the pavement)
	_ground_y = 0.0
	if not _alcove_at.is_empty():
		(_alcove_at["dark"] as CanvasItem).visible = false
	player.modulate = Color.WHITE
	player.rim_line = Vector3(-1.0, 0.0, 0.0)
	player._rim = -1.0
	player.set_rim(0.0)


func _move(dir: float, aim: Vector2, delta: float) -> float:
	if over:   # he is down: the fall (_drop) alone moves him now, nothing else pulls at the body
		return 0.0
	if absf(dir) > 0.85 and signf(dir) == _sprint_side:
		_sprint += delta
	else:
		_sprint = 0.0
		_sprint_side = signf(dir) if absf(dir) > 0.85 else 0.0
	if hud.jump_tapped or Input.is_action_just_pressed("ui_accept") or (Input.is_physical_key_pressed(KEY_W) and not _w_was):
		_jump_buf = 0.15
	_w_was = Input.is_physical_key_pressed(KEY_W)
	_jump_buf = maxf(0.0, _jump_buf - delta)
	_coyote = maxf(0.0, _coyote - delta)
	var jump: bool = _jump_buf > 0.0
	var dive: bool = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_E)
	var duck_held: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_C) or hud.duck or _demo_duck
	_up_held = Input.is_physical_key_pressed(KEY_UP) or hud.up
	if not _up_held:
		_up_spent = false
	elif _up_spent:
		_up_held = false
	if _alcove >= 0.0:   # (rule 33) back in a doorway: still; any move along, down or a jump takes him out of it
		if dir != 0.0 or duck_held or jump or move_state != "ground" or over:
			_leave_alcove()
		else:
			dir = 0.0
			run = 0.0
	elif move_state == "ground" and _up_held and _section_at(player.position) < 0 and _ladder_foot() == null:
		for al in _alcoves:
			if absf(float(al["x"]) - player.position.x) < ALCOVE_REACH and absf(player.position.y) < 10.0:
				_enter_alcove(al)
				break
	if _alcove >= 0.0:   # up the steps and into the opening, then still in it
		player.position = player.position.move_toward(Vector2(_alcove, _alcove_y), 520.0 * delta)
		player.ground = 0.0
		return 0.0
	var slide: bool = duck_held and not _duck_was   # a fresh press: out of a run that is a slide
	_duck_was = duck_held
	if hud.dive_tapped:   # the button always throws him into a dive; a slide is the stick pulled down in a run
		_dive_buf = 0.2
	_dive_buf = maxf(0.0, _dive_buf - delta)
	if _dive_buf > 0.0:   # (audit 22. 11.) tapped while still rolling or getting up: it goes as soon as he can
		dive = true
	hud.jump_tapped = false
	hud.dive_tapped = false
	var facing := -1.0 if aim.x < 0.0 else 1.0
	var legs := 0.0
	_rope_cool = maxf(0.0, _rope_cool - delta)
	_fling = maxf(0.0, _fling - delta)
	if move_state != "jump":   # (audit 22. 11.) landed: the wall he touched in the air is no longer there to kick off
		_wall_t = 0.0
	if move_state == "stairs":
		return _on_stairdoor(delta)
	if move_state in ["climb", "zip", "swing"]:
		_on_rope(dir, jump, duck_held, delta)
		if move_state in ["climb", "zip", "swing"]:
			player.ground = _floor_at(player.position.x, player.position.y) - player.position.y
			return 0.0
	elif move_state in ["jump", "dive"] and _rope_cool <= 0.0:
		_grab_rope()

	if move_state == "ground":
		var can_act: bool = player.dive < 0.05 and player.slide < 0.3 and not over   # back on his feet first
		if can_act and dive and _over_bar():   # on the bar counter: straight down onto his back and along it
			player.dive = 1.0
			player.dive_side = dir if dir != 0.0 else facing
			glide = player.dive_side * DIVE_SPEED.x
			player.position.y += DIVE_LAND   # (lying flat: the origin goes down as when he lands prone)
			_dive_buf = 0.0
			sfx.play("skid", -5.0, INF, 0.1)
		elif can_act and dive:
			_start_dive(dir if dir != 0.0 else facing, facing, DIVE_SPEED.y, absf(run) > 300.0)
		elif can_act and slide and absf(run) > 300.0 and player.duck < 0.3:
			move_state = "slide"
			slide_left = 0.55
			player.slide_side = signf(run) * facing
			run = signf(run) * RUN_SPEED * 1.4
		elif can_act and jump and _stair_door_here() >= 0:   # the stairs in the back wall: in, up (or down) a storey, out
			_start_stairdoor(_stair_door_here())
		elif can_act and _up_held and _ladder_foot() != null:   # (23. 11.) at a ladder's foot, the stick up: onto it
			_take_ladder(_ladder_foot())
		elif can_act and jump:
			move_state = "jump"
			fall = -JUMP_SPEED
			player.air_v = -1.0   # the push off: straight into the rising pose
			player.air = maxf(player.air, 0.45)
			_jump_buf = 0.0
			_coyote = 0.0
		# Running at a low crate: over it without breaking stride. Only on a committed run, the stick
		# held hard that way for a moment, and not mid-fight: a man running to a crate while he shoots
		# wants it for cover, not to leap it.
		elif can_act and absf(run) > 560.0 and player.duck < 0.3 and _sprint > 0.5 and _idle_fire > 1.0 and not (hud.touch_seen and hud.aim_left > 0.0):
			var vb := _vault_box(signf(run))
			if vb >= 0:
				_start_vault(vb, signf(run))

	_drop_t = maxf(0.0, _drop_t - delta)
	_bar_t = maxf(0.0, _bar_t - delta)
	# stick pulled down TWICE on a landing or the stairs: he drops through (user 17. 11.: one pull is a crouch
	# behind the rail, and dropping on it was "I fall through the balconies")
	_drop_tap = maxf(0.0, _drop_tap - delta)
	var drop_ask := false
	if move_state == "ground" and slide and player.dive < 0.05:
		drop_ask = _drop_tap > 0.0
		_drop_tap = 0.0 if drop_ask else 0.4
	if drop_ask:
		_floor_at(player.position.x, player.position.y)
		if _last_kind == "floor" and absf(run) < 300.0:
			_drop_t = 0.35
			_drop_y = player.position.y
			move_state = "jump"
			fall = 60.0
	var before_x: float = player.position.x
	var floor_y := _floor_at(player.position.x, player.position.y - DIVE_LAND * player.dive)
	if move_state == "ground":
		var crouched: bool = duck_held and player.dive < 0.05 and _pop == 0.0
		player.duck = move_toward(player.duck, 1.0 if crouched else 0.0, delta * (11.0 if crouched else 10.0))
		run = move_toward(run, dir * RUN_SPEED * (1.0 - player.dive) * (1.0 - 0.62 * player.duck) * _wading(player.position.y), RUN_ACCEL * delta)
		var on_bar := _last_kind == "floor" and _last_floor_style == "bar"
		glide = move_toward(glide, 0.0, delta * (220.0 if on_bar else 1500.0))    # landed flat, he skids along the wet stones a while (along a bar: all the way)
		if on_bar and absf(glide) > 400.0:
			_bar_slide(delta)
		player.position.x += (run + glide) * delta
		player.air = move_toward(player.air, 0.0, delta * 8.0)
		if absf(glide) < 180.0:   # and only gets up once the skid has run out
			player.dive = move_toward(player.dive, 0.0, delta * 3.5)
		else:
			steps.emitting = true
		player.slide = move_toward(player.slide, 0.0, delta * 5.0)
		player.crouch = lerpf(player.crouch, 0.0, 1.0 - exp(-7.0 * delta))
		if floor_y > player.position.y - DIVE_LAND * player.dive + 36.0 and player.dive < 0.05:   # walked off an edge (a step down the stairs is just walked)
			move_state = "jump"
			fall = 0.0
			_coyote = 0.12   # a jump a beat late still goes
		elif floor_y > player.position.y - DIVE_LAND * player.dive + 60.0 and player.dive > 0.9 and absf(glide) > 300.0:   # skidded off the end of a bar: flying on, flat out
			move_state = "dive"
			fall = 0.0
			player.position.y -= DIVE_LAND
		else:
			player.position.y = floor_y + DIVE_LAND * player.dive   # getting up brings him back onto his feet
		legs = run / RUN_SPEED if player.dive < 0.05 else 0.0
	elif move_state == "jump":
		fall += GRAVITY * delta
		player.position.y += fall * delta
		if _fling <= 0.0:   # flung off a rope he keeps the swing's speed a moment
			run = move_toward(run, dir * RUN_SPEED, RUN_ACCEL * 0.5 * delta)
		player.position.x += run * delta
		player.air = move_toward(player.air, 1.0, delta * 8.0)
		player.air_v = move_toward(player.air_v, clampf(fall / JUMP_SPEED, -1.0, 1.0), delta * 6.0)
		_wall_t = maxf(0.0, _wall_t - delta)
		if jump and _wall_t > 0.0 and _coyote <= 0.0:   # off the wall (the stunt list, ch II): up and back the other way, a slowed beat
			_wall_kick(dir)
		elif jump and _coyote > 0.0:
			fall = -JUMP_SPEED
			_coyote = 0.0
			_jump_buf = 0.0
		elif dive:   # a dive can also be thrown out of a jump
			_start_dive(dir if dir != 0.0 else facing, facing, minf(fall, -300.0), false)
		elif fall > AWNING_BOUNCE and player.position.y >= floor_y and _awning_under():   # (a trampoline every time: user)
			player.position.y = floor_y   # onto an awning: the canvas gives and throws him up (a stunt: a slowed beat)
			fall = -JUMP_SPEED * 1.8   # high enough to land on the fire escape's landings beside it
			if absf(run) > 50.0:   # (and on: the canvas throws him the way he was going, onto the fire escape there)
				var way := signf(run)
				var goal := INF
				for k in catwalks.size():
					var c: Rect2 = catwalks[k]
					if catwalk_style[k] == "drawn" and c.position.y < floor_y - 200.0:
						var cx := c.position.x + 120.0 if way > 0.0 else c.end.x - 120.0
						if (cx - player.position.x) * way > 0.0 and absf(cx - player.position.x) < 2000.0 and absf(cx - player.position.x) < absf(goal - player.position.x):
							goal = cx
				var t_air := -fall / GRAVITY * 1.5   # up to the top and part way down: over the landing
				run = clampf((goal - player.position.x) / t_air, -RUN_SPEED * 2.0, RUN_SPEED * 2.0) if goal != INF else way * RUN_SPEED * 1.25
				_fling = t_air
			sfx.play("land", -2.0)
			_word(["thud"], player.position + Vector2(0.0, -80.0), 0.14)
			_stunt_slow("awning", 0.6)
			_clip("flip", run if absf(run) > 50.0 else signf(player.scale.x))   # thrown up: once over, tucked
			if props:
				props.landed_on(player.position)
		elif fall > 0.0 and player.position.y >= floor_y:
			player.position.y = floor_y
			player.crouch = clampf(fall / 1500.0, 0.3, 0.9)   # the harder the landing, the deeper the knees
			if fall > 900.0:
				fx.dust(player.position, 0.35 + clampf(fall / 4000.0, 0.0, 0.3))
				_buzz(20)
			move_state = "ground"
			steps.restart()
			sfx.play("land", -4.0)
			if _win_landing:   # down from the window: a heavy landing, deep in the knees, the street shakes
				_win_landing = false
				player.crouch = 1.0
				_shake = maxf(_shake, 0.4)
				fx.dust(player.position, 0.7)
				_word(["thud"], player.position + Vector2(60.0, -160.0), 0.18)
				glide = 260.0
	elif move_state == "dive":
		_kick_check()
		fall += _dive_g() * delta
		player.position.y += fall * delta
		player.position.x += glide * delta
		player.dive = move_toward(player.dive, 1.0, delta * 6.0)
		_speed_t -= delta
		if _speed_t <= 0.0 and absf(glide) > 300.0:   # comic speed lines streaming off him
			_speed_t = 0.07
			fx.speed_lines(player.position + Vector2(-signf(glide) * 120.0, -150.0 + randf_range(-70.0, 70.0)), signf(glide), randf_range(0.4, 0.6))
		player.air_v = move_toward(player.air_v, clampf(fall / 900.0, -1.0, 1.0), delta * 5.0)
		player.air = move_toward(player.air, 0.0, delta * 8.0)
		_try_vault()
		if move_state != "dive":
			pass
		elif dive_rolls and fall > 0.0 and player.position.y >= floor_y + 30.0 and not _over_bar():   # fast and forward: over the shoulder (onto a bar: on his back, skidding)
			move_state = "roll"
			roll_done = 0.0
			if _win_landing:   # down from the window: the stones shake, glass and dust round the roll
				_win_landing = false
				_shake = maxf(_shake, 0.45)
				fx.dust(player.position, 0.8)
				_word(["thud"], player.position + Vector2(80.0, -170.0), 0.18)
				sfx.play("land", 0.0)
				_buzz(30)
			player.roll = 1.35 * player.dive * player.dive_side
			player.position.y = minf(player.position.y, floor_y)   # the origin moves up to his feet: on a crate he rolls along its top, not inside it
			player.dive = 0.0
		elif fall > 0.0 and player.position.y >= floor_y + DIVE_LAND:   # otherwise flat on the pavement, skidding on
			player.position.y = floor_y + DIVE_LAND
			player.dive = 1.0
			run = 0.0
			glide *= 0.8
			move_state = "ground"
			fx.dust(player.position + Vector2(0.0, -DIVE_LAND), 0.6)
			_impact(0.04, 0.12)   # (audit 17. 11.) the weight of him hitting the stones: a beat, a jolt, sparks off the buttons
			_shake = maxf(_shake, 0.16)
			for k in 4:
				fx.chip(player.position + Vector2(randf_range(-60.0, 60.0), -DIVE_LAND + 6.0))
			steps.restart()
			sfx.play("land", -4.0)
			sfx.play("skid", -5.0, INF, 0.1)
	elif move_state == "roll":   # over the shoulder: tucked tight in the middle of the turn, opening to come up
		roll_done = minf(1.0, roll_done + delta / 0.5)
		var ease_r := roll_done * roll_done * (3.0 - 2.0 * roll_done)
		player.roll = lerpf(1.35, TAU, ease_r) * player.dive_side
		var tuck := sin(roll_done * PI)
		player.air = lerpf(0.5, 1.0, tuck)
		player.crouch = lerpf(0.6, 1.0, tuck) if roll_done < 0.75 else lerpf(1.0, 0.7, (roll_done - 0.75) / 0.25)
		steps.emitting = roll_done > 0.2
		player.position.y = move_toward(player.position.y, floor_y, delta * 500.0)
		player.position.x += glide * 0.75 * delta
		if roll_done >= 1.0:   # a full turn: he comes up on his feet, still moving
			player.roll = 0.0
			run = clampf(glide * 0.5, -RUN_SPEED, RUN_SPEED)
			glide = 0.0
			move_state = "ground"
	elif move_state == "flip":   # vaulted off a crate: a forward somersault through the air
		fall += GRAVITY * 0.85 * delta
		player.position.y += fall * delta
		player.position.x += glide * delta
		roll_done = minf(1.0, roll_done + delta / 0.5)
		var e := roll_done * roll_done * (3.0 - 2.0 * roll_done)
		player.roll = TAU * e * _flip_way
		player.air = move_toward(player.air, 1.0, delta * 12.0)
		player.dive = move_toward(player.dive, 0.0, delta * 10.0)
		if fall > 0.0 and player.position.y >= floor_y:   # down on his feet, knees soaking it up, skidding back
			player.position.y = floor_y
			player.roll = 0.0
			player.crouch = 0.9
			run = clampf(glide * 0.6, -RUN_SPEED, RUN_SPEED)
			glide = glide * 0.35
			move_state = "ground"
			steps.restart()
			sfx.play("land", -2.0)
			sfx.play("skid", -8.0, INF, 0.1)
	elif move_state == "vault":   # a speed vault: one hand on the crate, legs swung over the side, landing running
		_vault["t"] = minf(1.0, float(_vault["t"]) + delta / float(_vault["dur"]))
		var t: float = _vault["t"]
		var a: Vector2 = _vault["from"]
		var b: Vector2 = _vault["to"]
		var c: Vector2 = _vault["ctrl"]
		player.position = a * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + b * t * t
		var lift := sin(t * PI)
		player.air = lift
		player.crouch = 0.35 * lift
		player.roll = 0.28 * lift * float(_vault["way"]) * facing   # the body tips forward over the hand
		if t > 0.3 and not _vault.get("planted", false):
			_vault["planted"] = true   # the hand meets the top
			sfx.play("land", -12.0, INF, 0.1)
			fx.chip(Vector2(float(_vault["hand"]), float(_vault["top"])))
		if t >= 1.0:
			player.roll = 0.0
			player.air = 0.0
			player.crouch = 0.35
			move_state = "ground"
			steps.restart()
			sfx.play("step1", -4.0)
	elif move_state == "slide":   # dropping into it, riding it out on the hip, then pushing back up
		slide_left -= delta
		run = move_toward(run, 0.0, 500.0 * delta)
		player.position.x += run * delta
		var into := clampf((0.55 - slide_left) / 0.12, 0.0, 1.0)
		var out := clampf(slide_left / 0.16, 0.0, 1.0)
		player.slide = minf(into, lerpf(0.55, 1.0, out))
		player.duck = (1.0 - out) * 0.5
		steps.emitting = true
		if slide_left <= 0.0:
			move_state = "ground"
		elif floor_y > player.position.y + 36.0:   # (audit 22. 11.) slid off a crate or a deck: he falls, not glides on in the air
			move_state = "jump"
			fall = 0.0
			player.slide = 0.0
			player.duck = 0.0
			steps.emitting = false
	_block(before_x)
	player.position.x = clampf(player.position.x, -1500.0, level_end + 500.0)
	if not roof.is_empty() and player.position.y < float(roof["y"]) + 40.0:   # the firewalls at both ends of the roofs
		player.position.x = clampf(player.position.x, float(roof["x0"]) + 70.0, float(roof["x1"]) - 70.0)
	if move_state != "ground":
		player.duck = move_toward(player.duck, 0.0, delta * 9.0)
	player.ground = _floor_at(player.position.x, player.position.y - DIVE_LAND * player.dive) - player.position.y
	return legs


## The highest thing under his feet: the pavement, the top of a crate, a landing or a flight of stairs.
## Sets _last_kind to what it found. While he drops through a landing, that landing and those above it
## do not count.
func _floor_at(x: float, feet: float) -> float:
	var best := 0.0
	_last_kind = "ground"
	_last_floor_style = ""   # (audit 22. 11.: a ramp after the bar kept "bar" and he skidded down the stairs)
	for bi in boxes.size():
		var b: Rect2 = boxes[bi]
		if box_info[bi]["kind"] == "car":
			continue   # nobody climbs on it either: it is behind him
		if x > b.position.x - 20.0 and x < b.end.x + 20.0 and feet <= b.position.y + 14.0 and b.position.y < best:
			best = b.position.y
			_last_kind = "box"
	for ci in catwalks.size():
		var c: Rect2 = catwalks[ci]
		var reach := 34.0 if catwalk_solid[ci] else 14.0   # a storey's floor is stepped onto off the top stair, like a stair
		reach = maxf(reach, fall * get_process_delta_time() * 1.3 + 14.0) if fall > 0.0 and move_state != "ground" else reach   # (falling fast: caught, not passed in one frame)
		if catwalk_solid[ci] and fall > 0.0 and move_state in ["dive", "jump"] and feet - fall * get_process_delta_time() <= c.position.y + 14.0:
			reach = 100.0   # (audit 22. 11.: only from above - from under the deck it pulled him up through it)   # falling fast onto a deck (out of a window at full tilt): caught, not dropped through onto the flight below
		if x > c.position.x and x < c.end.x and feet <= c.position.y + reach and c.position.y < best:
			if _drop_t > 0.0 and c.position.y <= _drop_y + 10.0:
				continue
			best = c.position.y
			_last_kind = "roof" if catwalk_solid[ci] else "floor"
			_last_floor_style = catwalk_style[ci]
	for r in ramps:
		var a: float = minf(r[0], r[2])
		var b2: float = maxf(r[0], r[2])
		if x < a or x > b2:
			continue
		if move_state == "dive" and r.size() > 4 and String(r[4]) == "fescape":
			continue   # a flat dive does not land on steep iron stairs: it carries on onto the deck
		var ry: float = lerpf(r[1], r[3], (x - float(r[0])) / (float(r[2]) - float(r[0])))
		var stride := maxf(34.0, absf((float(r[3]) - float(r[1])) / (float(r[2]) - float(r[0]))) * 30.0)   # steep iron stairs: a longer step
		if feet <= ry + stride and ry < best and ry < -1.0:   # a step up the stairs is within reach of a stride
			if _drop_t > 0.0 and ry <= _drop_y + 10.0:
				continue
			best = ry
			_last_kind = "floor"
	return best


## Crates and the like stop him when he runs, slides or dives into their side.
func _block(before_x: float) -> void:
	for s in sections:   # (audit 21. 11.) from outside its right end: the wall, unless back in through the window he broke
		var x1 := float(s[1])
		if before_x >= x1 - 1.0 and player.position.x < x1 and player.position.y > -float(s[2]) * section_h + 20.0 				and not (String(s[3]) == "works" and player.position.y > -60.0 and _works_out):   # (on the pavement past the works)
			var fb := _flat_at_storey(_ground_y)
			if fb.is_empty() or not fb["broken"] or move_state not in ["jump", "dive"] or absf(fb["wx1"] - x1) > 900.0:
				player.position.x = x1
				run = 0.0
				glide = maxf(glide, 0.0)
	var si := _section_at(Vector2(before_x, player.position.y), true)
	if si >= 0:   # a building's outer walls: the street door on the ground floor's left is the only way out
		var sec: Array = sections[si]
		var fw := _flat_at_storey(_ground_y)
		if not fw.is_empty() and not _through_window():   # the flat's end wall: up to its window's inner face
			player.position.x = minf(player.position.x, float(fw["wx0"]) - 60.0)
		elif fw.is_empty():
			player.position.x = minf(player.position.x, float(sec[1]) - (SEC_KIT_WALL.y - SEC_KIT_WALL.x) * section_h / SEC_KIT_ROWS - 40.0 if _section_kit() else float(sec[1]) - 70.0)
		if player.position.y < -40.0 or _works(si):
			player.position.x = maxf(player.position.x, float(sec[0]) + 70.0)
	_flat_door_block(before_x)
	_room_window_block(before_x)
	if level.has("sealed"):   # (CARGO HOLD) the hold's forward bulkhead: the way he came in is the hatch up, not back
		player.position.x = maxf(player.position.x, float(level["sealed"]))
	for c in level["floors"]:   # a fire escape landing's railing (drawn at its outer end) stops him: no flying off it
		if String(c[3]) != "fescape":
			continue
		var end := float(c[0]) + float(c[2]) - 40.0
		if player.position.y < float(c[1]) + DIVE_LAND + 10.0 and player.position.y > float(c[1]) - 300.0 and before_x <= end + 1.0 and player.position.x > end:   # (skidding prone too)
			player.position.x = end
			glide = 0.0
			run = 0.0
	if move_state == "vault":
		return
	var feet: float = player.position.y - DIVE_LAND * player.dive
	for b in boxes:
		if feet <= b.position.y + 14.0:
			continue   # he is on top of it or above it
		if feet > b.end.y + 40.0:
			continue   # it stands on a floor above him (on the stairs under the mezzanine)
		if box_info[boxes.find(b)]["kind"] == "car":
			continue   # parked at the kerb: it never bars the way
		var left := b.position.x - 45.0
		var right := b.end.x + 45.0
		if player.position.x > left and player.position.x < right:
			if move_state == "dive" and b.size.y <= VAULT_MAX and box_info[boxes.find(b)]["kind"] != "car":
				# launched too close to clear it: held at its side, he is lifted over the top in a few
				# frames instead of being dropped onto it, and flies on
				player.position.x = left if player.position.x < b.get_center().x else right
				player.position.y = move_toward(player.position.y, b.position.y + DIVE_LAND * player.dive - 6.0, 2600.0 * get_process_delta_time())
				fall = minf(fall, 0.0)
				continue
			player.position.x = left if before_x <= left + 1.0 else (right if before_x >= right - 1.0 else (left if player.position.x < b.get_center().x else right))
			if move_state == "jump" and b.position.y < feet - WALL_KICK_MIN:   # flying into a tall one's side: he can kick off it
				_wall_t = 0.25
				_wall_away = -1.0 if player.position.x <= b.get_center().x else 1.0
			run = 0.0
			glide = 0.0


## Down the bar on his back (the stunt list): a dive onto the club's counter skids him its whole length, glasses and
## bottles flying off ahead of him, a slowed beat for free the first moment.
## A move-sheet clip (puppet.gd CLIPS) toward world direction `way` (+1 right): the puppet's own frame is mirrored
## when he faces left.
func _clip(name: String, way: float) -> void:
	player.play_clip(name, signf(way) * signf(player.scale.x) if way != 0.0 else 1.0)


var _bar_t := 0.0
func _over_bar() -> bool:
	for k in catwalks.size():
		var c: Rect2 = catwalks[k]
		if catwalk_style[k] == "bar" and player.position.x > c.position.x - 20.0 and player.position.x < c.end.x + 20.0 and absf(player.position.y - c.position.y) < 120.0:
			return true
	return false


func _bar_slide(delta: float) -> void:
	if _bar_t <= 0.0:
		_stunt_slow("bar", 0.6)
		sfx.play("glass", -2.0, player.position.x, 0.1)
		_word(["smash", "clink"], player.position + Vector2(signf(glide) * 160.0, -170.0), 0.16)
	_bar_t = 0.3
	if randf() < delta * 9.0:   # a glass swept off ahead of him
		fx.shatter(player.position + Vector2(signf(glide) * randf_range(90.0, 180.0), -40.0))
	for e in enemies:   # whoever stands at the end of the bar takes his boots
		if e["alive"] and absf(float(e["node"].position.x) - player.position.x) < 110.0 and absf(float(e["node"].position.y) - player.position.y) < 260.0 and String(e["state"]) in ["post", "run", "move", "hop"]:
			_knock_down(e, signf(glide) * 700.0)


## Off a wall: flying into a tall crate stack's side, jump again and he plants a foot on it and kicks off, up and
## back the way he came, half a second of slowed time for free (user rule: stunts give slow time). The stick still
## held into the wall: he runs up its face instead and over the top onto it (a stack too tall to jump).
const WALL_KICK_MIN := 110.0   # how much of the side must stand above his feet to kick off it
func _wall_kick(stick: float) -> void:
	_wall_t = 0.0
	_jump_buf = 0.0
	var up := stick * _wall_away < -0.3
	fall = -JUMP_SPEED * (1.22 if up else 1.05)
	run = _wall_away * RUN_SPEED * (-0.4 if up else 1.15)
	_fling = 0.3   # keeps the kick's speed a moment against the stick
	player.air_v = -1.0
	player.air = 1.0
	_stunt_slow("wall", 0.5)
	_clip("wall_kick", -_wall_away)   # (toward the wall: the foot on it, then the push)
	sfx.play("land", -3.0)
	_word(["thud", "wham"], player.position + Vector2(-_wall_away * 60.0, -140.0), 0.14)
	fx.dust(player.position + Vector2(-_wall_away * 50.0, -120.0), 0.3)


## A dive that carries him just over a crate: his hands touch its top and he pushes off it, a
## parkour vault, tucking into a forward somersault and landing on his feet further on.
## A low crate just ahead on his floor, nothing standing right behind it: the one to vault (or -1).
func _vault_box(way: float) -> int:
	var px: float = player.position.x
	for i in boxes.size():
		var b: Rect2 = boxes[i]
		if b.size.y > VAULT_MAX or absf(b.end.y - player.position.y) > 4.0 or box_info[i]["kind"] in ["barrel", "car"]:
			continue
		var near: float = b.position.x - 45.0 if way > 0.0 else b.end.x + 45.0
		var gap: float = (near - px) * way
		if gap < -5.0 or gap > 60.0:
			continue
		var land: float = (b.end.x if way > 0.0 else b.position.x) + way * 150.0
		for o in boxes:   # somewhere to come down
			if o != b and land > o.position.x - 60.0 and land < o.end.x + 60.0:
				return -1
		return i
	return -1


func _start_vault(i: int, way: float) -> void:
	var b: Rect2 = boxes[i]
	var land: float = (b.end.x if way > 0.0 else b.position.x) + way * 150.0
	var from: Vector2 = player.position
	var to := Vector2(land, _floor_at(land, player.position.y - 10.0))
	var top := b.position.y - 70.0   # his hips skim the top
	_vault = {"t": 0.0, "from": from, "to": to, "ctrl": Vector2((from.x + to.x) * 0.5, 2.0 * top - (from.y + to.y) * 0.5),
			"dur": clampf(absf(to.x - from.x) / maxf(absf(run), 600.0), 0.32, 0.55), "way": way, "top": b.position.y,
			"hand": b.get_center().x - way * b.size.x * 0.15}
	move_state = "vault"
	sfx.play("dive", -10.0, INF, 0.1)


func _try_vault() -> void:
	if _vaulted or player.dive < 0.5:
		return
	var feet: float = player.position.y - DIVE_LAND * player.dive
	var hands_x: float = player.position.x + signf(glide) * 20.0
	for bi in boxes.size():
		var b: Rect2 = boxes[bi]
		if b.size.y > VAULT_MAX or hands_x < b.position.x or hands_x > b.end.x or box_info[bi]["kind"] == "car":
			continue
		var gap: float = b.position.y - feet
		if gap >= -10.0 and gap < 95.0:
			# his hands meet the top and push: no stop, no snap into a new pose, the dive just carries on
			# a little higher and as fast, over the crate and down the far side
			_vaulted = true
			fall = minf(fall, -560.0)
			glide = signf(glide) * maxf(absf(glide), 1050.0)
			sfx.play("land", -12.0, INF, 0.15)
			fx.chip(Vector2(hands_x, b.position.y))
			if Engine.time_scale < 1.0:
				slow_left = minf(1.0, slow_left + (0.15 if _perk("bloodtime") else 0.1))   # a little slowed time back for the style
			return


## (audit 22. 11.) A stunt's free slowed time (rule 18): the same kind of stunt gives it again only after a few
## seconds, so bouncing on one awning or swinging to and fro is not slowed time for ever.
const STUNT_SLOW_GAP := 4.0
func _stunt_slow(kind: String, secs: float) -> void:
	if _time - float(_stunt_at.get(kind, -100.0)) < STUNT_SLOW_GAP:
		return
	_stunt_at[kind] = _time
	_free_slow = maxf(_free_slow, secs)


func _dive_g() -> float:
	return GRAVITY * (0.8 if _perk("longdive") else 1.0)


func _start_dive(way: float, facing: float, up: float, from_run: bool) -> void:
	_dive_buf = 0.0
	sfx.play("dive", -2.0)
	if player.dive < 0.3:   # (audit 17. 11.: it snapped from upright to flat) the push-off, then the flight
		_clip("dive_push" if way * facing >= 0.0 else "dive_back", way)
		fx.dust(player.position, 0.3)
	move_state = "dive"
	_kicked_this_dive = false
	glide = DIVE_SPEED.x * way
	fall = up
	_vaulted = false
	# a crate in the way: he launches steeper, just enough to fly right over it and land clear of it;
	# only if that is out of reach, to land on top of it and roll off
	var found := false
	_dive_near.clear()   # (audit 22. 11.) only the crates the dive can reach: ~50 arcs over every crate on the map was a hitch
	for b in boxes:
		if (b.end.x - player.position.x) * way > -300.0 and (b.position.x - player.position.x) * way < DIVE_SPEED.x * 2.2 + 300.0:
			_dive_near.append(b)
	if _dive_near.is_empty():
		found = true
	# a low crate within reach: the arc that skims its top, so his hands meet it and he vaults
	for k in 24:
		var u := up * 0.5 - 40.0 * k
		if not found and _dive_vaults(way, u):
			fall = u
			found = true
	for strict in [true, false]:
		for k in 14:
			var u := up - 60.0 * k
			if not found and _dive_clears(way, u, strict):
				fall = u
				found = true
	run = 0.0
	player.dive_side = way * facing
	dive_rolls = from_run and way * facing > 0.0


## Does a dive launched with this upward speed come down onto a low crate's top just as he is over
## it (where _try_vault catches it), without first hitting the crate's side?
func _dive_vaults(way: float, up: float) -> bool:
	var x: float = player.position.x
	var y: float = player.position.y
	var d: float = player.dive
	var f := up
	var dt := 1.0 / 60.0
	for i in 90:
		f += _dive_g() * dt
		y += f * dt
		x += DIVE_SPEED.x * way * dt
		d = move_toward(d, 1.0, 6.0 * dt)
		var feet := y - DIVE_LAND * d
		var hands := x + way * 20.0
		for b in _dive_near:
			if b.size.y > VAULT_MAX:
				continue
			if x > b.position.x - 45.0 and x < b.end.x + 45.0 and feet > b.position.y + 14.0:
				return false   # into its side
			if d >= 0.5 and hands >= b.position.x and hands <= b.end.x and f > 0.0:
				var gap: float = b.position.y - feet
				if gap >= 10.0 and gap < 70.0:
					return true
		if feet > 0.0:
			return false
	return false


## Would a dive launched now, with this upward speed, fly over every low crate in its way and land
## with room to roll before the next one? Steps the same arc _move will fly.
func _dive_clears(way: float, up: float, strict: bool) -> bool:
	var x: float = player.position.x
	var y: float = player.position.y
	var d: float = player.dive
	var f := up
	var dt := 1.0 / 60.0
	for i in 120:
		f += _dive_g() * dt
		y += f * dt
		x += DIVE_SPEED.x * way * dt
		d = move_toward(d, 1.0, 6.0 * dt)
		var feet := y - DIVE_LAND * d
		for b in _dive_near:
			if b.size.y <= VAULT_MAX and x > b.position.x - 45.0 and x < b.end.x + 45.0 and feet > b.position.y + 14.0:
				return false
		if f > 0.0 and y >= _floor_at(x, feet) + 30.0:   # down: the roll that follows must not run into a crate
			if strict and _floor_at(x, feet) < 0.0 and _last_kind == "box":
				return false   # came down on top of a crate
			for b in _dive_near:
				var gap: float = (b.position.x - 45.0 - x) if way > 0.0 else (x - b.end.x - 45.0)
				if b.size.y <= VAULT_MAX and gap > -1.0 and gap < 420.0 and _floor_at(x, feet) > b.position.y:
					return false
			return true
	return true


## A lettered sound effect, picked from the given words so the same one does not come twice in a row.
var _last_word := ""
const WORD_SCALE := 1.6   # (feedback 17. 11.: the comic words were too small to read on a phone)
func _word(names: Array, at: Vector2, size: float, along := Vector2.ZERO) -> void:
	var pick: String = names.pick_random()
	if pick == _last_word and names.size() > 1:
		pick = names[(names.find(pick) + 1) % names.size()]
	_last_word = pick
	fx.word("res://art/fx/word_%s.png" % pick, at, size * WORD_SCALE * randf_range(0.92, 1.08), along)


## Out of rounds: a dry click, and then he reloads. A gun that is nearly full is topped up
## by itself once he has not fired for a while; the HUD's rounds can be tapped to reload at once.
func _dry_fire() -> void:
	sfx.play("dry_fire", 0.0)
	_word(["click"], player.muzzle() + Vector2(0.0, -110.0), 0.16)
	if weapon != "revolver" and ammo <= 0:   # nothing left for this gun: he drops it, takes the next one
		var empty := weapon
		weapon = "revolver"   # (so _switch stores nothing for the empty gun)
		mag = int(_bag.get("revolver", {}).get("mag", 0))
		_bag.erase(empty)
		_bag.erase("revolver")
		var next := "revolver"
		for k in _bag:
			next = k
		_equip(next)
		hud.toast("EMPTY")
		return
	_start_reload()


func _start_reload() -> void:
	var full := _mag_size(weapon)
	if reloading > 0.0 or mag >= full or (weapon != "revolver" and ammo <= 0):
		return
	var dur := float(_w(weapon)["reload"]) * (0.67 if weapon == "revolver" and _sperk("fast") else 1.0)
	reloading = dur
	if mag == 0 and randf() < 0.45:   # (an empty gun heard clicking, not a top-up)
		var near = _nearest_enemy()
		if near != null and _on_screen(near.position) and _same_floor(near):
			_bark(near, "empty")
	var missing := full - mag
	var later := func(t: float, what: Callable) -> void:
		get_tree().create_timer(t, false).timeout.connect(func() -> void:
			if reloading > 0.0 and not over:
				what.call())
	if weapon == "revolver" and side == "beretta":   # magazine out, a fresh one slapped in, the slide
		sfx.play("reload_mag", -2.0)
		later.call(dur * 0.8, func() -> void: sfx.play("click", -4.0, INF, 0.05))
	elif weapon == "revolver":
		# latch and cylinder out; the empties tumble onto the stones; a round into each chamber;
		# a spin of the cylinder with the thumb; it snaps shut (reload_done, in _tick_reload)
		sfx.play("cyl_open", 0.0)
		for k in missing:
			later.call(0.08 + 0.03 * k, func() -> void:
				fx.casing(player.position + Vector2(-player.scale.x * 20.0, -300.0), -player.scale.x))
		for k in missing:
			later.call(0.2 + (dur * 0.5) * k / maxf(1.0, missing), func() -> void: sfx.play("shell_in", -3.0, INF, 0.08))
		later.call(dur * 0.74, func() -> void: sfx.play("cyl_spin", -2.0, INF, 0.03))
	elif weapon == "shotgun":   # shell after shell thumbed into the tube
		var n := mini(missing, ammo)
		for k in n:
			later.call(0.08 + (dur * 0.75) * k / maxf(1.0, n), func() -> void: sfx.play("shell_in", -2.0, INF, 0.1))
	else:
		sfx.play("reload_mag", -1.0)


func _tick_reload(delta: float) -> void:
	if hud.switch_tapped or Input.is_action_just_pressed("ui_focus_next") or (Input.is_physical_key_pressed(KEY_Q) and not _q_held):
		hud.switch_tapped = false
		_switch_gun()
	_q_held = Input.is_physical_key_pressed(KEY_Q)
	if hud.reload_tapped or Input.is_physical_key_pressed(KEY_R):
		hud.reload_tapped = false
		_start_reload()
	_idle_fire += delta
	if reloading <= 0.0 and mag < _mag_size(weapon) and _idle_fire > 2.2 and not over:
		_start_reload()
	player.reload = 0.0 if reloading <= 0.0 else 1.0 - reloading / (float(_w(weapon)["reload"]) * (0.67 if weapon == "revolver" and _sperk("fast") else 1.0))
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			reloading = 0.0
			var full := _mag_size(weapon)
			if weapon == "revolver":
				mag = full
			else:
				var take := mini(full - mag, ammo)
				mag += take
				ammo -= take
			sfx.play("reload_done", -2.0)
			_word(["kachak"], player.position + Vector2(-player.scale.x * 40.0, -470.0), 0.13)
	_show_ammo()


## Guns in his coat besides the one in hand: kind -> {mag, ammo}; the revolver is kept here too when
## another gun is in his hand (its rounds in the cylinder).
var _bag := {}
func _show_guns() -> void:
	var other := ""
	for k in _bag:
		if k != weapon:
			other = k
	var card := func(k: String) -> String: return "twoguns" if k == "revolver" and player.dual else ("revolver" if not k in ["shotgun", "tommy"] else k)
	hud.set_guns(card.call(weapon), "" if other == "" else card.call(other))


## His big gun (a shotgun or a tommy gun), in hand or in the coat, or "". He carries one, besides
## his revolver.
var _swap_offer = null   # a big gun on the ground he is standing at, while he already has one
func _big_gun() -> String:
	if weapon != "revolver":
		return weapon
	for k in _bag:
		if k != "revolver":
			return k
	return ""


## Tap on Frank's picture (or Q): the next gun out of his coat, the one in hand goes in. Standing at
## a big gun while he has one already: the two are swapped (his goes down with its rounds).
func _switch_gun() -> void:
	if _swap_offer != null and pickups.has(_swap_offer) and absf(float(_swap_offer["at"].x) - player.position.x) < 120.0:
		var old := _big_gun()
		var st: Dictionary = {"mag": mag, "ammo": ammo} if weapon == old else _bag[old]
		var kind := String(_swap_offer["kind"])
		var total := int(_swap_offer.get("left", WEAPONS[kind]["ammo"]))   # (audit 21. 11.) what is left in the one on the ground
		(_swap_offer["node"] as Node2D).queue_free()
		pickups.erase(_swap_offer)
		_swap_offer = null
		_add_pickup(old, player.position + Vector2(-60.0 * player.scale.x, 0.0))
		pickups[pickups.size() - 1]["left"] = int(st["mag"]) + int(st["ammo"])
		_bag.erase(old)
		if weapon == old:
			weapon = "revolver"   # so _equip keeps nothing of the old gun
			mag = int(_bag.get("revolver", {}).get("mag", _mag_size("revolver")))
			_bag.erase("revolver")
		_bag[kind] = {"mag": mini(total, _mag_size(kind)), "ammo": maxi(0, total - _mag_size(kind))}
		_equip(kind)
		sfx.play("pickup", 0.0)
		return
	var order: Array = ["revolver"]
	for k in _bag:
		if k != "revolver":
			order.append(k)
	for k in WEAPONS:
		if k == weapon and not order.has(k):
			order.append(k)
	if order.size() < 2:
		return
	_equip(order[(order.find(weapon) + 1) % order.size()])
	sfx.play("reload_done", -4.0)


func _equip(kind: String) -> void:
	_bag[weapon] = {"mag": mag, "ammo": ammo}
	var st: Dictionary = _bag.get(kind, {"mag": _mag_size(kind), "ammo": 0})
	_bag.erase(kind)
	weapon = kind
	player.switch_to(kind)   # the arm takes the old gun down and brings the new one up
	fire_cool = maxf(fire_cool, player.SWITCH_TIME * 0.9)
	mag = int(st["mag"])
	ammo = int(st["ammo"])
	reloading = 0.0
	if kind == "revolver" and mag <= 0:
		_start_reload()
	_show_ammo()
	_show_guns()


## Rounds the gun holds: TWO GUNS doubles the revolver's.
func _mag_size(kind: String) -> int:
	match kind:
		"revolver": return int(_w(kind)["mag"]) + (2 * (2 if player != null and player.dual else 1) if _sperk("mag") else 0)
		"shotgun": return int(WEAPONS[kind]["mag"]) + (2 if _perk("sg_tube") else 0)   # the gunsmith's longer tube
		"tommy": return 50 if _perk("tg_drum") else int(WEAPONS[kind]["mag"])   # the drum
	return int(WEAPONS[kind]["mag"])


## Shotguns turn up from chapter II, tommy guns from III (instincts.gd GUN_FROM).
func _gun_open(kind: String) -> bool:
	if not kind in ["shotgun", "tommy"] or _auto in ["bag", "disarm", "fxsheet"]:
		return true
	return Instincts.gun_open(kind, chapter)


func _show_ammo() -> void:
	var w: Dictionary = _w(weapon)
	var left := 0.0 if reloading <= 0.0 else 1.0 - reloading / (float(w["reload"]) * (0.67 if weapon == "revolver" and _sperk("fast") else 1.0))
	hud.set_ammo("", mag, _mag_size(weapon), ammo if weapon != "revolver" else -1, left)


## One shot: flash, bullet (or a shotgun's pellets), casing, kick of the arm and the lettered bang.
## kind: the mobster's gun (post, tommy, shotgun); the detective fires whatever he holds.
func _fire(shooter, from_player: bool, kind := "") -> void:
	if from_player:
		_alcove_shot = _time   # (out of a doorway he leans into the street to shoot)
	if not from_player and shooter != player and not _same_floor(shooter):   # never from another floor
		return
	var at: Vector2 = shooter.muzzle()
	var d: Vector2 = shooter.aim_dir()
	if from_player and _aim_point != Vector2.INF and _aim_point.distance_to(at) > 120.0:
		d = (_aim_point - at).normalized()   # exactly onto the finger or the cursor, wherever the arm still is
	var gun := weapon if from_player else (kind if WEAPONS.has(kind) else "revolver")
	var w: Dictionary = _w(gun) if from_player else WEAPONS[gun]
	# the gunsmith's work shows in the street: a new barrel (or slide) and its loads flash bigger and
	# bark deeper; a worn Beretta's flash is small and sharp
	var flash := gun
	if from_player and gun == "revolver":
		flash = "heavy" if _sperk("dmg") else ("pistol" if side == "beretta" else "revolver")
	fx.muzzle(at, d, flash)
	_scare_birds(at, 1300.0)
	var point_blank := false
	if from_player:
		_buzz(12)
		_alarm(at, mapfx.hearing(1600.0))   # (under the El going over, nobody hears it)
	if from_player:   # a man right on top of him, between his chest and the muzzle: hit at point blank
		var chest: Vector2 = player.position + SHOULDER + Vector2(0.0, DUCK_DROP * player.duck)
		for e in enemies:
			if point_blank or not e["alive"] or e["state"] == "wait" or absf(e["node"].position.x - player.position.x) > 200.0:
				continue
			for j in 6:
				var p: Vector2 = chest.lerp(at + d * 60.0, j / 5.0)
				if e["node"].hit_part(p) != "":
					fx.hit_vel = d * BULLET_SPEED
					_bullet_hit(p, true)
					point_blank = true
					break
	var pellets := int(w["pellets"]) + (2 if from_player and gun == "shotgun" and _perk("sg_buck") else 0)
	for k in (0 if point_blank and pellets == 1 else pellets):
		var spread: float = float(w["spread"]) * (0.5 if from_player and gun == "revolver" and _sperk("steady") else 1.0) * (0.5 if from_player and gun == "tommy" and _perk("tg_comp") else 1.0)
		fx.shoot(at, d.rotated(randf_range(-spread, spread)) * BULLET_SPEED, from_player, w["life"])
	if gun != "revolver":   # a revolver keeps its empties until it is reloaded
		fx.casing(at - d * 50.0, signf(d.x))
	shooter.recoil = w["kick"]
	var sound: String = w["sound"] if from_player else ("shot_enemy" if gun == "revolver" else String(w["sound"]))
	if from_player:
		if gun == "revolver":   # the side gun: a Beretta cracks higher, fitted loads boom lower and louder
			var heavy := _sperk("dmg")
			sfx.play(sound, 2.5 if heavy else 0.0, INF, 0.04)
			if heavy or side == "beretta":
				sfx.pitch_last((0.86 if heavy else 1.0) * (1.18 if side == "beretta" else 1.0))
		else:
			sfx.play(sound, 0.0)
	else:
		sfx.play(sound, -2.0, at.x)
	# The comic words are a punctuation mark, not a soundtrack: only his own big moments get one,
	# a shotgun blast or a shot in slowed time, so they never drown out the bullets and the blood.
	var slowed := slow_on or Engine.time_scale < 0.9
	if from_player and gun == "shotgun":
		_word(["wham", "bam"], at + Vector2(signf(d.x) * 90.0, -160.0), 0.3, d)
	elif from_player and slowed and gun != "tommy":
		_word(["blam", "bam", "pow"], at + Vector2(signf(d.x) * 70.0, -150.0), 0.27, d)
	elif from_player and gun == "tommy" and slowed and randf() < 0.15:
		_word(["rattat"], at + Vector2(signf(d.x) * 120.0, -150.0), 0.26, d)
	shooter.next_hand()
	if from_player:
		if mag == 1 and _sperk("last") and gun == "revolver":   # the last round: it finds its man
			_last_round_t = 0.6
			_free_slow = maxf(_free_slow, 0.6)   # (audit 21. 11.: slow_on drained the whole meter for one round)
		mag -= 1
		_idle_fire = 0.0
		_clicked = false
		_show_ammo()


## A mobster opens fire the way his gun does: the tommy gunner in a burst, the boss in threes.
func _enemy_fire(e: Dictionary) -> void:
	var m = e["node"]
	match String(e["type"]):
		"boss":
			if e.has("shield"):
				_fire(m, false, "shotgun")
				e["cool"] = randf_range(1.2, 1.7)
				e["shells"] = int(e["shells"]) - 1
				_say(m, ["ONE.", "TWO.", "THREE.", "FOUR.", "FIVE."][clampi(4 - int(e["shells"]), 0, 4)])
				if int(e["shells"]) <= 0:
					e["reload_t"] = 2.4
					sfx.play("reload_shells", 0.0, m.position.x, 0.05)
				return
			_boss_fire(m)
			e["cool"] = randf_range(1.4, 2.3) * (0.55 if e.get("frantic", false) else 1.0)
		"tommy":
			for k in 6:
				get_tree().create_timer(0.09 * k, false).timeout.connect(func() -> void:
					if _still_firing(e):
						e["aim_off"] = randf_range(-110.0, 80.0) * _aim_spread()
						_fire(m, false, "tommy"))
			e["cool"] = randf_range(2.4, 3.2)
		"shotgun":
			_fire(m, false, "shotgun")
			e["cool"] = randf_range(1.5, 2.0)
		"sniper":   # he does not fire yet: he sights in, and the line shows where
			e["aim_t"] = 1.25
			e["cool"] = 99.0
			sfx.play("hammer", -6.0, m.position.x, 0.05)
			return
		"dynamite":
			if absf(player.position.x - m.position.x) < 320.0 or absf(player.position.x - m.position.x) > 1400.0:
				e["cool"] = 0.6   # too close to throw, or too far: he waits
				return
			_throw_stick(m)
			e["cool"] = randf_range(2.6, 3.4)
		_:
			# (user 17. 11.: "dumb robots - a long gap between shots; sometimes a bigger salvo; when they shout they'll bust
			# the cover I'd expect them to empty a magazine into it fast") a man shooting up a crate empties his gun into it;
			# otherwise one shot, a double tap, or now and then a salvo of three or four, like a player would
			var left := int(e.get("mag", ENEMY_MAG.get(String(e["type"]), 6)))
			var n := left if e.get("at_crate", false) else mini(left, [1, 1, 2, 2, 3, 4][randi() % 6])
			var gap := 0.13 if e.get("at_crate", false) else 0.17
			_fire(m, false)
			for k in range(1, n):
				get_tree().create_timer(gap * k, false).timeout.connect(func() -> void:
					if _still_firing(e):
						e["aim_off"] = float(e["aim_off"]) + randf_range(-45.0, 45.0) * _aim_spread()   # (each shot of a salvo kicks a bit off)
						_fire(m, false))
			e["mag"] = left - (n - 1)   # (the last one is counted below)
			e["cool"] = randf_range(0.8, 1.5) + gap * n
	_shots_at[int(e["id"])] = _ai_t
	e["cool"] = float(e["cool"]) * _ease_off() * float(diff["pause"]) * (1.35 if e.get("shaken", false) else 1.0)
	# They run dry too: a click, a few seconds fumbling with rounds, a chance to rush them.
	e["mag"] = int(e.get("mag", ENEMY_MAG.get(String(e["type"]), 6))) - 1
	if e["mag"] <= 0 and not _stand:
		e["mag"] = ENEMY_MAG.get(String(e["type"]), 6)
		var t := 0.6 if String(e["type"]) == "tommy" else 0.0   # after the burst has finished
		get_tree().create_timer(t + 0.25, false).timeout.connect(func() -> void:
			if not e["alive"] or over:
				return
			sfx.play("dry_fire", -4.0, m.position.x)
			_word(["click"], m.position + Vector2(0.0, -560.0), 0.14)
			if randf() < 0.5 and not e["boss"]:
				_bark(m, "reload")
			sfx.play("reload_mag" if String(e["type"]) != "post" else "reload_revolver", -6.0, m.position.x))
		e["cool"] = t + randf_range(2.2, 2.8)


## How far off the mobsters aim: wide when the detective stands in the dark, tight in the last stand.
## The encounter director: two or more hits on the detective in the last half minute and the
## mobsters aim a little worse and fire a little slower. Never shown, never below a fair fight.
func _ease_off() -> float:
	while not _hits_at.is_empty() and _ai_t - float(_hits_at[0]) > 30.0:
		_hits_at.pop_front()
	return 1.0 + clampf((_hits_at.size() - 1) * 0.15, 0.0, 0.6)


func _aim_spread() -> float:
	if _stand:
		return 0.5
	return _base_spread() * _ease_off() * float(diff["aim"])


func _base_spread() -> float:
	if sets.lit(player.position + Vector2(0.0, -150.0)):
		return 0.55   # in the searchlight they cannot miss
	if _in_beam(player.position):
		return 1.0    # a police flashlight on him: the dark no longer hides him
	if sets.in_smoke(player.position):
		return 2.6   # nobody can see through it
	return 2.1 if _in_dark(player.position.x) else 1.0


## Frank caught in the beam of a shield cop's flashlight: in front of him, near enough, same floor.
func _in_beam(at: Vector2) -> bool:
	for e in enemies:
		if not e["alive"] or e["type"] != "shield" or e["state"] in ["wait", "give", "down"]:
			continue
		var m = e["node"]
		var dx: float = at.x - m.position.x
		if signf(dx) == signf(m.scale.x) and absf(dx) < 950.0 and absf(at.y - m.position.y) < 200.0:
			return true
	return false


func _in_dark(x: float) -> bool:
	for i in lamps.size():
		if lamp_info[i]["on"] and absf(lamps[i].x - x) < 700.0:
			return false
	return true


## Called by fx.gd for every bullet in flight. True = the bullet stops here.
func _bullet_hit(pos: Vector2, from_player: bool) -> bool:
	_hit_at = pos   # where a word goes if this bullet kills
	for f in _flats:   # the shut door of a flat stops a bullet
		if not f["open"] and absf(pos.x - (float(f["hinge"]) - 60.0)) < 70.0 and pos.y < float(f["y"]) and pos.y > float(f["y"]) - float(f["h"]):
			fx.chip(pos)
			return true
	for sec in sections:   # a building cut open: its floors stop bullets both ways (nobody shoots through a storey)
		var x0: float = sec[0]
		var x1: float = sec[1]
		var top := -section_h * int(sec[2])
		var win := _flat_at_storey(-section_h * floorf(-pos.y / section_h), pos.x)
		var in_win: bool = not win.is_empty() and win["broken"] and pos.y < float(win["y"]) - float(win["sill"]) and pos.y > float(win["y"]) - float(win["lintel"])
		var works := String(sec[3]) == "works"
		if pos.y > top and pos.y < 0.0 and (absf(pos.x - x1) < 14.0 and not in_win and not (works and pos.y > -560.0) or absf(pos.x - x0) < 14.0 and pos.y < -560.0):
			fx.dust(pos, 0.25)   # and its outer walls (the street door on the ground floor's left is open)
			return true
		if pos.x > x0 and pos.x < x1 and not works:
			for k in range(1, int(sec[2]) + 1):
				var fy := -section_h * k
				if pos.y > fy + 5.0 and pos.y < fy + 60.0:   # just under the boards walked on: the slab, the ceiling below
					fx.dust(pos, 0.25)
					return true
	for i in boxes.size():   # cover stops bullets from both sides; wood gives way, a barrel goes up
		if boxes[i].has_point(pos):
			# the car stands at the far kerb: a man walks past in front of it, and there it hides
			# nobody; beside it, its steel stops what comes from the other side
			if box_info[i]["kind"] == "car" and player.position.x > boxes[i].position.x - 60.0 and player.position.x < boxes[i].end.x + 60.0:
				continue
			if from_player and _ricochet(i, pos):
				return true
			if not from_player and box_info[i]["kind"] == "barrel":
				fx.chip(pos)   # (audit 21. 11.) it rings off the steel
				return true
			_hit_box(i, pos)
			return true
	if from_player and props and props.shot(pos):
		cue(pos, 1.3, 0.3)   # (what the shot set off: the camera leans that way a moment)
		return true
	if from_player and (sets.bullet(pos) or mapfx.bullet(pos)):
		return true
	if from_player:
		for k in _sticks.size():   # a stick of dynamite, hit: it goes up right there
			if ((_sticks[k]["node"] as Sprite2D).position - pos).length() < 50.0:
				_stick_goes(k)
				return true
		if _load_hit(pos):
			return true
	if from_player:
		for i in lamps.size():
			if lamp_info[i]["on"] and not lamp_info[i].get("fixed", false) and pos.distance_to(lamps[i] + Vector2(0.0, float(lamp_info[i].get("glass", -8.0)))) < float(lamp_info[i].get("r", 38.0)):
				_lamp_out(i)
				return true
		if sets != null and sets.shoot_light(pos):
			return true
		for e in enemies:
			if not e["alive"] or e["state"] == "wait" or not e["node"].visible:   # (audit 21. 11.: not a man out of the picture)
				continue
			if from_player and not e["node"].hat_lost and e["node"].hat_hit(pos):
				_hat_off(e, pos)   # through the hat and nothing else: it goes, the bullet flies on
				continue
			# the gun itself: shot out of his hand, any time (2026-11-16: disarming was too rare; in slowed
			# time the forearm or the hand does it as well)
			if from_player and not e["boss"] and chapter > 0 and e["state"] not in ["give", "down"] \
					and e["type"] in ["post", "tommy", "shotgun"] and e["node"].gun_hit(pos, slow_on) and (slow_on or _perk("openhand") or randf() < 0.05):
				_disarm(e, pos)
				return true
			var part: String = e["node"].hit_part(pos)
			if part == "":
				continue
			if _shield_stops(e, part):
				fx.spark(pos)
				sfx.play("hit_cover", -2.0, pos.x, 0.12)
				_word(["zing"], pos + Vector2(0.0, -90.0), 0.16)
				if e["boss"]:   # (QUEUE §16 D) Briggs's: every round dents it, and at last it is torn off his arm
					e["shield_hp"] = int(e.get("shield_hp", BRIGGS_SHIELD)) - 1
					if int(e["shield_hp"]) <= 0:
						_shield_off(e)
				return true
			if e["state"] == "down":   # a man on his back takes one bullet (any gun: two Berettas' 0.75 left him standing)
				e["hp"] = 0.01
			if e["state"] == "give" and float(e["give_t"]) >= 0.0:   # an execution: quick to pay, slow to forget
				fx.blood(pos, fx.hit_vel, true)
				e["node"].add_wound(pos, part)
				stats["executed"] += 1
				_executed(e, pos)
				slow_left = 1.0
				if weapon != "revolver":
					ammo = int(WEAPONS[weapon]["ammo"])
					_show_ammo()
				sfx.play("hit_flesh", 0.0, pos.x)
				e["hp"] = 0
				_kill(e, part == "head", true, part)
				return true
			if e["type"] == "shade":   # no blood in him: a bullet knocks out a gust of ash and sparks
				_shade_hit(pos)
			elif (part.begins_with("farm") or part.begins_with("hand")) and (slow_on or _perk("openhand")) and not e["boss"] and chapter > 0 and e["state"] != "give":
				_disarm(e, pos)   # the gun is shot out of his hand: he has nothing left to fight with
				return true
			if e["type"] != "shade":
				fx.blood(pos, fx.hit_vel, part == "head" or e["hp"] <= 1)
				e["node"].add_wound(pos, part)
			var hm = e["node"]
			if not e.has("tint0"):
				e["tint0"] = hm.modulate
			var tint: Color = e["tint0"]   # (audit 21. 11.: two hits in 0.12 s kept him white)
			hm.modulate = Color(2.2, 2.0, 1.9)   # a white flash: the hit registers at a glance
			hm.create_tween().tween_property(hm, "modulate", tint, 0.12)
			sfx.play("hit_flesh", 0.0, pos.x)
			if e["boss"]:   # the boss takes a lot; at two thirds and one third of his health he calls for help
				e["hp"] -= 3 if part == "head" else 1
				hud.boss_bar(BOSS_NAMES.get(String(level["boss"]), "BOSS"), float(e["hp"]) / BOSS_HP)
				var calls := 2 - int(ceil(float(e["hp"]) / BOSS_HP * 3.0)) + 1
				while e["calls"] < calls and e["hp"] > 0:
					e["calls"] += 1
					if String(level["boss"]) == "kessler":   # he goes to ground in his own smoke
						sets.smoke(e["node"].position)
					_spawn_runner(e["node"].position.x + 1700.0, e["node"].position.x - 450.0)
					_spawn_runner(e["node"].position.x + 2000.0, e["node"].position.x - 750.0)
				if e["hp"] > 0 and e["hp"] <= BOSS_HP / 3 and not e.get("last_third", false):
					e["last_third"] = true
					_boss_last_third(e)
				if e["hp"] <= 0:
					hud.boss_bar("", -1.0)
					if e.has("shield"):   # Briggs goes down, but not out: the detective decides
						_briggs_down(e)
						return true
			else:
				e["hp"] -= (_head_dmg() if part == "head" else mob_hp) if (part == "head" or _last_round_t > 0.0) else _body_dmg()   # a head shot kills (two Berettas: two of them)
				if e["hp"] > 0 and e.has("witness"):   # (he is no fighter: hit, his hands go up)
					_give_up(e)
				if e["hp"] > 0:   # still up: knocked back a step, off his aim for a moment
					var m2 = e["node"]
					var back: float = signf(m2.position.x - player.position.x) * (70.0 if part == "torso" else 40.0)
					var clear := true   # never knocked into a crate, where bullets could no longer reach him
					for bx in boxes:
						if bx.grow(30.0).has_point(Vector2(m2.position.x + back, m2.position.y - 60.0)):
							clear = false
					if clear and e["state"] == "post":
						m2.create_tween().tween_property(m2, "position:x", m2.position.x + back, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					e["cool"] = maxf(float(e["cool"]), 0.7)
					e["timer"] = maxf(float(e["timer"]), 0.6)

			e["seen"] = true   # being shot at wakes him up, however far away
			if e["hp"] <= 0:
				_kill(e, part == "head", false, part)
			return true
		return false
	if over or cleared:
		return false
	if player.hit_part(pos) == "":   # the posed body: flying flat or crouched he really is a smaller target
		return false
	if _hurt_t > 0.0:   # the same blast hit him a moment ago
		return true
	_hurt_t = 0.3
	stats["hits"] += 1
	_combo = 0   # a hit breaks the streak
	_combo_t = 0.0
	_hits_at.append(_ai_t)
	fx.blood(pos, fx.hit_vel)
	player.add_wound(pos, "")   # he flinches
	sfx.play("hit_flesh", 2.0)
	_shake = maxf(_shake, 0.18)
	_buzz(35)
	hud.hurt(float(hp - 1) / max_hp)
	if (_dt < 0.0 or _dt > 7.4) and _tt < 0.0 and (_auto == "" or _auto == "stand"):   # nobody gets hurt during the demo or the tests
		hp -= 1
		hud.set_health(float(hp) / max_hp)
		if hp == 1:
			_inner_voice()
		if hp <= 0:
			_player_down()
		elif hp == 1 and _perk("lastchance") and not _last_chance_used:   # time slows by itself, once a map
			_last_chance_used = true
			slow_left = 1.0
			slow_on = true
			hud.toast("LAST CHANCE")
	return true


## One hit from the end, the voice in his head (voice/<md5>.mp3, the narrator's): never the same line
## twice running, and not again for a while.
const INNER := ["Barely a flesh wound.", "Get up, old man.", "Not tonight. Not like this.", "Breathe, Malone. Just breathe.",
	"Eddie never quit. Neither do you.", "Bleed later. Shoot now."]
var _inner_t := -100.0
var _inner_last := ""
func _inner_voice() -> void:
	if over or chapter == 0 or _time - _inner_t < 40.0 or sfx.voice_on():
		return
	_inner_t = _time
	var pick: String = INNER.pick_random()
	if pick == _inner_last:
		pick = INNER[(INNER.find(pick) + 1) % INNER.size()]
	_inner_last = pick
	hud.caption([pick])


## The kick: a dive into a man knocks him flat on his back. On the pavement he cannot shoot and one
## bullet finishes him; left alone he either gets up again or, shaken, gives up where he lies.
## Frank's move (not the prologue's, not a boss, not a shield).
func _kick_check() -> void:
	if player.clip == "" and absf(glide) > 400.0 and not _kicked_this_dive:   # a man or a shut door just ahead: the boot comes up
		var ahead := false
		for e in enemies:
			var ddx: float = e["node"].position.x - player.position.x
			if e["alive"] and not e["boss"] and signf(ddx) == signf(glide) and absf(ddx) < 330.0 and absf(float(e["node"].position.y) - player.position.y) < 260.0 and String(e["state"]) in ["post", "run", "move", "hop"]:
				ahead = true
		var fd := _flat_at_storey(_ground_y)
		if not fd.is_empty() and not fd["open"] and glide > 0.0 and absf(player.position.y - float(fd["y"])) < 80.0:
			var face := float(fd["hinge"]) - float(fd["span"]) - 30.0
			ahead = ahead or (face - player.position.x > 0.0 and face - player.position.x < 330.0)
		if ahead:
			_clip("fly_kick", glide)
	if diff_step < 0 or _kicked_this_dive:
		return
	for e in enemies:
		if not e["alive"] or e["boss"] or e.has("shield") or not (String(e["state"]) in ["post", "run", "move", "hop"]):
			continue
		var m = e["node"]
		var dx: float = m.position.x - player.position.x
		if absf(dx) > 120.0 or signf(dx) != signf(glide) or absf(m.position.y - player.position.y) > 260.0:
			continue
		_kicked_this_dive = true
		e["state"] = "down"
		e["down_t"] = 0.0
		e["seen"] = true
		m.duck = 0.0
		m.slide_side = 1.0   # (his own forward: he faces Frank) on his back, boots towards the man who kicked him
		e["push"] = signf(dx) * 700.0   # he skids back along the wet stones
		glide *= 0.12   # the kick takes the speed out of the dive: Frank drops in front of him
		sfx.play("punch", 0.0, m.position.x, 0.08)
		_word(["wham", "pow"], m.position + Vector2(0.0, -300.0), 0.3)
		_shake = maxf(_shake, 0.22)
		stats["kicks"] = int(stats.get("kicks", 0)) + 1
		return


## The lead pipe: walk up on a man and Frank lays him out with the pipe from his coat (puppet.gd swing),
## once every PIPE_COOL seconds. Flat on the stones he gives himself up when he comes round.
const PIPE_COOL := 6.0
const PIPE_TIME := 0.42
const PIPE_REACH := 170.0
var _pipe_cool := 0.0
var _pipe_t := -1.0
var _pipe_hit := false
var _pipe_e = null
var _kick_at := 0.0
func _tick_pipe(delta: float) -> void:
	_pipe_cool = maxf(0.0, _pipe_cool - delta)
	if _pipe_t >= 0.0:
		_pipe_t += delta / PIPE_TIME
		player.swing = minf(_pipe_t, 1.0)
		if not _pipe_hit and _pipe_t >= 0.47 and _pipe_e != null:
			_pipe_hit = true
			var e: Dictionary = _pipe_e
			if e["alive"] and String(e["state"]) in ["post", "run", "move", "hop"]:
				var m = e["node"]
				var dx: float = m.position.x - player.position.x
				e["state"] = "down"
				e["down_t"] = 0.0
				e["seen"] = true
				e["pipe"] = true
				m.duck = 0.0
				m.slide_side = 1.0
				e["push"] = signf(dx) * 520.0
				sfx.play("punch", 2.0, m.position.x, 0.06)
				sfx.play("hit_cover", -6.0, m.position.x, 0.1)   # the ring of the iron
				_word(["wham", "bam"], m.position + Vector2(0.0, -520.0), 0.3)
				_shake = maxf(_shake, 0.28)
				_impact(0.06, 0.05)
				stats["pipe"] = int(stats.get("pipe", 0)) + 1
		if _pipe_t >= 1.0:
			_pipe_t = -1.0
			player.swing = -1.0
		return
	if _pipe_cool > 0.0 or over or diff_step < 0 or move_state != "ground" or reloading > 0.0 or player.duck > 0.3:
		return
	for e in enemies:
		if not e["alive"] or e["boss"] or e.has("shield") or not (String(e["state"]) in ["post", "run", "move", "hop"]):
			continue
		var m = e["node"]
		var dx: float = m.position.x - player.position.x
		if absf(dx) > PIPE_REACH or absf(m.position.y - player.position.y) > 120.0:
			continue
		_pipe_e = e
		_pipe_t = 0.0
		_pipe_hit = false
		_pipe_cool = PIPE_COOL
		player.snap_aim(Vector2(signf(dx), 0.15))
		return


const KNOCK_ROLL := 0.5
func _knocked(e: Dictionary, delta: float) -> void:
	var m = e["node"]
	e["down_t"] = float(e["down_t"]) + delta
	var t: float = e["down_t"]
	m.slide = move_toward(m.slide, 1.0 if t < 2.3 else 0.0, delta * (6.0 if t < 2.3 else 2.5))
	m.roll = -KNOCK_ROLL * m.slide   # flat on his back, not sitting
	var push: float = e.get("push", 0.0)
	if push != 0.0:
		var step := push * delta
		var blocked := false
		for bx in boxes:
			if bx.grow(30.0).has_point(Vector2(m.position.x + step * 4.0, m.position.y - 60.0)):
				blocked = true
		if not blocked:
			m.position.x += step
		e["push"] = move_toward(push, 0.0, 1100.0 * delta)
	m.set_state(0.0, Vector2(signf(player.position.x - m.position.x), 0.4), delta)
	if t > 2.3 and not e.has("decided"):   # he has had time to think about it
		e["decided"] = true
		var gives: float = 0.45 + (0.25 if _perk("voice") else 0.0) + (0.2 if e.get("shaken", false) else 0.0) + (1.0 if e.get("pipe", false) else 0.0)
		if randf() < gives:
			m.slide = 0.0
			m.roll = 0.0
			_give_up(e)
			return
	if t > 2.8:
		m.slide = 0.0
		m.roll = 0.0
		e.erase("decided")
		e["state"] = "post"
		e["cover"] = _has_cover(m.position)
		e["cool"] = randf_range(0.8, 1.3)


## A mobster goes down: counted for the score, his gun left on the pavement.
func _kill(e: Dictionary, head: bool, quiet := false, part := "") -> void:
	e["alive"] = false
	if e.has("witness"):   # the lead is found on him: the story goes on, but not from his mouth
		if ARGS.has("--log-sets"): print("WITNESS KILLED at ", int(e["node"].position.x), " state ", e["state"], " head ", head)
		var lines: Array = WITNESS["%d:%d" % [chapter, map]][4]
		get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
			if not over:
				hud.caption(lines))
		if _auto == "":
			MenuScript.set_story("witness_%d-%d" % [chapter, map], "dead")
	var mk = e["node"].get_meta("mark") if e["node"].has_meta("mark") else null
	if mk != null and is_instance_valid(mk):
		mk.queue_free()
	_buzz(25 if head else 18)
	_score(e, head, part)
	var m = e["node"]
	stats["kills"] += 1
	stats["heads"] += 1 if head else 0
	stats["slow"] += 1 if Engine.time_scale < 1.0 else 0
	var how := "head" if head else ("blast" if part == "blast" else ("leg" if part.begins_with("thigh") or part.begins_with("shin") else ""))
	if _all_down() and not _stand:   # the last of them: the final shot plays out slowly
		_impact(1.1, 0.22)
		_shake = maxf(_shake, 0.12)
	elif not quiet:
		_impact(0.07 if head else 0.045, 0.05)
	# (audit 17. 11.: a kill felt weightless - the gun went down with the drawing) the gun leaves his hand, spinning,
	# and clatters on the stones; a head shot takes the hat off with it
	if e["type"] == "post" and not m.disarmed and m._gun != null and m._gun.visible and part != "blast":
		var src: Sprite2D = m._gun
		var gg := Sprite2D.new()
		gg.texture = src.texture
		gg.offset = src.offset
		gg.global_scale = src.global_scale.abs()
		gg.flip_h = src.global_scale.x < 0.0
		gg.global_position = src.global_position
		gg.global_rotation = src.global_rotation
		gg.modulate = _undo_night(0.55)
		gg.z_index = 1
		add_child(gg)
		src.visible = false
		var away2 := signf(m.position.x - player.position.x)
		_flying_guns.append({"node": gg, "v": Vector2(away2 * randf_range(160.0, 320.0), -randf_range(420.0, 640.0)),
			"spin": away2 * randf_range(8.0, 14.0), "ground": m.position.y - 10.0, "bounce": 0, "kind": "post"})
	if e["type"] == "shade":   # he does not fall: he comes apart into ash
		_shade_gone(m)
	if head and not m.hat_lost and m.hat_path() != "" and e["type"] != "shade":
		var info: Dictionary = m.lose_hat()
		var hh := Sprite2D.new()
		hh.texture = info["tex"]
		hh.centered = false
		hh.offset = info["offset"]
		hh.modulate = _undo_night(0.5)
		hh.z_index = 1
		add_child(hh)
		hh.global_transform = info["xform"]
		var away3 := signf(m.position.x - player.position.x)
		_flying_guns.append({"node": hh, "v": Vector2(away3 * randf_range(300.0, 450.0), -randf_range(700.0, 900.0)),
			"spin": away3 * randf_range(9.0, 13.0), "ground": m.position.y - 6.0, "bounce": 0, "kind": "hat"})
	_drop(m, signf(m.position.x - player.position.x), true, how)
	if not quiet and (head or _all_down() or slow_on):   # a headshot, the last man, or a kill in slowed time
		var at: Vector2 = _hit_at if part not in ["", "blast"] and _hit_at != Vector2.INF and _hit_at.distance_to(m.position) < 700.0 else m.position + Vector2(0.0, -420.0)
		_word(["crack"] if head else ["pow", "wham", "bam"], at + Vector2(signf(m.position.x - player.position.x) * 60.0, -70.0), 0.27)   # at the hit, thrown the way the bullet went
	if e["type"] in ["tommy", "shotgun"]:
		_add_pickup(String(e["type"]), m.position)
	elif randf() < 0.12:
		_add_pickup("flask", m.position)
	_fallen.append([String(e.get("name", "")), m.position.x, _ai_t])
	_cry(e, m, head)
	if e.get("role", "") == "lead":   # the man who gave the orders is down: the rest falter
		var next = null
		for o in enemies:
			if o["alive"] and o != e and absf(o["node"].position.x - m.position.x) < GROUP:
				o["shaken"] = true
				if o.get("role", "") == "flank" and (next == null or absf(o["node"].position.x - m.position.x) < absf(next["node"].position.x - m.position.x)):
					next = o
		if next != null:   # (audit 21. 11.) ... and then one of them gives the orders
			next["role"] = "lead"
	_witness(e, m)
	_morale(m.position, head or slow_on)


## Style points: how a man went down, not just that he did. A base of 100, doubled for a head shot,
## doubled again in the air, half again in slowed time, more for a trick (a ricochet, a blast), and
## all of it times the streak. A man who had already given up is worth nothing and ends the streak:
## the game never pays for an execution. The map's stars come from this score (see _rate).
## Experience earned on this map so far (saved when the map is won; a death loses it). A level
## reached mid-fight is announced at once.
var _xp_run := 0
func _gain_xp(n: int) -> void:
	if _stand or diff_step < 0 or n <= 0:
		return
	var before := Instincts.level_at(Instincts.xp() + _xp_run)
	_xp_run += n
	var now := Instincts.level_at(Instincts.xp() + _xp_run)
	if now > before:
		hud.level_up(now)
		sfx.play("sting", -4.0)
		crumb("level up %d" % now)


func _score(e: Dictionary, head: bool, part: String) -> void:
	if (e["state"] == "give" and float(e.get("give_t", 0.0)) >= 0.0) or _stand or diff_step < 0:
		_combo = 0
		_combo_t = 0.0
		return
	var pts := 100.0
	var how: Array = []
	if head:
		pts *= 2.0
		how.append("HEAD SHOT")
	var air := move_state in ["jump", "dive", "flip", "swing", "zip"]
	if air:
		pts *= 2.0
		stats["air"] += 1
		how.append("IN THE AIR")
	if Engine.time_scale < 1.0:
		pts *= 1.5
	if part == "blast":
		pts *= 1.5
		how.append("BOOM")
	elif _bounce_t > 0.0:
		pts *= 2.0
		how.append("RICOCHET")
	_combo = mini(_combo + 1, COMBO_MAX) if _combo_t > 0.0 else 1
	_combo_t = COMBO_GAP
	pts *= _combo
	stats["score"] += int(pts)
	_gain_xp(int(pts))
	stats["best_combo"] = maxi(int(stats["best_combo"]), _combo)
	hud.combo(_combo, int(pts), " ".join(how))
	if _combo == 2 and chapter == 1 and map == 0 and not _streak_told:   # once: what the numbers up top are
		_streak_told = true
		hud.hint("KILLS CLOSE TOGETHER BUILD A STREAK. IN THE AIR AND TO THE HEAD SCORE MORE. THE SCORE IS YOUR XP.", true)
	if _combo == 3 and _perk("hotstreak"):   # HOT STREAK: a round back, in the gun (audit 21. 11.: the side gun got none)
		if weapon == "revolver":
			mag = mini(mag + 1, _mag_size(weapon))
			_show_ammo()
		elif ammo < int(WEAPONS[weapon]["ammo"]):
			ammo += 1
			_show_ammo()
	if air and _perk("acrobat"):   # ACROBAT: a kill in the air gives back slowed time
		slow_left = minf(1.0, slow_left + 0.25)


## The last man of a group, seeing the others go down, may give up instead of dying for it. A
## wounded man always does; a fresh one sometimes, more often when it went fast and ugly.
const GROUP := 1700.0
func _morale(at: Vector2, ugly: bool) -> void:
	if _stand or chapter == 0 or over:
		return
	for e2 in enemies:
		if not e2["alive"] or e2["boss"] or e2["state"] in ["wait", "give", "run", "stairs", "around", "hop", "down"] or not e2["seen"] \
				or e2.has("witness"):
			continue
		var p2: Vector2 = e2["node"].position
		if absf(p2.x - at.x) > GROUP or absf(p2.y - at.y) > 300.0:   # (audit 21. 11.) his own floor: not a storey away
			continue
		var others := 0
		for e3 in enemies:
			if e3 != e2 and e3["alive"] and e3["state"] != "give" and not e3.has("witness") and absf(e3["node"].position.x - p2.x) < GROUP \
					and absf(e3["node"].position.y - p2.y) < 300.0:
				others += 1
		if others > 0:
			continue
		if not e2.get("alone_said", false):
			e2["alone_said"] = true
			var gone := ""
			for f in _fallen:
				if absf(float(f[1]) - p2.x) < GROUP * 1.3 and String(f[0]) != "":
					gone = String(f[0])
			get_tree().create_timer(0.9, false).timeout.connect(func() -> void:
				if e2["alive"] and e2["state"] != "give":
					_bark(e2["node"], "alone", gone, true))
		var chance := 1.0 if int(e2["hp"]) < mob_hp else (0.65 if ugly else 0.4) + (0.25 if e2.get("shaken", false) else 0.0) + (0.25 if _perk("voice") else 0.0)
		chance *= _quit_odds()   # word gets round: a man who shoots men with their hands up gets fewer hands up
		if randf() < chance:
			_give_up(e2, 0.55)
		elif _guilt_now() >= 6 and not e2.get("noquit_said", false):
			e2["noquit_said"] = true
			var e4: Dictionary = e2
			get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
				if e4["alive"] and e4["state"] != "give":
					_bark(e4["node"], "noquit", "", true))


## The ash as it stands right now: what is saved, plus this map so far (saved only when it is closed).
func _guilt_now() -> int:
	return maxi(0, MenuScript.guilt() + int(stats["executed"]) * 2 - int(stats["spared"]))


## How many of the six pages tucked behind the portrait he holds: his share of what Rosie needs.
func _pages_held() -> int:
	var total := maxi(1, MenuScript.evidence_total())
	return clampi(int(round(6.0 * MenuScript.evidence() / float(total))), 0, 6) if _auto == "" or MenuScript.evidence() > 0 else 0


## Fewer men give up the more Frank has shot with their hands up, more when he lets them walk.
func _quit_odds() -> float:
	return clampf(1.2 - _guilt_now() * 0.09, 0.2, 1.25)


## A man shot with his hands up (2026-11-16): the picture greys for a breath, ash falls where he stood,
## a match is struck somewhere, the soot spreads on Frank's portrait; a man who saw it says so by name,
## and the first time on a map Frank says something about it himself.
func _executed(e: Dictionary, at: Vector2) -> void:
	(stats["shot_up"] as Array).append(String(e.get("name", "")))
	var g := _guilt_now() / 10.0
	atmo.pulse_ash(MenuScript.guilt() / 10.0, minf(1.0, g + 0.45))
	sfx.play("match", -2.0, INF, 0.0)
	hud.soot_up(g)
	var p := CPUParticles2D.new()   # the ash coming down over him
	p.texture = atmo._flake()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 60
	p.lifetime = 3.5
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260.0, 40.0)
	p.position = at + Vector2(0.0, -620.0)
	p.direction = Vector2(0.2, 1.0)
	p.spread = 30.0
	p.gravity = Vector2(10.0, 90.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var gr := Gradient.new()
	gr.set_color(0, Color(0.85, 0.83, 0.8, 0.0))
	gr.set_color(1, Color(0.6, 0.58, 0.55, 0.0))
	gr.add_point(0.1, Color(0.85, 0.83, 0.8, 0.95))
	p.color_ramp = gr
	p.z_index = 15
	add_child(p)
	p.emitting = true
	get_tree().create_timer(4.0, false).timeout.connect(p.queue_free)
	var best = null
	for o in enemies:   # somebody saw him shot like that
		if o != e and o["alive"] and not o["boss"] and o["state"] not in ["give", "wait"] and absf(o["node"].position.x - at.x) < 1800.0 \
				and absf(o["node"].position.y - at.y) < 250.0:
			best = o
	if best != null:
		var who: Dictionary = best
		var nm := String(e.get("name", ""))
		get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
			if who["alive"] and who["state"] != "give":
				_bark(who["node"], "shotup", nm, true))
	elif int(stats["executed"]) == 1 and not _stand:
		hud.caption([["One more I'll carry.", "His hands were up.", "Eddie wouldn't have done that."].pick_random()])


## He drops the gun and puts his hands up. Shot like that, he is an execution; left alone, he backs
## off and is gone, and what he saw is Frank's to use later.
func _give_up(e: Dictionary, delay := 0.0) -> void:
	e["node"].slide = 0.0
	e["node"].roll = 0.0
	if e["state"] == "give" or _unreal():   # in the dream nobody gives up
		return
	if e.has("witness") and level.has("witness_house") and not e.get("holed_up", false) and int(e["hp"]) >= mob_hp:
		return   # (BACK STREETS) Sammy runs for his room: not the street's morale - only a bullet or his own door stops him
	e["state"] = "give"
	e["give_t"] = -delay
	e["said"] = false
	var m = e["node"]
	m.reload = 0.0
	if chapter >= 1 and not _stand and not _taught_run and MenuScript.story("mercy_taught") != "yes":
		_taught_run = true
		# the first man ever to give up: the game stops to say it is a choice, and what it weighs
		if _auto == "":
			MenuScript.set_story("mercy_taught", "yes")
		e["give_t"] = -delay - 1.2   # a longer look before he backs off
		_impact(0.7, 0.2)
		hud.caption(["He dropped the gun.", "Eddie would have let him walk."])
		hud.hint("HE GAVE UP. HOLD YOUR FIRE AND HE WALKS. SHOOT HIM AND YOU CARRY IT.", true)


## A bullet into a box: wood splinters and finally gives way, metal sparks, a barrel explodes.
func _hit_box(i: int, pos: Vector2) -> void:
	var info: Dictionary = box_info[i]
	if info["kind"] == "barrel":
		_explode.call_deferred(boxes[i].get_center(), i)
		return
	_last_hit = pos
	if not info["wood"]:
		fx.spark(pos)
		sfx.play("hit_cover", -4.0, pos.x, 0.12)
		if randf() < 0.35:   # off steel: the bullet sings away
			_word(["zing"], pos + Vector2(0.0, -90.0), 0.16)
		return
	sfx.play("wood_hit", -3.0, pos.x, 0.12)
	for k in 3:   # chips fly off the boards where the bullet went in
		fx.chip(pos)
	info["hp"] -= 3 if _perk("splinters") else 1   # SPLINTERS: wooden cover goes to pieces in a few shots
	var s: Sprite2D = info["sprite"]
	s.modulate = Color(1, 1, 1).darkened(0.08 * (7 - int(info["hp"])))
	var tw := s.create_tween()
	tw.tween_property(s, "position:x", s.position.x + 6.0, 0.03)
	tw.tween_property(s, "position:x", s.position.x, 0.05)
	if info["hp"] <= 0:
		_break_box(i)


## A crate shot to pieces: it collapses, splinters fly, and whoever hid behind it is in the open.
func _break_box(i: int) -> void:
	var r: Rect2 = boxes[i]
	var s: Sprite2D = box_info[i]["sprite"]
	boxes.remove_at(i)
	box_info.remove_at(i)
	sfx.play("wood_break", 0.0, r.get_center().x, 0.08)
	fx.break_apart(s, _last_hit, r.end.y)
	_word(["crash", "crash2"], r.get_center() + Vector2(0.0, -160.0), 0.24)
	s.queue_free()
	for e in enemies:
		if e["alive"] and e["state"] == "post":
			e["cover"] = _has_cover(e["node"].position)


## A barrel goes up: everyone close is thrown down, crates near it burst, other barrels follow it.
func _explode(at: Vector2, i: int) -> void:
	if i >= boxes.size() or boxes[i].get_center() != at:
		i = -1
		for k in boxes.size():
			if boxes[k].get_center() == at:
				i = k
	if i < 0:
		return
	box_info[i]["sprite"].queue_free()
	var floor_y: float = boxes[i].end.y
	boxes.remove_at(i)
	box_info.remove_at(i)
	_blast(at, 380.0, 330.0, 2)
	# the fuel spills and burns where the drum stood: a pool of fire for a while that hurts to cross
	sets._blaze(at.x - 160.0, 320.0, 9.0, floor_y, 1.2)


## A blast at `at`: men within `reach` go down, Frank within `hurt_reach` takes `hits`, crates near it
## break, barrels near it follow, lamps near it go out.
func _blast(at: Vector2, reach: float, hurt_reach: float, hits: int) -> void:
	_scare_birds(at, 2600.0)
	sfx.play("explosion", 2.0, at.x, 0.0)
	_buzz(50)
	_shake = 0.5
	fx.word("res://art/fx/word_krakoom.png", at + Vector2(0.0, -260.0), 0.5)
	fx.blast(at)
	var flash := Sprite2D.new()
	flash.texture = _soft_glow()
	flash.position = at
	flash.scale = Vector2.ONE * 1.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flash.material = mat
	flash.modulate = _undo_night(1.2) * Color(1.0, 0.75, 0.4)
	flash.z_index = 8
	add_child(flash)
	var tw := flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector2.ONE * 5.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(flash.queue_free)
	for k in 8:
		fx.spark(at + Vector2(randf_range(-160.0, 160.0), randf_range(-200.0, 40.0)))
	for e in enemies:
		if e["alive"] and e["state"] != "wait" and e["node"].position.distance_to(at + Vector2(0.0, 60.0)) < reach:
			if e["boss"]:
				e["hp"] -= 4
				hud.boss_bar(BOSS_NAMES.get(String(level["boss"]), "BOSS"), float(e["hp"]) / BOSS_HP)
				if e["hp"] > 0:
					continue
				hud.boss_bar("", -1.0)
			_kill(e, false, true, "blast")
	if not over and not cleared and player.position.distance_to(at + Vector2(0.0, 60.0)) < hurt_reach and _auto == "":
		hp -= hits
		stats["hits"] += 1
		hud.set_health(float(hp) / max_hp)
		if hp == 1:
			_inner_voice()
		if hp <= 0:
			_player_down()
	for k in range(boxes.size() - 1, -1, -1):
		if k < boxes.size() and boxes[k].get_center().distance_to(at) < 420.0:
			if box_info[k]["kind"] == "barrel":
				get_tree().create_timer(0.15, false).timeout.connect(_explode.bind(boxes[k].get_center(), k))
			elif box_info[k]["wood"]:
				_break_box(k)
	for k in lamps.size():
		if lamp_info[k]["on"] and lamps[k].distance_to(at) < 500.0:
			_lamp_out(k)


## A lamp shot out: its glow and light go, glass rains down, and the street around it is dark.
func _lamp_out(i: int) -> void:
	var rec: Dictionary = lamp_info[i]
	if rec.has("chandelier"):   # the chain snaps: it comes down (its light goes with it below)
		_drop_chandelier(rec["chandelier"])
	if rec.has("pend"):   # the shot jolts it on its cord; the swing dies away and it hangs dead still
		var pd: Dictionary = rec["pend"]
		pd["kick"] = deg_to_rad(14.0)
		var dt := create_tween()
		dt.tween_method(func(v: float) -> void: pd["damp"] = v, 1.0, 0.0, 2.5)
		dt.parallel().tween_method(func(v: float) -> void: pd["kick"] = minf(float(pd["kick"]), v), deg_to_rad(14.0), 0.0, 3.0)
	if rec.has("hum"):
		rec["hum"]["on"] = false
	rec["broken"] = true
	rec["on"] = false   # dark for the aim at once; to the eye it dies over a few stuttering flickers
	fx.shatter(lamps[i] + Vector2(0.0, float(rec.get("glass", -8.0))))
	var hole := Sprite2D.new()   # the glass is gone: a jagged black hole and cracks where the bulb was
	hole.texture = load("res://art/fx/bulb_broken.png")
	hole.position = lamps[i] + Vector2(0.0, float(rec.get("glass", -6.0)))
	hole.scale = Vector2.ONE * (float(rec.get("hole", 0.26)) if rec.has("off") else 0.17)
	hole.rotation = randf_range(-0.6, 0.6)
	hole.z_index = -3
	if rec.has("pend"):
		hole.position = Vector2(0.0, float(rec["pend"]["len"]) + 2.0)
		hole.scale = Vector2.ONE * 0.12
		rec["pend"]["node"].add_child(hole)
	else:
		add_child(hole)
	sfx.play("zap", -6.0, lamps[i].x, 0.1)
	_word(["smash"], lamps[i] + Vector2(0.0, -120.0), 0.2)
	sfx.play("glass", -2.0, lamps[i].x, 0.1)
	var light: PointLight2D = rec["light"]
	var tw := create_tween()
	for k in randi_range(3, 5):
		var show := k % 2 == 1
		tw.tween_callback(func() -> void:
			for n in rec["nodes"]:
				n.visible = show
			if light != null:
				light.enabled = show
				light.energy = randf_range(0.5, 1.3) if show else 0.0)
		tw.tween_interval(randf_range(0.03, 0.11))
	tw.tween_callback(func() -> void:
		for n in rec["nodes"]:
			n.visible = false
		if rec.has("off"):
			rec["off"].visible = true
		if light != null:
			light.enabled = false)


## One of the detective's bullets met one of theirs in the air.
func _bullets_clash(at: Vector2) -> void:
	fx.word("res://art/fx/word_clink.png", at + Vector2(0.0, -110.0), 0.22)
	if not _stand and diff_step >= 0:   # a bullet shot out of the air is style too, and keeps the streak alive
		stats["score"] += 50
		_gain_xp(50)
		_combo_t = maxf(_combo_t, COMBO_GAP)
		hud.combo(_combo, 50, "CLINK")
	sfx.play("clink", -3.0, at.x)
	slow_left = minf(1.0, slow_left + (0.225 if _perk("bloodtime") else 0.15))   # a little slowed time back as a reward


## The detective is shot dead: he goes down in slow motion, the screen says so, and the level restarts.
func _player_down() -> void:
	crumb("died " + _mem_line())
	_event("died", {"kills": int(stats["kills"]), "hits": int(stats["hits"]), "cp": int(checkpoint)})
	_buzz(60)
	over = true
	slow_on = false
	_death_t = 0.0
	sfx.play("death_sting", 0.0, INF, 0.0)
	var killer = _nearest_enemy()
	_drop(player, signf(player.position.x - killer.position.x) if killer != null else -player.scale.x, false)
	if _stand:   # the prologue ends as it must: Eddie down, and the story passes to Frank
		if _auto != "":
			get_tree().create_timer(1.6, true, false, true).timeout.connect(hud.caption.bind(level["outro"]))
		else:
			MenuScript.mark_done(chapter, map)   # (audit 22. 11.) saved now: a tab killed in the comic (its memory peak) kept the prologue unplayed
			get_tree().create_timer(3.2, true, false, true).timeout.connect(_play_cut.bind(CUTS["0:0"], func() -> void:
				Engine.time_scale = 1.0
				chapter += 1
				map = 0
				checkpoint = -1.0
				checkpoint_y = 0.0
				_travel(true)))
		return
	get_tree().create_timer(0.6, true, false, true).timeout.connect(hud.banner.bind("LIGHTS OUT"))
	if checkpoint_y < 0.0 and not roof.is_empty() and absf(checkpoint_y - float(roof["y"])) < 1.0 and player.position.y > float(roof["y"]) + 300.0:
		checkpoint = _ground_cp   # he went back down and died below: he comes back below, not up on the roof
		checkpoint_y = 0.0
	if _auto == "":
		get_tree().create_timer(2.0, true, false, true).timeout.connect(_restart)


## (audit 21. 11.) A checkpoint: where he comes back, and what he had done by then (see _cp_keep).
func _take_checkpoint(x: float, y: float, toast := true) -> void:
	checkpoint = x
	checkpoint_y = y
	var bag := _bag.duplicate(true)
	bag[weapon] = {"mag": mag, "ammo": ammo}
	_cp_keep = {"map": "%d:%d" % [chapter, map], "stats": stats.duplicate(true), "xp": _xp_run, "bag": bag}
	if _auto == "" and _sandbox < 0:
		MenuScript.save_cp({"map": _cp_keep["map"], "x": x, "y": y, "ground": _ground_cp, "keep": _cp_keep})
	if toast:
		hud.toast("CHECKPOINT")


## A dive, a roll, a slide, or running in slowed time leaves a short string of ink silhouettes of
## the detective behind him, each one fading as the next is laid down.
func _afterimages(delta: float, running: float) -> void:
	var on: bool = not over and (move_state in ["dive", "roll", "slide", "flip"] or (Engine.time_scale < 1.0 and running > 0.3))
	_ghost_t -= delta
	if not on or _ghost_t > 0.0:
		return
	_ghost_t = 0.05
	var g: CanvasGroup = player.ghost()
	var paper := Color(0.9, 0.87, 0.8) * _undo_night(0.5)   # pale paper ghosts read against the dark street
	g.self_modulate = Color(paper.r, paper.g, paper.b, 0.45)
	g.z_index = -1   # behind the detective and the mobsters, in front of the crates
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "self_modulate:a", 0.0, 0.26).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)


func _auto_arg() -> String:
	for arg in ARGS:
		if arg.begins_with("--test="):
			return arg.trim_prefix("--test=")
	return ""


## The map is won: it is marked done, the detective's closing words come up, and the next map starts
## (after a chapter's last map, the case file opens again).
func _map_cleared() -> void:
	crumb("cleared " + _mem_line())
	_event("cleared", {"kills": int(stats["kills"]), "hits": int(stats["hits"]), "spared": int(stats["spared"]), "executed": int(stats["executed"]), "t": int(stats["time"])})
	cleared = true
	MenuScript.mark_done(chapter, map)
	MenuScript.clear_cp()
	if _auto == "":
		MenuScript.set_conduct(chapter, map, int(stats["executed"]), int(stats["spared"]))
	var cut: String = CUTS.get("%d:%d" % [chapter, map], "")
	if cut == "" or _auto != "":
		hud.caption(level["outro"])
	_rate()
	var maps: Array = Levels.CAMPAIGN[chapter]["maps"]
	var next_c := chapter
	var next_m := map + 1
	var to_menu := false
	if next_m >= maps.size():   # the tally card says the chapter is closed
		next_m = 0
		next_c = mini(chapter + 1, Levels.CAMPAIGN.size() - 1)
		to_menu = true
	if _auto == "play":
		print("BOT CLEARED chapter ", chapter, " map ", map, " in ", int(_at), " s  hits taken ", stats["hits"], "  heads ", stats["heads"], "/", stats["kills"])
		get_tree().quit()
	elif _auto == "":
		var go := func() -> void:
			chapter = next_c
			map = next_m
			checkpoint = -1.0
			checkpoint_y = 0.0
			in_menu = to_menu
			_travel(not to_menu)
		# (audit 22. 11.) the tally card stays until a tap (after a moment to see it), or goes on by itself after a
		# while; it was 3 s before a comic hid it, too short for the level line and six rows
		var on := func() -> void:
			if not _after_tally.is_valid():
				return
			_after_tally = Callable()
			if cut != "":   # the story takes over for a page or two, then the next map
				_play_cut(cut, go)
			else:
				go.call()
		_after_tally = on
		_tally_ms = Time.get_ticks_msec()
		get_tree().create_timer(9.0 if cut != "" else 12.0).timeout.connect(on)


## A comic-page cutscene over the game, then `then`.
## A comic page in the middle of a map (rule 30, like Max Payne's): the street holds still under it, then play goes
## on where it stopped. Every time, like Max Payne's (SKIP is on the page).
func _mid_comic(id: String) -> void:
	if ARGS.has("--log-sets"): print("COMIC ", id, " t ", snappedf(_at, 0.1))
	if _auto != "" or over:
		return
	get_tree().paused = true
	_play_cut(id, func() -> void:
		get_tree().paused = false
		hud.release_all()
		_in_cut = false
		hud.visible = true
		_grace = maxf(_grace, 1.2))   # (a beat to take it in before anybody fires)


func _play_cut(id: String, then: Callable, test := false) -> void:
	crumb("cut " + id + " " + _mem_line())
	Engine.time_scale = 1.0
	slow_on = false
	hud.visible = false
	_in_cut = true
	# the street's drawings go first and the page opens a few frames later, on black (the page fades
	# in from black anyway): the phone never holds a whole street and a comic page at once. A page
	# killed at the start of a cutscene (crash report 9, the Teague page) had both.
	var black := CanvasLayer.new()
	black.layer = 90
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.add_child(rect)
	add_child(black)
	_stream_tick()
	for i in 3:
		await get_tree().process_frame
	black.queue_free()
	var c = CutsceneScript.new()
	c.scene_id = id
	c.done = then
	c.fast = test
	c.sound = func(n: String, db: float) -> void: sfx.play(n, db, INF, 0.0)
	c.audio = sfx
	if test:
		c.shot = _shot
	add_child(c)


## Under the painted title the street is not shown or heard: only the rain and the music play.
func _hide_world() -> void:
	_world_off = true
	_stream_tick()
	for n in get_children():
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	for l in sfx._loops:
		l["on"] = false
	set_physics_process(false)


func _start_map(c: int, m: int) -> void:
	chapter = c
	map = m
	checkpoint = -1.0
	checkpoint_y = 0.0
	_saved_cp()
	in_menu = false
	_travel(true)


## (audit 22. 11.) The checkpoint kept in the save for this map, if there is one (the page was closed mid-map).
func _saved_cp() -> void:
	var s := MenuScript.saved_cp()
	if _auto_arg() != "" or _url_sandbox >= 0 or String(s.get("map", "")) != "%d:%d" % [chapter, map] or not s.get("keep") is Dictionary:
		return
	checkpoint = float(s["x"])
	checkpoint_y = float(s["y"])
	_ground_cp = float(s.get("ground", -1.0))
	checkpoint_map = String(s["map"])
	_cp_keep = s["keep"]
	crumb("checkpoint from the save %s %d,%d" % [checkpoint_map, int(checkpoint), int(checkpoint_y)])


## Doors, checkpoints, the tutorial's hints, and the prologue's last stand.
func _map_events(delta: float) -> void:
	stats["time"] += delta
	var dry := 1.0 if _section_at(player.position) >= 0 else 0.0   # 1 indoors, falling off over the last steps to a door: the rain thins under the eaves, never cuts
	for v in _veils:
		var gap: float = maxf(maxf(float(v[0]) - player.position.x, player.position.x - float(v[1])), 0.0)
		(v[2] as Polygon2D).color.a = clampf((gap - 700.0) / 800.0, 0.0, 1.0)
		dry = maxf(dry, 1.0 - clampf(gap / 450.0, 0.0, 1.0))
	for rn in [atmo.rain_far, atmo.rain_near, atmo.splashes]:
		rn.modulate.a = 1.0 - dry
	_tick_rooms()
	var room := _room_at(player.position.x, player.position.y)
	if room != _room:   # through a door: a cut through black, no rain indoors
		var sec_door := room.begins_with("section_") or _room.begins_with("section_")
		_room = room
		# (user 17. 11.: "the smoke in the flat makes no sense") the street's steam stays out on the street
		for st in get_tree().get_nodes_in_group("street_steam"):
			(st as CanvasItem).visible = room == ""
		if _win_cut:
			_win_cut = false   # (out through the window: a hard cut, the street is simply there)
		elif not sec_door:   # into a building in cross-section there is no cut: its storeys open up round him
			hud.flash(1.0, 0.5)   # through a doorway: a dip through full black, the other side comes up out of it
		pass
		if atmo.splashes:
			atmo.splashes.visible = room == ""
	if not roof.is_empty() and player.position.y < float(roof["y"]) + 60.0 and not over and move_state == "ground":
		for cx in roof["checks"]:   # along the roof he goes the other way: these are passed going left
			if player.position.x < float(cx) and (checkpoint_y >= 0.0 or float(cx) < checkpoint):
				if checkpoint_y >= 0.0:
					_ground_cp = checkpoint   # where he would come back if he ends up down in the street again
				_take_checkpoint(float(cx), float(roof["y"]), not _win_landing)   # (no toast over a stunt in mid air: Gemini review 17. 11.)
	var cps: Array = level["checkpoints"]
	while _check_i < cps.size() and player.position.x > float(cps[_check_i]) and checkpoint_y >= 0.0:
		if float(cps[_check_i]) > checkpoint and not over and checkpoint_y >= 0.0:
			_take_checkpoint(float(cps[_check_i]), 0.0, not _win_landing)   # (no toast over a stunt in mid air)
		_check_i += 1
	var hints: Array = level["hints"]
	while _hint_i < hints.size() and player.position.x > float(hints[_hint_i][0]):
		if _auto == "" or _auto == "play" or _auto == "hint":
			hud.hint(String(hints[_hint_i][1]))
		_hint_i += 1
	var stand_x := float(level["stand"])
	if stand_x > 0.0 and not _stand and player.position.x > stand_x:
		_stand = true   # the dead end: they come from both sides, more and more, until Eddie falls
		_stand_t = 0.0
		if _auto == "play":
			print("BOT REACHED THE LAST STAND in ", int(_at), " s")
			get_tree().quit()
	if _stand and not over:
		_stand_t += delta
		# Nothing unseen holds him. Behind him is the dead end's chained gate (in the drawing); in front, the
		# mouth of the alley fills with Vail's men, and a man cannot walk through a line of men. They only
		# come from that side: over a chained gate nobody comes.
		if STAND_GATE_X == 0.0:
			STAND_GATE_X = _stand_gate_x()
		var gate := STAND_GATE_X - 30.0
		var line := stand_x - 1100.0
		for e in enemies:
			if e["alive"] and e["node"].position.x < player.position.x and e["node"].position.y > -50.0:
				line = maxf(line, float(e["node"].position.x) + 150.0)
		var was: float = player.position.x
		player.position.x = clampf(player.position.x, minf(line, gate - 300.0), gate)
		_stand_prev = player.position.x
		if _move_dir > 0.2 and was >= gate - 2.0 and _stand_t - _gate_said > 6.0:   # pushing on the gate: the chain rattles
			_gate_said = _stand_t
			sfx.play("chain", -2.0, player.position.x)
			_say(player, "CHAINED.")
		elif _move_dir < -0.2 and was <= minf(line, gate - 300.0) + 2.0 and _stand_t - _line_said > 6.0:   # he walked into them
			_line_said = _stand_t
			_say(player, "NOT THAT WAY.")
		slow_left = maxf(0.0, slow_left - delta * (0.03 + _stand_t * 0.004))
		_stand_spawn -= delta
		var alive := 0
		for e in enemies:
			alive += 1 if e["alive"] else 0
		if _stand_t < 0.1 and not _stand_opened:   # the trap shuts: a line of them walks into the alley mouth
			_stand_opened = true
			for k in 4:
				_spawn_runner(player.position.x - 1900.0 - k * 160.0, player.position.x - 620.0 - k * 150.0, "post")
			_say(player, "DEAD END.")
			sfx.play("chain", -4.0, STAND_GATE_X)
		if _stand_spawn <= 0.0 and alive < 7:
			_stand_spawn = maxf(0.6, 1.8 - _stand_t * 0.04)
			_spawn_runner(player.position.x - 1900.0 - randf() * 300.0, player.position.x - randf_range(500.0, 900.0), "tommy" if randf() < _stand_t / 60.0 else "post")
		if _stand_t > 55.0 and hp > 0:   # nobody walks out of this alley
			hp = 1


## Score card: one star for finishing, one for taking two hits at most, one for style (head shots and
## slowed-time kills). Frank's stars are his leads: his experience and what pins his instincts.
func _rate() -> void:
	var kills: int = int(stats["kills"]) - int(stats["executed"])
	var score: int = stats["score"]
	var lvl0 := Instincts.level()
	if _auto == "" or _auto == "tally":
		Instincts.add_xp(_xp_run)
	var x := Instincts.xp() + (_xp_run if _auto != "" else 0)
	var lvl := Instincts.level_at(x)
	var stars := 1 + (1 if score >= maxf(100.0, kills * 100.0) * STAR_2 else 0) + (1 if score >= maxf(100.0, kills * 100.0) * STAR_3 else 0)
	MenuScript.mark_stars(chapter, map, stars)   # kept for the case file's history; nothing is bought with them now
	var t := int(stats["time"])
	var head := String(Levels.CAMPAIGN[chapter]["title"]) + " CLOSED" if map + 1 >= (Levels.CAMPAIGN[chapter]["maps"] as Array).size() else String(level["name"]).to_upper()
	if _auto != "":
		print("SCORE ", score, " xp ", _xp_run, " level ", lvl, " combo ", stats["best_combo"])
	var nxt := Instincts.xp_for(lvl + 1)
	var lv_line := "LEVEL %d   %d / %d XP" % [lvl, x, nxt]
	if lvl > lvl0 and _auto == "":
		lv_line = "LEVEL UP: %d   A POINT TO SPEND" % lvl
	hud.rating(lv_line, head, score, [["BEST COMBO", "X%d" % stats["best_combo"]], ["IN THE AIR", stats["air"]],
		["HEAD SHOTS", stats["heads"]], ["SLOWED TIME", stats["slow"]], ["HITS TAKEN", stats["hits"]], ["TIME", "%d:%02d" % [t / 60, t % 60]]])
	hud.conscience(stats["let_go"], stats["shot_up"])


func _restart() -> void:
	Engine.time_scale = 1.0
	_retry = over and not in_menu   # back from death: no lingering, Hotline-Miami quick
	_travel(false)


## (audit 22. 11.) The game stops by itself when he cannot be watching: the tab hidden, the window left, the phone
## turned upright.
func _can_pause() -> bool:
	return not in_menu and _auto == "" and not over and not cleared and not _in_cut and not _card_up and not get_tree().paused \
			and player != null and hud != null


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT] and is_inside_tree() and _can_pause():
		_pause()


func _pause() -> void:
	hud.release_all()
	var p = PauseScript.new()
	p.title = "%s\n%s" % [String(Levels.CAMPAIGN[chapter]["title"]), String(level["name"])]
	p.sound = func(n: String) -> void: sfx.play(n, -4.0, INF, 0.1)
	hud.modal(true)
	p.on_close = func() -> void:
		_unpaused_frame = Engine.get_process_frames()
		hud.modal(false)
		hud.release_all()
		_shake_on = bool(MenuScript.setting("shake"))
		_assist = bool(MenuScript.setting("assist"))
	p.on_restart = _restart
	p.on_quit = func() -> void:
		hud.modal(false)
		Engine.time_scale = 1.0
		in_menu = true
		_travel(false)
	add_child(p)


## To the next map (or back to it, or to the title): through black, with the map's title card when
## `card`, so the screen is never a bare grey while it loads. The new map lifts the card.
func _travel(card: bool) -> void:
	crumb("travel to %d:%d menu=%s %s" % [chapter, map, in_menu, _mem_line()])
	var l = LoadingScript.new()
	l.quick = _retry
	l.chapter = chapter
	l.map = map
	l.to_menu = in_menu or not card
	l.then = func() -> void:
		_card_up = true
		# The card covers the screen: let go of this map's drawings first and give the browser a few
		# frames to hand the memory back, so the old map and the new one are never held at once
		# (on a phone that peak was enough for the browser to kill the page and load it again).
		set_process(false)
		set_physics_process(false)
		for n in get_children():
			n.queue_free()
		_stream.clear()
		load("res://paper.gd").forget()
		for k in 4:
			await get_tree().process_frame
		if _auto == "hops":
			print("  between maps: textures %d MB" % (int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576))
		crumb("reload scene " + _mem_line())
		get_tree().reload_current_scene()
	get_tree().root.add_child(l)


## A figure shot dead, pushed by the bullet towards `push` (-1 / 1). Two ways down: blown off his feet
## onto his back with the arms flung up, or (crouched, or one time in three) the knees give, the gun
## drops and he folds forward onto his face. He hits the pavement with a small bounce, a pool of
## blood spreads under him, and a mobster then fades away; the detective stays down.
## The fall follows the hit. how: "head" (snapped back, arms flung, straight down backwards),
## "leg" (the knee goes, he kneels a beat, then folds forward), "blast" (thrown up and over),
## anything else: a stagger and a fall, or a crumple where he stands.
func _drop(figure, push: float, fade: bool, how := "") -> void:
	figure.set_shadow(0.0, 0.0, 0.0)
	# whatever he was doing ends here: no dive, slide, tumble, reload or raised hands left in the body,
	# or the fall would bend limbs the wrong way
	for k in ["air", "dive", "crouch", "slide", "roll", "reload", "recoil", "hands_up", "_flinch", "_hit_dip"]:
		figure.set(k, 0.0)
	var facing: float = figure.scale.x
	var crumple: bool = how == "leg" or (how == "" and (figure.duck > 0.5 or randf() < 0.34))
	var at: Vector2 = figure.position
	var arm0: float = clampf(figure._aim.angle(), -1.4, 1.4)
	var knees0: float = figure.duck
	var side: float = facing if crumple else push   # which way the head goes down
	if how == "leg":
		side = -push   # forward, towards the one who shot him
	var lie := PI * 0.5 * side
	# where he ends up: thrown that far along whatever he stands on, never through a crate or wall,
	# and lying on the surface that is really under him there (off a crate's edge he falls to the street)
	var throw: float = {"blast": 210.0, "head": 200.0, "leg": -60.0}.get(how, 30.0 if crumple else 170.0) * push
	var land := _land_point(at, throw)
	for bi in boxes.size():   # his head must not end up inside a crate either: he lies short of it
		var b: Rect2 = boxes[bi]
		if box_info[bi]["kind"] != "car" and b.position.y < land.y - 30.0:
			var head_x: float = land.x + side * 440.0
			if (b.position.x - land.x) * side > 0.0 and minf(b.position.x, b.end.x) < maxf(land.x, head_x) and maxf(b.position.x, b.end.x) > minf(land.x, head_x):
				var edge: float = b.position.x if side > 0.0 else b.end.x
				land.x = edge - side * 455.0
				land.y = _floor_at(land.x, land.y + 4.0)
	var curl := false
	# the whole body has to lie on something: feet, hips and head on the same surface, not hanging
	# off the end of a landing in the air. Shift back onto it, turn the other way, or go over the edge.
	if not _body_fits(land, side):
		var found := false
		for k in range(1, 30):
			for sgn in [-1.0, 1.0]:
				var x2: float = land.x + sgn * side * k * 20.0
				if not found and _body_fits(Vector2(x2, land.y), side):
					land.x = x2
					found = true
		if not found and _body_fits(land, -side):
			side = -side
			lie = -lie
			found = true
		if not found:   # too narrow to lie on: over an edge to what is below, or slumped against what stopped him
			var over_x: float = land.x + side * 220.0
			var below: float = _floor_at(over_x, land.y + 4.0)
			if below > land.y + 40.0 and _body_fits(Vector2(over_x, below), side):
				land = Vector2(over_x, below)
			else:   # curled up short, knees drawn in, in the gap that there is
				curl = true
				var best_x: float = land.x
				var done := false
				for k in range(0, 30):
					for sgn in [-1.0, 1.0]:
						for sd in [side, -side]:
							var x3: float = land.x + sgn * k * 20.0
							if not done and _body_fits(Vector2(x3, land.y), sd, 300.0):
								best_x = x3
								side = sd
								done = true
				land.x = best_x
				lie = PI * 0.5 * side
	var rest := Vector2(land.x, land.y - 26.0)
	# how the dead arms lie: along the body, over the head or down by the side, and tipped to the open
	# side, never down through the pavement. Face down when he falls the way he faces.
	var face_down: bool = facing * side > 0.0
	var over_head: float = -PI * 0.5 + (-0.12 if face_down else 0.12)
	var by_side: float = PI * 0.5 + (0.12 if face_down else -0.12)
	figure.dead_far = -0.25 if face_down else 0.25
	var mid := Vector2(lerpf(at.x, land.x, 0.45), minf(at.y, land.y))
	var tw := create_tween()
	# the arms only ever swing the short way round, through open air in front of him or over his head
	if how == "blast":
		tw.tween_method(func(k: float) -> void: figure.die_pose(lerpf(arm0, -2.2, k), 0.5 * k), 0.0, 1.0, 0.2)
		tw.parallel().tween_property(figure, "rotation", lie, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(figure, "position:x", rest.x, 0.55).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_method(func(k: float) -> void: figure.position.y = lerpf(at.y, rest.y, k) - sin(k * PI) * 150.0, 0.0, 1.0, 0.55)
		tw.parallel().tween_method(func(k: float) -> void: figure.die_pose(lerpf(-2.2, over_head, k), lerpf(0.5, 0.0, k)), 0.0, 1.0, 0.55).set_delay(0.2)
	elif how == "head":
		tw.tween_method(func(k: float) -> void: figure.die_pose(lerpf(arm0, -2.2, k), 0.0), 0.0, 1.0, 0.09).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(figure, "rotation", 0.35 * side, 0.09).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(figure, "position", mid, 0.09).set_ease(Tween.EASE_OUT)
		tw.tween_property(figure, "rotation", lie, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(figure, "position", rest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(func(k: float) -> void: figure.die_pose(lerpf(-2.2, over_head, k), 0.0), 0.0, 1.0, 0.28)
	elif how == "leg":
		tw.tween_method(func(k: float) -> void: figure.die_pose(lerpf(arm0, 0.9, k), lerpf(knees0, 1.0, k)), 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(figure, "rotation", 0.15 * side, 0.18)
		tw.tween_interval(0.28)   # down on one knee, a beat
		tw.tween_property(figure, "rotation", lie, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(figure, "position", rest, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(func(k: float) -> void: figure.die_pose(lerpf(0.9, by_side, k), lerpf(1.0, 0.0 if face_down else 0.2, k)), 0.0, 1.0, 0.4)
	elif crumple:
		tw.tween_property(figure, "rotation", -0.1 * side, 0.1)
		tw.parallel().tween_method(func(k: float) -> void: figure.die_pose(lerpf(arm0, 1.2, k), lerpf(knees0, 1.0, k)), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(figure, "rotation", lie, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(figure, "position", rest, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(func(k: float) -> void: figure.die_pose(lerpf(1.2, by_side, k), lerpf(1.0, 0.0 if face_down else 0.15, k)), 0.0, 1.0, 0.34)   # the legs go out straight as he lands
	else:
		tw.tween_method(func(k: float) -> void: figure.die_pose(lerpf(arm0, -1.75, k), lerpf(knees0, 0.25, k)), 0.0, 1.0, 0.14).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(figure, "rotation", 0.18 * side, 0.14).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(figure, "position", mid, 0.14).set_ease(Tween.EASE_OUT)
		tw.tween_property(figure, "rotation", lie, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(figure, "position", rest, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_method(func(k: float) -> void: figure.die_pose(lerpf(-1.75, over_head, k), lerpf(0.25, 0.0, k)), 0.0, 1.0, 0.36)
	if curl:   # in a tight spot he ends curled on his side, knees drawn up, inside the gap
		tw.tween_method(func(k: float) -> void: figure.die_pose(figure._aim.angle(), 0.75 * k), 0.0, 1.0, 0.18)
	# the bounce off the pavement
	tw.tween_property(figure, "rotation", lie - 0.13 * side, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(figure, "rotation", lie, 0.1).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _pool(Vector2(figure.position.x + side * 230.0, land.y), side))
	tw.parallel().tween_callback(func() -> void: sfx.play("body_fall", 0.0 if figure == player else -3.0, figure.position.x))
	if fade:
		tw.tween_interval(3.0)
		tw.tween_property(figure, "modulate:a", 0.0, 0.9)


## Where a body thrown `dist` along from `at` comes to rest: it slides along the surface under it,
## stops against anything that stands up in the way, drops off an edge onto what is below.
func _land_point(at: Vector2, dist: float) -> Vector2:
	var surf := _floor_at(at.x, at.y + 4.0)
	var x := at.x
	var step := signf(dist) * 15.0
	for i in int(absf(dist) / 15.0):
		var nx := x + step
		var wall := false
		for bi in boxes.size():
			if box_info[bi]["kind"] == "car":
				continue
			var b: Rect2 = boxes[bi]
			if nx > b.position.x - 40.0 and nx < b.end.x + 40.0 and b.position.y < surf - 30.0:
				wall = true   # a crate taller than where he lies: he stops against it
		if wall or (_room_at(nx) != _room_at(at.x)):
			break
		x = nx
		surf = _floor_at(x, surf + 4.0)
	return Vector2(x, surf)


func _body_fits(at: Vector2, side: float, length := 440.0) -> bool:
	for t in [0.0, 0.3, 0.6, 0.95]:
		if absf(_floor_at(at.x + side * length * t, at.y + 4.0) - at.y) > 6.0:
			return false
	for bi in boxes.size():
		var b: Rect2 = boxes[bi]
		if box_info[bi]["kind"] != "car" and b.position.y < at.y - 30.0 and minf(at.x, at.x + side * length) < b.end.x + 10.0 and maxf(at.x, at.x + side * length) > b.position.x - 10.0:
			return false
	return true


## Blood spreading on the pavement under a body: dark, flat, slow.
func _pool(at: Vector2, side: float) -> void:
	var tex: Texture2D = load("res://art/fx/blood2.png")
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at + Vector2(0.0, -14.0)
	s.z_index = -1   # on the street, under the body
	s.modulate = Color(0.32, 0.05, 0.04, 0.95) * Color(_undo_night(0.6), 1.0)
	s.scale = Vector2(0.05, 0.012)
	s.flip_h = side < 0.0
	add_child(s)
	var w := 300.0 / tex.get_width()
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(w, w * 0.16), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.9)
	tw.tween_callback(s.queue_free)


## Buildings in cross-section (2026-11-16, plan in the story doc, tab "Řez domem a kamera"): the front
## wall cut away, the storeys stacked. From the street the facade is all there is; through the door
## the storeys open up (they fade in round him) and stay open while he is inside, and the camera holds
## the storey he stands on. The storeys' drawings are the kit in art/section/<style>_*.png (gen/QUEUE_doma.md
## §5); until it exists the tenement room drawing stands in, so the system can be played.
func _section_kit() -> bool:
	return ResourceLoader.exists("res://art/section/tenement_hall_a.png")


## The tenement kit (gen/section_art.py, art_src 212-219): each piece one storey, SEC_KIT_ROWS rows, the boards
## walked on at SEC_KIT_WALK; two pieces side by side make a storey of the building. The layout is the
## generator's (gen/levels.py section: the stairs openings and the ladder are where these pieces paint them).
## A brick end wall caps each storey that has none of its own (the end piece's wall, mirrored on the right).
const SEC_KIT_ROWS := 1112.0
const SEC_KIT_WALK := 1097.0
const SEC_KIT_W := 3168.0
const SEC_KIT_X0 := 510.0      # from the first piece's left edge to the building's x0: the street door in the facade
const SEC_SIDE_OUT := 158.0     # tenement_side.png (gen/section_side.py): its outer face, its pixels from the outside
const SEC_KIT_WALL := Vector2(167.0, 680.0)   # the end piece's brick wall: outer face, inner face (its pixels)
const SEC_KIT_LAYOUT := [      # per storey: the two pieces, then the end walls it needs
	["tenement_entry", "tenement_stairs_a", "", "R"],
	["tenement_stairs_b", "tenement_stairs_a", "L", "R"],
	["tenement_stairs_b", "tenement_flat", "L", ""]]   # (the flat has its own outer wall and window)
const SEC_KIT_STUNT := [["tenement_entry", "tenement_flat", "", ""]]   # SANDBOX STUNTS: one storey, the flat by the door
func _build_section_kit(x0: float, x1: float, storeys: int, holder: Node2D, style := "tenement") -> void:
	# (21. 11.) another house on the same frame: "rooming" (BACK STREETS, gen/rooming_art.py) - each of its pieces where
	# it has one (the end wall and the fire escape are the tenement's)
	if style == "works":
		_build_works(x0, x1, storeys, holder)
		return
	var kit := "rooming" if style.begins_with("rooming") else "tenement"
	var own := func(n: String) -> String:
		var k := n.replace("tenement_", kit + "_")
		return k if ResourceLoader.exists("res://art/section/%s.png" % k) else n
	var s := section_h / SEC_KIT_ROWS
	var start := x0 - SEC_KIT_X0
	var city := not _city_house(x0).is_empty()   # (22. 11.) among the city's fronts: whole outer walls, the alley past them
	var facade := Node2D.new()   # the front seen from the street: under the storeys, which open over it from the door
	facade.z_index = -6
	add_child(facade)
	for k in storeys:
		var layout: Array = SEC_KIT_STUNT if style == "tenement_stunt" else SEC_KIT_LAYOUT
		var lay: Array = layout[mini(k, layout.size() - 1)]
		var top := -section_h * k - SEC_KIT_WALK * s
		var storey := Node2D.new()
		storey.modulate = Color(ROOM_BASE, ROOM_BASE, ROOM_BASE, 1.0)
		holder.add_child(storey)
		for i in 2:
			var pn := String(lay[i])
			if city and pn == "tenement_entry" and kit == "tenement":
				pn = "tenement_entry_city"   # (gen/section_side.py) no side door onto a painted street: the street door is the front's
			var reg := Rect2(0.0, 0.0, SEC_KIT_W, SEC_KIT_ROWS)
			if city and i == 0 and String(lay[2]) == "L":
				reg = Rect2(SEC_SIDE_OUT, 0.0, SEC_KIT_W - SEC_SIDE_OUT, SEC_KIT_ROWS)   # nothing of the hallway out past its wall
			elif city and i == 1 and String(lay[3]) == "R":
				reg = Rect2(0.0, 0.0, SEC_KIT_W - SEC_SIDE_OUT, SEC_KIT_ROWS)
			var piece := _kit_piece(own.call(pn), reg, Vector2(start + (i * SEC_KIT_W + reg.position.x) * s, top), s, false)
			storey.add_child(piece)
			if String(lay[i]) == "tenement_flat":   # its window bursts: swapped for the drawing with the empty hole
				_flat_art.append([-section_h * k, piece, kit])
				if kit == "tenement":   # (22. 11.) the wall with its door turned the way the window wall is
					var ptex: Texture2D = BigTex.get_tex("res://art/section/tenement_partition.png")
					storey.add_child(_kit_piece("tenement_partition", Rect2(0.0, 0.0, ptex.get_width(), SEC_KIT_ROWS), Vector2(start + (i * SEC_KIT_W + PARTITION_X) * s, top), s, false))
			var front := "tenement_facade_ground" if k == 0 and i == 0 else "tenement_facade"
			if not _city_house(x0).is_empty():
				continue   # (rule 31) its front comes from the modular city's sheet (below)
			facade.add_child(_kit_piece(own.call(front), Rect2(0.0, 0.0, SEC_KIT_W, SEC_KIT_ROWS), Vector2(start + i * SEC_KIT_W * s, top), s, false))
		var cap := Rect2(0.0, 0.0, SEC_KIT_WALL.y, SEC_KIT_ROWS)
		var end := "tenement_side" if city else "tenement_end"   # (a whole wall, not a broken one over a grey void)
		if String(lay[2]) == "L":
			storey.add_child(_kit_piece(end, cap, Vector2(start, top), s, false))
		if String(lay[3]) == "R":
			storey.add_child(_kit_piece(end, cap, Vector2(start + 2.0 * SEC_KIT_W * s - SEC_KIT_WALL.y * s, top), s, true))
	var hf := _city_house(x0)
	if not hf.is_empty():
		_city_front(String(hf[1]), float(hf[2]), float(hf[3]), int(hf[4]), int(hf[5]), facade, 0)


## (QUEUE §22) A works in cross-section: one open hall the height of its front (art_src 354 drawn on gen/works_template.py's
## layout, 3000 x 2464 world px from the pavement up), its front from the modular city's sheet over it.
const WORKS_H := 2464.0
const WORKS_TONE := 0.74       # (the drawing is paler than the kit's storeys)
const WORKS_DOOR := 1800.0     # its street door in the stone front (the middle bay's door): the only way out of the hall
var _works_out := true         # on its ground floor's x: out on the pavement in front (true) or in the hall (false)
var _works_boxes_out := false  # (the hall's floor crates moved away while he is on the pavement in front)
const WORKS_AWAY := 100000.0
var _works_px := 0.0           # (where he was the frame before: the door is crossed, not stood on)
func _build_works(x0: float, x1: float, storeys: int, holder: Node2D) -> void:
	var facade := Node2D.new()
	facade.z_index = -6
	add_child(facade)
	var storey := Node2D.new()   # (one "storey": the hall is lit all through)
	storey.modulate = Color(ROOM_BASE, ROOM_BASE, ROOM_BASE, 1.0)
	holder.add_child(storey)
	var tex: Texture2D = BigTex.get_tex("res://art/section/works_hall.png")
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.scale = Vector2((x1 - x0) / tex.get_width(), WORKS_H / tex.get_height())
	sp.position = Vector2(x0, -WORKS_H)
	sp.light_mask = 0
	sp.modulate = Color(WORKS_TONE, WORKS_TONE, WORKS_TONE, 1.0)
	storey.add_child(sp)
	var s := section_h / SEC_KIT_ROWS   # its end walls: whole brick walls cut through, storey by storey (gen/section_side.py)
	var cap := Rect2(0.0, 0.0, SEC_KIT_WALL.y, SEC_KIT_ROWS)
	for k in storeys:
		var top := -section_h * k - SEC_KIT_WALK * s
		storey.add_child(_kit_piece("tenement_side", cap, Vector2(x0 - SEC_SIDE_OUT * s, top), s, false))
		storey.add_child(_kit_piece("tenement_side", cap, Vector2(x1 - (SEC_KIT_WALL.y - SEC_SIDE_OUT) * s, top), s, true))
	var hf := _city_house(x0)
	if not hf.is_empty():
		_city_front(String(hf[1]), float(hf[2]), float(hf[3]), int(hf[4]), int(hf[5]), facade, 0)


func _works(i: int) -> bool:
	return i >= 0 and i < sections.size() and String((sections[i] as Array)[3]) == "works"


## (QUEUE §22, user 22. 11.) Off the washing line through the works' front window: the glass goes in with him, the front
## opens from the window, he lands rolling on the low gallery and time slows round the men in the hall.
const WORKS_CRASH_SLOW := 2.6
func _crash_into_works(i: int, pul: Vector2) -> void:
	var win := Rect2(pul.x + 10.0, -CITY_FOOT - CITY_STOREY - 150.0 - 440.0, 300.0, 440.0)   # the window the pulley is on (CITY_WIN)
	var mid := win.get_center()
	var art: Dictionary = _sec_art[i]
	(art["ink"] as ShaderMaterial).set_shader_parameter("origin", mid)
	player.position = Vector2(mid.x + 60.0, -section_h - 30.0)
	_ground_y = -section_h
	move_state = "dive"
	player.dive = 1.0
	player.dive_side = 1.0
	dive_rolls = true
	_kicked_this_dive = true
	glide = 560.0
	run = 0.0
	fall = -160.0
	_cam_snap = true
	fx.burst_window(win, Vector2(520.0, 120.0), -section_h, Vector2(float((sections[i] as Array)[0]), float((sections[i] as Array)[0]) + 1400.0), 0.0)
	fx.shatter(mid)
	_impact(0.07, 0.05)
	_word(["crash", "smash"], mid + Vector2(150.0, -170.0), 0.26, Vector2.RIGHT)
	sfx.play("glass", 3.0, mid.x, 0.05)
	_free_slow = maxf(_free_slow, WORKS_CRASH_SLOW)
	_grace = maxf(_grace, 0.8)
	for e in enemies:   # the crash is heard all over the hall
		if e["alive"] and _section_at(e["node"].position) == i:
			e["seen"] = true


func _kit_piece(name: String, region: Rect2, at: Vector2, s: float, flip: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = BigTex.get_tex("res://art/section/" + name + ".png")
	sp.centered = false
	sp.region_enabled = true
	sp.region_rect = region
	sp.scale = Vector2.ONE * s
	sp.flip_h = flip
	sp.position = at
	sp.light_mask = 0
	return sp


## (rule 31, QUEUE §21) The modular city in front: every front cut from a module sheet (gen/modules.py: Gemini's facade on
## gen/module_template.py's grid, 3 bays x cornice + 3 storeys = CITY_SHEET world px) - the left bay with its outer corner,
## the middle bay repeated, the right bay with its corner; the cornice, the storeys under it (the sheet's two alternating),
## the ground floor. Alleys between fronts (their own drawing) and a house's side-wall fire escape (art_src 346).
const CITY_SHEET := Vector2(3000.0, 2400.0)
const CITY_CORNICE := 300.0
const CITY_STOREY := 700.0
const CITY_FOOT := 64.0                      # a front's foot: the back of the pavement (WALL_LIFT + 4)
const CITY_ESC_H := 1436.4                   # the side-on fire escape's drawing in world px (2528 px at 0.5682)
const CITY_ESC_DECK := 1756.0 / 2528.0       # its lower deck's row, a fraction of the drawing's height
const CITY_TONE := 0.86                      # the fronts under the night grade (the street drawings' moonlit wash)
func _build_city() -> void:
	for cy in level.get("city", []):
		var kind := String(cy[0])
		var x := float(cy[2])
		if kind == "bldg":
			_city_front(String(cy[1]), x, float(cy[3]), int(cy[4]), int(cy[5]), self, -6)
			_city_alcoves(String(cy[1]), x, float(cy[3]), int(cy[4]))
		elif kind == "gap":   # the alley between two fronts: its sky keyed out, the city's sky behind
			var tex: Texture2D = BigTex.get_tex("res://art/city/%s.png" % String(cy[1]))
			var k := float(cy[3]) / tex.get_width()
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.scale = Vector2(k, k)
			sp.position = Vector2(x, -CITY_FOOT - tex.get_height() * k)
			sp.z_index = -7
			sp.light_mask = 0
			sp.modulate = Color(CITY_TONE, CITY_TONE, CITY_TONE, 1.0)
			add_child(sp)
		elif kind == "escape":   # bolted to the house's side wall, seen edge-on: its landings stand out over the alley
			var tex: Texture2D = BigTex.get_tex("res://art/city/%s.png" % String(cy[1]))
			var k := CITY_ESC_H / tex.get_height()
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.scale = Vector2(k, k)
			sp.position = Vector2(x, float(cy[3]) + CITY_STOREY - CITY_ESC_H * CITY_ESC_DECK)
			sp.z_index = -2
			sp.light_mask = 0
			sp.modulate = Color(0.66, 0.66, 0.7, 1.0)   # (the drawing's iron is pale: down to the street's ink)
			add_child(sp)


## (rule 33, user 23. 11. "C": depth at points) The street doors drawn in a front's ground floor, which he can go in
## at: per module sheet the bay its door is in (0 the left one, 1 the middle ones), its middle in the bay, its width,
## the top of its opening and its threshold (sheet units, the ground row 0..700 from its top; measured on the sheets).
## User 23. 11.: standing on the pavement in front of the steps he was "unseen" - nonsense. He goes up onto the
## threshold, the door opens inward onto a dark hall, he stands IN the dark opening: only then is he hard to see.
const CITY_DOORS := {"brick": [0, 0.5, 275.0, 102.0, 598.0], "pale": [0, 0.5, 275.0, 80.0, 598.0],
		"walkup": [1, 0.796, 232.0, 233.0, 694.0], "stone": [1, 0.81, 207.0, 233.0, 685.0]}
var _alcoves: Array = []          # every doorway: {"x", "w", "top", "sill" (world y of the threshold), "dark" (its opening)}
func _city_alcoves(style: String, x0: float, w: float, bays: int) -> void:
	if not CITY_DOORS.has(style):
		return
	var d: Array = CITY_DOORS[style]
	var n := maxi(bays, 2)
	var bw := w / float(n)
	var sx := bw / 1000.0
	var row := -CITY_FOOT - CITY_STOREY
	var xs: Array = [x0 + bw * float(d[1])] if int(d[0]) == 0 else range(1, n - 1).map(func(j: int) -> float: return x0 + bw * (j + float(d[1])))
	for x in xs:
		var dw := float(d[2]) * sx
		var top := row + float(d[3])
		var sill := row + float(d[4])
		var dark := Polygon2D.new()   # the door swung in: the hall behind it, dark, a little light from the street on its floor
		dark.polygon = PackedVector2Array([Vector2(x - dw * 0.42, top + 14.0), Vector2(x + dw * 0.42, top + 14.0), Vector2(x + dw * 0.42, sill), Vector2(x - dw * 0.42, sill)])
		dark.vertex_colors = PackedColorArray([Color(0.02, 0.02, 0.025), Color(0.02, 0.02, 0.025), Color(0.09, 0.09, 0.1), Color(0.09, 0.09, 0.1)])
		dark.z_index = -5
		dark.visible = false
		add_child(dark)
		_alcoves.append({"x": float(x), "w": dw, "top": top, "sill": sill, "dark": dark})


## The modular city's front laid for the house in cross-section at x0 (its "house" entry), or [].
func _city_house(x0: float) -> Array:
	for cy in level.get("city", []):
		if String(cy[0]) == "house" and float(cy[2]) <= x0 and float(cy[2]) + float(cy[3]) > x0:
			return cy
	return []


## One front: `bays` bays across `w` world px from x0, `storeys` storeys and the cornice over them, its foot at CITY_FOOT.
func _city_front(style: String, x0: float, w: float, bays: int, storeys: int, parent: Node, z: int) -> void:
	var tex: Texture2D = BigTex.get_tex("res://art/city/%s.png" % style)
	var kx := tex.get_width() / CITY_SHEET.x
	var ky := tex.get_height() / CITY_SHEET.y
	var bay := CITY_SHEET.x / 3.0
	var bw := w / float(maxi(bays, 2))
	var rows: Array = [[0.0, CITY_CORNICE]]   # [the sheet's y, height]: the cornice, the storeys from the top, the ground floor
	for s in storeys - 1:
		rows.append([CITY_CORNICE + (s % 2) * CITY_STOREY, CITY_STOREY])
	rows.append([CITY_CORNICE + 2.0 * CITY_STOREY, CITY_STOREY])
	var y := -CITY_FOOT - (storeys * CITY_STOREY + CITY_CORNICE)
	for row in rows:
		for j in maxi(bays, 2):
			var col: float = 0.0 if j == 0 else (2.0 * bay if j == maxi(bays, 2) - 1 else bay)
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.centered = false
			sp.region_enabled = true
			sp.region_rect = Rect2(col * kx, float(row[0]) * ky, bay * kx, float(row[1]) * ky)
			sp.scale = Vector2(bw / (bay * kx), 1.0 / ky)
			sp.position = Vector2(x0 + j * bw, y)
			sp.z_index = z
			sp.light_mask = 0
			sp.modulate = Color(CITY_TONE, CITY_TONE, CITY_TONE, 1.0)
			parent.add_child(sp)
		y += float(row[1])


func _build_sections() -> void:
	sections = level.get("sections", [])
	section_h = float(level.get("section_h", 700.0))
	_xy_checks = level.get("xy_checks", [])
	_stairdoors = level.get("stairdoors", [])
	_build_flats()
	for sec in sections:
		var x0 := float(sec[0])
		var x1 := float(sec[1])
		var holder := Node2D.new()   # all its storeys: shown from inside only
		holder.z_index = -3
		holder.visible = false
		add_child(holder)
		var ink := ShaderMaterial.new()   # the facade dissolves from the door like ink in water (runs only while it does)
		ink.shader = _sec_ink_shader()
		ink.set_shader_parameter("origin", Vector2(x0 + 60.0, -210.0))
		ink.set_shader_parameter("radius", -400.0)
		if _section_kit():
			_build_section_kit(x0, x1, int(sec[2]), holder, String(sec[3]))
		for k in (0 if _section_kit() else int(sec[2])):
			var storey := Node2D.new()   # one hallway: its end walls only at its ends, never a wall with a window halfway along
			storey.modulate = Color(ROOM_BASE, ROOM_BASE, ROOM_BASE, 1.0)
			holder.add_child(storey)
			var tex: Texture2D = BigTex.get_tex("res://art/rooms/tenement.png")   # stand-in until the kit is drawn
			var sc := section_h / tex.get_height()
			var top_y := -section_h * k - section_h
			var span := (x1 - x0) / sc   # the hallway in the drawing's pixels
			# the stairs in the back wall are the drawing's own: just past the left end wall, and in its far end piece
			var has_left := false
			var has_right := false
			for d in _stairdoors:
				if absf(float(d[1]) + section_h * k) < 1.0:
					has_left = has_left or absf(float(d[0]) - (x0 + (SEC_STAND_STAIRS.x + SEC_STAND_STAIRS.y) * 0.5 * sc)) < 60.0
					has_right = has_right or absf(float(d[0]) - (x1 - (tex.get_width() - (SEC_STAND_STAIRS.x + SEC_STAND_STAIRS.y) * 0.5) * sc)) < 60.0
			var right_from: float = SEC_STAND_RIGHT if has_right else SEC_STAND_STAIRS.y   # no stairs on the top storey's far end
			var right_w := tex.get_width() - right_from
			var pieces: Array = [[0.0, SEC_STAND_LEFT, 0.0]]   # [from, to, at]: the left end wall
			var at := SEC_STAND_LEFT
			if has_left:
				pieces.append([SEC_STAND_STAIRS.x, SEC_STAND_STAIRS.y, at])
				at += SEC_STAND_STAIRS.y - SEC_STAND_STAIRS.x
			var n := 0
			while at < span - right_w:   # the middle: bare wall, and a door now and then (never the same door twice running)
				var core: Vector2 = SEC_STAND_CORE if n % 4 == 3 else SEC_STAND_WALL
				var w := minf(core.y - core.x, span - right_w - at + 20.0)
				pieces.append([core.x, core.x + w, at])
				at += core.y - core.x
				n += 1
			pieces.append([right_from, float(tex.get_width()), span - right_w])   # (the stairs,) 3C and the window: the far end
			for pc in pieces:
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.centered = false
				sp.region_enabled = true
				sp.region_rect = Rect2(float(pc[0]), 0.0, float(pc[1]) - float(pc[0]), tex.get_height())
				sp.scale = Vector2.ONE * sc
				sp.position = Vector2(x0 + float(pc[2]) * sc, top_y)
				sp.light_mask = 0
				storey.add_child(sp)
		# (user 22. 11.: "the black can't stay, the world I jump into should show") no veil on the houses either side and no
		# black sky behind them any more: from inside and off the fire escape the street round the house is seen as it is
		var reach := Vector2(x1 - x0, section_h * int(sec[2])).length() + 500.0
		_sec_art.append({"holder": holder, "lit": 0.0, "ink": ink, "open": 0.0, "reach": reach})


var _ink_shader: Shader
func _sec_ink_shader() -> Shader:
	if _ink_shader == null:
		_ink_shader = Shader.new()
		_ink_shader.code = """shader_type canvas_item;
uniform vec2 origin;
uniform float radius;
varying vec2 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float n = noise(world / 190.0) * 0.55 + noise(world / 47.0) * 0.3 + noise(world / 13.0) * 0.15;
	float edge = radius - distance(world, origin) + (n - 0.5) * 380.0;
	c.rgb *= mix(0.08, 1.0, smoothstep(0.0, 55.0, edge));   // a thin ink rim where it spreads
	c.a *= smoothstep(-6.0, 14.0, edge);
	COLOR = c;
}
"""
	return _ink_shader


## The stairs in the back wall (user's choice 16. 11.): a flight drawn side-on cannot zigzag, so the stairs are
## an opening in the hallway's back wall. Jump there: he goes in and up into the dark (0.55 s), the camera
## takes the storey (it follows _ground_y), and he comes out of the opening above. Nobody fires meanwhile.
const STAIRDOOR_IN := 0.55
const STAIRDOOR_FOOT := 60.0   # the stand-in flight: its foot this far right of the opening's middle, its top as far left
const STAIRDOOR_HOLD := 0.5
const STAIRDOOR_OUT := 0.45
## The flat at the end of the top storey (story doc: kick the door in, 1.2 s slowed for free; out of the window
## onto the fire escape). Two-state drawings from gen/section_art.py (art_src 221); the escape is art_src 222.
const ESC_K := 1.0526            # the fire escape drawing's pixels to the world (its landings fall on the storeys)
func _build_flats() -> void:
	_flats.clear()
	var ks := section_h / SEC_KIT_ROWS
	for fl in level.get("flats", []):
		var y := float(fl[1])
		var h := float(fl[2])
		# the door seen from the front, shut in the passage, its hinge on the painted post (FLAT_POST)
		var hinge := float(fl[0]) + FLAT_DOOR_HINGE
		var dtex: Texture2D = load("res://art/section/flat_door.png")
		var door := Polygon2D.new()   # a card in space: turned round its hinge, it narrows in perspective
		door.texture = dtex
		door.z_index = -2
		door.color = Color(ROOM_BASE, ROOM_BASE, ROOM_BASE, 1.0)
		door.visible = false
		add_child(door)
		var dw := h * dtex.get_width() / dtex.get_height()
		var wx0 := float(fl[3])
		var wx1 := float(fl[4])
		var glass := Node2D.new()   # (the glazed window is painted in the flat's drawing, art_src 227)
		add_child(glass)
		var turned := true   # (22. 11.) the tenement's partition is drawn turned like its window wall: the door shut in it likewise
		for sec in level.get("sections", []):
			if float(sec[0]) <= float(fl[0]) and float(fl[0]) <= float(sec[1]) and String(sec[3]).begins_with("rooming"):
				turned = false
		var yaw0 := FLAT_YAW0 if turned else 0.0
		_flats.append({"x": float(fl[0]), "hinge": hinge, "y": y, "h": h, "door": door, "dw": dw, "open": false,
				"yaw0": yaw0, "span": dw * cos(yaw0), "knob_free": turned, "vh": h * (0.95 if turned else 1.0), "eye": 5600.0 if turned else DOOR_EYE,
				"glass": glass, "gx": (wx0 + wx1) * 0.5, "wx0": wx0, "wx1": wx1, "sill": float(fl[5]), "lintel": float(fl[6]), "broken": false})
		var has_escape := false   # the fire escape on the side: only where the map has its decks (not on a ground-floor flat)
		for c in level["floors"]:
			if String(c[3]) == "fescape" and absf(float(c[1]) - y) < 10.0:
				has_escape = true
		if not has_escape or level.has("city"):
			continue
		var tex: Texture2D = BigTex.get_tex("res://art/section/tenement_escape.png")
		var to_roof := false   # a landing up at the roof he can get to (else its top flight led nowhere: user 22. 11.)
		for c in level["floors"]:
			if String(c[3]) == "fescape" and absf(float(c[1]) - (y - section_h)) < 10.0:
				to_roof = true
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2.ONE * ESC_K
		sp.position = Vector2(wx1, y - section_h)   # its top landing level with the roof
		sp.z_index = -2   # over the houses around
		sp.light_mask = 0
		sp.modulate = Color(ROOM_BASE, ROOM_BASE, ROOM_BASE, 1.0)
		# (user 22. 11.: "the wall ends at random, an ugly seam") the wall behind the iron goes soft into the street past the
		# landings' outer end, and above his landing when nothing up there is his to reach
		var fade := ShaderMaterial.new()
		fade.shader = _esc_fade_shader()
		fade.set_shader_parameter("right", Vector2(ESC_FADE_R.x, ESC_FADE_R.y) / float(tex.get_width()))
		fade.set_shader_parameter("top", (Vector2(ESC_FADE_TOP.x, ESC_FADE_TOP.y) if not to_roof else Vector2(-2.0, -1.0)) / float(tex.get_height()))
		sp.material = fade
		add_child(sp)
	for f in _flats:
		_door_card(f, float(f["yaw0"]), 0.0, Vector2.ZERO)


const ESC_PIER_HIDE := 330.0   # past the landings' end, the escape's back wall (still whole there) hides a street join
const ESC_FADE_R := Vector2(720.0, 950.0)     # the escape drawing's px: the wall behind it fades out from the landings' end
const ESC_FADE_TOP := Vector2(395.0, 470.0)   # and down to the top of the second-storey landing's railing (when no roof)
var _esc_shader: Shader
func _esc_fade_shader() -> Shader:
	if _esc_shader == null:
		_esc_shader = Shader.new()
		_esc_shader.code = """shader_type canvas_item;
uniform vec2 right;
uniform vec2 top;
void fragment() {
	COLOR.a *= (1.0 - smoothstep(right.x, right.y, UV.x)) * smoothstep(top.x, top.y, UV.y);   // (COLOR is already the texture's)
}
"""
	return _esc_shader


## The window as a card in the outer wall's plane: the sash's face turned WIN_YAW away from us round its inner
## edge (the wall is seen from the side), its foot on the sill.
const WIN_YAW := 1.22


## The door as a card in space: `yaw` round its hinge (radians, + swings its free edge away into the room),
## `pitch` falling flat (+ tips its top toward the viewer onto the floor), `shift` moves the hinge's foot.
## Projected with a mild perspective from the viewer, on a grid so the texture does not bend at the seam.
const DOOR_FLAT := 1.43     # lying on the boards: not quite edge-on, so it still reads as a door (a plank's thickness)
const DOOR_EYE := 2600.0   # how far the viewer stands from the cut (px): the perspective's strength
func _door_card(f: Dictionary, yaw: float, pitch: float, shift: Vector2) -> void:
	var poly: Polygon2D = f["door"]
	var w := float(f["dw"])
	var h := float(f.get("vh", f["h"]))
	var eye := float(f.get("eye", DOOR_EYE))
	var foot := Vector2(float(f["hinge"]), float(f["y"])) + shift
	var tex := poly.texture
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var nx := 4
	var ny := 8
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			# the door's own space: hinge edge at x 0, the free edge at -w, the foot at y 0, the top at -h
			var x := -w * (1.0 - u)
			var y := -h * (1.0 - v)
			var z := 0.0
			var y2 := y * cos(pitch)
			var z2 := -y * sin(pitch)        # falling: the top comes out of the picture toward the viewer
			var x3 := x * cos(yaw)
			var z3 := z2 + x * sin(yaw)       # turning: the free edge goes back into the room
			var k := eye / (eye - z3)
			pts.append(foot + Vector2(x3 * k, y2 * k))
			var uu := 1.0 - u if bool(f.get("knob_free", false)) else u   # (23. 11.) the knob on the free edge, the hinges on the hinge's
			uvs.append(Vector2(uu * tex.get_width(), v * tex.get_height()))
	var polys := []
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			polys.append(PackedInt32Array([a, a + 1, a + nx + 2, a + nx + 1]))
	poly.polygon = pts
	poly.uv = uvs
	poly.polygons = polys


func _flat_at_storey(y: float, at := INF) -> Dictionary:
	var px: float = player.position.x if at == INF else at
	for f in _flats:   # (23. 11.) its own house's, not one on the same storey of another (the works next door took
		# the flat's window wall of the house across the alley and threw him back to its left wall)
		if absf(float(f["y"]) - y) < 40.0 and px > float(f["x"]) - SEC_FLAT_DOOR_X - 600.0 and px < float(f["wx1"]) + 1200.0:
			return f
	return {}
const SEC_FLAT_DOOR_X := 1778.0   # (gen/levels.py SEC_FLAT_DOOR: the flat's door from its house's x0)


## The shut door stops him. The player kicks it in himself: a dive or a slide into it (never automatic, user
## 16. 11.); the kick meets the door: the picture stops for a beat, CRACK, splinters, and the door goes in.
func _flat_door_block(before_x: float) -> void:
	var f := _flat_at_storey(_ground_y)
	# (audit 21. 11.) the door is as high as it is drawn: a jump at it no longer goes over a 60 px line through it
	if f.is_empty() or f["open"] or player.position.y < float(f["y"]) - float(f["h"]) - 40.0 or player.position.y > float(f["y"]) + 60.0:
		return
	var face := float(f["hinge"]) - float(f["span"]) - 30.0
	var inner := float(f["hinge"]) + 30.0
	if before_x <= face + 1.0 and player.position.x > face:
		if move_state in ["dive", "slide"] or absf(glide) > 200.0:
			_kick_door(f)
		else:
			player.position.x = face
			run = 0.0
	elif before_x >= inner - 1.0 and player.position.x < inner:   # from inside the flat it opens only by being kicked in from the stairs
		player.position.x = inner
		run = 0.0
		glide = maxf(glide, 0.0)


const FLAT_YAW0 := -1.08        # the door shut in the turned partition (its doorway 112 px wide on the picture, the leaf 238)
const PARTITION_X := 106.0      # tenement_partition.png (gen/flat_partition.py) over tenement_flat, its pixels
const FLAT_DOOR_HINGE := 65.0   # the door's hinge: on the painted post, this far right of the passage's middle
const FLAT_KICK_FROM := 330.0   # how far before the door a run turns into the flying kick
const FLAT_SWING := 2.35        # how far the kicked door swings round its hinge (radians): back into the flat, onto the stove
func _say_near(f: Dictionary) -> void:   # the first man through the door he broke
	var best = null
	for e in enemies:
		if e["alive"] and absf(float(e["node"].position.y) - float(f["y"])) < 60.0 and (best == null or absf(e["node"].position.x - float(f["x"])) < absf(best["node"].position.x - float(f["x"]))):
			best = e
	if best != null:
		best["seen"] = true
		_say(best["node"], "THERE HE IS!")


func _kick_door(f: Dictionary, by_player := true) -> void:
	f["open"] = true
	var d: Polygon2D = f["door"]
	var contact := Vector2(float(f["hinge"]) - float(f["span"]) * 0.8, float(f["y"]) - float(f["h"]) * 0.45)
	_impact(0.09, 0.03)   # the moment of contact: the world holds still a beat
	_word(["crack", "wham"], contact + Vector2(-40.0, -170.0), 0.24, Vector2.RIGHT)
	sfx.play("door", 3.0, contact.x, 0.05)
	sfx.play("wood_break", 1.0, contact.x, 0.08)
	for k in 6:
		fx.chip(contact + Vector2(randf_range(-30.0, 30.0), randf_range(-90.0, 90.0)))
	fx.dust(Vector2(contact.x, float(f["y"])), 0.5)
	_shake = 0.3
	if by_player:   # (audit 21. 11.: the men's break-in behind him took his dive's speed in mid air)
		_free_slow = 1.2
		glide *= 0.25   # the kick takes his speed: he lands in the doorway
	var tw := d.create_tween()
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void:
		d.texture = load("res://art/section/flat_door_broken.png"))
	if by_player and _perk("doorram"):   # BATTERING RAM: torn off its hinges, it flies on the way he kicked, falls flat, flattens whoever is there
		d.z_index = 3
		tw.tween_method(func(t: float) -> void:
			var fly := Vector2(float(f["dw"]) * 0.9 + FLAT_RAM_FLY * t, -60.0 * sin(t * PI))
			_door_card(f, float(f["yaw0"]) * (1.0 - t) + 0.35 * t, DOOR_FLAT * t * t, fly)   # turning a little, tipping over onto the boards
			_door_ram_hits(f, float(f["hinge"]) + fly.x), 0.0, 1.0, 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			sfx.play("wood_hit", 0.0, float(f["hinge"]) + FLAT_RAM_FLY, 0.08)
			fx.dust(Vector2(float(f["hinge"]) + FLAT_RAM_FLY, float(f["y"])), 0.6))
	else:     # round on its hinge into the flat, slammed against the stove, and left hanging there broken
		var swing := func(a: float) -> void:
			_door_card(f, a, 0.0, Vector2.ZERO)
		# (22.-23. 11.) in the turned partition it is shut at yaw0, its free edge toward us: kicked, it goes a quarter turn
		# round its hinge into the flat, square to the wall (user 23. 11.: "only 90 degrees"), and slams to a stop: a bang,
		# dust off it, the picture shakes, it bounces back a little and settles (the old rest snapped it to +FLAT_SWING:
		# the far way round, 180 degrees on the screen)
		var y0 := float(f["yaw0"])
		var turned := y0 != 0.0
		var y1 := y0 - PI * 0.5 if turned else FLAT_SWING
		var back := -0.2 if turned else 0.18
		tw.tween_method(swing, y0, y1, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			var edge := Vector2(float(f["hinge"]) - float(f["dw"]) * cos(y1), float(f["y"]) - float(f["h"]) * 0.5)
			sfx.play("wood_hit", 4.0 if turned else 0.0, edge.x, 0.08)
			if turned:
				sfx.play("door", -2.0, edge.x, 0.05)
				_word(["bang"], edge + Vector2(30.0, -260.0), 0.2, Vector2.RIGHT)
				fx.dust(Vector2(edge.x, float(f["y"])), 0.45)
				fx.dust(edge, 0.3)
				for k in 4:
					fx.chip(edge + Vector2(randf_range(-20.0, 20.0), randf_range(-160.0, 160.0)))
				_shake = maxf(_shake, 0.22)
				_impact(0.05, 0.02))
		tw.tween_method(swing, y1, y1 - back, 0.08).set_ease(Tween.EASE_OUT)   # the bounce off the stop
		tw.tween_method(swing, y1 - back, y1, 0.14).set_ease(Tween.EASE_IN_OUT)
		_door_knock(f, 260.0)   # only the man right behind it
	for e in enemies:   # the rest: caught cold, a beat before they fire
		if e["alive"] and absf(float(e["node"].position.y) - float(f["y"])) < 60.0 and e["node"].position.x > float(f["x"]):
			e["seen"] = true
			e["cool"] = maxf(float(e["cool"]), 0.8)


const FLAT_RAM_FLY := 420.0     # BATTERING RAM: how far the door flies (about a metre and a half)
func _door_ram_hits(f: Dictionary, at_x: float) -> void:
	for e in enemies:
		if e["alive"] and absf(float(e["node"].position.y) - float(f["y"])) < 60.0 and absf(e["node"].position.x - at_x) < 90.0 \
				and String(e["state"]) in ["post", "run", "move", "hop"]:
			_knock_down(e, 900.0)


func _door_knock(f: Dictionary, reach: float) -> void:
	for e in enemies:
		var dx: float = e["node"].position.x - float(f["hinge"])
		if e["alive"] and absf(float(e["node"].position.y) - float(f["y"])) < 60.0 and dx > -20.0 and dx < reach \
				and String(e["state"]) in ["post", "run", "move", "hop"]:
			_knock_down(e, 600.0)


func _knock_down(e: Dictionary, push: float) -> void:
	e["state"] = "down"
	e["down_t"] = 0.0
	e["seen"] = true
	e["push"] = push
	e["node"].duck = 0.0
	e["node"].slide_side = 1.0
	_word(["thud"], e["node"].position + Vector2(0.0, -380.0), 0.18)


## A room whose way out at its far end is a window (user 17. 11.: the tenement hallway "can be a way out through the
## window, but you must jump through it, as in the test level"): the drawn window's glass (picture px of its frame,
## sill and lintel rows) stops him on foot; jumping or diving into it, it bursts out with him.
const ROOM_EXIT_WINDOW := {"tenement": [2850.0, 3040.0, 920.0, 280.0]}
# (user 17. 11.: "the jump through the window is cheap... he comes out of the door... the player doesn't know to do it, it
# blends into the background"; reviewed with Gemini) - the window is lit and glints so it reads as the way out; on foot it
# stops him and says so; a jump into it: a beat of stillness on the glass, then a hard cut (no fade) to the same window
# seen from the street, high in the front over the side door, and he comes out of it head first in slowed time in a cloud
# of glass, falls to the pavement and lands heavy.
# (user 18. 11.: "I go in on the ground floor and jump out of a window upstairs") the ground-floor window right of the
# front's side door - he came in off the street, he goes out at street level (front picture px)
const FRONT_EXIT_WINDOW := {"tenement": Rect2(2660.0, 905.0, 85.0, 170.0)}
var _room_windows_broken := {}
var _room_windows_lit := {}
var _win_hint_t := -99.0
var _win_cut := false   # (the room change it makes is a hard cut, not the dip through black)
var _win_landing := false
var _cam_snap := false
func _room_window_rect(r: Array) -> Rect2:
	var style := String(r[2])
	var x0 := float(r[0])
	var x1 := float(r[1])
	var tex: Texture2D = BigTex.get_tex("res://art/rooms/%s.png" % style)
	var rs: float = ROOM_SCALES.get(style, ROOM_SCALE)
	var w: Array = ROOM_EXIT_WINDOW[style]
	var cx := x0 + (x1 - x0) * 0.5
	var top := -tex.get_height() * rs * SEGMENT_BASE
	var a := cx + (float(w[0]) - tex.get_width() * 0.5) * rs
	var b := cx + (float(w[1]) - tex.get_width() * 0.5) * rs
	return Rect2(a, top + float(w[3]) * rs, b - a, (float(w[2]) - float(w[3])) * rs)


func _light_room_window(r: Array, opening: Rect2) -> void:
	# cold moonlight and rain in the glass, a soft pool of it on the boards: the way out shows at the dark end of the hall
	var into: Node = self
	for ra in _room_art:
		if absf(float(ra[0]) - float(r[0])) < 1.0:
			into = ra[2]
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var holder := Node2D.new()
	holder.z_index = 1
	into.add_child(holder)
	var o := opening.grow(-10.0)
	var glass := Polygon2D.new()
	glass.polygon = PackedVector2Array([o.position, Vector2(o.end.x, o.position.y), o.end, Vector2(o.position.x, o.end.y)])
	glass.vertex_colors = PackedColorArray([Color(0.35, 0.45, 0.65), Color(0.3, 0.4, 0.6), Color(0.12, 0.16, 0.25), Color(0.14, 0.18, 0.28)])
	glass.material = add
	holder.add_child(glass)
	for k in 7:   # rain running down the pane
		var l := Line2D.new()
		var x := o.position.x + o.size.x * (k + 0.5) / 7.0 + randf_range(-6.0, 6.0)
		l.points = PackedVector2Array([Vector2(x, o.position.y + randf_range(0.0, 60.0)), Vector2(x + randf_range(-4.0, 4.0), o.end.y - randf_range(0.0, 50.0))])
		l.width = 2.0
		l.default_color = Color(0.5, 0.6, 0.8, 0.35)
		l.material = add
		holder.add_child(l)
	var pool := Sprite2D.new()
	pool.texture = _soft_glow()
	pool.position = Vector2(o.get_center().x - 120.0, -10.0)
	pool.scale = Vector2(3.2, 0.35)
	pool.modulate = Color(0.35, 0.45, 0.7, 0.5)
	pool.material = add
	holder.add_child(pool)
	var glint := Sprite2D.new()   # a glint that runs over the glass now and then
	glint.texture = _soft_glow()
	glint.material = add
	glint.scale = Vector2(0.35, 1.2)
	glint.rotation = 0.5
	glint.modulate = Color(0.8, 0.9, 1.0, 0.0)
	holder.add_child(glint)
	var tw := glint.create_tween().set_loops()
	tw.tween_callback(func() -> void: glint.position = Vector2(o.position.x, o.position.y + o.size.y * 0.3))
	tw.tween_property(glint, "modulate:a", 0.8, 0.15)
	tw.parallel().tween_property(glint, "position", Vector2(o.end.x, o.position.y + o.size.y * 0.7), 0.5)
	tw.tween_property(glint, "modulate:a", 0.0, 0.15)
	tw.tween_interval(2.2)
	_room_windows_lit[float(r[0])] = holder


func _room_window_block(_before_x: float) -> void:
	for r in rooms:
		var style := String(r[2])
		if not ROOM_EXIT_WINDOW.has(style) or (r as Array).size() > 3:
			continue
		var x0 := float(r[0])
		var x1 := float(r[1])
		if _room_windows_broken.has(x0):
			continue
		var opening := _room_window_rect(r)
		if not _room_windows_lit.has(x0):
			_light_room_window(r, opening)
		if player.position.x < x0 or player.position.x > x1 + 40.0 or player.position.y < GROUND_STOREY:
			continue
		var face := opening.position.x - 20.0   # his front against the glass
		var stand := opening.position.x - 60.0
		var near_glass := opening.position.x - 420.0   # (on foot he is stopped back here, the window ahead: room for the leap)
		if move_state == "ground" or player.position.y > -40.0:
			if player.position.x > near_glass and player.position.x < stand + 1.0 and hud.move > 0.3:
				if _ai_t - _win_hint_t > 6.0:   # walking up to it: the hint, early
					_win_hint_t = _ai_t
					hud.toast("JUMP THROUGH THE WINDOW")
			if player.position.x > stand:
				player.position.x = stand   # on foot the glass stops him
				run = 0.0
				glide = 0.0
				if _ai_t - _win_hint_t > 6.0:
					_win_hint_t = _ai_t
					hud.toast("JUMP THROUGH THE WINDOW")
			continue
		if player.position.x < face:
			# (user 17. 11.: a new pose) close to the glass in the air he throws himself at it head first: the dive
			if move_state == "jump" and player.position.x > face - 330.0:
				move_state = "dive"
				player.dive_side = signf(player.scale.x) if player.scale.x != 0.0 else 1.0
				glide = 720.0
				fall = minf(fall, -140.0)
				dive_rolls = true
				_kicked_this_dive = true
				sfx.play("dive", -2.0)
			continue
		_room_windows_broken[x0] = true
		_crash_out(r, opening)


func _crash_out(r: Array, opening: Rect2) -> void:
	var lit = _room_windows_lit.get(float(r[0]))
	if lit != null and is_instance_valid(lit):
		(lit as Node).queue_free()
	_impact(0.09, 0.02)   # on the glass: a beat of stillness
	_shake = 0.35
	sfx.play("glass", 4.0, opening.get_center().x, 0.05)
	player.dive = 1.0   # (on the glass he is laid out flat, head first)
	glide = 0.0
	fall = 0.0
	var inside := opening.get_center()   # the glass gives inside first: a spray of it back into the hall
	for k in 8:
		fx.chip(inside + Vector2(randf_range(-30.0, 10.0), randf_range(-120.0, 120.0)))
	get_tree().create_timer(0.14, true, false, true).timeout.connect(_crash_out_street.bind(r))


func _crash_out_street(r: Array) -> void:
	if ARGS.has("--log-sets"): print("CRASH OUT t ", snappedf(_at, 0.05))
	# the same window from the street: over the front's side door (the front whose span holds the room's right end)
	var style := String(r[2])
	var out_rect := Rect2(float(r[1]) - 60.0, -1080.0, 160.0, 250.0)
	for seg in level["street"]:
		var art := String(seg[0])
		if art.begins_with("front_") and art.trim_prefix("front_") == style:
			var fx0 := float(seg[1])
			var ws: float = WALL_SCALE * float(SEGMENT_SIZE.get(art, 1.0))
			if float(r[1]) > fx0 and float(r[1]) < fx0 + 3168.0 * ws:
				var fr: Rect2 = FRONT_EXIT_WINDOW.get(style, Rect2())
				var top := -1344.0 * ws * SEGMENT_BASE - WALL_LIFT
				out_rect = Rect2(fx0 + fr.position.x * ws, top + fr.position.y * ws, fr.size.x * ws, fr.size.y * ws)
	var hole := Polygon2D.new()   # the frame left empty, jagged teeth of glass round it
	var pts := PackedVector2Array()
	var o := out_rect.grow(-6.0)
	var n := 22
	for k in n:
		var t := float(k) / n
		var edge: Vector2
		if t < 0.25:
			edge = o.position.lerp(Vector2(o.end.x, o.position.y), t * 4.0)
		elif t < 0.5:
			edge = Vector2(o.end.x, o.position.y).lerp(o.end, (t - 0.25) * 4.0)
		elif t < 0.75:
			edge = o.end.lerp(Vector2(o.position.x, o.end.y), (t - 0.5) * 4.0)
		else:
			edge = Vector2(o.position.x, o.end.y).lerp(o.position, (t - 0.75) * 4.0)
		pts.append(edge.lerp(o.get_center(), randf_range(0.0, 0.18)))
	hole.polygon = pts
	hole.color = _undo_night(0.5) * Color(0.55, 0.62, 0.8)   # the hallway's light behind him: he comes out as a dark shape
	hole.z_index = -5   # (over the front's drawing)
	add_child(hole)
	hole.create_tween().tween_property(hole, "color", Color(0.03, 0.03, 0.05), 1.6).set_delay(0.6)   # and it goes dark behind him
	var glow := Sprite2D.new()
	glow.texture = _soft_glow()
	glow.position = out_rect.get_center()
	glow.scale = Vector2(3.0, 3.0)
	glow.modulate = _undo_night(0.4) * Color(0.6, 0.7, 1.0, 0.7)
	var addm := CanvasItemMaterial.new()
	addm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = addm
	glow.z_index = -4
	add_child(glow)
	var gt := glow.create_tween()
	gt.tween_property(glow, "modulate:a", 0.0, 1.2).set_delay(0.3)
	gt.tween_callback(glow.queue_free)
	# the cut: a white frame and a held beat, then the fall
	var lay := CanvasLayer.new()
	lay.layer = 3
	add_child(lay)
	var white := ColorRect.new()
	white.color = Color(1.0, 1.0, 1.0, 0.35)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	lay.add_child(white)
	var wt := white.create_tween()
	wt.tween_property(white, "color:a", 0.0, 0.12)
	wt.tween_callback(lay.queue_free)
	_impact(0.06, 0.02)
	# a hard cut: he is out there, head first through it, the glass going with him
	_win_cut = true
	_cam_snap = true
	player.position = Vector2(maxf(out_rect.end.x + 40.0, float(r[1]) + 30.0), out_rect.end.y - 30.0)   # (already half out of the frame)   # (past the room's end: on the street side)
	_tick_rooms()   # (the hallway goes the same frame: never a frame of it without him)
	_ground_y = 0.0
	move_state = "dive"   # head first out of the frame, laid out flat, and over the shoulder on the stones
	player.dive = 1.0
	player.dive_side = signf(player.scale.x) if player.scale.x != 0.0 else 1.0
	dive_rolls = true
	_kicked_this_dive = true
	glide = 680.0
	run = 0.0
	fall = -220.0
	fx.burst_window(out_rect, Vector2(1000.0, -260.0), 0.0, Vector2(-INF, INF), 0.0)   # (fast and wide: clear of him at once)
	fx.shatter(out_rect.get_center())
	_word(["crash", "smash"], out_rect.get_center() + Vector2(170.0, -150.0), 0.26, Vector2.RIGHT)
	sfx.play("glass", 2.0, out_rect.get_center().x, 0.08)
	_free_slow = maxf(_free_slow, 1.1)   # out of the window in slowed time, the shards round him
	_grace = maxf(_grace, 1.6)
	_win_landing = true


## Through the flat's window: only in the air (the sill is above the boards); the glass bursts out with him.
func _through_window() -> bool:
	var f := _flat_at_storey(_ground_y)
	if f.is_empty() or move_state not in ["jump", "dive"] or player.position.x < float(f["wx0"]) - 70.0:
		return false
	if not f["broken"] and glide + run < 150.0:
		return false   # (audit 21. 11.) through the glass going out at it, not a hop against the wall under it (no nearer than
		# the wall's stop at wx0 - 60 though: a mark at wx0 - 20 was never reached and nobody got out, user 22. 11.)
	if player.position.y > float(f["y"]) + 10.0:
		return false
	if not f["broken"]:
		f["broken"] = true
		for fa in _flat_art:   # nothing left in the frame: all of it goes out with him
			if absf(float(fa[0]) - float(f["y"])) < 10.0 and absf((fa[1] as Sprite2D).global_position.x - float(f["wx0"])) < 9000.0:
				(fa[1] as Sprite2D).texture = BigTex.get_tex("res://art/section/%s_flat_open.png" % String(fa[2]))
		var mid := Vector2(float(f["gx"]), float(f["y"]) - (float(f["sill"]) + float(f["lintel"])) * 0.5)
		_impact(0.06, 0.05)
		_word(["crash", "smash"], mid + Vector2(60.0, -200.0), 0.24, Vector2.RIGHT)
		var opening := Rect2(float(f["wx0"]), float(f["y"]) - float(f["lintel"]), float(f["wx1"]) - float(f["wx0"]), float(f["lintel"]) - float(f["sill"]))
		var deck := Vector2(-INF, INF)
		for c in level["floors"]:   # the fire escape's landing outside: what falls past its end goes down to the street
			if String(c[3]) == "fescape" and absf(float(c[1]) - float(f["y"])) < 10.0:
				deck = Vector2(float(c[0]), float(c[0]) + float(c[2]))
		fx.burst_window(opening, Vector2(glide + run, fall), float(f["y"]), deck, 0.0)   # out with him
		fx.shatter(mid)
		_clip("window", glide + run)   # an arm over his face against the glass, knees up
		sfx.play("glass", 3.0, float(f["gx"]), 0.05)
		_free_slow = maxf(_free_slow, 0.5)
	return true


## The flat's shut door between two points on its storey.
func _flat_closed_between(a: Vector2, b: Vector2) -> bool:
	for f in _flats:
		if f["open"] or absf(a.y - float(f["y"])) > 300.0 or absf(b.y - float(f["y"])) > 300.0:
			continue
		if (a.x - float(f["hinge"])) * (b.x - float(f["hinge"])) < 0.0:
			return true
	return false


const AWNING_BOUNCE := 120.0   # how fast he must be falling for the awning to throw him back up (any landing from a jump)
func _awning_under() -> bool:
	for i in catwalks.size():
		var c: Rect2 = catwalks[i]
		if catwalk_style[i] == "awning" and player.position.x > c.position.x and player.position.x < c.end.x and absf(player.position.y - c.position.y) < 60.0:
			return true
	return false


func _stair_foot() -> float:
	return 0.0 if _section_kit() else STAIRDOOR_FOOT   # the kit's flights go straight back from the opening


func _stair_door_here() -> int:
	for i in _stairdoors.size():
		var d: Array = _stairdoors[i]
		if absf(player.position.x - float(d[0])) < 110.0 and absf(player.position.y - float(d[1])) < 12.0:
			return i
	return -1


func _start_stairdoor(i: int) -> void:
	var d: Array = _stairdoors[i]
	move_state = "stairs"
	run = 0.0
	glide = 0.0
	_jump_buf = 0.0
	_sd = {"from": player.position, "x": float(d[0]), "to": float(d[1 + 1]), "t": 0.0, "moved": false}
	_grace = maxf(_grace, STAIRDOOR_IN + STAIRDOOR_HOLD + STAIRDOOR_OUT + 1.5)   # the way through is a calm beat
	sfx.play("step1", -6.0, player.position.x, 0.1)


func _on_stairdoor(delta: float) -> float:
	# The flight painted in each storey's opening leads UP from that storey. Going up he climbs it into the
	# dark and comes out of the opening above on the level, from behind; going down he walks into the
	# opening on the level and comes down the flight painted below.
	_sd["t"] = float(_sd["t"]) + delta
	var t: float = _sd["t"]
	var from: Vector2 = _sd["from"]
	var to_y: float = _sd["to"]
	var up := to_y < from.y
	var foot := float(_sd["x"]) + _stair_foot()
	var top := float(_sd["x"]) - _stair_foot()
	var climb := -170.0   # how much of the painted flight is seen walked before the dark takes him
	player.duck = 0.0
	if t < STAIRDOOR_IN:
		var k := t / STAIRDOOR_IN
		if up:   # to the foot of the flight, then up it
			var a := smoothstep(0.0, 0.35, k)
			var b := smoothstep(0.35, 1.0, k)
			player.position = Vector2(lerpf(lerpf(from.x, foot, a), top, b), from.y + climb * b)
		else:    # into the opening, on the level
			player.position = Vector2(lerpf(from.x, float(_sd["x"]), smoothstep(0.0, 1.0, k)), from.y)
		var v := 1.0 - 0.85 * smoothstep(0.2, 1.0, k)
		player.modulate = Color(v, v, v, 1.0 - smoothstep(0.7, 1.0, k))
		return 0.6
	if not _sd["moved"]:   # gone into the dark: he is on the other storey now, the camera goes after him
		_sd["moved"] = true
		_ground_y = to_y
		player.position = Vector2(float(_sd["x"]) if up else top, to_y + (0.0 if up else climb))
		sfx.play("step2", -10.0, player.position.x, 0.1)
	if t < STAIRDOOR_IN + STAIRDOOR_HOLD:
		player.modulate = Color(0.15, 0.15, 0.15, 0.0)
		return 0.0
	var k := clampf((t - STAIRDOOR_IN - STAIRDOOR_HOLD) / STAIRDOOR_OUT, 0.0, 1.0)
	var e := smoothstep(0.0, 1.0, k)
	if up:   # out of the opening on the level, a step toward the hallway
		var way := 1.0 if roundi(-to_y / section_h) % 2 == 0 else -1.0   # the way on along that storey (the route zigzags)
		player.position = Vector2(float(_sd["x"]) + way * 90.0 * e, to_y)
	else:    # down the flight painted on this storey, from the dark at its top
		player.position = Vector2(lerpf(top, foot, e), to_y + climb * (1.0 - e))
	var v := 0.15 + 0.85 * smoothstep(0.2, 1.0, k)
	player.modulate = Color(v, v, v, smoothstep(0.0, 0.4, k))
	if k >= 1.0:
		player.position.y = to_y
		player.modulate = Color.WHITE
		move_state = "ground"
		_sd = {}
	return 0.6


## The building he is in, or -1; `storey` out: which storey (0 = the street's).
func _section_at(p: Vector2, me := false) -> int:
	for i in sections.size():
		var sec: Array = sections[i]
		if p.x > float(sec[0]) and p.x < float(sec[1]) and p.y > -section_h * int(sec[2]) + 20.0:
			if String(sec[3]) == "works" and p.y > -60.0 and _works_out and player != null and (me or p.distance_to(player.position) < 1.0):
				continue   # (QUEUE §22) he walks the pavement in front of the works: it has no door but its own
			return i
	return -1


## (QUEUE §22) In the works' hall or out in front of it: in from up high (its window), out by its street door.
func _tick_works() -> void:
	if _works_out != _works_boxes_out:   # (23. 11.) its floor's crates and drums stand in the hall, not on the pavement in front
		_works_boxes_out = _works_out
		for bi in boxes.size():
			var bc: Vector2 = boxes[bi].get_center()
			for s in sections:
				if String(s[3]) == "works" and absf(bc.y + boxes[bi].size.y * 0.5 - (0.0 if _works_out else WORKS_AWAY)) < 40.0 						and bc.x > float(s[0]) and bc.x < float(s[1]):
					boxes[bi].position.y += WORKS_AWAY if _works_out else -WORKS_AWAY
	for i in sections.size():
		var sec: Array = sections[i]
		if String(sec[3]) != "works":
			continue
		var x0 := float(sec[0])
		var px: float = player.position.x
		var door := x0 + WORKS_DOOR
		if not _works_out and absf(px - door) > 150.0:
			_door_armed = true   # (in by the door just now: it lets him out only once he has been in the hall)
		if px > x0 and px < float(sec[1]) and (_ground_y < -60.0 or move_state == "climb"):
			_works_out = false   # up on a gallery or its ladder (a jump on the pavement in front is still the pavement)
		elif not _works_out and _door_armed and player.position.y > -60.0 and _ground_y > -60.0 and move_state in ["ground", "slide", "dive"] 				and (_works_px - door) * (px - door) <= 0.0 and _works_px != px:
			_works_out = true   # (user 23. 11.: "there is no way on out of the works") out through its door, walking
			(_sec_art[i]["ink"] as ShaderMaterial).set_shader_parameter("origin", Vector2(door, -210.0))
		elif _works_out and _up_held and move_state == "ground" and absf(px - door) < 90.0:
			_works_out = false   # in from the pavement: the stick up at its door, as onto a ladder (the pavement goes on
			# past it - walking by is walking by, user 23. 11.: "it should switch where I go in at the door")
			(_sec_art[i]["ink"] as ShaderMaterial).set_shader_parameter("origin", Vector2(door, -210.0))
			sfx.play("door", -6.0, door, 0.05)
			_up_spent = true   # (the same push of the stick does not take him on up the ladder beside the door)
			_door_armed = false
		_works_px = px


## Inside: the facade dissolves from the door and the storeys show; outside it closes back over them.
func _tick_sections(real: float) -> void:
	_tick_works()
	var inside := _section_at(player.position)
	for i in _sec_art.size():
		var art: Dictionary = _sec_art[i]
		var h: Node2D = art["holder"]
		var was := float(art["open"])
		var open := move_toward(was, 1.0 if i == inside else 0.0, real / SEC_DISSOLVE)
		art["open"] = open
		h.visible = open > 0.0
		var moving := open > 0.0 and open < 1.0
		if moving or was != open:   # the dissolve: an inked edge running out from the door, eased
			var e := open * open * (3.0 - 2.0 * open)
			(art["ink"] as ShaderMaterial).set_shader_parameter("radius", lerpf(-400.0, float(art["reach"]), e))
			for st in h.get_children():
				for sp in st.get_children():
					(sp as CanvasItem).material = art["ink"] if moving else null
		var sx1 := float((sections[i] as Array)[1])
		for f in _flats:   # the flat's door and glass show with the storeys (of its own house: audit 21. 11.)
			if float(f["x"]) >= float((sections[i] as Array)[0]) and float(f["x"]) <= sx1:
				for key in ["door", "glass"]:
					(f[key] as CanvasItem).visible = open > 0.5
		for bi in boxes.size():   # (audit 21. 11.) a crate in there stood in front of the closed facade
			var bc: float = boxes[bi].get_center().x
			if bc > float((sections[i] as Array)[0]) and bc < sx1 and box_info[bi]["sprite"] != null and is_instance_valid(box_info[bi]["sprite"]):
				(box_info[bi]["sprite"] as CanvasItem).visible = open > 0.3
		for e in enemies:   # whoever is inside is behind the facade until it opens: nobody floats in front of it
			if e["state"] != "wait" and _section_at(e["node"].position) == i:
				e["node"].visible = open > 0.3
		# the storey he is on is lit, the others sink back; on the stairs the light goes up with him
		var want := clampf(-player.position.y / section_h, 0.0, float(h.get_child_count() - 1)) if i == inside else float(art["lit"])
		art["lit"] = lerpf(float(art["lit"]), want, 1.0 - exp(-6.0 * real))
		for k in h.get_child_count():
			var near := clampf(1.0 - absf(float(k) - float(art["lit"])), 0.0, 1.0)
			var v := ROOM_BASE * lerpf(SEC_DIM, 1.0, near)   # brightness only: the storey stays opaque over the facade
			(h.get_child(k) as CanvasItem).modulate = Color(v, v, v, 1.0)
	var st := roundi(-_ground_y / section_h) if inside >= 0 else -1
	if st != _storey_was:
		_storey_was = st
		_storey_since = _ai_t
	_steps_above = maxf(0.0, _steps_above - real)
	if inside < 0 or over:
		return
	var held := _xy_index(checkpoint, checkpoint_y)   # (audit 21. 11.) only ever on up: going back down takes none
	for ci in _xy_checks.size():   # a checkpoint on each storey, where he comes up the stairs
		var c: Array = _xy_checks[ci]
		if ci > held and absf(player.position.y - float(c[1])) < 60.0 and absf(player.position.x - float(c[0])) < 160.0 \
				and move_state == "ground":
			if checkpoint_y >= 0.0:
				_ground_cp = checkpoint
			_take_checkpoint(float(c[0]), float(c[1]))


## The storey checkpoint he holds (its index in xy_checks), or -1 for none.
func _xy_index(x: float, y: float) -> int:
	var xs: Array = level.get("xy_checks", [])
	for i in xs.size():
		if absf(float(xs[i][0]) - x) < 1.0 and absf(float(xs[i][1]) - y) < 1.0:
			return i
	return -1


## The way on along the storey he is on: the ground floor and the second go right, the first left.
func _section_dir() -> float:
	var i := _section_at(player.position)
	if i < 0:
		return 0.0
	if _works(i):   # (the works: one hall, out at its far end)
		return 1.0
	var storey := int(floor((-_ground_y + 2.0) / section_h))   # on the stairs: still the storey he climbs from, to the top step
	return 1.0 if storey % 2 == 0 else -1.0


## The rooms, crates, floors, stairs, lamps, pickups and mobsters of the map being played.
func _build_level() -> void:
	for r in rooms:
		if String(r[2]).begins_with("section_"):
			continue   # a storey of a building in cross-section: drawn by _build_sections
		_build_room(float(r[0]), float(r[1]), String(r[2]))
	_build_sections()
	_build_city()
	for spec in level["boxes"]:
		var kind := String(spec[0])
		var art: String = BOX_ART[kind][0] if BOX_ART.has(kind) else kind
		var grow: float = 1.0 if kind in ["stack", "car"] else FIG   # a cargo stack is sized to the rope that swings over it
		var bw := float(spec[2]) * grow
		var bh := float(spec[3]) * grow
		var place := _place_at(float(spec[1]) + float(spec[2]) * 0.5)
		var choices: Array = (PROP_SETS.get(place, {}) as Dictionary).get(kind, [])
		var local: bool = kind != "barrel" and not choices.is_empty() and (spec.size() <= 4 or float(spec[4]) == 0.0)   # up on the roof: tar drums and builders' crates
		if local:   # the same spot always gets the same thing
			art = String(choices[absi(int(float(spec[1]) / 37.0)) % choices.size()])
		var tex: Texture2D = LowRes.tex("res://art/props/" + art + ".png", 0.5)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		var inset: float = TOP_INSET.get(art, 0.05)
		var cx := float(spec[1]) + float(spec[2]) * 0.5   # grown round its own middle, not into the next one
		var base := float(spec[4]) if spec.size() > 4 else 0.0   # up on the roof, or on the street
		var sx: float
		var sy: float
		if local:   # its own proportions at its real size
			sy = float(PROP_H.get(art, bh)) / (tex.get_height() * (1.0 - inset))
			sx = sy
		else:
			sx = bw / tex.get_width()
			sy = bh / (tex.get_height() * (1.0 - inset))
		# the box is what he stands on and hides behind: exactly as wide as the drawing, and its top
		# exactly the drawn surface (it used to sit 6 px over the lid, so he floated above crates)
		var w := tex.get_width() * sx
		var top := tex.get_height() * sy * (1.0 - inset)
		s.scale = Vector2(sx, sy)
		s.position = Vector2(cx - w * 0.5, base - top - tex.get_height() * sy * inset + 3.0)
		s.z_index = -2
		if BOX_ART.has(kind) and not local:
			s.modulate = BOX_ART[kind][1]
		elif local:
			s.modulate = Color(0.84, 0.82, 0.79)   # the new drawings came out paler than the old crates: match them
		add_child(s)
		_ground_shadow(cx, w, base)
		boxes.append(Rect2(cx - w * 0.5, base - top, w, top))
		if _auto != "":   # the audit: everything in its place and the right size beside a man
			var why := ""
			if art in INDOOR_ONLY and not place.begins_with("room:"):
				why = "indoor thing outdoors"
			elif art in OUTDOOR_ONLY and place.begins_with("room:"):
				why = "street thing indoors"
			elif top < 110.0 * FIG:
				why = "too small beside a man"
			elif top > 262.0 * FIG and kind != "bar" and kind != "stack":   # a cargo stack is meant to be swung over
				why = "too tall to get over: it would block the street"
			if why != "":
				print("AUDIT BAD ", why, ": ", art, " in ", place, " at ", cx, " top ", top)
		box_info.append({"kind": kind, "sprite": s, "hp": 7, "wood": kind in WOOD and (not local or art in WOOD)})
	for c in level["floors"]:
		var r := Rect2(float(c[0]), float(c[1]), float(c[2]), 0.0)
		catwalks.append(r)
		catwalk_style.append(String(c[3]))
		catwalk_solid.append(String(c[3]) in ["roof", "section", "fescape"])   # a storey's floor, a fire escape's deck: no dropping through it
		if String(c[3]) == "bar":   # the club's bar counter (art_src 246), standing on the boards, its top the floor
			var bt: Texture2D = load("res://art/props/bar_counter.png")
			var bh := (-r.position.y + 6.0) / (1.0 - 0.238)   # its top (24 % down the drawing) is the floor
			var bar := Sprite2D.new()
			bar.texture = bt
			bar.centered = false
			bar.scale = Vector2(r.size.x / bt.get_width(), bh / bt.get_height())   # (stretched along: a long bar, a man's waist high)
			bar.position = Vector2(r.position.x, -bh)
			bar.z_index = -2
			bar.modulate = Color(0.84, 0.82, 0.79)
			add_child(bar)
			var first := get_child_count()
			_ground_shadow(r.position.x + r.size.x * 0.5, r.size.x, 0.0)
			var ri := _plain_room_at(Vector2(r.get_center().x, -10.0))
			if ri >= 0:   # the counter is the room's: seen only from inside it, like the rest of the room
				bar.reparent(_room_art[ri][2])
				for n in get_children().slice(first):
					(n as Node).reparent(_room_art[ri][2])
			continue
		if String(c[3]) in ["section", "fescape", "drawn", "awning"]:
			continue   # the storey's drawing (or the fire escape's) is the floor
		if String(c[3]) == "floor":
			_slab(r)
			continue
		if String(c[3]) == "roof":   # the roof drawing is the floor (see _build_roofs)
			continue
		if String(c[3]) == "scaffold":
			_scaffold(r)
			continue
		# Ironwork baked at the game's scale (gen/iron.py): a landing bolted to the wall, or on the
		# docks a walkway on its own legs. Deck and railing in front of the man on it; brackets behind.
		var path := "res://art/props/iron_walk.png"
		if String(c[3]) != "gantry":
			var n := 0
			for k in IRON_LAND_W.size():
				if absf(IRON_LAND_W[k] - r.size.x) < absf(IRON_LAND_W[n] - r.size.x):
					n = k
			path = "res://art/props/iron_land_%d.png" % n
		var it: Texture2D = load(path)
		var ox := r.position.x + (r.size.x - it.get_width()) * 0.5
		for part in 2:
			var sp := Sprite2D.new()
			sp.texture = it
			sp.centered = false
			sp.region_enabled = true
			sp.region_rect = Rect2(0.0, 0.0, it.get_width(), IRON_SPLIT) if part == 0 else Rect2(0.0, IRON_SPLIT, it.get_width(), it.get_height() - IRON_SPLIT)
			sp.position = Vector2(ox, r.position.y - IRON_DECK + (0.0 if part == 0 else IRON_SPLIT))
			sp.z_index = 2 if part == 0 else -2
			add_child(sp)
	for rp in level["ramps"]:
		ramps.append(rp)
		if rp.size() > 4 and (String(rp[4]) == "section" and _section_kit() or String(rp[4]) == "fescape"):
			continue   # the stairs are in the storey's drawing (until it is drawn: the street's stairs stand in)
		if rp.size() > 4 and String(rp[4]) == "station":
			_station_stairs(Vector2(float(rp[0]), float(rp[1])), Vector2(float(rp[2]), float(rp[3])))
		else:
			_stairs(Vector2(float(rp[0]), float(rp[1])), Vector2(float(rp[2]), float(rp[3])))
	for ro in level.get("ropes", []):
		_add_rope(ro)
	for l in level["lamps"]:   # the rooms' lamps: a shaded bulb hanging on its cord from the ceiling, and its light
		var at := Vector2(float(l[0]), float(l[1]))
		if ROOM_BULBS.has(_room_at(at.x)):
			continue   # that room's drawing has its own lamps (see _build_room)
		var pend := _pendant(at)
		lamps.append(at + Vector2(0.0, 8.0))
		var light := _lamp_light(at + Vector2(0.0, -8.0))
		light.reparent(pend["node"])   # the pool of light swings with the lamp
		var rec := {"nodes": [pend["bulb"]], "light": light, "on": true, "glass": -6.0, "r": 34.0, "pend": pend}
		lamp_info.append(rec)
		pend["lamp"] = lamps.size() - 1
		_swingers.append(pend)
	if in_menu:
		return
	for pk in level["pickups"]:
		_add_pickup(String(pk[0]), Vector2(float(pk[1]), float(pk[2])))
	for spec in _cast(level["enemies"]):
		var goal := Vector2(float(spec["x"]), float(spec["y"]))
		var runner: bool = spec["run"]
		if checkpoint_y < 0.0 and checkpoint > 0.0 and _xy_index(checkpoint, checkpoint_y) >= 0:   # (audit 21. 11.) a storey of a house
			var house := []
			for s in level.get("sections", []):
				if checkpoint >= float(s[0]) and checkpoint <= float(s[1]):
					house = s
			var way := 1.0 if roundi(-checkpoint_y / section_h) % 2 == 0 else -1.0   # as _section_dir
			if house.is_empty() or goal.x < float(house[0]):
				if goal.x < checkpoint + 300.0 and (not runner or float(spec["trig"]) < checkpoint):
					continue   # the street before the house
			elif goal.x <= float(house[1]):
				if goal.y > checkpoint_y + 100.0:
					continue   # the storeys below him
				if absf(goal.y - checkpoint_y) < 100.0 and (goal.x - checkpoint) * way < 300.0:
					continue   # behind him on his storey
		elif checkpoint_y < 0.0 and checkpoint > 0.0:   # back on the roof: all below him, and those he passed up here, are done with
			if goal.y > checkpoint_y + 100.0 or (goal.x > checkpoint - 300.0 and not runner):
				continue
		elif checkpoint > 0.0 and goal.x < checkpoint + 300.0 and (not runner or float(spec["trig"]) < checkpoint):
			continue   # dealt with before the checkpoint
		var e := _add_enemy(Vector2(float(spec["from"]), goal.y) if runner else goal, String(spec["kind"]), "wait" if runner else "post", goal.x)
		e["trig"] = float(spec["trig"])
		e["delay"] = float(spec["delay"])
		if e["boss"]:
			boss = e
	_add_witness()
	_place_loads()
	if not roof.is_empty():   # what is on the roof only matters up there, and the street only down here
		var lo: Array[Rect2] = []
		var hi: Array[Rect2] = []
		var lo_i: Array = []
		var hi_i: Array = []
		for i in boxes.size():
			if boxes[i].end.y < float(roof["y"]) + 50.0:
				hi.append(boxes[i])
				hi_i.append(box_info[i])
			else:
				lo.append(boxes[i])
				lo_i.append(box_info[i])
		_box_sets = {"lo": [lo, lo_i], "hi": [hi, hi_i]}
		boxes = lo
		box_info = lo_i
		_box_up = false


func _swap_boxes() -> void:
	if _box_sets.is_empty():
		return
	var up: bool = player.position.y < float(roof["y"]) + 250.0
	if up != _box_up:
		_box_up = up
		var set_: Array = _box_sets["hi" if up else "lo"]
		boxes = set_[0]
		box_info = set_[1]


## The difficulty curve. The prologue is Eddie at his best: the player sees what a man who has done
## this for twenty years can do. Then Eddie dies and the story passes to Frank, who has not held a gun
## in anger for eight years: fewer hits to put him down, a shorter slowed time that comes back slower.
## His first streets are thin and forgiving, and every map after asks a little more: more of the mob,
## harder men, tighter aim, shorter pauses, more of them firing at once. Frank grows into it as he goes
## (his rank and his instincts: instincts.gd).
## Rows: step (Frank's maps counted from chapter I map 1) -> mobsters per 10,000 px of street,
## body hits per mobster, aim spread, pause between shots, men firing at once, share of plain gunmen
## swapped for a Tommy gun or a shotgun.
const CURVE := [
	[0, {"density": 4.7, "mob_hp": 3, "aim": 1.45, "pause": 1.35, "shooters": 1, "heavy": 0.0}],
	[2, {"density": 6.0, "mob_hp": 3, "aim": 1.3, "pause": 1.2, "shooters": 2, "heavy": 0.0}],
	[4, {"density": 7.2, "mob_hp": 3, "aim": 1.15, "pause": 1.1, "shooters": 2, "heavy": 0.0}],
	[7, {"density": 9.0, "mob_hp": 3, "aim": 1.0, "pause": 1.0, "shooters": 2, "heavy": 0.1}],
	# (audit 18. 11.: the bot took 2-4 hits a map in chapter II and 16-21 in chapter III - a wall, not a slope) three at once
	# and the tighter aim only by the chapter's end; Briggs' map (16) keeps the old hardest row
	[10, {"density": 10.0, "mob_hp": 3, "aim": 0.97, "pause": 0.97, "shooters": 2, "heavy": 0.2}],
	[13, {"density": 11.0, "mob_hp": 3, "aim": 0.93, "pause": 0.93, "shooters": 2, "heavy": 0.25}],
	[16, {"density": 13.5, "mob_hp": 4, "aim": 0.85, "pause": 0.85, "shooters": 3, "heavy": 0.3}],
]
# The three settings on top of the curve: hits Frank can take, how many men, how well they aim, how
# long they wait between shots, how many may fire at once.
const DIFFICULTY := [
	{"hp": 1, "density": 0.8, "aim": 1.25, "pause": 1.2, "shooters": 0},
	{"hp": 0, "density": 1.0, "aim": 1.0, "pause": 1.0, "shooters": 0},
	{"hp": -1, "density": 1.15, "aim": 0.85, "pause": 0.85, "shooters": 1},
]
const EDDIE := {"hp": PLAYER_HP, "drain": 0.28, "refill": 0.14, "density": -1.0, "mob_hp": MOBSTER_HP, "aim": 1.0, "pause": 1.0, "shooters": 2, "heavy": 0.0}
var diff: Dictionary = EDDIE
var _last_chance_used := false
var _kicked_this_dive := false
var _kick_target = null   # the kick test's man
var _last_round_t := 0.0   # the LAST ROUND instinct: seconds the last bullet still kills whatever it hits
var diff_step := -1   # -1 in the prologue


## An instinct Frank has pinned (never Eddie's: the prologue is played as it is).
## A head hit: always a kill, but for two Berettas sprayed (balance 2026-11-16: the bot's sprays hit
## heads by chance 18 times in 19 kills; two of their head hits kill).
func _head_dmg() -> float:
	if weapon == "revolver" and side == "beretta" and player.dual:
		return float(mob_hp) * 0.55
	return float(mob_hp)


## A body hit with the gun in hand: the side gun's own weight (SIDE_STATS), its loads card on top.
func _body_dmg() -> float:
	if weapon != "revolver":
		return 1.0
	var d := float(_w("revolver")["dmg"])
	if _sperk("dmg"):
		d *= 2.0 if side == "revolver" else 1.5
	return d


func _perk(fx: String) -> bool:
	return diff_step >= 0 and Instincts.has_fx(fx)


func _set_difficulty(hero: String) -> void:
	var step := -1
	if hero != "eddie":
		step = 0
		for c in range(1, chapter):
			step += (Levels.CAMPAIGN[c]["maps"] as Array).size()
		step += map
	for arg in ARGS:   # --step=N tries any point of the curve
		if arg.begins_with("--step="):
			step = int(arg.trim_prefix("--step="))
	diff_step = step
	if step < 0:
		diff = EDDIE.duplicate()
	else:
		diff = _curve_at(step)
		var lvl := int(MenuScript.setting("difficulty"))   # 0 easy, 1 normal, 2 hard (settings)
		var k: Dictionary = DIFFICULTY[clampi(lvl, 0, 2)]
		diff["density"] = float(diff["density"]) * float(k["density"])
		diff["aim"] = float(diff["aim"]) * float(k["aim"])
		diff["pause"] = float(diff["pause"]) * float(k["pause"])
		diff["shooters"] = clampi(int(diff["shooters"]) + int(k["shooters"]), 1, 3)
		var r := Instincts.rank()
		diff["hp"] = maxi(2, int(r[0]) + int(k["hp"]))
		diff["drain"] = float(r[1])
		diff["refill"] = r[2]
	max_hp = int(diff["hp"])
	mob_hp = int(diff["mob_hp"])
	hp = max_hp


## The curve between its rows: the counts step, the rest slides.
static func _curve_at(step: int) -> Dictionary:
	var lo: Array = CURVE[0]
	var hi: Array = CURVE[CURVE.size() - 1]
	for i in CURVE.size():
		if int(CURVE[i][0]) <= step:
			lo = CURVE[i]
			hi = CURVE[mini(i + 1, CURVE.size() - 1)]
	var a: Dictionary = lo[1]
	var b: Dictionary = hi[1]
	var t := 0.0 if hi == lo else clampf(float(step - int(lo[0])) / float(int(hi[0]) - int(lo[0])), 0.0, 1.0)
	return {"density": lerpf(a["density"], b["density"], t), "mob_hp": int(a["mob_hp"]), "aim": lerpf(a["aim"], b["aim"], t),
		"pause": lerpf(a["pause"], b["pause"], t), "shooters": int(a["shooters"]), "heavy": lerpf(a["heavy"], b["heavy"], t)}


## The map's mob as this point of the story has it: as many men as the curve's density asks for on a
## street this long. Early on some plain gunmen stay home (spread evenly along the street, never a boss,
## never the last man of an ambush); later a gunman standing in the open gets a partner a few steps
## behind him, where nothing stands, and some carry heavier guns. The prologue keeps its mob as drawn.
## Always the same for the same map, so a checkpoint finds the street as it was.
## (audit 22. 11.) gen/levels.py thin_to_curve already lays the count the curve asks for at the normal setting, so on
## normal this keeps every man; it cuts or adds only for easy / hard (and where a map's drawn fights hold more).
func _cast(specs: Array) -> Array:
	if float(diff["density"]) < 0.0:
		return specs
	var posts := 0
	for spec in specs:
		posts += 1 if String(spec["kind"]) == "post" else 0
	var want := roundi(float(level["end"]) / 10000.0 * float(diff["density"]))
	var want_posts := maxi(want - (specs.size() - posts), ceili(posts * 0.4))
	var keep := minf(1.0, float(want_posts) / maxf(1.0, float(posts)))
	var partners: Array = []   # indices of the men who get one
	if want_posts > posts:
		var open: Array = []
		for i in specs.size():
			if _partner_spot(specs, i) != INF:
				open.append(i)
		var extra := mini(want_posts - posts, open.size())
		var acc := 0.5
		for i in open:
			acc += float(extra) / float(maxi(1, open.size()))
			if acc >= 1.0:
				acc -= 1.0
				partners.append(i)
	var out: Array = []
	var keep_acc := 0.5
	var heavy_acc := 0.0
	var heavy_pick := 0
	for i in specs.size():
		var spec: Dictionary = (specs[i] as Dictionary).duplicate()
		if String(spec["kind"]) == "post":
			keep_acc += keep
			var last_of_group: bool = bool(spec["run"]) and (i + 1 >= specs.size() or not bool(specs[i + 1]["run"]) or float(specs[i + 1]["trig"]) != float(spec["trig"]))
			if keep_acc < 1.0 and not last_of_group:
				continue
			keep_acc = maxf(0.0, keep_acc - 1.0)
		var group := [spec]
		if i in partners:
			var mate := spec.duplicate()
			mate["x"] = _partner_spot(specs, i)
			group.append(mate)
		for g in group:
			if String(g["kind"]) == "post":
				heavy_acc += float(diff["heavy"])
				if heavy_acc >= 1.0:
					heavy_acc -= 1.0
					g["kind"] = ["tommy", "shotgun"][heavy_pick % 2]
					heavy_pick += 1
			out.append(g)
	return _chapter_men(out)


## Each chapter brings its own men (GDD 8). The docks: longshoremen with cargo hooks who come running,
## a man lobbing dynamite from a height, a marksman with a scoped rifle. Underground: police with steel
## shields and a flashlight that finds Frank in the dark, and a police marksman. Only plain gunmen are
## swapped, spread evenly; the counts grow a little through the chapter.
const CHAPTER_MEN := {
	2: [["hook", 0.16, "any"], ["dynamite", 0.1, "high"], ["sniper", 0.07, "far"]],
	3: [["shield", 0.16, "ground"], ["sniper", 0.07, "far"]],
}

func _chapter_men(cast: Array) -> Array:
	var plan: Array = CHAPTER_MEN.get(chapter, [])
	if plan.is_empty() or diff_step < 0:
		return cast
	var acc := {}
	var made := {}
	for p in plan:
		acc[p[0]] = 0.5
		made[p[0]] = 0
	var grow := 1.0 + map * 0.12
	for spec in cast:
		if String(spec["kind"]) != "post":
			continue
		var high: bool = float(spec["y"]) < -1.0
		var runner: bool = spec["run"]
		for p in plan:
			var kind: String = p[0]
			var where: String = p[2]
			if where == "ground" and (high or runner):
				continue
			if where == "high" and not high and runner:
				continue
			if where == "far" and runner:
				continue
			acc[kind] = float(acc[kind]) + float(p[1]) * grow * (2.0 if where == "high" and high else 1.0)
			if float(acc[kind]) >= 1.0 and float(spec["x"]) > 3200.0:
				acc[kind] = float(acc[kind]) - 1.0
				spec["kind"] = kind
				made[kind] = int(made[kind]) + 1
				break
	return cast


func _print_curve() -> void:
	for c in Levels.CAMPAIGN.size():
		var ch: Dictionary = Levels.CAMPAIGN[c]
		if not ch["ready"]:
			continue
		for m in (ch["maps"] as Array).size():
			chapter = c
			map = m
			level = ch["maps"][m]
			rooms = level["rooms"]
			_set_difficulty(String(ch["hero"]))
			var cast := _cast(level["enemies"])
			var kinds := {}
			for e in cast:
				kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
			var drawn_x := []
			for e in level["enemies"]:
				drawn_x.append(float(e["x"]))
			var added := []
			for e in cast:
				if not float(e["x"]) in drawn_x:
					added.append(int(e["x"]))
			if not added.is_empty():
				print("CURVE   partners at ", added)
			print("CURVE step %2d %-15s drawn %2d -> %2d %s  hero hp %d  mob hits %d  aim x%.2f  pause x%.2f  firing %d" % [diff_step, level["name"], (level["enemies"] as Array).size(), cast.size(), str(kinds), max_hp, mob_hp, diff["aim"], diff["pause"], diff["shooters"]])


## Where a second man can stand beside gunman i: on the pavement a few steps further up the street,
## in the same room or out of doors as he is, clear of crates, stairs and every other man. INF = nowhere.
func _partner_spot(specs: Array, i: int) -> float:
	var spec: Dictionary = specs[i]
	if String(spec["kind"]) != "post" or bool(spec["run"]) or absf(float(spec["y"])) > 1.0:
		return INF
	var x0 := float(spec["x"])
	for dx in [260.0, -260.0, 420.0]:
		var x: float = x0 + dx
		if x < 2600.0 or x > float(level["end"]) - 900.0 or _room_at(x) != _room_at(x0):
			continue
		var clear := true
		for b in level["boxes"]:
			if x > float(b[1]) - 140.0 and x < float(b[1]) + float(b[2]) + 140.0:
				clear = false
		for r in level["ramps"]:
			if x > minf(float(r[0]), float(r[2])) - 160.0 and x < maxf(float(r[0]), float(r[2])) + 160.0:
				clear = false
		for other in specs:
			if absf(float(other["x"]) - x) < 180.0 and absf(float(other["y"])) < 1.0:
				clear = false
		if clear:
			return x
	return INF


## Faces for the mobsters: the drawing and where its neck is (x in its pixels). Each kind has its
## own few, and the boss is always Teague, the old boxer.
const MOB_HEADS := {"fedora": 193.5, "homburg": 171.0, "cap": 136.0, "boxer": 144.0}
const MOB_FACES := {"post": ["", "fedora", "cap", "homburg"], "tommy": ["fedora", "homburg"], "shotgun": ["cap", ""], "boss": ["boxer"],
		"hook": ["cap", ""], "dynamite": ["cap"], "sniper": ["fedora", "homburg"], "shade": ["cap"]}

## Eddie Doyle: the detective's body under his own head (art/eddie/head.png, art_src 127): a younger
## face, the pork-pie hat with the press card, the turned-up collar of the pea coat.
func _eddie_cfg() -> Dictionary:
	var c: Dictionary = DETECTIVE.duplicate(true)
	c["head_tex"] = "res://art/eddie/head.png"
	c["parts"]["head"] = {"a": Vector2(210.0, 390.6), "b": Vector2(210.0, 84.0), "ppm": 1100}
	c["short_coat"] = true   # (puppet.gd: no drawn trench-coat flares for him)
	var sk: Dictionary = c["parts"]["skirt"]   # a pea coat stops at the hip: only the top of the coat's drawing
	sk["b"] = Vector2((sk["b"] as Vector2).x, lerpf((sk["a"] as Vector2).y, (sk["b"] as Vector2).y, 0.45))
	return c


## (audit 18. 11.: "shotgunners, tommy gunners and bosses share one silhouette") each kind its own clothes on the same rig
## (gen/outfits.py: art/mobster/<outfit>/ torso, arms, legs): tommy gunners in pale pinstripes and a white tie, shotgunners in
## a dockworker's black leather coat, a bit bigger; the police in navy uniforms (their tommy gunners in plain clothes).
const OUTFIT := {"shade": "docker", "tommy": "torpedo", "shotgun": "docker", "hook": "docker", "dynamite": "docker", "boss": "boss"}   # (bosses: a white dinner jacket)
const COP_OUTFIT := {"post": "patrolman", "shotgun": "patrolman", "sniper": "patrolman", "shield": "patrolman"}
func _mob_cfg(kind: String) -> Dictionary:
	var c: Dictionary = MOBSTER.duplicate(true)
	var cops: bool = level.get("cops", false)
	var outfit: String = String((COP_OUTFIT if cops else OUTFIT).get(kind, ""))
	if outfit != "" and (not _unreal() or kind == "shade"):
		c["base_dir"] = c["dir"]
		c["dir"] = "res://art/mobster/%s/" % outfit
		c["leg_tex"] = "res://art/mobster/%s/leg.png" % outfit
	var face: String = ((COP_FACES if cops else MOB_FACES).get(kind, [""]) as Array).pick_random()
	if kind == "boss":
		face = BOSS_FACES.get(String(level.get("boss", "")), face)
	if cops and COP_HEADS.has(face):
		var cx: float = COP_HEADS[face]
		c["head_tex"] = "res://art/police/heads/%s.png" % face
		c["parts"]["head"] = {"a": Vector2(cx, 334.0), "b": Vector2(cx, 72.0), "ppm": 1000}
	elif face != "":
		var x: float = MOB_HEADS[face]
		c["head_tex"] = "res://art/mobster/heads/%s.png" % face
		c["parts"]["head"] = {"a": Vector2(x, 351.5), "b": Vector2(x, 75.6), "ppm": 1000}
	return c


## One mobster of any kind. state: post (stands and fights), wait (off-screen until his mark), run.
func _add_enemy(at: Vector2, kind: String, state: String, goal_x: float) -> Dictionary:
	if level.get("dream", false) and kind != "boss":
		kind = "shade"   # (user 18. 11.) in the dream no gunmen: the dock workers who burned in there (_shade)
	var m = PuppetScript.new()
	m.cfg = _mob_cfg(kind)
	m.night = _undo_night(1.0)
	m.position = at
	m.modulate = ENEMY_TINT.get(kind, Color(1, 1, 1)) * (COP_TINT if level.get("cops", false) else Color.WHITE)
	if _unreal():   # the men who set the fire, as he dreams them: shadows with the fire behind them
		m.modulate = Color(0.2, 0.15, 0.14)
	if kind == "shade":   # a burned man: pitch dark, a little see-through, smoke coming off him
		m.modulate = Color(0.05, 0.045, 0.045, 0.9)
	add_child(m)
	if kind == "boss":
		m.size = 1.15
	elif kind == "shotgun" and not level.get("cops", false):
		m.size = 1.07   # (the bruiser: a head over the others)
	var briggs: bool = kind == "boss" and String(level.get("boss", "")) == "briggs"
	m.set_weapon("shotgun" if briggs else {"tommy": "tommy", "shotgun": "shotgun", "boss": "pistols", "sniper": "rifle", "hook": "hook", "dynamite": "dynamite"}.get(kind, "pistol"))
	if briggs or kind == "shield":
		_add_shield(m, kind == "shield")
	if kind == "shade":
		m.set_meta("shade", true)
		m.disarmed = true   # empty hands, reaching for him
		_shade_body(m)
	m.set_state(0.0, Vector2(-1.0, 0.0), 0.0)
	m.visible = state != "wait"
	var e := {"node": m, "type": kind, "hp": BOSS_HP if kind == "boss" else mob_hp, "cool": randf_range(0.8, 1.6), "aim_off": 0.0,
			"alive": true, "seen": state == "run", "cover": false if state != "post" else _has_cover(at), "up": false, "shot": false,
			"timer": randf_range(0.5, 1.5), "state": state, "goal": goal_x, "trig": -1.0, "delay": 0.0, "boss": kind == "boss", "calls": 0,
			"id": enemies.size(), "role": {"tommy": "suppress", "shotgun": "rush", "boss": "boss", "hook": "rush", "shade": "rush"}.get(kind, "post"), "notice": -1.0}
	if kind == "shade":
		e["sought"] = true   # (no cover for the dead)
		e["blink"] = randf_range(1.5, 3.0)
	if briggs or kind == "shield":   # a steel shield on his arm, turned toward wherever the detective was a moment ago
		e["shield"] = -1.0
		e["shells"] = 5
		e["reload_t"] = 0.0
	if kind != "boss":
		e["name"] = _new_name()
		e["voice"] = Barks.VOICES[randi() % Barks.VOICES.size()]
	enemies.append(e)
	return e


## A riveted steel shield with a slit to look through, carried on the front arm (the drawing from
## art_src/99). A police shield carries a flashlight clipped beside the slit: it finds Frank in the dark.
func _add_shield(m, lamp := false) -> void:
	var plate := Sprite2D.new()
	plate.texture = load("res://art/guns/riot_shield.png")
	plate.scale = Vector2.ONE * (230.0 / plate.texture.get_height())   # chest to knee
	plate.position = Vector2(96.0, -200.0)
	plate.name = "Shield"
	plate.modulate = Color(0.42, 0.43, 0.46)   # dull steel in the dark, not a sheet of paper
	m.add_child(plate)
	if lamp:
		var torch := Sprite2D.new()
		torch.texture = load("res://art/guns/flashlight.png")
		torch.scale = Vector2.ONE * (72.0 / torch.texture.get_width())
		torch.position = Vector2(132.0, -322.0)   # clipped on the top edge of the shield
		torch.modulate = Color(0.5, 0.5, 0.52)
		torch.name = "Torch"
		m.add_child(torch)
		var beam := PointLight2D.new()   # the beam from the lens, along the way he faces
		beam.texture = load("res://art/light_cone_soft.png")
		beam.rotation = -PI * 0.5
		beam.position = Vector2(168.0, -322.0)
		beam.offset = Vector2(0.0, beam.texture.get_height() * 0.5)   # the cone's tip at the lens
		beam.texture_scale = 2.2
		beam.energy = 1.4
		beam.color = Color(1.0, 0.92, 0.75)
		beam.height = 140.0
		beam.range_item_cull_mask = MASK_LIT
		beam.name = "Beam"
		var lens := Sprite2D.new()   # the lens itself, lit
		lens.texture = _soft_glow()
		lens.scale = Vector2.ONE * 0.12
		lens.position = Vector2(168.0, -322.0)
		lens.material = _unshaded()
		lens.modulate = _undo_night(1.0) * Color(1.0, 0.92, 0.75)
		m.add_child(lens)
		m.add_child(beam)


## Briggs's shield is between his chest and anything fired from the side it faces; not his head, and
## not while he has it down to thumb shells into the gun.
func _shield_stops(e: Dictionary, part: String) -> bool:
	if not e.has("shield") or e.get("shield_off", false) or part == "head" or float(e["reload_t"]) > 0.0:
		return false
	return signf(player.position.x - e["node"].position.x) * float(e["shield"]) > 0.2


## The burning warehouse of the dream (2026-11-15): where each drawing's painted fire burns, as
## [x, foot y, height, width] in shares of the drawing (gen/process_fire.py found them). Hand-inked
## flames (art/fx/fire, art_src 134) burn over them, swaying in a heat shimmer, so the painting moves.
const FIRE_SPOTS := {
	"fire_a": [[0.299, 0.716, 0.257, 0.256], [0.771, 0.715, 0.194, 0.192], [0.626, 0.826, 0.156, 0.133], [0.106, 0.447, 0.199, 0.084],
		[0.929, 0.497, 0.141, 0.093], [0.691, 0.285, 0.082, 0.137], [0.218, 0.233, 0.105, 0.057]],
	"fire_b": [[0.673, 0.895, 0.477, 0.234], [0.803, 0.591, 0.466, 0.289], [0.271, 0.747, 0.34, 0.209, false], [0.922, 0.898, 0.125, 0.109],
		[0.542, 0.866, 0.212, 0.081], [0.106, 0.441, 0.194, 0.084], [0.405, 0.458, 0.126, 0.058], [0.218, 0.242, 0.112, 0.058]],
	"fire_c": [[0.307, 0.84, 0.375, 0.266], [0.768, 0.762, 0.198, 0.19], [0.929, 0.901, 0.147, 0.094], [0.105, 0.443, 0.195, 0.085],
		[0.675, 0.286, 0.099, 0.137], [0.929, 0.493, 0.135, 0.093], [0.218, 0.24, 0.108, 0.057]],
	# the rooms gone wrong (gen/process_dream.py); fires on a beam, a stair or the flying front page stay painted
	# (18. 11.: fire_d's two big fires burn behind the painted huddled people - in front of them they set their heads alight)
	"fire_d": [[0.711, 0.891, 0.362, 0.326, false], [0.302, 0.721, 0.262, 0.251, false], [0.105, 0.448, 0.2, 0.085], [0.93, 0.501, 0.143, 0.092],
		[0.084, 0.752, 0.184, 0.044], [0.692, 0.283, 0.093, 0.138], [0.225, 0.242, 0.117, 0.072]],
	"fire_e": [[0.785, 0.638, 0.513, 0.328, false], [0.694, 0.893, 0.468, 0.193], [0.262, 0.79, 0.357, 0.193], [0.922, 0.897, 0.134, 0.108],
		[0.105, 0.445, 0.197, 0.085], [0.536, 0.875, 0.166, 0.092], [0.349, 0.632, 0.128, 0.061, false]],
	"fire_f": [[0.326, 0.839, 0.378, 0.252], [0.769, 0.766, 0.214, 0.199], [0.927, 0.9, 0.142, 0.098], [0.105, 0.449, 0.201, 0.085],
		[0.524, 0.608, 0.313, 0.055, false], [0.726, 0.277, 0.21, 0.067], [0.935, 0.502, 0.144, 0.081]],
	"fire_g": [[0.525, 0.701, 0.53, 0.258, false], [0.923, 0.898, 0.134, 0.106], [0.867, 0.541, 0.273, 0.143], [0.102, 0.44, 0.19, 0.079],
		[0.327, 0.936, 0.133, 0.149], [0.725, 0.319, 0.184, 0.121], [0.745, 0.895, 0.177, 0.103], [0.55, 0.876, 0.174, 0.116]],
}
var _dream_fires: Array = []   # where the fires stand: the building groans and gives way near them
var _dream_soot: Array = []   # the tops of the biggest fires, where their smoke starts
var _dream_event_t := 3.0
var _dream_music_on := false
var _fire_glows: Array = []   # [sprite, phase]: the painted fire's glow layers, breathing
var _fire_lights: Array = []  # [PointLight2D, base energy, phase]: firelight on the people in front of it


func _fire_life(w: Sprite2D, glow: Sprite2D, seg_name: String, ws: float) -> void:
	_fire_glows.append([glow, randf() * 10.0])
	glow.modulate = _undo_night(0.75)
	var size: Vector2 = Vector2(w.texture.get_size()) * ws
	var k := 0
	for spot in FIRE_SPOTS.get(seg_name, []):
		if float(spot[1]) < 0.6 or (spot.size() > 4 and not spot[4]):   # fires up in the roof stay painted: a loose flame up there floats
			continue
		var foot := w.position + Vector2(float(spot[0]) * size.x, float(spot[1]) * size.y)
		var hgt: float = float(spot[2]) * size.y
		var wid: float = float(spot[3]) * size.x
		var n := clampi(int(wid / 260.0) + 1, 1, 3)   # a wide fire is a few flames side by side
		for j in n:   # overlapping, of different heights, the tallest in the middle: one fire, not a row of candles
			var mid: float = 1.0 - absf(float(j) - (n - 1) * 0.5) / maxf(1.0, n * 0.5)
			_flame(foot + Vector2((float(j) - (n - 1) * 0.5) * wid / float(n) * 0.7 + randf_range(-20.0, 20.0), 14.0),
				hgt * randf_range(0.6, 0.8) * (0.75 + mid * 0.45), k * 7 + j * 3, -9)
		if k < 3 and hgt > 150.0:
			_dream_soot.append(foot + Vector2(0.0, -hgt * 0.9))
		if k < 3 and hgt > 150.0:   # the biggest fires light whoever stands in front of them
			var l := PointLight2D.new()
			l.texture = _soft_glow()
			l.texture_scale = 7.0
			l.color = Color(1.0, 0.55, 0.22)
			l.energy = 1.1
			l.position = foot + Vector2(0.0, -hgt * 0.4)
			l.height = 120.0
			l.range_item_cull_mask = MASK_LIT
			add_child(l)
			_fire_lights.append([l, 1.1, randf() * 10.0])
		sfx.add_loop("fire", foot.x, -20.0, 1300.0, foot.y)   # crackle and roar where it burns (Artlist: Barney Oram - Flames)
		_dream_fires.append(foot)
		k += 1


## The dream burns nearer than the paintings (2026-11-15): flames along the boards in front of him,
## low enough to keep the men's guns and hands in sight, and soot rising from the big fires.
func _dream_vfx() -> void:
	var end: float = float(level.get("end", 20000.0))
	var x := 700.0
	var k := 0
	while x < end + 1500.0:
		# (chapter I audit 18. 11.: men behind them vanished) knee high: the fire is near, the men's bodies stay in sight
		# (18. 11.: they stood 190 px down in the black under the boards - rule 22, a flame burns on a drawn floor) on the
		# front edge of the boards, knee high
		var f := _flame(Vector2(x, 22.0), randf_range(150.0, 185.0), k * 5, 7)
		f.modulate = _undo_night(0.3) * Color(1.0, 0.85, 0.75, 0.85)
		if k % 2 == 0:   # and a lower one leaning in beside it, so it is a fire and not a candle
			var f2 := _flame(Vector2(x + randf_range(110.0, 190.0), 26.0), randf_range(105.0, 135.0), k * 5 + 2, 7)
			f2.modulate.a = 0.85
		x += randf_range(900.0, 1500.0)
		k += 1
	for sp in _dream_soot:
		_soot(sp as Vector2)


func _soot(top: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/puff%d.png" % (randi() % 4 + 1))
	p.amount = 7
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.position = top   # from the tips of the flames up into the roof, not over the fire itself
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(90.0, 30.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 25.0
	p.gravity = Vector2(14.0, -30.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -10.0
	p.angular_velocity_max = 10.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 2.2))
	p.scale_amount_curve = grow
	p.scale_amount_min = 1.6
	p.scale_amount_max = 2.6
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.05, 0.05, 0.0))
	g.add_point(0.2, Color(0.07, 0.06, 0.06, 0.6))
	g.add_point(0.7, Color(0.1, 0.09, 0.09, 0.4))
	g.set_color(g.get_point_count() - 1, Color(0.12, 0.12, 0.12, 0.0))
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # soot: the firelight does not turn it white
	p.material = mat
	p.z_index = -8
	add_child(p)


## One hand-inked flame standing at `foot`, `hgt` tall.
func _flame(foot: Vector2, hgt: float, variant: int, z: int) -> Sprite2D:
	# a hand-drawn flame, eight drawings of it played in a loop (art/fx/fire/anim.png), each fire on
	# its own beat and its own speed so no two neighbours flicker together
	if _flame_mat == null:
		_flame_mat = CanvasItemMaterial.new()
		_flame_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # fire is its own light
	var f := Sprite2D.new()
	f.texture = load("res://art/fx/fire/anim.png")
	f.hframes = FLAME_FRAMES
	f.frame = (variant + randi()) % FLAME_FRAMES
	f.centered = false
	var fw: float = f.texture.get_width() / float(FLAME_FRAMES)
	var fh: float = f.texture.get_height()
	f.offset = Vector2(-fw * 0.5, -fh)
	var sc: float = hgt / fh
	f.scale = Vector2(sc * randf_range(0.9, 1.1) * (1.0 if randf() < 0.5 else -1.0), sc)
	f.position = foot
	f.material = _flame_mat
	f.modulate = _undo_night(0.42)   # the drawing as painted: brighter and its ink and reds burn out to white
	f.z_index = z
	f.set_meta("fps", randf_range(10.0, 14.0))
	f.set_meta("t", randf())
	add_child(f)
	_flames.append(f)
	var tw := f.create_tween().set_loops()   # and the whole fire gathers and leaps, slowly
	var s0 := f.scale
	tw.tween_property(f, "scale", s0 * Vector2(0.96, 1.07), randf_range(0.5, 0.8)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(f, "scale", s0 * Vector2(1.03, 0.94), randf_range(0.45, 0.75)).set_trans(Tween.TRANS_SINE)
	return f


func _tick_flames(delta: float) -> void:
	var i := 0
	while i < _flames.size():
		if not is_instance_valid(_flames[i]):   # a blaze burned out and took its flames with it
			_flames.remove_at(i)
			continue
		var f: Sprite2D = _flames[i]
		var t: float = float(f.get_meta("t")) + delta * float(f.get_meta("fps"))
		if t >= 1.0:
			t -= 1.0
			# mostly the next drawing; now and then one skipped, so the loop never reads as a loop
			f.frame = (f.frame + (2 if randf() < 0.18 else 1)) % FLAME_FRAMES
		f.set_meta("t", t)
		i += 1


## The fire gets him: a hit, the screen jolts, a grunt. Not in the tests (the bot does not jump fires).
func _burn_player(hits: int) -> void:
	if over or cleared or _grace > 0.0 or _auto != "":
		return
	hp -= hits
	stats["hits"] += 1
	hud.set_health(float(hp) / max_hp)
	_shake = maxf(_shake, 0.25)
	sfx.play("hit_flesh", -2.0, INF, 0.1)
	if hp == 1:
		_inner_voice()
	if hp <= 0:
		_player_down()


func _tick_fire(t: float) -> void:
	for g in _fire_glows:
		(g[0] as Sprite2D).modulate.a = 0.8 + 0.2 * sin(t * 7.0 + g[1]) * sin(t * 3.1 + g[1] * 2.0)
	for l in _fire_lights:
		(l[0] as PointLight2D).energy = float(l[1]) * (0.78 + 0.22 * sin(t * 9.0 + l[2]) * sin(t * 4.3 + l[2] * 1.7))


## An interior seen only from inside (user 17. 11., rule 25: "I can't go from a window into an open alley" -
## a room pasted on the street beside other houses, a dark hole between them, was rejected). From the street
## nothing of it shows: the street drawing runs on. Stepping in is a dip through black, and inside the street
## round it is black (walls): its men, crates and lamps are seen only from in there (`_tick_rooms`).
var _left_room := -1   # the interior he was last in (its men may follow him out)
var _room_art: Array = []   # [x0, x1, holder] per interior (not the storeys of a building in cross-section)
func _build_room(x0: float, x1: float, style: String) -> void:
	var first := get_child_count()
	_build_room_art(x0, x1, style)
	var holder := Node2D.new()
	holder.visible = false
	var made: Array = get_children().slice(first)
	add_child(holder)
	for n in made:
		(n as Node).reparent(holder)
	for side in [Rect2(x0 - 8000.0, -6000.0, 8000.0, 12000.0), Rect2(x1, -6000.0, 8000.0, 12000.0)]:   # the walls: nothing outside is seen
		var cover := Polygon2D.new()
		var r: Rect2 = side
		cover.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		cover.color = Color(0.0, 0.0, 0.0, 1.0)
		cover.z_index = 9
		holder.add_child(cover)
	_room_art.append([x0, x1, holder])


## Inside an interior the camera never looks past its ends (user 18. 11.: the laundry's end showed as a black
## band, a man at the wall cut in half by it): the picture stops at the room's walls, the drawing fills the screen.
var _cam_room := -1
var _drop_k := -1
var _bot_lad = null   # the test bot: the ladder it was heading for last frame   # --test=sheets --drop: the shot fired last
func _room_cam_x(x: float) -> float:
	var i := _plain_room_at(player.position)
	if i < 0 or _section_at(player.position) >= 0:
		return x
	var half: float = get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x + 30.0   # (+ the tilt and shake)
	var x0: float = float(_room_art[i][0]) + half
	var x1: float = float(_room_art[i][1]) - half
	if x0 > x1:
		return (x0 + x1) * 0.5
	return clampf(x, x0, x1)


## Up on an interior's catwalk the camera never looks over the top of the drawing (user 18. 11.: a black band
## over the laundry's roof trusses): it stops where the drawing's top meets the screen's.
func _room_cam_y(y: float) -> float:
	var i := _plain_room_at(player.position)
	if i < 0 or _section_at(player.position) >= 0:
		return y
	var x0 := float(_room_art[i][0])
	for t in _room_tops:
		if absf(float(t[0]) - x0) < 1.0:
			var half: float = get_viewport().get_visible_rect().size.y * 0.5 / cam.zoom.y
			return maxf(y, float(t[2]) + half - 10.0)
	return y


## Which interior (index into _room_art) a point is in, or -1 out in the street.
func _plain_room_at(p: Vector2) -> int:
	if p.y <= GROUND_STOREY:
		return -1
	for i in _room_art.size():
		var r1 := float(_room_art[i][1])
		if r1 > level_end:   # (the map ends in this room - the boss's: there is no going out the back of it)
			r1 = INF
		if p.x > float(_room_art[i][0]) and p.x < r1:
			return i
	return -1


## Inside an interior only it is seen; from the street nothing of it (its men and things hidden with it).
func _tick_rooms() -> void:
	if _room_art.is_empty():
		return
	var here := _plain_room_at(player.position)
	for i in _room_art.size():
		(_room_art[i][2] as Node2D).visible = i == here
	if here >= 0:
		_left_room = here
	elif _left_room >= 0 and not over:   # he walked out with men still in there: they come out after him, through the door on his side
		for e in enemies:
			if not e["alive"] or e["state"] != "post" or e.get("followed", false) or e["node"].position.y != 0.0:
				continue
			var ri := _plain_room_at(e["node"].position)
			if ri != _left_room:
				continue
			var a := float(_room_art[ri][0])
			var b := float(_room_art[ri][1])
			if player.position.x > b and player.position.x < b + 1500.0 or player.position.x < a and player.position.x > a - 1500.0:
				e["followed"] = true
				e["goal"] = b + 260.0 if player.position.x > b else a - 260.0
				e["state"] = "move"
				e["to_cover"] = true
	for e in enemies:   # (only what this hid is shown again: other things hide men for their own reasons)
		if e["state"] == "wait" or _section_at(e["node"].position) >= 0:
			continue
		var apart := _plain_room_at(e["node"].position) != here
		if apart and e["node"].visible:
			e["node"].visible = false
			e["room_hid"] = true
		elif not apart and e.get("room_hid", false):
			e["node"].visible = true
			e["room_hid"] = false
	for bi in box_info.size():
		var spr = box_info[bi]["sprite"]
		if spr != null and is_instance_valid(spr):
			(spr as CanvasItem).visible = _plain_room_at(boxes[bi].get_center()) == here
	for pk in pickups:
		if pk.has("node") and is_instance_valid(pk["node"]):
			(pk["node"] as CanvasItem).visible = _plain_room_at(pk["node"].position + Vector2(0.0, 60.0)) == here
	if mapfx:   # the laundry's sheets on their line belong to the room
		for sh in mapfx._sheets:
			var r: Rect2 = sh["rect"]
			(sh["node"] as CanvasItem).visible = _plain_room_at(Vector2(r.get_center().x, -100.0)) == here
			for bit in sh.get("bits", []):   # cloth shot down onto the floor: part of the room too
				if is_instance_valid(bit):
					(bit as CanvasItem).visible = (sh["node"] as CanvasItem).visible


func _build_room_art(x0: float, x1: float, style: String) -> void:
	var rs: float = ROOM_SCALES.get(style, ROOM_SCALE)   # (the laundry hall is drawn bigger: shown at full size)
	var sky_top := -4200.0   # the dark over a room reaches up out of the picture; under the roofs only to their cornice
	if not roof.is_empty():
		var pics: Array = roof["pics"]
		if x1 > float(pics[0][1]) and x0 < float(pics[pics.size() - 1][1]) + 3200.0:
			sky_top = float(roof["y"]) + 200.0
	var tex: Texture2D = BigTex.get_tex("res://art/rooms/" + style + ".png")
	var wall := Sprite2D.new()
	wall.texture = tex
	wall.centered = false
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.region_enabled = true
	# The interiors were drawn close up: at the street's scale a door in them came out three men tall.
	# At rs a door is a head taller than him; above the drawing a dark ceiling.
	# A room wider than its drawing never repeats it (that would put the drawing's end walls halfway along
	# the room, the user's rule 16. 11.): the drawing sits in the middle and the extra at each end is the
	# dark the hallway runs on into.
	var src_w := minf((x1 - x0) / rs, tex.get_width())
	var pad := maxf(0.0, ((x1 - x0) - tex.get_width() * rs) * 0.5)
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	wall.region_rect = Rect2(maxf(0.0, (tex.get_width() - src_w) * 0.5), 0.0, src_w, tex.get_height())
	wall.scale = Vector2.ONE * rs
	var top := -tex.get_height() * rs * SEGMENT_BASE
	wall.position = Vector2(x0 + pad, top)
	wall.z_index = -5
	# The painting already has its lamps' light in it: it takes no lamplight of its own (one big
	# drawing redrawn once per light cost the phone its frame rate). It sits dim, and each painted
	# lamp lays a soft pool on it (below) that goes dark when the bulb is shot out.
	wall.light_mask = 0
	wall.modulate = Color.WHITE * ROOM_BASE
	add_child(wall)
	# A hall drawn in parts (ROOM_PARTS - the big laundry, QUEUE §14): the drawings one after another, each cut on a
	# painted iron column; a part's catwalk is its own layer a little in front of the wall, with its shadow (rule 27)
	var bulb_list: Array = []   # [world point, colour, size] of every painted lamp
	var parts: Array = ROOM_PARTS.get(style, []) if (x1 - x0) > tex.get_width() * rs + 10.0 else []
	if not parts.is_empty():
		pad = 0.0
		wall.visible = false   # (every part, the first too, is laid by the loop: the first need not be the style's own drawing)
		src_w = 0.0
		var ox := x0
		for k in range(parts.size()):
			var pt: Array = parts[k]
			var a := float(pt[1])
			var pw := float(pt[2]) - a
			var ptex: Texture2D = BigTex.get_tex("res://art/rooms/%s.png" % pt[0])
			for layer in ([""] if String(pt[3]) == "" else ["", String(pt[3])]):
				var lt: Texture2D = ptex if layer == "" else BigTex.get_tex("res://art/rooms/%s.png" % layer)
				if layer != "":   # the catwalk's shadow on the wall behind it, a step down and to the right
					var sh := Sprite2D.new()
					sh.texture = lt
					sh.centered = false
					sh.region_enabled = true
					sh.region_rect = Rect2(a, 0.0, pw, lt.get_height())
					sh.scale = Vector2.ONE * rs
					sh.position = Vector2(ox + 9.0, top + 14.0)
					sh.modulate = Color(0.0, 0.0, 0.0, 0.42)
					sh.light_mask = 0
					sh.z_index = -5
					add_child(sh)
				var ps := Sprite2D.new()
				ps.texture = lt
				ps.centered = false
				ps.region_enabled = true
				ps.region_rect = Rect2(a, 0.0, pw, lt.get_height())
				ps.scale = Vector2.ONE * rs
				ps.position = Vector2(ox, top)
				ps.light_mask = 0
				ps.modulate = Color.WHITE * ROOM_BASE * (1.06 if layer != "" else 1.0)   # (the iron in front catches a little more light)
				ps.z_index = -5
				add_child(ps)
			if String(pt[0]) == "club_hall":   # the chandelier over the dance floor: its own layer, it can be shot down
				_chandelier(Vector2(ox + (CHANDELIER_BOX.position.x - a) * rs, top + CHANDELIER_BOX.position.y * rs), rs)
			var own: Array = ROOM_BULBS.get(String(pt[0]), []) if String(pt[0]) == style else ROOM_PART_BULBS.get(String(pt[0]), [])
			var own_v: Array = ROOM_VENTS.get(String(pt[0]), []) if String(pt[0]) == style else ROOM_PART_VENTS.get(String(pt[0]), [])
			for b in own:
				var bx: float = float(b[0]) * ptex.get_width()
				if bx > a + 30.0 and bx < a + pw - 30.0:
					bulb_list.append([Vector2(ox + (bx - a) * rs, top + float(b[1]) * ptex.get_height() * rs), String(b[2]), String(b[3])])
			for v: Vector2 in own_v:
				room_vents.append([x0, x1, Vector2(ox + (v.x * ptex.get_width() - a) * rs, top + v.y * ptex.get_height() * rs)])
			ox += pw * rs
	var roof := Polygon2D.new()   # above the ceiling: the storeys over the room, the facade seen dim through the cut
	roof.polygon = PackedVector2Array([Vector2(x0, sky_top), Vector2(x1, sky_top), Vector2(x1, top + 2.0), Vector2(x0, top + 2.0)])
	roof.color = Color(0.0, 0.0, 0.0, 1.0)   # (only seen from inside: above the ceiling the floors over it, dark)
	roof.z_index = 9
	add_child(roof)
	var fade := Polygon2D.new()   # the top of the drawing dissolves into the dark ceiling, no hard edge
	fade.polygon = PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, top + 260.0), Vector2(x0, top + 260.0)])
	fade.vertex_colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 1), Color(0, 0, 0, 0), Color(0, 0, 0, 0)])
	fade.z_index = -4
	add_child(fade)
	_room_tops.append([x0, x1, top])
	var veil := Polygon2D.new()   # from down the street the inside is dark: it opens up as he comes to the door
	veil.polygon = PackedVector2Array([Vector2(x0, top), Vector2(x1, top), Vector2(x1, 40.0), Vector2(x0, 40.0)])
	veil.color = Color(0, 0, 0, 1)
	veil.z_index = 8
	add_child(veil)
	_veils.append([x0, x1, veil])
	# Each end of the room goes off into darkness, the way a hallway runs on past the lamp: no drawn
	# door frame stuck on the picture, and the street beyond is not seen through the wall.
	for side: float in [-1.0, 1.0]:
		var x: float = x1 if side > 0.0 else x0
		var dark := Polygon2D.new()
		var edge: float = x - side * pad   # past the drawing's end: all dark
		if pad > 0.0:
			var solid := Polygon2D.new()
			solid.polygon = PackedVector2Array([Vector2(edge, top), Vector2(x, top), Vector2(x, 40.0), Vector2(edge, 40.0)])
			solid.color = Color(0, 0, 0, 1)
			solid.z_index = -4
			add_child(solid)
		var inner: float = edge - side * 340.0
		dark.polygon = PackedVector2Array([Vector2(inner, top), Vector2(edge, top), Vector2(edge, 40.0), Vector2(inner, 40.0)])
		dark.vertex_colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 1), Color(0, 0, 0, 1), Color(0, 0, 0, 0)])
		dark.z_index = -4
		add_child(dark)
		var out_x: float = x + side * 460.0   # outside, the street sinks into the building's shadow: no hard edge
		var shade := Polygon2D.new()
		shade.polygon = PackedVector2Array([Vector2(x, sky_top), Vector2(out_x, sky_top), Vector2(out_x, 40.0), Vector2(x, 40.0)])
		shade.vertex_colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)])
		shade.z_index = -4
		add_child(shade)
		var wall_side := Polygon2D.new()   # the outside wall of the building, cut away above the door
		wall_side.polygon = PackedVector2Array([Vector2(-60, -560), Vector2(60, -560), Vector2(60, maxf(-3200.0, sky_top)), Vector2(-60, maxf(-3200.0, sky_top))])
		wall_side.color = Color(0.0, 0.0, 0.0)
		wall_side.position = Vector2(x, 0.0)
		wall_side.z_index = 9
		add_child(wall_side)
	# the painted lamps: a soft glow on each bulb and its light on whoever stands under it
	var crop_x := maxf(0.0, (tex.get_width() - src_w) * 0.5)
	for pd in ROOM_PENDANTS.get(style, []):   # lamps hung from the painting's ceiling beam: they swing
		var px: float = x0 + pad + (float(pd[0]) * tex.get_width() - crop_x) * rs
		if px < x0 + 200.0 or px > x1 - 200.0:
			continue
		var hook: float = top + float(pd[1]) * tex.get_height() * rs
		var at := Vector2(px, top + float(pd[2]) * tex.get_height() * rs)
		var pend := _pendant(at, hook)
		lamps.append(at + Vector2(0.0, 8.0))
		var plight := _lamp_light(at + Vector2(0.0, -8.0))
		plight.reparent(pend["node"])
		lamp_info.append({"nodes": [pend["bulb"]], "light": plight, "on": true, "glass": -6.0, "r": 34.0, "pend": pend})
		pend["lamp"] = lamps.size() - 1
		_swingers.append(pend)
	for b in (ROOM_BULBS.get(style, []) if parts.is_empty() else []):
		var bat := Vector2(x0 + pad + (float(b[0]) * tex.get_width() - crop_x) * rs, top + float(b[1]) * tex.get_height() * rs)
		bulb_list.insert(0, [bat, String(b[2]), String(b[3])])
	for v: Vector2 in (ROOM_VENTS.get(style, []) if parts.is_empty() else []):   # the steam pipes painted in the drawing (mapfx _tick_room_vents)
		room_vents.append([x0, x1, Vector2(x0 + pad + (v.x * tex.get_width() - crop_x) * rs, top + v.y * tex.get_height() * rs)])
	for b in bulb_list:
		var at: Vector2 = b[0]
		if at.x < x0 + 60.0 or at.x > x1 - 60.0:
			continue
		var col: Color = BULB_COLORS.get(String(b[1]), BULB_COLORS["warm"])
		var sky: bool = String(b[1]) == "sky"
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		var nodes: Array = []
		var pool := Sprite2D.new()   # the pool of light on the painted room round the lamp
		pool.texture = _soft_glow()
		pool.position = at + Vector2(0.0, 110.0)   # spreading from the bulb itself, falling off down the wall
		var low: bool = String(b[2]) == "small"   # a table lamp or a lantern lights its corner, a ceiling lamp the room
		pool.scale = (Vector2(1.7, 1.6) if low else Vector2(2.8, 2.9)) if not sky else Vector2(4.2, 4.0)   # the light the lamp throws, not a halo hung in the air
		pool.material = add
		pool.light_mask = 0
		pool.modulate = _undo_night(0.1 if not sky else 0.045) * col.lerp(Color.WHITE, 0.8)   # warm, not orange
		pool.z_index = -4
		add_child(pool)
		nodes.append(pool)
		if not sky:   # daylight through a skylight has no bulb to glow
			var halo := Sprite2D.new()
			halo.texture = _soft_glow()
			halo.position = at
			halo.scale = Vector2.ONE * (0.32 if String(b[1]) == "candle" else 0.5)   # a warm breath round the bulb, not a white disc
			halo.material = add
			halo.light_mask = 0
			halo.modulate = _undo_night(0.09) * col
			halo.z_index = -4
			add_child(halo)
			nodes.append(halo)
		var p := PointLight2D.new()   # on the people and things in the room only, not on the painting
		p.texture = load("res://art/light_blob.png")
		p.texture_scale = (2.0 if low else 3.4) if not sky else 4.5
		p.position = at + Vector2(0.0, 260.0)
		p.color = col
		p.energy = 0.85 if not sky else 0.45
		p.height = 140.0
		p.range_item_cull_mask = MASK_LIT
		add_child(p)
		if not sky and not String(b[1]) in ["candle", "spot"]:   # (the stage spot keeps its painted beam: not shootable) a bulb can be shot out like any street lamp: the room round it goes dark
			var off := Sprite2D.new()   # the painted bulb itself, dead: an ink shadow over its glow
			off.texture = load("res://art/fx_pool.png")
			off.position = at
			off.scale = Vector2.ONE * (0.4 if low else 0.6)
			off.modulate = Color(1, 1, 1, 0.45)
			off.z_index = -4
			off.visible = false
			add_child(off)
			lamps.append(at)
			lamp_info.append({"nodes": nodes, "light": p, "on": true, "off": off, "r": 30.0 if low else 46.0, "glass": 0.0, "hole": 0.16 if low else 0.26})


## A lamp hanging from an interior's ceiling: cord, enamel shade, the bulb glowing under it.
## A shaded bulb on its cord from the ceiling, in a room big enough for a draught: it swings a little,
## its light swinging with it, and a shot puts the bulb out and jolts it (the swing then dies away).
func _pendant(at: Vector2, hook := NAN) -> Dictionary:
	var ceiling := at.y - 600.0
	for r in _room_tops:
		if at.x >= float(r[0]) and at.x <= float(r[1]):
			ceiling = float(r[2])
	if not is_nan(hook):
		ceiling = hook
	var length: float = at.y - ceiling
	var n := Node2D.new()   # pivots at the ceiling hook
	n.position = Vector2(at.x, ceiling)
	n.z_index = -3
	add_child(n)
	# the lamp (art/props/pendant.png): an enamel shade and its bulb, and the drawing's own cord stretched
	# up to the hook (a plain vertical line: stretching it lengthwise changes nothing in it)
	var tex: Texture2D = load("res://art/props/pendant.png")
	var sc := 0.28
	var bulb_y := 840.0   # the bulb's centre on the drawing
	var shade_top := 520.0
	var shade := Sprite2D.new()
	shade.texture = tex
	shade.centered = false
	shade.region_enabled = true
	shade.region_rect = Rect2(0.0, shade_top, tex.get_width(), tex.get_height() - shade_top)
	shade.scale = Vector2.ONE * sc
	shade.position = Vector2(-tex.get_width() * 0.5 * sc, length - (bulb_y - shade_top) * sc)
	n.add_child(shade)
	var cord := Sprite2D.new()
	cord.texture = tex
	cord.centered = false
	cord.region_enabled = true
	cord.region_rect = Rect2(264.0, 0.0, 30.0, shade_top)
	cord.scale = Vector2(sc, maxf(0.01, (length - (bulb_y - shade_top) * sc) / shade_top))
	cord.position = Vector2(-15.0 * sc, 0.0)
	n.add_child(cord)
	var bulb := Sprite2D.new()
	bulb.texture = load("res://art/light_blob.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	bulb.material = add
	bulb.position = Vector2(0.0, length)
	bulb.scale = Vector2(0.16, 0.16)
	bulb.modulate = _undo_night(0.55) * LAMP_COLOR
	n.add_child(bulb)
	# a pendulum: the longer the cord the slower; a few degrees each way, never two in step
	return {"node": n, "bulb": bulb, "len": length, "amp": deg_to_rad(randf_range(3.0, 6.0)),
			"w": sqrt(980.0 / maxf(length, 100.0)), "phase": randf() * TAU, "kick": 0.0, "damp": 1.0}


## The hanging lamps swing; the bulb's hit point follows the glass.
func _tick_swingers(delta: float) -> void:
	for p in _swingers:
		var n: Node2D = p["node"]
		if not is_instance_valid(n):
			continue
		p["phase"] = float(p["phase"]) + float(p["w"]) * delta
		p["kick"] = float(p["kick"]) * exp(-delta * 0.9)
		var amp: float = float(p["amp"]) * float(p["damp"]) + float(p["kick"])
		n.rotation = sin(float(p["phase"])) * amp
		if p.has("lamp"):
			lamps[int(p["lamp"])] = n.position + Vector2(0.0, float(p["len"]) + 8.0).rotated(n.rotation)


## A landing indoors.
## The rooftops a map climbs to (gen/levels.py roofs): drawn at half the street's scale, the walked line
## of the drawing on roof y, the firewall at the right edge of each left off where the next joins on.
## Their cornice covers the tops of the facades below, and nothing of them shows from the street.
const ROOF_SCALE := 0.95
const ROOF_LINE := 0.828   # the top of the coping in the drawing, as a share of its height
const ROOF_STUB := 190.0   # the firewall at a drawing's right edge, in its pixels
func _build_roofs() -> void:
	if roof.is_empty():
		return
	var pics: Array = roof["pics"]
	for i in pics.size():
		var tex: Texture2D = BigTex.get_tex("res://art/street/" + String(pics[i][0]) + ".png")
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.region_enabled = true
		var k := float(roof.get("scale", ROOF_SCALE))
		var keep := tex.get_width() - (float(roof.get("stub", ROOF_STUB)) if i < pics.size() - 1 else 0.0)
		var ledge := float(roof.get("ledge", 0.0))   # (over kit facades only the top of its stone ledge: their own windows show)
		sp.region_rect = Rect2(0.0, 0.0, keep, tex.get_height() * float(roof.get("line", ROOF_LINE)) + ledge if ledge > 0.0 else tex.get_height())
		sp.scale = Vector2.ONE * k
		sp.position = Vector2(float(pics[i][1]), float(roof["y"]) - tex.get_height() * k * float(roof.get("line", ROOF_LINE)))
		sp.z_index = -8   # over the facades' own glow (a lit sign at the top of a wall would shine through)
		sp.material = atmo.blur_material(1.4)
		sp.modulate = Color.WHITE * SEGMENT_MOON * 0.95
		add_child(sp)
		if String(pics[i][0]) == "roof_a" and props:   # its water tower's tank: its own layer, it can be shot (QUEUE §15 H)
			var tx := float(pics[i][1]) + 950.0 * k
			if tx > float(roof["x0"]) and tx < float(roof["x1"]):
				props.place_roof_tank(sp.position + Vector2(950.0, 135.0) * k, k, sp.material, sp.modulate)


## A floor of scaffolding: bays of tubes and planks (art/props/scaffold.png, the deck walked on 735 px
## down the picture), each one storey tall, standing on the deck or the street below.
const SCAF_DECK := 735.0
const SCAF_STEP := 769.0
func _scaffold(r: Rect2) -> void:
	var tex: Texture2D = load("res://art/props/scaffold.png")
	var below := minf(-r.position.y, 520.0)
	var k := below / (tex.get_height() - SCAF_DECK)
	var n := maxi(1, roundi(r.size.x / SCAF_STEP))
	var w := tex.get_width() * k
	for i in n:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.scale = Vector2.ONE * k
		sp.position = Vector2(r.position.x + r.size.x * (i + 0.5) / n - w * 0.5, r.position.y - SCAF_DECK * k)
		sp.z_index = -3
		sp.modulate = Color(0.84, 0.82, 0.79)
		add_child(sp)


## How far the camera rises with him: a little on a landing, and all the way with him up the scaffold,
## so on the roof the roof sits where the pavement does.
## Platform snapping (research ch14, Itay Keren): in the air the camera keeps the height of the floor he jumped from,
## so a hop or a dive in a gunfight does not bob the picture; only past CAM_SNAP above or below it does it follow
## (an awning's throw, a drop off a landing), smoothly, and on landing it settles on the new floor.
const CAM_SNAP := 380.0
## The map's opening (user 17. 11.: "not a ride over the whole map - I don't want to see it before I walk it; a light
## cinematic move in onto the hero that starts a little way from him"): the camera starts a little ahead of him,
## higher and wider, and eases in onto him over INTRO_LEN; he can walk off at once, which hands it straight back.
const INTRO_LEN := 2.4
const INTRO_FROM := Vector2(520.0, -170.0)   # where the camera starts, off him
const INTRO_WIDE := 0.84                     # and how much wider (the zoom eases back by itself)
var _pan_t := 0.0
func _intro_pan() -> void:
	_pan_t = INTRO_LEN
	cam.position = Vector2(player.position.x + _lead, cam.position.y) + INTRO_FROM
	cam.zoom = Vector2.ONE * ZOOM * INTRO_WIDE


## Cue focus (ch14): something that matters (a boss stepping out, a hazard going off, a crate coming down) pulls the
## camera part of the way toward it for a moment, easing in and out: attention without a word of text.
var _cue_at := Vector2.ZERO
var _sky_nodes: Array = []
var _city_far: Array = []   # [sprite, its x, its top y at the street's own scale]
const CITY_FAR_SCALE := 0.5   # how far behind the fronts the old street drawings stand (their size and their speed)
const CITY_FAR_LIFT := 1500.0   # raised so only their upper storeys show over the fronts' roofs
const CITY_FAR_TONE := 0.42
var wide_shot := 0.0   # 0..1, set by mapfx while something big goes by (eased back each frame there)
var _cue_t := 0.0
var _cue_len := 1.0
var _cue_w := 0.0
func cue(at: Vector2, secs: float, weight: float) -> void:
	if _cue_t > 0.0 and weight < _cue_w:
		return
	_cue_at = at
	_cue_t = secs
	_cue_len = secs
	_cue_w = weight
func _snap_y(y: float) -> float:
	if move_state == "ground" or move_state == "climb" or move_state == "stairs":
		return y
	var d := y - _ground_y
	return _ground_y + signf(d) * maxf(0.0, absf(d) - CAM_SNAP)


func _cam_rise(y: float) -> float:
	var low := clampf(y * 0.45, -330.0, 0.0)
	if props and props.near_climb(player.position.x):   # up a street piece's fire escape / off its awning: the camera goes up with him
		low = clampf(y * 0.62, -880.0, 0.0)
	if (roof.is_empty() and not level.has("city")) or y > -600.0:   # (the modular city: up its fire escapes, the camera goes too)
		return low
	return lerpf(low, y, smoothstep(-600.0, -1500.0, y))


## Everyone up on the roof is down (the street below is left behind him).
func _roof_clear() -> bool:
	for e in enemies:
		if e["alive"] and (e["node"].position.y < float(roof["y"]) + 100.0 or e["state"] == "wait"):
			return false
	return true


func _slab(r: Rect2) -> void:
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([r.position + Vector2(0, -6), r.position + Vector2(r.size.x, -6), r.position + Vector2(r.size.x, 34), r.position + Vector2(0, 34)])
	beam.color = Color(0.09, 0.07, 0.06)
	beam.z_index = -3
	add_child(beam)
	var rail := Line2D.new()
	rail.points = PackedVector2Array([r.position + Vector2(0, -110), r.position + Vector2(r.size.x, -110)])
	rail.width = 8.0
	rail.default_color = Color(0.06, 0.05, 0.04)
	rail.z_index = -3
	add_child(rail)
	var x := r.position.x
	while x < r.end.x:
		var post := Line2D.new()
		post.points = PackedVector2Array([Vector2(x, r.position.y), Vector2(x, r.position.y - 110)])
		post.width = 5.0
		post.default_color = Color(0.06, 0.05, 0.04)
		post.z_index = -3
		add_child(post)
		x += 60.0


## The stairs from the platform up to the mezzanine (art/props/station_stairs.png): the treads in the
## drawing run from STAIR_FOOT to STAIR_TOP, scaled so they lie on the line he walks from a to b.
const STAIR_FOOT := Vector2(168.0, 1258.0)
const STAIR_TOP := Vector2(2352.0, 255.0)
func _station_stairs(a: Vector2, b: Vector2) -> void:
	var st := Sprite2D.new()
	st.texture = load("res://art/props/station_stairs.png")
	st.centered = false
	var k := (a.y - b.y) / (STAIR_FOOT.y - STAIR_TOP.y)
	st.scale = Vector2.ONE * k
	st.position = a - STAIR_FOOT * k
	st.z_index = -2
	st.modulate = Color(0.84, 0.82, 0.79)
	add_child(st)
	if _auto != "" and absf((b.x - a.x) - (STAIR_TOP.x - STAIR_FOOT.x) * k) > 3.0:
		print("AUDIT BAD station stairs do not match their drawing: ", a, b)


## A flight of iron stairs from a to b: the stringer and the treads, in ink.
func _stairs(a: Vector2, b: Vector2) -> void:
	var k := absf(b.y - a.y) / 370.0   # a taller storey (a building in cross-section): the same flight, bigger
	var st := Sprite2D.new()   # one storey of iron stairs, its treads along the line he walks
	st.texture = load("res://art/props/iron_flight.png")
	st.centered = false
	st.scale = Vector2.ONE * k
	st.flip_h = b.x < a.x
	st.position = a - IRON_FOOT * k if b.x > a.x else Vector2(a.x - (st.texture.get_width() - IRON_FOOT.x) * k, a.y - IRON_FOOT.y * k)
	st.z_index = -2
	add_child(st)
	if _auto != "" and (absf(absf(b.x - a.x) - 261.0 * k) > 3.0 or absf(absf(b.y - a.y) - 370.0 * k) > 3.0):
		print("AUDIT BAD stairs do not match their drawing: ", a, b)


## What kind of place a spot on the map is: the room it is in, or else the street drawing behind it.
func _place_at(x: float) -> String:
	var room := _room_at(x)
	if room != "":
		return "room:" + room
	var seg := ""
	for sg in level.get("street", []):
		if x >= float(sg[1]):
			seg = String(SEGMENT_KIT.get(String(sg[0]), String(sg[0])))   # a variant is its kit
	return seg


## The interior at a point. A room is [x0, x1, style] on the street's own storey, or [x0, x1, style,
## top, bottom] for one up in a building (the cross-sections, 2026-11-16): rooms stack at the same x,
## so where he stands decides which, and on a roof above a street room he is not indoors.
func _room_at(x: float, y := 0.0) -> String:
	for r in rooms:
		if x > float(r[0]) and x < float(r[1]):
			if (r as Array).size() >= 5:
				if y >= float(r[3]) and y <= float(r[4]):
					return String(r[2])
			elif y > GROUND_STOREY:
				return String(r[2])
	return ""


## Something to pick up: a gun or the flask, bobbing a little so it catches the eye.
func _add_pickup(kind: String, at: Vector2) -> void:
	if not _gun_open(kind):   # a gun from a later chapter: it is not lying about yet
		return
	if kind == "page":
		_add_page(at)
		return
	var s := Sprite2D.new()
	s.texture = load("res://art/items/" + kind + ".png")
	s.scale = Vector2.ONE * (0.5 if kind == "flask" else 0.62)
	s.position = at + Vector2(0.0, -70.0)
	s.modulate = _undo_night(0.95)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	s.z_index = 1
	add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", at.y - 95.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", at.y - 70.0, 0.6).set_trans(Tween.TRANS_SINE)
	pickups.append({"kind": kind, "node": s, "at": at})


## A page of Eddie's notebook, nailed to the wall at a man's chest height where he left it to be
## found: the real page, small, a little crooked, its corner lifting in the draught.
func _add_page(at: Vector2) -> void:
	var holder := Node2D.new()
	# nailed to the wall at chest height, never on a crate or a cabinet: where it would land on one,
	# it moves to the bare wall just before it, where a man walking past reaches it
	for _try in 4:
		var moved := false
		for b in boxes:
			if at.x > b.position.x - 70.0 and at.x < b.end.x + 70.0:
				at.x = b.position.x - 140.0
				moved = true
		if not moved:
			break
	holder.position = Vector2(at.x, at.y - 330.0)
	holder.z_index = -1   # on the wall: people pass in front of it
	add_child(holder)
	var note := "res://art/items/notes/%d_%d.png" % [chapter, map]   # this page small, its own writing and stains
	var tex: Texture2D = load(note if ResourceLoader.exists(note) else "res://art/items/page_note.png")
	var page := Sprite2D.new()
	page.texture = tex
	page.scale = Vector2.ONE * (130.0 / tex.get_width())
	page.offset = Vector2(0.0, tex.get_height() * 0.5 - 12.0)   # hung from the nail near its top edge
	page.rotation = deg_to_rad(randf_range(-9.0, 9.0))
	page.modulate = _undo_night(0.5)   # pale paper: it reads in the dark without a glow round it
	var flat := CanvasItemMaterial.new()
	flat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	page.material = flat
	if MenuScript.has_page(chapter, map) and _auto == "":
		page.modulate.a = 0.45   # read before: still there, for anyone who wants it again
	var shadow := Sprite2D.new()
	shadow.texture = tex
	shadow.scale = page.scale
	shadow.offset = page.offset
	shadow.position = Vector2(5.0, 7.0)
	shadow.rotation = page.rotation
	shadow.modulate = Color(0, 0, 0, 0.45)
	holder.add_child(shadow)
	holder.add_child(page)
	var nail := Sprite2D.new()
	nail.texture = load("res://art/light_blob.png")
	nail.scale = Vector2.ONE * 0.045
	nail.modulate = Color(0.05, 0.05, 0.05)
	holder.add_child(nail)
	var tw := page.create_tween().set_loops()   # the draught lifts it a little and lets it fall back
	var r0 := page.rotation
	tw.tween_property(page, "rotation", r0 + 0.05, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(page, "rotation", r0 - 0.02, 1.6).set_trans(Tween.TRANS_SINE)
	pickups.append({"kind": "page", "node": holder, "at": at, "reach": 160.0})


func _pickups() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pk: Dictionary = pickups[i]
		var s: Node2D = pk["node"]
		var spot: Vector2 = pk["at"]
		if absf(spot.x - player.position.x) > 90.0 or absf(spot.y - player.position.y) > float(pk.get("reach", 160.0)):
			continue
		var kind: String = pk["kind"]
		if kind == "page":
			_read_page()
		elif kind == "flask":
			if hp >= max_hp:
				continue
			hp = mini(max_hp, hp + 2)
			hud.set_health(float(hp) / max_hp)
			sfx.play("drink", 0.0)
			hud.toast("A PULL FROM THE FLASK")
		else:   # into his coat: the gun in his hand stays there; the same gun again is rounds for it
			sfx.play("pickup", 0.0)
			if kind == weapon:
				ammo += int(WEAPONS[kind]["ammo"])
				_show_ammo()
				hud.toast("+%d %s ROUNDS" % [int(WEAPONS[kind]["ammo"]), String(WEAPONS[kind]["name"])])
			elif _bag.has(kind):
				_bag[kind]["ammo"] = int(_bag[kind]["ammo"]) + int(WEAPONS[kind]["ammo"])
				hud.toast("+%d %s ROUNDS" % [int(WEAPONS[kind]["ammo"]), String(WEAPONS[kind]["name"])])
			elif _big_gun() != "":   # one big gun only: this one waits on the ground for a swap
				if _swap_offer != pk:
					_swap_offer = pk
					hud.toast("TAP THE GUN: %s FOR THE %s" % [String(WEAPONS[_big_gun()]["name"]), String(WEAPONS[kind]["name"])])
				continue
			else:
				var total: int = int(pk.get("left", WEAPONS[kind]["ammo"]))   # a gun he put down keeps its rounds
				_bag[kind] = {"mag": mini(total, _mag_size(kind)), "ammo": maxi(0, total - _mag_size(kind))}
				hud.toast("%s TAKEN: TAP THE GUN TO SWITCH" % String(WEAPONS[kind]["name"]))
			_show_guns()
		s.queue_free()
		pickups.remove_at(i)


## A page of Eddie's notebook: the street stops while Frank reads it.
func _read_page() -> void:
	if _auto == "play":   # the test bot does not stop to read
		print("BOT found the page")
		return
	MenuScript.mark_page(chapter, map)
	var d = DiaryScript.new()
	d.text = String(level.get("diary", ""))
	d.paper = "res://art/ui/pages/%d_%d.png" % [chapter, map]
	var pages: Array = Levels.CAMPAIGN[chapter]["maps"].filter(func(mp) -> bool: return String(mp.get("diary", "")) != "")
	d.found = pages.find(Levels.CAMPAIGN[chapter]["maps"][map]) + 1   # this page's place among the chapter's pages (the dream has none: "PAGE 5 OF 6")
	d.total = pages.size()
	d.sound = func(n: String, db: float) -> void: sfx.play(n, db, INF, 0.0)
	d.done = func() -> void:
		hud.modal(false)
		hud.release_all()
	hud.release_all()
	hud.modal(true)
	add_child(d)


## One of the boss's men (or the prologue's endless mob), sent running in from off-screen to `goal`.
func _spawn_runner(from_x: float, goal_x: float, kind := "post") -> void:
	var e := _add_enemy(Vector2(from_x, 0.0), kind, "run", goal_x)
	e["cool"] = 0.6


## The boss fires in bursts of three.
## The glint of a gun coming up to fire: a beat of warning, the time to get out of the way.
func _glint(m) -> void:
	var g := Sprite2D.new()
	g.texture = load("res://art/light_blob.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	g.material = add
	g.modulate = Color(1.0, 0.92, 0.75) * Color(_undo_night(0.9), 1.0)
	g.global_position = m.muzzle()
	g.scale = Vector2.ZERO
	g.z_index = 8
	add_child(g)
	for a in [0.0, PI * 0.5]:   # a four-point star across it
		var l := Line2D.new()
		l.points = PackedVector2Array([Vector2.from_angle(a) * -150.0, Vector2.from_angle(a) * 150.0])
		l.width = 14.0
		l.default_color = Color(1, 1, 1, 0.9)
		g.add_child(l)
	var tw := g.create_tween()
	tw.tween_property(g, "scale", Vector2.ONE * 0.28, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "rotation", 0.8, 0.3)
	tw.tween_property(g, "scale", Vector2.ZERO, 0.2)
	tw.tween_callback(g.queue_free)
	sfx.play("clink", -14.0, m.position.x, 0.2)


## Words over somebody's head: Briggs counting his shells out loud.
## Now and then a man goes down with a sound: a gasp, a groan, his mother. Never on a head shot (he has
## no breath left), never two close together, about one kill in four (barks.gd "death").
func _cry(e: Dictionary, m, head: bool) -> void:
	var voice := String(e.get("voice", ""))
	if voice == "" or head or _unreal() or _ai_t - _cry_t < 6.0 or randf() > 0.28:
		return
	var heard: Array = Barks.LINES["death"].filter(func(l: String): return ResourceLoader.exists(Barks.path(voice, l)) and not _bark_recent.has(l))
	if heard.is_empty():
		return
	var line: String = heard.pick_random()
	_cry_t = _ai_t
	_bark_recent.append(line)
	sfx.cry(Barks.path(voice, line), m.position.x)


## A name for a new man, not yet used on this map.
func _new_name() -> String:
	var free: Array = Barks.NAMES.filter(func(n): return not _names.has(n))
	if free.is_empty():
		_names.clear()
		free = Barks.NAMES.duplicate()
	var n: String = free.pick_random()
	_names.append(n)
	return n


## One of the lines of a kind (barks.gd) over a man's hat. `who` fills {n}; lines that need a name are
## left out when there is none. One voice at a time: a line that is not urgent waits its turn by being
## dropped (they are many; silence is better than a chorus).
func _bark(m, kind: String, who := "", urgent := false) -> void:
	if m == null or _unreal() or _stand:
		return
	for o in enemies:   # the bosses have their own words
		if o["node"] == m and o["boss"]:
			return
	if _ai_t - _bark_t < (0.6 if urgent else 1.6) or _ai_t - float(_bark_at.get(kind, -99.0)) < float(BARK_GAP.get(kind, 0.0)):
		return
	_bark_at[kind] = _ai_t
	var lines: Array = Barks.LINES[kind].filter(func(l: String): return who != "" or not l.contains("{n}"))
	if lines.size() > 1:
		lines = lines.filter(func(l: String): return l != String(_bark_last.get(kind, "")))
	var hero := "DOYLE" if String(Levels.CAMPAIGN[chapter]["hero"]) == "eddie" else "MALONE"
	var voice := ""
	for o in enemies:
		if o["node"] == m:
			voice = String(o.get("voice", ""))
	if voice != "":   # a line he has a recording of, if there is one (a voice beats a silent bubble)
		var heard: Array = lines.filter(func(l: String): return ResourceLoader.exists(Barks.path(voice, l.format({"n": who, "p": hero}))))
		if not heard.is_empty():
			lines = heard
	if lines.size() > 1:   # nothing heard in the last minute or so again (the last 14 lines)
		var fresh: Array = lines.filter(func(l: String): return not _bark_recent.has(l.format({"n": who, "p": hero})))
		if not fresh.is_empty():
			lines = fresh
		elif not urgent:
			return   # all of them heard just now: better silence than the same line again
	if who != "" and randf() < 0.75:   # a name in it, when there is one, most of the time
		var named: Array = lines.filter(func(l: String): return l.contains("{n}"))
		if not named.is_empty():
			lines = named
	var line: String = lines.pick_random()
	_bark_last[kind] = line
	_bark_t = _ai_t
	var text := line.format({"n": who, "p": hero})
	_bark_recent.append(text)
	if _bark_recent.size() > 14:
		_bark_recent.pop_front()
	_say(m, text)
	if voice != "":
		sfx.bark(Barks.path(voice, text), m.position.x)


## A man is shot: the nearest of his own who can see it says so, by name. He is angry: he fires sooner.
func _witness(dead: Dictionary, dm) -> void:
	if _all_down():
		return
	var best = null
	var best_d := 1800.0
	for o in enemies:
		if not o["alive"] or o == dead or o["boss"] or o["state"] in ["give", "wait", "around", "down"] or o.has("witness"):
			continue
		var on = o["node"]
		if not o["seen"] and not _on_screen(on.position) and absf(on.position.x - dm.position.x) > 900.0:
			continue   # far off and not yet in the fight: he did not see it
		var d: float = absf(on.position.x - dm.position.x)
		if d < best_d and absf(on.position.y - dm.position.y) < 200.0:   # (off the picture too: his shout comes from its edge)
			best_d = d
			best = o
	if best == null or randf() > (0.9 if best_d < 900.0 else 0.65):
		return
	var who: Dictionary = best
	get_tree().create_timer(randf_range(0.35, 0.6), false).timeout.connect(func() -> void:   # a beat: he takes it in
		if who["alive"] and who["state"] != "give":
			_bark(who["node"], "lead_down" if dead.get("role", "") == "lead" else "down", String(dead.get("name", "")), true)
			who["cool"] = minf(float(who["cool"]), 0.7))


func _say(m, text: String) -> void:
	if text == "" or (m != player and m is Node2D and not m.visible):
		return
	if _auto != "":
		print("SAY ", text, " at ", int(m.position.x))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://fonts/ComicNeue-BoldItalic.woff"))   # speech is lettered like the comic
	l.add_theme_font_size_override("font_size", 72)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85) * Color(_undo_night(0.5), 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 12)
	var font: Font = l.get_theme_font("font")
	var tw_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	l.set_meta("say", m.position.x)
	l.position = m.position + Vector2(-tw_w * 0.5, -640.0)
	if m != player and cam != null:   # a shout from beyond the picture: at its edge, toward him
		var half: float = get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
		l.position.x = clampf(l.position.x, cam.position.x - half + 140.0, cam.position.x + half - 140.0 - tw_w)
	# (audit 17. 11.: two shouts printed over each other) a line still up where this one would go: this one goes above it
	var moved := true
	var guard := 0
	while moved and guard < 6:
		moved = false
		guard += 1
		for o in get_children():
			if o is Label and o != l and o.has_meta("say") and o.modulate.a > 0.2:
				var r1 := Rect2(l.position, Vector2(tw_w, 80.0)).grow(16.0)
				var r2 := Rect2((o as Label).position, (o as Label).size)
				if r1.intersects(r2):
					l.position.y = (o as Label).position.y - 95.0
					moved = true
	l.z_index = 20
	add_child(l)
	var tw := l.create_tween()
	var long_line: float = 0.5 + 0.03 * text.length()   # a longer line stays up long enough to read
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.7 + long_line)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(long_line)
	tw.tween_callback(l.queue_free)


## Lieutenant Briggs on his knees, gun gone: the game waits for the detective's answer.
func _briggs_down(e: Dictionary) -> void:
	e["alive"] = false
	var m = e["node"]
	m.duck = 1.0
	m._gun.visible = false   # the shotgun on the ground
	var sh: Node2D = m.get_node_or_null("Shield")
	if sh:
		var tw := sh.create_tween()
		tw.tween_property(sh, "position", sh.position + Vector2(90.0, 170.0), 0.4)
		tw.parallel().tween_property(sh, "rotation", 1.4, 0.4)
	sfx.play("body_fall", 0.0, m.position.x, 0.05)
	_say(m, "GO ON, MALONE.")
	if _auto != "":   # the test bot spares him
		MenuScript.set_story("briggs", "spared")
		return
	var c = ChoiceScript.new()
	c.question = "Briggs is on his knees. He counted every shell. He never once called you a murderer."
	c.options = ["LET HIM LIVE", "FINISH IT"]
	hud.release_all()
	hud.modal(true)
	c.done = func(i: int) -> void:
		hud.modal(false)
		hud.release_all()
		if i == 0:
			MenuScript.set_story("briggs", "spared")
			_say(m, "...")
		else:
			MenuScript.set_story("briggs", "killed")
			sfx.play("shot_player", 2.0, m.position.x, 0.0)
			_drop(m, signf(m.position.x - player.position.x), true, "head")
			fx.blood(m.position + Vector2(0.0, -620.0), Vector2(signf(m.position.x - player.position.x) * 600.0, -100.0), true)
	add_child(c)


## The bosses' last third (QUEUE §16 D, user 18. 11. "go on"): each turns into another fight.
## Teague throws his pistols away and comes in with his fists - the old boxer; Kessler backs off to the far wall of his
## office (between Frank and his papers) and fires from there as fast as he can pull; Briggs's is his shield (_shield_off).
const BRIGGS_SHIELD := 12   # rounds into Briggs's shield before it is torn off his arm
func _boss_last_third(e: Dictionary) -> void:
	var m = e["node"]
	print("BOSS LAST THIRD ", level.get("boss", ""), " at x ", int(m.position.x), " t ", snappedf(_at, 0.1))
	match String(level.get("boss", "")):
		"teague":
			for g in [m._gun, m._gun2]:   # both pistols to the floor, away from him
				if g != null and g.visible:
					var gg := Sprite2D.new()
					gg.texture = g.texture
					gg.offset = g.offset
					gg.global_scale = g.global_scale.abs()
					gg.global_position = g.global_position
					gg.global_rotation = g.global_rotation
					gg.modulate = _undo_night(0.55)
					gg.z_index = 1
					add_child(gg)
					var away := signf(m.position.x - player.position.x)
					_flying_guns.append({"node": gg, "v": Vector2(away * randf_range(160.0, 300.0), -randf_range(380.0, 560.0)),
						"spin": away * randf_range(8.0, 14.0), "ground": m.position.y - 10.0, "bounce": 0, "kind": "post"})
			m.disarmed = true
			e["type"] = "hook"   # (_hook_man: in close, the arm back and the blow - here a fist)
			e["role"] = "rush"
			e["cool"] = 0.9
			_say(m, "NO MORE GUNS, MALONE. COME HERE.")
			sfx.play("clink", 0.0, m.position.x, 0.05)
		"kessler":
			var far: float = m.position.x + signf(m.position.x - player.position.x) * 900.0
			for r in rooms:   # the far wall of the room he is in
				if m.position.x > float(r[0]) and m.position.x < float(r[1]):
					far = (float(r[1]) - 260.0) if m.position.x > player.position.x else (float(r[0]) + 260.0)
			e["retreat"] = far
			e["frantic"] = true
			sets.smoke(m.position)
			_say(m, "YOU'LL NEVER SEE THAT DRAWER.")
		"briggs":
			if not e.get("shield_off", false):
				_say(m, "STILL COUNTING, MALONE.")


## Briggs's shield, dented through, is torn off his arm and clangs down: from now he is open from the front.
func _shield_off(e: Dictionary) -> void:
	if e.get("shield_off", false):
		return
	e["shield_off"] = true
	var m = e["node"]
	print("BOSS SHIELD OFF at x ", int(m.position.x), " t ", snappedf(_at, 0.1))
	var sh: Node2D = m.get_node_or_null("Shield")
	sfx.play("hit_cover", 4.0, m.position.x, 0.05)
	sfx.play("clink", 2.0, m.position.x, 0.05)
	_word(["clink", "wham"], m.position + Vector2(0.0, -420.0), 0.25)
	_shake = maxf(_shake, 0.3)
	if sh:
		var at: Vector2 = sh.global_position
		m.remove_child(sh)
		add_child(sh)
		sh.global_position = at
		sh.z_index = 1
		var away := signf(m.position.x - player.position.x)
		var tw := sh.create_tween().set_parallel(true)
		tw.tween_property(sh, "position", Vector2(at.x + away * 220.0, m.position.y - 40.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(sh, "rotation", away * 1.45, 0.55)
	_say(m, "...FINE. FACE TO FACE.")


func _boss_fire(m) -> void:
	_fire(m, false)
	for k in [1, 2]:
		get_tree().create_timer(0.13 * k, false).timeout.connect(func() -> void:
			if _still_firing(boss):
				_fire(m, false))


## (audit 21. 11.) The rest of a burst: only from a man still up, with his gun, not giving up (his gun shot out of his
## hand, kicked flat, hands going up - the rounds already "on their way" used to come out of an empty hand).
func _still_firing(e: Dictionary) -> bool:
	return not e.is_empty() and e["alive"] and not over and not cleared and String(e["state"]) not in ["give", "down", "hop", "stairs"] \
		and not e["node"].disarmed


## Cover = something tall standing just in front of (to the left of) a mobster, on his floor.
func _has_cover(at: Vector2) -> bool:
	for bx in boxes:
		var gap: float = at.x - bx.end.x
		if gap > 30.0 and gap < 300.0 and bx.size.y > 200.0 and absf(bx.end.y - at.y) < 1.0:
			return true
	return false


## Every mobster of the chapter is down, including those still waiting to run in.
func _all_down() -> bool:
	for e in enemies:
		if e["alive"]:
			return false
	return true


## The closest mobster still standing and near enough to matter, or null.
## Is a mobster's body under this point of the screen (with a finger's width to spare)?
func _man_under(screen: Vector2) -> bool:
	var w: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	for e in enemies:
		if not e["alive"] or e["state"] == "wait" or not e["node"].visible:
			continue
		var m = e["node"]
		var top: float = m.position.y - 400.0 * m.size + DUCK_DROP * m.duck
		if absf(w.x - m.position.x) < (130.0 if _sperk("steady") else 80.0) and w.y > top and w.y < m.position.y + 30.0:
			return true
	return false


## The nearest mobster on screen and in sight; on one side only (+1 / -1) or either (0).
func _nearest_enemy(side := 0.0):
	var best = null
	for e in enemies:
		if not e["alive"] or e["state"] in ["wait", "give"] or not e["node"].visible:
			continue
		if e.has("witness") and _auto != "" and ARGS.has("--spare-witness"):
			continue   # (test: the bot lets the witness run, to follow him into his house)
		var dx: float = e["node"].position.x - player.position.x
		if absf(dx) > SIGHT * (1.0 - 0.6 * (mapfx.fog if mapfx else 0.0)) or (side != 0.0 and signf(dx) != side):
			continue
		if absf(e["node"].position.y - player.position.y) > 1300.0:   # storeys below him on the street, out of the picture
			continue
		if e["state"] == "stairs" or (_section_at(player.position) >= 0 and not _works(_section_at(player.position)) and absf(e["node"].position.y - _ground_y) > 300.0):
			continue   # in a building only his own storey: the ceiling is between him and the rest
		if _flat_closed_between(e["node"].position, player.position):
			continue   # behind a shut door: kick it in first
		if best == null or absf(dx) < absf(best.position.x - player.position.x):
			best = e["node"]
	return best


## The bot's way up the scaffold: the ladder that stands on the floor he is on (on the street, only
## once he has come to it).
func _bot_ladder():
	for r in _ropes:   # a street piece's fire escape with a man still up on it: up the drop ladder after him
		if r["kind"] != "ladder" or not r.get("drawn", false) or player.position.y < -10.0:
			continue
		var lx: float = (r["a"] as Vector2).x
		var deck := Rect2(lx - 900.0, float(r["top"]) - 5.0, 1800.0, 10.0)   # the floor the ladder leads up to (the laundry's long catwalk)
		for c in catwalks:
			if absf(c.position.y - float(r["top"])) < 30.0 and lx > c.position.x - 60.0 and lx < c.end.x + 60.0:
				deck = deck.merge(c)
		for e in enemies:
			var ex: float = float(e["node"].position.x)
			if e["alive"] and not String(e["state"]) in ["give", "down"] and float(e["node"].position.y) < -300.0 					and float(e["node"].position.y) > float(r["top"]) - 800.0 and ex > deck.position.x - 200.0 and ex < deck.end.x + 200.0 					and player.position.x > deck.position.x - 1600.0 and player.position.x < deck.end.x + 200.0:   # (under the deck too: back to its ladder)
				return r
	if roof.is_empty() or player.position.y < float(roof["y"]) + 60.0:
		return null
	for r in _ropes:
		if r["kind"] != "ladder" or absf(player.position.y - float(r["bottom"])) > 40.0:
			continue
		if (r["a"] as Vector2).x < float(roof["x0"]) - 2500.0 or (r["a"] as Vector2).x > float(roof["x1"]) + 2500.0:
			continue   # (a ladder nowhere near the roofs: the big laundry's up to its catwalk)
		if player.position.y < -10.0 or player.position.x > (r["a"] as Vector2).x - 500.0:
			return r
	return null


## True when the detective is crouched with cover between him and a mobster on side `side` (+1 = right).
var _cov_frame := -1   # (audit 22. 11.) worked out once a frame, at the top of _enemies: each man asked it 3-4 times
var _cov := [false, false]
func _player_covered(side: float) -> bool:
	if _cov_frame == Engine.get_process_frames():
		return _cov[0 if side > 0.0 else 1]
	if _alcove >= 0.0 and _time - _alcove_shot > ALCOVE_EXPOSE:
		return true   # (rule 33) back in a doorway: the frame takes their rounds
	if player.duck < 0.6 or move_state != "ground":
		return false
	for bx in boxes:
		if absf(bx.end.y - player.position.y) > 60.0:   # a crate up on the roof is no cover in the street
			continue
		var near_edge: float = bx.position.x if side > 0.0 else bx.end.x
		var gap: float = (near_edge - player.position.x) * side
		if gap > -10.0 and gap < 260.0 * FIG and bx.size.y > 200.0 * FIG:
			return true
	return false


## A shot rings out: everyone within earshot knows where the detective is.
func _alarm(at: Vector2, radius: float) -> void:
	for e in enemies:
		if e["alive"] and not e["seen"] and e["state"] == "post" and absf(e["node"].position.x - at.x) < radius:
			e["seen"] = true
			e["cool"] = maxf(float(e["cool"]), 0.7)
			_mark(e["node"], "!")


## Fair play: nobody fires from beyond the edge of the screen.
## A gunman can only shoot what he can see: on the screen both ways, and not from below a roof or a
## floor at a man standing up on it (from the street the cornice hides whoever is on the roof).
func _can_see(m) -> bool:
	if not _on_screen(m.position):
		return false
	if _section_at(m.position) != _section_at(player.position):   # a building's walls between them
		return false
	if _plain_room_at(m.position) != _plain_room_at(player.position):   # an interior's walls
		return false
	if _flat_closed_between(m.position, player.position):   # the flat's door is shut between them
		return false
	var half_h: float = get_viewport().get_visible_rect().size.y * 0.5 / cam.zoom.y
	if absf(m.position.y - 60.0 - cam.position.y) > half_h + 40.0:
		return false
	return _same_floor(m)


## RULE (the user's, 15. 11.): a man shoots only at a Frank on his own floor. Frank's floor is where
## he last stood (a jump or a ladder doesn't change it); a crate is still the same floor.
const FLOOR_REACH := 400.0
func _same_floor(m) -> bool:
	return absf(m.position.y - _ground_y) < FLOOR_REACH


func _on_screen(p: Vector2) -> bool:
	var half: float = get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
	return absf(p.x - cam.position.x) < half - 30.0


## At most two of them shooting at once: a third waits for one of them to stop.
func _slot_free(e: Dictionary) -> bool:
	var busy := 0
	for k in _shots_at:
		if int(k) != int(e["id"]) and _ai_t - float(_shots_at[k]) < 0.7:
			busy += 1
	return busy < int(diff["shooters"])


## A "?" or "!" over a mobster's hat: he has noticed something, or he has seen the detective.
func _mark(m, text: String) -> void:
	if m != player and (not m.visible or m.has_meta("shade")):   # (the dream's dead do not cry out)
		return   # (a man behind a wall - in a room or a house he is not in - shows nothing over it)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load("res://fonts/ComicNeue-BoldItalic.woff"))
	l.add_theme_font_size_override("font_size", 110)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85) * Color(_undo_night(0.5), 1.0) if text == "?" else Color(0.75, 0.12, 0.08) * Color(_undo_night(0.55), 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 14)
	l.position = m.position + Vector2(-26.0, -640.0)
	l.z_index = 20
	add_child(l)
	if m != player:   # (audit 17. 11.: a "!" left floating over a man already falling dead)
		var old = m.get_meta("mark") if m.has_meta("mark") else null
		if old != null and is_instance_valid(old):
			old.queue_free()
		m.set_meta("mark", l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 40.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## The oddíl: one man leads and calls it, a tommy gunner keeps the detective's head down, the
## others go round, a shotgunner comes straight in. Roles are taken as the fight finds them.
func _squad(e: Dictionary, m, to_player: Vector2, delta: float) -> void:
	if e["boss"] or _stand or chapter == 0:
		return
	if e["role"] == "post":   # the first pistol of a group to see him leads it; the rest go round
		var lead := false
		for o in enemies:
			if o != e and o["alive"] and o.get("role", "") == "lead" and absf(o["node"].position.x - m.position.x) < GROUP:
				lead = true
		e["role"] = "flank" if lead else "lead"
	if e["role"] == "lead" and _cover_t > 3.5 and _ai_t - _behind_at > 22.0 and _flank_ok():
		_send_round(e, m)
	if e["role"] == "lead" and _cover_t > 1.8 and not _flank_called:
		_flank_called = true
		var sent := ""
		for o in enemies:
			if o["alive"] and o.get("role", "") == "flank" and o["state"] == "post" and o["node"].position.y == 0.0 \
					and absf(o["node"].position.x - m.position.x) < GROUP and signf(o["node"].position.x - player.position.x) == signf(m.position.x - player.position.x):
				_go_close(o)
				sent = String(o.get("name", ""))
				break
		_bark(m, "flank", sent)
	if e["state"] == "move":
		var goal: float = e["goal"]
		var way: float = signf(goal - m.position.x)
		var step: float = way * 260.0 * delta
		var blocked := false
		for bx in boxes:
			if e.get("followed", false):
				break   # (out of a room after him: he passes behind the crates, deeper in the room)
			if bx.grow(40.0).has_point(Vector2(m.position.x + step * 4.0, -60.0)) and m.position.y == 0.0:
				var far: float = bx.end.x + 70.0 if way > 0.0 else bx.position.x - 70.0
				if bx.size.y <= 270.0 and absf(far - player.position.x) > 260.0 and (goal - far) * way >= 0.0:
					_hop(e, m, bx, far)   # over the crate in his way, hands on the lid
					return
				blocked = true
		if blocked or absf(goal - m.position.x) < 12.0 or (_cover_t <= 0.0 and not e.get("to_cover", false)):
			e.erase("to_cover")
			e["state"] = "post"
			e["cover"] = _has_cover(m.position)
			e["home"] = m.position.x
			e["wander"] = m.position.x
			e["cool"] = maxf(float(e["cool"]), 0.5)
			return
		m.position.x += step
		m.duck = move_toward(m.duck, 0.0, delta * 7.0)
		m.set_state(way, to_player, delta)


## In a building in cross-section a man on the storey next to Frank's comes to him through the stairs in the
## back wall (story doc: the men on other storeys come by the stairs), once Frank has stood on his storey a
## while, one man at a time. From above he is heard first: a step, the camera looks up, a shout.
const STAIRS_SPEED := 300.0
const STAIRS_WAIT := 2.0      # s Frank has been on his storey before anyone comes for him
func _take_stairs(e: Dictionary, m) -> bool:
	if _stairdoors.is_empty() or e["boss"] or e["state"] != "post" or e["type"] not in ["post", "tommy", "shotgun"] or e.has("shield"):
		return false
	var si := _section_at(player.position)
	if si < 0 or _section_at(m.position) != si or move_state != "ground" or _ai_t - _storey_since < STAIRS_WAIT:
		return false
	if _ai_t - float(e.get("stairs_t", -99.0)) < 6.0:
		return false
	var going := 0
	for o in enemies:
		if o["alive"] and o["state"] == "stairs":
			going += 1
	if going >= 2:   # (user 21. 11.: "they keep me locked in their aim instead of coming my way") two at a time
		return false
	var d := _stairs_toward(m)
	if not d.is_empty():
		e["sd"] = {"x": float(d[0]), "to": float(d[2]), "phase": 0, "t": 0.0, "tint": m.modulate}
		e["state"] = "stairs"
		e["stairs_t"] = _ai_t
		if float(d[2]) > float(d[1]):   # coming down to him: heard before he is seen
			_steps_above = 0.5
			sfx.play("step1", -4.0, m.position.x, 0.1)
			_bark(m, "comedown", "", true)
		else:
			_bark(m, "goup", "", true)
		return true
	return false


## The stairs from his storey one storey on toward Frank's (the house's storeys are joined one to the next).
func _stairs_toward(m) -> Array:
	var way := signf(_ground_y - m.position.y)
	if way == 0.0:
		return []
	for d in _stairdoors:
		if absf(float(d[1]) - m.position.y) < 12.0 and signf(float(d[2]) - float(d[1])) == way:
			return d
	return []


func _on_stairs(e: Dictionary, m, delta: float) -> void:
	var sd: Dictionary = e["sd"]
	var x: float = sd["x"]
	var to_y: float = sd["to"]
	var up: bool = to_y < m.position.y if int(sd["phase"]) == 0 else bool(sd.get("up", false))
	var tint: Color = sd["tint"]
	var aim_at: Vector2 = player.position + Vector2(0.0, SHOULDER.y) - (m.position + Vector2(0.0, SHOULDER.y))
	m.duck = move_toward(m.duck, 0.0, delta * 7.0)
	sd["t"] = float(sd["t"]) + delta
	match int(sd["phase"]):
		0:   # along his storey to the opening
			if move_state == "stairs" or (move_state == "ground" and (absf(_ground_y - m.position.y) < 12.0 					or signf(_ground_y - m.position.y) != signf(to_y - m.position.y))):
				# (18. 11.: they came down the stairs as he went up, and missed him for good) he is leaving, or has left, the
				# storey this man was going to: he stays on his own and takes him on from here, or follows him later
				e["state"] = "post"
				e.erase("sd")
				e["stairs_t"] = _ai_t - 6.0   # (a few seconds, then he may go after him again)
				return
			sd["up"] = up
			var goal: float = x + (_stair_foot() if up else 0.0)
			var way := signf(goal - m.position.x)
			m.set_state(way, aim_at, delta)
			m.position.x = move_toward(m.position.x, goal, STAIRS_SPEED * delta * _wading(m.position.y))
			if absf(goal - m.position.x) < 2.0:
				sd["phase"] = 1
				sd["t"] = 0.0
				sd["from_y"] = m.position.y
		1:   # in: up the painted flight into the dark, or into the opening on the level
			var k := clampf(float(sd["t"]) / STAIRDOOR_IN, 0.0, 1.0)
			if up:
				m.position = Vector2(lerpf(x + _stair_foot(), x - _stair_foot(), k), float(sd["from_y"]) - 170.0 * k)
			m.set_state(-1.0 if up else 0.0, aim_at, delta)
			var v := 1.0 - 0.85 * smoothstep(0.2, 1.0, k)
			m.modulate = Color(tint.r * v, tint.g * v, tint.b * v, tint.a * (1.0 - smoothstep(0.7, 1.0, k)))
			if k >= 1.0:
				sd["phase"] = 2
				sd["t"] = 0.0
				m.position = Vector2(x if up else x - _stair_foot(), to_y - (0.0 if up else 170.0))
		2:   # unseen a moment on the stairs
			if float(sd["t"]) > 0.7:
				sd["phase"] = 3
				sd["t"] = 0.0
		3:   # out: on the level from the opening above, or down the flight painted below
			var k := clampf(float(sd["t"]) / STAIRDOOR_OUT, 0.0, 1.0)
			var toward := signf(player.position.x - x)
			if up:
				m.position = Vector2(x + toward * 90.0 * k, to_y)
			else:
				m.position = Vector2(lerpf(x - _stair_foot(), x + _stair_foot(), k), to_y - 170.0 * (1.0 - k))
			m.set_state(toward if up else 1.0, aim_at, delta)
			var v := 0.15 + 0.85 * smoothstep(0.2, 1.0, k)
			m.modulate = Color(tint.r * v, tint.g * v, tint.b * v, tint.a * smoothstep(0.0, 0.4, k))
			if k >= 1.0:   # on Frank's storey: he stands and fights, a beat before his first shot
				m.position.y = to_y
				m.modulate = tint
				e.erase("sd")
				e["state"] = "post"
				e["cover"] = _has_cover(m.position)
				e["home"] = m.position.x
				e["wander"] = m.position.x
				e["cool"] = maxf(float(e["cool"]), 1.0)


func _hop(e: Dictionary, m, bx: Rect2, far: float, back_to := "move") -> void:
	e["state"] = "hop"
	var x0: float = m.position.x
	var y0: float = m.position.y   # (his own floor, not always the street)
	var top: float = bx.position.y - 30.0
	var tw: Tween = m.create_tween()
	tw.tween_method(func(k: float) -> void:
		if not e["alive"] or e["state"] != "hop":
			return
		m.position.x = lerpf(x0, far, k)
		m.position.y = minf(y0, lerpf(y0, top, sin(k * PI) * 1.15))
		m.duck = sin(k * PI) * 0.6, 0.0, 1.0, 0.6)
	tw.tween_callback(func() -> void:
		if e["alive"]:
			m.position.y = y0   # (exactly: a float left over kept him out of every "on the street" test)
			if e["state"] == "hop":
				e["state"] = back_to)


## The wooden crate the detective is crouched behind on the side `side` (toward the man), or -1.
func _covering_crate(side: float) -> int:
	if player.duck < 0.6 or move_state != "ground":
		return -1
	for i in boxes.size():
		var bx: Rect2 = boxes[i]
		if absf(bx.end.y - player.position.y) > 60.0 or not box_info[i].get("wood", false) or box_info[i]["kind"] == "barrel":
			continue
		var near_edge: float = bx.position.x if side > 0.0 else bx.end.x
		var gap: float = (near_edge - player.position.x) * side
		if gap > -10.0 and gap < 260.0 * FIG and bx.size.y > 200.0 * FIG:
			return i
	return -1


## Seen him, standing in the open: if there is a crate or a drum a few steps away on his side of the
## fight, he gets behind it (2026-11-16: they used to stand and wait to be shot). True if he goes.
func _seek_cover(e: Dictionary, m) -> bool:
	if e["boss"] or e["cover"] or e["type"] not in ["post", "tommy", "dynamite"] or e.has("shield") or _stand or chapter == 0:
		return false
	if m.position.y != 0.0 or absf(m.position.y - player.position.y) > 60.0:
		return false
	var side: float = signf(m.position.x - player.position.x)
	if absf(m.position.x - player.position.x) < 500.0:
		return false   # too close to turn his back and walk
	var best := INF
	var goal := 0.0
	for bx in boxes:
		if absf(bx.end.y - m.position.y) > 1.0 or bx.size.y < 200.0:
			continue
		var g: float = (bx.end.x + 80.0) if side > 0.0 else (bx.position.x - 80.0)   # on his side of it
		if (g - player.position.x) * side < 650.0:   # not right up against the detective
			continue
		if absf(g - m.position.x) > 650.0 or absf(g - m.position.x) < 40.0:
			continue
		var taken := false
		for o in enemies:
			if o != e and o["alive"] and absf(float(o["node"].position.x) - g) < 140.0 and o["node"].position.y == 0.0:
				taken = true
		if not taken and absf(g - m.position.x) < best:
			best = absf(g - m.position.x)
			goal = g
	if best == INF:
		return false
	e["goal"] = goal
	e["state"] = "move"
	e["to_cover"] = true
	if randf() < 0.4:
		_bark(m, "cover")
	return true


## Going round behind him is for a fight he has dug into, not the first streets of the story, and
## never where there is no behind: the roof of a train, a room, the dream.
func _flank_ok() -> bool:
	if chapter < 1 or (chapter == 1 and map < 2) or _room != "" or level.get("dream", false) or float(level.get("moving", 0.0)) > 0.0:
		return false
	return player.position.y > -60.0


## The lead sends one man round the block: the one furthest back walks off out of sight, and some
## seconds later he comes running in from behind the detective (a shout and a "!" first, so it is fair).
func _send_round(lead: Dictionary, lm) -> void:
	var side: float = signf(lm.position.x - player.position.x)
	var pick: Dictionary = {}
	var far := 0.0
	var group := 0
	for o in enemies:
		if not o["alive"] or o["boss"] or o["state"] not in ["post", "move"] or o["node"].position.y != 0.0 or o.has("witness"):
			continue
		if signf(o["node"].position.x - player.position.x) != side or absf(o["node"].position.x - lm.position.x) > GROUP:
			continue
		group += 1
		if o == lead or o["type"] not in ["post", "shotgun"] or o["state"] != "post":
			continue
		var d: float = absf(o["node"].position.x - player.position.x)
		if d > far:
			far = d
			pick = o
	if pick.is_empty() or group < 3:   # two men hold the line; only a third goes round
		return
	var half: float = get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
	var behind := INF
	for k in 6:   # he comes in along the street, somewhere clear of crates, out of the picture
		var x: float = player.position.x - side * (half + 250.0 + 150.0 * k)
		var clear: bool = x > 400.0 and x < level_end - 200.0
		for bx in boxes:
			if bx.grow(120.0).has_point(Vector2(x, -50.0)):
				clear = false
		if clear:
			behind = x
			break
	if behind == INF:
		return
	_behind_at = _ai_t
	_bark(lm, "round", String(pick.get("name", "")), true)
	pick["state"] = "around"
	pick["around_t"] = randf_range(3.5, 5.0)
	pick["around_x"] = behind
	pick["around_side"] = side


func _add_witness() -> void:
	var key := "%d:%d" % [chapter, map]
	if not WITNESS.has(key) or _auto == "give":
		return
	var w: Array = WITNESS[key]
	var x: float = maxf(level_end * float(w[1]), checkpoint + 1500.0)
	var house: Array = level.get("witness_house", [])
	var holed := not house.is_empty() and (x >= float(house[0]) - 40.0 or checkpoint_y < 0.0)   # (audit 21. 11.)
	if holed:
		x = float(house[1])
	elif x > level_end - 700.0:
		return
	var e := _add_enemy(Vector2(x, 0.0), "post", "post", x)
	e["witness"] = true
	e["name"] = String(w[0])
	e["role"] = "witness"
	var m = e["node"]
	m.disarmed = true   # no gun on him: he only knows things
	if m._gun != null:
		m._gun.visible = false
	if holed or ARGS.has("--witness-holed") and level.has("witness_house"):   # (test: already up in his room)
		e["holed_up"] = true
		m.position = Vector2(float(level["witness_house"][1]), float(level["witness_house"][2]))
	if ARGS.has("--log-sets"): print("WITNESS ", w[0], " at ", int(x))


## (BACK STREETS, 21. 11.) A map won in the witness's room ("goal_witness"): only once he is let go or dead, and a
## moment after, so what he says (or what Frank finds on him) is read before the page turns.
var _witness_t := 0.0
func _witness_settled(delta: float) -> bool:
	if not level.get("goal_witness", false):
		return true
	for e in enemies:
		if e.has("witness") and e["alive"]:
			_witness_t = 0.0
			return false
	_witness_t += delta
	return _witness_t > 2.6


## The witness: never fires. Frank close, he runs on down the street; at its end, cornered, he gives up. Where the map
## has his house ("witness_house": its street door, where he hides, that storey), he runs to its door and goes in, up to
## his room; there, Frank in the room with him, he gives up.
func _witness_tick(e: Dictionary, m, delta: float) -> bool:
	if e["state"] != "post":
		return false   # (running: the runner's own walk; giving up: as any man)
	var to_player: Vector2 = player.position - m.position
	var dx: float = absf(to_player.x)
	var house: Array = level.get("witness_house", [])
	if not house.is_empty():
		if e.get("holed_up", false):   # in his room: the door between them until Frank kicks it in
			if absf(player.position.y - m.position.y) < 80.0 and player.position.x > float(house[1]) - 900.0 and dx < 900.0 \
					and not _flat_closed_between(m.position, player.position):
				_give_up(e)
				if ARGS.has("--log-sets"): print("WITNESS CORNERED in his room at ", int(m.position.x))
			else:
				m.set_state(0.0, to_player, delta)
			return true
		if m.position.x >= float(house[0]) - 40.0:   # at the house's door: in, and up the stairs to his room
			e["holed_up"] = true
			m.position = Vector2(float(house[1]), float(house[2]))
			e["post_x"] = m.position.x
			if ARGS.has("--log-sets"): print("WITNESS HOLES UP at ", int(m.position.x), ",", int(m.position.y))
			return true
		if dx < 2800.0:   # (sooner than on an open street, and all the way: he knows where he is going)
			e["state"] = "run"
			e["goal"] = float(house[0])
			e["seen"] = true
			_say(m, (WITNESS["%d:%d" % [chapter, map]][2] as Array).pick_random())
			if ARGS.has("--log-sets"): print("WITNESS RUNS to ", int(e["goal"]))
			return true
		m.set_state(0.0, to_player, delta)
		return true
	if m.position.x < level_end - 600.0 and dx < 1900.0:   # (as soon as Frank is in sight)
		e["state"] = "run"
		e["goal"] = minf(m.position.x + 1700.0, level_end - 350.0)
		e["seen"] = true
		_say(m, (WITNESS["%d:%d" % [chapter, map]][2] as Array).pick_random())
		if ARGS.has("--log-sets"): print("WITNESS RUNS to ", int(e["goal"]))
		return true
	if m.position.x >= level_end - 600.0 and dx < 900.0:   # nowhere left to run
		_give_up(e)
		if ARGS.has("--log-sets"): print("WITNESS CORNERED at ", int(m.position.x))
		return true
	m.set_state(0.0, to_player, delta)
	return true


func _going_round(e: Dictionary, m, delta: float) -> void:
	var side: float = float(e["around_side"])
	if m.visible:   # walking off, away from the fight, until he is out of the picture
		m.position.x += side * 330.0 * delta
		m.set_state(side, Vector2(side, 0.0), delta)
		if not _on_screen(m.position + Vector2(-side * 120.0, 0.0)):
			m.visible = false
		return
	e["around_t"] = float(e["around_t"]) - delta
	if float(e["around_t"]) > 0.0:
		return
	if _room != "" or absf(player.position.y) > 60.0:   # the detective moved on somewhere he cannot follow: he waits
		e["around_t"] = 1.0
		e["around_wait"] = float(e.get("around_wait", 0.0)) + 1.0
		if float(e["around_wait"]) > 6.0:   # (audit 21. 11.) ... not for ever: back where he went off, on his own, where he can be found
			m.visible = true
			e["state"] = "post"
			e["cover"] = _has_cover(m.position)
		return
	var half: float = get_viewport().get_visible_rect().size.x * 0.5 / cam.zoom.x
	var x: float = player.position.x - side * (half + 250.0)
	m.position = Vector2(x, 0.0)
	m.visible = true
	e["state"] = "run"
	e["goal"] = player.position.x - side * 650.0
	e["cover"] = false
	e["sought"] = true
	_mark(m, "!")
	sfx.play("step1", 2.0, x, 0.1)
	_bark(m, "behind", "", true)


## Another man stands within a man's width or two of this one on his floor: the one further from the detective
## steps back away from him (returns the way to step, 0 when there is room).
## (user 18. 11. look at the big laundry: two men drawn one over the other) two men on one floor never stand in the
## same spot: whoever is nearer to Frank stays, the other slides back a step, never into cover or off his floor.
const SEPARATE := 90.0
func _separate(delta: float) -> void:
	# (audit 22. 11.) sorted along the street, each man is held only against the next few: it was every pair of the
	# whole map's men, every frame
	var men: Array = []
	for e in enemies:
		if e["alive"] and not e["boss"] and String(e["state"]) in ["post", "move", "run"]:
			men.append(e["node"])
	men.sort_custom(func(p, q) -> bool: return float(p.position.x) < float(q.position.x))
	for i in men.size():
		var ma = men[i]
		for j in range(i + 1, men.size()):
			var mb = men[j]
			var dx: float = float(mb.position.x) - float(ma.position.x)
			if dx > SEPARATE + 4.0:   # (a man pushed back this frame moves 160 * delta at most: a little slack)
				break
			if absf(float(mb.position.y) - float(ma.position.y)) > 20.0 or absf(dx) > SEPARATE:
				continue
			var back = ma if absf(float(ma.position.x) - player.position.x) > absf(float(mb.position.x) - player.position.x) else mb
			var way := signf(float(back.position.x) - player.position.x)
			if way == 0.0:
				way = 1.0
			var to: float = float(back.position.x) + way * 160.0 * delta
			var blocked := false
			for bx in boxes:
				if bx.grow(30.0).has_point(Vector2(to, float(back.position.y) - 40.0)):
					blocked = true
			if not blocked and (back.position.y == 0.0 or _floor_under_ok(Vector2(to, back.position.y))):
				back.position.x = to


const CROWD := 230.0
func _crowded(e: Dictionary, m) -> float:
	var away: float = signf(m.position.x - player.position.x)
	for o in enemies:
		if o == e or not o["alive"] or o["boss"]:
			continue
		var om = o["node"]
		if absf(float(om.position.y) - m.position.y) > 40.0 or absf(float(om.position.x) - m.position.x) > CROWD:
			continue
		if absf(m.position.x - player.position.x) >= absf(float(om.position.x) - player.position.x):
			return away if away != 0.0 else 1.0
	return 0.0


## He stands on a floor he can take a step along (the street, or a deck under him both ways).
func _floor_under_ok(p: Vector2) -> bool:
	if p.y == 0.0:
		return true
	if _plain_room_at(p) < 0:   # (only an interior's catwalk, the big laundry's: the roofs and fire escapes keep their men put)
		return false
	for c in catwalks:   # (not _floor_at: that one tells the player's landing what it found)
		if absf(c.position.y - p.y) < 4.0 and p.x - 300.0 > c.position.x and p.x + 300.0 < c.end.x:
			return true
	return false


## A flanker goes in close, to just beyond the detective's crate, where he can fire down over it.
func _go_close(o: Dictionary) -> void:
	if o["node"].position.y != 0.0:
		return
	var side: float = signf(o["node"].position.x - player.position.x)
	var goal: float = player.position.x + side * 470.0
	for bx in boxes:   # stop on his own side of anything in the way, a few steps off it: he does not lean on the detective's own crate
		if (bx.get_center().x - goal) * side < 0.0 and (bx.get_center().x - o["node"].position.x) * side < 0.0 and (bx.get_center().x - player.position.x) * side > 0.0:
			goal = (bx.end.x + 70.0) if side > 0.0 else (bx.position.x - 70.0)
			if absf(bx.get_center().x - player.position.x) < 400.0:
				goal += side * 160.0
	if (goal - player.position.x) * side > 550.0:
		goal = player.position.x + side * 550.0   # (close enough to fire down over his crate)
	for k in enemies:   # not onto another man's spot: a step further back
		if k != o and k["alive"] and absf(float(k["node"].position.x) - goal) < 110.0 and k["node"].position.y == 0.0:
			goal += side * 130.0
	o["goal"] = goal
	o["state"] = "move"


## Each mobster keeps his gun on the detective once he has seen him. One with cover in front of him
## stays down behind it and pops up every couple of seconds to shoot; one without just shoots.
## Nobody fires at a detective crouched behind cover: they wait for him to show himself.
func _enemies(delta: float) -> void:
	_ai_t += delta
	_separate(delta)
	_tick_sticks(delta)
	_tick_bottles(delta)
	_tick_loads(delta)
	_cov_frame = -1
	_cov = [_player_covered(1.0), _player_covered(-1.0)]
	_cov_frame = Engine.get_process_frames()
	var crouched: bool = _cov[0] or _cov[1]
	_cover_t = _cover_t + delta if crouched else 0.0
	if not crouched:
		_flank_called = false
		_crate_called = false
	_crate_shooters = 0
	if _cover_t > 6.0 and _ai_t - _taunt_t > 14.0 and randf() < delta * 0.5:
		var near = _nearest_enemy()
		if near != null:
			for o in enemies:
				if o["node"] == near and o["alive"] and o["seen"] and o["state"] == "post" and not o.has("witness"):
					_taunt_t = _ai_t
					_bark(near, "taunt")
	for e in enemies:
		if e.has("line") and (not e["alive"] or e["state"] != "post"):   # (audit 21. 11.) the marksman's line goes with him
			if is_instance_valid(e["line"]):
				(e["line"] as Node).queue_free()
			e.erase("line")
			e.erase("aim_t")
		if not e["alive"]:
			continue
		var m = e["node"]
		if e["state"] == "give":
			_giving_up(e, delta)
			continue
		if e["state"] == "down":
			_knocked(e, delta)
			continue
		if e["state"] == "hop":
			m.set_state(signf(player.position.x - m.position.x) * -0.0, player.position - m.position, delta)
			continue
		if e["state"] == "around":   # gone round the block: out of sight, then in from behind him
			_going_round(e, m, delta)
			continue
		if e.has("witness") and _witness_tick(e, m, delta):
			continue
		if e["state"] == "wait":   # a runner holds back, out of sight, until the detective passes his mark
			var passed: bool = player.position.x > float(e["trig"])
			if not roof.is_empty() and m.position.y < float(roof["y"]) + 60.0:   # up on the roof he is coming the other way
				passed = player.position.x < float(e["trig"]) and player.position.y < float(roof["y"]) + 60.0
			if passed:
				e["delay"] = float(e["delay"]) - delta
			if passed and float(e["delay"]) <= 0.0:
				e["state"] = "run"
				e["seen"] = true
				m.visible = true
			continue
		if e["state"] == "stairs":   # through the stairs in the back wall to Frank's storey
			_on_stairs(e, m, delta)
			continue
		if e["state"] == "run":   # running in to his spot, gun already on the detective; then he stands and fights
			var way: float = signf(float(e["goal"]) - m.position.x)
			m.position.x += way * RUNNER_SPEED * delta * _wading(m.position.y)
			var aim_at: Vector2 = player.position + Vector2(0.0, SHOULDER.y) - (m.position + Vector2(0.0, SHOULDER.y))
			m.set_state(way, aim_at, delta)
			m.duck = move_toward(m.duck, 0.0, delta * 7.0)
			if absf(float(e["goal"]) - m.position.x) < RUNNER_SPEED * delta * 1.5:
				m.position.x = float(e["goal"])
				e["state"] = "post"
				e["cover"] = _has_cover(m.position)
				e["cool"] = randf_range(0.3, 0.8)
			continue
		if m.position.y == 0.0 and player.position.x - m.position.x > 1800.0:   # left behind: he comes after the detective
			e["state"] = "run"
			e["goal"] = player.position.x - randf_range(800.0, 1000.0)
			e["up"] = false
			continue
		var side: float = signf(m.position.x - player.position.x)
		var to_player: Vector2 = (player.position + Vector2(0.0, SHOULDER.y + DUCK_DROP * player.duck)) - (m.position + Vector2(0.0, SHOULDER.y + DUCK_DROP * m.duck))
		# Seeing him: in the dark only from closer; a moment of "?" before the "!" so the detective
		# always gets a beat to act first. A boss knows he is coming.
		var sight: float = SIGHT * (0.6 if _in_dark(player.position.x) and not sets.lit(player.position + Vector2(0.0, -150.0)) and not _in_beam(player.position) else 1.0)
		sight *= 1.0 - 0.6 * mapfx.fog   # in the fog off the river nobody sees far
		if _alcove >= 0.0 and _time - _alcove_shot > ALCOVE_EXPOSE:
			sight = minf(sight, ALCOVE_SEEN)   # (rule 33) in a doorway: only from close by
		if absf(to_player.x) < sight and not e["seen"]:
			if e["boss"]:
				hud.boss_bar(BOSS_NAMES.get(String(level["boss"]), "BOSS"), 1.0)
				cue(m.position + Vector2(0.0, -250.0), 1.6, 0.45)   # the camera looks at him as he steps out
				if String(level["boss"]) == "kessler":
					sets.smoke(m.position + Vector2(-500.0, 0.0))
				e["seen"] = true
			elif float(e["notice"]) < 0.0:
				e["notice"] = 0.0
				_mark(m, "?")
		if float(e["notice"]) >= 0.0 and not e["seen"]:
			e["notice"] = float(e["notice"]) + delta
			if float(e["notice"]) > 0.5:
				e["seen"] = true
				e["cool"] = maxf(float(e["cool"]), 0.6)
				_mark(m, "!")
				if randf() < 0.55:
					_bark(m, "spot")
		if not e["seen"]:
			continue
		if not e.get("sought", false) and e["state"] == "post":
			e["sought"] = true
			if _seek_cover(e, m):
				continue
		if _take_stairs(e, m):
			continue
		var msi := _section_at(m.position)
		if msi >= 0 and msi == _section_at(player.position) and not _same_floor(m) and e["state"] == "post" and not e["boss"]:
			# (user 21. 11.) Frank on another storey of the house: no gun on him through the floor - he faces the stairs
			# that lead to him, ready for whoever comes out of them, until it is his turn to go up (or down) them
			var sd := _stairs_toward(m)
			var look := Vector2(float(sd[0]) - m.position.x, 0.0) if not sd.is_empty() and absf(float(sd[0]) - m.position.x) > 120.0 				else Vector2(signf(player.position.x - m.position.x) * 400.0, 0.0)
			m.set_state(0.0, look, delta)
			m.duck = move_toward(m.duck, 0.0, delta * 7.0)
			continue
		_squad(e, m, to_player, delta)
		if e["state"] == "move":   # on his way somewhere: he does not stop to shoot
			continue
		if e.has("retreat"):   # Kessler, the last third: back to the far wall of his office, not a shot on the way
			var rx: float = float(e["retreat"])
			if absf(rx - m.position.x) > 30.0 and not over:
				m.position.x += signf(rx - m.position.x) * 420.0 * delta
				m.set_state(signf(rx - m.position.x), to_player, delta)
				continue
			e.erase("retreat")
			e["cool"] = 0.4
		if e["type"] == "hook":   # no gun: he comes for Frank with the hook
			_hook_man(e, m, to_player, delta)
			continue
		if e["type"] == "shade":
			_shade(e, m, to_player, delta)
			continue
		if e.has("aim_t"):   # the marksman, sighted in: the line holds on Frank, then the shot
			_sniper_aim(e, m, to_player, delta)
			continue
		var hiding: bool = e["cover"] and side > 0.0   # his cover only works while the detective is on its far side
		var want_duck: float = 0.0
		var walk := 0.0
		var over_cover: bool = e["role"] == "flank" and absf(to_player.x) < 600.0   # close up he shoots down over the crate
		var at_cover: bool = e["role"] == "suppress" and _cover_t > 1.2       # the tommy gun chews the cover itself
		# a wooden crate he hides behind is shot to pieces: two men at most, once he has sat there a moment
		var crate_i: int = _covering_crate(side) if _cover_t > 1.0 and e["type"] in ["post", "tommy", "shotgun"] and not over_cover else -1
		var at_crate: bool = crate_i >= 0 and (_crate_shooters < 2 or at_cover) and _can_see(m)
		e["at_crate"] = at_crate
		if at_crate:
			_crate_shooters += 1
			if not _crate_called and e["type"] == "post":
				_crate_called = true
				_bark(m, "crate")
		var reach: float = 1500.0 if e["type"] == "shotgun" else 2450.0   # (inside their guns' range: WEAPONS life)
		var may_fire: bool = not over and not cleared and _grace <= 0.0 and absf(to_player.x) < minf(reach, SIGHT * 1.3) * (1.0 - 0.6 * mapfx.fog) \
				and (not _player_covered(side) or over_cover or at_cover or at_crate) and _can_see(m) and (_slot_free(e) or at_crate)
		var aim_vec: Vector2 = to_player
		if at_crate and _player_covered(side):   # his gun on the boards, chest high on the crate
			var cb: Rect2 = boxes[crate_i]
			aim_vec = Vector2(cb.get_center().x + side * cb.size.x * 0.2, cb.position.y + cb.size.y * 0.4) - (m.position + Vector2(0.0, SHOULDER.y + DUCK_DROP * m.duck))
		e["timer"] -= delta
		if hiding:
			if e["up"]:
				if e["timer"] < 0.9 and not e.get("glinted", false) and may_fire:
					e["glinted"] = true
					_glint(m)
				if e["timer"] < 0.55 and not e["shot"]:
					e["shot"] = true
					if may_fire:
						e["aim_off"] = randf_range(-120.0, 90.0) * _aim_spread()
						_enemy_fire(e)
				if e["timer"] <= 0.0:
					e["up"] = false
					e["timer"] = randf_range(1.0, 1.9)
			else:
				want_duck = 1.0
				if e["timer"] <= 0.0:
					e["up"] = true
					e["shot"] = false
					e["glinted"] = false
					e["timer"] = 1.15
		else:
			var was_cool: float = e["cool"]
			e["cool"] -= delta
			if was_cool > 0.32 and e["cool"] <= 0.32 and may_fire:   # a glint at the muzzle: he is about to fire
				_glint(m)
			# between shots a man without cover does not stand like a target: a step this way or that
			# (user 18. 11. look at the big laundry: three men in one spot) every gunman in the open spreads out, on any floor
			var spread_ok: bool = (e["type"] == "post" and m.position.y == 0.0) or (e["type"] in ["post", "tommy", "shotgun"] and _plain_room_at(m.position) >= 0 and _floor_under_ok(m.position))
			if spread_ok and not e["boss"] and e["cool"] > 0.5:
				if not e.has("home"):
					e["home"] = m.position.x
					e["wander"] = m.position.x
				var crowd := _crowded(e, m)   # (feedback 17. 11.: no knot of men shoulder to shoulder in the open)
				if crowd != 0.0 and absf(float(e["wander"]) - m.position.x) <= 8.0:
					var to2: float = m.position.x + crowd * 260.0
					var ok2 := true
					for bx in boxes:
						if bx.grow(60.0).has_point(Vector2(to2, -50.0)):
							ok2 = false
					if ok2:
						e["wander"] = to2
						e["home"] = to2
				if absf(float(e["wander"]) - m.position.x) > 8.0:
					walk = signf(float(e["wander"]) - m.position.x)
					m.position.x += walk * 170.0 * delta
				elif randf() < delta * 0.6:
					var to: float = float(e["home"]) + randf_range(-150.0, 150.0)
					var free := true
					for bx in boxes:
						if bx.grow(60.0).has_point(Vector2(to, -50.0)):
							free = false
					if free:
						e["wander"] = to
			if e["type"] == "shotgun" and absf(m.position.y - player.position.y) < 60.0 and absf(to_player.x) > 520.0:
				walk = signf(to_player.x)   # the shotgunner closes in
				m.position.x += walk * 300.0 * delta
			var in_range: bool = e["type"] != "shotgun" or absf(to_player.x) < 760.0
			if e.has("shield"):   # Briggs: walks in behind his shield, turns slowly, and counts every shell
				e["shield"] = move_toward(float(e["shield"]), signf(to_player.x), delta * (3.0 if e.get("shield_off", false) else 1.5))
				if float(e["reload_t"]) > 0.0:
					e["reload_t"] = float(e["reload_t"]) - delta
					may_fire = false
					if float(e["reload_t"]) <= 0.0:
						e["shells"] = 5
						_say(m, "LOADED.")
				if signf(float(e["shield"])) != signf(to_player.x) and not e.get("shield_off", false):
					may_fire = false
				if absf(to_player.x) > 420.0 and absf(m.position.y - player.position.y) < 60.0:
					walk = signf(to_player.x)
					m.position.x += walk * 210.0 * delta
				var sh: Node2D = m.get_node_or_null("Shield")
				if sh and not e.get("shield_off", false):
					sh.position.y = -200.0 + (120.0 if float(e["reload_t"]) > 0.0 else 0.0)   # lowered while he loads
				in_range = absf(to_player.x) < 900.0
			if e["cool"] <= 0.0 and may_fire and in_range:
				e["aim_off"] = randf_range(-150.0, 110.0) * _aim_spread()
				_enemy_fire(e)
		m.duck = move_toward(m.duck, want_duck, delta * 7.0)
		m.set_state(walk, aim_vec + Vector2(0.0, e["aim_off"] * (0.3 if aim_vec != to_player else 1.0)), delta)


## The marksman: a thin line from his scope onto Frank while he sights in, then one shot that does
## not miss a man who stands still. Duck behind cover, dive, or shoot him first.
func _sniper_aim(e: Dictionary, m, to_player: Vector2, delta: float) -> void:
	e["aim_t"] = float(e["aim_t"]) - delta
	var line: Line2D = e.get("line")
	if line == null or not is_instance_valid(line):
		line = Line2D.new()
		line.width = 3.0
		line.default_color = Color(0.85, 0.12, 0.08, 0.0)
		line.z_index = 6
		line.material = _unshaded()
		add_child(line)
		e["line"] = line
	var from: Vector2 = m.muzzle()
	var to: Vector2 = player.position + Vector2(0.0, SHOULDER.y + DUCK_DROP * player.duck)
	line.points = PackedVector2Array([from, to])
	line.default_color.a = clampf(1.25 - float(e["aim_t"]), 0.0, 0.85) * (0.6 + 0.4 * sin(_time * 30.0))
	m.set_state(0.0, to_player, delta)
	var lost: bool = over or cleared or not _can_see(m) or (_player_covered(signf(m.position.x - player.position.x)) and (player.duck > 0.6 or _alcove >= 0.0))
	if lost or float(e["aim_t"]) <= 0.0:
		line.queue_free()
		e.erase("line")
		e.erase("aim_t")
		e["cool"] = randf_range(2.4, 3.2)
		if not lost:
			e["aim_off"] = randf_range(-20.0, 20.0)
			_fire(m, false, "rifle")
			_shots_at[int(e["id"])] = _ai_t


var _unshaded_mat: CanvasItemMaterial
func _unshaded() -> CanvasItemMaterial:
	if _unshaded_mat == null:
		_unshaded_mat = CanvasItemMaterial.new()
		_unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded_mat


## The longshoreman with a cargo hook: no gun, so he comes running, over crates if he must, and swings
## when he is close. A beat of warning ("!" and the arm up) before each swing. A kick puts him down.
func _hook_man(e: Dictionary, m, to_player: Vector2, delta: float) -> void:
	var walk := 0.0
	var dx: float = to_player.x
	var same_floor: bool = absf(m.position.y - player.position.y) < 90.0
	e["cool"] = float(e["cool"]) - delta
	if over or cleared or _grace > 0.0:
		m.set_state(0.0, to_player, delta)
		return
	if e.has("swing_t"):
		e["swing_t"] = float(e["swing_t"]) - delta
		m.recoil = 0.9   # the hook raised
		if float(e["swing_t"]) <= 0.0:
			e.erase("swing_t")
			m.recoil = -0.6   # and down
			sfx.play("whiz", -4.0, m.position.x, 0.1)
			if absf(dx) < 190.0 and same_floor and move_state != "dive":
				fx.hit_vel = Vector2(-signf(m.position.x - player.position.x), 0.0) * 900.0
				_bullet_hit(player.position + Vector2(0.0, SHOULDER.y + 40.0), false)
			e["cool"] = 1.2
	elif e["boss"] and not same_floor and absf(dx) < 1500.0:   # Teague with his fists, Frank up out of his reach: bottles off the bar
		if float(e["cool"]) <= 0.0:
			e["cool"] = randf_range(1.1, 1.6)
			m.recoil = 0.9
			_throw_bottle(m)
	elif absf(dx) > 150.0 or not same_floor:
		walk = signf(dx)
		var step: float = walk * 360.0 * delta
		var blocked := -1
		for k in boxes.size():
			if boxes[k].grow(25.0).has_point(Vector2(m.position.x + step * 8.0, m.position.y - 60.0)):
				blocked = k
		if blocked >= 0 and same_floor and boxes[blocked].size.y <= 270.0:   # over the crate, the way the flankers go
			var bx: Rect2 = boxes[blocked]
			var far: float = (bx.end.x + 90.0) if walk > 0.0 else (bx.position.x - 90.0)
			if absf(player.position.x - far) > 140.0:
				_hop(e, m, bx, far, "post")
				return
			walk = 0.0
		elif blocked < 0:
			m.position.x += step
	elif float(e["cool"]) <= 0.0 and _slot_free(e):
		e["swing_t"] = 0.38
		_mark(m, "!")
		_shots_at[int(e["id"])] = _ai_t
	m.set_state(walk, to_player, delta)


## THE DREAM's dead (user 18. 11.: "the workers who burned in there - shadows, souls, like Alan Wake 2's; they need not
## shoot"): the dock workers' silhouettes, cap and work coat, pitch dark, smoke coming off them, two embers for eyes.
## They lurch at Frank with their hands out; a touch burns him. Out of his sight they come on in a jerk - a puff of soot
## and the shadow is suddenly nearer. A bullet knocks ash out of them; the last one takes them apart into ash and sparks.
func _shade_body(m) -> void:
	var smoke := CPUParticles2D.new()
	smoke.texture = load("res://art/fx/puff3.png")
	smoke.amount = 10
	smoke.lifetime = 1.8
	smoke.local_coords = false   # (it trails behind him)
	smoke.position = Vector2(0.0, -300.0)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(60.0, 220.0)
	smoke.direction = Vector2(0.0, -1.0)
	smoke.spread = 25.0
	smoke.gravity = Vector2(0.0, -70.0)
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 60.0
	smoke.scale_amount_min = 0.25
	smoke.scale_amount_max = 0.5
	smoke.angle_max = 360.0
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.05, 0.05, 0.0))
	g.add_point(0.25, Color(0.06, 0.05, 0.05, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.1, 0.09, 0.09, 0.0))
	smoke.color_ramp = g
	smoke.show_behind_parent = true
	m.add_child(smoke)
	m.rim_line = Vector3(0.9, 0.42, 0.14)   # a contour of embers, not the cream ink of the living
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var eye := Sprite2D.new()   # the embers where his eyes were (on the figure, off its CanvasGroup: _shade_eyes places them)
	eye.texture = _soft_glow()
	eye.material = add
	eye.scale = Vector2(0.24, 0.12)
	eye.modulate = _undo_night(1.5) * Color(1.0, 0.45, 0.12, 1.0)   # (through the night's CanvasModulate, as the flames are)
	eye.z_index = 30
	add_child(eye)   # (not on the figure: its near-black colour and its CanvasGroup would put the embers out)
	m.set_meta("eyes", eye)


const SHADE_ASH := Color(0.1, 0.09, 0.09)   # (as it shows: fx.smoke's own night lift is divided out, _ash_tint)
func _ash_tint() -> Color:
	return Color(SHADE_ASH.r / maxf(0.05, fx.night.r), SHADE_ASH.g / maxf(0.05, fx.night.g), SHADE_ASH.b / maxf(0.05, fx.night.b))
func _shade_eyes(m) -> void:
	var eye: Sprite2D = m.get_meta("eyes") if m.has_meta("eyes") else null
	var head: Sprite2D = m._spr.get("head")
	if eye == null or not is_instance_valid(eye) or head == null:
		return
	eye.visible = m.visible
	var a: Vector2 = m.cfg["parts"]["head"]["a"]
	var local := Vector2(head.texture.get_width() * 0.8, head.texture.get_height() * 0.47) - a   # (the profile's eye)
	eye.global_position = head.global_transform * local
	eye.self_modulate.a = (0.75 + 0.25 * sin(_ai_t * 5.0 + m.position.x)) * m.modulate.a / 0.9   # (smouldering; out with him)
	if ARGS.has("--log-sets") and fmod(_ai_t, 2.0) < 0.034: print("EYES ", eye.global_position, " head ", head.global_position, " vis ", eye.is_visible_in_tree(), " mod ", eye.modulate)


func _shade(e: Dictionary, m, to_player: Vector2, delta: float) -> void:
	var walk := 0.0
	var dx: float = to_player.x
	var same_floor: bool = absf(m.position.y - player.position.y) < 90.0
	e["cool"] = float(e["cool"]) - delta
	if over or cleared or _grace > 0.0:
		m.set_state(0.0, to_player, delta)
		return
	# out of his sight (he looks the other way), far enough: the jerk forward in a puff of soot
	e["blink"] = float(e["blink"]) - delta
	if same_floor and absf(dx) > 420.0 and signf(dx) == -signf(_look) and float(e["blink"]) <= 0.0:
		e["blink"] = randf_range(1.6, 2.8)
		var to_x: float = m.position.x + signf(dx) * minf(300.0, absf(dx) - 260.0)
		var clear := true
		for bx in boxes:
			if bx.grow(40.0).has_point(Vector2(to_x, m.position.y - 60.0)):
				clear = false
		if clear:
			for at: Vector2 in [m.position, Vector2(to_x, m.position.y)]:
				fx.smoke(at + Vector2(0.0, -260.0), Vector2(randf_range(-30.0, 30.0), -60.0), 0.9, 0.9, 0.55, _ash_tint())
			m.position.x = to_x
			sfx.play("flutter", -12.0, to_x, 0.1)
	if absf(dx) > 120.0 or not same_floor:
		walk = signf(dx) * (0.55 + 0.3 * sin(_ai_t * 2.6 + float(e["id"])))   # a lurch, not a walk
		var step: float = walk * 300.0 * delta
		var blocked := -1
		for k in boxes.size():
			if boxes[k].grow(25.0).has_point(Vector2(m.position.x + signf(dx) * 200.0, m.position.y - 60.0)):
				blocked = k
		if blocked >= 0 and same_floor and boxes[blocked].size.y <= 270.0:   # over the crate
			var bx: Rect2 = boxes[blocked]
			var far: float = (bx.end.x + 90.0) if dx > 0.0 else (bx.position.x - 90.0)
			if absf(player.position.x - far) > 140.0:
				_hop(e, m, bx, far, "post")
				return
			walk = 0.0
		elif blocked < 0:
			m.position.x += step
	elif float(e["cool"]) <= 0.0 and move_state != "dive":   # his hands on Frank: it burns
		e["cool"] = 1.3
		sfx.play("fire", -6.0, m.position.x, 0.1)
		for k in 6:
			fx.spark(player.position + Vector2(randf_range(-40.0, 40.0), randf_range(-380.0, -160.0)))
		_burn_player(1)
		var back: float = player.position.x + signf(dx) * 60.0   # (he tears himself free: a step back, away from it)
		var free_way := true
		for bx in boxes:
			if bx.grow(20.0).has_point(Vector2(back, player.position.y - 60.0)):
				free_way = false
		if free_way:
			player.position.x = back
	m.set_state(walk, to_player, delta)


func _shade_hit(at: Vector2) -> void:
	for k in 4:
		fx.smoke(at, Vector2(fx.hit_vel.x * 0.15 + randf_range(-60.0, 60.0), randf_range(-120.0, -30.0)), 0.35, 0.8, 0.6, _ash_tint())
	for k in 5:
		fx.spark(at + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)))


func _shade_gone(m) -> void:
	sfx.play("fire", -2.0, m.position.x, 0.1)
	var eyes = m.get_meta("eyes") if m.has_meta("eyes") else null
	if eyes != null and is_instance_valid(eyes):   # the embers go out first
		eyes.create_tween().tween_property(eyes, "modulate:a", 0.0, 0.25)
	for k in 9:   # the whole of him goes up as ash
		fx.smoke(m.position + Vector2(randf_range(-80.0, 80.0), -randf_range(60.0, 520.0)), Vector2(randf_range(-80.0, 80.0), -randf_range(60.0, 200.0)),
				randf_range(0.6, 1.0), randf_range(1.0, 1.6), 0.7, _ash_tint())
	for k in 12:
		fx.spark(m.position + Vector2(randf_range(-90.0, 90.0), -randf_range(40.0, 520.0)))
	var tw: Tween = m.create_tween()
	tw.tween_interval(0.1)   # (gone inside the burst of ash: a fade shows him half drawn - the contour shader lets the coat through)
	tw.tween_callback(func() -> void:
		m.visible = false
		var eye = m.get_meta("eyes") if m.has_meta("eyes") else null
		if eye != null and is_instance_valid(eye):
			eye.queue_free())


## Dynamite: a lit stick lobbed to land at Frank's feet. It burns down and goes up where it lies;
## a bullet sets it off at once, in the air or on the ground, wherever it is.
var _sticks: Array = []

func _throw_stick(m) -> void:
	if not _same_floor(m):
		return
	var from: Vector2 = m.muzzle()
	var target := Vector2(player.position.x + randf_range(-70.0, 70.0), player.position.y)
	var t := clampf(absf(target.x - from.x) / 900.0, 0.7, 1.3)
	var g := 2600.0
	var v := Vector2((target.x - from.x) / t, (target.y - from.y - 0.5 * g * t * t) / t)
	var st := Sprite2D.new()
	st.texture = load("res://art/guns/dynamite.png")
	st.scale = Vector2.ONE * (90.0 / st.texture.get_width())
	st.position = from
	st.z_index = 4
	add_child(st)
	_sticks.append({"node": st, "vel": v, "fuse": 1.6, "down": false, "spark": 0.0})
	sfx.play("match", -6.0, m.position.x, 0.1)
	m.recoil = 0.8


## Teague's bottles (QUEUE §16 D): thrown at Frank where his fists cannot reach him (the club's gallery). A whiskey
## bottle (art/props/bottle.png, art_src 319) in an arc onto him; it bursts on him (a hit) or on the boards.
var _bottles: Array = []
func _throw_bottle(m) -> void:
	var from: Vector2 = m.position + Vector2(0.0, -330.0)
	var target: Vector2 = player.position + Vector2(randf_range(-60.0, 60.0), -200.0)
	var t := clampf(absf(target.x - from.x) / 1000.0, 0.55, 1.1)
	var g := 2400.0
	var b := Sprite2D.new()
	b.texture = load("res://art/props/bottle.png")
	b.scale = Vector2.ONE * (110.0 / b.texture.get_width())
	b.position = from
	b.modulate = _undo_night(0.6)
	b.z_index = 4
	add_child(b)
	_bottles.append({"node": b, "vel": Vector2((target.x - from.x) / t, (target.y - from.y - 0.5 * g * t * t) / t), "g": g})
	sfx.play("whiz", -6.0, m.position.x, 0.1)
	if ARGS.has("--log-sets"): print("BOTTLE at t ", snappedf(_at, 0.1))


func _tick_bottles(delta: float) -> void:
	for k in range(_bottles.size() - 1, -1, -1):
		var bt: Dictionary = _bottles[k]
		var n: Sprite2D = bt["node"]
		bt["vel"] = (bt["vel"] as Vector2) + Vector2(0.0, float(bt["g"])) * delta
		n.position += (bt["vel"] as Vector2) * delta
		n.rotation += 11.0 * delta * signf((bt["vel"] as Vector2).x)
		var on_him: bool = not over and absf(n.position.x - player.position.x) < 70.0 and n.position.y > player.position.y - 430.0 * (1.0 - 0.45 * player.duck) and n.position.y < player.position.y
		var floor_y := _floor_at(n.position.x, n.position.y - 30.0)
		if on_him or n.position.y >= floor_y - 6.0 or n.position.y > 3000.0:
			if on_him and move_state != "dive":
				fx.hit_vel = Vector2(signf((bt["vel"] as Vector2).x), 0.0) * 700.0
				_bullet_hit(player.position + Vector2(0.0, SHOULDER.y + 40.0), false)   # (as a hook blow lands: on his chest)
			sfx.play("glass", -2.0, n.position.x, 0.1)
			for c in 8:
				fx.chip(n.position)
			n.queue_free()
			_bottles.remove_at(k)


func _tick_sticks(delta: float) -> void:
	for k in range(_sticks.size() - 1, -1, -1):
		var st: Dictionary = _sticks[k]
		var n: Sprite2D = st["node"]
		st["fuse"] = float(st["fuse"]) - delta
		st["spark"] = float(st["spark"]) - delta
		if float(st["spark"]) <= 0.0:
			st["spark"] = 0.08
			fx.spark(n.position + Vector2(40.0, -12.0).rotated(n.rotation) * n.scale.x * 2.2)
		if not st["down"]:
			st["vel"] = (st["vel"] as Vector2) + Vector2(0.0, 2600.0) * delta
			n.position += (st["vel"] as Vector2) * delta
			n.rotation += 9.0 * delta * signf((st["vel"] as Vector2).x)
			var floor_y := _floor_at(n.position.x, n.position.y - 40.0)
			if n.position.y >= floor_y - 8.0 and (st["vel"] as Vector2).y > 0.0:
				n.position.y = floor_y - 8.0
				n.rotation = 0.0
				st["down"] = true
				sfx.play("clink", -8.0, n.position.x, 0.2)
		if float(st["fuse"]) <= 0.0:
			_stick_goes(k)


func _stick_goes(k: int) -> void:
	var st: Dictionary = _sticks[k]
	var at: Vector2 = (st["node"] as Sprite2D).position
	(st["node"] as Sprite2D).queue_free()
	_sticks.remove_at(k)
	_blast(at + Vector2(0.0, -40.0), 300.0, 270.0, 1)


## A crate hanging from a crane over the docks, on a rope that goes up out of the picture. Shoot the
## rope and it comes down on whoever stands under it; then it is a crate on the ground like any other.
var _loads: Array = []

func _place_loads() -> void:
	if chapter != 2 or diff_step < 0 or in_menu or _unreal():   # crane loads hang over the docks, not over 1931
		return
	var last := -99999.0
	var n := 0
	for e in enemies:
		var m = e["node"]
		if e["state"] != "post" or e["boss"] or m.position.y != 0.0 or m.position.x < 2600.0 or m.position.x - last < 1600.0 or e.has("witness"):
			continue
		if _room_at(m.position.x, m.position.y) != "" or _has_cover(m.position) or n >= 3:
			continue
		var x: float = m.position.x
		var clear := true
		for bx in boxes:
			if absf(bx.get_center().x - x) < 260.0:
				clear = false
		if not clear:
			continue
		last = x
		n += 1
		var crate := Sprite2D.new()
		crate.texture = load("res://art/props/crate.png")
		var w := 230.0
		crate.scale = Vector2.ONE * (w / crate.texture.get_width())
		var h: float = crate.texture.get_height() * crate.scale.y
		crate.position = Vector2(x, -640.0 - h * 0.5)
		crate.modulate = Color(0.84, 0.82, 0.79)
		crate.z_index = -1
		add_child(crate)
		var rope := Line2D.new()   # hemp: the yarn drawing turned brown-grey
		rope.texture = load("res://art/props/rope.png")
		rope.texture_mode = Line2D.LINE_TEXTURE_TILE
		rope.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		rope.width = 11.0
		rope.default_color = _undo_night(0.5)
		rope.z_index = -1
		var top := -640.0 - h
		rope.points = PackedVector2Array([Vector2(x, top - 1600.0), Vector2(x, top - 70.0), Vector2(x - w * 0.42, top + 6.0)])
		var rope2 := rope.duplicate() as Line2D
		rope2.points = PackedVector2Array([Vector2(x, top - 70.0), Vector2(x + w * 0.42, top + 6.0)])
		add_child(rope)
		add_child(rope2)
		_loads.append({"crate": crate, "ropes": [rope, rope2], "x": x, "top": top, "h": h, "w": w, "fall": -1.0})


## True if the bullet cut a rope.
func _load_hit(pos: Vector2) -> bool:
	for ld in _loads:
		if float(ld["fall"]) >= 0.0:
			continue
		if absf(pos.x - float(ld["x"])) < 14.0 and pos.y < float(ld["top"]) - 60.0 and pos.y > float(ld["top"]) - 1600.0:
			ld["fall"] = 0.0
			fx.spark(pos)
			sfx.play("wood_hit", -2.0, pos.x, 0.1)
			_word(["crack"], pos + Vector2(0.0, -60.0), 0.18)
			for r in ld["ropes"]:
				(r as Line2D).queue_free()
			return true
	return false


func _tick_loads(delta: float) -> void:
	for k in range(_loads.size() - 1, -1, -1):
		var ld: Dictionary = _loads[k]
		if float(ld["fall"]) < 0.0:
			continue
		ld["fall"] = float(ld["fall"]) + 3200.0 * delta
		var c: Sprite2D = ld["crate"]
		c.position.y += float(ld["fall"]) * delta
		var bottom: float = c.position.y + float(ld["h"]) * 0.5
		if bottom >= 0.0:   # down: whoever is under it does not get up
			c.position.y = -float(ld["h"]) * 0.5
			var x: float = ld["x"]
			var half: float = float(ld["w"]) * 0.5
			for e in enemies:
				if e["alive"] and e["state"] != "wait" and absf(e["node"].position.x - x) < half + 60.0 and e["node"].position.y > -100.0:
					_kill(e, false, true, "blast")
			sfx.play("wood_break", 2.0, x, 0.05)
			sfx.play("body_fall", 0.0, x, 0.05)
			_shake = maxf(_shake, 0.35)
			_word(["crash"], Vector2(x, -330.0), 0.34)
			if absf(player.position.x - x) < half + 50.0 and player.position.y > -120.0:
				c.queue_free()   # on Frank: it bursts apart on him instead of burying him
				fx.hit_vel = Vector2(0.0, 800.0)
				_bullet_hit(player.position + Vector2(0.0, SHOULDER.y), false)
			else:
				c.z_index = -2
				_ground_shadow(x, float(ld["w"]))
				boxes.append(Rect2(x - half, -float(ld["h"]), float(ld["w"]), float(ld["h"])))
				box_info.append({"kind": "crate", "sprite": c, "hp": 7, "wood": true})
			_loads.remove_at(k)


## In slowed time, from chapter II: a dashed line from his gun shows where the shot would glance off
## steel and go on. Only when there is a glance in it; plain shots need no line.
var _aim_line: Line2D

func _tick_aim_line() -> void:
	if _aim_line == null:
		_aim_line = Line2D.new()
		var img := Image.create_empty(32, 4, false, Image.FORMAT_RGBA8)
		for x in 32:
			for y in 4:
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if x < 18 else 0.0))
		_aim_line.texture = ImageTexture.create_from_image(img)
		_aim_line.texture_mode = Line2D.LINE_TEXTURE_TILE
		_aim_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_aim_line.width = 5.0
		_aim_line.default_color = Color(0.95, 0.35, 0.25, 0.9) * Color(_undo_night(1.0), 1.0)
		_aim_line.material = _unshaded()
		_aim_line.z_index = 7
		add_child(_aim_line)
	_aim_line.visible = false
	if chapter < 2 or diff_step < 0 or over or Engine.time_scale >= 1.0 or reloading > 0.0:
		return
	var from: Vector2 = player.muzzle()
	var d: Vector2 = player.aim_dir().normalized()
	if _aim_point != Vector2.INF and _aim_point.distance_to(from) > 120.0:
		d = (_aim_point - from).normalized()
	var pts := PackedVector2Array([from])
	var p := from
	var bounced := false
	var ended := false
	for k in 130:
		p += d * 20.0
		var hit := -1
		for i in boxes.size():
			if boxes[i].has_point(p):
				hit = i
				break
		if hit < 0:
			continue
		var info: Dictionary = box_info[hit]
		if bounced or info["wood"] or info["kind"] in ["barrel", "stack"]:
			pts.append(p)
			ended = true
			break
		var n := _face_normal(boxes[hit], p, d)
		d = d - 2.0 * d.dot(n) * n
		pts.append(p)
		p += n * 16.0
		bounced = true
	if not bounced:
		return
	if not ended:
		pts.append(p)
	_aim_line.points = pts
	_aim_line.visible = true


## ---- Ropes: up a fire escape hand over hand, down a cable from the roof with the gun out, across
## the quay on a crane's rope. Grabbed by jumping (or running off a landing) with his hands on it.
const LADDER_W := 125.0       # rail to rail
const LADDER_PROUD := 230.0   # how far it stands up past the deck it leans on
const LADDER_HANDS := 200.0   # his hands at the top, before he steps off onto the deck
const ROPE_REACH := 392.0 * FIG       # feet to fists, arms straight up (the puppet's hang_top: 1.95 m)
const ZIP_WINCH_H := 250.0            # the zip line's winch on the street, its height in px
const ZIP_DRUM := Vector2(0.29, 0.27)  # where the cable leaves the winch's drum, share of its picture
const ZIP_WHEEL := Vector2(0.8, 0.13) # the mast's pulley wheel, share of its picture
const ZIP_TINT := Color(0.6, 0.58, 0.56)   # the drawings came out paler than the street's crates
const ZIP_PULLEY_BACK := 260.0
const WASH_K := 0.55   # laundry on a washing line: its drawings' scale        # the pulley stands this far back up the cable from where he grabs it
const SWING_ANCHOR := -1460.0   # the crane's jib, above the top of the picture
const SWING_BOTTOM := -650.0 - 392.0 * (FIG - 1.0)   # the rope's end: within reach of a jump; higher by what his longer arms add, so his feet still clear the stacks
const SWING_AMP := 1.33         # how far out he swings (radians)
const SWING_LET_GO := 0.98      # and where he lets go, on the way up
var _ropes: Array = []
var _rope = null
var _rope_cool := 0.0
var _fling := 0.0
var _hand := Vector2.ZERO        # where his fists are on the rope
var _rope_v := 0.0               # along the rope / cable, px per second
var _theta := 0.0                # swing: the rope's angle from straight down (+ = the way he swings)
var _omega := 0.0
var _swing_dir := 1.0
var _climbed := 0.0
var _mantle_t := -1.0
var _mantle_from := Vector2.ZERO
var _mantle_to := Vector2.ZERO


func _rope_line(tex_tint: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.texture = load("res://art/props/rope.png")
	l.texture_mode = Line2D.LINE_TEXTURE_TILE
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.width = width
	l.default_color = tex_tint
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.z_index = -1
	add_child(l)
	return l


func _add_rope(ro: Array) -> void:
	var kind := String(ro[0])
	var r := {"kind": kind}
	if kind == "ladder":   # a builder's ladder from one deck (or the street) up to the next, standing proud of it
		var x := float(ro[1])
		var top := float(ro[2])
		var bottom := float(ro[4])
		r["a"] = Vector2(x, top - LADDER_HANDS)
		r["b"] = Vector2(x, bottom - 10.0)
		r["top"] = top
		r["bottom"] = bottom
		var tex: Texture2D = load("res://art/props/ladder.png")
		var k := LADDER_W / tex.get_width()
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		sp.centered = false
		sp.region_enabled = true
		var h := bottom - top + LADDER_PROUD
		sp.region_rect = Rect2(0.0, 0.0, tex.get_width(), h / k)
		sp.scale = Vector2.ONE * k
		sp.position = Vector2(x - LADDER_W * 0.5, top - LADDER_PROUD)
		sp.z_index = -1
		sp.modulate = Color(0.84, 0.82, 0.79)
		sp.visible = not (_section_kit() and _section_at(Vector2(x, bottom - 10.0)) >= 0) and not (ro.size() > 5 and String(ro[5]) == "drawn")   # the drawing paints its own
		add_child(sp)
		r["line"] = sp
		r["drawn"] = ro.size() > 5 and String(ro[5]) == "drawn"
	elif kind == "climb":   # knotted to the landing's rail, the end coiled on the stones
		var x := float(ro[1])
		r["a"] = Vector2(x, float(ro[2]) - 92.0)
		r["b"] = Vector2(x, -10.0)
		r["top"] = float(ro[2])
		var l := _rope_line(_undo_night(0.7), 13.0)
		l.points = PackedVector2Array([r["a"], r["b"], Vector2(x + 26.0, -4.0), Vector2(x + 58.0, -8.0), Vector2(x + 40.0, -2.0)])
		r["line"] = l
	elif kind == "zip":   # a cable over a mast's pulley on the walkway's end, down to a winch on the street
		# (user 17. 11.: tied to a barrel on the ground it was random: each end has a thing of its own, art_src 240)
		var s0 := Vector2(float(ro[1]), float(ro[2]) - ROPE_REACH - 6.0)
		var winch_tex: Texture2D = load("res://art/props/zip_winch.png")
		var wk := ZIP_WINCH_H / winch_tex.get_height()
		var drum := Vector2(float(ro[3]) + 330.0, -winch_tex.get_height() * wk * (1.0 - ZIP_DRUM.y))
		var winch := Sprite2D.new()
		winch.texture = winch_tex
		winch.centered = false
		winch.scale = Vector2.ONE * wk
		winch.position = drum - Vector2(winch_tex.get_width() * ZIP_DRUM.x, winch_tex.get_height() * ZIP_DRUM.y) * wk
		winch.z_index = -2
		winch.modulate = ZIP_TINT
		add_child(winch)
		_ground_shadow(drum.x + winch_tex.get_width() * (0.5 - ZIP_DRUM.x) * wk, winch_tex.get_width() * wk, 0.0)
		var d := (drum - s0).normalized()
		var pulley := s0 - d * ZIP_PULLEY_BACK   # the wheel the cable runs over, behind and above his hands
		var mast_tex: Texture2D = load("res://art/props/zip_mast.png")
		var mk := (float(ro[2]) - pulley.y) / (mast_tex.get_height() * (1.0 - ZIP_WHEEL.y))
		var mast := Sprite2D.new()
		mast.texture = mast_tex
		mast.centered = false
		mast.scale = Vector2.ONE * mk
		mast.position = pulley - Vector2(mast_tex.get_width() * ZIP_WHEEL.x, mast_tex.get_height() * ZIP_WHEEL.y) * mk
		mast.z_index = -2
		mast.modulate = ZIP_TINT
		add_child(mast)
		var end_y := -ROPE_REACH - 30.0   # he lets go with his feet just off the ground
		var e := s0 + d * ((end_y - s0.y) / d.y)
		r["a"] = s0
		r["b"] = e
		r["d"] = d
		r["top"] = float(ro[2])
		var l := _rope_line(_undo_night(0.42) * Color(0.8, 0.82, 0.86), 7.0)
		l.points = PackedVector2Array([pulley, drum])
		r["line"] = l
		var hook := Sprite2D.new()   # a cargo hook hung over the cable: what he rides down on
		hook.texture = load("res://art/guns/hook.png")
		hook.scale = Vector2.ONE * (64.0 / hook.texture.get_width())
		hook.rotation = -PI * 0.5
		hook.z_index = 1
		hook.modulate = _undo_night(0.7)
		add_child(hook)
		r["hook"] = hook
		r["rest"] = s0
		hook.position = s0 + Vector2(0.0, 22.0)
	elif kind == "wash":   # a washing line tied to the fire escape's top rail, run through a pulley on the next
		# house's window jamb (user 17. 11.: it must start and end on something): ridden down like a zip line, the
		# laundry torn off as he passes (the stunt list)
		r["kind"] = "zip"
		var start := Vector2(float(ro[1]), float(ro[2]))
		var pul := Vector2(float(ro[3]), float(ro[4]))
		var d := (pul - start).normalized()
		var a := start + d * 70.0
		r["a"] = a
		r["b"] = pul - d * 110.0
		r["pul"] = pul
		r["d"] = d
		r["top"] = float(ro[5]) if ro.size() > 5 else float(ro[2])
		var l := _rope_line(_undo_night(0.55) * Color(0.85, 0.83, 0.78), 4.0)
		l.points = PackedVector2Array([start, pul])
		r["line"] = l
		_pulley(start, Vector2(0.0, 26.0))   # tied round the rail's post
		_pulley(pul, Vector2(-26.0, 0.0))    # on its bracket in the window jamb
		var hook := Sprite2D.new()   # (nothing rides on it but his hands: an empty marker the zip code moves)
		hook.visible = false
		add_child(hook)
		r["hook"] = hook
		r["rest"] = a
		var clothes: Array = []
		var rng := RandomNumberGenerator.new()
		rng.seed = int(a.x)
		var span := start.distance_to(pul)
		var t := 150.0
		while t < span - 130.0:
			var tex: Texture2D = load("res://art/props/laundry_%d.png" % rng.randi_range(0, 8))
			var c := Sprite2D.new()
			c.texture = tex
			c.centered = false
			c.offset = Vector2(-tex.get_width() * 0.5, 0.0)   # pinned by its top middle
			c.scale = Vector2.ONE * WASH_K * rng.randf_range(0.9, 1.05)
			c.position = start + d * t + Vector2(0.0, -4.0)
			c.rotation = rng.randf_range(-0.05, 0.05)
			c.modulate = _undo_night(0.27)
			c.z_index = -2
			add_child(c)
			clothes.append(c)
			t += tex.get_width() * WASH_K + rng.randf_range(30.0, 70.0)
		r["laundry"] = clothes
	elif kind == "swing":   # from a crane's jib out of the picture, a cargo hook on its end
		var x := float(ro[1])
		r["a"] = Vector2(x, float(ro[2]) if float(ro[2]) != 0.0 else SWING_ANCHOR)   # a hoist's painted pulley, or the crane's jib out of the picture
		r["b"] = Vector2(x, SWING_BOTTOM)
		r["line"] = _rope_line(_undo_night(0.55), 12.0)
		var hook := Sprite2D.new()
		hook.texture = load("res://art/guns/hook.png")
		hook.scale = Vector2.ONE * (84.0 / hook.texture.get_width())
		hook.rotation = PI * 0.5
		hook.z_index = -1
		hook.modulate = _undo_night(0.75)
		add_child(hook)
		r["hook"] = hook
		_draw_swing(r, 0.0, SWING_BOTTOM - (r["a"] as Vector2).y)
	_ropes.append(r)


## A manhole cover in the pavement (art_src 247), where the street's steam comes up: flat on the stones, toned like
## the drawing behind it.
const MANHOLE_W := 380.0
var manholes: Array[float] = []   # (mapfx: the steam bursts out of these in a street)
var _manhole_sprites := {}
## The steam blows the cover: it jumps, rattles and drops back.
func hop_manhole(x: float) -> void:
	for k in _manhole_sprites:
		if absf(float(k) - x) < 30.0:
			var sp: Sprite2D = _manhole_sprites[k]
			var y := sp.position.y
			var tw := sp.create_tween()
			tw.tween_property(sp, "position:y", y - 70.0, 0.12).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(sp, "rotation", 0.25, 0.12)
			tw.tween_property(sp, "position:y", y, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(sp, "rotation", 0.0, 0.18)
			for j in 3:
				tw.tween_property(sp, "position:y", y - 8.0, 0.05)
				tw.tween_property(sp, "position:y", y, 0.05)
			sfx.play("hammer", -10.0, x, 0.1)
			return
func _manhole(x: float, tone: Color) -> void:
	manholes.append(x)
	var tex: Texture2D = load("res://art/props/manhole.png")
	var k := MANHOLE_W / tex.get_width()
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.scale = Vector2(k, k * 0.42)   # (laid flatter: the pavement is seen from low down)
	sp.position = Vector2(x, -12.0)
	_manhole_sprites[x] = sp
	sp.modulate = tone * 0.9
	sp.z_index = -6
	add_child(sp)


## A washing line hung between two window jambs (on its pulleys), sagging, laundry pegged along it: the alley's landmark.
func _washing_line(a: Vector2, b: Vector2) -> void:
	var sag := 60.0
	var pts := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		pts.append(a.lerp(b, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t)))
	var l := _rope_line(_undo_night(0.5) * Color(0.85, 0.83, 0.78), 3.0)
	l.points = pts
	_pulley(a, Vector2(-26.0, 0.0))
	_pulley(b, Vector2(26.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(a.x * 7.0 + a.y)
	var span := b.x - a.x
	var x := 60.0
	while x < span - 90.0:
		var tex: Texture2D = load("res://art/props/laundry_%d.png" % rng.randi_range(0, 8))
		var t := x / span
		var c := Sprite2D.new()
		c.texture = tex
		c.centered = false
		c.offset = Vector2(-tex.get_width() * 0.5, 0.0)
		c.scale = Vector2.ONE * WASH_K * rng.randf_range(0.85, 1.05)
		c.position = a.lerp(b, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t) - 4.0)
		c.rotation = rng.randf_range(-0.06, 0.06)
		c.modulate = _undo_night(0.24)
		c.z_index = -2
		add_child(c)
		x += tex.get_width() * WASH_K + rng.randf_range(20.0, 90.0)


## A small iron pulley: a ring and the bracket that holds it (from `arm` off the ring to the ring).
func _pulley(at: Vector2, arm: Vector2) -> void:
	var col := _undo_night(0.32)
	var bracket := Line2D.new()
	bracket.points = PackedVector2Array([at + arm, at])
	bracket.width = 6.0
	bracket.default_color = col
	bracket.z_index = -2
	add_child(bracket)
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for k in 13:
		pts.append(at + Vector2.from_angle(TAU * k / 12.0) * 12.0)
	ring.points = pts
	ring.width = 5.0
	ring.default_color = col
	ring.z_index = -2
	add_child(ring)


func _draw_swing(r: Dictionary, th: float, grip_len: float) -> void:
	var a: Vector2 = r["a"]
	var d := Vector2(sin(th), cos(th))
	var full: float = SWING_BOTTOM - a.y
	var end := a + d * maxf(full, grip_len + 40.0)
	(r["line"] as Line2D).points = PackedVector2Array([a, end])
	var hook: Sprite2D = r["hook"]
	hook.position = end + d * 30.0
	hook.rotation = PI * 0.5 - th


## Where his fists are now (world), from the pose: a little in front of his chest, arms straight up.
func _fists() -> Vector2:
	return player.position + Vector2(0.06 * PlayerPPM() * signf(player.scale.x), -ROPE_REACH)


static func PlayerPPM() -> float:
	return 200.0


## (23. 11.) The ladder whose foot he stands at (its bottom at his feet, within a step), or null.
func _ladder_foot():
	for r in _ropes:
		if r["kind"] == "ladder" and absf((r["a"] as Vector2).x - player.position.x) < 60.0 and absf(float(r["bottom"]) - player.position.y) < 40.0 				and not (_works_out and _works(_section_at(Vector2((r["a"] as Vector2).x, -10.0)))):   # (not through the works' front)
			return r
	return null


func _take_ladder(r: Dictionary) -> void:
	_rope = r
	_hand = Vector2((r["a"] as Vector2).x, clampf(player.position.y - ROPE_REACH, (r["a"] as Vector2).y, (r["b"] as Vector2).y))
	_jump_buf = 0.0
	move_state = "climb"
	player.hang = 1.0
	player.air = 0.0
	player.dive = 0.0
	player.roll = 0.0
	player.hang_one = false
	_rope_v = 0.0
	_climbed = 0.0
	run = 0.0
	sfx.play("land", -10.0, INF, 0.1)


func _grab_rope() -> void:
	if _rope_cool > 0.0 or diff_step < -1:
		return
	var fists := _fists()
	for r in _ropes:
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		if r["kind"] == "swing":
			a = Vector2(a.x, -1250.0)   # only the low part is in reach
		var near := Geometry2D.get_closest_point_to_segment(fists, a, b)
		if near.distance_to(fists) > (60.0 if r["kind"] == "climb" else 85.0):
			continue
		if r["kind"] == "climb" and fall < -200.0 and near.y > -200.0:
			continue
		if r["kind"] == "ladder" and (fall < -200.0 and near.y > float(r["bottom"]) - 200.0 or not _up_held):
			continue   # (user 23. 11.: "he grabs the ladder in mid flight by himself") only with the stick up
		if r.has("pul") and _works(_section_at(player.position)):
			continue   # (23. 11.) the washing line is outside the works' front: not caught from its gallery
		_rope = r
		_hand = near
		move_state = "climb" if r["kind"] == "ladder" else String(r["kind"])
		player.hang = 1.0
		player.air = 0.0
		player.dive = 0.0
		player.roll = 0.0
		sfx.play("land", -10.0, INF, 0.1)
		if move_state == "climb":
			player.hang_one = false
			_rope_v = 0.0
			_climbed = 0.0
		elif move_state == "zip":
			player.hang_one = true
			player.hang_cycle = -1.0
			if r.has("laundry"):   # riding a washing line over their heads: a slowed beat for free (rule 18) to shoot them
				_stunt_slow("zip", 1.6)
			_rope_v = maxf(250.0, absf(run) * 0.6)
			sfx.play("skid", -6.0, INF, 0.05)
		else:
			player.hang_one = false
			player.hang_cycle = -1.0
			var g := GRAVITY / (SWING_BOTTOM - (r["a"] as Vector2).y)
			var rel := (near - (r["a"] as Vector2))
			_swing_dir = signf(run) if absf(run) > 50.0 else (signf(player.scale.x))
			_theta = clampf(atan2(rel.x, rel.y) * _swing_dir, -SWING_AMP + 0.05, SWING_AMP - 0.05)
			_omega = sqrt(maxf(0.0, 2.0 * g * (cos(_theta) - cos(SWING_AMP))))
			sfx.play("creak", -8.0, near.x, 0.1)
		return


func _let_go(vx: float, vy: float) -> void:
	move_state = "jump"
	player.hang = 0.0
	player.hang_one = false
	player.hang_cycle = -1.0
	player.rotation = 0.0
	run = vx
	fall = vy
	_mantle_t = -1.0   # (audit 22. 11.) knocked off mid-haul: the next climb starts from the start
	_rope_cool = 0.45
	if _rope != null and _rope["kind"] == "swing":
		_draw_swing(_rope, 0.0, 0.0)
		_stunt_slow("swing", 1.0)   # flung off the swing: a slowed second for free, in the air (user, 16. 11.)
	_rope = null


func _on_rope(dir: float, jump: bool, down: bool, delta: float) -> void:
	var r: Dictionary = _rope
	player.ground = 0.0
	if move_state == "climb":
		var top: float = r["top"]
		if jump:   # lets go
			_let_go(signf(player.scale.x) * 160.0, 0.0)
			return
		var v := (700.0 if down else -330.0) if r["kind"] == "climb" else (520.0 if down else (-420.0 if _up_held else 0.0))   # up hand over hand; the stick down slides him down; a ladder: up only with the stick up (user 23. 11.), else he holds on
		_hand.y = clampf(_hand.y + v * delta, (r["a"] as Vector2).y, (r["b"] as Vector2).y)
		_climbed += absf(v * delta)
		player.hang_cycle = fmod(_climbed / 260.0, 1.0) if not down and v != 0.0 else (-1.0 if down else player.hang_cycle)
		player.position = Vector2((r["a"] as Vector2).x - 12.0 * signf(player.scale.x), _hand.y + ROPE_REACH)
		if not down and v != 0.0 and fmod(_climbed, 130.0) < absf(v) * delta:
			sfx.play("step1", -14.0, INF, 0.2)
		if _mantle_t >= 0.0:   # hands on the rail: he hauls himself up and over it onto the landing
			_mantle_t += delta
			var k := clampf(_mantle_t / 0.45, 0.0, 1.0)
			var e := k * k * (3.0 - 2.0 * k)
			player.position = _mantle_from.lerp(_mantle_to, e) + Vector2(0.0, -sin(e * PI) * 60.0)
			player.hang = 1.0 - e
			player.hang_cycle = -1.0
			player.crouch = sin(e * PI) * 0.8
			if k >= 1.0:
				_mantle_t = -1.0
				_let_go(0.0, 0.0)
				move_state = "ground"
				player.position = _mantle_to
				player.crouch = 0.4
				sfx.play("land", -8.0)
			return
		if not down and _hand.y <= (r["a"] as Vector2).y + 1.0:   # at the rail
			_mantle_t = 0.0
			_mantle_from = player.position
			_mantle_to = Vector2(player.position.x + 90.0, top)
			for c in catwalks:
				if absf(c.position.y - top) < 2.0 and player.position.x > c.position.x - 160.0 and player.position.x < c.end.x + 160.0:
					var into := 1.0 if absf(player.position.x - c.position.x) < absf(player.position.x - c.end.x) else -1.0
					_mantle_to = Vector2((c.position.x + 90.0) if into > 0.0 else (c.end.x - 90.0), top)
					if player.position.x > c.position.x + 90.0 and player.position.x < c.end.x - 90.0:   # (audit 22. 11.) over the deck: straight up
						_mantle_to = Vector2(player.position.x, top)
					if r["kind"] == "ladder":   # off the ladder onto the deck beside it, the way he faces
						var side := signf(player.scale.x)
						_mantle_to = Vector2(clampf((r["a"] as Vector2).x + side * 110.0, c.position.x + 90.0, c.end.x - 90.0), top)
			sfx.play("hit_cover", -14.0, INF, 0.1)   # his hand on the iron
			return
		if down and player.position.y >= float(r.get("bottom", 0.0)) - 2.0:
			player.position.y = float(r.get("bottom", 0.0))
			_let_go(0.0, 0.0)
			move_state = "ground"
			return
	elif move_state == "zip":
		var d: Vector2 = r["d"]
		_rope_v = minf(1250.0, _rope_v + GRAVITY * d.y * 0.55 * delta)
		_hand += d * _rope_v * delta
		player.position = _hand + Vector2(-0.06 * PlayerPPM() * signf(player.scale.x) * 0.0, ROPE_REACH)
		player.air = move_toward(player.air, 0.8, delta * 6.0)
		(r["hook"] as Sprite2D).position = _hand + Vector2(0.0, -6.0)
		for c in r.get("laundry", []):   # a washing line: what he passes is torn off and flutters down
			var cs := c as Sprite2D
			if cs.has_meta("gone") or absf(cs.position.x - _hand.x) > 60.0:
				continue
			cs.set_meta("gone", true)
			var tw := cs.create_tween().set_parallel()
			tw.tween_property(cs, "position", cs.position + Vector2(d.x * _rope_v * 0.35 + randf_range(-80.0, 80.0), -cs.position.y - 20.0), 1.1).set_ease(Tween.EASE_IN)
			tw.tween_property(cs, "rotation", randf_range(-1.2, 1.2), 1.1)
			tw.tween_property(cs, "modulate:a", 0.0, 0.5).set_delay(2.5)
		if jump or _hand.x * signf(d.x) >= (r["b"] as Vector2).x * signf(d.x):
			_let_go(d.x * _rope_v * 0.85, d.y * _rope_v * 0.25)
			var hk: Sprite2D = r["hook"]   # the hook slides on down the cable to the drum and stays there
			hk.create_tween().tween_property(hk, "position", (r["b"] as Vector2) + d * 160.0, 0.3)
			if not jump and r.has("pul"):   # (QUEUE §22) the line ends at a works' window: on through the glass
				var wi := _section_at((r["pul"] as Vector2) + Vector2(40.0, 300.0))
				if _works(wi):
					_crash_into_works(wi, r["pul"])
			return
	elif move_state == "swing":
		var L: float = SWING_BOTTOM - (_rope["a"] as Vector2).y   # (a hoist's rope is shorter than a crane's)
		var g := GRAVITY / L
		_omega -= g * sin(_theta) * delta
		_theta += _omega * delta
		var th := _theta * _swing_dir
		var grip: Vector2 = (r["a"] as Vector2) + Vector2(sin(th), cos(th)) * (L - 10.0)
		player.rotation = -th
		player.position = grip + Vector2(sin(th), cos(th)) * ROPE_REACH
		_draw_swing(r, th, L - 10.0)
		if absf(_omega) > 1.6 and absf(_theta) < 0.08:
			sfx.play("whiz", -10.0, grip.x, 0.1)
		var feet: Vector2 = player.position
		var into_box := false
		for b in boxes:
			if b.grow(10.0).has_point(feet + Vector2(0.0, -30.0)):
				into_box = true
		if jump or (_theta >= SWING_LET_GO and _omega > 0.0) or into_box:   # flung off at the top of the swing
			var v := Vector2(cos(th), -sin(th)) * _omega * L * _swing_dir
			player.rotation = 0.0
			player.position = grip + Vector2(0.0, ROPE_REACH)
			_let_go(v.x, v.y)
			_fling = 0.7
			player.air = 1.0
			return


## Steel turns a bullet: off a drum, a dumpster, a car, his shot glances away once, mirrored about the
## face it struck. Chapter II on, where there is steel enough on the docks to learn it.
func _ricochet(i: int, pos: Vector2) -> bool:
	if chapter < 2 or diff_step < 0:
		return false
	var info: Dictionary = box_info[i]
	if info["wood"] or info["kind"] in ["barrel", "stack"]:
		return false
	var r: Rect2 = boxes[i]
	var v: Vector2 = fx.hit_vel
	var n := _face_normal(r, pos, v)
	var out := v - 2.0 * v.dot(n) * n
	fx.spark(pos)
	sfx.play("whiz", -3.0, pos.x, 0.15)
	_word(["zing"], pos + Vector2(0.0, -70.0), 0.15)
	fx.shoot(pos + n * 16.0, out, true, 0.8)
	_bounce_t = 0.7
	return true


## Which face of a box a bullet going `v` came through at `pos`: the nearest edge it was heading into.
func _face_normal(r: Rect2, pos: Vector2, v: Vector2) -> Vector2:
	var d_left := absf(pos.x - r.position.x) if v.x > 0.0 else INF
	var d_right := absf(r.end.x - pos.x) if v.x < 0.0 else INF
	var d_top := absf(pos.y - r.position.y) if v.y > 0.0 else INF
	var best := minf(d_left, minf(d_right, d_top))
	if best == d_top:
		return Vector2.UP
	return Vector2.LEFT if best == d_left else Vector2.RIGHT


## A man who has given up: the gun goes down, the hands come up, he says it, then he backs off out
## of the fight and is gone. He never fires again and never comes back for the detective's back.
func _giving_up(e: Dictionary, delta: float) -> void:
	var m = e["node"]
	e["give_t"] = float(e["give_t"]) + delta
	var t: float = e["give_t"]
	var side: float = signf(m.position.x - player.position.x)
	var to_player: Vector2 = player.position - m.position + Vector2(0.0, SHOULDER.y)
	var walk := 0.0
	m.duck = move_toward(m.duck, 0.0, delta * 5.0)
	if t >= 0.0:
		if not m.disarmed:
			m.disarmed = true
			_drop_gun(m)
		m.hands_up = move_toward(m.hands_up, 1.0, delta * 4.0)
		if not e["said"] and t > 0.25:
			e["said"] = true
			if MenuScript.spared_total() + int(stats["spared"]) >= 2 and _guilt_now() <= 2 and randf() < 0.5:
				_bark(m, "quit", "", true)   # Frank's name for letting men walk has got round
			else:
				_say(m, ["DON'T SHOOT!", "I'M DONE!", "OKAY, OKAY!"].pick_random())
	if t > 1.7 and m.position.y == 0.0:   # backs away, eyes on the gun
		walk = side
		var step: float = side * 190.0 * delta
		var blocked := false
		for bx in boxes:
			if bx.grow(20.0).has_point(Vector2(m.position.x + step * 6.0, -60.0)):
				blocked = true
		if not blocked:
			m.position.x += step
		else:
			walk = 0.0
	if t > 3.6:
		m.modulate.a = move_toward(m.modulate.a, 0.0, delta * 1.4)
		if m.modulate.a <= 0.0:
			e["alive"] = false
			e["spared"] = true
			m.visible = false
			stats["spared"] += 1
			(stats["let_go"] as Array).append(String(e.get("name", "")))
			if not over:   # the rain washes a little ash off his face
				hud.set_conscience(_guilt_now() / 10.0, _pages_held(), true)
			_gain_xp(250)   # a man let go is worth as much as a clean kill or two
			if _perk("secondwind") and hp < max_hp and not over:   # letting him go puts something back in Frank
				hp += 1
				hud.set_health(float(hp) / max_hp)
				hud.toast("SECOND WIND")
			if _perk("questioning") and stats["spared"] == 1:
				var page_x := INF
				for pk in pickups:
					if pk["kind"] == "page" and is_instance_valid(pk["node"]):
						page_x = float(pk["at"].x)
				if page_x != INF:
					hud.caption(["He told me where to look.", "Eddie's page: %s." % ("up ahead" if page_x > player.position.x else "back the way I came")])
			var key := "%d:%d" % [chapter, map]
			if e.has("witness"):   # the lead, from his own mouth
				if ARGS.has("--log-sets"): print("WITNESS SPARED")
				hud.caption(WITNESS[key][3])
				if _auto == "":
					MenuScript.set_story("witness_" + key.replace(":", "-"), "spared")
				return
			if stats["spared"] == 1 and TESTIMONY.has(key):   # the first man let go on a map talks on his way out
				hud.caption(["He talked before he ran.", String(TESTIMONY[key])])
				var was := _pages_held()
				if _auto == "":
					MenuScript.set_story("testimony_" + key.replace(":", "-"), "yes")
				sfx.play("page", -4.0, INF, 0.0)
				hud.page_in(get_viewport().get_canvas_transform() * (m.position + Vector2(0.0, -260.0)), _guilt_now() / 10.0, maxi(was, _pages_held()) if _auto == "" else was + 1)
			return
	m.set_state(walk, to_player.normalized() * 100.0, delta)


## The gun shot out of a man's hand: sparks and a ring of steel where the bullet struck it, a beat of
## slowed time, the gun spinning away from Frank and clattering down (a tommy gun or a shotgun can be
## picked up once it lies still), the man wringing his hand before his hands go up.
var _flying_guns: Array = []
func _disarm(e: Dictionary, at: Vector2) -> void:
	if _auto != "":
		print("DISARM slow=", slow_on)
	var m = e["node"]
	for k in 3:
		fx.spark(at)
	sfx.play("clink", 2.0, at.x, 0.06)
	sfx.play("hit_cover", -2.0, at.x, 0.1)
	_word(["clink"], at + Vector2(0.0, -80.0), 0.2)
	_impact(0.14, 0.18)
	_shake = maxf(_shake, 0.06)
	m._flinch = 1.0
	m.disarmed = true
	var src: Sprite2D = m._gun
	var g := Sprite2D.new()   # his own gun, the same drawing he held, now on its own
	g.texture = src.texture
	g.offset = src.offset
	g.global_scale = src.global_scale.abs()
	g.flip_h = src.global_scale.x < 0.0
	g.global_position = src.global_position
	g.global_rotation = src.global_rotation
	g.modulate = _undo_night(0.55)   # (audit: lit like the figures, or nobody saw it fly)
	g.z_index = 1
	add_child(g)
	src.visible = false
	var away := signf(m.position.x - player.position.x)
	_flying_guns.append({"node": g, "v": Vector2(away * randf_range(380.0, 520.0), -randf_range(760.0, 940.0)),
		"spin": away * randf_range(13.0, 19.0), "ground": m.position.y - 10.0, "bounce": 0, "kind": String(e["type"])})
	_say(m, ["MY HAND!", "AAGH!", "OKAY, OKAY!"].pick_random())
	_give_up(e, 0.7)
	e["said"] = true   # he has said it already: no second line over the first
	if not _stand and diff_step >= 0:   # style: a man taken out of the fight without a kill
		stats["score"] += 150
		_gain_xp(150)
		_combo_t = maxf(_combo_t, COMBO_GAP)
		hud.combo(_combo, 150, "DISARMED")


## A bullet through a man's hat: the hat spins off and lands on the pavement (it stays there), he
## flinches and holds his fire a moment. Style, not a kill.
func _hat_off(e: Dictionary, at: Vector2) -> void:
	var m = e["node"]
	var info: Dictionary = m.lose_hat()
	var g := Sprite2D.new()
	g.texture = info["tex"]
	g.centered = false
	g.offset = info["offset"]
	g.modulate = _undo_night(0.45)
	g.z_index = 1
	add_child(g)
	g.global_transform = info["xform"]
	var away := signf(m.position.x - player.position.x)
	_flying_guns.append({"node": g, "v": Vector2(away * randf_range(260.0, 380.0), -randf_range(650.0, 820.0)),
		"spin": away * randf_range(7.0, 11.0), "ground": m.position.y - 6.0, "bounce": 0, "kind": "hat"})
	sfx.play("whiz", -2.0, at.x, 0.1)
	m._flinch = 1.0
	e["cool"] = maxf(float(e["cool"]), 1.2)   # he ducks his head and forgets to shoot for a moment
	e["timer"] = maxf(float(e["timer"]), 1.0)
	e["seen"] = true
	_say(m, ["MY HAT!", "HEY!", "WHAT THE--"].pick_random())
	_impact(0.1, 0.25)
	if not _stand and diff_step >= 0:
		stats["score"] += 100
		_gain_xp(100)
		_combo_t = maxf(_combo_t, COMBO_GAP)
		hud.combo(_combo, 100, "HAT TRICK")


func _tick_flying_guns(delta: float) -> void:
	for i in range(_flying_guns.size() - 1, -1, -1):
		var f: Dictionary = _flying_guns[i]
		var g: Sprite2D = f["node"]
		if not is_instance_valid(g):
			_flying_guns.remove_at(i)
			continue
		var v: Vector2 = f["v"]
		v.y += 2300.0 * delta
		g.position += v * delta
		g.rotation += float(f["spin"]) * delta
		if g.position.y >= float(f["ground"]) and v.y > 0.0:
			g.position.y = float(f["ground"])
			sfx.play("hit_cover", -8.0 - 6.0 * int(f["bounce"]), g.position.x, 0.2)
			if int(f["bounce"]) == 0:   # one bounce off the pavement, then it lies where it stops
				v = Vector2(v.x * 0.45, -v.y * 0.32)
				f["spin"] = float(f["spin"]) * 0.35
				f["bounce"] = 1
			else:
				g.rotation = 0.0 if absf(wrapf(g.rotation, -PI, PI)) < PI * 0.5 else PI
				_flying_guns.remove_at(i)
				if String(f["kind"]) in ["tommy", "shotgun"] and _gun_open(String(f["kind"])):   # a gun worth having: Frank can take it
					_add_pickup(String(f["kind"]), g.position + Vector2(0.0, 10.0))
					g.queue_free()
				continue
		f["v"] = v


func _drop_gun(m) -> void:
	var g := Sprite2D.new()   # his own gun, the same drawing he held, flat on the wet pavement
	g.texture = m._gun.texture
	g.offset = m._gun.offset
	g.scale = m._gun.scale * absf(m.scale.y)
	g.flip_h = player.position.x < m.position.x
	g.position = m.position + Vector2(signf(player.position.x - m.position.x) * 50.0, -10.0)
	g.rotation = randf_range(-0.12, 0.12)
	g.modulate = _undo_night(0.6)   # lit like the figures are, so it reads on the dark pavement
	g.z_index = 0
	add_child(g)
	sfx.play("hit_cover", -10.0, m.position.x, 0.2)


## A kill lands: time all but stops for a moment (`secs` real seconds at `scale`).
func _impact(secs: float, scale: float) -> void:
	if _auto == "play":
		return
	_stop_t = maxf(_stop_t, secs)
	_stop_scale = minf(_stop_scale, scale)


## Slowed time: Shift held, or the stopwatch button tapped on and off. It drains a meter that refills.
func _slow_time(real: float) -> void:
	if hud.slow_tapped:   # the stopwatch toggles it, also mid-air: a tap in a slowed dive lets time run again
		if Engine.time_scale < 1.0:
			slow_on = false
			_slow_cancelled = move_state in ["dive", "flip"]
		else:
			slow_on = true
			_slow_cancelled = false
		hud.slow_tapped = false
	if move_state not in ["dive", "flip"]:
		_slow_cancelled = false
	# a dive slows time by itself for as long as he is in the air
	if over:   # the fall of the detective plays in slow motion, then time runs on
		_death_t += real
		Engine.time_scale = 0.3 if _death_t < 1.3 else 1.0
		hud.set_slow(slow_left, false)
		return
	if _free_slow > 0.0:   # a stunt's own slowed beat (door kicked in, a window, a swing on a rope): free, the meter untouched
		_free_slow -= real
		Engine.time_scale = SLOW_SCALE
		hud.set_slow(slow_left, true)
		if not _slowed_was:
			sfx.play("slow_in", -3.0, INF, 0.0)
			_slowed_was = true
		return
	var air_slow: bool = (move_state == "dive" or move_state == "flip" or move_state == "zip") and not _slow_cancelled
	var want := (slow_on or air_slow or Input.is_physical_key_pressed(KEY_SHIFT)) and not over
	var slowed := Engine.time_scale < 1.0
	if want and (slow_left > 0.0 if slowed else slow_left > 0.2):   # an empty meter must refill a little first
		slow_left = maxf(0.0, slow_left - real * diff["drain"])
		Engine.time_scale = SLOW_SCALE
	else:
		if slow_left == 0.0 or not want:
			slow_on = false
		slow_left = minf(1.0, slow_left + real * diff["refill"])
		Engine.time_scale = 1.0
	hud.set_slow(slow_left, Engine.time_scale < 1.0)
	var now_slow := Engine.time_scale < 1.0
	_slow_base = now_slow
	if now_slow != _slowed_was:
		sfx.play("slow_in" if now_slow else "slow_out", -3.0, INF, 0.0)
		_slowed_was = now_slow
	if _stop_t > 0.0:   # an impact: the world holds its breath for a few frames
		_stop_t -= real
		Engine.time_scale *= _stop_scale
		if _stop_t <= 0.0:
			_stop_scale = 1.0


## The nearest lamp throws the figure's shadow onto the wall behind it, leaning away from the light.
func _cast_shadow(p) -> void:
	var best := Vector2.INF
	for i in lamps.size():
		var l: Vector2 = lamps[i]
		if lamp_info[i]["on"] and absf(l.x - p.position.x) < absf(best.x - p.position.x):
			best = l
	var dx: float = p.position.x - best.x
	var reach := 900.0
	var k := clampf(1.0 - absf(dx) / reach, 0.0, 1.0)
	p.set_shadow(dx * 0.9, clampf(dx / 600.0, -0.9, 0.9), 0.45 * k)


## The dream and the memories: shadows for men, nobody gives up, the fire keeps its colour.
func _unreal() -> bool:
	return level.get("dream", false) or level.get("memory", false)


func _dump_textures() -> void:
	var seen := {}
	for n in get_tree().root.find_children("*", "", true, false):
		var texs: Array = []
		for prop in ["texture", "normal_texture"]:
			if prop in n and n.get(prop) is Texture2D:
				texs.append(n.get(prop))
		for t in texs:
			if t is CanvasTexture:
				texs.append((t as CanvasTexture).diffuse_texture)
				continue
			if t != null and not seen.has(t.get_rid()):
				seen[t.get_rid()] = [t.get_width() * t.get_height() * 4, t.resource_path, t.get_width(), t.get_height(), n.get_class()]
	var arr: Array = seen.values()
	arr.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
	var tot := 0
	for t in arr: tot += int(t[0])
	print("  tree textures ", arr.size(), " total MB ", tot / 1048576)
	var extra := {}
	for n in get_tree().root.find_children("*", "", true, false):
		var cands: Array = []
		for prop in ["texture", "normal_texture"]:
			if prop in n and n.get(prop) is CanvasTexture:
				var ct: CanvasTexture = n.get(prop)
				cands.append_array([ct.normal_texture, ct.specular_texture])
		if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial:
			var sm: ShaderMaterial = (n as CanvasItem).material
			for u in sm.shader.get_shader_uniform_list():
				var v = sm.get_shader_parameter(u["name"])
				if v is Texture2D:
					cands.append(v)
		if n is Label or n is Button:
			pass
		for t in cands:
			if t != null and not seen.has(t.get_rid()) and not extra.has(t.get_rid()):
				extra[t.get_rid()] = [t.get_width() * t.get_height() * 4, t.resource_path, t.get_width(), t.get_height(), n.name]
	var ea: Array = extra.values()
	ea.sort_custom(func(x, y): return int(x[0]) > int(y[0]))
	var et := 0
	for t in ea: et += int(t[0])
	print("  EXTRA (normals, shader params) ", ea.size(), " MB ", et / 1048576)
	for t in ea.slice(0, 20): print("   ", int(t[0]) / 1048576, " MB ", t[2], "x", t[3], " ", t[1], " ", t[4])
	for t in arr.slice(0, 25): print("   ", int(t[0]) / 1048576, " MB ", t[2], "x", t[3], " ", t[1], " ", t[4])


func _shot(shot_name: String) -> void:
	if "--texdump" in ARGS:
		_dump_textures()
		print("  buffers %d MB" % (int(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)) / 1048576))
	print("shot ", shot_name, "  fps ", Engine.get_frames_per_second(), "  textures %d MB  static %d MB" % [
		int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576, OS.get_static_memory_usage() / 1048576])
	# every screen of paper and text is checked as it is pictured: text past its box or its paper's
	# inner line, text over text, paper over paper, anything at the screen's edge, "A · B" strings
	var view := get_viewport().get_visible_rect().size
	var top := -1
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.visible and (n as CanvasLayer).layer >= 20 and (n as CanvasLayer).layer > top:
			top = (n as CanvasLayer).layer
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl.visible and cl.layer == top:
			for line in load("res://paper.gd").audit(cl, view):
				print("UI BAD [", shot_name, "] ", line)
	if shot_name.begins_with("film") or shot_name.begins_with("cap"):
		for line in load("res://paper.gd").audit(hud, view):
			if "caption" in line or "inner line" in line or "overlap" in line:
				print("UI BAD [", shot_name, "] ", line)
	if _tt >= 0.0:
		var states := []
		for e in enemies:
			states.append("%d:%s:hp%d:duck%.1f" % [int(e["node"].position.x), "alive" if e["alive"] else "dead", e["hp"], e["node"].duck])
		print("  player x ", int(player.position.x), " duck ", snappedf(player.duck, 0.1), "  ", states)
	await RenderingServer.frame_post_draw
	if not is_inside_tree():   # the scene was restarted while waiting for the frame
		return
	var img := get_viewport().get_texture().get_image()
	if img.save_png("res://_shots/" + shot_name + ".png") != OK:   # (an exported pack: res:// is read-only)
		DirAccess.make_dir_recursive_absolute("user://_shots")
		img.save_png("user://_shots/" + shot_name + ".png")


func _alc_want() -> float:   # (--test=alcove[:shoot][@x]: the doorway nearest x, else the playground's last one)
	return float(_auto.split("@")[1]) if "@" in _auto else 36328.0
