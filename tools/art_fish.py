"""Bungeoppang sprites (96x72): six flavours x four patterns, plus toppings.

Toppings are separate 96x72 overlays that fit any flavour, so their shapes
use the same BODY geometry as the fish.
"""

import random

import numpy as np

from pixel_kit import Sprite, arc_points, edge, heart, shifted, soft_shade, sparkle, star_points

FISH_W, FISH_H = 96, 72

# highlight, light, base, shade, outline, filling, blush, mouth
# Flavours were removed in stage 14; redbean is the only bungeoppang.
FISH_SKINS = {
    "redbean": ("cream", "honey_light", "honey", "caramel", "crust_line", "wine", "blush", "crust_line"),
}
FISH_PATTERNS = ["scales", "heartscale", "starmark", "crispgrid"]
FISH_TOPPINGS = ["sugar", "choco", "almond", "sprinkle"]


def body_mask(s):
    return s.ellipse(57, 37, 30, 22)


def silhouette(s):
    body = body_mask(s)
    tail = s.poly([(33, 29), (14, 13), (8, 14), (8, 20), (17, 36), (8, 52), (8, 58), (14, 59), (33, 45)])
    fin = s.poly([(41, 19), (47, 10), (56, 8), (66, 11), (71, 18)])
    belly = s.poly([(47, 55), (51, 64), (58, 64), (63, 56)])
    return body, body | tail | fin | belly


def fish(skin, pattern="scales"):
    hi, light, base, shade, line, filling, blush, mouth = FISH_SKINS[skin]
    s = Sprite(FISH_W, FISH_H)
    body, sil = silhouette(s)
    extra = s.empty()
    if skin == "custard":  # a cream drip under the belly
        extra = s.rrect(53, 57, 4, 9, 2)
    if skin == "matcha":  # a little tea leaf on the head
        extra = s.poly([(73, 17), (77, 8), (82, 10), (78, 17)])
    soft_shade(s, sil, (hi, light, base, shade))
    # Soft round specular on the upper back.
    s.fill(s.ellipse(52, 22, 9, 2.6) & body, hi)
    s.fill(s.ellipse(47, 22, 3, 1.5) & body, "white" if skin != "cocoa" else "choco0")
    # Tail fan ribs and the tail joint.
    for a, b in [((13, 17), (29, 31)), ((11, 36), (29, 37)), ((13, 55), (29, 43))]:
        s.fill(s.line([a, b]) & sil & ~edge(sil, 0, 1), shade)
    s.pixels(arc_points(38, 37, 5, 12, -60, 60), shade)
    inner = body & ~edge(body, 0, 4) & ~edge(body, 0, -4) & (s.xs > 38) & (s.xs < 67)
    draw_pattern(s, pattern, skin, inner, light, shade)
    # Gill.
    s.pixels(arc_points(68, 37, 5, 13, -62, 62), shade)
    # Filling peeking out of the belly seam.
    for x in range(38, 47):
        col = np.nonzero(sil[:, x])[0]
        if len(col):
            s.put(x, col.max(), filling)
            if 40 <= x <= 44:
                s.put(x, col.max() - 1, filling)
    if skin == "custard":
        s.fill(extra, "lemon")
        s.fill(extra & edge(extra, -1, 0), "glow")
    if skin == "matcha":
        s.fill(extra, "leaf2")
        s.fill(extra & edge(extra, -1, 0), "leaf1")
    face(s, blush, mouth)
    s.outline(line)
    if skin == "cocoa":  # cream sprinkles
        for x, y in [(45, 19), (52, 17), (59, 18), (63, 22), (49, 25), (56, 24)]:
            s.pixels([(x, y), (x + 1, y)], "cream")
    if skin == "sweetpotato":  # curly steam
        for x0 in (70, 77):
            s.pixels([(x0, 9), (x0 + 1, 8), (x0 + 1, 7), (x0, 6), (x0, 5), (x0 + 1, 4), (x0 + 1, 3)], "mist")
    return s


def face(s, blush, mouth):
    # Big glossy eye: dark oval, two highlights.
    s.art(73, 24, [
        ".kkkk.",
        "kwwkkk",
        "kwwkkk",
        "kkkkkk",
        "kkkkwk",
        ".kkkk.",
    ], {"k": "ink", "w": "white"})
    # Round blush with a tiny shine.
    s.fill(s.ellipse(71.5, 35, 3.6, 1.8), blush)
    s.put(70, 34, "white")
    # Small "w" mouth.
    s.pixels([(80, 35), (81, 36), (82, 35), (83, 36), (84, 35)], mouth)


