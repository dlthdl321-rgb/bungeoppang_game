# 9단계 — Google Play 게임즈 온라인 랭킹

작성: 2026-10-05. 시작 기준: 커밋 `3f6baca stage8`(테스트 217개). 실행 환경은 8단계와 같다(`B:` subst, `GRADLE_USER_HOME=C:\GradleCache`).

## 결정 기록

- 사용자 요청: 다른 기기 사용자끼리 겨루는 랭킹. 서버가 필요하다고 보고하고 A(Play 게임즈 리더보드), B(자체 서버), C(오프라인 공유) 중 **A**로 결정받았다.
- 설계안(자체 v2 연동, 리더보드 3개, 드문 제출) 승인. 참여 방식은 권장안(선택 참여) 대신 **앱 시작 시 자동**(Google 권장 방식)으로 결정받았다. 그래서 참여 여부를 저장할 필요가 없어졌다. 설계표에 있던 **저장 v8은 만들지 않았고 v7을 유지**한다.
- 조사 결과: 대표 플러그인 `games_services` 5.3.0은 v1 SDK(`play-services-games:21.0.0`)를 쓴다. Google 일정상 v1은 2025년 9월부터 신규 게임 게시에 쓸 수 없으므로 v2(`play-services-games-v2` 22.1.0, 2026-09-15 메이븐 기준 최신)를 직접 연동했다.
- 구현 중 결정(안전장치): 앱 ID가 빈 상태에서 SDK의 자동 초기화 프로바이더(`PlayGamesInitProvider`)가 앱을 종료시키는지 공개 자료로 확인하지 못했고, 에뮬레이터 실행도 실패했다. 그래서 `games-ids.xml`에 숫자 앱 ID가 있을 때만 SDK와 연동 코드를 빌드에 넣는다. 설정 전 빌드는 8단계와 동일하게 아무것도 수집하지 않는다.

## 범위

| 항목 | 내용 |
|---|---|
| Android | `build.gradle.kts`가 `games-ids.xml`의 `app_id`를 읽는다. 값이 있으면 `play-services-games-v2:22.1.0`과 `src/playGames/kotlin/PlayGamesBridge.kt`(v2 SDK 초기화, 로그인 상태 확인, 로그인, 점수 제출, 전체 순위표 화면)를 빌드한다. 값이 없으면 `src/noPlayGames/kotlin/PlayGamesBridge.kt`(항상 "설정 안 됨")를 빌드한다. `GamesApplication.onCreate`에서 초기화한다(Google 권장). 채널은 `todays_bungeoppang/play_games`, 리더보드 ID는 `games-ids.xml` |
| Dart | `online_ranking.dart`(`RankingService`, `PlayGamesRankingService`, `NoRankingService`, 점수 변환), `ranking_config.dart`(리더보드 이름, 64비트 상한, 5분 간격), `ranking_controller.dart`(상태 새로고침, 로그인, 제출, 순위 보기). `main.dart`는 Android에서만 Play 게임즈 서비스를 주입한다 |
| 리더보드 | 최고 초당 생산(아이템 제외), 누적 생산(922경 초과 시 상한으로 보내고 화면에 알림), 최고 콤보 |
| 제출 | 탭마다 보내지 않는다. 플레이 중 최대 5분 간격, 레벨업·앱 나가기·순위 보기·로그인 직후에는 즉시 보낸다. 직전 제출과 같으면 생략한다. 저장 파일·DB와 무관하다 |
| UI | 내 기록 화면에 "온라인 랭킹 · Google Play 게임즈" 카드를 넣었다. 설정 전에는 "준비 중", 미로그인이면 로그인 버튼, 로그인하면 순위 보기 버튼을 보여 준다. 설명 문구는 "다른 사람과 비교하지 않음"에서 사실에 맞게 바꿨다 |
| 문서 | 개인정보처리방침(Play 게임즈 절 신설, 절 번호 재정렬), 데이터 보안 기준(연결 여부별 답변, Google 가이드 기반 데이터 표), README(온라인 랭킹 절, Play Console 설정 절차) |

## 변경 파일

