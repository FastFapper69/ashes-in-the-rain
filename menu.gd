extends CanvasLayer
## The title and the case file, over the street where the story stands right now. What the
## player sees here follows the story: the street of the map they are on, Frank's line for that
## moment typed out under the title, the date and the place on the stamp. The ash thickens as
## he gets closer to the truth (main.gd sets that from phase()).

const Levels = preload("res://levels.gd")
const Paper = preload("res://paper.gd")
const Instincts = preload("res://instincts.gd")
const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const CRIMSON := Color(0.6, 0.1, 0.07)
const AMBER := Color(0.95, 0.66, 0.13)
const SAVE := "user://progress2.cfg"   # progress2: the maps were rebuilt longer, old progress no longer applies

## The save file, read once and kept in memory: the case file and the skill tree ask it hundreds of
## questions a screen. Every change is written straight back.
static var _cfg: ConfigFile = null

static func _save() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(SAVE)
	return _cfg


## A new start: everything Frank has done is forgotten; the settings stay as they are.
static func erase_progress() -> void:
	var cfg := _save()
	for sec in cfg.get_sections():
		if sec != "settings":
			cfg.erase_section(sec)
	_store()


static func _store() -> void:
	if _cfg != null:
		_cfg.save(SAVE)

# What Frank says on the title, and the stamp under it, for the point the player has reached:
# [chapter, map] of the next map to play. A later entry wins once it is reached.
const PHASES := [
	[0, 0, "December 17th, 1947. A week before Christmas.\nIt hadn't snowed yet. It only rained.", "NEW YORK  ·  DEC 17, 1947  ·  11:52 PM"],
	[1, 0, "They called me at ten past two.\nEddie was already cold. The rain was working on the rest.", "HELL'S KITCHEN  ·  DEC 18, 1947  ·  2:10 AM"],
	[1, 1, "The shooters ran east. So did I.\nI was always better at running after than running from.", "HELL'S KITCHEN  ·  DEC 18, 1947  ·  3:05 AM"],
	[1, 2, "Somebody gave up a laundry on Tenth.\nIn this town even the dirty money gets washed.", "TENTH AVENUE  ·  DEC 18, 1947  ·  4:40 AM"],
	[1, 3, "A receipt signed M. T. and a road over the roofs.\nDown below, a neon sign kept saying JAZZ.", "HELL'S KITCHEN  ·  DEC 18, 1947  ·  5:15 AM"],
	[1, 4, "The Blue Note didn't open till dark. I waited across the street all day.\nMickey Teague lost every fight he was paid to. Somebody was paying for this one too.", "THE BLUE NOTE  ·  DEC 18, 1947  ·  11:30 PM"],
	[1, 5, "I slept an hour in the car outside the Blue Note.\nLong enough for the dream. It's always the same one.", "PIER 17  ·  AUGUST 14, 1939  ·  2:10 AM"],
	[2, 0, "Rosie gave me his diary. First page, his hand:\nPier 17. Eleven dead. Who signed the report?", "PIER 17  ·  DEC 19, 1947"],
	[2, 1, "Pier 17 burned twice. Once for money, once for paper.\nThe cranes were next.", "NORTH RIVER  ·  DEC 19, 1947  ·  4:30 AM"],
	[2, 2, "A ship called Santa Lucia, and a dock master\nwho hadn't closed a door in eight years.", "THE SANTA LUCIA  ·  DEC 19, 1947  ·  5:10 AM"],
	[2, 3, "Below decks it smelled of tar and other people's prayers.", "THE SANTA LUCIA  ·  DEC 19, 1947  ·  5:50 AM"],
	[2, 4, "Kessler ran for his office.\nMen like him always run toward their paperwork.", "HARBOR MASTER  ·  DEC 19, 1947  ·  6:20 AM"],
	[2, 5, "Some fires you carry with you.\nI'd carried this one for sixteen years.", "HELL'S KITCHEN  ·  MARCH 3, 1931  ·  1:40 AM"],
	[3, 0, "They read me my rights in the rain.\nEddie would have written it down.", "10TH PRECINCT  ·  DEC 19, 1947  ·  7:00 AM"],
	[3, 1, "Briggs's men knew the stations.\nI knew the tunnels.", "UNDER 14TH STREET  ·  DEC 19, 1947  ·  8:40 AM"],
	[3, 2, "Down here the dark has a sound.\nIt sounds like trains that never come.", "THE TUNNELS  ·  DEC 19, 1947  ·  10:15 AM"],
	[3, 3, "The yard was the only way out\nthat didn't have a badge standing in it.", "TRAIN YARD  ·  DEC 19, 1947  ·  NOON"],
	[3, 4, "The last train ran out of tunnel\nunder the old Bowery.", "THE BOWERY  ·  DEC 19, 1947  ·  1:30 PM"],
	[4, 0, "Two old men in a tower were drinking to me.\nI meant to spoil it for them.", "MIDTOWN  ·  DEC 24, 1947  ·  CHRISTMAS EVE"],
]
const ENDING := ["For the first time that winter, it snowed.", "NEW YORK  ·  DEC 24, 1947"]

var play := Callable()    # func(chapter: int, map: int), set by main.gd
var restart := Callable()   # main.gd: builds the title again after the progress is erased
var sound := Callable()   # func(name: String), set by main.gd
var _chapter := 0
var _page: Control
var _type_label: Label
var _type_text := ""
var _type_t := 0.0
var _font_type: FontFile
var _font_head: FontVariation
var _on_case_file := false
# The title is a painted scene, not the game's street: one picture for each part of the story, the
# camera drifting slowly over it, rain and ash across it, its lights alive.
const KEY_ART := {0: 86, 1: 86, 2: 79, 3: 80, 4: 80}   # 86: the street in layers, the detective a layer of his own
## The lamps (gen/key_neon.py): the box each painted lamp and its cone sit in. Their glow is cut
## from the painting itself, so it has the lamp's own shape and never floats as a disc in the air.
const KEY_LAMPS := {78: [[0.70, 0.0, 0.90, 0.55]], 79: [[0.44, 0.40, 0.56, 0.80]], 80: [[0.65, 0.15, 0.76, 0.42]]}
## The painted neon (gen/key_neon.py): the box each picture's red light and its reflections sit in.
## A glow in the exact shape of the letters goes on over it, and a dark copy of those same pixels
## goes over the picture whenever the tube cuts out, so the street's red goes out with the sign.
const KEY_NEON := {86: [0.40, 0.42, 0.66, 1.0], 78: [0.40, 0.40, 0.80, 1.0], 79: [0.55, 0.72, 0.72, 0.92], 80: [0.43, 0.36, 0.56, 0.55]}
var _neon: Dictionary = {}
var _frank: TextureRect   # the detective under his lamp: nearer than the street, so he slides against it
var _frank_glow: TextureRect
var _back: Control
var _art: TextureRect
var _rain: Control
var _drops: Array = []
var _lights: Array = []
var _clock := 0.0


## Tests can set how far the player has got: --progress=N, the first N maps of the campaign done.
static func _test_progress() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--progress="):
			return int(a.substr(11))
	return -1


static func is_done(chapter: int, map: int) -> bool:
	var tp := _test_progress()
	if tp >= 0:
		var k := 0
		for c in chapter:
			k += (Levels.CAMPAIGN[c]["maps"] as Array).size()
		return k + map < tp
	var cfg := _save()
	return bool(cfg.get_value("done", "%d-%d" % [chapter, map], false))


static func mark_done(chapter: int, map: int) -> void:
	var cfg := _save()
	cfg.set_value("done", "%d-%d" % [chapter, map], true)
	_store()


static func mark_stars(chapter: int, map: int, stars: int) -> void:
	var cfg := _save()
	var key := "%d-%d" % [chapter, map]
	cfg.set_value("stars", key, maxi(stars, int(cfg.get_value("stars", key, 0))))
	_store()


static func stars(chapter: int, map: int) -> int:
	var cfg := _save()
	return int(cfg.get_value("stars", "%d-%d" % [chapter, map], 0))


## The player's settings: music and sound volume 0..10, screen shake and aim assist on or off.
const SETTING_DEFAULTS := {"music": 7, "sound": 8, "shake": true, "assist": true, "difficulty": 1, "telemetry": true, "haptics": true}

static func setting(key: String):
	var cfg := _save()
	return cfg.get_value("settings", key, SETTING_DEFAULTS[key])


static func set_setting(key: String, value) -> void:
	var cfg := _save()
	cfg.set_value("settings", key, value)
	_store()
	apply_settings()


## Volumes onto the audio buses (sfx.gd makes the Music and SFX buses).
static func apply_settings() -> void:
	for pair in [["Music", "music"], ["SFX", "sound"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			var v: float = float(setting(pair[1])) / 10.0
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)) + 0.0)
			AudioServer.set_bus_mute(i, v <= 0.0)
	if OS.has_feature("web"):   # crash.js reads these two before it sends play data or buzzes
		JavaScriptBridge.eval("try{localStorage.setItem('ashes_telemetry','%d');localStorage.setItem('ashes_haptics','%d')}catch(e){}" % [
			1 if setting("telemetry") else 0, 1 if setting("haptics") else 0], true)


## What the detective chose when it was his to choose (Briggs: "spared" or "killed").
static func set_story(key: String, value: String) -> void:
	var cfg := _save()
	cfg.set_value("story", key, value)
	_store()


static func story(key: String) -> String:
	var cfg := _save()
	return String(cfg.get_value("story", key, ""))


static func mark_page(chapter: int, map: int) -> void:
	var cfg := _save()
	cfg.set_value("pages", "%d-%d" % [chapter, map], true)
	_store()


static func has_page(chapter: int, map: int) -> bool:
	var cfg := _save()
	return bool(cfg.get_value("pages", "%d-%d" % [chapter, map], false))


## How many of Eddie's pages have been found in a chapter.
static func pages(chapter: int) -> int:
	var n := 0
	for m in Levels.CAMPAIGN[chapter]["maps"].size():
		if has_page(chapter, m):
			n += 1
	return n


## A map can be played once the one before it (in this chapter, or the last of the chapter before) is done.
static func is_open(chapter: int, map: int) -> bool:
	if not Levels.CAMPAIGN[chapter]["ready"]:
		return false
	if map > 0:
		return is_done(chapter, map - 1)
	if chapter == 0:
		return true
	return is_done(chapter - 1, Levels.CAMPAIGN[chapter - 1]["maps"].size() - 1)


## The next map to play, in story order: [chapter, map]. [-1, -1] once every map there is, is done.
static func progress() -> Array:
	for c in Levels.CAMPAIGN.size():
		if not Levels.CAMPAIGN[c]["ready"]:
			return [c, 0]
		for m in Levels.CAMPAIGN[c]["maps"].size():
			if not is_done(c, m):
				return [c, m]
	return [-1, -1]


## Frank's line and the stamp for where the story stands.
static func phase() -> Array:
	var p := progress()
	if p[0] < 0:
		return ENDING
	var best: Array = PHASES[0]
	for ph in PHASES:
		if ph[0] < p[0] or (ph[0] == p[0] and ph[1] <= p[1]):
			best = ph
	return [best[2], best[3]]


## How thick the ash hangs over the title: thin at the start, heavier the closer Frank gets.
static func ash_level() -> float:
	var p := progress()
	if p[0] < 0:
		return 0.0
	return clampf(0.25 + p[0] * 0.18 + p[1] * 0.03 + guilt() * 0.04, 0.25, 1.0)


