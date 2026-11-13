extends CanvasLayer
## The story between the maps, told as a comic that comes to life: one drawn panel after another,
## the camera drifting slowly over each, rain falling across the page, and Frank's narration typed
## into cream caption boxes. A tap finishes the line being typed or turns to the next; SKIP ends it.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const SPEECH := Color(0.98, 0.97, 0.94)
const TYPE_STEP := 0.032   # seconds per letter

## Every cutscene: a list of panels. A panel: its picture (art/cut/<img>.jpg); where the camera starts
## and ends ([x, y] of the picture to centre on, as fractions, and a zoom where 1.0 just fills the
## screen); the lines (a line in quotes is somebody speaking); and its weather and sounds.
const SCENES := {
	"eddie": [
		{"img": 49, "from": [0.5, 0.4, 1.12], "to": [0.62, 0.5, 1.0], "rain": 1.0, "stamp": "NEW YORK  ·  DECEMBER 18, 1947  ·  2:10 A.M.",
			"lines": ["Eleven days of rain. The city had forgotten what dry felt like.", "Somewhere under it, a phone was about to ring."]},
		{"img": 50, "from": [0.45, 0.45, 1.0], "to": [0.66, 0.42, 1.18], "rain": 0.0, "sound": "phone_ring",
			"lines": ["Ten past two. Nobody calls at ten past two with good news.", "I knew before I picked it up. You always know."]},
		{"img": 51, "from": [0.3, 0.5, 1.15], "to": [0.5, 0.62, 1.02], "rain": 1.0,
			"lines": ["They had him under a tarp behind the Blue Note, like something the club forgot to take out.", "Eddie Doyle. Reporter. My friend, when he remembered to be."]},
		{"img": 52, "from": [0.5, 0.5, 1.0], "to": [0.5, 0.56, 1.22], "rain": 0.6,
			"lines": ["Somebody had to look. Somebody always does.", "The man in the puddle looked like he owed somebody money."]},
		{"img": 53, "from": [0.35, 0.45, 1.05], "to": [0.66, 0.58, 1.3], "rain": 0.7, "hit": 1,
			"lines": ["In his fist, a matchbook from the Blue Note.", "His notebook was soaked through. They didn't let me read it. Not yet."]},
	],
	"interlude": [
		{"img": 54, "from": [0.62, 0.45, 1.0], "to": [0.52, 0.52, 1.2], "rain": 0.0,
			"lines": ["A laundry receipt. Two hundred dollars for shirts nobody would ever wear.", "Signed M. T. Mickey Teague signed everything. Even his fights."]},
		{"img": 55, "from": [0.5, 0.5, 1.12], "to": [0.42, 0.45, 1.0], "rain": 0.0,
			"lines": ["Two weeks ago Eddie bought the coffee. Eddie never bought the coffee.", "\"Frank, I need to tell you something. Tomorrow.\"", "Tomorrow was a long time coming. Then it didn't come at all."]},
	],
	"teague": [
		{"img": 56, "from": [0.3, 0.6, 1.15], "to": [0.55, 0.5, 1.0], "rain": 0.0,
			"lines": ["Mickey went down on cue, like always.", "\"Feed my birds, Frank... Pier Seventeen. Ask your boss.\""]},
		{"img": 57, "from": [0.5, 0.42, 1.0], "to": [0.47, 0.38, 1.16], "rain": 0.0,
			"lines": ["Rosie Kowalski came down off the stage like it was the last song of the night.", "Eddie's girl. She'd been holding something for him."]},
		{"img": 58, "from": [0.45, 0.5, 1.0], "to": [0.52, 0.48, 1.2], "rain": 0.0,
			"lines": ["\"He said if anything happened, you'd know what to do.\""]},
		{"img": 59, "from": [0.4, 0.5, 1.0], "to": [0.62, 0.45, 1.55], "rain": 0.0, "hit": 1,
			"lines": ["Pier 17. Eleven dead. Who signed the report?", "Everybody on the West Side remembered that fire. I remembered it as well as anybody."]},
	],
	"kessler": [
		{"img": 64, "from": [0.35, 0.45, 1.05], "to": [0.55, 0.62, 1.4], "rain": 0.0, "hit": 1,
			"lines": ["Second drawer, like Eddie said. PIER 17. FIRE. CAUSE: ACCIDENTAL.", "At the bottom, in ink gone brown: Ptl. F. Malone. My hand. My two hundred dollars."]},
		{"img": 65, "from": [0.7, 0.4, 1.2], "to": [0.4, 0.45, 1.0], "rain": 0.8, "sound": "door",
			"lines": ["\"Frank Malone. You're under arrest for the murder of Eddie Doyle.\"", "Declan Rourke taught me how to tie a tie. He coughed into my mother's handkerchief and wouldn't look me in the eye."]},
	],
	"docks": [
		{"img": 60, "from": [0.3, 0.55, 1.12], "to": [0.6, 0.45, 1.0], "rain": 1.2,
			"lines": ["The waterfront at four in the morning. The ash was thicker down here.", "Pier 17 had been dead for eight years. Nobody told the smoke."]},
		{"img": 61, "from": [0.5, 0.4, 1.0], "to": [0.5, 0.3, 1.25], "rain": 0.0, "sound": "match",
			"lines": ["Bruno Kessler. Dock master since '38. Sleeps with every door open.", "A man who sleeps like that knows what a locked door costs."]},
	],
}

