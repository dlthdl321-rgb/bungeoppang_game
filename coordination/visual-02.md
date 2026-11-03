# 비주얼 조정 2단계 — 디자인 토큰·공통 위젯 정비

작성일: 2026-10-24.
기준 프롬프트: [2.2.5 프롬프트 2단계](../2_development_plans_and_checklists/2.2_art_creation_guides_and_galleries/2.2.5_mockup_visual_update_prompts/README.md).
조사 결과: [visual-00-gap.md](visual-00-gap.md).

## 바꾼 파일

| 파일 | 내용 |
| --- | --- |
| `1_app_development/lib/ui/cozy_style.dart` | 토큰 추가, 기존 위젯 7개 모양 조정, 새 위젯 추가, 테마 조정. `dart format` 적용 |
| `1_app_development/lib/ui/game_app.dart` | `MaterialApp.builder`에서 `CozyMotion`으로 앱 전체를 감쌈. 값은 설정의 모션 줄이기(`settings.reduceMotion`) |
| `1_app_development/test/cozy_widgets_test.dart` | 새 테스트 6개 |
| `1_app_development/test/goldens/home_*.png` 3장 | 갱신(아래 골든 절) |
| `MASTER.md` 11장 | 토큰·공통 위젯·글자 크기 표 갱신 |

로직·설정·저장·서버 파일은 바꾸지 않았다. 화면 배치(위치·크기 규칙)도 바꾸지 않았다.

## 토큰

색은 시안 `서브UI5종`의 버튼·탭·칩·토글·슬라이더 픽셀을 뽑아 정했다.

| 토큰 | 값 | 시안 근거 |
| --- | --- | --- |
| honeyLight·honey·honeyDeep | `#FFD054`·`#FDBE38`·`#FEB432` | "강화"·"저장" 버튼과 선택된 "장비" 탭 면의 위·가운데·아래 |
| amber | `#F07D0C` | 노란 버튼 아래 경계 |
| tangerine | `#FD9607` | ON 토글 |
| tan | `#E9B47E` | 카드 안쪽 연한 선, 고르지 않은 탭 테두리 |
| peach·peachEdge | `#FDD09C`·`#F0B47A` | "클릭 +2" 칩 |
| taupe | `#8A6E62` | OFF 토글, 음량 막대 빈 부분 |
| knob | `#FFF6E8` | 토글·슬라이더 손잡이 |
| shadow·shadowDeep | `#55000000`·`#66000000` | 기존 하드코딩 그림자 값을 토큰으로 옮김 |

기존에 `CozyOnOff`의 OFF 색(`#8F8178`)과 그림자 값이 하드코딩되어 있었다. 모두 토큰으로 바꿨다.

## 기존 위젯 (이름·생성자 인자 그대로)

| 위젯 | 바뀐 모양 |
| --- | --- |
| CozyPanel | 안쪽 선을 woodLight에서 tan으로 바꿈(시안의 "짙은 선 → 연한 선" 2겹) |
| CozyRoundButton | 크기 48 유지. 그림자 추가, 눌림 |
| CozyFrame | 그림자 토큰만 바꿈 |
| CozyCloseButton | 크기 44 유지. 짙은 바깥선 1.5 + 크림 테두리 3, 눌림 |
| CozyBackButton | 전체 높이 54(여백 3 + 48) 유지. 아래 경계(peachEdge), 눌림. Key `sheet-back`은 눌림 대상에 그대로 있음 |
| CozySettingRow | 바꾸지 않음 |
| CozyOnOff | ON tangerine, OFF taupe, 손잡이 knob. 모션 줄이기면 이동 애니메이션 없음 |

## 새 위젯

