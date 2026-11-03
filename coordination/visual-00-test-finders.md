# 비주얼 조정 0단계 부록 — 테스트가 찾는 Key·툴팁·문구·타입 전체 목록

작성일: 2026-10-24. [visual-00-gap.md](visual-00-gap.md) 3장의 원본 목록이다.
생성 도구: `coordination/visual-00-tools/finders.py`. `1_app_development` 폴더에서 `python -I -X utf8 ../coordination/visual-00-tools/finders.py .`로 다시 만든다.

## 읽는 법

- **범위:** `test/*.dart` 62개 파일에서 다음을 찾았다.
  - `Key('…')`, `ValueKey('…')`
  - `find.byTooltip`, `find.text`, `find.textContaining`, `find.widgetWithText`, `find.bySemanticsLabel`, `find.byType`, `find.byWidgetPredicate`
  - `containsKey(` 같은 Map 메서드는 제외했다.
- **"정의된 lib 파일" 열:** lib의 `Key('…${id}…')` 같은 조합 Key도 패턴으로 대조했다. 여러 패턴이 맞으면 고정 글자가 가장 긴 것만 남겼다.
  - 예: `buy-cosmetic-boy`는 `buy-${id}`가 아니라 `buy-cosmetic-${id}`에 대응한다.
- **이 방식으로 못 잡는 것:** Key 문자열을 변수로 넘기는 경우(`Key(key)`, `_action('invite-new', …)`)는 정규식으로 잡히지 않아 "(lib에 없음)"으로 나온다. 아래에서 6개를 손으로 확인했다.
- **비주얼 작업 범위:** 출시 경로(Workshop)에 해당하는 파일은 다음과 같다.
  - `ui/night_home.dart`, `ui/workshop_*.dart`, `ui/public_menus.dart`, `ui/shop_panel.dart`, `ui/gold_widgets.dart`, `ui/cozy_style.dart`, `ui/cook_cut.dart`, `ui/customer_story_panel.dart`
  - `ui/game_app.dart`(`SoundSettings`, 앱 틀), `ui/ranking_panel.dart`, `ui/friends_panel.dart`, `ui/progress_panels.dart`(`SharePanel`)
  - 그 밖의 파일(`bake_target.dart`, `skill_shop.dart`, `support_panels.dart`, `level_missions.dart`, `invite_panel.dart` 등)은 구형 홈 또는 Workshop에서 열리지 않는 화면이다. 지우거나 바꾸지 않아도 되지만, 공통 위젯(`cozy_style.dart`)을 바꾸면 함께 영향을 받는다.

## "(lib에 없음)" 6개 확인 결과

| Key | 실제 위치 |
| --- | --- |
| `setting-music-volume` | `ui/game_app.dart` 704행 `SoundSettings`의 `slider('setting-music-volume', …)` → `Key(key)` |
| `invite-new`, `invite-level-one`, `invite-existing` | `ui/invite_panel.dart` 230행 근처 `_action('invite-…', …)` |
| `batter` | 테스트(`cooking_controls_test`)가 직접 만든 위젯의 `ValueKey`. lib Key가 아니다 |
| `mock-butter` | `level_missions_widget_test`가 "없어야 한다(findsNothing)"를 검사하는 Key |

## Key (148)

