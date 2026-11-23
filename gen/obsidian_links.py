"""(23. 11., user: "udelame ted ten obsidian") The project's notes as an Obsidian vault (the repo root): chapter mentions
("ch05", "Ch05") become [[wiki links]] to the chapter files, mentions of HANDOFF.md / QUEUE_doma.md / CLAUDE.md /
PC_SETUP.md link to those notes, so the graph shows how rules, chapters, the queue and the log hang together.
Safe to run again: text already inside [[...]] or `code` is left alone. Run: py gen/obsidian_links.py"""
import glob, os, re
ROOT = os.path.join(os.path.dirname(__file__), "..")
K = os.path.join(ROOT, ".claude", "skills", "ashes-znalosti")
CH = {os.path.basename(p)[:4]: os.path.basename(p)[:-3] for p in glob.glob(os.path.join(K, "chapters", "ch*.md"))}
NOTES = {"HANDOFF.md": "HANDOFF", "gen/QUEUE_doma.md": "QUEUE_doma", "QUEUE_doma.md": "QUEUE_doma",
         "CLAUDE.md": "CLAUDE", "gen/PC_SETUP.md": "PC_SETUP", "PC_SETUP.md": "PC_SETUP"}
files = [os.path.join(K, "SKILL.md"), os.path.join(K, "cheatsheet.md"), os.path.join(K, "glossary.md"),
         os.path.join(K, "patterns.md")] + glob.glob(os.path.join(K, "chapters", "*.md")) + \
        [os.path.join(ROOT, "CLAUDE.md")] + glob.glob(os.path.join(ROOT, ".claude", "skills", "*", "SKILL.md"))
# the pieces not to touch: code spans, fenced blocks, links already made
SKIP = re.compile(r"```.*?```|`[^`\n]*`|\[\[[^\]]*\]\]", re.S)
CHRE = re.compile(r"(?<![\w/\[|#-])([Cc]h)(\d\d)(?![\w-])")
NOTERE = re.compile(r"(?<![\w/\[|])(" + "|".join(re.escape(k) for k in sorted(NOTES, key=len, reverse=True)) + r")(?![\w])")


def link(text, me):
    def ch(m):
        key = "ch" + m.group(2)
        if key not in CH or CH[key] == me:
            return m.group(0)
        return "[[%s|%s]]" % (CH[key], m.group(0))

    def note(m):
        n = NOTES[m.group(1)]
        return m.group(0) if n == me else "[[%s|%s]]" % (n, m.group(1))
    out, last = [], 0
    for s in SKIP.finditer(text):
        part = text[last:s.start()]
        out.append(NOTERE.sub(note, CHRE.sub(ch, part)))
        out.append(s.group(0))
        last = s.end()
    out.append(NOTERE.sub(note, CHRE.sub(ch, text[last:])))
    return "".join(out)


n = 0
for p in files:
    t = open(p, encoding="utf-8", newline="").read()
    me = os.path.basename(p)[:-3]
    u = link(t, me)
    if u != t:
        open(p, "w", encoding="utf-8", newline="").write(u)
        n += u.count("[[") - t.count("[[")
print("links added:", n)
