# Chapter 4: Phone memory & crashes

## Core Idea
iPhone Safari silently kills the tab when textures + wasm heap + decoded audio get too big. Every crash so far was memory, found through breadcrumbs, and fixed by cutting what is resident at once.

## Diagnosis tools
- `gen/deploy/crash.js` keeps the last 80 breadcrumbs in localStorage; `main.gd crumb()` logs boot, ready, every 5 s a `beat` (textures, fps, nodes, map, x, `heap=`, `worst_frame=`), cut, cleared, died, travel, reload, pack fetch, and every `hitch Nms tex +X nodes +Y` > 90 ms.
- If the previous page never said goodbye (`ashes_alive` = 1) the next load POSTs a `crash`; JS errors, Godot `SCRIPT ERROR`, WebGL context loss → `error`.
- Supabase project **PixelKrypta** `mpxfppuigwvwlfhsnbgr`, table `public.ashes_reports` (anon insert only). Read: `select created_at, kind, build, report from ashes_reports where kind <> 'test' order by id desc limit 10`.
- Local: `--test=hops`, `--test=probe`, `--texdump`, `--timing`.

## What eats memory and the fix that worked
| Cause | Fix |
|---|---|
| Web Audio decodes every stream whole to PCM | long tracks 22050 Hz mono, loops ≤ ~110 s, wav > 1.5 s → 22 kHz mono; `sfx._streams` static (was re-decoded per map) |
| Street drawings all resident | texture streaming `_collect_stream/_stream_tick`: load within STREAM_LOAD 1100 px, drop past STREAM_DROP 2200 px; all dropped under the title and in cutscenes |
| Full-resolution textures | BigTex cap 2048, Basis for streets (−36…−51 MB/map), half-size characters/FX |
| Pack held whole in wasm heap (MEMFS) | page loads only ONE pack group; Basis made pack a 68 MB → panels back to WebP (a 48, b 19, c 36, base 51 MB) |
| 3× pixel ratio full-screen passes | crash.js caps devicePixelRatio at 2; hide puppet `_shadow` when alpha 0 (CanvasGroup = screen pass) |
| Paper caches growing forever | `_baked` capped at 40, `Paper.forget()` on travel |
| Hitches 130 ms on kill captions | `Paper.plan()` measures without baking, `_scaled` cache |
| First glyph rasterisation ~100 ms | `main._warm_text()` draws fonts at 1 % alpha for 2 frames on screen at map load; add new font sizes to `specs` |

## Packs
`gen/packs.py`: base + pack a (prologue + ch I), b (ch II), c (ch III). Drawings used by one group's maps/cutscenes go into that pack. `_ready` checks `Packs.has(chapter)`, fetches (`HTTPRequest accept_gzip=false`, write to /tmp, `load_resource_pack`, reload, caption "OPENING THE CASE FILE…"); another group already loaded → `Packs.fresh_page` (localStorage `ashes_resume`). Chapter IV: add scenes to CUTS, group "d". Next step if crashes continue: pack per map.

## Anti-patterns
- Reading a street sprite's `.texture` after build assuming it is loaded (streaming may have dropped it).
- 44.1 kHz stereo music (the dream track was ~39 MB PCM and crashed).
- Menu waiting for a chapter pack before the title (was up to 68 MB).

## Key Takeaways
1. Heap ≈ base pck + loaded pack + game; textures ≈ desktop + ~100 MB on iPhone.
2. Every crash report first: what was the last crumb, heap, textures.
3. ffprobe every audio file before commit; Basis check before every new texture.
