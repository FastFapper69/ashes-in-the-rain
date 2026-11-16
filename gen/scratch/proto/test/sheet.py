import pathlib, sys
from playwright.sync_api import sync_playwright
root = pathlib.Path(__file__).resolve().parent.parent
src = lambda f: (root / 'src' / f).read_text(encoding='utf8')
html = f"""<!DOCTYPE html><html><body style="margin:0;background:#F2ECE1"><canvas id="c" width="1800" height="1150"></canvas><script>
{src('sim.js')}
{src('art.js')}
const ctx = document.getElementById('c').getContext('2d'); const m = 150;
ctx.fillStyle = '#F2ECE1'; ctx.fillRect(0,0,1800,1150);
ctx.fillStyle = '#0D0D0D'; ctx.fillRect(0, 2.6*m, 1800, 0.3*m); ctx.fillRect(0, 5.6*m, 1800, 0.3*m); ctx.fillRect(1500, 3.0*m, 300, 2.6*m);
ctx.save(); ctx.scale(m, m);
const row = (y, list) => list.forEach((o, i) => Art.figure(ctx, Object.assign({{x: 0.9 + i * 1.45, y, f: 1, t: 0.3, vx: 0, vy: 0, kind: 'player', aim: [1, 0]}}, o)));
row(2.6, [
  {{pose:'stand'}}, {{pose:'stand', aim:[0.6,-0.8]}}, {{pose:'run', phase:0, vx:7}}, {{pose:'run', phase:0.25, vx:7}}, {{pose:'run', phase:0.5, vx:7}}, {{pose:'run', phase:0.75, vx:7, aim:[-0.9,-0.44], f:-1}},
  {{pose:'air', vy:-5, vx:3}}, {{pose:'air', vy:6, vx:3, aim:[0.7,0.7]}},
]);
row(5.6, [
  {{pose:'stand', kind:'grunt', aim:null}}, {{pose:'stand', kind:'grunt', aim:[-1,0], f:-1}}, {{pose:'run', phase:0.25, kind:'grunt', vx:3.5, aim:[1,-0.1]}},
  {{pose:'stand', kind:'brok', aim:null}}, {{pose:'run', phase:0.5, kind:'brok', vx:5, aim:[1,0]}}, {{pose:'stand', kind:'brok', aim:[-1,0.1], f:-1}},
  {{pose:'stand', kind:'grunt', aim:[1,0], flash:true}},
]);
// flat poses: x,y = body centre
ctx.restore(); ctx.fillStyle = '#0D0D0D'; ctx.fillRect(0, 7.15*m, 1800, 0.2*m); ctx.save(); ctx.scale(m, m);
Art.figure(ctx, {{x:1.4, y:6.5, f:1, pose:'dive', dir:[1,-0.25], aim:[1,0.1], kind:'player', t:0.3, vx:11, vy:-3}});
Art.figure(ctx, {{x:3.9, y:6.5, f:-1, pose:'dive', dir:[-1,0.3], aim:[-1,-0.2], kind:'player', t:0.5, vx:-11, vy:3}});
Art.figure(ctx, {{x:6.3, y:6.8, f:1, pose:'prone', dir:[1,0], aim:[1,-0.15], kind:'player', t:0.3, vx:4, vy:0}});
Art.figure(ctx, {{x:8.4, y:6.4, f:1, pose:'dead', dir:[0.5,-0.86], aim:null, kind:'grunt', t:0.3}});
Art.figure(ctx, {{x:10.2, y:6.85, f:1, pose:'dead', dir:[1,0], aim:null, kind:'brok', t:0.3}});
Art.figure(ctx, {{x:10.9, y:4.2, f:1, pose:'dive', dir:[1,0], aim:[1,0], kind:'player', t:0.3, vx:11, vy:0}});
ctx.restore();
</script></body></html>"""
p_html = root / 'shots' / 'sheet.html'; p_html.write_text(html, encoding='utf8')
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
    page = b.new_page(viewport={'width': 1800, 'height': 1150}); errs = []
    page.on('pageerror', lambda e: errs.append(str(e)))
    page.goto(p_html.as_uri()); page.wait_for_timeout(200)
    page.screenshot(path=str(root / 'shots' / 'sheet.png'))
    print('errors', errs)
    b.close()
