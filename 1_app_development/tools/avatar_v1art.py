"""26번 3차 AV3: the v1 designs of hair and clothes laid on the v2 vendor.

The user (2026-11-20): "남자 여자 모두 헤어스타일이 다 이상해. 너무 머리에 딱
달라붙게 그렸어. 디자인 자체는 그 전 디자인이 훨 나아" and "옷도 너무 딱
달라붙어있어서 전 옷 디자인들이 훨씬 나아". The 42번 bare base is the v1 face
and body (the outlines match the v1 base pixel for pixel at the same place,
checked by overlay), so the v1 pictures need no move or scale: each v1 item
is taken from the v1 vendor as the game drew it (base, `_cut`, layers -
tools/avatar_layers.py) and only its own pixels are kept:

- hair: the v1 hair (the long style is painted into the v1 base) minus what
  the v2 base already shows there (face, ears, outlines: same colour), the
  eye and mouth boxes, skin and pale ear strokes; the v1 ear rim where the
  v2 base has nothing becomes hair. Rows from HAIR_CUT down go to the back
  half (`hair_<id>_back.png`, behind the body), the rest is the front.
- clothes and the hair accessories: the pixels where the v1 vendor wearing
  the item differs from the v1 vendor wearing the default of that slot
  (holes closed), plus the default garment painted into the v1 base (tee,
  shorts, flats) - kept to near the 43~49번 picture of the same item
  (V1_GROW px), minus skin (the v1 skin copies' changed pixels, without the
  v1 recolouring slips inside cloth), the v1 hair, the hands and thin strays.

Nothing here is per skin tone: skin is never kept, the v2 base shows its own.
Called from tools/avatar_v2.py `v1art` (after `items`, which it reads for
the 43~49번 shapes)."""
import json

import numpy as np
from PIL import Image
from scipy import ndimage

import avatar_layers as L

# Items drawn from the v1 vendor (the rest keep their 43~49번 picture).
# Kept 43~49번: the hats (the same designs, refitted over the hair volume by
# HAT_FIT), glasses (the v1 lenses are filled white and hide the eyes),
# crossbag (the v1 bag is a flap at the hand without its strap), the ribbon
# and mittens (see V1_ART), the tools
# (hands holding them, 26번 3차 AV) and the six bottoms v1 never had.
V1_ART = {
    'hair': ('long', 'short', 'ponytail', 'curly'),
    'top': ('tee', 'creamlong', 'pinksweater', 'sagesweater', 'creamsweater',
            'cardigan', 'padding', 'chefcoat'),
    'bottom': ('shorts', 'skirt', 'widepants', 'brownpants'),
    'shoes': ('flats', 'sneakers', 'boots', 'furboots'),
    'outfit': ('apron', 'darkapron', 'creamapron', 'stripe', 'waistapron'),
    # ribbon, mittens: the v1 bow sits in the v1 hair and the v1 mittens on
    # the v1 hands - too little of either is left apart from them.
    'accessory': ('fishpin', 'scarf'),
}
# The v1 vendor's look while one slot changes (the apron off, so a top or a
# bottom shows whole).
# Ids whose v1 picture is another garment: the v1 boy's 'skirt' is cream
# shorts (the 43~49번 pleated skirt matches its name and icon) - kept.
V1_SKIP = {'boy': {'bottom_skirt'}}
# The bottoms' waists sit lower than the shortest v1 top's hem (the v1 tops
# are short and the 43~49번 bottoms were drawn for the longer 43~49번 tops):
# a strip of belly showed. Each waistband moves up to RAISE_OVERLAP rows
# above that hem (RAISE_BAND rows kept whole, the cloth below stretched).
RAISE = ('shorts', 'skirt', 'widepants', 'brownpants', 'jeans',
         'denimshorts', 'joggers', 'checkskirt', 'cargopants', 'longskirt')
RAISE_OVERLAP = 3
RAISE_BAND = 10
V1_DEFAULT = {'hair': 'long', 'top': 'tee', 'bottom': 'shorts',
              'shoes': 'flats', 'outfit': 'noapron', 'hat': 'nohat',
              'accessory': 'noacc', 'tool': 'tongs'}
