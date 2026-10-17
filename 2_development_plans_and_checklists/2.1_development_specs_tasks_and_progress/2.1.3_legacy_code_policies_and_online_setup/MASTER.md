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
| 광고·추적 SDK 금지 | ads, admob, analytics, crashlytics, sentry 등 금지. Firebase는 core/auth/functions만 허용. 카카오는 로그인용만 | `test/no_tracking_sdk_test.dart` |
| 현실 보상 없음 | 현금·상품·포인트를 지급하지 않음. 공유에도 보상 없음 | README |
| 경제는 BigInt | 가격·생산·보상은 BigInt로 계산하고, 배율은 정수 천분율(‰)로 계산(`effectScale` = 1000). double 금지. 저장할 때는 10진 문자열 | `economy.dart`, `config_values.dart` |
| 코인은 원장으로만 | 모든 코인 변동은 `support.transact(id, …)`/`grantReward`로. id가 중복 지급을 막는 키(`daily:<day>:<id>`, `weekly:<week>:<id>`, `achievement:<id>`, `level:<n>`) | `support_rules.dart` |
| 저장은 원자적으로 | 중요한 명령은 `before = state.copy()` → 변경 → `_commit`. 저장 실패 시 되돌림. 프레임·탭마다 저장 금지 | `game_controller.dart` |
| 시간은 게임 시계로 | `DateTime.now()` 대신 `gameNow`/`observedUtc` 사용. 기기 시계를 되돌려도 지난 날짜·주는 다시 열리지 않음 | `support_state.dart` |
| 키 커밋 금지 | 카카오·Firebase 키를 저장소에 넣지 않음 | `test/stage16_kakao_ranking_test.dart` |
| 테스트 기준 유지 | 테스트 목표나 골든 허용치를 낮추지 않음 | README |
| 개발자 전용 기능 | 초대 시뮬레이터 등은 `developerTools`(= `!kReleaseMode`)일 때만 | `game_controller.dart` |

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
5. `controller.initialize()` → `runApp(GameApp)`. 저장 데이터가 손상되면 `RecoveryApp`.

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
| 돌아오기 환영 창 | 24시간 이상 떠나 있었고 획득량이 있을 때 | `offlineWelcomeAfter` |

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
| 해금 | 누적 생산 ≥ `unlockTotal`, 또는 황금 붕어빵으로 조기 해금 |
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
| outfit | **apron 기본 앞치마 0/1**, darkapron 초코 앞치마 5/2, padding 패딩 조끼 6/3, creamapron 크림 앞치마 7/4, stripe 줄무늬 앞치마 9/5, waistapron 허리 앞치마 9/5, chefcoat 요리사 복 12/7 |
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
| 2 | base | 포즈 그림(몸·얼굴·기본 머리·기본 옷) |
| 3 | eyes | 눈 프레임 |
| 4 | mouth | 입 프레임 |
| 5~11 | bottom, shoes, top, outfit, hat, accessory, tool | 칸별 아이템(`rigSlotLayers`). tool만 탭할 때 올라감 |
| 12 | front | 아이템 앞 조각 `<slot>_<id>_front.png` |

- 아이템 그림의 기준점은 캔버스 원점입니다. 잘라낸 그림은 `avatarTrimOffsets`의 (left, top)에 놓입니다. 그림 크기가 280×520이면 오프셋을 무시합니다.
- 그림별 위치 보정·크기·회전·같은 층 안의 순서는 `rigPlacements`(경로 → `RigPlacement`)에 둡니다. 지금은 비어 있습니다.
- 앞/뒤 조각은 파일만 넣으면 됩니다. `PixelSprites.load`가 에셋 목록에 있는 것만 읽습니다.
- character·skin·hair는 레이어가 아니라 base 그림 자체를 바꿉니다(머리 그림은 아직 base에 합쳐져 있음).

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
- 부분 그림은 그려진 눈·입을 주변 피부색으로 덮고 새 모양을 그립니다(`tools/avatar_layers.py face`). 피부색은 skin1 그림에서 가져옵니다. skin2·skin3 그림이 생기면 피부톤별 부분 그림도 만들어야 합니다.

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

