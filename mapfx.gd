extends Node2D
## Set pieces that belong to single maps (2026-11-16), each switched on by its map:
##  - the El over Back Streets ("el"): an elevated railway along the kerb; now and then a train goes
##    over, the street shakes and dust comes down, and while it thunders over nobody hears a shot;
##  - the sheets in the laundry (every laundry room): bed sheets on a line in front of the fight, the
##    men behind them only shapes through the cloth; bullets go through and leave holes;
##  - the fog on Pier 17 ("fog"): banks of it roll in off the river, the foghorn sounds, and in it
##    nobody sees far, him or them; the muzzle flashes and the lamps still show through.

##  - the storm over the Tenements ("storm"): lightning close overhead every few seconds, the thunder
##    on top of it, and in the flash every man waiting in the dark stands out white for a moment;
##  - the ship ("rock"): the Santa Lucia rides the swell, the whole picture leans slowly and the hull
##    groans;
##  - the steam in the Tunnels ("steam"): old pipes burst overhead, a white cloud nobody sees through;
##    and rats ("rats"): a few run at him out of the dark a moment before the men there show;
##  - the hotel sign in the Alley ("neon_drop"): a neon HOTEL over the men; shoot its chains and it
##    comes down on them in a shower of glass and sparks;
##  - the freight in the Train Yard ("freight"): a long freight drags through on the far track, and
##    while it bangs past nobody hears a shot;
##  - the storm on the harbor ("sea"): the lightning, and waves breaking over the quay, the spray
##    knocking the men off their aim and him off his feet for a moment;
##  - the water in the Catacombs ("flood"): it rises the longer he stays, and wading slows everybody.

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


# ---- the storm, the ship, the steam ------------------------------------------------------------
var _storm := false
var _rock := false
var _steam := false
var _storm_t := 7.0
var _flash_seen := 0.0
var _rock_t := 0.0
var _creak_t := 4.0
var _steam_t := 10.0


var _rats := false
var _rat_cool := 0.0
var _rat_seen: Dictionary = {}
var _neon: Dictionary = {}
var _freight := false
var _freight_t := 12.0
var _sea := false
var _wave_t := 9.0
var _flood := false
var flood := 0.0                 # how high the water stands (px above the floor); main.gd slows by it
var _flood_t := 0.0
var _water: Array = []


func setup(g) -> void:
	game = g
	_el = bool(game.level.get("el", false))
	_fog = bool(game.level.get("fog", false))
	_storm = bool(game.level.get("storm", false))
	_rock = bool(game.level.get("rock", false))
	_steam = bool(game.level.get("steam", false))
	if _rock:
		game.cam.ignore_rotation = false
	_rats = bool(game.level.get("rats", false))
	_freight = bool(game.level.get("freight", false))
	_sea = bool(game.level.get("sea", false))
	_flood = bool(game.level.get("flood", false))
	if _sea:
		_storm = true
	if bool(game.level.get("neon_drop", false)):
		_hang_neon.call_deferred()
	if _flood:
		_lay_water()
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
	if _storm:
		_tick_storm(delta)
	if _rock:
		_tick_rock(delta)
	if _steam:
		_tick_steam(delta)
	if _rats:
		_tick_rats(delta)
	if not _neon.is_empty():
		_tick_neon(delta)
	if _freight:
		_tick_freight(delta)
	if _sea:
		_tick_sea(delta)
	if _flood:
		_tick_flood(delta)


## How far a shot is heard now (main.gd _alarm): under a train going over, only by the man next to him.
func hearing(radius: float) -> float:
	return 260.0 if _el_loud > 0.0 else radius   # (the freight in the yard sets _el_loud too)


# ---- the El ------------------------------------------------------------------------------------

func _build_el() -> void:
	var tex: Texture2D = load("res://art/props/el_span.png")
	var s := EL_SCALE
	_el_span_w = tex.get_width() * s
	var top_h := 560.0   # the deck, its braces and the head of the column
	var shaft := Rect2(118.0, 600.0, 112.0, 160.0)   # a plain stretch of the column, stacked down to the kerb
	var x := -3000.0
	# the fore layer slides at 0.35 of the camera: to reach the map's end its pieces must run 1.35x as far
	while x < (game.level_end + 3000.0) * 1.35:
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


# ---- the storm ---------------------------------------------------------------------------------

