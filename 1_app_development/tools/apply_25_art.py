"""Fits the drawn art of 25번 필요한 그림 (1·2·4·5번) into the game's assets.

The generated pictures are bigger than the game needs and their transparent
background is soft (inside alpha about 250, faint haze around). This tool
reads them (it never writes into the source folder), resizes them with
premultiplied area/Lanczos sampling (the sources have no whole-pixel dot grid
to keep: their dots are 3-8 source pixels, not a divisor of the target), and
snaps the alpha so there is no halo:

    python tools/apply_25_art.py <25_generated folder>            # write all
    python tools/apply_25_art.py <25_generated folder> --preview  # + sheet
    python tools/apply_25_art.py <25_generated folder> --measure  # re-fit stoves

Run it in 1_app_development. Outputs:

* assets/images/stove_empty/<stove>.png (941x470): the generated empty
  griddle, scaled and moved onto the original stove (assets/images/stove)
  so the plate, hinge, flames and the six cavities stay where
  griddleCavities and griddleFishClips expect them. [STOVE_FIT] holds the
  scale and offset measured by --measure (gradient match of the plate
  outside the cavities).
* assets/images/stove_fish/<stove>.png (941x470): only the six baked
  bungeoppang of the original stove (tools/empty_griddle.py's fish masks).
  GriddlePainter draws a cooking cell's fish from this layer, so the drawn
  hollow around it stays visible (no rectangle of the old cavity).
* assets/images/cook/piping_bag_<paste>[_squeeze].png (128x192): the paste
  (or the nozzle tip) touches (64, 188), where the finger is.
* assets/images/fx/overflow_<paste>.png (32x48): one drip, its top centre
  on the top edge.
* assets/images/fx/flip_ring.png, flip_ring_fill.png (512x512): ring centre
  (256, 256), radius 236. The generated guide ring has both arrowheads
  pointing the same screen way (the lower-left one runs counter-clockwise),
  so its lower-left half is the upper-right half turned 180 degrees.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets/images"
STOVES = ["iron", "copper", "castiron", "golden"]
PASTES = ["batter", "redbean", "custard", "cocoa"]
STOVE_SIZE = (941, 470)

# Scale and offset (stove pixels) that put each generated empty griddle on
# the original stove, from --measure.
STOVE_FIT = {
    "iron": (0.5310, -0.25, 0.50),
    "copper": (0.5305, -0.25, 0.75),
    "castiron": (0.5310, -0.25, 0.25),
    "golden": (0.5275, -2.75, 1.75),
}

BAG_SIZE = (128, 192)
BAG_TIP = (64, 188)
DRIP_SIZE = (32, 48)
RING_SIZE, RING_RADIUS = 512, 236


def load(path):
    return Image.open(path).convert("RGBA")


def premultiplied_resize(img, size, box=None):
    """Resize without dark or light fringes from transparent pixels."""
    return img.convert("RGBa").resize(size, Image.LANCZOS, box=box).convert("RGBA")


def snap_alpha(img, low, high):
    """Alpha under [low] becomes 0 (haze), over [high] becomes 255."""
    a = np.asarray(img).copy()
    al = a[..., 3]
    al[al < low] = 0
    al[al > high] = 255
    a[al == 0, :3] = 0
    return Image.fromarray(a, "RGBA")


def place(img, scale, dx, dy, size):
    """[img] scaled by [scale] with its top-left at (dx, dy) in a [size]
    canvas (sub-pixel), via a padded source box."""
    pad = 64
    big = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad))
    big.paste(img, (pad, pad))
    w, h = size
    box = (pad - dx / scale, pad - dy / scale,
           pad + (w - dx) / scale, pad + (h - dy) / scale)
    return premultiplied_resize(big, size, box=box)


# ---------------------------------------------------------------- stoves

# griddleFishClips (lib/ui/boost_effects.dart): left out of the stove match.
CLIPS = [(.188, .430, .380, .6085), (.406, .430, .596, .6085),
         (.619, .430, .816, .6085), (.149, .6085, .362, .815),
         (.395, .6085, .603, .815), (.632, .6085, .847, .815)]


def _grad(img):
    a = np.asarray(img).astype(float)
    lum = (a[..., :3] * (a[..., 3:] / 255)) @ np.array([.3, .59, .11])
    lum = nd.gaussian_filter(lum, 1.0)
    return np.hypot(nd.sobel(lum, 0), nd.sobel(lum, 1))


def measure_stove(name, src):
    """Best (scale, dx, dy) by gradient correlation outside the cavities."""
    w, h = STOVE_SIZE
    mask = np.ones((h, w), bool)
    for l, t, r, b in CLIPS:
        mask[int(t * h):int(b * h), int(l * w):int(r * w)] = False
    ref = _grad(load(IMAGES / "stove" / f"{name}.png"))[mask]
    ref = (ref - ref.mean()) / ref.std()
    gen = load(src)

    def score(s, dx, dy):
        g = _grad(place(gen, s, dx, dy, STOVE_SIZE))[mask]
        return float((ref * (g - g.mean()) / g.std()).mean())

    best = (-2.0, w / gen.width, 0.0, 0.0)
    for s in np.arange(.526, .5381, .004):
        for dx in range(-6, 7, 2):
            for dy in range(-6, 7, 2):
                v = score(s, dx, dy)
                if v > best[0]:
                    best = (v, s, dx, dy)
    for step in (1.0, .5, .25):
        _, s0, x0, y0 = best
        for s in (s0 - .002 * step, s0, s0 + .002 * step):
            for dx in (x0 - step, x0, x0 + step):
                for dy in (y0 - step, y0, y0 + step):
                    v = score(s, dx, dy)
                    if v > best[0]:
                        best = (v, s, dx, dy)
    return best


def stove_fish_layers():
    """The six bungeoppang of each original stove, alone."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import empty_griddle as eg
    full = {n: np.asarray(load(IMAGES / "stove" / f"{n}.png")).astype(float)
            for n in STOVES}
    seeds = eg.seeds(full["iron"])
    out = {}
    for n in STOVES:
        a = full[n]
        keep = np.zeros(a.shape[:2], bool)
        for s in seeds:
            keep |= eg.fish_mask(a, s)
        keep = nd.binary_dilation(keep, iterations=1)
        b = a.copy()
        b[~keep] = 0
        out[n] = Image.fromarray(b.round().astype(np.uint8), "RGBA")
    return out


