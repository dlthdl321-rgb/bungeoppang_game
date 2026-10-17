# 3단계 인계 — 직원3 / 손님·관계·주문·재고

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
