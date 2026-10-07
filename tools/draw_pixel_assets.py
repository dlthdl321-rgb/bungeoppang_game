"""Draws every pixel-art image of the game into assets/images/.

Pastel storybook style on the shared palette (tools/palette.py). The art
lives in art_fish.py, art_avatar.py, art_scene.py and art_icons.py, built
on pixel_kit.py. An AI image processed with tools/pixelize.py into the same
path (and size) replaces any of these files; afterwards redraw only other
groups with --only, or the replacement is overwritten.

Sizes and scene positions must match lib/ui/pixel_sprites.dart,
lib/ui/night_stall_painter.dart and lib/ui/avatar_painter.dart.

Run:  python tools/draw_pixel_assets.py [--only fish,icons] [--preview DIR]
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

from art_avatar import avatar_sprites
from art_fish import FISH_PATTERNS, FISH_SKINS, FISH_TOPPINGS, fish, topping
from art_icons import MENU_ICONS, SKILL_ICONS, app_icon, skill_icon
from art_scene import DECORATIONS, SCENES, STOVES, counter, stove

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images"


def build():
    out = {}
    for flavor in FISH_SKINS:
        out[f"fish/{flavor}.png"] = fish(flavor)
        for pattern in FISH_PATTERNS[1:]:
            out[f"fish/{flavor}@{pattern}.png"] = fish(flavor, pattern)
    for kind in FISH_TOPPINGS:
        out[f"topping/{kind}.png"] = topping(kind)
    out.update(avatar_sprites())
    for name, make in SCENES.items():
        out[f"bg/{name}.png"] = make()
    out["stall/counter.png"] = counter()
    out["stall/counter_snow.png"] = counter(snow=True)
    for kind in STOVES:
        out[f"stove/{kind}.png"] = stove(kind)
    for name, make in DECORATIONS.items():
        out[f"deco/{name}.png"] = make()
    for name, make in MENU_ICONS.items():
        out[f"icons/{name}.png"] = make()
    for skill_id in SKILL_ICONS:
        out[f"skills/{skill_id}.png"] = skill_icon(skill_id)
    return out


def write_launcher_icons():
    """Android launcher icons and a 512px store icon from app/app_icon.png."""
    img = Image.open(OUT / "app" / "app_icon.png").convert("RGBA")
    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        # Below 2x, smooth downsampling reads better than dropped pixel rows.
        method = Image.Resampling.NEAREST if size >= 128 else Image.Resampling.LANCZOS
        img.resize((size, size), method).save(res / f"mipmap-{folder}" / "ic_launcher.png")
    img.resize((512, 512), Image.Resampling.NEAREST).save(OUT / "app" / "app_icon_512.png")


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # Korean paths on Windows consoles
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--preview", type=Path, help="also write 4-8x previews into this folder")
    p.add_argument("--only", help="comma-separated path prefixes to draw, e.g. fish,icons; "
                                  "'launcher' only rebuilds launcher icons from app/app_icon.png")
    args = p.parse_args()
    sprites = build()
    only = args.only.split(",") if args.only else []
    if only:
        sprites = {k: v for k, v in sprites.items() if k.startswith(tuple(only))}
    for rel, sprite in sprites.items():
        sprite.save(OUT / rel)
        if args.preview:
            scale = 3 if sprite.w >= 100 else 8
            path = args.preview / rel.replace("/", "_")
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(sprite.a, "RGBA").resize((sprite.w * scale, sprite.h * scale),
                                                     Image.Resampling.NEAREST).save(path)
    if not only or "app" in only:
        app_icon().save(OUT / "app" / "app_icon.png")
    if not only or "app" in only or "launcher" in only:
        write_launcher_icons()
    print(f"wrote {len(sprites)} sprites to {OUT}")


if __name__ == "__main__":
    main()