V1_ORDER = ('bottom', 'shoes', 'top', 'outfit', 'hat', 'accessory', 'tool')
HAIR_CUT = {'girl': 204, 'boy': 206}  # the chin: front hair above, back below
V1_GROW = {'top': 10, 'bottom': 8, 'shoes': 6, 'outfit': 6, 'accessory': 14}
# Wardrobe icons made from the worn v1 layer (avatar_v2.py v1icons): the
# 31번 icons of these show the 43~49번 design, which no longer matches.
V1_ICONS = ('creamlong', 'pinksweater', 'sagesweater', 'creamsweater',
            'cardigan', 'padding', 'chefcoat', 'brownpants', 'flats',
            'stripe', 'waistapron')
HOLES = {'bottom': 600, 'outfit': 200, 'top': 120}  # largest hole filled, px
CHANGED = 25  # RGB distance from the default look that makes an item pixel
SAME = 40     # RGB distance to the v2 base pixel that is the same drawing
K3 = np.ones((3, 3))

# The 43~49번 hats were drawn on the bare head; over the v1 hair they sat
# inside it. Each is scaled (at 4x, about its brim's middle) so its width a
# few rows above the brim is the character's default hair width there.
HAT_FIT = {'rows_above_brim': 6, 'extra': 0.02, 'min': 1.15, 'max': 1.42,
           # earmuffs: the band over the hair, the muffs on the ears
           'band': {'earmuffs'}}
DEFAULT_HAIR = {'girl': 'long', 'boy': 'short'}


class V1:
    """The v1 vendor's pictures on the 280x520 canvas."""

    def __init__(self):
        self.trim = json.loads(L.DATA.read_text('utf-8'))['trim']

    def get(self, rel):
        if not (L.IMAGES / rel).exists():
            return None
        return L.rgba(rel, self.trim).astype(np.int32)

    def skinned(self, rel, skin):
        if skin != 'skin1':
            r = rel.replace('.png', f'@{skin}.png')
            if (L.IMAGES / r).exists():
                return self.get(r)
        return self.get(rel)

    def look(self, c, skin, eq):
        """The v1 vendor as the game drew it (AvatarRig without v2): base
        with every worn item's `_cut`, the hair layer, then the items."""
        eq = {**V1_DEFAULT, **eq}
        base = self.skinned(f'avatar/{c}/base.png', skin)
        for slot, item in eq.items():
            cut = self.get(f'avatar/{c}/{slot}_{item}_cut.png')
            if cut is not None:
                base[cut[..., 3] > 0, 3] = 0
        out = np.zeros_like(base)
        for slot, item in eq.items():
            out = over(out, self.skinned(f'avatar/{c}/{slot}_{item}_back.png', skin))
        out = over(out, base)
        out = over(out, self.skinned(f'avatar/{c}/hair_{eq["hair"]}.png', skin))
        for slot in V1_ORDER:
            out = over(out, self.skinned(f'avatar/{c}/{slot}_{eq[slot]}.png', skin))
        return out


def over(dst, src):
    if src is None:
        return dst
    a = src[..., 3:4] / 255.0
    out = dst.astype(np.float64).copy()
    out[..., :3] = src[..., :3] * a + out[..., :3] * (1 - a)
    out[..., 3] = np.maximum(out[..., 3], src[..., 3])
    return out.astype(np.int32)


def dist(a, b):
    return np.sqrt(((a[..., :3].astype(np.int64) - b[..., :3]) ** 2).sum(-1))


def lum(a):
    return a[..., :3].astype(np.int64).mean(-1)


def closefill(m, it):
    return ndimage.binary_fill_holes(ndimage.binary_closing(m, iterations=it) | m)


def changed_by_skin(one, three):
    """Pixels the skin3 copy recoloured: skin (and the v1 recolouring's
    slips, see skin_v1)."""
    return (one[..., 3] > 0) & (np.abs(one[..., :3] - three[..., :3]).sum(-1) > 30)


