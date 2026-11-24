# MASTER 색인 — 작업별로 읽을 곳

[MASTER.md](MASTER.md)는 약 440KB라 한 번에 다 읽을 수 없다. 작업을 시작할 때는 **이 색인에서 관련 장을 고른 뒤 그 장만** 읽는다. 장 찾기: `grep -n "^## " MASTER.md`로 장 제목과 줄 위치를 확인하고, 그 줄부터 다음 `## `까지만 읽는다. (줄 번호는 자주 바뀌므로 이 색인에는 적지 않는다.)

코드와 문서가 다르면 코드가 기준이다. 이 색인은 2026-11-23 `dev/stabilization`(1da6311) 코드에서 직접 확인했다.

## 1. 작업 → 읽을 MASTER 장

| 하려는 작업 | MASTER.md에서 읽을 장 | 함께 볼 문서 |
| --- | --- | --- |
| 무엇이든 처음 | 1장 개발 원칙 (짧음, 금지 SDK·BigInt·키 커밋 금지) | 이 색인 2~5절 |
| 저장 형식·필드 추가 | 3장 저장과 시간, 14장 "저장되는 상태를 건드리는 기능" | 이 색인 4절 |
| 밸런스·가격·레벨업 조건 | 5장 "레벨업 조건", 40장 경제 재조정, 43장 재료 타이쿤 | [14_개발용임시수치설정.md](../14_개발용임시수치설정.md) (생성 문서) |
| 홈 화면·배치 | 10장 "Workshop 홈", 41·42장 | 24번·26번 문서의 해당 단계만 |
| 굽기(큰 틀·6구) | 10장, 27장, 37장, 42장 | 24번 문서 |
| 손님·판매·대사 | 24장, 30장, 39장 | 21·22번 문서 |
| 재료 타이쿤 | 43·44·45장 | — |
| 꾸미기·아바타 | 7장, 33장, 38장 | 25번 문서(그림 주문)는 그림 작업일 때만 |
| 매일 보상·공유 | 34·35장 | — |
| 로그인·온라인·결제·서버 | 8·9장, 23장, 29장, 31장 | [online_setup.md](online_setup.md) |
| 소리 | 12장 | — |
| 빌드·실행·테스트 | 13장 | 이 색인 5절 |
| 법률·개인정보 | 36장, 32장 | [privacy_policy.md](privacy_policy.md), [play_data_safety.md](play_data_safety.md) |

1~16장 중 클리커/코인·구형 레벨·환생 설명(4~6장 일부)은 **구형 프로토타입 기록**이다. 새 게임 규칙의 근거로 쓰지 않는다. 17~22장과 "직원" 장은 과거 작업 기록이므로 필요할 때만 본다.

대형 기획 문서(25번 약 430KB, 26번 약 420KB, CHECKLIST 약 150KB)도 통째로 읽지 않는다. 단계 번호나 그림 번호로 `grep`해서 해당 부분만 읽는다.

## 2. 두 컨트롤러의 역할

둘 다 `ChangeNotifier`이고 [main.dart](../../../1_app_development/lib/main.dart)에서 **둘 다** 만들어 [GameApp](../../../1_app_development/lib/ui/game_app.dart)에 넘긴다. (MASTER 2장의 "유일한 ChangeNotifier"라는 설명은 예전 기준이다.)

| | [WorkshopController](../../../1_app_development/lib/workshop_controller.dart) | [GameController](../../../1_app_development/lib/game_controller.dart) |
| --- | --- | --- |
| 지금 역할 | **실제 게임**: 굽기·판매·손님·재고·재료·레벨업·미션·도감·매일 보상·꾸미기 착용·구매 요청 | **계정·온라인 기반**: 온라인 연결, 랭킹, 친구·초대, 황금(유료 재화) 잔액·Play 결제, 사용 통계, 소리 설정 등 예전 계정 저장 |
| 저장 | `WorkshopState` → [workshop_storage.dart](../../../1_app_development/lib/workshop_storage.dart) (`part`), schema **14**, SQLite `user_version` 4 | `GameState` → [models.dart](../../../1_app_development/lib/models.dart)·[repository.dart](../../../1_app_development/lib/repository.dart), `formatVersion` **14** |
| 붙은 파일 | `part` 6개: `workshop_storage.dart`(저장), `workshop_controller_level_up.dart`(레벨업), `_commands.dart`(배경·미션·아바타·보상·광고·구매), `_collection.dart`(도감), `_daily.dart`(오늘의 주문서·출석), `_pantry.dart`(재료). 규칙 파일 `workshop_*.dart`, `development_*.dart`, `pantry_*.dart`, `cooking_*.dart` | `part` 6개: invite·boost·online·premium·menu·ranking `_controller.dart` |
| 둘의 연결 | 시험용 빌드 구매는 `LocalTestPurchaseGateway`가 GameController의 황금을 읽고 씀(main.dart) | [owner_account.dart](../../../1_app_development/lib/owner_account.dart)가 둘 다 받음 |

