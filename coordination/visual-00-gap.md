# 비주얼 조정 0단계 — 시안 대비 현재 화면 차이 조사

작성일: 2026-10-24(같은 날 보완). 범위: 조사만 했다. 앱 코드(`lib/`)·에셋·설정·테스트는 수정하지 않았다.
기준 프롬프트: [2.2.5 완성 시안 기준 비주얼 조정 프롬프트](../2_development_plans_and_checklists/2.2_art_creation_guides_and_galleries/2.2.5_mockup_visual_update_prompts/README.md) 1단계.
부록: [테스트 탐색자 전체 목록](visual-00-test-finders.md).

## 0. 조사 기준과 먼저 알아야 할 사실

### 조사한 자료

- **시안** `3_original_images_and_visual_references/3.5_completed_game_mockups/`의 11장을 모두 열어 보았다.
  - 메인UI_화면(941×1672)
  - 중앙클리커화면: HUD 없는 장면. 2×3 판과 서 있는 사장님.
  - 조리컷가스화면: 판 아래 스테인리스 가스레인지와 노브. HUD 없음.
  - 미분류생성이미지01: 액자형 조리 컷과 손잡이 달린 2×3 판.
  - 서브UI5종: 메뉴·설정·스킬·꾸미기·상점.
  - feature_graphic: 스토어 이미지. 화면 시안이 아니다.
  - 개별 컷 5장(메뉴·설정·스킬·꾸미기·상점): 서브UI5종의 각 칸을 잘라 낸 것과 내용이 같다.
- **현재 화면**
  - 홈: `4_image_generation_results_and_backups/4.9_work_records/4.9.1_inspection_sheets/home_stage_20261022/` 13장(780×1688. 영업 준비·영업 중·주문 도착·제작 단계).
  - 창 16장: 이번에 새로 캡처했다. `4.9.1_inspection_sheets/visual_00_current_20261024/` `00_home`~`15_share` 390×844, 모아보기 `90`·`91`.
    - 캡처 도구: `coordination/visual-00-tools/capture_test.dart`
    - 실제 앱 경로 `GameApp(workshop:)`를 테스트 환경에서 띄우고, 실제 키를 눌러 창을 연 뒤 화면 전체 레이어를 저장했다.
    - Jua와 Material Icons 글꼴을 불러와 한글이 보이게 했다.
    - 실기기 화면이 아니다. 테스트 환경에서는 `Image.asset`이 비동기로 늦게 로드되어 빈칸으로 찍히는 곳이 있다(가게 관리 창 위쪽 배경).
  - 골든 3장 + 시안 비교: `visual_00_current_20261024/92_goldens_vs_mockup.png`
- **코드:** 아래 파일을 끝까지 읽었다.
  - `night_home.dart`, `workshop_mold_stage.dart`, `workshop_windows.dart`, `workshop_page.dart`, `cook_cut.dart`, `cozy_style.dart`
  - `night_stall_painter.dart`의 그리기 부분(`NightStallPainter.paint`, `StallFramePainter`, `GriddlePainter`)
  - `public_menus.dart`의 `MenuPanel`·`WardrobePanel` 본문, `shop_panel.dart`의 항목 카드, `customer_story_panel.dart`
  - `game_app.dart`의 `SoundSettings`와 라우팅·오버레이 부분
- **검색만 한 코드:** `ranking_panel.dart`, `friends_panel.dart`, `progress_panels.dart`, `invite_panel.dart`(위젯 종류만), `boost_effects.dart`(`griddleSpriteRect`·`GoldenGriddleLayer` 위치만)

### 작업 트리 상태 (중요)

- 기준 커밋은 `50b6fa8`이다.
- 아직 커밋하지 않은 홈 무대 변경이 있다(공백·줄바꿈 무시 기준 약 250줄).
  - 대상 파일: `night_home.dart`, `night_stall_painter.dart`, `pixel_sprites.dart`, `workshop_mold_stage.dart`, `workshop_page.dart`
  - 추적하지 않는 에셋: `assets/images/mold/` 7장, `assets/images/bg_clean/clear.png`
  - 추적하지 않는 도구: `tools/make_home_stage_art.py`
- 이 변경으로 **영업 중 대기 상태의 "떠 있는 붕어빵 + 반짝이"와 알약(`큰 틀 연습 시작`)은 이미 구현되어 있다**(`FloatingFishPainter`, `_pill`). 영업 준비 중이거나 주문이 막 도착하면 쇠틀 안의 붕어빵을 보여 준다.
- 아래 조사·캡처·테스트 기준선은 모두 **이 미커밋 상태의 작업 트리** 기준이다.

### 실제 출시 경로는 Workshop 홈이다

