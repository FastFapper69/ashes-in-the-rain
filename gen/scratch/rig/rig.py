import math, json, numpy as np
from PIL import Image
from key import keyed, parts, cut
SRC_PPM = 1000.0          # the sheet is drawn at about 1000 px per metre
OUT_PPM = 300.0
img = keyed('04.jpg'); bx, lab = parts(img, 950)
box = {'head': bx[0], 'torso': bx[1], 'uarm': bx[4], 'farm': bx[5], 'thigh': bx[6], 'shin': bx[8]}
# joints inside each part, as fractions of its box: a = where it hangs from, b = where the next part hangs
PIV = {'head': ((0.45, 0.93), (0.45, 0.2)), 'torso': ((0.50, 0.90), (0.48, 0.07)), 'uarm': ((0.52, 0.16), (0.45, 0.86)),
       'farm': ((0.17, 0.12), (0.74, 0.74)), 'thigh': ((0.33, 0.13), (0.66, 0.87)), 'shin': ((0.24, 0.09), (0.30, 0.86))}
P = {}
for k, b in box.items():
    im = cut(img, lab, b); w, h = im.size
    a = (PIV[k][0][0] * w, PIV[k][0][1] * h); c = (PIV[k][1][0] * w, PIV[k][1][1] * h)
    P[k] = {'im': im, 'a': a, 'b': c, 'len': math.dist(a, c) / SRC_PPM, 'ang': math.atan2(c[1] - a[1], c[0] - a[0])}
    im.save(f'part_{k}.png')
gun = keyed('06.jpg'); gb, gl = parts(gun); pistol = cut(gun, gl, gb[3]); pistol.save('part_pistol.png')

def place(canvas, part, A, B, dark=False, flip=False):
    """draw a part so its joint a sits on A and it points towards B (world metres)"""
    p = P[part]; s = OUT_PPM / SRC_PPM
    th = math.atan2(B[1] - A[1], B[0] - A[0]) - p['ang']
    c, sn = math.cos(-th) / s, math.sin(-th) / s
    ax, ay = A[0] * OUT_PPM + OX, A[1] * OUT_PPM + OY
    # output pixel -> input pixel
    M = (c, -sn, p['a'][0] - c * ax + sn * ay, sn, c, p['a'][1] - sn * ax - c * ay)
    layer = p['im'].transform(canvas.size, Image.AFFINE, M, resample=Image.BICUBIC)
    if dark:
        arr = np.asarray(layer).astype(np.float32); arr[..., :3] *= 0.55; layer = Image.fromarray(arr.astype(np.uint8), 'RGBA')
    canvas.alpha_composite(layer)

def ik(a, t, l1, l2, bend):
    dx, dy = t[0] - a[0], t[1] - a[1]; d = min(max(math.hypot(dx, dy), 1e-4), l1 + l2 - 1e-4)
    k = (l1 * l1 - l2 * l2 + d * d) / (2 * d); h = math.sqrt(max(0, l1 * l1 - k * k))
    ux, uy = dx / math.hypot(dx, dy), dy / math.hypot(dx, dy)
    return (a[0] + ux * k - uy * h * bend, a[1] + uy * k + ux * h * bend), (a[0] + ux * d, a[1] + uy * d)

def pose(canvas, x, kind, phase=0.0, aim=(1, 0)):
    global OX; OX = x
    L1, L2, U, Fa, T = P['thigh']['len'], P['shin']['len'], P['uarm']['len'], P['farm']['len'], P['torso']['len']
    leg = (L1 + L2) * 0.96
    if kind == 'run':
        th = phase * 2 * math.pi
        fa = (0.42 * math.cos(th), -max(0, math.sin(th)) * 0.3); fb = (0.42 * math.cos(th + math.pi), -max(0, math.sin(th + math.pi)) * 0.3)
        hip = (0.0, -leg + 0.07 * abs(math.cos(th)) + 0.02); lean = 0.16
    else:
        fa, fb = (-0.16, 0.0), (0.14, 0.0); hip = (0.0, -leg + 0.02); lean = 0.04
    neck = (hip[0] + lean, hip[1] - T)
    sh = (neck[0] - 0.01, neck[1] + 0.11)
    ank = 0.09
    def legdraw(f, dark):
        knee, foot = ik(hip, (f[0], f[1] - ank), L1, L2, -1); place(canvas, 'thigh', hip, knee, dark); place(canvas, 'shin', knee, foot, dark)
    def armdraw(target, dark):
        el, hand = ik(sh, target, U, Fa, 1); place(canvas, 'uarm', sh, el, dark); place(canvas, 'farm', el, hand, dark); return hand
    l = math.hypot(*aim); ax, ay = aim[0] / l, aim[1] / l
    armdraw((sh[0] + ax * 0.5 + 0.06, sh[1] + ay * 0.5 + 0.05) if kind != 'run' else (hip[0] - 0.25 * math.cos(phase * 2 * math.pi), hip[1] + 0.05), True)
    legdraw(fb, True); legdraw(fa, False)
    place(canvas, 'torso', hip, neck)
    place(canvas, 'head', (neck[0], neck[1] + 0.03), (neck[0] + 0.02, neck[1] - 0.3))
    hand = armdraw((sh[0] + ax * 0.55, sh[1] + ay * 0.55), False)
    g = pistol.resize((round(pistol.width * 0.11), round(pistol.height * 0.11)), Image.LANCZOS).rotate(-math.degrees(math.atan2(ay, ax)), expand=True, resample=Image.BICUBIC)
    canvas.alpha_composite(g, (round(hand[0] * OUT_PPM + OX - g.width / 2 + ax * 30), round(hand[1] * OUT_PPM + OY - g.height / 2 + ay * 30)))

OX, OY = 0, 640
cv = Image.new('RGBA', (2100, 720), (70, 74, 80, 255))
pose(cv, 180, 'stand'); pose(cv, 520, 'stand', aim=(1, -0.8)); pose(cv, 860, 'stand', aim=(0.6, 0.8))
for i in range(3): pose(cv, 1240 + i * 320, 'run', phase=i / 6 + 0.05)
cv.convert('RGB').save('preview_mobster.png')
json.dump({k: {'a': v['a'], 'b': v['b'], 'len': v['len'], 'size': v['im'].size} for k, v in P.items()}, open('rig_mobster.json', 'w'), indent=1)
print({k: round(v['len'], 3) for k, v in P.items()})
