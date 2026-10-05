"""Turn AI-generated "pixel art" into clean, game-ready pixel sprites.

AI images fake pixel art: blocks have uneven sizes, edges are blurred and
colors drift. This script rebuilds a true low-resolution image:

  1. detects the image's fake pixel grid (pitch and offset) from its edges
  2. (sprite) removes the flat background by flood fill from the borders
  3. samples each grid cell from the median of its center, so blur and AI
     noise at cell borders are ignored -> one true pixel per fake pixel
  4. (sprite) crops to the content and centers it on the target canvas,
     shrinking only if it does not fit
     (background) center-crops to the target aspect ratio and resizes
  5. snaps colors to the shared game palette (or N adaptive colors)
  6. hardens alpha and removes tiny floating islands (--despeckle: lone pixels)

Output: <name>.png, plus preview/<name>@<preview>x.png enlarged with
nearest neighbor for checking (a subfolder, so it is not bundled). In Flutter draw it with FilterQuality.none and
integer scaling only.

Examples:
  python tools/pixelize.py raw/redbean.png -o assets/images/fish --size 64x48
  python tools/pixelize.py raw/night.png -o assets/images/bg --size 180x320 --mode background
  python tools/pixelize.py raw/icons/ -o assets/images/icons --size 24x24 --colors 12
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from palette import GAME_PALETTE  # shared with draw_pixel_assets.py

# Fill colors that mark removed background; the one farthest from the
# background is used, since floodfill skips seeds already near the fill color.
SENTINELS = [(255, 0, 254), (1, 255, 2), (2, 1, 255), (254, 255, 1)]


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def remove_background(img, tolerance):
    """Flood fill from border pixels whose color matches a corner.

    Runs on a median-filtered copy so AI noise does not stop the fill.
    """
    rgb = img.convert("RGB").filter(ImageFilter.MedianFilter(5))
    w, h = rgb.size
    corners = {rgb.getpixel(p) for p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]}
    sentinel = max(SENTINELS, key=lambda c: min(sum(abs(a - b) for a, b in zip(c, k)) for k in corners))
    seeds = [(x, 0) for x in range(0, w, 8)] + [(x, h - 1) for x in range(0, w, 8)]
    seeds += [(0, y) for y in range(0, h, 8)] + [(w - 1, y) for y in range(0, h, 8)]
    for seed in seeds:
        px = rgb.getpixel(seed)
        if px == sentinel:
            continue
        if min(sum(abs(a - b) for a, b in zip(px, c)) for c in corners) <= tolerance * 3:
            ImageDraw.floodfill(rgb, seed, sentinel, thresh=tolerance)
    out = np.array(img.convert("RGBA"))
    out[(np.array(rgb) == sentinel).all(axis=2), 3] = 0
    return out


def grid_pitch(signal, max_pitch):
    """Pitch and phase of the strongest periodic edge pattern in `signal`.

    Edges on a grid of pitch p line up in phase (concentration near 1); p/2
    and p/3 score just as high, so the largest pitch near the top score wins.
    """
    signal = np.clip(signal - np.median(signal), 0, None)
    total = signal.sum()
    if total == 0:
        return None
    x = np.arange(len(signal))
    scores = []
    for p in np.arange(3.0, max_pitch, 0.05):
        z = (signal * np.exp(2j * np.pi * x / p)).sum() / total
        scores.append((abs(z), p, np.angle(z)))
    top = max(s[0] for s in scores)
    _, p, angle = max((s for s in scores if s[0] >= top * 0.92), key=lambda s: s[1])
    return p, (angle / (2 * np.pi) * p) % p


def detect_grid(arr):
    """Cell edges along x and y of the AI image's fake pixel grid."""
    gray = arr[..., :3].astype(np.float64).mean(axis=2)
    h, w = gray.shape
    fx = grid_pitch(np.abs(np.diff(gray, axis=1)).sum(axis=0), min(w, h) / 6)
    fy = grid_pitch(np.abs(np.diff(gray, axis=0)).sum(axis=1), min(w, h) / 6)
    if fx is None or fy is None:
        return None
    (px, ox), (py, oy) = fx, fy
    if abs(px - py) < 0.5:  # square pixels: share one pitch
        px = py = (px + py) / 2
    # diff index i is the edge between pixels i and i+1.
    ox, oy = ox + 0.5, oy + 0.5
    xs = edges_within(np.arange(ox - px * np.ceil(ox / px), w + px, px), w, px)
    ys = edges_within(np.arange(oy - py * np.ceil(oy / py), h + py, py), h, py)
    return xs, ys, (px, py)