| 위젯 | 용도(적용 예정 단계) |
| --- | --- |
| CozyPrimaryButton | 노란 주 버튼: 강화·구매·적용·저장·보관·영업 시작 (3~8단계) |
| CozyButton | 크림 보조 버튼: 버리기·제작 취소·영업 종료 (4·8단계) |
| CozyChip | 효과 칩: 스킬 효과, 미션 진행, 재고 경과일 (7·8단계) |
| CozyTabBar·CozyTab | 같은 폭 탭: 상점·꾸미기·스킬 종류·맛 선택 (7·8단계). `ChoiceChip`의 Key를 `CozyTab.key`로 옮기면 기존 테스트 Key가 유지됨 |
| CozyMenuRow | 메뉴 줄: 메뉴 창, 업적·도감·통계 (6·8단계) |
| CozyPressable | 위 버튼들의 눌림 처리(2px 내려감) |
| CozyMotion | 모션 줄이기 전달 |

- 슬라이더는 새 위젯을 만들지 않고 **테마**(`CozySliderTrackShape`, `CozySliderThumbShape`)로 바꿨다.
  - 그래서 `Slider` 타입과 Key(`setting-music-volume` 등)가 그대로 유지된다.
  - 설정 창의 음량 막대 3개는 지금 바로 시안 모양(두께 12, 노란 채움, 짙은 테두리, 눈금 없음)으로 보인다.
- `FilledButton`·`Switch`·`Chip`의 테마 색도 새 토큰으로 바꿨다(노란 면 + 짙은 테두리, 비활성은 creamDeep + tan).
  - 가게 관리·미션·스킬 창의 Material 버튼이 배치 변화 없이 시안 색으로 보인다.

### 구현 중 발견한 제약

- Flutter는 모서리가 둥근 상자의 테두리 색을 변마다 다르게 줄 수 없다(`A borderRadius can only be given on borders with uniform colors`).
- 그래서 시안의 "아래 경계"는 테두리가 아니라, 경계 색 바탕 위에 면을 3px 올리는 방식(`_Ledge`)으로 그렸다. 이후 단계에서 비슷한 모양을 만들 때도 같은 방식을 쓴다.

## 검증

| 확인 | 결과 |
| --- | --- |
| `flutter test --no-pub` 전체 (골든 갱신 전) | **592개 통과, 1개 건너뜀, 3개 실패.** 실패 3개는 `home_golden_test` 360·390·412이다. 기준선 589 + 새 테스트 6 − 골든 3과 같다 |
| 골든 차이 | 0.70~0.84%. 세 크기 모두 차이 영역이 HUD(위 40~204px)뿐이다. 바뀐 것은 HUD 카드 안쪽 선 색과 둥근 버튼 그림자이고, 배치 변화는 없다. 의도한 변경으로 확인하고 `--update-goldens`로 갱신했다. 갱신 뒤 3개 통과(비교 이미지 `04_golden_hud_diff_390.png`) |
| `test/cozy_widgets_test.dart` | 6개 통과. 다음을 확인한다: 눌림 2px·놓으면 실행, 모션 줄이기에서 정지, 비활성 버튼 눌리지 않음·흐린 글자, 탭 Key·선택 Semantics, 메뉴 줄·칩 글자, 돌아가기 높이 54 유지 |
| `dart analyze lib test` (영문 junction) | error 0, warning 5, info 73. **기준선과 같다.** 바뀐 파일에서 생긴 진단은 없다 |
| 견본 화면 | `4.9.1_inspection_sheets/visual_02_tokens_20261024/`: 새 위젯 견본, 시안과 비교, 창 4종의 전·후, HUD 골든 차이. 도구: `coordination/visual-00-tools/cozy_gallery_test.dart` |
| 실기기·에뮬레이터 | **미확인** |

## 다음 단계에 넘기는 것

- 새 위젯은 아직 화면에 쓰이지 않는다. 3단계(HUD)부터 적용한다.
- 0단계 5장의 결정 대기 항목(미커밋 홈 변경 커밋, Workshop 홈 골든, Jua에 없는 기호, 시트 높이, 가스레인지 그림)은 그대로 남아 있다.
