# Až bude PC volné (okna „Uložit jako“ zavřená, Claude in Chrome připojený)

## 1. Stáhnout (už vygenerováno v Artlistu, MCP Session)
Dialogy v komiksu, voice/<key>.mp3 (22050 Hz mono 64k):
- f54dc0f57b  Mickey, telefon       01a1e43e-cdeb-732e-95b1-73cb60606786
- 7bf2a2ffb3  Eddie                 01a1e43e-d1db-7f93-9229-cc94418c905a
- d983d5403b  Mickey, umírá         01a1e43e-d572-7e24-815a-c03c26c2c826
- 920d6db581  Mickey, „Feed my birds“ 01a1e43e-d9a1-7264-8f91-fc31cea1546b
- f6403da3be  Rosie                 01a1e43e-ddf3-7eac-b3a5-1e0fba138406
- cd8da7992d  Rourke, zatčení       01a1e43e-e19e-70fe-b99d-9eab2ae0d2b3
- 55bea9f8e3  Briggs                01a1e43e-e543-7b1b-aa6f-f9e36e59b2bb
- 5dc0a2b459  Rourke, přípitek      01a1e43e-e9a8-7d31-bde6-16e76ba4683d
- 88914502ac  vypravěč (Gravity)    01a1e43e-ed0e-70d0-89cf-de6cac3185f4
Pak v cutscene.gd přepsat Rourkův řádek: "Up in the Saint's tower, two old men were drinking to me. One of them was Declan Rourke." + "\"He'll come. He always comes. He's his father's son.\"" (klíče 88914502ac, 5dc0a2b459). Mluvené repliky už se přehrávají, jakmile soubor existuje.

## 2. Gemini (art_src 205+), zelené pozadí #00FF00, stejná póza jako gunsmith kresby
- 205/206 brokovnice nová / ošoupaná (edit 205 → 206): vstup art/ui/gunsmith/shotgun.png
- 207/208 tommy nový / ošoupaný: vstup art/ui/gunsmith/tommy.png
Pak gen/gun_parts.py rozšířit (díly: brokovnice pažba/předpažbí/hlaveň/pouzdro, tommy pažba/buben/hlaveň/tělo).

## 3. Doma rovnou přepnout na Claude Code na PC (rendrované testy tam běží v reálném čase)

## 4. Hlášky ke svědomí (Artlist audio, 3 hlasy adam/james/shadow, gen/bark_voices.py)
Nové druhy v barks.gd: shotup ("{n} HAD HIS HANDS UP!"…), noquit ("HE SHOOTS YOU ANYWAY!"…), quit ("THEY SAY YOU LET MEN WALK!"…).
`python3 gen/bark_voices.py scripts` je přidá do scénářů; nahrát, pak `split`.

## 5. Gemini: řez činžákem (kapitola I, mapa TENEMENTS) – stavebnice
Proč stavebnice: Gemini neudělá velký řez a fasádu, které by sedly na pixel. Kusy stejné velikosti se dají skládat
nad sebe a vedle sebe; gen/section_art.py (napíšu) najde v každém kusu čáru podlahy a srovná ji na přesný řádek.

### Měřítko (pevné pro všechny kusy)
- Patro ve hře = 700 px (muž ~420 px, dveře ~520 px). Kus = 3168×1344 = přesně jedno patro (měřítko 0,52).
- Řádky obrázku: 0–110 černý ŘEZ STROPU (deska patra nad, tuší, zubatý okraj s cihlami/trámy v řezu);
  110–1230 prostor; **1230 = čára podlahy, po které se chodí**; 1230–1344 černý ŘEZ PODLAHY.
- Žádná perspektiva podlahy (ne jako art/rooms/tenement.png, kde se nedalo poznat, kde stojí nohy): zadní stěna
  rovně zepředu, podlaha je jen horní hrana černé desky + nanejvýš tenký pruh prken.
- Oba boční okraje končí půlkou svislého dřevěného pilastru/trubky: dva kusy vedle sebe dají celý pilastr,
  spoj není vidět. Nic jiného okrajem neprochází.