## Frank's conduct on a map, kept from the last time he closed it: men shot while giving up, and men
## let go. Never shown as a number: the city shows it (ash in the air, greyer rain, harder lines).
static func set_conduct(chapter: int, map: int, executed: int, spared: int) -> void:
	var cfg := _save()
	var key := "%d-%d" % [chapter, map]
	cfg.set_value("executed", key, executed)
	cfg.set_value("spared", key, spared)
	_store()


static func _sum(section: String) -> int:
	var cfg := _save()
	var n := 0
	if cfg.has_section(section):
		for k in cfg.get_section_keys(section):
			n += int(cfg.get_value(section, k, 0))
	return n


## The ash: every man shot with his hands up weighs on Frank; every man let go takes a little off.
static func guilt() -> int:
	for a in OS.get_cmdline_user_args():   # tests: --guilt=N
		if a.begins_with("--guilt="):
			return int(a.trim_prefix("--guilt="))
	return maxi(0, _sum("executed") * 2 - _sum("spared"))


static func spared_total() -> int:
	return _sum("spared")


## What Frank holds against the Saint at the end: Eddie's pages found and statements heard.
static func evidence() -> int:
	var n := 0
	for c in Levels.CAMPAIGN.size():
		for m in Levels.CAMPAIGN[c]["maps"].size():
			n += 1 if has_page(c, m) else 0
			n += 1 if story("testimony_%d-%d" % [c, m]) == "yes" else 0
	return n


## The ending the player has earned so far: "snow" (low ash, Briggs alive, at least half the
## evidence) or "ash". Chapter IV reads this when it is built.
static func evidence_total() -> int:
	var total := 0
	for c in Levels.CAMPAIGN.size():
		for mp in Levels.CAMPAIGN[c]["maps"]:
			total += 0 if mp.get("dream", false) or mp.get("memory", false) else 2
	return total


static func ending() -> String:
	var total := evidence_total()
	if guilt() < 4 and story("briggs") == "spared" and evidence() * 2 >= total:
		return "snow"
	return "ash"


func _ready() -> void:
	layer = 20
	Paper.wear = clampf(guilt() / 10.0, 0.0, 1.0)
	_font_type = load("res://fonts/SpecialElite.ttf")
	_font_head = FontVariation.new()
	_font_head.base_font = load("res://fonts/Oswald.ttf")
	_font_head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	for c in Levels.CAMPAIGN.size():   # the case file opens on the furthest chapter that is open
		if is_open(c, 0):
			_chapter = c
	_make_back()
	_title()
	# a phone turned while the title is up: lay the page out again for the new shape
	get_viewport().size_changed.connect(func() -> void:
		if _on_case_file:
			_case_file()
		else:
			_title())


func _process(delta: float) -> void:
	_tick_back(delta)
	if _type_label == null or not is_instance_valid(_type_label):
		return
	if _type_label.visible_characters < _type_text.length():
		_type_t += delta
		while _type_t > 0.034 and _type_label.visible_characters < _type_text.length():   # a key at a time, a breath at each stop
			_type_t -= 0.034
			_type_label.visible_characters += 1
			var ch := _type_text[_type_label.visible_characters - 1]
			if ch in ".,:\n":
				_type_t = -0.25
			if ch != " " and ch != "\n" and sound.is_valid():
				sound.call("type")


## The painted scene behind the title and the case file.
func _make_back() -> void:
	_back = Control.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_child(black)
	var ch := maxi(0, progress()[0])
	var img: int = KEY_ART.get(ch, 78)
	if progress() == [2, 5]:   # the memory between II and III has its own picture: the block on fire, 1931
		img = 87
	for a in OS.get_cmdline_user_args():   # the tests can pick a picture
		if a.begins_with("--key="):
			img = int(a.substr(6))
	_art = TextureRect.new()
	_art.texture = load("res://art/ui/key_%d.jpg" % img)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.modulate = Color(0, 0, 0)
	_back.add_child(_art)
	create_tween().tween_property(_art, "modulate", Color.WHITE, 2.5)   # out of the dark
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var lamps: Array = KEY_LAMPS.get(img, [])
	for i in lamps.size():
		var g := TextureRect.new()
		g.texture = load("res://art/ui/key_%d_lamp%d.png" % [img, i])
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_SCALE
		g.material = add
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate = Color(1.0, 0.85, 0.6, 0.0)
		_art.add_child(g)
		_lights.append({"node": g, "box": lamps[i], "phase": randf() * TAU})
	if KEY_NEON.has(img):
		var off := TextureRect.new()
		off.texture = load("res://art/ui/key_%d_off.png" % img)
		var glow := TextureRect.new()
		glow.texture = load("res://art/ui/key_%d_glow.png" % img)
		glow.material = add
		glow.modulate = Color(1.0, 0.22, 0.14, 0.0)
		off.modulate.a = 0.0
		for n in [off, glow]:
			n.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			n.stretch_mode = TextureRect.STRETCH_SCALE
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_art.add_child(n)
		_neon = {"off": off, "glow": glow, "box": KEY_NEON[img], "next": randf_range(2.5, 5.0), "dip": 0.0}
	if img == 86:
		_frank = TextureRect.new()
		_frank.texture = load("res://art/ui/menu/frank.png")
		_frank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frank.stretch_mode = TextureRect.STRETCH_SCALE
		_frank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frank.modulate = Color(0, 0, 0)
		_back.add_child(_frank)
		create_tween().tween_property(_frank, "modulate", Color.WHITE, 2.5)
		_frank_glow = TextureRect.new()   # the lantern's light, cut from the lantern itself
		_frank_glow.texture = load("res://art/ui/menu/frank_glow.png")
		_frank_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_frank_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_frank_glow.material = add
		_frank_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frank_glow.modulate = Color(1.0, 0.8, 0.5, 0.0)
		_frank.add_child(_frank_glow)
	var ash := CPUParticles2D.new()   # the ash, thicker the further the story has gone
	ash.texture = load("res://art/light_blob.png")
	ash.amount = int(20 + 50 * ash_level())
	ash.lifetime = 12.0
	ash.preprocess = 12.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.direction = Vector2(0.3, 1.0)
	ash.spread = 25.0
	ash.gravity = Vector2(6.0, 10.0)
	ash.initial_velocity_min = 20.0
	ash.initial_velocity_max = 45.0
	ash.scale_amount_min = 0.025
	ash.scale_amount_max = 0.06
	ash.color = Color(0.75, 0.74, 0.72, 0.55)
	ash.name = "Ash"
	_back.add_child(ash)
	_rain = Control.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	_back.add_child(_rain)
	for k in 190:
		_drops.append(Vector3(randf() * 1.2, randf(), randf_range(0.3, 1.0)))
	var vig := TextureRect.new()   # the corners fall away into black, like the end of a lamp's reach
	var vg := GradientTexture2D.new()
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.55, 0.45)
	vg.fill_to = Vector2(1.15, 1.1)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.add_point(0.5, Color(0, 0, 0, 0))
	gr.set_color(gr.get_point_count() - 1, Color(0, 0, 0, 0.7))
	vg.gradient = gr
	vig.texture = vg
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_child(vig)


func _tick_back(delta: float) -> void:
	if _art == null:
		return
	_clock += delta
	var view := get_viewport().get_visible_rect().size
	var tex := _art.texture.get_size()
	# a slow push in and drift, never showing an edge: a camera breathing over the picture
	var zoom := 1.06 + 0.04 * sin(_clock * 0.05)
	var sc := maxf(view.x / tex.x, view.y / tex.y) * zoom
	var size := tex * sc
	_art.size = size
	var slack := size - view
	_art.position = -slack * Vector2(0.5 + 0.45 * sin(_clock * 0.037), 0.5 + 0.4 * sin(_clock * 0.029 + 1.0))
	for l in _lights:   # a lamp breathes a little in the wet air
		var n: TextureRect = l["node"]
		var b: Array = l["box"]
		n.position = Vector2(float(b[0]), float(b[1])) * size
		n.size = Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])) * size
		n.modulate.a = 0.35 + 0.1 * sin(_clock * 1.3 + float(l["phase"])) + 0.04 * sin(_clock * 7.0 + float(l["phase"]))
	if _frank != null:   # nearer the eye: he moves the other way, half as far again
		var fh := view.y * 1.16
		var fw := fh * _frank.texture.get_width() / _frank.texture.get_height()
		_frank.size = Vector2(fw, fh)
		_frank.position = Vector2(view.x * 0.8 - fw * 0.5 - view.x * 0.022 * sin(_clock * 0.037), view.y * 0.035 - view.y * 0.012 * sin(_clock * 0.029 + 1.0))
		_frank_glow.position = Vector2(fw * 0.6, 0.0)
		_frank_glow.size = Vector2(fw * 0.4, fh * 0.26)
		_frank_glow.modulate.a = 0.5 + 0.06 * sin(_clock * 1.3) + 0.03 * sin(_clock * 7.0)
	if not _neon.is_empty():
		var b: Array = _neon["box"]
		var lit := 0.94 + 0.06 * sin(_clock * 53.0)   # the hum of a tube
		_neon["next"] = float(_neon["next"]) - delta
		if float(_neon["next"]) <= 0.0:
			_neon["next"] = randf_range(3.0, 7.0)
			_neon["dip"] = randf_range(0.18, 0.5)
		if float(_neon["dip"]) > 0.0:   # it stutters: off, on, off
			_neon["dip"] = float(_neon["dip"]) - delta
			lit = 0.05 if fmod(float(_neon["dip"]), 0.13) < 0.07 else 0.8
		for key in ["off", "glow"]:
			var n: TextureRect = _neon[key]
			n.position = Vector2(float(b[0]), float(b[1])) * size
			n.size = Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])) * size
		(_neon["glow"] as TextureRect).modulate.a = 0.55 * lit
		(_neon["off"] as TextureRect).modulate.a = 1.0 - lit
	var ash: CPUParticles2D = _back.get_node("Ash")
	ash.position = Vector2(view.x * 0.5, -40.0)
	ash.emission_rect_extents = Vector2(view.x * 0.7, 20.0)
	for k in _drops.size():
		var d: Vector3 = _drops[k]
		d.y += delta * (0.9 + d.z * 1.6)
		d.x -= delta * (0.08 + d.z * 0.12)
		if d.y > 1.1:
			d = Vector3(randf() * 1.2, -0.1 - randf() * 0.2, d.z)
		_drops[k] = d
	_rain.queue_redraw()


func _draw_rain() -> void:
	var view := get_viewport().get_visible_rect().size
	for d in _drops:
		var p := Vector2(d.x * view.x, d.y * view.y)
		var ln: float = 18.0 + d.z * d.z * 70.0
		_rain.draw_line(p, p + Vector2(-0.14, 1.0).normalized() * ln, Color(0.85, 0.87, 0.92, 0.05 + 0.15 * d.z), 0.8 + d.z * 1.4)


