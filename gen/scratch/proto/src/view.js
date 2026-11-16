// Rendering only. Reads simulation state, never changes it.
const View = (() => {
  const PAPER = '#EAE6DF', INK = '#08080A', RED = '#D92525', GOLD = '#E5A91A', AMBER = '#F2A922', NIGHT = '#08080A', ZOOM = 1.15, CRIM = '#8A1C14', BIG = 1.15; // figures are drawn 15 % over life size, like a comic
  const FONT = "Bangers,'Avenir Next Condensed',Impact,'Roboto Condensed','sans-serif-condensed',sans-serif";
  const fx = { texts: [], sparks: [], bodies: [], splats: [], casings: [], flashes: [], flash: 0, shake: 0, banner: 0, btFade: 0, rain: 0, clock: 0, stars: [], lastClink: -99, lastWord: -99, lastFoe: -99, prevShot: -99, streak: 0 };
  const cam = { x: 0, y: 0, snap: true };

  function layout(vw, vh) {
    const s = Math.min(vw / Sim.VW, vh / Sim.H);
    const ox = (vw - Sim.VW * s) / 2, oy = (vh - Sim.H * s) / 2;
    const u = vh, R = Math.max(26, 0.098 * u), ring = Math.max(5, R * 0.16), bx = R + ring + 6;
    // the camera sits close: about 8.3 m of street top to bottom instead of 12, so figures are large on a phone
    const z = Math.max(Math.min(vh / (Sim.H / ZOOM), vw / 16), vh / Sim.H); // a figure is a bit over a quarter of the screen tall
    const d = 0.15 * u + R + ring + 0.06 * u, cx = vw - d - R - ring - 8, cy = vh - 0.24 * u;
    const arc = deg => ({ x: cx + d * Math.cos(deg * 0.0174533), y: cy + d * Math.sin(deg * 0.0174533) });
    return {
      z, vw, vh, s, ox, oy, R, ring, stickR: 0.15 * u,
      // right hand: aim stick at the bottom, SKOK right beside it, PLAVMO and ČAS side by side above
      // right thumb: aim stick low in the corner, buttons on an arc around it within reach
      jump: arc(-6), bt: arc(-62), dive: arc(-118),
      // fixed sticks: always in the same place under each thumb
      styleBtn: { x: vw / 2 - 0.62 * u, y: vh - 0.15 * u, w: 1.24 * u, h: 0.11 * u },
      hintL: { x: 0.29 * u, y: vh - 0.29 * u },
      hintR: { x: cx, y: cy },
    };
  }

  let seed = 12345;
  function vr() { seed = (Math.imul(seed, 1103515245) + 12345) >>> 0; return seed / 4294967296; }
  function burst(x, y, n, c, sp) {
    for (let i = 0; i < n; i++) fx.sparks.push({ x, y, vx: (vr() - 0.5) * (sp || 9), vy: (vr() - 0.7) * (sp || 9), t: 14 + vr() * 10, c });
    if (fx.sparks.length > 90) fx.sparks.splice(0, fx.sparks.length - 90);
  }

  function onEvents(events) {
    for (const e of events) {
      if (e.t === 'kill') {
        const word = e.combo >= 6 ? 'KRA-KOOM!' : (e.combo >= 3 ? 'BLAM!' : 'BAM!');
        fx.texts.push({ x: e.x, y: e.y - e.h - 0.6, s: word, c: e.slow ? RED : INK, t: 30, max: 30, big: e.combo >= 6, seed: 1 + ((vr() * 97) | 0) });
        fx.bodies.push({ x: e.x, y: e.y - e.h / 2, vx: e.dx * (5 + vr() * 4), vy: -5 - vr() * 3, rot: -1.5708, vrot: e.dx * (4 + vr() * 5), kind: e.kind, dx: e.dx, t: 420, rest: false, id: (vr() * 1000) | 0 });
        if (fx.bodies.length > 10) fx.bodies.shift();
        for (let i = 0; i < 9; i++) { const big = i < 2; fx.splats.push({ x: e.x + e.dx * (0.2 + vr() * 1.5), y: e.y - e.h * (0.25 + vr() * 0.8), r: big ? 0.11 + vr() * 0.08 : 0.025 + vr() * 0.06, d: big && vr() < 0.6 ? 0.25 + vr() * 0.5 : 0 }); }
        if (fx.splats.length > 110) fx.splats.splice(0, fx.splats.length - 110);
        burst(e.x, e.y - e.h / 2, 12, '#7E1717', 12); fx.shake = e.last ? 10 : 6;
      } else if (e.t === 'hit') burst(e.x, e.y, 5, PAPER);
      else if (e.t === 'hurt') { fx.flash = 16; fx.shake = 12; burst(e.x, e.y, 10, RED); }
      else if (e.t === 'spark') { burst(e.x, e.y, 3, PAPER, 6); if (fx.clock - fx.lastClink > 26) { fx.lastClink = fx.clock; fx.stars.push({ x: e.x, y: e.y, t: 7 }); fx.texts.push({ x: e.x, y: e.y - 0.7, s: 'CINK!', c: INK, t: 18, max: 18, small: true, seed: 5 }); } } // lead on brick and iron
      else if (e.t === 'clink') { fx.texts.push({ x: e.x, y: e.y - 0.3, s: 'CINK!', c: INK, t: 18, max: 18, seed: 5 }); burst(e.x, e.y, 6, PAPER); }
      else if (e.t === 'shot' || e.t === 'blast') {
        fx.flashes.push({ x: e.x, y: e.y, dx: e.dx, dy: e.dy, t: 3, big: e.t === 'blast', team: e.t === 'blast' ? 1 : e.team });
        const word = (str, c, x, y) => fx.texts.push({ x, y, s: str, c, t: 22, max: 22, small: true, seed: 1 + ((vr() * 97) | 0) });
        if (e.t === 'blast') { if (fx.clock - fx.lastFoe > 20) { fx.lastFoe = fx.clock; word('KRA-KOOM!', GOLD, e.x + e.dx * 0.8, e.y - 1.0); } }
        else if (e.team === 0) {
          fx.streak = fx.clock - fx.prevShot < 14 ? fx.streak + 1 : 0; fx.prevShot = fx.clock;
          if (fx.clock - fx.lastWord > 24) { fx.lastWord = fx.clock; word(fx.streak >= 3 ? 'RAT-TAT-TAT!' : 'BLAM!', RED, e.x + e.dx * 1.0, e.y - 1.0 - vr() * 0.3); }
        } else if (fx.clock - fx.lastFoe > 36) { fx.lastFoe = fx.clock; word('BANG!', GOLD, e.x + e.dx * 0.8, e.y - 0.9); }
        if (e.team === 0) {
          fx.casings.push({ x: e.x - e.dx * 0.4, y: e.y - e.dy * 0.4, vx: -e.dx * 2.5 + (vr() - 0.5) * 2, vy: -5.5 - vr() * 2, t: 40, a: vr() * 6, va: 0.5 + vr() * 0.4 });
          if (fx.casings.length > 14) fx.casings.shift();
        }
      } else if (e.t === 'page') { fx.banner = 110; cam.snap = true; fx.bodies = []; fx.splats = []; }
      else if (e.t === 'alert') fx.texts.push({ x: e.x, y: e.y - 0.5, s: '!', c: GOLD, t: 26, max: 26 });
      else if (e.t === 'land') burst(e.x, e.y, 4, PAPER, 5);
    }
  }

  function tickFx(k) { // k = world time scale, so debris also hangs in the air during bullet time
    for (const t of fx.texts) t.t -= 1;
    fx.texts = fx.texts.filter(t => t.t > 0);
    if (fx.texts.length > 7) fx.texts.splice(0, fx.texts.length - 7);
    for (const p of fx.sparks) { p.t -= k; p.x += p.vx / 60 * k; p.y += p.vy / 60 * k; p.vy += 0.5 * k; }
    fx.sparks = fx.sparks.filter(p => p.t > 0);
    for (const c of fx.casings) { c.t -= k; c.x += c.vx / 60 * k; c.y += c.vy / 60 * k; c.vy += 0.5 * k; c.a += c.va * k; }
    fx.casings = fx.casings.filter(c => c.t > 0);
    for (const b of fx.bodies) {
      b.t -= 1;
      if (!b.rest) {
        b.x += b.vx / 60 * k; b.y += b.vy / 60 * k; b.vy += 0.5 * k; b.rot += b.vrot / 60 * k;
        if (b.y > 10.74) { b.y = 10.74; b.rest = true; b.rot = b.vx >= 0 ? 0 : 3.1416; }
      }
    }
    fx.bodies = fx.bodies.filter(b => b.t > 0);
    for (const f of fx.flashes) f.t--;
    fx.flashes = fx.flashes.filter(f => f.t > 0);
    if (fx.flash > 0) fx.flash--;
    if (fx.shake > 0) fx.shake--;
    if (fx.banner > 0) fx.banner--;
    fx.rain += k / 60; fx.clock++;
    for (const q of fx.stars) q.t -= 1; fx.stars = fx.stars.filter(q => q.t > 0);
  }

  function text(ctx, str, x, y, size, color, align, stroke) {
    ctx.font = `400 ${size}px ${FONT}`;
    ctx.textAlign = align || 'left'; ctx.textBaseline = 'middle';
    if (stroke) { ctx.lineJoin = 'round'; ctx.lineWidth = Math.max(2, size * 0.22); ctx.strokeStyle = stroke; ctx.strokeText(str, x, y); }
    ctx.fillStyle = color; ctx.fillText(str, x, y);
  }
  function fit(ctx, str, size, maxW) {
    ctx.font = `400 ${size}px ${FONT}`;
    const w = ctx.measureText(str).width;
    return w > maxW ? size * maxW / w : size;
  }

  function drop(ctx, x, y, r, filled) {
    ctx.beginPath();
    ctx.moveTo(x, y - r * 1.5);
    ctx.bezierCurveTo(x + r * 1.3, y - r * 0.1, x + r, y + r, x, y + r);
    ctx.bezierCurveTo(x - r, y + r, x - r * 1.3, y - r * 0.1, x, y - r * 1.5);
    ctx.closePath();
    ctx.lineWidth = Math.max(1.5, r * 0.26); ctx.strokeStyle = filled ? INK : PAPER;
    ctx.fillStyle = filled ? RED : INK; ctx.fill(); ctx.stroke();
  }

  function body(ctx, a, m, band, bandY) {
    const x = (a.x - a.w / 2) * m, y = (a.y - a.h) * m, w = a.w * m, h = a.h * m;
    ctx.lineJoin = 'miter';
    ctx.lineWidth = Math.max(2, 0.09 * m); ctx.strokeStyle = PAPER; ctx.strokeRect(x, y, w, h);
    ctx.fillStyle = INK; ctx.fillRect(x, y, w, h);
    ctx.fillStyle = band; ctx.fillRect(x, y + bandY * m, w, 0.22 * m);
  }

  function gun(ctx, x, y, dx, dy, len, m) {
    ctx.lineCap = 'butt';
    ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(4, 0.26 * m);
    ctx.beginPath(); ctx.moveTo(x * m, y * m); ctx.lineTo((x + dx * (len + 0.04)) * m, (y + dy * (len + 0.04)) * m); ctx.stroke();
    ctx.strokeStyle = INK; ctx.lineWidth = Math.max(2, 0.15 * m);
    ctx.beginPath(); ctx.moveTo(x * m, y * m); ctx.lineTo((x + dx * len) * m, (y + dy * len) * m); ctx.stroke();
  }

  // Halftone sheet for bullet time, drawn once into an offscreen canvas and then blitted each frame.
  // Filling the screen with a pattern every frame cost four times a normal frame.
  let sheet = null, sheetKey = '', sheetPeriod = 1;
  function dotSheet(ctx, m) {
    const dpr = ctx.getTransform().a || 1, key = m + ':' + dpr;
    if (sheet && sheetKey === key) return sheet;
    const sp = Math.max(6, Math.round(0.4 * m)), per = sp * 2;
    const w = Math.ceil(Sim.VW * m) + per, h = Math.ceil(Sim.H * m);
    sheet = document.createElement('canvas'); sheet.width = Math.ceil(w * dpr); sheet.height = Math.ceil(h * dpr);
    const g = sheet.getContext('2d'); g.scale(dpr, dpr);
    g.fillStyle = PAPER; g.fillRect(0, 0, w, h); // opaque sheet: paper plus dots already mixed to 30 % red, so the blit needs no blending
    g.fillStyle = '#EAB1A9';
    g.beginPath();
    for (let y = sp / 2, row = 0; y < h + sp; y += sp, row++) for (let x = (row & 1 ? sp * 1.5 : sp / 2); x < w + sp; x += per) { g.moveTo(x + sp * 0.17, y); g.arc(x, y, sp * 0.17, 0, 6.2832); }
    g.fill();
    sheet.cssW = w; sheet.cssH = h; sheetKey = key; sheetPeriod = per;
    return sheet;
  }

  // a character is a body frame from its sheet plus an arm sprite turned to the aim. No sheet yet: the placeholder draws it.
  const blank = new Map();
  function white(img) { let c = blank.get(img); if (!c) { c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const g = c.getContext('2d'); g.drawImage(img, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = PAPER; g.fillRect(0, 0, c.width, c.height); blank.set(img, c); } return c; }
  function actor(ctx, o) {
    const sheet = Assets.get(o.kind === 'player' ? 'player_sheet' : 'enemy_sheet'), arms = Assets.get('arms_sheet');
    if (!sheet || (!SPR.BAKED_ARMS && !arms)) { Art.figure(ctx, o); return; }
    const S = SPR, F = S.F, FW = F / S.PPM, f = o.f >= 0 ? 1 : -1, t = o.t || 0, flat = o.pose === 'dive' || o.pose === 'prone' || o.pose === 'dead';
    let col = 0, row = 0;
    if (o.kind === 'player') {
      if (o.pose === 'run') { row = 1; col = Math.floor(o.phase * 8) % 8; }
      else if (o.pose === 'air') { row = 2; col = (o.vy < 0 ? 0 : 2) + (Math.floor(t * 6) & 1); }
      else if (o.pose === 'dive') { row = 3; col = Math.max(0, Math.min(5, Math.floor(((o.vy || 0) + 9) / 3))); }
      else if (o.pose === 'prone') { row = 3; col = 6 + (Math.floor(t * 4) & 1); }
      else col = Math.floor(t * 5) % 4;
    } else {
      const base = o.kind === 'grunt' ? 0 : 3;
      if (o.pose === 'run') { row = base + 1; col = Math.floor(o.phase * 8) % 8; }
      else if (o.pose === 'air') { row = base + 2; col = Math.floor(t * 6) & 1; }
      else if (o.pose === 'dead') { row = base + 2; col = (o.rest ? 4 : 2) + ((o.id || 0) & 1); }
      else { row = base; col = Math.floor(t * 5) % 4; }
    }
    const img = o.flash ? white(sheet) : sheet;
    ctx.save(); ctx.translate(o.x, o.y);
    if (!flat || o.pose === 'dive') ctx.scale(BIG, BIG);
    if (flat) { ctx.rotate(Math.atan2(o.dir[1], o.dir[0])); if (o.dir[0] < 0) ctx.scale(1, -1); ctx.drawImage(img, col * F, row * F, F, F, -FW / 2, -FW / 2, FW, FW); }
    else { ctx.scale(f, 1); ctx.drawImage(img, col * F, row * F, F, F, -S.FEET_X / S.PPM, -S.FEET_Y / S.PPM, FW, FW); }
    ctx.restore();
    if (o.pose === 'dead' || SPR.BAKED_ARMS) return;
    const ax = o.aim ? o.aim[0] : f * 0.45, ay = o.aim ? o.aim[1] : 0.89;
    let sx, sy;
    if (flat) { const l = Math.sqrt(o.dir[0] * o.dir[0] + o.dir[1] * o.dir[1]) || 1; sx = o.x + o.dir[0] / l * 0.21; sy = o.y + o.dir[1] / l * 0.21; }
    else { sx = o.x + f * (o.pose === 'run' ? 0.13 : 0.04); sy = o.y - 1.37; }
    ctx.save(); ctx.translate(sx, sy); ctx.rotate(Math.atan2(ay, ax)); if (ax < 0) ctx.scale(1, -1);
    ctx.drawImage(o.flash ? white(arms) : arms, (o.kind === 'player' ? 0 : (o.kind === 'grunt' ? 1 : 2)) * S.ARM_W, 0, S.ARM_W, S.ARM_H, -S.ARM_PX / S.PPM, -S.ARM_PY / S.PPM, S.ARM_W / S.PPM, S.ARM_H / S.PPM);
    ctx.restore();
  }
  // halftone dots and paper grain, made once at screen size and laid over the frame while time is slow
  let grain = null, grainKey = '';
  function grainSheet(L) {
    const k = L.vw + 'x' + L.vh; if (grain && grainKey === k) return grain;
    grain = document.createElement('canvas'); grain.width = Math.ceil(L.vw); grain.height = Math.ceil(L.vh); grainKey = k;
    const g = grain.getContext('2d'), sp = Math.max(5, Math.round(L.vh * 0.016));
    g.fillStyle = 'rgba(8,8,10,0.2)'; g.beginPath();
    for (let y = 0, r = 0; y < L.vh + sp; y += sp, r++) for (let x = (r & 1) * sp / 2; x < L.vw + sp; x += sp) { g.moveTo(x + sp * 0.2, y); g.arc(x, y, sp * 0.2, 0, 6.2832); }
    g.fill();
    for (let i = 0; i < 2600; i++) { g.fillStyle = vr() < 0.5 ? 'rgba(234,230,223,0.22)' : 'rgba(8,8,10,0.3)'; const z = 1 + vr() * 1.6; g.fillRect(vr() * L.vw, vr() * L.vh, z, z); }
    return grain;
  }

  function drawWorld(ctx, st, L, touch, it) {
    // the simulation ticks at 60 Hz; drawing blends each body between its last two ticks so motion stays smooth
    // on 90 and 120 Hz screens and while the camera scrolls
    const lerp = o => { const q = it && it.prev.get(o); if (!q) return o; const c = Object.create(o); c.x = q.x + (o.x - q.x) * it.a; c.y = q.y + (o.y - q.y) * it.a; return c; };
    const m = L.z, p = lerp(st.player), slow = st.bt || st.slowT > 0, FXI = Assets.get('fx_sheet');
    const spr = (k, x, y, w) => { const r = FXR[k]; ctx.drawImage(FXI, r[0], r[1], r[2], r[3], x - w / 2, y - w * r[3] / r[2] / 2, w, w * r[3] / r[2]); };
    const enemies = st.enemies.map(lerp), bullets = st.bullets.map(lerp);
    const visW = L.vw / m, visH = Math.min(Sim.H, L.vh / m);
    const target = Math.max(0, Math.min(st.len - visW, p.x + p.ax * 2.6 - visW / 2));
    const targetY = Math.max(0, Math.min(Sim.H - visH, p.y - 1 - visH * 0.6));
    const dtf = it ? it.dt : 1 / 60;
    if (cam.snap) { cam.x = target; cam.y = targetY; cam.snap = false; } else { cam.x += (target - cam.x) * (1 - Math.exp(-dtf * 7)); cam.y += (targetY - cam.y) * (1 - Math.exp(-dtf * 5)); }
    fx.btFade += ((slow ? 1 : 0) - fx.btFade) * (1 - Math.exp(-dtf * 14));
    const x0 = cam.x - 1, x1 = cam.x + visW + 1;

    ctx.save();
    const sh = fx.shake > 0 ? fx.shake * 0.012 * m : 0;
    ctx.beginPath(); ctx.rect(0, 0, L.vw, L.vh); ctx.clip();
    ctx.translate((vr() - 0.5) * sh, (vr() - 0.5) * sh - cam.y * m);
    Art.backdrop(ctx, st, cam.x, m, fx.btFade); // skyline, fence, street, crates: inked once, blitted here
    if (fx.btFade > 0.02) { // bullet time drains the street to black and white; only what moves keeps its colour
      ctx.globalCompositeOperation = 'saturation'; ctx.globalAlpha = fx.btFade; ctx.fillStyle = '#000'; ctx.fillRect(0, cam.y * m, L.vw, L.vh);
      ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
    }
    ctx.translate(-cam.x * m, 0);

    ctx.fillStyle = '#7E1717'; // what a hit leaves on the wall, with drips
    for (const s of fx.splats) if (s.x > x0 && s.x < x1) {
      if (FXI && s.r > 0.1) { spr('splat', s.x * m, s.y * m, s.r * 4.5 * m); continue; }
      ctx.beginPath(); ctx.arc(s.x * m, s.y * m, s.r * m, 0, 6.2832); ctx.fill();
      if (s.d) ctx.fillRect((s.x - 0.02) * m, s.y * m, 0.04 * m, s.d * m);
    }
    if (st.exitX < x1) text(ctx, 'VÝCHOD', (st.exitX + 2.1) * m, 7.08 * m, 0.5 * m, PAPER, 'center');

    let aimEnd = null;
    if (!st.over) { // aim line: where the next shot will fly, up to the first wall or enemy
      const gx = p.x + p.ax * 0.6, gy = p.y - p.h * 0.6 + p.ay * 0.6;
      let d = 0, hit = false;
      for (; d < 24 && !hit; d += 0.1) {
        const x = gx + p.ax * d, y = gy + p.ay * d;
        for (const b of st.solids) if (x > b.x && x < b.x + b.w && y > b.y && y < b.y + b.h) hit = true;
        for (const e of enemies) if (x > e.x - e.w / 2 && x < e.x + e.w / 2 && y > e.y - e.h && y < e.y) hit = true;
      }
      const ex = gx + p.ax * d, ey = gy + p.ay * d;
      ctx.strokeStyle = RED; ctx.globalAlpha = 0.7; ctx.lineWidth = Math.max(1.5, 0.045 * m); ctx.lineCap = 'butt';
      ctx.setLineDash([0.22 * m, 0.18 * m]);
      ctx.beginPath(); ctx.moveTo(gx * m, gy * m); ctx.lineTo(ex * m, ey * m); ctx.stroke();
      ctx.setLineDash([]); ctx.globalAlpha = 1;
      aimEnd = { x: ex, y: ey };
    }

    for (const t of fx.texts) {
      const k = t.t / t.max, size = (t.big ? 1.0 : (t.small ? 0.5 : 0.72)) * m * (1.15 - 0.15 * k);
      ctx.save(); ctx.translate(t.x * m, (t.y - (1 - k) * 0.6) * m); ctx.rotate(-0.16 + (t.seed % 7) * 0.04);
      ctx.globalAlpha = Math.min(1, k * 3);
      if (t.s === '!') { text(ctx, t.s, 0, 0, size, t.c, 'center', INK); ctx.restore(); continue; }
      const lettered = FXI && { 'BLAM!': 'blam', 'BAM!': 'blam', 'KRA-KOOM!': 'krakoom', 'RAT-TAT-TAT!': 'rat', 'CINK!': 'clink' }[t.s];
      if (lettered) { spr(lettered, 0, 0, size * (lettered === 'rat' ? 3.6 : (lettered === 'clink' ? 2.0 : 2.5))); ctx.restore(); continue; } // hand-lettered from the FX sheet
      ctx.font = `400 ${size}px ${FONT}`;
      const w = ctx.measureText(t.s).width / 2 + size * 0.35, h = size * 0.72, n = 14;
      ctx.fillStyle = PAPER; ctx.strokeStyle = INK; ctx.lineWidth = Math.max(2.5, size * 0.11); ctx.lineJoin = 'miter'; ctx.beginPath(); // jagged impact burst behind the word
      for (let i = 0; i < n * 2; i++) {
        const a = i / (n * 2) * 6.2832, rr = i & 1 ? 0.78 : 1.12 + ((t.seed * (i + 3) * 7919) % 100) / 400;
        const x = Math.cos(a) * w * rr, y = Math.sin(a) * h * rr;
        if (i) ctx.lineTo(x, y); else ctx.moveTo(x, y);
      }
      ctx.closePath(); ctx.fill(); ctx.stroke();
      text(ctx, t.s, 0, size * 0.04, size, t.c === INK ? GOLD : t.c, 'center', INK);
      ctx.restore();
    }

    const frac = v => ((v % 1) + 1) % 1, now = st.tick / 60;
    ctx.save(); ctx.scale(m, m);
    for (const b of fx.bodies) { // tumbling and fallen bodies
      if (b.x < x0 - 2 || b.x > x1 + 2) continue;
      const o = { x: b.x, y: b.y, f: b.dx, pose: 'dead', dir: [Math.cos(b.rot), Math.sin(b.rot)], aim: null, kind: b.kind, t: b.rest ? 0 : now, id: b.id, rest: b.rest };
      if (!b.rest || Assets.get('enemy_sheet')) { ctx.globalAlpha = Math.min(1, b.t / 40); actor(ctx, o); ctx.globalAlpha = 1; continue; }
      if (!b.sprite || b.spriteM !== m) { // a body at rest never changes: draw it once, then blit
        const k = Math.min(2, ctx.getTransform().a / m || 1) * m, c = document.createElement('canvas');
        c.width = Math.ceil(3.4 * k); c.height = Math.ceil(1.7 * k);
        const g = c.getContext('2d'); g.scale(k, k); g.translate(1.7 - b.x, 1.1 - b.y);
        Art.figure(g, o); b.sprite = c; b.spriteM = m;
      }
      ctx.globalAlpha = Math.min(1, b.t / 40); ctx.drawImage(b.sprite, b.x - 1.7, b.y - 1.1, 3.4, 1.7); ctx.globalAlpha = 1;
    }
    for (const e of enemies) if (e.onGround && e.x > x0 && e.x < x1) Art.shadow(ctx, e.x, e.y, 0.36);
    if (p.onGround) Art.shadow(ctx, p.x, p.y, p.prone > 0 ? 0.8 : 0.36);
    enemies.forEach((e, i) => {
      if (e.x < x0 || e.x > x1) return;
      let aim = null;
      if (e.active) { const dx = p.x - e.x, dy = (p.y - p.h * 0.5) - (e.y - e.h * 0.6), l = Math.sqrt(dx * dx + dy * dy) || 1; aim = [dx / l, dy / l]; }
      const moving = Math.abs(e.vx) > 0.5;
      actor(ctx, { x: e.x, y: e.y, f: e.face, pose: !e.onGround ? 'air' : (moving ? 'run' : 'stand'), phase: frac(e.x * e.face / 1.7), vx: e.vx, vy: e.vy, aim, kind: e.kind, flash: e.flash > 0, t: now, id: i + 1, lit: Art.lit(st, e.x, e.y) });
    });
    if (!(p.inv > 0 && (st.tick >> 2) & 1)) {
      const f = p.ax >= 0 ? 1 : -1;
      if (p.dive || p.prone > 0) {
        const sl = Math.sqrt(p.vx * p.vx + p.vy * p.vy), dir = p.dive && sl > 0.5 ? [p.vx / sl, p.vy / sl] : [p.vx >= 0 ? 1 : -1, 0];
        actor(ctx, { x: p.x, y: p.y - (p.dive ? 0.5 : 0.3), f, pose: p.dive ? 'dive' : 'prone', dir, aim: [p.ax, p.ay], kind: 'player', t: now, vx: p.vx, vy: p.vy, lit: Art.lit(st, p.x, p.y) });
      } else {
        const moving = Math.abs(p.vx) > 0.5;
        actor(ctx, { x: p.x, y: p.y, f, pose: !p.onGround ? 'air' : (moving ? 'run' : 'stand'), phase: frac(p.x * f / 1.9), vx: p.vx, vy: p.vy, aim: [p.ax, p.ay], kind: 'player', t: now, lit: Art.lit(st, p.x, p.y) });
      }
    }
    ctx.restore();
    for (const e of enemies) if (e.tele > 0 && e.x > x0 && e.x < x1) text(ctx, '!', e.x * m, (e.y - e.h - 0.62) * m, 0.9 * m, GOLD, 'center', INK);

    for (const f of fx.flashes) { // muzzle flash
      if (FXI) { const w = (f.big ? 1.9 : 1.3) * m; ctx.save(); ctx.translate((f.x + f.dx * 0.1) * m, (f.y + f.dy * 0.1) * m); ctx.rotate(Math.atan2(f.dy, f.dx)); spr('flash', w * 0.42, 0, w); ctx.restore(); continue; }
      const r = (f.big ? 0.55 : 0.34) * m, px = -f.dy, py = f.dx;
      ctx.fillStyle = PAPER; ctx.strokeStyle = INK; ctx.lineWidth = Math.max(2, 0.06 * m); ctx.lineJoin = 'miter';
      ctx.beginPath(); // a jagged star of white paper with an ink edge
      for (let i = 0; i < 14; i++) { const a = i / 14 * 6.2832 + f.x, rr = r * (i & 1 ? 0.55 : 1.25 + ((i * 7) % 3) * 0.25); const X = (f.x + f.dx * 0.25) * m + Math.cos(a) * rr, Y = (f.y + f.dy * 0.25) * m + Math.sin(a) * rr; if (i) ctx.lineTo(X, Y); else ctx.moveTo(X, Y); }
      ctx.closePath(); ctx.fill(); ctx.stroke();
      ctx.fillStyle = f.team === 0 ? PAPER : AMBER; ctx.beginPath();
      ctx.moveTo((f.x + f.dx * 0.9 * (f.big ? 1.4 : 1)) * m, (f.y + f.dy * 0.9 * (f.big ? 1.4 : 1)) * m);
      ctx.lineTo(f.x * m + px * r, f.y * m + py * r); ctx.lineTo((f.x - f.dx * 0.1) * m, (f.y - f.dy * 0.1) * m); ctx.lineTo(f.x * m - px * r, f.y * m - py * r);
      ctx.closePath(); ctx.fill(); ctx.stroke();
    }

    const trail = slow ? 2.6 : 1.6;
    for (const b of bullets) { // every round drags a wedge of ink smoke: white for yours, amber for theirs
      const sp = Math.sqrt(b.vx * b.vx + b.vy * b.vy) || 1, ux = b.vx / sp, uy = b.vy / sp, px = -uy, py = ux, mine = b.team === 0;
      const hw = 0.085, tx = b.x - ux * trail, ty = b.y - uy * trail;
      ctx.fillStyle = mine ? PAPER : AMBER; ctx.strokeStyle = INK; ctx.lineWidth = Math.max(1.5, 0.035 * m); ctx.lineJoin = 'round';
      ctx.beginPath(); ctx.moveTo((b.x + px * hw) * m, (b.y + py * hw) * m); ctx.lineTo(tx * m, ty * m); ctx.lineTo((b.x - px * hw) * m, (b.y - py * hw) * m); ctx.closePath(); ctx.stroke(); ctx.fill();
      if (mine) { ctx.beginPath(); for (let i = 0; i < 4; i++) { const d = trail * (0.25 + i * 0.2), o = (i & 1 ? 1 : -1) * 0.07, cx = (b.x - ux * d + px * o) * m, cy = (b.y - uy * d + py * o) * m, rr = (0.085 - i * 0.012) * m; for (let j = 0; j < 10; j++) { const a = j / 10 * 6.2832 + i, q = rr * (j & 1 ? 1.15 : 1.6); if (j) ctx.lineTo(cx + Math.cos(a) * q, cy + Math.sin(a) * q); else ctx.moveTo(cx + Math.cos(a) * q, cy + Math.sin(a) * q); } ctx.closePath(); } ctx.stroke(); ctx.fill(); }
      const r = 0.105 * m;
      ctx.fillStyle = mine ? RED : GOLD; ctx.lineWidth = Math.max(1.5, 0.045 * m);
      ctx.beginPath(); ctx.moveTo((b.x + ux * 0.2) * m, (b.y + uy * 0.2) * m); ctx.lineTo(b.x * m + px * r, b.y * m + py * r); ctx.lineTo((b.x - ux * 0.12) * m, (b.y - uy * 0.12) * m); ctx.lineTo(b.x * m - px * r, b.y * m - py * r); ctx.closePath(); ctx.stroke(); ctx.fill();
    }

    if (aimEnd) {
      ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(3, 0.11 * m);
      ctx.beginPath(); ctx.arc(aimEnd.x * m, aimEnd.y * m, 0.17 * m, 0, 6.2832); ctx.stroke();
      ctx.strokeStyle = RED; ctx.lineWidth = Math.max(1.5, 0.055 * m);
      ctx.beginPath(); ctx.arc(aimEnd.x * m, aimEnd.y * m, 0.17 * m, 0, 6.2832); ctx.stroke();
      ctx.beginPath(); for (let i = 0; i < 4; i++) { const a = i * 1.5708 + 0.2, c = Math.cos(a), s2 = Math.sin(a); ctx.moveTo((aimEnd.x + c * 0.11) * m, (aimEnd.y + s2 * 0.11) * m); ctx.lineTo((aimEnd.x + c * 0.3) * m, (aimEnd.y + s2 * 0.3) * m); } ctx.stroke(); // inked cross hairs
    }
    for (const c of fx.casings) { // spinning brass
      ctx.save(); ctx.translate(c.x * m, c.y * m); ctx.rotate(c.a);
      if (FXI) { spr('casing', 0, 0, 0.2 * m); ctx.restore(); continue; }
      ctx.fillStyle = INK; ctx.fillRect(-0.13 * m, -0.065 * m, 0.26 * m, 0.13 * m);
      ctx.fillStyle = AMBER; ctx.fillRect(-0.1 * m, -0.04 * m, 0.2 * m, 0.08 * m);
      ctx.fillStyle = PAPER; ctx.fillRect(-0.1 * m, -0.04 * m, 0.2 * m, 0.025 * m);
      ctx.restore();
    }
    if (FXI) for (const q of fx.stars) spr('star', q.x * m, q.y * m, (0.5 + (7 - q.t) * 0.09) * m);
    for (const s of fx.sparks) {
      ctx.fillStyle = s.c; ctx.globalAlpha = Math.min(1, s.t / 8);
      ctx.fillRect(s.x * m - 0.05 * m, s.y * m - 0.05 * m, 0.1 * m, 0.1 * m);
    }
    ctx.globalAlpha = 1;
    ctx.translate(cam.x * m, 0);
    Art.foreground(ctx, cam.x, m);
    { // rain: hard white slashes. In bullet time it hangs in the air as short dashes.
      const n = 120, W = Sim.VW + 3;
      ctx.strokeStyle = PAPER; ctx.globalAlpha = slow ? 0.95 : 0.7; ctx.lineWidth = Math.max(1.2, (slow ? 0.034 : 0.024) * m); ctx.lineCap = 'butt';
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const sp = 15 + (i * 37 % 11), len = slow ? 0.16 : 0.45 + (i % 5) * 0.12, y = ((i * 0.6180339 + fx.rain * sp / 13) % 1) * 13 - 0.5, x = ((i * 0.754877 + 0.31) % 1) * W - ((cam.x * 1.2) % W + W) % W;
        const xx = ((x % W) + W) % W - 1.5 - y * 0.28;
        ctx.moveTo(xx * m, y * m); ctx.lineTo((xx - len * 0.28) * m, (y + len) * m);
      }
      ctx.stroke(); ctx.globalAlpha = 1;
      // each drop that lands throws a little crown of ink on the street, crate or catwalk it hits
      ctx.lineWidth = Math.max(1, 0.022 * m); ctx.beginPath();
      for (let i = 0; i < 18; i++) {
        const tt = fx.rain * 3 + i * 0.137, ph = tt % 1, cyc = Math.floor(tt); if (ph > 0.55) continue;
        const h = Math.sin(cyc * 12.9898 + i * 78.233) * 43758.5453, wx = cam.x + (h - Math.floor(h)) * visW; let gy = 11;
        for (const b of st.solids) if (b.w !== 1 && wx > b.x && wx < b.x + b.w && b.y < gy && b.y > 0.5) gy = b.y;
        const X = (wx - cam.x) * m, Y = gy * m, r = (0.05 + ph * 0.22) * m;
        ctx.moveTo(X, Y); ctx.lineTo(X - r, Y - r * 0.8); ctx.moveTo(X, Y); ctx.lineTo(X + r, Y - r * 0.8); ctx.moveTo(X, Y); ctx.lineTo(X, Y - r * 1.2);
      }
      ctx.stroke();
    }
    ctx.restore();
    if (fx.btFade > 0.02) { // slow time: halftone and grain over the picture, and a black panel border closes in
      const u = L.vh, b = 0.045 * u * fx.btFade;
      ctx.globalAlpha = fx.btFade; ctx.drawImage(grainSheet(L), 0, 0, L.vw, L.vh); ctx.globalAlpha = 1;
      ctx.fillStyle = INK; ctx.fillRect(0, 0, L.vw, b); ctx.fillRect(0, L.vh - b, L.vw, b); ctx.fillRect(0, 0, b, L.vh); ctx.fillRect(L.vw - b, 0, b, L.vh);
      ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(2, 0.006 * u); ctx.strokeRect(b, b, L.vw - 2 * b, L.vh - 2 * b);
    }
    hud(ctx, st, L, p, it);
  }

  // rough ink disc: a circle that was drawn, not plotted
  function disc(ctx, x, y, R, seedN) {
    ctx.beginPath();
    for (let i = 0; i < 22; i++) { const a = i / 22 * 6.2832, rr = R * (1 + (((seedN * (i + 5) * 7919) % 100) / 100 - 0.5) * 0.05); if (i) ctx.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); else ctx.moveTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
    ctx.closePath();
  }
  function pth(ctx, s, pts) { ctx.beginPath(); for (let i = 0; i < pts.length; i += 2) { if (i) ctx.lineTo(pts[i] * s, pts[i + 1] * s); else ctx.moveTo(pts[i] * s, pts[i + 1] * s); } ctx.closePath(); }
  // comic panel with the detective's face
  function portrait(ctx, x, y, s) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(-0.035);
    ctx.fillStyle = INK; ctx.fillRect(-0.05 * s, -0.05 * s, 1.1 * s, 1.1 * s);
    ctx.fillStyle = PAPER; ctx.fillRect(0, 0, s, s);
    ctx.beginPath(); ctx.rect(0.055 * s, 0.055 * s, 0.89 * s, 0.89 * s); ctx.clip();
    ctx.fillStyle = '#585C62'; ctx.fillRect(0, 0, s, s);
    ctx.strokeStyle = INK; ctx.lineWidth = Math.max(1, 0.022 * s); ctx.beginPath();
    for (let d = -0.2; d < 1.4; d += 0.075) { ctx.moveTo((d + 0.5) * s, 0); ctx.lineTo(d * s, s * 0.9); }
    ctx.stroke();
    ctx.fillStyle = INK; pth(ctx, s, [0, 1, 0.1, 0.74, 0.4, 0.6, 0.7, 0.62, 1, 0.8, 1, 1]); ctx.fill();
    ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(1, 0.03 * s); ctx.lineJoin = 'miter'; ctx.beginPath(); ctx.moveTo(0.36 * s, 0.68 * s); ctx.lineTo(0.5 * s, 0.9 * s); ctx.lineTo(0.66 * s, 0.68 * s); ctx.stroke();
    ctx.fillStyle = CRIM; pth(ctx, s, [0.36, 0.58, 0.7, 0.59, 0.68, 0.7, 0.4, 0.7]); ctx.fill();
    ctx.fillStyle = PAPER; pth(ctx, s, [0.36, 0.36, 0.7, 0.36, 0.78, 0.47, 0.72, 0.5, 0.7, 0.6, 0.52, 0.64, 0.38, 0.56]); ctx.fill();
    ctx.fillStyle = INK; pth(ctx, s, [0.36, 0.36, 0.52, 0.36, 0.48, 0.5, 0.52, 0.64, 0.38, 0.56]); ctx.fill();
    pth(ctx, s, [0.5, 0.36, 0.74, 0.36, 0.72, 0.45, 0.5, 0.43]); ctx.fill(); // the brim's shadow over the eyes
    ctx.strokeStyle = INK; ctx.lineWidth = Math.max(1, 0.025 * s); ctx.beginPath(); ctx.moveTo(0.59 * s, 0.555 * s); ctx.lineTo(0.7 * s, 0.55 * s); ctx.stroke();
    ctx.fillStyle = INK; pth(ctx, s, [0.3, 0.34, 0.33, 0.12, 0.5, 0.07, 0.68, 0.12, 0.73, 0.34]); ctx.fill();
    ctx.fillStyle = CRIM; pth(ctx, s, [0.305, 0.27, 0.72, 0.27, 0.73, 0.34, 0.3, 0.34]); ctx.fill();
    ctx.fillStyle = INK; pth(ctx, s, [0.12, 0.34, 0.92, 0.33, 0.86, 0.41, 0.2, 0.4]); ctx.fill();
    ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(1, 0.022 * s); ctx.beginPath(); ctx.moveTo(0.33 * s, 0.13 * s); ctx.lineTo(0.5 * s, 0.08 * s); ctx.lineTo(0.66 * s, 0.125 * s); ctx.moveTo(0.14 * s, 0.335 * s); ctx.lineTo(0.9 * s, 0.325 * s); ctx.stroke();
    ctx.restore();
  }
  function tile(ctx, x, y, s, rot, label, value, vc) { // square comic panel with a number in it
    ctx.save(); ctx.translate(x + s / 2, y + s / 2); ctx.rotate(rot);
    ctx.fillStyle = INK; ctx.fillRect(-s * 0.55, -s * 0.55, s * 1.1, s * 1.1);
    ctx.fillStyle = PAPER; ctx.fillRect(-s / 2, -s / 2, s, s);
    ctx.fillStyle = INK; ctx.fillRect(-s * 0.44, -s * 0.44, s * 0.88, s * 0.88);
    text(ctx, label, 0, -s * 0.27, s * 0.2, PAPER, 'center');
    text(ctx, value, 0, s * 0.12, fit(ctx, value, s * 0.5, s * 0.78), vc || PAPER, 'center');
    ctx.restore();
  }
  function roughRect(ctx, x, y, w, h, seedN) { // a frame ruled by hand: the edges wander and overshoot
    const j = i => (((seedN * (i + 3) * 7919) % 100) / 100 - 0.5) * Math.min(w, h) * 0.035;
    ctx.beginPath(); ctx.moveTo(x + j(1), y + j(2));
    for (let i = 1; i <= 6; i++) ctx.lineTo(x + w * i / 6 + j(i + 2), y + j(i + 9));
    for (let i = 1; i <= 3; i++) ctx.lineTo(x + w + j(i + 15), y + h * i / 3 + j(i + 19));
    for (let i = 5; i >= 0; i--) ctx.lineTo(x + w * i / 6 + j(i + 23), y + h + j(i + 30));
    for (let i = 2; i >= 1; i--) ctx.lineTo(x + j(i + 37), y + h * i / 3 + j(i + 41));
    ctx.closePath();
  }
  function gritty(ctx, L, path) { ctx.save(); path(); ctx.clip(); ctx.globalAlpha = 0.85; ctx.drawImage(grainSheet(L), 0, 0, L.vw, L.vh); ctx.restore(); } // paper grain over a piece of UI
  function hud(ctx, st, L, p, it) {
    const u = L.vh, pad = 0.014 * u, ps = 0.15 * u, sw = 0.06 * u, gap = 0.01 * u, shh = 0.044 * u, sk = 0.02 * u;
    const pw = ps + 0.05 * u + Sim.HP * (sw + gap) + sk + 0.02 * u, ph = ps + 0.04 * u;
    const plate = () => roughRect(ctx, pad, pad, pw, ph, 3);
    plate(); ctx.fillStyle = 'rgba(8,8,10,0.78)'; ctx.fill(); ctx.lineJoin = 'round'; ctx.strokeStyle = INK; ctx.lineWidth = Math.max(5, 0.016 * u); ctx.stroke(); ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(2, 0.006 * u); ctx.stroke();
    portrait(ctx, pad + 0.022 * u, pad + 0.022 * u, ps);
    const hx = pad + ps + 0.055 * u, hy = pad + 0.03 * u;
    for (let i = 0; i < Sim.HP; i++) {
      const x = hx + i * (sw + gap);
      ctx.beginPath(); ctx.moveTo(x + sk, hy); ctx.lineTo(x + sw + sk, hy); ctx.lineTo(x + sw, hy + shh); ctx.lineTo(x, hy + shh); ctx.closePath();
      ctx.lineJoin = 'miter'; ctx.strokeStyle = INK; ctx.lineWidth = Math.max(4, 0.02 * u); ctx.stroke();
      ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(1.5, 0.007 * u); ctx.stroke();
      ctx.fillStyle = i < p.hp ? CRIM : INK; ctx.fill();
    }
    const rl = p.reload > 0, ay = hy + shh + 0.06 * u;
    text(ctx, rl ? 'PŘEBÍJÍM' : `${p.ammo}`, hx, ay, 0.07 * u, rl ? AMBER : PAPER, 'left', INK);
    if (!rl) { const aw = ctx.measureText(`${p.ammo}`).width; text(ctx, `/ ${Sim.MAG}`, hx + aw + 0.014 * u, ay + 0.008 * u, 0.042 * u, PAPER, 'left', INK); }
    gritty(ctx, L, plate);
    if (st.combo >= 2) text(ctx, `×${st.combo}`, pad + pw + 0.06 * u, pad + ph * 0.5, 0.11 * u, CRIM, 'left', PAPER);
    ctx.globalAlpha = 0.75; // small print along the edges
    text(ctx, `STRANA ${st.page}  ·  ${st.kills} ZABITÍ`, L.vw - 0.012 * u, 0.022 * u, 0.028 * u, PAPER, 'right', INK);
    if (it && it.fps) text(ctx, `${it.fps} FPS`, 0.012 * u, L.vh - 0.018 * u, 0.024 * u, PAPER, 'left', INK);
    ctx.globalAlpha = 1;
    if (fx.banner > 0 && !st.over) { // page caption, like a narration box
      const s2 = `STRÁNKA ${st.page}`, size = 0.085 * u; ctx.font = `400 ${size}px ${FONT}`;
      const w = ctx.measureText(s2).width + 0.09 * u, h = 0.13 * u;
      ctx.save(); ctx.translate(L.vw / 2, 0.3 * u); ctx.rotate(-0.025); ctx.globalAlpha = Math.min(1, fx.banner / 12);
      ctx.fillStyle = INK; ctx.fillRect(-w / 2 - 0.012 * u, -h / 2 - 0.012 * u, w + 0.024 * u, h + 0.024 * u);
      ctx.fillStyle = PAPER; ctx.fillRect(-w / 2, -h / 2, w, h);
      text(ctx, s2, 0, 0.006 * u, size, INK, 'center');
      ctx.restore();
    }
    if (fx.flash > 0) { ctx.fillStyle = CRIM; ctx.globalAlpha = fx.flash / 16 * 0.4; ctx.fillRect(0, 0, L.vw, L.vh); ctx.globalAlpha = 1; }
  }

  let curL = null;
  function button(ctx, b, R, ring, label, ready, meter, icon, on) {
    ctx.globalAlpha = ready ? 1 : 0.55;
    const bt = icon === 'bt', col = bt ? GOLD : PAPER;
    ctx.fillStyle = INK; disc(ctx, b.x, b.y, R + ring + 4, 3); ctx.fill();
    if (bt) { // the stopwatch: its gold rim is the bullet time meter
      const rr = R + ring * 0.5; ctx.lineCap = 'butt';
      ctx.lineWidth = ring; ctx.strokeStyle = '#4A3A10'; ctx.beginPath(); ctx.arc(b.x, b.y, rr, 0, 6.2832); ctx.stroke();
      if (meter > 0.005) { ctx.strokeStyle = GOLD; ctx.beginPath(); ctx.arc(b.x, b.y, rr, -1.5708, -1.5708 + 6.2832 * meter); ctx.stroke(); }
      ctx.strokeStyle = INK; ctx.lineWidth = 2; for (let i = 0; i < 12; i++) { const a = i / 12 * 6.2832; ctx.beginPath(); ctx.moveTo(b.x + Math.cos(a) * R, b.y + Math.sin(a) * R); ctx.lineTo(b.x + Math.cos(a) * (R + ring), b.y + Math.sin(a) * (R + ring)); ctx.stroke(); }
    } else { ctx.fillStyle = PAPER; disc(ctx, b.x, b.y, R + ring * 0.55, 5); ctx.fill(); }
    ctx.fillStyle = on ? CRIM : INK; disc(ctx, b.x, b.y, R - 1, 7); ctx.fill();
    ctx.strokeStyle = col; ctx.fillStyle = col; ctx.lineWidth = Math.max(2.5, R * 0.1); ctx.lineJoin = 'miter'; ctx.lineCap = 'butt';
    const iy = b.y - R * 0.18, ir = R * 0.34;
    if (bt) {
      ctx.beginPath(); ctx.arc(b.x, iy + ir * 0.12, ir * 0.95, 0, 6.2832); ctx.stroke();
      ctx.fillRect(b.x - ir * 0.2, iy - ir * 1.3, ir * 0.4, ir * 0.36); ctx.fillRect(b.x - ir * 0.42, iy - ir * 1.5, ir * 0.84, ir * 0.22);
      ctx.beginPath(); ctx.moveTo(b.x + ir * 0.75, iy - ir * 0.75); ctx.lineTo(b.x + ir * 1.05, iy - ir * 1.05); ctx.stroke();
      ctx.lineWidth = Math.max(2, R * 0.075); ctx.beginPath(); ctx.moveTo(b.x, iy + ir * 0.12); ctx.lineTo(b.x, iy - ir * 0.5); ctx.moveTo(b.x, iy + ir * 0.12); ctx.lineTo(b.x + ir * 0.42, iy + ir * 0.3); ctx.stroke();
    } else if (icon === 'jump') { // chevrons going up
      for (const o of [-0.35, 0.35]) { ctx.beginPath(); ctx.moveTo(b.x - ir, iy + ir * (o + 0.45)); ctx.lineTo(b.x, iy + ir * (o - 0.45)); ctx.lineTo(b.x + ir, iy + ir * (o + 0.45)); ctx.stroke(); }
    } else { // a diving figure: body line, arms forward, speed lines behind
      ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(b.x - ir * 0.9, iy + ir * 0.55); ctx.lineTo(b.x + ir * 0.3, iy - ir * 0.2); ctx.lineTo(b.x + ir * 1.05, iy - ir * 0.45); ctx.stroke();
      ctx.beginPath(); ctx.arc(b.x + ir * 0.5, iy - ir * 0.62, ir * 0.24, 0, 6.2832); ctx.fill();
      ctx.lineWidth = Math.max(1.5, R * 0.055); ctx.beginPath(); ctx.moveTo(b.x - ir * 1.2, iy - ir * 0.3); ctx.lineTo(b.x - ir * 0.4, iy - ir * 0.62); ctx.moveTo(b.x - ir * 1.3, iy + ir * 0.1); ctx.lineTo(b.x - ir * 0.7, iy - ir * 0.14); ctx.stroke();
    }
    text(ctx, label, b.x, b.y + R * 0.54, fit(ctx, label, R * 0.3, R * 1.55), col, 'center');
    if (curL) gritty(ctx, curL, () => disc(ctx, b.x, b.y, R + ring + 4, 3));
    ctx.globalAlpha = 1;
  }

  function stick(ctx, hint, st, R) {
    const base = hint;
    ctx.globalAlpha = st.on ? 0.8 : 0.5;
    ctx.fillStyle = 'rgba(8,8,10,0.35)'; disc(ctx, base.x, base.y, R, 11); ctx.fill();
    ctx.strokeStyle = INK; ctx.lineWidth = 7; ctx.stroke();
    ctx.strokeStyle = PAPER; ctx.lineWidth = 3; ctx.setLineDash([R * 0.9, R * 0.12, R * 0.35, R * 0.08]); ctx.stroke(); // a dry brush: the ring breaks
    ctx.lineWidth = 1.5; ctx.setLineDash([R * 0.5, R * 0.3]); disc(ctx, base.x + 2, base.y - 1, R * 1.04, 29); ctx.stroke(); ctx.setLineDash([]);
    ctx.fillStyle = PAPER;
    for (let i = 0; i < 4; i++) { const a = i * 1.5708, c = Math.cos(a), s2 = Math.sin(a), d = R * 0.82, w = R * 0.1; ctx.beginPath(); ctx.moveTo(base.x + c * (d + w), base.y + s2 * (d + w)); ctx.lineTo(base.x + c * (d - w * 0.4) - s2 * w, base.y + s2 * (d - w * 0.4) + c * w); ctx.lineTo(base.x + c * (d - w * 0.4) + s2 * w, base.y + s2 * (d - w * 0.4) - c * w); ctx.closePath(); ctx.fill(); }
    const kx = base.x + (st.on ? st.vx * R : 0), ky = base.y + (st.on ? st.vy * R : 0);
    ctx.fillStyle = INK; disc(ctx, kx, ky, R * 0.46, 13); ctx.fill();
    ctx.fillStyle = PAPER; disc(ctx, kx, ky, R * 0.4, 17); ctx.fill();
    ctx.fillStyle = '#585C62'; disc(ctx, kx + R * 0.03, ky + R * 0.04, R * 0.33, 19); ctx.fill();
    ctx.globalAlpha = 1;
  }

  function drawControls(ctx, st, L, sticks, pulse, touch) {
    const p = st.player;
    if (touch) { stick(ctx, L.hintL, sticks.l, L.stickR); stick(ctx, L.hintR, sticks.r, L.stickR); }
    curL = L;
    button(ctx, L.bt, L.R * 1.14, L.ring * 1.2, 'BULLET TIME', st.meter > 0.05 || st.bt, st.meter, 'bt', st.bt);
    if (!touch) return;
    button(ctx, L.dive, L.R * 0.86, L.ring, 'PLAVMO', p.diveCd <= 0 && !p.dive && p.prone <= 0, undefined, 'dive', false);
    button(ctx, L.jump, L.R * 0.86, L.ring, 'SKOK', !p.dive && p.prone <= 0, undefined, 'jump', false);
    if (pulse && L[pulse]) {
      const b = L[pulse], k = (st.tick % 40) / 40;
      ctx.strokeStyle = PAPER; ctx.globalAlpha = 1 - k; ctx.lineWidth = Math.max(3, L.R * 0.12);
      ctx.beginPath(); ctx.arc(b.x, b.y, L.R + L.ring + 6 + k * L.R * 0.6, 0, 6.2832); ctx.stroke(); ctx.globalAlpha = 1;
    }
  }

  // speech bubble with a tail: how the game explains itself
  function bubble(ctx, L, str, target) {
    const u = L.vh, size = 0.046 * u, maxW = 0.6 * u, words = str.split(' '), lines = [];
    ctx.font = `400 ${size}px ${FONT}`;
    let cur = '';
    for (const w of words) { const t = cur ? cur + ' ' + w : w; if (cur && ctx.measureText(t).width > maxW) { lines.push(cur); cur = w; } else cur = t; }
    lines.push(cur);
    let tw = 0; for (const l of lines) tw = Math.max(tw, ctx.measureText(l).width);
    const w = tw + 0.07 * u, h = lines.length * size * 1.18 + 0.05 * u;
    let x, y, tail = null;
    if (target) { x = Math.max(8, Math.min(L.vw - w - 8, target.x - w * 0.6)); y = Math.max(0.185 * u, target.y - L.R - L.ring - 0.07 * u - h); tail = [Math.min(x + w - 0.04 * u, Math.max(x + 0.04 * u, target.x)), y + h, target.x, target.y - L.R - L.ring - 6]; }
    else { x = L.vw / 2 - w / 2; y = 0.27 * u; }
    const shape = grow => { ctx.beginPath(); const r = 0.03 * u; ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.lineTo(x + w, y + r); ctx.lineTo(x + w, y + h - r); ctx.lineTo(x + w - r, y + h);
      if (tail) { ctx.lineTo(tail[0] + 0.03 * u, y + h); ctx.lineTo(tail[2], tail[3]); ctx.lineTo(tail[0] - 0.03 * u, y + h); }
      ctx.lineTo(x + r, y + h); ctx.lineTo(x, y + h - r); ctx.lineTo(x, y + r); ctx.closePath(); };
    shape(); ctx.lineJoin = 'round'; ctx.strokeStyle = INK; ctx.lineWidth = Math.max(5, 0.02 * u); ctx.stroke(); ctx.fillStyle = PAPER; ctx.fill();
    lines.forEach((l, i) => text(ctx, l, x + w / 2, y + 0.025 * u + size * 0.62 + i * size * 1.18, size, INK, 'center'));
  }

  function panel(ctx, L, title, lines, foot) {
    const m = L.s, w = Math.min(L.vw - 24, 16 * m), inner = w - 1.3 * m;
    let ls = 0.5 * m;
    for (const ln of lines) ls = Math.min(ls, fit(ctx, ln, 0.5 * m, inner));
    const ts = fit(ctx, title, 1.15 * m, inner), fs = foot ? fit(ctx, foot, 0.62 * m, inner) : 0;
    const lh = ls * 1.55, h = 2.3 * m + lines.length * lh + (foot ? 1.5 * m : 0.3 * m), x = (L.vw - w) / 2, y = (L.vh - h) / 2;
    ctx.fillStyle = 'rgba(8,8,10,0.78)'; ctx.fillRect(0, 0, L.vw, L.vh);
    ctx.fillStyle = INK; ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = PAPER; ctx.lineWidth = Math.max(2, 0.06 * m); ctx.strokeRect(x + 0.16 * m, y + 0.16 * m, w - 0.32 * m, h - 0.32 * m);
    text(ctx, title, L.vw / 2, y + 1.2 * m, ts, PAPER, 'center');
    lines.forEach((ln, i) => text(ctx, ln, L.vw / 2, y + 2.35 * m + i * lh, ls, PAPER, 'center'));
    if (foot) text(ctx, foot, L.vw / 2, y + h - 0.95 * m, fs, RED, 'center');
  }

  function draw(ctx, st, L, opts) {
    ctx.fillStyle = NIGHT; ctx.fillRect(0, 0, L.vw, L.vh);
    drawWorld(ctx, st, L, opts.touch, opts.interp);
    drawControls(ctx, st, L, opts.sticks, opts.pulse, opts.touch);
    if (opts.hint && !opts.panel) bubble(ctx, L, opts.hint, opts.touch && opts.pulse ? L[opts.pulse] : null);
    if (opts.panel) panel(ctx, L, opts.panel.title, opts.panel.lines, opts.panel.foot);
  }

  return { layout, draw, onEvents, tickFx, camX: () => cam.x, screenOf: (L, x, y) => ({ x: (x - cam.x) * L.z, y: (y - cam.y) * L.z }), reset: () => { cam.snap = true; fx.bodies = []; fx.splats = []; fx.texts = []; fx.sparks = []; fx.casings = []; Art.reset(); } };
})();
