extends CanvasLayer
## The title and the case file, over the street where the story stands right now. What the
## player sees here follows the story: the street of the map they are on, Frank's line for that
## moment typed out under the title, the date and the place on the stamp. The ash thickens as
## he gets closer to the truth (main.gd sets that from phase()).

const Levels = preload("res://levels.gd")
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


static func is_done(chapter: int, map: int) -> bool:
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
	return clampf(0.25 + p[0] * 0.18 + p[1] * 0.03, 0.25, 1.0)


func _ready() -> void:
	layer = 20
	_font_type = load("res://fonts/SpecialElite.ttf")
	_font_head = FontVariation.new()
	_font_head.base_font = load("res://fonts/Oswald.ttf")
	_font_head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	for c in Levels.CAMPAIGN.size():   # the case file opens on the furthest chapter that is open
		if is_open(c, 0):
			_chapter = c
	_title()
	# a phone turned while the title is up: lay the page out again for the new shape
	get_viewport().size_changed.connect(func() -> void:
		if _on_case_file:
			_case_file()
		else:
			_title())


func _process(delta: float) -> void:
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


## A button like a strip of paper pasted on the page: ink caption, slightly askew.
func _button(text: String, at: Vector2, width: float, main: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font_head)
	b.add_theme_font_size_override("font_size", 40 if main else 30)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", CRIMSON)
	b.add_theme_color_override("font_pressed_color", CRIMSON)
	var bg := PAPER if main else PAPER.darkened(0.12)
	for state in ["normal", "hover", "focus"]:
		var st := _box(bg, INK, 4)
		st.content_margin_left = 22.0
		st.content_margin_right = 22.0
		b.add_theme_stylebox_override(state, st)
	b.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), INK, 4))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.position = at
	b.size = Vector2(width, 66.0 if main else 54.0)
	b.rotation = deg_to_rad(randf_range(-1.2, 0.8))
	b.pressed.connect(func() -> void:
		if sound.is_valid():
			sound.call("page")
		on_press.call())
	_page.add_child(b)
	return b


## The title: the logo, Frank's line for this moment typed out beneath it, and what to do next.
func _title() -> void:
	_on_case_file = false
	var view := _new_page()
	if view.x < view.y:   # held upright: the game is played sideways
		_portrait_note(view)
		return
	var shade := TextureRect.new()   # the left of the street darkened so the words read; the right stays open
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.82))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.3, 0.0)
	gt.fill_to = Vector2(0.75, 0.0)
	shade.texture = gt
	shade.size = view
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shade)

	var left := view.x * 0.06
	var logo := TextureRect.new()
	logo.texture = load("res://art/ui/title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	var aspect := float(logo.texture.get_width()) / logo.texture.get_height()
	var lh := minf(view.y * 0.46, view.x * 0.42 / aspect)   # never wider than the left part of the screen
	logo.size = Vector2(lh * aspect, lh)
	logo.position = Vector2(left, view.y * 0.05)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.modulate.a = 0.0
	_page.add_child(logo)
	var tw := logo.create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 1.6).set_delay(0.3)

	var ph := phase()
	_type_text = String(ph[0])
	_type_label = _label(_type_text, _font_type, 26, PAPER, 6)
	_type_label.position = Vector2(left, view.y * 0.53)
	_type_label.size = Vector2(view.x * 0.5, 80.0)
	_type_label.visible_characters = 0
	_type_t = -1.8   # after the title has come up
	_page.add_child(_type_label)

	var p := progress()
	var y := view.y * 0.68
	if p[0] >= 0 and Levels.CAMPAIGN[p[0]]["ready"]:
		var ch: Dictionary = Levels.CAMPAIGN[p[0]]
		var what := "BEGIN" if p[0] == 0 and p[1] == 0 else "CONTINUE"
		var sub := "%s  ·  %s" % [String(ch["title"]), String(ch["maps"][p[1]]["name"])]
		_button(what, Vector2(left, y), 300.0, true, func() -> void: play.call(p[0], p[1]))
		var subl := _label(sub, _font_type, 18, Color(PAPER, 0.8), 5)
		subl.position = Vector2(left + 4.0, y + 72.0)
		subl.size = Vector2(600.0, 26.0)
		_page.add_child(subl)
		y += 112.0
	_button("CASE FILE", Vector2(left, y), 300.0, false, _case_file)

	var stamp := _label(String(ph[1]), _font_type, 20, Color(PAPER, 0.75), 5)
	stamp.position = Vector2(view.x - 640.0, view.y - 52.0)
	stamp.size = Vector2(600.0, 30.0)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page.add_child(stamp)