- Android: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`(앱 클래스, APP_ID 메타데이터), `android/app/src/main/res/values/games-ids.xml`(신규, 빈 값), `android/app/src/main/kotlin/.../MainActivity.kt`, `android/app/src/playGames/kotlin/.../PlayGamesBridge.kt`(신규), `android/app/src/noPlayGames/kotlin/.../PlayGamesBridge.kt`(신규)
- lib: `online_ranking.dart`, `ranking_config.dart`, `ranking_controller.dart`(신규), `game_controller.dart`, `main.dart`, `ui/progress_panels.dart`
- 테스트: `test/stage9_ranking_test.dart`(신규 18개), `test/no_tracking_sdk_test.dart`, `test/widget_test.dart`(`mountGame`에 `ranking` 선택 인자만 추가)
- 문서: `README.md`, `docs/privacy_policy.md`, `docs/play_data_safety.md`, 이 문서

### 기존 테스트 변경과 이유

| 파일 | 변경 | 이유 |
|---|---|---|
| `no_tracking_sdk_test.dart` Gradle 검사 | `play-services` 전면 금지 → Play 서비스 모듈 중 `play-services-games-v2`만 허용. `com.google.gms`(google-services 플러그인)와 Firebase 금지는 그대로 | 승인된 A안. 다른 Play 서비스 모듈(광고, 분석 등)이 들어오면 계속 실패한다 |
| 같은 파일 병합 매니페스트 검사 | `com.google.android.gms` 전면 금지 → 광고(`gms.ads`), 분석(`gms.measurement`), 광고 ID, 결제, Firebase를 개별 금지. INTERNET·ACCESS_NETWORK_STATE 금지는 **유지** | v2 SDK의 Play 게임즈 컴포넌트가 병합되므로 필요하다. 실제 병합 결과에 인터넷 권한이 없어 그 검사는 약화하지 않았다 |
| 같은 파일 합성 매니페스트 테스트 | Play 게임즈 항목은 통과하고 인터넷·광고 ID·결제·분석은 걸리는지 확인하도록 바꿨다 | 위와 같은 규칙 변경 |

나머지 테스트, 골든, 기대값은 바꾸지 않았다.

## 실제 실행한 검증

- `dart format --set-exit-if-changed lib test`: 변경 0개
- `flutter analyze`: No issues found
- `flutter test`: **235개 전부 통과, skip 0**(217 + 18). release 병합 매니페스트 검사는 아래 기본 구성 빌드 산출물로 실행됐다.
- 신규 테스트 내용:
  - 64비트 상한 처리
  - 탭 300번·30초 동안 제출 없음, 5분 뒤 1회 제출, 변화 없으면 생략, 제출이 저장 횟수를 늘리지 않음
  - 레벨업·앱 나가기·순위 보기에서 즉시 제출
  - 미로그인·미설정 시 제출·로그인 시도 없음, 로그인 직후 제출
  - 채널: 플러그인 없음, 정상 응답, 플랫폼 오류 처리
  - 내 기록 랭킹 카드: 3×3 화면·글자 조합에서 로그인 → 상한 안내 → 순위 보기, overflow 없음, 시제품 문구 없음
  - 설정 전 "준비 중" 표시
- `flutter build apk --release` **기본 구성(app_id 비어 있음)**: 성공, 48.3MB(50,696,323 bytes). 병합 매니페스트의 Google 항목은 사용되지 않는 `games.APP_ID` 메타데이터 하나뿐이다(SDK 미포함).
- `flutter build apk --release` **임시 앱 ID(123456789012) 구성**: 성공, 48.6MB. `PlayGamesInitProvider`가 병합되고 INTERNET·광고 ID·결제 권한이 없음을 확인했다. 빌드 후 `games-ids.xml`을 원래(빈 값)로 되돌렸다(확인함).

## 실행하지 못한 검증

- **실제 로그인·점수 제출·순위표 화면은 한 번도 실행하지 못했다.** Play Console 게임 프로젝트, 앱 ID, 리더보드 ID, OAuth/SHA-1 등록, 테스터 계정이 없다. 현재 에뮬레이터 이미지(`android-35/default`, Play 스토어 없음)에는 Play 게임즈가 없다.
- 에뮬레이터 부팅을 시도했지만 12분 이상 부팅 애니메이션 단계에서 멈췄다(`Can't find service: package`). 그래서 release APK 설치와 앱 시작(설정 전 구성 포함)을 기기에서 확인하지 못했다. 에뮬레이터는 종료했다.
- 앱 ID를 넣은 구성에서 `PlayGamesInitProvider`와 `GamesApplication`이 실제 기기에서 정상 시작하는지는 확인하지 못했다(컴파일과 매니페스트 병합까지만).
- 64비트 상한값이 Play 게임즈 숫자 형식에서 어떻게 표시되는지 확인하지 못했다.
- iOS(Game Center)는 범위 밖이다. iOS에서는 `NoRankingService`로 "준비 중"이 표시된다.

## 잔여 위험

- **부정 점수**: 점수를 기기에서 계산하므로 저장 파일 수정이나 시계 조작으로 부풀릴 수 있다. Play Console의 조작 방지와 리더보드별 점수 상한(특히 콤보)을 반드시 설정해야 한다. 서버 검증은 없다.
- **데이터 보안 양식**: 앱 ID를 넣는 순간 "수집함"으로 바꿔야 한다. 앱 시작 시 자동 초기화 방식이라 로그인하지 않은 사용자에게서도 SDK 분석·진단 데이터가 전송될 수 있다(Google 가이드 기준). 양식 항목 대응은 제출 시점의 Google 가이드로 다시 확인해야 한다.
- **설정 의존성**: release 서명 키 생성, 앱 서명 키 SHA-1 등록, 리더보드 생성이 모두 끝나야 동작한다. SHA-1이 틀리면 로그인이 조용히 실패하고 화면에는 로그인 버튼만 남는다.
- **로그인 대기 처리**: 로그인 실패 때 SDK는 자동 재시도하고, 앱은 복귀(resume) 때 상태를 다시 확인한다. 로그인 창이 열려 있는 동안의 동작은 기기에서 확인하지 않았다.
- **빌드 경고**: `share_plus`가 Kotlin Gradle 플러그인을 적용한다는 Flutter 경고가 계속 나온다. 향후 Flutter 버전에서 빌드 실패 원인이 될 수 있으니 플러그인 업데이트를 지켜봐야 한다.
