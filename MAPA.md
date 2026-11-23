# Ashes in the Rain - mapa ke hře

Start každého chatu. Uživatel řekne **„načti si mapu ke hře“**, nový chat přečte tuhle stránku a projde kroky níže.
Je to i úvodní stránka Obsidianu (vault = celé repo, graf Ctrl+G).

## Načtení (v tomhle pořadí, nic nepřeskakovat)
1. Tahle stránka celá.
2. `.claude/skills/ashes-znalosti/SKILL.md` - pravidla uživatele (§1, čísla pravidel), rejstřík kapitol. Kapitolu
   otevři až když na její téma sáhneš ([[ch05-levels-maps]] mapy, [[ch03-art-pipeline]] kresby, ...).
3. Konec [[HANDOFF]] - posledních ~40 řádků (`tail -40 HANDOFF.md`): co se dělalo naposled, co je dál.
4. [[QUEUE_doma]] - otevřené oddíly (teď §21 modulární město, §22 tiskárna, §23 hřiště s tabulkou stanovišť).
5. Paměť `C:\Users\super\.claude\projects\C--Users-super\memory\MEMORY.md` (načte se sama) - rozhodnutí a zpětná vazba.
6. `git fetch` a `git log --oneline -8` - druhý chat mohl něco nasadit.
Pak krátce česky: co je rozdělané a na co se čeká od uživatele. Nic nepředělávat, dokud to uživatel nechce.

## Kde co je
| co | kde |
|---|---|
| repo (Godot 4.7.2, web + iPhone) | `C:\Users\super\Documents\MobileGames\ashes-in-the-rain` (GitHub FastFapper69/ashes-in-the-rain) |
| Godot | `/c/Users/super/Downloads/Godot_v4.7.2-stable_win64_console.exe` (proměnná `G`) |
| web build (gh-pages) | klon `../ashes-in-the-rain-pages`, web https://fastfapper69.github.io/ashes-in-the-rain/ |
| zdrojové kresby z Gemini | `C:\Users\super\Documents\MobileGames\Ashes in the Rain\art_src\NNN.jpg` (mimo repo) |
| mapy | `gen/levels.py` (generátor, chunky) -> `levels.gd` (nikdy ručně) |
| hra | `main.gd` (vše herní), `props.gd`, `menu.gd`, `hud.gd`, `paper.gd` (UI), `changelog.gd` (co je nového) |
| snímky z testů | `_shots/` (gitignore), přehled `_shots/sheet.png` |
| deník / fronta | [[HANDOFF]] (záznamy `- (NNN)`), [[QUEUE_doma]] |

## Stav (23. 11. 2026)
- **Modulární město** (pravidlo 31): domy z modulů Gemini na mřížce, malované ulice jen daleko vzadu. Pilot hotový.
- **Hřiště** = SANDBOX 2 "PLAYGROUND" (menu: štítek TEST LAB / THE PLAYGROUND): stanoviště 1-4 postavená (dům, šňůra +
  tiskárna, pohyb na ulici, boj). Čeká se na OK uživatele po stanovištích; další stanoviště (střechy, lešení,
  markýza, kladka) potřebují nové moduly - tabulka v [[QUEUE_doma]] §23.
- **Hloubka jen v bodech** (pravidlo 33, uživatel zvolil C 23. 11.): výklenek dveří hotový (stanoviště 4b na konci
  hřiště), bistro jako hala za výlohou (4c); další body: vstup do uličky, schování za auto.
- **Příběh přepsaný** (23. 11., pravidlo 35): [[Srdce-a-hlas]] - Frank mluví k mrtvému Eddiemu, jeden požár, jeden deník. Scénář celé hry je napsaný v `pribeh/`. Do hry zatím nic: začít prologem a kapitolou I.
- Komiksy až nakonec (paměť). Kapitoly I-III hratelné, staré mapy se po hřišti převedou na modulární město.

