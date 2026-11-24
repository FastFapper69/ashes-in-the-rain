"""Blender, no window: a BVH motion capture -> the world position of each joint in every frame (JSON).
(user 24. 11.: "I want to see the mocap Blender version" - postavy/plan-novych-postav.md, layer A)
usage: blender -b --factory-startup --python gen/mocap/bvh_joints.py -- <in.bvh> <out.json>
The CMU skeleton's bones: we keep the hips, both legs (hip, knee, ankle, ball, toe), the spine to the head and both
arms (shoulder, elbow, wrist, hand tip). Metres are not needed: gen/mocap/side.py scales to the figure's own bones."""
import bpy, sys, json

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_anim.bvh(filepath=src, axis_forward="-Z", axis_up="Y", rotate_mode="NATIVE", update_scene_fps=False, update_scene_duration=True)
arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
sc = bpy.context.scene
action = arm.animation_data.action
f0, f1 = int(action.frame_range[0]), int(action.frame_range[1])
# joint name -> (bone, head or tail)
J = {"hips": ("Hips", 0), "neck": ("Neck1", 0), "head": ("Head", 0), "head_top": ("Head", 1), "chest": ("Spine1", 0)}
for s, S in (("l", "Left"), ("r", "Right")):
    J.update({s + "_hip": (S + "UpLeg", 0), s + "_knee": (S + "Leg", 0), s + "_ankle": (S + "Foot", 0), s + "_ball": (S + "ToeBase", 0),
              s + "_toe": (S + "ToeBase", 1), s + "_shoulder": (S + "Arm", 0), s + "_elbow": (S + "ForeArm", 0),
              s + "_wrist": (S + "Hand", 0), s + "_hand": (S + "Hand", 1)})
names = {b.name for b in arm.pose.bones}
if "Neck1" not in names:
    J["neck"] = ("Neck", 0)
if "Spine1" not in names:
    J["chest"] = ("Spine", 0)
frames = []
mw = arm.matrix_world
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    row = {}
    for k, (b, end) in J.items():
        pb = arm.pose.bones[b]
        p = mw @ (pb.tail if end else pb.head)
        row[k] = [round(p.x, 4), round(p.y, 4), round(p.z, 4)]   # Blender: z is up
    frames.append(row)
ft = 1.0 / (sc.render.fps / sc.render.fps_base)
for line in open(src, encoding="utf-8", errors="ignore"):
    if line.startswith("Frame Time:"):
        ft = float(line.split(":")[1])
json.dump({"src": src.replace("\\", "/").split("/")[-1], "frame_time": ft, "bones": sorted(names), "frames": frames}, open(out, "w"))
print("BVH OK", src, len(frames), "frames", ft)