- `main.dart`는 항상 `GameApp(workshop: …)`으로 시작한다.
- 그래서 사용자가 보는 화면은 `WorkshopPage` → `NightHome(headerData, centerBuilder, griddleContent, vendor)`이다.
- 구형 `GameHome`(`BakeTarget`, `SkillShop`, `game_app.dart` `_settings`)은 workshop이 없을 때만, 즉 사실상 테스트에서만 쓰인다.
- 이 사실에서 생기는 결과:
  1. **`fish-button`은 Workshop 홈에 없다.** `step02_home_test`는 Workshop 홈에 `BakeTarget`이 없어야 한다고 검사한다(`findsNothing`). 중앙 입력 Key는 `workshop-mold-action`이다.
  2. **홈 골든 3장(`home_golden_test`)은 구형 홈을 찍는다.** 출시 화면을 보호하는 골든이 없다. 골든은 테스트 글꼴로 그려서 한글이 □이고, 배경도 쇠틀이 그려진 구형 배경이다(92번 비교 이미지).
  3. 스킬 창은 `WorkshopSkillShop`(workshop_windows.dart), 설정 창은 `_audioSettings`(workshop_page.dart) + `SoundSettings`(game_app.dart)이다.
  4. `_open()`에 `invite` 경로가 없어서, 초대 창(`InvitePanel`)은 Workshop에서 열리지 않는다. 알 수 없는 경로는 `default`로 가게 관리 창이 열린다.

### 글꼴 문제: Jua에 없는 기호

- `assets/fonts/Jua-Regular.ttf`의 cmap을 확인했다.
  - 없는 기호: `·`(U+00B7), `●`, `○`, `…`, `→`, `↶`, `×`, `✓`, `—`, `–`, `⏱`, `☝`
  - 있는 기호: `★`, `☆`, `~`, `%`, `+`, `>`
- 화면 글에는 `·`가 142곳 쓰였다.
- 이번 캡처(Jua를 불러온 상태)에서 `·`가 모두 □로 찍혔다. 예: "영업 준비 □ 주문 0", "주문□재고□영업 관리", "0/1000 □ 클릭당 1", "로그인□보상 확인".
- 도감의 익힘 표시 `●/○`도 같은 문제가 있다.
- 실기기에서 시스템 글꼴로 대체되는지는 **미확인**이다. 시안과 무관한 현재 버그로, 비주얼 작업에서 함께 처리해야 한다.

## 1. 시안 요소 ↔ 현재 위젯 차이표

**위험 표기**
- **K** = 테스트가 그 Key·툴팁·문구·타입을 직접 찾는다(부록 기준).
- **D** = 문서(MASTER 10장)에만 있는 Key로, 테스트는 참조하지 않는다.
- **G** = 골든 영향. 현재 골든은 구형 홈이다.
- **L** = 로직 결합. 화면 코드 안에 명령·조건이 섞여 있다.

### 1-0. 홈 비율 측정 (근사치)

- **측정 방법:** 시안(941×1672)과 현재(영업 중, 780×1688 = 390×844의 2배)의 픽셀 좌표를 눈으로 읽었다. 오차는 약 ±2%p이다.
- **비교 기준:** 시안이 현재보다 덜 길쭉해서(폭/높이 0.56 vs 0.46), 가로는 화면 폭 기준, 세로는 화면 높이 기준으로 비교한다.

| 요소 | 시안 | 현재 | 차이 |
| --- | --- | --- | --- |
| HUD 1줄(Lv·잔액·생산율) 높이 | 8.7%H, 위 5.4%H에서 시작 | 10.4%H, 위 4.4%H에서 시작 | 현재가 약간 크다 |
| HUD 2줄(메뉴·설정 버튼) | 없음. 메뉴는 Lv 배지 아래, 설정은 1줄 오른쪽 끝 | 별도 줄 약 5.3%H(원형 버튼 2개 + 상태 문구) | 현재만 있는 줄이다 |
| Lv 배지 폭 | 15%W | 24%W | 현재가 1.6배 넓다(내부 빈 공간이 많다) |
| 잔액 카드 폭 | 36%W | 40%W | 비슷하다 |
| 생산율 알약 폭 | 23%W | 28%W | 현재가 넓다(설정 버튼 칸이 없어서) |
| 중앙 붕어빵 폭 / 세로 중심 | 67%W / 48%H | 66%W / 43%H | 크기는 같다. 현재가 5%H 위에 있다 |
| 알약 폭 / 위치 | 32%W, 붕어빵 바로 아래(62~65%H) | 42%W, 붕어빵에서 떨어진 카운터 위(65~69%H) | 현재 알약이 넓고 붕어빵과 떨어져 있다 |
| 조리 컷 폭 × 높이 | 32%W × 15.3%H(폭:높이 = 1:0.84) | 32%W × 12.4%H(1:0.84) | 비율은 같다. 세로 기준 크기만 작다 |
| 6구 판 폭 | 75%W(왼쪽 뚜껑 열림 + 오른쪽 손잡이 포함 약 100%) | 85%W | 비슷하다 |
| 하단 메뉴 높이 | 6.3%H | 6.8%H | 비슷하다 |

