"""Synthesizes the effect sounds in assets/audio/ from code (no samples).

Run from 1_app_development:  python tools/generate_sounds.py
Writes tap, purchase, reward, levelup and result_<perfect·good·near·fail>.wav.
The background music (bgm_warm_stall.ogg) comes from tools/prepare_bgm.py and
the griddle loop (sizzle_loop.wav) from tools/generate_cooking_sound.py.

One family (26번 4-6단계, S46-Q4·Q5): real objects with a little cuteness,
made from noise hits and resonances, never plain sine beeps.
  tap      a light, fresh bubble-like 'tok' (4차 피드백 IB4; was a pat + crackle)
  purchase two or three coins on a wooden counter + a paper bag rustle
  reward   a small shop bell
  levelUp  a shop door bell jingling + a short pour of coins
  result_* crust crackle + bell / soft pop / dull thud with a short hiss
All: 44.1 kHz mono 16-bit, at most 1.5 s, sound from the first 10 ms, peak
-3 dBFS or lower, and all eight within 2 dB of each other (RMS over the part
above -40 dB). Output is deterministic (fixed seeds) and dedicated to the
public domain (CC0 1.0) by the project.
Needs: pip install --user numpy
"""
import math
import os
import wave

import numpy as np

RATE = 44100
PEAK = 10 ** (-3 / 20)
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')


