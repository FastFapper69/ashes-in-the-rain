"""The chapter I street kit's interactive things (user 16. 11.: they stand a little out of the picture, 3D in 2D).
The street drawings are Gemini's versions with the thing removed (art_src 233-236); the things themselves come from
one green sheet drawn to match (art_src 232): cut apart and keyed into art/props/hk_<kind>.png. The game stands each
one where it was painted (gen/kit.py PIECES: its box in the street drawing's pixels, same numbers as BOXES here), a little in front of the wall: parallax + a contact shadow.

Run from the repo root after gen/process_art.py hk_tailor hk_grocery hk_saloon hk_laundry.
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
from paths import SRC
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
# (props.gd splits it by width / 6; ANIM_W there = the thing's width share of a cell). A grid sheet (rows > 1) reads row by row.
ANIMS = {"hydrant": ("237.jpg", 1), "kegs": ("238.jpg", 2), "steampipe": ("239.jpg", 2), "windlass": ("241.jpg", 2), "trolley": ("242.jpg", 2),
         "thirdrail": ("244.jpg", 4, 8, [0, 1, 2, 4, 5, 7])}   # (file, rows(, frames drawn, the six used))   # (file, rows of 6 frames)
SHRINK = {"hydrant": 0.72, "kegs": 0.5, "windlass": 0.5, "trolley": 0.6, "thirdrail": 0.8}
# The trolley wire's far piece wanders a little near the cell's edge: cut it off at the same x in every cell (dark
# pixels only, in a band round it, so smoke there stays), the game draws it on from there (props.gd TROLLEY_WIRE).
WIRE_CUT = {"trolley": (705, 140, 240)}   # x, rows y0..y1 in the cell, full size   # drawn bigger than shown: a hydrant cell is ~360 px wide on the street
DESPILL = {"thirdrail"}
def anim(kind, f, n=6, rows=1, pick=None):
    a = np.asarray(Image.open(os.path.join(SRC, f)).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] -= np.maximum(g - np.maximum(r, b), 0) * (1 - alpha * 0.5)
    if kind in DESPILL:   # smoke and haze are see-through: what is left green in them goes grey
        a[..., 1] = np.minimum(a[..., 1], (a[..., 0] + a[..., 2]) / 2 + 6)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    cols = n // rows
    W, H = rgba.shape[1] // cols, rgba.shape[0] // rows
    cells = [rgba[(i // cols) * H:(i // cols + 1) * H, (i % cols) * W:(i % cols + 1) * W].copy() for i in range(n)]
    if pick:
        cells = [cells[i] for i in pick]
    ys, xs = np.where(np.max([c[..., 3] for c in cells], axis=0) > 20)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    if kind in WIRE_CUT:   # (measured on the crop, the same in every cell)
        wx, wy0, wy1 = WIRE_CUT[kind]
        for c in cells:
            band = c[y0 + wy0:y0 + wy1, x0 + wx:]
            dark = band[..., :3].mean(axis=2) < 110
            band[..., 3] = np.where(dark, 0, band[..., 3])
    strip = Image.fromarray(np.concatenate([c[y0:y1, x0:x1] for c in cells], axis=1))
    if kind in SHRINK:   # no more pixels than the game shows it at (props.gd scales the cell to the thing on the street)
        strip = strip.resize((round(strip.width * SHRINK[kind] / 6) * 6, round(strip.height * SHRINK[kind])), Image.LANCZOS)
    strip.save(os.path.join(ROOT, "art", "props", f"hk_{kind}_anim.png"))
    print(kind, "anim", n, "frames of", (strip.width // 6, strip.height))


if __name__ == "__main__":
    for kind, (f, rows, *more) in ANIMS.items():
        if os.path.exists(os.path.join(SRC, f)):
            anim(kind, f, more[0] if more else 6, rows, more[1] if more else None)
    if os.path.exists(os.path.join(SRC, "238.jpg")):
        kegs_still()
    if os.path.exists(os.path.join(SRC, "241.jpg")):
        still("windlass")
    if os.path.exists(os.path.join(SRC, "242.jpg")):
        still("trolley")
    if os.path.exists(os.path.join(SRC, "244.jpg")):
        still("thirdrail")


# The kegs on the street are the animation's first frame (user 17. 11.: the stack must not change when shot), its
# bullet spark, splinters and the shell off: cut right of the hit barrel above the standing one, the star on the lid
# covered by the same spot of the left barrel's lid. Cropped to the stack: props.gd ANIM_W/ANIM_X0 = its share/left in a cell.
def kegs_still():
    a = np.asarray(Image.open(os.path.join(ROOT, "art", "props", "hk_kegs_anim.png"))).astype(float)
    cw = a.shape[1] // 6
    c = a[:, :cw].copy()
    k = cw / 875.0   # the numbers below were measured on the full-size cell (875 px)
    yy, xx = np.mgrid[:c.shape[0], :c.shape[1]]
    sx, sy = xx / k - 98, yy / k - 76
    c[..., 3] = np.where((sx > 536) & (sy < 304), 0, c[..., 3])
    m = np.clip((44 - np.sqrt((sx - 500) ** 2 + (sy - 245) ** 2)) / 10, 0, 1) * (c[..., 3] > 0)
    d = np.roll(c, (-round(5 * k), round(280 * k)), axis=(0, 1))
    for i in range(3):
        c[..., i] = c[..., i] * (1 - m) + d[..., i] * m
    c = c.astype(np.uint8)
    ys, xs = np.where(c[..., 3] > 20)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    Image.fromarray(c[y0:y1, x0:x1]).save(os.path.join(ROOT, "art", "props", "hk_kegs.png"))
    print("kegs still", (x1 - x0, y1 - y0), "ANIM_W %.3f ANIM_X0 %.3f foot gap %d" % ((x1 - x0) / cw, x0 / cw, c.shape[0] - y1))


# A free-standing thing (not cut out of a street drawing: placed by gen/levels.py Chunk.prop, docks and on) stands as
# its animation's first cell: the bullet (a loose bit) dropped - only the biggest piece kept - and the spark's bright
# yellow filled from the iron round it. props.gd ANIM_W/ANIM_X0 from the numbers printed.
def still(kind):
    a = np.asarray(Image.open(os.path.join(ROOT, "art", "props", f"hk_{kind}_anim.png"))).copy()
    cw = a.shape[1] // 6
    c = a[:, :cw].copy()
    lab, n = ndimage.label(c[..., 3] > 40)
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        c[..., 3] = np.where(lab == np.argmax(sizes) + 1, c[..., 3], 0)
    r, g, b = [c[..., i].astype(float) for i in range(3)]
    spark = ndimage.binary_dilation((((r > 170) & (g > 150) & (b < 0.7 * g)) | ((g > r + 18) & (g > b + 18)) | ((r + g + b) / 3 > 215)) & (c[..., 3] > 0), iterations=2) & (c[..., 3] > 0)   # (yellow or white spark, green spill)
    ok = (~spark) & (c[..., 3] > 0)
    for i in range(3):
        ch = c[..., i].astype(float)
        num = ndimage.uniform_filter(np.where(ok, ch, 0), 15)
        den = ndimage.uniform_filter(ok.astype(float), 15)
        c[..., i] = np.where(spark, np.clip(num / np.maximum(den, 1e-3), 0, 255), ch).astype(np.uint8)
    ys, xs = np.where(c[..., 3] > 20)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    Image.fromarray(c[y0:y1, x0:x1]).save(os.path.join(ROOT, "art", "props", f"hk_{kind}.png"))
    print(kind, "still", (x1 - x0, y1 - y0), "ANIM_W %.3f ANIM_X0 %.3f foot gap %d spark px %d" % ((x1 - x0) / cw, x0 / cw, c.shape[0] - y1, spark.sum()))


# The zip line's two ends (art_src 240, user 17. 11.: "a cable tied to a barrel on the ground is random – it wants an
# object of its own, a mast or so"): a timber mast with a pulley block on top (the cable runs over its wheel) and an
# iron hand winch on a skid (the cable wound on its drum). Cut apart on the green, left to right.
def cut_pair(f, names):
    a = np.asarray(Image.open(os.path.join(SRC, f)).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] -= np.maximum(g - np.maximum(r, b), 0) * (1 - alpha * 0.5)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    lab, n = ndimage.label(ndimage.binary_dilation(alpha > 0.5, iterations=6))   # (a thin cable stays with its winch)
    objs = sorted([(sl[1].start, i + 1, sl) for i, sl in enumerate(ndimage.find_objects(lab)) if (lab[sl] == i + 1).sum() > 20000])
    for name, (_, idx, sl) in zip(names, objs):
        piece = rgba[sl].copy()
        piece[..., 3] = np.where(lab[sl] == idx, piece[..., 3], 0)
        if name == "zip_winch":   # its painted loose cable off: the game draws the taut one from the drum's top
            h, w = piece.shape[:2]
            piece[: int(h * 0.262), : int(w * 0.53), 3] = 0   # everything above the drum's top, left of the frame
        im = Image.fromarray(piece)
        im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
        im.save(os.path.join(ROOT, "art", "props", f"{name}.png"))
        print(name, im.size)


# Laundry for the washing line (art_src 243): eight pieces on green in two rows, each hung from its top edge (clothespins)
# -> art/props/laundry_0..7.png, read row by row; props pin them along the line by the top middle.
def cut_set(f, prefix, rows=2):
    a = np.asarray(Image.open(os.path.join(SRC, f)).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] -= np.maximum(g - np.maximum(r, b), 0) * (1 - alpha * 0.5)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    lab, n = ndimage.label(ndimage.binary_dilation(alpha > 0.5, iterations=4))
    objs = [(sl, i + 1) for i, sl in enumerate(ndimage.find_objects(lab)) if (lab[sl] == i + 1).sum() > 8000]
    H = a.shape[0]
    objs.sort(key=lambda o: (int(o[0][0].start > H / rows), o[0][1].start))
    for k, (sl, idx) in enumerate(objs):
        piece = rgba[sl].copy()
        piece[..., 3] = np.where(lab[sl] == idx, piece[..., 3], 0)
        im = Image.fromarray(piece)
        im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
        im.save(os.path.join(ROOT, "art", "props", f"{prefix}_{k}.png"))
    print(prefix, len(objs), "pieces")


# The Blue Note's bar counter (art_src 246, user 17. 11.: "the bar should run along the room, not stand into the
# depth"): drawn on green in front elevation, stood in the club room in front of its painted back bar (art_src 245
# is the room without one). Its top is a floor (style "bar") he dives onto and skids along. Prints where the top is.
def cut_one(f, name, scale=0.5):
    a = np.asarray(Image.open(os.path.join(SRC, f)).convert("RGB")).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    alpha = ndimage.grey_opening(1 - np.clip((g - np.maximum(r, b) - 40) / 50, 0, 1), size=(3, 3))
    a[..., 1] = np.minimum(a[..., 1], (a[..., 0] + a[..., 2]) / 2 + 6)
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    lab, n = ndimage.label(ndimage.binary_dilation(alpha > 0.5, iterations=6))
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    keep = lab == (np.argmax(sizes) + 1)
    ys, xs = np.where(keep & (alpha > 0.5))
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    piece = rgba[y0:y1, x0:x1].copy()
    piece[..., 3] = np.where(keep[y0:y1, x0:x1], piece[..., 3], 0)
    rows = (piece[..., 3] > 128).mean(axis=1)   # the counter's top: the first row solid across most of the width
    top = int(np.argmax(rows > 0.8))
    im = Image.fromarray(piece)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    im.save(os.path.join(ROOT, "art", "props", f"{name}.png"))
    print(name, im.size, "top of the counter at %.3f of its height" % (top / piece.shape[0]))


if __name__ == "__main__" and os.path.exists(os.path.join(SRC, "246.jpg")):
    cut_one("246.jpg", "bar_counter")
# The street's steam comes out of a manhole (art_src 247, user 17. 11.: "steam out of the middle of the pavement -
# there should be a manhole or something"): main.gd puts one under every plume.
if __name__ == "__main__" and os.path.exists(os.path.join(SRC, "247.jpg")):
    cut_one("247.jpg", "manhole", 0.35)


if __name__ == "__main__" and os.path.exists(os.path.join(SRC, "243.jpg")):
    cut_set("243.jpg", "laundry")


if __name__ == "__main__" and os.path.exists(os.path.join(SRC, "240.jpg")):
    cut_pair("240.jpg", ["zip_mast", "zip_winch"])
