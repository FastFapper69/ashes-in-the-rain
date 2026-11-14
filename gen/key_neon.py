"""Neon layers for the menu's painted key art. The red neon and everything it lights (the wet street,
the kerb) is painted into the picture, so it can't flicker by itself. From each picture this cuts:
  key_N_glow.png  the red light's own shape, blurred, laid on additively while the tube is lit
  key_N_off.png   the same pixels dark and grey, laid over the picture when the tube cuts out
so the sign, its halo and its reflection on the street all go dark together."""
from PIL import Image, ImageFilter
import numpy as np, sys

REGIONS = {78: (0.40, 0.40, 0.80, 1.0), 79: (0.55, 0.72, 0.72, 0.92), 80: (0.43, 0.36, 0.56, 0.55)}
# The lamps: the painted bulb and the cone under it, cut out the same way so the glow has their shape.
LAMPS = {78: [(0.70, 0.0, 0.90, 0.55)], 79: [(0.44, 0.40, 0.56, 0.80)], 80: [(0.65, 0.15, 0.76, 0.42)]}


def warm_mask(crop):
    hsv = np.asarray(crop.convert('HSV')).astype(float)
    h, s, v = hsv[..., 0], hsv[..., 1] / 255, hsv[..., 2] / 255
    hue = np.clip(1 - np.abs(h - 28) / 22, 0, 1)   # amber to yellow
    return hue * np.clip((s - 0.18) / 0.2, 0, 1) * np.clip((v - 0.45) / 0.3, 0, 1) * v


def build_lamp(root, k, i, box):
    src = Image.open(f'{root}/art/ui/key_{k}.jpg').convert('RGB')
    W, H = src.size
    x0, y0, x1, y1 = box
    crop = src.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
    core = Image.fromarray((np.clip(warm_mask(crop) * 1.4, 0, 1) * 255).astype('uint8'))
    near = np.asarray(core.filter(ImageFilter.GaussianBlur(4))).astype(float)
    far = np.asarray(core.filter(ImageFilter.GaussianBlur(20))).astype(float)
    glow = Image.new('RGBA', crop.size, (255, 255, 255, 0))
    glow.putalpha(Image.fromarray(np.clip(near * 0.8 + far * 1.2, 0, 255).astype('uint8')))
    glow.resize((crop.width // 2, crop.height // 2), Image.LANCZOS).save(f'{root}/art/ui/key_{k}_lamp{i}.png')

def red_mask(crop):
    hsv = np.asarray(crop.convert('HSV')).astype(float)
    h, s, v = hsv[..., 0], hsv[..., 1] / 255, hsv[..., 2] / 255
    hue = np.clip(1 - np.minimum(h, 255 - h) / 14, 0, 1)
    return hue * np.clip((s - 0.4) / 0.25, 0, 1) * np.clip((v - 0.12) / 0.15, 0, 1), v

def build(root, k):
    src = Image.open(f'{root}/art/ui/key_{k}.jpg').convert('RGB')
    W, H = src.size
    x0, y0, x1, y1 = REGIONS[k]
    crop = src.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
    m, v = red_mask(crop)
    rgb = np.asarray(crop).astype(float)
    grey = rgb.mean(axis=2, keepdims=True) * np.array([0.42, 0.40, 0.40])   # an unlit tube, wet stone with no light on it
    am = Image.fromarray((m * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.5))
    off = Image.fromarray(np.clip(grey, 0, 255).astype('uint8').repeat(3, axis=2) if grey.shape[2] == 1 else np.clip(grey, 0, 255).astype('uint8'))
    off.putalpha(am)
    off.save(f'{root}/art/ui/key_{k}_off.png')
    core = np.clip(m * v * 1.6, 0, 1)
    # the brightest red is the tube itself; what's lit by it (wet street, kerb) only gets a faint lift
    tube = np.clip((v - 0.55) / 0.25, 0, 1)
    ci = Image.fromarray((core * 255).astype('uint8'))
    ti = Image.fromarray((core * tube * 255).astype('uint8'))
    near = np.asarray(ci.filter(ImageFilter.GaussianBlur(4))).astype(float)
    far = np.asarray(ti.filter(ImageFilter.GaussianBlur(24))).astype(float)
    a = np.clip(near * 0.35 + far * 2.4, 0, 255).astype('uint8')
    glow = Image.new('RGBA', crop.size, (255, 255, 255, 0))
    glow.putalpha(Image.fromarray(a))
    glow = glow.resize((crop.width // 2, crop.height // 2), Image.LANCZOS)   # soft anyway: half size is plenty
    glow.save(f'{root}/art/ui/key_{k}_glow.png')

if __name__ == '__main__':
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    for k in REGIONS:
        build(root, k)
    for k, boxes in LAMPS.items():
        for i, b in enumerate(boxes):
            build_lamp(root, k, i, b)
