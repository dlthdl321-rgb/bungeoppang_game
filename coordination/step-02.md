# 2단계 인계: 제작 미니게임·독립 6구

- 담당: 직원2 / 2026-10-18 KST
- 기준 커밋: `9108513a89e83d4dd8f6c0772f6554c844d1e8a0`
- 브랜치: `employee2/cooking-production`
- worktree: `C:/Users/이소이/Desktop/Git/bungeoppang-step-02`
- 대상: P1-004, P4-001~P4-004, P5-001~P5-002. **로컬 구현·검증 인계이며 Android 실기기 완료 판정이 아니다.**

## 기준과 보존

CHECKLIST.md·진행현황.md·tasks.json, 00_결정취합.md·02_제작숙련6구_결정안.md·MASTER.md, 실제 Workshop/제작/6구/입력/UI/기존 테스트를 대조했다. 저장소 CLAUDE.md가 지정한 MASTER.md를 따랐고 적용 AGENTS.md는 발견하지 못했다. 원본 작업 폴더의 수정된 결정취합 문서도 읽었으며 그 변경·미추적 android/build/firebase/ios는 이동·삭제·커밋하지 않았다.

확정 결정은 후속 사용자 답변을 우선했다. 특히 오래된 02번 추천의 '덜 익음 수확 불가'를 적용하지 않고 **덜 익음도 수확 가능**을 유지했다. 보유 AND 숙련 후보(팥 포함), 5단계, 두 반죽·오입력·익힘의 손기술 AND, 연습/주문 진행 구분, 직접 수확·탄 칸 직접 폐기, 앱 이탈/큰 틀/가려진 6구 정지와 복원도 유지했다. 설정 수치·초기 맛 목록은 바꾸지 않았다.

## 완료한 보완과 기존 구현 확인

| ID | 이번 변경·검증 |
| --- | --- |
| P1-004 | 센서 명령 생성기를 순수 모듈로 분리. 보정·중립 복귀·단계 변경·입력 취소/대체를 로컬 검증. 센서 토글 비동기 경합에 generation 확인 추가. Android 하드웨어 검수는 남음. |
| P4-001 | 기존 연습/주문 진입·단일 세션·취소·순서·토큰 검증을 유지하고 전용 controller 테스트로 확인. 보유하지만 미숙련인 팥 주문 제작 진입 가능. |
| P4-002 | 터치로 단계가 바뀌어도 이전 센서 기울기를 다음 반죽/속 입력으로 넘기지 않음. 반죽 영역 이탈·최초 포인터 취소·차단은 미완료 입력 취소. 둘째 포인터 취소가 첫 입력을 취소하지 않음. |
| P4-003 | 기존 방향 순서·오입력·닫기/뒤집기 지연·터치 대체 유지. 스킵/늦은 입력/지연 전 입력을 테스트. 숟가락·젓가락의 별도 회전/스와이프 연출은 이번에 새로 구현하지 않음. |
| P4-004 | 모든 익힘 경계의 직전/진입 ms, 결과 고정·주문과 연습 분리 검증. 같은 프로세스에서 저장 실패 후 reloadAfterError로 재시도해도 최초 꺼내기 익힘을 유지. 완료/보관 중복 인정 차단. |
| P5-001 | 기존 6칸·보유/숙련 후보·칸별 시작 시각/속도/경과·복원 유지. 시차 투입과 독립 경과, 꺼내기 전 제품 미생성 검증. |
| P5-002 | 표시 회차를 expectedCycle로 전달. 과거 회차 터치가 새 제품을 수확하지 않음. 실패 수확의 익힘/제작일을 메모리에 고정하고 해당 칸에만 재적용. 다른 5칸의 경과를 이전 snapshot으로 되돌리지 않음. 빈 칸 중복 수확·탄 칸 제품0 검증. |

## 변경 파일과 충돌 주의

- 신규 `1_app_development/lib/cooking_sensor_input.dart`: 하드웨어와 무관한 센서→CookingSession 명령 변환. reset(보정 포함 초기화), interrupt(현재 보정 유지·미완료 입력 해제), sample 인터페이스.
- `lib/cooking_input.dart`: 최초 입력 포인터 확인용 ownsPointer 한 메서드.
- `lib/ui/cooking_session_controls.dart`: 최초 포인터의 영역 이탈/취소 처리.
- `lib/ui/workshop_page.dart`: 센서 모듈 연결·구독 토글 경합 방지·일시정지 차단·표시 회차 캡처. 6구 가능 여부는 controller의 주입 시계 c.now() 사용.
- `lib/development_griddle.dart`: harvest의 optional expectedCycle, 고정 결과를 해당 칸에 적용하는 applyHarvest.
- **공통 `lib/workshop_controller.dart`**: cookingCommand의 실패 시도 고정/성공 후 해제, harvestCell의 회차 검증/고정 수확 재시도, 읽기 getter 두 개만 추가. 기존 command·원자 저장·수명주기·시간 집계는 변경하지 않음.
- 신규 `test/step02_controller_test.dart`, `test/step02_cooking_production_test.dart`, 기존 `test/cooking_controls_test.dart`에 담당 회귀 검사 추가.
- MASTER.md에 이번 범위만 추가. tasks.json·CHECKLIST.md·진행현황.md는 수정하지 않음. main·모델·저장 스키마·의존성·Android Kotlin은 수정하지 않음.

## 요청/결과 연결 계약

