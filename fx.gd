extends Node2D
# Comic-book gunfire: muzzle flashes, bullets with white ink trails, lettered sound effects,
# blood, casings and smoke. Everything here is drawn unshaded and lifted by `night` (the inverse
# of the scene's darkness), so the effects keep the colours they were drawn in.

const FLASHES := ["res://art/fx/ink/flash0.png", "res://art/fx/ink/flash1.png", "res://art/fx/ink/flash3.png", "res://art/fx/ink/flash5.png",
		"res://art/fx/ink/flash6.png", "res://art/fx/ink/flash7.png"]   # hand-painted flashes (art_src 150), fired to the right
const BIG_FLASHES := ["res://art/fx/ink/flash1.png", "res://art/fx/ink/flash5.png", "res://art/fx/ink/flash6.png"]   # the long ragged ones, for a shotgun
const SMOKE := ["res://art/fx/ink/smoke0.png", "res://art/fx/ink/smoke1.png", "res://art/fx/ink/smoke2.png", "res://art/fx/ink/smoke3.png",
		"res://art/fx/ink/smoke4.png", "res://art/fx/ink/smoke5.png", "res://art/fx/ink/smoke6.png", "res://art/fx/ink/smoke7.png"]   # one puff, born to gone (art_src 151)
const INK_SPARKS := ["res://art/fx/ink/spark0.png", "res://art/fx/ink/spark1.png", "res://art/fx/ink/spark2.png", "res://art/fx/ink/spark3.png",
		"res://art/fx/ink/spark4.png", "res://art/fx/ink/spark5.png", "res://art/fx/ink/spark6.png", "res://art/fx/ink/spark7.png"]   # art_src 152
const SPEED := ["res://art/fx/ink/speed0.png", "res://art/fx/ink/speed1.png", "res://art/fx/ink/speed2.png", "res://art/fx/ink/speed3.png"]   # art_src 153
const TRACERS := ["res://art/fx/ink/tracer0.png", "res://art/fx/ink/tracer1.png", "res://art/fx/ink/tracer2.png", "res://art/fx/ink/tracer3.png"]
const INK_BLOOD := ["res://art/fx/ink/blood0.png", "res://art/fx/ink/blood1.png", "res://art/fx/ink/blood2.png", "res://art/fx/ink/blood3.png",
		"res://art/fx/ink/blood4.png", "res://art/fx/ink/blood5.png", "res://art/fx/ink/blood6.png", "res://art/fx/ink/blood7.png"]   # art_src 157, blown to the right
const DUST := ["res://art/fx/ink/dust0.png", "res://art/fx/ink/dust1.png", "res://art/fx/ink/dust2.png", "res://art/fx/ink/dust3.png"]
const STAIN_SPRAYS := ["res://art/fx/stain_spray1.png", "res://art/fx/stain_spray2.png"]
const STAIN_DRIPS := ["res://art/fx/stain_drip1.png", "res://art/fx/stain_drip2.png"]
const STAIN_MISTS := ["res://art/fx/stain_mist1.png", "res://art/fx/stain_mist2.png"]
const BLOODS := ["res://art/fx/blood1.png", "res://art/fx/blood2.png", "res://art/fx/blood3.png", "res://art/fx/blood4.png"]
const SPARKS := ["res://art/fx/spark1.png", "res://art/fx/spark2.png"]
const PUFFS := ["res://art/fx/puff1.png", "res://art/fx/puff2.png", "res://art/fx/puff3.png"]
const WORDS := ["res://art/fx/word_blam.png", "res://art/fx/word_bang.png", "res://art/fx/word_krakoom.png", "res://art/fx/word_clink.png",
		"res://art/fx/word_pow.png", "res://art/fx/word_bam.png", "res://art/fx/word_crack.png", "res://art/fx/word_wham.png",
		"res://art/fx/word_click.png", "res://art/fx/word_kachak.png", "res://art/fx/word_smash.png", "res://art/fx/word_crash.png",
		"res://art/fx/word_crash2.png", "res://art/fx/word_thud.png", "res://art/fx/word_zing.png", "res://art/fx/word_rattat.png"]
const TRAIL_LENGTH := 620.0
const CLASH_RADIUS := 34.0   # how close two bullets must pass to count as a hit; generous on purpose
const GROUND_Y := -48.0   # bullets stop at the pavement

var night := Color.WHITE        # set by main.gd
var sound: Node                 # sfx.gd, set by main.gd
var listener: Node2D            # the detective: enemy bullets that pass close to him whistle
var clash := Callable()         # func(at: Vector2), called when two opposing bullets meet
var stain_host := Callable()   # func(pos) -> Node2D: the mask a wall stain at pos is clipped to
var wall_at := Callable()      # func(pos: Vector2) -> bool, false where there is no wall to stain (an alley's mouth)
var hit_test := Callable()      # func(pos: Vector2, from_player: bool) -> bool, true when the bullet hit someone

