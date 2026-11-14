extends CanvasLayer
## A page of Eddie Doyle's notebook, found in the street: the game holds its breath while it is read.
## The page lies over the darkened scene in Eddie's own carpenter's-pencil hand, a clean copy typed
## beside it; only its button puts it away.

const GRAPHITE := Color(0.17, 0.17, 0.19)
const PAPER := Color(0.93, 0.89, 0.8)

var text := ""
var found := 1      # pages of this chapter found so far, this one included
var total := 5
var sound := Callable()   # func(name: String, db: float)
var done := Callable()

var _page: Control
var _closing := false
var _button: Button
var _age := 0.0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var view := get_viewport().get_visible_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)   # the same page always carries the same stains
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.6, 0.3)
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	# The page itself, left of centre: Eddie's hand, smudged, stained, partly lost. It can afford to
	# be hard to read, since what it says is typed out clean beside it.
	var tex: Texture2D = load("res://art/ui/diary_page.png")
	var h := minf(view.y * 0.8, view.x * 0.52 * tex.get_height() / tex.get_width())
	var w := h * tex.get_width() / tex.get_height()
	_page = Control.new()
	_page.size = Vector2(w, h)
	_page.pivot_offset = _page.size * 0.5
	_page.position = Vector2(view.x * 0.05, (view.y - h) * 0.5 + 6.0)
	_page.rotation = deg_to_rad(rng.randf_range(-3.0, -1.0))
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	var shadow := TextureRect.new()   # it lies on something: the page's own outline, dark and offset
	shadow.texture = tex
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.size = _page.size
	shadow.position = Vector2(10.0, 14.0)
	shadow.modulate = Color(0, 0, 0, 0.55)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(shadow)
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW   # stains and writing stay on the paper
	_page.add_child(pic)
	# the writing sits on the ruled lines: the paper has a rule every 1/17 of its height, from 0.215
	var fs := int(h * 0.075)
	var ghost := _hand(w, h, fs, Color(GRAPHITE, 0.25))   # graphite smeared by a thumb
	ghost.position += Vector2(fs * 0.12, fs * 0.1)
	var hand := _hand(w, h, fs, GRAPHITE)
	for n in [ghost, hand]:
		n.modulate.a = 0.0
		pic.add_child(n)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(hand, "modulate:a", 1.0, 0.9)
	tw.parallel().tween_property(ghost, "modulate:a", 1.0, 0.9)
	var stains := ["res://art/fx/stain_smear1.png", "res://art/fx/stain_spray1.png", "res://art/fx/stain_spray2.png", "res://art/fx/stain_drip1.png"]
	for k in rng.randi_range(2, 3):
		var st := TextureRect.new()
		st.texture = load(stains[rng.randi() % stains.size()])
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_SCALE
		var sz := h * rng.randf_range(0.3, 0.55)
		st.size = Vector2(sz, sz)
		st.pivot_offset = st.size * 0.5
		# mostly at the edges and corners, where a bloody hand held it; one may run over the words
		var corner := Vector2(rng.randf_range(-0.12, 0.25) if rng.randf() < 0.5 else rng.randf_range(0.6, 0.95), rng.randf_range(0.45, 0.95))
		st.position = corner * _page.size - st.size * 0.5
		st.rotation = rng.randf_range(-PI, PI)
		st.modulate = Color(0.42, 0.06, 0.05, rng.randf_range(0.55, 0.8))   # dried blood, soaked into the paper
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(st)
	var crease := ColorRect.new()   # folded once to fit a coat pocket
	crease.color = Color(0, 0, 0, 0.12)
	crease.size = Vector2(2.0, h)
	crease.position = Vector2(w * rng.randf_range(0.46, 0.54), 0.0)
	crease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(crease)
	# The clean copy: down the right of the screen over a fall of shadow, typed like a case report.
	var side_x := view.x * 0.6
	var fade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.0))
	gr.add_point(0.35, Color(0, 0, 0, 0.75))
	gr.set_color(gr.get_point_count() - 1, Color(0, 0, 0, 0.92))
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	fade.texture = gt
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.position = Vector2(side_x - view.x * 0.12, 0.0)
	fade.size = Vector2(view.x - side_x + view.x * 0.12, view.y)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var title := Label.new()
	title.text = "EDDIE DOYLE'S NOTEBOOK\nPAGE %d OF %d" % [found, total]
	title.add_theme_font_override("font", head)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.85, 0.22, 0.18))
	title.position = Vector2(side_x + 20.0, view.y * 0.14)
	title.size = Vector2(view.x - side_x - 70.0, 60.0)
	add_child(title)
	var copy := Label.new()
	copy.text = text
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_override("font", load("res://fonts/SpecialElite.ttf"))
	copy.add_theme_font_size_override("font_size", 26)
	copy.add_theme_color_override("font_color", PAPER)
	copy.add_theme_constant_override("line_spacing", 6)
	copy.position = Vector2(side_x + 20.0, view.y * 0.14 + 78.0)
	copy.size = Vector2(view.x - side_x - 70.0, view.y * 0.55)
	add_child(copy)
	for n in [fade, title, copy]:
		n.modulate.a = 0.0
		create_tween().tween_property(n, "modulate:a", 1.0, 0.5).set_delay(0.25)
	# Only this puts it away: a stray tap meant for a mobster must not throw the page away.
	_button = Button.new()
	_button.text = "PUT IT AWAY"
	_button.add_theme_font_override("font", head)
	_button.add_theme_font_size_override("font_size", 26)
	for st_name in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAPER if st_name != "pressed" else PAPER.darkened(0.15)
		sb.border_color = GRAPHITE
		sb.set_border_width_all(3)
		sb.set_content_margin_all(12)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_offset = Vector2(4.0, 5.0) if st_name != "pressed" else Vector2(1.0, 1.0)
		_button.add_theme_stylebox_override(st_name, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_button.add_theme_color_override(c, GRAPHITE)
	_button.position = Vector2(side_x + 20.0, view.y * 0.78)
	_button.rotation = deg_to_rad(-1.5)
	_button.pressed.connect(close)
	_button.modulate.a = 0.0
	add_child(_button)
	create_tween().tween_property(_button, "modulate:a", 1.0, 0.4).set_delay(0.6)
	_page.scale = Vector2(0.9, 0.9)
	_page.modulate.a = 0.0
	var t2 := create_tween().set_parallel()
	t2.tween_property(_page, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(_page, "modulate:a", 1.0, 0.25)
	if sound.is_valid():
		sound.call("page", -2.0)


## Eddie's carpenter's-pencil hand on the page's ruled lines.
func _hand(w: float, h: float, fs: int, col: Color) -> Label:
	var hand := Label.new()
	hand.text = text
	hand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hand.add_theme_font_override("font", load("res://fonts/ReenieBeanie.ttf"))
	hand.add_theme_font_size_override("font_size", fs)
	hand.add_theme_color_override("font_color", col)
	hand.add_theme_constant_override("line_spacing", int(h * 0.118) - fs)
	hand.position = Vector2(w * 0.175, h * 0.14)
	hand.size = Vector2(w * 0.76, h * 0.8)
	hand.rotation = deg_to_rad(0.6)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hand


func _process(delta: float) -> void:
	_age += delta


func _input(event: InputEvent) -> void:
	# keys put it away on a computer; on the phone only the button does (the Button handles itself)
	if event is InputEventKey and event.pressed and not event.echo and _age > 0.6 \
			and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_E]:
		get_viewport().set_input_as_handled()
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
