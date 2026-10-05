"""Draws every pixel-art image of the game into assets/images/.

The art is authored in code: filled shapes on the shared palette
(tools/palette.py), simple top-left lighting, then an automatic 1-pixel
outline, so every sprite shares one look. An AI image processed with
tools/pixelize.py into the same path replaces any of these files.

Scene layout (backgrounds 180x400, bottom-aligned in the game) must match
lib/ui/pixel_sprites.dart.

Run:  python tools/draw_pixel_assets.py [--preview DIR]
"""

import argparse
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from palette import PALETTE

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "images"
SCENE_W, SCENE_H = 180, 400
COUNTER_TOP = 304


def rgba(name):
    h = PALETTE[name]
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


def shifted(m, dx, dy):
    """out[y, x] = m[y + dy, x + dx]; outside the image counts as empty."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(dy, h), slice(0, h - dy)) if dy >= 0 else (slice(0, h + dy), slice(-dy, h))
    xs, xd = (slice(dx, w), slice(0, w - dx)) if dx >= 0 else (slice(0, w + dx), slice(-dx, w))
    out[yd, xd] = m[ys, xs]
    return out


def edge(m, dx, dy):
    """Pixels of `m` whose neighbour in direction (dx, dy) is outside `m`."""
    return m & ~shifted(m, dx, dy)


class Sprite:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)
        self.ys, self.xs = np.mgrid[0:h, 0:w]

    # masks
    def ellipse(self, cx, cy, rx, ry):
        return ((self.xs + .5 - cx) / rx) ** 2 + ((self.ys + .5 - cy) / ry) ** 2 <= 1

    def rect(self, x, y, w, h):
        return (self.xs >= x) & (self.xs < x + w) & (self.ys >= y) & (self.ys < y + h)

    def poly(self, pts):
        im = Image.new("1", (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon(pts, fill=1, outline=1)
        return np.array(im, bool)

    def line(self, pts, width=1):
        im = Image.new("1", (self.w, self.h), 0)
        ImageDraw.Draw(im).line(pts, fill=1, width=width)
        return np.array(im, bool)

    def checker(self, phase=0):
        return (self.xs + self.ys + phase) % 2 == 0

    @property
    def solid(self):
        return self.a[..., 3] > 0

    # painting
    def fill(self, mask, color):
        self.a[mask] = rgba(color)

    def put(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = rgba(color)

    def pixels(self, pts, color):
        for x, y in pts:
            self.put(x, y, color)

    def outline(self, color="outline", mask=None):
        m = self.solid if mask is None else mask
        ring = shifted(m, 1, 0) | shifted(m, -1, 0) | shifted(m, 0, 1) | shifted(m, 0, -1)
        self.fill(ring & ~m & (~self.solid if mask is None else ~m), color)

    def art(self, x, y, rows, colors):
        """Stamp ASCII art; '.' is transparent."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.put(x + i, y + j, colors[ch])

    def paste(self, other, x, y):
        for j in range(other.h):
            for i in range(other.w):
                if other.a[j, i, 3] and 0 <= x + i < self.w and 0 <= y + j < self.h:
                    self.a[y + j, x + i] = other.a[j, i]

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.a, "RGBA").save(path)


def shade_body(s, m, light, base, shade):
    """Base fill, 2px highlight on top/left, 2px shade at bottom/right."""
    s.fill(m, base)
    s.fill(edge(m, 0, -2) | edge(m, -1, 0), light)
    s.fill(edge(m, 0, 2) | edge(m, 1, 0), shade)


def arc_points(cx, cy, rx, ry, a0, a1, steps=40):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        p = (round(cx + rx * math.cos(a) - .5), round(cy + ry * math.sin(a) - .5))
        if p not in pts:
            pts.append(p)
    return pts


# ---------------------------------------------------------------- fish

FISH_SKINS = {
    # light, base, shade, filling, outline
    "redbean": ("butter", "gold", "toast", "wine", "outline"),
    "custard": ("light", "butter", "gold", "cream", "outline"),
    "cocoa": ("toast", "cocoa", "wood_dark", "deep", "deep"),
    "sweetpotato": ("peach", "orange", "toast", "lavender", "outline"),
    "matcha": ("cream", "mint", "green", "forest", "outline"),
    "strawberry": ("snow", "pink", "rose", "red", "outline"),
}