func _label(text: String, font: Font, font_size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _new_page() -> Vector2:
	if _page != null:
		_page.queue_free()
	var view := get_viewport().get_visible_rect().size
	_page = Control.new()
	_page.size = view
	add_child(_page)
	return view


const M := 48.0     # the margin round every screen
const GAP := 16.0   # between papers in a group
const TILT := [-1.2, 0.8, -0.6, 1.1, -0.9, 0.5]   # each paper a little askew, the same each time


## A paper button on the page.
func _paper(kind: String, at: Vector2, size: Vector2, tilt: float, on_press: Callable) -> Control:
	var b: Control = Paper.button(kind, size, on_press, sound)
	b.position = at
	b.rotation = deg_to_rad(tilt)
	_page.add_child(b)
	return b


## The title: the logo, and under it one police report with everything to do typed on it: the case in
## hand and the one main action, then the case file and the settings. A place and time caption sits down on the street.
func _title() -> void:
	_on_case_file = false
	var view := _new_page()
	if view.x < view.y:   # held upright: the game is played sideways
		_portrait_note(view)
		return
	var shade := TextureRect.new()   # the left of the street darkened so the words read; the right stays open
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.86))
	g.add_point(0.45, Color(0.0, 0.0, 0.0, 0.55))
	g.set_color(g.get_point_count() - 1, Color(0.0, 0.0, 0.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.5, 0.0)
	shade.texture = gt
	shade.size = view
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shade)

	var logo := TextureRect.new()
	logo.texture = load("res://art/ui/title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var aspect := float(logo.texture.get_width()) / logo.texture.get_height()
	var lh := 214.0
	logo.size = Vector2(lh * aspect, lh)
	logo.position = Vector2(M, 30.0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.modulate.a = 0.0
	_page.add_child(logo)
	logo.create_tween().tween_property(logo, "modulate:a", 1.0, 1.6).set_delay(1.2)

	# Everything to do is typed on one police report, clipped together: the case in hand, then the
	# one main action in big letters, then the case file and the settings. One paper, one hand.
	var ph := phase()
	var p := progress()
	var y := 30.0 + lh + GAP
	var rh := view.y - M - y
	var report: Control = Paper.sheet("report", Vector2(rh * 789.0 / 1129.0, rh))
	report.position = Vector2(M, y)
	report.rotation = deg_to_rad(TILT[0])
	_page.add_child(report)
	var papers: Array = [report]
	# the parts of the sheet (fractions of its text area), measured on the drawing: above the header
	# rule, clear of the clip; the big line under it; two lines either side of the fold
	const HEAD := Rect2(0, 0.036, 0.74, 0.093)
	const MAIN := Rect2(0, 0.178, 1, 0.184)
	const LINE_1 := Rect2(0, 0.405, 1, 0.115)
	const LINE_2 := Rect2(0, 0.565, 1, 0.115)
	const LINE_3 := Rect2(0, 0.725, 1, 0.115)
	if p[0] >= 0 and Levels.CAMPAIGN[p[0]]["ready"]:   # the one main action: the biggest line
		var ch: Dictionary = Levels.CAMPAIGN[p[0]]
		var what := "BEGIN" if p[0] == 0 and p[1] == 0 else "CONTINUE"
		Paper.write(report, String(ch["maps"][p[1]]["name"]), _font_type, 17, Color(INK, 0.85), HORIZONTAL_ALIGNMENT_LEFT, HEAD, 6.0)
		var go := Paper.write(report, what, _font_head, 50, INK, HORIZONTAL_ALIGNMENT_LEFT, MAIN, 8.0)
		Paper.line_button(report, go, MAIN, func() -> void: play.call(p[0], p[1]), sound)
	elif p[0] >= 0:   # caught up with the story: the sheet says what comes next, and is not a button
		var ch: Dictionary = Levels.CAMPAIGN[p[0]]
		Paper.write(report, String(ch["title"]), _font_type, 17, Color(INK, 0.85), HORIZONTAL_ALIGNMENT_LEFT, HEAD, 6.0)
		Paper.write(report, "TO BE CONTINUED", _font_head, 28, INK, HORIZONTAL_ALIGNMENT_LEFT, MAIN, 8.0)
	var cf := Paper.write(report, "CASE FILE", _font_head, 30, CRIMSON, HORIZONTAL_ALIGNMENT_LEFT, LINE_1, 8.0)
	Paper.line_button(report, cf, LINE_1, _case_file, sound)
	var st_line := LINE_2
	if Instincts.reached(1):   # Frank's board, right on the sheet once the story is his
		var left := Instincts.unspent()
		var il := Paper.write(report, "INSTINCTS", _font_head, 30, CRIMSON if left > 0 else INK, HORIZONTAL_ALIGNMENT_LEFT, LINE_2, 8.0)
		Paper.line_button(report, il, LINE_2, _instincts.bind(_title), sound)
		if left > 0:   # how many leads wait to be spent, typed small at the end of the line
			Paper.write(report, "%d POINTS" % left, _font_type, 17, CRIMSON, HORIZONTAL_ALIGNMENT_RIGHT, LINE_2, 10.0).set_meta("decor", true)
		st_line = LINE_3
	var st_l := Paper.write(report, "SETTINGS", _font_head, 30, INK, HORIZONTAL_ALIGNMENT_LEFT, st_line, 8.0)
	Paper.line_button(report, st_l, st_line, _open_settings, sound)
	for k in papers.size():   # they come out of the dark one after another
		var n: Control = papers[k]
		n.modulate.a = 0.0
		n.create_tween().tween_property(n, "modulate:a", 1.0, 0.6).set_delay(1.6 + k * 0.15)

	var cap := Paper.caption(Paper.place_time(String(ph[1])), _font_caption(), 19)   # where and when: a comic's location caption
	cap.position = Vector2(view.x * 0.4, view.y - M - cap.size.y)
	cap.rotation = deg_to_rad(-0.6)
	_page.add_child(cap)
	# the build the player is on, on a tag in the corner: tapped, what changed lately (whatsnew.gd, changelog.gd)
	var WN = load("res://whatsnew.gd")
	var tag: Control = Paper.button("tag", Vector2(250.0, 104.0), _open_whatsnew, sound)
	tag.position = Vector2(view.x - M - tag.size.x, view.y - M - tag.size.y)
	tag.rotation = deg_to_rad(1.2)
	_page.add_child(tag)
	Paper.write(tag, "WHAT'S NEW", _font_head, 22, CRIMSON, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0, 1, 0.5), 6.0)
	Paper.write(tag, WN.build_text(), _font_type, 16, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0.5, 1, 0.5), 6.0)   # (the date is on the card)


var _cap_font: Font
func _font_caption() -> Font:
	if _cap_font == null:
		_cap_font = load("res://fonts/ComicNeue-BoldItalic.woff")
	return _cap_font


## The case file: one chapter at a time, its maps as comic panels pinned in a row.
func _case_file() -> void:
	_on_case_file = true
	var view := _new_page()
	if view.x < view.y:
		_portrait_note(view)
		return
	_type_label = null
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.size = view
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shade)

	var ch: Dictionary = Levels.CAMPAIGN[_chapter]
	var head_y := 34.0
	var t1 := _label(String(ch["title"]), _font_type, 22, Color(0.78, 0.75, 0.68), 6)
	t1.position = Vector2(0.0, head_y)
	t1.size = Vector2(view.x, 30.0)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(t1)
	var t2 := _label(String(ch["name"]), _font_head, 50, PAPER, 12)
	t2.position = Vector2(0.0, head_y + 30.0)
	t2.size = Vector2(view.x, 70.0)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(t2)
	for side in [-1, 1]:   # turning the pages of the file: the tape says where it goes
		var to: int = _chapter + side
		if to < 0 or to >= Levels.CAMPAIGN.size():
			continue
		var name_to := String(Levels.CAMPAIGN[to]["title"])
		var tw := 220.0
		var at := Vector2(M if side < 0 else view.x - M - tw, head_y + 30.0)
		var b := _paper("tape", at, Vector2(tw, 60.0), TILT[3] if side < 0 else TILT[4], func() -> void:
			_chapter = to
			_case_file())
		Paper.write(b, ("\u2039  " + name_to) if side < 0 else (name_to + "  \u203a"), _font_head, 22, INK)

	var maps: Array = ch["maps"]
	var gap := 24.0
	var w := minf(214.0, (view.x - 2.0 * M - gap * (maps.size() - 1)) / maps.size())
	var h: float = roundf(w * 1.5)
	var x0 := (view.x - (w * maps.size() + gap * (maps.size() - 1))) * 0.5
	var y0 := 150.0
	for m in maps.size():
		var open := is_open(_chapter, m)
		var done := is_done(_chapter, m)
		var now: bool = open and not done and bool(ch["ready"])
		var at := Vector2(x0 + m * (w + gap), y0)
		var card: Control
		if open and ch["ready"]:
			card = _paper("panel", at, Vector2(w, h), TILT[m % TILT.size()], func() -> void: play.call(_chapter, m))
		else:
			card = Paper.sheet("panel", Vector2(w, h))
			card.position = at
			card.rotation = deg_to_rad(TILT[m % TILT.size()])
			_page.add_child(card)
			(card.get_node("Drawing") as TextureRect).modulate = Color(0.58, 0.56, 0.53)   # an unopened file, in the dark
		var ink: Color = INK
		Paper.write(card, str(m + 1), _font_head, 64, ink, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0, 1, 0.36), 4.0)
		Paper.write(card, String(maps[m]["name"]), _font_head, 22, ink, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.36, 1, 0.28), 10.0)   # (audit 17. 11.: the typed name read too small on a phone)
		var low := Rect2(0, 0.64, 1, 0.36)
		if not ch["ready"]:
			Paper.write(card, "SOON", _font_head, 30, Color(0.1, 0.1, 0.1), HORIZONTAL_ALIGNMENT_CENTER, low, 10.0)
		elif done:   # a closed case: the stamp, and the marks it earned
			var st := Paper.write(card, "CLOSED", _font_head, 32, CRIMSON, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.64, 1, 0.2), 8.0)
			st.pivot_offset = st.size * 0.5
			st.rotation = deg_to_rad(-5.0)
			_stars(card, Rect2(0, 0.84, 1, 0.16), stars(_chapter, m))
		elif now:   # the next case: the one thing to do on this screen
			Paper.write(card, "PLAY", _font_head, 40, CRIMSON, HORIZONTAL_ALIGNMENT_CENTER, low, 10.0)
			card.scale = Vector2(1.05, 1.05)
			card.z_index = 1
		else:   # locked: it says why
			Paper.write(card, "LOCKED\nCLOSE CASE %d FIRST" % m, _font_head, 20, INK, HORIZONTAL_ALIGNMENT_CENTER, low, 10.0)

	if not ch["ready"]:
		var soon := _label("THE INVESTIGATION CONTINUES SOON", _font_type, 24, PAPER, 6)
		soon.position = Vector2(0.0, y0 + h + 34.0)
		soon.size = Vector2(view.x, 34.0)
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page.add_child(soon)
	var back := _paper("tape", Vector2(M, view.y - M - 60.0), Vector2(180.0, 60.0), TILT[5], _title)
	Paper.write(back, "BACK", _font_head, 24, INK)
	if Instincts.reached(1):   # Frank's board, once the story is his
		var left := Instincts.unspent()
		var ib := _paper("tape", Vector2(view.x - M - 300.0, view.y - M - 60.0), Vector2(300.0, 60.0), TILT[2], _instincts.bind(_case_file))
		Paper.write(ib, "INSTINCTS" if left == 0 else "INSTINCTS (%d POINTS)" % left, _font_head, 24, CRIMSON if left > 0 else INK)


