# Nové postavy a animace – plán (24. 11. 2026)

Start: [[MAPA]]. Proč: [[postava-rozbor-2026-11-24]] (kolena a lokty na špatném místě, běh = rychlá chůze, trup z jiného úhlu než hlava,
Eddie = přebarvený Frank). Uživatel 24. 11.: „nové vygenerování všeho… každá důležitá postava výraznější podobu, víc jako v komiksu…
co nejvíc smooth cool animace… otestujeme to nejdřív na Eddiem“. Pilot: **Eddie v šedém prologu** (hřiště 3).

## 1. Odkud vezmu pohyb (tři vrstvy)

| Vrstva | Co | Jak |
|---|---|---|
| **A. Snímaný pohyb člověka** | chůze, klus, běh, rozběh a zastavení, otočka, chůze v podřepu, skok a dopad | volná data mocap (CMU, soubory BVH) → Blender bez okna (skript) → pohled z boku → tabulka úhlů kloubů po snímcích → naše loutka. Smyčky vyčistit, chodidlo zamknout k zemi. |
| **B. Ručně klíčované klipy** | rybička, skluz, kop do dveří, přebití, pád po zásahu, šňůra | dnešní systém `CLIPS` v puppet.gd, rozšířený na celé tělo (dnes klíčuje jen nohy, náklon a jednu ruku). Stylizace: předkmit, přetažení, dosednutí. |
| **C. Vrstvy navrch v kódu** | míření horní půlkou těla, zpětný ráz, dech, pohled, kabát a klobouk na pružinách, náklon do zrychlení | zůstává procedurální; míchá se přes A a B (dolní půlka běží, horní míří). |

K tomu: **stavový stroj s prolínáním** (0,1–0,15 s mezi klipy), **kadence podle rychlosti** (délka kroku × kadence = rychlost, jinak
chodidla kloužou), zbraň u těla při běhu a natažení jen na výstřel.

Proč mocap: běh od oka (dnešní `_foot()`) je přesně to, co působí groteskně. Skutečný běh má letovou fázi, patu k hýždi, došlap pod
tělo a pohyb pánve, který se ručně trefuje špatně. Nasnímaný pohyb to má zadarmo; stylizace se přidá navrch.

## 2. Loutka (kostra)

- Správné délky: stehno ≈ bérec, nadloktí > předloktí (tabulka v rozboru). Každá postava vlastní proporce.
- Víc kostí než dnes: pánev, břicho, hrudník, krk, hlava, klíční kost + nadloktí + předloktí + ruka, stehno + bérec + **chodidlo
  (kotník, špička)**, klobouk, kabát po dílech (přední a zadní šos po 2–3 článcích).
- Ohyb v loktech, kolenou a pase sítí (Polygon2D s váhami; nohy a šos to už dnes mají), ne dvěma tuhými deskami.
- Výměnné díly: ruka (úchop, otevřená, pěst), chodidlo (plné, na špičce), hlava (profil; později pohled nahoru/dolů).
- Pořadí vrstev: vzdálená ruka a noha za tělem, tmavší.

## 3. Kresby (Gemini, přes Chrome)

Postup na jednu postavu, **dvě schválení uživatelem**:
1. **Návrhový list**: celá postava z čistého profilu v klidném stoji + portrét jako z komiksu + 3 věci, podle kterých ji poznáš
   v siluetě. Předloha: komiksový panel / dnešní hlava. → *uživatel schválí podobu*.
2. **List dílů** podle šablony ze skriptu (`gen/*_template.py`, Gemini rozvržení drží): každý díl rovně, končetiny svisle,
   **kulaté přesahy v kloubech**, nakreslené i to, co je zakryté (trup pod rukou), jedno světlo, jedna tloušťka linky, čisté pozadí.
3. Výřez, světelné mapy (dnešní postup), jedna textura 2048 px na hrdinu (paměť telefonu).
4. Postava složená ve hře ve stoji → *uživatel schválí* dřív, než se animuje.

Eddie – zadání siluety (můj návrh): plochý klobouk s novinářskou kartou, krátký tmavý kabát se zvednutým límcem, štíhlejší a mladší
než Frank, cigareta, viditelný krk. Proporce lehce přehnané (delší nohy, o něco větší hlava s kloboukem), na malém displeji se čtou líp.

## 4. Nástroje

- **Blender 5.x** (je nainstalovaný, skill `blender-modelovani`): převod mocapu, čištění smyček, náhled; jednoduchá 3D figurína
  v proporcích postavy jako **předloha póz pro Gemini** a pro kontrolu siluety.
