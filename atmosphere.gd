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
uniform vec2 registration = vec2(1.6, 1.0);
uniform float lift = 0.0;   // 0 = Sin City blacks; 1 = the darks opened up so walls in the dark keep their lines
uniform float fire_keep = 0.0;   // 1 in the dream: the flames are not greyed with the rest
uniform float dream = 0.0;   // the burning dream (2026-11-15): heat shimmer, smoke under the roof, embers at the edges, the plates slipping
uniform float jolt = 0.0;
uniform float fog = 0.0;   // Pier 17: the river fog; clear only round him (fog_at, screen UV)
uniform vec2 fog_at = vec2(0.5, 0.75);   // a start in the nightmare: the picture doubles for a moment
uniform float ash = 0.0;   // 0..1, Frank's guilt: the paper greys, the amber dies, the rain goes to soot   // screen pixels between the ink and the colour plates

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float smoke_at(vec2 p) {
	float v = vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 9.1) * 0.15;
	return v;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 q0 = uv - 0.5;
	float edge2 = dot(q0, q0);
	if (dream > 0.0) {
		// heat: the air wavers, more low down where the fires stand, and it never keeps still
		float low = 0.35 + 0.65 * smoothstep(0.2, 1.0, uv.y);
		uv.x += (sin(uv.y * 70.0 + TIME * 4.3) + 0.6 * sin(uv.y * 31.0 - TIME * 2.7)) * 0.0011 * dream * low;
		uv.y += sin(uv.x * 45.0 + TIME * 3.1) * 0.0007 * dream * low;
		uv += vec2(sin(TIME * 47.0), cos(TIME * 39.0)) * jolt * 0.004;
	}
	vec3 c = texture(screen_texture, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// the colour plate is printed a hair off the ink plate, like cheap 1940s newsprint
	// (in the dream it slips further toward the edges of the page, and a start doubles it)
	vec2 reg = registration * (1.0 + dream * edge2 * 14.0) + vec2(jolt * 14.0, -jolt * 6.0);
	vec3 cc = texture(screen_texture, uv + reg * SCREEN_PIXEL_SIZE).rgb;
	float lc = dot(cc, vec3(0.299, 0.587, 0.114));
	float mx = max(cc.r, max(cc.g, cc.b));
	float mn = min(cc.r, min(cc.g, cc.b));
	float sat = (mx - mn) / (mx + 0.0001);
	// crimson stays: a true red, not the orange of lamplit wood
	float red = smoothstep(0.12, 0.3, cc.r - max(cc.g, cc.b)) * smoothstep(0.5, 0.7, sat)
			* (1.0 - smoothstep(0.3, 0.45, cc.g / (cc.r + 0.0001)));
	// lamplight stays warm, as a dirty, half-faded amber
	float warm = smoothstep(0.08, 0.25, cc.r - cc.b) * smoothstep(0.28, 0.55, lc);
	float t = clamp((l - black_point) / (white_point - black_point), 0.0, 1.0);
	t = pow(mix(t, t * t * (3.0 - 2.0 * t), 0.5), 0.85);   // firm blacks, open grey mid-tones
	t = mix(t, pow(t, 0.62), lift);
	vec3 mono = mix(mix(ink, vec3(0.12, 0.115, 0.11), lift), paper, t);
	// amber belongs to the light sources: painted orange washes fade toward the newsprint grey
	vec3 amber = mix(vec3(lc), cc, 0.3) * vec3(1.1, 0.93, 0.7);
	vec3 col = mix(mono, amber, warm * 0.55);
	col = mix(col, cc * vec3(1.05, 0.85, 0.85), red);
	// the heavier the ash, the more the page looks burnt: warmth drains to soot grey, whites dull
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(g) * vec3(0.96, 0.95, 0.94), ash * 0.6 * (1.0 - red));
	col *= 1.0 - ash * 0.1;
	// in the burning dream the fire keeps its own colour: deep orange that is also bright stays
	float fire = smoothstep(0.3, 0.55, cc.r - cc.b) * smoothstep(0.35, 0.6, lc) * fire_keep;
	col = mix(col, cc * vec3(1.0, 0.92, 0.85), fire * 0.8);
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
	if (fog > 0.0) {
		// banks of fog drifting in off the river: thick a few yards from him, thinner round him;
		// what burns bright (lamps, muzzle flashes, fire) still glows through it
		vec2 asp = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
		float d = length((SCREEN_UV - fog_at) * asp);
		float bank = smoke_at(vec2(SCREEN_UV.x * 1.8 - TIME * 0.05, SCREEN_UV.y * 2.4 + TIME * 0.015));
		float f = clamp(smoothstep(0.2, 0.72, d) * (0.6 + 0.45 * bank) + smoothstep(0.55, 0.0, SCREEN_UV.y) * 0.15, 0.0, 0.86) * fog;
		vec3 fogc = mix(paper, vec3(0.55, 0.56, 0.57), 0.55);
		float glow = max(lc - 0.62, 0.0) * 1.6;
		col = mix(col, fogc, f) + vec3(glow) * f * vec3(1.0, 0.92, 0.75);
	}
	if (dream > 0.0) {
		// smoke rolling under the roof, thick at the top of the page, thinning down to his shoulders
		vec2 sp = vec2(SCREEN_UV.x * 2.6 + TIME * 0.035, SCREEN_UV.y * 3.2 + TIME * 0.09);
		float sm = smoothstep(0.3, 0.72, smoke_at(sp)) * (1.0 - smoothstep(0.05, 0.62, SCREEN_UV.y));
		col = mix(col, ink * 1.6, sm * 0.75 * dream);
		// the edges of the page smoulder: a breathing ember red in place of the plain black
		float beat = pow(0.5 + 0.5 * sin(TIME * 1.7), 3.0);
		float rim = smoothstep(0.1, 0.32, edge2 + (vnoise(SCREEN_UV * 6.0 + TIME * 0.2) - 0.5) * 0.06);
		col = mix(col, vec3(0.42, 0.07, 0.02) * (0.6 + beat * 0.6), rim * dream * 0.55);
	}
	// heavy vignette
	vec2 q = SCREEN_UV - 0.5;
	col *= clamp(1.0 - dot(q, q) * (vignette + slow * 0.35 + dream * 0.25) * 2.6, 0.0, 1.0);
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