## The marks a closed case earned, inked like a rubber stamp: up to three stars, the rest outlined.
## Frank's instincts: a cork board, one row of index cards per branch, pinned with red yarn between
## the cards he has. A card he can have says what it costs; one he cannot says why.
func _instincts(back_to := Callable()) -> void:
	_on_case_file = true
	if back_to.is_valid():
		_instincts_back = back_to
	elif not _instincts_back.is_valid():
		_instincts_back = _case_file
	var view := _new_page()
	if view.x < view.y:
		_portrait_note(view)
		return
	var board := TextureRect.new()
	board.texture = load("res://art/ui/instincts/board.jpg")
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	board.size = view
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(board)
	var title := _label("FRANK'S INSTINCTS", _font_head, 44, PAPER, 12)
	title.position = Vector2(0.0, 14.0)
	title.size = Vector2(view.x, 56.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(title)
	var r := Instincts.rank()
	var lv := Instincts.level()
	var line := "LEVEL %d        %d / %d XP        POINTS %d        TAKES %d HITS" % [lv, Instincts.xp(), Instincts.xp_for(lv + 1), Instincts.unspent(), r[0]]
	var sub := _label(line, _font_type, 20, PAPER, 6)
	sub.position = Vector2(0.0, 82.0)
	sub.size = Vector2(view.x, 28.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(sub)

	var tag_w := 130.0
	var gap := 14.0
	var top := 122.0
	var bottom := view.y - M - 60.0 - 16.0
	var cols := 5   # (audit 21. 11.: SECOND WIND, the sixth trick, was never on the board)
	for b in Instincts.BOARD:
		cols = maxi(cols, Instincts.tiers(b))
	var h := minf((bottom - top - 2.0 * 12.0) / 3.0, ((view.x - 2.0 * M - tag_w - GAP - (cols - 1) * gap) / cols) * 1096.0 / 1496.0)
	var w := roundf(h * 1496.0 / 1096.0)
	h = roundf(h)
	var x0 := (view.x - (tag_w + GAP + cols * w + (cols - 1) * gap)) * 0.5
	var rows := ["frank", "guns", "instinct"]
	for bi in 3:
		var branch: String = rows[bi]
		var y := top + bi * (h + 12.0)
		var tag := Paper.sheet("tag", Vector2(tag_w, 64.0))
		tag.position = Vector2(x0, y + (h - 64.0) * 0.5)
		tag.rotation = deg_to_rad(TILT[bi + 2])
		_page.add_child(tag)
		Paper.write(tag, "GUNS" if branch == "guns" else String(Instincts.BRANCH_NAMES[branch]), _font_head, 18, INK)
		if branch == "guns":   # the guns are upgraded at the gunsmith: one wide sheet that opens it
			var gw := cols * w + (cols - 1) * gap
			var smith := _paper("panel", Vector2(x0 + tag_w + GAP, y), Vector2(gw, h), TILT[4] * 0.4, func() -> void:
				_smith_back = _instincts
				_gunsmith("gun", 0))
			var inner: Rect2 = smith.get_meta("inner")
			var icons := ["revolver", "shotgun", "tommy"]
			for k in icons.size():
				var open := Instincts.reached(int(Instincts.GUN_FROM[Instincts.GUNS[k]]))
				var ic := TextureRect.new()
				ic.texture = load("res://art/ui/gun_%s.png" % icons[k])
				ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ic.position = inner.position + Vector2(inner.size.x * (0.03 + k * 0.16), inner.size.y * 0.1)
				ic.size = Vector2(inner.size.x * 0.15, inner.size.y * 0.8)
				ic.modulate = Color.WHITE if open else Color(0.4, 0.38, 0.36)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ic.set_meta("decor", true)
				smith.add_child(ic)
			var fitted := 0
			for g in Instincts.GUNS:
				for t in Instincts.tiers(g):
					fitted += 1 if Instincts.owned(g, t) else 0
			Paper.write(smith, "THE GUNSMITH", _font_head, 26, CRIMSON, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0.52, 0.08, 0.48, 0.46))
			Paper.write(smith, "%d FITTED" % fitted, _font_head, 18, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0.52, 0.54, 0.48, 0.38))
			if smith.has_node("Hit"):
				smith.move_child(smith.get_node("Hit"), smith.get_child_count() - 1)
			continue
		var pins: Array = []
		for t in Instincts.tiers(branch):
			var at := Vector2(x0 + tag_w + GAP + t * (w + gap), y)
			var why := Instincts.why_locked(branch, t)
			var have := Instincts.owned(branch, t)
			# every card can be picked up and read: the board shows its name and where it stands
			var card := _paper("card", at, Vector2(w, h), TILT[(t + bi) % TILT.size()] * 0.6, _card_detail.bind(branch, t))
			if not have and why != "":
				(card.get_node("Drawing") as TextureRect).modulate = Color(0.62, 0.6, 0.57)
			var info: Array = Instincts.CARDS[branch][t]
			_card_icon(card, branch, t, Rect2(0.0, 0.0, 0.34, 0.66))
			Paper.write(card, String(info[0]), _font_head, 17, INK, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0.34, 0.0, 0.66, 0.62), 4.0)
			var foot := "PINNED" if have else ("LOCKED" if why != "" else "READY")
			Paper.write(card, foot, _font_head, 17, CRIMSON if (have or why == "") else INK, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.66, 1, 0.3), 4.0)
			if have:   # the head of the card's own pin, turned with the card
				var half := Vector2(w, h) * 0.5
				pins.append(at + half + (Vector2(w * 0.535, h * 0.06) - half).rotated(card.rotation))
		if pins.size() > 1:   # red yarn from pin to pin along what he has
			var yarn := Line2D.new()
			yarn.texture = load("res://art/ui/instincts/yarn.png")
			yarn.texture_mode = Line2D.LINE_TEXTURE_TILE
			yarn.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			yarn.width = 9.0
			yarn.default_color = Color(1, 1, 1)
			yarn.joint_mode = Line2D.LINE_JOINT_ROUND
			for i in pins.size():   # it hangs a little between the pins, the way yarn does
				yarn.add_point(pins[i])
				if i + 1 < pins.size():
					for k in range(1, 6):
						var u := k / 6.0
						yarn.add_point((pins[i] as Vector2).lerp(pins[i + 1], u) + Vector2(0.0, 14.0 * sin(PI * u)))
			_page.add_child(yarn)

	var back := _paper("tape", Vector2(M, view.y - M - 60.0), Vector2(180.0, 60.0), TILT[5], _instincts_back)
	Paper.write(back, "BACK", _font_head, 24, INK)
	if Instincts.spent() > 0:
		var reset := _paper("tape", Vector2(view.x - M - 300.0, view.y - M - 60.0), Vector2(300.0, 60.0), TILT[1], func() -> void:
			for b in Instincts.BRANCHES:
				Instincts.unpin(b, 0)
			_instincts())
		Paper.write(reset, "TAKE ALL CARDS DOWN", _font_head, 22, INK)


var _instincts_back := Callable()


## WHAT'S NEW over the title: the build and the latest changes.
func _open_whatsnew() -> void:
	var wn = load("res://whatsnew.gd").new()
	wn.sound = sound
	_page.visible = false
	wn.done = func() -> void: _page.visible = true
	add_child(wn)


## The settings card over the title, with the one thing only the title offers: erasing the progress.
func _open_settings() -> void:
	var st = load("res://settings.gd").new()
	st.sound = sound
	st.erase = _erase
	_page.visible = false
	st.done = func() -> void: _page.visible = true
	add_child(st)


## Progress wiped: the title is built again from nothing, the street back at the prologue.
func _erase() -> void:
	erase_progress()
	Instincts.forget()
	# give the browser a moment to write the wiped save down before the scene goes (on the web the
	# file reaches the phone's storage a beat after it is closed; a reload right away could lose it)
	await get_tree().create_timer(0.8, true, false, true).timeout
	if restart.is_valid():
		restart.call()
	else:
		_title()


func _pin_card(branch: String, tier: int) -> void:
	if Instincts.owned(branch, tier):
		Instincts.unpin(branch, tier)
	else:
		Instincts.pin(branch, tier)
	_instincts()


## A card's drawing (art/ui/instincts/icon_<branch><tier>.png, art_src 142), fitted into `part` of the
## card's inner area, greyed when the card is locked.
func _card_icon(card: Control, branch: String, tier: int, part: Rect2) -> void:
	var path := "res://art/ui/instincts/icon_%s.png" % String(Instincts.CARDS[branch][tier][3])
	if not ResourceLoader.exists(path):
		return
	var inner: Rect2 = card.get_meta("inner")
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.position = inner.position + inner.size * part.position
	r.size = inner.size * part.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta("decor", true)
	if not Instincts.owned(branch, tier) and Instincts.why_locked(branch, tier) != "":
		r.modulate = Color(0.55, 0.53, 0.5)
	card.add_child(r)


## One card picked up off the board: big enough to read on a phone, with what it does, what it
## costs or why it is locked, and the one thing to do with it.
func _card_detail(branch: String, tier: int) -> void:
	var view := get_viewport().get_visible_rect().size
	var layer := Control.new()
	layer.size = view
	_page.add_child(layer)
	var dim := ColorRect.new()   # the board steps back
	dim.color = Color(0, 0, 0, 0.62)
	dim.size = view
	layer.add_child(dim)
	var info: Array = Instincts.CARDS[branch][tier]
	var have := Instincts.owned(branch, tier)
	var why := Instincts.why_locked(branch, tier)
	var h := minf(view.y - 2.0 * M - 76.0, 470.0)
	var w := roundf(h * 1496.0 / 1096.0)
	var card := Paper.sheet("card", Vector2(w, h))
	card.position = Vector2((view.x - w) * 0.5, M)
	layer.add_child(card)
	Paper.write(card, String(info[0]), _font_head, 40, INK, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.0, 1, 0.22), 8.0)
	_card_icon(card, branch, tier, Rect2(0.02, 0.24, 0.36, 0.48))   # the evidence photo pinned on it
	Paper.write(card, String(info[1]), _font_type, 26, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0.4, 0.24, 0.6, 0.48), 8.0)
	var price := "1 POINT"
	var foot := "PINNED ON THE BOARD" if have else (why if why != "" else "COSTS " + price)
	Paper.write(card, foot, _font_head, 24, CRIMSON, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.74, 1, 0.24), 8.0)
	var y := M + h + 16.0
	var close := func() -> void: layer.queue_free()
	var lone := not (have or why == "")
	var back := _paper("tape", Vector2(view.x * 0.5 - (110.0 if lone else 236.0), y), Vector2(220.0, 60.0), TILT[5], close)
	back.reparent(layer)
	Paper.write(back, "BACK", _font_head, 24, INK)
	if have or why == "":
		var act := _paper("tape", Vector2(view.x * 0.5 + 16.0, y), Vector2(260.0, 60.0), TILT[1], _pin_card.bind(branch, tier))
		act.reparent(layer)
		Paper.write(act, "TAKE IT DOWN" if have else "PIN IT", _font_head, 26, CRIMSON if not have else INK)


