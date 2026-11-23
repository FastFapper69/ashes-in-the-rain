"""The newest Gemini download (Downloads/Gemini_Generated_Image_*) into art_src as the next free number - the step
after the download icon in the Gemini tab (ch03: Gemini via Claude in Chrome). Refuses a file older than 3 minutes
(the download did not land: click the icon again). usage: py gen/tools/gemini_take.py [number]   -> prints the path"""
import glob, os, shutil, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from paths import SRC
dl = os.path.join(os.path.expanduser("~"), "Downloads")
files = sorted(glob.glob(os.path.join(dl, "Gemini_Generated_Image_*")), key=os.path.getmtime)
if not files or time.time() - os.path.getmtime(files[-1]) > 180:
    print("STOP: no Gemini download in the last 3 minutes"); sys.exit(1)
nums = [int(os.path.splitext(os.path.basename(p))[0]) for p in glob.glob(SRC + "*.*") if os.path.splitext(os.path.basename(p))[0].isdigit()]
n = int(sys.argv[1]) if len(sys.argv) > 1 else max(nums) + 1
out = SRC + "%03d%s" % (n, os.path.splitext(files[-1])[1].lower())
if os.path.exists(out):
    print("STOP: %s exists" % out); sys.exit(1)
shutil.copy2(files[-1], out)
from PIL import Image
print(out, Image.open(out).size)
