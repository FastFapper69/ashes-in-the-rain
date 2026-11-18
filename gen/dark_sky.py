"""Gemini painted some street pieces with a flat dark night sky above the roofs instead of white (18. 11., art_src 291-301):
process_art.py's sky key (white) keeps it. This cuts it: from the top edge down, every pixel close to the sky's own colour
(the median of the top rows) and smooth (no ink line), connected to the top - the roofline, chimney and sawtooth roof stay.
Run after process_art.py for the named pieces: py -3 gen/dark_sky.py <name>..."""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
ST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "street")
for name in sys.argv[1:]:
    p = os.path.join(ST, name + ".png")
    im = np.asarray(Image.open(p)).copy()
    rgb = im[..., :3].astype(float)
    top = np.median(rgb[2:14].reshape(-1, 3), axis=0)
    close = np.abs(rgb - top).max(axis=2) < 26
    edge = ndimage.gaussian_gradient_magnitude(rgb.mean(axis=2), 1.5) < 9
    m = close & edge
    m[300:] = False   # (the sky never comes down into the storeys)
    # column by column from the top: sky until the first pixel that is not (a broken pane lower down is not sky)
    m = ndimage.binary_opening(m, iterations=1)
    first = np.argmin(m, axis=0)                       # the first non-sky row in each column
    first[m.all(axis=0)] = m.shape[0]
    first = ndimage.median_filter(first, size=9)      # (a raindrop or a speck does not end the sky)
    keep = np.arange(im.shape[0])[:, None] < first[None, :]
    a = (1.0 - ndimage.gaussian_filter(keep.astype(float), 1.0)) * 255.0   # (no white sky here: process_art's white key is
    # dropped, or light painted-over panes would be cut out as sky)
    im[..., 3] = a.astype(np.uint8)
    Image.fromarray(im).save(p)
    sm = Image.fromarray(((im[..., 3] > 128) * 255).astype(np.uint8)).resize((im.shape[1] // 2, im.shape[0] // 2), Image.BILINEAR)
    Image.merge("RGBA", [Image.new("L", sm.size, 255)] * 3 + [sm]).save(os.path.join(ST, name + "_solid.png"))
    print(name, "sky", round(float(keep.mean()), 3), "top rgb", top.astype(int))
