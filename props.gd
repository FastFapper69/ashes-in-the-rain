extends Node2D
## The street kit's things to play with (gen/kit.py -> kit.gd: which piece has what, where; this file: how each
## KIND looks and behaves). Each thing is cut out of its street drawing (gen/street_props.py) and stood a little in
## front of the wall: it slides against the facade as the camera moves (parallax), casts a shadow on the wall and a
## contact pool on the stones, so it reads 3D in 2D (user 16. 11.).
##
## A new kind: a line in gen/kit.py KINDS + a `_shot_<kind>` (or floor behaviour) here. main.gd only calls
## build(), place(), tick(), shot(), landed_on() and near_climb(). A thing not cut out of a street drawing (the docks'
## windlass...) is placed free-standing on the street by the level (levels "things": place()).

const Kit = preload("res://kit.gd")
var game   # main.gd
var items: Array = []   # {kind, node, shadow, base, sbase, rect (world), used, depth}


## For one street drawing placed in the world (its sprite w, scale ws * sx, the left trim): its things.
func build(art: String, w: Sprite2D, ws: float, sx: float, trim: float) -> void:
	var piece: Dictionary = Kit.PIECES.get(art, {})
	for pr in piece.get("props", []):
		var kind := String(pr["kind"])
		var box: Array = pr["box"]
		var tex: Texture2D = load("res://art/props/hk_%s.png" % kind)
		var bw := (float(box[2]) - float(box[0])) * ws * sx
		var k := bw / tex.get_width()
		var h := tex.get_height() * k
		var x := w.position.x + (float(box[0]) - trim) * ws * sx
		var y_foot := w.position.y + float(box[3]) * ws
		var top: float = w.position.y + float(box[1]) * ws if String(pr["anchor"]) == "top" else y_foot - h
		_add(kind, tex, x, top, bw, k, y_foot if String(pr["anchor"]) == "foot" else NAN, w.material, w.modulate, w.light_mask)


## A free-standing thing on the street (levels "things"): its foot on the stones at x (its left edge), as wide as THING_W
## says, toned like the drawings behind it (the facade's material and moonlit wash).
const THING_W := {"windlass": 520.0, "trolley": 960.0, "thirdrail": 1300.0}
func place(kind: String, x: float, like: Sprite2D) -> void:
	var tex: Texture2D = load("res://art/props/hk_%s.png" % kind)
	var bw: float = THING_W.get(kind, 400.0)
	var k := bw / tex.get_width()
	_add(kind, tex, x, -tex.get_height() * k, bw, k, 0.0, like.material if like else null,
			Color.WHITE * float(game.SEGMENT_MOON) * 0.9 if like == null else like.modulate, like.light_mask if like else 1)
	if kind == "trolley":   # the overhead wire goes on from where the drawing cuts it, to a rosette on the next wall
		var p: Dictionary = items[items.size() - 1]
		var a := _cell_point(p, TROLLEY_WIRE)
		var wire := Line2D.new()
		var b := a + Vector2(1300.0, -60.0)
		wire.points = PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0.0, 26.0), b])
		wire.width = 6.0
		wire.default_color = Color(0.06, 0.06, 0.07)
		wire.z_index = -8
		add_child(wire)
		var rosette := Sprite2D.new()
		rosette.texture = game._soft_glow()
		rosette.scale = Vector2.ONE * 0.22
		rosette.position = b
		rosette.modulate = Color(0, 0, 0, 0.95)
		rosette.z_index = -8
		add_child(rosette)


## A point of a thing's drawn animation cell (shares of the cell) in the world, where the cell sits over its still.
const TROLLEY_WIRE := Vector2(0.81, 0.263)   # where the drawing cuts the trolley wire (gen/street_props.py WIRE_CUT)
func _cell_point(p: Dictionary, at: Vector2) -> Vector2:
	var tex: Texture2D = load("res://art/props/hk_%s_anim.png" % String(p["kind"]))
	var cw := tex.get_width() / 6.0
	var ch := float(tex.get_height())
	var r: Rect2 = p["rect"]
	var k: float = r.size.x / (cw * float(ANIM_W.get(String(p["kind"]), 1.0)))
	var o := Vector2(r.position.x - cw * k * float(ANIM_X0.get(p["kind"], 0.0)), r.end.y - ch * k * (1.0 - float(ANIM_GAP.get(p["kind"], 0.0))))
	return o + at * Vector2(cw * k, ch * k)


