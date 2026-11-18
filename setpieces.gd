extends Node2D
## The things that happen to a street while Frank fights along it, so no two stretches play alike:
## a car of reinforcements pulling up hard, the power going out, a searchlight sweeping the yard, a
## warehouse burning, a crate on a crane's chains waiting to be shot down onto whoever stands under it.
## The map lists them (level["events"]); main.gd ticks them and asks them about bullets and light.

const CAR_W := 1000.0
# where the windows burn on a drawing that is set on fire: fractions of the (trimmed) picture
const FIRES := {"shipping": [Vector2(0.11, 0.193), Vector2(0.21, 0.193), Vector2(0.36, 0.193), Vector2(0.165, 0.333),
		Vector2(0.31, 0.333), Vector2(0.11, 0.562), Vector2(0.41, 0.562)],   # window sills, measured on the drawing
	"laundry": [Vector2(0.275, 0.415), Vector2(0.36, 0.415), Vector2(0.795, 0.33), Vector2(0.965, 0.33), Vector2(0.795, 0.505)],
	"market": [Vector2(0.065, 0.505), Vector2(0.18, 0.505), Vector2(0.29, 0.505), Vector2(0.86, 0.385), Vector2(0.97, 0.385)],
	"alley_fire": [Vector2(0.085, 0.34), Vector2(0.29, 0.34), Vector2(0.145, 0.5), Vector2(0.35, 0.5), Vector2(0.085, 0.76),
		Vector2(0.405, 0.76), Vector2(0.33, 0.14), Vector2(0.67, 0.34), Vector2(0.86, 0.34), Vector2(0.97, 0.34),
		Vector2(0.92, 0.5), Vector2(0.86, 0.76), Vector2(0.97, 0.76), Vector2(0.93, 0.12)],   # (art_src 317: its burning windows' sills, both sides)
	"pier17": [Vector2(0.14, 0.34), Vector2(0.25, 0.34), Vector2(0.36, 0.34), Vector2(0.2, 0.68)]}

const MenuGuilt = preload("res://menu.gd")
var game   # main.gd
var _events: Array = []   # {kind, trig, done, ...}
var _beams: Array = []    # {sprite, light, pivot, base, swing, speed, phase, len, half}
var _crates: Array = []   # {sprite, rect (chains), state, vel}
var _smokes: Array = []   # [center, until]
var _band: Node2D          # the tunnel rushing past a moving train (chapter III, the last train)
var _band_w := 0.0
var _band_top := 0.0
var _speed := 0.0
var _beam_t := 6.0
var _beams_live: Array = []   # [node, x of last frame]
var _signal: Node2D
var _cars: Node2D
var _blackout_t := 0.0
var _blacked: Array = []  # lamps the blackout put out, to come back
var _t := 0.0


func setup(main) -> void:
	game = main
	for ev in game.level.get("events", []):
		var kind := String(ev[0])
		match kind:
			"car":
				_events.append({"kind": kind, "trig": float(ev[1]), "stop": float(ev[2]), "side": float(ev[3]), "men": int(ev[4]), "done": false})
			"blackout":
				_events.append({"kind": kind, "trig": float(ev[1]), "secs": float(ev[2]), "done": false})
			"searchlight":
				_add_beam(Vector2(float(ev[1]), float(ev[2])), float(ev[3]))
			"burn":
				_burn(String(ev[1]))
			"train_pass":
				_events.append({"kind": kind, "trig": float(ev[1]), "done": false})
			"beam":   # it starts to go a little before he gets there
				_events.append({"kind": kind, "trig": float(ev[1]) - 650.0, "x": float(ev[1]), "done": false})
			"blaze":   # (1931, audit 18. 11.: "flames round the ankles") a street on fire burns man-high
				_blaze(float(ev[1]), float(ev[2]), INF, 0.0, 1.7 if game.level.get("memory", false) else 1.0)
			"loop":
				_events.append({"kind": kind, "trig": float(ev[1]), "done": false})
	if game.level.get("dream", false):   # eleven knocks from behind the chained doors, spread down the warehouse
		var end: float = float(game.level["end"])
		for k in 11:
			_events.append({"kind": "knock", "trig": end * (0.06 + 0.86 * k / 10.0), "n": k, "done": false})
	_speed = float(game.level.get("moving", 0.0))
	if _speed > 0.0:
		_make_moving.call_deferred()   # after main.gd has made its camera
	# every crane yard keeps its crate hanging over the street
	for seg in game.level.get("street", []):
		if String(seg[0]) == "cranes":
			_add_crate(float(seg[1]))


func tick(delta: float) -> void:
	_t += delta
	var px: float = game.player.position.x
	for ev in _events:
		if ev["done"] or px < ev["trig"]:
			continue
		ev["done"] = true
		match String(ev["kind"]):
			"car":
				_car(ev)
			"blackout":
				_blackout(ev)
			"train_pass":
				_train_pass()
			"beam":
				_beam_fall(ev)
			"loop":
				_loop_again(ev)
			"knock":
				_knock(ev)
	_tick_blazes(delta)
	if game.level.get("dream", false):
		_tick_guilt_ash(delta)
		_tick_posts()
	if _loops > 0 and not game.over:   # (18. 11.) each time round worse: the burning roof sheds cinders, more often every loop
		_cinder_t -= delta
		if _cinder_t <= 0.0:
			_cinder_t = randf_range(3.5, 6.0) / _loops
			_cinders(game.player.position.x + randf_range(-500.0, 1100.0))
	if _speed > 0.0 and _band != null:
		_tick_moving(delta)
	if _blackout_t > 0.0:
		_blackout_t -= delta
		if _blackout_t <= 0.0:
			_lights_back()
	for b in _beams:
		if b.get("dead", false):
			continue
		var a: float = b["base"] + sin(_t * b["speed"] + b["phase"]) * b["swing"]
		b["angle"] = a
		# the drum tilts with its beam, and the lens (where the beam starts) goes round the swivel with it
		var tilt: float = a - float(b["rest"])
		b["drum"].rotation = tilt
		b["pivot"] = (b["swivel"] as Vector2) + (b["lens_rel"] as Vector2).rotated(tilt)
		b["sprite"].position = b["pivot"]
		b["head"].position = b["pivot"]
		b["sprite"].rotation = a
		b["light"].rotation = a
		b["light"].position = b["pivot"] + Vector2(0.0, b["len"] * 0.5).rotated(a)
	for c in _crates:
		if c["state"] == "fall":
			c["vel"] += 2600.0 * delta
			var s: Sprite2D = c["sprite"]
			s.position.y += c["vel"] * delta
			if s.position.y + c["h"] >= 0.0:
				s.position.y = -c["h"]
				_crate_lands(c)
		elif c["state"] == "hang":   # a slow swing on its chains
			c["sprite"].rotation = sin(_t * 0.7 + c["phase"]) * 0.025


