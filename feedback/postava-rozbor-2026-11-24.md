# Rozbor postavy a pohybu (Claude Code, 24. 11. 2026)

Start: [[MAPA]]. Související: [[gemini-neon-2026-11-24]]. Zadání uživatele: „na té tváři je něco divného… při běhu s nataženou pistolí
groteskní pohyb… nastuduj si anatomii, herní postavy, udělej si rozbor a feedback ty sám“.

Podklady: nový test `--test=gait` (`--chapter=0` Eddie, `1` Frank): 8 fází běhu s mířením, 8 fází chůze se spuštěnou zbraní, 2 stoje;
délky kostí z `puppet.gd` (`_len`); stopa nohy `_foot()`; snímek uživatele z telefonu. Srovnání: tabulka délek částí těla
(Drillis–Contini / Winter), klíčové pózy běhu (kontakt, dolů, průchod, nahoru/let – AnimSchool, Animator's Survival Kit).

## A. Stavba těla (měřeno, výška postavy ~1,78 m)

| Část | U nás | Člověk (podíl výšky) | Rozdíl |
|---|---|---|---|
| Stehno | 0,37 m | 0,245 H = 0,44 m | **o 7 cm kratší** |
| Bérec (+ kotník 0,09) | 0,49 m + 0,09 | 0,246 H = 0,44 m (+0,07 kotník) | **o 5–7 cm delší** |
| Nadloktí | 0,30 m | 0,186 H = 0,33 m | o 3 cm kratší |
| Předloktí (po dlaň) | 0,34 m | 0,146 H = 0,26 m (+ část dlaně) | o 3–5 cm delší |

- **Koleno sedí moc vysoko** (uživatel to odhadl správně): v 61 % výšky nohy místo ~53 %. Při zvednutí nohy pak dlouhý bérec visí
  jako chůda a krátké stehno jde až do vodorovna. Stejně je vysoko loket.
- Hlava s kloboukem ≈ 1/7 výšky: v pořádku (realisticky 7,5, hrdinsky 8). Hlava velká není.

## B. Hlava a tvář (hlavně Eddie)

1. **Límec za hlavou.** Díl „zvednutý límec“ (`_collars`) trčí za týlem jako světlý svislý pruh od ramene po krempu. U Franka
   (světlý kabát) čte jako límec; u Eddieho je kabát skoro černý a pruh světlý, takže vypadá jako obvaz, dlouhé ucho nebo druhá tvář.
   To je podle mě ta „divná věc na tváři“.
2. **Hlava bez krku.** Brada leží pod linkou límce, krk není vidět vůbec. U shrbeného Franka to funguje, u mladého štíhlého Eddieho
   to čte jako hlava zaražená do trupu.
3. **Tři různé pohledy v jedné postavě.** Hlava z profilu, trup ze tří čtvrtin zepředu (oba klopy, knoflíky, přezka), nohy z profilu.
   Ve stoji to projde; v chůzi se trup nikdy nenatočí a hlava „jede“ na trupu, který se dívá jinam.
4. **Hodnoty.** Eddieho tvář je nejsvětlejší plocha a tělo skoro černé: tvář působí jako maska. Předloktí má světlejší a jinak
   šrafovaný rukáv než nadloktí a kabát (vidět se spuštěnou rukou i na fotce uživatele): vypadá jako návlek.
5. **Kapky deště na klobouku a ramenou** jsou na tmavém Eddiem bílé tečky = „lupy“. U Franka nevadí.
6. **Obrys** je jen kolem celé siluety. Ruka přes trup obrys nemá, takže se spuštěná ruka do kabátu ztrácí.

## C. Běh (proč působí groteskně)

1. **Je to chůze přehraná rychle, ne běh.** `_foot()` drží vždy jednu nohu na zemi (půl cyklu stojná, půl švihová). Běh má
   **letovou fázi** (obě nohy ve vzduchu) a tělo je nejníž při došlapu, nejvýš v letu. U nás tělo jen lehce kmitá.
2. **Vysoká kolena, žádné zakopnutí.** Švihová noha jde souměrným obloukem pod tělem (zdvih 0,26 m) → stehno do vodorovna, bérec
   svisle dolů: pochod „vysoká kolena“. V běhu se pata po odrazu **složí dozadu k hýždi**, koleno jde dopředu jen do ~45–60° a noha
   došlapuje pod tělo s pokrčeným kolenem.
3. **Rozkrok jako nůžky.** V kontaktu (fáze 1 a 5) jsou obě nohy natažené a obě chodidla plochá na zemi. Chybí odraz ze špičky a
   došlap na patu/střed chodidla.
4. **Trup stojí rovně.** Náklon 7° (na hřišti 14°) je málo vidět, protože dlouhý kabát zakrývá pánev. Trup se nekroutí proti nohám.
5. **Ruka se zbraní je tyč.** Natažená vodorovně celý cyklus, nepohne se s krokem. Druhá ruka přitom švihá naplno: horní půlka těla
   „stojí“, dolní pochoduje. To je jádro grotesky.
6. **Nikdo neběhá s nataženou zbraní.** Hry (Max Payne, Uncharted) při běhu drží zbraň v pokrčené ruce u těla a natahují ji jen na
   výstřel. My míříme stále.

## D. Chůze se spuštěnou zbraní (nová)
- Funguje, ale: krok je stejná stopa jako běh jen menší; ruce švihají málo; ramena se nehoupou; hlava se nehne.
- Předloktí jiné barvy (bod B4) je tu nejvíc vidět.

## E. Co bych s tím dělal, v pořadí podle poměru cena / výkon

Jen kód (`puppet.gd`), žádné kresby:
1. **Běh se zbraní u těla.** Když neběží výstřel a cíl není blízko: loket ~90°, zbraň před hrudí, ruka pumpuje s krokem. Na
   výstřel se natáhne (stejně jako teď při spuštěné zbrani).
2. **Opravdový běh:** letová fáze, pata dozadu k hýždi, koleno níž, došlap pod tělo s pokrčeným kolenem, tělo dolů při došlapu a
   nahoru v letu, ruka se zbraní se pohupuje s krokem.
3. **Posunout koleno a loket** na správné místo. Pozor: díly jsou nakreslené na dnešní délky, posun kloubu znamená překrytí nebo
   natažení kreseb; nejdřív zkusit v kódu o 4–5 cm a podívat se.
4. **Límec za hlavou u Eddieho** ztmavit na tón kabátu nebo zkrátit; kapky na tmavém kabátu ztlumit.
5. **Hlavu o kousek výš a dopředu** (kotva `on_torso.head`), aby byl vidět kousek krku.

Nové kresby z Gemini (až po kódu):
6. Eddieho předloktí ve stejném tónu a šrafuře jako kabát.
7. Trup z čistšího profilu (nebo druhý trup pro běh), aby seděl k hlavě a nohám.

## Opraveno 24. 11.
- B1 (světlý pruh za Eddieho hlavou): byla to chyba, ne kresba. Eddie nosí Frankovo tělo obarvené do tmavomodra, ale dva díly límce (`_collars`) se neobarvily a zůstaly světlé. Teď mají barvu kabátu.
