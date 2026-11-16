# Wall blood stains in the style of the existing blood sprites: flat crimson with a darker rim.
import random, math
from PIL import Image, ImageDraw, ImageFilter
from paths import REPO
OUT = REPO + 'art/fx/'
SS = 2
FILL = (118, 24, 19, 255)
RIM = (62, 8, 6, 255)

def finish(mask, name):
    mask = mask.filter(ImageFilter.GaussianBlur(1.6 * SS)).point(lambda v: 255 if v > 120 else 0)
    inner = mask.filter(ImageFilter.MinFilter(2 * (3 * SS) + 1))
    w, h = mask.size
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    out.paste(Image.new('RGBA', (w, h), RIM), (0, 0), mask)
    # slight tone variation inside, like the drawn splats
    tone = Image.effect_noise((w, h), 18).filter(ImageFilter.GaussianBlur(6 * SS))
    fill = Image.merge('RGBA', [tone.point(lambda v, c=c: max(0, min(255, c + (v - 128) // 4))) for c in FILL[:3]] + [Image.new('L', (w, h), 255)])
    out.paste(fill, (0, 0), inner)
    out = out.resize((w // SS, h // SS), Image.LANCZOS)
    out.save(OUT + name)
    print(name, out.size)

def blob(d, cx, cy, r, lumps=9):
    pts = []
    for i in range(lumps * 4):
        a = i / (lumps * 4) * math.tau
        rr = r * (0.8 + 0.25 * math.sin(a * lumps / 2 + random.random()) + random.uniform(-0.08, 0.08))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=255)

def streak(d, x, y, ang, length, width):
    # a drop flung along ang: thin tail behind, round head in front
    hx, hy = x + math.cos(ang) * length, y + math.sin(ang) * length
    n = 14
    for i in range(n + 1):
        t = i / n
        px, py = x + (hx - x) * t, y + (hy - y) * t
        r = width * (0.15 + 0.85 * t ** 1.6)
        d.ellipse([px - r, py - r, px + r, py + r], fill=255)

def spray(name, seed):   # exit spray: a burst at the left, drops flung out to the right in a cone
    random.seed(seed)
    W, H = 520 * SS, 300 * SS
    m = Image.new('L', (W, H), 0); d = ImageDraw.Draw(m)
    ox, oy = 90 * SS, H / 2
    blob(d, ox, oy, 38 * SS, 7)
    for i in range(46):
        ang = random.gauss(0, 0.32)
        dist = random.uniform(40, 400) * SS
        x, y = ox + math.cos(ang) * dist * 0.35, oy + math.sin(ang) * dist * 0.35
        streak(d, x, y, ang, dist * random.uniform(0.15, 0.4), max(2.5, (14 - dist / SS / 34)) * SS * random.uniform(0.6, 1.1))
    for i in range(70):   # fine mist
        ang = random.gauss(0, 0.45); dist = random.uniform(60, 470) * SS; r = random.uniform(1.6, 4) * SS
        x, y = ox + math.cos(ang) * dist, oy + math.sin(ang) * dist
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    finish(m, name)

def drips(name, seed):   # a splat high on the wall with runs dribbling down from it
    random.seed(seed)
    W, H = 300 * SS, 520 * SS
    m = Image.new('L', (W, H), 0); d = ImageDraw.Draw(m)
    cx, cy = W / 2, 95 * SS
    blob(d, cx, cy, 62 * SS, 8)
    for i in range(10):
        a = random.uniform(0, math.tau); r = random.uniform(70, 120) * SS
        rr = random.uniform(5, 12) * SS
        d.ellipse([cx + math.cos(a) * r - rr, cy + math.sin(a) * r * 0.8 - rr, cx + math.cos(a) * r + rr, cy + math.sin(a) * r * 0.8 + rr], fill=255)
    for i in range(random.randint(3, 5)):
        x = cx + random.uniform(-48, 48) * SS
        top = cy + 30 * SS
        bottom = top + random.uniform(120, 380) * SS
        w = random.uniform(5, 10) * SS
        y = top
        while y < bottom:
            ww = w * (0.85 + 0.3 * math.sin(y / (17 * SS)))
            d.ellipse([x - ww, y - ww, x + ww, y + ww], fill=255)
            x += random.uniform(-0.6, 0.6) * SS
            y += 2 * SS
        b = w * 1.7
        d.ellipse([x - b, bottom - b, x + b, bottom + b * 1.3], fill=255)
    finish(m, name)

def smear(name, seed):   # a hand or a body dragged along the wall: uneven strands fading into dry brush marks
    random.seed(seed)
    W, H = 560 * SS, 220 * SS
    m = Image.new('L', (W, H), 0); d = ImageDraw.Draw(m)
    y0 = H / 2
    for k in range(16):
        y = y0 + random.gauss(0, 26) * SS
        x0 = random.uniform(30, 90) * SS
        length = random.uniform(150, 470) * SS
        w = random.uniform(2.5, 11) * SS
        ph = random.uniform(0, 6)
        x = x0
        while x < x0 + length:
            t = (x - x0) / length
            ww = max(1.2 * SS, w * (1.0 - t * 0.85) * (0.8 + 0.3 * math.sin(x / (23 * SS) + ph)))
            if random.random() > t * 0.6:
                d.ellipse([x - ww, y - ww, x + ww, y + ww], fill=255)
            x += 2 * SS
            y += math.sin(x / (60 * SS) + ph) * 0.35 * SS
    blob(d, 70 * SS, y0, 46 * SS, 6)
    finish(m, name)

def mist(name, seed):   # a graze: no blob, only a fan of fine droplets
    random.seed(seed)
    W, H = 420 * SS, 300 * SS
    m = Image.new('L', (W, H), 0); d = ImageDraw.Draw(m)
    ox, oy = 50 * SS, H / 2
    for i in range(160):
        ang = random.gauss(0, 0.38); dist = abs(random.gauss(0, 170)) * SS + 10 * SS
        r = max(1.2 * SS, random.uniform(1.5, 6.5) * SS * (1.2 - dist / (420 * SS)))
        x, y = ox + math.cos(ang) * dist, oy + math.sin(ang) * dist
        if random.random() < 0.25:
            streak(d, x, y, ang, r * 5, r)
        else:
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    finish(m, name)

spray('stain_spray1.png', 1); spray('stain_spray2.png', 7)
drips('stain_drip1.png', 3); drips('stain_drip2.png', 11)
smear('stain_smear1.png', 5)
mist('stain_mist1.png', 9); mist('stain_mist2.png', 13)