var _unshaded: CanvasItemMaterial
var _additive: CanvasItemMaterial
var _soft: GradientTexture2D
var _bits: Array = []      # loose particles under gravity, see _bit
var _spots: Array = []   # drops and glass lying on the pavement
const MAX_SPOTS := 50
var pass_test := Callable()     # func(bullet: Dictionary, from: Vector2, to: Vector2): what it flew through this frame (mapfx.gd: sheets)
var hit_vel := Vector2.RIGHT     # the velocity of the bullet being tested in hit_test, for main.gd
var _bullets: Array = []
var _cache := {}
const LowRes = preload("res://lowres.gd")
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
	_additive = CanvasItemMaterial.new()
	_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# read every drawing now: loading one in the middle of a fight makes the game stutter
	for path in TRACERS + INK_BLOOD + FLASHES + SMOKE + INK_SPARKS + SPEED + DUST + BLOODS + PUFFS + WORDS + STAIN_SPRAYS + STAIN_DRIPS + STAIN_MISTS + ["res://art/fx/stain_smear1.png", "res://art/fx/spark1.png", "res://art/fx/spark2.png", "res://art/fx/flash3.png", "res://art/fx/casing1.png", "res://art/light_blob.png"]:
		_cache[path] = LowRes.tex(path, 0.5)   # words and splashes are drawn far bigger than they show


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


## The flash at the barrel, a burst of light on everything near, sparks and a puff of smoke.
## No two are alike: shape, size, how long it hangs and how the light flickers all vary a little,
## and the gun sets the scale (a shotgun roars, a tommy gun stutters small and fast).
func muzzle(at: Vector2, dir: Vector2, kind := "") -> void:
	var big: float = {"shotgun": 1.35, "tommy": 0.78, "heavy": 1.25, "pistol": 0.8}.get(kind, 1.0) * randf_range(0.82, 1.18)
	var s := _sprite((BIG_FLASHES if kind == "shotgun" else FLASHES).pick_random(), at, 0.34)
	s.centered = false   # the drawings fire to the right from their left edge
	s.offset = Vector2(-20.0, -s.texture.get_height() * 0.5)
	s.rotation = dir.angle() + randf_range(-0.1, 0.1)
	s.flip_v = randf() < 0.5
	s.scale = Vector2(0.2, 0.3) * big
	var peak := Vector2(randf_range(0.42, 0.6), randf_range(0.4, 0.55)) * big
	var tw := create_tween()
	tw.tween_property(s, "scale", peak, 0.035)
	tw.tween_interval(randf_range(0.02, 0.07))
	tw.tween_property(s, "scale", peak * Vector2(0.6, 0.3), 0.03)
	tw.tween_callback(s.queue_free)
	if randf() < 0.45:   # now and then the gas also bursts out sideways at the cylinder gap
		var side := _sprite(FLASHES.pick_random(), at - dir * 18.0, 0.1)
		side.centered = false
		side.offset = Vector2(-30.0, -side.texture.get_height() * 0.5)
		side.rotation = dir.angle() + (1.25 if randf() < 0.5 else -1.25) + randf_range(-0.2, 0.2)
		side.scale = Vector2(0.12, 0.14) * big
		_fade_out(side, 0.03, 0.04)
	var core := _sprite("res://art/light_blob.png", at, 0.09 * big)   # the white-hot point at the muzzle
	core.material = _additive
	core.modulate = night * Color(1.0, 0.92, 0.75)
	_fade_out(core, 0.02, 0.06)

	var l := PointLight2D.new()
	l.texture = _cache["res://art/light_blob.png"]
	l.texture_scale = randf_range(4.2, 6.2) * big
	l.position = at + dir * 30.0
	l.color = Color(1.0, randf_range(0.72, 0.86), randf_range(0.45, 0.62))
	l.energy = randf_range(1.7, 2.8) * big
	l.height = 60.0
	l.range_item_cull_mask = 1 | 4
	add_child(l)
	var tl := create_tween()
	if randf() < 0.35:   # a stutter: the light dips and catches once more
		tl.tween_property(l, "energy", l.energy * 0.25, 0.03)
		tl.tween_property(l, "energy", l.energy * 0.8, 0.02)
	tl.tween_property(l, "energy", 0.0, randf_range(0.08, 0.15))
	tl.tween_callback(l.queue_free)

	for k in randi_range(2, 5):   # burning grains of powder flung out with the shot
		var v := dir.rotated(randf_range(-0.35, 0.35)) * randf_range(700.0, 1500.0)
		_bit(SPARKS.pick_random(), at + dir * 20.0, v, randf_range(0.04, 0.07), randf_range(0.08, 0.2), 900.0, true, Color(1.0, 0.75, 0.4))

	smoke(at + dir * randf_range(30.0, 55.0), Vector2(dir.x * randf_range(40.0, 90.0), -randf_range(60.0, 120.0)), 0.3 * big, randf_range(0.7, 1.1))