| Key | 정의된 lib 파일 | 참조 테스트 |
| --- | --- | --- |
| `achievement-claim-bake-1e4` | ui/progress_panels.dart | support_widget_test |
| `achievement-claim-combo-50` | ui/progress_panels.dart | stage8_widget_test |
| `achievement-claim-level-10` | ui/progress_panels.dart | support_widget_test |
| `achievement-tab-collection` | ui/progress_panels.dart | stage8_widget_test, support_widget_test |
| `active-empty-mold` | ui/workshop_mold_stage.dart | step02_home_test |
| `auto-rate` | ui/night_home.dart | step02_home_test, widget_test |
| `badge-daily` | ui/public_menus.dart | mission_alerts_test |
| `batter` | (lib에 없음) | cooking_controls_test |
| `boost-time-${boost.id}` | ui/support_panels.dart | support_widget_test |
| `boost-time-golden` | ui/support_panels.dart | support_widget_test |
| `buy-cosmetic-${pair.$2}` | ui/public_menus.dart | public_menus_widget_test |
| `buy-cosmetic-beanie` | ui/public_menus.dart | stage12_customization_test, stage8_widget_test |
| `buy-cosmetic-boy` | ui/public_menus.dart | step02_menu_test |
| `buy-cosmetic-cardigan` | ui/public_menus.dart | stage14_systems_test |
| `buy-tap_1` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `buy-tap_2` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `celebration` | ui/celebration.dart | stage10_feedback_test |
| `claim-level` | ui/level_missions.dart | level_missions_widget_test, stage8_widget_test |
| `coin-balance` | ui/support_panels.dart | support_widget_test |
| `combo-label` | ui/night_home.dart | stage10_feedback_test, stage8_widget_test |
| `confetti` | ui/celebration.dart | stage10_feedback_test |
| `confirm-support` | ui/support_panels.dart | public_menus_widget_test, stage11_endgame_test, stage12_customization_test, stage14_systems_test, stage8_widget_test |
| `cook-cut` | ui/cook_cut.dart | stage12_customization_test |
| `cosmetic-category-${slot.tab.name}` | ui/public_menus.dart | stage11_endgame_test |
| `cosmetic-category-bungeoppang` | ui/public_menus.dart | stage12_customization_test, stage7_widget_test |
| `cosmetic-category-hair` | ui/public_menus.dart | stage12_customization_test, step02_menu_test |
| `cosmetic-category-outfit` | ui/public_menus.dart | stage14_systems_test |
| `cosmetic-category-props` | ui/public_menus.dart | stage14_systems_test |
| `cosmetic-category-stall` | ui/public_menus.dart | public_menus_widget_test, stage12_customization_test |
| `cosmetic-slot-${pair.$1.name}` | ui/public_menus.dart | public_menus_widget_test |
| `cosmetic-slot-${slot.name}` | ui/public_menus.dart | stage11_endgame_test, stage14_systems_test |
| `cosmetic-slot-accessory` | ui/public_menus.dart | stage14_systems_test |
| `cosmetic-slot-fish` | ui/public_menus.dart | stage12_customization_test |
| `cosmetic-slot-hat` | ui/public_menus.dart | stage12_customization_test, stage8_widget_test |
| `cosmetic-slot-tool` | ui/public_menus.dart | stage14_systems_test |
| `crumbs` | ui/bake_target.dart | stage10_feedback_test |
| `current-auto_1` | ui/skill_shop.dart | skill_shop_test |
| `daily-claim-all` | ui/support_panels.dart | support_widget_test |
| `daily-claim-taps` | ui/support_panels.dart | support_widget_test |
| `daily-store` | ui/support_panels.dart | support_widget_test |
| `developer-invites` | ui/progress_panels.dart | invite_widget_test, level_missions_widget_test, stage8_widget_test |
| `event-countdown` | ui/public_menus.dart | stage7_widget_test, widget_test |
| `event-entry` | ui/public_menus.dart | public_menus_widget_test, stage7_widget_test, stage8_widget_test, widget_test |
| `fish-button` | ui/bake_target.dart | stage10_feedback_test, stage12_customization_test, stage8_widget_test, widget_test |
| `fish-scale` | ui/bake_target.dart | widget_test |
| `friends-offline` | ui/friends_panel.dart | stage9_ranking_test |
| `griddle` | ui/night_home.dart | step02_home_test |
| `home-capture` | ui/night_home.dart | home_golden_test, stage7_widget_test, step02_home_test |
| `home-prestige` | ui/night_home.dart | stage11_endgame_test |
| `home-title` | ui/night_home.dart | stage8_widget_test, support_widget_test |
| `invite-click` | ui/invite_panel.dart | invite_widget_test |
| `invite-copy` | ui/invite_panel.dart | invite_widget_test |
| `invite-debug` | ui/invite_panel.dart | invite_widget_test, level_missions_widget_test |
| `invite-existing` | (lib에 없음) | invite_widget_test |
| `invite-level-one` | (lib에 없음) | invite_widget_test |
| `invite-new` | (lib에 없음) | invite_widget_test |
| `invite-player` | ui/invite_panel.dart | invite_widget_test |
| `invite-prepare` | ui/invite_panel.dart | invite_widget_test |
| `invite-replay` | ui/invite_panel.dart | invite_widget_test |
| `invite-share` | ui/invite_panel.dart | invite_widget_test |
| `kind-auto` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `level-mission-entry` | ui/night_home.dart | level_missions_widget_test, stage11_endgame_test, stage8_widget_test |
| `level-progress` | ui/night_home.dart | widget_test |
| `menu-$id` | ui/night_home.dart | stage8_widget_test, widget_test |
| `menu-achievements` | ui/public_menus.dart | support_widget_test |
| `menu-badge` | ui/night_home.dart | mission_alerts_test |
| `menu-daily` | ui/public_menus.dart | support_widget_test |
| `menu-friends` | ui/public_menus.dart | stage9_ranking_test |
| `menu-menu` | ui/night_home.dart | invite_widget_test, level_missions_widget_test, mission_alerts_test, public_menus_widget_test, stage7_widget_test, stage8_widget_test, stage9_ranking_test, step02_home_test, support_widget_test, widget_test |
| `menu-ranking` | ui/public_menus.dart | stage9_ranking_test |
| `menu-records` | ui/public_menus.dart | public_menus_widget_test, stage8_widget_test |
| `menu-share` | ui/public_menus.dart | invite_widget_test, level_missions_widget_test, stage8_widget_test |
| `menu-shop` | ui/night_home.dart | stage14_systems_test, support_widget_test, widget_test |
| `menu-skills` | ui/night_home.dart | skill_shop_test, widget_test |
| `menu-skins` | ui/night_home.dart | public_menus_widget_test, stage11_endgame_test, stage12_customization_test, stage14_systems_test, stage7_widget_test |
| `mission-invites` | ui/level_missions.dart | level_missions_widget_test |
| `mission-notice` | ui/celebration.dart | mission_alerts_test |
| `mission-open-cosmetics` | ui/level_missions.dart | stage8_widget_test |
| `mission-preview` | ui/level_missions.dart | level_missions_widget_test |
| `missions-finished` | ui/level_missions.dart | level_missions_widget_test |
| `mock-butter` | (lib에 없음) | level_missions_widget_test |
| `mock-invite-create` | ui/invite_panel.dart | level_missions_widget_test |
| `mock-invite-notice` | ui/invite_panel.dart | level_missions_widget_test, stage8_widget_test |
| `offline-reward` | ui/celebration.dart | stage10_feedback_test |
| `offline-reward-amount` | ui/celebration.dart | stage10_feedback_test |
| `offline-reward-close` | ui/celebration.dart | stage10_feedback_test |
| `online-account` | ui/ranking_panel.dart | stage9_ranking_test |
| `online-sign-in` | ui/ranking_panel.dart | stage9_ranking_test |
| `online-sign-in-error` | ui/ranking_panel.dart | stage9_ranking_test |
| `online-sign-out` | ui/ranking_panel.dart | stage9_ranking_test |
| `piping-amount` | ui/piping_bag_control.dart | step02_home_test, step02_piping_test |
| `prestige-card` | ui/level_missions.dart | stage11_endgame_test |
| `prestige-open` | ui/level_missions.dart | stage11_endgame_test |
| `preview-${last.id}` | ui/public_menus.dart | stage11_endgame_test |
| `preview-${pair.$2}` | ui/public_menus.dart | public_menus_widget_test |
| `preview-avatar` | ui/public_menus.dart | stage12_customization_test, stage8_widget_test |
| `preview-beanie` | ui/public_menus.dart | stage12_customization_test, stage8_widget_test |
| `preview-bungeoppang` | ui/public_menus.dart | stage12_customization_test |
| `preview-cardigan` | ui/public_menus.dart | stage14_systems_test |
| `preview-stall` | ui/public_menus.dart | public_menus_widget_test, stage12_customization_test |
| `preview-starmark` | ui/public_menus.dart | stage7_widget_test |
| `quantity-maximum` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `quantity-one` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `quantity-ten` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `ranking-lifetime-capped` | ui/ranking_panel.dart | stage9_ranking_test |
| `ranking-list` | ui/ranking_panel.dart | stage9_ranking_test |
| `ranking-me` | ui/ranking_panel.dart | stage9_ranking_test |
| `ranking-tab-$rankingBestCombo` | ui/ranking_panel.dart | stage9_ranking_test |
| `ranking-tab-$rankingLifetime` | ui/ranking_panel.dart | stage9_ranking_test |
| `ranking-unavailable` | ui/ranking_panel.dart | stage9_ranking_test |
| `record-best-combo` | ui/progress_panels.dart | stage8_widget_test |
| `record-lifetime` | ui/progress_panels.dart | public_menus_widget_test |
| `record-new-combo` | ui/progress_panels.dart | stage8_widget_test |
| `record-new-day` | ui/progress_panels.dart | stage8_widget_test |
| `recovery-message` | ui/game_app.dart | stage7_widget_test |
| `recovery-reset-confirm` | ui/game_app.dart | stage7_widget_test |
| `referral-code` | ui/invite_panel.dart | invite_widget_test |
| `setting-music` | ui/game_app.dart | step02_home_test |
| `setting-music-volume` | (lib에 없음) | stage10_feedback_test |
| `setting-sfx` | ui/game_app.dart | stage10_feedback_test |
| `settings-save` | ui/game_app.dart, ui/workshop_page.dart | stage14_systems_test, step02_home_test |
| `share-game` | ui/progress_panels.dart | stage8_widget_test |
| `share-message` | ui/progress_panels.dart | stage8_widget_test |
| `shop-buy-castiron` | ui/shop_panel.dart | stage14_systems_test |
| `shop-buy-night` | ui/shop_panel.dart | support_widget_test |
| `shop-buy-rain` | ui/shop_panel.dart | stage14_systems_test |
| `shop-buy-ribbon` | ui/shop_panel.dart | stage14_systems_test |
| `shop-tab-cosmetics` | ui/shop_panel.dart | stage14_systems_test |
| `shop-tab-gear` | ui/shop_panel.dart | step02_menu_test |
| `shop-tab-theme` | ui/shop_panel.dart | stage14_systems_test, support_widget_test |
| `skill-auto_1` | ui/skill_shop.dart, ui/workshop_windows.dart | step02_menu_test |
| `skill-tap_1` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `skill-tap_2` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `skills-tap` | ui/skill_shop.dart, ui/workshop_windows.dart | skill_shop_test |
| `static-gain` | ui/bake_target.dart | stage10_feedback_test, widget_test |
| `status-tap_1` | ui/skill_shop.dart | skill_shop_test |
| `support-entry` | ui/shop_panel.dart | stage14_systems_test, support_widget_test |
| `tap-burst` | ui/bake_target.dart | stage10_feedback_test, widget_test |
| `tap-rate` | ui/night_home.dart | step02_home_test, widget_test |
| `title-combo-50` | ui/progress_panels.dart | stage8_widget_test |
| `title-level-10` | ui/progress_panels.dart | support_widget_test |
| `weather` | ui/weather_layer.dart | stage14_systems_test |
| `weekly-claim-taps` | ui/progress_panels.dart | public_menus_widget_test |
| `weekly-countdown` | ui/progress_panels.dart | widget_test |
| `workshop-cell-5` | ui/workshop_mold_stage.dart | step02_home_test |
| `workshop-mold-action` | ui/workshop_mold_stage.dart | step02_home_test |
| `workshop-phase-time` | ui/workshop_mold_stage.dart | step02_home_test |
| `workshop-window-title` | ui/workshop_windows.dart | step02_menu_test |

