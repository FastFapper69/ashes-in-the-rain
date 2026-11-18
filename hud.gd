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
var switch_tapped := false  # Frank's picture was tapped: the next gun
var reload_tapped := false  # the rounds under the health bar were tapped
var pause_tapped := false
var _pause: Sprite2D
var target_at := Callable()   # func(screen: Vector2) -> bool: is there a mobster under this point (main.gd)
var touch_seen := false    # true once a finger has touched the screen: then the mouse is ignored

var _portrait: Sprite2D
var _plate: Control
const PLATE_RECT := Rect2(10.0, 8.0, 512.0, 112.0)
const PLATE_TINT := Color(0.2, 0.19, 0.18, 0.86)
var _bar: Sprite2D
var _fill: Polygon2D
var _ring: Sprite2D
var _knob: Sprite2D
var _fire: Sprite2D
var _slow: Sprite2D
var _meter: Line2D
var _jump: Sprite2D
var _dash: Sprite2D
var _cuts: Array = []
var _stick_finger := -1
var _stick_at := Vector2.ZERO


func _ready() -> void:
	layer = 6
	# One plate under the whole cluster (UI audit 18. 11.: portrait, health, rounds and gun card floated as
	# separate pieces): the caption paper inked dark, so the cream bar, rounds and cards read on it.
	_plate = load("res://paper.gd").sheet("panel", PLATE_RECT.size)
	_plate.position = PLATE_RECT.position
	_plate.modulate = PLATE_TINT
	add_child(_plate)
	_portrait = _add("res://art/ui/portrait.png", 0.2)
	_soot = ShaderMaterial.new()   # the ash on Frank's face: his conscience, without a number
	_soot.shader = Shader.new()
	_soot.shader.code = SOOT_SHADER
	_portrait.material = _soot
	_bar = _add("res://art/ui/bar_empty.png", 0.25)
	_bar.centered = false
	_fill = Polygon2D.new()
	_fill.color = CRIMSON
	_bar.add_child(_fill)
	set_segments(SEGMENTS)
	_ring = _add("res://art/ui/stick_base.png", 0.8)   # the stick's base: an empty printed badge, its middle see-through
	_ring.modulate.a = 0.55   # see-through enough that cover under the thumb still reads
	_knob = _add("res://art/ui/stick_knob.png", 0.62)
	_knob.modulate.a = 0.75
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
	# the buttons are printed badges of the same family as the stopwatch: ink disc, cream ring
	_dash = _add("res://art/ui/badge_dive.png", 0.37)
	_jump = _add("res://art/ui/badge_jump.png", 0.37)
	_pause = _add("res://art/ui/badge_pause.png", 0.27)
	_dash.modulate.a = 0.82
	_jump.modulate.a = 0.82
	set_health(1.0)
	get_viewport().size_changed.connect(_layout)
	_layout()
	set_slow(1.0, false)


## A card over the game (pause, a diary page, a choice): the thumb controls step out of the way, so the
## card is the only thing on the screen to look at or touch.
## Frank's conscience on his portrait (2026-11-16): the ash settles on it as soot, every man let go
## lets the rain wash a little off, and the pages of testimony he holds are tucked in behind it. The
## player never sees a number, but always sees that it moved.
const SOOT_SHADER := "shader_type canvas_item;\nuniform float soot = 0.0;\n" + \
	"float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\n" + \
	"float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);\n" + \
	"\treturn mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y); }\n" + \
	"void fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.3, 0.59, 0.11));\n" + \
	"\tvec3 grey = mix(c.rgb, vec3(g) * 0.9, clamp(soot * 1.4, 0.0, 1.0));\n" + \
	"\tfloat e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));\n" + \
	"\tfloat k = n(UV * 5.0) * 0.3 + n(UV * 14.0) * 0.15 + n(UV * 37.0) * 0.08 + (0.5 - e) * 1.1;\n" + \
	"\tfloat edge = 1.05 - soot * 0.85;\n\tfloat m = smoothstep(edge, edge + 0.1, k);\n" + \
	"\tc.rgb = mix(grey, grey * 0.22, m * 0.9);\n\tCOLOR = c;\n}\n"
var _soot: ShaderMaterial
var _soot_now := 0.0
var _pages: Array = []
const PAGE_SPOTS := [[Vector2(-30, 40), -14.0], [Vector2(28, 44), 9.0], [Vector2(-8, 47), -4.0],
	[Vector2(34, 36), 17.0], [Vector2(-38, 30), -22.0], [Vector2(10, 49), 3.0]]