func _add(kind: String, tex: Texture2D, x: float, top: float, bw: float, k: float, y_foot: float, mat: Material, tone: Color, lmask: int) -> void:
	var h := tex.get_height() * k
	var shadow := Sprite2D.new()   # on the wall and the stones behind it
	shadow.texture = tex
	shadow.centered = false
	shadow.scale = Vector2(k, k * 0.97)
	shadow.position = Vector2(x + 16.0, top + 14.0)
	shadow.modulate = Color(0, 0, 0, 0.42)
	shadow.z_index = -9
	shadow.light_mask = 0
	add_child(shadow)
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.scale = Vector2.ONE * k
	sp.position = Vector2(x, top)
	sp.material = mat
	sp.modulate = tone
	sp.z_index = -8
	sp.light_mask = lmask
	add_child(sp)
	if not is_nan(y_foot):   # where it stands: a dark contact pool on the stones
		var pool := Sprite2D.new()
		pool.texture = game._soft_glow()
		pool.scale = Vector2(bw / 90.0, 0.35)
		pool.position = Vector2(x + bw * 0.5, y_foot + 4.0)
		pool.modulate = Color(0, 0, 0, 0.55)
		pool.z_index = -9
		add_child(pool)
	items.append({"kind": kind, "node": sp, "shadow": shadow, "base": sp.position, "sbase": shadow.position,
			"rect": Rect2(x, top, bw, h), "used": false, "depth": float(Kit.KINDS[kind]["depth"])})


func tick(_delta: float) -> void:
	var cx: float = game.cam.position.x
	for p in items:
		var sp: Sprite2D = p["node"]
		if not is_instance_valid(sp):
			continue
		var base: Vector2 = p["base"]
		var off := clampf((base.x + (p["rect"] as Rect2).size.x * 0.5 - cx) * float(p["depth"]), -60.0, 60.0)
		sp.position.x = base.x + off
		(p["shadow"] as Sprite2D).position.x = float((p["sbase"] as Vector2).x) + off * 0.5


## Near something climbed in a street piece (an awning and the fire escape beside it): the camera rises with him.
func near_climb(x: float) -> bool:
	for p in items:
		if String(p["kind"]) == "awning" and x > (p["rect"] as Rect2).position.x - 600.0 and x < (p["rect"] as Rect2).end.x + 1500.0:
			return true
	return false


## Frank's bullet at pos: true if it set one of them off.
func shot(pos: Vector2) -> bool:
	for p in items:
		if p["used"] or not bool(Kit.KINDS[String(p["kind"])]["shot"]) or not (p["rect"] as Rect2).grow(10.0).has_point(pos):
			continue
		p["used"] = true
		call("_shot_" + String(p["kind"]), p, pos)
		return true
	return false


## A man falling onto one of the floors at pos: the thing gives under him (an awning's canvas sags and springs).
func landed_on(pos: Vector2) -> void:
	for p in items:
		if String(p["kind"]) == "awning" and (p["rect"] as Rect2).grow(40.0).has_point(pos + Vector2(0.0, 20.0)):
			var aw: Sprite2D = p["node"]
			var sy := aw.scale.y
			var tw := aw.create_tween()
			tw.tween_property(aw, "scale:y", sy * 0.86, 0.07)
			tw.tween_property(aw, "scale:y", sy * 1.05, 0.12)
			tw.tween_property(aw, "scale:y", sy, 0.2)


