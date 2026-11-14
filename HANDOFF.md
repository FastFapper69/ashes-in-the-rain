# ASHES IN THE RAIN – handoff for the next session (14. 11. 2026, 16:55)

Read this first when picking the project up in a new chat. Reply to the user in Czech, short. In-game text English, nothing Czech in the story, hero Frank Malone.

## Where things live
- GitHub: `FastFapper69/ink-and-lead` – `main` = sources, `gh-pages` = web build (https://fastfapper69.github.io/ink-and-lead/). The user plays on an iPhone 17.
- PC project folder: `C:\Users\super\Documents\MobileGames\Ink and Lead` (Gemini images in `art_src`, numbered; last used **99**, next is **100**).
- Docs (claude.ai): GDD `aac76a8f-a825-409f-a7d5-7834fe45049d` (tab Úkoly = task list by blocks 1–7), story doc `c223d676-08b8-42df-ae12-8f2cdf9b9dc3`, Gemini briefs `855fd524-d34d-495e-a18c-22e6eefa5dee`.
- UI rules: `.claude/skills/ui-papir/SKILL.md` (paper.gd kit, mandatory `UI BAD` audit at 1280 and 1560 wide).

## Rebuild from scratch in a new container
1. `git clone` the repo (main), download Godot 4.7.2 stable linux + export templates.
2. `godot --headless --import`
3. Web export (art/_src holds generator inputs and art kept for later; it is not exported): `godot --headless --export-release Web build/index.html` (pck must stay < 100 MB, now ~94 MB; `export_presets.cfg` exclude_filter keeps unused art out).
4. Deploy: copy sources into the `main` clone (never copy a `.git` folder over it); commit; copy `build/index.{pck,html,js,wasm}` into a `gh-pages` worktree, commit, push, check `git rev-parse HEAD == origin/gh-pages`.
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

- Difficulty curve (main.gd CURVE, `--test=curve`, `--step=N`): prologue Eddie at full strength; Frank weak and mob grows map by map (density per 10k px, toughness, aim, pace, shooters, heavy guns).
- Skill tree (instincts.gd, menu `_instincts`, `--test=instincts --leads=N --pin=lead0,...`, `--instincts=all` in play): leads = Frank's stars + testimonies; leads earned set Frank's rank (3/4/5 hits at 0/10/24 leads); 12 of 15 cards work in play.
- Sound: per-panel cutscene audio (cutscene.gd AUDIO: beds, music, rain, timed cues), 4 music stems in step (base, lead, tension, fight) driven by _tick_music, rain only where it rains (sfx.rain_want / indoor), new sounds from gen/sfx_story.py; `--log-sound` prints every sound.
- Technical cleanup: dead code and ~30 unused pictures removed, generator inputs moved to art/_src, the save file cached in memory (menu.gd _save/_store), pck 97 -> 90 MB.
- Title sheet: INSTINCTS line (with "N NEW"); settings on the title has PROGRESS / ERASE ALL (two taps; settings kept) and DIFFICULTY (easy/normal/hard on top of the curve, main.gd DIFFICULTY).
- Chapter mechanics: dive kick (Frank only: man knocked flat, one bullet finishes him, else he gets up or gives up), ch II hook men / dynamite throwers / marksmen with a red sight line, crane loads over the docks (shoot the rope), ricochet off steel with a dashed line in slowed time; ch III shield police with a flashlight that finds Frank in the dark, police marksmen. New art: art_src/99 (rifle, hook, dynamite, riot shield, flashlight) in art/guns. Tests: `--test=men:hook|dynamite|sniper|shield|load`, `--test=kick`, `--test=ricochet`.
- Pasted bills in the streets reprinted with real 1947 notices (gen/fix_posters.py, originals in art/_src/street); the Palace marquee and one-sheets fixed.
- Character hatching: a softening pass was tried and looked smudged (worse, more AI-like); left as drawn.

- Ropes (elevation): climb ropes up fire escapes, zip lines from roofs down to the street (one hand, gun out, slowed time), crane swings over cargo stacks in the docks (art/props/rope.png, stack.png). gen/levels.py Chunk.rope(kind,...); main.gd `_add_rope`, `_on_rope`, `_grab_rope`; `--test=rope:climb|zip|swing`. The bot backs off and retries a missed swing.
- Voice: all 88 narration lines read by Artlist "Gravity" (ElevenLabs Multilingual v2, speed 0.9, stability 0.35), voice/<md5[:10]>.mp3 (gen/voice_lines.py lists them; 64 kbps mono, -16 LUFS). Changing a line's text needs a new recording (the key is the md5 of the text).
- Music and sound from Artlist: The Magnetic Buzz - Keep Your Head Down (sfx/music_jazz.ogg, in play), Rotem Cinamon - Dusk (music_dusk.ogg, title and story); the jazz replaces the base+lead stems whenever nothing is fighting (sfx.gd MELODIES, `melody`). Revolvers: dfMG SW .38 (shot_player), DT Sound Point Blank (shot_enemy). Rain: SoundBits heavy rain + city hum (rain_loop.ogg), West Wolf wet streets lowpassed (rain_in.ogg). Long loops are Ogg now (sfx.gd `_looped`).
- Story fixes: Mickey is fought in his club (boss_room "club", beer kegs for cover), Kessler in his harbor office (boss_room "office"); panels 56/57 redrawn (art_src/100, 102: Mickey in a suit, two pigeons in a closed cage, no flock); Rosie brings Eddie's diary (not the notebook the police took).
- Diary pages hang on the wall just before a crate at ground reach (never on a crate or cabinet).
- Sky: a mirrored copy under the sky so a high jump never shows black under it. `--test=look:x --high` frames the camera as high as a jump.
- art_src numbering: last used 102.

## Next
- Skill tree cards still to build when chapter IV exists: DEAD EYE, SHOOT THEM DOWN, ALLY (they open in chapter IV).
- Ideas from the player: melee with a pipe when passing a man (cooldown, a good animation); inner-voice barks when nearly dead (Sin City style: 'get up, old man'); new backdrops so streets repeat less, and subway backdrops that make sense (tracks on the walls, scale).
- pck ~54 MB: textures import as lossy WebP (0.85, diary pages and cards 0.8); normal maps (_n) stay lossless. New art: keep compress/mode=1.
- Block 6 left: room breaching and lightning (chapter IV). Block 7: content (chapter IV, menus II/III, train yard).
- Endings (Snow / Ash) wait for chapter IV.
- Not yet heard back: FPS on the iPhone in interiors after the lighting fix.


## Vícepatrové levely – prototyp TENEMENTS (kap. I mapa 4), 14. 11. 2026
- Lešení (`scaffold` chunk v gen/levels.py): 3 patra po 448.5 px + žebříky cik-cak (rope kind `ladder`: x, top, bottom), nahoře střechy.
- Střechy: `roofs()` v levels.py → level["roof"] {x0, x1, y=-1794, goal, pics, checks}; hráč jde po střechách DOLEVA, mapa končí u firewallu (goal). Kresby art/street/roof_a/b.png (art_src 107/108) v měřítku 0.95, chůze na 0.828 výšky kresby; okrajové kresby za firewally jen jako kulisa.
- Pod střechami jen fasády tenrow_a/b (art_src 111/112, SEG_SIZE 0.675): jejich římsa navazuje přesně na spodek střech.
- main.gd: _build_roofs, _scaffold, _cam_rise (kamera jede s ním nahoru), roof checkpoints (checkpoint_y), _swap_boxes (bedny střechy vs ulice), runneři na střeše se budí když jde doleva, bot leze po žebřících (_bot_ladder).
- Uličky do hloubky: DEEP_SPLIT (alley, warehouse, laundry, subway, market): zadní konec ujíždí, boční stěny se natahují/naklání jako ploché roviny (žádné ohýbání čar).
- Hotové kresby nepoužité zatím: 104 Bowery stanice, 105 servisní lávka v tunelu, 106 čerpací stanice (kap. III), 103 = station14 už ve hře.
- POZOR look test: na x s deníkem (page) se hra zastaví čtením → test visí.
