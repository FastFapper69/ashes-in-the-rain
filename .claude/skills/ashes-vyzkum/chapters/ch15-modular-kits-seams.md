# Chapter 15: Modular kits, joins and transitions between scenes

Researched 2026-11-17 after the user: "we need to polish the game so the breaks between scenes do not show so much"
(photos: street → hallway 3A with a hard vertical cut, no entrance; hallway 3C pasted beside the TAILOR street;
window straight into an open alley; alley deep view sheared). Rules 24/25 in `ashes-znalosti` came out of the same day.

## Core Idea
A modular world reads as one place when (1) every piece obeys the **same metrics** (floor line, eye level, door
size), (2) pieces only meet along **edges that are declared compatible**, (3) every change of *kind of space* goes
through a **drawn threshold** (door, gate, arch, stairs, facade), and (4) repetition is broken by variants, props and
light – never by patches. Bethesda, Dead Cells, Spelunky, Trine and Hollow Knight all do some mix of these four.

## Frameworks

### 1. Kits and metrics first (Bethesda – Burgess & Purkeypile, GDC 2013/2016)
- A kit = pieces built on one footprint/grid so they snap. Two kit artists made 7 kits (50+ pieces each) and level
  designers built ~400 unique cells from them.
- **Lock pivots, footprints and transition metrics first, polish visuals last** – metrics are hard to change once
  levels exist.
- **One standard doorway/portal system across all kits** – the same door logic everywhere lets kits combine.
- Anti-repetition: interoperable variants and props across kits; do not tie a kit to one light/enemy/culture;
  "floating" sub-kits that hide the grid. **Anti-pattern: patch pieces** that break the kit's logic.
- Equilateral kits are the most versatile and the most repetitive; decide early what tiles in which direction.

### 2. Edge contracts (Wang tiles)
- Each edge of a piece gets a "colour"; two pieces may touch only where their shared edge has the same colour.
- Several pieces with the same edge colours = non-periodic variety for free (10 different grass tiles, same edges).
- For us the "tile" is a whole street drawing and only the left/right edges matter.

### 3. Level graph + hand-made rooms (Dead Cells, Spelunky)
- Hand-built room templates; a **concept graph per biome** places entrance and exit first, then special rooms, then
  combat/exploration rooms; the generator tries random rooms from that biome's pool until one matches the node's
  entrance/exit count, position and type. Rooms belong to one biome only.
- Spelunky: each room type (e.g. "has left+right exits") has 8–16 templates; the exits are guaranteed, the inside
  varies.

### 4. Composition, layers, seams (Frozenbyte's Trine level-art wiki, Hollow Knight)
- Break the 2D plane with overlapping elements and flows into depth; don't align roads/houses/walls exactly with
  the play plane; **tie background, gameplay and foreground together** – keeping gameplay art separate from the
  background usually works worse. Don't leave the foreground empty.
- Only the gameplay area must match collisions exactly; elsewhere organic shapes / another material hide angular
  shapes. Avoid repetition of shapes, silhouettes, details and **light placement**; mix detailed and nearly empty
  areas; never place things on a grid.
- Hollow Knight: foreground / middle ground (play) / background, background stacked in layers; middle ground has
  stronger contrast and thicker outlines so figures read. It loads **one room at a time** and moves between rooms
  through gates/edges with a fade – discrete rooms are cleaner than a continuous world with visible joins.

### 5. Thresholds and transition zones (Disney "transition zones", squeeze holes, airlocking)
- Between two themed lands Disney puts a transition zone (a covered bridge, a planted berm) so there is no
  "thematic whiplash".
- Games use squeeze gaps, doors, corridors and elevators as thresholds; level transitions go in **down-time between
  fights, at a natural chokepoint**.
- Fallback when no threshold exists: fade out → move → fade in (Metroid door), or an animated door opening.

