extends Node2D
# A character built from drawn parts. No stored animation: every frame the code decides where the
# feet, hips and hands are, solves the knees and elbows, and lays each drawn part between its two joints.

const PPM := 200.0   # world pixels per metre
## The figure's drawings carry mipmaps (their .import): read them, so fine hatching shrinks to a clean
## grey on a phone instead of shimmering. Only on those drawings: a texture without mipmaps vanishes under it.
const MIPS := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
const MASK_FIGURE := 1 | 4   # lit by the street lights (1) and by the figure's own back light (4)

# Back to front. The far arm and leg reuse the near ones' drawings, darkened.
const ORDER := [
	["uarm_b", "uarm", true], ["farm_b", "farm", true], ["gun2", "", false],
	["thigh_b", "thigh", true], ["shin_b", "shin", true],
	["thigh_f", "thigh", false], ["shin_f", "shin", false],
	["skirt", "skirt", false],   # the coat below the belt hangs over the legs
	["torso", "torso", false], ["head", "head", false], ["collar_front", "", false],
	["gun", "", false],
	["uarm_f", "uarm", false], ["collar_back", "", false], ["farm_f", "farm", false],
]

# The guns, drawn facing right: picture, length in metres (a touch over life size, so they read on a
# phone), and points on the picture as fractions of it: where the hand grips, the muzzle, and for the
# long guns where the other hand holds it.
const GUNS := {
	"revolver": {"tex": "res://art/guns/revolver.png", "len": 0.34, "grip": Vector2(0.17, 0.56), "muzzle": Vector2(1.0, 0.13),
		"hand": {"tex": "res://art/guns/revolver_hand.png", "len": 0.37, "wrist": Vector2(0.03, 0.63), "muzzle": Vector2(1.0, 0.115)}},
	"pistol": {"tex": "res://art/guns/pistol.png", "len": 0.33, "grip": Vector2(0.21, 0.55), "muzzle": Vector2(1.0, 0.13),
		"hand": {"tex": "res://art/guns/pistol_hand.png", "len": 0.43, "wrist": Vector2(0.03, 0.64), "muzzle": Vector2(1.0, 0.137)}},
	"tommy": {"tex": "res://art/guns/tommy.png", "len": 0.92, "grip": Vector2(0.42, 0.6), "muzzle": Vector2(1.0, 0.16), "fore": Vector2(0.76, 0.58), "stock": true},
	"shotgun": {"tex": "res://art/guns/shotgun.png", "len": 1.0, "grip": Vector2(0.31, 0.42), "muzzle": Vector2(1.0, 0.07), "fore": Vector2(0.68, 0.3), "stock": true},
	"rifle": {"tex": "res://art/guns/rifle.png", "len": 1.15, "grip": Vector2(0.27, 0.6), "muzzle": Vector2(1.0, 0.33), "fore": Vector2(0.6, 0.5), "stock": true},
	"hook": {"tex": "res://art/guns/hook.png", "len": 0.34, "grip": Vector2(0.08, 0.45), "muzzle": Vector2(0.92, 0.85)},
	"dynamite": {"tex": "res://art/guns/dynamite.png", "len": 0.22, "grip": Vector2(0.35, 0.5), "muzzle": Vector2(1.0, 0.2)},
}
var weapon := ""
# (user 25. 11.: "he does not hold the gun, no finger on the trigger") a figure with cfg "grip_cuff" holds a one-hand gun
# with a drawn hand (art/guns/<gun>_hand.png: the fingers round the grip, the index on the trigger, art_src 364/365):
# the forearm loses its fist (<dir>/farm_grip.png, gen/grip_cuff.py) and the hand comes out of the cuff
var _grip := false
var _grip_tex: Texture2D
var _legs := {}            # "f"/"b" -> the bending leg mesh
var _pelvis: Polygon2D
var _crooks := {}          # "f"/"b" -> cloth under the leg: the bent mesh leaves a hole in the crook of a tightly folded knee
var _leg_shadows := {}
var _flinch := 0.0          # a hit knocks him back a moment
var _hit_part := ""         # where the last bullet hit him: the reaction depends on it
var _hit_dip := 0.0         # a leg hit: the knee buckles
var _wounds: Array = []     # where he has been hit, kept on the bones as he moves
const LEG_ROWS := 14
const LEG_HIP := 0.06       # the leg drawing: rows of the hip joint, the knee and the ankle (top of the shoe)
const LEG_KNEE := 0.47
const LEG_ANKLE := 0.89
const LEG_AXIS := 0.36      # the leg's centre line across the drawing
var _skirt_mesh: Polygon2D   # the coat below the belt as a bending sheet instead of one stiff board
var _skirt_shadow: Polygon2D
const SKIRT_ROWS := 7
const SKIRT_COLS := 4
var _gun2: Sprite2D   # the second pistol, in the far hand
var dual := false
var side := "revolver"   # Frank's side gun: "revolver" or "beretta" (drawn as the pistol)
var _skirt_fly: Sprite2D
var _skirt_poses := {}   # "run" / "air": drawn coats (art_src 159) the hanging one fades into, belt middle at (W/2, 8)
var _skirt_w := {}
var _farm_tex: Texture2D        # the free hand as drawn (relaxed) ...
var _farm_open_tex: Texture2D   # ... and flung open for balance in the air (art_src 156)
const SKIRT_FLY_WAIST := Vector2(528.0, 10.0)   # the belt's middle on art/detective/skirt_fly.png (art_src 155)   # TWO GUNS: a second revolver in the far hand
# The lead pipe (art/guns/pipe.png) he keeps in his coat: swing 0..1 is one blow (wind up over the
# shoulder, down onto the man, follow through), -1 = not swinging. The gun goes back in the coat meanwhile.
const PIPE_LEN := 0.62
const PIPE_GRIP := Vector2(0.17, 0.234)
var swing := -1.0
var _pipe: Sprite2D
var _left_shot := false   # with two pistols: the next shot comes from the far hand

# Set before the node enters the tree. See main.gd for the two characters.
var cfg := {}
var night := Color.WHITE        # inverse of the scene's darkness, so the outline keeps its colour
var body_boost := Color.WHITE
var _body: CanvasGroup

