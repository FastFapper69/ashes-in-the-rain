extends RefCounted
## Drawings that are painted far bigger than they are ever seen (a man's torso is 1300 px tall in its
## file and some 300 on a phone's screen) are kept on the graphics card at a fraction of their
## resolution, while reporting their full size: every offset, region and polygon in the game stays as
## it is. On a phone this is the difference between a page that holds and one the browser kills.

static var _cache := {}   # "path@factor" -> ImageTexture, kept for the whole session: reading a drawing
# back from the graphics card is slow on a phone, and figures and effects are needed on every map
static var failed := 0
static var _log := "--lowres-log" in OS.get_cmdline_user_args()


static func tex(path: String, factor := 0.5) -> Texture2D:
	var key := "%s@%s" % [path, factor]
	if _cache.has(key):
		return _cache[key]
	if _log:
		print("LOWRES ", path, " ", factor)
	# imported at its reduced size already (gen/basis_imports.py, gen/lowres_paths.txt): just told its
	# painted size, nothing decoded or shrunk here
	if preload("res://big_sizes.gd").SIZES.has(path):
		var b := BigTex.get_tex(path)
		_cache[key] = b
		return b
	var src: Texture2D = load(path)
	if src == null or factor >= 1.0:
		return src
	var img: Image = src.get_image()
	if img == null or img.is_empty():   # this renderer can't read it back: the full drawing, then
		failed += 1
		return src
	if img.is_compressed():
		img.decompress()
	var full := Vector2i(src.get_size())
	img.resize(maxi(1, roundi(full.x * factor)), maxi(1, roundi(full.y * factor)), Image.INTERPOLATE_CUBIC)
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(full)
	_cache[key] = t
	return t
