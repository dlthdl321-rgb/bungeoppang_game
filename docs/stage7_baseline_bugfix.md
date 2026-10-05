# 7단계 — Git 기준점과 알려진 버그 수정

작성: 2026-10-05. 실행 환경: Windows 11, Flutter `C:\flutter-sdk`, 프로젝트를 `B:`로 subst 매핑, release 빌드는 `GRADLE_USER_HOME=C:\GradleCache`.

## 범위

### 1. Git 기준점

- `.gitignore`에 `*.apk`, `test/failures/`, `android/.gradle/`, `android/.kotlin/`, `android/local.properties`를 추가했다. `*.log`는 이미 있어서 중복으로 넣지 않았다.
- 루트 debug APK: 사용자 결정에 따라 `오늘의붕어빵_APK_260928_2228_01.apk`만 삭제하고 `_260929_0146_02.apk`는 남겼다(git에서는 제외됨).
- 이 폴더는 자체 저장소가 없었고, 상위 `Desktop/Git` 저장소에서는 추적되지 않는 상태였다. 사용자 결정에 따라 이 폴더에서 `git init -b main`을 실행했다. 이 저장소에만 `core.autocrlf=false`와 작성자 `Soi Lee <dlthdl321@gmail.com>`를 설정했다.
- 기준점 커밋은 `f0b15ab baseline: stage6 complete`이고 파일은 136개다. 커밋 직전에 실행한 검증은 format 변경 0개, analyze 0건, 테스트 151개 통과다.

### 2. 버그 수정 (재현 테스트 → 수정)

| # | 문제 | 수정 | 재현 테스트 (수정 전 결과) |
|---|---|---|---|
| a | v6 저장에 `eventDefinitions`의 모든 이벤트 항목이 있어야 로드됨 | 없는 이벤트 항목이나 `events` 필드가 통째로 없으면 `LocalEventState.initial`로 채운다. `events`가 맵이 아니면 계속 손상으로 거부한다 | 수정 전에는 `FormatException: 초대 저장 구조 손상`으로 로드 실패 |
| b | `ownedSkins`를 `{'redbean','custard','cocoa'}`로 하드코딩 필터링 | 카탈로그의 fish 슬롯 ID로 거른다. 테스트에서 미래 카탈로그를 넣을 수 있도록 `GameState.fromJson(..., cosmetics:)` 매개변수를 추가했다(기본값은 현재 카탈로그) | 새 fish 외형을 장착한 저장 → 수정 전 `장착 외형을 보유하지 않음` |
| c | 복구 화면의 두 버튼이 저장만 바꾸고 화면은 그대로이며 피드백도 없음. 게다가 `recover()`→`save()` 경로는 백업 시퀀스가 손상된 현재 행보다 낮아 **저장소가 조용히 무시**함 | `GameRepository.restoreBackup()`을 추가했다. SQLite는 트랜잭션 안에서 백업을 손상된 행보다 높은 시퀀스로 current에 올린다. 컨트롤러의 `restoreBackupAndStart`/`resetAndStart`는 성공 시 `initialize` 후 `null`, 실패 시 이유를 반환한다. `RecoveryApp`은 상태를 가지며, 성공하면 `GameApp`으로 전환하고 실패하면 `recovery-message`를 표시한다. 진행 중에는 버튼을 비활성화하고, 초기화 전에는 확인 대화상자를 띄운다 | 수정 전에는 전환 없음, 메시지 없음 |
| d | `updateSettings`·`finishTutorial`이 `busy`를 확인하지 않음 | `_untilIdle()`로 진행 중인 commit이 끝난 뒤 변경하고 저장한다 | 수정 전: commit 도중 바꾼 설정이 저장소에 없음, 롤백 시 설정/튜토리얼 완료가 사라짐 |
| e | fish 꾸미기 구매가 `cosmeticUnlocked`(누적 생산) 검사를 건너뜀 | 모든 슬롯이 같은 경로에서 해금을 검사한다. fish는 기존 원장 ID `skin:<id>`를 유지한다. `buyOrEquip(SkinDefinition)`은 같은 명령으로 위임한다(코인 상점 화면 경로도 동일 검사). 테스트용으로 `GameController(cosmetics:)`를 주입할 수 있다 | 누적 생산 조건이 있는 fish → 수정 전에는 검사 없이 `skins.firstWhere`에서 `Bad state: No element` 예외 |
| f | 홈 카드는 `eventDefinitions.first`, `EventPanel`은 `currentEventId` 사용 | `event_config.dart`의 `currentEvent` 하나로 통일했다 | **수정 전에도 통과**: 현재 설정에서는 둘이 같은 이벤트라 실패로 재현할 수 없었다. 불일치를 막는 회귀 테스트로 남겼다 |
| g | 옷장 미리보기 속 색상이 `Colors.brown`으로 고정 | 속 색상은 `FishPainter.filling`이 `skin`에서 계산한다(유일한 위치). `BakeTarget`과 옷장이 같은 값을 쓴다 | 수정 전 미리보기는 갈색, 홈(슈크림)은 다른 색 |
| h | 홈 카운트다운은 초 올림, 이벤트 화면은 `Duration` 내림이라 표시가 다름 | `home_presentation.dart`의 `countdownLabel`/`eventCountdownLabel` 하나만 사용한다. 쓰지 않던 `HomeEventDefinition`(`rewardNotice`, `exampleCapacity`, `countdown(TimeService)`)과 `homeEvent`는 삭제했다 | 종료 1일 2분 0.5초 전: 홈은 `1일 00:02:01`, 화면은 `1일 0시간 2분` |
| i | 초당 10회 rebuild마다 설정 문자열을 `BigInt.parse`하고 랭킹을 다시 정렬 | `config_values.dart`의 `configBigInt`/`configUtc`가 값마다 한 번만 파싱한다. 꾸미기·이벤트 정의에 `*Amount` 접근자를 추가하고 `menu_rules`·`menu_state`·`public_menus`에 적용했다. 랭킹은 가상 점수를 한 번 파싱·정렬해 두고 내 점수만 삽입하며, 같은 누적 생산이면 직전 결과(수정 불가 리스트)를 그대로 반환한다 | 수정 전에는 `identical(d.cost, d.cost)`와 같은 입력의 `rankingFor` 결과가 모두 false |
| j | SDK 검사 테스트가 소스 매니페스트만 확인 | release 병합 매니페스트(`merged_manifests/release/processReleaseManifest`, `merged_manifest/release/processReleaseMainManifest`)에서 INTERNET·ACCESS_NETWORK_STATE·AD_ID·ADSERVICES·BILLING·gms·firebase를 검사한다. 산출물이 없거나 manifest/gradle/pubspec.lock보다 오래됐으면 이유와 재빌드 명령을 skip 메시지로 남긴다. 검사 함수 자체는 가짜 매니페스트로 검증한다 | 금지 항목이 실제로 없어 수정 전 실패를 재현할 대상은 없다. 대신 검사 함수가 금지 항목을 찾아내는지 합성 매니페스트로 확인했다 |

