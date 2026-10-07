import pathlib,json
from PIL import Image,ImageDraw
root=pathlib.Path(__file__).resolve().parents[2]
jobs=json.loads((root/'output/imagegen/eyelash_jobs.json').read_text(encoding='utf-8'))
for start in range(0,len(jobs),20):
    sheet=Image.new('RGB',(1500,1200),'#e8e8e8');draw=ImageDraw.Draw(sheet)
    for k,j in enumerate(jobs[start:start+20]):
        with Image.open(root/j['path']) as im:
            im=im.convert('RGBA');w,h=im.size
            if '/cook/' in j['path']:box=(int(w*.40),int(h*.02),int(w*.95),int(h*.48))
            else:box=(int(w*.10),int(h*.05),int(w*.9),int(h*.4))
            face=im.crop(box);face.thumbnail((288,265))
            x=(k%5)*300;y=(k//5)*300
            sheet.paste(face,(x+(300-face.width)//2,y+(270-face.height)//2),face)
            draw.text((x+3,y+274),str(start+k)+' '+pathlib.Path(j['path']).name,fill='black')
    sheet.save(root/f'output/imagegen/eyelash_results_{start//20}.jpg')
print('Eight inspection sheets created.')
