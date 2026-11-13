extends CanvasLayer
# What sits on the glass: the detective's portrait and health, the thumbstick, and the buttons.
# It lives on a layer above the screen-wide grade, so the drawings keep their own colours.
# It also reads the touches; main.gd picks the results up from the variables below.

const CRIMSON := Color(0.541, 0.11, 0.078)
const AMBER := Color(0.95, 0.66, 0.13)
const BAR_INNER := [Vector2(60.0, 28.0), Vector2(892.0, 28.0), Vector2(866.0, 118.0), Vector2(33.0, 118.0)]
const SEGMENTS := 5

var move := 0.0            # -1, 0 or 1 from the thumbstick
var duck := false          # the thumbstick is pulled down
var fire_tapped := false   # main.gd sets these back to false once it has acted on them
var slow_tapped := false
var jump_tapped := false
var dive_tapped := false
var aim_at := Vector2.ZERO   # where the aiming finger is, in screen pixels
var aim_held := false       # an aiming finger is on the screen
var aim_left := 0.0         # seconds the aim stays where the finger last was
var _aim_finger := -1
var touch_seen := false    # true once a finger has touched the screen: then the mouse is ignored

var _portrait: Sprite2D
var _bar: Sprite2D
var _fill: Polygon2D
var _ring: Sprite2D
var _knob: Sprite2D
var _fire: Sprite2D
var _slow: Sprite2D
var _meter: Line2D
var _jump: Sprite2D
var _dash: Sprite2D
var _stick_finger := -1
var _stick_at := Vector2.ZERO


func _ready() -> void:
	layer = 6
	_portrait = _add("res://art/ui/portrait.png", 0.2)
	_bar = _add("res://art/ui/bar_empty.png", 0.25)
	_bar.centered = false
	_fill = Polygon2D.new()
	_fill.color = CRIMSON
	_bar.add_child(_fill)
	for i in range(1, SEGMENTS):   # ink strokes that cut the bar into segments
		var cut := Line2D.new()
		var u := float(i) / SEGMENTS
		cut.points = PackedVector2Array([BAR_INNER[0].lerp(BAR_INNER[1], u), BAR_INNER[3].lerp(BAR_INNER[2], u)])
		cut.width = 10.0
		cut.default_color = Color(0.03, 0.03, 0.04)
		_bar.add_child(cut)
	_ring = _add("res://art/ui/stick_ring.png", 0.62)
	_ring.modulate.a = 0.8
	_knob = _add("res://art/ui/stick_knob.png", 0.62)
	_knob.modulate.a = 0.9
	_slow = _add("res://art/ui/stopwatch.png", 0.215)
	_meter = Line2D.new()
	_meter.width = 5.0
	_meter.default_color = AMBER
	add_child(_meter)
	_fire = _add("res://art/ui/button_ring.png", 0.3)
	var gun := Sprite2D.new()
	gun.texture = load("res://art/revolver.png")
	gun.scale = Vector2.ONE * 0.27
	gun.position = Vector2(0.0, 6.0)
	_fire.add_child(gun)
	_fire.visible = false   # a touch on the street aims and fires; the button is no longer needed
	_dash = _add("res://art/ui/icon_dash.png", 0.5)
	_jump = _add("res://art/ui/icon_jump.png", 0.5)
	set_health(1.0)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_slow(1.0, false)


func _add(path: String, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.scale = Vector2.ONE * size
	add_child(s)
	return s


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	_portrait.position = Vector2(72.0, 62.0)
	_bar.position = Vector2(128.0, 30.0)
	_stick_at = Vector2(180.0, size.y - 175.0)
	_ring.position = _stick_at
	_knob.position = _stick_at
	_fire.position = Vector2(size.x - 105.0, size.y - 215.0)
	_jump.position = Vector2(size.x - 80.0, size.y - 85.0)
	_dash.position = Vector2(size.x - 200.0, size.y - 95.0)
	_slow.position = Vector2(size.x - 340.0, size.y - 95.0)


## Big words across the middle of the screen.
func banner(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 84)
	l.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04))
	l.add_theme_constant_override("outline_size", 18)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)


const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
var _boss_box: Control
var _boss_fill: ColorRect


