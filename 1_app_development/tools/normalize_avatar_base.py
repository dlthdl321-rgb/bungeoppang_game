"""Normalizes the 25번 23번 bare vendor bases to the 4x rig (26번 4-7단계).

The six generated bases (23_avatar_base/<girl|boy>/base_skin1..3.png, about
880x1787) are not on the 1120x2080 canvas of 25번 23~31번 공통 and their
eyes, mouth and soles are not on its points. This tool (it never writes
into the source folders) puts each base on that canvas with ONE uniform
scale + shift per character:

* the soles' last opaque row (alpha > 127) on row 2079 (soles line
  2076~2079, the game's row 519) and the eyes' centre on the 4x anchor
  (girl 614, 620 / boy 606, 624) - these two fix scale and shift;
* the mouth (girl 608, 736 / boy 600, 736) follows. A single transform
  cannot also put it on its point (the drawn face is proportioned
  differently), so its error is measured and written down.

skin1 sets the transform of its character. skin2/skin3 do not use their own
pictures' shapes (they are shifted 1-2px and the boy's skin3 scalp line
differs): their skin colour is painted onto skin1's shape instead, so the
three pictures differ only in skin pixels. The skin of skin1 is the warm,
light region (avatar_layers.skinish) that grows from pixels that really
change between skin1 and skin3; each tone's colour is a per-channel linear
fit skin1 -> skinN over the skin pixels both pictures share.

Landmarks (source pixels, centres of the pixel = index + 0.5):
  eyes   mean of the bounding-box centres of the two largest dark blobs
         (R<110, G<85, B<75, alpha>200) in the eye box below
  mouth  bounding-box centre of the largest red-brown blob in the mouth box
  soles  bottom edge of the last row with alpha > 127

  python tools/normalize_avatar_base.py            # all, + compare sheet
  python tools/normalize_avatar_base.py --src <23_avatar_base folder>

Writes 23_avatar_base/normalized/<girl|boy>/base_skin<1-3>.png (1120x2080,
alpha 0/255), normalized/report.json (transforms, errors, colour fits) and
normalized/compare.png (originals left, normalized right, target lines).
Run in 1_app_development.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as nd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import avatar_layers as L  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT.parent / '4_image_generation_results_and_backups' / \
    '26_feedback_generated' / '23_avatar_base'
CANVAS = (1120, 2080)
SOLE_EDGE = 2080  # bottom edge of row 2079
SKINS = ('skin1', 'skin2', 'skin3')
# 4x anchors (25번 23~31번 공통 = tools/avatar_v2.json anchors x 4), pixel
# centres.
TARGET = {
    'girl': {'eyes': (614.0, 620.0), 'mouth': (608.0, 736.0)},
    'boy': {'eyes': (606.0, 624.0), 'mouth': (600.0, 736.0)},
}
# Search boxes in skin1 source pixels (l, t, r, b), from review/*_landmarks.
EYE_BOX = {'girl': (220, 420, 640, 570), 'boy': (230, 475, 651, 616)}
MOUTH_BOX = {'girl': (370, 575, 495, 625), 'boy': (375, 625, 506, 676)}


def load(path):
    return np.array(Image.open(path).convert('RGBA'))


def blobs(mask, box, count):
    l, t, r, b = box
    lab, n = nd.label(mask[t:b, l:r])
    if n == 0:
        return []
    sizes = nd.sum(np.ones_like(lab), lab, range(1, n + 1))
    out = []
    for i in np.argsort(sizes)[::-1][:count]:
        ys, xs = np.nonzero(lab == i + 1)
        out.append(((xs.min() + xs.max()) / 2 + l + .5,
                    (ys.min() + ys.max()) / 2 + t + .5))
    return out


def landmarks(a, c, eye_box=None, mouth_box=None):
    """{'eyes': (x, y), 'mouth': (x, y), 'sole': bottom edge} in pixel
    coordinates (centre of pixel i is i + .5)."""
    r, g, b, al = (a[..., i].astype(int) for i in range(4))
    dark = (r < 110) & (g < 85) & (b < 75) & (al > 200)
    eyes = blobs(dark, eye_box or EYE_BOX[c], 2)
    red = (r > 110) & (r < 220) & (g < 120) & (b < 110) & (r > 1.35 * g) & (al > 200)
    mouth = blobs(red, mouth_box or MOUTH_BOX[c], 1)
    rows = np.nonzero((al > 127).any(1))[0]
    return {'eyes': tuple(np.mean(eyes, 0)) if len(eyes) == 2 else None,
            'mouth': mouth[0] if mouth else None,
            'sole': float(rows.max() + 1)}


def transform(lm, c):
    """(scale, dx, dy): x' = scale * x + dx. Eyes and soles fixed."""
    ex, ey = lm['eyes']
    tx, ty = TARGET[c]['eyes']
    s = (SOLE_EDGE - ty) / (lm['sole'] - ey)
    return s, tx - s * ex, ty - s * ey


