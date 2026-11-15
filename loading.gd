extends CanvasLayer
## Between two maps: the picture goes to black and a title card holds the screen while the next map is
## built, like the card between two reels: where we are, when, and a line of Frank's. The new map
## lifts it once it is ready, so there is never a bare grey frame.

const PAPER := Color(0.93, 0.89, 0.8)
const CRIMSON := Color(0.6, 0.1, 0.07)
const Levels = preload("res://levels.gd")
const MenuScript = preload("res://menu.gd")

var chapter := 0
var map := 0
var to_menu := false
var then := Callable()      # called once the card has covered the screen (load the next map)
var lifting := false        # true: made by the new map, already covering, to be faded away

var _root: Control
var _drops: Array = []
var _rain: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var view := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.size = view
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.015, 0.02)
	bg.size = view
	_root.add_child(bg)
	_rain = Control.new()   # a faint rain across the black, so it is a night and not a dead screen
	_rain.size = view
	_rain.draw.connect(_draw_rain)
	_root.add_child(_rain)
	for k in 70:
		_drops.append(Vector3(randf() * 1.2, randf(), randf_range(0.3, 1.0)))
	if not to_menu:
		_card(view)
	if lifting:
		_root.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_property(_root, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)
	else:
		_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 1.0, 0.6)
		tw.tween_interval(1.2 if not to_menu else 0.2)   # long enough to read where we are going
		tw.tween_callback(func() -> void:
			if then.is_valid():
				then.call())


func _card(view: Vector2) -> void:
	var ch: Dictionary = Levels.CAMPAIGN[chapter]
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var type: Font = load("res://fonts/SpecialElite.ttf")
	var x := view.x * 0.12
	var y := view.y * 0.32
	# the dream and the memories between the cases are not cases: they are counted apart
	var cases: Array = ch["maps"].filter(func(mp) -> bool: return not (mp.get("dream", false) or mp.get("memory", false)))
	var lv: Dictionary = ch["maps"][map]
	var kicker := "%s, CASE %d OF %d" % [String(ch["title"]), cases.find(lv) + 1, cases.size()]
	if lv.get("dream", false):
		kicker = "%s, A DREAM" % String(ch["title"])
	elif lv.get("memory", false):
		kicker = "%s, A MEMORY" % String(ch["title"])
	var top := _text(kicker, type, 26, Color(PAPER, 0.7))
	top.position = Vector2(x, y)
	_root.add_child(top)
	var name := _text(String(ch["maps"][map]["name"]), head, 92, PAPER)
	name.position = Vector2(x - 4.0, y + 36.0)
	_root.add_child(name)
	var rule := ColorRect.new()
	rule.color = CRIMSON
	rule.position = Vector2(x, y + 168.0)
	rule.size = Vector2(0.0, 5.0)
	_root.add_child(rule)
	create_tween().tween_property(rule, "size:x", minf(view.x * 0.4, 560.0), 0.9).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for ph in MenuScript.PHASES:   # where and when, and Frank's line for it
		if int(ph[0]) == chapter and int(ph[1]) == map:
			var Paper = load("res://paper.gd")
			var stamp := _text(Paper.place_time(String(ph[3])), type, 24, Color(PAPER, 0.75))
			stamp.position = Vector2(x, y + 190.0)
			_root.add_child(stamp)
			var line := _text(String(ph[2]), type, 26, Color(PAPER, 0.55))
			line.position = Vector2(x, y + 264.0)
			_root.add_child(line)


func _text(t: String, font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _process(delta: float) -> void:
	for k in _drops.size():
		var d: Vector3 = _drops[k]
		d.y += delta * (0.9 + d.z * 1.6)
		d.x -= delta * (0.08 + d.z * 0.12)
		if d.y > 1.1:
			d = Vector3(randf() * 1.2, -0.1 - randf() * 0.2, d.z)
		_drops[k] = d
	_rain.queue_redraw()


func _draw_rain() -> void:
	var view := _rain.size
	for d in _drops:
		var p := Vector2(d.x * view.x, d.y * view.y)
		_rain.draw_line(p, p + Vector2(-0.14, 1.0).normalized() * (18.0 + d.z * 50.0), Color(0.8, 0.82, 0.88, 0.04 + 0.08 * d.z), 1.0 + d.z)
