# Sounds for the comic-panel cutscenes, kept apart from sfx.py so its random music stays as it is:
# a 1940s desk telephone ringing, a match struck, and the low musical hit under a key panel.
import sys, numpy as np
sys.argv = ['x']
exec(open(__file__.replace('sfx_cut.py', 'sfx.py')).read().split('# ---- music')[0].split('def gunshot')[0])
rng = np.random.default_rng(11)

# the telephone: a hammer chattering between two bells for a second and a half, twice, ringing on
def bell(f, sec):
    tt = t(sec)
    return sum(a * np.sin(2 * np.pi * f * r * tt) * np.exp(-tt * d) for r, a, d in ((1, 1.0, 3), (2.76, 0.45, 6), (5.4, 0.25, 10), (8.9, 0.1, 16)))
ring = np.zeros(int(SR * 4.2))
for burst in (0.0, 2.2):
    for k in range(int(1.4 * 22)):
        at = int(SR * (burst + k / 22.0))
        b = bell(1180 if k % 2 else 1010, 0.6) * (0.6 + 0.4 * np.sin(np.pi * k / 30.8))
        ring[at:at + len(b)] += b[:len(ring) - at]
save('phone_ring.wav', reverb(bp(ring, 300, 9000), 0.7, 0.18), 0.6)

# a match: the scratch, the flare, a soft hiss settling
tt = t(1.2)
scratch = bp(noise(1.2), 1500, 8000) * np.exp(-((tt - 0.08) / 0.05) ** 2)
flare = bp(noise(1.2), 400, 5000) * np.minimum(1, np.maximum(0, tt - 0.12) / 0.02) * np.exp(-np.maximum(0, tt - 0.12) / 0.25)
hiss = hp(noise(1.2), 3000) * 0.08 * np.minimum(1, tt / 0.3) * np.exp(-tt / 0.8)
save('match.wav', scratch * 1.2 + flare * 0.7 + hiss, 0.5)

# the hit: a low piano cluster and a bowed bass swelling under it, in the music's D minor
def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
tt = t(4.0)
x = np.zeros_like(tt)
for m, a in ((38, 1.0), (50, 0.6), (53, 0.45), (56, 0.35), (62, 0.25)):   # D, D, F, Ab: a tritone in it
    f = hz(m)
    x += a * sum(b * np.sin(2 * np.pi * f * h * tt) for h, b in ((1, 1), (2, 0.4), (3, 0.15))) * np.exp(-tt * 1.1) * np.minimum(1, tt / 0.004)
x += 0.5 * np.sin(2 * np.pi * hz(26) * tt) * np.minimum(1, tt / 0.6) * np.exp(-tt * 0.6)   # the bass under it
save('sting.wav', reverb(lp(x, 2500), 3.0, 0.5, 2000), 0.75)

# a sedan pulling up hard: the engine coming in under the rain, then the brakes squealing it to a stop
tt = t(2.6)
f0 = 38 + 22 * np.clip(tt / 1.2, 0, 1) - 18 * np.clip((tt - 1.3) / 0.6, 0, 1)
ph = 2 * np.pi * np.cumsum(f0) / SR
eng = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sign(np.sin(3 * ph))) * (0.4 + 0.6 * np.clip(tt / 0.9, 0, 1)) * np.exp(-np.maximum(0, tt - 1.9) * 4)
eng = lp(eng, 900) + 0.15 * bp(noise(2.6), 200, 1500) * np.clip(tt / 1.0, 0, 1)
sq = np.zeros_like(tt)
on = (tt > 1.25) & (tt < 2.0)
sq[on] = np.sin(2 * np.pi * (2300 + 140 * np.sin(2 * np.pi * 9 * tt[on])) * tt[on]) * np.sin(np.pi * (tt[on] - 1.25) / 0.75)
tires = bp(noise(2.6), 900, 4000) * on * 0.6
save('car_arrive.wav', reverb(eng * 0.9 + sq * 0.25 + tires, 0.8, 0.2), 0.8)

# a heavy car door: the latch, the slam of steel
x = np.zeros(int(SR * 0.6))
tt = t(0.4)
x[:len(tt)] += np.sin(2 * np.pi * 70 * tt) * np.exp(-tt / 0.06) + bp(noise(0.4), 300, 3000) * np.exp(-tt / 0.03) * 0.7
x[int(SR * 0.005):int(SR * 0.005) + 2000] += bp(noise(2000 / SR), 2000, 8000)[:2000] * np.exp(-np.arange(2000) / 300) * 0.5
save('door.wav', reverb(x, 0.4, 0.15), 0.7)

# the power going: a fat electrical crack, then everything humming down to nothing
tt = t(1.6)
crack = bp(noise(1.6), 1000, 9000) * np.exp(-tt / 0.04)
hum = np.sin(2 * np.pi * np.cumsum(120 * np.exp(-tt * 1.4) + 20) / SR) * np.exp(-tt * 1.8) * 0.6
save('power_down.wav', reverb(crack + hum, 1.0, 0.3), 0.7)