func set_lift(amount: float) -> void:
	_post.set_shader_parameter("lift", amount)


func set_fire_keep(amount: float) -> void:
	_post.set_shader_parameter("fire_keep", amount)


## The burning dream's own page (0 = none): see `dream` in POST_SHADER. It gets worse each time it starts over.
func set_dream(amount: float) -> void:
	_post.set_shader_parameter("dream", amount)


## The river fog (0 = none) and where on the screen he stands, the one place it is thin.
func set_fog(amount: float, at: Vector2) -> void:
	_post.set_shader_parameter("fog", amount)
	_post.set_shader_parameter("fog_at", at)


## A start: the picture doubles and shakes for a moment, then settles.
func jolt(amount: float) -> void:
	_post.set_shader_parameter("jolt", amount)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _post.set_shader_parameter("jolt", v), amount, 0.0, 0.45)


func set_ash(amount: float) -> void:
	_post.set_shader_parameter("ash", clampf(amount, 0.0, 1.0))
	for r in [rain_far, rain_near]:   # rain falls grey with soot, not silver
		if r:
			r.color = r.color.lerp(Color(0.62, 0.6, 0.58, r.color.a), clampf(amount, 0.0, 1.0) * 0.8)


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
	splashes.texture = load("res://art/fx/ink/splash1.png")   # painted crowns (art_src 158)
	splashes.amount = 70
	splashes.lifetime = 0.28
	splashes.local_coords = false   # a splash stays where the drop landed as the camera moves on
	splashes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	splashes.emission_rect_extents = Vector2(2200.0, 26.0)
	splashes.position = Vector2(0.0, street_y)
	splashes.gravity = Vector2.ZERO
	splashes.initial_velocity_min = 0.0
	splashes.initial_velocity_max = 0.0
	splashes.scale_amount_min = 0.05
	splashes.scale_amount_max = 0.1
	splashes.color_ramp = _fade(Color(1.0, 1.0, 1.0, 0.55))
	splashes.modulate = boost
	splashes.z_index = -4
	cam.add_child(splashes)


