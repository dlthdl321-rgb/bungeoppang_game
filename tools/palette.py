"""Shared pixel-art palette: every game image uses only these colors.

Pastel storybook look. Colors come in ramps from light to dark; the darkest
step of a ramp is that object's outline, so nothing uses a black line.
"""

PALETTE = {
    # neutrals
    "white": "#FFFFFF", "snow": "#F6F3FB", "mist": "#DDD6EA", "stone": "#A9A0BE",
    "slate": "#776F92", "ink": "#4A4363",
    # pastry crust (honey -> baked)
    "cream": "#FFF6E3", "honey_light": "#FFE6A8", "honey": "#F8C871", "caramel": "#E59F55",
    "bake": "#BE7442", "crust_line": "#8C5137",
    # chocolate
    "choco0": "#E3B79C", "choco1": "#C98B6B", "choco2": "#9C5F45", "choco3": "#6E3D2E",
    "choco4": "#4A2820",
    # pink
    "pink0": "#FFF0F4", "pink1": "#FFD3DE", "pink2": "#F8A9BE", "pink3": "#E27E9C",
    "pink4": "#B4577A", "blush": "#FF9DB6",
    # mint
    "mint0": "#ECFBF0", "mint1": "#C8F0D4", "mint2": "#98DDB2", "mint3": "#63BA8C",
    "mint4": "#3F8A67",
    # lilac
    "lilac0": "#F3ECFF", "lilac1": "#DCCBF8", "lilac2": "#BBA6EC", "lilac3": "#9783D8",
    "lilac4": "#6F5DB6",
    # twilight sky (top of the scene, dark enough for cream UI text)
    "night_deep": "#2D2869", "dusk_deep": "#3F3784", "twilight": "#5A4FA3",
    "periwinkle": "#7E72C6",
    # sea / sky blue
    "sea0": "#D3F0FA", "sea1": "#9FD6EC", "sea2": "#68B0D6", "sea3": "#4683B8",
    "sea4": "#325E96",
    # peach / sunset
    "peach0": "#FFEADD", "peach1": "#FFCDAE", "peach2": "#F8A27C", "peach3": "#DB7A5C",
    # warm lights
    "glow": "#FFF5BE", "lemon": "#FFE07D", "coral": "#F57373", "berry": "#D9505C",
    "wine": "#A13B52",
    # sweet potato
    "potato1": "#CDA6E6", "potato2": "#A77CCB",
    # soft wood
    "wood0": "#F0C796", "wood1": "#D9A16C", "wood2": "#B47A4E", "wood3": "#8A5638",
    "wood4": "#62392A",
    # foliage at dusk
    "leaf1": "#7FBF9A", "leaf2": "#5A9C7E", "leaf3": "#417A68", "leaf4": "#2F5A55",
    # vendor skin tones: light, base, shade, line
    "skin1a": "#FFEADB", "skin1b": "#FFD5BF", "skin1c": "#F3B49B", "skin1d": "#CF8C78",
    "skin2a": "#F8D3B2", "skin2b": "#EBB08A", "skin2c": "#CF8E68", "skin2d": "#A66A4E",
    "skin3a": "#CC9470", "skin3b": "#A9704F", "skin3c": "#86533B", "skin3d": "#5C3727",
    # hair
    "hair_brown1": "#9A6248", "hair_brown2": "#73452F", "hair_brown3": "#4F2E22",
    "hair_gold1": "#F4CF7E", "hair_gold2": "#D9A456", "hair_gold3": "#A87338",
}

GAME_PALETTE = list(PALETTE.values())
