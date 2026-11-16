# Synthesised sound effects for INK & LEAD: a 1940s revolver, wet pavement, rain, slowed time.
import numpy as np
from scipy import signal
from scipy.io import wavfile
from paths import REPO
SR = 44100
OUT = REPO + 'sfx/'
rng = np.random.default_rng(4)

def t(sec): return np.arange(int(SR * sec)) / SR
def noise(sec): return rng.standard_normal(int(SR * sec))
def env(x, attack, decay):
    n = len(x); tt = np.arange(n) / SR
    e = np.minimum(1.0, tt / max(attack, 1e-4)) * np.exp(-tt / decay)
    return x * e
def bp(x, lo, hi, order=2): return signal.sosfilt(signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos'), x)
def lp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, 'lowpass', fs=SR, output='sos'), x)
def hp(x, f, order=2): return signal.sosfilt(signal.butter(order, f, 'highpass', fs=SR, output='sos'), x)
def pad(x, sec): return np.concatenate([x, np.zeros(int(SR * sec) - len(x))]) if len(x) < SR * sec else x[:int(SR * sec)]
def reverb(x, sec=1.2, wet=0.25, bright=4000):
    # a wet alley: exponentially decaying filtered noise as the impulse response
    ir = lp(noise(sec), bright) * np.exp(-np.arange(int(SR * sec)) / SR / (sec / 5))
    ir[:int(SR * 0.012)] = 0
    x = x.copy(); f = int(SR * 0.04); x[-f:] *= np.linspace(1, 0, f)   # no click where the dry sound stops
    y = signal.fftconvolve(x, ir)[:len(x) + len(ir) - 1]
    y = y / (np.max(np.abs(y)) + 1e-9)
    dry = np.concatenate([x, np.zeros(len(y) - len(x))])
    return dry + wet * y * np.max(np.abs(x))
def save(name, x, peak=0.89):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    fade = int(SR * 0.01); x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(OUT + name, SR, (x * 32767).astype(np.int16)); print(name, round(len(x) / SR, 2))

def gunshot(pitch=1.0, body=1.0, tail=1.3):
    crack = env(hp(noise(0.25), 1500), 0.0005, 0.012)
    blast = env(bp(noise(0.5), 150 * pitch, 3000 * pitch), 0.001, 0.06)
    thump = env(np.sin(2 * np.pi * 70 * pitch * t(0.4) * np.exp(-t(0.4) * 6)), 0.002, 0.09) * body
    x = pad(crack, 0.5) * 0.8 + pad(blast, 0.5) * 1.0 + pad(thump, 0.5) * 1.2
    x = np.tanh(x * 2.5)
    return reverb(pad(x, tail), tail, 0.5, 2500)

save('shot_player.wav', gunshot(1.0, 1.3, 1.4))
save('shot_enemy.wav', gunshot(1.25, 0.9, 1.2), 0.75)

# flesh hit: a dull thud and a wet slap
th = env(np.sin(2 * np.pi * 95 * t(0.3) * np.exp(-t(0.3) * 4)), 0.001, 0.05)
wet = env(bp(noise(0.3), 300, 1800), 0.002, 0.04)
save('hit_flesh.wav', reverb(pad(th * 1.2 + wet * 0.8, 0.3), 0.4, 0.15))

# into wood or metal cover: a crack and a ricochet whine sliding down
crack = env(bp(noise(0.2), 800, 6000), 0.0005, 0.02)
tt = t(0.5); fr = 3200 * np.exp(-tt * 2.2) + 900
whine = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-tt * 5) * np.minimum(1, tt / 0.03)
save('hit_cover.wav', reverb(pad(crack, 0.5) + 0.35 * whine, 0.5, 0.2), 0.7)

# bullet meets bullet: a bright clink of two struck pieces of metal
x = np.zeros(int(SR * 0.9))
for f, a, d in [(2650, 1.0, 0.25), (4120, 0.7, 0.18), (5870, 0.5, 0.12), (1730, 0.4, 0.3)]:
    x += a * np.sin(2 * np.pi * f * t(0.9)) * np.exp(-t(0.9) / d)