# fire: a low roar with crackles
tt = t(4.0)
roar = lp(noise(4.0), 500) * (1 + 0.3 * np.sin(2 * np.pi * 0.7 * tt))
crk = np.zeros_like(tt)
for k in range(70):
    at = int(rng.uniform(0, 3.9) * SR); n = int(SR * 0.012)
    crk[at:at + n] += bp(noise(n / SR), 1500, 7000)[:n] * np.exp(-np.arange(n) / 120) * rng.uniform(0.3, 1.0)
x = roar * 0.6 + crk * 0.8
f = int(SR * 0.3); x[:f] = x[:f] * np.linspace(0, 1, f) + x[-f:] * np.linspace(1, 0, f); x = x[:-f]   # loops round
x = x / np.max(np.abs(x)) * 0.6
from scipy.io import wavfile as _w
_w.write(OUT + 'fire.wav', SR, (x * 32767).astype(np.int16)); print('fire.wav')

# a chain snapping and a heavy crate hitting the stones
x = np.zeros(int(SR * 1.2))
for k in range(5):   # links rattling as it lets go
    at = int(SR * (0.01 + k * 0.035)); tt = t(0.08)
    x[at:at + len(tt)] += np.sin(2 * np.pi * (2600 + 400 * k) * tt) * np.exp(-tt / 0.012) * 0.5
save('chain.wav', reverb(x, 0.6, 0.2), 0.6)

# a subway train: the clack of wheels over rail joints, four to a car, under a steel rumble (loops)
tt = t(4.0)
x = lp(noise(4.0), 160) * 1.6 + 0.4 * np.sin(2 * np.pi * 47 * tt) * (1 + 0.2 * np.sin(2 * np.pi * 3 * tt))
for k in range(16):
    for d in (0.0, 0.11):
        at = int(SR * (k * 0.25 + d)); n = int(SR * 0.05)
        x[at:at + n] += bp(noise(n / SR), 300, 2500)[:n] * np.exp(-np.arange(n) / 260) * 1.4
x = x / np.max(np.abs(x)) * 0.6
_w.write(OUT + 'train_loop.wav', SR, (x * 32767).astype(np.int16)); print('train_loop.wav')

# a train going by: the roar swelling and falling away, a long squeal of a wheel, and its horn
tt = t(4.5)
env = np.exp(-((tt - 1.8) / 0.9) ** 2)
x = (lp(noise(4.5), 400) * 1.5 + bp(noise(4.5), 600, 3000) * 0.5) * env
for k in range(28):
    at = int(SR * (0.8 + k * 0.075)); n = int(SR * 0.04)
    if at + n < len(x):
        x[at:at + n] += bp(noise(n / SR), 300, 3000)[:n] * np.exp(-np.arange(n) / 200) * env[at] * 1.5
h = sum(np.sin(2 * np.pi * f * tt) for f in (311, 370, 466)) * ((tt > 0.2) & (tt < 1.4)) * np.minimum(1, (tt - 0.2) / 0.05)
x += lp(np.sign(h) * 0.25 + h * 0.1, 3000) * 0.5
save('train_pass.wav', reverb(x, 1.0, 0.3), 0.85)

# reloading a revolver by hand: the latch and the cylinder swinging out, a round pushed into a chamber,
# the cylinder spun with the thumb (a ratchet running down), each a short dry metallic sound
def tick(f, sec, decay, amp=1.0):
    tt = t(sec)
    return amp * (np.sin(2 * np.pi * f * tt) * 0.6 + bp(noise(sec), f * 0.7, min(f * 3.0, 11000))) * np.exp(-tt / decay)
x = np.zeros(int(SR * 0.3))
x[:len(t(0.05))] += tick(3200, 0.05, 0.006)
at = int(SR * 0.05); y = tick(1400, 0.2, 0.03, 0.6); x[at:at + len(y)] += y[:len(x) - at]
save('cyl_open.wav', reverb(x, 0.3, 0.08), 0.55)
x = tick(2600, 0.12, 0.012)
y = tick(900, 0.095, 0.02, 0.7); at = int(SR * 0.025); x[at:at + len(y)] += y[:len(x) - at]
save('shell_in.wav', x, 0.45)
x = np.zeros(int(SR * 0.6))
tm = 0.0; gap = 0.018
while tm < 0.5:
    at = int(SR * tm); y = tick(4200 + rng.uniform(-300, 300), 0.02, 0.003, 0.8 - tm)
    x[at:at + len(y)] += y[:len(x) - at]
    tm += gap; gap *= 1.09
save('cyl_spin.wav', reverb(x, 0.25, 0.08), 0.5)
