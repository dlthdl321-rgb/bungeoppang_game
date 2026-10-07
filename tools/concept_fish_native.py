"""The centre bungeoppang at the concept's own resolution.

Cuts the fish out of its iron mould in the approved concept (붕어빵선택,
raw/references/references_010.png) by colour and writes it, unshrunk, to
assets/images/fish/redbean.png on a 4:3 canvas laid out like the 96x72
sprite (the fish fills ~77% of the width, centred), so FishPainter,
BakeTarget's mould alignment and the 96x72 topping overlays still line up.

The pattern variants (fish/redbean@*.png) and toppings stay as
tools/concept_fish.py makes them.

    python tools/concept_fish_native.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / '이미지' / 'bungeoppang_raw_assets_261007_0114_01' / 'raw'
       / 'references' / 'references_010.png')
OUT = ROOT / 'assets' / 'images' / 'fish' / 'redbean.png'
FILL = .77  # fish width / canvas width, as in the 96x72 sprite


def cut():
    img = Image.open(SRC).convert('RGB')
    a = np.asarray(img).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # Golden crust and its darker baked edges; not the grey iron or steam.
    crust = (r > 120) & (r > b + 45) & (g > b + 10)
    crust = nd.binary_opening(crust, iterations=2)
    labels, n = nd.label(crust)
    sizes = nd.sum(crust, labels, range(1, n + 1))
    fish = nd.binary_fill_holes(labels == np.argmax(sizes) + 1)
    fish = nd.binary_closing(fish, iterations=3)
    ys, xs = np.where(fish)
    rgba = np.dstack([np.asarray(img), (fish * 255).astype(np.uint8)])
    return Image.fromarray(rgba, 'RGBA').crop(
        (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def main():
    fish = cut()
    width = round(fish.width / FILL)
    canvas = Image.new('RGBA', (width, round(width * .75)))
    canvas.alpha_composite(fish, ((canvas.width - fish.width) // 2,
                                  (canvas.height - fish.height) // 2))
    canvas.save(OUT)
    print('redbean.png', canvas.size, 'fish', fish.size)


if __name__ == '__main__':
    main()
