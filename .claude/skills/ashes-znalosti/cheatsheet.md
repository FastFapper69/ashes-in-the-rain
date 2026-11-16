# Cheatsheet – decide fast

## Before you ship (every change)
| If you changed… | Then |
|---|---|
| anything visible | zoomed screenshots, look yourself; UI at 1280 + 1560, zero `UI BAD` |
| movement, scale, cover, AI | bot clears all maps |
| a map | prop logic check, lamps rule, same-floor rule, camera per floor, no spawn fire |
| an audio file | ffprobe: 22050 Hz mono if long |
| a texture | read via get_image? → no Basis. > 2048 px? → BigTex + `gen/basis_imports.py` |
| pack contents | split-build test with `--main-pack` + `--packs` |
| narration text | re-record voice (md5 key) |
| commit/deploy | `git fetch` both clones, merge origin first |

## Decision rules
- Need visible art (mast, shade, beam)? → Gemini drawing, never Line2D/Polygon2D.
- Light without a painted source? → add the source or drop the light.
- Enemy can shoot? → same floor AND on screen AND not just after spawn.
- Frank camps behind cover? → wood: chip it; groups ≥ 3: flank. Never bullets through cover.
- Pickup? → into the coat, never auto-equip.
- Deep view slide? → only if its ground ends inside the cut-out.
- Street variant? → ≥ 25 % different above the floor, same edges, never next to its kit.
- User already decided it (§1.9 of SKILL.md)? → do not propose it again.

## Numbers
| Thing | Value |
|---|---|
| Figure scale FIG | 1.18 (jump speed × √FIG) |
| Post `lift` | 0.2 |
| Lamp halo | 1.0 |
| FLOOR_REACH | 400 px |
| Texture stream load / drop | 1100 / 2200 px |
| BigTex cap | 2048 px, Basis dims multiple of 4 |
| devicePixelRatio cap | 2 |
| Paper `_baked` cap | 40 |
| Combo gap / max | 2.5 s / ×5 |
| Score multipliers | head ×2, air ×2, slowed ×1.5, blast ×1.5, ricochet ×2 |
| XP curve | 2500(l−1) + 250(l−1)² |
| XP bonuses | disarm 150, hat 100, clash 50, let go 250 |
| Pipe | reach 170, cooldown 6 s |
| Flank | group ≥ 3, cover_t > 3.5 s, once / 22 s |
| Seek cover | sees Frank > 500 px, cover within 650 px |
| Hitch log threshold | 90 ms |
| Packs (MB) | base 51, a 48, b 19, c 36 |
| Cut panel | 1920×815 |
| Viewport | 720 high, 1280–1600 wide, margin 48, gap 16 |
| Voice | Gravity, speed 0.9, stability 0.35, 64 kbps mono, −16 LUFS |

## Smells
- "Looks like a Flash game from 2010" → vector/procedural art crept in.
- Crash with no JS error → memory (check heap/textures in the last crumbs).
- 100+ ms hitch on a kill → something bakes/rasterises on the spot (Paper, glyphs, decode).
- User says "almost everything was wrong" in an interior → scale, feet, floating stairs, lamps – re-audit all.
