# 3단계 인계 — 직원3 / 손님·관계·주문·재고

> 후속 완료 요청에 따른 추가 구현·검증은 맨 아래 「후속 마무리」가 최신이다. 아래 최초56개 검증/미해결 fixture 설명은 최초 커밋 당시 기록이다.

2026-10-18 (KST). 기준 커밋 `9108513a89e83d4dd8f6c0772f6554c844d1e8a0`.
작업 브랜치 `codex/employee3-domain`, 별도 worktree `../bungeoppang-step03`.
기존 작업 폴더의 미커밋 결정 문서·android/build/firebase/ios는 이동·커밋·삭제하지 않았다.
저장소 및 상위 경로에서 적용할 AGENTS.md는 발견되지 않았다. 별도 인계 관례가 없어 본 파일을 사용한다.
tasks.json, CHECKLIST.md, 진행현황.md는 수정하지 않았다. 원장 상태 변경은 통합 담당의 몫이다.

## 기존 구현 확인과 이번 완료 범위

21·22번 및 후속 결정, CHECKLIST의 대상 작업과 실제 소스를 대조했다. 기존 구현을 재작성하지 않았다.

| 대상 | 유지한 기존 구현 | 이번 보완·실행 검증 |
| --- | --- | --- |
| P3-004 | NPC8·상황대사144, 영구 관계와 무기명 방문 분리, 취향 도감 | 콘텐츠 생성물 일치, 대사 조건·실명 비노출 위젯 테스트 |
| P4-006 | 첫 도윤/초기 팥, 하루 신규2명, 기존 단골 우선, 개별 입장 대기, 보유 맛/레벨/취향 주문 | 4영업일8명 소개와 저장 복원, 장면 중 개인 타이머 정지 및 복귀 후 해당 주문만 만료 |
| P4-007 | 보유 레시피의 숙련 전후 주문 제작→제품→판매, 별1~5 품질/신선도 계산 | 주문 ID 지정 납품·선택 재고 검증 API 연결. 잘못 고른 익힘은 무소비·시간 연장 없음 |
| P5-004 | 제작 영업일별 묶음, 준비품 최초 영업일 귀속, age0~4 보존/age5 소멸, 생산 결과 처리 원장 | 경계·준비품 부분 소비/복원·재보관 방지 검증. 미래 묶음은 자동 선택에서 제외 |
| P5-005 | 주문 전량 검증 후 재고·일반 대금·판매 원장·황금 심사 대기·관계를 한 명령으로 저장 | oldest-first 선택기를 순수 함수로 분리, 같은 제작일 ID 순 안정 배정, 복합 행 수량 공유. 종료 주문 재납품·다음 손님 오납 방지 |
| 21·22번 관계/선택 | 일반/선택 상한 분리, 고정 추첨, 개인별 선행 조건, 선택/반응/후일담/재생, 장면 저장·복귀 | 선택 전/반응 중 복원, 같은 선택 재실행 보상1회, 후일담 조건 및1회 소비, 재생 무보상, 판매 저장 실패 재시도 검증 |

접수는 입장부터 타이머, 잘못된 납품은 무소비 재선택, 교환1회/15초 유예 없음이라는 확정을 유지한다.
관계 숫자·빈도·선택 콘텐츠를 새로 확정하거나 조정하지 않았다. 기존 공통 설정은 개발 임시값이다.

## 변경 파일과 충돌 주의

- `1_app_development/lib/development_orders.dart`: `selectCustomerInventory` 추가. 기존 판매 가격/증거/원장 형식은 유지.
- `1_app_development/lib/workshop_controller.dart`: 판매 함수 부근만 변경. `sellToCustomer(orderId, selectedByLine: ...)` 추가, 기존 `sellToFirstCustomer` 유지. 맨 앞 주문 제한 유지.
- `1_app_development/lib/ui/workshop_page.dart`: build 시 첫 주문 ID를 캡처하고 기존 판매 버튼에서 전달하는 두 지점 변경. 오래된 버튼 콜백이 다음 손님을 팔지 않게 한다.
- `1_app_development/test/customer_inventory_contract_test.dart`: 순수 재고/판매 계약 테스트5개 추가.
- `1_app_development/test/workshop_customers_test.dart`: 소개4영업일·선택/후일담 복원 테스트2개 추가.
- `1_app_development/test/workshop_controller_test.dart`: JSON fixture의 `Map<String, dynamic>` 캐스트 수정, 납품 ID·수동 오선택·개별 만료/정지 테스트3개 추가.

