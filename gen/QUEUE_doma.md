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

## 5. Gemini: řez domem, činžák (kapitola I) – stavebnice, vše ve stejném měřítku, bez postav
Patro ~700 px ve hře (muž ~420 px), podlaha vždy na stejném řádku obrázku. Styl jako art/rooms/tenement.png.
- pruh patra: chodba činžáku se dveřmi bytů (3 varianty: oprýskaná, s čísly bytů 1A–4C, tmavá se zhasnutou žárovkou)
- sloupec schodiště vlevo a vpravo (schody v kresbě = schody ve hře)
- pruh fasády na jedno patro (okna padnou na chodbu), přízemí se vchodem, římsa se střechou
- byt jako malá místnost (2 varianty), poklop na střechu
