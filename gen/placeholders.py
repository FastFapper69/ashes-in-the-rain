# Placeholder art until the Gemini pictures arrive: the back walls of the interiors (tiling sideways)
# and the pickups. Drawn as ink: flat dark tones, hard edges, hatching.
import random, math
from PIL import Image, ImageDraw, ImageFilter
R = '/home/claude/repo/art/'
W, H = 1000, 1500
random.seed(3)

def hatch(d, box, gap, col, ang=1):
    x0, y0, x1, y1 = box
    for k in range(int(x0 - (y1 - y0)), int(x1), gap):
        d.line([(k, y1), (k + (y1 - y0) * ang, y0)], fill=col, width=1)

def grain(im, amt=14):
    n = Image.effect_noise(im.size, amt).convert('L')
    return Image.composite(im, Image.new('RGB', im.size, (0, 0, 0)), n.point(lambda v: 255 if v > 40 else 200))

def room(name, base, draw_fn):
    im = Image.new('RGB', (W, H), base); d = ImageDraw.Draw(im)
    draw_fn(d)
    d.rectangle([0, 0, W, 170], fill=(14, 13, 12))                         # the ceiling, in shadow
    for x in range(0, W, 250): d.rectangle([x, 150, x + 40, 200], fill=(26, 24, 22))   # joists
    d.rectangle([0, H - 40, W, H], fill=(20, 18, 16))                       # skirting
    im = grain(im.filter(ImageFilter.GaussianBlur(0.6)))
    im.save(R + f'rooms/{name}.png'); print(name)

def laundry(d):
    for y in range(200, H - 40, 70):                                         # white tiles gone grey
        for x in range(0, W, 70):
            d.rectangle([x + 2, y + 2, x + 68, y + 68], fill=(88, 86, 80), outline=(40, 38, 35))
    for x in (120, 620):                                                     # pipes
        d.rectangle([x, 170, x + 26, H - 40], fill=(30, 28, 26)); d.rectangle([x + 4, 170, x + 9, H - 40], fill=(70, 68, 64))
    d.line([(0, 520), (W, 560)], fill=(20, 20, 20), width=3)                 # a washing line with sheets
    for x in range(60, W, 180):
        d.polygon([(x, 528 + x * 0.04), (x + 120, 532 + x * 0.04), (x + 110, 760 + random.randint(-30, 30)), (x + 10, 740 + random.randint(-30, 30))], fill=(150, 146, 136), outline=(30, 30, 30))
        hatch(d, (x + 10, 600, x + 110, 760), 9, (110, 106, 98))

