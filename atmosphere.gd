extends Node
# Night atmosphere for the street scene: the screen-wide noir grade, rain, splashes, steam, mist
# and the blurred foreground. Kept apart from main.gd so the look can be tuned in one place.

const POST_SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec3 ink = vec3(0.035, 0.033, 0.032);
uniform vec3 paper = vec3(0.93, 0.902, 0.855);   // old newsprint, a little yellowed
uniform float black_point = 0.012;
uniform float white_point = 0.42;   // the night scene is dark; stretch it so the ink drawing reads
uniform float vignette = 0.5;
uniform float grain = 0.035;
uniform float dot_size = 4.0;
uniform float halftone = 0.16;
uniform float slow = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / (mx + 0.0001);
	// crimson stays: a true red, not the orange of lamplit wood
	float red = smoothstep(0.12, 0.3, c.r - max(c.g, c.b)) * smoothstep(0.5, 0.7, sat)
			* (1.0 - smoothstep(0.3, 0.45, c.g / (c.r + 0.0001)));
	// lamplight stays warm, as a dirty, half-faded amber
	float warm = smoothstep(0.08, 0.25, c.r - c.b) * smoothstep(0.28, 0.55, l);
	float t = clamp((l - black_point) / (white_point - black_point), 0.0, 1.0);
	t = pow(mix(t, t * t * (3.0 - 2.0 * t), 0.5), 0.85);   // firm blacks, open grey mid-tones
	vec3 mono = mix(ink, paper, t);
	vec3 amber = mix(vec3(l), c, 0.4) * vec3(1.12, 0.92, 0.66);
	vec3 col = mix(mono, amber, warm * 0.75);
	col = mix(col, c * vec3(1.05, 0.85, 0.85), red);
	// halftone dots in the mid-tones only, like cheap newsprint; deep shadows stay solid ink
	vec2 p = FRAGCOORD.xy / dot_size;
	vec2 rp = vec2(p.x + p.y, p.y - p.x) * 0.7071;
	vec2 cell = fract(rp) - 0.5;
	float dark = 1.0 - t;
	float dotm = 1.0 - smoothstep(sqrt(dark) * 0.45 - 0.06, sqrt(dark) * 0.45, length(cell));
	col = mix(col, col * 0.5, dotm * (halftone + slow * 0.4) * smoothstep(0.05, 0.25, t) * smoothstep(0.3, 0.65, dark));
	// paper grain, redrawn twelve times a second
	float n = hash(floor(FRAGCOORD.xy * 0.5) + floor(TIME * 12.0) * 17.0);
	col += (n - 0.5) * grain;
	// heavy vignette
	vec2 q = SCREEN_UV - 0.5;
	col *= clamp(1.0 - dot(q, q) * (vignette + slow * 0.35) * 2.6, 0.0, 1.0);
	// slowed time: a hand-inked panel border closes in, with a thin paper line inside it
	vec2 px = FRAGCOORD.xy;
	vec2 size = px / max(SCREEN_UV, vec2(0.0001));
	float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
	float rough = (hash(floor(px / 5.0)) - 0.5) * 5.0;
	float border = slow * size.y * 0.035;
	col = mix(col, paper, slow * step(edge + rough, border + 5.0));
	col = mix(col, ink, step(edge + rough, border) * step(0.001, slow));
	COLOR = vec4(col, 1.0);
}
"""

const BLUR_SHADER := """
shader_type canvas_item;
uniform float radius = 1.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	vec4 c = texture(TEXTURE, UV) * 0.36;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.16;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.16;
	COLOR = c * COLOR;
}
"""

var _blur: Shader
var _post: ShaderMaterial
var post_layer: CanvasLayer
var rain_far: CPUParticles2D
var rain_near: CPUParticles2D
var splashes: CPUParticles2D
var ash: Array[CPUParticles2D] = []


## Full-screen grade on a layer above the world, so CanvasModulate does not darken it a second time.
func add_post(parent: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	parent.add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	_post = mat
	layer.add_child(rect)
	post_layer = layer


## 0 = normal, 1 = slowed time: a black panel border closes in, heavier dots and darker edges.
func set_slow(amount: float) -> void:
	_post.set_shader_parameter("slow", amount)


func blur_material(radius: float) -> ShaderMaterial:
	if _blur == null:   # one shader for every blurred sprite, compiled once
		_blur = Shader.new()
		_blur.code = BLUR_SHADER
	var sh := _blur
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("radius", radius)
	return mat


## Rain hangs off the camera so it always covers the screen. One layer behind the figures, one in front.
## street_y: the pavement, in the camera's own coordinates.
func add_rain(cam: Camera2D, boost: Color, street_y: float) -> void:
	rain_far = _rain(Vector2(2500.0, 40.0), 1000, 0.7, 0.22, 0.55, -5, boost)
	rain_near = _rain(Vector2(2500.0, 40.0), 320, 0.6, 0.5, 1.0, 20, boost)
	cam.add_child(rain_far)
	cam.add_child(rain_near)

	splashes = CPUParticles2D.new()   # every drop that lands throws up a small crown on the pavement
	splashes.texture = load("res://art/fx/splash2.png")
	splashes.amount = 70
	splashes.lifetime = 0.28
	splashes.local_coords = false   # a splash stays where the drop landed as the camera moves on
	splashes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	splashes.emission_rect_extents = Vector2(2200.0, 26.0)
	splashes.position = Vector2(0.0, street_y)
	splashes.gravity = Vector2.ZERO
	splashes.initial_velocity_min = 0.0
	splashes.initial_velocity_max = 0.0
	splashes.scale_amount_min = 0.07
	splashes.scale_amount_max = 0.14
	splashes.color_ramp = _fade(Color(1.0, 1.0, 1.0, 0.55))
	splashes.modulate = boost
	splashes.z_index = -4
	cam.add_child(splashes)


func _rain(extents: Vector2, amount: int, life: float, alpha: float, size: float, z: int, boost: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/rain_streak.png")
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false   # the drops fall through the street; only where new ones start follows the camera
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.position = Vector2(-300.0, -1000.0)
	p.direction = Vector2(0.28, 1.0)
	p.spread = 2.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2600.0
	p.initial_velocity_max = 3300.0
	p.particle_flag_align_y = true
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.3
	p.color = Color(0.9, 0.93, 1.0, alpha)
	p.modulate = boost
	p.z_index = z
	return p


func _fade(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	return g


## Slow plumes of steam out of the street, lit by whatever lamp is near.
func add_steam(parent: Node, at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/puff3.png")
	p.amount = 9
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = at
	p.direction = Vector2(0.15, -1.0)
	p.spread = 14.0
	p.gravity = Vector2(10.0, -6.0)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.angular_velocity_min = -8.0
	p.angular_velocity_max = 8.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = grow
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.62, 0.66, 0.0))
	g.set_color(1, Color(0.6, 0.62, 0.66, 0.0))
	g.add_point(0.25, Color(0.6, 0.62, 0.66, 0.28))
	p.color_ramp = g
	p.z_index = -3
	parent.add_child(p)


## Mist gathers along the street.
func add_mist(parent: Node, x0: float, w: float, street: float, boost: Color) -> void:
	var mist := Sprite2D.new()
	mist.texture = _vertical(Color(0.55, 0.6, 0.68, 0.0), Color(0.55, 0.6, 0.68, 0.13))
	mist.centered = false
	mist.scale = Vector2(w / 64.0, 380.0 / 256.0)
	mist.position = Vector2(x0, street - 380.0)
	mist.modulate = boost
	mist.z_index = -9
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mist.material = unshaded
	parent.add_child(mist)


func _vertical(top: Color, bottom: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 256
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	return t


## Water kicked up by the feet while a figure runs.
func add_steps(figure: Node2D, boost: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/splash1.png")
	p.amount = 6
	p.lifetime = 0.3
	p.local_coords = false
	p.emitting = false
	p.position = Vector2(0.0, -6.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(50.0, 4.0)
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.2
	p.color_ramp = _fade(Color(1.0, 1.0, 1.0, 0.7))
	p.modulate = boost
	p.z_index = 1
	figure.add_child(p)
	return p


## Ash: the fire at Pier 17 that the rain will not wash out. Fine flakes float slowly down through
## the rain, all but gone in the dark and silvery where a lamp or a neon catches them (they take
## light like everything on the street). One layer behind the figures, a sparser nearer one in front.
## density 0..1 is set per map; embers 0..1 adds flakes that still glow (the burnt pier).
func add_ash(cam: Camera2D, density: float, embers: float) -> void:
	if density <= 0.0:
		return
	var flake := _flake()
	for layer in 2:
		var p := CPUParticles2D.new()
		p.texture = flake
		p.amount = maxi(6, int((320.0 if layer == 0 else 70.0) * density))
		p.lifetime = 14.0
		p.preprocess = 14.0
		p.local_coords = false   # they hang in the street, the camera passes through them
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(2300.0, 1300.0)
		p.direction = Vector2(0.3, 1.0)
		p.spread = 180.0
		p.gravity = Vector2(6.0, 16.0)
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 34.0
		p.damping_min = 2.0
		p.damping_max = 6.0
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -70.0
		p.angular_velocity_max = 70.0
		p.scale_amount_min = 0.6 if layer == 0 else 1.1
		p.scale_amount_max = 1.2 if layer == 0 else 2.0
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.97, 0.94, 0.0))
		g.set_color(1, Color(1.0, 0.97, 0.94, 0.0))
		g.add_point(0.15, Color(1.0, 0.97, 0.94, 0.95 if layer == 0 else 0.6))
		g.add_point(0.8, Color(0.95, 0.93, 0.9, 0.8 if layer == 0 else 0.5))
		p.color_ramp = g
		p.z_index = -5 if layer == 0 else 14
		if layer == 1:
			p.material = blur_material(2.5)   # nearer than the focus: soft
		cam.add_child(p)
		ash.append(p)
	if embers > 0.0:   # a few still burning: unshaded, so they glow in the dark
		var e := CPUParticles2D.new()
		e.texture = flake
		e.amount = maxi(4, int(40.0 * embers))
		e.lifetime = 7.0
		e.preprocess = 7.0
		e.local_coords = false
		e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		e.emission_rect_extents = Vector2(2300.0, 500.0)
		e.position = Vector2(0.0, 500.0)
		e.direction = Vector2(0.2, -1.0)
		e.spread = 40.0
		e.gravity = Vector2(10.0, -18.0)
		e.initial_velocity_min = 20.0
		e.initial_velocity_max = 60.0
		e.scale_amount_min = 0.35
		e.scale_amount_max = 0.8
		var add := CanvasItemMaterial.new()
		add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		e.material = add
		var eg := Gradient.new()
		eg.offsets = PackedFloat32Array([0.0, 0.1, 0.35, 0.5, 0.7, 1.0])
		eg.colors = PackedColorArray([Color(1.0, 0.5, 0.15, 0.0), Color(1.0, 0.6, 0.2, 0.9), Color(1.0, 0.45, 0.12, 0.35),
				Color(1.0, 0.6, 0.2, 0.85), Color(0.9, 0.3, 0.1, 0.3), Color(0.5, 0.15, 0.05, 0.0)])
		e.color_ramp = eg
		e.z_index = -4
		cam.add_child(e)
		ash.append(e)


## A gust now and then: the whole cloud of ash leans with the wind. Called every frame.
func blow_ash(t: float) -> void:
	var wind := sin(t * 0.23) * 14.0 + sin(t * 0.61 + 1.3) * 9.0
	for p in ash:
		p.gravity.x = wind + 6.0


## A small torn flake: a ragged soft-edged blob, so the ash does not read as round dots.
func _flake() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1939
	var lobes: Array[Vector3] = []
	for k in 4:
		lobes.append(Vector3(rng.randf_range(8.0, 16.0), rng.randf_range(9.0, 15.0), rng.randf_range(2.5, 5.0)))
	for y in 24:
		for x in 24:
			var a := 0.0
			for l in lobes:
				var d := Vector2(x + 0.5 - l.x, (y + 0.5 - l.y) * 1.4).length()
				a = maxf(a, clampf((l.z - d) / 1.6, 0.0, 1.0))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
