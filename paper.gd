extends RefCounted
## The game's paper: buttons, cards and comic lettering boxes cut from inked drawings (gen/menu_layers.py),
## so nothing on screen is a flat digital rectangle. One look for the menu, the settings, the pause
## card and the narration.

const INK := Color(0.07, 0.06, 0.06)
const CRIMSON := Color(0.55, 0.09, 0.07)


## A drawing stretched as a box: its torn or inked edges keep their size, only the middle stretches.
static func box(kind: String, margin := 0.12, tint := Color.WHITE, fit := Vector2(9999, 9999)) -> StyleBoxTexture:
	var tex: Texture2D = load("res://art/ui/paper/%s.png" % kind)
	var s := StyleBoxTexture.new()
	s.texture = tex
	var mx := minf(tex.get_width() * margin, fit.x * 0.3)   # never more edge than the thing is wide
	var my := minf(minf(tex.get_height() * 0.3, mx), fit.y * 0.3)
	s.content_margin_top = 2.0
	s.content_margin_bottom = 2.0
	s.texture_margin_left = mx
	s.texture_margin_right = mx
	s.texture_margin_top = my
	s.texture_margin_bottom = my
	s.modulate_color = tint
	return s


## A button that is a piece of paper: a strip of tape, a tag, a clipping. Pressed, it darkens and
## sinks a little, like a thumb on it.
static func button(kind: String, text: String, font: Font, font_size: int, size: Vector2, color := INK) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, color)
	b.add_theme_color_override("font_pressed_color", CRIMSON)
	for state in ["normal", "hover", "focus", "pressed"]:
		var st := box(kind, 0.12, Color(0.8, 0.77, 0.72) if state == "pressed" else Color.WHITE, size)
		st.content_margin_left = minf(size.y * 0.42, size.x * 0.2)
		st.content_margin_right = minf(size.y * 0.42, size.x * 0.2)
		b.add_theme_stylebox_override(state, st)
	b.size = size
	b.pivot_offset = size * 0.5
	b.button_down.connect(func() -> void: b.scale = Vector2(0.97, 0.97))
	b.button_up.connect(func() -> void: b.scale = Vector2.ONE)
	var shadow := NinePatchRect.new()   # it lies on something
	var tex: Texture2D = load("res://art/ui/paper/%s.png" % kind)
	shadow.texture = tex
	var mx := int(minf(tex.get_width() * 0.12, size.x * 0.3))
	var my := int(minf(minf(tex.get_height() * 0.3, mx), size.y * 0.3))
	shadow.patch_margin_left = mx
	shadow.patch_margin_right = mx
	shadow.patch_margin_top = my
	shadow.patch_margin_bottom = my
	shadow.size = size
	shadow.position = Vector2(5.0, 7.0)
	shadow.modulate = Color(0, 0, 0, 0.5)
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shadow)
	return b


## A card of paper to put things on (the settings, the pause card), or a narration box.
static func card(kind: String, size: Vector2, margin := 0.1) -> NinePatchRect:
	var n := NinePatchRect.new()
	var tex: Texture2D = load("res://art/ui/paper/%s.png" % kind)
	n.texture = tex
	var m := int(tex.get_width() * margin)
	n.patch_margin_left = m
	n.patch_margin_right = m
	n.patch_margin_top = m
	n.patch_margin_bottom = m
	n.size = size
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n
