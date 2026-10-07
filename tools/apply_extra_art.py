"""Applies the extra art set ("이미지/추가 생성 이미지") to assets/images.

Sources are RAW: RGB on a flat white background, at 3-15x the game size.
The source folder is only read. Every stage writes into assets/images and,
with --preview, a check sheet into build/extra_art_preview (not bundled).

Mapping and decisions: docs/prompts/오늘의붕어빵_추가이미지적용프롬프트_
261007_2012_01.md (B절) and the stage reports.

  python tools/apply_extra_art.py fish topping stove [--preview]
  python tools/apply_extra_art.py all --preview

Rules kept by every stage:
  - the white background goes by flood fill from the borders only
    (pixelize.remove_background), never by colour, so white clothes,
    sugar or snow inside a figure stay;
  - art is only ever shrunk (area sampling); nothing is scaled up;
  - outputs keep the canvas size of the files they replace.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelize import adaptive_palette, remove_background, snap_to_palette  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / '이미지' / '추가 생성 이미지'
OUT = ROOT / 'assets' / 'images'
PREVIEW = ROOT / 'build' / 'extra_art_preview'


# ---------------------------------------------------------------- helpers

def load_cut(path, tolerance=24):
    """The source with its border-connected white background made clear."""
    arr = remove_background(Image.open(path), tolerance)
    arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
    return arr


def bbox(alpha):
    ys, xs = np.nonzero(alpha)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def area_sample(arr, w, h, min_cover=0.5):
    """Shrinks RGBA [arr] to w x h: each output pixel is the mean colour of
    the opaque source pixels in its cell, opaque when at least [min_cover]
    of the cell is. Hard alpha, no scaling up."""
    sh, sw = arr.shape[:2]
    assert w <= sw and h <= sh, 'area_sample only shrinks'
    xs = np.linspace(0, sw, w + 1).round().astype(int)
    ys = np.linspace(0, sh, h + 1).round().astype(int)
    a = (arr[..., 3] >= 128).astype(np.float64)
    rgb = arr[..., :3].astype(np.float64) * a[..., None]
    # Summed-area tables make every cell O(1).
    def sat(v):
        s = np.zeros((sh + 1, sw + 1) + v.shape[2:])
        s[1:, 1:] = v.cumsum(0).cumsum(1)
        return s
    sa, sc = sat(a), sat(rgb)
    def cells(s):
        return (s[ys[1:]][:, xs[1:]] - s[ys[:-1]][:, xs[1:]]
                - s[ys[1:]][:, xs[:-1]] + s[ys[:-1]][:, xs[:-1]])
    cover, colour = cells(sa), cells(sc)
    size = np.outer(np.diff(ys), np.diff(xs))
    out = np.zeros((h, w, 4), np.uint8)
    opaque = cover >= min_cover * size
    out[..., :3] = np.where(opaque[..., None],
                            colour / np.maximum(cover, 1)[..., None], 0).round()
    out[..., 3] = opaque * 255
    return out


def quantize(arr, colors):
    """Snaps opaque pixels to [colors] adaptive colours (small sprites)."""
    palette = adaptive_palette(arr, colors)
    if palette:
        mask = arr[..., 3] == 255
        arr[mask] = snap_to_palette(arr.copy(), palette)[mask]
    return arr


def place(arr, box, canvas):
    """[arr] shrunk into [box] (l, t, r, b) of an empty [canvas] (w, h)."""
    l, t, r, b = box
    out = np.zeros((canvas[1], canvas[0], 4), np.uint8)
    out[t:b, l:r] = area_sample(arr, r - l, b - t)
    return out


def register(src, ref, steps=8, span=0.04):
    """Scale and offset that lay [src]'s silhouette best over [ref]'s.

    Starts from matching bounding boxes, then searches a little around it
    for the best alpha overlap (IoU) at [ref]'s resolution. Returns
    (scale, dx, dy): src pixel (x, y) lands on ref (x * scale + dx, ...).
    """
    rl, rt, rr, rb = bbox(ref[..., 3])
    sl, st, sr, sb = bbox(src[..., 3])
    s0 = ((rr - rl) / (sr - sl) + (rb - rt) / (sb - st)) / 2
    ra = ref[..., 3] > 0
    best = (-1, s0, 0, 0)
    for s in np.linspace(s0 * (1 - span), s0 * (1 + span), steps * 2 + 1):
        w, h = round(src.shape[1] * s), round(src.shape[0] * s)
        a = np.asarray(Image.fromarray(src[..., 3]).resize((w, h), Image.BOX)) >= 128
        cx = (rl + rr) / 2 - (sl + sr) / 2 * s
        cy = (rt + rb) / 2 - (st + sb) / 2 * s
        for dy in range(round(cy) - 4, round(cy) + 5):
            for dx in range(round(cx) - 4, round(cx) + 5):
                m = np.zeros_like(ra)
                y0, x0 = max(dy, 0), max(dx, 0)
                y1, x1 = min(dy + h, ra.shape[0]), min(dx + w, ra.shape[1])
                if y1 <= y0 or x1 <= x0:
                    continue
                m[y0:y1, x0:x1] = a[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
                iou = (m & ra).sum() / (m | ra).sum()
                if iou > best[0]:
                    best = (iou, s, dx, dy)
    return best[1], best[2], best[3], best[0]


def warp(src, scale, dx, dy, size):
    """[src] shrunk by [scale] and placed at (dx, dy) on a [size] canvas."""
    w, h = round(src.shape[1] * scale), round(src.shape[0] * scale)
    small = area_sample(src, w, h)
    out = np.zeros((size[1], size[0], 4), np.uint8)
    y0, x0 = max(dy, 0), max(dx, 0)
    y1, x1 = min(dy + h, size[1]), min(dx + w, size[0])
    out[y0:y1, x0:x1] = small[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
    return out


def save(arr, path, mode='RGBA'):
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray(arr, 'RGBA')
    (img.convert('RGB') if mode == 'RGB' else img).save(path)
    print(f'  -> {path.relative_to(ROOT)} {img.size[0]}x{img.size[1]}')


def sheet(name, images, height=216, bg=(200, 230, 200)):
    """Check sheet: [images] scaled (nearest) to [height] on a coloured
    ground, so cleared pixels inside a figure show up."""
    tiles = []
    for im in images:
        im = Image.fromarray(im) if isinstance(im, np.ndarray) else im
        im = im.convert('RGBA')
        k = max(1, height // im.height)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        tile = Image.new('RGBA', im.size, bg + (255,))
        tile.alpha_composite(im)
        tiles.append(tile)
    out = Image.new('RGB', (sum(t.width + 6 for t in tiles), max(t.height for t in tiles)), (70, 70, 70))
    x = 0
    for t in tiles:
        out.paste(t, (x, 0))
        x += t.width + 6
    PREVIEW.mkdir(parents=True, exist_ok=True)
    out.save(PREVIEW / f'{name}.png')
    print(f'  preview {PREVIEW.relative_to(ROOT) / name}.png')


# ---------------------------------------------------------------- stage 1

FISH_CANVAS = (96, 72)
# The fish's box on that canvas: the same for every pattern image and for
# the concept fish/redbean.png (999x749, box 115,108-884,640) the toppings
# are drawn over.
FISH_BOX = (11, 10, 85, 62)
PATTERNS = ['crispgrid', 'heartscale', 'starmark']
TOPPINGS = ['almond', 'choco', 'sprinkle', 'sugar']


def stage_fish(args):
    print('fish')
    done = []
    for p in PATTERNS:
        cut = load_cut(SRC / 'fish' / f'redbean@{p}.png')
        l, t, r, b = bbox(cut[..., 3])
        arr = quantize(place(cut[t:b, l:r], FISH_BOX, FISH_CANVAS), 24)
        save(arr, OUT / 'fish' / f'redbean@{p}.png')
        done.append(arr)
    if args.preview:
        sheet('fish', done + [np.asarray(Image.open(OUT / 'fish' / 'redbean.png').convert('RGBA').resize(FISH_CANVAS, Image.BOX))])


def topping_core(t, on, hsv, diff, inside):
    """Pixels that are surely topping, by colour: the fish under it is an
    orange crust (PIL hue 12-27, saturation 81+), so a plain colour diff
    would also keep every redrawn crust edge."""
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    op = on[..., 3] > 0
    core, min_size = {
        'sugar': (op & (s < 70) & (v > 190), 6),  # white dust
        'sprinkle': (op & inside & ((h < 6) | (h > 36)) & (s > 70) & (v > 110), 30),
        'choco': (op & inside & (v < 105) & (s > 120) & (diff > 90), 400),
        'almond': (op & (s < 150) & (v > 200) & (diff > 60), 150),  # pale slices
    }[t]
    core = ndimage.binary_opening(core, iterations=1)
    lab, n = ndimage.label(core)
    sizes = ndimage.sum(core, lab, range(1, n + 1))
    core = np.isin(lab, 1 + np.nonzero(sizes >= min_size)[0])
    return ndimage.binary_fill_holes(ndimage.binary_closing(core, iterations=4 if t == 'almond' else 3))


# How far the core grows (in fish/redbean.png pixels) to take in the
# topping's own outline, where it still differs from the plain fish.
TOPPING_GROW = {'almond': 10, 'choco': 4, 'sprinkle': 4, 'sugar': 4}


def stage_topping(args):
    """Each source is the whole fish with its topping. The plain concept
    fish (fish/redbean.png) is laid under it by silhouette; the topping is
    found by colour (topping_core) plus its outline where it differs from
    the plain fish, and shrunk on the fish's own canvas."""
    print('topping')
    base = np.asarray(Image.open(OUT / 'fish' / 'redbean.png').convert('RGBA')).copy()
    base[..., 3] = np.where(base[..., 3] >= 128, 255, 0)
    inside = ndimage.binary_erosion(base[..., 3] > 0, iterations=14)
    smooth = lambda a: ndimage.uniform_filter(a[..., :3].astype(float), (3, 3, 1))
    done = []
    for t in TOPPINGS:
        cut = load_cut(SRC / 'topping' / f'{t}.png')
        scale, dx, dy, iou = register(cut, base)
        print(f'  {t}: scale {scale:.4f} offset {dx},{dy} silhouette IoU {iou:.3f}')
        on = warp(cut, scale, dx, dy, (base.shape[1], base.shape[0]))
        diff = np.abs(smooth(on) - smooth(base)).sum(2)
        hsv = np.asarray(Image.fromarray(on[..., :3]).convert('HSV')).astype(int)
        core = topping_core(t, on, hsv, diff, inside)
        op = on[..., 3] > 0
        mask = (ndimage.binary_dilation(core, iterations=TOPPING_GROW[t]) & op & (diff > 35)) | (core & op)
        layer = on.copy()
        layer[..., 3] = mask * 255
        # Shrink with the same box as the fish so the overlay lines up.
        small = quantize(area_sample(layer, *FISH_CANVAS, min_cover=0.3), 12)
        save(small, OUT / 'topping' / f'{t}.png')
        done.append(small)
    if args.preview:
        fish = np.asarray(Image.open(OUT / 'fish' / 'redbean.png').convert('RGBA').resize(FISH_CANVAS, Image.BOX)).copy()
        fish[..., 3] = np.where(fish[..., 3] >= 128, 255, 0)
        over = []
        for d in done:
            f = Image.fromarray(fish)
            f.alpha_composite(Image.fromarray(d))
            over.append(f)
        sheet('topping', done + over)


