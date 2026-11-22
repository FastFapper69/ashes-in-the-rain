# Chapter 8: Player & progression

## Core Idea
A "2D Max Payne": slowed time, dives, style kills. Frank starts weak and grows through XP levels and bought upgrades; style (air, head, slowed time, streaks) is what earns XP.

## Controls (phone)
Fixed sticks (no floating joysticks), jump right beside the aim stick, dive and bullet-time button side by side above it; touch-to-aim instead of a fire button; first joystick tap never fires. Desktop: A/D, mouse, Shift slowed time, W/Space jump, E/Ctrl dive, S/C slide/crouch, Q switch gun. "skok plavmo" was renamed "úskok".

## Moves
- `FIG = 1.18` (figures +18 %): SHOULDER, DUCK_DROP, VAULT_MAX, ROPE_REACH, cover checks scale with FIG; JUMP_SPEED × √FIG; boxes grow except "stack" and "car".
- Puppet (`puppet.gd`): parts posed by code; `air_v` drives jump pose (push-off, tuck, legs reaching, coat flies), dive coat `skirt_fly`, running/air coats crossfade, open hand `farm_open`. Smooth vault (no bounce). Eddie: `short_coat`.
- Ropes: climb up fire escapes, zip lines (one hand, gun out, slowed time), crane swings; `Chunk.rope(kind,…)`, `_grab_rope`.
- Pipe melee (`_tick_pipe`, reach 170, cooldown 6 s). Bullet clash (shoot bullets out of the air, +50). Ricochet off steel (dashed line in slowed time). Inner voice at hp 1 (not in prologue).

## Score → XP → levels
- `_score`: base 100, ×2 head, ×2 in the air, ×1.5 slowed time, ×1.5 blast, ×2 ricochet (0.7 s), × streak 1..5 (COMBO_GAP 2.5 s; a hit on Frank ends it). HUD `hud.combo`.
- XP from style points, disarm 150, hat 100, clash 50, man let go 250; saved on map clear, a death loses the run's XP. `xp_for(l) = 2500(l-1) + 250(l-1)^2`, 1 point per level, cards cost 1. Level-up = small tape at the top 1.8 s.
- Rows: FRANK (TOUGH/TOUGHER/IRON +1 hit each, LONG WATCH, LAST CHANCE), GUN (FAST HANDS, HEAVY LOADS, STEADY HAND, LAST ROUND, TWO GUNS), TRICKS (OPEN HAND, HOT STREAK, SPLINTERS, ACROBAT, SECOND WIND). `Instincts.has_fx(id)` / `_perk(id)`. Stars were replaced (still marked in the case file).

## Guns
- Revolver always + ONE big gun (shotgun ch II, tommy ch III: `GUN_FROM`, `_gun_open()`). Pickups never auto-equip; swap by tapping the gun card at the gun on the ground. GTA-style card right of the health bar (`hud.set_guns`), switch animation `puppet.switch_to()` 0.3 s.
- Gunsmith (`menu._gunsmith`): rows gun/shotgun/tommy, `SMITH_PARTS`. Two pistols via TWO GUNS.
- Gunsmith acts (`SMITH_ACTS`, `_smith_act`, 17. 11.): each upgrade shows what it does on the gun (revolver: cylinder opens, cases out, rounds in; recoil; steady; last round. Beretta: magazine out/in, long mag). Rule 28: the open revolver is composed per part from worn/new x loaded/empty drawings (`art/ui/gunsmith/open/`, gen/open_revolver.py) so it always matches the closed gun's parts. Words go through LowRes on their own CanvasLayer; tweens live on the gun node (quick taps). Test: `--test=gunsmith --gun=gun --pick=N [--buy] [--mash]`.

## Key Takeaways
1. Reward style, not grind: every multiplier is a skill expression.
2. HP/damage are purchases; nothing grows automatically.
3. Any change to body size or jumps → re-run the bot on all maps.

## Save: checkpoint and evidence (audit 22. 11.)
- The last checkpoint of the map being played is in the save (`menu.gd save_cp/saved_cp/clear_cp`, section "checkpoint": map, x, y, ground, keep = `_cp_keep`). `main.gd _start_map` (CONTINUE or the case file) and a fresh page (`take_resume`) restore it through `_saved_cp()`; `_map_cleared` clears it. Not in tests or sandboxes.
- The prologue is marked done when Eddie goes down, before the last comic.
- `evidence_total()` counts what exists: a page per map with a `diary`, a statement per `main.gd TESTIMONY` key, ready chapters only (30 now). The diary's "PAGE N OF M" counts only maps with a page.