## soot 0..1 (the ash), pages 0..6 (how much of what Rosie needs he holds). `wash`: the rain takes
## some soot off in front of the player's eyes instead of it just changing.
func set_conscience(soot: float, pages: int, wash := false) -> void:
	soot = clampf(soot, 0.0, 1.0)
	if wash and soot < _soot_now:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: _soot.set_shader_parameter("soot", v), _soot_now + 0.06, soot, 1.6).set_trans(Tween.TRANS_SINE)
		var sp := _portrait.scale
		tw.parallel().tween_property(_portrait, "scale", sp * 1.12, 0.25)
		tw.parallel().tween_property(_portrait, "scale", sp, 0.5).set_delay(0.25)
	else:
		_soot.set_shader_parameter("soot", soot)
	_soot_now = soot
	pages = clampi(pages, 0, PAGE_SPOTS.size())
	while _pages.size() < pages:
		var spot: Array = PAGE_SPOTS[_pages.size()]
		var pg := Sprite2D.new()
		pg.texture = load("res://art/items/page.png")
		pg.scale = Vector2.ONE * 0.24
		pg.rotation = deg_to_rad(float(spot[1]))
		add_child(pg)
		move_child(pg, _portrait.get_index())   # tucked in behind the portrait
		_pages.append(pg)
	_layout_pages()


## Darker at once: a man shot with his hands up. The portrait jolts and the soot spreads over it.
func soot_up(soot: float) -> void:
	soot = clampf(soot, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _soot.set_shader_parameter("soot", v), _soot_now, soot + 0.08, 0.35)
	tw.tween_method(func(v: float) -> void: _soot.set_shader_parameter("soot", v), soot + 0.08, soot, 0.8)
	var p0 := _portrait.position
	for k in 4:
		tw.parallel().tween_property(_portrait, "position", p0 + Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.05).set_delay(k * 0.05)
	tw.tween_property(_portrait, "position", p0, 0.05)
	_soot_now = soot


