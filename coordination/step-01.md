# 직원 1 — 저장·영업·복구 기반

- 작업일: 2026-10-18 KST
- 기준 커밋: `9108513a89e83d4dd8f6c0772f6554c844d1e8a0`
- 브랜치: `employee1/storage-lifecycle`
- 별도 worktree: `C:/Users/이소이/Desktop/Git/bungeoppang-step-01`
- 관련 ID: P1-003, P1-005, P1-006, P5-003 중 저장·영업 수명 영역. 전체 항목 완료나 실기기 검수 완료를 의미하지 않는다.
- 원본 worktree의 미커밋 android/build/firebase/ios 파일은 이동·삭제·커밋하지 않았다. 공용 tasks.json/CHECKLIST.md/진행현황.md도 수정하지 않았다.

## 확인한 기준과 유지한 결정

AGENTS.md는 저장소 파일 검색에서 없었다. CLAUDE.md 및 MASTER.md, CHECKLIST.md·진행현황.md·tasks.json, 18/19/20/22번 최신 결정·구현 기록을 확인했다. 신규 게임이며 기존 사용자 이전 대상 없음이 tasks.json P1-003 scope_decision 및 18번에 확정되어 있다. 구형 `repository.dart`의 클리커 저장을 신규 재화/레벨로 환산하지 않는다. 신규 Workshop schema1~3은 기존 fromJson의 보호 필드 검증을 거쳐 schema4로 직렬화한다. 실제 사용자 파일을 수집·확인했다는 의미는 아니다.

기존 코드에 영업 시작/종료·KST 날짜·동일 날짜 재영업+0·공백 후 실제 이어가기+1·준비품 최초 귀속·시계 역행 방어·영업 전후 자동0·부재8시간/50%·결과/판매/구매 ID 원장이 구현되어 있어 재작성하지 않았다. 앱 이탈/종료는 영업 종료와 다르며 고객/제작/6구 경과는 부재 시간으로 진행하지 않는다. KST 날짜 변경은 명시 이어가기 전까지 제품 활동을 막고 자동 생산 정산과 구분한다.

## 완료 변경

1. 저장 클래스를 새 `lib/workshop_storage.dart` part로 분리했다. 외부 import는 계속 `workshop_controller.dart` 하나이며 기존 Repository 인터페이스가 유지된다.
2. SQLite4 기존 테이블에 최신 `recovery` 사본과 `purchase_guard` id2 전체 집계 증거를 추가했다. JSON schema4 및 SQL 버전4 유지, DDL 변경 없음. 기존 정상 저장은 읽을 수 있고 다음 성공 저장에서 복구 행을 원자적으로 채택한다.
3. 현재 저장 손상/누락/이전 순번 되돌림은 최신 전체 증거와 완전히 같은 사본만 복원한다. 기존 구매/보상/관계 보호도 일치해야 한다. controller는 모델 검증까지 통과한 사본만 사용한다. 현재 순번이 사본보다 새로우면 중단하여 구버전 앱 등이 기록한 새 진행도 오래된 사본으로 덮지 않는다. 직전 backup은 보존하되 자동 복원하지 않는다. 판매·구매·보상 원장 및 재화가 함께 복원되므로 과거 백업으로 일부만 되돌아가는 경로를 열지 않는다.
4. 복구 재읽기 중 busy 잠금을 적용하여 다른 명령·틱이 집계를 변경하지 못하게 했다. lifecycle은 진행 중 저장/복구가 끝나기를 기다린다.
5. 실제 영업일보다 미래에 귀속된 재고·준비품 binding을 거부한다.
6. 실제 SQLite 트랜잭션 실패 주입 및 lifecycle/날짜 경계 테스트를 추가했다. 기존 controller 테스트의 setUp에서 Dart 런타임 Map.addAll 타입 오류를 고치기 위해 fixture Map에 `<String,dynamic>`을 명시했다(기대값 변경 없음).

## 모듈 연결 계약과 오류 처리