var scene_id := ""
var done := Callable()    # called once the last panel has gone dark (or SKIP)
var sound := Callable()   # func(name: String, db: float)
var shot := Callable()    # tests only: func(name: String) saves a picture
var fast := false         # tests: no waiting to read

var _panels: Array = []
var _i := -1
var _line := 0
var _pic: Sprite2D
var _old: Sprite2D
var _stage: Node2D
var _rain: Control
var _drops: Array = []
var _rain_on := 0.0
var _rain_want := 0.0
var _boxes: Array = []
var _typing: Label
var _type_t := 0.0
var _wait := 0.0     # seconds left to read the line, then the next one comes by itself
var _pan_t := 0.0
var _pan_len := 8.0
var _font_type: Font
var _font_head: FontVariation
var _stamp: Label
var _flash: ColorRect
var _black: ColorRect
var _ending := false
var _shot_taken := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panels = SCENES.get(scene_id, [])
	_font_type = load("res://fonts/SpecialElite.ttf")
	_font_head = FontVariation.new()
	_font_head.base_font = load("res://fonts/Oswald.ttf")
	_font_head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_rain = Control.new()
	_rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain.draw.connect(_draw_rain)
	add_child(_rain)
	var vig := TextureRect.new()   # the page darkens toward its edges
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.05, 1.05)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.75))
	grad.add_point(0.55, Color(0, 0, 0, 0.0))
	g.gradient = grad
	vig.texture = g
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	var skip := Button.new()
	skip.text = "SKIP  ▸▸"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", _font_head)
	skip.add_theme_font_size_override("font_size", 26)
	skip.add_theme_color_override("font_color", Color(PAPER, 0.75))
	skip.add_theme_color_override("font_hover_color", PAPER)
	skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-170.0, 18.0)
	skip.size = Vector2(150.0, 54.0)
	skip.pressed.connect(_finish)
	add_child(skip)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	for k in 110:
		_drops.append(Vector3(randf(), randf(), randf_range(0.6, 1.0)))
	get_viewport().size_changed.connect(_place_pic)
	_next_panel()


func _view() -> Vector2:
	return get_viewport().get_visible_rect().size


func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT])
	if not tap or _ending:
		return
	var at: Vector2 = event.position if not event is InputEventKey else Vector2.ZERO
	if at.x > _view().x - 190.0 and at.y < 90.0:   # the SKIP button takes its own taps
		return
	get_viewport().set_input_as_handled()
	if _typing != null and _typing.visible_characters < _typing.text.length():
		_typing.visible_characters = _typing.text.length()   # the whole line at once
		_wait = 2.5
	else:
		_advance()