**디버그:** 개발 빌드(`developerTools`)의 설정 맨 아래 '레이어 기준점 보기'를 켭니다(`AvatarRigDebug.show`). 노란 선은 리그 영역, 하늘색 선은 레이어 경계, 분홍 표시는 기준점입니다. 확인용 이미지는 `flutter test tools/preview_avatar_layers_test.dart`로 만들고, 결과는 `build/preview/avatar_layers.png`에 저장됩니다.

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
| 스킬 조기 해금 | n단계 × 10 (`goldPerSkillStep`), 2~16단계만 |
| 황금 부스트 | 20 (`boughtBoostGold`) |

- 상점에 보이는 가격은 Play가 지역에 맞게 주는 가격입니다.
- 결제 흐름: `buyGoldPack`(로그인 필요) → Play 결제 → 서버 `walletRedeem`이 Play API로 확인하고 소모 처리 → 지급. 앱에서는 자동 소모하지 않습니다(`autoConsume: false`).
- 사용할 때는 요청마다 20자 무작위 id를 붙여 `walletSpend`를 부릅니다. 같은 id는 한 번만 처리됩니다.

---

## 9. 온라인: 로그인·랭킹·친구·초대

- 온라인 기능은 **Android 빌드에 키 5개가 모두 들어 있을 때만** 켜집니다. 아니면 오프라인 게임으로 동작합니다.
- 서버 지역은 `asia-northeast3`(서울), 런타임은 Node 22입니다.

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
| 5 | 굽는 판(화로) | 폭 `w×0.94`, 높이 폭×40/88, 바닥 = 내비 높이 − 10 | `griddle` |
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

- 모든 패널은 `GameHome._open(id)`(`lib/ui/game_app.dart`)로 엽니다. 화면 높이 92%의 바텀시트입니다.
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

**공통 위젯**

| 위젯 | 모양 |
| --- | --- |
| CozyPanel | 반경 12, 나무 테두리 |
| CozyRoundButton | 48 원형 |
| CozyFrame | 반경 18/14 |
| CozyCloseButton | 44 정사각형, 벽돌색 |
| CozyBackButton | 높이 48 이상, '돌아가기' |
| CozySettingRow | 설정 한 줄 |
| CozyOnOff | 84×36 켜기/끄기 |

**글자 크기**

| 쓰는 곳 | 크기 |
| --- | --- |
| 시트 제목 | Jua 28 |
| 하단 내비 글자 | Jua 21 |
| 잔액 표시 | Jua 20 |
| 메뉴 줄 제목 | 18 굵게 |
| 보조 글자 | 12 |

간격은 4·6·8·10·12·16을 씁니다. 패널 안쪽 여백은 보통 16입니다.

---

## 12. 이미지·소리

### 이미지 경로 (`lib/ui/pixel_sprites.dart`)

| 종류 | 경로 |
| --- | --- |
| 붕어빵 | `fish/redbean.png`, 무늬는 `fish/redbean@<pattern>.png` |
| 토핑 | `topping/<id>.png` |
| 배경 | `bg/<id>.png`, 밤 `bg/<id>_night.png` |
| 화로 | `stove/<id>.png` |
| 장식 | `deco/<id>.png` (위치는 `night_stall_painter.dart` `decorationAt`) |
| 등불 | `stall/postlamp_<색>.png` (id는 `<색>lamp`) |
| 아바타 | `avatar/<girl·boy>/base.png`, `avatar/<character>/<slot>_<id>.png` (여백을 잘라내고 위치는 `avatarTrimOffsets`), 앞/뒤 조각 `_front`·`_back` |
| 얼굴 부분 | `parts/<character>_<front·side>_<eyes·mouth>_<frame>.png` (위치는 `avatarPartPivots`, `avatarFaceAnchors`) |
| 스킬 | `skills/tap_N.png`, `skills/auto_N.png` |
| 아이콘 | `icons/<name>.png` (이름을 `iconNames`에 등록) |
| 효과 | `fx/minifish, sparkle, fairy_up, fairy_down, butter_glow` |
| 화면 장식 | `ui/wardrobe_bg, offline, title_fish` |
| 이벤트 배너 | `event/spring·summer·autumn·winter` |
| 조리 장면 | `cook/girl_1~6.png` (700ms 간격 반복) |

