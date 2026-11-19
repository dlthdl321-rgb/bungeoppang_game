"""The vendor redrawn from a bare base (26번 4-7단계, 25번 문서 23~31번).

The v1 vendor (tools/avatar_layers.py) has hair, a tee, shorts and flats
painted into its base picture; items are laid over it and `_cut` masks
erase what they hide, which left hair ghosts, sleeves lying on the arms and
the shorts showing under a skirt (2차 녹화 G6·G9·G10). v2 starts from a
bare base (no hair, plain grey underwear, bare feet) with one picture per
skin tone, and every item - the defaults too - is its own worn layer.

Jobs (safe to run again, in this order; no job = all):

  align     23번 bases (1120x2080, 4x the game; 23_avatar_base/normalized/
            from tools/normalize_avatar_base.py when there) -> 280x520. Only a shift,
            never a resize: the soles land on row 519 and the eyes on the
            anchor of avatar_v2.json. skin2/3 take skin1's shift.
  items     24~30번 item pictures -> the same 280x520 canvas, shifted like
            that character's skin1 base. Keeps only pixels that differ
            from the base (an item drawn alone or on the base gives the
            same layer) and warns about skin-coloured pixels.
  hairmask  hat_<id>_hairmask.png for every hat: where the game erases the
            HAIR layer under that hat (never the base, it has no hair).
            Rules per hat in avatar_v2.json hat_hair.
  face      Eye and mouth frames for each base (its own skin colour):
            face_<eyes_half|eyes_closed|mouth_small|mouth_wide>@<skin>.png.
  icons     31번 icons (512x512) -> assets/images/cosmetic_icons/<id>.png
            64x64, only for a slot whose icons are ALL there (no slot mixes
            drawn and temporary icons).
  trim      Cuts the empty margins, remembers each offset.
  atlas     lib/avatar_v2_atlas.dart: the shipped files, offsets, pivots,
            anchors and avatarV2Ready (every required picture is there);
            adds the avatar_v2 folders to pubspec.yaml once they have art.
  faceaudit G3 check: face width left and right of the eyes' axis, row by
            row, for the v1 boy and girl, the original concept crop, the
            game's own rendering (build/avatar_v2/render_<c>.png, written
            by tools/preview_avatar_v2_test.dart) and the v2 bases when
            present. Writes build/avatar_v2/g3_face.png and g3_face.json.

  python tools/avatar_v2.py [jobs] [--src <26_feedback_generated>] [--preview]
  python tools/avatar_v2.py --demo     # pipeline check on v1-made stand-ins,
                                       # written to build/avatar_v2/demo/ only

Run in 1_app_development. Sources default to
../4_image_generation_results_and_backups/26_feedback_generated (git-ignored;
from a worktree pass --src to the main checkout's folder).
"""
import json
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import apply_extra_art as X  # noqa: E402
import avatar_layers as L  # noqa: E402

ROOT = L.ROOT
IMAGES = L.IMAGES
DATA = ROOT / 'tools' / 'avatar_v2.json'
DART = ROOT / 'lib' / 'avatar_v2_atlas.dart'
PUBSPEC = ROOT / 'pubspec.yaml'
BUILD = ROOT / 'build' / 'avatar_v2'
CANVAS = L.CANVAS  # (280, 520)
SCALE = 4  # sources are drawn at 4x the game
SOLE_ROW = CANVAS[1] - 1
CHARACTERS = ('girl', 'boy')
SKINS = ('skin1', 'skin2', 'skin3')
HAIR_BACKS = ('long', 'ponytail', 'curly')
# Item slot -> 25번 source folder (CosmeticSlot names, as the game files).
FOLDERS = {'hair': '24_hair', 'hat': '25_hats', 'top': '26_tops',
           'bottom': '27_bottoms', 'shoes': '28_shoes', 'outfit': '29_aprons',
           'accessory': '30_props', 'tool': '30_props'}
ITEM_SLOTS = tuple(FOLDERS)
# 'tongs' draws nothing since 26번 3차 H8 (cosmetic_config.dart blankCosmetics).
BLANK = {'nohat', 'noacc', 'noapron', 'tongs'}
CHANGED = 40  # RGB distance from the base that makes an item pixel
SKIN_WARN = 25  # skin-coloured pixels an item may have before a warning


def default_src():
    return ROOT.parent / '4_image_generation_results_and_backups' / \
        '26_feedback_generated'


def load_data():
    data = json.loads(DATA.read_text('utf-8')) if DATA.exists() else {}
    data.setdefault('anchors', {
        'girl': {'eyes': [153.5, 155.0], 'mouth': [152, 184]},
        'boy': {'eyes': [151.5, 156.0], 'mouth': [150, 184]}})
    data.setdefault('hat_hair', {
        '_': 'cover: hair above the hat\'s lower edge in its columns is '
             'erased; band: only under the hat itself (+keep boxes, canvas '
             'l,t,r,b, never erased). Back halves (hair_*_back) are never '
             'erased, so a ponytail stays behind any hat.',
        'default': {'mode': 'cover', 'keep': []},
        'earmuffs': {'mode': 'band', 'keep': []},
    })
    return data


