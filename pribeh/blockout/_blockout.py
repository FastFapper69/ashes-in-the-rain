"""Blockout karty map: z <mapa>.json udela <id>.md (karta) a <id>.png (nakres).
Spusteni: python3 pribeh/blockout/_blockout.py   (projde vsechny .json ve slozce)"""
import json, glob, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

HERE = os.path.dirname(os.path.abspath(__file__))
KINDS = ["ticho", "klid", "pohyb", "boj", "vrchol"]            # serazeno podle napeti
COL = dict(zip(KINDS, ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab", "#0d366b"]))  # jeden odstin, svetla -> tmava
INK, MUTED, SURF = "#0b0b0b", "#52514e", "#fcfcfb"

def picture(d, path):
    beats = d["beats"]
    fig, (a, b) = plt.subplots(2, 1, figsize=(11, 5.6), dpi=150, gridspec_kw={"height_ratios": [1, 1.25], "hspace": 0.5})
    fig.patch.set_facecolor(SURF)
    for ax in (a, b):
        ax.set_facecolor(SURF)
        for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
        ax.spines["bottom"].set_color("#c9c8c2"); ax.tick_params(colors=MUTED, labelsize=8, length=0)
    # nahore: napeti v case
    t = 0
    for bt in beats:
        lvl = KINDS.index(bt["kind"]) + 1
        a.add_patch(Rectangle((t + 1, 0), max(bt["sec"] - 2, 1), lvl, color=COL[bt["kind"]], lw=0))
        a.text(t + bt["sec"] / 2, lvl + 0.18, str(bt["n"]), ha="center", va="bottom", fontsize=8, color=INK)
        t += bt["sec"]
    a.set_xlim(0, t); a.set_ylim(0, 6.2); a.set_yticks(range(1, 6)); a.set_yticklabels(KINDS)
    step = 30 if t <= 360 else 60
    a.set_xticks(range(0, int(t) + 1, step)); a.set_xticklabels([f"{s // 60}:{s % 60:02d}" for s in range(0, int(t) + 1, step)])
    a.set_title(f"Napětí v čase (celkem {t // 60}:{t % 60:02d})", loc="left", fontsize=10, color=INK)
    # dole: mapa z boku
    x = 0
    top = max(bt["floor"] for bt in beats) + 1
    for bt in beats:
        w = max(bt["px"], 600)
        y = bt["floor"]
        b.add_patch(Rectangle((x + 40, y), w - 80, 0.82, color=COL[bt["kind"]], lw=0))
        b.text(x + w / 2, y + 0.41, str(bt["n"]), ha="center", va="center", fontsize=9, color=(INK if bt["kind"] in ("ticho", "klid") else "#ffffff"), fontweight="bold")
        if bt.get("cp"):
            b.plot([x + 40, x + 40], [y, y + 1.15], color=INK, lw=1.2); b.text(x + 70, y + 1.0, "CP", fontsize=7, color=INK, va="center")
        if bt.get("collect"):
            b.plot(x + w / 2, y + 1.08, marker="D", ms=5, color=INK)
        x += w
    b.set_xlim(0, x); b.set_ylim(-0.1, top + 0.5)
    b.set_yticks([i + 0.41 for i in range(top)]); b.set_yticklabels(["ulice"] + [f"{i}. patro" if i < top - 1 or top == 2 else "střecha" for i in range(1, top)])
    b.set_xticks(range(0, int(x) + 1, 4000)); b.set_xticklabels([f"{v // 1000} tis. px" for v in range(0, int(x) + 1, 4000)])
    real = sum(bt["px"] for bt in beats)
    b.set_title(f"Mapa z boku (délka {round(real / 1000, 1)} tis. px)   CP = checkpoint   ◆ = něco k nalezení", loc="left", fontsize=10, color=INK)
    fig.savefig(path, facecolor=SURF, bbox_inches="tight"); plt.close(fig)
    return t, real

def card(d, t, x):
    L = [f"# Blockout: {d['name']}", "",
         "Návrh k posouzení, nic z toho není postavené. Vygenerováno z `%s.json` (data pro stavbu) skriptem `_blockout.py`, ručně needitovat." % d["src"],
         "Pravidla a postup: [[pravidla-map]]. Stav všech map: [[stav-map]]. Příběh: [[Srdce-a-hlas]].", "",
         f"**Smysl mapy:** {d['meaning']}", f"**Proč tudy jde:** {d['why']}", f"**Předává:** {d['handover']}",
         f"**Hraje se za:** {d['hero']}. **Cíl délky:** {d['target_min']}. **Součet úseků:** {t // 60}:{t % 60:02d}, {round(x / 1000, 1)} tisíce px. Součet je čistý průchod bez smrtí a hledání, s nimi počítej zhruba o třetinu víc.", "",
         f"![[{d['id']}.png]]", "",
         "## Návrh pro generátor", "", "`" + " → ".join(d["graph"]) + "`", "", d["graph_note"], "",
         "## Postup hráče", ""] + [f"- {p}" for p in d["progression"]] + ["",
         "## Pro hráče, který přeskakuje panely", "", "Tři věci, které musí zaznít přímo v mapě:", ""] + [f"{i + 1}. {s}" for i, s in enumerate(d["skipper"])] + ["", "## Úseky", ""]
    for bt in d["beats"]:
        L += [f"### {bt['n']}. {bt['name']} ({bt['kind']}, {bt['sec']} s, {bt['px']} px)", "",
              f"- **Prostor:** {bt['space']}", f"- **Nepřátelé:** {bt['men'] or 'nikdo'}",
              f"- **Zvuk:** {bt['music']}"]
        if bt.get("collect"): L.append(f"- **K nalezení:** {bt['collect']}")
        L += [f"- **Text:** {bt['text']}", f"- **Checkpoint:** {'ano, na začátku úseku' if bt.get('cp') else 'ne'}", f"- **Náročnost:** {bt['cost']}", ""]
    L += ["## Rizika", ""] + [f"- {r}" for r in d["risks"]] + ["", "## Poznámky Claude Code", "", "Sem připsat, co je těžké, hloupé nebo proti pravidlům map, a opravit odhady A, B, C.", ""]
    return "\n".join(L)

for p in sorted(glob.glob(os.path.join(HERE, "*.json"))):
    d = json.load(open(p, encoding="utf-8")); d["src"] = os.path.basename(p)[:-5]
    t, x = picture(d, os.path.join(HERE, d["id"] + ".png"))
    out = os.path.join(HERE, d["id"] + ".md")
    text = card(d, t, x)
    mark = "## Poznámky Claude Code"
    if os.path.exists(out):                      # poznamky Claude Code se pri novem generovani nesmi ztratit
        old = open(out, encoding="utf-8").read()
        if mark in old:
            text = text[:text.index(mark)] + old[old.index(mark):]
    open(out, "w", encoding="utf-8").write(text)
    print(d["id"], f"{t // 60}:{t % 60:02d}", int(x), "px")
