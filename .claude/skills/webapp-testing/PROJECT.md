# webapp-testing in this repo

Vendored from https://github.com/anthropics/skills @e4bb5d9 (Apache 2.0, LICENSE.txt). SKILL.md unchanged.

## Recipe: check the exported web build before pushing gh-pages
The container cannot reach github.io, so test the local export (`build/`) instead; the live URL is still checked in the PC's built-in browser (ashes-znalosti ch01).

```bash
python3 .claude/skills/webapp-testing/scripts/with_server.py \
  --server "python3 -m http.server 8060 -d build" --port 8060 -- python3 /tmp/web_check.py
```
`/tmp/web_check.py` (write per need, keep it short):
- Chromium headless with `--use-angle=swiftshader --enable-unsafe-swiftshader`, viewport 852×393 landscape, `device_scale_factor=2`, `is_mobile=True`, `has_touch=True` (iPhone-like).
- `page.on("console")` + `page.on("pageerror")` → fail on `compressedTexImage2D`, `SCRIPT ERROR`, WebGL context lost.
- Tap once (audio unlock), wait until `JSON.parse(localStorage.ashes_crumbs)` contains a `ready` crumb, screenshot to `_shots/web_*.png`, print the last crumbs (heap, textures, fps).
- Look at the screenshot yourself (hard rule 1).
