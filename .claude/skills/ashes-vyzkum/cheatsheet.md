# Research cheatsheet – decide fast

## Before building…
| You are about to… | Ask |
|---|---|
| brief Gemini for art | Are the blacks placed as shapes? Equal white? One visible hard source? Few greys? (ch01) |
| add a light | Is its source in the painting, in its shape? Window stripes only with a window (ch01) |
| add an enemy behaviour | Does it bark? Does it take a token? Same floor + on screen? (ch04) |
| design a map | What is its ONE idea? Ki / Shō / Ten / Ketsu beats? Seen blockers only? (ch05) |
| tune bullet time | Real-time aim kept? Bullets visible? Does a kill feed the meter? Can it become a crutch? (ch03) |
| add an effect | Pooled? A new CanvasGroup / full-screen pass? Counted in the fight budget? (ch06, ch07) |
| touch memory | Page total under ~350 MB on iPhone? Allocation spread over frames? (ch06) |
| change jumps/controls | Coyote/buffer kept? Bot re-run? (ch08) |
| write story | Does narration react to the player's choices? One reveal per interlude? (ch02) |

## Thresholds & defaults (approximate, verify on device)
| Thing | Value | Source |
|---|---|---|
| iOS page memory limit | ~300–450 MB (cleanups ~50 % / 65 %) | WebKit analysis |
| hitstop | ~60–120 ms; light hit short, heavy longer | juice guides |
| coyote window | ~0.06–0.12 s (Celeste ~5 frames) | forgiveness guides |
| jump buffer | ~0.1–0.15 s (ours 0.15) | ours |
| simultaneous shooters | 2 (token pool) | ours / DOOM |
| death → play again | ≤ 1–2 s target | Hotline/Katana principle |

## Tells & smells
- Page "looks dirty, not dark" → blacks without structure.
- AI "feels dumb" but works → missing barks.
- Slow-mo always on → meter too generous (Pedro critique).
- FPS drops only in slowed-time fights → ghost trail / CanvasGroups.
- Crash right after loading a map → allocation spike or pack heap.
