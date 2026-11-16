---
name: mapy
description: Rules and checks for laying out Ashes in the Rain maps (gen/levels.py): cover, rooms, red barrels, where the men stand, what they shout. Read before adding or changing a map, a chunk or a room.
---

# Mapy – pravidla rozmístění (16. 11. 2026)

Uživatel: „ať to dává smysl a level je zajímavější“. Každé pravidlo níž hlídá `check_props()` v `gen/levels.py`
(volá ho `check()`): `python3 gen/levels.py levels.gd` musí u všech map vypsat jen „ok“.

## Kryt na ulici
- Mezi dvěma kusy krytu je buď 0 (záměrná hromada, `stack`), nebo **aspoň 260 px** (projde mezi nimi muž).
- **Nikdy tři stejné věci za sebou** (do 2600 px). Chunk se třemi kryty (gauntlet) losuje druhy.
- Muž na ulici bez krytu je terč: `cover_men()` dá ~60 % z nich bednu/sud 140–200 px před sebe
  (Frank přichází zleva), jen kde je místo (ne pod rampou, lávkou, u checkpointu, sbíraček, auta).
- Dva muži nestojí rameno na rameni (< 250 px).

## Interiéry (`furnish()`)
- Každá místnost se zařizuje **znovu podle seedu** – dvě prádelny nejsou stejné.
- `ROOM_CLEAR`: dveře, oblouky, průchody, žebříky namalované v kresbě (v pixelech kresby, 3168 š.).
  Před nimi nic nestojí. Nová kresba místnosti = nejdřív změřit a zapsat její průchody.
- `ROOM_KINDS`: co do místnosti patří (prádelna: pračka, vozík, stůl na prádlo, necky). Nikdy dvě stejné
  věci vedle sebe, nejvýš jeden velký stroj, první věc u vchodu není sud s palivem.
- Odstup od vchodu ~430–600, od zadní stěny 380, mezi věcmi 430–680.
- Muži stojí **za krytem** (na jeho vzdálenější straně od vchodu), ne v otevřeném prostoru.
- **Žádné předěly** (uživatel 16. 11., platí pro celou hru): kresba se nikdy neopakuje vedle sebe tak, aby se
  uprostřed místnosti/chodby objevila její koncová stěna nebo okno. Místnost širší než kresba (2376 px při
  ROOM_SCALE 0.75) má kresbu uprostřed a na koncích tmu (`_build_room`, `_room_src()`). Dlouhá chodba =
  levý konec + opakovaný střed bez stěn (spoje na svislé trubce/sloupu) + pravý konec; střed střídá holou zeď
  a dveře, nikdy stejné dveře dvakrát za sebou. Nové kresby (Gemini) zadávat jako konce + navazující střed.

## Červené sudy (palivo)
- Jen tam, kde se palivo skladuje: `BARREL_OK` (dvory, sklady, doky, tunely, zadní ulička, sklep klubu)
  a v místnostech jen sklad a podpalubí.
- `street()` pod sud přednostně vybere vhodnou kresbu; kde to nejde, sud se změní v obyčejný ocelový
  sud (`drum`) a muži se odsunou z jeho místa.
- Sud stojí u skupiny mužů (past), ne sám uprostřed prázdné ulice.

## Hlášky nepřátel (`barks.gd`)
- Každý muž má jméno (NAMES, žádné jméno z příběhu). Když padne, nejbližší kumpán zakřičí jeho jméno
  („HE GOT VINNIE!“); poslední ze skupiny volá padlé; velitel posílá muže jménem.
- Jeden hlas naráz (`_bark`: odstup 1,6 s, naléhavé 0,6 s) a každý druh má svůj odstup (`BARK_GAP`).
- Nové hlášky do `LINES`: anglicky, verzálky, ~24 znaků. `{n}` jméno, `{p}` MALONE/DOYLE.

## Kontrola (povinná)
- `python3 gen/levels.py levels.gd` – bez ERRORS.
- `python3 gen/prop_audit.py` – sudy a jejich místo, těsné mezery.
- `python3 gen/foe_audit.py` – kolik mužů stojí na otevřeném prostranství / za krytem.
- `--test=props --chapter=C --map=M` – snímek každé skupiny krytu, **prohlédnout**.
- Boti na všech mapách (`--test=play`).
