"""Paint out AI glyph soup in the street paintings (Gemini art review, 14. 11. 2026).

Two kinds of fix, listed per picture in EDITS:
  ("posters", box)                 every light poster inside the box loses its fake print and
                                   becomes a blank, rain-washed sheet (its torn edge and outline stay)
  ("word", box, text, size, ink)   the fake lettering inside the box is painted out and one real
                                   1940s word is lettered in its place
Boxes are in pixels of the painting (3028 x 1344). Run from the project root; overwrites art/street.
"""
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT = "fonts/Oswald.ttf"

EDITS = {
	"laundry": [
		("word", (2036, 846, 2262, 904), "PROVISIONS", 44, (70, 38, 28)),
		("word", (2036, 1012, 2258, 1072), "FRESH MEAT DAILY", 30, (90, 40, 34)),
	],
	"market": [   # the signs down the street that runs away into the city: repainted plates
		("plate", (2097, 651, 2124, 732), "H\nO\nT\nE\nL", 15, (34, 30, 28), (236, 226, 204)),
		("plate", (1770, 858, 1810, 892), "BAR", 17, (36, 32, 30), (228, 216, 194)),
		("plate", (1818, 818, 1839, 875), "E\nA\nT", 14, (36, 32, 30), (228, 216, 194)),
		("plate", (2086, 855, 2124, 875), "PAWN", 13, (222, 205, 160), (40, 32, 28)),
		("plate", (2126, 870, 2174, 907), "CAFE", 19, (200, 190, 170), (36, 30, 26)),
	],
}


def paper_tone(rgb, mask):
	px = rgb[mask]
	if len(px) == 0:
		return np.array([200, 190, 170], np.uint8)
	lum = px.mean(axis=1)
	return np.median(px[lum > np.percentile(lum, 60)], axis=0).astype(np.uint8)


