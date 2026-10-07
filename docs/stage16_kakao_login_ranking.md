# 16단계 — 카카오 로그인과 자체 온라인 랭킹

작성: 2026-10-07. 기준 요청: [카카오 로그인 전환 프롬프트](prompts/오늘의붕어빵_카카오로그인전환프롬프트_261007_2100_01.md).
실행 환경: `B:` subst, `PUB_CACHE=C:\PubCacheBungeoppang`, `GRADLE_USER_HOME=C:\GradleCache`, Flutter `C:\flutter-sdk`.

출시 전이라 실제 사용자가 없으므로, 9단계의 구글 로그인·리더보드를 계정 이전 없이 **통째로 교체**했다. 결제(Google Play Billing, 서버 구매 확인)와 지갑·친구·초대는 Firebase uid 기준이라 그대로 쓴다.

## 구조

```
앱 ── 카카오톡 로그인 (설치돼 있으면) ─┐
   └─ 카카오계정 로그인 (없거나 실패) ─┴─> 카카오 접속 토큰
        │
        v
   authKakao (Functions) ── /v1/user/access_token_info: app_id == KAKAO_APP_ID ?
        │                 └ /v2/user/me: 회원번호, 닉네임(동의 시)
        v
   커스텀 토큰 (uid "kakao:<회원번호>", claim provider="kakao")
        │
        v
   signInWithCustomToken ──> 다른 모든 callable (signedIn: sign_in_provider "custom" + provider "kakao")
```

## 결정

| 항목 | 결정 |
|---|---|
| 키 | 네이티브 앱 키는 `--dart-define=KAKAO_NATIVE_APP_KEY`로만 받는다. Gradle이 같은 값을 읽어 매니페스트 scheme `kakao<키>`를 채운다. 서버의 앱 ID는 `functions/.env`의 `KAKAO_APP_ID`(gitignore). |
| 키가 없을 때 | `FirebaseOnlineBackend.create`가 `NoOnlineBackend`를 돌려준다. 랭킹·친구는 "준비 중", 게임은 오프라인 그대로(9단계에서 앱 ID가 비었을 때와 같음). 매니페스트 scheme은 `kakao-not-configured`가 된다. |
| 로그인 시점 | 사용자가 로그인 버튼을 누르거나, 로그인이 필요한 기능(친구 추가, 황금 붕어빵 구매·사용)을 직접 쓸 때만 카카오 화면을 연다. 2분마다 도는 배경 동기화와 결제 재전달 처리는 **로그인 화면을 열지 않는다**(로그인돼 있을 때만 동작). |
| 취소 | `PlatformException(CANCELED)`, 동의 거부(`access_denied`), SDK 취소는 `SignInResult.canceled`. 로그인 버튼에서는 아무 메시지도 내지 않는다. 기능을 쓰다 취소하면 "카카오 계정으로 로그인해 주세요"로 안내한다. |
| 세션 유지 | Firebase Auth가 세션을 기기에 보관하므로 앱을 다시 켜도 로그인 상태다. |
| 로그아웃 | 랭킹·친구 화면 위의 카카오 계정 줄에 로그아웃 버튼. Firebase `signOut` + 카카오 `logout`. 계정 탈퇴는 범위 밖. |
| 이름 | 서버가 카카오 닉네임(동의 시, 최대 16자)을 Auth `displayName`에 넣는다. 없으면 지우고, 앱은 기존 규칙대로 '친구'를 쓴다. |
| 다른 앱 토큰 | `access_token_info`의 `app_id`가 `KAKAO_APP_ID`와 다르면 `permission-denied`. 만료·무효 토큰(카카오 401)은 `unauthenticated`. |
| 랭킹 저장 | `rankings/{board}/entries/{uid}` = `{score, scoreText, name, look, updatedAt}`. 점수가 2^63-1까지라 앱은 문자열로 보내고, `score`(숫자)는 정렬용, `scoreText`는 정확한 값. 이름·모습은 서버의 프로필(`profileSet`)에서 가져온다. |
| 최고 기록만 | 더 높을 때만 점수와 `updatedAt`을 바꾼다. 낮으면 이름·모습만 갱신한다. 0점은 순위표에 올리지 않는다. |
| 빈도 제한 | uid당 `rankingSubmitMinGapMs`(= `rankingSubmitIntervalMs` ÷ 5 = 1분) 안의 재호출은 `resource-exhausted`. 앱도 즉시 제출(레벨업 등)을 포함해 이 간격을 지킨다. |
| 비정상 증가 | 판정 기준은 `lib/ranking_config.dart`. 순위표별 하한(초당 100만, 누적 10억, 콤보 1000) 이하는 항상 통과. 그 위로는 `max(이전 최고, 하한) × 10 × 10^(이전 최고 이후 시간)`까지만 받는다(한 번에 10배, 5분 뒤 약 12배, 1시간 뒤 100배, 하루 뒤 사실상 제한 없음). 거절돼도 나중에 다시 보내면 된다. 서버 값은 `firebase/functions/src/ranking.ts`에 있고 `test/stage16_kakao_ranking_test.dart`가 두 값이 같은지 확인한다. |
| 순위 | `rankingTop`은 점수 내림차순, 같은 점수는 먼저 기록한 사람이 위(복합 인덱스 `score DESC, updatedAt ASC`). 같은 점수는 같은 순위(1, 2, 2, 4). 내 순위는 `count()` 집계(`score > 내 점수`) + 1. 결과에는 uid 대신 해시한 `playerId`만 담아 카카오 회원번호가 나가지 않는다. |
| 규칙 | `firestore.rules`에서 `rankings`를 명시적으로 막았다(전체 차단 규칙과 별도). |