def skin_v1(one, three):
    """The v1 skin: what its skin3 copy changed, without the small patches
    inside cloth the v1 recolouring took for skin (cream trousers)."""
    s = changed_by_skin(one, three)
    op = one[..., 3] > 0
    lab, _ = ndimage.label(s, K3)
    out = s.copy()
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        y0, y1 = max(sl[0].start - 2, 0), sl[0].stop + 2
        x0, x1 = max(sl[1].start - 2, 0), sl[1].stop + 2
        m = lab[y0:y1, x0:x1] == k
        ring = ndimage.binary_dilation(m, iterations=2) & ~m
        cloth = op[y0:y1, x0:x1] & ~s[y0:y1, x0:x1]
        if ring.sum() and (cloth & ring).sum() / ring.sum() >= .8 and m.sum() < 400:
            out[y0:y1, x0:x1][m] = False
    return out


def hairlike(a):
    rgb = a[..., :3].astype(np.int64)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return (r < 190) & (r - b > 35) & (rgb.mean(-1) < 130) & (r >= g) & (g >= b - 5)


def hands_of(base):
    """The hands and forearms hanging apart from the body (rows 300~420)."""
    al = base[..., 3] > 0
    m = np.zeros_like(al)
    for y in range(300, 420):
        xs = np.nonzero(al[y])[0]
        if not len(xs):
            continue
        gaps = np.nonzero(np.diff(xs) > 1)[0]
        if len(gaps) >= 2:
            m[y, xs[0]:xs[gaps[0]] + 1] = True
            m[y, xs[gaps[-1] + 1]:xs[-1] + 1] = True
    return m


