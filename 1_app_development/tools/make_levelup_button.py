"""Draws the skill window's temporary 'LEVEL UP' word button (26번 시안 확인
2차, 2026-11-19) until 25번 33번 is generated:

    python tools/make_levelup_button.py            # write both
    python tools/make_levelup_button.py --preview  # + build/preview/levelup_button.png

Run it in 1_app_development. Outputs assets/images/ui/levelup.png (lit,
honey) and levelup_off.png (dark, warm grey): 108x72 RGBA, a 27x18 pixel
drawing doubled twice with nearest sampling so the dots stay square. The
words sit on two lines ('LEVEL' over 'UP') in a 3x5 pixel font so the
button fits the skill row (the game draws it 54x36). When the generated
art arrives, tools/apply_25_art.py --only levelup writes the same two
files instead.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images" / "ui"
W, H, SCALE = 27, 18, 4

FONT = {
    "L": ["100", "100", "100", "100", "111"],
    "E": ["111", "100", "110", "100", "111"],
    "V": ["101", "101", "101", "101", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "P": ["110", "101", "110", "100", "100"],
}

LIT = {
    "outline": (90, 52, 24),      # Cozy.wood-ish dark brown
    "body": (253, 190, 56),       # honey #FDBE38
    "light": (255, 226, 140),     # top highlight
    "shade": (214, 140, 30),      # lower body
    "rim": (168, 98, 22),         # bottom rim (pressable depth)
    "text": (74, 40, 18),
    "glint": (255, 246, 214),
}
OFF = {
    "outline": (111, 101, 96),
    "body": (183, 172, 165),
    "light": (183, 172, 165),     # flat: no highlight
    "shade": (166, 155, 148),
    "rim": (140, 130, 124),
    "text": (110, 100, 94),
    "glint": (183, 172, 165),
}


def draw(colours):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    def put(x, y, name):
        r, g, b = colours[name]
        px[x, y] = (r, g, b, 255)

    for y in range(H):
        for x in range(W):
            corner = (x in (0, W - 1)) and (y in (0, H - 1))
            if corner:
                continue
            edge = x in (0, W - 1) or y in (0, H - 1)
            # Rounded corners: the pixels next to each corner are outline.
            near = (x in (1, W - 2)) and (y in (1, H - 2))
            if edge or near:
                put(x, y, "outline")
            elif y >= H - 3:
                put(x, y, "rim")
            elif y == 1 or y == 2:
                put(x, y, "light")
            elif y >= H - 6:
                put(x, y, "shade")
            else:
                put(x, y, "body")
    # A small glint at the top left.
    for x, y in ((3, 2), (4, 2), (2, 3)):
        put(x, y, "glint")

    def word(text, top):
        width = len(text) * 4 - 1
        left = (W - width) // 2
        for i, ch in enumerate(text):
            for dy, row in enumerate(FONT[ch]):
                for dx, bit in enumerate(row):
                    if bit == "1":
                        put(left + i * 4 + dx, top + dy, "text")

    word("LEVEL", 3)
    word("UP", 9)
    return img.resize((W * SCALE, H * SCALE), Image.NEAREST)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lit, off = draw(LIT), draw(OFF)
    lit.save(OUT / "levelup.png")
    off.save(OUT / "levelup_off.png")
    print("wrote", OUT / "levelup.png", OUT / "levelup_off.png")
    if "--preview" in sys.argv:
        sheet = Image.new("RGBA", (W * SCALE * 2 + 30, H * SCALE + 20), (255, 243, 220, 255))
        sheet.alpha_composite(lit, (10, 10))
        sheet.alpha_composite(off, (W * SCALE + 20, 10))
        path = ROOT / "build" / "preview" / "levelup_button.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(path)
        print("preview", path)


if __name__ == "__main__":
    main()
