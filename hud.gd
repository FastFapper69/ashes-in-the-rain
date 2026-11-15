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
var reload_tapped := false  # the rounds under the health bar were tapped
var pause_tapped := false
var _pause: Sprite2D
var target_at := Callable()   # func(screen: Vector2) -> bool: is there a mobster under this point (main.gd)
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
var _cuts: Array = []
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


const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
var _boss_box: Control
var _boss_fill: ColorRect


## The detective's narration, in comic captions: cream boxes with black lettering at the top of the
## screen, one line after another, then gone.
var voice := Callable()   # main.gd: sfx.voice, for the narration captions

func caption(lines: Array) -> void:
	# Up in the corner under his portrait, small: the narration sits beside the action, never on it.
	# Each line its own inked caption box, sized to its words (the drawing is never stretched out of shape).
	var Paper = load("res://paper.gd")
	var font: Font = load("res://fonts/ComicNeue-BoldItalic.woff")
	var fs := 22
	var box := Control.new()
	box.position = Vector2(28.0, 128.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_captions.append(box)
	# one thing to read at a time: a how-to-play line on screen steps aside for the narration and comes back after it
	if is_instance_valid(_hint_box):
		_hint_queue.push_front(_hint_text)
		var hb := _hint_box
		_hint_box = null
		hb.create_tween().tween_property(hb, "modulate:a", 0.0, 0.2).finished.connect(hb.queue_free)
	var tw := create_tween()
	var y := 0.0
	for i in lines.size():
		var text := String(lines[i]).to_upper()
		var cap: Control = Paper.caption(text, font, fs, 460.0)
		cap.position = Vector2(0.0, y)
		cap.modulate.a = 0.0
		box.add_child(cap)
		var h: float = cap.size.y
		y += h + 8.0
		tw.tween_property(cap, "modulate:a", 1.0, 0.35)
		var said := String(lines[i])
		var vo: float = 0.0
		if voice.is_valid():   # Frank says it: the next line waits for him
			var sfx = voice.get_object()
			if sfx != null and sfx.has_method("voice") and ResourceLoader.exists("res://voice/%s.mp3" % said.md5_text().substr(0, 10)):
				vo = (load("res://voice/%s.mp3" % said.md5_text().substr(0, 10)) as AudioStream).get_length()
				tw.tween_callback(sfx.voice.bind(said))
		tw.tween_interval(maxf(1.2 + text.length() * 0.028, vo + 0.4))
	tw.tween_interval(1.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.6)
	tw.tween_callback(box.queue_free)


## How to play: a tutorial line in its own box, low in the middle of the screen, apart from the narration
## up in the corner (they used to land on top of each other). One at a time; the next waits its turn.
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
	tw.tween_callback(func() -> void:
		if is_instance_valid(cap):   # narration may have taken it down already
			cap.queue_free()
		if _hint_box == cap:
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
	_title_box = box
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.2)
	tw.tween_property(box, "modulate:a", 0.0, 0.9)
	tw.tween_callback(box.queue_free)


var _weapon_label: Label


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
	if tail != "":
		_ammo_box.draw_string_outline(font, Vector2(x + 12.0, 28.0), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 7, INK)
		_ammo_box.draw_string(font, Vector2(x + 12.0, 28.0), tail, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, AMBER if progress > 0.0 or _ammo[0] <= 0 else PAPER)


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
	l.position = Vector2(0.0, view.y * 0.68)
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


func flash() -> void:
	var r := ColorRect.new()
	r.color = Color(0.0, 0.0, 0.0, 0.85)
	r.size = get_viewport().get_visible_rect().size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	move_child(r, 0)
	var tw := create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)


## The map's tally: an index card pinned up beside the action (the closing words stay readable in
## their corner): the score, one to three stars for it, and what it was made of.
## rows: pairs [label, value], set out in two columns.
var _tally: Control
func rating(stars: int, head: String, score: int, rows: Array) -> void:
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
	Paper.write(card, "SCORE %d" % score, oswald, 28, CRIMSON, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0.17, 0.62, 0.22), 10.0)
	var inner: Rect2 = card.get_meta("inner")
	var st := Control.new()   # the stars, inked beside the score
	st.position = inner.position + inner.size * Vector2(0.62, 0.17)
	st.size = inner.size * Vector2(0.38, 0.22)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.draw.connect(func() -> void:
		var r := minf(st.size.y * 0.4, 15.0)
		for i in 3:
			var at := Vector2(st.size.x * 0.5 + (i - 1) * r * 2.6, st.size.y * 0.5)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(at + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.42))
			if i < stars:
				st.draw_colored_polygon(pts, CRIMSON)
			else:
				pts.append(pts[0])
				st.draw_polyline(pts, Color(CRIMSON, 0.7), 2.0, true))
	card.add_child(st)
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
	var y := 116.0 if under_boss else 22.0
	if under_boss and is_instance_valid(_hint_box):   # a how-to line up there too: below it
		y = _hint_box.position.y + _hint_box.size.y + 10.0
	cap.position = Vector2(view.x - 124.0 - cap.size.x, y)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cap)
	cap.pivot_offset = cap.size * Vector2(1.0, 0.5)
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
