"""Inventory of every avatar item for sale (stage 26 4-4).

For girl and boy, each item of config/development_balance.json's
avatar_catalog gets one row: is its art in assets/images (and made how),
only in the original folder, or nowhere? Writes build/avatar_audit/audit.md
(or audit_<tag>.md) for the stage report. Read-only on the art.

  python tools/avatar_audit.py [tag]
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import avatar_layers as L  # noqa: E402

ROOT = L.ROOT
OUT = ROOT / 'build' / 'avatar_audit'

# What the base picture itself already wears (no layer of its own).
IN_BASE = {'girl', 'boy', 'skin1', 'long', 'tee', 'shorts', 'flats'}
BLANK = {'nohat', 'noacc', 'noapron'}
# Hats need a worn picture (PixelSprites.avatarWornOnlySlots).
WORN_ONLY = {'hat', 'hair'}


def source_for(character, slot, item):
    for stem, (s, i) in L.WORN_ITEMS.items():
        if (s, i) == (slot, item) and (L.WORN_SRC / character / f'{stem}.png').exists():
            return f'{character}/{stem}.png'
    if slot == 'skin' and (L.WORN_SRC / character / f'skin_{item}.png').exists():
        return f'{character}/skin_{item}.png'
    return None


def status(character, slot, item, worn):
    """(art, how, shown)"""
    if item in IN_BASE:
        return 'base에 포함', '-', True
    if item in BLANK:
        return '그림 없음(빈 칸)', '-', True
    src = source_for(character, slot, item)
    if slot == 'skin':
        path = L.IMAGES / 'avatar' / character / f'base@{item}.png'
        if path.exists():
            return '에셋 있음', '색 치환(@skin)', True
        return ('원본만' if src else '원본 없음'), '-', False
    key = f'avatar/{character}/{slot}_{item}.png'
    if (L.IMAGES / key).exists():
        how = 'worn 레이어' if key in worn else \
            '색 바꿈(derive)' if f'{slot}_{item}' in L.DERIVED else '평면 그림'
        shown = how == 'worn 레이어' or slot not in WORN_ONLY
        return '에셋 있음', how, shown
    return ('원본만' if src else '원본 없음'), '-', False


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else ''
    catalog = json.loads((ROOT / 'config' / 'development_balance.json')
                         .read_text('utf-8'))['avatar_catalog']
    worn = set(L.load_data().get('worn', {}))
    lines = ['# 아바타 아이템 전수 조사' + (f' ({tag})' if tag else ''), '',
             '| 칸 | id | 이름 | 무료 | girl 그림 | girl 방식 | girl 노출 | boy 그림 | boy 방식 | boy 노출 |',
             '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    counts = {}
    for item, row in catalog.items():
        cells = []
        for character in ('girl', 'boy'):
            art, how, shown = status(character, row['slot'], item, worn)
            counts[(character, shown)] = counts.get((character, shown), 0) + 1
            cells += [art, how, '노출' if shown else '숨김']
        lines.append(f"| {row['slot']} | {item} | {row['label']} | "
                     f"{'예' if row['free'] else ''} | " + ' | '.join(cells) + ' |')
    lines += ['', f"합계 {len(catalog)}개. " + ', '.join(
        f"{c} 노출 {counts.get((c, True), 0)} · 숨김 {counts.get((c, False), 0)}"
        for c in ('girl', 'boy'))]
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / (f'audit_{tag}.md' if tag else 'audit.md')
    out.write_text('\n'.join(lines) + '\n', 'utf-8')
    print(f'wrote {out}')


if __name__ == '__main__':
    main()