func _stars(card: Control, part: Rect2, n: int) -> void:
	var inner: Rect2 = card.get_meta("inner")
	var area := Rect2(inner.position + inner.size * part.position, inner.size * part.size)
	var c := Control.new()
	c.position = area.position
	c.size = area.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r := minf(area.size.y * 0.36, 11.0)
		for i in 3:
			var at := Vector2(area.size.x * 0.5 + (i - 1) * r * 2.8, area.size.y * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(at + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.42))
			if i < n:
				c.draw_colored_polygon(pts, CRIMSON)
			else:
				pts.append(pts[0])
				c.draw_polyline(pts, Color(CRIMSON, 0.7), 1.6, true))
	card.add_child(c)
	if card.has_node("Hit"):
		card.move_child(card.get_node("Hit"), card.get_child_count() - 1)


## Upright phone: the title, small, and a word to turn it sideways.
func _portrait_note(view: Vector2) -> void:
	_type_label = null
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.85)
	shade.size = view
	_page.add_child(shade)
	var logo := TextureRect.new()
	logo.texture = load("res://art/ui/title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size = Vector2(view.x * 0.8, view.x * 0.8 * logo.texture.get_height() / logo.texture.get_width())
	logo.position = Vector2(view.x * 0.1, view.y * 0.18)
	_page.add_child(logo)
	var l := _label("Turn your phone sideways.", _font_type, 52, PAPER, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(view.x * 0.1, logo.position.y + logo.size.y + 60.0)
	l.size = Vector2(view.x * 0.8, 100.0)
	_page.add_child(l)


# ---------------------------------------------------------------------------------------------------
## THE GUNSMITH: a gun drawn big over a comic burst, its upgrades on paper strips at the right. Picking
## one swings the drawing round onto the part it changes, rings it in ink and works it: the revolver's
## cylinder swings out, the shotgun's shells go in, the tommy gun takes its drum. Points are the same as
## the board's (instincts.gd: rows "gun", "shotgun", "tommy").
# The side guns in parts (gen/gun_parts.py, art/ui/gunsmith/parts): every part worn until its card is
# fitted, then new; fitting knocks the old part off and slides the new one in. [part, offset on the
# 1300 x 726 drawing], in the order of the gun's cards; a fifth card is the second gun.
const SMITH_SIZE := Vector2(1300.0, 726.0)
const SMITH_PIECES := {
	"gun": [["cylinder", Vector2(491.3, 87.4)], ["barrel", Vector2(817.7, 41.6)], ["grip", Vector2(85.0, 302.3)], ["frame", Vector2(83.6, 34.5)]],
	"beretta": [["frame", Vector2(132.3, 95.4)], ["slide", Vector2(199.8, 45.8)], ["grip", Vector2(157.3, 205.0)], ["plate", Vector2(135.1, 619.3)]],
}
var _smith_pieces := {}   # part -> its Sprite2D on the stage
const SMITH_ART := {"gun": ["revolver", "revolver_open"], "beretta": ["revolver", "revolver"], "shotgun": ["shotgun", "shotgun_open"], "tommy": ["tommy", "tommy_drum"]}
## The big guns' drawings as they are now (rule 28, gen/big_gun_states.py): the shotgun's tube short or long,
## the tommy gun's stick or drum and plain muzzle or compensator - every view shows the parts fitted, nothing
## else. The second drawing is what the picked card shows at work: the part fitted (a preview of it), or for
## BUCKSHOT the open action with the same tube.
func _big_art(gun: String, pick: int, fitted_too := false) -> Array:
	var a := Instincts.owned(gun, 0) or (fitted_too and pick == 0)
	var b := Instincts.owned(gun, 1) or (fitted_too and pick == 1)
	if gun == "shotgun":
		var tube := "long" if a else "short"
		var alt := "shotgun_open_" + tube if pick == 1 else "shotgun_long"
		return ["shotgun_" + tube, alt]
	var mag := "drum" if a else "stick"
	var muz := "comp" if b else "plain"
	var alt2 := "tommy_drum_" + muz if pick == 0 else "tommy_%s_comp" % mag
	return ["tommy_%s_%s" % [mag, muz], alt2]
# per upgrade: the part (pixels on the drawing), how close to go, its name, the drawing to show
# ("" closed, "alt" the second), the word that pops, the sound, and an extra: shells fly in, a second gun
const SMITH_PARTS := {
	"gun": [
		[Vector2(620, 220), 1.6, "THE CYLINDER", "", "", "cyl_open", ""],
		[Vector2(1000, 120), 1.45, "THE BARREL", "", "", "cyl_spin", ""],
		[Vector2(240, 470), 1.55, "THE GRIPS", "", "", "click", ""],
		[Vector2(500, 260), 1.15, "THE FRAME", "", "", "hammer", ""],
		[Vector2(650, 380), 0.8, "A SECOND REVOLVER", "", "", "reload_done", "second"],
	],
	"beretta": [
		[Vector2(560, 470), 0.72, "THE MAGAZINE CATCH", "", "", "reload_mag", ""],   # (the whole gun, high in the panel: room below for the drop)
		[Vector2(700, 120), 1.45, "THE SLIDE", "", "", "hammer", ""],
		[Vector2(280, 420), 1.55, "THE GRIPS", "", "", "click", ""],
		[Vector2(560, 470), 0.72, "THE MAGAZINE", "", "", "reload_mag", ""],
		[Vector2(650, 380), 0.8, "A SECOND BERETTA", "", "", "reload_done", "second"],
	],
	"shotgun": [
		[Vector2(1430, 128), 1.6, "THE TUBE", "alt", "kachak", "reload_shells", ""],
		[Vector2(800, 80), 1.9, "THE SHELLS", "alt", "kachak", "shell_in", "shells"],
	],
	"tommy": [
		[Vector2(895, 230), 1.6, "THE MAGAZINE", "alt", "kachak", "reload_mag", ""],
		[Vector2(1470, 88), 1.9, "THE MUZZLE", "alt", "", "reload_done", ""],
	],
}
var _smith_gun := "gun"
var _smith_pick := 0
var _smith_back := Callable()
var _smith_stage: Node2D
var _smith_fit := 1.0
var _smith_c := Vector2.ZERO
var _smith_sprites := []
var _smith_panel: Control   # the comic panel the gun is drawn in: everything of the gun is clipped to it


func _gunsmith(gun := "", pick := -1) -> void:
	_on_case_file = true
	if gun != "":
		_smith_gun = gun
	if pick >= 0:
		_smith_pick = pick
	if not Instincts.reached(int(Instincts.GUN_FROM[_smith_gun])):
		_smith_gun = "gun"
	_smith_pick = clampi(_smith_pick, 0, Instincts.tiers(_smith_gun) - 1)
	_smith_swapping = false
	if _word_layer != null and is_instance_valid(_word_layer):   # (a quick tap to another card: last card's words go)
		for w in _word_layer.get_children():
			w.queue_free()
	var view := _new_page()
	if view.x < view.y:
		_portrait_note(view)
		return
	var bg := TextureRect.new()   # the burst, pushed back so the paper and the steel lead
	bg.texture = load("res://art/ui/gunsmith/burst.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = view
	bg.modulate = Color(0.5, 0.48, 0.45)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(bg)
	var col_w := 400.0
	var col_x := view.x - M - col_w
	var stage := Rect2(M, 112.0, col_x - GAP - M, view.y - 112.0 - M - 60.0 - GAP)   # above BACK
	# the gun's own comic panel: an ink frame, the burst showing through, the drawing clipped to it
	var panel_c := Control.new()
	panel_c.position = stage.position
	panel_c.size = stage.size
	panel_c.clip_contents = true
	panel_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(panel_c)
	_smith_panel = panel_c
	var frame := Control.new()
	frame.position = stage.position
	frame.size = stage.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func() -> void:
		frame.draw_rect(Rect2(Vector2.ZERO, stage.size), INK, false, 7.0)
		frame.draw_rect(Rect2(Vector2(5, 5), stage.size - Vector2(10, 10)), Color(PAPER, 0.85), false, 2.0))
	_smith_c = stage.size * 0.5
	# the gun
	var holder := Node2D.new()
	panel_c.add_child(holder)
	_smith_stage = holder
	var names: Array = _big_art(_smith_gun, _smith_pick) if _smith_gun in ["shotgun", "tommy"] else SMITH_ART[_smith_gun]
	var part: Array = SMITH_PARTS[_smith_gun][_smith_pick]
	var have := Instincts.owned(_smith_gun, _smith_pick)
	_smith_sprites = []
	_smith_pieces = {}
	var tex_size := SMITH_SIZE
	if SMITH_PIECES.has(_smith_gun):   # the side guns: built of parts, each worn or new
		for k in (SMITH_PIECES[_smith_gun] as Array).size():
			var pc: Array = SMITH_PIECES[_smith_gun][k]
			var sp := _smith_piece(String(pc[0]), Instincts.owned(_smith_gun, k))
			sp.position = (pc[1] as Vector2) + sp.texture.get_size() * 0.5 - SMITH_SIZE * 0.5
			holder.add_child(sp)
			_smith_pieces[String(pc[0])] = sp
	else:
		for k in 2:
			var sp := Sprite2D.new()
			sp.texture = load("res://art/ui/gunsmith/%s.png" % names[k])
			sp.visible = k == 0   # (the gun as it is; the second is the part at work)
			holder.add_child(sp)
			_smith_sprites.append(sp)
		tex_size = (_smith_sprites[0] as Sprite2D).texture.get_size()
	_smith_fit = minf(stage.size.x * 0.92 / tex_size.x, stage.size.y * 0.8 / tex_size.y)
	if String(part[6]) == "second":   # a second one, behind and below the first, as it stands now
		var two := Node2D.new()
		for c in holder.get_children():
			var d: Sprite2D = (c as Sprite2D).duplicate()
			two.add_child(d)
		two.modulate = Color(0.7, 0.68, 0.66)
		two.position = Vector2(140.0, 150.0)
		two.rotation = deg_to_rad(9.0)
		holder.add_child(two)
		holder.move_child(two, 0)   # behind the first
		two.set_meta("second", true)
		_smith_sprites.append(two)
	holder.position = _smith_c
	holder.scale = Vector2.ONE * _smith_fit
	_page.add_child(frame)
	holder.rotation = deg_to_rad(-4.0)
	# a slow breath while it is looked at
	var idle := holder.create_tween().set_loops()
	idle.tween_property(holder, "rotation", deg_to_rad(-2.6), 2.2).set_trans(Tween.TRANS_SINE)
	idle.tween_property(holder, "rotation", deg_to_rad(-4.4), 2.2).set_trans(Tween.TRANS_SINE)

	var title := _label("THE GUNSMITH", _font_head, 44, PAPER, 12)
	title.position = Vector2(M, 18.0)
	title.size = Vector2(420.0, 56.0)
	_page.add_child(title)
	var sub := _label("LEVEL %d     %d POINTS TO SPEND" % [Instincts.level(), Instincts.unspent()], _font_type, 20, PAPER, 6)
	sub.position = Vector2(M, 74.0)
	sub.size = Vector2(420.0, 28.0)
	_page.add_child(sub)
	# the three guns as tags, top right
	var ng := Instincts.GUNS.size()
	var tag_w := minf(196.0, (view.x - M - 470.0 - (ng - 1) * GAP) / ng)
	for gi in ng:
		var g: String = Instincts.GUNS[gi]
		var open := Instincts.reached(int(Instincts.GUN_FROM[g]))
		var at := Vector2(view.x - M - (ng - gi) * tag_w - (ng - 1 - gi) * GAP, 28.0)
		var tag := _paper("tag", at, Vector2(tag_w, 64.0), TILT[gi + 1], _gunsmith.bind(g, 0) if open else func() -> void: pass)
		var word: String = String({"gun": "REVOLVER", "beretta": "BERETTA", "shotgun": "SHOTGUN", "tommy": "TOMMY"}[g]) if open else "CH " + String(["", "I", "II", "III"][int(Instincts.GUN_FROM[g])])
		Paper.write(tag, word, _font_head, 15, CRIMSON if g == _smith_gun else INK)
		if not open:
			(tag.get_node("Drawing") as TextureRect).modulate = Color(0.78, 0.76, 0.72)
	# the upgrades, one strip each
	var y := 112.0
	var n := Instincts.tiers(_smith_gun)
	var strip_h := 56.0
	for t in n:
		var info: Array = Instincts.CARDS[_smith_gun][t]
		var owned := Instincts.owned(_smith_gun, t)
		var why := Instincts.why_locked(_smith_gun, t)
		var s := _paper("strip", Vector2(col_x, y), Vector2(col_w, strip_h), TILT[t % TILT.size()] * 0.4, _gunsmith.bind(_smith_gun, t))
		var c := INK if t != _smith_pick else CRIMSON
		Paper.write(s, String(info[0]), _font_head, 20, c, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0, 0.62, 1))
		Paper.write(s, "FITTED" if owned else ("LOCKED" if why != "" else "1 POINT"), _font_head, 17, CRIMSON if owned or why == "" else Color(0.3, 0.29, 0.27), HORIZONTAL_ALIGNMENT_RIGHT, Rect2(0.6, 0, 0.4, 1))
		if why != "" and not owned:
			(s.get_node("Drawing") as TextureRect).modulate = Color(0.72, 0.7, 0.66)
		y += strip_h + 8.0
	# what the picked one does
	var info2: Array = Instincts.CARDS[_smith_gun][_smith_pick]
	var why2 := Instincts.why_locked(_smith_gun, _smith_pick)
	var panel_top := y + GAP - 8.0
	var panel := Paper.sheet("panel", Vector2(col_w, view.y - M - 60.0 - GAP - panel_top))
	panel.position = Vector2(col_x, panel_top)
	_page.add_child(panel)
	Paper.write(panel, String(info2[0]), _font_head, 28, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0, 1, 0.3))
	Paper.write(panel, String(info2[1]), _font_type, 21, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0.3, 1, 0.42))
	Paper.write(panel, "FITTED" if have else (why2 if why2 != "" else "COSTS 1 POINT"), _font_head, 19, CRIMSON, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0.72, 1, 0.28))
	var back := _paper("tape", Vector2(M, view.y - M - 60.0), Vector2(180.0, 60.0), TILT[5], _smith_back if _smith_back.is_valid() else _instincts)
	Paper.write(back, "BACK", _font_head, 24, INK)
	if _smith_gun in ["shotgun", "tommy"]:   # take it along into each new chapter, with few rounds
		var along := Instincts.big() == _smith_gun
		var x1 := M + 180.0 + GAP * 2.0
		var tk := _paper("tape", Vector2(x1, view.y - M - 60.0), Vector2(250.0, 60.0), TILT[2], func() -> void:
			Instincts.set_big("" if along else _smith_gun)
			if sound.is_valid():
				sound.call("reload_done")
			_gunsmith())
		Paper.write(tk, "LEAVE IT" if along else "TAKE ALONG", _font_head, 24, INK if along else CRIMSON)
		var note := _label("%d ROUNDS AT EACH CHAPTER START" % int(Instincts.BIG_START[_smith_gun]) if along else "", _font_type, 16, PAPER, 6)
		note.position = Vector2(x1 + 250.0 + GAP, view.y - M - 46.0)
		note.size = Vector2(300.0, 30.0)
		_page.add_child(note)
	if _smith_gun in ["gun", "beretta"]:   # which side gun he carries, and one or two of it
		var kind := "revolver" if _smith_gun == "gun" else "beretta"
		var carried := Instincts.side() == kind
		var two_fx := "twoguns" if kind == "revolver" else "b_two"
		var x0 := M + 180.0 + GAP * 2.0
		if carried:
			var st := _label("CARRIED", _font_head, 30, CRIMSON, 0)
			st.position = Vector2(x0, view.y - M - 56.0)
			st.size = Vector2(170.0, 50.0)
			st.rotation = deg_to_rad(-4.0)
			_page.add_child(st)
		else:
			var carry := _paper("tape", Vector2(x0, view.y - M - 60.0), Vector2(200.0, 60.0), TILT[2], func() -> void:
				Instincts.set_side(kind, Instincts.has_fx(two_fx))
				if sound.is_valid():
					sound.call("reload_done")
				_gunsmith())
			Paper.write(carry, "CARRY IT", _font_head, 24, CRIMSON)
		if Instincts.has_fx(two_fx) and carried:
			var two := Instincts.side_two()
			var tog := _paper("tape", Vector2(x0 + 200.0 + GAP, view.y - M - 60.0), Vector2(170.0, 60.0), TILT[3], func() -> void:
				Instincts.set_side(kind, not two)
				if sound.is_valid():
					sound.call("cyl_spin")
				_gunsmith())
			Paper.write(tog, "ONE GUN" if two else "TWO GUNS", _font_head, 22, INK)
	if not have and why2 == "":
		var buy := _paper("tape", Vector2(view.x - M - 260.0, view.y - M - 60.0), Vector2(260.0, 60.0), TILT[1], _smith_buy)
		Paper.write(buy, "FIT IT", _font_head, 26, CRIMSON)
	elif have:
		var off := _paper("tape", Vector2(view.x - M - 260.0, view.y - M - 60.0), Vector2(260.0, 60.0), TILT[1], func() -> void:
			Instincts.unpin(_smith_gun, _smith_pick)
			_gunsmith())
		Paper.write(off, "TAKE IT OFF", _font_head, 22, INK)
	_smith_show(part, have)


