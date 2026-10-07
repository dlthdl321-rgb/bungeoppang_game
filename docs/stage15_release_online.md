# 15단계 — 출시용 온라인 기능 (로그인·초대·랭킹·황금 붕어빵)

작성: 2026-10-06. 14단계(시안 적용)와 같은 작업 폴더에서 병행 중이다.

## 결정 기록

| 항목 | 결정 |
|---|---|
| 서버 | **Firebase.** Play 게임즈 계정으로 Firebase Auth에 로그인한다. 데이터는 Firestore(서울)에 두고, 앱은 Cloud Functions만 호출한다 |
| 유료 재화 이름 | **황금 붕어빵**. 코인은 무료 재화로 유지한다 |
| 먼저 해금 | **스킬**(누적 생산 조건 건너뛰기), **레벨 잠긴 꾸미기**(잠금 무시), **부스트 구매**(아이템이 없어져서 대체) |
| 캐시 꾸미기 | **모든 꾸미기를 코인 또는 황금 붕어빵으로** 살 수 있다 |
| 맛 기능 | **제거.** 팥만 남겨 그림 기준으로만 쓴다. 나중에 레벨 스킬로 다시 만든다. 출시 전이라 환불하지 않는다 |
| 요정·버터 | **제거.** 아이템 보상은 코인으로 바꿨다(일일 전체 10, 초대 5/2, 주간 3/7). 아래 부스트로 대체 |
| 초대 손님 | 초대받은 B가 A의 아이디를 입력하고 Lv.1을 달성하면, **B 가게에 A가 손님으로** 온다. B는 **10분 ×5** |
| 친구 방문 | 아이디로 친구를 추가한다(서로 친구가 됨, 초대로 가입한 사이는 자동). **친구마다 하루 1번** 방문할 수 있고, 방문받은 친구가 **5분 ×3**을 받는다. 같은 부스트가 겹치면 시간이 늘어난다 |
| 황금 찬스 | 플레이 중 **3~7분마다** 하단 틀의 붕어빵 하나가 8초 동안 황금빛이 되고, 누르면 **1분 ×3** |
| 부스트 겹침 | 종류가 다른 부스트가 겹치면 **가장 큰 배율 하나만** 적용한다(곱하지 않음) |
| 부스트 중 화면 | 가운데 붕어빵이 황금색이 되고 남은 시간 배지가 붙는다. 손님이 오면 아바타가 걸어와 인사하고 돌아간다 |

## 구조

```
앱 ── Play 게임즈 로그인 ──> serverAuthCode ──> Firebase Auth (playgames.google.com)
 │
 ├─ Google Play Billing (in_app_purchase) ── 구매 토큰 ──┐
 │                                                     v
 └─ Cloud Functions (asia-northeast3) ──> Firestore    Google Play Developer API
      walletSync / walletRedeem / walletSpend          (구매 확인·소비)
      inviteRegister / inviteCreateTicket / inviteAccept / inviteLevelOne / inviteFetchEvents
```

- **황금 붕어빵 잔액은 서버만 바꾼다.** 앱의 잔액은 표시용 사본이다.
  - 충전: 서버가 Google Play에 구매를 확인한 뒤 더하고, 그 구매를 소비 처리한다. 같은 구매 토큰은 한 계정에서 한 번만 인정한다.
  - 사용: 앱이 정한 `requestId`로 요청한다. 다시 보내도 두 번 차감되지 않는다.
  - 산 것(꾸미기, 스킬 해금, 부스트)은 서버 원장에 남는다. 앱을 다시 설치하면 영구 항목(꾸미기·스킬 해금)이 복원되고, 이미 쓴 부스트는 다시 주지 않는다.
