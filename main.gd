extends Node2D
# The test level: the detective fights his way down a night street past six mobsters.
# A / D walk, the mouse aims. No game rules yet.
# For the first seconds of every run the detective walks and aims by himself and the game saves
# two pictures into _shots/, so the result can be checked without anyone taking a screenshot.

const PuppetScript = preload("res://puppet.gd")
const AtmosphereScript = preload("res://atmosphere.gd")
const FxScript = preload("res://fx.gd")
const HudScript = preload("res://hud.gd")
const PPM := 200.0
const WALL_SCALE := 1.9         # sized so a doorway on the wall drawing is a little taller than a man
const WALL_LIFT := 60.0         # the wall stands at the back of the pavement
const SHOULDER := Vector2(0.0, -1.45 * 200.0)

# Night: everything a light does not reach sinks to this colour.
const AMBIENT := Color(0.2, 0.21, 0.27)
const LAMP_COLOR := Color(0.95, 0.74, 0.5)
const WINDOW_COLOR := Color(1.0, 0.78, 0.5)
# Lamps on the wall drawing, in its own pixels: over the two front doors and under the shop awnings.
const LAMPS_PX := [Vector2(335.0, 1040.0), Vector2(1933.0, 1040.0), Vector2(1300.0, 1012.0), Vector2(2850.0, 1012.0)]
# Lit windows, in wall pixels (same rectangles as art/bg/wall_lit.png).
const WINDOWS_PX := [Rect2(70, 1066, 128, 124), Rect2(774, 812, 74, 126), Rect2(1460, 572, 70, 122), Rect2(2335, 332, 68, 118), Rect2(2500, 810, 58, 128)]
const WINDOW_LIGHTS := [0, 4]   # only the low windows throw light down to the street; the light limit per item is 16
# Neon signs on the wall, in wall pixels (centre) and their colour.
const NEONS := [["res://art/props/neon_jazz.png", Vector2(515.0, 880.0), Color(1.0, 0.25, 0.22)], ["res://art/props/neon_hotel.png", Vector2(2600.0, 880.0), Color(1.0, 0.68, 0.25)]]
const LAMP_BULB := Vector2(452.0, 470.0)   # bottom of the bulb on art/props/lamp_wall.png
const SLAB_SCALE := 0.42
const SLAB_REGION_X := Vector2(250.0, 975.0)   # the part of slab_sidewalk.png that tiles without gaps
const MASK_LIT := 1      # things lights fall on
const MASK_UNLIT := 2    # foreground silhouettes: they stay black
const ZOOM := 0.4
# The test level. Solid things he has to jump over and can hide behind: [drawing, left edge, width, height].
# Cover is as tall as a crouching man (about 250 px = 1.25 m), so it hides him and he can still jump it.
const BOXES := [["crate", 1500.0, 250.0, 248.0], ["drum", 3000.0, 160.0, 246.0], ["crate_long", 4500.0, 330.0, 176.0], ["dumpster", 6600.0, 300.0, 250.0], ["crate", 7500.0, 250.0, 248.0], ["crate", 7880.0, 250.0, 248.0], ["crate", 8130.0, 250.0, 248.0]]
# The fire-escape catwalk: he can jump up onto it from the long crate and drop off its ends.
const CATWALK := Rect2(4900.0, -370.0, 1180.0, 0.0)
# Where the mobsters stand: x, and the height of what they stand on.
# A mobster with cover close in front of him crouches behind it and pops up to shoot.
const ENEMIES := [Vector2(2600.0, 0.0), Vector2(3220.0, 0.0), Vector2(5600.0, -370.0), Vector2(6960.0, 0.0), Vector2(8460.0, 0.0), Vector2(9050.0, 0.0)]
const DUCK_DROP := 116.0   # how much lower the chest is when crouched, px
const LEVEL_END := 9600.0
const SIGHT := 2100.0   # a mobster starts shooting once the detective is this close
# The automatic pictures: when (seconds of game time) and under what name.
const SHOTS := [[6.45, "duck"], [6.95, "duck_walk_a"], [7.15, "duck_walk_b"], [1.2, "stand"], [2.0, "run_a"], [2.11, "run_b"], [2.22, "run_c"], [2.8, "run"], [2.95, "dive"], [3.08, "roll_a"], [3.2, "roll_b"], [3.32, "roll_c"], [3.6, "up"], [4.45, "slide_a"], [4.7, "slide_b"], [5.35, "jump"], [5.62, "land_a"], [5.72, "land_b"]]
const BULLET_SPEED := 4200.0
const PLAYER_HP := 5
const MOBSTER_HP := 3
const GRAVITY := 3000.0
const JUMP_SPEED := 1300.0   # clears the 230 px cover with room to spare
const RUN_SPEED := 640.0
const RUN_ACCEL := 4200.0   # he gets up to speed and stops over a few steps, not in one frame
const DIVE_SPEED := Vector2(1250.0, -720.0)
const DIVE_LAND := 125.0   # lying flat, the figure's origin sits this far below the pavement line
const SLOW_SCALE := 0.3   # how fast time runs while it is slowed
const CAM_Y := -572.0     # puts the pavement about four fifths of the way down the screen
const CAM_LEAD := 400.0   # the camera looks ahead of the detective
# Layers behind the street, nearest last: texture, how much they follow the camera (1 = not at all
# displaced, i.e. infinitely far), top edge in world units, scale, brightness, blur.
const DEPTH := [["res://art/bg/far.png", 0.85, -1560.0, 0.8, 0.18, 2.5, -25], ["res://art/bg/mid.png", 0.6, -1500.0, 0.7, 0.14, 1.5, -20]]

