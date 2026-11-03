# 완성 시안 기준 비주얼 조정 프롬프트

[3.5_completed_game_mockups](../../../3_original_images_and_visual_references/3.5_completed_game_mockups/)의 완성 시안에 맞춰 현재 게임 화면을 조정하기 위한 단계별 작업 프롬프트입니다. **지금까지 만든 기능은 모두 유지하고 비주얼만 바꾸는 것**이 목표입니다.

작성일: 2026-10-24

## 현재 상태와 시안의 차이

| 구분 | 내용 |
| --- | --- |
| 이미 맞는 부분 | 홈 화면의 큰 구조(상단 HUD → 배경 → 중앙 → 6구 판 → 조리 컷 → 하단 메뉴 4개)는 시안과 같다. |
| 가장 큰 차이 ① | 중앙에 시안의 "떠 있는 큰 붕어빵 + 반짝이 + 터치해서 굽기" 대신 큰 쇠틀(`WorkshopMoldStage`)이 놓여 있다. |
| 가장 큰 차이 ② | `lib/ui/workshop_page.dart`의 가게 관리, 미션, 도감, 설정, 황금 충전 화면이 기본 Material 위젯(`ListTile`, `Chip`, `DropdownButton`, `FilledButton`)으로 되어 있어 시안의 크림·나무 패널 스타일과 다르다. |
| 지켜야 할 것 | 테스트가 쓰는 위젯 키(`fish-button`, `menu-menu`, `balance-value` 등), 골든 테스트 3종(360×800, 390×844, 412×915), CLAUDE.md의 "화면 배치를 바꾸면 MASTER.md도 고친다" 규칙. |

## 쓰는 방법

- 매 단계마다 **[공통 머리말]을 맨 앞에 붙여서** 사용한다.
- 한 번에 한 단계씩 실행하고, 끝날 때마다 골든 이미지나 스크린샷을 직접 확인한 뒤 다음 단계로 넘어간다.
- 3단계와 4단계는 서로 겹치는 파일(`night_home.dart`)이 많으므로 순서대로 진행한다.
- 중앙의 "떠 있는 붕어빵"은 영업 중 대기 상태에서 이미 구현되어 있다(2026-10-24 기준 미커밋 변경). 4단계는 이를 다듬는 작업이다.
- 1단계 조사 결과는 [coordination/visual-00-gap.md](../../../coordination/visual-00-gap.md)에 있다. 2단계부터는 이 문서를 함께 참고한다.

| 단계 | 내용 | 코드 수정 |
| --- | --- | --- |
| 1 | 조사·차이표 만들기 | 없음 |
| 2 | 디자인 토큰·공통 위젯 정비 | `cozy_style.dart` |
| 3 | 홈 상단 HUD | `night_home.dart` |
| 4 | 중앙 굽기 영역·굽는 판·조리 컷 | `night_home.dart`, `workshop_mold_stage.dart`, `cook_cut.dart` 등 |
| 5 | 하단 내비게이션 | `night_home.dart` |
| 6 | 시트 공통 틀 + 메뉴·설정 패널 | `workshop_windows.dart`, `public_menus.dart`, `workshop_page.dart` |
| 7 | 스킬·꾸미기·상점 패널 | `skill_shop.dart`, `public_menus.dart`, `shop_panel.dart`, `gold_widgets.dart` |
| 8 | 시안에 없는 화면 스타일 통일 | `workshop_page.dart`, `customer_story_panel.dart` |
| 9 | 검수·골든·문서 마무리 | 테스트·문서 |

---

## [공통 머리말] — 모든 단계 앞에 붙이기