## A page of testimony flies from where the man stood (screen pixels) into the stack behind the portrait.
func page_in(from: Vector2, soot: float, pages: int) -> void:
	var pg := Sprite2D.new()
	pg.texture = load("res://art/items/page.png")
	pg.scale = Vector2.ONE * 0.5
	pg.position = from
	add_child(pg)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(pg, "position", _portrait.position + Vector2(0, 40), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(pg, "rotation", TAU * 1.5, 0.9)
	tw.parallel().tween_property(pg, "scale", Vector2.ONE * 0.24, 0.9)
	tw.tween_callback(func() -> void:
		pg.queue_free()
		set_conscience(soot, pages, true))


func _layout_pages() -> void:
	for i in _pages.size():
		_pages[i].position = _portrait.position + (PAGE_SPOTS[i][0] as Vector2)


## Under the score card after a map: who he let go and who he shot with their hands up, by name.
func conscience(let_go: Array, shot: Array) -> void:
	if not is_instance_valid(_tally) or (let_go.is_empty() and shot.is_empty()):
		return
	var Paper = load("res://paper.gd")
	var font: Font = load("res://fonts/ComicNeue-BoldItalic.woff")
	var lines: Array = []
	if not let_go.is_empty():
		lines.append("LET GO: " + _names_line(let_go))
	if not shot.is_empty():
		lines.append("SHOT WITH HIS HANDS UP: " + _names_line(shot))
	var y := _tally.size.y + 10.0
	for l in lines:
		var cap: Control = Paper.caption(l, font, 18, _tally.size.x - 40.0)
		cap.position = Vector2(20.0, y)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tally.add_child(cap)
		y += cap.size.y + 6.0


func _names_line(names: Array) -> String:
	var shown: Array = names.slice(0, 4).map(func(n): return String(n) if String(n) != "" else "A MAN")
	var s := ", ".join(shown)
	if names.size() > 4:
		s += " AND %d MORE" % (names.size() - 4)
	return s


func set_portrait(path: String) -> void:
	_portrait.texture = load(path)


func modal(on: bool) -> void:
	for n in [_ring, _knob, _slow, _meter, _dash, _jump, _pause]:
		if n != null:
			n.visible = not on


func _add(path: String, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.scale = Vector2.ONE * size
	add_child(s)
	return s


var _upright: Control   # shown over the game while the phone is held upright

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	if _upright == null:
		_upright = ColorRect.new()
		(_upright as ColorRect).color = Color(0.0, 0.0, 0.0, 0.9)
		var l := Label.new()
		l.text = "Turn your phone sideways."
		l.add_theme_font_override("font", load("res://fonts/SpecialElite.ttf"))
		l.add_theme_font_size_override("font_size", 52)
		l.add_theme_color_override("font_color", PAPER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		_upright.add_child(l)
		add_child(_upright)
	_upright.size = size
	_upright.visible = size.x < size.y
	_portrait.position = Vector2(72.0, 62.0)
	_layout_pages()
	_bar.position = Vector2(128.0, 30.0)
	_stick_at = Vector2(180.0, size.y - 175.0)
	_pause.position = Vector2(size.x - 64.0, 56.0)
	_ring.position = _stick_at
	_knob.position = _stick_at
	_fire.position = Vector2(size.x - 105.0, size.y - 215.0)
	_jump.position = Vector2(size.x - 80.0, size.y - 85.0)
	_dash.position = Vector2(size.x - 200.0, size.y - 95.0)
	_slow.position = Vector2(size.x - 340.0, size.y - 95.0)


## Big words across the middle of the screen.
func banner(text: String) -> void:
	# a big strip of paper slapped across the middle, the words in the game's headline type
	var Paper = load("res://paper.gd")
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var view := get_viewport().get_visible_rect().size
	var fs := 64
	var w := clampf(head.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 200.0, 420.0, view.x - 96.0)
	var b: Control = Paper.sheet("tape", Vector2(w, 120.0))
	Paper.write(b, text, head, fs, Paper.INK)
	b.position = (view - b.size) * 0.5 + Vector2(0.0, -30.0)
	b.pivot_offset = b.size * 0.5
	b.rotation = deg_to_rad(-1.5)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.scale = Vector2.ONE * 1.25
	b.modulate.a = 0.0
	add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "modulate:a", 1.0, 0.12)


## A level reached mid-fight (2026-11-16): a small paper tag up at the top between the gun card and
## the pause button, never over the street, gone again in under two seconds.
var _level_box: Control   # the LEVEL n banner while it is up (audit 18. 11.: the combo printed over it)
func level_up(n: int) -> void:
	var Paper = load("res://paper.gd")
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var view := get_viewport().get_visible_rect().size
	var text := "LEVEL %d" % n
	var fs := 30
	var w := head.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 200.0
	var b: Control = Paper.sheet("tape", Vector2(w, 66.0))
	Paper.write(b, text, head, fs, Paper.INK)
	b.position = Vector2((view.x - b.size.x) * 0.5, -b.size.y - 10.0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	_level_box = b
	var tw := b.create_tween()
	tw.tween_property(b, "position:y", 22.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(b, "position:y", -b.size.y - 10.0, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(b.queue_free)


const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
var _boss_box: Control
var _boss_fill: ColorRect


## The detective's narration, in comic captions: cream boxes with black lettering low in the middle of
## the screen, one line after another, then gone.
var voice := Callable()   # main.gd: sfx.voice, for the narration captions

func caption(lines: Array) -> void:
	# Low in the middle, between the thumbstick and the buttons, over the dark street foreground: the
	# narration reads like a comic's caption under the panel and never covers the men up the street
	# (UI audit 18. 11.: in the corner under the portrait it sat on the top-left of the action).
	# Each line its own inked caption box, sized to its words (the drawing is never stretched out of shape);
	# the lines stack upwards from the bottom edge, so the last one always sits lowest.
	var Paper = load("res://paper.gd")
	var font: Font = load("res://fonts/ComicNeue-BoldItalic.woff")
	var fs := 26   # (audit 18. 11.: 22 read small on a phone)
	var view := get_viewport().get_visible_rect().size
	var left := _stick_at.x + 120.0   # clear of the thumbstick's ring
	var right := _slow.position.x - 92.0   # clear of the stopwatch and its meter
	var band := right - left
	var max_w := minf(760.0, band)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for old in _captions:   # the new narration takes the place: the last one steps aside, never under it
		if is_instance_valid(old):
			old.create_tween().tween_property(old, "modulate:a", 0.0, 0.15).finished.connect(old.queue_free)
	_captions = []
	add_child(box)
	_captions.append(box)
	# one thing to read at a time: a how-to-play line on screen steps aside for the narration and comes back after it
	if is_instance_valid(_hint_box):
		_hint_queue.push_front(_hint_text)
		var hb := _hint_box
		_hint_box = null
		hb.create_tween().tween_property(hb, "modulate:a", 0.0, 0.2).finished.connect(hb.queue_free)
	var caps: Array = []
	var w := 0.0
	for i in lines.size():
		var text := String(lines[i]).to_upper()
		var cap: Control = Paper.caption(text, font, fs, _even_width(text, font, fs, max_w))
		cap.modulate.a = 0.0
		cap.visible = false
		box.add_child(cap)
		caps.append(cap)
		w = maxf(w, cap.size.x)
	box.size = Vector2(w, 0.0)
	box.position = Vector2(roundf(left + (band - w) * 0.5), roundf(view.y - 26.0))   # the bottom edge: lines stack up from it
	var tw := create_tween()
	for i in lines.size():
		tw.tween_callback(_caption_step.bind(caps, i))
		var said := String(lines[i])
		var vo: float = 0.0
		if voice.is_valid():   # Frank says it: the next line waits for him
			var sfx = voice.get_object()
			if sfx != null and sfx.has_method("voice") and ResourceLoader.exists("res://voice/%s.mp3" % said.md5_text().substr(0, 10)):
				vo = (load("res://voice/%s.mp3" % said.md5_text().substr(0, 10)) as AudioStream).get_length()
				tw.tween_callback(sfx.voice.bind(said))
		tw.tween_interval(maxf(1.55 + said.length() * 0.028, vo + 0.4))
	tw.tween_interval(1.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


## Line i of a narration comes in at the bottom; the lines before it step up. Never more than
## CAPTION_MAX_H of boxes on screen: the oldest fades out, so the stack stays under the street.
const CAPTION_MAX_H := 140.0
func _caption_step(caps: Array, i: int) -> void:
	var w: float = 0.0
	for c in caps:
		if is_instance_valid(c):
			w = maxf(w, (c as Control).size.x)
	var y := 0.0
	for k in range(i, -1, -1):
		if not is_instance_valid(caps[k]):   # (a new narration took the place: its boxes are gone)
			continue
		var c: Control = caps[k]
		var h := c.size.y
		var at := Vector2(roundf((w - c.size.x) * 0.5), -(y + h))
		var keep := k == i or y + h <= CAPTION_MAX_H
		if k == i:
			c.position = at
			c.visible = true
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.35)
		elif keep:
			c.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(c, "position", at, 0.25)
		elif c.visible and not c.has_meta("gone"):
			c.set_meta("gone", true)
			c.create_tween().tween_property(c, "modulate:a", 0.0, 0.2).finished.connect(c.hide)
		y += h + 8.0


## The narrowest width that still keeps the text on as few lines as max_w does: the lines come out even,
## never a long line and one word left alone under it.
func _even_width(text: String, font: Font, fs: int, max_w: float) -> float:
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w, fs).y
	var lo := max_w * 0.4
	var hi := max_w
	for k in 10:
		var mid := (lo + hi) * 0.5
		if font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, mid, fs).y > h + 1.0:
			lo = mid
		else:
			hi = mid
	return ceilf(hi) + 2.0


## How to play: a tutorial line in its own box, up on the right, apart from the narration
## low in the middle (they used to land on top of each other). One at a time; the next waits its turn.
var _hint_box: Control
var _hint_queue: Array = []
var _hint_text := ""
var _captions: Array = []   # narration boxes still on screen
var _title_box: Control
func hint(text: String, queued := false) -> void:
	if is_instance_valid(_hint_box) or (not queued and not _hint_queue.is_empty()):
		_hint_queue.append(text)
		return
	_captions = _captions.filter(func(b) -> bool: return is_instance_valid(b))
	if not _captions.is_empty():   # Frank is talking: the tutorial waits until he's done
		_hint_queue.push_front(text)
		get_tree().create_timer(0.4).timeout.connect(_next_hint)
		return
	if is_instance_valid(_title_box):   # not over the map's title: after it
		_hint_queue.push_front(text)
		get_tree().create_timer(0.5).timeout.connect(_next_hint)
		return
	var view := get_viewport().get_visible_rect().size
	var Paper = load("res://paper.gd")
	var font: Font = load("res://fonts/ComicNeue-BoldItalic.woff")
	var cap: Control = Paper.caption(text.to_upper(), font, 24, 560.0)
	cap.position = Vector2(view.x - 48.0 - cap.size.x, 128.0)   # up on the right, under the pause button
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.modulate.a = 0.0
	add_child(cap)
	_hint_box = cap
	_hint_text = text
	var tw := create_tween()
	tw.tween_property(cap, "modulate:a", 1.0, 0.3)
	tw.tween_interval(maxf(2.6, 1.4 + text.length() * 0.05))
	tw.tween_property(cap, "modulate:a", 0.0, 0.5)
	var ref: WeakRef = weakref(cap)   # narration may take it down before this runs: never hold the freed box
	tw.tween_callback(func() -> void:
		var c = ref.get_ref()
		if c != null:
			c.queue_free()
		if _hint_box == c:   # still the one up (or both gone): the next line may come
			_hint_box = null
			_next_hint())


func _next_hint() -> void:
	if not is_instance_valid(_hint_box) and not _hint_queue.is_empty():
		hint(String(_hint_queue.pop_front()), true)


## The boss's name and health across the top of the screen; fraction below 0 takes it away.
func boss_bar(boss_name: String, fraction: float) -> void:
	if _boss_box == null:
		_boss_box = Control.new()
		_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vw := get_viewport().get_visible_rect().size.x
		var band_l := plate_right() + 24.0   # between the HUD plate and the pause button, never over either
		var band_r := vw - 120.0
		var bw := minf(600.0, band_r - band_l)
		var bx := clampf(vw * 0.5 - bw * 0.5, band_l, band_r - bw)
		_boss_box.position = Vector2(roundf(bx), 26.0)
		_boss_box.set_meta("w", bw)
		add_child(_boss_box)
		var back := ColorRect.new()
		back.color = INK
		back.size = Vector2(bw, 30.0)
		back.position = Vector2(0.0, 46.0)
		_boss_box.add_child(back)
		_boss_fill = ColorRect.new()
		_boss_fill.color = CRIMSON
		_boss_fill.position = Vector2(5.0, 51.0)
		_boss_fill.size = Vector2(bw - 10.0, 20.0)
		_boss_box.add_child(_boss_fill)
		var l := Label.new()
		l.text = boss_name
		l.size = Vector2(bw, 44.0)
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
	_boss_fill.size.x = (float(_boss_box.get_meta("w")) - 10.0) * clampf(fraction, 0.0, 1.0)


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
	_title_box = box
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.9)
	tw.tween_callback(box.queue_free)


var _weapon_label: Label


## The gun slot, GTA style: a card like his picture's with the gun in hand drawn on it, and the
## other gun he carries as a smaller card tucked behind. Tapping either switches guns.
var _gun_card: Sprite2D
var _gun_spare: Sprite2D
const GUN_CARD_AT := Vector2(418.0, 64.0)
var _guns_shown := ["", ""]
func set_guns(hand: String, other: String) -> void:
	if _gun_card == null:
		_gun_spare = _add("res://art/ui/gun_revolver.png", 0.12)
		_gun_spare.rotation = deg_to_rad(6.0)
		_gun_card = _add("res://art/ui/gun_revolver.png", 0.19)
	var swap: bool = _guns_shown[0] == other and _guns_shown[1] == hand and other != "" and hand != other
	_guns_shown = [hand, other]
	var front_at := GUN_CARD_AT
	var back_at := GUN_CARD_AT + Vector2(62.0, -18.0)
	if swap:   # the two cards trade places: the one in hand flicks back and down, the spare jumps forward over it
		var t := 0.28
		var old_front := _gun_card
		var old_back := _gun_spare
		_gun_card = old_back
		_gun_spare = old_front
		move_child(_gun_card, _gun_spare.get_index() + 1)   # the new gun's card comes up on top
		for c in [_gun_card, _gun_spare]:
			var tw0: Tween = c.get_meta("tw") if c.has_meta("tw") else null
			if tw0 != null and tw0.is_valid():
				tw0.kill()
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_gun_card.set_meta("tw", tw)
		tw.tween_property(_gun_card, "position", front_at, t)
		tw.tween_property(_gun_card, "scale", Vector2.ONE * 0.19, t)
		tw.tween_property(_gun_card, "rotation", deg_to_rad(-4.0), t * 0.5)
		tw.chain().tween_property(_gun_card, "rotation", 0.0, t * 0.5)
		var tw2 := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_gun_spare.set_meta("tw", tw2)
		tw2.tween_property(_gun_spare, "position", back_at + Vector2(0.0, 26.0), t * 0.45)   # dipping under on the way
		tw2.tween_property(_gun_spare, "scale", Vector2.ONE * 0.12, t)
		tw2.tween_property(_gun_spare, "rotation", deg_to_rad(6.0), t)
		tw2.chain().tween_property(_gun_spare, "position", back_at, t * 0.55)
		_gun_card.modulate = Color(1.25, 1.25, 1.25)
		create_tween().tween_property(_gun_card, "modulate", Color.WHITE, 0.35)
		return
	_gun_card.texture = load("res://art/ui/gun_%s.png" % hand)
	_gun_spare.visible = other != ""
	_fit_plate(other != "")
	if other != "":
		_gun_spare.texture = load("res://art/ui/gun_%s.png" % other)
	_gun_card.position = front_at
	_gun_card.rotation = 0.0
	_gun_spare.position = back_at
	_gun_spare.rotation = deg_to_rad(6.0)
	_gun_spare.scale = Vector2.ONE * 0.12
	var tw := _gun_card.create_tween()   # a little flip as the gun changes
	_gun_card.scale = Vector2(0.02, 0.19)
	tw.tween_property(_gun_card, "scale", Vector2.ONE * 0.19, 0.16)


## The plate ends just past the last card: the gun card alone, or the spare one tucked behind it.
var _plate_wide := true
func _fit_plate(wide: bool) -> void:
	if wide == _plate_wide:
		return
	_plate_wide = wide
	var size := PLATE_RECT.size if wide else Vector2(PLATE_RECT.size.x - 40.0, PLATE_RECT.size.y)
	var fresh: Control = load("res://paper.gd").sheet("panel", size)
	fresh.position = PLATE_RECT.position
	fresh.modulate = PLATE_TINT
	add_child(fresh)
	move_child(fresh, _plate.get_index())
	_plate.queue_free()
	_plate = fresh


func plate_right() -> float:
	return PLATE_RECT.position.x + (PLATE_RECT.size.x if _plate_wide else PLATE_RECT.size.x - 40.0)


## The gun in hand and its rounds, under the health bar; the revolver never runs dry, so it shows none.
func set_weapon(weapon_name: String, rounds: int) -> void:
	if _weapon_label == null:
		_weapon_label = Label.new()
		_weapon_label.position = Vector2(132.0, 66.0)
		_weapon_label.add_theme_font_size_override("font_size", 26)
		_weapon_label.add_theme_color_override("font_color", PAPER)
		_weapon_label.add_theme_color_override("font_outline_color", INK)
		_weapon_label.add_theme_constant_override("outline_size", 8)
		_weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_weapon_label)
	_weapon_label.text = "" if weapon_name == "revolver" else "%s   %d" % [weapon_name.to_upper(), rounds]


## The rounds in the gun under the health bar: a cartridge per round, bright when loaded, hollow
## when spent. While he reloads they fill up again from the left. A big magazine is shown as a
## count. Tapping them reloads.
var _ammo_box: Control
var _ammo := [0, 6, -1, 0.0]   # in the gun, gun holds, left to load (-1: no limit), reload progress
var _ammo_name := ""
const AMMO_AT := Vector2(132.0, 70.0)

func set_ammo(gun_name: String, rounds: int, holds: int, spare: int, reload_progress: float) -> void:
	if _ammo_box == null:
		_ammo_box = Control.new()
		_ammo_box.position = AMMO_AT
		_ammo_box.size = Vector2(560.0, 40.0)
		_ammo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ammo_box.draw.connect(_draw_ammo)
		add_child(_ammo_box)
	var now := [rounds, holds, spare, snappedf(reload_progress, 0.02)]
	if now == _ammo and gun_name == _ammo_name:
		return
	_ammo = now
	_ammo_name = gun_name
	_ammo_box.queue_redraw()


func _draw_ammo() -> void:
	var rounds: int = _ammo[0]
	var holds: int = _ammo[1]
	var progress: float = _ammo[3]
	if progress > 0.0:   # reloading: the chambers fill one after another
		rounds = int(lerpf(float(rounds), float(holds), progress))
	var font := ThemeDB.fallback_font
	var x := 0.0
	if holds <= 14:
		for i in holds:
			var r := Rect2(Vector2(x, 4.0), Vector2(11.0, 28.0))
			var shell := PackedVector2Array([r.position + Vector2(0, 9), r.position + Vector2(5.5, 0), r.position + Vector2(11, 9), r.end, Vector2(r.position.x, r.end.y)])
			_ammo_box.draw_colored_polygon(shell, INK)
			var inner := PackedVector2Array()
			for p in shell:
				inner.append(p.lerp(r.get_center(), 0.28))
			if i < rounds:
				_ammo_box.draw_colored_polygon(inner, AMBER if i < 1 and rounds <= 2 else PAPER)
			else:   # spent: just the outline of the round, so the gun's size still reads
				var ring := inner.duplicate()
				ring.append(inner[0])
				_ammo_box.draw_polyline(ring, Color(PAPER, 0.45), 1.5)
			x += 16.0
	else:
		_ammo_box.draw_string_outline(font, Vector2(x, 30.0), "%d" % rounds, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, INK)
		_ammo_box.draw_string(font, Vector2(x, 30.0), "%d" % rounds, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, PAPER)
		x += 50.0
	var tail := _ammo_name
	if _ammo[2] >= 0:
		tail += ("  " if tail != "" else "") + "+%d" % _ammo[2]
	if progress > 0.0:
		tail = "RELOADING"
	elif _ammo[0] <= 0:
		tail = "TAP TO RELOAD"
	if tail != "":   # on the plate, clear of the gun card: a long word is set smaller, never under the card
		var room := GUN_CARD_AT.x - 56.0 - AMMO_AT.x - (x + 12.0)
		var tfs := 22
		while tfs > 14 and font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > room:
			tfs -= 1
		_ammo_box.draw_string_outline(font, Vector2(x + 12.0, 28.0), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, 7, INK)
		_ammo_box.draw_string(font, Vector2(x + 12.0, 28.0), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, AMBER if progress > 0.0 or _ammo[0] <= 0 else PAPER)


## A short word low on the screen that fades: CHECKPOINT, a gun picked up.
var _toast: Label
func toast(text: String) -> void:
	var view := get_viewport().get_visible_rect().size
	if is_instance_valid(_toast):   # one at a time: a new one replaces the last, never prints over it
		_toast.queue_free()
	var l := Label.new()
	_toast = l
	l.text = text
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	l.add_theme_font_override("font", head)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", PAPER)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(view.x, 50.0)
	var ty := view.y * 0.68
	_captions = _captions.filter(func(b) -> bool: return is_instance_valid(b))
	for cb in _captions:   # (audit 18. 11.: "+60 TOMMY GUN ROUNDS" over the narration) above the narration's top
		for c in (cb as Control).get_children():
			if (c as Control).visible:
				ty = minf(ty, (cb as Control).position.y + (c as Control).position.y - 60.0)
	l.position = Vector2(0.0, ty)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


## A cut through black: going through a door.
## Hit: the edges of the screen go red and fade; at low health a red rim stays, beating.
var _hurt_rim: TextureRect
var _low := 0.0
func hurt(health: float) -> void:
	if _hurt_rim == null:
		_hurt_rim = TextureRect.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.1, 1.1)
		var gr := Gradient.new()
		gr.set_color(0, Color(0.5, 0.02, 0.02, 0.0))
		gr.add_point(0.55, Color(0.5, 0.02, 0.02, 0.0))
		gr.set_color(gr.get_point_count() - 1, Color(0.55, 0.02, 0.02, 0.9))
		g.gradient = gr
		_hurt_rim.texture = g
		_hurt_rim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_hurt_rim.stretch_mode = TextureRect.STRETCH_SCALE
		_hurt_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hurt_rim)
		move_child(_hurt_rim, 0)
	_hurt_rim.size = get_viewport().get_visible_rect().size
	_low = 0.35 if health <= 0.41 else 0.0
	_hurt_rim.modulate.a = 1.0


