import pathlib,json
from PIL import Image,ImageDraw
root=pathlib.Path(__file__).resolve().parents[2]
jobs=json.loads((root/'output/imagegen/eyelash_jobs.json').read_text(encoding='utf-8'))
for start in range(0,len(jobs),20):
    canvas=Image.new('RGB',(1400,1800),'#eee');draw=ImageDraw.Draw(canvas)
    for k,j in enumerate(jobs[start:start+20]):
        with Image.open(root/j['reference']) as im:
            im=im.convert('RGBA');im.thumbnail((270,410))
            x=(k%5)*280;y=(k//5)*450
            canvas.paste(im,(x+(280-im.width)//2,y),im)
            draw.text((x+4,y+414),str(start+k)+' '+pathlib.Path(j['path']).name,fill='black')
    canvas.save(root/f'output/imagegen/boy_inspection_{start//20}.jpg')
print('Inspection sheets: 8')