```
이 작업은 "오늘의 붕어빵"의 비주얼만 조정하는 작업이다.
기준 시안: 3_original_images_and_visual_references/3.5_completed_game_mockups/ 의 이미지
(메인UI_화면, 중앙클리커화면, 조리컷가스화면, 서브UI5종, 메뉴/설정/스킬/꾸미기/상점_컷).

반드시 지킬 것:
1. 기능·규칙·저장·경제 로직은 바꾸지 않는다. WorkshopController, *_rules.dart, *_config.dart,
   저장 스키마, 서버 코드, development_balance.json은 수정 금지다. 수정 대상은 lib/ui/ 아래 위젯과 에셋뿐이다.
2. 지금 있는 버튼·패널·정보·진입 경로를 하나도 없애지 않는다. 시안에 없는 기능(가게 관리, 미션, 황금,
   센서 토글 등)도 시안의 스타일로 옮겨서 남긴다.
3. 기존 위젯 Key와 툴팁('설정', '닫기'), 창 제목 문자열, Semantics 라벨을 유지한다.
   Workshop 홈: griddle, workshop-cell-N, workshop-mold-action, workshop-phase-time, active-empty-mold,
   menu-menu, menu-menubar, menu-skills, menu-skins, menu-shop, balance-value, lifetime-value, auto-rate,
   tap-rate, level-mission-entry, home-scroll, home-capture. 창: workshop-window-title, settings-save,
   menu-management 등. 구형 홈(테스트 전용)의 fish-button, golden-chance-N도 지운다는 뜻이 아니다.
   전체 목록은 coordination/visual-00-gap.md 3장을 따른다.
4. 화면 글은 한국어로 쓰고 Jua 글꼴, lib/ui/cozy_style.dart의 Cozy 토큰을 사용한다.
   새 색이 필요하면 하드코딩하지 말고 Cozy에 토큰으로 추가한다.
5. 화면 배치·토큰을 바꾸면 같은 작업에서 MASTER.md 10장(화면 배치)·11장(디자인 토큰)을 코드에 맞게 고친다.
6. 작업 후 flutter test --no-pub를 실행하고, 결과를 있는 그대로 보고한다(Flutter는 C:/flutter-sdk/bin/flutter.bat,
   PUB_CACHE=C:/PubCacheBungeoppang). 정적 분석은 한글 경로에서 flutter analyze가 중단되므로 영문 junction
   C:/Temp/bungeoppang-visual-analysis에서 dart analyze lib test를 실행한다. 기준선은 coordination/visual-00-gap.md 4장이다.
   골든 차이는 의도한 변경인지 확인한 뒤에만 --update-goldens로 갱신한다.
7. 실기기·에뮬레이터로 확인하지 않았다면 "미확인"이라고 적는다.
```

---

## 1단계 — 조사·차이표 만들기 (코드 수정 없음)

```
[공통 머리말]

코드는 아직 고치지 말고 조사만 해 줘.
1. 3.5_completed_game_mockups의 시안 이미지를 모두 보고, 화면 요소마다 지금 어느 위젯이 담당하는지 표로 정리해 줘.
   (night_home.dart, night_stall_painter.dart, workshop_mold_stage.dart, cook_cut.dart, cozy_style.dart,
   public_menus.dart, skill_shop.dart, shop_panel.dart, workshop_page.dart, workshop_windows.dart 중심)
2. 표의 열: 시안 요소 / 현재 위젯·파일 / 차이(크기·색·테두리·아이콘·배치) / 바꿀 때 위험(Key, 골든, 로직 결합).
3. 시안에 없지만 지금 있는 기능(가게 관리, 일일·주간 미션, 레벨 미션, 황금 충전, 센서 토글, 손님 장면, 도감 등)을
   따로 목록으로 만들고, 각각 시안의 어떤 스타일로 옮기면 될지 제안해 줘.
4. 테스트가 참조하는 Key와 텍스트를 grep으로 모아 "바꾸면 안 되는 목록"을 만들어 줘.
5. 지금 flutter test 결과(특히 home_golden_test, step02_home_test, public_menus_widget_test)를 기준선으로 기록해 줘.
결과는 coordination/visual-00-gap.md에 저장해 줘.
```

## 2단계 — 디자인 토큰·공통 위젯 정비

```
[공통 머리말]

coordination/visual-00-gap.md를 참고해서 lib/ui/cozy_style.dart의 공통 위젯을 시안 스타일에 맞춰 줘.
- 시안의 크림색 카드(두꺼운 갈색 테두리 + 안쪽 밝은 테두리 + 아래 그림자), 노란 그라데이션 주 버튼("강화", "구매", "적용", "저장"),
  작은 효과 칩("클릭 +2", "초당 +5"), 탭 버튼(장비/꾸미기/테마, 헤어/의상/소품), ON/OFF 토글, 노란 음량 슬라이더,
  "아이콘 + 제목 + >" 메뉴 줄, 빨간 X 닫기 버튼, "↶ 돌아가기" 버튼을 공통 위젯으로 정리한다.
- 기존 위젯(CozyPanel, CozyFrame, CozyRoundButton, CozyCloseButton, CozyBackButton, CozySettingRow, CozyOnOff)은
  이름과 생성자 인자를 유지하고 모양만 바꾼다. 새 위젯은 추가만 한다(예: CozyPrimaryButton, CozyChip, CozyTabBar, CozyMenuRow, CozySlider).
- 눌림 상태(살짝 내려가는 모션), 비활성 상태(creamDeep, 흐린 글자)를 정의하고, reduceMotion이 켜져 있으면 모션을 끈다.
- 이 단계에서는 화면 배치를 바꾸지 않는다. 바뀐 공통 위젯으로 인한 골든 차이만 확인한다.
- MASTER.md 11장의 표를 갱신한다.
```

## 3단계 — 홈 상단 HUD

