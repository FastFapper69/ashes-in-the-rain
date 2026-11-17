extends CanvasLayer
## WHAT'S NEW: the build the player is on and what changed lately (changelog.gd), on an inked comic panel over the
## title. Tap anywhere or BACK to close.

const INK := Color(0.05, 0.05, 0.06)
const CRIMSON := Color(0.6, 0.1, 0.07)
const Paper = preload("res://paper.gd")
const Log = preload("res://changelog.gd")
const Version = preload("res://version.gen.gd")

var done := Callable()
var sound := Callable()


static func build_text() -> String:
	return "BUILD %d" % Version.BUILD if Version.BUILD > 0 else "DEV BUILD"


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	var head := FontVariation.new()
	head.base_font = load("res://fonts/Oswald.ttf")
	head.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	var type: Font = load("res://fonts/SpecialElite.ttf")
	var view := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = view
	add_child(dim)
	var size := Vector2(minf(820.0, view.x - 96.0), view.y - 64.0)
	var card := Paper.sheet("panel", size)
	card.position = (view - size) * 0.5
	card.rotation = deg_to_rad(-0.5)
	add_child(card)
	var inner: Rect2 = card.get_meta("inner")
	var pad := 26.0
	var left := inner.position.x + pad
	var right := inner.end.x - pad
	var title := Label.new()
	title.text = "WHAT'S NEW"
	title.add_theme_font_override("font", head)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", INK)
	title.position = Vector2(left, inner.position.y + 12.0)
	title.size = Vector2(right - left, 52.0)
	title.set_meta("inside", true)
	card.add_child(title)
	var ver := Label.new()   # the build on the right of the title line
	ver.text = build_text() if Version.DATE == "DEV" else "%s\n%s" % [build_text(), Version.DATE]
	ver.add_theme_font_override("font", type)
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", CRIMSON)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.position = Vector2(left, inner.position.y + 14.0)
	ver.size = Vector2(right - left, 48.0)
	ver.set_meta("inside", true)
	card.add_child(ver)
	# the entries, newest first, as many lines as the panel holds above the back button
	var top := inner.position.y + 12.0 + 52.0 + 10.0
	var bottom := inner.end.y - 20.0 - 52.0 - 10.0
	var fs := 18
	var line_h := fs * 1.45
	var lines: Array = []
	for e in Log.ENTRIES:
		lines.append(["day", String(e[0])])
		for t in e[1]:
			lines.append(["item", "- " + String(t)])
	var y := top
	for ln in lines:
		var h := line_h * (1.5 if ln[0] == "day" else 1.0)   # (a date gets air under it)
		if y + h > bottom:
			break
		var l := Label.new()
		l.text = String(ln[1])
		l.add_theme_font_override("font", head if ln[0] == "day" else type)
		l.add_theme_font_size_override("font_size", fs + (2 if ln[0] == "day" else 0))
		l.add_theme_color_override("font_color", CRIMSON if ln[0] == "day" else INK)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.position = Vector2(left, y)
		l.size = Vector2(right - left, line_h)
		l.set_meta("inside", true)
		card.add_child(l)
		y += h
	var back: Control = Paper.button("tape", Vector2(170.0, 52.0), _close, sound)
	back.position = Vector2(left - 6.0, inner.end.y - 20.0 - 52.0)
	card.add_child(back)
	Paper.write(back, "BACK", head, 26, INK)


func _close() -> void:
	if done.is_valid():
		done.call()
	queue_free()
