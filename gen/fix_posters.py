"""Real print on the pasted bills in the street paintings, in place of Gemini's glyph soup.

For each box listed in BILLS (pixels of the painting): every sheet of light paper inside it is found,
its fake lettering inpainted away from the paper round it (the sheet's torn outline and the brick
round it stay), and a short real 1947 bill is set on it in the game's own fonts, a shade askew.
The street's lit layer (art/street/<name>_lit.png, half size) gets the same change through the lamp's
gain, as gen/fix_lit.py does. Originals are read from art/_src/street/<name>.png (kept on first run),
so the script can be run again and again.
usage: python3 gen/fix_posters.py [name ...]   (from the project root)"""
import os
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HEAD = "fonts/Oswald.ttf"
TYPE = "fonts/SpecialElite.ttf"
# what a wall in Hell's Kitchen had on it in December 1947: [big line, small lines...]
TEXTS = [
	["FIGHT", "FRIDAY", "ST. NICK'S"], ["ROOMS", "TO LET"], ["WANTED", "INFORMATION"], ["LOST DOG", "REWARD"],
	["JAZZ", "TONITE"], ["DANCE", "SAT. 9 PM"], ["MEN", "WANTED", "PIER 21"], ["BOXING", "MON. NIGHT"],
	["NOTICE"], ["WORK", "ON THE", "DOCKS"], ["MISSING"], ["SALE"], ["BINGO", "THURS."], ["UNION", "MEETING"],
	["CIRCUS", "TUES."], ["REWARD", "$50"], ["TONITE"],
]
# Each bill, listed bottom sheet first: the sheet (x0, y0, x1, y1: its fake print is wiped inside it,
# clear of its outline and of any sheet pasted over it), and where real print goes on the part that
# shows ([x0, y0, x1, y1], or None to leave it a blank, rain-washed sheet).
BILLS = {
	"laundry": [
		[(243, 890, 290, 980), (249, 895, 286, 975)],
		[(293, 955, 328, 1013), (296, 959, 324, 1009)],
		[(331, 982, 346, 1033), None],
		[(262, 1018, 310, 1041), None],
		[(1127, 888, 1188, 966), (1131, 892, 1185, 943)],
		[(1191, 920, 1222, 981), None],
		[(1117, 985, 1167, 1060), (1120, 1021, 1164, 1057)],
		[(1147, 945, 1205, 1018), (1151, 949, 1201, 1014)],
		[(1206, 980, 1256, 1068), (1210, 985, 1252, 1063)],
		[(1176, 1060, 1212, 1105), (1179, 1064, 1209, 1101)],
	],
	"bluenote": [
		[(198, 975, 266, 1061), (201, 979, 239, 1057)],
		[(350, 1010, 371, 1064), None],
		[(300, 982, 351, 1061), (304, 1012, 347, 1047)],
		[(242, 918, 311, 1011), (246, 922, 307, 1007)],
		[(330, 1082, 363, 1126), None],
		[(285, 1050, 333, 1114), (289, 1054, 329, 1109)],
		[(825, 900, 889, 986), (829, 903, 885, 957)],
		[(888, 930, 944, 1013), (907, 934, 940, 1008)],
		[(812, 998, 869, 1076), (815, 1002, 840, 1071)],
		[(882, 1073, 919, 1114), None],
		[(842, 960, 906, 1053), (846, 964, 902, 1049)],
		[(908, 1012, 966, 1103), (912, 1016, 962, 1098)],
	],
	"church": [
		[(2897, 1001, 2961, 1096), (2901, 1005, 2944, 1092)],
		[(2947, 1040, 2993, 1113), (2951, 1044, 2989, 1109)],
		[(2140, 1010, 2190, 1098), (2144, 1014, 2181, 1094)],
		[(2184, 1051, 2235, 1120), (2188, 1055, 2231, 1115)],
	],
	"subway": [
		[(371, 505, 438, 609), (375, 509, 434, 603)],
		[(414, 605, 455, 670), (417, 610, 444, 665)],
		[(447, 563, 494, 639), (451, 567, 490, 634)],
	],
	"alley": [
		[(931, 920, 988, 1001), (935, 924, 983, 974)],
		[(958, 977, 999, 1021), (961, 981, 995, 1016)],
		[(1100, 941, 1128, 980), None],
		[(1110, 1002, 1161, 1072), (1114, 1016, 1157, 1067)],
		[(1124, 961, 1166, 1013), (1128, 965, 1162, 1008)],
	],
	# the Palace: the marquee's second line and the lettering on two one-sheets (their pictures stay)
	"market": [
		[(1324, 826, 1520, 876), (1340, 838, 1516, 870), ["PLUS CARTOON & NEWSREEL"], "slant", [(1324, 827), (1522, 841), (1522, 877), (1324, 863)]],
		[(1050, 980, 1132, 1020), (1061, 983, 1129, 1017), ["NIGHT FALLS"], "plate"],
		[(1060, 1078, 1134, 1112), (1063, 1081, 1131, 1109), ["VERA LANE", "DAN COLE"], "plate"],
		[(1437, 1068, 1514, 1108), (1440, 1071, 1511, 1105), ["COMING", "FRIDAY"], "plate"],
	],
}


def wipe(rgb, area):
	gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
	paper = cv2.medianBlur(gray, 21)
	sat = (rgb.max(axis=2).astype(int) - rgb.min(axis=2).astype(int))
	sat_paper = cv2.medianBlur(sat.astype(np.uint8), 21).astype(int)
	strokes = (((paper.astype(int) - gray.astype(int)) > 14) | ((sat - sat_paper) > 18)).astype(np.uint8) * 255
	strokes = cv2.dilate(strokes, np.ones((3, 3), np.uint8), iterations=1) & area
	return cv2.inpaint(rgb, strokes, 4, cv2.INPAINT_TELEA)