1. 진입은 기존 `startPractice()` 또는 `startOrderProduction(orderId, flavor)`를 사용한다. 주문 본체가 활성 주문/미판매 잔량을 관리하고, 제작 진입 검증의 변경은 주문 담당이 연결한다.
2. UI 입력은 현재 불변 CookingSession에서 만든 후속 상태만 cookingCommand에 전달한다. 센서/터치 모두 동일 토큰·단일 후속 검사 경로를 거친다. phaseMs는 controller의 활성 시간만 누적한다.
3. 제작 결과 규칙은 `evaluateCookingResult(config, session, difficulty: …)`의 MasteryResult(id/flavor/variant/completed/practice/techniquePassed)를 사용한다. 연습의 보관 선택은 결과 인정과 분리된다. 주문품은 기존대로 재고 경유이며 제작 모듈에서 판매/대금 처리를 하지 않는다.
4. 6구 입력은 `harvestCell(index, expectedCycle: 화면에 표시한 cycle)`를 사용한다. 새 UI에서도 optional 인수를 생략하지 말 것. GriddleHarvest는 resultId/state/product이며 탄 칸 product=null, 일반 수확 product=ProductBatch이다. ProductBatch의 id/맛/익힘/수량/제작영업일은 재시도 중 고정한다.
5. 저장 담당은 성공 연출 전에 칸/제품/처리 ID 및 제작 결과/숙련을 기존 원자 저장 경계에서 함께 확정해야 한다. 성공 후에만 수확 시도 캐시를 해제한다.

## 실행한 검증

환경: Windows PowerShell, `C:/flutter-sdk`, Flutter 3.47.5 / Dart 3.13.4. Flutter 명령은 1_app_development에서 실행했다.

```powershell
C:/flutter-sdk/bin/flutter.bat pub get --offline
C:/flutter-sdk/bin/flutter.bat test --no-pub test/step02_controller_test.dart test/step02_cooking_production_test.dart test/cooking_input_test.dart test/cooking_controls_test.dart test/development_production_test.dart
git diff --check
```

- 의존성 로컬 해석 성공. pubspec/lock 변경 없음.
- 최종 담당·기존 관련 묶음 **30 tests passed**. 순수 규칙/상태 전이/익힘 경계/중복 입력·수확/메모리 저장 실패 재시도/전경 이탈 중 제작·6구 시간 정지/위젯 포인터를 검증했다. 실제 SQLite 테스트가 아니다.
- git diff --check 통과.
- 신규 모듈·전용 테스트에 dart format 실행. 공통 controller/UI 전체 재포맷은 하지 않음.

정적 분석은 한글 경로에서 LSP JSON 초기화가 잘려 analysis server exit255가 발생했다. 코드 오류로 숨기지 않고 영문 경로 junction `C:/Temp/bungeoppang-step02-analysis`를 같은 앱 폴더에 연결해 아래 명령을 실행했다.

```powershell
C:/flutter-sdk/bin/flutter.bat analyze --no-pub --no-fatal-infos lib/cooking_input.dart lib/cooking_sensor_input.dart lib/development_griddle.dart lib/ui/cooking_session_controls.dart lib/ui/workshop_page.dart lib/workshop_controller.dart test/step02_controller_test.dart test/step02_cooking_production_test.dart test/cooking_controls_test.dart
```

오류0·경고0, 기존 curly_braces 스타일 info23개. info를 비실패로 취급하는 옵션으로 exit0. 일반 analyze가 완전 무진단 통과했다고 기록하지 않는다.

초기 확대 실행에 포함했던 `development_rules_test.dart`·`workshop_controller_test.dart`는 준비 코드의 dynamic map.addAll 타입 오류로 실패했다(그 묶음 16통과/31실패). 각각 load helper와 setUp의 기존 무타입 Map 리터럴이 원인이다. 해당 공통 테스트 파일은 수정하지 않았으며 전체 회귀 통과로 주장하지 않는다. 실제 설정을 그대로 읽는 step02 전용 테스트로 담당 범위를 검증했다.

## 미실행 검수·저장 담당 연결

- Android 중력/가속도 센서 보정·각도·샘플 누락·앱 복귀·센서 없는 기기 및 실제 손가락/화면 읽기 검수: **미실행**. 기존 CookingTiltStream Kotlin 소스와 채널은 존재하며 이번에는 변경하지 않았다. 위젯·순수 센서 입력 테스트는 실기기 검수의 대체 완료 판정이 아니다.
- Android APK 빌드·앱 구동·실제 SQLite·프로세스 강제 종료/재시작: **미실행**. 로컬 Dart/Flutter 테스트와 정적 분석만 실시했다.
- 실패 저장 시도 중 프로세스 종료까지의 고정 결과 보존: **저장 담당 연결 필요**. 이번 캐시는 같은 controller의 reloadAfterError에서는 유지되지만 디스크에 저장하지 않는다. 새 controller로 복구하면 마지막 성공 체크포인트가 기준이며 실패 시도 결과는 복구 보장하지 않는다.
- 저장 저널이 사용할 읽기 연결점은 `pendingCookingResolution`과 `pendingHarvestResolutions`다. 전자는 결과 CookingSession의 toJson, 후자는 resultId/product/대상 칸 회차를 원장에 기록할 수 있다. 저널의 복구 시점/재주입 및 트랜잭션 결합은 저장 담당이 구현해야 한다. 이번에 공용 schema를 임의로 추가하지 않았다.
- 순수 제작에 필요한 외부 키·유료 서비스 설정은 없음. Android 검수에는 Android 기기/에뮬레이터와 센서 유무별 입력 시나리오가 필요하다. 서비스 키/토큰은 이 문서에 기록하지 않았다.

## 권장 통합 순서

1. 저장 담당의 브랜치를 먼저 적용한다.
2. 이 브랜치를 적용하되 공통 controller의 위 세 지점과 WorkshopPage 센서 연결만 병합한다. 다른 담당의 생명주기·주문·재고 변경을 되돌리지 않는다.
3. 주문 담당은 기존 요청/결과 인터페이스에 미판매 잔량 검증을 연결하고, 저장 담당은 고정 시도 저널을 결합한다.
4. 위 30개 테스트와 통합 담당이 복구한 공통 회귀를 실행하고, Android 실기기·SQLite·강제 종료를 별도 검수한다. 그 뒤 원장/생성 문서 상태를 통합 담당이 갱신한다.