저장 JSON 구조는 바꾸지 않았다(formatVersion 6 유지, 마이그레이션 추가 없음). 이번 변경은 같은 v6 구조를 더 관대하게 읽을 뿐이다. v1~v5 마이그레이션 테스트는 수정 없이 통과한다. 밸런스 수치는 변경하지 않았다.

### 화면 표시 변경 (게임 규칙·보상 변경 없음)

- 이벤트 화면 카운트다운 형식이 `종료까지 N일 H시간 M분`에서 홈과 같은 `종료까지 N일 HH:MM:SS`로 바뀌었다. 시작 전에는 기존 화면의 `시작까지 …` 대신 홈과 같은 `이벤트 시작 전`을 표시한다. 현재 고정 시즌(2026-09-01~11-01)에서는 시작 전 상태가 나타나지 않는다.
- 복구 화면의 "새로 시작"에 확인 대화상자를 추가했다. 설정 화면의 초기화와 같은 방식이다.

## 변경 파일

- 수정한 lib 파일: `models.dart`, `game_controller.dart`, `menu_controller.dart`, `repository.dart`, `cosmetic_config.dart`, `event_config.dart`, `menu_rules.dart`, `menu_state.dart`, `ranking.dart`, `home_presentation.dart`, `ui/game_app.dart`, `ui/night_home.dart`, `ui/public_menus.dart`, `ui/fish_painter.dart`, `ui/bake_target.dart`
- 새 lib 파일: `config_values.dart`
- 새 테스트: `test/stage7_regression_test.dart`(13개), `test/stage7_widget_test.dart`(16개: 복구 4개, 복구 화면 3×3 overflow 9개, f/g/h 3개)
- 수정한 테스트(약화 없음):
  - `test/home_presentation_test.dart`: 삭제한 `HomeEventDefinition` 대신 `countdownLabel`을 호출한다. 기대 문자열 5개는 그대로다.
  - `test/economy_persistence_test.dart`: 테스트용 `JsonRepository`에 새 인터페이스 메서드 `restoreBackup`을 구현했다. 단언은 바꾸지 않았다.
  - `test/no_tracking_sdk_test.dart`: 테스트 2개를 추가했고 기존 3개는 그대로다.
