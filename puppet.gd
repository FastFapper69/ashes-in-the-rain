extends Node2D
# A character built from drawn parts. No stored animation: every frame the code decides where the
# feet, hips and hands are, solves the knees and elbows, and lays each drawn part between its two joints.

const PPM := 200.0   # world pixels per metre
const MASK_FIGURE := 1 | 4   # lit by the street lights (1) and by the figure's own back light (4)

# Back to front. The far arm and leg reuse the near ones' drawings, darkened.
const ORDER := [
	["uarm_b", "uarm", true], ["farm_b", "farm", true],
	["thigh_b", "thigh", true], ["shin_b", "shin", true],
	["thigh_f", "thigh", false], ["shin_f", "shin", false],
	["skirt", "skirt", false],   # the coat below the belt hangs over the legs
	["torso", "torso", false], ["head", "head", false], ["collar_front", "", false],
	["gun", "", false],
	["uarm_f", "uarm", false], ["collar_back", "", false], ["farm_f", "farm", false],
]

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
uniform float width = 1.6;
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
	COLOR = vec4(col, max(c.a, m * 0.9) * fade);
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
var roll := 0.0      # extra turn of the whole body, radians: a tumble out of a dive
var ground := 0.0    # where the pavement is below the figure's origin, in pixels (0 when standing on it)
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
	mat.set_shader_parameter("line", Vector3(0.92 * night.r, 0.9 * night.g, 0.87 * night.b))
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
		if row[0] == "gun":
			_gun = Sprite2D.new()
			_gun.texture = load(cfg["gun"])
			_gun.flip_h = cfg["gun_flip"]
			_gun.scale = Vector2.ONE * 0.0733
			_body.add_child(_gun)
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
		s.texture = _tex(String(cfg["dir"]) + part)
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
	var g := Sprite2D.new()
	g.texture = _gun.texture
	g.flip_h = _gun.flip_h
	g.scale = _gun.scale
	g.modulate = Color(0.0, 0.0, 0.0)
	_shadow.add_child(g)
	_shadow_spr["gun"] = g


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
	scale.x = facing
	var want := Vector2(absf(aim.x), aim.y)
	if want.length() < 0.001:
		want = Vector2.RIGHT
	# the gun arm eases onto the target instead of snapping; the kick of a shot is added on top
	_aim_angle = lerp_angle(_aim_angle, want.angle(), 1.0 - exp(-22.0 * delta))
	recoil = move_toward(recoil, 0.0, delta * 1.6)
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
	var drop := minf(0.62, crouch * 0.3 + slide * 0.5 + duck * 0.58)   # how far the hips sink
	var hip := Vector2(-0.1 * slide * slide_side, -(l1 + l2) * 0.985 - ankle + drop + lerpf(0.01, 0.04 + 0.035 * cos(th * 2.0), t))
	var legs_lean := dive * 1.35 * dive_side + roll        # the legs follow a dive or a tumble
	var lean := legs_lean - slide * 0.75 * slide_side + crouch * 0.25 + duck * 0.32   # the torso also lies back in a slide, bows in a crouch
	var neck := hip + Vector2(lerpf(0.03, 0.15, t), -float(_len["torso"])).rotated(lean)
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

	# far arm: supports the aim when standing, swings against the far leg when running
	var far_target := (shoulder + _aim * 0.5 + Vector2(0.02, 0.06)).lerp(hip + Vector2(0.25 * cos(th), 0.05), t)
	var k := _ik(far_shoulder, far_target, ua, fa, 1.0)
	_place("uarm_b", "uarm", far_shoulder, k[0])
	_place("farm_b", "farm", k[0], k[1])

	k = _ik(hip, hip + (foot_b - Vector2(0.0, ankle) - hip).rotated(legs_lean), l1, l2, -1.0)
	_place("thigh_b", "thigh", hip, k[0])
	_place("shin_b", "shin", k[0], k[1])
	k = _ik(hip, hip + (foot_a - Vector2(0.0, ankle) - hip).rotated(legs_lean), l1, l2, -1.0)
	_place("thigh_f", "thigh", hip, k[0])
	_place("shin_f", "shin", k[0], k[1])

	if _spr.has("skirt"):   # hangs from the belt, sways with speed, tips with the body
		# in a slide it lies along the legs; crouched it falls back behind the heels; never through the pavement
		var skirt_lean := lean - slide * 0.8 * slide_side + duck * 0.45
		_place("skirt", "skirt", belt, belt + (_tail_dir.normalized() * float(_len["skirt"])).rotated(skirt_lean))
	_place("torso", "torso", hip, neck)
	for c in _collars:
		c.position = _spr["torso"].position
		c.rotation = _spr["torso"].rotation
	var look := (lean - roll) * 0.5 + roll   # the head tips less than the body: he keeps his eyes on the target
	_place("head", "head", head_base, head_base + Vector2(0.02, -0.3).rotated(look))

	# near arm: always on the target, the gun in its hand
	k = _ik(shoulder, shoulder + _aim * 0.55, ua, fa, 1.0)
	_place("uarm_f", "uarm", shoulder, k[0])
	_place("farm_f", "farm", k[0], k[1])
	var hand: Vector2 = k[1]
	_gun.position = (hand + _aim * 0.093) * PPM + Vector2(0.0, -5.0)
	_gun.rotation = _aim.angle()
	if _shadow:
		for key in _shadow_spr:
			var src: Node2D = _gun if key == "gun" else _spr[key]
			var d: Node2D = _shadow_spr[key]
			d.position = src.position
			d.rotation = src.rotation


## The end of the barrel, in world coordinates.
func muzzle() -> Vector2:
	var up := Vector2(_aim.y, -_aim.x)
	return to_global(_gun.position + _aim * 38.0 + up * 9.0)


## Where the gun points, in world coordinates.
func aim_dir() -> Vector2:
	return Vector2(_aim.x * scale.x, _aim.y)


func _place(sprite: String, part: String, a: Vector2, b: Vector2) -> void:
	var s: Sprite2D = _spr[sprite]
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