def stoves(src, measure):
    (IMAGES / "stove_empty").mkdir(exist_ok=True)
    (IMAGES / "stove_fish").mkdir(exist_ok=True)
    made = {}
    for n in STOVES:
        path = src / "stove_empty" / f"{n}.png"
        if measure:
            v, s, dx, dy = measure_stove(n, path)
            print(f"  {n}: match {v:.4f} scale {s:.4f} dx {dx:+.2f} dy {dy:+.2f}")
            STOVE_FIT[n] = (s, dx, dy)
        s, dx, dy = STOVE_FIT[n]
        img = snap_alpha(place(load(path), s, dx, dy, STOVE_SIZE), 24, 230)
        img.save(IMAGES / "stove_empty" / f"{n}.png")
        made[f"stove_empty/{n}"] = img
    for n, img in stove_fish_layers().items():
        img.save(IMAGES / "stove_fish" / f"{n}.png")
        made[f"stove_fish/{n}"] = img
    return made


# ---------------------------------------------------------- piping bags

def nozzle_tip_x(a):
    """x of the silver nozzle's lowest rows (low saturation, light grey)."""
    rgb, al = a[..., :3].astype(float), a[..., 3]
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1)
    grey = (al > 128) & (sat < .12) & (mx > 110)
    grey[:int(a.shape[0] * .6)] = False
    lab, k = nd.label(grey)
    j = np.argmax(nd.sum(grey, lab, range(1, k + 1))) + 1
    ys, xs = np.where(lab == j)
    return float(xs[ys >= ys.max() - 6].mean())


def bags(src):
    out_dir = IMAGES / "cook"
    names = [f"{p}{s}" for p in PASTES for s in ("", "_squeeze")]
    srcs = {n: load(src / "cook" / f"piping_bag_{n}.png") for n in names}
    # One scale for all eight: the tallest silhouette fits above the tip.
    boxes = {}
    for n, img in srcs.items():
        a = np.asarray(img)
        ys, xs = np.where(a[..., 3] > 128)
        boxes[n] = (ys.min(), ys.max(), nozzle_tip_x(a))
    scale = min((BAG_TIP[1] - 2) / (b - t + 1) for t, b, _ in boxes.values())
    made = {}
    for n, img in srcs.items():
        top, bottom, tip_x = boxes[n]
        # The lowest opaque row (paste or nozzle) lands on the finger.
        dx = BAG_TIP[0] - (tip_x + .5) * scale
        dy = BAG_TIP[1] - (bottom + 1) * scale
        out = _binary(place(snap_alpha(img, 128, 200), scale, dx, dy, BAG_SIZE))
        out.save(out_dir / f"piping_bag_{n}.png")
        made[f"cook/piping_bag_{n}"] = out
    print(f"  piping bags: scale {scale:.4f}")
    return made


