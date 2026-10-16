import pathlib,json
import numpy as np
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[2]
jobs=json.loads((root/'output/imagegen/eyelash_jobs.json').read_text(encoding='utf-8'))
generated=pathlib.Path('C:/Users/이소이/.codex/generated_images/01a115e0-894c-70d0-8d96-15f8bbd3d591')
files=sorted(generated.glob('*.png'))
def features(file):
    with Image.open(file) as im:
        im=im.convert('RGBA'); bg=Image.new('RGBA',im.size,'white');bg.alpha_composite(im)
        return np.asarray(bg.convert('RGB').resize((96,96)),dtype=np.float32).reshape(-1)/255
refs=np.array([features(root/j['reference']) for j in jobs])
matches=[]
for file in files:
    f=features(file)
    distances=np.mean((refs-f)**2,axis=1)
    order=np.argsort(distances)
    best,second=order[:2]
    if distances[best]<0.008 and distances[second]>distances[best]*1.15:
        matches.append({'path':jobs[best]['path'],'reference':jobs[best]['reference'],'source':str(file),'distance':float(distances[best]),'ratio':float(distances[second]/max(distances[best],1e-9))})
chosen={}
for match in matches:
    if match['path'] not in chosen or match['distance']<chosen[match['path']]['distance']:chosen[match['path']]=match
results=sorted(chosen.values(),key=lambda j:j['path'])
(root/'output/imagegen/recovered_eyelash_outputs.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'matched':len(results),'files':[(j['path'],round(j['distance'],5),round(j['ratio'],2)) for j in results]},ensure_ascii=True))
