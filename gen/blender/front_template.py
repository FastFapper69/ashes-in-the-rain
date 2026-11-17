"""A building front for an interior, as a grey 3D blockout rendered in the game's own view (QUEUE_doma §8.1, §9;
user 17. 11.: "a modular system: from the street through a door into the house's hallway - and no ugly joins").

The street drawings of the hk kit are 3168 x 1344 px, seen square-on, 1.52 world px per picture px (main.gd
WALL_SCALE 1.9 x SEGMENT_SIZE 0.8). This builds a flat front of that kit in Blender - the same dark party walls
down both edges (any neighbour joins), the cornice, three storeys of windows, the pavement - with the two doors of
an interior exactly where the room begins and ends (gen/levels.py FRONTS). Gemini (Nano Banana) paints over the
render in the game's style, keeping every edge: so the doors land where the game opens them.

Run:  blender --background --factory-startup --python gen/blender/front_template.py -- <style> <out.png>
Units: 1 Blender unit = 100 picture px; x to the right, z up, the picture's row r is z = (1344 - r) / 100.
"""
import sys, math
import bpy

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["tenement", "/tmp/front.png"]
STYLE, OUT = argv[0], argv[1]

W, H = 3168, 1344
PX = 1.52                 # world px per picture px
PAVE = 1250               # the row where the front stands on the pavement
TOP = 96                  # the cornice's top
PIER = 124                # the dark party wall down each edge
# the interiors (gen/levels.py chunk widths): the doors' middles this far apart, the room's middle at the picture's
ROOM_W = {"tenement": 2300, "laundry": 2700, "warehouse": 2400, "club": 2600, "yard": 2600}
# plain street pieces (no interior behind): their ground-floor bays (shop door middles), spread along the front
SHOPS = {"shops": [700, 1584, 2468], "church": [1584], "warehouse_row": [900, 2268]}
if STYLE in SHOPS:
    DOORS = SHOPS[STYLE]
else:
    span = ROOM_W[STYLE] / PX
    DOORS = [W / 2 - span / 2, W / 2 + span / 2]   # picture px: the street door (the room's left end), the side door (its right)
DOOR_W, DOOR_H = {"warehouse": (230, 400), "church": (280, 470), "warehouse_row": (300, 420), "yard": (270, 450)}.get(STYLE, (150, 360))

def z(r): return (H - r) / 100.0
def x(c): return c / 100.0

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, grey):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (grey, grey, grey, 1.0)
    return m
WALL, DARK, TRIM, GLASS, PAVEM = mat("wall", 0.62), mat("dark", 0.18), mat("trim", 0.8), mat("glass", 0.08), mat("pave", 0.5)

