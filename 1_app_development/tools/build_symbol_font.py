"""Builds assets/fonts/BungeoSymbols-Regular.ttf: the punctuation and symbols
that Jua lacks, cut from Noto Sans KR (SIL OFL 1.1).

Jua has no `·`, `…`, `‘’`, `→`, `「」`, `—`, `×`, `●○` and the like. The app
lists this font as Jua's fallback (ui/cozy_style.dart `Cozy.fontFallback`),
so those glyphs never show as boxes, on any device or in a golden test.

Usage (from 1_app_development/):
  python tools/build_symbol_font.py <path to NotoSansKR[wght].ttf>
The source is https://github.com/google/fonts/tree/main/ofl/notosanskr.
The output is renamed because the OFL forbids a modified font from keeping
a reserved name; its license is assets/fonts/BungeoSymbols-OFL.txt.
"""
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

# Ranges, not single code points, so a new sentence with a sibling symbol
# (for example `↓` next to `→`) keeps working.
RANGES = [
    (0x00A0, 0x00BF),  # Latin-1 punctuation: · « » ° ±
    (0x00D7, 0x00D7),  # ×
    (0x00F7, 0x00F7),  # ÷
    (0x2010, 0x2027),  # dashes, quotes, bullets, …
    (0x2030, 0x203B),  # ‰ ′ ″ ※
    (0x2190, 0x2199),  # arrows
    (0x2460, 0x2473),  # circled numbers ①
    (0x25A0, 0x25FF),  # geometric shapes ● ○ ■ □ ▶ ◆
    (0x2600, 0x266F),  # ☆ ★ ♥ ♪
    (0x2713, 0x2714),  # ✓ ✔
    (0x3000, 0x3011),  # CJK punctuation 「」『』〈〉
    (0x318D, 0x318D),  # ㆍ
    (0xFF5E, 0xFF5E),  # ～
]
FAMILY = 'BungeoSymbols'
OUT = 'assets/fonts/BungeoSymbols-Regular.ttf'


def main(source: str) -> None:
    font = TTFont(source)
    if 'fvar' in font:
        # Jua is a heavy rounded face; a medium-bold weight sits closest.
        font = instancer.instantiateVariableFont(font, {'wght': 600})
    cmap = font.getBestCmap()
    unicodes = [u for a, b in RANGES for u in range(a, b + 1) if u in cmap]
    options = subset.Options()
    options.name_IDs = ['*']
    options.notdef_outline = True
    options.layout_features = ['*']
    sub = subset.Subsetter(options)
    sub.populate(unicodes=unicodes)
    sub.subset(font)
    name = font['name']
    for record in list(name.names):
        if record.nameID in (1, 16):
            record.string = FAMILY
        elif record.nameID in (2, 17):
            record.string = 'Regular'
        elif record.nameID in (3, 4):
            record.string = f'{FAMILY} Regular'
        elif record.nameID == 6:
            record.string = f'{FAMILY}-Regular'
        elif record.nameID == 25:
            name.names.remove(record)
    font.save(OUT)
    print(f'{OUT}: {len(unicodes)} glyphs')


if __name__ == '__main__':
    main(sys.argv[1])