const LEGS := {
	"thigh": {"a": Vector2(86.5, 62.5), "b": Vector2(172.9, 418.5), "ppm": 1000},
	"shin": {"a": Vector2(80.6, 56.9), "b": Vector2(100.8, 543.5), "ppm": 1000},
}
var DETECTIVE := {
	"dir": "res://art/detective/", "gun": "res://art/revolver.png", "gun_flip": false,
	# where things attach, in the torso drawing's pixels: the armholes, the bottom of the collar, the belt
	"on_torso": {"shoulder": Vector2(100.0, 225.0), "far_shoulder": Vector2(400.0, 240.0), "head": Vector2(272.0, 168.0), "belt": Vector2(262.0, 596.0)},
	"parts": {
		"head": {"a": Vector2(178.1, 390.6), "b": Vector2(178.1, 84.0), "ppm": 1100},
		# the drawing is used down to the belt only; below it the skirt takes over
		"torso": {"a": Vector2(239.0, 683.3), "b": Vector2(265.5, 65.7), "ppm": 1100, "region": Rect2(0.0, 0.0, 531.0, 627.0)},
		"uarm": {"a": Vector2(116.8, 65.1), "b": Vector2(131.4, 390.6), "ppm": 1100},
		"farm": {"a": Vector2(92.5, 77.4), "b": Vector2(266.4, 412.8), "ppm": 1100},
		# the coat below the belt, from the parts sheet: one panel that hangs over the legs
		"skirt": {"a": Vector2(250.0, 10.0), "b": Vector2(250.0, 850.0), "ppm": 1180},
		# pieces of the torso drawing laid on top again: the belt buckle, which hangs below the cut,
		# and the back wing of the collar over the top of the sleeve
		"collar_front": Rect2(350.0, 620.0, 65.0, 25.0),
		"collar_back": Rect2(150.0, 20.0, 85.0, 195.0),
		"thigh": LEGS["thigh"], "shin": LEGS["shin"],
	},
}
var MOBSTER := {
	"dir": "res://art/mobster/", "gun": "res://art/pistol.png", "gun_flip": true,
	"on_torso": {"shoulder": Vector2(75.0, 125.0), "far_shoulder": Vector2(300.0, 130.0), "head": Vector2(207.0, 62.0), "belt": Vector2(216.0, 673.2)},
	"parts": {
		"head": {"a": Vector2(165.6, 351.5), "b": Vector2(165.6, 75.6), "ppm": 1000},
		"torso": {"a": Vector2(216.0, 673.2), "b": Vector2(207.4, 52.4), "ppm": 1000},
		"uarm": {"a": Vector2(92.6, 52.8), "b": Vector2(80.1, 283.8), "ppm": 1000},
		"farm": {"a": Vector2(50.5, 44.8), "b": Vector2(219.8, 276.0), "ppm": 1000},
		"thigh": LEGS["thigh"], "shin": LEGS["shin"],
	},
}

var player
var enemies: Array = []        # one entry per mobster: node, hp, cool, aim_off, alive
var boxes: Array[Rect2] = []
var cleared := false
var cam: Camera2D
var fore: Node2D
var depth: Array[Node2D] = []   # the far and mid layers, moved with the camera in _process
var depth_follow: Array[float] = []
var lamps: Array[Vector2] = []   # world positions of every lamp, for the cast shadows
var atmo
var steps: CPUParticles2D
var fx
var hud
var hp := PLAYER_HP
var fire_cool := 0.0
var slow_on := false           # toggled by the stopwatch button
var slow_left := 1.0           # 1 = full meter
var move_state := "ground"     # ground, jump or dive
var fall := 0.0                # vertical speed, pixels per second, down is positive
var run := 0.0                 # horizontal running speed, eased towards what the player asks for
var slide_left := 0.0          # seconds of slide remaining
var roll_done := 0.0           # 0..1 through the tumble
var dive_rolls := false        # this dive ends in a roll instead of a flat landing
var glide := 0.0               # horizontal speed of a dive
var over := false              # the detective is down
var _time := 0.0
var _env: Environment
var _probe := 0.0
var _snap := 0
var _slow_look := 0.0   # 0 normal .. 1 the screen is in its slowed-time look
var _show_fps := false
var _dt := -1.0   # the clock of the self-running demo; below 0 = not running. F9 starts it.
var _demo_step := 0
var _demo_duck := false
var _tt := -1.0   # clock of the F11 cover test; below 0 = not running
const TEST_FIRE := [1.6, 2.1, 2.6, 3.1, 3.6]
const TEST_SHOTS := [[1.2, "cover_duck"], [1.68, "cover_pop"], [3.9, "stain"], [4.6, "enemy_a"], [5.1, "enemy_b"], [5.6, "enemy_c"], [6.1, "enemy_d"]]
var _tt_done := 0
var _duck_was := false        # the crouch key was down last frame: a fresh press while running slides
var _pop := 0.0               # seconds the detective stays risen out of his crouch to shoot
var _queued_shot := false     # fire as soon as he has risen far enough to clear his cover
var _shots_done := 0


func _ready() -> void:
	atmo = AtmosphereScript.new()
	add_child(atmo)
	_build_street()
	_build_light()

	_build_level()
	player = PuppetScript.new()
	player.cfg = DETECTIVE
	player.night = _undo_night(1.0)
	add_child(player)

	fore = Node2D.new()   # foreground silhouettes, nearer than the action, so they slide past faster
	fore.z_index = 10
	add_child(fore)
	var fore_tex: Texture2D = load("res://art/bg/fore.png")
	for i in range(-2, 3):
		var f := Sprite2D.new()
		f.texture = fore_tex
		f.centered = false
		f.modulate = Color(0.1, 0.1, 0.11)
		f.light_mask = MASK_UNLIT
		f.scale = Vector2.ONE * 0.62
		f.position = Vector2(i * 6000.0 + 900.0, -fore_tex.get_height() * 0.62 + 235.0)
		f.material = atmo.blur_material(5.0)   # nearer than the focus: soft
		fore.add_child(f)
	for k in range(-2, 3):   # telephone wires sagging across the top of the frame, nearest of all
		var wire := Line2D.new()
		var pts := PackedVector2Array()
		for j in range(17):
			var u := float(j) / 16.0
			pts.append(Vector2(k * 4200.0 + u * 4200.0, -980.0 + sin(u * PI) * 160.0 + (k % 2) * 40.0))
		wire.points = pts
		wire.width = 7.0
		wire.default_color = Color(0.02, 0.02, 0.025)
		wire.light_mask = MASK_UNLIT
		fore.add_child(wire)

	cam = Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position = Vector2(CAM_LEAD, CAM_Y)
	add_child(cam)
	cam.make_current()
	_build_depth()
	atmo.add_rain(cam, _undo_night(0.7), -WALL_LIFT + 18.0 - CAM_Y)
	atmo.add_post(self)
	steps = atmo.add_steps(player, _undo_night(0.6))
	fx = FxScript.new()
	fx.night = _undo_night(1.0)
	fx.hit_test = _bullet_hit
	fx.clash = _bullets_clash
	add_child(fx)
	hud = HudScript.new()
	add_child(hud)
	DirAccess.make_dir_recursive_absolute("res://_shots")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for n in find_children("*", "Light2D", true, false):
		n.add_to_group("lights")
	for n in find_children("*", "Sprite2D", true, false):
		if n.material is ShaderMaterial:
			n.add_to_group("blurred")


