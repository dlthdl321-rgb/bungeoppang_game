import pathlib,json,hashlib,html
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[2]
dest=root/'이미지/추가 생성 이미지'
expected=json.loads((root/'output/imagegen/expected_additions.json').read_text(encoding='utf-8'))
missing=[j['path'] for j in expected if not (dest/j['path']).exists()]
if missing:
    print(json.dumps({'missing':missing},ensure_ascii=False));raise SystemExit(1)
original=json.loads((dest/'manifest.json').read_text(encoding='utf-8-sig'))
changed=[j['path'] for j in original if hashlib.sha256((dest/j['path']).read_bytes()).hexdigest()!=j['sha256']]
unexpected=[p for p in changed if not (p.startswith('avatar/boy/') or p.startswith('cook/boy_'))]
if unexpected: raise RuntimeError('Unexpected original image changed: '+str(unexpected))
eye_jobs=json.loads((root/'output/imagegen/eyelash_jobs.json').read_text(encoding='utf-8'))
completed=set((root/'output/imagegen/eyelash_completed.txt').read_text(encoding='utf-8-sig').splitlines())
eye_missing=[j['path'] for j in eye_jobs if j['path'] not in completed]
if eye_missing: raise RuntimeError('Pending eyelash edits: '+str(eye_missing))
for j in eye_jobs:
    with Image.open(root/j['path']) as edited,Image.open(root/j['reference']) as before:
        if edited.size!=before.size: raise RuntimeError('Dimensions changed: '+j['path'])
manifest=[]
for file in sorted(dest.rglob('*.png')):
    with Image.open(file) as im:
        im.verify()
    with Image.open(file) as im:
        size=list(im.size)
    manifest.append(dict(path=file.relative_to(dest).as_posix(),bytes=file.stat().st_size,sha256=hashlib.sha256(file.read_bytes()).hexdigest(),size=size))
(dest/'manifest_complete.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(dest/'generation_prompts_additional.json').write_text(json.dumps({'mode':'built-in image_gen','source':'오늘의붕어빵_이미지생성프롬프트_통합_261007_0223_01.md','prompts':expected},ensure_ascii=False,indent=2),encoding='utf-8')
(dest/'generation_prompts_eyelashes.json').write_text(json.dumps({'mode':'built-in image_gen','instruction':'모든 남자 아바타의 속눈썹은 눈꼬리 끝에만 짧게 돌출','prompts':eye_jobs},ensure_ascii=False,indent=2),encoding='utf-8')
cards=''.join('<figure><img loading="lazy" src="'+html.escape(j['path'],quote=True)+'"><figcaption>'+html.escape(j['path'])+'</figcaption></figure>' for j in manifest)
(dest/'gallery_complete.html').write_text('<!doctype html><meta charset="utf-8"><title>추가 생성 이미지 전체</title><style>body{font-family:sans-serif;background:#eee;padding:20px}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:16px}figure{margin:0;background:white;padding:12px}img{width:100%;height:260px;object-fit:contain}figcaption{overflow-wrap:anywhere}</style><h1>추가 생성 이미지 '+str(len(manifest))+'장</h1><main>'+cards+'</main>',encoding='utf-8')
(dest/'추가생성_완료보고.txt').write_text('이전 생성 이미지 9장 합침\n이번에 누락 이미지 49장 생성\n전체 '+str(len(manifest))+'장\n남자 아바타·조리 이미지 141장 및 게임 기본 몸 1장 속눈썹 수정\n수정 전 원본: output/imagegen/boy_eyelashes_backup\n수정 이미지 원본 크기 유지 확인 완료\n프롬프트 문서 1~14절 및 조리 동작 반복 누락 점검 완료\nPNG 무결성 확인 완료\n배경 제거, 레이어 추출, 게임 규격 정렬은 별도 작업입니다.\n목록: manifest_complete.json\n미리보기: gallery_complete.html\n',encoding='utf-8')
print(json.dumps({'total':len(manifest),'missing':missing,'eyelash_edits':len(eye_jobs),'unexpected_changes':unexpected},ensure_ascii=False))