WorkshopController의 part 파일(`workshop_controller_*.dart`)은 `extension ... on WorkshopController`다. 필드·static·`@override`는 extension에 둘 수 없으므로 본체에 둔다. extension 안에서 static은 `WorkshopController.이름`으로 부르고, 화면 갱신은 `notifyListeners()` 대신 본체의 `_notifyChanged()`를 부른다.

**홈 화면 구성 (2026-11-23 28번 C3 이후).** 실제 홈 [ui/workshop_page.dart](../../../1_app_development/lib/ui/workshop_page.dart)는 `NightHome`([ui/night_home.dart](../../../1_app_development/lib/ui/night_home.dart))으로 장면을 그린다. 예전 클리커 홈(`GameHome`)과 `NightHome`의 예전 분기는 지웠으므로 `NightHome`은 새 홈 전용이며 만드는 곳도 `workshop_page.dart` 한 곳이다. 상점 `ShopPanel`·메뉴 `MenuPanel`·꾸미기 `WardrobePanel`·설정 `SoundSettings`는 계정 쪽 GameController(설정·황금 잔액·착용 꾸미기)를 받는다. 이 파일들을 고친 뒤에는 `golden` 태그 테스트를 꼭 돌린다.

예전 클리커의 **로직**(`economy*.dart`, `prestige_*`, `support_*`, `weekly_config.dart`, `achievement_config.dart`)과 GameController는 남아 있고 테스트도 있다. 계정·온라인·결제·저장 형식과 얽혀 있으므로 **지우거나 바꾸기 전에 승인을 받는다.** 랭킹·친구·초대 패널은 지금 새 화면에 연결이 없지만 보존한다(`stage9_ranking_test`가 직접 띄워 검사). 새 게임 랭킹(31번, DEC-153)은 메뉴 '온라인 랭킹'으로 연결돼 있고 출시 스위치 `rankingLaunched`(`lib/ranking_config.dart`)로 연다 — 점수는 서버가 자기 진행 확인 기록에서 읽음(`ranking.ts` `submitWorkshop`). 친구 초대(29번)는 새 홈 메뉴 '친구'로 연결돼 있고 출시 스위치 `inviteLaunched`(`lib/invite_reward_rules.dart`)로 연다 — 규칙 `invite_reward_rules.dart`·서버 `functions/src/invites.ts`, 테스트 `premium_flow_test`·`workshop_shared_ui_test`·`functions/test/invites.test.ts`.

## 3. 기능 → 코드 → 보호 테스트