## A loose particle flying under gravity: a powder spark, a drop of blood, a sliver of glass.
## stretch: drawn long along its flight, like a streak caught by the shutter.
func _bit(path: String, at: Vector2, vel: Vector2, size: float, life: float, gravity: float, stretch: bool, tint: Color, land := "") -> Sprite2D:
	var n := _sprite(path, at, size)
	n.modulate = Color(night.r * tint.r, night.g * tint.g, night.b * tint.b, tint.a)
	if path == "res://art/light_blob.png" or path in SPARKS:
		n.material = _additive
	_bits.append({"node": n, "vel": vel, "g": gravity, "life": 0.0, "max": life, "size": size, "stretch": stretch, "land": land, "spin": randf_range(-12.0, 12.0)})
	return n


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


func shoot(from: Vector2, velocity: Vector2, from_player: bool, life := 1.4) -> void:
	# Three layers: a soft glow along the path, a hot streak that cools from white at the bullet to
	# smoke at the tail, and the slug itself, a bright bead. His shots burn warm; theirs a harder red.
	var hot := Color(1.0, 0.95, 0.8) if from_player else Color(1.0, 0.72, 0.6)
	var mid := Color(1.0, 0.62, 0.25) if from_player else Color(0.95, 0.25, 0.15)
	if _soft == null:   # cross-section of a streak: bright along the middle, nothing at the edges
		var sg := Gradient.new()
		sg.set_color(0, Color(1, 1, 1, 0))
		sg.set_color(1, Color(1, 1, 1, 0))
		sg.add_point(0.5, Color(1, 1, 1, 1))
		sg.add_point(0.3, Color(1, 1, 1, 0.25))
		sg.add_point(0.7, Color(1, 1, 1, 0.25))
		_soft = GradientTexture2D.new()
		_soft.gradient = sg
		_soft.width = 4
		_soft.height = 32
		_soft.fill_from = Vector2(0, 0)
		_soft.fill_to = Vector2(0, 1)
	var glow := Line2D.new()
	glow.width = 30.0
	glow.texture = _soft
	glow.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	var gg := Gradient.new()
	gg.set_color(0, Color(mid, 0.0))
	gg.set_color(1, Color(mid, 0.5))
	glow.gradient = gg
	glow.material = _additive
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.add_point(from)
	add_child(glow)
	var line := Line2D.new()
	line.width = 7.0
	var taper := Curve.new()   # thin at the tail, full at the bullet
	taper.add_point(Vector2(0.0, 0.15))
	taper.add_point(Vector2(1.0, 1.0))
	line.width_curve = taper
	var g := Gradient.new()   # smoke, then the heat, then white at the head
	g.set_color(0, Color(0.55, 0.55, 0.58, 0.0))
	g.add_point(0.55, Color(mid * night, 0.55))
	g.set_color(g.get_point_count() - 1, Color(hot, 1.0))
	line.gradient = g
	line.material = _unshaded
	line.texture = _soft
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(from)
	add_child(line)
	var head := Sprite2D.new()   # the slug and the heat behind it, painted (art_src 158)
	head.texture = _cache[TRACERS[randi() % TRACERS.size()]]
	head.centered = false
	head.offset = Vector2(-head.texture.get_width(), -head.texture.get_height() * 0.5)
	head.material = _additive
	head.modulate = hot
	head.scale = Vector2(0.38, 0.22)
	head.rotation = velocity.angle()
	head.position = from
	add_child(head)
	_bullets.append({"pos": from, "vel": velocity, "line": line, "glow": glow, "head": head, "player": from_player, "life": 0.0, "max": life, "wake": 0.0})


