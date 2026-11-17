import math, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi
import key, seg
OUT_PPM = 300.0
SRC = '/mnt/user-data/uploads/Ashes in the Rain/art_src/'
def white_part(img, box):
    c = img[box[1]:box[3], box[0]:box[2]].copy()
    lab, n = ndi.label(c[..., 3] > 40); sizes = ndi.sum(c[..., 3] > 40, lab, range(1, n + 1)); keep = 1 + int(np.argmax(sizes))
    c[..., 3] = np.where(lab == keep, c[..., 3], 0); return Image.fromarray(c, 'RGBA')
mob = key.keyed('04.jpg'); mb, ml = key.parts(mob, 950)
det = seg.rgba(SRC + '04_v2.jpg')
def M(i): return key.cut(mob, ml, mb[i])
CH = {
 'mobster': {'head': (M(0), (0.45, 0.93), (0.45, 0.2), 1000), 'torso': (M(1), (0.50, 0.90), (0.48, 0.07), 1000), 'uarm': (M(4), (0.52, 0.16), (0.45, 0.86), 1000),
             'farm': (M(5), (0.17, 0.12), (0.74, 0.74), 1000), 'thigh': (M(6), (0.33, 0.13), (0.66, 0.87), 1000), 'shin': (M(8), (0.24, 0.09), (0.30, 0.86), 1000)},
 'detective': {'head': (white_part(det, (170, 58, 594, 478)), (0.42, 0.93), (0.42, 0.2), 1100), 'torso': (white_part(det, (699, 62, 1230, 1376)), (0.45, 0.52), (0.50, 0.05), 1100),
               'uarm': (white_part(det, (1494, 106, 1786, 540)), (0.40, 0.15), (0.45, 0.90), 1100), 'farm': (white_part(det, (1397, 900, 1767, 1416)), (0.25, 0.15), (0.72, 0.80), 1100),
               'tail': (white_part(det, (2081, 121, 2483, 670)), (0.55, 0.08), (0.55, 0.95), 1100), 'thigh': (M(6), (0.33, 0.13), (0.66, 0.87), 1000), 'shin': (M(8), (0.24, 0.09), (0.30, 0.86), 1000)},
}
gun = key.keyed('06.jpg'); gb, gl = key.parts(gun); GUNS = {'pistol': key.cut(gun, gl, gb[3]), 'revolver': key.cut(gun, gl, gb[1])}
data = {}
import os
for name, parts in CH.items():
    os.makedirs(f'out/{name}', exist_ok=True); data[name] = {}
    for k, (im, a, b, ppm) in parts.items():
        im.save(f'out/{name}/{k}.png'); w, h = im.size
        data[name][k] = {'a': [round(a[0] * w, 1), round(a[1] * h, 1)], 'b': [round(b[0] * w, 1), round(b[1] * h, 1)], 'ppm': ppm}
for g, im in GUNS.items(): im.save(f'out/{g}.png'); print(g, im.size)
json.dump(data, open('out/rig.json', 'w'))