x[:int(SR * 0.004)] += env(hp(noise(0.004), 3000), 0.0001, 0.002)
save('clink.wav', reverb(x, 0.9, 0.3), 0.75)

# spent casing bouncing on wet stone: three little pings, each quieter
x = np.zeros(int(SR * 0.7))
for i, (dt, a) in enumerate([(0.0, 1.0), (0.13, 0.55), (0.22, 0.3)]):
    s = int(SR * dt); seg = t(0.2)
    ping = sum(np.sin(2 * np.pi * f * seg) * np.exp(-seg / dd) for f, dd in [(5200, 0.05), (7600, 0.03), (3300, 0.06)]) * np.minimum(1, seg / 0.0015)
    x[s:s + len(seg)] += a * ping
save('casing.wav', x, 0.35)

# slowed time: a deep falling whoosh in, a rising one out
tt = t(1.1)
sweep = np.sin(2 * np.pi * np.cumsum(220 * np.exp(-tt * 2.2) + 40) / SR)
air = lp(noise(1.1), 900) * np.exp(-tt * 1.8)
save('slow_in.wav', reverb((sweep * 0.8 + air * 0.6) * np.minimum(1, tt / 0.02) * np.exp(-tt * 1.6), 1.0, 0.4), 0.8)
sweep = np.sin(2 * np.pi * np.cumsum(50 + 160 * (1 - np.exp(-tt * 3))) / SR)
air = lp(noise(1.1), 1500) * (1 - np.exp(-tt * 4))
save('slow_out.wav', (sweep * 0.6 + air * 0.5) * np.exp(-tt * 3.0) * np.minimum(1, tt / 0.05), 0.6)

# a dive: coat and air rushing past
tt = t(0.6)
x = bp(noise(0.6), 250, 2200) * np.sin(np.pi * np.minimum(tt / 0.6, 1)) ** 1.5
save('dive.wav', x, 0.55)

# landing / a body hitting the pavement
def thud(f=60, sec=0.5, splash=0.5):
    tt = t(sec)
    b = np.sin(2 * np.pi * f * tt * np.exp(-tt * 3)) * np.exp(-tt / 0.08)
    s = env(bp(noise(sec), 600, 5000), 0.003, 0.06)   # wet pavement
    return reverb(b + splash * s, 0.5, 0.15)
save('land.wav', thud(70, 0.4, 0.6), 0.6)
save('body_fall.wav', thud(48, 0.8, 0.8), 0.85)

# footsteps on wet stone, two of them so they alternate
for i in range(2):
    tt = t(0.18)
    step = env(bp(noise(0.18), 180 + i * 40, 900), 0.002, 0.03) * 0.8 + env(bp(noise(0.18), 2500, 7000), 0.01, 0.04) * 0.5
    save(f'step{i + 1}.wav', step, 0.3)

# an enemy bullet passing close: a short whistle with doppler fall
tt = t(0.35)
fr = 1800 - 900 * tt / 0.35
w = bp(noise(0.35), 900, 3500) * np.sin(np.pi * tt / 0.35) ** 2 + 0.25 * np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.sin(np.pi * tt / 0.35) ** 3
save('whiz.wav', w, 0.5)

# the detective goes down: a low brass-like stab, minor and fading
tt = t(3.0)
x = np.zeros_like(tt)
for f in [55, 65.4, 82.4, 98]:   # A minor-ish with a flat
    for h, a in [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)]:
        x += a * np.sin(2 * np.pi * f * h * tt + rng.uniform(0, 6))
x = lp(np.tanh(x * 0.6), 1400) * np.minimum(1, tt / 0.04) * np.exp(-tt / 0.9)
save('death_sting.wav', reverb(x, 2.5, 0.5), 0.8)

# a barrel going up: a cracking blast, a deep body and a long rolling tail
tt = t(2.5)
blast = env(lp(noise(2.5), 2500), 0.002, 0.25) * 1.2
body = np.sin(2 * np.pi * 42 * tt * np.exp(-tt * 0.8)) * np.exp(-tt / 0.5)
crackle = env(hp(noise(2.5), 2000), 0.001, 0.05) * 0.6
save('explosion.wav', reverb(np.tanh((blast + body + crackle) * 2.0), 2.0, 0.6, 1800), 0.95)

