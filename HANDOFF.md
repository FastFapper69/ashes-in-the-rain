# ASHES IN THE RAIN – handoff for the next session (14. 11. 2026, 16:55)

Read this first when picking the project up in a new chat. Reply to the user in Czech, short. In-game text English, nothing Czech in the story, hero Frank Malone.

## Where things live
- GitHub: `FastFapper69/ink-and-lead` – `main` = sources, `gh-pages` = web build (https://fastfapper69.github.io/ink-and-lead/). The user plays on an iPhone 17.
- PC project folder: `C:\Users\super\Documents\MobileGames\Ink and Lead` (Gemini images in `art_src`, numbered; last used **96**, next is **97**).
- Docs (claude.ai): GDD `aac76a8f-a825-409f-a7d5-7834fe45049d` (tab Úkoly = task list by blocks 1–7), story doc `c223d676-08b8-42df-ae12-8f2cdf9b9dc3`, Gemini briefs `855fd524-d34d-495e-a18c-22e6eefa5dee`.
- UI rules: `.claude/skills/ui-papir/SKILL.md` (paper.gd kit, mandatory `UI BAD` audit at 1280 and 1560 wide).

## Rebuild from scratch in a new container
1. `git clone` the repo (main), download Godot 4.7.2 stable linux + export templates.
2. `godot --headless --import`
3. Web export: `godot --headless --export-release Web build/index.html` (pck must stay < 100 MB, now ~94 MB; `export_presets.cfg` exclude_filter keeps unused art out).
4. Deploy: commit sources to `main`; copy `build/index.{pck,html,js,wasm}` into a `gh-pages` worktree, commit, push, check `git rev-parse HEAD == origin/gh-pages`.
5. Commit trailer:
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and the current `Claude-Session:` link.

## Tests
- Rendered: `xvfb-run -a -s "-screen 0 1700x800x24" godot --rendering-driver opengl3 --resolution 1560x720 --fixed-fps 30 -- --test=<mode>`; pictures land in `_shots/`.
- Modes: `play --chapter=N --map=M` (bot), `menu --progress=N`, `pause`, `page`, `card`, `choice`, `cut:<scene>` (eddie, interlude, teague, dream, kessler, underground, briggs, docks), `look:x`, `tops`, `give`, `bulbs:x`, `fall:x[,player]`, `pin:i`, `--guilt=N`.
- Output must have no `UI BAD`; look at the zoomed shots yourself before shipping.

## Gemini on the user's PC (computer use)
- Request access to both gemini.exe paths (`computer_resolve_access` → `computer_request_access`).
- New chat for every redraw: editing an image in the same chat drifts (Gemini keeps its last version). Upload the reference with +/Nahrát soubory and ask for a NEW drawing with the reference used only for style.
- Download: hover the image, click the download icon at its top right, save dialog → full path `...\art_src\NN.jpg`. Stage into the container with `device_stage_files`.
- Cutscene panels are 1920×815 (Gemini gives 3168×1344, same ratio → plain resize). Live fire/smoke spots per panel: `LIVE` in cutscene.gd.

## The user's standing rules (he gets angry when they are broken)
- Look at every graphic change yourself before delivering. No AI tells: six fingers, hands through solid wood, glyph soup text (fix text with `gen/fix_cut_text.py`).
- Geometry matches the painted art, feet on surfaces, straight lines stay straight, no code-drawn slabs.
- Logic audit of props; no enemy fire right after spawn/checkpoint.
- Every light has a visible source; glows in the source's shape.

## Done this session
- Visual unity block (badges, paper variants, print layer, fonts), surrender / disarm / ash (guilt) system, testimony pages, interiors (shootable bulbs that break, darker rooms, FPS), death poses fixed, enemy squad AI (roles, flank, cover, morale, max two shooters, director, callouts), touch fix (first joystick tap no longer fires).
- Art audit of all cutscene panels: dream panel 70 redrawn (art_src/96.jpg, hands only through gaps, empty-handed patrolman, line "I counted eleven knocks."), real text on 56, 59, 61, 64, 65.

## Next
- Block 1: pasted posters in street paintings; lighter hatching on character parts.
- Block 4: skill tree (INSTINCTS cork board, Lead / Time / Conscience branches).
- Block 5: sound – cutscene SFX per panel, music that follows the action, rain only where it rains (not in the fire dream, muffled indoors), try an AI voice for Frank's narration (English, one voice, check licence).
- Block 6: chapter mechanics; block 7: content (chapter IV, menus II/III, train yard).
- Endings (Snow / Ash) wait for chapter IV.
- Not yet heard back: FPS on the iPhone in interiors after the lighting fix.
