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
	var Paper = load("res://paper.gd")
	var box: Control = Paper.caption(question.to_upper(), load("res://fonts/ComicNeue-BoldItalic.woff"), 30, minf(view.x * 0.6, 860.0))
	box.position = Vector2((view.x - box.size.x) * 0.5, view.y * 0.2)
	add_child(box)
	var w := 320.0
	var gap := 48.0
	var x0 := (view.x - (w * options.size() + gap * (options.size() - 1))) * 0.5
	for i in options.size():
		var b: Control = Paper.button("tape", Vector2(w, 72.0), _pick.bind(i))
		b.position = Vector2(x0 + i * (w + gap), view.y * 0.62)
		b.rotation = deg_to_rad(-1.0 if i == 0 else 1.0)
		add_child(b)
		Paper.write(b, String(options[i]), head, 32, Paper.INK if i == 0 else Paper.CRIMSON)


func _process(delta: float) -> void:
	_age += delta


func _pick(i: int) -> void:
	if _age < 0.8:   # no answering by accident with the last tap of the fight
		return
	get_tree().paused = false
	if done.is_valid():
		done.call(i)
	queue_free()
