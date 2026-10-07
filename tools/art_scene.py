"""Stall scene: six backgrounds (180x400), the counter, stoves and decorations.

The sky stays dark enough at the top for the cream UI text; scenery gets
lighter toward the horizon. The lower part is hidden by the counter layer.
Positions must match lib/ui/night_stall_painter.dart.
"""

import random

from pixel_kit import Sprite, edge, glow, grow, heart, sag, soft_shade, sparkle, star_points

SCENE_W, SCENE_H = 180, 400
COUNTER_TOP = 304


# ---------------------------------------------------------------- pieces

def sky(s, bands):
    """bands: [(color, y_end)]; dithered 3-row transitions between bands."""
    y0 = 0
    for i, (color, y1) in enumerate(bands):
        s.fill(s.rect(0, y0, s.w, y1 - y0), color)
        if i:
            prev = bands[i - 1][0]
            s.fill(s.rect(0, y0, s.w, 1) & s.checker(), prev)
            s.fill(s.rect(0, y0 + 1, s.w, 1) & s.sparse(2), prev)
            s.fill(s.rect(0, y0 - 1, s.w, 1) & s.sparse(2, 1), color)
        y0 = y1


def stars(s, rng, count, y_max, colors=("white", "glow", "lilac1"), twinkles=5):
    for _ in range(count):
        s.put(rng.randrange(s.w), rng.randrange(y_max), rng.choice(colors))
    for _ in range(twinkles):
        x, y = rng.randrange(6, s.w - 6), rng.randrange(6, max(7, y_max - 6))
        sparkle(s, x, y, "glow", big=rng.random() < .4)
        s.put(x, y, "white")


def moon(s, cx, cy, r, halo=("dusk_deep", "twilight")):
    glow(s, cx, cy, r * 2.4, halo[1], halo[0])
    m = s.circle(cx, cy, r)
    s.fill(m, "glow")
    s.fill(m & edge(m, 2, 0) & edge(m, 0, 2), "lemon")
    s.fill(s.circle(cx + r * .3, cy + r * .2, r * .22) | s.circle(cx - r * .35, cy + r * .4, r * .15), "honey_light")
    # A sleepy face makes it storybook.
    s.pixels([(cx - 4, cy - 1), (cx - 3, cy), (cx - 2, cy - 1), (cx + 2, cy - 1), (cx + 3, cy), (cx + 4, cy - 1)], "caramel")
    s.fill(s.circle(cx - 5, cy + 3, 1.3) | s.circle(cx + 5, cy + 3, 1.3), "pink2")


def cloud(s, x, y, w, color, light, shade):
    m = s.empty()
    for i in range(0, w, 7):
        m |= s.circle(x + i + 4, y + (2 if i % 14 else 0), 5 + (i % 3))
    m |= s.rrect(x, y, w + 4, 8, 4)
    s.fill(m, color)
    s.fill(m & edge(m, 0, -2), light)
    s.fill(m & edge(m, 0, 2), shade)


def wire(s, y0, depth, color="night_deep", x0=0, x1=None):
    x1 = s.w if x1 is None else x1
    for x in range(x0, x1):
        s.put(x, sag(x, x0, x1, y0, depth), color)


