// Touch (two floating sticks + three tap buttons), keyboard + mouse, gamepad.
const Input = (() => {
  const st = {
    l: { on: false, id: -1, o: { x: 0, y: 0 }, vx: 0, vy: 0 },
    r: { on: false, id: -1, o: { x: 0, y: 0 }, vx: 0, vy: 0, t0: 0, maxd: 0 },
    btn: {}, latch: { bt: false, dive: false }, tapShot: 0, fireLatch: 0, recent: { x: 0, y: 0, t: -1e9 },
    keys: {}, mouse: { x: 0, y: 0, down: false, used: false }, touchSeen: false, any: false,
  };
  let getL = null, toGame = null;

  function hitBtn(L, g) {
    for (const k of ['jump', 'dive', 'bt']) {
      const b = L[k], dx = g.x - b.x, dy = g.y - b.y, r = L.R * 1.35;
      if (dx * dx + dy * dy < r * r) return k;
    }
    return null;
  }

  function setVec(s, g, R) {
    let dx = g.x - s.o.x, dy = g.y - s.o.y;
    const d = Math.sqrt(dx * dx + dy * dy);
    if (d > R) { dx *= R / d; dy *= R / d; } // fixed base: the knob stops at the rim, the base never moves
    s.vx = dx / R; s.vy = dy / R;
    return Math.min(1, d / R);
  }

  function down(e) {
    st.any = true;
    const g = toGame(e.clientX, e.clientY), L = getL();
    st.lastTap = g;
    if (e.pointerType === 'mouse') {
      st.mouse.x = g.x; st.mouse.y = g.y; st.mouse.used = true;
      if (e.button === 0) st.mouse.down = true;
      if (e.button === 2) st.latch.bt = true;
      return;
    }
    st.touchSeen = true;
    const k = hitBtn(L, g);
    if (k) { st.btn[e.pointerId] = k; if (k !== 'jump') st.latch[k] = true; return; }
    const s = g.x < L.vw / 2 ? st.l : st.r;
    if (s.on) return;
    const c = s === st.l ? L.hintL : L.hintR;
    s.on = true; s.id = e.pointerId; s.o = { x: c.x, y: c.y }; s.start = { x: g.x, y: g.y }; s.moved = 0;
    setVec(s, g, L.stickR);
    if (s === st.r) s.t0 = performance.now();
    if (s === st.l && s.vx * s.vx + s.vy * s.vy > 0.09) st.recent = { x: s.vx, y: s.vy, t: performance.now() };
  }
  function move(e) {
    const g = toGame(e.clientX, e.clientY), L = getL();
    if (e.pointerType === 'mouse') { st.mouse.x = g.x; st.mouse.y = g.y; st.mouse.used = true; return; }
    if (st.l.on && st.l.id === e.pointerId) { setVec(st.l, g, L.stickR); if (st.l.vx * st.l.vx + st.l.vy * st.l.vy > 0.09) st.recent = { x: st.l.vx, y: st.l.vy, t: performance.now() }; }
    else if (st.r.on && st.r.id === e.pointerId) { setVec(st.r, g, L.stickR); const mx = g.x - st.r.start.x, my = g.y - st.r.start.y, d = Math.sqrt(mx * mx + my * my); if (d > st.r.moved) st.r.moved = d; }
  }
  function up(e) {
    if (e.pointerType === 'mouse') { if (e.button === 0) st.mouse.down = false; return; }
    delete st.btn[e.pointerId];
    if (st.l.on && st.l.id === e.pointerId) { st.l.on = false; st.l.vx = 0; st.l.vy = 0; }
    else if (st.r.on && st.r.id === e.pointerId) {
      if (st.r.moved < 12 && performance.now() - st.r.t0 < 260) st.tapShot = 4; // a short tap is one shot
      else if (Math.sqrt(st.r.vx * st.r.vx + st.r.vy * st.r.vy) > 0.35) st.fireLatch = 14; // keep firing while the thumb hops to a button
      st.r.on = false; st.r.vx = 0; st.r.vy = 0;
    }
  }

  function init(target, layoutFn, toGameFn) {
    getL = layoutFn; toGame = toGameFn;
    target.addEventListener('pointerdown', e => { e.preventDefault(); down(e); });
    target.addEventListener('pointermove', e => { e.preventDefault(); move(e); });
    for (const n of ['pointerup', 'pointercancel']) target.addEventListener(n, e => { e.preventDefault(); up(e); });
    target.addEventListener('contextmenu', e => e.preventDefault());
    for (const n of ['touchstart', 'touchmove', 'touchend']) target.addEventListener(n, e => e.preventDefault(), { passive: false });
    window.addEventListener('keydown', e => {
      if (e.repeat) return;
      st.keys[e.code] = true; st.any = true; st.lastTap = null;
      if (e.code === 'KeyB') { st.styleKey = true; st.any = false; }
      if (e.code === 'KeyE' || e.code === 'KeyQ' || e.code === 'KeyF') st.latch.bt = true;
      if (e.code === 'ShiftLeft' || e.code === 'ShiftRight') st.latch.dive = true;
      if (['Space', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) e.preventDefault();
    });
    window.addEventListener('keyup', e => { st.keys[e.code] = false; });
    window.addEventListener('blur', () => { st.keys = {}; st.mouse.down = false; });
  }

  let padPrev = {};
  function sample(playerScreen) {
    const k = st.keys, q = v => Math.round(Math.max(-1, Math.min(1, v)) * 127) / 127;
    let mx = st.l.vx, my = st.l.vy, ax = st.r.vx, ay = st.r.vy;
    let fire = st.r.on && Math.sqrt(ax * ax + ay * ay) > 0.35;
    if (st.tapShot > 0) { st.tapShot--; fire = true; }
    if (st.r.on) st.fireLatch = 0; else if (st.fireLatch > 0) { st.fireLatch--; fire = true; }
    let jump = false, bt = st.latch.bt, dive = st.latch.dive;
    for (const id in st.btn) if (st.btn[id] === 'jump') jump = true;

    st.latch.bt = st.latch.dive = false;

    if (k.KeyA || k.ArrowLeft) mx -= 1;
    if (k.KeyD || k.ArrowRight) mx += 1;
    if (k.KeyS || k.ArrowDown) my += 1;
    if (k.KeyW || k.ArrowUp) my -= 1;
    if (k.Space) jump = true;
    if (st.mouse.used && !st.touchSeen && playerScreen) {
      const dx = st.mouse.x - playerScreen.x, dy = st.mouse.y - playerScreen.y, d = Math.sqrt(dx * dx + dy * dy);
      if (d > 4) { ax = dx / d; ay = dy / d; }
      if (st.mouse.down) fire = true;
    }
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    for (const gp of pads) {
      if (!gp || !gp.connected) continue;
      const dz = v => (Math.abs(v) < 0.18 ? 0 : v), b = i => !!(gp.buttons[i] && gp.buttons[i].pressed);
      mx += dz(gp.axes[0] || 0); my += dz(gp.axes[1] || 0);
      const gx = dz(gp.axes[2] || 0), gy = dz(gp.axes[3] || 0);
      if (gx || gy) { ax = gx; ay = gy; }
      if (b(7)) fire = true;
      if (b(0)) jump = true;
      const edge = (name, i) => { const now = b(i), was = padPrev[name]; padPrev[name] = now; return now && !was; };
      if (edge('dive', 6) || edge('dive2', 1)) dive = true;
      if (edge('bt', 5) || edge('bt2', 4)) bt = true;
      if (b(7) || b(0) || b(9)) st.any = true;
      break;
    }
    return { mx: q(mx), my: q(my), ax: q(ax), ay: q(ay), fire, jump, dive, bt };
  }

  function takeAny() { const a = st.any; st.any = false; return a; }
  function styleKey() { const k = st.styleKey; st.styleKey = false; return k; }
  function lastTap() { const t = st.lastTap; st.lastTap = null; return t; }
  return { init, sample, takeAny, lastTap, styleKey, sticks: () => ({ l: st.l, r: st.r }), touch: () => st.touchSeen };
})();
