"""Icons: menu (24x24), skills (32x32, one per skill), items (32x32), app icon.

Skill icons combine a motif from the skill's noun (mold, batter, hand,
recipe, stove, workshop, bakery...) with a badge and an accessory from its
adjective (moonlight, starlight, galaxy, meteor, sun, gold, legend...), so
all 32 are different but read as one family.
"""

import math
import random

from pixel_kit import Sprite, arc_points, edge, glow, heart, soft_shade, sparkle, star_points
from art_scene import mini_fish

# ---------------------------------------------------------------- menu icons (24x24)


def icon_shop():
    s = Sprite(24, 24)
    for x in range(3, 21):
        s.fill(s.rect(x, 4, 1, 5), "pink2" if (x - 3) // 3 % 2 == 0 else "cream")
    for x in range(3, 21, 3):
        s.fill(s.circle(x + 1.5, 9, 1.6) & (s.ys >= 9), "pink2" if (x - 3) // 3 % 2 == 0 else "cream")
    s.fill(s.rect(4, 11, 2, 5) | s.rect(18, 11, 2, 5), "wood1")
    counter = s.rrect(3, 15, 18, 5, 1)
    s.fill(counter, "honey")
    s.fill(counter & edge(counter, 0, -1), "honey_light")
    mini_fish(s, 7, 10)
    s.outline("pink4")
    return s


def icon_skins():
    s = Sprite(24, 24)
    hanger = s.line([(12, 8), (3, 16), (3, 18), (20, 18), (20, 16), (12, 8)], 2)
    s.fill(hanger, "lilac1")
    s.fill(s.line([(12, 7), (12, 5), (13, 3), (15, 3), (16, 5)]), "lilac2")
    heart(s, 9, 9, "pink2", 2)
    s.put(10, 9, "pink1")
    s.outline("lilac4")
    return s


def icon_records():
    s = Sprite(24, 24)
    book = s.rrect(5, 3, 15, 18, 2)
    s.fill(book, "cream")
    s.fill(s.rect(5, 3, 3, 18) & book, "sea1")
    s.fill(s.rect(10, 13, 2, 5), "pink2")
    s.fill(s.rect(13, 10, 2, 8), "honey")
    s.fill(s.rect(16, 6, 2, 12), "mint2")
    s.fill(s.rect(9, 18, 10, 1), "mist")
    s.outline("sea3")
    return s


def icon_share():
    s = Sprite(24, 24)
    plane = s.poly([(3, 11), (20, 4), (14, 20), (10, 14)])
    s.fill(plane, "white")
    s.fill(s.poly([(10, 14), (20, 4), (14, 20)]), "sea0")
    s.fill(s.line([(10, 14), (20, 4)]), "sea1")
    s.fill(s.poly([(10, 14), (10, 19), (13, 16)]), "sea2")
    s.outline("sea3")
    s.pixels([(3, 17), (4, 17), (6, 19), (7, 19)], "sea1")
    return s


def icon_daily():
    s = Sprite(24, 24)
    s.fill(s.rect(5, 5, 14, 14), "cream")
    rolls = s.rrect(3, 3, 18, 3, 1) | s.rrect(3, 18, 18, 3, 1)
    s.fill(rolls, "peach1")
    s.fill(rolls & edge(rolls, 0, 1), "peach2")
    s.pixels([(7, 9), (8, 10), (9, 9), (10, 8)], "mint3")
    s.pixels([(7, 14), (8, 15), (9, 14), (10, 13)], "mint3")
    s.fill(s.rect(12, 9, 5, 1) | s.rect(12, 14, 5, 1), "mist")
    s.outline("peach3")
    return s


def icon_achievements():
    s = Sprite(24, 24)
    s.fill(s.poly([(6, 2), (10, 2), (13, 10), (9, 10)]), "pink2")
    s.fill(s.poly([(14, 2), (18, 2), (15, 10), (11, 10)]), "sea1")
    medal = s.circle(12, 15, 6.5)
    soft_shade(s, medal, ("glow", "lemon", "honey", "caramel"))
    s.fill(s.poly(star_points(12, 15.5, 3.5, 1.6)), "glow")
    s.outline("bake")
    return s


def icon_settings():
    s = Sprite(24, 24)
    gear = s.circle(12, 12, 7)
    for a in range(0, 360, 45):
        gear |= s.circle(12 + 8.2 * math.cos(math.radians(a)), 12 + 8.2 * math.sin(math.radians(a)), 2.2)
    soft_shade(s, gear, ("white", "lilac0", "lilac1", "lilac2"))
    s.a[s.circle(12, 12, 3)] = 0
    s.outline("lilac4")  # also rings the hole
    return s


def icon_leaderboard():
    s = Sprite(24, 24)
    soft_shade(s, s.rect(9, 11, 6, 10), ("glow", "lemon", "honey", "caramel"))
    soft_shade(s, s.rect(3, 14, 6, 7), ("white", "snow", "mist", "stone"))
    soft_shade(s, s.rect(15, 16, 6, 5), ("peach0", "peach1", "peach2", "peach3"))
    crown = s.poly([(8, 9), (8, 4), (10, 6), (12, 3), (14, 6), (16, 4), (16, 9)])
    s.fill(crown, "lemon")
    s.put(12, 7, "pink3")
    s.outline("bake")
    return s


def icon_star():
    s = Sprite(24, 24)
    star = s.poly(star_points(12, 12.5, 10, 4.8)) | s.circle(12, 13, 5)
    soft_shade(s, star, ("glow", "lemon", "honey", "caramel"))
    s.pixels([(10, 12), (14, 12)], "ink")
    s.fill(s.ellipse(9, 14.5, 1.3, .8) | s.ellipse(15, 14.5, 1.3, .8), "blush")
    s.pixels([(11, 14), (12, 15), (13, 14)], "ink")
    s.outline("bake")
    return s


def icon_butter():
    s = Sprite(24, 24)
    top = s.poly([(4, 10), (12, 6), (20, 10), (12, 14)])
    left = s.poly([(4, 10), (12, 14), (12, 20), (4, 16)])
    right = s.poly([(12, 14), (20, 10), (20, 16), (12, 20)])
    s.fill(left, "lemon")
    s.fill(right, "honey")
    s.fill(top, "glow")
    s.pixels([(9, 9), (10, 9), (11, 8)], "white")
    s.outline("bake")
    sparkle(s, 4, 4)
    sparkle(s, 20, 5, "glow")
    return s


MENU_ICONS = {
    "shop": icon_shop, "skins": icon_skins, "records": icon_records, "share": icon_share,
    "daily": icon_daily, "achievements": icon_achievements, "settings": icon_settings,
    "leaderboard": icon_leaderboard, "star": icon_star, "butter": icon_butter,
}


# ---------------------------------------------------------------- skill icons (32x32)

BADGES = {  # fill, border
    "tap": ("pink0", "pink2"),
    "auto": ("mint0", "mint2"),
    "night": ("dusk_deep", "periwinkle"),
    "gold": ("honey_light", "honey"),
}
METALS = {  # highlight, light, base, shade, line
    "silver": ("white", "snow", "mist", "stone", "slate"),
    "brass": ("glow", "honey_light", "honey", "caramel", "bake"),
    "lilac": ("lilac0", "lilac1", "lilac2", "lilac3", "lilac4"),
    "sea": ("sea0", "sea1", "sea2", "sea3", "sea4"),
    "gold": ("glow", "lemon", "honey", "caramel", "bake"),
    "peach": ("peach0", "peach1", "peach2", "peach3", "choco3"),
    "pink": ("pink0", "pink1", "pink2", "pink3", "pink4"),
    "mint": ("mint0", "mint1", "mint2", "mint3", "mint4"),
}


def badge(s, kind):
    fill, border = BADGES[kind]
    b = s.rrect(1, 1, 30, 30, 8)
    s.fill(b, fill)
    s.fill(b & (edge(b, 0, 1) | edge(b, 0, 2)), border)
    s.fill(b & (edge(b, 0, -1) | edge(b, -1, 0) | edge(b, 1, 0)), border)
    if kind == "night":
        rng = random.Random(7)
        for _ in range(7):
            s.put(rng.randrange(4, 28), rng.randrange(4, 26), rng.choice(["white", "lilac1", "glow"]))
    return b


def layer(s, draw, line):
    """Draw a motif on its own layer, outline it, and stamp it on `s`."""
    m = Sprite(s.w, s.h)
    draw(m)
    m.outline(line)
    s.paste(m)


def motif_mold(metal):
    hi, light, base, shade, line = METALS[metal]

    def draw(s):
        plate = s.rrect(5, 10, 22, 14, 4)
        soft_shade(s, plate, (hi, light, base, shade))
        s.fill(s.rect(26, 15, 4, 3), shade)  # handle
        cav = s.rrect(8, 13, 16, 9, 3)
        s.fill(cav, shade)
        mini_fish(s, 11, 14)
    return draw, line


def motif_batter(color):
    def draw(s):
        bowl = s.ellipse(16, 18, 11, 8) & (s.ys >= 17)
        soft_shade(s, bowl, ("white", "sea0", "sea1", "sea2"))
        dough = s.ellipse(16, 17, 10, 3)
        s.fill(dough, color[1])
        s.fill(dough & edge(dough, 0, -1), color[0])
        s.fill(s.line([(21, 16), (26, 6)], 2), "wood1")  # spoon
        s.fill(s.ellipse(20.5, 16, 2, 1.4), "wood0")
    return draw, "sea3"


def motif_layers():
    def draw(s):
        for i, (light, base) in enumerate([("cream", "honey_light"), ("honey_light", "honey"), ("honey", "caramel")]):
            y = 20 - i * 5
            sheet = s.rrect(6 + i, y, 20 - 2 * i, 6, 3)
            s.fill(sheet, base)
            s.fill(sheet & edge(sheet, 0, -1), light)
    return draw, "crust_line"


def motif_ball(ramp, line):
    def draw(s):
        ball = s.circle(16, 17, 9)
        soft_shade(s, ball, ramp)
        s.fill(s.circle(12.5, 13, 2), "white")
    return draw, line


def motif_hand(ramp, line):
    """An oven mitt: upright palm, thumb to the side, cream cuff."""
    def draw(s):
        palm = s.rrect(11, 5, 13, 18, 6)
        thumb = s.rrect(6, 11, 7, 6, 3)
        mitt = palm | thumb
        soft_shade(s, mitt, ramp)
        s.fill(s.line([(11, 16), (12, 14)]), ramp[3])  # thumb crease
        cuff = s.rrect(10, 21, 15, 6, 2)
        s.fill(cuff, "cream")
        s.fill(cuff & s.checker() & (s.ys == 24), "mist")
        heart(s, 15, 11, "blush")
    return draw, line


def motif_mixer():
    def draw(s):
        base = s.rrect(6, 24, 20, 4, 1)
        arm = s.rrect(17, 6, 8, 19, 3)
        head = s.rrect(7, 6, 18, 7, 3)
        bowl = s.ellipse(13, 19, 7, 5) & (s.ys >= 17)
        soft_shade(s, base | arm | head, ("white", "pink0", "pink1", "pink2"))
        soft_shade(s, bowl, ("white", "snow", "mist", "stone"))
        s.fill(s.rect(12, 13, 2, 5), "stone")
    return draw, "pink4"


def motif_book(glowing):
    def draw(s):
        left = s.poly([(4, 10), (16, 12), (16, 26), (4, 24)])
        right = s.poly([(16, 12), (28, 10), (28, 24), (16, 26)])
        s.fill(left | right, "cream")
        s.fill(right, "snow")
        s.fill(s.rect(16, 12, 1, 14), "mist")
        for y in (15, 18, 21):
            s.fill(s.rect(7, y, 6, 1) | s.rect(19, y, 6, 1), "mist")
        if glowing:
            s.fill(s.rect(6, 4, 20, 6) & s.sparse(2), "glow")
    return draw, "wood2"


def motif_stove(ramp, line):
    def draw(s):
        body = s.rrect(5, 13, 22, 13, 4)
        soft_shade(s, body, ramp)
        s.fill(s.rrect(4, 11, 24, 4, 2), ramp[3])
        win = s.rrect(11, 17, 10, 6, 2)
        s.fill(win, "night_deep")
        s.fill(win & (s.ys >= 20), "coral")
        s.fill(win & (s.ys >= 21) & s.checker(), "lemon")
        s.fill(s.rect(8, 26, 3, 2) | s.rect(21, 26, 3, 2), ramp[3])
    return draw, line


def motif_flipper():
    def draw(s):
        blade = s.rrect(5, 8, 13, 10, 3)
        s.fill(blade, "snow")
        s.fill(blade & edge(blade, 0, 1), "mist")
        for x in (8, 11, 14):
            s.fill(s.rect(x, 10, 1, 5), "stone")
        s.fill(s.line([(15, 17), (26, 26)], 2), "wood1")
    return draw, "slate"


def motif_cottage(wall, roof):
    def draw(s):
        body = s.rect(7, 15, 18, 12)
        s.fill(body, wall[1])
        s.fill(body & edge(body, -1, 0), wall[0])
        roof_m = s.poly([(4, 16), (16, 6), (28, 16)])
        s.fill(roof_m, roof[0])
        s.fill(roof_m & edge(roof_m, 0, 1), roof[1])
        s.fill(s.rrect(14, 19, 5, 8, 2), roof[1])
        s.fill(s.rect(9, 18, 3, 3), "glow")
        s.fill(s.rect(21, 18, 3, 3), "glow")
    return draw, roof[1]


def motif_bakery(wall, awning, tall=False):
    def draw(s):
        top = 6 if tall else 11
        body = s.rect(5, top, 22, 27 - top)
        s.fill(body, wall[1])
        s.fill(body & edge(body, -1, 0), wall[0])
        if tall:
            for y in (8, 12):
                for x in (8, 13, 18, 23):
                    s.fill(s.rect(x, y, 2, 2), "glow")
        for x in range(5, 27, 4):
            s.fill(s.rect(x, 16, 2, 4), awning)
            s.fill(s.rect(x + 2, 16, 2, 4), "cream")
            s.fill(s.circle(x + 1, 20, 1.2) & (s.ys >= 20), awning)
        s.fill(s.rect(8, 21, 7, 6), "glow")
        s.fill(s.rect(18, 21, 5, 6), wall[2])
    return draw, wall[2]


# accessories (drawn after the outlined motif)
def acc_sparkles(s):
    sparkle(s, 5, 6, "white", True)
    sparkle(s, 26, 25, "glow")


def acc_moon(s):
    m = s.circle(25, 7, 4.5) & ~s.circle(27, 5.5, 3.8)
    s.fill(m, "glow")
    s.outline("honey", mask=m)


def acc_stars(s):
    for x, y, r in [(25, 6, 3.6), (6, 6, 2.6)]:
        st = s.poly(star_points(x, y, r, r * .45))
        s.fill(st, "lemon")
        s.outline("honey", mask=st)


def acc_galaxy(s):
    pts = arc_points(24, 8, 5, 3, 0, 300) + arc_points(24, 8, 2.5, 1.5, 0, 300)
    s.pixels(pts, "lilac1")
    s.pixels([(24, 8), (23, 8)], "white")
    s.pixels([(29, 6), (19, 10)], "glow")


def acc_meteor(s):
    s.fill(s.line([(17, 3), (26, 9)]), "sea0")
    s.fill(s.line([(18, 2), (25, 7)]) & s.checker(), "lilac1")
    m = s.circle(27, 9, 2.5)
    s.fill(m, "glow")
    s.outline("honey", mask=m)


def acc_sun(s):
    glow(s, 25, 7, 6, "lemon", "glow", 3)
    s.fill(s.circle(25, 7, 3), "honey")
    s.put(24, 6, "glow")


def acc_planet(s):
    p = s.circle(25, 7, 3.5)
    s.fill(p, "pink2")
    s.fill(p & edge(p, 0, 1), "pink3")
    s.fill(s.line([(19, 9), (31, 5)]) & ~s.circle(25, 7, 2), "lemon")


def acc_crown(s):
    c = s.poly([(9, 7), (9, 2), (12, 4), (16, 1), (20, 4), (23, 2), (23, 7)])
    s.fill(c, "lemon")
    s.fill(c & edge(c, 0, 1), "honey")
    s.outline("bake", mask=c)
    s.put(16, 5, "pink3")


def acc_steam(s):
    for x in (7, 13, 19):
        s.pixels([(x, 9), (x + 1, 8), (x + 1, 7), (x, 6), (x, 5), (x + 1, 4)], "mist")


def acc_spin(s):
    s.pixels(arc_points(16, 18, 14, 12, 200, 250) + arc_points(16, 18, 14, 12, 20, 70), "mint3")
    s.pixels([(3, 15), (4, 14), (29, 21), (28, 22)], "mint3")


def acc_motion(s):
    for y in (9, 12, 15):
        s.fill(s.rect(26, y, 3, 1), "stone")


def acc_heart(s):
    heart(s, 23, 4, "pink3", 2)


CRUST = ("cream", "honey_light", "honey", "caramel")
GOLD = ("glow", "lemon", "honey", "caramel")
SKIN = ("skin1a", "skin1a", "skin1b", "skin1c")

# skill id -> (badge, motif, accessories)
SKILL_ICONS = {
    "tap_1": ("tap", motif_mold("silver"), [acc_sparkles]),        # 반짝이는 틀
    "tap_2": ("tap", motif_batter(("honey_light", "honey")), []),  # 진한 반죽
    "tap_3": ("tap", motif_hand(SKIN, "skin1d"), [acc_sparkles]),  # 노릇한 손놀림
    "tap_4": ("tap", motif_mixer(), []),                           # 정밀 반죽기
    "tap_5": ("tap", motif_mold("brass"), []),                     # 황동 빵틀
    "tap_6": ("tap", motif_layers(), []),                          # 겹겹이 반죽
    "tap_7": ("night", motif_hand(("lilac0", "lilac0", "lilac1", "lilac2"), "lilac4"), [acc_moon]),  # 달빛 손길
    "tap_8": ("tap", motif_book(False), [acc_heart]),              # 숙련 뒤집기
    "tap_9": ("night", motif_mold("lilac"), [acc_stars]),          # 별빛 빵틀
    "tap_10": ("gold", motif_ball(GOLD, "bake"), [acc_sparkles]),  # 금빛 앙금
    "tap_11": ("night", motif_hand(("sea0", "sea0", "sea1", "sea2"), "sea4"), [acc_galaxy]),  # 별무리 손길
    "tap_12": ("night", motif_mold("sea"), [acc_meteor]),          # 유성 빵틀
    "tap_13": ("gold", motif_book(True), [acc_sparkles]),          # 오로라 반죽
    "tap_14": ("gold", motif_ball(CRUST, "crust_line"), [acc_sun]),  # 태양의 반죽
    "tap_15": ("night", motif_hand(("pink0", "pink0", "pink1", "pink2"), "pink4"), [acc_planet]),  # 우주의 손길
    "tap_16": ("gold", motif_mold("gold"), [acc_crown]),           # 천년 빵틀
    "auto_1": ("auto", motif_stove(METALS["peach"][:4], "choco3"), []),     # 작은 화로
    "auto_2": ("auto", motif_flipper(), [acc_motion]),             # 부지런한 집게
    "auto_3": ("auto", motif_cottage(("peach0", "peach1"), ("pink2", "pink4")), []),  # 붕어빵 공방
    "auto_4": ("auto", motif_stove(METALS["mint"][:4], "mint4"), [acc_spin]),  # 회전 화로
    "auto_5": ("auto", None, []),                                  # 연속 굽기 (custom below)
    "auto_6": ("auto", motif_cottage(("sea0", "sea1"), ("sea2", "sea4")), [acc_steam]),  # 증기 공방
    "auto_7": ("auto", motif_bakery(("peach0", "peach1", "peach3"), "pink2"), []),  # 골목 제빵소
    "auto_8": ("auto", motif_bakery(("sea0", "sea1", "sea3"), "sea2", tall=True), []),  # 도시 제빵소
    "auto_9": ("night", motif_stove(METALS["lilac"][:4], "lilac4"), [acc_stars]),  # 별빛 화로
    "auto_10": ("gold", motif_bakery(("glow", "lemon", "caramel"), "honey"), [acc_sparkles]),  # 황금 제빵소
    "auto_11": ("night", motif_cottage(("lilac0", "lilac1"), ("lilac3", "lilac4")), [acc_galaxy]),  # 성운 공방
    "auto_12": ("night", motif_stove(METALS["sea"][:4], "sea4"), [acc_meteor]),  # 유성 화로
    "auto_13": ("gold", motif_cottage(("glow", "lemon"), ("honey", "bake")), [acc_sparkles]),  # 찬란한 공방
    "auto_14": ("gold", motif_bakery(("peach0", "peach1", "peach3"), "coral"), [acc_sun]),  # 태양 제빵소
    "auto_15": ("night", motif_bakery(("lilac0", "lilac1", "lilac4"), "pink2", tall=True), [acc_planet]),  # 우주 제빵소
    "auto_16": ("gold", motif_stove(GOLD, "bake"), [acc_crown]),   # 천년 화로
}


def skill_icon(skill_id):
    kind, motif, accessories = SKILL_ICONS[skill_id]
    s = Sprite(32, 32)
    badge(s, kind)
    if motif is None:  # 연속 굽기: three buns in a row with an arrow
        for x, y in [(3, 18), (11, 13), (19, 8)]:
            mini_fish(s, x, y)
        s.pixels([(20, 22), (23, 22), (26, 22), (27, 21), (28, 22), (27, 23)], "mint3")
    else:
        draw, line = motif
        layer(s, draw, line)
    for acc in accessories:
        acc(s)
    return s


# ---------------------------------------------------------------- items (32x32)

def item_fairy():
    s = Sprite(32, 32)
    wings = s.ellipse(9, 12, 6, 7) | s.ellipse(23, 12, 6, 7)
    s.fill(wings, "sea0")
    s.fill(wings & edge(wings, 0, 1), "sea1")
    s.outline("sea2", mask=wings)
    body = s.poly([(12, 18), (20, 18), (22, 29), (10, 29)])
    soft_shade(s, body, ("pink0", "pink1", "pink1", "pink2"))
    head = s.circle(16, 12, 5.5)
    soft_shade(s, head, ("skin1a", "skin1a", "skin1b", "skin1c"))
    hair = s.circle(16, 10, 6) & (s.ys < 11)
    s.fill(hair, "hair_gold1")
    s.fill(hair & edge(hair, 0, 1), "hair_gold2")
    s.pixels([(14, 12), (18, 12)], "ink")
    s.fill(s.ellipse(12.5, 14.5, 1.4, .8) | s.ellipse(19.5, 14.5, 1.4, .8), "blush")
    s.outline("pink4")
    mini_fish(s, 11, 22)
    sparkle(s, 4, 4, "glow", True)
    sparkle(s, 28, 26)
    return s


def item_butter():
    s = Sprite(32, 32)
    top = s.poly([(5, 13), (16, 7), (27, 13), (16, 19)])
    left = s.poly([(5, 13), (16, 19), (16, 27), (5, 21)])
    right = s.poly([(16, 19), (27, 13), (27, 21), (16, 27)])
    s.fill(left, "lemon")
    s.fill(right, "honey")
    s.fill(top, "glow")
    s.pixels([(10, 12), (11, 12), (12, 11), (13, 11)], "white")
    s.pixels([(10, 21), (21, 21)], "ink")
    s.pixels([(14, 23), (15, 24), (16, 23)], "ink")
    s.outline("bake")
    sparkle(s, 5, 5, "white", True)
    sparkle(s, 27, 6, "glow")
    return s




# ---------------------------------------------------------------- app icon (64x64)

def app_icon():
    """Twilight sky with a moon; the bungeoppang fills the frame, tail cut off."""
    from art_fish import fish
    s, rng = Sprite(64, 64), random.Random(9)
    s.fill(s.rect(0, 0, 64, 64), "dusk_deep")
    s.fill(s.rect(0, 44, 64, 20), "twilight")
    s.fill(s.rect(0, 42, 64, 2) & s.checker(), "twilight")
    s.fill(s.rect(0, 56, 64, 8), "periwinkle")
    s.fill(s.rect(0, 54, 64, 2) & s.checker(), "periwinkle")
    for _ in range(14):
        s.put(rng.randrange(64), rng.randrange(40), rng.choice(["white", "glow", "lilac1"]))
    glow(s, 50, 10, 9, "twilight", "dusk_deep")
    m = s.circle(50, 10, 5)
    s.fill(m, "glow")
    s.fill(m & edge(m, 1, 0), "lemon")
    sparkle(s, 8, 8, "glow", True)
    s.paste(fish("redbean"), -28, -1)
    return s