func flash(strength := 0.85, length := 0.35) -> void:
	var r := ColorRect.new()
	r.color = Color(0.0, 0.0, 0.0, strength)
	r.size = get_viewport().get_visible_rect().size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	move_child(r, 0)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, length).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)   # (black a moment, then up)
	tw.tween_callback(r.queue_free)


## The map's tally: an index card pinned up beside the action (the closing words stay readable in
## their corner): the score, one to three stars for it, and what it was made of.
## rows: pairs [label, value], set out in two columns.
var _tally: Control
func rating(level_line: String, head: String, score: int, rows: Array) -> void:
	var Paper = load("res://paper.gd")
	var view := get_viewport().get_visible_rect().size
	if is_instance_valid(_tally):
		_tally.queue_free()
	var w := 470.0
	var card: Control = Paper.sheet("card", Vector2(w, roundf(w * 1096.0 / 1496.0)))
	_tally = card
	card.position = Vector2(maxf((view.x - w) * 0.5, 520.0), (view.y - card.size.y) * 0.5 - 20.0)
	card.rotation = deg_to_rad(-1.2)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var oswald := FontVariation.new()
	oswald.base_font = load("res://fonts/Oswald.ttf")
	oswald.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var type: Font = load("res://fonts/SpecialElite.ttf")
	Paper.write(card, head, oswald, 24, Paper.INK, HORIZONTAL_ALIGNMENT_CENTER, Rect2(0, 0.0, 1, 0.17), 8.0)
	# (audit 17. 11.: the XP line wrapped into two cramped lines) the score on its own line, the level under it, one line each
	Paper.write(card, "SCORE %d" % score, oswald, 28, CRIMSON, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0.17, 0.42, 0.22), 10.0)
	Paper.write(card, level_line, type, 14, CRIMSON, HORIZONTAL_ALIGNMENT_RIGHT, Rect2(0.42, 0.17, 0.58, 0.22), 10.0)
	for i in rows.size():   # two columns, typed
		var col := i % 2
		var row := i / 2
		var part := Rect2(col * 0.5, 0.42 + row * 0.19, 0.5, 0.19)
		Paper.write(card, "%s %s" % [rows[i][0], rows[i][1]], type, 18, Paper.INK, HORIZONTAL_ALIGNMENT_LEFT, part, 10.0)
	card.modulate.a = 0.0
	card.create_tween().set_ignore_time_scale(true).tween_property(card, "modulate:a", 1.0, 0.3)