- Bez postav. Nic nestojí na podlaze v cestě (jen u zadní stěny: koš, radiátor, noviny).
- **Bez předělů** (uživatel 16. 11.): v kusech 211–213 žádná koncová/boční stěna ani okno u okraje – zeď budovy
  je jen v kusu 214 na koncích chodby. Kusy se střídají, nikdy dva stejné vedle sebe.

### Společný úvod do každé zprávy (nový chat Gemini na každý kus; nahraj art/rooms/tenement.png jako vzor stylu,
od kusu 2 i schválený kus 1 jako vzor měřítka)
"Ink-and-wash noir comic illustration, same hand-drawn style, line weight and muted sepia-grey palette as the
reference image; red only on lights. NEW drawing, the reference is only for style. A side-scrolling video game
building CROSS-SECTION, seen exactly from the front (orthographic, no perspective, no vanishing point): the front
wall of the building is cut away so we look straight at the back wall of one storey. Wide 21:9 image. The top
8 % of the image is the solid black cut of the floor above (inked slab edge, broken bricks and joists in the cut).
The bottom 8 % is the solid black cut of this storey's floor slab; its top edge is a perfectly straight horizontal
line where people walk. Both the left and right edges end exactly on half of a plain vertical wooden pilaster so
copies can be joined side by side. No people. Nothing standing in the middle of the floor."

### Kusy (art_src od 211, zelené pozadí netřeba – vše je plné)
211 CHODBA A: "…A 1947 Hell's Kitchen tenement hallway: three apartment doors with brass numbers 2A 2B 2C, doors
     74 % of the image height standing on the floor line, peeling striped wallpaper over wainscot, a radiator, one
     bare bulb hanging from the ceiling, lit and glowing warm."
212 CHODBA B (tma): "…same hallway, different layout: two doors (one boarded up), the bulb broken and dark, light
     only from a door left ajar, trash bin, scattered newspapers against the wall."
213 CHODBA C (okno): "…hallway with one door and a tall back window to the light-well, rain on the glass, a red
     neon glow from outside on the window frame, a wall payphone."
214 KONEC BUDOVY: "…as 211, but the left 18 % is the building's outer side wall in cross-section: a thick brick
     wall cut through, bricks visible in the cut, from the floor slab up to the ceiling slab."  (zrcadlí se pro pravý konec)
215 SCHODY VE ZDI (uživatel 16. 11.: schody jsou vzadu ve zdi, ne z boku – z boku nejde cikcak trasa; art_src 211
     = pokus z boku, zamítnut): "…as 211, but in the middle of the back wall a wide dark opening (no door) in which a
     straight wooden flight with a banister rises from the floor line at the opening's right side up to the left into
     darkness under the ceiling slab; the opening's floor is the hallway floor." Rameno vždy vede NAHORU z patra.
(staré) 215 SCHODIŠTĚ (čtverec 1:1, DVĚ patra): "…a square image, two storeys tall. Bottom 4 % black floor slab, a black
     slab across the middle only on the right half (the landing of the floor above), top 4 % black slab. One straight
     flight of wooden stairs with a banister rises from the bottom floor at the left edge to the middle landing on
     the right, exactly half the image height. Dim, one sconce on the landing."  (zrcadlí se pro druhou stranu)
216 ŽEBŘÍK NA STŘECHU: "…as 211 top storey: a wooden ladder fixed to the back wall rises from the floor line to an
     open square hatch in the black ceiling slab, rain and night sky seen through the hatch."
217 BYT A: "…a small tenement apartment in the same cross-section: kitchen table and chairs against the back wall,
     iron stove, window with a torn curtain, crucifix, a door on the left back wall."
218 BYT B: "…a bedroom: iron bed against the back wall, wardrobe, washstand, a suitcase half packed, window."
219 FASÁDA PATRO: "…the OUTSIDE of the same storey, seen from the street, exactly the same size and floor line:
     red-brown brick tenement front, two tall sash windows whose sills are at 45 % and tops at 15 % of the image
     height, one window lit warm, one dark; a stone band at the bottom where the storey ends."
220 FASÁDA PŘÍZEMÍ: "…the ground floor front from the street: a stoop-less entrance door (the door bottom on the
     floor line), a shop window with lettering 'TAILOR', a hanging sign, a gas lamp bracket with its lamp, wet bricks."
