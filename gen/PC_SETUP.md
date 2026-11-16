# Přechod na Claude Code na PC (16. 11. 2026)

Proč: rendrované testy v cloudu běží ~1 snímek/s (test se screenshoty 15 min), Gemini/Artlist stahování blokovaly
dialogy „Uložit jako“. Na PC s grafikou je to v reálném čase a soubory jdou rovnou do projektu.

## Co udělá Jakub (asi 15 minut)
1. **Git for Windows**: https://git-scm.com/downloads/win (výchozí volby). Claude Code pak má Bash, deploy.sh běží v Git Bash.
2. **Claude Code**: PowerShell (ne jako správce) → `irm https://claude.ai/install.ps1 | iex` → zavřít a otevřít PowerShell → `claude --version`.
   (Návod: https://code.claude.com/docs/en/setup)
3. **Repo** (bez mezer v cestě, ne do OneDrive):
   ```
   cd C:\Users\super\Documents\MobileGames
   git clone https://github.com/FastFapper69/ink-and-lead.git ink-and-lead
   cd ink-and-lead
   claude
   ```
   Při prvním spuštění přihlášení k účtu Claude. Push na GitHub: Git for Windows se při prvním `git push` zeptá na přihlášení
   k GitHubu (okno prohlížeče) – přihlas se ty, Claude hesla nezadává.
4. První zpráva v Claude Code: **„Přečti gen/PC_SETUP.md a připrav prostředí.“**

## Co pak udělá Claude na PC (sám, v tomhle pořadí)
1. Přečíst CLAUDE.md → skill ashes-znalosti → HANDOFF (13), (14).
2. Ověřit nástroje a doinstalovat, co chybí (winget / pip, s potvrzením):
   - Godot 4.7.2 + **export templates pro Web** (Editor → Manage Export Templates) – na PC je Godot stažený, cesta zjistit.
   - Python 3 + `pip install pillow numpy pocketsphinx` (gen/*.py), ffmpeg (zvuk 22050 Hz mono).
3. Deploy na PC: `gen/deploy/deploy.sh` má cesty z cloudu (/home/claude/repo, /home/claude/ink-and-lead, /tmp/ghp).
   Na PC je repo jediné: udělat `gen/deploy/deploy_pc.sh` (export do build/, gh-pages v samostatném klonu
   `..\ink-and-lead-pages` na větvi gh-pages, `version_build.py`, guard na commity druhého chatu zůstává).
4. Testy s grafikou bez xvfb: `godot --path . --resolution 1560x720 -- --test=<mode>` (a 1280x720); bot `gen/tests/bots.sh` (cesta ke Godotu přes proměnnou G).
5. Složka s Gemini obrázky: `C:\Users\super\Documents\MobileGames\Ink and Lead\art_src` – ponechat, číslování pokračuje (gun parts 201–208 rezervované, řez domem 211–221).

## Pak práce (pořadí dohodnuté s Jakubem)
1. **Podívat se na řez domem** `--sandbox=0` na 1280 i 1560 (zatím s dočasným artem) a opravit, co je špatně.
2. **Fasáda se rozpouští od dveří** (shader, 0,6 s), pak **kopnutí do dveří** (1,2 s zpomalení), **skok oknem** ven na požární
   schodiště, **nepřátelé po schodech** mezi patry. Kaskadérské kousky a předměty prostředí místo sudů (schváleno 16. 11.):
   přidávat po kapitolách s mapami, 3–4 na kapitolu, seznam a obtížnost v story docu, tab „Řez domem a kamera“, sekce
   „Kaskadérské kousky a prostředí“. Každý: kresba ve 2 stavech, balíček kapitoly, screenshoty 1280/1560, bot, telefon.
3. **Gemini**: stavebnice činžáku (gen/QUEUE_doma.md §5, kusy 211–221) + kresby pro kousky výše (okno celé/rozbité, poklop,
   zábradlí, šňůra) – Gemini jen na PC, Artlist jen zvuk.
4. **Fronta z cloudu** (gen/QUEUE_doma.md §1, §2, §4): stáhnout 9 dialogů z Artlistu, ošoupaná brokovnice a tommy, nadabovat
   hlášky shotup/noquit/quit.
5. Pak mapy kapitol I–III podle tras (story doc „ASHES IN THE RAIN – Dramaturgie a kapitola IV“) a kapitola IV.