## 후속 구현 및 검증 진행 — 2026-10-18

이 절이 위 초기 인계의 미완료 항목보다 최신이다. 브랜치는 `employee2/cooking-production`, 초기 변경 커밋은 `8ffac0b`이며 직원1 저장 기반 `73fa6a5`를 `d6cbee8`로 적용했다. 다른 작업창의 파일은 수정하지 않았다.

- P1-004/P4-001~004/P5-001~002: 숟가락 좌우 스와이프와 젓가락 회전을 별도 `cooking_gestures.dart`/`ui/cooking_filling_controls.dart`에 구현했다. 단계 토큰·최초 포인터·취소·입력 차단을 기존 세션 명령에 연결하며 기존 버튼 대체 입력도 유지한다. 거리/시간/방향 우세/회전각/중심 반경은 공통 임시 수치 설정의 새 5개 필드다.
- `WorkshopProductionJournal.stageProduction(next, expectedSequence)`를 선택적 저장 포트로 추가했다. SQLite는 전체 후보 집계·기준 원문·순번을 additive `production_journal` 테이블에 먼저 기록한다. 최종 저장 트랜잭션이 저널을 제거하며 재시작은 일치하는 기준에서만 고정 후보를 재적용한다. JSON schema4/SQLite user_version4 및 구매·보상 원장은 유지한다. 최종 꺼내기/보관/6구 수확에서 사용한다.
- 공통 controller의 자동 체크포인트가 반죽 누르기를 취소하던 문제를 수정했다. `cookingInputBlocked`를 사용하고 체크포인트 대기 전에 입력 도착 시간으로 판정한다. 공통 controller 전체 재포맷은 하지 않는다.
- 정상 앱 컴파일을 위해 직원5의 `premium_controller.dart` transport 지역 변수 타입 좁히기 2줄 수정만 반영했다. 결제 동작 변경은 없다.
- 실제 디스크 SQLite ffi 저널 테스트 및 Android 통합 테스트/강제 종료 호스트 도구를 추가했다. `PRODUCTION_AUDIT=true`일 때만 debug 앱 ID에 `.step02audit`를 붙여 사용자 게임 저장과 격리한다. integration_test는 개발 의존성이다.

확인된 후속 검증: `flutter test --no-pub --concurrency=1 test/step02_controller_test.dart test/workshop_storage_test.dart --reporter expanded` **21개 통과**. 자동 체크포인트 중 2.5초 반죽 유지와 대기 전 꺼내기 판정 시각 고정을 포함한다. `python -X utf8 tools/development_balance.py --check` 통과. 추가 회귀와 최종 정적 검사 결과는 실행 완료 뒤 이 절에 기록한다.

Android SM-S921N의 ADB 연결은 확인했으나 아직 빌드/실행/센서/손가락 검수 통과가 아니다. PC 디스크 부족 및 동시 빌드 부하로 첫 실행을 중지했다. 전용 도구는 UTF-8/ASCII 임시 경로, 별도 Gradle home, JVM 2GB 및 worker2로 재실행하도록 구성했다. 테스트용 기기 일련번호나 개인 저장 내용은 인계에 기록하지 않는다.

통합 순서: 직원1 저장 기반 → 초기 `8ffac0b` → 본 후속 변경. 이미 반영된 의존 커밋은 중복 적용하지 않는다. 주문 담당은 `startOrderProduction`/`MasteryResult`/`ProductBatch`, UI 담당은 `cookingInputBlocked` 및 `harvestCell(expectedCycle: …)` 연결을 유지한다. 저장 담당은 `WorkshopProductionJournal`의 전체 집계 CAS·기준 원문 비교·저널 제거 원자성을 보존해야 한다. 외부 키·유료 서비스 설정은 필요 없다.

후속 검증 추가:

```powershell
flutter test --no-pub --concurrency=1 test/step02_gestures_test.dart test/step02_production_journal_test.dart test/step02_cooking_production_test.dart test/cooking_input_test.dart test/cooking_controls_test.dart test/development_production_test.dart test/development_rules_test.dart test/workshop_controller_test.dart --reporter expanded
flutter test --no-pub --concurrency=1 test/step02_production_journal_test.dart --reporter expanded
flutter analyze --no-pub --no-fatal-infos lib/cooking_gestures.dart lib/ui/cooking_filling_controls.dart lib/ui/cooking_session_controls.dart lib/ui/workshop_page.dart lib/workshop_controller.dart lib/workshop_storage.dart integration_test test/step02_controller_test.dart test/step02_gestures_test.dart test/step02_production_journal_test.dart
```

첫 회귀 묶음 62개 통과. 저널 동시 저장 보호 추가 뒤 재실행에서는 PC 부하로 수확 복구 테스트가 기본30초 제한을 초과했고, 이 실행은 3통과/1실패로 기록한다. 실제 파일 IO 테스트 제한을3분으로 늘린 최종 재실행은 **4개 모두 통과**. 추가된 테스트는 대기 저널을 다른 저장자가 바꾸지 못함을 확인한다. 앞선 집중21개와 중복을 제외한 규칙/위젯/저장 검증은 총84개다. 정적 검사는 오류0/경고0/info24, 위 비실패 info 옵션에서 exit0이다. 전체 앱 무진단 검사나 Android 통과로 해석하지 않는다. 설정 검사 및 `git diff --check`도 통과했다.