def edges_within(edges, size, pitch):
    """Clip edges to the image and drop border slivers under half a pitch."""
    edges = np.unique(np.clip(edges, 0, size))
    if len(edges) > 2 and edges[1] - edges[0] < pitch / 2:
        edges = edges[1:]
    if len(edges) > 2 and edges[-1] - edges[-2] < pitch / 2:
        edges = edges[:-1]
    return edges


def cell_sample(arr, tw, th, core, edges=None):
    """Median color of the central `core` fraction of each cell."""
    h, w = arr.shape[:2]
    xs, ys = edges or (np.linspace(0, w, tw + 1), np.linspace(0, h, th + 1))
    out = np.zeros((len(ys) - 1, len(xs) - 1, 4), dtype=np.uint8)
    pad = (1 - core) / 2
    for j in range(len(ys) - 1):
        y0, y1 = ys[j], ys[j + 1]
        cy0 = int(y0 + (y1 - y0) * pad)
        cy1 = max(cy0 + 1, int(round(y1 - (y1 - y0) * pad)))
        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            cx0 = int(x0 + (x1 - x0) * pad)
            cx1 = max(cx0 + 1, int(round(x1 - (x1 - x0) * pad)))
            block = arr[cy0:cy1, cx0:cx1].reshape(-1, 4)
            opaque = block[block[:, 3] >= 128]
            if len(block) == 0 or len(opaque) * 2 < len(block):
                continue  # mostly transparent -> stays transparent
            out[j, i, :3] = np.median(opaque[:, :3], axis=0)
            out[j, i, 3] = 255
    return out


def snap_to_palette(arr, palette):
    """Nearest palette color by perceptual 'redmean' distance."""
    pal = np.array(palette, dtype=np.float64)
    rgb = arr[..., :3].reshape(-1, 1, 3).astype(np.float64)
    rmean = (rgb[..., 0] + pal[None, :, 0]) / 2
    d = rgb - pal[None]
    dist = (2 + rmean / 256) * d[..., 0] ** 2 + 4 * d[..., 1] ** 2 + (2 + (255 - rmean) / 256) * d[..., 2] ** 2
    arr[..., :3] = pal[dist.argmin(axis=1)].reshape(arr.shape[:2] + (3,)).astype(np.uint8)
    return arr


def adaptive_palette(arr, colors):
    opaque = arr[arr[..., 3] == 255][:, :3]
    if len(opaque) == 0:
        return []
    strip = Image.fromarray(opaque.reshape(1, -1, 3))
    q = strip.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    flat = q.getpalette()[: colors * 3]
    return [tuple(flat[i:i + 3]) for i in range(0, len(flat), 3)]


def despeckle(arr):
    """Drop lone pixels: replace one whose 4 neighbors all agree on another value."""
    out = arr.copy()
    h, w = arr.shape[:2]
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            n = [tuple(arr[y - 1, x]), tuple(arr[y + 1, x]), tuple(arr[y, x - 1]), tuple(arr[y, x + 1])]
            if n.count(n[0]) == 4 and n[0] != tuple(arr[y, x]):
                out[y, x] = n[0]
    return out


def remove_islands(arr, min_size):
    """Clear opaque 4-connected regions smaller than `min_size` pixels."""
    h, w = arr.shape[:2]
    seen = np.zeros((h, w), dtype=bool)
    for y0 in range(h):
        for x0 in range(w):
            if seen[y0, x0] or arr[y0, x0, 3] == 0:
                continue
            region, stack = [], [(y0, x0)]
            seen[y0, x0] = True
            while stack:
                y, x = stack.pop()
                region.append((y, x))
                for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                    if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx] and arr[ny, nx, 3]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            if len(region) < min_size:
                for y, x in region:
                    arr[y, x] = 0
    return arr


def native_pixels(arr, args):
    """One output pixel per fake pixel of the AI image, or None."""
    if args.no_grid:
        return None
    grid = detect_grid(arr)
    if grid is None:
        return None
    xs, ys, (px, py) = grid
    print(f"  grid pitch {px:.2f} x {py:.2f} -> {len(xs) - 1}x{len(ys) - 1} cells")
    return cell_sample(arr, 0, 0, args.core, (xs, ys))


def fit(arr, tw, th, margin, core):
    """Center `arr` on a tw x th canvas, shrinking only when it does not fit."""
    bh, bw = arr.shape[:2]
    avail_w, avail_h = tw - 2 * margin, th - 2 * margin
    if bw > avail_w or bh > avail_h:
        scale = min(avail_w / bw, avail_h / bh)
        print(f"  content {bw}x{bh} larger than {avail_w}x{avail_h}: shrinking (detail may be lost)")
        arr = cell_sample(arr, max(1, round(bw * scale)), max(1, round(bh * scale)), core)
        bh, bw = arr.shape[:2]
    canvas = np.zeros((th, tw, 4), dtype=np.uint8)
    ox, oy = (tw - bw) // 2, (th - bh) // 2
    canvas[oy:oy + bh, ox:ox + bw] = arr
    return canvas


