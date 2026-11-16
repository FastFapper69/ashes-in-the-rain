import sys
p = '/mnt/user-data/outputs/godot2/main.gd'
s = open(p).read()


def rep(a, b, count=1):
    global s
    n = s.count(a)
    if n != count:
        sys.exit(f"expected {count}, found {n}: {a[:90]!r}")
    s = s.replace(a, b)


# ---------------------------------------------------------------- state
rep("var catwalks: Array[Rect2] = []\n", '''var catwalks: Array[Rect2] = []   # floors above the street: catwalks, fire-escape landings, landings indoors
var ramps: Array = []          # flights of stairs: [x0, y0, x1, y1]
var rooms: Array = []          # interiors: [x0, x1, style]
var box_info: Array = []       # one per box, same order: {kind, sprite, hp, wood}
var lamp_info: Array = []      # one per lamp, same order as lamps: {nodes, light, on}
var pickups: Array = []        # {kind, node}
var weapon := "revolver"
var ammo := 0
var stats := {"kills": 0, "heads": 0, "slow": 0, "hits": 0, "time": 0.0}
var _last_kind := "ground"     # what _floor_at last stood him on: ground, box or floor
var _drop_t := 0.0             # seconds he falls through the landing he stood on (stick pulled down)
var _drop_y := 0.0
var _hurt_t := 0.0             # a moment of grace after a hit: a shotgun blast counts once
var _room := ""
var _hint_i := 0
var _check_i := 0
var _stand := false
var _stand_t := 0.0
var _stand_spawn := 0.0
var _shake := 0.0
static var checkpoint := -1.0   # where a death sends him back to on this map; -1 = the start
# the guns: seconds between shots, rounds when picked up, pellets per shot, spread (radians), how long a
# bullet flies, the kick of the arm, the sound
const WEAPONS := {
	"revolver": {"cool": 0.2, "ammo": 0, "pellets": 1, "spread": 0.0, "life": 1.4, "kick": 0.2, "sound": "shot_player", "name": "REVOLVER"},
	"pistols": {"cool": 0.11, "ammo": 40, "pellets": 1, "spread": 0.025, "life": 1.4, "kick": 0.12, "sound": "shot_enemy", "name": "TWO PISTOLS"},
	"tommy": {"cool": 0.085, "ammo": 60, "pellets": 1, "spread": 0.05, "life": 1.4, "kick": 0.08, "sound": "shot_tommy", "name": "TOMMY GUN"},
	"shotgun": {"cool": 0.7, "ammo": 10, "pellets": 6, "spread": 0.15, "life": 0.3, "kick": 0.35, "sound": "shot_shotgun", "name": "SHOTGUN"},
}
const WOOD := ["crate", "crate_long"]
const BOX_ART := {"barrel": ["drum", Color(1.0, 0.32, 0.26)], "machine": ["dumpster", Color(0.7, 0.72, 0.78)], "bar": ["crate_long", Color(0.45, 0.32, 0.26)]}
const ENEMY_TINT := {"post": Color(1, 1, 1), "tommy": Color(0.82, 0.86, 1.0), "shotgun": Color(1.0, 0.9, 0.78), "boss": Color(1, 1, 1)}
''')

# ---------------------------------------------------------------- setup
rep('''	level = ch["maps"][map]
	level_end = level["end"]''', '''	level = ch["maps"][map]
	level_end = level["end"]
	rooms = level["rooms"]
	if _auto_arg() != "":
		checkpoint = -1.0''')
rep('''	_build_level()
	player = PuppetScript.new()
	player.cfg = DETECTIVE
	player.night = _undo_night(1.0)
	add_child(player)
''', '''	_build_level()
	player = PuppetScript.new()
	player.cfg = DETECTIVE
	player.night = _undo_night(1.0)
	add_child(player)
	if ch["hero"] == "eddie":   # stand-in until Eddie has his own drawings: a paler, younger coat
		player.modulate = Color(0.9, 0.95, 1.1)
	if checkpoint > 0.0 and not in_menu:
		player.position = Vector2(checkpoint, _floor_at(checkpoint, -2000.0))
		cam_start = player.position.x
''')
rep('''	cam.position = Vector2(CAM_LEAD, CAM_Y)''', '''	cam.position = Vector2(cam_start + CAM_LEAD, CAM_Y)''')
rep("var level_end := 0.0\n", "var level_end := 0.0\nvar cam_start := 0.0\n")
rep('''	elif _auto_arg() == "" or _auto_arg() == "play":
		hud.title(''', '''	elif checkpoint > 0.0:
		hud.toast("CHECKPOINT")
	elif _auto_arg() == "" or _auto_arg() == "play":
		hud.title(''')

# street lamps: none inside rooms, and every lamp remembers its parts so it can be shot out
rep('''		for px in LAMPS_PX:
			var at: Vector2 = origin + (px as Vector2) * WALL_SCALE
			lamps.append(at)''', '''		for px in LAMPS_PX:
			var at: Vector2 = origin + (px as Vector2) * WALL_SCALE
			if _room_at(at.x) != "":
				continue
			lamps.append(at)
			var rec := {"nodes": [], "light": null, "on": true}
			lamp_info.append(rec)''')
