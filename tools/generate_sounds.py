"""Synthesizes every sound in assets/audio/ from code (no samples, no downloads).

Run from the project root:  python tools/generate_sounds.py
Output is deterministic (fixed random seed), 22.05 kHz mono 16-bit WAV.
The generated audio is dedicated to the public domain (CC0 1.0) by the project.
"""
import math
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
rng = np.random.default_rng(20261005)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def env(n, attack, release):
    """Linear attack, exponential release envelope of n samples."""
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.arange(n - a) / (RATE * release))
    return e


def tone(freq, seconds, attack=0.005, release=0.15, harmonics=(1, .3, .1)):
    x = t(seconds)
    wave_ = sum(a * np.sin(2 * math.pi * freq * (i + 1) * x)
                for i, a in enumerate(harmonics))
    return wave_ * env(len(x), attack, release)


def mix(*parts):
    n = max(int(RATE * offset) + len(p) for offset, p in parts)
    out = np.zeros(n)
    for offset, p in parts:
        start = int(RATE * offset)
        end = min(n, start + len(p))
        out[start:end] += p[:end - start]
    return out


def write(name, samples, peak=0.8):
    samples = samples / (np.max(np.abs(samples)) or 1) * peak
    data = (samples * 32767).astype('<i2').tobytes()
    with wave.open(os.path.join(OUT, name), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)


def note(semitones_from_a4):
    return 440 * 2 ** (semitones_from_a4 / 12)


def main():
    os.makedirs(OUT, exist_ok=True)

    # Tap: a short warm "pop" (pitch drop + a puff of filtered noise).
    x = t(0.09)
    pitch = 520 * np.exp(-x * 18)
    pop = np.sin(2 * math.pi * np.cumsum(pitch) / RATE) * env(len(x), .002, .03)
    puff = np.convolve(rng.normal(0, 1, len(x)), np.ones(12) / 12, 'same')
    write('tap.wav', pop + .25 * puff * env(len(x), .001, .015), .55)

    # Purchase: two bright notes up a fourth.
    write('purchase.wav', mix((0, tone(note(3), .18, release=.08)),
                              (.07, tone(note(8), .3, release=.12))), .6)

    # Reward: a quick sparkle arpeggio.
    write('reward.wav', mix(*[(i * .055, tone(note(n), .35, release=.12,
                                              harmonics=(1, .2, .15, .05)))
                              for i, n in enumerate([7, 11, 14, 19])]), .65)

    # Level up: rising major arpeggio landing on a held chord.
    arp = [(i * .09, tone(note(n), .3, release=.1))
           for i, n in enumerate([3, 7, 10, 15])]
    chord = [(.36, tone(note(n), 1.1, attack=.02, release=.45))
             for n in [15, 19, 22]]
    write('levelup.wav', mix(*arp, *chord), .7)

    # BGM: a calm 24 s pentatonic loop. Soft pads plus a sparse music-box line;
    # every voice decays before the loop point so the seam is silent-smooth.
    beat = .5
    bars = [(-12, 3), (-9, 7), (-14, 2), (-7, 10)]  # (pad root, melody degree)
    scale = [0, 2, 4, 7, 9, 12, 14, 16]
    melody_steps = [0, 2, 4, 2, 5, 4, 2, 1, 3, 5, 6, 5, 4, 2, 3, 0]
    parts = []
    for b, (root, _) in enumerate(bars * 3):
        start = b * 2.0  # two seconds per bar
        for interval in (0, 4, 7):
            parts.append((start, .18 * tone(note(root + interval - 12), 2.0,
                                            attack=.4, release=.7,
                                            harmonics=(1, .15))))
    for i in range(24 * 2):  # eighth-ish notes, sparse
        if i % 3 == 2:
            continue
        step = melody_steps[i % len(melody_steps)]
        parts.append((i * beat, .35 * tone(note(scale[step] + 3), .9,
                                           release=.35, harmonics=(1, .4, .05))))
    loop = mix(*parts)[:int(RATE * 24)]
    fade = int(RATE * .05)
    loop[:fade] *= np.linspace(0, 1, fade)
    loop[-fade:] *= np.linspace(1, 0, fade)
    write('bgm.wav', loop, .5)


if __name__ == '__main__':
    main()
