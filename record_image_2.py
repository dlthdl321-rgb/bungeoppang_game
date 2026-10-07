import json, sys, shutil
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parent
out=root/'이미지/추가 생성 이미지 2'
prompts=out/'generation_prompts.json'
jobs=json.loads(prompts.read_text(encoding='utf-8'))
index=int(sys.argv[1])
source=Path(sys.argv[2])
target=out/jobs[index-1]['file']
target.parent.mkdir(parents=True,exist_ok=True)
if source.resolve()!=target.resolve():
    if target.exists():
        raise RuntimeError('Destination already exists')
    shutil.copy2(source,target)
with Image.open(target) as im:
    im.verify()
with Image.open(target) as im:
    size=list(im.size)
jobs[index-1].update(status='generated',source=str(source),actual_size=size,tool='built-in image_gen')
prompts.write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
manifest={'total':len(jobs),'generated':sum(j['status']=='generated' for j in jobs),'images':jobs}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'index':index,'file':jobs[index-1]['file'],'actual_size':size,'generated':manifest['generated']},ensure_ascii=True))
