# Chapter 10: Story & cutscenes

## Core Idea
A story-driven noir told as an animated comic: narration over painted panels, between maps and interludes, with no plot holes. Full story lives in the claude.ai story doc (id in ch01) – read it before writing story.

## Fixed facts
- Title ASHES IN THE RAIN (formerly Ink & Lead). Hero **Frank Malone** (never renamed). Opens with an atmosphere intro on the world, then the prologue as Eddie (Frank's partner, overpowered tutorial) ending in an unwinnable shootout where Eddie dies; Frank takes over, weak.
- Eddie wears a clearly different (short) coat. Rosie brings Eddie's diary (not the notebook the police took). Rourke (1931: holds young Frank, then drives him in cuffs). Bosses Mickey (club, in a suit), Kessler (harbor office), Briggs (police). Endings Snow / Ash (guilt) – two only.
- **16. 11. decisions** (doc "ASHES IN THE RAIN – Dramaturgie a kapitola IV", id 6b27a135-4ad7-4136-ad82-a666cd08b246, tabs Dramaturgie + Řez domem a kamera): chapter IV = one night, Christmas Eve 21:00–2:10, 7 maps (Rooftops in the storm, Scaffold, The Ball, Service floors on fire with the knocking door, Elevator shaft, Penthouse, The Spire) + playable Rosie interlude. Vail's tower stands on the 1931 tenement site. Twist: Rourke carried the kerosene in 1931, took Frank in out of guilt. Rosie = one of the three Kowalczyk children Patrick carried out. Finale: Rourke fights, shows an empty cylinder, hands Frank one round; choice 1 shoot / lower the gun, choice 2 diary to Rosie (Snow, needs low ash + half the evidence) or burn it (Ash). Only two endings. Phone at 2:10 after the credits (DLC hook, not designed).
- Nothing Czech in the story; inspired by Max Payne / Alan Wake / L.A. Noire, never copying; original characters, bestseller-level ambition (Sam Lake / Kojima).
- Interludes between chapters: recurring nightmare in the burning 1939 warehouse (eleven knocks), 1931 tenement fire memory, Rosie / Eddie memory after ch III.

## In-game comic panels (idea, user 18. 11., rule 30; QUEUE §17)
- Like Max Payne 1/2: a few times a chapter, mid-map, a short comic page shows what is happening in the scene and why Frank does the next thing (a horde arrives, he runs for a house, he jumps). The map hands over: map N ends in the panel, map N+1 opens with its consequence.
- First instance the user sketched: end of THE LAUNDRY - panel: a crowd of men pours in; he has to run - he gets into a tenement, up to the first floor - panel, end of map. TENEMENTS opens with that escape: out of the first-floor window, he catches a washing line and slides down it to the street.

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
