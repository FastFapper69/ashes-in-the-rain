# Předání pro Claude Code

Od příběhového chatu, 23. 11. 2026 večer. Uživatel: „vše zálohuj a předej to Claude Code“. Start: [[MAPA]]. Stav map: [[stav-map]].

## Co se změnilo

Příběh hry je přepsaný a schválený uživatelem. Kostra zůstala, změnilo se srdce a hlas. Ve hře z toho zatím není nic, všechno jsou poznámky ve složce `pribeh/`.

Pět věcí, které musíš vědět, než sáhneš na jakýkoli text, panel nebo mapu:

1. **Frank mluví celou hru k mrtvému Eddiemu** („you“). Pět pravidel hlasu je v [[Srdce-a-hlas]].
2. **Jeden požár.** Molo 17 v roce 1939. Rok 1931 je jen vzpomínka na otce hasiče: žádný žhář, Rourke nenesl petrolej. Petrolej v bednách na Santa Lucii zůstává.
3. **Rourke dal zabít Eddieho.** Odhalení kapitoly III, důkaz je telefonní lístek od Briggse. Nahrazuje odhalení o činžáku.
4. **Jeden deník.** Eddie ho v prologu dá Rosie. Žádný zápisník v dešti. Slovo FRANK je nadpis prázdné stránky, kterou si nechá Rosie.
5. **Dva symboly a holubi.** Popel a sníh, sirky. K tomu jedno krmení holubů na kapitolu.

Pravidlo 14 v SKILL.md je zčásti zrušené, platí pravidlo 35. Kapitola [[ch10-story-cutscenes]] má nahoře shrnutí.

## Co si přečíst, v tomhle pořadí

1. [[pribeh-denik]]: co se rozhodlo a proč, a seznam zahozených nápadů.
2. [[Srdce-a-hlas]]: příběh, hlas, prolog a repliky kapitoly I.
3. [[pravidla-map]]: jak se teď navrhují mapy.
4. [[blockout-prolog]] a [[blockout-I-1-alley]]: první dva návrhy map.

Zbytek (kapitoly II až IV, [[scenar-mapy]], [[jedenact-a-pisen]], [[mapy-prolog-a-kapitola-I]]) otevři, až na to téma sáhneš.

## Co udělat

Pořadí platí. Další krok až po souhlasu uživatele s předchozím.

1. **Posoudit oba blockouty.** Do oddílu „Poznámky Claude Code“ na konci každé karty napiš: co je těžké, co je hloupé nebo proti pravidlům map, které odhady A, B, C jsou špatně a kolik minut mapa opravdu vyjde. Ten oddíl se při novém generování karty zachová. Zbytek karty needituj, mění se přes `.json`.
2. **Říct to uživateli** krátce česky a počkat, co z toho chce.
3. **Postavit šedou verzi prologu** z hotových modulů, bez nových kreseb, s Eddieho bublinami. Spustit ji uživateli přes hřiště (pravidlo 21), ne přes kampaň.
4. **Texty prologu a kapitoly I do hry**: `cutscene.gd`, úvody a závěry v generátoru map, věty na titulní obrazovce, vnitřní hlas. Jen jako text a bubliny, hlas se nahrává až na konci (pravidlo 17). Zdroj: [[Srdce-a-hlas]] a [[scenar-mapy]].
5. **Škrty**: panel se zápisníkem v dešti, věta „One word: FRANK“ v závěru prologu, petrolej u Rourka v roce 1931, jméno Kowalczyk, stránky deníku kapitoly III o roce 1931 a o helmě v zastavárně.
6. **Zapsat stav** do [[stav-map]] (sloupce Posouzeno, Šedá verze, Kresby, Hotovo).

## Na co si dát pozor

- Délky v pixelech a vteřinách v blockoutech jsou odhad od stolu. Když nesedí, oprav čísla v `.json` a spusť `python3 pribeh/blockout/_blockout.py`.
- Názvy uzlů v „Návrhu pro generátor“ jsou jen návrh. Oprav je podle toho, co generátor umí.
- Když je něco v příběhu proti tomu, co ve hře jde postavit, neměň příběh sám. Napiš to do poznámek a řekni uživateli. Příběh se ladí v příběhovém chatu.
- Do složky `pribeh/` zapisují dva chaty. Před commitem `git fetch`.

## Co dělá příběhový chat dál

Blockouty zbytku kapitoly I (I-2 až I-5 a sen) a scénáře úseků kapitol II až IV.
