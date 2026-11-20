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

흥행 개선(26번) 장: 28 결정, 29 온라인 운영 설정, 30 손님 방문·알림, 31 첫 실행 로그인, [32 사용 통계](#32-사용-통계firebase-analytics--2026-11-19), [33 꾸미기·상점 화면 정리](#33-꾸미기상점-화면-정리--2026-11-19), [34 매일 돌아올 이유](#34-매일-돌아올-이유--2026-11-19), [35 공유 카드](#35-공유-카드--2026-11-19), [36 법률 확인 반영](#36-법률-확인-반영--2026-11-19), [37 3차 피드백 홈·굽기](#37-실기기-3차-녹화-피드백--홈굽기-c-묶음-h17h30--2026-11-19), [38 3차 피드백 E: 공통 테마·충전 상품·배경](#38-3차-피드백-e-공통-테마충전-상품배경--2026-11-19).

---

## 1. 개발 원칙

| 원칙 | 내용 | 지키는 곳 |
| --- | --- | --- |
| 광고·오류 수집 SDK 금지, 분석은 Firebase Analytics만 | ads, admob, crashlytics, sentry, 그 밖의 analytics 계열 금지. Firebase는 core/auth/functions/app_check와 **analytics**(26번 5단계, DEC-045·046)만 허용(app_check는 23번 7단계, Play Integrity). Analytics는 광고 ID·SSAID 수집과 개인화 광고 신호를 매니페스트 meta-data로 끄고, 라이브러리가 넣는 `AD_ID`·`ACCESS_ADSERVICES_*` 권한은 `tools:node="remove"`로 뺌. `setUserId`는 쓰지 않음. 카카오는 로그인용만. 구글은 `google_sign_in`(로그인만, 26번 2-1단계. 금지 단어에 걸리지 않아 허용 목록 추가 없음) | `test/no_tracking_sdk_test.dart` |
| 첫 실행 로그인 필수 (26번 2-1단계) | 온라인 빌드는 새 설치·업데이트 뒤 첫 실행에 필수 동의('만 14세 이상입니다' 확인 포함, 만 14세 미만 가입 불가 — 36장) + 카카오 또는 구글 로그인을 마쳐야 게임에 들어감. 한 번 로그인하면 저장된 로그인으로 오프라인 플레이. 필수 동의(이용약관·개인정보 수집·이용)와 선택 동의(성별·연령대)는 따로 받음. 앱 안에서 계정 삭제 가능(Play 정책). 이메일은 서버 프로필에만, 화면·분석에 쓰지 않음 | `lib/owner_account.dart`, `test/owner_first_run_test.dart` |
| 손님 알림은 기기 안에서만 | 26번 5-1단계: `flutter_local_notifications`(+`timezone`, UTC만)로 앱이 꺼진 동안 올 손님을 기기 안에 예약. 서버 푸시·Firebase Messaging 없음, 정보를 어디에도 보내지 않음. 권한은 `POST_NOTIFICATIONS`(Android 13+ 실행 중 요청)·`RECEIVE_BOOT_COMPLETED`(재부팅 뒤 재예약)뿐, 정확한 알람 권한(`SCHEDULE_EXACT_ALARM`·`USE_EXACT_ALARM`) 없음(몇 분 늦을 수 있음) | `test/no_tracking_sdk_test.dart`, `lib/customer_notifier.dart` |
| 현실 보상 없음 | 현금·상품·포인트를 지급하지 않음. 공유에도 보상 없음 | README |
| 경제는 BigInt | 가격·생산·보상은 BigInt로 계산하고, 배율은 정수 천분율(‰)로 계산(`effectScale` = 1000). double 금지. 저장할 때는 10진 문자열 | `economy.dart`, `config_values.dart` |
| 코인은 원장으로만 | 모든 코인 변동은 `support.transact(id, …)`/`grantReward`로. id가 중복 지급을 막는 키(`daily:<day>:<id>`, `weekly:<week>:<id>`, `achievement:<id>`, `level:<n>`) | `support_rules.dart` |
| 저장은 원자적으로 | 중요한 명령은 `before = state.copy()` → 변경 → `_commit`. 저장 실패 시 되돌림. 프레임·탭마다 저장 금지 | `game_controller.dart` |
| 시간은 게임 시계로 | `DateTime.now()` 대신 `gameNow`/`observedUtc` 사용. 기기 시계를 되돌려도 지난 날짜·주는 다시 열리지 않음 | `support_state.dart` |
| 키 커밋 금지 | 카카오·Firebase 키를 저장소에 넣지 않음. 앱 키는 `dart_defines/online.json`, 서버 설정은 `firebase/functions/.env`(둘 다 gitignore, 견본만 커밋) | `test/stage16_kakao_ranking_test.dart`, `test/online_setup_test.dart` |
| 테스트 기준 유지 | 테스트 목표나 골든 허용치를 낮추지 않음 | README |
| 개발자 전용 기능 | 초대 시뮬레이터 등은 `developerTools`(= `!kReleaseMode`)일 때만 | `game_controller.dart` |

**2026-11-19 26번 5단계로 바뀜:** 첫 줄은 원래 '광고·추적 SDK 금지'였고, DEC-045·046에 따라 `firebase_analytics`만 허용으로 바꿨다(32장). 광고 SDK는 출시 빌드에 넣지 않는다(DEC-028 유지, 출시 후 별도 브랜치 DEC-049).

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
2. `withOnline = Android && firebaseConfigured`. 온라인이면 `KakaoSdk.init` 후 `FirebaseOnlineBackend.create()`. 아니면 `NoOnlineBackend`·`NoRankingService`·`NoBillingService`. 사용 통계는 Firebase가 켜진 빌드만 `UsageStats(FirebaseUsageStatsSink())`, 아니면 `UsageStats.none`(32장). 같은 기록기를 `GameController(usage:)`·`WorkshopController(usage:)`·`OwnerAccount(analytics: UsageOwnerAnalytics(usage))`에 넘김.
3. `GameController(SqliteGameRepository(), SystemTimeService(), …)` 생성.
4. `PixelSprites.load()`로 이미지를 미리 읽음.
5. `controller.initialize()` → 설정 파일(+ `config/owner_name_rules.json`) → `WorkshopController.initialize()` → `OwnerAccount.load()`(첫 실행 기록, 26번 2-1단계) → `runApp(GameApp)`. `GameApp`은 `OwnerGate`로 첫 실행 화면(로그인·이름·캐릭터·선택 정보)을 마칠 때까지 게임 대신 보여 줌. 셋 중 하나라도 읽지 못하면 두 DB를 닫고 `SaveRecoveryApp`(`ui/save_recovery.dart`, 3장 "저장 손상 대처").

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
| 저장 형식 버전 | `GameState.formatVersion = 14` (`models.dart`) |
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
| JSON 저장 형식 | `schema` 10. 1~9를 읽고 10으로 저장 (`user_version` 4 그대로, 생산 저널·구매 보호 기록 형식 변경 없음. 구매 보호 저장 검사는 schema 10만 받음, 보호 목록 `[2,…,10]`) |
| schema 5 (2026-11-09) | 대기 손님 주문의 `deliveries`(부분 판매 기록). schema 4 이하에 있으면 거절 |
| 결과 등급 (26번 4단계) | 저장 변경 없음: 등급은 화면에서 계산하고, 주문 손님 반응 연결은 메모리에만 둠 |
| 제작 세션 `session` (CookingSession schema 1, 24번 5단계 G1) | 짤주머니 세 단계의 칠한 양을 **추가 필드**로 저장: `firstBatterCoverage`·`firstBatterAmount`, `fillingCoverage`·`fillingAmount`, `secondBatterCoverage`·`secondBatterAmount`(permille, 단계를 마치면 둘 다 있음, 0 < 덮음 ≤ 1000, 덮음 ≤ 양 ≤ 9000). 예전 `firstBatterMs`·`secondBatterMs`·`fillingDurationMs`는 읽기만 하고 새로 쓰지 않음(같은 단계에 두 종류가 함께 있으면 거절). 단계 완료 = 둘 중 하나가 있음. 예전 저장·진행 중 세션은 그대로 이어서 하고, ms로 끝난 반죽 단계는 손기술 실패. Workshop schema 6·`user_version` 4·생산 저널 형식 변경 없음 |
| schema 6 (2026-11-11) | 첫 실행 안내 `tutorial`: `cook` → `sell` → `done`, 또는 `skipped`. 새 설치는 `cook`. schema 5 이하는 `done`으로 올리고, 그 버전에 `tutorial`이 있으면 거절. 판매 기록이 있는데 `cook`/`sell`이면 거절 |
| schema 7 (2026-11-18, 26번 5-1단계) | 손님 시계 `regularClock`·`namedClock`(`{nextAt: UTC ms 또는 null, seed, draws}`)과 직전 네임드 `lastNamedVisitor`. 7에 셋 중 하나라도 없거나 6 이하에 있으면 거절. 닫힌 가게·안내 중인데 `nextAt`이 있거나, `nextAt`이 정산 시각 + 최대 간격보다 멀면 거절. `lastNamedVisitor`는 만난 손님만. 6 이하 이전: 시드는 진행 ID(`grid.runId`)에서 만들고 시계는 멈춘 채(null) 두어 불러온 뒤 첫 정산 시각부터 셈, `lastNamedVisitor`는 관계 기록의 가장 늦은 방문. `arrivalMs`는 안내 중 손님 간격용으로 그대로 |
| schema 9 (2026-11-19, 26번 4-5단계, G12) | 필드 추가 없음. 요리사 복(`chefcoat`)·패딩 조끼(`padding`)가 앞치마(`outfit`) 칸에서 상의(`top`) 칸으로 옮겨 감(`movedToTop`). 8 이하에서 `avatarEquipment.outfit`이 둘 중 하나면 `top`=그 id, `outfit`=`noapron`으로 읽음(보이는 모습 유지, 보유 `purchases.owned['cosmetic:<id>']`는 id 그대로라 변화 없음). 9에서 `outfit`이 둘 중 하나면 칸 불일치로 거절 |
| `avatarGrants` (2026-11-19, 3차 피드백 H11·H12, DEC-129) | schema 10 그대로 키만 더함: 사지 않고 가진 아바타 아이템(정렬 목록, 칸이 character·skin인 것만, 사장님은 정확히 하나). 새 가게 `['girl']`, 첫 실행 사장님 고르기(`chooseStarterCharacter`)가 그 사장님 하나로 바꿈. 이 키가 없는 저장(규칙 전)은 그때 입은 사장님(없으면 girl)과 입은 피부톤을 넣어 읽음(기존 저장 존중). 착용 검사는 무료 ∪ `avatarGrants` ∪ 산 것 ∪ 가진 사장님의 기본 머리(26번 3차 G, `WorkshopState.hasAvatar`·`characterDefaultHair`: 남자 사장님을 가지면 짧은 머리도 가짐 — 저장 키는 늘지 않음). 구매 보호 대상 아님 |
| schema 10 (2026-11-19, 26번 7단계) | 매일 기록 `daily`: `day`(마지막으로 본 KST 날짜), `order`(오늘의 주문서 `{day, npc, flavor, variant 1~3, quantity, event, reward, businessIndex}`, 납품하면 `reward`(붕어빵력 10진 문자열)·`businessIndex`가 함께 생김), `stamps`(출석 칸 0~7)·`stampDay`(마지막 도장 날짜, 둘은 0/null을 함께), `events`(들어온 행사 ID, 정렬). 9 이하는 빈 기록으로 읽음(첫 명령에서 오늘 날짜·주문서가 채워짐), 9 이하에 `daily`가 있거나 10에 없으면 거절. 날짜가 정산 시각의 KST 날짜보다 뒤, 가지지 않은 맛, 만나지 않은 손님, 모르는 행사 ID, 단골 주문서를 납품했는데 관계 기록 `special:<날짜>`가 없음(또는 납품 전인데 있음)이면 거절. 황금 심사 `pendingGold['attendance:<날짜>']`(출석 7칸째)는 `{scope:'attendance', period, goal:'day7', gold, revision}` 다섯 키만, 날짜 ≤ `stampDay`. 구매 보호 대상 아님 |
| schema 8 (2026-11-18, 26번 2단계) | 이미 본 기능 소개 카드 `featureIntros`(`WorkshopFeature` 이름 목록, 정렬해 저장: `skills`·`griddle`·`collection`·`recipes`·`specialOrders`·`fishCosmetics`·`freshness`·`stallCosmetics`). 8에 없거나, 모르는 이름·중복이 있거나, 7 이하에 있으면 거절. 7 이하 이전: 불러온 상태에서 **이미 열린 기능은 본 것으로 채움**(고레벨 기존 저장은 카드 0장, 낮은 레벨은 앞으로 열릴 카드만). 첫 판매 칭찬(`salePraise`)은 저장하지 않음 |

**첫 실행 기록 저장** (26번 2-1단계, `lib/owner_profile.dart` `OwnerProfile`, `lib/owner_repository.dart`)

| 항목 | 값 |
| --- | --- |
| DB | sqflite `todays_bungeoppang_owner.db`, 테이블 `owner(id, body)` 한 줄(JSON). 계정·가게 저장과 따로라 **계정 저장 v13·가게 schema 8은 그대로** |
| JSON | `schema` 1. `account`(`kakao:<번호>` 또는 구글 uid)·`provider`(`kakao`/`google`, 둘은 함께 있거나 함께 없음), `consentVersion`(필수 동의 판, 지금 `2026-11-19` = `requiredConsentVersion`, 이 판부터 '만 14세 이상' 확인 포함)·`consentAtMs`, `name`(사장님 이름), `characterChosen`, `optionalAsked`, `optional`(`gender`·`ageBand`·`agreedAtMs`. 연령대에 `under14` 없음), `serverSynced`(서버 프로필에 보냈는지). 옛 기록의 `optional.guardianConsent`는 읽을 때 무시하고 쓰지 않음, `ageBand: under14`+보호자 체크였던 선택 정보는 읽을 때 버리고 `serverSynced=false`로(다음 동기화에 서버 연령대도 지움, 36장) |
| 읽기 실패 | 모양이 틀리거나 DB를 못 읽으면 빈 기록으로 보고 첫 실행 질문을 다시 함(게임 진행은 다른 저장이라 영향 없음, 복구 화면으로 가지 않음) |
| 캐릭터 | 고른 값은 가게 저장 `avatarEquipment.character`(`WorkshopController.equipAvatar`)에 들어가 꾸미기와 같음. 이 기록은 물었는지만 |
| 기존 저장 | 로그인 없이 하던 저장은 그대로 두고, 로그인한 계정이 이 기기 가게의 주인이 됨. 가게 저장에 이미 `rewardAccount`·`purchases.account`가 있으면 그 계정만 받음(다른 계정이면 로그아웃시키고 안내) |
| 계정 삭제 뒤 | 서버 삭제가 끝나면 세 DB(`todays_bungeoppang.db`·`_workshop.db`·`_owner.db`)를 지우고 새 설치처럼 다시 시작(`main.dart` `_wipeAndRestart`) |

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
| v14 | 26번 4-5단계(G12): 필드 추가 없음. 13 이하에서 `wardrobe.equipped.outfit`이 `chefcoat`·`padding`이면 `top`=그 id, `outfit`=`noapron`(`menu_state.dart`). 14에서 앞치마 칸에 두 아이템이 있으면 거절 |
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
| 매일 돌아올 이유 하루 경계 (26번 7단계) | 정산 시각(`business.settledUtc`, 앞으로만 감)의 KST 날짜(`WorkshopController.today`). 기기 시계를 되돌려도 지난 날이 다시 열리지 않고, 며칠을 비워도 출석은 돌아온 날 한 칸·주문서는 오늘 하나. 영업일 번호와 따로(닫혀 있어도 출석은 됨, 납품은 영업 중에만). 34장 | `lib/workshop_daily.dart` |
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
- 스킬 창(`lib/ui/workshop_skill_shop.dart` `WorkshopSkillShop`, `workshop_windows.dart`가 다시 내보냄; 26번 4-3단계 F12~F19): '사는 목록'이 아니라 **레벨을 올리는 목록**. 위 줄 = 탭 버튼 '클릭 생산'·'자동 생산'(키 `kind-tap/kind-auto`, 체크 표시 없는 직접 만든 탭, 아이콘 28px, 고른 탭은 꿀색, 두 탭이 줄을 반씩). 단위 돌림판은 **스킬마다** 칸 안에 하나씩(26번 시안 확인 2차, DEC-128): `SkillStepWheel`(키 `skill-step-<id>`, 값 `step-<id>-1/10/100`, 폭 40·줄 14, 위아래로 밀거나 이웃 값을 눌러 한 칸씩). 고른 단위는 `WorkshopController.skillSteps`(스킬 id → 단위)에 **앱을 켜 둔 동안만** 기억하고 저장하지 않음(저장 형식 변경 없음, 없으면 ×1). 단위 `skillLevelUpSteps = [1, 10, 100]`은 Dart 상수(`lib/development_rules.dart`, 설정 파일 아님). 한 번에 올리는 양 `skillLevelUpQuantity` = min(단위, 1000 − 레벨) — 995에서 ×10은 5. 서버(`development_contracts.ts`)가 `cap − owned` 이하면 받으므로 서버 변경 없음. '최대(살 수 있는 만큼)'·1개/10개/최대 칩·'자세히 보기'·'스킬 구매는 온라인 연결…' 문장은 없앰. 칸(키 `skill-$id`, 높이 약 66px): 왼쪽 그림 40px, 가운데 이름 + 두 줄 'Lv.12/1000' / '+60/클릭'(키 `level-$id`, 글은 줄바꿈 하나로 이어진 한 Text, 이 스킬 한 레벨 효과, 자동은 '/초'), 오른쪽 비용(`CurrencyAmount`: 붕어빵력·황금 아이콘 + 줄인 숫자, 모자라면 빨강 `0xffc0392b`, 줄였으면 길게 눌러 정확한 숫자, 황금 0이면 황금 줄 없음, 키 `cost-$id`) + 그 스킬의 돌림판(해금된 칸만) + 'LEVEL UP' 글자 버튼(`LevelUpButton`, 키 `buy-$id`, `ui/levelup.png`·`levelup_off.png` 108×72를 54×36으로, 둘째 줄 'UP'; 25번 33번 생성 그림을 `tools/apply_25_art.py --only levelup`으로 적용(2026-11-19, 꺼짐 그림은 켜짐 그림을 밝기대로 회색으로 바꿔 만듦 — 생성된 꺼짐 그림은 면에 구멍 두 개라 안 씀), 그림이 없으면 같은 크기 글자 버튼. 예전 둥근 '+'·'×10' 꼬리표는 DEC-128로 없앰). 버튼은 해금·온라인 구매 연결·로그인·오류 없음·바쁘지 않음·두 재화 충분일 때만 켜짐. 꺼진 '+'를 누르면 스낵바로 이유: '누적 N개 만들면 열려요.' / '인터넷에 연결하면 레벨업할 수 있어요.' / '카카오 로그인 후 레벨업할 수 있어요.' / '붕어빵력이 3.2만 모자라요.'(황금도 같은 식) / '잠시 뒤에 다시 눌러 주세요.'. 1000이면 버튼·돌림판 대신 'MAX' 배지(키 `max-$id`). 잠긴 스킬은 **바로 다음 하나만** 보이고(S43-Q3) 그 뒤는 숨김: 그림 대신 공통 잠금 `LockedOverlay(style: LockStyle.hidden)`(키 `skill-lock-$id`, 실루엣 + 큰 자물쇠) + '누적 100만 개 만들면 해금'(키 `unlock-$id`, `compactNumber`라 '누적 2000조 개'). 조기 해금 없음(S43-Q5). 위쪽 안내: 황금 0 단계가 있으면 '1~N단계 스킬은 붕어빵력만으로 레벨업해요. 황금붕어빵력은 N+1단계부터 필요해요.'(키 `skill-gold-note`, N은 설정에서 계산), 온라인 빌드에서 로그인 전이면 '카카오 로그인 후 레벨업할 수 있어요.' + '카카오 로그인' 버튼(키 `skill-sign-in`, `GameController.signInOnline`), 정산 안 된 거래는 '레벨업 확인 대기: 스킬 이름'(꾸미기는 '구매 확인 대기') + 복구·취소 확인. 로그인 전 `purchaseSkill`은 거래를 만들지 않고 같은 안내만 남긴다. 확인 실패·복구 문구는 스킬이면 '레벨업 확인이 남아 있어요…'·'레벨업 복구 확인이 필요해요', 꾸미기(`cosmetic:`)는 '구매'. 저장(`purchases.owned` = 레벨)·서버 함수 이름은 그대로. 한 화면에 보이는 칸: 390×844 7칸, 360×640 4칸(전에는 390×844에서 약 2칸, `test/workshop_skill_window_test.dart`가 확인). 구형 `lib/ui/skill_shop.dart` `SkillShop`(구형 `GameHome`)은 고치지 않음.

---

## 5. 미션·일일·주간·업적·환생

### 매일 돌아올 이유 (Workshop, 26번 7단계)

오늘의 주문서·출석 도장·이야기 하루 한 조각·겨울 행사. 규칙·설정값·화면은 [34장](#34-매일-돌아올-이유--2026-11-19). 아래 레벨 미션~환생은 구형 홈 기록입니다.

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

신규 Workshop 미션 창은 `config/development_balance.json` `mission_targets`의 label을 보여 줍니다. 26번 4-3단계에서 일일 `purchases` '스킬 구매 수량' → '스킬 레벨업 횟수', 주간 '주간 스킬 구매 수량' → '주간 스킬 레벨업 횟수'로 바꿈(id·집계 그대로, 레벨 수를 셈: ×10 한 번 = 10).

| id | 내용 | 목표 | 보상 |
| --- | --- | --- | --- |
| taps | 붕어빵 탭 | 50 | 2코인 |
| production | 오늘 붕어빵 생산 | 1000 | 3코인 |
| purchases | 스킬 레벨업 횟수 | 3 | 2코인 |
| auto | 기본 초당 생산 | 10 | 3코인 |
| (전체 완료) | | | 10코인 (`dailyAllReward`) |

초당 생산 목표는 부스트를 뺀 기본 생산량의 최고치로 판정합니다.

### 주간 도전 (`lib/weekly_config.dart` `weeklyGoals`)

**Workshop(현재 경로)**: 일일 미션·주간 도전은 메뉴가 아니라 홈 '오늘' 창에 있다(3차 피드백 H36, 34장). 목표·보상은 `config/development_balance.json` `mission_targets`·`mission_gold_rewards`. 아래 표는 구형 홈 기록.

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
> 26번 4-6단계: 배경음악은 모든 배경·시간에 같은 곡 'Warm Bungeoppang Stall' 하나입니다(`audio/bgm_warm_stall.ogg`). 아래 표의 '음악' 열(분위기)은 코드 구조로만 남아 있고 지금은 모두 같은 곡을 틉니다. 설정의 '배경음 선택' 드롭다운은 없앴습니다(저장값은 그대로 읽음, [12장 소리](#12-이미지소리)).

- 해금 조건: 레벨 ≥ `unlockLevel` 그리고 누적 생산 ≥ `unlockProduction`. 신규 Workshop의 아바타는 `avatar_catalog`의 `unlock_level`·`unlock_total`(누적 생산, 지금 모두 "0")이고, 화면에는 **'Lv.N 해금'만** 보임(26번 4-5단계 S45-Q2: '누적' 표시는 지움, 값 0과 서버 검사는 그대로).
- 코인으로 삽니다. 황금 붕어빵으로 사면 가격은 코인 × 5이고 해금 조건을 건너뜁니다.
- 기본 아이템과 character, skin, time 칸의 아이템은 수집 개수에서 빠집니다(구형 클리커에서는 무료).
- **사장님·피부톤(Workshop, 3차 피드백 H11·H12, DEC-129):** 첫 실행에서 고른 사장님 하나만 가지고 바꿀 수 없음(안내 '한 번 고르면 바꿀 수 없어요', `OwnerTexts.characterHelp`). 다른 사장님은 꾸미기에서 삼(`avatar_catalog` girl·boy `free: false`, 가격 `cosmetic_purchase` girl·boy 붕어빵력 1000 + 황금 10, 임시값). 피부톤은 skin1만 무료, skin2·3은 판매(붕어빵력 1000 + 황금 2, 임시값). 사지 않고 가진 것은 가게 저장 `avatarGrants`(3장). 규칙 전 저장은 입던 사장님·피부톤을 그대로 가짐. 첫 실행 뒤(`OwnerProfile.characterChosen`)에는 `chooseCharacter`가 가진 것만 입힘. 서버 생성 설정이 바뀌어 **서버 배포 필요**. 구형 금화 가격표(`catalog.json`)에는 넣지 않음(`tools/development_balance.py`가 이 넷만 예외로 허용).
- **사장님별 기본 머리(26번 3차 G, 2026-11-20 사용자 결정):** 여자 사장님은 긴 생머리, **남자 사장님은 짧은 머리**(`characterDefaultHair`·`defaultHairOf`, `cosmetic_config.dart`). 그 사장님을 가진 가게는 기본 머리를 사지 않고 가짐(`WorkshopState.hasAvatar`, 저장 형식 그대로). 머리를 고른 적 없으면(가게 저장 `avatarEquipment`에 hair가 없고 옛 계정 꾸미기 값이 기본 긴 생머리) 지금 사장님의 기본 머리를 입음(`WorkshopState.avatarWorn`) — 그래서 기존 저장의 남자 사장님도 짧은 머리로 보이고, 직접 고르거나 산 머리는 그대로. 사장님을 바꿔 입을 때 입던 머리가 이전 사장님의 기본 머리면 '고른 적 없음'으로 돌려 새 사장님의 기본 머리가 보임(꾸미기 미리보기도 같음). 첫 실행 캐릭터 카드·공유 카드·서버에서 받은 모습도 같은 규칙. 서버 변경 없음.

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

칸 이름(화면): pattern은 **'틀'**(26번 4-5단계 S45-Q5, 전에는 '무늬'), outfit은 '앞치마'. id·enum은 저장값이라 그대로.
| props | accessory, tool |
| bungeoppang | pattern, topping |
| stall | 노점 칸 전부 |

### 아이템 표

표기는 `id 이름 코인/레벨[/누적생산]`이고, 굵게 표시한 것이 기본값입니다.

| 칸 | 아이템 |
| --- | --- |
| background | **clear 맑은 날 0/1**, night 야간 골목 3/1, dusk 보랏빛 해질녘 5/2/100, rain 비 오는 날 6/2, snow 눈 오는 밤 7/3, autumn 가을 골목 9/4, forest 숲길 노점 9/5/1만, cherry 벚꽃 골목 10/6, snowday 눈 오는 낮 11/6, seaside 바닷가 야시장 14/8 (구형 코인 값. **신규 Workshop은 26번 3차 H42부터 `avatar_catalog`에 slot `background`로 들어가 붕어빵력 1000 + 황금 2(`cosmetic_purchase`)로 팔고, 해금 레벨은 위 레벨 그대로·누적 조건 없음, clear는 무료** — 38장) |
| stove | **iron 기본 화로 0/1**, castiron 무쇠 화로 6/2, copper 구리 화로 7/3/1000, golden 황금 화로 15/9 |
| decoration | **none 0/1**, lantern 종이 등불 4/2, starlights 별 전구 5/3, bunting 작은 축제 깃발 8/4/5000, windchime 풍경 9/5, paperlanterns 종이 초롱 줄 10/6, snowman 눈사람 12/7 |
| lamp | **amberlamp 기본 등불 0/1**, roselamp 분홍 4/2, mintlamp 민트 6/3, lilaclamp 라일락 8/4 |
| time | **scenetime 배경 그대로**, day 낮, night_time 밤, clock 기기 시간(19~06시 밤) |
| pattern | **scales 기본 모양 0/1**(26번 4-5단계, 전 '기본 비늘'), heartscale 하트 비늘 5/2, starmark 별 도장 8/4, crispgrid 바삭 격자 11/6 |
| topping | **plain 0/1**, sugar 슈가파우더 4/2, choco 초코 드리즐 7/3, almond 아몬드 슬라이스 9/5, sprinkle 무지개 스프링클 13/8 |
| character | **girl 여자 사장님**, boy 남자 사장님 (첫 실행에 고른 하나만 무료, 다른 하나 1000/황금 10) |
| skin | **skin1**, skin2, skin3 (skin2·3은 1000/황금 2, 3차 피드백 H12; 26번 4-7단계 G4: skin3 = 2026-11-18까지의 skin2 색, skin2 = skin1과 그 사이의 연한 새 색, id 그대로) |
| hair | **long 긴 생머리 0/1**(여자 사장님 기본), short 짧은 머리 3/1(**남자 사장님 기본** — 26번 3차 G, 남자 사장님을 가진 가게는 사지 않고 가짐), ponytail 묶은 머리 5/2, curly 곱슬머리 8/5 |
| top | **tee 흰 티셔츠 0/1**, creamlong 크림 긴팔 3/2, pinksweater 분홍 니트 6/3, sagesweater 세이지 니트 6/4, creamsweater 꽈배기 니트 8/5, cardigan 카디건 10/6, padding 패딩 조끼 6/3, chefcoat 요리사 복 12/7 (padding·chefcoat는 26번 4-5단계 G12에서 outfit → top, 그림 `avatar/<성별>/top_<id>.png`, 앞치마를 위에 겹쳐 입을 수 있음) |
| bottom | **shorts 베이지 반바지 0/1**, skirt 주름치마 4/2, widepants 와이드 바지 6/3, brownpants 갈색 바지 7/4, jeans 연청 청바지 5/2, denimshorts 데님 반바지 5/3, joggers 회색 조거 바지 6/3, checkskirt 빨강 체크 치마 7/4, cargopants 카키 카고 바지 8/5, longskirt 크림 롱스커트 9/6 (새 6종은 26번 4-7단계 G11, 가격·레벨 임시값, 서버 `avatar_catalog`·`cosmetic_purchase`에도 있음. **v2 아바타 그림에만 있어 v2가 꺼지면 꾸미기·상점에서 숨김**(26번 3차 AV로 켜져 보임). brownpants는 46번에서 '갈색 골덴 일자 바지'로 그려짐, 이름은 '갈색 바지' 그대로·칸 아이콘은 25번 46번 51번 재주문) |
| shoes | **flats 갈색 단화 0/1**, sneakers 흰 운동화 4/2, boots 앵클부츠 7/4, furboots 털 부츠 10/7 |
| outfit | **apron 기본 앞치마 0/1**(26번 4-4부터 그림으로 입혀짐), noapron 앞치마 없음 0/1(무료, 그림 없음), darkapron 초코 앞치마 5/2, creamapron 크림 앞치마 7/4, stripe 줄무늬 앞치마 9/5, waistapron 허리 앞치마 9/5 (앞치마만) |
| hat | **nohat 0/1**, beanie 털 비니 3/2, bandana 크림 두건 4/2, earmuffs 귀마개 6/3, redbandana 빨간 두건 6/3, ballcap 크림 야구모자 7/4, newsboy 헌팅캡 8/4, blackcap 검정 야구모자 9/6, chefhat 요리사 모자 10/6, santa 산타 모자 14/9 |
| accessory | **noacc 0/1**, ribbon 분홍 리본 4/2, fishpin 붕어빵 머리핀 5/3, glasses 동그란 안경 6/3, scarf 분홍 목도리 8/5, mittens 털장갑 9/6, crossbag 크로스백 11/7 |
| tool | **tongs 도구 없음 0/1**(26번 3차 H8: 손에 든 집게를 지움 — id는 저장용으로 그대로, 그림 없음 `blankCosmetics`), paperbag 붕어빵 봉투 8/5, fishhold 갓 구운 붕어빵 12/8, goldtongs **황금 뒤집개** 15/9(26번 3차 AV, DEC-146 갱신: 같은 id로 25번 41번 황금 뒤집개 그림·칸 아이콘, 이름 '황금 집게' → '황금 뒤집개'(앱·`config/development_balance.json`·서버 생성 설정), 숨김 해제 — 가격·해금·보유 기록 그대로) |

### 사장님 레이어와 얼굴 모션 (17단계)

파일: 데이터 `lib/avatar_rig_config.dart`, 생성 데이터 `lib/avatar_atlas.dart`(직접 고치지 않음), 모션 `lib/avatar_motion.dart`, 그리기 `lib/ui/avatar_painter.dart`(`AvatarRig`), 화면 연결 `lib/ui/avatar_face.dart`(`AvatarFace`), 에셋 도구 `tools/avatar_layers.py`

**좌표:** 리그 픽셀 = 포즈 그림의 픽셀입니다(정면 280×520 캔버스, 조리 프레임 506×506). 레이어는 기준점(anchor)에 걸리고, 이동·확대·좌우 반전은 리그 전체에 한 번 적용되므로 모든 레이어가 함께 움직입니다.

**그리기 순서(`RigLayer`)**

| 순서 | 레이어 | 내용 |
| --- | --- | --- |
| 1 | behind | 아이템 뒤 조각 `<slot>_<id>_back.png` |
| 2 | base | 포즈 그림(몸·얼굴·기본 머리·기본 옷). 피부톤이 skin2·3이면 `base@<skin>.png` |
| 2-1 | (_cut) | 착용 중인 아이템의 `<slot>_<id>_cut.png` 마스크로 base에서 가려질 픽셀을 지움(`BlendMode.dstOut`, base만 담은 `saveLayer` 안). 머리·얼굴·옷은 지우지 않음 |
| 3 | hair | 머리 모양 `hair_<short·ponytail·curly>.png`(긴 생머리 `long`은 base 그대로). 긴 머리는 hair의 `_cut`이 지움. (v2 순서는 아래 '맨 바탕 아바타 v2') |
| 4 | eyes | 눈 프레임 |
| 5 | mouth | 입 프레임 |
| 6~12 | bottom, shoes, top, outfit, hat, accessory, tool | 칸별 아이템(`rigSlotLayers`). tool만 탭할 때 올라감 |
| 13 | front | 아이템 앞 조각 `<slot>_<id>_front.png` |

- 아이템 그림의 기준점은 캔버스 원점입니다. 잘라낸 그림은 `avatarTrimOffsets`의 (left, top)에 놓입니다. 그림 크기가 280×520이면 오프셋을 무시합니다.
- 그림별 위치 보정·크기·회전·같은 층 안의 순서는 `rigPlacements`(경로 → `RigPlacement`)에 둡니다. 지금은 비어 있습니다.
- 앞/뒤 조각은 파일만 넣으면 됩니다. `PixelSprites.load`가 에셋 목록에 있는 것만 읽습니다.
- character는 base 그림을 고릅니다. skin은 그림마다 피부색만 바꾼 복사본 `<파일>@skin2.png`·`@skin3.png`를 고릅니다(`rigSkinPicture`, 복사본이 없는 그림은 원래 그림). 복사본은 base, 정면 얼굴 부분 그림, 피부가 보이는 hair·hat 레이어에만 있습니다. hair는 hair 레이어입니다(26번 4-4, 2026-11-18).
- **입은 모습(worn) 레이어:** 3.3 원본 폴더의 '입은 모습' 전신 그림(`avatar/<성별>/<slot>_<id>.png`)을 base에 겹쳐(머리 아래 몸으로 맞춤) 바뀐 픽셀만 아이템 레이어로, base에서 사라진 픽셀은 `_cut` 마스크로 만듭니다(`tools/avatar_layers.py worn`, `WORN_ITEMS`). `_cut`은 base 가장자리 밖·아이템 아래로 2픽셀 넓혀서 축소해 그려도 옛 외곽선이 남지 않습니다. 모자·액세서리는 얼굴(눈·입 상자 + 12픽셀)을 바꾸지 않습니다. 어느 레이어가 worn으로 만들어졌는지는 생성 파일 `avatarWornLayers`, 에셋 목록은 `avatarArtFiles`(둘 다 `lib/avatar_atlas.dart`).
- **꾸미기에 보이는 조건(`PixelSprites.avatarArtReady`):** 기본값·그림 없는 아이템(`blankCosmetics`)·skin1·긴 생머리는 늘 보임. skin2·3은 `base@<skin>.png`, hat·hair는 worn 레이어(`avatarWornOnlySlots`), 나머지는 그림 파일이 있어야 보입니다. 지금 캐릭터 기준이고, 이미 산 아이템은 그림이 없어도 보입니다(`workshop_page.dart` `_cosmetics` `listed`). 그림이 들어오면 `python tools/avatar_layers.py`만 다시 돌리면 코드 변경 없이 보입니다. 2026-11-18: 털 비니·크림 두건·크림 야구모자·헌팅캡도 '쓴 모습' 레이어가 생겨(25번 17번) 지금 숨기는 아바타 아이템은 없음.
- 조리 장면(cook 측면 6장)은 옷·피부가 그려진 그림이라 피부톤·머리·아이템을 반영하지 않습니다(26번 4-4 '이번엔 정면만', 4-7에서도 범위 밖 — 후속 단계).
- **남자 바탕 되돌림(26번 3차 G, 2026-11-20 사용자 결정 '아바타 전(v1)이 더 낫다 — 얼굴·몸은 그대로'):** 3차 B1이 `rebase`로 남자 base를 다른 원본 묶음에서 다시 만들어 얼굴이 원래와 달라졌으므로, 남자 base를 3차 전 원본(git `ab54928`)으로 되돌리고 `REBASE`는 비움(함수는 남김), 얼굴 상자 `FACES['boy_front']`·`CHIN` 208도 원래 값. H9(목 비뚤어 보임)는 `tidy`만으로 고침: 목 뒤 짙은 머리가 오른쪽만 넓어 목이 한쪽으로 쏠려 보이던 것을 목 띠(206~218행)의 왼쪽 절반을 x 150 기준으로 오른쪽에 거울처럼 복사(얼굴·몸통은 그대로). 남녀 모두 캔버스 맨 아래(510행 아래) 200px 미만 찌꺼기(첫 실행 카드 발 옆 짧은 선)를 지움. `FRINGE` 남자 회색 상자·`clear`(팔과 몸 사이 흰 찌꺼기, 90~106열·300~352행)는 유지. 머리 모양이 긴 머리를 모두 지우는 `WORN_NEAR['hair']` 400은 유지. 남자 옷 레이어의 팔·몸 사이 흰 배경 찌꺼기는 `gap`(`GAPS` 상자 안 밝은 회백색, 바탕이 빈 곳), 여자 옷 레이어(앞치마·상의·하의·소품)에 남은 긴 머리 끝(짧은·묶은 머리에서 손 옆에 뜨던 것)은 `strands`(짧은·묶은 머리 `_cut`이 모두 지우는 자리에서 바탕과 같은 색, 또는 팔 바깥 열 `STRAND_SIDES` 64·238 밖)가 지움. 그리기: v1에서 모자를 쓰면 남자 기본 짧은 머리는 바탕 머리로 그림(`v1HatHairAsBase` — v1 모자는 바탕 머리를 누른 그림에서 잘라 짧은 머리와 겹치면 머리 조각이 흩어졌음). 순서: `python tools/avatar_layers.py`(rebase fringe tidy face worn chin gap strands derive skin trim). 주의: 여자 아이템 레이어는 3차 B1 때 그림 그대로에 `tidy`·`strands`만 적용 — `worn`을 다시 돌리면 여자 레이어도 새로 만들어지므로 점검 시트로 다시 확인. 얼굴·몸 비교: 원본 대비 바뀐 픽셀은 목 띠·바닥 찌꺼기·머리 회색 찌꺼기·팔 옆 흰 찌꺼기뿐(26번 3차 G 결과 표).
- **남자 턱(26번 4-7단계 G3):** 남자 사장님의 앞치마 5종·요리사 복 worn 레이어(와 `_cut`)가 194행부터 시작해 원본 그림의 다른 턱·목을 덮어 그려 얼굴 아래가 납작하게 잘려 보였습니다. `tools/avatar_layers.py chin`이 `CHIN = {'boy': 208}`(목선) 위를 지웁니다(worn 다음, derive·skin 전에 돌림). 화면 배율 문제는 아님(게임 그리기 = 에셋 픽셀, `tools/avatar_v2.py faceaudit`).

### 맨 바탕 아바타 v2 (26번 4-7단계)

파일: 규칙 `lib/avatar_v2.dart`, 생성 `lib/avatar_v2_atlas.dart`(직접 고치지 않음), 도구 `tools/avatar_v2.py`·`tools/avatar_v2.json`, 그림 `assets/images/avatar_v2/<girl·boy>/`(25번 문서 23~31번)

- **방식:** 머리·옷 없는 맨 바탕(민소매 이너·속바지·맨발, 피부톤마다 `base@skin1~3.png` 한 장씩) 위에 모든 아이템(기본 흰 티·반바지·단화·긴 생머리·기본 앞치마 포함)을 '입은 모습' 레이어로 얹습니다. `_cut`·`@skin` 복사본을 쓰지 않습니다.
- **켜는 스위치:** 필수 그림 110장(바탕 6 + 노출 아바타 아이템 전부 × 남녀 + 긴·묶은·곱슬 머리 뒤 조각 `hair_<id>_back.png`, `avatarV2Required`; 3차 H8로 `tongs`가 그림 없음이 되어 112→110)이 **모두** 있을 때만 생성 상수 `avatarV2Ready = true`. 하나라도 없으면 정면 아바타 전체가 v1(위 표)로 그려지고 섞이지 않습니다. 조리 장면은 v2와 무관(늘 v1). **2026-11-19 밤 110/110 → 켜짐**(25번 24~31번 적용, 3차 B1). **2026-11-20 다시 꺼짐(26번 3차 G):** 사용자 결정 '아바타 전(v1)이 더 낫다 — 얼굴·몸은 그대로 두고 머리·옷만 바꿔야'로 따로 둔 스위치 `avatarV2Enabled = false`(`lib/avatar_v2.dart`, `avatarV2On = avatarV2Enabled && avatarV2Ready`). v2 그림·23번 바탕은 지우지 않고 보관. 다음: 25번 42번(v1 얼굴·몸 그대로 머리·옷만 지운 맨 바탕) + 43~49번(그 몸에 '입은 모습'으로 다시 그린 머리·모자·상의·하의·신발·앞치마·소품·도구, `_back`·`_front` 조각 포함)이 오면 `avatar_v2/` 그림을 바꾸고 점검 시트를 통과한 뒤 스위치를 켬. 24~30번(v2용) 아이템은 v1 몸에 옮겨 보니 머리·어깨 크기가 달라 '입은 느낌'이 나지 않아 쓰지 않음(사용자 요구 2026-11-20 '스티커가 아니라 입은 느낌'). 그리기 코드는 이미 몸 뒤 조각(`_back`)·맨 앞 조각(`_front`, 도구 쥔 손가락)·모자 아래 머리 지우기(`hairmask`)·머리 모양 바탕 지우기(`basemask`)와 순서 `rigV2Order`를 지원. 사장님 칸 아이콘(`cosmetic_icons/girl·boy.png`)은 v1 얼굴로 되돌리고 `avatar_v2.py icons`는 사장님 아이콘을 만들지 않음. 저장 형식은 v1과 같은 id라 이전 작업 없음. **2026-11-20 다시 켜짐(26번 3차 AV, DEC-149):** 바탕 = 25번 42번 확정 바탕, 아이템 = 43~49번(122장, 모두 점검 시트 통과·숨김 0) + 41번 황금 뒤집개 → `avatarV2Enabled = true`.
- **v2 그리기 순서(`rigV2Order`):** behind(머리 뒤 조각) → base → eyes → mouth → bottom → shoes → top → outfit(앞치마) → **hair** → hat → accessory → tool → front. 표정 파츠는 바탕 바로 위(앞머리가 눈 위를 덮음), 앞치마는 상의 위(요리사 복 위 앞치마 가능).
- **모자와 머리:** 모자마다 `hat_<id>_hairmask.png`(도구가 모자 실루엣으로 만듦). 그리기 때 **머리 레이어에서만** 그 영역을 지움(`RigSprite.erase`, saveLayer 안 dstOut). 바탕·뒤 조각은 안 지움(묶은 머리 꽁지는 모자 뒤로 남음). 규칙 `avatar_v2.json` `hat_hair`: 기본 `cover`(모자 열에서 모자 아랫선 위의 머리 지움), `earmuffs`는 `band`(귀마개 자리만), `keep` 상자로 예외.
- **v1 맨 바탕 확정(25번 42번, 2026-11-20, DEC-147):** 생성 시안 그대로(얼굴·몸 v1 픽셀 복원 안 함) + 회색 머리 덮개만 맨머리로 지움 → `4_image_generation_results_and_backups/26_feedback_generated/42_v1_bare_base/normalized/<girl·boy>/base_skin1~3.png`(1120×2080, 발바닥 2079행, 눈 여자 (613.25, 687.75)·남자 (605.75, 680.5), 입 여자 (612.5, 814.5)·남자 (603.5, 797.5), `normalized/report.json`). **26번 3차 AV에서 게임 바탕으로 넣음**(`avatar_v2/<성별>/base@skin1~3.png`, 23번 v2 바탕은 4_image에 보관): 280×520으로 줄인 뒤 눈을 v1 앵커에 맞춰 평행 이동(여자 (0,−17)·남자 (0,−14)) — v1 사장님이 서던 자리·크기 그대로, 발바닥 여자 502·남자 505행. 표정 앵커는 v1 값 유지.
- **표정 파츠:** skin1 바탕에서 만들고(26번 3차 AV: 눈 상자는 v1 상자 근처의 눈 덩어리 크기 + 2px로 다시 잼 `eye_box`, 틀은 앵커에 걸림) skin2·3은 바탕끼리의 색 비율로 피부만 바꿈: `avatar_v2/<성별>/face_<eyes_half·eyes_closed·mouth_small·mouth_wide>@<skin>.png`. 앵커는 v1과 같음(`avatarV2FaceAnchors`: 여자 눈 153.5,155·입 152,184 / 남자 눈 151.5,156·입 150,184).
- **보이는 조건:** v2가 켜지면 `avatarArtReady`가 v2 파일 기준(새 하의 6종 포함). 꺼져 있으면 v1 규칙(새 하의는 그림이 없어 숨김). v1·v2 공통으로 `withdrawnAvatarItems`(`cosmetic_config.dart`, 캐릭터별)에 있는 아이템은 상점·꾸미기에서 숨기고(보유해도 `workshop_page.dart` `listed`에서 빠짐) 입고 있어도 그리지 않음 — 지금 없음(26번 3차 AV로 황금 뒤집개 해제).
- **3차 피드백 적용 보정(2026-11-19, `tools/avatar_v2.py`):** ① 24~30번 원본은 정규화 전 바탕 캔버스(880×1787)에 그려져 와서, 그 크기의 원본은 성별 바탕과 같은 배율·이동(`23_avatar_base/normalized/report.json`)으로 1120×2080에 놓은 뒤 줄임(`RAW`, `to_4x`). ② 아이템만 그린 원본(바탕을 절반 넘게 덮지 않음)은 '바탕과 같은 픽셀 지우기'를 하지 않음(베이지 반바지·흰 모자에 구멍이 나던 문제). ③ `bare`: 바탕의 회색 머리 덮개는 이마선(`BARE['forehead']` 108행) 위 회색·외곽선만 지우고, 회색 민소매·속바지와 그 경계선은 그 피부톤의 피부색 한 가지로 칠함(머리·상의·하의는 늘 입으므로 회색 자리표시가 비치지 않게). ④ `basemask`: 머리 모양마다 `hair_<id>_basemask.png` — 그 머리가 덮지 않는 귀 위(138행 위)·얼굴 타원 밖의 피부가 아닌 바탕 픽셀을 바탕에서 지움(`avatarV2BaseMask`, 선택 파일, 없으면 바탕 그대로). ⑤ 머리 레이어 가장자리의 흰 배경 찌꺼기 제거(`despeck`). ⑥ 신발은 바탕 발바닥 선에 맞춰 올림(남자 신발이 약 16px 아래로 그려져 캔버스 아래에서 잘리던 문제, `SOLE_SLOTS`). ⑦ 안경은 상자 가운데를 눈 앵커에 맞춤(입 위에 그려져 옴, `ON_ANCHOR`). `--only=<칸>`으로 그 칸 아이템만 다시 만듦.
- **43~49번 적용 보정(26번 3차 AV, `tools/avatar_v2.py`):** 원본 폴더 `FOLDERS`(43_hair_v1 … 49_props_v1, 황금 뒤집개는 `EXTRA_FOLDERS` 41_gold_turner, 바탕 `BASE_DIR` 42_v1_bare_base). ① 880×1787 원본은 확정 바탕을 그 크기로 줄인 캔버스에 그린 것으로 보고 1120×2080으로 늘림(`STRETCHED`; 크기가 다른 남자 세이지 니트는 `STRETCH_FIX`). ② 그림마다 옆 어긋남(3~16px)을 모양으로 가운데 맞춤 `CENTER`/`CENTER_ITEM`(sym 좌우 대칭·crown 정수리 16줄·hand 손가락 조각 상자 가운데를 주먹(몸에서 떨어진 팔의 아래 22줄)에·follow 다른 그림 따라·anchor 안경), `_back`·`_front`는 본 그림과 같이 움직임, 결과 `avatar_v2.json` `centred`. ③ `ITEM_SHIFT`: 남자 반바지 (0,−6)·와이드·갈색 바지 (0,−5)(허리를 니트 밑단에). ④ `defringe`: 바깥 테두리 중 안쪽보다 45 이상 밝은 무채색 픽셀 2겹 지움. ⑤ 모자 `hairmask`는 모자 모양 그대로(테두리 없음), cover 모자는 모자 옆 열도 가장 가까운 모자 열의 아랫선 위 머리를 지우고(`HAT_SIDE_KEEP` 0), 뒷머리에도 적용. `hat_<id>_basemask.png`: 그 영역의 모자 밖 맨머리를 바탕에서 지움. ⑥ `basemask`(머리): 앞머리만 기준, 머리 줄 폭·열 정수리 안쪽은 남기고 바깥으로 삐져나온 맨머리만(이마 상자 `forehead_row` 118 아래). ⑦ `slim`: 바지·신발(`SLIM`) 옆 3px 안 다리 픽셀을 손 아래(372행)·밑단 위에서 바탕에서 지움 → `<slot>_<id>_basemask.png`. ⑧ `skinned`: `tool_<id>_front.png`(손가락)를 피부톤별 `@skin1~3`로. ⑨ `pose`: 39번 `pose_proud_arms@skin1~3.png`·`pose_proud_hide.png`(가림은 대칭 가운데 맞춤 + 팔이 몸에서 떨어진 230~430행의 몸 바깥 전부 + 2px + 26번 3차 AV2 `pose_remnants`: 바탕·상의·앞치마·소품에 떨어져 남은 60px 미만 조각과 216~300행 몸통 옆 14px 밖). 25번 50번 소매 `pose_proud_sleeve_<top>.png`(상의마다 한 장, 피부톤 무관): 소매 두 조각을 따로 든 팔 모양에 크기·위치를 찾아 맞춤(`sleeve_fit`, 결과·원본 sha는 `avatar_v2.json` `sleeve_fit`, 반팔 `SLEEVE_SHORT`는 긴팔 크기 가운값으로 위치만), 손·붕어빵 상자 `SLEEVE_HANDS`에서는 지우고 경계에 한 단 어두운 단(`SLEEVE_HEM`), 어깨 끊긴 곳 `SLEEVE_FILL` 48px(4배) 안 맨팔은 소매 색으로 덮음, `SLEEVE_HELD`에 넣은 상의는 내보내지 않음(지금 없음). ⑩ `bare`의 머리 덮개 지우기는 끔(`BARE['cap']`, 42번은 이미 맨머리). 그리기: 바탕은 입은 아이템마다 있는 `<slot>_<id>_basemask.png`로 지우고(`avatarV2ItemBaseMask`), 반쪽 조각은 `@<skin>` 복사본이 있으면 그것. 자랑 포즈(`AvatarRig.proud`)는 든 팔 다음에 입은 상의의 `avatarV2ProudSleeve`를 맨 앞(front)에 그림(그림이 없거나 상의 없음·회수면 맨팔).
- **점검 시트:** `AVATAR_CHECK_TAG=<이름> flutter test tools/preview_avatar_check_test.dart` → `build/avatar_check/<이름>/`: 남녀 × 피부톤 3 × 모든 아바타 아이템(기본 차림 위 하나씩), 머리×모자·머리×소품·머리×도구·머리×앞치마·상의×앞치마·하의×신발·하의×앞치마 조합, 기본 차림 확대. 빨간 칸은 상점·꾸미기에 안 나오는 아이템. `AVATAR_CHECK_V2=1`이면 v2가 꺼져 있어도 v2로 그림.
- **아이콘:** 머리·모자(`WORN_ICON_SLOTS`)는 `tools/avatar_v2.py wornicons`(icons 작업과 함께 돎)가 **입은 레이어 그 자체로** 만듦(26번 3차 AV3d, 사용자 '헤어는 왜 스타일마다 크기가 달라?' → '머리만, 마네킹 없이'): 머리 = 뒤 조각 + 앞 조각, 모자 = 모자(뒤 조각은 모자에 닿을 때만 — 크림 두건 매듭처럼 떨어진 조각은 뺌), 몸·머리·얼굴 없이 투명 바탕. **칸·성별마다 배율 하나**(그 칸에서 가장 큰 아이템이 64×64 안 60px을 채움, 각 아이템은 가운데) → 같은 성별의 머리 스타일은 모두 같은 크기. 줄이기: 곱한 알파(premultiplied) Lanczos → 알파 110 이상만 남김 → 3×3 다수결로 가장자리 다듬기·6px 이하 구멍 채움(가장 가까운 색)·4px 미만 조각 지움(`ICON_ALPHA`·`ICON_PINHOLE`·`ICON_SPECK`), 바깥 테두리 덧그리기 없음. 배율은 `avatar_v2.json` `wornicons`. 파일: 여자 = `cosmetic_icons/<id>.png`(성별 없이 부르면 이것), 남자 = `cosmetic_icons/boy/<id>.png`(머리·모자만, pubspec에 폴더 추가). 앱: `PixelSprites.cosmeticIcon(id, character:)`가 그 캐릭터 폴더의 것이 있으면 그것, 없으면 공용; 꾸미기·상점 칸(`CosmeticThumb`)은 지금 고른(입어 보는) 캐릭터를 넘김. 레이어가 바뀌면 `python tools/avatar_v2.py wornicons --src <26_feedback_generated>`로 다시 만듦. 상의·하의·신발·앞치마·피부톤·소품·도구는 남녀 공용 물건 아이콘: `icons`가 칸 단위로 그 칸 25번 31번 아이콘이 모두 있을 때만 `cosmetic_icons/<id>.png`를 덮어씀(머리·모자 칸은 건너뜀), 다른 절 그림의 아이콘은 `EXTRA_FOLDERS`의 `icon_<id>.png`(41번 황금 뒤집개), `brownpants`는 25번 51번 새 아이콘(짙은 갈색 골덴 일자, 26번 3차 AV2), 빼기 아이템은 `none.png`. 사장님(`girl`·`boy`) 아이콘은 v1 얼굴 그대로. (26번 3차 AV3 WIP의 `v1icons`(`avatar_v1art.V1_ICONS` 11종을 여자 입은 레이어에서 잘라 칸마다 꽉 채움)는 지움 — 그 칸들은 31번 아이콘으로 되돌림.)
- **바탕 정규화(25번 23번 확정본):** 생성 바탕(약 880×1787)은 먼저 `python tools/normalize_avatar_base.py`가 성별마다 skin1 하나의 균일 배율 + 평행 이동으로 1120×2080에 놓음(발바닥 마지막 행 2079, 두 눈 중심 = 4배 앵커, 입은 따라감·오차 기록). skin2·3은 skin1 모양에 자기 피부색만 칠함(채널별 선형 맞춤) → 세 장은 피부 픽셀만 다름. 결과 `4_image_generation_results_and_backups/26_feedback_generated/23_avatar_base/normalized/<성별>/base_skin1~3.png`·`report.json`·`compare.png`. 2026-11-19 값: 여자 배율 1.1460, 남자 1.2365, 입 오차(게임 px) 여자 (1.75, 1.25)·남자 (1.5, 3.38), 눈 0.25 이하, 발 0.
- **도구 순서:** `python tools/avatar_v2.py --src <26_feedback_generated>` = align(`42_v1_bare_base/normalized/` 1120×2080 → 280×520, 측정 눈(`report.json` `landmarks_280x520`)을 v1 앵커로 평행 이동, skin2·3은 skin1과 같은 이동) → items(늘림·가운데 맞춤·테두리, 바탕 피부 위 피부색은 경고) → bare → basemask → hairmask → slim → skinned → pose → face → icons(+ wornicons) → trim → atlas(파일 목록·`avatarV2Ready`, 그림이 있으면 pubspec에 `avatar_v2/` 추가). 규격이 다른 원본은 '규격 미달'로 건너뜀. `--demo`는 v1 그림으로 만든 대역으로 도구만 점검(build/에만 씀). `faceaudit`은 얼굴 좌우 폭(G3) 검사.

**포즈(`RigPose`)**

| 포즈 | 그림 | 얼굴 보기 | 아이템 |
| --- | --- | --- | --- |
| front | `avatar/<character>/base.png` | front | 그림 |
| cook1~6 | `cook/<character>_1~6.png` | side | 안 그림(프레임에 옷이 그려져 있음) |

얼굴 기준점은 `avatarFaceAnchors[포즈 그림]['eyes'·'mouth']`입니다. 없으면 얼굴 프레임을 그리지 않고 그림 속 얼굴을 그대로 둡니다. cook1~6 기준점은 26번 4-2단계에서 조리 컷을 옮긴 만큼 같이 옮김(`tools/align_cook_cuts.py`가 `tools/avatar_layers.json` anchors를 고치고 `avatar_layers.py write`로 생성 파일 갱신, 얼굴 측정 상자 `FACES['girl_side']`도 2번 컷 이동 (+5, −2)만큼 옮김). 여자 4·5·6번은 25번 10번에서 1번을 기준으로 다시 그린 그림(뒤집기·뚜껑 열기·집게로 꺼내 담기)으로 바꿈 — 탭하면 보이는 꺼내기 컷은 6번째(`CookCutPainter.tapFrame` 5, DEC-139)(2026-11-19, `python tools/align_cook_cuts.py --import <10_cook 폴더>`: 1254→511(1.01배)로 줄여 발·머리·작업대를 1번에 맞춤 — 머리 차이 ±1px, 기준점은 1번의 눈·입 상자를 찾아 잼, 결과 json `redraws`). 남자 사장님 조리 컷(3.3 `cook/boy_1~6.png`)은 아직 앱에 없고(`cookCharacters = ['girl']`) 옮길 값만 json `boy`에 저장.

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
| talk | mouth: small 90 → wide 110 → small 80 → closed 70 → wide 100 → small 90 → closed 120 (ms, 반복) | 손님이 와 있는 동안 조리 장면 사장님(`CookCut.greeting`), 인사하는 손님 (꾸미기 미리보기는 26번 4-5단계 G2부터 눌러도 말하지 않음, 눈 깜빡임만) |
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

- 시간 설정이 밤이면 배경과 상관없이 night 분위기가 됩니다. 26번 4-6단계부터 모든 분위기가 같은 곡이라 소리는 바뀌지 않고, 분위기가 바뀌어도 곡을 처음부터 다시 틀지 않습니다(`AudioplayersAudio`가 불러 둔 파일 경로를 비교).
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
- 신규 Workshop의 황금 쓰는 곳(26번 3단계): 꾸미기(유료 아바타)와 5단계 이상 스킬. 상점(`ShopPanel`, Workshop 경로)은 **꾸미기 탭으로 열리고**(구형 경로는 장비 탭; 26번 4-5단계부터 Workshop 상점은 꾸미기·충전 두 탭, 꾸미기 탭은 사고 바로 입는 곳, 모든 Workshop 창 위 잔액 줄 황금 옆 '+'가 충전 목록), 충전 탭에 '황금붕어빵력 쓰는 곳: 꾸미기(옷·모자·머리·도구)와 높은 단계 스킬…' 한 줄(`gold-uses`), 약관 줄은 '황금붕어빵력 잔액은 로그인한 카카오 계정에 보관돼요.'(구형 경로의 '꾸미기와 스킬 해금은 돌아와요'는 Workshop에서 쓰지 않음). 메뉴 '로그인·보상 확인' 뒤 잔액이 늘면 '황금붕어빵력 N개를 받았어요. 꾸미기에서 써 보세요.' 알림(환영 황금 안내). 이미 황금으로 1~4단계를 산 사용자는 환불 없이 그대로(DEC-062). **충전 탭 모양(26번 3차 H31, `GoldChargeTab`·`GoldPackCard`·`GoldPackArt`):** 맨 위 황금색(보상) 잔액 카드(아이콘 34 + '보유 황금붕어빵력' + 큰 'N개', `gold-balance`), 로그인 전이면 파란 안내 줄 '로그인하면 충전할 수 있어요'(`gold-offline`), 쓰는 곳 한 줄, 상품마다 카드 한 장(왼쪽 60×60 황금 타일에 상품 그림, 가운데 '황금붕어빵력' + 큰 숫자 '330 개', 오른쪽 꿀색 버튼에 Play 가격·없으면 '구매할 수 없음' 흐린 버튼, `gold-pack-<id>`). 상품 그림은 `ui/gold_pack_1~5.png`(128×128, 25번 40번 생성 그림을 `tools/apply_25_art.py --only packs`로 적용 — 한 개·세 개·더미·봉투·보물상자, 그린 부분 긴 변 100·108·114·118·122로 큰 묶음일수록 조금 크게), 파일이 없으면 황금 붕어빵 아이콘을 1~5개 쌓은 임시 그림(4·5번은 반짝 표시).

---

## 9. 온라인: 로그인·랭킹·친구·초대

- 온라인 기능은 **Android 빌드에 키 5개가 모두 들어 있을 때만** 켜집니다. 이런 빌드는 첫 실행에 로그인을 반드시 거칩니다(아래 "첫 실행 로그인"). 구글 로그인은 선택 키 `GOOGLE_SERVER_CLIENT_ID`가 있을 때만 버튼이 보입니다. 아니면 오프라인 게임으로 동작합니다. 키는 `--dart-define-from-file=dart_defines/online.json`으로 넣습니다(13장 "온라인 빌드").
- 서버 지역은 `asia-northeast3`(서울), 런타임은 Node 22입니다.
- 운영 설정(Firebase·카카오·Play 결제·App Check)을 처음부터 하는 순서는 [online_setup.md](online_setup.md)(23번 7단계, 초보자용)입니다.
- **사용 통계(26번 5단계):** Firebase가 켜진 빌드는 로그인 여부와 상관없이 Firebase Analytics로 이벤트 7종을 보냅니다(기본 켬, 설정에서 끔). 서버 함수·Firestore는 쓰지 않고 Google Analytics 콘솔에서 봅니다. 자세한 내용은 32장, 콘솔 설정은 [online_setup.md](online_setup.md) '사용 통계'.

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

**카카오** (`FirebaseOnlineBackend.signIn(LoginProvider.kakao)`)
1. 카카오톡 로그인을 시도하고, 안 되면 카카오 계정 페이지로 로그인합니다.
2. 서버 `authKakao`가 카카오 토큰과 app_id를 확인합니다. 닉네임과(동의 항목 `account_email`에 동의했고 카카오가 확인한) 이메일을 받아 이메일은 `accountProfiles/{uid}.email`에 둡니다(`rememberEmail`).
3. uid를 `kakao:<회원번호>`로 정한 커스텀 토큰(`provider: kakao`)을 돌려줍니다.
4. Firebase에 로그인합니다.

**구글** (26번 2-1단계, `google_sign_in` 7.2.0)
1. `GoogleSignIn.instance.initialize(serverClientId: GOOGLE_SERVER_CLIENT_ID)` 후 `authenticate()`(Credential Manager 계정 선택).
2. 받은 ID 토큰으로 `FirebaseAuth.signInWithCredential(GoogleAuthProvider.credential(idToken))`. uid는 Firebase가 만든 값(28자 영숫자).
3. 서버는 토큰의 `email`(확인된 것만)을 `accountProfileSet` 때 저장합니다.

**서버 검사** (`functions/src/auth.ts` `signedIn`·`signedInAccount`): `sign_in_provider`가 `custom`이고 `provider: kakao`이거나, `google.com`이면 통과. 익명·이메일·애플 등은 거절. 지갑·구매·랭킹·친구 문서 키가 모두 uid 그대로라(`development_contracts`는 `encodeURIComponent(uid)`) 구글 uid도 바뀌는 것 없음. 같은 사람이 두 방법을 쓰면 **계정이 둘**(연결은 후속 과제). 서버 `.env`에는 `KAKAO_APP_ID`가 필요합니다(구글은 서버 설정 없음).

**첫 실행 로그인** (26번 2-1단계, `lib/owner_account.dart` `OwnerAccount.step`)

| 순서 | 화면 | 조건·저장 |
| --- | --- | --- |
| ① 동의 + 로그인 | 앱 이름·붕어빵 그림(카드 위) / 전체 동의 / (필수) 이용약관 [보기] / (필수) 개인정보 수집·이용 [보기] / (필수) 만 14세 이상입니다(키 `consent-age`) → '카카오로 시작하기'·'Google로 시작하기'(필수 셋 다 체크해야 로그인, 전체 동의는 셋을 함께. 체크 전에는 흐리게 보이고, 누르면 로그인 대신 아래 작은 빨간 글 '필수 항목에 모두 동의해 주세요' — 26번 3차 H4). 만 14세 이상을 체크하지 않은 동안 그 아래 작은 글 '만 14세 미만은 지금은 이용할 수 없어요.'(키 `first-run-child-notice`, 처음엔 회색, 체크 없이 로그인을 누르면 빨강). '처음 고른 방법으로 계속 로그인해 주세요…', 약관·방침 전문 링크 | 누르면 먼저 인터넷 확인(`lookupInternet`, DNS 4초). 없으면 ② 대신 오프라인 화면. 이미 로그인한 사용자(업데이트 전 카카오 로그인)는 로그인 버튼 대신 '동의하고 계속하기'. 다른 계정이 이 기기 가게의 주인이면 로그아웃시키고 '이 기기의 가게는 다른 ○○ 계정에…' |
| 오프라인 | '인터넷 연결이 필요해요' + '다시 시도' | 로그인 전에만. 로그인 뒤에는 Firebase 세션이 기기에 남아 오프라인 플레이 |
| ② 사장님 이름 | 한 줄 입력칸(높이 약 46, 글자 수 표시 없음, 로그인 닉네임에서 허용 글자만 남긴 값이 기본값, '사장님' 꼬리말), 그 아래 '설정에서 언제든 바꿀 수 있어요'만, 작은 '다음' 알약 버튼. 규칙(2~8자·글자 종류·금지어)은 '다음'을 눌러 틀렸을 때만 칸 아래 작은 빨간 글(키 `owner-name-problem`), 다시 입력하면 사라짐(26번 3차 H4·H5) | `OwnerNameRules`(아래) |
| ③ 사장님 고르기 | 여자/남자 사장님 그림 두 장(`AvatarPainter`), 지금 입은 캐릭터가 기본 선택 | `equipAvatar('girl'/'boy')` |
| ④ 선택 정보 | 성별(여성·남성·선택 안 함)·연령대(14~19세~50대 이상·선택 안 함, 만 14세 미만 항목 없음), 수집 항목·목적·보관 기간 상자('Google(미국) 서버로 보내져 14개월 보관' 포함), (선택) 동의 체크. '건너뛰기'와 '저장하고 시작'이 같은 크기 | 동의 체크·두 값을 골라야 저장 켜짐 |
| 끝 | 게임 + 2단계 첫 실행 안내 | 알림 권한 질문(5-1)은 안내가 끝난 뒤 그대로 |

온라인 설정이 없는 빌드(개발용)는 ①·④ 없이 ②·③만. 테스트용 `GameApp`에 `owner`를 넘기지 않으면 바로 게임.

**첫 실행 화면 모양** (26번 3차 H2~H5, DEC-131, `lib/ui/first_run.dart` `FirstRunBackdrop`·`FirstRunCard`·`FirstRunButton`·`FirstRunStyle`): 네 화면(+오프라인) 모두 같은 틀. 뒤는 겨울 노점 그림 — `ui/first_run.png`(416×945 불투명 256색, 노점 밖에서 본 눈 오는 밤 포장마차, 25번 37번 생성 그림을 `tools/apply_25_art.py --only firstrun`로 적용)가 있으면 그것, 없으면 홈 배경 `bg_low/<firstRunBackground>`(`feedback_config.dart`, 지금 `snow` 눈 오는 밤 노점)를 화면에 꽉 차게(아래 맞춤, 도트 그대로) + `WeatherLayer` 눈 내림(모션 줄이기·시스템 애니메이션 끔이면 멈춤) + 검정 16% 막. 그 위 가운데(세로로 남는 공간 가운데, 길면 스크롤) 폭 최대 400·좌우 여백 20의 밝은 카드(크림 97%, 모서리 20, 테두리 없음) 하나에 제목(20)·한 줄 설명(13)·내용. 버튼은 높이 44 둥근 알약(주 버튼 주황 `Cozy.amber` 채움·흰 글자 16, 보조는 흰 바탕·옅은 테두리), 최소 폭 132, 화면 가운데(선택 정보의 '건너뛰기'·'저장하고 시작'만 반씩 같은 크기). 로그인 화면만 카드 위에 붕어빵 그림(72, 높이 700 미만 화면 48)과 앱 이름(크림 32, 짧은 화면 26, 어두운 번짐 그림자). 캐릭터 카드는 흰 바탕·옅은 테두리, 고르면 주황 2px 테두리·연한 크림, 그림 높이 170. 선택 정보 칩은 작은 알약(고르면 주황 채움). 골든 `test/goldens/first_run_{login,name,name_error,character,optional}_{390x844,360x800}.png`·`first_run_login_360x640.png`

**사장님 이름 규칙** (`config/owner_name_rules.json`, 앱 `OwnerNameRules`, 서버 `account.ts` `cleanOwnerName`): 한 글자씩 세어 2~8자, 완성형 한글·영문·숫자만(빈칸·기호·자음만 불가), 다른 사람과 겹쳐도 됨, `banned_words`(욕설·운영자 사칭 등 간단한 목록, 대소문자 무시 포함 검사)는 앱만 검사. 이름은 기기 기록 + 서버 `accountProfiles`, 친구·랭킹에는 `profileSet`으로 `GameController.ownerName`이 감(없으면 예전처럼 로그인 닉네임).

### Firestore

**클라이언트는 아무것도 읽고 쓸 수 없습니다**(`firestore.rules`가 전부 거부). 모든 데이터는 서버 함수만 다룹니다.

주요 컬렉션:
- `users/{uid}`(+ `ledger`, `entitlements`)
- `purchases`
- `inviteProfiles`, `inviteCodes`, `players`, `inviteTickets`, `inviteAccepts`, `inviteEvents`
- `friends/{uid}/list`, `visitsSent`, `visits/{uid}/inbox`
- `rankings/{board}/entries`, `rankingSubmits`
- `accountProfiles/{uid}` (26번 2-1단계): `provider`, `name`, `email`(있을 때), `requiredConsent{version, atMs, over14}`(`over14: true` = 만 14세 이상 확인, 36장), 선택 동의 시 `optionalConsent{atMs}`·`gender`·`ageBand`, `updatedAtMs`. 문서를 통째로 다시 쓰므로 예전 `guardianConsentAtMs`·`under14`는 다음 저장 때 사라짐

### 서버 함수 (`firebase/functions/src/index.ts`)

| 함수 | 역할 |
| --- | --- |
| authKakao | 카카오 토큰 → Firebase 토큰(+ 동의한 이메일 기억) |
| accountProfileSet | (26번 2-1단계) 사장님 이름·필수 동의 판·선택 정보 저장. 선택 정보를 안 보내면 지움. 동의 판이 `2026-11-19`가 아니면 `consent-required`, `over14Confirmed: true`가 없으면 `age-required`(둘 다 `failed-precondition`), 연령대 `under14`는 `invalid-argument`(36장) |
| accountDelete | (26번 2-1단계) uid로 된 문서 전부(`users/{uid}`·인코딩한 `users/{…}` 하위 전부, 친구 양쪽·하루 방문 표시, 내 아이디 코드·최근 초대 링크, 방문함, 초대 기록, 프로필, 랭킹 3개, `accountProfiles`)와 Firebase 인증 사용자 삭제. 결제 기록 `purchases/*`만 법정 보관. 다시 불러도 안전 |
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
| 스페셜 붕어빵 무대 | **26번 3차 피드백(37장): 틀은 조리 컷·카운터 윗변보다 8 위로 올라가고(H18), 영업 준비 빈 틀에 붕어빵을 그리지 않으며(H20), 맛 드롭다운 대신 HUD 왼쪽 위 맛 버튼(H26), 시작 버튼은 빈 틀 가운데.** HUD 아래 중앙. 배경에 그려진 붕어빵 자리에 맞춤. 영업 상태별(DEC-035, 아래 "두 틀 규칙"): 영업 준비 중 빈 틀 + 맛 선택 + '스페셜 붕어빵 제작 시작'(버튼 아래끝 = 판매 카운터 윗변 − 60, 가운데 뜬 카운터 버튼 위 10. 24번 4단계의 − 4를 26번 4-1단계에서 바꿈(`WorkshopHomeLayout.practiceLift`). 행주 값이 없는 배경이면 예전처럼 틀 아래 경계에 걸침), 영업 중 세션이 없으면 틀 없이 떠 있는 큰 붕어빵(클리커. 예전 구도: 틀 자리에서 틀 높이×0.75 위. **새 구도(26번 4-1단계, 아래 '손님 표시')**: 틀 자리의 0.8배, 가로 가운데, 아래끝 = 판매 카운터 윗변 − 54(`WorkshopHomeLayout.clickerScale`·`clickerLift`), 손님은 그 뒤), 제작 세션 중에는 틀과 단계 조작. 새 영업일 이어서 영업 전에는 빈 틀만 | `workshop-center-stage`, `workshop-mold-action`, `workshop-clicker` | `ui/workshop_mold_stage.dart` `WorkshopMoldStage`·`WorkshopClicker` |
| 손님 표시 (새 구도) | **26번 4-1단계(DEC-095)**. 낮춘 배경 14장(`bg_low/`)이 모두 읽혔을 때만(`WorkshopHomeLayout.active` = `enabled` && `PixelSprites.lowStallReady`, S4-1-Q4) 켜짐. 손님 그림(256×320, `customer/<id>_<normal·happy·sad>`)이 매대 뒤에 서고 그림 아래끝 = 판매 카운터 윗변(행주). 맨 앞 손님은 가로 가운데, 폭 = min(w×0.46, 220)이고 (층 높이 − 88 − 122)/1.25 이하·112 이상(HUD를 피함), 카운터 윗변보다 88(`frontLift`) 위에 섬. 뒤 손님은 자리 순서로 (가로 ±0.62×앞 폭, 0.8배, 10 위) → (±0.3, 0.66배, 40 위)(`backPlaces`, S4-1-Q1 '맨 앞 크게 + 뒤 작게'). 줄 최대 = 일반 3 + 네임드 1(30장). 머리 위 남은 시간 막대(폭 0.46, 높이 7, 25% 아래면 벽돌색, 표정도 `sad`, S4-1-Q3). 판매 직후 기쁜 얼굴·시간 초과는 슬픈 얼굴로 1.5초 동안 맨 앞에서 흐려지며 떠남(`guestDeparture`, 메모리만, 모션 줄이기면 흐려짐 없음). 스페셜 붕어빵 제작 중에는 투명도 0.4. 그림 층은 무대 아래(터치 없음), 터치 영역은 무대 위의 같은 자리 머리 쪽 42%(클리커와 겹치면 클리커 윗변까지)이고 누르면 손님 창. 손님이 없으면 배경과 큰 붕어빵만. 주문 제작 결과의 손님 반응은 그 손님 머리 위 말풍선(`guest-reaction`, 머리 위끝에서 34 아래 걸침) | `customer-guests`, `customer-guest-taps`, `customer-N`(터치), `customer-art-N`, `customer-time-<주문 id>`, `customer-leaving`, `guest-reaction` | `ui/workshop_guests.dart` `WorkshopGuestLayer`, 수치 `ui/workshop_home_layout.dart` `WorkshopHomeLayout` |
| 손님 줄 (예전 구도) | 낮춘 배경이 다 없을 때만(`WorkshopHomeLayout.active` false). 무대 왼쪽, 폭 64, 위 48·아래 56 여백. 맨 앞이 위. 배지 52(이름 첫 글자, 남은 시간 고리, 맨 앞은 노란 면) + 맛 첫 글자·수량('N번'은 26번 4-1단계 F2에서 없앰). '맞이' 버튼은 **첫 실행 안내 중이고 줄이 비었을 때만**(26번 5-1단계 S5-1-Q2). 안내가 끝나면 손님은 실제 시간 시계로만 옴(30장). 줄은 일반 3 + 네임드 1까지. 23번 3단계 B안의 왼쪽 세로 줄은 새 구도에서 DEC-095로 대체됨 | `customer-queue`, `customer-N`, `customer-welcome` | `ui/workshop_counter.dart` `WorkshopCustomerQueue` |
| 판매 카운터 | 왼쪽 8, 폭 = w − 16 − (조리 컷 폭 + 8), **위 = 배경 왼쪽 빨간 체크 행주의 윗변**(DEC-038, 아래 "행주 윗변"), 높이는 내용대로. 행주 값이 없는 배경(장면 크기 픽셀 그림·새 배경)이면 예전처럼 아래 = 굽는 판 바닥 + 굽는 판 높이×0.66. 스페셜 붕어빵 제작 중에는 숨김. 버튼은 카운터 밖(아래 줄) | `sale-counter` | `WorkshopSaleCounter` |
| '오늘' 쪽지 (26번 7단계) | **오른쪽 위 설정(톱니바퀴) 버튼 바로 아래**(26번 시안 확인 2차, DEC-128): 윗변 = 설정 버튼 아랫변 + 6(`WorkshopHomeLayout.slipGap`), 오른쪽 끝을 설정 버튼에 맞춤. HUD가 글자 크기·스크롤로 움직여도 따라가게 `LayerLink`(설정 버튼 `CompositedTransformTarget`, 키 `home-settings` → 쪽지 `CompositedTransformFollower`)로 붙이고, 손님 터치 층보다 위에 그림. (예전: 조리 컷 오른쪽 위 끝.) 52×52 크림 판에 `icons/daily` 34만(3차 피드백 H36: 글씨 '오늘' 없음, 의미는 접근성 이름 '오늘: 출석 도장·오늘의 주문서·미션'), 출석 도장·오늘의 주문서가 남았거나 일일·주간 미션 보상이 있으면 오른쪽 위 빨간 점(13). 첫 실행 안내 중·스페셜 붕어빵 제작 중에는 숨김. 누르면 전체 창 '오늘'(`daily-card`): 행사 띠(행사 중) → 출석 도장 → 오늘의 주문서 → 일일 미션 → 주간 도전. 34장 | `daily-ticket`, `daily-ticket-dot`, `daily-card`, `attendance-stamp`, `attendance-box-N`, `daily-order-deliver`, `daily-order-bake` | `ui/workshop_daily_card.dart`, `NightHome.counterSlip` |
| 카운터 버튼 | **26번 4-1단계 F6(S4-1-Q6 '버튼만 화면 가운데')**: 카운터의 다음 행동 버튼 하나를 화면 가로 가운데에 띄움. 아래끝 = 판매 카운터 윗변 − 6(`actionGap`), 폭 160~260, 높이 44, 글자 17. 두 구도 모두 같음. **다음 행동이 영업 열기·닫기('영업 시작'·'이어서 영업'·'영업 종료')이면 여기에 그리지 않고 아래 '영업 버튼'으로**(26번 시안 확인 2차, DEC-128) — 그래서 영업 준비 중·손님 없는 영업 중에는 이 자리가 비고, 손님 판매·주문 제작·반응 확인·다시 확인만 뜸 | `counter-action`(안의 버튼 키는 아래 '판매 카운터' 표) | `WorkshopCounterAction` |
| 영업 버튼 | **26번 시안 확인 2차(DEC-128, '너무 큼 → 작게, 가운데가 아니라 상단으로')**: HUD 아래 줄 가게 상태 간판 바로 오른쪽(같은 줄, 간판은 남는 폭에서 줄어듦, 설정 버튼과 겹치지 않음). 높이 32(`WorkshopHomeLayout.businessHeight`, 나무 테두리 포함), 글자 Jua 14(`businessFontSize`), 좌우 여백 10, 글자 크기 1.2배까지. '영업 시작'·'이어서 영업'은 꿀색, '영업 종료'는 크림색. 스페셜 붕어빵 제작 중·다른 행동 차례에는 없음. 첫 실행 안내 7번째('영업 시작'을 눌러…)의 고리도 이 버튼을 가리킴 | `business-toggle`, 안의 `business-open`·`business-close` | `workshop_counter.dart` `WorkshopBusinessButton`, `NightHome.statusAction` |
| 가게 상태 간판 | **26번 3차 피드백 H17(37장)로 모양이 바뀜: 버튼과 다른 반투명 유리 간판 + 영업 중 빛나는 등불 점.** 예전(26번 4-1단계 F7): HUD 아래 줄 가운데 나무 간판(짙은 나무색, 주황 테두리 2, 둥근 12, 그림자), 앞에 점(영업 중 초록·영업 준비 회색), 글 Jua 16 크림색 '영업 중'/'영업 준비'('· 주문 N'은 없앰). 저장 오류면 벽돌색 간판 '저장 확인 필요'. 구형 홈의 `_note`(`home-prestige` 등)는 그대로 | `workshop-status`(글), `workshop-status-badge` | `night_home.dart` `WorkshopStatusBadge` |
| 숙련된 붕어빵 틀 칸 | 굽는 판 그림의 6칸 위. 굽는 판 폭 = w − 16(왼쪽 8), 높이 = 폭 × 그림 높이/폭(941×470), 그림이 상자를 꽉 채워 칸 위치·터치 영역도 같은 비율로 커짐(DEC-038). 바탕은 **빈 굽는 판 그림**(`assets/images/stove_empty/<화로>.png`, 25번 1번 생성 그림을 `tools/apply_25_art.py`로 원래 화로 위치에 맞춤: 칸이 붕어빵 모양 홈)이고, 굽는 칸에만 원래 그림의 붕어빵만 남긴 층(`stove_fish/<화로>.png`, 없으면 `stove/<화로>.png`)을 그 칸 자리(`griddleFishClips`)에서 잘라 겹쳐 그림(`GriddlePainter(filled:)`, `workshopGriddleFilled`). 홈 중심과 `griddleCavities` 차이는 그림 px로 가로 −9~+3, 세로 −3~+1(25번 1번). **판 그림 상태(26번 4-2단계 F8, DEC-099, `workshopGriddleOpen`)**: 영업 준비 중(새 영업일 이어서 영업 전 포함)과 숙련 전(잠김)에는 **닫히고 불 꺼진 판**(`stove_closed/<화로>.png` 941×470, `GriddlePainter(closed: true)`, 그림이 없으면 빈 굽는 판 위 검은 반투명 0.45), 영업 중 + 쓸 수 있음(숙련한 맛 있음, 또는 굽는 칸이 남은 옛 저장)이면 **열리고 불 켜진 판**: 바탕은 위의 빈 굽는 판 그대로(칸·붕어빵 층 그대로)이고 뚜껑은 굽는 판 상자 **위로** 따로 그림(`GriddleLidPainter`, 키 `griddle-lid`, 칸 높이 = 굽는 판 폭 × 230/941, 390 폭에서 약 91; `stove_open/<화로>.png` 941×700의 위 230 + 판 뒤 가장자리 186px까지를 그려 칸 아래로 굽는 판 상자 위쪽 투명 띠까지 내려감 — 25번 34번 낮게 젖힌 뚜껑은 그 띠에 누움, 굽는 판이 그 위에 덮임, DEC-139). 층 순서: 손님 그림 → 뚜껑 → 굽는 판 → HUD·무대 → 카운터·카운터 버튼·조리 컷이라 7번 세운 뚜껑은 대부분 판매 카운터·조리 컷 뒤에 가려졌고(S4-2-Q2 '가려지는 대로'), 2026-11-19 25번 34번 낮은 뚜껑으로 바꾼 뒤에는 카운터 아래·굽는 판 바로 뒤에 낮은 띠로 보이고 오른쪽 끝만 조리 컷 뒤. 굽는 판 상자·칸 위치는 상태와 상관없이 그대로. 영업 준비 중에는 칸을 하나도 그리지 않음: 닫힌 판 그림만, 글자·면·터치 없음(`griddle-idle`). 영업 중 빈 칸은 글자 없음: 누를 수 있으면(영업 중·세션 없음) 옅은 크림색 면(투명도 0.18)과 크림색 테두리(투명도 0.7, 두께 1.5), 누를 수 없으면(제작 중 등) 검은 반투명 면만. **숙련한 맛이 하나도 없으면**(26번 2단계, S2-Q2) 빈 칸 대신 (닫힌) 굽는 판 그림 전체에 공통 잠금(`griddle-locked`, 빗금 + 큰 자물쇠 + '팥을 숙련하면 열려요 (연습 n/m · 손기술 n/m)')을 덮고, 누르면 같은 글을 짧은 알림으로. 굽는 중인 칸(옛 저장)은 잠금 위에 그대로 그려 꺼내기·폐기 가능. 굽는 칸은 번호·익힘·'수확'/'폐기' 글자와 갈색(탄 칸은 검정) 면. 화면 읽기 라벨: 빈 칸 '숙련된 붕어빵 틀 N번 칸 굽기 시작', 굽는 칸 'N번 맛 익힘 · 수확/폐기' | `workshop-cell-N` | `WorkshopGriddleLayer` |
| 손님 창 | 손님(그림 머리 쪽 또는 예전 배지)을 누르면 뜨는 작은 창. 제목은 별명 전체(`customerName`, 'N번' 없음, 키 `customer-card-title`): 주문 줄(드린 수/주문 수), 대사, '이웃 이야기 확인', 맛별 '주문 제작'(영업 중·세션 없을 때만. 누르면 창을 닫고 그 주문 하나를 만드는 동안만 스페셜 붕어빵 틀이 나옴. 결과를 닫으면 다시 클리커). 카운터의 '맛 제작'(`order-produce`)도 같은 주문 제작 | `customer-card`, `customer-produce-<맛>` | `WorkshopCustomerCard` |
| 재고 창 | 카운터 글자를 누르면 뜨는 작은 창: 오래된 순 묶음(맛·익힘·개수·경과 영업일), 준비품 | `stock-card` | `WorkshopStockList` |

**두 틀 규칙 (DEC-035·036, 24번 3단계):**

| 상태 | 스페셜 붕어빵(큰 틀) | 숙련된 붕어빵(6구) |
| --- | --- | --- |
| 영업 준비 중 | 빈 틀, 맛 선택, '스페셜 붕어빵 제작 시작'(연습만). '+붕어빵력' 버튼 없음 | 빈 굽는 판 그림만(붕어빵·칸 글자·면·터치 없음) |
| 영업 중, 평소 | 틀 없이 떠 있는 큰 붕어빵(`FloatingFishPainter`). 둘레 반짝이 6곳은 따로 그리는 층(`TwinklingSparkles`, `FloatingFishPainter.sparkles`)이 1.2초 주기로 서로 다른 박자에 나타났다 사라짐(26번 4단계 F11, 아래 '반짝이'), 모션 줄이기면 멈춘 한 장면. 탭하면 `clickerTap` → `tap`(붕어빵력 +`tapRate`)과 탭 효과(눌림·작은 붕어빵 부스러기·'+N', 모션 줄이기면 멈춘 '+N'만, 진동 설정 시 80ms 간격 진동). 1초에 `server_validation.max_taps_per_second`(15)번을 넘는 탭은 효과만 보이고 '+N'·붕어빵력·탭 수 없음. 새 주문이 와도 틀을 다시 보이지 않음(예전 `orderFlash` 2.5초 삭제) | 지금처럼 동작 |
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
| 안내 글(`piping-amount`) | 틀 아래쪽 가운데. 아래끝 = 무대 아래 '제작 취소' 버튼(누르는 영역 48) 윗변 − 4(필요할 때만 올림, `captionLift`, 24번 6단계에서 버튼과 겹치던 것을 고침). 대기 '틀 위를 문질러 반죽을 부어 주세요' / '틀 위를 문질러 속을 짜 주세요'. 반죽 칠하는 중 '반죽 덮음 85% · 양 112% · 손을 떼면 마무리'(G5), 속 '속 양 72% · 손을 떼면 마무리'. 130% 초과면 끝에 ' · 넘쳤어요'. 위 캡션은 '팥 붕어빵 연습'/'팥 붕어빵 주문'만(26번 3차 피드백 H19, 예전 '팥 연습 · 반죽 목표 90% 이상 덮기 · 130% 넘으면 넘침'과 '현재 단계 경과') |
| 결과 글 (G6 → 26번 4단계 → 3차 피드백 H22·H24) | 반투명 띠 창(`mold-result-band`) 안에 별 줄(`mold-result-stars`, 37장)·등급 큰 글씨(`mold-result-grade`)와 칭찬·이유 한 줄(`mold-result-caption`). 이유는 `batterFailureLabel`(넘침이 우선)에서 '반죽이 넘쳤어요'·'반죽이 조금 모자랐어요'. 아래 '결과 등급·연출' |
| 모션 줄이기 | 짤주머니가 손가락을 따라가는 것은 직접 조작이라 그대로. 움직임에 따라 짤주머니가 기우는 연출만 끔. 판정 같음 |
| 진동(설정 켜짐) | 단계 확정 때 `selectionClick` 1회, 한 붓질에서 130%를 처음 넘는 순간 `mediumImpact` 1회 |
| 판정 (DEC-031) | 반죽 두 번 각각 덮은 면적 ≥ `batter_min_coverage_permille`(900) 그리고 양 ≤ `paint_overflow_amount_permille`(1300) + 익힘 `success_doneness_min_index`~`max_index`. 속은 판정 안 함(양·넘침만 표시). 예전 길게 누르기로 끝난 반죽 단계(저장의 `firstBatterMs`·`secondBatterMs`)는 손기술 실패(G1) |
| 센서 (DEC-033) | 기울기 센서 삭제: 스위치, `cooking_sensor_input.dart`·`cooking_tilt_source.dart`·`TiltDirectionGate`·`BatterHoldInput`·`BatterHoldButton`, Android `CookingTiltStream.kt`와 채널, `tilt_*` 설정 3개 |

**원 그려 뒤집기 (DEC-034, 24번 6단계) — 26번 3차 피드백 H21에서 '걸이 축 밀어 뒤집기'로 바뀜(37장). 아래 표는 예전 기록:** 뒤집기 단계에는 버튼이 없고 틀 둘레에 손가락으로 원을 그립니다(`lib/ui/flip_circle_control.dart` `FlipCircleControl`, 계산은 `lib/cooking_flip.dart` `FlipCircle`). 탭으로는 뒤집히지 않습니다.

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

**결과 등급·연출 (26번 4단계, 판정 DEC-031~034·040은 그대로):** 결과 화면(`CookingPhase.result`)은 등급을 보여 주기만 합니다. 손기술 판정(`evaluateCookingResult`)·숙련·재고·판매값은 바뀌지 않습니다. 계산은 `lib/cooking_result_rules.dart` `cookingGrade`, 화면은 `lib/ui/cooking_result_effects.dart` `CookingResultView`, 결과 그림은 `lib/ui/workshop_mold_stage.dart` `ResultLook`·`WorkshopMoldArt`.

| 등급 | 조건(위에서부터) | 큰 글씨 | 칭찬·이유 | 소리 | 화면 효과 | 진동 | 주문 손님 반응 | 결과 그림 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 완벽 | 손기술 성공 + 반죽 두 번 모두 덮음 ≥ `perfect_min_coverage_permille`(950)·양 ≤ `perfect_max_amount_permille`(1150) + 익힘 = `perfect_doneness_index`(2, 미디엄) | 완벽해요! | 겉은 바삭, 속은 촉촉! | `result_perfect`(바삭 + 작은 종 두 번) | 큰 글씨 300ms 튀어 오름 + 반짝 8 + 김 3줄 + 윤기 한 번 지나감 | `heavyImpact` | 와, 이건 사진 찍고 싶을 만큼 예뻐요! | 미디엄 색 + 윗면 윤기 |
| 성공 | 손기술 성공 | 잘 구웠어요! | 익힘별 '부드럽게/알맞게/바삭하게 잘 익었어요' | `result_good`(작은 바삭 + 종 한 번) | 작게 튀어 오름 + 반짝 4 + 김 2줄 | `mediumImpact` | 맛있어 보여요. 잘 먹을게요! | 익힘별 색 |
| 아쉬움 | 손기술 실패, 익힘은 성공 범위(1~3) — 반죽 부족·넘침, 예전 길게 누르기 저장 | 아깝다! | 반죽이 조금 모자랐어요 / 반죽이 넘쳤어요 / 조금만 더 하면 돼요 | `result_near`(부드러운 '퐁') | 김 1줄 | `lightImpact` | 그래도 맛있을 것 같아요. | 익힘별 색 + 넘침이면 반죽 방울 3개(`fx/overflow_batter`) |
| 실패 | 익힘 0(덜 익음) 또는 4(타버림) | 다음엔 더 잘할 수 있어요 | 덜 익었어요 / 타버렸어요 | `result_fail`('툭' + 짧은 치익) | 타버림만 회색 연기 2 | 없음 | 괜찮아요, 천천히 해 주세요. | 덜 익음 창백 / 타버림 진한 갈색 |

| 항목 | 규칙 |
| --- | --- |
| 익힘 색 (`ResultLook.filter`) | 덜 익음 채도 60%·밝기 +15%(+38), 부드러움 +6%(+15), 미디엄 그대로, 바삭함 R×1.02·G×0.88·B×0.66, 타버림 R×0.55·G×0.45·B×0.38. 큰 틀 결과 그림만(6구·재고 아이콘은 그대로) |
| 한 번만 | 소리·진동·효과는 결과마다 한 번(`CookingResultView.celebrated`에 세션 id, 메모리). 다시 그리거나 돌아와도 다시 울리지 않음 |
| 효과 | `AnimationController` 1개 1400ms, 입자 상한 12(`maxParticles`). 반짝이는 아래 '반짝이'와 같은 그림 |
| 모션 줄이기 | 설정 `reduceMotion` 또는 시스템 '애니메이션 제거'(`MediaQuery.disableAnimations`)면 효과·튀어 오름 없이 글·소리·진동만 |
| 소리·진동 설정 | 효과음 끔·음량 0이면 소리 없음(`SoundPolicy.play`), 진동 끔이면 진동 없음 |
| 주문 손님 반응 | `startOrderProduction`이 (세션 id, 주문 id)를 메모리에 기억(`_orderProductionFor`, 저장 안 함). 결과 때 그 손님이 줄에 있으면 결과 아래 말풍선 '이름: 대사'(`mold-result-reaction`, `WorkshopController.resultReaction`). 대사는 `config/customer_content.json` `common_dialogues`의 `result_perfect·result_good·result_near·result_fail`. 연습·앱 재시작 뒤·손님이 떠난 뒤엔 없음. 4-1단계가 손님 그림 위 말풍선으로 옮길 예정 |
| 저장 | 변경 없음. Workshop schema·`CookingSession` schema 1 그대로 |

**결과 등급 설정값(`config/development_balance.json` `cooking_grade`, 개발용 임시값):** `perfect_min_coverage_permille` 950, `perfect_max_amount_permille` 1150, `perfect_doneness_index` 2. 검사(`tools/development_balance.py`, `DevelopmentBalance.fromJson`): `batter_min_coverage_permille` ≤ 완벽 덮음 ≤ 1000 ≤ 완벽 양 ≤ `paint_overflow_amount_permille`, 모든 난이도의 `success_doneness_min_index` ≤ 완벽 익힘 ≤ `max_index`. 서버는 읽지 않음(`metadata.revision` 그대로).

**반짝이 (26번 4단계 F11):** 옛 `fx/sparkle.png`(21×21, 진한 외곽선 'UFO 같음')를 지우고 `lib/ui/sparkle_art.dart`로 바꿈. 떠 있는 큰 붕어빵·결과 효과·맑은 하늘 날씨(`Weather.sparkle`)·`BakeTarget`의 `fish-sparkles`가 모두 같은 반짝이를 씀.

| 항목 | 값 |
| --- | --- |
| 안 (`SparkleArt.style`) | A `star`(기본): 25번 12번 생성본 3프레임 `fx/sparkle_1~3.png`(32×32, 외곽선 없음, 흰 가운데 → 꿀색 #FDBE38) / B `glow`: 코드로 그린 꿀색 광채 / C `steam`: 김 한 줄 + 빛 알갱이. 비교 그림 `1_app_development/build/f11_sparkle_options.png`(골든 `test/goldens/sparkle_options.png` 복사본). 사용자 선택 전까지 A |
| 한 번 반짝임 | `SparkleArt.cycleMs` 1200ms: 0~20% 프레임1(처음 8% 서서히 나타남) → 20~45% 프레임2 → 45~70% 프레임3(끝 10% 사라짐) → 70~100% 쉼. 큰 붕어빵 6곳은 0.37주기씩 어긋난 박자 |
| 멈춤 | 모션 줄이기·테스트(`TwinklingSparkles.animate = false`, `test/flutter_test_config.dart`)면 `stillPhase` .32(가장 큰 프레임2)로 멈춤 |
| 그리기 | 초당 20번만 다시 그림. 큰 붕어빵 크기: 화면 짧은 변의 24%/16%(번갈아). 날씨는 장면 9px |

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
| `checkpoint_ms` | 1000 | 제작 중 저장 간격. 이 주기 저장 중에는 `busy`가 켜져도 화면은 `inputBusy`(= `busy && !_savingCheckpoint`)로 판단해 버튼·손님·6구 칸·클리커가 깜빡이지 않음. 저장 중 들어온 명령은 저장이 끝난 뒤 실행되고, 안내 문구(`notice`)는 사용자 명령에서만 지움(주기·수명 저장은 `keepNotice`). 26번 4-1단계 F1 |
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

**낮춘 배경 (26번 4-1단계 F5, 25번 20번):** 새 구도는 `assets/images/bg_low/<id>.png` 14장(335×762, 불투명, 구운 틀 없음, 매대·수저통·나무 상자가 행주 높이로 내려옴)을 씁니다. `python tools/apply_26_home_art.py <26_feedback_generated> --only backgrounds --measure`가 생성 원본을 335 폭으로 줄인 뒤 그림마다 잰 행주 윗변(`TOWEL_AT_335`, 335 폭 기준 460~576)을 524로 옮겨 만들어서, `towelTops`의 `bg_low/<id>`는 **모두 524**입니다(DEC-038 규칙 그대로, 값만 이 표에 더함). 행주가 524보다 위인 그림(clear·snowday·rain·seaside)만 키우고(왼쪽 끝 고정, 오른쪽 자름), 아래로 모자란 줄은 굽는 판 뒤에 가려지는 매대 앞면 줄을 반복합니다. 그래서 카운터 윗변 화면 값은 위 bg_clean/clear와 같습니다. 맑은 날은 `clear-v2`(25번 20번 'v2 우선'). 밤 그림이 없는 배경은 `lowStallBackground`가 낮 그림을 어둡게 그림.

**판매 카운터 (26번 4-1단계 F6):** 제목(Jua 16, 최대 2줄, 잘림·흐림 없음), 설명(12, 최대 2줄, 안내 문구가 있으면 벽돌색으로 대신, 키 `counter-notice`), 글자 크기 1.3배 상한. 다음 행동 버튼 하나는 카운터 밖 화면 가운데에 뜸(위 표 '카운터 버튼', 예전: 오른쪽 최대 폭 104). 손님 이름은 짧은 이름(`customerShortName`, S4-1-Q2: '도윤'·'막례 할머니', 무기명은 '일반 손님'), 남은 초는 글에서 빼고 손님 머리 위 막대로. 상태 순서:

| 상태 | 제목 / 설명 | 버튼 |
| --- | --- | --- |
| 저장 오류 | 저장 확인이 필요해요 | 다시 확인 (`counter-reload`) |
| 영업 전·새 영업일 | 오늘 영업 준비 / 새 영업일이 밝았어요, 재고·준비품 | 영업 시작 / 이어서 영업 (`business-open`) |
| 태오 사진 반응 | 태오 대사 | 반응 확인 (`photo-reaction`) |
| 손님 없음 | 마지막 판매 한마디 또는 '손님을 기다리는 중이에요', 재고 | 영업 종료 (`business-close`, 위 '영업 버튼' 자리) |
| 맨 앞 손님 | 짧은 이름 · 주문("도윤 · 팥 1/2") / "재고 3개" | 드릴 재고가 있으면 'N개 먼저 판매' 또는 '판매 완료'(`sale-button`), 없으면 '맛 제작'(`order-produce`) |

**메뉴 창 위 (26번 2-1단계):** 사장님 이름이 있으면 '○○ 사장님의 가게'(`menu-owner-name`). 이름이 보이는 곳은 이 한 곳.

**설정 창 맨 위 '계정' (26번 2-1단계, `lib/ui/owner_settings.dart` `OwnerSettingsSection`, `WorkshopPage(owner:)`가 있을 때만):** '사장님 이름: ○○' + '이름 바꾸기'(같은 규칙, 틀리면 창 안에 이유), '카카오/구글 계정으로 로그인 중', '성별·연령대 (선택): …' + '바꾸기'(첫 실행 ④와 같은 양식)·'지우기'(서버에서도 지움), 이용약관·개인정보처리방침(앱 안 `assets/legal/` 사본을 제목·목록·표 줄로 보여 줌, `test/owner_first_run_test.dart`가 문서 폴더 원본과 같은지 확인), '로그아웃'(확인 뒤 설정 창을 닫고 로그인 화면, 진행은 기기에 남음), '계정 삭제'(지워지는 것·되돌릴 수 없음 안내 + '위 내용을 확인했어요' 체크 뒤 '삭제하기', 인터넷 없으면 '계정 삭제는 인터넷에 연결된 상태에서만…'). '이름 바꾸기' 창도 첫 실행과 같은 입력칸·안내 한 줄·틀렸을 때만 칸 아래 빨간 글(26번 3차 H4). 첫 실행 골든은 위 '첫 실행 화면 모양'(`test/first_run_golden_test.dart`, 실제 글꼴).

**설정 창 '사용 통계 보내기' (26번 5단계, DEC-046, 키 `settings-usage-stats`):** 손님 알림 세 줄('밤 알림 끄기') 바로 아래, '배경 시간' 위. 아이콘 `Icons.insights_outlined`, 설명 '게임을 고치는 데 쓰는 사용 기록이에요(이름·계정과 연결하지 않아요)'(36장에서 '이름 없는' 표현을 바꿈), 기본 켬, 첫 실행 안내 없음(수집은 첫 실행 필수 동의 뒤부터, 36장). 끄면 `GameSettings.sendUsageStats=false` 저장 뒤 `setAnalyticsCollectionEnabled(false)`(저장에 실패하면 원래 값으로 되돌린 값을 Analytics에 알림). 계정 저장 v13 그대로(없으면 켬).

**메뉴 창 아래:** 황금붕어빵력 심사 대기 건수(`menu-pending-gold`), '로그인·보상 확인'(`menu-sync`), 영업 중이면 '영업 종료'(`menu-close-business`). 예전 "가게 관리" 시트는 없앴습니다. 레시피(슈크림·초코) 미션 받기는 레벨 미션 창, 맛별 연습·손기술 진행과 손님 취향 기록·이야기 다시 보기는 도감 창으로 옮겼습니다.

**메뉴 창 목록(Workshop):** 도감 · 업적 · 통계 · 배경 테마 · 일일 미션 · 주간 도전 · 레벨 미션 · 가게 사진 찍기(26번 8단계 공유 카드, 35장. 구형 화면 `GameApp` 메뉴에서는 `hidden:{'photo'}`로 뺌). 온라인 랭킹·친구·공유는 가출시 범위 밖이라 `MenuPanel(hidden:)`으로 뺌(DEC-029, 2026-11-16 5단계). 도감은 Lv.3 전까지 같은 방법으로 숨김(26번 2단계, 아래 "처음 5분 해금"). 배경 테마는 26번 2단계부터 Lv.8 전까지 숨겼으나 26번 3차 H42부터 `stall_background`(Lv.1)부터 보임.

**Workshop 창**(`showWorkshopWindow`, `lib/ui/workshop_windows.dart`, 키 `workshop-window`): 위 안전 영역 아래 화면 전체 높이. 위에서부터 잔액 알약, 제목 프레임(닫기 버튼), 내용. 잔액 알약(`workshop-balance`, 26번 4-5단계 F31·S45-Q4)은 `CurrencyAmount` 두 개(아이콘 24, 굵은 숫자 19: `balance-buns`·`balance-gold`)와 황금 옆 꿀색 '+'(`balance-gold-plus`, `onGold` → `WorkshopPage._goldPacks` 충전 목록). 제목 양옆은 25번 35번 붕어빵 `ui/title_fish` 48×36(왼쪽은 좌우 뒤집음, `title-fish-left`), 설정 창은 톱니 아이콘. 맨 아래 받침(`workshop-window-base`, 화면 폭 전체, 최소 높이 = `NightHome.navHeight` 66, 아래 여백 10 + 안전 영역) 가운데에 '돌아가기'. 받침이 홈 하단 메뉴를 완전히 덮어 버튼 옆으로 메뉴가 비치지 않음. 26번 3차 H41부터 받침은 연한 creamDeep + 위 가는 선(line), 닫기 버튼은 흰 동그라미 X(보이는 원 36, 위치는 3차 H38의 `CozyCloseButton.edge`), 창 안 오류·알림 줄은 `CozyNotice`(오류 경고색 `workshop-window-error`, 알림 안내색 `workshop-window-notice`). 홈 위 작은 창(`_popup`)은 반경 20.

**꾸미기·상점 역할 (26번 4-5단계, S45-Q1 B, `lib/ui/workshop_wardrobe.dart` `WorkshopWardrobe`):** 꾸미기 창(하단 '꾸미기', `WardrobeMode.wear`)은 **가진 것(무료 포함)을 먼저, 그 뒤에 파는 아바타 아이템(가격·잠김 표시)** 을 보여 주고 입어 보고·사고·입는 곳(3차 피드백 H15, 2026-11-19: '모두 사기'를 위해 파는 것도 꾸미기에 둠), 상점의 꾸미기 탭(`WardrobeMode.shop`, 키 `shop-wardrobe`)은 **아직 없는 아바타 아이템만** 보여 1건씩 사는 곳(잠긴 것도 눌러 입어 봄). '상점에서 더 보기'(`wardrobe-more-<slot>`)는 그 칸의 파는 것이 꾸미기 격자에 하나도 안 보일 때만 남음(지금은 나오지 않음). 상점은 꾸미기·충전 두 탭(Workshop에서 장비 탭 없음, 도구는 꾸미기의 소품 탭).
- 배치(위만 고정, 격자만 스크롤, 3차 피드백 H16): 책갈피 탭 줄(`cosmetic-category-<tab>`, `WardrobeTabRow(fill: true)`로 **탭이 폭을 나눠 가져 360 폭에서도 다섯 탭이 다 보임**; 탭 폭이 74(`WardrobePill.iconWidth`) 미만이면 아이콘을 빼고 글만, 글은 줄지 않으면 `FittedBox`로 작게) → 10 → 미리보기(창 높이의 34%, 140~210, 모서리 12, 테두리 황갈색 1.5·입어 보는 중이면 꿀색 2.5) → 6 → **버튼 줄**(높이 34, 아래) → 6 → 작은 책갈피 칸 줄(역시 폭을 나눔)(`cosmetic-slot-<slot>`, 입어 보는 칸에 꿀색 점) → 3열 카드 격자(`wardrobe-grid`). **탭·칸은 시안 (나) '책갈피 탭 + 각진 카드'**(26번 시안 확인 2차, DEC-128): `WardrobeTabRow`가 탭들을 가는 나무색 선(칸 줄은 황갈색 1.5) 위에 세우고, 탭(`WardrobePill`, 이름은 예전 알약 그대로)은 위 모서리만 둥근 7·아래 평평, 고른 탭은 복숭아색(`Cozy.peach`)·밝은 나무색 테두리 1.5·4 더 높음·진한 글, 나머지는 크림·황갈색 테두리 1·회갈색(`Cozy.taupe`) 글. 탭 사이 3. 탭 줄 아래 선은 밝은 나무색 1.5(칸 줄은 황갈색 1). 입어 보는 칸 점은 주황 6(`Cozy.amber`). '모습만 바뀌어요' 글은 없음(G14).
- 미리보기: 사장님 탭은 매대 없는 방 `ui/wardrobe_room`(25번 11번) 위 전신(G1), 누르면 말하지 않음(G2). 붕어빵 탭은 붕어빵 크게. 가게 탭은 **사장님 없는 가로 노점 장면**(26번 시안 확인 2차, DEC-128; 예전 F33의 세로 홈 장면 통째 + 사장님은 이상하다는 답): `StallPreviewPainter`(키 `preview-stall-scene`, 상자 가득)가 낮춘 배경(`bg_low`, 없으면 매대 없는 배경)의 거리~매대를 상자에 덮고 행주 줄을 높이의 0.68에 둠, 장식은 줄 종류(폭 150 장면 단위 이상: 깃발·별 전구·종이 초롱 줄)는 위 4에 가로 가득, 등불·풍경은 양쪽 0.17 안쪽에 한 쌍(왼쪽 뒤집기는 `decorationAt` 그대로), 눈사람은 매대 위 오른쪽(0.86), 등불 색은 칸 그림 `stall/lamp_<색>`(기둥 등)을 양 끝에 높이 0.42, 화로는 가로 0.45 중심·폭 0.5(높이 0.52 이하)로 매대 위. 밤낮은 그 배경의 밤 그림(없으면 어둡게). 값은 모두 `StallPreviewPainter`의 상수. 고른 것은 칸마다 기억(`picks`)해 탭·칸을 바꿔도 함께 그림.
- 미리보기 왼쪽 위: 입은 것과 다를 때만 작은 칩 '입어 보는 중'(`cosmetic-preview-status`, `WardrobeRibbon`: 높이 24, 양끝 둥근 알약, 반투명 짙은 바탕(`Cozy.ink` 72%)에 크림 글 12·꿀색 반짝이). 입은 그대로면 아무것도 없음(G15). 예전 되돌리기(`wardrobe-revert`, ↺)는 뜻을 모르겠다는 지적(H13)으로 없애고 '모두 취소'로 바꿈.
- 버튼 줄(3차 피드백 H14·H15, 미리보기 바로 아래 오른쪽 정렬, 숫자 없음, `WardrobeActionButton` 높이 32·모서리 8·글 13, 사이 6): 입어 보는 것이 없으면 버튼 없이 왼쪽에 흐린 안내 '눌러서 입어 보세요'(상점은 '눌러서 입어 보고, 마음에 들면 사요', `wardrobe-hint`). 입어 보는 중이면 **'모두 취소'**(`wardrobe-cancel-all`, 테두리만) — 입어 본 것을 모두 되돌림, **'모두 사기'**(`wardrobe-buy-all`, 꿀색, 안 산 것을 입어 볼 때만) — 확인 창(`wardrobe-buy-all-dialog`: 아이템마다 아이콘·이름·가격 줄 `wardrobe-buy-row-<id>`, 둘 이상이면 합계 `wardrobe-buy-all-total`, 잠김·황금 모자람·붕어빵력 모자람·연결 없음이면 빨간 이유와 함께 '사고 입기' 꺼짐) → 차례로 1건씩 사고(서버 변경 없음, `CosmeticMenuAccess.apply`) 이어서 가진 것도 모두 입힘, **'모두 적용'**(`wardrobe-apply-all`, 짙은 나무색, 가진 것을 입어 볼 때만) — 가진 것만 칸마다 입힘. 다 입으면 **창이 스스로 닫혀** 홈으로 돌아감(`WardrobePanel.onClose`, '돌아가기'를 눌러야 들어가던 흐름 없앰). 못 입힌 것·안 산 것은 이름을 미리보기 아래 반투명 띠(`wardrobe-message`)로 말하고 입어 보는 중으로 남김. 상점은 '모두 취소'와 마지막으로 누른 아이템의 '사고 바로 입기'(`buy-cosmetic-<id>`, 잠겼으면 'Lv.N 해금', 못 사면 꺼짐) → 확인 창(가격 아이콘·'사면 계속 갖고, 바로 입어요', `wardrobe-buy-confirm`) → 1건 구매 뒤 바로 입힘(창은 닫지 않음).
- 타일(`WardrobeTile`, 키 `preview-<id>`): **각진 카드**(모서리 4, `WardrobeTile.radius`)에 아이템 아이콘(폭 68% 네모 받침 모서리 4, G5 `CosmeticThumb`), 이름 한 줄, 상태 한 줄. 입는 중 = 진한 테두리 + 오른쪽 위 체크 + '입는 중', 보유 = '보유' 배지, 살 수 있음 = 가격표 한 줄(`CurrencyAmount` 붕어빵력·황금, `FittedBox`로 줄바꿈 없음), 모자람 = 같은 가격표에 모자란 재화 빨강(화면 읽기 '붕어빵력 모자람'), 레벨 잠김 = 아이콘에만 공통 잠금 `LockedOverlay`(빗금+자물쇠) + 빨간 'Lv.N 해금', 눌러서 입어 보기 가능. 고른 타일은 꿀색 테두리.
- 탭 공개: 붕어빵 탭은 `fish_cosmetics`(Lv.5)부터 보임(`CosmeticMenuAccess.tabOpen`, S45-Q6). 가게 탭은 26번 3차 H42부터 `stall_background`(Lv.1)부터 보이고 그 안의 배경·밤낮 칸만 열림, 화로·장식·등불 칸은 `stall_cosmetics`(Lv.8)부터(`CosmeticMenuAccess.slotOpen`). 배경은 상점 꾸미기 탭의 가게 칸에서 팔고(입어 보기·사면 바로 입음), 꾸미기 가게 탭·메뉴 '배경 테마'·설정 '배경 바꾸기'(`settings-background`, '지금: 맑은 날', 설정 창 계정 칸 바로 아래)에서 바꿈. 산 배경은 가게 저장 `avatarEquipment['background']`(저장 형식 그대로). 탭·칸은 체크 표시 없는 책갈피(위 '배치'), 고르면 복숭아색.
- 구형 클리커 경로(`game_app.dart`, access 없음)의 `WardrobePanel`·`ShopPanel`은 예전 모양 그대로.

**상점·꾸미기(Workshop):** 파는 것은 아바타 카탈로그(`avatar_catalog`)뿐. 그 밖의 구형 꾸미기(화로·배경·장식·등불·무늬·토핑)는 가지고 있을 때만 보임(`CosmeticMenuAccess.listed`). 품목이 하나도 없는 상점 탭(지금은 테마)은 숨기고 충전 탭은 항상 둠. 충전 탭에는 구형 클리커 부스트 줄을 두지 않음(`GoldChargeTab(legacyBoost: false)`). 로그인 전에는 '로그인하면 충전할 수 있어요', 상품을 불러오는 동안 가격 자리에 '불러오는 중'.

골든: `test/goldens/workshop_counter_{360x800,390x844,412x915}.png`(`test/workshop_counter_test.dart`, 테스트 글꼴). 실제 글꼴(Jua·BungeoSymbols·Material 아이콘)을 불러 찍는 `test/goldens/workshop_home_{open,menu}_{360x640,360x800,390x844,412x915}.png`, `workshop_home_{ready,baking}_390x844.png`, `workshop_home_flipping_360x640.png`(`test/workshop_home_golden_test.dart`): 영업 중 홈(손님 2·재고 1, 떠 있는 큰 붕어빵), 메뉴 창, 영업 준비(빈 틀·빈 굽는 판 그림), 스페셜 붕어빵 제작 중, 원 그려 뒤집기 반 바퀴(모션 줄이기 상태라 틀은 돌지 않고 고리 56%), 그리고 25번 그림 적용 때 더한 `workshop_home_filling_390x844`(속을 짜는 도중, 넘침·짜는 중 짤주머니)와 `workshop_home_griddle_390x844`(영업 중 1·4번 칸만 굽는 중), 26번 4단계에서 더한 `workshop_home_result_<perfect·good·near·fail>_390x844`(결과 등급별, 모션 줄이기라 효과 없이 글·익힘 색·넘침 방울·윤기)와 반짝이 시안 `sparkle_options.png`(`test/sparkle_options_golden_test.dart`). 26번 4단계 반짝이 교체로 `workshop_home_open_*`·`workshop_home_griddle_390x844`·`workshop_counter_*`·`home_*`(맑은 하늘 날씨·`BakeTarget`)을 다시 만듦. 24번 4단계에서 굽는 판 폭·카운터 높이·빈 굽는 판 그림으로 13장 모두 다시 만듦. 배치 숫자는 `test/workshop_home_layout_test.dart`가 4개 해상도에서 확인(굽는 판 폭 = 화면 폭 − 16, 카운터 윗변 = 행주 윗변, 시작 버튼 아래끝 = 카운터 윗변 − 4, 칸이 카운터 아래·하단 메뉴 위, 손님 줄(예전 구도)·손님 그림 아래끝(새 구도, ±1)이 카운터 윗변, 맨 앞 손님 가로 가운데, 손님 머리가 HUD 아래, 제작 단계 안내 글 아래끝 ≤ '제작 취소' 버튼 윗변 − 4). 26번 2단계에서 `workshop_counter_*` 3장과 `workshop_home_*` 13장을 모두 다시 만듦(이유: Lv.1 새 상태라 초당·클릭당 숫자가 숨고 하단 메뉴 '스킬'에 빗금 자물쇠, 숙련 전 굽는 판에 공통 잠금과 남은 숙련 글이 덮임. `griddle` 골든은 숙련 상태라 칸 그대로, 소개 카드는 본 것으로 둠). 웨이브 4 병합(2·4단계)에서 두 변경이 함께 보이도록 `workshop_counter_*`·`workshop_home_open_*`·`workshop_home_griddle_390x844`·`workshop_home_result_*` 12장을 다시 만듦. **26번 4-1단계**에서 `workshop_counter_*` 3장과 `workshop_home_*` 17장을 모두 다시 만듦(이유: 낮춘 배경·매대 앞 손님·클리커 0.8배 내림, 카운터 버튼 가운데·카운터 2줄 글, 상태 간판, 무기명 '일반 손님', 결과 손님 반응을 손님 머리 위 말풍선으로). 새 골든 6장: `workshop_home_empty_{360x640,412x915}`(손님 0명 빈 매대), `workshop_home_guests_max_390x844`(손님 4명), `workshop_home_sold_390x844`(판매 직후 기쁜 손님이 떠나는 중), `workshop_home_reaction_390x844`(주문 제작 결과 손님 말풍선), `workshop_home_old_layout_390x844`(낮춘 배경이 다 없을 때 예전 구도). **26번 4-2단계**에서 `workshop_home_*` 23장 모두·`workshop_counter_*` 3장·`home_{360x800,390x844,412x915}`·`skill_shop_{tap,auto}_390x844`·`skill_shop_states_360x800`을 다시 만듦(이유: 하단 메뉴 아이콘 위·이름 아래와 nav_* 아이콘, 영업 준비·숙련 전 닫힌 판, `griddle` 골든의 열린 판·뚜껑, 위치를 맞춘 조리 컷). **26번 7단계**에서 `workshop_counter_*` 3장과 `workshop_home_*` 중 안내가 끝난 상태 15장(open 4·menu 4·empty 2·ready·griddle·guests_max·sold·old_layout)을 다시 만듦(이유: 조리 컷 위 '오늘' 쪽지와 빨간 점. 메뉴 창은 뒤에 비치는 홈만 바뀜. `skill_shop_*` 3장·`wardrobe_hair`·`wardrobe_stall`·`shop_avatar`도 창 가장자리에 비치는 빨간 점 6px로 다시 만듦), 새 골든 `workshop_daily_card_390x844`(`test/workshop_daily_test.dart`, 크리스마스 행사 중 쪽지 카드). **26번 8단계**에서 `workshop_home_menu_{360x800,390x844,412x915}`(메뉴 '가게 사진 찍기' 줄, 360x640은 줄이 화면 밖이라 그대로)과 `workshop_home_result_perfect_390x844`·`workshop_home_reaction_390x844`(완벽 결과의 '자랑하기' 버튼)를 다시 만듦. 새 골든 `share_card_{perfect,story,shop}_360x450`(`test/share_card_test.dart`, 공유 카드 축소본). 이 골든과 `workshop_counter_*` 골든은 `WorkshopController(monotonicMs: () => 0)`으로 단조 시계를 멈춰 '현재 단계 경과'와 손님 대기 고리가 실제 시간에 따라 바뀌지 않음. **3차 피드백 F(2026-11-19, 25번 생성 그림 적용)**에서 `workshop_home_griddle_390x844`(34번 낮은 뚜껑)·`workshop_home_menu_*` 4장·`skill_shop_*` 3장·`wardrobe_hair`·`wardrobe_stall`·`shop_avatar`(35번 제목 붕어빵·33번 LEVEL UP)를 다시 만듦.

**첫 영업 이야기** (26번 3차 H6, DEC-132, `workshop_tutorial.dart` `workshopStoryChapter`·`workshopStoryLines`·`workshopStoryAction`, `ui/workshop_guide.dart` `WorkshopStoryOverlay`, 키 `story-overlay`·`story-card`·`story-next`·`story-skip`): 아래 안내 카드보다 먼저, 홈을 검정 45%로 덮고 가운데보다 조금 아래(세로 정렬 0.35)에 첫 실행 카드와 같은 밝은 카드(붕어빵 그림 44, 한 줄 글 Jua 19, 진행 점, '건너뛰기'·'다음' 알약 버튼). 한 줄씩 '다음' 또는 화면 아무 곳이나 눌러 넘기고 마지막 줄 버튼은 장면별 글. ① `welcome`(안내 `cook`, 가게 닫힘, 굽는 중 아님): '어서 오세요, ○○ 사장님! 환영합니다.'(이름이 없으면 '사장님') → '우리는 오늘부터 이 작은 노점에서 따끈한 붕어빵을 팔 거예요.' → '손님을 맞기 전에, 먼저 붕어빵 굽기 연습을 해 볼까요?' [연습해 볼게요] ② `open`(안내 `sell`, 가게 닫힘): '잘 구웠어요! 이 정도면 손님에게 내놓아도 되겠어요.' → '이제 가게 문을 열고 첫 손님에게 붕어빵을 팔아 볼까요?' [좋아요]. '건너뛰기'는 이야기만 끝냄. 본 장면은 `WorkshopPage` 상태에만 기억(저장 안 함) — 앱을 다시 켰을 때 아직 그 단계면 한 번 더 나옴. 이야기가 떠 있는 동안 아래 안내 카드는 숨김.

**첫 실행 안내** (`lib/workshop_tutorial.dart` 단계 계산, `lib/ui/workshop_guide.dart` `WorkshopTutorialOverlay`): 홈 위에 겹친 층. 대상 위젯을 꿀색 고리로 두르고 작은 카드(“첫 영업 안내 N/7”, 한 줄 설명, '건너뛰기')를 띄움. 카드만 터치를 받고 게임은 그대로 조작됨. 저장하는 것은 `tutorial` 값뿐이고 단계는 매 프레임 상태에서 계산.

| 단계 | 조건 | 대상 키 |
| --- | --- | --- |
| 1 | `cook`, 스페셜 붕어빵 틀 비어 있음 | `workshop-mold` |
| 2~6 | 연습 굽기 단계: 반죽 문지르기('틀 위를 문질러 반죽을 칠하듯 부어요. 붕어빵 모양을 고르게 덮고 손을 떼요.') → 속('틀 위를 문질러 속을 짜 넣어요.') → 둘째 반죽('반죽을 한 번 더 문질러 속을 덮어요.')·뚜껑 → 뒤집기('틀을 위로 밀어 올려 고리 축을 따라 뒤집어요.', 26번 3차 피드백 H21) → 꺼내기·보관 | `workshop-mold`, 결과는 `mold-store` |
| 1(영업 중) | `cook`인데 이미 영업 중(DEC-037): 손님 없으면 '영업 중에는 손님 주문을 받아 구워요. 손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요.', 손님이 있으면 판매할 재고가 있으면 판매, 없으면 '손님 주문은 주문 제작으로 바로 구워요.' 주문 제작 결과를 닫으면 `sell` | `workshop-clicker`, `sale-button`, `order-produce` |
| 7 | `sell`: 영업 시작 → 첫 손님 기다리기('첫 손님을 기다려요. 손님을 기다리는 동안 큰 붕어빵을 톡톡 눌러 붕어빵력을 모아요.') → 판매(재고 없으면 주문 제작) | `business-open`, `workshop-clicker`, `sale-button`, `order-produce` |

카드 위치: 스페셜 붕어빵 제작 단계는 무대(`workshop-center-stage`) 바로 아래, 그 밖에는 대상의 넓은 쪽. 왼쪽 72(예전 구도: 손님 줄 피함), 새 구도는 왼쪽 12(`WorkshopHomeLayout.guideLeft`)·오른쪽 12. 어떤 글자 크기에서도 하단 메뉴(`home-nav`) 위 6에서 멈추도록 위로 밀어 올림. 이야기 장면 중에는 숨김. 연습 결과를 보관하거나 주문 제작 결과를 닫으면 `sell`, 첫 판매 완료(주문을 다 채운 판매)면 `done`. 안내 중 첫 판매는 네임드 손님이어도 이야기·후일담·선택 장면을 붙이지 않고, 손님 맞이에서도 선택 장면을 굴리지 않음.

**처음 5분 해금** (26번 2단계, DEC-043 A. 하나씩 열기, `lib/workshop_feature_unlocks.dart`): 화면·창·컨트롤러가 모두 `featureOpen`/`featureLockReason`(`WorkshopController.featureIsOpen`·`featureLock`) 하나로 판단. 핵심 진행(굽기·판매·영업·연습)은 레벨로 잠그지 않음(`tools/development_balance.py`가 `manual_practice`·`core_*`·`mastery_progress`·`six_slot_access` = 1을 검사, `skill_shop`은 2~5만 허용).

| 기능 (`WorkshopFeature`) | 열리는 조건 | 잠겨 있을 때 화면 |
| --- | --- | --- |
| 굽기·영업·손님·판매·큰 붕어빵 | 처음부터 | — |
| 꾸미기·상점 (`wardrobe`) | 첫 실행 안내가 끝나면(`done`/`skipped`) | 하단 메뉴 '꾸미기'·'상점'에 빗금 자물쇠, 누르면 '꾸미기: 첫 영업 안내가 끝나면 열려요' |
| 스킬 창·초당/클릭당 숫자 (`skills`) | `feature_unlock_levels.skill_shop`(Lv.2), 또는 스킬을 이미 샀거나 정산 중인 거래가 있을 때 | 하단 메뉴 '스킬'에 빗금 자물쇠('스킬: Lv.2에 열려요'), HUD 초당·클릭당 칸 숨김(잔액 칸이 넓어짐) |
| 숙련된 붕어빵 틀 6구 (`griddle`) | 맛 하나 숙련(`masteryAwards`, S2-Q2) + `six_slot_access`(Lv.1) | 위 '숙련된 붕어빵 틀 칸' 줄의 `griddle-locked` |
| 도감 (`collection`) | `full_recipe_collection_ui`(Lv.3) | 메뉴 창에서 숨김 |
| 새 맛 레시피 (`recipes`) | `additional_recipe_acquisition_tiers` 가장 낮은 `unlock_level`(Lv.4), 또는 이미 받은 레시피 | 소개 카드만(레벨 미션 창의 레시피 미션 줄은 원래 조건 그대로) |
| 특별 주문 (`specialOrders`) | `ordinary_sale.special_order_unlock_level`(Lv.5) | 소개 카드만(주문 규칙은 원래대로) |
| 붕어빵 꾸미기 (`fishCosmetics`) | `fish_cosmetics`(Lv.5) | 소개 카드만(꾸미기 칸 정리는 4-5단계) |
| 신선도 (`freshness`) | 재고 묶음이 영업일을 하나 이상 넘김 | 아무것도 잠그지 않음, 소개 카드만 |
| 가게 꾸미기 (`stallCosmetics`) | `stall_cosmetics`(Lv.8) | 꾸미기 가게 탭의 화로·장식·등불 칸(26번 3차 H42 전에는 메뉴 '배경 테마'까지 숨김) |
| 배경 테마 (`stallBackground`, 소개 카드 없음) | `stall_background`(Lv.1, 26번 3차 H42) | 메뉴 창 '배경 테마'·설정 '배경 바꾸기'·꾸미기 가게 탭(배경·밤낮 칸) |

- **공통 잠금 표시** (`lib/ui/lock_overlay.dart` `LockedOverlay`, 4-3단계가 함께 씀): 원래 모습을 투명도 0.5로 흐리게 + 짙은 나무색 0.18 면 + **대각선 빗금 한 줄**(`LockHatchPainter`, 26번 3차 피드백 H27: 굵기 3, `0xff5b3a24` 55%, 옅은 면 0.12. 예전 굵기 6·간격 10 여러 줄) + 큰 자물쇠(`ui/lock_badge.png` 128×128, 25번 13번 생성 그림을 `tools/apply_25_art.py --only locks`로 줄임, 없으면 Material 자물쇠) + 높이 64 이상이면 아래에 잠금 글 상자. 하단 메뉴는 자물쇠 18을 버튼 오른쪽 위 모서리(`Alignment(.82, -.78)`, H27)에 두어 아이콘·글자를 가리지 않고 잠금 글은 숨김(화면 읽기 '잠김, 스킬: Lv.2에 열려요'). 키 `menu-<id>-locked`, `griddle-locked`, `lock-hatch`, `lock-badge`, `lock-caption`. 모양은 두 가지(26번 4-3단계, S43-Q4 '빗금+큰 자물쇠'): `LockStyle.hatch`(기능·꾸미기, 위 설명) / `LockStyle.hidden`(다음 스킬: 그림을 `ColorFiltered`로 `0xff3e2a1d` 실루엣 0.55 + 큰 자물쇠, 빗금 없음, 키 `lock-silhouette`). `maxLock`·`showCaption`·`lockAlignment`·`onTap`을 받고, 잠긴 칸의 손가락은 아래 그림에 닿지 않음(`test/lock_overlay_test.dart`). 4-5단계 꾸미기 잠금도 이 위젯을 쓴다.
- **재화 표시** (`lib/ui/currency_amount.dart` `CurrencyAmount(Currency.buns|gold, amount, short, missing)`, 26번 4-3단계): 아이콘(`icons/bun.png` / 황금 `icons/gold_bun.png` 72×72, 25번 18번) + 숫자(기본 `compactNumber`, 줄였으면 길게 눌러 정확한 숫자 Tooltip, 모자라면 빨강, 화면 읽기 '붕어빵력 12345, 모자라요'). 스킬 창 비용이 쓰고 4-5단계 잔액 줄·꾸미기 타일이 쓴다.
- **스킬 창 골든** `test/goldens/skill_shop_{tap,auto}_390x844.png`·`skill_shop_states_360x800.png`(`test/workshop_skill_window_test.dart`, 실제 글꼴; 26번 4-3단계에서 새로 만듦): tap = MAX·올릴 수 있음·돈 부족·해금됨 Lv.0·잠김(실루엣), auto = ×10 + 황금이 필요한 5단계를 못 사는 상태, states = 360 폭·×100·두 재화. 시안 비교 `flutter test tools/preview_skill_shop_test.dart` → `build/preview/skill_shop_options.png`(칸 2안·단위 고르기 2안·잠금 3안).
- **기능 소개 카드** (`ui/workshop_guide.dart` `WorkshopFeatureIntroCard`, 키 `feature-intro-<id>`): 그림 200×150 틀 + 제목 + 두 문장 + '알겠어요'(`feature-intro-ok`). 그림은 `ui/intro_<id>.png`(25번 22번, 160×120을 1:1로, 2026-11-19 생성 그림 8장 적용 `tools/apply_25_art.py --only intro`, 골든 `test/goldens/feature_intro_cards.png`) — 파일이 없으면 기존 아이콘(`skill`·`bun`·`achievements`·`mission`·`daily`·`tab_fish`·`records`·`tab_stall`)을 88로 그린 임시 그림(`feature-intro-standin`). 안내가 끝난 뒤, 다른 창·복귀 카드·알림 질문·이야기 장면·스페셜 붕어빵 제작·첫 판매 칭찬이 없을 때 한 장씩(여러 개면 표 순서), 바깥을 눌러도 닫히지 않음. 닫으면 `markIntroSeen`으로 저장(schema 8 `featureIntros`). 손님 알림 질문은 소개 카드가 떠 있으면 기다림. 스킬 카드 문구에 '카카오 로그인 후 레벨업'(S3-Q3).
- **첫 판매 칭찬** (S2-Q4, `WorkshopSalePraiseBanner`, 키 `sale-praise`): 안내를 끝내는 첫 판매에만. 화면 가운데에 손님 이름·성공 대사 말풍선(`sale-praise-speech`) + 큰 별(`icons/star`, 64) + '별 N개!' + 둘레 반짝이(`SparklePainter`, `fx/sparkle`) 2초, 커졌다 돌아오는 연출. 모션 줄이기(설정 또는 기기)면 반짝이·연출 없이 정지 표시. 터치는 막지 않음. 저장하지 않음(`WorkshopController.salePraise`, 다시 켜면 없음). 그 뒤 판매는 예전처럼 카운터 한 줄(`lastSaleFeedback`).
- 새 설치 첫 화면 비교(26번 2단계 결과 표): HUD·하단 메뉴에서 바로 쓸 수 있는 버튼 8 → 5(화면 전체 12 → 9: 맛 선택·제작 시작·영업 시작·건너뛰기 포함), HUD 숫자 6 → 4(초당·클릭당 숨김).

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
  - 레벨 엠블럼(지름 62 원, 둘레 꿀색 고리 = 레벨 미션 진행, 26번 3차 피드백 H29). 누르면 레벨 미션이 열립니다. 키 `level-mission-entry`·`level-progress`.
  - 보유 붕어빵(비율 44, 아이콘 40). 둘째 줄: Workshop은 황금붕어빵력(`hud-gold`, H30), 구형 홈은 누적. 키 `balance-value`, `lifetime-value`(구형).
  - 초당/클릭당(비율 30). 키 `auto-rate`, `tap-rate`.
- 2줄
  - 메뉴 둥근 버튼 48×48. 받을 보상 수를 배지로 표시합니다. 키 `menu-menu`. **Workshop 홈에는 없음**(26번 3차 피드백 H28: 메뉴는 하단에만, 이 자리는 맛 버튼 `flavor-button`, 37장).
  - 가운데 환생·칭호 문구.
  - 설정 버튼.

**굽기 영역**
- 굽기 영역 전체가 탭 영역입니다. 키 `fish-button`.
- 누르고 있으면 250ms마다 굽습니다. Space/Enter 키로도 구울 수 있습니다.
- 콤보 표시는 위 8px에 나옵니다. 콤보 20 이상, 50 이상에서 글자 크기와 색이 바뀝니다.

**하단 내비게이션**: 버튼 4개가 같은 폭으로 놓입니다. 버튼 안은 **아이콘 위, 이름 아래**(26번 4-2단계 F10): 아이콘은 여백을 잘라 96×96을 채운 `icons/nav_menu·nav_skill·nav_skins·nav_shop.png`(`tools/fit_nav_icons.py`, 그림 긴 변 87~88px. 원본 `menu`·`skill`·`tab_outfit`·`shop`은 다른 화면용으로 그대로) 32, 이름 Jua 15(줄 높이 1.15). 가장 긴 이름('꾸미기')이 버튼 폭에, 아이콘 + 가장 높은 이름이 버튼 높이(60 − 7)에 들어가도록 **넷이 같은 비율**로 줄임(`NightHome.navScale`, 글자 크기 설정 반영) → 네 아이콘이 늘 같은 크기(예전: 버튼마다 따로 줄어 번개·앞치마가 훨씬 작게 보임). 잠긴 버튼은 빗금 한 줄 + 작은 자물쇠 18이 **버튼 오른쪽 위 모서리**에 놓임(26번 3차 피드백 H27, 37장. 예전 DEC-128: 자물쇠 34가 버튼 가운데에서 '스킬' 글자를 가림). Workshop 홈은 받을 보상 수 배지를 이 '메뉴' 버튼에 붙임(H28).

| id | 표시 | 키 |
| --- | --- | --- |
| menu | 메뉴 | `menu-menubar` |
| skills | 스킬 | `menu-skills` |
| skins | 꾸미기 | `menu-skins` |
| shop | 상점 | `menu-shop` |

**화면 크기 대응:** 글자가 크거나 굽기 영역이 360보다 작으면 HUD와 굽기 영역이 스크롤됩니다(`home-scroll`).

### 패널(시트)

**Workshop 메뉴·도감·생산 기록 (3차 피드백 H32·H44·H45, DEC-137)**: 메뉴 줄은 도감·업적·생산 기록(옛 '통계')·레벨 미션·가게 사진 찍기(+잠금 풀린 배경 테마). 도감은 Lv.3(`feature_unlock_levels.full_recipe_collection_ui`) 전에도 자물쇠·'Lv.3에 열려요'와 함께 보이고(`MenuPanel.locks`), 열면 맛마다 다섯 익힘 그림 칸(`WorkshopCollectionView`, 찾은 것 색·못 찾은 것 '?' 그림자)·찾은 수·연습/손기술 막대, 아직 없는 맛은 얻는 방법. 잠김이면 위에 안내, 아래는 흐린 미리보기. 생산 기록은 아이콘 + 큰 숫자 칸 두 줄(`WorkshopRecordsView`). 모든 창의 닫기(X)는 창 안쪽 오른쪽 위(`CozyCloseButton.edge` 8, 36×36), 작은 팝업 내용은 `CozyCloseButton.inset` 34 아래에서 시작(H38). 미리보기 `flutter test tools/preview_h_d_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf` → `build/preview/hd_*.png`. 레벨 미션 창도 같은 카드(누적 붕어빵력·이번 레벨 탭·판매 막대 + '승급', 레시피 미션 카드 '레시피 받기'). 이 변경(오늘 버튼·X 위치·메뉴 줄)으로 `workshop_counter_*`·`workshop_home_*`(18장)·`skill_shop_*`·`wardrobe_{hair,stall}`·`shop_avatar`·`workshop_daily_card`·`share_card_*` 골든을 다시 만듦. 공유 시안 비교 `tools/preview_share_mockups_test.dart`

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

**메뉴 목록 순서:** 도감 · 업적 · 통계 · 온라인 랭킹 · 배경 테마 · 일일 미션 · 주간 도전 · 레벨 미션 · 친구 · 공유 · 가게 사진 찍기(`photo`, Workshop 전용)

**모든 화면 위에 뜨는 것**(`ui/celebration.dart`, 짧은 알림은 `ui/center_toast.dart` `showCenterToast` — 화면 가운데 반투명 창, 스낵바 없음, 26번 3차 피드백 H23)
- 축하 배너: 화면 중앙보다 위, 최대 폭 320.
- '미션 달성!' 알림: 위쪽에 2.6초 동안.
- 오프라인 보상 창.

---

## 11. 디자인 토큰

파일: `lib/ui/cozy_style.dart`. 글꼴은 Jua입니다(`assets/fonts/Jua-Regular.ttf`, OFL).

**기호 대체 글꼴:** Jua에는 `·` `…` `‘’` `→` `「」` `—` `×` `●○` 같은 문장 부호·기호가 없습니다. 이 글자들은 `BungeoSymbols`(`assets/fonts/BungeoSymbols-Regular.ttf`, 약 36KB)로 그립니다. Noto Sans KR(OFL)에서 굵기 600으로 기호 범위만 잘라 이름을 바꾼 글꼴이고, 라이선스는 `BungeoSymbols-OFL.txt`입니다. 다시 만들 때는 `python tools/build_symbol_font.py <NotoSansKR[wght].ttf>`. 코드에서는 `fontFamily: 'Jua'`를 쓰는 모든 곳(테마·`TextTheme`·직접 지정한 `TextStyle`)에 `fontFamilyFallback: Cozy.fontFallback`을 함께 씁니다. 새 `TextStyle`에 Jua를 지정할 때도 같이 넣어야 합니다(버튼 테마처럼 기본 글자 모양을 물려받지 않는 곳이 있음). `test/font_coverage_test.dart`가 `lib/`와 `config/development_balance.json`의 모든 글자가 두 글꼴 중 하나에 있는지 확인합니다.

**26번 3차 H41(2026-11-19)로 바뀜:** '말풍선·창이 모두 갈색/베이지로 똑같아 올드하다'는 지적에 따라 패널·창의 두꺼운 나무 테두리를 없애고, 따뜻한 흰 면 + 가는 선 1 + 부드러운 그림자로 바꿨다. 메시지 종류마다 색을 나눴다(`CozyTone`). 이름은 그대로 두고 값만 바꿔 모든 화면이 따라온다. 괄호 안은 바꾸기 전 값.

| 이름 | 색 | 용도 |
| --- | --- | --- |
| cream | `#FFFAF3` (전 `#FEF1D6`) | 패널·창 면 |
| creamDeep | `#F4ECE2` (전 `#FEE6BC`) | 비활성, 탭 줄 바탕, 창 아래 받침 |
| wood | `#6B4532` (전 `#7D3419`) | 강조 테두리·글자 |
| woodLight | `#DCC6AE` (전 `#C1682D`) | 카드 위 보이는 연한 선 |
| woodDark | `#3D2B23` (전 `#68311F`) | 홈의 짙은 조각(레벨 상자 등) |
| ink | `#2F221C` (전 `#3A1E1A`) | 본문 글자 |
| inkSoft | `#85766C` (전 `#7A6963`) | 보조 글자 |
| caption | `#A3928A` (새로) | 더 흐린 글자(약관 줄, 메뉴 줄 `>`) |
| line | `#EADFD2` (새로) | 모든 패널·창의 가는 선 |
| orange | `#FFB65C` (전 `#FBAF5A`) | 강조·진행 막대 |
| orangeDeep | `#F29A38` (전 `#E39E57`) | 강조 테두리·테마 기준색 |
| brick | `#D0533A` (전 `#AC3613`) | 배지·경고 |
| honeyLight·honey·honeyDeep | `#FFD96B`·`#FFC83D`·`#FFB92E` (전 `#FFD054`·`#FDBE38`·`#FEB432`) | 주 버튼·고른 탭 면, 슬라이더 채운 부분, `FilledButton` 바탕 |
| amber | `#EB960F` (전 `#F07D0C`) | 주 버튼 아래 2px 턱 |
| tangerine | `#FFA21A` (전 `#FD9607`) | ON 토글 |
| tan | `#EBDCCB` (전 `#E9B47E`) | 카드 안쪽 연한 선, 고르지 않은 탭 테두리 |
| peach·peachEdge | `#FFE7C7`·`#F3D1A8` (전 `#FDD09C`·`#F0B47A`) | 효과 칩 바탕·테두리 |
| taupe | `#D3C6BA` (전 `#8A6E62`) | OFF 토글, 슬라이더 빈 부분 |
| knob | `#FFFFFF` (전 `#FFF6E8`) | 토글·슬라이더 손잡이 |
| shadow·shadowDeep | 검정 14%·25% (전 33%·40%) | 카드(`Cozy.cardShadow`: 검정 8%, 아래 1·흐림 4)·창(검정 18%, 아래 4·흐림 16) 그림자 |

**종류별 색 `CozyTone` (면 / 선 / 글자):** neutral(cream / line / ink), info 안내(`#EDF4FB` / `#C6DBEF` / `#2F6596`), reward 보상·황금(`#FFF5D8` / `#F3D27F` / `#9A6200`), warning 경고·오류(`#FDEEEA` / `#F2C3B8` / `#B23F28`), success 완료(`#EBF6EE` / `#C3E3CD` / `#2E7A4C`). 쓰는 곳: 충전 탭 잔액 카드(reward), '로그인하면 충전할 수 있어요'(info), 결제 알림(success), Workshop 창 오류 줄(warning)·알림 줄(info), '미션 달성!' 알림(success). 다른 화면은 `CozyPanel(tone:)`·`CozyNotice`·`CozyBubble(tone:)`·`CozyChip(tone:)`로 같은 색을 쓴다.

버튼·탭·칩·토글·슬라이더 색은 `3.5_completed_game_mockups/서브UI5종`에서 뽑았습니다. 근거는 `coordination/visual-00-gap.md`와 `coordination/visual-02.md`에 있습니다.

**공통 위젯**

| 위젯 | 모양 (26번 3차 H41) |
| --- | --- |
| CozyPanel | 반경 14(기본), 면 = `tone.fill`(기본 cream), 선 1 = `tone.edge`(기본 line), 카드 그림자. `tone:`으로 종류 색 |
| CozyNotice (새로) | 한 줄 메시지 상자: 종류 색 면·선, 반경 10, 앞에 종류 아이콘(안내 i, 보상 선물, 경고 !, 완료 ✓), 글자 13 |
| CozyBubble (새로) | 말풍선: 반경 14(낮으면 높이의 반), 아래 가운데 꼬리 7, 선 1, 그림자. 기본 흰색(목소리), `tone:`으로 게임 메시지 색. 손님 말풍선(`GuestSpeechBubble`)이 씀 |
| CozyRoundButton | 48 원형, cream 면 + line 선 + 카드 그림자, 눌림 |
| CozyFrame | 창: 반경 22, cream 면, line 선 1, 그림자(아래 4·흐림 16). 두꺼운 나무 테두리 없음 |
| CozyCloseButton | 누르는 칸 44, 보이는 원 36(cream·line·카드 그림자), 짙은 X 22, 눌림 |
| CozyBackButton | 알약(반경 24), 최소 높이 48, cream·line·카드 그림자, 뒤로 아이콘 22 + '돌아가기' Jua 18, 눌림, Key `sheet-back` |
| CozySettingRow | 설정 한 줄: 반경 14, line 선 1, 이름 Jua 18 |
| CozyOnOff | 72×34 켜기/끄기(tangerine/taupe, 테두리 없음, 흰 손잡이 + 그림자) |
| CozyPrimaryButton | 주 버튼. 최소 높이 44, 꿀색 그라데이션(honeyLight→honey) + honeyDeep 선 1 + amber 아래 턱 2, 짙은 테두리 없음, Jua 18. `onPressed`가 null이면 creamDeep 면에 흐린 글자(턱도 같은 색) |
| CozyButton | 보조 버튼. 같은 모양에 cream 면 + woodLight 선 + line 턱 |
| CozyChip | 효과 칩. peach 바탕 + peachEdge 선 1(또는 `tone:` 색), 반경 8, Jua 14 |
| CozyTabBar·CozyTab | 한 줄 세그먼트: creamDeep 우물(반경 13, line 선) 안에 같은 폭 탭, 고른 탭만 꿀색 알약 + 그림자, 나머지는 흐린 글자. 높이 44(바깥), Jua 17. 각 탭의 Key는 `CozyTab.key` |
| CozyMenuRow | 메뉴 줄. 최소 높이 64, 아이콘 48, 제목 Jua 20, cream·line·카드 그림자, 오른쪽 흐린 `>` |
| MenuPanel 줄 | CozyMenuRow와 같은 흰 카드(반경 14, line 선, 그림자 1) |
| CozyPressable | 위 버튼들이 쓰는 눌림 처리. 누르는 동안 2px 내려감 |
| CozyMotion | 모션 줄이기 전달. `GameApp`이 설정의 모션 줄이기 값으로 앱 전체를 감쌈. 켜져 있거나 기기 애니메이션 끄기면 눌림·토글 이동을 하지 않음 |
| 슬라이더(테마) | `CozySliderTrackShape`·`CozySliderThumbShape`. 두께 10, line 선 1, 빈 부분 creamDeep, 흰 손잡이(반지름 12, honeyDeep 선 1, 흐린 그림자) |
| 테마 | `FilledButton` 꿀색·honeyDeep 선 1·그림자 없음, `OutlinedButton`·카드·칩은 line/woodLight 선 1, 대화상자 반경 20·line 선, 구분선 line, 스낵바 ink 92% |

**글자 크기**

| 쓰는 곳 | 크기 |
| --- | --- |
| 시트 제목 | Jua 28 |
| 메뉴 줄 제목(CozyMenuRow) | Jua 20 (H41 전 22) |
| 하단 내비 글자 | Jua 15, 아이콘 32 위·이름 아래(넷이 같은 비율로 줄어듦, 26번 4-2단계) |
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
| 배경 | `bg/<id>.png`, 밤 `bg/<id>_night.png`. 매대를 행주 높이로 내린 새 구도 배경 `bg_low/<id>.png` 14장(335×762, `tools/apply_26_home_art.py --only backgrounds`, 25번 20번, 26번 4-1단계) |
| 손님 | `customer/<npc_* 8명·walkin_1~4>_<normal·happy·sad>.png`(256×320 RGBA, 몸 아래끝이 그림 아래끝, 세 표정 같은 자리. `tools/apply_26_home_art.py --only customers`, 25번 6번. walkin_1은 3.3 원본 `customer/order·receive`를 잘라 씀) — 무기명 손님 그림은 주문 id로 4종 중 하나(`guestArtId`) |
| 화로 | `stove/<id>.png`, 빈 굽는 판 `stove_empty/<id>.png`·붕어빵만 `stove_fish/<id>.png`(941×470, `tools/apply_25_art.py`), 닫히고 불 꺼진 판 `stove_closed/<id>.png`(941×470)·열린 판 `stove_open/<id>.png`(941×700, 아래 941×470 = `stove_empty`와 같은 픽셀, 그 위에 뚜껑)(25번 7번 → 2026-11-19 25번 34번 낮게 젖힌 뚜껑, `tools/apply_26_stoves.py --low`, 26번 4-2단계) |
| 장식 | `deco/<id>.png` (위치는 `night_stall_painter.dart` `decorationAt`) |
| 등불 | `stall/postlamp_<색>.png` (id는 `<색>lamp`) |
| 아바타 | `avatar/<girl·boy>/base.png`, `avatar/<character>/<slot>_<id>.png` (여백을 잘라내고 위치는 `avatarTrimOffsets`), 앞/뒤 조각 `_front`·`_back`, 지울 마스크 `_cut`, 피부톤 복사본 `@skin2`·`@skin3` |
| 얼굴 부분 | `parts/<character>_<front·side>_<eyes·mouth>_<frame>.png` (위치는 `avatarPartPivots`, `avatarFaceAnchors`) |
| 아바타 v2 (26번 4-7단계) | `avatar_v2/<girl·boy>/base@<skin1·2·3>.png`, `<slot>_<id>.png`(기본 아이템 포함), 머리 뒤 조각 `hair_<long·ponytail·curly>_back.png`, 모자별 `hat_<id>_hairmask.png`, 바탕 지우기 `<slot>_<id>_basemask.png`(머리·모자·바지·신발), 몸 뒤·앞 조각 `<slot>_<id>_back.png`·`tool_<id>_front@<skin>.png`, 공유 카드 포즈 `pose_proud_arms@<skin>.png`·`pose_proud_hide.png`, 표정 `face_<eyes·mouth>_<frame>@<skin>.png`. 위치 `avatarV2TrimOffsets`·`avatarV2PartPivots`(`lib/avatar_v2_atlas.dart`). 필수 110장이 다 있고 `avatarV2Enabled`여야 쓰임(`avatarV2Ready`; 2026-11-20 26번 3차 AV: 42번 바탕 + 43~49번, 켜짐) |
| 스킬 | `skills/tap_N.png`, `skills/auto_N.png` |
| 아이콘 | `icons/<name>.png` (이름을 `iconNames`에 등록) |
| 효과 | `fx/minifish`, 반짝임 3프레임 `fx/sparkle_1~3`(32×32, 25번 12번, `tools/apply_25_art.py --only sparkles`, 26번 4단계), `fx/fairy_up, fairy_down, butter_glow`, 넘침 방울 `fx/overflow_<batter·redbean·custard·cocoa>`(32×48), 뒤집기 고리 `fx/flip_ring, flip_ring_fill`(512×512) |
| 짤주머니 | `cook/piping_bag_<batter·redbean·custard·cocoa>[_squeeze].png`(128×192, 손가락 점 (64, 188), `pipingPastes`) |
| 속 칠 질감 | `mold/paint_<redbean·custard·cocoa>.png`(256×256 불투명 심리스, `tools/apply_25_art.py --only textures`로 v2 생성본을 줄이고 이음매 보정) |
| 화면 장식 | `ui/wardrobe_bg`(조리 장면 `cook_cut.dart`), 꾸미기 미리보기 방 `ui/wardrobe_room`(1440×864, 128색, 25번 11번, 26번 4-5단계), `ui/offline`, 창 제목 붕어빵 `ui/title_fish`(96×72, 화면 48×36, `TitleFish` — 25번 15번 그림은 '완전 이상'해서 뺐고(DEC-128) 25번 35번 다시 그린 얼굴 없는 붕어빵을 `tools/apply_25_art.py --only title`로 적용(2026-11-19). 파일이 없으면 제목은 장식 없이 가운데), 큰 자물쇠 `ui/lock_badge`(128×128, 26번 2단계), 스킬 창 'LEVEL UP' 버튼 `ui/levelup`·`levelup_off`(108×72, 화면 54×36, 25번 33번 생성 그림 `tools/apply_25_art.py --only levelup`, 꺼짐은 켜짐을 회색으로 바꿔 만듦; 임시 그림 도구 `tools/make_levelup_button.py`는 남겨 둠; 예전 둥근 '+' `levelup_plus`는 DEC-128로 지움), 황금붕어빵력 아이콘 `icons/gold_bun`(72×72, 25번 18번, 26번 4-3단계), 충전 상품 그림 `ui/gold_pack_1~5`(128×128, 작은 묶음→큰 묶음, 화면 54×54, 25번 40번 생성 그림 `tools/apply_25_art.py --only packs` — 파일이 없으면 `GoldPackArt`가 황금 아이콘을 쌓은 임시 그림), 첫 실행 배경 `ui/first_run`(416×945, 25번 37번 `--only firstrun`), 기능 소개 그림 `ui/intro_<skills·griddle·collection·recipes·special_orders·fish_cosmetics·freshness·stall_cosmetics>`(160×120, 64색 불투명, 25번 22번 생성 그림 `tools/apply_25_art.py --only intro`, 없으면 아이콘) |
| 꾸미기 칸 아이콘 (26번 4-5단계, G5) | `cosmetic_icons/<id>.png` 64×64(남자 전용은 `cosmetic_icons/boy/<id>.png`), 아바타 아이템마다 한 장 + 빼기 아이템(모자 없음·앞치마 없음·소품 없음)이 같이 쓰는 `none.png`(빈 옷걸이+사선). 26번 3차 AV3d부터 머리·모자는 `tools/avatar_v2.py wornicons`가 입은 레이어로 만들고 남자 것은 `cosmetic_icons/boy/<id>.png`(위 '맨 바탕 아바타 v2' 아이콘 줄), 나머지는 25번 31번 그림. `tools/make_cosmetic_icons.py`는 다시 돌리지 않음. `PixelSprites.cosmeticIcon(id)`, 없으면 예전처럼 작은 전신 |
| 가게 칸 그림 (25번 16번, 26번 4-5단계) | 등불 칸 `stall/lamp_<amber·rose·mint·lilac>.png` 64×96(기둥째 등불), 밤낮 칸 `icons/time_<scenetime·day·night·clock>.png` 64×64. 꾸미기 타일에만 씀(`PixelSprites.stallTile`). 배경 칸은 배경 그림 가운데 정사각형 |
| 이벤트 배너 | `event/spring·summer·autumn·winter` |
| 조리 장면 | `cook/girl_1~6.png` (700ms 간격 반복). 26번 4-2단계 F9: 작업대(나무 상자)의 가운데·아래끝이 6장 모두 같은 자리가 되도록 장마다 정수 픽셀로 옮김(`tools/align_cook_cuts.py`, 값 `tools/cook_cut_alignment.json`, 공통 이동 (−24, −2)). 남은 머리 흔들림: 2·3번 ≤3px, 4번 세로 9, 5번 7·7, 6번 12·4(그림 자체의 자세 차이 → 25번 10번 재생성 요청) |
| 하단 메뉴 아이콘 | `icons/nav_menu·nav_skill·nav_skins·nav_shop.png`(96×96, 그림 긴 변 87~88, `tools/fit_nav_icons.py`: 2배 이상이면 정수배 최근접(`skill` ×3 = 57×87), 아니면 Lanczos. 26번 4-2단계 F10) |

- 모든 경로는 `assets/images/` 아래이고, **새 폴더는 `pubspec.yaml`의 assets에도 등록**해야 합니다.
- 파일이 없으면 오류 없이 그려지지 않습니다.
- 그림이 없는 아이템은 `blankCosmetics`에 올립니다. 붕어빵·가게 아이템은 모두 그림이 있어야 하고(`test/pixel_art_test.dart`), 아바타 아이템은 그림이 준비될 때까지 꾸미기에서 숨깁니다(`PixelSprites.avatarArtReady`, 7장). 예전 `artPending` 목록은 26번 4-4에서 없앴습니다.
- 아바타 그림을 바꾸거나 추가했으면 `python tools/avatar_layers.py`를 실행합니다(fringe → face → worn → derive → skin → trim, 2026-11-18 기준 약 20분). 머리 사이 흰 배경 잔여를 메우고, 얼굴 부분 그림·입은 모습 레이어와 `_cut`·피부톤 복사본을 만들고, 280×520 그림의 여백을 잘라낸 뒤 `lib/avatar_atlas.dart`를 다시 만듭니다. 전수 확인은 `python tools/avatar_audit.py`(`build/avatar_audit/audit.md`)와 `flutter test tools/preview_avatar_audit_test.dart`(`build/avatar_audit/<girl·boy>.png`, 모든 아이템·피부톤×머리 비교 이미지). 이미 잘라낸 그림은 기록된 위치를 유지합니다. 측정값은 `tools/avatar_layers.json`에 저장됩니다.

### 소리 (`lib/game_audio.dart`, `lib/music_config.dart`, `lib/feedback_config.dart`)

| 소리 | 파일 | 언제 | 만든 방법·출처·라이선스 |
| --- | --- | --- | --- |
| tap | `audio/tap.wav` (0.12초) | 굽기. 최소 간격 60ms | 따뜻한 빵 손끝 '톡' + 작은 바삭. `tools/generate_sounds.py` 합성, CC0 |
| purchase | `audio/purchase.wav` (0.62초) | 구매 | 동전 세 개가 나무 계산대에 짤랑 + 종이봉투 바스락. 같은 도구, CC0 |
| reward | `audio/reward.wav` (0.90초) | 그 밖의 보상, 미션 달성, 돌아오기 환영 | 작은 가게 종 '딸랑'. 같은 도구, CC0 |
| levelUp | `audio/levelup.wav` (1.45초) | 레벨업·환생 | 가게 문 종 '딸랑딸랑' + 동전 쏟아짐. 같은 도구, CC0 |
| resultPerfect·resultGood·resultNear·resultFail | `audio/result_<perfect·good·near·fail>.wav` (0.6~1.3초) | 스페셜 붕어빵 결과 등급(26번 4단계) | 바삭+종 두 번·바삭+종·'퐁'·'툭'+'치익'. 같은 도구, CC0 |
| 굽는 소리 | `audio/sizzle_loop.wav` (16.40초 반복, 44.1kHz 모노 16bit, 약 1.45MB, 평균 −25.1dB·최고 −3.0dBFS) | 실제 굽기 활동이 있을 때(설정 '굽는 소리', 기본 꺼짐·50%) | **녹음** 'Crepe Making' — mefrancis13, Freesound 117602 (https://freesound.org/people/mefrancis13/sounds/117602/), **CC0**(표기 의무 없음, 기록용, 라이선스는 소리 페이지에서 확인 2026-11-18). 로그인 없이 받는 공개 고음질 미리듣기 MP3(60초 48kHz 모노, 원본 `4_image_generation_results_and_backups/26_feedback_generated/sounds/`)의 22.8~41.3초를 `tools/make_seamless_loop.py`로 크기 고르기(2초 이동 평균)·끝 2초 교차 페이드·튀는 소리만 −3dBFS로 눌러 이음매 없게 함(25번 소리1). 예비 합성본은 `tools/generate_cooking_sound.py`(CC0, 실행하면 녹음본을 덮어씀) |
| 배경 음악 | `audio/bgm_warm_stall.ogg` (171.04초 반복, OGG Vorbis q4 스테레오 48kHz, 약 2.3MB) | 모든 배경·시간(분위기 6종이 모두 이 곡) | 'Warm Bungeoppang Stall' — 사용자가 Suno **유료 요금제**로 2026-10-17에 만든 곡(태그 'created=2026-10-17T16:16:48Z', Suno 곡 id `29f264fe-0757-41e8-827f-c31b6b6bab3c`, 원본 `7_music/Warm Bungeoppang Stall.mp3`, SHA-256 `83fadd55…f7fbead3`). 유료 요금제 생성곡이라 상업 앱에 넣을 수 있음(사용자 확인 2026-11-18, S46-Q2). 크레딧 표기 의무 없음. `tools/prepare_bgm.py`가 끝 3초를 처음 3초에 같은 힘으로 겹쳐 이음매를 없애고 −6dB, 태그·표지 제거 |

- 효과음 8개는 한 계열('진짜 물건 소리 + 살짝 귀엽게', S46-Q4·Q5)입니다: 모두 44.1kHz 모노 16bit, 1.5초 이하, 앞 무음 10ms 이하, 최고 −3dBFS 이하, 소리 부분 평균 크기 차 2dB 안(`test/audio_assets_test.dart`). 녹음 소리 후보는 25번 '필요한 소리'.
- 기본 볼륨은 효과음 70, 음악 40입니다. 배경음은 처음부터 켬(`GameSettings.music` 기본 true). 26번 3차 H7(DEC-133): 설정 JSON에 `musicOnByDefault: true`를 함께 쓰고, 이 키가 없는 예전 저장(출시 전 테스트 기기)은 읽을 때 배경음을 한 번 켬. 그 뒤 끈 값은 그대로(계정 저장 형식 v14 유지).
- 앱이 백그라운드로 가면 음악을 멈춥니다.
- 26번 4-6단계에서 합성 배경음 `audio/bgm_<day·spring·dusk·rain·snow·night>.wav`(24초) 6개를 지웠습니다. 저장된 '배경음 선택' 값('auto'·분위기 id)은 계속 유효하고 저장 형식은 바뀌지 않았습니다(`validMusicSelection`). 설정 화면에서는 선택 드롭다운을 없앴습니다.
- MP3는 반복할 때 인코더 여백으로 틈이 생겨 쓰지 않습니다. iOS는 OGG를 못 틀므로 iOS 빌드 때 `prepare_bgm.py --m4a`로 만든 `.m4a`를 쓰도록 바꿔야 합니다(지금은 Android만).

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
| 시작 화면(스플래시) | Android 11 이하: `LaunchTheme`의 `drawable/launch_background.xml`(나무색 #68311F + `drawable-nodpi/splash.png` 붕어빵 틀 384×384). Android 12 이상(26번 3차 H1, DEC-134): 시스템 스플래시가 이것을 무시하므로 `values-v31`·`values-night-v31/styles.xml`에 `windowSplashScreenBackground` #68311F, `windowSplashScreenIconBackgroundColor` 크림 #FEF1D6, `windowSplashScreenAnimatedIcon` `drawable-nodpi/splash_icon.png`(1152×1152, 같은 그림을 1배 도트로 줄인 뒤 6배 정수 확대해 가운데 원 안에 맞춤). Flutter 첫 화면이 그려질 때까지 보임 |
| 앱 버전 | `pubspec.yaml` `version: 0.1.0+1`. `+` 뒤 versionCode는 Play 업로드마다 +1(재사용 불가), versionName은 가출시 동안 `0.1.x`, 정식 출시 `1.0.0` |
| release 서명 | `android/key.properties`(커밋 금지)의 업로드 키로만 서명. 파일이 없거나 항목·키 파일이 없으면 release 작업(`flutter build appbundle/apk --release`, `flutter run --release`)이 "Release build stopped (release 빌드 중단)" 오류로 멈춤. debug 키로 대체하지 않음. debug·profile은 키 없이 빌드됨. 키 만들기·빌드·설치: [release_signing.md](release_signing.md) |
| 권한(메인 매니페스트) | `INTERNET`(온라인 가출시, DEC-027), `POST_NOTIFICATIONS`·`RECEIVE_BOOT_COMPLETED`(26번 5-1 손님 알림), 광고 ID·광고 서비스 권한 4개는 `tools:node="remove"`로 제거(26번 5단계). 병합 결과(라이브러리가 넣는 `VIBRATE`·`USE_BIOMETRIC`·`USE_FINGERPRINT`·`BIND_GET_INSTALL_REFERRER_SERVICE` 포함)는 23번 6단계 '26번 반영 뒤 권한 다시 확인' 표(2026-11-19, profile로 확인한 뒤 같은 날 업로드 키 release APK로도 확인 — 13개 같음) |

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
| 효과음 다시 만들기 | `python tools/generate_sounds.py` (효과음 8개, 크기 맞춤까지) |
| 굽는 소리 다시 만들기 | 지금 녹음본: `python tools/make_seamless_loop.py ../4_image_generation_results_and_backups/26_feedback_generated/sounds/crepe_making_117602_preview.mp3 --start 22.8 --end 41.3 --seconds 16.4 --flatten 2` (`python tools/make_seamless_loop.py assets/audio/sizzle_loop.wav --check`로 이음매 검사). 예비 합성본: `python tools/generate_cooking_sound.py` |
| 배경음악 다시 만들기 | `python tools/prepare_bgm.py` (원본 `../7_music/Warm Bungeoppang Stall.mp3`를 읽기만), 이음매 검사 `python tools/prepare_bgm.py --check`. 필요: `pip install --user numpy imageio-ffmpeg` |
| 서버 배포 | `firebase_local.cmd deploy --only "functions,firestore"` (`firebase/` 폴더, [online_setup.md](online_setup.md) 4장) |
| 에뮬레이터 | `tools/run_android_emulator.ps1` |

**한글 경로 문제:** 셰이더 도구와 Kotlin 데몬이 한글 경로에서 실패합니다.
1. `subst B: "<프로젝트 경로>"`로 영문 드라이브를 만들고 `B:`에서 실행합니다.
2. 릴리스·debug APK 빌드는 추가로 `GRADLE_USER_HOME=D:\DevMoved\GradleCache`, `PUB_CACHE=C:\PubCacheBungeoppang`을 지정합니다(2026-11-17 debug APK도 이것 없이는 Gradle 데몬·`jni` CMake가 한글 사용자 폴더에서 실패). 빌드 뒤 기본 캐시로 `flutter pub get`을 다시 실행해 테스트 환경을 되돌립니다.
   `C:\GradleCache`는 `D:\DevMoved\GradleCache`로 가는 정션이다. 정션 경로를 Gradle 홈으로 쓰면 `*.gradle.kts`를 고친 뒤 다시 컴파일할 때 `Unresolved reference 'println'`·`'orEmpty'`처럼 Kotlin 표준 함수를 전부 못 찾고 실패한다(스크립트를 안 고치면 예전 컴파일 결과를 재사용해서 성공하므로 늦게 드러남). 2026-11-17 23번 6단계에서 확인, 실제 경로로 바꾸면 통과.
3. `processDebugResources`가 `Unable to delete directory … .ap_`(다른 프로세스가 사용 중)로 실패하면 방금 만든 파일의 일시적 잠금입니다. 코드를 고치지 말고 같은 명령을 다시 실행합니다(2026-11-03 재실행으로 통과).
4. 영문 경로의 작업 폴더(worktree, 예: `D:\s26wt\s6`)에서는 `subst`가 필요 없고 2번의 두 환경 변수만 지정하면 됩니다(2026-11-19 26번 6단계: debug APK 6분 22초·약 211MB, profile APK 3분 21초·128.9MB). 업로드 키 없이 release와 같은 라이브러리 병합 결과를 보려면 `flutter build apk --profile` 뒤 `C:\Android\sdk\build-tools\36.0.0\aapt.exe dump badging build\app\outputs\flutter-apk\app-profile.apk`와 `build\app\outputs\logs\manifest-merger-profile-report.txt`(권한마다 넣은 라이브러리)를 봅니다.

**분석 제외:** `analysis_options.yaml`은 `firebase/local_tools/**`(Firebase CLI가 받은 Dart 템플릿)를 분석하지 않습니다. 2026-11-17(23번 7단계, App Check·키 파일 뒤) 기준 `flutter analyze`는 error·warning 0(info 72), `flutter test`는 698개 통과·건너뜀 0(약 7~12분). 2026-11-19(26번 웨이브 9 병합 `862908e` 뒤, 26번 6단계) 기준 `flutter analyze` error·warning 0(info 71), 마지막 전체 `flutter test`는 웨이브 9 병합 때 904개 통과·5개 건너뜀(v2 골든 4개 포함), 서버 `npm test` 103개 통과. `no_tracking_sdk_test`의 release 병합 매니페스트 검사는 `build/app/intermediates/…/release/` 산출물(26번 5단계부터는 업로드 키 없이 만들 수 있는 `flutter build apk --profile`의 `…/profile/processProfileManifest/` 산출물도, 둘 중 새것)이 매니페스트·`build.gradle.kts`·`pubspec.lock`보다 새것일 때만 실행되고, 없으면 1개 건너뜀으로 나온다. 서버 `npm test`는 86개 통과, 에뮬레이터 통합 8개 통과입니다.

**온라인 빌드:** 키는 `1_app_development/dart_defines/online.json`(gitignore. `online.example.json`을 복사해 채움. 키 7개: `FIREBASE_API_KEY`·`FIREBASE_APP_ID`·`FIREBASE_SENDER_ID`·`FIREBASE_PROJECT_ID`·`KAKAO_NATIVE_APP_KEY`·선택 `APP_CHECK_DEBUG_TOKEN`·선택 `GOOGLE_SERVER_CLIENT_ID`(26번 2-1단계, Firebase 구글 로그인의 웹 클라이언트 ID. 없으면 구글 버튼이 숨음))에 두고 파일째 넘깁니다. 이 앱은 `google-services.json`을 쓰지 않고 Firebase 설정을 이 키들로 넣습니다.
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
| 소리 | audio_assets(파일·효과음 한 계열·굽는 소리 이음매), independent_music(배경음 선택 저장값·드롭다운 없음), step05_audio, stage10_feedback(길이·형식) |
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
   - **아바타 v2(26번 4-7단계 이후):** 25번 문서 43~49번 형식(42번 확정 바탕을 첨부해 같은 1120×2080 캔버스에 **그 아이템만**, 남녀 각 1장, 몸 뒤로 가는 머리는 `_back` 따로)으로 그림을 주문 → `4_image_generation_results_and_backups/26_feedback_generated/<번호>_<이름>/<성별>/<slot>_<id>.png`에 넣고 `python tools/avatar_v2.py --src <그 폴더>` → 칸 아이콘(31번 형식 512×512)도 같은 칸 전부 → `test/avatar_v2_test.dart`·`avatar_golden_test.dart` v2 골든(`--update-goldens`) 확인. 새 아이템은 `avatarV2Required`에 자동으로 들어가므로 그림이 없으면 v2 전체가 꺼집니다(섞이지 않게). 모자는 `avatar_v2.json` `hat_hair` 규칙을 확인합니다.
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
| 광고 | 제외. SDK 미도입·광고 버튼 숨김. 1장 '광고·추적 SDK 금지'와 `no_tracking_sdk_test` 유지. 2026-11-18: 광고는 출시 후 첫 업데이트(별도 브랜치, DEC-049), 분석은 `firebase_analytics`만 허용(DEC-045, 2026-11-19 26번 5단계 구현, 32장) | DEC-028 |
| 레벨 | Lv.1~50 전체(11~50은 임시 곡선). 2026-11-18 유지 재확인. 2026-11-19 26번 6단계 확인: Lv.50이면 레벨 창에 '최고 레벨에 도달했어요.'만 보이고 분점 '준비 중' 문구는 없음(할 일 1 건너뜀) | DEC-029, DEC-050 |
| 맛 | 팥 기본, 슈크림·초코 획득 경로 유지 | DEC-029 |
| 손님 | 네임드 8명 전체 + 무기명 | DEC-029 |
| 유료·온라인 노출 | 황금 상점(IAP)·유료 아바타 노출. 랭킹·친구·초대 숨김. 2026-11-18: 그림이 준비 안 된 유료 아바타는 숨김(모자 4종은 그림 적용으로 풀림, 지금 숨김 없음) | DEC-029, DEC-066 |
| 테스트 | Play 비공개 테스트로 바로 배포, 12~20명·14일 이상 | DEC-030 |
| 부분 판매 집계 | 판매 횟수 = 주문 완료 1회. 별점 = 판매 당시 품질·신선도 고정, 개수 가중 | DEC-017/023/007, DEC-018/022 |

날짜경계·영업종료/다음날복귀·맛별연습량/실패인정·5칸등록/숙련관계·주문표/보상·6구배정/주기/익힘/대기·신선도가격등은 [DEC](../00_공통기준.md#5-결정-관리)에미정으로남겼다. 차기저장버전/세션영속은미정,이전101시간일정은새범위에사용하지않는다. 기존실제일일미션KST자정은새영업일경계의확정근거가아니다.

## 17. 현재 환경 소스 변경 — 오디오 v13·공통 임시 계산

v13은 오디오 설정 musicSelection/cookingSound/cookingVolume만 추가한다. v1~12 자산 파싱은 유지하고 구형 자동 배경 모드를 보존한다. 사업 운영·숙련·재고/복합 거래의 실제 저장 이전은 포함하지 않는다. 변경·다운그레이드/실제 SQLite 검수는 미실행이다.

설정 화면의 배경음 선택은 배경/시간대와 독립이며 ‘배경에 맞춤’으로 기존 모드로 돌아간다. 굽기 루프는 실제 활동 소스가 있을 때만 별도 player로 출력하고 설정/음량·전경에 따라 정지한다. 실제 신규 스페셜 붕어빵/숙련된 붕어빵 제작 활동 전달은 미연결이다. 오디오 기본값은 development_balance.json에서 development_audio_defaults.dart로 생성한다. sizzle_loop.wav는 처음에 generate_cooking_sound.py로 직접 합성(CC0)했다. 26번 4-6단계에서 4초·양 끝 25ms를 0으로 줄이던 방식(4초마다 소리가 잠깐 꺼짐)을 20초 44.1kHz 원형 합성(이음매 없음)으로 바꿨고(2026-11-19 DEC-124로 CC0 녹음 'Crepe Making' 16.40초 반복으로 다시 바꿈, 합성 도구는 예비), 배경음 선택 드롭다운을 없애 새 곡 하나로 통일했다([12장 소리](#12-이미지소리)).

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

[23번 가출시 작업](../23_가출시우선작업프롬프트.md) 3단계. 사용자 선택: 홈 배치 **B안(왼쪽 세로 손님 줄 + 굽는 판 위 판매 카운터)**. 화면 배치는 10장 "Workshop 홈". (2026-11-18 26번 4-1단계 DEC-095로 대체됨: 낮춘 배경이 모두 있으면 손님이 매대 앞에 서는 구도, 왼쪽 줄은 예전 구도에서만)

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
| 영업 준비 중 | 스페셜 붕어빵 틀로 연습 제작만. '+붕어빵력' 버튼 없음. 숙련된 붕어빵 틀은 빈 틀(칸 글자·터치 없음) (DEC-035·036). **3단계 구현 완료**(10장 "두 틀 규칙"). 26번 4-2단계(DEC-099)부터 이 빈 틀 그림은 **닫히고 불 꺼진 판** | 3 |
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
| 처음 5분 기능 해금 | 하나씩 열기: 안내 중 굽기·영업·손님·판매·큰 붕어빵 / 안내 끝 꾸미기·상점 / Lv.2 스킬 창·초당 숫자 / 첫 숙련 6구 / Lv.3 도감 / Lv.4 레시피 / Lv.5 특별 주문·붕어빵 꾸미기 / 재고 하루 경과 시 신선도 안내 / Lv.8 가게 꾸미기. 핵심 진행은 레벨로 잠그지 않음. 새 설정 키 `feature_unlock_levels.skill_shop`(2), 공통 잠금 표시·소개 카드 | DEC-043 | 26번 2단계 **구현 완료**(2026-11-18, 10장 "처음 5분 해금", 3장 schema 8) |
| 초반 손님 간격 | 예외 없음. 튜토리얼 뒤 레벨과 관계없이 일반 30초~5분(DEC-106, 처음엔 1~15분)·네임드 30분~3시간 | DEC-044 | 26번 5-1단계 |
| 측정 방식 | `firebase_analytics` 도입(1장 원칙·`no_tracking_sdk_test`를 이 패키지만 허용으로), 광고 ID·SSAID·개인화 광고 신호 끔. 이벤트 10개 이하. 자체 서버 집계·`metrics_report.py`는 만들지 않음 | DEC-045 | 26번 5단계 **구현 완료**(2026-11-19, 32장) |
| 측정 대상·기본값·보관 | 로그인과 상관없이 모두(첫 실행 필수 동의 뒤부터, DEC-126·36장), 기본 켬, 첫 실행 안내 없음, 설정 '사용 통계 보내기'로 끔(`setAnalyticsCollectionEnabled(false)`). 보관 14개월(Analytics 무료판 최대) | DEC-046 | 26번 5단계 **구현 완료**(2026-11-19, 32장) |
| 매일 돌아올 이유 | 오늘의 특별 주문(주문서 카드) + 손님 이야기 하루 한 조각 + 겨울 계절 행사(장식·인사·주문 문구) + 출석 보상(7일째 황금 1, 서버 검증) | DEC-047 | 26번 7단계 |
| 매일 돌아올 이유 구현 세부 | 오늘의 주문서 Lv.5부터 KST 하루 1장(날짜+설치 고정, 영업 중 재고 납품, 붕어빵력 + 의뢰 단골 친밀도 +3, 황금 없음) / 출석 7칸 '도장 찍기'(걸러도 이어짐, 1~6칸 붕어빵력, 7칸 황금 1 서버 검증·직전 출석 황금에서 7일 이상, 서버 없는 빌드는 붕어빵력) / 이야기·후일담·선택 사건 합쳐 영업일당 1개 / 행사 날짜는 설정 `daily_return.seasonal_events`에만 | DEC-107~110 | 26번 7단계 (34장) |
| 공유 카드 | 넣음, 보상 없음. 완벽 결과·이야기·도감 완성·가게 사진 네 곳, 1080×1350 | DEC-048 | 26번 8단계 **구현함**(2026-11-19, 35장) |
| 공유 카드 구현 세부 | 카드 미리보기 창 → '공유하기' = 휴대폰 공유 창(사진첩 저장·권한 없음). 위 70% 가게 거리·사장님·붕어빵·손님, 아래 30% 배지·제목·대사 한 줄·'오늘의 붕어빵 · 곧 Google Play에서'(설정 `share.store_line_mode`). 개인 정보 없음, 상태 변화 없음, 사용 통계 `share` 하루 1번 | DEC-111~113 | 26번 8단계 (35장) |
| 보상형 광고 | 출시 후 첫 업데이트. 별도 브랜치 `s26/9-ads`에만, 출시 빌드에 광고 SDK 없음(DEC-028 유지). 충전 탭 + 황금 부족 안내, 광고 ID 안 씀, 만 13세 이상 | DEC-049 | 26번 9단계 |
| 출시 범위 | Lv.50 전체 유지(DEC-029). 26번 6단계 할 일 1 건너뜀 | DEC-050 | 26번 6단계 확인(2026-11-19, 코드 변경 없음) |
| 출시 범위 정리·23번 복귀 | 26번 서버 변경(2-1·3·4-4·4-5·4-7·5-1·7)은 단계마다 따로 배포하지 않고 한 번에, **서버 먼저·앱 나중**([online_setup.md](online_setup.md) 18장). 첫 업로드는 `0.1.0+1` 그대로. 23번 문서에 '26번 흥행 개선 반영' 표·6단계 '26번 반영 뒤 권한' 표·8단계 '가져갈 것' 표·9단계 검수표(처음5분·결제·통계·홈·스킬·꾸미기·매일·공유) 추가. 구글 로그인 라이브러리(androidx.credentials)가 가져오는 `USE_BIOMETRIC`·`USE_FINGERPRINT`(일반 권한)는 그대로 둠 | DEC-119~120 | 26번 6단계 **완료**(2026-11-19, 문서·빌드 확인만, 코드 변경 없음). 다음은 23번 7단계 콘솔 → 8 → 9 |
| 손님 방문 간격·알림 | 실제 시간: 일반 30초~5분(DEC-106)·네임드 30분~3시간, 자리 일반 3·네임드 1, 기다림은 켠 순간부터, 자정 자동 영업일 넘김, 네임드 하루 1회 제한·무기명 30% 폐지(직전 손님 제외), 튜토리얼 뒤 '맞이' 버튼 없음, 기기 안 알림(일반 끔·네임드 켬·밤 22~8시 끔 기본), 희귀 황금 3배. **구현 완료** (30장) | DEC-051~060 | 26번 5-1단계 |
| 스킬 황금 0 산식·검증 | 기본 황금 0이면 몇 번째든 0(10번마다 증가 없음). 황금 0은 스킬만 허용, 꾸미기·부스트는 1 이상. 앱·서버 같은 식, **서버 먼저 배포 후 앱** | DEC-061 | 26번 3단계 (4장) |
| 기존 구매자 | 황금으로 1~4단계를 산 사용자는 환불 없이 그대로 | DEC-062 | 26번 3단계 |
| 환영 황금 용도 | 10개 그대로, 꾸미기에 쓰도록 안내('꾸미기에서 써 보세요'), 충전 탭 '쓰는 곳' 한 줄, Workshop 상점은 꾸미기 탭으로 열림 | DEC-063 | 26번 3단계 (8장) |
| 스킬 레벨업 로그인 | 지금처럼 로그인 필요(DEC-021). 스킬 창에 '카카오 로그인 후 레벨업할 수 있어요' + 로그인 버튼, 로그인 전 구매는 거래를 만들지 않음 | DEC-064 | 26번 3단계 (4장) |
| 성장 속도 | 그대로. 황금 0 서버로 Lv.10 9분, 5단계 개방 Lv.15~21. 5-1(손님 간격) 뒤 다시 확인 | DEC-065 | 26번 3단계·5-1 |
| 아바타 그림 매칭 | 머리 = 입은 모습 레이어 + `_cut`, 피부톤 = 도구 색 치환 복사본(`@skin2·3`), 정면만. 기본 앞치마를 그림으로 입히고 무료 '앞치마 없음'(`noapron`) 추가. 그림이 준비 안 된 유료 아바타는 꾸미기·상점에서 숨김(보유자에겐 보임). **구현함**(7장, 2026-11-18) | DEC-066~068 | 26번 4-4단계 |
| 배경음악·굽는 소리·효과음 | 새 곡 'Warm Bungeoppang Stall' 하나로 모든 분위기 통일(Suno 유료 요금제, 출시 빌드에 넣음, 출처 12장), 설정 '배경음 선택' 없앰(저장값 유지), 굽는 소리 이음매 없는 반복(처음 20초 합성 → DEC-124로 CC0 녹음 'Crepe Making' 16.40초), 효과음 4종을 결과음과 같은 '진짜 물건 소리 + 살짝 귀엽게' 계열·크기로. **구현함**(12장, 2026-11-18) | DEC-089~091·DEC-124 | 26번 4-6단계 |
| 스킬 창 레벨업 방식 | 스킬 창은 레벨업 목록: 칸 = 그림·이름·'Lv.12/1000'/'+60/클릭'·비용·스킬별 돌림판·'LEVEL UP' 버튼(시안 확인 2차 DEC-128, 처음엔 둥근 '+'와 창 위 돌림판 하나). 단위 ×1·×10·×100, 실제 양 = min(단위, 1000 − 레벨), '최대' 없음. 모자라면 '+' 끔·모자란 비용 빨강·꺼진 '+'는 이유 안내. 'Lv.' 통일, 미션 '스킬 레벨업 횟수'. 잠긴 스킬은 다음 하나만 실루엣+자물쇠, 조기 해금 없음. 공통 잠금 `LockedOverlay`(hatch·hidden)·재화 `CurrencyAmount`. **구현함**(4장, 10장, 2026-11-18) | DEC-092~094 | 26번 4-3단계 |
| 홈 손님·매대·판매 카운터 | 낮춘 배경 14장(`bg_low/`)이 모두 있으면 손님이 매대 앞에 섬(맨 앞 크게·뒤 0.8배, 최대 4명, 머리 위 남은 시간 막대·반응 말풍선), 클리커 0.8배로 카운터 위, 매대·대사는 짧은 이름, 카운터는 글만 + 버튼은 화면 가운데, 상태는 나무 간판, 주기 저장 중 깜빡임 없음(`inputBusy`). **구현함**(10장, 12장, 24장, 2026-11-18) | DEC-095~098 | 26번 4-1단계 |
| 사용 통계 구현 세부 | `firebase_analytics` 12.6.1, 광고 ID·SSAID·광고 서비스 권한 제거, dart-define으로 `google_app_id` 리소스, 설정을 읽은 뒤 수집 켬, 직접 이벤트 7종, 선택 정보 `gender`·`age_band`, 설정 '사용 통계 보내기'. **구현함**(32장, 2026-11-19) | DEC-084~088 | 26번 5단계 |

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
| 26번 배포 묶음 (2026-11-19) | 26번 서버 변경은 아직 배포 전. 4장 배포는 online_setup.md 18장(검사 `npm test` → `firebase_local.cmd deploy --only "functions,firestore"` → 그 뒤에만 AAB)으로 한 번에. 16장(구글 로그인)·17장(Analytics)도 이 묶음 전에 |

## 30. 손님 방문 간격·알림 — 2026-11-18

[26번 5-1단계](../26_흥행개선단계별프롬프트.md#5-1단계--손님-방문-간격과-알림). 결정은 00_결정취합.md `DEC-051`~`10`(병합 때 번호). 설정값은 `config/development_balance.json` `customer_arrivals`·`customer_notifications`(하드코딩 없음, 14번 문서에 자동 반영).

| 규칙 | 내용 | 코드 |
| --- | --- | --- |
| 손님 시계 | 일반(무기명)·네임드 두 개가 따로 돎. 간격 = `min + hash(seed, draws) % (max − min + 1)`(고정 32비트 해시)이라 미리 정해짐 → 알림 예약 시각 = 실제 도착 시각. 일반 `regular_min_ms` 30000~`regular_max_ms` 300000(30초~5분, DEC-106 — 처음엔 1~15분), 네임드 `named_min_ms` 1800000~`named_max_ms` 10800000 | `lib/workshop_arrivals.dart` `ArrivalClock`·`WorkshopArrivals` |
| 자리 | 일반 `regular_slots` 3, 네임드 `named_slots` 1. 켜 있을 때도 같은 자리. 자리가 차면 그 시계가 멈추고(`nextAt` null), 판매·시간 초과로 자리가 나면 그 순간부터 다음 간격. 예전 레벨별 `max_queue` 열은 없앰 | `WorkshopArrivals.resume`·`arrived` |
| 시간 기준 | 영업 정산 시각(`business.settledUtc`, 뒤로 안 감)까지의 사건을 시각 순서로 처리. 기기 시계를 되돌려도 지난 도착이 다시 생기지 않고, 앞당겨도 자리 수에서 막힘. 앱이 꺼져 있어도 흐름(복귀·재실행 때 한꺼번에) | `WorkshopController._syncArrivals` |
| 기다림 | 꺼진 동안 온 손님도 `order_wait_ms`를 다 가진 채 생기고, 기다림은 앱이 앞에 있을 때만 줄어듦(켠 순간부터) | `_advanceMemory` |
| 자정 | 열린 가게는 KST 자정에 저절로 다음 영업일(`BusinessProgress.nextDay`) + 재고 나이·준비품 수락·미션 '영업한 날'. 같은 처리 순서 안에서 자정 뒤 손님은 새 영업일로 관계·소개를 셈. 여러 날 비워도 한 번만(S5-1-Q3) | `_startBusinessDay(next: true)` |
| 멈춤 | 이야기 장면·광고 중에는 도착·자정 처리를 미루고 끝난 뒤 처리. 손님 도착으로 후일담 장면이 열리면 그 뒤 사건은 장면 뒤로 | `_syncArrivals` |
| 네임드 고르기 | 처음은 도윤 → 못 만난 손님이 있고 그 영업일 소개 2명(`new_npcs_daily_limit`) 미만이면 목록 순서로 소개 → 아니면 만난 손님 중 직전 네임드(`lastNamedVisitor`)·줄에 선 사람을 뺀 무작위(시계 해시). 한 명뿐이면 그 사람. 하루 1회 제한(`visits_per_npc_business_day`)·무기명 30%(`anonymous_visit_basis_points`)는 설정에서 없앰. 일반 시계는 늘 무기명, 네임드 시계는 늘 네임드(못 고르면 그 회차 건너뜀). `holiday_visit_basis_points`(은채 쉬는 날)는 그대로 | `WorkshopRelationships.selectNamedVisitor` |
| 첫 실행 안내 | 안내 중(`cook`/`sell`)엔 시계 없음. 줄이 비었으면 도윤이 바로(처음), 그 뒤엔 `customer_arrival_interval_ms`(15초) 뒤 한 명(무기명). 안내 '맞이' 버튼도 이때만. 첫 판매로 `done`이 되거나 건너뛰면 같은 명령에서 두 시계 시작. `customer_arrival_interval_ms`는 안내용 + 서버 판매 한도 계산용으로 키 유지 | `WorkshopController._tick`, `welcomeCustomer` |
| 짧은 이름 | `customer_content.json` `short_name`: 도윤·윤하 씨·막례 할머니·오 작가님(이야기 뒤 서진 씨)·태오 씨·은채 씨·민재 씨·수아 씨. 조사 이/가는 받침으로(`withSubjectParticle`) | `WorkshopCustomerCatalog.shortName` |
| 알림 예약 | 앱이 `paused`/`hidden`이 될 때만(inactive 아님) 저장 뒤 `upcomingArrivals(preview_horizon_ms 24시간)`으로 올 손님(일반 ≤3·네임드 ≤1)을 계산 → 끈 종류 빼기, 일반은 `regular_max_notices` 3번까지, 밤 끄기 켜면 기기 시각 `quiet_start_minute` 1320(22:00)~`quiet_end_minute` 480(08:00) 알림만 건너뜀(손님은 옴) → 모두 취소 후 예약. `resumed`에서 모두 취소. 영업 닫힘·안내 중·이야기 장면 중이면 예약 없음 | `ui/game_app.dart` `_scheduleNotices`, `planCustomerNotices` |
| 알림 문구 | 제목 '오늘의 붕어빵'. 일반 '손님이 붕어빵을 사러 왔어요! 가게로 가 볼까요?', 네임드 '{짧은 이름}{이/가} 찾아왔어요. 따끈한 붕어빵을 기다려요.' 누르면 앱이 홈으로 열리고 손님이 기다림. 채널 '손님 알림'. 아이콘 `res/drawable-<dpi>/ic_stat_customer.png`(흰 붕어빵 실루엣 24~96px, 25번 21번, `tools/notification_icon.py`로 생성) | `lib/customer_notifier.dart` |
| 알림 드라이버 | `CustomerNotifier`(schedule·cancelAll·requestPermission·hasPermission — 묻지 않고 지금 허용됐는지, Android `areNotificationsEnabled`·iOS `checkPermissions`). 앱은 `LocalCustomerNotifier`(Android만, `inexactAllowWhileIdle`, UTC `TZDateTime`), 테스트는 가짜. 예약 실패는 게임을 막지 않음. `build.gradle.kts` core library desugaring, 매니페스트에 예약·부팅 수신기 | `main.dart`, `android/app` |
| 설정 화면 | 설정 창 '모션 줄이기' 아래 '일반 손님 알림'(기본 끔), '단골 손님 알림'(기본 켬), '밤 알림 끄기 (밤 10시~아침 8시)'(기본 켬). 켤 때 권한을 묻고, 거절되면 그대로 꺼진 채 '휴대폰 설정에서 이 앱의 알림을 허용해야 받을 수 있어요.' 일반·단골 중 하나라도 켜져 있는데 휴대폰이 알림을 막고 있으면 단골 스위치 아래에 '알림 권한이 필요해요 — 휴대폰이 이 앱의 알림을 막고 있어 켜 둔 알림이 오지 않아요.' + '권한 허용하기'(`settings-notice-permission`, 누를 때만 다시 요청, 거절이면 위 안내). 설정 창을 열 때와 앱이 앞으로 돌아올 때 다시 확인(DEC-105, `ui/notice_permission_hint.dart`). 저장은 `GameSettings` `notifyRegularGuests`·`notifyNamedGuests`·`quietNightNotices`·`notificationPromptDone`(없으면 기본값, 계정 저장 v13 그대로) | `ui/workshop_page.dart` `_audioSettings`·`_setNotice` |
| 권한 묻기 | 안내가 끝나고(또는 건너뛰고) 첫 판매가 끝난 뒤 한 번 창 '손님 알림 — 손님이 찾아오면 알려 드릴까요? 앱을 꺼 둬도 단골손님이 오면 알림으로 알려 드려요.' [나중에][알림 받기]. 어느 쪽이든 다시 묻지 않음(다음 실행 때도). '알림 받기' → Android 13+ 권한 창. 허용·거절·'나중에' 모두 스위치는 그대로(단골 켬·일반 끔 기본값, DEC-105). '나중에'는 권한 창을 띄우지 않고, 거절이면 위 안내 문구. 권한이 없는 상태는 설정 창의 '알림 권한이 필요해요' 줄로 보임 | `_askNotifications` (`notice-prompt`) |
| 희귀 황금 | 별 1~5 확률 300·600·900·1200·1500(3·6·9·12·15%), 하루 최대 10 그대로. 서버 생성본 갱신(revision 그대로) — **서버를 다시 배포하기 전까지 서버는 옛 확률(1~5%)로 추첨** | `rare_gold_sale`, `firebase/functions/src/generated/development_balance.json` |

테스트: `test/workshop_arrivals_test.dart`(시계 범위·결정성, 30초·5분·3시간, 자리 상한·재시작, 시계 되돌림·1년 앞당김, 영업 닫힘, 자정 넘김·새 영업일 손님·미션, 기다림은 켠 순간부터, 미리보기 = 실제 도착, 이야기 장면 보류, 안내 → 시계 시작, schema 6→7·잘못된 7 거절, 밤 판정, 알림 계획, 설정 저장, 수명주기 예약·취소, 권한 묻기 3가지(허용·거절·나중에 — 단골 켬 유지), 설정 권한 안내(거절·복귀 뒤 사라짐·스위치 끄면 숨김), 내린 뒤 일반 손님 15분 안 최대 3명), `test/workshop_customers_test.dart`(소개 하루 2명·하루 1회 없음·직전 제외·1명뿐·짧은 이름·조사), `test/no_tracking_sdk_test.dart`(권한 3개·정확한 알람 없음·메시징 없음), `test/workshop_progression_simulation_test.dart`(평균 간격 3분마다 판매: Lv.5 12분·Lv.10 27분), 서버 `test/sale_rewards.test.ts`(생성본 확률 = 앱). 에뮬레이터 알림 수신 확인은 26번 5-1단계 결과 표. 확인용 debug 빌드: `flutter build apk --debug --dart-define=CUSTOMER_NOTICE_SELFTEST=true`(13장대로 `GRADLE_USER_HOME`·`PUB_CACHE` 영문 경로) — 앱을 내리면 진짜 예약에 더해 1분 뒤 '[시험] …' 알림 하나를 예약(`main.dart` `_SelfTestNotifier`, release에서는 꺼짐). AVD `TodayBungeoppang_API35`가 없으면 `avdmanager create avd -n TodayBungeoppang_API35 -k "system-images;android-35;default;x86_64"`로 만든다.

## 31. 첫 실행 로그인·사장님 이름·캐릭터 — 2026-11-18

26번 2-1단계(DEC-076~083). 원칙은 1장 '첫 실행 로그인 필수', 시작 순서는 2장, 저장은 3장 "첫 실행 기록 저장", 로그인·서버 함수·Firestore는 9장, 설정·메뉴 화면은 10장, 빌드 키는 13장 "온라인 빌드". 개인정보처리방침·이용약관(`terms_of_service.md`, 새 문서)·Play 데이터 보안 문서·online_setup.md 16장(콘솔 작업)을 같은 작업에서 고쳤다.

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 화면 | ① 필수 동의 + 카카오/구글 ② 사장님 이름 ③ 여자/남자 사장님 ④ 선택 성별·연령대 → 2단계 첫 실행 안내 | `lib/ui/first_run.dart` |
| 상태 | `OwnerAccount`(`step`, `signIn`·`acceptConsent`·`setName`·`chooseCharacter`·`saveOptional`·`skipOptional`·`clearOptional`·`signOut`·`deleteAccount`·`pushProfile`) | `lib/owner_account.dart` |
| 문구 | 첫 실행·계정 설정 문구 한 곳 | `lib/owner_texts.dart` |
| 분석 연결 지점 | `OwnerAnalytics.setUserProperties(gender, ageBand)` — 선택 동의한 값만(만 14세 미만 연령대는 36장에서 없앰), 이메일·이름은 절대 안 보냄. `OwnerAnalytics.setConsented(bool)` — 필수 동의 여부(36장).  26번 5단계에서 `UsageOwnerAnalytics`로 Firebase Analytics 사용자 속성 `gender`·`age_band`에 연결('선택 안 함'은 지움, 32장) | `lib/owner_account.dart` |
| 서버 | `auth.ts`(구글 허용), `account.ts`(`setAccountProfile`·`rememberEmail`·`deleteAccount`), `kakao.ts`(이메일), `index.ts`(`accountProfileSet`·`accountDelete`). **배포 필요** | `firebase/functions/src` |
| 테스트 | 앱 `test/owner_first_run_test.dart` 25개·`test/first_run_golden_test.dart` 2개(골든 5장), 서버 `test/account.test.ts` 8개 + `kakao.test.ts` 3개 추가·수정 | |

## 32. 사용 통계(Firebase Analytics) — 2026-11-19

26번 5단계(DEC-045·046, DEC-084~088). 목적은 "어디까지 와서 그만두는지". 원칙은 1장 첫 줄, 설정은 10장 '사용 통계 보내기', 개인정보는 [privacy_policy.md](privacy_policy.md) 1-3절·[play_data_safety.md](play_data_safety.md).

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 패키지 | `firebase_analytics` 12.6.1(firebase_core 4.15.x와 맞는 12.x 마지막 안정판, 고정). 하위 `firebase_analytics_platform_interface` 6.0.7·`firebase_analytics_web` 0.6.1+13. Android 쪽은 `play-services-measurement` 23.2.0 계열 | `pubspec.yaml` |
| 매니페스트 | meta-data `firebase_analytics_collection_enabled` false(첫 실행 필수 동의를 마치고 설정이 켬일 때 `setAnalyticsCollectionEnabled(true)`를 부르기 전엔 수집 안 함 — 자동 `first_open`·`session_start`도, 그 뒤엔 Firebase가 마지막 값을 기억하므로 동의 전 상태에서는 시작할 때마다 false를 다시 알림, 36장), `google_analytics_adid_collection_enabled`·`google_analytics_ssaid_collection_enabled`·`google_analytics_default_allow_ad_personalization_signals` 모두 false. `AD_ID`·`ACCESS_ADSERVICES_AD_ID`·`_ATTRIBUTION`·`_TOPICS` 권한 `tools:node="remove"`. 선택 라이브러리 `android.ext.adservices`(Privacy Sandbox)도 `tools:node="remove"`. 병합 뒤 새로 생기는 것: 권한 `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`(설치 경로), `AppMeasurementReceiver`·`AppMeasurementService`·`AppMeasurementJobService`, 구성 요소 `AnalyticsConnectorRegistrar`·`FlutterFirebaseAppRegistrar`(analytics). `ACCESS_NETWORK_STATE`·`WAKE_LOCK`은 원래 있음 | `android/app/src/main/AndroidManifest.xml` |
| Firebase 앱 ID 리소스 | 이 앱은 `google-services.json`을 쓰지 않으므로 `android/app/build.gradle.kts`가 `--dart-define`의 Firebase 키 4개를 문자열 리소스 `google_app_id`·`google_api_key`·`gcm_defaultSenderId`·`project_id`로 넣음(`buildFeatures.resValues`, 네 값이 모두 있을 때만). Analytics가 앱 ID를 이 리소스에서 읽음. Firebase가 같은 값으로 기본 앱을 먼저 만들고 Dart `Firebase.initializeApp(options:)`은 apiKey가 같아 그 앱을 그대로 씀 | `android/app/build.gradle.kts` |
| 기록기 | `UsageStats`(이벤트·하루 1번·평생 1번 판정, 끄기) + `UsageStatsSink`(`FirebaseUsageStatsSink` / 아무것도 안 보내는 `NoUsageStatsSink`: 키 없는 빌드·테스트). 모든 호출은 기다리지 않고 오류를 삼킴 | `lib/usage_stats.dart`, `lib/firebase_usage_stats.dart` |
| 이벤트 10종 | `first_bake`(첫 굽기 결과), `first_sale`(첫 판매), `tutorial_done`(`result`: done/skipped), `level_reached`(`level`: 3·5·10), `shop_open`(상점 창, 한국 날짜로 하루 1번), `pay_view`(황금 충전 탭·충전 목록, 하루 1번), `pay_done`(`product_id`만, 금액 없음, 서버 확인 뒤 결제마다), `special_order_done`(오늘의 주문서 납품, `event`: 행사 ID 또는 none, 26번 7단계), `event_join`(행사 기간 첫 접속, 행사마다 1번, `event`: 행사 ID), `share`(공유 카드를 공유 창으로 보냄, 하루 1번, `moment`: perfect·story·collection·shop, 26번 8단계 — 이것으로 10개 상한). 첫 실행·재방문은 Analytics 자동 `first_open`·`session_start`. 9단계 `ad_reward`는 출시 후 별도 브랜치에서 다시 셈(하나를 빼거나 합쳐야 함) | `UsageEvent` |
| 보내는 때 | Workshop 진행 6종은 `WorkshopController.command`가 **저장에 성공한 뒤** `finally`에서 명령 전후 `UsageProgress`(굽기 수·판매 수·레벨·안내 상태·오늘 납품한 주문서 날짜·들어온 행사)를 비교해 보냄(명령·저장 트랜잭션 안에서 보내지 않음, 실패한 명령은 안 보냄). 구형 저장(schema 5 이하)을 안내 끝으로 읽는 경로·다시 열기는 명령이 아니라 아무것도 안 보냄. `shop_open`은 `WorkshopPage._store`, `pay_view`는 `GoldChargeTab.initState`·`_goldPacks`, `pay_done`은 `PremiumCommands`의 서버 지급 성공 뒤 | `workshop_controller.dart`, `ui/workshop_page.dart`, `ui/gold_widgets.dart`, `premium_controller.dart` |
| 사용자 속성 | 선택 정보 동의 시 `gender`·`age_band`('선택 안 함'은 null로 지움). `setUserId`는 쓰지 않음 | `UsageOwnerAnalytics` |
| 끄기 | `GameSettings.sendUsageStats`(기본 true). 시작 때와 바꿀 때 `setAnalyticsCollectionEnabled(설정 && 동의)`. 끈 동안은 기록기가 이벤트를 넘기지 않음(사용자 속성은 넘기지만 Analytics 수집이 꺼져 있어 보내지 않음) | `game_controller.dart` |
| 첫 실행 동의 전 (36장) | `main.dart`가 `UsageStats(FirebaseUsageStatsSink(), consented: false)`로 만듦 → `GameController.initialize`의 `setEnabled(설정)`은 `false`를 알림. `OwnerAccount`가 읽기·저장마다 `setConsented(requiredConsentDone)`(= 로그인 없는 빌드이거나 `consentVersion == requiredConsentVersion`)을 알리고, 값이 바뀔 때만 Analytics에 `setAnalyticsCollectionEnabled(collecting)`. 재동의가 필요한 기존 사용자·계정 삭제 뒤에도 다시 멈춤. `collecting = enabled && consented`가 거짓이면 이벤트를 넘기지 않음 | `usage_stats.dart`, `owner_account.dart`, `main.dart` |
| 보관·보기 | Analytics 이벤트 데이터 보존 14개월(무료판 최대, 콘솔에서 설정). 10년 보관은 BigQuery 내보내기로만 가능(online_setup.md '사용 통계') | — |
| 테스트 | `test/usage_stats_test.dart`(이름 규칙·하루 1번·끄기·오류 격리·진행 비교·사용자 속성·Workshop 한 바퀴·저장 실패·skip·구형 저장·설정 호환·충전 탭), `test/no_tracking_sdk_test.dart`(허용 목록 3개 추가, 매니페스트 끄기 스위치·광고 권한 제거, release/profile 병합 매니페스트) | |

## 33. 꾸미기·상점 화면 정리 — 2026-11-19

26번 4-5단계(F25~F36, 2차 녹화 G1·G2·G5·G8·G12~G15, DEC-100~104). 배치는 10장 '꾸미기·상점 역할', 칸·이름은 7장, 저장은 3장(계정 v14·가게 schema 9), 그림은 12장.

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 역할 | 꾸미기 = 가진 것 입기(여러 칸 '모두 적용'), 상점 꾸미기 탭 = 사고 바로 입기. 구매는 지금처럼 1건씩(서버 변경 없음) | `lib/ui/workshop_wardrobe.dart`, `public_menus.dart`(`CosmeticMenuAccess.forSale·cost·tabOpen`), `shop_panel.dart`, `workshop_page.dart` |
| 누적 조건 | 화면에서만 뺌('Lv.N 해금'). `unlock_total` 값 0과 서버 검사는 그대로 | `workshop_page.dart` `_cosmetics.requirement` |
| 칸 이동 | 요리사 복·패딩 조끼 outfit → top(`movedToTop`), 설정 `avatar_catalog` slot, 서버 생성 JSON, 그림 파일 이름 `top_*`, `tools/avatar_layers.py` `WORN_ITEMS`·`WORN_ROWS['top']`, `concept_avatar.py`. **서버 생성 설정이 바뀌어 배포 묶음에 포함** | `cosmetic_config.dart`, `config/development_balance.json`, `firebase/functions/src/generated/development_balance.json` |
| 잔액 줄·제목 | 모든 Workshop 창 공통(10장) | `workshop_windows.dart` |
| 그림 적용 | `python tools/apply_25_art.py ../4_image_generation_results_and_backups/26_feedback_generated --only room --only title --only stall16 --preview` | `tools/apply_25_art.py` |
| 테스트 | `test/workshop_wardrobe_test.dart`(17개, 골든 `wardrobe_hair_390x844`·`wardrobe_stall_390x844`·`shop_avatar_390x844`), 창 골든 다시 만듦(`skill_shop_*` 3장·`workshop_home_menu_*` 4장: 잔액 줄·제목 붕어빵) | |
| 시안 | `tools/preview_wardrobe_options_test.dart` → `build/preview/wardrobe_options.png` | |
| 3차 녹화 피드백 B2 (2026-11-19, H11~H16, DEC-129) | 사장님·피부톤 판매(7장), 꾸미기 창에 파는 것도 보이고 '모두 취소·모두 사기·모두 적용' 작은 버튼 줄, 다 입으면 창 닫힘, '입어 보는 중' 칩, ↺ 없앰, 탭이 폭을 나눔(10장). 저장 `avatarGrants`(3장). **서버 생성 설정 변경 → 배포 필요** | `workshop_wardrobe.dart`, `workshop_controller.dart`, `owner_account.dart`, `config/development_balance.json`; 비교 `tools/preview_h_b2_test.dart` → `build/preview/h_b2/` |
| 시안 확인 2차 (2026-11-19, DEC-128) | 탭·칸 = (나) 책갈피 탭 + 각진 카드, 가게 탭 미리보기 = 사장님 없는 가로 노점 장면(`StallPreviewPainter`), 창 제목 붕어빵은 25번 35번 다시 그리기 전까지 없음. '모두 적용' 자리·'입어 보는 중' 리본은 그대로. 저장 형식·서버 변경 없음. 홈·스킬 창 변경은 10장·4장 | `workshop_wardrobe.dart`, `pixel_sprites.dart` `TitleFish`; 비교 `tools/preview_ui_r2_test.dart` → `build/preview/ui_r2/` |

## 34. 매일 돌아올 이유 — 2026-11-19

26번 7단계(DEC-047·DEC-107~110, S7-Q1 주문서 카드·S7-Q2 7일째 황금 1·S7-Q3 장식+인사+주문 문구). 설정은 `config/development_balance.json` `daily_return`(행사 날짜는 이 설정에만, 코드에 날짜 없음), 저장은 3장 schema 10, 화면은 10장 '오늘' 쪽지.

| 항목 | 규칙 | 위치 |
| --- | --- | --- |
| 하루 경계 | 정산 시각의 KST 날짜(`today`). 시계를 되돌리면 그대로, 앞당기면 그 날로(여러 날 지나도 한 번). 첫 실행 안내 중에는 아무것도 열리지 않음. 모든 명령 뒤와 복귀 때 `_observeDaily`가 날짜·행사·주문서만 기록(보상 없음) | `WorkshopController._observeDaily` |
| 오늘의 주문서 | **특별 주문(Lv.5, `ordinary_sale.special_order_unlock_level`, 기능 소개 카드 '특별 주문이 와요')부터** 하루 1장. 날짜 + 설치(`grid.runId`)로 고정(`makeDailyOrder`, 같은 날은 언제 봐도 같음): 가진 맛 중 하나, 익힘 1~3(부드러움·미디엄·바삭함), 1~`quantity_max`(2)개, 의뢰인은 만난 단골 중 한 명(없으면 '동네 손님'), 행사 중이면 행사 ID. **영업 중에만** 재고에서 맞는 맛·익힘(5영업일 미만, 오래된 것부터)을 '납품하기'. '주문서 굽기'는 영업 중 큰 틀에서 그 맛을 주문 제작(손님 없이, 결과는 재고로). 보상: 붕어빵력 = max(초당 자동 생산 × `reward_seconds` 600, `min_buns` 200) + 의뢰 단골 친밀도 `affinity` 3(관계 기록 `special:<날짜>`, 자기 칸 `special` 하루 상한 `customer_relationships.special_daily_cap` 3, 판매·대화 상한과 따로). **황금 없음**. 하루 1번, 납품하지 않으면 다음 날 새 주문서로 바뀜 | `lib/workshop_daily.dart`, `deliverDailyOrder`, `startDailyOrderProduction`, `WorkshopRelationships.specialOrder` |
| '오늘' 창 (3차 피드백 H36~H40, DEC-135·136) | 홈 오른쪽 위 설정 버튼 아래 '오늘' 버튼(글씨 없이 달력 아이콘, 52×52)이 여는 Workshop 전체 창 '오늘'(`today-scroll`). 위에서부터 행사 띠 → 출석 도장 → 오늘의 주문서 → 일일 미션 → 주간 도전, 각 칸은 밝은 카드(`TodaySection`). 출석 = 빨간 도장 원 + 흰 체크, 칸 최대 40, '7번 출석하면 황금붕어빵력 1개'(`cycle_days`·`gold`, 서버 없으면 대신 주는 붕어빵력). 아이콘: 출석 `AttendanceStampIcon` = `icons/stamp.png`(나무 손잡이 빨간 도장)·주문서 `DailyOrderIcon` = `icons/order.png`(집게 꽂힌 주문 쪽지, 붕어빵 그림), 둘 다 72×72 `PixelIcon`(화면 26, 25번 38번 생성 그림 `tools/apply_25_art.py --only today`)·버튼 `icons/daily.png`(달력). 미션은 기간('11월 16일(월) ~ 11월 22일(일)'·'N일 남음'), 칸마다 진행 막대·숫자·황금, 다 채운 것만 '보상 받기'(받으면 '받았어요'). 메뉴에는 일일 미션·주간 도전 줄 없음. 미션 보상이 있거나 도장·주문서가 남으면 버튼 빨간 점 | `ui/workshop_daily_card.dart` `WorkshopDailyTicket`·`WorkshopDailyCard`·`WorkshopMissionSection`, `ui/workshop_page.dart` `_daily`·`_claimMission` |
| 출석 도장 | 7칸(`cycle_days`). KST 하루 처음 '도장 찍기'로 다음 칸(자동 아님, 쪽지 빨간 점으로 알림). 하루를 걸러도 이어지고, 7칸 뒤 다음 도장은 1칸부터. 1~6칸: 붕어빵력 max(초당 × `buns_seconds` 300, `min_buns` 100). 7칸: **황금 `gold` 1** — 서버가 있는 빌드는 `pendingGold['attendance:<날짜>']`로 신청해 미션 황금처럼 서버 검증 뒤 지갑에(쪽지에서 찍으면 로그인 상태일 때 바로 `syncRewards`), 서버가 없는 빌드는 붕어빵력 max(초당 × `substitute_seconds` 1800, `substitute_min_buns` 600)로 대신(첫 실행 로그인이 필수라 출시 빌드는 황금) | `stampAttendance`, `attendanceClaim` |
| 이야기 하루 한 조각 | 이야기 장면·후일담·선택 사건을 합쳐 영업일당 `story_daily_limit` 1개(`storiesOpenedToday`: 그날 `storyDays`·`followupDays`·`lastChoiceDay` + 지금 보이는 장면). 넘치면 그 손님 판매 뒤 장면 대신 '내일 ○○가(이) 이야기를 이어 갈 것 같아요.'(짧은 이름, 카운터 안내 줄), 다음 영업일 그 손님 판매 때 열림. 저장 변경 없음 | `_afterNamedSale`, `_spawnCustomer` |
| 겨울 행사 | `seasonal_events`: 첫눈 `first_snow_2026` 12/1~12/7(`event_first_snow` 눈 쌓인 처마 + 눈사람), 크리스마스 `christmas_2026` 12/20~12/26(`event_christmas` 빨강·초록 전구 줄 + 리스), 설날 `seollal_2027` 2027-02-05~02-09(`event_seollal` 색동 초롱 줄 + 복주머니). 기간 안(양 끝 포함, KST)이면 ① 홈의 가게 장식을 행사 장식으로 바꿔 그림(가진 장식과 상관없이, 입은 장식 기록·꾸미기 창은 그대로 `WorkshopPage._homeEquipped`. 행사 전용 장식 `deco/event_<kind>.png`(25번 32번 생성 그림, 2026-11-19 적용: 폭 540 = 장면 180 × 3, 높이 87·156·144, 알파 40 미만 0·215 초과 255). 판매 목록에 없는 장식이라 `CosmeticDefinition` 없이 `PixelSprites.eventDecorations`로 읽고, 자리는 `NightStallPainter.decorationAt`의 별 전구와 같은 (0, 104) — 첫눈만 좌우 뒤집어 눈사람이 왼쪽(오른쪽 '오늘' 버튼과 안 겹침). 설정 검사 `development_balance.py`가 판매 장식 + 이 3개 id만 받음) ② 손님 창 첫 줄에 행사 인사 ③ 그날 주문서에 행사 문구(`order_note`)와 쪽지 카드 위 행사 띠. 새 재화·판매 없음. 날짜를 바꾸려면 설정만 고치고 `python 1_app_development/tools/development_balance.py` | `activeSeasonalEvent`, `WorkshopPage._homeEquipped` |
| 복귀 안내 | 2시간 이상 비웠다 돌아오면 카드에 '오늘의 주문서가 도착했어요.'·'오늘 출석 도장을 찍을 수 있어요.' | `WorkshopAwayReport.newOrder·stampReady` |
| 사용 통계 | `special_order_done`(`event`), `event_join`(`event`) — 32장 | `usage_stats.dart` |
| 서버 | 출석 황금은 보상 종류 `mission`의 새 목표(`scope:'attendance'`, `goal:'day7'`): `plausibility_validator.ts`가 보상량(설정 `gold`)·기간(미션과 같은 KST 날짜 유예 `mission_claim_grace_days`)을 확인, `workshop_missions.ts`가 계정당 날짜 하나(`attendance:<날짜>`)와 **직전 출석 황금에서 7일 이상**(`users/<계정>/workshopAttendance/latest`)일 때만 지급(아니면 `unverifiable`). 타당성 한도에 지난 KST 날짜 수(+2) × (초당 × (600 + 1800) + 200 + 600)을 더함. **서버 배포 필요**(함수·생성 설정) | `firebase/functions/src/plausibility_validator.ts`, `workshop_missions.ts`, `workshop_service.ts` |
| 테스트 | `test/workshop_daily_test.dart`(11개: 사흘 흐름, 시계 되돌리기·앞당기기, 자정 걸침, 오프라인 5일, 씨앗 고정·가진 맛, 행사 안/밖/없음, 안내 중, 출석 7칸 서버 유무, 저장 9→10·거절, 쪽지 화면, 카드 골든), 서버 `test/plausibility_validator.test.ts` 3개 | |
| 미리보기 | `flutter test tools/preview_daily_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf` → `build/preview/daily_{home,card}_{christmas,plain}.png` | |

## 35. 공유 카드 — 2026-11-19

26번 8단계(DEC-048·S8-Q1, DEC-111~113). 내가 구운 붕어빵·이야기·도감·가게를 카드 한 장으로 휴대폰 공유 창에 보낸다. **보상 없음**(1장 '공유에도 보상 없음'), 게임 상태·저장 형식 변경 없음. 홍보 자료는 [27번 문서](../27_홍보자료준비.md).

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 여는 곳 | ① 완벽 결과 화면 '자랑하기'(`mold-share`, 등급 perfect일 때만) ② 이야기 장면(다시 보기 포함) '자랑하기'(`story-share`) ③ 도감에서 다섯 익힘을 다 찾은 맛의 '도감 완성 자랑하기'(`collection-share-<맛>`, 팥 미디엄은 처음부터 아는 것으로 셈) ④ 메뉴 '가게 사진 찍기'(`menu-photo`) | `ui/workshop_mold_stage.dart` `onSharePerfect`, `ui/workshop_page.dart` `_share*`, `ui/public_menus.dart` |
| 창 | 카드 미리보기(창 폭에 맞춰 축소) + '닫기'·'공유하기'. '공유하기'는 카드를 그 자리에서 찍어 PNG로 만들고 `share_plus` 파일 공유(`XFile.fromData`, `todays_bungeoppang_<moment>.png`)로 공유 창을 엶. 사진첩 저장 버튼이 없어 저장 권한·새 패키지 없음. 실패(예외·`unavailable`)면 창 안에 '공유 창을 열지 못했어요. 잠시 뒤 다시 해 주세요.', 카드는 그대로 | `ui/share_card_view.dart` `ShareCardDialog`, `invite_sharing.dart` `CardSharer`·`SharePlusCardSharer`, `share_card.dart` `ShareCards.sharer`(테스트가 바꿈) |
| 카드 (3차 피드백 H43 A안, DEC-138, 아래 옛 설명보다 우선) | 밝은 종이 바탕(#FFFAF0) 위 둥근(16) 사진 + 아래 글. 사진: 홈과 같은 거리 풍경, 왼쪽에 **내 사장님 자랑 포즈 크게**(146×270, 입은 옷 그대로, 입 조금 벌림 `ShareCardView.vendorFace`; 26번 3차 AV: 25번 39번 포즈 — `AvatarLook.paint(proud: true)`가 원래 팔을 바탕·상의·앞치마·소품에서 `pose_proud_hide`로 지우고 든 팔(붕어빵·V)을 맨 앞에, 도구는 안 듦, `avatarV2ProudReady`일 때) + 발밑 그림자 + 반짝이, 오른쪽 손님(있을 때), 왼쪽 위 흰 알약 배지. 포즈가 없을 때(v1)만 따로 붕어빵(완벽 = 윤기) `share-card-fish`. 든 팔에 상의 소매가 없어 민소매처럼 보임 → 25번 39번 50번 소매 레이어 주문. 시안 비교 `tools/preview_share_mockups_test.dart` | `ShareCardView`, `_PosePainter` |
| 카드 | 360×450으로 배치해 3배(설정 `share.card_width` 1080 ÷ 360)로 찍음 → **1080×1350(4:5)**. 위 70%: 홈과 같은 배경·장식(행사 중이면 행사 장식, `_homeEquipped`)의 거리 풍경(배경 그림 세로 260~557px 구간, 행주·매대 윗면까지) + 왼쪽 아래 조리 컷 창의 사장님(입은 옷 그대로, 정지 그림) + 붕어빵(완벽 = 미디엄 + 윤기, 도감 = 바삭함 색, 가게 사진은 붕어빵 대신 큰 조리 컷) + 오른쪽 손님 그림(완벽 결과의 주문 손님·이야기 손님, `happy` 얼굴) + 왼쪽 위 배지('완벽!'·'이야기'·'도감 완성'·'우리 가게'). 아래 30%: 제목(‘팥 붕어빵’·이야기 이름·‘팥 붕어빵 도감’·‘우리 가게’), 대사 한 줄(완벽 = 주문 손님 반응, 없으면 등급 문구 / 이야기 = 장면에서 사장님이 아닌 첫 대사, 없으면 '○○의 이야기를 들었어요.' / 도감 = '다섯 가지 익힘을 모두 찾았어요.' / 가게 = 행사 인사 또는 '따끈한 붕어빵 구워 놓고 기다릴게요!'), 맨 아래 작은 붕어빵 + 스토어 문구 | `ShareCardView`, `ShareFishPainter` |
| 넣지 않는 것 | 사장님 이름·아이디·레벨·재화·날짜·기기 정보. 손님 이름은 게임 속 인물 이름 | `ShareCardData` |
| 스토어 문구 | 설정 `share.store_line_mode` `soon` → '오늘의 붕어빵 · 곧 Google Play에서'(지금), `live` → '오늘의 붕어빵 · Google Play에서 만나요'(정식 출시 뒤 이 값만 바꾸고 `python 1_app_development/tools/development_balance.py`). 공유 글 = 순간별 한 줄('완벽한 팥 붕어빵을 구웠어요!' 등) + 스토어 문구 + `share.store_url`(`https://play.google.com/store/apps/details?id=com.todaybungeoppang.app`). 서버는 이 설정을 읽지 않음(생성본만 갱신) | `config/development_balance.json` `share`, `ShareCardTexts` |
| 사용 통계 | `share`(공유 창을 연 뒤, KST 하루 1번, `moment`만) — 32장 | `usage_stats.dart` |
| 개인정보 | 개인정보처리방침 1-3절 이벤트 목록과 5절 '게임 장면 그림'(앱 `assets/legal/`·문서 두 곳) | `privacy_policy.md` |
| 그림 | 새 그림 없음(기존 배경·조리 컷·손님·붕어빵 그림, 나무 테두리는 코드). 메뉴 줄 아이콘은 Material `photo_camera_outlined`. 장식 테두리가 필요하면 25번 다음 번호로 주문 | — |
| 테스트 | `test/share_card_test.dart`(9개: 설정·공유 글, 하루 1번, 골든 축소본 3장 `share_card_{perfect,story,shop}_360x450`, 메뉴 가게 사진 → 1080×1350 PNG·스토어 주소·보상 없음·이벤트 하루 1번, 공유 실패 안내·상태 불변, 완벽 결과에만 '자랑하기'·손님 반응, 이야기·도감 완성) | |
| 미리보기 | `flutter test tools/preview_share_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf` → `build/preview/share_card_{perfect,story,collection,shop}.png`(실제 크기) | |

## 36. 법률 확인 반영 — 2026-11-19

출시 전 법률 확인 메모(만 14세 미만 필수 정보, 사용 통계 기본 켬)에 대한 사용자 결정(2026-11-19) 반영. 결정은 00_결정취합 `DEC-125~127`, 결과 표는 26번 문서 '법률 확인 반영'. **법률 자문이 아니며 근거 조항은 변호사 확인 권장**(23번 8단계 사용자 할 일).

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| 만 14세 미만 가입 불가 (A안) | 필수 동의에 '(필수) 만 14세 이상입니다'(전체 동의에 포함). 체크 안 하면 로그인·'동의하고 계속하기' 버튼이 꺼지고 '만 14세 미만은 지금은 이용할 수 없어요.' 안내. 선택 정보 연령대에서 '만 14세 미만'과 보호자 체크·`guardian-required`를 없앰 | `owner_texts.dart`, `ui/first_run.dart`, `owner_profile.dart` |
| 서버 확인 기록 | `accountProfileSet` 입력 `over14Confirmed: true` 필수(`age-required`), `requiredConsent.over14: true`로 저장. 앱은 `consentVersion == requiredConsentVersion`이면 `over14Confirmed: true`를 보냄(현재 판 동의는 반드시 이 체크를 거침). **서버 배포 필요**(옛 서버는 새 앱의 `2026-11-19` 동의를 `consent-required`로 거절 → 프로필 저장만 실패하고 다음 시작에 다시 시도) | `firebase/functions/src/account.ts`, `online_backend.dart` `AccountProfileUpdate` |
| 재동의 | `requiredConsentVersion` `2026-11-18` → `2026-11-19`(앱·서버). 기존 사용자는 업데이트 뒤 첫 실행에 ① 화면(이미 로그인이면 '동의하고 계속하기')에서 세 항목에 다시 동의해야 게임에 들어감 | `owner_profile.dart`, `account.ts` |
| 옛 만 14세 미만 기록 | 기기 기록의 `ageBand: under14`(+보호자 체크) 선택 정보는 읽을 때 버리고 서버 동기화로 지움. 계정 자체는 자동 삭제하지 않음(알게 되면 운영자가 삭제 — 처리방침 8절) | `OptionalInfo.fromJson` |
| 사용 통계 시작 시점 | 기본 켬 유지, 단 첫 실행 필수 동의 뒤에 수집 시작(32장 '첫 실행 동의 전'). 매니페스트 `firebase_analytics_collection_enabled=false`는 그대로라 동의 전에는 자동 `first_open`도 남지 않고, 동의 뒤 수집을 켤 때 Analytics가 `first_open`을 남김(Firebase 동작, 9단계 DebugView로 확인할 것) | `usage_stats.dart` |
| 문구 | 설정 설명 '게임을 고치는 데 쓰는 사용 기록이에요(이름·계정과 연결하지 않아요)', 선택 동의 상자 '…이름·이메일·계정과 연결하지 않고, Google(미국) 서버로 보내져 14개월 보관돼요' | `ui/workshop_page.dart`, `owner_texts.dart` |
| 문서 | 개인정보처리방침 1-0절(처리 근거 구분: 동의/동의 없이/법령), 1-2절 국외 이전 한 줄, 1-3절 '이름·계정과 연결하지 않은 기록'·동의 뒤 수집·자동 수집 장치, 7-1절 국외 이전 법정 항목 표(이전 근거 조항 포함), 8절 만 14세 미만 가입 불가·알게 되면 삭제. 이용약관 2-1절 이용 자격. Play 데이터 보안·online_setup.md 16-8(카카오 14세 필터, 보조)·17장·18-4 | `privacy_policy.md`, `terms_of_service.md`, `assets/legal/` 사본 |
| 테스트 | `owner_first_run_test`(14세 체크 없이 로그인 불가·전체 동의·재동의·옛 under14 기록·연령대 항목 없음·동의 전 통계 멈춤), `usage_stats_test`('첫 실행 동의 전에는 모으지 않음' 4개), 서버 `account.test.ts`(만 14세 이상 확인·under14 거절·옛 보호자 기록 지움·옛 동의 판 거절) | |

## 37. 실기기 3차 녹화 피드백 — 홈·굽기 (C 묶음, H17~H30) — 2026-11-19

26번 문서 '실기기 3차 녹화 피드백' H17~H30. 저장 형식 변경 없음(Workshop schema·`CookingSession` schema 1 그대로). 서버 변경 없음.

| 번호 | 바뀐 것 | 값·위치 |
| --- | --- | --- |
| H17 가게 상태 간판 | 버튼처럼 보이던 나무 간판(짙은 나무색·주황 테두리 2) → **간판 전용 모양**: 짙은 반투명 유리판(`0xb3221410`, 모서리 8, 크림 테두리 1 투명도 0.28), Jua 15. 앞 등불 점 9가 영업 중이면 초록(`0xff7ed957`)으로 켜지고 1.6초 주기로 은은하게 빛남(`WorkshopStatusBadge.glowMs`, 모션 줄이기·테스트(`WorkshopStatusBadge.animate = false`)면 멈춘 빛), 영업 준비는 회색 점·옅은 글자, 저장 오류는 벽돌색 판 | `night_home.dart` `WorkshopStatusBadge` |
| H18 큰 틀 위치 | 스페셜 붕어빵 틀(영업 준비 빈 틀·제작 중·결과)은 **그림 전체(틀 불투명 행 102 ~ 걸이 축 받침 발 833, 25번 36번 그림 적용 뒤. 예전 코드 그림은 89~847)가 판매 카운터 윗변과 조리 컷 윗변 중 높은 쪽보다 8 위**(`WorkshopHomeLayout.moldGap`)에 오도록 올림. 올라가도 그림 윗변은 무대 위끝(HUD 아래) 34 아래까지만(`moldTopRoom`). `NightHome`이 `centerBuilder`의 넷째 값 `moldLimit` = min(행주 윗변, 조리 컷 윗변)을 넘김(스크롤 홈·행주 값 없는 배경은 null → 예전 자리). 영업 중 떠 있는 큰 붕어빵(클리커)은 그대로. '스페셜 붕어빵 제작 시작'은 빈 틀 가운데. 보관하기·버리기·자랑하기·제작 취소는 틀 그림 아래 6(`moldButtonGap`), 조리 컷 왼쪽(오른쪽 여백 = 폭 × `cookCutShare` 0.32 + 8) 가운데 | `workshop_mold_stage.dart` `moldPictureSpan`, `workshop_home_layout.dart` |
| H19 제작 중 위 글 | '팥 연습 · 반죽 목표 90% 이상 덮기 · 130% 넘으면 넘침'과 '현재 단계 경과 N초'를 지우고 **'팥 붕어빵 연습' / '팥 붕어빵 주문'** 한 줄(반투명 판, Jua 15, 일시정지면 ' · 일시정지'). 키 `workshop-session-title`, 글 `workshop-phase-time` | `_sessionTitle` |
| H20 반죽이 미리 부어진 모습 | ① 영업 준비 빈 틀에 다 구운 붕어빵을 그리던 것을 지우고 **빈 틀**만(`WorkshopMoldArt(idleMold)`). ② 칠한 칸은 저장하지 않으므로(G2) 앱을 다시 켤 때 속·둘째 반죽·뚜껑 닫기 전(`filling`·`secondBatter`·`closing`) 세션은 **같은 id·맛·연습/주문으로 첫 반죽부터 다시 시작**(`WorkshopController` 불러오기, `phaseMs` 0). 쓰인 재료가 없어 손해 없음 | `workshop_controller.dart` |
| H21 뒤집기 | 원 그리기(DEC-034) → **걸이 축 밀어 뒤집기**. 틀은 양옆 고리를 지나는 축에 걸려 있고(**25번 36번 생성 그림 적용, 2026-11-20 3차 F3**: 틀 7장 `mold/<상태>.png`는 고리를 둥근 축 구멍(부싱)으로 다시 그림, 축 장치는 틀과 같은 1200×880 캔버스 두 장 — `mold/axle_back.png`(받침 기둥·쇠 막대, 틀 뒤)·`mold/axle_front.png`(놋쇠 핀 머리, 도는 틀 앞) — 를 `MoldAxlePainter`가 그림, 그림이 없으면 예전 코드 그림. 틀 그림 좌표 고리 구멍 중심 (118,441.5)·(1076,441.5) = `flipAxleLeftRing`·`flipAxleRightRing`(예전 임시 (114,430)·(1072,430)). 만드는 법 `python tools/apply_25_art.py <26_feedback_generated> --only mold`: 1464×1074 원본을 1200×880으로 그냥 줄이면 붕어빵 홈 `fishRect` (215,174)~(984,706)가 2px 안에서 맞음, 상태마다 고리 위치가 최대 10px 달라 7장 모두 닫힌 틀의 고리(x<153·x≥1040 열)를 씀, 축 두 장은 좌우 반쪽씩 그 구멍에 맞춰 옮김(왼쪽 (0,+4), 오른쪽 (−5,+4)). 생성 틀에는 바닥 그림자가 없음), 틀을 위(또는 아래)로 밀면 축을 따라 3D로 돎(`rotateX`, 원근 0.0018, 90° 넘으면 뒷면). 틀 높이(`fishRect` 높이 × 배율)만큼 밀면 180°(`flipAxleDegreesPerHeight`), **120°**(`flipAxleDoneDegrees`)를 넘으면 `flip_ms` 동안 마저 넘어간 뒤 `flip` 명령. 6px 미만 움직임은 0°(`flipAxleStartPx`). 손을 떼면 제자리, 진행은 오른쪽 핀 둘레 꿀색 고리, 밀기 전에는 틀 가운데 굽은 화살표. 안내 글 '틀을 위로 밀어 올려 뒤집어요' / '뒤집기 N% · 손을 떼면 처음부터' / '뒤집는 중…'. 계산 `lib/cooking_flip.dart` `FlipAxle`(예전 `FlipCircle` 삭제). 설정 `manual_cooking.flip_turn_degrees`·`flip_dead_zone_permille`은 **화면에서 더 읽지 않음**(설정 파일·서버 생성본 호환으로 남김). `fx/flip_ring*.png`도 쓰지 않음. 축 장치는 다른 단계(빈 틀·칠하기·결과)에도 같이 그림. 새 틀 그림 주문 25번 36번 | `flip_circle_control.dart`(이름 유지), `feedback_config.dart` |
| H22 결과 말 | 등급 큰 글씨·이유를 붕어빵 위에 테두리 글자로 쓰던 것 → 틀 윗변에 걸친 **반투명 띠 창**(`CookingResultView.bandColor` `0xb3221410`, 모서리 16, 최대 폭 280, 키 `mold-result-band`) 안에 별 줄 → 등급(Jua 23, 실패 19) → 이유(13) | `cooking_result_effects.dart` |
| H24 품질 별 | 등급별 별 수(3개 중): 완벽 3 · 성공 2 · 아쉬움 1 · 실패 0(`feedback_config.dart` `cookingStars*`, `cooking_result_rules.dart` `cookingStars`). 켜진 별 `icons/star` 22, 꺼진 별은 같은 그림 회색 0.4. 화면 읽기 '별 3개 중 N개'. 키 `mold-result-stars`. 판정·숙련·판매값 변화 없음 | |
| H25 결과 버튼 | 'FilledButton 보관' + 글자만 '버리기'(버튼처럼 안 보임) → 같은 크기 둥근 버튼 `StageButton`(높이 40, 최소 폭 92, Jua 16): **보관하기**(꿀색), **버리기**(크림, 키 `mold-discard`), 완벽이면 자랑하기(크림), 제작 중 '제작 취소'(반투명, 키 `mold-cancel`). 주문 제작 결과는 손님 몫이라 '결과 닫기' 하나(버리기 없음, 예전과 같음) | `workshop_mold_stage.dart` `StageButton` |
| H26 맛 고르기 | 영업 준비 중 HUD 아래 작은 드롭다운('팥') 삭제. **HUD 왼쪽 위 둥근 자리(예전 메뉴 버튼, H28)**에 맛 버튼(`WorkshopFlavorButton`, 48 원 안에 속 질감 `mold/paint_<맛>` + 아래 이름표, 키 `flavor-button`·`flavor-label`). 영업 준비 중 누르면 맛 고르기 창(`showFlavorPicker`, 키 `flavor-picker`, 맛마다 `flavor-pick-<맛>`; 아직 없는 맛은 흐리게 + 자물쇠 + 'Lv.N 레시피 미션'). 제작 중엔 그 맛을 보여 주고 누르면 '만드는 중에는 맛을 바꿀 수 없어요.', 영업 중 세션이 없으면 빈 자리. '스페셜 붕어빵 제작 시작'은 맛이 둘 이상이면 먼저 고르기 창 → 고른 맛으로 연습 | `ui/flavor_picker.dart` |
| H23 알림 | 아래에서 올라오는 스낵바를 앱 전체에서 없애고 **화면 가운데 반투명 창**(`showCenterToast`, `ui/center_toast.dart`): 짙은 나무색 0.82(`0xd12a1810`), 모서리 14, 최대 폭 300, 글 15 크림, 0.18초 나타남 → 2.2초 → 사라짐, 터치는 통과, 새 알림이 앞 알림을 바꿈, 화면 읽기 liveRegion. 키 `center-toast`. 잠긴 메뉴·잠긴 6구·스킬 창·레벨 승급·황금 구매·로그인·알림 권한·설정 계정·저장 복구 복사 등 21곳 모두 | |
| H27 잠금 표시 | 공통 잠금(`LockedOverlay` `LockStyle.hatch`)의 여러 줄 빗금(굵기 6·간격 10) → **빗금 한 줄**(왼쪽 아래 → 오른쪽 위 대각선, 굵기 3, `0xff5b3a24` 0.55, 모서리 안쪽 최대 10 띄움) + 옅은 면(나무색 0.12). 하단 메뉴 잠금 자물쇠 34 가운데 → **18, 버튼 오른쪽 위 모서리**(`NightHome.navLockSize`, `Alignment(.82, -.78)`), 아이콘·이름은 흐리게 보임 | `lock_overlay.dart` `LockHatchPainter` |
| H28 메뉴 한 곳 | Workshop 홈 HUD 왼쪽 위 메뉴 둥근 버튼(`menu-menu`) 삭제, 메뉴는 하단 '메뉴'(`menu-menubar`)만. 받을 보상 수 배지는 하단 메뉴 버튼으로(`menubar-badge`). 빈자리는 맛 버튼(H26). 구형 클리커 홈(`GameApp` 구형 경로)은 그대로 | `NightHome.hudLeading` |
| H29 HUD | 레벨: 짙은 나무 상자 + 막대 → **원형 엠블럼**(지름 62, 짙은 테두리 + 크림 원, 'Lv' 11 + 숫자 Jua 24, 레벨 미션 진행을 둘레 꿀색 고리로, 키 `level-progress`·`current-level`). 붕어빵력 아이콘 34 → **40**, '붕어빵력' 제목 줄 삭제 | `night_home.dart` `_levelBadge`·`_LevelRingPainter` |
| H30 황금 붕어빵 | 붕어빵력 칸 둘째 줄에 **황금붕어빵력**(아이콘 `gold_bun` 26 + 숫자 17 진한 금색 + 꿀색 '+' 18, 키 `hud-gold`·`hud-gold-value`). 누르면 충전 목록(`gold`). 값은 계정 `premium.gold`(창 잔액 알약과 같음). 예전 '누적 N개' 줄은 구형 홈에만 | `NightHomeHeaderData.gold` |

확인 그림: `C:\Users\이소이\Desktop\26번_시안_확인\3차\C\`(전후 비교, 390×844·360×800). 미리보기 하네스 `flutter test tools/preview_h_c_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after` → `build/preview/h_c/`.

## 38. 3차 피드백 E: 공통 테마·충전 상품·배경 — 2026-11-19

26번 실기기 3차 녹화 피드백 H31·H41·H42(E 묶음). 결정은 00_결정취합 DEC-141~143(병합 때 번호 확정).

| 항목 | 내용 | 위치 |
| --- | --- | --- |
| H41 공통 테마 | 패널·창·버튼·탭·토글·말풍선을 가는 선 + 흰 면 + 부드러운 그림자로, 종류별 색 `CozyTone`(11장). 화면 파일은 최소만: 메뉴 줄(`public_menus.dart`), 손님 말풍선(`workshop_guests.dart`), 창 받침·닫기·오류 줄(`workshop_windows.dart`), 작은 창 닫기 위치(`workshop_page.dart` `_popup`), 스킬 창 고른 탭·돌림판 테두리(`workshop_skill_shop.dart`), '미션 달성!' 완료 색(`celebration.dart`) | `lib/ui/cozy_style.dart` |
| H31 충전 상품 | 충전 탭을 잔액 카드 + 상품 카드(그림·큰 숫자·가격 알약)로(8장). 상품 그림 25번 40번 주문, 임시는 아이콘 쌓기 | `lib/ui/gold_widgets.dart`, `pixel_sprites.dart` `uiNames` |
| H42 배경 되살리기 | 원인: 26번 2단계(커밋 b7ad3e9, 2026-11-18)가 메뉴 '배경 테마'와 꾸미기 가게 탭을 Lv.8(`stall_cosmetics`)까지 숨겼고, 26번 4-5단계 Workshop 상점은 `avatar_catalog`(아바타)만 팔아 배경은 어디서도 살 수 없었다(`cosmetic_purchase`에는 값이 있었음). 고침: 배경 10종을 `avatar_catalog`에 slot `background`로 넣음(clear 무료, 나머지 붕어빵력 1000 + 황금 2, 해금 레벨 1·1·2·2·3·4·5·6·6·8), 새 설정 `feature_unlock_levels.stall_background` = 1(가게 탭의 배경·밤낮 칸), 화로·장식·등불은 그대로 Lv.8. 설정 창 '배경 바꾸기' 줄 추가(10장) | `config/development_balance.json`, `lib/workshop_feature_unlocks.dart` `stallBackground`, `lib/ui/workshop_page.dart` `_cosmetics`·`_audioSettings`, `public_menus.dart` `slotOpen`, `workshop_wardrobe.dart` `_slots` |
| 서버 | 서버 생성 설정(`firebase/functions/src/generated/development_balance.json`)이 바뀜 → **배포 묶음에 포함, 배포 전 `npm test`**(104개 통과, 배경 구매 테스트 추가). 서버 코드는 바뀌지 않음(구매 검사는 `avatar_catalog`·`cosmetic_purchase`를 그대로 읽음). 슬롯 검사(`lib/development_balance.dart`, `tools/development_balance.py`)에 `background` 추가 | `firebase/functions/test/workshop_service.test.ts` |
| 저장 | 형식 변경 없음. 산 배경 = 가게 저장 `purchases.owned['cosmetic:<id>']`, 입은 배경 = `avatarEquipment['background']` | 3장 |
| 확인 | `flutter test tools/preview_theme_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf --dart-define=PREVIEW_TAG=after` → `build/preview/theme/`(홈·메뉴·상점 두 탭·가게 배경·꾸미기·설정·오늘·스킬·기록·주간·업적·레벨 미션, 360×800·390×844) | |