### 1-1. 홈 (메인UI_화면 · 중앙클리커화면 · 조리컷가스화면)

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 줄무늬 차양·기둥·등불 | `StallFramePainter`(night_stall_painter.dart): `stall/awning`, `post`, 꾸미기 `lamp` 그림을 배치 | 시안은 양쪽 기둥에 큰 등불이 HUD 높이에 하나씩 보인다. 현재 등불은 HUD 뒤에 가려 오른쪽 일부만 보인다. 차양 높이 = 그림 높이 × 화면폭/72로, 시안보다 얇다. | G |
| 배경(한옥·N서울타워·골목) | `NightStallPainter` + `bg_clean/clear.png`(미커밋) | 같은 계열 그림이다. 현재는 카운터 나무 상판이 화면 중간(약 55%H)부터 보인다. 시안은 판 바로 뒤(약 73%H)부터만 보여 거리 풍경이 더 넓다. | G. 카운터 선 y=304(MASTER 10장) |
| Lv 배지 + 진행 막대 | `NightHome._levelBadge` | 시안은 숫자가 배지를 꽉 채우고 막대가 노란색이다. 현재는 배지 폭이 넓어 빈 공간이 많고, 막대 바탕이 `Cozy.ink`(검정에 가까움)이다. | K `level-mission-entry`, `level-progress`. Semantics 'Lv.N 레벨 미션 …' |
| 메뉴 버튼 | `CozyRoundButton` `menu-menu`(48 원형) | 시안은 Lv 배지 바로 아래 같은 폭의 나무 사각 버튼이다. | K `menu-menu`(테스트 11개 파일), `menu-badge`, 툴팁 '메뉴' |
| 보유 재화 카드 | `NightHome._balance` | 시안: 큰 붕어빵 아이콘 + "보유 붕어빵" + 쉼표가 있는 큰 숫자. 현재: 아이콘 34, 제목 "붕어빵력", 숫자 26(`compactNumber`), 아래 "누적 N개". 제목 문구는 기획 용어(3-3)라 바꾸지 않는다. | D `balance-value`, `lifetime-value`. Semantics '보유 붕어빵 N개' |
| 초당/클릭당 알약 | `NightHome._rate` | 시안은 시계·손가락 픽셀 아이콘이다. 현재는 Material 선 아이콘(`timer_outlined`, `touch_app_outlined`)이다. | K `auto-rate`, `tap-rate` |
| 설정 톱니 | `CozyRoundButton` 툴팁 '설정' | 시안은 HUD 1줄 오른쪽 끝의 사각 나무 버튼이다. | K 툴팁 '설정' |
| (시안 없음) 상태 문구 | `_note('workshop-status')` | 배경 위 흰 그림자 글자라 잘 안 읽히고, `·`가 □로 나온다. | 테스트 참조 없음 |
| 중앙 큰 붕어빵 + 반짝이 | `WorkshopMoldStage` + `FloatingFishPainter`(미커밋) | 크기는 시안과 같다(1-0). 반짝이가 시안보다 작고 적다(6개, 크기 10~16%). 영업 준비·주문 도착 직후에는 쇠틀(`idle-mold`)로 바뀐다. | K `active-empty-mold`. 미참조 `floating-fish`, `idle-mold`, `workshop-center-stage`. L 표시 조건 |
| "터치해서 굽기" 알약 | `_pill('큰 틀 연습 시작')` + `workshop-mold-action` | 모양은 같다. 문구가 다르다(실제 동작이 연습 시작이다). 위치·폭 차이는 1-0 참고. | K `workshop-mold-action`. L `startPractice` |
| (시안 없음) 맛 선택·`+N 붕어빵력` | `WorkshopMoldStage` 위쪽 `DropdownButton` + `TextButton(c.tap)` | 흰 그림자 글자만 있고, 드롭다운 밑줄이 보인다. | L `selectFlavor`, `tap` |
| (시안 없음) 제작 중 안내·버튼 | `_caption`, `sensorControl`, `FilledButton('보관')`, `TextButton('버리기'/'제작 취소')` | 흰 그림자 글자, 기본 `Switch`, Material 버튼이다. | K `workshop-phase-time`, 문구 '보관', 타입 `BatterHoldButton`·`PipingBagControl`. L 제작 명령 |
| 2×3 굽는 판 | `GriddlePainter`(꾸미기 `stove` 그림 한 장을 판 영역에 맞춰 그림) + `WorkshopGriddleLayer` | 판 그림은 시안과 비슷하다. 칸마다 "1 시작" 글자 상자가 붕어빵을 덮는다. 칸 상자 색은 `Colors.black26`, `Colors.brown`, `Colors.black87`로 하드코딩되어 있다. | K `griddle`, `workshop-cell-N`. D `golden-chance-N`(구형 홈). L `startCell`/`harvestCell(expectedCycle)` |
| 가스 불꽃·스테인리스 버너·노브 | `stove` 그림 안에 판과 파란 불꽃 줄이 함께 들어 있다 | 시안 `조리컷가스화면`의 스테인리스 몸체·노브·호스는 없다. 그리려면 새 그림이나 추가 레이어가 필요하다. 판 높이는 폭×40/88로 고정이고, 판 바닥이 하단 메뉴 10px 위라 아래 공간이 없다. | G. MASTER 10장 판 규칙 |
| 조리 컷 액자 | `CookCut`: 나무색 3px 테두리 + `wardrobe_bg` 가게 실내 + 사장님 | 비율은 시안과 같다(1-0). 시안은 두꺼운 크림 액자에 바깥 갈색선이고, 판을 집게로 집는 사장님을 가까이 잡는다. 현재는 얇은 테두리에 가게 실내 전체가 보여 사장님이 작다. | K `cook-cut`(구형 테스트) |
| 하단 메뉴 4개 | `NightHome._nav`, `_NavButton` | 구성·높이는 같다. 시안 아이콘은 약 40px이고 꾸미기 아이콘이 빨간 앞치마이다. 현재 스킬 번개 아이콘이 작고 흐리며, 꾸미기는 사람 모양이다. | K `menu-menubar`, `menu-skills`, `menu-skins`, `menu-shop`, `menubar-badge` |