def _binary(img):
    """Hard pixel-art edges: alpha 0 or 255."""
    a = np.asarray(img).copy()
    on = a[..., 3] >= 128
    a[..., 3] = np.where(on, 255, 0)
    a[~on, :3] = 0
    return Image.fromarray(a, "RGBA")


# --------------------------------------------------------------- drips

def drips(src):
    made = {}
    w, h = DRIP_SIZE
    for p in PASTES:
        img = load(src / "fx" / f"overflow_{p}.png")
        a = np.asarray(img)
        ys, xs = np.where(a[..., 3] > 128)
        # Drop the haze around the drip before sampling.
        img = snap_alpha(img, 128, 200)
        bw, bh = xs.max() - xs.min() + 1, ys.max() - ys.min() + 1
        scale = min((w - 2) / bw, h / bh)
        cx = (xs.min() + xs.max() + 1) / 2
        dx = w / 2 - cx * scale
        dy = -ys.min() * scale
        out = _binary(place(img, scale, dx, dy, DRIP_SIZE))
        out.save(IMAGES / "fx" / f"overflow_{p}.png")
        made[f"fx/overflow_{p}"] = out
    return made


# ---------------------------------------------------------------- rings

def ring_geometry(a, low):
    ys, xs = np.where(a[..., 3] > low)
    cx, cy = xs.mean(), ys.mean()
    return cx, cy, float(np.median(np.hypot(xs - cx, ys - cy)))


def rings(src):
    made = {}
    for name in ("flip_ring", "flip_ring_fill"):
        img = load(src / "fx" / f"{name}.png")
        a = np.asarray(img)
        cx, cy, r = ring_geometry(a, 100)
        if name == "flip_ring":
            # Both arrowheads point down-right on screen; clockwise at the
            # lower left is up-left. Use the upper-right half twice.
            turned = img.rotate(180, resample=Image.BICUBIC, center=(cx, cy))
            yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
            lower_left = (xx - cx) - (yy - cy) < 0
            b = a.copy()
            b[lower_left] = np.asarray(turned)[lower_left]
            img = Image.fromarray(b, "RGBA")
        scale = RING_RADIUS / r
        d = RING_SIZE / 2 - (cx + .5) * scale, RING_SIZE / 2 - (cy + .5) * scale
        out = place(img, scale, d[0], d[1], (RING_SIZE, RING_SIZE))
        out = snap_alpha(out, 20, 235 if name == "flip_ring_fill" else 250)
        out.save(IMAGES / "fx" / f"{name}.png")
        made[f"fx/{name}"] = out
        print(f"  {name}: centre ({cx:.1f}, {cy:.1f}) radius {r:.1f} -> scale {scale:.4f}")
    return made


def preview(made, path):
    """Every output at 2x (nearest) on dark and light backing."""
    tiles = []
    for key, img in made.items():
        k = 2 if img.width <= 200 else 1
        if key.startswith("stove") or key.endswith("ring") or key.endswith("fill"):
            k = .5 if img.width > 600 else 1
        big = img.resize((max(1, int(img.width * k)), max(1, int(img.height * k))),
                         Image.NEAREST)
        tiles.append(big)
    w = max(t.width for t in tiles) * 2 + 12
    h = sum(t.height + 6 for t in tiles)
    sheet = Image.new("RGBA", (w, h), (40, 34, 30, 255))
    y = 0
    for t in tiles:
        sheet.alpha_composite(t, (4, y))
        light = Image.new("RGBA", t.size, (120, 200, 120, 255))
        light.alpha_composite(t)
        sheet.paste(light, (w // 2 + 4, y))
        y += t.height + 6
    sheet.save(path)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("source", type=Path, help="the 25_generated folder")
    p.add_argument("--preview", action="store_true")
    p.add_argument("--measure", action="store_true",
                   help="re-measure STOVE_FIT (slow, a few minutes)")
    args = p.parse_args()
    src = args.source.resolve()
    made = {}
    print("stoves")
    made.update(stoves(src, args.measure))
    print("piping bags")
    made.update(bags(src))
    print("drips")
    made.update(drips(src))
    print("rings")
    made.update(rings(src))
    for key, img in made.items():
        print(f"  {key}.png {img.size}")
    if args.preview:
        out = ROOT / "build" / "apply_25_art_preview.png"
        out.parent.mkdir(exist_ok=True)
        preview(made, out)
        print("preview", out.relative_to(ROOT).as_posix())


if __name__ == "__main__":
    main()
