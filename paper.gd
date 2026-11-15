extends RefCounted
## The game's paper: buttons, cards and comic lettering boxes made from inked drawings (art/ui/paper/src,
## cut by gen/menu_layers.py). Rules, learned the hard way (Pixel Krypta and this game):
##  - a drawing is never stretched out of shape: it is scaled evenly, and where a box is longer than the
##    drawing, the plain middle of the drawing is repeated (mirrored, so there is no seam) while its
##    ends, torn edges, corners and halftone stay exactly as drawn. Every box gets its own texture,
##    baked at its own size;
##  - text sits inside the drawing's inner line, with about one letter of air all round, and audit()
##    checks every screen: text past its box, text over text, boxes over boxes, anything off screen;
##  - one main action per screen; a locked thing says why it is locked; no "A · B · C" strings.

const INK := Color(0.07, 0.06, 0.06)
const CRIMSON := Color(0.55, 0.09, 0.07)
const PAPER := Color(0.93, 0.89, 0.8)
const BAKE := 2.0   # textures are baked at twice the layout size: sharp on a phone's screen

## Each drawing: its file, the ends that must never stretch (caps, source px: left, top, right, bottom)
## and the area where text may go (inner, source px from each edge). "rot": the drawing turned on its
## side; "fixed": never extended, only scaled evenly and centred in its box.
const KINDS := {
	"panel": {"src": "cap_full", "scale": 0.6, "caps": [290, 290, 245, 330], "inner": [50, 50, 50, 54]},
	"tape": {"src": "tape", "fit": "h", "caps": [330, 0, 330, 0], "inner": [80, 14, 80, 14]},
	"strip": {"src": "strip_full", "rot": true, "fit": "h", "caps": [330, 0, 330, 0], "inner": [80, 14, 80, 14]},
	"tag": {"src": "tag", "fixed": true, "inner": [50, 56, 360, 56]},   # the body, clear of the eyelet
	"folder": {"src": "folder_full", "fixed": true, "inner": [80, 400, 90, 100]},   # the cover under its label
	"clip": {"src": "clip", "fixed": true, "inner": [40, 26, 40, 28]},
	"card": {"src": "index_card", "path": "res://art/ui/card/index_card.png", "fixed": true, "inner": [70, 250, 80, 70]},   # a ruled index card, its pin above the text
	"report": {"src": "report", "fixed": true, "inner": [50, 30, 50, 60]},   # one police report sheet, its paperclip top right
	"minus": {"src": "badge_minus", "fixed": true, "inner": [60, 60, 60, 60]},   # printed badges, the HUD's family
	"plus": {"src": "badge_plus", "fixed": true, "inner": [60, 60, 60, 60]},
}
# "scale": the same stroke and halftone on every box of the kind (bake px per source px);
# "fit": "h" scaled to the box's height, then made longer or shorter in the middle;
# "fixed": scaled evenly to fit and centred, never lengthened.

static var _src := {}
static var _baked := {}
static var _scaled := {}   # "kind/w s" -> the source drawing already scaled for that stroke: a caption
# of new words only needs its plain middle lengthened, not the whole drawing filtered again (on a phone
# that full-size filter was a 100+ ms stall on every kill's combo caption)


## Between maps: every baked sheet and source drawing let go (they would outlive the scene otherwise).
static func forget() -> void:
	for k in _src.keys():   # the caption panel is needed on every map (combo, barks, hints): kept
		if not String(k).begins_with("panel"):
			_src.erase(k)
	for k in _scaled.keys():
		if not String(k).begins_with("panel"):
			_scaled.erase(k)
	_baked.clear()
	_turns.clear()


static func _source(kind: String, wide: bool) -> Image:
	var key := kind + ("/w" if wide else "")
	if _src.has(key):
		return _src[key]
	var k: Dictionary = KINDS[kind]
	var tex: Texture2D = load(k.get("path", "res://art/ui/paper/src/%s.png" % k["src"]))
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if k.get("rot", false):
		img.rotate_90(COUNTERCLOCKWISE)
	if wide:
		img.rotate_90(COUNTERCLOCKWISE)
	_src[key] = img
	return img


## The drawing's insets turned with it (a panel used wide is the tall drawing on its side).
static func _turn(v: Array, wide: bool) -> Array:
	return [v[1], v[2], v[3], v[0]] if wide else v


