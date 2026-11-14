# Sounds for what the story shows (cutscene panels) and two more music stems that follow the fight.
# Kept apart from sfx.py so its random music stays as it is. Same helpers, same 72 BPM, 16-bar loop,
# so the new stems run in step with music_base and music_lead.
import sys, numpy as np
sys.argv = ['x']
src = open(__file__.replace('sfx_story.py', 'sfx.py')).read()
exec(src.split('# ---- music')[0].split('def gunshot')[0])
from scipy import signal
rng = np.random.default_rng(23)

def save_loop(name, x, peak):
    n = len(x); f = int(SR * 0.4)   # crossfade the end into the start so it loops without a seam
    y = x[:n - f].copy(); y[:f] = y[:f] * np.linspace(0, 1, f) + x[n - f:] * np.linspace(1, 0, f)
    save(name, y, peak)

# ---- one-shots -------------------------------------------------------------------------------
# a fist on a heavy plank door: the boom of the boards and the knuckle on top
def knock(p=1.0):
    tt = t(0.6)
    body = np.sin(2 * np.pi * 95 * p * tt) * np.exp(-tt / 0.08) + 0.5 * np.sin(2 * np.pi * 210 * p * tt) * np.exp(-tt / 0.05)
    knuckle = env(bp(noise(0.6), 400 * p, 2200 * p), 0.001, 0.012)
    return reverb(np.tanh((body + knuckle * 1.4) * 1.5), 0.9, 0.35, 2500)
save('knock.wav', np.concatenate([knock(1.0), np.zeros(1)]), 0.8)

# 1940s mechanical siren, far off, rising and falling (a loop)
tt = t(6.0)
f = 520 + 520 * (0.5 - 0.5 * np.cos(2 * np.pi * tt / 6.0))
ph = 2 * np.pi * np.cumsum(f) / SR
x = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph)
x = lp(x, 2200) * (0.85 + 0.15 * np.sin(2 * np.pi * 0.3 * tt))
save_loop('siren.wav', reverb(np.concatenate([x, x[:int(SR * 0.4)]]), 1.0, 0.4, 2000)[:int(SR * 6.4)], 0.45)

# a club full of people talking low: murmur that never makes words, a glass now and then (a loop)
sec = 10.4
x = np.zeros(int(SR * sec))
for k in range(140):   # syllables from many mouths: short formant blips
    at = rng.uniform(0, sec - 0.4); d = rng.uniform(0.08, 0.25)
    f1 = rng.uniform(300, 800); f2 = rng.uniform(900, 2400)
    s = bp(noise(d), f1 * 0.8, f1 * 1.2) + 0.6 * bp(noise(d), f2 * 0.85, f2 * 1.15)
    s *= np.sin(np.pi * t(d) / d) ** 2 * rng.uniform(0.3, 1.0)
    i = int(at * SR); x[i:i + len(s)] += s
for k in range(5):
    at = int(rng.uniform(0.5, sec - 1.0) * SR); tt2 = t(0.8)
    g = sum(np.sin(2 * np.pi * fr * tt2) * np.exp(-tt2 * dc) for fr, dc in ((2600, 9), (4100, 14), (5900, 20))) * 0.08
    x[at:at + len(g)] += g
save_loop('crowd.wav', reverb(lp(x, 3500), 1.2, 0.45, 2500)[:int(SR * sec)], 0.4)

# water slapping the pilings under a pier (a loop)
sec = 8.4; tt = t(sec)
swell = 0.5 + 0.5 * np.sin(2 * np.pi * tt / 4.2) ** 2
x = lp(noise(sec), 500) * swell * 0.6
for k in range(9):
    at = int(rng.uniform(0, sec - 0.6) * SR); d = rng.uniform(0.2, 0.5)
    s = env(bp(noise(d), 250, 1800), 0.01, d / 3) * rng.uniform(0.4, 1.0)
    x[at:at + len(s)] += s
save_loop('water.wav', x, 0.4)

# a ship's foghorn across the river
tt = t(3.6)
f = 98
x = sum(a * np.sin(2 * np.pi * f * k * tt) for k, a in ((1, 1.0), (2, 0.7), (3, 0.5), (4, 0.3), (5, 0.18), (7, 0.08)))
x *= np.minimum(1, tt / 0.25) * np.clip((3.0 - tt) / 0.6, 0, 1)
save('foghorn.wav', reverb(lp(np.tanh(x * 0.8), 1200), 3.0, 0.6, 1500), 0.55)

