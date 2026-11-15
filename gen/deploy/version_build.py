# Copy the web build into the gh-pages folder under versioned names, so a phone's browser can never
# mix an old cached pack with a new page (Safari reloading a crashed tab served a stale index.pck).
import hashlib, os, re, shutil, sys, glob
src, dst = sys.argv[1], sys.argv[2]
h = hashlib.md5(open(os.path.join(src, 'index.pck'), 'rb').read()).hexdigest()[:8]
name = 'ashes-' + h
keep = set()
try:
    prev = re.search(r'"executable":"(ashes-[0-9a-f]+)"', open(os.path.join(dst, 'index.html')).read())
    if prev:
        keep.add(prev.group(1))   # the build before stays one deploy longer: a phone with the old page cached can still start
except Exception:
    pass
for old in [f for f in glob.glob(os.path.join(dst, 'ashes-*')) if not any(os.path.basename(f).startswith(k + '.') or os.path.basename(f).startswith(k + '-') for k in keep)] + [os.path.join(dst, 'index.' + e) for e in ('pck', 'wasm', 'js', 'audio.worklet.js', 'audio.position.worklet.js')]:
    if os.path.exists(old):
        os.remove(old)
for ext in ('pck', 'wasm', 'js', 'audio.worklet.js', 'audio.position.worklet.js'):
    shutil.copy(os.path.join(src, 'index.' + ext), os.path.join(dst, name + '.' + ext))
for pk in glob.glob(os.path.join(src, 'pack_*.pck')):   # the story's packs, fetched by packs.gd as <name>-<group>.pck
    shutil.copy(pk, os.path.join(dst, '%s-%s.pck' % (name, os.path.basename(pk)[5:-4])))
html = open(os.path.join(src, 'index.html')).read()
html = html.replace('<script src="index.js"></script>', '<script src="%s.js"></script>' % name)
html = html.replace('"executable":"index"', '"executable":"%s"' % name)
html = html.replace('"index.pck":', '"%s.pck":' % name).replace('"index.wasm":', '"%s.wasm":' % name)
crash = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'crash.js')).read().replace('__BUILD__', name)
html = html.replace('<head>', '<head><script>' + crash + '</script>', 1)
assert name + '.js' in html and '"executable":"%s"' % name in html
open(os.path.join(dst, 'index.html'), 'w').write(html)
print('versioned as', name)
