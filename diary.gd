extends CanvasLayer
## A page of Eddie Doyle's notebook, found in the street: the game holds its breath while it is read.
## The page lies over the darkened scene in Eddie's own carpenter's-pencil hand, a clean copy typed
## beside it; only its button puts it away.

const GRAPHITE := Color(0.17, 0.17, 0.19)
const PAPER := Color(0.93, 0.89, 0.8)

var text := ""
var paper := ""   # this page's own sheet (gen/notes.py): torn, folded and yellowed its own way
var found := 1      # pages of this chapter found so far, this one included
var total := 5
var sound := Callable()   # func(name: String, db: float)
var done := Callable()

var _page: Control
var _closing := false
var _button: Control
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
	var tex: Texture2D = load(paper if paper != "" and ResourceLoader.exists(paper) else "res://art/ui/diary_page_clean.png")
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
	ghost.set_meta("decor", true)
	var hand := _hand(w, h, fs, GRAPHITE)
	for n in [ghost, hand]:
		n.modulate.a = 0.0
		pic.add_child(n)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(hand, "modulate:a", 1.0, 0.9)
	tw.parallel().tween_property(ghost, "modulate:a", 1.0, 0.9)
	# blood in ink wash, stippled and dry-brushed (gen/cut_card.py): soaked into the paper, never a flat blob
	var stains := ["res://art/fx/blood/blood_0.png", "res://art/fx/blood/blood_1.png", "res://art/fx/blood/blood_3.png", "res://art/fx/blood/blood_5.png", "res://art/fx/blood/blood_4.png"]
	for k in rng.randi_range(2, 3):
		var st := TextureRect.new()
		st.texture = load(stains[rng.randi() % stains.size()])
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_SCALE
		var sz := h * rng.randf_range(0.28, 0.48)
		var ts: Vector2 = st.texture.get_size()
		st.size = Vector2(sz, sz * ts.y / ts.x) if ts.x > ts.y else Vector2(sz * ts.x / ts.y, sz)
		st.pivot_offset = st.size * 0.5
		# mostly at the edges and corners, where a bloody hand held it; one may run over the words
		var corner := Vector2(rng.randf_range(-0.12, 0.25) if rng.randf() < 0.5 else rng.randf_range(0.6, 0.95), rng.randf_range(0.45, 0.95))
		st.position = corner * _page.size - st.size * 0.5
		st.rotation = rng.randf_range(-PI, PI)
		st.modulate = Color(0.85, 0.8, 0.8, rng.randf_range(0.7, 0.9))   # dried a little darker, soaked into the paper
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(st)
	var crease := ColorRect.new()   # folded once to fit a coat pocket
	crease.color = Color(0, 0, 0, 0.12)
	crease.size = Vector2(2.0, h)
	crease.position = Vector2(w * rng.randf_range(0.46, 0.54), 0.0)
	crease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(crease)
	# The clean copy: typed out on an index card pinned beside the page, the way a detective files it.
	var side_x := view.x * 0.6
	var fade := TextureRect.new()   # a fall of shadow behind the card, so the street stays back
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.0))
	gr.add_point(0.35, Color(0, 0, 0, 0.6))
	gr.set_color(gr.get_point_count() - 1, Color(0, 0, 0, 0.8))
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
	var Paper = load("res://paper.gd")
	var type: Font = load("res://fonts/SpecialElite.ttf")
	var card_tex: Texture2D = load("res://art/ui/card/index_card.png")
	var cw := clampf(view.x - side_x - 40.0, 420.0, 600.0)
	var chh := cw * card_tex.get_height() / card_tex.get_width()
	var card := Control.new()
	card.size = Vector2(cw, chh)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csh := TextureRect.new()
	csh.texture = card_tex
	csh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	csh.stretch_mode = TextureRect.STRETCH_SCALE
	csh.size = card.size
	csh.position = Vector2(6.0, 9.0)
	csh.modulate = Color(0, 0, 0, 0.5)
	csh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(csh)
	var cpic := TextureRect.new()
	cpic.texture = card_tex
	cpic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cpic.stretch_mode = TextureRect.STRETCH_SCALE
	cpic.size = card.size
	cpic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cpic)
	add_child(card)
	# the card's printing, measured on the drawing (px of 1496 x 1096, at x = 80): the red rule at
	# 298, then a ruled line every 57 from 355 to about 1010; the lines climb 1.68 degrees to the right, so the
	# typing is turned with them. The pin's point stands in the header band between x 680 and 820.
	var k := cw / 1496.0
	var tilt := deg_to_rad(-1.68)
	var ink := Color(0.1, 0.09, 0.09)
	var red := Color(0.55, 0.09, 0.07)
	var hfs := 20
	while hfs > 12 and type.get_string_size("EDDIE DOYLE'S NOTEBOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x > 580.0 * k:
		hfs -= 1
	var title := Label.new()
	title.text = "EDDIE DOYLE'S NOTEBOOK"
	var page_no := Label.new()
	page_no.text = "PAGE %d OF %d" % [found, total]
	for l in [title, page_no]:
		l.add_theme_font_override("font", type)
		l.add_theme_font_size_override("font_size", hfs)
		l.add_theme_color_override("font_color", red)
		l.position = Vector2(80.0 * k, 298.0 * k - type.get_ascent(hfs) - 22.0 * k)
		l.size = Vector2(1150.0 * k, type.get_height(hfs))   # clear of the dog-eared, hatched corner
		l.rotation = tilt
		l.set_meta("inside", true)
		card.add_child(l)
	page_no.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# the copy on every other ruled line; a long page gets a smaller type until it fits the card
	var text_w := 1300.0 * k
	var lines_room := 6
	var tfs := 24
	while tfs > 15:
		var lines := int(round(type.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, text_w, tfs).y / type.get_height(tfs)))
		if lines <= lines_room:
			break
		tfs -= 1
	var step := 114.0 * k
	var copy := Label.new()
	copy.text = text
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_theme_font_override("font", type)
	copy.add_theme_font_size_override("font_size", tfs)
	copy.add_theme_color_override("font_color", ink)
	copy.add_theme_constant_override("line_spacing", int(round(step - type.get_height(tfs))))
	# each baseline a hair above its ruled line, like typewriter ink
	copy.position = Vector2(80.0 * k, 412.0 * k - type.get_ascent(tfs) - 3.0)   # from the second ruled line: clear of the red rule
	copy.size = Vector2(text_w, 6.0 * step)
	copy.rotation = tilt
	copy.set_meta("inside", true)
	card.add_child(copy)
	# Only this puts it away: a stray tap meant for a mobster must not throw the page away.
	_button = Paper.button("tape", Vector2(240.0, 60.0), close, func(_n: String) -> void: pass)
	Paper.write(_button, "PUT IT AWAY", head, 24, Paper.INK)
	add_child(_button)
	var total_h := chh + 26.0 + 60.0
	var y := (view.y - total_h) * 0.5
	card.position = Vector2(view.x - 40.0 - cw, y)
	card.rotation = deg_to_rad(0.6)
	_button.position = Vector2(card.position.x + cw * 0.5 - 120.0, y + chh + 26.0)
	_button.rotation = deg_to_rad(-1.2)
	var copy_parts := [fade, card]
	for n in copy_parts:
		n.modulate.a = 0.0
		create_tween().tween_property(n, "modulate:a", 1.0, 0.5).set_delay(0.25)
	_button.modulate.a = 0.0
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