for name in ["beam", "halo", "bulb"]:
    rep(f"\t\t\tadd_child({name})\n", f"\t\t\tadd_child({name})\n\t\t\trec[\"nodes\"].append({name})\n")
rep("\t\t\t\tadd_child(wet)\n", "\t\t\t\tadd_child(wet)\n\t\t\t\trec[\"nodes\"].append(wet)\n")
rep('''	var cone: Texture2D = load("res://art/light_cone.png")
	for l in lamps:
		var p := PointLight2D.new()   # a hard cone straight down from the lamp to the pavement
		p.texture = cone
		p.texture_scale = 1.35
		p.position = l + Vector2(0.0, 256.0 * 1.35)
		p.color = LAMP_COLOR
		p.energy = 1.3
		p.height = 160.0
		p.range_item_cull_mask = MASK_LIT
		add_child(p)
''', '''	for i in lamps.size():
		lamp_info[i]["light"] = _lamp_light(lamps[i])
''')
rep('''func _add_window_light(''', '''## A hard cone of light straight down from a lamp.
func _lamp_light(at: Vector2) -> PointLight2D:
	var p := PointLight2D.new()
	p.texture = load("res://art/light_cone.png")
	p.texture_scale = 1.35
	p.position = at + Vector2(0.0, 256.0 * 1.35)
	p.color = LAMP_COLOR
	p.energy = 1.3
	p.height = 160.0
	p.range_item_cull_mask = MASK_LIT
	add_child(p)
	return p


func _add_window_light(''')

