"""The mobsters' shouts (barks.gd), recorded per voice with Artlist Eleven v3 (2026-11-16).

  python3 gen/bark_voices.py scripts        -> /tmp/vo/<voice>_<k>.txt, the texts to record (≤ ~2400 chars each)
  python3 gen/bark_voices.py split V K F    -> cut recording F of script K of voice V at its pauses into
                                               voice/barks/<voice>_<md5[:10]>.mp3 (22050 Hz mono, 64 kbps)
Every line is recorded with its feeling: a man who sees his friend shot panics, a taunt mocks. The scripts
separate lines with [long pause]; split cuts at silences ≥ ~1 s and checks the count matches."""
import re, sys, os, hashlib, json, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, 'barks.gd')).read()
VOICES = re.findall(r'"(\w+)"', re.search(r'const VOICES := \[(.*?)\]', src).group(1))
NAMES = re.findall(r'"([A-Z]+)"', re.search(r'const NAMES := \[(.*?)\]', src, re.S).group(1))
LINES = {k: re.findall(r'"((?:[^"\\]|\\.)*)"', v) for k, v in re.findall(r'\n\t"(\w+)": \[(.*?)\]', src[src.index('const LINES'):], re.S)}
FEEL = {"down": "[panicked, shouting]", "lead_down": "[panicked]", "alone": "[scared, quiet]", "spot": "[shouting]",
        "flank": "[shouting orders]", "round": "[shouting orders]", "behind": "[mocking, shouting]", "cover": "[urgent, shouting]",
        "crate": "[angry, shouting]", "reload": "[urgent]", "empty": "[excited, shouting]", "taunt": "[mocking, shouting]", "death": "[in pain, weak]"}
NAMED = {"down": ["HE GOT {n}!"]}   # the only lines with a name that are recorded, for every name
DOWN_FEEL = ["[panicked, shouting]"]


def spoken(t):
    """HE GOT VINNIE! -> He got Vinnie!  (read as written; capitals would be read as an acronym or a yell)"""
    if t != t.upper():
        return t   # (already written as spoken: the death cries)
    s = t.lower()
    s = re.sub(r"(^|[.!?]\s+|--\s*)([a-z])", lambda m: m.group(1) + m.group(2).upper(), s)
    for w in NAMES + ["MALONE"]:
        s = re.sub(r"\b%s\b" % w.lower(), w.capitalize(), s)
    return re.sub(r"\bi('m)?\b", lambda m: "I" + (m.group(1) or ""), s)


def lines():
    out = []
    for kind, lst in LINES.items():
        for l in lst:
            if "{n}" in l:
                continue
            out.append((kind, l.replace("{p}", "MALONE"), FEEL[kind]))
    for t, feel in zip(NAMED["down"], DOWN_FEEL):
        for n in NAMES:
            out.append(("down", t.replace("{n}", n), feel))
    return out


def key(voice, text):
    return "%s_%s" % (voice, hashlib.md5(text.encode()).hexdigest()[:10])


def scripts():
    os.makedirs('/tmp/vo', exist_ok=True)
    ls = lines()
    chunks, cur, n = [], [], 0
    last, run = None, 0
    for kind, text, feel in ls:
        if n + len(spoken(text)) + len(feel) > 2600 and cur:
            chunks.append(cur); cur, n, last = [], 0, None
        run = run + 1 if feel == last else 0
        piece = ("%s %s" % (feel, spoken(text))) if feel != last or run % 6 == 0 else spoken(text)   # the feeling again every few lines, so it does not fade
        last = feel
        cur.append((text, piece)); n += len(piece) + 16
    chunks.append(cur)
    total = 0
    for v in VOICES:
        for k, c in enumerate(chunks):
            body = "\n\n...\n\n".join(p for t, p in c)
            open('/tmp/vo/%s_%d.txt' % (v, k), 'w').write(body)
            json.dump([t for t, p in c], open('/tmp/vo/%s_%d.json' % (v, k), 'w'))
            total += len(body)
    print(len(ls), "lines,", len(chunks), "scripts per voice,", total, "characters in all")


_norm = lambda t: ' '.join(re.findall(r"[a-z']+", t.lower()))