공통 controller/UI는 다른 직원의 변경과 충돌 가능성이 있다. 파일 전체를 덮지 말고 판매 함수/버튼 변경만 병합한다.
모델·저장 스키마·main·pubspec·수치 원본·생성물은 변경하지 않았다. 기존 schema4/SQLite4를 그대로 사용한다.

## 제작 엔진·저장 담당 연결 계약

1. 제조 완료 제품은 기존 `ProductBatch(id, flavor, variant, quantity, madeOnBusinessIndex)`로 전달한다. ID는 제조 결과의 안정 ID이며 재시도 때 새로 발급하지 않는다.
2. 실제 영업 중 제품은 `recordResult`; 영업 전 준비품은 index0과 `recordPreparedResult`. 최초 명시적 영업 시작 시 `acceptPrepared(actualBusinessIndex)`. 달력 경과나 같은 날 재영업으로 제품 제작일을 다시 매기지 않는다.
3. 주문 제작은 기존 `startOrderProduction(orderId, flavor)`를 사용한다. 숙련을 판매 선행 조건으로 추가하지 않는다. 제작 중 해당 주문 만료 후 제품이 남으면 일반 재고이며 자동 판매·친밀도 보상은 없다.
4. 납품은 화면/제작 시작 때 캡처한 안정 주문 ID로 `sellToCustomer(orderId)`를 호출한다. 직접 선택은 `selectedByLine: List<Map<batchId, quantity>>`이며 주문 행과1:1이다. 전체 맛/수량/익힘/신선도/재고를 다시 검증하고 실패하면 무소비·유예 없음. 종료 ID는 false이며 다른 손님으로 대체하지 않는다.
5. 선택기 `selectCustomerInventory`는 예약/차감/저장을 하지 않는다. 같은 재고를 두 호출에서 미리 선택해도 납품 명령의 최신 검증과 직렬화가 최종 권한이다. 영속 예약 스키마를 새로 만들지 않았다.
6. 순수 판매 계약은 `CustomerSalesProgress.sell`이다. 같은 판매 ID/같은 요청은 원장 기준 재지급하지 않는다. controller는 이미 종료된 주문의 재호출을 거부한다. 재고 소비·대금/누적·sales·pendingGold·주문 제거·관계는 기존 `command` 저장 하나로 확정한다. 저장 실패 후 `reloadAfterError()`로 동일 주문/제품을 읽고 재시도한다.
7. 저장 담당은 inventory의 dispositions/prepared/bindings, sales 원장과 pendingGold 증거, relationships와 customerScene을 함께 보존한다. 소비/소멸 후 dispositions를 제거하면 제품 부활 방지가 깨진다. 선택 확정·보상·후일담도 같은 원자 저장을 유지한다.
8. 로컬 판매 증거는 서버 황금 발급 권한이 아니다. 서버 검증/영수증 계약은 다른 담당의 기존 연결점을 사용한다. 본 작업에서 황금 직접 지급 없음.

권장 통합 순서: orders 선택기 → controller 판매 명령 → UI 주문 ID 캡처 → 테스트 → 저장/제작 담당의 공통 파일 변경과 병합 후 아래 검증 재실행.

## 실행 검증

작업 디렉터리 `1_app_development`, Windows Flutter SDK `C:/flutter-sdk`, `PUB_CACHE=C:/PubCacheBungeoppang`.

```powershell
C:/flutter-sdk/bin/flutter.bat pub get --offline
C:/flutter-sdk/bin/flutter.bat test --no-pub test/workshop_customers_test.dart test/workshop_controller_test.dart test/development_production_test.dart test/customer_inventory_contract_test.dart test/customer_story_panel_test.dart --reporter expanded
C:/flutter-sdk/bin/dart.bat analyze lib/development_orders.dart lib/development_inventory.dart lib/workshop_controller.dart lib/workshop_customers.dart lib/workshop_customer_events.dart lib/workshop_customer_dialogue.dart lib/ui/workshop_page.dart test/customer_inventory_contract_test.dart test/workshop_customers_test.dart test/workshop_controller_test.dart
python -X utf8 tools/customer_content.py --check
python -X utf8 tools/development_balance.py --check
git diff --check
```

