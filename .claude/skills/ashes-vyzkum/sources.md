# Sources (read 2026-11-16)

## Style references
- Making of Max Payne (3D Realms) – bullet time with real-time aim, projectiles not hitscan, shootdodge, panels, photo textures: https://apollo.3drealms.com/news/making-max-payne
- Scott Miller on Max Payne (Film Stories) – panels were Remedy's cost-saving idea; flying bullets: https://filmstories.co.uk/features/max-payne-producer-scott-miller-on-the-making-of-a-classic/
- Max Payne 2 legacy (Game Developer): https://gamedeveloper.com/design/looking-back-at-the-legacy-of-i-remedy-s-max-payne-2-i-
- A Bit Closer to Heaven – Max Payne history (Wertzone), Sam Lake's psychological thriller aim: https://thewertzone.blogspot.com/2019/08/a-bit-closer-to-heaven-max-payne.html
- Mignola: the shadow is a form (My Comics Collection): https://mycomicscollection.com/en/blog/shadow-mignola-not-shadow-form/
- Spotting black areas (Big Time Attic): https://bigtimeattic.blogspot.com/2007/02/tips-and-tricks-spotting-black-areas.html
- Sin City cinematography (Color Culture): https://colorculture.org/sin-city-cinematography-analysis/
- Film noir lighting (PremiumBeat): https://www.premiumbeat.com/blog/lighting-for-film-noir/
- Noir lighting mechanics (Vectree): https://vectree.io/pdf/c/classic-noir-lighting-mechanics
- John Wick choreography (Film Independent / Darrin Prescott): https://www.filmindependent.org/blog/bonus-stunt-coordinator-darrin-prescott-dissects-john-wicks-best-action-scenes/
- John Wick as dance (Stahelski via Yahoo/IndieWire): https://ca.news.yahoo.com/gene-kelly-singin-rain-taught-150055946.html
- L.A. Noire – Emily Short analysis: https://gamedeveloper.com/design/analysis-three-roles-i-played-in-em-l-a-noire-em-
- L.A. Noire interrogation UI: https://www.gamedeveloper.com/design/l-a-noire-s-interrogation-system
- Katana ZERO (Wikipedia, reviews): https://en.wikipedia.org/wiki/Katana_Zero
- My Friend Pedro (Siliconera, devlogs): https://www.siliconera.com/my-friend-pedro-is-cool-in-motion-but-only-after-getting-used-to-clunky-controls/ , https://itch.io/post/448748/view-in-topic
- Hotline Miami (Wikipedia; Game Developer HM2 analysis): https://en.wikipedia.org/wiki/Hotline_Miami , https://gamedeveloper.com/design/hotline-miami-2-wrong-number---we-are-all-perfectly-tuned-projectiles

## Godot & web
- Godot docs (CC BY 3.0), godot-docs repo @2c6cc13: tutorials/export/exporting_for_web, performance/gpu_optimization, assets_pipeline/importing_images, 2d/2d_parallax, 2d/2d_lights_and_shadows, physics/interpolation, classes/Engine (time_scale), classes/CanvasGroup – https://docs.godotengine.org/en/stable/
- Godot 3 batching doc (lights multiply draw calls; 4.x draws 2D lights in one pass): https://docs.godotengine.org/en/3.5/tutorials/performance/batching.html , https://godotengine.org/article/godots-2d-engine-gets-several-improvements-upcoming-40
- WebKit memory internals (Catchmetrics): https://www.catchmetrics.io/blog/deep-dive-ram-internals-webkit
- WebKit bug – iOS reload loop with WebGL/texture-heavy pages: https://bugs.webkit.org/show_bug.cgi?id=300782
- iOS Safari gotchas (canvas resize leak): https://abratabia.com/mobile-web-games/ios-safari-gotchas.php
- Godot forum: iOS web crashes: https://forum.godotengine.org/t/game-crashes-randomly-on-ios-devices-html-export/114043

## Game design
- The Art of Screenshake list (Uni Bayreuth slides): https://medienwissenschaft.uni-bayreuth.de/wp-content/uploads/GxD-10-Game-Feel.pdf
- Screen shake guide (feedback must stay information): https://gamejuice.pages.dev/articles/screen-shake-guide
- F.E.A.R. AI – Orkin GDC 2006 paper: https://pages.cs.wisc.edu/~dyer/cs540/handouts/gdc2006_orkin_jeff_fear.pdf ; barks analysis: https://abratabia.com/game-ai-npc/best-enemy-ai.php
- DOOM push-forward combat (GDC Q&A) and tokens: https://gdconf.com/news/speaker-qa-kurt-loudy-jake-campbell-break-combat-philosophy-doom , https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair
- Kishōtenketsu in Mario (Nintendo Life): https://www.nintendolife.com/news/2015/03/video_nintendos_four_step_stage_design_is_why_you_love_super_mario_games_so_much
- Celeste & Forgiveness (Maddy Thorson): https://maddymakesgames.com/articles/celeste_and_forgiveness/
- Game Programming Patterns (free online): https://gameprogrammingpatterns.com/contents.html , https://gameprogrammingpatterns.com/object-pool.html
- Mobile design (Fortnite docs): https://dev.epicgames.com/documentation/fortnite/designing-for-mobile-in-fortnite ; mobile controls overview: https://abratabia.com/game-controls/best-mobile-controls.php

## Modular kits and joins (ch15, 2026-11-17)
- Burgess & Purkeypile, Skyrim's modular approach (GDC 2013): https://gamedeveloper.com/design/skyrim-s-modular-approach-to-level-design , slides https://www.slideshare.net/JoelBurgess/gdc2013-kit-buildingfinal
- Burgess, kits and art fatigue (80.lv): https://80.lv/articles/building-huge-open-worlds-modularity-kits-art-fatigue ; Level Design Book, modular kits: https://book.leveldesignbook.com/process/blockout/metrics/modular
- Dead Cells hybrid level design (Sébastien Bénard): https://deepnight.net/tutorial/the-level-design-of-dead-cells-a-hybrid-approach/ ; Spelunky generator: https://tinysubversions.com/spelunkyGen2/
- Wang tiles / autotiling (Red Blob Games): https://www.redblobgames.com/articles/autotile/claude/
- Frozenbyte Trine level art – composition: https://wiki.frozenbyte.com/index.php/Level_Art:_Composition
- Hollow Knight layers: https://medium.com/3d-environmental-art/the-art-of-hollow-knight-f4c05dda3882 , Unity case study https://unity.com/madewith/hollow-knight
- Transition zones / squeeze holes / airlocking: https://filmstories.co.uk/features/squeeze-holes-where-did-they-come-from-and-what-are-they-for/ , https://www.mapcore.org/articles/development/creative-airlocking-streaming-in-action-games-r87
- Outpainting for game backgrounds (Image Extender, Poisson blending): https://sourceforge.net/mirror/image-extender/profile/