### 1-2. 시트 공통 틀 (서브UI5종 공통)

캡처 `01`~`15`로 확인했다.

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 위쪽 잔액 알약 | `showWorkshopWindow`의 `CozyPanel` + `Wrap` | 시안은 가운데 작은 알약(아이콘 + "12,850개")이다. 현재는 아이콘 없이 "붕어빵력 0 황금붕어빵력 0"을 글자로 보여 준다. 두 재화 표시는 유지한다. 알약이 홈 HUD의 Lv 배지·생산율 알약과 겹쳐 보인다. | L 두 재화. 글자 1.3배 제한 |
| 큰 크림 패널 + 아이콘 제목 | `CozyFrame` + 제목 `Row` | 구조는 같다. 시안 제목 아이콘은 창마다 다르다(메뉴=붕어빵, 설정=톱니, 스킬=번개, 꾸미기·상점=쇼핑백). 현재는 설정만 톱니이고 나머지는 모두 `title_fish`이다. | K `workshop-window-title`(창 제목 문자열을 정확히 비교) |
| 빨간 X | `CozyCloseButton` | 시안과 같다. | K 툴팁 '닫기'(테스트 9개 파일) |
| ↶ 돌아가기 | `CozyBackButton` | 모양은 같다. 단, 시트 높이가 화면의 92%라 버튼이 홈의 하단 메뉴 위에 겹쳐 놓인다. 버튼 양옆으로 하단 메뉴의 '메뉴'·'상점'이 비쳐 보인다. | K 타입 `CozyBackButton`, 360×800에서 아래 끝 ≤ 776 |
| 시트 뒤 노점 배경 | `showModalBottomSheet` 기본 막 | 시안은 시트 양옆과 위로 노점이 선명하다. 현재는 막이 살짝 어둡게 덮고, 홈 HUD 윗부분과 하단 메뉴가 그대로 보여 어수선하다. | 없음 |

### 1-3. 메뉴 창 (서브UI5종 1, 캡처 `01_menu`)

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 아이콘 + 제목 + `>` 카드 줄 | `MenuPanel`(public_menus.dart). 줄 최소 높이 56, 아이콘 32, 제목 18 굵게 | 시안은 4줄(도감·업적·통계·배경 테마)이고, 아이콘이 패널 폭의 약 25%, 제목이 큰 Jua이다. 현재는 10줄이라 아이콘·제목이 작다(아이콘이 패널 폭의 약 9%). 아이콘은 대부분 PixelIcon이고, 친구만 Material 선 아이콘(`Icons.people_alt_outlined`)이다. | K `menu-collection`, `menu-achievements`, `menu-records`, `menu-ranking`, `menu-theme`, `menu-daily`, `event-entry`, `menu-missions`, `menu-friends`, `menu-share`, `badge-daily` |
| (시안 없음) 가게 관리·로그인 | `_menu()`의 `FilledButton.icon` `menu-management` + `TextButton('로그인·보상 확인')` | 목록 아래 Material 버튼으로 따로 놓여 있고, `·`가 □로 나온다(캡처 확인). | K `menu-management`(창 제목 '가게 관리') |

### 1-4. 설정 창 (서브UI5종 2, 캡처 `02_settings`)

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 배경음·효과음·진동 토글 줄 | `SoundSettings` + `CozySettingRow` + `CozyOnOff`(84×36) | 토글 줄은 시안과 같은 모양이다. 현재는 줄이 더 많다: 배경음, **배경음 선택**, **굽는 소리**, 효과음, 음량, 진동, 모션 줄이기, 배경 시간. | K `setting-music`, `setting-sfx`, 문구 '진동'·'모션 줄이기' |
| 노란 음량 슬라이더 1개 | `SoundSettings.slider()` 3개(배경음·굽는 소리·효과음). 기본 `Slider`에 theme 색, 20칸 | 시안은 굵은 노란 트랙 + 크림 손잡이이다. 현재는 얇은 트랙 위에 눈금 점 20개가 찍히고, 끈 항목은 손잡이가 회색이다. | K `setting-music-volume`(lib에서는 `Key(key)`로 생성) |
| (시안 없음) 배경음 선택 | `InputDecorator(labelText:'배경음 선택')` + `DropdownButton` | Material 입력칸 스타일에 밑줄이 있다. | L `musicSelection` |
| (시안 없음) 배경 시간 | `Text` + `DropdownButton` | 밑줄 있는 기본 드롭다운이다. | L `setBackgroundTime` |
| 노란 "저장" 버튼 | `FilledButton.icon` `settings-save` | 목록 맨 끝이라 스크롤해야 보인다. 시안은 패널 아래 고정 큰 버튼이다. | K `settings-save`, `Scrollable`로 찾아감 |

