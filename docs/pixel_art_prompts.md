# 도트 이미지 생성 프롬프트 (최종)

이미지 생성 AI에 그대로 붙여 넣을 수 있는 완성형 프롬프트와, 생성한 이미지를 게임용 도트로 바꾸는 후처리 명령을 한곳에 모은 문서입니다. 후처리는 [tools/pixelize.py](../tools/pixelize.py)를 씁니다.

## 지금 게임에 들어 있는 그림

게임의 도트 그림은 [tools/draw_pixel_assets.py](../tools/draw_pixel_assets.py)가 코드로 직접 찍은 것입니다. 팔레트는 [tools/palette.py](../tools/palette.py) 한 곳에서 관리합니다. 게임은 [lib/ui/pixel_sprites.dart](../lib/ui/pixel_sprites.dart)에서 `assets/images/` 아래 파일을 시작할 때 불러와 확대 보간 없이(nearest-neighbor) 그립니다.

```powershell
python tools/draw_pixel_assets.py                      # 전부 다시 그리기
python tools/draw_pixel_assets.py --only fish,icons    # 일부만 다시 그리기
python tools/draw_pixel_assets.py --preview 미리보기폴더  # 8배 미리보기도 저장
```

**AI 그림으로 바꿀 때:** 아래 프롬프트로 만든 이미지를 `pixelize.py`로 처리해 **같은 경로, 같은 크기**로 덮어쓰면 됩니다. 그 뒤에는 `draw_pixel_assets.py`를 `--only` 없이 실행하지 마세요. 교체한 그림까지 다시 덮어씁니다.

## 작업 순서

1. 아래 프롬프트로 이미지를 생성해 `raw/<종류>/<id>.png`로 저장합니다. **파일 이름은 반드시 게임 id**(`redbean`, `night` 등)로 맞춥니다. 후처리 결과도 같은 이름으로 나옵니다.
2. 종류별 명령을 실행하면 `assets/images/<종류>/<id>.png`와 8배 미리보기 `preview/<id>@8x.png`가 생깁니다. 미리보기는 하위 폴더라 앱에 포함되지 않습니다.
3. 미리보기를 보고 마음에 들지 않으면 다시 생성하거나, Claude에게 픽셀 단위 수정을 요청합니다.
4. 캔버스 크기는 각 절에 적힌 값과 정확히 같아야 합니다. 게임은 이 크기를 기준으로 위치를 잡습니다.

**통일감을 지키는 순서:** 팥 붕어빵(`redbean`)을 가장 먼저 만들어 확정합니다. 나머지 붕어빵, 화로, 아이콘은 그 이미지를 참조 이미지(image-to-image, style reference)로 넣고 생성합니다. 시드 고정을 지원하는 도구라면 같은 시드를 씁니다.

## 프롬프트에 넣은 후처리용 조건

후처리 스크립트가 잘 동작하도록 모든 프롬프트에 다음 조건을 넣었습니다. 프롬프트를 고칠 때도 이 문장은 지우지 마세요.

| 조건 | 이유 |
|---|---|
| 모든 픽셀이 같은 크기인 균일한 격자, 안티에일리어싱·블러·그라데이션 없음 | 스크립트가 격자를 찾아 1칸을 1픽셀로 복원합니다. 격자가 흐트러지면 디테일이 사라집니다. |
| 대략적인 픽셀 해상도 지정(예: 약 60×44) | 결과가 게임 캔버스 안에 축소 없이 들어갑니다. 크면 축소되면서 디테일이 손실됩니다. |
| 단색 배경(흰색, 흰 물체는 마젠타), 그림자·바닥 없음 | 테두리에서 배경을 채워 지우는 방식이라 배경이 균일해야 깨끗하게 지워집니다. |
| 실루엣 전체를 감싸는 닫힌 진한 갈색 외곽선 | 배경 지우기가 물체 안쪽으로 번지지 않게 막아 줍니다. |
| 물체 하나만, 가운데, 여백 넉넉히 | 스크립트는 스프라이트 시트를 자르지 못합니다. 한 장에 하나씩 생성합니다. |
| 빛·광채는 디더링 픽셀 고리로 | 부드러운 광채는 격자를 망가뜨리고 배경 지우기도 어렵게 합니다. |
| 약 16~24색 | 결과를 게임 공통 팔레트 24색에 맞추기 때문에 색이 적을수록 원래 느낌이 유지됩니다. |