class Extract:
    def __init__(self, V, data, demo=False):
        self.V, self.data, self.demo = V, data, demo
        self.v1 = V1()
        self._base = {}
        self._hair_region = {}
        self._defaults = {}

    def v2(self, c, name):
        path = self.V.out_dir(self.demo) / 'avatar_v2' / c / name
        return self.V.full(path, self.data, self.demo).astype(np.int32) \
            if path.exists() else None

    def base(self, c):
        if c not in self._base:
            one, three = self.v2(c, 'base@skin1.png'), self.v2(c, 'base@skin3.png')
            self._base[c] = (one, changed_by_skin(one, three))
        return self._base[c]

    # -------------------------------------------------------------- hair

    def hair_pixels(self, c, a1, region):
        """The v1 hair in [a1] (skin1) inside [region], cleaned."""
        b, bs = self.base(c)
        bal = b[..., 3] > 0
        ys = np.arange(a1.shape[0])[:, None]
        cut = HAIR_CUT[c]
        rgb = a1[..., :3]
        cand = region & (a1[..., 3] > 0) & ~(bal & (dist(a1, b) < SAME))
        l, t, r, bb = L.face_box(c, 1)
        f = L.FACES[f'{c}_front']
        cand[max(b_[3] for b_, _ in f['eyes']):cut, l + 12:r - 12] = False
        # The eyes (blink frames go under the hair): a strand may lie over
        # the skin of an eye box as in v1, never over the eye itself; the
        # mouth box stays clear.
        for (el, et, er, eb), _ in f['eyes']:
            box = np.zeros_like(cand)
            box[et:eb, el:er] = True
            cand &= ~(box & ~bs)
        ml, mt, mr, mb = f['mouth'][0]
        cand[mt - 2:mb + 2, ml - 2:mr + 2] = False
        cand &= ~(rgb[..., 0] >= 200)       # skin, blush, pale ear strokes
        ex, ey = self.data['anchors'][c]['eyes']
        # The v2 ears: the head's pixels beside its temples' width.
        xs_ = np.nonzero(bal[int(ey) - 28])[0]
        cols = np.arange(a1.shape[1])[None, :]
        ear = (ys > ey - 22) & (ys < ey + 30) & \
            ((cols < xs_.min() - 1) | (cols > xs_.max() + 1))
        # Never over the v2 ears (the v1 ear strokes stood a pixel apart).
        cand &= ~(ear & ndimage.binary_dilation(bal & ear & bs, iterations=4))
        cand &= ~(ear & ((rgb[..., 0] - rgb[..., 1]) > 85))
        # The v1 brows and lashes beside the v2 ones (a style drawn with its
        # own brows): nothing dark round the v2 brows, lashes and eyes.
        for (el, et, er, eb), _ in f['eyes']:
            zone = np.zeros_like(cand)
            zone[et - 24:eb + 4, el - 10:er + 10] = True
            feature = zone & bal & ~bs & (lum(b) < 150)
            cand &= ~((lum(a1) < 80) & zone &
                      ndimage.binary_dilation(feature, iterations=2))
        # The v1 pictures' white and grey specks round the hair.
        sat = rgb.max(-1) - rgb.min(-1)
        cand &= ~((rgb.mean(-1) > 140) & (sat < 45)) & \
            ~((rgb.mean(-1) > 55) & (sat < 25))
        cand &= ~((ys >= cut) & bal) & ~((ys >= cut) & (lum(a1) > 170))
        dark = lum(a1) < 62
        fab = cand & ~dark
        fab = np.where(ys >= cut, ndimage.binary_opening(fab), fab)
        near = ndimage.convolve(fab.astype(int), K3, mode='constant')
        # Dark: the hair's own outlines and its darkest locks (a mass that
        # survives an opening), not the v1 face's thin outline on v2 skin.
        keep = fab | (cand & dark & ndimage.binary_dilation(fab, iterations=2)
                      & ~(bs & (near < 5))) | ndimage.binary_opening(cand & dark)
        # Brow strokes of the v1 face that are not the v2 brows: pieces in
        # the band over each eye box that no fringe strand comes down into.
        # Brow and lash strokes of the v1 face round each eye: small dark
        # pieces there (a fringe strand is mid-brown and comes from above).
        for (l, t, r, bb), _ in L.FACES[f'{c}_front']['eyes']:
            z = keep[t - 24:bb + 4, l - 12:r + 12]
            zl = lum(a1[t - 24:bb + 4, l - 12:r + 12])
            lab, n = ndimage.label(z, K3)
            for k in range(1, n + 1):
                m = lab == k
                if zl[m].mean() < 75 and (m.sum() < 60 or not m[0].any()):
                    z[m] = False
        # Below the chin only locks, not the v1 body's thin outlines.
        thick = ndimage.binary_dilation(ndimage.binary_opening(keep, K3), K3)
        keep &= (ys < cut) | thick
        lab, n = ndimage.label(keep & (ys >= cut), K3)
        if n:  # and no small pieces there (v1 arm outlines)
            sizes = ndimage.sum(keep, lab, range(1, n + 1))
            keep &= ~np.isin(lab, 1 + np.nonzero(sizes < 150)[0])
        lab, n = ndimage.label(keep, K3)
        if n:
            sizes = ndimage.sum(keep, lab, range(1, n + 1))
            keep = np.isin(lab, 1 + np.nonzero(sizes >= 40)[0])
        return keep

    def hair_region(self, c):
        """The long hair painted into the v1 base."""
        if c not in self._hair_region:
            a1 = self.v1.get(f'avatar/{c}/base.png')
            a3 = self.v1.get(f'avatar/{c}/base@skin3.png')
            b, _ = self.base(c)
            ys = np.arange(a1.shape[0])[:, None]
            region = (a1[..., 3] > 0) & ~changed_by_skin(a1, a3) & (ys < 400)
            region &= ~ndimage.binary_dilation(
                (b[..., 3] > 0) & (ys >= HAIR_CUT[c]))
            self._hair_region[c] = self.hair_pixels(c, a1, region)
        return self._hair_region[c]

    def hair(self, c, item):
        """(front, back) of the v1 hair style [item]."""
        a1 = self.v1.look(c, 'skin1', {'hair': item})
        region = self.hair_region(c).copy()
        cut = self.v1.get(f'avatar/{c}/hair_{item}_cut.png')
        if cut is not None:
            region &= ~(cut[..., 3] > 0)
        lay = self.v1.get(f'avatar/{c}/hair_{item}.png')
        if lay is not None:
            region |= closefill(lay[..., 3] > 0, 2)
        keep = self.hair_pixels(c, a1, region)
        out = a1.astype(np.uint8).copy()
        out[~keep, 3] = 0
        out = self.fill_rim(c, out, a1)
        out = self.V.defringe(self.V.despeck(out))
        rows = np.arange(out.shape[0])[:, None]
        front, back = out.copy(), out.copy()
        front[(rows >= HAIR_CUT[c]).repeat(out.shape[1], 1), 3] = 0
        back[(rows < HAIR_CUT[c]).repeat(out.shape[1], 1), 3] = 0
        return front, back

    def fill_rim(self, c, out, a1):
        """v1 pixels left out as skin where the v2 base has nothing (the v1
        ears stand a pixel or two wider): hair from the nearest kept pixel,
        so no gap opens between the hair and the head."""
        b, _ = self.base(c)
        ys = np.arange(out.shape[0])[:, None]
        k = out[..., 3] > 0
        hole = (a1[..., 3] > 0) & ~k & (b[..., 3] == 0) & (ys < HAIR_CUT[c])
        hole &= ndimage.binary_dilation(k, iterations=5)
        # Closed holes in the hair where the v1 ear showed through and the
        # v2 head has nothing (the v2 ear sits further in).
        hole |= ndimage.binary_fill_holes(k) & ~k & (b[..., 3] == 0) &             (ys < HAIR_CUT[c])
        # The v1 ear's red strokes left round the v2 ear take hair colour too.
        rgb = out[..., :3].astype(np.int64)
        ex, ey = self.data['anchors'][c]['eyes']
        red = k & ((rgb[..., 0] - rgb[..., 1]) > 60) & (rgb[..., 0] > 100) &             (b[..., 3] == 0) & \
            (ys > ey - 35) & (ys < ey + 35)
        # and its pale tan rim (light, little red over blue: not hair).
        light = rgb.mean(-1) > 110
        red |= k & light & ((rgb[..., 0] - rgb[..., 2]) < 70) &             (b[..., 3] == 0) & (ys > ey - 35) & (ys < ey + 35)
        src = k & ~red
        hole |= red
        if hole.any() and src.any():
            _, (iy, ix) = ndimage.distance_transform_edt(~src, return_indices=True)
            out[hole] = out[iy[hole], ix[hole]]
        return out

    # ----------------------------------------------------------- clothes

    def defaults(self, c):
        """The tee, shorts and flats painted into the v1 base."""
        if c in self._defaults:
            return self._defaults[c]
        a1 = self.v1.get(f'avatar/{c}/base.png')
        a3 = self.v1.get(f'avatar/{c}/base@skin3.png')
        hair = self.hair_region(c)
        ys = np.arange(a1.shape[0])[:, None]
        cloth = (a1[..., 3] > 0) & ~skin_v1(a1, a3) & ~hair & \
            (ys >= HAIR_CUT[c] - 4)

        def near(name, k):
            m = self.v2(c, name)
            return ndimage.binary_dilation(m[..., 3] > 0, iterations=k)

        flats = cloth & near('shoes_flats.png', 6) & (ys > 440)
        rgb = a1[..., :3]
        white = cloth & (rgb.mean(-1) > 185) & \
            ((rgb.max(-1) - rgb.min(-1)) < 32) & (ys < 400)
        tee = np.zeros_like(cloth)
        for x in np.nonzero(white.any(0))[0]:
            tee[:np.nonzero(white[:, x])[0].max() + 3, x] = True
        xs = np.nonzero(white.any(0))[0]
        mid = (xs.min() + xs.max()) // 2
        lows = [np.nonzero(white[:, x])[0].max()
                for x in range(mid - 20, mid + 21) if white[:, x].any()]
        tee[int(np.median(lows)) + 5:] = False
        tee &= cloth & ~flats
        shorts = cloth & ~tee & ~flats & (ys < 430)
        self._defaults[c] = {'top': tee, 'bottom': shorts, 'shoes': flats}
        return self._defaults[c]

    def item(self, c, slot, item):
        eq = {slot: item}
        a1 = self.v1.look(c, 'skin1', eq)
        a0 = self.v1.look(c, 'skin1', {slot: V1_DEFAULT[slot]})
        a3 = self.v1.look(c, 'skin3', eq)
        b, bs = self.base(c)
        ys = np.arange(a1.shape[0])[:, None]
        op = a1[..., 3] > 0
        diff = op & ((a0[..., 3] == 0) | (dist(a1, a0) >= CHANGED))
        region = closefill(diff, 1)
        if slot in self.defaults(c):
            region |= self.defaults(c)[slot] & op
        own = np.zeros(op.shape, bool)
        lay = self.v1.get(f'avatar/{c}/{slot}_{item}.png')
        if lay is not None:
            own = closefill(lay[..., 3] > 0, 8)  # its see-through holes too
        elif slot in self.defaults(c):
            own = closefill(self.defaults(c)[slot], 2)
        ref = self.v2(c, f'{slot}_{item}.png')
        if ref is not None:
            region &= ndimage.binary_dilation(ref[..., 3] > 0,
                                              iterations=V1_GROW[slot])
        skin = skin_v1(a1, a3)
        hands = hands_of(b)
        if slot in ('top', 'bottom', 'outfit'):
            # Skin-coloured shading inside the cloth (beige, cream) is
            # cloth: holes the size of a patch close, the hands stay apart.
            shut = ndimage.binary_fill_holes(ndimage.binary_closing(
                op & ~skin, iterations=7)) & ~ndimage.binary_dilation(hands)
            skin &= ~(shut & ~ndimage.binary_dilation(~op))
        moved = changed_by_skin(a1, a3)
        skin |= hands & moved  # the v1 hands (not a cream cuff over them)
        skin |= L.skinish(a1) & (ys > 470) & (slot == 'bottom')
        same = (b[..., 3] > 0) & ~bs & (dist(a1, b) < SAME) & (lum(a1) < 90)
        cand = region & op & ~skin & ~same
        cand &= ~(ndimage.binary_dilation(self.hair_region(c)) & hairlike(a1))
        if slot in ('top', 'outfit'):
            cand &= ~(hairlike(a1) & hairlike(a0) & (dist(a1, a0) < 70))
        if slot != 'accessory':
            cand &= ys >= HAIR_CUT[c] - 4
        else:
            cand &= ~hairlike(a1) | ~ndimage.binary_dilation(
                self.hair_region(c), iterations=2) | diff
        dark = lum(a1) < 62
        fab = cand & ~dark
        keep = fab | (cand & dark & (ndimage.binary_dilation(fab, iterations=2)
                                     | ndimage.binary_opening(cand & dark)))
        # v1 skin edges left beside the cloth (they would stay skin1 on
        # every tone): recoloured by the v1 skin copy, and skin on v2 too.
        keep &= ~(moved & bs)
        lab, n = ndimage.label(keep, K3)
        if n:
            sizes = ndimage.sum(keep, lab, range(1, n + 1))
            keep = np.isin(lab, 1 + np.nonzero(sizes >= 12)[0])
        # Thin strays (arm and leg outlines of the v1 body) away from the item.
        keep &= ndimage.binary_dilation(ndimage.binary_opening(keep, iterations=2),
                                        iterations=2)
        if slot in HOLES:
            # The v1 cloth has see-through holes (the v1 legs and the cloth
            # under it showed through): closed holes take the nearest cloth.
            hole = ndimage.binary_fill_holes(keep) & ~keep
            lab, n = ndimage.label(hole)
            if n:
                sizes = ndimage.sum(hole, lab, range(1, n + 1))
                hole = np.isin(lab, 1 + np.nonzero(sizes < HOLES[slot])[0])
            # and the bites open to an edge, inside the 43~49번 garment's
            # outline (the same item, so the same silhouette).
            # Inside where the garment is drawn: the 43~49번 picture of the
            # same item (same silhouette) or the v1 layer itself.
            inside = own.copy()
            if ref is not None:
                inside |= ref[..., 3] > 0
            hull = ndimage.binary_fill_holes(
                ndimage.binary_closing(keep, K3, iterations=8))
            hole |= hull & ~keep & ~ndimage.binary_dilation(hands, K3) &                 ndimage.binary_erosion(inside, K3, iterations=2)
            if hole.any():
                _, (iy, ix) = ndimage.distance_transform_edt(
                    ~keep, return_indices=True)
                a1 = a1.copy()
                a1[hole] = a1[iy[hole], ix[hole]]
                keep |= hole
        out = a1.astype(np.uint8).copy()
        out[~keep, 3] = 0
        return out