## A kill's style points, up by the pause badge: what made it count and the streak it is part of.
var _combo_box: Control
func combo(streak: int, points: int, how: String) -> void:
	var Paper = load("res://paper.gd")
	var view := get_viewport().get_visible_rect().size
	if is_instance_valid(_combo_box):
		_combo_box.queue_free()
	var text := ("%s  " % how if how != "" else "") + "+%d" % points
	if streak >= 2:
		text = "X%d COMBO  " % streak + text
	var cap: Control = Paper.caption(text, load("res://fonts/ComicNeue-BoldItalic.woff"), 22, 560.0)
	_combo_box = cap
	var under_boss := is_instance_valid(_boss_box) and _boss_box.visible   # the boss's name owns the top
	var y := 112.0 if under_boss else 26.0
	if is_instance_valid(_level_box):   # (the LEVEL banner owns the top a moment: under it)
		y = maxf(y, 100.0)
	# (audit 18. 11.: right beside the pause button) in the middle at the top, between the HUD plate and the pause
	var mid := (plate_right() + view.x - 120.0) * 0.5
	cap.position = Vector2(roundf(mid - cap.size.x * 0.5), y)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)
	cap.pivot_offset = cap.size * Vector2(0.5, 0.5)
	cap.scale = Vector2.ONE * (1.0 + 0.06 * streak)
	var tw := cap.create_tween().set_ignore_time_scale(true)
	tw.tween_property(cap, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(cap, "modulate:a", 0.0, 0.5)
	tw.tween_callback(cap.queue_free)


## fraction: 0 = dead, 1 = unhurt.
## One segment per hit the hero can take: Eddie five, Frank three at first.
func set_segments(n: int) -> void:
	for c in _cuts:
		c.queue_free()
	_cuts.clear()
	for i in range(1, n):   # ink strokes that cut the bar into segments
		var cut := Line2D.new()
		var u := float(i) / n
		cut.points = PackedVector2Array([BAR_INNER[0].lerp(BAR_INNER[1], u), BAR_INNER[3].lerp(BAR_INNER[2], u)])
		cut.width = 10.0
		cut.default_color = Color(0.03, 0.03, 0.04)
		_bar.add_child(cut)
		_cuts.append(cut)


func set_health(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	if f > 0.41:   # patched up: the red rim goes
		_low = 0.0
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
			# a finger on a mobster shoots him, even where it also touches a button: the man wins
			var on_man: bool = target_at.is_valid() and target_at.call(t.position)
			if t.position.distance_to(_pause.position) < 46.0:
				pause_tapped = true
			elif _gun_card != null and (t.position.distance_to(_gun_card.position) < 56.0 or (_gun_spare.visible and t.position.distance_to(_gun_spare.position) < 40.0)):
				switch_tapped = true
			elif on_man and _aim_finger == -1 and not _in_stick_zone(t.position):
				_aim_finger = t.index
				aim_at = t.position
				aim_held = true
				aim_left = 0.7
				fire_tapped = true
			elif Rect2(AMMO_AT - Vector2(20.0, 20.0), Vector2(320.0, 80.0)).has_point(t.position):
				reload_tapped = true
			elif _fire.visible and t.position.distance_to(_fire.position) < 80.0:
				fire_tapped = true
			elif t.position.distance_to(_slow.position) < 66.0:   # only the drawn button, no margin round it
				slow_tapped = true
			elif t.position.distance_to(_jump.position) < 50.0:
				jump_tapped = true
			elif t.position.distance_to(_dash.position) < 50.0:
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


## Forget every finger: after the game was paused (a notebook page, a choice) the lifts of fingers
## that were down never arrived, and a stick still "held" would walk the detective off by himself.
func release_all() -> void:
	_stick_finger = -1
	_aim_finger = -1
	move = 0.0
	duck = false
	aim_held = false
	fire_tapped = false
	jump_tapped = false
	dive_tapped = false
	slow_tapped = false
	_knob.position = _stick_at


## The thumbstick is the ring in the lower left and a little margin round it; a touch anywhere else
## that is not a button aims there and shoots, behind the detective as well as in front of him.
func _in_stick_zone(at: Vector2) -> bool:
	return at.distance_to(_stick_at) < 165.0


func _process(delta: float) -> void:
	if _hurt_rim != null:   # the red fades back to the low-health beat, or to nothing
		var floor_a := _low * (0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008))
		_hurt_rim.modulate.a = maxf(floor_a, _hurt_rim.modulate.a - delta / maxf(Engine.time_scale, 0.05) * 2.2)
	if not aim_held:
		aim_left = maxf(0.0, aim_left - delta / Engine.time_scale)


func _steer(at: Vector2) -> void:
	var off := (at - _stick_at).limit_length(76.0)
	_knob.position = _stick_at + off
	move = 0.0 if absf(off.x) < 22.0 else signf(off.x)
	duck = off.y > 38.0