# ---------------------------------------------------------------- the level
i0 = s.index("## The crates, catwalks and mobsters of the chapter being played.")
i1 = s.index("## One of the boss's men, sent running in from off-screen to `goal`.")
s = s[:i0] + '''## The rooms, crates, floors, stairs, lamps, pickups and mobsters of the map being played.
func _build_level() -> void:
	for r in rooms:
		_build_room(float(r[0]), float(r[1]), String(r[2]))
	for spec in level["boxes"]:
		var kind := String(spec[0])
		var art: String = BOX_ART[kind][0] if BOX_ART.has(kind) else kind
		var tex: Texture2D = load("res://art/props/" + art + ".png")
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(float(spec[2]) / tex.get_width(), float(spec[3]) / tex.get_height())
		s.position = Vector2(float(spec[1]), -float(spec[3]) + 6.0)
		s.z_index = -2
		if BOX_ART.has(kind):
			s.modulate = BOX_ART[kind][1]
		add_child(s)
		boxes.append(Rect2(float(spec[1]), -float(spec[3]), float(spec[2]), float(spec[3])))
		box_info.append({"kind": kind, "sprite": s, "hp": 7, "wood": kind in WOOD})
	var cat_tex: Texture2D = load("res://art/props/catwalk.png")
	for c in level["floors"]:
		var r := Rect2(float(c[0]), float(c[1]), float(c[2]), 0.0)
		catwalks.append(r)
		if String(c[3]) == "floor":   # a landing indoors: a dark beam and a rail
			_slab(r)
			continue
		var cat := Sprite2D.new()
		cat.texture = cat_tex
		cat.centered = false
		cat.scale = Vector2.ONE * (r.size.x / cat_tex.get_width())
		cat.position = r.position - Vector2(0.0, 215.0 * cat.scale.y)   # its floor is 215 px down the drawing
		cat.z_index = -2
		add_child(cat)
	for rp in level["ramps"]:
		ramps.append(rp)
		_stairs(Vector2(float(rp[0]), float(rp[1])), Vector2(float(rp[2]), float(rp[3])))
	for l in level["lamps"]:   # lamps hanging from the ceilings of the rooms
		var at := Vector2(float(l[0]), float(l[1]))
		var cord := Line2D.new()
		cord.points = PackedVector2Array([Vector2(at.x, -1330.0), at + Vector2(0.0, -30.0)])
		cord.width = 5.0
		cord.default_color = Color(0.03, 0.03, 0.03)
		cord.z_index = -4
		add_child(cord)
		var rec := {"nodes": [], "light": null, "on": true}
		var shade := Polygon2D.new()
		shade.polygon = PackedVector2Array([Vector2(-50, 0), Vector2(50, 0), Vector2(22, -36), Vector2(-22, -36)])
		shade.color = Color(0.05, 0.05, 0.05)
		shade.position = at
		shade.z_index = -4
		add_child(shade)
		var bulb := Sprite2D.new()
		bulb.texture = load("res://art/light_blob.png")
		bulb.scale = Vector2.ONE * 0.1
		bulb.position = at + Vector2(0.0, 6.0)
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		bulb.material = mat
		bulb.modulate = _undo_night(0.8) * Color(1.0, 0.85, 0.6)
		bulb.z_index = -4
		add_child(bulb)
		rec["nodes"].append(bulb)
		rec["light"] = _lamp_light(at + Vector2(0.0, -8.0))
		lamps.append(at + Vector2(0.0, 8.0))
		lamp_info.append(rec)
	if in_menu:
		return
	for pk in level["pickups"]:
		_add_pickup(String(pk[0]), Vector2(float(pk[1]), float(pk[2])))
	for spec in level["enemies"]:
		var goal := Vector2(float(spec["x"]), float(spec["y"]))
		var runner: bool = spec["run"]
		if checkpoint > 0.0 and goal.x < checkpoint + 300.0 and (not runner or float(spec["trig"]) < checkpoint):
			continue   # dealt with before the checkpoint
		var e := _add_enemy(Vector2(float(spec["from"]), goal.y) if runner else goal, String(spec["kind"]), "wait" if runner else "post", goal.x)
		e["trig"] = float(spec["trig"])
		e["delay"] = float(spec["delay"])
		if e["boss"]:
			boss = e


## One mobster of any kind. state: post (stands and fights), wait (off-screen until his mark), run.
func _add_enemy(at: Vector2, kind: String, state: String, goal_x: float) -> Dictionary:
	var m = PuppetScript.new()
	m.cfg = MOBSTER
	m.night = _undo_night(1.0)
	m.position = at
	m.modulate = ENEMY_TINT.get(kind, Color(1, 1, 1))
	add_child(m)
	if kind == "boss":
		m.size = 1.15
	m.set_state(0.0, Vector2(-1.0, 0.0), 0.0)
	m.visible = state != "wait"
	var e := {"node": m, "type": kind, "hp": BOSS_HP if kind == "boss" else MOBSTER_HP, "cool": randf_range(0.8, 1.6), "aim_off": 0.0,
			"alive": true, "seen": state == "run", "cover": false if state != "post" else _has_cover(at), "up": false, "shot": false,
			"timer": randf_range(0.5, 1.5), "state": state, "goal": goal_x, "trig": -1.0, "delay": 0.0, "boss": kind == "boss", "calls": 0}
	enemies.append(e)
	return e


## An interior: its back wall in front of the street, a ceiling, and a doorway at each end.
func _build_room(x0: float, x1: float, style: String) -> void:
	var tex: Texture2D = load("res://art/rooms/" + style + ".png")
	var wall := Sprite2D.new()
	wall.texture = tex
	wall.centered = false
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.region_enabled = true
	wall.region_rect = Rect2(0.0, 0.0, x1 - x0, tex.get_height())
	wall.position = Vector2(x0, -tex.get_height() + 2.0)
	wall.z_index = -5
	add_child(wall)
	var roof := Polygon2D.new()   # everything above the ceiling is solid black
	roof.polygon = PackedVector2Array([Vector2(x0, -3200), Vector2(x1, -3200), Vector2(x1, -tex.get_height() + 120.0), Vector2(x0, -tex.get_height() + 120.0)])
	roof.color = Color(0.0, 0.0, 0.0)
	roof.z_index = 9
	add_child(roof)
	for x in [x0, x1]:   # the doorways: a black gap in a thick frame
		var door := Polygon2D.new()
		door.polygon = PackedVector2Array([Vector2(-70, 0), Vector2(70, 0), Vector2(70, -520), Vector2(-70, -520)])
		door.color = Color(0.01, 0.01, 0.01)
		door.position = Vector2(x, 0.0)
		door.z_index = -4
		add_child(door)
		var frame := Line2D.new()
		frame.points = PackedVector2Array([Vector2(x - 80, 0), Vector2(x - 80, -530), Vector2(x + 80, -530), Vector2(x + 80, 0)])
		frame.width = 16.0
		frame.default_color = Color(0.16, 0.13, 0.11)
		frame.z_index = -4
		add_child(frame)
		var wall_side := Polygon2D.new()   # the outside wall of the building, cut away above the door
		wall_side.polygon = PackedVector2Array([Vector2(-60, -530), Vector2(60, -530), Vector2(60, -3200), Vector2(-60, -3200)])
		wall_side.color = Color(0.03, 0.03, 0.035)
		wall_side.position = Vector2(x, 0.0)
		wall_side.z_index = 9
		add_child(wall_side)


## A landing indoors.
func _slab(r: Rect2) -> void:
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([r.position + Vector2(0, -6), r.position + Vector2(r.size.x, -6), r.position + Vector2(r.size.x, 34), r.position + Vector2(0, 34)])
	beam.color = Color(0.09, 0.07, 0.06)
	beam.z_index = -3
	add_child(beam)
	var rail := Line2D.new()
	rail.points = PackedVector2Array([r.position + Vector2(0, -110), r.position + Vector2(r.size.x, -110)])
	rail.width = 8.0
	rail.default_color = Color(0.06, 0.05, 0.04)
	rail.z_index = -3
	add_child(rail)
	var x := r.position.x
	while x < r.end.x:
		var post := Line2D.new()
		post.points = PackedVector2Array([Vector2(x, r.position.y), Vector2(x, r.position.y - 110)])
		post.width = 5.0
		post.default_color = Color(0.06, 0.05, 0.04)
		post.z_index = -3
		add_child(post)
		x += 60.0


## A flight of iron stairs from a to b: the stringer and the treads, in ink.
func _stairs(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([a + Vector2(0, 14), b + Vector2(0, 14)])
	line.width = 20.0
	line.default_color = Color(0.05, 0.05, 0.05)
	line.z_index = -3
	add_child(line)
	var n := int(absf(b.y - a.y) / 34.0)
	for k in n:
		var p := a.lerp(b, (k + 0.5) / n)
		var tread := Line2D.new()
		tread.points = PackedVector2Array([p + Vector2(-20, 0), p + Vector2(20, 0)])
		tread.width = 7.0
		tread.default_color = Color(0.12, 0.12, 0.13)
		tread.z_index = -3
		add_child(tread)
	var rail := Line2D.new()
	rail.points = PackedVector2Array([a + Vector2(0, -100), b + Vector2(0, -100)])
	rail.width = 5.0
	rail.default_color = Color(0.05, 0.05, 0.05)
	rail.z_index = -3
	add_child(rail)


func _room_at(x: float) -> String:
	for r in rooms:
		if x > float(r[0]) and x < float(r[1]):
			return String(r[2])
	return ""


## Something to pick up: a gun or the flask, bobbing a little so it catches the eye.
func _add_pickup(kind: String, at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://art/items/" + kind + ".png")
	s.scale = Vector2.ONE * (0.5 if kind == "flask" else 0.62)
	s.position = at + Vector2(0.0, -70.0)
	s.modulate = _undo_night(0.95)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	s.z_index = 1
	add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", at.y - 95.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", at.y - 70.0, 0.6).set_trans(Tween.TRANS_SINE)
	pickups.append({"kind": kind, "node": s})


func _pickups() -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pk: Dictionary = pickups[i]
		var s: Sprite2D = pk["node"]
		if absf(s.position.x - player.position.x) > 90.0 or absf(s.position.y + 80.0 - player.position.y) > 160.0:
			continue
		var kind: String = pk["kind"]
		if kind == "flask":
			if hp >= PLAYER_HP:
				continue
			hp = mini(PLAYER_HP, hp + 2)
			hud.set_health(float(hp) / PLAYER_HP)
			sfx.play("drink", 0.0)
			hud.toast("A PULL FROM THE FLASK")
		else:
			weapon = kind
			ammo = int(WEAPONS[kind]["ammo"])
			hud.set_weapon(String(WEAPONS[kind]["name"]), ammo)
			sfx.play("pickup", 0.0)
			hud.toast(String(WEAPONS[kind]["name"]))
		s.queue_free()
		pickups.remove_at(i)


''' + s[i1:]

