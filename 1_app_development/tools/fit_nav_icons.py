"""Bottom-menu icons that fill their square (26번 4-2단계 F10, 25번 14번).

The home screen's four bottom-menu icons (menu, skill, tab_outfit, shop)
are 72x72 pictures whose drawn part differs a lot (skill 19x29, tab_outfit
43x53, menu 68x68, shop 59x68), so at one size the bolt and the apron look
much smaller. This tool cuts each picture to its drawn part and scales its
longer side to [FILL] of a [CANVAS] square, centred:

* x2 or more: whole-number nearest-neighbour (the dots stay crisp; skill
  x3 = 57x87);
* less: premultiplied Lanczos (menu, tab_outfit, shop).

The original icons are kept (other screens use them). Outputs
assets/images/icons/nav_menu.png, nav_skill.png, nav_skins.png,
nav_shop.png (96x96). Running it again gives the same pictures.

    python tools/fit_nav_icons.py            # write the four icons
    python tools/fit_nav_icons.py --preview  # + build/fit_nav_icons_preview.png

Run it in 1_app_development.
"""
import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICONS = ROOT / "assets/images/icons"
CANVAS = 96
FILL = 88
SOURCES = {          # output name: source icon
    "nav_menu": "menu",
    "nav_skill": "skill",
    "nav_skins": "tab_outfit",
    "nav_shop": "shop",
}


def fit(img):
    part = img.crop(img.getchannel("A").getbbox())
    longer = max(part.size)
    k = FILL / longer
    if k >= 2:
        n = int(k)
        big = part.resize((part.width * n, part.height * n), Image.NEAREST)
    else:
        size = (max(1, round(part.width * k)), max(1, round(part.height * k)))
        big = part.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
    out = Image.new("RGBA", (CANVAS, CANVAS))
    out.alpha_composite(big, ((CANVAS - big.width) // 2, (CANVAS - big.height) // 2))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--preview", action="store_true")
    args = p.parse_args()
    made = {}
    for name, source in SOURCES.items():
        out = fit(Image.open(ICONS / f"{source}.png").convert("RGBA"))
        out.save(ICONS / f"{name}.png")
        box = out.getchannel("A").getbbox()
        print(f"  {name}.png from {source}.png: drawn {box[2] - box[0]}x{box[3] - box[1]}")
        made[name] = (Image.open(ICONS / f"{source}.png").convert("RGBA"), out)
    if args.preview:
        sheet = Image.new("RGBA", (len(made) * 200 + 8, 112), (240, 228, 200, 255))
        for i, (old, new) in enumerate(made.values()):
            sheet.alpha_composite(old.resize((96, 96), Image.NEAREST), (8 + i * 200, 8))
            sheet.alpha_composite(new, (8 + i * 200 + 100, 8))
        path = ROOT / "build" / "fit_nav_icons_preview.png"
        path.parent.mkdir(exist_ok=True)
        sheet.save(path)
        print(f"preview: {path}")


if __name__ == "__main__":
    main()
