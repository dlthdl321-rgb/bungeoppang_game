"""Copies the 재료 타이쿤 icons (25번 필요한 그림 62번) into the game's assets.
It only reads the generated folder.

    python tools/apply_62_ingredient_icons.py <26_feedback_generated folder>
    python tools/apply_62_ingredient_icons.py <26_feedback_generated> --only shop
    python tools/apply_62_ingredient_icons.py <26_feedback_generated> --only prep

Run it in 1_app_development. The delivered icons are already the game's
icon size (72x72 RGBA, one dot = one pixel, alpha 0 or 255), so they are
copied as they are after a check (no resizing, which would blur the dots):

* --only shop (상점 '재료' 탭, 묶음 C): ing_<flour|milk|egg|sugar|salt|
  redbean|cocoa>.png, prem_<butter|redbean|vanilla|chocolate>.png,
  tab_ingredients.png
* --only prep (재료 준비 창, 묶음 D·E): tub_<batter|redbean|custard|cocoa>.png,
  btn_prep.png

Each goes to assets/images/icons/<same name>.png; add new names to
PixelSprites.iconNames (lib/ui/pixel_sprites.dart).
"""
import argparse
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICON_DIR = ROOT / "assets/images/icons"
GROUPS = {
    "shop": ["ing_flour", "ing_milk", "ing_egg", "ing_sugar", "ing_salt", "ing_redbean", "ing_cocoa",
             "prem_butter", "prem_redbean", "prem_vanilla", "prem_chocolate", "tab_ingredients"],
    "prep": ["tub_batter", "tub_redbean", "tub_custard", "tub_cocoa", "btn_prep"],
}
SIZE = (72, 72)


def check(path):
    img = Image.open(path)
    if img.size != SIZE or img.mode != "RGBA":
        sys.exit(f"{path.name}: {img.size} {img.mode}, 72x72 RGBA가 아니에요")
    alphas = set(img.getchannel("A").getdata())
    if not alphas <= {0, 255}:
        sys.exit(f"{path.name}: 반투명 픽셀이 있어요 {sorted(alphas)[:5]}")
    return img


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("generated", type=Path)
    parser.add_argument("--only", choices=sorted(GROUPS), action="append")
    args = parser.parse_args()
    source = args.generated / "62_ingredients/icons"
    for group in args.only or sorted(GROUPS):
        for name in GROUPS[group]:
            img = check(source / f"{name}.png")
            img.save(ICON_DIR / f"{name}.png", optimize=True)
            print(f"{group}: {name}.png")


if __name__ == "__main__":
    main()
