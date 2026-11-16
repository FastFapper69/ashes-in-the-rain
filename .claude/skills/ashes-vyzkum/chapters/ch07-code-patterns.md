# Chapter 7: Code patterns

## Core Idea
Robert Nystrom's *Game Programming Patterns* (free online) names the handful of patterns that keep a growing game fast and editable. Ours is a 360 KB `main.gd`; the patterns show where to cut it without a rewrite.

## Patterns that fit
- **Object Pool** (optimisation): create objects up front and reuse them – used for entities, visual effects and even playing sounds. Fits: ghost trail, bullets/tracers, casings, ink FX sprites, kill words. Avoids node churn and allocation spikes on the web.
- **State** (design): each state is an object with enter/update/exit. Fits: enemy states (post, around, give, cover) and Frank's `move_state` – fewer cross-cutting `if move_state in [...]` checks.
- **Component** (decoupling): split one big class into parts that own one domain. Fits: move AI, scoring/XP, rope logic, streaming out of `main.gd` into their own scripts the way `mapfx.gd` and `setpieces.gd` already were.
- **Dirty Flag** (optimisation): recompute derived data only when inputs change. Fits: Paper layout (`Paper.plan` already does this in spirit), HUD texts.
- **Event Queue / Observer**: decouple "a kill happened" from score, sound, music stems, crumbs.
- **Spatial Partition**: only if enemy/prop counts grow – queries like `_seek_cover` within 650 px.

## Rules
- [H] Refactor only with the bot over all maps before/after and identical screenshots (the user hates regressions).
- Pool first where the phone suffers (FX in big fights), split files second.

## Key Takeaways
1. Pool what is created many times per second.
2. Move whole domains out of `main.gd`, one at a time.
3. Prove no behaviour change with the bot.
