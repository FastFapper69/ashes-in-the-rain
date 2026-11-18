"""Split the web build into a base pack and one pack per part of the story, so a phone only holds the
drawings of the chapter being played (Godot's web build keeps every pack it has in memory).

Groups: a = prologue + chapter I (both in Hell's Kitchen), b = chapter II, c = chapter III, d = chapter IV.
A street, room or cross-section drawing goes into a group's pack if only that group's maps name it; a comic panel if
only that group's cutscenes show it. Everything else stays in the base pack.
Writes export_presets.cfg (base exclude list + one preset per group) and packs.gd (what runtime needs).
Run from the repo root: python3 gen/packs.py
"""
import re, os, glob, collections, json

GROUP_OF_CHAPTER = {0: 'a', 1: 'a', 2: 'b', 3: 'c', 4: 'd'}
CUTS = {'opening': 'a', 'eddie': 'a', 'interlude': 'a', 'teague': 'a', 'dream': 'e',   # (the dream's panels: before 1:5, with its own pack)
       
        'docks': 'b', 'cranes': 'b', 'lucia': 'b', 'hold': 'b', 'harbor': 'b', 'kessler': 'b', 'memory': 'b', 'underground': 'c', 'briggs': 'c'}

src = open('levels.gd').read()
src = src.split('const SANDBOX')[0]   # trial maps use chapter I drawings: they add nothing to the packs
chapters = re.split(r'\n\t\{"title": ', src)[1:]
# a map with a pack of its own (18. 11.: pack a, prologue + chapter I, reached 93.5 MB of GitHub's 100): THE DREAM's
# burning warehouse drawings are named by no other map. Its text is taken out of its chapter's and given its group.
OWN_PACK = {"THE DREAM": "e"}
GROUP_OF_MAP = {}
units = []   # (group, text) of every chapter, and of every map with its own pack
for i, c in enumerate(chapters):
    maps = c.split('\n\t\t{"name": ')
    rest = [maps[0]]
    for k, m in enumerate(maps[1:]):
        nm = m.split('"')[1]
        if nm in OWN_PACK:
            units.append((OWN_PACK[nm], m))
            GROUP_OF_MAP["%d:%d" % (i, k)] = OWN_PACK[nm]
        else:
            rest.append(m)
    units.append((GROUP_OF_CHAPTER[i], '\n\t\t{"name": '.join(rest)))
files = collections.defaultdict(set)   # path -> groups
# the big laundry's other drawings (main.gd ROOM_PARTS, 18. 11.): never named in levels.gd themselves - they go
# wherever its long front goes (only chapter I's THE LAUNDRY), or the base pack grew past GitHub's 100 MB
PART_OF = {'laundry_mid': 'front_laundry_l', 'laundry_end': 'front_laundry_l'}
for f in sorted(set(x.replace(os.sep, '/') for x in glob.glob('art/street/*.png') + glob.glob('art/rooms/**/*.png', recursive=True))):   # (/ on Windows too)
    stem = os.path.basename(f)[:-4]
    base = re.sub(r'_(lit|solid|neon\d|n|catwalk)$', '', stem)
    base = PART_OF.get(base, base)
    for g, c in units:
        if re.search(r'"%s"' % re.escape(base), c):
            files[f].add(g)
# a building in cross-section (art/section/<style>_*.png, the kit main.gd builds the storeys from): into the pack
# of the only group whose maps have a section of that style ("tenement" -> chapter I)
for f in sorted(x.replace(os.sep, '/') for x in glob.glob('art/section/*.png')):
    style = os.path.basename(f)[:-4].split('_')[0]
    gs = {GROUP_OF_CHAPTER[i] for i, c in enumerate(chapters) if re.search(r'"%s[a-z_]*"' % re.escape(style), c)}
    if len(gs) == 1:
        files[f] = gs
cs = open('cutscene.gd').read()
body = cs[cs.index('const SCENES'):]
body = body[:body.index('\n}\n')]
for m in re.finditer(r'\n\t"(\w+)": \[(.*?)\n\t\]', body, re.S):
    for img in re.findall(r'"img": (\d+)', m.group(2)):
        files['art/cut/%s.jpg' % img].add(CUTS[m.group(1)])
# set pieces of single maps (mapfx.gd / setpieces.gd, 2026-11-16): into the pack of the chapter they play in
EXTRA = {'a': ['art/props/el_span.png', 'art/props/sheets.png', 'art/props/neon_hotel.png', 'art/props/neon_hotel_glow.png'],
         'b': ['art/props/wave.png'],
         'e': ['art/fore/dream_post.png'],   # (THE DREAM's burning posts in the foreground, 18. 11.)
         'c': ['art/props/girder.png', 'art/props/boxcars.png', 'art/props/sewer_water.png', 'art/props/rat.png']}