- 의존성 오프라인 복원 성공. pubspec/lock 변경 없음.
- 최종 대상 테스트 **56개 통과**, 실제 Flutter 호스트 실행 결과다. 새 테스트10개 포함. 실기기 검수나 전체 suite 통과와는 다르다.
- 콘텐츠/수치 생성물 검사 성공. Python 기본 인코딩으로 실행 시 UnicodeDecodeError가 있어 `-X utf8`로 재실행했다. 생성물을 수정하지 않았다.
- 대상 Dart 분석 종료코드0: error0·warning0, 스타일 info43개(`curly_braces_in_flow_control_structures`). 무결점 lint 통과를 주장하지 않는다.
- diff 공백 검사 성공.

초기 실행에서 `workshop_controller_test.dart`와 `development_rules_test.dart`는 JSON Map fixture의 동적 `addAll` 타입 오류로 실패했다. 담당 controller fixture만 고쳐 최종56개에 포함했다. `development_rules_test.dart`의 별도 fixture 오류는 남아 있어 전체 suite 통과를 주장하지 않는다. 제작/공통 수치 담당은 해당 파일의 `as Map`/`addAll` 입력 타입을 점검해야 한다.
신규 재고 테스트의 미래 제품 입력에 대한 `expire` 예외 기대도 기존 오류 거부 계약에 맞게 수정 후 통과했다.

## 남은 콘텐츠·외부 검수

- 22번에 이미 남긴 동행·날씨/실제 시간대·정확한 제품 외형·특별 행동과 복장 연출·표정24종 아트는 미구현/미검수 범위다. 근거 없는 대사 조건을 활성화하지 않았다. 144문장 전용 연출 전체 완료를 뜻하지 않는다.
- 실제 앱 실행 조작, 실기기, Android/iOS 빌드, 실제 SQLite 업그레이드/충돌/강제 종료, 전체 테스트 suite, 서버 테스트·운영 황금 심사·실제 광고/결제는 이번에 실행하지 않았다. 호스트 저장 실패 주입·Map 직렬화/복원 테스트를 실기기 검수로 대체하지 않는다.
- 로컬 도메인 테스트에 외부 키/계정 설정은 필요 없다. 실제 SQLite 검수는 앱/기기 환경, 서버 심사는 통합 담당의 Firebase 프로젝트·인증·검증 endpoint 연결이 필요하다. 비밀값은 이 문서에 기록하지 않는다.
- 출시 완료/체감 밸런스/희귀 확률 확정/신규 관계 정책을 선언하지 않는다. 공통 문서 원장 갱신과 다른 직원 변경을 합친 최종 실행 검수는 통합 담당이 수행한다.

## 후속 마무리 — 사용자 전체 진행 요청

최초 커밋 `2503e41`을 유지하고 같은 브랜치에서 이어서 작업했다. 다른 직원 브랜치는 읽기 확인만 했고 main이나 다른 worktree를 덮어쓰지 않았다.

### 추가로 찾고 수정한 실제 누락

1. **태오의 신메뉴 사건 도달 불가:** 이전에는 태오가 항상 팥을 주문해, 새 레시피를 처음 정확히 제공하는 선택 조건을 실제 주문에서 충족할 수 없었다. 별도 `workshop_customer_orders.dart`의 `preferredCustomerFlavor`가 실제 보유한 미경험 신메뉴를 고르고 과거 판매 원장으로 이미 제공한 맛을 제외한다. 미보유/미숙련 맛을 임의로 보유 처리하지 않으며, 첫 도윤 팥과 나머지 인물의 기존 취향 설정은 유지한다. 신규 방문 확률/콘텐츠/관계 정책은 추가하지 않았다.
   기본 관계의 ‘카메라 없는 방문’ 완료가 이후의 신메뉴 사건까지 영구 차단하지 않도록, 미경험 신메뉴 방문에는 촬영 맥락을 부여한다. C 선택의 ‘다음 촬영 때 알려주기’ 후일담도 실제 cameraPresent/photoReminder가 함께 있는 방문으로 생성한다. 일반 방문의 기존 맥락은 유지한다. 태오 사건에는 다른 인물처럼 기본 관계 완료 금지 플래그가 없다는 기존 조건을 따른다.
