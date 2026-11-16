"""The layered title screen and the paper controls.
  art/ui/key_86.jpg (+_glow, _off)  the street with nobody in it (art_src/86.jpg) and its neon layers
  art/ui/menu/frank.png             the detective and his lamp post, cut out and graded for the night
  art/ui/menu/frank_glow.png        the lantern's own light, in the lantern's shape
  art/ui/paper/*.png                the paper controls and comic lettering shapes, at the size they are used"""
import os, sys
import numpy as np
from PIL import Image, ImageFilter, ImageChops
sys.path.insert(0, 'gen')
import cut_props, key_neon
from paths import SRC
os.makedirs('art/ui/menu', exist_ok=True); os.makedirs('art/ui/paper', exist_ok=True)
TMP = '/tmp/menu_cut'; os.makedirs(TMP, exist_ok=True)

plate = Image.open(SRC + '86.jpg').convert('RGB').resize((2400, 1018), Image.LANCZOS)
plate.save('art/ui/key_86.jpg', quality=90)
key_neon.REGIONS = {86: (0.40, 0.42, 0.66, 1.0)}
key_neon.build('.', 86)

cut_props.cut(SRC + '87.jpg', ['frank'], TMP)
f = Image.open(TMP + '/frank.png').convert('RGBA')
a = np.asarray(f).astype(float); H, W = a.shape[:2]
yy, xx = np.mgrid[0:H, 0:W]
lx, ly = W * 0.83, H * 0.105                       # the lantern
d = np.sqrt((xx - lx) ** 2 + ((yy - ly) * 0.8) ** 2) / H
light = 0.34 + 0.75 * np.exp(-d / 0.16)            # lit near the lamp, lost in the dark at his knees
light *= np.clip(0.75 + 0.5 * (xx / W), 0.7, 1.2)  # the side toward the lamp catches more
lantern = np.clip(1 - np.sqrt(((xx - lx) / (W * 0.14)) ** 2 + ((yy - ly) / (H * 0.085)) ** 2), 0, 1) ** 0.5
k = np.clip(light, 0, 1.0)
rgb = a[..., :3] * k[..., None] * np.array([1.0, 0.93, 0.84])
rgb = rgb * (1 - lantern[..., None]) + a[..., :3] * lantern[..., None]
g = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a[..., 3]]).astype('uint8'), 'RGBA')
g = g.resize((round(W * 1300 / H), 1300), Image.LANCZOS)
g.save('art/ui/menu/frank.png')
top = f.crop((int(W * 0.6), 0, W, int(H * 0.26)))
core = Image.fromarray((np.clip(key_neon.warm_mask(top.convert('RGB')) * 1.5, 0, 1) * 255).astype('uint8'))
near = np.asarray(core.filter(ImageFilter.GaussianBlur(10))).astype(float)
far = np.asarray(core.filter(ImageFilter.GaussianBlur(70))).astype(float)
glow = Image.new('RGBA', top.size, (255, 255, 255, 0))
glow.putalpha(Image.fromarray(np.clip(near * 0.6 + far * 1.6, 0, 255).astype('uint8')))
glow.resize((top.width // 3, top.height // 3), Image.LANCZOS).save('art/ui/menu/frank_glow.png')
print('frank', g.size)

cut_props.cut(SRC + '88.jpg', ['clip_full', 'folder_full', 'tape', 'tag'], TMP)
cut_props.cut(SRC + '89.jpg', ['cap_full', 'balloon', 'burst', 'strip_full'], TMP)
c = Image.open(TMP + '/clip_full.png'); cw, chh = c.size
h = int(chh * 0.4); clip = c.crop((0, 0, cw, h)); eh = int(chh * 0.05)
al = clip.getchannel('A'); al.paste(ImageChops.multiply(al.crop((0, h - eh, cw, h)), c.crop((0, chh - eh, cw, chh)).getchannel('A')), (0, h - eh)); clip.putalpha(al)
out = {'clip': clip, 'folder': Image.open(TMP + '/folder_full.png').rotate(90, expand=True), 'tape': Image.open(TMP + '/tape.png'),
       'tag': Image.open(TMP + '/tag.png'), 'caption': Image.open(TMP + '/cap_full.png').rotate(90, expand=True),
       'balloon': Image.open(TMP + '/balloon.png'), 'burst': Image.open(TMP + '/burst.png'), 'strip': Image.open(TMP + '/strip_full.png').rotate(90, expand=True)}
for n, im in out.items():
    im = im.resize((640, round(im.height * 640 / im.width)), Image.LANCZOS)
    im.save(f'art/ui/paper/{n}.png'); print(n, im.size)