## 바뀐 파일

- 서버: `firebase/functions/src/auth.ts`(신규, `signedIn`), `kakao.ts`(신규, `authKakao`), `ranking.ts`(신규), `index.ts`, `invites.ts`(주석), `test/kakao.test.ts`·`test/ranking.test.ts`(신규), `firebase/firestore.rules`, `firebase/firestore.indexes.json`, `firebase/functions/.gitignore`
- 앱: `pubspec.yaml`/`pubspec.lock`(`kakao_flutter_sdk_user` 2.0.1), `lib/main.dart`, `lib/firebase_online_backend.dart`, `lib/online_backend.dart`, `lib/online_controller.dart`, `lib/online_ranking.dart`, `lib/ranking_config.dart`, `lib/ranking_controller.dart`, `lib/game_controller.dart`(필드 3줄), `lib/premium_controller.dart`, `lib/server_invite_repository.dart`, `lib/ui/ranking_panel.dart`(신규), `lib/ui/progress_panels.dart`(랭킹 카드 삭제), `lib/ui/public_menus.dart`(메뉴 '온라인 랭킹'), `lib/ui/game_app.dart`, `lib/ui/friends_panel.dart`, `lib/ui/gold_widgets.dart`
- Android: `build.gradle.kts`(소스셋 분기·게임 SDK 삭제, dart-define 읽기), `AndroidManifest.xml`(`AuthCodeHandlerActivity`, 앱 클래스·게임 메타데이터 삭제), `MainActivity.kt`(브리지 호출 삭제). 삭제: 브리지 소스셋 폴더 2개(앱 ID 유무에 따른 분기), `res/values/games-ids.xml`, `res/values/firebase-ids.xml`(게임 로그인용 서버 클라이언트 ID라 더 쓰지 않음)
- 테스트: `test/stage9_ranking_test.dart`(재작성), `test/stage16_kakao_ranking_test.dart`(신규), `test/widget_test.dart`(`mountGame`에 `online` 인자, 메뉴 목록에 '온라인 랭킹'), `test/online_backend_test.dart`, `test/premium_flow_test.dart`, `test/no_tracking_sdk_test.dart`
- 문서: `README.md`, `docs/privacy_policy.md`, `docs/play_data_safety.md`, `docs/플레이_가이드.md`, `docs/stage15_release_online.md`, `docs/stage10_feedback_sound.md`(한 줄), `docs/stage9_play_games_ranking.md`(대체됨 표시, 요약), 이 문서

### 기존 테스트 변경과 이유

