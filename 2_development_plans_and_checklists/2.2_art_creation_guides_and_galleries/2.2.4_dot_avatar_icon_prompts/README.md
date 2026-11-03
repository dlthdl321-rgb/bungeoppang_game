# 아바타·아이콘 도트 변환 프롬프트 (단계별)

대상: 아바타, 아이콘, 스킬 아이콘, 앱 아이콘 (+ 선택: 작은 소품)
제외: 홈 화면·배경 (`bg/`, `bg_clean/`, `mold/`, `stove/`, `cook/`, `deco/`, `event/`, `ui/wardrobe_bg.png`)

## 0. 규칙 (모든 단계 공통)

- **도트 배율 = 4.** 게임 안의 원본 크기에서 도트 1칸이 4×4 px이 되게 맞춰요.
- **저장 크기는 지금 파일 크기 그대로** 둬요. 도트 원본(작은 크기)을 ×4 Nearest로 키워서 저장하면 `avatar_atlas.dart` 좌표와 위젯 크기를 고칠 필요가 없어요.
- **색은 `tools/palette.py`만 써요.** `pixelize.py`가 기본으로 이 팔레트에 맞춰 줘요.
- **외곽선은 검정이 아니라** 그 물체 색 계열에서 가장 어두운 단계를 써요 (예: 빵은 `#8C5137`, 초코는 `#4A2820`).
- **기준 이미지 2장을 매번 같이 첨부해요.** 1단계에서 확정한 아바타 1장과 아이콘 1장이에요.

| 그룹 | 파일 | 지금 크기 | 도트 원본 크기 (÷4) |
|---|---|---|---|
| 아바타 몸 | `avatar/{boy,girl}/base.png` | 280×520 캔버스 | 70×130 |
| 아바타 아이템 | `avatar/{boy,girl}/hat_* top_* …` | 280×520 캔버스 | 70×130 |
| UI 아이콘 | `icons/*.png` (40개) | 72×72 | 18×18 |
| 스킬 아이콘 | `skills/tap_1~16`, `auto_1~16` | 96×96 | 24×24 |
| 앱 아이콘 | `app/app_icon.png`, `app_icon_512.png` | 96, 512 | 32×32 (예외: ×3, ×16) |
| 선택 | `topping/*` 96×72, `ui/title_fish` 48×36, `fish/redbean@*` 96×72 | | 24×18, 12×9, 24×18 |

---

## 공통 스타일 문구 (STYLE LOCK)

모든 프롬프트 맨 앞에 그대로 붙여요. 이 부분은 절대 수정하지 않아요.

```
STYLE LOCK:
Cozy Korean street-food pixel art, warm golden-hour mood, cute storybook feel.
TRUE pixel art on a strict square grid. The sprite is exactly {W}x{H} art pixels,
shown enlarged so every art pixel is an identical solid square block.
No anti-aliasing, no gradients, no blur, no soft glow, no painterly texture, no noise,
no half-pixels, no mixed pixel sizes.
Palette only: cream #FFF6E3, honey #FFE6A8 #F8C871, caramel #E59F55, bake #BE7442,
crust line #8C5137, chocolate #C98B6B #9C5F45 #6E3D2E #4A2820,
pink #FFD3DE #F8A9BE #E27E9C, blush #FF9DB6, mint #C8F0D4 #98DDB2 #63BA8C,
lilac #DCCBF8 #BBA6EC #9783D8, sky #9FD6EC #68B0D6, white #FFFFFF.
Outline: 1 art pixel, using the darkest shade of each object's own color (never pure black).
Light from upper-left; shading in 2-3 flat color steps; 1-pixel cream highlight on top edges.
Match the attached reference images exactly in pixel size, outline weight and shading.
Background: flat solid #FF00FF (magenta) only, no shadow on the ground.
```

공통 NEGATIVE (도구가 지원하면 넣어요):

```
blurry, anti-aliased, smooth shading, gradient, realistic, 3D, photo, painting,
watercolor, vector, mixed pixel sizes, jpeg artifacts, bloom, text, watermark, frame
```

---

## 1단계 — 기준 이미지 확정 (가장 중요)

전체 에셋의 기준이 되는 2장을 먼저 만들고 확정해요. 이후 모든 단계에서 이 2장을 첨부해요.

**1-A. 기준 아바타 (여자 base)**: 지금 `avatar/girl/base.png`를 첨부해요.

```
{STYLE LOCK, W=70 H=130}
Redraw the attached character as clean pixel art, same design:
young girl, long brown hair, big brown eyes, rosy cheeks, gentle smile,
plain white T-shirt, beige shorts, brown shoes.
Front view, standing straight, arms relaxed at the sides, feet together,
full body centered, head top at about row 6, feet bottom at about row 126.
Simple 2-pixel-tall eyes with a 1-pixel white highlight, 1-pixel smile, 2x1 blush.
```

**1-B. 기준 아이콘 (상점 아이콘)**: 지금 `icons/shop.png`를 첨부해요.

