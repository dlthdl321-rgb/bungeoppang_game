"""The vendor (avatar): chibi proportions, layered on one 52x60 canvas.

Layer order (also in lib/ui/avatar_painter.dart): skin (head, neck) ->
face (by character) -> outfit -> hair (by style and character) -> hat ->
tool -> hands. In the scene the canvas sits at AVATAR_AT, right of the
stove; rows below the counter are hidden.
"""

from pixel_kit import Sprite, edge, heart, soft_shade, sparkle

AVATAR_W, AVATAR_H = 52, 60
AVATAR_AT = (116, 250)
HEAD = (26, 21, 14, 13)  # cx, cy, rx, ry
CHARACTERS = ["girl", "boy"]

SKIN_TONES = {  # highlight, light, base, shade, line
    "skin1": ("skin1a", "skin1a", "skin1b", "skin1c", "skin1d"),
    "skin2": ("skin2a", "skin2a", "skin2b", "skin2c", "skin2d"),
    "skin3": ("skin3a", "skin3a", "skin3b", "skin3c", "skin3d"),
}


def avatar_head(tone):
    hi, light, base, shade, line = SKIN_TONES[tone]
    s = Sprite(AVATAR_W, AVATAR_H)
    head = s.ellipse(*HEAD)
    ears = s.ellipse(12.5, 23, 2, 3) | s.ellipse(39.5, 23, 2, 3)
    neck = s.rect(23, 33, 6, 4)
    m = head | ears | neck
    s.fill(m, base)
    s.fill(head & edge(head, 0, -3), light)
    s.fill(m & (edge(m, 0, 2) | edge(m, 2, 0)), shade)
    s.fill(neck & (s.ys == 33), shade)
    s.outline(line)
    return s


def avatar_face(character):
    """Eyes, blush and mouth; skin-tone independent."""
    s = Sprite(AVATAR_W, AVATAR_H)
    if character == "girl":
        eye = [".kkk.", "kwwkk", "kwkkk", "kkkkk", ".kkk."]
        s.art(17, 21, eye, {"k": "ink", "w": "white"})
        s.art(30, 21, eye, {"k": "ink", "w": "white"})
        s.pixels([(16, 21), (15, 20), (35, 21), (36, 20)], "ink")  # lashes
        s.fill(s.ellipse(17, 28.5, 2.6, 1.4) | s.ellipse(35, 28.5, 2.6, 1.4), "blush")
        s.pixels([(16, 28), (34, 28)], "white")
        s.pixels([(24, 29), (25, 30), (26, 30), (27, 30), (28, 29)], "wine")
        s.pixels([(25, 31), (26, 31)], "coral")
    else:
        eye = [".kk.", "kwkk", "kkkk", ".kk."]
        s.art(18, 22, eye, {"k": "ink", "w": "white"})
        s.art(30, 22, eye, {"k": "ink", "w": "white"})
        s.pixels([(18, 19), (19, 19), (20, 19), (31, 19), (32, 19), (33, 19)], "hair_brown2")  # brows
        s.fill(s.ellipse(17, 28.5, 2.2, 1.1) | s.ellipse(35, 28.5, 2.2, 1.1), "pink2")
        s.pixels([(24, 29), (25, 30), (26, 30), (27, 30), (28, 29)], "wine")
    return s


def avatar_hands(tone):
    hi, light, base, shade, line = SKIN_TONES[tone]
    s = Sprite(AVATAR_W, AVATAR_H)
    hands = s.ellipse(12, 48.5, 3.4, 3) | s.ellipse(40, 48.5, 3.4, 3)
    s.fill(hands, base)
    s.fill(hands & edge(hands, 0, -1), light)
    s.fill(hands & edge(hands, 0, 1), shade)
    s.outline(line)
    return s


# shirt ramp (hi, light, base, shade, line)
OUTFITS = {
    "apron": ("sea0", "sea0", "sea1", "sea2", "sea3"),
    "padding": ("cream", "cream", "snow", "mist", "stone"),
    "stripe": ("lilac0", "lilac0", "lilac1", "lilac2", "lilac3"),
    "chefcoat": ("white", "white", "snow", "mist", "stone"),
}


