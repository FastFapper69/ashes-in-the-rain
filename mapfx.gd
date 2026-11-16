extends Node2D
## Set pieces that belong to single maps (2026-11-16), each switched on by its map:
##  - the El over Back Streets ("el"): an elevated railway along the kerb; now and then a train goes
##    over, the street shakes and dust comes down, and while it thunders over nobody hears a shot;
##  - the sheets in the laundry (every laundry room): bed sheets on a line in front of the fight, the
##    men behind them only shapes through the cloth; bullets go through and leave holes;
##  - the fog on Pier 17 ("fog"): banks of it roll in off the river, the foghorn sounds, and in it
##    nobody sees far, him or them; the muzzle flashes and the lamps still show through.

var game   # main.gd

# ---- the El ------------------------------------------------------------------------------------
const EL_SCALE := 0.77
const EL_TOP := -1020.0          # the top of the deck: over the second-floor windows, the train on it in the picture
const EL_DECK_H := 270.0         # the deck in the drawing (px of art/props/el_span.png): girders and ties
const EL_TRAIN_SPEED := 2300.0
var _el := false
var _el_t := 9.0                 # seconds to the next train
var _el_loud := 0.0              # seconds the street is too loud to hear a shot in
var _el_told := false
var _el_trains: Array = []       # [root, light]
var _el_span_w := 0.0

# ---- the sheets --------------------------------------------------------------------------------
const SHEET_SCALE := 0.62
var _sheets: Array = []          # {node, rect, img, sway, phase}

# ---- the fog -----------------------------------------------------------------------------------
var _fog := false
var fog := 0.0                   # 0..1 now: main.gd shortens everybody's sight by it
var _fog_phase := 0              # 0 clear, 1 rolling in, 2 thick, 3 thinning
var _fog_t := 6.0


func setup(g) -> void:
	game = g
	_el = bool(game.level.get("el", false))
	_fog = bool(game.level.get("fog", false))
	if _el:
		_build_el()
	for r in game.rooms:
		if String(r[2]) == "laundry":
			_hang_sheets(float(r[0]) + 600.0)
	if _fog:
		game.atmo.set_fog(0.0, Vector2(0.5, 0.75))


func tick(delta: float) -> void:
	if _el:
		_tick_el(delta)
	if not _sheets.is_empty():
		_tick_sheets(delta)
	if _fog:
		_tick_fog(delta)


## How far a shot is heard now (main.gd _alarm): under a train going over, only by the man next to him.
func hearing(radius: float) -> float:
	return 260.0 if _el_loud > 0.0 else radius


# ---- the El ------------------------------------------------------------------------------------

func _build_el() -> void:
	var tex: Texture2D = load("res://art/props/el_span.png")
	var s := EL_SCALE
	_el_span_w = tex.get_width() * s
	var top_h := 560.0   # the deck, its braces and the head of the column
	var shaft := Rect2(118.0, 600.0, 112.0, 160.0)   # a plain stretch of the column, stacked down to the kerb
	var x := -3000.0
	while x < game.level_end + 4000.0:
		var top := Sprite2D.new()
		top.texture = tex
		top.centered = false
		top.region_enabled = true
		top.region_rect = Rect2(0.0, 0.0, tex.get_width(), top_h)
		top.scale = Vector2.ONE * s
		top.position = Vector2(x, EL_TOP)
		_silhouette(top)
		game.fore.add_child(top)
		var y := EL_TOP + top_h * s
		while y < 205.0:
			var piece := Sprite2D.new()
			piece.texture = tex
			piece.centered = false
			piece.region_enabled = true
			piece.region_rect = shaft
			piece.scale = Vector2.ONE * s
			piece.position = Vector2(x + shaft.position.x * s, y)
			_silhouette(piece)
			game.fore.add_child(piece)
			y += shaft.size.y * s - 1.0
		x += _el_span_w - 2.0


func _silhouette(n: CanvasItem) -> void:
	n.modulate = Color(0.1, 0.1, 0.11)   # as near as the lamp posts at the kerb: black against the street
	n.light_mask = game.MASK_UNLIT
	n.material = game.atmo.blur_material(3.0)