2. **관계 장면과 입장 후일담의 우선순위:** 후일담이 입장 시 먼저 열려 이미 조건을 만족한 기본 관계 장면을 앞지르는 경로를 고쳤다. `_readyCustomerStory`를 공통으로 사용하여 기존 관계→선택 후일담→새 선택 순서를 유지한다. 후일담은 선택한 날에 소비하지 않고 이후 조건에 맞는 방문까지 보존한다. 동일 매칭 함수를 입장/판매 후에 사용해 조건 분기를 통일했다.
3. **남겨둔 수치 테스트 fixture 타입 오류:** `development_rules_test.dart`의 JSON Map 캐스트3곳을 명시했다. 운영 설정/수치/제작 조건은 수정하지 않았다. 해당11개 테스트 실행 통과.
4. **전체 검증을 막던 기존 컴파일 오류:** `premium_controller.dart`의 `OnlineBackend`/`WorkshopTransport` 타입 교차 접근을 명시적인 nullable transport 변수로 고쳤다. `main.dart`의 WorkshopOnline 생성 인자도 같은 이유로 명시적 타입 캐스트1줄을 적용했다. 지갑 동기화 전후 동일 계정 확인은 유지한다. 직원4/5와 충돌 가능한 공통 파일이므로 해당 작은 hunk만 병합한다. main의 기존 CRLF를 보존했고 새 모듈/기존 도메인 파일은 원래 LF를 유지한다.

추가 파일: `workshop_customer_orders.dart`, `customer_domain_completion_test.dart`, `customer_scene_transaction_test.dart`. 공통 파일의 추가 수정은 controller 취향 선택/장면 우선순위, premium 타입 오류 수정뿐이다.

### 콘텐츠와 검증 범위 구분

- NPC8명 각각 A/B/C/배웅32경로와 기본 관계8경로, 선택 전·후 복원/반복 보상 방지/후일담1회 소비를 실행 검증했다. 기본 관계는 특정 선택 사건 완료를 선행으로 요구하지 않는다.
- 실제 controller에서 영업일 전진→태오 신메뉴 주문 생성→전량 판매→촬영을 잊은 반응 확인→선택 저장 실패 주입→동일 선택 복원/재시도→반응 닫기→다음 영업일 방문 후일담→소비까지 연결해 실행 검증했다. 희귀 추첨은 이 테스트에서만100%로 고정하고 운영 설정은 유지했다.
- 기본 관계가 준비된 방문의 후일담 보류→납품 후 기본 관계 완료→다음 방문 후일담 경로를 추가 검증한다.
- Lv1~50 실제 controller 주문 생성의 보유 맛·맛 종류/전체 수량 한도·개인 대기 설정·특정 익힘/특별 주문 해금 조건을 전 구간 검사한다.
- 처음 남긴 동행/실제 날씨·시간대/표정 아트/외형 연출은 초기 요청의 도메인 기능과 별도인 콘텐츠·표현 확장이다. 이를 새 관계 정책이나 신규 아트 범위로 임의 확정하지 않았다. 현 기능이 제공하지 않는 맥락은 계속 비활성/중립 대사다. 이 항목을 이번 도메인 구현 누락과 혼동하지 않는다.

### 통합 담당 연결점 추가

`preferredCustomerFlavor(npc, config, owned: ..., previouslyServed: ..., firstCustomer: ...)`는 맛 선택만 반환한다. 주문ID·수량/익힘·개인 대기는 기존 주문 생성 명령이 결정한다. `previouslyServed`는 성공 판매 원장의 실제 맛에서 구하며 현재 재고나 단순 방문을 판매 경험으로 세지 않는다. 직원2의 레시피 보유/숙련 변경을 병합할 때 이 구분을 유지한다.

장면 완료는 기존 원자 저장 계약을 사용하며 신규 저장 필드/스키마를 추가하지 않았다. 새 파일→controller 변경→기존 판매 UI 변경→테스트 순으로 통합한다. premium 타입 수정은 별도 작은 hunk로 반영한다.

### 최종 실행 결과

추가 대상 검증 `flutter test --no-pub --concurrency=1 test/customer_domain_completion_test.dart test/customer_scene_transaction_test.dart test/development_rules_test.dart --reporter expanded`: 최초 추가54개 통과. 장면 우선순위 회귀를 더한 최종 전체 실행과 분석 결과는 아래 확정 결과에 기록한다.

전체 테스트 첫 시도는 기존 premium 컴파일 오류를 확인하고 중단했다. 이를 통과로 집계하지 않는다. 수정 후 동시성1의 전체 실행에서 완료한 파일은 보존하고, 진행 중이던 파일과 이후 파일은 동시성2로 나눠 이어갔다. 최신 장면 파일은 다시 포함했다. `step-03-test-audit.json`의 완료30개 파일과 최종23개 파일은 서로 겹치지 않으며, 이 브랜치의 전체53개 테스트 파일을 빠짐없이 구성한다. 첫 실행의 중단된 프로세스 전체를 통과로 표시하지 않고 파일별 완료 근거만 사용한다. 실제 SQLite/기기/운영 서비스 검수와 호스트 테스트 결과는 계속 구분한다.