| 기능 | 주요 코드 (`1_app_development/lib/`) | 지키는 테스트 (`1_app_development/test/`) |
| --- | --- | --- |
| 홈 화면 | `ui/workshop_page.dart`, `ui/workshop_home_layout.dart`, `ui/pixel_sprites.dart` | `workshop_home_layout`, `workshop_home_golden`, `step02_home`, `workshop_touch_area` |
| 스페셜 큰 틀 굽기 | `cooking_session/paint/flip/input.dart`, `cooking_result_rules.dart`, `ui/workshop_mold_stage.dart`, `ui/piping_bag_control.dart`, `ui/flip_circle_control.dart` | `cooking_*`, `flip_circle_control`, `workshop_bench_mold`, `workshop_two_molds` |
| 6구 생산 | `development_griddle.dart`, `development_business.dart`, `development_rules.dart` | `step02_cooking_production`, `development_production`, `workshop_two_molds` |
| 손님·주문·판매 | `workshop_customers.dart`, `workshop_customer_*.dart`, `workshop_arrivals.dart`, `development_orders.dart`, `development_sale_quality.dart`, `development_inventory.dart`, `ui/workshop_counter.dart`, `ui/workshop_guests.dart` | `workshop_customers`, `workshop_arrivals`, `partial_sale`, `customer_*`, `workshop_counter` |
| 재료 타이쿤 | `pantry_rules.dart`, `pantry_home.dart`, `prep_minigames.dart`, `ui/pantry_*.dart`, `ui/prep_minigames.dart` | `pantry_*`, `prep_minigames` |
| 레벨업·미션·해금 | `workshop_missions.dart`, `workshop_feature_unlocks.dart` | `workshop_missions`, `workshop_feature_unlock`, `workshop_progression_simulation` |
| 매일 보상·도감 | `workshop_daily.dart`, `workshop_collection_rules.dart` | `workshop_daily`, `workshop_collection` |
| 구매·서버 요청 | `workshop_purchases.dart`, `workshop_online.dart`, `development_purchase_journal.dart`, `local_test_purchases.dart` | `workshop_purchases`, `workshop_online`, `local_test_purchases`, `development_purchase_journal` |
| 꾸미기·아바타 | `cosmetic_config.dart`, `avatar_*.dart`, `ui/workshop_wardrobe.dart` | `workshop_wardrobe`, `avatar_*`, `hair_hat_rule` |
| 첫 실행·로그인 | `owner_account.dart`, `owner_profile.dart`, `ui/first_run.dart` | `owner_first_run`, `first_run_golden` |
| 저장 | `workshop_storage.dart`, `models.dart`, `repository.dart`, `save_quarantine.dart` | `workshop_storage`, `serialization`, `stage7_regression`(`fixtures/v1_save.json`), `economy_persistence` |
| 설정 생성물 | `config/*.json` → `tools/development_balance.py`, `tools/customer_content.py` | `generated_config_sync` (생성물·서버 복사본 일치) |
| 소리 | `game_audio.dart`, `music_config.dart` | `audio_*`, `step05_audio`, `independent_music` |
| 금지 SDK·키 | `pubspec.yaml`, `android/` | `no_tracking_sdk`, `online_setup` |

## 4. 저장 호환을 지키는 규칙

- 저장 필드를 바꾸면 schema(가게 14, 계정 14)를 올리고 옛 버전 읽기를 유지한다. 순서는 MASTER 14장 "저장되는 상태를 건드리는 기능"의 10번까지 그대로 따른다.
- 가게 schema를 올리면 `workshop_storage.dart`의 구매 보호 schema 목록도 함께 올린다.
- 옛 저장 데이터의 값을 지어내지 않는다. 잘못된 값은 `FormatException`으로 거절한다.
- `test/fixtures/v1_save.json`과 저장 테스트의 기대값은 낮추거나 지우지 않는다.
- 저장 형식은 `test/save_format_test.dart`가 고정한다(가게 schema 16·계정 formatVersion 14의 키·값 종류, 견본 저장 읽기, 옛 가게 형식 schema 12~15 견본 읽기). 형식을 일부러 바꿨을 때만 schema/formatVersion·옛 저장 이전을 고친 뒤 `UPDATE_SAVE_FORMAT=1 flutter test test/save_format_test.dart`로 견본을 다시 쓴다.
- **유료 황금 구매 기록 보호**(`workshop_storage.dart`의 `purchase_guard` 표·구매 보호 schema 목록, 가게 저장의 `purchases`)는 옛 schema 이전 코드라도 지우지 않는다. 결제 복구가 여기에 기대고 있다.

### 출시 시점 저장 규칙 (2026-11-24)

- **출시 전(지금):** 실제 사용자 저장이 없으므로 형식을 바꿀 수 있다. 바꾸면 위 순서대로 schema를 올리고 `save_format_test` 견본을 다시 쓴다. 내부 테스트 기기의 저장도 읽혀야 하므로 옛 버전 읽기는 유지한다.
- **출시 빌드를 만들 때:** 그때의 가게 schema·계정 formatVersion을 "출시 형식"으로 이 절에 적고, 그 견본(`test/fixtures/save_format/`)을 지우지 않는다.
- **출시 후:** 필드를 지우거나 이름을 바꾸지 않는다(새 필드 추가만). 형식을 바꿀 때마다 직전 출시 형식의 견본 저장을 읽는 테스트를 하나씩 더한다. 저장을 다시 시작하게 만드는 초기화(`economyResetSchema` 같은 것)는 출시 후에 쓰지 않는다.