def render(name, gunname, flipgun):
    parts = CH[name]; P = {}
    for k, (im, a, b, ppm) in parts.items():
        w, h = im.size; pa = (a[0] * w, a[1] * h); pb = (b[0] * w, b[1] * h)
        P[k] = dict(im=im, a=pa, ang=math.atan2(pb[1] - pa[1], pb[0] - pa[0]), len=math.dist(pa, pb) / ppm, s=OUT_PPM / ppm)
    cv = Image.new('RGBA', (2100, 760), (70, 74, 80, 255)); OY = 680
    def place(part, A, B, ox, dark=False):
        p = P[part]; th = math.atan2(B[1] - A[1], B[0] - A[0]) - p['ang']; c, sn = math.cos(-th) / p['s'], math.sin(-th) / p['s']
        ax, ay = A[0] * OUT_PPM + ox, A[1] * OUT_PPM + OY
        layer = p['im'].transform(cv.size, Image.AFFINE, (c, -sn, p['a'][0] - c * ax + sn * ay, sn, c, p['a'][1] - sn * ax - c * ay), resample=Image.BICUBIC)
        if dark: arr = np.asarray(layer).astype(np.float32); arr[..., :3] *= 0.55; layer = Image.fromarray(arr.astype(np.uint8), 'RGBA')
        cv.alpha_composite(layer)
    def ik(a, t, l1, l2, bend):
        dx, dy = t[0] - a[0], t[1] - a[1]; dd = math.hypot(dx, dy); d = min(max(dd, 1e-4), l1 + l2 - 1e-4); ux, uy = dx / dd, dy / dd
        k = (l1 * l1 - l2 * l2 + d * d) / (2 * d); h = math.sqrt(max(0, l1 * l1 - k * k))
        return (a[0] + ux * k - uy * h * bend, a[1] + uy * k + ux * h * bend), (a[0] + ux * d, a[1] + uy * d)
    def pose(ox, t, phase, aim):
        L1, L2, U, Fa, T = P['thigh']['len'], P['shin']['len'], P['uarm']['len'], P['farm']['len'], P['torso']['len']
        th = phase * 2 * math.pi; lerp = lambda a, b: a + (b - a) * t
        fa = (lerp(-0.16, 0.42 * math.cos(th)), lerp(0, -max(0, math.sin(th)) * 0.3)); fb = (lerp(0.14, 0.42 * math.cos(th + math.pi)), lerp(0, -max(0, math.sin(th + math.pi)) * 0.3))
        hip = (0.0, -(L1 + L2) * 0.985 - 0.09 + lerp(0.01, 0.07 * abs(math.cos(th)) + 0.03)); neck = (hip[0] + lerp(0.03, 0.15), hip[1] - T); sh = (neck[0] - 0.05, neck[1] + 0.11)
        l = math.hypot(*aim); ax, ay = aim[0] / l, aim[1] / l
        far = (lerp(sh[0] + ax * 0.5 + 0.06, hip[0] - 0.25 * math.cos(th)), lerp(sh[1] + ay * 0.5 + 0.05, hip[1] + 0.05))
        e, hnd = ik(sh, far, U, Fa, 1); place('uarm', sh, e, ox, True); place('farm', e, hnd, ox, True)
        if 'tail' in P: place('tail', (hip[0] - 0.08, hip[1] - 0.05), (hip[0] - 0.08 - lerp(0.05, 0.45), hip[1] + 0.5), ox)
        for f, dk in ((fb, True), (fa, False)):
            kn, ft = ik(hip, (f[0], f[1] - 0.09), L1, L2, -1); place('thigh', hip, kn, ox, dk); place('shin', kn, ft, ox, dk)
        place('torso', hip, neck, ox); place('head', (neck[0], neck[1] + 0.03), (neck[0] + 0.02, neck[1] - 0.3), ox)
        g = GUNS[gunname]; g = g.transpose(Image.FLIP_LEFT_RIGHT) if flipgun else g
        e, hnd = ik(sh, (sh[0] + ax * 0.55, sh[1] + ay * 0.55), U, Fa, 1)
        gs = g.resize((round(g.width * 0.11), round(g.height * 0.11)), Image.LANCZOS).rotate(-math.degrees(math.atan2(ay, ax)), expand=True, resample=Image.BICUBIC)
        cv.alpha_composite(gs, (round(hnd[0] * OUT_PPM + ox - gs.width / 2 + ax * 28), round(hnd[1] * OUT_PPM + OY - gs.height / 2 + ay * 28 - 8)))
        place('uarm', sh, e, ox); place('farm', e, hnd, ox)
    pose(190, 0, 0, (1, 0)); pose(540, 0, 0, (1, -0.8)); pose(880, 0, 0, (0.6, 0.8))
    for i in range(3): pose(1250 + i * 320, 1, i / 6 + 0.05, (1, 0))
    cv.convert('RGB').save(f'preview_{name}.png')
render('detective', 'revolver', False); render('mobster', 'pistol', True)
print(json.dumps(data))
