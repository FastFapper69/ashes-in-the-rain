# Chapter 11: UI & HUD

## Core Idea
All UI is drawn paper (`paper.gd`) – never flat rectangles – and is checked automatically and by eye. Full rules: skill **ui-papir** (read it before any UI change).

## ui-papir in five lines
1. Kit: `Paper.sheet/button/write/caption/place_time`; kinds panel, tape, strip, tag, folder, clip.
2. Drawings never deform: fixed scale per kind, only the clean middle stretches; no StyleBoxFlat.
3. Margin 48 px, gap 16 px, viewport 720 high × 1280–1600 wide; one main action per screen; locked things say why; fixed tilts (no randf).
4. In-game captions: Comic Neue Bold Italic, caps, left aligned, frame fitted to text.
5. `Paper.audit()` in every `_shot` → zero `UI BAD`; then zoomed eyes at 1280 and 1560.

## HUD
- Landscape only. Portrait (Frank; Eddie in the prologue, `portrait_eddie.png`) + health top-left, gun card GTA-style beside it (other gun as a small card behind), pause top-right; combo caption left of pause (below boss bar/hint).
- `hud.modal()` hides thumb controls under pause/diary/choice; idle stick/buttons see-through; tutorial hints wait for narration captions (`_hint_queue`).
- Map tally `hud.rating` = Paper card right of centre (LEVEL/XP; "<CHAPTER> CLOSED" on a chapter's last map). Level-up = small tape at top 1.8 s.
- Instincts board: cards show name + PINNED/READY/LOCKED; tap opens a big detail card (`menu._card_detail`) with BACK + PIN IT / TAKE IT DOWN; icons `art/ui/instincts/icon_*.png`.
- Title sheet: INSTINCTS line ("N NEW"), settings with PROGRESS / ERASE ALL (two taps), DIFFICULTY. Menu builds only 2 street drawings behind the key art.

## Key Takeaways
1. Any new screen = paper kit + audit + zoomed shots at both widths.
2. Text on cards stays short; details behind a tap.
3. HUD never sits over gameplay-critical props (open point: joystick over cover props).

## Conscience on the HUD (16. 11.)
- `hud.set_conscience(soot, pages, wash)`: soot 0..1 = guilt/10 as a shader on the portrait (creeps in from the frame edges, greys the face); pages 0..6 = `page.png` tucked behind the portrait, share of the evidence Rosie needs (`MenuScript.evidence()/evidence_total()`).
- Execution → `main._executed()`: `atmo.pulse_ash`, match sound, `hud.soot_up`, ash burst over the man, witness bark `shotup` by name, Frank's caption the first time on a map. Spare → `set_conscience(..., wash=true)`; testimony → `hud.page_in()` flies a page from the man into the stack.
- First surrender ever (story flag `mercy_taught`): `_impact`, caption "He dropped the gun. / Eddie would have let him walk.", hint "HOLD YOUR FIRE AND HE WALKS. SHOOT HIM AND YOU CARRY IT.", a longer window.
- Score card: `hud.conscience(let_go, shot_up)` captions under the card with the men's names.
- `_quit_odds()`: surrender chance × (1.2 − 0.09·guilt), 0.2..1.25; high guilt → bark `noquit`, low guilt + 2 spared → `quit`.
- Test: `--test=mercy --chapter=1 --map=1 [--guilt=N]` → shots mercy_0..4 (grey pulse, bark, second surrender, page flying, card).