# a lamp shot out: glass bursting and tinkling down
x = env(hp(noise(0.9), 3000), 0.0005, 0.03)
for k in range(14):
    s0 = int(SR * rng.uniform(0.03, 0.6)); seg = t(0.08)
    f0 = rng.uniform(3500, 8000)
    x[s0:s0 + len(seg)] += rng.uniform(0.15, 0.5) * np.sin(2 * np.pi * f0 * seg) * np.exp(-seg / 0.015)
save('glass.wav', reverb(x, 0.6, 0.2), 0.6)

# picking up a gun: a metallic double click
x = np.zeros(int(SR * 0.4))
for dt0, f0 in [(0.0, 2200), (0.11, 1600)]:
    s0 = int(SR * dt0); seg = t(0.06)
    x[s0:s0 + len(seg)] += env(bp(noise(0.06), f0, f0 * 3), 0.0005, 0.008) + 0.3 * np.sin(2 * np.pi * f0 * seg) * np.exp(-seg / 0.01)
save('pickup.wav', x, 0.6)

# a pull from the flask: cap, two swallows, a breath out
x = np.zeros(int(SR * 1.1))
x[:int(SR * 0.05)] += env(bp(noise(0.05), 1500, 5000), 0.0005, 0.006)
for dt0 in (0.25, 0.55):
    s0 = int(SR * dt0); seg = t(0.18)
    x[s0:s0 + len(seg)] += env(bp(noise(0.18), 200, 700), 0.02, 0.05) * 0.8
s0 = int(SR * 0.8); x[s0:] += env(bp(noise(len(x[s0:]) / SR), 400, 2500), 0.05, 0.12)[:len(x) - s0] * 0.4
save('drink.wav', x, 0.5)

# a tommy gun burst and a shotgun: built from the shot, quicker and heavier
# a flock taking off: a rush of wingbeats, each a soft papery clap, thinning out as they climb
x = np.zeros(int(SR * 1.6))
for k in range(26):
    at = int(SR * (rng.random() ** 1.6) * 1.1)
    clap = bp(noise(0.05), 500, 3500) * env(noise(0.05) * 0 + 1, 0.004, 0.035)
    x[at:at + len(clap)] += clap * (1 - at / len(x)) * rng.uniform(0.5, 1.0)
save('flutter.wav', reverb(lp(x, 4000), 0.5, 0.15), 0.55)
save('shot_tommy.wav', gunshot(1.35, 0.7, 0.6), 0.7)
save('shot_shotgun.wav', gunshot(0.8, 1.6, 1.5), 0.95)

# rain on the street, seamless loop: hiss, a steady patter of drops, gutter trickle
sec = 8.0; n = int(SR * sec)
hiss = lp(hp(noise(sec), 600), 7000) * 0.35
drops = np.zeros(n)
for k in range(int(sec * 140)):
    s = rng.integers(0, n - 2000); f = rng.uniform(1500, 6000); seg = np.arange(1200) / SR
    drops[s:s + 1200] += rng.uniform(0.05, 0.25) * np.sin(2 * np.pi * f * seg) * np.exp(-seg / 0.004)
trickle = bp(noise(sec), 300, 900) * 0.15 * (1 + 0.3 * np.sin(2 * np.pi * 0.3 * np.arange(n) / SR))
x = hiss + drops + trickle
cross = int(SR * 0.5)   # crossfade the ends so it loops without a click
x[:cross] = x[:cross] * np.linspace(0, 1, cross) + x[-cross:] * np.linspace(1, 0, cross)
x = x[:-cross]
x = x / np.max(np.abs(x)) * 0.5
wavfile.write(OUT + 'rain_loop.wav', SR, (x * 32767).astype(np.int16)); print('rain_loop.wav', len(x) / SR)


# ---- guns running dry and being reloaded --------------------------------------------------
def tick(f0, dec=0.008, amp=1.0, band=(1500, 9000)):
    seg = t(0.08)
    return amp * (env(bp(noise(0.08), *band), 0.0003, dec) + 0.35 * np.sin(2 * np.pi * f0 * seg) * np.exp(-seg / (dec * 1.5)))