## The air a bullet tore through, seen in slowed time: a ring of disturbed air left hanging behind it.
func _wake(at: Vector2, dir: Vector2) -> void:
	var w := Sprite2D.new()
	w.texture = load("res://art/light_blob.png")
	w.position = at
	w.rotation = dir.angle()
	w.scale = Vector2(0.05, 0.08)
	w.modulate = Color(0.85, 0.87, 0.9, 0.22) * Color(night, 1.0)
	w.z_index = -1
	add_child(w)
	var tw := w.create_tween().set_parallel()
	tw.tween_property(w, "scale", Vector2(0.14, 0.32), 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(w.queue_free)


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
				for bb in [mine, theirs]:
					_fade_out(bb["line"], 0.0, 0.2)
					_fade_out(bb["glow"], 0.0, 0.1)
					_fade_out(bb["head"], 0.0, 0.05)
				_bullets.remove_at(maxi(a, e))
				_bullets.remove_at(mini(a, e))
				if clash.is_valid():
					clash.call(at)
				a = mini(a, _bullets.size())
				break
		a -= 1


## A hit: a burst of red mist, a splash over a black ink shadow, and a spray of drops flung out
## the far side that streak, fall and spatter the pavement. A few drops spit back towards the gun.
## dir: the way the bullet was going. heavy: a head shot or a kill, more of everything.
func blood(at: Vector2, dir: Vector2, heavy := false) -> void:
	dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var more := 1.6 if heavy else 1.0
	var mist := _sprite(STAIN_MISTS.pick_random(), at + dir * 30.0, 0.08)   # the red cloud the shot blows out
	mist.rotation = dir.angle() + randf_range(-0.3, 0.3)
	mist.flip_h = dir.x < 0.0
	mist.modulate = Color(0.6 * night.r, 0.08 * night.g, 0.06 * night.b, 0.75)
	var tm := create_tween()
	tm.set_parallel(true)
	tm.tween_property(mist, "scale", Vector2.ONE * randf_range(0.35, 0.5) * more, 0.22).set_ease(Tween.EASE_OUT)
	tm.tween_property(mist, "position", mist.position + dir * 60.0 + Vector2(0.0, 20.0), 0.4)
	tm.tween_property(mist, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tm.chain().tween_callback(mist.queue_free)

	var spray := _sprite(INK_BLOOD.pick_random(), at - dir * 10.0, 0.05)   # the painted burst, thrown out along the shot
	spray.centered = false
	spray.offset = Vector2(-spray.texture.get_width() * 0.08, -spray.texture.get_height() * 0.5)
	spray.rotation = dir.angle() + randf_range(-0.25, 0.25)
	spray.flip_v = randf() < 0.5
	var size := randf_range(0.42, 0.55) * (1.3 if heavy else 1.0)
	var tw := create_tween()
	tw.tween_property(spray, "scale", Vector2.ONE * size, 0.06).set_ease(Tween.EASE_OUT)
	tw.tween_interval(randf_range(0.1, 0.2))
	tw.tween_property(spray, "modulate:a", 0.0, 0.25)
	tw.tween_callback(spray.queue_free)
	_stain(at, dir)
	var red := Color(0.62, 0.07, 0.05)
	for i in int(randi_range(10, 16) * more):   # the spray out of the exit side
		var v := dir.rotated(randf_range(-0.55, 0.55)) * randf_range(260.0, 950.0) + Vector2(0.0, -randf_range(0.0, 320.0))
		_bit(BLOODS.pick_random(), at + dir * 15.0, v, randf_range(0.028, 0.075), randf_range(0.5, 1.0), 2300.0, true, red * randf_range(0.8, 1.15), "blood")
	for i in randi_range(2, 4):   # and a little back the way it came
		var v := (-dir).rotated(randf_range(-0.7, 0.7)) * randf_range(150.0, 420.0) + Vector2(0.0, -randf_range(60.0, 260.0))
		_bit(BLOODS.pick_random(), at, v, randf_range(0.015, 0.03), randf_range(0.4, 0.7), 2300.0, true, red, "blood")


## A street lamp shot out: the glass bursts, sparks rain down from the socket.
func shatter(at: Vector2) -> void:
	var ring := _sprite("res://art/light_blob.png", at, 0.15)
	ring.material = _additive
	ring.modulate = night * Color(1.0, 0.9, 0.7)
	var tr := create_tween()
	tr.set_parallel(true)
	tr.tween_property(ring, "scale", Vector2.ONE * 0.7, 0.12)
	tr.tween_property(ring, "modulate:a", 0.0, 0.14)
	tr.chain().tween_callback(ring.queue_free)
	for i in randi_range(12, 18):   # slivers of glass, turning and catching the light as they fall
		var shard := Polygon2D.new()
		var r := randf_range(7.0, 18.0)
		shard.polygon = PackedVector2Array([Vector2(-r, -r * 0.3), Vector2(r * randf_range(0.6, 1.2), randf_range(-r, -r * 0.2)), Vector2(randf_range(-r * 0.3, r * 0.5), r * randf_range(0.4, 1.0))])
		shard.color = Color(0.85 * night.r, 0.9 * night.g, 0.95 * night.b, randf_range(0.5, 0.95))
		shard.material = _unshaded
		shard.position = at
		add_child(shard)
		var v := Vector2.from_angle(randf_range(-PI, 0.3)) * randf_range(200.0, 720.0)
		_bits.append({"node": shard, "vel": v, "g": 2000.0, "life": 0.0, "max": randf_range(0.8, 1.4), "size": 1.0, "stretch": false, "land": "glass", "spin": randf_range(-16.0, 16.0)})
	for i in randi_range(8, 14):   # sparks from the broken socket, dripping down
		var v := Vector2(randf_range(-260.0, 260.0), randf_range(-280.0, 60.0))
		_bit(SPARKS.pick_random(), at, v, randf_range(0.03, 0.06), randf_range(0.5, 1.1), 1500.0, true, Color(1.0, 0.7, 0.3))


## A stain picture placed so that `origin` (its pixel where the blood came from) sits at `at`,
## pointing along `dir`, a little tilted.
func _stain_sprite(path: String, at: Vector2, origin: Vector2, dir: Vector2) -> Sprite2D:
	var s := _sprite(path, at, 0.05)
	var tex := s.texture
	s.offset = Vector2(tex.get_width() * 0.5 - origin.x, tex.get_height() * 0.5 - origin.y)
	s.flip_h = dir.x < 0.0
	if s.flip_h:
		s.offset.x = -s.offset.x
	s.rotation = randf_range(-0.25, 0.25)
	return s


## Blood thrown onto the wall behind whoever was hit. It stays for the rest of the fight; the
## oldest stains go once there are too many.
func _stain(at: Vector2, dir: Vector2) -> void:
	if wall_at.is_valid() and not wall_at.call(at + dir * 40.0):
		return
	# What a bullet really leaves on a wall behind someone: a fine fan of small droplets, now and
	# then a few of them running. No big splats or smears.
	var s: Sprite2D
	var size := 1.0
	var grow_down := false
	if randf() < 0.75:
		s = _stain_sprite(STAIN_MISTS.pick_random(), at + dir * 10.0, Vector2(50.0, 150.0), dir)
		size = randf_range(0.28, 0.42)
	else:   # a little heavier: a few drops that run
		s = _stain_sprite(STAIN_DRIPS.pick_random(), at + Vector2(dir.x * randf_range(20.0, 60.0), randf_range(-30.0, 0.0)), Vector2(150.0, 95.0), Vector2.RIGHT if randf() < 0.5 else Vector2.LEFT)
		s.rotation = 0.0
		size = randf_range(0.2, 0.3)
		grow_down = true
	s.z_index = -15   # with this node at 6: just over the wall, behind every figure and prop
	var dark := randf_range(0.8, 1.1)
	s.modulate = Color(0.3 * night.r * dark, 0.05 * night.g * dark, 0.045 * night.b * dark, 0.0)   # dark, not paint red
	var tw := create_tween()
	tw.set_parallel(true)
	if grow_down:   # the runs creep down the wall over a second
		s.scale = Vector2(size, size * 0.3)
		tw.tween_property(s, "scale:y", size, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		s.scale = Vector2.ONE * size * 0.3
		tw.tween_property(s, "scale", Vector2(size, size * randf_range(0.85, 1.1)), 0.09)
	tw.tween_property(s, "modulate:a", 0.8, 0.09)
	if stain_host.is_valid():   # clipped to the solid parts of the drawing behind: no blood on the gaps of a railing
		var host = stain_host.call(at)
		if host != null:
			s.reparent(host, true)
			s.z_index = 0
	_stains.append(s)
	if _stains.size() > MAX_STAINS:
		_stains.pop_front().queue_free()


func spark(at: Vector2) -> void:
	var s := _sprite(INK_SPARKS.pick_random(), at, 0.22)
	s.material = _additive
	s.offset = Vector2(0.0, -s.texture.get_height() * 0.38)   # the drawings burst up from a point low in the picture
	s.rotation = randf_range(-0.9, 0.9)
	s.flip_h = randf() < 0.5
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.3, 0.4), 0.06).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.16).set_delay(0.04)
	tw.tween_callback(s.queue_free)


