import pathlib, base64
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parent.parent
(root / 'assets').mkdir(exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    page = b.new_page(); errs = []; page.on('pageerror', lambda e: errs.append(str(e)))
    page.goto((root / 'dist' / 'index.html').as_uri()); page.wait_for_timeout(800)
    out = page.evaluate("() => window.__game.exportSheets()")
    for k, v in out.items():
        f = root / 'assets' / (k + '.png'); f.write_bytes(base64.b64decode(v.split(',')[1])); print(k, f.stat().st_size)
    print('errors', errs); b.close()