- **Python skripty** v `gen/`: šablony dílů, BVH → tabulka úhlů, kontrola klouzání chodidel.
- **Godot testy**: `--test=gait` (je), nově `--test=anim:<klip>` = pásek snímků + GIF na telefon, starý a nový vedle sebe.
- **Nepotřebuju**: Spine (placený), snímkové sprity z AI (postava se mezi snímky mění), Godot editor ručně.

## 5. Jak poznám, že je to dobré (měřené, ne od oka)

- Chodidlo na zemi neklouže víc než 2 px za snímek.
- Běh má letovou fázi; koleno ve švihu pod úrovní kyčle; pata po odrazu nad kolenem.
- Žádná mezera ani zlom v lokti, koleni a pase v žádné fázi (pásek 16 snímků, zvětšený).
- Silueta: Eddie a Frank rozeznatelní jako černé stíny.
- GIF každého klipu pošlu uživateli; do hry jde až po jeho „ok“.

## 6. Pořadí práce (pilot Eddie)

1. Návrhový list Eddieho → schválení.
2. List dílů, výřez, nová kostra, stoj → schválení.
3. Mocap: chůze a běh na novou kostru, GIF → schválení.
4. Horní půlka: zbraň u těla, míření, výstřel, přebití.
5. Ostatní pohyby (skok, rybička, skluz, krytí, zásah, pád).
6. Do šedého prologu; starý Eddie zůstane přepínatelný pro srovnání.
7. Když pilot dopadne: Frank, pak bossové (vlastní těla), gangsteři nakonec (sdílená kostra, nové oblečení).

## 7. Rizika a co nevím

- Licence dat CMU pro komerční hru: podle jejich stránky volná, **ověřím před použitím**; náhrada = vlastní klíčování podle referenčních videí.
- Gemini neudrží stejnou postavu mezi listem návrhu a listem dílů → víc pokusů, šablona, případně díly z jednoho obrázku.
- Mocap z 3D do boku: ruce a nohy se překrývají jinak než v kresbě → ruční doladění pořadí vrstev.
- Paměť telefonu: každý hrdina vlastní texturu; bossové ano, řadoví gangsteři ne.
- Rozsah: je to přepis puppet.gd pro hrdinu. Starý systém nechám běžet vedle, dokud nový nebude lepší.

## Zdroje
- Rozbor: [[postava-rozbor-2026-11-24]], [[gemini-neon-2026-11-24]].
- Toon Boom: příprava vystřihované postavy (díly, hierarchie, hlavní kolík); Godot docs: cutout animation; AnimSchool: klíčové pózy běhu;
  CMU Graphics Lab Motion Capture Database (BVH převod cgspeed).

## Stav 24. 11. večer
- Krok 1 hotov: uživatel schválil návrh C (art_src 362; portrét = závazná tvář).
- Krok 2 hotov: list dílů art_src 363 → `gen/char_cut.py`, `gen/eddie_parts.py` → `art/eddie2/` → `main.gd _eddie2_cfg`. Eddie ve hře stojí, chodí a běží s vlastním tělem (`--test=gait --close --chapter=0`). Starý: `--old-eddie`.
- Šablona `gen/char_template.py` se nepoužila: Gemini na dlouhá zadání se šablonou odpovídal jen textem; zabralo krátké zadání bez šablony, klouby jsem odečetl z mřížky.
- Zbývá u Eddieho: krok 3 (běh a chůze z nasnímaného pohybu, zbraň u těla), portrét v HUD, otevřená dlaň, klobouk jako samostatný díl (aby mohl spadnout).

## Stav 24. 11. noc
- Výtky uživatele k první verzi: ruce v jiném měřítku než trup, hlava za kabátem, svetr skoro černý. Opraveno, poučení = pravidlo 39 (měřítko dílů podle tloušťky v metrech, hlava před límcem, srovnání s návrhem vedle sebe před odesláním).
- Krok 3 hotov bez mocapu: `gait2` v puppet.gd (klíčovaná dráha chodidla proti kyčli, běh s letovou fází, vzpřímená chůze, kadence ze skutečné rychlosti, pumpující ruce). Mocap zatím nebyl potřeba.
- Další: krok 4 (míření, výstřel, přebití na novém těle), krok 5 (skok, rybička, skluz, krytí).

## Stav 24. 11. pozdě v noci
- Uživatel: „dodělej všechny pohyby a animace, ať pak hodnotím celek“. Nový test `--test=moves` (82 snímků, 29 pohybů), všechny prošlé, opravy viz HANDOFF (148).
- Běh z úhlů kloubů skutečného běhu (pravidlo 39). Čeká na celkový dojem uživatele, pak Frank stejnou cestou.

