"""The vendor redrawn from a bare base (26번 4-7단계, 25번 문서 23~31번;
since 26번 3차 AV the 42번 bare base and the 43~49번 worn items).

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
  slim      <slot>_<id>_basemask.png for trousers and shoes: the sliver of
            leg beside a slim item, erased from the base (26번 3차 AV).
  skinned   tool_<id>_front@<skin>.png: the finger pieces per skin tone.
  pose      The share card's proud pose (25번 39번): pose_proud_arms@<skin>
            and pose_proud_hide (where the hanging arms were), and each
            top's sleeves on the raised arms pose_proud_sleeve_<top>
            (25번 50번 creamlong sleeve fitted by shape, cached in
            avatar_v2.json sleeve_fit, then coloured and cut like the
            standing v1 top's sleeves - 26번 3차 AV3b, sleeve_v1).
  face      Eye and mouth frames for each base (its own skin colour):
            face_<eyes_half|eyes_closed|mouth_small|mouth_wide>@<skin>.png.
  icons     31번 icons (512x512) -> assets/images/cosmetic_icons/<id>.png
            64x64, only for a slot whose icons are ALL there (no slot mixes
            drawn and temporary icons). Not hair and hats (wornicons).
  wornicons Runs with icons. The hair and hat icons are the worn layers
            themselves (no body), one scale per slot and character:
            cosmetic_icons/<id>.png (girl) and cosmetic_icons/boy/<id>.png.
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
# 26번 3차 AV (2026-11-20, DEC-145·147): the 42번 bare base (the v1 face
# and body, hair and clothes taken off) and the 43~49번 items drawn worn
# on it replace the 23번 base and 24~30번 items (kept in 4_image).
FOLDERS = {'hair': '43_hair_v1', 'hat': '44_hats_v1', 'top': '45_tops_v1',
           'bottom': '46_bottoms_v1', 'shoes': '47_shoes_v1',
           'outfit': '48_aprons_v1', 'accessory': '49_props_v1',
           'tool': '49_props_v1'}
# Items drawn in another 25번 section: id -> folder (41번 황금 뒤집개).
EXTRA_FOLDERS = {'goldtongs': '41_gold_turner'}
BASE_DIR = '42_v1_bare_base'
# Skin-coloured item halves (the fingers round a tool's handle): recoloured
# for skin2/3 like the face frames, as <name>@<skin>.png.
SKINNED_HALVES = ('_front',)
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


def withdrawn():
    """character -> withdrawn item ids (lib/cosmetic_config.dart
    withdrawnAvatarItems): not shown, so not required."""
    text = (ROOT / 'lib/cosmetic_config.dart').read_text('utf-8')
    block = re.search(r'withdrawnAvatarItems = <String, Set<String>>\{(.*?)\n\};',
                      text, re.S).group(1)
    return {c: set(re.findall(r"'(\w+)'", ids)) for c, ids in
            re.findall(r"^\s*'(\w+)':\s*\{([^}]*)\}", block, re.M)}


def required():
    """Every picture v2 needs: the six bases, then every item layer the
    wardrobe can show (the defaults too), girl and boy. Same list as
    lib/avatar_v2.dart avatarV2Required."""
    defs = definitions()
    held = withdrawn()
    out = []
    for c in CHARACTERS:
        out += [f'avatar_v2/{c}/base@{s}.png' for s in SHIPPED_SKINS]
        for item, slot in defs:
            if slot in ITEM_SLOTS and item not in BLANK and                     item not in held.get(c, ()):
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
STRETCHED = True  # 43~49번: see to_4x
# character/stem -> where the whole picture goes on the 1120x2080 canvas
# (l, t, r, b), for a picture that came at another size or position.
# The boy's sage sweater came at 949x1657, drawn at the same size as his
# other sweaters on a cropped canvas: placed by its centre on the pink one's.
STRETCH_FIX = {'boy/top_sagesweater': (-16, 179, 1192, 2108)}
# character/stem -> (dx, dy) on the 280x520 canvas after the base's shift:
# the boy's shorts and two trousers came with the waist ~5px below his
# sweaters' hem (a strip of belly showed); up to meet them.
ITEM_SHIFT = {'boy/bottom_shorts': (0, -6), 'boy/bottom_widepants': (0, -5),
              'boy/bottom_brownpants': (0, -5)}
RAW_SOLE = {}  # character -> last opaque row of the raw skin1 base
SOLE_SLOTS = ('shoes_',)


def to_4x(path, character):
    """[path] as a 4x RGBA array: as it is, or placed like its character's
    raw base (RAW); None when neither fits."""
    img = Image.open(path)
    want = (CANVAS[0] * SCALE, CANVAS[1] * SCALE)
    if img.size == want:
        return np.array(img.convert('RGBA'))
    if STRETCHED:
        # 26번 3차 AV: 43~49번 came at 880x1787 (some a few px off), drawn
        # on the 42번 normalized 1120x2080 base squeezed to that size, so
        # stretching back to 1120x2080 lays them on the base (checked by
        # overlay, avatar_v2.json 'items'). STRETCH_FIX moves the odd ones.
        fix = STRETCH_FIX.get(f'{character}/{path.stem}')
        if fix:
            l, t, r, b = fix
            canvas = Image.new('RGBA', want, (0, 0, 0, 0))
            part = img.convert('RGBa').resize((r - l, b - t), Image.LANCZOS)
            canvas.paste(part.convert('RGBA'), (l, t))
            return np.array(canvas)
        big = img.convert('RGBa').resize(want, Image.LANCZOS).convert('RGBA')
        return np.array(big)
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
    norm_dir = src / BASE_DIR / 'normalized'
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
                path = src / BASE_DIR / c / f'base_{skin}.png'
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
                if normalized and 'landmarks_280x520' in measured[c]:
                    # 26번 3차 AV: the 42번 base (soles on row 519) moves so
                    # its eyes sit on the v1 anchors: the vendor stands where
                    # the v1 vendor stood and the v1 face boxes fit.
                    mx, my = measured[c]['landmarks_280x520']['eyes']
                    ax, ay = data['anchors'][c]['eyes']
                    offset = (int(round(ax - mx)), int(round(ay - my)))
            arr = shift(arr, *offset)
            sole, fx, fy = landmarks(arr, c)
            # Left over after the shift: the soles decide the height, so a
            # face drawn higher or lower than v1's shows up in eyes_y.
            err = {'sole': sole - SOLE_ROW, 'eyes_x': fx, 'eyes_y': fy}
            if normalized and 'landmarks_280x520' in measured[c]:
                mx, my = measured[c]['landmarks_280x520']['eyes']
                ax, ay = data['anchors'][c]['eyes']
                err = {'sole': sole - SOLE_ROW,
                       'eyes_x': round(mx + offset[0] - ax, 2),
                       'eyes_y': round(my + offset[1] - ay, 2),
                       'v1_face_x': fx, 'v1_face_y': fy}
            elif normalized:  # its own eyes (4x error / 4), v1 match kept
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
        # 26번 3차 AV3: skin2·3 are not shipped (atlas moves them to
        # UNSHIPPED); the tool still reads skin3 to tell skin apart.
        kept = UNSHIPPED / f'avatar_v2/{c}/base@{skin}.png'
        if demo or not kept.exists():
            return None
        img = np.array(Image.open(kept).convert('RGBA'))
        if img.shape[:2] == (CANVAS[1], CANVAS[0]):
            return img
        x, y = load_data().get('trim', {}).get(
            f'avatar_v2/{c}/base@{skin}.png', (0, 0))
        out = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
        out[y:y + img.shape[0], x:x + img.shape[1]] = img
        return out
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


def defringe(arr, passes=2, lighter=45):
    """26번 3차 AV: the 43~49번 pictures keep a pale rim of the white
    background outside their dark outline. A rim pixel much lighter than
    the opaque pixels next to it (inside) goes."""
    from scipy import ndimage
    out = arr.copy()
    for _ in range(passes):
        a = out[..., 3] > 0
        rim = a & ndimage.binary_dilation(~a)
        lum = out[..., :3].astype(np.float64).mean(-1)
        inner = a & ~rim
        k = np.ones((3, 3))
        s = ndimage.convolve(np.where(inner, lum, 0), k, mode='constant')
        n = ndimage.convolve(inner.astype(np.float64), k, mode='constant')
        mean = np.where(n > 0, s / np.maximum(n, 1), lum)
        rgb = out[..., :3].astype(np.int32)
        pale = (rgb.max(-1) - rgb.min(-1)) < 60
        drop = rim & (n > 0) & (lum - mean > lighter) & pale
        out[drop, 3] = 0
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


# 26번 3차 AV: each 43~49번 picture came a few px off sideways (each its
# own: -3..-16 at game size; the stretch gets the height right). It is
# centred on the base by its own shape: 'sym' - its rows' midpoints on the
# base's (the base is symmetric), 'crown' - only its top rows on the base
# (hair and hats: a side part or a knot does not count), 'low' - its bottom
# rows, 'hand' - its finger piece
# on the base's hand, 'follow:<stem>' - moved like that picture (a pin
# drawn on that hair; the santa hat's tip and the ponytail's knot lean to
# one side), 'anchor' - ON_ANCHOR. Halves move with their main.
CENTER = {'hair': 'crown', 'hat': 'crown', 'top': 'sym', 'bottom': 'sym',
          'shoes': 'sym', 'outfit': 'sym', 'accessory': 'sym', 'tool': 'hand'}
CENTER_ITEM = {'hat_santa': 'follow:hat_beanie',
               'hair_ponytail': 'follow:hair_long', 'accessory_scarf': 'crown',
               'accessory_glasses': 'anchor',
               'accessory_ribbon': 'follow:hair_long',
               'accessory_fishpin': 'follow:hair_long'}
CENTER_ROWS = 16
HAND_ROWS = 22  # the fist's height on the base


def row_mids(alpha, rows):
    out = {}
    for y in rows:
        xs = np.nonzero(alpha[y])[0]
        if len(xs):
            out[y] = (xs.min() + xs.max()) / 2
    return out


def center_dx(arr, base, mode, front=None):
    """(dx, dy) that centres [arr] on [base] by [mode] (see CENTER)."""
    a = arr[..., 3] > 0
    b = base[..., 3] > 0
    rows = np.nonzero(a.any(1))[0]
    if not len(rows):
        return 0, 0
    if mode == 'hand':
        f = (front if front is not None else arr)[..., 3] > 0
        ys, xs = np.nonzero(f)
        if not len(xs):
            return 0, 0
        # The vendor's left hand (viewer's right): the lowest HAND_ROWS
        # rows of the arm hanging apart from the body (rows 280~420, the
        # outermost run right of the body) - the fist. The finger piece's box
        # centre goes on the fist's.
        mid = np.median(list(row_mids(b, range(220, 300)).values()))
        hx, hy = [], []
        for y in range(280, 420):
            xs_ = np.nonzero(b[y, int(mid):])[0] + int(mid)
            if not len(xs_):
                continue
            gaps = np.nonzero(np.diff(xs_) > 1)[0]
            if not len(gaps):
                continue  # the arm touches the body here
            seg = xs_[gaps[-1] + 1:]  # the outermost run: the arm
            if seg.min() > mid + 40:
                hx += list(seg)
                hy += [y] * len(seg)
        if not hx:
            return 0, 0
        hx, hy = np.array(hx), np.array(hy)
        low = hy >= hy.max() - HAND_ROWS
        hx, hy = hx[low], hy[low]
        return (int(round((hx.min() + hx.max()) / 2 - (xs.min() + xs.max()) / 2)),
                int(round((hy.min() + hy.max()) / 2 - (ys.min() + ys.max()) / 2)))
    if mode == 'crown':
        rows = [y for y in rows if b[y].any()][:CENTER_ROWS]
    elif mode == 'low':
        rows = [y for y in rows if b[y].any()][-CENTER_ROWS:]
    ia, ib = row_mids(a, rows), row_mids(b, rows)
    d = [ib[y] - ia[y] for y in ia if y in ib]
    return (int(round(float(np.median(d)))) if d else 0), 0


def items(data, src, demo):
    report = data.setdefault('items', {})
    moved = data.setdefault('centred', {})
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
            paths = sorted((src / folder / c).glob(f'{slot}_*.png'))
            for item, extra in EXTRA_FOLDERS.items():
                paths += sorted((src / extra / c).glob(f'{slot}_{item}*.png'))
            for path in paths:
                if path.stem[len(slot) + 1:] in BLANK:
                    continue  # drawn as nothing (the tongs, 3차 H8)
                key = f'avatar_v2/{c}/{path.name}'
                arr, why = shrink(path, c)
                if arr is None:
                    report[key] = {'state': f'규격 미달 {why}'}
                    print(f'items {key}: skipped, {why}')
                    continue
                arr = shift(arr, *shift_by)
                stem = path.stem
                main = re.sub(r'_(back|front)$', '', stem)
                mode = CENTER_ITEM.get(main, CENTER.get(slot, 'sym'))
                if main == stem and mode != 'anchor':
                    if mode.startswith('follow:'):
                        dxy = tuple(moved.get(f'{c}/{mode[7:]}', (0, 0)))
                    else:
                        front = None
                        fp = path.with_name(f'{stem}_front.png')
                        if mode == 'hand' and fp.exists():
                            front, _ = shrink(fp, c)
                            front = shift(front, *shift_by)
                        dxy = center_dx(arr, base, mode, front)
                    moved[f'{c}/{stem}'] = list(dxy)
                dxy = tuple(moved.get(f'{c}/{main}', (0, 0)))
                arr = shift(arr, *dxy)
                if f'{c}/{path.stem}' in ITEM_SHIFT:
                    arr = shift(arr, *ITEM_SHIFT[f'{c}/{path.stem}'])
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
                arr = defringe(arr)
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
                print(f'items {key}: {state}, centred {dxy}')


# ---------------------------------------------------------------- v1art

def v1art(data, src, demo):
    """26번 3차 AV3: hair and clothes from the v1 designs (tools/
    avatar_v1art.py), then the hats refitted over the fuller hair."""
    import avatar_v1art as A
    ex = A.Extract(sys.modules[__name__], data, demo)
    report = data.setdefault('v1art', {})
    for c in CHARACTERS:
        folder = out_dir(demo) / 'avatar_v2' / c
        if not (folder / 'base@skin1.png').exists():
            continue
        made = {}
        for slot, ids in A.V1_ART.items():
            for item in ids:
                if f'{slot}_{item}' in A.V1_SKIP.get(c, ()):
                    continue
                if slot == 'hair':
                    front, back = ex.hair(c, item)
                    made[f'hair_{item}.png'] = front
                    # Kept even when empty (the boy's short styles hang
                    # nowhere below the chin): avatarV2Required lists it.
                    made[f'hair_{item}_back.png'] = back
                else:
                    made[f'{slot}_{item}.png'] = ex.item(c, slot, item)
                    # The 43~49번 halves belong to the 43~49번 picture.
                    made[f'{slot}_{item}_back.png'] = None
                    made[f'{slot}_{item}_front.png'] = None
        # Every bottom's waist up to the hem of the shortest top (see
        # RAISE): no strip of belly between them.
        def hem(arr):
            a = arr[..., 3] > 0
            cols = np.nonzero(a.any(0))[0]
            mid = (cols.min() + cols.max()) // 2
            return min(int(np.nonzero(a[:, x])[0].max())
                       for x in range(mid - 8, mid + 9) if a[:, x].any())
        tops = [arr for n, arr in made.items()
                if n.startswith('top_') and arr is not None]
        waist = min(hem(t) for t in tops) - A.RAISE_OVERLAP
        for item in A.RAISE:
            name = f'bottom_{item}.png'
            if name not in made:
                if not (folder / name).exists():
                    continue
                made[name] = full(folder / name, data, demo)
            made[name] = A.raise_waist(made[name], waist)
        for item, hem in A.LENGTHEN.get(c, {}).items():
            name = f'bottom_{item}.png'
            if name not in made and (folder / name).exists():
                made[name] = full(folder / name, data, demo)
            if name in made:
                made[name] = A.lengthen(made[name], hem, ex.base(c)[0],
                                         A.CUFF_ROWS[item])
        for name, arr in made.items():
            path = folder / name
            key = path.relative_to(out_dir(demo)).as_posix()
            data.setdefault('trim', {}).pop(key, None)
            if arr is None:
                path.unlink(missing_ok=True)
                report.pop(key, None)
                continue
            save(arr, path)
            report[key] = {'pixels': int((arr[..., 3] > 0).sum())}
        print(f'v1art {c}: {sum(a is not None for a in made.values())} '
              f'layers from the v1 vendor')
    hatfit(data, src, demo)


def hat_geometry(alpha, band):
    """(centre x, pivot row) of a hat: the brim (lowest row of its middle)
    or, for a band hat, the row where it is widest (the muffs)."""
    cols = np.nonzero(alpha.any(0))[0]
    cx = (cols.min() + cols.max()) / 2
    if band:
        widths = [(np.ptp(np.nonzero(r)[0]) if r.any() else 0) for r in alpha]
        return cx, int(np.argmax(widths))
    mid = alpha[:, int(cx) - 15:int(cx) + 15]
    return cx, int(np.nonzero(mid.any(1))[0].max())


KNOT_FOLLOW = 0.7


def hatfit(data, src, demo):
    """26번 3차 AV3: the 43~49번 hats were drawn on the bare head and sat
    inside the v1 hair. Each is scaled at 4x about its brim's middle (a
    band hat about its muffs) so it is as wide as the default hair a few
    rows above the brim (avatar_v1art.HAT_FIT); the hairmask job then
    presses the hair under it."""
    import avatar_v1art as A
    fit = A.HAT_FIT
    report = data.setdefault('hat_fit', {})
    for c in CHARACTERS:
        folder = out_dir(demo) / 'avatar_v2' / c
        hair = folder / f'hair_{A.DEFAULT_HAIR[c]}.png'
        if not hair.exists():
            continue
        hal = full(hair, data, demo)[..., 3] > 0
        shift_by = tuple(data.get('align', {}).get(
            f'avatar_v2/{c}/base@skin1.png', {}).get('shift', (0, 0)))
        for path in sorted((src / FOLDERS['hat'] / c).glob('hat_*.png')):
            stem = path.stem
            main = re.sub(r'_(back|front)$', '', stem)
            hat_id = main[len('hat_'):]
            if hat_id in BLANK:
                continue
            cur = folder / f'{main}.png'
            if not cur.exists():
                continue  # (items makes it)
            band = hat_id in fit['band']
            dxy = tuple(data.get('centred', {}).get(f'{c}/{main}', (0, 0)))
            if main == stem:
                # Measured on the 43~49번 picture as placed (not on the
                # file, which may be scaled already).
                plain, _ = shrink(path, c)
                al = shift(shift(plain, *shift_by), *dxy)[..., 3] > 0
                cx, row = hat_geometry(al, band)
                # 26번 3차 AV3c: the place and size of the v1 hat of the
                # same id (avatar_v1art.fit_to_v1), not the hair's width.
                adj = A.FIT_ADJUST.get(f'{c}/{hat_id}', {})
                if 'set' in adj:  # the v1 hat could not be told from the hair
                    iou, (s, mx, my) = 0.0, adj['set']
                else:
                    target = A.v1_hat_mask(
                        c, hat_id, shift(shift(plain, *shift_by), *dxy))
                    iou, s, mx, my = A.fit_to_v1(al, target, (cx, row + 1))
                s = round(s + adj.get('scale', 0), 3)
                mx += adj.get('move', (0, 0))[0]
                my += adj.get('move', (0, 0))[1]
                report[f'{c}/{main}'] = {'scale': s,
                                         'pivot': [round(float(cx), 1), row],
                                         'move': [int(mx), int(my)],
                                         'iou': round(float(iou), 3)}
            entry = report.get(f'{c}/{main}')
            if not entry:
                continue
            s = entry['scale']
            px, py = entry['pivot']
            mx, my = entry.get('move', (0, 0))
            ox, oy = shift_by[0] + dxy[0], shift_by[1] + dxy[1]
            big = to_4x(path, c)
            if big is None:
                continue
            if big[..., 3].min() == 255:
                big = X.load_cut(path)
            # Pivot on the 4x canvas before the shifts; scaled premultiplied
            # so the edge has no dark halo.
            p4x, p4y = (px - ox) * SCALE, (py + 1 - oy) * SCALE
            img = Image.fromarray(big.astype(np.uint8), 'RGBA').convert('RGBa')
            w, h = img.size
            if main == stem:
                img = img.resize((round(w * s), round(h * s)), Image.LANCZOS)
                at = (round(p4x - p4x * s + mx * SCALE),
                      round(p4y - p4y * s + my * SCALE))
            else:
                # A knot behind the head keeps its size.
                ys_, xs_ = np.nonzero(big[..., 3] > 127)
                kx, ky = (xs_.min() + xs_.max()) / 2, ys_.min()
                # Sideways with the hat's edge, at the same height (beside
                # the ear, half behind the fuller hair).
                at = (round(KNOT_FOLLOW * (s - 1) * (kx - p4x) + mx * SCALE),
                      round(my * SCALE))
            canvas = Image.new('RGBa', (w, h), (0, 0, 0, 0))
            canvas.paste(img, at)
            arr = np.array(canvas.convert('RGBA'))
            small = X.area_sample(arr, *CANVAS)
            small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
            small = shift(shift(small.astype(np.uint8), *shift_by), *dxy)
            small = defringe(small)
            key = cur.with_name(f'{stem}.png')
            save(small, key)
            data.setdefault('trim', {}).pop(
                key.relative_to(out_dir(demo)).as_posix(), None)
            print(f'hatfit {c}/{stem}: x{s:.2f} about ({px}, {py}) '
                  f'moved ({mx}, {my})')


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
        'face': (95, 125, 215, 200),  # l, t, r, b: eye whites are grey too
        # 26번 3차 AV: the 42번 base has a bare head already (DEC-147); its
        # outline stays and the hair layer and basemask do the rest.
        'cap': False}


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
        if not BARE.get('cap', True):
            cap = np.zeros_like(cap)
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
            # 2026-11-24 사용자: the vendor wearing nothing shows the 42번
            # base's own light grey vest and shorts; dressed, the bare base
            # below (no underwear ever shows past the clothes). Kept on the
            # full canvas (no trim entry needed). Right only after 'align'
            # (the aligned base still wears the underwear).
            save(out, out_dir(demo) / f'avatar_v2/{c}/base_underwear@{s}.png')
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
BASEMASK = {'above': 138, 'face': (60, 48), 'brow': 50, 'forehead_row': 118}


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
            # 26번 3차 AV: only the front part counts - the back part is
            # drawn behind the base, so bare head over it would show.
            hair = full(path, data, demo)[..., 3] > 0
            # The forehead's skin stays (a short fringe shows it); skin of
            # the bare head beside the hair (temples above the ears) goes.
            # 26번 3차 AV: only inside the hair's outline (below); the old
            # forehead box kept bare head sticking out above a side part.
            keep = skin_pixels(c, demo) & (np.abs(xs - ex) <= BASEMASK['brow'])                 & (ys >= BASEMASK['forehead_row'])
            # Bare head inside the hair's outline (a temple between the
            # fringe and the cheek) stays: only what sticks out past the
            # hair - beside it in its row or above it in its column - goes.
            inside = np.zeros_like(hair)
            for y in np.nonzero(hair.any(1))[0]:
                xs_ = np.nonzero(hair[y])[0]
                inside[y, xs_.min():xs_.max() + 1] = True
            top = np.where(hair.any(0), hair.argmax(0), CANVAS[1])
            inside &= ys >= top[None, :]
            hair = ndimage.binary_fill_holes(hair) | inside
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


# ---------------------------------------------------------------- slim

# 26번 3차 AV: slim trousers and boots drawn a little narrower than the bare
# legs left a sliver of leg along their sides. <slot>_<id>_basemask.png
# erases from the base the leg pixels just outside such an item (within
# SLIM['reach'] px of it), below the hands (row SLIM['below']) only.
SLIM = {'slots': ('bottom', 'shoes'), 'reach': 3, 'below': 372}


def slim(data, demo):
    from scipy import ndimage
    for c in CHARACTERS:
        base = base_full(c, 'skin1', demo)
        folder = out_dir(demo) / 'avatar_v2' / c
        if base is None:
            continue
        b = base[..., 3] > 0
        for slot in SLIM['slots']:
            for path in sorted(folder.glob(f'{slot}_*.png')):
                if path.stem.endswith(('_basemask', '_back', '_front')) or                         '@' in path.stem:
                    continue
                on = ndimage.binary_fill_holes(full(path, data, demo)[..., 3] > 0)
                near = ndimage.binary_dilation(on, iterations=SLIM['reach'])
                mask = near & ~on & b
                mask[:SLIM['below']] = False
                rows = np.nonzero(on.any(1))[0]
                if not len(rows):
                    continue
                # Only beside the item, never below its hem (the ankles
                # under trousers, the feet under a skirt stay).
                mask[rows.max() + 1:] = False
                # Not between the legs: only pixels left of the item's
                # leftmost or right of its rightmost pixel in that row.
                for y in np.nonzero(mask.any(1))[0]:
                    xs = np.nonzero(on[y])[0]
                    if not len(xs):
                        mask[y] = False
                        continue
                    mask[y, xs.min():xs.max() + 1] = False
                key = path.with_name(f'{path.stem}_basemask.png')
                if not mask.any():
                    key.unlink(missing_ok=True)
                    continue
                out = np.zeros(base.shape, np.uint8)
                out[mask] = (0, 0, 0, 255)
                save(out, key)
                data.setdefault('trim', {}).pop(
                    key.relative_to(out_dir(demo)).as_posix(), None)
                print(f'slim {key.name}: {int(mask.sum())} px')


# ---------------------------------------------------------------- hairmask

def hairmask(data, demo):
    from scipy import ndimage
    rules = data['hat_hair']
    for c in CHARACTERS:
        folder = out_dir(demo) / 'avatar_v2' / c
        for path in sorted(folder.glob('hat_*.png')):
            if path.stem.endswith(('_hairmask', '_back', '_basemask')):
                continue  # a knot behind the body presses no hair
            hat_id = path.stem[len('hat_'):]
            rule = rules.get(hat_id, rules['default'])
            hat = full(path, data, demo)
            on = ndimage.binary_fill_holes(hat[..., 3] > 0)
            # 26번 3차 AV: no rim round the hat (its pale rim is gone,
            # defringe), so the hair meets it with no gap of bare head.
            mask = on.copy()
            if rule['mode'] == 'cover':
                # 26번 3차 AV: no rim below the hat's edge (the pale rim is
                # gone, defringe): hair meets the brim with no gap.
                mask = on.copy()
                cols = np.nonzero(on.any(0))[0]
                lows = {}
                for x in cols:
                    low = np.nonzero(on[:, x])[0].max()
                    lows[x] = low
                    mask[:low + 1, x] = True
                # 26번 3차 AV: beside the hat, hair above the hat's edge at
                # its nearest column goes too (no tufts floating over the
                # brim); hair hanging lower stays.
                flat = mask.copy()
                for x in range(CANVAS[0]):
                    if x in lows or not len(cols):
                        continue
                    near = cols[np.abs(cols - x).argmin()]
                    flat[:lows[near] - HAT_SIDE_KEEP, x] = True
                    drop = min(int(HAT_SIDE_SLOPE * abs(int(near) - x)),
                               HAT_SIDE_DROP)
                    mask[:lows[near] - HAT_SIDE_KEEP + drop, x] = True
            if rule['mode'] == 'cover':
                # The bare head the hat leaves showing above that same edge
                # (a hat a little smaller than the head) goes from the base.
                base = base_full(c, 'skin1', demo)
                ex, ey = data['anchors'][c]['eyes']
                rx, ry = BASEMASK['face']
                ys, xs = np.mgrid[0:CANVAS[1], 0:CANVAS[0]]
                face_ = ((xs - ex) / rx) ** 2 + ((ys - ey) / ry) ** 2 <= 1
                # (the flat cut: the sloped one would reach the ears)
                scalp = flat & ~on & (base[..., 3] > 0) & ~face_
                scalp |= ndimage.binary_dilation(scalp) & (base[..., 3] == 0)
                sm = np.zeros(hat.shape, np.uint8)
                sm[scalp] = (0, 0, 0, 255)
                save(sm, path.with_name(f'{path.stem}_basemask.png'))
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


# ---------------------------------------------------------------- skinned

def skin_ratio(c, skin, demo):
    """Median colour ratio skin<n> / skin1 over the base's skin pixels."""
    one, other = base_full(c, 'skin1', demo), base_full(c, skin, demo)
    if one is None or other is None or skin == 'skin1':
        return np.ones(3)
    changed = (one[..., 3] > 0) & (np.abs(
        one[..., :3].astype(int) - other[..., :3]).sum(-1) > 30)
    if not changed.any():
        return np.ones(3)
    return np.median(other[changed][:, :3].astype(float) /
                     np.maximum(one[changed][:, :3], 1), 0)