# 26번 3차 AV3 (user, 2026-11-20): "여자 기본 반바지는 핫팬츠로 하지 말고 무릎
# 위 정도로 길이를 조정해줘" - the girl's shorts (and, the same problem, her
# denim shorts) end a few rows below the crotch. Their legs are stretched
# down to this hem row (the knee is at ~400), the cuff moved with them.
LENGTHEN = {'girl': {'shorts': 392, 'denimshorts': 392}}
# Rows of the turned-up cuff at the bottom of each (moved down whole).
CUFF_ROWS = {'shorts': 14, 'denimshorts': 13}


def lengthen(arr, hem, base, cuff_rows):
    """[arr] (a shorts layer) with its legs reaching row [hem]. Column by
    column, the leg between the waistband and the cuff (its last
    [cuff_rows] rows) is stretched (nearest row, crisp pixel art) and the
    cuff moved down by the same amount, so the shape, folds and cuff stay
    the drawing's own; below the base's crotch the gap between the legs
    stays open with an outline each side."""
    a = arr[..., 3] > 0
    # The garment's own rows (a stray pixel or two lower does not count),
    # and nothing of it below.
    rows = np.nonzero(a.sum(1) >= 20)[0]
    top, bottom = int(rows.min()), int(rows.max())
    if bottom >= hem:
        return arr
    arr = arr.copy()
    arr[bottom + 1:, ..., 3] = 0
    a = arr[..., 3] > 0
    ext = hem - bottom
    s0 = top + 22  # below the waistband and pockets
    out = arr.copy()
    for x in np.nonzero(a[s0:].any(0))[0]:
        col = np.nonzero(a[:, x])[0]
        b = int(col.max())
        c0 = max(b - cuff_rows + 1, s0 + 1)
        out[s0:, x] = 0
        n_old, n_new = c0 - s0, c0 - s0 + ext
        for k in range(n_new):
            out[s0 + k, x] = arr[s0 + int(k * n_old / n_new), x]
        out[c0 + ext:b + 1 + ext, x] = arr[c0:b + 1, x]
    ink = np.percentile(arr[a][:, :3], 3, axis=0).astype(out.dtype)
    bal = base[..., 3] > 0
    cols = np.nonzero(a.any(0))[0]
    mid = (cols.min() + cols.max()) // 2
    for y in range(s0, hem + 1):
        if bal[y, mid - 1:mid + 2].any():
            continue  # above the base's crotch
        gap = np.nonzero(~bal[y, mid - 8:mid + 9])[0] + mid - 8
        if not len(gap):
            continue
        g0, g1 = int(gap.min()), int(gap.max())
        out[y, g0:g1 + 1, 3] = 0
        for x in (g0 - 1, g1 + 1):
            if out[y, x, 3]:
                out[y, x, :3] = ink
    # Specks left beside the legs (v1 outline bits) go.
    lab, n = ndimage.label(out[..., 3] > 0, K3)
    if n:
        sizes = ndimage.sum(out[..., 3] > 0, lab, range(1, n + 1))
        out[np.isin(lab, 1 + np.nonzero(sizes < 30)[0]), 3] = 0
    return out


def raise_waist(arr, target):
    """[arr] (a bottom) with its waistband's top on row [target]: per
    column the band (RAISE_BAND rows) moves up, the rows below it down to
    30 rows under the old waist stretch to meet it."""
    a = arr[..., 3] > 0
    rows = np.nonzero(a.sum(1) >= 20)[0]
    if not len(rows):
        return arr
    top = int(rows.min())
    d = top - target
    if d <= 0:
        return arr
    s1 = top + 30
    out = arr.copy()
    for x in np.nonzero(a[top - 2:s1].any(0))[0]:
        col = np.nonzero(a[:s1, x])[0]
        if not len(col):
            continue
        t = int(col.min())
        b0 = t + RAISE_BAND
        if b0 >= s1:
            continue
        seg = arr[b0:s1, x].copy()
        band = arr[t:b0, x].copy()
        out[t - d:s1, x] = 0
        out[t - d:b0 - d, x] = band
        n_new = s1 - (b0 - d)
        for k in range(n_new):
            out[b0 - d + k, x] = seg[int(k * len(seg) / n_new)]
    return out
