import pathlib,json,shutil
root=pathlib.Path(__file__).resolve().parents[2]
dest=root/'이미지/추가 생성 이미지'
files=sorted((dest/'avatar/boy').glob('*.png'))+sorted((dest/'cook').glob('boy_*.png'))+[root/'assets/images/avatar/boy/base.png']
backup=root/'output/imagegen/boy_eyelashes_backup'
jobs=[]
for file in files:
    rel=file.relative_to(root).as_posix()
    saved=backup/rel
    saved.parent.mkdir(parents=True,exist_ok=True)
    if not saved.exists():shutil.copy2(file,saved)
    jobs.append({'path':rel,'reference':saved.relative_to(root).as_posix(),'transparent':rel=='assets/images/avatar/boy/base.png','prompt':'Precise localized edit of the supplied image. Change ONLY the male character eyelashes. Remove every protruding lash spike along the upper eyelid except at its outer corner. Each eye must have exactly one very short subtle eyelash protruding only at the far outer eye corner, pointing outward. The inner corner and middle of both upper lids are smooth, with no protruding eyelash spikes. Preserve the eye shapes, pupils, gaze, mouth and existing expression, skin, hairstyle, all clothing and accessories, hands, pose, scene objects, counter and cooking action, composition, original framing, dimensions, pixel art rendering, palette, and background. Keep existing glasses and closed-eye expressions intact where present. Keep the thin upper eyelid line; avoid thick eyeliner and long feminine eyelashes. Do not add text or labels. Preserve transparency if the source has it; otherwise preserve the original white background. One edited image only.'})
(root/'output/imagegen/eyelash_jobs.json').write_text(json.dumps(jobs,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'male_images':len(jobs),'backup':str(backup)},ensure_ascii=False))