func _tick_el(delta: float) -> void:
	_el_loud = maxf(0.0, _el_loud - delta)
	if game.over or game.cleared:
		return
	_el_t -= delta
	if _el_t <= 0.0:
		_el_t = randf_range(24.0, 38.0)
		_el_train()
	var view_w: float = game.get_viewport().get_visible_rect().size.x / game.cam.zoom.x
	var fx_x: float = game.cam.position.x * 0.35   # (the fore layer slides at its own pace)
	for t in _el_trains.duplicate():
		var root: Node2D = t[0]
		root.position.x += float(t[2]) * EL_TRAIN_SPEED * delta
		var mid: float = root.position.x + float(t[3]) * 0.5 - fx_x
		var near: float = 1.0 - clampf(absf(mid - game.cam.position.x) / (view_w * 0.5 + float(t[3]) * 0.5), 0.0, 1.0)
		if near > 0.0:
			game._shake = maxf(game._shake, 0.22 * near)
			_el_loud = maxf(_el_loud, 0.6)
		(t[1] as PointLight2D).position.x = game.cam.position.x + (mid - game.cam.position.x)
		(t[1] as PointLight2D).energy = 0.55 * near * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.03))
		if (float(t[2]) > 0.0 and root.position.x - fx_x > game.cam.position.x + view_w * 1.5) \
				or (float(t[2]) < 0.0 and root.position.x + float(t[3]) - fx_x < game.cam.position.x - view_w * 1.5):
			root.queue_free()
			(t[1] as Node).queue_free()
			_el_trains.erase(t)


func _el_train() -> void:
	var tex: Texture2D = load("res://art/props/subway_car.png")
	var lit: Texture2D = load("res://art/props/subway_car_lit.png")
	var sc := 0.62
	var w: float = tex.get_width() * sc
	var cars := 5
	var length := cars * (w + 18.0)
	var dir := 1.0 if randf() < 0.5 else -1.0
	var view_w: float = game.get_viewport().get_visible_rect().size.x / game.cam.zoom.x
	var fx_x: float = game.cam.position.x * 0.35
	var root := Node2D.new()
	root.position = Vector2(game.cam.position.x + fx_x - view_w * 0.5 - length - 400.0, EL_TOP + 6.0 - tex.get_height() * sc)
	if dir < 0.0:
		root.position.x = game.cam.position.x + fx_x + view_w * 0.5 + 400.0
	game.fore.add_child(root)
	root.z_index = -1   # behind the deck's railing, on the ties
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for k in cars:
		var car := Sprite2D.new()
		car.texture = tex
		car.centered = false
		car.scale = Vector2.ONE * sc
		car.position = Vector2(k * (w + 18.0), 0.0)
		car.modulate = Color(0.12, 0.12, 0.13)
		car.light_mask = game.MASK_UNLIT
		root.add_child(car)
		var glow := Sprite2D.new()   # its lit windows, the only light up there
		glow.texture = lit
		glow.centered = false
		glow.scale = car.scale
		glow.position = car.position
		glow.material = add
		glow.modulate = game._undo_night(0.5)
		root.add_child(glow)
	var grit := CPUParticles2D.new()   # grit and old rain shaken out of the ties onto the street
	grit.texture = load("res://art/fx/spark1.png")
	grit.amount = 60
	grit.lifetime = 1.6
	grit.position = Vector2(length * 0.5, tex.get_height() * sc + EL_DECK_H * EL_SCALE)
	grit.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	grit.emission_rect_extents = Vector2(length * 0.5, 10.0)
	grit.direction = Vector2(0.0, 1.0)
	grit.spread = 8.0
	grit.gravity = Vector2(0.0, 1400.0)
	grit.initial_velocity_min = 40.0
	grit.initial_velocity_max = 160.0
	grit.scale_amount_min = 0.05
	grit.scale_amount_max = 0.12
	grit.color = Color(0.2, 0.19, 0.18, 0.8)
	grit.light_mask = game.MASK_UNLIT
	root.add_child(grit)
	# the light from its windows sweeping along the street under it, through the ties
	var l := PointLight2D.new()
	l.texture = game._soft_glow()
	l.texture_scale = 14.0
	l.color = Color(1.0, 0.85, 0.6)
	l.energy = 0.0
	l.position = Vector2(game.cam.position.x, -500.0)
	l.range_item_cull_mask = game.MASK_LIT
	game.add_child(l)
	_el_trains.append([root, l, dir, length])
	game.sfx.play("el_train", 0.0, INF, 0.03)
	if not _el_told:
		_el_told = true
		game.get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
			game.hud.hint("THE EL GOES OVER: NOBODY HEARS A SHOT."))