221 ŘÍMSA: "…the top of the facade: an ornate inked cornice across the whole width at 60–75 % of the image height,
     dark night sky with rain above it, the cornice top edge is a straight line (the roof parapet)."

### Šablona promptu (poučení z přegenerování 16. 11., podrobně knowledge ch03 „Gemini prompt lessons“)
- Otvor ve zdi v řezu: „cut wall ONLY ABOVE the opening as a lintel … BELOW that NO wall, the floor runs straight through“.
- Okno ve zdi v řezu: „hole THROUGH the cut wall, seen from the side, NO glass“ + „the back wall has NO door and NO window“.
- Zrcadlené kusy: „NO text, numbers or letters“. Železo z boku: výšky podest v % odspodu.

### Po stažení
- `python3 gen/section_art.py` (napíšu): srovná čáru podlahy na řádek 1230, zkontroluje spoj dvou kusů, uloží
  art/section/tenement_*.png + Basis importy. Pak testovací mapa řezu a screenshoty 1280 i 1560.
- Odmítnout a přegenerovat kus, kde: je perspektiva podlahy, dveře nestojí na čáře, okraj není pilastr, je tam postava.

## 6. Z výzkumu – SCHVÁLENO uživatelem 16. 11. večer (zjištění 1, 2, 3, 4, 6 z `ashes-vyzkum` ch11–ch14)
Dělat postupně mezi ostatní prací, každý bod s testem/screenshoty podle pravidel. Přístupnost (titulky, assist mód) a byznys/licence zatím NE.

1. **Vodoznaky v artu** (ch12): projít všechny kresby z Gemini (`art/`, `art_src`) a hledat zbytky viditelného vodoznaku Gemini
   (hvězdička/logo v rohu, typicky vpravo dole) – skript, který vyřízne rohy všech PNG do jednoho kontaktního archu + ruční kontrola.
   Nalezené: vyčistit (retuš) nebo přegenerovat. Výsledek a seznam souborů do HANDOFF.
2. **Nástroje Claude Code na PC** (ch11) – instalaci vždy krátce potvrdit s uživatelem v okně Claude Code:
   - runtime Godot MCP `Erodenn/godot-mcp-runtime` (MIT, zdarma): screenshoty běžící hry, simulovaný vstup, živý strom scény →
     používat ke kontrole „podívej se sám“. Jeho dočasný autoload nesmí skončit v commitu (ověřit .gitignore / git status).
   - hooks v `.claude/settings.json`: po Edit/Write `*.gd` rychlá kontrola parsování (Godot `--headless --check-only` nebo ekvivalent),
     při Stop krátký smoke test jednoho `--test=` módu; těžké věci (bot přes všechny mapy) dál ručně. Nic, co trvá přes ~1–2 min.
   - GdUnit4 (MIT): prvních 10–20 testů na čísla – XP křivka, násobiče skóre, CURVE, packs list, barks bez opakování.
   - TokenEconomizer (microsoft, Apache 2.0) na týden zkušebně; porovnat spotřebu. Zapsat do ch11, co se osvědčilo.
3. **Kamera** (ch14, Itay Keren): (a) cue focus – přitažení kamery k bossovi při vstupu, k padající neonce, k světlometu;
   (b) platform snapping – výška kamery se při skoku/úskoku drží a srovná až po dopadu (méně houpání při střelbě);
   (c) krátký nájezd na začátku mapy, který ukáže trasu nahoru (schody, střecha, řez domem). Pravidla: žádné tvrdé střihy,
   pravidlo „jen aktuální patro v záběru“ platí dál. Porovnat před/po na videu nebo sérii screenshotů 1280 i 1560.
4. **Telemetrie** (ch14): události `death` (mapa, x, y, příčina, čas na mapě, build), `map_done` (čas, smrti, XP) a `quit`
   (kde hráč zavřel hru) do Supabase vedle `ashes_reports` (nová tabulka, jen anon insert, čtení jen přes MCP – klíče nikdy do repa).
   Skript `gen/tools/heatmap.py`: heatmapa smrtí přes pás mapy + funnel po mapách. Souhlas: jedna věta v nastavení
   („Send anonymous play data“, výchozí ZAP, jde vypnout) + zmínka v privacy textu; žádná osobní data kromě user agentu.
