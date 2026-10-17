# 온라인 서버

카카오 로그인·랭킹·친구·초대·유료 재화 서버입니다. 오프라인 앱 개발과 단위 테스트에는 실제 서비스 키가 필요하지 않습니다.

```bash
cd 1_app_development/firebase/functions
npm ci
npm test
```

Node.js 22를 사용합니다. `npm test`는 TypeScript 빌드와 서버 단위 테스트를 실행합니다. 함수 소스는 `functions/src`, 테스트는 `functions/test`, Firestore 규칙과 인덱스는 이 폴더에 있습니다.

실제 배포에는 별도 Firebase·카카오·Play 설정이 필요합니다. [보존한 온라인 설정 문서](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/2.1.3_legacy_code_policies_and_online_setup/README.md)를 확인하세요. 문서 정리는 실제 서비스 배포를 뜻하지 않습니다.

## 개발 중인 내부 계약

functions/src/development_contracts.ts는 임시 공통 설정 기반 견적 검증·광고 예약/증거 재사용 방지·보상 심사 결과 저장 코드다. 공개 함수로 등록하지 않았고 실제 황금/grant 지급·업체 서명 검증도 연결하지 않았다. 새 테스트 소스는 미실행이다. [구현 경계와 후속 조건](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/17_구매저널저장과서버검증기반.md).


## 신규 복합 구매·판매 황금 내부 모듈

`functions/src/composite_purchases.ts`는 기존 gold 지갑의 구매금 홀드/확정/취소와 활성 진행 epoch를 같은 트랜잭션에서 처리합니다. `sale_rewards.ts`는 신뢰된 판매 검증 뒤 서버 최초 확정 KST 날짜·초과분 이월 없음·고정 추첨/일일 상한/지갑/지급 원장을 함께 저장합니다. 기존 `earned_gold.ts`와 동일한 earned ID를 사용해 지급 경로 사이의 중복을 방지합니다.

아직 index.ts의 공개 함수나 실제 verifier로 연결하지 않았습니다. 클라이언트의 재고/별점/차감 표식, 로그인·App Check만으로 서버 검증을 대신하면 안 됩니다. 생산/차감 보호 증거와 계정·진행·거래·고정 지문을 검증하는 운영 adapter가 필요합니다. 실제 서비스 호출·테스트·배포는 수행하지 않았습니다. 전체 소스/운영 경계는 [19번 후속 문서](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/19_구매원자저장과복구후속.md)를 따릅니다.

최신 후속: [온라인·광고·꾸미기 연결과 검수 인계](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/20_온라인광고꾸미기연결과검수인계.md). callable은 소스에 연결했지만 기본 비활성이고 실제 서버 검증 파이프라인/광고 SDK·운영 설정과 실행 검수가 남습니다.

## 직원4 서버 검증 후속 (2026-10-18)

구매 원장 우선 복구·신뢰된 취소 증거·실제 ECDSA SSV 검증 모듈과 기본 OFF HTTP 수신점을 추가했다. [4단계 연결 계약과 검증 근거](../../coordination/step-04.md)를 참조한다. 과거의 ‘SSV interface만 존재’ 설명보다 이 후속 소스가 최신이며, 실제 AdMob/서비스 검수와 운영 전환은 여전히 미완료다.

추가 로컬 검증은 `run_emulator_checks.ps1`을 사용한다. Node22Path/FirebaseCliPath/Java21Bin을 지정하며 demo 프로젝트와127.0.0.1 전용 포트를 강제한다. 기본120초 발견 대기를 사용하고 운영 배포·활성화는 하지 않는다. 서버 서명 스냅샷 수신/발급 서버의 구분과 최신 검증 결과는 [4단계 인계](../../coordination/step-04.md)를 따른다.
