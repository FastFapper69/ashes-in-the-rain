// Ink-and-paper art, drawn by code. Everything here is view-only.
// Figures are posed from a few joints; backgrounds are inked once into offscreen sheets.
const Art = (() => {
  // rainy night noir: charcoal walls, red brick, amber lamplight, pale mist; ink black on top
  const PAPER = '#EAE6DF', INK = '#08080A', RED = '#D92525', GOLD = '#E5A91A';
  const DEEP = '#191B1F', SLATE = '#30343B', MIST = '#6E747C', PALE = '#C4C3BD';
  const BRICK = '#5E2422', BRICK2 = '#7C332E', AMBER = '#F2A922', FOG = '#8E949A', PAVE = '#4E545C';
  const TAU = 6.2832;
  // mono: the world is black and white, and colour appears only where light falls (plus red for the hero, gold for his enemies)
  let mono = true; // one style now: ink noir

  function rng(seed) { let s = (seed >>> 0) || 1; return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296); }
  function hash(n) { n = Math.imul(n ^ (n >>> 15), 2246822519); n = Math.imul(n ^ (n >>> 13), 3266489917); return ((n ^ (n >>> 16)) >>> 0) / 4294967296; }

  // ---------- figures ----------
  // two-bone IK: returns the middle joint between a and b
  function ik(ax, ay, bx, by, l1, l2, bend) {
    let dx = bx - ax, dy = by - ay, d = Math.sqrt(dx * dx + dy * dy);
    const max = l1 + l2 - 0.002;
    if (d > max) { dx *= max / d; dy *= max / d; d = max; }
    if (d < 0.05) { d = 0.05; dx = 0; dy = 0.05; }
    const a = (l1 * l1 - l2 * l2 + d * d) / (2 * d), h = Math.sqrt(Math.max(0, l1 * l1 - a * a));
    return [ax + dx / d * a - dy / d * h * bend, ay + dy / d * a + dx / d * h * bend, ax + dx, ay + dy];
  }

  function tracePath(ctx, sh) {
    ctx.beginPath();
    if (sh.t === 'ell') ctx.ellipse(sh.x, sh.y, sh.rx, sh.ry, sh.rot || 0, 0, TAU);
    else { ctx.moveTo(sh.p[0], sh.p[1]); for (let i = 2; i < sh.p.length; i += 2) ctx.lineTo(sh.p[i], sh.p[i + 1]); if (sh.t === 'poly') ctx.closePath(); }
  }
  // All shapes of a figure go into ONE path, wound the same way, so the whole silhouette costs one stroke and one fill.
  // Drawing every limb on its own made a figure cost close to a millisecond.
  function traceAll(ctx, shapes) {
    ctx.beginPath();
    for (const sh of shapes) {
      if (sh.t === 'ell') { ctx.moveTo(sh.x + sh.rx, sh.y); ctx.ellipse(sh.x, sh.y, sh.rx, sh.ry, 0, 0, TAU); continue; }
      let q = sh.p;
      if (sh.t === 'line') { // a straight bar: turn it into a quad
        const dx = q[2] - q[0], dy = q[3] - q[1], l = Math.sqrt(dx * dx + dy * dy) || 1, px = -dy / l * sh.w / 2, py = dx / l * sh.w / 2;
        q = [q[0] + px, q[1] + py, q[2] + px, q[3] + py, q[2] - px, q[3] - py, q[0] - px, q[1] - py];
      }
      let area = 0; const n = q.length / 2;
      for (let i = 0; i < n; i++) { const j = (i + 1) % n; area += q[i * 2] * q[j * 2 + 1] - q[j * 2] * q[i * 2 + 1]; }
      if (area >= 0) { ctx.moveTo(q[0], q[1]); for (let i = 1; i < n; i++) ctx.lineTo(q[i * 2], q[i * 2 + 1]); }
      else { ctx.moveTo(q[(n - 1) * 2], q[(n - 1) * 2 + 1]); for (let i = n - 2; i >= 0; i--) ctx.lineTo(q[i * 2], q[i * 2 + 1]); }
      ctx.closePath();
    }
  }
  // tapered limb segment from a to b, with a round joint at a
  function seg(into, ax, ay, bx, by, w1, w2) {
    const dx = bx - ax, dy = by - ay, l = Math.sqrt(dx * dx + dy * dy) || 1, px = -dy / l, py = dx / l;
    into.push({ t: 'poly', p: [ax + px * w1 / 2, ay + py * w1 / 2, bx + px * w2 / 2, by + py * w2 / 2, bx - px * w2 / 2, by - py * w2 / 2, ax - px * w1 / 2, ay - py * w1 / 2] });
    into.push({ t: 'ell', x: ax, y: ay, rx: w1 / 2, ry: w1 / 2 }, { t: 'ell', x: bx, y: by, rx: w2 / 2, ry: w2 / 2 });
  }

  // o: {x, y, f, pose, phase, vy, vx, dir:[dx,dy], aim:[ax,ay]|null, kind, flash, t}
  // x,y = feet for upright poses, body centre for 'dive' / 'prone' / 'dead'
  function figure(ctx, o) {
    const f = o.f >= 0 ? 1 : -1, kind = o.kind, bulky = kind === 'brok';
    const step = Math.floor((o.t || 0) * 5), jit = i => (hash(step * 131 + i * 17 + (o.id || 0) * 7919) - 0.5) * 0.02; // the line "boils" five times a second
    let hip, neck, head, fa, fb, sx, sy, nx, ny, flare, bendK;
    const flat = o.pose === 'dive' || o.pose === 'prone' || o.pose === 'dead';
    if (flat) {
      let dx = o.dir[0], dy = o.dir[1];
      const l = Math.sqrt(dx * dx + dy * dy) || 1; dx /= l; dy /= l;
      sx = dx; sy = dy; nx = -dy; ny = dx; if (ny > 0) { nx = -nx; ny = -ny; } // n points "up", away from the ground
      hip = [o.x - sx * 0.2, o.y - sy * 0.2]; neck = [o.x + sx * 0.3, o.y + sy * 0.3];
      head = [neck[0] + sx * 0.19 + nx * 0.04, neck[1] + sy * 0.19 + ny * 0.04];
      const sp = o.pose === 'dead' ? 0.2 : 0.07;
      fa = [hip[0] - sx * 0.9 + nx * sp, hip[1] - sy * 0.9 + ny * sp];
      fb = [hip[0] - sx * 0.72 - nx * sp * 1.3, hip[1] - sy * 0.72 - ny * sp * 1.3];
      flare = 0.2; bendK = (sx * ny - sy * nx) > 0 ? 1 : -1;
    } else {
      let hipY = -0.93, lean = 0.05, a, b;
      if (o.pose === 'run') {
        const th = (Math.floor(o.phase * 8) / 8) * TAU; // stepped: eight drawings a stride
        a = [0.4 * Math.cos(th), -Math.max(0, Math.sin(th)) * 0.3]; b = [0.4 * Math.cos(th + 3.1416), -Math.max(0, Math.sin(th + 3.1416)) * 0.3];
        hipY += 0.06 * Math.abs(Math.cos(th)) - 0.03; lean = 0.16;
      } else if (o.pose === 'air') {
        if (o.vy < 0) { a = [-0.22, -0.34]; b = [0.2, -0.13]; } else { a = [-0.17, -0.04]; b = [0.24, -0.22]; }
        lean = 0.1;
      } else { a = [-0.17, 0]; b = [0.15, 0]; hipY += Math.floor((o.t || 0) * 2.5) % 2 ? 0.012 : 0; }
      hip = [o.x, o.y + hipY]; neck = [o.x + f * lean, o.y + hipY - 0.53];
      head = [neck[0] + f * 0.04, neck[1] - 0.19];
      fa = [o.x + f * a[0], o.y + a[1]]; fb = [o.x + f * b[0], o.y + b[1]];
      const l = Math.sqrt((neck[0] - hip[0]) ** 2 + (neck[1] - hip[1]) ** 2);
      sx = (neck[0] - hip[0]) / l; sy = (neck[1] - hip[1]) / l; nx = -f; ny = 0; // n = towards the back
      flare = Math.max(-0.05, Math.min(0.2, (o.vx || 0) * f * 0.026)) + (o.pose === 'air' ? 0.1 : 0); bendK = -f;
    }
    hip[0] += jit(1); hip[1] += jit(2); neck[0] += jit(3); neck[1] += jit(4); fa[0] += jit(5); fb[0] += jit(6);
    const W = bulky ? 1.28 : 1, fx = -nx, fy = -ny; // f* = front direction
    const lift = flat ? 0 : 0.085; // the ankle sits above the ground, the shoe reaches down to it
    const ka = ik(hip[0], hip[1], fa[0], fa[1] - lift, 0.48, 0.44, bendK), kb = ik(hip[0], hip[1], fb[0], fb[1] - lift, 0.48, 0.44, bendK);
    const back = [], front = [], accent = [];
    const leg = (k, into) => {
      seg(into, hip[0], hip[1], k[0], k[1], 0.25 * W, 0.18 * W); seg(into, k[0], k[1], k[2], k[3], 0.18 * W, 0.12 * W);
      // shoe: a wedge pointing forward
      const tx = flat ? fx : f, ty = flat ? fy : 0, ux = flat ? sx : 0, uy = flat ? sy : -1;
      const bx = k[2] - ux * lift, by = k[3] - uy * lift; // sole
      into.push({ t: 'poly', p: [bx - tx * 0.09, by - ty * 0.09, bx + tx * 0.25, by + ty * 0.25, bx + tx * 0.22 + ux * 0.07, by + ty * 0.22 + uy * 0.07, bx + tx * 0.05 + ux * 0.15, by + ty * 0.05 + uy * 0.15, bx - tx * 0.09 + ux * 0.13, by - ty * 0.09 + uy * 0.13] });
    };
    leg(ka, back); leg(kb, front);

    const tw = 0.22 * W, hw = 0.17 * W;
    if (!bulky) { // long coat: back panel trails with speed, cut into two tails
      front.push({ t: 'poly', p: [
        neck[0] + nx * tw, neck[1] + ny * tw,
        hip[0] + nx * (0.25 + flare * 0.5), hip[1] + ny * (0.25 + flare * 0.5),
        hip[0] - sx * 0.52 + nx * (0.3 + flare) + jit(7), hip[1] - sy * 0.52 + ny * (0.3 + flare) + jit(8),
        hip[0] - sx * 0.3 + nx * (0.13 + flare * 0.4), hip[1] - sy * 0.3 + ny * (0.13 + flare * 0.4),
        hip[0] - sx * 0.54 + nx * (0.03 + flare * 0.5) + jit(9), hip[1] - sy * 0.54 + ny * (0.03 + flare * 0.5),
        hip[0] - sx * 0.46 + fx * 0.14, hip[1] - sy * 0.46 + fy * 0.14,
        hip[0] + fx * hw, hip[1] + fy * hw,
        neck[0] + fx * tw, neck[1] + fy * tw] });
    } else { // short heavy jacket with square shoulders
      front.push({ t: 'poly', p: [neck[0] + nx * (tw + 0.05) + sx * 0.03, neck[1] + ny * (tw + 0.05) + sy * 0.03, hip[0] + nx * (hw + 0.06) - sx * 0.08, hip[1] + ny * (hw + 0.06) - sy * 0.08, hip[0] + fx * (hw + 0.07) - sx * 0.1, hip[1] + fy * (hw + 0.07) - sy * 0.1, neck[0] + fx * (tw + 0.04) + sx * 0.03, neck[1] + fy * (tw + 0.04) + sy * 0.03] });
    }
    front.push({ t: 'poly', p: [hip[0] + nx * hw, hip[1] + ny * hw, hip[0] + fx * hw, hip[1] + fy * hw, neck[0] + fx * tw, neck[1] + fy * tw, neck[0] + nx * tw, neck[1] + ny * tw] });
    seg(front, neck[0], neck[1], head[0], head[1], 0.17, 0.15);

    // head: skull, jaw and what sits on it
    const hr = bulky ? 0.165 : 0.15, up = flat ? [sx, sy] : [0, -1];
    const faceX = flat ? fx : f, faceY = flat ? fy : 0;
    front.push({ t: 'ell', x: head[0], y: head[1], rx: hr, ry: hr * 1.06 });
    front.push({ t: 'poly', p: [head[0] + faceX * hr * 0.55 + up[0] * 0.04, head[1] + faceY * hr * 0.55 + up[1] * 0.04, head[0] + faceX * (hr + 0.075) - up[0] * 0.05, head[1] + faceY * (hr + 0.075) - up[1] * 0.05, head[0] + faceX * hr * 0.75 - up[0] * 0.1, head[1] + faceY * hr * 0.75 - up[1] * 0.1, head[0] + faceX * hr * 0.35 - up[0] * 0.2, head[1] + faceY * hr * 0.35 - up[1] * 0.2, head[0] - faceX * 0.03 - up[0] * 0.12, head[1] - faceY * 0.03 - up[1] * 0.12] });
    if (kind === 'player') { // fedora with a red band, brim pulled low
      const bx = head[0] + up[0] * hr * 0.5, by = head[1] + up[1] * hr * 0.5;
      front.push({ t: 'line', w: 0.065, p: [bx - faceX * 0.3, by - faceY * 0.3 + up[1] * 0.0, bx + faceX * 0.36 - up[0] * 0.03, by + faceY * 0.36 - up[1] * 0.03] });
      front.push({ t: 'poly', p: [bx - faceX * 0.18, by - faceY * 0.18, bx - faceX * 0.15 + up[0] * 0.19, by - faceY * 0.15 + up[1] * 0.19, bx - faceX * 0.02 + up[0] * 0.23, by - faceY * 0.02 + up[1] * 0.23, bx + faceX * 0.14 + up[0] * 0.18, by + faceY * 0.14 + up[1] * 0.18, bx + faceX * 0.19, by + faceY * 0.19] });
      accent.push({ t: 'line', w: 0.05, c: RED, p: [bx - faceX * 0.17 + up[0] * 0.058, by - faceY * 0.17 + up[1] * 0.058, bx + faceX * 0.18 + up[0] * 0.058, by + faceY * 0.18 + up[1] * 0.058] });
      // turned-up collar
      front.push({ t: 'poly', p: [neck[0] + nx * 0.19, neck[1] + ny * 0.19, neck[0] + nx * 0.2 + sx * 0.17, neck[1] + ny * 0.2 + sy * 0.17, neck[0] + nx * 0.02 + sx * 0.06, neck[1] + ny * 0.02 + sy * 0.06] });
    } else if (kind === 'grunt') { // trilby with a gold band
      const bx = head[0] + up[0] * hr * 0.5, by = head[1] + up[1] * hr * 0.5;
      front.push({ t: 'line', w: 0.06, p: [bx - faceX * 0.27, by - faceY * 0.27, bx + faceX * 0.33, by + faceY * 0.33] });
      front.push({ t: 'poly', p: [bx - faceX * 0.17, by - faceY * 0.17, bx - faceX * 0.13 + up[0] * 0.2, by - faceY * 0.13 + up[1] * 0.2, bx - faceX * 0.0 + up[0] * 0.15, by + up[1] * 0.15, bx + faceX * 0.13 + up[0] * 0.19, by + faceY * 0.13 + up[1] * 0.19, bx + faceX * 0.18, by + faceY * 0.18] });
      accent.push({ t: 'line', w: 0.05, c: GOLD, p: [bx - faceX * 0.16 + up[0] * 0.055, by - faceY * 0.16 + up[1] * 0.055, bx + faceX * 0.17 + up[0] * 0.055, by + faceY * 0.17 + up[1] * 0.055] });
    } else { // flat cap with a short peak
      const bx = head[0] + up[0] * hr * 0.55, by = head[1] + up[1] * hr * 0.55;
      front.push({ t: 'poly', p: [bx - faceX * 0.19, by - faceY * 0.19, bx - faceX * 0.12 + up[0] * 0.12, by - faceY * 0.12 + up[1] * 0.12, bx + faceX * 0.12 + up[0] * 0.1, by + faceY * 0.12 + up[1] * 0.1, bx + faceX * 0.33, by + faceY * 0.33, bx + faceX * 0.3 - up[0] * 0.03, by + faceY * 0.3 - up[1] * 0.03] });
    }

    // arms and guns
    if (o.part === 'arms') { back.length = 0; front.length = 0; accent.length = 0; }
    const sh = [neck[0] - sx * 0.09, neck[1] - sy * 0.09];
    const arm = (hx, hy, into) => { const e = ik(sh[0], sh[1], hx, hy, 0.29, 0.28, (hx - sh[0]) >= 0 ? 1 : -1); seg(into, sh[0], sh[1], e[0], e[1], 0.17 * W, 0.13 * W); seg(into, e[0], e[1], e[2], e[3], 0.13 * W, 0.11); return e; };
    let ax = f, ay = 0;
    if (o.aim) { ax = o.aim[0]; ay = o.aim[1]; }
    let px = -ay, py = ax; if (py < 0) { px = -px; py = -py; } // perpendicular to the aim, pointing down
    const pistol = (h, into) => {
      into.push({ t: 'line', cap: 'butt', w: 0.115, p: [h[2] - ax * 0.05, h[3] - ay * 0.05, h[2] + ax * 0.33, h[3] + ay * 0.33] });
      into.push({ t: 'line', cap: 'butt', w: 0.1, p: [h[2] + px * 0.02, h[3] + py * 0.02, h[2] + px * 0.17 - ax * 0.04, h[3] + py * 0.17 - ay * 0.04] });
    };
    if (o.part !== 'body') {
    if (o.pose === 'dead') {
      arm(sh[0] + sx * 0.25 + nx * 0.45, sh[1] + sy * 0.25 + ny * 0.45, back); arm(sh[0] + sx * 0.45 - nx * 0.28, sh[1] + sy * 0.45 - ny * 0.28, front);
    } else if (bulky) {
      const reach = o.aim ? 0.33 : 0.2, gx = o.aim ? ax : f * 0.75, gy = o.aim ? ay : 0.66;
      const h1 = arm(sh[0] + gx * reach, sh[1] + gy * reach + 0.08, back), h2 = arm(sh[0] + gx * (reach + 0.27), sh[1] + gy * (reach + 0.27) + 0.08, front);
      front.push({ t: 'line', cap: 'butt', w: 0.105, p: [h1[2] - gx * 0.2, h1[3] - gy * 0.2, h2[2] + gx * 0.46, h2[3] + gy * 0.46] });
      front.push({ t: 'line', cap: 'butt', w: 0.17, p: [h1[2] - gx * 0.34, h1[3] - gy * 0.34, h1[2] - gx * 0.1, h1[3] - gy * 0.1] });
    } else if (o.aim) {
      if (kind === 'player') pistol(arm(sh[0] + ax * 0.47 - px * 0.13, sh[1] + ay * 0.47 - py * 0.13, back), back);
      else arm(hip[0] + nx * 0.12, hip[1] - sy * 0.04, back);
      pistol(arm(sh[0] + ax * 0.52 + px * 0.07, sh[1] + ay * 0.52 + py * 0.07, front), front);
    } else {
      arm(hip[0] + nx * 0.13, hip[1] + 0.03, back);
      const ha = arm(hip[0] + f * 0.22, hip[1] + 0.06, front); ax = f * 0.45; ay = 0.89; px = -f * 0.89; py = 0.45; pistol(ha, front);
    }

    }
    if (o.part === 'arms') { /* arms only */ } else if (kind === 'player') { // red scarf: band at the neck and a tail that trails
      accent.push({ t: 'line', cap: 'butt', w: 0.12, c: RED, p: [neck[0] + nx * 0.15 + sx * 0.02, neck[1] + ny * 0.15 + sy * 0.02, neck[0] + fx * 0.15 + sx * 0.05, neck[1] + fy * 0.15 + sy * 0.05] });
      const st = Math.floor((o.t || 0) * 8), sp = Math.min(1, (Math.abs(o.vx || 0) + Math.abs(o.vy || 0)) / 6);
      let tx = nx * (0.35 + sp * 0.6) + (flat ? -sx : 0), ty = ny * (0.35 + sp * 0.6) + (flat ? -sy : 0.75 * (1 - sp)) - (o.vy || 0) * 0.03;
      const tl = Math.sqrt(tx * tx + ty * ty) || 1; tx /= tl; ty /= tl;
      const b0 = [neck[0] + nx * 0.15 + sx * 0.03, neck[1] + ny * 0.15 + sy * 0.03], wv = i => Math.sin(st * 1.3 + i * 1.9) * 0.06 * (0.4 + sp);
      const q = (d, i) => [b0[0] + tx * d - ty * wv(i), b0[1] + ty * d + tx * wv(i)], p1 = q(0.2, 1), p2 = q(0.4, 2), p3 = q(0.58, 3);
      accent.push({ t: 'poly', c: RED, p: [b0[0] - ty * 0.055, b0[1] + tx * 0.055, p1[0] - ty * 0.05, p1[1] + tx * 0.05, p2[0] - ty * 0.04, p2[1] + tx * 0.04, p3[0], p3[1], p2[0] + ty * 0.04, p2[1] - tx * 0.04, p1[0] + ty * 0.05, p1[1] - tx * 0.05, b0[0] + ty * 0.055, b0[1] - tx * 0.055] });
    } else if (kind === 'grunt') { // gold tie
      const tx0 = neck[0] + fx * 0.15 - sx * 0.03, ty0 = neck[1] + fy * 0.15 - sy * 0.03;
      accent.push({ t: 'poly', c: GOLD, p: [tx0 + nx * 0.05, ty0 + ny * 0.05, tx0 + fx * 0.05, ty0 + fy * 0.05, tx0 + fx * 0.04 - sx * 0.2, ty0 + fy * 0.04 - sy * 0.2, tx0 - sx * 0.3, ty0 - sy * 0.3, tx0 + nx * 0.03 - sx * 0.2, ty0 + ny * 0.03 - sy * 0.2] });
    } else { // gold bandolier and belt
      accent.push({ t: 'line', cap: 'butt', w: 0.08, c: GOLD, p: [neck[0] + nx * tw, neck[1] + ny * tw, hip[0] + fx * hw + sx * 0.1, hip[1] + fy * hw + sy * 0.1] });
      accent.push({ t: 'line', cap: 'butt', w: 0.07, c: GOLD, p: [hip[0] + nx * (hw + 0.05) - sx * 0.04, hip[1] + ny * (hw + 0.05) - sy * 0.04, hip[0] + fx * (hw + 0.06) - sx * 0.04, hip[1] + fy * (hw + 0.06) - sy * 0.04] });
    }

    const body = o.flash ? PAPER : INK, rim = o.flash ? INK : (o.lit ? '#F0B45A' : PALE);
    ctx.save();
    if (o.alpha !== undefined) ctx.globalAlpha = o.alpha;
    const all = back.concat(front), hi = o.lit ? '#FFE9C2' : PAPER;
    traceAll(ctx, all);
    ctx.lineJoin = 'round';
    if (o.flash) { ctx.strokeStyle = INK; ctx.lineWidth = 0.12; ctx.stroke(); ctx.fillStyle = PAPER; ctx.fill(); }
    else {
      const tone = kind === 'player' ? '#6E7278' : (bulky ? '#4A4E54' : '#34373C');
      ctx.strokeStyle = hi; ctx.lineWidth = 0.19; ctx.stroke();   // off-white comic rim: lifts the figure off the night
      ctx.strokeStyle = INK; ctx.lineWidth = 0.1; ctx.stroke();   // ink outline
      ctx.fillStyle = hi; ctx.fill();                             // three hard tones: light, cloth, shadow
      ctx.save(); ctx.clip();
      ctx.translate(0.03, 0.04); traceAll(ctx, all); ctx.fillStyle = tone; ctx.fill();
      ctx.translate(0.06, 0.075); traceAll(ctx, all); ctx.fillStyle = INK; ctx.fill();
      ctx.restore();
      if (o.part === 'arms') { ctx.restore(); return; }
      const P = (a2, b2) => [head[0] + faceX * a2 + up[0] * b2, head[1] + faceY * a2 + up[1] * b2];
      const poly = pts => { ctx.beginPath(); pts.forEach((q, i) => i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1])); ctx.closePath(); };
      const stroke = (pts, w2, c) => { ctx.strokeStyle = c; ctx.lineWidth = w2; ctx.lineCap = 'round'; ctx.beginPath(); pts.forEach((q, i) => i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1])); ctx.stroke(); };
      // face under the brim: lit cheek and jaw, eye lost in the hat's shadow
      poly([P(hr * 0.05, 0.035), P(hr + 0.04, 0.02), P(hr + 0.095, -0.05), P(hr * 0.95, -0.075), P(hr * 0.9, -0.15), P(hr * 0.25, -0.185), P(-0.03, -0.07)]);
      ctx.fillStyle = hi; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 0.022; ctx.stroke();
      poly([P(hr * 0.05, 0.035), P(hr + 0.04, 0.02), P(hr * 0.9, -0.035), P(hr * 0.2, -0.03)]); ctx.fillStyle = INK; ctx.fill();
      poly([P(-0.03, -0.07), P(hr * 0.05, 0.035), P(hr * 0.3, -0.03), P(hr * 0.38, -0.18), P(hr * 0.25, -0.185)]); ctx.fill(); // sideburn and the shadow of the collar
      stroke([P(hr * 0.62, -0.115), P(hr * 0.92, -0.108)], 0.02, INK);
      // cloth: closure, belt, folds. Each line in ink, with a hair of light beside it so it shows on the black side too
      const two = pts => { stroke(pts.map(q => [q[0] - 0.02, q[1] - 0.022]), 0.016, 'rgba(234,230,223,0.75)'); stroke(pts, 0.032, INK); };
      const B = (a2, b2, c2) => [hip[0] + sx * a2 + fx * b2 + nx * (c2 || 0), hip[1] + sy * a2 + fy * b2 + ny * (c2 || 0)];
      two([B(0.1, hw * 0.95), B(0.1, 0, hw * 0.95)]);
      if (!bulky) {
        two([[neck[0] + fx * 0.05 - sx * 0.03, neck[1] + fy * 0.05 - sy * 0.03], B(0.12, 0.08), B(-0.4, 0.1)]);
        two([B(0.02, 0, 0.12), B(-0.42, 0, 0.17 + flare * 0.6)]); two([B(-0.05, 0, 0.02), B(-0.36, 0, 0.0 + flare * 0.3)]);
        poly([[neck[0] + fx * 0.14 - sx * 0.02, neck[1] + fy * 0.14 - sy * 0.02], [neck[0] + fx * 0.05 - sx * 0.2, neck[1] + fy * 0.05 - sy * 0.2], [neck[0] + fx * 0.2 - sx * 0.15, neck[1] + fy * 0.2 - sy * 0.15]]); ctx.fillStyle = hi; ctx.fill(); ctx.strokeStyle = INK; ctx.lineWidth = 0.02; ctx.stroke(); // lapel
        for (const t of [0.3, 0.2]) { const q = B(t, 0.1); ctx.fillStyle = INK; ctx.beginPath(); ctx.arc(q[0], q[1], 0.02, 0, TAU); ctx.fill(); }
      } else two([[neck[0] + fx * 0.02 - sx * 0.05, neck[1] + fy * 0.02 - sy * 0.05], B(0.12, 0.04)]);
      two([[sh[0] + nx * 0.06 - sx * 0.02, sh[1] + ny * 0.06 - sy * 0.02], [sh[0] + nx * 0.1 - sx * 0.2, sh[1] + ny * 0.1 - sy * 0.2]]);
    }
    for (const a of accent) { tracePath(ctx, a); if (a.t === 'line') { ctx.strokeStyle = a.c; ctx.lineWidth = a.w; ctx.lineCap = a.cap || 'butt'; ctx.stroke(); } else { ctx.fillStyle = a.c; ctx.fill(); } }
    ctx.restore();
  }

  // ---------- hand-inked primitives for the background sheets ----------
  function inkLine(g, r, x1, y1, x2, y2, w, wob) {
    const len = Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2), n = Math.max(2, Math.ceil(len / 0.45));
    const px = -(y2 - y1) / (len || 1), py = (x2 - x1) / (len || 1), k = wob === undefined ? 0.018 : wob;
    g.lineCap = 'round'; g.lineJoin = 'round';
    let lx = x1, ly = y1;
    for (let i = 1; i <= n; i++) {
      const t = i / n, o = i === n ? 0 : (r() - 0.5) * 2 * k;
      const x = x1 + (x2 - x1) * t + px * o, y = y1 + (y2 - y1) * t + py * o;
      g.lineWidth = w * (0.75 + r() * 0.5); // pressure varies along the stroke
      g.beginPath(); g.moveTo(lx, ly); g.lineTo(x, y); g.stroke();
      lx = x; ly = y;
    }
  }
  function inkRect(g, r, x, y, w, h, lw, wob) { inkLine(g, r, x, y, x + w, y, lw, wob); inkLine(g, r, x + w, y, x + w, y + h, lw, wob); inkLine(g, r, x + w, y + h, x, y + h, lw, wob); inkLine(g, r, x, y + h, x, y, lw, wob); }
  function hatch(g, r, x, y, w, h, gap, lw, slope) { // diagonal hatching clipped to a rectangle
    g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip();
    const s = slope === undefined ? 1 : slope;
    for (let d = -h; d < w + h; d += gap * (0.8 + r() * 0.4)) inkLine(g, r, x + d, y + h, x + d + h * s, y, lw, 0.01);
    g.restore();
  }
  // closed shape whose edges wander like a loaded brush
  function rough(g, r, pts, k) {
    g.beginPath();
    const n = pts.length / 2;
    for (let i = 0; i < n; i++) {
      const x1 = pts[i * 2], y1 = pts[i * 2 + 1], x2 = pts[((i + 1) % n) * 2], y2 = pts[((i + 1) % n) * 2 + 1];
      const len = Math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2) || 1, st = Math.max(1, Math.ceil(len / 0.3)), px = -(y2 - y1) / len, py = (x2 - x1) / len;
      for (let j = 0; j < st; j++) { const t = j / st, o = j ? (r() - 0.5) * 2 * k : 0, x = x1 + (x2 - x1) * t + px * o, y = y1 + (y2 - y1) * t + py * o; if (!i && !j) g.moveTo(x, y); else g.lineTo(x, y); }
    }
    g.closePath();
  }
  function blot(g, r, x, y, s) { // ink blot with a few flung drops
    g.beginPath();
    for (let i = 0; i < 10; i++) { const a = i / 10 * TAU, rr = s * (0.6 + r() * 0.6); if (i) g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); else g.moveTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
    g.closePath(); g.fill();
    for (let i = 0; i < 5; i++) { const a = r() * TAU, d = s * (1.3 + r() * 2.2), z = s * (0.12 + r() * 0.25); g.beginPath(); g.arc(x + Math.cos(a) * d, y + Math.sin(a) * d, z, 0, TAU); g.fill(); }
  }
  function cross(g, r, x, y, w, h, gap, lw) { hatch(g, r, x, y, w, h, gap, lw, 0.7); hatch(g, r, x, y, w, h, gap * 1.25, lw, -0.7); }
  function steam(g, r, x, y, n) { // a plume of steam: stacked puffs under one ink outline
    const ps = [];
    for (let i = 0; i < n; i++) ps.push([x + (r() - 0.5) * 0.2 + i * 0.1, y - i * 0.3, 0.13 + i * 0.05]);
    g.fillStyle = INK; for (const p of ps) { g.beginPath(); g.arc(p[0], p[1], p[2] + 0.035, 0, TAU); g.fill(); }
    g.fillStyle = PAPER; for (const p of ps) { g.beginPath(); g.arc(p[0], p[1], p[2], 0, TAU); g.fill(); }
    g.strokeStyle = INK; for (const p of ps) { g.lineWidth = 0.022; g.beginPath(); g.arc(p[0] + 0.02, p[1] + 0.03, p[2] * 0.6, 0.3, 1.9); g.stroke(); }
  }
  function neon(g, x, y, word) { // vertical neon sign: the one loud colour in the street
    const h = word.length * 0.58 + 0.34;
    g.fillStyle = INK; g.fillRect(x - 0.46, y - 0.04, 0.92, h + 0.08);
    g.strokeStyle = '#6B1512'; g.lineWidth = 0.09; g.strokeRect(x - 0.37, y + 0.05, 0.74, h - 0.1);
    g.strokeStyle = RED; g.lineWidth = 0.04; g.strokeRect(x - 0.37, y + 0.05, 0.74, h - 0.1);
    g.font = "400 0.6px Bangers,Impact,sans-serif"; g.textAlign = 'center'; g.textBaseline = 'middle';
    for (let i = 0; i < word.length; i++) { g.fillStyle = RED; g.fillText(word[i], x, y + 0.5 + i * 0.58); }
    g.fillStyle = INK; g.fillRect(x - 0.6, y + 0.3, 0.16, 0.06); g.fillRect(x - 0.6, y + h - 0.4, 0.16, 0.06); // brackets
  }
  function sheet(wm, hm, m, dpr) {
    const c = document.createElement('canvas');
    c.width = Math.ceil(wm * m * dpr); c.height = Math.ceil(hm * m * dpr);
    const g = c.getContext('2d'); g.scale(m * dpr, m * dpr);
    c.wm = wm; c.hm = hm;
    return [c, g];
  }

  // soft round glow, used for lamps and lit windows
  function glow(g, x, y, rad, col, a) {
    if (mono) return; // noir has no soft light: every light is a hard shape
    const gr = g.createRadialGradient(x, y, 0, x, y, rad);
    gr.addColorStop(0, `rgba(${col},${a})`); gr.addColorStop(0.35, `rgba(${col},${a * 0.45})`); gr.addColorStop(1, `rgba(${col},0)`);
    g.fillStyle = gr; g.fillRect(x - rad, y - rad, rad * 2, rad * 2);
  }
  const AMB = '242,169,34', FOGC = '150,156,162';

  // far layer: night sky fading into mist, cloud, two rows of skyline lost in the haze, wires. Opaque, wraps.
  const FAR_W = 36;
  function farSheet(m, dpr, slow) {
    const [c, g] = sheet(FAR_W, 12, m, dpr), r = rng(77);
    if (mono) { // black sky, two flat bands of city light with torn, hatched edges
      g.fillStyle = INK; g.fillRect(0, 0, FAR_W, 12);
      g.fillStyle = '#26282C'; rough(g, r, [-1, 4.6, FAR_W + 1, 4.6, FAR_W + 1, 12, -1, 12], 0.2); g.fill();
      g.fillStyle = '#4B4F55'; rough(g, r, [-1, 6.9, FAR_W + 1, 6.9, FAR_W + 1, 12, -1, 12], 0.2); g.fill();
      g.strokeStyle = INK; hatch(g, r, 0, 4.5, FAR_W, 0.9, 0.2, 0.03, 0.8); g.strokeStyle = '#26282C'; hatch(g, r, 0, 6.8, FAR_W, 0.9, 0.22, 0.03, 0.8);
      g.strokeStyle = 'rgba(234,230,223,0.2)';
      for (let k = 0; k < 30; k++) { const x = r() * FAR_W, y = 0.5 + r() * 3.6, l = 1.5 + r() * 4.5, d = (r() - 0.5) * 0.15; for (const o of [0, -FAR_W, FAR_W]) inkLine(g, r, x + o, y, x + o + l, y + d, 0.022, 0.02); }
    } else {
      const sky = g.createLinearGradient(0, 0, 0, 10);
      sky.addColorStop(0, '#15171B'); sky.addColorStop(0.45, '#2E3238'); sky.addColorStop(1, '#868C92');
      g.fillStyle = sky; g.fillRect(0, 0, FAR_W, 12);
    }
    if (!mono) for (let k = 0; k < 16; k++) { const x = r() * FAR_W, y = 0.8 + r() * 3.6, w = 3 + r() * 5; g.fillStyle = 'rgba(120,126,133,0.12)'; g.beginPath(); g.ellipse(x, y, w, 0.5 + r() * 0.5, 0, 0, TAU); g.fill(); g.beginPath(); g.ellipse(x - FAR_W, y, w, 0.7, 0, 0, TAU); g.fill(); g.beginPath(); g.ellipse(x + FAR_W, y, w, 0.7, 0, 0, TAU); g.fill(); }
    const row = (col, lo, hi, wmin, wmax, lit, line) => {
      let x = 0;
      while (x < FAR_W) {
        let w = wmin + r() * (wmax - wmin); if (x + w > FAR_W - wmin) w = FAR_W - x;
        const top = lo + r() * (hi - lo);
        g.fillStyle = col; g.fillRect(x - 0.02, top, w + 0.04, 12 - top);
        g.strokeStyle = line; inkLine(g, r, x, top, x + w, top, 0.03, 0.006);
        if (r() < 0.6) hatch(g, r, x + w * 0.55, top, w * 0.45, 12 - top, 0.22, 0.014, -1);
        for (let wy = top + 0.45; wy < 11; wy += 0.75) for (let wx = x + 0.35; wx < x + w - 0.4; wx += 0.62) if (r() < lit) { g.fillStyle = mono ? 'rgba(225,223,216,0.7)' : `rgba(${AMB},0.75)`; g.fillRect(wx, wy, 0.2, 0.3); }
        const t = r();
        if (t < 0.3 && w > 2.4) { // water tower
          const tx = x + w * 0.25; g.fillStyle = col;
          g.fillRect(tx, top - 1.35, 0.85, 0.75); g.beginPath(); g.moveTo(tx - 0.08, top - 1.35); g.lineTo(tx + 0.42, top - 1.72); g.lineTo(tx + 0.93, top - 1.35); g.closePath(); g.fill();
          inkLine(g, r, tx + 0.08, top, tx + 0.14, top - 0.6, 0.028); inkLine(g, r, tx + 0.77, top, tx + 0.71, top - 0.6, 0.028); inkRect(g, r, tx, top - 1.35, 0.85, 0.75, 0.022, 0.004);
        } else if (t < 0.55) { inkLine(g, r, x + w * 0.7, top, x + w * 0.7, top - 1.2, 0.022); inkLine(g, r, x + w * 0.7 - 0.18, top - 0.85, x + w * 0.7 + 0.18, top - 0.85, 0.018); }
        else if (t < 0.75) { g.fillStyle = col; g.fillRect(x + w * 0.45, top - 0.5, 0.38, 0.5); }
        x += w;
      }
    };
    if (mono) { row('#17181B', 4.2, 6.4, 2.0, 4.2, 0.05, '#8D9096'); row(INK, 5.8, 8.2, 2.4, 4.8, 0.1, PAPER); steam(g, r, 7.5, 6.6, 6); steam(g, r, 25, 7.0, 5); neon(g, 13.2, 6.2, 'JAZZ'); neon(g, 30.5, 6.6, 'BAR'); } // black blocks against the pale mist, a white line where the light catches the roof
    else { row('#6F757C', 4.2, 6.4, 2.0, 4.2, 0.06, '#5A6067'); row('#474C54', 5.8, 8.2, 2.4, 4.8, 0.12, '#2C3036'); }
    if (!mono) { const haze = g.createLinearGradient(0, 6, 0, 12); haze.addColorStop(0, `rgba(${FOGC},0)`); haze.addColorStop(1, `rgba(${FOGC},0.55)`); g.fillStyle = haze; g.fillRect(0, 6, FAR_W, 6); }
    g.strokeStyle = mono ? 'rgba(234,230,223,0.4)' : INK;
    for (const [x1, y1, x2, y2, sag] of [[0, 1.6, 15, 2.6, 0.9], [15, 2.6, 36, 1.6, 1.2], [3, 0.2, 24, 3.4, 0.5], [20, 0.4, 36, 2.9, 0.7]]) {
      g.lineWidth = 0.026; g.beginPath();
      for (let i = 0; i <= 40; i++) { const t = i / 40, x = x1 + (x2 - x1) * t, y = y1 + (y2 - y1) * t + Math.sin(t * 3.1416) * sag; if (i) g.lineTo(x, y); else g.moveTo(x, y); }
      g.stroke();
    }
    for (let k = 0; k < 4000; k++) { g.fillStyle = r() < 0.5 ? 'rgba(0,0,0,0.10)' : 'rgba(255,255,255,0.05)'; const z = 0.015 + r() * 0.04; g.fillRect(r() * FAR_W, r() * 12, z, z); }
    if (slow) { g.fillStyle = mono ? 'rgba(8,8,10,0.45)' : 'rgba(217,37,37,0.26)'; g.fillRect(0, 0, FAR_W, 12); } // bullet time washes the night red
    return c;
  }

  // tenement wall: charcoal or red brick, fire escape, windows (a few lit amber), doorway with a lamp
  function facade(g, r, x, w, top) {
    const red = r() < 0.4;
    const base = mono ? (red ? '#474B52' : SLATE) : (red ? BRICK : SLATE), lite = mono ? (red ? '#5A5F66' : '#3C4149') : (red ? BRICK2 : '#3C4149'), mortar = mono ? (red ? '#2A2D32' : '#1F2226') : (red ? '#3A1614' : '#1F2226');
    g.fillStyle = base; g.fillRect(x, top, w, WALL - top);
    g.strokeStyle = mortar; g.lineWidth = 0.018; g.beginPath();
    for (let y = top + 0.28, k = 0; y < WALL; y += 0.28, k++) {
      g.moveTo(x, y + (r() - 0.5) * 0.01); g.lineTo(x + w, y + (r() - 0.5) * 0.01);
      for (let bx = x + (k & 1 ? 0.3 : 0.6); bx < x + w; bx += 0.6) if (r() < 0.75) { g.moveTo(bx, y); g.lineTo(bx, y + 0.28); }
    }
    g.stroke();
    g.fillStyle = lite;
    for (let k = 0; k < w * 6; k++) g.fillRect(x + Math.floor(r() * (w / 0.6)) * 0.6 + 0.03, top + 0.28 + Math.floor(r() * ((WALL - 0.3 - top) / 0.28)) * 0.28 + 0.03, 0.54, 0.22);
    // cast shadow down the right side and under the cornice
    g.fillStyle = 'rgba(11,11,13,0.6)'; g.beginPath(); g.moveTo(x + w * 0.62, top); g.lineTo(x + w, top); g.lineTo(x + w, WALL); g.lineTo(x + w * 0.42, WALL); g.closePath(); g.fill();
    g.strokeStyle = INK; hatch(g, r, x + w * 0.28, top, w * 0.4, WALL - top, 0.3, 0.022, 0.35);
    g.fillStyle = DEEP; g.fillRect(x - 0.12, top - 0.05, w + 0.24, 0.42);
    g.fillStyle = INK; g.fillRect(x - 0.12, top + 0.37, w + 0.24, 0.1);
    g.strokeStyle = MIST; inkLine(g, r, x - 0.1, top - 0.03, x + w + 0.1, top - 0.03, 0.035, 0.004); g.strokeStyle = INK;
    inkLine(g, r, x, top, x, WALL, 0.08, 0.006); inkLine(g, r, x + w, top, x + w, WALL, 0.08, 0.006);
    const cols = Math.max(2, Math.floor((w - 1.2) / 2.1)), gap = (w - cols * 1.0) / (cols + 1), lits = [];
    for (let wy = top + 1.0; wy < 8.4; wy += 2.2) for (let i = 0; i < cols; i++) {
      const wx = x + gap + i * (1.0 + gap), lit = r() < 0.16;
      g.fillStyle = lit ? AMBER : DEEP; g.fillRect(wx, wy, 1.0, 1.45);
      if (lit) { g.fillStyle = 'rgba(255,240,200,0.5)'; g.fillRect(wx + 0.08, wy + 0.08, 0.84, 0.5); lits.push([wx + 0.5, wy + 0.7]); }
      g.strokeStyle = lit ? INK : MIST; g.lineWidth = 0.05; g.strokeRect(wx, wy, 1.0, 1.45);
      g.beginPath(); g.moveTo(wx + 0.5, wy); g.lineTo(wx + 0.5, wy + 1.45); g.moveTo(wx, wy + 0.72); g.lineTo(wx + 1.0, wy + 0.72); g.stroke();
      g.fillStyle = MIST; g.fillRect(wx - 0.1, wy + 1.45, 1.2, 0.09);
      g.fillStyle = INK; g.fillRect(wx - 0.1, wy + 1.54, 1.2, 0.07);
    }
    const fxp = x + gap * 0.5, fw = 1.0 + gap;
    g.strokeStyle = INK; g.fillStyle = INK;
    for (let wy = top + 2.5, k = 0; wy < 9.0; wy += 2.2, k++) {
      g.fillRect(fxp - 0.1, wy, fw + 0.2, 0.1);
      inkLine(g, r, fxp - 0.1, wy - 0.75, fxp + fw + 0.1, wy - 0.75, 0.04, 0.003);
      for (let px = fxp - 0.08; px <= fxp + fw + 0.1; px += 0.22) inkLine(g, r, px, wy, px, wy - 0.75, 0.02, 0.002);
      if (wy + 2.2 < 9.2) { const a = k & 1 ? fxp : fxp + fw, b = k & 1 ? fxp + fw : fxp; inkLine(g, r, a, wy + 0.09, b, wy + 2.2, 0.055, 0.004); inkLine(g, r, a, wy - 0.5, b, wy + 1.6, 0.028, 0.004); }
    }
    inkLine(g, r, x + w - 0.5, top + 0.4, x + w - 0.5, WALL, 0.07, 0.004);
    const dx = x + w * 0.55;
    g.fillStyle = DEEP; g.fillRect(dx, 8.5, 1.25, 2.05); g.strokeStyle = MIST; g.lineWidth = 0.04; g.strokeRect(dx, 8.5, 1.25, 2.05);
    g.fillStyle = INK; g.fillRect(dx - 0.2, 8.22, 1.65, 0.2);
    // lamp over the doorway: a pool of amber on wet brick
    const lx = dx + 0.62, ly = 7.75;
    if (mono) { // the lamp gives the wall its colour back: red brick shows red, grey brick warms up, and only inside the light
      g.save(); g.beginPath(); g.rect(x, top, w, WALL - top); g.clip();
      g.globalCompositeOperation = 'color';
      const cg = g.createRadialGradient(lx, ly + 1.2, 0.2, lx, ly + 1.2, 3.9), col = red ? '190,52,40' : '205,140,60';
      cg.addColorStop(0, `rgba(${col},1)`); cg.addColorStop(0.55, `rgba(${col},0.75)`); cg.addColorStop(1, `rgba(${col},0)`);
      g.fillStyle = cg; g.fillRect(lx - 4, ly - 2.8, 8, 8);
      g.restore();
    }
    glow(g, lx, ly + 0.5, 3.6, AMB, 0.42);
    g.fillStyle = `rgba(${AMB},0.16)`; g.beginPath(); g.moveTo(lx - 0.25, ly); g.lineTo(lx + 0.25, ly); g.lineTo(lx + 1.9, WALL); g.lineTo(lx - 1.9, WALL); g.closePath(); g.fill();
    g.fillStyle = INK; g.beginPath(); g.moveTo(lx - 0.34, ly); g.lineTo(lx + 0.34, ly); g.lineTo(lx + 0.14, ly - 0.24); g.lineTo(lx - 0.14, ly - 0.24); g.closePath(); g.fill(); g.fillRect(lx - 0.03, ly - 0.5, 0.06, 0.28);
    g.fillStyle = '#FFE9B8'; g.beginPath(); g.ellipse(lx, ly + 0.05, 0.2, 0.09, 0, 0, TAU); g.fill();
    for (const [gx, gy] of lits) glow(g, gx, gy, 1.5, AMB, 0.3);
  }

  // noir wall: flat tone, bricks only where the plaster has gone, a plane of solid black shadow, hard light from the lamp
  function facadeNoir(g, r, x, w, top) {
    const red = r() < 0.4, H = WALL - top, dx = x + w * 0.55, lx = dx + 0.62, ly = 7.75;
    const cone = () => { g.beginPath(); g.moveTo(lx - 0.3, ly); g.lineTo(lx + 0.3, ly); g.lineTo(lx + 2.4, WALL); g.lineTo(lx - 2.4, WALL); g.closePath(); };
    g.fillStyle = '#585C62'; g.fillRect(x, top, w, H);
    const patch = [];
    for (let k = 0; k < Math.ceil(w * 1.1); k++) patch.push([x + r() * w, top + 0.6 + r() * (H - 0.6), 0.8 + r() * 1.5, 0.5 + r() * 1.0]);
    const bare = (bx, by) => { for (const p of patch) { const ax = (bx - p[0]) / p[2], ay = (by - p[1]) / p[3]; if (ax * ax + ay * ay < 1) return true; } return false; };
    g.lineWidth = 0.024; g.strokeStyle = INK;
    for (let y = top + 0.28, k = 0; y < WALL - 0.2; y += 0.28, k++) for (let bx = x + (k & 1 ? -0.3 : 0); bx < x + w; bx += 0.6) {
      if (!bare(bx + 0.3, y + 0.14)) continue;
      const t = r(); g.fillStyle = t < 0.3 ? '#80858B' : (t < 0.55 ? '#3C3F44' : '#6A6E74');
      const jx = (r() - 0.5) * 0.02, jy = (r() - 0.5) * 0.02; g.fillRect(bx + 0.02 + jx, y + 0.02 + jy, 0.56, 0.24); g.strokeRect(bx + 0.02 + jx, y + 0.02 + jy, 0.56, 0.24);
    }
    g.save(); g.beginPath(); g.rect(x, top, w, H); g.clip();
    // plaster: scratches, hatched damp patches, cracks
    for (let k = 0; k < w * 0.7; k++) hatch(g, r, x + r() * w, top + r() * H, 0.6 + r() * 1.2, 0.4 + r() * 0.8, 0.09, 0.018, 0.8);
    for (let k = 0; k < w * 0.5; k++) { let cx = x + r() * w, cy = top + r() * H; for (let i = 0; i < 5; i++) { const nx2 = cx + (r() - 0.5) * 0.5, ny2 = cy + 0.15 + r() * 0.35; inkLine(g, r, cx, cy, nx2, ny2, 0.025, 0.01); cx = nx2; cy = ny2; } }
    g.strokeStyle = 'rgba(234,230,223,0.3)'; for (let k = 0; k < w * 1.2; k++) { const sx = x + r() * w, sy = top + r() * H; inkLine(g, r, sx, sy, sx + 0.3 + r() * 0.6, sy + (r() - 0.5) * 0.05, 0.016, 0.004); }
    // hard light: the lamp cuts a bright cone out of the wall; red brick is red only there
    cone();
    if (red) { g.globalCompositeOperation = 'color'; g.fillStyle = 'rgb(176,34,28)'; g.fill(); g.globalCompositeOperation = 'source-over'; g.fillStyle = 'rgba(234,230,223,0.12)'; g.fill(); }
    else { g.fillStyle = 'rgba(234,230,223,0.42)'; g.fill(); }
    g.save(); cone(); g.clip(); g.strokeStyle = 'rgba(8,8,10,0.55)'; hatch(g, r, lx - 2.4, ly, 1.3, WALL - ly, 0.11, 0.02, -0.75); hatch(g, r, lx + 1.1, ly, 1.3, WALL - ly, 0.11, 0.02, 0.75); g.restore(); // the cone's edges feather into hatching
    // the upper floors drop into the night in two steps of cross-hatching
    g.strokeStyle = INK; cross(g, r, x, top, w, H * 0.3, 0.1, 0.03); hatch(g, r, x, top + H * 0.3, w, H * 0.22, 0.15, 0.026, 0.7);
    // shadow plane: solid ink with a brushed edge, hatching where it breaks up
    hatch(g, r, x + w * 0.36, top, w * 0.28, H, 0.14, 0.032, 0.2 * w / H);
    g.fillStyle = INK; rough(g, r, [x + w * 0.64, top, x + w + 0.3, top, x + w + 0.3, WALL, x + w * 0.44, WALL], 0.07); g.fill();
    g.strokeStyle = 'rgba(234,230,223,0.16)'; g.lineWidth = 0.02; g.beginPath();
    for (let y = top + 0.56; y < WALL; y += 0.56) for (let bx = x + w * 0.5; bx < x + w; bx += 0.6) if (r() < 0.2 && bx > x + w * (0.66 - 0.2 * (y - top) / H)) { g.moveTo(bx, y); g.lineTo(bx + 0.5, y); g.moveTo(bx, y); g.lineTo(bx, y - 0.28); }
    g.stroke();
    g.fillStyle = INK; for (let k = 0; k < 3; k++) blot(g, r, x + r() * w * 0.5, top + H * (0.35 + r() * 0.6), 0.05 + r() * 0.06);
    g.restore();
    // cornice and corners
    g.fillStyle = INK; g.fillRect(x - 0.14, top - 0.06, w + 0.28, 0.52);
    g.strokeStyle = PAPER; inkLine(g, r, x - 0.12, top - 0.04, x + w * 0.66, top - 0.04, 0.05, 0.005);
    for (let bx = x + 0.2; bx < x + w * 0.64; bx += 0.5) { g.fillStyle = PALE; g.fillRect(bx, top + 0.3, 0.22, 0.1); }
    g.strokeStyle = INK; inkLine(g, r, x, top, x, WALL, 0.12, 0.008); inkLine(g, r, x + w, top, x + w, WALL, 0.12, 0.008);
    g.strokeStyle = PAPER; inkLine(g, r, x + 0.08, top + 0.5, x + 0.08, WALL, 0.03, 0.005);
    // windows: black glass in white frames, a few lit, rain streaks under the sills
    const cols = Math.max(2, Math.floor((w - 1.2) / 2.1)), gap = (w - cols * 1.0) / (cols + 1);
    for (let wy = top + 1.0; wy < 8.4; wy += 2.2) for (let i = 0; i < cols; i++) {
      const wx = x + gap + i * (1.0 + gap), lit = r() < 0.14;
      g.fillStyle = INK; g.fillRect(wx - 0.09, wy - 0.09, 1.18, 1.63);
      g.fillStyle = lit ? PAPER : INK; g.fillRect(wx, wy, 1.0, 1.45);
      if (lit) { g.fillStyle = INK; g.beginPath(); g.moveTo(wx, wy + 1.45); g.lineTo(wx, wy + 0.75); g.lineTo(wx + 0.34, wy + 0.5); g.lineTo(wx + 0.42, wy + 1.45); g.closePath(); g.fill(); g.strokeStyle = INK; hatch(g, r, wx, wy, 1.0, 0.5, 0.1, 0.02, 0.6); } // a curtain and its shadow
      else { g.strokeStyle = 'rgba(234,230,223,0.55)'; g.lineWidth = 0.028; g.beginPath(); g.moveTo(wx + 0.12, wy + 0.5); g.lineTo(wx + 0.38, wy + 0.14); g.moveTo(wx + 0.2, wy + 0.6); g.lineTo(wx + 0.3, wy + 0.46); g.moveTo(wx + 0.62, wy + 1.3); g.lineTo(wx + 0.88, wy + 0.94); g.stroke(); }
      g.strokeStyle = lit ? INK : PAPER; g.lineWidth = 0.06; g.strokeRect(wx, wy, 1.0, 1.45);
      g.beginPath(); g.moveTo(wx + 0.5, wy); g.lineTo(wx + 0.5, wy + 1.45); g.moveTo(wx, wy + 0.72); g.lineTo(wx + 1.0, wy + 0.72); g.stroke();
      g.fillStyle = PAPER; g.fillRect(wx - 0.12, wy + 1.45, 1.24, 0.08);
      g.fillStyle = INK; g.fillRect(wx - 0.12, wy + 1.53, 1.24, 0.13);
      g.strokeStyle = INK; for (let d = 0; d < 3; d++) { const sx = wx + r() * 1.0; inkLine(g, r, sx, wy + 1.66, sx, wy + 1.9 + r() * 0.7, 0.03, 0.004); }
    }
    // wrought-iron fire escape: every bar drawn twice, white then black, so it reads on the light plane and on the black one
    const fxp = x + gap * 0.5, fw = 1.0 + gap;
    const bar = (x1, y1, x2, y2, lw) => { g.strokeStyle = 'rgba(234,230,223,0.8)'; g.lineWidth = lw * 0.5; g.beginPath(); g.moveTo(x1 - 0.035, y1 - 0.035); g.lineTo(x2 - 0.035, y2 - 0.035); g.stroke(); g.strokeStyle = INK; inkLine(g, r, x1, y1, x2, y2, lw, 0.003); };
    for (let wy = top + 2.5, k = 0; wy < 9.0; wy += 2.2, k++) {
      g.fillStyle = PAPER; g.fillRect(fxp - 0.14, wy - 0.04, fw + 0.28, 0.05); g.fillStyle = INK; g.fillRect(fxp - 0.14, wy, fw + 0.28, 0.14);
      bar(fxp - 0.14, wy - 0.8, fxp + fw + 0.14, wy - 0.8, 0.06); bar(fxp - 0.14, wy - 0.4, fxp + fw + 0.14, wy - 0.4, 0.028);
      for (let px = fxp - 0.1; px <= fxp + fw + 0.12; px += 0.2) { bar(px, wy, px, wy - 0.8, 0.026); g.strokeStyle = INK; g.lineWidth = 0.02; g.beginPath(); g.arc(px + 0.1, wy - 0.6, 0.07, 0, TAU); g.stroke(); } // scrollwork
      for (const bx of [fxp + 0.1, fxp + fw - 0.1]) { g.fillStyle = INK; g.beginPath(); g.moveTo(bx - 0.05, wy + 0.14); g.lineTo(bx + 0.3, wy + 0.14); g.lineTo(bx - 0.05, wy + 0.5); g.closePath(); g.fill(); } // brackets
      if (wy + 2.2 < 9.2) { const a = k & 1 ? fxp : fxp + fw, b2 = k & 1 ? fxp + fw : fxp; bar(a, wy + 0.1, b2, wy + 2.2, 0.075); bar(a, wy - 0.5, b2, wy + 1.6, 0.032); for (let t = 0.12; t < 1; t += 0.14) bar(a + (b2 - a) * t, wy + 0.1 + 2.1 * t, a + (b2 - a) * t, wy + 0.1 + 2.1 * t - 0.2, 0.03); }
    }
    bar(x + w - 0.5, top + 0.45, x + w - 0.5, WALL, 0.09);
    if (r() < 0.45) neon(g, x + w * 0.83, top + 3.0, r() < 0.5 ? 'HOTEL' : 'JAZZ');
    // doorway and its lamp
    g.fillStyle = INK; g.fillRect(dx - 0.08, 8.42, 1.41, 2.13); g.strokeStyle = PAPER; g.lineWidth = 0.055; g.strokeRect(dx, 8.5, 1.25, 2.05);
    g.strokeStyle = 'rgba(234,230,223,0.5)'; g.lineWidth = 0.03; g.strokeRect(dx + 0.2, 8.72, 0.85, 0.7); g.strokeRect(dx + 0.2, 9.6, 0.85, 0.75);
    g.fillStyle = PAPER; g.fillRect(dx + 1.0, 9.5, 0.1, 0.06);
    g.fillStyle = INK; g.fillRect(dx - 0.22, 8.18, 1.69, 0.24); g.fillStyle = PAPER; g.fillRect(dx - 0.22, 8.14, 1.69, 0.045);
    g.fillStyle = INK; g.beginPath(); g.moveTo(lx - 0.36, ly); g.lineTo(lx + 0.36, ly); g.lineTo(lx + 0.15, ly - 0.26); g.lineTo(lx - 0.15, ly - 0.26); g.closePath(); g.fill(); g.fillRect(lx - 0.035, ly - 0.55, 0.07, 0.3);
    g.strokeStyle = PAPER; inkLine(g, r, lx - 0.16, ly - 0.25, lx - 0.36, ly - 0.01, 0.03, 0.002);
    g.fillStyle = AMBER; g.beginPath(); g.moveTo(lx - 0.24, ly); g.lineTo(lx + 0.24, ly); g.lineTo(lx + 0.14, ly + 0.13); g.lineTo(lx - 0.14, ly + 0.13); g.closePath(); g.fill();
    g.strokeStyle = AMBER; for (const [ax, ay] of [[-0.75, 0.25], [-0.5, 0.6], [0.5, 0.6], [0.75, 0.25]]) inkLine(g, r, lx + ax * 0.55, ly + 0.1 + ay * 0.55, lx + ax, ly + 0.1 + ay, 0.03, 0.003); // drawn rays instead of a glow
    for (let k = 0; k < w * 12; k++) { g.fillStyle = r() < 0.6 ? 'rgba(8,8,10,0.6)' : 'rgba(234,230,223,0.2)'; const z = 0.02 + r() * 0.05; g.fillRect(x + r() * w, top + r() * H, z, z); }
  }

  // 2.5D: every solid is a box. Its front face sits a little towards the viewer (F), its top and right side run back (D).
  const FX = -0.06, FY = 0.15, DX = 0.22, DY = -0.45, WALL = 10.55;
  function buildings(st) {
    const r = rng(st.page * 131 + 9), out = [];
    let x = -3;
    while (x < st.len + 4) { const w = 7.5 + r() * 3.5; out.push({ x, w, top: -0.6 + r() * 3.4, seed: Math.floor(r() * 1e6) }); x += w + 3.6 + r() * 2.2; }
    return out;
  }
  function box(g, r, b, kind) {
    const pi = Assets.get('props_sheet');
    if (pi) { // front face of the art maps onto the collision box; lid and side overhang it
      const X = b.x + FX, Y = b.y + FY;
      if (kind === 'crate') g.drawImage(pi, 0, 0, 384, 384, X - b.w * 0.125, Y - b.h * 0.375, b.w * 1.5, b.h * 1.5);
      else { const n = Math.max(1, Math.round(b.w / b.h)), cw = b.w / n; for (let i = 0; i < n; i++) g.drawImage(pi, 0, 0, 384, 384, X + i * cw - cw * 0.125, Y - b.h * 0.375, cw * 1.5, b.h * 1.5); } // a long box is a row of crates
      return;
    }
    const x = b.x + FX, y = b.y + FY, w = b.w, h = b.h, crate = kind === 'crate', oxide = !crate && r() < 0.5;
    const face = mono ? (crate ? '#17191C' : '#101113') : (crate ? '#3B352F' : (oxide ? '#4A2422' : '#2C3138'));
    const topc = mono ? (crate ? '#C9CACA' : '#B4B7B9') : (crate ? '#7A7166' : (oxide ? '#7A4A45' : '#6A7078'));
    g.fillStyle = DEEP; g.beginPath(); g.moveTo(x + w, y); g.lineTo(x + w + DX, y + DY); g.lineTo(x + w + DX, y + h + DY); g.lineTo(x + w, y + h); g.closePath(); g.fill();
    g.strokeStyle = INK; inkLine(g, r, x + w + DX, y + DY, x + w + DX, y + h + DY, 0.04, 0.003);
    g.fillStyle = topc; g.beginPath(); g.moveTo(x, y); g.lineTo(x + w, y); g.lineTo(x + w + DX, y + DY); g.lineTo(x + DX, y + DY); g.closePath(); g.fill();
    inkLine(g, r, x + DX, y + DY, x + w + DX, y + DY, 0.035, 0.003); inkLine(g, r, x, y, x + DX, y + DY, 0.04, 0.002); inkLine(g, r, x + w, y, x + w + DX, y + DY, 0.04, 0.002);
    if (crate) for (let i = 1; i < 3; i++) inkLine(g, r, x + w * i / 3, y, x + w * i / 3 + DX, y + DY, 0.02, 0.002);
    else for (let px = x + 0.3; px < x + w; px += 0.26) inkLine(g, r, px, y, px + DX, y + DY, 0.016, 0.002);
    g.fillStyle = INK; g.fillRect(x, y, w, h);
    g.fillStyle = face; g.fillRect(x + 0.1, y + 0.1, w - 0.2, h - 0.2);
    g.strokeStyle = mono ? '#4E535A' : INK;
    if (crate) {
      for (let i = 1; i < 4; i++) inkLine(g, r, x + 0.1, y + 0.1 + i * (h - 0.2) / 4, x + w - 0.1, y + 0.1 + i * (h - 0.2) / 4, 0.022, 0.006);
      inkLine(g, r, x + 0.12, y + 0.12, x + w - 0.12, y + h - 0.12, 0.09, 0.008);
      if (r() < 0.55) inkLine(g, r, x + w - 0.12, y + 0.12, x + 0.12, y + h - 0.12, 0.09, 0.008);
    } else {
      for (let px = x + 0.3; px < x + w - 0.2; px += 0.26) inkLine(g, r, px, y + 0.14, px, y + h - 0.14, 0.05, 0.003);
      inkLine(g, r, x + w * 0.5, y + 0.1, x + w * 0.5, y + h - 0.1, 0.09, 0.003);
      hatch(g, r, x + w * 0.62, y + 0.1, w * 0.38 - 0.1, h - 0.2, 0.13, 0.02, 0.5);
    }
    g.strokeStyle = mono ? PAPER : PALE; inkLine(g, r, x + 0.03, y + 0.02, x + w - 0.03, y + 0.02, mono ? 0.045 : 0.03, 0.002);
    if (mono) inkLine(g, r, x + 0.03, y + 0.05, x + 0.03, y + h - 0.03, 0.03, 0.002); // light down the near edge
    g.strokeStyle = INK;
  }

  // play layer: tenement walls, wet pavement, boxes, catwalks and the exit, one sheet per 16 m of level.
  const CH = 16;
  function chunkSheet(st, idx, m, dpr) {
    const [c, g] = sheet(CH, 12, m, dpr), x0 = idx * CH, r = rng(1000 + idx * 37 + st.page * 7919);
    g.translate(-x0, 0);
    const vis = b => b.x < x0 + CH + 4 && b.x + b.w > x0 - 4;
    if (!Assets.get('bg_street_wall')) { // walls, lamps and pavement are placeholders for bg_street_wall.png
    const bs = buildings(st), lamps = [];
    for (let i = 0; i < bs.length; i++) {
      const b = bs[i], n = bs[i + 1];
      if (vis(b)) { (mono ? facadeNoir : facade)(g, rng(b.seed), b.x, b.w, b.top); lamps.push(b.x + b.w * 0.55 + 0.62); }
      if (n && b.x + b.w < x0 + CH + 4 && n.x > x0 - 4) { // gap: chain-link fence and a street lamp
        const x1 = b.x + b.w, x2 = n.x, fr = rng(b.seed + 5), lx = (x1 + x2) / 2;
        glow(g, lx + 0.95, 5.6, 4.2, AMB, 0.5);
        g.fillStyle = mono ? 'rgba(234,230,223,0.1)' : `rgba(${AMB},0.13)`; g.beginPath(); g.moveTo(lx + 0.72, 5.46); g.lineTo(lx + 1.14, 5.43); g.lineTo(lx + 3.1, WALL); g.lineTo(lx - 1.2, WALL); g.closePath(); g.fill();
        g.strokeStyle = INK; g.save(); g.beginPath(); g.rect(x1, 8.9, x2 - x1, 1.7); g.clip();
        for (let d = x1 - 2; d < x2 + 2; d += 0.28) { inkLine(g, fr, d, 10.6, d + 1.7, 8.9, 0.016, 0.003); inkLine(g, fr, d, 8.9, d + 1.7, 10.6, 0.016, 0.003); }
        g.restore();
        inkLine(g, fr, x1, 8.9, x2, 8.9, 0.055, 0.005);
        if (mono) { g.strokeStyle = PALE; inkLine(g, fr, x1, 8.86, x2, 8.86, 0.025, 0.004); inkLine(g, fr, lx - 0.05, 10.6, lx - 0.05, 5.45, 0.03, 0.004); g.strokeStyle = INK; }
        inkLine(g, fr, lx, 10.6, lx, 5.4, 0.09, 0.005); inkLine(g, fr, lx, 5.4, lx + 0.9, 5.15, 0.07, 0.004);
        g.fillStyle = INK; g.beginPath(); g.moveTo(lx + 0.62, 5.18); g.lineTo(lx + 1.25, 5.1); g.lineTo(lx + 1.15, 5.42); g.lineTo(lx + 0.7, 5.46); g.closePath(); g.fill();
        g.fillStyle = mono ? AMBER : '#FFE9B8'; g.beginPath(); g.ellipse(lx + 0.93, 5.47, 0.2, 0.07, -0.08, 0, TAU); g.fill();
        if (mono) { g.strokeStyle = 'rgba(8,8,10,0.5)'; g.save(); g.beginPath(); g.moveTo(lx + 0.72, 5.46); g.lineTo(lx + 1.14, 5.43); g.lineTo(lx + 3.1, WALL); g.lineTo(lx - 1.2, WALL); g.closePath(); g.clip(); hatch(g, fr, lx - 1.2, 5.4, 1.2, WALL - 5.4, 0.12, 0.02, -0.4); hatch(g, fr, lx + 1.6, 5.4, 1.6, WALL - 5.4, 0.12, 0.02, 0.4); g.restore(); }
        lamps.push(lx + 0.95);
      }
    }
    // mist gathering at street level: lifts the lower walls so dark figures read against them
    if (!mono) { const fog = g.createLinearGradient(0, 5.2, 0, WALL); fog.addColorStop(0, `rgba(${FOGC},0)`); fog.addColorStop(1, `rgba(${FOGC},0.4)`); g.fillStyle = fog; g.fillRect(x0 - 1, 5.2, CH + 2, WALL - 5.2); }
    // wet pavement running back to the wall, kerb, road
    g.fillStyle = mono ? '#131417' : PAVE; g.fillRect(x0 - 1, WALL, CH + 2, 11 + FY - WALL);
    if (mono) { g.fillStyle = 'rgba(233,227,214,0.2)'; for (let k = 0; k < 46; k++) { const sx = x0 - 1 + r() * (CH + 2), sw = 0.25 + r() * 0.9; g.fillRect(sx, WALL + 0.08 + r() * 0.48, sw, 0.022); } }
    for (const lx of lamps) { // lamplight smeared down the wet stone
      g.fillStyle = mono ? AMBER : `rgba(${AMB},0.22)`;
      for (let k = -4; k <= 4; k++) { if (mono && (k & 1)) continue; g.fillRect(lx + k * 0.3 - 0.07 + (r() - 0.5) * 0.1, WALL + 0.06, mono ? 0.035 + r() * 0.03 : 0.1 + r() * 0.1, mono ? 0.3 - Math.abs(k) * 0.04 : 0.56 - Math.abs(k) * 0.07); }
      if (mono) { g.fillStyle = PAPER; for (let k = -2; k <= 2; k++) g.fillRect(lx + k * 0.22 + (r() - 0.5) * 0.1, WALL + 0.1 + r() * 0.1, 0.035, 0.34 - Math.abs(k) * 0.07); }
      glow(g, lx, 10.85, 2.2, AMB, 0.22);
    }
    g.strokeStyle = mono ? '#3A3E44' : '#353A41';
    for (let x = Math.floor(x0 / 1.5) * 1.5 - 1.5; x < x0 + CH + 1; x += 1.5) inkLine(g, r, x, 11 + FY, x + 0.3, WALL, 0.025, 0.003);
    inkLine(g, r, x0 - 1, 10.82, x0 + CH + 1, 10.82, 0.02, 0.003);
    for (let k = 0; k < 4; k++) { // puddles
      const px = x0 + r() * CH, py = 10.72 + r() * 0.3, pw = 0.5 + r() * 0.7;
      g.fillStyle = mono ? 'rgba(214,216,216,0.7)' : 'rgba(150,156,162,0.45)'; g.beginPath(); g.ellipse(px, py, pw, 0.07, 0, 0, TAU); g.fill();
      g.strokeStyle = INK; g.lineWidth = 0.018; g.stroke();
    }
    g.strokeStyle = INK; inkLine(g, r, x0 - 1, WALL, x0 + CH + 1, WALL, 0.07, 0.004);
    hatch(g, r, x0 - 1, WALL, CH + 2, 0.16, 0.09, 0.016, 0.4);
    g.fillStyle = INK; g.fillRect(x0 - 1, 11 + FY, CH + 2, 0.26);
    g.fillStyle = DEEP; g.fillRect(x0 - 1, 11 + FY + 0.26, CH + 2, 1);
    g.strokeStyle = PALE; inkLine(g, r, x0 - 1, 11 + FY + 0.015, x0 + CH + 1, 11 + FY + 0.015, 0.03, 0.002);
    for (const lx of lamps) { g.fillStyle = `rgba(${AMB},0.2)`; g.fillRect(lx - 0.5, 11.45, 1.0, 0.05); g.fillRect(lx - 0.3, 11.62, 0.6, 0.04); }
    g.strokeStyle = SLATE;
    for (let x = Math.floor(x0 / 2.4) * 2.4; x < x0 + CH; x += 2.4) inkLine(g, r, x, 11.8, x + 1.1, 11.8, 0.05, 0.003);
    g.strokeStyle = INK;
    if (mono) { const sx = x0 + 2 + r() * (CH - 4); g.fillStyle = INK; g.beginPath(); g.ellipse(sx, 10.82, 0.5, 0.09, 0, 0, TAU); g.fill(); g.strokeStyle = PALE; g.lineWidth = 0.025; g.stroke(); steam(g, r, sx - 0.1, 10.6, 5); } // a manhole breathing steam
    const free = x => { for (const b of st.solids) if (b.y < 11 && b.y > 0 && x > b.x - 1.3 && x < b.x + b.w + 1.3) return false; return x > 3 && x < st.len - 9; };
    for (let k = 0; k < 3; k++) {
      const x = x0 + 1.5 + r() * (CH - 3), kind = r(), by = 10.78;
      if (!free(x)) continue;
      if (kind < 0.4) {
        g.fillStyle = mono ? '#17191C' : SLATE; g.fillRect(x, by - 0.85, 0.62, 0.85); if (mono) { g.fillStyle = PALE; g.fillRect(x - 0.07, by - 0.92, 0.76, 0.04); g.fillRect(x - 0.03, by - 0.85, 0.035, 0.85); } inkRect(g, r, x, by - 0.85, 0.62, 0.85, 0.05, 0.004); inkLine(g, r, x - 0.07, by - 0.85, x + 0.69, by - 0.85, 0.08, 0.004);
        for (let i = 1; i < 4; i++) inkLine(g, r, x + i * 0.155, by - 0.75, x + i * 0.155, by - 0.08, 0.02, 0.004);
      } else if (kind < 0.7) {
        g.fillStyle = mono ? MIST : BRICK2; g.fillRect(x, by - 0.58, 0.3, 0.58); inkRect(g, r, x, by - 0.58, 0.3, 0.58, 0.05, 0.004); inkLine(g, r, x - 0.1, by - 0.38, x + 0.4, by - 0.38, 0.09, 0.004); inkLine(g, r, x + 0.02, by - 0.6, x + 0.28, by - 0.6, 0.11, 0.004);
      } else {
        for (let i = 0; i < 3; i++) { g.fillStyle = DEEP; g.fillRect(x, by - 0.24 - i * 0.24, 0.72, 0.22); inkRect(g, r, x, by - 0.24 - i * 0.24, 0.72, 0.22, 0.05, 0.005); }
      }
    }
    }
    if (st.exitX + 0.5 < x0 + CH && st.exitX + 3.6 > x0) { // exit: a lit doorway
      const dx = st.exitX + 1.2;
      glow(g, dx + 0.9, 9.0, 3.4, AMB, 0.5);
      g.fillStyle = INK; g.fillRect(dx - 0.15, 7.55, 2.1, 3.0);
      g.fillStyle = AMBER; g.fillRect(dx + 0.08, 7.8, 1.64, 2.75);
      g.fillStyle = 'rgba(255,240,200,0.55)'; g.fillRect(dx + 0.2, 7.95, 1.4, 1.2);
      inkLine(g, r, dx + 0.9, 7.8, dx + 0.9, 10.55, 0.05, 0.004);
      g.fillStyle = INK; g.fillRect(dx + 1.02, 9.1, 0.1, 0.24);
      g.fillStyle = RED; g.fillRect(dx - 0.25, 6.75, 2.3, 0.62); g.strokeStyle = INK; g.lineWidth = 0.05; g.strokeRect(dx - 0.25, 6.75, 2.3, 0.62);
    }
    for (const p of st.plats) if (vis(p)) { // catwalks
      const x = p.x + FX, y = p.y + FY;
      g.strokeStyle = INK;
      inkLine(g, r, x + 0.3 + DX, y + DY, x + 0.3 + DX, 0, 0.03, 0.003); inkLine(g, r, x + p.w - 0.3 + DX, y + DY, x + p.w - 0.3 + DX, 0, 0.03, 0.003);
      g.fillStyle = mono ? '#B4B7B9' : '#6A7078'; g.beginPath(); g.moveTo(x, y); g.lineTo(x + p.w, y); g.lineTo(x + p.w + DX, y + DY); g.lineTo(x + DX, y + DY); g.closePath(); g.fill();
      for (let px = x + 0.2; px < x + p.w; px += 0.2) inkLine(g, r, px, y, px + DX, y + DY, 0.014, 0.001);
      inkLine(g, r, x + DX, y + DY, x + p.w + DX, y + DY, 0.035, 0.003);
      g.fillStyle = DEEP; g.beginPath(); g.moveTo(x + p.w, y); g.lineTo(x + p.w + DX, y + DY); g.lineTo(x + p.w + DX, y + DY + 0.22); g.lineTo(x + p.w, y + 0.22); g.closePath(); g.fill();
      for (let px = x + 0.2; px < x + p.w - 0.3; px += 0.5) { inkLine(g, r, px, y + 0.2, px + 0.25, y + 0.5, 0.035, 0.004); inkLine(g, r, px + 0.25, y + 0.5, px + 0.5, y + 0.2, 0.035, 0.004); }
      inkLine(g, r, x + 0.15, y + 0.5, x + p.w - 0.15, y + 0.5, 0.045, 0.005);
      inkLine(g, r, x + 0.3, y, x + 0.3, 0, 0.045, 0.003); inkLine(g, r, x + p.w - 0.3, y, x + p.w - 0.3, 0, 0.045, 0.003);
      g.fillStyle = INK; g.fillRect(x, y, p.w, 0.22);
      g.strokeStyle = PALE; inkLine(g, r, x + 0.05, y + 0.02, x + p.w - 0.05, y + 0.02, 0.03, 0.002);
    }
    const boxes = st.solids.filter(b => vis(b) && b.y < 11 && b.y > 0 && b.w !== 1).sort((a, b) => (b.y + b.h) - (a.y + a.h) || a.x - b.x);
    for (const b of boxes) box(g, rng(Math.floor(b.x * 100) + st.page * 31), b, b.h <= 1.3 ? 'crate' : 'container');
    for (const b of st.solids) if (b.w === 1 && vis(b)) { g.fillStyle = INK; g.fillRect(b.x, 0, b.w, 12); }
    return c;
  }

  // foreground: parked cars and bollards at the roadside, nearer than the action. Low, so they never hide a fight.
  const FG_W = 44;
  function fgSheet(m, dpr) {
    const [c, g] = sheet(FG_W, 1.3, m, dpr), r = rng(909);
    g.translate(0, -10.7);
    for (const x of [3, 19.5, 33]) {
      g.fillStyle = INK; g.beginPath(); g.moveTo(x, 12); g.lineTo(x + 0.2, 11.55); g.lineTo(x + 1.3, 11.45); g.lineTo(x + 2.0, 10.95); g.lineTo(x + 3.9, 10.92); g.lineTo(x + 4.7, 11.45); g.lineTo(x + 5.9, 11.55); g.lineTo(x + 6.1, 12); g.closePath(); g.fill();
      g.fillStyle = '#23262B'; g.beginPath(); g.moveTo(x + 1.55, 11.45); g.lineTo(x + 2.1, 11.05); g.lineTo(x + 2.9, 11.03); g.lineTo(x + 2.9, 11.45); g.closePath(); g.fill();
      g.beginPath(); g.moveTo(x + 3.05, 11.03); g.lineTo(x + 3.8, 11.02); g.lineTo(x + 4.45, 11.45); g.lineTo(x + 3.05, 11.45); g.closePath(); g.fill();
      g.strokeStyle = PALE; inkLine(g, r, x + 2.05, 10.96, x + 3.85, 10.94, 0.03, 0.002); inkLine(g, r, x + 0.3, 11.56, x + 1.25, 11.47, 0.025, 0.002);
      g.strokeStyle = `rgba(${AMB},0.8)`; inkLine(g, r, x + 4.8, 11.5, x + 5.8, 11.58, 0.03, 0.002);
    }
    for (const x of [11, 13.2, 27.5, 41]) { g.fillStyle = INK; g.fillRect(x, 11.2, 0.22, 0.9); g.fillRect(x - 0.05, 11.14, 0.32, 0.1); g.strokeStyle = PALE; inkLine(g, r, x - 0.04, 11.15, x + 0.26, 11.15, 0.025, 0.001); }
    return c;
  }

  // ---------- cache ----------
  let key = '', far = null, farSlow = null, fg = null, chunks = new Map(), levelKey = '';
  function sheets(ctx, m) {
    const dpr = ctx.getTransform().a || 1, k = m + ':' + dpr + ':' + mono;
    // the far sheet is rendered soft and small: it is distant, and it is the one blit that covers the whole screen
    if (k !== key) { key = k; const lo = Math.min(dpr, 1.25); far = farSheet(m, lo, false); farSlow = farSheet(m, lo, true); fg = fgSheet(m, Math.min(dpr, 2)); chunks = new Map(); }
    return { far, farSlow, fg, dpr };
  }
  function chunk(ctx, st, idx, m) {
    const lk = st.page + ':' + st.len + ':' + (st.solids.length) + ':' + st.exitX + ':' + mono;
    if (lk !== levelKey) { levelKey = lk; chunks = new Map(); }
    let c = chunks.get(idx);
    if (!c) {
      c = chunkSheet(st, idx, m, Math.min(ctx.getTransform().a || 1, 2)); chunks.set(idx, c);
      if (chunks.size > 4) chunks.delete(chunks.keys().next().value);
    }
    return c;
  }
  function tile(ctx, c, off, m, y) { // draw a wrapping sheet shifted left by `off` metres
    const w = c.wm * m; let x = -(((off % c.wm) + c.wm) % c.wm) * m;
    for (; x < Sim.VW * m; x += w) ctx.drawImage(c, x, (y || 0) * m, w, c.hm * m);
  }
  function backdrop(ctx, st, cam, m, slowK) {
    const s = sheets(ctx, m), layer = (n, k, wm) => { const im = Assets.get(n); if (!im) return false; im.wm = wm || FAR_W; im.hm = 12; tile(ctx, im, cam * k, m); return true; };
    if (!layer('bg_manhattan_far', 0.25)) {
      if (slowK < 0.97) tile(ctx, s.far, cam * 0.25, m);
      if (slowK > 0.02) { ctx.globalAlpha = slowK > 0.97 ? 1 : slowK; tile(ctx, s.farSlow, cam * 0.25, m); ctx.globalAlpha = 1; }
    }
    layer('bg_rooftop_mid', 0.55); layer('bg_street_wall', 1, 54);
    for (let i = Math.floor(cam / CH); i <= Math.floor((cam + Sim.VW) / CH); i++) {
      if (i < 0 || i * CH >= st.len) continue;
      ctx.drawImage(chunk(ctx, st, i, m), (i * CH - cam) * m, 0, CH * m, 12 * m);
    }
  }
  let lampKey = '', lampList = [];
  function lit(st, x, y) { // is this spot inside a pool of lamplight?
    const k = st.page + ':' + st.len;
    if (k !== lampKey) {
      lampKey = k; lampList = [];
      const bs = buildings(st);
      for (let i = 0; i < bs.length; i++) { lampList.push(bs[i].x + bs[i].w * 0.55 + 0.62); if (bs[i + 1]) lampList.push((bs[i].x + bs[i].w + bs[i + 1].x) / 2 + 0.95); }
      if (st.exitX) lampList.push(st.exitX + 2.1);
    }
    if (y < 7.2) return false;
    for (let i = 0; i < lampList.length; i++) { const d = x - lampList[i]; if (d > -1.7 && d < 1.7) return true; }
    return false;
  }
  function foreground(ctx, cam, m) { tile(ctx, sheets(ctx, m).fg, cam * 1.45, m, 10.7); }
  function shadow(ctx, x, y, w) { // contact shadow on whatever the figure stands on
    ctx.fillStyle = 'rgba(13,13,13,0.38)'; ctx.beginPath(); ctx.ellipse(x + 0.05, y + 0.03, w, 0.075, 0, 0, TAU); ctx.fill();
  }

  // placeholder sheets, written out once in the exact layout the real art has to follow
  function propsTemplate() {
    const c = document.createElement('canvas'); c.width = 1024; c.height = 384; const g = c.getContext('2d'); g.scale(200, 200);
    box(g, rng(5), { x: 0.22, y: 0.33, w: 1.28, h: 1.28 }, 'crate'); box(g, rng(9), { x: 2.14, y: 0.33, w: 2.56, h: 1.28 }, 'container');
    return c;
  }
  return { farTemplate: () => farSheet(4096 / FAR_W, 1, false), propsTemplate, figure, backdrop, foreground, shadow, lit, reset: () => { chunks = new Map(); levelKey = ''; lampKey = ''; }, isMono: () => mono, setMono: v => { mono = !!v; }, PAPER, INK, RED, GOLD, PALE, MIST, AMBER };
})();
