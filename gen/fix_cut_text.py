"""Replace AI glyph soup in cutscene panels with real words, drawn in the panel's own hand.
Each fix: a polygon on the picture where the fake lettering is wiped (dark strokes inpainted from the
paper round them), then real lines laid in at an angle, in a font that fits (Eddie's hand, a typewriter).
usage: fix_cut_text.py <original.jpg> <out.jpg> <panel id>"""
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FIXES = {
	"59": [   # Eddie's notebook, left page: what he really wrote that night
		{"wipe": [(572, 232), (888, 190), (950, 445), (952, 474), (832, 478), (832, 600), (800, 668), (660, 712)],
			"keep": [(832, 476, 1000, 680), (800, 600, 832, 690)],
			"font": "fonts/ReenieBeanie.ttf", "size": 30, "ink": (48, 40, 36), "angle": -8.8, "at": (596, 254), "lead": 27,
			"lines": ["Nov 24. Pier 17, two a.m.", "You can still see where", "the doors were chained.", "Nobody chains a door to keep",
				"a fire in by accident.", "", "Sully says Kessler had", "the keys that night.", "He cried when he said it.",
				"Eleven men.", "Who signed", "the report?"]},
	],
	"64": [   # the 1939 report Frank signed
		{"wipe": [(893, 389), (1148, 415), (1142, 460), (1088, 470), (1085, 558), (866, 548), (870, 430), (893, 428)],
			"font": "fonts/SpecialElite.ttf", "size": 9, "ink": (44, 38, 32), "angle": 6.6, "at": (921, 394), "lead": 12,
			"lines": ["At 2:10 A.M., Aug. 14, 1939, fire broke", "out in Warehouse 17, West St. Eleven", "longshoremen were found inside after",
				"the fire was put out. Cause determined", "to be faulty wiring. Doors found", "unsecured. No sign of foul play.", "",
				"No further action recommended.", "Reported by the undersigned,", "23rd Precinct. Witnesses: none."]},
		{"wipe": [(1079, 353), (1133, 357), (1132, 375), (1078, 371)],
			"font": "fonts/SpecialElite.ttf", "size": 8, "ink": (44, 38, 32), "angle": 5.0, "at": (1092, 358), "lead": 10,
			"lines": ["Aug. 14,"]},
	],
	"65": [   # wall map and the report in Briggs's hand
		{"wipe": [(1553, 158), (1640, 158), (1640, 222), (1553, 222)], "font": "fonts/SpecialElite.ttf", "size": 11, "ink": (60, 50, 40), "angle": -14.0, "at": (1562, 180), "lead": 12, "lines": ["BROOKLYN"]},
		{"wipe": [(1478, 262), (1558, 262), (1558, 298), (1478, 298)], "font": "fonts/SpecialElite.ttf", "size": 10, "ink": (60, 50, 40), "angle": 8.0, "at": (1484, 270), "lead": 12, "lines": ["UPPER BAY"]},
		{"wipe": [(1536, 40), (1634, 40), (1634, 85), (1536, 85)], "font": "fonts/SpecialElite.ttf", "size": 9, "ink": (60, 50, 40), "angle": -6.0, "at": (1542, 62), "lead": 12, "lines": ["QUEENS"]},
		{"wipe": [(1508, 158), (1572, 158), (1572, 188), (1508, 188)], "lines": []},
		{"wipe": [(1021, 400), (1090, 381), (1101, 419), (1035, 437)], "font": "fonts/Oswald.ttf", "size": 12, "ink": (40, 34, 28), "angle": -16.0, "base": (1029, 412), "lead": 12, "lines": ["PIER 17 - 1939"], "rule": 3},
		{"wipe": [], "font": "fonts/Oswald.ttf", "size": 9, "ink": (40, 34, 28), "angle": -16.0, "base": (1042, 431), "lead": 12, "lines": ["CAUSE: ACCIDENTAL"]},
	],
	"56": [   # club posters
		{"wipe": [(230, 250), (292, 250), (292, 278), (230, 278)], "font": "fonts/Oswald.ttf", "size": 15, "ink": (30, 26, 24), "angle": -3.0, "at": (234, 254), "lead": 16, "lines": ["CABARET"]},
		{"wipe": [(266, 338), (302, 338), (302, 362), (266, 362)], "font": "fonts/Oswald.ttf", "size": 11, "ink": (30, 26, 24), "angle": -3.0, "at": (270, 342), "lead": 12, "lines": ["9 P.M."]},
		{"wipe": [(4, 336), (72, 336), (72, 357), (4, 357)], "font": "fonts/Oswald.ttf", "size": 10, "ink": (30, 26, 24), "angle": 0.0, "at": (8, 339), "lead": 12, "lines": ["EVERY NIGHT"]},
		{"wipe": [(1593, 268), (1655, 268), (1655, 291), (1593, 291)], "font": "fonts/Oswald.ttf", "size": 15, "ink": (30, 26, 24), "angle": -2.0, "at": (1598, 271), "lead": 16, "lines": ["JENNY"]},
		{"wipe": [(1600, 358), (1660, 358), (1660, 378), (1600, 378)], "font": "fonts/Oswald.ttf", "size": 10, "ink": (30, 26, 24), "angle": -2.0, "at": (1606, 362), "lead": 12, "lines": ["LIVE"]},
	],
	"61": [   # crate stencil
		{"wipe": [], "clone": ((372, 524, 452, 580), 58), "font": "fonts/Oswald.ttf", "size": 20, "ink": (24, 20, 18), "angle": 0.0, "at": (381, 526), "lead": 22, "lines": ["PIER 17"]},
		{"wipe": [], "clone": ((372, 560, 452, 590), -30), "lines": []},
	],
}