def place(a, s, dx, dy):
    """[a] scaled by [s] and shifted onto the canvas: premultiplied Lanczos,
    then alpha snapped to 0/255 (no halo), like tools/avatar_v2.py."""
    pad = 512  # resize boxes cannot start left of / above the picture
    big = Image.new('RGBA', (a.shape[1] + 2 * pad, a.shape[0] + 2 * pad))
    big.paste(Image.fromarray(a, 'RGBA'), (pad, pad))
    img = big.convert('RGBa')
    w, h = CANVAS
    box = (pad - dx / s, pad - dy / s, pad + (w - dx) / s, pad + (h - dy) / s)
    out = np.array(img.resize(CANVAS, Image.LANCZOS, box=box).convert('RGBA'))
    keep = out[..., 3] >= 128
    out[..., 3] = np.where(keep, 255, 0)
    out[~keep, :3] = 0
    return out


def best_shift(one, other):
    """The integer shift (dx, dy <= 4) that best lays [other]'s opaque
    pixels on [one]'s."""
    h = min(one.shape[0], other.shape[0])
    ref = one[:h, :, 3] > 127
    best = None
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            moved = np.roll(np.roll(other[:h, :, 3] > 127, dy, 0), dx, 1)
            d = int((moved != ref).sum())
            if best is None or d < best[0]:
                best = (d, dx, dy)
    return best[1], best[2]


def on_one(one, other):
    """[other] moved by best_shift onto an array shaped like [one]."""
    dx, dy = best_shift(one, other)
    out = np.zeros_like(one)
    h = min(one.shape[0], other.shape[0])
    out[:h] = np.roll(np.roll(other[:h], dy, 0), dx, 1)
    return out, (dx, dy)


def skin_mask(one, three):
    """skin1's skin: warm light pixels connected to pixels that change
    colour between skin1 and skin3 (eyes, outline, grey cloth and scalp
    stay)."""
    warm = L.skinish(one) & (one[..., 3] > 127)
    diff = np.abs(one[..., :3].astype(int) - three[..., :3]).sum(-1)
    seeds = warm & (diff > 24) & (three[..., 3] > 127)
    seeds = nd.binary_opening(seeds, iterations=1)
    return nd.binary_propagation(seeds, structure=np.ones((3, 3)), mask=warm)


def colour_fit(one, other, mask):
    """Per-channel least squares other = k * one + m over [mask] pixels
    that are skin in both pictures; returns (k, m) arrays and the mean
    absolute residual."""
    both = mask & L.skinish(other) & (other[..., 3] > 127)
    x = one[both][:, :3].astype(float)
    y = other[both][:, :3].astype(float)
    k, m, res = np.zeros(3), np.zeros(3), np.zeros(3)
    for ch in range(3):
        A = np.stack([x[:, ch], np.ones(len(x))], 1)
        (k[ch], m[ch]), *_ = np.linalg.lstsq(A, y[:, ch], rcond=None)
        res[ch] = np.abs(A @ (k[ch], m[ch]) - y[:, ch]).mean()
    return k, m, res, int(both.sum())


def recolour(one, mask, k, m):
    out = one.copy()
    rgb = one[mask][:, :3].astype(float) * k + m
    out[mask, :3] = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
    return out


def scaled_box(box, s, dx, dy, pad=12):
    l, t, r, b = box
    return (int(l * s + dx) - pad, int(t * s + dy) - pad,
            int(r * s + dx) + pad, int(b * s + dy) + pad)