func _process(delta: float) -> void:
	if _ending:
		return
	# the slow drift over the picture
	_pan_t += delta
	_place_pic()
	# the letters of the line being typed
	if _typing != null and _typing.visible_characters < _typing.text.length():
		_type_t += delta
		while _type_t > TYPE_STEP and _typing.visible_characters < _typing.text.length():
			_type_t -= TYPE_STEP
			_typing.visible_characters += 1
			var ch := _typing.text[_typing.visible_characters - 1]
			if ch in ".,?!":
				_type_t = -0.18
			if ch != " " and _typing.visible_characters % 2 == 0 and sound.is_valid():
				sound.call("type", -16.0)
		if fast:
			_typing.visible_characters = _typing.text.length()
		if _typing.visible_characters >= _typing.text.length():
			_wait = 1.0 if fast else 1.8 + _typing.text.length() * 0.035
	elif _wait > 0.0:
		if fast and not _shot_taken and shot.is_valid() and _line == _panels[_i]["lines"].size() - 1:
			_shot_taken = true
			shot.call("cut_%s_%d" % [scene_id, _i])
		_wait -= delta
		if _wait <= 0.0:
			_advance()
	# the rain over the page
	_rain_on = move_toward(_rain_on, _rain_want, delta * 0.8)
	for k in _drops.size():
		var d: Vector3 = _drops[k]
		d.y += delta * (1.6 + d.z * 0.9)
		d.x -= delta * 0.12
		if d.y > 1.1:
			d = Vector3(randf() * 1.2, -0.1 - randf() * 0.2, d.z)
		_drops[k] = d
	_rain.queue_redraw()
	if _stamp != null and _stamp.visible_characters < _stamp.text.length():
		_stamp.visible_characters = mini(_stamp.text.length(), _stamp.visible_characters + 1)


func _draw_rain() -> void:
	if _rain_on <= 0.01:
		return
	var view := _view()
	for d in _drops:
		var p := Vector2(d.x * view.x, d.y * view.y)
		var ln: float = 34.0 + d.z * 40.0
		_rain.draw_line(p, p + Vector2(-0.12, 1.0).normalized() * ln, Color(0.85, 0.87, 0.92, 0.16 * d.z * _rain_on), 1.6)


## Where the camera is over the current picture: from its start to its end, eased, over the time the
## panel is up, always covering the whole screen.
func _place_pic() -> void:
	if _pic == null:
		return
	var p: Dictionary = _panels[_i]
	var k := clampf(_pan_t / _pan_len, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var a: Array = p["from"]
	var b: Array = p["to"]
	var f := Vector2(lerpf(a[0], b[0], k), lerpf(a[1], b[1], k))
	var zoom := lerpf(a[2], b[2], k)
	_frame(_pic, f, zoom)


func _frame(s: Sprite2D, focus: Vector2, zoom: float) -> void:
	var view := _view()
	var tex := s.texture.get_size()
	var sc: float = maxf(view.x / tex.x, view.y / tex.y) * zoom
	s.scale = Vector2(sc, sc)
	var size := tex * sc
	var pos := view * 0.5 - (focus - Vector2(0.5, 0.5)) * size
	pos.x = clampf(pos.x, view.x - size.x * 0.5, size.x * 0.5)
	pos.y = clampf(pos.y, view.y - size.y * 0.5, size.y * 0.5)
	s.position = pos


func _advance() -> void:
	var lines: Array = _panels[_i]["lines"]
	if _line + 1 < lines.size():
		_line += 1
		_show_line()
	else:
		_next_panel()


func _next_panel() -> void:
	_i += 1
	if _i >= _panels.size():
		_finish()
		return
	var p: Dictionary = _panels[_i]
	for b in _boxes:   # the old captions leave with their picture
		if is_instance_valid(b):
			var tw: Tween = b.create_tween()
			tw.tween_property(b, "modulate:a", 0.0, 0.3)
			tw.tween_callback(b.queue_free)
	_boxes.clear()
	_typing = null
	if _stamp != null:
		_stamp.queue_free()
		_stamp = null
	if _old != null:
		_old.queue_free()
	_old = _pic
	_pic = Sprite2D.new()
	_pic.texture = load("res://art/cut/%d.jpg" % int(p["img"]))
	_pic.modulate.a = 0.0
	_stage.add_child(_pic)
	_pan_t = 0.0
	_line = 0
	_shot_taken = false
	var chars := 0
	for l in p["lines"]:
		chars += String(l).length()
	_pan_len = 3.0 + p["lines"].size() * 2.2 + chars * 0.07
	_place_pic()
	var tw := create_tween()
	tw.tween_property(_pic, "modulate:a", 1.0, 0.7 if _i > 0 else 1.4)
	if _i == 0:
		create_tween().tween_property(_black, "color:a", 0.0, 1.2)
	elif sound.is_valid():
		sound.call("page", -6.0)
	_rain_want = float(p.get("rain", 0.0))
	if p.has("sound") and sound.is_valid():
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
			if is_inside_tree():
				sound.call(String(p["sound"]), -4.0))
	if p.has("hit"):   # the key picture lands with a low chord and a flash
		get_tree().create_timer(0.35, true, false, true).timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			if sound.is_valid():
				sound.call("sting", -3.0)
			_flash.color.a = 0.35
			create_tween().tween_property(_flash, "color:a", 0.0, 0.9))
	if p.has("stamp"):
		_stamp = Label.new()
		_stamp.text = String(p["stamp"])
		_stamp.add_theme_font_override("font", _font_head)
		_stamp.add_theme_font_size_override("font_size", 30)
		_stamp.add_theme_color_override("font_color", PAPER)
		_stamp.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		_stamp.add_theme_constant_override("shadow_offset_x", 3)
		_stamp.add_theme_constant_override("shadow_offset_y", 3)
		_stamp.visible_characters = 0
		_stamp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_stamp.position = Vector2(48.0, -78.0)
		_stamp.size = Vector2(900.0, 50.0)
		_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_stamp)
	get_tree().create_timer(0.9 if _i == 0 else 0.5, true, false, true).timeout.connect(func() -> void:
		if is_inside_tree() and not _ending and _line == 0 and _typing == null:
			_show_line())


