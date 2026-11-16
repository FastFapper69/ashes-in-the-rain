# Chapter 3: Art pipeline

## Core Idea
All visible art is hand-drawn-looking Gemini output processed by scripts in `gen/`; code never draws visible art. Every drawing has a pixel contract (sizes, anchor points) that import tricks must preserve.

## Gemini on the user's PC (computer use)
- Request access to both gemini.exe paths (`computer_resolve_access` → `computer_request_access`).
- **New Gemini chat for every redraw** – editing in the same chat drifts to its last version. Upload the reference (+ / Nahrát soubory), ask for a NEW drawing, reference for style only.
- Download: hover → download icon top right → save as `…\art_src\NN.jpg` (next free number) → `device_stage_files` into the container.
- Cutscene panels 1920×815 (Gemini 3168×1344 = same ratio, plain resize).
- Black-keyed FX sheets (fire 4×2, ink fx 8 frames) are cut by script; sheets on white are keyed accordingly.

## Processing scripts (gen/)
`process_art.py` (STREET / KIT), `process_dream.py`, `fix_cut_text.py` (real text on panels), `fix_posters.py` (1947 notices), `coat_poses.py`, `gunsmith_art.py`, `perk_icons.py`, `map_props.py`, `tools/align_head.py` (template match on the face for bare heads), `tools/feather_sky.py`, `basis_imports.py`, `bigtex_sizes.py` (superseded by basis_imports), `sfx_story.py`, `voice_lines.py`, `packs.py`.

## Kits and variants (streets)
- Kits in `gen/levels.py KIT` / `main.gd SEGMENT_KIT`. A variant keeps width/scale/pavement/edges of its kit; size, trim and props come from the kit, deep views/signs/lamps/fires by its own name.
- **Variant must differ from its kit over ≥ 25 % of the picture above the floor** (blurred 396×168 grey diff > 18). Never a kit next to its own variant; never the same segment twice in a row.
- Layout is built on kits (`plain`), variants swapped in afterwards; a same-width drawing with wall goes back under any fire escape → gameplay never moves (levels.gd non-street lines unchanged).

## Import rules (memory, see ch04)
- Street/room drawings > 2048 px: imported capped, loaded via `BigTex.get_tex()`, which reports the painted size from `big_sizes.gd` (RS size override) → all pixel coordinates stay valid.
- **Basis Universal** (compress/mode=4) for street/room drawings, `_lit/_solid`, bg, fore, big props – dimensions must be multiples of 4 (`gen/basis_imports.py` trims the cap).
- **Never Basis**: anything read with `get_image` (LowRes, Paper, hats, `sheets.png` bullet holes), normal maps, comic panels (`art/cut` back to WebP – pack heap).
- Characters/FX/lamps (`gen/lowres_paths.txt`, 140 files) import at half size; `LowRes.tex` wraps them via BigTex. Exceptions loaded directly: blood*, puff*, hole*, spark1, bulb_broken, fire/*, light_blob, crate, crate_long.
- Lossy WebP 0.85 by default (diary pages/cards 0.8), normal maps lossless, new art `compress/mode=1` unless Basis applies.
- After any new big drawing: `python3 gen/basis_imports.py`.

## Anti-patterns
- Code primitives as art (Line2D masts, Polygon2D shades) – replace with a drawing.
- "Softening" character hatching – looked smudged and more AI-like; leave as drawn.
- Redrawing in the same Gemini chat.

## Key Takeaways
1. Painted size is sacred; shrink pixels, never the reported size.
2. Before choosing a texture format ask: is it read on the CPU (`get_image`)? Then no Basis.
3. Variants are art-only swaps – layout never depends on them.