### 6. Outpainting for continuous joins
- Generating piece B by **extending the edge of piece A** (outpainting) keeps light, style and perspective
  continuous; tools blend the overlap (Poisson blending) and only extend horizontally (vertical would change the
  game height). Gemini image models do outpainting well.

## Apply to Ashes (proposals; [H] = try in TEST LAB and measure, nothing here overrides `ashes-znalosti` §1)
1. **Metrics sheet for every drawing** [H, cheap]: floor/walk line y, curb top, eye level (horizon) y, door height
   and width, cornice y – one table in gen/kit.py. Gemini briefs give these numbers + a grey template (the Blender
   blockout from QUEUE §8 is exactly this). Same eye level everywhere = deep views and alleys stop "veering"
   against each other. Audit: refuse a drawing whose measured floor/eye line differs.
2. **Edge colours on street drawings** [H]: each drawing's left/right edge gets a type – `party_wall` (dark wall,
   the hk_* standard), `alley_mouth`, `facade_door` (a building we can enter), `open_lot`, `fence`, `water`.
   `street()` in gen/levels.py may join only equal types; audit_maps.py errors otherwise. More drawings per edge
   type = more variety without new rules.
3. **A threshold kit** (rule 25): one drawn piece per change of kind – facade with a street door (into the
   cross-section), alley mouth with a gate/arch, yard gate, subway stairs, dock fence gate, warehouse loading door.
   Standard opening size across kits (Burgess portals) so any interior fits behind any facade door. Interiors only
   ever start behind a facade door of the SAME building.
4. **Joint pieces over joins** [H]: a narrow drawn pier/drainpipe/lamp post that belongs to the wall (stands on the
   drawn curb, rule 22) placed over a join, like the hallway joints already sit on a pipe/post. Must pass rule 23
   (screenshot against the picture) – the user rejected floating foreground silhouettes, so only things that
   stand on drawn ground.
5. **Map = graph of spaces** (Dead Cells): street → alley mouth → yard → back door → stairwell → flat → window →
   own fire escape → roof. Each node picks a drawing from its pool whose edges/openings match; rule 25 is then
   true by construction, and the audit only double-checks.
6. **Outpaint the neighbour** [H]: for pieces that must meet (left end / middle / right end of a street block, a
   facade and its alley mouth) give Gemini the right 20–30 % of A and ask it to continue; cut at a vertical drawn
   element; optional Poisson blend on a 64 px overlap (small tool gen/tools/blend_seam.py). Compare seam scores
   (audit_maps.py SEAMS) before/after.
7. **Variety without patches**: variants (≥25 % different, already a rule), different props, different light
   states per drawing (lit window/dark window, wet/dry), weather; never the same light placement twice in a row.
8. **Unavoidable change of scene = drawn door + comic transition**: fade or an ink wipe at the door, only when no
   enemy is active (airlocking at a chokepoint). Never a cut in the middle of open ground.
9. **Discrete beats continuous where art cannot join** (Hollow Knight): if two pieces cannot honestly meet, end the
   space at a door and load the next one behind it rather than placing them side by side.

## Anti-patterns
- Pasting an interior drawing at the end of a street drawing (what the user saw: 3A, 3C).
- A deep view or alley that moves/warps on its own (rule 24) – perspective mismatch is fixed by shared eye level,
  not by shaders.
- Patch pieces: a black strip, a sticker wall, a fog blob to hide a join (Burgess: undermines the kit).
- Uniform scatter: props at equal spacing read as a grid even when "random".
- A transition while enemies are active.

## Key Takeaways
1. Metrics first (floor, eye level, door) – the same numbers in every brief and every drawing.
2. Pieces meet only on matching edge types; more pieces per type = variety.
3. Every change of kind of space passes a drawn threshold; one standard opening size.
4. Build maps as a graph of spaces, not as a strip of pictures.
5. Outpaint neighbours so joins continue; hide the rest at drawn verticals; never patch.
6. Where art cannot join, end at a door and fade – discrete is better than ugly continuous.