### 1-5. 스킬 창 (서브UI5종 3, 캡처 `03_skills`)

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 카드: 큰 아이콘 + 이름 + 효과 칩 + "강화" | `WorkshopSkillShop` → theme `Card`(크림 + woodLight 테두리) | 현재 카드는 아이콘 48·이름 아래로 "0/1000 □ 클릭당 1", "구매 후 클릭당 2", 해금 안내, 긴 가격 버튼("1개 □ 붕어빵력 15 + 황금 1"), "자세히 보기"를 세로로 쌓는다. 서버 구매가 연결되지 않아 버튼이 모두 비활성(크림)이다. | K `skill-<id>`, `buy-<id>`, `after-<id>`, 문구 '자세히 보기'. L 활성 조건·`purchaseSkill` |
| (시안 없음) 클릭/자동, 1/10/최대 | `ChoiceChip` `kind-*`, `quantity-*` | Material 칩 두 줄이다. | K `kind-auto`, `quantity-one/ten/maximum` |
| (시안 없음) 준비 중 안내·구매 확인 대기 | `Text`, `CozyPanel` + `TextButton('복구'/'취소 확인')` | 안내 한 줄이 칩 아래에 그냥 놓여 있다. | L `recoverPurchase` |
| "뜨거운 불꽃 · 사용" 부스트 카드 | 없음 | 새 기획에 없는 기능이다(3-3). **만들지 않는다.** | — |

### 1-6. 꾸미기 창 (서브UI5종 4, 캡처 `04_wardrobe`)

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 큰 미리보기 액자 | `WardrobePanel._preview`(높이 180, 가게 실내 + 사장님 전신) | 시안은 탭 위에 놓이고, 사장님 상반신을 크게 보여 준다. 현재는 탭(5개, 2줄로 줄바꿈) 아래에 있고 전신이 작게 보인다. | K `preview-avatar`, `preview-stall`, `preview-bungeoppang`, 문구 '미리보기 · 미장착' |
| 헤어/의상/소품 탭 3개 | `ChoiceChip` `cosmetic-category-*` 5개(헤어·의상·소품·붕어빵·가게) + 칸 칩 `cosmetic-slot-*` 한 줄 | 시안은 같은 폭의 사각 탭 한 줄이다. 현재 '가게' 칩은 둘째 줄로 내려가고, 칸 칩(캐릭터·피부톤·머리·모자 …)이 한 줄 더 있다. | K `cosmetic-category-*`, `cosmetic-slot-*` |
| 3열 그리드(선택 시 주황 테두리) | `_tile` + `CosmeticThumb` | 3열은 같다. 칸 안에 이름·상태 글이 들어 있다("여자 사장님 / 장착 중"). | K `preview-<id>` |
| 노란 "적용" 버튼 | `_apply` → `CozyPanel`(이름·보유·해금 안내) + `FilledButton` | 그리드 아래 패널 속에 있어 스크롤해야 보인다. | K `buy-cosmetic-<id>`. L 구매·적용 |

### 1-7. 상점 창 (서브UI5종 5, 캡처 `05_shop`)

| 시안 요소 | 현재 위젯·파일 | 차이 | 위험 |
| --- | --- | --- | --- |
| 장비/꾸미기/테마 탭 | `ShopPanel` `ChoiceChip` `shop-tab-*` 4개(장비·꾸미기·테마·**충전**) | 시안은 같은 폭의 사각 탭이다. | K `shop-tab-gear/cosmetics/theme` |
| 1열 목록 카드(왼쪽 큰 그림 + 이름·가격·구매) | `AccessCosmeticAction` 2열 격자(그림이 카드 위에 따로 놓이고, 카드 안에 이름·상태·버튼) | 배치가 다르다. 현재는 "판매 준비 중"과 '잠김' 버튼이 대부분이고, 가격 앞 붕어빵 아이콘이 없다. | K `shop-buy-<id>`, `buy-cosmetic-<id>` |
| (시안 없음) 황금 충전 | 상점 '충전' 탭(`GoldChargeTab`) + `_goldPacks()`(흰 Material 바텀시트 + `ListTile`) | `_goldPacks`는 시트 틀 없이 열린다. 로그인이 필요해 이번 캡처에는 없다. | K `gold-*`. L 결제 |

### 1-8. 골든 3장 대 시안 (`92_goldens_vs_mockup.png`)

- 골든은 **구형 홈**이다. 그 결과:
  - 배경에 쇠틀이 그려진 그림을 쓴다.
  - 중앙 붕어빵이 쇠틀 안에 있다.
  - 하단 메뉴 배지가 보인다.
  - 글자는 테스트 글꼴이라 모두 □이다.
- 360·390·412 세 크기 모두 HUD가 두 줄이고, 메뉴·설정이 원형 버튼으로 둘째 줄에 있다.
- 시안과 같은 점: 차양, 6구 판, 조리 컷 위치, 하단 4버튼.
- 시안과 다른 점: Lv 배지 폭, 카운터 높이, 중앙 쇠틀.
- 출시 화면 비교용으로는 쓸 수 없다. 5장 2번을 참고한다.

## 2. 시안에 없지만 지금 있는 기능 → 옮길 스타일 제안

