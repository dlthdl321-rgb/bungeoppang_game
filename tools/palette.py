"""Shared pixel-art palette: every game image uses only these colors."""

PALETTE = {
    # pastry
    "cream": "#FFF4E0", "light": "#FFE9A8", "butter": "#F8D27A", "gold": "#E0A040",
    "toast": "#A8642F", "cocoa": "#6B3A1F", "outline": "#4A2C2A", "deep": "#2A1A18",
    # night / sky
    "snow": "#F4F7FF", "ice": "#AFC3E8", "dusk_blue": "#5B6BA8", "navy2": "#2E3466",
    "navy": "#1E2140", "night": "#141830", "purple": "#4B3F72", "plum": "#6E4A7E",
    # warm lights
    "peach": "#FFC9A0", "orange": "#FF9E4A", "red": "#D9573B", "wine": "#8C2F39",
    # pastel accents
    "pink": "#F6B3C2", "rose": "#E07A98", "mint": "#B9E3A8", "green": "#5E9E5A",
    "forest": "#2F5B48", "forest_dark": "#1C3530", "sky": "#9AD3E8", "teal": "#2F6F8A",
    "lavender": "#B28AD8",
    # wood / neutrals
    "wood": "#5C3A28", "wood_dark": "#3A2420", "grey": "#C9C2BA", "stone": "#7A726C",
    # vendor skin tones (used with cream, peach, toast and wood_dark)
    "tan": "#D9A07A", "umber": "#8A5536",
}

GAME_PALETTE = list(PALETTE.values())
