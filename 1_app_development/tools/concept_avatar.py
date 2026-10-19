"""Cuts the vendor's paper-doll parts out of the concept sheets.

Sources (3_original_images_and_visual_references/3.2_visual_design_references_20261006/01_원본전체):
  여자꾸미기선택_원본_261006_1905_01.png: girl base, hair, tops, bottoms, shoes, items
  남자꾸미기선택_원본_261006_1905_01.png: boy base, hair, tops, bottoms, shoes, items
  가게꾸미기요소_원본_261006_1905_01.png: aprons, tops, hats, scarf, mittens, tools

Hair swaps, pants and aprons are left out: the sheets' hair pieces would
lie over the base figure's own hair, and their pants and aprons are drawn
laid flat, not worn. Nothing is drawn: each part is cut out, its white sheet background removed,
then scaled and placed onto its character's base figure by landmarks
measured on that figure (tee, shorts, shoes, face, hair, hands). Output, one
canvas per character, all layers the same size:
  assets/images/avatar/<character>/base.png        body, face, long hair,
                                                   tee, shorts, flats
(CANVAS size, all layers the same size)
  assets/images/avatar/<character>/<slot>_<id>.png one part on its own

Run from the project root:  python tools/concept_avatar.py
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
REF = ROOT.parent / '3_original_images_and_visual_references' / '3.2_visual_design_references_20261006' / '01_원본전체'
OUT = ROOT / 'assets' / 'images' / 'avatar'

CANVAS = (280, 520)  # every layer's size; one base figure with margin

# Landmarks on each base figure, in sheet pixels: boxes are (l, t, r, b).
MARKS = {
    # The girl sheet's right figure: the left one stands with crossed legs.
    'girl': dict(sheet='여자꾸미기선택_원본_261006_1905_01.png', box=(615, 0, 895, 520),
                 tee=(710, 215, 825, 292),
                 shorts=(718, 293, 815, 348), shoes=(725, 475, 810, 502),
                 face=(728, 105, 830, 200), hair=(677, 22, 855, 200),
                 hand_l=(700, 345), hand_r=(836, 345), eyes=150, neck=200),
    # The boy sheet's right figure: the left one has eyelashes.
    'boy': dict(sheet='남자꾸미기선택_원본_261006_1905_01.png', box=(620, 0, 900, 520),
                tee=(695, 215, 838, 318),
                shorts=(712, 310, 825, 410), shoes=(705, 468, 833, 502),
                face=(710, 105, 830, 205), hair=(667, 15, 877, 215),
                hand_l=(697, 352), hand_r=(842, 352), eyes=150, neck=210,
                pants_extra=26),
}

# (character or None for both, slot, id, sheet, crop box, fit)
PARTS = [
    # Girl sheet.
    ('girl', 'top', 'cardigan', '여자꾸미기선택_원본_261006_1905_01.png', (503, 770, 725, 920), 'top'),
    ('girl', 'top', 'creamsweater', '여자꾸미기선택_원본_261006_1905_01.png', (786, 770, 1016, 927), 'top'),
    ('girl', 'bottom', 'skirt', '여자꾸미기선택_원본_261006_1905_01.png', (507, 934, 717, 1072), 'bottom'),
    ('girl', 'shoes', 'sneakers', '여자꾸미기선택_원본_261006_1905_01.png', (287, 1132, 431, 1226), 'shoes'),
    ('girl', 'shoes', 'boots', '여자꾸미기선택_원본_261006_1905_01.png', (453, 1124, 611, 1231), 'shoes'),
    ('girl', 'accessory', 'ribbon', '여자꾸미기선택_원본_261006_1905_01.png', (651, 1140, 775, 1231), 'ribbon'),
    ('girl', 'accessory', 'glasses', '여자꾸미기선택_원본_261006_1905_01.png', (803, 1149, 966, 1223), 'glasses'),
    ('girl', 'accessory', 'crossbag', '여자꾸미기선택_원본_261006_1905_01.png', (994, 1062, 1139, 1245), 'bag'),
    # Boy sheet.
    ('boy', 'top', 'cardigan', '남자꾸미기선택_원본_261006_1905_01.png', (499, 729, 745, 900), 'top'),
    ('boy', 'top', 'creamsweater', '남자꾸미기선택_원본_261006_1905_01.png', (801, 731, 1057, 895), 'top'),
    ('boy', 'shoes', 'sneakers', '남자꾸미기선택_원본_261006_1905_01.png', (238, 1121, 401, 1225), 'shoes'),
    ('boy', 'shoes', 'boots', '남자꾸미기선택_원본_261006_1905_01.png', (420, 1116, 609, 1229), 'shoes'),
    ('boy', 'accessory', 'glasses', '남자꾸미기선택_원본_261006_1905_01.png', (625, 1139, 793, 1213), 'glasses'),
    ('boy', 'accessory', 'crossbag', '남자꾸미기선택_원본_261006_1905_01.png', (1028, 1056, 1188, 1235), 'bag'),
    (None, 'hat', 'ballcap', '남자꾸미기선택_원본_261006_1905_01.png', (811, 1121, 987, 1231), 'hat'),
    # Shop sheet: for both characters.
    (None, 'outfit', 'padding', '가게꾸미기요소_원본_261006_1905_01.png', (894, 765, 1147, 938), 'top'),
    (None, 'top', 'creamlong', '가게꾸미기요소_원본_261006_1905_01.png', (106, 775, 347, 935), 'top'),
    (None, 'top', 'pinksweater', '가게꾸미기요소_원본_261006_1905_01.png', (368, 772, 616, 937), 'top'),
    (None, 'top', 'sagesweater', '가게꾸미기요소_원본_261006_1905_01.png', (632, 773, 881, 937), 'top'),
    (None, 'hat', 'bandana', '가게꾸미기요소_원본_261006_1905_01.png', (54, 944, 234, 1103), 'scarfhat'),
    (None, 'hat', 'newsboy', '가게꾸미기요소_원본_261006_1905_01.png', (253, 955, 433, 1072), 'hat'),
    (None, 'hat', 'beanie', '가게꾸미기요소_원본_261006_1905_01.png', (446, 950, 609, 1076), 'hat'),
    (None, 'accessory', 'scarf', '가게꾸미기요소_원본_261006_1905_01.png', (638, 939, 792, 1088), 'scarf'),
    (None, 'accessory', 'mittens', '가게꾸미기요소_원본_261006_1905_01.png', (833, 963, 1000, 1075), 'mittens'),
    (None, 'accessory', 'fishpin', '가게꾸미기요소_원본_261006_1905_01.png', (1040, 972, 1186, 1063), 'pin'),
    (None, 'shoes', 'furboots', '가게꾸미기요소_원본_261006_1905_01.png', (443, 1094, 647, 1232), 'shoes'),
    (None, 'tool', 'tongs', '가게꾸미기요소_원본_261006_1905_01.png', (656, 1092, 823, 1241), 'tool'),
    (None, 'tool', 'paperbag', '가게꾸미기요소_원본_261006_1905_01.png', (842, 1079, 1004, 1241), 'tool'),
    (None, 'tool', 'fishhold', '가게꾸미기요소_원본_261006_1905_01.png', (1025, 1111, 1198, 1232), 'tool'),
]


def cut(sheet, box):
    """The part inside [box] with the white sheet around it made clear."""
    img = Image.open(REF / sheet).convert('RGBA').crop(box)
    a = np.asarray(img).copy()
    white = a[..., :3].min(axis=2) > 232
    labels, _ = ndimage.label(white)
    edge = np.unique(np.concatenate(
        [labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    a[np.isin(labels, edge[edge > 0]), 3] = 0
    part = Image.fromarray(a)
    return part.crop(part.getbbox())


def scaled(part, width):
    h = max(1, round(part.height * width / part.width))
    return part.resize((max(1, round(width)), h), Image.LANCZOS)


def place(canvas, part, left, top, m):
    ox, oy = m['box'][0], m['box'][1]
    canvas.alpha_composite(part, (round(left - ox), round(top - oy)))


def fit(kind, part, m):
    """The part scaled and placed on a fresh canvas for marks [m]."""
    canvas = Image.new('RGBA', CANVAS)
    tee, shorts, shoes, face, hair = (m[k] for k in
                                      ('tee', 'shorts', 'shoes', 'face', 'hair'))
    cx = lambda b: (b[0] + b[2]) / 2
    w = lambda b: b[2] - b[0]
    if kind == 'top':
        # Wide enough and long enough to cover the base tee.
        width = max(w(tee) * 1.12,
                    (tee[3] - tee[1] + 10) * part.width / part.height)
        p = scaled(part, width)
        place(canvas, p, cx(tee) - p.width / 2, tee[1] - 6, m)
    elif kind == 'apron':
        p = scaled(part, w(tee) * .92)
        place(canvas, p, cx(tee) - p.width / 2, tee[1] + 10, m)
    elif kind == 'waist':
        p = scaled(part, w(shorts) * 1.3)
        place(canvas, p, cx(shorts) - p.width / 2, shorts[1] - 10, m)
    elif kind == 'bottom':
        p = scaled(part, w(shorts) * 1.08)
        place(canvas, p, cx(shorts) - p.width / 2, shorts[1] - 4, m)
    elif kind == 'pants':
        # Waist to the top of the shoes; the boy's reach over the shoe tops.
        length = shoes[1] - shorts[1] + m.get('pants_extra', 10)
        p = scaled(part, min(length * part.width / part.height,
                             w(shorts) * 1.3))
        place(canvas, p, cx(shorts) - p.width / 2, shorts[1] - 4, m)
    elif kind == 'shoes':
        p = scaled(part, w(shoes) * 1.05)
        place(canvas, p, cx(shoes) - p.width / 2, shoes[3] - p.height, m)
    elif kind == 'hair':
        p = scaled(part, w(hair))
        place(canvas, p, cx(hair) - p.width / 2, hair[1] - 2, m)
    elif kind in ('hat', 'scarfhat'):
        # A headscarf's knot hangs below its band, so it sits lower.
        p = scaled(part, w(face) * 1.55)
        drop = 48 if kind == 'scarfhat' else 18
        place(canvas, p, cx(face) - p.width / 2, face[1] + drop - p.height, m)
    elif kind == 'glasses':
        p = scaled(part, w(face) * .92)
        place(canvas, p, cx(face) - p.width / 2, m['eyes'] - p.height / 2, m)
    elif kind == 'ribbon':
        p = scaled(part, w(face) * .55)
        place(canvas, p, hair[2] - p.width - 8, hair[1] + 18, m)
    elif kind == 'pin':
        p = scaled(part, w(face) * .38)
        place(canvas, p, face[2] - p.width / 2, face[1] - 4, m)
    elif kind == 'scarf':
        p = scaled(part, w(tee) * .9)
        place(canvas, p, cx(tee) - p.width / 2, m['neck'] - 10, m)
    elif kind == 'mittens':
        half = part.width // 2
        for side, hand in ((part.crop((0, 0, half, part.height)), m['hand_l']),
                           (part.crop((half, 0, part.width, part.height)),
                            m['hand_r'])):
            side = side.crop(side.getbbox())
            p = scaled(side, 34)
            place(canvas, p, hand[0] - p.width / 2, hand[1] - p.height / 2, m)
    elif kind == 'bag':
        p = scaled(part, w(tee) * .55)
        place(canvas, p, tee[2] - p.width * .55, shorts[1] - p.height * .4, m)
    elif kind == 'tool':
        p = scaled(part, 62)
        hand = m['hand_r']
        place(canvas, p, hand[0] - p.width * .35, hand[1] - p.height * .55, m)
    else:
        raise ValueError(kind)
    return canvas


def main():
    for character, m in MARKS.items():
        folder = OUT / character
        folder.mkdir(parents=True, exist_ok=True)
        base = cut(m['sheet'], m['box'])
        canvas = Image.new('RGBA', CANVAS)
        # Keep the base where it sits in the sheet (cut() trimmed it).
        full = Image.open(REF / m['sheet']).convert('RGBA').crop(m['box'])
        bbox = Image.fromarray(np.asarray(full)[..., :3].min(axis=2)
                               .__le__(232).astype('uint8') * 255).getbbox()
        canvas.alpha_composite(base, (bbox[0], bbox[1]))
        canvas.save(folder / 'base.png')
        count = 1
        for who, slot, item, sheet, box, kind in PARTS:
            if who not in (None, character):
                continue
            fit(kind, cut(sheet, box), m).save(folder / f'{slot}_{item}.png')
            count += 1
        print(f'{character}: {count} images')


if __name__ == '__main__':
    main()
