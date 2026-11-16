# Patterns that worked in this project

## Painted-size contract (BigTex / LowRes)
**When**: a drawing must use less memory without moving anything. **How**: import smaller (cap or half size), report the painted size via RS size override (`big_sizes.gd`), keep all coordinates in painted pixels. **Trade-offs**: CPU readers (`get_image`) must rescale their pixel lookups (see `puppet.hat_hit`).

## Kit-then-variant layout
**When**: more backdrop variety without breaking gameplay. **How**: generate layout on kits only, swap variants in afterwards, verify non-street lines of levels.gd are unchanged. **Trade-offs**: variants must share edges/pavement exactly.

## Texture streaming by distance
**When**: long maps with many big drawings. **How**: list sprites using big art, load within a near radius, drop past a far radius, drop all under title/cutscenes. **Trade-offs**: decode hitch (~90 ms WebP) when a drawing streams in; code must not assume `.texture` is loaded.

## One pack per page
**When**: web build too big for phone memory. **How**: base pck + per-chapter packs; a page loads only one group; a different group → fresh page with a resume key. **Trade-offs**: a reload between chapters.

## Breadcrumb crash reports
**When**: crashes you cannot reproduce on desktop. **How**: ring buffer of crumbs in localStorage + "alive" flag; next load posts the report to Supabase. **Trade-offs**: needs the PC browser/Supabase MCP to read.

## Warm-up rendering
**When**: first-use stalls (glyphs, shaders). **How**: draw them on screen at ~1 % alpha for 2 frames during map load (off-screen does nothing in Godot). **Trade-offs**: list every font/size in `specs`.

## Measure-without-bake
**When**: UI frames are rebuilt in action. **How**: `Paper.plan()` computes layout without baking; cache the scaled source. **Trade-offs**: none found; output pixel-identical.

## Template-match alignment
**When**: Gemini redraws a part (bare head, open hand) that must sit exactly on the old one. **How**: template match on a stable feature (face, sleeve), cut by a hand-drawn polygon (`gen/tools/align_head.py`). **Trade-offs**: needs one redraw per head.

## Test mode per mechanic
**When**: every new feature. **How**: a `--test=<name>` that stages and photographs it. **Trade-offs**: the list grows – keep ch02 current.

## Fair-pressure AI
**When**: player camps in cover. **How**: chip wooden cover, send a flanker after a delay, cap shooters at two, gate on floor and screen. **Trade-offs**: tuned per chapter (not in tutorial maps).