func _tick_storm(delta: float) -> void:
	_storm_t -= delta
	if _storm_t <= 0.0 and not game.over:
		_storm_t = randf_range(9.0, 16.0)
		game._lightning_t = 0.0   # main.gd's own lightning, only close and often
		get_tree().create_timer(0.25, false).timeout.connect(func() -> void:
			game.sfx.play("thunder", 2.0, INF, 0.1)
			game._shake = maxf(game._shake, 0.18))
		game._lightning_t = 0.0
	if game._flash > 0.8 and _flash_seen <= 0.8:   # the brightest flicker: everyone in the dark shows
		for e in game.enemies:
			if not e["alive"] or not e["node"].visible:
				continue
			var n: CanvasItem = e["node"]
			if absf(n.position.x - game.player.position.x) < 2600.0:
				var was: Color = n.get_meta("lit_was", n.modulate)
				n.set_meta("lit_was", was)
				var tw := n.create_tween()
				tw.tween_property(n, "modulate", Color(2.6, 2.6, 2.8, was.a), 0.04)
				tw.tween_property(n, "modulate", was, 0.45)
	_flash_seen = game._flash


# ---- the ship ----------------------------------------------------------------------------------

func _tick_rock(delta: float) -> void:
	_rock_t += delta
	# a long slow swell with a shorter one on top: never the same lean twice
	game.cam.rotation = sin(_rock_t * 0.42) * 0.018 + sin(_rock_t * 1.13 + 1.7) * 0.006
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(5.0, 9.0)
		game.sfx.play("creak", -6.0, INF, 0.2)


# ---- the steam ---------------------------------------------------------------------------------

func _tick_steam(delta: float) -> void:
	_steam_t -= delta
	if _steam_t > 0.0 or game.over or game.cleared:
		return
	_steam_t = randf_range(11.0, 18.0)
	# a pipe goes somewhere ahead of him, between him and the next men: a white wall for a few seconds
	var px: float = game.player.position.x
	var ahead := INF
	for e in game.enemies:
		if e["alive"] and e["node"].visible and e["node"].position.x > px + 300.0:
			ahead = minf(ahead, e["node"].position.x)
	if ahead == INF:
		return
	var at := Vector2(lerpf(px, ahead, 0.55), 0.0)
	game.sets.smoke(at, true)
	game.fx.spark(at + Vector2(0.0, -900.0))


## A shot of his in flight (main.gd _bullet_hits): true if it hit something of these.
func bullet(pos: Vector2) -> bool:
	if _neon.is_empty() or _neon["state"] != "hang":
		return false
	if (_neon["chains"] as Rect2).has_point(pos):
		_neon_drop()
		return true
	if (_neon["body"] as Rect2).has_point(pos):   # into the box: glass, sparks, the tubes stutter
		game.fx.spark(pos)
		game.sfx.play("glass", -6.0, pos.x, 0.15)
		_neon["flicker"] = 0.6
		_neon["hits"] = int(_neon["hits"]) + 1
		if int(_neon["hits"]) >= 3:
			_neon_drop()
		return true
	return false


# ---- the hotel sign ----------------------------------------------------------------------------

func _hang_neon() -> void:
	# over the thickest knot of men in the second half of the alley
	var best_x := 0.0
	var best := -1
	for e in game.enemies:
		var x: float = e["node"].position.x
		if x < game.level_end * 0.35 or e["node"].position.y < -100.0:
			continue
		var n := 0
		for o in game.enemies:
			if absf(o["node"].position.x - x) < 380.0 and o["node"].position.y > -100.0:
				n += 1
		if n > best:
			best = n
			best_x = x
	if best < 0:
		return
	var tex: Texture2D = load("res://art/props/neon_hotel.png")
	var glow_tex: Texture2D = load("res://art/props/neon_hotel_glow.png")
	var h := 620.0
	var sc := h / tex.get_height()
	var w := tex.get_width() * sc
	var root := Node2D.new()
	root.position = Vector2(best_x, -1180.0)   # hanging from its bracket, the bottom well over their hats
	root.z_index = -2
	game.add_child(root)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() * 0.5, 0.0)
	spr.scale = Vector2.ONE * sc
	spr.modulate = game._undo_night(0.5)
	root.add_child(spr)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var glow := Sprite2D.new()
	glow.texture = glow_tex
	glow.centered = false
	glow.offset = spr.offset
	glow.scale = spr.scale
	glow.material = add
	root.add_child(glow)
	var light := PointLight2D.new()   # its pink on the wet street under it: the tubes are the source
	light.texture = game._soft_glow()
	light.texture_scale = 6.0
	light.color = Color(1.0, 0.35, 0.5)
	light.energy = 0.9
	light.position = Vector2(0.0, h * 0.55)
	light.range_item_cull_mask = game.MASK_LIT
	root.add_child(light)
	var hum: Dictionary = game.sfx.add_loop("neon_hum", best_x, -12.0, 700.0, -900.0)
	_neon = {"root": root, "glow": glow, "light": light, "hum": hum, "state": "hang", "hits": 0, "flicker": 0.0, "vel": 0.0, "h": h, "w": w,
		"chains": Rect2(root.position + Vector2(-w * 0.35, 0.0), Vector2(w * 0.7, h * 0.16)),
		"body": Rect2(root.position + Vector2(-w * 0.5, h * 0.16), Vector2(w, h * 0.84))}


