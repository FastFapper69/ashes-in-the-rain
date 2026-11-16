// Deterministic simulation, v2: "2D Max Payne". Global bullet time, shootdodge, scrolling level.
// No DOM, no Math.sin/cos/random, fixed 60 Hz tick: same inputs give the same state everywhere.
const Sim = (() => {
  const VW = 21, H = 12, TICK = 1 / 60, EPS = 1e-6;
  const GRAV = 30, RUN = 7.5, JUMP_V = 12.49;
  const MAG = 18, HP = 5, SEG = 16;
  const BT_WORLD = 0.25, BT_MOVE = 0.5, BT_FIRE = 0.7, BT_PBULLET = 0.45;
  const ROT = [[1, 0], [0.996194698, 0.087155743], [0.984807753, 0.173648178]];

  function rnd(s) {
    s.rng = (Math.imul(s.rng, 1664525) + 1013904223) >>> 0;
    return s.rng / 4294967296;
  }

  function surfaceY(s, x) { // top of whatever a body standing at x would rest on
    let y = 11;
    for (let i = 0; i < s.solids.length; i++) {
      const b = s.solids[i];
      if (b.y > 0 && b.y < y && x > b.x - 0.3 && x < b.x + b.w + 0.3) y = b.y;
    }
    return y;
  }

  function addEnemy(s, x, y) {
    const brok = rnd(s) < 0.28;
    s.enemies.push({
      kind: brok ? 'brok' : 'grunt', x, y, vx: 0, vy: 0, w: brok ? 0.9 : 0.7, h: brok ? 1.7 : 1.8, hp: brok ? 2 : 1,
      onGround: false, onPlat: false, wall: 0, dropT: 0, face: -1, active: false,
      cd: 20 + rnd(s) * 50, tele: 0, burst: 0, burstT: 0, strafe: rnd(s) < 0.5 ? 1 : -1, strafeT: 30 + rnd(s) * 60,
      jumpCd: 0, flash: 0, dead: false,
    });
  }

  function genLevel(s) {
    const segs = 5 + (s.page < 4 ? s.page : 4);
    s.len = SEG * (segs + 2);
    s.exitX = s.len - 6;
    s.solids = [
      { x: 0, y: 11, w: s.len, h: 1 }, { x: 0, y: -1, w: s.len, h: 1 },
      { x: -1, y: -6, w: 1, h: 19 }, { x: s.len, y: -6, w: 1, h: 19 },
    ];
    s.plats = []; s.enemies = []; s.bullets = [];
    for (let i = 1; i <= segs; i++) {
      const x0 = SEG * i, type = Math.floor(rnd(s) * 4), spots = [];
      if (type === 0) {
        const c1 = x0 + 3 + Math.floor(rnd(s) * 3), c2 = x0 + 9 + Math.floor(rnd(s) * 4);
        s.solids.push({ x: c1, y: 9.8, w: 1.2, h: 1.2 }, { x: c2, y: 9.8, w: 1.2, h: 1.2 }, { x: c2 + 1.2, y: 9.8, w: 1.2, h: 1.2 }, { x: c2 + 0.6, y: 8.6, w: 1.2, h: 1.2 });
        spots.push(x0 + 6.5, x0 + 8, c2 + 1.2, x0 + 14.5);
      } else if (type === 1) {
        s.solids.push({ x: x0 + 5, y: 9, w: 6, h: 2 }, { x: x0 + 8.5, y: 7.8, w: 1.2, h: 1.2 });
        spots.push(x0 + 6, x0 + 10.3, x0 + 13, x0 + 15);
      } else if (type === 2) {
        s.plats.push({ x: x0 + 2.5, y: 8.5, w: 5 }, { x: x0 + 8.5, y: 6.1, w: 5.5 });
        s.solids.push({ x: x0 + 13.5, y: 9.8, w: 1.2, h: 1.2 });
        spots.push(x0 + 5, x0 + 10, x0 + 12, x0 + 15.3);
        addEnemy(s, x0 + 5, 8.5); addEnemy(s, x0 + 11, 6.1);
      } else {
        s.solids.push({ x: x0 + 2, y: 9, w: 3, h: 2 }, { x: x0 + 12, y: 9.8, w: 1.2, h: 1.2 });
        s.plats.push({ x: x0 + 6.5, y: 7.3, w: 5 });
        spots.push(x0 + 3.5, x0 + 7, x0 + 10.5, x0 + 14.5);
        addEnemy(s, x0 + 9, 7.3);
      }
      let n = 2 + Math.floor((s.page + 1) / 2) + Math.floor(rnd(s) * 2);
      if (n > spots.length + 2) n = spots.length + 2;
      for (let k = 0; k < n; k++) {
        const x = spots[k % spots.length] + (k >= spots.length ? 1.1 : 0);
        addEnemy(s, x, surfaceY(s, x));
      }
    }
    s.total = s.enemies.length;
  }

  function create(seed) {
    const s = {
      tick: 0, rng: (seed >>> 0) || 1, hitstop: 0, over: false, page: 1,
      kills: 0, btKills: 0, combo: 0, comboT: 0, best: 0,
      bt: false, btAuto: false, meter: 1, slowT: 0,
      len: 0, exitX: 0, total: 0, solids: [], plats: [], enemies: [], bullets: [], events: [],
      player: {
        x: 4, y: 11, vx: 0, vy: 0, w: 0.7, h: 1.8, onGround: true, onPlat: false, wall: 0, dropT: 0,
        ax: 1, ay: 0, hp: HP, inv: 0, ammo: MAG, fireCd: 0, reload: 0, idleT: 0, gun: 1,
        dive: false, prone: 0, diveCd: 0, diveBuf: 0, coy: 0, jumpBuf: 0, kickT: 0,
        pJump: false, pDive: false, pBt: false,
      },
    };
    genLevel(s);
    return s;
  }

  function pointInSolid(s, x, y) {
    for (let i = 0; i < s.solids.length; i++) {
      const b = s.solids[i];
      if (x > b.x && x < b.x + b.w && y > b.y && y < b.y + b.h) return true;
    }
    return false;
  }

  function los(s, x0, y0, x1, y1) {
    const dx = x1 - x0, dy = y1 - y0, n = Math.floor(Math.sqrt(dx * dx + dy * dy) / 0.4) + 1;
    for (let i = 1; i < n; i++) if (pointInSolid(s, x0 + dx * i / n, y0 + dy * i / n)) return false;
    return true;
  }

  function moveActor(s, a, dt) {
    const hw = a.w / 2;
    a.wall = 0;
    if (a.y - a.h < 0) a.y = a.h;
    let nx = a.x + a.vx * dt;
    for (let i = 0; i < s.solids.length; i++) {
      const b = s.solids[i];
      if (a.y > b.y + EPS && a.y - a.h < b.y + b.h - EPS && nx + hw > b.x && nx - hw < b.x + b.w) {
        if (a.x <= b.x + b.w / 2) { nx = b.x - hw; a.wall = 1; } else { nx = b.x + b.w + hw; a.wall = -1; }
      }
    }
    a.x = nx;
    let ny = a.y + a.vy * dt;
    a.onGround = false; a.onPlat = false;
    for (let i = 0; i < s.solids.length; i++) {
      const b = s.solids[i];
      if (a.x + hw > b.x + EPS && a.x - hw < b.x + b.w - EPS) {
        if (a.vy >= 0 && a.y <= b.y + EPS && ny >= b.y) { ny = b.y; a.vy = 0; a.onGround = true; }
        else if (a.vy < 0 && a.y - a.h >= b.y + b.h - EPS && ny - a.h <= b.y + b.h) { ny = b.y + b.h + a.h; a.vy = 0; }
      }
    }
    if (a.vy >= 0 && a.dropT <= 0) {
      for (let i = 0; i < s.plats.length; i++) {
        const p = s.plats[i];
        if (a.x + hw > p.x && a.x - hw < p.x + p.w && a.y <= p.y + EPS && ny >= p.y) { ny = p.y; a.vy = 0; a.onGround = true; a.onPlat = true; }
      }
    }
    a.y = ny;
    if (a.y - a.h < 0) { a.y = a.h; if (a.vy < 0) a.vy = 0; }
  }

  function norm(dx, dy) {
    const l = Math.sqrt(dx * dx + dy * dy);
    return l > EPS ? [dx / l, dy / l] : [1, 0];
  }

  function addBullet(s, x, y, dx, dy, speed, team, life) {
    s.bullets.push({ x, y, vx: dx * speed, vy: dy * speed, team, life, dead: false });
  }

  function stepPlayer(s, inp) {
    const p = s.player, slow = s.bt || s.slowT > 0;
    const mts = slow ? BT_MOVE : 1, fts = slow ? BT_FIRE : 1, dt = TICK * mts;
    if (p.inv > 0) p.inv--;
    if (p.dropT > 0) p.dropT--;
    if (p.fireCd > 0) p.fireCd -= fts;
    if (p.diveCd > 0) p.diveCd -= mts;

    if (inp.ax * inp.ax + inp.ay * inp.ay > 0.0225) { const n = norm(inp.ax, inp.ay); p.ax = n[0]; p.ay = n[1]; }

    // bullet time toggle and meter
    if (inp.bt && !p.pBt) {
      if (s.bt) { s.bt = false; s.btAuto = false; s.events.push({ t: 'btOff' }); }
      else if (s.meter > 0.05) { s.bt = true; s.btAuto = false; s.events.push({ t: 'btOn' }); }
    }
    p.pBt = inp.bt;
    if (s.bt) {
      s.meter -= s.btAuto ? 1 / 500 : 1 / 270; // slow motion that comes with a dive is cheap, the button is not
      if (s.meter <= 0) { s.meter = 0; s.bt = false; s.btAuto = false; s.events.push({ t: 'btOff' }); }
    } else if (s.meter < 1) { s.meter += 1 / 1100; if (s.meter > 1) s.meter = 1; }

    if (inp.jump && !p.pJump) p.jumpBuf = 7;
    p.pJump = inp.jump;
    if (p.jumpBuf > 0) p.jumpBuf--;
    p.coy = p.onGround ? 5 : (p.coy > 0 ? p.coy - 1 : 0);

    if (p.dive) { // shootdodge: committed arc, ends on landing
      p.vy += GRAV * 0.75 * dt;
      moveActor(s, p, dt);
      if (p.onGround) {
        p.dive = false; p.prone = 10; p.diveCd = 14;
        if (s.btAuto) { s.bt = false; s.btAuto = false; s.events.push({ t: 'btOff' }); }
        s.events.push({ t: 'land', x: p.x, y: p.y });
      }
    } else {
      if (p.prone > 0) {
        p.prone -= mts; p.vx *= 0.86;
        if (p.prone <= 0) { p.prone = 0; p.h = 1.8; }
      } else {
        if (p.kickT > 0) p.kickT--;
        else p.vx = (inp.mx > 0.2 || inp.mx < -0.2) ? inp.mx * RUN : 0;
        // separate dive button: a shootdodge along the move stick, or the way the character faces when the stick is at rest
        const ml = Math.sqrt(inp.mx * inp.mx + inp.my * inp.my);
        if (inp.dive && !p.pDive) p.diveBuf = 7;
        if (p.diveBuf > 0) p.diveBuf--;
        if (p.diveBuf > 0 && p.coy > 0 && p.diveCd <= 0) {
          const dx = ml > 0.3 ? inp.mx / ml : (p.ax >= 0 ? 1 : -1), dy = ml > 0.3 ? inp.my / ml : 0;
          p.vx = dx * 11.5; p.vy = dy * 9 - 6.5;
          if (p.vy < -13) p.vy = -13;
          p.dive = true; p.h = 1.0; p.kickT = 0; p.onGround = false; p.coy = 0; p.jumpBuf = 0; p.diveBuf = 0;
          if (dy > 0.6 && p.onPlat) p.dropT = 15;
          if (!s.bt && s.meter > 0.05) { s.bt = true; s.btAuto = true; s.events.push({ t: 'btOn' }); }
          s.events.push({ t: 'dive' });
        } else if (p.jumpBuf > 0 && p.coy > 0) { p.vy = -JUMP_V; p.jumpBuf = 0; p.coy = 0; s.events.push({ t: 'jump' }); }
        else if (p.jumpBuf > 0 && p.wall !== 0 && !p.onGround) { p.vy = -11; p.vx = -p.wall * 8; p.kickT = 10; p.jumpBuf = 0; s.events.push({ t: 'jump' }); }
        if (inp.my > 0.6 && p.onPlat && !p.dive) p.dropT = 15;
      }
      p.vy += (p.dive ? GRAV * 0.75 : GRAV) * dt;
      moveActor(s, p, dt);
    }
    p.pDive = inp.dive;

    if (p.reload > 0) {
      p.reload -= fts;
      if (p.reload <= 0) { p.reload = 0; p.ammo = MAG; s.events.push({ t: 'reloaded' }); }
    }
    if (inp.fire && p.fireCd <= 0 && p.reload <= 0 && p.ammo > 0) {
      const cy = p.y - p.h * 0.6, o = p.gun * 0.13; p.gun = -p.gun; // two pistols, alternating
      const mx = p.x + p.ax * 0.6 - p.ay * o, my = cy + p.ay * 0.6 + p.ax * o;
      addBullet(s, mx, my, p.ax, p.ay, 34, 0, 70);
      p.ammo--; p.fireCd = 8; p.idleT = 0;
      s.events.push({ t: 'shot', x: mx + p.ax * 0.25, y: my + p.ay * 0.25, dx: p.ax, dy: p.ay, team: 0 });
      if (p.ammo === 0) p.reload = 52;
    } else if (p.ammo < MAG && p.reload <= 0) {
      p.idleT++;
      if (p.idleT > 70) { p.reload = 40; p.idleT = 0; }
    }
  }

  function enemyFire(s, e, speed, spread) {
    const p = s.player, sy = e.y - e.h * 0.6;
    const d = norm(p.x - e.x, (p.y - p.h * 0.5) + (rnd(s) - 0.5) * spread - sy);
    addBullet(s, e.x + d[0] * 0.5, sy + d[1] * 0.5, d[0], d[1], speed, 1, 200);
    s.events.push({ t: 'shot', x: e.x + d[0] * 0.7, y: sy + d[1] * 0.7, dx: d[0], dy: d[1], team: 1 });
  }

  function stepEnemy(s, e, wts) {
    const p = s.player, dt = TICK * wts;
    const dx = p.x - e.x, adx = dx < 0 ? -dx : dx, dir = dx < 0 ? -1 : 1, dy = p.y - e.y;
    if (!e.active) {
      if (adx < 11 && dy > -7 && dy < 7) { e.active = true; s.events.push({ t: 'alert', x: e.x, y: e.y - e.h }); }
    }
    e.vx = 0;
    if (e.active) {
      if (e.dropT > 0) e.dropT--;
      if (e.cd > 0) e.cd -= wts;
      if (e.jumpCd > 0) e.jumpCd -= wts;
      e.face = dir;
      const sy = e.y - e.h * 0.6, see = los(s, e.x, sy, p.x, p.y - p.h * 0.5);
      if (e.kind === 'grunt') {
        if (e.burstT > 0) { e.burstT -= wts; if (e.burstT <= 0 && e.burst > 0) { e.burst--; enemyFire(s, e, 16, 1.3); if (e.burst > 0) e.burstT = 9; } }
        if (e.tele > 0) {
          e.tele -= wts;
          if (e.tele <= 0) { e.tele = 0; enemyFire(s, e, 16, 1.0); e.burst = 1; e.burstT = 9; e.cd = 70 + rnd(s) * 60; }
        } else {
          e.strafeT -= wts;
          if (e.strafeT <= 0) { e.strafe = -e.strafe; e.strafeT = 40 + rnd(s) * 70; }
          if (adx > 10 || !see) e.vx = dir * 3.6; else if (adx < 4) e.vx = -dir * 3.2; else e.vx = e.strafe * 2;
          if (e.onGround && e.jumpCd <= 0 && e.wall !== 0) { e.vy = -JUMP_V; e.jumpCd = 40; }
          if (e.cd <= 0 && see && adx < 13) e.tele = 14;
        }
      } else {
        if (e.tele > 0) {
          e.tele -= wts;
          if (e.tele <= 0) {
            e.tele = 0;
            const d = norm(p.x - e.x, (p.y - p.h * 0.5) - sy);
            for (let k = -2; k <= 2; k++) {
              const r = ROT[k < 0 ? -k : k], sn = k < 0 ? -r[1] : r[1];
              addBullet(s, e.x + d[0] * 0.5, sy + d[1] * 0.5, d[0] * r[0] - d[1] * sn, d[0] * sn + d[1] * r[0], 13, 1, 30);
            }
            s.events.push({ t: 'blast', x: e.x + d[0] * 0.7, y: sy + d[1] * 0.7, dx: d[0], dy: d[1] });
            e.cd = 90;
          }
        } else {
          if (adx > 2.6) e.vx = dir * 5.5;
          if (e.onGround && e.jumpCd <= 0 && (e.wall !== 0 || (dy < -1.2 && adx < 6))) { e.vy = -JUMP_V; e.jumpCd = 45; }
          if (dy > 1 && e.onPlat && adx < 4) e.dropT = 15;
          if (e.cd <= 0 && see && adx < 4.6 && dy > -2.5 && dy < 2.5) e.tele = 18;
        }
      }
    }
    e.vy += GRAV * dt;
    moveActor(s, e, dt);
  }

  function hitBox(a, x, y, r) {
    return x > a.x - a.w / 2 - r && x < a.x + a.w / 2 + r && y > a.y - a.h - r && y < a.y + r;
  }

  function stepBullets(s, wts) {
    const p = s.player, bs = s.bullets, slow = s.bt || s.slowT > 0;
    for (let i = 0; i < bs.length; i++) {
      const b = bs[i];
      if (b.dead) continue;
      const ts = b.team === 0 ? (slow ? BT_PBULLET : 1) : wts;
      b.life -= ts;
      if (b.life <= 0) { b.dead = true; continue; }
      const mx = b.vx * TICK * ts, my = b.vy * TICK * ts;
      let n = Math.floor(Math.sqrt(mx * mx + my * my) / 0.25) + 1;
      const sx = mx / n, sy = my / n;
      for (; n > 0 && !b.dead; n--) {
        b.x += sx; b.y += sy;
        if (pointInSolid(s, b.x, b.y)) { b.dead = true; s.events.push({ t: 'spark', x: b.x, y: b.y }); break; }
        if (b.team === 0) {
          for (let j = 0; j < s.enemies.length; j++) {
            const e = s.enemies[j];
            if (e.dead || !hitBox(e, b.x, b.y, 0.12)) continue;
            b.dead = true; e.hp--; e.flash = 6; e.active = true;
            if (e.hp <= 0) {
              e.dead = true; s.kills++; if (slow) s.btKills++;
              s.combo++; s.comboT = 150; if (s.combo > s.best) s.best = s.combo;
              s.meter += 0.2; if (s.meter > 1) s.meter = 1;
              s.hitstop = slow ? 0 : 2;
              let left = false;
              for (let k = 0; k < s.enemies.length; k++) if (!s.enemies[k].dead && s.enemies[k].active) left = true;
              if (!left) s.slowT = 40; // the last one of a group goes down in slow motion
              s.events.push({ t: 'kill', kind: e.kind, x: e.x, y: e.y, w: e.w, h: e.h, dx: b.vx > 0 ? 1 : -1, dy: b.vy, slow, combo: s.combo, last: !left });
            } else s.events.push({ t: 'hit', x: b.x, y: b.y });
            break;
          }
        } else if (p.inv <= 0 && hitBox(p, b.x, b.y, 0.1)) {
          b.dead = true; p.hp--; p.inv = 24; s.hitstop = 4; s.combo = 0;
          s.events.push({ t: 'hurt', x: p.x, y: p.y - p.h / 2 });
          if (p.hp <= 0) { s.over = true; s.events.push({ t: 'over' }); }
        }
      }
    }
    for (let i = 0; i < bs.length; i++) {
      const a = bs[i];
      if (a.dead || a.team !== 0) continue;
      for (let j = 0; j < bs.length; j++) {
        const b = bs[j];
        if (b.dead || b.team === 0) continue;
        const dx = a.x - b.x, dy = a.y - b.y;
        if (dx * dx + dy * dy < 0.1) { a.dead = true; b.dead = true; s.events.push({ t: 'clink', x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 }); break; }
      }
    }
    s.bullets = bs.filter(b => !b.dead);
  }

  function step(s, inp) {
    s.events = [];
    if (s.over) return;
    if (s.hitstop > 0) { s.hitstop--; return; }
    s.tick++;
    if (s.slowT > 0) s.slowT--;
    if (s.comboT > 0 && --s.comboT === 0) s.combo = 0;
    stepPlayer(s, inp);
    const wts = (s.bt || s.slowT > 0) ? BT_WORLD : 1;
    const p = s.player;
    for (let i = 0; i < s.enemies.length; i++) {
      const e = s.enemies[i];
      if (e.flash > 0) e.flash--;
      if (e.active || (e.x > p.x - 26 && e.x < p.x + 26)) stepEnemy(s, e, wts);
    }
    stepBullets(s, wts);
    s.enemies = s.enemies.filter(e => !e.dead);
    if (p.x >= s.exitX) {
      s.page++;
      p.x = 4; p.y = 11; p.vx = 0; p.vy = 0; p.dive = false; p.prone = 0; p.h = 1.8;
      p.hp += 2; if (p.hp > HP) p.hp = HP;
      p.ammo = MAG; p.reload = 0;
      s.bt = false; s.btAuto = false; s.slowT = 0;
      genLevel(s);
      s.events.push({ t: 'page' });
    }
  }

  return { VW, W: VW, H, TICK, MAG, HP, create, step };
})();
if (typeof module !== 'undefined') module.exports = Sim;