def skinned(data, demo):
    """26번 3차 AV: an item half drawn in skin (the fingers round a tool's
    handle, tool_<id>_front.png, skin1) gets a copy per skin tone,
    <name>@<skin>.png, recoloured like the face frames."""
    for c in CHARACTERS:
        folder = out_dir(demo) / 'avatar_v2' / c
        for path in sorted(folder.glob('*.png')):
            if '@' in path.stem or not path.stem.endswith(SKINNED_HALVES):
                continue
            arr = full(path, data, demo).astype(np.int32)
            where = (L.skinlike(arr) | L.skinish(arr)) & (arr[..., 3] > 0)
            for skin in SKINS:
                out = L.recolour(arr, where, skin_ratio(c, skin, demo))                     if skin != 'skin1' else arr
                key = path.with_name(f'{path.stem}@{skin}.png')
                save(out, key)
                data.setdefault('trim', {}).pop(
                    key.relative_to(out_dir(demo)).as_posix(), None)
            print(f'skinned {path.name}: {int(where.sum())} skin px')


# ---------------------------------------------------------------- pose

POSE_DIR = '39번_proud_pose'


def pose(data, src, demo):
    """26번 3차 AV (25번 39번): the share card's proud pose for the v2
    vendor. pose_proud_arms@<skin>.png = two raised bare arms and the
    bungeoppang (skin2/3 recoloured), pose_proud_hide.png = where the
    hanging arms were (opaque = erase), both on the base's canvas."""
    for c in CHARACTERS:
        shift_by = tuple(data.get('align', {}).get(
            f'avatar_v2/{c}/base@skin1.png', {}).get('shift', (0, 0)))
        folder = out_dir(demo) / 'avatar_v2' / c
        arms_src = src / POSE_DIR / c / 'pose_proud_arms.png'
        hide_src = src / POSE_DIR / c / 'pose_proud_hide.png'
        if not arms_src.exists() or not hide_src.exists():
            continue
        arms, _ = shrink(arms_src, c)
        arms = shift(arms, *shift_by)
        img = Image.open(hide_src).convert('RGBA')
        big = np.array(img.resize((CANVAS[0] * SCALE, CANVAS[1] * SCALE),
                                  Image.LANCZOS))
        on = (big[..., 3] > 128) & (big[..., :3].mean(-1) > 200)
        small = X.area_sample(np.dstack([np.zeros(on.shape + (3,), np.uint8),
                                         (on * 255).astype(np.uint8)]),
                              *CANVAS, min_cover=0.3)
        small = shift(small, *shift_by)
        # Both arms' mask is symmetric: centred on the base like the items
        # (center_dx 'sym'), the raised arms moved with it.
        dxy = center_dx(small, base_full(c, 'skin1', demo), 'sym')
        data.setdefault('centred', {})[f'{c}/pose_proud'] = list(dxy)
        mask = shift(small, *dxy)[..., 3] > 0
        # Where the hanging arm stands apart from the body, everything
        # outside the gap goes too: the generated mask missed the arm's
        # outline and a wide sleeve's edge in places.
        b = base_full(c, 'skin1', demo)[..., 3] > 0
        mid = int(np.median(list(row_mids(b, range(220, 300)).values())))
        for y in range(*POSE_ARM_ROWS):
            for sign in (-1, 1):
                xs_ = np.nonzero(b[y, mid:] if sign > 0 else b[y, :mid][::-1])[0]
                gaps = np.nonzero(np.diff(xs_) > 1)[0]
                if not len(gaps):
                    continue
                gap = xs_[gaps[-1]] + 1  # first empty pixel past the body
                if sign > 0:
                    mask[y, mid + gap + 1:] = True
                else:
                    mask[y, :mid - gap - 1] = True
        arms = shift(arms, *dxy).astype(np.int32)
        where = (L.skinlike(arms) | L.skinish(arms)) & (arms[..., 3] > 0)
        for skin in SKINS:
            out = L.recolour(arms, where, skin_ratio(c, skin, demo))                 if skin != 'skin1' else arms
            key = f'avatar_v2/{c}/pose_proud_arms@{skin}.png'
            save(out, out_dir(demo) / key)
            data.setdefault('trim', {}).pop(key, None)
        from scipy import ndimage
        mask = ndimage.binary_dilation(mask, iterations=POSE_HIDE_GROW)
        mask |= pose_remnants(c, mask, data, demo)
        out = np.zeros((CANVAS[1], CANVAS[0], 4), np.uint8)
        out[mask] = (0, 0, 0, 255)
        key = f'avatar_v2/{c}/pose_proud_hide.png'
        save(out, out_dir(demo) / key)
        data.setdefault('trim', {}).pop(key, None)
        print(f'pose {c}: arms {int((arms[..., 3] > 0).sum())} px, '
              f'hide {int(mask.sum())} px')
        sleeves(data, src, demo, c, shift_by, dxy)