## A puff of smoke that lives its drawn life: the eight painted stages from a dense bright puff to
## torn wisps, drifting with `vel`, over `life` seconds.
func smoke(at: Vector2, vel: Vector2, size: float, life: float, alpha := 0.7) -> void:
	var p := _sprite(SMOKE[0], at, size)
	p.modulate = Color(night.r, night.g, night.b, alpha)
	p.rotation = randf_range(-0.3, 0.3)
	p.flip_h = randf() < 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(p):
			p.texture = _cache[SMOKE[mini(int(t * SMOKE.size()), SMOKE.size() - 1)]], 0.0, 0.999, life)
	tw.tween_property(p, "position", at + vel * life, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(p, "scale", Vector2.ONE * size * 1.5, life)
	tw.chain().tween_callback(p.queue_free)


## An explosion's own drawing: a painted fireball bursting out, sparks thrown wide and a column of
## dark smoke climbing after it.
func blast(at: Vector2) -> void:
	for path in ["res://art/fx/ink/flash2.png", "res://art/fx/ink/flash4.png"]:
		var b := _sprite(path, at, 0.3)
		b.rotation = randf() * TAU
		var tw := create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * randf_range(1.0, 1.25), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		tw.tween_property(b, "modulate:a", 0.0, 0.18)
		tw.tween_callback(b.queue_free)
	for k in 5:
		var v := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(900.0, 1900.0)
		_bit(SPARKS.pick_random(), at, v, randf_range(0.06, 0.1), randf_range(0.4, 0.8), 1600.0, true, Color(1.0, 0.7, 0.35))
	for k in 6:
		var d := Vector2(randf_range(-160.0, 160.0), randf_range(-60.0, 40.0))
		var sm_at := at + d
		get_tree().create_timer(0.05 * k).timeout.connect(func() -> void:
			smoke(sm_at, Vector2(d.x * 0.4, -randf_range(180.0, 320.0)), randf_range(0.8, 1.15), randf_range(1.6, 2.4), 0.6))


## Comic speed lines left in the air behind a body flying sideways (`dir` the way it flies).
func speed_lines(at: Vector2, dir: float, size := 0.5) -> void:
	var s := _sprite(SPEED.pick_random(), at, size)
	s.centered = false
	s.flip_h = dir < 0.0   # the drawings trail off to the left: the thick end at the body
	s.offset = Vector2(-s.texture.get_width() if dir > 0.0 else 0.0, -s.texture.get_height() * 0.5)
	s.modulate = Color(night.r, night.g, night.b, 0.55)
	s.z_index = -1
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(s, "scale:x", size * 1.3, 0.22)
	tw.tween_callback(s.queue_free)


## Wet dust and spray kicked up off the pavement where a man lands hard.
func dust(at: Vector2, size := 0.45) -> void:
	var p := _sprite(DUST[0], at, size)
	p.centered = false
	p.offset = Vector2(-p.texture.get_width() * 0.5, -p.texture.get_height() * 0.85)
	p.modulate = Color(night.r, night.g, night.b, 0.75)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(p):
			p.texture = _cache[DUST[mini(int(t * DUST.size()), DUST.size() - 1)]], 0.0, 0.999, 0.5)
	tw.tween_property(p, "scale", Vector2(size * 1.4, size * 1.1), 0.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5).set_delay(0.15)
	tw.chain().tween_callback(p.queue_free)


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
		var glow: Line2D = b["glow"]
		line.add_point(pos)
		glow.add_point(pos)
		line.width = lerpf(10.0, 18.0, slow)
		glow.width = lerpf(30.0, 54.0, slow)
		(b["head"] as Sprite2D).position = pos
		(b["head"] as Sprite2D).scale = Vector2(lerpf(0.2, 0.32, slow), 0.06)
		b["wake"] = float(b["wake"]) + pos.distance_to(b["prev"])
		if slow > 0.3 and float(b["wake"]) > 55.0:   # slowed: the bullet leaves its wake in the air
			b["wake"] = 0.0
			_wake(pos - b["vel"].normalized() * 30.0, b["vel"])
		if not b["player"] and not b.has("whizzed") and listener and pos.distance_to(listener.position + Vector2(0.0, -260.0)) < 260.0:
			b["whizzed"] = true   # a near miss: the bullet whistles past his ear
			if sound:
				sound.play("whiz", -2.0, INF, 0.1)
		while line.get_point_count() > 2 and line.get_point_position(0).distance_to(pos) > TRAIL_LENGTH:
			line.remove_point(0)
		while glow.get_point_count() > 2 and glow.get_point_position(0).distance_to(pos) > TRAIL_LENGTH * 0.6:
			glow.remove_point(0)
		var done := false
		# A bullet covers 70 px or more a frame, more than a man is wide: test the whole stretch it
		# flew this frame in short steps, or it would pass straight through people and crates.
		var from: Vector2 = b["prev"]
		if pass_test.is_valid():
			pass_test.call(b, from, pos)
		var steps := maxi(1, ceili(from.distance_to(pos) / 10.0))
		for k in range(1, steps + 1):
			hit_vel = b["vel"]
			if hit_test.is_valid() and hit_test.call(from.lerp(pos, float(k) / steps), b["player"]):
				done = true
				break
		if done:
			pass
		elif pos.y > GROUND_Y:
			spark(pos)
			done = true
		elif b["life"] > float(b["max"]):
			done = true
		if done:
			_fade_out(line, 0.0, 0.25)
			_fade_out(glow, 0.0, 0.15)
			_fade_out(b["head"], 0.0, 0.05)
			_bullets.remove_at(i)
		i -= 1

	_clashes()

	_fly_bits(delta)
	_fly_debris(delta)

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
			if sound and randf() < 0.7:
				sound.play("casing", -8.0, node.position.x, 0.15)
			_fade_out(node, 0.0, 0.3)
			_casings.remove_at(j)
		j -= 1