func _build_street() -> void:
	var wall_tex: Texture2D = load("res://art/bg/wall2.png")
	var wall_n: Texture2D = load("res://art/bg/wall2_n.png")
	var lit_tex: Texture2D = load("res://art/bg/wall2_lit.png")
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	var additive := CanvasItemMaterial.new()
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var halo_tex := _soft_glow()
	var cone_tex: Texture2D = load("res://art/light_cone_soft.png")
	var wall_w := wall_tex.get_width() * WALL_SCALE
	for i in range(-1, 3):   # the test level runs to x = 9600, past the third copy
		var origin := Vector2(i * wall_w - wall_w * 0.5, -wall_tex.get_height() * WALL_SCALE - WALL_LIFT)
		var tex := CanvasTexture.new()   # the normal map lets lamplight rake across the brickwork
		tex.diffuse_texture = wall_tex
		tex.normal_texture = wall_n
		var w := Sprite2D.new()
		w.texture = tex
		w.centered = false
		w.scale = Vector2.ONE * WALL_SCALE
		w.position = origin
		w.z_index = -10
		w.material = atmo.blur_material(1.4)   # the wall sits a step behind the action: a touch soft
		add_child(w)
		atmo.add_mist(self, origin.x, wall_w, -WALL_LIFT, _undo_night(0.8))
		atmo.add_steam(self, Vector2(origin.x + 700.0 * WALL_SCALE, -20.0))
		atmo.add_steam(self, Vector2(origin.x + 2300.0 * WALL_SCALE, -20.0))
		# windows with a light on behind them. CanvasModulate darkens every item, unshaded or not,
		# so their colour is pushed up by the inverse of the night to come out at full strength.
		var glow := Sprite2D.new()
		glow.texture = lit_tex
		glow.centered = false
		glow.scale = Vector2.ONE * WALL_SCALE
		glow.position = origin
		glow.material = unshaded
		glow.modulate = _undo_night(1.0)
		glow.z_index = -9
		add_child(glow)
		for n in NEONS:
			_add_neon(n[0], origin + (n[1] as Vector2) * WALL_SCALE, n[2], unshaded)
			var glint := Sprite2D.new()   # and the neon's colour on the wet stone below it
			glint.texture = halo_tex
			glint.scale = Vector2(1.2, 0.14)
			glint.position = Vector2(origin.x + (n[1] as Vector2).x * WALL_SCALE, -30.0)
			glint.material = additive
			glint.modulate = _undo_night(0.22) * (n[2] as Color)
			glint.z_index = -7
			add_child(glint)
		for px in LAMPS_PX:
			var at: Vector2 = origin + (px as Vector2) * WALL_SCALE
			lamps.append(at)
			var fix := Sprite2D.new()   # the lamp itself, hung on the wall
			fix.texture = load("res://art/props/lamp_wall.png")
			fix.centered = false
			fix.scale = Vector2.ONE * 0.2
			fix.offset = -LAMP_BULB
			fix.position = at
			fix.z_index = -7
			add_child(fix)
			var beam := Sprite2D.new()   # the cone of lamplight itself, visible in the rain
			beam.texture = cone_tex
			beam.scale = Vector2.ONE * 1.35
			beam.position = at + Vector2(0.0, 256.0 * 1.35)
			beam.material = additive
			beam.modulate = Color(0.0, 0.0, 0.0)   # switched off: the plain lamp glow read better
			beam.z_index = -6
			add_child(beam)
			var halo := Sprite2D.new()   # a small warm glow right at the bulb, nothing more
			halo.texture = halo_tex
			halo.scale = Vector2.ONE * 2.2
			halo.position = at + Vector2(0.0, -8.0)
			halo.material = additive
			halo.modulate = _undo_night(0.4) * Color(1.0, 0.68, 0.32)
			halo.z_index = -6
			add_child(halo)
			for wet_scale in [Vector2(1.7, 0.13), Vector2(0.55, 0.3)]:   # the lamp mirrored in the wet pavement
				var wet := Sprite2D.new()
				wet.texture = halo_tex
				wet.scale = wet_scale
				wet.position = Vector2(at.x, -30.0)
				wet.material = additive
				wet.modulate = _undo_night(0.2) * Color(1.0, 0.72, 0.4)
				wet.z_index = -7
				add_child(wet)
			var bulb := Sprite2D.new()   # the glass glows
			bulb.texture = load("res://art/light_blob.png")
			bulb.scale = Vector2.ONE * 0.11
			bulb.position = at + Vector2(0.0, -8.0)
			bulb.material = unshaded
			bulb.modulate = _undo_night(0.8) * Color(1.0, 0.85, 0.6)
			bulb.z_index = -6
			add_child(bulb)
		for wi in WINDOW_LIGHTS:
			var rr: Rect2 = WINDOWS_PX[wi]
			_add_window_light(origin + (rr.position + rr.size * Vector2(0.5, 1.0)) * WALL_SCALE, rr.size.x * WALL_SCALE)
		_pavement(origin.x, wall_w)