def avatar_outfit(kind):
    hi, light, base, shade, line = OUTFITS[kind]
    s = Sprite(AVATAR_W, AVATAR_H)
    torso = s.poly([(17, 35), (35, 35), (40, 40), (41, 59), (11, 59), (12, 40)]) | s.rrect(14, 34, 24, 10, 4)
    arms = s.poly([(12, 39), (17, 40), (15, 48), (9, 47)]) | s.poly([(40, 39), (35, 40), (37, 48), (43, 47)])
    clothes = torso | arms
    soft_shade(s, clothes, (hi, light, base, shade))
    s.fill(clothes & edge(arms, 0, 1), shade)
    s.outline(line)
    if kind in ("apron", "stripe"):
        apron = s.rrect(17, 42, 18, 18, 3) | s.rect(18, 35, 2, 8) | s.rect(32, 35, 2, 8)
        if kind == "apron":
            s.fill(apron, "cream")
            s.fill(apron & edge(apron, 0, 1), "mist")
            heart(s, 23, 47, "pink2", 2)  # pocket
            s.pixels([(24, 47)], "pink1")
        else:
            s.fill(apron, "cream")
            s.fill(apron & (s.xs % 4 < 2), "pink2")
            s.fill(apron & edge(apron, 0, 1), "pink3")
        s.outline("stone" if kind == "apron" else "pink4", mask=apron)
    elif kind == "padding":
        vest = (torso & (s.ys >= 37)) & ~s.rect(24, 37, 4, 23)
        soft_shade(s, vest, ("peach0", "peach1", "peach1", "peach2"))
        s.fill(vest & (s.ys % 5 == 1), "peach2")
        s.outline("peach3", mask=vest)
        s.fill(s.rrect(19, 34, 14, 4, 2), "peach1")  # fluffy collar
        s.fill(s.rect(19, 37, 14, 1), "peach2")
    elif kind == "chefcoat":
        for x in (21, 31):
            for y in (41, 46, 51, 56):
                s.put(x, y, "stone")
        s.fill(s.poly([(21, 35), (31, 35), (26, 41)]), "pink2")  # neckerchief
        s.fill(s.poly([(21, 35), (31, 35), (26, 41)]) & edge(s.poly([(21, 35), (31, 35), (26, 41)]), 0, 1), "pink3")
    return s


HAIR_COLORS = {  # light, base, shade, line
    "short": ("hair_brown1", "hair_brown1", "hair_brown2", "hair_brown3"),
    "ponytail": ("hair_brown1", "hair_brown1", "hair_brown2", "hair_brown3"),
    "curly": ("hair_gold1", "hair_gold1", "hair_gold2", "hair_gold3"),
}


def avatar_hair(style, character):
    light, base, shade, line = HAIR_COLORS[style]
    s = Sprite(AVATAR_W, AVATAR_H)
    cx, cy, rx, ry = HEAD
    cap = s.ellipse(cx, cy - 2, rx + 1.5, ry + 0.5) & (s.ys < 18)
    face_hole = s.ellipse(cx, cy + 4, rx - 2, ry - 3)
    if style == "curly":
        hair = s.empty()
        ring = [(14, 14), (18, 9), (24, 7), (30, 7), (35, 10), (39, 15), (40, 21), (12, 21)]
        if character == "girl":
            ring += [(11, 27), (41, 27), (12, 33), (40, 33)]
        for x, y in ring:
            hair |= s.circle(x, y, 4.3)
        hair &= ~(face_hole & (s.ys > 16))
        fringe = s.circle(20, 15, 3.5) | s.circle(27, 14, 3.5) | s.circle(33, 15, 3.2)
        hair |= fringe
    elif character == "girl":
        sides = s.rrect(10, 14, 7, 21, 3) | s.rrect(35, 14, 7, 21, 3)  # bob
        fringe = s.poly([(14, 13), (38, 13), (38, 18), (34, 16), (31, 19), (27, 16), (23, 19), (19, 16), (14, 19)])
        hair = cap | fringe | (sides if style == "short" else s.rrect(10, 14, 5, 12, 2) | s.rrect(37, 14, 5, 12, 2))
        if style == "ponytail":
            hair |= s.ellipse(44, 22, 4, 9) | s.rrect(37, 10, 6, 6, 2)
    else:
        sides = s.rect(11, 14, 3, 8) | s.rect(38, 14, 3, 8)
        fringe = s.poly([(13, 12), (39, 12), (39, 16), (35, 15), (31, 17), (27, 14), (22, 17), (18, 14), (13, 17)])
        hair = cap | fringe | sides | s.poly([(26, 8), (29, 2), (31, 4), (29, 8)])  # cowlick
        if style == "ponytail":
            hair |= s.circle(26, 5, 4)  # top bun
    s.fill(hair, base)
    s.fill(hair & edge(hair, 0, 2), shade)
    s.fill(hair & edge(hair, 0, -2), light)
    # Shine band ("angel ring").
    s.fill(hair & (s.ys == 11) & (s.xs > 16) & (s.xs < 24), "cream")
    s.fill(hair & (s.ys == 12) & (s.xs > 15) & (s.xs < 19), "cream")
    s.outline(line)
    if style == "ponytail" and character == "girl":
        heart(s, 38, 9, "pink2", 2)
        s.put(39, 9, "pink1")
    if style == "ponytail" and character == "boy":
        s.fill(s.rect(23, 7, 7, 1), "pink3")
    return s