## True when a point stands in a searchlight's beam: they can see you there.
func lit(p: Vector2) -> bool:
	for b in _beams:
		if b.get("dead", false):
			continue
		var d: Vector2 = p - b["pivot"]
		if d.length() > b["len"]:
			continue
		var off := absf(angle_difference(d.angle() - PI * 0.5, b["angle"]))
		if off < b["half"]:
			return true
	return false


## Kessler's smoke: a grey wall rolling out over the quay for a few seconds.
## Steam out of a street manhole (THE LAUNDRY's grates): a white jet straight up out of the cover, spreading into a
## cloud once it has risen - it always comes out of the iron in the stones, never out of the air.
func steam_jet(at: Vector2, indoors := false) -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/puff3.png")
	p.angle_min = 0.0
	p.angle_max = 360.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(0.35, 0.9))
	grow.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = grow
	# (audit 17. 11.: a hard pillar of cotton balls) a roaring jet that is see-through at its root, billows out wide as it
	# slows and thins away overhead, turning as it goes
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.amount = 90
	p.lifetime = 2.6
	p.explosiveness = 0.1
	p.position = at + Vector2(0.0, -14.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(45.0, 6.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 14.0
	p.gravity = Vector2(60.0, 40.0)
	p.initial_velocity_min = 700.0
	p.initial_velocity_max = 1050.0
	p.damping_min = 420.0
	p.damping_max = 560.0   # (shot up fast, slowing as it rises: it piles up into a cloud overhead and drifts)
	p.scale_amount_min = 1.1
	p.scale_amount_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.95, 0.93, 0.35))
	g.add_point(0.15, Color(0.95, 0.95, 0.93, 0.7))
	g.add_point(0.55, Color(0.9, 0.9, 0.88, 0.38))
	g.set_color(g.get_point_count() - 1, Color(0.85, 0.85, 0.85, 0.0))
	p.color_ramp = g
	p.modulate = game._undo_night(0.6)
	p.z_index = 4
	p.amount = 22   # (the inked puffs only at its edge now: piled up they read as cauliflower)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3
	add_child(p)
	var body := p.duplicate() as CPUParticles2D   # the jet itself: soft, see-through, no ink lines
	body.texture = game._soft_glow()
	body.amount = 110
	body.scale_amount_min = 1.6
	body.scale_amount_max = 2.6
	var gb := Gradient.new()
	gb.set_color(0, Color(0.9, 0.92, 0.95, 0.0))
	gb.add_point(0.08, Color(0.9, 0.92, 0.95, 0.24))
	gb.add_point(0.5, Color(0.85, 0.87, 0.9, 0.12))
	gb.set_color(gb.get_point_count() - 1, Color(0.8, 0.82, 0.85, 0.0))
	body.color_ramp = gb
	body.z_index = 4
	add_child(body)
	if indoors:   # (user 18. 11.: cut flat at the top, a straight edge at the side) under a roof: a shorter jet that spreads
		# under the ceiling, unlit by the lamps (a lamp's light square cut it), drawn over the dark above the room
		for q: CPUParticles2D in [p, body]:
			q.light_mask = 0
			q.z_index = 10
			q.initial_velocity_min *= 0.55
			q.initial_velocity_max *= 0.55
			q.spread = 26.0
			q.gravity = Vector2(60.0, 10.0)
	get_tree().create_timer(3.6, false).timeout.connect(func() -> void: body.emitting = false)
	get_tree().create_timer(7.5, false).timeout.connect(body.queue_free)
	game.sfx.play("steam", 2.0, at.x, 0.1)
	_smokes.append([at, _t + 6.0])
	game.hop_manhole(at.x)
	get_tree().create_timer(3.6, false).timeout.connect(func() -> void: p.emitting = false)
	get_tree().create_timer(7.5, false).timeout.connect(p.queue_free)


func smoke(at: Vector2, steam := false) -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/puff3.png")   # inked puffs, the same as the street's steam (the round flame blob read as white discs)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -12.0
	p.angular_velocity_max = 12.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.4))
	p.scale_amount_curve = grow
	p.amount = 34   # (fewer, so they do not pile into one opaque mass)
	p.lifetime = 4.0
	p.one_shot = false
	p.explosiveness = 0.6
	p.position = at + Vector2(0.0, -120.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(160.0, 60.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.gravity = Vector2(20.0, -18.0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 220.0
	p.damping_min = 40.0
	p.damping_max = 70.0
	p.scale_amount_min = 1.4
	p.scale_amount_max = 2.6
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.57, 0.55, 0.0))
	g.add_point(0.12, Color(0.48, 0.5, 0.49, 0.38))   # (audit 18. 11.: an opaque white wall on a phone - the men inside it
	g.add_point(0.7, Color(0.4, 0.42, 0.41, 0.26))     # must still show as shapes; the smoke still blocks their sight, in_smoke)
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.4, 0.4, 0.0))
	p.color_ramp = g
	p.modulate = game._undo_night(0.35)
	p.z_index = 4
	if steam:   # a burst pipe (mapfx.gd): white, out of the roof and down, with its own hiss
		p.position = at + Vector2(0.0, -700.0)
		p.direction = Vector2(0.0, 1.0)
		p.spread = 50.0
		p.gravity = Vector2(10.0, 60.0)
		p.initial_velocity_min = 300.0
		p.initial_velocity_max = 650.0
		p.emission_rect_extents = Vector2(70.0, 20.0)
		g.set_color(0, Color(0.95, 0.95, 0.93, 0.0))
		g.set_color(1, Color(0.9, 0.9, 0.88, 0.5))
		p.modulate = game._undo_night(0.6)
	add_child(p)
	game.sfx.play("steam" if steam else "slow_out", 2.0 if steam else -4.0, at.x, 0.1)   # the hiss of the canister / the pipe
	_smokes.append([at, _t + 7.0])
	get_tree().create_timer(4.5, false).timeout.connect(func() -> void: p.emitting = false)
	get_tree().create_timer(9.5, false).timeout.connect(p.queue_free)


func in_smoke(p: Vector2) -> bool:
	for sm in _smokes:
		if _t < float(sm[1]) and absf(p.x - (sm[0] as Vector2).x) < 520.0:
			return true
	return false


## A bullet of Frank's in flight: true if it hit one of these (the chains of a hanging crate).
func bullet(pos: Vector2) -> bool:
	for c in _crates:
		if c["state"] != "hang":
			continue
		if (c["chains"] as Rect2).has_point(pos):
			_crate_drop(c)
			return true
		if (c["body"] as Rect2).has_point(pos):   # a few rounds into it and the hook tears out of the boards
			game.sfx.play("wood_hit", -4.0, pos.x, 0.12)
			game.fx.chip(pos)
			c["phase"] += 0.6
			c["hits"] = int(c.get("hits", 0)) + 1
			if c["hits"] >= 3:
				_crate_drop(c)
			return true
	return false


# ---- the car ---------------------------------------------------------------------------------