## 공통 금지어

네거티브 프롬프트를 지원하는 도구에는 모든 이미지에 아래를 넣습니다.

```
blurry, anti-aliasing, soft edges, smooth gradient, gradient background, drop shadow, ground shadow,
soft glow, bloom, 3D render, realistic, photo, vector art, painterly, mixed pixel sizes,
uneven pixel grid, noise, jpeg artifacts, multiple objects, sprite sheet, text, letters, watermark,
signature, frame, border, harsh pure black outline
```

---

## 1. 붕어빵 — 꾸미기 `fish` 슬롯

캔버스 64×48. 생성 비율 4:3 권장(예: 1024×768).

```powershell
python tools/pixelize.py raw/fish -o assets/images/fish --size 64x48
```

### redbean · 팥 붕어빵 (기준 이미지, 가장 먼저 생성)
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: one bungeoppang (Korean fish-shaped pastry), side view facing right, plump round body, embossed scale pattern drawn with darker pixel dots, a tiny 1-pixel dark eye and a small smile, two pink blush pixels on the cheek, classic golden-brown crust (#E0A040, highlight #F8D27A, shade #A8642F), a little dark red bean paste peeking from the tail edge.
The whole sprite fits within about 60 x 44 pixels.
```

### custard · 슈크림 붕어빵
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same bungeoppang design as the reference, side view facing right, tiny 1-pixel eye, small smile, pink blush pixels, lighter pale-gold crust (#F8D27A, highlight #FFE9A8), creamy yellow custard peeking from the tail edge with one small cream drip.
The whole sprite fits within about 60 x 44 pixels.
```

### cocoa · 코코아 붕어빵
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same bungeoppang design as the reference, side view facing right, tiny cream-colored 1-pixel eye highlight so the face stays visible, small smile, pink blush pixels, chocolate-brown crust (#6B3A1F, highlight #A8642F), glossy dark chocolate filling peeking from the tail edge, a few cream sprinkle pixels on top.
The whole sprite fits within about 60 x 44 pixels.
```

### sweetpotato · 고구마 붕어빵
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same bungeoppang design as the reference, side view facing right, tiny 1-pixel eye, small smile, pink blush pixels, warm amber crust (#E0A040 with #FF9E4A accents), purple and orange sweet potato filling (#B28AD8, #FF9E4A) peeking from the tail edge, a tiny 3-pixel steam puff above.
The whole sprite fits within about 60 x 44 pixels.
```

### matcha · 녹차 붕어빵
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same bungeoppang design as the reference, side view facing right, tiny 1-pixel eye, small smile, pink blush pixels, soft matcha green crust (#B9E3A8, shade #5E9E5A), pale green cream filling peeking from the tail edge, one tiny leaf accent on top.
The whole sprite fits within about 60 x 44 pixels.
```

### strawberry · 딸기 붕어빵
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same bungeoppang design as the reference, side view facing right, tiny 1-pixel eye, small smile, deeper pink blush pixels, light pink crust (#F6B3C2, shade #E07A98), strawberry cream filling peeking from the tail edge, a few red seed pixels arranged like tiny hearts.
The whole sprite fits within about 60 x 44 pixels.
```

탭할 때 찌그러지는 연출은 지금처럼 코드(scale 변형)로 처리하므로 프레임 이미지는 만들지 않습니다.

---

## 2. 배경 — 꾸미기 `background` 슬롯

캔버스 180×400(9:20 세로). 같은 비율로 생성합니다(예: 1024×2276). 도구가 지원하지 않으면 9:16으로 만들되 위아래가 잘려도 괜찮게 구성합니다. 게임은 이 장면을 화면에 꽉 차게 키우되 **아래쪽을 기준으로 맞추고**, 남는 부분은 하늘 쪽을 자릅니다.

장면 좌표(1칸 = 1픽셀)로 아래처럼 겹쳐 그립니다. 배경에는 노점을 그리지 말고 풍경과 바닥만 그립니다.

| 레이어 | 위치(x, y) | 크기 |
|---|---|---|
| 배경 | (0, 0) | 180×400 |
| 카운터 `stall/counter.png` (눈 오는 밤은 `counter_snow.png`) | (0, 304) | 180×96 |
| 화로 | (30, 268) | 80×40 |
| 장식 | 4절 표 참고 | |

```powershell
python tools/pixelize.py raw/bg -o assets/images/bg --mode background --size 180x400
```

### night · 야간 골목
```
Cozy pixel art game background, 16-bit retro style, vertical 9:20. Chunky square pixels on a strict uniform grid of about 180 pixels wide by 400 pixels tall, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients: skies use 3-5 flat color bands with dithered transitions. Limited palette of about 24 colors, soft dark outlines. Heartwarming, nostalgic Korean night mood. The bottom quarter is covered later by a stall counter, so keep only plain ground there and put no stall, cart or table in the picture. No characters, no text, no UI, no frame.
Scene: a narrow old Korean alley at night, navy sky (#1E2140, #2E3466) with twinkling 1-pixel stars, a crescent moon, warm yellow windows (#FFE9A8) glowing in small brick houses, power lines across the sky, a flat stone-paved ground at the bottom.
```

### dusk · 보랏빛 해질녘
```
Cozy pixel art game background, 16-bit retro style, vertical 9:20. Chunky square pixels on a strict uniform grid of about 180 pixels wide by 400 pixels tall, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients: skies use 3-5 flat color bands with dithered transitions. Limited palette of about 24 colors, soft dark outlines. Heartwarming, nostalgic Korean night mood. The bottom quarter is covered later by a stall counter, so keep only plain ground there and put no stall, cart or table in the picture. No characters, no text, no UI, no frame.
Scene: a purple-pink dusk sky in flat bands (#4B3F72, #B28AD8, #F6B3C2, #FF9E4A at the horizon), silhouetted rooftops and a small water tower, the first few stars appearing, warm lit windows, a flat paved ground at the bottom.
```

### forest · 숲길 노점
```
Cozy pixel art game background, 16-bit retro style, vertical 9:20. Chunky square pixels on a strict uniform grid of about 180 pixels wide by 400 pixels tall, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients: skies use 3-5 flat color bands with dithered transitions. Limited palette of about 24 colors, soft dark outlines. Heartwarming, nostalgic Korean night mood. The bottom quarter is covered later by a stall counter, so keep only plain ground there and put no stall, cart or table in the picture. No characters, no text, no UI, no frame.
Scene: a quiet forest path at night, tall layered pine trees in dark greens (#5E9E5A, #2E3466 shadows), fireflies as single yellow pixels, mossy round stones, moonlight drawn as a few pale dithered stripes, a flat dirt path at the bottom.
```

### snow · 눈 오는 밤
```
Cozy pixel art game background, 16-bit retro style, vertical 9:20. Chunky square pixels on a strict uniform grid of about 180 pixels wide by 400 pixels tall, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients: skies use 3-5 flat color bands with dithered transitions. Limited palette of about 24 colors, soft dark outlines. Heartwarming, nostalgic Korean night mood. The bottom quarter is covered later by a stall counter, so keep only plain ground there and put no stall, cart or table in the picture. No characters, no text, no UI, no frame.
Scene: a snowy night alley, snowflakes as single white pixels (#F4F7FF), thick snow piled on rooftops and shop signs, cold blue tones (#AFC3E8, #5B6BA8) contrasted with warm orange window light (#FF9E4A), a flat snowy ground at the bottom.
```

### cherry · 벚꽃 골목
```
Cozy pixel art game background, 16-bit retro style, vertical 9:20. Chunky square pixels on a strict uniform grid of about 180 pixels wide by 400 pixels tall, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients: skies use 3-5 flat color bands with dithered transitions. Limited palette of about 24 colors, soft dark outlines. Heartwarming, nostalgic Korean night mood. The bottom quarter is covered later by a stall counter, so keep only plain ground there and put no stall, cart or table in the picture. No characters, no text, no UI, no frame.
Scene: a spring alley at night lined with cherry blossom trees (#F6B3C2, #E07A98), pink petals drifting as 1-2 pixel dots, small round paper lanterns, a soft violet night sky (#4B3F72), a flat paved ground at the bottom.
```

### seaside · 바닷가 야시장
```
Cozy pixel art game background, 16-bit retro style, vertical 9:20. Chunky square pixels on a strict uniform grid of about 180 pixels wide by 400 pixels tall, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients: skies use 3-5 flat color bands with dithered transitions. Limited palette of about 24 colors, soft dark outlines. Heartwarming, nostalgic Korean night mood. The bottom quarter is covered later by a stall counter, so keep only plain ground there and put no stall, cart or table in the picture. No characters, no text, no UI, no frame.
Scene: a seaside night market, calm sea with the moon reflected as broken horizontal pixel stripes (#AFC3E8 on #2E3466), string lights along a wooden pier as single warm pixels, a small distant lighthouse, a flat wooden boardwalk at the bottom.
```

---

## 3. 화로 — 꾸미기 `stove` 슬롯

캔버스 80×40. 생성 비율 2:1. 카운터 위에 올라가는 붕어빵 굽는 기계입니다(노점 전체가 아님).

```powershell
python tools/pixelize.py raw/stove -o assets/images/stove --size 80x40
```

### iron · 기본 화로 (화로 기준 이미지)
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: a small cute bungeoppang baking machine seen from the front, a wide low box with a mold plate on top holding three small golden bungeoppang, a little fire window with orange embers on the front, two short feet, three thin steam wisps above, simple grey iron body (#7A726C, #C9C2BA).
The whole sprite fits within about 76 x 38 pixels.
```

### copper · 구리 화로
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same baking machine design as the reference, front view, shiny copper body (#FF9E4A, highlight #FFC9A0, shade #A8642F), three small bungeoppang on the mold plate, orange embers, three thin steam wisps.
The whole sprite fits within about 76 x 38 pixels.
```

### castiron · 무쇠 화로
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same baking machine design as the reference, front view, heavy dark cast-iron body (#4A2C2A, #7A726C) with a row of light rivet pixels, three small bungeoppang on the mold plate, orange embers, three thin steam wisps.
The whole sprite fits within about 76 x 38 pixels.
```

### golden · 황금 화로
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: the same baking machine design as the reference, front view, luxurious golden body (#F8D27A, #E0A040, highlight #FFE9A8) with a few 4-point sparkle pixels, three small bungeoppang on the mold plate, orange embers, three thin steam wisps.
The whole sprite fits within about 76 x 38 pixels.
```

---

## 4. 장식 — 꾸미기 `decoration` 슬롯

장식마다 캔버스가 다르고, 게임이 정해진 자리에 놓습니다. 등불과 풍경은 같은 그림을 양쪽에 하나씩 놓으므로 **한 개만** 그립니다.

| id | 캔버스 | 장면 위치(x, y) | 명령 |
|---|---|---|---|
| lantern | 14×24 | (8, 78), (158, 78) | `python tools/pixelize.py raw/deco/lantern.png -o assets/images/deco --size 14x24 --margin 0` |
| windchime | 14×30 | (10, 74), (156, 74) | `python tools/pixelize.py raw/deco/windchime.png -o assets/images/deco --size 14x30 --margin 0` |
| bunting | 180×22 | (0, 100) | `python tools/pixelize.py raw/deco/bunting.png -o assets/images/deco --size 180x22 --margin 0` |
| starlights | 180×24 | (0, 104) | `python tools/pixelize.py raw/deco/starlights.png -o assets/images/deco --size 180x24 --margin 0` |
| snowman | 26×34 | (148, 274) | `python tools/pixelize.py raw/deco/snowman.png -o assets/images/deco --size 26x34 --margin 0` |

깃발과 별 전구는 화면 가로 전체에 걸치는 아주 납작한 그림이라, 8:1 정도로 생성하거나 넓게 생성한 뒤 잘라 씁니다.

### lantern · 종이 등불
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: one round Korean paper lantern hanging from a short string, warm orange paper (#FF9E4A, #FFE9A8 bright center), thin red rib lines, dark red caps at top and bottom, a small tassel, glow drawn only as dithered pixels inside the outline.
The whole sprite fits within about 14 x 24 pixels.
```

### bunting · 작은 축제 깃발
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: one long, gently sagging string of twelve tiny triangle festival flags spanning the full width, in pastel pink, butter yellow, mint and sky blue (#F6B3C2, #F8D27A, #B9E3A8, #9AD3E8), each flag outlined.
The whole sprite fits within about 180 x 22 pixels.
```

### starlights · 별 전구
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: one long, gently sagging garland wire spanning the full width with nine small star-shaped bulbs, alternating butter yellow and pale cream (#F8D27A, #FFE9A8), each star outlined, no glow outside the outline.
The whole sprite fits within about 180 x 24 pixels.
```

### windchime · 풍경
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: a small traditional Korean temple wind chime (punggyeong), a little bronze bell (#A8642F, #E0A040) with a tiny metal fish hanging below it like a bungeoppang, a short string on top.
The whole sprite fits within about 14 x 30 pixels.
```

### snowman · 눈사람 (흰 물체라 마젠타 배경)
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure magenta background (#FF00FF), no shadow, no ground, no frame, no text.
Subject: a tiny chubby two-ball snowman (#F4F7FF, shade #AFC3E8), dot eyes and a small smile, pink blush pixels, a knitted red scarf (#D9573B), a twig arm holding a tiny bungeoppang.
The whole sprite fits within about 26 x 34 pixels.
```

---

## 5. 메뉴 · 축하 아이콘

캔버스 24×24. **한 장에 아이콘 하나씩** 생성합니다(스크립트는 여러 아이콘이 든 이미지를 자르지 못합니다). 첫 아이콘을 확정한 뒤 나머지는 그 이미지를 참조로 넣습니다.

```powershell
python tools/pixelize.py raw/icons -o assets/images/icons --size 24x24
```

아래 공통 문장 뒤에 표의 `Subject`를 붙여 씁니다.

```
Cute cozy pixel art UI icon, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills only. Only 4-6 colors: cream #FFF4E0, butter yellow #F8D27A, gold #E0A040, toasted brown #A8642F, outline #4A2C2A. Closed 1-pixel dark cocoa-brown outline. Bold, simple, readable at very small size, matching a set of game menu icons. Single icon only, centered, empty margin on all sides. Plain solid flat pure white background, no shadow, no frame, no text.
The whole icon fits within about 20 x 20 pixels.
Subject: <아래 표의 내용>
```

| 파일 이름 | 대체하는 곳 | Subject |
|---|---|---|
| `shop` | 상점 | `a tiny street stall with a striped awning` |
| `skins` | 꾸미기 | `a clothes hanger with a small ribbon bow` |
| `records` | 내 기록 | `a small notebook showing a rising bar chart` |
| `share` | 공유 | `a paper airplane` |
| `daily` | 일일 미션 | `a rolled checklist scroll with two check marks` |
| `achievements` | 업적·도감 | `a round medal with a tiny fish emblem on a ribbon` |
| `settings` | 설정 | `a chubby round gear` |
| `leaderboard` | 랭킹 | `a three-step podium with a small crown on top` |
| `star` | 레벨업·기타 축하 배너 | `a plump rounded five-point star with a cute dot-eye face and pink blush pixels` |
| `butter` | 아이템 사용 축하 배너 | `a golden butter cube in isometric view with a 2-pixel shine and two 4-point sparkles` |

---

## 6. 앱 아이콘

배경까지 포함된 정사각형 그림이라 배경 모드로 64×64를 만듭니다. 두 번째 명령이 이 파일로 Android 런처 아이콘(48~192px)과 스토어용 `app_icon_512.png`를 다시 만듭니다.

```powershell
python tools/pixelize.py raw/app/app_icon.png -o assets/images/app --mode background --size 64x64
python tools/draw_pixel_assets.py --only launcher
```
```
Cute cozy pixel art mobile app icon, 16-bit retro style. Chunky square pixels on a strict uniform grid of about 64 x 64 pixels, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no smooth gradients. Limited warm palette of about 16 colors, 1-pixel dark cocoa outline (#4A2C2A) on the main subject. Fills the whole square edge to edge.
Subject: a smiling golden bungeoppang (#F8D27A, #E0A040) wearing a tiny knitted red winter hat (#D9573B), pink blush pixels, a small 3-pixel steam swirl above, centered on a flat navy night background (#1E2140) with a few single-pixel stars. No text.
```

---

## 이미지로 만들지 않는 것

- **탭 부스러기, 축하 색종이:** 8×8 이하의 아주 작은 조각은 AI가 격자를 지키지 못하고, 지금 코드([tap_effects.dart](../lib/ui/tap_effects.dart), [celebration.dart](../lib/ui/celebration.dart))가 개수 제한과 재사용까지 처리합니다. 코드로 유지하되 색은 공통 팔레트로 맞추고, 원 대신 격자에 맞춘 네모로 그려 도트 느낌을 냅니다.
- **붕어빵 탭 찌그러짐:** 코드 연출(크기 변형)을 유지하고 그 안의 스프라이트만 바뀝니다.
- **눈송이, 벚꽃잎:** 배경 그림 안에 멈춘 픽셀로 들어 있습니다.

## 부록: 게임에 아직 자리가 없는 그림

아래 그림은 지금 게임 화면에 들어갈 곳이 없어 만들지 않았습니다. 해당 화면을 만들 때 쓰도록 프롬프트만 남겨 둡니다.

### 황금 붕어빵 (큰 버전)
캔버스 128×96. 파일은 `raw/hero/golden.png`.

```powershell
python tools/pixelize.py raw/hero -o assets/images/hero --size 128x96
```
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions, heartwarming Korean winter street-food mood. Single object only, centered, generous empty margin on all sides. Plain solid flat pure white background, no shadow, no ground, no frame, no text.
Subject: a large hero golden bungeoppang, the same design as the reference but bigger and more detailed, side view facing right, shining gold crust (#F8D27A, #E0A040, highlight #FFE9A8), happy closed-eye smile (^ ^), pink blush cheeks, a few 4-point sparkle pixels touching the outline, iconic and huggable.
The whole sprite fits within about 124 x 92 pixels.
```

### 아이템·재화 아이콘

캔버스 32×32. 생성 비율 1:1.

```powershell
python tools/pixelize.py raw/items -o assets/images/items --size 32x32
```

#### fairy · 요정 (자동 생산 강화)
```
Cute cozy pixel art game item icon, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills only. Limited palette of about 12 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Bold, simple shape readable at small size. Single object only, centered, empty margin on all sides. Plain solid flat pure white background, no shadow, no frame, no text.
Subject: a tiny cute fairy hugging a mini bungeoppang, pale blue wings (#9AD3E8) drawn as solid shapes, two sparkle pixels beside her.
The whole icon fits within about 28 x 28 pixels.
```

#### coin · 코인
```
Cute cozy pixel art game item icon, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills only. Limited palette of about 12 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Bold, simple shape readable at small size. Single object only, centered, empty margin on all sides. Plain solid flat pure white background, no shadow, no frame, no text.
Subject: a round golden coin seen from the front (#F8D27A, rim #E0A040), stamped with a tiny fish silhouette in the center, one diagonal shine.
The whole icon fits within about 28 x 28 pixels.
```

#### bun · 붕어빵 재화
```
Cute cozy pixel art game item icon, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills only. Limited palette of about 12 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Bold, simple shape readable at small size. Single object only, centered, empty margin on all sides. Plain solid flat pure white background, no shadow, no frame, no text.
Subject: a very simplified tiny bungeoppang facing right, golden crust (#E0A040), one eye pixel, three scale pixels.
The whole icon fits within about 28 x 20 pixels.
```

### panel · 패널·버튼 프레임 (9-slice)
캔버스 48×48. 이건 가장자리를 정확히 써야 해서 `--margin 0`을 줍니다.

```powershell
python tools/pixelize.py raw/ui/panel.png -o assets/images/ui --size 48x48 --margin 0
```
```
Cute cozy pixel art UI panel frame, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills only. A cozy wooden signboard frame (#A8642F, #6B3A1F) with a flat cream inner area (#FFF4E0), rounded pixel corners, 2-pixel dark cocoa outline (#4A2C2A), identical thickness on all four sides so it can be 9-slice scaled, nothing inside the cream area. Fills the image edge to edge. Plain solid flat pure white background outside the rounded corners, no shadow, no text.
About 48 x 48 pixels.
```

### levelup_banner · 레벨업 배너
캔버스 160×48. 생성 비율 16:9 이상 가로형.

```powershell
python tools/pixelize.py raw/ui/levelup_banner.png -o assets/images/ui --size 160x48
```
```
Cute cozy pixel art game sprite, 16-bit retro style. Chunky square pixels on a strict uniform grid, every pixel exactly the same size, hard edges, no anti-aliasing, no blur, no gradients, flat color fills with simple dithering only. Limited warm palette of about 16 colors. Closed 1-pixel dark cocoa-brown outline (#4A2C2A) around the entire silhouette. Kawaii chibi proportions. Single object only, centered, empty margin on all sides. Plain solid flat pure white background, no shadow, no frame, no text, no letters.
Subject: a wide cream ribbon banner (#FFF4E0) with gold trim (#E0A040) and folded ribbon tails, a tiny cheering bungeoppang mascot at each end, the long center area left completely empty for text added later in the game.
The whole sprite fits within about 156 x 44 pixels.
```

---

## 결과가 이상할 때

| 증상 | 해결 |
|---|---|
| `grid pitch`가 이상하게 크거나 작게 나옴, 디테일이 뭉개짐 | 프롬프트의 픽셀 해상도를 더 작게(픽셀을 더 크게) 해서 다시 생성합니다. 그래도 안 되면 `--no-grid`(디테일 손실 가능). |
| `shrinking (detail may be lost)` 경고 | 그림이 캔버스보다 큼. 프롬프트의 `fits within` 숫자를 줄여 다시 생성합니다. |
| 배경이 덜 지워짐 | `--tolerance 60`. 물체 안쪽까지 지워지면 `--tolerance 25`로 낮추고, 외곽선이 끊긴 이미지는 다시 생성합니다. |
| 색이 원본과 많이 달라짐 | `--colors 16`으로 공통 팔레트 대신 그림 자체의 색을 씁니다(다른 에셋과 색감이 어긋날 수 있음). |
| 흰 물체가 배경과 함께 지워짐 | 프롬프트의 배경을 마젠타(`#FF00FF`)로 바꿔 다시 생성합니다. |
