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
	dim.color = Color(0, 0, 0, 0.82)
	dim.size = view
	_root.add_child(dim)
	# the map's caption at the top, PAUSED under it, then the four tapes, all on one centre line
	var Paper = load("res://paper.gd")
	var cap: Control = Paper.caption(title, load("res://fonts/ComicNeue-BoldItalic.woff"), 20)
	cap.position = Vector2(view.x * 0.5 - cap.size.x * 0.5, 40.0)
	_root.add_child(cap)
	var top := Label.new()
	top.text = "PAUSED"
	top.add_theme_font_override("font", _head)
	top.add_theme_font_size_override("font_size", 60)
	top.add_theme_color_override("font_color", PAPER)
	top.add_theme_color_override("font_outline_color", INK)
	top.add_theme_constant_override("outline_size", 12)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.position = Vector2(0.0, 140.0)
	top.size = Vector2(view.x, 80.0)
	_root.add_child(top)
	var y := 236.0
	var bw := 380.0
	var items := [["RESUME", _resume, "tape"], ["RESTART CHECKPOINT", _restart, "strip"], ["SETTINGS", _settings, "strip"], ["QUIT TO TITLE", _quit, "strip"]]
	for i in items.size():
		var it: Array = items[i]
		var b: Control = Paper.button(String(it[2]), Vector2(bw, 64.0 if i == 0 else 56.0), it[1])
		b.position = Vector2(view.x * 0.5 - bw * 0.5, y)
		b.rotation = deg_to_rad([-0.8, 0.6, -0.4, 0.7][i])
		_root.add_child(b)
		Paper.write(b, String(it[0]), _head, 30 if i == 0 else 26, Paper.INK)
		y += (64.0 if i == 0 else 56.0) + 18.0


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