func _tick_neon(delta: float) -> void:
	var n := _neon
	var root: Node2D = n["root"]
	if n["state"] == "hang":
		root.rotation = sin(Time.get_ticks_msec() * 0.0009) * 0.02
		n["flicker"] = maxf(0.0, float(n["flicker"]) - delta)
		var on: float = 1.0 if float(n["flicker"]) <= 0.0 or randf() < 0.5 else 0.15
		(n["glow"] as CanvasItem).modulate.a = on
		(n["light"] as PointLight2D).energy = 0.9 * on
	elif n["state"] == "fall":
		n["vel"] = float(n["vel"]) + 2600.0 * delta
		root.position.y += float(n["vel"]) * delta
		root.rotation += delta * 0.6
		if root.position.y + float(n["h"]) >= 0.0:
			_neon_lands()


func _neon_drop() -> void:
	var n := _neon
	n["state"] = "fall"
	game.sfx.play("chain", 0.0, (n["root"] as Node2D).position.x, 0.05)
	game.fx.spark((n["chains"] as Rect2).get_center())
	game._word(["clink"], (n["chains"] as Rect2).get_center() + Vector2(0.0, -80.0), 0.18)
	(n["glow"] as CanvasItem).visible = false   # the wires tear: dark on the way down
	(n["light"] as PointLight2D).energy = 0.0
	(n["hum"] as Dictionary)["on"] = false


func _neon_lands() -> void:
	var n := _neon
	n["state"] = "down"
	var root: Node2D = n["root"]
	var x: float = root.position.x
	root.position.y = -float(n["h"])
	game._shake = 0.4
	game.sfx.play("glass", 4.0, x, 0.05)
	game.sfx.play("zap", 0.0, x, 0.05)
	game._word(["crash", "crash2"], Vector2(x, -520.0), 0.3)
	for k in 6:
		game.fx.spark(Vector2(x + randf_range(-90.0, 90.0), randf_range(-60.0, -10.0)))
	for e in game.enemies:   # whoever stood under it
		if e["alive"] and absf(e["node"].position.x - x) < float(n["w"]) * 0.9 and e["node"].position.y > -200.0 and e["node"].visible:
			game._kill(e, false, true, "blast")
	var p = game.player
	if absf(p.position.x - x) < float(n["w"]) * 0.6 and p.position.y > -200.0 and not game.over:
		game.hp = mini(game.hp, 1)
	root.rotation = 0.0
	root.z_index = 1
	var spr: Sprite2D = root.get_child(0)
	game.fx.break_apart(spr, root.position + Vector2(0.0, float(n["h"]) * 0.7), 0.0)
	root.queue_free()
	_neon = {}


# ---- the rats ----------------------------------------------------------------------------------

func _tick_rats(delta: float) -> void:
	_rat_cool -= delta
	if _rat_cool > 0.0 or game.over:
		return
	var px: float = game.player.position.x
	var view_w: float = game.get_viewport().get_visible_rect().size.x / game.cam.zoom.x
	for e in game.enemies:   # men just past the edge of the picture, not yet come at him
		if not e["alive"] or not e["node"].visible:
			continue
		var ex: float = e["node"].position.x
		var id: int = e["node"].get_instance_id()
		if _rat_seen.has(id) or ex < px + view_w * 0.5 or ex > px + view_w * 0.5 + 900.0 or e["node"].position.y < -100.0:
			continue
		_rat_seen[id] = true
		_rat_cool = 6.0
		for k in randi_range(2, 4):
			_rat(Vector2(px + view_w * 0.5 + 40.0 + k * randf_range(60.0, 140.0), 0.0), k * 0.15)
		game.sfx.play("rats", -4.0, px + view_w * 0.4, 0.15)
		return


func _rat(at: Vector2, wait: float) -> void:
	var tex: Texture2D = load("res://art/props/rat.png")
	var r := Sprite2D.new()
	r.texture = tex
	r.centered = false
	r.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	r.scale = Vector2.ONE * (70.0 / tex.get_height()) * randf_range(0.85, 1.1)
	# (the drawing runs to the left: at him, away from the men)
	r.position = at + Vector2(0.0, 6.0)
	r.modulate = game._undo_night(0.4)
	r.z_index = 2
	game.add_child(r)
	var speed := randf_range(900.0, 1200.0)
	var dist: float = game.get_viewport().get_visible_rect().size.x / game.cam.zoom.x + 600.0
	var tw := r.create_tween()
	tw.tween_interval(wait)
	tw.tween_method(func(t: float) -> void:
		r.position.x = at.x - t * dist
		r.position.y = at.y + 6.0 - absf(sin(t * dist * 0.03)) * 8.0, 0.0, 1.0, dist / speed)
	tw.tween_callback(r.queue_free)


