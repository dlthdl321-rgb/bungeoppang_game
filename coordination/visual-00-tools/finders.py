# 사용: 저장소의 1_app_development 폴더에서 python -I -X utf8 ../coordination/visual-00-tools/finders.py . > 결과.md
"""Collect every finder the widget tests use and where each Key is defined in lib/."""
import collections
import pathlib
import re
import sys

app = pathlib.Path(sys.argv[1])
tests = sorted((app / 'test').glob('*.dart'))
lib = {p: p.read_text(encoding='utf-8') for p in (app / 'lib').rglob('*.dart')}

patterns = {
    'key': r"(?<![A-Za-z])(?:Value)?Key\(\s*'([^']+)'\s*\)",
    'tooltip': r"find\.byTooltip\(\s*'([^']+)'",
    'text': r"find\.text\(\s*'([^']+)'",
    'textContaining': r"find\.textContaining\(\s*'([^']+)'",
    'widgetWithText': r"find\.widgetWithText\(\s*(\w+)\s*,\s*'([^']+)'",
    'semantics': r"find\.bySemanticsLabel\(\s*'([^']+)'",
    'type': r"find\.byType\(\s*([A-Za-z_]\w*)",
    'predicate': r"find\.byWidgetPredicate\(",
}
found = {k: collections.defaultdict(set) for k in patterns}
for t in tests:
    s = t.read_text(encoding='utf-8')
    for kind, pat in patterns.items():
        for m in re.finditer(pat, s):
            value = ' / '.join(m.groups()) if m.groups() else f'(line {s[:m.start()].count(chr(10)) + 1})'
            found[kind][value].add(t.stem)


INTERP = re.compile(r"\$\{[^}]*\}|\$\w+")
lib_keys = []  # (file, literal, regex)
for p, s in lib.items():
    for m in re.finditer(r"(?<![A-Za-z])(?:Value)?Key\(\s*'([^']+)'\s*\)", s):
        lit = next(g for g in m.groups() if g)
        parts = INTERP.split(lit)
        rx = re.compile('^' + '.+'.join(re.escape(x) for x in parts) + '$')
        if not any(parts): continue
        lib_keys.append((p.relative_to(app / 'lib').as_posix(), lit, rx))


def defined_in(key):
    """lib files whose Key literal matches [key]; only the most specific
    (longest fixed text) patterns are kept, so 'buy-${id}' does not claim
    'buy-cosmetic-boy' when 'buy-cosmetic-${id}' exists."""
    best, hits = -1, set()
    test_prefix = INTERP.split(key)[0]
    for f, lit, rx in lib_keys:
        fixed = len(''.join(INTERP.split(lit)))
        ok = lit == key or rx.match(key) or (
            '$' in key and test_prefix and INTERP.split(lit)[0] == test_prefix)
        if not ok:
            continue
        if fixed > best:
            best, hits = fixed, {f}
        elif fixed == best:
            hits.add(f)
    return ', '.join(sorted(hits)) or '(lib에 없음)'


out = []
for kind in patterns:
    rows = found[kind]
    out.append(f'## {kind} ({len(rows)})\n')
    if kind == 'key':
        out.append('| Key | 정의된 lib 파일 | 참조 테스트 |\n| --- | --- | --- |')
        for v in sorted(rows):
            out.append(f'| `{v}` | {defined_in(v)} | {", ".join(sorted(rows[v]))} |')
    else:
        out.append('| 값 | 참조 테스트 |\n| --- | --- |')
        for v in sorted(rows):
            out.append(f'| `{v}` | {", ".join(sorted(rows[v]))} |')
    out.append('')
print('\n'.join(out))