# handcuffs: the ratchet teeth, then the clack shut
x = np.zeros(int(SR * 0.9))
for k in range(9):
    s = env(bp(noise(0.05), 2500, 7000), 0.0005, 0.004)
    i = int((0.08 + k * 0.035) * SR); x[i:i + len(s)] += s
tt = t(0.4); clack = (np.sin(2 * np.pi * 1900 * tt) * np.exp(-tt * 40) + env(bp(noise(0.4), 1500, 6000), 0.0005, 0.01)) * 1.4
i = int(0.45 * SR); x[i:i + len(clack)] += clack[:len(x) - i]
save('cuffs.wav', reverb(x, 0.5, 0.15, 5000), 0.55)

# a wooden desk drawer pulled open, stopping hard
tt = t(0.75)
fric = bp(noise(0.75), 180, 1400) * (0.6 + 0.4 * np.sin(2 * np.pi * 37 * tt)) * np.clip(tt / 0.05, 0, 1) * np.clip((0.55 - tt) / 0.05, 0, 1)
stop = np.zeros_like(tt); s = env(np.sin(2 * np.pi * 120 * t(0.2)) + bp(noise(0.2), 300, 2000), 0.001, 0.03)
i = int(0.55 * SR); stop[i:i + len(s)] = s[:len(stop) - i]
save('drawer.wav', reverb(fric * 0.5 + stop, 0.5, 0.2, 3000), 0.5)

# a punch landing: the slap and the thump in the chest
tt = t(0.4)
x = env(bp(noise(0.4), 800, 5000), 0.0005, 0.015) * 1.2 + np.sin(2 * np.pi * 75 * tt * np.exp(-tt * 4)) * np.exp(-tt / 0.07)
save('punch.wav', reverb(np.tanh(x * 2), 0.6, 0.25, 3000), 0.7)

# a coffee cup set down on its saucer
tt = t(0.6)
x = sum(np.sin(2 * np.pi * fr * tt) * np.exp(-tt * dc) for fr, dc in ((2200, 18), (3300, 25), (4700, 35))) * 0.5 + env(bp(noise(0.6), 1000, 6000), 0.0005, 0.006)
save('cup.wav', reverb(x, 0.4, 0.15, 5000), 0.45)

# a revolver's hammer drawn back: two clicks
x = np.zeros(int(SR * 0.5))
for at, p in ((0.05, 1.0), (0.2, 1.35)):
    s = env(bp(noise(0.08), 1800 * p, 7000), 0.0003, 0.006) + np.sin(2 * np.pi * 3100 * p * t(0.08)) * np.exp(-t(0.08) * 120) * 0.5
    i = int(at * SR); x[i:i + len(s)] += s
save('hammer.wav', reverb(x, 0.4, 0.15, 6000), 0.55)

# two glasses touching for a toast
tt = t(1.4)
x = sum(np.sin(2 * np.pi * fr * tt) * np.exp(-tt * dc) for fr, dc in ((2350, 4), (2410, 4.5), (5600, 9), (7900, 14)))
save('toast.wav', reverb(x, 0.6, 0.2, 7000), 0.4)

# old timber groaning in the heat
tt = t(1.6)
f = 140 + 60 * np.sin(2 * np.pi * 0.7 * tt) + rng.standard_normal(len(tt)).cumsum() * 0.02
ph = 2 * np.pi * np.cumsum(f) / SR
x = signal.sawtooth(ph) * (0.5 + 0.5 * (rng.random(len(tt)) > 0.6)) * np.sin(np.pi * tt / 1.6) ** 2
save('creak.wav', reverb(bp(x, 150, 1800), 0.8, 0.3, 2000), 0.4)

# the fight is over: a low, soft D minor chord with a held bass
def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
tt = t(3.5)
x = np.zeros_like(tt)
for m in (38, 50, 53, 57, 60, 64):
    f = hz(m); x += (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt) * np.exp(-tt / 0.4)) * np.exp(-tt / 1.6)
x *= np.minimum(1, tt / 0.01)
save('resolve.wav', reverb(lp(x, 2500), 2.0, 0.4, 2500), 0.4)

# ---- the music: two more stems in step with music_base -------------------------------------
BPM = 72; BEAT = 60.0 / BPM; BARS = 16
LEN = int(SR * BEAT * 4 * BARS)
def wrap_add(buf, at, snd):
    s0 = int(at) % LEN; n = len(snd); e = min(LEN, s0 + n); buf[s0:e] += snd[:e - s0]
    if s0 + n > LEN: buf[:s0 + n - LEN] += snd[e - s0:]
ROOTS = [38, 38, 43, 43, 38, 46, 45, 45, 43, 43, 38, 48, 46, 45, 38, 45]   # the bass roots of the tune

