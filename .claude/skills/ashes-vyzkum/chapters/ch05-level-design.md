# Chapter 5: Level design & pacing

## Core Idea
A good map is built around one idea that is introduced safely, developed, twisted and concluded; failure must be cheap so players experiment.

## Frameworks
- **Kishōtenketsu (Koichi Hayashida, Mario)**: Ki – introduce the mechanic where failure costs nothing; Shō – develop it with risk; Ten – a twist that makes you use it differently; Ketsu – conclude using what was learned, then the game drops the idea.
- **Teach through the level, not text** (Katana ZERO previews: each level adds a factor naturally rather than a text box).
- **Instant restart** (Hotline Miami, Katana ZERO): death costs a breath – no load screen, no penalty animation, no long walk back – which creates a rhythm of retry.
- **Permanence** (Vlambeer): the world remembers the fight (bullet holes, debris, corpses).
- **Time pressure gives slow-mo a purpose** (My Friend Pedro dev notes).

## Apply to Ashes
- Map template: Ki (first screen, no enemies near the new prop – e.g. neon sign chains, ropes, flood), Shō (enemies near it), Ten (it turns against Frank or combines with another mechanic), Ketsu (a short finale fight that uses it). `mapfx` flags = the map's featured idea.
- Tutorial hints stay short and come only after narration (already rule); prefer a safe first use over text.
- [H] Measure death → playable again on the iPhone (crumbs `died` → next `ready`); aim for ≤ 1–2 s, never a reload of the page.
- Difficulty curve per chapter stays (user rule): the Ten step can carry the wall.

## Anti-patterns
- Several new mechanics at once on one map.
- Invisible walls instead of seen blockers (already flagged in the prologue).
- Long retry walks.

## Key Takeaways
1. One featured idea per map, four beats.
2. Cheap death enables bold play.
3. Leave marks of the fight in the world.