STOVE_CANVAS = (941, 470)
STOVES = ['castiron', 'copper', 'golden']
# lib/ui/boost_effects.dart griddleCavities: cavity centres as fractions of
# the stove sprite (measured on the concept griddle, stove/iron.png).
CAVITIES = [(.284, .524), (.502, .525), (.719, .525),
            (.257, .715), (.501, .715), (.743, .715)]


def stage_stove(args):
    """Laid over stove/iron.png by silhouette, so the six cavities sit where
    the golden-chance layer expects them (CAVITIES, measured on the concept
    griddle). iron.png is rebuilt from castiron by stage_iron, so reruns
    keep the same place. The preview marks those points."""
    print('stove')
    W, H = STOVE_CANVAS
    iron = np.asarray(Image.open(OUT / 'stove' / 'iron.png').convert('RGBA')).copy()
    iron[..., 3] = np.where(iron[..., 3] >= 128, 255, 0)
    done = []
    for s in STOVES:
        cut = load_cut(SRC / 'stove' / f'{s}.png')
        k, dx, dy, iou = register(cut, iron, span=0.08)
        print(f'  {s}: scale {k:.4f} offset {dx},{dy} silhouette IoU {iou:.3f}')
        arr = warp(cut, k, dx, dy, STOVE_CANVAS)
        save(arr, OUT / 'stove' / f'{s}.png')
        done.append(arr)
    if args.preview:
        from PIL import ImageDraw
        marked = []
        for arr in [iron] + done:
            im = Image.fromarray(arr).copy()
            draw = ImageDraw.Draw(im)
            for fx, fy in CAVITIES:
                cx, cy = int(fx * W), int(fy * H)
                draw.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), outline=(255, 0, 255, 255), width=5)
            marked.append(im)
        sheet('stove', marked, height=470)


