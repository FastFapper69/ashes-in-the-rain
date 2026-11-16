"""The chapter I street kit's interactive things (user 16. 11.: they stand a little out of the picture, 3D in 2D).
The street drawings are Gemini's versions with the thing removed (art_src 233-236); the things themselves come from
one green sheet drawn to match (art_src 232): cut apart and keyed into art/props/hk_<kind>.png. The game stands each
one where it was painted (STREET_PROPS in main.gd: its box in the street drawing's pixels, same numbers as BOXES
here), a little in front of the wall: parallax + a contact shadow.

Run from the repo root after gen/process_art.py hk_tailor hk_grocery hk_saloon hk_laundry.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(os.path.expanduser("~"), "Documents", "MobileGames", "Ink and Lead", "art_src")
# where each was painted in the original (approved) drawings, in the processed 3168x1344 pixels
BOXES = {"awning": ("hk_tailor", (975, 752, 1732, 958)), "hydrant": ("hk_grocery", (1805, 1112, 1922, 1302)),
         "kegs": ("hk_saloon", (1082, 985, 1328, 1262)), "steampipe": ("hk_laundry", (1588, 1000, 2158, 1292))}

if __name__ == "__main__":
    a = np.asarray(Image.open(os.path.join(SRC, "232.jpg")).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] -= np.maximum(g - np.maximum(r, b), 0) * (1 - alpha * 0.5)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    lab, n = ndimage.label(alpha > 0.5)
    objs = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        size = int((lab[sl] == i + 1).sum())
        if size > 4000:
            objs.append((sl[1].start, sl[0].start, sl, i + 1, size))
    # the sheet: awning top left, hydrant top middle, kegs top right, pipes along the bottom (the first one is used)
    top = sorted([o for o in objs if o[1] < a.shape[0] * 0.45], key=lambda o: o[0])
    bottom = sorted([o for o in objs if o[1] >= a.shape[0] * 0.45], key=lambda o: o[0])
    for kind, o in zip(["awning", "hydrant", "kegs"], top[:3]):
        sl = o[2]
        piece = rgba[sl].copy()
        piece[..., 3] = np.where(lab[sl] == o[3], piece[..., 3], 0)
        Image.fromarray(piece).save(os.path.join(ROOT, "art", "props", f"hk_{kind}.png"))
        print(kind, piece.shape[1::-1])
    o = bottom[0]
    sl = o[2]
    piece = rgba[sl].copy()
    piece[..., 3] = np.where(lab[sl] == o[3], piece[..., 3], 0)
    Image.fromarray(piece).save(os.path.join(ROOT, "art", "props", "hk_steampipe.png"))
    print("steampipe", piece.shape[1::-1])


# Animation sheets (art_src 237 hydrant, 238 kegs, 239 steam pipe): six frames in a row on green, the thing's foot at
# the same place in each. Keyed and cut into six equal cells, all cropped by the SAME box (the union over the frames,
# aligned on the cells' foot) so the thing does not jump: art/props/hk_<kind>_anim.png, a strip of 6 cells
# (main.gd/props.gd split it by width / 6). The foot's x share in the cell is printed (props.gd ANIM_FOOT).
ANIMS = {"hydrant": ("237.jpg", 1), "kegs": ("238.jpg", 1), "steampipe": ("239.jpg", 2)}   # (file, rows of 6 frames)
def anim(kind, f, n=6, rows=1):
    a = np.asarray(Image.open(os.path.join(SRC, f)).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] -= np.maximum(g - np.maximum(r, b), 0) * (1 - alpha * 0.5)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    cols = n // rows
    W, H = rgba.shape[1] // cols, rgba.shape[0] // rows
    cells = [rgba[(i // cols) * H:(i // cols + 1) * H, (i % cols) * W:(i % cols + 1) * W] for i in range(n)]
    ys, xs = np.where(np.max([c[..., 3] for c in cells], axis=0) > 20)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    strip = np.concatenate([c[y0:y1, x0:x1] for c in cells], axis=1)
    Image.fromarray(strip).save(os.path.join(ROOT, "art", "props", f"hk_{kind}_anim.png"))
    print(kind, "anim", n, "frames of", (x1 - x0, y1 - y0))


if __name__ == "__main__":
    for kind, (f, rows) in ANIMS.items():
        if os.path.exists(os.path.join(SRC, f)):
            anim(kind, f, 6, rows)