def sheet(rows, path):
    """Originals (left three) and normalized (right three) per character,
    on a checker, shown at 1/4 with the target eye / mouth / sole lines."""
    k = 4
    cw, ch = CANVAS[0] // k, CANVAS[1] // k
    gap, head = 8, 22
    out = Image.new('RGB', (6 * (cw + gap) + gap, len(rows) * (ch + head + gap) + gap),
                    (40, 34, 30))
    d = ImageDraw.Draw(out)
    try:  # Korean labels (Windows); the default font has no Hangul
        font = ImageFont.truetype('malgun.ttf', 14)
    except OSError:
        font = None
    for ri, (c, originals, normals) in enumerate(rows):
        y0 = gap + ri * (ch + head + gap)
        for ci, (label, a, lines) in enumerate(
                [(f'{c} {s} 원본', o, False) for s, o in zip(SKINS, originals)] +
                [(f'{c} {s} 정규화', n, True) for s, n in zip(SKINS, normals)]):
            x0 = gap + ci * (cw + gap)
            bg = Image.new('RGB', (cw, ch), (230, 226, 220))
            bd = ImageDraw.Draw(bg)
            for yy in range(0, ch, 10):
                for xx in range((yy // 10) % 2 * 10, cw, 20):
                    bd.rectangle((xx, yy, xx + 9, yy + 9), fill=(246, 243, 238))
            img = Image.fromarray(a, 'RGBA')
            if img.size != CANVAS:  # original: on the canvas size, top left
                big = Image.new('RGBA', CANVAS)
                big.paste(img, (0, 0))
                img = big
            small = img.resize((cw, ch), Image.LANCZOS)
            bg.paste(small, (0, 0), small)
            if lines:
                t = TARGET[c]
                for (tx, ty), col in ((t['eyes'], (0, 160, 255)), (t['mouth'], (230, 40, 160))):
                    bd.line((0, ty / k, cw, ty / k), fill=col)
                    bd.line((tx / k, ty / k - 6, tx / k, ty / k + 6), fill=col)
                bd.line((0, SOLE_EDGE / k - 1, cw, SOLE_EDGE / k - 1), fill=(0, 170, 60))
            out.paste(bg, (x0, y0 + head))
            d.text((x0 + 2, y0 + 2), label if font else label.encode('ascii', 'ignore').decode(),
                   fill=(255, 243, 214), font=font)
    out.save(path)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    p = argparse.ArgumentParser()
    p.add_argument('--src', type=Path, default=SRC, help='23_avatar_base folder')
    args = p.parse_args()
    src = args.src.resolve()
    dest = src / 'normalized'
    report = {'canvas': list(CANVAS), 'targets': {c: {k: list(v) for k, v in t.items()}
                                                   for c, t in TARGET.items()},
              'sole_edge': SOLE_EDGE, 'characters': {}}
    rows = []
    for c in ('girl', 'boy'):
        srcs = {s: load(src / c / f'base_{s}.png') for s in SKINS}
        one = srcs['skin1']
        lm = landmarks(one, c)
        s, dx, dy = transform(lm, c)
        # Alpha snapping can lose or add the soles' half-covered last row:
        # move by what the placed skin1 is off (whole rows), once.
        dy -= landmarks(place(one, s, dx, dy), c)['sole'] - SOLE_EDGE
        three, shift3 = on_one(one, srcs['skin3'])
        mask = skin_mask(one, three)
        info = {'source_landmarks': {k: (list(map(float, v)) if isinstance(v, tuple) else v)
                                     for k, v in lm.items()},
                'scale': round(s, 6), 'dx': round(dx, 3), 'dy': round(dy, 3),
                'skin_pixels_source': int(mask.sum()), 'tones': {}}
        normals = []
        for skin in SKINS:
            if skin == 'skin1':
                painted = one
                info['tones'][skin] = {'from': 'skin1 그대로'}
            else:
                other, shift = on_one(one, srcs[skin])
                k, m, res, n = colour_fit(one, other, mask)
                painted = recolour(one, mask, k, m)
                info['tones'][skin] = {
                    'from': f'skin1 모양에 {skin} 피부색(채널별 선형 맞춤)',
                    'source_shift_to_skin1': list(shift),
                    'fit_k': [round(v, 4) for v in k], 'fit_m': [round(v, 2) for v in m],
                    'fit_mean_abs_residual': [round(v, 2) for v in res], 'fit_pixels': n,
                    'median_skin_rgb': [int(v) for v in np.median(
                        painted[mask][:, :3], 0)]}
            out = place(painted, s, dx, dy)
            (dest / c).mkdir(parents=True, exist_ok=True)
            Image.fromarray(out, 'RGBA').save(dest / c / f'base_{skin}.png', optimize=True)
            normals.append(out)
        info['tones']['skin1']['median_skin_rgb'] = [int(v) for v in np.median(one[mask][:, :3], 0)]
        # Measure the result again (boxes moved with the transform).
        got = landmarks(normals[0], c, scaled_box(EYE_BOX[c], s, dx, dy),
                        scaled_box(MOUTH_BOX[c], s, dx, dy))
        t = TARGET[c]
        err = {
            'eyes': [round(float(got['eyes'][i] - t['eyes'][i]), 2) for i in (0, 1)],
            'mouth': [round(float(got['mouth'][i] - t['mouth'][i]), 2) for i in (0, 1)],
            'sole_last_row': int(got['sole']) - 1,
            'sole': round(float(got['sole'] - SOLE_EDGE), 2),
        }
        err['mouth_game_px'] = [round(v / 4, 2) for v in err['mouth']]
        alpha = normals[0][..., 3] > 0
        ys, xs = np.nonzero(alpha)
        info['bbox'] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
        info['margin_lr'] = [int(xs.min()), int(CANVAS[0] - 1 - xs.max())]
        same = all(np.array_equal(normals[0][..., 3], n[..., 3]) for n in normals[1:])
        diff = [np.abs(normals[0][..., :3].astype(int) - n[..., :3]).sum(-1) > 0
                for n in normals[1:]]
        changed = np.logical_or.reduce(diff)
        info['same_alpha_all_tones'] = bool(same)
        info['pixels_that_differ_between_tones'] = int(changed.sum())
        info['skin_pixels'] = int((normals[0][..., 3] > 0).sum())
        info['error_after'] = err
        report['characters'][c] = info
        print(f'{c}: scale {s:.4f} shift ({dx:.1f}, {dy:.1f}) error {err}')
        rows.append((c, [srcs[k] for k in SKINS], normals))
    (dest / 'report.json').write_text(json.dumps(report, indent=1, ensure_ascii=False) + '\n',
                                      'utf-8', newline='\n')
    sheet(rows, dest / 'compare.png')
    print('wrote', dest)


if __name__ == '__main__':
    main()