# ---- the sheets --------------------------------------------------------------------------------

func _hang_sheets(x: float) -> void:
	var tex: Texture2D = load("res://art/props/sheets.png")
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2.ONE * SHEET_SCALE
	s.position = Vector2(x, -680.0)   # from the pipe under the ceiling down to his knees
	s.z_index = 4   # in front of the men: whoever is behind them is a shape through the cloth
	s.modulate = Color(game._undo_night(0.95), 0.74)
	game.add_child(s)
	var size: Vector2 = tex.get_size() * SHEET_SCALE
	_sheets.append({"node": s, "rect": Rect2(s.position, size), "img": tex.get_image(), "sway": 0.0, "kick": 0.0, "phase": randf() * 10.0})


func _tick_sheets(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var px: float = game.player.position.x
	for sh in _sheets:
		var r: Rect2 = sh["rect"]
		if px > r.position.x and px < r.end.x and absf(game.run) > 200.0:   # he pushes through them
			sh["kick"] = maxf(float(sh["kick"]), 0.5)
		sh["kick"] = move_toward(float(sh["kick"]), 0.0, delta * 0.6)
		var k: float = float(sh["kick"])
		(sh["node"] as Sprite2D).skew = sin(t * 1.1 + float(sh["phase"])) * 0.012 + sin(t * 7.0) * k * 0.05


## A bullet's flight this frame (fx.gd pass_test): where it goes through a sheet, a hole and a flap.
func bullet_pass(b: Dictionary, from: Vector2, to: Vector2) -> void:
	for i in _sheets.size():
		var sh: Dictionary = _sheets[i]
		var r: Rect2 = sh["rect"]
		var key := "sheet%d" % i
		if b.has(key):
			continue
		if maxf(from.x, to.x) < r.position.x or minf(from.x, to.x) > r.end.x:
			continue
		var steps := maxi(1, int(from.distance_to(to) / 12.0))
		for k in steps + 1:
			var p: Vector2 = from.lerp(to, float(k) / steps)
			if not r.has_point(p):
				continue
			var img: Image = sh["img"]
			var u: Vector2 = (p - r.position) / SHEET_SCALE
			var px := Vector2i(clampi(int(u.x), 0, img.get_width() - 1), clampi(int(u.y), 0, img.get_height() - 1))
			if img.get_pixelv(px).a < 0.5:   # between two sheets
				continue
			b[key] = true
			var hole := Sprite2D.new()
			hole.texture = load("res://art/fx/hole%d.png" % (randi() % 2 + 1))
			hole.position = Vector2(u)
			hole.scale = Vector2.ONE * 0.16 / SHEET_SCALE
			hole.rotation = randf() * TAU
			hole.modulate = Color(0.08, 0.07, 0.06, 0.9)
			(sh["node"] as Sprite2D).add_child(hole)
			sh["kick"] = maxf(float(sh["kick"]), 0.35)
			game.sfx.play("cloth", -8.0, p.x, 0.15)
			break


# ---- the fog -----------------------------------------------------------------------------------

func _tick_fog(delta: float) -> void:
	_fog_t -= delta
	if _fog_t <= 0.0:
		_fog_phase = (_fog_phase + 1) % 4
		_fog_t = float([randf_range(14.0, 22.0), 7.0, randf_range(18.0, 26.0), 8.0][_fog_phase])
		if _fog_phase == 1:   # it comes in off the river: the horn first
			game.sfx.play("foghorn", -2.0, INF, 0.03)
	var want: float = [0.0, 1.0, 1.0, 0.0][_fog_phase]
	var rate := 1.0 / 7.0 if _fog_phase == 1 else (1.0 / 8.0 if _fog_phase == 3 else 0.5)
	fog = move_toward(fog, want, delta * rate)
	var vp: Vector2 = game.get_viewport().get_visible_rect().size
	var sp: Vector2 = game.get_viewport().get_canvas_transform() * (game.player.position + Vector2(0.0, -220.0))
	game.atmo.set_fog(fog, sp / vp)
