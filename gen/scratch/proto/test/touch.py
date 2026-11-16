import pathlib
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    for name, vp in [('wide', (844, 390)), ('p169', (736, 414))]:
        ctx = b.new_context(viewport={'width': vp[0], 'height': vp[1]}, has_touch=True, is_mobile=True, device_scale_factor=2)
        page = ctx.new_page(); errs = []
        page.on('pageerror', lambda e: errs.append(str(e)))
        page.goto((root / 'dist' / 'index.html').as_uri()); page.wait_for_timeout(200)
        w, h = vp
        ev = "([t,id,x,y])=>document.getElementById('game').dispatchEvent(new PointerEvent(t,{pointerId:id,pointerType:'touch',clientX:x,clientY:y,bubbles:true,cancelable:true,button:0}))"
        page.evaluate(ev, ['pointerdown', 9, w / 2, h / 2]); page.evaluate(ev, ['pointerup', 9, w / 2, h / 2])  # start
        page.wait_for_timeout(300)
        x0 = page.evaluate("()=>window.__game.state().player.x")
        lx, ly = 0.29 * h, h - 0.29 * h
        page.evaluate(ev, ['pointerdown', 1, lx + 60, ly])           # left stick pushed right, away from centre
        page.evaluate(ev, ['pointerdown', 2, w - 200, h - 150])      # right stick: touch, then drag up-right
        page.evaluate(ev, ['pointermove', 2, w - 150, h - 190])
        page.wait_for_timeout(500)
        st = page.evaluate("()=>{const s=window.__game.state();return {x:s.player.x, ax:s.player.ax, ay:s.player.ay, ammo:s.player.ammo}}")
        page.screenshot(path=str(root / 'shots' / f'touch_{name}.png'))
        print(name, 'moved', round(st['x'] - x0, 2), 'm; aim', round(st['ax'], 2), round(st['ay'], 2), 'ammo', st['ammo'], 'errors', errs)
        ctx.close()
    b.close()
