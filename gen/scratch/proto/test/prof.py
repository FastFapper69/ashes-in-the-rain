import pathlib
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parent.parent
JS = """
() => {
  const g = window.__game; g.start(); const s = g.state();
  g.run(240, {mx:1,my:0,ax:1,ay:0,fire:true,jump:false,dive:false,bt:false});
  const cv = document.getElementById('game'), ctx = cv.getContext('2d');
  const L = View.layout(cv.clientWidth, cv.clientHeight), m = L.s;
  const T = (n, f) => { f(); const t0 = performance.now(); for (let i = 0; i < n; i++) f(); ctx.getImageData(0,0,1,1); return +((performance.now() - t0) / n).toFixed(2); };
  const out = {canvas: cv.width + 'x' + cv.height};
  out.backdrop = T(60, () => Art.backdrop(ctx, s, View.camX(), m, 0));
  out.foreground = T(60, () => Art.foreground(ctx, View.camX(), m));
  out.figure1 = T(200, () => { ctx.save(); ctx.scale(m, m); Art.figure(ctx, {x: 5, y: 8, f: 1, pose: 'run', phase: 0.3, vx: 5, vy: 0, aim: [1, 0], kind: 'player', t: 1}); ctx.restore(); });
  out.dead1 = T(200, () => { ctx.save(); ctx.scale(m, m); Art.figure(ctx, {x: 5, y: 8, f: 1, pose: 'dead', dir: [1, 0], aim: null, kind: 'grunt', t: 0}); ctx.restore(); });
  out.full = T(60, () => View.draw(ctx, s, L, {touch: true, sticks: Input.sticks(), interp: {a: 1, prev: new WeakMap(), dt: 1/60, fps: 60}}));
  return out;
}
"""
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    ctx = b.new_context(viewport={'width': 844, 'height': 390}, has_touch=True, is_mobile=True, device_scale_factor=3)
    page = ctx.new_page(); page.goto((root / 'dist' / 'index.html').as_uri()); page.wait_for_timeout(400)
    print(page.evaluate(JS))
    b.close()