```
{STYLE LOCK, W=18 H=18}
Redraw the attached icon as a tiny 18x18 pixel-art icon:
red shopping bag with a golden bungeoppang (fish-shaped pastry) emblem, brown handles.
Centered, 1-pixel empty margin on every side, bold readable silhouette at small size.
```

→ `pixelize.py`로 정리한 뒤(4단계 참고) 확대본을 보고 확정해요. 확정한 2장을 `reference_avatar.png`, `reference_icon.png`로 이 폴더에 저장해요.

---

## 2단계 — 아바타

### 2-A. 남자 base (첨부: 기준 아바타 + 지금 `avatar/boy/base.png`)

```
{STYLE LOCK, W=70 H=130}
Same art style, proportions and pose as the reference girl (first image).
Redraw the second image's boy as pixel art: short brown hair, brown eyes, rosy cheeks,
white T-shirt, beige shorts, brown shoes.
Exactly the same canvas, same head size, same foot line (bottom at row 126),
same arm position as the reference girl.
```

### 2-B. 착용 아이템 (아이템마다 1장씩)

첨부: 기준 아바타(또는 남자 base) + 지금 아이템 이미지. 아이템 레이어는 **캐릭터가 아이템을 입은 전신 모습**으로 만들어요. 그래야 나중에 몸 위에 겹쳤을 때 위치가 맞아요.

```
{STYLE LOCK, W=70 H=130}
The reference character (first image) in the exact same pose, position and canvas,
now wearing: {ITEM}.
Do not change the face, body, hair outside the item, or the pose.
Draw the item in the same pixel style; it must fit the body exactly.
```

`{ITEM}`에 넣을 문구:

| 파일 | {ITEM} |
|---|---|
| hat_ballcap | a cream baseball cap with a small fish logo |
| hat_bandana | a pink kitchen bandana tied over the hair |
| hat_beanie | a knitted caramel beanie with a pom-pom |
| hat_newsboy | a brown newsboy cap |
| hat_chefhat (girl) | a tall white chef hat |
| hat_earmuffs (girl) | fluffy pink earmuffs |
| hat_santa (girl) | a red Santa hat with white fur trim |
| top_cardigan | a soft caramel cardigan over the T-shirt |
| top_creamlong | a long-sleeve cream shirt |
| top_creamsweater | a chunky cream knit sweater |
| top_pinksweater | a pastel pink knit sweater |
| top_sagesweater | a sage-mint knit sweater |
| outfit_padding | a puffy padded winter jacket |
| bottom_skirt (girl) | a short beige pleated skirt instead of shorts |
| shoes_boots | brown leather ankle boots |
| shoes_furboots | boots with cream fur cuffs |
| shoes_sneakers | white sneakers with pink laces |
| accessory_scarf | a knitted red-and-cream scarf |
| accessory_mittens | pink knitted mittens on both hands |
| accessory_glasses | round thin brown glasses |
| accessory_crossbag | a small brown crossbody bag |
| accessory_fishpin | a tiny golden fish hairpin |
| accessory_ribbon (girl) | a pink hair ribbon |
| tool_fishhold | holding one bungeoppang in the right hand |
| tool_paperbag | holding a small paper bag of bungeoppang |
| tool_tongs | holding metal cooking tongs |

> 색이나 디자인은 **지금 아이템 이미지를 첨부해서 그대로 따라 그리게** 하는 게 가장 정확해요. 표의 문구는 보조용이에요.

### 2-C. 눈·입 표정 (프롬프트 불필요)

`parts/*` 파일은 `tools/avatar_layers.py face`가 base 그림을 보고 자동으로 만들어요. base를 바꾼 뒤 다시 실행하면 돼요. 다만 이 도구는 소수점 좌표(예: 53.5)로 그려서 결과가 도트 격자에 안 맞을 수 있어요. 확대본에서 꼭 확인하세요.

---

## 3단계 — 아이콘

### 3-A. UI 아이콘 40개 (각각 지금 아이콘 첨부 + 기준 아이콘 첨부)

```
{STYLE LOCK, W=18 H=18}
Same style as the reference icon (first image). Redraw the second image as an
18x18 pixel-art icon: {SUBJECT}.
Centered, 1-pixel empty margin, one clear silhouette, max 6 colors, readable at 18x18.
```