## Play a kind's drawn animation (art/props/hk_<kind>_anim.png, 6 equal cells, gen/street_props.py) over the thing:
## (cells 0-2 the hit, `loop` repeated for `hold` seconds, 4-5 the end) - the strip's cells are scaled so the thing in them matches the thing on the street (its width share ANIM_W), the
## foot on the same line; `hold` (seconds) on the given loop cells, then it ends on the last cell and stays there.
const ANIM_W := {"hydrant": 0.5, "kegs": 0.849, "steampipe": 0.9359, "windlass": 0.869, "trolley": 0.902, "thirdrail": 0.925}   # the thing's width in a cell, as a share of the cell
const ANIM_X0 := {"kegs": 0.112, "steampipe": 0.019, "windlass": 0.061, "trolley": 0.054, "thirdrail": 0.05}   # where the thing starts in a cell (its still IS the first cell, cropped); else centred
const ANIM_GAP := {"windlass": 0.055, "thirdrail": 0.052}   # empty cell below its foot, as a share of the cell's height (gen/street_props.py still())
func _animate(p: Dictionary, loop: Array, hold: float) -> bool:
	var path := "res://art/props/hk_%s_anim.png" % String(p["kind"])
	if not ResourceLoader.exists(path):
		return false
	var tex: Texture2D = load(path)
	var cw := tex.get_width() / 6.0
	var ch := float(tex.get_height())
	var r: Rect2 = p["rect"]
	var k: float = r.size.x / (cw * float(ANIM_W.get(String(p["kind"]), 1.0)))
	var sp: Sprite2D = p["node"]
	sp.texture = tex
	sp.region_enabled = true
	sp.scale = Vector2.ONE * k
	var x0: float = r.position.x - cw * k * float(ANIM_X0[p["kind"]]) if ANIM_X0.has(p["kind"]) else r.get_center().x - cw * k * 0.5
	sp.position = Vector2(x0, r.end.y - ch * k * (1.0 - float(ANIM_GAP.get(p["kind"], 0.0))))
	p["base"] = sp.position
	(p["shadow"] as Sprite2D).visible = false
	var tw := sp.create_tween()
	for f in [0, 1, 2]:
		tw.tween_callback(func() -> void: sp.region_rect = Rect2(cw * f, 0.0, cw, ch))
		tw.tween_interval(0.09)
	var loops := int(hold / (0.12 * loop.size())) if loop.size() > 0 else 0
	for i in loops:
		for f in loop:
			tw.tween_callback(func() -> void: sp.region_rect = Rect2(cw * f, 0.0, cw, ch))
			tw.tween_interval(0.12)
	for f in [4, 5]:
		tw.tween_callback(func() -> void: sp.region_rect = Rect2(cw * f, 0.0, cw, ch))
		tw.tween_interval(0.14)
	return true


# ---- the kinds -----------------------------------------------------------------------------------------------
func _foot(p: Dictionary) -> Vector2:
	var r: Rect2 = p["rect"]
	return Vector2(r.get_center().x, r.end.y)


## The cap blows off and a column of water knocks down whoever is by it.
func _shot_hydrant(p: Dictionary, _pos: Vector2) -> void:
	var foot := _foot(p)
	var r: Rect2 = p["rect"]
	game._impact(0.08, 0.05)
	game._word(["clink", "smash"], foot + Vector2(0.0, -r.size.y - 120.0), 0.2, Vector2.UP)
	game.sfx.play("water", 4.0, foot.x, 0.05)
	_animate(p, [2, 3], 4.0)   # the drawn column (6 frames), held 4 s, ending on the broken hydrant
	var jet := CPUParticles2D.new()   # spray on top of the drawn column, falling back
	jet.position = foot + Vector2(0.0, -r.size.y * 3.2)
	jet.amount = 60
	jet.lifetime = 1.1
	jet.direction = Vector2.UP
	jet.spread = 70.0
	jet.initial_velocity_min = 300.0
	jet.initial_velocity_max = 700.0
	jet.gravity = Vector2(0.0, 2600.0)
	jet.scale_amount_min = 3.0
	jet.scale_amount_max = 7.0
	jet.color = Color(0.82, 0.88, 0.95, 0.75) * Color(game._undo_night(1.0), 1.0)
	jet.z_index = 2
	add_child(jet)
	get_tree().create_timer(5.0, false).timeout.connect(func() -> void:
		jet.emitting = false
		get_tree().create_timer(1.5, false).timeout.connect(jet.queue_free))
	_knock_round(foot, 420.0, 700.0)