- **Firestore 보안 규칙은 앱 접근을 전부 막는다.** 모든 읽기·쓰기는 Functions(Admin SDK)를 거친다.
- **초대**는 기존 앱 규칙(`invite_rules.dart`)을 그대로 쓴다. 서버 이벤트는 `clicked → classifiedNew → reachedLevelOne`(새 플레이어) 또는 `clicked → existingParticipated`(기존 플레이어)이다.
  - 새 플레이어 판단: 서버가 그 계정을 처음 본 지 24시간 안에 초대를 수락하면 새 플레이어다.
  - 초대 링크: Play 스토어 주소에 `referrer=invite=코드&ticket=…`를 붙인다. 새로 설치한 앱이 Install Referrer로 코드를 읽는다. 코드를 직접 입력할 수도 있다.
  - 한 계정은 초대를 한 번만 수락할 수 있다. 자기 자신은 초대할 수 없다.
  - 서로에게는 계정 ID 대신 해시한 `playerId`만 보인다.
  - Lv.1 달성은 앱이 알리는 값을 믿는다. 서버가 검증하지 않으므로 보상(요정 1개)은 작게 둔다.
- **랭킹**은 9단계 Play 게임즈 리더보드를 그대로 쓴다.

## 가격표 (`lib/premium_config.dart` → `firebase/functions/src/catalog.json`)

| 상품 ID | 황금 붕어빵 | 예정 가격 | 1,000원당 |
|---|---|---|---|
| gold_60 | 60 | ₩1,200 | 50 |
| gold_330 | 330 | ₩5,900 | 56 |
| gold_700 | 700 | ₩11,000 | 64 |
| gold_2200 | 2,200 | ₩33,000 | 67 |
| gold_3800 | 3,800 | ₩55,000 | 69 |

| 쓰는 곳 | 가격 |
|---|---|
| 꾸미기 | 코인 가격 × 5. 잠금 무시 |
| 스킬 먼저 해금 | n번째 스킬(`tap_n`/`auto_n`) × 10. 처음부터 열린 스킬은 제외. 해금 후 구매는 지금처럼 붕어빵으로 |
| 황금 부스트 | 20 (10분 ×3) |

- 실제 판매가는 Play Console에서 정한다. 앱은 Google Play가 주는 현지 가격을 보여 준다.
- 가격을 바꾸면 `UPDATE_PREMIUM_CATALOG=1 flutter test test/premium_catalog_test.dart`로 `catalog.json`을 다시 쓰고, 서버를 다시 배포한다. 평소에는 이 테스트가 앱과 서버 가격이 다르면 실패한다.

## 진행 상태 (2026-10-06)

| 영역 | 파일 | 상태 |
|---|---|---|
| 서버 | `firebase/functions/src/{wallet,invites,friends,store,catalog,index}.ts`, `firestore.rules` | 단위 테스트 14개 통과(`npm test`). 실제 배포 전 |
| 서버 함수 | `walletSync/Redeem/Spend`, `inviteRegister/CreateTicket/Accept/LevelOne/FetchEvents`, `profileSet`, `friendAdd/List/Visit`, `visitsFetch` | 모두 Play 게임즈 로그인 계정만 호출 가능 |
| 앱 서버 연결 | `lib/online_backend.dart`, `lib/firebase_online_backend.dart`, `lib/server_invite_repository.dart` | Firebase 설정은 `--dart-define`으로만 넣음(저장소에 없음) |
| 결제 | `lib/billing_service.dart`, `lib/play_billing_service.dart` | 서버가 확인·소비한 뒤 앱이 결제를 마무리함(autoConsume 끔) |
| 세이브 | `lib/premium_state.dart`(`premium` 항목), `support-v2`(부스트, 받은 방문) | 옛 세이브: 지갑 없음 → 빈 지갑, `support-v1` → 아이템 버리고 사용 횟수만 부스트 횟수로 |
| 규칙 | `lib/boost_controller.dart`, `lib/online_controller.dart`, `lib/premium_controller.dart`, `economy.dart`의 `skillUnlocked` | 2분마다(앱 켜져 있을 때) 방문·지갑 동기화 |
| 화면 | 상점 '충전' 탭, 꾸미기·스킬 '황금 N' 버튼, 메뉴 '친구', 황금 찬스, 손님 도착, 부스트 배지 | `lib/ui/{gold_widgets,friends_panel,boost_effects}.dart` |
| 미션·업적 | Lv.4 '황금버터 사용' → '황금 찬스 잡기', '아이템 누적 사용' → '부스트 누적 사용' | |
| 정책 문서 | `docs/privacy_policy.md`, `docs/play_data_safety.md`, `test/no_tracking_sdk_test.dart`(허용 목록 방식) | 법무 검토 권장 |