for g, lst in EXTRA.items():
    for f in lst:
        files[f] = {g}
# never needed in the build: the old painted-wall street (main.gd _build_street's fallback when a map has
# no drawn street; every map has one) and a foreground layer nothing loads
NEVER = ['art/bg/far.png', 'art/bg/mid.png', 'art/bg/fore.png', 'art/bg/wall2.png', 'art/bg/wall2_n.png', 'art/bg/wall2_lit.png']
# (18. 11.: the base pack hit GitHub's 100 MB limit) a street or room drawing no campaign map names - the trial maps'
# (they play as chapter I, pack a) or one no map uses any more (front_laundry, the old kits): into pack a, never the
# base. Only the firewall pier is loaded by name for every map.
_sand = open('levels.gd').read().split('const SANDBOX')[1]
for f in sorted(set(x.replace(os.sep, '/') for x in glob.glob('art/street/*.png') + glob.glob('art/rooms/**/*.png', recursive=True))):
    if f in files or f.endswith('/pier.png'):
        continue
    base = re.sub(r'_(lit|solid|neon\d|n|catwalk)$', '', os.path.basename(f)[:-4])
    if re.search(r'"%s"' % re.escape(PART_OF.get(base, base)), _sand):
        files[f] = {'a'}
    else:   # named by no map at all: not in the build (its source stays in the repo)
        NEVER.append(f)
# the title screen of a page with no pack yet (main.gd stand_in: the "1931" map) loads before any pack is mounted:
# every drawing it names stays in the base pack (17. 11.: market_b left chapter I's maps, went into pack b, and a
# fresh page died on "No loader found ... market_b.png")
_i = src.index('"name": "1931"')
_j = src.find('{"name": "', _i + 10)
_stand = src[_i:_j if _j > 0 else len(src)]
for f in list(files):
    stem = re.sub(r'_(lit|solid|neon\d|n)$', '', os.path.basename(f)[:-4])
    if re.search(r'"%s"' % re.escape(stem), _stand):
        files[f] = set()
groups = collections.defaultdict(list)
for f, g in sorted(files.items()):
    if len(g) == 1:
        groups[next(iter(g))].append(f)

def size(f):
    imp = open(f + '.import').read()
    d = re.search(r'path="res://([^"]+)"', imp)
    return os.path.getsize(d.group(1)) if d and os.path.exists(d.group(1)) else 0

for g in sorted(groups):
    print('pack %s: %d files, %.1f MB' % (g, len(groups[g]), sum(size(f) for f in groups[g]) / 1048576))

# export presets: the base excludes every grouped file; each group pack exports exactly its files
cfg = open('export_presets.cfg').read()
cfg = cfg[:cfg.index('[preset.1]')] if '[preset.1]' in cfg else cfg
base_ex = 'art_src/*,art/_src/*,_shots/*,gen/*,build/*'
allg = [f for g in sorted(groups) for f in groups[g]]
cfg = re.sub(r'exclude_filter="[^"]*"', lambda _m: 'exclude_filter="%s"' % ','.join([base_ex] + allg + NEVER), cfg, count=1)
cfg = cfg.rstrip('\n') + '\n'
for k, g in enumerate(sorted(groups)):
    lst = ', '.join('"res://%s"' % f for f in groups[g])
    cfg += '''
[preset.%d]

name="pack_%s"
platform="Web"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray(%s)
include_filter=""
exclude_filter=""
export_path="build/pack_%s.pck"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.%d.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=false
''' % (k + 1, g, lst, g, k + 1)
open('export_presets.cfg', 'w').write(cfg)
probes = {g: 'res://' + groups[g][0] for g in sorted(groups)}
open('packs_list.gen.gd', 'w').write('# Generated by gen/packs.py: do not edit by hand.\nextends RefCounted\n\nconst GROUP_OF_MAP := %s\nconst GROUP_OF_CHAPTER := %s\nconst PROBE := %s\n' % (
    json.dumps(GROUP_OF_MAP),
    json.dumps({str(k): v for k, v in GROUP_OF_CHAPTER.items()}).replace('"0"', '0').replace('"1"', '1').replace('"2"', '2').replace('"3"', '3').replace('"4"', '4'),
    json.dumps(probes)))