def fish(skin):
    light, base, shade, filling, line = FISH_SKINS[skin]
    s = Sprite(64, 48)
    body = s.ellipse(38.5, 25, 20.5, 14.5)
    tail = s.poly([(21, 21), (7, 10), (4, 12), (5, 15), (10, 24), (5, 33), (4, 36), (7, 38), (21, 29)])
    fin = s.poly([(27, 13), (32, 7), (38, 6), (45, 9), (47, 13)])
    belly = s.poly([(31, 36), (34, 42), (39, 42), (42, 37)])
    sil = body | tail | fin | belly
    if skin == "custard":
        sil |= s.rect(36, 39, 3, 4) | s.rect(37, 43, 2, 1)
    if skin == "matcha":
        sil |= s.poly([(49, 12), (52, 6), (55, 8), (52, 12)])
    shade_body(s, sil, light, base, shade)
    if skin == "custard":
        s.fill(s.rect(36, 39, 3, 4) | s.rect(37, 43, 2, 1), filling)
    if skin == "matcha":
        s.fill(s.poly([(50, 11), (52, 7), (54, 8), (52, 11)]), "green")
    # Tail ribs and the joint where the tail meets the body.
    for a, b in [((8, 13), (18, 22)), ((7, 24), (18, 25)), ((8, 35), (18, 28))]:
        s.fill(s.line([a, b]) & sil, shade)
    s.pixels(arc_points(25, 25, 4, 8, -60, 60), shade)
    # Embossed scales: shade arc with a highlight underneath.
    inner = body & ~edge(body, 0, 3) & ~edge(body, 0, -3)
    for r, y0 in enumerate([15, 21, 27]):
        for c in range(4):
            x0 = 23 + c * 6 + (r % 2) * 3
            pts = [(x0, y0), (x0 + 1, y0 + 1), (x0 + 2, y0 + 1), (x0 + 3, y0)]
            if x0 + 3 > 43 or not all(inner[y, x] for x, y in pts):
                continue
            if skin == "strawberry":  # seeds instead of scales
                s.pixels([(x0 + 1, y0), (x0 + 2, y0 + 1)], "red")
                s.put(x0 + 1, y0 + 1, "light")
                continue
            s.pixels(pts, shade)
            s.pixels([(x0 + 1, y0 + 2), (x0 + 2, y0 + 2)], light)
    # Gill line.
    s.pixels(arc_points(42, 25, 4, 9, -65, 65), shade)
    # Face: tall eye with a shine, blush, small smile.
    s.pixels([(51, 19), (52, 19), (51, 20), (52, 20), (51, 21), (52, 21)], line)
    s.put(51, 19, "snow")
    s.pixels([(48, 24), (49, 24), (50, 24)], "rose" if skin == "strawberry" else "pink")
    s.pixels([(54, 26), (55, 27), (56, 26)], line)
    # Filling leaking from the belly seam.
    for x in range(25, 31):
        col = np.nonzero(sil[:, x])[0]
        if len(col):
            s.put(x, col.max(), filling)
            if x in (27, 28):
                s.put(x, col.max() - 1, filling)
    s.outline(line)
    if skin == "cocoa":
        s.pixels([(30, 12), (35, 11), (40, 13), (33, 15), (45, 15)], "cream")
    if skin == "sweetpotato":
        s.pixels([(48, 8), (49, 7), (49, 6), (48, 5), (48, 4), (49, 3), (52, 7), (53, 6), (53, 5)], "grey")
    return s


# ---------------------------------------------------------------- scenes

def sky(s, bands):
    """bands: [(color, y_end)]; 2-row dithered transitions between bands."""
    y0 = 0
    for i, (color, y1) in enumerate(bands):
        s.fill(s.rect(0, y0, s.w, y1 - y0), color)
        if i:
            prev = bands[i - 1][0]
            s.fill(s.rect(0, y0, s.w, 1) & s.checker(), prev)
            s.fill(s.rect(0, y0 + 1, s.w, 1) & s.checker() & (s.xs % 4 == y0 % 2), prev)
        y0 = y1


def stars(s, rng, count, y_max, colors=("snow", "light", "ice"), twinkles=4):
    for _ in range(count):
        s.put(rng.randrange(s.w), rng.randrange(y_max), rng.choice(colors))
    for _ in range(twinkles):
        x, y = rng.randrange(6, s.w - 6), rng.randrange(6, y_max - 6)
        s.pixels([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], "ice")
        s.put(x, y, "snow")


def moon(s, cx, cy, r, color="light", crescent=True):
    m = s.ellipse(cx, cy, r, r)
    if crescent:
        m &= ~s.ellipse(cx + r * .55, cy - r * .35, r * .9, r * .9)
    s.fill(m, color)
    s.fill(edge(m, 0, -1) & edge(m, -1, 0), "snow")


