extends Node2D
# Comic-book gunfire: muzzle flashes, bullets with white ink trails, lettered sound effects,
# blood, casings and smoke. Everything here is drawn unshaded and lifted by `night` (the inverse
# of the scene's darkness), so the effects keep the colours they were drawn in.

const FLASHES := ["res://art/fx/flash1.png", "res://art/fx/flash2.png", "res://art/fx/flash4.png"]
const BLOODS := ["res://art/fx/blood1.png", "res://art/fx/blood2.png", "res://art/fx/blood3.png", "res://art/fx/blood4.png"]
const PUFFS := ["res://art/fx/puff1.png", "res://art/fx/puff2.png", "res://art/fx/puff3.png"]
const WORDS := ["res://art/fx/word_blam.png", "res://art/fx/word_bang.png", "res://art/fx/word_krakoom.png", "res://art/fx/word_clink.png"]
const TRAIL_LENGTH := 620.0
const CLASH_RADIUS := 34.0   # how close two bullets must pass to count as a hit; generous on purpose
const GROUND_Y := -48.0   # bullets stop at the pavement

var night := Color.WHITE        # set by main.gd
var clash := Callable()         # func(at: Vector2), called when two opposing bullets meet
var hit_test := Callable()      # func(pos: Vector2, from_player: bool) -> bool, true when the bullet hit someone

var _unshaded: CanvasItemMaterial
var _bullets: Array = []
var _cache := {}
var _swoosh: Array[Line2D] = []
var _stains: Array[Sprite2D] = []
const MAX_STAINS := 60
var _swoosh_pts: Array = []
var _clock := 0.0
var slow := 0.0   # 0..1, set by main.gd: in slowed time the bullets drag thick smoke trails
var _casings: Array = []


func _ready() -> void:
	z_index = 6
	_unshaded = CanvasItemMaterial.new()
	_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	# read every drawing now: loading one in the middle of a fight makes the game stutter
	for path in FLASHES + BLOODS + PUFFS + WORDS + ["res://art/fx/spark1.png", "res://art/fx/casing1.png", "res://art/light_blob.png"]:
		_cache[path] = load(path)


func _sprite(path: String, at: Vector2, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _cache[path] if _cache.has(path) else load(path)
	s.position = at
	s.scale = Vector2.ONE * size
	s.material = _unshaded
	s.modulate = night
	add_child(s)
	return s


func _fade_out(node: CanvasItem, hold: float, fade: float) -> void:
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(node, "modulate:a", 0.0, fade)
	tw.tween_callback(node.queue_free)


## The flash at the barrel, a burst of light on everything near, and a puff of smoke.
func muzzle(at: Vector2, dir: Vector2) -> void:
	var s := _sprite(FLASHES.pick_random(), at, 0.34)
	s.centered = false   # the drawings fire to the right from their left edge
	s.offset = Vector2(-30.0, -s.texture.get_height() * 0.5)
	s.rotation = dir.angle()
	s.scale = Vector2(0.2, 0.34)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2(0.5, 0.5), 0.04)
	tw.tween_interval(0.05)
	tw.tween_callback(s.queue_free)

	var l := PointLight2D.new()
	l.texture = _cache["res://art/light_blob.png"]
	l.texture_scale = 5.0
	l.position = at
	l.color = Color(1.0, 0.8, 0.55)
	l.energy = 2.2
	l.height = 60.0
	l.range_item_cull_mask = 1 | 4
	add_child(l)
	var tl := create_tween()
	tl.tween_property(l, "energy", 0.0, 0.12)
	tl.tween_callback(l.queue_free)

	var p := _sprite(PUFFS.pick_random(), at + dir * 40.0, 0.25)
	p.modulate = Color(night.r, night.g, night.b, 0.6)
	p.rotation = randf() * TAU
	var tp := create_tween()
	tp.set_parallel(true)
	tp.tween_property(p, "position", p.position + Vector2(dir.x * 30.0, -70.0), 0.7)
	tp.tween_property(p, "scale", Vector2.ONE * 0.5, 0.7)
	tp.tween_property(p, "modulate:a", 0.0, 0.7)
	tp.chain().tween_callback(p.queue_free)