6. **Haptika** (ch13): na webu Android `navigator.vibrate`, iPhone Safari 17.4+ trik se skrytým `<input type="checkbox" switch>`
   (jen při dotyku, jinak nefunguje) – v `gen/deploy/crash.js` nebo vlastním JS + `JavaScriptBridge` z Godotu. Jemně a málo:
   výstřel (velmi krátce), zásah Franka, zabití, dopad z výšky, výbuch. Přepínač „Vibration“ v nastavení (výchozí ZAP).
   Ověřit na uživatelově iPhonu 17; když trik nepůjde, nechat jen Android a zapsat do HANDOFF.

## 7. Kontrola podobnosti screenshotů – SCHVÁLENO uživatelem 16. 11. (z `ashes-vyzkum` ch09, nápad z craft-anything)
Cíl: automaticky poznat vizuální regresi, aby se nic nerozbilo bez povšimnutí (pravidlo „podívej se sám“ tím NEnahrazuje – jen upozorní, kam se dívat).
1. `gen/tools/likeness.py`: SSIM (skimage nebo vlastní numpy) + jednoduchá shoda rozvržení mezi novým screenshotem a schváleným
   referenčním (`gen/tests/approved/<test>_<1280|1560>.png`), výstup skóre 0–100 a obrázek rozdílů (heatmapa) do `_shots/diff/`.
2. Maska věcí, které se mění samy (déšť, oheň, blikající neon, kouř, pára): stejnou scénu vyfotit 3× (jiný čas / seed) a pixely, které se
   liší mezi těmi třemi, při porovnání vynechat. Masku uložit vedle reference.
3. Referenční screenshoty jen se souhlasem uživatele („schváleno“ = poslal OK nebo je ve hře nasazené a nestěžoval si); nová reference
   se zapisuje vědomě (`--approve`), nikdy automaticky.
4. Pro menu a UI: porovnání i s mockupem z Gemini, který uživatel schválil (jen orientačně – jiné rozvržení dá nižší skóre, sledovat trend).
5. Zapojit do testů: po `--test=` módech s fotkami spustit likeness; pod prahem (začít ~85, doladit) vypsat `LIKENESS LOW <test> <šířka> <skóre>`
   a otevřít diff. Na PC lze pustit i z hooku Stop, pokud to trvá do ~1 min.
6. Výsledek a práh zapsat do `ashes-znalosti` ch02 (Tests) a cheatsheetu.

## 8. POKUS: Blender jako pomocník pro 2D art – SCHVÁLENO uživatelem 17. 11. ráno (zatím jen test, ne plošně)
Nástroje: Blender 5.2+ na PC + EL4CTEO/blender-skills (MIT; plugin `/plugin marketplace add EL4CTEO/blender-skills`,
`/plugin install blender-agent-skills@blender-agent-skills`) – instalaci krátce potvrdit s uživatelem. Účtový skill `blender-modelovani` má pravidla.
ZÁSADA: 3D nikdy není vidět ve hře tak, jak vyrenderovalo – vždy jen jako předloha/data; viditelný výsledek je ruční kresba (Gemini) nebo
přemalba. Postavy se do 3D NEdělají (loutky zůstávají).

Pokus (dvě malé věci, pak ukázat uživateli porovnání a čekat na verdikt):
1. **Šablona místnosti pro Gemini**: šedý blockout jedné scény z řezu činžákem (chodba + schody v zadní stěně) ve stejné kameře a měřítku jako hra
   (postava = 1,8 m, FIG 1.18, čára podlahy jako v section_art). Render: šedé tvary + čáry hran (Line Art / Freestyle), bez textur.
   Dát Gemini jako vzor perspektivy a rozměrů („redraw this layout in the style of art/rooms/tenement.png, keep every edge where it is“).
   Porovnat s kresbou bez šablony: rovné čáry, měřítko proti postavě, schody vs kolize. Kolize brát z rozměrů blockoutu.
2. **Zbraň u zbrojíře**: jednoduchý model revolveru (nebo brokovnice) s vyměnitelnými díly (hlaveň, rukojeť, mířidla), renderovaný
   inkoustovým NPR stylem (blender-stylized-npr: outline, 2–3 tónové pásy) ve stejném úhlu jako gunsmith kresby. Stavy: starý/opotřebovaný
   → každý upgrade. Pak přetáhnout Gemini do ručního stylu (stejná póza), a porovnat se současnými kresbami 201–208.
