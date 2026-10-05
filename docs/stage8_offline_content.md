# 8단계 — "모의 기능"을 자체 게임 콘텐츠로 교체

작성: 2026-10-05. 실행 환경: Windows 11, Flutter `C:\flutter-sdk`, 프로젝트를 `B:`로 subst 매핑, release 빌드는 `GRADLE_USER_HOME=C:\GradleCache`.
시작 기준: 커밋 `b63fafa stage7: fix known bugs`(테스트 182개).

## 승인된 설계와 결정

구현 전에 항목별 설계표(바뀌는 규칙, 저장 마이그레이션, 기존 진행도 처리)를 제시해 승인받았다. 추가로 받은 결정은 아래와 같다.

- Lv.9 대체 조건: 처음 승인한 안은 최종 자동 스킬(auto_16) 1단계였다. 구현 전에 수치를 확인해 보니 auto_16은 가격·해금 2경, 효과 초당 1000조로 Lv.10(초당 20조)보다 약 1000배 늦은 지점이었다. 이 문제를 보고하고 다시 확인받아 **은하 공방(auto_11) 1단계 보유**로 바꿨다.
- 기존 '완주 기록' 교환 저장: Lv.10 업적과 칭호로 이전하고, 그때 쓴 **코인은 환불하지 않는다**.

## 범위

| # | 바뀐 규칙 | 저장(v6→v7) | 기존 진행도 |
|---|---|---|---|
| 1 레벨 미션 | 새 시즌 `offline-v1`(`mission_config.dart`). 바뀐 조건은 Lv.5 기본 외 꾸미기 1개, Lv.7 아이템 누적 사용 5회, Lv.9 auto_11 1단계, Lv.10 업적 12개. 생산·초당 목표와 레벨 보상은 이전과 같다. 미션 카드에 해당 화면으로 가는 바로가기를 넣었다 | v7 이전 저장은 `MissionState.migrateToCurrentSeason()`으로 옮긴다. 세대, 활성 시각, 버터 사용 수, 초대 기록은 유지한다. 옛 시즌 정의는 옛 저장 로드와 디버그 초대 테스트를 위해 남겼다 | 진행 중인 단계의 초대 조건을 이미 채웠으면 그 대체 조건을 `waivedGoals`로 완료 처리한다. 덜 채웠으면 새 조건을 처음부터 진행한다. 받은 레벨 보상은 그대로다 |
| 2 공유 | 배포 빌드의 홈 메뉴 '공유'는 OS 공유 창 또는 복사만 제공한다. 내용은 소개 문구와 `invite_config.storeUrl`이고 보상은 없다. 초대 시뮬레이터·추천 코드·개발자 도구는 `GameController.developerTools`(기본값 `!kReleaseMode`)일 때만 공유 화면에서 연다. `canSimulateInvites`도 이 플래그를 확인한다 | `invites` 필드는 그대로 보존한다 | 이미 받은 초대 보상은 유지되고 새로 받을 수는 없다 |
| 3 내 기록 | `ranking.dart`(가상 20명)를 삭제했다. 최고 초당 생산(아이템 제외), 누적 생산·굽기, 플레이 일수, 최고 콤보, 레벨 도달 시각을 보여 준다. 오늘과 지난 최고를 비교해 신기록을 표시한다. 콤보는 직접 탭 간격 1초 이내일 때만 이어지고 길게 누르기는 제외하며 생산 효과는 없다. 홈에는 5콤보부터 표시한다 | 새 `records` 필드. 하루가 바뀌는 처리는 기존 `observeSupport` 한 곳에서 한다 | 최고 초당 = max(현재 초당 생산, 저장된 초당 생산, 오늘 최고)로 정한다. 플레이 일수는 원장 `daily:날짜` 고유 날짜 수 + 오늘이다. 누적 굽기는 오늘 탭 수부터 센다. 콤보와 하루 최고 생산은 "기록 없음"에서 시작하고 지어낸 값은 넣지 않는다. 레벨 도달 시각은 보상 수령 시각을 쓰고, 이전 버전 기록은 "시각 없음"으로 표시한다 |
| 4 주간 도전 | `event_config.dart`(2026-11-01 종료 고정 시즌, 가상 참여자, 선착순 재고)를 삭제했다. 매주 월요일 00:00 KST에 시작해 끝나면 다음 주가 자동으로 시작된다. 목표 4개(탭 1,000, 접속 3일, 스킬 20개 구매, 일일 전체 완료 3회)는 각각 한 번 수령한다(`weekly_config.dart`). 계절 테마는 KST 월에 따라 제목·문구만 바꾼다 | 새 `weekly` 필드. 원장 ID는 `weekly:<주 시작일>:<목표>`. v6 `events`는 읽고 버린다 | 받은 이벤트 코인·아이템은 원장·재고에 남는다. 받지 않은 모의 단계 보상은 사라진다 |
| 5 업적·도감 | 최종 교환(`FinalExchangePanel`, `exchangeFinalReward`)을 삭제했다. 업적 20개, 보상은 코인 1~5개 또는 칭호 5종(`achievement_config.dart`). 칭호 하나를 홈과 내 기록에 표시한다. 도감은 꾸미기 11종 보유 여부와 칭호 수집 현황을 보여 준다 | 새 `achievements` 필드(`claimed`, `equippedTitle`). 원장 ID는 `achievement:<id>`. 원장 없는 수령 기록이나 보유하지 않은 칭호는 손상으로 거부한다 | `final:prototype-v1` 원장이 있으면 `level-10` 업적을 수령 완료로 하고 0코인 원장 기록을 추가한다(칭호 '골목 명장', 환불 없음). 일일 전체 완료 횟수와 주간 완주 횟수는 원장에서 센다 |
| 6 문구 | 배포 화면에서 '모의', '실제 지급 없음', '예시', '가상', '추정', 'estimated', 미션 시즌 ID, 공개 후기 근거 문구를 정리했다. 내 기록에는 "이 기기 기록, 다른 사람과 비교하지 않음"을 명시했다. 디버그 전용 초대 화면의 '모의' 표기는 사실이므로 그대로 두었다 | — | — |
| 7 문서 | 개인정보처리방침, 데이터 보안 문서, README, 차이분석 문서 머리 안내를 갱신했다 | — | — |