def metal_mask(rgba):
    """Griddle metal: everything opaque but the baked fish and the flames."""
    rgb = rgba[..., :3].astype(float) / 255
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    fish = (r > g) & (g > b) & (sat > 0.35) & (mx > 0.45)
    flame = (b > r + 0.15) & (b > g)
    return (rgba[..., 3] > 0) & ~fish & ~flame


# The concept griddle's metal (조리컷가스화면, the first stove/iron.png):
# its average colour and brightness quantiles (5 .. 95 %).
IRON_TINT = np.array([65, 50, 47], float)
IRON_LEVELS = [0.010, 0.084, 0.152, 0.302, 0.591]


def stage_iron(args):
    """The default griddle (stove/iron.png). The concept screen cut its
    hinge and handle off at both sides, and the extra art set has no iron
    griddle, so it is rebuilt from the cast iron one (stove/castiron.png,
    already laid on the cavities) with its metal recoloured to the
    concept's warm grey: same brightness spread, same tint."""
    print('iron')
    arr = np.asarray(Image.open(OUT / 'stove' / 'castiron.png').convert('RGBA')).copy()
    metal = metal_mask(arr)
    lum = arr[..., :3].astype(float).mean(2) / 255
    q = np.percentile(lum[metal], [5, 25, 50, 75, 95])
    matched = np.interp(lum, q, IRON_LEVELS)
    tint = IRON_TINT / IRON_TINT.mean()
    rgb = np.clip(matched[..., None] * tint * 255, 0, 255)
    arr[..., :3] = np.where(metal[..., None], rgb.round(), arr[..., :3]).astype(np.uint8)
    save(arr, OUT / 'stove' / 'iron.png')
    if args.preview:
        sheet('iron', [arr, np.asarray(Image.open(OUT / 'stove' / 'castiron.png').convert('RGBA'))], height=470)


