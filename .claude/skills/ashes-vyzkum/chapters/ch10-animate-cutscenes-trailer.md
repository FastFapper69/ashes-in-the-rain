# Chapter 10: cth9191/animate – cutscene craft and a trailer pipeline

## Core Idea
`github.com/cth9191/animate` (MIT, @7e5eb56) is a Claude Code skill that makes short videos in code: one `<canvas>`, deterministic frames, headless Chromium + ffmpeg, voice-over and a music track, measured review. Its *drawing* is procedural (not for our game art – user rule), but its **story/sound grammar, voice timing and review discipline** transfer directly to our comic cutscenes and to a future trailer.

## Rules worth taking (from its craft.md, STORY.md, FRAME.md)
- **Silence before the payoff, loudest on the payoff**: 0.5–4 s near-silence on a held image, then the single loudest hit. The busiest moment comes just *before* the silence, not on it.
- **The voice is the clock**: each beat starts ~0.3 s after the previous sentence ends; big moments land on spoken words. **Put the payoff hit in the pause before the line that names it** – a hit under speech is ducked away.
- **The end is the start, changed** (callback to the opening image).
- **One constant the eye can hold** per frame; **colour means one thing** for the whole piece.
- **Something new every 2–4 s** (a move, reveal, cut, reaction); held frames keep small life (steam, blink, smoke).
- **Act ideas out literally**; vary scale – at least one extreme close-up per sequence.
- **Captions** ≥ 1.25 s on screen, ≤ 3.5 words/s.
- **Every cut has a reason you can say out loud** (next step, match position, cause→effect, time cut, callback, POV).
- **Banned AI-video defaults**: centred title on a gradient, everything fading in, generic particle bursts, glows on UI chrome, logo sting as the only ending.
- **Process**: story check (beat table) → look check (2–4 frames) → storyboard (every beat) → only then build; ask with options and a recommended default. "Done" = measured checks pass + contact sheets looked at.

## Apply to Ashes
- **Cutscenes (`cutscene.gd`)** – [OK] live fire/smoke spots (held-frame life), narration waits for the voice. [H] audit every scene for: a silence + single loudest hit at its turn; hits placed in pauses, not under narration; last panel calls back to the first; one extreme close-up; no panel held > 4 s without a change.
- [H] **Word-level voice timing**: its `tools/voice_words.py` runs faster-whisper locally on a voice file and returns every word's start/end. We could time caption write-on per word (instead of letters paced by line length) and cue SFX/panel moves on the exact word. Try on one scene (`--test=voice:eddie`) and compare.
- [H] **Contact sheet for review**: one image per test run with every `_shots` frame small (its `review/phone.jpg` idea, 1 fps at 360 px) – quick self-check and something the user can open on the phone.
- [H] **Pixel-identity regression** (its `framehash.mjs` idea): md5 of `_shots` PNGs before/after a refactor proves "nothing changed" – needs seeded randomness in the test path first.
- **Trailer / store video (later, ask the user)**: capture real gameplay with Godot's Movie Maker mode (`--write-movie out.avi --fixed-fps 30`, deterministic frames + audio) from our `--test` scenarios, cut on the music's beats (animate's `beats.mjs` finds tempo, drops and loudest hit of a track), narrate with the Gravity voice, export 9:16 / 16:9 with ffmpeg. Its "assets" path can frame real panels/screenshots, but no code-drawn art in anything we ship.

## Key Takeaways
1. Silence, then the loudest hit – and never under the narrator's words.
2. Measure cutscenes like UI: timing, loudness, text, dead beats.
3. A trailer can be built from deterministic Godot captures + beat-cut editing.
