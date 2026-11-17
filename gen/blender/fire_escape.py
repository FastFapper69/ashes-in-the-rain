"""hk_tailor's fire escape built in 3D and rendered as its own layer (QUEUE §11, rule 27; user 17. 11.: "use Blender").
Gemini could not draw it apart from the wall in the same place, so it is built here from the game's own numbers
(gen/kit.py hk_tailor: landings at rows 693 and 389 over x 1909..2321, the stairs 2013,693 -> 2239,390, the drop ladder
at x 2020 down to row 902) and rendered square-on like the street drawing, iron grey with black ink lines (Freestyle),
on a clear background: art/props/hk_fescape.png, its box (picture px) printed for gen/kit.py.

Run:  blender --background --factory-startup --python gen/blender/fire_escape.py -- <out.png>
Units: 1 Blender unit = 100 picture px; x right, z up, picture row r -> z = (1344 - r) / 100; y = towards the wall.
"""
import sys
import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["/tmp/fescape.png"]
OUT = ARGS[0]
H = 1344
# per street piece (gen/kit.py): the render window, the landings' span and rows, the stairs, the drop ladder x and foot
FE = {"hk_tailor": {"box": (1880, 250, 2360, 930), "x": (1909, 2321), "floors": (389, 693), "ramp": ((2013, 693), (2239, 390)), "ladder": (2020, 902)},
      "alley_wash": {"box": (810, 260, 1340, 1030), "x": (840, 1303), "floors": (400, 747), "ramp": ((950, 747), (1200, 400)), "ladder": (1260, 1010)}}
P = FE[ARGS[1] if len(ARGS) > 1 else "hk_tailor"]
BOX = P["box"]   # the render's window on the street drawing (picture px)
RES = 2                        # render px per picture px (drawn bigger, shown smaller: crisp lines)


def z(r): return (H - r) / 100.0
def x(c): return c / 100.0


bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
iron = bpy.data.materials.new("iron")
iron.diffuse_color = (0.055, 0.052, 0.05, 1.0)
iron_top = bpy.data.materials.new("iron_top")
iron_top.diffuse_color = (0.12, 0.115, 0.11, 1.0)


def box(name, x0, x1, r_top, r_bot, d0, d1, mat=iron):
    """A block from picture x0..x1, rows r_top..r_bot, depth d0..d1 picture px out from the wall (y negative = out)."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.name = name
    o.location = ((x(x0) + x(x1)) / 2, -(d0 + d1) / 200.0, (z(r_top) + z(r_bot)) / 2)
    o.scale = (x(x1) - x(x0), (d1 - d0) / 100.0, z(r_top) - z(r_bot))
    o.data.materials.append(mat)
    return o


(X0, X1), DEPTH = P["x"], 70          # the landings' span, how far they stand out of the wall
LOW = P["floors"][1]
for fy in P["floors"]:
    box("floor", X0, X1, fy - 4, fy + 14, 0, DEPTH, iron_top)          # the grating
    box("rail_top", X0, X1, fy - 112, fy - 104, DEPTH - 8, DEPTH)      # the hand rail
    box("rail_mid", X0, X1, fy - 20, fy - 14, DEPTH - 6, DEPTH)
    for side in (X0, X1 - 8):                                          # the end rails back to the wall
        box("rail_end", side, side + 8, fy - 112, fy - 104, 0, DEPTH)
    n = 22
    for i in range(n + 1):                                             # the balusters
        bx = X0 + (X1 - X0 - 6) * i / n
        box("bar", bx, bx + 5, fy - 108, fy, DEPTH - 6, DEPTH - 1)
    for bx in (X0 + 30, (X0 + X1) / 2, X1 - 40):                       # the brackets under it, into the wall
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.object
        o.data.materials.append(iron)
        o.location = (x(bx), -DEPTH / 200.0, z(fy + 40))
        o.scale = (0.05, DEPTH / 100.0 * 1.35, 0.05)
        o.rotation_euler = (0.9, 0.0, 0.0)

# the stairs: two stringers and the treads, from the lower landing up to the upper
import math
(ax, ar), (bx_, br) = P["ramp"]
L = math.hypot(bx_ - ax, br - ar)
ang = math.atan2(ar - br, bx_ - ax)
for d0, d1 in ((DEPTH - 50, DEPTH - 42), (DEPTH - 12, DEPTH - 4)):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.data.materials.append(iron)
    o.location = (x((ax + bx_) / 2), -(d0 + d1) / 200.0, (z(ar) + z(br)) / 2)
    o.scale = (L / 100.0, (d1 - d0) / 100.0, 0.09)
    o.rotation_euler = (0.0, -ang, 0.0)
steps = 14
for i in range(1, steps):
    t = i / steps
    cx, cr = ax + (bx_ - ax) * t, ar + (br - ar) * t
    box("tread", cx - 10, cx + 10, cr - 3, cr + 3, DEPTH - 48, DEPTH - 6, iron_top)
# the stair rail
bpy.ops.mesh.primitive_cube_add(size=1)
o = bpy.context.object
o.data.materials.append(iron)
o.location = (x((ax + bx_) / 2), -(DEPTH - 4) / 100.0, (z(ar - 100) + z(br - 100)) / 2)
o.scale = (L / 100.0, 0.06, 0.06)
o.rotation_euler = (0.0, -ang, 0.0)

# the drop ladder: two rails and rungs, hanging under the lower landing (its foot ~590 px over the pavement)
(LX, FOOT), LW = P["ladder"], 64
for rx in (LX - LW / 2, LX + LW / 2 - 7):
    box("ladder_rail", rx, rx + 7, LOW, FOOT, DEPTH - 30, DEPTH - 22)
r = LOW + 19
while r < FOOT - 2:
    box("rung", LX - LW / 2, LX + LW / 2, r, r + 5, DEPTH - 29, DEPTH - 23, iron_top)
    r += 28

# camera: square-on, orthographic, the window BOX
cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
w_px, h_px = BOX[2] - BOX[0], BOX[3] - BOX[1]
cam.ortho_scale = max(w_px, h_px) / 100.0
co = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(co)
co.location = (x((BOX[0] + BOX[2]) / 2), -20.0, (z(BOX[1]) + z(BOX[3])) / 2)
co.rotation_euler = (math.radians(90), 0.0, 0.0)
scene.camera = co
scene.render.resolution_x = w_px * RES
scene.render.resolution_y = h_px * RES
scene.render.film_transparent = True
scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "MATERIAL"
sh.show_cavity = True
scene.view_settings.view_transform = "Standard"
scene.render.use_freestyle = True
scene.render.line_thickness_mode = "ABSOLUTE"
scene.render.line_thickness = 2.2
ls = scene.view_layers[0].freestyle_settings.linesets[0] if scene.view_layers[0].freestyle_settings.linesets else scene.view_layers[0].freestyle_settings.linesets.new("ink")
ls.select_by_visibility = True
ls.select_silhouette = ls.select_border = ls.select_crease = True
if ls.linestyle is None:
    ls.linestyle = bpy.data.linestyles.new("ink")
ls.linestyle.color = (0.0, 0.0, 0.0)
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("FESCAPE box", BOX, "res", RES)
