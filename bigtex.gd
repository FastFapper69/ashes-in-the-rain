class_name BigTex
extends Texture2D
## A street or room drawing kept on the graphics card at reduced size (its import is capped at 2048 px
## wide: a 3000 px drawing is never seen above ~1700 px, and on a phone each one cost 16 MB) while it
## reports its painted size, so every pixel position measured on the drawing (lamps, signs, cut-outs,
## trims) stays as it is. The small texture is told its full size on the rendering server, so source
## rectangles and UVs given in painted pixels land where they should.

const LIMIT := 2048.0
var path := ""
var inner: Texture2D
var full := Vector2i.ZERO
static var _cache := {}   # path -> WeakRef: one wrapper per drawing while anything shows it


static func get_tex(p: String) -> Texture2D:
	if _cache.has(p):
		var held = (_cache[p] as WeakRef).get_ref()
		if held != null:
			return held
	var t: Texture2D = load(p)
	if t == null:
		return t
	var b := BigTex.new()
	b.path = p
	b.inner = t
	b.full = BigTex.painted_size(p, t)
	if b.full == Vector2i(t.get_width(), t.get_height()):   # imported at its painted size: nothing to wrap
		return t
	RenderingServer.texture_set_size_override(t.get_rid(), b.full.x, b.full.y)
	_cache[p] = weakref(b)
	return b


## The drawing's painted size (gen/basis_imports.py): drawings capped at 2048 px, and the light/blood
## layers and comic panels imported a few pixels smaller so their size is a multiple of 4 (a GPU-compressed
## texture must be, or WebGL refuses it).
static func painted_size(p: String, t: Texture2D) -> Vector2i:
	var sizes: Dictionary = preload("res://big_sizes.gd").SIZES
	return sizes.get(p, Vector2i(t.get_width(), t.get_height()))


func _get_width() -> int:
	return full.x


func _get_height() -> int:
	return full.y


func _get_rid() -> RID:
	return inner.get_rid()


func _has_alpha() -> bool:
	return inner.has_alpha()


func _is_pixel_opaque(x: int, y: int) -> bool:
	return true