def place(x, at, snd, amp=1.0):
    s0 = int(SR * at); e0 = min(len(x), s0 + len(snd)); x[s0:e0] += amp * snd[:e0 - s0]

# the hammer falling on an empty chamber: one dry, sharp metal click
x = np.zeros(int(SR * 0.25)); place(x, 0.0, tick(4200, 0.006)); place(x, 0.012, tick(2600, 0.01, 0.5))
save('dry_fire.wav', reverb(x, 0.3, 0.12), 0.7)

# revolver: the latch, the cylinder swings out, empties rattle out, six rounds pushed in, snapped shut
x = np.zeros(int(SR * 1.3))
place(x, 0.0, tick(2400, 0.01)); place(x, 0.06, tick(1800, 0.02, 0.6, (600, 4000)))
for k in range(6):
    place(x, 0.16 + rng.uniform(0, 0.18), tick(rng.uniform(3500, 6000), 0.03, 0.35, (2500, 9000)))
for k in range(6):
    place(x, 0.5 + k * 0.085 + rng.uniform(-0.01, 0.01), tick(rng.uniform(1800, 2600), 0.012, 0.45, (900, 5000)))
place(x, 1.12, tick(1500, 0.02, 1.1, (500, 6000)))
save('reload_revolver.wav', reverb(x, 0.4, 0.12), 0.7)

# a magazine: release, out with a slide, the new one seated with a thunk, the bolt racked
x = np.zeros(int(SR * 1.7))
place(x, 0.0, tick(2800, 0.008))
seg = env(bp(noise(0.12), 800, 4000), 0.01, 0.05); place(x, 0.05, seg, 0.5)
place(x, 0.7, tick(700, 0.03, 1.2, (200, 2500)))
seg = env(bp(noise(0.1), 1000, 6000), 0.005, 0.04); place(x, 1.3, seg, 0.7)
place(x, 1.42, tick(1300, 0.02, 1.0, (400, 6000)))
save('reload_mag.wav', reverb(x, 0.4, 0.12), 0.75)

# shotgun: shells thumbed in one by one, then the pump
x = np.zeros(int(SR * 1.7))
for k in range(4):
    place(x, 0.15 + k * 0.28, tick(1100, 0.018, 0.8, (400, 4000)))
    place(x, 0.2 + k * 0.28, env(bp(noise(0.06), 1500, 6000), 0.005, 0.02), 0.3)
place(x, 1.35, env(bp(noise(0.12), 400, 3000), 0.01, 0.05), 0.8)
place(x, 1.5, tick(900, 0.025, 1.2, (300, 5000)))
save('reload_shells.wav', reverb(x, 0.4, 0.12), 0.8)

# ready again: a soft metallic settle
x = np.zeros(int(SR * 0.2)); place(x, 0.0, tick(3200, 0.012, 0.6))
save('reload_done.wav', x, 0.35)

# ---- the street ---------------------------------------------------------------------------
def loop(x, cross=0.3):
    c = int(SR * cross)
    x[:c] = x[:c] * np.linspace(0, 1, c) + x[-c:] * np.linspace(1, 0, c)
    return x[:-c]

def save_loop(name, x, peak):
    x = x / np.max(np.abs(x)) * peak
    wavfile.write(OUT + name, SR, (x * 32767).astype(np.int16)); print(name, round(len(x) / SR, 2))

# neon: the transformer's 120 Hz hum with its buzzy harmonics and the odd crackle in the tube
sec = 3.0; tt = t(sec)
x = sum(a * np.sin(2 * np.pi * 120 * h * tt + rng.uniform(0, 6)) for h, a in [(1, 1.0), (2, 0.6), (3, 0.45), (5, 0.25), (7, 0.15)])
x = np.tanh(x * 1.5) * (1 + 0.08 * np.sin(2 * np.pi * 0.7 * tt))
crk = np.zeros_like(tt)
for k in range(12):
    s0 = rng.integers(0, len(tt) - 3000); crk[s0:s0 + 3000] += env(hp(noise(3000 / SR), 3000), 0.0005, 0.004)[:3000] * rng.uniform(0.2, 0.8)