# ---------------------------------------------------------------- stage 2

BG_CANVAS = (335, 762)
# Day pictures replaced or new, and the night pictures of four seasons
# (PixelSprites.sceneBackground loads bg/<id>_night.png).
BACKGROUNDS = ['clear', 'rain', 'autumn', 'cherry', 'snow', 'snowday',
               'dusk', 'forest', 'night', 'seaside',
               'clear_night', 'rain_night', 'autumn_night', 'cherry_night']


def baked_fish(img):
    """Box (l, t, r, b) of the big golden bungeoppang baked into a scene:
    the largest crust-coloured blob in the band where the mold sits."""
    hsv = np.asarray(img.convert('HSV')).astype(int)
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    m = (h >= 10) & (h <= 32) & (s > 110) & (v > 170)
    rows = m.shape[0]
    m[:int(rows * .42)] = False
    m[int(rows * .75):] = False
    m = ndimage.binary_closing(ndimage.binary_opening(m, iterations=2), iterations=6)
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    return bbox(lab == np.argmax(sizes) + 1)


def shift(img, dx, dy):
    """[img] moved by (dx, dy); the uncovered edge repeats its last row or
    column (the counter front at the bottom, the stall posts at the sides)."""
    a = np.asarray(img)
    ys = np.clip(np.arange(a.shape[0]) - dy, 0, a.shape[0] - 1)
    xs = np.clip(np.arange(a.shape[1]) - dx, 0, a.shape[1] - 1)
    return Image.fromarray(a[ys][:, xs])


