# Chapter 10: Story & cutscenes

## Core Idea
A story-driven noir told as an animated comic: narration over painted panels, between maps and interludes, with no plot holes. Full story lives in the claude.ai story doc (id in ch01) – read it before writing story.

## Fixed facts
- Title ASHES IN THE RAIN (formerly Ink & Lead). Hero **Frank Malone** (never renamed). Opens with an atmosphere intro on the world, then the prologue as Eddie (Frank's partner, overpowered tutorial) ending in an unwinnable shootout where Eddie dies; Frank takes over, weak.
- Eddie wears a clearly different (short) coat. Rosie brings Eddie's diary (not the notebook the police took). Rourke (1931: holds young Frank, then drives him in cuffs). Bosses Mickey (club, in a suit), Kessler (harbor office), Briggs (police). Endings Snow / Ash (guilt) wait for chapter IV.
- Nothing Czech in the story; inspired by Max Payne / Alan Wake / L.A. Noire, never copying; original characters, bestseller-level ambition (Sam Lake / Kojima).
- Interludes between chapters: recurring nightmare in the burning 1939 warehouse (eleven knocks), 1931 tenement fire memory, Rosie / Eddie memory after ch III.

## Cutscenes (cutscene.gd)
- Panels 1920×815 in `art/cut`, WebP (never Basis). `LIVE` = live fire/smoke spots per panel. Ids: eddie, interlude, teague, dream, kessler, underground, briggs, docks, memory.
- Narration: letters paced to voice length; a line waits until the voice ends (`voice_on()`), a tap never cuts Frank mid-sentence. Captions: Paper.caption stamp top-right, corners "tr" start under SKIP.
- Street is freed under black 3 frames before a comic page loads (memory).
- Art audit: no AI hands (re-checked 56, 57, 64, 65, 88), real text on panels (`fix_cut_text.py`), no flocks where the story says two pigeons in a closed cage.
- Diary pages and testimony pages appear in maps (ch05 placement rule).

## Key Takeaways
1. Every new panel: check hands, text, continuity with earlier panels (coats, props).
2. Story change → story doc first, then lines, then re-record voice.
3. Each chapter boss should hint at the next chapter, so the campaign reads as one arc.