# tension: a bowed low drone on the root with a slow tremolo, a pizzicato pulse, a thin high cluster
tense = np.zeros(LEN)
for b, r in enumerate(ROOTS):
    d = BEAT * 4.2; tt = t(d); f = hz(r - 12)
    ph = 2 * np.pi * f * tt
    drone = (signal.sawtooth(ph) * 0.6 + signal.sawtooth(ph * 2.003) * 0.3) * (0.75 + 0.25 * np.sin(2 * np.pi * 5.5 * tt))
    drone = lp(drone, 500) * np.minimum(1, tt / 0.6) * np.clip((d - tt) / 0.6, 0, 1)
    wrap_add(tense, b * 4 * BEAT * SR, drone * 0.35)
    for k in (0, 1.5, 2, 3.5):   # pizzicato: the root an octave up, uneven, uneasy
        tt2 = t(0.5); p = np.sin(2 * np.pi * hz(r) * tt2) * np.exp(-tt2 / 0.09) + env(bp(noise(0.5), 300, 1500), 0.001, 0.01) * 0.3
        wrap_add(tense, (b * 4 + k) * BEAT * SR, lp(p, 1500) * 0.45)
    if b % 4 == 2:
        tt3 = t(BEAT * 6); hi = sum(np.sin(2 * np.pi * hz(m) * tt3) for m in (86, 87, 93)) * np.sin(np.pi * tt3 / tt3[-1]) ** 2
        wrap_add(tense, b * 4 * BEAT * SR, hi * 0.03)

# fight: drums and low brass stabs (kick on one and three, rim on two and four, swung ghosts, fills)
fight = np.zeros(LEN)
def kick():
    tt = t(0.4); return np.sin(2 * np.pi * 55 * tt * np.exp(-tt * 9) * 3) * np.exp(-tt / 0.12) + env(bp(noise(0.4), 1000, 4000), 0.0005, 0.004) * 0.3
def snare(a=1.0):
    tt = t(0.3); return (env(bp(noise(0.3), 1500, 7000), 0.0005, 0.06) + np.sin(2 * np.pi * 190 * tt) * np.exp(-tt / 0.04) * 0.5) * a
def tom(f):
    tt = t(0.5); return np.sin(2 * np.pi * f * tt * (1 + 0.3 * np.exp(-tt * 20))) * np.exp(-tt / 0.15)
def stab(m, d):
    tt = t(d); ph = 2 * np.pi * hz(m) * tt
    x = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.4 * np.sin(3 * ph) + 0.25 * np.sin(4 * ph)
    return lp(np.tanh(x * 1.5) * np.minimum(1, tt / 0.02) * np.exp(-tt / (d / 2.5)), 2200)
for b, r in enumerate(ROOTS):
    for k in range(4):
        if k in (0, 2):
            wrap_add(fight, (b * 4 + k) * BEAT * SR, kick() * 0.9)
        if k in (1, 3):
            wrap_add(fight, (b * 4 + k) * BEAT * SR, snare(0.8))
        wrap_add(fight, (b * 4 + k + 0.66) * BEAT * SR, snare(0.18))
        wrap_add(fight, (b * 4 + k) * BEAT * SR, env(hp(noise(0.3), 7000), 0.001, 0.05) * 0.12)
    if b % 4 == 3:   # a tom fill into the next phrase
        for j, f in enumerate((180, 150, 120, 95)):
            wrap_add(fight, (b * 4 + 3 + j * 0.25) * BEAT * SR, tom(f) * 0.6)
    if b % 2 == 0:   # the band hits with the drums: two short low brass stabs
        wrap_add(fight, (b * 4) * BEAT * SR, stab(r + 12, 0.35) * 0.5)
        wrap_add(fight, (b * 4 + 2.66) * BEAT * SR, stab(r + 15, 0.25) * 0.4)

def wet(x, sec, mix):
    ir_n = int(SR * sec); ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / (SR * sec / 5))
    y = signal.fftconvolve(np.concatenate([x, x]), lp(ir, 3000))[:2 * LEN]
    y = y[LEN:2 * LEN]
    return x * (1 - mix) + y / np.max(np.abs(y)) * np.max(np.abs(x)) * mix
for name, x, mix in (('music_tension', tense, 0.35), ('music_fight', fight, 0.18)):
    x = wet(x, 1.8, mix)
    x = x / np.max(np.abs(x)) * 0.7
    wavfile.write(OUT + name + '.wav', SR, (x * 32767).astype(np.int16)); print(name, round(LEN / SR, 1))
