"""Copies 25번 62번 (재료 타이쿤) art into the game, unchanged.

The generated scenes are already on the game grid (scenes 1200x880 and
tools 400x400 at 4 px per dot, alpha 0/255), so they are only checked and
copied:

* scenes/<name>.png (9) -> assets/images/prep/<name>.png
  (the mini-game bowls and pots, the strong fire layer, spatula, whisk)

The 17 icons of 62_ingredients/icons/ are copied by
`tools/apply_25_art.py <26_feedback_generated> --only ingredients` into
assets/images/icons/ (4차 병합 3: one copy, one tool, one loader).

    python tools/apply_62_prep_art.py <26_feedback_generated folder>

Run it in 1_app_development. It never writes into the source folder and
never redraws anything (the art side owns the pictures).
"""
import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image

SCENES = {'bowl_batter_lumpy': (1200, 880), 'bowl_batter_smooth': (1200, 880),
          'pot_redbean': (1200, 880), 'pot_cocoa': (1200, 880), 'fire_high': (1200, 880),
          'bowl_custard_low': (1200, 880), 'bowl_custard_high': (1200, 880),
          'tool_spatula': (400, 400), 'tool_whisk': (400, 400)}
OUT = Path('assets/images')


def check(path, size):
    with Image.open(path) as image:
        if image.size != size:
            sys.exit(f'{path}: {image.size}, expected {size}')
        alpha = image.convert('RGBA').getchannel('A')
        if set(alpha.getdata()) - {0, 255}:
            sys.exit(f'{path}: alpha other than 0/255')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path, help='26_feedback_generated folder')
    args = parser.parse_args()
    root = args.source / '62_ingredients'
    jobs = [(root / 'scenes' / f'{n}.png', OUT / 'prep' / f'{n}.png', s) for n, s in SCENES.items()]
    for source, _, size in jobs:
        if not source.exists():
            sys.exit(f'missing {source}')
        check(source, size)
    for source, target, _ in jobs:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    print(f'{len(jobs)} scenes copied.')


if __name__ == '__main__':
    main()
