# ch16 – The twelve principles of animation, for our puppets (2026-11-25)

Source: Thomas & Johnston, *The Illusion of Life: Disney Animation* (1981), ch. 3; game readings: J. Cooper, "The 12 principles of animation in video games" (Game Anim, gamedeveloper.com 2019), C. Totten, "12 principles for game animation" (gamedeveloper.com 2021), Wikipedia "Twelve basic principles of animation". Paraphrased notes, no book text.

**The one game rule:** the conflict is anticipation and follow-through versus responsiveness. The player's moves start on the frame of the input (anticipation shown as a pose, not as time). Follow-through plays out fully only while there is no new input (a "control-return frame"). Long windups belong to enemies: they are the telegraph.

| # | Principle | Core | In a game | Ours (puppet.gd) |
|---|---|---|---|---|
| 1 | Squash & stretch | deform to show weight; volume stays the same | rigid rigs fake it with poses (crouch on takeoff, stretched in the air, deep on landing); keep it brief so the art does not leave the hitbox | [H] no landing compression after a jump or a fall: hips should dip 2–4 frames and come back up (ease-out) |
| 2 | Anticipation | a small counter-move before the big one | player: zero delay, one squash frame while already leaving the ground; enemies: a clear windup = telegraph, longer for heavy hits | the pipe swing winds up; enemy `aim_t`; [H] a visible pose for the tommy/shotgun windup (shoulder dropping, the gun coming up) before the burst |
| 3 | Staging | the action reads at once | silhouette test (fill it black); the action must not hide inside the body's mass | collar/arm-over-face fixes (rule 41 §21, §23) were staging fixes; [H] black-silhouette sheet of the 115 poses in the moves test |
| 4 | Straight ahead / pose to pose | keys first, or draw in order | pose to pose is the default (cheap to change); straight ahead for cloth, hair, hit reactions; mocap = a base to key over and retime | mocap + keyed.py = pose to pose over capture; coat = procedural "straight ahead" |
| 5 | Follow-through & overlap | parts stop at different times; loose parts drag and settle | the body leads, arms, coat and hat trail; never let everything stop on the same frame; physics does it procedurally | coat tail lags/streams/settles; recoil settles; blend spring; [H] the hat and the off hand lag a frame or two behind the head on a hard stop or turn |
| 6 | Slow in / slow out | more frames near the extremes | not everything: a sword strike is fast in, slow out (the weight is in the settle) | critically damped blend spring (IN_W 14); [H] shots: kick fast, settle slow (recoil uses move_toward = linear; try exponential) |
| 7 | Arcs | living motion moves on arcs, machines move straight | clean arc breaks from mocap; break an arc on purpose for impact (a head snapping back after a hit) | air_v follows the jump arc; [H] hand paths when aim switches (lerp_angle = arc, fine) |
| 8 | Secondary action | small acts that support the main one, never compete | tired breathing, face on damage, idle fidgets; additive layers | breathing at rest, coat flutter; [H] heavier breath after bullet time or a long run |
| 9 | Timing | the number of frames = speed and weight | a heavier thing reacts later; hold a pose after a strike so it reads; smears instead of frames | dive/roll timings; [H] a 2–3 frame hold at the end of a kick or pipe blow |
| 10 | Exaggeration | push past reality, consistently | one level across the whole cast; must not break collision or control | deaths, being thrown back by a shotgun; keep the mobsters at Frank's level |
| 11 | Solid drawing | volume, balance, weight | avoid "twins" (left and right mirrored and in step): it looks dead | [H] check that idle and aim never mirror the arms or legs exactly |
| 12 | Appeal | the character feels real and interesting, villains too | a clear silhouette and one dominant shape per character | hats and coats tell the men apart (ENEMY_TINT white) |

## Checks to add to the poses audit (rule 41 §23)
- Silhouette: do the poses read when filled black? (staging)
- Twins: no frame where both arms or both legs mirror each other.
- Landing: the frames after touchdown dip and come back up, they do not freeze.
- Settle: after a stop, a shot or a blow, a loose part (coat, hat, the off hand) still moves for 0.1–0.3 s.
- Telegraph: every enemy attack shows a pose before the bullet that the player can read in slowed time too.

**Done 25. 11. (ashes-znalosti rule 41 (24)):** telegraph `brace`, overlap `_nod`, recoil slow-out, pipe follow-through, `_exert` breath. Landing compression already existed (main.gd `_crouch_v` spring). Still [H]: hat lag (the hat is painted on the head), the off hand lagging, silhouette/twins: done the same day (`--test=moves --sil`, TWIN lines; rule 41 (25)).

[H] = idea, measure or view it in the playground before shipping (new mechanics go through the playground).