func _fly_bits(delta: float) -> void:
	var i := _bits.size() - 1
	while i >= 0:
		var b: Dictionary = _bits[i]
		var n: Node2D = b["node"]
		var vel: Vector2 = b["vel"]
		vel.y += float(b["g"]) * delta
		vel *= 1.0 - 1.2 * delta   # air drag: the fine drops slow first
		b["vel"] = vel
		n.position += vel * delta
		b["life"] += delta
		if b["stretch"]:
			n.rotation = vel.angle()
			var sz: float = b["size"]
			n.scale = Vector2(sz * clampf(1.0 + vel.length() / 260.0, 1.0, 4.5), sz * 0.8)
		else:
			n.rotation += float(b["spin"]) * delta
			if b["land"] == "glass":   # glints as it turns
				n.modulate.a = 0.35 + 0.6 * absf(sin(n.rotation * 2.0))
		var landed: bool = b["land"] != "" and n.position.y > GROUND_Y + 40.0 and vel.y > 0.0
		if landed or float(b["life"]) > float(b["max"]):
			if landed:
				_land(String(b["land"]), n.position, vel)
			if landed or b["land"] != "":
				n.queue_free()
			else:
				_fade_out(n, 0.0, 0.08)
			_bits.remove_at(i)
		i -= 1