3. Volitelně, až 1–2 dopadnou dobře: normálová mapa z jednoduchého 3D tvaru jedné fasády/rekvizity pro světla v Godotu
   (porovnat s dnešní normálovou mapou na `--test=look`), a mechanické animace (jeřáb, cedule, ventilátor) jako 3D → snímky → přemalba.
Výstup pokusu: screenshoty 1280 i 1560 před/po, 2–3 věty do HANDOFF, poznatky do `ashes-vyzkum` (nová kapitola 15, pokud se osvědčí).

## 9. OPRAVA – uličky se kroutí a scény na sebe nenavazují – uživatel naštvaný 17. 11. dopoledne (PRIORITA, před vším ostatním)
Uživatel (fotky z monitoru, art_src/ ne – v chatu): „prostory jako uličky se stále úplně kreténsky uhýbají, myslel jsem, že tohle už jsme si prošli.
To samé návaznosti scén. Nemůžu jít přeci z okna do otevřené uličky.“ Nová tvrdá pravidla 24 a 25 v `ashes-znalosti` §1 + ch05.
Viděno: (a) ulička s párou – dveře a zdi v hloubce jsou zkosené do kosodélníku (DEEP_PERSPECTIVE posouvá vzdálený konec),
(b) chodba činžáku (dveře 3C, schody) stojí hned vedle ulice s krejčím (TAILOR) a mezi nimi tmavá díra – interiér nalepený vedle ulice,
(c) cedulky na dveřích 3C i 3A jsou nečitelná AI „glyph soup“ (pravidlo 1 – `gen/fix_cut_text.py` nebo přemalovat),
(d) uživatel 10:47: z ulice (cihly, chodník) rovnou do chodby se dveřmi 3A – „hnusný tvrdý předěl, žádné vstupní dveře“: tvrdý svislý řez
   mezi kresbami, podlaha chodby jinak vysoko než chodník, žádná fasáda ani vchod. Do domu se vchází jen namalovanými vstupními dveřmi
   ve fasádě (dveře se otevřou / fasáda se rozpustí), chodba je uvnitř téže fasády – nikdy kresba chodby položená na konec ulice.
1. **Hloubkové pohledy stojí**: vypnout posun/smyk úplně (DEEP_SLIDE = 0, DEEP_LIFT = 0, pak DEEP_PERSPECTIVE a `_tick_deep` smazat jako mrtvý kód,
   pokud nic jiného nepotřebují). `--test=deep:<art>` u KAŽDÉ položky DEEP_SPLIT ze 3 poloh kamery → snímky musí být pixelově stejné jako kresba.
   Žádný nový efekt hloubky bez ukázky v TEST LAB a souhlasu uživatele.
2. **Audit návazností** – rozšířit `gen/tests/audit_maps.py` o pravidla (exit 1 při chybě) a projet všechny mapy + SANDBOX:
   - interiér/řez (rooms, sections, flats) nikdy přímo vedle uliční/uličkové kresby bez fasády téhož domu kolem (řez domem s dissolve);
   - vstup/výstup z budovy jen namalovaným otvorem: dveře do ulice → chodník před TOUTÉŽ fasádou; okno → požární schodiště/římsa/střecha
     TÉHOŽ domu (nebo pád na ulici před tou fasádou); nikdy z okna do uličky, jiného domu nebo jiné scény;
   - každá změna druhu prostoru (interiér/ulice/ulička/střecha/podzemí) má namalovaný přechod (dveře, brána, schody, fasáda), jinak prolínačku.
   Výpis: mapa, x, dvojice sousedů, proč. Opravit v gen/levels.py (chunk `section`/`stunts`/`lab`: dům s fasádou kolem chodby i bytu,
   okno bytu ústí na jeho vlastní požární schodiště na fasádě), ne lepením kulis.
3. Ověřit: boti na všech mapách, `--test=look` u KAŽDÉHO přechodu z auditu (1560 i 1280), prohlédnout zvětšené; přechody, které se změnily,
   ukázat uživateli jako list snímků v TEST LAB (`--sandbox=1`). Až potom deploy + řádek do changelog.gd.