def definitions():
    """(id, slot) of every avatar item in lib/cosmetic_config.dart."""
    text = (ROOT / 'lib/cosmetic_config.dart').read_text('utf-8')
    return re.findall(
        r"CosmeticDefinition\(\s*'(\w+)',\s*'[^']*',\s*CosmeticSlot\.(\w+)",
        text)


def required():
    """Every picture v2 needs: the six bases, then every item layer the
    wardrobe can show (the defaults too), girl and boy. Same list as
    lib/avatar_v2.dart avatarV2Required."""
    defs = definitions()
    out = []
    for c in CHARACTERS:
        out += [f'avatar_v2/{c}/base@{s}.png' for s in SKINS]
        for item, slot in defs:
            if slot in ITEM_SLOTS and item not in BLANK:
                out.append(f'avatar_v2/{c}/{slot}_{item}.png')
                if slot == 'hair' and item in HAIR_BACKS:
                    out.append(f'avatar_v2/{c}/{slot}_{item}_back.png')
    return out


def out_dir(demo):
    return BUILD / 'demo' / 'images' if demo else IMAGES


# 26번 3차 (2026-11-19): 24~30번 came drawn on the 23번 bases as generated
# (880x1787), not on the normalized 1120x2080 canvas. Such a source gets
# the same scale + shift its character's base got from
# tools/normalize_avatar_base.py (23_avatar_base/normalized/report.json), so
# it lands where the normalized base is.
RAW = {}  # character -> (scale, dx, dy), filled by main() from the report
RAW_SOLE = {}  # character -> last opaque row of the raw skin1 base
SOLE_SLOTS = ('shoes_',)


def to_4x(path, character):
    """[path] as a 4x RGBA array: as it is, or placed like its character's
    raw base (RAW); None when neither fits."""
    img = Image.open(path)
    want = (CANVAS[0] * SCALE, CANVAS[1] * SCALE)
    if img.size == want:
        return np.array(img.convert('RGBA'))
    if character in RAW and img.size == RAW[character][3]:
        import normalize_avatar_base as N
        s, dx, dy, _ = RAW[character]
        arr = np.array(img.convert('RGBA'))
        if arr[..., 3].min() == 255:
            arr = X.load_cut(path)
        if path.stem.startswith(SOLE_SLOTS) and character in RAW_SOLE:
            # 26번 3차 H9·H10: the boy's shoes were drawn ~50px below his
            # soles and came out cut at the canvas foot; shoes stand on the
            # base's soles.
            rows = np.nonzero((arr[..., 3] > 127).any(1))[0]
            lift = int(rows.max()) - RAW_SOLE[character]
            if lift > 0:
                arr = shift(arr, 0, -lift)
        saved = N.CANVAS
        try:
            return N.place(arr, s, dx, dy)
        finally:
            N.CANVAS = saved
    return None


def shrink(path, character=None):
    """A 4x source on the 280x520 canvas (area average, then clean edges:
    alpha 0/255 so no halo), or None with the reason."""
    img = Image.open(path)
    want = (CANVAS[0] * SCALE, CANVAS[1] * SCALE)
    if img.size != want:
        arr = to_4x(path, character) if character else None
        if arr is None:
            return None, f'{img.size[0]}x{img.size[1]} (필요 {want[0]}x{want[1]})'
        small = X.area_sample(arr, *CANVAS)
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        return small.astype(np.uint8), None
    arr = np.array(img.convert('RGBA'))
    if arr[..., 3].min() == 255:  # white background: clear it
        arr = X.load_cut(path)
    else:
        arr[..., 3] = np.where(arr[..., 3] >= 128, 255, 0)
    small = X.area_sample(arr, *CANVAS)
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    return small.astype(np.uint8), None