## The detective's narration, in comic captions: cream boxes with black lettering at the top of the
## screen, one line after another, then gone.
func caption(lines: Array) -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 430.0, 140.0)
	box.custom_minimum_size = Vector2(860.0, 0.0)
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var tw := create_tween()
	for i in lines.size():
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = PAPER
		style.border_color = INK
		style.set_border_width_all(4)
		style.set_content_margin_all(14)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		style.shadow_offset = Vector2(6.0, 6.0)
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = String(lines[i]).to_upper()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(minf(700.0, 60.0 + String(lines[i]).length() * 17.0), 0.0)
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", INK)
		panel.add_child(l)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if i % 2 == 0 else Control.SIZE_SHRINK_END   # boxes step across like panels on a page
		panel.modulate.a = 0.0
		box.add_child(panel)
		tw.tween_property(panel, "modulate:a", 1.0, 0.35)
		tw.tween_interval(1.6 + String(lines[i]).length() * 0.03)
	tw.tween_interval(1.6)
	tw.tween_property(box, "modulate:a", 0.0, 0.7)
	tw.tween_callback(box.queue_free)


## The boss's name and health across the top of the screen; fraction below 0 takes it away.
func boss_bar(boss_name: String, fraction: float) -> void:
	if _boss_box == null:
		_boss_box = Control.new()
		_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_box.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 300.0, 26.0)
		add_child(_boss_box)
		var back := ColorRect.new()
		back.color = INK
		back.size = Vector2(600.0, 30.0)
		back.position = Vector2(0.0, 46.0)
		_boss_box.add_child(back)
		_boss_fill = ColorRect.new()
		_boss_fill.color = CRIMSON
		_boss_fill.position = Vector2(5.0, 51.0)
		_boss_fill.size = Vector2(590.0, 20.0)
		_boss_box.add_child(_boss_fill)
		var l := Label.new()
		l.text = boss_name
		l.size = Vector2(600.0, 44.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", PAPER)
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", 10)
		_boss_box.add_child(l)
	if fraction < 0.0:
		_boss_box.queue_free()
		_boss_box = null
		return
	_boss_fill.size.x = 590.0 * clampf(fraction, 0.0, 1.0)


## The chapter's title card: the chapter number small, its name large, both fading in and out.
func title(small: String, big: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for spec in [[small, 34, 8], [big, 92, 18]]:
		var l := Label.new()
		l.text = spec[0]
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", Color(0.93, 0.9, 0.86))
		l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04))
		l.add_theme_constant_override("outline_size", spec[2])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	box.modulate.a = 0.0
	add_child(box)
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.9)
	tw.tween_callback(box.queue_free)


## fraction: 0 = dead, 1 = unhurt.
func set_health(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	_fill.polygon = PackedVector2Array([BAR_INNER[0], BAR_INNER[0].lerp(BAR_INNER[1], f), BAR_INNER[3].lerp(BAR_INNER[2], f), BAR_INNER[3]])


## fraction: how much slowed time is left. active: time is slowed right now.
func set_slow(fraction: float, active: bool) -> void:
	var pts := PackedVector2Array()
	var steps := int(48.0 * clampf(fraction, 0.0, 1.0))
	for i in range(steps + 1):
		var a := -PI * 0.5 + TAU * float(i) / 48.0
		pts.append(_slow.position + Vector2(cos(a), sin(a)) * 69.0)
	_meter.points = pts
	_slow.modulate = Color(1.25, 1.25, 1.25) if active else Color(1.0, 1.0, 1.0)
	_slow.scale = Vector2.ONE * (0.235 if active else 0.215)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_seen = true
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _fire.visible and t.position.distance_to(_fire.position) < 80.0:
				fire_tapped = true
			elif t.position.distance_to(_slow.position) < 80.0:
				slow_tapped = true
			elif t.position.distance_to(_jump.position) < 60.0:
				jump_tapped = true
			elif t.position.distance_to(_dash.position) < 60.0:
				dive_tapped = true
			elif _in_stick_zone(t.position) and _stick_finger == -1:
				_stick_finger = t.index
				_steer(t.position)
			elif _aim_finger == -1:   # anywhere else on the street: aim there and shoot
				_aim_finger = t.index
				aim_at = t.position
				aim_held = true
				aim_left = 0.7
				fire_tapped = true
		elif t.index == _aim_finger:
			_aim_finger = -1
			aim_held = false
		elif t.index == _stick_finger:
			_stick_finger = -1
			move = 0.0
			duck = false
			_knob.position = _stick_at
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_steer(d.position)
		elif d.index == _aim_finger:
			aim_at = d.position
			aim_left = 0.7


## The thumbstick is the ring in the lower left and a little margin round it; a touch anywhere else
## that is not a button aims there and shoots, behind the detective as well as in front of him.
func _in_stick_zone(at: Vector2) -> bool:
	return at.distance_to(_stick_at) < 165.0


func _process(delta: float) -> void:
	if not aim_held:
		aim_left = maxf(0.0, aim_left - delta / Engine.time_scale)


func _steer(at: Vector2) -> void:
	var off := (at - _stick_at).limit_length(76.0)
	_knob.position = _stick_at + off
	move = 0.0 if absf(off.x) < 22.0 else signf(off.x)
	duck = off.y > 38.0