화면 검증 도구 `flutter test --no-pub tools/preview_step02_gestures_test.dart --reporter expanded`도 1개 통과했고 360×640 화면의 두 도구 이미지를 `build/step02-preview/`에서 확인했다. 한글/양쪽 대체 버튼/힌트가 잘리지 않음을 확인했다. 로컬 Windows 한글 폰트를 도구에서만 읽으며 앱 의존성/폰트 설정은 바꾸지 않는다. 이미지 생성은 runAsync를 사용한다. 처음 작성한 도구 실행은 이미지 비동기 완료 대기로 중단했으며 통과로 집계하지 않는다.

Android 진행 기록: 분리 앱 ID 빌드는 Gradle Kotlin DSL의 기본 함수와 android/flutter 참조 해석 실패로 두 번 실패했다. 기존 builtInKotlin=false에 대응하는 앱 `org.jetbrains.kotlin.android` 플러그인 선언을 추가했으나 이것만으로 해결되지는 않았다. 공용 캐시는 지우지 않았으며 별도 캐시에서 재현/분리 중이다. Kotlin JAR들의 ZIP CRC 검사에서는 손상이 발견되지 않았다. 기기 재연결은 확인했지만 실제 설치·제작·센서 수신·손가락·강제 종료 검수는 아직 통과가 아니다.

후속 환경 조사: 구현·로컬 검증 커밋은 `a3c737d`다. Gradle9.3.1 공식 binary ZIP의 SHA-256 검증 및 기존 all 배포본 내 JAR 전수 비교가 일치했다. 같은 배포본의 일반 Kotlin 컴파일도 종료0이었다. 공유 캐시를 연결하지 않은 `C:/Temp/g2fresh`와 ASCII TEMP/작업 경로의 독립 Gradle Kotlin DSL 예제는 `BUILD SUCCESSFUL in 2m 57s`, 종료0으로 통과했다. 캐시 별칭/실행 환경에 따른 실패 가능성을 확인한 것이며 정확한 내부 원인을 확정하지 않았다. 프로젝트의 Gradle/AGP/Kotlin 버전은 바꾸지 않았다. 직원5 인계의 동일 Gradle 버전 APK 성공 기록은 참고만 하며 이 브랜치의 실기기 통과 근거로 사용하지 않는다.

실제 앱 진입점 검수 준비: `lib/main.dart`의 `WorkshopOnline(online as WorkshopTransport)` 한 줄은 직원5의 기존 타입 수정과 동일하게 재사용했다. 공통 main의 다른 동작은 수정하지 않았다. 이미 통합된 브랜치는 이 중복 수정을 다시 적용할 필요가 없다. `flutter analyze --no-pub --no-fatal-infos lib/main.dart lib/premium_controller.dart`는 종료0/No issues found였다.

`tools/step02_manual_review.dart`는 실제 main을 실행하고 제작 단계/두 반죽 시간/6구 회차와 시간/수명 이벤트만 관찰한다. 게임 상태를 주입하지 않으며 debug+PRODUCTION_AUDIT 빌드만 허용한다. `flutter analyze --no-pub --no-fatal-infos tools/step02_manual_review.dart`도 종료0/No issues found였다. 기기 도구의 `--review-only`는 별도 앱을 빌드·업데이트·실행하며 물리 검수 통과를 자동 선언하지 않는다. `python -X utf8 -m py_compile tools/run_step02_device_audit.py` 통과. 기존 main의 CRLF는 보존했고 `git -c core.whitespace=cr-at-eol diff --check`를 사용했다.

Android 실측 추가: `C:/GradleCache`를 실제 Gradle home으로 사용한 별도 앱 APK 빌드는 964.8초 뒤 성공했고 설치도 성공했다. Android16/SM-S921N에서 자동 제작 입력(2.6초 실제 대기 반죽 포함)·네이티브 센서3샘플 수신·Android SQLite 저널 재적용이 종료0/1개 통과했다. 물리 손가락·실제 기울임 판정 완료와는 구분한다. KGP 전환·SDK XML 버전 경고가 남으며 경고0 빌드로 기록하지 않는다.

첫 실행의 Flutter 기본 종료 정리가 audit suffix 대신 기본 앱 ID의 uninstall을 시도했고 DELETE_FAILED_INTERNAL_ERROR로 실패했다. 직후 기본 앱 ID는 pm path에서 발견되지 않았다(실행 전 설치 상태까지 확정하는 기록은 아님). 이를 확인하고 후속 호스트만 중지한 뒤 모든 Flutter test 명령에 **`--no-uninstall`을 필수로 추가**했다. 이후 재실행은 자동 제거 없이 종료0/1개 통과했다(`C:/Temp/step02-device-20261018131607/smoke.log`). 향후 직접 명령을 실행할 때도 `--dart-define=PRODUCTION_AUDIT=true --no-uninstall`을 반드시 함께 사용한다. 강제 종료 검수는 suffix 앱만 대상으로 하며 기본 앱을 제거하거나 초기화하지 않는다.

강제 종료 검수 완료: 같은 디렉터리의 crash-stage.log에서 STEP02_KILL_READY를 확인한 뒤 audit 앱의 실제 프로세스를 am force-stop 했고 PID 소멸을 확인했다. stage 실행은 의도적인 VM 연결 유실로 끝났으며 Flutter 임시 리스너 정리 PathNotFoundException도 출력했다. 이 실행을 테스트 통과로 집계하지 않는다. 별도 프로세스의 crash-recover.log는 종료0/1개 통과, STEP02_FORCE_STOP_RECOVERY_OK다. 같은 DB의 결과 ID/15000ms 익힘/연습1회/빈 저널을 검증하고 controller 재생성 뒤에도 연습1회를 확인했다. 현재 네이티브 자동 검사는 제작·센서·SQLite 1개와 종료 복구 1개, 총2종 통과다.

