---
name: ui-papir
description: Rules and tools for every menu, button, card and caption in Ashes in the Rain (paper.gd). Read before building or changing any UI screen; run the UI check before shipping.
---

# UI z papíru – pravidla (poučení z Pixel Krypty a z téhle hry, 14. 11. 2026)

Uživatel: „Neodevzdávej mi odpad.“ Každá obrazovka se před odesláním **zkontroluje automaticky i očima**.

## Stavebnice `paper.gd`
- `Paper.sheet(kind, size)` – kus papíru (kresba z Gemini, `art/ui/paper/src`). Druhy: `panel` (komiksový rámeček),
  `tape` (lepicí páska), `strip` (pruh papíru), `tag` (štítek), `folder` (složka), `clip` (výstřižek).
- `Paper.button(kind, size, on_press, sound)` – papír jako tlačítko (stisk: ztmavne, klesne, stín se přiblíží).
- `Paper.write(box, text, font, size, color, align, part, air)` – text **uvnitř vnitřní linky** kresby, s ~jedním písmenem vzduchu.
  `part` = část textové plochy (např. horní třetina na číslo karty).
- `Paper.caption(text, font, size, max_w)` – komiksový rámeček **přesně na míru textu** (měří vnitřní linku a dopočítá velikost).
- `Paper.place_time("A · B · C")` → dva řádky „A / B, C“ (tečkové řetězce jsou zakázané).

## Kresby se nikdy nedeformují
- Měřítko je u druhu pevné (`scale`: stejná tloušťka linky na všech rámečcích; malé boxy celou kresbu zmenší, aby rohy zůstaly celé).
- Delší/kratší box: konce (roztržené okraje, rohy, rastr) zůstanou, natahuje se jen **čistý střed** podél jedné osy.
  `caps` u druhu musí obsahovat celý rastr v rozích (změřeno: rastr panelu sahá ~290 px od kraje).
- `fixed` druhy (štítek, složka, výstřižek) se jen zmenší a vystředí.
- Žádné `StyleBoxFlat` obdélníky, žádné natažené `StyleBoxTexture` na kresby.

## Rozvržení
- Okraj obrazovky 48 px (`M`), mezi papíry 16 px (`GAP`). Viewport je 720 vysoký, šířka 1280–1600+ – **testuj 1280 i 1560**.
- Jedna hlavní akce na obrazovku (největší papír, výraznější písmo: BEGIN/CONTINUE, PLAY).
- Zamčené věci říkají proč („LOCKED / CLOSE CASE 2 FIRST“), ne jen šedá barva. Zamčené karty jsou tmavší, ale text čitelný.
- Popisky ve hře: komiksové písmo (Comic Neue Bold Italic), verzálky, zarovnání vlevo, rámeček na míru.
- Stejné náklony (`TILT`) pokaždé – žádné `randf` v rozvržení.

## Kontrola (povinná)
- Každý `_shot()` v testech spustí `Paper.audit()` nad horní vrstvou UI a vypíše `UI BAD …`:
  text přes vnitřní linku papíru, text přes text, papír přes papír, cokoli u okraje obrazovky, tečkové řetězce,
  text širší než box, víc řádků než se vejde. **Výstup musí být prázdný.**
- Testy: `--test=menu --progress=N` (titul + spis pro stav hráče, N = hotové mapy), `--test=pause` (pauza + nastavení),
  `--test=page`, `--test=card`, `--test=choice` (volba + popisky ve hře), `--test=cut:<id>`, `--test=paperkit` (všechny druhy papíru).
- Pak snímky **opravdu prohlédnout zvětšené** (výřez 2–3×): zarovnání, vzduch kolem textu, nic se nedotýká kresby (kroužek štítku, sponka).

## Jednotný vzhled (Gemini art review, 14. 11. 2026)
- **Tři písma, nic dalšího:** Oswald (nadpisy, tlačítka), Special Elite (dokumenty, data, opis deníku),
  Comic Neue Bold Italic (popisky a řeč v komiksu). Ručně psaný ReenieBeanie jen jako Eddieho písmo na samotné stránce deníku.
- **Tlačítka na obrazovce hry** jsou tištěné odznaky (`art/ui/badge_*.png`, rodina stopek): tmavý kotouč, krémový prstenec.
  Žádné ploché vektorové ikony ani kreslené kroužky z kódu.
- **Více voleb na jednom papíře:** `Paper.line_button(box, label, part, on_press, sound)` – řádek listu jako tlačítko (titulka: policejní hlášení `report`).
- **Žádné dva sousední papíry stejné:** `Paper.sheet` je střídavě zrcadlí a stárne o odstín; nové druhy přidávat se stejným pravidlem.
- Paleta: tuš #0D0D0F, uhel #2B2A29, sépie #7A7062, novinový papír #DFD3BE, jantar jen u zdrojů světla, karmín jen krev a neon.
- Přes vše leží jeden list papíru (`PRINT_SHADER` v main.gd, vrstva 100): nové vrstvy UI nikdy nad 99.