## A round glow that fades out smoothly to nothing at its edge (light_blob.png ends in a hard rim).
func _soft_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.2, 0.35, 0.5, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.11), Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Sky, far skyline and the roofs one block back, seen over the low buildings of the street.
## None of them takes lamplight (light_mask 0); the night still darkens them, so each is lifted
## to the brightness it should keep. Copies alternate with mirrored ones so the seams match.
func _build_depth() -> void:
	var sky_tex: Texture2D = load("res://art/bg/sky.png")
	var sky := Sprite2D.new()   # infinitely far: it hangs off the camera and never slides
	sky.texture = sky_tex
	sky.centered = false
	sky.scale = Vector2.ONE * 1.1
	# the pale band low in the drawing sits right behind the rooftops, so the skyline stands dark against it
	sky.position = Vector2(-sky_tex.get_width() * 1.1 * 0.5, -1838.0)
	sky.modulate = _undo_night(0.4)
	sky.light_mask = 0
	sky.z_index = -30
	sky.material = atmo.blur_material(2.0)
	cam.add_child(sky)
	for d in DEPTH:
		var layer := Node2D.new()
		add_child(layer)
		depth.append(layer)
		depth_follow.append(d[1])
		var t: Texture2D = load(d[0])
		var w: float = t.get_width() * d[3]
		for i in range(-4, 5):
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.flip_h = i % 2 != 0
			s.scale = Vector2.ONE * d[3]
			s.position = Vector2(i * w, d[2])
			s.modulate = _undo_night(d[4])
			s.light_mask = 0
			s.z_index = d[6]
			s.material = atmo.blur_material(d[5])
			layer.add_child(s)


func _undo_night(strength: float) -> Color:
	return Color(strength / AMBIENT.r, strength / AMBIENT.g, strength / AMBIENT.b)


func _add_neon(path: String, at: Vector2, col: Color, unshaded: Material) -> void:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.scale = Vector2.ONE * 0.3
	s.position = at
	s.material = unshaded
	s.modulate = _undo_night(0.9)
	s.z_index = -7
	add_child(s)
	var p := PointLight2D.new()   # the tubes colour the wall around them
	p.texture = load("res://art/light_blob.png")
	p.texture_scale = 2.6
	p.position = at
	p.color = col
	p.energy = 0.5
	p.height = 60.0
	p.range_item_cull_mask = MASK_LIT
	add_child(p)


## Drawn sidewalk slabs laid end to end: the stone top people walk on, the kerb face, then the dark road.
func _pavement(x0: float, w: float) -> void:
	var tex := CanvasTexture.new()
	tex.diffuse_texture = load("res://art/props/slab_sidewalk.png")
	tex.normal_texture = load("res://art/props/slab_sidewalk_n.png")
	# only the middle of the drawing: its ends are bevelled and would leave gaps between slabs
	var region := Rect2(SLAB_REGION_X.x, 0.0, SLAB_REGION_X.y - SLAB_REGION_X.x, tex.diffuse_texture.get_height())
	var sw: float = region.size.x * SLAB_SCALE
	var sh: float = region.size.y * SLAB_SCALE
	_rect(Rect2(x0, -WALL_LIFT - 12.0, w, sh), Color(0.05, 0.05, 0.06))   # dark backing in case a seam opens
	var x := x0
	while x < x0 + w:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.region_enabled = true
		s.region_rect = region
		s.scale = Vector2.ONE * SLAB_SCALE
		s.position = Vector2(x, -WALL_LIFT - 12.0)
		s.z_index = -8
		add_child(s)
		x += sw - 2.0
	_rect(Rect2(x0, -WALL_LIFT - 12.0 + sh - 4.0, w, 900.0), Color(0.05, 0.05, 0.06))


func _rect(r: Rect2, c: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y)])
	p.color = c
	p.z_index = -8
	add_child(p)


func _build_light() -> void:
	var dark := CanvasModulate.new()
	dark.color = AMBIENT
	add_child(dark)

	var moon := DirectionalLight2D.new()   # cold light from above and behind: a thin edge on everything
	moon.color = Color(0.55, 0.63, 0.9)
	moon.energy = 0.35
	moon.height = 0.35
	moon.rotation_degrees = 35.0
	moon.range_item_cull_mask = MASK_LIT
	add_child(moon)

	var cone: Texture2D = load("res://art/light_cone.png")
	for l in lamps:
		var p := PointLight2D.new()   # a hard cone straight down from the lamp to the pavement
		p.texture = cone
		p.texture_scale = 1.35
		p.position = l + Vector2(0.0, 256.0 * 1.35)
		p.color = LAMP_COLOR
		p.energy = 1.3
		p.height = 160.0
		p.range_item_cull_mask = MASK_LIT
		add_child(p)

	var env := Environment.new()   # glow: the lamps and windows bleed a little into the dark
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.75
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_env = env