| 기능 | 현재 위치·형태 (캡처) | 제안 스타일 |
| --- | --- | --- |
| 가게 관리: 영업 시작/종료, 붕어빵력 모으기, 승급 | `_content(management:true)` 위쪽 (`06`) | 맨 위에 꾸미기 창의 미리보기 액자(배경 + 사장님)를 둔다. "영업" 크림 카드 하나에 상태 알약, 노란 주 버튼(영업 시작/이어가기), 보조 버튼(영업 종료·승급)을 넣는다. 지금은 사장님 전신 위 빈 공간이 크다. |
| 영업 종료 확인 | `AlertDialog`(theme 크림 + 나무 테두리) | 시트 틀과 같은 제목·버튼 모양으로 맞춘다. |
| 큰 틀 연습·레시피 획득 | 같은 창. `DropdownButton`, `ListTile` + '받기', `Chip ●/○` | 맛 선택은 상점의 사각 탭으로 바꾼다. 레시피 미션은 스킬 카드 형식(아이콘 + 조건 칩 + '받기')으로 만든다. 익힘 5단계는 작은 붕어빵 아이콘(채움/빈칸)으로 바꿔 `●○` 글꼴 문제도 해결한다. |
| 재고 | 같은 창. `Text` 줄 | 메뉴 카드 줄로 만든다(맛 아이콘 + "팥 미디엄 3개" + 경과일 칩). |
| 손님 주문: 대기열·대사·주문 제작·판매 | 같은 창. `Text` 여러 줄 + `TextButton` | 손님마다 크림 카드에 이름표, 말풍선, 주문 칩, 남은 시간 막대, 노란 "주문 제작" 버튼을 둔다. '첫 손님에게 전량 판매'는 창 아래 고정 주 버튼으로 둔다. |
| 손님 장면: 이웃 이야기·선택 | `Scaffold + AppBar('이웃 이야기')`, `CustomerChoicePanel`(선택지 `OutlinedButton` 3개 + `TextButton`) | 시트 틀 + 이름표 + 큰 말풍선 카드로 만든다. **선택지는 `OutlinedButton` 타입을 유지한 채 스타일만 바꾼다**(`customer_story_panel_test`가 정확히 3개를 센다). |
| 도감 | `_collection()` (`07`): 잠김이면 글 한 줄 | 잠김 상태도 자물쇠 아이콘 카드로 만든다. 열리면 메뉴 카드 줄 + 익힘 붕어빵 아이콘, 손님은 `CustomerRecordCard`(현재 theme `Card` + `ListTile`)를 크림 카드 + 단계 칩으로 만든다. |
| 업적 | `_achievements()` (`08`): `CozyPanel(ListTile)` | 메뉴 카드 줄 형식에 오른쪽 상태 칩(진행 중/달성)을 둔다. |
| 생산 기록(통계) | `_records()` (`09`): `CozyPanel(Row)` 9줄 | 이미 크림 카드이다. 왼쪽 아이콘만 추가하고 줄 높이를 메뉴 카드에 맞춘다. 메뉴 이름은 '통계', 창 제목은 '생산 기록'으로 다르다(테스트가 '생산 기록'을 검사하므로 제목은 유지). |
| 일일·주간 미션 | `_missions()`, `_mission()` (`10`, `11`): `ListTile` + 비활성 `TextButton('보상 신청')` | 스킬 카드 형식으로 만든다(아이콘 + 미션명 + 진행 칩 "0/50" + 노란 "보상 신청"). 보상 문구의 `·`를 정리한다. |
| 레벨 미션·승급 | `_levelMissions()` (`12`) | 홈 Lv 배지 모양을 크게 쓰고, 노란 막대와 조건 칩 3개, 노란 '승급' 버튼을 둔다. |
| 황금 보상 확인·광고(비활성) | 가게 관리 창 아래 `TextButton`, `FilledButton(null)` | 크림 카드 하나에 "심사 대기 N건" 칩, 보조 버튼, 비활성 노란 광고 버튼과 안내를 넣는다. |
| 황금 충전 | `_goldPacks()` 기본 바텀시트 | `showWorkshopWindow` 틀과 상점 카드 형식을 쓴다. |
| 온라인 랭킹 | `RankingPanel` (`13`): 준비 중이면 글 한 줄. 연결되면 `ChoiceChip` 탭 + `CozyPanel` 목록 | 준비 중 상태도 아이콘 + 안내 카드로 만든다. 탭은 사각 탭, 내 순위는 강조 카드로 만든다. |
| 친구 | `FriendsPanel` (`14`): 내 아이디 `CozyPanel` + 기본 `TextField` 2개 + 버튼 | 입력칸을 크림 바탕 + 나무 테두리로 맞추고, 버튼은 노란 주 버튼으로 바꾼다. |
| 게임 공유 | `SharePanel` (`15`): 문구 상자 + 노란 '공유하기' + '문구 복사하기' | 이미 시안 톤에 가깝다. 문구 상자의 `·`만 정리한다. |
| 초대 | `InvitePanel` | Workshop에서 열리지 않는다(0장). 대상에서 뺀다. |
| 축하 배너·미션 알림·오프라인 보상 | `CelebrationHost`(game_app.dart, 모든 창 위) / `OfflineRewardDialog` | `CelebrationHost`는 구형 `GameController` 이벤트로 움직인다. Workshop 진행으로 뜨는지는 확인하지 못했다(**미확인**). 오프라인 보상 창은 workshop이 있으면 열지 않는다(`_welcomeBack` 앞에서 return). 이번 단계에서는 다루지 않고, 뜨는 경로가 확인되면 시트 틀 스타일을 적용한다. |
| 짧은 알림 | `SnackBar`(theme: 짙은 나무색 + 크림 Jua) | 로그인·지갑 오류 문구용이다. 이미 Cozy 색이다. 유지한다. |
| 콤보 표시 | `_ComboLabel`(구형 홈 `_stage`에만 있음) | Workshop 홈에는 콤보가 없다. 대상에서 뺀다. |
| 센서 토글·다시 보정 | `_sensorControl()`: `Switch` + 글자 + `IconButton(Icons.screen_rotation)` | 반죽 단계에서만 보이는 작은 크림 알약에 `CozyOnOff`와 상태 글을 넣는다. 보정 버튼은 작은 둥근 나무 버튼으로 만든다. |
| 제작 중 안내·버튼 | `WorkshopMoldStage`의 `_caption`, `FilledButton`, `TextButton` | 안내는 반투명 크림 알약에, 보관은 노란 주 버튼에, 버리기·제작 취소는 크림 보조 버튼에 넣는다. |
| 홈 상태 문구 | `_note('workshop-status')` | HUD 아래 작은 크림 알약으로 옮기고 `·`를 바꾼다. |