저장 JSON은 **v7**이다(`GameState.formatVersion`). 탭, 콤보, 접속일 기록은 메모리에서만 바뀌고 10초 주기 저장이나 중요 명령 저장에 포함된다. 탭마다 DB에 쓰지 않는 것은 테스트로 확인했다.
새로 만든 게임은 생성한 날을 첫 접속일로 기록한다. 그래서 첫 `tick`에서 상태가 바뀌지 않는다.

## 변경 파일

- 새 lib 파일: `weekly_config.dart`, `achievement_config.dart`, `progress_state.dart`, `progress_rules.dart`, `ui/progress_panels.dart`
- 삭제한 lib 파일: `event_config.dart`, `ranking.dart`
- 수정한 lib 파일: `mission_config.dart`, `mission_state.dart`, `missions.dart`, `models.dart`, `game_controller.dart`, `invite_controller.dart`, `invite_config.dart`, `invite_sharing.dart`, `menu_controller.dart`, `menu_rules.dart`, `menu_state.dart`, `support_config.dart`, `support_rules.dart`, `home_presentation.dart`, `config_values.dart`, `ui/game_app.dart`, `ui/night_home.dart`, `ui/level_missions.dart`, `ui/public_menus.dart`, `ui/support_panels.dart`, `ui/invite_panel.dart`, `ui/bake_target.dart`
- 새 테스트: `test/stage8_progress_test.dart`, `test/stage8_widget_test.dart`
- 문서: `README.md`, `docs/privacy_policy.md`, `docs/play_data_safety.md`, `오늘의붕어빵_차이분석_260929_0146_01.md`(머리 안내 한 줄), 이 문서
- 도구: `tools/preview_home_test.dart`(새 메뉴 키)

### 기존 테스트 변경과 이유

기대값을 낮춘 곳은 없다. 기능을 삭제·교체해 대상이 사라진 경우만 아래처럼 바꿨다.