## The case file: one chapter at a time, its maps as pasted comic panels.
func _case_file() -> void:
	_on_case_file = true
	var view := _new_page()
	if view.x < view.y:
		_portrait_note(view)
		return
	_type_label = null
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.size = view
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shade)

	var ch: Dictionary = Levels.CAMPAIGN[_chapter]
	var t1 := _label(String(ch["title"]), _font_type, 26, Color(0.75, 0.72, 0.66), 6)
	t1.position = Vector2(0.0, view.y * 0.07)
	t1.size = Vector2(view.x, 36.0)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(t1)
	var t2 := _label(String(ch["name"]), _font_head, 56, PAPER, 14)
	t2.position = Vector2(0.0, view.y * 0.07 + 34.0)
	t2.size = Vector2(view.x, 76.0)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page.add_child(t2)

	var maps: Array = ch["maps"]
	var gap := 22.0
	var w := minf(250.0, (view.x - 320.0 - gap * (maps.size() - 1)) / maps.size())
	var h := w * 1.25
	var x0 := (view.x - (w * maps.size() + gap * (maps.size() - 1))) * 0.5
	var y0 := view.y * 0.07 + 140.0
	for m in maps.size():
		var open := is_open(_chapter, m)
		var done := is_done(_chapter, m)
		var panel := Button.new()
		panel.position = Vector2(x0 + m * (w + gap), y0 + (12.0 if m % 2 == 1 else 0.0))   # off-line, like hand-pasted panels
		panel.size = Vector2(w, h)
		panel.rotation = deg_to_rad(-1.2 if m % 2 == 0 else 1.0)
		panel.focus_mode = Control.FOCUS_NONE
		var bg := PAPER if open else Color(0.2, 0.2, 0.22)
		for state in ["normal", "hover", "focus", "disabled"]:
			panel.add_theme_stylebox_override(state, _box(bg, INK, 6))
		panel.add_theme_stylebox_override("pressed", _box(bg.darkened(0.15), INK, 6))
		panel.disabled = not open
		if open:
			panel.pressed.connect(func() -> void: play.call(_chapter, m))
		_page.add_child(panel)
		var num := _label(str(m + 1), _font_head, 76, INK if open else Color(0.4, 0.4, 0.42))
		num.position = Vector2(0.0, h * 0.03)
		num.size = Vector2(w, 100.0)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(num)
		var nm := _label(String(maps[m]["name"]), _font_type, 20, INK if open else Color(0.45, 0.45, 0.47))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.position = Vector2(8.0, h * 0.45)
		nm.size = Vector2(w - 16.0, 60.0)
		panel.add_child(nm)
		var tag := ""
		if not ch["ready"]:
			tag = "SOON"
		elif done:
			tag = "CLOSED" + ("  " + "I".repeat(stars(_chapter, m)) if stars(_chapter, m) > 0 else "")
		elif open:
			tag = "PLAY"
		else:
			tag = "LOCKED"
		var stamp := _label(tag, _font_head, 32, CRIMSON if done or tag == "PLAY" else Color(0.55, 0.55, 0.57))
		stamp.position = Vector2(0.0, h - 50.0)
		stamp.size = Vector2(w, 44.0)
		stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if done:
			stamp.rotation = deg_to_rad(-8.0)
		panel.add_child(stamp)

	if not ch["ready"]:
		var soon := _label("THE INVESTIGATION CONTINUES SOON", _font_type, 26, PAPER, 6)
		soon.position = Vector2(0.0, y0 + h + 40.0)
		soon.size = Vector2(view.x, 40.0)
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_page.add_child(soon)

	for side in [-1, 1]:   # turning the pages of the file
		var to: int = _chapter + side
		if to < 0 or to >= Levels.CAMPAIGN.size():
			continue
		var b := Button.new()
		b.text = "<" if side < 0 else ">"
		b.add_theme_font_override("font", _font_head)
		b.add_theme_font_size_override("font_size", 64)
		b.add_theme_color_override("font_color", PAPER)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, _box(Color(0.08, 0.08, 0.09, 0.9), PAPER, 4))
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(80.0, 120.0)
		b.position = Vector2(24.0 if side < 0 else view.x - 104.0, y0 + h * 0.5 - 60.0)
		b.pressed.connect(func() -> void:
			_chapter = to
			if sound.is_valid():
				sound.call("page")
			_case_file())
		_page.add_child(b)
	_button("BACK", Vector2(view.x * 0.06, view.y - 100.0), 180.0, false, _title)


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
