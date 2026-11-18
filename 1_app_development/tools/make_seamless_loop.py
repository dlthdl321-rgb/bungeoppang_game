"""Turns a recorded sound (e.g. a CC0 griddle sizzle) into a seamless loop.

Run from 1_app_development:
    python tools/make_seamless_loop.py <input> --seconds 20 [--output assets/audio/sizzle_loop.wav]
    python tools/make_seamless_loop.py assets/audio/sizzle_loop.wav --check

Steps: decode to 44.1 kHz mono (imageio-ffmpeg), cut silence at both ends,
take [--seconds] + [--fade] seconds from the start of the sound, cross-fade
the tail onto the head with equal power (no dip, no click at the loop point),
match the loudness of the synthesized loop (--rms-db), write a plain 16-bit
WAV without tags. The input is only read. Put recorded files in
4_image_generation_results_and_backups/26_feedback_generated/sounds/ and
write the page address and license in 25번 '필요한 소리'.
Needs: pip install --user numpy imageio-ffmpeg
"""
import argparse
import math
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100


def decode(path):
    import imageio_ffmpeg
    raw = subprocess.run(
        [imageio_ffmpeg.get_ffmpeg_exe(), '-v', 'error', '-i', str(path), '-f', 'f32le',
         '-ac', '1', '-ar', str(RATE), 'pipe:1'],
        check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype='<f4').astype(np.float64)


def db(x):
    return 20 * math.log10(math.sqrt(float(np.mean(np.square(x)))) or 1e-12)


def trim_silence(y, threshold_db=-50):
    loud = np.flatnonzero(np.abs(y) > 10 ** (threshold_db / 20))
    return y[loud[0]:loud[-1] + 1] if len(loud) else y


def seamless(y, seconds, fade_seconds):
    fade, body = int(RATE * fade_seconds), int(RATE * seconds)
    if len(y) < body + fade:
        raise SystemExit(f'input has {len(y) / RATE:.1f}s of sound; '
                         f'need {seconds + fade_seconds:.1f}s for a {seconds}s loop')
    y = y[:body + fade]
    angle = np.linspace(0, math.pi / 2, fade)
    head = y[:fade] * np.sin(angle) + y[-fade:] * np.cos(angle)
    return np.concatenate([head, y[fade:body]])


def seam_report(y):
    """The same numbers test/audio_assets_test.dart checks."""
    edge, window = int(RATE * .05), int(RATE * .01)
    levels = np.array([db(y[i * window:(i + 1) * window]) for i in range(len(y) // window)])
    median = float(np.median(levels))
    return {
        'seconds': len(y) / RATE,
        'sample_jump': float(abs(y[-1] - y[0])),
        'level_gap_db': abs(db(y[-edge:]) - db(y[:edge])),
        'quiet_10ms_windows': int(np.sum(levels < median - 10)),
        'rms_db': db(y),
    }


def passes(r):
    return r['sample_jump'] <= .02 and r['level_gap_db'] <= 3 and r['quiet_10ms_windows'] == 0


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
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'assets/audio/sizzle_loop.wav')
    parser.add_argument('--seconds', type=float, default=20)
    parser.add_argument('--fade', type=float, default=2.0, help='cross-fade seconds (1.5-2)')
    parser.add_argument('--rms-db', type=float, default=-25.0,
                        help='loudness to match (the synthesized sizzle is about -25 dB)')
    parser.add_argument('--check', action='store_true', help='only measure the seam of <input>')
    args = parser.parse_args()
    if args.check:
        report = seam_report(decode(args.input))
        for k, v in report.items():
            print(f'{k}: {v:.4f}' if isinstance(v, float) else f'{k}: {v}')
        print('OK' if passes(report) else 'SEAM CHECK FAILED')
        sys.exit(0 if passes(report) else 1)
    y = seamless(trim_silence(decode(args.input)), args.seconds, args.fade)
    y *= 10 ** ((args.rms_db - db(y)) / 20)
    peak = float(np.max(np.abs(y)))
    if peak > 10 ** (-1 / 20):
        y *= 10 ** (-1 / 20) / peak
    write(args.output, y)
    report = seam_report(y)
    print(args.output, report, 'OK' if passes(report) else 'SEAM CHECK FAILED')


if __name__ == '__main__':
    main()
