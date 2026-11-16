# Chapter 4: Enemy AI

## Core Idea
AI feels smart when it *tells* the player what it is doing and when its pressure is paced. Complex planning matters less than barks and a cap on simultaneous attackers.

## Frameworks
- **F.E.A.R. (Jeff Orkin, GDC 2006 "Three States and a Plan")**: the runtime FSM had essentially states for going somewhere and animating; goals + actions were planned (GOAP). The team's insight: communicate what the AI thinks and knows – callouts ("flanking", "covering", "grenade") made coordination visible; soldiers didn't truly coordinate, their goals combined into what looked like teamwork.
- **DOOM 2016 attack tokens (GDC 2018, Loudy & Campbell)**: a shared token pool – an enemy must hold a token to attack; tokens can be stolen (the other attack cancels). Pools are typically per target and per attack category. Used to pace pressure and to vary difficulty.
- **Push-forward combat**: a filter for every mechanic – fast movement, distinct enemy archetypes, the player's strength; enemies are resources (health/ammo) so the player attacks instead of hiding.
- **Hotline Miami**: hair-trigger enemies make every encounter a learnable puzzle; fairness comes from instant restart.

## Status in Ashes
- [OK] max two shooters (a token pool of 2), callouts, named men + witness barks ("HE GOT VINNIE!", barks.gd, 16. 11.), cover chipping on wood, flanking with a delay, same-floor + on-screen gates.
- [H] tokens per category: rifle/pistol 2, thrower 1, heavy (tommy/shotgun) 1, marksman 1; a man that loses sight of Frank releases his token; "steal" when a closer man has a clean line. Difficulty = token counts + reaction delay, not accuracy (keeps it fair and readable).
- [H] push-forward hook for Frank: men knocked down/disarmed drop rounds (ties into the gun bag) – rewards aggression over camping.
- Every new behaviour ships with a bark line (English, comic lettering).

## Anti-patterns
- Raising aim accuracy as the difficulty knob.
- Silent tactics the player cannot read.
- Shots from off-screen or another floor (our hard rule).

## Key Takeaways
1. Barks are half the AI.
2. Pace attackers with tokens.
3. Make aggression pay.