func _add_window_light(bottom_center: Vector2, width: float) -> void:
	var p := PointLight2D.new()   # warm spill from a lit window onto its sill and whoever passes under it
	p.texture = load("res://art/light_blob.png")
	p.texture_scale = width * 3.2 / 256.0
	p.position = bottom_center + Vector2(0.0, width * 0.2)
	p.color = WINDOW_COLOR
	p.energy = 0.55
	p.height = 120.0
	p.range_item_cull_mask = MASK_LIT
	add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:   # switches for finding what costs time
		match event.physical_keycode:
			KEY_0:
				_show_fps = not _show_fps
			KEY_1:
				atmo.post_layer.visible = not atmo.post_layer.visible
				print("post ", atmo.post_layer.visible)
			KEY_2:
				_env.glow_enabled = not _env.glow_enabled
				print("glow ", _env.glow_enabled)
			KEY_3:
				atmo.rain_far.visible = not atmo.rain_far.visible
				atmo.rain_near.visible = atmo.rain_far.visible
				atmo.splashes.visible = atmo.rain_far.visible
				print("rain ", atmo.rain_far.visible)
			KEY_4:
				var on := true
				for n in get_tree().get_nodes_in_group("lights"):
					n.enabled = not n.enabled
					on = n.enabled
				print("lights ", on)
			KEY_5:
				for n in get_tree().get_nodes_in_group("blurred"):
					n.set_meta("m", n.material if n.material else n.get_meta("m"))
					n.material = null if n.material else n.get_meta("m")
				print("blur toggled")
			KEY_6:
				fore.visible = not fore.visible
				for d in depth:
					d.visible = fore.visible
				print("layers ", fore.visible)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		_snap += 1
		_shot("play_%d" % _snap)
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		_tt = 0.0   # cover test: crouch behind the first crate, pop up and shoot, then watch a mobster use cover
		_tt_done = 0
		player.position = Vector2(1350.0, 0.0)
		cam.position.x = player.position.x + CAM_LEAD
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F9:
		hp = PLAYER_HP
		hud.set_health(1.0)
		_dt = 0.0   # run the demo of every move and save pictures of it into _shots/
		_demo_step = 0
		player.position = Vector2(-6500.0, 0.0)   # an empty stretch of street, away from the mobsters
		cam.position.x = player.position.x + CAM_LEAD
		_shots_done = 0
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not hud.touch_seen:   # on a phone a tap also arrives as a click; the buttons handle those
			hud.fire_tapped = true


func _process(delta: float) -> void:
	_time += delta
	_probe += delta / Engine.time_scale
	if _probe > 2.0 and _show_fps:   # key 0 switches the readout on
		_probe = 0.0
		var vp := get_viewport().get_viewport_rid()
		print("fps ", Engine.get_frames_per_second(), "  script ms ", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), "  gpu ms ", snappedf(RenderingServer.viewport_get_measured_render_time_gpu(vp), 0.1), "  cpu-render ms ", snappedf(RenderingServer.viewport_get_measured_render_time_cpu(vp), 0.1), "  draws ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "  window ", get_window().size)
	var real := delta / Engine.time_scale   # the slow-time meter runs on the wall clock
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	dir = clampf(dir + hud.move, -1.0, 1.0)
	var chest: Vector2 = player.position + SHOULDER + Vector2(0.0, DUCK_DROP * player.duck)
	var aim: Vector2 = get_global_mouse_position() - chest
	if hud.touch_seen:   # no mouse on a phone: he aims at the mobster, or ahead when there is none
		var near = _nearest_enemy()
		aim = (near.position + SHOULDER + Vector2(0.0, DUCK_DROP * near.duck) - chest) if near != null else Vector2(1.0 if dir >= 0.0 else -1.0, 0.0)
	if _dt >= 0.0:
		_dt += delta
	var demo: bool = _dt >= 0.0 and _dt < 7.4 and dir == 0.0   # self-running start for the automatic pictures
	if demo:
		aim = Vector2(1.0, 0.0)
		if _dt > 1.6 and (_dt < 5.9 or _dt > 6.6):
			dir = 1.0
			aim = Vector2(1.0, -0.12)
		_demo_duck = _dt > 5.9
	if _tt >= 0.0:
		_tt += delta
		var target = _nearest_enemy()
		aim = Vector2(1.0, 0.0) if target == null else (target.position + SHOULDER + Vector2(0.0, DUCK_DROP * target.duck) - chest)
		dir = 0.0
		_demo_duck = _tt < 1.5
		for i in TEST_FIRE.size():
			if _tt_done & (1 << i) == 0 and _tt > float(TEST_FIRE[i]):
				_tt_done |= 1 << i
				hud.fire_tapped = true
		for i in TEST_SHOTS.size():
			if _tt_done & (1 << (i + 8)) == 0 and _tt > float(TEST_SHOTS[i][0]):
				_tt_done |= 1 << (i + 8)
				_shot(TEST_SHOTS[i][1])
		if _tt > 4.0 and player.position.x < 2750.0:   # on to the mobster behind the drum
			player.position.x = 2750.0
			cam.position.x = player.position.x + CAM_LEAD
		if _tt > 6.4:
			_tt = -1.0
			_demo_duck = false
	if over:
		dir = 0.0
	if demo:   # the demo throws one of each move, so the pictures show them all
		if _demo_step == 0 and _dt > 2.55:
			_demo_step = 1
			hud.dive_tapped = false
			_start_dive(1.0, 1.0, DIVE_SPEED.y, true)
		elif _demo_step == 1 and _dt > 4.3 and move_state == "ground":
			_demo_step = 2
			hud.dive_tapped = true   # out of a run this is a slide
		elif _demo_step == 2 and _dt > 5.2 and move_state == "ground":
			_demo_step = 3
			hud.jump_tapped = true
	elif _tt < 0.0:
		_demo_duck = false
	dir = _move(dir, aim, delta)
	if not over:
		player.set_state(dir, aim, delta)
	steps.emitting = absf(dir) > 0.3 and move_state == "ground"

	fire_cool = maxf(0.0, fire_cool - delta)
	if demo and _dt > 0.95 and _dt < 1.1 and fire_cool == 0.0:
		hud.fire_tapped = true
	if hud.fire_tapped and fire_cool == 0.0 and not over:
		if player.duck > 0.3:   # crouched behind cover: he rises over it first, then fires
			_queued_shot = true
		else:
			_fire(player, true)
		fire_cool = 0.28
		_pop = 0.5
	hud.fire_tapped = false
	_pop = maxf(0.0, _pop - delta)
	if _queued_shot and player.duck < 0.12:
		_queued_shot = false
		_fire(player, true)

	_enemies(delta)
	if not cleared and not over and player.position.x > LEVEL_END and _nearest_enemy() == null:
		cleared = true
		hud.banner("CASE CLOSED")
		get_tree().create_timer(4.0).timeout.connect(get_tree().reload_current_scene)
	_slow_time(real)
	fx.trail(move_state in ["dive", "roll", "slide"], player.position + Vector2(0.0, -150.0 if move_state == "slide" else -230.0))
	_slow_look = lerpf(_slow_look, 1.0 if Engine.time_scale < 1.0 else 0.0, 1.0 - exp(-10.0 * real))
	atmo.set_slow(_slow_look)
	fx.slow = _slow_look
	_cast_shadow(player)
	for e in enemies:
		if e["alive"]:
			_cast_shadow(e["node"])
	# the camera trails the detective softly and does not bob with jumps
	cam.position = Vector2(lerpf(cam.position.x, player.position.x + CAM_LEAD, 1.0 - exp(-9.0 * real)), CAM_Y)
	fore.position.x = -cam.position.x * 0.35
	for i in depth.size():
		depth[i].position.x = cam.position.x * depth_follow[i]
	if _dt >= 0.0:
		for i in SHOTS.size():
			if _shots_done & (1 << i) == 0 and _dt > float(SHOTS[i][0]):
				_shots_done |= 1 << i
				if SHOTS[i][1] == "stand":
					_fire(player, true)
				_shot(SHOTS[i][1])


