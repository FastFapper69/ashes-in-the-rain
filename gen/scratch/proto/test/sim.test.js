const Sim = require('../src/sim.js');
const crypto = require('crypto');

function lcg(seed) { let s = seed >>> 0; return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296); }

function run(seed, ticks, smart) {
  const s = Sim.create(seed), r = lcg(seed ^ 0x9e3779b9);
  let inp = { mx: 0, my: 0, ax: 1, ay: 0, fire: false, jump: false, dive: false, bt: false };
  let maxBullets = 0, maxPage = 1, btTicks = 0;
  for (let t = 0; t < ticks; t++) {
    if (t % 6 === 0) {
      const q = v => Math.round(v * 127) / 127;
      inp = { mx: q(r() * 2 - 1), my: q(r() * 2 - 1), ax: q(r() * 2 - 1), ay: q(r() * 2 - 1), fire: r() < 0.7, jump: r() < 0.15, dive: r() < 0.1, bt: r() < 0.03 };
      if (smart) { // walk right, shoot the nearest awake enemy, dive when bullets are close
        const p = s.player; let b = null;
        for (const e of s.enemies) if (e.active && (!b || Math.abs(e.x - p.x) < Math.abs(b.x - p.x))) b = e;
        inp.mx = b ? q((r() - 0.3)) : 1; inp.my = 0;
        if (b) { inp.ax = q(Math.max(-1, Math.min(1, (b.x - p.x) / 6))); inp.ay = q(Math.max(-1, Math.min(1, ((b.y - b.h / 2) - (p.y - 1)) / 6))); inp.fire = true; }
        else { inp.fire = false; inp.jump = r() < 0.4; }
        inp.dive = s.bullets.some(k => k.team === 1 && Math.abs(k.x - p.x) < 5) && r() < 0.5;
        if (p.wall !== 0) { inp.jump = true; inp.mx = 0; }
      }
    }
    Sim.step(s, inp);
    const p = s.player;
    for (const v of [p.x, p.y, p.vx, p.vy, s.meter]) if (!Number.isFinite(v)) throw new Error('NaN at tick ' + t);
    if (p.x < 0 || p.x > s.len || p.y < 0 || p.y > 11.001) throw new Error(`player out of level at tick ${t}: ${p.x},${p.y}`);
    for (const e of s.enemies) if (e.x < 0 || e.x > s.len || e.y < 0 || e.y > 11.001) throw new Error(`enemy out at ${t}: ${e.x},${e.y}`);
    if (s.meter < 0 || s.meter > 1) throw new Error('meter out of range');
    maxBullets = Math.max(maxBullets, s.bullets.length); maxPage = Math.max(maxPage, s.page); if (s.bt) btTicks++;
    if (s.over) break;
  }
  const hash = crypto.createHash('sha1').update(JSON.stringify(s)).digest('hex');
  return { hash, tick: s.tick, page: s.page, kills: s.kills, btKills: s.btKills, best: s.best, hp: s.player.hp, over: s.over, maxBullets, btTicks, total: s.total };
}

let fails = 0;
for (const seed of [1, 7, 42, 1234, 99999]) {
  for (const smart of [false, true]) {
    const a = run(seed, 60 * 240, smart), b = run(seed, 60 * 240, smart);
    const ok = a.hash === b.hash;
    if (!ok) fails++;
    console.log(`seed ${seed} smart=${smart} ${ok ? 'DETERMINISTIC' : 'MISMATCH'} tick=${a.tick} page=${a.page} kills=${a.kills} btKills=${a.btKills} combo=${a.best} hp=${a.hp} over=${a.over} maxB=${a.maxBullets} btTicks=${a.btTicks} lvlEnemies=${a.total}`);
  }
}
// bullet time must slow enemy bullets to a quarter
{
  const mk = () => { const s = Sim.create(3); s.enemies = []; s.bullets.push({ x: 30, y: 3, vx: 16, vy: 0, team: 1, life: 999, dead: false }); return s; };
  const idle = { mx: 0, my: 0, ax: 0, ay: 0, fire: false, jump: false, dive: false, bt: false };
  const a = mk(), b = mk();
  Sim.step(b, { ...idle, bt: true });
  for (let i = 0; i < 12; i++) { Sim.step(a, idle); Sim.step(b, idle); }
  const fast = a.bullets[0].x - 30, slow = b.bullets[0].x - 30 - 16 / 60 * 0.25;
  const ok = Math.abs(fast / 12 * 0.25 - slow / 12) < 1e-9 && b.bt;
  if (!ok) fails++;
  console.log(`bullet time test: normal ${fast.toFixed(3)} m, slowed ${slow.toFixed(3)} m in 12 ticks ${ok ? 'OK' : 'FAIL'}`);
}
process.exit(fails ? 1 : 0);
