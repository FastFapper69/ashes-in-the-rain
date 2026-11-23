# Jak navrhujeme mapy

Postup a pravidla pro návrh map (23. 11. 2026, uživatel: „co navrhuješ, udělej“). Příběh: [[Srdce-a-hlas]]. Stav všech map: [[stav-map]]. Technická pravidla map: [[ch05-levels-maps]]. Deník rozhodnutí: [[pribeh-denik]].

## Postup

Mapa projde pěti kroky. Další krok začíná, až je předchozí odsouhlasený.

1. **Scénář úseků.** Co se děje a proč, co hráč dělá, co má cítit. Píše příběhový chat. Příklad: [[mapy-prolog-a-kapitola-I]].
2. **Blockout.** Úseky dostanou vteřiny, pixely, patra, nepřátele, checkpointy, zvuk a věci k nalezení. Data jsou v `pribeh/blockout/<mapa>.json`, karta a nákres se z nich generují skriptem `_blockout.py`. Příklad: [[blockout-prolog]], [[blockout-I-1-alley]].
3. **Posouzení.** Claude Code připíše do karty, co je těžké, hloupé nebo proti pravidlům, a opraví odhady náročnosti.
4. **Šedá verze.** Claude Code postaví mapu z hotových modulů bez nových kreseb. Uživatel si ji zahraje na telefonu.
5. **Kresby a dotažení.** Teprve co přežilo šedou verzi, dostane kresby z Gemini, zvuk a nakonec hlas.

Nejdřív se celé dotáhnou prolog a THE ALLEY. Podle nich se ukáže, jestli příběh funguje, a teprve potom se rozjede zbytek. Test na člověku, který hru nezná, přijde, až bude co testovat.

## Rozpočet času a křivka napětí

- Mapa má 5 až 8 minut čistého průchodu. Se smrtmi a hledáním z toho je 7 až 12.
- Úsek je jeden z pěti druhů: **ticho, klid, pohyb, boj, vrchol**.
- Nikdy tři boje za sebou bez klidu nebo pohybu mezi nimi.
- Každá mapa má jeden až dva vrcholy. Druhý je vždy blízko konce.
- Příběhové věty patří do klidu a ticha, nikdy doprostřed střelby.

## Klidná místa

- Klid nesmí být prázdný. Hráč v něm vždycky něco dělá: jde, dívá se, krmí holuby, poslouchá.
- Klid trvá nejvýš 30 vteřin, ticho nejvýš 10.
- V každé kapitole aspoň jedna mapa klidem začíná a jedna klidem končí.
- Vzorec „přijdu v klidu a zvrtne se to“ je vyhrazený pro tři místa: bistro se Sammym (I-2), Katakomby (III) a ples (IV).

## Holubi

Frank a Eddie chodili na střechu redakce na cigaretu. Eddie kouřil, Frank mu připálil a holubi dostali kůrky z Eddieho chleba. Krmení je proto ve hře chvíle, kdy Frank mluví s Eddiem nejvíc.

- **Jedno krmení na kapitolu**, vždy mimo boj. Páčka nahoru u holubů, asi 15 vteřin.
- U každého zazní jedna Eddieho věta, pokaždé jiná. Uloží se do deníku pod „Things Eddie said“.
- Krmení vrátí jeden zásah zdraví, aby ho hráč nepřebíhal.
- Povinné je jen první, na střeše Blue Note. Ostatní jsou mimo hlavní cestu.

| Kde | Frank | Co říkal Eddie |
|---|---|---|
| I-5, střecha Blue Note | We used to do this on the Ledger roof, Eddie. You smoked, I held the match, and the pigeons got your crusts. | You always fed the ugly one first. Said the pretty ones had agents. |
| II-1, trámy vyhořelého Mola 17 | Pigeons in the rafters of Pier 17. Something had moved back in after all. | You said pigeons were the only honest New Yorkers. They take what you give them and they don't pretend to like you. |
| III, světlík v depu | One had got in through the skylight and couldn't find the way out. I knew the feeling. | You said a bird that walks when it could fly has made its peace with the city. You meant me. The walking part. |
| U Rosie, požární schodiště | Rosie fed them off the fire escape every morning. “Eddie's,” she said. “He named them after editors.” | The fat one was called Hearst. Of course it was. |
| Konec Sníh, schody stanice | I still had seed in my coat from Mickey's roof. I left it on the station steps. Somebody ought to eat. | |
| Konec Popel, okno | The match flared and every pigeon on the sill went up at once. They know what a man with a match is. | |

## Postup hráče

Každá mapa přidá právě jednu novou věc (nepřítele, pohyb nebo nebezpečí) a dvě starší zopakuje. Blockout to má v oddíle „Postup hráče“.

| Kapitola | Frankova zbraň navíc | Noví nepřátelé | Nové pohyby a místa |
|---|---|---|---|
| Prolog | Eddie, vše vylepšené | střelci s pistolí | pohyb, krytí, skok šipkou, sud, zpomalení |
| I | jen revolver | brokovnice (I-1), samopal (I-2), boxer Mickey | milost, dům v řezu, šňůra, výklenky, bistro, střechy, kop do dveří, skluz po baru |
| II | brokovnice | muži s háky, dynamit, ostřelovači, břemena z jeřábů | jeřábová lana, lávky, paluba, mlha |
| III | samopal | policie se štítem a baterkou, policejní ostřelovači | tma, třetí kolejnice, střecha vlaku |
| IV | podle volby hráče | ochranka ve smokinzích, Rourkovi muži | civilisté, oheň za zády, šachta, vítr na špici |

Kolik bodů na vylepšení má hráč po které mapě mít, změří Claude Code botem. Pravidlo je jen jedno: po I-1 musí stačit na první kartu.

## Pro hráče, který přeskakuje panely

Každá mapa musí sama, bez panelů, říct tři věci: **po kom jdu, proč zrovna tady a co se na konci změnilo**. Slouží k tomu bubliny, pokřiky nepřátel, úvodní a závěrečná věta mapy a věta na titulní obrazovce. Blockout má tyhle tři věty vypsané.

Text, který už jednou zazněl, se po smrti a návratu na checkpoint neopakuje.

## Zvuk a ticho

| Co | Kdy |
|---|---|
| Jen déšť | klidné úseky venku |
| Jazz | klid ve městě, vždy s viditelným zdrojem (klub, okno, rádio) |
| Bojové stopy | boj a vrchol, řídí je hra sama |
| Klavír | vyprávění, vzpomínky, klid po boji. Nikdy během střelby |
| Ticho | tři ticha příběhu a chvíle před nevyhratelným bojem |
| Tommyho melodie | jednou za kapitolu: Rosie zkouší (I-5), broukání ve snu, čtyři takty u skříňky (II-1), Rosie ladí kytaru (U Rosie), celá píseň na plese (IV-3), poslední sloka v titulcích |

## Co se v mapách sbírá

| Co | Kolik | Kde |
|---|---|---|
| Stránka Eddieho deníku | 1 na mapu | mimo hlavní cestu, v klidném místě |
| Svědectví | 1 na mapu | od muže, kterého Frank nechal jít |
| Svědek | 1 na mapu v kapitolách I a II | honička, na konci volba |
| Jméno z Mola 17 | 11 za hru | předmět, který na to místo patří, viz [[jedenact-a-pisen]] |
| Krmení holubů | 1 na kapitolu | viz výše |

## Co neřešíme

- Čeština. Hra je anglicky (uživatel 23. 11.).
- Hlas. Nahrává se až na konci najednou, do té doby jen bubliny.
