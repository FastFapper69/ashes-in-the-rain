# Chapter 14: Camera, playtest telemetry, accessibility

## Camera (Itay Keren, "Scroll Back")
Three goals: **attention** (show what matters), **interaction** (show the player's control and target), **comfort** (smooth, predictable motion). Named techniques mapped to Ashes:
- [OK] forward focus (`_lead`), target focus (aim offsets camera y), region-based anchors (floor zoom on multi-floor maps), lerp/exp smoothing of zoom.
- [H] **cue focus**: attractors pull the camera toward a boss entrance, a searchlight, a falling neon sign – a cheap way to point attention without text.
- [H] **platform snapping**: keep camera y steady during jumps/dives, re-centre on landing – less vertical bobbing, more readable gunfights.
- [H] **cinematic path**: a short scripted pan at a map start to foreshadow the route (fits "levels shouldn't only go right": show the stairs/roof first).
- [H] **zoom-to-fit** for boss fights / many enemies.
- Shake is drama, keep it rare (we have a shake toggle).

## Playtest telemetry
- Watch real players first, then measure. Death heatmaps per map, drop-off funnel per map/chapter, time per map (a map taking 4× longer than its neighbours is a design signal), quit points.
- Rule of thumb: an issue hit by 3+ players independently gets fixed.
- [H] Add a `death` event (map, x, y, cause, time on map, build) and `map_done` / `quit` events to Supabase next to the crash reports; draw a heatmap over the map strip with a small script. Needs consent/privacy note (ch12).

## Accessibility (Game Accessibility Guidelines)
- [OK] aim assist toggle, screen-shake toggle, difficulty in settings.
- Basic list: subtitles for all important speech, readable default size, ≤ 38 characters per line, always contrasting background; settings saved; accessibility features described in-game.
- Assist mode à la Celeste: game speed, invincibility, skip a fight – introduced with respectful wording ("the game is meant to be hard; if it is inaccessible to you…"). Also lets the user's story reach more players.
- Haptics as optional feedback when native (ch13).

## Key Takeaways
1. Point the camera at what matters before adding text.
2. Measure where players die and quit, then fix the top spots.
3. Subtitles + assist mode are cheap and widen the audience.
