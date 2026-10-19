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