def pose_remnants(c, mask, data, demo):
    """26번 3차 AV2: bits of the hanging arm's outline that the hide mask
    leaves of the base, a top, an apron or an accessory (a thin line beside
    the body, an arc over the shoulder): every small piece cut off from the
    rest of its layer, unless some layer has its main part there."""
    from scipy import ndimage
    folder = out_dir(demo) / 'avatar_v2' / c
    names = [folder / 'base@skin1.png'] + [
        p for slot in ('top', 'outfit', 'accessory')
        for p in sorted(folder.glob(f'{slot}_*.png'))
        if not re.search(r'_(basemask|hairmask|back|front)', p.stem)]
    small, main = np.zeros_like(mask), np.zeros_like(mask)
    for path in names:
        if not path.exists():
            continue
        seen = (full(path, data, demo)[..., 3] > 0) & ~mask
        lab, n = ndimage.label(seen)
        if not n:
            continue
        size = ndimage.sum(seen, lab, range(1, n + 1))
        big = np.nonzero(size >= POSE_REMNANT)[0] + 1
        main |= np.isin(lab, big)
        small |= seen & ~np.isin(lab, big)
    out = small & ~main
    # Below the chin the hanging sleeve's outer outline may still hang on
    # at the shoulder (a top drawn wider than the hidden base): everything
    # further than POSE_BAND_REACH beside the base's body in that row goes.
    base = (full(folder / 'base@skin1.png', data, demo)[..., 3] > 0) & ~mask
    lab, n = ndimage.label(base)
    if n:
        size = ndimage.sum(base, lab, range(1, n + 1))
        body = lab == (int(np.argmax(size)) + 1)
        for y in range(*POSE_BAND_ROWS):
            xs = np.nonzero(body[y])[0]
            if len(xs):
                out[y, :max(xs.min() - POSE_BAND_REACH, 0)] = True
                out[y, xs.max() + 1 + POSE_BAND_REACH:] = True
    print(f'pose {c}: remnants {int((out & ~mask).sum())} px')
    return out