save_loop('neon_hum.wav', loop(bp(x, 100, 3000) * 0.6 + crk * 0.5), 0.6)

# a street lamp's quieter mains hum
sec = 3.0; tt = t(sec)
x = np.sin(2 * np.pi * 60 * tt) + 0.5 * np.sin(2 * np.pi * 120 * tt) + 0.2 * np.sin(2 * np.pi * 180 * tt)
save_loop('lamp_hum.wav', loop(lp(np.tanh(x), 600)), 0.5)

# steam out of a manhole: a breathy hiss that swells and settles
sec = 4.0; tt = t(sec)
x = bp(noise(sec), 1500, 7000) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.35 * tt) ** 2)
save_loop('steam.wav', loop(x, 0.5), 0.5)

# the city behind it all: a low traffic rumble, a horn far off, a train on the El going by
sec = 24.0; tt = t(sec)
x = lp(noise(sec), 180) * 3.0
for at, f in [(5.0, 330), (5.35, 392), (16.0, 294)]:   # two-tone horns, far away
    seg = t(0.45); place(x, at, lp(np.sign(np.sin(2 * np.pi * f * seg)) * env(np.ones_like(seg), 0.03, 0.25), 1200), 0.12)
train = bp(noise(7.0), 60, 900) * np.sin(np.pi * t(7.0) / 7.0) ** 2 * (1 + 0.4 * np.sign(np.sin(2 * np.pi * 3.2 * t(7.0))))
place(x, 9.0, train, 0.6)
save_loop('city.wav', loop(lp(x, 1500), 1.0), 0.5)

# far thunder: a long low roll
tt = t(5.0)
x = lp(noise(5.0), 120) * np.exp(-tt / 1.6) * (1 + 0.6 * np.sin(2 * np.pi * 0.9 * tt) ** 2) * np.minimum(1, tt / 0.3)
save('thunder.wav', reverb(x * 3, 2.5, 0.4, 600), 0.8)

# a pigeon cooing: a soft throaty two-part "hoo-ooo"
x = np.zeros(int(SR * 0.9))
for at, f0, dur in [(0.0, 330, 0.18), (0.24, 300, 0.45)]:
    tt = t(dur); fr = f0 * (1 + 0.08 * np.sin(np.pi * tt / dur)) * (1 + 0.04 * np.sin(2 * np.pi * 28 * tt))
    v = np.sin(2 * np.pi * np.cumsum(fr) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(fr) / SR)
    place(x, at, lp(v, 900) * np.sin(np.pi * tt / dur) ** 1.5, 0.8)
save('coo.wav', reverb(x, 0.4, 0.15), 0.4)

# one flap of wings, for a bird passing close
x = np.zeros(int(SR * 0.3)); place(x, 0.0, env(bp(noise(0.08), 400, 3000), 0.006, 0.03)); place(x, 0.11, env(bp(noise(0.08), 400, 3000), 0.006, 0.03), 0.7)
save('wing.wav', x, 0.4)

# water dripping off a fire escape into a puddle
x = np.zeros(int(SR * 0.4)); seg = t(0.12)
place(x, 0.0, np.sin(2 * np.pi * (1300 + 900 * np.exp(-seg / 0.01)) * seg) * np.exp(-seg / 0.03))
save('drip.wav', reverb(x, 0.6, 0.3), 0.3)

# wood: a crate breaking, a dry crack and splinters rattling down
x = np.zeros(int(SR * 1.0))
place(x, 0.0, env(bp(noise(0.2), 300, 5000), 0.0005, 0.04), 1.2)
place(x, 0.0, np.sin(2 * np.pi * 110 * t(0.2)) * np.exp(-t(0.2) / 0.05), 0.8)
for k in range(16):
    place(x, rng.uniform(0.05, 0.7), tick(rng.uniform(600, 1800), 0.02, 0.35, (300, 3000)))
save('wood_break.wav', reverb(x, 0.6, 0.2), 0.85)

