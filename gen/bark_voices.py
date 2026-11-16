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
        "crate": "[angry, shouting]", "reload": "[urgent]", "empty": "[excited, shouting]", "taunt": "[mocking, shouting]"}
NAMED = {"down": ["HE GOT {n}!"]}   # the only lines with a name that are recorded, for every name
DOWN_FEEL = ["[panicked, shouting]"]


def spoken(t):
    """HE GOT VINNIE! -> He got Vinnie!  (read as written; capitals would be read as an acronym or a yell)"""
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
    last = None
    for kind, text, feel in ls:
        piece = ("%s %s" % (feel, spoken(text))) if feel != last else spoken(text)
        last = feel
        if n + len(piece) > 2300 and cur:
            chunks.append(cur); cur, n = [], 0
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


def split(voice, k, f):
    texts = json.load(open('/tmp/vo/%s_%s.json' % (voice, k)))
    dur = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f], capture_output=True, text=True).stdout)
    for d in (1.0, 0.9, 1.1, 0.8, 1.2, 0.7, 1.3):
        log = subprocess.run(['ffmpeg', '-hide_banner', '-i', f, '-af', 'silencedetect=noise=-38dB:d=%s' % d, '-f', 'null', '-'], capture_output=True, text=True).stderr
        st = [float(x) for x in re.findall(r'silence_start: ([\d.]+)', log)]
        en = [float(x) for x in re.findall(r'silence_end: ([\d.]+)', log)]
        cuts, t0 = [], 0.0
        for a, b in zip(st, en):
            if a > t0 + 0.15:
                cuts.append((t0, a))
            t0 = b
        if dur > t0 + 0.15:
            cuts.append((t0, dur))
        if len(cuts) == len(texts):
            break
    else:
        sys.exit("%s %s: %d pieces for %d lines - check by ear" % (voice, k, len(cuts), len(texts)))
    for (a, b), t in zip(cuts, texts):
        out = os.path.join(ROOT, 'voice/barks/%s.mp3' % key(voice, t))
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-ss', '%.3f' % max(0, a - 0.06), '-to', '%.3f' % (b + 0.12), '-i', f,
                        '-af', 'afade=t=out:st=%.3f:d=0.08,loudnorm=I=-14:TP=-1.0' % (b - a + 0.1), '-ar', '22050', '-ac', '1', '-b:a', '64k', out], check=True)
    print(voice, k, len(cuts), "lines cut (silence %.1f s)" % d)


if __name__ == '__main__':
    if sys.argv[1] == 'scripts':
        scripts()
    elif sys.argv[1] == 'split':
        split(sys.argv[2], sys.argv[3], sys.argv[4])