POSE_REMNANT = 60  # a visible piece smaller than this is a remnant
POSE_BAND_ROWS = (216, 300)  # chin to elbow of the hanging arm
POSE_BAND_REACH = 14  # cloth may stand this far beside the hidden base


# 26번 3차 AV2 (25번 50번): the worn top's sleeves on the raised arms,
# pose_proud_sleeve_<top>.png. The sources came at another size than the
# arms (girl 880x1787, boy 971x1620; arms 920x1709) and each sleeve a bit
# off, so each of the two sleeves is fitted to its arm by shape (sleeve_fit)
# on the arms' 1120x2080 canvas, then shrunk and moved like the arms.
# Hand and bungeoppang per arm on that canvas (l, t, r, b): the sleeve may
# not lie there, and where it does the hand stays in front of the cuff.
SLEEVE_HANDS = {'girl': [(0, 0, 330, 1035), (810, 0, 1120, 1095)],
                'boy': [(0, 0, 320, 1010), (820, 0, 1120, 1090)]}
SLEEVE_SHOULDER = 40  # arm pixels this near the shoulder cut weigh more
SLEEVE_FILL = 48  # bare arm this near the cut is covered with the sleeve
SLEEVE_HEM = 6  # the cuff's hem line where the hand covers it
SLEEVE_HELD = {}  # 'character/top' -> why it is not shipped (25번 50번)


