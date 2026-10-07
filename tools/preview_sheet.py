"""Tiles game screenshots (build/preview/extra/<stage>_*.png) into labelled
sheets for the stage reports: build/preview/extra/sheet_<stage>_<n>.png.

  python tools/preview_sheet.py bg [--per 5] [--scale 0.5] [--only a,b]
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

DIR = Path(__file__).resolve().parent.parent / 'build' / 'preview' / 'extra'


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    p = argparse.ArgumentParser()
    p.add_argument('stage')
    p.add_argument('--per', type=int, default=5, help='screens per sheet')
    p.add_argument('--scale', type=float, default=0.5)
    p.add_argument('--only', help='comma separated names, in this order')
    args = p.parse_args()
    if args.only:
        files = [DIR / f'{args.stage}_{n}.png' for n in args.only.split(',')]
    else:
        files = sorted(DIR.glob(f'{args.stage}_*.png'))
    font = ImageFont.truetype('C:/Windows/Fonts/malgun.ttf', 16)
    for n, i in enumerate(range(0, len(files), args.per)):
        group = files[i:i + args.per]
        shots = [Image.open(f).convert('RGB') for f in group]
        shots = [s.resize((round(s.width * args.scale), round(s.height * args.scale)), Image.BOX) for s in shots]
        w = sum(s.width + 8 for s in shots)
        h = max(s.height for s in shots) + 24
        out = Image.new('RGB', (w, h), (40, 40, 40))
        draw = ImageDraw.Draw(out)
        x = 0
        for f, s in zip(group, shots):
            out.paste(s, (x, 24))
            draw.text((x + 4, 2), f.stem[len(args.stage) + 1:], fill=(255, 255, 255), font=font)
            x += s.width + 8
        path = DIR / f'sheet_{args.stage}_{n + 1}.png'
        out.save(path)
        print(path)


if __name__ == '__main__':
    main()
