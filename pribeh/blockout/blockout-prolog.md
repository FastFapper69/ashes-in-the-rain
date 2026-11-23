# Blockout: Prolog – THE LAST NOTE

Návrh k posouzení, nic z toho není postavené. Vygenerováno z `prolog.json` (data pro stavbu) skriptem `_blockout.py`, ručně needitovat.
Pravidla a postup: [[pravidla-map]]. Stav všech map: [[stav-map]]. Příběh: [[Srdce-a-hlas]].

**Smysl mapy:** Poznat Eddieho a mít ho rád, než umře. Tutoriál je až druhý účel.
**Proč tudy jde:** Schůzka je za klubem Blue Note. Zadní dvorek je v noci zamčený, takže Eddie musí obejít blok. Muži, kteří ho hlídají, čekají na obou koncích ulice.
**Předává:** Telefon ve 2:10. Frank přijíždí na stejné místo (I-1 THE ALLEY).
**Hraje se za:** Eddie. **Cíl délky:** 5 minut hraní a asi 2 minuty panelů. **Součet úseků:** 4:43, 16.0 tisíce px. Součet je čistý průchod bez smrtí a hledání, s nimi počítej zhruba o třetinu víc.

![[blockout-prolog.png]]

## Návrh pro generátor

`street → street → street → street → last_stand`

Dnešní prolog je jedna ulice se slepou uličkou na konci (last_stand). Zůstává, mění se jen rozložení úseků.

## Postup hráče

- Eddie má plně vylepšený revolver, tři zásahy navíc a dlouhé zpomalení. Nesbírá zkušenosti.
- Nepřátelé: jen obyčejní střelci s pistolí, nejnižší hustota, nikdo se nevzdává.
- Učí se: pohyb, střelba, krytí, skok šipkou, sud s palivem, zpomalení času.

## Pro hráče, který přeskakuje panely

Tři věci, které musí zaznít přímo v mapě:

1. Kdo jsem a kam jdu: bublina „Left the book with Rosie. Good. One less thing to bleed on.“ hned v úseku 1.
2. Co vím: „Frank, I know what you signed. I'm not printing it.“ v úseku 7.
3. Jak to skončí: nevyhratelný boj a poslední bublina „Tomorrow, Frank.“

## Úseky

### 1. Z klubu do deště (klid, 15 s, 1200 px)

- **Prostor:** ulice před Blue Note
- **Nepřátelé:** nikdo
- **Zvuk:** jen déšť, z klubu je slyšet jazz
- **Text:** “No matches. Frank always has the matches.” · “Left the book with Rosie. Good. One less thing to bleed on.”
- **Checkpoint:** ne
- **Náročnost:** A + animace „proklepe kapsy“ (C, malá)

### 2. Novinový stánek (klid, 10 s, 900 px)

- **Prostor:** ulice, stánek s Evening Ledger
- **Nepřátelé:** nikdo
- **Zvuk:** jen déšť
- **Text:** “Frank. I found something in the Pier 17 file.” ... “No.”
- **Checkpoint:** ne
- **Náročnost:** A, stánek B (dá se vynechat)

### 3. První dva (boj, 35 s, 2000 px)

- **Prostor:** ulice, dvě bedny jako kryt
- **Nepřátelé:** 2 s pistolí, nejdřív zavolají
- **Zvuk:** bojové stopy
- **Text:** “Still there.”
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A + animace „sáhne na kapsu“ (C, malá)

### 4. Bedny před zelinářstvím (boj, 40 s, 2400 px)

- **Prostor:** ulice, řada beden
- **Nepřátelé:** 3 s pistolí
- **Zvuk:** bojové stopy
- **Text:** “Lieutenant, you want the bad news or the worse news?” ... “He'll hit me. I'd hit me.”
- **Checkpoint:** ne
- **Náročnost:** A

### 5. Garáž s kanystry (boj, 30 s, 1800 px)

- **Prostor:** garáž, sud s palivem
- **Nepřátelé:** 3 s pistolí, jeden u sudu
- **Zvuk:** bojové stopy
- **Text:** bez textu
- **Checkpoint:** ne
- **Náročnost:** A, garáž jako modul nebo B

### 6. Dodávka (vrchol, 45 s, 2400 px)

- **Prostor:** ulice, dodávka napříč
- **Nepřátelé:** 4 naráz
- **Zvuk:** bojové stopy naplno
- **Text:** “Still there. Rosie, you're marrying an idiot.”
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A

### 7. Tichá ulice (klid, 20 s, 1500 px)

- **Prostor:** ulice bez beden
- **Nepřátelé:** nikdo
- **Zvuk:** poprvé ve hře klavír, potichu
- **Text:** “Frank, I know what you signed. I know what it cost you. I'm not printing it.” ... “That's the one. Say it like that.”
- **Checkpoint:** ne
- **Náročnost:** A

### 8. Za klubem nikdo není (ticho, 8 s, 700 px)

- **Prostor:** slepá ulička, neon JAZZ zepředu
- **Nepřátelé:** nikdo
- **Zvuk:** klavír utne, jen déšť a bzučení neonu
- **K nalezení:** na římse holubi, při příjezdu aut uletí
- **Text:** “Half past one. I'm early.”
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A, holubi B + C (dá se vynechat)

### 9. Tři auta (vrchol, 70 s, 2500 px)

- **Prostor:** slepá ulička, auta na obou koncích
- **Nepřátelé:** nekonečno, zpomalení se nedobíjí
- **Zvuk:** bojové stopy, po 60 vteřinách jen tep
- **Text:** bez textu
- **Checkpoint:** ne
- **Náročnost:** B (auta v mapě), nevyhratelný konec ve hře je

### 10. Pád (ticho, 10 s, 0 px)

- **Prostor:** stejné místo
- **Nepřátelé:** nikdo
- **Zvuk:** ticho, pak klavír do panelu
- **Text:** “Tomorrow, Frank. I'll tell you tomor—”
- **Checkpoint:** ne
- **Náročnost:** C, animace „kapsa, pak sirky“

## Rizika

- Úseky 1, 2, 7 a 8 jsou bez střelby. Dohromady 53 vteřin, víc nesmí být.
- Úsek 9: 70 vteřin boje, který nejde vyhrát, může být moc. Po první zkoušce na telefonu zkrátit podle pocitu.

## Poznámky Claude Code

Sem připsat, co je těžké, hloupé nebo proti pravidlům map, a opravit odhady A, B, C.