const OUTLINE_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec3 line = vec3(0.92, 0.9, 0.87);
uniform vec3 boost = vec3(1.0);
uniform float width = 1.0;
void fragment() {
	float fade = COLOR.a;
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	float m = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		m = max(m, textureLod(screen_texture, SCREEN_UV + vec2(cos(a), sin(a)) * SCREEN_PIXEL_SIZE * width, 0.0).a);
	}
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec3 col = mix(line, c.rgb * boost, c.a);
	// a firm ink contour round the whole silhouette, like the inked outline of a comic figure: it
	// has to survive being a few centimetres tall on a phone
	COLOR = vec4(col, max(c.a, m * 0.92) * fade);
}
"""

var _outline_mat: ShaderMaterial
var _outline_w := 1.8
var _rim := 0.0
var rim_line := Vector3(-1.0, 0.0, 0.0)   # (an own contour colour, the dream's shades: a glow of embers; x < 0: the usual cream)
## In slowed time the figures' contour thickens and brightens (audit 17. 11., Gemini: dark coats lost on dark walls).
func set_rim(k: float) -> void:
	if _outline_mat == null or absf(k - _rim) < 0.02:
		return
	_rim = k
	_outline_mat.set_shader_parameter("width", _outline_w * (1.0 + 0.7 * k))
	_outline_mat.set_shader_parameter("line", rim_line if rim_line.x >= 0.0 else Vector3(0.8, 0.77, 0.7).lerp(Vector3(0.97, 0.95, 0.9), k))


var _spr := {}
var _ang := {}
var _len := {}
var _gun: Sprite2D
var _collars: Array[Sprite2D] = []
var _phase := 0.0
var _moving := 0.0   # 0 standing .. 1 running, eased so the pose blends instead of snapping
var _aim := Vector2.RIGHT
var hands_up := 0.0   # 0..1: a man giving up, gun dropped, both hands raised beside his hat
# On a rope: 0..1 how much he hangs by his hands. hang_cycle: hand over hand on a climb (0..1, -1 = just
# hanging); hang_one: one hand on a cable, the other keeps the gun up. hang_top: where his hands are,
# local metres above his feet (negative y), so main.gd can hang him where the rope is.
var hang := 0.0
var hang_cycle := -1.0
var hang_one := false
var hang_top := -2.3
var dead_far := 0.25   # where the far arm lies off the near one once he is down
var disarmed := false  # his gun is on the pavement: it never comes back to his hand
var _aim_angle := 0.0
var _vel := Vector2.ZERO          # how fast the figure is really moving, for the coat
# (user 25. 11.: "mind Frank's coat so it does not behave oddly - try a better animation for it") the long coat's spine
# is SIMULATED: a chain of points from the belt down (one per row of the skirt grid), with gravity, the body's inertia
# (it lags a start and swings on after a stop), air drag (it streams back in a run), length kept, bending limited like
# cloth, never through the pavement. The grid's columns hang across it as before. Before: a kinematic curve plus drawn
# coats turned whole - in a roll or a flip the drawn coat stood up off him like a board.
var _coat := PackedVector2Array()
var _coat_prev := PackedVector2Array()
var _coat_clock := -1.0
var _coat_v := Vector2.ZERO
var _coat_hug := 0.0   # 0..1: in a tumble the coat wraps along the thighs (spun free it flew out like a sail)
var _coat_thigh := Vector2.DOWN
var _last := Vector2.ZERO
var _have_last := false
var _clock := 0.0
var _tail_dir := Vector2(0.0, 0.5)   # where the coat tail hangs to, from its root
var air := 0.0       # 0 on the ground .. 1 in a jump: the legs tuck up
var air_v := 0.0     # in a jump: -1 going up hard .. 0 at the top .. 1 coming down: the pose follows the arc
var dive := 0.0      # 0 upright .. 1 flying flat, head first
var dive_side := 1.0 # 1 = he dives the way he faces, -1 = backwards
var crouch := 0.0    # 0 standing .. 1 deep knee bend: soaks up a landing
var slide := 0.0     # 0 .. 1 sliding along the ground, legs first
var duck := 0.0      # 0 .. 1 crouched low behind cover
var slide_side := 1.0
## How thick each body part is for bullets, in metres either side of its bone. Checked in this order,
## so a bullet through the head counts as a head shot.
const HIT_RADIUS := {"head": 0.14, "torso": 0.17, "skirt": 0.11, "uarm_f": 0.06, "farm_f": 0.055, "thigh_f": 0.085, "thigh_b": 0.085, "shin_f": 0.07, "shin_b": 0.07}
var _bones := {}   # sprite name -> [start, end] in this node's pixels, as last posed
var size := 1.0   # a boss is drawn a little bigger
static var fig_scale := -1.0   # test comparison (--figscale=): every figure drawn bigger
var _dead := false   # set by die_pose: the arms hang straight from the shoulders, no aiming, no IK twists
var roll := 0.0      # extra turn of the whole body, radians: a tumble out of a dive

# The move sheet (user 17. 11.: "the new moves borrow the old poses - give him animations for them"): each new stunt
# is a short clip of hand-set key poses, blended over whatever the code pose is (in at the start, out at the end),
# so a kick is a kick and not a dive. A key: t (0..1 of the clip), fa / fb = the near / far foot (metres from the
# figure's origin, x forward, before the legs' turn), legs = the legs' turn about the hip, lean = the torso's,
# drop = how far the hips sink, spin = whole turns of the body (a flip), far = the free hand off its shoulder.
# Angles and x are in the clip's own forward (clip_side: +1 = the way he faces). Played by main.gd (play_clip).
const CLIPS := {
	# a dive at a door or a man ahead turns into a flying kick: feet first, the body laid back behind the boot
	"fly_kick": {"len": 0.42, "keys": [
		[0.0, {"fa": Vector2(0.3, -0.62), "fb": Vector2(-0.12, -0.3), "legs": -0.2, "lean": -0.35, "drop": 0.12, "far": Vector2(-0.25, -0.1)}],
		[0.35, {"fa": Vector2(0.88, -0.78), "fb": Vector2(0.18, -0.42), "legs": -0.15, "lean": -1.0, "drop": 0.05, "far": Vector2(-0.3, -0.2)}],
		[0.8, {"fa": Vector2(0.88, -0.78), "fb": Vector2(0.14, -0.38), "legs": -0.15, "lean": -0.95, "drop": 0.05, "far": Vector2(-0.3, -0.2)}],
		[1.0, {"fa": Vector2(0.35, -0.45), "fb": Vector2(-0.1, -0.2), "legs": -0.15, "lean": -0.25, "drop": 0.1, "far": Vector2(-0.22, -0.05)}]]},
	# off a wall (clip_side = toward the wall): a foot planted on it, the knee folded, then the leg drives him off
	"wall_kick": {"len": 0.42, "keys": [
		[0.0, {"fa": Vector2(0.45, -0.78), "fb": Vector2(-0.05, -0.2), "legs": 0.05, "lean": 0.3, "drop": 0.2, "far": Vector2(0.28, 0.05)}],
		[0.35, {"fa": Vector2(0.55, -0.35), "fb": Vector2(-0.2, -0.3), "legs": -0.1, "lean": -0.35, "drop": 0.05, "far": Vector2(-0.25, -0.3)}],
		[1.0, {"fa": Vector2(0.15, -0.4), "fb": Vector2(-0.25, -0.12), "legs": 0.0, "lean": -0.15, "drop": 0.05, "far": Vector2(-0.22, -0.12)}]]},
	# thrown up by an awning: tucked tight, once over forward, opening to land
	"flip": {"len": 0.75, "keys": [
		[0.0, {"fa": Vector2(0.18, -0.45), "fb": Vector2(-0.02, -0.4), "legs": 0.0, "lean": 0.2, "drop": 0.25, "spin": 0.0, "far": Vector2(0.15, 0.15)}],
		[0.2, {"fa": Vector2(0.28, -0.62), "fb": Vector2(0.18, -0.6), "legs": 0.0, "lean": 0.45, "drop": 0.3, "spin": 0.2, "far": Vector2(0.25, 0.3)}],
		[0.75, {"fa": Vector2(0.28, -0.62), "fb": Vector2(0.18, -0.6), "legs": 0.0, "lean": 0.45, "drop": 0.3, "spin": 0.95, "far": Vector2(0.25, 0.3)}],
		[1.0, {"fa": Vector2(0.12, -0.15), "fb": Vector2(-0.1, -0.05), "legs": 0.0, "lean": 0.05, "drop": 0.08, "spin": 1.0, "far": Vector2(-0.2, -0.1)}]]},
	# into a dive: a beat of push-off - leaning hard forward, the back leg driving, the free hand reaching (audit 17. 11.)
	"dive_push": {"len": 0.22, "keys": [
		# a lunge: the front foot planted, its knee over it, the back leg already reaching behind; then the front leg
		# drives him off it long and low and the back leg swings up into the flat dive (no knee drawn up forward)
		[0.0, {"fa": Vector2(0.3, 0.0), "fb": Vector2(-0.36, -0.03), "legs": 0.15, "lean": 0.55, "drop": 0.2, "far": Vector2(0.35, 0.05)}],
		[0.55, {"fa": Vector2(0.06, -0.02), "fb": Vector2(-0.5, -0.3), "legs": 0.75, "lean": 1.1, "drop": 0.04, "far": Vector2(0.42, 0.0)}],
		[1.0, {"fa": Vector2(-0.03, -0.05), "fb": Vector2(-0.1, -0.18), "legs": 1.35, "lean": 1.4, "drop": 0.0, "far": Vector2(0.42, 0.0)}]]},
	# backwards (he aims behind him and dives away, the shootdodge on his back): both feet push off under him and he
	# tips back flat; x is in the dive's direction, so his feet in front of him are at minus x
	"dive_back": {"len": 0.22, "keys": [
		[0.0, {"fa": Vector2(-0.16, 0.0), "fb": Vector2(0.1, 0.0), "legs": 0.1, "lean": 0.35, "drop": 0.22, "far": Vector2(0.1, 0.1)}],
		[0.55, {"fa": Vector2(-0.22, -0.1), "fb": Vector2(-0.02, -0.06), "legs": 0.65, "lean": 0.95, "drop": 0.05, "far": Vector2(0.2, 0.05)}],
		[1.0, {"fa": Vector2(0.03, -0.05), "fb": Vector2(-0.05, -0.1), "legs": 1.35, "lean": 1.4, "drop": 0.0, "far": Vector2(0.25, 0.0)}]]},
	# through a window: the free arm over the face against the glass, knees up, curled
	"window": {"len": 0.5, "keys": [
		[0.0, {"fa": Vector2(0.25, -0.5), "fb": Vector2(0.02, -0.42), "legs": 0.1, "lean": 0.3, "drop": 0.2, "far": Vector2(0.3, -0.12)}],
		[0.7, {"fa": Vector2(0.28, -0.55), "fb": Vector2(0.05, -0.48), "legs": 0.15, "lean": 0.35, "drop": 0.22, "far": Vector2(0.32, -0.15)}],
		[1.0, {"fa": Vector2(0.15, -0.3), "fb": Vector2(-0.12, -0.15), "legs": 0.0, "lean": 0.1, "drop": 0.1, "far": Vector2(-0.2, -0.1)}]]},
}
var clip := ""
var clip_t := 0.0     # seconds into it
var clip_side := 1.0
func play_clip(name: String, side := 1.0) -> void:
	if not CLIPS.has(name):
		return
	clip = name
	clip_t = 0.0
	clip_side = side


## The clip's pose now (its keys eased into each other) and how much of it shows (eased in and out).
func _clip_now() -> Array:
	var c: Dictionary = CLIPS[clip]
	var u := clampf(clip_t / float(c["len"]), 0.0, 1.0)
	var keys: Array = c["keys"]
	# (user 24. 11.: "mechanical" - each key was eased in and out, so the body stopped at every key) a Catmull-Rom spline
	# through the keys: the motion flows through them, slowing only where the keys themselves are close
	var n := keys.size()
	var i := n - 2
	for k in n - 1:
		if u <= float(keys[k + 1][0]):
			i = k
			break
	var span := maxf(0.0001, float(keys[i + 1][0]) - float(keys[i][0]))
	var v := clampf((u - float(keys[i][0])) / span, 0.0, 1.0)
	var k0: Dictionary = keys[maxi(i - 1, 0)][1]
	var k1: Dictionary = keys[i][1]
	var k2: Dictionary = keys[i + 1][1]
	var k3: Dictionary = keys[mini(i + 2, n - 1)][1]
	var out := {}
	for key in k1:
		var p0 = k0.get(key, k1[key])
		var p1 = k1[key]
		var p2 = k2.get(key, p1)
		var p3 = k3.get(key, p2)
		out[key] = 0.5 * (2.0 * p1 + (p2 - p0) * v + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * v * v + (3.0 * p1 - p0 - 3.0 * p2 + p3) * v * v * v)
	var w := smoothstep(0.0, 0.12, u) if clip != "flip" else 1.0
	w *= 1.0 - smoothstep(0.85, 1.0, u)
	return [out, w]
var ground := 0.0    # where the pavement is below the figure's origin, in pixels (0 when standing on it)
var reload := 0.0    # 0: not reloading; else how far through it (0..1): the gun comes in to the chest
static var heavy := false   # (trial 24. 11., main.gd _lab) more weight: deeper lean, a harder kick, a bigger step, a looser coat
var at_ease := false # (user 24. 11.: "he holds the gun arm out stiff all the time") nobody to shoot at: the gun comes down by his side
var ease := 0.0      # 0 the gun up on its aim .. 1 down by the leg, the arm swinging with the walk
var recoil := 0.0    # set after a shot: the gun arm kicks up by this many radians and settles back
var _shadow: CanvasGroup   # a black copy of the figure, thrown onto the wall by the nearest lamp
var _shadow_spr := {}


static func _fs() -> float:
	if fig_scale < 0.0:
		fig_scale = 1.18   # main.gd FIG
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--figscale="):
				fig_scale = float(a.trim_prefix("--figscale="))
	return fig_scale


func _ready() -> void:
	# All the drawn parts go into one group, which is drawn as a single picture; its shader then
	# inks an off-white line around the whole silhouette, so the figure stands off the dark street.
	_body = CanvasGroup.new()
	_body.fit_margin = 14.0
	_body.clear_margin = 14.0
	var sh := Shader.new()
	sh.code = OUTLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var look2 := not OS.get_cmdline_user_args().has("--oldlook")   # (feedback 17. 11.: a pale contour reads on dark walls)
	mat.set_shader_parameter("line", Vector3(0.8, 0.77, 0.7) if look2 else Vector3(0.03, 0.03, 0.035))
	mat.set_shader_parameter("width", 1.8 if look2 else 2.8)   # the cream contour keeps a dark coat apart from a dark wall
	mat.set_shader_parameter("boost", Vector3(body_boost.r, body_boost.g, body_boost.b))
	_body.material = mat
	_outline_mat = mat
	_outline_w = (1.8 if look2 else 2.8) * (0.7 if heavy else 1.0)
	add_child(_body)
	var parts: Dictionary = cfg["parts"]
	for key in parts:
		if not parts[key] is Dictionary:
			continue
		var p: Dictionary = parts[key]
		var d: Vector2 = p["b"] - p["a"]
		_ang[key] = d.angle()
		_len[key] = d.length() / float(p["ppm"])
	for row in ORDER:
		var part: String = row[1]
		if row[0] == "gun" or row[0] == "gun2":
			var g := Sprite2D.new()
			g.centered = false
			g.light_mask = 1   # no normal map: the figure's own rim light would wash the steel out
			g.modulate = Color(0.78, 0.78, 0.8)
			g.texture_filter = MIPS
			_body.add_child(g)
			if row[0] == "gun":
				_gun = g
			else:
				_gun2 = g
			continue
		if String(row[0]).begins_with("collar"):
			if parts.has(row[0]):   # a piece of the torso drawing laid over the head or the sleeve again
				var c := Sprite2D.new()
				# (its own cut of the torso drawing when there is one: only the near half of a raised collar)
				c.texture = _tex(String(cfg["dir"]) + ("collar" if ResourceLoader.exists(String(cfg["dir"]) + "collar.png") else "torso"))
				c.centered = false
				c.region_enabled = true
				c.region_rect = parts[row[0]]
				c.offset = (parts[row[0]] as Rect2).position - parts["torso"]["a"]
				c.scale = Vector2.ONE * (PPM / float(parts["torso"]["ppm"]))
				c.light_mask = MASK_FIGURE
				c.texture_filter = MIPS
				_body.add_child(c)
				_collars.append(c)
			continue
		if not parts.has(part):
			continue
		var s := Sprite2D.new()
		var pdir := String(cfg["dir"])
		if cfg.has("base_dir") and not ResourceLoader.exists(pdir + part + ".png"):   # (an outfit draws only what shows: the hidden thigh/shin from the plain suit)
			pdir = String(cfg["base_dir"])
		s.texture = _tex(String(cfg["head_tex"]).trim_suffix(".png")) if part == "head" and cfg.has("head_tex") else _tex(pdir + part)
		s.centered = false
		s.offset = -parts[part]["a"]
		if parts[part].has("region"):   # only part of the drawing is used
			s.region_enabled = true
			s.region_rect = parts[part]["region"]
			s.offset += (parts[part]["region"] as Rect2).position
		s.scale = Vector2.ONE * (PPM / float(parts[part]["ppm"]))
		if parts[part].has("thick"):   # (user 24. 11.: "the arm does not sit on the shoulder, it is oddly small") wider across the bone, same length
			var across_x := absf(cos(float(_ang[part]))) < 0.5   # a bone drawn upright widens in x, one drawn lying in y
			s.scale *= Vector2(float(parts[part]["thick"]), 1.0) if across_x else Vector2(1.0, float(parts[part]["thick"]))
		if row[2]:
			s.modulate = Color(0.55, 0.55, 0.55)
		s.light_mask = MASK_FIGURE
		s.texture_filter = MIPS
		_body.add_child(s)
		_spr[row[0]] = s
	set_weapon(String(cfg.get("weapon", "revolver")))
	_pipe = Sprite2D.new()
	var pt: Texture2D = load("res://art/guns/pipe.png")
	_pipe.texture = pt
	_pipe.centered = false
	_pipe.offset = -Vector2(pt.get_size()) * PIPE_GRIP
	_pipe.scale = Vector2.ONE * PIPE_LEN * PPM / pt.get_width()
	_pipe.modulate = Color(0.78, 0.78, 0.8)
	_pipe.texture_filter = MIPS
	_pipe.visible = false
	_body.add_child(_pipe)
	if cfg.has("pelvis"):   # the seat of his trousers: under a short coat the street showed between his thighs in a long stride
		_pelvis = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 14:
			pts.append(Vector2(cos(i * TAU / 14.0) * 0.125, sin(i * TAU / 14.0) * 0.12 + 0.03) * PPM)
		_pelvis.polygon = pts
		_pelvis.color = cfg["pelvis"]
		_pelvis.light_mask = MASK_FIGURE
		_body.add_child(_pelvis)
		_body.move_child(_pelvis, _spr["thigh_b"].get_index())
	if cfg.has("leg_tex"):   # whole legs that bend at the knee, instead of a thigh and a shin on a pin
		for side in ["b", "f"]:
			var lm := _make_leg_mesh()
			_body.add_child(lm)
			_body.move_child(lm, _spr["thigh_" + side].get_index())
			_spr["thigh_" + side].visible = false
			_spr["shin_" + side].visible = false
			if side == "b":
				lm.modulate = _spr["thigh_b"].modulate
			_legs[side] = lm
			if cfg.has("pelvis"):
				var ck := Line2D.new()   # a band of trouser cloth along the bones, under the drawn leg
				ck.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
				ck.width = 0.13 * PPM
				ck.joint_mode = Line2D.LINE_JOINT_ROUND
				ck.begin_cap_mode = Line2D.LINE_CAP_ROUND
				ck.default_color = (cfg["pelvis"] as Color) * lm.modulate
				ck.light_mask = MASK_FIGURE
				_body.add_child(ck)
				_body.move_child(ck, lm.get_index())
				_crooks[side] = ck
	if _spr.has("skirt"):
		_skirt_mesh = _make_skirt_mesh()
		_body.add_child(_skirt_mesh)
		_body.move_child(_skirt_mesh, _spr["skirt"].get_index())
		_spr["skirt"].visible = false
		if ResourceLoader.exists(String(cfg["dir"]) + "farm_open.png") and _spr.has("farm_b"):
			_farm_tex = _spr["farm_b"].texture
			_farm_open_tex = _tex(String(cfg["dir"]) + "farm_open")
		var long_coat: bool = not cfg.get("short_coat", false)   # (Eddie's pea coat stops at the hip: none of the trench's drawn flares)
		if long_coat and ResourceLoader.exists(String(cfg["dir"]) + "skirt_fly.png"):   # the coat caught by the wind, for dives
			_skirt_fly = Sprite2D.new()
			_skirt_fly.texture = _tex(String(cfg["dir"]) + "skirt_fly")
			_skirt_fly.centered = false
			_skirt_fly.flip_h = true   # the flare hangs below him in a dive, not up over his back
			_skirt_fly.offset = -Vector2(754.0 - SKIRT_FLY_WAIST.x, SKIRT_FLY_WAIST.y)
			_skirt_fly.scale = _spr["skirt"].scale
			_skirt_fly.light_mask = MASK_FIGURE
			_skirt_fly.texture_filter = MIPS
			_skirt_fly.visible = false
			_body.add_child(_skirt_fly)
			_body.move_child(_skirt_fly, _skirt_mesh.get_index())
		for pose in (["run", "air"] if long_coat else []):   # the coat streaming back in a run, flared open in a leap
			var path: String = String(cfg["dir"]) + "skirt_" + pose
			if not ResourceLoader.exists(path + ".png"):
				continue
			var sp := Sprite2D.new()
			sp.texture = _tex(path)
			sp.centered = false
			sp.offset = -Vector2(sp.texture.get_width() * 0.5, 7.0)
			sp.scale = _spr["skirt"].scale
			sp.light_mask = MASK_FIGURE
			sp.texture_filter = MIPS
			sp.visible = false
			_body.add_child(sp)
			_body.move_child(sp, _skirt_mesh.get_index())
			_skirt_poses[pose] = sp
			_skirt_w[pose] = 0.0
	_build_shadow()
	_build_back_light()
	_pose()
	queue_redraw()


## A cold light low behind the figure, seen only by figures: with the normal maps it draws a thin rim
## along the back of the coat and hat, so a figure in the dark reads as a lit silhouette.
func _build_back_light() -> void:
	var l := PointLight2D.new()
	l.texture = load("res://art/light_blob.png")
	l.texture_scale = 4.0
	l.position = Vector2(-0.75, -1.9) * PPM   # above and behind: it catches the hat, shoulders and back
	l.color = Color(0.62, 0.72, 1.0)
	l.energy = 3.0
	l.height = 20.0
	l.range_item_cull_mask = 4
	add_child(l)


## The drawing with its normal map, so lamps shade the folds and edges instead of lighting it flat.
const LowRes = preload("res://lowres.gd")
const PART_RES := 0.5   # the parts are drawn some four times bigger than a phone ever shows them
static var _canvas := {}
func _tex(path: String) -> Texture2D:
	var diffuse: Texture2D = LowRes.tex(path + ".png", PART_RES)
	if not ResourceLoader.exists(path + "_n.png"):
		return diffuse
	var held = (_canvas[path] as WeakRef).get_ref() if _canvas.has(path) else null
	if held != null:
		return held
	var t := CanvasTexture.new()
	t.diffuse_texture = diffuse
	t.normal_texture = LowRes.tex(path + "_n.png", PART_RES)
	_canvas[path] = weakref(t)
	return t


func _build_shadow() -> void:
	_shadow = CanvasGroup.new()
	_shadow.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_shadow)
	move_child(_shadow, 0)
	for key in _spr:
		var src: Sprite2D = _spr[key]
		var d := Sprite2D.new()
		var t: Texture2D = src.texture
		if t is CanvasTexture:
			t = (t as CanvasTexture).diffuse_texture
		d.texture = t
		d.centered = false
		d.offset = src.offset
		d.region_enabled = src.region_enabled
		d.region_rect = src.region_rect
		d.scale = src.scale
		d.modulate = Color(0.0, 0.0, 0.0)
		_shadow.add_child(d)
		_shadow_spr[key] = d
	for side in _legs:
		var ls := _make_leg_mesh()
		ls.modulate = Color(0.0, 0.0, 0.0)
		_shadow.add_child(ls)
		_leg_shadows[side] = ls
		_shadow_spr["thigh_" + side].visible = false
		_shadow_spr["shin_" + side].visible = false
	if _skirt_mesh:
		_skirt_shadow = _make_skirt_mesh()
		_skirt_shadow.modulate = Color(0.0, 0.0, 0.0)
		_shadow.add_child(_skirt_shadow)
		_shadow_spr["skirt"].visible = false
	for key in ["gun", "gun2"]:
		var src: Sprite2D = _gun if key == "gun" else _gun2
		var g := Sprite2D.new()
		g.texture = src.texture
		g.centered = false
		g.offset = src.offset
		g.scale = src.scale
		g.visible = src.visible
		g.modulate = Color(0.0, 0.0, 0.0)
		_shadow.add_child(g)
		_shadow_spr[key] = g


## A flat ink copy of the figure exactly as it is posed this frame: the afterimages a dive, a roll or
## a run in slowed time leaves behind. The caller adds it to the scene and fades it.
func ghost() -> CanvasGroup:
	var g := CanvasGroup.new()
	g.position = position
	g.scale = scale
	g.rotation = rotation
	for key in _spr:
		var src: Sprite2D = _spr[key]
		if not src.visible:
			continue
		var d := Sprite2D.new()
		var t: Texture2D = src.texture
		if t is CanvasTexture:
			t = (t as CanvasTexture).diffuse_texture
		d.texture = t
		d.centered = src.centered
		d.offset = src.offset
		d.flip_h = src.flip_h
		d.region_enabled = src.region_enabled
		d.region_rect = src.region_rect
		d.position = src.position
		d.rotation = src.rotation
		d.scale = src.scale
		g.add_child(d)
	for side in _legs:
		var lg := _make_leg_mesh()
		lg.polygon = (_legs[side] as Polygon2D).polygon
		g.add_child(lg)
		g.move_child(lg, 0)
	if _skirt_mesh:
		var m := _make_skirt_mesh()
		m.polygon = _skirt_mesh.polygon
		g.add_child(m)
		g.move_child(m, 0)
	for src in [_gun, _gun2]:
		if not src.visible:
			continue
		var gun := Sprite2D.new()
		gun.texture = src.texture
		gun.centered = false
		gun.offset = src.offset
		gun.position = src.position
		gun.rotation = src.rotation
		gun.scale = src.scale
		g.add_child(gun)
	return g


## The hat (mobster heads with a hat drawn in): art/mobster/hats/<head>.png is the hat alone on the
## head's canvas, art/mobster/heads/<head>_bare.png the same head without it (art_src 143-145).
var hat_lost := false
static var _hat_img := {}

func hat_path() -> String:
	if not cfg.has("head_tex"):
		return ""
	var p := String(cfg["head_tex"]).replace("/heads/", "/hats/")
	return p if ResourceLoader.exists(p) else ""


## A bullet at `world` goes through his hat and nothing else: the crown above his skull or the brim.
func hat_hit(world: Vector2) -> bool:
	if hat_lost:
		return false
	var hp := hat_path()
	var s: Sprite2D = _spr.get("head")
	if hp == "" or s == null or not s.is_visible_in_tree() or world.distance_squared_to(s.global_position) > 40000.0:
		return false
	var bp := String(cfg["head_tex"]).trim_suffix(".png") + "_bare.png"
	for path in [hp, bp]:
		if not _hat_img.has(path):
			var im: Image = (load(path) as Texture2D).get_image()
			if im != null and im.is_compressed():
				im.decompress()
			_hat_img[path] = im
	var hat: Image = _hat_img[hp]
	var bare: Image = _hat_img[bp]
	if hat == null or bare == null:
		return false
	# (the head drawings are imported at half size: gen/lowres_paths.txt; the image is read at its own size)
	var painted: Vector2 = Vector2(BigTex.painted_size(hp, load(hp)))
	var px := Vector2i((s.to_local(world) - s.offset) * Vector2(hat.get_size()) / painted)
	if px.x < 0 or px.y < 0 or px.x >= hat.get_width() or px.y >= hat.get_height():
		return false
	var used := hat.get_used_rect()   # the upper part of the crown counts even where a tall head of hair is under it
	# a near miss of the brim or the crown counts too (2026-11-16: it almost never came off): any hat
	# pixel within a few pixels of the bullet, on the hat's own part, not the bare face under it
	var reach := maxi(3, hat.get_width() / 40)
	for d in [Vector2i.ZERO, Vector2i(0, -reach), Vector2i(reach, 0), Vector2i(-reach, 0), Vector2i(0, reach)]:
		var q: Vector2i = px + d
		if q.x < 0 or q.y < 0 or q.x >= hat.get_width() or q.y >= hat.get_height() or hat.get_pixelv(q).a <= 0.5:
			continue
		var bq := Vector2i(Vector2(px) * Vector2(bare.get_size()) / Vector2(hat.get_size()))   # (the bare head may be imported at another size)
		bq = bq.clamp(Vector2i.ZERO, bare.get_size() - Vector2i.ONE)
		if bare.get_pixelv(bq).a < 0.5 or q.y < used.position.y + used.size.y * 0.55:
			return true
	return false


## A bullet through his gun (2026-11-16): the gun's drawing, a little generous at the edges.
func gun_hit(world: Vector2, generous := false) -> bool:
	if not _gun.is_visible_in_tree() or _gun.texture == null:
		return false
	var lp := (_gun.to_local(world) - _gun.offset) / Vector2(_gun.texture.get_size())
	if generous:   # (in slowed time: the edges count)
		return lp.x > -0.08 and lp.x < 1.05 and lp.y > -0.25 and lp.y < 1.25
	return lp.x > 0.35 and lp.x < 1.0 and lp.y > 0.0 and lp.y < 1.0   # the barrel end, not the grip in his fist


## The hat comes off: the head is drawn bare from now on. Returns what main.gd needs to throw the hat.
func lose_hat() -> Dictionary:
	hat_lost = true
	var s: Sprite2D = _spr["head"]
	var out := {"tex": load(hat_path()), "offset": s.offset, "xform": s.global_transform}
	s.texture = _tex(String(cfg["head_tex"]).trim_suffix(".png") + "_bare")
	return out


## dx: how far the shadow lands from the feet (world pixels), skew: its lean, alpha: 0 = no lamp near.
func set_shadow(dx: float, skew_amount: float, alpha: float) -> void:
	_shadow.self_modulate = Color(1.0, 1.0, 1.0, alpha)
	_shadow.visible = alpha > 0.01   # an invisible group still costs a pass over the screen on a phone
	_shadow.position = Vector2(dx * scale.x, -6.0)
	_shadow.skew = skew_amount * scale.x
	_shadow.scale = Vector2(1.12, 1.12)


func _draw() -> void:
	# contact shadow: the figure stands on the pavement instead of floating over it
	var high := clampf(ground / 300.0, 0.0, 1.0)   # the higher he is, the smaller and fainter it gets
	var r := 0.46 * PPM * (1.0 - high * 0.4)
	var k := 1.0 - high * 0.6
	draw_set_transform(Vector2(0.0, ground - 3.0), 0.0, Vector2(1.0 + dive * 0.8, 0.15))
	draw_texture_rect(pool_texture(), Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1, 1, 1, k))   # soft pool
	draw_circle(Vector2.ZERO, r * 0.42, Color(0.0, 0.0, 0.0, 0.5 * k))   # dark core right under the feet
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static var _pool: Texture2D
## A soft round pool of ink, dark in the middle and gone at the rim.
static func pool_texture() -> Texture2D:
	if _pool == null:
		_pool = load("res://art/fx_pool.png")
	return _pool


## dir: -1..1 along the ground (how fast the legs run). aim: vector from the shoulder to the target,
## in the parent's space.
func set_state(dir: float, aim: Vector2, delta: float) -> void:
	var facing := -1.0 if aim.x < 0.0 else 1.0
	scale = Vector2(facing * size, size) * _fs()
	var want := Vector2(absf(aim.x), aim.y)
	if want.length() < 0.001:
		want = Vector2.RIGHT
	# the gun arm eases onto the target instead of snapping; the kick of a shot is added on top
	_aim_angle = lerp_angle(_aim_angle, want.angle(), 1.0 - exp(-22.0 * delta))
	recoil = move_toward(recoil, 0.0, delta * 1.6)
	_flinch = move_toward(_flinch, 0.0, delta * 2.2)
	_hit_dip = move_toward(_hit_dip, 0.0, delta * 2.5)

	_aim = Vector2.from_angle(_aim_angle - recoil)
	ease = move_toward(ease, 1.0 if at_ease else 0.0, delta * (1.8 if at_ease else 9.0))   # down slowly, up fast
	if clip != "":
		clip_t += delta
		if clip_t >= float(CLIPS[clip]["len"]):
			clip = ""
	if _switch_p >= 0.0:   # down to the coat pocket and back up: the new gun swaps in at the bottom
		_switch_p += delta / SWITCH_TIME
		if _switch_to != "" and _switch_p >= 0.5:
			set_weapon(_switch_to)
			_switch_to = ""
		if _switch_p >= 1.0:
			_switch_p = -1.0
		else:
			var dip := sin(PI * _switch_p)
			_aim = Vector2.from_angle(lerp_angle(_aim.angle(), 1.45, dip * 0.92))
	_moving = lerpf(_moving, absf(dir), 1.0 - exp(-9.0 * delta))
	var g2s: bool = cfg.get("gait2", false)
	if not g2s:
		_phase = fposmod(_phase + dir * facing * delta * 2.2, 1.0)   # walking backwards runs the cycle in reverse

	# the coat tail: it hangs, streams back with speed, flies up in a fall, and lags behind every change
	if _have_last and delta > 0.0:
		_vel = _vel.lerp((global_position - _last) / delta, 1.0 - exp(-12.0 * delta))
	_last = global_position
	_have_last = true
	_clock += delta
	var forward := _vel.x * facing
	if g2s and delta > 0.0:   # the cadence from the ground he really covers: a planted foot does not slide
		_gs = lerpf(_gs, clampf(absf(_vel.x) / 640.0, 0.0, 1.25), 1.0 - exp(-10.0 * delta))
		_moving = clampf(_gs / 0.2, 0.0, 1.0)
		var rate := lerpf(WALK_RATE * sqrt(clampf(_gs / 0.4, 0.0, 1.3)), RUN_RATE * sqrt(clampf(_gs, 0.0, 1.2)), _run_w())
		if _use_mocap():   # the recording's own cadence (a little slower when he goes slower than the man who was captured)
			var mx := _mc_mix()
			var nat := float(mx[2]) * (float(_len["thigh"]) + float(_len["shin"])) / float(mx[1])   # m/s of the recording on his legs
			var sp := absf(_vel.x) / (PPM * maxf(0.01, absf(scale.x)))
			rate = (1.0 / float(mx[1])) * clampf(sqrt(sp / maxf(0.1, nat)), 0.0, 1.15)
		_phase = fposmod(_phase + signf(forward) * delta * rate, 1.0)
	# kept modest: the upper coat is part of the torso drawing, and a tail that swings far breaks away from it
	# straight down at rest and in a walk; it only streams back once he is really moving
	var hang := Vector2(-clampf((absf(forward) - 150.0) / 400.0, 0.0, 1.3) * signf(forward) * 0.11, 0.5 - clampf(_vel.y / 1200.0, -0.5, 1.0) * (0.15 + 0.2 * maxf(air, dive)))
	hang.x -= maxf(air, dive) * 0.09 * (signf(forward) if absf(forward) > 50.0 else 1.0)   # in a leap the coat flies out behind him
	hang.x += sin(_clock * 9.0) * 0.025 * _moving + sin(_clock * 1.6) * 0.012   # flutter in the run, a breath of wind at rest
	if heavy:   # the coat streams further and comes after him later
		hang.x *= 1.7
	_tail_dir = _tail_dir.lerp(hang, 1.0 - exp(-(4.0 if heavy else 7.0) * delta))
	_pose()
	queue_redraw()


## One foot's path through a running stride, p = 0..1: carried back along the ground for the first
## half, then lifted and swung forward in an eased arc.
## (user 24. 11.: "the run is grotesque" - postavy/plan-novych-postav, cfg "gait2") The stride keyed from how a man really
## moves, one foot's path against the hip, p = 0 at its strike: [p, x forward, y (up is minus)], metres.
## RUN: a man running hard in the street, not a sprinter (user 24. 11.: "he still lifts his knees too much - closer to
## realism"). The keys are worked out from joint angles of a ~3 m/s run (gait studies) through Eddie's leg lengths:
## contact thigh 25 deg forward, knee 20 bent; toe-off on the ball of the foot, thigh 15 back; the knee folds most
## (95 deg) just after, the thigh then only ~10 forward; the thigh's highest is ~40 deg (a sprinter's 70+ reads as
## high-stepping), the shin swinging out to land a little ahead of the hip. On the ground 38 %: a short flight between.
## Checked by `--test=gait` (prints each frame's thigh and knee angle).
const RUN_KEYS := [[0.0, 0.216, 0.0], [0.3, -0.25, 0.0], [0.38, -0.386, -0.06], [0.47, -0.5, -0.27], [0.6, -0.357, -0.36],
		[0.7, -0.183, -0.24], [0.8, 0.055, -0.12], [0.92, 0.242, -0.04], [1.0, 0.216, 0.0]]
## WALK: on the ground 62 % (both feet down between steps), the heel peeling up before the toe leaves, a low swing
## just clear of the pavement. The planted leg is all but straight: a walk on bent knees is a creep.
const WALK_KEYS := [[0.0, 0.3, 0.0], [0.45, -0.135, 0.0], [0.62, -0.3, -0.05], [0.72, -0.33, -0.12], [0.82, -0.08, -0.12], [0.93, 0.26, -0.05], [1.0, 0.3, 0.0]]
const RUN_RATE := 1.6     # strides a second at full speed: with RUN_KEYS' ground stretch the planted foot stands still
const WALK_RATE := 1.12   # at the calm walk (0.4 of full speed)
var _gs := 0.0            # gait2: how fast he really moves over the ground, 0..1 of a full run


static func _keyed(keys: Array, p: float) -> Vector2:
	p = fposmod(p, 1.0)
	var n := keys.size()
	for i in n - 1:
		if p <= float(keys[i + 1][0]):
			var a: Array = keys[i]
			var b: Array = keys[i + 1]
			var u := (p - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			var pa := Vector2(a[1], a[2])
			var pb := Vector2(b[1], b[2])
			if i == 0:   # the planted stretch: straight back along the ground, at the speed he travels
				return pa.lerp(pb, u)
			var a0: Array = keys[i - 1]
			var b1: Array = keys[(i + 2) if i + 2 < n else 1]
			var m0 := (pb - Vector2(a0[1], a0[2])) / (float(b[0]) - float(a0[0]))
			var m1 := (Vector2(b1[1], b1[2]) - pa) / ((float(b1[0]) + (1.0 if i + 2 >= n else 0.0)) - float(a[0]))
			var d := float(b[0]) - float(a[0])
			var u2 := u * u
			var u3 := u2 * u
			return pa * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * d * (u3 - 2.0 * u2 + u) + pb * (-2.0 * u3 + 3.0 * u2) + m1 * d * (u3 - u2)
	return Vector2(keys[0][1], keys[0][2])


## gait2: how much of the stride is the run (0 = the walk).
func _run_w() -> float:
	return smoothstep(0.5, 0.8, _gs)


## (user 24. 11.: "most of it looks mechanical - I want to see the mocap Blender version") cfg "mocap": the walk and the run
## are real people's, captured (CMU database) and seen from the side (gen/mocap, mocap_data.gd). The near leg, the far leg,
## the hips' height, the torso, the head and both hands come from the recording; the figure only scales it to its own legs.
const MOCAP := preload("res://mocap_data.gd")
static var mocap_off := false   # --nomocap: the keyed gait2 instead, to compare
var _mc := {}                   # the blended mocap pose this frame (empty: none)
var roll_t := -1.0              # main.gd's roll: 0..1 through it (-1 not rolling) - the captured dive roll plays along it
var slide_t := -1.0             # main.gd's slide: 0..1 through it (-1 not sliding) - the keyed slide sheet (gen/mocap/keyed.py)
var death_t := -1.0             # main.gd _drop, cfg "mocap": 0..1 through the fall (keyed.py die_back / die_front)
var death_clip := "die_back"
var prone := false              # main.gd: down flat after a dive; while dive runs 1 -> 0 he gets up (the keyed get-up sheet)
var _mcl := []                  # the one-off captured move this frame: [name, sample, weight, side]

## (user 25. 11.: "the animations must blend into each other - they snap, frames are missing") INERTIAL BLENDING, every
## figure: whenever the pose would jump - one move handing over to the next (the key changes), or a part leaping further
## in a frame than a body can - the difference between what was SHOWN and the new pose is kept as an offset and faded out
## over IN_TIME, while the new move already plays underneath. Nothing freezes, nothing snaps. Goes through: hips, both
## feet, the torso's lean, both hands, the head. `blend_off`: the still-frame tests (moves, gait) pose out of time.
const IN_W := 14.0   # the blend spring's stiffness (1/s): ~80 % gone in 0.2 s, all in ~0.4 s
static var blend_off: bool = OS.get_cmdline_user_args().has("--noblend")   # (test --noblend: the raw poses, to compare)
static var _headlog: bool = OS.get_cmdline_user_args().has("--headlog")
static var _jointlog: bool = OS.get_cmdline_user_args().has("--jointlog")
var _in_key := ""
var _in_new := false
var _in_dt := 0.0
var _in_clock := 0.0
var _in_off := {}
var _in_offv := {}
var _in_step := {}
var _in_cool := {}
var _in_v := {}
var _in_t := {}
var _in_shown := {}
var _in_raw := {}


var _fdt_frame := -1


## This frame's game time (scaled with slow time), once per frame: posed twice in a frame, the second pose gets 0.
func _frame_dt() -> float:
	var f := Engine.get_process_frames()
	if f == _fdt_frame:
		return 0.0
	_fdt_frame = f
	return clampf(get_process_delta_time(), 0.0, 0.1)


func _inert(name: String, raw, jump := 0.0, angle := false):
	# (25. 11., second pass - user: "make every blend smoother") the offset is a critically damped SPRING (smooth start,
	# no overshoot); at a hand-over it starts from where the shown pose was GOING (its last speed carried one frame on),
	# a break inside a move only takes up the break. Measured with gen/tests/jerk.py: carrying the shown speed into the
	# spring as well made the hips overshoot half a metre after the dive's landing - the spring starts at rest.
	if blend_off:
		return raw
	if _in_dt <= 0.0:   # posed again in the same frame: the blend as it stands, nothing stepped or measured
		return raw + _in_off.get(name, raw * 0.0)
	var dt := _in_dt
	var restart := _in_new
	var step = raw * 0.0
	if _in_raw.has(name):
		step = raw - _in_raw[name]
		if angle:
			step = wrapf(step, -PI, PI)
	_in_cool[name] = maxf(0.0, float(_in_cool.get(name, 0.0)) - dt)
	# (after one break is taken up the next 0.2 s are not tested: breaks taken up frame after frame cancel the move's
	# own speeding up - the hips stayed down after the roll)
	if not restart and jump > 0.0 and _in_step.has(name) and float(_in_cool[name]) <= 0.0:   # a break inside one move
		# (25. 11.) not a big step but a CHANGE of step - a discontinuity. Testing the step itself restarted the blend
		# every frame of a fast roll, and the spring, fed its own speed each time, ran away (the hips flew)
		var dd = step - _in_step[name]
		restart = (absf(dd) if angle else (dd as Vector2).length()) > jump
	if restart and _in_shown.has(name):
		var d
		if _in_new:   # a hand-over: from where the shown pose was going to the new move, the spring at rest
			var v = _in_v.get(name, raw * 0.0)
			d = _in_shown[name] + v * dt - raw
			_in_offv[name] = raw * 0.0
		else:   # a break inside a move: only the break itself is taken up (taking the shown speed again counted it twice
			# and the hips overshot half a metre), the spring runs on as it was
			d = _in_off.get(name, raw * 0.0) - (step - _in_step.get(name, step))
			_in_cool[name] = 0.2
			if not _in_offv.has(name):
				_in_offv[name] = raw * 0.0
		_in_off[name] = clampf(wrapf(d, -PI, PI), -1.6, 1.6) if angle else (d as Vector2).limit_length(0.8)
	if not restart or not _in_step.has(name):   # the step that held a break is not the pose's own motion: not kept
		_in_step[name] = step
	_in_raw[name] = raw
	var shown = raw
	if _in_off.has(name):
		var x = _in_off[name]
		var v = _in_offv[name]
		var e := exp(-IN_W * dt)
		var j = v + x * IN_W
		_in_off[name] = (x + j * dt) * e
		_in_offv[name] = (v - j * IN_W * dt) * e
		shown = raw + _in_off[name]
		var small: bool = (absf(_in_off[name]) < 0.002) if angle else ((_in_off[name] as Vector2).length() < 0.002)
		if small and ((absf(_in_offv[name]) < 0.02) if angle else ((_in_offv[name] as Vector2).length() < 0.02)):
			_in_off.erase(name)
			_in_offv.erase(name)
	if _in_shown.has(name):
		var dv = shown - _in_shown[name]
		_in_v[name] = (wrapf(dv, -PI, PI) if angle else dv) / dt
	_in_shown[name] = shown
	return shown


static func _mcl_at(name: String, u: float) -> Array:
	var ph: Array = MOCAP.CLIPS[name]["phases"]
	var t := clampf(u, 0.0, 1.0) * (ph.size() - 1)
	var i := mini(int(t), ph.size() - 2)
	var v := t - i
	var out := []
	for k in (ph[i] as Array).size():
		out.append(lerpf(float(ph[i][k]), float(ph[i + 1][k]), v))
	return out


static func _mc_at(name: String, p: float) -> Array:
	var ph: Array = MOCAP.CYCLES[name]["phases"]
	var n := ph.size()
	var t := fposmod(p, 1.0) * n
	var i := int(t)
	var u := t - i
	var a: Array = ph[i % n]
	var b: Array = ph[(i + 1) % n]
	var out := []
	for k in a.size():
		out.append(lerpf(float(a[k]), float(b[k]), u))
	return out


## How much walk / run (0 = the walk cycle, 1 = the run), the length of a cycle in seconds, and its stride in leg lengths.
func _mc_mix() -> Array:
	var rw := smoothstep(0.42, 0.72, _gs)
	var walk: Dictionary = MOCAP.CYCLES["walk"]
	var run: Dictionary = MOCAP.CYCLES["run"]
	return [rw, lerpf(float(walk["seconds"]), float(run["seconds"]), rw), lerpf(float(walk["travel"]), float(run["travel"]), rw)]


func _use_mocap() -> bool:
	return cfg.get("mocap", false) and not mocap_off and not OS.get_cmdline_user_args().has("--nomocap")


func _foot2(p: float) -> Vector2:
	var rw := _run_w()
	var w := _keyed(WALK_KEYS, p) * Vector2(sqrt(clampf(_gs / 0.4, 0.05, 1.3)), 1.0)
	var r := _keyed(RUN_KEYS, p) * Vector2(sqrt(clampf(_gs, 0.3, 1.2)), 1.0)
	return w.lerp(r, rw)


func _foot(p: float) -> Vector2:
	if cfg.get("gait2", false):
		return _foot2(p)
	p = fposmod(p, 1.0)
	if p < 0.5:
		return Vector2(lerpf(0.36, -0.36, p * 2.0), 0.0)
	var u := (p - 0.5) * 2.0
	var e := u * u * (3.0 - 2.0 * u)
	return Vector2(lerpf(-0.36, 0.36, e), -sin(u * PI) * 0.26)


func _pose() -> void:
	var l1: float = _len["thigh"]
	var l2: float = _len["shin"]
	var ua: float = _len["uarm"]
	var fa: float = _len["farm"]
	var t := _moving
	var th := _phase * TAU
	var ankle := 0.09
	# feet: planted when standing, the stride when running
	var stride := Vector2(1.0 - 0.4 * duck, 1.0 - 0.5 * duck)   # crouched, the steps are short and low
	var foot_a := Vector2(-0.16, 0.0).lerp(_foot(_phase) * stride, t)
	var foot_b := Vector2(0.14, 0.0).lerp(_foot(_phase + 0.5) * stride, t)
	_mc = {}
	if _use_mocap() and t > 0.0 and not _dead:
		var mx := _mc_mix()
		var w := _mc_at("walk", _phase)
		var r := _mc_at("run", _phase)
		var m := []
		for k in w.size():
			m.append(lerpf(float(w[k]), float(r[k]), float(mx[0])))
		var legk: float = float(_len["thigh"]) + float(_len["shin"])
		var nat := float(mx[2]) * legk / float(mx[1])
		var sp := absf(_vel.x) / (PPM * maxf(0.01, absf(scale.x))) if _have_last else nat
		var sx := clampf(sp / maxf(0.1, nat) / clampf(sqrt(sp / maxf(0.1, nat)), 0.3, 1.15), 0.55, 1.2)   # what the cadence leaves to the stride
		var armk: float = (float(_len["uarm"]) + float(_len["farm"])) / (float(MOCAP.CYCLES["jog"]["arm"]) * legk)
		_mc = {"hip": -(float(m[0]) * legk + ankle), "fa": Vector2(float(m[1]) * legk * sx, -float(m[2]) * legk),
				"fb": Vector2(float(m[3]) * legk * sx, -float(m[4]) * legk), "torso": float(m[5]), "head": float(m[6]),
				"hf": Vector2(float(m[7]), -float(m[8])) * legk * armk, "hb": Vector2(float(m[9]), -float(m[10])) * legk * armk,
				"w": t}
		if duck > 0.0:   # crouched: the same walk, the hips let down and the body bowed, the step a little shorter
			_mc["hip"] = float(_mc["hip"]) + 0.45 * legk * duck
			_mc["torso"] = float(_mc["torso"]) + 0.42 * duck
			_mc["fa"] = (_mc["fa"] as Vector2) * Vector2(1.0 - 0.2 * duck, 1.0)
			_mc["fb"] = (_mc["fb"] as Vector2) * Vector2(1.0 - 0.2 * duck, 1.0)
		foot_a = Vector2(-0.16, 0.0).lerp(_mc["fa"], _mc["w"]).lerp(foot_a, duck * (1.0 - t))
		foot_b = Vector2(0.14, 0.0).lerp(_mc["fb"], _mc["w"]).lerp(foot_b, duck * (1.0 - t))
	foot_a = foot_a.lerp(Vector2(0.2, 0.0), duck * (1.0 - t))    # standing crouch: one foot forward, one back
	foot_b = foot_b.lerp(Vector2(-0.22, 0.0), duck * (1.0 - t))
	# in a jump the knees come up; in a dive the legs trail straight; in a slide they lead
	# a jump is a leap, not a plank: going up, the lead knee drives high and the back leg trails long
	# from the push; at the top both knees tuck; coming down the legs open again and reach for the ground
	var up := clampf(-air_v, 0.0, 1.0)
	var down := clampf(air_v, 0.0, 1.0)
	var ja := Vector2(0.14, -0.36).lerp(Vector2(0.24, -0.46), up).lerp(Vector2(0.12, -0.1), down)
	var jb := Vector2(-0.12, -0.24).lerp(Vector2(-0.26, -0.02), up).lerp(Vector2(-0.1, -0.04), down)
	# a dive is the shootdodge (user 18. 11.: "like Max Payne", the knee forward rejected): laid out flat, the legs
	# long behind him and together, only a soft bend at the knees (down, toward the ground), breathing as he flies
	var flut := sin(_clock * 7.0) * 0.015
	foot_a = foot_a.lerp(ja, air).lerp(Vector2(-0.03, -0.05 + flut), dive).lerp(Vector2(0.74 * slide_side, -0.03), slide)
	foot_b = foot_b.lerp(jb, air).lerp(Vector2(0.05, -0.1 - flut), dive).lerp(Vector2(0.3 * slide_side, 0.0), slide)
	if hang > 0.0:   # hanging: the legs hang; climbing, the knees come up in turn to grip the rope
		var fa_h := Vector2(0.07, -0.05)
		var fb_h := Vector2(-0.05, -0.02)
		if hang_cycle >= 0.0:
			var c := 0.5 - 0.5 * cos(hang_cycle * TAU)
			fa_h = Vector2(0.12, -0.06 - 0.34 * c)
			fb_h = Vector2(0.02, -0.06 - 0.34 * (1.0 - c))
		foot_a = foot_a.lerp(fa_h, hang)
		foot_b = foot_b.lerp(fb_h, hang)
	var cl := {}
	var cw := 0.0
	if clip != "" and not _dead:
		var now := _clip_now()
		cl = now[0]
		cw = float(now[1])
		var sd := Vector2(clip_side, 1.0)
		foot_a = foot_a.lerp((cl["fa"] as Vector2) * sd, cw)
		foot_b = foot_b.lerp((cl["fb"] as Vector2) * sd, cw)
	var drop := minf(0.62, crouch * 0.3 + slide * 0.5 + duck * 0.58 + _hit_dip * 0.16)   # how far the hips sink
	drop = lerpf(drop, float(cl.get("drop", drop)), cw)
	var g2: bool = cfg.get("gait2", false)
	var rw := _run_w() if g2 else 0.0
	var bob := lerpf(0.01, 0.04 + (0.065 if heavy else 0.035) * cos(th * 2.0), t)
	if g2:   # the hips ride low enough for the legs to reach their stride: lowest over the planted foot in a run (and up
		# in the flight between), lowest between the steps in a walk
		bob = 0.01 + t * lerpf(0.015 + 0.017 * cos(th * 2.0), 0.03 + 0.012 * cos((th - 1.2) * 2.0), rw) * (1.0 - maxf(air, maxf(dive, slide)))
	var hip := Vector2(-0.1 * slide * slide_side, -(l1 + l2) * 0.985 - ankle + drop + bob)
	if not _mc.is_empty():   # the hips ride as the captured man's did (up in the flight, down over the planted foot)
		hip.y = lerpf(-(l1 + l2) * 0.985 - ankle + 0.01, float(_mc["hip"]), float(_mc["w"])) + drop - minf(duck * 0.58, drop) * float(_mc["w"])   # (the crouch is already in the captured hips)
	var legs_lean := dive * 1.5 * dive_side + roll        # the legs follow a dive (flat out) or a tumble
	if not _dead:   # the whole body pitches into the leap and settles back for the landing
		legs_lean += air * (0.16 * clampf(-air_v, 0.0, 1.0) - 0.05 * clampf(air_v, 0.0, 1.0)) * (1.0 - dive)
		legs_lean += dive * dive_side * (0.18 * clampf(air_v, -1.0, 1.0) - 0.08)   # the dive follows its arc: head up leaving, down landing
	var lean := legs_lean - slide * 0.75 * slide_side + crouch * 0.25 + duck * 0.32   # the torso also lies back in a slide, bows in a crouch
	if not _dead:
		if not _mc.is_empty():
			lean += float(_mc["torso"]) * float(_mc["w"]) * (1.0 - dive)
		else:
			lean += t * ((lerpf(0.04, 0.2, rw) + 0.025 * sin(th * 2.0) * rw) if g2 else (0.24 if heavy else 0.13)) * (1.0 - dive)                 # leaning into a run
		lean += air * (0.1 * clampf(-air_v, 0.0, 1.0) - 0.07 * clampf(air_v, 0.0, 1.0) + 0.04)   # into the leap going up, back a little to land
		lean -= recoil * (0.5 if heavy else 0.22)                          # each shot knocks him back a touch
		lean -= _flinch * (0.6 if _hit_part == "torso" else 0.35)   # and a bullet much more: rocked back
		lean -= sin(_flinch * PI) * 0.12 * _hit_dip              # a leg hit folds him forward a moment
		lean += clampf(_aim.angle(), -0.9, 0.6) * 0.08   # the body follows the gun up or down a little
	lean = lerpf(lean, 0.0, hang)   # hanging straight down from the hands
	# (25. 11., rule 41: both fists straight over his head hid the whole face) the cfg "mocap" figure hangs as a rope climber
	# does: the body a little behind the rope, leaning back off it, the feet forward clamping it; the near fist low at his
	# chin, the far one reaching high - hand over hand, the near one never higher than his brow
	if _use_mocap() and hang > 0.0 and not hang_one and not _dead:
		hip.x -= 0.15 * hang
		lean = lerpf(lean, -0.12, hang)
	var spin := 0.0
	if cw > 0.0:   # the clip's body: the legs and the torso turned as set, and a flip turns the lot
		spin = float(cl.get("spin", 0.0)) * TAU * clip_side
		legs_lean = lerpf(legs_lean, float(cl["legs"]) * clip_side, cw) + spin
		lean = lerpf(lean, float(cl["lean"]) * clip_side, cw) + spin
	# the captured one-off moves (gen/mocap clips): over a jump the leap of a man running and jumping long (CMU 127_21), the
	# legs from his hips; along main.gd's roll the dive roll (127_23) whole: his hips, legs, torso and head, all the way round
	_mcl = []
	if _use_mocap() and (not _dead or death_t >= 0.0) and swing < 0.0:
		var legk: float = l1 + l2
		if death_t >= 0.0:   # shot dead: the fall sheet, the feet where he stood, the hips going down past them
			var m := _mcl_at(death_clip, death_t)
			_mcl = [death_clip, m, 1.0, 1.0]
			var hx := float(m[11]) * legk
			hip = Vector2(hx, -float(m[0]) * legk - ankle)
			foot_a = Vector2(hx + float(m[1]) * legk, -float(m[2]) * legk)
			foot_b = Vector2(hx + float(m[3]) * legk, -float(m[4]) * legk)
			legs_lean = 0.0
			lean = float(m[5])
		elif roll_t >= 0.0 and roll != 0.0:
			var sd := dive_side
			var m := _mcl_at("roll", roll_t)
			var w := 1.0 - smoothstep(0.62, 1.0, roll_t)   # coming up he hands over to the game's crouch, which runs on (25. 11.: longer - the hips shot up)
			_mcl = ["roll", m, w, sd]
			hip = hip.lerp(Vector2(0.0, -float(m[0]) * legk - ankle), w)
			var fa2 := Vector2(float(m[1]) * legk * sd, -float(m[2]) * legk)
			var fb2 := Vector2(float(m[3]) * legk * sd, -float(m[4]) * legk)
			foot_a = (hip + (foot_a - hip).rotated(legs_lean)).lerp(fa2, w)   # (the game's feet as they would be turned, so the hand-over is smooth)
			foot_b = (hip + (foot_b - hip).rotated(legs_lean)).lerp(fb2, w)
			legs_lean = 0.0
			lean = lerpf(lean, float(m[5]) * sd, w)
		elif clip == "dive_push" and cw > 0.0:   # into the dive: a man running and diving over (CMU 127_23), legs and torso
			var m := _mcl_at("launch", clip_t / float(CLIPS["dive_push"]["len"]))
			_mcl = ["launch", m, cw, 1.0]
			foot_a = foot_a.lerp(hip + Vector2(float(m[1]) * legk, (float(m[0]) - float(m[2])) * legk) + Vector2(0.0, ankle), cw)
			foot_b = foot_b.lerp(hip + Vector2(float(m[3]) * legk, (float(m[0]) - float(m[4])) * legk) + Vector2(0.0, ankle), cw)
			legs_lean = lerpf(legs_lean, 0.0, cw)
			lean = lerpf(lean, float(m[5]), cw)
		elif slide_t >= 0.0 and slide > 0.0:   # the slide sheet: down onto the hip, riding it, the folded leg driving him up
			var sd := slide_side
			var m := _mcl_at("slide", slide_t)
			var w := 1.0 - smoothstep(0.9, 1.0, slide_t)
			_mcl = ["slide", m, w, sd]
			hip = hip.lerp(Vector2(0.0, -float(m[0]) * legk - ankle), w)
			foot_a = (hip + (foot_a - hip).rotated(legs_lean)).lerp(Vector2(float(m[1]) * legk * sd, -float(m[2]) * legk), w)
			foot_b = (hip + (foot_b - hip).rotated(legs_lean)).lerp(Vector2(float(m[3]) * legk * sd, -float(m[4]) * legk), w)
			legs_lean = 0.0
			lean = lerpf(lean, float(m[5]) * sd, w)
		elif dive > 0.0 and not prone and roll_t < 0.0:   # the flight (shootdodge): laid out, legs scissoring, the free arm out
			var sd := dive_side
			var m := _mcl_at("flight", clampf((air_v + 1.0) * 0.5, 0.0, 1.0))
			var wob := sin(_clock * 7.0) * 0.04   # breathing in the air
			_mcl = ["flight", m, dive, sd]
			# (+ ankle: as the take-off has it - without it the feet hopped at the hand-over, gen/tests/jerk.py)
			foot_a = (hip + (foot_a - hip).rotated(legs_lean)).lerp(hip + Vector2(float(m[1]) * legk * sd, (float(m[0]) - float(m[2])) * legk + wob + ankle), dive)
			foot_b = (hip + (foot_b - hip).rotated(legs_lean)).lerp(hip + Vector2(float(m[3]) * legk * sd, (float(m[0]) - float(m[4])) * legk - wob + ankle), dive)
			legs_lean = lerpf(legs_lean, 0.0, dive)
			lean = lerpf(lean, float(m[5]) * sd, dive)
		elif prone and dive <= 1.0 and air <= 0.01:   # up off the stones after the dive: the get-up sheet, along dive 1 -> 0
			var sd := dive_side
			var fl := ground / (PPM * maxf(0.01, absf(scale.y)))   # the floor: the origin lies below it while he is down
			var m := _mcl_at("getup", 1.0 - dive)
			var w := 1.0 - smoothstep(0.85, 1.0, 1.0 - dive)
			_mcl = ["getup", m, w, sd]
			hip = hip.lerp(Vector2(0.0, fl - float(m[0]) * legk - ankle), w)
			foot_a = (hip + (foot_a - hip).rotated(legs_lean)).lerp(Vector2(float(m[1]) * legk * sd, fl - float(m[2]) * legk), w)
			foot_b = (hip + (foot_b - hip).rotated(legs_lean)).lerp(Vector2(float(m[3]) * legk * sd, fl - float(m[4]) * legk), w)
			legs_lean = 0.0
			lean = lerpf(lean, float(m[5]) * sd, w)
		elif _flinch > 0.0 and air <= 0.01 and cw <= 0.0 and hang <= 0.0 and dive <= 0.0 and slide <= 0.0 and duck <= 0.0:
			# hit, standing: the hit sheets (keyed.py) along the flinch; on the run the old lean back stays (he keeps going)
			var nm := "hit_leg" if (_hit_part.begins_with("thigh") or _hit_part.begins_with("shin")) else "hit"
			var m := _mcl_at(nm, 1.0 - _flinch)
			var w := (1.0 - t) * (1.0 - crouch)
			_mcl = [nm, m, w, 1.0]
			hip = hip.lerp(Vector2(0.0, -float(m[0]) * legk - ankle), w)
			foot_a = foot_a.lerp(Vector2(float(m[1]) * legk, -float(m[2]) * legk), w)
			foot_b = foot_b.lerp(Vector2(float(m[3]) * legk, -float(m[4]) * legk), w)
			legs_lean = lerpf(legs_lean, 0.0, w)
			lean = lerpf(lean, float(m[5]) + clampf(_aim.angle(), -0.9, 0.6) * 0.08, w)
		elif air > 0.0 and cw <= 0.0 and hang <= 0.0:
			var w := air * (1.0 - dive) * (1.0 - slide)
			if w > 0.0:
				var m := _mcl_at("leap", clampf((air_v + 1.0) * 0.5, 0.0, 1.0))
				_mcl = ["leap", m, w, 1.0]
				var fa2 := hip + Vector2(float(m[1]) * legk, (float(m[0]) - float(m[2])) * legk) + Vector2(0.0, ankle)
				var fb2 := hip + Vector2(float(m[3]) * legk, (float(m[0]) - float(m[4])) * legk) + Vector2(0.0, ankle)
				foot_a = foot_a.lerp(fa2, w)
				foot_b = foot_b.lerp(fb2, w)
				legs_lean = lerpf(legs_lean, 0.0, w)
				lean = lerpf(lean, float(m[5]) + clampf(_aim.angle(), -0.9, 0.6) * 0.08, w)
	# inertial blending (see _inert): which move this is; a change of it starts a blend of every part
	var in_key := (String(_mcl[0]) if not _mcl.is_empty() else "") + "|" + (clip if cw > 0.0 else "") + ("|dead" if _dead else "") + ("|swing" if swing >= 0.0 else "") + ("|hang" if hang > 0.5 else "")
	_in_new = in_key != _in_key
	_in_key = in_key
	# (25. 11.) the game's own frame time, not _clock (it stops when he dies: the blend and the coat froze half way) and
	# not the wall clock (the tests run at a fixed frame rate faster than real time); once per frame however often posed
	_in_dt = _frame_dt()
	hip = _inert("hip", hip, 0.09)
	lean = _inert("lean", lean, 0.7, true)
	var breath := sin(_clock * 1.7) * 0.006 * (1.0 - t) * (0.0 if _dead else 1.0)   # breathing, standing still
	var neck := hip + Vector2(lerpf(0.03, lerpf(0.05, 0.15, rw) if g2 else 0.15, t), -float(_len["torso"]) - breath).rotated(lean)
	# Joints that are drawn on the torso (armholes, the bottom of the collar, the belt) are given in
	# the torso drawing's own pixels, so they stay on the drawing however the torso turns.
	var shoulder := neck + Vector2(-0.05, 0.11).rotated(lean)
	var far_shoulder := shoulder
	var head_base := neck + Vector2(0.0, 0.03).rotated(lean)
	var belt := hip
	if cfg.has("on_torso"):
		var on: Dictionary = cfg["on_torso"]
		var turn: float = (neck - hip).angle() - float(_ang["torso"])
		var a0: Vector2 = cfg["parts"]["torso"]["a"]
		var k0: float = 1.0 / float(cfg["parts"]["torso"]["ppm"])
		shoulder = hip + ((on["shoulder"] as Vector2) - a0).rotated(turn) * k0
		far_shoulder = hip + ((on["far_shoulder"] as Vector2) - a0).rotated(turn) * k0
		head_base = hip + ((on["head"] as Vector2) - a0).rotated(turn) * k0
		belt = hip + ((on["belt"] as Vector2) - a0).rotated(turn) * k0

	# The near arm holds the gun on the target. A pistol is held out at arm's length (further when
	# aiming high, so the arm never folds over his face); a long gun is shouldered, the hand close in.
	var gun_key := "pistol" if weapon == "pistols" else weapon
	var gd: Dictionary = GUNS.get(gun_key, GUNS["revolver"])
	var long_gun: bool = gd.has("fore") and not _dead
	var up_aim := clampf(-_aim.y, 0.0, 1.0)
	var reach := (0.3 + 0.04 * up_aim) if long_gun else lerpf(0.55, 0.66, up_aim)
	var near_target := shoulder + _aim * reach + (Vector2(0.0, 0.05) if long_gun else Vector2.ZERO)
	if _dead:
		near_target = shoulder + _aim * (ua + fa) * 0.96
	# reloading: the gun comes in close in front of the chest, muzzle up, and goes back out at the end
	var rl := 0.0
	if reload > 0.0 and not _dead:
		rl = smoothstep(0.0, 0.14, reload) * (1.0 - smoothstep(0.86, 1.0, reload))
		near_target = near_target.lerp(shoulder + (Vector2(0.3, 0.36) if cfg.get("gait2", false) and not long_gun else Vector2(0.24, 0.24)), rl)
	if hands_up > 0.0 and not _dead:
		near_target = near_target.lerp(shoulder + Vector2(0.16, -(ua + fa) * 0.82), hands_up)
	var es := 0.0   # at ease: the gun hand down by the thigh (a long gun low across the body), swinging against the legs
	if ease > 0.0 and not _dead and swing < 0.0:
		es = smoothstep(0.0, 1.0, ease) * (1.0 - rl) * (1.0 - hands_up) * (1.0 - hang) * (1.0 - maxf(dive, slide))
		var low := shoulder + (Vector2(0.14, 0.4) if long_gun else Vector2(0.07 - 0.13 * cos(th) * t, (ua + fa) * 0.93))
		if g2 and not long_gun:   # walking the arm swings from the shoulder; running it pumps, the elbow bent, the gun by his ribs
			var sw := cos(th)   # 1: the near foot is forward, so the near hand is back
			var walk_h := Vector2(0.05 - 0.17 * sw * t, (ua + fa) * (0.95 - 0.03 * absf(sw) * t))
			var run_h := Vector2(0.05, 0.32).lerp(Vector2(-0.18, 0.36), maxf(sw, 0.0)).lerp(Vector2(0.22, 0.26), maxf(-sw, 0.0))
			low = shoulder + walk_h.lerp(run_h, rw * t)
			if not _mc.is_empty():
				low = (shoulder + Vector2(0.05, (ua + fa) * 0.95)).lerp(shoulder + (_mc["hf"] as Vector2), float(_mc["w"]))
		near_target = near_target.lerp(low, es)
	var gun_a := lerp_angle(_aim.angle(), 0.5 if long_gun else 1.2, es)
	if g2 and not long_gun and es > 0.0 and _mc.is_empty():   # the gun lies along the pumping forearm, muzzle up as the fist comes forward
		gun_a = lerp_angle(gun_a, lerpf(-0.4, 0.55, 0.5 + 0.5 * cos(th)), es * rw * t)
	var blow := 0.0   # the angle of the pipe arm, in his own forward frame
	if swing >= 0.0 and not _dead:
		var aim_a := _aim.angle()
		if swing < 0.35:      # up and back over the shoulder
			blow = lerp_angle(aim_a, -2.3, smoothstep(0.0, 0.35, swing))
		elif swing < 0.55:    # down onto him, fast
			blow = lerpf(-2.3, 0.95, smoothstep(0.35, 0.55, swing))
		else:                 # the follow-through, then back to the aim
			blow = lerp_angle(0.95, aim_a, smoothstep(0.6, 1.0, swing))
		near_target = shoulder + Vector2.from_angle(blow) * (ua + fa) * 0.9
	var reach_up := (ua + fa) * 0.96
	hang_top = shoulder.y - reach_up
	var climb_c := 0.5 - 0.5 * cos(hang_cycle * TAU) if hang_cycle >= 0.0 else 0.0
	if hang > 0.0 and not hang_one and not _dead:   # both fists on the rope, one above the other
		near_target = near_target.lerp(Vector2(0.06, hang_top + 0.2 * climb_c), hang)
		if _use_mocap():
			near_target = near_target.lerp(Vector2(0.1, neck.y - 0.02 - 0.2 * climb_c), hang)
	var armk_c := 1.0
	if not _mcl.is_empty():
		armk_c = (ua + fa) / (float(MOCAP.CLIPS[_mcl[0]]["arm"]) * (l1 + l2))
	if not _mcl.is_empty() and _mcl[0] == "getup" and dive > 0.55:   # the first half of getting up: both hands push off the stones
		var mg: Array = _mcl[1]
		near_target = near_target.lerp(shoulder + Vector2(float(mg[9]) * float(_mcl[3]), -float(mg[10])) * (l1 + l2) * armk_c, float(_mcl[2]) * smoothstep(0.55, 0.8, dive))
	if not _mcl.is_empty() and _mcl[0] == "roll":   # tumbling, the hands go where his did: down to the stones and tucked
		var m: Array = _mcl[1]
		near_target = near_target.lerp(shoulder + Vector2(float(m[7]) * float(_mcl[3]), -float(m[8])) * (l1 + l2) * armk_c, float(_mcl[2]))
	if not _mcl.is_empty() and String(_mcl[0]).begins_with("die"):   # falling dead: the gun hand where the sheet throws it
		var md: Array = _mcl[1]
		near_target = shoulder + Vector2(float(md[7]), -float(md[8])) * (l1 + l2) * armk_c
	near_target = _inert("hand_n", near_target)   # (only at a hand-over: the gun arm must follow a quick aim at once)
	var kn := _ik(shoulder, near_target, ua, fa, 1.0)
	var hand: Vector2 = kn[1]
	var gun_scale: float = float(gd["len"]) / float((_gun.texture as Texture2D).get_width())   # metres per picture pixel

	# far arm: with a long gun it holds the fore grip; with two pistols it aims the second one just
	# under the first; with one gun it supports the aim standing and swings against the legs running
	var far_target := (shoulder + _aim * 0.5 + Vector2(0.02, 0.06)).lerp(hip + Vector2(0.25 * cos(th), 0.05), t)
	if g2:   # the free arm against the legs: a hanging swing in the walk, a pump in the run (also while the other aims)
		var fw := Vector2(0.03 + 0.17 * cos(th), (ua + fa) * 0.93)
		var fr := Vector2(0.05, 0.32).lerp(Vector2(-0.18, 0.36), maxf(-cos(th), 0.0)).lerp(Vector2(0.22, 0.24), maxf(cos(th), 0.0))
		far_target = (shoulder + _aim * 0.5 + Vector2(0.02, 0.06)).lerp(far_shoulder + fw.lerp(fr, rw), t)
		if not _mc.is_empty():
			far_target = (shoulder + _aim * 0.5 + Vector2(0.02, 0.06)).lerp(far_shoulder + (_mc["hb"] as Vector2), float(_mc["w"]))
	if long_gun:
		var tex_size := Vector2((_gun.texture as Texture2D).get_size())
		far_target = hand + ((tex_size * ((gd["fore"] as Vector2) - (gd["grip"] as Vector2))) * gun_scale).rotated(gun_a)
	elif (weapon == "pistols" or (dual and weapon == "revolver")) and not _dead:
		far_target = far_shoulder + _aim * reach + Vector2(0.0, 0.07)
	elif air > 0.0 and not _dead and not g2:   # in the air the free arm swings out for balance, up on the way up
		far_target = far_target.lerp(far_shoulder + Vector2(-0.22, -0.08 - 0.18 * clampf(-air_v, 0.0, 1.0) + 0.12 * clampf(air_v, 0.0, 1.0)), air * 0.85)
	if g2 and air > 0.0 and not _dead and not long_gun and not (weapon == "pistols" or (dual and weapon == "revolver")):
		# (user 24. 11.: "in a jump he throws the back arm oddly" - it stood up behind his shoulder like a wing) the free
		# arm stays low: back and bent as he goes up, forward of the hip to meet the landing
		# (25. 11.: bent, the elbow stood out behind his back like a hump) nearly straight down along his side
		far_target = far_target.lerp(far_shoulder + Vector2(-0.14, (ua + fa) * 0.86).lerp(Vector2(0.14, (ua + fa) * 0.84), clampf(air_v * 0.5 + 0.5, 0.0, 1.0)), air)
	if not _mcl.is_empty() and _mcl[0] != "leap" and not long_gun and not (weapon == "pistols" or (dual and weapon == "revolver")):
		# (25. 11.) not the leap's: the long-jumper flings his arms up behind him - on Eddie a wing again (rule 41 (5))
		var m: Array = _mcl[1]
		# (25. 11.: "like a dog" - blended out toward the hanging arm, the hand dropped under his chest like a paw at the
		# hand-over from the take-off to the flight) the dive's free arm stays where the sheets put it, whole
		var aw := 1.0 if (_mcl[0] == "launch" or (_mcl[0] == "flight" and dive > 0.05)) else float(_mcl[2])
		far_target = far_target.lerp(far_shoulder + Vector2(float(m[9]) * float(_mcl[3]), -float(m[10])) * (l1 + l2) * armk_c, aw)
	if es > 0.0 and not long_gun:   # the free arm hangs too, and swings with the walk
		far_target = far_target.lerp(far_shoulder + Vector2(0.03 + 0.13 * cos(th) * t, (ua + fa) * 0.93), es * (1.0 - t) if g2 else es)
	if _dead and (_mcl.is_empty() or not String(_mcl[0]).begins_with("die")):   # dead weight: the arm lies almost straight along the thrown direction
		far_target = far_shoulder + Vector2.from_angle(_aim.angle() + dead_far) * (ua + fa) * 0.96
	if rl > 0.0:   # the other hand works the gun
		far_target = far_target.lerp(hand + Vector2(0.06, 0.03 + 0.03 * sin(reload * 40.0)), rl)
	if hands_up > 0.0 and not _dead:
		far_target = far_target.lerp(far_shoulder + Vector2(0.06, -(ua + fa) * 0.84), hands_up)
	if cw > 0.0 and cl.has("far") and not long_gun and not (weapon == "pistols" or (dual and weapon == "revolver")) 			and not (not _mcl.is_empty() and _mcl[0] == "launch"):   # (the take-off sheet has its own arm: this hung it down like a paw)
		var cf: Vector2 = cl["far"]
		if g2:
			cf = Vector2(0.12, 0.22) if clip == "window" else Vector2(clampf(cf.x, 0.02, 0.16), (ua + fa) * 0.85)   # (25. 11.: behind him it stood out like a wing in the wall kick)
		far_target = far_target.lerp(far_shoulder + cf * Vector2(clip_side, 1.0), cw)
	if hang > 0.0 and not _dead:
		var low := 0.2 * (1.0 - climb_c) if hang_cycle >= 0.0 else (0.0 if hang_one else 0.13)
		far_target = far_target.lerp(Vector2(0.06, hang_top + low), hang)
	far_target = _inert("hand_f", far_target, 0.3)
	var k := _ik(far_shoulder, far_target, ua, fa, 1.0)
	_place("uarm_b", "uarm", far_shoulder, k[0])
	_place("farm_b", "farm", k[0], k[1])
	if _farm_open_tex != null:   # in the air with the hand free: fingers spread for balance
		var open_hand := not _dead and maxf(air, dive) > 0.5 and not long_gun and rl <= 0.0 and hands_up <= 0.0 and hang <= 0.0 \
				and not (weapon == "pistols" or (dual and weapon == "revolver"))
		_spr["farm_b"].texture = _farm_open_tex if open_hand else _farm_tex
	_gun2.position = k[1] * PPM
	_gun2.rotation = _aim.angle() + 0.04
	var far_hand: Vector2 = k[1]

	k = _ik(hip, _inert("foot_b", hip + (foot_b - Vector2(0.0, ankle) - hip).rotated(legs_lean), 0.22), l1, l2, -1.0)
	_place("thigh_b", "thigh", hip, k[0])
	_place("shin_b", "shin", k[0], k[1])
	var leg_b := [hip, k[0], k[1]]
	k = _ik(hip, _inert("foot_a", hip + (foot_a - Vector2(0.0, ankle) - hip).rotated(legs_lean), 0.22), l1, l2, -1.0)
	_place("thigh_f", "thigh", hip, k[0])
	_place("shin_f", "shin", k[0], k[1])
	var leg_f := [hip, k[0], k[1]]
	for side in _crooks:
		var lg: Array = leg_f if side == "f" else leg_b
		(_crooks[side] as Line2D).points = PackedVector2Array([(lg[0] as Vector2) * PPM, (lg[1] as Vector2) * PPM, (lg[1] as Vector2).lerp(lg[2], 0.8) * PPM])
	if _pelvis != null:
		_pelvis.position = hip * PPM
		_pelvis.rotation = legs_lean
	if _legs.has("f"):
		_bend_leg(_legs["f"], leg_f, _leg_shadows.get("f"))
		_bend_leg(_legs["b"], leg_b, _leg_shadows.get("b"))

	if _spr.has("skirt"):   # hangs from the belt, sways with speed, tips with the body
		# in a slide it lies along the legs; crouched it falls back behind the heels; never through the pavement
		var skirt_lean := lean - slide * 0.8 * slide_side + duck * 0.45
		# flying flat, the coat does not lie along him like a board: it hangs off him, pulled down by its
		# own weight and snapping in the wind
		skirt_lean -= dive * dive_side * (0.5 + sin(_clock * 11.0) * 0.07) * (0.0 if _dead else 1.0)
		var hem := belt + (_tail_dir.normalized() * float(_len["skirt"])).rotated(skirt_lean)
		var tumble: bool = roll != 0.0 or (cw > 0.0 and absf(float(cl.get("spin", 0.0))) > 0.0) or (not _mcl.is_empty() and _mcl[0] in ["roll", "getup", "slide", "die_back", "die_front", "hit", "hit_leg"])
		_place("skirt", "skirt", belt, hem)
		if _skirt_mesh:
			_coat_hug = move_toward(_coat_hug, 1.0 if (tumble or (not _mcl.is_empty() and _mcl[0] == "flight")) else 0.0, 0.15)
			_coat_thigh = ((leg_f[1] as Vector2) + (leg_b[1] as Vector2)) * 0.5 - belt
			hem = _bend_skirt(belt, lean, hem, leg_f, leg_b)
		if _skirt_fly:   # flung through the air: the drawn wind-blown coat takes over from the hanging one
			var f := 0.0 if _dead else smoothstep(0.35, 0.8, dive)
			# the drawn run and leap coats: how much of each, eased so a change of pace blends over a few frames
			if tumble or _use_mocap():
				# (25. 11.) the simulated coat (_coat_spine) does it all: a drawn coat faded over it showed as a pale ghost
				# of a coat, and in a tumble it stood up off him like a board
				f = 0.0
			var still := 0.0 if (_dead or tumble or _use_mocap()) else (1.0 - f) * (1.0 - slide) * (1.0 - duck) * (1.0 - hang)
			var fwd: float = _vel.x * signf(scale.x)
			var goal := {"run": clampf((fwd - 260.0) / 320.0, 0.0, 1.0) * (1.0 - air) * still,
					"air": smoothstep(0.25, 0.7, air) * still}
			var drawn := 0.0
			for pose in _skirt_poses:
				_skirt_w[pose] = lerpf(float(_skirt_w[pose]), float(goal[pose]), 0.25)
				drawn += float(_skirt_w[pose])
			drawn = minf(drawn, 1.0)
			for pose in _skirt_poses:
				var sp: Sprite2D = _skirt_poses[pose]
				var w := float(_skirt_w[pose])
				sp.visible = w > 0.02
				sp.self_modulate.a = w
				if sp.visible:   # hangs off the belt like the plain coat, the cloth working in the wind
					sp.position = belt * PPM
					sp.rotation = (hem - belt).angle() - PI * 0.5 + (0.08 if pose == "run" else 0.0)
					var flap := sin(_clock * (13.0 if pose == "run" else 8.0)) * 0.035
					sp.scale = _spr["skirt"].scale * Vector2(1.0 + flap, 1.0 - flap * 0.6)
			_skirt_fly.visible = f > 0.01
			_skirt_mesh.visible = f < 0.99 and drawn < 0.98
			# set every frame: a dive that ends in one step (a landing, a death) jumps f to 0, and a fade
			# left at its last value kept the hanging coat see-through for good (seen on the phone)
			_skirt_fly.self_modulate.a = f
			_skirt_mesh.self_modulate.a = clampf(1.0 - maxf(f, drawn), 0.0, 1.0) if f > 0.01 or drawn > 0.02 else 1.0
			if _skirt_fly.visible:
				_skirt_fly.position = belt * PPM
				_skirt_fly.rotation = (hem - belt).angle() - PI * 0.5 - 0.15 * dive_side
	_place("torso", "torso", hip, neck)
	for c in _collars:
		c.position = _spr["torso"].position
		c.rotation = _spr["torso"].rotation
	# the head tips less than the body, and turns a little after the aim: he looks where he shoots
	var look := (lean - roll - spin) * 0.5 + roll + spin   # (24. 11.: the head went only half way round a flip - upside down in his coat)
	if not _mc.is_empty():
		look = lerp_angle(look, float(_mc["head"]) * 0.6 + lean * 0.4, float(_mc["w"]))
	if not _mcl.is_empty() and _mcl[0] in ["roll", "slide", "getup", "flight", "hit", "hit_leg", "die_back", "die_front"]:
		look = lerp_angle(look, float(_mcl[1][6]) * float(_mcl[3]) + (clampf(_aim.angle(), -0.9, 0.7) * (0.6 if _mcl[0] == "flight" else 0.3) if not _mcl[0] in ["roll", "die_back", "die_front"] else 0.0), float(_mcl[2]))
	if _use_mocap() and hang > 0.0 and not hang_one and not _dead:
		look = lerp_angle(look, -0.18, hang)   # chin up, looking up the rope
	if not _dead:
		look += clampf(_aim.angle(), -0.9, 0.7) * 0.4 * (1.0 - hands_up) * (1.0 - es) - recoil * 0.3 + hands_up * 0.12
		if not hang_one:
			look = lerp_angle(look, -0.35 if hang_cycle >= 0.0 else -0.1, hang)   # eyes on where the rope goes
		if reload > 0.0:   # eyes on the gun in his hands
			look = lerp_angle(look, 0.35, smoothstep(0.0, 0.14, reload) * (1.0 - smoothstep(0.86, 1.0, reload)))
	# (user 25. 11.: "the head is oddly broken at the landing and the roll") a tumble counts its angles past a full turn
	# (the roll 80 -> 380 deg) and a plain lerp against the crouch's ~0 swept the head round backwards, 130 deg against
	# the torso: every head blend is lerp_angle now, and the neck never bends further than a neck can, any figure alive
	if not _dead:
		look = lean + clampf(wrapf(look - lean, -PI, PI), -1.1, 1.25)
	look = _inert("look", look, 0.7, true)
	_place("head", "head", head_base, head_base + Vector2(0.02, -0.3).rotated(look))
	if _headlog and self == get_tree().current_scene.get("player"):   # (test --headlog) the neck: the head against the torso, every frame
		print("HEAD %.3f %s lean %.0f look %.0f neck %.0f" % [_clock, (String(_mcl[0]) if not _mcl.is_empty() else (clip if cw > 0.0 else "-")), rad_to_deg(lean), rad_to_deg(look), rad_to_deg(wrapf(look - lean, -PI, PI))])
	# laid out flat in a dive the near arm reaches forward at the height of his face: it hid the face (24. 11.) - the head,
	# chin up, goes over the arm, which then runs under his jaw (the shootdodge as drawn in the comics)
	var over := 1 if (not _mcl.is_empty() and ((_mcl[0] == "flight" and dive > 0.4) or (_mcl[0] == "launch" and float(_mcl[2]) > 0.4))) else 0
	_spr["head"].z_index = over
	for c in _collars:
		c.z_index = over
	# (user 25. 11.: "the collar is an explosion again, and the neck") running, the body leans and the head stays up:
	# a collar piece round the neck stayed with the leaning body and its tip stood over his ear like a flap. Every
	# piece cut near the neck turns with the head about the neck, as when he stands
	var torso_tilt := wrapf((neck - hip).angle() - Vector2(0.03, -float(_len["torso"])).angle(), -PI, PI)   # the torso as drawn against standing
	var neck_d := wrapf(look - torso_tilt, -PI, PI)
	var tp: Dictionary = cfg["parts"]["torso"]
	var pv: Vector2 = _spr["torso"].position + ((cfg["on_torso"]["head"] as Vector2) - (tp["a"] as Vector2)).rotated(_spr["torso"].rotation) * (PPM / float(tp["ppm"]))
	for c in _collars:
		if (c.region_rect.position.y + c.region_rect.size.y * 0.5) < float((cfg["on_torso"]["head"] as Vector2).y) + 120.0:
			c.rotation = _spr["torso"].rotation + neck_d
			c.position = pv + (_spr["torso"].position - pv).rotated(neck_d)

	_place("uarm_f", "uarm", shoulder, kn[0])
	_place("farm_f", "farm", kn[0], kn[1])
	if _jointlog and self == get_tree().current_scene.get("player"):   # (test --jointlog) every joint as shown, for gen/tests/jerk.py
		print("JL %.4f %s %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f %.4f" % [_clock, _in_key.replace(" ", "_") if _in_key != "" else "-",
				hip.x, hip.y, (leg_f[2] as Vector2).x, (leg_f[2] as Vector2).y, (leg_b[2] as Vector2).x, (leg_b[2] as Vector2).y,
				kn[1].x, kn[1].y, far_hand.x, far_hand.y, lean, look])
	_gun.position = hand * PPM
	_gun.rotation = gun_a
	# the drawn hand grips it: it comes out of the cuff, the wrist bending from the forearm to the gun's line
	var gripped := _grip_ok() and not disarmed and not (hang > 0.5 and not hang_one) and not (swing >= 0.0 and not _dead)
	if gripped != _grip:
		_set_grip(gripped)
	if _grip:
		_gun.position = kn[0].lerp(kn[1], float(cfg["grip_cuff"])) * PPM
	if g2 and not long_gun and es > 0.0 and not _mc.is_empty():   # (user 25. 11.: "the gun is broken in his hand") the gun follows the forearm,
		# the wrist cocked a little so the muzzle leans forward; never pointing back at him
		var fa_ang := wrapf((kn[1] - kn[0]).angle() - 0.3, -PI, PI)
		_gun.rotation = lerp_angle(gun_a, clampf(fa_ang, -1.1, 1.35), es)
	if not _mcl.is_empty() and (_mcl[0] == "roll" or (_mcl[0] == "getup" and dive > 0.55)):   # the gun along the forearm while the hand is on the stones
		_gun.rotation = lerp_angle(gun_a, (kn[1] - kn[0]).angle(), float(_mcl[2]) * (1.0 if _mcl[0] == "roll" else smoothstep(0.55, 0.8, dive)))
	_gun.visible = not disarmed and not (hang > 0.5 and not hang_one) and not (swing >= 0.0 and not _dead)   # both hands on the rope: the gun is in his coat
	if _pipe != null:
		_pipe.visible = swing >= 0.0 and not _dead
		if _pipe.visible:
			_pipe.position = hand * PPM
			_pipe.rotation = blow
	if disarmed:
		_gun2.visible = false
	if rl > 0.0:   # muzzle up; near the end a flick of the wrist snaps the cylinder home
		var flick := sin(clampf((reload - 0.78) / 0.1, 0.0, 1.0) * PI) * 0.5
		_gun.rotation = lerp_angle(_aim.angle(), (-0.85 if cfg.get("gait2", false) else -1.25) + flick, rl)   # (gait2: held out from the coat, it reads as a gun, not a pocket)
	if _shadow:
		for key in _shadow_spr:
			var src: Node2D = _gun if key == "gun" else (_gun2 if key == "gun2" else _spr[key])
			var d: Node2D = _shadow_spr[key]
			d.position = src.position
			d.rotation = src.rotation
	for w in _wounds:   # the wounds go where the bones went
		_place_wound(w)


## Turn the gun arm onto `aim` at once, without the usual easing: a tap on the screen fires exactly
## where the finger is, not where the arm happened to be pointing.
func snap_aim(aim: Vector2) -> void:
	scale = Vector2((-1.0 if aim.x < 0.0 else 1.0) * size, size) * _fs()
	_aim_angle = Vector2(absf(aim.x), aim.y).angle()
	_aim = Vector2.from_angle(_aim_angle - recoil)
	_pose()


## Dying: no more running or aiming. The gun arm goes where the hit throws it (an angle in the
## figure's own facing, 0 = straight ahead, negative = up) and the knees give by `knees`.
func die_pose(arm: float, knees: float) -> void:
	_dead = true
	_moving = 0.0
	duck = knees
	_aim = Vector2.from_angle(arm)
	_tail_dir = _tail_dir.lerp(Vector2(0.0, 0.5), 0.2)   # the coat settles along the legs, so it lies flat with him
	_pose()
	queue_redraw()


## Which body part a bullet at `world` is inside, or "" for a miss. The test follows the posed
## bones, so a crouch, a dive or a fall changes what can be hit exactly as it looks.
func hit_part(world: Vector2) -> String:
	var p := to_local(world)
	for key in HIT_RADIUS:
		if not _bones.has(key):
			continue
		var bone: Array = _bones[key]
		var near := Geometry2D.get_closest_point_to_segment(p, bone[0], bone[1])
		if near.distance_to(p) < float(HIT_RADIUS[key]) * PPM:
			return key
	return ""


## The coat skirt as a grid laid over its drawing, rows down from the belt to the hem.
func _make_skirt_mesh() -> Polygon2D:
	var m := Polygon2D.new()
	m.texture_filter = MIPS
	var tex := _tex(String(cfg["dir"]) + "skirt")
	m.texture = tex
	var size := Vector2((tex as Texture2D).get_size())
	var p: Dictionary = cfg["parts"]["skirt"]
	var uv := PackedVector2Array()
	for r in SKIRT_ROWS + 1:
		for c in SKIRT_COLS + 1:
			uv.append(Vector2(size.x * c / SKIRT_COLS, lerpf(float((p["a"] as Vector2).y), float((p["b"] as Vector2).y), float(r) / SKIRT_ROWS)))
	m.uv = uv
	m.polygon = uv
	var quads := []
	for r in SKIRT_ROWS:
		for c in SKIRT_COLS:
			var i := r * (SKIRT_COLS + 1) + c
			quads.append(PackedInt32Array([i, i + 1, i + SKIRT_COLS + 2]))   # (triangles: see _make_leg_mesh)
			quads.append(PackedInt32Array([i, i + SKIRT_COLS + 2, i + SKIRT_COLS + 1]))
	m.polygons = quads
	m.light_mask = MASK_FIGURE
	return m


## Bend the coat: from the belt it follows the hips, lower down it swings out to where the tail of
## the coat is blown (the hem), and in a stride its front and back edges are carried by the legs so
## it parts round them instead of sweeping through them like a board.
func _coat_spine(belt: Vector2, top_dir: Vector2, end_dir: Vector2, length: float) -> PackedVector2Array:
	var n := SKIRT_ROWS + 1
	var seg := length / SKIRT_ROWS
	var kin := PackedVector2Array()   # the old kinematic curve: the start, and the still-frame tests
	var c := belt
	for r in n:
		if r > 0:
			c += top_dir.slerp(end_dir, pow(float(r) / SKIRT_ROWS, 1.4)) * seg
		kin.append(c)
	var frame := float(Engine.get_process_frames())   # game time by frames (his _clock stops when he dies)
	if blend_off or _coat.size() != n or _coat_clock < 0.0 or frame - _coat_clock > 8.0:
		_coat = kin.duplicate()
		_coat_prev = kin.duplicate()
		_coat_clock = frame
		return kin
	var dt := minf(get_process_delta_time(), 0.05) if frame != _coat_clock else 0.0
	_coat_clock = frame
	if dt <= 0.0:
		return _coat
	var sx := signf(scale.x) if scale.x != 0.0 else 1.0
	var k := PPM * maxf(0.01, absf(scale.x))
	var v_loc := Vector2(_vel.x * sx, _vel.y) / k                       # the body's speed, in his own frame (m/s)
	var acc := ((v_loc - _coat_v) / dt).limit_length(60.0)               # and how it changed
	_coat_v = v_loc
	var g := Vector2(0.0, 9.8).rotated(-rotation)
	var steps := 2
	var h := dt / steps
	for s in steps:
		for i in range(1, n):
			var p := _coat[i]
			var vel := (p - _coat_prev[i]) / maxf(h, 0.0001)
			# gravity; the body's acceleration felt backwards (inertia); air streaming past a moving body; a little
			# rain-heavy damping; a flutter that grows with speed toward the hem
			var air := (-v_loc - vel) * (2.6 * float(i) / SKIRT_ROWS)
			var flutter := Vector2(0.0, sin(_clock * 13.0 + i * 1.3) * 0.6) * clampf(v_loc.length() / 5.0, 0.0, 1.0) * float(i) / SKIRT_ROWS
			var a := g - acc * 0.3 + air + flutter   # (a heavy wet trench coat: a stop throws it forward a little, not up like an apron)
			_coat_prev[i] = p
			_coat[i] = p + vel * h * 0.97 + a * h * h
		_coat[0] = belt
		for it in 4:   # inextensible, bending like cloth, off the pavement, not up through the body
			for i in range(1, n):
				var prev_dir := top_dir if i == 1 else (_coat[i - 1] - _coat[i - 2]).normalized()
				var d := _coat[i] - _coat[i - 1]
				var ang := prev_dir.angle_to(d)
				var lim := 0.32 if i == 1 else 0.22   # the top follows the hips, each row bends a little from the last (stiff cloth)
				if absf(ang) > lim:
					d = prev_dir.rotated(signf(ang) * lim) * d.length()
				_coat[i] = _coat[i - 1] + d.normalized() * seg
				if _coat[i].y > -0.03 and rotation == 0.0:   # (dead too: lying, the coat lies on the stones, not under them)
					_coat[i].y = -0.03
			if _coat_hug > 0.0:   # wrapped round the legs: along the thighs, then on past the knees
				var td := _coat_thigh.normalized() if _coat_thigh.length() > 0.01 else top_dir
				for i in range(1, n):
					var want := belt + td * seg * i
					_coat[i] = _coat[i].lerp(want, _coat_hug * 0.35)
	return _coat


func _bend_skirt(belt: Vector2, lean: float, hem: Vector2, leg_f: Array, leg_b: Array) -> Vector2:
	var p: Dictionary = cfg["parts"]["skirt"]
	var ppm := float(p["ppm"])
	var tex_w := float((_skirt_mesh.texture as Texture2D).get_width())
	var ax := float((p["a"] as Vector2).x)
	var length := float(_len["skirt"])
	var top_dir := Vector2(0.0, 1.0).rotated(lean)
	var end_dir := (hem - belt).normalized()
	var spine := _coat_spine(belt, top_dir, end_dir, length)
	var open := clampf(_moving * 0.8 + air * 0.6 + slide * 0.3, 0.0, 1.0) * (0.0 if _dead else 1.0)
	var pts := PackedVector2Array()
	var center := belt
	var last_row: Array = []   # (the row above: rows and columns must never cross - a folded quad draws nothing and
	# the background shows through the coat, outlined: user 17. 11. "a white spot on the coat when he moves")
	for r in SKIRT_ROWS + 1:
		var v := float(r) / SKIRT_ROWS
		center = spine[r]
		var d := top_dir if r == 0 else (spine[r] - spine[r - 1]).normalized()
		var n := Vector2(d.y, -d.x)   # across the coat, front edge on the + side
		var flare := 1.0 + 0.12 * v
		var at_f := _along_leg(leg_f, v)
		var at_b := _along_leg(leg_b, v)
		var row: Array = []
		for c in SKIRT_COLS + 1:
			var across := (tex_w * c / SKIRT_COLS - ax) / ppm * flare
			var q := center + n * across
			# the edge nearer each leg is pulled with it as he strides; the middle stays between
			var pull := open * smoothstep(0.15, 1.0, v) * 0.65
			if c == SKIRT_COLS:
				q = q.lerp(at_f + n * 0.05, pull)
			elif c == 0:
				q = q.lerp(at_b - n * 0.05, pull)
			elif c == SKIRT_COLS - 1:
				q = q.lerp(at_f - n * 0.02, pull * 0.5)
			elif c == 1:
				q = q.lerp(at_b + n * 0.02, pull * 0.5)
			if c > 0:   # left of the next column, never past it
				var left: Vector2 = row[c - 1]
				if (q - left).dot(n) < 0.004:
					q += n * (0.004 - (q - left).dot(n))
			if not last_row.is_empty() and (q - (last_row[c] as Vector2)).dot(d) < 0.002:   # below the row above
				q += d * (0.002 - (q - (last_row[c] as Vector2)).dot(d))
			row.append(q)
			pts.append(q * PPM)
		last_row = row
	_skirt_mesh.polygon = pts
	if _skirt_shadow:
		_skirt_shadow.polygon = pts
	return spine[spine.size() - 1]


## A point down a leg (hip, knee, ankle) at fraction v of the coat's length.
func _along_leg(leg: Array, v: float) -> Vector2:
	var u := v * 1.6
	if u < 1.0:
		return (leg[0] as Vector2).lerp(leg[1], u)
	return (leg[1] as Vector2).lerp(leg[2], minf(1.0, u - 1.0))


## A whole straight leg drawing as a strip of rows, bent along hip, knee and ankle each frame.
func _make_leg_mesh() -> Polygon2D:
	var m := Polygon2D.new()
	m.texture_filter = MIPS
	var tex: Texture2D = _tex(String(cfg["leg_tex"]).trim_suffix(".png"))
	m.texture = tex
	var size := Vector2(tex.get_size())
	var uv := PackedVector2Array()
	for r in LEG_ROWS + 1:
		var v := float(r) / LEG_ROWS
		for c in 3:
			uv.append(Vector2(size.x * c * 0.5, size.y * v))
	m.uv = uv
	m.polygon = uv
	var quads := []
	for r in LEG_ROWS:
		for c in 2:
			var i := r * 3 + c
			# (two triangles, never a quad: a quad bent into a bow-tie is not drawn at all and the background shows
			# through the leg - user 17. 11. "a white spot on the coat"; a twisted triangle still draws)
			quads.append(PackedInt32Array([i, i + 1, i + 4]))
			quads.append(PackedInt32Array([i, i + 4, i + 3]))
	m.polygons = quads
	m.light_mask = MASK_FIGURE
	return m


## Rows above the knee follow the thigh, rows below follow the shin, and round the knee the
## direction turns smoothly, so the trouser bends instead of breaking at a pin.
func _bend_leg(m: Polygon2D, leg: Array, shadow) -> void:
	var tex: Texture2D = m.texture
	var size := Vector2(tex.get_size())
	var hip: Vector2 = leg[0]
	var knee: Vector2 = leg[1]
	var ankle: Vector2 = leg[2]
	var up_dir := (knee - hip).normalized()
	var lo_dir := (ankle - knee).normalized()
	var ppm := (LEG_ANKLE - LEG_HIP) * size.y / ((knee - hip).length() + (ankle - knee).length())
	var axis := LEG_AXIS * size.x
	var pts := PackedVector2Array()
	var mid := up_dir.slerp(lo_dir, 0.5)   # down the leg at the knee: the plane thigh and shin meet on
	var prev: Array = [null, null, null]   # each column's last point: on the inside of a bent knee the rows must not cross
	for r in LEG_ROWS + 1:
		var v := float(r) / LEG_ROWS
		var at: Vector2
		var d: Vector2
		if v <= LEG_KNEE:   # each bone's rows stretched to the bone, so thigh and shin meet at the knee
			at = hip.lerp(knee, (v - LEG_HIP) / (LEG_KNEE - LEG_HIP))
		else:
			at = knee.lerp(ankle, (v - LEG_KNEE) / (LEG_ANKLE - LEG_KNEE))
		var blend := smoothstep(LEG_KNEE - 0.13, LEG_KNEE + 0.13, v)
		d = up_dir.slerp(lo_dir, blend)
		var n := Vector2(-d.y, d.x)   # across the leg; the drawing's right (the toe) is +x
		for c in 3:
			var across := (size.x * c * 0.5 - axis) / ppm
			var q := at - n * across
			# (user 17. 11.: "a white spot on the coat when he moves" - a knee bent hard folded the inside of the leg over
			# itself; the flipped triangles caught the light white. Thigh rows stay on the hip side of the knee's
			# mid-plane, shin rows on the foot side, and no column runs backwards)
			var side := (q - knee).dot(mid)
			if v <= LEG_KNEE and side > 0.0:
				q -= mid * side
			elif v > LEG_KNEE and side < 0.0:
				q -= mid * side
			if prev[c] != null and (q - (prev[c] as Vector2)).dot(d) < 0.0:
				q -= d * (q - (prev[c] as Vector2)).dot(d)
			prev[c] = q
			pts.append(q * PPM)
	m.polygon = pts
	if shadow:
		(shadow as Polygon2D).polygon = pts


## A bullet went in here: a small dark wound on the part it hit, and he flinches.
func add_wound(world: Vector2, part: String) -> void:
	_flinch = 1.0
	_hit_part = part
	if part.begins_with("thigh") or part.begins_with("shin"):
		_hit_dip = 1.0                 # a leg gives under him
	elif part.begins_with("uarm") or part.begins_with("farm"):
		recoil = maxf(recoil, 0.55)    # the gun arm jerks off its aim
	if not _bones.has(part) or _wounds.size() >= 8:
		return
	# The wound rides on its bone (the legs and the coat bend, so a sprite on a part would slide off):
	# how far along the bone, and how far to the side of it.
	var bone: Array = _bones[part]
	var a: Vector2 = bone[0]
	var ab: Vector2 = bone[1] - a
	var p := to_local(world)
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	var n := ab.normalized().orthogonal()
	var w := Node2D.new()
	w.set_meta("bone", part)
	w.set_meta("t", t)
	w.set_meta("off", (p - (a + ab * t)).dot(n) * 0.7)
	w.set_meta("spin", randf() * TAU)
	add_child(w)
	_wounds.append(w)
	# plain to see: a wet stain soaking out through the cloth, the dark hole in it, a run of blood below
	var size := randf_range(46.0, 62.0) / absf(global_scale.y)
	var tex: Texture2D = load("res://art/fx/blood%d.png" % (randi() % 4 + 1))
	var stain := Sprite2D.new()
	stain.texture = tex
	stain.modulate = Color(0.6, 0.05, 0.04, 0.95)
	stain.light_mask = MASK_FIGURE
	stain.scale = Vector2.ONE * size / 352.0 * 0.3
	w.add_child(stain)
	stain.create_tween().tween_property(stain, "scale", Vector2.ONE * size / 352.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var hole := Sprite2D.new()
	hole.texture = tex
	hole.modulate = Color(0.07, 0.0, 0.0)
	hole.light_mask = MASK_FIGURE
	hole.rotation = randf() * TAU
	hole.scale = Vector2.ONE * size * 0.3 / 352.0
	w.add_child(hole)
	var run := Line2D.new()
	run.width = 5.0 / absf(global_scale.y)
	run.default_color = Color(0.5, 0.03, 0.03, 0.9)
	run.begin_cap_mode = Line2D.LINE_CAP_ROUND
	run.end_cap_mode = Line2D.LINE_CAP_ROUND
	run.light_mask = MASK_FIGURE
	run.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	add_child(run)
	w.set_meta("run", run)
	w.set_meta("born", _clock)
	_place_wound(w)


## Keep a wound on its bone, and its trickle running straight down from it, longer for a second or two.
func _place_wound(w: Node2D) -> void:
	var bone: Array = _bones.get(String(w.get_meta("bone")), [])
	if bone.is_empty():
		return
	var a: Vector2 = bone[0]
	var ab: Vector2 = bone[1] - a
	w.position = a + ab * float(w.get_meta("t")) + ab.normalized().orthogonal() * float(w.get_meta("off"))
	w.rotation = ab.angle() + float(w.get_meta("spin"))
	# the trickle runs down the body along the bone, never off it into the air; none from the arms,
	# which swing about (the stain shows there), and it stops where the bone ends
	var run: Line2D = w.get_meta("run")
	var part := String(w.get_meta("bone"))
	if part.begins_with("uarm") or part.begins_with("farm") or part == "head":
		run.visible = false
		return
	var down: Vector2 = ab if ab.y >= 0.0 else -ab
	var t: float = w.get_meta("t")
	var left: float = ab.length() * ((1.0 - t) if ab.y >= 0.0 else t)   # what is left of the bone below the wound
	var k := clampf((_clock - float(w.get_meta("born"))) / 1.6, 0.0, 1.0)
	var reach := minf(42.0 / absf(global_scale.y) * k, left * 0.8)
	run.set_point_position(0, w.position)
	run.set_point_position(1, w.position + down.normalized() * reach)


## Put a gun in his hands: one of GUNS. Two pistols: one in each hand.
## Changing guns: the arm drops the one in hand to the coat, comes back up with the other (0.3 s).
const SWITCH_TIME := 0.3
var _switch_p := -1.0   # 0..1 through a change of guns, -1 = not changing
var _switch_to := ""

func switch_to(name: String) -> void:
	if _dead or name == weapon:
		set_weapon(name)
		return
	_switch_to = name
	_switch_p = 0.0


func set_weapon(name: String) -> void:
	var key := "pistol" if name == "pistols" or (name == "revolver" and side == "beretta") else name
	if not GUNS.has(key):
		key = "revolver"
	weapon = name
	var gd: Dictionary = GUNS[key]
	for g in [_gun, _gun2]:
		var tex: Texture2D = load(gd["tex"])
		g.texture = tex
		g.offset = -Vector2(tex.get_size()) * (gd["grip"] as Vector2)
		g.scale = Vector2.ONE * float(gd["len"]) * PPM / tex.get_width()
	_gun2.visible = name == "pistols" or (dual and name == "revolver")
	_grip = false
	_set_grip(_grip_ok())
	if _shadow_spr.has("gun"):
		for k in ["gun", "gun2"]:
			var src: Sprite2D = _gun if k == "gun" else _gun2
			var d: Sprite2D = _shadow_spr[k]
			d.texture = src.texture
			d.offset = src.offset
			d.scale = src.scale
			d.visible = src.visible
	_pose()


func _grip_ok() -> bool:
	if not cfg.has("grip_cuff") or not _spr.has("farm_f") or weapon == "pistols" or (dual and weapon == "revolver"):
		return false
	var key := "pistol" if weapon == "revolver" and side == "beretta" else weapon
	return GUNS.has(key) and (GUNS[key] as Dictionary).has("hand")


## Swap the gun in the near hand between the bare gun over a fist and the drawn hand gripping it.
func _set_grip(on: bool) -> void:
	if on == _grip and (not on or _grip_tex != null):
		return
	_grip = on
	var key := "pistol" if weapon == "pistols" or (weapon == "revolver" and side == "beretta") else weapon
	var gd: Dictionary = GUNS.get(key, GUNS["revolver"])
	var farm: Sprite2D = _spr["farm_f"]
	if on:
		var hd: Dictionary = gd["hand"]
		var tex: Texture2D = load(hd["tex"])
		_gun.texture = tex
		_gun.offset = -Vector2(tex.get_size()) * (hd["wrist"] as Vector2)
		_gun.scale = Vector2.ONE * float(hd["len"]) * PPM / tex.get_width()
		_gun.modulate = Color(0.78, 0.78, 0.8)
		if _grip_tex == null:
			_grip_tex = _tex(String(cfg["dir"]) + "farm_grip")
		farm.texture = _grip_tex
	else:
		var tex: Texture2D = load(gd["tex"])
		_gun.texture = tex
		_gun.offset = -Vector2(tex.get_size()) * (gd["grip"] as Vector2)
		_gun.scale = Vector2.ONE * float(gd["len"]) * PPM / tex.get_width()
		farm.texture = _tex(String(cfg["dir"]) + "farm")
	if _shadow_spr.has("gun"):
		var d: Sprite2D = _shadow_spr["gun"]
		d.texture = _gun.texture
		d.offset = _gun.offset
		d.scale = _gun.scale


## The crown of his hat and the top of his near shoulder, in world coordinates: where rain lands on him.
func head_top() -> Vector2:
	var h: Sprite2D = _spr["head"]
	return to_global(h.position + Vector2(0.0, -0.28 * PPM).rotated(h.rotation))


func shoulder_top() -> Vector2:
	return to_global((_bones["uarm_f"][0] as Vector2) + Vector2(-0.04 * PPM, -0.03 * PPM))


## The end of the barrel, in world coordinates. With two pistols the hands take turns.
func muzzle() -> Vector2:
	var g := _gun2 if (_left_shot and _gun2.visible) else _gun
	var key := "pistol" if weapon == "pistols" or (weapon == "revolver" and side == "beretta") else weapon
	var gd: Dictionary = GUNS.get(key, GUNS["revolver"])
	var size_px := Vector2(g.texture.get_size())
	var mz: Vector2 = (gd["hand"]["muzzle"] if g == _gun and _grip else gd["muzzle"])
	var local := (size_px * mz + g.offset) * g.scale
	return to_global(g.position + local.rotated(g.rotation))


## After a shot with two pistols, the other hand fires next.
func next_hand() -> void:
	if weapon == "pistols" or (dual and weapon == "revolver"):
		_left_shot = not _left_shot


## Where the gun points, in world coordinates.
func aim_dir() -> Vector2:
	return Vector2(_aim.x * scale.x, _aim.y)


func _place(sprite: String, part: String, a: Vector2, b: Vector2) -> void:
	var s: Sprite2D = _spr[sprite]
	_bones[sprite] = [a * PPM, b * PPM]
	s.position = a * PPM
	s.rotation = (b - a).angle() - float(_ang[part])


## Two-bone reach from a towards target. Returns [middle joint, end]. bend picks which way the joint folds.
func _ik(a: Vector2, target: Vector2, l1: float, l2: float, bend: float) -> Array:
	var d := target - a
	var dist := clampf(d.length(), 0.0001, l1 + l2 - 0.0001)
	var u := Vector2.DOWN
	if d.length() > 0.0001:
		u = d.normalized()
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var out := sqrt(maxf(0.0, l1 * l1 - along * along))
	var joint := a + u * along + Vector2(-u.y, u.x) * out * bend
	return [joint, a + u * dist]