| 파일 | 변경 | 이유 |
|---|---|---|
| `premium_flow_test.dart` 방문·Lv.1 테스트 | 시작 후 `await b.signIn()` 추가 | 배경 동기화가 더는 로그인 화면을 열지 않는다. 테스트 의도(로그인한 플레이어의 방문·Lv.1 처리)는 같다. |
| 같은 파일 친구 실패 문구 | `allowSignIn = false` → `signInResult = canceled`, 기대 문구 '카카오 계정으로 로그인해 주세요' | 로그인 결과가 성공/취소/실패 셋으로 나뉘었다. |
| `online_backend_test.dart` | `signIn()` 기대값을 `SignInResult`로 | 같은 이유. |
| `no_tracking_sdk_test.dart` | 게임 SDK 허용 → Google Play 서비스 라이브러리 전부 금지. 합성 매니페스트 예시를 카카오 항목으로 | 게임 SDK를 지웠다. 카카오 패키지는 금지어에 걸리지 않아 허용 목록을 늘리지 않았다. |
| `stage9_ranking_test.dart` | 채널 테스트 삭제, 즉시 제출도 1분 간격을 지키도록 기대값 조정, 로그인·랭킹 화면 테스트로 교체 | 채널이 없어졌고 서버 빈도 제한이 생겼다. |

## 직접 하셔야 하는 콘솔 작업

1. **카카오 개발자 콘솔**: 앱 추가 → 네이티브 앱 키, 앱 ID 확인. 플랫폼 Android에 패키지명 `com.todaybungeoppang.todays_bungeoppang`과 키 해시 3개(디버그 키, 업로드 키, Play Console 앱 서명 키) 등록. 카카오 로그인 활성화, 동의항목 '닉네임' 선택 동의.
2. **Firebase / Google Cloud**: `firebase/functions/.env`에 `KAKAO_APP_ID=<앱 ID>`(커밋 금지). Functions 실행 서비스 계정에 `roles/iam.serviceAccountTokenCreator`(없으면 `createCustomToken` 실패). `firebase deploy --only functions,firestore`로 함수·규칙·인덱스 배포. Authentication의 게임 로그인 제공업체는 꺼도 된다.
3. **Play Console**: 게임 서비스 프로젝트(리더보드)는 쓰지 않는다. 인앱 상품은 그대로. 데이터 보안 양식을 [기준 문서](play_data_safety.md)대로 다시 제출.
4. **빌드**: `flutter run --dart-define=KAKAO_NATIVE_APP_KEY=<키>`와 15단계의 Firebase dart-define.

## 실제 실행한 검증

이 문서 작성 시점의 결과는 작업 보고에 적었다. 요약: functions `npm test`, `flutter test`, `flutter analyze`, 키 없는 `flutter build apk --debug`.

## 실행하지 못한 검증

- 실제 카카오 로그인(카카오톡/카카오계정), `authKakao`의 실제 카카오 API 호출, 커스텀 토큰 발급, Firestore `count()`·복합 인덱스 쿼리는 실행하지 못했다. 카카오 앱과 Firebase 프로젝트가 없다. 서버 로직은 가짜 카카오 API와 메모리 저장소로, 앱 로직은 `FakeOnlineBackend`로 확인했다.
- 카카오계정 로그인 뒤 브라우저에서 앱으로 돌아오는 리다이렉트(`AuthCodeHandlerActivity`)는 기기에서 확인하지 못했다.

## 잔여 위험

- **부정 점수**: 점수는 기기에서 계산한다. 서버는 형식·빈도·증가 폭만 본다. 첫 제출은 상한(2^63-1)까지 무엇이든 받는다. 순위표를 지켜보다 이상한 기록은 콘솔에서 지워야 한다.
- **아주 큰 점수의 순서**: 정렬용 `score`는 배정밀도라 2^53을 넘는 서로 다른 점수가 같은 순위로 보일 수 있다(표시 값 `scoreText`는 정확).
- **카카오 동의항목 변경**: 닉네임 동의를 나중에 철회하면 다음 로그인 때 이름이 '친구'로 바뀐다.
- **로그아웃 범위**: 앱 로그아웃은 카카오 연결 끊기(unlink)가 아니다. 탈퇴·연결 끊기는 다음 단계에서 다룬다.