## Running, jumping, diving, sliding and rolling. Returns how fast the legs should run, -1..1.
func _move(dir: float, aim: Vector2, delta: float) -> float:
	var jump: bool = hud.jump_tapped or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_SPACE)
	var dive: bool = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_E)
	var duck_held: bool = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_C) or hud.duck or _demo_duck
	var slide: bool = duck_held and not _duck_was   # a fresh press: out of a run that is a slide
	_duck_was = duck_held
	if hud.dive_tapped:   # the one button on the phone: a slide out of a run, a dive otherwise
		if move_state == "ground" and absf(run) > 300.0:
			slide = true
		else:
			dive = true
	hud.jump_tapped = false
	hud.dive_tapped = false
	var facing := -1.0 if aim.x < 0.0 else 1.0
	var legs := 0.0

	if move_state == "ground":
		var can_act: bool = player.dive < 0.05 and player.slide < 0.3 and not over   # back on his feet first
		if can_act and dive:
			_start_dive(dir if dir != 0.0 else facing, facing, DIVE_SPEED.y, absf(run) > 300.0)
		elif can_act and slide and absf(run) > 300.0 and player.duck < 0.3:
			move_state = "slide"
			slide_left = 0.55
			player.slide_side = signf(run) * facing
			run = signf(run) * RUN_SPEED * 1.4
		elif can_act and jump:
			move_state = "jump"
			fall = -JUMP_SPEED

	var before_x: float = player.position.x
	var floor_y := _floor_at(player.position.x, player.position.y - DIVE_LAND * player.dive)
	if move_state == "ground":
		var crouched: bool = duck_held and player.dive < 0.05 and _pop == 0.0
		player.duck = move_toward(player.duck, 1.0 if crouched else 0.0, delta * (6.0 if crouched else 9.0))
		run = move_toward(run, dir * RUN_SPEED * (1.0 - player.dive) * (1.0 - 0.62 * player.duck), RUN_ACCEL * delta)
		glide = move_toward(glide, 0.0, delta * 4000.0)    # he slides a little after landing flat
		player.position.x += (run + glide) * delta
		player.air = move_toward(player.air, 0.0, delta * 8.0)
		player.dive = move_toward(player.dive, 0.0, delta * 3.5)
		player.slide = move_toward(player.slide, 0.0, delta * 5.0)
		player.crouch = lerpf(player.crouch, 0.0, 1.0 - exp(-7.0 * delta))
		if floor_y > player.position.y - DIVE_LAND * player.dive + 2.0 and player.dive < 0.05:   # walked off an edge
			move_state = "jump"
			fall = 0.0
		else:
			player.position.y = floor_y + DIVE_LAND * player.dive   # getting up brings him back onto his feet
		legs = run / RUN_SPEED if player.dive < 0.05 else 0.0
	elif move_state == "jump":
		fall += GRAVITY * delta
		player.position.y += fall * delta
		run = move_toward(run, dir * RUN_SPEED, RUN_ACCEL * 0.5 * delta)
		player.position.x += run * delta
		player.air = move_toward(player.air, 1.0, delta * 8.0)
		if dive:   # a dive can also be thrown out of a jump
			_start_dive(dir if dir != 0.0 else facing, facing, minf(fall, -300.0), false)
		elif fall > 0.0 and player.position.y >= floor_y:
			player.position.y = floor_y
			player.crouch = clampf(fall / 1500.0, 0.3, 0.9)   # the harder the landing, the deeper the knees
			move_state = "ground"
			steps.restart()
	elif move_state == "dive":
		fall += GRAVITY * delta
		player.position.y += fall * delta
		player.position.x += glide * delta
		player.dive = move_toward(player.dive, 1.0, delta * 6.0)
		player.air = move_toward(player.air, 0.0, delta * 8.0)
		if dive_rolls and fall > 0.0 and player.position.y >= floor_y + 30.0:   # fast and forward: over the shoulder
			move_state = "roll"
			roll_done = 0.0
			player.roll = 1.35 * player.dive * player.dive_side
			player.dive = 0.0
		elif fall > 0.0 and player.position.y >= floor_y + DIVE_LAND:   # otherwise flat on the pavement
			player.position.y = floor_y + DIVE_LAND
			player.dive = 1.0
			run = 0.0
			move_state = "ground"
			steps.restart()
	elif move_state == "roll":
		roll_done = minf(1.0, roll_done + delta / 0.5)
		player.roll = lerpf(1.35, TAU, roll_done) * player.dive_side
		player.air = move_toward(player.air, 1.0, delta * 10.0)
		player.crouch = move_toward(player.crouch, 0.9, delta * 10.0)
		player.position.y = move_toward(player.position.y, floor_y, delta * 500.0)
		player.position.x += glide * 0.75 * delta
		if roll_done >= 1.0:   # a full turn: he comes up on his feet, still moving
			player.roll = 0.0
			run = clampf(glide * 0.5, -RUN_SPEED, RUN_SPEED)
			glide = 0.0
			move_state = "ground"
	elif move_state == "slide":
		slide_left -= delta
		run = move_toward(run, 0.0, 500.0 * delta)
		player.position.x += run * delta
		player.slide = move_toward(player.slide, 1.0, delta * 10.0)
		if slide_left <= 0.0:
			move_state = "ground"
	_block(before_x)
	player.position.x = clampf(player.position.x, -8500.0, LEVEL_END + 500.0)
	if move_state != "ground":
		player.duck = move_toward(player.duck, 0.0, delta * 9.0)
	player.ground = _floor_at(player.position.x, player.position.y - DIVE_LAND * player.dive) - player.position.y
	return legs


