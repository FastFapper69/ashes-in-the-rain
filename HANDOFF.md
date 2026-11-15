# ASHES IN THE RAIN – handoff for the next session (updated 15. 11. 2026, 11:30)

Read this first when picking the project up in a new chat. Reply to the user in Czech, short. In-game text English, nothing Czech in the story, hero Frank Malone.

## Where things live
- GitHub: `FastFapper69/ink-and-lead` – `main` = sources, `gh-pages` = web build (https://fastfapper69.github.io/ink-and-lead/). The user plays on an iPhone 17.
- PC project folder: `C:\Users\super\Documents\MobileGames\Ink and Lead` (Gemini images in `art_src`, numbered; last used **140**, next is **141**).
- Docs (claude.ai): GDD `aac76a8f-a825-409f-a7d5-7834fe45049d` (tab Úkoly = task list by blocks 1–7), story doc `c223d676-08b8-42df-ae12-8f2cdf9b9dc3`, Gemini briefs `855fd524-d34d-495e-a18c-22e6eefa5dee`.
- UI rules: `.claude/skills/ui-papir/SKILL.md` (paper.gd kit, mandatory `UI BAD` audit at 1280 and 1560 wide).

## Rebuild from scratch in a new container
1. `git clone` the repo (main), download Godot 4.7.2 stable linux + export templates.
2. `godot --headless --import`
3. Web export (art/_src holds generator inputs and art kept for later; it is not exported): `godot --headless --export-release Web build/index.html` (pck must stay < 100 MB, now ~94 MB; `export_presets.cfg` exclude_filter keeps unused art out).
4. Deploy: `/home/claude/deploy.sh "msg"` (work in /home/claude/repo; the script copies repo -> this main clone, so edit files ONLY in repo). The web build goes to gh-pages under versioned names `ashes-<md5 of pck>.{pck,wasm,js,audio*.worklet.js}` (/home/claude/version_build.py) so Safari can never mix a cached old pack with a new page. HANDOFF.md lives only in this main clone.
   The container cannot reach github.io: check a deploy in the built-in browser on the user's PC (Claude_Browser preview_start, javascript_tool reads GODOT_CONFIG.executable).
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


## Metro (kap. III), 15. 11. 2026
- Kresby metra byly ve dvojnásobném měřítku (dveře 2,5 muže). Teď SEG_SIZE 0.52 (SUB) pro station14, walkway (105), bowery (104), tunnel_lo (= 67 zmenšený), signal (115), arches (116). Původní "tunnel" v plné velikosti jen v THE LAST TRAIN (střecha vlaku). Starý "platform" (66) a pump (106, 4× větší) se nepoužívají.
- TRACKLESS = pump, arches (drezína na kolejích): vlak nesmí projet v jejich dohledu (street() je vybírá mimo train_pass). Vlak jede na kolejích (spodek -170).
- street(): nikdy stejný segment dvakrát za sebou, jinak nejméně použitý.
- Horní patra zobecněná: KITS v levels.py ("roof", "mezz": scale/line/stub/y/deco/goal/under). 14TH STREET: na konci "stairs_up" (rampa se stylem "station", sprite art/props/station_stairs.png z 118, schody STAIR_FOOT→STAIR_TOP), mezipatro mezz_a/mezz_b (113/114) na y -1318, cíl u schodů ven (mezz_b 0.55).
- _block: bedny na patře nad ním (na mezipatře nad schody) ho neblokují. Bot: na horním patře doleva až když je opravdu nahoře (y < roof.y+8); u zakopaného muže po 16 s jde až k němu.

- 15. 11. ráno: podzemní mapy bez oblohy (_build_depth vrací hned), nad zmenšenými kresbami metra zrcadlený tmavší pruh klenby; mezipatro line 0.94 (navazuje na strop bez mezery); pod střechami 4 fasády tenrow_a–d (119, 120), všechny římsou na stejné výšce.

- 15. 11.: Útok trubkou (_tick_pipe: dosah 170, cooldown 6 s, puppet.swing + art/guns/pipe.png z 121; muž leží a pak se vzdá; test --test=pipe). Vnitřní hlas při hp==1 (INNER, 6 hlášek, voice/<md5>.mp3 Gravity, hud.caption, 40 s pauza, ne v prologu; look test --inner). Kesslerův kouř z puff3 (look --smoke). Instincts karty: písmo 16/14/14, kratší texty. Nad interiéry fasáda prosvítá (roof polygon alpha 0.6). Menu karta Santa Lucia místo PIER 21.


## 15. 11. 2026 – phone crashes, dream, fixes
- **Phone memory (iPhone crashed at map ends, after cutscenes, after erasing progress).** Causes and fixes:
  - Web audio decodes every stream whole: music/rain now 22 kHz mono, piano/jazz/dusk loops 110 s, rain 50 s (decoded ~230 -> ~90 MB). New long audio: keep it short and 22 kHz mono.
  - Texture streaming (main.gd `_collect_stream`/`_stream_tick`): every Sprite2D/Polygon2D using a big art/street or art/rooms drawing is listed; the texture is loaded within 2600 px of the screen and dropped past 4200 px. Under the title (`_world_off`, set in `_hide_world`) and during cutscenes (`_in_cut`) all of them are dropped. Anything that reads a street sprite's `.texture` after build must not assume it is loaded.
  - paper.gd `_baked` capped at 40 and `Paper.forget()` called in `_travel` (it grew forever across maps).
  - Measure: `--test=hops` (map after map, prints texture MB), `--texdump` with any shot test (lists textures in the tree), every `_shot` prints textures/static MB. Desktop numbers: map ~230 MB, title ~190 MB, cut ~200 MB textures.
  - Erase progress waits 0.8 s before the reload so the web save reaches storage (`menu._erase`). Test: `--test=erase`.
- **Tutorial hints** wait until a narration caption is gone (hud.gd `_captions`, `_hint_queue`, `_next_hint`).
- **Red barrels**: art/props/drum_red.png (recoloured drum), BOX_ART modulate 1.7.
- **Rain** ends at the pavement line on screen (atmosphere.gd RAIN_CUT shader + `set_ground`, splashes follow it); drops live 30 % longer.
- **Wall lamp** art without its brick patch (art/props/lamp_wall.png cut by script).
- **Fire**: art/fx/fire/anim.png = 8 hand-inked flame drawings (art_src 135, Gemini sheet 4×2, keyed on black, root fades over the lowest 13 %). main.gd `_flame()` plays them (hframes, 10–14 fps each, random start, sometimes skips a frame; `_tick_flames`). Old FLAME_SHADER removed. In the dream the post grade keeps orange fire (`atmo.set_fire_keep`). Vail Shipping window fires (setpieces FIRES, measured sills) use the same flames.
- **Shootable searchlights** (setpieces `shoot_light`, beam dead -> no longer `lit`). **Swinging pendants**: `_pendant` returns a pivot node at the ceiling, `_tick_swingers`, light reparented to swing; shot = jolt + swing dies away. Painted room bulbs (ROOM_BULBS) are shootable but do not swing (they are in the painting).
- **Art still needed from Gemini** (code primitives still on screen): searchlight drum + mast (setpieces `_add_beam` uses Line2D), pendant shade (`_pendant` uses Polygon2D), falling beam for the dream (falls back to crate_long), smoke under the dream's roof. For painted hold/laundry lamps to swing: Gemini "remove the lamp" versions of the room paintings + lamp cutouts.
- **Voices still missing**: dream panel 70 lines, dream map intro/outro, LOOP_LINES. Artlist voice settings above; quoted lines are not voiced.
- **Next**: interlude maps after ch II (1931 tenement fire) and ch III (Rosie, Eddie memory); ch IV plan; story doc update; feedback round (self + Gemini) over scaling, continuity, transitions, story, effects, UI.

- 15. 11. noon: **1931** interlude (ch II map 6, `memory: true` → `_unreal()` like the dream; laundry/market/alley streets burning, FIRES for laundry + market), cutscene `memory` (panels 87 = 1931 fire with Rourke holding young Frank, 88 = Rourke driving Frank in cuffs; art_src 136/137), title key art key_87.jpg at progress [2,5]. Map cards say "A DREAM"/"A MEMORY" and count cases without them.
- New prop art: art/props/searchlight.png (138, lens at (75,135) of the 900 px drawing; mast foot on the ground), art/props/pendant.png (139, cord stretched from region x 264..294, bulb at y 840), art/fx/fire/beam.png (140). ROOM_PENDANTS: swinging lamps hung in the warehouse room painting.
- AI sight: `_can_see(m)` (on screen in x and y, not far below Frank) gates enemy fire and marksman aim. Roof checkpoint: `_ground_cp` keeps the street checkpoint; dying below the roof respawns below.
- **Voices recorded but NOT downloaded** (Artlist folder "Ashes in the Rain VO", 19 lines for the dream, 1931, LOOP_LINES, Mickey outro): the container cannot reach the artifacts host; fetch through the built-in browser on the PC (bundle script pattern, /tmp/bundle.js recipe in this session) when the PC is on. Mickey's outro text now says "take care of Eddie" (the provider refused "shoot").
- Self-audit 15. 11.: all maps cleared by the bot, UI audit clean at 1280/1560. Seen and left: dark gaps where rooms end (designed shadow), painted glass lamp domes in tunnels. Gemini feedback round still to do (needs the PC).
- 15. 11. Gemini feedback round (art_src/audit_screens.jpg, chat "Noir Bullet-Time Shooter Art Audit"). Done: lamp halos 2.2 -> 1.0, kegs in the Catacombs. Still open from its top 10: enemy readability against dark walls (rim light / lighter walls behind the fight), HUD joystick over cover props, contact shadows under feet/props, hard-edged inked light cones instead of soft glows, white steam squiggle, black voids in night scenes, comic words anchored to hit points. Gemini also says characters ~15-20 % small against doors/cars (not changed: scale was set with the user earlier).
- All narration voiced (dream, loops, 1931, Mickey outro) on 15. 11.
- 15. 11. Gemini round 2 (art_src/ui_screens.jpg: menus, cards, comics). Done: hud.modal() hides thumb controls under pause/diary/choice; idle stick/buttons see-through; cutscene stamp = Paper.caption top-right (no dotted text); caption corners "tr" start under SKIP; Kessler 64 at [tr,br,br], opening 83 at [tl,tl]; settings card 600 wide; map card text 26/30 brighter; puppet outline 2.8; prop contact line (_ground_shadow core); room light pools ~30 % smaller; steam puffs broad and faint.
- Deliberately NOT done (explain if asked): character scale (agreed with the user), inked light cones (the user preferred plain lamp glow), black voids (Sin City blacks are the style), redrawing AI hands in cutscene panels (needs a Gemini redraw pass per panel: 56/57/63/64/65/88 candidates), instincts board text size (cards to be redesigned to tap-to-read).
- 15. 11. 13:20: figures +18 % (main.gd FIG = 1.18, puppet fig_scale): SHOULDER, DUCK_DROP, VAULT_MAX, ROPE_REACH, cover check scale with FIG; boxes grow by FIG round their centre except "stack" and "car"; JUMP_SPEED x sqrt(FIG); SWING_BOTTOM raised by the longer arms. All 18 maps cleared by the bot. Post shader `lift` = 0.2 by default (user: only a little lighter). Inked lamp cones tried (--cones, art/light_cone_ink.png) and REJECTED by the user ("looks terrible"): do not bring them back. Test flags: --figscale=, --lift=, --cones.