## 5. 실행·테스트 명령

Flutter는 PATH에 없다. 전체 경로를 쓴다: `D:\DevMoved\flutter-sdk\bin\flutter.bat` (Git Bash에서는 `/d/DevMoved/flutter-sdk/bin/flutter.bat`). 명령은 `1_app_development/`에서 실행한다.

| 목적 | 명령 | 걸리는 시간 |
| --- | --- | --- |
| 고친 기능만 빠르게 | `flutter.bat test test/<파일>_test.dart` (3절 표의 테스트) | 수십 초 |
| 느린 것 빼고 전부 | `flutter.bat test --exclude-tags slow` (태그는 `dart_test.yaml`) | 약 6분(2026-11-24 측정: 970개) |
| 기준 이미지 테스트만 | `flutter.bat test --tags golden` | — |
| 전체 | `flutter.bat test` | 약 20분(2026-11-24 측정: 997개 통과·7개 건너뜀. 가장 긴 것은 `workshop_progression_simulation` 약 15분) |
| 정적 분석 | `flutter.bat analyze` | — |
| 설정 생성물 확인 | `python tools/development_balance.py --check`, `python tools/customer_content.py --check` (콘솔이 cp1252면 `PYTHONIOENCODING=utf-8`) | 수 초 |
| 서버 | `firebase/functions/`에서 `npm test` (Node 22) | — |

- **기준 이미지(`test/goldens/`, 62장)는 의도한 화면 변경일 때만, 사용자 확인 뒤에** `--update-goldens`로 다시 만든다. 테스트를 통과시키려고 기준 이미지나 허용치를 바꾸지 않는다.
- 한글 경로 때문에 빌드가 실패하면 MASTER 13장 "한글 경로 문제"를 따른다.

## 6. 새 기능 추가 틀 (2026-11-24)

새 기능은 아래 순서로 만든다. 지금 구조(새 홈 하나, 컨트롤러는 part 파일, 계산은 규칙 파일)가 다시 엉키지 않게 하려는 것이다.

| 순서 | 할 일 | 위치 | 예시(재료 타이쿤) |
| --- | --- | --- | --- |
| 1 | 설정값을 밸런스 설정에 넣는다. 서버도 쓰면 생성 도구로 서버 복사본을 다시 만든다 | `config/development_balance.json` → `python tools/development_balance.py` | `ingredients` 구역 |
| 2 | 계산만 하는 순수 함수와 그 테스트를 먼저 만든다(위젯·컨트롤러·저장 없이) | `lib/<기능>_rules.dart`, `test/<기능>_rules_test.dart` | `pantry_rules.dart`, `pantry_rules_test.dart` |
| 3 | 저장할 상태가 있으면 `WorkshopState`에 필드를 더하고 4절 순서를 따른다 | `workshop_controller.dart`, `workshop_storage.dart`, `save_format_test` 견본 | `pantry`(schema 12) |
| 4 | 명령은 컨트롤러 part 파일의 extension에 둔다. 규칙 함수를 부르기만 한다. 화면 갱신은 `_notifyChanged()` | `lib/workshop_controller_<기능>.dart` | `workshop_controller_pantry.dart` |
| 5 | 화면은 별도 위젯 파일로 만들고 `workshop_page.dart`에는 연결 한두 줄만 더한다 | `lib/ui/<기능>_*.dart` | `ui/pantry_window.dart`, `ui/pantry_shop.dart` |
| 6 | 화면 테스트는 `setUpAccount` + 새 홈(`GameApp(controller:, workshop:)`)으로 쓴다. 기준 이미지가 필요하면 `golden` 태그 | `test/<기능>_*_test.dart` | `pantry_window_test.dart` |
| 7 | 이 색인의 3절(기능 → 코드 → 테스트)과 MASTER 해당 장을 고친다 | 이 파일, `MASTER.md` | 43~45장 |

- 계정 쪽(GameController)에 새 상태를 넣지 않는다. 계정 쪽은 로그인·온라인·결제·설정·꾸미기 보유만 맡는다.
- 유료 화폐(황금)를 주거나 쓰는 기능은 서버 함수와 서버 테스트(`firebase/functions/test/`)를 함께 만든다.
- 자주 바뀌는 파일(CLAUDE.md "지킬 것" 목록)은 한 번에 한 작업만 고친다.