## One caption box: the first of a panel at the top left, the next at the bottom right, like boxes
## stepping down a page. Spoken lines are white, with their quotes.
func _show_line() -> void:
	var text := String(_panels[_i]["lines"][_line])
	if _typing != null:
		_typing.visible_characters = _typing.text.length()
	var speech := text.begins_with("\"")
	var view := _view()
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SPEECH if speech else PAPER
	style.border_color = INK
	style.set_border_width_all(4)
	style.set_content_margin_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_offset = Vector2(7, 7)
	if speech:
		style.set_corner_radius_all(26)
	box.add_theme_stylebox_override("panel", style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text if speech else text.to_upper()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _font_type)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", INK)
	l.visible_characters = 0
	var w := minf(view.x * 0.46, 40.0 + text.length() * 16.5)
	l.custom_minimum_size = Vector2(maxf(w, 260.0), 0.0)
	box.add_child(l)
	add_child(box)
	move_child(box, _black.get_index())
	var n := _boxes.size()
	box.modulate.a = 0.0
	_place_box.call_deferred(box, n)
	_boxes.append(box)
	_typing = l
	_type_t = 0.0
	_wait = 0.0


## Once the box knows how tall its wrapped text is: where it goes on the page.
func _place_box(box: PanelContainer, n: int) -> void:
	if not is_instance_valid(box):
		return
	box.reset_size()
	var l: Label = box.get_child(0)
	var text_h := _font_type.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, l.custom_minimum_size.x + 8.0, 30).y
	box.size.y = maxf(box.size.y, text_h + 40.0)
	var view := _view()
	var margin := Vector2(46.0, 44.0)
	var y_top := 30.0 + float(n / 2) * 140.0
	if n % 2 == 0:
		box.position = Vector2(margin.x + n * 20.0, y_top + margin.y * 0.4)
	else:
		box.position = Vector2(view.x - box.size.x - margin.x, view.y - box.size.y - margin.y - float(n / 2) * 140.0)
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.25)


func _finish() -> void:
	if _ending:
		return
	_ending = true
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	tw.tween_callback(func() -> void:
		if done.is_valid():
			done.call()
		queue_free())