AVATAR_HATS = ["beanie", "earmuffs", "chefhat", "santa"]


def avatar_hat(kind):
    s = Sprite(AVATAR_W, AVATAR_H)
    if kind == "beanie":
        dome = s.ellipse(26, 13, 15.5, 10) & (s.ys < 13)
        soft_shade(s, dome, ("pink1", "pink1", "pink2", "pink3"))
        s.fill(dome & (s.xs % 4 == 0) & (s.ys > 5), "pink3")
        band = s.rrect(10, 11, 32, 5, 2)
        s.fill(band, "cream")
        s.fill(band & s.checker(), "mist")
        pom = s.circle(26, 3, 3.2)
        s.fill(pom, "white")
        s.fill(pom & edge(pom, 0, 1), "mist")
        s.outline("pink4")
    elif kind == "earmuffs":
        s.fill(s.line([(12, 21), (14, 11), (20, 6), (26, 5), (32, 6), (38, 11), (40, 21)], 2), "lilac3")
        muffs = s.ellipse(11, 24, 4.2, 5) | s.ellipse(41, 24, 4.2, 5)
        soft_shade(s, muffs, ("white", "pink1", "pink1", "pink2"))
        s.outline("lilac4")
    elif kind == "chefhat":
        puff = s.circle(26, 6, 6.5) | s.circle(19, 8, 4.5) | s.circle(33, 8, 4.5)
        band = s.rrect(13, 9, 26, 6, 1)
        soft_shade(s, puff | band, ("white", "white", "snow", "mist"))
        s.fill(band & (s.ys == 9), "mist")
        s.outline("stone")
    elif kind == "santa":
        cone = s.poly([(12, 13), (40, 13), (37, 5), (44, 2), (46, 7), (41, 7)])
        soft_shade(s, cone, ("coral", "coral", "berry", "wine"))
        s.fill(s.rrect(10, 11, 32, 5, 2), "white")
        s.fill(s.rect(10, 15, 32, 1), "mist")
        s.fill(s.circle(46, 6, 3), "white")
        s.outline("wine")
    return s


TOOLS = {"tongs": ("white", "mist", "stone", "slate"), "goldtongs": ("glow", "lemon", "honey", "bake")}


def avatar_tool(kind):
    hi, light, base, line = TOOLS[kind]
    s = Sprite(AVATAR_W, AVATAR_H)
    prongs = s.line([(12, 58), (7, 33)]) | s.line([(13, 58), (17, 33)])
    tips = s.rect(6, 31, 3, 2) | s.rect(16, 31, 3, 2)
    s.fill(prongs, light)
    s.fill(tips, base)
    s.put(6, 31, hi)
    s.outline(line)
    if kind == "goldtongs":
        sparkle(s, 4, 30, "white")
        sparkle(s, 19, 36, "glow")
    return s


AVATAR_LAYERS = {
    "skin": (list(SKIN_TONES), avatar_head),
    "face": (CHARACTERS, avatar_face),
    "hands": (list(SKIN_TONES), avatar_hands),
    "outfit": (list(OUTFITS), avatar_outfit),
    "hat": (AVATAR_HATS, avatar_hat),
    "tool": (list(TOOLS), avatar_tool),
}


def avatar_sprites():
    out = {}
    for layer, (ids, make) in AVATAR_LAYERS.items():
        for i in ids:
            out[f"avatar/{layer}/{i}.png"] = make(i)
    for style in HAIR_COLORS:
        for character in CHARACTERS:
            out[f"avatar/hair/{style}_{character}.png"] = avatar_hair(style, character)
    return out


def avatar_full(tone="skin1", character="girl", style="short", outfit="apron", hat=None, tool="tongs"):
    """All layers composed, for previews and the app icon."""
    s = Sprite(AVATAR_W, AVATAR_H)
    layers = [avatar_head(tone), avatar_face(character), avatar_outfit(outfit), avatar_hair(style, character)]
    if hat:
        layers.append(avatar_hat(hat))
    layers += [avatar_tool(tool), avatar_hands(tone)]
    for layer in layers:
        s.paste(layer)
    return s
