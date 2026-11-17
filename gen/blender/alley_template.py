"""An alley mouth for the hk street kit, as a grey 3D blockout (QUEUE §10.3 thresholds, research ch15; rule 24: a deep view
is part of the painting and stands still - so its perspective must be right in the drawing itself).

Two row houses with the kit's metrics (3168x1344, party walls 0-124 / 3044-3168, pavement row 1250, cornice ~96) and
between them the mouth of an alley with an iron gate. The camera is a real perspective camera at a man's eye height
(row EYE) looking straight at the street; its lens is shifted so the plane of the fronts (y = 0) fills the picture
exactly as the flat kit pieces do - the fronts line up with every other piece, and only what lies behind them (the
alley running away) shows depth, vanishing at the same eye height the game's other deep views use.

Run:  blender --background --factory-startup --python gen/blender/alley_template.py -- <out.png> [mouth_left mouth_right]
"""
import sys, math
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["/tmp/alley.png"]
OUT = argv[0]
SUBWAY = "--subway" in argv          # a subway entrance instead: an arch in one front, stairs going down inside
FIRE = "--fire" in argv              # the washing-line alley: a fire escape up the left house's front beside the mouth
argv = [a for a in argv if a not in ("--subway", "--fire")]
W, H = 3168, 1344
PAVE, TOP, PIER = 1250, 96, 124
EYE = 976                                    # a man's eyes: 274 px over the pavement (door 360 = 2.1 m, eyes 1.6 m)
M0, M1 = (float(argv[1]), float(argv[2])) if len(argv) > 2 else ((1400.0, 1768.0) if SUBWAY else (1330.0, 1840.0))   # the opening, picture px
ARCH = PAVE - 470                            # (subway) the arch's top
DEPTH = 34.0                                 # how far the alley runs back (units of 100 px)

def z(r): return (H - r) / 100.0
def x(c): return c / 100.0

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
def mat(name, grey):
    m = bpy.data.materials.new(name); m.diffuse_color = (grey, grey, grey, 1.0); return m
WALL, DARK, TRIM, GLASS, PAVEM, IRON = mat("wall", 0.62), mat("dark", 0.18), mat("trim", 0.8), mat("glass", 0.08), mat("pave", 0.5), mat("iron", 0.1)

def box(cx0, cx1, rz0, rz1, y0, y1, m):
    """columns cx0..cx1 (picture px), rows rz0 (top) .. rz1, depth y0..y1 (units, +y away from the street)"""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.object
    o.scale = (x(cx1 - cx0), (y1 - y0), z(rz0) - z(rz1))
    o.location = ((x(cx0) + x(cx1)) / 2, (y0 + y1) / 2, (z(rz0) + z(rz1)) / 2)
    o.data.materials.append(m)

# the pavement and the street before it
box(0, W, PAVE, H + 400, -0.6, 0.0, PAVEM)
# the two houses: fronts, party walls at the picture's edges, cornices, floor bands, windows, a stoop door each
if SUBWAY:   # (one building: its front closes over the arch)
    box(M0, M1, TOP, ARCH, 0.0, 0.4, WALL)
    box(M0 - 40, M1 + 40, ARCH - 110, ARCH - 20, -0.2, 0.0, TRIM)    # the sign board over the arch
for a, b in ((PIER, M0), (M1, W - PIER)):
    box(a, b, TOP, PAVE, 0.0, 0.4, WALL)
    box(a, b, TOP, TOP + 46, -0.32, 0.0, TRIM)
    for r in (420, 760):
        box(a, b, r, r + 18, -0.08, 0.0, TRIM)
    c = a + 120
    while c + 118 < b - 60:
        for r0 in (190, 530, 880):
            box(c, c + 118, r0, r0 + 150, -0.04, -0.01, GLASS)
            box(c - 12, c + 130, r0 + 150, r0 + 166, -0.12, 0.0, TRIM)
        c += 236
box(0, PIER, 40, PAVE, -0.25, 0.4, DARK)
box(W - PIER, W, 40, PAVE, -0.25, 0.4, DARK)
if SUBWAY:   # inside the arch: a tiled passage, the stairs going down away from the street, a lit landing below
    box(M0, M1, PAVE, PAVE + 20, 0.0, 3.0, PAVEM)
    for k in range(14):                                   # the flight: each step a little lower and further in
        box(M0, M1, PAVE + 20 + k * 22, PAVE + 42 + k * 22, 3.0 + k * 0.55, 3.55 + k * 0.55, TRIM)
    box(M0 - 10, M0, ARCH, PAVE + 400, 0.0, 12.0, GLASS)  # tiled side walls
    box(M1, M1 + 10, ARCH, PAVE + 400, 0.0, 12.0, GLASS)
    box(M0, M1, ARCH, ARCH + 10, 0.0, 12.0, TRIM)         # its ceiling sloping down with the stairs
    box(M0, M1, ARCH, PAVE + 420, 12.0, 12.4, WALL)        # the landing's back wall below
    box(M0 - 18, M0, ARCH, PAVE, -0.1, 0.0, TRIM)          # the arch's jambs
    box(M1, M1 + 18, ARCH, PAVE, -0.1, 0.0, TRIM)
    for gx in (M0 - 120, M1 + 120):                        # the two globe lamps on posts either side
        box(gx - 8, gx + 8, PAVE - 520, PAVE, -0.6, -0.5, IRON)
        box(gx - 40, gx + 40, PAVE - 600, PAVE - 520, -0.65, -0.45, GLASS)
    DEPTH = 0.0
