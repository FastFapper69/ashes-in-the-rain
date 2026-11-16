# Chapter 3: Combat feel & bullet time

## Core Idea
Bullet time is fun when the world slows but the player's aim does not, bullets are visible objects, and style is rewarded. "Juice" is a stack of small, tuned feedbacks – a few done well beat many done badly.

## Frameworks
- **Max Payne bullet time**: Scott Miller's key point – slow the game, keep aiming real-time. Bullets are physical projectiles (no hitscan), which is what makes slowed time worth looking at. Shootdodge became 360° by blending eight dive animations. Slow-mo covered a radius around the player (one reason multiplayer was dropped).
- **My Friend Pedro**: focus (slow-mo) refills on kills; one critic felt it slowed things a bit too much and became a crutch; the solo dev added time pressure *because* you can slow time ("gives slow-mo a practical use"); split aim; environmental tricks (ricochet off a pan).
- **Katana ZERO**: slow-mo + dodge roll + one-hit deaths; rooms become action puzzles.
- **Juice (Vlambeer, "The Art of Screenshake")**: in order of the talk: animation & sound, lower enemy HP, bigger/faster bullets, muzzle flash, less accuracy, impact effect, hit animation, knockback, permanence (corpses, shells, smoke), camera lerp/kick, screen shake, sleep (hit pause), more bass, slow motion. Rule from later writers: not one uniform shake for everything – feedback must stay information.
- **Gun-fu clarity (John Wick)**: choreography trained like dance; the camera shows the hit landing on the man (no fast cuts); action is motivated by the story.

## Status in Ashes
- [OK] projectile bullets, bullet clash, ricochet, hitstop (`_impact`), shake only on blasts/collapses, permanence (casings, holes, corpses, hats on the pavement), kill words at impact, ACROBAT perk refills slowed time on air kills.
- [H] small base refill of the slowed-time meter on any kill (perks increase it) – test that it does not become a crutch (Pedro critique): measure % of fight time spent slowed with the bot and on the user's playtest.
- [H] map moments with time pressure (train, flood already exist) are where slowed time feels best – add one per chapter.
- [H] in slowed time pull the camera so shooter and target are both in frame (Wick clarity), never cut.

## Anti-patterns
- Hitscan or invisible enemy bullets in slow-mo.
- One shake/flash for every event.
- Slow-mo that the player can keep on all the time.

## Key Takeaways
1. Real-time aim, slowed world, visible bullets.
2. Reward style with time and points.
3. Tune 3–4 feedbacks hard instead of adding all of them.
