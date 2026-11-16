# Chapter 8: Mobile controls

## Core Idea
Touch has no tactile feedback, so good mobile action games forgive imprecision under the hood and automate what thumbs do badly (aiming), while the player keeps the decisions (movement, timing).

## Frameworks
- **Design for thumbs**: primary buttons within average thumb reach, plain UI, playtest on several screens (Fortnite mobile guidelines).
- **Virtual joysticks + action buttons** suit action games; auto-aim at the nearest enemy (Archero style) lets the player focus on movement and timing. Virtual controls lose tactile feedback – a measurable performance cost.
- **Forgiveness (Celeste)**: coyote time (jump shortly after leaving a ledge), jump buffering (a press shortly before landing counts), halved gravity at the jump peak, corner correction. "Tight" games are the most forgiving underneath.
- Taps should tolerate small finger movement; long-press for deliberate actions.

## Status in Ashes
- [OK] fixed sticks (user's choice, he dislikes floating sticks), jump beside aim, dive + bullet time above, touch-to-aim, first stick tap never fires, `_jump_buf` 0.15 s and `_coyote` in `main.gd`.
- [H] halved gravity at the jump peak for air shooting (more hang time to aim, fits "2D Max Payne") – test with `--test=jumpseq` and the bot (jump distances change → re-check VAULT/rope reach).
- [H] corner correction for jumps into fire-escape edges.

## Key Takeaways
1. Hide forgiveness in the controls.
2. Automate aim, keep timing with the player.
3. Re-run the bot after any jump-physics change.
