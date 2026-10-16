import json, re, pathlib, shutil
root = pathlib.Path(__file__).resolve().parents[2]
dest = root / '이미지/추가 생성 이미지'
source = root / '오늘의붕어빵_이미지생성프롬프트_통합_261007_0223_01.md'
text = source.read_text(encoding='utf-8-sig')
style = re.search(r'\*\*\[STYLE\].*?```\s*(.*?)```', text, re.S).group(1).strip()
raw = '이미지/bungeoppang_raw_assets_261007_0114_01/raw/'
jobs = []
def add(path, ref, prompt):
    previous = root / 'output/imagegen/from_300' / path
    target = dest / path
    if not target.exists() and previous.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(previous, target)
    jobs.append(dict(path=path, reference=ref, prompt=style+'\n'+prompt))
groups=json.loads((dest/'generation_prompts.json').read_text(encoding='utf-8-sig'))
sweater=next(p['prompt'] for g in groups for p in g['prompts'] if p['path']=='cook/boy_2_outfit_sweater.png')
for n in range(3,7):
    jobs.append(dict(path=f'cook/boy_{n}_outfit_sweater.png',reference=f'이미지/추가 생성 이미지/cook/boy_{n}.png',prompt=sweater))
for section in range(7,15):
    body=re.search(rf'^## {section}\. .*?(?=^## |\Z)',text,re.M|re.S).group(0)
    rows=[]
    for line in body.splitlines():
        if line.startswith('|'):
            cells=[c.strip().strip('`') for c in line.strip('|').split('|')]
            if len(cells)>1 and not cells[0].startswith('-') and cells[0] not in ('파일','id'):
                rows.append(cells)
    for cells in rows:
        name=cells[0]
        if section==7:
            names=name.split(' / ')
            changes=re.findall(r'`([^`]+)`', next(l for l in body.splitlines() if l.startswith('| '+name+' |')))
            for name, change in zip(names,changes):
                add('customer/'+name+'.png',raw+'customers/customers_001.png','One chibi customer only, full body, same character design as the input: short black wavy bob, light blue jacket over a cream top, cream pants, brown crossbody bag. Pose: '+change+'. Plain solid flat white background, no ground, no shadow.')
        elif section==8:
            add('deco/'+name+'.png',raw+'backgrounds/backgrounds_002.png','One stall decoration only, front view: '+cells[1]+'. Plain solid flat white background.')
        elif section==9:
            add('bg/'+name+'.png',raw+'backgrounds/backgrounds_002.png','Exactly the same composition, framing and layout as the input image (the striped awning, wooden posts, lantern, the bungeoppang in its iron mold and the wooden counter stay in the same place and size). Change only the scene: '+cells[1]+'. Vertical, same aspect ratio as the input.')
        elif section in (10,12):
            add('icons/'+name+'.png','assets/images/icons/coin.png','One small game UI icon only, bold and readable at small size, warm palette of cream, caramel, golden and brick red, dark chocolate-brown outline. Subject: '+cells[-1]+'. Plain solid flat white background.')
        elif section==11:
            ref=re.search(r'backgrounds_\d+',cells[1]).group(0)
            add('bg/'+name+'.png',raw+'backgrounds/'+ref+'.png','Redraw the input image at a much higher resolution (about 1080 x 2456) with a finer, denser pixel grid and more detail, keeping exactly the same composition, framing, colors and the position and size of every object (awning, posts, lantern, the bungeoppang in its iron mold, the counter). Do not add or remove anything. Preserve the original aspect ratio.')
        elif section==13:
            ref='assets/images/stove/iron.png' if name.startswith('stove/') else 'assets/images/fish/redbean.png'
            add(name+'.png',ref,'Exactly the same object, shape, size and position as the input image. Change only this: '+cells[1]+'. Plain solid flat white background.')
        elif section==14:
            ref=re.search(r'backgrounds_\d+',cells[1]).group(0)
            add(name,raw+'backgrounds/'+ref+'.png','Exactly the same composition, framing, objects and their positions as the input image (awning, posts, lantern, the bungeoppang in its iron mold, the counter, every shop and tree). Change only the time of day to night: '+cells[2]+'. Do not add or remove anything. Vertical, preserve original aspect ratio.')
pending=[j for j in jobs if not (dest/j['path']).exists()]
(root/'output/imagegen/remaining_jobs.json').write_text(json.dumps(pending,ensure_ascii=False,indent=2),encoding='utf-8')
(root/'output/imagegen/expected_additions.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'expected':len(jobs),'pending':len(pending),'files':[j['path'] for j in pending]},ensure_ascii=False))