- 모든 경로는 `assets/images/` 아래이고, **새 폴더는 `pubspec.yaml`의 assets에도 등록**해야 합니다.
- 파일이 없으면 오류 없이 그려지지 않습니다.
- 그림이 없는 아이템은 `blankCosmetics`에, 그림을 기다리는 아이템은 `artPending`에 올립니다(`test/pixel_art_test.dart`가 확인).
- 아바타 그림을 바꾸거나 추가했으면 `python tools/avatar_layers.py`를 실행합니다. 280×520 그림의 여백을 잘라내고, 얼굴 부분 그림과 `lib/avatar_atlas.dart`를 다시 만듭니다. 이미 잘라낸 그림은 기록된 위치를 유지합니다. 측정값은 `tools/avatar_layers.json`에 저장됩니다.

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
| 패키지 이름 | `com.todaybungeoppang.todays_bungeoppang` |
| 앱 버전 | `pubspec.yaml` `version: 0.1.0+1` |

**자주 쓰는 명령**

| 작업 | 명령 |
| --- | --- |
| 패키지 받기 | `flutter pub get` |
| 테스트 | `flutter test` |
| 실행 | `flutter run` |
| 디버그 APK | `flutter build apk --debug` |
| 골든 다시 만들기(의도한 홈 화면 변경 후에만) | `flutter test --update-goldens test/home_golden_test.dart` |
| 서버 가격표 다시 만들기 | `UPDATE_PREMIUM_CATALOG=1 flutter test test/premium_catalog_test.dart` |
| 서버 배포 | `firebase deploy --only functions` (`firebase/` 폴더) |
| 에뮬레이터 | `tools/run_android_emulator.ps1` |

**한글 경로 문제:** 셰이더 도구와 Kotlin 데몬이 한글 경로에서 실패합니다.
1. `subst B: "<프로젝트 경로>"`로 영문 드라이브를 만들고 `B:`에서 실행합니다.
2. 릴리스 빌드는 추가로 `GRADLE_USER_HOME=C:\GradleCache`, `PUB_CACHE=C:\PubCacheBungeoppang`을 지정합니다.

**온라인 빌드:**
```
flutter run --dart-define=KAKAO_NATIVE_APP_KEY=... --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```
- 키가 하나라도 없으면 오프라인으로 동작합니다.
- Gradle flavor는 없습니다. Play Games용 playGames/noPlayGames 구분은 16단계에서 없어졌습니다.

**테스트 지도**

| 영역 | 파일 |
| --- | --- |
| 경제 | economy, economy_expansion, economy_persistence, economy_simulation, skill_shop |
| 저장·이전 | serialization, stage7_regression, stage8_progress, stage10_feedback, stage12_customization |
| 미션·보조 | level_missions(_widget), mission_alerts, support_system, support_widget |
| 진행·환생 | stage8_progress, stage11_endgame |
| 꾸미기·그림 | public_menus(_widget), stage12_customization, pixel_art, stage14_systems, day_night, stage17_avatar_layers |
| 온라인 | online_backend, stage9_ranking, stage16_kakao_ranking, premium_catalog, premium_flow, invite_system, invite_widget |
| 화면 | widget_test(공용 `mountGame`, `FixedTime`), home_golden, stage7_widget, stage8_widget |
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

### 스킬 단계 추가

