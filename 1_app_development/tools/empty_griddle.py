"""Temporary empty griddles (24번 4단계): the stove sprites without their six
baked bungeoppang.

Superseded (2026-11-17): the game now ships drawn empty griddles fitted by
tools/apply_25_art.py, which also reuses this file's fish masks for
assets/images/stove_fish. This tool now writes its temporary art to
build/stove_empty_temp, so running it no longer overwrites the drawn art.

The stove art (assets/images/stove/<id>.png) has a bungeoppang in every
cavity. Until real empty art is drawn, this tool paints each bungeoppang over
with the dark cavity floor, keeping a faint fish-shaped hollow, and writes
assets/images/stove_empty/<id>.png at the same size, so griddleCavities and
GriddlePainter's clipping line up:

    python tools/empty_griddle.py            # write all four
    python tools/empty_griddle.py --preview  # also a side-by-side sheet

Replacing a stove_empty file with drawn art needs no code change, as long as
it keeps the stove's canvas size and cavity positions.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
STOVE = ROOT / "assets/images/stove"
OUT = ROOT / "build/stove_empty_temp"
NAMES = ["iron", "copper", "castiron", "golden"]


def _hsv(a):
    rgb = a[..., :3] / 255
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return rgb, mx, sat


def seeds(iron):
    """The six bungeoppang of the iron griddle (saturated orange blobs); the
    other stoves are recolours with the fish in (nearly) the same place."""
    rgb, mx, sat = _hsv(iron)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    fish = (sat > .45) & (r > .55) & (r >= g) & (g > b) & (iron[..., 3] > 0)
    lab, n = nd.label(fish)
    sizes = nd.sum(fish, lab, range(1, n + 1))
    big = np.argsort(sizes)[::-1][:6] + 1
    return [nd.binary_fill_holes(lab == i) for i in big]


def fish_mask(a, seed):
    """The bright bungeoppang inside the dark cavity around [seed]."""
    region = nd.binary_dilation(seed, iterations=10)
    rgb, mx, sat = _hsv(a)
    lum = rgb @ np.array([.3, .59, .11])
    # The cavity floor around the fish is the darkest part of the region.
    ring = region & ~nd.binary_dilation(seed, iterations=3)
    floor = np.percentile(lum[ring], 35)
    bright = region & (lum > floor + .18) & (sat > .3)
    lab, n = nd.label(bright)
    if n == 0:
        return seed
    overlap = nd.sum(seed, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, v in enumerate(overlap) if v > 50])
    keep = nd.binary_closing(keep, iterations=3)
    keep = nd.binary_fill_holes(keep)
    # Take in the fish's own dark outline.
    return nd.binary_dilation(keep, iterations=2) & region


def empty(a, masks):
    out = a.copy()
    rgb = a[..., :3]
    lum = rgb @ np.array([.3, .59, .11])
    for m in masks:
        ring = nd.binary_dilation(m, iterations=5) & ~m & (a[..., 3] > 0)
        ring_lum = lum[ring]
        # The cavity floor: the darker half of the pixels around the fish.
        floor = np.median(rgb[ring][ring_lum <= np.median(ring_lum)], axis=0)
        # The plate's metal: the lighter pixels a little further out.
        far = nd.binary_dilation(m, iterations=24) & ~nd.binary_dilation(m, iterations=8) & (a[..., 3] > 0)
        far_lum = lum[far]
        metal = np.median(rgb[far][far_lum >= np.percentile(far_lum, 60)], axis=0)
        # A fish-shaped hollow in the metal: the fish's own shading, squeezed
        # around a colour between the floor and the plate, so the empty
        # cavity still reads as a bungeoppang mould.
        base = floor * .6 + metal * .4
        f = lum[m]
        shade = (f - f.mean()) / max(f.std(), 1e-6)
        k = np.clip(1 + .22 * shade, .55, 1.45)[:, None]
        out[m, :3] = np.clip(base[None, :] * k, 0, 255)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--preview", action="store_true")
    args = p.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    load = lambda n: np.asarray(Image.open(STOVE / f"{n}.png").convert("RGBA")).astype(float)
    iron_seeds = seeds(load("iron"))
    sheets = []
    for name in NAMES:
        a = load(name)
        masks = [fish_mask(a, s) for s in iron_seeds]
        img = Image.fromarray(empty(a, masks).round().astype(np.uint8), "RGBA")
        img.save(OUT / f"{name}.png")
        sheets.append((Image.open(STOVE / f"{name}.png").convert("RGBA"), img))
        print(name, img.size, "fish px", [int(m.sum()) for m in masks])
    if args.preview:
        w, h = sheets[0][0].size
        sheet = Image.new("RGBA", (w * 2, h * len(sheets)), (255, 255, 255, 255))
        for i, (before, after) in enumerate(sheets):
            sheet.alpha_composite(before, (0, i * h))
            sheet.alpha_composite(after, (w, i * h))
        sheet.save(OUT.parent.parent.parent / "build" / "empty_griddle_preview.png")


if __name__ == "__main__":
    main()
