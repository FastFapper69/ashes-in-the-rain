extends CanvasLayer
## The title and the case file, over the street where the story stands right now. What the
## player sees here follows the story: the street of the map they are on, Frank's line for that
## moment typed out under the title, the date and the place on the stamp. The ash thickens as
## he gets closer to the truth (main.gd sets that from phase()).

const Levels = preload("res://levels.gd")
const Paper = preload("res://paper.gd")
const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const CRIMSON := Color(0.6, 0.1, 0.07)
const AMBER := Color(0.95, 0.66, 0.13)
const SAVE := "user://progress2.cfg"   # progress2: the maps were rebuilt longer, old progress no longer applies

# What Frank says on the title, and the stamp under it, for the point the player has reached:
# [chapter, map] of the next map to play. A later entry wins once it is reached.
const PHASES := [
	[0, 0, "December 17th, 1947. A week before Christmas.\nIt hadn't snowed yet. It only rained.", "NEW YORK  ·  DEC 17, 1947  ·  11:52 PM"],
	[1, 0, "They called me at ten past two.\nEddie was already cold. The rain was working on the rest.", "HELL'S KITCHEN  ·  DEC 18, 1947  ·  2:10 AM"],
	[1, 1, "The shooters ran east. So did I.\nI was always better at running after than running from.", "HELL'S KITCHEN  ·  DEC 18, 1947  ·  3:05 AM"],
	[1, 2, "Somebody gave up a laundry on Tenth.\nIn this town even the dirty money gets washed.", "TENTH AVENUE  ·  DEC 18, 1947  ·  4:40 AM"],
	[1, 3, "A receipt signed M. T. and a road over the roofs.\nDown below, a neon sign kept saying JAZZ.", "HELL'S KITCHEN  ·  DEC 18, 1947  ·  5:15 AM"],
	[1, 4, "Mickey Teague owned the Blue Note and lost every fight he was paid to.\nSomebody was paying for this one too.", "THE BLUE NOTE  ·  DEC 18, 1947  ·  11:30 PM"],
	[2, 0, "Rosie gave me his diary. First page, his hand:\nPier 17. Eleven dead. Who signed the report?", "PIER 17  ·  DEC 19, 1947"],
	[2, 1, "Pier 17 burned twice. Once for money, once for paper.\nThe cranes were next.", "NORTH RIVER  ·  DEC 19, 1947  ·  4:30 AM"],
	[2, 2, "A ship called Santa Lucia, and a dock master\nwho hadn't closed a door in eight years.", "PIER 21  ·  DEC 19, 1947  ·  5:10 AM"],
	[2, 3, "Below decks it smelled of tar and other people's prayers.", "THE SANTA LUCIA  ·  DEC 19, 1947  ·  5:50 AM"],
	[2, 4, "Kessler ran for his office.\nMen like him always run toward their paperwork.", "HARBOR MASTER  ·  DEC 19, 1947  ·  6:20 AM"],
	[3, 0, "They read me my rights in the rain.\nEddie would have written it down.", "10TH PRECINCT  ·  DEC 19, 1947  ·  7:00 AM"],
	[3, 1, "Briggs's men knew the stations.\nI knew the tunnels.", "UNDER 14TH STREET  ·  DEC 19, 1947  ·  8:40 AM"],
	[3, 2, "Down here the dark has a sound.\nIt sounds like trains that never come.", "THE TUNNELS  ·  DEC 19, 1947  ·  10:15 AM"],
	[3, 3, "The yard was the only way out\nthat didn't have a badge standing in it.", "TRAIN YARD  ·  DEC 19, 1947  ·  NOON"],
	[3, 4, "The last train ran out of tunnel\nunder the old Bowery.", "THE BOWERY  ·  DEC 19, 1947  ·  1:30 PM"],
	[4, 0, "Two old men in a tower were drinking to me.\nI meant to spoil it for them.", "MIDTOWN  ·  DEC 24, 1947  ·  CHRISTMAS EVE"],
]
const ENDING := ["For the first time that winter, it snowed.", "NEW YORK  ·  DEC 24, 1947"]

