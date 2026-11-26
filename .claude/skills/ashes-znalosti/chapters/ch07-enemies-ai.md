# Chapter 7: Enemies & difficulty

## Core Idea
Enemies are a squad with roles that must be fair (same floor, on screen, no spawn fire) and must scale with Frank's growth chapter by chapter.

## Fairness gates
- `_same_floor` (FLOOR_REACH 400 from `_ground_y`, where Frank last stood) gates `_can_see`, `_fire`, `_throw_stick`.
- `_can_see(m)`: on screen in x and y, not far below Frank – gates fire and marksman aim.
- No fire right after spawn/checkpoint.
- Max two shooters at once, director, callouts.

## Squad AI (main.gd `_enemies`)
- Roles, flank, cover, morale. `_seek_cover`: post/tommy seeing Frank from > 500 px walks to a crate/drum within 650 px on his side (not near Frank, not taken; not prologue).
- `_covering_crate`: Frank crouched > 1 s behind a **wooden** crate → up to 2 men chip it apart (~8–10 s), "SHOOT THROUGH IT!". Steel is never shot at.
- `_send_round` / `_going_round`: lead sends the furthest of a group ≥ 3 round the back after cover_t > 3.5 s (off-screen 3.5–5 s, runs in with "!"); once per 22 s; `_flank_ok` excludes ch I maps 0–1, rooms, dream, moving, roofs.
- Barks (`barks.gd`, `_bark`): every non-boss man has a name (NAMES, none from the story); `_witness` – the nearest of his own shouts the fallen man's name ("HE GOT VINNIE!", bubble clamped to the screen edge when off-screen) and fires sooner; last man calls the fallen, lead sends men by name, empty reload → "HE'S EMPTY!", long hiding → taunt. One voice at a time (1.6 s, urgent 0.6 s) + per-kind gap `BARK_GAP`. {p} = MALONE / DOYLE.
- `_go_close` flanker stops 470–550 px off, never on Frank's crate, no two on one spot.

## Men as people (rule 42, 26. 11., playground only: `_human()`)
- Tool: `--test=watch:x[@y] --film=T,step,n --ailog` (+ `--wduck=a,b`, `--wshoot=t`, `--wlen=t`). Look at the strip before and after any AI change; `--nohuman` = the old behaviour beside it.
- `shot_at` (set in `_fire` for every seen man within 210 px of the bullet's line) -> `cower` (duck 0.55, no fire), bark "whizz", down behind cover longer, or `_seek_cover` again / a step back (`sought_t`: at most every 5 s).
- `step_due` after each shot -> a new `wander`/`home` 100-230 px off (`_step_free`); the shotgun closes to 520 only when about to fire (cool < 0.7), else gives ground to 820.
- `aim_v`: the aim vector eased toward Frank (1 - exp(-6 dt)); shots leave along the puppet's aim, so they trail a moving Frank.
- Cover: up 0.95-1.5 s, down 0.7-2.4 s, `peek` 25 % (duck 0.5, no shot, 0.45-0.8 s).
- Unseen: `at_ease`, `idle_face` flips every 2.5-6 s; `alert_t` from a friend's "!" starts his own "?".
- NEXT ideas (not built): wounded men back off and call it; a man whose friends are all down breaks and runs / gives up sooner; push when Frank reloads (bark "empty" exists) as a real rush; talk between men before the fight; tokens per gun category (research ch04).

## Enemy types by chapter
ch I mobsters (fedora/homburg/cap) and boxer; ch II hook men, dynamite throwers, marksmen (red sight line), crane loads; ch III police: shield + flashlight (finds Frank in the dark), police marksmen; bosses Mickey (club), Kessler (office), Briggs (cap can be shot off).
- Each kind reads by its clothes (18. 11., user: "make new characters so they differ"): main.gd OUTFIT / COP_OUTFIT pick art/mobster/<outfit>/ (gen/outfits.py: Gemini redraws the plain suit's parts sheet, cut back onto the same rig). Plain dark suit = gunman; pale pinstripe + white tie = tommy gunner (torpedo); black leather coat, roll-neck, a bit bigger = shotgun/hook/dynamite (docker); white dinner jacket = mob boss; navy uniform = patrolman (ch III post/shotgun/sniper/shield; ch III tommy gunners and Briggs in plain clothes). No colour tints per kind any more. The 1931 memory keeps its shadow men (the arsonists).
- Boss last third (QUEUE §16 D, 18. 11.): main.gd _boss_last_third at hp <= BOSS_HP/3 - Teague drops both pistols (they fly), becomes type "hook" (_hook_man: fists), and throws whiskey bottles (art/props/bottle.png, _throw_bottle/_tick_bottles) when Frank is on another floor (the club's gallery); Kessler retreats (e["retreat"]) to the far wall of his room and fires 0.55x the cooldown ("frantic"); Briggs's shield takes BRIGGS_SHIELD = 12 rounds and is torn off (_shield_off: e["shield_off"], _shield_stops false, he turns faster). Check: --test=lineup --chapter=3 --map=4 --shieldoff.
- THE DREAM has no gunmen (user 18. 11.: "the workers who burned there, as shadows/souls like Alan Wake 2; they need not shoot"): main.gd kind "shade" (every non-boss there) - a dock worker's silhouette (cap + docker outfit, near-black, ember contour puppet.rim_line, ember eyes as a separate node, smoke off him), no gun (disarmed, arms reach), lurches at Frank, a touch burns 1 hp (cool 1.3 s), out of Frank's sight jerks up to 300 px nearer in a puff of soot, no barks/marks, no blood: ash + sparks, dies into a burst of ash. Check with --test=lineup.

## Non-lethal outcomes
- **Surrender / let go**: `state == "give"`; execution scores nothing and ends the streak; letting go gives XP (guilt/ash system).
- **Disarm** (`_disarm`, `_tick_flying_guns`): forearm hit in slowed time (or OPEN HAND perk) → sparks, CLINK, gun spins away and lies flat (tommy/shotgun become pickups), "MY HAND!", hands up after 0.7 s, +150.
- **Hats** (`hat_hit`, `lose_hat`, `_hat_off`): bullet through hat-not-head pixels (top 40 % of crown counts) → `<head>_bare` swap, hat spins and stays, flinch + hold fire 1.2 s, "MY HAT!", +100 HAT TRICK. Police caps too.
- Dive kick (Frank only): man knocked flat, one bullet finishes him.

## Difficulty
- `main.gd CURVE` (`--test=curve --step=N`): prologue Eddie full strength; Frank weak, mob grows map by map (density per 10k px, toughness, aim, pace, shooters, heavy guns). `DIFFICULTY` easy/normal/hard on top.
- Readability: enemies against dark walls need rim light / lighter wall behind (open Gemini audit point).

## Key Takeaways
1. Any new enemy behaviour passes the three gates: same floor, on screen, not right after spawn.
2. Pressure Frank out of cover (chip wood, flank) instead of buffing accuracy.
3. Non-lethal choices feed the story (guilt) and XP – keep them rewarding.