## Drops end on the pavement wherever the camera is: below the street's line on the screen they are cut
## away (main.gd moves the line each frame), so jumping or standing on a crate never lifts the ground.
const RAIN_CUT := "shader_type canvas_item;\nuniform float cut = 2.0;\nvoid fragment() {\n\tif (SCREEN_UV.y > cut) { discard; }\n}\n"
var _rain_cut: Shader
var rain_mats: Array = []


## The street's line on the screen (world y of the pavement) for the drops and the splashes.
func set_ground(cam: Camera2D, ground_y: float) -> void:
	var ct := cam.get_viewport().get_canvas_transform()
	var v: float = (ct * Vector2(0.0, ground_y)).y / cam.get_viewport().get_visible_rect().size.y
	for i in rain_mats.size():
		(rain_mats[i] as ShaderMaterial).set_shader_parameter("cut", v + (0.0 if i == 0 else 0.03))
	if splashes:
		splashes.position.y = ground_y - cam.get_screen_center_position().y + 4.0


func _rain(extents: Vector2, amount: int, life: float, alpha: float, size: float, z: int, boost: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/fx/rain_streak.png")
	p.amount = amount
	life *= 1.3   # long enough to reach the pavement with the camera up on a crate or a roof; the cut ends them
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
	if _rain_cut == null:
		_rain_cut = Shader.new()
		_rain_cut.code = RAIN_CUT
	var m := ShaderMaterial.new()
	m.shader = _rain_cut
	p.material = m
	rain_mats.append(m)
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
	p.scale_amount_min = 0.7   # broad soft puffs: small ones strung in a line read as a white squiggle
	p.scale_amount_max = 1.1
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = grow
	var g := Gradient.new()
	g.set_color(0, Color(0.6, 0.62, 0.66, 0.0))
	g.set_color(1, Color(0.6, 0.62, 0.66, 0.0))
	g.add_point(0.3, Color(0.6, 0.62, 0.66, 0.16))
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


## Rain landing on the detective: tiny splashes on the crown of his hat and on his shoulders, and
## now and then a drop running off the brim. Three emitters main.gd moves with him each frame.
func add_hat_rain(parent: Node, boost: Color) -> Array:
	var out := []
	for k in 3:
		var p := CPUParticles2D.new()
		p.local_coords = false
		p.texture = load("res://art/fx/splash2.png" if k < 2 else "res://art/fx/rain_streak.png")
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(40.0 if k == 0 else (50.0 if k == 1 else 6.0), 4.0)
		p.amount = 10 if k == 0 else (8 if k == 1 else 2)
		p.lifetime = 0.22 if k < 2 else 0.5
		p.direction = Vector2(0.0, -1.0) if k < 2 else Vector2(0.0, 1.0)
		p.spread = 50.0 if k < 2 else 2.0
		p.initial_velocity_min = 40.0 if k < 2 else 30.0
		p.initial_velocity_max = 120.0 if k < 2 else 60.0
		p.gravity = Vector2(0.0, 900.0 if k < 2 else 1400.0)
		p.scale_amount_min = 0.03 if k < 2 else 0.25
		p.scale_amount_max = 0.06 if k < 2 else 0.4
		p.particle_flag_align_y = k == 2
		p.color_ramp = _fade(Color(0.9, 0.93, 1.0, 0.7))
		p.modulate = boost
		p.z_index = 3
		parent.add_child(p)
		out.append(p)
	return out