## 툴팁 (2)

| 값 | 참조 테스트 |
| --- | --- |
| `닫기` | level_missions_widget_test, public_menus_widget_test, stage11_endgame_test, stage12_customization_test, stage8_widget_test, stage9_ranking_test, step02_menu_test, support_widget_test, widget_test |
| `설정` | stage10_feedback_test, stage14_systems_test, step02_home_test, widget_test |

## 문구(정확히 일치) (36)

| 값 | 참조 테스트 |
| --- | --- |
| `$comboDisplayMinimum 콤보!` | stage8_widget_test |
| `+3` | customer_story_panel_test |
| `0 / 1 · 진행 중` | level_missions_widget_test |
| `0 / 3 · 진행 중` | level_missions_widget_test |
| `1 / 1 · 완료` | level_missions_widget_test |
| `1.23조` | widget_test |
| `10개 구매 후 클릭당 11` | skill_shop_test |
| `1개 · 15` | widget_test |
| `3 / 3 · 완료` | level_missions_widget_test |
| `3 코인` | stage10_feedback_test |
| `test:fund` | support_widget_test |
| `길게 눌러 굽기` | widget_test |
| `김도윤` | customer_story_panel_test |
| `내 순위 · 1위` | stage9_ranking_test |
| `내 순위 · 2위` | stage9_ranking_test |
| `내 아이디  BBFAKECODE` | stage9_ranking_test |
| `다음 단계 미리보기 · Lv.5` | level_missions_widget_test |
| `다음 단계 미리보기 · Lv.6` | level_missions_widget_test |
| `로그인하지 못했어요. 잠시 후 다시 해 주세요` | stage9_ranking_test |
| `모션 줄이기` | step02_home_test |
| `미리보기 · 미장착` | stage12_customization_test, stage14_systems_test |
| `보관` | step02_home_test |
| `보유 코인 112개` | support_widget_test |
| `붕어왕` | stage9_ranking_test |
| `새로 시작 (데이터 초기화)` | stage7_widget_test |
| `숟가락` | step02_home_test |
| `신규 플레이어 초대 성공: 1 · 미활성` | level_missions_widget_test |
| `아직 만나지 않은 이웃` | customer_story_panel_test |
| `왼쪽으로 속 넣기` | step02_home_test |
| `이전 저장 복구` | stage7_widget_test |
| `자세히 보기` | skill_shop_test |
| `진동` | step02_home_test |
| `취소` | support_widget_test |
| `코인 거래 기록` | support_widget_test |
| `클릭당 2개` | widget_test |
| `퇴근길 윤하 씨` | customer_story_panel_test |