## Swing onto the part: the gun turns and comes close, an ink ring draws itself round the part, the
## part works (the second drawing cuts in with a word and a flash), and its name is captioned.
func _smith_show(part: Array, fitted: bool) -> void:
	var holder := _smith_stage
	var tex_size: Vector2 = SMITH_SIZE if SMITH_PIECES.has(_smith_gun) else (_smith_sprites[0] as Sprite2D).texture.get_size()
	var hot: Vector2 = (part[0] as Vector2) - tex_size * 0.5
	var z: float = float(part[1])
	var s := _smith_fit * z
	var goal := _smith_c - hot * s * 0.82   # the part comes most of the way to the middle
	var tw := holder.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	holder.scale = Vector2.ONE * _smith_fit * 0.92
	tw.tween_property(holder, "scale", Vector2.ONE * s, 0.55)
	tw.tween_property(holder, "position", goal, 0.55)
	var outlined: Sprite2D = null
	# the ring (guns not built of parts)
	var ring := Node2D.new()
	ring.position = hot
	ring.set_meta("p", 0.0)
	var rad := 150.0 / z
	ring.draw.connect(func() -> void:
		var p: float = ring.get_meta("p")
		if p <= 0.0:
			return
		var a0 := -PI * 0.6
		ring.draw_arc(Vector2.ZERO, rad, a0, a0 + TAU * p, 48, INK, 22.0 / z, true)
		ring.draw_arc(Vector2.ZERO, rad, a0, a0 + TAU * p, 48, PAPER, 10.0 / z, true))
	holder.add_child(ring)
	ring.visible = false   # (user 17. 11.: no ring - the part is shown by what it does)
	var rt := ring.create_tween()
	rt.tween_interval(0.45)
	rt.tween_method(func(v: float) -> void:
		ring.set_meta("p", v)
		ring.queue_redraw(), 0.0, 1.0, 0.3)
	# the part at work
	var alt := String(part[3]) == "alt"
	var first: Sprite2D = _smith_sprites[0] if _smith_sprites.size() > 1 else null
	var second: Sprite2D = _smith_sprites[1] if _smith_sprites.size() > 1 else null
	var t2 := holder.create_tween()
	t2.tween_interval(0.6)
	t2.tween_callback(func() -> void:
		if SMITH_ACTS.has(_smith_gun) and String(SMITH_ACTS[_smith_gun][_smith_pick]) != "":
			if _smith_swapping:
				return   # (bought while the camera was still closing in: the fitted part's own act plays instead)
			_smith_act(String(SMITH_ACTS[_smith_gun][_smith_pick]))
			return
		if alt and second != null and not second.visible:
			first.visible = false
			second.visible = true
			_smith_flash()
		if String(part[4]) != "":
			_smith_word(String(part[4]), holder.position + (hot + Vector2(rad * 0.9, -rad * 1.0)).rotated(holder.rotation) * holder.scale.x)
		if String(part[5]) != "" and sound.is_valid():
			sound.call(String(part[5]))
		if String(part[6]) == "shells":
			_smith_shells(holder, tex_size)
		if String(part[6]) == "second":
			for sp in _smith_sprites:
				if (sp as Node2D).has_meta("second"):
					var two: Node2D = sp
					var at := two.position
					two.position = at + Vector2(700.0, 120.0)
					two.create_tween().tween_property(two, "position", at, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	# the caption with the part's name
	var cap: Control = Paper.caption(String(part[2]), _font_head, 22)
	_smith_panel.add_child(cap)
	_smith_cap = cap
	var spot := goal + (hot + Vector2(0.0, rad + 24.0)).rotated(holder.rotation) * s
	var room := _smith_panel.size
	cap.position = Vector2(clampf(spot.x - cap.size.x * 0.5, 16.0, room.x - 16.0 - cap.size.x), clampf(spot.y, 16.0, room.y - 16.0 - cap.size.y))
	cap.modulate.a = 0.0
	cap.create_tween().tween_property(cap, "modulate:a", 1.0, 0.2).set_delay(0.75)
	if fitted:   # already on the gun: a stamp says so
		var st := _label("FITTED", _font_head, 40, CRIMSON, 0)
		st.position = Vector2(24.0, 18.0)
		st.size = Vector2(200.0, 56.0)
		st.rotation = deg_to_rad(-7.0)
		_smith_panel.add_child(st)


func _smith_flash() -> void:
	var view := get_viewport().get_visible_rect().size
	var f := ColorRect.new()
	f.color = Color(1.0, 0.97, 0.9, 0.55)
	f.size = _smith_panel.size if _smith_panel != null else view
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_smith_panel if _smith_panel != null else _page).add_child(f)
	f.create_tween().tween_property(f, "color:a", 0.0, 0.22)
	var h := _smith_stage
	var at := h.position
	var sh := h.create_tween()
	for k in 4:
		sh.tween_property(h, "position", at + Vector2(randf_range(-8, 8), randf_range(-6, 6)), 0.03)
	sh.tween_property(h, "position", at, 0.04)


var _outline: ShaderMaterial
func _outline_mat() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = OUTLINE_SHADER
		_outline = ShaderMaterial.new()
		_outline.shader = sh
	return _outline
const OUTLINE_SHADER := "shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.98, 0.84, 0.42, texture(TEXTURE, UV).a);
}
"