def box(c0, c1, r0, r1, y0, y1, m):
    """A box spanning picture columns c0..c1 and rows r0..r1 (r0 the top), from depth y0 to y1 (toward the camera
    is -y)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = bpy.context.object
    o.scale = (x(c1 - c0), (y1 - y0), z(r0) - z(r1))
    o.location = ((x(c0) + x(c1)) / 2, (y0 + y1) / 2, (z(r0) + z(r1)) / 2)
    o.data.materials.append(m)
    return o

# the pavement, the kerb, the front wall, the party walls standing a little forward of it
box(0, W, PAVE, H, -0.6, 0.4, PAVEM)
box(PIER, W - PIER, TOP, PAVE, 0.0, 0.4, WALL)
box(0, PIER, 40, PAVE, -0.25, 0.4, DARK)
box(W - PIER, W, 40, PAVE, -0.25, 0.4, DARK)
# the cornice along the top, a band at each floor
box(PIER, W - PIER, TOP, TOP + 46, -0.32, 0.0, TRIM)
for r in (420, 760):
    box(PIER, W - PIER, r, r + 18, -0.08, 0.0, TRIM)

def window(cx, r0, w=118, h=150):
    box(cx - w / 2 - 14, cx + w / 2 + 14, r0 + h, r0 + h + 16, -0.12, 0.0, TRIM)   # the sill
    box(cx - w / 2 - 10, cx + w / 2 + 10, r0 - 18, r0, -0.1, 0.0, TRIM)            # the lintel
    box(cx - w / 2, cx + w / 2, r0, r0 + h, -0.04, -0.01, GLASS)                   # (a dark pane over the wall: reads as the opening)

# upper storeys: windows evenly along, never over a door's line (the doors' storeys above get a window each)
cols = [PIER + 170 + k * 236 for k in range(12)]
cols = [c for c in cols if c < W - PIER - 150]
for r0 in (190, 530):
    for c in cols:
        if STYLE == "church" and 650 < c < 2520:
            continue
        if STYLE == "warehouse_row" and abs(c - 1584) < 200:
            continue   # (the loading doors' column)   # (the church's nave: its own tall windows, no storeys)
        window(c, r0)

def door(cx, kind):
    left, right = cx - DOOR_W / 2, cx + DOOR_W / 2
    box(left - 30, right + 30, PAVE - DOOR_H - 50, PAVE - DOOR_H, -0.16, 0.0, TRIM)   # the lintel / pediment
    box(left - 22, left, PAVE - DOOR_H, PAVE, -0.1, 0.0, TRIM)                       # the frame
    box(right, right + 22, PAVE - DOOR_H, PAVE, -0.1, 0.0, TRIM)
    box(left, right, PAVE - DOOR_H, PAVE, -0.04, -0.01, DARK)                         # the door
    if kind == "stoop":   # two low steps out onto the pavement (no higher: he walks in level)
        box(left - 40, right + 40, PAVE - 14, PAVE, -0.5, 0.0, TRIM)
        box(left - 60, right + 60, PAVE, PAVE + 14, -0.8, -0.3, TRIM)

kind = {"tenement": "stoop"}.get(STYLE, "plain")
for cx in DOORS:
    door(cx, kind)
# the ground floor between the doors: by the style
HOIST = (1584, 464)   # (warehouse_row) the pulley's bottom, picture px: the game hangs its swinging rope from it
if STYLE == "warehouse_row":   # loading doors on every floor up the middle, the hoist beam over the top one, the pulley under it
    box(1584 - 115, 1584 + 115, 480, 760, -0.04, -0.01, DARK)
    box(1584 - 115, 1584 + 115, 140, 400, -0.04, -0.01, DARK)
    box(1584 - 20, 1584 + 20, 400, 430, -1.6, 0.0, IRON if False else TRIM)   # the beam, sticking out from the wall
    box(1584 - 34, 1584 + 34, 430, HOIST[1], -1.5, -1.3, DARK)               # the pulley block hanging under its end
    for c in (500, 1300, 1868, 2668):
        box(c - 70, c + 70, PAVE - 300, PAVE - 120, -0.04, -0.01, GLASS)
elif STYLE == "church":   # a church squeezed into the row: tall lancet windows either side of the portal, a rose window over it
    for c in (900, 1180, 1988, 2268):
        box(c - 60, c + 60, PAVE - 760, PAVE - 120, -0.04, -0.01, GLASS)
    box(1584 - 150, 1584 + 150, 330, 630, -0.04, -0.01, GLASS)
    box(1584 - 200, 1584 + 200, PAVE - DOOR_H - 140, PAVE - DOOR_H - 50, -0.2, 0.0, TRIM)
elif STYLE in SHOPS:   # a shop each side of every door: windows, a sign board over the bay, an awning frame
    for d in DOORS:
        for side in (-1, 1):
            a0, b0 = sorted((d + side * 110, d + side * 400))
            box(a0, b0, PAVE - 300, PAVE - 50, -0.04, -0.01, GLASS)
        box(d - 420, d + 420, PAVE - 440, PAVE - 360, -0.14, 0.0, TRIM)
elif STYLE in ("laundry", "club"):   # a shop window, a blank sign board over it
    a, b = DOORS[0] + 180, DOORS[1] - 180
    box(a, b, PAVE - 330, PAVE - 60, -0.04, -0.01, GLASS)
    box(a - 20, b + 20, PAVE - 60, PAVE - 40, -0.1, 0.0, TRIM)
    box(a + 80, b - 80, PAVE - 440, PAVE - 360, -0.14, 0.0, TRIM)   # the sign
elif STYLE == "warehouse":   # a loading door between, shut, and a plain board over it
    mid = (DOORS[0] + DOORS[1]) / 2
    box(mid - 260, mid + 260, PAVE - 420, PAVE, -0.04, -0.01, DARK)
    box(mid - 300, mid + 300, PAVE - 520, PAVE - 440, -0.14, 0.0, TRIM)
elif STYLE == "yard":   # carriage passages through the building into its back yard: a few barred windows between
    for c in cols:
        if all(abs(c - d) > 260 for d in DOORS):
            window(c, 900, 90, 120)
elif STYLE == "tenement":   # tenement ground floor: windows between the stoops
    for c in cols:
        if all(abs(c - d) > 200 for d in DOORS):
            window(c, 880, 118, 170)
# the ground-floor windows beyond the doors, outside the room
for c in cols:
    if (c < DOORS[0] - 200 or c > DOORS[-1] + 200) and STYLE not in SHOPS:
        if STYLE != "tenement":
            window(c, 880, 118, 170)

# the camera: square-on, orthographic, exactly the picture
bpy.ops.object.camera_add(location=(x(W) / 2, -50.0, z(H / 2)), rotation=(math.pi / 2, 0.0, 0.0))
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = x(W)
scene.camera = cam
scene.render.resolution_x, scene.render.resolution_y = W, H
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_cavity = True
sh.cavity_type = "BOTH"
sh.show_object_outline = True
sh.object_outline_color = (0.0, 0.0, 0.0)
sh.show_shadows = False
scene.view_settings.view_transform = "Standard"
scene.display.light_direction = (0.45, -0.6, 0.65)
scene.render.film_transparent = False
world = bpy.data.worlds.new("w"); scene.world = world
sh.background_type = "VIEWPORT"
sh.background_color = (1.0, 1.0, 1.0)   # white sky: process_art.py keys it out like every street drawing's
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("FRONT", STYLE, "doors at px", [round(d) for d in DOORS], "->", OUT)