실제 페이지 구성 후속: 그리기 위젯을 SingleChildScrollView에 넣은 새 회귀에서 원 그리기 도중 페이지가 함께 움직임을 재현했다. 일반 pan 인식기만으로는 부모 vertical drag의 선점이 남아 실패했고, 그리기 영역의 EagerGestureRecognizer로 해결했다. 그리기 영역 밖의 페이지 스크롤은 별도 확인한다. 최종 `flutter test --no-pub --concurrency=1 test/step02_gestures_test.dart test/cooking_controls_test.dart --reporter expanded`는 **11개 통과**, 대상2파일 analyze는 종료0/No issues found였다. 중복 제외 규칙/상태/위젯/저장 검증은 이제85개, 화면 렌더 도구1개는 별도다.

실제 main 기반 관찰 앱은 `--review-only`로 빌드67.2초/설치/실행 각각 종료0이며 STEP02_REVIEW_READY를 확인했다(`C:/Temp/step02-device-20261018132151/`). 자동 테스트용 화면과 구분한다. 현재 실제 손가락/기울임/홈 복귀는 사용자 조작과 관찰 기록을 대조 중이며 아직 최종 완료로 표시하지 않는다.


## 사용자 실기기 피드백·기존 홈 복원 후속 (2026-10-18)

기준 `a3c737d`, 브랜치 `employee2/cooking-production`. 사용자는 센서를 켜도 반죽이 진행되지 않는다고 확인했다. 이전 네이티브 샘플 수신 통과는 실제 기울임 제작 성공이 아니다. 또한 기존 홈의 중앙 큰 틀에서 제작하고 기존 상단 메뉴·설정·생산량 배치를 유지하도록 재확정했다.

P1-004/P4-001~004/P5-001~002 연결: NightHome의 기존 배경/큰 틀/사장님/아래6구/하단 메뉴와 기존 상단 HUD를 재사용한다. NightHomeHeaderData는 Workshop 레벨/재화/생산량/승급 진행만 주입하고 구형 경제에는 입력하지 않는다. 독립 ui/workshop_mold_stage.dart가 배경의 원래 큰 틀 위치에 반죽/속/닫기/뒤집기/꺼내기/보관을 배치한다. 배경 속 붕어빵을 중복 렌더하지 않는다. 6구는 기존 칸 좌표에 expectedCycle 수확을 연결한다. 주문/재고/미션은 메뉴 관리 창, 주문 제작 성공 시 창을 닫고 중앙 제작으로 복귀한다. SoundSettings/Cozy를 재사용하여 소리·음량·진동·모션 줄이기/배경 시간을 연결한다. 신규 DB 초기화를 구형 계정 초기화에 잘못 연결하지 않는다.

센서는 중력 X/Y/Z를 네이티브에서 전달하고 Dart의 atan2(-x,sqrt(y²+z²))로 좌우를 계산한다. X/Y만 계산한 기존식의 평평한 자세 불안정성을 보완한다. 순수 테스트는 평평한/세운 중립·좌우30도·무효 벡터·2.5초 붓기 명령을 확인한다. 보정/준비/붓는 중/중립 복귀 상태와 다시 보정을 표시한다. 이것이 실기기 원인을 최종 확정했거나 실기기 성공했다는 뜻은 아니다.

공통 충돌: night_home.dart의 선택적 표현 포트, workshop_page.dart의 홈/센서/설정 연결을 조정한다. 기존 주문/재고/손님 관리 코드는 보존한다. 이번 복원에서 game_app.dart, controller/모델/저장 스키마는 수정하지 않는다. main 타입 수정은 직원5와 동일한 중복 수정이다. a3c737d 다음 본 후속을 적용하며 타 직원의 WorkshopPage 변경을 보존한다. CHECKLIST/진행현황/tasks.json은 수정하지 않는다.

검증 과정: 기존 홈 골든3개 통과. 새 홈390×844/360×640 실제 controller의 연습 시작·첫 반죽→속 넣기·구형 경제 불변 확인 후 전체 제작과 설정 열기/스크롤/저장 회귀로 확장했다. 작은 화면의 방향 버튼이 취소 버튼/사장님에 가려지는 실패를 재현해 배치와 그리기 순서를 수정했다. 수정 전 실패는 통과로 집계하지 않는다. 최종 결과는 다음 기록을 따른다.

첫 복원 Android APK64.0초 빌드/설치/실행 성공, SHA256 690EADC45036B449C570DDED27E38F9EF1171A519CD05EC0EEFACDCE14A11351. 실제 화면에서 중복 붕어빵을 발견하여 수정했으므로 최종본이 아니다. audit suffix 앱만 업데이트하고 데이터를 지우지 않는다. 최종 실기기 기울임·손가락·홈 복귀는 아직 미완료다. 외부 키/유료 서비스 설정은 필요 없다.


홈 복원 최종 로컬 근거:
- `flutter test --no-pub --concurrency=1 test/step02_home_test.dart test/home_golden_test.dart --reporter expanded`: 6개 모두 통과(C:/Temp/step02-home-ui-final.log). 390×844/360×640의 상단 메뉴/설정·소리/진동/모션·저장 후 전체 제작/보관을 실제 WorkshopController에 연결한다. 닫기/뒤집기/익힘 시간은 테스트에서 명시적으로 주입하며 실시간15초 측정으로 기록하지 않는다. 구형 GameController 경제 불변을 확인한다. 나머지3개는 기존 홈 골든 비교다.
- `flutter test --no-pub --concurrency=1 test/step02_home_test.dart test/step02_gestures_test.dart test/cooking_controls_test.dart test/cooking_input_test.dart --reporter expanded`: 18개 모두 통과(C:/Temp/step02-restored-input-tests.log). 기존85개와 중복 제외 새3개로 제작 핵심 로컬 검증은88개, 기존 홈 골든3개는 별도다.
- `flutter analyze --no-pub --no-fatal-infos lib/ui/night_home.dart lib/ui/workshop_page.dart lib/ui/workshop_mold_stage.dart lib/ui/cooking_filling_controls.dart lib/ui/cooking_session_controls.dart lib/cooking_tilt_source.dart lib/cooking_sensor_input.dart test/step02_home_test.dart`: 오류0/경고0/info1/종료0(C:/Temp/step02-restored-analyze.log). 중괄호 스타일 info1이 남는다.
- `flutter build apk --debug --no-pub --target-platform=android-arm64 --target=tools/step02_manual_review.dart --dart-define=PRODUCTION_AUDIT=true`:58.0초 빌드 성공(C:/Temp/step02-restored-build.log), 설치-r 및 suffix 앱 재실행 성공. 최종 APK SHA256 `E4D3408AD3EA455F5220ED86D116665BA3D119A39DB4069FC4DE22A5CD3472A3`. KGP 전환 경고는 남는다. 이후 소스 수정은 WorkshopPage EOF 공백 제거만이며 동작 변경은 없다.
- 실기기 화면 캡처 C:/Temp/step02-restored-device.png에서 기존 상단 구성/설정 아이콘/중앙 원래 큰 틀/아래6구 및 중복 붕어빵 제거를 직접 확인했다. 실제 기울임 반죽/손가락 회전/앱 홈 복귀는 별도 재확인을 요청한 상태다. 전체 완료로 표시하지 않는다.


