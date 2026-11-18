"""Fits 25번 7번 (26번 4-2단계 F8) closed and open griddles onto the game.

The generated griddles (26_feedback_generated/07_stoves/) redraw the whole
stove, so their plate is not pixel-identical to assets/images/stove_empty.
The plate of the empty griddle is kept (griddleCavities and
griddleFishClips stay true) and only what is new is taken from the
generated art:

* stove_closed/<stove>.png (941x470): the closed, cold griddle (lid over
  the plate, no flames). The whole generated picture is scaled and moved so
  its base (hinge, burner rail, base plate) lies on stove_empty's; the lid
  hides the plate, so nothing of the old plate is needed. [CLOSED_FIT].
* stove_open/<stove>.png (941x700): the bottom 941x470 is stove_empty
  itself (pixel-identical, flames on); the open lid of the generated
  picture stands in the 230 px above it. The generated picture is first
  fitted so its lower plate lies on stove_empty's plate ([OPEN_FIT]), then
  only its lid (the rows above the plate's back edge) is kept and drawn
  under stove_empty.

    python tools/apply_26_stoves.py <26_feedback_generated folder>
    python tools/apply_26_stoves.py <...> --measure   # re-fit (slow)
    python tools/apply_26_stoves.py <...> --preview   # build/apply_26_stove_preview.png

Run it in 1_app_development. It never writes into the source folder.
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from apply_25_art import (IMAGES, ROOT, STOVES, STOVE_SIZE, _grad, load,  # noqa: E402
                          premultiplied_resize, snap_alpha)

OPEN_SIZE = (941, 700)
LID_ROOM = OPEN_SIZE[1] - STOVE_SIZE[1]   # 230 px above the plate

# The plate's back edge in stove_empty (y), its left end (x): the lid is
# what stands above this line.
PLATE_BACK = 186
HINGE_RIGHT = 132

# (scale, dx, dy) of the generated picture on stove_empty, from --measure.
CLOSED_FIT = {
    "iron": (0.5300, 0.50, 0.50),
    "copper": (0.5300, 1.00, 1.00),
    "castiron": (0.5300, 0.50, 0.50),
    "golden": (0.5300, 0.00, 1.50),
}
OPEN_FIT = {
    "iron": (0.6410, 7.50, -186.50),
    "copper": (0.6500, -2.00, -195.50),
    "castiron": (0.6450, 1.50, -203.50),
    "golden": (0.6450, -2.50, -198.50),
}


def place(img, scale, dx, dy, size):
    """[img] scaled by [scale] with its top-left at (dx, dy) in a [size]
    canvas (sub-pixel), like apply_25_art.place with room for big moves."""
    pad = 600
    big = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad))
    big.paste(img, (pad, pad))
    w, h = size
    box = (pad - dx / scale, pad - dy / scale,
           pad + (w - dx) / scale, pad + (h - dy) / scale)
    return premultiplied_resize(big, size, box=box)


def _mask(rows, cols=None):
    w, h = STOVE_SIZE
    m = np.zeros((h, w), bool)
    m[rows[0]:rows[1], :] = True
    if cols is not None:
        m[:, cols[0]:cols[1]] = True
    return m


def _fit(gen, ref_img, mask, scales, span, start):
    """Best (score, scale, dx, dy) of [gen] placed on [ref_img] by gradient
    correlation inside [mask]; coarse grid around [start], then finer."""
    ref = _grad(ref_img)[mask]
    ref = (ref - ref.mean()) / ref.std()

    def score(s, dx, dy):
        g = _grad(place(gen, s, dx, dy, STOVE_SIZE))[mask]
        sd = g.std()
        return -2.0 if sd == 0 else float((ref * (g - g.mean()) / sd).mean())

    _, x0, y0 = start
    best = (-2.0,) + start
    for s in scales:
        for dx in np.arange(x0 - span, x0 + span + 1, 4):
            for dy in np.arange(y0 - span, y0 + span + 1, 4):
                v = score(s, dx, dy)
                if v > best[0]:
                    best = (v, s, dx, dy)
    for step in (2.0, 1.0, .5):
        _, s0, x0, y0 = best
        for s in (s0 - .002 * step, s0, s0 + .002 * step):
            for dx in (x0 - step, x0, x0 + step):
                for dy in (y0 - step, y0, y0 + step):
                    v = score(s, dx, dy)
                    if v > best[0]:
                        best = (v, s, dx, dy)
    return best


def measure(name, src):
    empty = load(IMAGES / "stove_empty" / f"{name}.png")
    closed = load(src / f"stove_closed_{name}.png")
    # The base under the lid: the burner rail, base plate and hinge.
    c = _fit(closed, empty, _mask((400, 470), (0, 160)),
             np.arange(.522, .5391, .004), 8, CLOSED_FIT[name])
    opened = load(src / f"stove_open_{name}.png")
    o = _fit(opened, empty, _mask((PLATE_BACK - 6, 470)),
             np.arange(.61, .651, .01), 24, OPEN_FIT[name])
    return c, o


def closed_stove(name, src):
    s, dx, dy = CLOSED_FIT[name]
    return snap_alpha(place(load(src / f"stove_closed_{name}.png"), s, dx, dy,
                            STOVE_SIZE), 24, 230)


def open_stove(name, src):
    s, dx, dy = OPEN_FIT[name]
    # The generated picture on the 941x700 canvas: its plate on the bottom
    # 941x470 (stove_empty's plate), its lid in the room above.
    lid = snap_alpha(place(load(src / f"stove_open_{name}.png"), s, dx,
                           dy + LID_ROOM, OPEN_SIZE), 24, 230)
    a = np.asarray(lid).copy()
    back = LID_ROOM + PLATE_BACK
    a[back + 4:, :, :] = 0              # the generated plate and base
    a[LID_ROOM + 146:, :HINGE_RIGHT, :] = 0   # its hinge: stove_empty's stays
    out = Image.fromarray(a, "RGBA")
    out.alpha_composite(load(IMAGES / "stove_empty" / f"{name}.png"), (0, LID_ROOM))
    return out


def preview(made, path):
    tiles = [img.resize((img.width // 2, img.height // 2), Image.LANCZOS)
             for img in made.values()]
    w = max(t.width for t in tiles) * 2 + 12
    h = sum(t.height + 6 for t in tiles)
    sheet = Image.new("RGBA", (w, h), (40, 34, 30, 255))
    y = 0
    for t in tiles:
        sheet.alpha_composite(t, (4, y))
        light = Image.new("RGBA", t.size, (120, 200, 120, 255))
        light.alpha_composite(t)
        sheet.paste(light, (w // 2 + 4, y))
        y += t.height + 6
    path.parent.mkdir(exist_ok=True)
    sheet.save(path)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("source", type=Path,
                   help="the 26_feedback_generated folder (or its 07_stoves)")
    p.add_argument("--measure", action="store_true")
    p.add_argument("--preview", action="store_true")
    args = p.parse_args()
    src = args.source.resolve()
    if (src / "07_stoves").is_dir():
        src = src / "07_stoves"
    made = {}
    for kind in ("stove_closed", "stove_open"):
        (IMAGES / kind).mkdir(exist_ok=True)
    for n in STOVES:
        if args.measure:
            c, o = measure(n, src)
            print(f"  {n}: closed match {c[0]:.4f} scale {c[1]:.4f} dx {c[2]:+.2f} dy {c[3]:+.2f}"
                  f" / open match {o[0]:.4f} scale {o[1]:.4f} dx {o[2]:+.2f} dy {o[3]:+.2f}")
            CLOSED_FIT[n] = tuple(float(v) for v in c[1:])
            OPEN_FIT[n] = tuple(float(v) for v in o[1:])
        closed = closed_stove(n, src)
        closed.save(IMAGES / "stove_closed" / f"{n}.png")
        opened = open_stove(n, src)
        opened.save(IMAGES / "stove_open" / f"{n}.png")
        made[f"stove_closed/{n}"] = closed
        made[f"stove_open/{n}"] = opened
    if args.preview:
        out = ROOT / "build" / "apply_26_stove_preview.png"
        preview(made, out)
        print(f"preview: {out}")


if __name__ == "__main__":
    main()