## A lettered sound effect that pops in, hangs for a moment and fades.
func word(path: String, at: Vector2, size: float, along := Vector2.ZERO) -> void:
	var s := _sprite(path, at, size * 0.4)
	s.z_index = 9
	s.rotation = randf_range(-0.1, 0.1)
	if along != Vector2.ZERO:   # tilted the way the shot went, but never upside down
		s.rotation += clampf(Vector2(absf(along.x), along.y * signf(along.x)).angle(), -0.45, 0.45) - 0.12 * signf(along.x)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * size, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(s.queue_free)


## A brush stroke that follows the detective through a dive, a roll or a slide: black ink with an
## off-white stroke inside it, gone a third of a second after it was laid down.
func trail(active: bool, at: Vector2) -> void:
	if _swoosh.is_empty():
		for spec in [[46.0, Color(0.0, 0.0, 0.0)], [28.0, Color(0.92, 0.9, 0.87)]]:
			var line := Line2D.new()
			line.width = spec[0]
			var taper := Curve.new()
			taper.add_point(Vector2(0.0, 0.0))
			taper.add_point(Vector2(0.75, 1.0))
			taper.add_point(Vector2(1.0, 0.35))
			line.width_curve = taper
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.default_color = Color(spec[1].r * night.r, spec[1].g * night.g, spec[1].b * night.b, 0.85)
			line.material = _unshaded
			line.z_index = -7   # behind the figures
			add_child(line)
			_swoosh.append(line)
	_clock += get_process_delta_time() / Engine.time_scale
	if active:
		_swoosh_pts.append([at, _clock])
	while not _swoosh_pts.is_empty() and _clock - float(_swoosh_pts[0][1]) > 0.3:
		_swoosh_pts.remove_at(0)
	var pts := PackedVector2Array()
	for p in _swoosh_pts:
		pts.append(p[0])
	for line in _swoosh:
		line.points = pts if pts.size() > 1 else PackedVector2Array()


func shoot(from: Vector2, velocity: Vector2, from_player: bool) -> void:
	var line := Line2D.new()
	line.width = 12.0
	var taper := Curve.new()   # thin at the tail, full at the bullet
	taper.add_point(Vector2(0.0, 0.0))
	taper.add_point(Vector2(1.0, 1.0))
	line.width_curve = taper
	line.default_color = night
	line.material = _unshaded
	line.add_point(from)
	add_child(line)
	_bullets.append({"pos": from, "vel": velocity, "line": line, "player": from_player, "life": 0.0})


## The detective's bullets knock the mobsters' bullets out of the air. Both are fast, so the test
## is on the stretch each one covered this frame, not just on where they ended up.
func _clashes() -> void:
	var a := _bullets.size() - 1
	while a >= 0:
		var mine: Dictionary = _bullets[a]
		if mine["player"] and mine.has("prev"):
			for e in range(_bullets.size()):
				var theirs: Dictionary = _bullets[e]
				if theirs["player"] or not theirs.has("prev"):
					continue
				var near := Geometry2D.get_closest_points_between_segments(mine["prev"], mine["pos"], theirs["prev"], theirs["pos"])
				if near[0].distance_to(near[1]) > CLASH_RADIUS:
					continue
				var at: Vector2 = (near[0] + near[1]) * 0.5
				spark(at)
				spark(at + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)))
				_fade_out(mine["line"], 0.0, 0.2)
				_fade_out(theirs["line"], 0.0, 0.2)
				_bullets.remove_at(maxi(a, e))
				_bullets.remove_at(mini(a, e))
				if clash.is_valid():
					clash.call(at)
				a = mini(a, _bullets.size())
				break
		a -= 1


