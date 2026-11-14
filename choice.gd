extends CanvasLayer
## A choice that is the player's to make: the game stops, a line of what is at stake, two answers.

const PAPER := Color(0.93, 0.89, 0.8)
const INK := Color(0.05, 0.05, 0.06)
const BLOOD := Color(0.54, 0.11, 0.08)

var question := ""
var options: Array = []
var done := Callable()   # func(index: int)

var _age := 0.0


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var view := get_viewport().get_visible_rect().size
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.6, 0.5)
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = INK
	st.set_border_width_all(4)
	st.set_content_margin_all(26)
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_offset = Vector2(8, 8)
	box.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = question.to_upper()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(view.x * 0.62, 900.0), 0.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load("res://fonts/SpecialElite.ttf"))
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", INK)
	box.add_child(l)
	add_child(box)
	box.reset_size()
	box.position = Vector2((view.x - box.size.x) * 0.5, view.y * 0.2)
	var w := 330.0
	for i in options.size():
		var b := Button.new()
		b.text = String(options[i])
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", head)
		b.add_theme_font_size_override("font_size", 38)
		var bs := StyleBoxFlat.new()
		bs.bg_color = INK if i == 0 else BLOOD
		bs.border_color = PAPER
		bs.set_border_width_all(3)
		bs.set_content_margin_all(14)
		b.add_theme_stylebox_override("normal", bs)
		b.add_theme_stylebox_override("hover", bs)
		b.add_theme_stylebox_override("pressed", bs)
		b.add_theme_color_override("font_color", PAPER)
		b.add_theme_color_override("font_hover_color", PAPER)
		b.add_theme_color_override("font_pressed_color", PAPER)
		b.size = Vector2(w, 86.0)
		b.position = Vector2(view.x * 0.5 + (i - options.size() * 0.5) * (w + 40.0) + 20.0, view.y * 0.62)
		b.pressed.connect(_pick.bind(i))
		add_child(b)


func _process(delta: float) -> void:
	_age += delta


func _pick(i: int) -> void:
	if _age < 0.8:   # no answering by accident with the last tap of the fight
		return
	get_tree().paused = false
	if done.is_valid():
		done.call(i)
	queue_free()
