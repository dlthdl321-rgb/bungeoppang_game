# 오늘의 붕어빵 마스터 문서

**[첫 출시 언어·지역과 문구 원칙](../08_개발도구와안드로이드출시.md#한국어-첫-출시와-번역-준비--dec-014-확정)**: 한국어·국내 Android 먼저, 외국어·해외 대응은 후속입니다. 신규/수정 문구는 공통 관리하고 UI 이미지와 글자를 분리합니다. 구현 완료를 뜻하지 않습니다.

**[개발 도구·Android 우선 출시 기준](../08_개발도구와안드로이드출시.md)**: 사용자 확정 개발 방향. 현재 도구를 유지하며 iOS·웹은 후속으로 진행합니다. 설치·구현 완료를 뜻하지 않습니다.

**[신규 기획 문서 안내](../README.md)**: REQ-01~07 및 최신 숙련·영업·주문·재고의 구현 전 기획·기술·작업·검수. 현재 구현과 구분하며 게임 기능 완료를 뜻하지 않습니다.

현재 main은 20장의 신규 Workshop 경로에 21~22장의 구매·복구/온라인·아바타 후속을 적용합니다. 1~15장의 클리커/코인·구형 레벨·환생/DB 설명은 구형 프로토타입 및 설정/계정 포트의 기록이며 신규 게임 규칙의 근거로 사용하지 않습니다.

기능이나 설정을 더하기 전에 먼저 확인하는 기준 문서입니다. 내용은 코드에서 직접 확인한 값입니다(2026-10-16 소스 기준, 저장 형식 v13; 실행 검수 미실행).

- **코드와 이 문서가 다르면 코드가 맞습니다.** 그 경우 이 문서를 고쳐 주세요.
- 설정값을 바꾸거나 기능을 추가했으면 같은 작업에서 이 문서의 해당 표도 함께 고칩니다.
- 줄 번호는 바뀌기 쉬워서 적지 않았습니다. 파일 이름과 상수·함수 이름으로 찾으세요.
- 과거 단계 기록은 정리했으며 온라인 설정 기록은 이 폴더에 보존합니다. 현재 상태는 코드와 최신 기획을 함께 확인하세요.
- 1~15장은 구형 코드 기록, 16장은 당시 목표, 17~20장은 후속 소스와 실제 연결 범위입니다. 현재는20장을 먼저 확인합니다.

## 목차

1. [개발 원칙](#1-개발-원칙)
2. [구조](#2-구조)
3. [저장과 시간](#3-저장과-시간)
4. [경제·스킬](#4-경제스킬)
5. [미션·일일·주간·업적·환생](#5-미션일일주간업적환생)
6. [부스트·황금 찬스](#6-부스트황금-찬스)
7. [꾸미기](#7-꾸미기)
8. [황금 붕어빵(유료)](#8-황금-붕어빵유료)
9. [온라인: 로그인·랭킹·친구·초대](#9-온라인-로그인랭킹친구초대)
10. [화면 배치](#10-화면-배치)
11. [디자인 토큰](#11-디자인-토큰)
12. [이미지·소리](#12-이미지소리)
13. [빌드·실행·테스트](#13-빌드실행테스트)
14. [추가 작업 체크리스트](#14-추가-작업-체크리스트)
15. [알려진 문제](#15-알려진-문제)
16. [기획 중인 변경](#16-기획-중인-변경)

---

## 1. 개발 원칙

| 원칙 | 내용 | 지키는 곳 |
| --- | --- | --- |
| 광고·추적 SDK 금지 | ads, admob, analytics, crashlytics, sentry 등 금지. Firebase는 core/auth/functions/app_check만 허용(app_check는 23번 7단계, Play Integrity). 카카오는 로그인용만 | `test/no_tracking_sdk_test.dart` |
| 손님 알림은 기기 안에서만 | 26번 5-1단계: `flutter_local_notifications`(+`timezone`, UTC만)로 앱이 꺼진 동안 올 손님을 기기 안에 예약. 서버 푸시·Firebase Messaging 없음, 정보를 어디에도 보내지 않음. 권한은 `POST_NOTIFICATIONS`(Android 13+ 실행 중 요청)·`RECEIVE_BOOT_COMPLETED`(재부팅 뒤 재예약)뿐, 정확한 알람 권한(`SCHEDULE_EXACT_ALARM`·`USE_EXACT_ALARM`) 없음(몇 분 늦을 수 있음) | `test/no_tracking_sdk_test.dart`, `lib/customer_notifier.dart` |
| 현실 보상 없음 | 현금·상품·포인트를 지급하지 않음. 공유에도 보상 없음 | README |
| 경제는 BigInt | 가격·생산·보상은 BigInt로 계산하고, 배율은 정수 천분율(‰)로 계산(`effectScale` = 1000). double 금지. 저장할 때는 10진 문자열 | `economy.dart`, `config_values.dart` |
| 코인은 원장으로만 | 모든 코인 변동은 `support.transact(id, …)`/`grantReward`로. id가 중복 지급을 막는 키(`daily:<day>:<id>`, `weekly:<week>:<id>`, `achievement:<id>`, `level:<n>`) | `support_rules.dart` |
| 저장은 원자적으로 | 중요한 명령은 `before = state.copy()` → 변경 → `_commit`. 저장 실패 시 되돌림. 프레임·탭마다 저장 금지 | `game_controller.dart` |
| 시간은 게임 시계로 | `DateTime.now()` 대신 `gameNow`/`observedUtc` 사용. 기기 시계를 되돌려도 지난 날짜·주는 다시 열리지 않음 | `support_state.dart` |
| 키 커밋 금지 | 카카오·Firebase 키를 저장소에 넣지 않음. 앱 키는 `dart_defines/online.json`, 서버 설정은 `firebase/functions/.env`(둘 다 gitignore, 견본만 커밋) | `test/stage16_kakao_ranking_test.dart`, `test/online_setup_test.dart` |
| 테스트 기준 유지 | 테스트 목표나 골든 허용치를 낮추지 않음 | README |
| 개발자 전용 기능 | 초대 시뮬레이터 등은 `developerTools`(= `!kReleaseMode`)일 때만 | `game_controller.dart` |

**바뀔 예정(2026-11-18 결정, 아직 구현 전):** 첫 줄 '광고·추적 SDK 금지'는 26번 5단계에서 **`firebase_analytics`만 허용**(광고 ID·SSAID 수집 끔, 설정에서 끌 수 있음, 그 밖의 분석·광고·오류 수집 SDK는 계속 금지)으로 바뀐다(DEC-045·046). 광고 SDK는 출시 빌드에 넣지 않는다(DEC-028 유지, 출시 후 별도 브랜치 DEC-049). 지금 코드와 `no_tracking_sdk_test`는 위 표 그대로다.

---

## 2. 구조

### 폴더

| 위치 | 내용 |
| --- | --- |
| `lib/*_config.dart` | 조정 가능한 값(밸런스·보상·가격·표) |
| `lib/*_rules.dart` | 상태를 받아 계산만 하는 순수 함수 |
| `lib/*_state.dart`, `lib/models.dart` | 저장되는 상태와 JSON 변환·이전 |
| `lib/game_controller.dart` + `*_controller.dart` | 유일한 `ChangeNotifier`. 다른 controller 파일은 `part`로 붙은 확장 메서드 |
| `lib/ui/` | 화면 |
| `firebase/functions/src/` | 서버 함수(TypeScript) |
| `test/` | 테스트와 골든 |
| `tools/` | 이미지·소리 제작 스크립트, 에뮬레이터 실행 |

### 시작 순서 (`lib/main.dart`)

1. 세로 고정.
2. `withOnline = Android && firebaseConfigured`. 온라인이면 `KakaoSdk.init` 후 `FirebaseOnlineBackend.create()`. 아니면 `NoOnlineBackend`·`NoRankingService`·`NoBillingService`.
3. `GameController(SqliteGameRepository(), SystemTimeService(), …)` 생성.
4. `PixelSprites.load()`로 이미지를 미리 읽음.
5. `controller.initialize()` → 설정 파일 → `WorkshopController.initialize()` → `runApp(GameApp)`. 셋 중 하나라도 읽지 못하면 두 DB를 닫고 `SaveRecoveryApp`(`ui/save_recovery.dart`, 3장 "저장 손상 대처").

`initialize()`는 저장을 읽고, `resume()`으로 오프라인 생산을 정산하고, 100ms 틱 타이머와 10초 자동 저장 타이머를 시작합니다.

### controller 확장 파일

| 파일 | 역할 |
| --- | --- |
| `boost_controller.dart` | 황금 찬스(세션 전용), 손님 방문, 부스트 시작 |
| `online_controller.dart` | 로그인, 친구, 방문, 서버 동기화(2분 간격) |
| `premium_controller.dart` | 황금 붕어빵 결제·사용 |
| `menu_controller.dart` | 꾸미기 구매·착용 |
| `ranking_controller.dart` | 랭킹 조회·제출 |
| `invite_controller.dart` | 초대 |

### 화면이 상태를 받는 방법

- **상태 변경**: 틱(100ms)·탭·커밋마다 `notifyListeners()`. 화면은 `AnimatedBuilder`/`addListener`로 받습니다.
- **한 번만 일어나는 일**: `controller.events` 스트림(`GameEventKind`: purchase, levelUp, missionReward, achievement, boostStarted, prestige). `ui/celebration.dart`가 받아서 소리와 축하 배너를 띄웁니다.
- **미션 달성 알림**: 진행도를 따로 저장하지 않고 매번 상태에서 계산합니다(`missionProgress`, `claimableGoals`).

### 탭 한 번의 흐름

`BakeTarget._bake` → `GameController.tap()` → `tick()`으로 자동 생산 정산 → 콤보·기록 갱신 → 획득량 = `(tapRate × 부스트배율 × 환생배율 + 나머지) ~/ 1000` → `buns`·`lifetime`·`daily` 증가 → `notifyListeners()`. 저장은 10초 주기나 앱을 나갈 때 합니다.

---

## 3. 저장과 시간

### 저장소

| 항목 | 값 |
| --- | --- |
| DB | sqflite `todays_bungeoppang.db` |
| 테이블 | `snapshots(slot, sequence, body)`. 슬롯 `current`, `backup` |
| 저장 형식 버전 | `GameState.formatVersion = 13` (`models.dart`) |
| 밸런스 버전 | `economyBalanceVersion = 3` |
| 보조 시스템 버전 | `supportConfigVersion = 'support-v2'` (v1도 읽음) |
| 주간 버전 | `weeklyConfigVersion = 'weekly-v1'` (다르면 읽기 실패) |
| 프리미엄 | `premiumConfigVersion = 'premium-v1'` |

**저장 시점:** 10초마다, 모든 `_commit`(구매·수령·레벨업·환생·부스트·꾸미기), 설정 변경, 튜토리얼 완료, 앱을 나갈 때(`leaveActive`). 강제 종료 시에는 마지막 저장 이후의 탭이 사라질 수 있습니다.

**검증:** 엄격합니다. 아래처럼 맞지 않으면 `FormatException`이 나고 복구 화면으로 갑니다.
- 코인 원장 합계 ≠ 코인 잔액
- 수령 기록이 있는데 원장에 없음
- 환생 별이 누적 생산으로 가능한 수보다 많음
- 목록에 없는 업적·주간 id

**신규 Workshop 진행 저장**(`lib/workshop_controller.dart` `WorkshopState`, 실제 진입 경로)

| 항목 | 값 |
| --- | --- |
| DB | sqflite `todays_bungeoppang_workshop.db`, `user_version` 4 |
| JSON 저장 형식 | `schema` 7. 1~6을 읽고 7로 저장 (`user_version` 4 그대로, 생산 저널·구매 보호 기록 형식 변경 없음. 구매 보호 저장 검사는 schema 7만 받음) |
| schema 5 (2026-11-09) | 대기 손님 주문의 `deliveries`(부분 판매 기록). schema 4 이하에 있으면 거절 |
| 제작 세션 `session` (CookingSession schema 1, 24번 5단계 G1) | 짤주머니 세 단계의 칠한 양을 **추가 필드**로 저장: `firstBatterCoverage`·`firstBatterAmount`, `fillingCoverage`·`fillingAmount`, `secondBatterCoverage`·`secondBatterAmount`(permille, 단계를 마치면 둘 다 있음, 0 < 덮음 ≤ 1000, 덮음 ≤ 양 ≤ 9000). 예전 `firstBatterMs`·`secondBatterMs`·`fillingDurationMs`는 읽기만 하고 새로 쓰지 않음(같은 단계에 두 종류가 함께 있으면 거절). 단계 완료 = 둘 중 하나가 있음. 예전 저장·진행 중 세션은 그대로 이어서 하고, ms로 끝난 반죽 단계는 손기술 실패. Workshop schema 6·`user_version` 4·생산 저널 형식 변경 없음 |
| schema 6 (2026-11-11) | 첫 실행 안내 `tutorial`: `cook` → `sell` → `done`, 또는 `skipped`. 새 설치는 `cook`. schema 5 이하는 `done`으로 올리고, 그 버전에 `tutorial`이 있으면 거절. 판매 기록이 있는데 `cook`/`sell`이면 거절 |
| schema 7 (2026-11-18, 26번 5-1단계) | 손님 시계 `regularClock`·`namedClock`(`{nextAt: UTC ms 또는 null, seed, draws}`)과 직전 네임드 `lastNamedVisitor`. 7에 셋 중 하나라도 없거나 6 이하에 있으면 거절. 닫힌 가게·안내 중인데 `nextAt`이 있거나, `nextAt`이 정산 시각 + 최대 간격보다 멀면 거절. `lastNamedVisitor`는 만난 손님만. 6 이하 이전: 시드는 진행 ID(`grid.runId`)에서 만들고 시계는 멈춘 채(null) 두어 불러온 뒤 첫 정산 시각부터 셈, `lastNamedVisitor`는 관계 기록의 가장 늦은 방문. `arrivalMs`는 안내 중 손님 간격용으로 그대로 |

**저장 손상 대처** (`lib/main.dart` `_start`, `lib/ui/save_recovery.dart`, `lib/save_quarantine.dart`)

| 단계 | 동작 |
| --- | --- |
| 실패 위치 | 계정 저장(`account`) → 게임 설정 파일(`config`) → 가게 진행 저장(`workshop`) 순서로 읽고, 실패한 곳을 화면과 복사 내용에 표시 |
| 복구 시도 | 처음 화면에는 '복구 시도'와 '오류 내용 복사'만. 계정 저장은 `restoreBackup()` 뒤 다시 읽고, 가게 저장은 다시 읽을 때 최신 증거 복구본으로 되돌아감(「직원 1 저장·영업 수명 후속」 절). 실패하면 시도 횟수를 올려 같은 화면 |
| 처음부터 시작 | 복구 시도가 한 번 이상 실패한 뒤에만 보임. 두 번 확인. 실패한 DB 파일(과 `-wal`/`-shm`/`-journal`)을 지우지 않고 `<이름>.damaged-YYYYMMDD-HHMMSS[-N].db`로 옮긴 뒤 새로 시작. 가게 저장 실패면 가게 DB만, 계정 저장 실패면 계정 DB만 옮김 |
| 설정 파일 오류 | 앱에 들어 있는 파일이라 '처음부터 시작'을 두지 않고 업데이트·재설치 안내 |
| 오류 내용 복사 | 위치·시각(UTC)·복구 시도 횟수·오류 문장을 클립보드로 |

**버전별 이전:** 모두 `GameState.fromJson` 안에서 처리합니다.

| 버전 | 바뀐 내용 |
| --- | --- |
| v1 | 기존 스킬 6종만 존재 |
| v3 | 레벨 보상 기록 |
| v4 | 보조 시스템. 별을 코인으로 1:1 이전 |
| v5 | 초대 |
| v6 | 꾸미기 기본값 |
| v7 | 미션 시즌 이전, 기록·주간·업적 |
| v8 | 소리 설정 |
| v9 | 환생 |
| v10 | 꾸미기 칸: pattern, topping, skin, hair, outfit, hat, tool |
| v11 | 꾸미기 칸: character |
| v12 | 꾸미기 칸: lamp, time, top, bottom, shoes, accessory |
| v13 | 독립 음악 선택·굽기 채널 설정만 추가. 구형 v1~12 파싱/자산 유지, 실제 이전·실행 검수 미실행 |
| (버전 없음) | premium: 키가 없으면 기본값, 잘못된 값이면 오류 |

### 시간 규칙

| 항목 | 값 | 위치 |
| --- | --- | --- |
| 일일 초기화 | 한국 시각 자정(UTC+9 고정, 기기 시간대 무시) | `dailyUtcOffsetMinutes = 540` |
| 주간 초기화 | 한국 시각 월요일 00:00. 받지 않은 주간 보상은 사라짐 | `progress_state.dart` `weekKey` |
| 시계 되돌림 방지 | `support.observedUtc`는 앞으로만 감 | `support_state.dart` |
| 시간 경과 처리 | `observeSupport` 한 곳에서 일·주 넘김과 기록 갱신 | `support_rules.dart` |
| 오프라인 최대 | 8시간 (`maxOfflineMs`) | `balance.dart` |
| 오프라인 효율 | 접속 중 생산의 50%. 일일 생산 목표에는 안 셈(`dailyOfflineCounts = false`) | `support_rules.dart` |
| 돌아오기 환영 창 | 24시간 이상 떠나 있었고 획득량이 있을 때(구형 홈) | `offlineWelcomeAfter` |
| Workshop 복귀 안내 | 영업 시계로 2시간 이상 비웠다가 돌아왔을 때 한 번(앱 다시 열기·백그라운드 복귀 모두). 비운 시간, 영업 중이면 쌓인 붕어빵력(오프라인 효율·상한 함께 표시), 닫혀 있으면 쌓이지 않았다는 문구, '자리 비운 동안 손님 N명이 왔어요.'(0명이면 없음, `welcome-back-arrivals`), 기다리는 손님 수. 판매와 손님 기다림은 앱이 앞에 있을 때만 흐르므로 판매 수는 없음 |
| Workshop 손님 도착 (26번 5-1단계) | 실제 시간. 30장 "손님 방문 간격·알림" | `lib/workshop_arrivals.dart` |
| Workshop 영업일 넘김 (26번 5-1단계) | 영업을 열어 두면 KST 자정 뒤 저절로 다음 영업일(재고 나이·준비품 수락·미션 '영업한 날'까지 영업 시작과 같이). 며칠을 비워도 한 번만 넘김. 닫혀 있으면 지금처럼 '영업 시작' | `BusinessProgress.nextDay`, `WorkshopController._startBusinessDay` | `workshopWelcomeBackAfter`, `WorkshopController.awayReport`, `ui/workshop_guide.dart` `WorkshopWelcomeBackCard` |

---

## 4. 경제·스킬

파일: `lib/economy_config.dart`, `lib/balance.dart`, `lib/economy.dart`

> 18단계 기획: 화면 이름 '붕어빵'을 '붕어빵력'으로 바꾸고, 리얼 붕어빵은 별도 재화로 둡니다([16장](#16-기획-중인-변경)).

### 공식

| 항목 | 공식 |
| --- | --- |
| n번째(0부터) 구매 가격 | `ceil(baseCost × (num/den)^n)`, 정확한 유리수로 계산 |
| 묶음 가격 | 누적합 차이 |
| 최대 구매 | 이진 탐색, 1000 − 보유 수까지 |
| 클릭당 생산 | `1 + Σ(탭 스킬 효과 × 보유 수)` |
| 초당 생산(기본) | `Σ(자동 스킬 효과 × 보유 수)` |
| 실제 생산 | 기본 × 환생배율(1000 + 50×별)/1000 × 부스트배율 |
| 해금 | 누적 생산 ≥ `unlockTotal` (황금 붕어빵 조기 해금은 구형 클리커 경로만, 신규 Workshop에는 없음) |
| 스킬당 최대 보유 | `skillCountLimit = 1000` |
| 숫자 표기 | 1만 미만은 그대로, 이후 만·억·조·경·해·자·양·구·간·정·재·극 단위로 소수점 2자리, 극을 넘으면 x.xxeN |

### 스킬 표

가격 증가율은 1~3단계만 따로 정해져 있고 4~16단계는 모두 115/100입니다. 4단계부터는 가격이 단계마다 10배, 효과는 약 5.65배씩 늘어납니다. 해금 조건은 누적 생산량입니다.

| 단계 | 탭 스킬 | 가격 | 효과 | 해금 | 자동 스킬 | 가격 | 효과/초 | 해금 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 반짝이는 틀 (115/100) | 15 | 1 | 0 | 작은 화로 (115/100) | 50 | 1 | 0 |
| 2 | 진한 반죽 (118/100) | 250 | 8 | 500 | 부지런한 집게 (118/100) | 600 | 10 | 1000 |
| 3 | 노릇한 손놀림 (120/100) | 4000 | 60 | 1만 | 붕어빵 공방 (120/100) | 8000 | 100 | 2만 |
| 4 | 정밀 반죽기 | 1e4 | 600 | 1e4 | 회전 화로 | 2e4 | 1000 | 2e4 |
| 5 | 황동 빵틀 | 1e5 | 3390 | 1e5 | 연속 굽기 | 2e5 | 5650 | 2e5 |
| 6 | 겹겹이 반죽 | 1e6 | 19200 | 1e6 | 증기 공방 | 2e6 | 31900 | 2e6 |
| 7 | 달빛 손길 | 1e7 | 10.8만 | 1e7 | 골목 제빵소 | 2e7 | 18만 | 2e7 |
| 8 | 숙련 뒤집기 | 1e8 | 61.1만 | 1e8 | 도시 제빵소 | 2e8 | 102만 | 2e8 |
| 9 | 별빛 빵틀 | 1e9 | 345만 | 1e9 | 별빛 화로 | 2e9 | 576만 | 2e9 |
| 10 | 금빛 앙금 | 1e10 | 1950만 | 1e10 | 황금 제빵소 | 2e10 | 3250만 | 2e10 |
| 11 | 별무리 손길 | 1e11 | 1.1억 | 1e11 | 성운 공방 | 2e11 | 1.84억 | 2e11 |
| 12 | 유성 빵틀 | 1e12 | 6.23억 | 1e12 | 유성 화로 | 2e12 | 10.4억 | 2e12 |
| 13 | 오로라 반죽 | 1e13 | 35.2억 | 1e13 | 찬란한 공방 | 2e13 | 58.7억 | 2e13 |
| 14 | 태양의 반죽 | 1e14 | 199억 | 1e14 | 태양 제빵소 | 2e14 | 332억 | 2e14 |
| 15 | 우주의 손길 | 1e15 | 1120억 | 1e15 | 우주 제빵소 | 2e15 | 1870억 | 2e15 |
| 16 | 천년 빵틀 | 1e16 | 6350억 | 1e16 | 천년 화로 | 2e16 | 1.06조 | 2e16 |

- 스킬 id는 `tap_1`~`tap_16`, `auto_1`~`auto_16`입니다.
- 4단계부터의 id는 목록 순서로 자동으로 붙습니다. **중간에 끼워 넣거나 순서를 바꾸면 안 됩니다.**
- 목표 밸런스는 Lv.10까지 약 21~22일입니다(`test/economy_simulation_test.dart`).
- 신규 Workshop 경로: 스킬은 붕어빵력+황금붕어빵력 두 재화 가격(`skill_purchase`). **1~4단계(`tap_1`~`tap_4`, `auto_1`~`auto_4`)는 황금 0**이라 붕어빵력만으로 사고 몇 번째든 황금 0, **5~16단계는 황금 2·3·4개(4단계씩) + 10번마다 1개 증가**(DEC-041, 26번 3단계). 황금 공식은 `기본 황금 > 0`일 때만 `기본 황금 + ⌊n / gold_step_purchase_count⌋ × gold_step_amount`, 기본 황금이 0이면 0(앱 `lib/development_rules.dart` `quoteCompositeSkill`, 서버 `development_contracts.ts` `validateDevelopmentCompositeQuote` 같은 식). 황금 0은 스킬에만 허용하고 꾸미기·부스트는 계속 황금 1 이상이어야 한다(설정 검사 `lib/development_balance.dart`·`tools/development_balance.py`, 저널 `PurchaseJournal.start`, 영수증 `compositeReceiptMatches`, 서버 `parseCompositeIntent`).
- 성장 확인(`test/workshop_progression_simulation_test.dart`, 탭 2회/초·1분 1판매·가장 싼 스킬부터 분당 3개까지 구매): 황금 0인 서버로 Lv.5 4분·Lv.10 9분, 스킬 황금 소비 0. 첫 황금 스킬인 5단계는 탭 Lv.15·자동 Lv.19에서 열림(탭 1회/초면 Lv.17·21). 환영 황금(`welcome_reward.gold` = 10)은 스킬에 쓰이지 않고 꾸미기(가장 싼 유료 아바타 황금 2)에 쓴다. Lv.1~5 승급은 스킬 없이 30분 안에 가능([23장](#23-서버-타당성-검증과-환영-황금--2026-11-03)). 손님 간격이 바뀌면(5-1단계) 다시 확인한다.
- 스킬 창(`lib/ui/workshop_windows.dart` `WorkshopSkillShop`): 황금 0이면 버튼·자세히 보기에 황금 줄을 숨기고 '붕어빵력만 있으면 돼요.', 맨 위에 '1~N단계 스킬은 붕어빵력만으로 레벨업해요…'(N은 설정에서 계산). 온라인 빌드에서 로그인 전이면 '카카오 로그인 후 레벨업할 수 있어요.' + '카카오 로그인' 버튼(`GameController.signInOnline`). 로그인 전 `purchaseSkill`은 거래를 만들지 않고 같은 안내만 남긴다. 모양 개편('+' 레벨업 등)은 26번 4-3단계.

---

## 5. 미션·일일·주간·업적·환생

### 레벨 미션 (`lib/mission_config.dart`)

- 현재 시즌은 `offline-v1`(`offlineLevels`)입니다. 과거 시즌 `public-reviews-2025-12-v1`은 옛 저장 데이터용으로 남겨 둡니다.
- 레벨업 보상은 기본 3코인입니다(Lv.1은 0).
- 레벨업은 직접 받기 버튼으로 합니다(`claimLevelUp`). 자동 레벨업은 꺼져 있습니다.

| 레벨 | 조건 |
| --- | --- |
| 1 | 없음 |
| 2 | 굽기 안내 확인 1 + 누적 생산 10 |
| 3 | 초당 1 |
| 4 | 황금 찬스 잡기 1 |
| 5 | 초당 5000 + 기본 외 꾸미기 1개 보유 |
| 6 | 초당 4억 |
| 7 | 초당 160억 + 부스트 누적 사용 5 |
| 8 | 초당 8000억 |
| 9 | 초당 5조 + 성운 공방(`auto_11`) 보유 |
| 10 | 초당 20조 + 업적 12개 달성 |

미션 종류(`MissionKind`)는 tutorial, lifetime, autoRate, goldenCatches, cosmeticsOwned, boostUses, skillLevel, achievements, newPlayerInvites(과거 시즌 전용)입니다.

### 일일 미션 (`lib/support_config.dart` `dailyDefinitions`)

| id | 내용 | 목표 | 보상 |
| --- | --- | --- | --- |
| taps | 붕어빵 탭 | 50 | 2코인 |
| production | 오늘 붕어빵 생산 | 1000 | 3코인 |
| purchases | 스킬 구매 수량 | 3 | 2코인 |
| auto | 기본 초당 생산 | 10 | 3코인 |
| (전체 완료) | | | 10코인 (`dailyAllReward`) |

초당 생산 목표는 부스트를 뺀 기본 생산량의 최고치로 판정합니다.

### 주간 도전 (`lib/weekly_config.dart` `weeklyGoals`)

| id | 내용 | 목표 | 보상 |
| --- | --- | --- | --- |
| taps | 탭으로 1,000번 굽기 | 1000 | 3코인 |
| days | 3일 동안 노점 열기 | 3 | 3코인 |
| purchases | 스킬 20개 구매 | 20 | 3코인 |
| dailyAll | 일일 미션 전체 완료 3회 | 3 | 7코인 |

주간 테마 문구와 배너는 그 주가 시작된 달(한국 시각)로 정합니다.

| 달 | 테마 | 배너 |
| --- | --- | --- |
| 3~5월 | 벚꽃 노점 주간 | `event/spring.png` |
| 6~8월 | 여름밤 노점 주간 | `event/summer.png` |
| 9~11월 | 단풍 골목 주간 | `event/autumn.png` |
| 그 외 | 첫눈 붕어빵 주간 | `event/winter.png` |

### 업적 (`lib/achievement_config.dart`, 24개)

| id | 조건 | 보상 |
| --- | --- | --- |
| bake-1 / bake-100 / bake-1e4 / bake-1e8 | 누적 생산 1 / 100 / 1만 / 1억 | 1 / 1 / 2 / 3코인 |
| bake-1e12 | 누적 생산 1조 | 칭호 '조 단위 제빵사' |
| bake-1e16 | 누적 생산 1경 | 5코인 |
| auto-100 / auto-1e8 | 최고 초당 생산 100 / 1억 | 2 / 3코인 |
| level-5 / level-10 | 레벨 5 / 10 | 3코인 / 칭호 '골목 명장' |
| taps-1000 | 누적 탭 1000 | 2코인 |
| combo-50 | 최고 콤보 50 | 칭호 '번개손' |
| items-10 | 부스트 사용 10 | 2코인 |
| cosmetics-5 / cosmetics-all | 꾸미기 5개 / 전부 | 3코인 / 칭호 '수집가' |
| days-7 / days-30 | 플레이 일수 7 / 30 | 3코인 / 칭호 '단골' |
| weekly-1 | 주간 도전 완료 1 | 3코인 |
| daily-all-10 | 일일 전체 완료 10 | 3코인 |
| record-1 | 하루 생산 신기록 1 | 3코인 |
| prestige-1 | 환생 1회 | 칭호 '노점 개척자' |
| stars-10 | 별 10개 | 5코인 |
| avatar-5 / fish-5 | 아바타 꾸미기 5 / 붕어빵 꾸미기 5 | 3코인 / 3코인 |

콤보 규칙(같은 파일)은 이렇습니다.
- 탭 간격이 1000ms 이하면 콤보가 이어집니다(`comboWindowMilliseconds`). 누르고 있기로 반복된 탭은 제외합니다.
- 콤보가 5 이상일 때 화면에 표시합니다.
- 콤보 보너스는 꺼져 있습니다(`feedback_config.dart` `comboBonus`).

### 환생 "새 노점 열기" (`lib/prestige_config.dart`, `prestige_rules.dart`)

| 항목 | 값 |
| --- | --- |
| 열리는 레벨 | 10 |
| 별 공식 | `floor(cbrt(누적생산 ÷ 1경))` − 이미 받은 별 |
| 별 1개 효과 | 생산 +5% (환생배율 = 1000 + 50×별 ‰) |
| 설계 목표 | 첫 환생(누적 약 2e18)에 별 5~6개 |

---

## 6. 부스트·황금 찬스

`lib/support_config.dart`

| 종류 | 이름 | 배율 | 지속 | 얻는 방법 |
| --- | --- | --- | --- | --- |
| invite | 초대 손님 | ×5 | 600초 | 초대한 친구가 Lv.1 도달 |
| visit | 친구 방문 | ×3 | 300초 | 친구가 내 노점 방문 |
| golden | 황금 찬스 | ×3 | 60초 | 화면의 황금 붕어빵 잡기 |
| bought | 황금 부스트 | ×3 | 600초 | 황금 붕어빵 20개로 구매 |

- 부스트는 겹쳐도 합산하지 않고 가장 센 것 하나만 적용됩니다. 탭 생산과 자동 생산 모두에 곱해집니다.
- 같은 부스트를 다시 받으면 시간이 연장됩니다.
- 황금 찬스는 플레이 중 180~420초마다 나타나고 8초 동안 보입니다. 굽는 판의 6칸 중 한 곳에 뜹니다.

---

## 7. 꾸미기

파일: `lib/cosmetic_config.dart`, 해금 규칙은 `lib/menu_rules.dart`

> 18단계 기획: 꾸미기를 붕어빵력으로 사도록 바꾸고, 배경과 음악 선택을 분리합니다([16장](#16-기획-중인-변경)).

- 해금 조건: 레벨 ≥ `unlockLevel` 그리고 누적 생산 ≥ `unlockProduction`.
- 코인으로 삽니다. 황금 붕어빵으로 사면 가격은 코인 × 5이고 해금 조건을 건너뜁니다.
- 기본 아이템과 character, skin, time 칸의 아이템은 무료이고 수집 개수에서 빠집니다.

### 칸과 분류

| 분류 | 칸 |
| --- | --- |
| 붕어빵 | fish(숨김), pattern, topping |
| 아바타 | character, skin, hair, top, bottom, shoes, outfit, hat, accessory, tool |
| 노점 | background, stove, decoration, lamp, time |

| 옷장 탭 | 칸 |
| --- | --- |
| hair | character, skin, hair, hat |
| outfit | top, bottom, shoes, outfit |
| props | accessory, tool |
| bungeoppang | pattern, topping |
| stall | 노점 칸 전부 |

### 아이템 표

표기는 `id 이름 코인/레벨[/누적생산]`이고, 굵게 표시한 것이 기본값입니다.

| 칸 | 아이템 |
| --- | --- |
| background | **clear 맑은 날 0/1**, night 야간 골목 3/1, dusk 보랏빛 해질녘 5/2/100, rain 비 오는 날 6/2, snow 눈 오는 밤 7/3, autumn 가을 골목 9/4, forest 숲길 노점 9/5/1만, cherry 벚꽃 골목 10/6, snowday 눈 오는 낮 11/6, seaside 바닷가 야시장 14/8 |
| stove | **iron 기본 화로 0/1**, castiron 무쇠 화로 6/2, copper 구리 화로 7/3/1000, golden 황금 화로 15/9 |
| decoration | **none 0/1**, lantern 종이 등불 4/2, starlights 별 전구 5/3, bunting 작은 축제 깃발 8/4/5000, windchime 풍경 9/5, paperlanterns 종이 초롱 줄 10/6, snowman 눈사람 12/7 |
| lamp | **amberlamp 기본 등불 0/1**, roselamp 분홍 4/2, mintlamp 민트 6/3, lilaclamp 라일락 8/4 |
| time | **scenetime 배경 그대로**, day 낮, night_time 밤, clock 기기 시간(19~06시 밤) |
| pattern | **scales 기본 비늘 0/1**, heartscale 하트 비늘 5/2, starmark 별 도장 8/4, crispgrid 바삭 격자 11/6 |
| topping | **plain 0/1**, sugar 슈가파우더 4/2, choco 초코 드리즐 7/3, almond 아몬드 슬라이스 9/5, sprinkle 무지개 스프링클 13/8 |
| character | **girl 여자 사장님**, boy 남자 사장님 |
| skin | **skin1**, skin2, skin3 |
| hair | **long 긴 생머리 0/1**, short 짧은 머리 3/1, ponytail 묶은 머리 5/2, curly 곱슬머리 8/5 |
| top | **tee 흰 티셔츠 0/1**, creamlong 크림 긴팔 3/2, pinksweater 분홍 니트 6/3, sagesweater 세이지 니트 6/4, creamsweater 꽈배기 니트 8/5, cardigan 카디건 10/6 |
| bottom | **shorts 베이지 반바지 0/1**, skirt 주름치마 4/2, widepants 와이드 바지 6/3, brownpants 갈색 바지 7/4 |
| shoes | **flats 갈색 단화 0/1**, sneakers 흰 운동화 4/2, boots 앵클부츠 7/4, furboots 털 부츠 10/7 |
| outfit | **apron 기본 앞치마 0/1**(26번 4-4부터 그림으로 입혀짐), noapron 앞치마 없음 0/1(무료, 그림 없음), darkapron 초코 앞치마 5/2, padding 패딩 조끼 6/3, creamapron 크림 앞치마 7/4, stripe 줄무늬 앞치마 9/5, waistapron 허리 앞치마 9/5, chefcoat 요리사 복 12/7 |
| hat | **nohat 0/1**, beanie 털 비니 3/2, bandana 크림 두건 4/2, earmuffs 귀마개 6/3, redbandana 빨간 두건 6/3, ballcap 크림 야구모자 7/4, newsboy 헌팅캡 8/4, blackcap 검정 야구모자 9/6, chefhat 요리사 모자 10/6, santa 산타 모자 14/9 |
| accessory | **noacc 0/1**, ribbon 분홍 리본 4/2, fishpin 붕어빵 머리핀 5/3, glasses 동그란 안경 6/3, scarf 분홍 목도리 8/5, mittens 털장갑 9/6, crossbag 크로스백 11/7 |
| tool | **tongs 붕어빵 집게 0/1**, paperbag 붕어빵 봉투 8/5, fishhold 갓 구운 붕어빵 12/8, goldtongs 황금 집게 15/9 |

### 사장님 레이어와 얼굴 모션 (17단계)

파일: 데이터 `lib/avatar_rig_config.dart`, 생성 데이터 `lib/avatar_atlas.dart`(직접 고치지 않음), 모션 `lib/avatar_motion.dart`, 그리기 `lib/ui/avatar_painter.dart`(`AvatarRig`), 화면 연결 `lib/ui/avatar_face.dart`(`AvatarFace`), 에셋 도구 `tools/avatar_layers.py`

**좌표:** 리그 픽셀 = 포즈 그림의 픽셀입니다(정면 280×520 캔버스, 조리 프레임 506×506). 레이어는 기준점(anchor)에 걸리고, 이동·확대·좌우 반전은 리그 전체에 한 번 적용되므로 모든 레이어가 함께 움직입니다.

**그리기 순서(`RigLayer`)**

| 순서 | 레이어 | 내용 |
| --- | --- | --- |
| 1 | behind | 아이템 뒤 조각 `<slot>_<id>_back.png` |
| 2 | base | 포즈 그림(몸·얼굴·기본 머리·기본 옷). 피부톤이 skin2·3이면 `base@<skin>.png` |
| 2-1 | (_cut) | 착용 중인 아이템의 `<slot>_<id>_cut.png` 마스크로 base에서 가려질 픽셀을 지움(`BlendMode.dstOut`, base만 담은 `saveLayer` 안). 머리·얼굴·옷은 지우지 않음 |
| 3 | hair | 머리 모양 `hair_<short·ponytail·curly>.png`(긴 생머리 `long`은 base 그대로). 긴 머리는 hair의 `_cut`이 지움 |
| 4 | eyes | 눈 프레임 |
| 5 | mouth | 입 프레임 |
| 6~12 | bottom, shoes, top, outfit, hat, accessory, tool | 칸별 아이템(`rigSlotLayers`). tool만 탭할 때 올라감 |
| 13 | front | 아이템 앞 조각 `<slot>_<id>_front.png` |

- 아이템 그림의 기준점은 캔버스 원점입니다. 잘라낸 그림은 `avatarTrimOffsets`의 (left, top)에 놓입니다. 그림 크기가 280×520이면 오프셋을 무시합니다.
- 그림별 위치 보정·크기·회전·같은 층 안의 순서는 `rigPlacements`(경로 → `RigPlacement`)에 둡니다. 지금은 비어 있습니다.
- 앞/뒤 조각은 파일만 넣으면 됩니다. `PixelSprites.load`가 에셋 목록에 있는 것만 읽습니다.
- character는 base 그림을 고릅니다. skin은 그림마다 피부색만 바꾼 복사본 `<파일>@skin2.png`·`@skin3.png`를 고릅니다(`rigSkinPicture`, 복사본이 없는 그림은 원래 그림). 복사본은 base, 정면 얼굴 부분 그림, 피부가 보이는 hair·hat 레이어에만 있습니다. hair는 hair 레이어입니다(26번 4-4, 2026-11-18).
- **입은 모습(worn) 레이어:** 3.3 원본 폴더의 '입은 모습' 전신 그림(`avatar/<성별>/<slot>_<id>.png`)을 base에 겹쳐(머리 아래 몸으로 맞춤) 바뀐 픽셀만 아이템 레이어로, base에서 사라진 픽셀은 `_cut` 마스크로 만듭니다(`tools/avatar_layers.py worn`, `WORN_ITEMS`). `_cut`은 base 가장자리 밖·아이템 아래로 2픽셀 넓혀서 축소해 그려도 옛 외곽선이 남지 않습니다. 모자·액세서리는 얼굴(눈·입 상자 + 12픽셀)을 바꾸지 않습니다. 어느 레이어가 worn으로 만들어졌는지는 생성 파일 `avatarWornLayers`, 에셋 목록은 `avatarArtFiles`(둘 다 `lib/avatar_atlas.dart`).
- **꾸미기에 보이는 조건(`PixelSprites.avatarArtReady`):** 기본값·그림 없는 아이템(`blankCosmetics`)·skin1·긴 생머리는 늘 보임. skin2·3은 `base@<skin>.png`, hat·hair는 worn 레이어(`avatarWornOnlySlots`), 나머지는 그림 파일이 있어야 보입니다. 지금 캐릭터 기준이고, 이미 산 아이템은 그림이 없어도 보입니다(`workshop_page.dart` `_cosmetics` `listed`). 그림이 들어오면 `python tools/avatar_layers.py`만 다시 돌리면 코드 변경 없이 보입니다. 2026-11-18 기준 숨김: 털 비니·크림 두건·크림 야구모자·헌팅캡(남녀, 평면 그림만 있음 — 25번 17번 '쓴 모습' 원본 대기).
- 조리 장면(cook 측면 6장)은 옷·피부가 그려진 그림이라 피부톤·머리·아이템을 반영하지 않습니다(26번 4-4 '이번엔 정면만', 후속).

**포즈(`RigPose`)**

| 포즈 | 그림 | 얼굴 보기 | 아이템 |
| --- | --- | --- | --- |
| front | `avatar/<character>/base.png` | front | 그림 |
| cook1~6 | `cook/<character>_1~6.png` | side | 안 그림(프레임에 옷이 그려져 있음) |

얼굴 기준점은 `avatarFaceAnchors[포즈 그림]['eyes'·'mouth']`입니다. 없으면 얼굴 프레임을 그리지 않고 그림 속 얼굴을 그대로 둡니다.

**얼굴 채널(`rigChannels`)**

| 채널 | 프레임 | 쉬는 프레임 | 그림 |
| --- | --- | --- | --- |
| eyes | open, half, closed | open | `parts/<character>_<view>_eyes_<frame>.png` |
| mouth | closed, small, wide | closed | `parts/<character>_<view>_mouth_<frame>.png` |

- 쉬는 프레임은 그림 자체라서 파일이 없습니다. 프레임 그림이 없으면 쉬는 프레임으로 대체됩니다.
- 부분 그림의 피벗(기준점에 닿는 점)은 `avatarPartPivots`에 있습니다.
- 부분 그림은 그려진 눈·입을 주변 피부색으로 덮고 새 모양을 그립니다(`tools/avatar_layers.py face`). 피부색은 skin1 그림에서 가져오고, skin2·skin3용은 `skin` 작업이 같은 색 치환으로 `parts/<character>_front_<part>@<skin>.png`를 만듭니다.

**모션(`MotionClip`)**

| 클립 | 트랙 | 쓰는 곳 |
| --- | --- | --- |
| talk | mouth: small 90 → wide 110 → small 80 → closed 70 → wide 100 → small 90 → closed 120 (ms, 반복) | 손님이 와 있는 동안 조리 장면 사장님(`CookCut.greeting`), 인사하는 손님, 꾸미기 미리보기를 누를 때 |
| blink | eyes: half 40 → closed 70 → half 40 | 자동. 간격 `blinkGapMs` 2400~5200ms 무작위 |
| cheer | eyes closed + mouth wide 520ms(같은 시계) | 정의만 있음 |

- 채널마다 클립 하나가 재생됩니다. 다른 채널의 클립은 동시에 재생됩니다. 한 클립의 여러 트랙은 같은 시계를 씁니다.
- `AvatarFace`는 프레임이 바뀔 때만 다시 그립니다. 차림이 바뀌어도 진행 중인 모션은 이어집니다.
- 모션 줄이기를 켜거나 `WeatherLayer.animate`가 false(테스트)이면 얼굴은 그려진 그대로이고 티커도 돌지 않습니다.
- 친구·랭킹 목록의 아바타는 움직이지 않습니다.

**디버그:** 개발 빌드(`developerTools`)의 설정 맨 아래 '레이어 기준점 보기'를 켭니다(`AvatarRigDebug.show`). 노란 선은 리그 영역, 하늘색 선은 레이어 경계, 분홍 표시는 기준점입니다. 확인용 이미지는 `flutter test tools/preview_avatar_layers_test.dart`로 만들고, 결과는 `build/preview/avatar_layers.png`에 저장됩니다. 골든 `test/goldens/avatar_skin_hair.png`(`test/avatar_golden_test.dart`, 2026-11-18 26번 4-4에서 새로 만듦)는 남녀 × 피부톤 3 × 머리 4와 짧은 머리+요리사 모자·앞치마 없음을 찍어 `_cut`·피부 복사본·머리 레이어가 깨지는지 봅니다. 황금 집게는 원본이 다른 팔 자세라 기존 집게를 금색으로 바꾼 그림입니다(`tools/avatar_layers.py derive`).

**저장:** 바뀐 것이 없습니다. 장착 상태는 원래부터 `wardrobe.equipped`에 '칸 이름 → 아이템 id'로 저장됩니다. 그림 경로는 저장하지 않습니다. 서버 외형도 같은 id를 씁니다(`lookFromServer`).

**조합 제약:** 함께 쓸 수 없는 조합이 실제로는 없어서 제약 데이터를 두지 않았습니다. 액세서리는 한 칸에 하나뿐이고, 모자 위의 리본·머리핀도 그림이 어긋나지 않습니다.

### 배경과 날씨·음악·밤

| 배경 | 날씨 효과 | 음악 | 밤 이미지 |
| --- | --- | --- | --- |
| clear | 반짝임 | day | `clear_night` |
| night | 별 | night | 자체 |
| dusk | 반딧불 | dusk | 없음 → 푸른 색조 덧칠 |
| forest | 반딧불 | dusk | 없음 → 덧칠 |
| seaside | 별 | night | 없음 → 덧칠 |
| rain | 비 | rain | `rain_night` |
| autumn | 낙엽 | dusk | `autumn_night` |
| cherry | 꽃잎 | spring | `cherry_night` |
| snow / snowday | 눈 | snow | snow ↔ snowday 짝 |

- 시간 설정이 밤이면 배경과 상관없이 night 음악이 나옵니다.
- 계절은 주간 도전 문구에만 영향을 주고, 홈 배경을 바꾸지 않습니다.

---

## 8. 황금 붕어빵(유료)

> 18단계 기획: 화면 이름을 '황금붕어빵력'으로 바꿉니다. 코드 이름·상품 id는 그대로입니다([16장](#16-기획-중인-변경)).

파일: `lib/premium_config.dart`. 서버 가격표는 `firebase/functions/src/catalog.json`이고, 직접 고치지 말고 테스트로 다시 생성합니다.

| 상품 id (소모성) | 황금 붕어빵 | 계획 가격(원) |
| --- | --- | --- |
| gold_60 | 60 | 1,200 |
| gold_330 | 330 | 5,900 |
| gold_700 | 700 | 11,000 |
| gold_2200 | 2,200 | 33,000 |
| gold_3800 | 3,800 | 55,000 |

| 쓰는 곳 | 가격 |
| --- | --- |
| 꾸미기 | 코인 가격 × 5 (`goldPerCoin`), 영구 보유, 잠금 무시 |
| 스킬 조기 해금 | n단계 × 10 (`goldPerSkillStep`), 2~16단계만 — **구형 클리커 경로만**. 신규 Workshop에는 조기 해금이 없음 |
| (신규 Workshop) 꾸미기 | 유료 아바타 붕어빵력 1000 + 황금 2 (`cosmetic_purchase`) |
| (신규 Workshop) 스킬 레벨업 | 1~4단계 황금 0, 5~16단계 황금 2·3·4 + 10번마다 1 (4장, DEC-041) |
| 황금 부스트 | 20 (`boughtBoostGold`) |

- 상점에 보이는 가격은 Play가 지역에 맞게 주는 가격입니다.
- 결제 흐름: `buyGoldPack`(로그인 필요) → Play 결제 → 서버 `walletRedeem`이 Play API로 확인하고 소모 처리 → 지급. 앱에서는 자동 소모하지 않습니다(`autoConsume: false`).
- 사용할 때는 요청마다 20자 무작위 id를 붙여 `walletSpend`를 부릅니다. 같은 id는 한 번만 처리됩니다.
- 신규 Workshop의 황금 획득: 환영 황금(계정당 1회, `ledger/welcome_v1`), 일일·주간 미션, 희귀 판매 추첨. 모두 서버 지갑에서만 늘어나고 앱은 로컬 황금을 만들지 않습니다([23장](#23-서버-타당성-검증과-환영-황금--2026-11-03)).
- 신규 Workshop의 황금 쓰는 곳(26번 3단계): 꾸미기(유료 아바타)와 5단계 이상 스킬. 상점(`ShopPanel`, Workshop 경로)은 **꾸미기 탭으로 열리고**(구형 경로는 장비 탭), 충전 탭에 '황금붕어빵력 쓰는 곳: 꾸미기(옷·모자·머리·도구)와 높은 단계 스킬…' 한 줄(`gold-uses`), 약관 줄은 '황금붕어빵력 잔액은 로그인한 카카오 계정에 보관돼요.'(구형 경로의 '꾸미기와 스킬 해금은 돌아와요'는 Workshop에서 쓰지 않음). 메뉴 '로그인·보상 확인' 뒤 잔액이 늘면 '황금붕어빵력 N개를 받았어요. 꾸미기에서 써 보세요.' 알림(환영 황금 안내). 이미 황금으로 1~4단계를 산 사용자는 환불 없이 그대로(DEC-062).

---

## 9. 온라인: 로그인·랭킹·친구·초대

- 온라인 기능은 **Android 빌드에 키 5개가 모두 들어 있을 때만** 켜집니다. 아니면 오프라인 게임으로 동작합니다. 키는 `--dart-define-from-file=dart_defines/online.json`으로 넣습니다(13장 "온라인 빌드").
- 서버 지역은 `asia-northeast3`(서울), 런타임은 Node 22입니다.
- 운영 설정(Firebase·카카오·Play 결제·App Check)을 처음부터 하는 순서는 [online_setup.md](online_setup.md)(23번 7단계, 초보자용)입니다.

### App Check (23번 7단계)

| 쪽 | 내용 | 위치 |
| --- | --- | --- |
| 서버 | 모든 callable이 `enforceAppCheck: true`. `functions/.env`의 `APP_CHECK_ENFORCED=false`일 때만 끔(값이 없거나 다른 값이면 켬 — 설정을 잊으면 막히는 쪽). 배포할 때 읽히므로 바꾸면 재배포. HTTP `workshopAdSsv`는 AdMob이 부르는 곳이라 대상 아님 | `functions/src/callable_options.ts`, `index.ts` |
| 앱 | `FirebaseOnlineBackend.create`가 Firebase 초기화 직후 `FirebaseAppCheck.activate`. debug 빌드(`kDebugMode`)는 `AndroidDebugProvider`(선택 dart-define `APP_CHECK_DEBUG_TOKEN`으로 콘솔에 등록한 토큰 사용), 그 외 `AndroidPlayIntegrityProvider`. 실패해도 게임은 계속되고 서버 호출만 거절됨 | `lib/firebase_online_backend.dart` `_activateAppCheck` |
| 결과 | Play에서 받은 앱과 등록된 debug 토큰만 서버를 부를 수 있음. 직접 설치한 release APK는 Play Integrity를 통과하지 못할 수 있음 → 확인용으로 잠깐 끌 때는 online_setup.md 14장 | |

### 서버 운영 설정 (`functions/.env`, 커밋 금지)

| 이름 | 운영값 | 뜻 |
| --- | --- | --- |
| `KAKAO_APP_ID` | 카카오 앱 ID(숫자) | `authKakao`가 다른 앱 토큰을 거절 |
| `WORKSHOP_ONLINE_ENABLED` | **`true`** (23번 7단계: DEC-027 온라인 가출시라 켬) | 타당성 검증·환영 황금·스킬 구매·미션/판매 황금 |
| `WORKSHOP_SALE_DRAW_KEY_BASE64` | 32바이트 난수 base64(`firebase/make_server_env.ps1`이 생성, 이후 바꾸지 않음) | 판매 황금 추첨 키 |
| `WORKSHOP_AD_SSV_ENABLED` | `false` | 광고 가출시 제외(DEC-028) |
| `WORKSHOP_PROTECTION_ENABLED` | `false` | 서명 스냅샷 대신 타당성 검증 사용(23장) |
| `APP_CHECK_ENFORCED` | `true` | 위 App Check |

견본은 `functions/.env.example`. 에뮬레이터 검사(`run_emulator_checks.ps1`)는 실행 동안만 `functions/.env.local`을 만들어 테스트 값(온라인 끔·App Check 켬·카카오 ID 없음)으로 `.env`를 덮고 끝나면 지운다(에뮬레이터는 `.env`를 프로세스 환경보다 우선함).

### 서버가 Google에 요청할 때 쓰는 계정

2세대 함수는 Compute Engine 기본 서비스 계정(`프로젝트번호-compute@developer.gserviceaccount.com`)으로 실행된다(15단계 문서의 `@appspot`은 1세대 기준). 이 계정에 필요한 것: 프로젝트 IAM `서비스 계정 토큰 생성자`(카카오 커스텀 토큰), Play Console 앱 권한 `재무 데이터 보기`·`주문 및 구독 관리`(`walletRedeem`의 Play Developer API 구매 확인·소모), Google Cloud API `IAM Service Account Credentials API`·`Google Play Android Developer API` 사용 설정.

### 로그인

1. 카카오톡 로그인을 시도하고, 안 되면 카카오 계정 페이지로 로그인합니다.
2. 서버 `authKakao`가 카카오 토큰과 app_id를 확인합니다.
3. uid를 `kakao:<회원번호>`로 정한 커스텀 토큰을 돌려줍니다.
4. Firebase에 로그인합니다.

나머지 서버 함수는 모두 카카오 커스텀 로그인만 받습니다. 서버 `.env`에는 `KAKAO_APP_ID`가 필요합니다.

### Firestore

**클라이언트는 아무것도 읽고 쓸 수 없습니다**(`firestore.rules`가 전부 거부). 모든 데이터는 서버 함수만 다룹니다.

주요 컬렉션:
- `users/{uid}`(+ `ledger`, `entitlements`)
- `purchases`
- `inviteProfiles`, `inviteCodes`, `players`, `inviteTickets`, `inviteAccepts`, `inviteEvents`
- `friends/{uid}/list`, `visitsSent`, `visits/{uid}/inbox`
- `rankings/{board}/entries`, `rankingSubmits`

### 서버 함수 (`firebase/functions/src/index.ts`)

| 함수 | 역할 |
| --- | --- |
| authKakao | 카카오 토큰 → Firebase 토큰 |
| walletSync / walletRedeem / walletSpend | 황금 붕어빵 잔액·결제 확인·사용 |
| inviteRegister / inviteCreateTicket / inviteAccept / inviteLevelOne / inviteFetchEvents | 초대 |
| profileSet | 이름과 외형 등록 |
| friendAdd / friendList / friendVisit / visitsFetch | 친구와 방문 |
| rankingSubmit / rankingTop | 랭킹 |
| workshopProgressClaim | 활성 진행 등록 + 환영 황금(계정당 1회) |
| workshopPurchaseReserve / Commit / Query / Cancel | 신규 스킬·아바타 두 재화 구매. 예약·확정 전에 타당성 검증기가 진행 스냅샷을 확인 |
| workshopRewardSubmit / Query | 미션·판매 황금. 타당성 검증 후 서버 지갑 지급 |

### 랭킹 (`lib/ranking_config.dart` ↔ `functions/src/ranking.ts`, 테스트가 일치 여부를 확인)

| 항목 | 값 |
| --- | --- |
| 순위표 | bestAutoRate, lifetime, bestCombo |
| 제출 주기 | 최대 5분마다(점수가 올랐을 때), 최소 간격 60초 |
| 그 외 제출 시점 | 레벨업, 앱 나갈 때, 랭킹 열 때 |
| 상위 표시 | 100명 |
| 이상치 차단 | 점수 ≤ 하한값, 또는 ≤ max(이전, 하한) × 10 × 10^경과시간. 하한: 초당 1e6, 누적 1e9, 콤보 1000 |

### 친구·초대

| 항목 | 값 |
| --- | --- |
| 친구 수 | 최대 100 (서로 친구) |
| 친구 방문 | 친구마다 하루(한국 시각) 1번, 방문 기록 7일 보관 |
| 초대 코드 | `BB` + 8자(A-Z, 2-7). 이 코드가 "내 아이디" |
| 신규 판정 | 계정 생성 24시간 이내 |
| 초대 보상 | 신규 5코인, 기존 2코인. 같은 플레이어는 하루 1번 |
| 초대 받은 쪽 | 초대한 사람과 자동으로 친구가 되고, Lv.1 도달 시 초대 손님 부스트 |
| 앱 동기화 | 2분마다 (`onlineSyncIntervalMs`) |

---

## 10. 화면 배치

> README의 홈 화면 설명(왼쪽 위 미션 버튼, 오른쪽 세로 메뉴, 아래 레벨 카드)은 예전 구조입니다. 현재 구조는 아래와 같습니다.

### Workshop 홈 (실제 진입 경로, `lib/ui/workshop_page.dart`)

`main.dart` → `GameApp` → `WorkshopPage`가 `NightHome`에 Workshop 내용을 넣어 그립니다. 아래 "홈 화면"의 층 구성(배경·굽는 판·HUD·하단 내비)은 같고, 다음이 다릅니다.

| 요소 | 위치·크기 | 키 | 파일 |
| --- | --- | --- | --- |
| 스페셜 붕어빵 무대 | HUD 아래 중앙. 배경에 그려진 붕어빵 자리에 맞춤. 영업 상태별(DEC-035, 아래 "두 틀 규칙"): 영업 준비 중 빈 틀 + 맛 선택 + '스페셜 붕어빵 제작 시작'(버튼 아래끝 = 판매 카운터 윗변 − 4, 24번 4단계. 행주 값이 없는 배경이면 예전처럼 틀 아래 경계에 걸침), 영업 중 세션이 없으면 틀 없이 떠 있는 큰 붕어빵(클리커, 틀 자리에서 틀 높이×0.75 위), 제작 세션 중에는 틀과 단계 조작. 새 영업일 이어서 영업 전에는 빈 틀만 | `workshop-center-stage`, `workshop-mold-action`, `workshop-clicker` | `ui/workshop_mold_stage.dart` `WorkshopMoldStage`·`WorkshopClicker` |
| 손님 줄 | 무대 왼쪽, 폭 64, 위 48·아래 56 여백. 맨 앞이 위. 배지 52(남은 시간 고리, 맨 앞은 노란 면) + "N번" + 맛 첫 글자·수량. '맞이' 버튼은 **첫 실행 안내 중이고 줄이 비었을 때만**(26번 5-1단계 S5-1-Q2). 안내가 끝나면 손님은 실제 시간 시계로만 옴(30장). 줄은 일반 3 + 네임드 1까지 | `customer-N`, `customer-welcome` | `ui/workshop_counter.dart` `WorkshopCustomerQueue` |
| 판매 카운터 | 왼쪽 8, 폭 = w − 16 − (조리 컷 폭 + 8), **위 = 배경 왼쪽 빨간 체크 행주의 윗변**(DEC-038, 아래 "행주 윗변"), 높이는 내용대로. 행주 값이 없는 배경(장면 크기 픽셀 그림·새 배경)이면 예전처럼 아래 = 굽는 판 바닥 + 굽는 판 높이×0.66. 스페셜 붕어빵 제작 중에는 숨김 | `sale-counter` | `WorkshopSaleCounter` |
| 숙련된 붕어빵 틀 칸 | 굽는 판 그림의 6칸 위. 굽는 판 폭 = w − 16(왼쪽 8), 높이 = 폭 × 그림 높이/폭(941×470), 그림이 상자를 꽉 채워 칸 위치·터치 영역도 같은 비율로 커짐(DEC-038). 바탕은 **빈 굽는 판 그림**(`assets/images/stove_empty/<화로>.png`, 25번 1번 생성 그림을 `tools/apply_25_art.py`로 원래 화로 위치에 맞춤: 칸이 붕어빵 모양 홈)이고, 굽는 칸에만 원래 그림의 붕어빵만 남긴 층(`stove_fish/<화로>.png`, 없으면 `stove/<화로>.png`)을 그 칸 자리(`griddleFishClips`)에서 잘라 겹쳐 그림(`GriddlePainter(filled:)`, `workshopGriddleFilled`). 홈 중심과 `griddleCavities` 차이는 그림 px로 가로 −9~+3, 세로 −3~+1(25번 1번). 영업 준비 중(새 영업일 이어서 영업 전 포함)에는 칸을 하나도 그리지 않음: 빈 굽는 판 그림만, 글자·면·터치 없음(`griddle-idle`). 영업 중 빈 칸은 글자 없음: 누를 수 있으면(영업 중·세션 없음·숙련한 맛 있음) 옅은 크림색 면(투명도 0.18)과 크림색 테두리(투명도 0.7, 두께 1.5), 누를 수 없으면 검은 반투명 면만. 굽는 칸은 번호·익힘·'수확'/'폐기' 글자와 갈색(탄 칸은 검정) 면. 화면 읽기 라벨: 빈 칸 '숙련된 붕어빵 틀 N번 칸 굽기 시작', 굽는 칸 'N번 맛 익힘 · 수확/폐기' | `workshop-cell-N` | `WorkshopGriddleLayer` |
| 손님 창 | 손님 배지를 누르면 뜨는 작은 창: 주문 줄(드린 수/주문 수), 대사, '이웃 이야기 확인', 맛별 '주문 제작'(영업 중·세션 없을 때만. 누르면 창을 닫고 그 주문 하나를 만드는 동안만 스페셜 붕어빵 틀이 나옴. 결과를 닫으면 다시 클리커). 카운터의 '맛 제작'(`order-produce`)도 같은 주문 제작 | `customer-card`, `customer-produce-<맛>` | `WorkshopCustomerCard` |
| 재고 창 | 카운터 글자를 누르면 뜨는 작은 창: 오래된 순 묶음(맛·익힘·개수·경과 영업일), 준비품 | `stock-card` | `WorkshopStockList` |

**두 틀 규칙 (DEC-035·036, 24번 3단계):**

| 상태 | 스페셜 붕어빵(큰 틀) | 숙련된 붕어빵(6구) |
| --- | --- | --- |
| 영업 준비 중 | 빈 틀, 맛 선택, '스페셜 붕어빵 제작 시작'(연습만). '+붕어빵력' 버튼 없음 | 빈 굽는 판 그림만(붕어빵·칸 글자·면·터치 없음) |
| 영업 중, 평소 | 틀 없이 떠 있는 큰 붕어빵(`FloatingFishPainter`). 탭하면 `clickerTap` → `tap`(붕어빵력 +`tapRate`)과 탭 효과(눌림·작은 붕어빵 부스러기·'+N', 모션 줄이기면 멈춘 '+N'만, 진동 설정 시 80ms 간격 진동). 1초에 `server_validation.max_taps_per_second`(15)번을 넘는 탭은 효과만 보이고 '+N'·붕어빵력·탭 수 없음. 새 주문이 와도 틀을 다시 보이지 않음(예전 `orderFlash` 2.5초 삭제) | 지금처럼 동작 |
| 영업 중, 주문 제작 중 | 손님 창·카운터의 주문 제작 동안만 틀과 단계 조작. 클리커 탭 거부(`tap`도 세션 중 무시). 결과를 닫으면 클리커로 | 멈춤(칸 터치 없음) |

명령에서도 막음: `startPractice`는 영업 중(새 영업일 이어서 영업 전 포함) '연습 제작은 영업 준비 중에만 할 수 있어요.', `openBusiness`는 스페셜 붕어빵 세션(결과 대기 포함)이 있으면 '스페셜 붕어빵을 다 만든 뒤 영업을 시작해요.'(이어서 영업도 같음). `startOrderProduction`은 영업 중 그대로 허용. 클리커 탭 상한은 컨트롤러의 단조 시계로 센 최근 1초 기록(저장하지 않음)이며, 구형 `tap()` 경로 자체에는 상한이 없음. 저장 형식(schema 6) 변경 없음.

**짤주머니 색칠 (DEC-031~033, 24번 5단계, 사용자 확정 G1~G8):** 첫 반죽·속·둘째 반죽은 스페셜 붕어빵 틀 위를 색칠하듯 문지르는 조작입니다(`lib/ui/piping_bag_control.dart` `MoldPaintControl`, 계산은 `lib/cooking_paint.dart` `MoldPaint`).

| 항목 | 규칙 |
| --- | --- |
| 마스크 | `fish/redbean.png`의 불투명 부분(알파 > 128)을 틀 그림(1200×880) (100, 66)에 놓고 `WorkshopMoldArt.fishRect`(215,174~984,706)를 16px 칸으로 나눈 49×34 격자. 칸 면적 절반 이상이 붕어빵이면 마스크 칸(**1,081칸**). 생성: `1_app_development`에서 `python tools/fish_cavity_mask.py`(`--check`로 확인) → `lib/generated/fish_cavity_mask.dart` |
| 붓 | 지름 = 붕어빵 폭(769) × `paint_brush_width_permille`(140) = 107.7(틀 그림 px, 390 폭 화면에서 약 37px). 포인터 이동마다 직전 점에서 반 칸(8px) 간격으로 찍어 빠르게 휘둘러도 빈틈 없음 |
| 덧칠 (DEC-032) | 칸 중심이 붓 반지름 안에 새로 들어오면 그 칸에 한 겹. 머무는 동안은 다시 세지 않음. 붓 중심이 **반지름 + 1칸**보다 멀어져야 떠난 것으로 봄(떨림 여유, G7). 칸당 최대 9겹. 마스크 밖은 세지 않음 |
| 양 | 덮은 면적 = 1겹 이상 칸 ÷ 1,081, 덧칠 포함 양 = 겹 합계 ÷ 1,081 (모두 permille 정수, `PaintAmount(coverage, amount)`) |
| 입력 | 첫 포인터 하나만(두 번째 손가락 무시). 누르자마자 제스처를 차지해(`ImmediateMultiDragGestureRecognizer`) 큰 글씨 홈이 스크롤되지 않음. 틀 밖으로 나가도 취소하지 않고 양에만 넣지 않음. **손을 떼면 그 단계 확정**. 칠이 0이면(틀 밖만 문지름) 확정하지 않음(G3). 포인터 취소·차단(`cookingInputBlocked`, 일시정지)·단계 토큰 변경·앱 비활성은 칠을 버림 |
| 화면 읽기 | 두 번 활성화 = '고르게 칠하기': 덮음 100%·양 100%로 확정(G4, 이 경로는 반죽 성공) |
| 칠 표시 | 반죽은 칠한 칸 모양으로 `mold/batter.png`(둘째 반죽은 `mold/batter_top.png`)를 드러냄. 속은 `mold/paint_<맛>.png`(256×256 심리스 질감, 25번 3번)를 반복해 채움(`ImageShader`, `fillingTextureScale` 2 = 질감 1px가 틀 그림 2px, 390 폭 화면에서 질감 한 장 약 180px·팥알 약 10~12px). 그림이 없으면 맛 색(팥 `#642B27`, 슈크림 `#E8B84A`, 초코 `#4A2C1D`). 2겹 이상 칸은 조금 진하게, 130%를 넘으면 칠한 열 5칸마다 붕어빵 아래 가장자리에 흘러내림 방울 `fx/overflow_<반죽·맛>.png`(32×48, 폭 = 칸×2.4, 위 가운데가 가장자리) |
| 확정 뒤 (G2) | 이번 세션의 칠한 칸 모양을 메모리에 남겨 뚜껑을 닫을 때까지 보임(`paintedMoldFor`). 저장하지 않으므로 앱을 다시 켜면 단계 그림(`moldFor`) 전체로 보임 |
| 짤주머니 | 세 단계 모두 손가락을 따라감. `cook/piping_bag_<반죽·맛>[_squeeze].png`(128×192, 25번 2번)의 꼭지 끝 내용물 점 (64, 188)이 손가락, 화면 폭 = min(조작 상자 폭×0.3, 64)(보통 화면은 64, 주머니 자체 약 43×92), 오른쪽 위로 0.45rad 기울임(+움직임 기울기). 손가락이 붕어빵 마스크 칸 위면 짜는 중 그림, 밖이면 빈 그림 |
| 안내 글(`piping-amount`) | 틀 아래쪽 가운데. 아래끝 = 무대 아래 '제작 취소' 버튼(누르는 영역 48) 윗변 − 4(필요할 때만 올림, `captionLift`, 24번 6단계에서 버튼과 겹치던 것을 고침). 대기 '틀 위를 문질러 반죽을 부어 주세요' / '틀 위를 문질러 속을 짜 주세요'. 반죽 칠하는 중 '반죽 덮음 85% · 양 112% · 손을 떼면 마무리'(G5), 속 '속 양 72% · 손을 떼면 마무리'. 130% 초과면 끝에 ' · 넘쳤어요'. 위 캡션 '팥 연습 · 반죽 목표 90% 이상 덮기 · 130% 넘으면 넘침' |
| 결과 글 (G6) | '완성 · 미디엄 · 반죽 넘침' / '… · 반죽 부족'(`batterFailureLabel`, 넘침이 우선, `mold-result-caption`) |
| 모션 줄이기 | 짤주머니가 손가락을 따라가는 것은 직접 조작이라 그대로. 움직임에 따라 짤주머니가 기우는 연출만 끔. 판정 같음 |
| 진동(설정 켜짐) | 단계 확정 때 `selectionClick` 1회, 한 붓질에서 130%를 처음 넘는 순간 `mediumImpact` 1회 |
| 판정 (DEC-031) | 반죽 두 번 각각 덮은 면적 ≥ `batter_min_coverage_permille`(900) 그리고 양 ≤ `paint_overflow_amount_permille`(1300) + 익힘 `success_doneness_min_index`~`max_index`. 속은 판정 안 함(양·넘침만 표시). 예전 길게 누르기로 끝난 반죽 단계(저장의 `firstBatterMs`·`secondBatterMs`)는 손기술 실패(G1) |
| 센서 (DEC-033) | 기울기 센서 삭제: 스위치, `cooking_sensor_input.dart`·`cooking_tilt_source.dart`·`TiltDirectionGate`·`BatterHoldInput`·`BatterHoldButton`, Android `CookingTiltStream.kt`와 채널, `tilt_*` 설정 3개 |

**원 그려 뒤집기 (DEC-034, 24번 6단계):** 뒤집기 단계에는 버튼이 없고 틀 둘레에 손가락으로 원을 그립니다(`lib/ui/flip_circle_control.dart` `FlipCircleControl`, 계산은 `lib/cooking_flip.dart` `FlipCircle`). 탭으로는 뒤집히지 않습니다.

| 항목 | 규칙 |
| --- | --- |
| 각도 | 틀 중심(= `WorkshopMoldArt.fishRect` 중심 = 조작 상자 중심) 둘레로 손가락이 쓸고 간 각도를 부호와 함께 더함(화면 시계 방향 +). 거꾸로 돌면 줄고, 어느 방향이든 절댓값이 `flip_turn_degrees`(320) 이상이면 뒤집힘. 한 번의 움직임은 짧은 쪽(±180도 이내)으로 셈 |
| 중심 무시 | 틀 중심에서 틀 그림 폭(1200px 캔버스 × 화면 배율) × `flip_dead_zone_permille`(150) = 15% 안쪽 점은 무시하고, 그다음 바깥 점부터 다시 셈(중심에서 맴돌기·중심을 가로지르기는 0도). 반지름 360 폭 화면 약 57px, 390 폭 약 61px |
| 입력 | 짤주머니와 같음: 첫 포인터 하나만, 누르자마자 제스처를 차지해 큰 글씨 홈이 스크롤되지 않음, 시작은 틀(조작 상자) 위에서, 그 뒤는 틀 밖으로 나가도 계속 셈. **320도 전에 손을 떼면 0도로 초기화·틀 원위치**. 포인터 취소·차단(`cookingInputBlocked`, 일시정지)·단계 토큰 변경·앱 비활성도 0도로 되돌림 |
| 그리는 동안 | 닫힌 틀 그림(`active-empty-mold`)이 누적 각도만큼 틀 중심을 축으로 따라 돎. 틀 둘레에 안내 고리 `fx/flip_ring.png`(512×512, 반지름 236 → 화면 반지름 = 틀 그림 400px × 배율, 오른쪽 위·왼쪽 아래 시계 방향 화살촉 포함)와, 12시에서 시작해 진행 비율만큼 부채꼴로 잘라 보이는 꿀색 고리 `fx/flip_ring_fill.png`(25번 5번) |
| 다 그리면 | 바로 뒤집힘 연출을 `flip_ms`(1000) 동안 보이고(그린 각도는 한 바퀴로 마저 돌며 틀이 긴 축으로 뒤집혀 살짝 들림), 연출이 끝나면 `flip` 명령을 보냄. 명령이 거부되면 0도·원위치로 돌아가 다시 그림. 연출 중 차단·일시정지·앱 비활성이면 보내지 않고 원위치 |
| `flip_ms`와의 관계 | 컨트롤러는 뒤집기 단계 경과(`activePhaseElapsedMs`, 일시정지 제외)가 `flip_ms` 미만인 `flip`을 '뒤집는 중이에요.'로 거부(`workshop_controller.dart` `cookingCommand`). 명령은 원을 그린 시간 + 연출 `flip_ms` 뒤에 가므로 늘 통과. 시계 차이 대비로 보내기 직전 경과가 `flip_ms`보다 작으면 모자란 만큼 더 기다림(`WorkshopMoldStage`). 서버는 제작 값을 받지 않음 |
| 안내 글(`flip-caption`) | 대기 '틀 둘레로 원을 한 바퀴 그려 뒤집어요', 그리는 중 '뒤집기 56% · 손을 떼면 처음부터', 연출 중 '뒤집는 중…'. 위치는 짤주머니 안내 글과 같음(제작 취소 버튼 4 위) |
| 화면 읽기 | 두 번 활성화 = 뒤집기(라벨 '틀 뒤집기', 연출 뒤 같은 명령). 짤주머니 '고르게 칠하기'(G4)와 같은 방식 |
| 모션 줄이기 | 틀이 따라 돌지 않고 뒤집힘 연출(회전·들림)도 없음. 고리 진행·안내 글·`flip_ms` 기다림·판정은 같음 |
| 진동(설정 켜짐) | 다 그린 순간 `selectionClick` 1회 |
| 저장 | 변경 없음. 각도는 저장하지 않으며 `CookingSession`(schema 1)·Workshop schema 6 그대로 |

**제작 설정값(`config/development_balance.json` `manual_cooking`, 개발용 임시값, 24번 6단계 기준):**

| 설정 | 값 | 뜻 |
| --- | --- | --- |
| `paint_brush_width_permille` | 140 | 붓 지름 = 붕어빵 폭(`fishRect`)의 14% |
| `batter_min_coverage_permille` | 900 | 반죽 덮은 면적 하한 |
| `paint_overflow_amount_permille` | 1300 | 덧칠 포함 양이 이보다 크면 넘침(반죽 실패) |
| `lid_close_ms` / `flip_ms` | 1000 / 1000 | 뚜껑 닫힘·뒤집기 단계의 최소 시간(컨트롤러 검사). `flip_ms`는 원을 다 그린 뒤 뒤집힘 연출 시간과 같음(24번 6단계) |
| `flip_turn_degrees` | 320 | 원 그려 뒤집기에 필요한 누적 각도(양방향, 거꾸로 돌면 감소) |
| `flip_dead_zone_permille` | 150 | 틀 중심에서 틀 그림 폭의 15% 안쪽 움직임 무시 |
| `filling_inputs` | 4 | 옛 속 방향 순서 길이(저장 토큰 호환용, 화면에 안 보임) |
| `batter_input_passes` | 2 | 반죽 두 번 구조 기록용(코드에서 읽지 않음, G6에서 유지) |
| `checkpoint_ms` | 1000 | 제작 중 저장 간격 |
| `products_per_completed_result`, `minimum_cooling_ms` | 1, 0 | 결과 1개당 재고 수, 식힘 시간 |

삭제(24번 5단계): `mastery_difficulties[*].batter_target_ms`·`batter_tolerance_permille`, `manual_cooking.filling_capacity_ms`·`touch_batter_tick_ms`·`tilt_sampling_ms`·`tilt_activation_degrees`·`tilt_dead_zone_degrees`. `tools/development_balance.py`가 다시 생기지 않게 검사하고, 서버 생성본(`firebase/functions/src/generated/development_balance.json`)과 14번 문서를 같은 도구로 다시 만듭니다. 서버 코드는 제작 값을 읽지 않으며 `metadata.revision`은 `development-provisional-3` 그대로입니다(G8).

**행주 윗변 (DEC-038, 24번 4단계):** 판매 카운터 윗변은 배경 왼쪽 빨간 체크 행주의 윗변이고 그 위로는 카운터가 보이지 않습니다. 값은 배경 그림마다 다르며 `NightStallPainter.towelTops`(그림 파일 → 원본 y)에 둡니다. 출처: `1_app_development/assets/images/bg/<id>.png`·`bg_clean/clear.png`(모두 335×762)에서 28~40열을 천(빨강·크림 체크, 주황 나무 제외)이 60% 이상 덮는 첫 행. 측정 도구 `python tools/towel_top.py`(`1_app_development`에서).

| 그림 | 원본 y | 그림 | 원본 y |
| --- | --- | --- | --- |
| bg/autumn | 520 | bg/forest | 521 |
| bg/autumn_night | 518 | bg/night | 522 |
| bg/cherry | 523 | bg/rain | 529 |
| bg/cherry_night | 523 | bg/rain_night | 530 |
| bg/clear | 522 | bg/seaside | 522 |
| bg/clear_night | 520 | bg/snow | 530 |
| bg/dusk | 523 | bg/snowday | 530 |
| bg_clean/clear | 524 | | |

화면 y 변환(`towelTopOnScreen`, 배경을 화면을 덮게 아래 맞춤으로 그리는 식과 같음): s = max(180/335, 400/762), k = max(W/180, H/400), 화면 y = (H − 400k) + (400 − 762s + y·s)·k. 어떤 그림인지는 `PixelSprites.sceneBackground`가 고른 그림(밤·깨끗한 카운터 포함)으로 정합니다. 맑은 날 낮 기본 배경(bg_clean/clear)에서 카운터 윗변: 360x640 384.2, 360x800 544.2, 390x844 566.9, 412x915 622.3.

**판매 카운터:** 1줄 제목(Jua 15), 1줄 설명(12, 안내 문구가 있으면 벽돌색으로 대신), 오른쪽에 다음 행동 버튼 하나(최대 폭 104, 높이 44). 상태 순서:

| 상태 | 제목 / 설명 | 버튼 |
| --- | --- | --- |
| 저장 오류 | 저장 확인이 필요해요 | 다시 확인 (`counter-reload`) |
| 영업 전·새 영업일 | 오늘 영업 준비 / 새 영업일이 밝았어요, 재고·준비품 | 영업 시작 / 이어서 영업 (`business-open`) |
| 태오 사진 반응 | 태오 대사 | 반응 확인 (`photo-reaction`) |
| 손님 없음 | 마지막 판매 한마디 또는 '손님을 기다리는 중이에요', 재고 | 영업 종료 (`business-close`) |
| 맨 앞 손님 | 이름 (남은 초) / "팥 1/2, 재고 3" | 드릴 재고가 있으면 'N개 먼저 판매' 또는 '판매 완료'(`sale-button`), 없으면 '맛 제작'(`order-produce`) |

**메뉴 창 아래:** 황금붕어빵력 심사 대기 건수(`menu-pending-gold`), '로그인·보상 확인'(`menu-sync`), 영업 중이면 '영업 종료'(`menu-close-business`). 예전 "가게 관리" 시트는 없앴습니다. 레시피(슈크림·초코) 미션 받기는 레벨 미션 창, 맛별 연습·손기술 진행과 손님 취향 기록·이야기 다시 보기는 도감 창으로 옮겼습니다.

**메뉴 창 목록(Workshop):** 도감 · 업적 · 통계 · 배경 테마 · 일일 미션 · 주간 도전 · 레벨 미션. 온라인 랭킹·친구·공유는 가출시 범위 밖이라 `MenuPanel(hidden:)`으로 뺌(DEC-029, 2026-11-16 5단계).

**Workshop 창**(`showWorkshopWindow`, `lib/ui/workshop_windows.dart`, 키 `workshop-window`): 위 안전 영역 아래 화면 전체 높이. 위에서부터 잔액 알약, 제목 프레임(닫기 버튼), 내용. 맨 아래 짙은 나무색 받침(`workshop-window-base`, 화면 폭 전체, 위 테두리 wood 2, 최소 높이 = `NightHome.navHeight` 66, 아래 여백 10 + 안전 영역) 가운데에 '돌아가기'. 받침이 홈 하단 메뉴를 완전히 덮어 버튼 옆으로 메뉴가 비치지 않음.

**상점·꾸미기(Workshop):** 파는 것은 아바타 카탈로그(`avatar_catalog`)뿐. 그 밖의 구형 꾸미기(화로·배경·장식·등불·무늬·토핑)는 가지고 있을 때만 보임(`CosmeticMenuAccess.listed`). 품목이 하나도 없는 상점 탭(지금은 테마)은 숨기고 충전 탭은 항상 둠. 충전 탭에는 구형 클리커 부스트 줄을 두지 않음(`GoldChargeTab(legacyBoost: false)`). 로그인 전에는 '로그인하면 충전할 수 있어요', 상품을 불러오는 동안 가격 자리에 '불러오는 중'.

골든: `test/goldens/workshop_counter_{360x800,390x844,412x915}.png`(`test/workshop_counter_test.dart`, 테스트 글꼴). 실제 글꼴(Jua·BungeoSymbols·Material 아이콘)을 불러 찍는 `test/goldens/workshop_home_{open,menu}_{360x640,360x800,390x844,412x915}.png`, `workshop_home_{ready,baking}_390x844.png`, `workshop_home_flipping_360x640.png`(`test/workshop_home_golden_test.dart`): 영업 중 홈(손님 2·재고 1, 떠 있는 큰 붕어빵), 메뉴 창, 영업 준비(빈 틀·빈 굽는 판 그림), 스페셜 붕어빵 제작 중, 원 그려 뒤집기 반 바퀴(모션 줄이기 상태라 틀은 돌지 않고 고리 56%), 그리고 25번 그림 적용 때 더한 `workshop_home_filling_390x844`(속을 짜는 도중, 넘침·짜는 중 짤주머니)와 `workshop_home_griddle_390x844`(영업 중 1·4번 칸만 굽는 중). 24번 4단계에서 굽는 판 폭·카운터 높이·빈 굽는 판 그림으로 13장 모두 다시 만듦. 배치 숫자는 `test/workshop_home_layout_test.dart`가 4개 해상도에서 확인(굽는 판 폭 = 화면 폭 − 16, 카운터 윗변 = 행주 윗변, 시작 버튼 아래끝 = 카운터 윗변 − 4, 칸이 카운터 아래·하단 메뉴 위, 손님 줄이 카운터 위, 제작 단계 안내 글 아래끝 ≤ '제작 취소' 버튼 윗변 − 4). 이 골든과 `workshop_counter_*` 골든은 `WorkshopController(monotonicMs: () => 0)`으로 단조 시계를 멈춰 '현재 단계 경과'와 손님 대기 고리가 실제 시간에 따라 바뀌지 않음.

**첫 실행 안내** (`lib/workshop_tutorial.dart` 단계 계산, `lib/ui/workshop_guide.dart` `WorkshopTutorialOverlay`): 홈 위에 겹친 층. 대상 위젯을 꿀색 고리로 두르고 작은 카드(“첫 영업 안내 N/7”, 한 줄 설명, '건너뛰기')를 띄움. 카드만 터치를 받고 게임은 그대로 조작됨. 저장하는 것은 `tutorial` 값뿐이고 단계는 매 프레임 상태에서 계산.

| 단계 | 조건 | 대상 키 |
| --- | --- | --- |
| 1 | `cook`, 스페셜 붕어빵 틀 비어 있음 | `workshop-mold` |
| 2~6 | 연습 굽기 단계: 반죽 문지르기('틀 위를 문질러 반죽을 칠하듯 부어요. 붕어빵 모양을 고르게 덮고 손을 떼요.') → 속('틀 위를 문질러 속을 짜 넣어요.') → 둘째 반죽('반죽을 한 번 더 문질러 속을 덮어요.')·뚜껑 → 뒤집기('틀 둘레로 원을 한 바퀴 그려 틀을 뒤집어요.') → 꺼내기·보관 | `workshop-mold`, 결과는 `mold-store` |
| 1(영업 중) | `cook`인데 이미 영업 중(DEC-037): 손님 없으면 '영업 중에는 손님 주문을 받아 구워요. 손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요.', 손님이 있으면 판매할 재고가 있으면 판매, 없으면 '손님 주문은 주문 제작으로 바로 구워요.' 주문 제작 결과를 닫으면 `sell` | `workshop-clicker`, `sale-button`, `order-produce` |
| 7 | `sell`: 영업 시작 → 첫 손님 기다리기('첫 손님을 기다려요. 손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요.') → 판매(재고 없으면 주문 제작) | `business-open`, `workshop-clicker`, `sale-button`, `order-produce` |

카드 위치: 스페셜 붕어빵 제작 단계는 무대(`workshop-center-stage`) 바로 아래, 그 밖에는 대상의 넓은 쪽. 왼쪽 72(손님 줄 피함)·오른쪽 12. 어떤 글자 크기에서도 하단 메뉴(`home-nav`) 위 6에서 멈추도록 위로 밀어 올림. 이야기 장면 중에는 숨김. 연습 결과를 보관하거나 주문 제작 결과를 닫으면 `sell`, 첫 판매 완료(주문을 다 채운 판매)면 `done`. 안내 중 첫 판매는 네임드 손님이어도 이야기·후일담·선택 장면을 붙이지 않고, 손님 맞이에서도 선택 장면을 굴리지 않음.

**복귀 카드:** 3장 "Workshop 복귀 안내". 화면이 그려진 뒤 대화상자로 띄우고, 떠 있는 동안 숙련된 붕어빵 제작을 멈춤(다른 창과 같음). 닫으면 보고를 지움.

### 기준

- 따로 정한 디자인 해상도는 없습니다. 콘텐츠 폭 `w = min(화면폭, 560)`이고 태블릿에서는 가운데 정렬합니다. 크기는 `w`에 대한 비율로 정합니다.
- 배경 장면은 180×400 장면 단위 격자를 화면을 덮도록 확대하고 아래쪽에 맞춥니다. 카운터 선은 y=304입니다.
- 골든 테스트 기준 화면은 360×800, 390×844, 412×915입니다.

### 홈 화면 (`lib/ui/night_home.dart`)

아래에서 위 순서로 쌓입니다.

| 층 | 요소 | 위치·크기 | 키 |
| --- | --- | --- | --- |
| 1 | 노점 배경 | 전체 | `stall-scene` |
| 2 | 날씨 효과 | 전체, 터치 통과, 20fps | |
| 3 | 차양·기둥·등불 | 전체 | |
| 4 | 손님 방문 | 왼쪽, 폭 w×0.18~0.38 | |
| 5 | 굽는 판(화로) | 예전 홈: 폭 `w×0.94`, 높이 폭×40/88. Workshop 홈: 왼쪽 8, 폭 `w − 16`, 높이 폭×그림 높이/폭(941×470, DEC-038). 바닥 = 내비 높이 − 10 | `griddle` |
| 6 | 황금 찬스 | 굽는 판 위 6칸 중 하나 | `golden-chance-N` |
| 7 | 상단 HUD + 굽기 영역 | 폭 w, 위 = 안전 영역 | |
| 8 | 조리 장면 컷 | 오른쪽 8px, 폭 `w×0.32`, 높이 `w×0.27` | |
| 9 | 하단 내비게이션 | 아래, 높이 66 + 안전 영역 | |

**상단 HUD**
- 1줄
  - 레벨 배지(비율 26). 누르면 레벨 미션이 열립니다. 키 `level-mission-entry`.
  - 보유 붕어빵(비율 44). 키 `balance-value`, `lifetime-value`.
  - 초당/클릭당(비율 30). 키 `auto-rate`, `tap-rate`.
- 2줄
  - 메뉴 둥근 버튼 48×48. 받을 보상 수를 배지로 표시합니다. 키 `menu-menu`.
  - 가운데 환생·칭호 문구.
  - 설정 버튼.

**굽기 영역**
- 굽기 영역 전체가 탭 영역입니다. 키 `fish-button`.
- 누르고 있으면 250ms마다 굽습니다. Space/Enter 키로도 구울 수 있습니다.
- 콤보 표시는 위 8px에 나옵니다. 콤보 20 이상, 50 이상에서 글자 크기와 색이 바뀝니다.

**하단 내비게이션**: 버튼 4개가 같은 폭으로 놓입니다.

| id | 표시 | 키 |
| --- | --- | --- |
| menu | 메뉴 | `menu-menubar` |
| skills | 스킬 | `menu-skills` |
| skins | 꾸미기 | `menu-skins` |
| shop | 상점 | `menu-shop` |

**화면 크기 대응:** 글자가 크거나 굽기 영역이 360보다 작으면 HUD와 굽기 영역이 스크롤됩니다(`home-scroll`).

### 패널(시트)

- 구형 GameHome(도달하지 않는 코드)에서는 모든 패널을 `GameHome._open(id)`(`lib/ui/game_app.dart`)로 엽니다. 구형은 화면 높이 92%의 바텀시트입니다. Workshop 홈은 `WorkshopPage._open(id)`가 `showWorkshopWindow`(`lib/ui/workshop_windows.dart`)로 같은 모양의 창을 엽니다. 전체 높이이고 바닥 받침이 하단 메뉴를 덮습니다(위 "Workshop 창").
- 시트 구성: 위에 잔액 표시, 그 아래 제목 프레임, 오른쪽 위 닫기 버튼, 아래 돌아가기 버튼.
- 잔액 표시는 shop과 skins 패널에서 코인, 나머지에서는 붕어빵입니다.

| id | 패널 | 파일 |
| --- | --- | --- |
| menu | 메뉴 목록 | `ui/public_menus.dart` `MenuPanel` |
| skills | 스킬 상점 | `ui/skill_shop.dart` |
| shop | 상점(장비·꾸미기·테마·황금) | `ui/shop_panel.dart`, `ui/gold_widgets.dart` |
| support | 아이템·코인 상점 | `ui/support_panels.dart` `SupportPanel` |
| daily | 일일 미션 | `ui/support_panels.dart` |
| skins, skins:avatar, skins:stall | 옷장 | `ui/public_menus.dart` `WardrobePanel` |
| missions | 레벨 미션·환생 | `ui/level_missions.dart` |
| records | 통계 | `ui/progress_panels.dart` |
| event | 주간 도전 | `ui/progress_panels.dart` |
| achievements, achievements:collection | 업적·도감 | `ui/progress_panels.dart` |
| share | 공유 | `ui/progress_panels.dart` |
| ranking | 온라인 랭킹 | `ui/ranking_panel.dart` |
| friends | 친구 | `ui/friends_panel.dart` |
| invite | 초대(개발자 전용) | `ui/invite_panel.dart` |
| settings | 설정 | `game_app.dart` `_settings` |

**메뉴 목록 순서:** 도감 · 업적 · 통계 · 온라인 랭킹 · 배경 테마 · 일일 미션 · 주간 도전 · 레벨 미션 · 친구 · 공유

**모든 화면 위에 뜨는 것**(`ui/celebration.dart`)
- 축하 배너: 화면 중앙보다 위, 최대 폭 320.
- '미션 달성!' 알림: 위쪽에 2.6초 동안.
- 오프라인 보상 창.

---

## 11. 디자인 토큰

파일: `lib/ui/cozy_style.dart`. 글꼴은 Jua입니다(`assets/fonts/Jua-Regular.ttf`, OFL).

**기호 대체 글꼴:** Jua에는 `·` `…` `‘’` `→` `「」` `—` `×` `●○` 같은 문장 부호·기호가 없습니다. 이 글자들은 `BungeoSymbols`(`assets/fonts/BungeoSymbols-Regular.ttf`, 약 36KB)로 그립니다. Noto Sans KR(OFL)에서 굵기 600으로 기호 범위만 잘라 이름을 바꾼 글꼴이고, 라이선스는 `BungeoSymbols-OFL.txt`입니다. 다시 만들 때는 `python tools/build_symbol_font.py <NotoSansKR[wght].ttf>`. 코드에서는 `fontFamily: 'Jua'`를 쓰는 모든 곳(테마·`TextTheme`·직접 지정한 `TextStyle`)에 `fontFamilyFallback: Cozy.fontFallback`을 함께 씁니다. 새 `TextStyle`에 Jua를 지정할 때도 같이 넣어야 합니다(버튼 테마처럼 기본 글자 모양을 물려받지 않는 곳이 있음). `test/font_coverage_test.dart`가 `lib/`와 `config/development_balance.json`의 모든 글자가 두 글꼴 중 하나에 있는지 확인합니다.

| 이름 | 색 | 용도 |
| --- | --- | --- |
| cream | `#FEF1D6` | 기본 배경·패널 안쪽 |
| creamDeep | `#FEE6BC` | 비활성 |
| wood | `#7D3419` | 테두리·버튼 |
| woodLight | `#C1682D` | 얇은 테두리 |
| woodDark | `#68311F` | 홈 배경·프레임 |
| ink | `#3A1E1A` | 본문 글자 |
| inkSoft | `#7A6963` | 보조 글자 |
| orange | `#FBAF5A` | 강조·진행 막대 |
| orangeDeep | `#E39E57` | 강조 테두리·테마 기준색 |
| brick | `#AC3613` | 닫기 버튼·배지 |
| honeyLight·honey·honeyDeep | `#FFD054`·`#FDBE38`·`#FEB432` | 주 버튼·선택된 탭의 노란 면(위→아래), 슬라이더 채운 부분, `FilledButton` 바탕 |
| amber | `#F07D0C` | 노란 버튼·선택 탭 아래 경계, 탭 꼭지 |
| tangerine | `#FD9607` | ON 토글 |
| tan | `#E9B47E` | 카드 안쪽 연한 선, 고르지 않은 탭·비활성 버튼 테두리 |
| peach·peachEdge | `#FDD09C`·`#F0B47A` | 효과 칩 바탕·테두리, 크림 버튼 아래 경계 |
| taupe | `#8A6E62` | OFF 토글, 슬라이더 빈 부분 |
| knob | `#FFF6E8` | 토글·슬라이더 손잡이 |
| shadow·shadowDeep | 검정 33%·40% | 패널·창 그림자 |

버튼·탭·칩·토글·슬라이더 색은 `3.5_completed_game_mockups/서브UI5종`에서 뽑았습니다. 근거는 `coordination/visual-00-gap.md`와 `coordination/visual-02.md`에 있습니다.

**공통 위젯**

| 위젯 | 모양 |
| --- | --- |
| CozyPanel | 반경 12. 나무 테두리 2 + 안쪽 연한 선(tan) 1.5 |
| CozyRoundButton | 48 원형(나무 테두리 2 포함), 눌림 |
| CozyFrame | 반경 18/14 |
| CozyCloseButton | 44 정사각형(짙은 테두리 1.5 + 크림 테두리 3 + 벽돌색), 눌림 |
| CozyBackButton | 높이 48 이상(여백 3 포함 54), '돌아가기', 아래 경계(peachEdge), 눌림, Key `sheet-back` |
| CozySettingRow | 설정 한 줄 |
| CozyOnOff | 84×36 켜기/끄기(tangerine/taupe, knob 손잡이) |
| CozyPrimaryButton | 주 버튼. 최소 높이 44, 짙은 나무 테두리 2 + 노란 그라데이션 + amber 아래 경계 3, Jua 18. `onPressed`가 null이면 creamDeep 면에 흐린 글자 |
| CozyButton | 보조 버튼. CozyPrimaryButton과 같은 모양에 크림 면 + peachEdge 아래 경계 |
| CozyChip | 효과 칩. peach 바탕 + peachEdge 테두리, 반경 8, Jua 14 |
| CozyTabBar·CozyTab | 같은 폭 탭 한 줄, 높이 44. 선택 탭은 노란 면 + 아래 꼭지, 나머지는 크림. 각 탭의 Key는 `CozyTab.key`로 탭 대상에 붙음 |
| CozyMenuRow | 메뉴 줄. 최소 높이 64, 아이콘 48, 제목 Jua 22, 오른쪽 `>` |
| CozyPressable | 위 버튼들이 쓰는 눌림 처리. 누르는 동안 2px 내려감 |
| CozyMotion | 모션 줄이기 전달. `GameApp`이 설정의 모션 줄이기 값으로 앱 전체를 감쌈. 켜져 있거나 기기 애니메이션 끄기면 눌림·토글 이동을 하지 않음 |
| 슬라이더(테마) | `CozySliderTrackShape`·`CozySliderThumbShape`. 두께 12, 짙은 테두리, 눈금 없음, 손잡이 반지름 12 |

**글자 크기**

| 쓰는 곳 | 크기 |
| --- | --- |
| 시트 제목 | Jua 28 |
| 메뉴 줄 제목(CozyMenuRow) | Jua 22 |
| 하단 내비 글자 | Jua 21 |
| 잔액 표시 | Jua 20 |
| 주 버튼·탭 | Jua 18 |
| 메뉴 줄 제목(현재 MenuPanel) | 18 굵게 |
| 칩 | Jua 14 |
| 보조 글자 | 12 |

간격은 4·6·8·10·12·16을 씁니다. 패널 안쪽 여백은 보통 16입니다.

2026-10-24 비주얼 조정 2단계에서 공통 위젯의 모양과 테마(FilledButton·Switch·Slider·Chip 색)를 바꾸고 새 위젯을 추가했습니다. 화면 배치는 바꾸지 않았고, 새 위젯은 아직 화면에 쓰이지 않습니다(3단계부터 적용). 2026-11-09 가출시 3단계의 판매 카운터·손님 창·메뉴 아래 버튼에서 `CozyPrimaryButton`·`CozyButton`을 처음 씁니다(높이 40~44, Jua 15~16).

---

## 12. 이미지·소리

### 이미지 경로 (`lib/ui/pixel_sprites.dart`)

| 종류 | 경로 |
| --- | --- |
| 붕어빵 | `fish/redbean.png`, 무늬는 `fish/redbean@<pattern>.png` |
| 토핑 | `topping/<id>.png` |
| 배경 | `bg/<id>.png`, 밤 `bg/<id>_night.png` |
| 화로 | `stove/<id>.png`, 빈 굽는 판 `stove_empty/<id>.png`·붕어빵만 `stove_fish/<id>.png`(941×470, `tools/apply_25_art.py`) |
| 장식 | `deco/<id>.png` (위치는 `night_stall_painter.dart` `decorationAt`) |
| 등불 | `stall/postlamp_<색>.png` (id는 `<색>lamp`) |
| 아바타 | `avatar/<girl·boy>/base.png`, `avatar/<character>/<slot>_<id>.png` (여백을 잘라내고 위치는 `avatarTrimOffsets`), 앞/뒤 조각 `_front`·`_back`, 지울 마스크 `_cut`, 피부톤 복사본 `@skin2`·`@skin3` |
| 얼굴 부분 | `parts/<character>_<front·side>_<eyes·mouth>_<frame>.png` (위치는 `avatarPartPivots`, `avatarFaceAnchors`) |
| 스킬 | `skills/tap_N.png`, `skills/auto_N.png` |
| 아이콘 | `icons/<name>.png` (이름을 `iconNames`에 등록) |
| 효과 | `fx/minifish, sparkle, fairy_up, fairy_down, butter_glow`, 넘침 방울 `fx/overflow_<batter·redbean·custard·cocoa>`(32×48), 뒤집기 고리 `fx/flip_ring, flip_ring_fill`(512×512) |
| 짤주머니 | `cook/piping_bag_<batter·redbean·custard·cocoa>[_squeeze].png`(128×192, 손가락 점 (64, 188), `pipingPastes`) |
| 속 칠 질감 | `mold/paint_<redbean·custard·cocoa>.png`(256×256 불투명 심리스, `tools/apply_25_art.py --only textures`로 v2 생성본을 줄이고 이음매 보정) |
| 화면 장식 | `ui/wardrobe_bg, offline, title_fish` |
| 이벤트 배너 | `event/spring·summer·autumn·winter` |
| 조리 장면 | `cook/girl_1~6.png` (700ms 간격 반복) |

- 모든 경로는 `assets/images/` 아래이고, **새 폴더는 `pubspec.yaml`의 assets에도 등록**해야 합니다.
- 파일이 없으면 오류 없이 그려지지 않습니다.
- 그림이 없는 아이템은 `blankCosmetics`에 올립니다. 붕어빵·가게 아이템은 모두 그림이 있어야 하고(`test/pixel_art_test.dart`), 아바타 아이템은 그림이 준비될 때까지 꾸미기에서 숨깁니다(`PixelSprites.avatarArtReady`, 7장). 예전 `artPending` 목록은 26번 4-4에서 없앴습니다.
- 아바타 그림을 바꾸거나 추가했으면 `python tools/avatar_layers.py`를 실행합니다(fringe → face → worn → derive → skin → trim, 2026-11-18 기준 약 20분). 머리 사이 흰 배경 잔여를 메우고, 얼굴 부분 그림·입은 모습 레이어와 `_cut`·피부톤 복사본을 만들고, 280×520 그림의 여백을 잘라낸 뒤 `lib/avatar_atlas.dart`를 다시 만듭니다. 전수 확인은 `python tools/avatar_audit.py`(`build/avatar_audit/audit.md`)와 `flutter test tools/preview_avatar_audit_test.dart`(`build/avatar_audit/<girl·boy>.png`, 모든 아이템·피부톤×머리 비교 이미지). 이미 잘라낸 그림은 기록된 위치를 유지합니다. 측정값은 `tools/avatar_layers.json`에 저장됩니다.

### 소리 (`lib/game_audio.dart`, `lib/music_config.dart`, `lib/feedback_config.dart`)

| 소리 | 파일 | 언제 |
| --- | --- | --- |
| tap | `audio/tap.wav` | 굽기. 최소 간격 60ms |
| purchase | `audio/purchase.wav` | 구매 |
| levelUp | `audio/levelup.wav` | 레벨업·환생 |
| reward | `audio/reward.wav` | 그 밖의 보상, 미션 달성, 돌아오기 환영 |
| 배경 음악 | `audio/bgm_<mood>.wav` (24초 반복) | day, spring, dusk, rain, snow, night |

- 기본 볼륨은 효과음 70, 음악 40입니다.
- 앱이 백그라운드로 가면 음악을 멈춥니다.
- 미사용 파일 `audio/bgm.wav`는 중복·불필요 파일 정리에서 삭제했습니다.
- 18단계 기획: 배경 음악을 설정에서 따로 고르고, 붕어빵 익는 소리(`audio/sizzle_loop.wav`)를 겹쳐 트는 옵션을 더합니다([16장](#16-기획-중인-변경)).

### 연출 값 (`lib/feedback_config.dart`)

| 항목 | 값 |
| --- | --- |
| 떠오르는 +N 최대 개수 | 8 |
| +N 표시 시간 | 700ms |
| 부스러기 최대 개수 | 48 |
| 탭당 부스러기 | 4 |
| 축하 시간 | 2200ms (동작 줄이기 1600ms) |
| 색종이 최대 | 36 |
| 미션 알림 | 2600ms |
| 레벨업 배너에 보이는 새 아이템 | 3개 |

---

## 13. 빌드·실행·테스트

| 항목 | 값 |
| --- | --- |
| 도구 | Flutter 3.47.5 / Dart 3.13.4, JDK 17, Android SDK 36 |
| 패키지 이름(applicationId·namespace) | `com.todaybungeoppang.app` (2026-11-17 23번 6단계에서 `com.todaybungeoppang.todays_bungeoppang`에서 변경. Play에 올린 뒤에는 못 바꿈. Dart 패키지 이름 `todays_bungeoppang`은 그대로) |
| SDK | minSdk 24 · targetSdk 36 · compileSdk 36 (Flutter 3.47.5 기본값, `build.gradle.kts`가 `flutter.*`를 따름) |
| 앱 버전 | `pubspec.yaml` `version: 0.1.0+1`. `+` 뒤 versionCode는 Play 업로드마다 +1(재사용 불가), versionName은 가출시 동안 `0.1.x`, 정식 출시 `1.0.0` |
| release 서명 | `android/key.properties`(커밋 금지)의 업로드 키로만 서명. 파일이 없거나 항목·키 파일이 없으면 release 작업(`flutter build appbundle/apk --release`, `flutter run --release`)이 "Release build stopped (release 빌드 중단)" 오류로 멈춤. debug 키로 대체하지 않음. debug·profile은 키 없이 빌드됨. 키 만들기·빌드·설치: [release_signing.md](release_signing.md) |
| 권한(메인 매니페스트) | `INTERNET`(온라인 가출시, DEC-027). 병합 결과는 23번 6단계 결과 표 |

**자주 쓰는 명령**

| 작업 | 명령 |
| --- | --- |
| 패키지 받기 | `flutter pub get` |
| 테스트 | `flutter test` |
| 실행 | `flutter run` |
| 디버그 APK | `flutter build apk --debug` |
| Play 업로드용 AAB | `flutter build appbundle --release` (key.properties 필요) |
| 실기기 확인용 release APK | `flutter build apk --release` → `adb install build\app\outputs\flutter-apk\app-release.apk` |
| 골든 다시 만들기(의도한 홈 화면 변경 후에만) | `flutter test --update-goldens test/workshop_home_golden_test.dart`(실제 홈), 구형은 `test/home_golden_test.dart` |
| 서버 가격표 다시 만들기 | `UPDATE_PREMIUM_CATALOG=1 flutter test test/premium_catalog_test.dart` |
| 서버 배포 | `firebase_local.cmd deploy --only "functions,firestore"` (`firebase/` 폴더, [online_setup.md](online_setup.md) 4장) |
| 에뮬레이터 | `tools/run_android_emulator.ps1` |

**한글 경로 문제:** 셰이더 도구와 Kotlin 데몬이 한글 경로에서 실패합니다.
1. `subst B: "<프로젝트 경로>"`로 영문 드라이브를 만들고 `B:`에서 실행합니다.
2. 릴리스·debug APK 빌드는 추가로 `GRADLE_USER_HOME=D:\DevMoved\GradleCache`, `PUB_CACHE=C:\PubCacheBungeoppang`을 지정합니다(2026-11-17 debug APK도 이것 없이는 Gradle 데몬·`jni` CMake가 한글 사용자 폴더에서 실패). 빌드 뒤 기본 캐시로 `flutter pub get`을 다시 실행해 테스트 환경을 되돌립니다.
   `C:\GradleCache`는 `D:\DevMoved\GradleCache`로 가는 정션이다. 정션 경로를 Gradle 홈으로 쓰면 `*.gradle.kts`를 고친 뒤 다시 컴파일할 때 `Unresolved reference 'println'`·`'orEmpty'`처럼 Kotlin 표준 함수를 전부 못 찾고 실패한다(스크립트를 안 고치면 예전 컴파일 결과를 재사용해서 성공하므로 늦게 드러남). 2026-11-17 23번 6단계에서 확인, 실제 경로로 바꾸면 통과.
3. `processDebugResources`가 `Unable to delete directory … .ap_`(다른 프로세스가 사용 중)로 실패하면 방금 만든 파일의 일시적 잠금입니다. 코드를 고치지 말고 같은 명령을 다시 실행합니다(2026-11-03 재실행으로 통과).

**분석 제외:** `analysis_options.yaml`은 `firebase/local_tools/**`(Firebase CLI가 받은 Dart 템플릿)를 분석하지 않습니다. 2026-11-17(23번 7단계, App Check·키 파일 뒤) 기준 `flutter analyze`는 error·warning 0(info 72), `flutter test`는 698개 통과·건너뜀 0(약 7~12분). `no_tracking_sdk_test`의 release 병합 매니페스트 검사는 `build/app/intermediates/…/release/` 산출물이 매니페스트·`build.gradle.kts`·`pubspec.lock`보다 새것일 때만 실행되고, 없으면 1개 건너뜀으로 나온다. 서버 `npm test`는 86개 통과, 에뮬레이터 통합 8개 통과입니다.

**온라인 빌드:** 키는 `1_app_development/dart_defines/online.json`(gitignore. `online.example.json`을 복사해 채움. 키 6개: `FIREBASE_API_KEY`·`FIREBASE_APP_ID`·`FIREBASE_SENDER_ID`·`FIREBASE_PROJECT_ID`·`KAKAO_NATIVE_APP_KEY`·선택 `APP_CHECK_DEBUG_TOKEN`)에 두고 파일째 넘깁니다.
```
flutter run --dart-define-from-file=dart_defines/online.json
flutter build appbundle --release --dart-define-from-file=dart_defines/online.json
```
- 키가 하나라도 없으면(`APP_CHECK_DEBUG_TOKEN` 제외) 오프라인으로 동작합니다.
- 파일로 넘긴 값도 Gradle의 `dart-defines`로 전달되어 카카오 로그인 scheme(`kakao<네이티브 앱 키>`)이 매니페스트에 들어갑니다(2026-11-17 가짜 키 파일로 release 빌드해 병합 매니페스트에서 확인).
- 서버 배포는 `firebase/firebase_local.cmd`(저장소 안 `local_tools`의 Node 22·Firebase CLI 실행)로 `firebase_local.cmd deploy --only "functions,firestore"`. 순서와 콘솔 작업은 [online_setup.md](online_setup.md).
- Gradle flavor는 없습니다. Play Games용 playGames/noPlayGames 구분은 16단계에서 없어졌습니다.

**테스트 지도**

| 영역 | 파일 |
| --- | --- |
| 경제 | economy, economy_expansion, economy_persistence, economy_simulation, skill_shop |
| 저장·이전 | serialization, stage7_regression, stage8_progress, stage10_feedback, stage12_customization |
| 미션·보조 | level_missions(_widget), mission_alerts, support_system, support_widget |
| 진행·환생 | stage8_progress, stage11_endgame |
| 꾸미기·그림 | public_menus(_widget), stage12_customization, pixel_art, stage14_systems, day_night, stage17_avatar_layers |
| 온라인 | online_backend, online_setup(키 파일·gitignore·App Check), stage9_ranking, stage16_kakao_ranking, premium_catalog, premium_flow, invite_system, invite_widget |
| 화면 | widget_test(공용 `mountGame`, `FixedTime`), home_golden, stage7_widget, stage8_widget |
| Workshop 제작·홈(24번) | cooking_paint, cooking_controls, cooking_flip, flip_circle_control, workshop_two_molds, workshop_home_layout, workshop_home_golden, step02_home, workshop_full_flow(새 설치~주문 제작 통합 흐름) |
| 규칙 | no_tracking_sdk |

---

## 14. 추가 작업 체크리스트

### 저장되는 상태를 건드리는 기능

1. 값은 `*_config.dart`에, 계산은 `*_rules.dart`에 둡니다.
2. 필드를 상태 클래스에 추가합니다. 생성자, 초기값, `toJson`, `fromJson`을 모두 고치고 잘못된 값이면 `FormatException`을 냅니다.
3. `GameState.formatVersion`을 올리고 `fromJson`에서 `version >= N ? 읽기 : 초기값`으로 처리합니다. 옛 저장 데이터의 값을 지어내지 않습니다.
4. 코인이 오가면 고유 id로 `support.transact`를 씁니다.
5. 시간은 `gameNow`를 쓰고, 날짜·주가 바뀔 때 할 일은 `observeSupport`/`rollTo`에 붙입니다.
6. 명령은 `busy || _away` 확인 → `tick()` → `before = state.copy()` → 변경 → `_commit`/`_commitWith(before, 이벤트)` 순서로 씁니다.
7. 새 이벤트를 만들면 `GameEventKind`와 소리 연결(`celebration.dart`)을 추가합니다. 받을 보상이면 `claimableGoals`에도 추가합니다.
8. 테스트를 추가합니다.
   - 저장 왕복과 잘못된 값 거부
   - 옛 버전 이전
   - 저장 실패 시 되돌림(`failNextSave`)
   - 자정·월요일 경계
   - 3개 화면 크기 × 글자 크기
9. 이 문서와 README를 갱신합니다.
10. Workshop 진행(`WorkshopState`)이면 `toJson`의 `schema`를 올리고 `fromJson`의 허용 목록·옛 버전 이전(새 필드가 옛 버전에 있으면 거절)을 고치며, `lib/workshop_storage.dart`의 구매 보호 schema 목록(`[2,…,N]`, 저장 검사 `!= N`)도 같이 올립니다. SQLite `user_version`은 표 구조가 바뀔 때만 올립니다(26번 5-1단계 schema 7 예).

### 스킬 단계 추가

1. `lateTapSkillConfig`/`lateAutoSkillConfig` **끝에만** 추가합니다.
2. **저장 형식 버전을 올리고, 옛 저장 데이터에 없는 스킬 id를 0으로 채웁니다.** 이렇게 하지 않으면 기존 저장 데이터를 읽지 못합니다.
3. 스킬 그림 `skills/<id>.png`를 넣습니다.
4. 황금 붕어빵 조기 해금 가격이 생기므로 서버 가격표를 다시 만들고 배포합니다.
5. `economy_expansion_test`(단계 수 16), `economy_simulation_test`를 확인합니다.
6. (신규 Workshop) `config/development_balance.json` `skill_purchase.entries`에 붕어빵력·황금(0이면 그 단계는 황금 없이 레벨업, DEC-041)을 넣고 `tools/development_balance.py`를 돌린 뒤, 서버 견적이 바뀌므로 **서버를 먼저 배포**합니다.

### 레벨 미션 변경

- 작은 수치 조정은 `offlineLevels`만 고칩니다.
- 큰 변경은 새 시즌 id를 만들어 `missionSeasons`에 등록하고, 옛 시즌은 그대로 둡니다. 저장 데이터에 시즌 id가 들어 있기 때문입니다.
- 새 `MissionKind`를 만들면 `missions.dart`에 진행도 계산을 추가합니다.

### 업적 추가

1. `achievementDefinitions` 끝에 추가합니다. **id를 지우거나 바꾸지 않습니다.**
2. 새 측정 항목이면 `AchievementMetric`과 `achievementProgress`에 추가합니다.
3. `stage8_progress_test`의 개수(24)를 고칩니다.
4. Lv.10은 업적 12개를 요구하므로 밸런스를 함께 확인합니다.

### 일일·주간 목표 추가

- 끝에 추가하고 id는 고유해야 합니다.
- 일일 목표를 늘리면 전체 완료가 어려워집니다.
- **주간 목표를 늘리면 과거 주의 완료 판정이 바뀝니다**(완료 = 받은 수 ≥ 목표 수). 필요하면 `weeklyConfigVersion`을 올립니다.

### 부스트 추가

`BoostKind`와 `boostDefinitions`에 추가합니다. 화면은 목록을 자동으로 표시합니다.

### 꾸미기 아이템 추가

1. `cosmetic_config.dart`에 `CosmeticDefinition`을 추가합니다. id는 `^[a-z0-9_]{1,32}$` 형식이어야 합니다(서버 검사).
2. [12장](#12-이미지소리) 경로에 그림을 넣습니다. 아바타는 girl과 boy 둘 다 필요하고, 가능하면 '입은 모습' 원본을 3.3 폴더에 넣고 `WORN_ITEMS`에 한 줄 더한 뒤 `python tools/avatar_layers.py`를 돌립니다. 그림이 아예 없는 기본·빈 아이템은 `blankCosmetics`에 올리고, 그림이 아직 없는 유료 아바타 아이템은 꾸미기에서 자동으로 숨겨집니다.
3. 종류별 추가 작업
   - 장식: `decorationAt` 위치
   - 배경: `musicMoodFor`, 밤 이미지
   - 등불: `postlampColors`
4. 코인 가격이 있으면 서버 가격표를 다시 만들고 서버를 배포합니다.
5. 아바타 아이템이 몸을 감싸면(목도리 뒤쪽, 후드 위로 내려오는 머리) `<slot>_<id>_back.png`/`_front.png`를 같은 캔버스에 추가합니다. 위치·크기·회전·순서를 따로 맞춰야 하면 `rigPlacements`에 적습니다. 그다음 `tools/avatar_layers.py trim`을 실행합니다.
6. 새 얼굴 프레임(예: 눈 `wink`)은 `RigChannel.frames`에 이름을 넣고 `parts/<character>_<view>_<channel>_<frame>.png`와 피벗을 추가합니다(`tools/avatar_layers.py`의 `FACES`에서 만들거나, 직접 그린 그림의 피벗을 `avatar_layers.json`에 적고 다시 실행). 새 모션은 `MotionClip`을 정의하고 `AvatarFace`(`talking`, `onTap`)나 `AvatarMotion.play`로 재생합니다.
7. **새 칸(slot)을 만드는 것은 큰 작업입니다.**
   - 고칠 곳: enum, 분류·탭, 기본값, `cosmeticSlotSince`, 저장 형식 버전, 라벨, 경로
   - 서버의 외형 칸 수 제한(16)도 확인합니다.

### 황금 붕어빵 상품 추가

1. `goldProducts`에 추가합니다. 큰 묶음일수록 원당 개수가 같거나 많아야 합니다.
2. 서버 가격표를 다시 만들고 배포합니다.
3. Play Console에 같은 id로 소모성 상품을 만듭니다.

### 메뉴·패널 추가

1. `lib/ui/<name>_panel.dart`를 만듭니다. `SingleChildScrollView` + 여백 16 + Cozy 위젯을 쓰고, 프레임과 제목은 넣지 않습니다.
2. `game_app.dart`의 제목 목록과 `_body`에 id를 추가합니다.
3. 들어가는 곳을 정합니다. 메뉴 목록 줄(`MenuPanel`), 하단 내비(`night_home.dart`), HUD 버튼 중 하나입니다.
4. 아이콘이 새로 필요하면 `iconNames`에 이름을 넣고 `icons/<name>.png`를 추가합니다.
5. 보상 배지가 필요하면 `claimableGoals`와 `claimDestinations`에 추가합니다.
6. 키는 `menu-<id>` 규칙을 지킵니다.

---

## 15. 알려진 문제

2026-10-08에 확인한 것입니다. 해결하면 이 목록에서 지워 주세요. (2026-11-17: "릴리스 빌드가 debug 키로 서명됨"은 23번 6단계에서 업로드 키 서명·키 없으면 빌드 중단으로 해소해 지움. "서버 App Check 꺼짐"은 23번 7단계에서 모든 callable 강제·앱 Play Integrity로 해소해 지움.)

| 문제 | 내용 |
| --- | --- |
| 붕어빵력은 타당성 검증만 함 | 서버는 붕어빵력을 재생하지 못하고 시간·보유 스킬 기준 상한만 확인합니다. 조작된 앱은 상한 안에서 붕어빵력을 부풀릴 수 있습니다. 황금은 서버 지갑에서만 움직입니다. |
| 노점 부품 그림 없음 | `assets/images/stall/`에 `awning`, `post`, `postlamp`, `counter`(`_snow`) 파일이 없어서 해당 층이 그려지지 않습니다. 현재 있는 것은 `postlamp_lilac/mint/rose`뿐입니다. |
| 온라인은 Android 전용 | iOS에서는 오프라인으로만 동작합니다. |
| 도달하지 않는 구형 UI가 남아 있음 | `ui/game_app.dart`의 `GameHome`, `ui/skill_shop.dart`, `ui/level_missions.dart`, `ui/invite_panel.dart`, `lib/composite_purchase_coordinator.dart`. 앱은 `WorkshopPage`로만 들어가며 release 빌드에서는 빠집니다. 지우면 이 화면을 띄우는 구형 위젯 테스트 약 49개도 지우고 `mountGame`(`test/widget_test.dart`)이 `GameHome`을 거치지 않게 고쳐야 합니다. 가출시 뒤에 정리(2026-11-16 사용자 결정). |

---

## 16. 기획 중인 변경

**2026-10-14 최신 사용자 확정 기획이며 아직 구현하지 않았다.** 선택형보상광고하루2회로황금획득을추가허용한다. 이는1장현재광고금지의미래예외이며SDK/데이터/지급량·테스트/정책검토는미정이다. [광고계약](../11_하루2회보상형광고.md)을따른다. 현재 구현은1~15장과코드다. 상세는 [기획 안내](../README.md)·[요약](../01_요약기획서.md)·[상세](../02_상세기획서.md)를 따른다. 개정 전 stage18 초안 기록은 문서 정리 과정에서 삭제했다.

| 영역 | 최신 목표 |
| --- | --- |
| 성장/숙련 | 레시피획득→맛별큰틀연습→요구량AND조건충족→맛도감완성/6구해금. 팥기본이나팥도숙련필요 |
| 큰틀/도감 | 보유레시피로숙련전후연습·즉석판매. 맛×익힘5단계,발견/완성분리 |
| 6구/재고 | 획득AND숙련한맛만랜덤후보. 직접수확만재고반영,자동/오프라인제품지급없음 |
| 주문/손님 | 레벨별종류/수량증가·개인대기/줄대기·재고/즉석판매·지속취향도감 |
| 영업/신선도 | 영업시작과접속분리·같은날중복없음·실제영업일0일제작/5일소멸·달력공백제외 |
| 붕어빵력 | 영업중만자동·앱종료에도영업지속·복귀시기존8시간/50%정산. 기존사용처/자산유지 |
| 오디오/출시 | 독립BGM/굽기/SFX,한국어국내Android·현재도구유지·문구/이미지분리 |

### 가출시 범위 (2026-11-03 사용자 확정, 구현 전)

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 1단계 결정. 상세는 [결정 취합](../2.1.1_game_rules_and_decisions/00_결정취합.md)의 「가출시 범위 결정」 절.

| 항목 | 결정 | DEC |
| --- | --- | --- |
| 온라인 | Firebase·카카오 로그인·Play 결제 켬. 황금은 서버 검증 후 지급 유지, 로컬 황금 생성 없음 | DEC-027 |
| 광고 | 제외. SDK 미도입·광고 버튼 숨김. 1장 '광고·추적 SDK 금지'와 `no_tracking_sdk_test` 유지. 2026-11-18: 광고는 출시 후 첫 업데이트(별도 브랜치, DEC-049), 분석은 `firebase_analytics`만 허용으로 바뀔 예정(DEC-045) | DEC-028 |
| 레벨 | Lv.1~50 전체(11~50은 임시 곡선). 2026-11-18 유지 재확인 | DEC-029, DEC-050 |
| 맛 | 팥 기본, 슈크림·초코 획득 경로 유지 | DEC-029 |
| 손님 | 네임드 8명 전체 + 무기명 | DEC-029 |
| 유료·온라인 노출 | 황금 상점(IAP)·유료 아바타 노출. 랭킹·친구·초대 숨김. 2026-11-18: 그림이 준비 안 된 유료 아바타(지금은 모자 4종)는 숨김 | DEC-029, DEC-066 |
| 테스트 | Play 비공개 테스트로 바로 배포, 12~20명·14일 이상 | DEC-030 |
| 부분 판매 집계 | 판매 횟수 = 주문 완료 1회. 별점 = 판매 당시 품질·신선도 고정, 개수 가중 | DEC-017/023/007, DEC-018/022 |

날짜경계·영업종료/다음날복귀·맛별연습량/실패인정·5칸등록/숙련관계·주문표/보상·6구배정/주기/익힘/대기·신선도가격등은 [DEC](../00_공통기준.md#5-결정-관리)에미정으로남겼다. 차기저장버전/세션영속은미정,이전101시간일정은새범위에사용하지않는다. 기존실제일일미션KST자정은새영업일경계의확정근거가아니다.

## 17. 현재 환경 소스 변경 — 오디오 v13·공통 임시 계산

v13은 오디오 설정 musicSelection/cookingSound/cookingVolume만 추가한다. v1~12 자산 파싱은 유지하고 구형 자동 배경 모드를 보존한다. 사업 운영·숙련·재고/복합 거래의 실제 저장 이전은 포함하지 않는다. 변경·다운그레이드/실제 SQLite 검수는 미실행이다.

설정 화면의 배경음 선택은 배경/시간대와 독립이며 ‘배경에 맞춤’으로 기존 모드로 돌아간다. 굽기 루프는 실제 활동 소스가 있을 때만 별도 player로 출력하고 설정/음량·전경에 따라 정지한다. 실제 신규 스페셜 붕어빵/숙련된 붕어빵 제작 활동 전달은 미연결이다. 오디오 기본값은 development_balance.json에서 development_audio_defaults.dart로 생성한다. sizzle_loop.wav는 generate_cooking_sound.py로 직접 합성(CC0)했다.

development_balance.dart/asset 로더와 development_rules.dart는 새 복합 견적·익힘·숙련·신선도·KST 날짜·복구 라우팅 계산의 소스를 제공한다. 실제 서버 지갑/광고/신규 게임 흐름 연결은 하지 않았다. [15번 소스 구현·검수 대기](../15_현재환경소스구현과검수대기.md)를 따른다. 테스트 코드는 작성했으나 앱 실행·컴파일/Flutter/서버 테스트·빌드·실기기는 미실행이다.

## 18. 후속 10단계 정적 소스 보강

GameState v13/기존 자산과 지갑은 유지한다. development_rules.dart의 숙련 분리 schema1 직렬화는 결과 원장과 수치/수집을 대조하며 실제 SQLite/해금 저장에는 미연결이다. development_evidence.dart는 계정별 불변 증거 대기와 견적 영수증 필드 비교만 수행한다. 서버 검증·추첨·잔액 변경은 없다. 광고 잔여 계산은 서버 예약/검증대기를 포함한 표시용 스냅샷 계산이며 시작 승인을 대신하지 않는다. game_app.dart는 초기 비활성·detached에서 오디오를 정지하고 init 완료 후 mounted를 확인한다. 실행 검수는 미실행이다. [상세 계약](../16_10단계정적개발과서버계약.md).

## 19. 구매 저널·내부 서버 검증 기반

GameState v13과 실제 지갑은 유지한다. development_purchase_journal.dart는 분리 schema1의 구매 의도/예약/차감/서버 결과/지급/복원을 기록한다. development_journal_repository.dart는 CAS·한 단계 전이 검사와 명시적 SQLite development_purchase_journal_v1 테이블을 제공한다. 앱 시작 시 열지 않으며 저널만 저장했다고 실제 재화가 차감된 것이 아니다. 같은 Transaction 안의 스냅샷/상품 변경 연결과 기기/백업 권위 검수가 남는다. development_evidence.dart에 불변 심사 결과/어댑터 인터페이스를 추가했다. firebase/functions/src/development_contracts.ts는 내부 서버 견적 재계산·광고 원자 예약/증거 재사용 차단·심사 결과 저장을 제공하며 index.ts/지갑/grant에는 미연결이다. [17번 상세](../17_구매저널저장과서버검증기반.md). 모든 새 테스트는 작성만 했고 실행 검수 미실행이다.

## 20. 신규 Workshop 진입·두 재화·확정 정책

현재 main.dart는 공통 임시 설정을 읽고 WorkshopController/SqliteWorkshopRepository를 초기화해 GameApp.workshop→WorkshopPage로 연결한다. GameApp의 기존 controller는 설정·로그인·서버 황금/IAP 포트이며 구형 buns/coin/레벨은 신규 진행의 권위가 아니다. 신규 화면은 코인/환생 UI를 노출하지 않는다. goldName 표기는 황금붕어빵력이다.

신규 진행 DB는 todays_bungeoppang_workshop.db, snapshots current/backup, aggregate schema1이다. GameState v13은 설정/계정 포트에 그대로 남는다. 단계·결과/숙련 확정·6구·준비품 귀속·재고/판매/대금/누적/심사 대기·승급을 집계 원자 저장하며 CAS 실패/저장 오류는 복원 후 재읽기까지 차단한다. 자동 backup 복원은 서버 보호 대조 전 제공하지 않는다. 연속 입력/탭 체크포인트는 설정 checkpoint_ms이며 무손실 보장은 아니다.

초기 팥 미디엄만, 슈크림/초코는 지정 미션 조건으로 각각 획득 가능하고 상점은 준비 중이다. 맛별 숙련5종/횟수/손기술 AND, 당시 revision/요구량의 숙련 확정 기록을 보존한다. 보유 AND 숙련한 맛만6구 후보, 직접 수확·탄 칸 폐기. 앱 이탈·가려진6구 정지, 고객 전경 시간 계속, KST 실제 영업일/준비품1회 귀속·5영업일 소멸이다.

손님 판매는 재고·붕어빵력/누적을 함께 저장하고, 주문을 다 채운 판매에서만 판매ID·황금 대기를 함께 저장한다(부분 판매는 24장). 별점은 품질·신선도이며 일반 대금에 다시 곱하지 않는다. 미션·판매·광고 황금은 서버 검증 전 로컬 잔액을 올리지 않는다. 수동 승급은 현재 레벨 추가 탭/판매 기준선을 갱신하고50 이후 분점은 후속이다. 같은 손님의 명시 맛/익힘만 영구 관찰하며 실패·취소로 삭제하지 않는다.

실제 새 스킬/꾸미기 복합 결제·검증 황금·SDK/SSV·신규 친구/랭킹 연결은 미완료이고 현재 신규 자동 생산율은0이다. 비영 생산율8시간/50% 계산 소스는 별도로 있다. AdMob 공식 문서 접근은 HTTP403으로 차단돼 검증 구현을 추정하지 않았다. SDK/추적 의존성과 현 개인정보 문구는 변경하지 않았다. 앱 실행·컴파일/테스트/빌드/실기기 미실행이다. [18번 상세](../18_신규게임연결과사용자결정반영.md).


## 21. 신규 구매·판매·복귀 후속 소스

[19번 후속 기록](../19_구매원자저장과복구후속.md)이20장과18번 기록보다 최신이다. Workshop schema2/SQLite2이며 구매 원장을 재화와 한 번 저장하고 purchase_guard와 대조한다. schema1은 구매 없는 이전으로만 읽는다. 실제 기기/SQL 검수와 서버 보호 증거를 대신하지 않는다.

WorkshopPurchases의 영수증으로 확정된 보유 수만 공통 effect에 연결하며 기본 탭1·자동0이다. 서버 composite_purchases.ts는 기존 gold 지갑 홀드/확정/취소와 활성 진행 epoch를 함께 처리하는 내부 모듈이다. production gateway/신뢰된 차감 verifier/공개 함수는 미연결이며 미정산을 같은 거래로 복구한다. 로컬 황금 지급·구형 결제 우회는 없다.

복귀·복구 재읽기는 부재8시간/50% 정산 후 전경으로 전환한다. 광고 gameplay pause와 경제 정산은 구분한다. 주문 제작 UI는 연습량/손기술을 늘리지 않고 결과 익힘 발견·재고를 함께 저장하며, 연습은 보관/버리기 선택이다. 판매 저장은 원본 생산량/소비 누적과 대조한다.

희귀 판매 서버 코어는 검증된 증거·고정 추첨/일일 상한/지갑·원장 원자 반영만 준비했다. 판매 일일 귀속은 사용자 확정에 따라 최초 서버 심사 확정 KST 날짜이며 초과분 이월은 없다. 광고 시작일 귀속과 구분한다. AdMob/실제 서버 검증/출시 꾸미기 적용·실행 검수는 남는다. 추가 테스트27개는 작성만 했고 앱/테스트/빌드/서비스를 실행하지 않았다.


## 22. 인증·보상 수신·광고·아바타 연결

[20번 검수 인계](../20_온라인광고꾸미기연결과검수인계.md)가 현재 소스 기준이다. Workshop schema3/SQLite3이며 rewardAccount/rewardReceipts/adAttempts/avatarEquipment/missions/sceneTime을 추가하고 구매 guard에 보상 계정/수신/광고를 함께 보호한다. schema1/2에 신규 보호 필드가 섞이거나 schema3 필드가 누락되면 거부한다.

FirebaseOnlineBackend가 WorkshopTransport를 제공해 main의 WorkshopOnline과 callable 소스로 연결한다. 서버 서비스는 기본 비활성이다. 신뢰된 서버 검증 증거와 클라이언트 제출을 분리하고 account/progress/epoch/지문을 대조한다. 이전 시 미정산 구매 잠금을 같은 tx에서 재확인한다. 실제 보호 증거 생성 파이프라인/배포·앱 검수는 미완료다.

판매/승급 보상은 원본 claim을 유지하고 서버 최종 수신을 별도 저장한다. 서버가 이미 지급한 원장은 verifier 장애에도 재조회하며 로컬 황금을 생성하지 않는다. 실제 잔액은 인증 서버 지갑에서 조회하고 구형 아이템 지급을 새 진행에 적용하지 않는다. 신규 미션은 사용자 선택2번에 따라 기존 구매/자동 생산 포함 구성을 유지한다. mission_targets/mission_gold_rewards를 쓰며 KST 자정/월요일·전경 생산·스킬 확정 적용만 집계한다. 신청 당시 수치/진행 근거와 계정별 목표 의미 키를 보존해 기기 이전으로 재지급하지 않는다. 전경 경제는 단조 경과시간을 사용한다.

광고는 승인 ID 선저장·customData 토큰·provider 거래 잠금·서버 earned 지급을 연결했다. 앱 시청 완료는 지급 근거가 아니다. 게임 pause와 finally 복원, 동일 ID 복구를 제공하며 SDK는 미설치/시청 UI 비활성이다. 실제 서명 verifier/SDK 데이터·동의/테스트 광고는 별도다.

기존 사장님 아바타51개(무료13/유료38)의 label/slot/무료 여부/임시 해금 수치를 development_balance.json에 넣었다. 유료 가격은 같은 설정의 두 재화 표만 사용한다. 신규 화면은 아바타 렌더·무료/보유 착용·복합 구매를 제공하며 배경/붕어빵 꾸미기는 출시 아바타 범위로 확장하지 않는다. 기본 배경은 기존 무료 시간(기본/낮/밤/기기 시간) 선택을 따로 저장하고 clear/clear_night를 재사용한다. BGM 수동 선택은 그대로 독립이다. 상단은 상점+메뉴로 정리하고 배경/소리 설정은 작은 화면 스크롤을 제공한다. 서버 생성 JSON은 공통 설정 도구로 갱신/검사한다.

TypeScript --noEmit과 구문/링크/생성 검사는 정적 확인이며 실제 앱·테스트·빌드·서버/SSV·실기기 통과가 아니다.

## 손님·관계 기획 반영 — 2026-10-16

현재 `workshop_controller.dart`는 `customer_N` 임시8종과 주문·취향 관찰을 저장하고 `ui/workshop_page.dart`에 대기열/전량 판매/도감을 표시한다. `npc_yunha` 등8명 캐릭터·친밀도·대사/스토리/선택/후일담 저장·정적표정 자산은 아직 없다. 이번 작업은 코드·설정·스키마 변경 없이 [21번 기획](../21_손님캐릭터와관계시스템.md)과 관련 기존 문서만 갱신했다.

신규 목표와 현재 코드의 차이는 [03번](../03_현재상태_차이분석.md)에 기록했다. 영업일/앱 이탈은 기존 사용자 결정을 유지하고 수락 시점/교환 유예는 결정 대기다. 이 문서의 기존 구현 설명을 신규 콘텐츠 구현 완료로 읽지 않는다.

## 손님 코드 후속 — 2026-10-16

현재 Workshop schema4/SQLite4는 관계 원장과 customerScene을 추가한다. customer_content.json→생성 Dart의 NPC8/대사144·관계/선택8개를 읽고 controller와 page에서 방문/무기명/친밀도/장면/도감을 연결한다. 실제 실행·타입 검사·SQLite 업그레이드는 미검증이다. 기존 schema3 구매/보상/미션 guard를 보존하고 관계/장면을 함께 보호한다. 최신 범위와 남은 작업은 [22번](../22_손님콘텐츠구현과현재환경후속.md)이다.


## 직원2 제작·6구 후속 — 2026-10-18

`cooking_sensor_input.dart`는 기존 `CookingSession` 명령을 생성하며 세션/단계마다 중립 복귀 후 새 센서 입력을 요구한다. 일시정지·입력 방식 전환은 미완료 붓기를 취소한다. 터치 반죽은 최초 포인터만 소유하며 영역 이탈·해당 포인터 취소·차단 시 확정하지 않는다. 일반 터치 버튼도 gameplayPaused 동안 차단한다.

`harvestCell(index, expectedCycle: …)`는 화면에 표시된 회차를 검증한다. `GriddleProgress.applyHarvest`는 고정 결과를 해당 칸에만 적용한다. controller의 `pendingCookingResolution`/`pendingHarvestResolutions`는 저장 실패 뒤 같은 프로세스의 reloadAfterError에서 익힘·제작일을 재판정하지 않도록 보관하는 읽기 인터페이스다. 실패 시도 중 프로세스 종료까지의 영속 보장은 아직 저장 담당의 저널 연결이 필요하다. 저장 스키마·주문/재고 원장은 변경하지 않았다.

기존 확정인 덜 익음6구 수확 가능·탄 칸 직접 폐기·보유AND숙련 후보·앱 이탈/큰 틀 진입 중6구 정지를 유지한다. 시간·횟수·판정 경계는 기존 공통 임시 설정 그대로다. 실행 근거와 통합 주의사항은 저장소 루트 `coordination/step-02.md`에 기록한다. Android 센서/실제 터치·실제 SQLite/프로세스 강제 종료는 검수 완료가 아니다.

직원2 추가 후속: 숟가락 스와이프/젓가락 회전은 독립 규칙·위젯으로 구현하고 공통 설정의 manual_cooking에 거리32px/시간800ms/우세2000permille/회전360도/중심 반경20px를 추가했다. 결과·보관·6구 수확은 선택적 `WorkshopProductionJournal` 포트를 사용한다. SQLite additive `production_journal`은 후보 전체 집계와 정확한 기준 원문/순번을 보관하고 최종 저장과 저널 제거를 원자 처리한다. 검증된 일치 기준에서만 재시작 시 후보를 재적용하며 schema4/user_version4를 유지한다. 위 메모리 한계 설명은 이 SQLite 구현 사용 시 해소되며 포트 미구현 저장소에는 해당하지 않는다. 자동 체크포인트 중 제작 입력을 유지하고 대기 전 수신 시각을 고정한다. 최신 검증 완료 여부는 `coordination/step-02.md` 후속 절을 따른다.
### 직원 1 저장·영업 수명 후속 (2026-10-18)

`workshop_storage.dart`는 `workshop_controller.dart`의 part로 저장 인터페이스와 SQLite 구현을 분리한다. Workshop JSON schema4와 SQLite user_version4는 유지한다. 다음 성공 저장부터 기존 테이블에 `snapshots.recovery`와 `purchase_guard.id=2`를 추가한다. current/recovery/전체 집계 증거(id2)/기존 구매 보호(id1)/직전 backup을 하나의 SQL 트랜잭션에서 기록한다. 전체 집계 증거는 해시가 아닌 직렬화 원문이며 저장 공간을 추가로 사용한다.

현재 저장이 손상·누락되면 전체 집계 증거와 원문·순번이 일치하고 기존 구매 보호 및 모델 검증을 통과하는 최신 recovery만 current로 복원한다. 과거 backup은 자동 복원하지 않는다. 증거 불일치·증거 소실·구형 저장 손상은 초기화하지 않고 오류로 중단한다. 로컬 복구는 서버의 활성 진행·계정·epoch·거래 검증을 대체하지 않으며 전체 DB 삭제·변조나 파일 손상 복구를 보장하지 않는다. 기존 정상 schema1~3 이전 경로는 유지하고 구형 클리커 재화 환산은 추가하지 않는다(기존 사용자 없음 확정).

복구 재읽기 동안 명령·틱을 잠그고 lifecycle 요청은 해당 작업을 기다린다. 미래 영업일에 귀속된 재고/준비품 binding은 저장 검증에서 거부한다. 영업 시작·종료, KST 명시 이어가기, 준비품 최초 귀속과 열린 영업 부재 정산 8시간/50% 규칙은 기존 구현을 유지한다. 실행 근거·통합 순서는 저장소 루트 `coordination/step-01.md`를 따른다. Android 실기기 검수는 별도다.


### 직원2 기존 홈·중앙 큰 틀 연결 정정 (2026-10-18)

신규 제작은 기존 NightHome의 배경·중앙 큰 틀·아래6구·사장님·상단 HUD 메뉴/설정과 하단 메뉴를 재사용한다. NightHomeHeaderData로 Workshop 경제/레벨/생산량을 표시하고 GameController는 설정/계정 포트로 유지한다. WorkshopMoldStage는 배경의 큰 틀 좌표에 기존 세션/입력을 연결하며 붕어빵을 중복 렌더하지 않는다. 주문/재고/미션은 메뉴 창, 주문 제작 시작 후 중앙 홈 복귀다. 설정의 소리/진동/모션 줄이기와 배경 시간을 연결하며 신규 DB 초기화를 구형 계정 초기화에 연결하지 않는다.

센서는 중력3축 전달 후 Dart에서 X축과 Y/Z 합성으로 좌우 기울기를 계산한다. 평평한 자세의 X/Y 각도 불안정성을 보완하며 중립 복귀/단계 토큰 보호와15도 활성·5도 중립 수치는 유지한다. 보정/붓기 상태와 다시 보정을 표시한다. 사용자가 실제 기울임 실패를 확인했으므로 샘플 수신만으로 실기기 완료라 하지 않는다. 검증 근거와 남은 항목은 coordination/step-02.md를 따른다.


### 직원2 사용자 조작 정정: 짤주머니·빈 큰 틀 (2026-10-18, 위 도구/방향 기록보다 우선)

> **2026-11-16 사용자 결정으로 대체됨.** 길게 누르기 짤주머니·센서·'뒤집기' 버튼 규칙은 [27장](#27-제작-조작화면용어-변경-결정--2026-11-16)(DEC-031~039)의 색칠 드래그·원 그려 뒤집기·센서 삭제로 바뀝니다. **짤주머니 색칠과 센서 삭제는 24번 5단계, 원 그려 뒤집기는 6단계에서 구현했습니다**(10장 "짤주머니 색칠"·"원 그려 뒤집기"). 아래 길게 누르기·`fillingDurationMs`·`filling_capacity_ms` 설명은 옛 기록이며, `fillingDurationMs`는 옛 저장을 읽을 때만 씁니다. 빈 틀 위에 단계별 상태를 그리는 마지막 문단은 유지합니다.

사용자는 좌우 속 넣기와 숟가락/젓가락을 요청하지 않았다고 정정하고, 큰 틀을 길게 눌러 양을 조절하는 짤주머니 액션을 지정했다. 신규 화면에서 방향 버튼/원 그리기/쓸기/도구 선택을 제거하고 관련 제스처 모듈·테스트·임시 설정5개를 삭제한다. 센서는 두 반죽에만 적용한다. 짤주머니는 최초 포인터의 누른 시간을 속 양으로 기록하며 취소/영역 이탈/일시정지 시 확정하지 않는다. filling_capacity_ms=4000은 양 표시100% 기준의 공통 임시 수치이며 손기술 성공 범위나 판매 가격 규칙이 아니다.

CookingSession의 선택적 fillingDurationMs는 기존 schema1/Workshop schema4를 유지하는 추가 필드다. 미완료/음수/다른 단계의 위조 기록을 거부하고 재시작·결과까지 유지한다. squeezeFilling은 저장 호환 토큰/시퀀스를 내부에서 원자 소비하며 신규 사용자에게 방향 과제를 노출하지 않는다. 기존 방향 필드는 옛 저장 호환용으로 남는다. 신규 짤주머니 완료에 과거 방향 실수 페널티를 적용하지 않는다. 속 양의 별도 합격/손님 가격 산식은 임의로 추가하지 않는다.

제작 중 정적 배경 속 완성 붕어빵을 불투명 빈 철판/빈 공동으로 덮고 첫 반죽·속·둘째 반죽·닫힌 틀·결과를 별도 상태로 그린다. 완성 붕어빵은 결과에서만 표시한다. 현재 단계 경과 시간은 큰 틀 위에 표시한다. 배경 전체/기존 상단 메뉴·설정/하단 메뉴는 유지한다. 현재 기기 연결과 실기기 완료 여부는 coordination/step-02.md 최신 절을 따른다.


### 직원2 기존 메뉴 복원 후속 (2026-10-18)

Workshop의 기존 홈 하단 상점/스킬/꾸미기와 메뉴 목적지를 개별 창으로 복원했다. workshop_windows.dart는 기존 나무 프레임·제목·닫기/돌아가기·잔액 창을 재사용하고 Workshop 견적/구매/미션/도감/통계를 표시한다. MenuPanel/WardrobePanel/ShopPanel에는 선택적 표현/액션 포트만 추가해 기본 구형 경로를 보존한다. 스킬 종류/수량 선택과 꾸미기 탭/미리보기/3열 격자/적용, 상점 분류/충전을 복원한다. 신규 진행의 권위는 Workshop이고 두 재화 정책을 유지한다. 가격 계약 없는 미보유 비아바타 상품은 준비 중이며 기존 보유 외형만 계정 저장 포트에 적용한다.

친구/랭킹/공유는 기존 계정 UI/서비스를 다시 연다. 구형 실적을 신규 실적으로 제출하거나 연결되지 않은 방문 부스트를 신규 생산에 적용했다고 표시하지 않는다. 서버 실사용은 별도다. 주문/재고/영업은 추가 관리 항목으로 남기고 기존 메뉴 전체를 관리 목록으로 대체하지 않는다. 여러 창 전환 중6구 비표시 정지는 창 개수로 관리한다. 검증/통합 기록은 coordination/step-02.md를 따른다.

## 직원3 손님·관계·주문·재고 후속 — 2026-10-18

별도 브랜치 `codex/employee3-domain`의 P3-004, P4-006~007, P5-004~005 구현·검증과 제작/저장 연결 계약은 [3단계 인계](../../../coordination/step-03.md)를 따른다. 위2026-10-16의 실행 미검증 기록과 구분한다. 자동 원장/체크리스트/진행현황은 이번 작업에서 수정하지 않았다.

- `selectCustomerInventory`는 오래된 묶음 우선·같은 날짜 ID 순으로 남은 요구량을 배정하고(`partial: true`면 모자라도 있는 만큼), `sellToCustomer(orderId, selectedByLine: ...)`가 현재 주문·수량·신선도를 재검증한다. 부분 판매·완료 규칙은 24장. 판매 버튼은 표시한 주문 ID를 캡처해 종료된 주문의 입력이 다음 손님으로 넘어가지 않는다.
- `preferredCustomerFlavor`는 태오의 실제 보유 미경험 신메뉴를 주문에 반영한다. 기본 관계 완료가 이후 신메뉴 사건을 영구 차단하지 않으며 C 선택 후일담은 실제 촬영 맥락과 함께 생성한다. 기본 관계→선택 후일담→새 선택의 우선순위를 입장/판매 후에 함께 적용한다.
- 접수·교환·소개와 관계 수치/상한·영업일·저장 schema4는 유지한다. 날씨/동행·표정/복장 아트 범위를 새로 확정하지 않는다. 로컬 판매 근거는 서버 황금 지급 권한이 아니다.
- 호스트 테스트는 전체53개 파일을 분할 대조하고 기존 실패8건을 최신 테스트로 재실행해 고유537개 통과를 확인했다. 릴리즈 manifest가 필요한1개는 미실행이다. 단일 전체 명령 종료0이나 실기기/실제 SQLite 이전 검수 완료를 뜻하지 않는다. 최신 도메인 분석은 error0·warning0, 전체 분석은 error0·기존 warning8이며 수치/콘텐츠 생성물 검사도 통과했다. Android 빌드의 최종 결과 및 남은 외부 검수는 인계 파일에 별도 기록한다.
- Android offline debug 빌드는 종료0으로 성공했다(17m17s). APK 113194638 bytes와 manifest/dex/arm64 Flutter 라이브러리를 확인했다. 실기기 실행·릴리즈 검증은 별도 미실행이며 정확한 명령·해시·통합 순서는 인계 파일에 기록했다.

### 2026-10-18 직원4 서버 검증 후속

`staff-04/server-verification`의 서버 변경은 [coordination/step-04.md](../../../coordination/step-04.md)에 인계한다. 구매 재시도는 기존 원장을 우선 복구하며, callable 취소에는 신뢰된 cancellation 증거(account/progress/epoch/transaction/fingerprint, debitFenced/localDebitRestored)가 필요하다. 클라이언트 차감 플래그나 증거 부재만으로 환불하지 않는다. 보호 파이프라인의 실제 권위·복원 검증은 운영 전 필수다.

`admob_ssv.ts`와 `workshopAdSsv`는 원본 쿼리 ECDSA 검증과 고정 HTTPS 공개키/23시간 캐시를 사용한다. `WORKSHOP_ONLINE_ENABLED` 기본 OFF를 유지하며, 광고는 별도로 `WORKSHOP_AD_SSV_ENABLED`와 `WORKSHOP_ADMOB_AD_UNITS` allowlist가 필요하다. 광고 시작도 이 설정 없이 승인하지 않는다. SDK 완료 콜백은 지급 증거가 아니다. 실제 서명 요청·SDK/동의·보호 검증 파이프라인·에뮬레이터·실기기 검수 완료를 의미하지 않는다. 검증 명령/결과와 운영 설정은 위 인계 파일을 기준으로 확인한다.

### 2026-10-18 직원4 추가 검증

서버 보호 증거 수신은 `protected_purchase_pipeline.ts`의 서버 Ed25519 서명+계정/진행 epoch+순번/이전 digest CAS로 보완했다. 미검증 로컬 저장을 자동 승인하거나 기기에 서명키를 주지 않는다. 실제 게임 이벤트를 검증해 서명하는 발급 서버는 별도 연결이 필요하며 운영은 OFF다. 서버 홀드 전 실패는 검증된 취소 서명/잠금 확인 후 차감 없는 취소 원장으로 정산한다.

Functions 발견 단계에서 Play SDK와 Firestore client를 만들지 않도록 `play_purchases.ts`/`firestore_store.ts`로 초기화를 지연했다. Node22 빌드·테스트 및 실제 Firestore/Auth/Functions 에뮬레이터 결과와 실패 이력, 기본10초 발견 제한과 로컬120초 대기의 구분은 [4단계 인계](../../../coordination/step-04.md)에 기록한다. 이 기록은 실제 서비스 서명·광고 SDK·동의·계정 설정·실기기·배포 완료가 아니다.

재현 스크립트는 Windows Java의 한글 규칙 경로 문제를 ASCII 임시 규칙 사본으로 해결하고 종료 시 개별 임시 파일을 정리한다. 원본 규칙은 그대로 적용한다. 단일 스크립트로 Node22 빌드·단위73개·Auth/Firestore/Functions 통합7개 통과를 확인했다. DEBUG 환경 로그 억제 후속과 실제 Firebase 로그인 미확인 상태 등 정확한 검증 범위는 같은 인계를 따른다.

## 직원5 오디오 수명 보완 — 2026-10-18

GameApp은 앱 전경과 WorkshopController.adPaused를 함께 확인하여 광고 중 BGM/굽기/SFX를 차단한다. 스토리 중에는 굽기 소스만 비우고 독립 BGM 설정을 유지한다. 복귀는 현재 소스를 먼저 반영한다. AudioplayersAudio는 전경 이탈 시 진행 중 효과음과 늦게 시작된 효과음도 중단한다. 기본값/저장 형식은 변경하지 않았다. 검증 근거는 coordination/step-05.md에 기록한다.

## 23. 서버 타당성 검증과 환영 황금 — 2026-11-03

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 2단계. 사용자 결정: 검증 방식은 **서버 타당성 검증**, 초반 황금은 **서버 환영 황금**. 19~22장의 "신뢰된 검증 증거 발급자 미연결" 상태를 해소한다.

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 진행 스냅샷 | 앱이 구매·보상 호출마다 `snapshot = {buns, lifetimeBuns, level, taps, sales}`를 함께 보냄 | `lib/workshop_online.dart` `WorkshopProgressSource`, `WorkshopController.progressSnapshot` |
| 서버 체크포인트 | `users/{uid}/workshopPlausibility/{progress}`에 직전 확인 값과 서버 시각 저장. 증거 기록과 같은 트랜잭션 | `functions/src/plausibility_validator.ts` |
| 상한 공식 | 누적 붕어빵력 증가 ≤ 탭 증가×서버 기준 탭 생산 + 경과초×서버 기준 자동 생산 + 판매 증가×최대 판매가 + 승급 보상 + 여유분. 탭 증가 ≤ 경과초×15+여유. 판매 증가 ≤ 경과시간/손님 간격+여유. 감소·레벨 조건 미달은 확정 거절 | 같은 파일 `advance` |
| 첫 확인 | 체크포인트가 없으면 누적 100만·탭 10만·판매 2000 이하만 허용 | `server_validation.first_checkpoint_*` |
| 구매 | 예약: 붕어빵력 ≥ 가격. 확정: 예약 이후 붕어빵력 증가가 누적 증가를 넘지 않아야 함(차감 반영 확인). 거절된 예약은 `취소 확인`으로 무과금 취소 기록(tombstone)을 남겨 정리. 예약된 구매 취소는 황금 반환·스킬 미지급 | `PlausibilityValidator.purchase/cancellation` |
| 미션 | 설정 revision·목표·보상량 일치, 기간은 서버 KST 기준 최근 3일(`mission_claim_grace_days`) 안, 진행량 ≤ 스냅샷 누적/서버 보유 스킬 수/자동 생산. 실패는 `unverifiable`(지급 0) 확정 | `missionGold/missionPlausible` |
| 판매 | 증거 형식(주문 id·별점 1~5·제품) 확인, 검증한 판매 수 ≤ 스냅샷 판매 수. 이후 기존 서버 추첨·일일 상한 | `PlausibilityValidator.sale`, `sale_rewards.ts` |
| 환영 황금 | 첫 `workshopProgressClaim`에서 계정당 1회 `welcome_reward.gold`(10) 지급. 26번 3단계부터 1~4단계 스킬이 황금 0이라 꾸미기용(앱이 '꾸미기에서 써 보세요' 안내) | `WorkshopService.welcome` |
| 켜는 조건 | 운영 함수는 `WORKSHOP_ONLINE_ENABLED=true`와 `WORKSHOP_SALE_DRAW_KEY_BASE64`가 있어야 검증기·환영 황금이 켜짐. 배포·운영값은 7단계 | `functions/src/index.ts` |
| 앱 표시 | Firebase 설정 없는 빌드: 스킬 상점에 "온라인 연결(카카오 로그인)이 있는 빌드에서만" 안내. 미션 보상 신청 시 로그인 상태면 바로 서버 확인 | `lib/ui/workshop_windows.dart`, `lib/ui/workshop_page.dart` |

설정 원본은 `config/development_balance.json`의 `server_validation`·`welcome_reward`이며 `tools/development_balance.py`로 서버 사본·14번 문서를 다시 만든다. 테스트: `functions/test/plausibility_validator.test.ts`(11개), 에뮬레이터 `test/emulator/workshop.integration.ts` 마지막 항목, Dart `test/workshop_online_test.dart`·`test/workshop_progression_simulation_test.dart`.

## 24. 판매 루프 홈 화면과 부분 판매 — 2026-11-09

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 3단계. 사용자 선택: 홈 배치 **B안(왼쪽 세로 손님 줄 + 굽는 판 위 판매 카운터)**. 화면 배치는 10장 "Workshop 홈".

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 부분 판매 | 판매 버튼은 맨 앞 손님 주문의 남은 요구량을 오래된 재고부터 있는 만큼 고름. 다 못 채우면 그 제품의 일반 대금만 바로 받고 주문에 `deliveries`로 기록(판매 당시 영업일·익힘·나이·대금 고정). 판매 횟수·판매 ID·황금 심사 대기·친밀도는 만들지 않음 | `development_orders.dart` `CustomerDelivery`, `CustomerSalesProgress.deliver`, `WorkshopController.sellToCustomer` |
| 주문 완료 | 남은 요구가 0이 되는 판매에서 판매 1회(DEC-017/023/007). 별점은 앞서 드린 제품과 이번 제품을 판매 당시 값으로 개수 가중(DEC-018/022). 증거 `ordinaryBuns`는 전체 합, 이번에 받는 대금은 이번 제품분만 | `prepareCustomerSale` |
| 대금 반올림 | 제품 1개 단위로 반올림하므로 나눠 팔아도 합계가 같음 | `development_sale_quality.dart` |
| 판매 증거 | 주문(`order`)에는 납품 기록을 넣지 않음. 다른 영업일에 먼저 드린 제품은 `soldOnBusinessIndex`를 붙이고 `age`는 그날 기준. 서버는 제품 목록을 검사하지 않아 변경 없음 | `validateStoredCustomerSale` |
| 미완료 종료 | 영업 종료·시간 초과로 손님이 떠나면 받은 대금은 남고 횟수·황금 기회는 없음 | `closeBusiness`, `_advanceMemory` |
| 저장 | JSON schema 5. 읽을 때 납품 기록의 생산 근거·소비량·대금(누적 이하)을 판매 원장과 함께 대조 | `WorkshopState.fromJson` |
| 같은 묶음 | 이미 드린 묶음은 같은 주문 줄에 다시 고르지 않음(증거 지문 중복 방지) | `selectCustomerInventory`, `_handOver` |

테스트: `test/partial_sale_test.dart`(규칙 4·컨트롤러 5), `test/workshop_counter_test.dart`(위젯 3·골든 3). 새 화면 문구에는 Jua에 없는 `·`·`…`를 쓰지 않았고(쉼표·괄호·흐림 처리), 기존 문구의 글자 깨짐은 5단계에서 다룹니다. 네임드 손님 그림은 assets에 없어 이름 첫 글자 배지로 대신합니다.

## 25. 첫 실행 안내·복귀 안내·저장 손상 대처 — 2026-11-11

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 4단계. 화면은 10장 "첫 실행 안내"·"복귀 카드", 저장은 3장 schema 6·"저장 손상 대처"·"Workshop 복귀 안내".

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 첫 실행 안내 | 7단계, 실제 홈 위 고리+카드, 건너뛰기 저장 | `workshop_tutorial.dart`, `ui/workshop_guide.dart`, `WorkshopController.skipTutorial`·`storeResult`·`sellToCustomer` |
| 첫 손님 | 안내 중에는 선택 장면을 굴리지 않고(`rollChoice(tutorial:)`), 첫 판매 뒤 이야기 장면도 붙이지 않음 | `WorkshopController.welcomeCustomer`·`sellToCustomer` |
| 복귀 안내 | 2시간 이상 부재 뒤 돌아오면 카드 한 장(사용자 결정 2026-11-11). 자리 비운 동안 판매는 없다는 현재 규칙 유지(자동 판매 도입 안 함) | `feedback_config.dart` `workshopWelcomeBackAfter`, `WorkshopAwayReport` |
| 저장 손상 | 복구 시도 → 실패 후 '처음부터 시작'(두 번 확인, 손상 파일은 이름 바꿔 보관) + 오류 내용 복사 | `main.dart` `_start`, `ui/save_recovery.dart`, `save_quarantine.dart`, `SqliteGameRepository`/`SqliteWorkshopRepository`의 `defaultPath`·`close` |
| 구형 안내 | 구형 `GameHome`의 안내는 클리커용 대화상자 한 장(“붕어빵을 눌러 굽고…”)이라 재사용하지 않음. 5단계 구형 UI 정리 대상 | `ui/game_app.dart` `_GameHomeState` |

테스트: `test/workshop_guide_test.dart` 12개(새 설치→안내 완료 360x640·390x844, 건너뛰기·재시작, 안내 중 네임드 손님 장면 없음, schema 이전, 복귀 보고·카드·홈 표시, 손상 파일 보관, 복구 화면 두 번 확인·복사·설정 오류·재시도 실패).

## 26. 화면 마감 — 2026-11-16

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 5단계. 화면은 10장 "메뉴 창 목록"·"Workshop 창"·"상점·꾸미기", 글꼴은 11장 "기호 대체 글꼴".

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 범위 밖 메뉴 | 온라인 랭킹·친구·공유를 Workshop 메뉴에서 뺌(공유는 문구가 구형이고 스토어 주소가 없어 8단계 뒤 다시 판단) | `MenuPanel.hidden`, `WorkshopPage._menu` |
| 팔지 않는 꾸미기 | '판매 준비 중'·'준비 중' 대신 목록에서 뺌. 빈 상점 탭 숨김 | `CosmeticMenuAccess.listed`, `ShopPanel._tabs` |
| 충전 탭 | 구형 부스트 줄과 "이미 쓴 부스트" 안내 뺌, '로그인하면 충전할 수 있어요', '불러오는 중'/'구매할 수 없음' | `GoldChargeTab.legacyBoost` |
| 온라인 연결 실패 문구 | '온라인 기능을 준비 중이에요' → '지금은 온라인에 연결할 수 없어요'(랭킹: '지금은 온라인 랭킹에 연결할 수 없어요') | `online_controller.dart`, `premium_controller.dart`, `ui/friends_panel.dart`, `ui/ranking_panel.dart` |
| Lv.50 | 코드에 분점 '준비 중' 문구 없음. 레벨 미션 창은 '최고 레벨에 도달했어요.' 그대로 | `WorkshopPage._levelMissions` |
| 기호 글자 깨짐 | 문구 교체 대신 대체 글꼴(146곳의 `·` 등 9종 → 이제 0) | 11장 |
| 창과 하단 메뉴 겹침 | 창을 전체 높이로 하고 바닥 받침이 하단 메뉴를 덮음(사용자 선택) | `showWorkshopWindow` |
| 구형 UI | 남김(사용자 결정). 15장 "도달하지 않는 구형 UI" | |

테스트: 신규 `font_coverage_test.dart` 1개, `workshop_home_golden_test.dart` 5개(골든 10장). `step02_menu_test`는 숨긴 메뉴·빈 테마 탭·창 받침 위치를 확인하도록 고침. `premium_flow_test`·`stage9_ranking_test`는 바뀐 연결 실패 문구로 고침.


## 27. 제작 조작·화면·용어 변경 결정 — 2026-11-16

[24번 작업](../24_제작조작화면용어변경프롬프트.md) 1단계 기록. 결정 원문은 [00_결정취합.md](../2.1.1_game_rules_and_decisions/00_결정취합.md) 「2026-11-16 제작 조작·화면·용어 변경」(DEC-031~039). 2단계(용어), 3단계(두 틀 규칙), 4단계(홈 배치·빈 굽는 판), 5단계(짤주머니 색칠·센서 삭제), 6단계(원 그려 뒤집기)를 구현했고, 7단계(통합 검수)에서 전체 흐름을 호스트 테스트로 확인했습니다. 실기기 검수는 대기입니다. 각 항목은 표의 단계에서 구현하며, 구현할 때 10장·설정값·저장 절을 함께 고칩니다. 수치는 모두 `manual_cooking` 개발용 임시값입니다.

| 항목 | 결정 | 구현 단계 |
| --- | --- | --- |
| 용어 | 큰 틀 제작 → 스페셜 붕어빵 제작, 6구 제작 → 숙련된 붕어빵 제작. 코드 이름·Key는 그대로 (DEC-039). **2단계 구현 완료**: 화면·안내·튜토리얼·오류 글 적용, 숙련된 붕어빵 틀 빈 칸 글자 제거(강조 면·테두리만) | 2 |
| 영업 준비 중 | 스페셜 붕어빵 틀로 연습 제작만. '+붕어빵력' 버튼 없음. 숙련된 붕어빵 틀은 빈 틀(칸 글자·터치 없음) (DEC-035·036). **3단계 구현 완료**(10장 "두 틀 규칙") | 3 |
| 영업 중 | 틀 없이 큰 붕어빵 = 클리커(`c.tap`·탭 효과, 1초 15번 초과분은 효과만, `server_validation.max_taps_per_second`). 손님 창 '주문 제작' 동안만 틀이 나오고 클리커 탭은 막힘. 연습 제작은 명령에서도 거부. `orderFlash` 없앰 (DEC-035·036). **3단계 구현 완료**: `WorkshopController.clickerTap`, `WorkshopClicker` | 3 |
| 제작 중 영업 시작 | 거부. `openBusiness`에서도 막고 '스페셜 붕어빵을 다 만든 뒤 영업을 시작해요' (DEC-035). **3단계 구현 완료** | 3 |
| 튜토리얼 | 흐름 유지. 7단계 손님 기다리기에 '손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요'. `cook` 단계에서 이미 영업 중이면 주문 제작 안내. schema 6 유지 (DEC-037). **3단계 구현 완료** | 3 |
| 홈 배치 | 숙련된 붕어빵 틀(6구) 폭 = 화면 폭 − 16, 비율 유지. 판매 카운터 윗변 = 배경 왼쪽 빨간 체크 행주 윗변 (DEC-038). **4단계 구현 완료**(10장 "행주 윗변", 층 5): 영업 준비 중 '스페셜 붕어빵 제작 시작' 버튼을 카운터 윗변 − 4로 올림(사용자 선택 A). 빈 굽는 판 임시 그림 | 4 |
| 짤주머니 색칠 | 첫 반죽·속·둘째 반죽 모두 드래그 색칠. 한 단계 = 한 번의 이어진 붓질(손 떼면 확정), 포인터 하나, 틀 밖 무시. 붓 굵기 = `fishRect` 폭의 14% (DEC-031). **5단계 구현 완료**(10장 "짤주머니 색칠") | 5 |
| 덧칠 | 격자 칸을 떠났다 다시 들어올 때마다 한 겹. 덮은 면적과 덧칠 포함 양을 따로 계산 (DEC-032). **5단계 구현 완료**: 16px 칸 1,081개, 떠남 = 반지름 + 1칸 | 5 |
| 품질 판정 | 반죽 두 번 각각 덮은 면적 ≥ 90% 그리고 덧칠 포함 양 ≤ 130%(초과는 넘침·실패) + 익힘이 `success_doneness_min_index`~`max_index` 안. 속은 판정 없이 양·넘침만 표시 (DEC-031). **5단계 구현 완료** | 5 |
| 기울기 센서 | 삭제: 스위치·센서 코드·테스트·`tilt_*` 설정 3개 (DEC-033). **5단계 삭제 완료**(Android 채널 포함) | 5 |
| 원 그려 뒤집기 | 누적 320도, 양방향, 거꾸로 돌면 감소, 틀 중심에서 틀 폭 15% 안쪽 무시, 손 떼면 0도·원위치. 연출은 `flip_ms` 1000과 맞춤. 1060행의 예전 회전 360도/중심 20px 설정을 대신함 (DEC-034). **6단계 구현 완료**(10장 "원 그려 뒤집기"): `flip_turn_degrees` 320·`flip_dead_zone_permille` 150, 다 그린 뒤 연출 `flip_ms` 뒤 명령 | 6 |

**용어 대응표 (2단계, 2026-11-16):**

| 플레이어 용어 | 코드 이름 |
| --- | --- |
| 스페셜 붕어빵(틀·제작) | 큰 틀: `state.session`(`CookingSession`), `WorkshopMoldStage`, `Key('workshop-mold')`, `startPractice`·`startOrderProduction` |
| 숙련된 붕어빵(틀·제작) | 6구: `state.grid`(`GriddleProgress`), `WorkshopGriddleLayer`, `Key('workshop-cell-N')`, `startCell`·`harvestCell` |

개발용 메모·설정 note는 '숙련된 붕어빵(6구)'처럼 옛 이름을 괄호로 함께 적는다. 날짜가 붙은 옛 기록 절(962~1092행 부근)은 당시 용어 그대로 둔다.

**3단계 기록 (두 틀 규칙, 2026-11-16):** 화면·명령 규칙은 10장 "두 틀 규칙", 안내는 10장 "첫 실행 안내" 표. 테스트 `test/workshop_two_molds_test.dart`(컨트롤러 5·화면 3: 영업 준비/영업 중 평소/주문 제작 세 상태의 두 틀 표시·입력, 연습 거부·주문 허용, 제작 중 영업 시작 거부, 클리커 상한, 주문 제작 중 탭 거부, 결과를 닫으면 클리커 복귀, `cook` 단계 영업 중 안내). 남은 점이던 "굽는 판 그림에 붕어빵 6개가 그려져 있음"은 4단계에서 임시 빈 굽는 판 그림으로 해결.

**4단계 기록 (홈 배치·빈 굽는 판, 2026-11-16):** 배치는 10장 Workshop 홈 표·"행주 윗변"·층 5. 겹침 점검(사용자 결정): 카운터가 시작 버튼을 16~19px 가려 버튼을 올림(A). 남는 작은 겹침은 받아들임: 360 폭에서 카운터 아래끝이 굽는 판 왼쪽 경첩 끝을 6.8px 가림(칸과는 5px 떨어짐). 조리 컷과 굽는 판 그림은 겹치지 않음(그림 투명도로 잰 최소 간격 360x640·360x800 20.5px, 390x844 22.7px, 412x915 24.0px). 굽는 판 아래가 하단 메뉴 뒤로 10px 들어가는 것은 예전 그대로. 당시 빈 굽는 판 그림은 임시 그림(`tools/empty_griddle.py`)이었고, 2026-11-17 생성 그림으로 바꿨습니다(아래 "25번 그림 적용"). 필요한 그림과 생성 프롬프트는 [필요한 그림 목록](../25_필요한그림프롬프트.md)에 있고, 앞으로 새로 필요한 그림도 그 파일에 추가합니다.

**5단계 기록 (짤주머니 색칠, 2026-11-17):** 규칙·설정값은 10장 "짤주머니 색칠"·"제작 설정값", 저장은 3장 Workshop 표의 `session` 행. 설계 갈림길 G1~G8은 사용자가 모두 추천안으로 확정(00_결정취합 DEC-040). 새 파일: `lib/cooking_paint.dart`(순수 계산), `lib/generated/fish_cavity_mask.dart`·`tools/fish_cavity_mask.py`(마스크 생성). 지운 파일: `lib/cooking_sensor_input.dart`, `lib/cooking_tilt_source.dart`, Android `CookingTiltStream.kt`. 테스트: `test/cooking_paint_test.dart`(마스크·면적·덧칠·떨림·빈틈·넘침·판정·저장 이전 17개), `test/cooking_controls_test.dart`(색칠 위젯 11개: 손 떼면 확정, 속 넘침, 칠 0, 틀 밖, 단계 변경, 앱 비활성, 차단, 포인터 취소, 두 번째 손가락, 화면 읽기, 진동), `test/step02_home_test.dart`(실제 홈에서 세 단계 문지르기 → 결과 글). 시뮬레이션: 가로 지그재그 줄 간격(붓 지름 대비) 100%·90%·80%에서 덮음 100%, 양 약 101%·108%·125%. 새로 필요한 그림(짤주머니, 속 칠 질감, 반죽 넘침)은 [필요한 그림 목록](../25_필요한그림프롬프트.md) 2~4번이고 지금은 코드로 그린 임시 그림입니다.

**6단계 기록 (원 그려 뒤집기, 2026-11-17):** 규칙·설정값은 10장 "원 그려 뒤집기"·"제작 설정값". 새 파일: `lib/cooking_flip.dart`(순수 각도 누적), `lib/ui/flip_circle_control.dart`(조작·연출·임시 고리). 결정 해석(추천안으로 진행): "틀 폭" = 틀 그림 캔버스 폭(1200px, 붕어빵 홈 폭 769px가 아님), 320도에 닿는 순간 손을 떼기 전에도 바로 뒤집음, 화면 읽기는 두 번 활성화로 뒤집기, 손 뗀 뒤 원위치는 연출 없이 즉시. 함께 고친 것: 5단계 짤주머니 안내 글이 '제작 취소' 버튼의 누르는 영역(48)과 4.6(412x915)~19.3px(360 폭) 겹치고, 360 폭에서는 안내 글 상자 아래 5px가 '제작 취소' 글자 위에 덮여 있던 문제(그 부분을 누르면 칠 대신 취소 버튼이 눌림) → 두 조작의 안내 글을 버튼 윗변 − 4까지 올림(`captionLift`). 테스트: `test/cooking_flip_test.dart`(설정값·한 바퀴·반시계·반 바퀴 부족·중심 맴돌기·중심 가로지르기·방향 바꾸기·짧은 쪽·취소·다 그린 뒤 고정·잘못된 설정 11개), `test/flip_circle_control_test.dart`(탭으로 안 뒤집힘, 원 → `flip_ms` 뒤 한 번, 반시계, 손 떼면 0도, 중심 맴돌기, 두 번째 손가락, 취소·단계 변경·앱 비활성, 연출 중 차단, 명령 거부, 화면 읽기, 모션 줄이기, 진동 12개), `test/step02_home_test.dart`(실제 홈에서 탭으로 안 뒤집히고 원을 그리면 cooking), `test/workshop_home_layout_test.dart`(4개 해상도 안내 글·제작 취소 간격). 새로 필요한 그림(안내 고리·화살표)은 [25번 필요한 그림](../25_필요한그림프롬프트.md) 5번.

**7단계 기록 (통합 검수, 2026-11-17):** 새 `test/workshop_full_flow_test.dart`가 새 설치 → 안내 → 영업 준비 중 스페셜 붕어빵 연습(실제 화면 색칠 세 번·원 그려 뒤집기) → 보관 → 영업 시작 → 숙련된 붕어빵 칸 굽기·수확 → 판매(안내 끝) → 클리커 탭 → 손님 창 '주문 제작'(틀 나옴·클리커 막힘·칸 멈춤 → '결과 닫기' 뒤 클리커 복귀) → 판매를 한 흐름으로 확인합니다. 숙련에 필요한 나머지 연습 7회만 명령으로 채우고, 시간은 가짜 단조 시계로 넘깁니다. 기기용 `integration_test/step02_android_test.dart`는 없어진 '뒤집기' 버튼 대신 원을 그리도록 고쳤습니다(기기 실행은 아직). **상태 구분:** 1~7단계 규칙은 Windows 호스트 테스트(분석·전체 테스트·골든·서버 테스트)로 실행 검수 완료, **실기기 검수는 대기**입니다. debug APK는 25번 그림 18장(1·2·4·5번)을 넣은 뒤 2026-11-17에 만들었고(`B:\1_app_development\build\app\outputs\flutter-apk\app-debug.apk`), 같은 날 3번 속 칠 질감을 넣고 다시 빌드), 실기기 확인표(색칠 반응, 손가락 가림, 작은 화면 원 그리기, 칸 누르기, 매대·행주, 새 그림 등)는 [24번 문서 7단계](../24_제작조작화면용어변경프롬프트.md) 아래에 있습니다. 확인표에서 '진행 불가'로 보고된 문제만 7단계 할 일 4로 고칩니다.

**25번 그림 적용 (2026-11-17):** [25번 필요한 그림](../25_필요한그림프롬프트.md) 1·2·4·5번(18장)을 게임에 넣었습니다. 생성 원본 `4_image_generation_results_and_backups/25_generated/`는 읽기만 하고 `1_app_development`에서 `python tools/apply_25_art.py <원본 폴더> --preview`가 줄여 넣습니다(투명도 곱한 Lanczos 축소, 투명도 정리로 할로 없음). 빈 굽는 판 4종은 칸이 붕어빵 모양 홈으로 바뀌어, 굽는 칸은 원래 화로의 붕어빵만 남긴 층(`assets/images/stove_fish`)을 겹치도록 `GriddlePainter`를 고쳤고 칸 좌표(`griddleCavities`·`griddleFishClips`)는 오차가 작아 그대로입니다(10장 Workshop 홈 표). 짤주머니·흘러내림·뒤집기 고리는 코드 임시 그리기를 그림으로 바꿨고(그림이 없으면 예전 그리기), 뒤집기 고리 생성본의 반대 방향 화살촉은 도구에서 보정했습니다. 3번 속 칠 질감은 처음엔 `ImageShader` 경로만 준비했고(`PixelSprites.fillingTexture`, 파일이 없으면 맛 색), 같은 날 다시 생성한 v2(`25_generated/mold_textures_v2`, 1254×1254)를 `apply_25_art.py --only textures`로 256×256으로 줄이고(상자 평균, 맛마다 28~40색) 네 변 이음매를 보정해(반 장 밀어 돌린 질감과 최소 오차 경계로 갈아탐) 넣었습니다. 타일 배율 `fillingTextureScale` = 2(질감 1px = 틀 그림 2px, 배율 1·2·3을 세 맛 화면으로 비교). 이때 짤주머니 화면 폭을 min(조작 상자 폭×0.2, 64) → ×0.3으로 바꿔 390×844에서 52 → 64px(25번 2번의 의도 크기)로 키웠습니다. `workshop_home_filling_390x844` 골든 다시 만듦. 예전 임시 빈 판 도구 `empty_griddle.py`는 이제 `build/stove_empty_temp`에만 씁니다. 골든 2장 추가(`workshop_home_filling_390x844`, `workshop_home_griddle_390x844`). 저장 형식 변경 없음.

## 28. 흥행 개선 결정 — 2026-11-17

[26번 흥행 개선 작업](../26_흥행개선단계별프롬프트.md)의 결정 기록. 결정 원문은 [00_결정취합.md](../2.1.1_game_rules_and_decisions/00_결정취합.md) 「2026-11-17 흥행 개선」. 각 단계가 구현할 때 이 장과 해당 장을 함께 고칩니다. DEC-041(스킬 황금)은 26번 3단계에서 구현했습니다(4장·8장·23장).

| 항목 | 결정 | DEC | 구현 단계 |
| --- | --- | --- | --- |
| 스킬 황금 조건 | 황금 재화·손님 희귀 황금·미션 황금·IAP 유지. 탭·자동 스킬 1~4단계는 붕어빵력만(몇 번을 사도 황금 0, 10번마다 +1 증가도 없음). 5~16단계는 지금 황금 가격 유지 | DEC-041 | 26번 3단계 **구현 완료**(2026-11-18). 5단계 개방은 시뮬레이션상 Lv.15~21(처음 적은 'Lv.23~25' 정정) |
| 출시 목표일 | 날짜 없음, 완성도 우선. 26번 단계를 순서대로 끝내고 6단계(비공개 테스트 업로드)를 맨 끝에. 4-1~4-6·7·8도 업로드 전 | DEC-042 | 진행 순서(코드 없음) |
| 처음 5분 기능 해금 | 하나씩 열기: 안내 중 굽기·영업·손님·판매·큰 붕어빵 / 안내 끝 꾸미기·상점 / Lv.2 스킬 창·초당 숫자 / 첫 숙련 6구 / Lv.3 도감 / Lv.4 레시피 / Lv.5 특별 주문·붕어빵 꾸미기 / 재고 하루 경과 시 신선도 안내 / Lv.8 가게 꾸미기. 핵심 진행은 레벨로 잠그지 않음. 새 설정 키 `feature_unlock_levels.skill_shop`(2), 공통 잠금 표시·소개 카드 | DEC-043 | 26번 2단계 |
| 초반 손님 간격 | 예외 없음. 튜토리얼 뒤 레벨과 관계없이 일반 1~15분·네임드 30분~3시간 | DEC-044 | 26번 5-1단계 |
| 측정 방식 | `firebase_analytics` 도입(1장 원칙·`no_tracking_sdk_test`를 이 패키지만 허용으로), 광고 ID·SSAID·개인화 광고 신호 끔. 이벤트 10개 이하. 자체 서버 집계·`metrics_report.py`는 만들지 않음 | DEC-045 | 26번 5단계 |
| 측정 대상·기본값·보관 | 로그인과 상관없이 모두, 기본 켬, 첫 실행 안내 없음, 설정 '사용 통계 보내기'로 끔(`setAnalyticsCollectionEnabled(false)`). 보관 14개월(Analytics 무료판 최대) | DEC-046 | 26번 5단계 |
| 매일 돌아올 이유 | 오늘의 특별 주문(주문서 카드) + 손님 이야기 하루 한 조각 + 겨울 계절 행사(장식·인사·주문 문구) + 출석 보상(7일째 황금 1, 서버 검증) | DEC-047 | 26번 7단계 |
| 공유 카드 | 넣음, 보상 없음. 완벽 결과·이야기·도감 완성·가게 사진 네 곳, 1080×1350 | DEC-048 | 26번 8단계 |
| 보상형 광고 | 출시 후 첫 업데이트. 별도 브랜치 `s26/9-ads`에만, 출시 빌드에 광고 SDK 없음(DEC-028 유지). 충전 탭 + 황금 부족 안내, 광고 ID 안 씀, 만 13세 이상 | DEC-049 | 26번 9단계 |
| 출시 범위 | Lv.50 전체 유지(DEC-029). 26번 6단계 할 일 1 건너뜀 | DEC-050 | — |
| 손님 방문 간격·알림 | 실제 시간: 일반 1~15분·네임드 30분~3시간, 자리 일반 3·네임드 1, 기다림은 켠 순간부터, 자정 자동 영업일 넘김, 네임드 하루 1회 제한·무기명 30% 폐지(직전 손님 제외), 튜토리얼 뒤 '맞이' 버튼 없음, 기기 안 알림(일반 끔·네임드 켬·밤 22~8시 끔 기본), 희귀 황금 3배. **구현 완료** (30장) | DEC-051~060 | 26번 5-1단계 |
| 스킬 황금 0 산식·검증 | 기본 황금 0이면 몇 번째든 0(10번마다 증가 없음). 황금 0은 스킬만 허용, 꾸미기·부스트는 1 이상. 앱·서버 같은 식, **서버 먼저 배포 후 앱** | DEC-061 | 26번 3단계 (4장) |
| 기존 구매자 | 황금으로 1~4단계를 산 사용자는 환불 없이 그대로 | DEC-062 | 26번 3단계 |
| 환영 황금 용도 | 10개 그대로, 꾸미기에 쓰도록 안내('꾸미기에서 써 보세요'), 충전 탭 '쓰는 곳' 한 줄, Workshop 상점은 꾸미기 탭으로 열림 | DEC-063 | 26번 3단계 (8장) |
| 스킬 레벨업 로그인 | 지금처럼 로그인 필요(DEC-021). 스킬 창에 '카카오 로그인 후 레벨업할 수 있어요' + 로그인 버튼, 로그인 전 구매는 거래를 만들지 않음 | DEC-064 | 26번 3단계 (4장) |
| 성장 속도 | 그대로. 황금 0 서버로 Lv.10 9분, 5단계 개방 Lv.15~21. 5-1(손님 간격) 뒤 다시 확인 | DEC-065 | 26번 3단계·5-1 |
| 아바타 그림 매칭 | 머리 = 입은 모습 레이어 + `_cut`, 피부톤 = 도구 색 치환 복사본(`@skin2·3`), 정면만. 기본 앞치마를 그림으로 입히고 무료 '앞치마 없음'(`noapron`) 추가. 그림이 준비 안 된 유료 아바타는 꾸미기·상점에서 숨김(보유자에겐 보임). **구현함**(7장, 2026-11-18) | DEC-066~068 | 26번 4-4단계 |

2026-11-18 26번 1단계 기록(문서만, 코드·설정 변경 없음). 추천안으로 확정한 세부(묻지 않은 것)와 1단계 밖 단계의 답은 00_결정취합.md 「26번 2차 구현 전 확정」 소절에 있고, 각 단계가 구현할 때 이 표에 줄을 더한다.

## 29. 온라인 운영 설정 — 2026-11-17

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 7단계. 코드·설정·스크립트는 준비했고, 계정이 필요한 콘솔 작업(Firebase 프로젝트·Blaze·배포·카카오 앱·Play 상품·권한·테스트 구매)은 사용자가 [online_setup.md](online_setup.md)대로 한다. 상세는 9장 "App Check"·"서버 운영 설정"·"서버가 Google에 요청할 때 쓰는 계정", 13장 "온라인 빌드".

| 항목 | 내용 |
| --- | --- |
| App Check | 서버 모든 callable 강제(`callable_options.ts`), 앱 `firebase_app_check` 0.4.9(Play Integrity / debug 토큰). 함께 `firebase_core` 4.15.0 → 4.15.2 |
| 키 주입 | `dart_defines/online.json` + `--dart-define-from-file`. 견본 `online.example.json`(빈 값)만 커밋 |
| 서버 설정 | `functions/.env`(커밋 금지), 견본 `.env.example`, 생성 스크립트 `firebase/make_server_env.ps1`. `WORKSHOP_ONLINE_ENABLED` 운영값 `true` |
| 상품 ID | `gold_60/330/700/2200/3800`, 앱·서버 일치(8장, `premium_catalog_test`). Play Console 등록은 사용자 |
| 지문 | 업로드 키 SHA-1 `17:17:AB:A9:DB:2D:31:40:06:0F:2D:4F:DE:48:89:16:3F:25:4C:42`(카카오 키 해시 `FxerqdstMUAGDy1P3kiJFj8lTEI=`), 이 PC debug 키 SHA-1 `04:1A:06:46:C2:D5:37:58:6C:A1:C5:6E:EA:97:21:33:62:08:82:DB`(`BBoGRsLVN1hsocVu6pchM2IIgts=`). Play 앱 서명 키는 첫 업로드 뒤 |
| 도구 | `firebase/firebase_local.cmd`(로컬 Firebase CLI), `tools/kakao_key_hash.ps1`(SHA-1 → 카카오 키 해시) |
| 미완료 | 운영 Firebase에서 테스트 구매 1건 서버 확인·지급·복구(online_setup.md 11장 표) — 사용자 콘솔 작업 뒤 확인 |

## 30. 손님 방문 간격·알림 — 2026-11-18

[26번 5-1단계](../26_흥행개선단계별프롬프트.md#5-1단계--손님-방문-간격과-알림). 결정은 00_결정취합.md `DEC-051`~`10`(병합 때 번호). 설정값은 `config/development_balance.json` `customer_arrivals`·`customer_notifications`(하드코딩 없음, 14번 문서에 자동 반영).

| 규칙 | 내용 | 코드 |
| --- | --- | --- |
| 손님 시계 | 일반(무기명)·네임드 두 개가 따로 돎. 간격 = `min + hash(seed, draws) % (max − min + 1)`(고정 32비트 해시)이라 미리 정해짐 → 알림 예약 시각 = 실제 도착 시각. 일반 `regular_min_ms` 60000~`regular_max_ms` 900000, 네임드 `named_min_ms` 1800000~`named_max_ms` 10800000 | `lib/workshop_arrivals.dart` `ArrivalClock`·`WorkshopArrivals` |
| 자리 | 일반 `regular_slots` 3, 네임드 `named_slots` 1. 켜 있을 때도 같은 자리. 자리가 차면 그 시계가 멈추고(`nextAt` null), 판매·시간 초과로 자리가 나면 그 순간부터 다음 간격. 예전 레벨별 `max_queue` 열은 없앰 | `WorkshopArrivals.resume`·`arrived` |
| 시간 기준 | 영업 정산 시각(`business.settledUtc`, 뒤로 안 감)까지의 사건을 시각 순서로 처리. 기기 시계를 되돌려도 지난 도착이 다시 생기지 않고, 앞당겨도 자리 수에서 막힘. 앱이 꺼져 있어도 흐름(복귀·재실행 때 한꺼번에) | `WorkshopController._syncArrivals` |
| 기다림 | 꺼진 동안 온 손님도 `order_wait_ms`를 다 가진 채 생기고, 기다림은 앱이 앞에 있을 때만 줄어듦(켠 순간부터) | `_advanceMemory` |
| 자정 | 열린 가게는 KST 자정에 저절로 다음 영업일(`BusinessProgress.nextDay`) + 재고 나이·준비품 수락·미션 '영업한 날'. 같은 처리 순서 안에서 자정 뒤 손님은 새 영업일로 관계·소개를 셈. 여러 날 비워도 한 번만(S5-1-Q3) | `_startBusinessDay(next: true)` |
| 멈춤 | 이야기 장면·광고 중에는 도착·자정 처리를 미루고 끝난 뒤 처리. 손님 도착으로 후일담 장면이 열리면 그 뒤 사건은 장면 뒤로 | `_syncArrivals` |
| 네임드 고르기 | 처음은 도윤 → 못 만난 손님이 있고 그 영업일 소개 2명(`new_npcs_daily_limit`) 미만이면 목록 순서로 소개 → 아니면 만난 손님 중 직전 네임드(`lastNamedVisitor`)·줄에 선 사람을 뺀 무작위(시계 해시). 한 명뿐이면 그 사람. 하루 1회 제한(`visits_per_npc_business_day`)·무기명 30%(`anonymous_visit_basis_points`)는 설정에서 없앰. 일반 시계는 늘 무기명, 네임드 시계는 늘 네임드(못 고르면 그 회차 건너뜀). `holiday_visit_basis_points`(은채 쉬는 날)는 그대로 | `WorkshopRelationships.selectNamedVisitor` |
| 첫 실행 안내 | 안내 중(`cook`/`sell`)엔 시계 없음. 줄이 비었으면 도윤이 바로(처음), 그 뒤엔 `customer_arrival_interval_ms`(15초) 뒤 한 명(무기명). 안내 '맞이' 버튼도 이때만. 첫 판매로 `done`이 되거나 건너뛰면 같은 명령에서 두 시계 시작. `customer_arrival_interval_ms`는 안내용 + 서버 판매 한도 계산용으로 키 유지 | `WorkshopController._tick`, `welcomeCustomer` |
| 짧은 이름 | `customer_content.json` `short_name`: 도윤·윤하 씨·막례 할머니·오 작가님(이야기 뒤 서진 씨)·태오 씨·은채 씨·민재 씨·수아 씨. 조사 이/가는 받침으로(`withSubjectParticle`) | `WorkshopCustomerCatalog.shortName` |
| 알림 예약 | 앱이 `paused`/`hidden`이 될 때만(inactive 아님) 저장 뒤 `upcomingArrivals(preview_horizon_ms 24시간)`으로 올 손님(일반 ≤3·네임드 ≤1)을 계산 → 끈 종류 빼기, 일반은 `regular_max_notices` 3번까지, 밤 끄기 켜면 기기 시각 `quiet_start_minute` 1320(22:00)~`quiet_end_minute` 480(08:00) 알림만 건너뜀(손님은 옴) → 모두 취소 후 예약. `resumed`에서 모두 취소. 영업 닫힘·안내 중·이야기 장면 중이면 예약 없음 | `ui/game_app.dart` `_scheduleNotices`, `planCustomerNotices` |
| 알림 문구 | 제목 '오늘의 붕어빵'. 일반 '손님이 붕어빵을 사러 왔어요! 가게로 가 볼까요?', 네임드 '{짧은 이름}{이/가} 찾아왔어요. 따끈한 붕어빵을 기다려요.' 누르면 앱이 홈으로 열리고 손님이 기다림. 채널 '손님 알림'. 아이콘 `res/drawable/ic_stat_customer.xml`(임시 흰 붕어빵, 25번 21번) | `lib/customer_notifier.dart` |
| 알림 드라이버 | `CustomerNotifier`(schedule·cancelAll·requestPermission). 앱은 `LocalCustomerNotifier`(Android만, `inexactAllowWhileIdle`, UTC `TZDateTime`), 테스트는 가짜. 예약 실패는 게임을 막지 않음. `build.gradle.kts` core library desugaring, 매니페스트에 예약·부팅 수신기 | `main.dart`, `android/app` |
| 설정 화면 | 설정 창 '모션 줄이기' 아래 '일반 손님 알림'(기본 끔), '단골 손님 알림'(기본 켬), '밤 알림 끄기 (밤 10시~아침 8시)'(기본 켬). 켤 때 권한을 묻고, 거절되면 그대로 꺼진 채 '휴대폰 설정에서 이 앱의 알림을 허용해야 받을 수 있어요.' 저장은 `GameSettings` `notifyRegularGuests`·`notifyNamedGuests`·`quietNightNotices`·`notificationPromptDone`(없으면 기본값, 계정 저장 v13 그대로) | `ui/workshop_page.dart` `_audioSettings`·`_setNotice` |
| 권한 묻기 | 안내가 끝나고(또는 건너뛰고) 첫 판매가 끝난 뒤 한 번 창 '손님 알림 — 손님이 찾아오면 알려 드릴까요? 앱을 꺼 둬도 단골손님이 오면 알림으로 알려 드려요.' [나중에][알림 받기]. 어느 쪽이든 다시 묻지 않음. '알림 받기' → Android 13+ 권한 창, 허용이면 기본값 그대로. 거절이나 '나중에'면 두 알림 끔(거절이면 위 안내 문구) | `_askNotifications` (`notice-prompt`) |
| 희귀 황금 | 별 1~5 확률 300·600·900·1200·1500(3·6·9·12·15%), 하루 최대 10 그대로. 서버 생성본 갱신(revision 그대로) — **서버를 다시 배포하기 전까지 서버는 옛 확률(1~5%)로 추첨** | `rare_gold_sale`, `firebase/functions/src/generated/development_balance.json` |

테스트: `test/workshop_arrivals_test.dart`(시계 범위·결정성, 1분·15분·3시간, 자리 상한·재시작, 시계 되돌림·1년 앞당김, 영업 닫힘, 자정 넘김·새 영업일 손님·미션, 기다림은 켠 순간부터, 미리보기 = 실제 도착, 이야기 장면 보류, 안내 → 시계 시작, schema 6→7·잘못된 7 거절, 밤 판정, 알림 계획, 설정 저장, 수명주기 예약·취소, 권한 묻기 2가지), `test/workshop_customers_test.dart`(소개 하루 2명·하루 1회 없음·직전 제외·1명뿐·짧은 이름·조사), `test/no_tracking_sdk_test.dart`(권한 3개·정확한 알람 없음·메시징 없음), `test/workshop_progression_simulation_test.dart`(8분마다 판매: Lv.5 32분·Lv.10 72분), 서버 `test/sale_rewards.test.ts`(생성본 확률 = 앱). 에뮬레이터 알림 수신 확인은 26번 5-1단계 결과 표. 확인용 debug 빌드: `flutter build apk --debug --dart-define=CUSTOMER_NOTICE_SELFTEST=true`(13장대로 `GRADLE_USER_HOME`·`PUB_CACHE` 영문 경로) — 앱을 내리면 진짜 예약에 더해 1분 뒤 '[시험] …' 알림 하나를 예약(`main.dart` `_SelfTestNotifier`, release에서는 꺼짐). AVD `TodayBungeoppang_API35`가 없으면 `avdmanager create avd -n TodayBungeoppang_API35 -k "system-images;android-35;default;x86_64"`로 만든다.
