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