rep('''## One of the boss's men, sent running in from off-screen to `goal`.
func _spawn_runner(from_x: float, goal_x: float) -> void:
	var m = PuppetScript.new()
	m.cfg = MOBSTER
	m.night = _undo_night(1.0)
	m.position = Vector2(from_x, 0.0)
	add_child(m)
	m.set_state(0.0, Vector2(-1.0, 0.0), 0.0)
	enemies.append({"node": m, "hp": MOBSTER_HP, "cool": 0.6, "aim_off": 0.0, "alive": true, "seen": true, "cover": false, "up": false,
			"shot": false, "timer": 1.0, "state": "run", "goal": goal_x, "trig": -1.0, "boss": false, "calls": 0})''', '''## One of the boss's men (or the prologue's endless mob), sent running in from off-screen to `goal`.
func _spawn_runner(from_x: float, goal_x: float, kind := "post") -> void:
	var e := _add_enemy(Vector2(from_x, 0.0), kind, "run", goal_x)
	e["cool"] = 0.6''')

# ---------------------------------------------------------------- floors and stairs
i0 = s.index("## The highest thing under his feet")
i1 = s.index("## Crates and the like stop him")
s = s[:i0] + '''## The highest thing under his feet: the pavement, the top of a crate, a landing or a flight of stairs.
## Sets _last_kind to what it found. While he drops through a landing, that landing and those above it
## do not count.
func _floor_at(x: float, feet: float) -> float:
	var best := 0.0
	_last_kind = "ground"
	for b in boxes:
		if x > b.position.x - 20.0 and x < b.end.x + 20.0 and feet <= b.position.y + 14.0 and b.position.y < best:
			best = b.position.y
			_last_kind = "box"
	for c in catwalks:
		if x > c.position.x and x < c.end.x and feet <= c.position.y + 14.0 and c.position.y < best:
			if _drop_t > 0.0 and c.position.y <= _drop_y + 10.0:
				continue
			best = c.position.y
			_last_kind = "floor"
	for r in ramps:
		var a: float = minf(r[0], r[2])
		var b2: float = maxf(r[0], r[2])
		if x < a or x > b2:
			continue
		var ry: float = lerpf(r[1], r[3], (x - float(r[0])) / (float(r[2]) - float(r[0])))
		if feet <= ry + 34.0 and ry < best and ry < -1.0:   # a step up the stairs is within reach of a stride
			if _drop_t > 0.0 and ry <= _drop_y + 10.0:
				continue
			best = ry
			_last_kind = "floor"
	return best


''' + s[i1:]
rep('''			if strict and _floor_at(x, feet) < 0.0 and not _on_catwalk(x):''', '''			if strict and _floor_at(x, feet) < 0.0 and _last_kind == "box":''')
rep('''		if floor_y > player.position.y - DIVE_LAND * player.dive + 2.0 and player.dive < 0.05:   # walked off an edge''',
    '''		if floor_y > player.position.y - DIVE_LAND * player.dive + 36.0 and player.dive < 0.05:   # walked off an edge (a step down the stairs is just walked)''')
