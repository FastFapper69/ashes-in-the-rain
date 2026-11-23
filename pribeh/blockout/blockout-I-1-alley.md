# Blockout: I-1 THE ALLEY

Návrh k posouzení, nic z toho není postavené. Vygenerováno z `I-1-alley.json` (data pro stavbu) skriptem `_blockout.py`, ručně needitovat.
Pravidla a postup: [[pravidla-map]]. Stav všech map: [[stav-map]]. Příběh: [[Srdce-a-hlas]].

**Smysl mapy:** Frank je slabý a sám. Střelci jsou pořád poblíž, protože hledají Eddieho deník a nenašli ho.
**Proč tudy jde:** Frank odchází od těla pěšky a narazí na muže, kteří prohledávají popelnice. Utečou mu domem, on musí vrchem.
**Předává:** Střelci ujedou autem na východ. I-2 BACK STREETS začíná honičkou za jejich hlídačem Sammym.
**Hraje se za:** Frank. **Cíl délky:** 6 až 7 minut hraní. **Součet úseků:** 5:20, 19.5 tisíce px. Součet je čistý průchod bez smrtí a hledání, s nimi počítej zhruba o třetinu víc.

![[blockout-I-1-alley.png]]

## Návrh pro generátor

`street → yard → street → house → street:wash_alley → street`

Návrh uzlů pro generátor. Dům v řezu a šňůra jsou stanoviště 1 a 2 z hřiště. Názvy uzlů opraví Claude Code.

## Postup hráče

- Frank začíná od nuly: základní zdraví, opotřebovaný revolver, krátké zpomalení.
- Nepřátelé: střelci s pistolí, v druhé půlce dvě brokovnice (už je to tak v generátoru).
- Nové pro hráče: první vzdání a milost, vstup do domu dveřmi, kop do dveří bytu, jízda po šňůře.
- Na konci mapy by měl hráč mít na první vylepšení.

## Pro hráče, který přeskakuje panely

Tři věci, které musí zaznít přímo v mapě:

1. Kdo umřel: O'Malley v úseku 1, „Sorry about your friend, Frank.“
2. Po čem jdou: pokřik „THE BOOK AIN'T HERE!“ v úseku 2.
3. Kam dál: auto odjíždí na východ, závěrečná věta mapy.

## Úseky

### 1. U plachty (klid, 20 s, 1200 px)

- **Prostor:** ulička za Blue Note, páska, dva strážníci
- **Nepřátelé:** nikdo, O'Malley nestřílí
- **Zvuk:** klavír z panelu doznívá do deště
- **Text:** O'Malley: “Sorry about your friend, Frank. Doyle was all right, for a newspaperman.”
- **Checkpoint:** ne
- **Náročnost:** C: postava, která nestřílí (nebo jen hlas)

### 2. Popelnice (boj, 30 s, 1800 px)

- **Prostor:** ulice, popelnice a kontejner
- **Nepřátelé:** 2 s pistolí, zády k hráči
- **Zvuk:** bojové stopy
- **Text:** muž: “THE BOOK AIN'T HERE!”
- **Checkpoint:** ne
- **Náročnost:** A, nový pokřik

### 3. Dvorek (boj, 45 s, 2600 px)

- **Prostor:** dvorek činžáku
- **Nepřátelé:** 3 s pistolí
- **Zvuk:** bojové stopy
- **K nalezení:** stránka deníku 1 za okapem na nízké římse (chce skok)
- **Text:** stránka: Nov 3. Rosie showed me Tommy's photo again...
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A

### 4. První vzdání (klid, 25 s, 1500 px)

- **Prostor:** konec dvorku
- **Nepřátelé:** 1, zahodí zbraň
- **Zvuk:** stopy utichnou, zpomalená chvíle
- **K nalezení:** milost č. 1, svědectví 1:0
- **Text:** He put his hands up. I know the look of a man hoping nobody writes it down.
- **Checkpoint:** ne
- **Náročnost:** A, ve hře je

### 5. Ulice s neonem (boj, 60 s, 3500 px)

- **Prostor:** ulice, výklenky dveří, padající neon
- **Nepřátelé:** 4, z toho 1 s brokovnicí
- **Zvuk:** bojové stopy
- **K nalezení:** jméno č. 5: svatební fotka Stana Wojcika se svíčkou v okně v přízemí
- **Text:** Married in June. Buried in August. She kept the name.
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A, fotka v okně B (malá)

### 6. Domem nahoru (pohyb, 40 s, 2400 px)

- **Prostor:** dům v řezu, schody v zadní zdi, kop do dveří bytu
- **Nepřátelé:** 2 na chodbách
- **Zvuk:** bojové stopy potichu
- **Text:** bez textu
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A (hřiště, stanoviště 1)

### 7. Šňůra na prádlo (pohyb, 20 s, 1800 px)

- **Prostor:** z okna po šňůře přes uličku
- **Nepřátelé:** 2 dole, ve zpomalení
- **Zvuk:** zpomalení, stopy ztlumené
- **Text:** bez textu
- **Checkpoint:** ne
- **Náročnost:** A (hřiště, stanoviště 2)

### 8. Na střeše (ticho, 10 s, 900 px)

- **Prostor:** střecha, výhled na Hell's Kitchen
- **Nepřátelé:** nikdo
- **Zvuk:** jen vítr a déšť
- **Text:** dole jsou vidět světla auta, které odjíždí na východ
- **Checkpoint:** ne
- **Náročnost:** A (střechy z hřiště)

### 9. Dolů na ulici (vrchol, 60 s, 3000 px)

- **Prostor:** požární schodiště dolů, ulice
- **Nepřátelé:** 4, z toho 1 s brokovnicí
- **Zvuk:** bojové stopy naplno
- **Text:** bez textu
- **Checkpoint:** ano, na začátku úseku
- **Náročnost:** A

### 10. Auto je pryč (klid, 10 s, 800 px)

- **Prostor:** prázdná křižovatka
- **Nepřátelé:** nikdo
- **Zvuk:** stopy dozní, jazz z okna
- **Text:** The shooters ran east. So did I. You'd have taken a cab and expensed it.
- **Checkpoint:** ne
- **Náročnost:** A

## Rizika

- Úsek 1 potřebuje policajta, který stojí a mluví. Když je to drahé, stačí hlas mimo obraz.
- Úseky 6 až 8 jdou za sebou bez velkého boje (70 vteřin). Je to schválně jako nádech před vrcholem, ale musí se to ověřit na telefonu.

## Poznámky Claude Code

Sem připsat, co je těžké, hloupé nebo proti pravidlům map, a opravit odhady A, B, C.
