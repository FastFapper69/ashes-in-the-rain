---
name: ashes-vyzkum
description: "Research notes for Ashes in the Rain (2026-11-16): noir visual language (Sin City, Mignola, film noir, Max Payne), storytelling (Max Payne, L.A. Noire, Katana ZERO), combat feel and bullet time, enemy AI (F.E.A.R., DOOM tokens), level design, Godot 4.7 web/iOS memory and rendering, code patterns, mobile controls. Use when designing a mechanic, map, story beat, art brief or optimisation."
---

<!-- argument-hint: [topic: noir art, story, bullet time, AI, level, godot web, ios memory, controls] -->

# Ashes in the Rain – research notes
**Built**: 2026-11-16 with the book-to-skill structure (index + on-demand chapters). **Content**: our own conclusions from public sources (links in `sources.md`), checked against the code where noted. Nothing here overrides the user's decisions in `ashes-znalosti` §1 – where research disagrees with a decision, the decision wins and the note says so.

## How to use
Pick the chapter for the task. Every idea marked **[H]** is a hypothesis: measure before and after (fps, texture MB, heap, bot clears) and keep it only if the numbers say so. **[OK]** = the game already does this – keep it.

---

## Top 12 takeaways
1. **[H] CanvasGroup is a backbuffer pass.** Godot's CanvasGroup draws its children by reading the back buffer. Every puppet body is one, and the dive/slowed-time trail (`main.gd` ghost every 0.05 s, ~0.26 s life) adds ~5 more brand-new CanvasGroups + Sprite2Ds per second. Prime suspect for FPS 31–42 in big fights → pool the ghosts or draw them as plain silhouettes; only use a CanvasGroup when a figure is actually translucent. ([[ch06-lights-fx|ch06]])
2. **iOS kills a page at roughly 300–450 MB** (WebKit derives the limit from device RAM and jetsam; warnings at 50 % / 65 %). Fast allocation bursts are also punished. Our last crash: heap 242 + textures ~150 MB → at the edge. Smaller packs (per map), spread loading over frames. ([[ch06-lights-fx|ch06]])
3. **[OK] Web audio = Web Audio "samples"** since Godot 4.3: whole files are decoded, no audio effects. Our 22 kHz mono rule is exactly right. ([[ch06-lights-fx|ch06]])
4. **[OK] Bullet time works because bullets are real projectiles and aiming stays real-time** (Max Payne). Keep enemy bullets visible and dodgeable in slowed time. ([[ch03-art-pipeline|ch03]])
5. **Kills should feed bullet time** (My Friend Pedro refills focus on kills; our ACROBAT card does it for air kills) – [H] consider a small base refill, perk makes it bigger. ([[ch03-art-pipeline|ch03]])
6. **Death must cost almost nothing** (Hotline Miami, Katana ZERO: instant restart, no load, no penalty animation). [H] Measure our death → respawn time on the iPhone; target well under 2 s. ([[ch05-levels-maps|ch05]])
7. **[OK] Max two shooters = DOOM's attack tokens.** [H] Extend to tokens per category (rifle 2, thrower 1, heavy 1) with "steal", and tune difficulty by token counts rather than aim. ([[ch04-phone-memory|ch04]])
8. **[OK] Callouts make AI look smart** (F.E.A.R.): the barks, not the planner, sold the intelligence. Every new behaviour gets a line ("FLANK HIM!", "SHOOT THROUGH IT!"). ([[ch04-phone-memory|ch04]])
9. **Black first, as shapes** (Mignola, Miller): solid black masses placed for composition, few mid-tones, balance black against equal white. Briefs for Gemini should ask for this, not for "dark". ([[ch01-build-deploy|ch01]])
10. **Noir light is motivated hard light**: one hard source, little fill, practicals in frame (lamps, neon), venetian-blind patterns only where a window is. Matches our "every light has a source" rule. ([[ch01-build-deploy|ch01]])
11. **One mechanic per map, taught without text** (kishōtenketsu: introduce safely → develop → twist → conclude; Katana ZERO teaches through levels). Our mapfx flags are the natural "featured mechanic". ([[ch05-levels-maps|ch05]])
12. **Clarity over chaos** (John Wick): wide framing so cause and effect are visible; rhythm like a dance. Keep shooter and target in frame in slowed time. ([[ch03-art-pipeline|ch03]])
13. **Anticipation is for enemies, not for the player** (Cooper, Game Anim): the player's move starts on the input frame, follow-through runs only until the next input; enemy windups are the telegraph. ([[ch16-animation-principles|ch16]])

---