rep('''	var before_x: float = player.position.x
	var floor_y := _floor_at(player.position.x, player.position.y - DIVE_LAND * player.dive)''', '''	_drop_t = maxf(0.0, _drop_t - delta)
	if move_state == "ground" and slide and player.dive < 0.05:   # stick pulled down on a landing or the stairs: he drops through
		_floor_at(player.position.x, player.position.y)
		if _last_kind == "floor" and absf(run) < 300.0:
			_drop_t = 0.35
			_drop_y = player.position.y
			move_state = "jump"
			fall = 60.0
	var before_x: float = player.position.x
	var floor_y := _floor_at(player.position.x, player.position.y - DIVE_LAND * player.dive)''')

# camera follows him up the storeys
rep('''	cam.position = Vector2(lerpf(cam.position.x, player.position.x + CAM_LEAD, 1.0 - exp(-9.0 * real)), CAM_Y)''',
    '''	cam.position = Vector2(lerpf(cam.position.x, player.position.x + CAM_LEAD, 1.0 - exp(-9.0 * real)),
			lerpf(cam.position.y, CAM_Y + clampf(player.position.y * 0.7, -560.0, 0.0), 1.0 - exp(-4.0 * real)))
	if _shake > 0.0:   # an explosion shakes the picture
		_shake = maxf(0.0, _shake - real)
		cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 60.0 * _shake
	else:
		cam.offset = Vector2.ZERO''')

# ---------------------------------------------------------------- firing
rep('''	if hud.fire_tapped and fire_cool > 0.0:''', '''	_hurt_t = maxf(0.0, _hurt_t - delta)
	if hud.fire_tapped and fire_cool > 0.0:''')
rep('''		fire_cool = 0.2
''', '''		fire_cool = float(WEAPONS[weapon]["cool"])
''')
i0 = s.index("## One shot: flash, bullet, casing, kick of the arm and the lettered bang.")
i1 = s.index("## Called by fx.gd for every bullet in flight.")
s = s[:i0] + '''## One shot: flash, bullet (or a shotgun's pellets), casing, kick of the arm and the lettered bang.
## kind: the mobster's gun (post, tommy, shotgun); the detective fires whatever he holds.
func _fire(shooter, from_player: bool, kind := "") -> void:
	var at: Vector2 = shooter.muzzle()
	var d: Vector2 = shooter.aim_dir()
	if from_player and _aim_point != Vector2.INF and _aim_point.distance_to(at) > 120.0:
		d = (_aim_point - at).normalized()   # exactly onto the finger or the cursor, wherever the arm still is
	var gun := weapon if from_player else (kind if WEAPONS.has(kind) else "revolver")
	var w: Dictionary = WEAPONS[gun]
	fx.muzzle(at, d)
	for k in int(w["pellets"]):
		var spread: float = w["spread"]
		fx.shoot(at, d.rotated(randf_range(-spread, spread)) * BULLET_SPEED, from_player, w["life"])
	fx.casing(at - d * 50.0, signf(d.x))
	shooter.recoil = w["kick"]
	var sound: String = w["sound"] if from_player else ("shot_enemy" if gun == "revolver" else String(w["sound"]))
	if from_player:
		sfx.play(sound, 0.0)
	else:
		sfx.play(sound, -2.0, at.x)
	if gun != "tommy" or randf() < 0.25:
		var word_path := "res://art/fx/word_blam.png" if from_player else "res://art/fx/word_bang.png"
		fx.word(word_path, at + Vector2(signf(d.x) * 70.0, -150.0), 0.29 if from_player else 0.32, d)
	if from_player and weapon != "revolver":
		ammo -= 1
		if ammo <= 0:
			weapon = "revolver"
			hud.toast("EMPTY")
		hud.set_weapon(String(WEAPONS[weapon]["name"]), ammo)


## A mobster opens fire the way his gun does: the tommy gunner in a burst, the boss in threes.
func _enemy_fire(e: Dictionary) -> void:
	var m = e["node"]
	match String(e["type"]):
		"boss":
			_boss_fire(m)
			e["cool"] = randf_range(1.4, 2.3)
		"tommy":
			for k in 6:
				get_tree().create_timer(0.09 * k, false).timeout.connect(func() -> void:
					if e["alive"] and not over:
						e["aim_off"] = randf_range(-110.0, 80.0) * _aim_spread()
						_fire(m, false, "tommy"))
			e["cool"] = randf_range(2.4, 3.2)
		"shotgun":
			_fire(m, false, "shotgun")
			e["cool"] = randf_range(1.5, 2.0)
		_:
			_fire(m, false)
			e["cool"] = randf_range(1.4, 2.3)


## How far off the mobsters aim: wide when the detective stands in the dark, tight in the last stand.
func _aim_spread() -> float:
	if _stand:
		return 0.5
	return 2.1 if _in_dark(player.position.x) else 1.0


func _in_dark(x: float) -> bool:
	for i in lamps.size():
		if lamp_info[i]["on"] and absf(lamps[i].x - x) < 700.0:
			return false
	return true


''' + s[i1:]

# enemies fire through _enemy_fire, with the spread of the dark
rep('''					if may_fire:
						if e["boss"]:
							_boss_fire(m)
						else:
							_fire(m, false)
						e["aim_off"] = randf_range(-120.0, 90.0)''', '''					if may_fire:
						e["aim_off"] = randf_range(-120.0, 90.0) * _aim_spread()
						_enemy_fire(e)''')