var _word_n := 0
var _smith_cap: Control   # the part's name: it steps aside while the cylinder is worked (it would cover it)
var _word_layer: CanvasLayer
func _smith_word(w: String, _at: Vector2) -> void:
	var path := "res://art/fx/word_%s.png" % w
	if not ResourceLoader.exists(path):
		return
	var s := Sprite2D.new()
	s.texture = preload("res://lowres.gd").tex(path, 0.5)   # (imported at half size: read through LowRes, as fx.gd does)
	# (always in the clear bit of the panel under the barrel, over everything, whole: never cut by the frame or behind the gun)
	var room := _smith_panel.size
	_word_n = (_word_n + 1) % 2
	s.position = _smith_panel.global_position + Vector2(room.x * (0.74 if _word_n == 0 else 0.66), room.y * (0.7 if _word_n == 0 else 0.8))
	s.rotation = deg_to_rad(-8.0)
	s.scale = Vector2.ONE * 0.05
	if _word_layer == null or not is_instance_valid(_word_layer):   # (a layer of its own over the whole screen: nothing clips it)
		_word_layer = CanvasLayer.new()
		_word_layer.layer = layer + 5
		add_child(_word_layer)
	_word_layer.add_child(s)
	var k := 190.0 / s.texture.get_width()
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE * k * 1.2, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "scale", Vector2.ONE * k, 0.1)
	tw.tween_interval(0.7)
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