# a crate hit but holding: a hollow knock
x = np.zeros(int(SR * 0.3)); place(x, 0.0, tick(380, 0.03, 1.0, (150, 2500)))
save('wood_hit.wav', reverb(x, 0.3, 0.15), 0.6)

# an electric zap: a neon tube catching again, a lamp's filament dying
x = np.zeros(int(SR * 0.25)); tt = t(0.12)
place(x, 0.0, (hp(noise(0.12), 2500) * 0.6 + np.sign(np.sin(2 * np.pi * 120 * tt)) * 0.3) * np.exp(-tt / 0.04))
save('zap.wav', x, 0.45)

# slowed time: the heart heard from inside, a low double beat, seamless loop
sec = 1.0; x = np.zeros(int(SR * sec))
for at, a in [(0.0, 1.0), (0.22, 0.7)]:
    tt = t(0.18); place(x, at, np.sin(2 * np.pi * 48 * tt * (1 - 0.3 * tt / 0.18)) * np.exp(-tt / 0.05) * a)
save_loop('heartbeat.wav', lp(x, 300), 0.8)

# a typewriter key and the bell-less carriage nudge, for narration typing out
x = np.zeros(int(SR * 0.12)); place(x, 0.0, tick(1700, 0.006, 1.0, (800, 7000))); place(x, 0.01, tick(240, 0.02, 0.4, (100, 1200)))
save('type.wav', x, 0.35)

# a page of the case file turned over
tt = t(0.5)
x = bp(noise(0.5), 800, 6000) * np.sin(np.pi * tt / 0.5) ** 3 * (1 + 0.5 * np.sin(2 * np.pi * 9 * tt))
save('page.wav', x, 0.45)

# a body skidding over wet stones: cloth dragged through water, slowing down
tt = t(0.9)
x = bp(noise(0.9), 300, 3500) * np.exp(-tt / 0.35) * (1 + 0.3 * np.sin(2 * np.pi * 23 * tt)) + bp(noise(0.9), 2000, 7000) * 0.3 * np.exp(-tt / 0.2)
save('skid.wav', x, 0.5)

# ---- music: a slow noir jazz loop in D minor, two stems -------------------------------------
# base: walking upright bass, brushes and ride, sparse piano chords. lead: a muted horn line.
BPM = 72; BEAT = 60.0 / BPM; BARS = 16
LEN = int(SR * BEAT * 4 * BARS)
def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def wrap_add(buf, at, snd):
    s0 = int(at) % LEN
    n = len(snd)
    e = min(LEN, s0 + n); buf[s0:e] += snd[:e - s0]
    if s0 + n > LEN: buf[:s0 + n - LEN] += snd[e - s0:]
def bass_note(m, dur):
    tt = t(dur); f = hz(m)
    x = (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(4 * np.pi * f * tt) + 0.2 * np.sin(6 * np.pi * f * tt))
    x *= np.minimum(1, tt / 0.008) * np.exp(-tt / 0.55)
    x += env(bp(noise(dur), 200, 900), 0.002, 0.02) * 0.4   # the pluck
    return lp(x, 900)
def piano(ms, dur):
    tt = t(dur); x = np.zeros_like(tt)
    for m in ms:
        f = hz(m)
        x += (np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(4 * np.pi * f * tt) * np.exp(-tt / 0.3) + 0.15 * np.sin(6 * np.pi * f * tt) * np.exp(-tt / 0.15))
    return lp(x * np.minimum(1, tt / 0.004) * np.exp(-tt / 1.4), 2500) / len(ms)