## 문구(포함) (16)

| 값 | 참조 테스트 |
| --- | --- |
| `1개 구매 후 클릭당` | skill_shop_test |
| `개발자 도구` | level_missions_widget_test |
| `맛 도감은 Lv.` | step02_menu_test |
| `문구 복사를 이용해 주세요` | invite_widget_test |
| `미리 채울 수 없어요` | level_missions_widget_test |
| `순위` | public_menus_widget_test |
| `오늘 보상 0명` | invite_widget_test |
| `오늘 보상 1명` | invite_widget_test |
| `오늘 보상 2명` | invite_widget_test |
| `이 기기 기록` | public_menus_widget_test |
| `이미 처리한 eventId` | invite_widget_test |
| `이전 저장이 없` | stage7_widget_test |
| `일일 미션` | mission_alerts_test |
| `잠김 · 누적 500` | skill_shop_test |
| `저장 실패` | level_missions_widget_test |
| `한국 시각 00:00` | support_widget_test |

## 위젯+문구 (0)

| 값 | 참조 테스트 |
| --- | --- |

## Semantics 라벨 (2)

| 값 | 참조 테스트 |
| --- | --- |
| `붕어빵 굽기` | widget_test |
| `상점` | widget_test |

## 위젯 타입 (12)

| 값 | 참조 테스트 |
| --- | --- |
| `BakeTarget` | step02_home_test, widget_test |
| `BatterHoldButton` | cooking_controls_test, step02_home_test |
| `CozyBackButton` | step02_menu_test |
| `CustomPaint` | stage7_widget_test |
| `NavigationBar` | widget_test |
| `NightHome` | step02_home_test |
| `OutlinedButton` | customer_story_panel_test |
| `PipingBagControl` | step02_home_test, step02_piping_test |
| `Scrollable` | skill_shop_test, stage14_systems_test, step02_home_test, step02_menu_test, widget_test |
| `SelectableText` | stage8_widget_test |
| `Text` | stage10_feedback_test, stage8_widget_test |
| `WorkshopSkillShop` | step02_menu_test |

## 조건식 탐색 (0)

| 값 | 참조 테스트 |
| --- | --- |