# the alley: its floor running back, the side walls of the two houses (with windows and a fire escape on one), a far wall
if not SUBWAY:
  box(M0, M1, PAVE, PAVE + 20, 0.0, DEPTH, PAVEM)
if not SUBWAY:
  box(M0 - 10, M0, TOP, PAVE, 0.0, DEPTH, WALL)                  # the left house's side wall, facing into the alley
  box(M1, M1 + 10, TOP, PAVE, 0.0, DEPTH, WALL)                  # the right house's
  for d in range(3, int(DEPTH) - 2, 5):                          # windows down both side walls
      for r0 in (260, 600, 900):
          box(M0, M0 + 2, r0, r0 + 130, d, d + 1.3, GLASS)
          box(M1 - 2, M1, r0, r0 + 130, d + 2, d + 3.3, GLASS)
  for k, r in enumerate((420, 760)):                              # a fire escape's landings on the left wall, deep in
      box(M0, M0 + 90, r, r + 10, 8.0 + k, 14.0 + k, IRON)
  box(M0 - 10, M1 + 10, 300, PAVE, DEPTH, DEPTH + 1, WALL)        # the far wall: a dead end, a lit back door in it
  box((M0 + M1) / 2 - 60, (M0 + M1) / 2 + 60, PAVE - 330, PAVE, DEPTH - 0.05, DEPTH, DARK)
  # the gate at the mouth: two iron leaves on posts, the left one swung half open into the alley
  posts = (M0 + 6, M1 - 6)
  for p in posts:
      box(p - 9, p + 9, PAVE - 470, PAVE, 0.2, 0.4, IRON)
  mid = (M0 + M1) / 2
  for k in range(int(M0 + 30), int(mid), 34):                    # left leaf, swung back (drawn deeper, to the left)
      box(k - 3, k + 3, PAVE - 440, PAVE - 10, 1.4, 1.5, IRON)
  for k in range(int(mid), int(M1 - 20), 34):                    # right leaf, shut
      box(k - 3, k + 3, PAVE - 440, PAVE - 10, 0.3, 0.36, IRON)
  for r in (PAVE - 440, PAVE - 230, PAVE - 30):
      box(mid, M1 - 15, r, r + 8, 0.3, 0.36, IRON)


if FIRE:   # an iron fire escape on the left house's front, its landings at the floors (rows 420, 760), right by the mouth
    FX0, FX1 = 860, 1300
    for r in (420, 760):
        box(FX0, FX1, r - 8, r + 8, -0.9, 0.0, IRON)                  # the deck
        box(FX0, FX1, r - 110, r - 100, -0.9, -0.85, IRON)            # its top rail
        for c in range(FX0, FX1 + 1, 110):
            box(c - 4, c + 4, r - 110, r, -0.9, -0.85, IRON)          # balusters
    for k in range(10):                                                # the flight between the landings
        cx = FX0 + 60 + k * 30
        box(cx - 18, cx + 18, 760 - k * 34 - 6, 760 - k * 34, -0.6, -0.4, IRON)
    box(FX1 - 60, FX1 - 52, 760, 1010, -0.95, -0.9, IRON)            # the drop ladder's rails
    box(FX1 - 12, FX1 - 4, 760, 1010, -0.95, -0.9, IRON)
    for r in range(790, 1010, 36):
        box(FX1 - 60, FX1 - 4, r, r + 6, -0.95, -0.9, IRON)

# the camera: a man's eye, on the mouth's middle, looking straight down the alley; the lens shifted so the fronts'
# plane (y = 0) is exactly the 3168 x 1344 picture
D = 40.0
mid = (M0 + M1) / 2
cam_x, cam_z = x(mid), z(EYE)
bpy.ops.object.camera_add(location=(cam_x, -D, cam_z), rotation=(math.pi / 2, 0.0, 0.0))
cam = bpy.context.object
cam.data.type = "PERSP"
cam.data.sensor_fit = "HORIZONTAL"
cam.data.sensor_width = 36.0
cam.data.lens = D * 36.0 / x(W)
cam.data.shift_x = (x(W) / 2 - cam_x) / x(W)
cam.data.shift_y = (z(H / 2) - cam_z) / x(W)
cam.data.clip_end = 500.0
scene.camera = cam
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"; sh.color_type = "MATERIAL"
sh.show_cavity = True; sh.cavity_type = "BOTH"
sh.show_object_outline = True; sh.object_outline_color = (0.0, 0.0, 0.0)
sh.show_shadows = False
sh.background_type = "VIEWPORT"; sh.background_color = (1.0, 1.0, 1.0)
scene.view_settings.view_transform = "Standard"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("ALLEY mouth", M0, M1, "eye row", EYE, "->", OUT)
