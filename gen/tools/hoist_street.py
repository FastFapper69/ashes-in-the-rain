"""art/street/warehouse_c.png: the warehouse street with its hoist's hanging rope and hook taken out (the game hangs
its own swinging rope from the painted pulley, gen/levels.py hoist_ropes). Rebuilt from the drawing itself, so it
stays sharp: the S of STORAGE from the S of HUDSON (same lettering, 150 px to the left), the T's crossbar mirrored
round its stem, the brick, rail and door tops under the sign copied from just left of the rope. The lit and
solid layers are the warehouse's own. Run from the repo root."""
import shutil
import numpy as np
from PIL import Image
o = np.asarray(Image.open("art/street/warehouse.png").convert("RGB")).copy()
src = o.copy()
# the rope's first strand (x 690-696) over the S's right side and the gap: from HUDSON's S, 150 px left
o[628:702, 686:702] = src[628:702, 686 - 150:702 - 150]
# the second strand (x 708-713) over the T's left edge: the T is symmetric round x 719, mirror its right half
for x in range(702, 718):
    o[628:702, x] = src[628:702, 2 * 719 - x]
# below the sign: the hook, its block and the rope over brick, the door rail and the door tops
o[702:795, 660:735] = src[702:795, 660 - 95:735 - 95]
Image.fromarray(o).save("art/street/warehouse_c.png")
for layer in ("_lit", "_solid"):   # its lit windows and blood mask are the warehouse's own (nothing there moved)
    shutil.copy(f"art/street/warehouse{layer}.png", f"art/street/warehouse_c{layer}.png")
print("ok")