- `WorkshopController.command(void Function() mutate) -> Future<bool>`: 상태 변경/고정 ID 원장/대금/재고를 동일 콜백 안에서 함께 갱신한다. async 콜백·외부 API 호출을 넣지 않는다. 저장 전 집계 전체를 왕복 검증하고 `sequence=expected+1`을 CAS 저장한다.
- `true`가 영속 저장 성공이다. `false`는 busy/disposed/error 상태이거나 업무 거부/저장 실패다. 업무 거부 `FormatException`은 notice로 표시하고 원복하며, 검증·저장 오류는 error를 설정하고 후속 명령을 차단한다. 콜백 밖에서 state를 직접 수정하지 않는다. 외부 응답이 불명확하면 새 ID로 재지급하지 않고 기존 거래/결과 ID를 조회한다.
- 저장 실패 시 명령 직전 메모리로 복원한다. 커밋 후 응답 유실도 가능하므로 저장 실패가 디스크 미반영이라는 가정은 금지한다. `reloadAfterError()`로 실제 영속 순번/원장을 읽고 동일 ID로 판단한다. 복구 읽기 실패는 예외를 전파하며 error를 유지한다. 자동 초기화/삭제는 없다.
- `WorkshopRepository.load/save(next, expectedSequence)`는 기존 fake와 호환된다. SQLite `loadValidated(validator)`는 current 검증 및 최신 사본 복원을 동일 SQL 트랜잭션에서 수행한다. `load()`는 저장/구매 보호만 검증하므로 게임 집계 소비자는 controller 또는 `loadValidated((row) { WorkshopState.fromJson(row,config); })`를 사용한다.
- `openBusiness/closeBusiness`를 통해 영업을 조작한다. 제품 기능은 `business.permitsProducts(now)`를 확인한다. `setForeground(false/true)`는 앱 수명이며 영업 상태를 닫지 않는다. OS 강제 종료 직전 저장 완료는 보장할 수 없고 마지막 성공 checkpoint로 재시작한다.
- 준비품은 `recordPreparedResult`의 index0 표시와 고정 결과 ID를 유지하고 영업 시작 시 `acceptPrepared`가 최초 한 번 binding한다. 소비·소멸 후에도 disposition/binding을 삭제하지 않는다. 판매·구매·보상 기록도 임의 정리하지 않는다.
- `SqliteWorkshopRepository.withDatabase(db)`는 로컬 SQLite 테스트 주입용이다. 운영 연결 생성자는 기존대로 인수 없이 사용한다.

## 변경 파일과 통합 순서

- 신규: `1_app_development/lib/workshop_storage.dart`, `test/workshop_storage_test.dart`, `test/workshop_lifecycle_test.dart`, 이 인계 파일.
- 공통: `lib/workshop_controller.dart`는 저장 클래스 블록을 part로 옮기고 part 선언·미래 재고 검증·검증 로드 함수·복구 잠금만 반영했다. 다른 직원의 제작/주문/구매 변경은 유지하며 해당 네 부분만 병합한다. 기존 import는 part가 사용하므로 삭제하지 않는다.
- 공통: pubspec.yaml은 **dev_dependencies**에 `sqflite_common_ffi` 1개, lock은 그 해석 결과 4개 패키지 추가. 운영 의존성은 바꾸지 않았다. 다른 의존성 작업 후 pub get으로 lock 통합한다.
- 공통: 기존 `test/workshop_controller_test.dart` fixture 타입 명시 1줄과 MASTER.md 후속 설명 추가. 자동 생성 원장은 통합 담당이 갱신한다.
- 순서: 새 part 파일과 controller의 part 선언/블록 이동을 함께 반영 → 나머지 controller 변경을 함수 단위 병합 → 개발 의존성 통합/pub get → 테스트 → 원장 갱신. main/모델 스키마/상품·광고 정책 변경 없음.

## 검증 기록

실행 결과를 아래에 확정 기록한다. 최초 실행에서 신규 날짜 기대값의 하루 계산 오류와 기존 controller 테스트 fixture 타입 오류가 드러나 수정했다. 테스트 도중 소스 변경이 있었으므로 최종 고정 소스 재실행 결과를 기준으로 삼는다.

환경: Windows x64, Flutter 3.47.5 / Dart 3.13.4, `PUB_CACHE=C:/PubCacheBungeoppang`. 아래 명령은 `1_app_development`에서 `C:/flutter-sdk/bin`의 실행 파일로 수행했다. Firebase/광고/결제 실서비스는 사용하지 않았다.

