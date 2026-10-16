"""Deterministic synthesized cooking loop (CC0), no samples or downloads."""
import argparse
from array import array
from pathlib import Path
import random
import sys
import wave


def generate(destination):
    rate, seconds = 22050, 4
    rng = random.Random(20261016)
    samples = rate * seconds
    noise = [rng.uniform(-1, 1) for _ in range(samples)]
    # Circular high-pass texture and a short linear fade at the seam.
    pcm = array('h')
    import math
    for i, value in enumerate(noise):
        high = value - (noise[(i - 1) % samples] + noise[(i + 1) % samples]) / 2
        edge = min(i, samples - 1 - i)
        fade = min(1.0, edge / (rate * .025))
        envelope = .75 + .25 * math.sin(2 * math.pi * i / samples * 8)
        pcm.append(int(max(-1, min(1, high * .10 * envelope * fade)) * 32767))
    if sys.byteorder != 'little':
        pcm.byteswap()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(pcm.tobytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'assets/audio/sizzle_loop.wav')
    args = parser.parse_args()
    generate(args.output)
    print(args.output)


if __name__ == '__main__':
    main()