func _car(ev: Dictionary) -> void:
	var side: float = ev["side"]   # +1: it comes in from the right, driving left
	var stop: float = ev["stop"]
	var car := Sprite2D.new()
	car.texture = load("res://art/props/sedan.png")
	car.flip_h = side > 0.0
	var h := car.texture.get_height()
	car.position = Vector2(stop + side * 2900.0, -h * 0.5 + 8.0)
	car.scale = Vector2.ONE   # 1000 px: a sedan four and a half metres long beside a 400 px man
	car.modulate = Color(0.78, 0.78, 0.84)
	car.z_index = -1
	add_child(car)
	var beam := Sprite2D.new()   # the headlights cutting through the rain ahead of it
	beam.texture = load("res://art/light_cone_soft.png")
	beam.rotation = PI * 0.5 * side
	beam.scale = Vector2(0.9, 1.6)
	beam.position = Vector2(-side * (CAR_W * 0.5 + 400.0), h * 0.12)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	beam.material = add
	beam.modulate = Color(1.0, 0.9, 0.7, 0.28)
	car.add_child(beam)
	game.sfx.play("car_arrive", 0.0, stop, 0.03)
	var tw := car.create_tween()
	tw.tween_property(car, "position:x", stop, 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(car, "rotation", -0.02 * side, 0.12)   # it rocks on its springs as it stops
	tw.tween_property(car, "rotation", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		# steel to hide behind, in the car's own outline: the boot, the cabin up to its roof, the bonnet
		# (the drawing: 1000 wide, nose to the right)
		var fwd := -side
		for part in [[-390.0, -260.0, 240.0], [-260.0, 110.0, 336.0], [110.0, 460.0, 254.0]]:
			var xa := stop + minf(float(part[0]) * fwd, float(part[1]) * fwd)
			var cover := Rect2(xa, -float(part[2]), absf(float(part[1]) - float(part[0])), float(part[2]))
			if cover.grow(50.0).has_point(game.player.position + Vector2(0.0, -40.0)):
				continue
			game.boxes.append(cover)
			game.box_info.append({"kind": "car", "sprite": car, "hp": 999, "wood": false})
		for i in ev["men"]:
			game.get_tree().create_timer(0.35 + i * 0.45, false).timeout.connect(func() -> void:
				if game.over:
					return
				game.sfx.play("door", -2.0, stop, 0.1)
				var kind := "tommy" if i == 1 else ("shotgun" if i == 2 else "post")
				game._spawn_runner(stop + side * (120.0 - i * 160.0), stop - side * (CAR_W * 0.5 + 180.0 + i * 260.0), kind)))
	tw.tween_property(beam, "modulate:a", 0.12, 1.5)


# ---- the power going out -----------------------------------------------------------------------

func _blackout(ev: Dictionary) -> void:
	game.sfx.play("power_down", 0.0, INF, 0.0)
	game.hud.toast("THE LIGHTS GO OUT")
	var x: float = game.player.position.x
	_blacked.clear()
	for i in game.lamps.size():
		var rec: Dictionary = game.lamp_info[i]
		if not rec["on"] or absf(game.lamps[i].x - x) > 5200.0:
			continue
		_blacked.append(i)
		rec["on"] = false
		if rec.has("hum"):
			rec["hum"]["on"] = false
		_flicker(rec, false, randf_range(0.0, 0.5))
	for n in game.neons:
		n["was"] = [n["mode"], n["on"]]
		n["mode"] = "off"
		n["on"] = false
		n["next"] = 0.0
	_blackout_t = float(ev["secs"])


func _lights_back() -> void:
	game.sfx.play("zap", -6.0, INF, 0.1)
	for i in _blacked:
		var rec: Dictionary = game.lamp_info[i]
		if rec.get("broken", false):
			continue
		rec["on"] = true
		if rec.has("hum"):
			rec["hum"]["on"] = true
		_flicker(rec, true, randf_range(0.0, 0.8))
	_blacked.clear()
	for n in game.neons:
		if n.has("was"):
			n["mode"] = n["was"][0]
			n["on"] = true
			n["next"] = randf_range(0.1, 0.6)
			n.erase("was")


func _flicker(rec: Dictionary, on: bool, wait: float) -> void:
	var light = rec["light"]
	var tw := create_tween()
	tw.tween_interval(wait)
	for k in randi_range(3, 6):
		var show := k % 2 == (0 if on else 1)
		tw.tween_callback(func() -> void:
			for n in rec["nodes"]:
				n.visible = show
			if light != null:
				light.enabled = show)
		tw.tween_interval(randf_range(0.04, 0.14))
	tw.tween_callback(func() -> void:
		for n in rec["nodes"]:
			n.visible = on
		if light != null:
			light.enabled = on)


# ---- searchlights ------------------------------------------------------------------------------

## A bullet at a searchlight's lens puts it out: glass, sparks, the beam gone, the yard dark there.
func shoot_light(pos: Vector2) -> bool:
	for b in _beams:
		if b.get("dead", false) or pos.distance_to(b["pivot"]) > 70.0:
			continue
		b["dead"] = true
		game.fx.shatter(b["pivot"] + Vector2(0.0, 10.0))
		game.fx.spark(b["pivot"] + Vector2(0.0, 10.0))
		game.sfx.play("glass", -1.0, b["pivot"].x, 0.1)
		game.sfx.play("zap", -4.0, b["pivot"].x, 0.1)
		game._word(["smash"], b["pivot"] + Vector2(0.0, -110.0), 0.2)
		var tw := create_tween()   # it stutters out
		for k in 4:
			var on := k % 2 == 1
			tw.tween_callback(func() -> void:
				b["sprite"].visible = on
				b["head"].visible = on
				b["light"].enabled = on)
			tw.tween_interval(randf_range(0.04, 0.1))
		tw.tween_callback(func() -> void:
			b["sprite"].visible = false
			b["head"].visible = false
			b["light"].enabled = false)
		return true
	return false


func _add_beam(pivot: Vector2, base_deg: float) -> void:
	var ln := 2300.0
	var s := Sprite2D.new()
	s.texture = load("res://art/light_beam_soft.png")   # soft sides, gone before its end (no hard edge anywhere)
	s.centered = false
	s.offset = Vector2(-256.0, 0.0)
	s.scale = Vector2(1.15, ln / 512.0)
	s.position = pivot
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = add
	s.modulate = Color(0.85, 0.9, 1.0, 0.3) * Color(game._undo_night(0.35), 1.0)
	s.z_index = 2
	add_child(s)
	# the searchlight itself (art/props/searchlight.png): its drum on a riveted mast down to the quay,
	# the lens at the pivot of the beam
	var lamp_tex: Texture2D = load("res://art/props/searchlight.png")
	var lens := Vector2(66.0, 142.0)   # the lens's centre on the drawing
	# the drum's axis on the drawing (axle -> lens) points this way as a beam angle (0 = straight down)
	var rest := atan2(-(lens.x - 205.0), lens.y - 127.0)
	var sc: float = -pivot.y / (lamp_tex.get_height() - lens.y)   # the foot of the mast on the ground
	# the searchlight in two layers (gen/searchlight_split.py): the drum turns on its axle in the yoke and
	# the beam leaves its lens along the drum's own axis; mast, yoke and cable stand still
	var axle := Vector2(205.0, 127.0)
	var origin: Vector2 = pivot - lens * sc
	var drum := Sprite2D.new()
	drum.texture = load("res://art/props/searchlight_drum.png")
	drum.centered = false
	drum.offset = -axle
	drum.scale = Vector2.ONE * sc
	drum.position = origin + axle * sc
	drum.z_index = -4
	add_child(drum)
	var post := Sprite2D.new()   # in front of the drum: the yoke's near arm holds it
	post.texture = load("res://art/props/searchlight_post.png")
	post.centered = false
	post.scale = Vector2.ONE * sc
	post.position = origin
	post.z_index = -4
	add_child(post)
	var head := Sprite2D.new()   # the lens, burning white
	head.texture = load("res://art/light_blob.png")
	head.position = pivot
	head.scale = Vector2.ONE * 0.28
	head.material = add
	head.modulate = Color(1.0, 1.0, 0.95, 0.8)
	head.z_index = 2
	add_child(head)
	var l := PointLight2D.new()
	l.texture = load("res://art/light_beam_light.png")
	l.texture_scale = ln / 512.0
	l.color = Color(0.8, 0.88, 1.0)
	l.energy = 1.1
	l.range_item_cull_mask = game.MASK_LIT
	add_child(l)
	var half := atan2(256.0 * 1.15 * 0.45, ln)   # the bright core of the cone, not its soft edge
	_beams.append({"sprite": s, "light": l, "head": head, "pivot": pivot, "base": deg_to_rad(base_deg), "swing": deg_to_rad(32.0),
			"drum": drum, "swivel": drum.position, "lens_rel": pivot - drum.position, "rest": rest,
			"speed": 0.42, "phase": randf() * TAU, "len": ln, "half": half, "angle": 0.0})
	game.sfx.add_loop("lamp_hum", pivot.x, -22.0, 600.0, pivot.y)


# ---- fire --------------------------------------------------------------------------------------

## A drawing's windows on fire: flames licking out and up, smoke, sparks, an orange light that will
## not hold still, and the roar of it.
func _burn(seg_name: String) -> void:
	for seg in game.level.get("street", []):
		if String(seg[0]) != seg_name:   # its own drawing only: a variant's windows are elsewhere
			continue
		var tex: Texture2D = BigTex.get_tex("res://art/street/%s.png" % seg_name)
		var kit: String = String(game.SEGMENT_KIT.get(seg_name, seg_name))   # (a variant: its kit's size and trim)
		var ws: float = game.WALL_SCALE * float(game.SEGMENT_SIZE.get(kit, 1.0))   # as the street builds it
		var w: float = tex.get_width() * ws
		var h: float = tex.get_height() * ws
		var top: float = -h * game.SEGMENT_BASE - game.WALL_LIFT
		var x0 := float(seg[1])
		var trim: float = game.SEGMENT_TRIM.get(kit, 0.0)
		var sx: float = tex.get_width() / (tex.get_width() - trim)
		var heat := PointLight2D.new()
		heat.texture = load("res://art/light_blob.png")
		heat.texture_scale = 14.0
		heat.color = Color(1.0, 0.5, 0.18)
		heat.energy = 1.2
		heat.position = Vector2(x0 + w * 0.27, top + h * 0.45)
		heat.range_item_cull_mask = game.MASK_LIT
		add_child(heat)
		var tw := heat.create_tween().set_loops()
		for k in 6:
			tw.tween_property(heat, "energy", randf_range(0.8, 1.6), randf_range(0.06, 0.18))
		for f in FIRES.get(seg_name, []):   # fractions of the drawing, to where it stands once trimmed and stretched
			_flames(Vector2(x0 + (f.x * tex.get_width() - trim) * sx * ws, top + h * f.y))
		game.sfx.add_loop("fire", x0 + w * 0.27, -4.0, 1600.0, top + h * 0.4)   # (every drawing of that name burns)


func _flames(at: Vector2) -> void:
	for k in 3:   # the painted flames licking out of the window, each on its own breath
		var hgt := randf_range(210.0, 260.0) * (1.2 if k == 1 else 0.8)
		var f = game._flame(at + Vector2(-26.0 + 26.0 * k + randf_range(-5.0, 5.0), 4.0), hgt, randi(), -8)
		f.modulate = game._undo_night(0.8) * Color(1.0, 0.78, 0.55)
	var smoke := CPUParticles2D.new()   # black smoke rolling off the top of each window: the inked puffs, darkened
	smoke.texture = load("res://art/fx/puff3.png")
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.amount = 10
	smoke.lifetime = 3.5
	smoke.preprocess = 3.0
	smoke.position = at + Vector2(0.0, -150.0)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(50.0, 10.0)
	smoke.direction = Vector2(0.15, -1.0)
	smoke.spread = 20.0
	smoke.gravity = Vector2(40.0, -60.0)
	smoke.initial_velocity_min = 60.0
	smoke.initial_velocity_max = 120.0
	smoke.scale_amount_min = 0.9
	smoke.scale_amount_max = 1.6
	var sg := Gradient.new()
	sg.set_color(0, Color(0.1, 0.09, 0.09, 0.0))
	sg.add_point(0.15, Color(0.1, 0.09, 0.09, 0.6))
	sg.set_color(sg.get_point_count() - 1, Color(0.14, 0.14, 0.15, 0.0))
	smoke.color_ramp = sg
	smoke.z_index = -8
	add_child(smoke)


# ---- the crate on the crane --------------------------------------------------------------------

## The crate hanging from the crane in the drawing is taken out of it and hung here instead, over the
## street, where a shot through its chains brings it down on whoever is under it.
func _add_crate(seg_x: float) -> void:
	var tex: Texture2D = load("res://art/props/cranes_cut.png")
	var street: Texture2D = BigTex.get_tex("res://art/street/cranes.png")
	var trim: float = game.SEGMENT_TRIM.get("cranes", 0.0)
	var sx: float = street.get_width() / (street.get_width() - trim)
	var cut: Rect2 = game.CRANE_CUT
	var top_left: Vector2 = Vector2(seg_x, -street.get_height() * game.WALL_SCALE * game.SEGMENT_BASE - game.WALL_LIFT) \
			+ Vector2((cut.position.x * street.get_width() - trim) * sx, cut.position.y * street.get_height()) * game.WALL_SCALE
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(game.WALL_SCALE * sx, game.WALL_SCALE)
	var size: Vector2 = tex.get_size() * s.scale
	s.offset = Vector2(-tex.get_width() * 0.5, 0.0)   # it swings from the top middle, where the chains meet
	s.position = top_left + Vector2(size.x * 0.5, 0.0)
	s.modulate = Color.WHITE * game.SEGMENT_MOON * 0.95
	s.z_index = -3
	add_child(s)
	var chains := Rect2(top_left + Vector2(size.x * 0.15, 0.0), Vector2(size.x * 0.7, size.y * 0.55))
	var body := Rect2(top_left + Vector2(0.0, size.y * 0.55), Vector2(size.x, size.y * 0.45))
	_crates.append({"sprite": s, "chains": chains, "body": body, "state": "hang", "vel": 0.0, "h": size.y, "w": size.x, "phase": randf() * TAU})


func _crate_drop(c: Dictionary) -> void:
	c["state"] = "fall"
	c["vel"] = 0.0
	c["sprite"].rotation = 0.0
	c["sprite"].z_index = 1
	game.sfx.play("chain", 0.0, c["sprite"].position.x, 0.05)
	game.fx.spark((c["chains"] as Rect2).get_center())
	game.cue(c["sprite"].position + Vector2(0.0, 300.0), 1.1, 0.3)
	game._word(["clink"], (c["chains"] as Rect2).get_center() + Vector2(0.0, -80.0), 0.18)


func _crate_lands(c: Dictionary) -> void:
	c["state"] = "down"
	var s: Sprite2D = c["sprite"]
	var x := s.position.x
	game._shake = 0.4
	game.sfx.play("wood_break", 2.0, x, 0.05)
	game.sfx.play("body_fall", 0.0, x, 0.05)
	game._word(["crash", "crash2"], Vector2(x, -520.0), 0.3)
	game._scare_birds(Vector2(x, 0.0), 2200.0)
	for e in game.enemies:   # whoever stood under it
		if e["alive"] and absf(e["node"].position.x - x) < c["w"] * 0.6 and e["node"].position.y > -200.0 and e["node"].visible:
			game._kill(e, false, true, "blast")
	var p = game.player
	if absf(p.position.x - x) < c["w"] * 0.45 and p.position.y > -200.0 and not game.over:
		game.hp = 1   # it nearly gets him too
	s.offset = Vector2.ZERO
	s.position.x -= c["w"] * 0.5
	game.fx.break_apart(s, s.position + Vector2(c["w"] * 0.5, c["h"] * 0.7), 0.0)
	s.queue_free()


# ---- the subway ------------------------------------------------------------------------------

## A train going by on the far track: three lit cars at full speed, the roar, the ground shaking.
func _train_pass() -> void:
	var tex: Texture2D = load("res://art/props/subway_car.png")
	var lit: Texture2D = load("res://art/props/subway_car_lit.png")
	var sc := 0.92
	var w: float = tex.get_width() * sc
	var root := Node2D.new()
	root.z_index = -6
	root.position = Vector2(game.cam.position.x + 3200.0, -tex.get_height() * sc - 170.0)   # on the rails behind the platform edge
	add_child(root)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for k in 3:
		var car := Sprite2D.new()
		car.texture = tex
		car.centered = false
		car.scale = Vector2.ONE * sc
		car.position = Vector2(k * (w + 30.0), 0.0)
		car.modulate = Color(0.7, 0.7, 0.75)
		root.add_child(car)
		var glow := Sprite2D.new()
		glow.texture = lit
		glow.centered = false
		glow.scale = car.scale
		glow.position = car.position
		glow.material = add
		glow.modulate = game._undo_night(0.45)
		root.add_child(glow)
	game.sfx.play("train_pass", 4.0, INF, 0.0)
	game._shake = 0.5
	var tw := root.create_tween()
	tw.tween_property(root, "position:x", root.position.x - 3.0 * w - 7000.0, 2.6)
	tw.tween_callback(root.queue_free)


func _make_moving() -> void:
	_make_band()
	_make_train()


const BAND_ART := ["tunnel", "tunnel_b", "tunnel_c"]


## The last train: the tunnel wall pours past behind the cars, which carry the fight on their roofs.
func _make_band() -> void:
	# the three drawings of the tunnel in turn (tunnel, tunnel_b, tunnel_c: same kit), so the wall that
	# pours past is not one picture over and over; the band wraps over all three, so none of them pops
	var texs: Array = []
	var lits: Array = []
	for nm in BAND_ART:
		texs.append(BigTex.get_tex("res://art/street/%s.png" % nm))
		lits.append(BigTex.get_tex("res://art/street/%s_lit.png" % nm))
	var tex: Texture2D = texs[0]
	var trim: float = game.SEGMENT_TRIM.get("tunnel", 0.0)
	var sx: float = tex.get_width() / (tex.get_width() - trim)
	_band_w = tex.get_width() * game.WALL_SCALE
	_band_top = -tex.get_height() * game.WALL_SCALE * game.SEGMENT_BASE - game.WALL_LIFT + 720.0   # its rails down level with the wheels, under the roofs
	_band = Node2D.new()
	_band.z_index = -10
	game.cam.add_child(_band)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in BAND_ART.size() * 2 + 1:
		var lit: Texture2D = lits[i % BAND_ART.size()]
		var w := Sprite2D.new()
		w.texture = texs[i % BAND_ART.size()]
		w.centered = false
		w.region_enabled = true
		w.region_rect = Rect2(trim, 0.0, tex.get_width() - trim, tex.get_height())
		w.scale = Vector2(game.WALL_SCALE * sx, game.WALL_SCALE)
		w.position = Vector2((i - BAND_ART.size()) * _band_w, 0.0)
		w.material = game.atmo.blur_material(2.6)   # going by too fast to be sharp
		w.modulate = Color.WHITE * game.SEGMENT_MOON * float(game.SEGMENT_GAIN.get("tunnel", 1.0)) * 0.8
		_band.add_child(w)
		var g := Sprite2D.new()
		g.texture = lit
		g.centered = false
		g.region_enabled = true
		g.region_rect = Rect2(trim * 0.5, 0.0, lit.get_width() - trim * 0.5, lit.get_height())
		g.scale = Vector2(game.WALL_SCALE * 2.0 * sx, game.WALL_SCALE * 2.0)
		g.position = w.position
		g.material = add
		g.modulate = game._undo_night(0.5)
		_band.add_child(g)
	_signal = Node2D.new()   # the red lamp of a signal ahead: it means a girder is coming, get down
	var lamp := Sprite2D.new()
	lamp.texture = load("res://art/light_blob.png")
	lamp.material = add
	lamp.modulate = Color(1.0, 0.15, 0.1, 0.0)
	lamp.scale = Vector2.ONE * 0.9
	lamp.name = "Lamp"
	_signal.add_child(lamp)
	_signal.z_index = 5
	game.cam.add_child(_signal)
	game.sfx.add_loop("train_loop", 0.0, -2.0, 1.0e9)


## The cars under his feet, one after another the length of the map, their roofs the floor.
func _make_train() -> void:
	var tex: Texture2D = load("res://art/props/subway_car.png")
	var lit: Texture2D = load("res://art/props/subway_car_lit.png")
	var sc := 1.05
	var w: float = tex.get_width() * sc
	_cars = Node2D.new()
	_cars.z_index = -2
	add_child(_cars)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var x := -3000.0
	while x < float(game.level_end) + 4000.0:
		var car := Sprite2D.new()
		car.texture = tex
		car.centered = false
		car.scale = Vector2.ONE * sc
		car.position = Vector2(x, -14.0 * sc)   # its roof is the pavement line
		car.modulate = Color(0.62, 0.62, 0.68)
		_cars.add_child(car)
		var glow := Sprite2D.new()
		glow.texture = lit
		glow.centered = false
		glow.scale = car.scale
		glow.position = car.position
		glow.material = add
		glow.modulate = game._undo_night(0.4)
		_cars.add_child(glow)
		x += w + 26.0


func _tick_moving(delta: float) -> void:
	var cam_x: float = game.cam.position.x
	_band.position = Vector2(-fposmod(cam_x + _t * _speed, _band_w * BAND_ART.size()), _band_top - game.cam.position.y)
	_cars.position.y = sin(_t * 9.0) * 3.0 + sin(_t * 2.3) * 2.0   # it rocks along the rails
	game._shake = maxf(game._shake, 0.04)
	var lamp: Sprite2D = _signal.get_node("Lamp")
	var view: Vector2 = get_viewport().get_visible_rect().size / game.cam.zoom
	_signal.position = Vector2(view.x * 0.5 - 140.0, -view.y * 0.5 + 260.0)
	if game.over or game.cleared:
		lamp.modulate.a = 0.0
		return
	_beam_t -= delta
	if _beam_t < 1.3 and _beam_t > 0.0:   # the warning: the red lamp blinking
		lamp.modulate.a = 0.95 if fmod(_beam_t, 0.3) < 0.15 else 0.15
	else:
		lamp.modulate.a = 0.0
	_tick_oncoming(delta, cam_x, view)
	if _beam_t <= 0.0 and _oncoming == null:
		_beam_t = randf_range(6.0, 9.5)
		var b := _girder()
		b.position = Vector2(cam_x + view.x * 0.75, 0.0)
		add_child(b)
		_beams_live.append([b, b.position.x])
	var px: float = game.player.position.x
	for bl in _beams_live.duplicate():
		var b: Node2D = bl[0]
		var was: float = bl[1]
		b.position.x -= _speed * delta
		if was >= px and b.position.x < px:   # it reaches him: down flat or under it, or it takes him off his feet
			for y in range(-470, -320, 25):
				if game.player.hit_part(Vector2(px, y)) != "":
					if OS.get_cmdline_user_args().has("--log-sets"): print("GIRDER HIT duck ", snappedf(game.player.duck, 0.01), " state ", game.move_state, " pop ", game._pop, " hud ", game.hud.duck, " dive ", snappedf(game.player.dive, 0.01), " t ", snappedf(_t, 0.1))
					game._bullet_hit(Vector2(px, y), false)
					game._shake = 0.5
					game.sfx.play("body_fall", 0.0, px, 0.05)
					break
		bl[1] = b.position.x
		if b.position.x < cam_x - view.x:
			b.queue_free()
			_beams_live.erase(bl)


## A train on the other track, the other way (2026-11-16): its headlamp grows in the dark ahead, the
## horn, then it screams past just below the roofs, its windows strobing, sparks off the rails, and
## the blast of air off it shoves a man standing in the open back along the roof. Down behind a vent
## housing it goes over him; crouched, it only staggers him.
var _oncoming: Node2D = null
var _oncoming_t := 16.0
var _oncoming_len := 0.0
var _headlamp: Sprite2D
var _strobe: ColorRect
var _oncoming_told := false
const ONCOMING_REL := 5200.0   # the two trains' speeds together


func _tick_oncoming(delta: float, cam_x: float, view: Vector2) -> void:
	if _headlamp == null:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_headlamp = Sprite2D.new()
		_headlamp.texture = load("res://art/light_blob.png")
		_headlamp.material = add
		_headlamp.modulate = Color(1.0, 0.92, 0.7, 0.0)
		_headlamp.z_index = -3
		game.cam.add_child(_headlamp)
		_strobe = ColorRect.new()
		_strobe.color = Color(1.0, 0.93, 0.78, 0.0)
		_strobe.size = Vector2(8000.0, 8000.0)
		_strobe.position = Vector2(-4000.0, -4000.0)
		_strobe.material = add
		_strobe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_strobe.z_index = 7
		game.cam.add_child(_strobe)
	if _oncoming == null:
		_oncoming_t -= delta
		if game.over or game.cleared:
			_headlamp.modulate.a = 0.0
			return
		if _oncoming_t < 2.6 and _oncoming_t > 0.0:   # the warning: its lamp coming up the tunnel ahead, growing
			var k: float = 1.0 - _oncoming_t / 2.6
			# low down at the end of the tunnel, where the other track comes out of the dark: the lamp
			# on its cab, small and far at first, then filling the tunnel mouth
			_headlamp.position = Vector2(view.x * 0.5 - 90.0, -game.cam.position.y + 40.0)
			_headlamp.scale = Vector2.ONE * lerpf(0.25, 2.2, k * k)
			_headlamp.modulate.a = 0.25 + 0.65 * k
			if _oncoming_t + delta >= 2.6:
				game.sfx.play("train_horn", 0.0, INF, 0.02)
				if not _oncoming_told:
					_oncoming_told = true
					game.hud.hint("A TRAIN THE OTHER WAY: GET BEHIND A VENT.")
		else:
			_headlamp.modulate.a = 0.0
		if _oncoming_t <= 0.0:
			if _beam_t < 3.0:   # never with a girder coming: one thing at a time
				_beam_t += 4.0
			_oncoming_t = randf_range(17.0, 25.0)
			_launch_oncoming(cam_x, view)
		return
	_headlamp.modulate.a = 0.0
	_oncoming.position.x -= ONCOMING_REL * delta
	var x0: float = _oncoming.position.x
	var x1: float = x0 + _oncoming_len
	var px: float = game.player.position.x
	var passing: bool = x0 < cam_x + view.x * 0.5 and x1 > cam_x - view.x * 0.5
	if passing:
		game._shake = maxf(game._shake, 0.3)
		# the lit windows going by: the light on everything flickers with them
		var phase: float = fposmod(px - x0, 1450.0) / 1450.0
		_strobe.color.a = 0.07 if phase > 0.18 and phase < 0.82 else 0.01
		if randf() < delta * 5.0:
			game.fx.speed_lines(Vector2(cam_x + randf_range(-view.x * 0.4, view.x * 0.4), randf_range(-60.0, 20.0)), -1.0, 0.6)
		if randf() < delta * 14.0:
			game.fx.spark(Vector2(cam_x + randf_range(-view.x * 0.4, view.x * 0.4), randf_range(60.0, 140.0)))
		if x0 < px and x1 > px - 200.0 and game.move_state == "ground":   # the blast of air off it
			var shelter: bool = false
			for bx in game.boxes:
				if absf(bx.end.y - game.player.position.y) < 60.0 and bx.position.x > px - 20.0 and bx.position.x < px + 380.0:
					shelter = true
			var push: float = 0.0 if shelter else (160.0 if game.player.duck > 0.6 else 620.0)
			game.player.position.x -= push * delta
	else:
		_strobe.color.a = 0.0
	if x1 < cam_x - view.x:
		_oncoming.queue_free()
		_oncoming = null
		_strobe.color.a = 0.0


func _launch_oncoming(cam_x: float, view: Vector2) -> void:
	var tex: Texture2D = load("res://art/props/subway_car.png")
	var lit: Texture2D = load("res://art/props/subway_car_lit.png")
	var sc := 1.12   # the near track: a little bigger than the cars under him
	var w: float = tex.get_width() * sc
	var cars := 6
	_oncoming_len = cars * (w + 24.0)
	_oncoming = Node2D.new()
	_oncoming.z_index = 3   # in front of his own train's flank, below the roofs he stands on
	_oncoming.position = Vector2(cam_x + view.x * 0.6, -150.0)   # its roof slides by across his shins: right there
	add_child(_oncoming)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for k in cars:
		var car := Sprite2D.new()
		car.texture = tex
		car.centered = false
		car.flip_h = true
		car.scale = Vector2.ONE * sc
		car.position = Vector2(k * (w + 24.0), 0.0)
		car.modulate = Color(0.5, 0.5, 0.55)
		car.material = game.atmo.blur_material(3.0)   # going by too fast to be sharp
		_oncoming.add_child(car)
		var glow := Sprite2D.new()
		glow.texture = lit
		glow.centered = false
		glow.flip_h = true
		glow.scale = car.scale
		glow.position = car.position
		glow.material = add
		glow.modulate = game._undo_night(0.55)
		_oncoming.add_child(glow)
	game.sfx.play("train_pass", 6.0, INF, 0.0)


## A steel girder hanging low across the tunnel, its riveted face and the strut up to the roof.
func _girder() -> Node2D:
	# the drawing (art/props/girder.png, gen/map_props.py): the I of the girder seen end-on, from -480
	# down to -330 where it catches a man standing, and its hanger strut stacked up out of sight
	var n := Node2D.new()
	n.z_index = 6
	var tex: Texture2D = load("res://art/props/girder.png")
	var s := 150.0 / (2258.0 - 1143.0)
	var body := Sprite2D.new()
	body.texture = tex
	body.centered = false
	body.scale = Vector2.ONE * s
	body.position = Vector2(-tex.get_width() * s * 0.5, -330.0 - 2258.0 * s)
	n.add_child(body)
	var strut := Rect2(414.0, 120.0, 176.0, 800.0)
	var y := body.position.y + 2.0
	while y > -2600.0:
		var piece := Sprite2D.new()
		piece.texture = tex
		piece.centered = false
		piece.region_enabled = true
		piece.region_rect = strut
		piece.scale = body.scale
		y -= strut.size.y * s - 1.0
		piece.position = Vector2(body.position.x + strut.position.x * s, y)
		n.add_child(piece)
	for c in n.get_children():
		(c as CanvasItem).modulate = Color(0.42, 0.42, 0.45)   # near and unlit: dark iron against the lit wall
	return n


# ---- the dream: Pier 17 burning ------------------------------------------------------------------

var _blazes: Array = []   # {x0, x1, until, flames}: floor on fire; standing in it burns
var _burn_cool := 0.0
var _loops := 0
const LOOP_LINES := [["The same room again. Only it isn't."], ["Every time it's worse. And the knocking a little quieter."]]


## A strip of floor on fire from x0, w wide: low hand-inked flames along it, the boards glowing.
func _blaze(x0: float, w: float, secs: float, ground := 0.0, tall := 1.0) -> void:
	var flames: Array = []
	var n := maxi(2, int(w / 110.0))
	for k in n:
		var f: Sprite2D = game._flame(Vector2(x0 + (k + 0.5) * w / n + randf_range(-20.0, 20.0), ground + 8.0), randf_range(170.0, 270.0) * tall, randi() % 6, 3)
		flames.append(f)
	var heat := PointLight2D.new()
	heat.texture = game._soft_glow()
	heat.texture_scale = maxf(3.0, w / 160.0)
	heat.color = Color(1.0, 0.5, 0.2)
	heat.energy = 1.0
	heat.position = Vector2(x0 + w * 0.5, ground - 60.0)
	heat.range_item_cull_mask = game.MASK_LIT
	add_child(heat)
	flames.append(heat)
	var loop: Dictionary = game.sfx.add_loop("fire", x0 + w * 0.5, -10.0, 700.0, ground - 40.0)
	_blazes.append({"x0": x0, "x1": x0 + w, "until": _t + secs, "flames": flames, "y": ground, "loop": loop})


func _tick_blazes(delta: float) -> void:
	_burn_cool -= delta
	var p = game.player
	for b in _blazes:
		if b["until"] < INF and _t > b["until"] and not b.get("out", false):   # it burns down to embers
			b["out"] = true
			if b.get("loop") is Dictionary:
				b["loop"]["on"] = false
			for f in b["flames"]:
				if is_instance_valid(f):
					var tw: Tween = f.create_tween()
					tw.tween_property(f, "modulate:a", 0.0, 1.5)
					tw.tween_callback(f.queue_free)
			continue
		if b.get("out", false):
			continue
		if _burn_cool <= 0.0 and p.position.x > b["x0"] + 20.0 and p.position.x < b["x1"] - 20.0 and absf(p.position.y - float(b.get("y", 0.0))) < 70.0:
			_burn_cool = 1.1
			game._burn_player(1)


## The roof gives: a creak, dust and sparks sifting down, a beat, and a burning beam across the floor.
func _beam_fall(ev: Dictionary) -> void:
	if OS.get_cmdline_user_args().has("--log-sets"): print("BEAM FALL ", ev["x"], " t ", _t)
	var x: float = ev["x"]
	game.sfx.play("creak", 0.0, x, 0.05)
	var dust := CPUParticles2D.new()
	dust.texture = load("res://art/fx/puff2.png")
	dust.amount = 26
	dust.lifetime = 1.4
	dust.one_shot = true
	dust.explosiveness = 0.3
	dust.position = Vector2(x, -1150.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(220.0, 10.0)
	dust.direction = Vector2(0.0, 1.0)
	dust.gravity = Vector2(0.0, 420.0)
	dust.initial_velocity_min = 40.0
	dust.initial_velocity_max = 140.0
	dust.scale_amount_min = 0.15
	dust.scale_amount_max = 0.4
	dust.color = Color(0.3, 0.27, 0.25, 0.7)
	dust.z_index = 4
	add_child(dust)
	dust.emitting = true
	get_tree().create_timer(1.6, false).timeout.connect(dust.queue_free)
	get_tree().create_timer(1.1, false).timeout.connect(_beam_drop.bind(x))


func _beam_drop(x: float) -> void:
	if OS.get_cmdline_user_args().has("--log-sets"): print("BEAM DROP ", x, " t ", _t)
	var tex: Texture2D = load("res://art/fx/fire/beam.png") if ResourceLoader.exists("res://art/fx/fire/beam.png") else load("res://art/props/crate_long.png")
	var beam := Sprite2D.new()
	beam.texture = tex
	var sc: float = 620.0 / tex.get_width()   # a roof timber, a little longer than two men lying down
	beam.scale = Vector2.ONE * sc
	beam.position = Vector2(x, -1300.0)
	beam.rotation = randf_range(-0.35, 0.35)
	beam.modulate = game._undo_night(0.75)
	beam.z_index = 4
	add_child(beam)
	var rest_y := -tex.get_height() * sc * 0.42   # its underside on the boards
	var tw := beam.create_tween().set_parallel(true)
	tw.tween_property(beam, "position:y", rest_y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(beam, "rotation", randf_range(-0.04, 0.04), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		game._shake = 0.45
		game.sfx.play("wood_break", 3.0, x, 0.05)
		game.sfx.play("body_fall", 0.0, x, 0.05)
		game._word(["crash", "crash2"], Vector2(x, -520.0), 0.3)
		for k in 10:
			game.fx.spark(Vector2(x + randf_range(-300.0, 300.0), randf_range(-120.0, 0.0)))
		for e in game.enemies:   # whoever stood under it
			if e["alive"] and absf(e["node"].position.x - x) < 300.0 and e["node"].position.y > -200.0 and e["node"].visible:
				game._kill(e, false, true, "blast")
		var p = game.player
		if absf(p.position.x - x) < 290.0 and p.position.y > -260.0:
			game._burn_player(2)
		_blaze(x - 280.0, 560.0, 7.0))   # it burns where it lies, then smoulders out


## THE DREAM's burning posts sliding past right by the lens (user 18. 11.: "it must not look awful, and they must come
## up from the bottom of the screen - never seen to start in the middle of nothing"): the charred post (art/fore/dream_post.png,
## gen/dream_post.py) in main.gd's fore layer (1.35x the camera), each frame stretched as a whole to more than the screen's
## height and centred on it, so neither end is ever in the picture. Off with DREAM_POSTS = false.
const DREAM_POSTS := true
var _posts: Array = []
func _make_posts() -> void:
	var tex: Texture2D = load("res://art/fore/dream_post.png")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1931
	var x := 2600.0
	while x < (float(game.level_end) + 3000.0) * 1.35:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.flip_h = rng.randf() < 0.5
		s.modulate = game._undo_night(0.62)   # nearer than the fires, in their shadow - its char and its embers still read
		s.material = game.atmo.blur_material(1.4)   # nearer than the focus: a little soft (more and it is a black stripe)
		s.position.x = x
		game.fore.add_child(s)
		_posts.append(s)
		x += rng.randf_range(3400.0, 5600.0)


func _tick_posts() -> void:
	if not DREAM_POSTS:
		return
	if _posts.is_empty():
		_make_posts()
	var inv: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	var top: float = (inv * Vector2(0.0, 0.0)).y
	var bot: float = (inv * Vector2(0.0, vs.y)).y
	var h: float = (bot - top) * 1.16   # 8 % past the top and the bottom edge, whatever the zoom or the shake
	for s in _posts:
		var sp := s as Sprite2D
		var sc: float = h / sp.texture.get_height()
		sp.scale = Vector2(sc, sc)
		sp.position.y = top - (h - (bot - top)) * 0.5 - game.fore.position.y


var _cinder_t := 2.0
var _guilt_ash := 0.0
## The dream's ash thickens like his guilt (user 18. 11.): thin at the door, thicker the deeper he goes, thicker each time
## it starts over, and thicker still for every man he has shot with his hands up (MenuScript.guilt, 0-10).
func _tick_guilt_ash(delta: float) -> void:
	var prog: float = clampf(game.player.position.x / maxf(1.0, float(game.level_end)), 0.0, 1.0)
	var want: float = clampf(0.22 + 0.45 * prog + 0.12 * _loops + 0.05 * MenuGuilt.guilt(), 0.15, 1.0)
	_guilt_ash = move_toward(_guilt_ash, want, delta * 0.25)   # (slowly: it settles, it does not jump)
	for p in game.atmo.ash:
		(p as CanvasItem).modulate.a = _guilt_ash
	if OS.get_cmdline_user_args().has("--log-sets") and fmod(_t, 5.0) < delta: print("GUILT ASH ", snappedf(_guilt_ash, 0.01), " layers ", game.atmo.ash.size(), " amount ", game.atmo.ash[0].amount if not game.atmo.ash.is_empty() else 0)
## A shower of glowing cinders and charred splinters out of the burning roof (the dream, from its first loop on).
func _cinders(x: float) -> void:
	if OS.get_cmdline_user_args().has("--log-sets"): print("CINDERS ", int(x), " t ", snappedf(_t, 0.05))
	var c := CPUParticles2D.new()
	c.texture = game._soft_glow()
	c.amount = 30 + 12 * mini(_loops, 4)   # (each time round a heavier shower)
	c.lifetime = 1.6
	c.one_shot = true
	c.explosiveness = 0.55
	c.position = Vector2(x, -1150.0)
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	c.emission_rect_extents = Vector2(160.0, 10.0)
	c.direction = Vector2(0.0, 1.0)
	c.spread = 18.0
	c.gravity = Vector2(30.0, 900.0)
	c.initial_velocity_min = 60.0
	c.initial_velocity_max = 220.0
	c.scale_amount_min = 0.06
	c.scale_amount_max = 0.13
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.5, 1.0))
	g.set_color(1, Color(0.9, 0.3, 0.08, 0.0))
	c.color_ramp = g
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	c.material = add
	c.z_index = 4
	add_child(c)
	c.emitting = true
	game.sfx.play("creak", -10.0, x, 0.1)
	for k in 5:   # and a few charred splinters with them
		get_tree().create_timer(randf_range(0.0, 0.5), false).timeout.connect(func() -> void:
			game.fx.chip(Vector2(x + randf_range(-150.0, 150.0), -700.0)))
	get_tree().create_timer(1.9, false).timeout.connect(c.queue_free)


## The dream starts over: a white flash, the same room, worse.
func _loop_again(_ev: Dictionary) -> void:
	var white := ColorRect.new()
	white.color = Color(1.0, 0.97, 0.9, 0.0)
	white.size = Vector2(100000.0, 100000.0)
	white.position = Vector2(-50000.0, -50000.0)
	white.z_index = 50
	add_child(white)
	var tw := white.create_tween()
	tw.tween_property(white, "color:a", 0.85, 0.12)
	tw.tween_property(white, "color:a", 0.0, 1.2)
	tw.tween_callback(white.queue_free)
	game.sfx.play("sting", -4.0, INF, 0.0)
	game.hud.caption(LOOP_LINES[mini(_loops, LOOP_LINES.size() - 1)])
	_loops += 1
	game.atmo.set_dream(0.55 + 0.25 * _loops)   # each time round the page burns worse
	game.atmo.jolt(1.0)


## A knock on the chained doors at the far end: far off at first, louder the nearer he gets.
func _knock(ev: Dictionary) -> void:
	var n: int = ev["n"]
	for k in (2 if n < 10 else 1):
		get_tree().create_timer(0.45 * k, false).timeout.connect(func() -> void:
			game.sfx.play("knock", -16.0 + n * 1.2, INF, 0.05))