def string_lights(s, y0, depth, step=14, colors=("glow", "pink1", "mint1", "sea0")):
    wire(s, y0, depth)
    for i, x in enumerate(range(step // 2, s.w, step)):
        y = sag(x, 0, s.w, y0, depth)
        c = colors[i % len(colors)]
        s.fill(s.rect(x - 2, y + 1, 5, 6) & s.sparse(2), "periwinkle")
        s.pixels([(x, y + 1), (x - 1, y + 2), (x, y + 2), (x + 1, y + 2), (x, y + 3)], c)
        s.put(x, y + 2, "white")


def window(s, x, y, w, h, lit, wall_shade):
    if lit:
        s.fill(s.rect(x - 2, y - 2, w + 4, h + 4) & s.sparse(2), "lemon")
        s.fill(s.rrect(x, y, w, h, 1), "glow")
        s.fill(s.rect(x, y + h - 2, w, 2), "lemon")
        s.fill(s.rect(x + w // 2, y, 1, h) | s.rect(x, y + h // 2, w, 1), "honey")
    else:
        s.fill(s.rrect(x, y, w, h, 1), wall_shade)


def houses(s, rng, ground, walls, roofs, lit=.55, snow=False, h_range=(34, 62)):
    x = -8
    while x < s.w:
        w = rng.randrange(22, 34)
        h = rng.randrange(*h_range)
        top = ground - h
        wall_hi, wall, wall_shade = rng.choice(walls)
        roof, roof_shade = rng.choice(roofs)
        body = s.rect(x, top, w, h)
        s.fill(body, wall)
        s.fill(body & edge(body, -2, 0), wall_hi)
        s.fill(body & edge(body, 2, 0), wall_shade)
        peak = rng.randrange(9, 15)
        roof_m = s.poly([(x - 3, top + 1), (x + w // 2, top - peak), (x + w + 2, top + 1)])
        roof_m |= s.rrect(x - 3, top - 1, w + 6, 4, 1)
        s.fill(roof_m, roof)
        s.fill(roof_m & edge(roof_m, 0, 2), roof_shade)
        if snow:
            s.fill(roof_m & edge(roof_m, 0, -3), "white")
            s.fill(roof_m & edge(roof_m, 0, -4) & ~edge(roof_m, 0, -3) & s.checker(), "snow")
        if rng.random() < .5:  # round attic window
            cx, cy = x + w // 2, top - peak // 3
            lit_attic = rng.random() < lit
            s.fill(s.circle(cx, cy, 2.3), "glow" if lit_attic else wall_shade)
        for wy in range(top + 6, ground - 9, 13):
            for wx in range(x + 4, x + w - 7, 10):
                window(s, wx, wy, 6, 7, rng.random() < lit, wall_shade)
        if rng.random() < .5:  # door
            dx = x + w // 2 - 3
            s.fill(s.rrect(dx, ground - 11, 7, 11, 3), roof_shade)
            s.put(dx + 5, ground - 6, "lemon")
        x += w + rng.randrange(1, 5)


def cobbles(s, top, base, gap, light, bottom=SCENE_H):
    s.fill(s.rect(0, top, s.w, bottom - top), gap)
    for row, y in enumerate(range(top + 1, bottom, 6)):
        off = (row % 2) * 5
        for x in range(-off, s.w, 10):
            stone = s.rrect(x + 1, y, 8, 5, 2)
            s.fill(stone, base)
            s.fill(stone & edge(stone, 0, -1), light)


def fluffy_tree(s, rng, cx, base, size, ramp, trunk=("wood2", "wood3")):
    hi, light, mid, dark = ramp
    s.fill(s.rect(cx - 2, base - size, 4, size), trunk[0])
    s.fill(s.rect(cx + 1, base - size, 1, size), trunk[1])
    crown = s.empty()
    for _ in range(7):
        crown |= s.circle(cx + rng.randrange(-size // 2, size // 2 + 1),
                          base - size - rng.randrange(0, size // 2), rng.randrange(size // 4, size // 3 + 2))
    s.fill(crown, mid)
    s.fill(crown & edge(crown, 0, 3), dark)
    s.fill(crown & edge(crown, 0, -2), light)
    s.fill(crown & edge(crown, 0, -1) & s.checker(), hi)
    return crown


def pine(s, cx, base, height, ramp):
    hi, light, mid, dark = ramp
    for i in range(4):
        y_top = base - height + i * height // 5
        y_bot = y_top + height * 2 // 5
        half = 6 + i * 4
        tri = s.poly([(cx, y_top), (cx - half, y_bot), (cx + half, y_bot)]) | s.rrect(cx - half, y_bot - 3, 2 * half, 4, 2)
        s.fill(tri, mid)
        s.fill(tri & (s.xs > cx + 1), dark)
        s.fill(tri & edge(tri, 0, -1) & (s.xs <= cx), light)
    s.fill(s.rect(cx - 1, base - height // 5, 3, height // 5), "wood3")


def firefly(s, x, y):
    s.fill(s.circle(x, y, 3) & s.sparse(2), "leaf1")
    s.put(x, y, "glow")
    s.put(x, y + 1, "lemon")


# ---------------------------------------------------------------- backgrounds

def scene_night():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(1)
    sky(s, [("night_deep", 100), ("dusk_deep", 180), ("twilight", 240), ("periwinkle", 300)])
    stars(s, rng, 70, 210)
    moon(s, 140, 52, 13)
    houses(s, rng, 300, [("lilac1", "lilac2", "lilac3"), ("pink1", "pink2", "pink3"), ("sea0", "sea1", "sea2")],
           [("pink3", "pink4"), ("lilac3", "lilac4"), ("peach2", "peach3")])
    string_lights(s, 128, 24)
    cobbles(s, 296, "lilac2", "lilac3", "lilac1")
    return s


def scene_dusk():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(2)
    sky(s, [("dusk_deep", 70), ("lilac4", 130), ("lilac3", 175), ("pink3", 212), ("pink2", 245), ("peach2", 275),
            ("peach1", 300)])
    stars(s, rng, 25, 90, ("white", "pink1"), 3)
    sun = s.circle(118, 262, 22) & (s.ys < 262)
    s.fill(s.circle(118, 262, 30) & (s.ys < 262) & s.sparse(2), "peach0")
    s.fill(sun, "glow")
    s.fill(sun & edge(sun, 0, 2), "lemon")
    cloud(s, 8, 150, 40, "pink1", "pink0", "pink2")
    cloud(s, 112, 120, 50, "pink1", "pink0", "pink2")
    cloud(s, 60, 200, 34, "peach1", "peach0", "peach2")
    houses(s, rng, 300, [("lilac2", "lilac3", "lilac4"), ("pink2", "pink3", "pink4")],
           [("lilac4", "dusk_deep"), ("pink4", "wine")], lit=.4)
    cobbles(s, 296, "pink2", "pink3", "pink1")
    return s


def scene_forest():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(3)
    sky(s, [("night_deep", 90), ("dusk_deep", 170), ("twilight", 230), ("leaf4", 300)])
    stars(s, rng, 45, 170)
    moon(s, 40, 56, 11)
    for x in range(-6, SCENE_W + 10, 24):
        pine(s, x, 262, rng.randrange(62, 86), ("leaf2", "leaf3", "leaf4", "dusk_deep"))
    for x in range(10, SCENE_W + 10, 38):
        fluffy_tree(s, rng, x + rng.randrange(-4, 5), 300, rng.randrange(40, 52), ("mint2", "leaf1", "leaf2", "leaf3"))
    for _ in range(18):
        firefly(s, rng.randrange(4, SCENE_W - 4), rng.randrange(150, 290))
    s.fill(s.rect(0, 296, SCENE_W, 104), "wood1")
    s.fill(s.rect(0, 296, SCENE_W, 3), "leaf2")
    s.fill(s.rect(0, 296, SCENE_W, 1), "leaf1")
    for x in (14, 66, 150):  # mushrooms
        cap = s.ellipse(x, 294, 4.5, 3) & (s.ys < 295)
        s.fill(s.rect(x - 1, 293, 3, 4), "cream")
        s.fill(cap, "pink2")
        s.pixels([(x - 2, 292), (x + 1, 291)], "white")
    for x in range(3, SCENE_W, 9):
        s.put(x, 302 + x % 5, "wood2")
    return s


def scene_snow():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(4)
    sky(s, [("dusk_deep", 90), ("twilight", 170), ("periwinkle", 240), ("lilac3", 300)])
    houses(s, rng, 298, [("cream", "peach0", "peach1"), ("lilac1", "lilac2", "lilac3"), ("sea0", "sea1", "sea2")],
           [("pink3", "pink4"), ("sea3", "sea4"), ("lilac4", "dusk_deep")], snow=True)
    s.fill(s.rect(0, 294, SCENE_W, 106), "white")
    s.fill(s.rect(0, 294, SCENE_W, 106) & s.sparse(4), "mist")
    s.fill(s.rect(0, 294, SCENE_W, 1), "snow")
    for _ in range(150):
        x, y = rng.randrange(SCENE_W), rng.randrange(290)
        s.put(x, y, "white" if rng.random() < .7 else "lilac1")
    for _ in range(14):
        sparkle(s, rng.randrange(3, SCENE_W - 3), rng.randrange(3, 280), "white")
    return s


def scene_cherry():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(5)
    sky(s, [("night_deep", 90), ("dusk_deep", 160), ("twilight", 230), ("lilac3", 300)])
    stars(s, rng, 35, 150, ("white", "pink1"), 4)
    moon(s, 136, 54, 11)
    houses(s, rng, 300, [("lilac1", "lilac2", "lilac3"), ("cream", "peach0", "peach1")],
           [("lilac4", "dusk_deep"), ("pink3", "pink4")], lit=.45, h_range=(28, 50))
    for cx in (16, 72, 128, 174):
        fluffy_tree(s, rng, cx + rng.randrange(-4, 5), 296, rng.randrange(44, 58), ("pink0", "pink1", "pink2", "pink3"))
    string_lights(s, 120, 20, colors=("glow", "pink1"))
    for _ in range(70):
        x, y = rng.randrange(SCENE_W), rng.randrange(290)
        s.put(x, y, "pink1")
        if rng.random() < .4:
            s.put(x + 1, y + 1, "pink2")
    cobbles(s, 296, "lilac2", "lilac3", "lilac1")
    return s


def scene_seaside():
    s, rng = Sprite(SCENE_W, SCENE_H), random.Random(6)
    sky(s, [("night_deep", 100), ("dusk_deep", 170), ("twilight", 214)])
    stars(s, rng, 60, 200)
    moon(s, 126, 74, 13)
    s.fill(s.rect(0, 214, SCENE_W, 86), "sea4")
    s.fill(s.rect(0, 240, SCENE_W, 60), "sea3")
    s.fill(s.rect(0, 238, SCENE_W, 2) & s.checker(), "sea3")
    for _ in range(46):
        x, y = rng.randrange(SCENE_W), rng.randrange(218, 296)
        s.fill(s.rect(x, y, rng.randrange(3, 7), 1), "sea2")
    for i, y in enumerate(range(218, 296, 4)):  # moonlight on the water
        w = max(3, 16 - i // 2)
        s.fill(s.rect(126 - w // 2 + rng.randrange(-1, 2), y, w, 1), "glow" if i % 3 else "lemon")
    # Lighthouse on a little cape.
    cape = s.poly([(0, 216), (0, 204), (30, 203), (46, 216)])
    s.fill(cape, "leaf3")
    s.fill(cape & edge(cape, 0, -1), "leaf2")
    tower = s.poly([(14, 205), (16, 160), (24, 160), (26, 205)])
    s.fill(tower, "white")
    for y in (168, 182, 196):
        s.fill(tower & s.rect(0, y, SCENE_W, 6), "coral")
    s.fill(s.rrect(15, 151, 10, 9, 2), "lilac4")
    s.fill(s.rect(17, 153, 6, 6), "glow")
    s.fill(s.poly([(14, 151), (20, 144), (26, 151)]), "coral")
    s.fill(s.poly([(25, 153), (64, 144), (64, 164), (25, 158)]) & s.sparse(2), "glow")
    string_lights(s, 236, 16)
    s.fill(s.rect(0, 296, SCENE_W, 104), "wood1")
    for y in range(298, SCENE_H, 4):
        s.fill(s.rect(0, y, SCENE_W, 1), "wood2")
    s.fill(s.rect(0, 296, SCENE_W, 1), "wood0")
    return s


SCENES = {"night": scene_night, "dusk": scene_dusk, "forest": scene_forest,
          "snow": scene_snow, "cherry": scene_cherry, "seaside": scene_seaside}


def counter(snow=False):
    s = Sprite(SCENE_W, SCENE_H - COUNTER_TOP)
    s.fill(s.rect(0, 0, s.w, s.h), "wood1")
    for x in range(0, s.w, 20):
        s.fill(s.rect(x, 7, 1, s.h), "wood2")
        s.fill(s.rect(x + 1, 7, 1, s.h), "wood0")
    s.fill(s.rect(0, 0, s.w, 6), "wood0")
    s.fill(s.rect(0, 0, s.w, 1), "cream")
    s.fill(s.rect(0, 5, s.w, 1), "wood2")
    s.fill(s.rect(0, 6, s.w, 1), "wood3")
    # Scalloped striped cloth under the board.
    for x in range(0, s.w, 12):
        stripe = s.rect(x, 7, 6, 9)
        s.fill(stripe, "pink2")
        s.fill(s.rect(x + 6, 7, 6, 9), "cream")
    for x in range(0, s.w, 6):
        scallop = s.circle(x + 3, 16, 3) & (s.ys >= 16)
        s.fill(scallop, "pink2" if (x // 6) % 2 == 0 else "cream")
    s.fill(s.rect(0, 7, s.w, 1), "pink3")
    # A little sign with a heart in the middle.
    sign = s.rrect(78, 26, 24, 16, 3)
    s.fill(sign, "cream")
    s.fill(sign & edge(sign, 0, 1), "mist")
    s.outline("wood3", mask=sign)
    heart(s, 86, 31, "pink3", 2)
    if snow:
        s.fill(s.rect(0, 0, s.w, 2), "white")
        for x in range(2, s.w, 9):
            s.fill(s.rrect(x, 1, 5, 3, 1), "white")
    return s


# ---------------------------------------------------------------- stoves (80x40)

STOVES = {  # highlight, light, base, shade, line
    "iron": ("white", "snow", "mist", "stone", "slate"),
    "copper": ("peach0", "peach1", "peach2", "peach3", "choco3"),
    "castiron": ("stone", "slate", "ink", "night_deep", "night_deep"),
    "golden": ("glow", "lemon", "honey", "caramel", "bake"),
}


def mini_fish(s, x, y, light="honey_light", base="honey", line="crust_line"):
    s.art(x, y, [
        "...oooooo.",
        "o.ollbbbbo",
        "oobbbbbkbo",
        "obbbbbbbbo",
        "oobbbbbbo.",
        "o..oooooo.",
    ], {"o": line, "l": light, "b": base, "k": "ink"})


def stove(kind):
    hi, light, base, shade, line = STOVES[kind]
    s = Sprite(80, 40)
    body = s.rrect(4, 14, 72, 23, 6)
    soft_shade(s, body, (hi, light, base, shade))
    s.fill(s.rrect(9, 36, 6, 4, 1) | s.rrect(65, 36, 6, 4, 1), shade)  # feet
    plate = s.rrect(6, 11, 68, 5, 2)
    s.fill(plate, shade)
    s.fill(plate & edge(plate, 0, -1), base)
    for x in (12, 35, 58):
        cav = s.rrect(x - 1, 6, 13, 8, 2)
        s.fill(cav, shade)
    window = s.rrect(24, 21, 32, 11, 4)
    s.fill(window, "night_deep")
    s.fill(window & (s.ys >= 27) & s.checker(), "coral")
    s.fill(window & (s.ys >= 29), "coral")
    s.fill(window & (s.ys >= 29) & s.checker(1), "lemon")
    s.fill(window & (s.ys == 30) & s.sparse(2), "glow")
    # Cute face on the left panel.
    s.pixels([(11, 23), (11, 24), (17, 23), (17, 24)], "ink")
    s.pixels([(13, 26), (14, 27), (15, 26)], "ink")
    s.fill(s.ellipse(9.5, 27, 1.5, 1) | s.ellipse(19.5, 27, 1.5, 1), "blush")
    if kind == "castiron":
        for x in range(60, 74, 4):
            s.put(x, 18, "mist")
            s.put(x, 33, "mist")
    s.outline(line)
    for x in (12, 35, 58):
        mini_fish(s, x + 1, 5)
    if kind == "golden":
        for x, y in [(6, 12), (74, 16), (62, 33), (22, 34)]:
            sparkle(s, x, y, "white")
    for x in (17, 40, 63):  # steam curls
        s.pixels([(x, 4), (x + 1, 3), (x + 1, 2), (x, 1), (x, 0)], "mist")
    return s


# ---------------------------------------------------------------- decorations

def lantern():
    s = Sprite(14, 24)
    body = s.ellipse(7, 13, 6, 6.5)
    s.fill(body, "peach2")
    s.fill(body & s.ellipse(6.5, 12, 4, 5), "peach1")
    s.fill(body & s.ellipse(6, 11, 2.5, 3), "glow")
    s.fill(body & ((s.xs == 3) | (s.xs == 10)), "peach3")
    s.fill(s.rrect(4, 5, 6, 2, 1) | s.rrect(4, 19, 6, 2, 1), "wine")
    s.fill(s.rect(6, 21, 2, 2), "coral")
    s.outline("wine")
    s.fill(s.rect(6, 0, 2, 4), "mist")
    s.fill(s.rect(6, 23, 2, 1), "coral")
    return s


def windchime():
    s = Sprite(14, 30)
    bell = s.poly([(4, 6), (9, 6), (11, 13), (2, 13)]) | s.rrect(1, 12, 12, 2, 1)
    soft_shade(s, bell, ("lilac0", "lilac1", "lilac2", "lilac3"))
    s.outline("lilac4")
    mini_fish(s, 2, 18, light="sea0", base="sea1", line="sea3")
    s.fill(s.rect(6, 0, 1, 5), "mist")
    s.fill(s.rect(6, 15, 1, 3), "mist")
    return s


def bunting():
    s = Sprite(SCENE_W, 22)
    colors = [("pink1", "pink2"), ("glow", "lemon"), ("mint1", "mint2"), ("sea0", "sea1"), ("lilac1", "lilac2")]
    flags = s.empty()
    for i, x in enumerate(range(4, SCENE_W - 6, 14)):
        y = sag(x + 4, 0, SCENE_W, 2, 8)
        light, base = colors[i % len(colors)]
        tri = s.poly([(x, y + 1), (x + 8, y + 1), (x + 4, y + 10)])
        s.fill(tri, base)
        s.fill(tri & edge(tri, 0, -1), light)
        s.put(x + 4, y + 4, "white")
        flags |= tri
    s.outline("lilac4", mask=flags)
    wire(s, 2, 8, "lilac4")
    return s


def starlights():
    s = Sprite(SCENE_W, 24)
    bulbs = s.empty()
    for i, x in enumerate(range(10, SCENE_W, 20)):
        y = sag(x, 0, SCENE_W, 2, 10) + 5
        s.fill(s.circle(x, y, 5) & s.sparse(2), "periwinkle")
        star = s.poly(star_points(x, y, 4, 1.8))
        s.fill(star, "lemon" if i % 2 else "glow")
        s.put(x, y, "white")
        bulbs |= star
    s.outline("honey", mask=bulbs)
    wire(s, 2, 10, "lilac4")
    for x in range(10, SCENE_W, 20):
        y = sag(x, 0, SCENE_W, 2, 10)
        s.fill(s.rect(x, y, 1, 2), "lilac4")
    return s


def snowman():
    s = Sprite(26, 34)
    low = s.ellipse(13, 24, 9, 8)
    top = s.ellipse(13, 12, 6.5, 6)
    body = low | top
    s.fill(body, "white")
    s.fill((edge(low, 1, 0) | edge(low, 0, 2) | edge(top, 1, 0) | edge(top, 0, 2)) & body, "mist")
    s.pixels([(10, 11), (15, 11), (10, 12), (15, 12)], "ink")
    s.fill(s.ellipse(9, 14.5, 1.6, 1) | s.ellipse(17, 14.5, 1.6, 1), "blush")
    s.pixels([(12, 14), (13, 14)], "coral")
    scarf = s.rrect(7, 17, 13, 3, 1) | s.rect(16, 19, 3, 5)
    s.fill(scarf, "pink2")
    s.fill(scarf & (s.xs % 3 == 0), "pink3")
    s.fill(s.line([(5, 21), (1, 16)]), "wood2")
    s.fill(s.rrect(0, 12, 5, 4, 1), "honey")
    s.put(1, 13, "honey_light")
    s.outline("stone")
    return s


DECORATIONS = {"lantern": lantern, "windchime": windchime, "bunting": bunting,
               "starlights": starlights, "snowman": snowman}