1. `lateTapSkillConfig`/`lateAutoSkillConfig` **끝에만** 추가합니다.
2. **저장 형식 버전을 올리고, 옛 저장 데이터에 없는 스킬 id를 0으로 채웁니다.** 이렇게 하지 않으면 기존 저장 데이터를 읽지 못합니다.
3. 스킬 그림 `skills/<id>.png`를 넣습니다.
4. 황금 붕어빵 조기 해금 가격이 생기므로 서버 가격표를 다시 만들고 배포합니다.
5. `economy_expansion_test`(단계 수 16), `economy_simulation_test`를 확인합니다.

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
2. [12장](#12-이미지소리) 경로에 그림을 넣습니다. 아바타는 girl과 boy 둘 다 필요합니다. 그림이 없으면 `blankCosmetics`/`artPending`에 올립니다.
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

2026-10-08에 확인한 것입니다. 해결하면 이 목록에서 지워 주세요.

| 문제 | 내용 |
| --- | --- |
| **릴리스 빌드가 debug 키로 서명됨** | `android/app/build.gradle.kts`의 release `signingConfig`가 debug입니다. Play에 올리기 전에 업로드 키를 설정해야 합니다. |
| 서버 App Check 꺼짐 | 모든 서버 함수가 `enforceAppCheck: false`입니다. |
| 노점 부품 그림 없음 | `assets/images/stall/`에 `awning`, `post`, `postlamp`, `counter`(`_snow`) 파일이 없어서 해당 층이 그려지지 않습니다. 현재 있는 것은 `postlamp_lilac/mint/rose`뿐입니다. |
| 온라인은 Android 전용 | iOS에서는 오프라인으로만 동작합니다. |

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

날짜경계·영업종료/다음날복귀·맛별연습량/실패인정·5칸등록/숙련관계·주문표/보상·6구배정/주기/익힘/대기·신선도가격등은 [DEC](../00_공통기준.md#5-결정-관리)에미정으로남겼다. 차기저장버전/세션영속은미정,이전101시간일정은새범위에사용하지않는다. 기존실제일일미션KST자정은새영업일경계의확정근거가아니다.

## 17. 현재 환경 소스 변경 — 오디오 v13·공통 임시 계산

v13은 오디오 설정 musicSelection/cookingSound/cookingVolume만 추가한다. v1~12 자산 파싱은 유지하고 구형 자동 배경 모드를 보존한다. 사업 운영·숙련·재고/복합 거래의 실제 저장 이전은 포함하지 않는다. 변경·다운그레이드/실제 SQLite 검수는 미실행이다.

설정 화면의 배경음 선택은 배경/시간대와 독립이며 ‘배경에 맞춤’으로 기존 모드로 돌아간다. 굽기 루프는 실제 활동 소스가 있을 때만 별도 player로 출력하고 설정/음량·전경에 따라 정지한다. 실제 신규 큰 틀/6구 활동 전달은 미연결이다. 오디오 기본값은 development_balance.json에서 development_audio_defaults.dart로 생성한다. sizzle_loop.wav는 generate_cooking_sound.py로 직접 합성(CC0)했다.

development_balance.dart/asset 로더와 development_rules.dart는 새 복합 견적·익힘·숙련·신선도·KST 날짜·복구 라우팅 계산의 소스를 제공한다. 실제 서버 지갑/광고/신규 게임 흐름 연결은 하지 않았다. [15번 소스 구현·검수 대기](../15_현재환경소스구현과검수대기.md)를 따른다. 테스트 코드는 작성했으나 앱 실행·컴파일/Flutter/서버 테스트·빌드·실기기는 미실행이다.

## 18. 후속 10단계 정적 소스 보강

GameState v13/기존 자산과 지갑은 유지한다. development_rules.dart의 숙련 분리 schema1 직렬화는 결과 원장과 수치/수집을 대조하며 실제 SQLite/해금 저장에는 미연결이다. development_evidence.dart는 계정별 불변 증거 대기와 견적 영수증 필드 비교만 수행한다. 서버 검증·추첨·잔액 변경은 없다. 광고 잔여 계산은 서버 예약/검증대기를 포함한 표시용 스냅샷 계산이며 시작 승인을 대신하지 않는다. game_app.dart는 초기 비활성·detached에서 오디오를 정지하고 init 완료 후 mounted를 확인한다. 실행 검수는 미실행이다. [상세 계약](../16_10단계정적개발과서버계약.md).

## 19. 구매 저널·내부 서버 검증 기반

GameState v13과 실제 지갑은 유지한다. development_purchase_journal.dart는 분리 schema1의 구매 의도/예약/차감/서버 결과/지급/복원을 기록한다. development_journal_repository.dart는 CAS·한 단계 전이 검사와 명시적 SQLite development_purchase_journal_v1 테이블을 제공한다. 앱 시작 시 열지 않으며 저널만 저장했다고 실제 재화가 차감된 것이 아니다. 같은 Transaction 안의 스냅샷/상품 변경 연결과 기기/백업 권위 검수가 남는다. development_evidence.dart에 불변 심사 결과/어댑터 인터페이스를 추가했다. firebase/functions/src/development_contracts.ts는 내부 서버 견적 재계산·광고 원자 예약/증거 재사용 차단·심사 결과 저장을 제공하며 index.ts/지갑/grant에는 미연결이다. [17번 상세](../17_구매저널저장과서버검증기반.md). 모든 새 테스트는 작성만 했고 실행 검수 미실행이다.

## 20. 신규 Workshop 진입·두 재화·확정 정책

현재 main.dart는 공통 임시 설정을 읽고 WorkshopController/SqliteWorkshopRepository를 초기화해 GameApp.workshop→WorkshopPage로 연결한다. GameApp의 기존 controller는 설정·로그인·서버 황금/IAP 포트이며 구형 buns/coin/레벨은 신규 진행의 권위가 아니다. 신규 화면은 코인/환생 UI를 노출하지 않는다. goldName 표기는 황금붕어빵력이다.

신규 진행 DB는 todays_bungeoppang_workshop.db, snapshots current/backup, aggregate schema1이다. GameState v13은 설정/계정 포트에 그대로 남는다. 단계·결과/숙련 확정·6구·준비품 귀속·재고/판매/대금/누적/심사 대기·승급을 집계 원자 저장하며 CAS 실패/저장 오류는 복원 후 재읽기까지 차단한다. 자동 backup 복원은 서버 보호 대조 전 제공하지 않는다. 연속 입력/탭 체크포인트는 설정 checkpoint_ms이며 무손실 보장은 아니다.

초기 팥 미디엄만, 슈크림/초코는 지정 미션 조건으로 각각 획득 가능하고 상점은 준비 중이다. 맛별 숙련5종/횟수/손기술 AND, 당시 revision/요구량의 숙련 확정 기록을 보존한다. 보유 AND 숙련한 맛만6구 후보, 직접 수확·탄 칸 폐기. 앱 이탈·가려진6구 정지, 고객 전경 시간 계속, KST 실제 영업일/준비품1회 귀속·5영업일 소멸이다.

전량 손님 판매는 재고·붕어빵력/누적·판매ID·황금 대기를 함께 저장한다. 별점은 품질·신선도이며 일반 대금에 다시 곱하지 않는다. 미션·판매·광고 황금은 서버 검증 전 로컬 잔액을 올리지 않는다. 수동 승급은 현재 레벨 추가 탭/판매 기준선을 갱신하고50 이후 분점은 후속이다. 같은 손님의 명시 맛/익힘만 영구 관찰하며 실패·취소로 삭제하지 않는다.

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

### 2026-10-18 직원4 서버 검증 후속

`staff-04/server-verification`의 서버 변경은 [coordination/step-04.md](../../../coordination/step-04.md)에 인계한다. 구매 재시도는 기존 원장을 우선 복구하며, callable 취소에는 신뢰된 cancellation 증거(account/progress/epoch/transaction/fingerprint, debitFenced/localDebitRestored)가 필요하다. 클라이언트 차감 플래그나 증거 부재만으로 환불하지 않는다. 보호 파이프라인의 실제 권위·복원 검증은 운영 전 필수다.

`admob_ssv.ts`와 `workshopAdSsv`는 원본 쿼리 ECDSA 검증과 고정 HTTPS 공개키/23시간 캐시를 사용한다. `WORKSHOP_ONLINE_ENABLED` 기본 OFF를 유지하며, 광고는 별도로 `WORKSHOP_AD_SSV_ENABLED`와 `WORKSHOP_ADMOB_AD_UNITS` allowlist가 필요하다. 광고 시작도 이 설정 없이 승인하지 않는다. SDK 완료 콜백은 지급 증거가 아니다. 실제 서명 요청·SDK/동의·보호 검증 파이프라인·에뮬레이터·실기기 검수 완료를 의미하지 않는다. 검증 명령/결과와 운영 설정은 위 인계 파일을 기준으로 확인한다.

### 2026-10-18 직원4 추가 검증

서버 보호 증거 수신은 `protected_purchase_pipeline.ts`의 서버 Ed25519 서명+계정/진행 epoch+순번/이전 digest CAS로 보완했다. 미검증 로컬 저장을 자동 승인하거나 기기에 서명키를 주지 않는다. 실제 게임 이벤트를 검증해 서명하는 발급 서버는 별도 연결이 필요하며 운영은 OFF다. 서버 홀드 전 실패는 검증된 취소 서명/잠금 확인 후 차감 없는 취소 원장으로 정산한다.

Functions 발견 단계에서 Play SDK와 Firestore client를 만들지 않도록 `play_purchases.ts`/`firestore_store.ts`로 초기화를 지연했다. Node22 빌드·테스트 및 실제 Firestore/Auth/Functions 에뮬레이터 결과와 실패 이력, 기본10초 발견 제한과 로컬120초 대기의 구분은 [4단계 인계](../../../coordination/step-04.md)에 기록한다. 이 기록은 실제 서비스 서명·광고 SDK·동의·계정 설정·실기기·배포 완료가 아니다.