def blank_posters(rgb, box):
	x0, y0, x1, y1 = box
	roi = rgb[y0:y1, x0:x1]
	lum = roi.mean(axis=2)
	sat = roi.max(axis=2).astype(int) - roi.min(axis=2)
	paper = ((lum > np.percentile(lum, 55)) & (sat < 60)).astype(np.uint8)
	paper = cv2.morphologyEx(paper, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
	n, lab, stats, _ = cv2.connectedComponentsWithStats(paper)
	for i in range(1, n):
		x, y, w, h, area = stats[i]
		if w < 22 or h < 22 or area < 600:
			continue
		sheet = (lab == i).astype(np.uint8)
		sheet = cv2.morphologyEx(sheet, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
		inside = cv2.erode(sheet, np.ones((7, 7), np.uint8))   # keep the drawn edge of the sheet
		tone = paper_tone(roi, inside.astype(bool))
		dark = (roi.mean(axis=2) < tone.mean() - 28) & inside.astype(bool)
		hole = cv2.dilate(dark.astype(np.uint8), np.ones((3, 3), np.uint8)) & inside
		roi[:] = cv2.inpaint(roi, hole, 6, cv2.INPAINT_TELEA)
		# rain has washed it: a few soft vertical streaks, darker toward the bottom
		yy = np.arange(roi.shape[0])[:, None]
		streak = (np.sin(np.arange(roi.shape[1])[None, :] * 0.9 + i) * 0.5 + 0.5) * np.clip((yy - y) / max(h, 1), 0, 1)
		shade = (1.0 - 0.10 * streak)[..., None]
		roi[inside.astype(bool)] = (roi * shade)[inside.astype(bool)].astype(np.uint8)
	rgb[y0:y1, x0:x1] = roi


def plate(rgb, box, text, size, fill, ink):
	"""A whole small sign painted anew: a flat plate with an ink rim and a thin inner line, one word."""
	x0, y0, x1, y1 = box
	pic = Image.fromarray(rgb[y0:y1, x0:x1].copy())
	d = ImageDraw.Draw(pic)
	w, h = pic.size
	d.rectangle((0, 0, w - 1, h - 1), fill=fill, outline=(14, 12, 12), width=2)
	d.rectangle((3, 3, w - 4, h - 4), outline=ink, width=1)
	rgb[y0:y1, x0:x1] = np.asarray(pic)
	letter(rgb, (x0 + 4, y0 + 4, x1 - 4, y1 - 4), text, size, ink, 0.0, False)
	# weather it into the painting: soften to the painting's brush, grain, a little of the old wall through
	old = np.asarray(Image.fromarray(rgb[y0:y1, x0:x1]).filter(ImageFilter.GaussianBlur(0.7)), np.float32)
	grain = np.random.default_rng(x0 * 7 + y0).normal(0, 9, old.shape[:2])[..., None]
	dim = 0.88 + 0.12 * np.linspace(1, 0, old.shape[0])[:, None, None]   # rain-dark toward the bottom
	rgb[y0:y1, x0:x1] = np.clip(old * dim + grain, 0, 255).astype(np.uint8)


def letter(rgb, box, text, size, ink, angle=0.0, clean=True):
	x0, y0, x1, y1 = box
	roi = rgb[y0:y1, x0:x1].copy()
	if clean:   # only the old lettering goes (strokes darker than the sign); feathered, so no patch shows
		lum = roi.mean(axis=2)
		marks = (lum < np.median(lum) - 35).astype(np.uint8)
		marks = cv2.dilate(marks, np.ones((5, 5), np.uint8))
		fixed = cv2.inpaint(roi, marks, 9, cv2.INPAINT_TELEA)
		soft = cv2.GaussianBlur(marks.astype(np.float32), (0, 0), 2.0)[..., None]
		soft = np.clip(soft * 1.6, 0, 1)
		roi = (fixed * soft + roi * (1 - soft)).astype(np.uint8)
	pic = Image.fromarray(roi)
	font = ImageFont.truetype(FONT, size)
	d = ImageDraw.Draw(pic)
	spacing = -size * 0.25
	tw, th = d.multiline_textbbox((0, 0), text, font=font, spacing=spacing, align="center")[2:]
	room = np.hypot(x1 - x0, y1 - y0) * 0.9 if angle else (x1 - x0) * 0.94
	while (tw > room or (not angle and th > (y1 - y0) * 0.96)) and size > 8:
		size -= 1
		spacing = -size * 0.25
		font = ImageFont.truetype(FONT, size)
		tw, th = d.multiline_textbbox((0, 0), text, font=font, spacing=spacing, align="center")[2:]
	# lettered by hand: draw on its own layer, rough the edge, let the wall show through a little
	layer = Image.new("L", pic.size, 0)
	ImageDraw.Draw(layer).multiline_text(((pic.width - tw) / 2, (pic.height - th) / 2 - size * 0.12), text, font=font, fill=255, spacing=spacing, align="center")
	if angle:
		big = Image.new("L", (int(tw * 1.4) + 8, int(th * 3) + 8), 0)
		ImageDraw.Draw(big).multiline_text((4, th), text, font=font, fill=255, spacing=spacing, align="center")
		big = big.rotate(angle, resample=Image.BICUBIC, expand=True)
		layer = Image.new("L", pic.size, 0)
		layer.paste(big, ((pic.width - big.width) // 2, (pic.height - big.height) // 2))
	noise = Image.effect_noise(pic.size, 60).filter(ImageFilter.GaussianBlur(0.6))
	layer = Image.fromarray(np.clip(np.asarray(layer, np.float32) * (0.75 + np.asarray(noise, np.float32) / 512.0), 0, 255).astype(np.uint8))
	pic.paste(Image.new("RGB", pic.size, ink), (0, 0), layer)
	rgb[y0:y1, x0:x1] = np.asarray(pic)


def main(names):
	for name in names:
		path = f"art/street/{name}.png"
		img = Image.open(path)
		mode = img.mode
		rgba = np.asarray(img.convert("RGBA")).copy()
		rgb = np.ascontiguousarray(rgba[..., :3])
		for e in EDITS[name]:
			if e[0] == "posters":
				blank_posters(rgb, e[1])
			elif e[0] == "plate":
				plate(rgb, *e[1:])
			else:
				letter(rgb, e[1], e[2], e[3], e[4], e[5] if len(e) > 5 else 0.0)
		rgba[..., :3] = rgb
		Image.fromarray(rgba, "RGBA").convert(mode).save(path)
		print("cleaned", name)


if __name__ == "__main__":
	main(sys.argv[1:] or list(EDITS))