## The texture for a box of this kind and size (layout px), and where its text may go (layout px).
## How a box of this kind and size is drawn, worked out from numbers only (no pictures touched):
## the stroke scale, the baked size, where the drawing sits and where its text may go.
static func plan(kind: String, size: Vector2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var wide: bool = kind == "panel" and size.x > size.y
	var src := _source(kind, wide)
	var t := Vector2i(int(round(size.x * BAKE)), int(round(size.y * BAKE)))
	var s := minf(float(t.x) / src.get_width(), float(t.y) / src.get_height())
	if k.has("scale"):   # the same stroke on every box, a heavier one only on a big card
		s = clampf(s, float(k["scale"]), 1.0)
		# a small box: the whole drawing smaller, so its corners (halftone and all) fit in whole
		var cp: Array = _turn(k["caps"], wide)
		s = maxf(0.22, minf(s, minf(float(t.x) / (cp[0] + cp[2]), float(t.y) / (cp[1] + cp[3]))))
	elif k.get("fit", "") == "h":
		s = float(t.y) / src.get_height()
	var scaled := Vector2i(maxi(2, int(round(src.get_width() * s))), maxi(2, int(round(src.get_height() * s))))
	var fixed: bool = k.get("fixed", false)
	var px := scaled if fixed else t   # a fitted box is lengthened to exactly the baked size
	var off := (Vector2(t) - Vector2(scaled)) * 0.5 / BAKE if fixed else Vector2.ZERO
	var draw := Vector2(px) / BAKE
	var inner: Array = _turn(k["inner"], wide)
	var r := Rect2(off + Vector2(inner[0], inner[1]) * s / BAKE, draw - Vector2(inner[0] + inner[2], inner[1] + inner[3]) * s / BAKE)
	return {"wide": wide, "t": t, "s": s, "scaled": scaled, "off": off, "size": draw, "inner": r}


static func make(kind: String, size: Vector2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var key := "%s %d %d" % [kind, int(size.x), int(size.y)]
	if _baked.has(key):
		return _baked[key]
	var p := plan(kind, size)
	var wide: bool = p["wide"]
	var s: float = p["s"]
	var t: Vector2i = p["t"]
	var skey := "%s%s %d %d" % [kind, "/w" if wide else "", (p["scaled"] as Vector2i).x, (p["scaled"] as Vector2i).y]
	var img: Image = _scaled.get(skey)
	if img == null:   # the whole drawing filtered down to this stroke once, then reused
		img = _source(kind, wide).duplicate()
		img.resize((p["scaled"] as Vector2i).x, (p["scaled"] as Vector2i).y, Image.INTERPOLATE_LANCZOS)
		if _scaled.size() >= 24:
			_scaled.clear()
		_scaled[skey] = img
	if not k.get("fixed", false):
		var caps: Array = _turn(k["caps"], wide)
		img = _fit(img, t.x, int(caps[0] * s), int(caps[2] * s), true)
		img = _fit(img, t.y, int(caps[1] * s), int(caps[3] * s), false)
	var tex := ImageTexture.create_from_image(img)
	var out := {"tex": tex, "size": p["size"], "off": p["off"], "inner": p["inner"]}
	if _baked.size() >= 40:   # captions come in every size their words need: keep only the latest few
		_baked.clear()
	_baked[key] = out
	return out


## Made to length along one axis: both ends stay exactly as drawn; the plain middle between them is
## drawn longer or shorter along that axis only (a straight frame line stays the same line).
static func _fit(img: Image, target: int, a: int, b: int, horizontal: bool) -> Image:
	var n := img.get_width() if horizontal else img.get_height()
	var m := img.get_height() if horizontal else img.get_width()
	if n == target:
		return img
	if a + b >= target - 2:   # a box smaller than the two ends: keep as much of each end as fits
		var k := float(target - 2) / (a + b)
		a = int(a * k)
		b = int(b * k)
	var out := Image.create_empty(target if horizontal else m, m if horizontal else target, false, Image.FORMAT_RGBA8)
	var piece := func(from: int, length: int) -> Rect2i:
		return Rect2i(from, 0, length, m) if horizontal else Rect2i(0, from, m, length)
	var at := func(p: int) -> Vector2i:
		return Vector2i(p, 0) if horizontal else Vector2i(0, p)
	out.blit_rect(img, piece.call(0, a), at.call(0))
	out.blit_rect(img, piece.call(n - b, b), at.call(target - b))
	var mid := img.get_region(piece.call(a, n - a - b))
	var span := target - a - b
	if horizontal:
		mid.resize(span, m, Image.INTERPOLATE_LANCZOS)
	else:
		mid.resize(m, span, Image.INTERPOLATE_LANCZOS)
	out.blit_rect(mid, piece.call(0, span), at.call(a))
	return out


## A piece of paper on the screen: the drawing at this size, with its shadow. meta "inner" = text area.
static var _turns := {}
static var wear := 0.0   # 0..1: the case file browns and greys as Frank's guilt grows (menu sets it)
## No two neighbouring pieces of paper may be the same print: each new sheet of a kind is the drawing
## turned over another way (left-right, upside down, both) and a shade older or newer.
const FLIPS := {"panel": true, "tape": true, "strip": true}
const AGE := [Color(1.0, 1.0, 1.0), Color(0.96, 0.94, 0.9), Color(0.99, 0.98, 0.95), Color(0.93, 0.92, 0.9)]


static func sheet(kind: String, size: Vector2, shadow := true) -> Control:
	var d := make(kind, size)
	var v: int = _turns.get(kind, 0)
	_turns[kind] = v + 1
	var fh := FLIPS.has(kind) and v % 2 == 1
	var fv := FLIPS.has(kind) and (v / 2) % 2 == 1 and kind != "panel"   # a card keeps its heavy foot at the bottom
	var box := Control.new()   # the box itself: the drawing sits in it
	box.size = size
	box.pivot_offset = size * 0.5
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta("paper", true)
	box.set_meta("inner", d["inner"])
	if shadow:
		var sh := TextureRect.new()
		sh.texture = d["tex"]
		sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sh.stretch_mode = TextureRect.STRETCH_SCALE
		sh.position = d["off"] + Vector2(5.0, 7.0)
		sh.size = d["size"]
		sh.modulate = Color(0, 0, 0, 0.5)
		sh.flip_h = fh
		sh.flip_v = fv
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sh.name = "Shadow"
		box.add_child(sh)
	var r := TextureRect.new()
	r.texture = d["tex"]
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = d["off"]
	r.size = d["size"]
	r.flip_h = fh
	r.flip_v = fv
	r.self_modulate = AGE[(v * 3 + 1) % AGE.size()] * Color.WHITE.lerp(Color(0.84, 0.82, 0.79), wear)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.name = "Drawing"
	box.add_child(r)
	return box


## Paper that is a button: pressed, it darkens and sinks to the surface it lies on.
static func button(kind: String, size: Vector2, on_press: Callable, sound := Callable()) -> Control:
	var box := sheet(kind, size)
	var b := TextureButton.new()   # an invisible hit area over the whole box
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.name = "Hit"
	box.add_child(b)
	box.set_meta("button", true)
	var drawing: TextureRect = box.get_node("Drawing")
	var sh: TextureRect = box.get_node("Shadow")
	var rest := sh.position
	b.button_down.connect(func() -> void:
		box.scale = Vector2(0.97, 0.97)
		drawing.modulate = Color(0.8, 0.78, 0.74)
		sh.position = rest - Vector2(3.0, 4.0))
	b.button_up.connect(func() -> void:
		box.scale = Vector2.ONE
		drawing.modulate = Color.WHITE
		sh.position = rest)
	b.pressed.connect(func() -> void:
		if sound.is_valid():
			sound.call("page")
		on_press.call())
	return box


## One typed line of a sheet as a button (several on one sheet, like entries on a report): an
## invisible hit area over that share of the text area; pressed, the line's ink darkens and sinks.
static func line_button(box: Control, label: Label, part: Rect2, on_press: Callable, sound := Callable()) -> Control:
	var inner: Rect2 = box.get_meta("inner")
	var b := TextureButton.new()
	b.position = inner.position + inner.size * part.position
	b.size = inner.size * part.size
	b.focus_mode = Control.FOCUS_NONE
	b.name = "Line"
	box.add_child(b)
	box.set_meta("button", true)
	var rest := label.position
	var col: Color = label.get_theme_color("font_color")
	b.button_down.connect(func() -> void:
		label.position = rest + Vector2(1.0, 2.0)
		label.add_theme_color_override("font_color", col.darkened(0.45)))
	b.button_up.connect(func() -> void:
		label.position = rest
		label.add_theme_color_override("font_color", col))
	b.pressed.connect(func() -> void:
		if sound.is_valid():
			sound.call("page")
		on_press.call())
	return b


## Text on a piece of paper, inside its inner line with about a letter's width of air, aligned as asked.
## part: a share of the text area as fractions (x, y, w, h), for papers that carry more than one line.
static func write(box: Control, text: String, font: Font, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_CENTER,
		part := Rect2(0, 0, 1, 1), air := -1.0) -> Label:
	var inner: Rect2 = box.get_meta("inner")
	var pad := size * 0.45 if air < 0.0 else air   # a letter's width of air at the sides; the font's own
	var area := Rect2(inner.position + inner.size * part.position, inner.size * part.size)   # line box gives it above and below
	area = area.grow_individual(-pad, -minf(pad, size * 0.12), -pad, -minf(pad, size * 0.12))
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = area.position
	l.size = area.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("inside", true)
	box.add_child(l)
	if box.has_node("Hit"):
		box.move_child(box.get_node("Hit"), box.get_child_count() - 1)
	return l


## A comic caption box that fits its words: about a letter of air round them, left-justified as
## captions are lettered, never wider than max_w. Returns the box (its size is known at once).
static func caption(text: String, font: Font, fs: int, max_w := 460.0) -> Control:
	var air := fs * 0.5
	var ts: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w, fs)
	var need := ts + Vector2(air * 2.0 + 2.0, fs * 0.24 + 4.0)   # what the inner line must hold
	var size := need + Vector2(32.0, 32.0)
	for i in 2:   # measure the panel's inner line at this size and make the box hold the words exactly
		var inner: Rect2 = plan("panel", size)["inner"]   # measured, not baked: only the final box is drawn
		size += need - inner.size
		size = size.ceil()
	var box := sheet("panel", size)
	write(box, text, font, fs, INK, HORIZONTAL_ALIGNMENT_LEFT, Rect2(0, 0, 1, 1), air)
	return box


## A place and a time as a comic letterer sets them: "HELL'S KITCHEN · DEC 18, 1947 · 2:10 AM" becomes
## two lines, the place, then the date and the hour.
static func place_time(s: String) -> String:
	var parts := s.split("·")
	for i in parts.size():
		parts[i] = parts[i].strip_edges()
	if parts.size() < 2:
		return s
	return parts[0] + "\n" + ", ".join(parts.slice(1))


# ---- the check -------------------------------------------------------------------------------------

## Where the letters of a label actually are, on screen.
static func _ink(l: Label) -> Rect2:
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var width := l.size.x if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var ts := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, width, fs)
	ts.y += maxf(0.0, l.get_line_count() - 1) * l.get_theme_constant("line_spacing")
	var x := 0.0
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x = (l.size.x - ts.x) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x = l.size.x - ts.x
	var y := 0.0
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = (l.size.y - ts.y) * 0.5
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = l.size.y - ts.y
	var p := Vector2(x, y)
	var xf := l.get_global_transform()
	var r := Rect2(xf * p, Vector2.ZERO)
	for q in [p + Vector2(ts.x, 0), p + Vector2(0, ts.y), p + ts]:
		r = r.expand(xf * q)
	return r


