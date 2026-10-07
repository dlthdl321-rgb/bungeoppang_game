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

    # Background music: one 24 s loop per mood (lib/music_config.dart maps
    # each stall background to one). The day loop is the original BGM.
    for mood in MOODS:
        write(f'bgm_{mood.name}.wav', bgm_loop(mood), .5)


class Mood:
    """How a BGM loop sounds: tempo, key, scales and timbre."""

    def __init__(self, name, beat, key, pad, scale, melody, melody_octave=0,
                 bell=(1, .4, .05), melody_release=.35, rest_every=3,
                 texture=None):
        self.name, self.beat, self.key, self.pad = name, beat, key, pad
        self.scale, self.melody, self.melody_octave = scale, melody, melody_octave
        self.bell, self.melody_release = bell, melody_release
        self.rest_every, self.texture = rest_every, texture


MAJOR_PENTA = [0, 2, 4, 7, 9, 12, 14, 16]
MINOR_PENTA = [0, 3, 5, 7, 10, 12, 15, 17]
STEPS = [0, 2, 4, 2, 5, 4, 2, 1, 3, 5, 6, 5, 4, 2, 3, 0]
BARS = [-12, -9, -14, -7]  # pad roots, relative to the key


def fit(samples, n):
    """[samples] cut or zero-padded to exactly n samples."""
    return np.pad(samples[:n], (0, max(0, n - len(samples))))


def rain_bed(seconds):
    """Soft rain: low-passed noise with a slow swell, plus a few drips."""
    n = int(RATE * seconds)
    hiss = np.convolve(rng.normal(0, 1, n), np.ones(6) / 6, 'same')
    swell = .75 + .25 * np.sin(2 * math.pi * np.arange(n) / n * 3)
    drips = [(rng.uniform(0, seconds - 1), .25 * tone(rng.uniform(1400, 2200),
                                                      .12, release=.04,
                                                      harmonics=(1,)))
             for _ in range(40)]
    return .05 * hiss * swell + fit(mix(*drips), n)


def night_bed(seconds):
    """Night air: a hushed low drone and far-off cricket chirps."""
    n = int(RATE * seconds)
    drone = .06 * tone(note(-33), seconds, attack=2, release=seconds,
                       harmonics=(1, .2))[:n]
    chirps = []
    for i in range(int(seconds / 1.6)):
        start = i * 1.6 + rng.uniform(0, .4)
        for k in range(3):
            chirps.append((start + k * .07, .05 * tone(4200, .04, release=.015,
                                                       harmonics=(1,))))
    return fit(drone, n) + fit(mix(*chirps), n)


MOODS = [
    # Clear day: the original calm pentatonic loop.
    Mood('day', .5, 3, (0, 4, 7), MAJOR_PENTA, STEPS),
    # Cherry blossoms: quicker and higher, brighter music box.
    Mood('spring', .4, 8, (0, 4, 7, 14), MAJOR_PENTA, STEPS, melody_octave=12,
         bell=(1, .5, .2, .05), melody_release=.25, rest_every=4),
    # Autumn, dusk and forest: slower, warm major-seventh pads.
    Mood('dusk', .6, 0, (0, 4, 7, 11), MAJOR_PENTA,
         [4, 2, 0, 2, 1, 0, 2, 4, 5, 4, 2, 1, 0, 1, 2, 0],
         bell=(1, .25, .05), melody_release=.5),
    # Rain: minor pentatonic over rain.
    Mood('rain', .75, -2, (0, 3, 7), MINOR_PENTA,
         [4, 3, 2, 0, 2, 3, 1, 0, 2, 4, 5, 4, 2, 1, 0, 0],
         bell=(1, .2), melody_release=.6, texture=rain_bed),
    # Snow: sparse glassy bells, an octave up.
    Mood('snow', .6, 5, (0, 4, 7), MAJOR_PENTA,
         [7, 5, 4, 5, 2, 4, 1, 0, 4, 5, 7, 6, 4, 2, 1, 0], melody_octave=12,
         bell=(1, 0, .45, 0, .2), melody_release=.8, rest_every=2),
    # Night and seaside: a slow lullaby over a low drone and crickets.
    Mood('night', .8, -5, (0, 3, 7, 10), MINOR_PENTA,
         [0, 2, 3, 2, 4, 3, 2, 0, 1, 2, 4, 5, 4, 3, 2, 0],
         bell=(1, .3), melody_release=.7, rest_every=2, texture=night_bed),
]


def bgm_loop(mood, seconds=24):
    """Soft pads plus a sparse melody; every voice decays before the loop
    point so the seam is smooth."""
    parts = []
    bar = 4 * mood.beat
    for b in range(int(seconds / bar)):
        root = BARS[b % len(BARS)] + mood.key
        for interval in mood.pad:
            parts.append((b * bar, .18 * tone(note(root + interval - 12), bar,
                                              attack=.4, release=.7,
                                              harmonics=(1, .15))))
    for i in range(int(seconds / mood.beat)):
        if i % mood.rest_every == mood.rest_every - 1:
            continue
        step = mood.melody[i % len(mood.melody)]
        pitch = mood.scale[step] + mood.key + mood.melody_octave
        parts.append((i * mood.beat, .35 * tone(note(pitch), .9,
                                                release=mood.melody_release,
                                                harmonics=mood.bell)))
    loop = fit(mix(*parts), int(RATE * seconds))
    if mood.texture:
        loop = loop / (np.max(np.abs(loop)) or 1) + mood.texture(seconds)
    fade = int(RATE * .05)
    loop[:fade] *= np.linspace(0, 1, fade)
    loop[-fade:] *= np.linspace(1, 0, fade)
    return loop

if __name__ == '__main__':
    main()