def ts(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def decay(n, seconds, attack=.002):
    e = np.exp(-np.arange(n) / (RATE * seconds))
    a = max(1, int(RATE * attack))
    e[:a] *= np.linspace(0, 1, a)
    return e


def place(total, *parts):
    out = np.zeros(int(RATE * total))
    for at, p in parts:
        s = int(RATE * at)
        e = min(len(out), s + len(p))
        out[s:e] += p[:e - s]
    return out


def smooth(x, width):
    return np.convolve(x, np.ones(width) / width, 'same')


def bell(freq, seconds, level=1.0):
    """Small shop bell: inharmonic partials, the high ones die first."""
    x = ts(seconds)
    partials = [(1, 1, 1), (2.76, .5, .45), (5.40, .25, .25), (8.93, .12, .12)]
    y = sum(a * np.sin(2 * math.pi * freq * k * x) * decay(len(x), seconds * d * .5)
            for k, a, d in partials)
    return level * y


def crackle(r, seconds, count, level=1.0):
    """Crisp crust: many tiny high clicks, thinning out."""
    n = int(RATE * seconds)
    out = np.zeros(n)
    for _ in range(count):
        at = int(abs(r.normal(0, n / 3.2))) % n
        m = int(RATE * r.uniform(.002, .006))
        click = np.diff(r.normal(0, 1, m) * decay(m, .0012, attack=.0003), prepend=0)
        e = min(n, at + m)
        out[at:e] += r.uniform(.3, 1) * click[:e - at]
    return level * out


def pop(start, end, seconds, level=1.0):
    x = ts(seconds)
    f = end + (start - end) * np.exp(-x * 30)
    y = np.sin(2 * math.pi * np.cumsum(f) / RATE)
    return level * y * decay(len(x), seconds / 4, attack=.003)


def hiss(r, seconds, level=1.0):
    n = int(RATE * seconds)
    noise = r.normal(0, 1, n)
    noise = np.diff(noise, prepend=0) * .6 + noise * .4
    sw = (1 - np.exp(-np.arange(n) / (RATE * .02))) * np.exp(-np.arange(n) / (RATE * seconds / 3))
    return level * noise * sw * (1 + .4 * r.normal(0, 1, n).clip(-1, 1))


def thud(r, seconds, level=1.0):
    x = ts(seconds)
    f = 70 + 90 * np.exp(-x * 40)
    body = np.sin(2 * math.pi * np.cumsum(f) / RATE) * decay(len(x), .05, attack=.001)
    knock = smooth(r.normal(0, 1, len(x)), 30) * decay(len(x), .015, attack=.0005)
    return level * (body + 1.5 * knock)


def plip(start, end, seconds=.09, level=1.0, sweep=.03):
    """A light, fresh 'tok' (4차 피드백 IB4: the old pat + crust crackle
    sounded like '짤짤'): a clean bubble-like blip whose pitch glides from
    [start] to [end] Hz, with a soft octave and no noise at all."""
    x = ts(seconds)
    f = end + (start - end) * np.exp(-x / sweep * 3)
    phase = 2 * math.pi * np.cumsum(f) / RATE
    body = np.sin(phase) + .22 * np.sin(2 * phase)
    return level * body * decay(len(x), seconds / 4.5, attack=.0012)


def coin(r, freq, seconds=.35, level=1.0):
    """A coin landing: a bright click then a few inharmonic ringing partials."""
    x = ts(seconds)
    partials = [(1, 1, 1), (1.53, .7, .8), (2.31, .45, .55), (3.17, .3, .4)]
    ring = sum(a * np.sin(2 * math.pi * freq * k * x + r.uniform(0, 6))
               * decay(len(x), seconds * d * .3, attack=.0005)
               for k, a, d in partials)
    click = np.diff(r.normal(0, 1, len(x)), prepend=0) * decay(len(x), .002, attack=.0002)
    return level * (ring + .8 * click)


def wood_knock(r, level=1.0):
    """The coin's tap on a wooden counter: a short hollow 'tok'."""
    x = ts(.06)
    body = (np.sin(2 * math.pi * 220 * x) + .5 * np.sin(2 * math.pi * 560 * x)) \
        * decay(len(x), .012, attack=.0005)
    knock = smooth(r.normal(0, 1, len(x)), 6) * decay(len(x), .004, attack=.0003)
    return level * (body + knock)


def rustle(r, seconds, level=1.0):
    """A paper bag: band noise broken into small crinkles."""
    n = int(RATE * seconds)
    noise = np.diff(smooth(r.normal(0, 1, n), 3), prepend=0)
    crinkles = np.zeros(n)
    for _ in range(int(seconds * 70)):
        at = r.integers(0, n)
        m = int(RATE * r.uniform(.004, .02))
        e = min(n, at + m)
        crinkles[at:e] += r.uniform(.2, 1) * decay(m, m / RATE / 3, attack=.001)[:e - at]
    shape = np.minimum(1, np.arange(n) / (RATE * .03)) * np.exp(-np.arange(n) / (RATE * seconds / 2.5))
    return level * noise * crinkles * shape


def jingle(r, level=1.0):
    """A shop door bell on a spring: a few small bells struck as it swings."""
    hits = []
    freqs = [1480, 1865, 2217]
    at = 0.0
    for i in range(7):
        f = freqs[i % 3] * r.uniform(.995, 1.005)
        hits.append((at, bell(f, .9 - at * .5, (1 - i * .1) * r.uniform(.7, 1))))
        at += r.uniform(.05, .09)
    return level * place(1.0, *hits)


def coin_pour(r, seconds, count, level=1.0):
    hits = []
    for i in range(count):
        at = seconds * (i / count) ** .8 + r.uniform(0, .02)
        hits.append((at, coin(r, r.uniform(2600, 4200), .22, r.uniform(.4, 1))))
        if r.random() < .4:
            hits.append((at, wood_knock(r, .3)))
    return level * place(seconds + .3, *hits)


def sounds():
    def rng(seed):
        return np.random.default_rng(seed)

    r = rng(20261118)  # the bake results keep their 4단계 seed and order
    out = {
        'result_perfect': place(1.3, (0, crackle(r, .32, 70, .9)), (.06, bell(1568, 1.1, .8)),
                                (.24, bell(2093, 1.05, .7))),
        'result_good': place(1.0, (0, crackle(r, .18, 30, .6)), (.03, bell(1760, .95, .9))),
        'result_near': place(.6, (0, pop(720, 330, .55, 1.0)), (.05, bell(1175, .5, .25))),
        'result_fail': place(.8, (0, thud(r, .35, 1.0)), (.08, hiss(r, .7, .35))),
        # 4차 피드백 g15 '보통': between good (crackle + high bell) and near
        # (pop + low soft bell) — a light pop and a middle bell, no random
        # parts so the other sounds keep their seeds.
        'result_fair': place(.8, (0, pop(900, 520, .4, .6)), (.04, bell(1480, .7, .55))),
    }
    # 4차 피드백 IB4 '짤짤 말고 가볍고 상큼하게': a rising bubble blip, no
    # crackle (also the special mold's tap).
    out['tap'] = place(.1, (0, plip(620, 1240, .09)))
    r = rng(20261120)
    out['purchase'] = place(.62, (0, wood_knock(r, .9)), (0, coin(r, 3150, .35, .9)),
                            (.075, wood_knock(r, .5)), (.075, coin(r, 3620, .3, .7)),
                            (.15, coin(r, 2870, .28, .55)), (.2, rustle(r, .4, 1.4)))
    r = rng(20261121)
    out['reward'] = place(.9, (0, bell(1319, .9, 1.0)), (.002, crackle(r, .03, 4, .2)))
    r = rng(20261122)
    out['levelup'] = place(1.45, (0, jingle(r)), (.38, coin_pour(r, .55, 14, .55)))
    return out


def loud(y):
    part = y[np.abs(y) > PEAK * 10 ** (-40 / 20)]
    return 20 * math.log10(math.sqrt(np.mean(part ** 2)) or 1e-9)


def write(name, y):
    data = (np.clip(y, -1, 1) * 32767).round().astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, f'{name}.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = sounds()
    for name, y in made.items():
        fade = int(RATE * .03)
        y[-fade:] *= np.linspace(1, 0, fade)
        made[name] = y / (np.max(np.abs(y)) or 1) * PEAK
    quietest = min(loud(y) for y in made.values())
    for name, y in made.items():
        over = loud(y) - quietest - 1.5
        if over > 0:
            y = y * 10 ** (-over / 20)
        lead = int(np.argmax(np.abs(y) > 1e-3))
        write(name, y)
        print(f'{name}.wav {len(y) / RATE:.2f}s peak {20 * math.log10(np.max(np.abs(y))):.1f} dBFS '
              f'loudness {loud(y):.1f} dB lead {lead / RATE * 1000:.1f} ms')


if __name__ == '__main__':
    main()