def warehouse(d):
    for y in range(200, H - 40, 46):                                         # brick
        off = 0 if (y // 46) % 2 == 0 else 60
        for x in range(-off, W, 120):
            d.rectangle([x + 3, y + 3, x + 117, y + 43], fill=(62 + random.randint(-8, 8), 50, 44), outline=(26, 22, 20))
    for x in (0, 500):                                                       # steel columns and a high window
        d.rectangle([x + 200, 170, x + 250, H - 40], fill=(28, 28, 30)); hatch(d, (x + 200, 170, x + 250, H - 40), 8, (50, 50, 54))
    d.rectangle([380, 260, 620, 600], fill=(18, 20, 26), outline=(10, 10, 10), width=8)
    for k in range(3): d.line([(380 + 80 * (k + 1), 260), (380 + 80 * (k + 1), 600)], fill=(10, 10, 10), width=6)
    d.line([(380, 430), (620, 430)], fill=(10, 10, 10), width=6)

def tenement(d):
    for x in range(0, W, 40):                                                # tired wallpaper
        d.rectangle([x, 170, x + 20, 900], fill=(74, 66, 58))
        d.rectangle([x + 20, 170, x + 40, 900], fill=(64, 57, 50))
    d.rectangle([0, 900, W, H - 40], fill=(48, 38, 30))                      # wainscot
    for x in range(0, W, 200): d.rectangle([x + 20, 940, x + 180, H - 80], outline=(28, 22, 18), width=4)
    d.rectangle([380, 420, 620, 900], fill=(36, 28, 22), outline=(16, 12, 10), width=8)   # a numbered door
    d.ellipse([580, 650, 596, 666], fill=(140, 120, 70)); d.text((470, 470), "4B", fill=(150, 130, 90))
    d.rectangle([60, 360, 260, 520], outline=(20, 18, 16), width=6); hatch(d, (66, 366, 254, 514), 10, (52, 46, 40))   # a picture frame

def club(d):
    for x in range(0, W, 60):                                                # velvet curtain folds
        shade = 34 + int(14 * math.sin(x / 60 * math.pi))
        d.rectangle([x, 170, x + 60, H - 40], fill=(shade + 10, shade - 8, shade - 6))
        d.line([(x + 30, 170), (x + 30, H - 40)], fill=(20, 12, 12), width=3)
    for x in (200, 700):                                                     # sconces
        d.rectangle([x, 640, x + 30, 700], fill=(120, 100, 60)); d.polygon([(x - 20, 640), (x + 50, 640), (x + 30, 600), (x, 600)], fill=(170, 150, 100))
    d.rectangle([0, 1100, W, H - 40], fill=(22, 18, 18))                     # the stage edge
    d.line([(0, 1100), (W, 1100)], fill=(90, 80, 60), width=4)

room('laundry', (70, 68, 64), laundry)
room('warehouse', (50, 44, 40), warehouse)
room('tenement', (58, 52, 46), tenement)
room('club', (40, 26, 26), club)

# pickups: silhouettes in ink with a cream edge so they read on the dark street
def item(name, size, shape):
    s = 4
    im = Image.new('RGBA', (size[0] * s, size[1] * s), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    shape(d, s)
    edge = im.split()[3].filter(ImageFilter.MaxFilter(13))
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(Image.new('RGBA', im.size, (236, 226, 204, 255)), (0, 0), edge)
    out.alpha_composite(im)
    out = out.resize(size, Image.LANCZOS); out.save(R + f'items/{name}.png'); print(name)

INK = (14, 14, 16, 255)
item('tommy', (260, 110), lambda d, s: (d.rectangle([20*s, 30*s, 200*s, 52*s], fill=INK), d.rectangle([200*s, 38*s, 250*s, 46*s], fill=INK),
     d.ellipse([80*s, 50*s, 130*s, 100*s], fill=INK), d.polygon([(20*s, 32*s), (0, 40*s), (0, 70*s), (40*s, 52*s)], fill=INK),
     d.rectangle([140*s, 52*s, 156*s, 86*s], fill=INK)))
item('shotgun', (270, 70), lambda d, s: (d.rectangle([60*s, 20*s, 265*s, 34*s], fill=INK), d.polygon([(60*s, 18*s), (0, 30*s), (8*s, 62*s), (70*s, 36*s)], fill=INK),
     d.rectangle([150*s, 34*s, 210*s, 44*s], fill=INK)))
item('pistols', (180, 110), lambda d, s: [(d.rectangle([(10 + k*60)*s, (20 + k*20)*s, (110 + k*60)*s, (36 + k*20)*s], fill=INK),
     d.polygon([((20 + k*60)*s, (36 + k*20)*s), ((44 + k*60)*s, (36 + k*20)*s), ((36 + k*60)*s, (80 + k*20)*s), ((12 + k*60)*s, (78 + k*20)*s)], fill=INK)) for k in (0, 1)])
item('flask', (80, 110), lambda d, s: (d.rounded_rectangle([8*s, 22*s, 72*s, 106*s], radius=14*s, fill=INK), d.rectangle([30*s, 4*s, 50*s, 24*s], fill=INK),
     d.rectangle([18*s, 50*s, 62*s, 80*s], fill=(150, 30, 24, 255))))
