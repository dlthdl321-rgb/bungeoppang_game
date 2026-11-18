"""Temporary wardrobe item icons (26번 4-5단계, G5) until 25번 31번 arrives.

The wardrobe tiles show an item icon instead of a tiny dressed vendor.
Every avatar item gets assets/images/cosmetic_icons/<id>.png (64x64,
transparent, shared by both characters). Until the drawn icons of 25번
31번 come, this tool cuts them from the girl's current layers:

* items with their own layer (hats, hair, tops, bottoms, shoes, aprons,
  accessories, tools): the layer's opaque part only, no body;
* the defaults the base picture wears (long hair, white tee, beige shorts,
  brown flats): that part of base.png (long hair = the dark hair pixels of
  the head, the face left out);
* characters (girl, boy): the head and shoulders of that vendor's base;
* skin tones: a faceless mannequin head and shoulders drawn here in the
  tone's face colour (base.png / base@skin2.png / base@skin3.png);
* 'none' (모자 없음·앞치마 없음·소품 없음): an empty hanger with a slash.

The real icons replace these files one for one (same path, same size), so
no code changes then. Once 4-7단계 redraws the vendor this tool is not run
again.

    python tools/make_cosmetic_icons.py            # writes the icons
    python tools/make_cosmetic_icons.py --preview  # + build/cosmetic_icons_preview.png
    python tools/make_cosmetic_icons.py --only skin2 --only skin3
                                                   # just these icons (4-7단계
                                                   # G4: new skin tone colours)

Items without any art yet (4-7단계 new bottoms, drawn only for the v2
vendor) are skipped; tools/avatar_v2.py icons brings their real icons.

Run in 1_app_development.
"""
import argparse
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
AVATAR = ROOT / "assets/images/avatar"
OUT = ROOT / "assets/images/cosmetic_icons"
SIZE = 64
FILL = 58  # longest side of the drawn part

AVATAR_SLOTS = ["character", "skin", "hair", "top", "bottom", "shoes",
                "outfit", "hat", "accessory", "tool"]
NONE_ITEMS = {"nohat", "noapron", "noacc"}

# Parts of the girl's base.png (trimmed 244x497) the defaults are cut from:
# (left, top, right, bottom).
BASE_BOXES = {
    "tee": (55, 188, 175, 278),
    "shorts": (62, 268, 168, 336),
    "flats": (60, 440, 175, 497),
    "long": (0, 0, 244, 305),
    "girl": (25, 0, 220, 215),
}
FACE = (62, 62, 182, 192)  # the face ellipse, left out of the long hair


def definitions():
    """(id, slot) of every avatar item in lib/cosmetic_config.dart."""
    text = (ROOT / "lib/cosmetic_config.dart").read_text(encoding="utf-8")
    found = re.findall(r"CosmeticDefinition\(\s*'([a-z0-9_]+)',\s*'[^']*',\s*CosmeticSlot\.(\w+)", text)
    return [(i, s) for i, s in found if s in AVATAR_SLOTS]


def solid(img, low=200, share=.04):
    """Only the clearly drawn pixels of a worn layer: the faint edge haze
    and the scraps it leaves round the body (smaller than [share] of the
    biggest piece) go."""
    a = np.asarray(img).copy()
    mask = a[..., 3] > low
    labels, n = nd.label(mask, structure=np.ones((3, 3)))
    if n:
        sizes = nd.sum(mask, labels, range(1, n + 1))
        big = sizes.max()
        keep_ids = [i + 1 for i, v in enumerate(sizes) if v >= big * share]
        mask = np.isin(labels, keep_ids)
    a[..., 3][~mask] = 0
    return Image.fromarray(a, "RGBA")


def not_skin(img):
    a = np.asarray(img).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    skin = (r > 200) & (g > 150) & (b > 120) & (r - b > 35) & (r - b < 110)
    return keep(img, ~skin & (a[..., 3] > 0))


