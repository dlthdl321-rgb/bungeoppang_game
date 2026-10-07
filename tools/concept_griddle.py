"""Griddle (stove) sprites from the concept art (stage 14).

Cuts the six-cavity gas griddle out of 07_UI's cooking screen concept
(조리컷가스화면) by removing the wood around it, keeps it at the concept's resolution on a
2:1 stove canvas, and recolours only its metal for the other stoves:

    python tools/concept_griddle.py

Writes assets/images/stove/{iron,copper,castiron,golden}.png and prints the
centres of the six bungeoppang cavities (fractions of the sprite) for
griddleCavities in lib/ui/boost_effects.dart.
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
CONCEPT = (ROOT / "이미지/붕어빵게임_개발에셋_261006_1905_01/01_원본전체"
           / "조리컷가스화면_원본_261006_1905_01.png")
STOVE = ROOT / "assets/images/stove"
SIZE = (80, 40)

# Metal ramps (dark -> light) per stove; iron keeps the concept's own greys.
METALS = {
    "copper": ["#3A1A10", "#8F3C20", "#C1682D", "#E39E57", "#FBC18A", "#FFE3C4"],
    "castiron": ["#14101A", "#2A2333", "#3E3448", "#5E4E66", "#8A7A92", "#B8ABC0"],
    "golden": ["#3A2408", "#9A6420", "#E3A23A", "#FED794", "#FFEBB0", "#FFF8DC"],
}


def cut():
    im = Image.open(CONCEPT).convert("RGB")
    crop = im.crop((0, 1180, im.width, im.height))
    a = np.asarray(crop).astype(float) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(2), a.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    wood = (sat > 0.28) & (r >= g) & (g >= b) & (mx > 0.15)
    lab, _ = nd.label(wood)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    keep = ~np.isin(lab, list(edge))
    # Shadowed wood below the burner reads as beige: drop warm, light pixels
    # under the flames.
    rows = np.arange(a.shape[0])[:, None]
    flames = np.where((b > 0.7) & (b > r + 0.3))[0]
    below = rows > (flames.max() + 8 if len(flames) else a.shape[0])
    keep &= ~(below & (r > b + 0.06) & (mx > 0.35))
    keep = nd.binary_opening(keep, iterations=2)
    lab2, n2 = nd.label(keep)
    sizes = nd.sum(keep, lab2, range(1, n2 + 1))
    keep = nd.binary_fill_holes(lab2 == (np.argmax(sizes) + 1))
    ys, xs = np.where(keep)
    rgba = np.dstack([np.asarray(crop), (keep * 255).astype(np.uint8)])
    return Image.fromarray(rgba, "RGBA").crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))


def pixelize(img):
    """Shrinks to the stove canvas keeping the aspect ratio, bottom-aligned.
    The concept griddle is drawn in perspective, so pixelize.py's uniform
    grid detection does not apply; colours are merged to 24 instead."""
    w = SIZE[0]
    h = min(SIZE[1], round(img.height * w / img.width))
    rgb = img.convert("RGB").resize((w, h), Image.LANCZOS)
    alpha = img.getchannel("A").resize((w, h), Image.BOX).point(lambda v: 255 if v >= 128 else 0)
    rgb = rgb.quantize(colors=24, method=Image.Quantize.MEDIANCUT).convert("RGB")
    small = rgb.convert("RGBA")
    small.putalpha(alpha)
    canvas = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(small, ((SIZE[0] - w) // 2, SIZE[1] - h))
    # Leftover light wood at the outer bottom corners (outside the plate).
    px = np.array(canvas)
    for y in range(SIZE[1] // 2, SIZE[1]):
        for x in list(range(0, 5)) + list(range(SIZE[0] - 7, SIZE[0])):
            r, g, b, al = (int(v) for v in px[y, x])
            if al and r > b + 40 and r > 150:
                px[y, x, 3] = 0
    return Image.fromarray(px, "RGBA")


def native(img):
    """The cut griddle at the concept's own resolution (no shrinking, no
    colour merging) on a canvas with the stove's 2:1 shape, bottom-aligned,
    so GriddlePainter and griddleCavities' fractions work unchanged."""
    w = img.width
    h = w * SIZE[1] // SIZE[0]
    canvas = Image.new("RGBA", (w, max(h, img.height)), (0, 0, 0, 0))
    canvas.alpha_composite(img, (0, canvas.height - img.height))
    # Leftover light wood at the outer bottom corners (outside the plate).
    px = np.array(canvas)
    sx = w / SIZE[0]
    edge = list(range(0, round(5 * sx))) + list(range(w - round(7 * sx), w))
    lower = px[canvas.height // 2:, edge]
    r, g, b, al = (lower[..., i].astype(int) for i in range(4))
    lower[..., 3] = np.where((al > 0) & (r > b + 40) & (r > 150), 0, al)
    px[canvas.height // 2:, edge] = lower
    return Image.fromarray(px, "RGBA")


def is_metal(px):
    rgb = px[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    blue = (rgb[..., 2] > rgb[..., 0] + 0.15)
    return (px[..., 3] > 0) & (sat < 0.3) & ~blue


def recolour(img, ramp):
    a = np.array(img)
    metal = is_metal(a)
    lum = (a[..., :3].astype(float) @ np.array([0.3, 0.59, 0.11])) / 255
    cols = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in ramp]
    idx = np.clip((lum * len(cols)).astype(int), 0, len(cols) - 1)
    for y, x in zip(*np.where(metal)):
        a[y, x, :3] = cols[idx[y, x]]
    return Image.fromarray(a, "RGBA")


def cavities(img):
    """Centres of the six baked bungeoppang (orange blobs), row by row."""
    a = np.array(img).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    fish = (a[..., 3] > 0) & (r > 150) & (r > b + 60) & (g > b + 20)
    lab, n = nd.label(fish)
    sizes = nd.sum(fish, lab, range(1, n + 1))
    biggest = np.argsort(sizes)[::-1][:6] + 1
    centres = [nd.center_of_mass(fish, lab, i) for i in biggest]
    centres = sorted(centres, key=lambda c: (round(c[0] / 6), c[1]))
    return [(round(c[1] / img.width, 3), round(c[0] / img.height, 3)) for c in centres]


def main():
    # The user asked for finer dots: keep the concept's resolution.
    # pixelize() is the older 80x40 export.
    iron = native(cut())
    iron.save(STOVE / "iron.png")
    for name, ramp in METALS.items():
        recolour(iron, ramp).save(STOVE / f"{name}.png")
    print("griddleCavities (x, y):", cavities(iron))


if __name__ == "__main__":
    main()
