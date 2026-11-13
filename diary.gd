extends CanvasLayer
## A page of Eddie Doyle's notebook, found in the street: the game holds its breath while it is read.
## The page lies over the darkened scene in Eddie's own carpenter's-pencil hand; a tap puts it away.

const GRAPHITE := Color(0.17, 0.17, 0.19)
const PAPER := Color(0.93, 0.89, 0.8)

var text := ""
var found := 1      # pages of this chapter found so far, this one included
var total := 5
var sound := Callable()   # func(name: String, db: float)
var done := Callable()

var _page: Control
var _closing := false
var _age := 0.0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var view := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.72, 0.3)
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var tex: Texture2D = load("res://art/ui/diary_page.png")
	var h := minf(view.y * 0.72, view.x * 0.62 * tex.get_height() / tex.get_width())
	var w := h * tex.get_width() / tex.get_height()
	_page = Control.new()
	_page.size = Vector2(w, h)
	_page.pivot_offset = _page.size * 0.5
	_page.position = (view - _page.size) * 0.5 + Vector2(0.0, 14.0)
	_page.rotation = deg_to_rad(-1.6)
	add_child(_page)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.add_child(pic)
	# the writing sits on the ruled lines: the paper has a rule every 1/17 of its height, from 0.215
	var hand := Label.new()
	hand.text = text
	hand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hand.add_theme_font_override("font", load("res://fonts/ReenieBeanie.ttf"))
	var fs := int(h * 0.075)
	hand.add_theme_font_size_override("font_size", fs)
	hand.add_theme_color_override("font_color", GRAPHITE)
	hand.add_theme_constant_override("line_spacing", int(h * 0.118) - fs)
	hand.position = Vector2(w * 0.175, h * 0.14)
	hand.size = Vector2(w * 0.76, h * 0.8)
	hand.rotation = deg_to_rad(0.6)
	hand.modulate.a = 0.0
	_page.add_child(hand)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(hand, "modulate:a", 1.0, 0.9)
	var title := Label.new()
	title.text = "FROM THE NOTEBOOK OF EDDIE DOYLE   ·   PAGE %d OF %d" % [found, total]
	title.add_theme_font_override("font", head)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0.0, maxf(8.0, _page.position.y - 46.0))
	title.size = Vector2(view.x, 36.0)
	add_child(title)
	var tap := Label.new()
	tap.text = "TAP TO PUT IT AWAY"
	tap.add_theme_font_override("font", head)
	tap.add_theme_font_size_override("font_size", 20)
	tap.add_theme_color_override("font_color", Color(PAPER, 0.6))
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.position = Vector2(0.0, minf(view.y - 34.0, _page.position.y + h + 14.0))
	tap.size = Vector2(view.x, 30.0)
	add_child(tap)
	_page.scale = Vector2(0.9, 0.9)
	_page.modulate.a = 0.0
	var t2 := create_tween().set_parallel()
	t2.tween_property(_page, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(_page, "modulate:a", 1.0, 0.25)
	if sound.is_valid():
		sound.call("page", -2.0)


func _process(delta: float) -> void:
	_age += delta


func _input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo)
	if not tap:
		return
	get_viewport().set_input_as_handled()
	if _age > 0.6:
		close()


func close() -> void:
	if _closing:
		return
	_closing = true
	if sound.is_valid():
		sound.call("page", -6.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(_page, "position:y", _page.position.y + 80.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "offset:y", 0.0, 0.3)
	for c in get_children():
		if c is CanvasItem:
			tw.tween_property(c, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void:
		get_tree().paused = false
		if done.is_valid():
			done.call()
		queue_free())