| 파일 | 변경 | 이유 |
|---|---|---|
| `level_missions_test.dart` | `atLevel`과 `levels`를 옛 초대 시즌으로 고정했다. 기대값은 그대로다 | 기본 시즌에 초대 조건이 없어졌다. 디버그용으로 남긴 초대 시즌을 같은 기대값으로 계속 검증한다 |
| `economy_simulation_test.dart` | 두 시뮬레이션의 시작 상태를 옛 초대 시즌으로 고정했다. 기대값은 그대로다 | 같은 이유. 새 시즌 시뮬레이션은 `stage8_progress_test.dart`에 추가했다 |
| `home_presentation_test.dart`, `invite_widget_test.dart`, `level_missions_widget_test.dart`, `invite_system_test.dart`(일부) | `MissionState.forLevel(..., seasonId: legacyInviteMissionSeason)`를 명시했다 | 같은 이유 |
| `invite_widget_test.dart`, `level_missions_widget_test.dart` | 홈 '친구 초대' 대신 '공유 → 개발자 도구'로 진입한다 | 홈 초대 메뉴를 공유로 바꿨다 |
| `invite_system_test.dart` v4 마이그레이션 | 미션 기록 비교에서 `seasonId`만 새 시즌으로 기대한다 | v7 이전 저장은 시즌을 옮기는 것이 설계다. 나머지 필드는 그대로 비교한다 |
| `level_missions_widget_test.dart` Lv.10 | '모의 데이터' 안내 대신 '개발자 도구' 안내를 확인한다 | 요구 6으로 배너를 삭제했다 |
| `public_menus_test.dart` | 가상 랭킹 1개, 고정 시즌 이벤트 5개 테스트를 삭제했다. v5 마이그레이션 테스트의 이벤트 확인은 업적 빈 상태 확인으로 바꿨다 | 기능 삭제. 대체 기능 테스트는 stage8 파일에 있다 |
| `public_menus_widget_test.dart` | 랭킹 단계는 내 기록 단계로, 고정 이벤트 단계는 주간 도전 수령 단계로 바꿨다(3×3 조합) | 기능 교체 |
| `support_system_test.dart` | 최종 교환 테스트를 Lv.10 업적 테스트로 바꿨다(조건, 1회, 칭호, 재시작 후 중복 금지). 롤백 테스트의 교환 항목은 업적 수령으로 바꿨다 | 기능 교체. 같은 성질을 검증한다 |
| `support_widget_test.dart` | 마지막 단계를 모의 교환에서 업적 수령과 칭호 장착으로 바꿨다. '추정 효과' 문구 확인은 '초 동안 적용' 확인으로 바꿨다 | 기능 교체, 문구 정리 |
| `widget_test.dart` | 메뉴 목록과 이벤트 화면 확인 대상(주간 카운트다운)을 바꿨다. `mountGame`에 `developerTools` 선택 인자를 추가했다 | 메뉴 교체. 인자 추가만 했고 기존 동작은 그대로다 |
| `stage7_regression_test.dart` | (a)는 "v6 이벤트 항목이 어떤 상태든 v7로 진행도 보존 로드"로 바꿨다. 이벤트 값이 맵이 아닐 때 이제는 거부하지 않는다. (i)의 랭킹 캐시 단언은 삭제했다 | 이벤트 저장 필드와 랭킹이 삭제됐다 |
| `stage7_widget_test.dart` | (f)(h)를 주간 도전 카드·화면 기준으로 바꿨다. 카운트다운 기대 문자열은 그대로다 | 고정 이벤트 삭제 |
| 홈 골든 3개 | 다시 만들었다. 허용 오차는 바꾸지 않았다 | 메뉴(내 기록·공유·업적)와 주간 카드가 바뀌었다. 360 폭 이미지를 직접 확인했다: 헤더의 '오늘의 붕어빵' 제목이 두 줄로 바뀌는 것 외에 겹침이나 잘림이 없다 |

## 실제 실행한 검증

