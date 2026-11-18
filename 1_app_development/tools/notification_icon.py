"""손님 알림 상태 표시줄 아이콘(25번 21번)을 Android 밀도별 PNG로 만든다.

생성 원본(읽기만)을 흰색(#FFFFFF)·알파 0/255 두 단계로 정리하고, 그림을
정사각 캔버스 가운데에 24px 기준 2px 여백(가장자리 1/12)을 두고 넣는다.

    1_app_development에서:
    python tools/notification_icon.py <ic_stat_customer.png> [--preview]

만드는 파일: android/app/src/main/res/drawable-<dpi>/ic_stat_customer.png
(mdpi 24 · hdpi 36 · xhdpi 48 · xxhdpi 72 · xxxhdpi 96).
--preview: 5개 크기를 어두운 배경에 나란히 놓은 build/notification_icon_check.png
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

APP = Path(__file__).resolve().parent.parent
RES = APP / 'android' / 'app' / 'src' / 'main' / 'res'
SIZES = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96}
NAME = 'ic_stat_customer.png'


def binary_mask(src: Path) -> Image.Image:
    """원본 알파를 128에서 잘라 0/255 마스크로 만들고 그림 부분만 자른다."""
    alpha = np.array(Image.open(src).convert('RGBA'))[..., 3]
    mask = Image.fromarray(np.where(alpha >= 128, 255, 0).astype(np.uint8), 'L')
    return mask.crop(mask.getbbox())


def icon(mask: Image.Image, size: int) -> Image.Image:
    margin = round(size / 12)
    box = size - 2 * margin
    scale = box / max(mask.size)
    w, h = max(1, round(mask.width * scale)), max(1, round(mask.height * scale))
    small = np.array(mask.resize((w, h), Image.Resampling.LANCZOS))
    alpha = np.zeros((size, size), np.uint8)
    x, y = (size - w) // 2, (size - h) // 2
    alpha[y:y + h, x:x + w] = np.where(small >= 128, 255, 0)
    out = np.full((size, size, 4), 255, np.uint8)
    out[..., 3] = alpha
    return Image.fromarray(out, 'RGBA')


def preview(icons: dict, path: Path) -> None:
    scale, pad = 4, 16
    widths = [im.width * scale for im in icons.values()]
    tall = max(widths)
    sheet = Image.new('RGB', (sum(widths) + pad * (len(widths) + 1), tall + 2 * pad + 96 + pad), (32, 33, 36))
    x = pad
    for im in icons.values():  # 위: 4배 확대(픽셀 확인), 아래: 실제 크기
        sheet.paste(im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST), (x, pad), im.resize((im.width * scale, im.height * scale), Image.Resampling.NEAREST))
        sheet.paste(im, (x, tall + 2 * pad), im)
        x += im.width * scale + pad
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)


def main() -> None:
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser()
    ap.add_argument('source', type=Path)
    ap.add_argument('--preview', action='store_true')
    args = ap.parse_args()
    mask = binary_mask(args.source)
    icons = {}
    for dpi, size in SIZES.items():
        im = icon(mask, size)
        out = RES / f'drawable-{dpi}' / NAME
        out.parent.mkdir(parents=True, exist_ok=True)
        im.save(out, optimize=True)
        icons[dpi] = im
        a = np.array(im)[..., 3]
        print(f'{out.relative_to(APP)} {size}x{size} 불투명 {int((a == 255).sum())}px, 알파 값 {sorted(set(a.ravel().tolist()))}')
    if args.preview:
        path = APP / 'build' / 'notification_icon_check.png'
        preview(icons, path)
        print(f'미리보기: {path.relative_to(APP)}')


if __name__ == '__main__':
    main()