func _smith_piece(part: String, new: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load("res://art/ui/gunsmith/parts/%s_%s_%s.png" % ["revolver" if _smith_gun == "gun" else _smith_gun, part, "new" if new else "worn"])
	return sp


## A part is fitted: the old one is knocked off the gun and falls away turning, the new one slides in
## from the other side and seats with a jolt, sparks fly at the joint, and the stamp comes down.
var _act_open: Node2D   # the open revolver of the act running now, and its tween
var _act_t: Tween
func _smith_act_stop() -> void:
	if _act_t != null and _act_t.is_valid():
		_act_t.kill()
	if _act_open != null and is_instance_valid(_act_open):
		_act_open.queue_free()
	_act_open = null
	for pk in _smith_pieces:
		if is_instance_valid(_smith_pieces[pk]):
			(_smith_pieces[pk] as CanvasItem).visible = true
	if _smith_cap != null and is_instance_valid(_smith_cap):
		_smith_cap.visible = true


var _smith_swapping := false
func _smith_swap(part: String) -> void:
	_smith_swapping = true
	_smith_act_stop()
	var old: Sprite2D = _smith_pieces.get(part)
	if old == null:
		_gunsmith()
		return
	var fresh := _smith_piece(part, true)
	fresh.position = old.position
	fresh.modulate.a = 0.0
	_smith_stage.add_child(fresh)
	_smith_stage.move_child(fresh, old.get_index() + 1)
	var t := _smith_stage.create_tween()
	t.tween_property(fresh, "modulate:a", 1.0, 0.45)
	t.tween_callback(func() -> void:
		old.queue_free()
		_smith_pieces[part] = fresh
		_smith_flash()
		_snd("hammer"))
	t.tween_interval(0.25)
	var act := String(SMITH_ACTS.get(_smith_gun, [])[_smith_pick]) if SMITH_ACTS.has(_smith_gun) else ""
	if act != "":
		t.tween_callback(_smith_act.bind(act))
		t.tween_interval(2.3 if act in ["open", "lastround"] else 0.9)
	t.tween_callback(_smith_stamp)


## What each upgrade does, shown on the gun (user 17. 11.: "every upgrade shown nicely, even a tiny animation"): the
## revolver's cylinder swings out (the drawn open revolver, as in the first gunsmith), a heavy load kicks with a flash,
## a steady hand stops shaking, the last round cocks and booms, the Beretta drops and slams its magazine.
# the open revolver's parts (gen/open_revolver.py prints these): where each cut sits on the 1300 x 678 open drawing
const SMITH_OPEN := {"frame_new": Vector2(83, 57), "frame_worn": Vector2(13, 38), "barrel_new": Vector2(794, 48), "barrel_worn": Vector2(794, 44),
		"grip_new": Vector2(83, 286), "grip_worn": Vector2(84, 286), "cylinder_new_loaded": Vector2(460, 203), "cylinder_new_empty": Vector2(460, 203),
		"cylinder_worn_loaded": Vector2(460, 203), "cylinder_worn_empty": Vector2(460, 203)}
const SMITH_ACTS := {"gun": ["open", "recoil", "steady", "lastround", ""], "beretta": ["mag", "recoil", "steady", "magfull", ""]}
const SMITH_MUZZLE := {"gun": Vector2(1285, 112), "beretta": Vector2(1190, 110)}
func _smith_act(kind: String) -> void:
	var holder := _smith_stage
	var to_screen := func(p: Vector2) -> Vector2: return holder.position + (p - SMITH_SIZE * 0.5).rotated(holder.rotation) * holder.scale.x
	match kind:
		"open", "lastround":   # the cylinder swings out (the drawn open revolver); a speedloader puts six rounds in at once
			# (FAST HANDS), or one round is thumbed into the last chamber (LAST ROUND) - then it snaps shut
			# (rule 28: the open gun is the same gun - each part worn or new exactly as on the closed one, the cylinder
			# loaded or empty as the moment says; gen/open_revolver.py cut the open drawings into the same parts)
			_smith_act_stop()   # (one act at a time: the preview's own, then the fitted part's - never both at once)
			var open := Node2D.new()
			_act_open = open
			var cyl_sp: Sprite2D = null
			var cyl_state := "worn"
			for part in ["frame", "barrel", "grip", "cylinder"]:
				var piece: Sprite2D = _smith_pieces.get(part)
				var st := "new" if piece != null and piece.texture.resource_path.ends_with("_new.png") else "worn"
				var nm := "%s_%s%s" % [part, st, "_loaded" if part == "cylinder" else ""]
				var sp := Sprite2D.new()
				sp.centered = false
				sp.texture = load("res://art/ui/gunsmith/open/%s.png" % nm)
				sp.position = (SMITH_OPEN[nm] as Vector2) - Vector2(650.0, 339.0)
				open.add_child(sp)
				if part == "cylinder":
					cyl_sp = sp
					cyl_state = st
			var set_cyl := func(load_state: String) -> void:
				cyl_sp.texture = load("res://art/ui/gunsmith/open/cylinder_%s_%s.png" % [cyl_state, load_state])
			open.visible = false
			holder.add_child(open)
			# (user 17. 11.: the spent cases are flung out, then new rounds pushed into the empty chambers one by one)
			var c0 := Vector2(650.0, 339.0)   # (the open drawing is centred: its picture px -> the holder's)
			var rims := [Vector2(680, 250), Vector2(697, 265), Vector2(666, 291), Vector2(667, 345), Vector2(687, 368), Vector2(700, 347)]
			var one := kind == "lastround"
			var kc := 0.14
			var t := _smith_stage.create_tween()   # (on the gun: a page rebuilt by a quick tap kills it with the gun)
			_act_t = t
			t.tween_callback(func() -> void:
				for pk in _smith_pieces:
					(_smith_pieces[pk] as CanvasItem).visible = false
				open.visible = true
				if _smith_cap != null and is_instance_valid(_smith_cap):
					_smith_cap.visible = false
				_smith_flash()
				_snd("cyl_open")
				_smith_word("kachak", Vector2.ZERO))
			t.tween_interval(0.35)
			t.tween_callback(func() -> void:   # the ejector rod pushed: the spent cases fly out and tumble down
				_snd("shell_in")
				for i in rims.size():
					if one and i > 0:
						break
					var cs := Sprite2D.new()
					cs.texture = load("res://art/ui/gunsmith/case.png")
					cs.scale = Vector2.ONE * kc
					var from: Vector2 = (rims[i] as Vector2) - c0 + Vector2(cs.texture.get_width() * kc * 0.5 - 6.0, 0.0)
					cs.position = from
					holder.add_child(cs)
					var out := from + Vector2(randf_range(120.0, 220.0), randf_range(-60.0, -10.0))
					var tw := cs.create_tween()
					tw.tween_property(cs, "position", out, 0.16).set_ease(Tween.EASE_OUT)
					tw.parallel().tween_property(cs, "rotation", randf_range(-1.5, 1.5), 0.16)
					tw.tween_property(cs, "position", out + Vector2(randf_range(-40.0, 80.0), 560.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw.parallel().tween_property(cs, "rotation", randf_range(-9.0, 9.0), 0.55)
					tw.tween_callback(cs.queue_free)
				if not one:
					set_cyl.call("empty"))   # (the drawn empty chambers)
			t.tween_interval(0.55)
			for i in (1 if one else rims.size()):   # a new round pushed into each empty chamber, nose first
				var rd := Sprite2D.new()
				rd.texture = load("res://art/ui/gunsmith/round.png")
				rd.flip_h = true
				rd.scale = Vector2.ONE * kc
				var home: Vector2 = (rims[i] as Vector2) - c0 + Vector2(rd.texture.get_width() * kc * 0.5 - 4.0, 0.0)
				rd.position = home + Vector2(150.0, 40.0)
				rd.modulate.a = 0.0
				holder.add_child(rd)
				t.tween_property(rd, "modulate:a", 1.0, 0.04)
				t.parallel().tween_property(rd, "position", home + Vector2(30.0, 0.0), 0.12).set_ease(Tween.EASE_OUT)
				t.tween_property(rd, "position", home, 0.06)
				var last := i == (0 if one else rims.size() - 1)
				t.tween_callback(func() -> void:
					_snd("click")
					if last and not one:
						set_cyl.call("loaded"))   # (all home: the loaded drawing)
				t.tween_property(rd, "modulate:a", 0.0, 0.05)
				t.tween_callback(rd.queue_free)
				t.tween_interval(0.04)
			var ammo := Node2D.new()   # (nothing left over: the old speedloader's slot)
			holder.add_child(ammo)
			t.tween_interval(0.15)
			t.tween_callback(func() -> void: _snd("cyl_spin"))
			t.tween_interval(0.25)
			t.tween_callback(func() -> void:
				open.queue_free()
				ammo.queue_free()
				for pk in _smith_pieces:
					(_smith_pieces[pk] as CanvasItem).visible = true
				_smith_flash()
				_snd("click")
				_smith_word("click", Vector2.ZERO)
				if _smith_cap != null and is_instance_valid(_smith_cap):
					_smith_cap.visible = true)
			if one:   # then the hammer back, a breath, and the shot in a red flash
				t.tween_interval(0.5)
				t.tween_callback(func() -> void:
					_smith_act("recoil")
					var red := ColorRect.new()
					red.color = Color(0.6, 0.08, 0.05, 0.45)
					red.size = _smith_panel.size
					red.mouse_filter = Control.MOUSE_FILTER_IGNORE
					_smith_panel.add_child(red)
					red.create_tween().tween_property(red, "color:a", 0.0, 0.5))
		"recoil":   # a heavy load: the flash at the muzzle, the gun kicks up and comes back
			var mz: Vector2 = SMITH_MUZZLE.get(_smith_gun, Vector2(1280, 110)) - SMITH_SIZE * 0.5
			var fl := Sprite2D.new()
			fl.texture = load("res://art/fx/flash%d.png" % (randi() % 4 + 1))
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			fl.material = add
			fl.position = mz + Vector2(fl.texture.get_width() * 0.35, 0.0)
			fl.scale = Vector2.ONE * 1.1
			holder.add_child(fl)
			fl.create_tween().tween_property(fl, "modulate:a", 0.0, 0.18).set_delay(0.06)
			get_tree().create_timer(0.4).timeout.connect(fl.queue_free)
			_snd("shot_player")
			_smith_flash()
			_smith_word("blam", to_screen.call(SMITH_MUZZLE.get(_smith_gun, Vector2(1280, 110)) + Vector2(-60, -80)))
			var r0 := holder.rotation
			var p0 := holder.position
			var t := holder.create_tween()
			t.tween_property(holder, "rotation", r0 - deg_to_rad(13.0), 0.05)
			t.parallel().tween_property(holder, "position", p0 + Vector2(-26.0, -10.0), 0.05)
			t.tween_property(holder, "rotation", r0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(holder, "position", p0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			if _smith_pieces.has("slide"):   # (the Beretta's slide runs back and home with it)
				var sl: Node2D = _smith_pieces["slide"]
				var s0 := sl.position
				var ts := sl.create_tween()
				ts.tween_property(sl, "position", s0 + Vector2(-70.0, 0.0), 0.05)
				ts.tween_property(sl, "position", s0, 0.12)
		"steady":   # it shakes in the hand, the shaking dies away, and it holds dead still on the mark
			var p0 := holder.position
			var t := holder.create_tween()
			for k in 14:
				var a := 9.0 * (1.0 - k / 14.0)
				t.tween_property(holder, "position", p0 + Vector2(randf_range(-a, a), randf_range(-a, a)), 0.05)
			t.tween_property(holder, "position", p0, 0.08)
			t.tween_callback(func() -> void:
				_snd("click")
				_smith_word("zing", to_screen.call(SMITH_MUZZLE.get(_smith_gun, Vector2(1280, 110)) + Vector2(-120, -70))))
		"mag", "magfull":   # (user 17. 11.: a real magazine change) the empty one slides out of the grip and drops, a fresh one
			# goes up into it and seats with a click, the slide is racked; LONG MAG: two rounds thumbed into a longer magazine first
			var k := 0.42
			var top_w := Vector2(379.0, 236.0) - SMITH_SIZE * 0.5   # the magazine's box top inside the gun (picture px -> holder)
			var axis := Vector2(-209.0, 1034.0).normalized()          # down the grip
			var mk := func(n: String, top_px: Vector2) -> Sprite2D:
				var m := Sprite2D.new()
				m.texture = load("res://art/ui/gunsmith/%s.png" % n)
				m.scale = Vector2.ONE * k
				m.set_meta("off", (m.texture.get_size() * 0.5 - top_px) * k)
				holder.add_child(m)
				holder.move_child(m, 0)   # behind the frame and the grips: only what is out of the grip shows
				return m
			var old := mk.call("mag", Vector2(424.0, 41.0)) as Sprite2D
			var long := kind == "magfull"
			var fresh := mk.call("mag_long" if long else "mag", Vector2(482.0, 41.0) if long else Vector2(424.0, 41.0)) as Sprite2D
			var at := func(m: Sprite2D, down: float) -> Vector2: return top_w + (m.get_meta("off") as Vector2) + axis * down
			old.position = at.call(old, 0.0)
			fresh.position = at.call(fresh, 700.0)
			fresh.modulate.a = 0.0
			var plate: CanvasItem = _smith_pieces.get("plate")
			if plate != null:
				plate.visible = false   # (the magazine's own base plate)
			if _smith_cap != null and is_instance_valid(_smith_cap):
				_smith_cap.visible = false   # (out of the way of the falling magazine)
			var t := holder.create_tween()
			t.tween_callback(func() -> void:
				_snd("reload_mag")
				_smith_word("click", Vector2.ZERO))
			t.tween_property(old, "position", at.call(old, 120.0), 0.08)   # released: it drops free
			t.tween_property(old, "position", at.call(old, 760.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.parallel().tween_property(old, "rotation", deg_to_rad(-18.0), 0.28)
			t.parallel().tween_property(old, "modulate:a", 0.0, 0.18).set_delay(0.12)
			t.tween_property(fresh, "modulate:a", 1.0, 0.05)
			t.parallel().tween_property(fresh, "position", at.call(fresh, 420.0), 0.22).set_ease(Tween.EASE_OUT)
			if long:   # two more rounds thumbed in at its lips
				for r in 2:
					var rd := Sprite2D.new()
					rd.texture = load("res://art/ui/gunsmith/round9.png")
					rd.scale = Vector2.ONE * k
					var lip: Vector2 = top_w + axis * 420.0 + Vector2(10.0, -4.0 - r * 8.0)
					rd.position = lip + Vector2(260.0, -120.0)
					rd.modulate.a = 0.0
					holder.add_child(rd)
					t.tween_property(rd, "modulate:a", 1.0, 0.04)
					t.parallel().tween_property(rd, "position", lip, 0.16).set_ease(Tween.EASE_OUT)
					t.tween_callback(func() -> void:
						_snd("shell_in")
						if r == 1:
							_smith_word("clink", Vector2.ZERO))
					t.tween_property(rd, "position", lip + axis * 14.0, 0.06)
					t.tween_property(rd, "modulate:a", 0.0, 0.05)
					t.tween_callback(rd.queue_free)
			t.tween_property(fresh, "position", at.call(fresh, 0.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(func() -> void:
				_snd("hammer")
				_smith_flash())
			var sl: Node2D = _smith_pieces.get("slide")
			if sl != null:   # and the slide racked: back, and home
				var s0 := sl.position
				t.tween_interval(0.15)
				t.tween_callback(func() -> void:
					_snd("cyl_open")
					_smith_word("kachak", Vector2.ZERO))
				t.tween_property(sl, "position", s0 + Vector2(-90.0, 6.0), 0.08)
				t.tween_property(sl, "position", s0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(0.5)
			t.tween_callback(func() -> void:
				old.queue_free()
				if _smith_cap != null and is_instance_valid(_smith_cap):
					_smith_cap.visible = true
				if plate != null and not long:
					fresh.queue_free()
					plate.visible = true)

func _snd(n: String) -> void:
	if sound.is_valid():
		sound.call(n)


func _show_fresh(fresh: Sprite2D) -> void:
	fresh.modulate.a = 1.0


func _place_fresh(fresh: Sprite2D, where: Vector2, k: float) -> void:
	fresh.position = where
	fresh.scale = Vector2.ONE * k
	fresh.modulate.a = 1.0


## The new part home: a jolt, sparks at the joint, the word.
func _smith_seat(at: Vector2) -> void:
	var holder := _smith_stage
	_snd("hammer")
	_smith_sparks(holder.position + at.rotated(holder.rotation) * holder.scale.x)
	_smith_flash()
	_smith_word("kachak", holder.position + (at + Vector2(0.0, -120.0)).rotated(holder.rotation) * holder.scale.x)


func _smith_stamp() -> void:
	var st := _label("FITTED", _font_head, 64, CRIMSON, 0)
	st.size = Vector2(320.0, 80.0)
	st.pivot_offset = st.size * 0.5
	st.position = _smith_c - st.size * 0.5 + Vector2(0.0, 150.0)
	st.rotation = deg_to_rad(-9.0)
	st.scale = Vector2.ONE * 2.6
	st.modulate.a = 0.0
	st.z_index = 6
	_smith_panel.add_child(st)
	var ts := st.create_tween().set_parallel()
	ts.tween_property(st, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ts.tween_property(st, "modulate:a", 1.0, 0.1)
	ts.chain().tween_interval(0.9)
	ts.chain().tween_callback(_gunsmith)


## Sparks off the joint where a new part seats: the game's own drawn sparks (fx.gd INK_SPARKS).
const SPARK_ART := preload("res://fx.gd").INK_SPARKS
func _smith_sparks(at: Vector2) -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for k in 3:
		var s := Sprite2D.new()
		s.texture = load(SPARK_ART.pick_random())
		s.material = add
		s.position = at + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		s.rotation = randf_range(-1.2, 1.2)
		s.scale = Vector2.ONE * 0.1
		s.z_index = 5
		_smith_panel.add_child(s)
		var tw := s.create_tween()
		tw.tween_interval(0.05 * k)
		tw.tween_property(s, "scale", Vector2.ONE * randf_range(0.35, 0.5), 0.08).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.22)
		tw.tween_callback(s.queue_free)


## The shotgun's shells fly up into the open port one after another.
func _smith_shells(holder: Node2D, tex_size: Vector2) -> void:
	var tex: Texture2D = load("res://art/ui/gunsmith/shells.png")
	var lie := Vector2(684, 172) + tex.get_size() * 0.5 - tex_size * 0.5
	var port := Vector2(800, 80) - tex_size * 0.5
	var s := Sprite2D.new()
	s.texture = tex
	s.position = lie + Vector2(0.0, 260.0)
	s.modulate.a = 0.0
	holder.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(s, "position", lie, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(s, "position", port, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "scale", Vector2(0.4, 0.4), 0.3)
	tw.tween_callback(func() -> void:
		if sound.is_valid():
			sound.call("shell_in"))
	tw.tween_property(s, "modulate:a", 0.0, 0.1)


## Fit the picked upgrade: a red stamp comes down on the drawing, then the screen shows it fitted.
func _smith_buy() -> void:
	if not Instincts.pin(_smith_gun, _smith_pick):
		return
	var fx := String(Instincts.CARDS[_smith_gun][_smith_pick][2])
	if fx in ["twoguns", "b_two"]:   # a second one bought: he carries the pair
		Instincts.set_side("revolver" if fx == "twoguns" else "beretta", true)
	if SMITH_PIECES.has(_smith_gun) and _smith_pick < (SMITH_PIECES[_smith_gun] as Array).size():
		_smith_swap(String(SMITH_PIECES[_smith_gun][_smith_pick][0]))
		return
	if _smith_gun in ["shotgun", "tommy"] and _smith_pick < 2 and not _smith_sprites.is_empty():
		# the part goes on: the gun as it is now fitted comes in over the old one (only the part changes - the
		# drawings are registered on one frame), a flash and the hammer, then the stamp
		var now_tex: Texture2D = load("res://art/ui/gunsmith/%s.png" % _big_art(_smith_gun, _smith_pick)[0])
		var cur: Sprite2D = _smith_sprites[0]
		var fresh := Sprite2D.new()
		fresh.texture = now_tex
		fresh.modulate.a = 0.0
		_smith_stage.add_child(fresh)
		for sp in _smith_sprites:
			if sp != cur:
				(sp as CanvasItem).visible = false
		cur.visible = true
		var ft := fresh.create_tween()
		ft.tween_property(fresh, "modulate:a", 1.0, 0.45)
		ft.tween_callback(func() -> void:
			_smith_flash()
			_snd("hammer"))
		ft.tween_interval(0.3)
		ft.tween_callback(_smith_stamp)
		return
	if sound.is_valid():
		sound.call("hammer")
	var st := _label("FITTED", _font_head, 64, CRIMSON, 0)
	st.size = Vector2(320.0, 80.0)
	st.pivot_offset = st.size * 0.5
	st.position = _smith_c - st.size * 0.5
	st.rotation = deg_to_rad(-9.0)
	st.scale = Vector2.ONE * 2.6
	st.modulate.a = 0.0
	_smith_panel.add_child(st)
	var tw := st.create_tween().set_parallel()
	tw.tween_property(st, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(st, "modulate:a", 1.0, 0.1)
	tw.chain().tween_callback(_smith_flash)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_callback(_gunsmith)
