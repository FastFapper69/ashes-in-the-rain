import pathlib
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parent.parent
JS = """
() => {
  const g = window.__game; g.start(); const s = g.state();
  const idle = {mx:1,my:0,ax:1,ay:0,fire:true,jump:false,dive:false,bt:false};
  g.run(240, idle);
  const cv = document.getElementById('game'), ctx = cv.getContext('2d');
  const L = View.layout(cv.clientWidth, cv.clientHeight);
  const opts = {touch:true, sticks:Input.sticks(), interp:{a:1, prev:new WeakMap(), dt:1/60, fps:60}};
  const time = (n) => { const t0 = performance.now(); for (let i = 0; i < n; i++) View.draw(ctx, s, L, opts); ctx.getImageData(0,0,1,1); return (performance.now() - t0) / n; };
  const normal = time(120);
  s.bt = true; s.meter = 1; for (let i = 0; i < 30; i++) View.draw(ctx, s, L, opts);
  const slow = time(120);
  const t0 = performance.now(); g.run(600, idle); const sim = (performance.now() - t0) / 600;
  return {drawNormalMs: +normal.toFixed(2), drawBulletTimeMs: +slow.toFixed(2), simTickMs: +sim.toFixed(3), enemies: s.enemies.length};
}
"""
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    ctx = b.new_context(viewport={'width': 844, 'height': 390}, has_touch=True, is_mobile=True, device_scale_factor=3)
    page = ctx.new_page(); page.goto((root / 'dist' / 'index.html').as_uri()); page.wait_for_timeout(200)
    print(page.evaluate(JS))
    b.close()