## 3. 바꾸면 안 되는 목록

전체 목록(Key 148, 툴팁 2, 문구 52, Semantics 2, 위젯 타입 12)은 [부록](visual-00-test-finders.md)에 있다. 이 장은 비주얼 작업이 닿는 것만 추린다.

### 3-1. Workshop 출시 경로에서 테스트가 찾는 것

| 영역 | Key | 툴팁·문구·타입 |
| --- | --- | --- |
| 홈 | `home-capture`, `griddle`, `workshop-cell-N`(테스트는 5번), `workshop-mold-action`, `workshop-phase-time`, `active-empty-mold`, `piping-amount`, `auto-rate`, `tap-rate`, `level-mission-entry`, `level-progress`, `menu-menu`, `menu-badge`, `menu-menubar`, `menu-skills`, `menu-skins`, `menu-shop` | 툴팁 '설정'. 문구 '보관', '숟가락', '왼쪽으로 속 넣기'. 타입 `NightHome`(1개), `BakeTarget`(0개), `BatterHoldButton`, `PipingBagControl` |
| 시트 틀 | `workshop-window-title`, `sheet-back` | 툴팁 '닫기'. 타입 `CozyBackButton`(360×800 아래 끝 ≤ 776) |
| 창 제목(정확히 일치) | — | '상점', '도감', '업적', '생산 기록', '온라인 랭킹', '꾸미기'(menu-theme), '일일 미션', '주간 도전', '레벨 미션', '친구', '게임 공유', '가게 관리' |
| 메뉴 | `menu-collection`, `menu-achievements`, `menu-records`, `menu-ranking`, `menu-theme`, `menu-daily`, `event-entry`, `event-countdown`, `menu-missions`, `menu-friends`, `menu-share`, `menu-management`, `badge-daily` | 문구 '맛 도감은 Lv.'(포함), '순위', '이 기기 기록', '일일 미션' |
| 설정 | `setting-music`, `setting-music-volume`, `setting-sfx`, `settings-save` | 문구 '진동', '모션 줄이기'. 타입 `Scrollable`(스크롤로 찾아감) |
| 스킬 | `kind-auto`, `quantity-one`, `quantity-ten`, `quantity-maximum`, `skill-auto_1`, `skill-tap_1`, `buy-tap_1`, `after-<id>`, `current-<id>`, `status-<id>`, `skills-tap` | 문구 '자세히 보기'. 타입 `WorkshopSkillShop` |
| 꾸미기 | `cosmetic-category-{hair,outfit,props,bungeoppang,stall}`, `cosmetic-slot-<slot>`, `preview-<id>`, `preview-avatar`, `preview-stall`, `preview-bungeoppang`, `buy-cosmetic-<id>` | 문구 '미리보기 · 미장착' |
| 상점 | `shop-tab-gear`, `shop-tab-cosmetics`, `shop-tab-theme`, `shop-buy-<id>`, `support-entry` | — |
| 손님 | — | 타입 `OutlinedButton` 정확히 3개(`CustomerChoicePanel`). 문구 '아직 만나지 않은 이웃', '김도윤', '퇴근길 윤하 씨', '+3'(없어야 함) |
| 온라인 | `ranking-*`, `online-*`, `friends-offline` | 문구 '내 순위 · N위', '로그인하지 못했어요. 잠시 후 다시 해 주세요' |

**주의**
- 테스트 문구 중 `·`가 들어간 것('미리보기 · 미장착', '내 순위 · 1위', '0 / 1 · 진행 중' 등)이 있다. 글꼴 문제로 `·`를 바꾸면 이 테스트들이 함께 깨진다.
- 기호를 바꾸는 방법으로는 다음 중 하나를 고른다(5장 3번).
  - 글자는 그대로 두고 대체 글꼴로 보이게 한다.
  - 문구와 테스트를 같은 작업에서 함께 바꾼다.

### 3-2. 테스트는 안 찾지만 문서·다른 화면이 쓰는 Key

- `balance-value`, `lifetime-value`, `stall-scene`, `golden-chance-N`, `home-scroll`, `records-scroll`은 MASTER 10장에 적힌 Key이다.
  - 테스트 의존은 없지만 이름을 바꾸면 MASTER도 고쳐야 하므로 유지한다.
- `floating-fish`, `idle-mold`, `workshop-center-stage`, `workshop-status`는 미커밋 변경과 Workshop 홈의 Key이다. 테스트 참조는 없다.

