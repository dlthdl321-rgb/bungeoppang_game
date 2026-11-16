"""Top edge of the red check towel on the left of each concept background
(24번 4단계, DEC-038): the sale counter's top sits on it.

    python tools/towel_top.py

Prints, per picture in assets/images/bg and bg_clean (335x762), the first
row where the towel's cloth (red and cream checks, not the orange wood)
covers at least 60% of columns 28..40 (right of the autumn leaf and the
cherry petals, left of the towel's folded edge). Copy the numbers into
NightStallPainter.towelTops (lib/ui/night_stall_painter.dart).
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
COLUMNS = slice(28, 41)


def towel_top(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    wood = (r > 200) & (g > 110) & (b < 60)
    cloth = (b > 60) & (r > b + 15) & ~wood
    cover = cloth[480:600, COLUMNS].mean(1)
    rows = np.where(cover >= .6)[0]
    return int(480 + rows[0]) if len(rows) else None


def main():
    for folder in ["bg", "bg_clean"]:
        for path in sorted((ROOT / "assets/images" / folder).glob("*.png")):
            print(f"'{folder}/{path.stem}': {towel_top(path)},")


if __name__ == "__main__":
    main()
