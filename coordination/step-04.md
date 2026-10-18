# 4단계 인계 — 서버 구매·복구와 보상 광고 검증

- 기준 커밋: `9108513` (main). 브랜치: `staff-04/server-verification`.
- 별도 worktree: `../bungeoppang-step-04`. 원본 작업 폴더의 미커밋 결정 문서와 android/build/firebase/ios는 이동·수정하지 않았다.
- 관련 작업: P1-007, P1-008, P3-007, P3-008. tasks.json 및 자동 생성 CHECKLIST/진행현황은 수정하지 않았다.
- 현재 단계는 서버 소스/로컬 검증 기반이다. 실제 서비스·실기기·출시 완료가 아니다.

## 확인한 기존 구현과 보완

기존 인증은 Firebase custom token의 provider=kakao 및 UID를 사용한다. 요청 account를 인증 UID로 대조하고, 진행 claim/epoch와 구매 pending 잠금으로 다른 진행의 변경을 차단한다. Firestore 클라이언트 read/write는 모두 거부한다. App Check는 현재 options.enforceAppCheck=false로 운영 보안 검토가 남는다. App Check만으로 생산/차감 증거를 대체할 수 없다.

서버 생성 설정의 revision·상품·실제 서버 보유 회차로 두 재화 가격을 재계산한다. 일반 재화는 신뢰된 보호 스냅샷의 현재 잔액, 해금은 누적·레벨, 황금은 서버 현재 지갑으로 검사한다. 황금 홀드/원장/잠금은 같은 트랜잭션, 확정은 보유 회차와 원장, 취소는 환불과 원장을 함께 기록한다. 새로운 지갑이나 클라이언트 황금 생성은 추가하지 않았다.

보완: 동일 거래 재시도는 기존 원장을 먼저 확인한다. reserve 재시도 및 terminal commit 재시도는 일시적으로 사라진 검증 증거 때문에 복구가 막히지 않는다. 다른 견적/계정/진행은 계속 거부하고, 실제 reserved→committed 변경은 debit 증거를 요구한다. 사전 조회 뒤에도 쓰기 트랜잭션 안에서 활성 epoch/원장/잠금을 재대조한다.

보완: callable 취소는 단순히 debit 증거가 없다는 이유로 환불하지 않는다. 신뢰된 파이프라인의 cancellation 증거를 요구한다. 아직 보호 파이프라인이 없으므로 실제 취소도 대기/차단하며 가짜 성공으로 바꾸지 않는다.

보완: `admob_ssv.ts`에 원본 escaped query의 ECDSA SHA256/DER 검증, 고정 HTTPS 공개키 공급원, 23시간 키 캐시, 중복 파라미터·변조·알 수 없는 키 거부를 구현했다. 키 조회 실패/만료는 지급 실패로 닫힌다. `workshopAdSsv` HTTP 수신점은 별도 OFF gate와 광고단위 allowlist를 사용한다. 서명 검증 후 opaque customData 토큰 인덱스로 계정/시도/revision을 결정한다. user_id나 클라이언트 완료 콜백으로 계정/지급을 승인하지 않는다. 공급자 보상 수량 대신 시작 승인에 저장된 서버 임시 보상을 사용한다.

기존 광고 한도는 계정별 KST 자정·서버 시작일에 귀속한다. reserved/verifying도 슬롯을 점유하고 날짜가 지나도 자동 해제하지 않는다. 영구 거절만 슬롯 해제하며 늦은 성공과 충돌하면 거부한다. provider+transaction 전역 해시 원장이 다른 시도/계정의 재사용을 차단한다. 검증 기록과 실제 지급 사이에 장애가 나면 adQuery가 earned 원장으로 한 번만 지급/복구한다. 이 정책을 변경하지 않았다.

## 클라이언트 연결 계약

