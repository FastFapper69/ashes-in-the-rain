import pathlib
from playwright.sync_api import sync_playwright

root = pathlib.Path(__file__).resolve().parent.parent
url = (root / 'dist' / 'index.html').as_uri()
out = root / 'shots'
out.mkdir(exist_ok=True)

# a scripted player: walk right, aim at the nearest awake enemy, dive when the first bullets come
SCRIPT = """
(stopAt) => {
  const g = window.__game; g.start();
  const s = g.state(); let dived = false, n = 0;
  const bot = () => {
    const p = s.player; let b = null;
    for (const e of s.enemies) if (e.active && (!b || Math.abs(e.x - p.x) < Math.abs(b.x - p.x))) b = e;
    const i = {mx: b ? 0.3 : 1, my: 0, ax: 1, ay: 0, fire: !!b, jump: false, dive: false, bt: false};
    if (b) { const dx = b.x - p.x, dy = (b.y - b.h / 2) - (p.y - 1), l = Math.hypot(dx, dy) || 1; i.ax = Math.round(dx / l * 127) / 127; i.ay = Math.round(dy / l * 127) / 127; }
    if (p.wall !== 0) { i.jump = (n % 24) < 12; i.mx = 0; }
    if (b && !dived && Math.abs(b.x - p.x) < 9 && p.onGround) { i.dive = true; i.mx = 1; i.my = -0.4; dived = true; }
    return i;
  };
  while (n < 3000) {
    g.run(1, bot()); n++;
    if (stopAt === 'hint' && s.enemies.some(e => e.active)) { g.run(8, bot()); break; }
    if (stopAt === 'dive' && s.player.dive && s.bt && s.bullets.length > 1) { g.run(10, bot()); break; }
    if (stopAt === 'kills' && s.kills >= 4 && !s.bt) break;
    if (stopAt === 'lamp' && !s.bt && s.slowT === 0 && s.player.onGround && Art.lit(s, s.player.x, s.player.y) && s.player.x > 14) break;
  }
  return {n, kills: s.kills, bt: s.bt, hp: s.player.hp, x: s.player.x, bullets: s.bullets.length};
}
"""

with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    errors = []
    for name, vp, touch in [('phone_wide', (844, 390), True), ('phone_169', (736, 414), True), ('phone_portrait', (390, 844), True), ('desktop', (1280, 720), False)]:
        ctx = b.new_context(viewport={'width': vp[0], 'height': vp[1]}, has_touch=touch, is_mobile=touch, device_scale_factor=2)
        page = ctx.new_page()
        page.on('pageerror', lambda e, n=name: errors.append(f'{n}: {e}'))
        page.on('console', lambda m, n=name: errors.append(f'{n} console: {m.text}') if m.type == 'error' else None)
        page.goto(url)
        page.wait_for_timeout(1500)
        page.screenshot(path=str(out / f'{name}_title.png'))
        for stop in (['hint', 'dive', 'kills', 'lamp'] if name != 'phone_portrait' else ['dive']):
            info = page.evaluate(SCRIPT, stop)
            page.wait_for_timeout(60)
            page.screenshot(path=str(out / f'{name}_{stop}.png'))
            print(name, stop, info)
        if name == 'phone_wide':
            page.evaluate("() => { const s = window.__game.state(); s.player.hp = 1; s.player.inv = 0; s.bt = false; s.bullets.push({x:s.player.x-1,y:s.player.y-1,vx:22,vy:0,team:1,life:50,dead:false}); }")
            page.wait_for_timeout(1300)
            page.screenshot(path=str(out / f'{name}_over.png'))
        ctx.close()
    b.close()
    print('ERRORS:', errors if errors else 'none')
