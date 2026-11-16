import pathlib
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parent.parent
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    ctx = b.new_context(viewport={'width': 844, 'height': 390}, has_touch=True, is_mobile=True, device_scale_factor=2)
    page = ctx.new_page(); errs = []; page.on('pageerror', lambda e: errs.append(str(e)))
    page.goto((root / 'dist' / 'index.html').as_uri()); page.wait_for_timeout(400)
    ev = "([t,id,x,y])=>document.getElementById('game').dispatchEvent(new PointerEvent(t,{pointerId:id,pointerType:'touch',clientX:x,clientY:y,bubbles:true,cancelable:true,button:0}))"
    before = page.evaluate("()=>Art.isMono()")
    page.evaluate(ev, ['pointerdown', 5, 422, 390 - 0.095 * 390]); page.evaluate(ev, ['pointerup', 5, 422, 390 - 0.095 * 390])
    page.wait_for_timeout(300)
    after = page.evaluate("()=>Art.isMono()"); tick0 = page.evaluate("()=>window.__game.state().tick")
    page.screenshot(path=str(root / 'shots' / 'toggle_colour_title.png'))
    page.evaluate(ev, ['pointerdown', 6, 422, 150]); page.evaluate(ev, ['pointerup', 6, 422, 150]); page.wait_for_timeout(500)
    tick1 = page.evaluate("()=>window.__game.state().tick")
    print('mono before', before, 'after tap on switch', after, '| game not started by that tap:', tick0 == 0, '| started by tap elsewhere:', tick1 > 0, '| errors', errs)
    b.close()