- 골든 파일 변경 없음. 기존 홈 골든 3개는 변경 없이 통과했다.
- `.gitignore`, 이 문서, `README.md`(복구 동작 한 줄)

## 실제 실행한 검증

모두 `B:\`에서 실행했다.

- 수정 전 재현 테스트 실행 결과: 위 표 중 f를 제외한 a·b·c·d·e·g·h·i 재현 테스트가 기대한 이유로 실패했다. 회귀 보호용 테스트(b의 왕복 저장·비 fish 제외, a의 비맵 거부, f)는 수정 전에도 통과했다. 실행 초기에 e 보호 테스트가 레벨·미션 불일치라는 테스트 준비 실수로 실패해, 준비 코드를 고친 뒤 다시 실행했다.
- `dart format --set-exit-if-changed lib test`: 변경 0개, exit 0
- `flutter analyze`: No issues found
- `flutter test`: **182개 전부 통과**(기존 151 + 신규 31), skip 0개. release 매니페스트 테스트는 아래 빌드 산출물로 실제 실행됐다.
- `flutter build apk --release`: 성공, `build/app/outputs/flutter-apk/app-release.apk` 49.1MB(51,531,611 bytes). 서명은 템플릿의 debug 키다. 첫 시도는 기본 Gradle 홈(한글 사용자 경로)에서 Gradle 에이전트 JAR 경로 오류로 실패했고, `GRADLE_USER_HOME=C:\GradleCache`로 다시 실행해 성공했다.
- release 병합 매니페스트를 직접 확인했다. INTERNET, AD_ID, BILLING, gms, firebase가 없다. 앱 자체 `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`과 share_plus·profileinstaller 컴포넌트만 있다.
- overflow: 360x800 / 390x844 / 412x915 × 1 / 1.5 / 2배. 기존 홈·패널 테스트(옷장·랭킹·이벤트 화면 포함)와 신규 복구 화면 9개 조합에서 `takeException()`이 null이었다.

## 실행하지 못한 검증

- `SqliteGameRepository.restoreBackup`을 실제 SQLite에서 실행하지 않았다. 프로젝트에 `sqflite_common_ffi`가 없어 위젯/단위 테스트는 메모리 저장소로만 검증했다. 기기나 에뮬레이터에서 손상 행을 만들어 복구하는 시험은 하지 않았다.
- release APK를 에뮬레이터나 실기기에 설치·실행하지 않았다.
- f(현재 이벤트 통일)와 j(release 매니페스트)는 현재 설정·산출물에 결함이 없어 "수정 전 실패"를 재현하지 못했다.
- iOS 빌드는 하지 않았다(Windows 환경).
- 장시간 FPS·메모리 측정을 하지 않았다. i의 개선 효과는 객체 동일성 테스트로만 확인했고 프레임 시간은 측정하지 않았다.

## 잔여 위험

- `restoreBackup`은 손상된 current 행을 덮어쓴다. 손상 원본은 보존되지 않아 사후 분석이 불가능하다. 백업도 손상이면 초기화 외에는 방법이 없다.
- `main.dart`는 `initialize`의 모든 예외(DB 열기 실패 등 일시 오류 포함)를 복구 화면으로 보낸다. 일시 오류에서 사용자가 "새로 시작"을 누르면 데이터를 잃을 수 있다. 확인 대화상자가 있지만 "다시 시도" 버튼은 없다.
- release 매니페스트 테스트는 로컬 빌드 산출물이 있을 때만 실행되고 CI에서는 skip된다. mtime으로 오래된 산출물은 걸러내지만, Gradle 플러그인 버전 변경 같은 다른 원인은 감지하지 못한다.
- release 서명이 debug 키다. Play 업로드 전에 업로드 키와 서명 설정이 필요하다.
- `support_panels.dart`, `level_missions.dart`, `support_rules.dart`, `mission_config.dart`에는 여전히 rebuild마다 `BigInt.parse`가 남아 있다(i의 범위는 `public_menus` 경로였다).
- `rankingFor` 캐시와 `configBigInt` 캐시는 전역이다. 키가 const 설정 문자열과 마지막 누적 생산값이라 크기는 한정적이다.
- 테스트용 카탈로그 주입 지점(`GameState.fromJson(cosmetics:)`, `GameController(cosmetics:)`)은 공개 API다. 운영 코드는 기본값만 쓴다.