def _big(path):
    img = Image.open(path).convert('RGBa')
    return np.array(img.resize((CANVAS[0] * SCALE, CANVAS[1] * SCALE),
                               Image.LANCZOS).convert('RGBA'))


def _two(mask):
    """The two biggest pieces of [mask], left one first."""
    from scipy import ndimage
    lab, n = ndimage.label(mask)
    if n < 2:
        return []
    size = ndimage.sum(mask, lab, range(1, n + 1))
    out = [lab == i for i in np.argsort(size)[::-1][:2] + 1]
    return sorted(out, key=lambda m: np.nonzero(m)[1].mean())


def _sleeve_weights(arms_a, c):
    """Score map on the 4x canvas: +1 on the arm, more near the shoulder
    cut, 0 just around it and past the cut (into the body), -2 on the hand
    and bungeoppang, -1 further out."""
    from scipy import ndimage
    hand = np.zeros_like(arms_a)
    for l, t, r, b in SLEEVE_HANDS[c]:
        hand[t:b, l:r] = True
    near = ndimage.binary_dilation(arms_a, iterations=24)
    w = np.where(arms_a & ~hand, 1.0, np.where(arms_a & hand, -2.0,
                 np.where(near, 0.0, -1.0))).astype(np.float32)
    for side, arm in enumerate(_two(arms_a)):
        ys, xs = np.nonzero(arm)
        cut = xs.max() if side == 0 else xs.min()
        rows = ys[xs >= cut - 2] if side == 0 else ys[xs <= cut + 2]
        strip = arm.copy()
        if side == 0:
            strip[:, :cut - SLEEVE_SHOULDER] = False
            body = (slice(rows.min() - 30, rows.max() + 30), slice(cut, cut + 60))
        else:
            strip[:, cut + SLEEVE_SHOULDER:] = False
            body = (slice(rows.min() - 30, rows.max() + 30), slice(cut - 60, cut))
        w[strip] = 3.0
        w[body] = np.maximum(w[body], 0)
    return w, hand


def _search(weights, piece, scales, shifts, step, centre):
    """Best (score, sx, sy, dx, dy) of [piece] (bool crop) scaled and moved
    about [centre] on [weights] (already 1/step of the 4x canvas)."""
    best = None
    h0, w0 = piece.shape
    img = Image.fromarray((piece * 255).astype(np.uint8))
    H, W = weights.shape
    for sx, sy in scales:
        w, h = w0 * sx, h0 * sy
        k = np.array(img.resize((max(1, int(w / step)), max(1, int(h / step))),
                                Image.BILINEAR)) > 127
        kh, kw = k.shape
        for dx, dy in shifts:
            x0 = int((centre[0] + dx - w / 2) / step)
            y0 = int((centre[1] + dy - h / 2) / step)
            if x0 < 0 or y0 < 0 or x0 + kw > W or y0 + kh > H:
                continue
            v = float((weights[y0:y0 + kh, x0:x0 + kw] * k).sum())
            if best is None or v > best[0]:
                best = (v, sx, sy, dx, dy)
    return best


def sleeve_fit(arms_a, sleeve_a, c, size=None):
    """Where each of the two sleeves goes: [{box, to, scale}] (4x canvas,
    box in the stretched source, to on the arms' canvas). [size] fixes the
    (sx, sy) per side (short sleeves)."""
    weights, _ = _sleeve_weights(arms_a, c)
    fits = []
    for side, piece in enumerate(_two(sleeve_a)):
        ys, xs = np.nonzero(piece)
        l, t = int(xs.min()), int(ys.min())
        r, b = int(xs.max()) + 1, int(ys.max()) + 1
        crop = piece[t:b, l:r]
        centre = ((l + r) / 2, (t + b) / 2)
        if size:
            scales = [tuple(size[side])]
        else:
            scales = [(s * a, s / a) for s in np.arange(0.84, 1.20, 0.04)
                      for a in np.arange(0.92, 1.09, 0.04)]
        coarse = [(dx, dy) for dx in range(-64, 65, 8)
                  for dy in range(-64, 65, 8)]
        _, sx, sy, dx, dy = _search(weights[::4, ::4], crop, scales, coarse,
                                    4, centre)
        fine_s = [tuple(size[side])] if size else \
            [(sx * f, sy * g) for f in (0.98, 1.0, 1.02) for g in (0.98, 1.0, 1.02)]
        fine = [(dx + i, dy + j) for i in range(-8, 9, 2) for j in range(-8, 9, 2)]
        _, sx, sy, dx, dy = _search(weights[::2, ::2], crop, fine_s, fine, 2,
                                    centre)
        w, h = (r - l) * sx, (b - t) * sy
        to = [round(centre[0] + dx - w / 2), round(centre[1] + dy - h / 2)]
        to += [to[0] + round(w), to[1] + round(h)]
        fits.append({'box': [l, t, r, b], 'to': to,
                     'scale': [round(float(sx), 3), round(float(sy), 3)]})
    return fits