rep('''			e["cool"] -= delta
			if e["cool"] <= 0.0 and may_fire:
				if e["boss"]:
					_boss_fire(m)
				else:
					_fire(m, false)
				e["cool"] = randf_range(1.4, 2.3)
				e["aim_off"] = randf_range(-150.0, 110.0)
		m.duck = move_toward(m.duck, want_duck, delta * 7.0)
		m.set_state(0.0, to_player + Vector2(0.0, e["aim_off"]), delta)''', '''			e["cool"] -= delta
			if e["type"] == "shotgun" and absf(m.position.y - player.position.y) < 60.0 and absf(to_player.x) > 520.0:
				walk = signf(to_player.x)   # the shotgunner closes in
				m.position.x += walk * 300.0 * delta
			var in_range: bool = e["type"] != "shotgun" or absf(to_player.x) < 760.0
			if e["cool"] <= 0.0 and may_fire and in_range:
				e["aim_off"] = randf_range(-150.0, 110.0) * _aim_spread()
				_enemy_fire(e)
		m.duck = move_toward(m.duck, want_duck, delta * 7.0)
		m.set_state(walk, to_player + Vector2(0.0, e["aim_off"]), delta)''')
rep('''		var hiding: bool = e["cover"] and side > 0.0   # his cover only works while the detective is on its far side
		var want_duck: float = 0.0''', '''		var hiding: bool = e["cover"] and side > 0.0   # his cover only works while the detective is on its far side
		var want_duck: float = 0.0
		var walk := 0.0''')
# runners wait out their delay once the hero passes their mark
rep('''		if e["state"] == "wait":   # a runner holds back, out of sight, until the detective passes his mark
			if player.position.x > float(e["trig"]):''', '''		if e["state"] == "wait":   # a runner holds back, out of sight, until the detective passes his mark
			if player.position.x > float(e["trig"]):
				e["delay"] = float(e["delay"]) - delta
			if player.position.x > float(e["trig"]) and float(e["delay"]) <= 0.0:''')

# ---------------------------------------------------------------- bullets meet the world
rep('''	for b in boxes:   # cover stops bullets from both sides
		if b.has_point(pos):
			fx.spark(pos)
			sfx.play("hit_cover", -4.0, pos.x, 0.12)
			return true
	if from_player:''', '''	for i in boxes.size():   # cover stops bullets from both sides; wood gives way, a barrel goes up
		if boxes[i].has_point(pos):
			_hit_box(i, pos)
			return true
	if from_player:
		for i in lamps.size():
			if lamp_info[i]["on"] and pos.distance_to(lamps[i] + Vector2(0.0, -8.0)) < 38.0:
				_lamp_out(i)
				return true''')
rep('''			else:
				e["hp"] -= MOBSTER_HP if part == "head" else 1   # a head shot always kills
			e["seen"] = true   # being shot at wakes him up, however far away
			if e["hp"] <= 0:
				e["alive"] = false
				_drop(e["node"], signf(e["node"].position.x - player.position.x), true)
				fx.word("res://art/fx/word_krakoom.png", e["node"].position + Vector2(0.0, -500.0), 0.28)
			return true''', '''			else:
				e["hp"] -= MOBSTER_HP if part == "head" else 1   # a head shot always kills
			e["seen"] = true   # being shot at wakes him up, however far away
			if e["hp"] <= 0:
				_kill(e, part == "head")
			return true''')
rep('''	if player.hit_part(pos) == "":   # the posed body: flying flat or crouched he really is a smaller target
		return false''', '''	if player.hit_part(pos) == "":   # the posed body: flying flat or crouched he really is a smaller target
		return false
	if _hurt_t > 0.0:   # the same blast hit him a moment ago
		return true
	_hurt_t = 0.3
	stats["hits"] += 1''')