## Where a drop or a sliver comes down it stays on the wet stone for a while.
func _land(kind: String, at: Vector2, vel: Vector2) -> void:
	var spot: Node2D
	if kind == "blood":
		var sp := _sprite(BLOODS.pick_random(), Vector2(at.x, GROUND_Y + 40.0 + randf_range(-6.0, 6.0)), 1.0)
		var sz := randf_range(0.03, 0.06)
		sp.scale = Vector2(sz * randf_range(1.6, 2.6), sz * 0.45)   # flattened: it lies on the ground
		sp.rotation = 0.0
		sp.modulate = Color(0.45 * night.r, 0.06 * night.g, 0.05 * night.b, 0.85)
		spot = sp
	else:
		if sound and randf() < 0.5:
			sound.play("casing", -14.0, at.x, 0.3)
		var g := Polygon2D.new()
		var r := randf_range(4.0, 9.0)
		g.polygon = PackedVector2Array([Vector2(-r, 0.0), Vector2(r, -r * 0.3), Vector2(r * 0.4, r * 0.25)])
		g.color = Color(0.7 * night.r, 0.75 * night.g, 0.8 * night.b, 0.6)
		g.material = _unshaded
		g.position = Vector2(at.x, GROUND_Y + 40.0)
		add_child(g)
		spot = g
	spot.z_index = -1
	_spots.append(spot)
	var tw := spot.create_tween()   # bound to the spot: if it is cleared early, its fade goes with it
	tw.tween_interval(randf_range(6.0, 10.0))
	tw.tween_property(spot, "modulate:a", 0.0, 2.0)
	tw.tween_callback(spot.queue_free)
	while _spots.size() > 0 and not is_instance_valid(_spots[0]):   # already faded and gone
		_spots.pop_front()
	if _spots.size() > MAX_SPOTS:
		_spots.pop_front().queue_free()


## A crate shot to pieces: the drawing itself is cut into jagged boards that fly apart from where
## the last bullet went in, tumble, bounce on the ground and lie there a while; thin splinters and
## a puff of dust go with them. floor_y: where the pieces land.
var _debris: Array = []