def horn(m, dur):
    tt = t(dur); f = hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.2 * tt) * np.minimum(1, tt / 0.4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.12 * np.sin(5 * ph)
    x += bp(noise(dur), 1200, 3500) * 0.05   # breath
    a = np.minimum(1, tt / 0.09) * np.minimum(1, (dur - tt) / 0.25).clip(0, 1)
    return lp(x * a, 1800)
# chords per bar (piano voicings, midi) and the bass roots
CHORDS = [[50, 53, 57, 60, 64], [50, 53, 57, 60, 64], [43, 53, 58, 62, 65], [43, 53, 58, 62, 65],
          [50, 53, 57, 60, 64], [46, 50, 53, 57, 60], [45, 49, 52, 55, 58], [45, 49, 52, 55, 58],
          [43, 53, 58, 62, 65], [43, 53, 58, 62, 65], [50, 53, 57, 60, 64], [48, 52, 55, 58, 62],
          [46, 50, 53, 57, 60], [45, 49, 52, 55, 58], [50, 53, 57, 60, 64], [45, 49, 52, 55, 58]]
base = np.zeros(LEN); lead = np.zeros(LEN)
for b, ch in enumerate(CHORDS):
    root = ch[0] - 12 if ch[0] > 40 else ch[0]
    walk = [root, root + 3 if b % 2 == 0 else root + 7, root + 7, root + 5 if b % 2 == 0 else root + 10]
    for k in range(4):   # walking quarters
        wrap_add(base, (b * 4 + k) * BEAT * SR, bass_note(walk[k], BEAT * 1.1) * 0.8)
    if b % 2 == 0 or rng.random() < 0.4:   # a chord on the and of one, sometimes another on three
        wrap_add(base, (b * 4 + 0.66) * BEAT * SR, piano(ch[1:], BEAT * 3) * 0.32)
    if rng.random() < 0.35:
        wrap_add(base, (b * 4 + 2.66) * BEAT * SR, piano(ch[1:], BEAT * 2) * 0.22)
    for k in range(4):   # brushes: a sweep under every beat, a slap on two and four
        sweep = bp(noise(BEAT), 1500, 6000) * np.sin(np.pi * t(BEAT) / BEAT) ** 2 * 0.028
        wrap_add(base, (b * 4 + k) * BEAT * SR, sweep)
        if k in (1, 3):
            wrap_add(base, (b * 4 + k) * BEAT * SR, env(bp(noise(0.2), 1200, 5000), 0.003, 0.06) * 0.16)
        for sw in (0.0, 0.66):   # the ride, swung
            wrap_add(base, (b * 4 + k + sw) * BEAT * SR, env(hp(noise(0.5), 6000), 0.001, 0.12 if sw == 0 else 0.06) * (0.03 if sw == 0 else 0.018))
# the horn: a slow minor phrase, answered, with rests where the city can be heard
PHRASE = [(0, 69, 1.5), (1.5, 67, 0.5), (2, 65, 1), (3, 64, 1), (4, 62, 3), (8, 69, 1), (9, 72, 1.5), (10.5, 70, 0.5),
          (11, 69, 1), (12, 67, 2), (14, 65, 2), (20, 62, 1), (21, 65, 1), (22, 69, 2), (24, 70, 1.5), (25.5, 69, 0.5),
          (26, 67, 1), (27, 64, 1), (28, 61, 2.5), (32, 69, 1.5), (33.5, 67, 0.5), (34, 65, 1), (35, 64, 1), (36, 62, 3),
          (40, 74, 2), (42, 72, 1), (43, 70, 1), (44, 69, 3), (48, 65, 1), (49, 67, 1), (50, 69, 2), (52, 64, 1.5),
          (53.5, 65, 0.5), (54, 61, 2), (56, 62, 4)]
for at, m, d in PHRASE:
    wrap_add(lead, at * BEAT * SR, horn(m, d * BEAT * 1.02) * 0.32)
def wet(x, sec, mix):
    ir_n = int(SR * sec); ir = rng.standard_normal(ir_n) * np.exp(-np.arange(ir_n) / (SR * sec / 5))
    y = signal.fftconvolve(np.concatenate([x, x]), lp(ir, 3000))[:2 * LEN]
    y = y[LEN:2 * LEN]   # the tail of the end of the loop wrapped onto its start
    return x * (1 - mix) + y / np.max(np.abs(y)) * np.max(np.abs(x)) * mix
for name, x, mix in (('music_base', base, 0.25), ('music_lead', lead, 0.4)):
    x = wet(x, 2.2, mix)
    x = x / np.max(np.abs(x)) * 0.7
    wavfile.write(OUT + name + '.wav', SR, (x * 32767).astype(np.int16)); print(name, round(LEN / SR, 1))