- 구매 context: `{progress,epoch}`. reserve/commit에는 기존 intent `{account,transaction,revision,skill,owned,quantity,buns,gold}`. query/cancel에는 transaction. 금액은 10진 문자열, 회차·수량은 안전한 정수다.
- 구매 응답: account/transaction 및 status=unknown/reserved/committed/canceled. 존재하는 원장은 기존 견적과 receiptId/grantId를 돌려준다. committed만 상품 grant를 적용하고 canceled는 같은 거래의 로컬 차감 복구를 마무리한다. 네트워크 예외를 성공으로 취급하지 않는다.
- 취소 증거 문서: `users/{uid}/workshopEvidence/cancellation_{transaction}`. 필수 source=trustedServerValidation, verifierVersion=1, account/progress/epoch/transaction/fingerprint(기존 purchaseFingerprint), debitFenced=true, localDebitRestored=true. 클라이언트가 작성할 수 없다. 보호 검증기는 늦은 차감/확정 경로를 영구 차단하고 차감 없음 또는 복원 가능 상태를 검증한 뒤 작성해야 한다. 현재 앱 저널은 canceled 영수증 후 restored를 기록하므로 localDebitRestored는 클라이언트 플래그 복사가 아닌 보호된 복원 권위의 증거여야 한다. 이 원자적 보호 파이프라인 구현/통합은 운영 전 필수다.
- adStart `{attempt}` → 기존 account/attempt/revision/day/startedAtMs/gold/status 및 customData. 동일 ID는 다음날 재시도해도 원래 승인일/토큰이다. customData를 SDK SSV 옵션에 설정한 뒤 광고를 표시한다. 실패 시 임의 새 ID를 반복 생성하지 않는다.
- adQuery `{attempt}` → unknown 또는 reserved/verifying/rejectedFinal + paid=false, verified + paid=true/receiptId. paid=true는 서버 지급 원장 반영 완료이며 클라이언트가 gold를 다시 생성하는 명령이 아니다. SDK 완료/닫힘은 pending 해소 근거가 아니다.
- callable 오류 details: transaction-retry/aborted/retryable=true, service-unavailable/unavailable/retryable=true, evidence-required/failed-precondition/retryable=false, request-or-evidence-required 또는 state-check-required/failed-precondition/retryable=false. 후자는 자동 반복 대신 동일 거래 조회·증거 검토가 필요하다. 인증 오류는 기존 unauthenticated/permission-denied를 유지한다. 광고 gate는 ads-disabled/failed-precondition/retryable=false다. 기존 전체 workshop OFF/판매 키 설정 HttpsError는 details가 없을 수 있어 코드 기반 fallback을 유지한다.
- HTTP SSV는 raw originalUrl 쿼리로 검증한다. 성공/동일 재전송은 200, 검증 거부는 400, 비활성/설정·키·저장소 일시 장애는 503. 수신점은 서명 쿼리·토큰·계정을 응답/로그에 쓰지 않는다. 인프라 요청 로그의 쿼리 수집 제한도 운영 설정에서 검토한다.

## 변경 파일과 통합 순서

1. 신규 모듈 admob_ssv.ts, workshop_errors.ts 및 테스트를 먼저 반영한다.
2. composite_purchases.ts의 원장 우선 복구, workshop_service.ts의 cancellation 증거 검사를 반영한다.
3. 공통 파일 index.ts는 import/오류 매핑/광고 시작 gate/SSV export 부분만 수동 통합한다. 다른 담당 callable 변경을 덮어쓰지 않는다. workshop_ads.ts는 구현 위치 주석만 갱신했다.
4. 클라이언트 담당은 기존 WorkshopOnline/구매 저널/CAS 저장을 유지하며 취소 대기 및 오류 details 연결을 확인한다. controller/모델/저장 스키마/main/의존성 파일은 이번에 수정하지 않았다.

## 운영 전 외부 설정과 남은 연결