def _decoder(texts):
    """PocketSphinx (pip install pocketsphinx; its English model ships in the wheel) held to a grammar of
    exactly these lines: it says which of them a piece of the recording is."""
    from pocketsphinx import Decoder, get_model_path
    md = get_model_path()
    extra = {'aaargh': 'AA R G', 'augie': 'AO G IY', 'reloading': 'R IY L OW D IH NG', 'agh': 'AA G'}
    open('/tmp/vo/my.dict', 'w').write(open(md + '/en-us/cmudict-en-us.dict', encoding='latin-1').read() + ''.join('%s %s\n' % kv for kv in extra.items()))
    alts = sorted(set(_norm(t) for t in texts))
    open('/tmp/vo/g.jsgf', 'w').write('#JSGF V1.0;\ngrammar l;\npublic <s> = ' + ' | '.join('( %s )' % a for a in alts) + ';\n')
    cfg = Decoder.default_config()
    cfg['hmm'] = md + '/en-us/en-us'; cfg['dict'] = '/tmp/vo/my.dict'; cfg['lm'] = None; cfg['jsgf'] = '/tmp/vo/g.jsgf'; cfg['logfn'] = '/dev/null'
    return Decoder(cfg)


def _align(texts, f, dur, noise, mind):
    """Which stretch of the recording is which line: every silence is a possible cut; a line may span up to
    three pieces (a pause inside it), a piece may be left out (a breath). The speech recogniser scores each
    stretch against the line it should be; the best path through all lines wins."""
    import functools
    log = subprocess.run(['ffmpeg', '-hide_banner', '-i', f, '-af', 'silencedetect=noise=%ddB:d=%s' % (noise, mind), '-f', 'null', '-'], capture_output=True, text=True).stderr
    sil = list(zip([float(x) for x in re.findall(r'silence_start: ([\d.]+)', log)], [float(x) for x in re.findall(r'silence_end: ([\d.]+)', log)]))
    pts = [(0.0, 0.0)] + [x for x in sil if 0.05 < x[0] and x[1] < dur - 0.05] + [(dur, dur)]
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', f, '-ar', '16000', '-ac', '1', '-f', 's16le', '-'], capture_output=True).stdout
    dec = _decoder(texts)
    cache = {}
    def hyp(p, q):   # what the stretch from the end of pause p to the start of pause q says
        if (p, q) not in cache:
            a, b = pts[p][1], pts[q][0]
            if b - a < 0.08:
                cache[(p, q)] = ''
                return ''
            dec.start_utt(); dec.process_raw(raw[int(a * 16000) * 2:int(b * 16000) * 2], full_utt=True); dec.end_utt()
            cache[(p, q)] = dec.hyp().hypstr if dec.hyp() else ''
        return cache[(p, q)]
    n = len(pts) - 1
    sys.setrecursionlimit(20000)
    @functools.lru_cache(None)
    def best(i, p):   # lines i.. from piece p on: (matches, ((p, q), ...))
        if i == len(texts):
            return (0.0, ()) if n - p <= 2 else (-99.0, ())
        if p >= n:
            return (-99.0, ())
        opts = []
        for span in (1, 2, 3):
            q = p + span
            if q > n:
                break
            m, rest = best(i + 1, q)
            opts.append((m + (1.0 if hyp(p, q) == _norm(texts[i]) else 0.0), ((p, q),) + rest))
        m, rest = best(i, p + 1)   # leave this piece out
        opts.append((m - 0.01, rest))
        return max(opts, key=lambda o: o[0])
    score, spans = best(0, 0)
    bad = [(t, hyp(p, q)) for (p, q), t in zip(spans, texts) if hyp(p, q) != _norm(t)]
    return score, [(pts[p][1], pts[q][0]) for p, q in spans], bad


def align(texts, f, dur):
    """Tried with a few silence settings (a line can follow another with hardly a breath); the best wins."""
    best = max((_align(texts, f, dur, n, d) for n, d in ((-40, 0.12), (-35, 0.08), (-30, 0.06), (-28, 0.05))), key=lambda r: r[0])
    print("recogniser agrees on %d of %d lines" % (round(best[0]), len(texts)))
    for t, h in best[2]:
        print("  check by ear: %-28s heard as %s" % (t, h))
    return best[1]


def split(voice, k, f):
    texts = json.load(open('/tmp/vo/%s_%s.json' % (voice, k)))
    dur = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout)
    cuts = align(texts, f, dur)
    for (a, b), t in zip(cuts, texts):
        out = os.path.join(ROOT, 'voice/barks/%s.mp3' % key(voice, t))
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-ss', '%.3f' % max(0, a - 0.06), '-to', '%.3f' % (b + 0.12), '-i', f,
                        '-af', 'afade=t=out:st=%.3f:d=0.08,loudnorm=I=-14:TP=-1.0' % (b - a + 0.1), '-ar', '22050', '-ac', '1', '-b:a', '64k', out], check=True)
    print(voice, k, len(cuts), "lines cut")


if __name__ == '__main__':
    if sys.argv[1] == 'scripts':
        scripts()
    elif sys.argv[1] == 'split':
        split(sys.argv[2], sys.argv[3], sys.argv[4])
