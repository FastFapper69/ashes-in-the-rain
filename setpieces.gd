extends Node2D
## The things that happen to a street while Frank fights along it, so no two stretches play alike:
## a car of reinforcements pulling up hard, the power going out, a searchlight sweeping the yard, a
## warehouse burning, a crate on a crane's chains waiting to be shot down onto whoever stands under it.
## The map lists them (level["events"]); main.gd ticks them and asks them about bullets and light.

const CAR_W := 1000.0
const CAR_COVER_H := 190.0
# where the windows burn on a drawing that is set on fire: fractions of the (trimmed) picture
const FIRES := {"shipping": [Vector2(0.06, 0.1), Vector2(0.17, 0.1), Vector2(0.37, 0.1), Vector2(0.06, 0.24), Vector2(0.17, 0.24),
		Vector2(0.37, 0.24), Vector2(0.43, 0.24), Vector2(0.06, 0.46), Vector2(0.43, 0.46), Vector2(0.1, 0.62), Vector2(0.3, 0.62)],
	"pier17": [Vector2(0.14, 0.34), Vector2(0.25, 0.34), Vector2(0.36, 0.34), Vector2(0.2, 0.68)]}

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
var _fire_tex: Texture2D
var _t := 0.0


func setup(main) -> void:
	game = main
	_fire_tex = _make_flame()
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
	if _speed > 0.0 and _band != null:
		_tick_moving(delta)
	if _blackout_t > 0.0:
		_blackout_t -= delta
		if _blackout_t <= 0.0:
			_lights_back()
	for b in _beams:
		var a: float = b["base"] + sin(_t * b["speed"] + b["phase"]) * b["swing"]
		b["angle"] = a
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
		var d: Vector2 = p - b["pivot"]
		if d.length() > b["len"]:
			continue
		var off := absf(angle_difference(d.angle() - PI * 0.5, b["angle"]))
		if off < b["half"]:
			return true
	return false


## Kessler's smoke: a grey wall rolling out over the quay for a few seconds.
func smoke(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = _fire_tex
	p.amount = 60
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
	p.scale_amount_min = 6.0
	p.scale_amount_max = 11.0
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.57, 0.55, 0.0))
	g.add_point(0.12, Color(0.5, 0.52, 0.5, 0.8))
	g.add_point(0.7, Color(0.42, 0.44, 0.43, 0.6))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.4, 0.4, 0.0))
	p.color_ramp = g
	p.modulate = game._undo_night(0.35)
	p.z_index = 4
	add_child(p)
	game.sfx.play("slow_out", -4.0, at.x, 0.1)   # the hiss of the canister
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
	car.scale = Vector2.ONE * 1.12
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
		var cover := Rect2(stop - CAR_W * 0.42, -CAR_COVER_H, CAR_W * 0.84, CAR_COVER_H)
		if not cover.has_point(game.player.position + Vector2(0.0, -40.0)):
			game.boxes.append(cover)   # steel to hide behind, for them or for him
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

func _add_beam(pivot: Vector2, base_deg: float) -> void:
	var ln := 2300.0
	var s := Sprite2D.new()
	s.texture = load("res://art/light_cone_soft.png")
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
	var pole := Line2D.new()   # an iron mast down to the quay, and the lamp's drum on top of it
	pole.points = PackedVector2Array([pivot + Vector2(0.0, 30.0), Vector2(pivot.x, 0.0)])
	pole.width = 16.0
	pole.default_color = Color(0.05, 0.05, 0.06)
	pole.z_index = -4
	add_child(pole)
	var drum := Line2D.new()
	drum.points = PackedVector2Array([pivot + Vector2(-34.0, -10.0), pivot + Vector2(34.0, -10.0)])
	drum.width = 52.0
	drum.default_color = Color(0.07, 0.07, 0.08)
	drum.z_index = 2
	add_child(drum)
	var head := Sprite2D.new()   # the lens, burning white
	head.texture = load("res://art/light_blob.png")
	head.position = pivot + Vector2(0.0, 10.0)
	head.scale = Vector2.ONE * 0.3
	head.material = add
	head.modulate = Color(1.0, 1.0, 0.95, 0.9)
	head.z_index = 2
	add_child(head)
	var l := PointLight2D.new()
	l.texture = load("res://art/light_cone.png")
	l.texture_scale = ln / 512.0
	l.color = Color(0.8, 0.88, 1.0)
	l.energy = 1.1
	l.range_item_cull_mask = game.MASK_LIT
	add_child(l)
	var half := atan2(256.0 * 1.15 * 0.45, ln)   # the bright core of the cone, not its soft edge
	_beams.append({"sprite": s, "light": l, "pivot": pivot, "base": deg_to_rad(base_deg), "swing": deg_to_rad(32.0),
			"speed": 0.42, "phase": randf() * TAU, "len": ln, "half": half, "angle": 0.0})
	game.sfx.add_loop("lamp_hum", pivot.x, -22.0, 600.0, pivot.y)


# ---- fire --------------------------------------------------------------------------------------

