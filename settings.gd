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
var _card: Control


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
	var size := Vector2(minf(720.0, view.x - 96.0), 480.0)
	_card = Paper.sheet("panel", size)   # an inked comic panel of old paper
	_card.position = (view - size) * 0.5
	_card.rotation = deg_to_rad(-0.5)
	add_child(_card)
	var inner: Rect2 = _card.get_meta("inner")
	var pad := 26.0
	var left := inner.position.x + pad
	var right := inner.end.x - pad
	var title := _label("SETTINGS", _head, 44, INK)
	title.position = Vector2(left, inner.position.y + 18.0)
	title.size = Vector2(right - left, 56.0)
	_card.add_child(title)
	# four rows evenly between the title and the back button, each centred on its line
	var top := inner.position.y + 18.0 + 56.0 + 14.0
	var bottom := inner.end.y - 20.0 - 56.0 - 14.0
	var step := (bottom - top) / 4.0
	var rows := [["MUSIC", "music", true], ["SOUND", "sound", true], ["SCREEN SHAKE", "shake", false], ["AIM ASSIST", "assist", false]]
	for i in rows.size():
		_row(top + step * (i + 0.5), left, right, String(rows[i][0]), String(rows[i][1]), bool(rows[i][2]))
	var back: Control = Paper.button("tape", Vector2(170.0, 56.0), func() -> void:
		if done.is_valid():
			done.call()
		queue_free(), sound)
	back.position = Vector2(left - 6.0, inner.end.y - 20.0 - 56.0)
	_card.add_child(back)
	Paper.write(back, "BACK", _head, 26, INK)


## One setting on its line: the name at the left, the control at the right, both centred on the line.
func _row(mid_y: float, left: float, right: float, text: String, key: String, volume: bool) -> void:
	var l := _label(text, _type, 26, INK)
	l.position = Vector2(left, mid_y - 20.0)
	l.size = Vector2(300.0, 40.0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_child(l)
	if volume:   # [-] 7 [+]
		var bw := 60.0
		var plus: Control = Paper.button("tape", Vector2(bw, bw), _step.bind(key, 1), sound)
		plus.position = Vector2(right - bw, mid_y - bw * 0.5)
		Paper.write(plus, "+", _head, 34, INK, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0, 1, 1), 0.0)
		var v := _label("", _head, 34, INK)
		v.position = Vector2(right - bw - 72.0, mid_y - 24.0)
		v.size = Vector2(72.0, 48.0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var minus: Control = Paper.button("tape", Vector2(bw, bw), _step.bind(key, -1), sound)
		minus.position = Vector2(right - bw * 2.0 - 72.0, mid_y - bw * 0.5)
		Paper.write(minus, "\u2212", _head, 34, INK, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0, 1, 1), 0.0)
		for n in [minus, v, plus]:
			_card.add_child(n)
		_rows[key] = v
	else:   # a strip of tape that says what it is now
		var t: Control = Paper.button("tape", Vector2(184.0, 52.0), func() -> void:
			MenuScript.set_setting(key, not bool(MenuScript.setting(key)))
			_show(), sound)
		t.position = Vector2(right - 184.0, mid_y - 26.0)
		_card.add_child(t)
		_rows[key] = Paper.write(t, "", _head, 26, INK)
	_show()


func _step(key: String, by: int) -> void:
	MenuScript.set_setting(key, clampi(int(MenuScript.setting(key)) + by, 0, 10))
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
	l.set_meta("inside", true)   # all of them sit on the card: the check keeps them in its frame
	return l
