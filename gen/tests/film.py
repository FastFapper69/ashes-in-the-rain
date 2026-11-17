"""A review strip of any test: runs it with --film=start,step,16 and lays the 16 frames out 4x4 (for Gemini / own review).
py gen/tests/film.py <out.png> <start> <step> -- <godot test args...>"""
import sys, subprocess, glob, os
from PIL import Image
out, start, step = sys.argv[1], sys.argv[2], sys.argv[3]
rest = sys.argv[sys.argv.index("--") + 1:]
for f in glob.glob("_shots/film_*.png"):
    os.remove(f)
G = os.environ.get("G", "C:/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe")
subprocess.run(["py", "gen/tests/rungd.py", "--idle", "25", "--max", "150", "--", "--path", ".", "--rendering-driver", "opengl3",
                "--resolution", "1560x720", "--fixed-fps", "30", "--"] + rest + ["--film=%s,%s,16" % (start, step)], capture_output=True)
fs = sorted(glob.glob("_shots/film_*.png"))
s = Image.new("RGB", (4 * 480, 4 * 222))
for i, f in enumerate(fs[:16]):
    s.paste(Image.open(f).convert("RGB").resize((480, 222)), ((i % 4) * 480, (i // 4) * 222))
s.save(out)
print(len(fs), "frames ->", out)
