import key, numpy as np, os
from PIL import Image
from scipy import ndimage as ndi
G = '/mnt/user-data/outputs/godot2/art/'
def cut_rect(img, lab, rect):
    x0, y0, x1, y1 = rect
    keep = []
    for i, sl in enumerate(ndi.find_objects(lab)):
        if sl is None: continue
        cx, cy = (sl[1].start + sl[1].stop) / 2, (sl[0].start + sl[0].stop) / 2
        if x0 <= cx <= x1 and y0 <= cy <= y1: keep.append(i + 1)
    m = np.isin(lab, keep)
    ys, xs = np.nonzero(m)
    a, b, c, d = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    out = img[b:d, a:c].copy(); out[..., 3] = np.where(m[b:d, a:c], out[..., 3], 0)
    return Image.fromarray(out, 'RGBA')
SHEETS = {
 '12': ('props', {'slab_sidewalk': (99,98,1336,396), 'slab_roof': (1411,77,2657,396), 'catwalk': (387,494,2366,884), 'catwalk_cap_l': (99,562,370,940),
        'catwalk_cap_r': (2382,562,2653,939), 'crate': (128,1007,592,1470), 'crate_long': (717,1014,1510,1444), 'drum': (1620,1004,1918,1456), 'dumpster': (2028,976,2648,1483)}),
 '13': ('props', {'lamp_post': (152,52,560,1475), 'lamp_wall': (755,138,1440,681), 'neon_jazz': (1730,96,2070,1042), 'neon_hotel': (2253,100,2552,1040),
        'hydrant': (575,819,961,1476), 'trash_can': (1142,877,1556,1477), 'neon_bar': (1994,1140,2645,1471)}),
 '14': ('fx', {'flash1': (145,55,670,355), 'flash2': (146,384,676,684), 'flash3': (148,724,607,1054), 'flash4': (160,1066,783,1484),
        'puff1': (778,133,930,285), 'puff2': (1078,111,1266,302), 'puff3': (745,404,962,620), 'puff4': (1026,375,1316,656), 'wisp1': (1383,86,1613,424), 'wisp2': (1406,404,1589,653),
        'smoke_big1': (1707,71,2134,587), 'smoke_big2': (2139,78,2640,556), 'spark1': (730,768,968,1028), 'spark2': (1068,782,1318,1053),
        'blood1': (1899,609,2263,884), 'blood2': (2365,604,2594,850), 'blood3': (1420,772,1762,1136), 'blood4': (2350,938,2614,1194),
        'hole1': (1768,983,2017,1209), 'hole2': (2050,959,2297,1204), 'casing1': (828,1200,1042,1430), 'casing2': (1091,1202,1310,1430),
        'splash1': (1360,1350,1533,1456), 'splash2': (1643,1322,1861,1470), 'splash3': (1957,1290,2271,1476), 'splash4': (2343,1312,2637,1475)}),
 '15': ('fx', {'word_blam': (43,40,1043,520), 'word_krakoom': (139,530,1387,1492), 'word_rattat': (1290,100,2700,450), 'word_clink': (1900,520,2650,890),
        'word_bang': (1420,940,2050,1480), 'word_excl': (2078,948,2272,1473), 'word_interrobang': (2300,990,2700,1475)}),
 '16': ('ui', {'portrait': (103,71,601,534), 'bar_full': (690,108,1631,272), 'bar_empty': (648,284,1588,446), 'bubble_say': (1809,112,2191,459), 'bubble_think': (2228,108,2639,414),
        'stopwatch': (653,482,1250,1076), 'icon_jump': (1309,486,1511,687), 'icon_run': (1555,482,1757,683), 'icon_dash': (1322,710,1524,911), 'icon_grenade': (1558,704,1760,904),
        'button_ring': (110,586,555,1028), 'side_revolver': (1848,488,2604,700), 'side_shotgun': (1828,702,2660,888), 'perk_ricochet': (1374,928,1770,1480),
        'perk_decoy': (1812,928,2208,1480), 'perk_boomstick': (2251,928,2646,1480), 'stick_ring': (105,1104,451,1450), 'stick_knob': (468,1191,638,1363)}),
}
made = []
for sheet, (folder, items) in SHEETS.items():
    img = key.keyed(sheet + '.jpg'); lab, _ = ndi.label(img[..., 3] > 30)
    os.makedirs(G + folder, exist_ok=True)
    for name, rect in items.items():
        im = cut_rect(img, lab, rect); im.save(f'{G}{folder}/{name}.png'); made.append((folder, name, im))
# contact sheet
W = 2000; x = y = rowh = 0; pos = []
for f, n, im in made:
    t = im.copy(); t.thumbnail((230, 230))
    if x + t.width > W: x = 0; y += rowh + 34; rowh = 0
    pos.append((t, x, y, n)); x += t.width + 16; rowh = max(rowh, t.height)
from PIL import ImageDraw
cs = Image.new('RGBA', (W, y + rowh + 40), (70, 74, 80, 255)); d = ImageDraw.Draw(cs)
for t, px, py, n in pos: cs.alpha_composite(t, (px, py)); d.text((px, py + t.height + 2), n, fill=(255, 255, 0, 255), font_size=20)
cs.convert('RGB').save('contact.png'); print(len(made), cs.size)
