# Chapter 6: Lights & effects

## Core Idea
Light only comes from things you can see, in their shape; effects are hand-inked sprite sheets, not procedural glows. The post grade turns warm colours cream, so flashes read light, not orange.

## Lamps & lights
- Street drawings list lamps in `SEGMENT_LIGHTS` (drawing pixels). "painted" = lamp is in the drawing, only light is added; goose/cage/lantern = `art/props/lamp_*.png` (art_src 141). Wall lamp art cut without its brick patch.
- Placement: over a shop sign or door, bare wall. Never on window, fire escape, sign.
- Halo strength 1.0 (was 2.2). Room light pools ~30 % smaller. Interiors darker; facade shows through roof polygon alpha 0.6.
- **Shootable**: painted room bulbs (`ROOM_BULBS`, break but don't swing), pendants (`_pendant` pivot, `_tick_swingers`, shot = jolt + swing dies away; `ROOM_PENDANTS` hung in the warehouse painting), searchlights (`shoot_light` → beam dead, no longer `lit`). Searchlight/headlight/flashlight beams = soft textures (`art/light_beam_*.png`, `light_cone_soft.png`, no hard ends).
- Rejected: inked light cones (`--cones`), strong amber lamp cones.

## Fire
`art/fx/fire/anim.png` = 8 hand-inked flames (art_src 135, 4×2 sheet keyed on black, root fades over lowest 13 %). `_flame()` plays them at 10–14 fps, random start, occasional skipped frame. Dream keeps orange fire through the grade (`atmo.set_fire_keep`); dream post `atmo.set_dream(0.55 + 0.25 per loop)` heat shimmer, smoke, glowing edges, colour-plate shift; `atmo.jolt()` on collapse; foreground flames `_dream_vfx`, soot `_soot`.

## Ink FX (art/fx/ink/, art_src 150–158)
flash0-7 (BIG_FLASHES for shotgun), smoke0-7 (`fx.smoke(at, vel, size, life)`), spark0-7, speed0-3 (behind dives every 0.07 s), dust0-3 (hard landings), blood0-7 (origin left-middle, rotated along the shot), tracer0-3 (tip at the slug), splash0-3 (rain). `fx.blast` = fireball stars + sparks + smoke column. Kill words (POW/CRACK) at the bullet's impact point (`_hit_at`). Steam: broad faint puffs (no white squiggle).

## Rain & grade
Rain stops at the pavement line on screen (`RAIN_CUT` shader + `set_ground`; splashes follow), only where it rains (`sfx.rain_want`/indoor). Post shader `lift` 0.2 (dark areas only slightly lighter). Prop contact line `_ground_shadow`.

## Anti-patterns
- Round blob glow for a shaped source; glow with no visible source.
- A flickering light whose painted reflection stays lit.
- Neon light on the ground.

## Key Takeaways
1. New light = name its source in the art first.
2. Use the ink FX sheets; never generate soft procedural glows.
3. Test with `--test=fxsheet`, `bulbs:x`, `look:x`.
