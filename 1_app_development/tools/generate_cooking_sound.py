"""Synthesized griddle sizzle loop (CC0), no samples or downloads.

NOT USED NOW: since 2026-11-18 assets/audio/sizzle_loop.wav is a recording
(Freesound 117602 'Crepe Making' by mefrancis13, CC0) made with
tools/make_seamless_loop.py. Running this script with the default --output
overwrites that recording; it is kept as a fallback (pass --output elsewhere
to compare).

Run from 1_app_development:  python tools/generate_cooking_sound.py
Writes assets/audio/sizzle_loop.wav: 20 s, 44.1 kHz mono 16-bit, fixed seed.

Seamless by construction: every layer is made on a circle of exactly
20 s. Noise is shaped with FFT filters (circular), every slow swell has a
whole number of cycles in 20 s, and pops that run past the end continue at
the start. There is no fade at the loop point, so it never dips.
Layers (26번 4-6단계, F38 'more realistic, the seam joins naturally'):
  1. sizzle bed: 2-8 kHz hiss with a slow 0.3-2 Hz swell,
  2. spits: tiny 1-5 ms clicks, 15-40 per second,
  3. bubbles: soft 300-900 Hz pops, 2-5 per second,
  4. griddle hum: quiet 80-200 Hz rumble.
Needs: pip install --user numpy
"""
import argparse
import math
import wave
from pathlib import Path

import numpy as np

RATE = 44100
SECONDS = 20
PEAK_DB = -3.0
SEED = 20261118


def band_noise(rng, n, low, high, tilt=0.0):
    """Circular noise between [low] and [high] Hz (soft edges), unit RMS."""
    spectrum = np.fft.rfft(rng.normal(0, 1, n))
    freq = np.fft.rfftfreq(n, 1 / RATE)
    edge = lambda f, c, w: 1 / (1 + np.exp(-(f - c) / w))  # noqa: E731
    gain = edge(freq, low, low * .15) * (1 - edge(freq, high, high * .15))
    if tilt:
        gain *= (np.maximum(freq, 1) / 1000) ** tilt
    y = np.fft.irfft(spectrum * gain, n)
    return y / (np.sqrt(np.mean(y ** 2)) or 1)


def swell(n, cycles_and_depths, rng):
    """Slow loudness wobble; whole cycles per loop so it joins at the seam."""
    x = np.arange(n) / n
    out = np.ones(n)
    for cycles, depth in cycles_and_depths:
        out += depth * np.sin(2 * math.pi * (cycles * x + rng.uniform(0, 1)))
    return out


def place(out, at, sound):
    """Adds [sound] at sample [at]; the part past the end wraps to the start."""
    n = len(out)
    idx = (at + np.arange(len(sound))) % n
    np.add.at(out, idx, sound)


def spits(rng, n):
    """Oil spitting: tiny bright clicks, the rate drifting 15-40 per second."""
    out = np.zeros(n)
    rate_curve = 27.5 + 12.5 * np.sin(2 * math.pi * (np.arange(n) / n * 9 + .3))
    t = 0.0
    while t < SECONDS:
        per_second = rate_curve[int(t * RATE) % n]
        t += rng.exponential(1 / per_second)
        if t >= SECONDS:
            break
        m = int(RATE * rng.uniform(.001, .005))
        click = rng.normal(0, 1, m) * np.exp(-np.arange(m) / (RATE * rng.uniform(.0003, .0012)))
        click = np.diff(click, prepend=0)  # brighter
        place(out, int(t * RATE), rng.uniform(.25, 1) ** 2 * click)
    return out


def bubbles(rng, n):
    """Batter bubbles bursting: short soft pops 300-900 Hz, 2-5 per second."""
    out = np.zeros(n)
    t = 0.0
    while True:
        t += rng.exponential(1 / 3.5)
        if t >= SECONDS:
            break
        seconds = rng.uniform(.015, .04)
        x = np.arange(int(RATE * seconds)) / RATE
        f0 = rng.uniform(300, 900)
        f = f0 * (1 + .35 * (1 - np.exp(-x * 120)))  # a small upward chirp
        body = np.sin(2 * math.pi * np.cumsum(f) / RATE)
        env = np.minimum(1, x / .002) * np.exp(-x / (seconds / 4))
        place(out, int(t * RATE), rng.uniform(.3, 1) * body * env)
    return out


def generate():
    rng = np.random.default_rng(SEED)
    n = RATE * SECONDS
    bed = band_noise(rng, n, 2000, 8000, tilt=-.3) * swell(
        n, [(7, .12), (13, .08), (23, .06), (37, .05)], rng)
    # A rougher top layer so the hiss has grain instead of a smooth 'shh'.
    grain = band_noise(rng, n, 4000, 11000) * (band_noise(rng, n, 20, 120) * .5 + 1).clip(0)
    hum = band_noise(rng, n, 80, 200) * swell(n, [(3, .2), (11, .1)], rng)
    y = (.55 * bed + .18 * grain + 2.2 * spits(rng, n) + .35 * bubbles(rng, n)
         + .12 * hum)
    # Rotate the circle so the file starts where neighbouring samples are
    # closest; the loop point is then as smooth as any other point.
    near_zero = np.abs(y) < .05 * np.max(np.abs(y))
    step = np.abs(y - np.roll(y, 1))
    step[~near_zero] = np.inf
    y = np.roll(y, -int(np.argmin(step)))
    return y / np.max(np.abs(y)) * 10 ** (PEAK_DB / 20)


def write(path, y):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((np.clip(y, -1, 1) * 32767).round().astype('<i2').tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'assets/audio/sizzle_loop.wav')
    args = parser.parse_args()
    y = generate()
    write(args.output, y)
    rms = 20 * math.log10(math.sqrt(float(np.mean(y ** 2))))
    print(f'{args.output} {len(y) / RATE:.2f}s rms {rms:.1f} dB '
          f'seam jump {abs(y[-1] - y[0]):.5f}')


if __name__ == '__main__':
    main()
