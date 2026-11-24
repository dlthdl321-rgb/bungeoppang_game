"""25번 42번 확정본 만들기 (2026-11-20 사용자 결정, DEC-147).

사용자 결정: 생성 시안 `42_v1_bare_base/<girl|boy>/base_skin1.png`(880x1787)을
그대로 확정하되 머리 쪽 회색(머리 덮개)만 지운다. 얼굴·몸은 시안 그대로
(v1 원본 픽셀로 복원하지 않음).

1. 회색 머리 덮개 지우기 (시안 크기 그대로)
   * 덮개 = 머리 위쪽(행 < 700)의 불투명·채도 낮은 밝은 픽셀 중 가장 큰 덩어리.
   * 덮개 자리와 덮개·이마 사이 경계선(덮개에서 SEAM px 안, 바깥 투명에서 OUTER px
     보다 안쪽)을 주변 깨끗한 이마·얼굴 피부의 가우시안 평균색으로 칠함
     -> 이마와 두피가 매끈하게 이어짐. 덮개 양옆 아래 끝
     TIP행은 덮개 밖을 건드리지 않아 귀 윗선·얼굴 옆선이 남음.
   * 바깥 외곽선(투명에서 OUTER px 안)은 그대로 두되, 외곽선과 회색이 섞인
     중간 픽셀은 회색 몫만 피부색으로 바꿈(진갈색 외곽선이 끊기지 않음).
   * 회색 민소매·속바지·맨발은 손대지 않음(행 700 아래는 보지 않음).
2. 1120x2080 정규화 (1_app_development/tools/normalize_avatar_base.py의
   landmarks·place 재사용): 성별마다 균일 배율 하나 + 평행 이동.
   * 배율: 눈 중심 -> 발바닥 거리를 지금 v1 사장님(42/reference 4배 파일:
     여자 눈 620행·발바닥 끝 2012, 남자 624·2024)과 같게 = 화면에서 v1과 같은 크기.
   * 세로: 발바닥 마지막 불투명 행을 2079에(23번·v2 틀과 같은 발 줄).
   * 가로: 눈 중심 x를 v1 x(여자 614, 남자 606)에.
   * 결과 눈·입·발 좌표는 결과 그림에서 다시 재서 report.json에 기록.
3. skin2·skin3: skin1 모양 그대로, 피부 픽셀만 23번 정규화에서 맞춘 채널별
   선형 색 맞춤(23_avatar_base/normalized/report.json의 fit_k·fit_m)으로 다시 칠함.

출력(시안·reference 파일은 읽기만):
  42_v1_bare_base/normalized/<girl|boy>/base_skin1~3.png (1120x2080, 알파 0/255)
  42_v1_bare_base/normalized/report.json
  42_v1_bare_base/normalized/compare.png  (시안 / 회색 지운 결과 / 피부톤 3)
  42_v1_bare_base/review/cap_removed_head_zoom.png (머리 확대 전후)

  python "4_image_generation_results_and_backups/26_feedback_generated/42_v1_bare_base/review/finalize_bare_base.py"
(어느 폴더에서 실행해도 됨. numpy·Pillow·scipy 필요)
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as nd

HERE = Path(__file__).resolve().parent
BASE = HERE.parent                      # 42_v1_bare_base
GEN = BASE.parent                       # 26_feedback_generated
REPO = GEN.parent.parent
sys.path.insert(0, str(REPO / '1_app_development' / 'tools'))
import avatar_layers as L  # noqa: E402
import normalize_avatar_base as N  # noqa: E402

CHARS = ('girl', 'boy')
SKINS = ('skin1', 'skin2', 'skin3')
CAP_ROWS = 700      # 덮개를 찾는 위쪽 행 범위(이 아래 민소매·속바지는 안 봄)
SEAM = 13           # 덮개에서 이만큼 안의 경계선·번짐은 피부로 칠함(눈썹은 15px 넘게 떨어짐)
TIP = 4             # 덮개 양옆 아래 끝(귀 윗선 높이) 이 행 수 안의 진한 선은 보존(귀 윗선·얼굴 옆선)
OUTER = 12          # 투명에서 이만큼 안은 바깥 외곽선(회색 몫만 바꿈)
# 시안(880x1787) 좌표 상자 (l, t, r, b)
EYE_BOX = {'girl': (260, 420, 680, 580), 'boy': (260, 480, 680, 640)}
MOUTH_BOX = {'girl': (400, 570, 530, 630), 'boy': (400, 610, 530, 670)}
FOREHEAD = {'girl': (400, 250, 530, 330), 'boy': (400, 300, 530, 380)}
# v1(42/reference 4배 파일)의 눈 중심과 발바닥 끝(마지막 불투명 행 + 1)
V1 = {'girl': {'eyes': (614.0, 620.0), 'sole_edge': 2012.0},
      'boy': {'eyes': (606.0, 624.0), 'sole_edge': 2024.0}}


def load(path):
    return np.array(Image.open(path).convert('RGBA'))


def lum(rgb):
    return rgb[..., 0] * .299 + rgb[..., 1] * .587 + rgb[..., 2] * .114


def remove_cap(a, c):
    """회색 덮개를 피부로. (결과, 정보) 반환."""
    f = a.astype(float)
    rgb = f[..., :3] / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    op = a[..., 3] > 127
    grey = op & (sat < .12) & (mx > .45)
    grey[CAP_ROWS:] = False
    lab, n = nd.label(grey)
    sizes = nd.sum(grey, lab, range(1, n + 1))
    cap = lab == int(np.argmax(sizes)) + 1
    d_cap = nd.distance_transform_edt(~cap)
    d_out = nd.distance_transform_edt(op)        # 투명까지 거리
    l, t, r, b = FOREHEAD[c]
    skin = np.median(f[t:b, l:r, :3].reshape(-1, 3), 0)
    grey_col = np.median(f[cap][:, :3], 0)
    dark = op & (lum(f[..., :3]) < 110) & (d_out <= OUTER)
    outline_col = np.median(f[dark & (d_cap <= SEAM)][:, :3], 0)

    L_ = lum(f[..., :3])
    ys, xs = np.nonzero(cap)
    mid = (xs.min() + xs.max()) / 2
    # 덮개 양옆 아래 끝(귀 위) TIP행 안의 덮개 밖 픽셀은 그대로: 귀 윗선과
    # 귀 앞 얼굴 옆선이 이어지는 자리
    tip = np.zeros_like(cap)
    for side in (xs < mid, xs >= mid):
        bottom = ys[side].max()
        band = np.zeros_like(cap)
        band[bottom - TIP:, :] = True
        cols = np.zeros(cap.shape[1], bool)
        cols[max(xs[side].min() - 20, 0):xs[side].max() + 21] = True
        band &= cols[None, :]
        tip |= band & (np.abs(np.arange(cap.shape[1]) - mid) > 120)[None, :]
    # 덮개에서 SEAM px 안의 경계선·번짐은 모두 칠함(눈썹·눈은 15px 넘게 떨어져
    # 있음). 귀 위 TIP 띠 안의 진한 선(귀 윗선·얼굴 옆선)만 남김.
    seam = op & ~cap & (d_out > OUTER) & (d_cap <= SEAM) & ~(tip & (L_ < 150))
    fill = cap | seam
    # 칠할 색: 깨끗한 이마·얼굴 피부의 정규화 가우시안 평균(가까운 곳은 좁게,
    # 먼 정수리는 넓게) -> 줄무늬 없이 매끈한 두피
    clean = op & L.skinish(a) & (d_cap > SEAM + 2) & (d_out > OUTER) & (L_ > 180)
    clean[CAP_ROWS:] = False
    col = np.zeros_like(f[..., :3])
    done = np.zeros(cap.shape, bool)
    for sigma in (6, 16, 40, 100):
        w = nd.gaussian_filter(clean.astype(float), sigma)
        ok = (w > .05) & ~done
        for ch in range(3):
            num = nd.gaussian_filter(f[..., ch] * clean, sigma)
            col[..., ch] = np.where(ok, num / np.maximum(w, 1e-9), col[..., ch])
        done |= ok
    out = f.copy()
    out[fill, :3] = col[fill]
    # 바깥 외곽선과 회색이 섞인 픽셀: 회색 몫 t만 피부색으로
    edge = op & ~cap & (d_cap <= 8) & (d_out <= OUTER)
    lo, hi = lum(outline_col), lum(grey_col)
    tt = np.clip((L_ - lo) / (hi - lo), 0, 1)
    tt = np.where(edge, tt, 0)[..., None]
    out[..., :3] = np.where(edge[..., None], f[..., :3] + tt * (col - grey_col), out[..., :3])
    out = np.clip(np.round(out), 0, 255).astype(np.uint8)
    ys, xs = np.nonzero(cap)
    info = {'cap_pixels': int(cap.sum()), 'cap_bbox': [int(xs.min()), int(ys.min()),
                                                       int(xs.max()), int(ys.max())],
            'seam_pixels': int(seam.sum()), 'outline_mixed_pixels': int((edge & (tt[..., 0] > 0)).sum()),
            'forehead_median_rgb': [int(round(v)) for v in skin], 'grey_rgb': [int(round(v)) for v in grey_col],
            'outline_rgb': [int(round(v)) for v in outline_col]}
    return out, info


def grey_left(a, rows, eye_box):
    """머리 영역(rows 위, 눈 상자 밖)에 남은 회색 픽셀 수 (덮개 판정과 같은 조건;
    눈 흰자·하이라이트는 눈 상자로 뺌)."""
    rgb = a[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    g = (a[..., 3] > 127) & (sat < .12) & (mx > .45)
    g[rows:] = False
    l, t, r, b = eye_box
    g[t:b + 30, l:r] = False
    lab, n = nd.label(g)
    if n == 0:
        return 0, 0
    sizes = nd.sum(g, lab, range(1, n + 1))
    return int(g.sum()), int(sizes[sizes > 200].sum())


def mouth(a, box):
    l, t, r, b = box
    x = a[t:b, l:r].astype(int)
    rr, gg, bb, al = (x[..., i] for i in range(4))
    red = (rr > 110) & (rr < 235) & (gg < 140) & (bb < 130) & (rr > 1.35 * gg) & (al > 200)
    ys, xs = np.nonzero(red)
    return ((xs.min() + xs.max()) / 2 + l + .5, (ys.min() + ys.max()) / 2 + t + .5)


def skin_mask(a, eye_box):
    """skin1 피부: skinish 덩어리 중 눈 상자 안(홍채)에 중심이 있는 것과 작은 것 제외,
    그 덩어리에 이어진 밝은 붉은 그늘 포함."""
    m = L.skinish(a) & (a[..., 3] > 127)
    lab, n = nd.label(m)
    keep = np.zeros(n + 1, bool)
    el, et, er, eb = eye_box
    for i, sl in enumerate(nd.find_objects(lab), 1):
        part = lab[sl] == i
        size = int(part.sum())
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        in_eye = el <= cx < er and et <= cy < eb and size < 20000
        keep[i] = size >= 300 and not in_eye
    m = keep[lab] & m
    # 목·팔 그늘처럼 skinish보다 붉고 진한 밝은 피부 그늘도 이어진 곳까지 포함
    rgb = a[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    shade = (a[..., 3] > 127) & (r >= g) & (g >= b) & (mx > .75) & (sat > .25) & (sat < .6) & (r - g < .5)
    return nd.binary_propagation(m, structure=np.ones((3, 3)), mask=m | shade)


def checker(w, h):
    bg = Image.new('RGB', (w, h), (230, 226, 220))
    d = ImageDraw.Draw(bg)
    for yy in range(0, h, 10):
        for xx in range((yy // 10) % 2 * 10, w, 20):
            d.rectangle((xx, yy, xx + 9, yy + 9), fill=(246, 243, 238))
    return bg


def font(size):
    try:
        return ImageFont.truetype('malgun.ttf', size)
    except OSError:
        return None


def sheet(rows, path):
    k = 4
    cw, ch = N.CANVAS[0] // k, N.CANVAS[1] // k
    gap, head = 8, 22
    out = Image.new('RGB', (5 * (cw + gap) + gap, len(rows) * (ch + head + gap) + gap), (40, 34, 30))
    d = ImageDraw.Draw(out)
    fnt = font(14)
    for ri, (c, src, capless, normals, lm) in enumerate(rows):
        y0 = gap + ri * (ch + head + gap)
        cells = [(f'{c} 시안(원본)', src, False), (f'{c} 회색 지운 결과', capless, False)] + \
            [(f'{c} {s} 정규화', n, True) for s, n in zip(SKINS, normals)]
        for ci, (label, a, lines) in enumerate(cells):
            x0 = gap + ci * (cw + gap)
            bg = checker(cw, ch)
            img = Image.fromarray(a, 'RGBA')
            if img.size != N.CANVAS:   # 시안: 정규화와 같은 배율로 보이게 캔버스 크기에 맞춰 위쪽 정렬
                sc = min(N.CANVAS[0] / img.width, N.CANVAS[1] / img.height)
                img = img.resize((round(img.width * sc), round(img.height * sc)), Image.LANCZOS)
                big = Image.new('RGBA', N.CANVAS)
                big.paste(img, ((N.CANVAS[0] - img.width) // 2, N.CANVAS[1] - img.height))
                img = big
            small = img.resize((cw, ch), Image.LANCZOS)
            bg.paste(small, (0, 0), small)
            if lines:
                bd = ImageDraw.Draw(bg)
                for (tx, ty), col in ((lm['eyes'], (0, 160, 255)), (lm['mouth'], (230, 40, 160))):
                    bd.line((0, ty / k, cw, ty / k), fill=col)
                    bd.line((tx / k, ty / k - 6, tx / k, ty / k + 6), fill=col)
                bd.line((0, N.SOLE_EDGE / k - 1, cw, N.SOLE_EDGE / k - 1), fill=(0, 170, 60))
            out.paste(bg, (x0, y0 + head))
            d.text((x0 + 2, y0 + 2), label if fnt else label.encode('ascii', 'ignore').decode(),
                   fill=(255, 243, 214), font=fnt)
    out.save(path)


def zoom_sheet(pairs, path):
    """머리 부분 2배 확대: 시안 / 지운 결과, 성별마다 한 줄 (초록 바탕)."""
    tiles = []
    for c, src, capless, box in pairs:
        row = []
        for a in (src, capless):
            im = Image.fromarray(a, 'RGBA').crop(box)
            bg = Image.new('RGBA', im.size, (0, 150, 0, 255))
            bg.alpha_composite(im)
            row.append(bg.resize((im.width * 2, im.height * 2), Image.NEAREST))
        tiles.append(row)
    w = max(r[0].width + r[1].width for r in tiles) + 24
    h = sum(r[0].height for r in tiles) + 8 * (len(tiles) + 1)
    out = Image.new('RGB', (w, h), (40, 34, 30))
    y = 8
    for r in tiles:
        out.paste(r[0], (8, y))
        out.paste(r[1], (16 + r[0].width, y))
        y += r[0].height + 8
    out.save(path)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    dest = BASE / 'normalized'
    fits = json.loads((GEN / '23_avatar_base' / 'normalized' / 'report.json').read_text('utf-8'))
    report = {'canvas': list(N.CANVAS), 'sole_edge': N.SOLE_EDGE,
              'decision': '시안 그대로 + 머리 회색 덮개만 피부로(2026-11-20 사용자, DEC-147)',
              'scale_rule': '눈 중심~발바닥 거리를 v1(42/reference)과 같게, 발바닥 마지막 행 2079, 눈 x = v1 x',
              'characters': {}}
    rows, pairs = [], []
    for c in CHARS:
        src = load(BASE / c / 'base_skin1.png')
        capless, cap_info = remove_cap(src, c)
        left_all, left_big = grey_left(capless, CAP_ROWS, EYE_BOX[c])
        cap_info['grey_left_head_rows'] = left_all
        cap_info['grey_left_head_blobs_over_200px'] = left_big
        lm = N.landmarks(capless, c, EYE_BOX[c], MOUTH_BOX[c])
        lm['mouth'] = mouth(capless, MOUTH_BOX[c])
        v = V1[c]
        s = (v['sole_edge'] - v['eyes'][1]) / (lm['sole'] - lm['eyes'][1])
        dx = v['eyes'][0] - s * lm['eyes'][0]
        dy = N.SOLE_EDGE - s * lm['sole']
        dy -= N.landmarks(N.place(capless, s, dx, dy), c, (0, 0, 1, 1), (0, 0, 1, 1))['sole'] - N.SOLE_EDGE
        mask = skin_mask(capless, EYE_BOX[c])
        normals = []
        tones = {}
        for skin in SKINS:
            if skin == 'skin1':
                painted = capless
                tones[skin] = {'from': '회색 지운 skin1 그대로'}
            else:
                t = fits['characters'][c]['tones'][skin]
                k, m = np.array(t['fit_k']), np.array(t['fit_m'])
                painted = capless.copy()
                rgb = capless[mask][:, :3].astype(float) * k + m
                painted[mask, :3] = np.clip(np.round(rgb), 0, 255).astype(np.uint8)
                tones[skin] = {'from': f'skin1 모양에 23번 {skin} 색 맞춤(채널별 선형) 적용',
                               'fit_k': t['fit_k'], 'fit_m': t['fit_m']}
            tones[skin]['median_skin_rgb'] = [int(x) for x in np.median(painted[mask][:, :3], 0)]
            out = N.place(painted, s, dx, dy)
            (dest / c).mkdir(parents=True, exist_ok=True)
            Image.fromarray(out, 'RGBA').save(dest / c / f'base_{skin}.png', optimize=True)
            normals.append(out)
        got = N.landmarks(normals[0], c, N.scaled_box(EYE_BOX[c], s, dx, dy),
                          N.scaled_box(MOUTH_BOX[c], s, dx, dy))
        got['mouth'] = mouth(normals[0], N.scaled_box(MOUTH_BOX[c], s, dx, dy, pad=4))
        al = normals[0][..., 3] > 0
        ys, xs = np.nonzero(al)
        same = all(np.array_equal(normals[0][..., 3], n[..., 3]) for n in normals[1:])
        res = {k2: [round(float(x), 2) for x in got[k2]] for k2 in ('eyes', 'mouth')}
        res['sole_last_row'] = int(got['sole']) - 1
        report['characters'][c] = {
            'source': f'42_v1_bare_base/{c}/base_skin1.png',
            'cap_removal': cap_info,
            'source_landmarks': {'eyes': [float(x) for x in lm['eyes']],
                                 'mouth': [float(x) for x in lm['mouth']], 'sole_edge': lm['sole']},
            'scale': round(s, 6), 'dx': round(dx, 3), 'dy': round(dy, 3),
            'landmarks_1120x2080': res,
            'landmarks_280x520': {'eyes': [round(x / 4, 2) for x in res['eyes']],
                                  'mouth': [round(x / 4, 2) for x in res['mouth']],
                                  'sole_last_row': res['sole_last_row'] // 4},
            'bbox': [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            'same_alpha_all_tones': bool(same),
            'skin_pixels_source': int(mask.sum()), 'tones': tones}
        print(c, f'scale {s:.4f} shift ({dx:.1f}, {dy:.1f})', res, 'bbox', report['characters'][c]['bbox'],
              'grey left', left_all, left_big)
        rows.append((c, src, capless, normals, {'eyes': res['eyes'], 'mouth': res['mouth']}))
        cb = cap_info['cap_bbox']
        pairs.append((c, src, capless, (cb[0] - 50, cb[1] - 20, cb[2] + 50, cb[3] + 120)))
    (dest / 'report.json').write_text(json.dumps(report, indent=1, ensure_ascii=False) + '\n',
                                      'utf-8', newline='\n')
    sheet(rows, dest / 'compare.png')
    zoom_sheet(pairs, HERE / 'cap_removed_head_zoom.png')
    print('wrote', dest)


if __name__ == '__main__':
    main()