홈 복원·센서 후속 구현 커밋은 `5d2cbd2`다. 2026-10-18 최신 설치본에서 사용자는 기울기 반죽이 '속 넣기로 넘어가요'라고 확인했다. 이는 사용자 실기기 조작 확인으로 기록하며, 호스트 로그에서 해당 입력 출처를 별도로 증명한 것으로 쓰지 않는다. 관찰 로그에는 첫 반죽→속 넣기 전이가 남았지만 센서별 상태 로그는 확인되지 않았다. 속 넣기 원/쓸기·스크롤 선점 및 홈5초 이탈/복귀 최종 확인은 이어서 요청했다. 최종 답변 전 확인 결과를 추가한다.


시간 표시 누락 후속: 사용자의 '2번 복귀·시간 문제'는 후속 답변에서 '제작 시간이 아예 안 떠'로 확인됐다. 이를 시간 정지 로직 실패로 확정하지 않는다. 실제 관찰 로그는 이탈 중 filling/token2/58036ms가 고정되고 paused=true임을 확인했다. 중앙 큰 틀 위에 '현재 단계 경과 N.N초'와 일시정지 표시를 복원했다. 공통 controller/수명 로직은 변경하지 않았다. test/step02_home_test.dart에 표시 존재/12초 표시/일시정지 표시/5초 동안 불변/복귀 후 단계 보존을 추가했다. `flutter test --no-pub --concurrency=1 test/step02_home_test.dart --reporter expanded` 3개 모두 통과(C:/Temp/step02-time-display-test.log), 기존 사례를 확장한 것이므로 총 사례 수를 중복 증가시키지 않는다. 시간 표시 추가본을 빌드·설치하고 실제5초 복귀를 확인할 예정이다.


## 최신 사용자 정정: 방향/도구 제거·짤주머니·빈 큰 틀

이 절이 이전 숟가락/젓가락·방향 제스처 구현/검수 기록보다 우선한다. 사용자는 속 넣기를 '큰 틀을 길게 눌러 속 양 조절', '짤주머니로 넣는 액션'으로 지정했고 제작 중에는 틀 안에 완성 붕어빵이 없어야 한다고 확인했다. 따라서 이전 제스처 구현을 유지하거나 사용자 확정으로 다시 인용하지 않는다.

변경: lib/cooking_gestures.dart, ui/cooking_filling_controls.dart, test/step02_gestures_test.dart, tools/preview_step02_gestures_test.dart를 삭제했다. ui/piping_bag_control.dart는 길게 짜기·양 표시·주머니 변형/속 줄기/단일 포인터/취소를 제공한다. ui/cooking_mold_painter.dart는 제작 중 배경의 완성품을 덮는 불투명 빈 틀과 원재료/닫힌 뚜껑을 그린다. 결과 단계에서만 FishPainter를 사용한다. 반죽 두 단계도 빈 틀 위에서 누르는 동안 양 표시를 제공한다. 기존 상단 HUD/메뉴/설정은 유지한다. 센서 속 방향 명령을 제거하고 두 반죽만 지원한다.

공통 변경 최소 범위: cooking_session.dart에 선택적 fillingDurationMs와 squeezeFilling(token,durationMs)를 추가했다. 기존 세션 schema1/전체 schema4, 옛 방향 시퀀스/토큰의 저장 형식은 보존한다. 현재 세션에서 정확히 도출 가능한 전체 짤주머니 완료만 successor로 인정하고 다른 맛/반죽 기록 위조·중복·지난 토큰을 막는다. cooking_result_rules.dart는 새 짤주머니 완료에 옛 방향 실수 페널티를 부과하지 않는다. controller/저장 본체/재고 모델은 이 정정에서 변경하지 않았다. 결과·주문 담당은 결과 확정 세션의 fillingDurationMs를 읽을 수 있다. 현재 ProductBatch에는 속 양 필드가 없고 보관 후 판매 가격에 속 양을 반영하지 않는다. 해당 본체 확장이 필요하면 다음 담당이 이 포트를 연결해야 하며 임의 숨은 가격/합격 기준은 추가하지 않았다.

설정: 제스처5개 수치를 삭제하고 manual_cooking.filling_capacity_ms=4000(표시100% 기준 임시값)을 추가했다. 속 양 합격 범위는 정의하지 않는다. 생성 서버JSON/14번 수치 문서를 도구로 갱신했다. 요약/상세/기술설계의 현재 조작 설명을 사용자 정정에 맞췄다. tasks.json/CHECKLIST/진행현황은 수정하지 않았다. 통합 시 다른 직원의 세션 모델/설정 변경을 보존하고 새 선택 필드를 함께 전달해야 한다.

