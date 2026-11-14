extends Node2D
# A character built from drawn parts. No stored animation: every frame the code decides where the
# feet, hips and hands are, solves the knees and elbows, and lays each drawn part between its two joints.

const PPM := 200.0   # world pixels per metre
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
	"revolver": {"tex": "res://art/guns/revolver.png", "len": 0.34, "grip": Vector2(0.17, 0.56), "muzzle": Vector2(1.0, 0.13)},
	"pistol": {"tex": "res://art/guns/pistol.png", "len": 0.33, "grip": Vector2(0.21, 0.55), "muzzle": Vector2(1.0, 0.13)},
	"tommy": {"tex": "res://art/guns/tommy.png", "len": 0.92, "grip": Vector2(0.42, 0.6), "muzzle": Vector2(1.0, 0.16), "fore": Vector2(0.76, 0.58), "stock": true},
	"shotgun": {"tex": "res://art/guns/shotgun.png", "len": 1.0, "grip": Vector2(0.31, 0.42), "muzzle": Vector2(1.0, 0.07), "fore": Vector2(0.68, 0.3), "stock": true},
}
var weapon := ""
var _legs := {}            # "f"/"b" -> the bending leg mesh
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
	COLOR = vec4(col, max(c.a, m * 0.5) * fade);   // a thin ink line that closes the silhouette, not a sticker edge
}
"""

var _spr := {}
var _ang := {}
var _len := {}
var _gun: Sprite2D
var _collars: Array[Sprite2D] = []
var _phase := 0.0
var _moving := 0.0   # 0 standing .. 1 running, eased so the pose blends instead of snapping
var _aim := Vector2.RIGHT
var _aim_angle := 0.0
var _vel := Vector2.ZERO          # how fast the figure is really moving, for the coat
var _last := Vector2.ZERO
var _have_last := false
var _clock := 0.0
var _tail_dir := Vector2(0.0, 0.5)   # where the coat tail hangs to, from its root
var air := 0.0       # 0 on the ground .. 1 in a jump: the legs tuck up
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
var _dead := false   # set by die_pose: the arms hang straight from the shoulders, no aiming, no IK twists
var roll := 0.0      # extra turn of the whole body, radians: a tumble out of a dive
var ground := 0.0    # where the pavement is below the figure's origin, in pixels (0 when standing on it)
var reload := 0.0    # 0: not reloading; else how far through it (0..1): the gun comes in to the chest
var recoil := 0.0    # set after a shot: the gun arm kicks up by this many radians and settles back
var _shadow: CanvasGroup   # a black copy of the figure, thrown onto the wall by the nearest lamp
var _shadow_spr := {}


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
	mat.set_shader_parameter("line", Vector3(0.03, 0.03, 0.035))
	mat.set_shader_parameter("boost", Vector3(body_boost.r, body_boost.g, body_boost.b))
	_body.material = mat
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
			_body.add_child(g)
			if row[0] == "gun":
				_gun = g
			else:
				_gun2 = g
			continue
		if String(row[0]).begins_with("collar"):
			if parts.has(row[0]):   # a piece of the torso drawing laid over the head or the sleeve again
				var c := Sprite2D.new()
				c.texture = _tex(String(cfg["dir"]) + "torso")
				c.centered = false
				c.region_enabled = true
				c.region_rect = parts[row[0]]
				c.offset = (parts[row[0]] as Rect2).position - parts["torso"]["a"]
				c.scale = Vector2.ONE * (PPM / float(parts["torso"]["ppm"]))
				c.light_mask = MASK_FIGURE
				_body.add_child(c)
				_collars.append(c)
			continue
		if not parts.has(part):
			continue
		var s := Sprite2D.new()
		s.texture = _tex(String(cfg["head_tex"]).trim_suffix(".png")) if part == "head" and cfg.has("head_tex") else _tex(String(cfg["dir"]) + part)
		s.centered = false
		s.offset = -parts[part]["a"]
		if parts[part].has("region"):   # only part of the drawing is used
			s.region_enabled = true
			s.region_rect = parts[part]["region"]
			s.offset += (parts[part]["region"] as Rect2).position
		s.scale = Vector2.ONE * (PPM / float(parts[part]["ppm"]))
		if row[2]:
			s.modulate = Color(0.55, 0.55, 0.55)
		s.light_mask = MASK_FIGURE
		_body.add_child(s)
		_spr[row[0]] = s
	set_weapon(String(cfg.get("weapon", "revolver")))
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
	if _spr.has("skirt"):
		_skirt_mesh = _make_skirt_mesh()
		_body.add_child(_skirt_mesh)
		_body.move_child(_skirt_mesh, _spr["skirt"].get_index())
		_spr["skirt"].visible = false
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
func _tex(path: String) -> Texture2D:
	var diffuse: Texture2D = load(path + ".png")
	if not ResourceLoader.exists(path + "_n.png"):
		return diffuse
	var t := CanvasTexture.new()
	t.diffuse_texture = diffuse
	t.normal_texture = load(path + "_n.png")
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


## dx: how far the shadow lands from the feet (world pixels), skew: its lean, alpha: 0 = no lamp near.
func set_shadow(dx: float, skew_amount: float, alpha: float) -> void:
	_shadow.self_modulate = Color(1.0, 1.0, 1.0, alpha)
	_shadow.position = Vector2(dx * scale.x, -6.0)
	_shadow.skew = skew_amount * scale.x
	_shadow.scale = Vector2(1.12, 1.12)


func _draw() -> void:
	# contact shadow: the figure stands on the pavement instead of floating over it
	var high := clampf(ground / 300.0, 0.0, 1.0)   # the higher he is, the smaller and fainter it gets
	draw_set_transform(Vector2(0.0, ground - 4.0), 0.0, Vector2(1.0 + dive * 0.8, 0.16))
	draw_circle(Vector2.ZERO, 0.34 * PPM * (1.0 - high * 0.4), Color(0.0, 0.0, 0.0, 0.55 * (1.0 - high * 0.5)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## dir: -1..1 along the ground (how fast the legs run). aim: vector from the shoulder to the target,
## in the parent's space.
func set_state(dir: float, aim: Vector2, delta: float) -> void:
	var facing := -1.0 if aim.x < 0.0 else 1.0
	scale = Vector2(facing * size, size)
	var want := Vector2(absf(aim.x), aim.y)
	if want.length() < 0.001:
		want = Vector2.RIGHT
	# the gun arm eases onto the target instead of snapping; the kick of a shot is added on top
	_aim_angle = lerp_angle(_aim_angle, want.angle(), 1.0 - exp(-22.0 * delta))
	recoil = move_toward(recoil, 0.0, delta * 1.6)
	_flinch = move_toward(_flinch, 0.0, delta * 2.2)
	_hit_dip = move_toward(_hit_dip, 0.0, delta * 2.5)

	_aim = Vector2.from_angle(_aim_angle - recoil)
	_moving = lerpf(_moving, absf(dir), 1.0 - exp(-9.0 * delta))
	_phase = fposmod(_phase + dir * facing * delta * 2.2, 1.0)   # walking backwards runs the cycle in reverse

	# the coat tail: it hangs, streams back with speed, flies up in a fall, and lags behind every change
	if _have_last and delta > 0.0:
		_vel = _vel.lerp((global_position - _last) / delta, 1.0 - exp(-12.0 * delta))
	_last = global_position
	_have_last = true
	_clock += delta
	var forward := _vel.x * facing
	# kept modest: the upper coat is part of the torso drawing, and a tail that swings far breaks away from it
	# straight down at rest and in a walk; it only streams back once he is really moving
	var hang := Vector2(-clampf((absf(forward) - 150.0) / 400.0, 0.0, 1.3) * signf(forward) * 0.11, 0.5 - clampf(_vel.y / 1200.0, -0.5, 1.0) * 0.15)
	hang.x += sin(_clock * 9.0) * 0.025 * _moving + sin(_clock * 1.6) * 0.012   # flutter in the run, a breath of wind at rest
	_tail_dir = _tail_dir.lerp(hang, 1.0 - exp(-7.0 * delta))
	_pose()
	queue_redraw()


## One foot's path through a running stride, p = 0..1: carried back along the ground for the first
## half, then lifted and swung forward in an eased arc.
func _foot(p: float) -> Vector2:
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
	foot_a = foot_a.lerp(Vector2(0.2, 0.0), duck * (1.0 - t))    # standing crouch: one foot forward, one back
	foot_b = foot_b.lerp(Vector2(-0.22, 0.0), duck * (1.0 - t))
	# in a jump the knees come up; in a dive the legs trail straight; in a slide they lead
	foot_a = foot_a.lerp(Vector2(0.16, -0.36), air).lerp(Vector2(0.07, 0.0), dive).lerp(Vector2(0.74 * slide_side, -0.03), slide)
	foot_b = foot_b.lerp(Vector2(-0.14, -0.2), air).lerp(Vector2(-0.09, -0.05), dive).lerp(Vector2(0.3 * slide_side, 0.0), slide)
	var drop := minf(0.62, crouch * 0.3 + slide * 0.5 + duck * 0.58 + _hit_dip * 0.16)   # how far the hips sink
	var hip := Vector2(-0.1 * slide * slide_side, -(l1 + l2) * 0.985 - ankle + drop + lerpf(0.01, 0.04 + 0.035 * cos(th * 2.0), t))
	var legs_lean := dive * 1.35 * dive_side + roll        # the legs follow a dive or a tumble
	var lean := legs_lean - slide * 0.75 * slide_side + crouch * 0.25 + duck * 0.32   # the torso also lies back in a slide, bows in a crouch
	if not _dead:
		lean += t * 0.13 * (1.0 - dive)                 # leaning into a run
		lean -= recoil * 0.22                          # each shot knocks him back a touch
		lean -= _flinch * (0.6 if _hit_part == "torso" else 0.35)   # and a bullet much more: rocked back
		lean -= sin(_flinch * PI) * 0.12 * _hit_dip              # a leg hit folds him forward a moment
		lean += clampf(_aim.angle(), -0.9, 0.6) * 0.08   # the body follows the gun up or down a little
	var breath := sin(_clock * 1.7) * 0.006 * (1.0 - t) * (0.0 if _dead else 1.0)   # breathing, standing still
	var neck := hip + Vector2(lerpf(0.03, 0.15, t), -float(_len["torso"]) - breath).rotated(lean)
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
		near_target = near_target.lerp(shoulder + Vector2(0.24, 0.24), rl)
	var kn := _ik(shoulder, near_target, ua, fa, 1.0)
	var hand: Vector2 = kn[1]
	var gun_scale: float = float(gd["len"]) / float((_gun.texture as Texture2D).get_width())   # metres per picture pixel

	# far arm: with a long gun it holds the fore grip; with two pistols it aims the second one just
	# under the first; with one gun it supports the aim standing and swings against the legs running
	var far_target := (shoulder + _aim * 0.5 + Vector2(0.02, 0.06)).lerp(hip + Vector2(0.25 * cos(th), 0.05), t)
	if long_gun:
		var tex_size := Vector2((_gun.texture as Texture2D).get_size())
		far_target = hand + ((tex_size * ((gd["fore"] as Vector2) - (gd["grip"] as Vector2))) * gun_scale).rotated(_aim.angle())
	elif weapon == "pistols" and not _dead:
		far_target = far_shoulder + _aim * reach + Vector2(0.0, 0.07)
	if _dead:   # dead weight: the arm lies almost straight along the thrown direction
		far_target = far_shoulder + Vector2.from_angle(_aim.angle() + 0.25) * (ua + fa) * 0.96
	if rl > 0.0:   # the other hand works the gun
		far_target = far_target.lerp(hand + Vector2(0.06, 0.03 + 0.03 * sin(reload * 40.0)), rl)
	var k := _ik(far_shoulder, far_target, ua, fa, 1.0)
	_place("uarm_b", "uarm", far_shoulder, k[0])
	_place("farm_b", "farm", k[0], k[1])
	_gun2.position = k[1] * PPM
	_gun2.rotation = _aim.angle() + 0.04

	k = _ik(hip, hip + (foot_b - Vector2(0.0, ankle) - hip).rotated(legs_lean), l1, l2, -1.0)
	_place("thigh_b", "thigh", hip, k[0])
	_place("shin_b", "shin", k[0], k[1])
	var leg_b := [hip, k[0], k[1]]
	k = _ik(hip, hip + (foot_a - Vector2(0.0, ankle) - hip).rotated(legs_lean), l1, l2, -1.0)
	_place("thigh_f", "thigh", hip, k[0])
	_place("shin_f", "shin", k[0], k[1])
	var leg_f := [hip, k[0], k[1]]
	if _legs.has("f"):
		_bend_leg(_legs["f"], leg_f, _leg_shadows.get("f"))
		_bend_leg(_legs["b"], leg_b, _leg_shadows.get("b"))

	if _spr.has("skirt"):   # hangs from the belt, sways with speed, tips with the body
		# in a slide it lies along the legs; crouched it falls back behind the heels; never through the pavement
		var skirt_lean := lean - slide * 0.8 * slide_side + duck * 0.45
		var hem := belt + (_tail_dir.normalized() * float(_len["skirt"])).rotated(skirt_lean)
		_place("skirt", "skirt", belt, hem)
		if _skirt_mesh:
			_bend_skirt(belt, lean, hem, leg_f, leg_b)
	_place("torso", "torso", hip, neck)
	for c in _collars:
		c.position = _spr["torso"].position
		c.rotation = _spr["torso"].rotation
	# the head tips less than the body, and turns a little after the aim: he looks where he shoots
	var look := (lean - roll) * 0.5 + roll
	if not _dead:
		look += clampf(_aim.angle(), -0.9, 0.7) * 0.4 - recoil * 0.3
		if reload > 0.0:   # eyes on the gun in his hands
			look = lerpf(look, 0.35, smoothstep(0.0, 0.14, reload) * (1.0 - smoothstep(0.86, 1.0, reload)))
	_place("head", "head", head_base, head_base + Vector2(0.02, -0.3).rotated(look))

	_place("uarm_f", "uarm", shoulder, kn[0])
	_place("farm_f", "farm", kn[0], kn[1])
	_gun.position = hand * PPM
	_gun.rotation = _aim.angle()
	if rl > 0.0:   # muzzle up; near the end a flick of the wrist snaps the cylinder home
		var flick := sin(clampf((reload - 0.78) / 0.1, 0.0, 1.0) * PI) * 0.5
		_gun.rotation = lerp_angle(_aim.angle(), -1.25 + flick, rl)
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
	scale = Vector2((-1.0 if aim.x < 0.0 else 1.0) * size, size)
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
			quads.append(PackedInt32Array([i, i + 1, i + SKIRT_COLS + 2, i + SKIRT_COLS + 1]))
	m.polygons = quads
	m.light_mask = MASK_FIGURE
	return m


## Bend the coat: from the belt it follows the hips, lower down it swings out to where the tail of
## the coat is blown (the hem), and in a stride its front and back edges are carried by the legs so
## it parts round them instead of sweeping through them like a board.
func _bend_skirt(belt: Vector2, lean: float, hem: Vector2, leg_f: Array, leg_b: Array) -> void:
	var p: Dictionary = cfg["parts"]["skirt"]
	var ppm := float(p["ppm"])
	var tex_w := float((_skirt_mesh.texture as Texture2D).get_width())
	var ax := float((p["a"] as Vector2).x)
	var length := float(_len["skirt"])
	var top_dir := Vector2(0.0, 1.0).rotated(lean)
	var end_dir := (hem - belt).normalized()
	var open := clampf(_moving * 0.8 + air * 0.6 + slide * 0.3, 0.0, 1.0) * (0.0 if _dead else 1.0)
	var pts := PackedVector2Array()
	var center := belt
	for r in SKIRT_ROWS + 1:
		var v := float(r) / SKIRT_ROWS
		var d := top_dir.slerp(end_dir, pow(v, 1.4))
		if r > 0:
			center += d * length / SKIRT_ROWS
		var n := Vector2(d.y, -d.x)   # across the coat, front edge on the + side
		var flare := 1.0 + 0.12 * v
		var at_f := _along_leg(leg_f, v)
		var at_b := _along_leg(leg_b, v)
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
			pts.append(q * PPM)
	_skirt_mesh.polygon = pts
	if _skirt_shadow:
		_skirt_shadow.polygon = pts


## A point down a leg (hip, knee, ankle) at fraction v of the coat's length.
func _along_leg(leg: Array, v: float) -> Vector2:
	var u := v * 1.6
	if u < 1.0:
		return (leg[0] as Vector2).lerp(leg[1], u)
	return (leg[1] as Vector2).lerp(leg[2], minf(1.0, u - 1.0))


## A whole straight leg drawing as a strip of rows, bent along hip, knee and ankle each frame.
func _make_leg_mesh() -> Polygon2D:
	var m := Polygon2D.new()
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
			quads.append(PackedInt32Array([i, i + 1, i + 4, i + 3]))
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
			pts.append((at - n * across) * PPM)
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
func set_weapon(name: String) -> void:
	var key := "pistol" if name == "pistols" else name
	if not GUNS.has(key):
		key = "revolver"
	weapon = name
	var gd: Dictionary = GUNS[key]
	for g in [_gun, _gun2]:
		var tex: Texture2D = load(gd["tex"])
		g.texture = tex
		g.offset = -Vector2(tex.get_size()) * (gd["grip"] as Vector2)
		g.scale = Vector2.ONE * float(gd["len"]) * PPM / tex.get_width()
	_gun2.visible = name == "pistols"
	if _shadow_spr.has("gun"):
		for k in ["gun", "gun2"]:
			var src: Sprite2D = _gun if k == "gun" else _gun2
			var d: Sprite2D = _shadow_spr[k]
			d.texture = src.texture
			d.offset = src.offset
			d.scale = src.scale
			d.visible = src.visible
	_pose()


## The crown of his hat and the top of his near shoulder, in world coordinates: where rain lands on him.
func head_top() -> Vector2:
	var h: Sprite2D = _spr["head"]
	return to_global(h.position + Vector2(0.0, -0.28 * PPM).rotated(h.rotation))


func shoulder_top() -> Vector2:
	return to_global((_bones["uarm_f"][0] as Vector2) + Vector2(-0.04 * PPM, -0.03 * PPM))


## The end of the barrel, in world coordinates. With two pistols the hands take turns.
func muzzle() -> Vector2:
	var g := _gun2 if (_left_shot and _gun2.visible) else _gun
	var key := "pistol" if weapon == "pistols" else weapon
	var gd: Dictionary = GUNS.get(key, GUNS["revolver"])
	var size_px := Vector2(g.texture.get_size())
	var local := (size_px * (gd["muzzle"] as Vector2) + g.offset) * g.scale
	return to_global(g.position + local.rotated(g.rotation))


## After a shot with two pistols, the other hand fires next.
func next_hand() -> void:
	if weapon == "pistols":
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