def process(src, dst_dir, args):
    print(src.name)
    img = Image.open(src)
    if args.mode == "sprite":
        arr = np.array(img.convert("RGBA")) if args.keep_bg else remove_background(img, args.tolerance)
        small = native_pixels(arr, args)
        if small is None:
            if not args.size:
                print("  skip: no pixel grid found; pass --size")
                return
            small = arr
        ys, xs = np.nonzero(small[..., 3] >= 128)
        if len(xs) == 0:
            print("  skip: nothing left after background removal")
            return
        small = small[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        if args.size:
            tw, th = args.size
        else:
            tw, th = small.shape[1] + 2 * args.margin, small.shape[0] + 2 * args.margin
        canvas = fit(small, tw, th, args.margin, args.core)
    else:
        arr = np.array(img.convert("RGBA"))
        arr[..., 3] = 255
        small = native_pixels(arr, args)
        small = arr if small is None else small
        small[..., 3] = 255
        h, w = small.shape[:2]
        tw, th = args.size or (w, h)
        if w / h > tw / th:  # too wide: crop sides
            nw = round(h * tw / th)
            small = small[:, (w - nw) // 2:(w - nw) // 2 + nw]
        else:
            nh = round(w * th / tw)
            small = small[(h - nh) // 2:(h - nh) // 2 + nh]
        h, w = small.shape[:2]
        canvas = small
        if (w, h) != (tw, th):
            print(f"  resized {w}x{h} -> {tw}x{th}")
            canvas = np.array(Image.fromarray(small).resize((tw, th), Image.Resampling.NEAREST))

    palette = adaptive_palette(canvas, args.colors) if args.colors else [hex_to_rgb(c) for c in GAME_PALETTE]
    if palette:
        mask = canvas[..., 3] == 255
        snapped = snap_to_palette(canvas.copy(), palette)
        canvas[mask] = snapped[mask]
    canvas[canvas[..., 3] < 255] = 0
    if args.despeckle:
        canvas = despeckle(canvas)
    if args.mode == "sprite" and args.min_island > 1:
        canvas = remove_islands(canvas, args.min_island)

    dst_dir.mkdir(parents=True, exist_ok=True)
    out = Image.fromarray(canvas, "RGBA")
    out.save(dst_dir / f"{src.stem}.png")
    if args.preview:
        (dst_dir / "preview").mkdir(exist_ok=True)
        out.resize((tw * args.preview, th * args.preview), Image.Resampling.NEAREST).save(
            dst_dir / "preview" / f"{src.stem}@{args.preview}x.png")
    used = len({tuple(p) for p in canvas.reshape(-1, 4) if p[3]})
    print(f"  -> {dst_dir / (src.stem + '.png')} ({tw}x{th}, {used} colors)")


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # Korean paths on Windows consoles
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input", type=Path, help="image file or folder of images")
    p.add_argument("-o", "--out", type=Path, required=True, help="output folder")
    p.add_argument("--size", type=lambda s: tuple(int(v) for v in s.lower().split("x")),
                   help="canvas size WxH, e.g. 64x48 (default: the detected native size)")
    p.add_argument("--mode", choices=["sprite", "background"], default="sprite")
    p.add_argument("--colors", type=int, default=0, help="N adaptive colors instead of the game palette")
    p.add_argument("--tolerance", type=int, default=40, help="background flood-fill tolerance (0-255)")
    p.add_argument("--keep-bg", action="store_true", help="sprite mode: keep the background")
    p.add_argument("--margin", type=int, default=1, help="sprite mode: empty pixels around the content")
    p.add_argument("--core", type=float, default=0.5, help="center fraction of each cell to sample")
    p.add_argument("--despeckle", action="store_true", help="also replace lone pixels (can erase 1px eyes)")
    p.add_argument("--no-grid", action="store_true", help="skip grid detection, sample straight to --size")
    p.add_argument("--min-island", type=int, default=4, help="sprite mode: drop floating bits smaller than this")
    p.add_argument("--preview", type=int, default=8, help="preview scale, 0 to skip")
    args = p.parse_args()

    exts = {".png", ".jpg", ".jpeg", ".webp"}
    files = sorted(f for f in args.input.iterdir() if f.suffix.lower() in exts) if args.input.is_dir() else [args.input]
    for f in files:
        process(f, args.out, args)


if __name__ == "__main__":
    main()