# ---- the freight -------------------------------------------------------------------------------

func _tick_freight(delta: float) -> void:
	if game.over or game.cleared:
		return
	_freight_t -= delta
	if _freight_t > 0.0:
		return
	_freight_t = randf_range(38.0, 55.0)
	var tex: Texture2D = load("res://art/props/boxcars.png")
	var sc := 0.62
	var w: float = tex.get_width() * sc
	var cars := 4   # the strip holds three cars: four strips is a dozen
	var root := Node2D.new()
	root.z_index = -6   # on the far track, behind the yard's own fences
	var view_w: float = game.get_viewport().get_visible_rect().size.x / game.cam.zoom.x
	root.position = Vector2(game.cam.position.x - view_w * 0.5 - cars * w - 200.0, -tex.get_height() * sc - 150.0)
	game.add_child(root)
	for k in cars:
		var c := Sprite2D.new()
		c.texture = tex
		c.centered = false
		c.scale = Vector2.ONE * sc
		c.position = Vector2(k * (w - 4.0), 0.0)
		c.modulate = game._undo_night(0.3) * Color(0.85, 0.85, 0.85)
		root.add_child(c)
	game.sfx.play("el_train", -2.0, INF, 0.05)   # the bang and drag of it
	var secs := 9.0
	var tw := root.create_tween()
	tw.tween_property(root, "position:x", root.position.x + cars * w + view_w + 600.0, secs)
	tw.tween_callback(root.queue_free)
	_el_loud = maxf(_el_loud, secs * 0.8)
	if not _el_told:
		_el_told = true
		game.hud.hint("THE FREIGHT GOES BY: NOBODY HEARS A SHOT.")


# ---- the sea -----------------------------------------------------------------------------------

func _tick_sea(delta: float) -> void:
	_wave_t -= delta
	if _wave_t > 0.0 or game.over or game.cleared:
		return
	_wave_t = randf_range(10.0, 16.0)
	var tex: Texture2D = load("res://art/props/wave.png")
	var view_w: float = game.get_viewport().get_visible_rect().size.x / game.cam.zoom.x
	var x: float = game.player.position.x + randf_range(-view_w * 0.3, view_w * 0.3)
	var spr := Sprite2D.new()   # it comes up over the edge of the quay in front, white, and falls back
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	var sc := 900.0 / tex.get_width()
	spr.scale = Vector2(sc, sc * 0.2)
	spr.position = Vector2(x + game.cam.position.x * 0.35, 260.0)
	spr.modulate = game._undo_night(0.55)
	spr.material = game.atmo.blur_material(2.0)
	game.fore.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale:y", sc, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(0.25)
	tw.tween_property(spr, "scale:y", sc * 0.1, 0.7).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(spr, "modulate:a", 0.0, 0.7)
	tw.tween_callback(spr.queue_free)
	game.sfx.play("wave", 2.0, x, 0.1)
	game._shake = maxf(game._shake, 0.2)
	# the spray takes the men near it off their aim, and him off his feet for a beat
	for e in game.enemies:
		if e["alive"] and absf(e["node"].position.x - x) < 600.0:
			e["timer"] = maxf(float(e["timer"]), 1.4)
	if absf(game.player.position.x - x) < 450.0 and game.move_state == "ground":
		game.player.position.x -= 60.0 * signf(game.player.position.x - x + 0.01) * -1.0
		game._shake = maxf(game._shake, 0.35)


# ---- the flood ---------------------------------------------------------------------------------

const FLOOD_TOP := 150.0   # knee deep, no deeper: slowed, never drowned
const FLOOD_TIME := 150.0  # seconds to reach it


func _lay_water() -> void:
	var tex: Texture2D = load("res://art/props/sewer_water.png")
	var sc := 1.0
	var w: float = tex.get_width() * sc
	var x := -3000.0
	while x < game.level_end + 3000.0:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2.ONE * sc
		s.position = Vector2(x, 0.0)
		s.z_index = 3   # in front of their legs: they stand in it
		s.modulate = Color(game._undo_night(0.35), 0.82)
		game.add_child(s)
		_water.append(s)
		x += w - 2.0


func _tick_flood(delta: float) -> void:
	if not game.over and not game.cleared:
		_flood_t += delta
	flood = FLOOD_TOP * smoothstep(0.0, 1.0, clampf(_flood_t / FLOOD_TIME, 0.0, 1.0)) + 18.0
	var t := Time.get_ticks_msec() * 0.001
	for k in _water.size():
		var s: Sprite2D = _water[k]
		s.position.y = -flood + sin(t * 1.3 + k) * 3.0
	if _flood_t > 20.0 and not _el_told:
		_el_told = true
		game.hud.hint("THE WATER IS RISING. KEEP MOVING.")
