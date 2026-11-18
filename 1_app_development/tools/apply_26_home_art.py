"""Fits the 26번 4-1단계 home art (25번 필요한 그림 6번 손님, 20번 배경) into
the game's assets. It only reads the generated folder.

    python tools/apply_26_home_art.py <26_feedback_generated folder> --preview
    python tools/apply_26_home_art.py <26_feedback_generated> --only customers
    python tools/apply_26_home_art.py <26_feedback_generated> --only backgrounds --measure

Run it in 1_app_development. Outputs:

* assets/images/customer/<id>_<normal|happy|sad>.png (256x320 RGBA): the
  guests standing at the stall (WorkshopGuestLayer). Named guests npc_* and
  walkin_2..4 come from 06_customers_v2/ (1122x1402, the same 0.8 shape):
  premultiplied Lanczos down, alpha snapped (no halo), and every expression
  moved by the normal face's offset so the body's cut sits on the bottom
  edge and the three expressions line up. walkin_1 is the original customer
  of 3.3 customer/ (white background): order.png is its normal and sad face
  (there is no sad pose), receive.png its happy one, cut from the head to
  the waist and fitted the same way.
* assets/images/bg_low/<id>.png (335x762, opaque): the 14 backgrounds with
  the stall lowered to the towel (20_home_background/; clear from clear-v2,
  "v2 우선"). Each is scaled to the 335 width, then moved up or down so the
  red check towel's top edge sits at TOWEL_TARGET (524, the towelTops the
  counter already uses, DEC-038); rows missing at the bottom repeat the
  counter front (it is under the griddle). rain and seaside (923x1704) are
  too short at that width: they are scaled up until the towel can reach 524
  and cut at the right (the towel is at the left edge).
  --measure prints the measured towel tops (put them in
  NightStallPainter.towelTops as bg_low/<id>; after this tool all are 524).
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
CUSTOMER_DIR = ROOT / "assets/images/customer"
LOW_DIR = ROOT / "assets/images/bg_low"
ORIGINAL_CUSTOMER = REPO / "3_original_images_and_visual_references/3.3_additional_character_and_background_images/customer"

GUEST_SIZE = (256, 320)
NAMED = ["npc_yunha", "npc_doyun", "npc_makrye", "npc_seojin", "npc_taeo",
         "npc_eunchae", "npc_minjae", "npc_sua"]
WALKINS = ["walkin_2", "walkin_3", "walkin_4"]
MOODS = ["normal", "happy", "sad"]

BG_SIZE = (335, 762)
TOWEL_TARGET = 524
BACKGROUNDS = ["autumn", "autumn_night", "cherry", "cherry_night", "clear",
               "clear_night", "dusk", "forest", "night", "rain", "rain_night",
               "seaside", "snow", "snowday"]
# clear uses the layout reference (25번 20번: v2 우선).
BG_SOURCE = {"clear": "clear-v2"}


def premultiplied_resize(img, size, box=None):
    return img.convert("RGBa").resize(size, Image.LANCZOS, box=box).convert("RGBA")


def snap_alpha(img, low=24, high=232):
    a = np.asarray(img).copy()
    al = a[..., 3]
    al[al < low] = 0
    al[al > high] = 255
    a[al == 0, :3] = 0
    return Image.fromarray(a, "RGBA")


# ------------------------------------------------------------- customers

def _fit_guest(img, dy):
    """[img] (already 0.8 wide) scaled to 256x320 and moved down by dy."""
    small = premultiplied_resize(img, GUEST_SIZE)
    out = Image.new("RGBA", GUEST_SIZE)
    out.paste(small, (0, dy))
    return snap_alpha(out)


def _bottom_gap(img):
    box = img.getbbox()
    return GUEST_SIZE[1] - box[3] if box else 0


def generated_guests(src):
    made = {}
    folder = src / "06_customers_v2"
    for gid in NAMED + WALKINS:
        normal = Image.open(folder / f"{gid}_normal.png").convert("RGBA")
        dy = _bottom_gap(premultiplied_resize(normal, GUEST_SIZE))
        for mood in MOODS:
            img = Image.open(folder / f"{gid}_{mood}.png").convert("RGBA")
            made[f"{gid}_{mood}"] = _fit_guest(img, dy)
    return made


def _cut_white(path):
    """The original customer on a transparent background: the near-white
    area joined to the border becomes transparent."""
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    white = (a[..., :3].min(2) > 236)
    labels, _ = nd.label(white)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    bg = np.isin(labels, list(border))
    bg = nd.binary_dilation(bg, iterations=1) & (a[..., :3].min(2) > 200)
    a[bg, 3] = 0
    return Image.fromarray(a, "RGBA")


def walkin_one():
    """walkin_1 from the original full-body poses: head to waist, centred
    on the head, the 0.8 shape of the other guests."""
    made = {}
    poses = {"normal": "order.png", "happy": "receive.png", "sad": "order.png"}
    cut = {name: _cut_white(ORIGINAL_CUSTOMER / name) for name in set(poses.values())}
    # One crop box from the order pose so the poses share the body's place.
    ref = cut["order.png"]
    l, t, r, b = ref.getchannel("A").getbbox()
    height = (b - t) * .64
    width = height * GUEST_SIZE[0] / GUEST_SIZE[1]
    # The head's centre: the middle of the top fifth of the figure.
    alpha = np.asarray(ref)[..., 3]
    head = alpha[t:int(t + (b - t) * .2)]
    xs = np.where(head.max(0) > 0)[0]
    cx = (xs.min() + xs.max()) / 2
    top = t - height * .05
    box = (cx - width / 2, top, cx + width / 2, top + height)
    pad = 200
    for mood, name in poses.items():
        img = Image.new("RGBA", (cut[name].width + 2 * pad, cut[name].height + 2 * pad))
        img.paste(cut[name], (pad, pad))
        small = premultiplied_resize(img, GUEST_SIZE, box=tuple(v + pad for v in box))
        made[f"walkin_1_{mood}"] = snap_alpha(small)
    return made


def customers(src):
    made = {**generated_guests(src), **walkin_one()}
    CUSTOMER_DIR.mkdir(parents=True, exist_ok=True)
    for name, img in made.items():
        img.save(CUSTOMER_DIR / f"{name}.png", optimize=True)
    return made


# ----------------------------------------------------------- backgrounds

# The red check towel's top edge in each generated picture scaled to the
# 335 width (rain and seaside are 618 tall there), read off a 20px grid
# sheet and checked on --preview's sheet (the 524 line). Automatic
# detection is not reliable: the towel's colours change with each
# picture's light (dusk's red street, cherry's pale checks).
TOWEL_AT_335 = {"clear-v2": 545, "clear": 512, "rain": 460, "seaside": 460,
                "autumn": 548, "autumn_night": 566, "cherry": 568,
                "cherry_night": 544, "clear_night": 566, "dusk": 572,
                "forest": 576, "night": 563, "rain_night": 576, "snow": 553,
                "snowday": 512}


def fit_background(img, source_id):
    w, h = img.size
    scale = BG_SIZE[0] / w
    top = TOWEL_AT_335[source_id]
    first = img.resize((BG_SIZE[0], round(h * scale)), Image.LANCZOS)
    if top < TOWEL_TARGET:
        # Too little room above the towel (rain, seaside, clear, snowday):
        # scale up until it reaches 524, keep the left edge (towel). Never
        # scale down (that left a black strip at the right edge); a short
        # bottom repeats the counter front below.
        grow = TOWEL_TARGET / top
        scale *= grow
        top = TOWEL_TARGET
        first = img.resize((round(w * scale), round(h * scale)), Image.LANCZOS)
        first = first.crop((0, 0, BG_SIZE[0], first.height))
    shift = top - TOWEL_TARGET
    out = Image.new("RGB", BG_SIZE)
    part = first.crop((0, max(0, shift), BG_SIZE[0], min(first.height, shift + BG_SIZE[1])))
    out.paste(part, (0, max(0, -shift)))
    a = np.asarray(out).copy()
    if shift < 0:
        a[:-shift] = a[-shift]
    filled = max(0, -shift) + part.height
    if filled < BG_SIZE[1]:
        # Repeat the counter front's last rows (hidden under the griddle).
        a[filled:] = a[filled - 1]
    return Image.fromarray(a, "RGB")


def backgrounds(src, measure):
    made = {}
    LOW_DIR.mkdir(parents=True, exist_ok=True)
    for bid in BACKGROUNDS:
        img = Image.open(src / "20_home_background" / f"{BG_SOURCE.get(bid, bid)}.png").convert("RGB")
        out = fit_background(img, BG_SOURCE.get(bid, bid))
        out.save(LOW_DIR / f"{bid}.png", optimize=True)
        made[bid] = out
        if measure:
            print(f"'bg_low/{bid}': {TOWEL_TARGET},  # source {TOWEL_AT_335[BG_SOURCE.get(bid, bid)]}")
    return made


def preview(guests, bgs, path):
    tiles = []
    for name in sorted(guests):
        bg = Image.new("RGBA", GUEST_SIZE, (120, 160, 120, 255))
        bg.alpha_composite(guests[name])
        tiles.append(bg.convert("RGB").resize((128, 160)))
    cols = 9
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 130, rows * 162 + (390 if bgs else 0)), "white")
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * 130, (i // cols) * 162))
    for i, (name, b) in enumerate(sorted(bgs.items())):
        if i >= 14:
            break
        # The towel corner, 2x, with the 524 line.
        crop = b.crop((0, 444, 60, 604)).resize((80, 214), Image.NEAREST)
        crop.paste((0, 255, 0), (0, 106, 80, 108))
        sheet.paste(crop, (i * 84, rows * 162 + 4))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    print(f"preview: {path}")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("source", type=Path)
    p.add_argument("--only", choices=["customers", "backgrounds"])
    p.add_argument("--preview", action="store_true")
    p.add_argument("--measure", action="store_true")
    args = p.parse_args()
    if not args.source.is_dir():
        sys.exit(f"no folder: {args.source}")
    guests = customers(args.source) if args.only in (None, "customers") else {}
    bgs = backgrounds(args.source, args.measure) if args.only in (None, "backgrounds") else {}
    if args.preview:
        preview(guests, bgs, ROOT / "build/apply_26_home_art_preview.png")


if __name__ == "__main__":
    main()
