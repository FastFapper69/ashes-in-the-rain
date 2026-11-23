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

Posouzeno 23. 11. 2026 proti hře, jak je teď (bot: dnešní THE ALLEY 27 tis. px a 13 mužů za 60 s).

### Čas
- 19,5 tis. px a 18 mužů: člověk to projde zhruba za **3 až 4 minuty**, ne za 5:20. Dům a šňůra čas natahují, ulice ne. Stejná oprava jako u prologu: chůze v klidu, delší klidné úseky, nebo přijmout kratší mapu.

### Logika, kde to nejde postavit tak, jak je to napsané
- **Úseky 7 a 8: po šňůře se nedá dojet na střechu.** Šňůra vede dolů (z okna 2. patra k oknu 1. patra protějšího domu). Střecha je o dvě patra výš. Jak to jde: šňůra → oknem do domu naproti (tichá hala nebo chodba) → žebřík na střechu → střecha → požární schodiště dolů. Přesně tohle je postavené na hřišti (stanoviště 2 a 5).
- **Úsek 9:** dolů po požárním schodišti se nestřílí. Muži střílí jen na Franka na svém patře (pravidlo z 15. 11.), takže vrchol začne, až Frank stoupne na chodník. To je v pořádku, jen s tím počítat.
- **Úsek 3:** stránka deníku je uprostřed boje, pravidla map říkají „v klidném místě mimo hlavní cestu“. Buď přesunout do úseku 4, nebo pravidlo upravit.
- **Úsek 2:** muži zády k hráči: dnes si hráče všimnou podle vzdálenosti. „Nevšimne si, dokud nevystřelím“ je C malé.
- **Úsek 4:** vzdání dnes závisí na morálce (kolik jich padlo). Jisté první vzdání na daném místě je C malé.

### Náročnost, opravy odhadů
| Úsek | Blockout | Opravdu |
|---|---|---|
| 1 O'Malley, který stojí a mluví | C | C střední (postava bez boje) + plachta a páska B. Šedá verze: hlas mimo obraz |
| 3 stránka na římse | A | B + C malé: stránky dnes leží jen na zemi, římsa je nová plošina |
| 5 výklenky dveří, padající neon | A | A (výklenky jsou z hřiště, neon ve hře je) |
| 5 svatební fotka v okně | B malá | B + **C střední**: „jméno z Mola 17“ je nový druh věci k nalezení a nová stránka v deníku (11 za hru) |
| 6 dům | A | A |
| 7 šňůra | A | A, konec šňůry viz logika |
| 8 střecha, světla auta dole | A | střechy A; auto, které odjíždí, C malé |
| 9 schodiště dolů | A | A |
| Uzly generátoru | návrh | **C střední**: modulární město je dnes jeden pevný blok hřiště. Musím ho rozdělit na díly (dům, ulička se šňůrou, hala, střechy, schodiště), aby se z nich skládaly mapy. Dvorek (yard) v modulárním městě není: B + C |

### Co ještě nesedí ve výtvarnu (uživatel 23. 11.)
- Napojení dvou domů u střech, trolej a kanál, které nesedí na zem a zeď. Rozpracovaný je pilíř mezi domy (není nasazený). Dokud to není vyřešené, šedá verze je správný krok: kresby až potom.

### Rozhodnutí uživatele 23. 11.
- Délka: zhruba jednou tolik obsahu než v kartě, ne třikrát.
- Šňůra a střecha: „vymysli něco, co dává smysl“. Návrh Claude Code pro úseky 6 až 9:
  1. **6 Domem nahoru** do bytu ve 2. patře, kop do dveří.
  2. **7 Šňůra**: z okna bytu na požární schodiště a po šňůře přes uličku; dva muži dole ve zpomalení. Šňůra končí u okna 1. patra domu naproti a Frank jím proletí.
  3. **7b Půda naproti** (ticho, nový krátký úsek): prázdný sklad nebo sušárna, nikdo tam není, jen rozbité sklo a žebřík k poklopu. Nádech.
  4. **8 Na střeše**: poklopem ven, výhled, dole světla auta, které odjíždí na východ.
  5. **9 Dolů**: po požárním schodišti na průčelí (páčka dolů u žebříku), vrchol začne na chodníku.
- Výtvarno (napojení domů u střech, trolej, kanál) počká, dokud neprojdou šedé verze.

