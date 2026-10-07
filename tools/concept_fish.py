"""Bungeoppang sprites from the concept art (stage 14).

The approved concept fish (이미지/붕어빵게임_개발에셋_261006_1905_01/
01_원본전체/붕어빵선택_원본) is cut out of its iron mould by colour, then
tools/pixelize.py turns it into the 96x72 game sprite. This script finishes
that sprite and draws everything that has to match its silhouette:

- fish/redbean.png              base (closed dark outline added)
- fish/redbean@<pattern>.png    heartscale, starmark, crispgrid: the body's
                                round scales replaced by the pattern
- topping/<id>.png              sugar, choco, almond, sprinkle overlays

    python tools/pixelize.py <cut dir> -o <out> --size 96x72 --colors 20
    python tools/concept_fish.py <out>/redbean.png
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
FISH = ROOT / "assets/images/fish"
TOPPING = ROOT / "assets/images/topping"

OUTLINE = (58, 30, 26, 255)  # Cozy.ink, the concept's dark chocolate line


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def outlined(img):
    """Adds a closed 1-pixel outline around the opaque silhouette."""
    a = np.array(img)
    solid = a[..., 3] > 0
    ring = nd.binary_dilation(solid, structure=np.ones((3, 3))) & ~solid
    a[ring] = OUTLINE
    return Image.fromarray(a, "RGBA")


def body_region(img):
    """The scaled flank: inside the silhouette, behind the gill line and in
    front of the tail, clear of the edge, the fins and the eye."""
    a = np.array(img)
    solid = a[..., 3] > 0
    inner = nd.binary_erosion(solid, iterations=5)
    ys, xs = np.where(solid)
    left, right = xs.min(), xs.max()
    width = right - left
    region = np.zeros_like(solid)
    x0, x1 = int(left + width * 0.42), int(left + width * 0.69)
    region[:, x0:x1] = True
    return inner & region


def shades(img):
    """Light, base and dark crust tones of the sprite (by brightness)."""
    a = np.array(img)
    px = a[a[..., 3] > 0][:, :3]
    lum = px @ np.array([0.3, 0.59, 0.11])
    order = np.argsort(lum)
    pick = lambda q: tuple(int(v) for v in px[order[int(len(order) * q)]]) + (255,)
    return pick(0.85), pick(0.55), pick(0.18)


def flatten(img, region, base, light):
    """Erases the round scales in [region] to the plain crust tone, with a
    sparse light dither so it still reads as baked dough."""
    a = np.array(img)
    a[region] = base
    ys, xs = np.where(region)
    for y, x in zip(ys, xs):
        if (x * 3 + y * 5) % 11 == 0:
            a[y, x] = light
    return a


def stamp(a, region, cells, dark, light):
    """Draws embossed marks: [cells] are (x, y) dark pixels; each gets a
    highlight below it, as if pressed into the dough."""
    for x, y in cells:
        if 0 <= y < a.shape[0] and 0 <= x < a.shape[1] and region[y, x]:
            a[y, x] = dark
            if y + 1 < a.shape[0] and region[y + 1, x] and (x, y + 1) not in cells:
                a[y + 1, x] = light


HEART = [".X.X.", "XXXXX", ".XXX.", "..X.."]
STAR = ["......X......", ".....XXX.....", ".....XXX.....", "XXXXXXXXXXXXX",
        ".XXXXXXXXXXX.", "...XXXXXXX...", "...XXXXXXX...", "..XXXX.XXXX..",
        "..XXX...XXX..", ".XX.......XX."]


def shape_cells(rows, ox, oy):
    return {(ox + x, oy + y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "X"}


def pattern(img, kind):
    region = body_region(img)
    light, base, dark = shades(img)
    ys, xs = np.where(region)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    if kind == "starmark":
        # A brand pressed into the middle: clear a round patch for it and
        # keep the concept's own scales around it.
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        yy, xx = np.mgrid[: region.shape[0], : region.shape[1]]
        region = region & ((xx - cx) ** 2 + (yy - cy) ** 2 <= 8.5 ** 2)
    a = flatten(img, region, base, light)
    cells = set()
    if kind == "heartscale":
        for row, y in enumerate(range(y0 + 1, y1 - 2, 6)):
            for x in range(x0 + (3 if row % 2 else 0), x1 - 3, 7):
                cells |= shape_cells(HEART, x, y)
    elif kind == "starmark":
        cx, cy = int((x0 + x1) / 2) - 6, int((y0 + y1) / 2) - 5
        cells |= shape_cells(STAR, cx, cy)
    elif kind == "crispgrid":
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if (x + y) % 7 == 0 or (x - y) % 7 == 0:
                    cells.add((x, y))
        # A softer line: the shade between base and dark.
        dark = tuple((np.array(dark) + np.array(base)) // 2)
    stamp(a, region, cells, dark, light)
    return Image.fromarray(a, "RGBA")


def top_band(img, depth=7):
    """Pixels of the upper back where toppings sit (below the outline)."""
    a = np.array(img)
    solid = a[..., 3] > 0
    inner = nd.binary_erosion(solid, iterations=2)
    band = np.zeros_like(solid)
    for x in range(solid.shape[1]):
        col = np.where(inner[:, x])[0]
        if len(col):
            band[col[0]:col[0] + depth, x] = True
    ys, xs = np.where(solid)
    left, right = xs.min(), xs.max()
    band[:, : int(left + (right - left) * 0.12)] = False  # not over the face
    band[:, int(left + (right - left) * 0.78):] = False  # not over the tail
    return band & inner


def topping(img, kind):
    band = top_band(img, depth=12 if kind == "choco" else 9)
    out = np.zeros(np.array(img).shape, np.uint8)
    h, w = band.shape
    ys, xs = np.where(band)
    rng = np.random.default_rng({"sugar": 1, "choco": 2, "almond": 3, "sprinkle": 4}[kind])
    top = {x: ys[xs == x].min() for x in set(xs)}

    def put(x, y, colour):
        if 0 <= x < w and 0 <= y < h and band[y, x]:
            out[y, x] = rgb(colour)

    if kind == "sugar":
        for y, x in zip(ys, xs):
            depth = y - top[x]
            if rng.random() < 0.3 * (1 - depth / 9):  # thicker at the top
                put(x, y, "#FFFFFF" if rng.random() < 0.7 else "#F4F0E8")
    elif kind == "choco":
        # Follow the back, not the dorsal fin: the lowest top edge nearby.
        xs_sorted = sorted(top)
        for x in xs_sorted:
            near = [top[n] for n in range(x - 6, x + 7) if n in top]
            y = max(near) + 2 + int(round(2 + 2 * np.sin(x / 2.6)))
            put(x, y - 1, "#A0623A")
            for dy in range(3):
                put(x, y + dy, "#3A1E1A" if dy else "#5C3020")
            if x % 7 == 3:  # a drip
                put(x, y + 3, "#3A1E1A")
                put(x, y + 4, "#3A1E1A")
    elif kind == "almond":
        xs_sorted = sorted(top)
        for i in range(5):
            x = xs_sorted[int((i + 0.5) * len(xs_sorted) / 5)] - 2
            y = top[x + 2] + 2 + (i % 2)
            flake = ["..OOO..", ".OCCCO.", "OCCCCCO", ".OOOOO."]
            for dy, row in enumerate(flake):
                for dx, c in enumerate(row):
                    if c == "O":
                        put(x + dx - 1, y + dy, "#A8642F")
                    elif c == "C":
                        put(x + dx - 1, y + dy, "#FFF3DC")
    elif kind == "sprinkle":
        colours = ["#F6A9BE", "#FED794", "#98DDB2", "#9FD6EC", "#BBA6EC"]
        for y, x in zip(ys, xs):
            if rng.random() < 0.13:
                c = colours[int(rng.integers(len(colours)))]
                d = 1 if rng.random() < 0.5 else -1
                for k in range(3):  # a short diagonal stick
                    put(x + k, y + d * (k // 2), c)
    return Image.fromarray(out, "RGBA")


def main(src):
    base = outlined(Image.open(src).convert("RGBA"))
    assert base.size == (96, 72), base.size
    base.save(FISH / "redbean.png")
    for kind in ["heartscale", "starmark", "crispgrid"]:
        pattern(base, kind).save(FISH / f"redbean@{kind}.png")
    for kind in ["sugar", "choco", "almond", "sprinkle"]:
        topping(base, kind).save(TOPPING / f"{kind}.png")
    print("wrote fish/redbean*.png and topping/*.png")


if __name__ == "__main__":
    main(sys.argv[1])