시간 표시 수정본 실기기: APK CC8B91A3F12B4C57CB6354B71B596B74428C1C8BCF671339F9FB693A8D37C24D, 빌드53.6초/설치/실행 성공. ADB로 실제 HOME5초→복귀하여 filling/token2 유지, 정지69435ms→복귀70805ms(재개 후 약1.37초) 확인, 백그라운드의 마지막3개 시간 표본 동일이었다. C:/Temp/step02-device-20261018135852/lifecycle-audit.log가 근거다. 시간 표시도 화면에서 확인했다. 이는 짤주머니 정정 전 APK 검수이며 새 짤주머니 실기기 통과로 재사용하지 않는다.

최신 로컬 검증:
- test/step02_home_test.dart + cooking_input_test.dart + step02_cooking_production_test.dart + step02_controller_test.dart + workshop_storage_test.dart:33개 통과(C:/Temp/step02-piping-tests.log).
- test/step02_piping_test.dart:4개 통과(C:/Temp/step02-piping-focused.log). 양 누적·다중 포인터·취소·저장 왕복·위조/중복을 확인했다.
- home+piping+home_golden+production_journal+development_rules:25개 통과(C:/Temp/step02-piping-final-tests.log), 중복 포함 실행 묶음이다.
- workshop_controller+development_production+cooking_controls+production_journal:39개 통과(C:/Temp/step02-piping-recovery-tests.log). 저널 케이스를 짤주머니1450ms 완료로 바꿔 실제 디스크 DB 재생성 뒤에도1450ms·한 번만 결과 확정을 검증했다.
- 중복 제외 핵심 규칙/상태/저장/위젯87개와 기존 홈 골든3개다. 제거한 제스처 테스트는 더 이상 현재 검증 수에 넣지 않는다. 시간/양 표시는 합성 UI 테스트이며 실제 손가락 완료와 구분한다.
- python -X utf8 tools/development_balance.py 및 --check 통과. 화면 캡처 home-empty.png/home-filling.png에서 빈 틀/반죽과 주머니를 확인했다. 생성물은 build/step02-preview에 있으며 git에 넣지 않는다.

최신 Android 짤주머니 앱 빌드는52.3초 성공(C:/Temp/step02-piping-build.log). 기기 연결 소실로 갱신한 Android smoke는 실행 전 'No devices connected'로 실패(C:/Temp/step02-device-20261018140938/smoke.log)했으며 통과가 아니다. 재연결을 요청했다. 새 APK 설치/실제 짤주머니/빈 틀 검수는 남는다. 키/토큰/서비스 계정/유료 서비스 설정은 필요 없다.


최종 정적 검사: 11개 대상(cooking_session/result_rules/sensor_input, session_controls/piping_bag/cooking_mold/workshop_mold/workshop_page, Android smoke, piping/home 테스트)은 오류0/경고0/info4, --no-fatal-infos에서 종료0(C:/Temp/step02-piping-static-complete.log). 새 짤주머니 APK SHA256 `AE7500D5DB5DF6EECD5C27804695E5977CAA8275D6B56E9ABDE0A95D4FF85F6F`. 로컬 빈 틀/반죽·주머니 이미지에서 완성품 미노출을 확인했고 빌드는 성공했으나 USB 부재로 이 APK는 아직 기기에 설치하지 못했다. 이전 APK가 휴대폰에 남아 있으므로 최신 수정이 실기기에 반영됐다고 안내하면 안 된다.


## 재연결 후 Android 실행 근거 (2026-10-18)

최신 짤주머니·빈 틀 구현 커밋 `019d734`의 Android 검수를 재연결 후 실행했다. `python -X utf8 tools/run_step02_device_audit.py --device <연결기기> --smoke-only --gradle-home C:/GradleCache`는 종료0/1개 통과. 근거 C:/Temp/step02-device-20261018142010/smoke.log: 빌드55.0초/설치12.2초, STEP02_PIPING_BAG_OK durationMs=1125(길게 누르기 및 SQLite에 같은 값 저장), 네이티브 센서3샘플 수신, Android SQLite 저널 재적용 모두 성공했다. --no-uninstall을 사용했고 기존 게임 패키지를 제거하지 않았다. 이는 자동 Android 입력 검수이며 실제 손가락 조작과 구분한다.

검수용 자동 화면 이후 SHA256 AE7500D5DB5DF6EECD5C27804695E5977CAA8275D6B56E9ABDE0A95D4FF85F6F인 실제 main 기반 관찰 APK를 재설치해 기존 홈을 복원하는 중이다. 마지막 실제 손가락 짤주머니·빈 틀 확인 결과는 후속 기록을 따른다.


기존 홈 관찰 APK 재설치/실행이 종료0으로 완료됐다. 실제 기기에서 큰 틀 연습을 시작해 완성 붕어빵이 없는 빈 공동과 단계 시간 표시를 확인했다(C:/Temp/step02-piping-empty-device.png). 실제 손가락의 반죽→짤주머니 양 증가→둘째 반죽은 사용자 확인을 요청한 상태다. 최신 앱 원본은 C:/Temp/step02-piping-review-019d734.apk이며 자동 검사 화면 APK와 구분한다.


최종 사용자 실기기 확인: 최신 짤주머니·빈 틀 APK에서 '완성 붕어빵 없이 반죽부터 채워짐'과 '누르는 동안 속 양 증가·손을 놓으면 둘째 반죽 진행'에 대해 사용자가 '두 항목 모두 정상'이라고 확인했다. 방향/숟가락/젓가락을 제거한 사용자 정정 흐름의 실제 손가락 검수다. 센서 반죽은 앞선 사용자 확인, HOME5초 시간 정지/복귀는 별도 실제 기기 관찰 기록을 따른다. 6구 전체 회차를 실제 손가락으로 각각 수확하는 검수는 실시하지 않았으며 로컬 독립6칸/탄 칸/중복 수확 검사와 구분한다. 체크리스트 원장 반영은 통합 담당이 수행한다. 직원2 최신 구현 커밋은019d734, 공통 홈 선행은5d2cbd2이며 이번 기록은 후속 인계 커밋으로 제공한다.


