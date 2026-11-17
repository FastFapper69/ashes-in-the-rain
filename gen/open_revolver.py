"""The open revolver in parts, worn/new x loaded/empty (rule 28, user 17. 11.: "closed it is the new cylinder and opened
it is the old one again; after the rounds are dumped it does not show the empty cylinder").
Four drawings of the same open gun: art/ui/gunsmith/revolver_open.png (new, loaded - the frame everything is
registered onto), art_src 281 (new, empty), 273 (worn, loaded), 272 (worn, empty): Gemini edits, white background.
Each is keyed, registered onto the frame (scale + shift, matched on the picture), and cut by one map of parts (frame,
barrel, grip, cylinder - the swung-out cylinder with its crane and rod), so any mix of worn and new parts lines up:
art/ui/gunsmith/open/<part>_<new|worn>[_<loaded|empty>].png, cropped; offsets printed for menu.gd SMITH_OPEN.
Run: py gen/open_revolver.py"""
import os
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from paths import SRC, REPO

GS = os.path.join(REPO, "art/ui/gunsmith")
ref = Image.open(os.path.join(GS, "revolver_open.png")).convert("RGBA")
W, H = ref.size
ref_a = np.asarray(ref).astype(np.float32)
ref_g = (ref_a[..., :3].mean(2) * (ref_a[..., 3] / 255.0) + 255.0 * (1 - ref_a[..., 3] / 255.0))


def key_white(im):
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    alpha = np.clip((250.0 - a.min(2)) / 22.0, 0.0, 1.0)
    return np.dstack([a, alpha * 255]).astype(np.uint8)


def onto_frame(src):
    """Gemini's drawing scaled and shifted onto the frame: coarse by the silhouette, then fine by the picture."""
    rgba = Image.fromarray(key_white(Image.open(SRC + src)), "RGBA")
    m = np.asarray(rgba)[..., 3] > 128
    rm = ref_a[..., 3] > 128
    ys, xs = np.nonzero(m)
    rys, rxs = np.nonzero(rm)
    k0 = ((rxs.max() - rxs.min()) / (xs.max() - xs.min()) + (rys.max() - rys.min()) / (ys.max() - ys.min())) / 2
    best = None
    for k in np.arange(k0 - 0.012, k0 + 0.0121, 0.003):
        s = rgba.resize((int(rgba.width * k), int(rgba.height * k)), Image.LANCZOS)
        sa = np.asarray(s).astype(np.float32)
        sg = sa[..., :3].mean(2) * (sa[..., 3] / 255.0) + 255.0 * (1 - sa[..., 3] / 255.0)
        ox0 = int(round(rxs.min() - xs.min() * k))
        oy0 = int(round(rys.min() - ys.min() * k))
        for dy in range(-10, 11):
            for dx in range(-10, 11):
                ox, oy = ox0 + dx, oy0 + dy
                c = np.full((H, W), 255.0, np.float32)
                x0, y0 = max(0, ox), max(0, oy)
                x1, y1 = min(W, ox + sg.shape[1]), min(H, oy + sg.shape[0])
                c[y0:y1, x0:x1] = sg[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
                e = float(np.abs(c[::3, ::3] - ref_g[::3, ::3]).mean())
                if best is None or e < best[0]:
                    best = (e, k, ox, oy)
    e, k, ox, oy = best
    s = rgba.resize((int(rgba.width * k), int(rgba.height * k)), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.alpha_composite(s, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
    print(src, "err", round(e, 2), "k", round(k, 4), "at", ox, oy)
    return np.asarray(canvas)


# the map of parts on the frame (open drawing's px)
def poly(pts):
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return np.asarray(m) > 0


cyl = poly([(462, 205), (728, 205), (728, 282), (962, 282), (962, 352), (728, 352), (728, 415), (462, 415)])
barrel = poly([(796, 40), (1295, 40), (1295, 215), (796, 215)]) & ~cyl
grip = poly([(232, 288), (338, 318), (345, 365), (305, 635), (75, 640), (95, 520), (140, 390)]) & ~cyl
frame = ~(cyl | barrel | grip)
PARTS = {"frame": frame, "barrel": barrel, "grip": grip, "cylinder": cyl}

VARIANTS = {("new", "loaded"): None, ("new", "empty"): "281.jpg", ("worn", "loaded"): "273.jpg", ("worn", "empty"): "272.jpg"}
pics = {}
for v, src in VARIANTS.items():
    pics[v] = np.asarray(ref) if src is None else onto_frame(src)

os.makedirs(os.path.join(GS, "open"), exist_ok=True)
offsets = {}
for part, m in PARTS.items():
    soft = ndimage.binary_dilation(m, iterations=2)   # (a hair of overlap: no gap shows between two parts)
    for v, pic in pics.items():
        if part != "cylinder" and v[1] == "empty":
            continue   # (only the cylinder is ever empty)
        name = f"{part}_{v[0]}" + (f"_{v[1]}" if part == "cylinder" else "")
        out = pic.copy()
        out[..., 3] = np.where(soft, out[..., 3], 0)
        # (rule 28: the same part looks the same open and closed - its colours matched to the closed part's drawing)
        closed = np.asarray(Image.open(os.path.join(GS, "parts", f"revolver_{part}_{v[0]}.png")).convert("RGBA")).astype(np.float32)
        cm = closed[..., 3] > 200
        om = (out[..., 3] > 200) & ~((part == "cylinder") & (out[..., 0].astype(np.float32) - out[..., 2] > 45))   # (not the brass)
        o = out.astype(np.float32)
        for ch in range(3):
            mu_o, sd_o = o[..., ch][om].mean(), o[..., ch][om].std() + 1e-3
            mu_c, sd_c = closed[..., ch][cm].mean(), closed[..., ch][cm].std()
            o[..., ch] = np.where(om, (o[..., ch] - mu_o) * (sd_c / sd_o) + mu_c, o[..., ch])
        out = o.clip(0, 255).astype(np.uint8)
        ys, xs = np.nonzero(out[..., 3] > 0)
        x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        Image.fromarray(out[y0:y1, x0:x1], "RGBA").save(os.path.join(GS, "open", name + ".png"))
        offsets[name] = [int(x0), int(y0)]
print(json.dumps(offsets))