```
[공통 머리말]

lib/ui/night_home.dart의 상단 HUD를 메인UI_화면 시안처럼 바꿔 줘.
- 왼쪽: "Lv. 12" 나무 배지 + 그 아래 노란 진행 막대(headerData.progressPermille), 배지 아래에 메뉴 둥근 버튼(보상 배지 유지).
- 가운데: 크림 카드에 붕어빵 아이콘 + "보유 붕어빵" 작은 제목 + 큰 숫자 "12,850개"(천 단위 쉼표).
- 오른쪽: "⏱ 초당 N개", "☝ 클릭당 N개" 두 알약, 그 옆에 톱니 설정 버튼.
- 현재 2줄에 있는 상태 문구(영업 중/영업 준비 · 주문 N, 저장 확인 필요)는 없애지 말고 HUD 아래 작은 알약으로 옮긴다.
- 누적 생산(lifetime-value)도 Key를 유지한 채 보이게 하거나, 보조 글자로 남긴다.
- 기존 Key와 탭 동작(레벨 배지 → 레벨 미션, 메뉴, 설정)을 그대로 둔다.
- 360×800에서 글자가 넘치지 않게 FittedBox·비율로 맞추고, 큰 글자 설정에서 home-scroll로 스크롤되는 동작을 유지한다.
```

## 4단계 — 중앙 굽기 영역·굽는 판·조리 컷

```
[공통 머리말]

중앙클리커화면과 조리컷가스화면 시안을 기준으로 홈 가운데와 아래를 조정해 줘.
1. 중앙(WorkshopMoldStage 주변):
   - 영업 중 대기 상태의 떠 있는 붕어빵(FloatingFishPainter)과 알약(_pill)은 이미 있다. 시안에 맞게 붕어빵 크기,
     반짝이 크기·개수, 알약 위치만 조정한다. 영업 준비·주문 도착 직후 쇠틀(idle-mold)로 바뀌는 조건은 그대로 둔다.
   - 큰 틀 세션이 진행 중이면 기존 틀·반죽·센서 표시를 그대로 보여 준다. 세션 시작·입력·판정 코드는 손대지 않는다.
   - 맛 선택 DropdownButton과 "+N 붕어빵력" 버튼, 제작 중 안내(_caption)·보관/버리기/제작 취소 버튼을
     시안 톤의 알약·버튼으로 바꾼다. workshop-mold-action, workshop-phase-time, active-empty-mold Key와 '보관' 문구를 유지한다.
   - 센서 토글(_sensorControl)은 지우지 말고 시안 톤의 작은 알약으로 바꾼다.
2. 굽는 판(griddle): 6구 판 아래에 파란 가스 불꽃과 스테인리스 버너, 손잡이 노브가 있는 받침을 그린다.
   6칸 수확·탄 칸 폐기·golden-chance-N 위치와 expectedCycle 연결은 그대로 둔다.
3. 조리 컷(CookCut): 오른쪽 아래 나무 액자 프레임(두꺼운 갈색 테두리 + 크림 안쪽 선)으로 바꾸고, 위치와 비율은 시안에 맞춘다.
4. 새 이미지가 필요하면 assets에 추가하고 pixel_sprites.dart 경로 규칙을 따른다. 원본은 3_original_images_and_visual_references에 남긴다.
```

## 5단계 — 하단 내비게이션

```
[공통 머리말]

하단 내비게이션 4개(메뉴·스킬·꾸미기·상점)를 메인UI_화면 시안처럼 바꿔 줘.
- 크림 카드 버튼 + 두꺼운 나무 테두리, 왼쪽 큰 픽셀 아이콘(☰, ⚡, 앞치마, 쇼핑백) + 오른쪽 Jua 글자.
- 같은 폭, 높이 66 + 안전 영역, 보상 배지와 Key(menu-menubar 등)를 유지한다.
- 360 폭에서 글자가 잘리지 않는지 확인한다.
```

## 6단계 — 시트 공통 틀 + 메뉴·설정 패널

```
[공통 머리말]

서브UI5종 시안의 1번(메뉴)과 2번(설정)을 기준으로 바꿔 줘.
1. 시트 공통 틀(workshop_windows.dart의 showWorkshopWindow, game_app.dart의 _open 계열):
   위쪽 가운데 잔액 알약(붕어빵 아이콘 + "12,850개"), 그 아래 큰 크림 패널 + 양옆에 아이콘이 있는 제목,
   오른쪽 위 빨간 X, 맨 아래 "↶ 돌아가기"로 통일한다. 시트 뒤에는 노점 배경이 흐리게 보이게 한다.
2. 메뉴 패널(MenuPanel): 줄마다 큰 아이콘 + 제목 + ">" 카드. 기존 메뉴 순서와 항목(도감·업적·통계·랭킹·배경 테마·
   일일·주간·레벨 미션·친구·공유)과 보상 배지를 모두 유지한다.
   workshop_page.dart _menu()의 "주문·재고·영업 관리", "로그인·보상 확인" 버튼도 같은 카드 줄 스타일로 넣는다(Key 유지).
3. 설정(_audioSettings, SoundSettings): 배경음·효과음·진동·모션 줄이기를 아이콘 + 토글 줄로,
   음량은 노란 슬라이더로, 배경 시간 DropdownButton은 시안 톤의 선택 줄(또는 탭)로 바꾸고, 노란 "💾 저장" 버튼을 둔다.
```