**아직 확인하지 못한 것**
- 실제 Firebase 로그인, 결제, 서버 호출은 실행하지 못했다. 프로젝트와 Play Console 설정이 없기 때문이다.
- 손님은 시안 손님 그림이 아니라 꾸미기 아바타 레이어로 그린다.
- 틀 위 황금 붕어빵 자리(`griddleCavities`)는 최종 틀 그림에 맞춰 조정해야 한다.

## 직접 하셔야 하는 설정 (계정·콘솔 권한이 필요)

1. **Play Console**
   - 앱을 만들고, 앱 서명 키의 SHA-1을 확인한다.
   - Play 게임즈 서비스를 설정한다. 앱 ID와 리더보드 3개를 만들고 `games-ids.xml`을 받는다.
   - 수익 창출 → 인앱 상품에 위 5개 ID를 **소비성**으로 만들고 가격을 정한다.
   - 앱 콘텐츠 → 데이터 삭제: 계정 삭제 요청 방법(이메일)을 입력한다.
   - 결제 프로필(판매자 계정)을 만든다.
2. **Firebase**
   - 프로젝트를 만들고 Android 앱(`com.todaybungeoppang.todays_bungeoppang`, SHA-1 등록)을 추가한다. Android 앱 설정 값(API 키, 앱 ID, 발신자 ID, 프로젝트 ID)을 확인한다(4번에서 사용).
   - Authentication에서 **Play Games** 로그인을 켠다. Play 게임즈의 클라이언트 ID·보안 비밀을 입력한다.
   - "Web client" OAuth ID를 `firebase-ids.xml`의 `server_client_id`에 넣는다. Play Console의 Play 게임즈 사용자 인증 정보에 '게임 서버'로도 등록한다.
   - Firestore를 서울 리전(`asia-northeast3`)으로 만든다.
   - Blaze 요금제로 바꾼다. Functions와 외부 API 호출에 필요하다.
3. **구매 확인 권한**
   - Functions가 실행되는 서비스 계정(기본: `PROJECT_ID@appspot.gserviceaccount.com`)을 Play Console 사용자 및 권한에 초대한다.
   - 권한은 '재무 데이터 보기'와 '주문 및 구독 관리'를 준다.
   - Google Cloud에서 **Google Play Android Developer API**를 켠다.
4. **빌드 설정**: Firebase 콘솔의 Android 앱 설정 값으로 빌드한다.
   `flutter build appbundle --dart-define=FIREBASE_API_KEY=… --dart-define=FIREBASE_APP_ID=… --dart-define=FIREBASE_SENDER_ID=… --dart-define=FIREBASE_PROJECT_ID=…`
   `google-services.json`과 google-services Gradle 플러그인은 쓰지 않는다(분석 SDK 유입 방지).
5. **배포**
   - `firebase/.firebaserc.example`을 `.firebaserc`로 복사하고 프로젝트 ID를 넣는다.
   - `cd firebase/functions && npm install && npm test`를 실행한다.
   - `firebase deploy --only functions,firestore`로 배포한다.
6. **테스트**
   - Play Console의 내부 테스트 트랙에 올리고, 라이선스 테스터 계정으로 테스트 결제를 한다(실제 청구 없음).

## 정책 확인 사항

- **결제 수단:** 디지털 재화는 Google Play 결제만 쓴다. 외부 결제 링크를 넣지 않는다.
- **환불:** Play 환불은 서버에 자동 반영되지 않는다. 다음 단계에서 Voided Purchases API로 정기 확인해 잔액을 차감할지 정해야 한다.
- **청약철회 안내:** 상점에 '구매 후 사용하지 않은 황금 붕어빵은 7일 안에 청약철회 가능' 등 국내 전자상거래 안내 문구가 필요하다. 문구는 법무 확인을 권한다.
- **확률형 아이템:** 없다(모든 상품의 내용이 정해져 있음).