def shift(arr, dx, dy):
    out = np.zeros_like(arr)
    h, w = arr.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else \
        (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else \
        (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = arr[ys, xs]
    return out


def landmarks(arr, character):
    """(sole row, face dx, face dy) of a base: the lowest opaque row, and
    how far its face (eyes and mouth) sits from the v1 face, found by laying
    the v1 face box over it (L.match). v2 keeps v1's face and its anchors,
    so (0, 0) means the eyes and mouth are on the anchors."""
    alpha = arr[..., 3] > 0
    rows = np.nonzero(alpha.any(1))[0]
    sole = int(rows.max()) if len(rows) else -1
    v1_trim = json.loads(L.DATA.read_text('utf-8'))['trim']
    ref = L.rgba(f'avatar/{character}/base.png', v1_trim)
    found = L.match(ref, arr.astype(np.int32), L.face_box(character, 3),
                    reach=60)
    if found is None:
        return sole, None, None
    return sole, found[1], found[2]


def save(arr, path):
    L.save(np.asarray(arr), path)


# ---------------------------------------------------------------- align

def align(data, src, demo):
    report = data.setdefault('align', {})
    norm_dir = src / '23_avatar_base' / 'normalized'
    norm_report = norm_dir / 'report.json'
    measured = (json.loads(norm_report.read_text('utf-8'))['characters']
                if norm_report.exists() else {})
    for c in CHARACTERS:
        offset = None
        for skin in SKINS:
            # The bases normalized to the 4x canvas and anchors by
            # tools/normalize_avatar_base.py come first (25번 23번 확정본).
            path = norm_dir / c / f'base_{skin}.png'
            normalized = path.exists() and c in measured
            if not normalized:
                path = src / '23_avatar_base' / c / f'base_{skin}.png'
            key = f'avatar_v2/{c}/base@{skin}.png'
            if not path.exists():
                report[key] = {'state': '없음'}
                continue
            arr, why = shrink(path)
            if arr is None:
                report[key] = {'state': f'규격 미달 {why}'}
                print(f'align {key}: skipped, {why}')
                continue
            sole, fx, _ = landmarks(arr, c)
            if offset is None:  # skin1 (or the first there) sets the shift
                # A normalized base already has its eyes on the anchor
                # (measured on its own eyes): only the soles may move. The
                # v1 face match is for bases drawn like the v1 face.
                offset = (0 if normalized or fx is None else -fx,
                          SOLE_ROW - sole)
            arr = shift(arr, *offset)
            sole, fx, fy = landmarks(arr, c)
            # Left over after the shift: the soles decide the height, so a
            # face drawn higher or lower than v1's shows up in eyes_y.
            err = {'sole': sole - SOLE_ROW, 'eyes_x': fx, 'eyes_y': fy}
            if normalized:  # its own eyes (4x error / 4), v1 match kept
                ex, ey = measured[c]['error_after']['eyes']
                err = {'sole': sole - SOLE_ROW,
                       'eyes_x': round(ex / SCALE + offset[0], 2),
                       'eyes_y': round(ey / SCALE, 2),
                       'v1_face_x': fx, 'v1_face_y': fy}
            report[key] = {'state': 'ok', 'shift': list(offset), 'error': err,
                           'source': path.relative_to(src).as_posix()}
            save(arr, out_dir(demo) / key)
            print(f'align {key}: shift {offset}, error {err}')


# ---------------------------------------------------------------- items

def base_full(c, skin, demo):
    path = out_dir(demo) / f'avatar_v2/{c}/base@{skin}.png'
    if not path.exists():
        return None
    # Back on its full canvas: trim may have run already.
    return full(path, load_data() if not demo else {}, demo)


def skin_pixels(c, demo):
    """Base pixels that are skin: they change between skin1 and skin3."""
    one, three = base_full(c, 'skin1', demo), base_full(c, 'skin3', demo)
    if one is None or three is None:
        return None
    diff = np.abs(one[..., :3].astype(int) - three[..., :3]).sum(-1)
    return (one[..., 3] > 0) & (diff > 30)


def despeck(arr):
    """Light grey-white pixels on a hair layer's rim: the white background
    of the generated picture left between strands (26번 3차 H10)."""
    from scipy import ndimage
    a = arr.astype(np.int32)
    rgb = a[..., :3]
    light = (a[..., 3] > 0) & (rgb.mean(-1) > 185) &         (rgb.max(-1) - rgb.min(-1) < 45)
    rim = ndimage.binary_dilation(a[..., 3] == 0, iterations=2)
    labels, _ = ndimage.label(light)
    hit = np.unique(labels[light & rim])
    out = arr.copy()
    out[np.isin(labels, hit[hit > 0]), 3] = 0
    return out


# 26번 3차 H10: items centred on a face anchor. The glasses came drawn
# over the mouth; their box's centre goes on the eyes' anchor.
ON_ANCHOR = {'accessory_glasses': 'eyes'}


def on_anchor(arr, anchor):
    ys, xs = np.nonzero(arr[..., 3] > 0)
    if len(xs) == 0:
        return arr
    cx, cy = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
    return shift(arr, int(round(anchor[0] - cx)), int(round(anchor[1] - cy)))


def items(data, src, demo):
    report = data.setdefault('items', {})
    for c in CHARACTERS:
        base = base_full(c, 'skin1', demo)
        if base is None:
            print(f'items {c}: no skin1 base yet, skipped')
            continue
        shift_by = tuple(data.get('align', {}).get(
            f'avatar_v2/{c}/base@skin1.png', {}).get('shift', (0, 0)))
        skin = skin_pixels(c, demo)
        for slot, folder in FOLDERS.items():
            # --only=<slot>[,<slot>]: redo just those slots.
            only = [a.split('=', 1)[1].split(',') for a in sys.argv
                    if a.startswith('--only=')]
            if only and slot not in only[0]:
                continue
            for path in sorted((src / folder / c).glob(f'{slot}_*.png')):
                if path.stem[len(slot) + 1:] in BLANK:
                    continue  # drawn as nothing (the tongs, 3차 H8)
                key = f'avatar_v2/{c}/{path.name}'
                arr, why = shrink(path, c)
                if arr is None:
                    report[key] = {'state': f'규격 미달 {why}'}
                    print(f'items {key}: skipped, {why}')
                    continue
                arr = shift(arr, *shift_by)
                # Only what differs from the base, for a picture drawn ON
                # the base (it covers most of the figure). A picture of the
                # item alone keeps every pixel: beige shorts over the legs
                # are close to skin and came out holed (26번 3차 H10).
                on_base = (arr[..., 3] > 0)[base[..., 3] > 0].mean() > .5
                if on_base:
                    d = np.sqrt(((arr[..., :3].astype(np.int32) -
                                  base[..., :3]) ** 2).sum(-1))
                    same = (arr[..., 3] > 0) & (base[..., 3] > 0) &                         (d < CHANGED)
                    arr[same, 3] = 0
                if slot == 'hair':
                    arr = despeck(arr)
                if path.stem in ON_ANCHOR:
                    arr = on_anchor(arr, data['anchors'][c][ON_ANCHOR[path.stem]])
                # Skin painted into the item: item pixels over the base's
                # skin that still look like skin (they would not follow the
                # other skin tones).
                warn = 0
                if skin is not None:
                    warn = int(((arr[..., 3] > 0) & skin &
                                (L.skinlike(arr) | L.skinish(arr))).sum())
                state = 'ok' if warn <= SKIN_WARN else f'피부색 {warn}px 경고'
                report[key] = {'state': state, 'pixels': int((arr[..., 3] > 0).sum())}
                save(arr, out_dir(demo) / key)
                print(f'items {key}: {state}')


# ---------------------------------------------------------------- bare

# 26번 3차 H10 (2026-11-19): the 23번 bases wear a grey head cover, a grey
# vest and grey shorts as placeholders, and the 24~27번 layers drawn for
# them do not always cover them (grey above the hair, a grey neckline over
# the tee collar). The game always wears hair, a top and a bottom, so the
# placeholders are never meant to show: the head cover goes (with its
# outline, above BARE['forehead']) and the vest and shorts become skin
# (each tone from its own nearest skin), with the seam lines inside them.
BARE = {'forehead': {'girl': 108, 'boy': 108},  # above the eyebrows
        'grey_sat': 28, 'grey_lum': (80, 245),
        'face': (95, 125, 215, 200)}  # l, t, r, b: eye whites are grey too


def bare(data, demo):
    from scipy import ndimage
    for c in CHARACTERS:
        tones = {s: base_full(c, s, demo) for s in SKINS}
        if any(t is None for t in tones.values()):
            continue
        one = tones['skin1'].astype(np.int32)
        alpha = one[..., 3] > 0
        rgb = one[..., :3]
        sat = rgb.max(-1) - rgb.min(-1)
        lum = rgb.mean(-1)
        lo, hi = BARE['grey_lum']
        grey = alpha & (sat < BARE['grey_sat']) & (lum >= lo) & (lum <= hi)
        fl, ft, fr, fb = BARE['face']
        grey[ft:fb, fl:fr] = False
        skin = skin_pixels(c, demo)
        rows = np.arange(alpha.shape[0])[:, None]
        top = rows < BARE['forehead'][c]
        # Head cover: the grey above the forehead and the dark outline
        # around it (the hair layer draws the head's outline).
        cap = top & alpha & (grey | (lum < 110)) & ~skin
        cap = ndimage.binary_dilation(cap, iterations=1) & top & alpha &             ~(skin & (sat >= BARE['grey_sat']))
        # Vest and shorts: the grey, plus the seams between them and the
        # skin (dark pixels next to the grey, away from the outer outline).
        under = grey & ~top
        inner = ndimage.binary_erosion(alpha, iterations=2)
        seam = ndimage.binary_dilation(under, iterations=3) & inner &             ~(skin & (lum >= 140)) & ~under & ~top
        seam[ft:fb, fl:fr] = False
        under |= seam
        body = skin & ~top & (rows > fb) & (lum >= 140)
        for s, arr in tones.items():
            out = arr.copy()
            out[cap] = 0
            # One flat skin colour (each tone's own): a neckline or hem gap
            # shows plain skin, never a smear of edge colours.
            out[under, :3] = np.median(arr[body][:, :3], axis=0).astype(np.uint8)
            key = f'avatar_v2/{c}/base@{s}.png'
            save(out, out_dir(demo) / key)
            data.setdefault('trim', {}).pop(key, None)
        print(f'bare {c}: head cover {int(cap.sum())} px cleared, '
              f'vest and shorts {int(under.sum())} px to skin')


# 26번 3차 H10: a hair style drawn a little inside the bare head lets the
# scalp show above or beside it. hair_<id>_basemask.png erases from the
# BASE what that hair leaves bare above the ears (rows < BASEMASK['above'])
# outside the face (an ellipse round the eyes anchor, radii 'face').
BASEMASK = {'above': 138, 'face': (60, 48), 'brow': 50}


def basemask(data, demo):
    from scipy import ndimage
    for c in CHARACTERS:
        base = base_full(c, 'skin1', demo)
        folder = out_dir(demo) / 'avatar_v2' / c
        if base is None:
            continue
        ex, ey = data['anchors'][c]['eyes']
        rx, ry = BASEMASK['face']
        ys, xs = np.mgrid[0:CANVAS[1], 0:CANVAS[0]]
        face = ((xs - ex) / rx) ** 2 + ((ys - ey) / ry) ** 2 <= 1
        for path in sorted(folder.glob('hair_*.png')):
            if path.stem.endswith(('_back', '_basemask')):
                continue
            hair = full(path, data, demo)[..., 3] > 0
            back = path.with_name(f'{path.stem}_back.png')
            if back.exists():
                hair |= full(back, data, demo)[..., 3] > 0
            hair = ndimage.binary_fill_holes(hair)
            # The forehead's skin stays (a short fringe shows it); skin of
            # the bare head beside the hair (temples above the ears) goes.
            keep = skin_pixels(c, demo) & (np.abs(xs - ex) <= BASEMASK['brow'])
            mask = (base[..., 3] > 0) & (ys < BASEMASK['above']) & ~face &                 ~hair & ~keep
            # One pixel wider (not into the face or kept skin): the game
            # draws the mask smoothed, which left a faint rim.
            mask |= ndimage.binary_dilation(mask) & (base[..., 3] > 0) &                 ~face & ~keep & ~hair
            mask |= ndimage.binary_dilation(mask, iterations=2) &                 (base[..., 3] == 0)
            out = np.zeros(base.shape, np.uint8)
            out[mask] = (0, 0, 0, 255)
            key = path.with_name(f'{path.stem}_basemask.png')
            save(out, key)
            print(f'basemask {key.relative_to(out_dir(demo)).as_posix()}: '
                  f'{int(mask.sum())} px')


# ---------------------------------------------------------------- hairmask

def hairmask(data, demo):
    from scipy import ndimage
    rules = data['hat_hair']
    for c in CHARACTERS:
        folder = out_dir(demo) / 'avatar_v2' / c
        for path in sorted(folder.glob('hat_*.png')):
            if path.stem.endswith('_hairmask'):
                continue
            hat_id = path.stem[len('hat_'):]
            rule = rules.get(hat_id, rules['default'])
            hat = full(path, data, demo)
            on = ndimage.binary_fill_holes(hat[..., 3] > 0)
            mask = ndimage.binary_dilation(on, iterations=2)
            if rule['mode'] == 'cover':
                cols = np.nonzero(on.any(0))[0]
                for x in cols:
                    low = np.nonzero(on[:, x])[0].max()
                    mask[:low + 1, x] = True
            for l, t, r, b in rule.get('keep', []):
                mask[t:b, l:r] = False
            out = np.zeros(hat.shape, np.uint8)
            out[mask] = (0, 0, 0, 255)
            key = path.with_name(f'{path.stem}_hairmask.png')
            save(out, key)
            print(f'hairmask {key.relative_to(out_dir(demo)).as_posix()}: '
                  f'{rule["mode"]}, {int(mask.sum())} px')


def full(path, data, demo):
    """[path] back on its full canvas (it may be trimmed already)."""
    img = np.array(Image.open(path).convert('RGBA'))
    if img.shape[:2] == (CANVAS[1], CANVAS[0]):
        return img
    key = path.relative_to(out_dir(demo)).as_posix()
    x, y = data.get('trim', {}).get(key, (0, 0))
    out = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
    out[y:y + img.shape[0], x:x + img.shape[1]] = img
    return out


# ---------------------------------------------------------------- face

def face(data, demo):
    """Frames are drawn on the skin1 base (the face boxes and skin test of
    tools/avatar_layers.py fit its light skin); skin2/3 get the same frames
    with their skin pixels recoloured by that base's own colour ratio (the
    bases differ only in skin)."""
    pivots = data.setdefault('pivots', {})
    for c in CHARACTERS:
        f = L.FACES[f'{c}_front']  # v2 keeps v1's anchors, so its boxes
        path = out_dir(demo) / f'avatar_v2/{c}/base@skin1.png'
        if not path.exists():
            continue
        a = full(path, data, demo).astype(np.int32)
        try:
            tone = L.median_skin(a, f['skin'])
        except ValueError:
            print(f'face {c}: no skin found in the face box')
            continue
        eyes_c = [p for _, p in f['eyes']]
        eye_mid = (sum(x for x, _ in eyes_c) / 2,
                   sum(y for _, y in eyes_c) / 2)
        made = {}
        for frame, (out, keep) in zip(('half', 'closed'),
                                      L.eye_frames(a, f['eyes'], tone)):
            made[f'eyes_{frame}'] = (L.cut(out, keep), eye_mid)
        for frame, (out, keep) in zip(('small', 'wide'),
                                      L.mouth_frames(a, f['mouth'], tone)):
            made[f'mouth_{frame}'] = (L.cut(out, keep), f['mouth'][1])
        one = a.astype(np.uint8)
        for skin in SKINS:
            other = base_full(c, skin, demo)
            if other is None:
                continue
            ratio = np.ones(3)
            if skin != 'skin1':
                changed = (one[..., 3] > 0) & (np.abs(
                    one[..., :3].astype(int) - other[..., :3]).sum(-1) > 30)
                if changed.any():
                    ratio = np.median(other[changed][:, :3].astype(float) /
                                      np.maximum(one[changed][:, :3], 1), 0)
            for part, ((arr, (l, t)), (ax, ay)) in made.items():
                part_arr = arr.astype(np.int32)
                where = (L.skinlike(part_arr) | L.skinish(part_arr)) &                     (part_arr[..., 3] > 0)
                out = L.recolour(part_arr, where, ratio)
                key = f'avatar_v2/{c}/face_{part}@{skin}.png'
                save(out, out_dir(demo) / key)
                pivots[key] = [ax - l, ay - t]
                print(f'face {key}: pivot ({ax - l}, {ay - t})')


# ---------------------------------------------------------------- icons

ICON = 64


def icons(data, src):
    folder = src / '31_icons'
    by_slot = {}
    for item, slot in definitions():
        if slot in ('character', 'skin') + ITEM_SLOTS and item not in BLANK:
            by_slot.setdefault(slot, []).append(item)
    done = data.setdefault('icons', {})
    for slot, ids in by_slot.items():
        missing = [i for i in ids if not (folder / f'{i}.png').exists()]
        if missing:
            done[slot] = f'대기 (없음: {", ".join(missing)})'
            continue
        for i in ids:
            arr = X.load_cut(folder / f'{i}.png')
            l, t, r, b = X.bbox(arr[..., 3])
            part = arr[t:b, l:r]
            k = (ICON - 4) / max(part.shape[:2])
            w, h = max(1, round(part.shape[1] * k)), max(1, round(part.shape[0] * k))
            small = X.area_sample(part, w, h)
            small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
            out = np.zeros((ICON, ICON, 4), np.uint8)
            out[(ICON - h) // 2:(ICON - h) // 2 + h,
                (ICON - w) // 2:(ICON - w) // 2 + w] = small
            save(out, IMAGES / 'cosmetic_icons' / f'{i}.png')
        done[slot] = '적용'
        print(f'icons {slot}: {len(ids)} applied')
    if (folder / 'none.png').exists() and all(
            v == '적용' for v in done.values()):
        arr = X.load_cut(folder / 'none.png')
        l, t, r, b = X.bbox(arr[..., 3])
        small = X.area_sample(arr[t:b, l:r], ICON - 4, ICON - 4)
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        out = np.zeros((ICON, ICON, 4), np.uint8)
        out[2:ICON - 2, 2:ICON - 2] = small
        save(out, IMAGES / 'cosmetic_icons' / 'none.png')


# ---------------------------------------------------------------- trim

def trim(data, demo):
    offsets = data.setdefault('trim', {})
    root = out_dir(demo)
    for path in sorted((root / 'avatar_v2').glob('*/*.png')):
        key = path.relative_to(root).as_posix()
        img = Image.open(path)
        if img.size != CANVAS:
            continue  # already trimmed (or a face part, cut to size)
        arr = np.array(img.convert('RGBA'))
        ys, xs = np.nonzero(arr[..., 3])
        if len(xs) == 0:
            continue
        l, t = max(xs.min() - L.PAD, 0), max(ys.min() - L.PAD, 0)
        r = min(xs.max() + 1 + L.PAD, CANVAS[0])
        b = min(ys.max() + 1 + L.PAD, CANVAS[1])
        save(arr[t:b, l:r], path)
        offsets[key] = [int(l), int(t)]


# ---------------------------------------------------------------- atlas

def shipped(demo=False):
    root = out_dir(demo)
    return sorted(p.relative_to(root).as_posix()
                  for p in (root / 'avatar_v2').glob('*/*.png'))


def atlas(data):
    files = shipped()
    ready = all(f in files for f in required())
    missing = [f for f in required() if f not in files]
    data['ready'] = ready
    data['missing'] = len(missing)

    def num(v):
        return f'{v:g}' if isinstance(v, float) and v != int(v) else f'{int(v)}'

    lines = [
        '// GENERATED by tools/avatar_v2.py from tools/avatar_v2.json.',
        '// Do not edit by hand: change the tool or the json and run it again.',
        '',
        '/// Every picture in assets/images/avatar_v2/ (26번 4-7단계).',
        'const avatarV2Files = <String>{',
        *[f"  '{f}'," for f in files],
        '};',
        '',
        '/// Whether every required v2 picture is there (avatarV2Required in',
        f'/// lib/avatar_v2.dart). {len(missing)} of {len(required())} missing.',
        f'const avatarV2Ready = {"true" if ready else "false"};',
        '',
        '/// Where each trimmed v2 picture sits on the 280x520 canvas.',
        'const avatarV2TrimOffsets = <String, (int, int)>{',
        *[f"  '{k}': ({x}, {y})," for k, (x, y) in sorted(data.get('trim', {}).items())
          if k in files],
        '};',
        '',
        '/// The point of each v2 face part that lands on its anchor.',
        'const avatarV2PartPivots = <String, (double, double)>{',
        *[f"  '{k}': ({num(float(x))}, {num(float(y))}),"
          for k, (x, y) in sorted(data.get('pivots', {}).items()) if k in files],
        '};',
        '',
        '/// Eye and mouth anchors of the v2 bases (the v1 rig points).',
        'const avatarV2FaceAnchors = <String, Map<String, (double, double)>>{',
    ]
    for c, parts in data['anchors'].items():
        inner = ', '.join(f"'{p}': ({num(float(x))}, {num(float(y))})"
                          for p, (x, y) in sorted(parts.items()))
        lines.append(f"  '{c}': {{{inner}}},")
    lines.append('};')
    DART.write_text('\n'.join(lines) + '\n', 'utf-8', newline='\n')
    if files:
        text = PUBSPEC.read_bytes().decode('utf-8')
        eol = '\r\n' if '\r\n' in text else '\n'  # keep the file's line ends
        text = text.replace('\r\n', '\n')
        if 'assets/images/avatar_v2/girl/' not in text:
            text = text.replace(
                '    - assets/images/avatar/boy/\n',
                '    - assets/images/avatar/boy/\n'
                '    # 26번 4-7단계: the vendor from a bare base (tools/avatar_v2.py).\n'
                '    - assets/images/avatar_v2/girl/\n'
                '    - assets/images/avatar_v2/boy/\n')
            PUBSPEC.write_bytes(text.replace('\n', eol).encode('utf-8'))
    print(f'atlas: {len(files)} files, ready={ready}, missing {len(missing)}')


# ---------------------------------------------------------------- G3

def half_widths(arr, eyes, mouth):
    """Per row from the cheeks to the chin: (row, left, right) half-widths
    of the face around the eyes' axis, measured on the skin region that
    holds the point between the nose and the mouth."""
    from scipy import ndimage
    skin = L.skinlike(arr) | L.skinish(arr)
    seed = (int(mouth[1]) - 8, int(mouth[0]))
    labels, _ = ndimage.label(ndimage.binary_closing(skin, iterations=2))
    lab = labels[seed]
    if lab == 0:
        return []
    face_ = ndimage.binary_fill_holes(labels == lab)
    rows = []
    for y in range(int(mouth[1]) + 8, int(mouth[1]) + 30):  # below the ears
        xs = np.nonzero(face_[y])[0]
        if len(xs) < 4:
            break
        rows.append((y, eyes[0] - xs.min(), xs.max() + 1 - eyes[0]))
    return rows


def faceaudit(data):
    from scipy import ndimage  # noqa: F401 (needed by half_widths)
    BUILD.mkdir(parents=True, exist_ok=True)
    sheet_dir = ROOT.parent / '3_original_images_and_visual_references' / \
        '3.2_visual_design_references_20261006' / '01_원본전체'
    concept = {'girl': ('여자꾸미기선택_원본_261006_1905_01.png', (615, 0, 895, 520)),
               'boy': ('남자꾸미기선택_원본_261006_1905_01.png', (620, 0, 900, 520))}
    v1_trim = json.loads(L.DATA.read_text('utf-8'))['trim']
    out, tiles = {}, []
    for c in CHARACTERS:
        eyes = data['anchors'][c]['eyes']
        mouth = data['anchors'][c]['mouth']
        cands = {'v1 asset': L.rgba(f'avatar/{c}/base.png', v1_trim)}
        if c in concept:
            name, box = concept[c]
            if (sheet_dir / name).exists():
                cands['concept sheet'] = np.array(Image.open(sheet_dir / name)
                                          .convert('RGBA').crop(box)).astype(np.int32)
        render = BUILD / f'render_{c}.png'
        if render.exists():
            img = Image.open(render).convert('RGBA')
            cands['game render'] = np.array(img.resize(CANVAS, Image.NEAREST)
                                       if img.size != CANVAS else img).astype(np.int32)
        for skin in SKINS:
            p = IMAGES / f'avatar_v2/{c}/base@{skin}.png'
            if p.exists():
                cands[f'v2 {skin}'] = full(p, data, False).astype(np.int32)
        for label, arr in cands.items():
            rows = half_widths(arr, eyes, mouth)
            if not rows:
                out[f'{c} {label}'] = None
                continue
            d = [r - l for _, l, r in rows]
            out[f'{c} {label}'] = {
                'rows': f'{rows[0][0]}~{rows[-1][0]}',
                'left_mean': round(float(np.mean([l for _, l, _ in rows])), 1),
                'right_mean': round(float(np.mean([r for _, _, r in rows])), 1),
                'diff_mean': round(float(np.mean(d)), 1),
                'diff_max': round(float(max(d, key=abs)), 1)}
            tile = Image.fromarray(arr.astype(np.uint8)).crop(
                (int(eyes[0]) - 90, int(eyes[1]) - 90,
                 int(eyes[0]) + 90, int(mouth[1]) + 50))
            bg = Image.new('RGBA', tile.size, (110, 140, 100, 255))
            bg.alpha_composite(tile)
            bg = bg.resize((bg.width * 3, bg.height * 3), Image.NEAREST)
            dr = ImageDraw.Draw(bg)
            ax = 90 * 3
            dr.line([(ax, 0), (ax, bg.height)], fill=(255, 43, 214, 255))
            for y, l, r in rows:
                yy = (y - int(eyes[1]) + 90) * 3 + 1
                dr.line([(ax - l * 3, yy), (ax - l * 3 + 2, yy)], fill=(0, 229, 255, 255))
                dr.line([(ax + r * 3 - 2, yy), (ax + r * 3, yy)], fill=(255, 235, 59, 255))
            stat = out[f'{c} {label}']
            dr.text((6, 6), f'{c} {label}', fill=(255, 255, 255, 255))
            dr.text((6, 20), f"L {stat['left_mean']} / R {stat['right_mean']} "
                    f"diff {stat['diff_mean']} (max {stat['diff_max']})",
                    fill=(255, 255, 255, 255))
            tiles.append(bg)
    if tiles:
        w = sum(t.width for t in tiles)
        sheet = Image.new('RGBA', (w, max(t.height for t in tiles)), (40, 30, 26, 255))
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.width
        sheet.save(BUILD / 'g3_face.png')
    (BUILD / 'g3_face.json').write_text(
        json.dumps(out, indent=1, ensure_ascii=False) + '\n', 'utf-8')
    for k, v in out.items():
        print(f'faceaudit {k}: {v}')
    data['faceaudit'] = out
    return out


# ---------------------------------------------------------------- demo

def demo_sources(dest):
    """4x stand-ins made from the v1 art, so the pipeline can be checked
    before the real pictures come. Never shipped: build/avatar_v2/demo/."""
    v1_trim = json.loads(L.DATA.read_text('utf-8'))['trim']

    def up(key):
        arr = L.rgba(key, v1_trim).astype(np.uint8)
        img = Image.fromarray(arr, 'RGBA').resize(
            (CANVAS[0] * SCALE, CANVAS[1] * SCALE), Image.NEAREST)
        return img

    for c in CHARACTERS:
        for skin, v1 in (('skin1', 'base.png'), ('skin2', 'base@skin2.png'),
                         ('skin3', 'base@skin3.png')):
            p = dest / '23_avatar_base' / c / f'base_{skin}.png'
            p.parent.mkdir(parents=True, exist_ok=True)
            up(f'avatar/{c}/{v1}').save(p)
        for slot, folder in FOLDERS.items():
            for src in sorted((IMAGES / 'avatar' / c).glob(f'{slot}_*.png')):
                if '@' in src.stem or src.stem.endswith('_cut'):
                    continue
                p = dest / folder / c / src.name
                p.parent.mkdir(parents=True, exist_ok=True)
                up(f'avatar/{c}/{src.name}').save(p)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    demo = '--demo' in sys.argv
    src = default_src()
    if '--src' in sys.argv:
        src = Path(sys.argv[sys.argv.index('--src') + 1])
        args = [a for a in args if Path(a) != src]
    data = load_data()
    report = src / '23_avatar_base' / 'normalized' / 'report.json'
    if report.exists():
        for c, m in json.loads(report.read_text('utf-8'))['characters'].items():
            raw = src / '23_avatar_base' / c / 'base_skin1.png'
            if raw.exists():
                RAW[c] = (m['scale'], m['dx'], m['dy'], Image.open(raw).size)
                a = np.array(Image.open(raw).convert('RGBA'))[..., 3] > 127
                RAW_SOLE[c] = int(np.nonzero(a.any(1))[0].max())
    if demo:
        import shutil
        shutil.rmtree(BUILD / 'demo', ignore_errors=True)
        src = BUILD / 'demo' / 'src'
        demo_sources(src)
        data = {k: v for k, v in data.items() if k in ('anchors', 'hat_hair')}
        jobs = ['align', 'items', 'hairmask', 'face', 'trim']
    else:
        jobs = args or ['align', 'items', 'bare', 'basemask', 'hairmask',
                        'face', 'icons', 'trim', 'atlas']
    if 'align' in jobs:
        align(data, src, demo)
    if 'items' in jobs:
        items(data, src, demo)
    if 'bare' in jobs:
        bare(data, demo)
    if 'basemask' in jobs:
        basemask(data, demo)
    if 'hairmask' in jobs:
        hairmask(data, demo)
    if 'face' in jobs:
        face(data, demo)
    if 'icons' in jobs and not demo:
        icons(data, src)
    if 'trim' in jobs:
        trim(data, demo)
    if 'faceaudit' in jobs:
        faceaudit(data)
    if demo:
        files = shipped(True)
        print(f'demo: {len(files)} files in build/avatar_v2/demo/images, '
              f'{sum(f in files for f in required())}/{len(required())} required')
        (BUILD / 'demo' / 'avatar_v2.json').write_text(
            json.dumps(data, indent=1, ensure_ascii=False) + '\n', 'utf-8')
        return
    if 'atlas' in jobs:
        atlas(data)
    DATA.write_text(json.dumps(data, indent=1, ensure_ascii=False) + '\n', 'utf-8')


if __name__ == '__main__':
    main()