## Chapter index
| # | Topic | Covers |
|---|-------|--------|
| [ch01](chapters/ch01-noir-visual-language.md) | Noir visual language | Sin City, Mignola, film noir lighting, Max Payne panels, Gemini brief rules |
| [ch02](chapters/ch02-storytelling.md) | Storytelling | Sam Lake / Max Payne, L.A. Noire lessons, Katana ZERO & Hotline Miami framing |
| [ch03](chapters/ch03-combat-feel.md) | Combat feel & bullet time | Max Payne, My Friend Pedro, Katana ZERO, juice list, gun-fu clarity |
| [ch04](chapters/ch04-enemy-ai.md) | Enemy AI | F.E.A.R. barks/squads, DOOM tokens & push-forward, fairness |
| [ch05](chapters/ch05-level-design.md) | Level design & pacing | kishōtenketsu, teaching without text, instant restart, permanence |
| [ch06](chapters/ch06-godot-web-ios.md) | Godot web & iOS | web export facts, iOS memory, CanvasGroup, time_scale, textures, audio |
| [ch07](chapters/ch07-code-patterns.md) | Code patterns | object pool, state, component, dirty flag – where they fit main.gd |
| [ch08](chapters/ch08-mobile-controls.md) | Mobile controls | thumb reach, forgiveness (coyote/buffer), auto-aim |
| [ch09](chapters/ch09-skills-and-tools.md) | Anthropic skills & tools | which of anthropics/skills help us, reader testing, web-build check, craft-anything likeness check, skill writing rules |
| [ch10](chapters/ch10-animate-cutscenes-trailer.md) | Cutscene craft & trailer | cth9191/animate: silence→loudest hit, voice as clock, word timing, contact sheets, Godot Movie Maker trailer |
| [ch11](chapters/ch11-claude-code-on-pc.md) | Claude Code on the PC | Godot MCP (runtime screenshots/input), GdUnit4, hooks, TokenEconomizer |
| [ch12](chapters/ch12-licences-stores.md) | Licences & stores | Artlist licence for games (Enterprise!), ElevenLabs, Gemini watermark/ownership, AI disclosure |
| [ch13](chapters/ch13-business-release.md) | Business & release | premium vs free-to-start, subscriptions, native iOS needs Mac+Xcode, haptics |
| [ch14](chapters/ch14-camera-telemetry-accessibility.md) | Camera, telemetry, accessibility | Keren camera techniques, death heatmaps/funnels, subtitles, assist mode |
| [ch15](chapters/ch15-modular-kits-seams.md) | Modular kits, joins, transitions | Bethesda kits & metrics, Wang edge types, Dead Cells graph, Trine/Hollow Knight layers, thresholds, outpainting joins |
| [ch16](chapters/ch16-animation-principles.md) | Twelve principles of animation | Thomas & Johnston, Cooper, Totten: each principle, what our puppet does, [H] gaps, checks for the poses audit |

## Topic index
- **attack tokens** → [[ch04-phone-memory|ch04]] · **backbuffer / CanvasGroup** → [[ch06-lights-fx|ch06]] · **barks / callouts** → [[ch04-phone-memory|ch04]]
- **black shapes / spotting blacks** → [[ch01-build-deploy|ch01]] · **bullet time** → [[ch03-art-pipeline|ch03]], [[ch06-lights-fx|ch06]] · **coyote time** → [[ch08-player-progression|ch08]]
- **death & restart** → [[ch05-levels-maps|ch05]] · **gobo / venetian blinds** → [[ch01-build-deploy|ch01]] · **heap / jetsam** → [[ch06-lights-fx|ch06]]
- **hitstop / screenshake** → [[ch03-art-pipeline|ch03]] · **interrogation (L.A. Noire)** → [[ch02-tests|ch02]] · **kishōtenketsu** → [[ch05-levels-maps|ch05]]
- **narration / monologue** → [[ch02-tests|ch02]] · **object pool** → [[ch07-enemies-ai|ch07]] · **Parallax2D** → [[ch06-lights-fx|ch06]]
- **texture compression (Basis, ETC2)** → [[ch06-lights-fx|ch06]] · **web audio samples** → [[ch06-lights-fx|ch06]]
- **skills / tools / web build check / reader testing** → [[ch09-audio-voice|ch09]]
- **cutscene pacing, voice timing, trailer** → [[ch10-story-cutscenes|ch10]]
- **Godot MCP / hooks / unit tests** → [[ch11-ui-hud|ch11]] · **licences, Artlist, AI disclosure** → ch12 · **business model, native export, haptics** → ch13 · **camera, heatmaps, accessibility** → ch14
- **modular kit / metrics / edge types / seams / threshold / transition between scenes / outpainting** → ch15
- **animation principles / squash / anticipation / follow-through / telegraph / arcs / timing / silhouette / twins** → ch16

## Supporting files
- [cheatsheet.md](cheatsheet.md) – decision rules distilled from all chapters
- [sources.md](sources.md) – every source with a one-line note

## Scope & limits
Public articles, official Godot docs (CC BY 3.0, read from the godot-docs repo @2c6cc13) and developer interviews. No book text is reproduced. Numbers from third-party articles are approximate – our own crumbs on the iPhone are the ground truth.
