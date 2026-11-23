# Chapter 10: Story & cutscenes

## Core Idea
A story-driven noir told as an animated comic: narration over painted panels, between maps and interludes, with no plot holes. Full story lives in the claude.ai story doc (id in [[ch01-build-deploy|ch01]]) – read it before writing story.

## Story rework 23. 11. (valid now - read first)
- The valid story and narration voice is [[Srdce-a-hlas]] (`pribeh/`), decisions and dropped ideas in [[pribeh-denik]]. Where the facts below disagree, that note wins.
- Frank narrates to dead Eddie in the second person ("you") the whole game; five voice rules; one fate's joke a chapter; three silences (ring for Rosie, the signature, Rourke's back).
- ONE fire (Pier 17, 1939). 1931 = memory of the fireman father only: no arson, no kerosene, Vail's tower is just a tower, Rosie / Tommy were not children carried out in 1931.
- Rourke: handed Frank the envelope in 1939, ordered Eddie killed in 1947 (chapter III reveal, from Briggs). Finale as before (empty cylinder, one round).
- ONE diary: in the prologue Eddie writes FRANK on a clean page and leaves the diary with Rosie; she keeps that last page until Frank tells her "I signed it". No notebook taken by the police. FRANK is a heading of a page left blank for Frank to write.
- Eddie = reporter (Evening Ledger), smokes, never has matches, carries a ring for Rosie. Two symbols only: ash / snow, matches.
- The whole script is written in `pribeh/`: [[Srdce-a-hlas]] (prologue, chapter I), [[kapitola-II]], [[kapitola-III]] (with the Rosie interlude), [[kapitola-IV]] (both endings; no phone in Snow), [[scenar-mapy]] (title lines, map intros / outros, chapter I diary pages, inner voice), [[jedenact-a-pisen]] (the eleven men of Pier 17, one object each, and the lyrics of Tommy's song).
- To build: prologue bubbles + panels, chapter I lines (table in the note), 7 new panels, cuts (notebook in the rain panel, kerosene / 1931 arson mentions, the tenement reveal in chapter III). Chapters II-IV lines are rewritten after the user has played chapter I.

## Fixed facts (before 23. 11. - see above for what changed)
- Title ASHES IN THE RAIN (formerly Ink & Lead). Hero **Frank Malone** (never renamed). Opens with an atmosphere intro on the world, then the prologue as Eddie (Frank's partner, overpowered tutorial) ending in an unwinnable shootout where Eddie dies; Frank takes over, weak.
- Eddie wears a clearly different (short) coat. Rosie brings Eddie's diary (not the notebook the police took). Rourke (1931: holds young Frank, then drives him in cuffs). Bosses Mickey (club, in a suit), Kessler (harbor office), Briggs (police). Endings Snow / Ash (guilt) – two only.
- **16. 11. decisions** (doc "ASHES IN THE RAIN – Dramaturgie a kapitola IV", id 6b27a135-4ad7-4136-ad82-a666cd08b246, tabs Dramaturgie + Řez domem a kamera): chapter IV = one night, Christmas Eve 21:00–2:10, 7 maps (Rooftops in the storm, Scaffold, The Ball, Service floors on fire with the knocking door, Elevator shaft, Penthouse, The Spire) + playable Rosie interlude. Vail's tower stands on the 1931 tenement site. Twist: Rourke carried the kerosene in 1931, took Frank in out of guilt. Rosie = one of the three Kowalczyk children Patrick carried out. Finale: Rourke fights, shows an empty cylinder, hands Frank one round; choice 1 shoot / lower the gun, choice 2 diary to Rosie (Snow, needs low ash + half the evidence) or burn it (Ash). Only two endings. Phone at 2:10 after the credits (DLC hook, not designed).
- Nothing Czech in the story; inspired by Max Payne / Alan Wake / L.A. Noire, never copying; original characters, bestseller-level ambition (Sam Lake / Kojima).
- Interludes between chapters: recurring nightmare in the burning 1939 warehouse (eleven knocks), 1931 tenement fire memory, Rosie / Eddie memory after ch III.

## In-game comic panels (idea, user 18. 11., rule 30; QUEUE §17)
- Like Max Payne 1/2: a few times a chapter, mid-map, a short comic page shows what is happening in the scene and why Frank does the next thing (a horde arrives, he runs for a house, he jumps). The map hands over: map N ends in the panel, map N+1 opens with its consequence.
- Built 18. 11. (HANDOFF 96): level event ["comic", x, scene] -> main.gd _mid_comic (paused like a before-map page, once per map, never for bots); a map can be won by getting somewhere: level "goal" [x, y] (no _all_down). First instance the user sketched: end of THE LAUNDRY - panel: a crowd of men pours in; he has to run - he gets into a tenement, up to the first floor - panel, end of map. TENEMENTS opens with that escape: out of the first-floor window, he catches a washing line and slides down it to the street.

## Cutscenes (cutscene.gd)
- Panels 1920×815 in `art/cut`, WebP (never Basis). `LIVE` = live fire/smoke spots per panel. Ids: eddie, interlude, teague, dream, kessler, underground, briggs, docks, memory.
- Narration: letters paced to voice length; a line waits until the voice ends (`voice_on()`), a tap never cuts Frank mid-sentence. Captions: Paper.caption stamp top-right, corners "tr" start under SKIP.
- Street is freed under black 3 frames before a comic page loads (memory).
- Art audit: no AI hands (re-checked 56, 57, 64, 65, 88), real text on panels (`fix_cut_text.py`), no flocks where the story says two pigeons in a closed cage.
- Diary pages and testimony pages appear in maps ([[ch05-levels-maps|ch05]] placement rule).

## Key Takeaways
1. Every new panel: check hands, text, continuity with earlier panels (coats, props).
2. Story change → story doc first, then lines, then re-record voice.
3. Each chapter boss should hint at the next chapter, so the campaign reads as one arc.