| 실제 실행 명령 | 결과 |
| --- | --- |
| `flutter pub get --offline` | 종료0, 기존 의존성 해석 성공 |
| `flutter pub add --dev sqflite_common_ffi` | 종료0, 테스트용 의존성 및 전이3개 추가 |
| `flutter test --no-pub --reporter expanded test/workshop_storage_test.dart test/workshop_lifecycle_test.dart test/workshop_controller_test.dart test/development_production_test.dart` | fixture/날짜 수정 후 45개 통과, 종료0 |
| `flutter test --no-pub --reporter expanded test/workshop_storage_test.dart` | 최종 13개 통과, 종료0. 후속 판매/구매 통합 복구·CAS 경합·schema1/2/3·더 새로운 current 보호 포함. 위 실행과 중복을 제외한 통과 시나리오 총51개 |
| `dart analyze lib/workshop_controller.dart lib/workshop_storage.dart test/workshop_lifecycle_test.dart test/workshop_storage_test.dart test/workshop_controller_test.dart` | 종료0, error/warning 없음, 기존 구문 및 이동된 구문의 중괄호 스타일 info21건. 전체 저장소 무결점 분석을 의미하지 않음 |
| `dart analyze lib/workshop_storage.dart test/workshop_storage_test.dart` | 마지막 새 진행 보호 변경 후 종료0, error/warning 없음, 옮긴 기존 구문의 스타일 info1건 |
| `git diff --check` | 종료0 |
| `git diff --cached --check` | 신규 part 파일 CRLF를 LF로 맞춘 후 종료0 |

SQLite 테스트는 fake SQL이 아닌 sqflite_common_ffi의 실제 SQLite(in-memory) 트랜잭션을 사용한다. current 삽입 직전 SQL trigger가 ABORT를 일으키도록 해 이미 실행한 guard/recovery/backup 쓰기도 모두 원복되는 것을 확인했다. fail trigger 제거 뒤 같은 expectedSequence로 재시도 성공을 확인했다. current 손상·누락·낮은 순번 되돌림·보호 기록 불일치·과거 backup 거부·반복 복구·두 writer CAS를 검증했다. 판매/보상 대기/관계/확정 구매가 든 집계의 복구 결과를 원본 전체와 비교했다.

Lifecycle 테스트9개는 KST 자정·8일 공백·시계 역행, 준비품 귀속 저장 실패/재시도/소멸 후 원장 보존, 앱 재시작의 열린 영업 및 제작/고객 경과 유지, 닫힌 영업0·부재 cap/멱등, 커밋 응답 유실, pause/resume 경합, 미래 재고 거부, 실패한 복귀 후 중복 없는 재읽기, 복구 읽기와 lifecycle의 상호 배제를 확인했다.

## 남은 검수·외부 설정·제한

- Android sqflite 플러그인의 디스크/프로세스 강제 종료·앱 lifecycle·실기기 검수, 실제 기존 SQLite1~3 파일의 onUpgrade 실행 검수는 별도다. 데스크톱 SQLite 실패 주입은 Android 검수를 대신하지 않는다.
- 로컬 DB 전체 삭제/손상, current/recovery/전체 증거 동시 유실, 임의 전체 DB 교체는 복구 보장 범위 밖이다. 복구 행이 없던 구형 손상 저장도 보존 후 중단한다. 과거 backup으로 복귀하려면 서버 활성 진행/계정/epoch/미정산 거래/보상 대조 및 별도 승인된 복구 절차가 필요하다.
- 최신 원문을 recovery와 id2에 중복 저장하므로 저장 크기/쓰기가 늘어난다. 원장이 커진 실서비스 데이터의 성능 측정은 남는다. 암호학적 변조 방지나 서버 증거가 아니다.
- 이 범위의 로컬 구현에 Firebase 키/서비스 계정/배포는 필요 없다. 구매·보상·기기 이전 운영 연결은 기존 서버 증거 verifier와 활성 진행 연결 담당에게 인계한다. 외부 설정 누락을 이유로 로컬 작업을 미루지 않았다.
