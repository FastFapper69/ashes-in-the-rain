# Chapter 9: Audio & voice

## Core Idea
Max Payne–style noir: piano/jazz under narration, music stems that react to fights, every sound short and 22 kHz mono because the web decodes all of it into memory.

## Music
- 4 stems in step (base, lead, tension, fight) driven by `_tick_music`; jazz (The Magnetic Buzz – Keep Your Head Down, `music_jazz.ogg`) replaces base+lead when nothing fights (`sfx.gd MELODIES`, `melody`). Title/story: Rotem Cinamon – Dusk (`music_dusk.ogg`). Dream: Alon Peretz – Fire and Ice via `_tick_dream_sound()`.
- Cutscene audio per panel (`cutscene.gd AUDIO`: beds, music, rain, timed cues).

## SFX
Artlist sources: revolvers dfMG SW .38 (`shot_player`), DT Sound Point Blank (`shot_enemy`); rain SoundBits heavy rain + city hum (`rain_loop.ogg`), West Wolf wet streets lowpassed (`rain_in.ogg`); el_train.ogg, train_horn.wav, cloth.wav, wave.wav, rats.wav, fire_bed, fire.ogg. Long loops are Ogg (`sfx._looped`); `sfx NAMES` accepts .ogg. `--log-sound` prints every sound. Every interactive map thing should have its own sound.

## Voice
All narration by Artlist voice "Gravity" (ElevenLabs Multilingual v2, speed 0.9, stability 0.35) → `voice/<md5[:10]>.mp3`, 64 kbps mono, −16 LUFS; `gen/voice_lines.py` lists them. **Changing a line's text needs a new recording** (key = md5 of the text). Quoted lines are not voiced. Provider refused "shoot" in Mickey's outro → "take care of Eddie". Artlist files may need fetching through the PC's browser (container can't reach the artifacts host).

## Mobster voices (barks)
3 recorded voices (Artlist Eleven v3: Adam, James, Shadow), `voice/barks/<voice>_<md5[:10]>.mp3`, made by `gen/bark_voices.py` (scripts → one generation per voice → `split` aligns lines with pocketsphinx). Every man gets a voice; `_bark` prefers recorded lines and skips the last 14 heard; dying cries sometimes (`_cry`). Never "shoot" in a script (provider safety filter). Cost ~0.2 credit per character.

## Format rules
22050 Hz mono for every long track (ffprobe before commit); loops ≤ ~110 s (rain 50 s); wav > 1.5 s → 22 kHz mono.

## Key Takeaways
1. Check sample rate/channels of every new file.
2. Edit narration text only together with re-recording it.
3. Fight intensity drives stems – new mechanics should hook into `_tick_music` rather than play their own music.