## 7단계 — 스킬·꾸미기·상점 패널

```
[공통 머리말]

서브UI5종 시안의 3~5번을 기준으로 바꿔 줘.
1. 스킬(skill_shop.dart, workshop_page의 _shop): 큰 아이콘 + 이름 + 효과 칩 + 노란 "강화/사용" 버튼 카드.
   가격, 잠김, 구매 불가, 복합 결제 진행 중, 서버 검증 대기 같은 기존 상태 표시를 모두 시안 톤으로 유지한다.
2. 꾸미기(WardrobePanel): 위에 사장님 미리보기 액자(가게 배경 + AvatarPainter), 헤어/의상/소품 탭,
   3열 아이템 그리드(장착 중이면 주황 테두리, 잠김이면 자물쇠), 아래 노란 "적용" 버튼.
   기존 action 문구(장착 중/잠김/적용/준비 중/구매하고 적용)와 stall 탭을 유지한다.
3. 상점(ShopPanel, gold_widgets.dart): 장비/꾸미기/테마 탭(+기존 황금 탭), 왼쪽 큰 그림 + 이름 + 가격 + "구매" 카드.
   _goldPacks의 기본 바텀시트도 같은 시트 틀과 카드로 바꾼다. 결제·로그인 흐름은 그대로 둔다.
```

## 8단계 — 시안에 없는 화면들 같은 스타일로 맞추기

```
[공통 머리말]

workshop_page.dart에서 아직 Material 기본 위젯으로 된 화면을 6~7단계의 공통 위젯으로 바꿔 줘.
대상: _content(management:true) 가게 관리, _records, _collection, _achievements, _missions, _levelMissions,
_mission 줄, 손님 장면(이웃 이야기 Scaffold/AppBar), CustomerChoicePanel·CustomerRecordCard.
- 가게 관리는 "영업 / 큰 틀 연습·레시피 / 재고 / 손님 주문 / 도감 / 미션 / 황금 보상" 섹션별 크림 카드로 나누고,
  ListTile·Chip·Divider·DropdownButton·TextButton을 CozyMenuRow·CozyChip·CozyPrimaryButton 등으로 바꾼다.
- 익힘 5단계 ●○ 표시는 작은 붕어빵 아이콘(채움/빈칸)으로 바꿔도 되지만 정보는 그대로 둔다.
- 손님 장면은 AppBar 대신 시트 틀 + 손님 이름표 + 말풍선 카드로 바꾼다.
  CustomerChoicePanel의 선택지는 OutlinedButton 타입을 유지하고 스타일만 바꾼다(테스트가 정확히 3개를 센다).
- 랭킹·친구·공유 창도 같은 공통 위젯으로 맞춘다. 초대 창은 Workshop에서 열리지 않으므로 대상이 아니다.
- 모든 버튼의 활성/비활성 조건(c.busy, c.error, gameplayPaused 등)은 그대로 둔다.
- 글이 긴 섹션은 작은 화면에서 스크롤되는지 확인한다.
```

## 9단계 — 검수·골든·문서 마무리

```
[공통 머리말]

비주얼 조정을 마무리해 줘.
1. flutter analyze, flutter test를 실행하고, 실패한 테스트는 로직 문제인지 비주얼 문제인지 구분해서 보고한다.
   로직 테스트를 통과시키려고 테스트 기대값을 바꾸지 않는다.
2. home_golden_test의 360×800, 390×844, 412×915 골든을 시안과 나란히 비교해서 차이 목록을 만들고,
   의도한 변경만 --update-goldens로 갱신한다. 메뉴·설정·스킬·꾸미기·상점 시트 골든이 없으면 추가한다.
3. 1단계의 "시안에 없지만 지금 있는 기능" 목록을 하나씩 확인해서 빠진 진입 경로가 없는지 체크표로 남긴다.
4. MASTER.md 10장·11장, 1_app_development/README.md의 화면 설명을 코드에 맞게 고친다.
5. 결과를 coordination/visual-09-review.md에 남긴다. 실기기 확인 여부를 따로 적는다.
```