var play := Callable()    # func(chapter: int, map: int), set by main.gd
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
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return bool(cfg.get_value("done", "%d-%d" % [chapter, map], false))


static func mark_done(chapter: int, map: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("done", "%d-%d" % [chapter, map], true)
	cfg.save(SAVE)


static func mark_stars(chapter: int, map: int, stars: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	var key := "%d-%d" % [chapter, map]
	cfg.set_value("stars", key, maxi(stars, int(cfg.get_value("stars", key, 0))))
	cfg.save(SAVE)


static func stars(chapter: int, map: int) -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return int(cfg.get_value("stars", "%d-%d" % [chapter, map], 0))


## The player's settings: music and sound volume 0..10, screen shake and aim assist on or off.
const SETTING_DEFAULTS := {"music": 7, "sound": 8, "shake": true, "assist": true}

static func setting(key: String):
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return cfg.get_value("settings", key, SETTING_DEFAULTS[key])


static func set_setting(key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("settings", key, value)
	cfg.save(SAVE)
	apply_settings()


## Volumes onto the audio buses (sfx.gd makes the Music and SFX buses).
static func apply_settings() -> void:
	for pair in [["Music", "music"], ["SFX", "sound"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			var v: float = float(setting(pair[1])) / 10.0
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)) + 0.0)
			AudioServer.set_bus_mute(i, v <= 0.0)


## What the detective chose when it was his to choose (Briggs: "spared" or "killed").
static func set_story(key: String, value: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("story", key, value)
	cfg.save(SAVE)


static func story(key: String) -> String:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	return String(cfg.get_value("story", key, ""))


static func mark_page(chapter: int, map: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("pages", "%d-%d" % [chapter, map], true)
	cfg.save(SAVE)


static func has_page(chapter: int, map: int) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
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
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	var key := "%d-%d" % [chapter, map]
	cfg.set_value("executed", key, executed)
	cfg.set_value("spared", key, spared)
	cfg.save(SAVE)


static func _sum(section: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	var n := 0
	if cfg.has_section(section):
		for k in cfg.get_section_keys(section):
			n += int(cfg.get_value(section, k, 0))
	return n


## The ash: every man shot with his hands up weighs on Frank; every man let go takes a little off.
static func guilt() -> int:
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
static func ending() -> String:
	var total := 0
	for c in Levels.CAMPAIGN.size():
		total += (Levels.CAMPAIGN[c]["maps"] as Array).size() * 2
	if guilt() < 4 and story("briggs") == "spared" and evidence() * 2 >= total:
		return "snow"
	return "ash"


func _ready() -> void:
	layer = 20
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


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	s.shadow_offset = Vector2(6.0, 6.0)
	return s


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
	var st_l := Paper.write(report, "SETTINGS", _font_head, 30, INK, HORIZONTAL_ALIGNMENT_LEFT, LINE_2, 8.0)
	Paper.line_button(report, st_l, LINE_2, func() -> void:
		var st = load("res://settings.gd").new()
		st.sound = sound
		_page.visible = false
		st.done = func() -> void: _page.visible = true
		add_child(st), sound)
	for k in papers.size():   # they come out of the dark one after another
		var n: Control = papers[k]
		n.modulate.a = 0.0
		n.create_tween().tween_property(n, "modulate:a", 1.0, 0.6).set_delay(1.6 + k * 0.15)

	var cap := Paper.caption(Paper.place_time(String(ph[1])), _font_caption(), 19)   # where and when: a comic's location caption
	cap.position = Vector2(view.x * 0.4, view.y - M - cap.size.y)
	cap.rotation = deg_to_rad(-0.6)
	_page.add_child(cap)


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
		Paper.write(card, String(maps[m]["name"]), _font_type, 18, ink, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.36, 1, 0.28), 10.0)
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


## The marks a closed case earned, inked like a rubber stamp: up to three stars, the rest outlined.
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