static func _area(c: Control, rect: Rect2) -> Rect2:
	var xf := c.get_global_transform()
	var r := Rect2(xf * rect.position, Vector2.ZERO)
	for q in [Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		r = r.expand(xf * q)
	return r


## Everything wrong with a screen's text and paper, as lines to print. Empty = fine.
static func audit(root: Node, view: Vector2) -> Array:
	var bad: Array = []
	var labels: Array = []
	var papers: Array = []
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		if c is Label and (c as Label).text.strip_edges() != "" and not c.has_meta("decor"):
			labels.append(c)
		if c.has_meta("paper") and c.get_meta("paper"):
			papers.append(c)
	for l: Label in labels:
		var ink := _ink(l)
		var say := l.text.replace("\n", " ")
		if "·" in l.text:
			bad.append("dot chain in \"%s\"" % say)
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.get_minimum_size().x > l.size.x + 1.0:
			bad.append("\"%s\" is wider than its box" % say)
		if l.get_visible_line_count() < l.get_line_count():
			bad.append("\"%s\" has more lines than fit" % say)
		if l.has_meta("inside"):
			var box := l.get_parent() as Control
			var area := _area(box, box.get_meta("inner"))
			if not area.grow(1.5).encloses(ink):
				bad.append("\"%s\" runs over the inner line of its paper" % say)
		if ink.position.x < 8.0 or ink.position.y < 8.0 or ink.end.x > view.x - 8.0 or ink.end.y > view.y - 8.0:
			bad.append("\"%s\" is at the screen edge" % say)
	for i in labels.size():
		for j in range(i + 1, labels.size()):
			var o := _ink(labels[i]).intersection(_ink(labels[j]))
			if o.size.x > 2.0 and o.size.y > 2.0:
				bad.append("\"%s\" and \"%s\" overlap" % [labels[i].text.replace("\n", " "), labels[j].text.replace("\n", " ")])
	for i in papers.size():
		var r := _area(papers[i], Rect2(Vector2.ZERO, papers[i].size))
		if r.position.x < 6.0 or r.position.y < 6.0 or r.end.x > view.x - 6.0 or r.end.y > view.y - 6.0:
			bad.append("a paper is at the screen edge: %s" % r)
		for j in range(i + 1, papers.size()):
			if papers[i].is_ancestor_of(papers[j]) or papers[j].is_ancestor_of(papers[i]):
				continue
			var o := r.intersection(_area(papers[j], Rect2(Vector2.ZERO, papers[j].size)))
			if o.size.x > 4.0 and o.size.y > 4.0:
				bad.append("papers overlap: %s" % o)
	return bad