def stage_bg(args):
    """Full-screen scenes, opaque like the concept backgrounds they replace.

    Each source has the concept's frame baked in (awning, lamps, the big
    bungeoppang in its mold, the counter), shrunk to 335x762. The game lays
    its own bungeoppang over the baked one at one fixed box
    (NightStallPainter.conceptFish), so every scene is moved to put its
    baked bungeoppang where clear.png has it: autumn, cherry and snow draw
    it about 12 px lower and would show two fish. The preview outlines
    conceptFish."""
    print('bg')
    from PIL import ImageDraw
    done = []
    target = None
    for name in BACKGROUNDS:
        out = Image.open(SRC / 'bg' / f'{name}.png').convert('RGB').resize(BG_CANVAS, Image.BOX)
        l, t, r, b = baked_fish(out)
        if target is None:  # clear: the reference
            target = ((l + r) / 2, t)
        dx, dy = round(target[0] - (l + r) / 2), round(target[1] - t)
        if dx or dy:
            out = shift(out, dx, dy)
        path = OUT / 'bg' / f'{name}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
        print(f'  -> {path.relative_to(ROOT)} {out.size[0]}x{out.size[1]} (fish moved {dx},{dy})')
        marked = out.convert('RGBA')
        ImageDraw.Draw(marked).rectangle((62, 382, 287, 525), outline=(255, 0, 255, 255), width=2)
        done.append(marked)
    if args.preview:
        sheet('bg_day', done[:10], height=381)
        sheet('bg_night', done[10:], height=381)

# ---------------------------------------------------------------- stage 3

# Width of each decoration in NightStallPainter's 180x400 scene units; the
# art is stored at DECO_SCALE times that and drawn back at scene size, so it
# keeps the source's finer dots (like the icons and skills).
DECO_SCALE = 3
DECO_WIDTH = {'lantern': 22, 'windchime': 14, 'bunting': 180,
              'starlights': 180, 'paperlanterns': 180, 'snowman': 30}


def stage_deco(args):
    """Stall decorations: cut from the white sheet (border flood fill only,
    so the snowman stays white), cropped to the content and shrunk to
    DECO_WIDTH x DECO_SCALE pixels wide."""
    print('deco')
    done = []
    for name, width in DECO_WIDTH.items():
        cut = load_cut(SRC / 'deco' / f'{name}.png', tolerance=20)
        l, t, r, b = bbox(cut[..., 3])
        cut = cut[t:b, l:r]
        w = width * DECO_SCALE
        h = round(cut.shape[0] * w / cut.shape[1])
        arr = quantize(area_sample(cut, w, h), 64)
        save(arr, OUT / 'deco' / f'{name}.png')
        done.append(arr)
    if args.preview:
        sheet('deco', done, height=270)


ICON_SIZE = 72  # 3x the 24 px logical icon, like tools/process_extra_art.sh
ICONS = ['shop', 'skins', 'records', 'share', 'daily', 'achievements',
         'settings', 'leaderboard', 'star', 'butter',
         'back', 'bgm', 'sfx', 'vibration', 'volume', 'save', 'menu']


def stage_icons(args):
    """Square icons on the same 72x72 canvas as the existing ones: content
    centred with a 2 px margin, 16 adaptive colours."""
    print('icons')
    done = []
    for name in ICONS:
        cut = load_cut(SRC / 'icons' / f'{name}.png')
        l, t, r, b = bbox(cut[..., 3])
        cut = cut[t:b, l:r]
        inner = ICON_SIZE - 4
        k = inner / max(cut.shape[:2])
        w, h = max(1, round(cut.shape[1] * k)), max(1, round(cut.shape[0] * k))
        arr = np.zeros((ICON_SIZE, ICON_SIZE, 4), np.uint8)
        x, y = (ICON_SIZE - w) // 2, (ICON_SIZE - h) // 2
        arr[y:y + h, x:x + w] = area_sample(cut, w, h)
        arr = quantize(arr, 16)
        save(arr, OUT / 'icons' / f'{name}.png')
        done.append(arr)
    if args.preview:
        sheet('icons', done, height=144)


STAGES = {'fish': stage_fish, 'topping': stage_topping, 'stove': stage_stove,
          'iron': stage_iron,
          'bg': stage_bg, 'deco': stage_deco, 'icons': stage_icons}


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('stages', nargs='+', choices=list(STAGES) + ['all'])
    p.add_argument('--preview', action='store_true', help='write check sheets to build/extra_art_preview')
    args = p.parse_args()
    for name in (STAGES if 'all' in args.stages else args.stages):
        STAGES[name](args)


if __name__ == '__main__':
    main()
