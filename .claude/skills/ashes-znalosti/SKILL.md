---
name: ashes-znalosti
description: "Distilled project knowledge for Ashes in the Rain (Godot 4.7 web/iPhone noir shooter, repo FastFapper69/ink-and-lead): the user's hard rules, build/deploy, tests, art pipeline, phone memory, levels, lights, enemy AI, progression, audio, story. Read first in every session on this game; open a chapter file when a task touches that topic."
---

<!-- argument-hint: [topic, system name, or chapter number] -->

# Ashes in the Rain – project knowledge
**Sources**: HANDOFF.md (up to section "(7) Barks, rooms, barrels", 2026-11-16), `.claude/skills/ui-papir`, user's standing rules | **Built with**: book-to-skill structure (index + on-demand chapters) | **Generated**: 2026-11-16

## How to use
- Read THIS file at the start of every session (~2k tokens; HANDOFF.md is ~10k and chronological).
- Touching a topic → open its chapter from the index below **before** editing code. Need a number or a rule fast → `cheatsheet.md`. Unknown name (CURVE, KIT, crumbs…) → `glossary.md`. A recurring technique → `patterns.md`.
- HANDOFF.md stays the **session log** (what changed today, what is next). This skill is the **stable knowledge**. If they disagree, the newer HANDOFF entry wins – then fix the chapter (see "Keeping it current").
- Reply to the user in Czech, short. In-game text English. Nothing Czech in the story. Hero = Frank Malone.

---