## The highest thing under his feet: the pavement, the top of a crate, or the catwalk.
func _floor_at(x: float, feet: float) -> float:
	var best := 0.0
	for b in boxes:
		if x > b.position.x - 20.0 and x < b.end.x + 20.0 and feet <= b.position.y + 14.0:
			best = minf(best, b.position.y)
	if x > CATWALK.position.x and x < CATWALK.end.x and feet <= CATWALK.position.y + 14.0:
		best = minf(best, CATWALK.position.y)
	return best


## Crates and the like stop him when he runs, slides or dives into their side.
func _block(before_x: float) -> void:
	var feet: float = player.position.y - DIVE_LAND * player.dive
	for b in boxes:
		if feet <= b.position.y + 14.0:
			continue   # he is on top of it or above it
		var left := b.position.x - 45.0
		var right := b.end.x + 45.0
		if player.position.x > left and player.position.x < right:
			player.position.x = left if before_x <= left + 1.0 else (right if before_x >= right - 1.0 else (left if player.position.x < b.get_center().x else right))
			run = 0.0
			glide = 0.0


func _start_dive(way: float, facing: float, up: float, from_run: bool) -> void:
	move_state = "dive"
	glide = DIVE_SPEED.x * way
	fall = up
	run = 0.0
	player.dive_side = way * facing
	dive_rolls = from_run and way * facing > 0.0


## One shot: flash, bullet, casing, kick of the arm and the lettered bang.
func _fire(shooter, from_player: bool) -> void:
	var at: Vector2 = shooter.muzzle()
	var d: Vector2 = shooter.aim_dir()
	fx.muzzle(at, d)
	fx.shoot(at, d * BULLET_SPEED, from_player)
	fx.casing(at - d * 50.0, signf(d.x))
	shooter.recoil = 0.2
	var word_path := "res://art/fx/word_blam.png" if from_player else "res://art/fx/word_bang.png"
	fx.word(word_path, at + Vector2(signf(d.x) * 70.0, -150.0), 0.29 if from_player else 0.32, d)


## Called by fx.gd for every bullet in flight. True = the bullet stops here.
func _bullet_hit(pos: Vector2, from_player: bool) -> bool:
	for b in boxes:   # cover stops bullets from both sides
		if b.has_point(pos):
			fx.spark(pos)
			return true
	if from_player:
		for e in enemies:
			if not e["alive"]:
				continue
			var rel: Vector2 = pos - e["node"].position
			if absf(rel.x) > 45.0 or rel.y < lerpf(-385.0, -225.0, e["node"].duck) or rel.y > -10.0:
				continue
			fx.blood(Vector2(e["node"].position.x, pos.y), Vector2(signf(e["node"].position.x - player.position.x), 0.0))
			e["hp"] -= 1
			e["seen"] = true   # being shot at wakes him up, however far away
			if e["hp"] <= 0:
				e["alive"] = false
				_drop(e["node"])
				fx.word("res://art/fx/word_krakoom.png", e["node"].position + Vector2(0.0, -500.0), 0.28)
			return true
		return false
	if over or cleared:
		return false
	var flat: bool = player.dive > 0.5 or player.slide > 0.5 or move_state == "roll"   # lying or flying flat he is a long, low target
	var half := 150.0 if flat else 45.0
	var top := -250.0 if flat else lerpf(-385.0, -225.0, player.duck)
	var rel_p: Vector2 = pos - player.position
	if absf(rel_p.x) > half or rel_p.y < top or rel_p.y > -10.0:
		return false
	fx.blood(Vector2(player.position.x, pos.y), Vector2(-signf(pos.x - player.position.x), 0.0))
	if (_dt < 0.0 or _dt > 7.4) and _tt < 0.0:   # nobody gets hurt during the demo or the test
		hp -= 1
		hud.set_health(float(hp) / PLAYER_HP)
		if hp <= 0:
			over = true
			_drop(player)
			Engine.time_scale = 1.0
			slow_on = false
			get_tree().create_timer(2.0).timeout.connect(get_tree().reload_current_scene)
	return true


## One of the detective's bullets met one of theirs in the air.
func _bullets_clash(at: Vector2) -> void:
	fx.word("res://art/fx/word_clink.png", at + Vector2(0.0, -110.0), 0.22)
	slow_left = minf(1.0, slow_left + 0.15)   # a little slowed time back as a reward


## A figure that has been shot down falls on its back and fades.
func _drop(figure) -> void:
	figure.set_shadow(0.0, 0.0, 0.0)
	var tw := create_tween()
	tw.tween_property(figure, "rotation", -PI * 0.5 * figure.scale.x, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.8)
	tw.tween_property(figure, "modulate:a", 0.0, 0.5)


