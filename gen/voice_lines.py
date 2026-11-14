"""Every line Frank narrates (cutscene captions and the map intros/outros), one file each:
voice/<key>.mp3, key = a short hash of the line's exact text. Quoted lines are other people talking:
they stay on the page only. Prints JSON [{key, text}]."""
import json, re, hashlib, sys
def key(t): return hashlib.md5(t.encode()).hexdigest()[:10]
def strings(block): return re.findall(r'"((?:[^"\\]|\\.)*)"', block)
lines = []
cut = open("cutscene.gd").read()
cut = cut[cut.index("const SCENES"):cut.index("const LIVE")]
for m in re.finditer(r'"lines": \[(.*?)\]', cut):
    lines += strings(m.group(1))
for m in re.finditer(r'"hard": \[(.*?)\]\}?,?\n', cut):
    lines += [s for s in strings(m.group(1))]
lv = open("levels.gd").read()
for m in re.finditer(r'"(?:intro|outro)": \[(.*?)\]', lv):
    lines += strings(m.group(1))
out, seen = [], set()
for t in lines:
    t = t.replace('\\"', '"')
    if t.startswith('"') or t in seen:
        continue
    seen.add(t)
    out.append({"key": key(t), "text": t})
json.dump(out, sys.stdout, indent=0)
