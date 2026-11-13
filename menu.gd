extends CanvasLayer
## The case file: the campaign menu over the rainy street. One chapter at a time, its five maps as
## comic panels: done ones stamped CLOSED, the next one open to play, the rest locked.

const Levels = preload("res://levels.gd")
const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const CRIMSON := Color(0.6, 0.1, 0.07)
const SAVE := "user://progress2.cfg"   # progress2: the maps were rebuilt longer, old progress no longer applies

var play := Callable()   # func(chapter: int, map: int), set by main.gd
var _chapter := 0
var _page: Control


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


func _ready() -> void:
	layer = 20
	# start on the furthest chapter that is open
	for c in Levels.CAMPAIGN.size():
		if is_open(c, 0):
			_chapter = c
	_build()


func _label(text: String, font_size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	s.shadow_offset = Vector2(8.0, 8.0)
	return s


func _build() -> void:
	if _page != null:
		_page.queue_free()
	var view := get_viewport().get_visible_rect().size
	_page = Control.new()
	_page.size = view
	add_child(_page)
	var shade := ColorRect.new()   # the street stays visible, dimmed, behind the file
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.size = view
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shade)

	var logo := _label("INK & LEAD", 96, PAPER, 22)
	logo.position = Vector2(0.0, view.y * 0.06)
	logo.size = Vector2(view.x, 110.0)
	_page.add_child(logo)

	var ch: Dictionary = Levels.CAMPAIGN[_chapter]
	var t1 := _label(String(ch["title"]), 30, Color(0.75, 0.72, 0.66), 8)
	t1.position = Vector2(0.0, view.y * 0.06 + 120.0)
	t1.size = Vector2(view.x, 40.0)
	_page.add_child(t1)
	var t2 := _label(String(ch["name"]), 52, PAPER, 14)
	t2.position = Vector2(0.0, view.y * 0.06 + 158.0)
	t2.size = Vector2(view.x, 64.0)
	_page.add_child(t2)

	# the five maps: comic panels across the page
	var maps: Array = ch["maps"]
	var gap := 22.0
	var w := minf(260.0, (view.x - 320.0 - gap * (maps.size() - 1)) / maps.size())
	var h := w * 1.25
	var x0 := (view.x - (w * maps.size() + gap * (maps.size() - 1))) * 0.5
	var y0 := view.y * 0.06 + 250.0
	for m in maps.size():
		var open := is_open(_chapter, m)
		var done := is_done(_chapter, m)
		var panel := Button.new()
		panel.position = Vector2(x0 + m * (w + gap), y0 + (12.0 if m % 2 == 1 else 0.0))   # a little off-line, like hand-pasted panels
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
		var num := _label(str(m + 1), 72, INK if open else Color(0.4, 0.4, 0.42))
		num.position = Vector2(0.0, h * 0.05)
		num.size = Vector2(w, 90.0)
		panel.add_child(num)
		var nm := _label(String(maps[m]["name"]), 20, INK if open else Color(0.45, 0.45, 0.47))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.position = Vector2(8.0, h * 0.42)
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
		var stamp := _label(tag, 30, CRIMSON if done or tag == "PLAY" else Color(0.55, 0.55, 0.57))
		stamp.position = Vector2(0.0, h - 44.0)
		stamp.size = Vector2(w, 40.0)
		if done:
			stamp.rotation = deg_to_rad(-8.0)
		panel.add_child(stamp)

	if not ch["ready"]:
		var soon := _label("THE INVESTIGATION CONTINUES SOON", 30, PAPER, 8)
		soon.position = Vector2(0.0, y0 + h + 40.0)
		soon.size = Vector2(view.x, 40.0)
		_page.add_child(soon)

	# turning the pages of the file
	for side in [-1, 1]:
		var to: int = _chapter + side
		if to < 0 or to >= Levels.CAMPAIGN.size():
			continue
		var b := Button.new()
		b.text = "<" if side < 0 else ">"
		b.add_theme_font_size_override("font_size", 64)
		b.add_theme_color_override("font_color", PAPER)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, _box(Color(0.08, 0.08, 0.09, 0.9), PAPER, 4))
		b.focus_mode = Control.FOCUS_NONE
		b.size = Vector2(80.0, 120.0)
		b.position = Vector2(24.0 if side < 0 else view.x - 104.0, y0 + h * 0.5 - 60.0)
		b.pressed.connect(func() -> void:
			_chapter = to
			_build())
		_page.add_child(b)