전체 `dart analyze lib test` 재실행 결과: 타입 오류0, 기존 warning8(미사용 import/선언), info67, 종료코드2. 기존 미사용 코드 정리를 이유로 타 직원 소스를 삭제하지 않았다. 따라서 전체 lint 무경고 통과를 주장하지 않는다.

Android debug 빌드 첫 실행은 GradleWrapperMain 로딩 실패였다. 로컬 Flutter SDK의 wrapper 파일을 이 worktree에 복원하고, 파일 안의 해당 클래스 존재를 확인했으나 한글 경로 재시도도 같은 오류였다. 영문 `R:` 경로를 이 앱 worktree에 임시 연결하고 `GRADLE_USER_HOME=C:/GradleCache`, `PUB_CACHE=C:/PubCacheBungeoppang`으로 실행해 Gradle 단계로 진행했다. 해당 생성 wrapper를 소스 커밋에 추가하지 않았다. 운영 키/서비스 설정은 사용하지 않았다.

### 완료한 코드 커밋

- `2503e41`: 주문 ID 납품·재고 배정·경계 회귀.
- `cc3177b`: 신메뉴 선호·장면 우선순위·NPC8 전 경로 검증·수치 fixture 수정.
- `19d684a`: main/premium의 공통 타입 오류만 분리한 작은 수정.
- `088c668`: 기본 관계 완료 이후 신메뉴/촬영 후일담 맥락과 복원 검증.
- `b1ca187`: 직원5의 기존 음악/설정 테스트 수정 재사용(런타임 변경 없음).

최신 도메인 통합 테스트 `customer_scene_transaction_test.dart` **4개 통과**: 레벨1~50, 장면 우선순위, 기본 관계 완료 전 A 선택, 완료 후 C 선택. 두 선택 모두 저장 실패·복귀·중복 선택·다음 방문 후일담 소비까지 실행했다.
레벨 전 구간 검증의 최초 fixture는 레벨 숫자만 바꿔 승급 원장 정합성 검사에 거부됐다. 테스트의 claimedLevels를 해당 레벨에 맞게 구성했으며 실제 저장 검증이나 승급 명령을 완화하지 않았다. 이 테스트는 주문 생성 검증이고 자연 성장/승급 검증과 구분한다.
최신 도메인 분석(controller/orders helper/추가 테스트) 종료코드0, error0·warning0·style info22. 콘텐츠/수치 생성물 검사 재실행 성공.
최종 공백 검사는 기존 main의 CRLF를 존중하도록 `git -c core.whitespace=trailing-space,space-before-tab,cr-at-eol diff --check`를 사용한다. 줄 끝 형식을 바꿔 공통 파일 전체를 재작성하지 않았다.

전체 회귀에서 발견한 옛 BGM 파일 참조/화면 밖 설정 위젯 접근 실패는 직원5가 이미 수정한 `9d6bb97`의 테스트3개(stage10_feedback, stage14_systems, widget_test)를 그대로 재사용했다. 런타임 오디오/UI를 재작성하지 않았다. 기본 BGM 1개가 아니라 현재6곡·실제 굽기 WAV를 검사하고, 저장/접근성 기대값을 유지한 채 ListView를 실제로 스크롤한다. 통합 브랜치에는 이미 있는 수정이므로 중복 적용하지 않는다.

빌드와 테스트를 같은 worktree에서 병렬 실행한 중간 검증은 `build/native_assets/windows/native_assets.json` 충돌로 시작하지 못했다. 테스트 선택자에 정규식 대신 plain-name을 사용한 별도 시도도 실행 대상0개였다. 둘 다 통과로 집계하지 않는다. 본인 소유 빌드 클라이언트만 취소했고 공유 Gradle daemon/다른 채팅 프로세스는 중단하지 않았다. 이후 테스트→실패 사례 재검증→APK 빌드 순으로 직렬 실행한다.

### 확정한 테스트 결과와 공통 문서