def sleeves(data, src, demo, c, shift_by, dxy):
    """26번 3차 AV3b: the tops are the v1 designs again (avatar_v1art.py),
    which the 25번 50번 sleeves (drawn for the 43~49번 tops) no longer match
    in colour, pattern or length. Every top's raised sleeves are now the
    plain SLEEVE_TEMPLATE sleeve (its shape and shading), coloured with the
    standing v1 top's own sleeve pixels and cut where the v1 sleeve ends
    along the arm (_v1_sleeve, _restyle)."""
    import hashlib
    from scipy import ndimage
    folder = src / POSE_DIR / c
    arms_a = _big(folder / 'pose_proud_arms.png')[..., 3] > 128
    _, hand = _sleeve_weights(arms_a, c)
    tops = [i for i, slot in definitions() if slot == 'top' and i not in BLANK]
    cache = data.setdefault('sleeve_fit', {})
    path = folder / f'pose_proud_sleeve_{SLEEVE_TEMPLATE}.png'
    big = _big(path)
    pieces = _two(big[..., 3] > 128)
    sha = hashlib.sha256(path.read_bytes()).hexdigest()[:16]
    entry = cache.get(f'{c}/{SLEEVE_TEMPLATE}')
    if not entry or entry.get('sha') != sha:
        entry = {'sha': sha, 'fits': sleeve_fit(arms_a, big[..., 3] > 128, c)}
    # Only the template's fit is used since AV3b.
    for k in [k for k in cache if k.startswith(f'{c}/')]:
        del cache[k]
    cache[f'{c}/{SLEEVE_TEMPLATE}'] = entry
    canvas = Image.new('RGBA', (CANVAS[0] * SCALE, CANVAS[1] * SCALE))
    for fit, piece in zip(entry['fits'], pieces):
        l, t, r, b = fit['box']
        part = big.copy()
        part[~ndimage.binary_dilation(piece, iterations=3)] = 0
        pl, pt, pr, pb = fit['to']
        img = Image.fromarray(part[t:b, l:r]).convert('RGBa')
        img = img.resize((pr - pl, pb - pt), Image.LANCZOS).convert('RGBA')
        canvas.alpha_composite(img, (pl, pt))
    arr = np.array(canvas)
    # The hand (and the bungeoppang) stays in front of the cuff, and the
    # cuff gets a hem line where it meets the hand (no flat cut).
    held = arms_a & hand
    hem = ndimage.binary_dilation(held, iterations=SLEEVE_HEM) & \
        ~held & (arr[..., 3] > 128)
    arr[hem, :3] = (arr[hem, :3] * 0.45).astype(np.uint8)
    arr[held] = 0
    # Bare arm left just inside the shoulder cut takes the nearest
    # sleeve colour, so no skin shows between the top and the sleeve.
    for side, arm in enumerate(_two(arms_a)):
        xs = np.nonzero(arm)[1]
        strip = arm.copy()
        if side == 0:
            strip[:, :xs.max() - SLEEVE_FILL] = False
        else:
            strip[:, xs.min() + SLEEVE_FILL:] = False
        solid = arr[..., 3] > 128
        gap = strip & ~solid
        if gap.any() and solid.any():
            _, (iy, ix) = ndimage.distance_transform_edt(
                ~solid, return_indices=True)
            arr[gap] = arr[iy[gap], ix[gap]]
    along, seg = _arm_param(c)
    report = data.setdefault('sleeve_v1', {})
    for top in tops:
        key = f'avatar_v2/{c}/pose_proud_sleeve_{top}.png'
        out_path = out_dir(demo) / key
        info = _v1_sleeve(c, top, data, demo)
        if info is None or f'{c}/{top}' in SLEEVE_HELD:
            out_path.unlink(missing_ok=True)
            data.setdefault('trim', {}).pop(key, None)
            report.pop(f'{c}/{top}', None)
            continue
        frac, outline, lut = info
        # Shoulder to elbow and elbow to wrist map separately (the raised
        # forearms are foreshortened): V1_ELBOW of the standing arm is its
        # elbow.
        cut = frac / V1_ELBOW if frac <= V1_ELBOW else             1 + (frac - V1_ELBOW) / (1 - V1_ELBOW)
        out = _restyle(arr, along, seg, cut, outline, lut)
        small = X.area_sample(out, *CANVAS)
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        small = small.astype(np.uint8)
        # Specks of the generated picture's soft edge.
        lab, n = ndimage.label(small[..., 3] > 0)
        if n:
            size = ndimage.sum(small[..., 3] > 0, lab, range(1, n + 1))
            small[np.isin(lab, np.nonzero(size < 6)[0] + 1)] = 0
        small = shift(shift(small, *shift_by), *dxy)
        save(small, out_path)
        data.setdefault('trim', {}).pop(key, None)
        report[f'{c}/{top}'] = {'length': round(float(frac), 3)}
        print(f'pose {c}: sleeve {top} {int((small[..., 3] > 0).sum())} px '
              f'length {frac:.2f} of the arm')


# 26번 3차 AV3b: the plain long sleeve every top's raised sleeves are made
# from (shape and shading; the cable-knit and ribbed 50번 sleeves would carry
# a pattern the v1 tops do not have).
SLEEVE_TEMPLATE = 'creamlong'
SLEEVE_BINS = 24  # luminance steps of the v1 sleeve's colours
SLEEVE_OUTLINE = 0.55  # darker than this x the median = the outline
SLEEVE_CUFF = 6  # the cut sleeve's hem line, px on the 4x canvas
V1_ELBOW = 0.62  # the standing elbow, of the way from shoulder top to wrist
# The raised arms' shoulder cut, elbow and wrist (centre of the arm, 4x
# canvas of pose_proud_arms.png, read off the 39번 picture), left arm first.
SLEEVE_JOINTS = {
    'girl': [((486, 1000), (330, 1160), (256, 1030)),
             ((704, 1010), (796, 1190), (840, 1070))],
    'boy': [((464, 964), (304, 1110), (240, 980)),
            ((696, 976), (804, 1170), (850, 1060))]}
SLEEVE_SEAM = 5  # dark pieces thicker than this x2 (4x px) are a seam, not outline
SLEEVE_SEAM_REACH = 0.5  # ... near the shoulder (_arm_param)
V1_COVER = 0.6  # a sleeve row covers this much of the hanging arm's width
V1_HAND_ROWS = 4  # the standing wrist: narrowest arm row this far above the hand


def _arm_param(c):
    """Where every pixel of the 4x canvas lies along the raised arm nearest
    to it (SLEEVE_JOINTS): 0 at the shoulder cut, 1 at the elbow, 2 at the
    wrist, and the length (px) of the segment it lies on."""
    H, W = CANVAS[1] * SCALE, CANVAS[0] * SCALE
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    best = np.full((H, W), np.inf, np.float32)
    param = np.zeros((H, W), np.float32)
    length = np.ones((H, W), np.float32)
    for joints in SLEEVE_JOINTS[c]:
        for k in range(2):
            (x0, y0), (x1, y1) = joints[k], joints[k + 1]
            vx, vy = x1 - x0, y1 - y0
            n = float(np.hypot(vx, vy))
            t = ((xx - x0) * vx + (yy - y0) * vy) / (n * n)
            tc = np.clip(t, 0, 1)
            d = np.hypot(xx - (x0 + tc * vx), yy - (y0 + tc * vy))
            near = d < best
            best[near] = d[near]
            # Before the shoulder or past the wrist the line goes on.
            param[near] = k + (t[near] if k == 0 else np.minimum(t[near], 1.5))
            length[near] = n
    return param, length


