"""Turns the vendor's art into small, separately placed layers.

Three jobs, all safe to run again:

  trim   Cuts the empty margin off every assets/images/avatar/<character>/
         *.png that is still a full 280x520 canvas, and remembers where
         the cut-out sat on the canvas. The game draws each file back at
         that spot, so nothing moves.

  face   Makes the eye and mouth frames that the game lays over the faces
         already drawn into the art (avatar/<character>/base.png from the
         front, cook/girl_1..6.png from the side):
           parts/<character>_<view>_eyes_half.png    eyes half shut
           parts/<character>_<view>_eyes_closed.png  eyes shut
           parts/<character>_<view>_mouth_small.png  mouth a little open
           parts/<character>_<view>_mouth_wide.png   mouth wide open
         Each part covers the drawn eyes or mouth with skin from around
         it (so the face below needs no change) and draws the new shape.
         The open eyes and closed smile are the art itself: no file.
         For the side frames the head moves between frames, so each
         frame's eyes and mouth are found by matching frame 2's face.

  worn   Makes item layers from pictures of the vendor WEARING the item
         (이미지/추가 생성 이미지/avatar/<character>/<slot>_<id>.png), so
         an item on the rig looks as it does when worn: a hat comes with
         the hair it presses down. Each picture is laid over the base
         figure (matched on the body below the head, which items there do
         not change) and only what changed inside the item's rows is kept:
           avatar/<character>/<slot>_<id>.png      the worn item (+ hair)
           avatar/<character>/<slot>_<id>_cut.png  base pixels the worn
                                                   picture no longer shows
                                                   (erased under the item)
         The face (eyes, mouth) is never taken, so the face layers keep
         working. Items drawn only flat (no worn picture) keep their art.

All write tools/avatar_layers.json (every number below) and the
generated lib/avatar_atlas.dart that the game reads.

Run from the project root:   python tools/avatar_layers.py [face] [worn] [trim]
(no argument runs all three in that order). Add --preview to save checking sheets to
build/avatar_layers/.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / 'assets' / 'images'
DATA = ROOT / 'tools' / 'avatar_layers.json'
DART = ROOT / 'lib' / 'avatar_atlas.dart'
PREVIEW = ROOT / 'build' / 'avatar_layers'

CANVAS = (280, 520)  # every front layer's canvas (tools/concept_avatar.py)
PAD = 1  # transparent pixels kept around a trimmed image (smooth edges)

# Faces drawn into the art, in that image's pixels. Boxes are (l, t, r, b)
# and must hold only the eye or mouth and skin around it; centres are where
# the part is anchored. Measured on gridded zooms of each image.
FACES = {
    'girl_front': dict(
        image='avatar/girl/base.png',
        eyes=[((100, 137, 137, 174), (118, 157)),
              ((168, 130, 212, 173), (189, 153))],
        mouth=((137, 177, 168, 191), (152, 184)),
        skin=(138, 150, 165, 172)),
    'boy_front': dict(
        image='avatar/boy/base.png',
        eyes=[((91, 135, 136, 174), (115, 157)),
              ((168, 133, 210, 174), (188, 155))],
        mouth=((135, 177, 166, 191), (150, 184)),
        skin=(138, 150, 165, 172)),
    # The side (cooking) frames: measured on frame 2, found in the others.
    'girl_side': dict(
        image='cook/girl_2.png',
        frames=[f'cook/girl_{i}.png' for i in range(1, 7)],
        match=(245, 135, 345, 200),
        eyes=[((246, 137, 279, 178), (263, 158)),
              ((303, 135, 345, 177), (324, 156))],
        mouth=((286, 184, 300, 193), (293, 188)),
        skin=(282, 160, 302, 182)),
}


def rgba(path, trimmed=None):
    """[path] as an RGBA array; a trimmed vendor image is put back on its
    full canvas, so measurements stay in canvas pixels."""
    img = Image.open(IMAGES / path).convert('RGBA')
    if trimmed and path in trimmed and img.size != CANVAS:
        full = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
        full.paste(img, tuple(trimmed[path]))
        img = full
    return np.array(img).astype(np.int32)


def save(arr, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr.astype(np.uint8), 'RGBA').save(path, optimize=True)


def load_data():
    return json.loads(DATA.read_text('utf-8')) if DATA.exists() else {}


# ---------------------------------------------------------------- trim


def trim(data):
    offsets = data.get('trim', {})
    before = after = 0
    for path in sorted((IMAGES / 'avatar').glob('*/*.png')):
        key = path.relative_to(IMAGES).as_posix()
        img = Image.open(path)
        if img.size != CANVAS:
            if key not in offsets:
                sys.exit(f'{key}: not {CANVAS} and no offset recorded')
            continue
        arr = np.array(img.convert('RGBA'))
        ys, xs = np.nonzero(arr[..., 3])
        if len(xs) == 0:
            continue
        l, t = max(xs.min() - PAD, 0), max(ys.min() - PAD, 0)
        r = min(xs.max() + 1 + PAD, CANVAS[0])
        b = min(ys.max() + 1 + PAD, CANVAS[1])
        before += path.stat().st_size
        save(arr[t:b, l:r], path)
        after += path.stat().st_size
        offsets[key] = [int(l), int(t)]
        print(f'trim {key}: {CANVAS} -> {r - l}x{b - t} at ({l}, {t})')
    data['trim'] = offsets
    if before:
        print(f'trimmed {before} -> {after} bytes')


# ---------------------------------------------------------------- face


def skinlike(a):
    """Skin or blush: warm and light (the faces' skin is red 250+); not the
    eye whites (green close to red), not the blended edge pixels around the
    eyes (darker), not the orange lid line (blue far below red)."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (a[..., 3] > 0) & (r >= 232) & (g > 130) & (g < r - 22) & \
        (b <= g + 8) & (r - b > 25) & (r - b < 115)


def feature_mask(a, box, round_=False):
    """Pixels in [box] that are not skin; [round_] keeps only the oval the
    box holds, so an eye's cover has no square corners biting into hair."""
    l, t, r, b = box
    mask = np.zeros(a.shape[:2], bool)
    mask[t:b, l:r] = ~skinlike(a[t:b, l:r]) & (a[t:b, l:r, 3] > 0)
    if round_:
        yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        rx, ry = (r - l) / 2 * 1.1, (b - t) / 2 * 1.1
        mask &= ((xx + .5 - (l + r) / 2) / rx) ** 2 + \
            ((yy + .5 - (t + b) / 2) / ry) ** 2 <= 1
    return mask


def dilate(mask, box):
    l, t, r, b = box
    out = mask.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        out |= np.roll(mask, (dy, dx), (0, 1))
    clip = np.zeros_like(mask)
    clip[t:b, l:r] = True
    return out & clip


def inpaint(a, mask, fallback, reach=14):
    """Fills [mask] with the skin around it: each pixel averages the nearest
    skin to its left, right, top and bottom, nearer ones counting more."""
    out = a.copy()
    skin = skinlike(a) & ~mask
    h, w = mask.shape
    for y, x in zip(*np.nonzero(mask)):
        total, weight = np.zeros(3), 0.0
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            for step in range(1, reach + 1):
                yy, xx = y + dy * step, x + dx * step
                if not (0 <= yy < h and 0 <= xx < w):
                    break
                if skin[yy, xx]:
                    total += a[yy, xx, :3] / step
                    weight += 1 / step
                    break
        out[y, x, :3] = total / weight if weight else fallback
        out[y, x, 3] = 255
    # Soften the cross-shaped streaks of the four-way fill.
    ys, xs = np.nonzero(mask)
    for _ in range(3):
        soft = out.copy()
        for y, x in zip(ys, xs):
            area = out[max(y - 1, 0):y + 2, max(x - 1, 0):x + 2]
            near = area[skinlike(area) | mask[max(y - 1, 0):y + 2,
                                              max(x - 1, 0):x + 2]]
            soft[y, x, :3] = near[:, :3].mean(0)
        out = soft
    return out


def median_skin(a, box):
    l, t, r, b = box
    area = a[t:b, l:r]
    return np.median(area[skinlike(area)][:, :3], axis=0)


def draw_curve(arr, keep, x0, x1, y, sag, width, colour):
    """A lash line from x0 to x1 sagging [sag] pixels in the middle."""
    img = Image.new('L', (arr.shape[1], arr.shape[0]), 0)
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(17):
        s = i / 16
        pts.append((x0 + (x1 - x0) * s, y + sag * 4 * s * (1 - s)))
    d.line(pts, fill=255, width=width)
    line = np.array(img) > 0
    arr[line, :3] = colour
    arr[line, 3] = 255
    keep |= line


def eye_frames(a, eyes, skin):
    """(half, closed): the image with each eye shut halfway or fully, and
    the pixels that changed."""
    frames = []
    for amount in ('half', 'closed'):
        out, keep = a.copy(), np.zeros(a.shape[:2], bool)
        for box, (cx, cy) in eyes:
            mask = feature_mask(a, box, True)
            ys, xs = np.nonzero(mask)
            h = ys.max() - ys.min() + 1
            dark = a[mask][:, :3]
            lash = dark[np.argsort(dark.sum(1))[:max(len(dark) // 10, 1)]]
            lash = np.median(lash, axis=0)
            width = max(2, round(h / 13))
            if amount == 'half':
                mask &= np.arange(a.shape[0])[:, None] < cy
                y, sag = cy - width // 2, round(h * .06)
            else:
                y, sag = cy + round(h * .12), round(h * .16)
            out = inpaint(out, mask, skin)
            keep |= mask
            row = np.nonzero(feature_mask(a, box, True)[min(y, ys.max())])[0]
            x0 = (row.min() if len(row) else xs.min()) + 1
            x1 = (row.max() if len(row) else xs.max()) - 1
            draw_curve(out, keep, x0, x1, y, sag, width, lash)
        frames.append((out, keep))
    return frames


def mouth_frames(a, mouth, skin):
    """(small, wide): the closed smile covered with skin and an open mouth
    drawn at its centre."""
    box, (cx, cy) = mouth
    smile = feature_mask(a, box)
    ys, xs = np.nonzero(smile)
    lip = np.median(a[smile][:, :3], axis=0)
    span = xs.max() - xs.min() + 1
    mask = dilate(smile, box)
    covered = inpaint(a, mask, skin)
    frames = []
    for w, h in ((max(5, round(span * .42)), max(3, round(span * .3))),
                 (max(7, round(span * .52)), max(6, round(span * .46)))):
        out, keep = covered.copy(), mask.copy()
        yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
        top = cy - h // 2
        nx = (xx + .5 - cx) / (w / 2)
        ny = (yy + .5 - (top + h / 2)) / (h / 2)
        inside = nx * nx + ny * ny <= 1
        edge = inside & ~(np.roll(inside, 1, 0) & np.roll(inside, -1, 0) &
                          np.roll(inside, 1, 1) & np.roll(inside, -1, 1))
        tongue = inside & ~edge & (yy >= top + h * .62)
        out[inside, :3] = (110, 38, 42)
        out[tongue, :3] = (232, 128, 124)
        out[edge, :3] = lip * .85
        out[inside, 3] = 255
        keep |= inside
        frames.append((out, keep))
    return frames


def cut(out, keep):
    """The kept pixels on a transparent image, cropped; and its top-left."""
    ys, xs = np.nonzero(keep)
    t, b, l, r = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    part = out[t:b, l:r].copy()
    part[..., 3] = np.where(keep[t:b, l:r], 255, 0)
    return part, (int(l), int(t))


def match(ref, frame, box, reach=70):
    """Offset that best lays [ref]'s [box] over [frame] (least difference)."""
    l, t, r, b = box
    tpl = ref[t:b, l:r, :3].astype(np.float32)
    best = None
    for step, around in ((3, None), (1, 3)):
        span = range(-reach, reach + 1, step)
        cands = [(dx, dy) for dy in span for dx in span] if around is None \
            else [(best[1] + dx, best[2] + dy)
                  for dy in range(-around, around + 1)
                  for dx in range(-around, around + 1)]
        for dx, dy in cands:
            if l + dx < 0 or t + dy < 0 or r + dx > frame.shape[1] or \
                    b + dy > frame.shape[0]:
                continue
            win = frame[t + dy:b + dy, l + dx:r + dx, :3].astype(np.float32)
            score = float(np.mean((win - tpl) ** 2))
            if best is None or score < best[0]:
                best = (score, dx, dy)
    return best


def face(data, preview):
    pivots, anchors = {}, {}
    trimmed = data.get('trim', {})
    for name, f in FACES.items():
        a = rgba(f['image'], trimmed)
        skin = median_skin(a, f['skin'])
        eyes_c = [c for _, c in f['eyes']]
        eye_mid = (sum(x for x, _ in eyes_c) / 2, sum(y for _, y in eyes_c) / 2)
        made = {}
        for frame, (out, keep) in zip(('half', 'closed'),
                                      eye_frames(a, f['eyes'], skin)):
            made[f'eyes_{frame}'] = (cut(out, keep), eye_mid)
        for frame, (out, keep) in zip(('small', 'wide'),
                                      mouth_frames(a, f['mouth'], skin)):
            made[f'mouth_{frame}'] = (cut(out, keep), f['mouth'][1])
        for part, ((arr, (l, t)), (ax, ay)) in made.items():
            key = f'parts/{name}_{part}.png'
            save(arr, IMAGES / key)
            pivots[key] = [ax - l, ay - t]
            print(f'face {key}: {arr.shape[1]}x{arr.shape[0]}, '
                  f'pivot ({ax - l}, {ay - t})')
        pose_anchor = {'eyes': list(eye_mid), 'mouth': list(f['mouth'][1])}
        if 'frames' not in f:
            anchors[f['image']] = pose_anchor
            continue
        for path in f['frames']:
            score, dx, dy = (0.0, 0, 0) if path == f['image'] else \
                match(a, rgba(path), f['match'])
            anchors[path] = {k: [x + dx, y + dy]
                             for k, (x, y) in pose_anchor.items()}
            print(f'face {path}: head at ({dx:+d}, {dy:+d}), '
                  f'difference {score:.0f}')
    # Keep entries this tool did not make (hand-drawn parts, poses measured
    # by hand); redo the ones it did.
    data['pivots'] = {**data.get('pivots', {}), **pivots}
    data['anchors'] = {**data.get('anchors', {}), **anchors}
    if preview:
        preview_sheet(data)


def preview_sheet(data):
    """Every face pose with each part laid on, 3x, for checking by eye."""
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for pose, anchor in data['anchors'].items():
        base = Image.fromarray(
            rgba(pose, data.get('trim')).astype(np.uint8), 'RGBA')
        view = 'front' if pose.startswith('avatar/') else 'side'
        who = pose.split('/')[1] if view == 'front' else \
            pose.split('/')[1].split('_')[0]
        ax, ay = anchor['mouth']
        ex, ey = anchor['eyes']
        box = (int(ex - 60), int(ey - 45), int(ex + 60), int(ay + 25))
        tiles = []
        for part in (None, 'eyes_half', 'eyes_closed', 'mouth_small',
                     'mouth_wide'):
            img = base.copy()
            if part:
                key = f'parts/{who}_{view}_{part}.png'
                sprite = Image.open(IMAGES / key).convert('RGBA')
                px, py = data['pivots'][key]
                x, y = anchor['eyes' if part.startswith('eyes') else 'mouth']
                img.alpha_composite(sprite, (round(x - px), round(y - py)))
            tile = Image.new('RGBA', (box[2] - box[0], box[3] - box[1]),
                             (110, 170, 110, 255))
            tile.alpha_composite(img.crop(box))
            tiles.append(tile.resize((tile.width * 3, tile.height * 3),
                                     Image.NEAREST))
        sheet = Image.new('RGBA', (sum(t.width for t in tiles), tiles[0].height))
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.width
        sheet.save(PREVIEW / (pose.replace('/', '_')))


# ---------------------------------------------------------------- worn

WORN_SRC = ROOT / '이미지' / '추가 생성 이미지' / 'avatar'

# Worn picture (file stem) -> (slot, id) in the game. The extra art names
# the trousers and the boy's skirt 'outfit_*', but they are bottoms.
# outfit_apron is left out: the default vendor still wears 'apron' with no
# art, and drawing it would put an apron on every default vendor (it needs
# a new blank default outfit and a save migration first).
WORN_ITEMS = {
    'hat_santa': ('hat', 'santa'),
    'hat_chefhat': ('hat', 'chefhat'),
    'hat_earmuffs': ('hat', 'earmuffs'),
    'hat_blackcap': ('hat', 'blackcap'),
    'hat_redbandana': ('hat', 'redbandana'),
    'outfit_stripe': ('outfit', 'stripe'),
    'outfit_chefcoat': ('outfit', 'chefcoat'),
    'outfit_darkapron': ('outfit', 'darkapron'),
    'outfit_creamapron': ('outfit', 'creamapron'),
    'outfit_waistapron': ('outfit', 'waistapron'),
    'outfit_widepants': ('bottom', 'widepants'),
    'outfit_brownpants': ('bottom', 'brownpants'),
    'outfit_skirt': ('bottom', 'skirt'),
    'accessory_ribbon': ('accessory', 'ribbon'),
    'tool_goldtongs': ('tool', 'goldtongs'),
}

# Canvas rows (top, bottom) where each slot may change the figure. Hats
# reach down the sides of the head (earmuffs), aprons to the knees.
WORN_ROWS = {
    'hat': (0, 215),
    'accessory': (0, 215),
    'outfit': (190, 470),
    'bottom': (275, 520),
    'tool': (290, 440),
}
BODY_FROM = 230  # canvas rows matched when laying a worn picture over
CHANGED = 48  # colour distance (RGB) that counts as a different pixel


def lay_over(src, ref):
    """(scale, dx, dy, overlap) laying [src] over [ref] by their bodies
    below the head, the part no item changes (overlap is the IoU there)."""
    import apply_extra_art as X
    ra = ref[..., 3] > 0
    rl, rt, rr, rb = X.bbox(ref[..., 3])
    sl, st, sr, sb = X.bbox(src[..., 3])
    s0 = (rb - rt) / (sb - st)
    best = None
    for s in np.linspace(s0 * .94, s0 * 1.06, 25):
        w, h = round(src.shape[1] * s), round(src.shape[0] * s)
        a = np.asarray(Image.fromarray(src[..., 3]).resize((w, h), Image.BOX)) >= 128
        cx = (rl + rr) / 2 - (sl + sr) / 2 * s
        cy = rb - sb * s
        for dy in range(round(cy) - 6, round(cy) + 7):
            for dx in range(round(cx) - 6, round(cx) + 7):
                m = np.zeros_like(ra)
                y0, x0 = max(dy, 0), max(dx, 0)
                y1, x1 = min(dy + h, ra.shape[0]), min(dx + w, ra.shape[1])
                m[y0:y1, x0:x1] = a[y0 - dy:y1 - dy, x0 - dx:x1 - dx]
                mm, rm = m[BODY_FROM:], ra[BODY_FROM:]
                iou = (mm & rm).sum() / (mm | rm).sum()
                if best is None or iou > best[0]:
                    best = (iou, s, dx, dy)
    return best[1], best[2], best[3], best[0]


def changed_from(on, base):
    """Pixels of [on] that the base does not have within one pixel around
    (AI redraws drift by a pixel everywhere)."""
    wc = on[..., :3].astype(np.int32)
    best = np.full(base.shape[:2], 1e9)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            b = np.roll(base, (dy, dx), (0, 1)).astype(np.int32)
            d = np.sqrt(((wc - b[..., :3]) ** 2).sum(-1))
            best = np.minimum(best, np.where(b[..., 3] > 0, d, 1e9))
    return (on[..., 3] > 0) & (best > CHANGED)


def clean(mask, smallest):
    """[mask] without specks smaller than [smallest], gaps closed."""
    from scipy import ndimage
    labels, n = ndimage.label(mask)
    if n == 0:
        return mask
    sizes = ndimage.sum(mask, labels, range(1, n + 1))
    keep = np.isin(labels, 1 + np.nonzero(sizes >= smallest)[0])
    return ndimage.binary_fill_holes(ndimage.binary_closing(keep)) & \
        ndimage.binary_dilation(keep)


def face_box(character, pad=3):
    f = FACES[f'{character}_front']
    boxes = [b for b, _ in f['eyes']] + [f['mouth'][0]]
    return (min(b[0] for b in boxes) - pad, min(b[1] for b in boxes) - pad,
            max(b[2] for b in boxes) + pad, max(b[3] for b in boxes) + pad)


def worn(data, preview):
    import apply_extra_art as X
    from scipy import ndimage
    trimmed = data.get('trim', {})
    made = data.setdefault('worn', {})
    sheets = []
    for character in ('girl', 'boy'):
        base = rgba(f'avatar/{character}/base.png', trimmed).astype(np.uint8)
        l, t, r, b = face_box(character)
        for stem, (slot, item) in WORN_ITEMS.items():
            path = WORN_SRC / character / f'{stem}.png'
            if not path.exists():
                continue
            scale, dx, dy, fit = lay_over(X.load_cut(path), base)
            on = X.warp(X.load_cut(path), scale, dx, dy, CANVAS)
            top, bottom = WORN_ROWS[slot]
            region = np.zeros(on.shape[:2], bool)
            region[top:bottom] = True
            region[t:b, l:r] = False  # the face stays the base's
            item_mask = clean(changed_from(on, base) & region, 12)
            # Take the item's outline too: opaque neighbours of the mask.
            item_mask = ndimage.binary_dilation(item_mask) & \
                (on[..., 3] > 0) & region
            # Base pixels the worn picture leaves bare, next to the item.
            near = ndimage.binary_dilation(item_mask, iterations=6)
            cut = clean((base[..., 3] > 0) & (on[..., 3] == 0) & region & near,
                        6) & (base[..., 3] > 0)
            layer = np.zeros_like(on)
            layer[item_mask] = on[item_mask]
            key = f'avatar/{character}/{slot}_{item}.png'
            save(layer, IMAGES / key)
            trimmed.pop(key, None)
            cut_key = key.replace('.png', '_cut.png')
            if cut.any():
                cut_img = np.zeros_like(on)
                cut_img[cut] = (0, 0, 0, 255)
                save(cut_img, IMAGES / cut_key)
            elif (IMAGES / cut_key).exists():
                (IMAGES / cut_key).unlink()
            trimmed.pop(cut_key, None)
            made[key] = dict(source=f'{character}/{stem}.png',
                             overlap=round(float(fit), 3),
                             scale=round(float(scale), 4),
                             at=[int(dx), int(dy)],
                             pixels=int(item_mask.sum()), cut=int(cut.sum()))
            print(f'worn {key}: overlap {fit:.3f}, {item_mask.sum()} px, '
                  f'cut {cut.sum()} px')
            if preview:
                shown = base.copy()
                shown[cut] = 0
                img = Image.fromarray(shown)
                img.alpha_composite(Image.fromarray(layer))
                sheets.append((Image.fromarray(on), img))
    if preview and sheets:
        PREVIEW.mkdir(parents=True, exist_ok=True)
        for i in range(0, len(sheets), 6):
            part = sheets[i:i + 6]
            out = Image.new('RGBA', (560 * len(part), 300), (110, 170, 110, 255))
            for k, (ref, img) in enumerate(part):
                out.alpha_composite(ref.crop((0, 0, 280, 300)), (560 * k, 0))
                out.alpha_composite(img.crop((0, 0, 280, 300)), (560 * k + 280, 0))
            out.save(PREVIEW / f'worn_{i // 6}.png')


# ---------------------------------------------------------------- output


def write_dart(data):
    def num(v):
        return f'{v:g}' if isinstance(v, float) and v != int(v) else f'{int(v)}'

    lines = [
        '// GENERATED by tools/avatar_layers.py from tools/avatar_layers.json.',
        '// Do not edit by hand: change the tool or the json and run it again.',
        '',
        '/// Where each trimmed vendor image sits on its 280x520 canvas',
        '/// (left, top), in canvas pixels. Images still the full canvas are',
        '/// not listed and sit at (0, 0).',
        'const avatarTrimOffsets = <String, (int, int)>{',
    ]
    for k, (x, y) in sorted(data.get('trim', {}).items()):
        lines.append(f"  '{k}': ({x}, {y}),")
    lines += [
        '};',
        '',
        '/// The point of each face part (eyes, mouth) that lands on its',
        "/// pose's anchor, in the part image's pixels.",
        'const avatarPartPivots = <String, (double, double)>{',
    ]
    for k, (x, y) in sorted(data.get('pivots', {}).items()):
        lines.append(f"  '{k}': ({num(float(x))}, {num(float(y))}),")
    lines += [
        '};',
        '',
        '/// Where the eyes and mouth are drawn in each face image (a front',
        '/// base figure or a side cooking frame), in that image\'s pixels.',
        'const avatarFaceAnchors = <String, Map<String, (double, double)>>{',
    ]
    for k, parts in sorted(data.get('anchors', {}).items()):
        inner = ', '.join(f"'{p}': ({num(float(x))}, {num(float(y))})"
                          for p, (x, y) in sorted(parts.items()))
        lines.append(f"  '{k}': {{{inner}}},")
    lines.append('};')
    DART.write_text('\n'.join(lines) + '\n', 'utf-8', newline='\n')


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    jobs = args or ['face', 'worn', 'trim']
    data = load_data()
    if 'face' in jobs:
        face(data, '--preview' in sys.argv)
    # Worn items are made on the full canvas, then trimmed below.
    if 'worn' in jobs:
        worn(data, '--preview' in sys.argv)
    if 'trim' in jobs:
        trim(data)
    DATA.write_text(json.dumps(data, indent=1, ensure_ascii=False) + '\n',
                    'utf-8')
    write_dart(data)


if __name__ == '__main__':
    main()