| 파일 | {SUBJECT} |
|---|---|
| achievements | a golden trophy cup |
| back | a left-pointing chunky arrow |
| bgm | a music note |
| bun | a single golden bungeoppang |
| butter | a pat of butter on a small dish |
| buy10 | a stack of bungeoppang with a small "x10" badge shape |
| check | a mint check mark in a circle |
| coin | a gold coin with a fish emblem |
| combo | a flame with a spark |
| daily | a calendar page with one marked day |
| invite | an envelope with a heart |
| leaderboard | a 3-step podium |
| levelup | an upward arrow with a star |
| lock | a padlock |
| menu | three stacked horizontal bars in a rounded square |
| mission | a clipboard with check marks |
| prestige | a crown |
| records | an open notebook |
| save | a floppy disk |
| settings | a gear |
| sfx | a speaker with one sound wave |
| share | three connected dots |
| shop | a red shopping bag with a fish emblem |
| skill | a lightning bolt |
| skins | a paint palette |
| star | a gold star |
| tab_acc | a hair ribbon |
| tab_auto | a gear with a circular arrow |
| tab_fish | a bungeoppang outline |
| tab_gear | a cooking spatula |
| tab_hair | a comb |
| tab_outfit | a T-shirt |
| tab_stall | a small street stall with an awning |
| tab_tap | a pointing finger tapping |
| theme | a small landscape picture frame |
| title | a name ribbon banner |
| vibration | a phone with shake lines |
| volume | a speaker with two sound waves |
| warning | a yellow triangle with "!" |
| weekly | a calendar with a 7-day row |

> 같은 계열(bgm·sfx·volume, daily·weekly, tab_*)은 **한 장에 나란히** 생성하면 모양이 더 잘 통일돼요. 예: "Draw these 3 icons side by side on one sheet, each in its own 18x18 cell with 2-pixel gaps: …". 시트는 나중에 셀 단위로 잘라요.

### 3-B. 스킬 아이콘 32개 (tap 16단계 + auto 16단계)

등급이 올라갈수록 화려해지게 **티어별 테두리 규칙**을 고정해요.

| 단계 | 테두리 |
|---|---|
| 1–4 | 크림색 원형 배지, 장식 없음 |
| 5–8 | 민트 배지 + 1px 하이라이트 |
| 9–12 | 라일락 배지 + 꼭대기에 작은 별 1개 |
| 13–16 | 골드 배지 + 반짝이 픽셀 2개 |

```
{STYLE LOCK, W=24 H=24}
Same style as the reference icon. Skill icon, tier {N} of 16, {tap|auto} line.
Round badge frame: {티어 테두리 규칙}.
Inside the badge: {SUBJECT}  (attach the current skills/{tap|auto}_{N}.png and keep its idea).
Centered, 1-pixel empty margin.
```

- tap 계열의 {SUBJECT}: 손가락·뒤집개·반죽 붓기처럼 "직접 굽는" 동작을 그려요.
- auto 계열의 {SUBJECT}: 톱니·타이머·자동 틀처럼 "자동 생산"을 그려요.
- 4개씩 한 장(4단계 1세트)으로 생성하면 단계 차이가 자연스러워져요.

### 3-C. 앱 아이콘

```
{STYLE LOCK, W=32 H=32}
App icon: one big golden bungeoppang tilted slightly, on a warm cream rounded-square
background with a 1-pixel caramel border, small sparkle top-right.
Fill the canvas edge to edge (background is part of the icon, not magenta).
```

→ 32×32 원본을 ×3 → `app_icon.png`(96), ×16 → `app_icon_512.png`(512)로 저장해요.

---

## 4단계 — 정리 (생성 → 진짜 도트)

AI 결과물은 도트 크기가 고르지 않아요. 아래처럼 `pixelize.py`로 진짜 도트 격자로 다시 만들어요. 프로젝트의 `1_app_development` 폴더에서 실행해요.

```
# 원본(작은 크기) 만들기 — 생성 결과물을 raw/ 아래 그룹별로 넣어 두고 실행
python tools/pixelize.py raw/icons   -o build/dot/icons   --size 18x18
python tools/pixelize.py raw/skills  -o build/dot/skills  --size 24x24
python tools/pixelize.py raw/avatar_girl -o build/dot/avatar_girl --size 70x130 --margin 0
python tools/pixelize.py raw/avatar_boy  -o build/dot/avatar_boy  --size 70x130 --margin 0
```

그다음 ×4 Nearest로 키워서 `assets/images/` 아래 같은 파일명으로 덮어써요.

```
python -c "import sys,glob,os;from PIL import Image;s=int(sys.argv[3]);[Image.open(f).resize((Image.open(f).width*s,Image.open(f).height*s),Image.NEAREST).save(os.path.join(sys.argv[2],os.path.basename(f))) for f in glob.glob(sys.argv[1]+'/*.png')]" build/dot/icons assets/images/icons 4
```

아바타는 덮어쓴 뒤 `python tools/avatar_layers.py`를 다시 실행해요 (face → worn → trim 순서로 좌표 갱신).

## 5단계 — 검수 체크리스트

- [ ] `preview/` 확대본에서 모든 도트가 같은 크기의 네모인가 (번진 픽셀 없음)
- [ ] 기준 이미지 2장과 나란히 놓았을 때 외곽선 두께·명암 단계가 같은가
- [ ] 아이콘 40개를 한 화면에 모았을 때 크기·여백·색 밀도가 고른가
- [ ] 아바타 아이템이 base 위에서 어긋나지 않는가 (`--preview`로 시트 확인)
- [ ] 게임 화면에서 `FilterQuality.none`으로 그려져 흐리지 않은가
- [ ] 바꾸기 전 파일은 `4_image_generation_results_and_backups`에 백업했는가
