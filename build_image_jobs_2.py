import json, re
from pathlib import Path

root = Path(__file__).resolve().parent
source = root / 'docs/prompts/오늘의붕어빵_추가생성필요이미지프롬프트_261008_0015_01.md'
doc = source.read_text(encoding='utf-8')
blocks = re.findall(r'```\s*\n(.*?)```', doc, re.S)
style = blocks[0].strip()
old = root / '이미지/추가 생성 이미지'
out = root / '이미지/추가 생성 이미지 2'
out.mkdir(parents=True, exist_ok=True)
jobs = []
def add(name, prompt, refs=(), size='1254×1254'):
    jobs.append(dict(index=len(jobs)+1, file=name, prompt=f'Output dimensions: {size}.\n'+prompt.replace('<STYLE>', style).strip(), references=[str(p) for p in refs], status='pending'))
for i, name in enumerate(['iron', 'castiron', 'copper', 'golden']):
    add(f'stove/{name}.png', blocks[1+i], [] if i == 0 else [out/'stove/iron.png'], '2048×1024')
for i, char in enumerate(['girl', 'boy']):
    add(f'avatar/{char}/accessory_fishbrooch.png', blocks[5+i], [old/f'avatar/{char}/face_neutral.png'], 'same as reference')
add('customer/stand.png', blocks[7], [old/'customer/walk_1.png'], '1024×1536')
add('customer/leave_2.png', blocks[8], [old/'customer/leave_1.png'], '1024×1536')
for name, extra in [('dusk',''), ('forest','Fireflies glow softly between the trees.'), ('seaside','Moonlight reflects on the water and the harbour boats have small lights.')]:
    add(f'bg/{name}_night.png', blocks[9].replace('<EXTRA>',extra), [old/f'bg/{name}.png',old/'bg/clear_night.png'], 'same as first reference')
for name, content in re.findall(r'\| `icons/([^`]+)\.png` \|[^|]+\| ([^|]+)\|', doc):
    add(f'icons/{name}.png',blocks[10].replace('<CONTENT>',content.strip()),[old/'icons/settings.png'])
section = doc.split('## 6.')[1].split('## 7.')[0]
for slot, chars, change in re.findall(r'\| `([^`]+)` \|[^|]+\| ([^|]+)\|\s*\d+\s*\| ([^|]+)\|',section):
    for char in (['girl','boy'] if '여·남' in chars else ['boy']):
        for frame in range(1,7):
            prompt=blocks[11 if char=='girl' else 12].replace('<CHANGE>',change.strip())
            if char=='boy' and slot.startswith('bottom_'):
                prompt=prompt.replace('longer beige shorts, ','')
            refs=[old/f'cook/{char}_{frame}.png']
            design=root/f'assets/images/avatar/{char}/{slot}.png'
            if design.exists():
                refs.append(design)
                prompt+='\nImage 1 is the edit target. Image 2 is only the appearance design reference; preserve Image 1 scene and pose.'
            add(f'cook/{char}_{frame}_{slot}.png',prompt,refs)
for face,change in re.findall(r'\| `(neutral|grin|wink|sleepy|surprised)` \| ([^|]+)\|',doc):
    for char in ['girl','boy']:
        for frame in range(1,7):
            add(f'cook/{char}_{frame}_face_{face}.png',blocks[11 if char=='girl' else 12].replace('<CHANGE>',change.strip()),[old/f'cook/{char}_{frame}.png'])
assert len(jobs)==324, len(jobs)
missing=sorted({p for j in jobs for p in j['references'] if not Path(p).exists() and not str(p).startswith(str(out))})
assert not missing, missing
(out/'generation_prompts.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Prepared {len(jobs)} image prompts.')