def fit(img, low=24):
    a = np.asarray(img)[..., 3]
    ys, xs = np.nonzero(a > low)
    part = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    k = FILL / max(part.size)
    size = (max(1, round(part.width * k)), max(1, round(part.height * k)))
    small = part.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    out = Image.new("RGBA", (SIZE, SIZE))
    out.alpha_composite(small, ((SIZE - size[0]) // 2, (SIZE - size[1]) // 2))
    a = np.asarray(out).copy()
    a[..., 3][a[..., 3] < 30] = 0
    a[..., 3][a[..., 3] > 220] = 255
    return Image.fromarray(a, "RGBA")


def base(character="girl", skin=None):
    name = "base.png" if skin in (None, "skin1") else f"base@{skin}.png"
    return Image.open(AVATAR / character / name).convert("RGBA")


def keep(img, mask):
    a = np.asarray(img).copy()
    a[..., 3][~mask] = 0
    return Image.fromarray(a, "RGBA")


def long_hair():
    img = base().crop(BASE_BOXES["long"])
    a = np.asarray(img).astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dark = (r + g + b) / 3 < 140
    yy, xx = np.mgrid[0:img.height, 0:img.width]
    cx, cy = (FACE[0] + FACE[2]) / 2, (FACE[1] + FACE[3]) / 2
    rx, ry = (FACE[2] - FACE[0]) / 2, (FACE[3] - FACE[1]) / 2
    face = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 < 1
    return keep(img, dark & ~face & (a[..., 3] > 0))


def skin_colour(skin):
    """The median face colour of the base (or its recoloured copy)."""
    a = np.asarray(base(skin=skin).crop(FACE)).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    light = (al > 200) & (r > g) & (g > b) & ((r + g + b) / 3 > 120)
    return tuple(int(np.median(c[light])) for c in (r, g, b))


def mannequin(colour):
    """A faceless head on a neck and shoulders, drawn at 4x then reduced."""
    k = 4
    img = Image.new("RGBA", (SIZE * k, SIZE * k))
    d = ImageDraw.Draw(img)
    dark = tuple(max(0, int(c * .62)) for c in colour) + (255,)
    shade = tuple(max(0, int(c * .86)) for c in colour) + (255,)
    fill = colour + (255,)
    w = 3 * k
    d.rounded_rectangle((10 * k, 44 * k, 54 * k, 66 * k), radius=12 * k, fill=fill, outline=dark, width=w)
    d.rectangle((26 * k, 34 * k, 38 * k, 48 * k), fill=shade, outline=dark, width=w)
    d.ellipse((17 * k, 4 * k, 47 * k, 40 * k), fill=fill, outline=dark, width=w)
    d.ellipse((22 * k, 9 * k, 31 * k, 17 * k), fill=tuple(min(255, int(c * 1.08)) for c in colour) + (255,))
    out = img.resize((SIZE, SIZE), Image.LANCZOS)
    return fit(out)


def hanger():
    k = 4
    img = Image.new("RGBA", (SIZE * k, SIZE * k))
    d = ImageDraw.Draw(img)
    wood, dark = (176, 120, 72, 255), (92, 58, 36, 255)
    d.arc((26 * k, 6 * k, 38 * k, 18 * k), 180, 90, fill=dark, width=3 * k)
    d.line((32 * k, 18 * k, 32 * k, 22 * k), fill=dark, width=3 * k)
    d.line((32 * k, 22 * k, 6 * k, 44 * k), fill=wood, width=5 * k)
    d.line((32 * k, 22 * k, 58 * k, 44 * k), fill=wood, width=5 * k)
    d.line((6 * k, 44 * k, 58 * k, 44 * k), fill=wood, width=5 * k)
    d.line((14 * k, 56 * k, 50 * k, 8 * k), fill=(192, 57, 43, 220), width=4 * k)
    return fit(img.resize((SIZE, SIZE), Image.LANCZOS))


LAYERS = json.loads((ROOT / "tools/avatar_layers.json").read_text(encoding="utf-8"))
CANVAS = (280, 520)


def dressed(slot, item):
    """A worn layer (hair, aprons, the chef coat, trousers) is mostly the
    changed outline of the body; alone it reads badly. Put it on the girl's
    base (its _cut mask erasing the base under it) and cut out the layer's
    box. Hair leaves the face out."""
    trim = LAYERS["trim"]
    key = f"avatar/girl/{slot}_{item}.png"
    canvas = Image.new("RGBA", CANVAS)
    canvas.alpha_composite(base(), tuple(trim["avatar/girl/base.png"]))
    cut_key = key.replace(".png", "_cut.png")
    if (ROOT / "assets/images" / cut_key).exists():
        cut = Image.open(ROOT / "assets/images" / cut_key).convert("RGBA")
        hole = Image.new("RGBA", CANVAS)
        hole.alpha_composite(cut, tuple(trim[cut_key]))
        a = np.asarray(canvas).copy()
        a[..., 3][np.asarray(hole)[..., 3] > 0] = 0
        canvas = Image.fromarray(a, "RGBA")
    layer = Image.open(ROOT / "assets/images" / key).convert("RGBA")
    x, y = trim[key]
    canvas.alpha_composite(layer, (x, y))
    box = (x, y, x + layer.width, y + layer.height)
    part = canvas.crop(box)
    if slot == "hair":
        bx, by = trim["avatar/girl/base.png"]
        a = np.asarray(part).copy()
        yy, xx = np.mgrid[0:part.height, 0:part.width]
        cx, cy = (FACE[0] + FACE[2]) / 2 + bx - x, (FACE[1] + FACE[3]) / 2 + by - y
        rx, ry = (FACE[2] - FACE[0]) / 2, (FACE[3] - FACE[1]) / 2
        a[..., 3][((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 < 1] = 0
        # Only the head: no shoulders or tee under the hair.
        a[..., 3][yy + y > by + 300] = 0
        rgb = a[..., :3].astype(int)
        a[..., 3][(rgb.min(axis=2) > 170)] = 0
        part = Image.fromarray(a, "RGBA")
    return part


def icon(item, slot):
    if item in NONE_ITEMS:
        return None  # one shared none.png
    if slot == "character":
        box = BASE_BOXES["girl"] if item == "girl" else None
        img = base(item)
        if box is None:
            h = img.height
            box = (0, 0, img.width, int(h * .43))
        return fit(img.crop(box))
    if slot == "skin":
        return mannequin(skin_colour(item))
    if item == "long":
        return fit(long_hair())
    if item in BASE_BOXES:
        img = base().crop(BASE_BOXES[item])
        if item == "tee":
            a = np.asarray(img).astype(int)
            light = (a[..., :3].min(axis=2) > 170) & (a[..., 3] > 0)
            img = keep(img, light)
        elif item in ("shorts", "flats"):
            img = not_skin(img)
        return fit(solid(img))
    if f"avatar/girl/{slot}_{item}.png" in LAYERS["worn"] and slot != "hat":
        return fit(solid(dressed(slot, item), low=100, share=.02))
    path = AVATAR / "girl" / f"{slot}_{item}.png"
    if not path.exists():
        path = AVATAR / "boy" / f"{slot}_{item}.png"
    if not path.exists():
        return None  # no art yet (4-7단계 new items)
    return fit(solid(Image.open(path).convert("RGBA")))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--preview", action="store_true")
    p.add_argument("--only", action="append", default=[],
                   help="write only this icon id (repeatable)")
    args = p.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    made = {} if args.only else {"none": hanger()}
    for item, slot in definitions():
        if args.only and item not in args.only:
            continue
        img = icon(item, slot)
        if img is not None:
            made[item] = img
    for name, img in made.items():
        img.save(OUT / f"{name}.png")
    print(f"{len(made)} icons in {OUT.relative_to(ROOT).as_posix()}")
    if args.preview:
        cols = 10
        rows = (len(made) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * 140, rows * 140), (246, 233, 210, 255))
        for i, (name, img) in enumerate(made.items()):
            x, y = (i % cols) * 140, (i // cols) * 140
            sheet.alpha_composite(img.resize((128, 128), Image.NEAREST), (x + 6, y + 2))
            ImageDraw.Draw(sheet).text((x + 6, y + 128), name, fill=(60, 40, 30, 255))
        (ROOT / "build").mkdir(exist_ok=True)
        sheet.save(ROOT / "build" / "cosmetic_icons_preview.png")
        print("preview build/cosmetic_icons_preview.png")


if __name__ == "__main__":
    main()