## 1. Hard rules (the user gets angry when they are broken)
1. **Look at every visual change yourself before delivering** – zoomed screenshots. No AI tells (six fingers, hands through wood, glyph-soup text → `gen/fix_cut_text.py`). UI: zero `UI BAD` lines and eyes on 1280 **and** 1560 wide shots (skill `ui-papir`).
2. **Geometry matches the painting.** Feet exactly on visible surfaces, no platforms/stairs the painting does not have, straight lines never bend (deep views only *slide*, and only if their ground ends inside the cut-out), no code-drawn slabs/lines/polygons as visible art – get a drawing (Gemini) instead.
3. **Logic check for every prop and map**: right size next to a man, belongs to the place, collision in its real shape, nothing blocks the path unfairly, no hard cuts between scenes. Run the automated audit over all maps (bot clears every map) – never repeat a mistake already pointed out.
4. **No enemy fire right after a level start or checkpoint respawn.**
5. **Enemies shoot / throw only at a Frank on their own floor** (`_same_floor`, `_can_see`). Multi-floor maps: camera zooms so only the current floor fills the frame. Every new multi-floor map keeps both.
6. **Every light has a visible source and the source's shape** (neon glow in letter shapes, not a round blob). Painted-in light and reflections react with the light (flickering neon dims its reflection). Lamps only where a real lamp hangs (over a sign or door, bare wall) – never on a window, fire escape or sign. **Inked light cones are rejected** ("looks terrible") – do not bring them back; strong amber cones were also disliked.
7. **Two chats deploy to this repo.** Before any commit/deploy: `git fetch` both clones, merge origin's commits first; `deploy.sh` STOPs by itself. Never copy the tree over a newer origin.
8. **Phone memory is the #1 crash cause** (Safari kills the tab, no JS error). Long audio 22050 Hz mono (ffprobe before commit); never Basis for textures read via `get_image` or for comic panels; new big drawing → `python3 gen/basis_imports.py`. Details: ch04.
9. **Things the user decided – do not reopen**: figures +18 % (FIG 1.18), post `lift` 0.2, character scale, Sin City blacks (black voids are style), plain lamp glow, levels/XP instead of stars, HP and damage *bought* not automatic, side gun of the player's choice (revolver or Beretta, one or two; changed by the user 16. 11.) + one big gun (can be taken along into a chapter with few rounds), pickups never auto-equip, bullets do not pass through cover (SPLINTERS instead), prologue Eddie overpowered then weak Frank with a rising curve, Eddie wears a different (short) coat.
10. **Cover and props make sense where they stand** (user, 16. 11.): never three identical things in a row, nothing in front of a painted door/passage/ladder, a man's width between two props, rooms not identical copies, red barrels only where fuel is kept. Enforced by `check_props()` in gen/levels.py – rules in skill `mapy`.
11. **Enemies talk** (user, 16. 11., "like The Last of Us"): every man has a name, the others shout it when he falls; every new behaviour ships with a bark (barks.gd, English caps, ~24 chars).
12. Story: no plot holes; inspired by Max Payne / Alan Wake / L.A. Noire storytelling but never copying; original characters.
13. **The player always sees that mercy and executions mattered, never as a number** (user, 16. 11.): the first surrender is taught (slowed beat, Frank's line, hint), an execution greys the picture and soots Frank's HUD portrait, a man let go washes some off, testimony pages tuck in behind the portrait, the score card lists names (LET GO / SHOT WITH HIS HANDS UP), and the ash changes play (fewer men give up). Ch11, ch10.
14. **Story decisions 16. 11.** – do not reopen: two endings only (Snow / Ash; the Rourke choice changes the scene inside them); Rourke carried the kerosene in 1931; Rosie is one of the three Kowalczyk children Patrick Malone carried out; chapter IV boss is Rourke (Vail dies in a cutscene). Maps are routes, not streets: in, up floors, along corridors, onto roofs, down fire escapes – building **cross-section** ("řez domem", the facade dissolves) chosen over cuts between rooms. Plan: claude.ai doc "ASHES IN THE RAIN – Dramaturgie a kapitola IV" (ch10).

## 2. Core mental models
- **The phone is the target, desktop numbers lie.** iPhone uses ~100 MB more textures (full-screen buffers at pixel ratio), the web keeps every loaded pack in the wasm heap, and Web Audio decodes whole streams to PCM. Measure with crumbs/crash reports, not with desktop feel.
- **Paintings are the level; code only adds light, collision and motion on top.** Pixel coordinates of drawings are the contract (BigTex reports painted size even when imported smaller) – never change a drawing's reported size.
- **Layout first on kits, variants swapped in after** – gameplay never moves when art changes (levels.gd non-street lines must stay identical).
- **One deploy = sources to `main` + versioned web build to `gh-pages`**, keeping the previous build so a cached phone page still starts.
- **Bot-cleared maps are the regression test.** Any change to movement, scale, cover or AI → run the bot over all maps.
- **The user judges by looking on his iPhone 17.** A feature is not done until it is seen in a screenshot and works in the web build.

## 3. Keeping it current (fold-in rule)
- New *durable* rule or decision from the user → add it to §1 here **and** to the matching chapter, in the same commit as the code.
- New system/technique → one paragraph in its chapter + a cheatsheet line if it has a number or threshold.
- Session progress, open bugs, "next" lists → HANDOFF.md only.
- Rebuild the whole skill from HANDOFF with `.claude/skills/book-to-skill` (Mode 4 "Update / Fold-in", project-local root `.claude/skills`), then `python3 .claude/skills/book-to-skill/tools/validate_skill.py .claude/skills/ashes-znalosti/SKILL.md` and `scan_generated_skill.py` on the folder.

---

## Chapter index

| # | Topic | Covers |
|---|-------|--------|
| [ch01](chapters/ch01-build-deploy.md) | Build & deploy | clones, Godot 4.7.2, deploy.sh, gh-pages versions, web check in PC browser, commit trailer, two-chat rule |
| [ch02](chapters/ch02-tests.md) | Tests | rendered tests, all `--test=` modes and flags, bot, UI audit |
| [ch03](chapters/ch03-art-pipeline.md) | Art pipeline | Gemini on the PC, art_src numbering, processing scripts, kits & variants, Basis/LowRes/BigTex import rules |
| [ch04](chapters/ch04-phone-memory.md) | Phone memory & crashes | crash reports (Supabase), texture streaming, packs, audio memory, hitches |
| [ch05](chapters/ch05-levels-maps.md) | Levels & maps | gen/levels.py, chunks, multi-floor roofs/mezzanine, metro scale, deep views, mapfx, setpieces, diary pages |
| [ch06](chapters/ch06-lights-fx.md) | Lights & effects | lamps, bulbs/pendants/searchlights, fire, ink FX sheets, post grade, rain |
| [ch07](chapters/ch07-enemies-ai.md) | Enemies & difficulty | floor/sight rules, squad AI, cover, flanking, chapter enemy types, disarm, hats, CURVE |
| [ch08](chapters/ch08-player-progression.md) | Player & progression | moves, FIG scale, ropes, pipe, style score, XP/levels, perks, guns & gunsmith |
| [ch09](chapters/ch09-audio-voice.md) | Audio & voice | music stems, Artlist sources, narration voice, audio format rules |
| [ch10](chapters/ch10-story-cutscenes.md) | Story & cutscenes | cast, chapters, interludes, cutscene.gd, panels, narration pacing |
| [ch11](chapters/ch11-ui-hud.md) | UI & HUD | ui-papir summary, HUD parts, modal, cards, board |

## Topic index
- **audio format / 22 kHz** → ch09, ch04
- **Basis / texture import** → ch03, ch04
- **bot / clearing maps** → ch02, ch05
- **camera zoom per floor** → ch05, ch07
- **checkpoints / respawn** → ch05, ch07
- **combo / style score / XP** → ch08
- **cover, crates, SPLINTERS** → ch07, ch08
- **barks / enemy names** → ch07
- **room furnishing, red barrels, prop rules** → ch05, skill `mapy`
- **crash reports / crumbs** → ch04
- **cutscene panels / narration** → ch10, ch09
- **deep views (DEEP_SPLIT)** → ch05
- **deploy / gh-pages** → ch01
- **difficulty CURVE** → ch07
- **disarm / hats** → ch07
- **dream / 1931 memory maps** → ch05, ch10
- **Gemini art workflow** → ch03
- **guns, bag, gunsmith** → ch08
- **HUD, cards, board, UI audit** → ch11
- **lamps / lights** → ch06
- **mapfx (el, fog, storm, flood…)** → ch05
- **packs a/b/c** → ch04, ch01
- **ropes / ladders / zip / swing** → ch08, ch05
- **street variants / kits** → ch03, ch05
- **Supabase `ashes_reports`** → ch04
- **tests list** → ch02

## Supporting files
- [cheatsheet.md](cheatsheet.md) – decision rules, thresholds, numbers
- [patterns.md](patterns.md) – recurring techniques that worked here
- [glossary.md](glossary.md) – code names and project terms
- Research (noir style, story, combat feel, AI, level design, Godot web/iOS, controls) → skill `ashes-vyzkum`

## Scope & limits
Covers what is in HANDOFF.md up to 2026-11-16 (5). Exact current values live in code – grep before relying on a number. Design docs (GDD, story, Gemini briefs) are claude.ai docs, ids in ch01.
