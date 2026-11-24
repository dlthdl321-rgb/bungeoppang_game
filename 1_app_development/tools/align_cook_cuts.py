"""Holds the vendor's cooking cut still (26번 4-2단계 F9, 25번 10번).

The six cooking frames (assets/images/cook/girl_1..6.png, 506x506,
transparent) were drawn with the whole scene at different places: the
workbench of frames 2-6 sits up to 41 px left and 28 px higher than in
frame 1 (frames 5-6 also draw it 2-4% wider), so the cut jumped every
CookCut.frameMs.

What it does:

1. Finds each frame's workbench box ([workbench]: the wooden crate, the
   columns that are wood in its middle rows, from its top to its bottom
   edge) and moves the frame by whole pixels (no pixel resampled) so the
   crate's bottom edge and middle lie on frame 1's ([fit]). One common
   move [COMMON] for all frames keeps every drawing on the 506x506 canvas.
2. Moves the face anchors of the frames (tools/avatar_layers.json
   "anchors" cook/girl_<n>.png, used by cookPoses through
   lib/avatar_atlas.dart avatarFaceAnchors) the same way, and the side face boxes of avatar_layers.py are measured on
   frame 2, so its FACES['girl_side'] boxes move with frame 2 (done by
   hand once, see the json). Runs avatar_layers.py's write step so the
   Dart file follows. The eye and mouth part pictures do not change.
3. Measures the boy frames of 3.3 (cook/boy_1..6.png, 1254x1254, not in
   the app yet: PixelSprites.cookCharacters is ['girl']) the same way and
   only stores their move (the costume variants
   boy_<n>_<item>.png share their frame's place), for when they are
   applied.
4. Writes tools/cook_cut_alignment.json (move, workbench box and
   head offset after) and build/cook_cut_alignment_before_after.png (the
   six frames before and after, red lines on frame 1's workbench top and
   bottom and head top).

Running it again on aligned frames finds nothing to move and writes
nothing.

    python tools/align_cook_cuts.py           # align + json + preview
    python tools/align_cook_cuts.py --check   # only report (exit 1 if not aligned)
    python tools/align_cook_cuts.py --import <10_cook folder>
        # 25번 10번 redraws (girl_4..6.png, any square size, drawn from
        # frame 1): scaled and placed so head, feet and workbench lie on
        # frame 1's, face anchors measured on the eyes and mouth

Run it in 1_app_development.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets/images"
TOOLS = ROOT / "tools"
LAYERS = TOOLS / "avatar_layers.json"
OUT_JSON = TOOLS / "cook_cut_alignment.json"
PREVIEW = ROOT / "build" / "cook_cut_alignment_before_after.png"
BOY_SRC = (ROOT.parent / "3_original_images_and_visual_references"
           / "3.3_additional_character_and_background_images" / "cook")
FRAMES = 6
SIZE = 506
# Frame 1's head box (506 pixels): only measures how far the head still
# moves once the workbench stands still.
HEAD = (260, 40, 440, 140)
# One move for all frames after the workbench match, so no frame's drawing
# leaves the canvas (frames 3 and 6 reach far right).
COMMON = (-24, -2)


def premul(img):
    a = np.asarray(img.convert("RGBA")).astype(float)
    return a[..., :3] * a[..., 3:] / 255


def workbench(img):
    """(left, top, right, bottom) of the wooden crate."""
    a = np.asarray(img.convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    wood = (al > 160) & (r > g) & (g > b) & (r - b > 35) & (r < 200) & (r > 50)
    # The longest run of wide wooden rows (brown hair can be wide too).
    wide = wood.sum(1) > img.width * .36
    top = bottom = run = 0
    for y, on in enumerate(wide):
        run = run + 1 if on else 0
        if run > bottom - top:
            top, bottom = y - run + 1, y + 1
    mid = wood[top + (bottom - top) // 3:bottom - (bottom - top) // 4]
    cols = np.nonzero(mid.mean(0) > .6)[0]
    return int(cols.min()), top, int(cols.max()) + 1, bottom


def find(ref, box, img, start=(0, 0), reach=4):
    """(dx, dy): where [ref]'s [box] is in [img] near [start]."""
    l, t, r, b = box
    want = ref[t:b, l:r]
    pad = 80
    big = np.pad(img, ((pad, pad), (pad, pad), (0, 0)))
    best = (1e18, 0, 0)
    for dy in range(start[1] - reach, start[1] + reach + 1):
        for dx in range(start[0] - reach, start[0] + reach + 1):
            v = ((big[t + dy + pad:b + dy + pad, l + dx + pad:r + dx + pad] - want) ** 2).mean()
            if v < best[0]:
                best = (v, dx, dy)
    return best[1], best[2]