## A hit: a crimson splash over a black ink shadow, with drops flung out the far side.
func blood(at: Vector2, dir: Vector2) -> void:
	var path: String = BLOODS.pick_random()
	var turn := randf() * TAU
	for layer in 2:
		var s := _sprite(path, at + dir * 20.0 + (Vector2(7.0, 7.0) if layer == 0 else Vector2.ZERO), 0.1)
		s.rotation = turn
		if layer == 0:
			s.modulate = Color(0.0, 0.0, 0.0, 0.9)
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2.ONE * (0.34 if layer == 0 else 0.3), 0.08)
		tw.tween_interval(0.14)
		tw.tween_property(s, "modulate:a", 0.0, 0.25)
		tw.tween_callback(s.queue_free)
	_stain(at, dir)
	for i in 6:
		var d := _sprite(BLOODS.pick_random(), at, randf_range(0.03, 0.07))
		d.rotation = randf() * TAU
		var fly := Vector2(dir.x * randf_range(60.0, 190.0), randf_range(-120.0, 40.0))
		var td := create_tween()
		td.set_parallel(true)
		td.tween_property(d, "position", at + fly + Vector2(0.0, 70.0), 0.4).set_ease(Tween.EASE_OUT)
		td.tween_property(d, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
		td.chain().tween_callback(d.queue_free)


## Blood thrown onto the wall behind whoever was hit. It stays for the rest of the fight; the
## oldest stains go once there are too many.
func _stain(at: Vector2, dir: Vector2) -> void:
	var s := _sprite(BLOODS.pick_random(), at + Vector2(dir.x * randf_range(50.0, 150.0), randf_range(-60.0, 30.0)), 0.05)
	s.z_index = -15   # with this node at 6: just over the wall, behind every figure and prop
	s.rotation = randf() * TAU
	s.modulate = Color(0.54 * night.r, 0.11 * night.g, 0.08 * night.b, 0.0)
	var size := randf_range(0.2, 0.32)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(size, size * randf_range(0.8, 1.1)), 0.09)
	tw.tween_property(s, "modulate:a", 0.9, 0.09)
	_stains.append(s)
	if _stains.size() > MAX_STAINS:
		_stains.pop_front().queue_free()


func spark(at: Vector2) -> void:
	var s := _sprite("res://art/fx/spark1.png", at, 0.2)
	s.rotation = randf() * TAU
	_fade_out(s, 0.05, 0.08)


func casing(at: Vector2, side: float) -> void:
	var s := _sprite("res://art/fx/casing1.png", at, 0.07)
	_casings.append({"node": s, "vel": Vector2(-side * randf_range(120.0, 220.0), -randf_range(380.0, 520.0)), "spin": randf_range(-14.0, 14.0)})


func _process(delta: float) -> void:
	var i := _bullets.size() - 1
	while i >= 0:
		var b: Dictionary = _bullets[i]
		var pos: Vector2 = b["pos"] + b["vel"] * delta
		b["prev"] = b["pos"]
		b["pos"] = pos
		b["life"] += delta
		var line: Line2D = b["line"]
		line.add_point(pos)
		line.width = lerpf(12.0, 26.0, slow)
		while line.get_point_count() > 2 and line.get_point_position(0).distance_to(pos) > TRAIL_LENGTH:
			line.remove_point(0)
		var done := false
		# A bullet covers 70 px or more a frame, more than a man is wide: test the whole stretch it
		# flew this frame in short steps, or it would pass straight through people and crates.
		var from: Vector2 = b["prev"]
		var steps := maxi(1, ceili(from.distance_to(pos) / 18.0))
		for k in range(1, steps + 1):
			if hit_test.is_valid() and hit_test.call(from.lerp(pos, float(k) / steps), b["player"]):
				done = true
				break
		if done:
			pass
		elif pos.y > GROUND_Y:
			spark(pos)
			done = true
		elif b["life"] > 1.4:
			done = true
		if done:
			_fade_out(line, 0.0, 0.25)
			_bullets.remove_at(i)
		i -= 1

	_clashes()

	var j := _casings.size() - 1
	while j >= 0:
		var c: Dictionary = _casings[j]
		var node: Sprite2D = c["node"]
		var vel: Vector2 = c["vel"]
		vel.y += 1900.0 * delta
		c["vel"] = vel
		node.position += vel * delta
		node.rotation += float(c["spin"]) * delta
		if node.position.y > GROUND_Y + 10.0:
			_fade_out(node, 0.0, 0.3)
			_casings.remove_at(j)
		j -= 1