## A drawing's windows on fire: flames licking out and up, smoke, sparks, an orange light that will
## not hold still, and the roar of it.
func _burn(seg_name: String) -> void:
	for seg in game.level.get("street", []):
		if String(seg[0]) != seg_name:
			continue
		var tex: Texture2D = load("res://art/street/%s.png" % seg_name)
		var w: float = tex.get_width() * game.WALL_SCALE
		var h: float = tex.get_height() * game.WALL_SCALE
		var top: float = -h * game.SEGMENT_BASE - game.WALL_LIFT
		var x0 := float(seg[1])
		var trim: float = game.SEGMENT_TRIM.get(seg_name, 0.0)
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
			_flames(Vector2(x0 + (f.x * tex.get_width() - trim) * sx * game.WALL_SCALE, top + h * f.y))
		game.sfx.add_loop("fire", x0 + w * 0.27, -4.0, 1600.0, top + h * 0.4)
		return


func _flames(at: Vector2) -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var glow := Sprite2D.new()   # the room behind the window, burning
	glow.texture = load("res://art/light_blob.png")
	glow.position = at
	glow.scale = Vector2(1.3, 1.0)
	glow.material = add
	glow.modulate = Color(1.0, 0.3, 0.05, 0.6) * Color(game._undo_night(0.3), 1.0)
	glow.z_index = -8
	add_child(glow)
	var gt := glow.create_tween().set_loops()
	for k in 5:
		gt.tween_property(glow, "modulate:a", randf_range(0.3, 0.7), randf_range(0.05, 0.16))
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/flame.png")
	p.amount = 40
	p.lifetime = 0.75
	p.preprocess = 1.0
	p.position = at + Vector2(0.0, 20.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(55.0, 14.0)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 10.0
	p.gravity = Vector2(25.0, -380.0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.6))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1.0, 0.15))
	p.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	g.add_point(0.25, Color(1.0, 0.5, 0.08, 0.9))
	g.add_point(0.65, Color(0.75, 0.15, 0.03, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.3, 0.05, 0.02, 0.0))
	p.color_ramp = g
	p.material = add
	p.modulate = game._undo_night(0.32)   # fire makes its own light: the night does not dim it
	p.z_index = -8
	add_child(p)
	var smoke := CPUParticles2D.new()   # black smoke rolling off the top of each window
	smoke.texture = _fire_tex
	smoke.amount = 14
	smoke.lifetime = 3.5
	smoke.preprocess = 3.0
	smoke.position = at + Vector2(0.0, -90.0)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(60.0, 10.0)
	smoke.direction = Vector2(0.15, -1.0)
	smoke.spread = 20.0
	smoke.gravity = Vector2(40.0, -60.0)
	smoke.initial_velocity_min = 60.0
	smoke.initial_velocity_max = 120.0
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 5.5
	var sg := Gradient.new()
	sg.set_color(0, Color(0.08, 0.07, 0.07, 0.0))
	sg.add_point(0.15, Color(0.08, 0.07, 0.07, 0.55))
	sg.set_color(sg.get_point_count() - 1, Color(0.1, 0.1, 0.11, 0.0))
	smoke.color_ramp = sg
	smoke.z_index = -8
	add_child(smoke)


func _make_flame() -> Texture2D:
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 64
	g.height = 64
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	g.gradient = gr
	return g


# ---- the crate on the crane --------------------------------------------------------------------

## The crate hanging from the crane in the drawing is taken out of it and hung here instead, over the
## street, where a shot through its chains brings it down on whoever is under it.
func _add_crate(seg_x: float) -> void:
	var tex: Texture2D = load("res://art/props/cranes_cut.png")
	var street: Texture2D = load("res://art/street/cranes.png")
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
	root.position = Vector2(game.cam.position.x + 3200.0, -tex.get_height() * sc + 10.0)
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


## The last train: the tunnel wall pours past behind the cars, which carry the fight on their roofs.
func _make_band() -> void:
	var tex: Texture2D = load("res://art/street/tunnel.png")
	var lit: Texture2D = load("res://art/street/tunnel_lit.png")
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
	for i in 5:
		var w := Sprite2D.new()
		w.texture = tex
		w.centered = false
		w.region_enabled = true
		w.region_rect = Rect2(trim, 0.0, tex.get_width() - trim, tex.get_height())
		w.scale = Vector2(game.WALL_SCALE * sx, game.WALL_SCALE)
		w.position = Vector2((i - 2) * _band_w, 0.0)
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
	_band.position = Vector2(-fposmod(cam_x + _t * _speed, _band_w), _band_top - game.cam.position.y)
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
	if _beam_t <= 0.0:
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
					game._bullet_hit(Vector2(px, y), false)
					game._shake = 0.5
					game.sfx.play("body_fall", 0.0, px, 0.05)
					break
		bl[1] = b.position.x
		if b.position.x < cam_x - view.x:
			b.queue_free()
			_beams_live.erase(bl)


## A steel girder hanging low across the tunnel, its riveted face and the strut up to the roof.
func _girder() -> Node2D:
	var n := Node2D.new()
	n.z_index = 6
	var strut := Polygon2D.new()
	strut.polygon = PackedVector2Array([Vector2(-30, -2400), Vector2(30, -2400), Vector2(30, -470), Vector2(-30, -470)])
	strut.color = Color(0.05, 0.05, 0.06)
	n.add_child(strut)
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(-70, -480), Vector2(70, -480), Vector2(70, -330), Vector2(-70, -330)])
	beam.color = Color(0.09, 0.09, 0.1)
	n.add_child(beam)
	var lip := Line2D.new()
	lip.points = PackedVector2Array([Vector2(-70, -470), Vector2(70, -470)])
	lip.width = 8.0
	lip.default_color = Color(0.22, 0.22, 0.25)
	n.add_child(lip)
	return n
