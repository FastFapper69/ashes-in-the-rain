"""Every notebook page its own: from each map's diary text this makes
  art/ui/pages/<chapter>_<map>.png   the page as read (paper torn, tinted, folded its own way)
  art/items/notes/<chapter>_<map>.png  the same page small, with its first lines in Eddie's hand
so no two pages in the game are the same sheet. Run from the project folder."""
import re, random, textwrap
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

STAINS = ['art/fx/stain_spray1.png', 'art/fx/stain_spray2.png', 'art/fx/stain_smear1.png', 'art/fx/stain_drip1.png', 'art/fx/stain_mist1.png']

def pages():
    s = open('levels.gd').read()
    chs = re.split(r'\n\t\{"title": ', s)[1:]
    for ci, ch in enumerate(chs):
        for mi, m in enumerate(re.split(r'\{"name": ', ch)[1:]):
            d = re.search(r'"diary": "((?:[^"\\]|\\.)*)"', m)
            if d and d.group(1):
                yield ci, mi, d.group(1).replace('\\"', '"').replace("\\'", "'")

def sheet(ci, mi, rnd):
    page = Image.open('art/ui/diary_page_clean.png').convert('RGBA')
    W, H = page.size
    if rnd.random() < 0.5:   # the coffee ring and the tears land elsewhere
        page = page.transpose(Image.FLIP_LEFT_RIGHT)
    a = np.asarray(page).astype(float)
    tint = np.array([rnd.uniform(0.9, 1.02), rnd.uniform(0.88, 0.98), rnd.uniform(0.8, 0.94)])   # older paper yellows
    a[..., :3] = np.clip(a[..., :3] * tint, 0, 255)
    page = Image.fromarray(a.astype('uint8'), 'RGBA')
    # a corner torn off (a jagged line across one corner), sometimes
    if rnd.random() < 0.6:
        al = page.getchannel('A')
        d = ImageDraw.Draw(al)
        cx = W if rnd.random() < 0.5 else 0
        pts = [(cx, H)]
        n = 9
        for k in range(n + 1):
            t = k / n
            x = cx + (-1 if cx else 1) * W * rnd.uniform(0.12, 0.22) * (1 - t)
            y = H - H * rnd.uniform(0.25, 0.4) * t
            pts.append((x + rnd.uniform(-8, 8), y + rnd.uniform(-8, 8)))
        pts.append((cx, H - H * 0.45))
        d.polygon(pts, fill=0)
        page.putalpha(al)
    # folded: a soft crease, once or twice
    fold = Image.new('RGBA', page.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(fold)
    for k in range(rnd.randint(1, 2)):
        if rnd.random() < 0.6:
            x = W * rnd.uniform(0.4, 0.6)
            fd.line([(x, 0), (x + rnd.uniform(-20, 20), H)], fill=(0, 0, 0, 55), width=6)
        else:
            y = H * rnd.uniform(0.4, 0.6)
            fd.line([(0, y), (W, y + rnd.uniform(-15, 15))], fill=(0, 0, 0, 55), width=6)
    page = Image.alpha_composite(page, fold.filter(ImageFilter.GaussianBlur(5)))
    return page

def blood(img, rnd, amount):
    W, H = img.size
    for k in range(amount):
        st = Image.open(rnd.choice(STAINS)).convert('RGBA')
        sz = int(H * rnd.uniform(0.3, 0.6))
        st = st.resize((sz, sz)).rotate(rnd.uniform(0, 360))
        lay = Image.new('RGBA', st.size, (rnd.randint(85, 120), 12, 10, 0))
        lay.putalpha(st.getchannel('A').point(lambda v: int(v * rnd.uniform(0.55, 0.85))))
        x = int(rnd.choice([rnd.uniform(-0.1, 0.25), rnd.uniform(0.6, 0.95)]) * W - sz / 2)
        y = int(rnd.uniform(0.3, 0.95) * H - sz / 2)
        layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
        layer.alpha_composite(lay, (max(-sz, min(W, x)), max(-sz, min(H, y)))) if 0 <= x < W and 0 <= y < H else layer.paste(lay, (x, y), lay)
        al = ImageChops.multiply(layer.getchannel('A'), img.getchannel('A'))   # only on the paper
        layer.putalpha(al)
        img = Image.alpha_composite(img, layer)
    return img

def main():
    font = ImageFont.truetype('fonts/ReenieBeanie.ttf', 92)
    import os
    os.makedirs('art/ui/pages', exist_ok=True)
    os.makedirs('art/items/notes', exist_ok=True)
    for ci, mi, text in pages():
        rnd = random.Random(hash(text) & 0xffffffff if False else sum(map(ord, text)) * 31 + ci * 7 + mi)
        page = sheet(ci, mi, rnd)
        page.save(f'art/ui/pages/{ci}_{mi}.png')   # the big one: diary.gd writes the text and stains on it
        small = page.copy()
        W, H = small.size
        d = ImageDraw.Draw(small)
        y = H * 0.2
        for line in textwrap.wrap(text, 26)[:5]:
            d.text((W * 0.17 + rnd.uniform(-6, 6), y), line, font=font, fill=(35, 35, 40, 255))
            y += H * 0.118
        small = blood(small, rnd, rnd.randint(1, 2))
        small = small.resize((300, int(300 * H / W)), Image.LANCZOS).filter(ImageFilter.UnsharpMask(1.2, 120, 2))
        small.save(f'art/items/notes/{ci}_{mi}.png')
        print(ci, mi, text[:40])

main()
