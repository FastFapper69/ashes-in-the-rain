extends CanvasLayer
## The game held still: resume, back to the last checkpoint, settings, or out to the title.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const CRIMSON := Color(0.6, 0.1, 0.07)
const SettingsScript = preload("res://settings.gd")

var title := ""            # the map's name, at the top of the card
var on_restart := Callable()
var on_quit := Callable()
var on_close := Callable()
var sound := Callable()

var _head: FontVariation
var _root: Control


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_head = FontVariation.new()
	_head.base_font = load("res://fonts/Oswald.ttf")
	_head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var view := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.size = view
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = view
	_root.add_child(dim)
	var x := view.x * 0.5 - 200.0
	var top := Label.new()
	top.text = "PAUSED"
	top.add_theme_font_override("font", _head)
	top.add_theme_font_size_override("font_size", 72)
	top.add_theme_color_override("font_color", PAPER)
	top.position = Vector2(x, view.y * 0.1)
	_root.add_child(top)
	var sub := Label.new()
	sub.text = title
	sub.add_theme_font_override("font", load("res://fonts/SpecialElite.ttf"))
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(PAPER, 0.7))
	sub.position = Vector2(x + 4.0, view.y * 0.1 + 100.0)
	_root.add_child(sub)
	var y := view.y * 0.1 + 170.0
	for item in [["RESUME", _resume, true], ["RESTART CHECKPOINT", _restart, false], ["SETTINGS", _settings, false], ["QUIT TO TITLE", _quit, false]]:
		var b := _button(String(item[0]), Vector2(x, y), 400.0, bool(item[2]))
		b.pressed.connect(item[1])
		_root.add_child(b)
		y += 92.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
		get_viewport().set_input_as_handled()
		_resume()


func _resume() -> void:
	_click()
	get_tree().paused = false
	if on_close.is_valid():
		on_close.call()
	queue_free()


func _restart() -> void:
	_click()
	get_tree().paused = false
	queue_free()
	if on_restart.is_valid():
		on_restart.call()


func _quit() -> void:
	_click()
	get_tree().paused = false
	queue_free()
	if on_quit.is_valid():
		on_quit.call()


func _settings() -> void:
	_click()
	_root.visible = false
	var s = SettingsScript.new()
	s.sound = sound
	s.done = func() -> void: _root.visible = true
	add_child(s)


func _click() -> void:
	if sound.is_valid():
		sound.call("page")


func _button(t: String, at: Vector2, w: float, main: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", _head)
	b.add_theme_font_size_override("font_size", 38 if main else 32)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = PAPER if main else PAPER.darkened(0.12)
		if state == "pressed":
			st.bg_color = st.bg_color.darkened(0.2)
		st.border_color = INK
		st.set_border_width_all(4)
		st.content_margin_left = 22.0
		st.shadow_color = Color(0, 0, 0, 0.55)
		st.shadow_offset = Vector2(6, 6)
		b.add_theme_stylebox_override(state, st)
	for c in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_pressed_color", CRIMSON)
	b.position = at
	b.size = Vector2(w, 70.0 if main else 62.0)
	b.rotation = deg_to_rad(randf_range(-0.8, 0.8))
	return b