4. HANDOFF: krátký záznam + co audit našel (počty po mapách).

## 10. Modulární systém – aby předěly mezi scénami nebyly poznat – SCHVÁLENO uživatelem 17. 11. 11:17 (hned po §9)
Nejdřív si přečti `.claude/skills/ashes-vyzkum/chapters/ch15-modular-kits-seams.md` (celé). Platí pravidla 24/25 a 20/22/23.
1. **Jednotné míry**: tabulka v gen/kit.py pro každou uliční kresbu, interiér a práh – čára chůze, horní hrana obrubníku, výška očí/horizontu,
   výška a šířka dveří, římsa (px kresby). Změřit všechny existující kresby, vypsat odchylky (nový skript gen/tests/metrics_audit.py).
   Nové zadání pro Gemini vždy s těmito čísly (+ šedá šablona z Blenderu, §8). Kresby, které se moc liší, označit k přemalování (seznam, ne hned).
2. **Typy okrajů**: každá uliční kresba dostane levý/pravý typ (`party_wall`, `alley_mouth`, `facade_door`, `open_lot`, `fence`, `water`).
   `street()` v gen/levels.py smí spojit jen stejné typy; `gen/tests/audit_maps.py` hlásí chybu jinak. Výpis, kolik kreseb má který typ.
3. **Sada prahů**: pro každou změnu druhu prostoru jedna kresba (fasáda se vstupními dveřmi do řezu domem, ústí uličky s bránou/obloukem,
   vrata do dvora, schody do metra, brána do doků, nakládací vrata skladu). Jednotná velikost otvoru, aby za každé dveře pasoval každý interiér.
   Interiér začíná jen za dveřmi fasády TÉHOŽ domu. Chybějící kresby → zadání do Gemini (QUEUE §5 šablona, poučení z ch03).
4. **Mapa = graf prostorů** (Dead Cells): v gen/levels.py popsat mapu jako sled uzlů (ulice → ústí uličky → dvůr → zadní dveře → schodiště →
   byt → okno → vlastní požární schodiště → střecha); každý uzel vybírá kresbu z poolu podle typu okrajů/otvorů. Pravidlo 25 pak platí z konstrukce,
   audit to jen ověří. Začít v TEST LAB (`--sandbox=1`), pak kapitola I.
5. Později (až 1–4 stojí a uživatel je viděl): navazující kresby rozšiřováním okraje v Gemini (outpainting) + spoj na namalovaném okapu/pilíři;
   kde napojit nejde, dveře + inkoustová prolínačka jen bez aktivních nepřátel.
Ověření: boti na všech mapách, audit bez chyb, `--test=look` u každého přechodu 1280 i 1560 (prohlédnout zvětšené), list snímků TEST LAB
ukázat uživateli před deployem. Do HANDOFF krátce, co se změnilo; nová trvalá pravidla do `ashes-znalosti`.

## 11. Požární žebřík u markýzy nečitelný (uživatel 17. 11. odpoledne)
„Vedle markýzy ten žebřík bude potřeba jakoby 3D nebo zvýraznit, protože není poznat, že na to jde skočit.“ hk_tailor (gen/kit.py
ladders (2020, 693, 902)): spodní výsuvný žebřík vyříznout do vlastní vrstvy (pravidlo 20: interaktivní věc kousek před zdí, paralaxa +
kontaktní stín, jemný obrys/odlesk kovu jako u postav), zeď za ním doplnit (Gemini bez žebříku, nebo vyříznutý kus z varianty).
Případně krátký záblesk/pohup žebříku, když je Frank blízko. Ověřit snímkem proti kresbě (pravidlo 23) ve 1280 i 1560.
Uživatel hned potom: „to samé ty balkónky, na které jde vylézt, vlastně všechny tyhle typy interaktivních věcí to musí mít“ (pravidlo 27).
Postup: Gemini – kresba bez požárního schodiště + schodiště (podesty, schody, žebřík) na zeleném (jako markýza/hydrant, street_props.py);
pak projít všechny „drawn“ podlahy ve všech kresbách (catwalk_style drawn) a udělat totéž. Pokus s výřezem přímo z malby (17. 11.) byl špinavý – zahozen.