def letter(pic, rect, lines, ink, tilt):
	x, y, w, h = rect
	pad = max(2, int(min(w, h) * 0.08))
	aw, ah = w - 2 * pad, h - 2 * pad
	gap = 1
	# the first line big and condensed, the rest small; shrink everything until it fits
	for scale in np.linspace(1.0, 0.2, 40):
		big = max(6, int(ah * 0.5 * scale))
		small = max(5, int(big * 0.5))
		fonts = [ImageFont.truetype(HEAD, big)] + [ImageFont.truetype(HEAD, small)] * (len(lines) - 1)
		sizes = [f.getbbox(t) for f, t in zip(fonts, lines)]
		tw = max(b[2] - b[0] for b in sizes)
		gap = max(1, small // 4)
		th = sum(b[3] - b[1] for b in sizes) + (len(lines) - 1) * gap
		if tw <= aw and th <= ah:
			break
	layer = Image.new("L", (w * 3, h * 3), 0)
	d = ImageDraw.Draw(layer)
	cy = h * 1.5 - th / 2
	for f, t, b in zip(fonts, lines, sizes):
		d.text((w * 1.5 - (b[2] - b[0]) / 2 - b[0], cy - b[1]), t, font=f, fill=235)
		cy += (b[3] - b[1]) + gap
	layer = layer.rotate(tilt, resample=Image.BICUBIC).filter(ImageFilter.GaussianBlur(0.35))
	pic.paste(Image.new("RGB", layer.size, ink), (x - w, y - h), layer)


def fix(name):
	src = f"art/_src/street/{name}.png"
	if not os.path.exists(src):
		os.makedirs("art/_src/street", exist_ok=True)
		Image.open(f"art/street/{name}.png").save(src)
		Image.open(f"art/street/{name}_lit.png").save(f"art/_src/street/{name}_lit.png")
	orig = Image.open(src).convert("RGBA")
	alpha = orig.split()[3]
	rgb = np.asarray(orig.convert("RGB")).copy()
	rng = np.random.default_rng(sum(map(ord, name)))
	bills = BILLS[name]
	for i, b in enumerate(bills):
		sheet = b[0]
		area = np.zeros(rgb.shape[:2], np.uint8)
		x0, y0, x1, y1 = sheet
		if len(b) > 4:   # a slanted band, as the marquee hangs
			cv2.fillPoly(area, [np.array(b[4], np.int32)], 255)
		else:
			area[y0 + 3:y1 - 3, x0 + 3:x1 - 3] = 255
		for above in bills[i + 1:]:   # never into a sheet pasted over this one
			ax0, ay0, ax1, ay1 = above[0]
			if name == "market":
				continue
			area[ay0 - 2:ay1 + 2, ax0 - 2:ax1 + 2] = 0
		if len(b) > 3 and b[3] == "plate":   # a printed band of paper: the poster's own light tone, its grain kept
			x0, y0, x1, y1 = b[0]
			region = rgb[y0 - 30:y1 + 30, x0:x1].reshape(-1, 3)
			lum = region.mean(axis=1)
			tone = np.median(region[lum > np.percentile(lum, 80)], axis=0)
			grain = rgb[y0:y1, x0:x1].astype(np.float32).mean(axis=2, keepdims=True)
			grain = (grain - grain.mean()) * 0.08
			rgb[y0 + 2:y1 - 2, x0 + 2:x1 - 2] = np.clip(tone + grain[2:-2, 2:-2], 0, 255).astype(np.uint8)
		else:
			rgb = wipe(rgb, area)
	pic = Image.fromarray(rgb)
	k = sum(map(ord, name))
	for b in bills:
		text = b[1]
		if text is None:
			continue
		x0, y0, x1, y1 = text
		lines = b[2] if len(b) > 2 else TEXTS[k % len(TEXTS)]
		tilt = float(rng.uniform(-2, 2)) if len(b) <= 2 else (-4.0 if len(b) > 4 else 0.0)
		letter(pic, (x0, y0, x1 - x0, y1 - y0), lines, (22, 18, 16), tilt)
		k += 3
	out = pic.convert("RGBA")
	out.putalpha(alpha)
	out.save(f"art/street/{name}.png")
	# the lit layer: same change, through the lamp's gain
	lit_src = Image.open(f"art/_src/street/{name}_lit.png").convert("RGBA")
	sz = lit_src.size
	small = lambda im: np.asarray(im.convert("RGB").resize(sz, Image.LANCZOS), np.float32)
	old_p, new_p = small(orig), small(out)
	lit = np.asarray(lit_src, np.float32).copy()
	blur = lambda a: np.asarray(Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)), np.float32)
	gain = blur(lit[..., :3]) / np.maximum(blur(old_p), 8.0)
	kx = sz[0] / orig.width
	for b in BILLS[name]:
		x0, y0, x1, y1 = [int(round(v * kx)) for v in b[0]]
		lit[y0 - 2:y1 + 2, x0 - 2:x1 + 2, :3] = np.clip(new_p[y0 - 2:y1 + 2, x0 - 2:x1 + 2] * gain[y0 - 2:y1 + 2, x0 - 2:x1 + 2], 0, 255)
	Image.fromarray(lit.astype(np.uint8), "RGBA").save(f"art/street/{name}_lit.png")
	print(name, len(BILLS[name]), "bills")


for n in (sys.argv[1:] or BILLS.keys()):
	fix(n)