## The barrels burst, beer foams over the stones and the man behind them goes off his feet.
func _shot_kegs(p: Dictionary, pos: Vector2) -> void:
	var foot := _foot(p)
	var r: Rect2 = p["rect"]
	game._impact(0.1, 0.04)
	game._word(["crash", "smash"], foot + Vector2(0.0, -r.size.y - 100.0), 0.22, Vector2.UP)
	game.sfx.play("wood_break", 2.0, foot.x, 0.05)
	var drawn := _animate(p, [], 0.0)   # the drawn burst: hit, staves and foam, the top barrel falls, the wreck in its puddle
	if not drawn:
		game.fx.break_apart(p["node"], pos, foot.y)
	(p["shadow"] as Sprite2D).visible = false
	for i in 3 if drawn else 14:   # (a little dust only: the foam is in the drawing, smoke would hide it)
		game.fx.smoke(foot + Vector2(randf_range(-r.size.x * 0.4, r.size.x * 0.4), -randf_range(10.0, r.size.y * 0.6)),
				Vector2(randf_range(-260.0, 260.0), randf_range(-160.0, 40.0)), randf_range(0.25, 0.4), randf_range(0.6, 1.1), 0.55)
	_knock_round(foot, 360.0, 800.0)


## The pipe bursts: a white cloud the men by it cannot see out of for a few seconds.
func _shot_steampipe(p: Dictionary, pos: Vector2) -> void:
	var foot := _foot(p)
	game._impact(0.06, 0.06)
	game.sfx.play("steam", 4.0, foot.x, 0.05)
	var r: Rect2 = p["rect"]
	var valve := r.position + r.size * Vector2(0.59, 0.74)   # the valve wheel: it snaps off and the steam comes out of its stem
	if not _animate(p, [3, 4], 3.0):
		var wheel := CPUParticles2D.new()
		wheel.position = valve
		wheel.amount = 90
		wheel.lifetime = 1.4
		wheel.direction = Vector2.UP
		wheel.spread = 14.0
		wheel.initial_velocity_min = 500.0
		wheel.initial_velocity_max = 900.0
		wheel.gravity = Vector2(0.0, -120.0)
		wheel.damping_min = 120.0
		wheel.damping_max = 200.0
		wheel.scale_amount_min = 10.0
		wheel.scale_amount_max = 26.0
		wheel.color = Color(0.92, 0.92, 0.94, 0.55) * Color(game._undo_night(1.0), 1.0)
		wheel.z_index = 2
		add_child(wheel)
		get_tree().create_timer(3.5, false).timeout.connect(func() -> void:
			wheel.emitting = false
			get_tree().create_timer(1.6, false).timeout.connect(wheel.queue_free))
	for e in game.enemies:
		if e["alive"] and absf(float(e["node"].position.x) - pos.x) < 520.0 and absf(float(e["node"].position.y) - foot.y) < 120.0:
			e["cool"] = maxf(float(e["cool"]), 3.2)
			game._mark(e["node"], "?")