def _v1_sleeve(c, top, data, demo):
    """(length, outline colour, colour by luminance step) of the standing
    v1 top's sleeves: length = how far down the hanging arm (shoulder to
    wrist) the sleeve reaches, the shorter side; the colours are the top's
    own pixels over the hanging arms (the proud pose's hide mask)."""
    folder = out_dir(demo) / 'avatar_v2' / c
    path = folder / f'top_{top}.png'
    if not path.exists():
        return None
    base = full(folder / 'base@skin1.png', data, demo)[..., 3] > 0
    hide = full(folder / 'pose_proud_hide.png', data, demo)[..., 3] > 0
    top_a = full(path, data, demo)
    cloth = top_a[..., 3] > 0
    mid = int(np.median(list(row_mids(base, range(220, 300)).values())))
    fracs, bottoms = [], []
    for side in (0, 1):
        half = np.zeros_like(base)
        if side == 0:
            half[:, :mid] = True
        else:
            half[:, mid:] = True
        arm = base & hide & half
        rows = np.nonzero(arm.any(1))[0]
        shoulder, end = int(rows.min()), int(rows.max())
        # The wrist: the narrowest row above the hand's widest.
        widths = {y: int(arm[y].sum()) for y in
                  range((shoulder + end) // 2, end - V1_HAND_ROWS)}
        palm = max(widths, key=lambda y: (widths[y], -y))
        wrist = min((y for y in widths if y < palm),
                    key=lambda y: (widths[y], -y))
        last = None
        for y in range(shoulder, end):
            bx, tx = np.nonzero(base[y])[0], np.nonzero(cloth[y])[0]
            if not len(tx) or not len(bx):
                break
            runs = np.split(bx, np.nonzero(np.diff(bx) > 1)[0] + 1)
            if len(runs) >= 3:  # the arm hangs apart: cloth all round it
                run = runs[0] if side == 0 else runs[-1]
                ok = cloth[y, run].mean() >= V1_COVER
            else:
                ok = tx.min() <= bx.min() + 3 if side == 0 else                     tx.max() >= bx.max() - 3
            if ok:
                last = y
            elif last is not None and y - last > 3:
                break
        if last is None:
            return None
        fracs.append((last - shoulder) / max(wrist - shoulder, 1))
        bottoms.append(last)
    rows = np.zeros_like(base)
    rows[:max(bottoms) + 1] = True
    px = top_a[cloth & hide & rows][:, :3].astype(np.float32)
    lum = px @ np.array([0.299, 0.587, 0.114], np.float32)
    dark = lum < np.median(lum) * SLEEVE_OUTLINE
    outline = np.median(px[dark], 0) if dark.any() else px[np.argsort(lum)[0]]
    inner = px[~dark][np.argsort(lum[~dark])]
    lut = np.array([np.median(part, 0) for part in
                    np.array_split(inner, SLEEVE_BINS)])
    return min(fracs), outline, lut


def _restyle(arr, along, seg, cut, outline, lut):
    """[arr] (the template's raised sleeves, 4x) in the v1 colours, cut
    at [cut] along each arm (_arm_param) with a hem line."""
    out = arr.copy()
    solid = out[..., 3] > 0
    out[solid & (along > cut)] = 0
    solid = out[..., 3] > 0
    px = out[solid][:, :3].astype(np.float32)
    lum = px @ np.array([0.299, 0.587, 0.114], np.float32)
    dark = lum < np.median(lum) * SLEEVE_OUTLINE
    # The template's thick dark shoulder seam (a wedge over the shoulder,
    # not an outline) takes the cloth's shadow colour.
    from scipy import ndimage
    blob = np.zeros(solid.shape, bool)
    blob[solid] = dark
    blob = ndimage.binary_opening(blob, iterations=SLEEVE_SEAM) &         (along < SLEEVE_SEAM_REACH)
    dark &= ~blob[solid]
    colour = np.empty_like(px)
    colour[dark] = outline
    order = np.argsort(lum[~dark], kind='stable')
    step = np.empty(len(order), np.int64)
    step[order] = np.arange(len(order)) * SLEEVE_BINS // max(len(order), 1)
    colour[~dark] = lut[step]
    colour[blob[solid]] = lut[SLEEVE_BINS // 4]
    out[solid, :3] = np.clip(colour, 0, 255).astype(np.uint8)
    hem = solid & ((cut - along) * seg < SLEEVE_CUFF) & (along <= cut)
    out[hem, :3] = outline.astype(np.uint8)
    return out


# Hair beside a hat: rows this far above the hat's edge stay.
HAT_SIDE_KEEP = 0
# 26번 3차 AV3c: beside the hat the cut goes down this many rows per column
# away from the hat's edge (at most HAT_SIDE_DROP): the v1 hair wider than
# the hat flares out from under the brim instead of standing beside it in a
# flat-topped block.
HAT_SIDE_SLOPE = 0.9
HAT_SIDE_DROP = 22

# The hanging arms' mask grows this many pixels (sleeves are wider).
POSE_HIDE_GROW = 2
POSE_ARM_ROWS = (230, 430)  # rows where a hanging arm may stand apart


# ---------------------------------------------------------------- face

EYE_MARGIN = 2


def eye_box(a, box):
    """(box, centre) of the eye near the v1 [box] on base [a]."""
    from scipy import ndimage
    l, t, r, b = box
    feat = ~L.skinlike(a) & (a[..., 3] > 0)
    near = np.zeros_like(feat)
    near[t:b, l:r] = True
    lab, _ = ndimage.label(feat)
    # The blob with most pixels inside the box (not the outline, which
    # runs round the whole figure: only its pixels inside count).
    inside = lab[near & feat]
    ids, cnt = np.unique(inside[inside > 0], return_counts=True)
    if not len(ids):
        return box, ((l + r) // 2, (t + b) // 2)
    blob = (lab == ids[cnt.argmax()]) & near
    blob |= (lab == ids[cnt.argmax()]) & ndimage.binary_dilation(near, iterations=6)
    ys, xs = np.nonzero(blob)
    l, t = int(xs.min()) - EYE_MARGIN, int(ys.min()) - EYE_MARGIN
    r, b = int(xs.max()) + 1 + EYE_MARGIN, int(ys.max()) + 1 + EYE_MARGIN
    return (l, t, r, b), ((l + r) // 2, round(t + (b - t) * .55))


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
        # 26번 3차 AV: the 42번 base's eyes are a little larger than the v1
        # boxes (an edge of the eye white stayed under a blink): each box
        # is the eye itself - its largest non-skin blob near the v1 box -
        # plus a margin. The frames hang on the anchors (pivot = anchor).
        eyes = [eye_box(a, box) for box, _ in f['eyes']]
        made = {}
        eye_mid = tuple(data['anchors'][c]['eyes'])
        for frame, (out, keep) in zip(('half', 'closed'),
                                      L.eye_frames(a, eyes, tone)):
            made[f'eyes_{frame}'] = (L.cut(out, keep), eye_mid)
        for frame, (out, keep) in zip(('small', 'wide'),
                                      L.mouth_frames(a, f['mouth'], tone)):
            made[f'mouth_{frame}'] = (L.cut(out, keep),
                                      tuple(data['anchors'][c]['mouth']))
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


def icon_from(path, item):
    arr = X.load_cut(path)
    l, t, r, b = X.bbox(arr[..., 3])
    part = arr[t:b, l:r]
    k = (ICON - 4) / max(part.shape[:2])
    w, h = max(1, round(part.shape[1] * k)), max(1, round(part.shape[0] * k))
    small = X.area_sample(part, w, h)
    small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
    out = np.zeros((ICON, ICON, 4), np.uint8)
    out[(ICON - h) // 2:(ICON - h) // 2 + h,
        (ICON - w) // 2:(ICON - w) // 2 + w] = small
    save(out, IMAGES / 'cosmetic_icons' / f'{item}.png')


def icons(data, src):
    folder = src / '31_icons'
    by_slot = {}
    for item, slot in definitions():
        # 26번 3차 G: the 사장님 icons keep the v1 faces (the v1 vendor is
        # drawn), so 'character' is not made from 31_icons.
        if slot in ('skin',) + ITEM_SLOTS and item not in BLANK:
            by_slot.setdefault(slot, []).append(item)
    done = data.setdefault('icons', {})
    for slot, ids in by_slot.items():
        missing = [i for i in ids if not (folder / f'{i}.png').exists()]
        if missing:
            done[slot] = f'대기 (없음: {", ".join(missing)})'
            continue
        for i in ids:
            if slot in WORN_ICON_SLOTS:
                continue  # drawn from the worn layers (wornicons)
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
    # 26번 3차 AV: an item drawn in another 25번 section brings its own
    # icon (41번 황금 뒤집개: 41_gold_turner/icon_goldtongs.png).
    for i, extra in EXTRA_FOLDERS.items():
        path = src / extra / f'icon_{i}.png'
        if path.exists():
            icon_from(path, i)
            print(f'icons {i}: from {extra}')
    if (folder / 'none.png').exists() and all(
            v == '적용' for v in done.values()):
        arr = X.load_cut(folder / 'none.png')
        l, t, r, b = X.bbox(arr[..., 3])
        small = X.area_sample(arr[t:b, l:r], ICON - 4, ICON - 4)
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        out = np.zeros((ICON, ICON, 4), np.uint8)
        out[2:ICON - 2, 2:ICON - 2] = small
        save(out, IMAGES / 'cosmetic_icons' / 'none.png')


# ---------------------------------------------------------------- wornicons

# 26번 3차 AV3d (사용자 '헤어는 왜 스타일마다 크기가 달라?'): the hair and
# hat icons are the worn layers themselves (hair: back + front pieces;
# hat: the hat and its back knot), no body or head, on a clear ground, so
# they show the v1-derived hair and the refitted hats as worn and follow
# the art when it changes. One scale per slot and character (the slot's
# largest item fills the tile), each centred, so every hair style is drawn
# at the same size. The boy's hair and hats differ from the girl's:
# cosmetic_icons/boy/<id>.png. Every other slot keeps the 31번 object
# drawings (icons).
WORN_ICON_SLOTS = ('hair', 'hat')
ICON_PAD = 2  # empty pixels round the picture in the 64x64 icon
ICON_ALPHA = 110  # shrunk alpha from which a pixel is kept (opaque)
ICON_SPECK = 4  # opaque pieces smaller than this (px) are dropped
ICON_PINHOLE = 6  # holes this small (px) inside an icon are filled


def _over(dst, src):
    if src is None:
        return dst
    a = src[..., 3:4] / 255.0
    out = dst.astype(float)
    out[..., :3] = src[..., :3] * a + out[..., :3] * (1 - a)
    out[..., 3] = np.maximum(out[..., 3], src[..., 3])
    return out.astype(np.uint8)


def _item_alone(c, slot, item, data, demo):
    """[item]'s own pieces as worn (back, item, front), no body."""
    folder = out_dir(demo) / 'avatar_v2' / c

    def get(name):
        path = folder / name
        return full(path, data, demo) if path.exists() else None

    layer = get(f'{slot}_{item}.png')
    if layer is None:
        return None
    back = get(f'{slot}_{item}_back.png')
    if back is not None:
        # A back piece that does not touch the item (the cream bandana's
        # knot behind the neck) would float apart in the icon.
        from scipy import ndimage
        near = ndimage.binary_dilation(layer[..., 3] > 0, iterations=2)
        if not (near & (back[..., 3] > 0)).any():
            back = None
    out = _over(np.zeros(layer.shape, np.uint8), back)
    return _over(_over(out, layer), get(f'{slot}_{item}_front.png'))


def _shrink(arr, box, side):
    """The square of [side] canvas pixels centred on [box], shrunk into the
    64x64 icon: Lanczos on premultiplied colour (no dark or white fringe),
    then hard alpha and no specks."""
    from scipy import ndimage
    l, t, r, b = box
    x, y = round((l + r - side) / 2), round((t + b - side) / 2)
    pad = np.zeros((side, side, 4), np.uint8)
    sx0, sy0 = max(0, x), max(0, y)
    sx1, sy1 = min(CANVAS[0], x + side), min(CANVAS[1], y + side)
    pad[sy0 - y:sy1 - y, sx0 - x:sx1 - x] = arr[sy0:sy1, sx0:sx1]
    n = ICON - 2 * ICON_PAD
    img = Image.fromarray(pad, 'RGBA').convert('RGBa')
    small = np.array(img.resize((n, n), Image.LANCZOS).convert('RGBA'))
    on = small[..., 3] >= ICON_ALPHA
    # A smooth edge: 3x3 majority (no one-pixel notches or spikes), the
    # pinholes between strands filled; new pixels take the nearest colour.
    on = ndimage.median_filter(on.astype(np.uint8), size=3).astype(bool)
    holes = ndimage.binary_fill_holes(on) & ~on
    lab, k = ndimage.label(holes)
    sizes = ndimage.sum(holes, lab, range(1, k + 1))
    for i, size in enumerate(sizes, 1):
        if size <= ICON_PINHOLE:
            on[lab == i] = True
    solid = small[..., 3] >= ICON_ALPHA
    _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
    small[..., :3] = small[iy, ix, :3]
    lab, k = ndimage.label(on)
    sizes = ndimage.sum(on, lab, range(1, k + 1))
    for i, size in enumerate(sizes, 1):
        if size < ICON_SPECK:
            on[lab == i] = False
    small[..., 3] = np.where(on, 255, 0)
    small[~on, :3] = 0
    out = np.zeros((ICON, ICON, 4), np.uint8)
    out[ICON_PAD:ICON_PAD + n, ICON_PAD:ICON_PAD + n] = small
    return out


def wornicons(data, demo):
    """cosmetic_icons/<id>.png (the girl's, also what a caller without a
    character gets) and cosmetic_icons/boy/<id>.png for every item of
    WORN_ICON_SLOTS, from the shipped layers. Run again after the layers
    change."""
    by_slot = {}
    for item, slot in definitions():
        if slot in WORN_ICON_SLOTS and item not in BLANK:
            by_slot.setdefault(slot, []).append(item)
    report = data.setdefault('wornicons', {})
    report.clear()
    for c in CHARACTERS:
        dest = IMAGES / 'cosmetic_icons'
        if c != 'girl':
            dest = dest / c
        for slot, ids in by_slot.items():
            pics, boxes = {}, {}
            for i in ids:
                arr = _item_alone(c, slot, i, data, demo)
                if arr is not None and (arr[..., 3] > 0).any():
                    pics[i] = arr
                    boxes[i] = tuple(int(v) for v in X.bbox(arr[..., 3] > 0))
            if not pics:
                continue
            # One scale per slot: its largest item fills the tile.
            side = max(max(b[2] - b[0], b[3] - b[1]) for b in boxes.values())
            for i in pics:
                save(_shrink(pics[i], boxes[i], side), dest / f'{i}.png')
            report[f'{c}/{slot}'] = {'side': side, 'icons': len(pics)}
            print(f'wornicons {c} {slot}: {len(pics)} icons, side {side}')


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


# 26번 3차 AV3 (DEC-TBD-hAV3-2): only skin1 is in the game. The other
# tones' pictures the jobs still make (skin3 tells skin apart) are moved
# out of the assets to here by atlas.
SHIPPED_SKINS = ('skin1',)
UNSHIPPED = BUILD / 'unshipped'


def atlas(data):
    import shutil
    for path in sorted((IMAGES / 'avatar_v2').glob('*/*@*.png')):
        skin = path.stem.rsplit('@', 1)[1]
        if skin in SKINS and skin not in SHIPPED_SKINS:
            dest = UNSHIPPED / path.relative_to(IMAGES)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(dest))
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
        jobs = args or ['align', 'items', 'v1art', 'bare', 'basemask',
                        'hairmask',
                        'slim', 'skinned', 'pose', 'face', 'icons', 'trim',
                        'atlas']
    if 'align' in jobs:
        align(data, src, demo)
    if 'items' in jobs:
        items(data, src, demo)
    if 'v1art' in jobs and not demo:
        if 'items' not in jobs:  # it reads the 43~49번 shapes items makes
            items(data, src, demo)
        v1art(data, src, demo)
    if 'bare' in jobs:
        bare(data, demo)
    if 'basemask' in jobs:
        basemask(data, demo)
    if 'hatfit' in jobs and 'v1art' not in jobs:
        hatfit(data, src, demo)
    if 'hairmask' in jobs:
        hairmask(data, demo)
    if 'slim' in jobs:
        slim(data, demo)
    if 'skinned' in jobs:
        skinned(data, demo)
    if 'pose' in jobs:
        pose(data, src, demo)
    if 'face' in jobs:
        face(data, demo)
    if 'icons' in jobs and not demo:
        icons(data, src)
    if ('icons' in jobs or 'wornicons' in jobs) and not demo:
        wornicons(data, demo)
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