def place(img, dx, dy):
    """[img] moved by whole pixels (dx, dy) on its canvas."""
    out = Image.new("RGBA", img.size)
    out.paste(img, (dx, dy))
    return out


def fit(frames):
    """Whole-pixel move of each frame onto frame 1's workbench: the crate's
    bottom edge on frame 1's and its middle on frame 1's middle (frames
    5-6 draw it 2-4% wider, so their edges stay 2-6 px off; scaling them
    would squash the crate's height instead). A crate as wide as frame 1's
    then settles on its front by a +-3 px least-squares match."""
    ref_box = workbench(frames[0])
    ref = premul(frames[0])
    front = (ref_box[0] + 10, ref_box[1] + (ref_box[3] - ref_box[1]) // 3,
             ref_box[2] - 10, ref_box[3] - 4)
    out = []
    for img in frames:
        l, t, r, b = workbench(img)
        dx = round((ref_box[0] + ref_box[2] - l - r) / 2)
        dy = ref_box[3] - b
        if abs((r - l) - (ref_box[2] - ref_box[0])) <= 3:
            mx, my = find(ref, front, premul(place(img, dx, dy)), reach=3)
            dx, dy = dx - mx, dy - my
        out.append((dx, dy))
    return out


def report(frames):
    """Each frame's workbench box and head offset from frame 1's."""
    ref = premul(frames[0])
    return [{"workbench": list(workbench(img)),
             "head": list(find(ref, HEAD, premul(img), reach=30))}
            for img in frames]


def write_dart():
    """avatar_layers.py's Dart step only (no image job)."""
    subprocess.run([sys.executable, str(TOOLS / "avatar_layers.py"), "write"],
                   cwd=ROOT, check=True)


