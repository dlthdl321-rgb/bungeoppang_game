"""Turns the background-music master into the app's seamless loop.

Run from 1_app_development:
    python tools/prepare_bgm.py            # write assets/audio/bgm_warm_stall.ogg
    python tools/prepare_bgm.py --check    # measure the seam of the written file

The source (../7_music/Warm Bungeoppang Stall.mp3, Suno, 2026-10-17, paid plan)
is only read, never moved or changed. Steps:
  1. decode to 48 kHz stereo float (imageio-ffmpeg's bundled ffmpeg),
  2. equal-power cross-fade of the last 3.0 s onto the first 3.0 s, so the
     loop end flows straight into the loop start (174.04 s -> 171.04 s),
  3. -6 dB, so the song sits near the old synthesized loops at the same
     slider value,
  4. encode OGG Vorbis q4 without tags or cover art.
MP3 is not used for the loop: encoder padding leaves a gap when it repeats.
Needs: pip install --user numpy imageio-ffmpeg
"""
import argparse
import hashlib
import math
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / '7_music' / 'Warm Bungeoppang Stall.mp3'
OUTPUT = ROOT / 'assets' / 'audio' / 'bgm_warm_stall.ogg'
RATE = 48000
CROSSFADE_SECONDS = 3.0
GAIN_DB = -6.0
QUALITY = 4


def ffmpeg():
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def decode(path):
    """[path] as float32 samples, shape (frames, 2), at RATE."""
    raw = subprocess.run(
        [ffmpeg(), '-v', 'error', '-i', str(path), '-f', 'f32le', '-ac', '2',
         '-ar', str(RATE), 'pipe:1'],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).astype(np.float64)


def encode(samples, path, extension='ogg'):
    codec = ['-c:a', 'libvorbis', '-q:a', str(QUALITY)] if extension == 'ogg' \
        else ['-c:a', 'aac', '-b:a', '160k']
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [ffmpeg(), '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE),
         '-ac', '2', '-i', 'pipe:0', '-map_metadata', '-1', *codec, str(path)],
        input=samples.astype('<f4').tobytes(), check=True)


def seamless(samples, seconds=CROSSFADE_SECONDS):
    """Equal-power cross-fade of the tail onto the head; the result is
    len - fade frames and its last frame leads into its first."""
    fade = int(RATE * seconds)
    angle = np.linspace(0, math.pi / 2, fade)[:, None]
    head = samples[:fade] * np.sin(angle) + samples[-fade:] * np.cos(angle)
    return np.concatenate([head, samples[fade:-fade]])


def db(x):
    return 20 * math.log10(math.sqrt(float(np.mean(np.square(x)))) or 1e-12)


def seam_report(loop):
    """Seam numbers of a loop: level just before/after the loop point,
    the sample jump across it, and 10 ms windows 15 dB below the median."""
    quarter = int(RATE * .25)
    before, after = db(loop[-quarter:]), db(loop[:quarter])
    jump = float(np.max(np.abs(loop[-1] - loop[0])))
    window = int(RATE * .01)
    frames = len(loop) // window
    levels = np.array([db(loop[i * window:(i + 1) * window]) for i in range(frames)])
    median = float(np.median(levels))
    # Look at the 2 s around the seam (the song's own quiet bars are music).
    around = np.concatenate([levels[-100:], levels[:100]])
    holes = int(np.sum(around < median - 15))
    return {
        'seconds': len(loop) / RATE,
        'before_db': before,
        'after_db': after,
        'level_gap_db': abs(before - after),
        'sample_jump': jump,
        'median_10ms_db': median,
        'holes_near_seam': holes,
        'mean_db': db(loop),
        'peak_db': 20 * math.log10(float(np.max(np.abs(loop))) or 1e-12),
    }


def passes(report):
    return (report['level_gap_db'] <= 3 and report['sample_jump'] <= .02
            and report['holes_near_seam'] == 0)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def print_report(title, report):
    print(title)
    for key, value in report.items():
        print(f'  {key}: {value:.4f}' if isinstance(value, float) else f'  {key}: {value}')


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--output', type=Path, default=OUTPUT)
    parser.add_argument('--check', action='store_true',
                        help='measure the seam of --output instead of writing it')
    parser.add_argument('--m4a', action='store_true',
                        help='also write an AAC .m4a next to the .ogg (for iOS later)')
    args = parser.parse_args()
    print(f'source sha256 {sha256(args.source)}')
    if args.check:
        loop = decode(args.output)
        report = seam_report(loop)
        print_report(f'{args.output.name} (decoded)', report)
        print(f'  size: {args.output.stat().st_size} bytes')
        print('OK' if passes(report) else 'SEAM CHECK FAILED')
        sys.exit(0 if passes(report) else 1)
    source = decode(args.source)
    print_report('source repeated as is', seam_report(source))
    loop = seamless(source) * 10 ** (GAIN_DB / 20)
    peak = float(np.max(np.abs(loop)))
    if peak > .99:
        loop *= .99 / peak
    print_report('prepared loop', seam_report(loop))
    encode(loop, args.output)
    if args.m4a:
        encode(loop, args.output.with_suffix('.m4a'), 'm4a')
    print(f'{args.output} {args.output.stat().st_size} bytes')


if __name__ == '__main__':
    main()
