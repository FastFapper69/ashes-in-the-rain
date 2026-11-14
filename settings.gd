extends CanvasLayer
## The settings card: music and sound volume, screen shake, aim assist. Opened from the title and from
## the pause card; saved at once, nothing to confirm.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const CRIMSON := Color(0.6, 0.1, 0.07)
const MenuScript = preload("res://menu.gd")
const Paper = preload("res://paper.gd")

var done := Callable()
var sound := Callable()   # func(name: String)

var _head: FontVariation
var _type: Font
var _rows: Dictionary = {}   # key -> value label


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_head = FontVariation.new()
	_head.base_font = load("res://fonts/Oswald.ttf")
	_head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	_type = load("res://fonts/SpecialElite.ttf")
	var view := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = view
	add_child(dim)
	var card := Paper.card("caption", Vector2.ZERO, 0.08)   # an inked comic panel of old paper
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size = Vector2(minf(820.0, view.x * 0.7), minf(580.0, view.y * 0.86))
	card.position = (view - card.size) * 0.5
	card.rotation = deg_to_rad(-0.6)
	add_child(card)
	var title := _label("SETTINGS", _head, 54, INK)
	title.position = Vector2(52.0, 30.0)
	card.add_child(title)
	var y := 112.0
	var step := (card.size.y - 112.0 - 120.0) / 4.0
	_row(card, y, "MUSIC", "music", true)
	_row(card, y + step, "SOUND", "sound", true)
	_row(card, y + step * 2.0, "SCREEN SHAKE", "shake", false)
	_row(card, y + step * 3.0, "AIM ASSIST", "assist", false)
	var back := _button("BACK", Vector2(52.0, card.size.y - 100.0), 220.0, true)
	back.pressed.connect(func() -> void:
		_click()
		if done.is_valid():
			done.call()
		queue_free())
	card.add_child(back)


func _row(card: Control, y: float, text: String, key: String, volume: bool) -> void:
	var l := _label(text, _type, 34, INK)
	l.position = Vector2(56.0, y)
	card.add_child(l)
	var x := card.size.x - 356.0
	if volume:
		var minus := _button("-", Vector2(x, y - 6.0), 64.0, false)
		var plus := _button("+", Vector2(x + 220.0, y - 6.0), 64.0, false)
		var v := _label("", _head, 40, INK)
		v.position = Vector2(x + 76.0, y - 8.0)
		v.size = Vector2(132.0, 56.0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(minus)
		card.add_child(plus)
		card.add_child(v)
		_rows[key] = v
		minus.pressed.connect(_step.bind(key, -1))
		plus.pressed.connect(_step.bind(key, 1))
	else:
		var b := _button("", Vector2(x, y - 6.0), 284.0, false)
		card.add_child(b)
		_rows[key] = b
		b.pressed.connect(func() -> void:
			MenuScript.set_setting(key, not bool(MenuScript.setting(key)))
			_click()
			_show())
	_show()


func _step(key: String, by: int) -> void:
	MenuScript.set_setting(key, clampi(int(MenuScript.setting(key)) + by, 0, 10))
	_click()
	_show()


func _show() -> void:
	for key in _rows:
		var n = _rows[key]
		var v = MenuScript.setting(key)
		if v is bool:
			n.text = "ON" if v else "OFF"
			n.add_theme_color_override("font_color", INK if v else CRIMSON)
		else:   # a row of ten marks, the set ones inked
			n.text = str(int(v))


func _click() -> void:
	if sound.is_valid():
		sound.call("page")


func _label(t: String, font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _button(t: String, at: Vector2, w: float, main: bool) -> Button:
	var b := Paper.button("tape" if main else ("tag" if w < 100.0 else "strip"), t, _head, 36, Vector2(w, 60.0))
	if w < 100.0:   # the little + and - squares: plain torn tape
		b = Paper.button("tape", t, _head, 36, Vector2(w, 60.0))
	b.position = at
	return b