rep('''## One of the detective's bullets met one of theirs in the air.''', '''## A mobster goes down: counted for the score, his gun left on the pavement.
func _kill(e: Dictionary, head: bool) -> void:
	e["alive"] = false
	var m = e["node"]
	stats["kills"] += 1
	stats["heads"] += 1 if head else 0
	stats["slow"] += 1 if Engine.time_scale < 1.0 else 0
	_drop(m, signf(m.position.x - player.position.x), true)
	fx.word("res://art/fx/word_krakoom.png", m.position + Vector2(0.0, -500.0), 0.28)
	if e["type"] in ["tommy", "shotgun"]:
		_add_pickup(String(e["type"]), m.position)
	elif randf() < 0.12:
		_add_pickup("flask", m.position)


## A bullet into a box: wood splinters and finally gives way, metal sparks, a barrel explodes.
func _hit_box(i: int, pos: Vector2) -> void:
	var info: Dictionary = box_info[i]
	if info["kind"] == "barrel":
		_explode.call_deferred(boxes[i].get_center(), i)
		return
	fx.spark(pos)
	sfx.play("hit_cover", -4.0, pos.x, 0.12)
	if not info["wood"]:
		return
	info["hp"] -= 1
	var s: Sprite2D = info["sprite"]
	s.modulate = Color(1, 1, 1).darkened(0.08 * (7 - int(info["hp"])))
	var tw := s.create_tween()
	tw.tween_property(s, "position:x", s.position.x + 6.0, 0.03)
	tw.tween_property(s, "position:x", s.position.x, 0.05)
	if info["hp"] <= 0:
		_break_box(i)


## A crate shot to pieces: it collapses, splinters fly, and whoever hid behind it is in the open.
func _break_box(i: int) -> void:
	var r: Rect2 = boxes[i]
	var s: Sprite2D = box_info[i]["sprite"]
	boxes.remove_at(i)
	box_info.remove_at(i)
	sfx.play("hit_cover", 0.0, r.get_center().x, 0.0)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale:y", s.scale.y * 0.15, 0.25)
	tw.tween_property(s, "position:y", s.position.y + r.size.y * 0.85, 0.25)
	tw.tween_property(s, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(s.queue_free)
	for k in 10:   # splinters
		var sp := Polygon2D.new()
		sp.polygon = PackedVector2Array([Vector2(-14, -3), Vector2(14, -2), Vector2(12, 3), Vector2(-12, 4)])
		sp.color = Color(0.32, 0.24, 0.16)
		sp.position = r.get_center() + Vector2(randf_range(-r.size.x, r.size.x) * 0.4, randf_range(-40.0, 40.0))
		sp.rotation = randf() * TAU
		sp.z_index = 2
		add_child(sp)
		var t2 := sp.create_tween().set_parallel(true)
		t2.tween_property(sp, "position", sp.position + Vector2(randf_range(-260.0, 260.0), randf_range(-200.0, 120.0)), 0.5).set_ease(Tween.EASE_OUT)
		t2.tween_property(sp, "rotation", sp.rotation + randf_range(-8.0, 8.0), 0.5)
		t2.tween_property(sp, "modulate:a", 0.0, 0.6)
		t2.chain().tween_callback(sp.queue_free)
	for e in enemies:
		if e["alive"] and e["state"] == "post":
			e["cover"] = _has_cover(e["node"].position)


## A barrel goes up: everyone close is thrown down, crates near it burst, other barrels follow it.
func _explode(at: Vector2, i: int) -> void:
	if i >= boxes.size() or boxes[i].get_center() != at:
		i = -1
		for k in boxes.size():
			if boxes[k].get_center() == at:
				i = k
	if i < 0:
		return
	box_info[i]["sprite"].queue_free()
	boxes.remove_at(i)
	box_info.remove_at(i)
	sfx.play("explosion", 2.0, at.x, 0.0)
	_shake = 0.5
	fx.word("res://art/fx/word_krakoom.png", at + Vector2(0.0, -260.0), 0.5)
	var flash := Sprite2D.new()
	flash.texture = load("res://art/light_blob.png")
	flash.position = at
	flash.scale = Vector2.ONE * 0.4
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flash.material = mat
	flash.modulate = _undo_night(1.2) * Color(1.0, 0.75, 0.4)
	flash.z_index = 8
	add_child(flash)
	var tw := flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector2.ONE * 2.6, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(flash.queue_free)
	for k in 8:
		fx.spark(at + Vector2(randf_range(-160.0, 160.0), randf_range(-200.0, 40.0)))
	for e in enemies:
		if e["alive"] and e["state"] != "wait" and e["node"].position.distance_to(at + Vector2(0.0, 60.0)) < 380.0:
			if e["boss"]:
				e["hp"] -= 4
				hud.boss_bar(BOSS_NAMES.get(String(level["boss"]), "BOSS"), float(e["hp"]) / BOSS_HP)
				if e["hp"] > 0:
					continue
				hud.boss_bar("", -1.0)
			_kill(e, false)
	if not over and player.position.distance_to(at + Vector2(0.0, 60.0)) < 330.0 and _auto == "":
		hp -= 2
		stats["hits"] += 1
		hud.set_health(float(hp) / PLAYER_HP)
		if hp <= 0:
			_player_down()
	for k in range(boxes.size() - 1, -1, -1):
		if k < boxes.size() and boxes[k].get_center().distance_to(at) < 420.0:
			if box_info[k]["kind"] == "barrel":
				get_tree().create_timer(0.15, false).timeout.connect(_explode.bind(boxes[k].get_center(), k))
			elif box_info[k]["wood"]:
				_break_box(k)
	for k in lamps.size():
		if lamp_info[k]["on"] and lamps[k].distance_to(at) < 500.0:
			_lamp_out(k)


## A lamp shot out: its glow and light go, glass rains down, and the street around it is dark.
func _lamp_out(i: int) -> void:
	var rec: Dictionary = lamp_info[i]
	rec["on"] = false
	for n in rec["nodes"]:
		n.visible = false
	if rec["light"] != null:
		rec["light"].enabled = false
	fx.spark(lamps[i])
	sfx.play("glass", -2.0, lamps[i].x, 0.1)


## One of the detective's bullets met one of theirs in the air.''')

# shadows only from lamps still lit
rep('''	var best := Vector2.INF
	for l in lamps:
		if absf(l.x - p.position.x) < absf(best.x - p.position.x):
			best = l''', '''	var best := Vector2.INF
	for i in lamps.size():
		var l: Vector2 = lamps[i]
		if lamp_info[i]["on"] and absf(l.x - p.position.x) < absf(best.x - p.position.x):
			best = l''')