## Crates, the catwalk and the mobsters of the test level.
func _build_level() -> void:
	for spec in BOXES:
		var tex: Texture2D = load("res://art/props/" + String(spec[0]) + ".png")
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(float(spec[2]) / tex.get_width(), float(spec[3]) / tex.get_height())
		s.position = Vector2(float(spec[1]), -float(spec[3]) + 6.0)
		s.z_index = -2
		add_child(s)
		boxes.append(Rect2(float(spec[1]), -float(spec[3]), float(spec[2]), float(spec[3])))
	var cat_tex: Texture2D = load("res://art/props/catwalk.png")
	var cat := Sprite2D.new()
	cat.texture = cat_tex
	cat.centered = false
	cat.scale = Vector2.ONE * (CATWALK.size.x / cat_tex.get_width())
	cat.position = CATWALK.position - Vector2(0.0, 215.0 * cat.scale.y)   # its floor is 215 px down the drawing
	cat.z_index = -2
	add_child(cat)
	for at in ENEMIES:
		var m = PuppetScript.new()
		m.cfg = MOBSTER
		m.night = _undo_night(1.0)
		m.position = at
		add_child(m)
		m.set_state(0.0, Vector2(-1.0, 0.0), 0.0)
		var cover := false
		for bx in boxes:   # cover = something tall standing just in front of him, on his floor
			var gap: float = at.x - bx.end.x
			if gap > 30.0 and gap < 300.0 and bx.size.y > 200.0 and absf(bx.end.y - at.y) < 1.0:
				cover = true
		enemies.append({"node": m, "hp": MOBSTER_HP, "cool": randf_range(0.8, 1.6), "aim_off": 0.0, "alive": true, "seen": false, "cover": cover, "up": false, "shot": false, "timer": randf_range(0.5, 1.5)})


## The closest mobster still standing and near enough to matter, or null.
func _nearest_enemy():
	var best = null
	for e in enemies:
		if e["alive"] and (best == null or absf(e["node"].position.x - player.position.x) < absf(best.position.x - player.position.x)):
			best = e["node"]
	return best


## True when the detective is crouched with cover between him and a mobster on side `side` (+1 = right).
func _player_covered(side: float) -> bool:
	if player.duck < 0.6 or move_state != "ground":
		return false
	for bx in boxes:
		var near_edge: float = bx.position.x if side > 0.0 else bx.end.x
		var gap: float = (near_edge - player.position.x) * side
		if gap > -10.0 and gap < 260.0 and bx.size.y > 200.0:
			return true
	return false


## Each mobster keeps his gun on the detective once he has seen him. One with cover in front of him
## stays down behind it and pops up every couple of seconds to shoot; one without just shoots.
## Nobody fires at a detective crouched behind cover: they wait for him to show himself.
func _enemies(delta: float) -> void:
	for e in enemies:
		if not e["alive"]:
			continue
		var m = e["node"]
		var side: float = signf(m.position.x - player.position.x)
		var to_player: Vector2 = (player.position + Vector2(0.0, SHOULDER.y + DUCK_DROP * player.duck)) - (m.position + Vector2(0.0, SHOULDER.y + DUCK_DROP * m.duck))
		if absf(to_player.x) < SIGHT:
			e["seen"] = true
		if not e["seen"]:
			continue
		var hiding: bool = e["cover"] and side > 0.0   # his cover only works while the detective is on its far side
		var want_duck: float = 0.0
		var may_fire: bool = not over and not cleared and absf(to_player.x) < SIGHT * 1.3 and not _player_covered(side)
		e["timer"] -= delta
		if hiding:
			if e["up"]:
				if e["timer"] < 0.55 and not e["shot"]:
					e["shot"] = true
					if may_fire:
						_fire(m, false)
						e["aim_off"] = randf_range(-120.0, 90.0)
				if e["timer"] <= 0.0:
					e["up"] = false
					e["timer"] = randf_range(1.0, 1.9)
			else:
				want_duck = 1.0
				if e["timer"] <= 0.0:
					e["up"] = true
					e["shot"] = false
					e["timer"] = 1.15
		else:
			e["cool"] -= delta
			if e["cool"] <= 0.0 and may_fire:
				_fire(m, false)
				e["cool"] = randf_range(1.4, 2.3)
				e["aim_off"] = randf_range(-150.0, 110.0)
		m.duck = move_toward(m.duck, want_duck, delta * 7.0)
		m.set_state(0.0, to_player + Vector2(0.0, e["aim_off"]), delta)


## Slowed time: Shift held, or the stopwatch button tapped on and off. It drains a meter that refills.
func _slow_time(real: float) -> void:
	if hud.slow_tapped:
		slow_on = not slow_on
		hud.slow_tapped = false
	# a dive slows time by itself for as long as he is in the air
	var want := (slow_on or move_state == "dive" or Input.is_physical_key_pressed(KEY_SHIFT)) and not over
	var slowed := Engine.time_scale < 1.0
	if want and (slow_left > 0.0 if slowed else slow_left > 0.2):   # an empty meter must refill a little first
		slow_left = maxf(0.0, slow_left - real * 0.28)
		Engine.time_scale = SLOW_SCALE
	else:
		if slow_left == 0.0 or not want:
			slow_on = false
		slow_left = minf(1.0, slow_left + real * 0.14)
		Engine.time_scale = 1.0
	hud.set_slow(slow_left, Engine.time_scale < 1.0)


## The nearest lamp throws the figure's shadow onto the wall behind it, leaning away from the light.
func _cast_shadow(p) -> void:
	var best := Vector2.INF
	for l in lamps:
		if absf(l.x - p.position.x) < absf(best.x - p.position.x):
			best = l
	var dx: float = p.position.x - best.x
	var reach := 900.0
	var k := clampf(1.0 - absf(dx) / reach, 0.0, 1.0)
	p.set_shadow(dx * 0.9, clampf(dx / 600.0, -0.9, 0.9), 0.45 * k)


func _shot(shot_name: String) -> void:
	print("shot ", shot_name, "  fps ", Engine.get_frames_per_second())
	if _tt >= 0.0:
		var states := []
		for e in enemies:
			states.append("%d:%s:hp%d:duck%.1f" % [int(e["node"].position.x), "alive" if e["alive"] else "dead", e["hp"], e["node"].duck])
		print("  player x ", int(player.position.x), " duck ", snappedf(player.duck, 0.1), "  ", states)
	await RenderingServer.frame_post_draw
	if not is_inside_tree():   # the scene was restarted while waiting for the frame
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_shots/" + shot_name + ".png")