func break_apart(s: Sprite2D, hit: Vector2, floor_y: float) -> void:
	var tex := s.texture
	var size := tex.get_size()
	var rect := Rect2((-size * 0.5 if s.centered else Vector2.ZERO) + s.offset, size)
	var cols := 4
	var rows := 3
	var pts := []   # a grid of points over the drawing, the inner ones nudged so the cuts run crooked
	for r in rows + 1:
		var row := []
		for c in cols + 1:
			var u := Vector2(float(c) / cols, float(r) / rows)
			if c > 0 and c < cols:
				u.x += randf_range(-0.07, 0.07)
			if r > 0 and r < rows:
				u.y += randf_range(-0.09, 0.09)
			row.append(rect.position + u * rect.size)
		pts.append(row)
	var local_hit := s.to_local(hit)
	for r in rows:
		for c in cols:
			var quad := [pts[r][c], pts[r][c + 1], pts[r + 1][c + 1], pts[r + 1][c]]
			var pieces := [quad]
			if randf() < 0.5:   # some boards split again on the diagonal
				pieces = [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]] if randf() < 0.5 else [[quad[0], quad[1], quad[3]], [quad[1], quad[2], quad[3]]]
			for piece in pieces:
				var mid := Vector2.ZERO
				for v in piece:
					mid += v
				mid /= piece.size()
				var poly := PackedVector2Array()
				var uv := PackedVector2Array()
				for v in piece:
					poly.append(v - mid)
					uv.append(v - rect.position)
				var f := Polygon2D.new()
				f.texture = tex
				f.polygon = poly
				f.uv = uv
				f.modulate = s.modulate.lightened(0.35)   # the raw wood inside shows lighter than the weathered face
				f.light_mask = s.light_mask
				f.z_index = 1
				add_child(f)
				f.global_position = s.to_global(mid)
				f.global_rotation = s.global_rotation
				f.scale = s.global_scale
				var away := (mid - local_hit).normalized()
				var v := Vector2(away.x * randf_range(250.0, 750.0), -randf_range(350.0, 950.0))
				_debris.append({"node": f, "vel": v, "spin": randf_range(-9.0, 9.0), "floor": floor_y - randf_range(0.0, 20.0), "bounces": 0, "rest": 0.0})
	for k in randi_range(10, 16):   # thin splinters
		var sp := Polygon2D.new()
		var l := randf_range(8.0, 22.0)
		sp.polygon = PackedVector2Array([Vector2(-l, -1.5), Vector2(l, -0.5), Vector2(l * 0.8, 2.0), Vector2(-l, 1.5)])
		sp.color = Color(0.3, 0.22, 0.15) * night
		sp.material = _unshaded
		sp.position = s.global_position + Vector2(randf_range(-0.4, 0.4) * rect.size.x * s.global_scale.x, randf_range(-0.4, 0.4) * rect.size.y * s.global_scale.y)
		add_child(sp)
		_debris.append({"node": sp, "vel": Vector2(randf_range(-600.0, 600.0), -randf_range(300.0, 1100.0)), "spin": randf_range(-20.0, 20.0), "floor": floor_y, "bounces": 0, "rest": 0.0})
	for k in 3:   # dust off the broken boards
		smoke(s.global_position + Vector2(randf_range(-60.0, 60.0), randf_range(-20.0, 40.0)), Vector2(randf_range(-60.0, 60.0), -80.0), randf_range(0.45, 0.6), randf_range(0.9, 1.2), 0.5)


func _fly_debris(delta: float) -> void:
	var i := _debris.size() - 1
	while i >= 0:
		var d: Dictionary = _debris[i]
		var n: Node2D = d["node"]
		if d["rest"] > 0.0:   # lying on the ground: wait, then fade
			d["rest"] = float(d["rest"]) - delta
			if d["rest"] <= 0.0:
				_fade_out(n, 0.0, 1.0)
				_debris.remove_at(i)
			i -= 1
			continue
		var v: Vector2 = d["vel"]
		v.y += 2600.0 * delta
		n.position += v * delta
		n.rotation += float(d["spin"]) * delta
		if n.position.y > float(d["floor"]) and v.y > 0.0:
			n.position.y = d["floor"]
			d["bounces"] = int(d["bounces"]) + 1
			if int(d["bounces"]) == 1 and sound and randf() < 0.4:
				sound.play("wood_hit", -14.0, n.position.x, 0.25)
			if int(d["bounces"]) >= 3 or absf(v.y) < 200.0:
				d["rest"] = randf_range(5.0, 8.0)
				n.rotation = snappedf(n.rotation, PI) + randf_range(-0.15, 0.15)   # settles flat
			else:
				v = Vector2(v.x * 0.5, -v.y * 0.32)
				d["spin"] = float(d["spin"]) * 0.5
		d["vel"] = v
		i -= 1


## A chip of wood knocked off a crate by a bullet.
func chip(at: Vector2) -> void:
	var sp := Polygon2D.new()
	var l := randf_range(5.0, 12.0)
	sp.polygon = PackedVector2Array([Vector2(-l, -2.0), Vector2(l, -1.0), Vector2(-l * 0.6, 2.5)])
	sp.color = Color(0.45, 0.34, 0.22) * night
	sp.material = _unshaded
	sp.position = at
	add_child(sp)
	_bits.append({"node": sp, "vel": Vector2(randf_range(-350.0, 350.0), -randf_range(200.0, 600.0)), "g": 2200.0, "life": 0.0, "max": 0.7, "size": 1.0, "stretch": false, "land": "", "spin": randf_range(-20.0, 20.0)})