## The brake snaps, the drum spins and the anchor chain lashes out along the quay to the right: whoever stands
## in its sweep goes down (ch II hazard, user's stunt list).
func _shot_windlass(p: Dictionary, _pos: Vector2) -> void:
	var foot := _foot(p)
	var r: Rect2 = p["rect"]
	game._impact(0.1, 0.05)
	game._word(["kachak", "wham"], foot + Vector2(0.0, -r.size.y - 110.0), 0.2, Vector2.UP)
	game.sfx.play("chain", 3.0, foot.x, 0.05)
	if not _animate(p, [], 0.0):
		game.fx.break_apart(p["node"], foot, foot.y)
	(p["shadow"] as Sprite2D).visible = false
	get_tree().create_timer(0.25, false).timeout.connect(func() -> void:   # the lash lands
		game.fx.dust(foot + Vector2(r.size.x * 0.7, 0.0), 0.5)
		for e in game.enemies:
			var dx: float = e["node"].position.x - foot.x
			if e["alive"] and dx > -160.0 and dx < 700.0 and absf(float(e["node"].position.y) - foot.y) < 120.0 and String(e["state"]) in ["post", "run", "move", "hop"]:
				game._knock_down(e, 750.0))


## The insulator shatters, the live wire drops into the puddle at the pole's foot: arcs over the water for two
## seconds, and whoever stands in it is done for (ch III hazard: "trolley wire in a puddle").
const TROLLEY_PUDDLE := Vector2(0.3, 0.97)   # the puddle's left and right ends, shares of the cell
func _shot_trolley(p: Dictionary, _pos: Vector2) -> void:
	var foot := _foot(p)
	var r: Rect2 = p["rect"]
	game._impact(0.08, 0.05)
	game._word(["crack", "zing"], _cell_point(p, TROLLEY_WIRE) + Vector2(-80.0, -60.0), 0.18)
	game.sfx.play("glass", -2.0, foot.x, 0.05)
	if not _animate(p, [3, 4], 2.0):
		return
	(p["shadow"] as Sprite2D).visible = false
	var x0 := _cell_point(p, Vector2(TROLLEY_PUDDLE.x, 1.0)).x
	var x1 := _cell_point(p, Vector2(TROLLEY_PUDDLE.y, 1.0)).x
	for i in 9:   # live: every quarter second while the arcs run
		get_tree().create_timer(0.27 + i * 0.25, false).timeout.connect(func() -> void:
			game.sfx.play("zap", -4.0, (x0 + x1) * 0.5, 0.2)
			for e in game.enemies:
				var ex: float = e["node"].position.x
				if e["alive"] and ex > x0 - 40.0 and ex < x1 + 40.0 and absf(float(e["node"].position.y) - foot.y) < 60.0:
					game._kill(e, false))


## The junction box by the tracks bursts: the third rail arcs along its whole length for two seconds and whoever
## stands on the track bed beside it is done for (ch III hazard, the stunt list's "third rail").
const RAIL_SPAN := Vector2(0.2, 0.97)   # the live rail's ends, shares of the cell (the box stands left of it)
func _shot_thirdrail(p: Dictionary, _pos: Vector2) -> void:
	var foot := _foot(p)
	game._impact(0.1, 0.06)
	game._word(["crack", "zing"], _cell_point(p, Vector2(0.08, 0.1)) + Vector2(0.0, -80.0), 0.18)
	game.sfx.play("zap", 2.0, foot.x, 0.1)
	if not _animate(p, [2, 3], 2.0):
		return
	(p["shadow"] as Sprite2D).visible = false
	var x0 := _cell_point(p, Vector2(RAIL_SPAN.x, 1.0)).x
	var x1 := _cell_point(p, Vector2(RAIL_SPAN.y, 1.0)).x
	for i in 9:
		get_tree().create_timer(0.27 + i * 0.25, false).timeout.connect(func() -> void:
			game.sfx.play("zap", -4.0, (x0 + x1) * 0.5, 0.2)
			for e in game.enemies:
				var ex: float = e["node"].position.x
				if e["alive"] and ex > x0 - 40.0 and ex < x1 + 40.0 and absf(float(e["node"].position.y) - foot.y) < 60.0:
					game._kill(e, false))


func _knock_round(at: Vector2, reach: float, push: float) -> void:
	for e in game.enemies:
		var dx: float = e["node"].position.x - at.x
		if e["alive"] and absf(dx) < reach and absf(float(e["node"].position.y) - at.y) < 120.0 and String(e["state"]) in ["post", "run", "move", "hop"]:
			game._knock_down(e, signf(dx) * push)