def draw_pattern(s, pattern, skin, inner, light, shade):
    if pattern == "starmark":
        star = s.poly(star_points(53, 37, 11, 5))
        s.fill(star & inner, shade)
        s.fill(star & inner & edge(star, 0, -1), light)
        s.fill(s.poly(star_points(53, 37, 6, 2.6)) & inner, light)
        return
    if pattern == "crispgrid":
        grid = inner & (((s.xs + s.ys) % 10 == 0) | ((s.xs - s.ys) % 10 == 0))
        s.fill(grid, shade)
        s.fill(shifted(grid, 0, 1) & inner & ~grid, light)
        return
    for r, y0 in enumerate([24, 32, 40]):
        for c in range(4):
            x0 = 41 + c * 7 + (r % 2) * 3
            pts = [(x0, y0), (x0, y0 + 1), (x0 + 1, y0 + 2), (x0 + 2, y0 + 2), (x0 + 3, y0 + 2),
                   (x0 + 4, y0 + 1), (x0 + 4, y0)]
            if not all(inner[y, x] for x, y in pts):
                continue
            if pattern == "heartscale":
                heart(s, x0, y0, "berry" if skin == "strawberry" else "pink3")
                s.put(x0 + 1, y0, "pink1")
                continue
            if skin == "strawberry":  # seeds instead of scales
                s.pixels([(x0 + 1, y0), (x0 + 3, y0 + 2)], "lemon")
                s.pixels([(x0 + 1, y0 + 1), (x0 + 3, y0 + 3)], "pink3")
                continue
            s.pixels(pts, shade)
            s.pixels([(x0 + 1, y0 + 3), (x0 + 2, y0 + 3), (x0 + 3, y0 + 3)], light)


def topping(kind):
    s = Sprite(FISH_W, FISH_H)
    body = body_mask(s)
    back = body & (s.ys < 27) & (s.xs > 38) & (s.xs < 68)  # top of the back, clear of the face
    rng = random.Random(kind)
    spots = [(x, y) for y in range(s.h) for x in range(s.w) if back[y, x]]
    if kind == "sugar":
        for x, y in rng.sample(spots, 70):
            s.put(x, y, "white" if rng.random() < .65 else "snow")
        for x, y in rng.sample(spots, 4):
            sparkle(s, x, y)
    elif kind == "choco":
        wave = [(x, 18 + (0, 1, 2, 2, 1, 0)[x % 6]) for x in range(38, 68)]
        wave = [(x, y) for x, y in wave if body[y, x]]
        for x, y in wave:
            s.fill(s.rect(x, y, 1, 2), "choco3")
            s.put(x, y, "choco2")
        for x, y in wave[3::7]:  # drips
            s.fill(s.rrect(x - 1, y + 2, 3, 5, 1), "choco3")
            s.put(x - 1, y + 2, "choco2")
        s.outline("choco4")
    elif kind == "almond":
        slices = s.empty()
        for cx, cy, tilt in [(42, 22, 1), (49, 17, -1), (57, 16, 1), (64, 19, -1), (53, 23, 1)]:
            m = s.ellipse(cx + .5, cy + .5, 3.5, 2) | s.ellipse(cx + .5 + tilt, cy - .5, 2.5, 1.5)
            s.fill(m, "cream")
            s.fill(m & edge(m, 0, 1), "wood0")
            slices |= m
        s.outline("wood2", mask=slices)
    elif kind == "sprinkle":
        colors = ["pink3", "sea2", "mint3", "lilac3", "lemon", "coral"]
        placed = 0
        for x, y in rng.sample(spots, len(spots)):
            dx, dy = rng.choice([(1, 0), (0, 1), (1, 1), (1, -1)])
            end = (x + 2 * dx, y + 2 * dy)
            near = s.a[max(y - 2, 0):y + 4, max(x - 2, 0):x + 5, 3]
            if placed == 24 or not back[end[1], end[0]] or near.any():
                continue
            s.pixels([(x, y), (x + dx, y + dy), end], colors[placed % len(colors)])
            placed += 1
    return s
