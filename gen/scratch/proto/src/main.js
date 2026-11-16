(() => {
  const cv = document.getElementById('game'), ctx = cv.getContext('2d');
  const coarse = (navigator.maxTouchPoints || 0) > 0;
  const used = { dive: false, bt: false };
  let prev = new WeakMap(), fpsT = 0, fpsN = 0, fps = 0, quality = 2, lowRuns = 0, warm = 0;
  let L = null, rot = false, GW = 0, GH = 0, mode = 'title', state = Sim.create(1), overT = 0, acc = 0, last = 0;

  function resize() {
    const iw = window.innerWidth, ih = window.innerHeight, dpr = Math.min(window.devicePixelRatio || 1, quality);
    rot = coarse && ih > iw; // the host app may not rotate: draw the game sideways so the phone can still be held in landscape
    GW = rot ? ih : iw; GH = rot ? iw : ih;
    cv.width = Math.round(GW * dpr); cv.height = Math.round(GH * dpr);
    cv.style.width = GW + 'px'; cv.style.height = GH + 'px';
    cv.style.transform = rot ? `translate(${iw}px,0) rotate(90deg)` : 'none';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    L = View.layout(GW, GH);
  }
  const toGame = (cx, cy) => (rot ? { x: cy, y: window.innerWidth - cx } : { x: cx, y: cy });
  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', resize);
  resize();
  Input.init(cv, () => L, toGame);
  Assets.onchange = () => View.reset(); Assets.load();

  // --- tiny synthesized sound, started from the first tap ---
  let ac = null, slow = 1;
  function audioInit() {
    if (ac) return;
    try { ac = new (window.AudioContext || window.webkitAudioContext)(); if (ac.state === 'suspended') ac.resume(); } catch (e) { ac = null; }
  }
  function noise(dur, freq, gain) {
    if (!ac) return;
    try {
      const n = Math.floor(ac.sampleRate * dur), buf = ac.createBuffer(1, n, ac.sampleRate), d = buf.getChannelData(0);
      for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n) * (1 - i / n);
      const src = ac.createBufferSource(), f = ac.createBiquadFilter(), g = ac.createGain();
      src.buffer = buf; src.playbackRate.value = slow; f.type = 'lowpass'; f.frequency.value = freq * slow; g.gain.value = gain;
      src.connect(f); f.connect(g); g.connect(ac.destination); src.start();
    } catch (e) { /* sound is optional */ }
  }
  function tone(f0, f1, dur, gain, type) {
    if (!ac) return;
    try {
      const o = ac.createOscillator(), g = ac.createGain(), t = ac.currentTime;
      o.type = type || 'triangle'; o.frequency.setValueAtTime(f0 * slow, t); o.frequency.exponentialRampToValueAtTime(Math.max(20, f1 * slow), t + dur);
      g.gain.setValueAtTime(gain, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
      o.connect(g); g.connect(ac.destination); o.start(t); o.stop(t + dur + 0.02);
    } catch (e) { /* sound is optional */ }
  }
  function sounds(events) {
    for (const e of events) {
      if (e.t === 'shot') { if (e.team === 0) { noise(0.12, 2600, 0.5); tone(220, 60, 0.09, 0.25); } else noise(0.1, 1200, 0.22); }
      else if (e.t === 'blast') { noise(0.22, 900, 0.5); tone(120, 40, 0.18, 0.3); }
      else if (e.t === 'snipe') { noise(0.2, 4200, 0.45); tone(900, 120, 0.15, 0.2, 'sawtooth'); }
      else if (e.t === 'kill') { tone(180, 45, 0.28, 0.5); noise(0.18, 700, 0.4); }
      else if (e.t === 'hit') tone(500, 200, 0.06, 0.2, 'square');
      else if (e.t === 'hurt') { tone(140, 50, 0.35, 0.5, 'sawtooth'); noise(0.25, 500, 0.4); }
      else if (e.t === 'clink') tone(1800, 1400, 0.12, 0.25, 'sine');
      else if (e.t === 'btOn') tone(700, 90, 0.6, 0.3, 'sine');
      else if (e.t === 'btOff') tone(90, 500, 0.3, 0.18, 'sine');
      else if (e.t === 'reloaded') tone(900, 700, 0.05, 0.15, 'square');
      else if (e.t === 'dive') noise(0.16, 500, 0.2);
      else if (e.t === 'page') { tone(330, 330, 0.15, 0.25); setTimeout(() => tone(494, 494, 0.3, 0.25), 140); }
    }
  }

  function start() { state = Sim.create((Date.now() & 0x7fffffff) || 1); mode = 'play'; acc = 0; View.reset(); audioInit();
    try { const o = screen.orientation; if (o && o.lock) { const q = o.lock('landscape'); if (q && q.catch) q.catch(() => {}); } } catch (e) { /* only allowed in fullscreen or an installed app */ }
  }

  function tick() {
    const p = state.player;
    const inp = Input.sample(View.screenOf(L, p.x, p.y - p.h * 0.6));
    if (mode === 'play') {
      prev = new WeakMap(); // positions before this tick, for smooth drawing between ticks
      prev.set(p, { x: p.x, y: p.y });
      for (const e of state.enemies) prev.set(e, { x: e.x, y: e.y });
      for (const b of state.bullets) prev.set(b, { x: b.x, y: b.y });
      Sim.step(state, inp);
      View.onEvents(state.events); sounds(state.events);
      for (const e of state.events) { if (e.t === 'dive') used.dive = true; if (e.t === 'btOn' && !state.btAuto) used.bt = true; }
      const slowNow = state.bt || state.slowT > 0;
      slow = slowNow ? 0.55 : 1;
      if (slowNow && state.tick % 22 === 0) tone(58, 38, 0.16, 0.35, 'sine'); // heartbeat while time is slow
      if (state.over) { mode = 'over'; overT = 45; Input.takeAny(); }
    } else {
      if (overT > 0) { overT--; Input.takeAny(); Input.lastTap(); }
      else if (Input.takeAny()) { Input.lastTap(); start(); }
    }
    Input.styleKey();
    View.tickFx(mode === 'play' && (state.bt || state.slowT > 0) ? 0.25 : 1);
  }

  function frame(now) {
    const dt = Math.min(0.1, (now - last) / 1000 || 0); last = now;
    acc += dt;
    while (acc >= Sim.TICK) { tick(); acc -= Sim.TICK; }
    fpsT += dt; fpsN++;
    if (fpsT >= 0.5) {
      fps = Math.round(fpsN / fpsT); fpsT = 0; fpsN = 0;
      // dynamic resolution: if the phone cannot hold the frame rate, draw fewer pixels rather than stutter
      if (mode === 'play' && ++warm > 4) {
        lowRuns = fps < 48 ? lowRuns + 1 : 0;
        if (lowRuns >= 3 && quality > 1) { quality -= 0.5; lowRuns = 0; warm = 0; resize(); }
      }
    }
    let panel = null;
    const touch = coarse || Input.touch();
    if (mode === 'title') {
      panel = {
        title: 'BULLET-TIME PROTOTYP', foot: touch ? 'ŤUKNI A HRAJ' : 'KLIKNI NEBO STISKNI KLÁVESU',
        lines: touch
          ? ['LEVÝ PALEC: POHYB', 'PRAVÝ PALEC: TAŽENÍM MÍŘÍŠ A STŘÍLÍŠ', 'PLAVMO: SKOK VE ZPOMALENÉM ČASE TAM, KAM DRŽÍŠ LEVOU PÁČKU', 'DOJDI K VÝCHODU VPRAVO']
          : ['WASD POHYB · MEZERNÍK SKOK · MYŠ MÍŘÍ A STŘÍLÍ', 'SHIFT: SKOK PLAVMO VE ZPOMALENÉM ČASE VE SMĚRU POHYBU', 'Q NEBO PRAVÉ TLAČÍTKO: ZPOMALENÝ ČAS', 'DOJDI K VÝCHODU VPRAVO'],
      };
    } else if (mode === 'over') {
      panel = {
        title: 'KONEC', foot: overT > 0 ? '' : (touch ? 'ŤUKNI PRO NOVOU HRU' : 'KLIKNI PRO NOVOU HRU'),
        lines: [`STRÁNKA ${state.page} · ${state.kills} ZABITÍ`, `${state.btKills} VE ZPOMALENÉM ČASE · NEJDELŠÍ ŠŇŮRA ×${state.best}`],
      };
    }
    let hint = null, pulse = null;
    if (mode === 'play' && state.enemies.some(e => e.active)) {
      if (!used.dive) { hint = touch ? 'PLAVMO! A STŘÍLEJ ZA LETU' : 'SHIFT: SKOK PLAVMO. STŘÍLEJ ZA LETU'; pulse = 'dive'; }
      else if (!used.bt && state.meter > 0.3) { hint = touch ? 'ZPOMAL ČAS, KDY CHCEŠ' : 'Q: ZPOMAL ČAS, KDY CHCEŠ'; pulse = 'bt'; }
    }
    View.draw(ctx, state, L, { touch, sticks: Input.sticks(), panel, hint, pulse, interp: { a: mode === 'play' ? acc / Sim.TICK : 1, prev, dt, fps } });
    requestAnimationFrame(frame);
  }
  // wait for the embedded lettering font so the first frame is not drawn in a fallback face
  const go = () => requestAnimationFrame(frame);
  if (document.fonts && document.fonts.load) Promise.race([document.fonts.load('20px Bangers', 'ŽČŘ'), new Promise(r => setTimeout(r, 1500))]).then(go, go); else go();

  // hooks for automated screenshots
  window.__game = {
    start, state: () => state,
    // writes the placeholder sheets in the layout documented for the real art
    exportSheets() {
      const F = SPR.F, P = SPR.PPM, out = {};
      const mk = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return [c, c.getContext('2d')]; };
      const cell = (g, col, row, o, flat) => { g.save(); g.translate(col * F, row * F); g.beginPath(); g.rect(0, 0, F, F); g.clip(); g.scale(P, P); Art.figure(g, Object.assign({ f: 1, t: 0, id: col + 1, vx: 0, vy: 0, aim: null }, o, flat ? { x: 1.28, y: 1.28, dir: [1, 0] } : { x: SPR.FEET_X / P, y: SPR.FEET_Y / P })); g.restore(); };
      let [c, g] = mk(8 * F, 4 * F);
      for (let i = 0; i < 4; i++) cell(g, i, 0, { pose: 'stand', kind: 'player', part: 'body', t: i * 0.4 });
      for (let i = 0; i < 8; i++) cell(g, i, 1, { pose: 'run', kind: 'player', part: 'body', phase: i / 8, vx: 6, t: i * 0.2 });
      for (let i = 0; i < 4; i++) cell(g, i, 2, { pose: 'air', kind: 'player', part: 'body', vy: i < 2 ? -5 : 5, t: i * 0.2 });
      for (let i = 0; i < 6; i++) cell(g, i, 3, { pose: 'dive', kind: 'player', part: 'body', vx: 10, vy: (i - 2.5) * 3, t: i * 0.2 }, true);
      for (let i = 6; i < 8; i++) cell(g, i, 3, { pose: 'prone', kind: 'player', part: 'body', t: i * 0.2 }, true);
      out.player_sheet = c.toDataURL('image/png');
      [c, g] = mk(8 * F, 6 * F);
      [['grunt', 0], ['brok', 3]].forEach(([kind, r0]) => {
        for (let i = 0; i < 4; i++) cell(g, i, r0, { pose: 'stand', kind, part: 'body', t: i * 0.4 });
        for (let i = 0; i < 8; i++) cell(g, i, r0 + 1, { pose: 'run', kind, part: 'body', phase: i / 8, vx: 4, t: i * 0.2 });
        for (let i = 0; i < 2; i++) cell(g, i, r0 + 2, { pose: 'air', kind, part: 'body', vy: i ? 5 : -5, t: i * 0.2 });
        for (let i = 2; i < 6; i++) cell(g, i, r0 + 2, { pose: 'dead', kind, t: i * 0.2 }, true);
      });
      out.enemy_sheet = c.toDataURL('image/png');
      [c, g] = mk(3 * SPR.ARM_W, SPR.ARM_H);
      ['player', 'grunt', 'brok'].forEach((kind, i) => { g.save(); g.translate(i * SPR.ARM_W, 0); g.beginPath(); g.rect(0, 0, SPR.ARM_W, SPR.ARM_H); g.clip(); g.scale(P, P); Art.figure(g, { x: SPR.ARM_PX / P - 0.0415, y: SPR.ARM_PY / P + 1.37, f: 1, pose: 'stand', aim: [1, 0], kind, part: 'arms', t: 0, id: 0 }); g.restore(); });
      out.arms_sheet = c.toDataURL('image/png');
      out.props_sheet = Art.propsTemplate().toDataURL('image/png');
      out.bg_manhattan_far = Art.farTemplate().toDataURL('image/png');
      return out;
    },
    run(n, inp) { for (let i = 0; i < n; i++) { Sim.step(state, typeof inp === 'function' ? inp(i, state) : inp); View.onEvents(state.events); View.tickFx(state.bt ? 0.25 : 1); } },
  };
})();