- 기본 `WORKSHOP_ONLINE_ENABLED` 미설정/OFF 유지. 판매 보상 키는 기존 `WORKSHOP_SALE_DRAW_KEY_BASE64`를 비밀 관리·함수 바인딩 방식으로 준비한다. 값은 이 문서에 기록하지 않는다.
- 광고는 추가로 `WORKSHOP_AD_SSV_ENABLED=true` 및 `WORKSHOP_ADMOB_AD_UNITS`(서명 콜백 ad_unit과 정확히 일치하는 값들의 allowlist)가 필요하다. 승인/검수 없이 켜지 않는다. 광고 시작도 이 설정이 없으면 막는다. adQuery 복구 경로는 별도 광고 OFF로 막지 않는다.
- Firebase 프로젝트/서울 리전/Firestore·규칙·인덱스/IAM, 카카오 custom 인증, 보호된 스냅샷·저널의 권위·CAS/epoch 이전 파이프라인과 cancellation fencing, 운영 App Check 설정/남용 방지 검토가 필요하다.
- AdMob 앱·보상형 광고단위·HTTPS SSV callback URL 등록, SDK customData 연결, 테스트 도구/테스트 광고의 실제 서명 요청, 키 서버 outbound HTTPS, 데이터 수집/동의/스토어 선언 검토가 필요하다. 공개키 실패 시 클라이언트 승인으로 대체하지 않는다.
- Node22 실제 런타임, Firestore 에뮬레이터의 동시 예약/CAS 재시도, 계정 전환·자정·중복 SSV·지급 후 앱 저장 실패·실기기 검수가 필요하다. 메모리 저장소 테스트는 실제 Firestore 경합 검증을 대체하지 않는다.
- 실제 배포·유료 서비스·운영 전환은 이번 작업에서 수행하지 않았다.

## 검증 근거

검증 명령과 최종 결과는 아래에 추가한다. 설치 중 1차 npm test는 tsc 실행파일 미준비로 실패했고, 설치 중 직접 tsc도 googleapis 미설치로 실패했다. 이를 통과 기록으로 사용하지 않는다.