# ---------------------------------------------------------------- per frame: rooms, checkpoints, hints, pickups, the last stand
rep('''	_enemies(delta)
''', '''	_enemies(delta)
	_pickups()
	_map_events(delta)
''')
rep('''func _restart() -> void:''', '''## Doors, checkpoints, the tutorial's hints, and the prologue's last stand.
func _map_events(delta: float) -> void:
	stats["time"] += delta
	var room := _room_at(player.position.x)
	if room != _room:   # through a door: a cut through black, no rain indoors
		_room = room
		hud.flash()
		atmo.rain_far.visible = room == ""
		atmo.rain_near.visible = room == ""
		if atmo.splashes:
			atmo.splashes.visible = room == ""
	var cps: Array = level["checkpoints"]
	while _check_i < cps.size() and player.position.x > float(cps[_check_i]):
		if float(cps[_check_i]) > checkpoint and not over:
			checkpoint = float(cps[_check_i])
			hud.toast("CHECKPOINT")
		_check_i += 1
	var hints: Array = level["hints"]
	while _hint_i < hints.size() and player.position.x > float(hints[_hint_i][0]):
		if _auto == "" or _auto == "play":
			hud.caption([String(hints[_hint_i][1])])
		_hint_i += 1
	var stand_x := float(level["stand"])
	if stand_x > 0.0 and not _stand and player.position.x > stand_x:
		_stand = true   # the dead end: they come from both sides, more and more, until Eddie falls
		_stand_t = 0.0
		if _auto == "play":
			print("BOT REACHED THE LAST STAND in ", int(_at), " s")
			get_tree().quit()
	if _stand and not over:
		_stand_t += delta
		player.position.x = clampf(player.position.x, stand_x - 400.0, level_end - 200.0)
		slow_left = maxf(0.0, slow_left - delta * (0.03 + _stand_t * 0.004))
		_stand_spawn -= delta
		var alive := 0
		for e in enemies:
			alive += 1 if e["alive"] else 0
		if _stand_spawn <= 0.0 and alive < 7:
			_stand_spawn = maxf(0.6, 1.8 - _stand_t * 0.04)
			var side := -1.0 if randf() < 0.5 else 1.0
			_spawn_runner(player.position.x + side * 1900.0, player.position.x + side * randf_range(500.0, 900.0), "tommy" if randf() < _stand_t / 60.0 else "post")
		if _stand_t > 55.0 and hp > 0:   # nobody walks out of this alley
			hp = 1


## Score card: one star for finishing, one for taking few hits, one for style (head shots and slowed-time kills).
func _rate() -> void:
	var kills: int = stats["kills"]
	var stars := 1
	if stats["hits"] <= 3:
		stars += 1
	if kills > 0 and (stats["heads"] + stats["slow"]) * 2 >= kills:
		stars += 1
	MenuScript.mark_stars(chapter, map, stars)
	var t := int(stats["time"])
	hud.rating(stars, ["TIME %d:%02d   KILLS %d" % [t / 60, t % 60, kills], "HEAD SHOTS %d   IN SLOWED TIME %d" % [stats["heads"], stats["slow"]], "HITS TAKEN %d" % stats["hits"]])


func _restart() -> void:''')

# map start resets the checkpoint; map clear shows the score; the prologue's death leads into chapter I
rep('''func _start_map(c: int, m: int) -> void:
	chapter = c
	map = m''', '''func _start_map(c: int, m: int) -> void:
	chapter = c
	map = m
	checkpoint = -1.0''')
rep('''	cleared = true
	MenuScript.mark_done(chapter, map)
	hud.caption(level["outro"])''', '''	cleared = true
	MenuScript.mark_done(chapter, map)
	hud.caption(level["outro"])
	_rate()''')
rep('''			chapter = next_c
			map = next_m
			in_menu = to_menu''', '''			chapter = next_c
			map = next_m
			checkpoint = -1.0
			in_menu = to_menu''')
rep('''	var killer = _nearest_enemy()
	_drop(player, signf(player.position.x - killer.position.x) if killer != null else -player.scale.x, false)
	get_tree().create_timer(1.1, true, false, true).timeout.connect(hud.banner.bind("LIGHTS OUT"))
	if _auto == "":
		get_tree().create_timer(3.4, true, false, true).timeout.connect(_restart)''', '''	var killer = _nearest_enemy()
	_drop(player, signf(player.position.x - killer.position.x) if killer != null else -player.scale.x, false)
	if _stand:   # the prologue ends as it must: Eddie down, and the story passes to Frank
		get_tree().create_timer(1.6, true, false, true).timeout.connect(hud.caption.bind(level["outro"]))
		if _auto == "":
			get_tree().create_timer(9.0, true, false, true).timeout.connect(func() -> void:
				MenuScript.mark_done(chapter, map)
				Engine.time_scale = 1.0
				chapter += 1
				map = 0
				checkpoint = -1.0
				get_tree().reload_current_scene())
		return
	get_tree().create_timer(1.1, true, false, true).timeout.connect(hud.banner.bind("LIGHTS OUT"))
	if _auto == "":
		get_tree().create_timer(3.4, true, false, true).timeout.connect(_restart)''')

open(p, 'w').write(s)
print("patched")