def wipe(img, poly, keep):
	if not poly:
		return img
	h, w = img.shape[:2]
	area = np.zeros((h, w), np.uint8)
	cv2.fillPoly(area, [np.array(poly, np.int32)], 255)
	if not poly:
		return img
	for x0, y0, x1, y1 in keep:
		area[y0:y1, x0:x1] = 0
	gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
	paper = cv2.medianBlur(gray, 21)
	strokes = ((paper.astype(int) - gray.astype(int)) > 18).astype(np.uint8) * 255
	strokes = cv2.dilate(strokes, np.ones((3, 3), np.uint8), iterations=2) & area
	return cv2.inpaint(img, strokes, 5, cv2.INPAINT_TELEA)


def write(pic, fx):
	font = ImageFont.truetype(fx["font"], fx["size"])
	layer = Image.new("L", (900, 900), 0)
	d = ImageDraw.Draw(layer)
	anchor = "ls" if "base" in fx else "la"
	if "base" in fx:
		fx = dict(fx, at=fx["base"])
	for i, line in enumerate(fx["lines"]):
		d.text((100, 100 + i * fx["lead"]), line, font=font, fill=235, anchor=anchor)
		if fx.get("rule"):
			w = d.textlength(line, font=font)
			d.line([(100, 100 + fx["rule"]), (100 + w, 100 + fx["rule"])], fill=235, width=1)
	layer = layer.rotate(-fx["angle"], resample=Image.BICUBIC, center=(100, 100))
	layer = layer.filter(ImageFilter.GaussianBlur(0.35))
	ink = Image.new("RGB", layer.size, fx["ink"])
	pic.paste(ink, (fx["at"][0] - 100, fx["at"][1] - 100), layer)


src, out, pid = sys.argv[1], sys.argv[2], sys.argv[3]
img = np.asarray(Image.open(src).convert("RGB")).copy()
for fx in FIXES[pid]:
	img = wipe(img, fx["wipe"], fx.get("keep", []))
pic = Image.fromarray(img)
for fx in FIXES[pid]:   # wood keeps its grain better copied from the same board than inpainted
	if "clone" in fx:
		(x0, y0, x1, y1), dy = fx["clone"]
		patch = pic.crop((x0, y0 + dy, x1, y1 + dy))
		m = Image.new("L", patch.size, 0)
		ImageDraw.Draw(m).rectangle((4, 4, patch.width - 5, patch.height - 5), fill=255)
		pic.paste(patch, (x0, y0), m.filter(ImageFilter.GaussianBlur(3)))
for fx in FIXES[pid]:
	if fx.get("lines"):
		write(pic, fx)
pic.save(out, quality=94)