참조: [AdMob 공식 SSV 문서](https://developers.google.com/admob/android/ssv), 2026-10-18 확인. 원본 서명 바이트 보존·공개키 회전/24시간 이내 캐시 기준에 맞춰 구현했다. 로컬 생성 테스트 키의 성공은 실제 AdMob 요청 검수 완료를 뜻하지 않는다.

- `npm.cmd ci --ignore-scripts --no-audit --no-fund`: 성공, 잠금 파일 변경 없음. 설치 중 Node22 요구 대비 호스트 Node v24.19.0 경고가 있었다.
- `node node_modules/typescript/bin/tsc`: 의존성 설치 완료 후 성공(종료 0).
- `npm.cmd test`: TypeScript 빌드 및 서버 테스트 64개 성공, 실패/건너뜀 0 (최종 오류 계약 회귀 테스트 추가 전).
- `node --test "lib/test/*.test.js"`: 별도 실행 64개 성공, 실패 0. 메모리 트랜잭션 저장소 및 로컬 생성 ECDSA 키를 사용한다.
- 공개키 HTTPS smoke: 고정 `https://www.gstatic.com/admob/reward/verifier-keys.json` 조회/Node crypto 파싱 성공. 키 1개, prime256v1. 실제 광고 서명 요청은 아니다.
- `git diff --check`: 성공. 초기 줄바꿈 차이는 수정했고 기존 index.ts 줄바꿈은 가능한 그대로 보존했다.
- Firestore/Functions 에뮬레이터: 실행하지 않음. `Get-Command firebase` 결과 CLI가 없으며 에뮬레이터 설정/프로세스도 준비하지 않았다. 실제 Firestore 경합·IAM·HTTP/Auth 통합 검수는 남는다.
- Flutter/controller/UI·실제 구매·AdMob 테스트 광고·실기기·서비스 배포: 실행하지 않음. 담당 범위 밖 또는 외부 프로젝트/광고단위/보호 파이프라인 연결이 필요하다.
- 최종 `npm.cmd test`: 종료 0, TypeScript 빌드 및 서버 테스트 **65개 통과**, 실패/취소/건너뜀 0. 오래된 epoch 등 도메인 오류의 재시도 분류 회귀 테스트를 포함한다(Node v24.19.0).
- 최종 `git diff --cached --check`: 성공. 브랜치 통합 시 index.ts와 MASTER.md는 다른 담당 변경과 수동 병합한다.

## 후속 실행 — 서명 스냅샷 검증과 Node 22 (2026-10-18)

기존 인계의 ‘파이프라인 없음’은 아래 구현으로 일부 보완됐다. **실제 게임 이벤트를 검증하고 서명하는 발급 서버 연결은 여전히 없다.** 서명 수신 모듈의 존재를 실제 게임 사실 검증 완료로 확대하지 않는다.

- `protected_purchase_pipeline.ts`: 서버에 등록된 Ed25519 공개키만 허용한다. 기기 키·클라이언트 debited/restored 플래그·해시 일치로 승인하지 않는다. 서버 서명된 checkpoint/reservation/debit/cancellation을 계정·활성 진행 epoch·순번·이전 digest로 검증하고, head/event/evidence를 같은 Firestore 트랜잭션에 기록한다.
- 고정 audience=`workshop-purchase-v1`, schema=1. envelope는 `{keyId,payload,signature}`이며 payload의 원본 UTF-8 바이트를 검증한다. 서명은 base64url Ed25519 64바이트다. payload는 account/progress/epoch/eventId/sequence/previousDigest/issuedAtMs/expiresAtMs/action/snapshot, 구매 단계에는 기존 intent를 포함한다. snapshot은 `{buns,lifetimeBuns,level}`이다. 신규 이벤트 유효기간은 최대15분이고, 승인된 동일 이벤트 재전송은 만료 뒤에도 저장 원장과 대조해 복구한다.
- 최초 checkpoint는 sequence=0/previousDigest 빈 문자열이며, 서버 발급자 검증 없는 로컬 세이브를 자동으로 신뢰하지 않는다. reservation은 현 보호 스냅샷과 일치해야 하고 서버 가격/회차/두 잔액을 확인한다. debit은 정확히 일반 비용만 차감하고 누적/레벨을 바꿀 수 없다. cancellation은 원래 보호 잔액으로 복원된 서버 서명이 있어야 한다.
- 취소 증거 생성과 commit이 경합하면 core가 같은 쓰기 트랜잭션에서 cancellation fence를 읽는다. committed 이후 취소 증거 생성은 거부한다. 예약 이전의 취소 증거도 뒤늦은 reserve를 차단한다.
- `workshopProtectedSnapshotIngest` callable을 추가했다. 기존 전체 OFF gate 외에 `WORKSHOP_PROTECTION_ENABLED=true`, `WORKSHOP_SNAPSHOT_VALIDATOR_KEYS_JSON`(keyId→{pem,notBeforeMs,notAfterMs}, 공개키만)이 있어야 한다. 서명 발급용 비밀키를 앱·저장소·이 문서에 넣지 않는다. 키를 설정하는 것만으로 미검증 게임 이벤트를 서명해서는 안 된다.
- `firestore_store.ts`로 기존 production Store adapter를 추출해 에뮬레이터도 같은 adapter를 사용한다. index.ts는 import/기존 함수 제거/보호 callable 추가 및 Play Android Publisher 전용 SDK import로 변경했다. 모든 Google API 타입을 한 번에 불러오던 부분을 줄였으며 Play 상품/소비 동작은 바꾸지 않았다. 통합 시 다른 담당의 index.ts 변경과 수동 병합한다.
- `firebase.emulator.json`: demo-workshop-step04 전용, auth19099/firestore18084/functions15004, 모두127.0.0.1. 운영 firebase.json은 수정하지 않았다. 통합 테스트는 demo 프로젝트·고정 loopback 호스트를 강제하고 해당 에뮬레이터의 테스트 문서만 초기화한다.
- `run_emulator_checks.ps1`: Node22·Firebase CLI·Java21 경로를 받아 빌드/단위/에뮬레이터 검사를 실행한다. 자신의 프로세스에서 OFF 환경을 강제하고 끝나면 환경을 복원한다. 실제 프로젝트에 배포하거나 유료 API를 호출하지 않는다.

### 확인된 환경과 현재 검증

- Node22.23.3을 공식 npm node 패키지에서 준비했다. Node22로 tsc 빌드 및 서버 테스트 **70개 통과**, 실패/건너뜀0. 서명 위조/다른 계정/만료/롤백/순번 충돌/잘못된 차감/취소 후 늦은 확정 검사를 포함한다. 서명 감사 원장 보완 후 최종 재검사는 별도 결과를 아래에 기록한다.
- Java21은 Adoptium 공식 API의 SHA256과 대조한 Temurin21.0.12.1 JRE다. 한글 사용자 경로에서는 launcher가 java.dll을 찾지 못했으며, 별도 ASCII 도구 경로 `C:/Users/Public/codex-workshop-step04-tools/java21/`에서는 `java -version` 실행에 성공했다. 프로젝트 코드/운영 서버 런타임 변경이 아니다.
- Firebase CLI 다운로드 중 ENOSPC 실패를 확인했다. 작업자가 만든 개별 중복 압축 파일·실패 파일만 삭제했다. 동적 경로의 재귀 정리 명령은 자동 승인 정책에 차단돼 실행되지 않았다. 다른 작업자의 소스·빌드·미커밋 파일은 삭제하지 않았다.
- 실제 Firebase 설정은 예시 `.firebaserc.example`뿐이며 실제 프로젝트 설정은 발견하지 못했다. 브라우저 도구는 처음 시간 초과, 재조회에서 apps=[]/browsers=[]였다. 따라서 실제 Firebase·AdMob 계정/광고단위는 확인되지 않았다.
- 실제 발급 서버·KMS/키의 소유 계정·게임 이벤트 검증 source와 클라이언트 서명 envelope 중계 연결, 실제 AdMob SDK/동의/스토어/기기, 운영 IAM/App Check/과금·배포는 미완료다. 키를 임의 생성해 실제 서비스가 검증된 것처럼 켜지 않는다.

### 취소 복구·초기화 후속

서버 홀드 이전에 실패한 승인 의도도 신뢰된 취소 서명+CAS+원장/잠금 부재를 같은 트랜잭션에서 확인한 경우에만 차감 없는 canceled tombstone을 생성한다. unknown 응답 자체를 취소/환불로 바꾸지 않는다. 원장/홀드 없이 환불하거나 상품을 지급하지 않으며, 뒤늦은 reserve/commit도 이 terminal 결과를 재사용한다.

Functions 기본10초 discovery에서 실제 로드 실패를 확인했다. 표시된 ‘All emulators ready’만으로 성공으로 세지 않았다. Play API는 `play_purchases.ts`에서 실제 결제 호출 때만 로드하도록 분리하고 Firestore Store도 최초 사용 시 client를 생성하도록 지연했다. 기존 Play 상품/상태/consume 계약과 gold 지갑은 유지한다. `index.ts` 통합에는 이 두 초기화 변경도 포함해야 한다.

로컬 검증 스크립트는 CI/비대화 모드와 기본120초 `FUNCTIONS_DISCOVERY_TIMEOUT`을 사용한다. 이는 로컬 함수 발견 대기이며 구매·광고 검증을 생략하지 않는다. 기본10초 성공이나 운영 콜드스타트 성능 통과를 의미하지 않는다. [Firebase 공식 초기화/Discovery Timeout 지침](https://firebase.google.com/docs/functions/tips#avoid_deployment_timeouts_during_initialization)을 참조했다. 실제 HTTP 검사 결과와 최종 빌드 결과는 아래에 별도 기록한다.

추가 공통 파일 주의: firestore_store.ts의 lazy wrapper와 play_purchases.ts를 먼저 넣고 index.ts의 store/db 접근 및 Play factory 사용 부분을 병합한다. SDK 의존성·잠금 파일은 수정하지 않았다.

- Additional verification: Node22.23.3 TypeScript build + 73 server tests passed (0 failures/skips) after lazy Firestore and Play initialization.
- Firestore emulator1.22.0 on Java21: 5 concurrency/security cases passed; a separate pre-hold cancellation recovery case also passed. First contention case logged lock timeouts and SDK retries before converging; it took about603s and is not a production latency guarantee.
- Actual service connection discovery: official Firebase plugin is available but was not installed at the last confirmed check. A connection suggestion was made. No cloud account, project, deployment or billing change has been performed.

### 최종 로컬 검증 결과 (2026-10-18)

- Node22.23.3 `node node_modules/typescript/bin/tsc` + `node --test --test-reporter=spec lib/test/*.test.js`: **빌드 성공, 73개 통과 / 실패0 / 건너뜀0**. Play SDK 지연 초기화와 최종 lazy Firestore adapter를 포함한 코드다.
- Firebase CLI15.34.0/Temurin21.0.12.1/Firestore emulator1.22.0/Auth+Functions emulator, 실제 Node22 runtime: **최종 통합 7개 모두 통과 / 실패0 / 건너뜀0**, 약136.8초. 검사 파일은 `functions/test/emulator/workshop.integration.ts`다.
- 통합 실행: `GCLOUD_PROJECT=demo-workshop-step04`, `FIRESTORE_EMULATOR_HOST=127.0.0.1:18084`, `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099`인 별도 셸에서 `node --test --test-reporter=spec lib/test/emulator/workshop.integration.js`. 설정은 모두 프로세스 한정이며 실제 프로젝트/기기/계정 설정을 바꾸지 않았다.
- 실제 HTTP 근거: 익명 callable 401, Auth emulator의 custom 로그인(provider=kakao) 후 전체 OFF callable 400/FAILED_PRECONDITION, SSV OFF 503 확인. SDK 완료 JSON으로 지급하는 테스트 우회는 없다. Auth emulator의 테스트 토큰은 코드/문서에 저장하지 않았다.
- Firestore 최종 검사: 동일 서명/구매 재요청의 1회 홀드/상품, snapshot fork CAS 1개만 승인, 취소 fence와 commit 경합 시 환불+상품 중복 없음, 광고2회/동일 provider 거래 1회 지급/KST 시작일 유지, 직접 client 증거 쓰기/보호 문서 읽기 거부, 홀드 전 취소 tombstone의 0환불을 확인했다.
- 초기 시험의 transaction lock timeout은 SDK 재시도로 수렴했고, 최종 재실행은 첫 동시성 케이스 약23.2초였다. 운영 지연/가용성 SLO 검수는 아니다.
- 로컬 Functions 발견은 초기10초 실패 후 초기화 지연 및 `FUNCTIONS_DISCOVERY_TIMEOUT=120`로 재시도했다. 최종 정의 로드와 HTTP 응답을 확인했다. 로컬 대기 연장·CI/비대화 모드 사용은 운영 시간 제한이나 보상 검증 완화가 아니다.
- `run_emulator_checks.ps1`은 동일 빌드/테스트 명령을 재현하는 도구다. 이번 실행은 Firestore 단독 프로세스와 Auth/Functions 프로세스를 분리해 띄운 뒤 최종 7개를 함께 실행했다. 스크립트 전체를 단일 명령으로 실행했다고 기록하지 않는다.
- 완료한 것은 서버 검증 수신/구매·광고 복구 기반 및 로컬 검증이다. **실제 게임 사실 검증·서명 발급 서버, 클라이언트 envelope 중계, Firebase/AdMob 실제 계정·SDK·공식 SSV 요청·동의/스토어·실기기·운영 전환은 미완료**다. 실제 서비스가 검증됐다고 완료 처리하거나 OFF를 켜지 않는다.
- 최신 연결 확인에서 공식 Firebase 플러그인은 available/installed=false였다. 설치 안내를 제공했으나 설치/연결을 확인하지 못했다. 프로젝트 ID/비밀값을 사용자에게 추측해 입력하게 하지 않고 설치/연결 후 계정의 실제 프로젝트를 조회하는 지점에서 이어간다.

### 중단 후 재개와 재현 스크립트 보완 (2026-10-18)

- 작업 시작 기준 `cc6905a`, 브랜치 `staff-04/server-verification`. 사용자 설치 완료 보고는 받았으나 이 채팅에 Firebase 도구가 노출되지 않았고, 로컬 CLI `projects:list --json --non-interactive`는 종료1/인증 필요로 실패했다. 실제 계정·프로젝트 조회 완료로 기록하지 않는다. 사용자의 PowerShell npx.ps1 차단에는 npx.cmd 로그인 명령을 안내했으며 이번 재개 시점에도 CLI 인증은 확인되지 않았다.
- `run_emulator_checks.ps1` 전체를 최초 실행했으나 Firestore Java가 한글 경로의 firestore.rules를 찾지 못해 실패했다. 단위73개는 통과했지만 이 시도는 통합 통과가 아니다.
- 재현 도구를 보완했다. 원본 규칙을 Public 아래 ASCII 경로의 실행별 고유 파일로 복사하고 임시 config에서만 참조한다. 운영 firebase.json/규칙 원본/권한은 바꾸지 않는다. finally에서 이번 실행의 개별 임시 파일만 제거한다. `EmulatorScratchRoot` 인자는 ASCII 절대 경로로 검증한다. 공통 controller/모델/index.ts/스키마/의존성 변경은 없다.
- 실제 성공 명령: 프로세스 한정 `FIREBASE_EMULATORS_PATH=C:/Users/Public/codex-workshop-step04-tools/emulators`, `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./run_emulator_checks.ps1 -Node22Path <기존 Node22 실행파일> -FirebaseCliPath <기존 CLI15.34.0 JS> -Java21Bin <기존 Temurin21 bin>`. 영구 실행 정책 변경 없음. 전체 스크립트 종료0, TypeScript 빌드 성공, 단위73/통합7 통과, 실패·건너뜀0. 통합 약95.0초. Auth/Firestore/Functions를 같은 emulators:exec에서 실행하고 정상 종료했다. 앞선 ‘스크립트 전체 미실행’ 기록은 당시 이력이며 현재는 이 실행 근거로 보완된다.
- 성공 실행 중 부모 DEBUG 설정으로 Firebase CLI가 환경 진단 로그를 출력하는 것을 확인했다. 이후 스크립트에서 DEBUG를 프로세스 한정 해제/복원하도록 추가했다. 이 로그 억제 한 줄은 해당 통합 성공 이후 추가됐으며 별도 전체 재실행은 하지 않았다. 원본 진단 로그는 인계/커밋에 포함하지 않는다.
- 추가 변경 파일: run_emulator_checks.ps1, firebase/README.md, 본 인계, MASTER.md의 실행 도구 설명. 통합 담당은 기존 서버 모듈 뒤에 이 로컬 검증 도구 보완을 적용한다. tasks.json/CHECKLIST.md/진행현황.md 수정 없음.
- 남은 실제 작업은 기존과 동일하다: 실제 게임 이벤트 검증·서명 발급 권위 및 클라이언트 중계, 인증된 Firebase 프로젝트/IAM/App Check, AdMob 광고단위·공식 SSV·SDK/동의·실기기. 로그인만으로 이 항목들이 완료되지는 않는다. 운영 OFF와 미배포 상태를 유지한다.