def sag(x, x0, x1, y0, depth):
    t = (x - x0) / (x1 - x0)
    return round(y0 + depth * 4 * t * (1 - t))


def wire(s, y0, depth, color="deep", x0=0, x1=None):
    x1 = s.w if x1 is None else x1
    for x in range(x0, x1):
        s.put(x, sag(x, x0, x1, y0, depth), color)


def string_lights(s, y0, depth, step=15, colors=("light", "orange")):
    wire(s, y0, depth)
    for i, x in enumerate(range(step // 2, s.w, step)):
        y = sag(x, 0, s.w, y0, depth)
        c = colors[i % len(colors)]
        s.pixels([(x, y + 1), (x + 1, y + 1), (x, y + 2), (x + 1, y + 2)], c)
        s.pixels([(x - 1, y + 3), (x + 2, y + 3), (x - 1, y), (x + 2, y)], "plum")


def houses(s, rng, ground, body, roof, window_on, window_off, lit=.45, snow=False, h_range=(36, 80)):
    x = -6
    while x < s.w:
        w = rng.randrange(20, 34)
        h = rng.randrange(*h_range)
        top = ground - h
        s.fill(s.rect(x, top, w, h), body)
        s.fill(s.rect(x, top, 1, h), roof)
        if rng.random() < .55:  # pitched roof
            peak = rng.randrange(6, 12)
            s.fill(s.poly([(x - 2, top), (x + w // 2, top - peak), (x + w + 1, top)]), roof)
            if snow:
                s.fill(s.poly([(x - 2, top), (x + w // 2, top - peak), (x + w + 1, top)])
                       & ~shifted(s.poly([(x - 2, top), (x + w // 2, top - peak), (x + w + 1, top)]), 0, -3), "snow")
        else:  # flat roof with a ledge
            s.fill(s.rect(x - 1, top - 2, w + 2, 2), roof)
            if snow:
                s.fill(s.rect(x - 1, top - 4, w + 2, 2), "snow")
        for wy in range(top + 6, ground - 8, 12):
            for wx in range(x + 4, x + w - 5, 8):
                on = rng.random() < lit
                s.fill(s.rect(wx, wy, 4, 5), window_on if on else window_off)
                if on:
                    s.fill(s.rect(wx, wy, 4, 1), "cream")
                    s.fill(s.rect(wx, wy + 2, 4, 1), roof)
        x += w + rng.randrange(0, 4)


def pavement(s, top, color, line, bottom=SCENE_H):
    s.fill(s.rect(0, top, s.w, bottom - top), color)
    for y in range(top + 3, bottom, 5):
        s.fill(s.rect(0, y, s.w, 1), line)
        off = (y // 5) % 2 * 6
        for x in range(off, s.w, 12):
            s.fill(s.rect(x, y - 4, 1, 4), line)


def pine(s, cx, base, height, dark, mid, light):
    layers = 4
    for i in range(layers):
        y_top = base - height + i * height // (layers + 1)
        y_bot = y_top + height * 2 // 5
        half = 6 + i * 4
        tri = s.poly([(cx, y_top), (cx - half, y_bot), (cx + half, y_bot)])
        s.fill(tri, mid)
        s.fill(tri & (s.xs > cx), dark)
        s.fill(edge(tri, -1, 0) & (s.xs < cx), light)
    s.fill(s.rect(cx - 1, base - height // 5, 3, height // 5), "wood_dark")


def cloud_tree(s, rng, cx, base, size, dark, mid, light, trunk="cocoa"):
    s.fill(s.rect(cx - 2, base - size, 4, size), trunk)
    s.fill(s.line([(cx, base - size // 2), (cx - size // 3, base - size)], 2), trunk)
    crown = np.zeros((s.h, s.w), bool)
    for _ in range(7):
        crown |= s.ellipse(cx + rng.randrange(-size // 2, size // 2), base - size - rng.randrange(0, size // 2),
                           rng.randrange(size // 4, size // 2), rng.randrange(size // 5, size // 3))
    s.fill(crown, mid)
    s.fill(crown & edge(crown, 0, 3), dark)
    s.fill(crown & edge(crown, 0, -2) & s.checker(), light)
    s.fill(crown & ~edge(crown, 0, 3) & ((s.xs + s.ys * 3) % 11 == 0), light)


def scene_night():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(1)
    sky(s, [("night", 70), ("navy", 170), ("navy2", 300)])
    stars(s, rng, 70, 200)
    moon(s, 142, 46, 11)
    houses(s, rng, 300, "navy", "purple", "light", "navy2")
    wire(s, 168, 16)
    s.fill(s.rect(150, 150, 3, 150), "deep")
    s.fill(s.rect(146, 154, 11, 2), "deep")
    string_lights(s, 126, 26)
    pavement(s, 296, "stone", "outline")
    return s


def scene_dusk():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(2)
    sky(s, [("purple", 70), ("plum", 130), ("rose", 180), ("pink", 220), ("peach", 250), ("orange", 300)])
    stars(s, rng, 25, 80, ("snow", "pink"), 2)
    s.fill(s.ellipse(120, 252, 20, 20) & (s.ys < 252), "light")
    houses(s, rng, 300, "purple", "navy2", "orange", "plum", lit=.3)
    pavement(s, 296, "plum", "purple")
    return s


def scene_forest():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(3)
    sky(s, [("night", 60), ("navy", 150), ("forest_dark", 300)])
    stars(s, rng, 45, 150)
    moon(s, 40, 44, 10, crescent=False)
    s.fill(s.ellipse(37, 41, 2, 2) | s.ellipse(44, 48, 2, 1.5), "butter")
    for x in range(-4, SCENE_W + 10, 22):
        pine(s, x, 262, rng.randrange(60, 85), "night", "navy2", "purple")
    for x in range(8, SCENE_W + 10, 34):
        pine(s, x + rng.randrange(-4, 4), 300, rng.randrange(75, 100), "forest_dark", "forest", "green")
    for _ in range(26):
        x, y = rng.randrange(SCENE_W), rng.randrange(160, 290)
        s.put(x, y, "light")
        s.put(x, y + 1, "butter")
    s.fill(s.rect(0, 296, SCENE_W, 104), "wood")
    s.fill(s.rect(0, 296, SCENE_W, 2), "green")
    for x in range(3, SCENE_W, 9):
        s.put(x, 300 + x % 5, "toast")
    return s


def scene_snow():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(4)
    sky(s, [("navy", 60), ("navy2", 160), ("dusk_blue", 300)])
    houses(s, rng, 300, "navy2", "purple", "orange", "navy", lit=.5, snow=True)
    s.fill(s.rect(0, 294, SCENE_W, 106), "snow")
    s.fill(s.rect(0, 294, SCENE_W, 106) & s.checker() & (s.ys % 3 == 0), "ice")
    for _ in range(140):
        x, y = rng.randrange(SCENE_W), rng.randrange(292)
        s.put(x, y, "snow" if rng.random() < .7 else "ice")
    for _ in range(18):
        x, y = rng.randrange(2, SCENE_W - 2), rng.randrange(2, 280)
        s.pixels([(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], "snow")
    return s


def scene_cherry():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(5)
    sky(s, [("navy", 60), ("purple", 170), ("plum", 300)])
    stars(s, rng, 35, 140, ("snow", "pink"), 3)
    moon(s, 136, 50, 10)
    houses(s, rng, 300, "navy2", "purple", "light", "navy", lit=.35, h_range=(30, 60))
    for cx in (18, 70, 128, 172):
        cloud_tree(s, rng, cx + rng.randrange(-4, 4), 296, rng.randrange(44, 60), "rose", "pink", "cream")
    string_lights(s, 120, 22, colors=("light", "pink"))
    for _ in range(60):
        x, y = rng.randrange(SCENE_W), rng.randrange(290)
        s.put(x, y, "pink")
        if rng.random() < .4:
            s.put(x + 1, y, "rose")
    pavement(s, 296, "plum", "purple")
    return s


def scene_seaside():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(6)
    sky(s, [("night", 70), ("navy", 170), ("navy2", 215)])
    stars(s, rng, 60, 200)
    moon(s, 128, 70, 12, crescent=False)
    s.fill(s.ellipse(124, 66, 3, 2) | s.ellipse(133, 75, 2, 2), "butter")
    s.fill(s.rect(0, 215, SCENE_W, 85), "navy2")
    s.fill(s.rect(0, 215, SCENE_W, 85) & s.checker() & (s.ys > 255), "teal")
    for _ in range(40):
        x, y = rng.randrange(SCENE_W), rng.randrange(218, 296)
        s.fill(s.rect(x, y, rng.randrange(3, 7), 1), "dusk_blue")
    for i, y in enumerate(range(218, 296, 4)):
        w = max(2, 14 - i // 2)
        s.fill(s.rect(128 - w // 2 + rng.randrange(-1, 2), y, w, 1), "light" if i % 3 else "butter")
    # Lighthouse on a distant cape.
    s.fill(s.poly([(0, 216), (0, 206), (30, 206), (44, 216)]), "navy")
    tower = s.poly([(14, 206), (16, 160), (24, 160), (26, 206)])
    s.fill(tower, "snow")
    for y in (168, 182, 196):
        s.fill(tower & s.rect(0, y, SCENE_W, 6), "red")
    s.fill(s.rect(15, 152, 10, 8), "navy")
    s.fill(s.rect(17, 153, 6, 6), "light")
    s.fill(s.poly([(16, 150), (20, 145), (24, 150)]), "red")
    s.fill(s.poly([(25, 153), (60, 146), (60, 162), (25, 158)]) & s.checker(), "light")
    string_lights(s, 238, 18)
    # Boardwalk.
    s.fill(s.rect(0, 296, SCENE_W, 104), "wood")
    for y in range(298, SCENE_H, 4):
        s.fill(s.rect(0, y, SCENE_W, 1), "wood_dark")
    s.fill(s.rect(0, 296, SCENE_W, 1), "toast")
    return s


def counter(snow=False):
    s = Sprite(SCENE_W, SCENE_H - COUNTER_TOP)
    s.fill(s.rect(0, 0, s.w, s.h), "wood")
    for x in range(0, s.w, 18):
        s.fill(s.rect(x, 5, 1, s.h), "wood_dark")
        s.fill(s.rect(x + 1, 5, 1, s.h), "cocoa")
    s.fill(s.rect(0, 0, s.w, 5), "toast")
    s.fill(s.rect(0, 0, s.w, 1), "gold")
    s.fill(s.rect(0, 5, s.w, 1), "outline")
    # Striped cloth skirt hanging under the board.
    for x in range(0, s.w, 12):
        s.fill(s.rect(x, 6, 6, 8), "red")
        s.fill(s.rect(x + 6, 6, 6, 8), "cream")
        s.fill(s.rect(x + 1, 14, 4, 1), "red")
        s.fill(s.rect(x + 7, 14, 4, 1), "cream")
    if snow:
        s.fill(s.rect(0, 0, s.w, 2), "snow")
        for x in range(2, s.w, 9):
            s.fill(s.rect(x, 2, 3, 1), "snow")
    return s


# ---------------------------------------------------------------- stoves

STOVES = {
    # light, base, shade, plate, extras
    "iron": ("grey", "stone", "outline", "deep"),
    "copper": ("peach", "orange", "toast", "wood_dark"),
    "castiron": ("stone", "outline", "deep", "deep"),
    "golden": ("light", "butter", "gold", "toast"),
}


def mini_fish(s, x, y, light="butter", base="gold", eye="deep"):
    s.art(x, y, [
        "..oooooo..",
        ".obbgggggo",
        "oobggggkgo",
        "ogggggggo.",
        "oogggggo..",
        ".o.ooooo..",
    ], {"o": "outline", "b": light, "g": base, "k": eye})


def stove(kind):
    light, base, shade, plate = STOVES[kind]
    s = Sprite(80, 40)
    box = s.rect(4, 16, 72, 20) | s.rect(5, 15, 70, 1) | s.rect(5, 36, 70, 1)
    shade_body(s, box, light, base, shade)
    s.fill(s.rect(8, 37, 4, 3) | s.rect(68, 37, 4, 3), shade)
    # Mold plate with three fish cavities.
    s.fill(s.rect(6, 13, 68, 4), plate)
    s.fill(s.rect(6, 13, 68, 1), light)
    for i, x in enumerate((10, 34, 58)):
        s.fill(s.rect(x - 1, 9, 14, 7), plate)
        mini_fish(s, x + 1, 9)
    # Fire window with embers.
    win = s.rect(14, 24, 52, 8)
    s.fill(win, "deep")
    s.fill(win & (s.ys >= 29) & s.checker(), "orange")
    s.fill(win & (s.ys >= 30), "red")
    s.fill(win & (s.ys == 31) & s.checker(1), "orange")
    s.fill(s.rect(14, 24, 52, 1), shade)
    if kind == "castiron":
        for x in range(8, 74, 8):
            s.put(x, 19, "grey")
            s.put(x, 34, "grey")
    if kind == "copper":
        s.fill(s.rect(6, 20, 68, 1), "peach")
    if kind == "golden":
        for x, y in [(6, 17), (40, 22), (71, 18), (24, 34)]:
            s.pixels([(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], "snow")
    s.outline()
    for x in (16, 40, 64):  # steam
        s.pixels([(x, 6), (x + 1, 5), (x + 1, 4), (x, 3), (x, 2), (x + 1, 1)], "grey")
    return s


# ---------------------------------------------------------------- decorations

def lantern():
    s = Sprite(14, 24)
    body = s.ellipse(7, 13, 6, 6.5)
    s.fill(body, "orange")
    s.fill(body & s.ellipse(6, 12, 3.5, 4.5), "light")
    s.fill(body & s.ellipse(6, 12, 3.5, 4.5) & s.checker() & ~s.ellipse(6, 11, 2, 3), "butter")
    s.fill(body & ((s.xs == 3) | (s.xs == 10)), "red")
    s.fill(s.rect(4, 5, 6, 2) | s.rect(4, 19, 6, 2), "wine")
    s.fill(s.rect(6, 21, 2, 2), "red")
    s.outline()
    s.fill(s.rect(6, 0, 2, 4), "grey")
    s.fill(s.rect(6, 23, 2, 1), "red")
    return s


def windchime():
    s = Sprite(14, 30)
    bell = s.poly([(4, 6), (9, 6), (11, 13), (2, 13)])
    shade_body(s, bell, "butter", "gold", "toast")
    s.fill(s.rect(1, 13, 12, 1), "toast")
    s.outline()
    mini_fish(s, 2, 18, light="snow", base="sky", eye="outline")
    s.fill(s.rect(6, 0, 1, 5), "grey")
    s.fill(s.rect(6, 15, 1, 3), "grey")
    return s


def bunting():
    s = Sprite(SCENE_W, 22)
    colors = ["pink", "butter", "mint", "sky"]
    flags = np.zeros((s.h, s.w), bool)
    for i, x in enumerate(range(4, SCENE_W - 6, 14)):
        y = sag(x + 4, 0, SCENE_W, 2, 8)
        tri = s.poly([(x, y + 1), (x + 8, y + 1), (x + 4, y + 9)])
        s.fill(tri, colors[i % 4])
        s.fill(tri & edge(tri, 1, 0), "cream" if colors[i % 4] != "butter" else "light")
        flags |= tri
    s.outline(mask=flags)
    wire(s, 2, 8, "outline")
    return s


def starlights():
    s = Sprite(SCENE_W, 24)
    bulbs = np.zeros((s.h, s.w), bool)
    for i, x in enumerate(range(10, SCENE_W, 20)):
        y = sag(x, 0, SCENE_W, 2, 10) + 3
        star = s.poly([(x, y - 3), (x + 1, y - 1), (x + 3, y), (x + 1, y + 1), (x, y + 3),
                       (x - 1, y + 1), (x - 3, y), (x - 1, y - 1)])
        s.fill(star, "butter" if i % 2 else "light")
        s.put(x, y, "cream")
        bulbs |= star
    s.outline(mask=bulbs)
    wire(s, 2, 10, "outline")
    for i, x in enumerate(range(10, SCENE_W, 20)):
        y = sag(x, 0, SCENE_W, 2, 10)
        s.fill(s.rect(x, y, 1, 2), "outline")
    return s


def snowman():
    s = Sprite(26, 34)
    low = s.ellipse(13, 24, 9, 8)
    top = s.ellipse(13, 12, 6.5, 6)
    body = low | top
    s.fill(body, "snow")
    s.fill((edge(low, 1, 0) | edge(low, 0, 2) | edge(top, 1, 0) | edge(top, 0, 2)) & body, "ice")
    s.pixels([(10, 11), (15, 11)], "outline")
    s.pixels([(9, 13), (16, 13)], "pink")
    s.pixels([(12, 13), (13, 13), (14, 13)], "orange")
    scarf = s.rect(7, 17, 13, 2) | s.rect(16, 19, 3, 5)
    s.fill(scarf, "red")
    s.fill(scarf & s.checker() & (s.ys == 18), "wine")
    s.fill(s.line([(5, 21), (1, 16)]), "toast")
    s.fill(s.rect(0, 13, 4, 3), "gold")
    s.put(0, 13, "butter")
    s.outline()
    return s


# ---------------------------------------------------------------- icons (24x24)

def icon_shop():
    s = Sprite(24, 24)
    for x in range(3, 21):
        s.fill(s.rect(x, 4, 1, 5), "red" if (x - 3) // 3 % 2 == 0 else "cream")
        if (x - 3) % 3 == 1:
            s.put(x, 9, "red" if (x - 3) // 3 % 2 == 0 else "cream")
    s.fill(s.rect(3, 4, 18, 1), "light")
    s.fill(s.rect(4, 10, 2, 6) | s.rect(18, 10, 2, 6), "toast")
    s.fill(s.rect(3, 15, 18, 5), "gold")
    s.fill(s.rect(3, 15, 18, 1), "butter")
    s.fill(s.rect(3, 19, 18, 1), "toast")
    s.art(9, 11, ["obbbo", "ggggk", "oggg."], {"o": "gold", "b": "butter", "g": "gold", "k": "outline"})
    s.outline()
    return s


def icon_skins():
    s = Sprite(24, 24)
    hanger = s.line([(12, 8), (3, 16), (3, 18), (20, 18), (20, 16), (12, 8)], 2)
    s.fill(hanger, "butter")
    s.fill(s.line([(12, 7), (12, 5), (13, 3), (15, 3), (16, 5)], 1), "gold")
    s.fill(s.poly([(8, 8), (12, 10), (8, 12)]) | s.poly([(16, 8), (12, 10), (16, 12)]), "pink")
    s.fill(s.rect(11, 9, 3, 3), "rose")
    s.outline()
    return s


def icon_records():
    s = Sprite(24, 24)
    s.fill(s.rect(5, 3, 15, 18), "cream")
    s.fill(s.rect(5, 3, 3, 18), "toast")
    s.fill(s.rect(19, 4, 1, 17), "grey")
    s.fill(s.rect(10, 13, 2, 5), "red")
    s.fill(s.rect(13, 10, 2, 8), "gold")
    s.fill(s.rect(16, 6, 2, 12), "green")
    s.fill(s.rect(9, 18, 10, 1), "toast")
    s.outline()
    return s


def icon_share():
    s = Sprite(24, 24)
    plane = s.poly([(3, 11), (20, 4), (14, 20), (10, 14)])
    s.fill(plane, "cream")
    s.fill(s.poly([(10, 14), (20, 4), (14, 20)]), "ice")
    s.fill(s.line([(10, 14), (20, 4)]), "grey")
    s.fill(s.poly([(10, 14), (10, 19), (13, 16)]), "dusk_blue")
    s.outline()
    return s


def icon_daily():
    s = Sprite(24, 24)
    s.fill(s.rect(5, 5, 14, 14), "cream")
    s.fill(s.rect(3, 3, 18, 3) | s.rect(3, 18, 18, 3), "butter")
    s.fill(s.rect(3, 5, 18, 1) | s.rect(3, 20, 18, 1), "gold")
    s.pixels([(7, 9), (8, 10), (9, 9), (10, 8)], "green")
    s.pixels([(7, 14), (8, 15), (9, 14), (10, 13)], "green")
    s.fill(s.rect(12, 9, 5, 1) | s.rect(12, 14, 5, 1), "toast")
    s.outline()
    return s


def icon_achievements():
    s = Sprite(24, 24)
    s.fill(s.poly([(6, 2), (10, 2), (13, 10), (9, 10)]), "red")
    s.fill(s.poly([(14, 2), (18, 2), (15, 10), (11, 10)]), "sky")
    medal = s.ellipse(12, 15, 6.5, 6.5)
    shade_body(s, medal, "light", "butter", "gold")
    s.fill(s.ellipse(12, 15, 4, 4) & ~s.ellipse(12, 15, 3, 3), "gold")
    s.pixels([(10, 15), (11, 14), (12, 14), (13, 15), (12, 16), (11, 16), (14, 14), (14, 16)], "toast")
    s.outline()
    return s


def icon_settings():
    s = Sprite(24, 24)
    gear = s.ellipse(12, 12, 7, 7)
    for a in range(0, 360, 45):
        cx = 12 + 8.2 * math.cos(math.radians(a))
        cy = 12 + 8.2 * math.sin(math.radians(a))
        gear |= s.ellipse(cx, cy, 2.2, 2.2)
    shade_body(s, gear, "cream", "butter", "gold")
    hole = s.ellipse(12, 12, 3, 3)
    s.a[hole] = 0
    s.outline()  # also rings the hole
    return s


def icon_leaderboard():
    s = Sprite(24, 24)
    shade_body(s, s.rect(9, 11, 6, 10), "light", "butter", "gold")
    shade_body(s, s.rect(3, 14, 6, 7), "snow", "grey", "stone")
    shade_body(s, s.rect(15, 16, 6, 5), "peach", "orange", "toast")
    crown = s.poly([(8, 9), (8, 4), (10, 6), (12, 3), (14, 6), (16, 4), (16, 9)])
    s.fill(crown, "butter")
    s.put(12, 7, "red")
    s.outline()
    return s


def icon_star():
    s = Sprite(24, 24)
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 10 if i % 2 == 0 else 4.6
        pts.append((12 + r * math.cos(a), 12.5 + r * math.sin(a)))
    star = s.poly(pts) | s.ellipse(12, 13, 5, 5)
    shade_body(s, star, "light", "butter", "gold")
    s.pixels([(10, 12), (14, 12)], "outline")
    s.pixels([(9, 14), (15, 14)], "pink")
    s.pixels([(11, 14), (12, 15), (13, 14)], "outline")
    s.outline()
    return s


def icon_butter():
    s = Sprite(24, 24)
    top = s.poly([(4, 10), (12, 6), (20, 10), (12, 14)])
    left = s.poly([(4, 10), (12, 14), (12, 20), (4, 16)])
    right = s.poly([(12, 14), (20, 10), (20, 16), (12, 20)])
    s.fill(left, "butter")
    s.fill(right, "gold")
    s.fill(top, "light")
    s.pixels([(9, 9), (10, 9), (11, 8)], "cream")
    s.outline()
    for x, y in [(4, 4), (20, 5)]:
        s.pixels([(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], "snow")
    return s


ICONS = {
    "shop": icon_shop, "skins": icon_skins, "records": icon_records, "share": icon_share,
    "daily": icon_daily, "achievements": icon_achievements, "settings": icon_settings,
    "leaderboard": icon_leaderboard, "star": icon_star, "butter": icon_butter,
}


# ---------------------------------------------------------------- app icon

def app_icon():
    s, rng = Sprite(64, 64), random.Random(9)
    s.fill(s.rect(0, 0, 64, 64), "navy")
    s.fill(s.rect(0, 0, 64, 64) & (s.ys > 50) & s.checker(), "navy2")
    s.fill(s.rect(0, 54, 64, 10), "navy2")
    stars(s, rng, 12, 14, twinkles=0)
    ox, oy = 2, 10  # fish offset; the hat sits on its head
    s.paste(fish("redbean"), ox, oy)
    hat = Sprite(64, 64)
    dome = hat.ellipse(ox + 50, oy + 10, 7, 6) & (hat.ys < oy + 10)
    hat.fill(dome, "red")
    hat.fill(dome & hat.checker() & (hat.ys == oy + 7), "wine")
    hat.fill(hat.rect(ox + 42, oy + 9, 16, 3), "cream")
    hat.fill(hat.rect(ox + 42, oy + 10, 16, 1) & hat.checker(), "grey")
    hat.fill(hat.ellipse(ox + 50, oy + 2, 2.5, 2.5), "cream")
    hat.outline()
    s.paste(hat, 0, 0)
    return s


# ---------------------------------------------------------------- output

def build():
    out = {}
    for skin in FISH_SKINS:
        out[f"fish/{skin}.png"] = fish(skin)
    scenes = {"night": scene_night, "dusk": scene_dusk, "forest": scene_forest,
              "snow": scene_snow, "cherry": scene_cherry, "seaside": scene_seaside}
    for name, make in scenes.items():
        out[f"bg/{name}.png"] = make()
    out["stall/counter.png"] = counter()
    out["stall/counter_snow.png"] = counter(snow=True)
    for kind in STOVES:
        out[f"stove/{kind}.png"] = stove(kind)
    for name, make in {"lantern": lantern, "windchime": windchime, "bunting": bunting,
                       "starlights": starlights, "snowman": snowman}.items():
        out[f"deco/{name}.png"] = make()
    for name, make in ICONS.items():
        out[f"icons/{name}.png"] = make()
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
    p.add_argument("--preview", type=Path, help="also write 8x previews into this folder")
    p.add_argument("--only", help="comma-separated path prefixes to draw, e.g. fish,icons; "
                                  "'launcher' only rebuilds launcher icons from app/app_icon.png")
    args = p.parse_args()
    sprites = build()
    if args.only:
        prefixes = tuple(args.only.split(","))
        sprites = {k: v for k, v in sprites.items() if k.startswith(prefixes)}
    for rel, sprite in sprites.items():
        sprite.save(OUT / rel)
        if args.preview:
            scale = 3 if sprite.w >= 100 else 8
            path = args.preview / rel.replace("/", "_")
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.fromarray(sprite.a, "RGBA").resize((sprite.w * scale, sprite.h * scale),
                                                     Image.Resampling.NEAREST).save(path)
    only = args.only.split(",") if args.only else []
    if not only or "app" in only:
        app_icon().save(OUT / "app" / "app_icon.png")
    if not only or "app" in only or "launcher" in only:
        write_launcher_icons()
    print(f"wrote {len(sprites)} sprites to {OUT}")


if __name__ == "__main__":
    main()
