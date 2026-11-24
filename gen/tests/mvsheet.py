import sys, glob
from PIL import Image
a, b = int(sys.argv[1]), int(sys.argv[2]); out = sys.argv[3]; hw = 230; top = int(sys.argv[4]) if len(sys.argv) > 4 else 40
fs = sorted(glob.glob('_shots/mv_*.png'))[a:b]
ims = [Image.open(f) for f in fs]
W, H = ims[0].size
cols = min(len(ims), 6); rows = (len(ims) + cols - 1) // cols
s = Image.new('RGB', (cols * 2 * hw, rows * 640))
for i, im in enumerate(ims):
    s.paste(im.crop((W // 2 - hw + 40, top, W // 2 + hw + 40, top + 640)), ((i % cols) * 2 * hw, (i // cols) * 640))
s.save(out); print([f[10:-4] for f in fs])