### 3-3. 이름·문구 원칙

- "붕어빵력", "황금붕어빵력"은 기획 용어이다(MASTER 20장 "goldName 표기는 황금붕어빵력"). 시안의 "보유 붕어빵" 문구를 그대로 가져오지 않는다.
- 신규 화면에서 코인·환생 UI는 노출하지 않는다(MASTER 20장). 시안의 부스트 카드("뜨거운 불꽃")를 새로 만들지 않는다.
- 메뉴의 '통계'와 창 제목 '생산 기록'처럼, 메뉴 이름과 창 제목이 다른 곳이 있다. 창 제목은 테스트가 고정하므로 맞추려면 메뉴 이름 쪽을 바꾼다.

## 4. 테스트 기준선

### 실행 조건

- 일시: 2026-10-24
- 도구: Flutter 3.47.5 stable(`C:/flutter-sdk/bin/flutter.bat`, PATH에 없음), Dart 3.13.4, `PUB_CACHE=C:/PubCacheBungeoppang`
- 대상: 커밋 `50b6fa8` + 0장의 미커밋 홈 무대 변경을 포함한 작업 트리

### 결과

| 명령 | 결과 |
| --- | --- |
| `flutter test --no-pub --reporter expanded` (전체 62개 파일) | 종료 0. **589개 통과, 1개 건너뜀, 실패 0**(약 6분) |
| 건너뛴 1개 | `no_tracking_sdk_test` "release 병합 매니페스트에 광고·광고 ID·분석 항목이 없다". release 빌드 산출물이 없어서 건너뛰었다. 비주얼과 무관하다 |
| `test/home_golden_test.dart` | 3개 통과: '홈 레이아웃 골든 360/390/412'(360×800, 390×844, 412×915). **구형 홈 기준** |
| `test/step02_home_test.dart` | 3개 통과: 단위 테스트 'gravity projection stays neutral …' 1개 + 위젯 테스트 'original stall hosts real Workshop commands at Size(390×844)'·'… at Size(360×640)' 2개 |
| `test/public_menus_widget_test.dart` | 9개 통과: '꾸미기·내 기록·주간 도전 {360, 390, 412}/{1.0, 1.5, 2.0} 확대와 모션 감소' |
| `test/step02_menu_test.dart` | 2개 통과: 'restored menu routes and appearance authority at text scale 1.0 / 1.5' |
| `flutter analyze --no-pub` | **실행 불가.** 한글 경로 때문에 analysis server의 LSP JSON이 잘려 exit 255가 난다. 영문 junction(`C:/Temp/bungeoppang-visual-analysis` → 앱 폴더)에서도 같다 |
| `dart analyze lib test` (위 junction에서) | 종료 2. **error 0, warning 5, info 73.** warning은 모두 기존 미사용 import·선언이다(`lib/balance.dart`, `lib/game_controller.dart` `_autoLevelUp`, `lib/ui/level_missions.dart`, `lib/ui/support_panels.dart`, `test/premium_catalog_test.dart`). info는 대부분 `curly_braces_in_flow_control_structures`이고 `lib/ui/` 안에 4건이 있다. 로그: `C:/Temp/visual-00-analyze.log` |
| 캡처 도구 `coordination/visual-00-tools/capture_test.dart` | 1개 통과. 16장 저장. 정식 테스트에 포함하지 않는다 |

### 비주얼 작업 뒤 비교하는 법

- 테스트 실패가 0이 아니면 새로 생긴 실패이다.
- `dart analyze`는 error 0 / warning 5 / info 73과 비교한다. 이번 작업으로 늘어난 진단만 고친다.
- 화면은 같은 캡처 도구로 다시 찍어 `visual_00_current_20261024`와 나란히 비교한다.
- 실기기·에뮬레이터 확인은 하지 않았다(**미확인**).

## 5. 다음 단계 전에 정할 것

1. 미커밋 홈 무대 변경(떠 있는 붕어빵, 쇠틀 그림, bg_clean)을 기준선으로 먼저 커밋할지 정한다.
2. Workshop 홈 골든을 만들지 정한다. 출시 화면을 보호하는 골든이 없다.
   - 영업 준비·영업 중·제작 중 3장과 메뉴·설정 창 2장을 2단계 전에 추가하는 것을 추천한다.
   - 이때 Jua를 불러와야 한글 배치까지 검사할 수 있다(캡처 도구 방식).
3. `·`·`●○` 등 Jua에 없는 기호의 처리 방법을 정한다.
   - **대체 글꼴 지정:** 테스트 문구를 바꾸지 않아도 된다.
   - **기호 교체:** 문구 52개 중 `·`가 든 테스트 문구도 함께 바꿔야 한다.
4. 시트를 화면 92% 높이로 유지할지 정한다. 지금은 '돌아가기'가 홈 하단 메뉴 위에 겹친다.
   - 시안처럼 홈 HUD·메뉴를 가리고 노점 배경만 보이게 하려면 시트 뒤 막과 높이를 바꿔야 한다.
   - `step02_menu_test`의 "아래 끝 ≤ 776" 조건은 지켜야 한다.
5. 6구 판 아래 스테인리스 가스레인지(조리컷가스화면)를 넣으려면 새 그림이 필요하다. 2.2.5의 4단계에서 그림 제작을 범위에 넣을지 정한다.