## Příkazy (Git Bash, z kořene repa)
| úkol | příkaz |
|---|---|
| přestavět mapy | `py -3 gen/levels.py` (řádky s ERRORS opravit) |
| nová kresba do hry | `bash gen/import_art.sh` (import -> Basis -> import) |
| snímky + přehled | `bash gen/tests/shots.sh "--test=look:6300@0,9750@0 --sandbox=2" [1560x720]` -> prohlédnout `_shots/sheet.png` |
| bot jedné mapy | `bash gen/tests/bot.sh sb 2` nebo `bash gen/tests/bot.sh 1 3` (`RUNS=3` = 3 běhy naráz) |
| boti všech map | `G=... TMPDIR="$TEMP/bots1" bash gen/tests/bots.sh` - jen při změně sdíleného kódu, jednou před nasazením |
| UI kontrola | `--test=menu --progress=3` v 1280 i 1560, výstup bez `UI BAD` (skill ui-papir) |
| nasazení | `git fetch` -> `bash gen/deploy/deploy_pc.sh "zpráva"` (vypíše GHP-OK, MAIN-OK a počká na LIVE) |
| Gemini: reference do schránky | `py -3 gen/tools/clip.py <obrázek>` -> v Gemini Ctrl+V |
| Gemini: stažený obrázek do art_src | `py -3 gen/tools/gemini_take.py` (další volné číslo) |
| odkazy pro Obsidian | `py -3 gen/obsidian_links.py` |
| záloha všeho | `bash gen/backup.sh ["zpráva"]` - paměť do `pamet/` (jen lokálně, v Obsidianu), repo commit + push; běží i po každém nasazení |
Užitečné testy (`--test=...`): `look:x@y,...`, `walkfrom:x[:up]`, `wash`, `doorkick`, `flatwin`, `cityview`, `play`.

## Jak pracovat efektivně (poučení)
- **Rozsah testů podle dosahu změny**: změna jedné mapy/hřiště = bot jen na ni; sdílený kód = všichni boti jednou.
- **Nezávislé věci paralelně**: bot na pozadí (`&`) a mezitím snímky; několik běhů bota naráz (`RUNS=3`).
- **Prohlížet jeden přehled** (`sheet.png`) místo desítky snímků; snímky vždy opravdu prohlédnout (pravidlo 1).
- **Úpravy kódu**: nástroj Edit nebo python skript v souboru; ne heredoc s `\` na konci řádku (rozbil se 2x).
- **GDScript**: u hodnot z `Dictionary`/`Array` psát typ (`var x: float = ...`) - `:=` z Variantu = parse error.
- **Logika obrazu před mechanikou**: každý herní efekt (neviditelný, krytý, v bezpečí) musí být vidět PROČ - snímek
  posoudit očima cizího hráče dřív, než to pošleš (23. 11. "stojí u schodů, jak ho můžou nevidět").
- **Nejasná geometrie** (kam se otáčí dveře, kde je zeď): zeptat se s náhledem (AskUserQuestion), ne hádat.
- **Před commitem/nasazením `git fetch`** (dva chaty), po nasazení počkat na LIVE (skript to dělá sám).
- **Každé trvalé rozhodnutí uživatele** -> SKILL.md §1 + kapitola, ve stejném commitu; denní postup -> [[HANDOFF]].
- **Odpovědi**: česky, krátce, co je hotové + co se čeká; text ve hře anglicky; kresby jen z Gemini.

## Paměť Clauda (`pamet/` = přímo jeho paměť, propojená složka; jen lokálně - repo je veřejné)
- `pamet/MEMORY.md` a soubory v `pamet/` (originál: `C:/Users/super/.claude/projects/C--Users-super/memory`)

## Znalosti (stabilní pravidla)
- ashes-znalosti: `.claude/skills/ashes-znalosti/SKILL.md`
- [[ch01-build-deploy]] · [[ch02-tests]] · [[ch03-art-pipeline]] · [[ch04-phone-memory]]
- [[ch05-levels-maps]] · [[ch06-lights-fx]] · [[ch07-enemies-ai]] · [[ch08-player-progression]]
- [[ch09-audio-voice]] · [[ch10-story-cutscenes]] · [[ch11-ui-hud]]
- [[cheatsheet]] · [[glossary]] · [[patterns]]
- příběh: [[Srdce-a-hlas]] (platný příběh a hlas vyprávění, 23. 11.) · [[pribeh-denik]] (rozhodnutí a zahozené nápady) · scénář [[kapitola-II]] · [[kapitola-III]] · [[kapitola-IV]] · [[scenar-mapy]] · [[jedenact-a-pisen]] · co se děje v mapách: [[mapy-prolog-a-kapitola-I]] (než se mapa staví, připsat k úsekům, co je těžké nebo hloupé) - složka `pribeh/`, ladí se v samostatném chatu
- další skilly: ashes-vyzkum (výzkum), mapy (pravidla map), ui-papir (UI), webapp-testing (web), [[CLAUDE]], [[PC_SETUP]]