def preview(before, after, path):
    w = SIZE // 2
    sheet = Image.new("RGBA", (FRAMES * (w + 4) + 4, 2 * (w + 4) + 4), (60, 90, 60, 255))
    for row, frames in enumerate((before, after)):
        for i, img in enumerate(frames):
            sheet.alpha_composite(img.resize((w, w), Image.LANCZOS),
                                  (4 + i * (w + 4), 4 + row * (w + 4)))
    d = ImageDraw.Draw(sheet)
    for row, frames in enumerate((before, after)):
        _, t, _, b = workbench(frames[0])
        head = int(np.nonzero(np.asarray(frames[0])[:, 250:450, 3].max(1) > 128)[0].min())
        y0 = 4 + row * (w + 4)
        for y in (t, b, head):
            d.line([(0, y0 + y // 2), (sheet.width, y0 + y // 2)], fill=(230, 40, 40, 255))
    path.parent.mkdir(exist_ok=True)
    sheet.save(path)


def _white_clear(img):
    """The boy originals stand on white: near-white becomes transparent."""
    a = np.asarray(img).copy()
    a[(a[..., :3] > 236).all(-1), 3] = 0
    return Image.fromarray(a, "RGBA")


def boys():
    if not BOY_SRC.is_dir():
        return None
    # Measured at the app's 506 (the originals are 1254x1254 RGB),
    # the moves given in original pixels.
    frames = [Image.open(BOY_SRC / f"boy_{n}.png").convert("RGBA") for n in range(1, FRAMES + 1)]
    k = frames[0].width / SIZE
    small = [_white_clear(f.resize((SIZE, SIZE), Image.LANCZOS)) for f in frames]
    try:
        moves = fit(small)
    except ValueError:
        return {"note": "workbench not found: measure when applied"}
    after = [place(img, *mv) for img, mv in zip(small, moves)]
    return {f"boy_{n}": {"move": [round(dx * k), round(dy * k)],
                         "head_after_506": rep["head"]}
            for n, (dx, dy), rep in zip(range(1, FRAMES + 1), moves, report(after))}


# Frame 1's feet box (506 pixels) and the eye/mouth boxes around its
# anchors, for --import.
FEET = (380, 420, 500, 505)
FACE_BOX = {"eyes": 30, "mouth": 14}


def import_redraws(folder):
    """25번 10번: redrawn frames from [folder] (girl_<n>.png, square, drawn
    on frame 1 as reference but at a slightly different size) replace
    cook/girl_<n>.png. For each, the scale (1.00-1.03 of 506) and the
    whole-pixel place that put its feet on frame 1's, then the one with
    the smallest head offset; the eye and mouth anchors are measured where
    frame 1's eyes and mouth are found in it."""
    ref_img = Image.open(IMAGES / "cook" / "girl_1.png").convert("RGBA")
    ref = premul(ref_img)
    data = json.loads(LAYERS.read_text("utf-8"))
    ref_anchor = data["anchors"]["cook/girl_1.png"]
    result = {}
    for path in sorted(Path(folder).glob("girl_[2-6].png")):
        n = int(path.stem.split("_")[1])
        src = Image.open(path).convert("RGBA").convert("RGBa")
        best = None
        for step in range(7):
            side = round(SIZE * (1 + step * .005))
            big = src.resize((side, side), Image.LANCZOS).convert("RGBA")
            fx, fy = find(ref, FEET, premul(big), start=(0, side - SIZE), reach=12)
            img = Image.new("RGBA", (SIZE, SIZE))
            img.paste(big, (-fx, -fy))
            head = find(ref, HEAD, premul(img), reach=12)
            feet = find(ref, FEET, premul(img), reach=6)
            err = max(map(abs, head + feet))
            if best is None or err < best[0]:
                best = (err, side, (-fx, -fy), head, feet, img)
        err, side, at, head, feet, img = best
        img.save(IMAGES / "cook" / path.name)
        p = premul(img)
        anchor = {}
        for key, (x, y) in ref_anchor.items():
            r = FACE_BOX[key]
            box = (int(x - r), int(y - r // 2), int(x + r), int(y + r // 2))
            dx, dy = find(ref, box, p, reach=6)
            anchor[key] = [x + dx, y + dy]
        data["anchors"][f"cook/{path.name}"] = anchor
        result[path.stem] = {"source": path.name, "size": side, "at": list(at),
                             "head_offset": list(head), "feet_offset": list(feet),
                             "workbench": list(workbench(img)), "anchors": anchor}
        print(f"  {path.name}: {side}px at {at}, head {head}, feet {feet}, "
              f"workbench {workbench(img)}, anchors {anchor}")
    LAYERS.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", "utf-8")
    write_dart()
    out = json.loads(OUT_JSON.read_text("utf-8"))
    out["redraws"] = {"note": "25번 10번 redraws (2026-11-19), imported with --import",
                      **result}
    OUT_JSON.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", "utf-8")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true")
    p.add_argument("--import", dest="redraws", type=Path,
                   help="folder with redrawn girl_<n>.png (25번 10번)")
    args = p.parse_args()
    if args.redraws:
        import_redraws(args.redraws)
        return
    paths = [IMAGES / "cook" / f"girl_{n}.png" for n in range(1, FRAMES + 1)]
    frames = [Image.open(path).convert("RGBA") for path in paths]
    moves = fit(frames)
    for n, (mv, rep) in enumerate(zip(moves, report(frames)), 1):
        print(f"  girl_{n}: workbench {rep['workbench']}, head {rep['head']}, fit {mv}")
    still = all(dx == 0 and dy == 0 for dx, dy in moves[1:])
    if args.check:
        sys.exit(0 if still else 1)
    if still:
        print("already aligned: nothing to do")
        return
    moves = [(dx + COMMON[0], dy + COMMON[1]) for dx, dy in moves]
    after = [place(img, *mv) for img, mv in zip(frames, moves)]
    for img, path, before in zip(after, paths, frames):
        lost = int((np.asarray(before)[..., 3] > 128).sum()) - int((np.asarray(img)[..., 3] > 128).sum())
        if lost > 200:
            print(f"  warning: {path.name} lost about {lost} opaque pixels at the canvas edge")
        img.save(path)
    data = json.loads(LAYERS.read_text("utf-8"))
    for n, (dx, dy) in enumerate(moves, 1):
        key = f"cook/girl_{n}.png"
        data["anchors"][key] = {k: [x + dx, y + dy]
                                for k, (x, y) in data["anchors"][key].items()}
    LAYERS.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", "utf-8")
    write_dart()
    reps = report(after)
    result = {
        "note": "26번 4-2단계 F9: cook/girl_<n>.png moved by whole "
                "pixels onto frame 1's workbench (bottom edge, middle), plus "
                "the common move; applied once, face anchors moved the "
                "same. boy: measured only (not in the app yet).",
        "common": list(COMMON),
        "girl": {f"girl_{n}": {"move": [dx, dy],
                               "workbench_after": rep["workbench"],
                               "head_after": rep["head"]}
                 for n, (dx, dy), rep in zip(range(1, FRAMES + 1), moves, reps)},
        "boy": boys(),
    }
    OUT_JSON.write_text(json.dumps(result, indent=1, ensure_ascii=False) + "\n", "utf-8")
    preview(frames, after, PREVIEW)
    for n, rep in enumerate(reps, 1):
        print(f"  after girl_{n}: workbench {rep['workbench']}, head {rep['head']}")
    print(f"json: {OUT_JSON}\npreview: {PREVIEW}")


if __name__ == "__main__":
    main()