## 기존 나머지 메뉴 복원 (추가 사용자 요청, 2026-10-18)

기준518da22/employee2/cooking-production. 사용자가 나머지 메뉴도 기존 구성으로 복원하도록 요청했다. 기존 GameHome의 목적지별 창, MenuPanel, SkillShop, WardrobePanel, ShopPanel, Friends/Ranking/Share 코드를 먼저 대조했다. 상점과 기타 목적지가 모두 가게 관리로 연결되던 WorkshopPage 경로를 분리했다.

변경: 별도 ui/workshop_windows.dart에 기존 나무 테두리/물고기 제목/빨간 닫기/돌아가기/상단 잔액 창과 WorkshopSkillShop을 구현했다. 스킬은 기존 클릭/자동 탭·1/10/최대 수량·아이콘/이름/보유/현재·구매 후 효과/상세를 유지하며 견적과 구매는 quoteCompositeSkill/maximumCompositeSkill/purchaseSkill 및 기존 복구 저널을 사용한다. 예전 코인이나 GameController 진행으로 구매하지 않는다.

기존 MenuPanel과 WardrobePanel/ShopPanel에 선택적 표현·액션 포트를 추가했다. 인자를 주지 않는 기존 경로는 그대로다. 메뉴의 도감/업적/통계/랭킹/배경 테마/일일/주간/레벨 미션/친구/공유를 목적지별로 복원했다. 새 주문·재고·영업 관리는 별도 메뉴 항목으로 보존한다. 도감/미션/업적/통계는 현재 Workshop 기록을 표시하며 구형 통계/보상을 신규 실적으로 꾸미지 않는다. 메뉴와 홈 보상 배지는 실제 미청구 미션/승급만 센다.

꾸미기는 기존5개 탭·분류·미리보기·3열 격자·적용을 재사용한다. 구매 가능한 아바타는 기존 공통51개 목록/두 재화 견적/서버 검증을 사용하고 무료/보유 착용은 Workshop 저장에 반영한다. 미리보기는 저장하지 않는다. 기존 보유 비아바타 꾸미기는 기존 계정의 appearance 저장 포트만 적용한다. 아직 가격/구매 계약이 없는 비아바타 미보유 상품은 준비 중으로 표시하며 코인 가격이나 임의 새 가격을 되살리지 않았다. 상점은 기존 장비/꾸미기/테마/충전 탭을 재사용한다.

친구/랭킹/공유는 기존 계정 UI/서비스에 연결했다. 친구 화면에서 신규 진행에 연결되지 않은 구형 부스트 안내만 숨겼고, 실제 계정의 친구/초대/방문 연결을 재사용한다. 신규 Workshop의 랭킹 점수 제출이나 친구 방문 생산 부스트 연결을 새로 완성한 것은 아니다. 기존 서버 연동 설정/다른 담당의 연결이 필요하며 실제 로그인·결제·친구 방문·공유 전송은 이번 검사에서 실행하지 않는다. 공유 창을 자동으로 열거나 메시지를 전송하지 않았다.

충돌 주의: 공통 public_menus.dart/MenuPanel·WardrobePanel의 선택적 CosmeticMenuAccess, ShopPanel의 같은 액션 포트, FriendsPanel의 안내 표시 옵션을 추가했다. controller/모델/저장 스키마/main/의존성은 변경하지 않는다. WorkshopPage는 목적지 연결과 창 개수별6구 가림을 관리한다. 창 전환 중 앞 창 finally가 새 창의6구를 재개하던 위험은 창 개수로 차단했다. 큰 틀·센서·시간·짤주머니는 앞선 사용자 정정을 유지한다. 자동 생성 원장은 수정하지 않는다.

검증 중 최초 새 메뉴 테스트는 배경 하단 '상점'과 창 제목을 같은 Text finder로 찾는 테스트 선택자 오류로2개 실패했다. 창 제목 키로 고친 재실행은2개 통과(일반/1.5배 글자;11개 목적지·스킬 탭/수량·무료 아바타 미리보기/적용·재화 불변·창 전환 중6구 정지). 이전 공통 메뉴/스킬/큰 틀 회귀 묶음19개 통과(C:/Temp/step02-menu-regression.log). 수정 전 실패를 통과로 세지 않는다. 최종 홈/골든/메뉴 재실행과 Android 결과는 후속 기록을 따른다.

대상6파일 정적 검사 오류0/경고0/info4, --no-fatal-infos에서 종료0(C:/Temp/step02-menu-static-final.log). 서버/유료 서비스 사용은 없으며 새 외부 설정을 추가하지 않았다.


메뉴 최종 로컬 확인: `flutter test --no-pub --concurrency=1 test/step02_menu_test.dart test/step02_home_test.dart test/home_golden_test.dart --reporter expanded` 8개 모두 통과(C:/Temp/step02-menu-final-tests.log). 창11곳·일반/큰 글자·무료 아바타 적용·미리보기 불변·두 재화/구형 코인 불변·창 전환 중6구 가림·큰 틀 전체 제작·기존 홈 골든을 확인했다. 도감 레벨 잠금/기존 보유 비아바타의 해금 조건 보존을 보완한 추가2개 재실행도 모두 통과(C:/Temp/step02-menu-policy-tests.log). 처음 Android 빌드는98.8초 성공했으며 정책 보완 후 최종본을 다시 빌드해 설치한다. 직전 통과를 최종 Android 설치 근거로 쓰지 않는다.
