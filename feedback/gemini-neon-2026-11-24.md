# Feedback kolečko: Gemini Neon, 24. 11. 2026

Start: [[MAPA]]. Zadání: uživatel 24. 11. („feedback kolečko s Gemini Neon: grafika, mechaniky, animace, efekty, příběh, game dokument“).
Co dostal: 2 listy snímků z 10 map (bot hraje, 1560x720), pásek 12 snímků animace (0,12 s), stručný herní dokument v angličtině
(prolog Eddie, kapitoly, mechaniky, ovládání, příběh Srdce a hlas, pravidla map, známé slabiny). Neon napoprvé odmítl („nerozumím“), po
upřesnění, že jde o vlastní stylizovanou hru, odpověděl.

Každý bod: **co Neon říká** → *poznámka Claude Code* (sedí / nesedí / co s tím). Nic z toho není rozhodnuto, rozhoduje uživatel.

## 1. Grafika
- **Postavy jako samolepky**: pozadí má moc středních tónů a jemného šrafování, proto má každá postava silný bílý obrys; ve světlých
  scénách (Santa Lucia) vypadají jako nalepené. Návrh: pozadí o 30–40 % tmavší a jednodušší, místo obrysu dokola světlo z jedné strany.
  → *Sedí částečně. Obrys je naše pravidlo čitelnosti; zkusit tenčí/jednostranný obrys + ztmavení pozadí jen jako pokus v laborce.*
- **HUD nepřátelský k telefonu**: páčka velká a neprůhledná, titulky, náboje a „DISARMED +150“ drobné. Návrh: páčka plovoucí /
  menší a průhlednější, titulky 1,5× větší, max. 2 řádky, body jen ve světě, horní pruh pryč.
  → *Velikost písma titulků a bodů ověřit na telefonu; páčka je stejně velká jako tlačítka a uživatel si nestěžoval. Kandidát.*
- **Ploché modulární město**: fronty v jedné rovině, „kulisa z kartonu“; teplé světlo a oheň jsou měkké digitální přechody.
  Návrh: tmavé popředí (hydranty, lampy, dráty), střešní díly přes spáry (římsy, komíny, vodojemy).
  → *Sedí s výtkou uživatele ke spárám u střech. Vodojem/komín přes spáru je jednodušší než pilíř (PARTY_ON).*

## 2. Mechaniky
- **Moc ovládání na dva palce**: páčka (pohyb, krytí, žebřík, výklenek) + tap-střelba + 3 tlačítka. Návrh: sloučit skok a skok
  rybičkou/skluz do jednoho tlačítka (ťuk = skok, podržet/tah = rybička), nebo zpomalení automaticky při rybičce (Max Payne).
  → *Auto-zpomalení při rybičce stojí za pokus v laborce.*
- **Moc systémů** (gunsmith, výklenky, krytí, rybička, skluz, odzbrojení, morálka, sudy, pára, hydranty, neony, šňůry, deník, nástěnka).
  Návrh: škrtnout ~30 %, hlavně gunsmith a výklenky.
  → *Nesouhlas u výklenků (rozhodnutí uživatele „C“). Gunsmith je na uživateli.*
- **Auto-míření vs. ťuk**: hráč bude jen spoléhat na auto-míření. Návrh: viditelné znamení před vzdáním (couvá, třese se) a velký
  zásah na zbraň při zpomalení.
  → *Sedí: větší zásahová plocha zbraně ve zpomalení je levná.*

## 3. Animace
- **Tuhý trup, nohy jako nůžky**: při běhu se trup nenaklání, chybí pohup. Návrh: náklon 10–15° v běhu, pohup v rytmu kroků.
- **Žádný zpětný ráz**: při výstřelu se tělo skoro nehne. Návrh: trup 8–10° dozadu na 0,1 s.
- **Vidět loutku**: kabát a klobouk bez setrvačnosti. Návrh: spodek kabátu 2–3 díly se zpožděním, rychlé klíčové pózy, 30–50 ms
  zastavení při zásahu do hlavy / odzbrojení.
  → *Všechno je kód v puppet.gd, žádné nové kresby. Nejlepší poměr cena/výkon z celé zpětné vazby. Ověřit, co už tam je.*

## 4. Efekty
- **Oheň a kouř digitální** (Sen, dým od hlavně): měkké částice. Návrh: ostré, ručně kreslené 3–4 snímkové plameny a kouř s rastrem.
  → *Sedí; kresby od Gemini (pravidlo: kresby jen z Gemini).*
- **Nápisy přes sebe**: CLINK!, OKAY, OKAY! a krev na hlavě nepřítele naráz. Návrh: zvuková slova odlétají ven po dráze zbraně,
  výkřiky vždy čistě nad hlavou.
  → *Sedí, vidět i na našich snímcích.*
- **Slabý déšť a zpomalení bez jazyka**: Návrh: silnější šikmý déšť, cákance na kloboucích; ve zpomalení déšť skoro stojí,
  tmavá vinětace, tlumený zvuk/tep.
  → *Ověřit, co zpomalení dnes dělá s deštěm; vinětace a tep jsou levné.*

## 5. Příběh a vyprávění
- **Text v boji**: dobré věty ve žlutém rámečku dole během přestřelky nikdo nepřečte. Návrh: pravidlo „žádné vyprávění v boji“,
  jen v klidných úsecích.
  → *Sedí s pravidly map příběhového chatu (klidné úseky). Do pravidel map.*
- **Dva systémy titulků**: žlutý rámeček dole vs. věty nad hlavou v šedém prologu; ty nad hlavou působí lépe, ale bez podkladu.
  Návrh: jeden styl, nad hlavou s jemným tmavým podkladem; žlutý rámeček jen pro přechody.
  → *K rozhodnutí uživatele.*
- **Zvrat v půlce**: musí být nachystaný v kap. I–II, jinak působí jako melodrama. Návrh: Frank uhne pohledem od výstřižku o Molu 17,
  zapálí cigaretu gangsterovi, bez vysvětlení.
  → *Pro příběhový chat.*

## 6. Dokument a postup
- **Leštění před zamčením základů**: 10+ map s kresbami, ale HUD, váha loutky a hodnoty ještě nejsou hotové. Návrh: zastavit nové mapy,
  jedna 3minutová mapa na 100 % (vertical slice), test s cizími lidmi na telefonu.
- **Chybí specifikace pro mobil**: zóny palců, velikosti cílů, min. písmo, pauza/návrat. Návrh: jedna stránka pravidel (max 3 tlačítka
  vpravo, min. písmo, max 1 nový trik na kapitolu).
- **Rozsah vs. tým**: 5 kapitol s unikátními scénami. Návrh: odložit gunsmith a složité interiéry, raději 90 minut, ale silných.

## TOP 10 podle Neonu
1. Oddělit postavy od pozadí hodnotami, pryč s bílým obrysem dokola.
2. Přestavět HUD: menší páčka, titulky 1,5×, pryč horní pruh bodů.
3. Zjednodušit tlačítka vpravo (sloučit skok + rybičku nebo zpomalení při rybičce).
4. Váha loutky: náklon v běhu, zpětný ráz, kabát se zpožděním.
5. Zastavit nové mapy, jedna mapa na 100 %.
6. Žádné vyprávění v boji.
7. Oheň, kouř, záblesky jako tušové kresby.
8. Rozházet nápisy z hlavy nepřítele.
9. Škrtnout nadbytečné systémy (gunsmith).
10. Popředí a střešní díly přes spáry modulů.