| 검증 | 확정 결과 |
| --- | --- |
| 최초 분할에서 완료한30개 파일 | 219통과·1건너뜀·0실패. 미완료 파일과 최신 장면 파일은 다음 분할에 포함 |
| 최종23개 파일 실행 | 310통과·8실패, 종료1. 실패는 기존 음악1·설정 저장1·큰 글자 설정6 |
| 위8건 최신 파일로 재검증 | 종료0, 8개 모두 통과. 기대값/제품 동작 완화 없음 |
| 전체 고유 사례 합계 | **537통과·1건너뜀**, 기록된 실패 모두 해소. 53개 파일의 전체 집합을 대조함. 단일 전체 실행 종료0 주장 없음 |
| 담당 도메인 관련8개 파일 | 기존56+NPC전경로42+최신장면4+수치규칙11 = **113개 통과** |
| 생성물 검사 | NPC8/대사144/관계8/선택8 및 수치·생성 문서 일치, 종료0 |

재검증 명령:

```powershell
C:/flutter-sdk/bin/flutter.bat test --no-pub --concurrency=2 test/stage10_feedback_test.dart test/stage14_systems_test.dart test/widget_test.dart --name '합성 효과음|설정의 저장|^확대 ' --reporter expanded
```

537 = 219+310+8이며, 단순히 중복 실행한 통과 수를 더한 수치가 아니다. `step-03-test-audit.json`에 분할 파일·실패8개 이름·재검증 해소·집계를 기록했다. 미실행1개는 `no_tracking_sdk_test.dart`의 release merged manifest 검사다. debug 산출물이나 소스 검사를 release/실기기 검수로 대체하지 않았다.

생성물 충돌 이후에는 다른 Flutter 실행을 모두 끝낸 뒤 이 worktree의 build/.dart_tool 절대 경로와 reparse point 여부를 확인하고 `flutter clean`, `flutter pub get --offline`을 실행했다. 원래 main 작업 폴더나 다른 worktree의 build는 삭제하지 않았다. 위 재검증8건은 이 복원 후 실제 호스트 실행 결과다.

CLAUDE.md가 지정한 MASTER.md의 손님 후속 부분에 이번 실행 근거와 인계 링크를 짧게 추가했다. 기존 설정값·공식·화면 배치·저장 형식을 바꾸지 않았다. 이 공통 문서 끝의 추가는 통합 시 직원1/2/5의 다른 추가와 **모두 보존**해야 한다. 원장/자동 문서는 여전히 미변경이다.

### Android debug 최종 빌드 확인

2026-10-18 최종 재실행은 **종료코드0, BUILD SUCCESSFUL in 17m 17s**, 430 tasks(309 executed/121 up-to-date)였다. 앞선 중단 로그를 성공으로 계산하지 않았다. 다른 Flutter 테스트와 동시에 실행하지 않았다.

```powershell
# R: = 이 직원3 worktree의 1_app_development (임시 subst)
# cwd R:/android; PUB_CACHE=C:/PubCacheBungeoppang
# GRADLE_USER_HOME=C:/GradleCache; JAVA_HOME=로컬 Microsoft JDK 17
./gradlew.bat --offline --no-daemon --max-workers=2 '-Ptarget-platform=android-arm64' '-Ptarget=lib/main.dart' '-Pdart-obfuscation=false' '-Ptrack-widget-creation=true' '-Ptree-shake-icons=false' assembleDebug --console=plain
```

- 산출물: `1_app_development/build/app/outputs/apk/debug/app-debug.apk` 및 `outputs/flutter-apk/app-debug.apk`, 각 113194638 bytes.
- SHA256: `B5A1CEB0AB2E4132AA0FAE518D093B0A773BB6267BA072A38C258B310E04C19F`.
- APK ZIP 내부 `AndroidManifest.xml`, `classes.dex`, `lib/arm64-v8a/libflutter.so` 존재 확인. 서명 배포/설치/실기기 실행은 하지 않았다.
- 기존 Kotlin/AGP deprecation 경고가 남는다. 빌드 성공을 release manifest 검사, 실기기 검수, 실제 SQLite 디스크 마이그레이션/강제 종료 복원 검증으로 대체하지 않는다.
- 최종 원본 로그는 로컬 ignored `1_app_development/step03-native-build-final.log`. APK와 빌드 생성물은 커밋하지 않는다. 임시 R: 연결은 빌드 종료 후 해제한다.

직원3 요청 범위의 구현·가능한 로컬 검증·연결 계약 기록은 완료했다. 남은 콘텐츠/외부 검수는 위 구분을 유지하며 통합 담당이 원장과 생성 문서에 반영한다. main으로 직접 병합하거나 다른 직원의 미커밋 변경을 이동하지 않았다.