모든 명령은 `B:\`에서 실행했다.

- `dart format --set-exit-if-changed lib test`: 변경 0개, exit 0
- `flutter analyze`: No issues found
- `flutter test`: **217개 전부 통과, skip 0**. 7단계 182개 기준으로 삭제 7개(랭킹 1, 고정 이벤트 5, 랭킹 캐시 1), 추가 42개(`stage8_progress_test` 28, `stage8_widget_test` 14)다. 182 − 7 + 42 = 217. release 병합 매니페스트 검사는 아래 빌드 산출물로 실제 실행됐다.
- 저장 마이그레이션: v1(기존 fixture), v2~v6(각 버전 형태로 만든 JSON)을 v7로 로드해 재화·누적·레벨·스킬·코인·아이템·꾸미기·원장 보존을 확인했다. 다시 저장·로드해도 결과가 같고(멱등), 컨트롤러로 이어서 플레이·저장되는 것도 확인했다. 초대 조건 인정, 미달 처리, 완주 기록 이전(환불 없음), 접속일 복원도 각각 테스트했다.
- 새 시즌 시뮬레이션(2회/초 클릭, 효율 구매, 활성 조건만 행동): **Lv.10 도달 3,254초**, 그 시점 달성 업적 13개, 남은 코인 28개. 같은 정책의 옛 초대 시즌은 4,130초다. 이 값은 테스트 정책의 결과이며 사람의 완료 시간을 약속하지 않는다.
- 배포 모드(`developerTools: false`) 위젯 테스트: 360x800/390x844/412x915 × 글자 1/1.5/2배 9개 조합에서 홈·일일·업적(목록·도감)·상점·꾸미기·내 기록·공유·주간 도전·레벨 미션을 열었다. overflow 예외가 없고, 화면 텍스트에 '모의/실제 지급/예시/가상/추정/estimated'가 없으며, 개발자 초대 진입점도 없음을 확인했다. 디버그 모드에서 개발자 도구로 진입할 수 있는 것도 확인했다.
- 공유: 플랫폼 채널 모의로 공유 호출이 일어나고 코인·아이템·초대 상태가 바뀌지 않는 것을 확인했다.
- 탭 200회 동안 저장소 저장 횟수가 변하지 않았다(탭당 DB 저장 없음).
- `flutter build apk --release`(`GRADLE_USER_HOME=C:\GradleCache`): 성공, `app-release.apk` 48.3MB(50,696,143 bytes). 배포 모드 분기를 포함한 최종 코드로 다시 빌드했다.
- 한글 폰트 미리보기(`tools/preview_home_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf`): 홈, 내 기록, 업적, 주간 도전, 공유 등 12개 화면 이미지를 `build/preview/`에 만들어 직접 확인했다. 주간 보상 표시의 "코인 0개"가 어색해 0코인은 생략하도록 고쳤다.

## 실행하지 못한 검증

- 실제 SQLite에서 v6→v7 마이그레이션을 실행하지 않았다(메모리/JSON 저장소로만 검증). 기기·에뮬레이터에서 기존 설치를 업데이트하는 시험도 하지 않았다.
- release APK를 기기나 에뮬레이터에 설치해 배포 모드 화면을 확인하지 않았다. 배포 모드 UI는 `developerTools: false` 주입으로 위젯 테스트에서만 확인했다. 실제 `kReleaseMode` 분기는 release 빌드 컴파일 성공까지만 확인했다.
- 스토어 링크 `storeUrl`은 앱이 그 applicationId로 게시되기 전에는 열리지 않는다. 실제로 열리는지는 확인하지 않았다.
- Android 공유 창의 실제 동작(받는 앱 선택)은 확인하지 않았다(채널 모의만).
- 실제 날짜를 넘기는 장기 플레이(주간 전환, 30일 업적)는 가짜 시계 테스트로만 검증했다.
- iOS 빌드는 하지 않았다.

## 잔여 위험

- **기기 시계 조작**: 서버가 없어 시계를 앞으로 돌리면 접속일·주간 도전을 앞당길 수 있다. 시계를 되돌려도 지난 날·주가 다시 열리지 않는 것만 보장한다.
- **Lv.10 업적 12개 조건**: 새 시즌 시뮬레이션(2회/초 클릭, 효율 구매, 아이템 사용·업적 수령)으로는 달성했다. 실제 사람의 플레이 속도와 코인 여유는 확인하지 않았다. 너무 어렵거나 쉬우면 `mission_config.dart`에서 조정한다.
- **업적 판정 비용**: 홈의 Lv.10 진행률은 매 rebuild마다 업적 20개를 판정한다. 원장을 훑는 집계는 원장 크기로 캐시하지만, 그 밖의 계산(꾸미기 수 등)은 매번 다시 한다. 저사양 기기 프레임 시간은 측정하지 않았다.
- **이전 저장의 받지 않은 이벤트 보상**: v6 모의 시즌에서 받지 않은 단계 보상은 사라진다(승인된 설계).
- 디버그 전용 초대 코드는 그대로 남아 있다. 배포 빌드에서는 UI와 명령(`canSimulateInvites`) 양쪽에서 막지만, `MockInvitationRepository` 객체는 배포 빌드에서도 만들어진다(네트워크·저장 부작용은 없다).
- 개인정보처리방침 연락처는 사용자 요청으로 dlthdl321@gmail.com을 넣었다(공개 문서라 이메일이 공개된다). 공개 URL 게시는 아직 하지 않았다. 시행일은 같은 날짜(2026-10-05)로 두었다.
- release 서명은 여전히 debug 키다.
