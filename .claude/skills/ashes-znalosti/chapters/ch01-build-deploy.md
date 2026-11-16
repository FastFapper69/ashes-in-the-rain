# Chapter 1: Build & deploy

## Core Idea
Sources live on `main`, the playable web build on `gh-pages`; one script builds packs, pushes both and keeps the previous build alive for cached phones. Two chats push here, so every deploy starts with a fetch.

## Where things live
- GitHub `FastFapper69/ink-and-lead` (public). `main` = sources, `gh-pages` = web build → https://fastfapper69.github.io/ink-and-lead/ . User plays on iPhone 17 (Safari/Chrome).
- PC folder `C:\Users\super\Documents\MobileGames\Ink and Lead`, Gemini images numbered in `art_src` (next free number: see HANDOFF – it grows every session).
- claude.ai docs: GDD `aac76a8f-a825-409f-a7d5-7834fe45049d` (tab Úkoly = task blocks 1–7), story `c223d676-08b8-42df-ae12-8f2cdf9b9dc3`, Gemini briefs `855fd524-d34d-495e-a18c-22e6eefa5dee`.

## Rebuild in a fresh container
1. Work copy `git clone https://github.com/FastFapper69/ink-and-lead /home/claude/repo` (edit only here). Main clone for pushing `/home/claude/ink-and-lead` (HANDOFF lives there). gh-pages clone `git clone -b gh-pages … /tmp/ghp`.
2. Godot 4.7.2 stable linux + export templates at `/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64`; first `godot --headless --import`.
3. `cp gen/deploy/deploy.sh gen/deploy/version_build.py /home/claude/` → `/home/claude/deploy.sh "msg"` prints `GHP-OK` / `MAIN-OK`. It runs `gen/packs.py` (rewrites export_presets.cfg + packs_list.gen.gd), exports `Web` + `pack_a/b/c` (`--export-pack`), copies repo → main clone and pushes, then `version_build.py` writes `ashes-<md5>.{pck,wasm,js}` + `ashes-<md5>-<group>.pck`, keeps the previous build, injects `gen/deploy/crash.js` into index.html.
4. Container cannot reach github.io / supabase.co: verify a deploy in the **built-in browser on the user's PC** (`preview_start https://fastfapper69.github.io/ink-and-lead/?v=<hash>`, then javascript `GODOT_CONFIG.executable`, `JSON.parse(localStorage.ashes_crumbs)`). Headless Chrome in the container (`/usr/bin/google-chrome` + playwright, `--use-angle=swiftshader --enable-unsafe-swiftshader`) is good for console checks (no `compressedTexImage2D` errors).
5. Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` + current `Claude-Session:` link.

## On the user's PC (Claude Code, from 2026-11-16)
- One clone `C:\Users\super\Documents\MobileGames\ink-and-lead` (main) + gh-pages clone `..\ink-and-lead-pages` (made by the script, depth 1). The old folder `Ink and Lead` stays only for `art_src` (Gemini images).
- Godot 4.7.2: `C:\Users\super\Downloads\Godot_v4.7.2-stable_win64_console.exe` (console build for logs), Web export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable`.
- Python: `py -3` (the bare `python` is the Microsoft Store stub). Pillow, numpy, scipy, opencv, pocketsphinx, playwright (+ chromium) installed. ffmpeg/ffprobe via winget. Run gen scripts with `PYTHONUTF8=1` (Windows default codepage breaks `open()`).
- Deploy: `gen/deploy/deploy_pc.sh "msg"` in Git Bash – same order as deploy.sh (fetch guard, packs, export, main push, version_build, gh-pages push, GHP-OK/MAIN-OK). Paths overridable with `G=`, `PY=`, `PAGES=`.
- Tests with the real GPU, no xvfb: `"$G" --path . --resolution 1560x720 --fixed-fps 30 -- --test=<mode>` (and 1280x720). Bot: `G=<godot.exe> bash gen/tests/bots.sh`.
- Git: repo-local identity `Claude <noreply@anthropic.com>`, `core.autocrlf input` (repo-local): Godot writes LF; with the Windows default (true) or false, git shows every .import as modified after an import (content identical – `git add` them to refresh the index). Pushing asks the user to log in to GitHub once (browser window); Claude never types passwords.

## Anti-patterns
- **Copying the repo tree over a newer origin** – wipes the other chat's work. Fetch, merge, then deploy.
- **Declaring a deploy done without seeing it live** – user expects Claude to verify Pages itself.
- **Godot export with `--main-pack` tests writing to res://** – read-only; `_shot` falls back to `user://_shots`.

## Key Takeaways
1. Fetch both clones before every commit; deploy.sh STOP line means pull first.
2. Old build stays on gh-pages on purpose – do not "clean it up".
3. Verify on the live URL in the PC browser, read crumbs from localStorage.
