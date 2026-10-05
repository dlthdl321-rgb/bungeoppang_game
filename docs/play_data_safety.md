# Play Console 데이터 보안 양식 작성 기준

기준일: 2026-10-05 · 앱 버전 0.1.0+1

## 점검 결과

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| 광고 SDK | 없음 | `pubspec.yaml`/`pubspec.lock`, Android Gradle 설정 |
| 인앱결제 SDK | 없음 | 위와 같음 |
| 분석·오류 수집 SDK | 별도 SDK 없음. 단, Play 게임즈 SDK 자체가 분석·진단 정보를 Google로 보냄(랭킹을 켠 빌드) | 위와 같음, 아래 표 |
| Google Play 게임즈 서비스 | v2 리더보드만(앱 ID 설정 시) | `play-services-games-v2` 22.1.0, `games-ids.xml`의 `app_id`가 있을 때만 링크 |
| 네트워크 | 배포 빌드에 INTERNET 권한 없음 | 병합 매니페스트에서 INTERNET은 `src/debug/AndroidManifest.xml`에서만 들어옴 |
| 직접 의존성 | `sqflite`, `path`, `share_plus` | 기기 저장, 경로 처리, OS 공유 창 |

`test/no_tracking_sdk_test.dart`가 의존성 목록을 검사해, 금지 SDK가 들어오면 `flutter test`에서 실패합니다.

## 양식 답변

Google 정의상 "수집"은 앱(SDK 포함)이 기기 밖으로 데이터를 전송하는 것입니다. 기기 안에서만 처리하는 데이터는 공개 대상이 아닙니다. 사용자가 직접 시작한 전송은 "공유"에서 제외됩니다. 데이터를 수집하지 않는 앱도 양식을 작성하고 개인정보처리방침 링크를 제출해야 합니다. ([Google Play 고객센터: 데이터 보안 섹션](https://support.google.com/googleplay/android-developer/answer/10787469))

### Play 게임즈 연결 여부에 따라 답이 달라집니다

`android/app/src/main/res/values/games-ids.xml`의 `app_id`가 **비어 있으면** Play 게임즈 SDK가 빌드에 들어가지 않습니다(`android/app/build.gradle.kts`). 이때는 이전과 같이 **"아니요(수집·공유 없음)"**입니다.

Play Console ID를 넣어 **온라인 랭킹을 켠 빌드**는 Play 게임즈 서비스 v2 SDK가 데이터를 보냅니다. SDK가 수집하는 데이터도 앱의 수집으로 신고해야 하므로 답은 **"예"**입니다. Google의 [Play 게임즈 서비스 데이터 공개 가이드](https://developer.android.com/games/pgs/data-collection)에 따른 이 앱의 해당 항목은 다음과 같습니다.

| Google 가이드의 데이터 | 이 앱에서 | 비고 |
| --- | --- | --- |
| 게이머 ID(게이머 이름, 아바타) | 수집 | Play 게임즈 로그인 시. 사용자가 공개 범위 설정 |
| 분석 데이터 | 수집(자동) | SDK 안정성·개선 목적, 일시적 |
| 진단 데이터 | 수집(자동) | SDK 안정성·개선 목적, 일시적 |
| 게임 점수 | 수집 | 순위표 3개(최고 초당 생산, 누적 생산, 최고 콤보) |
| 업적, 저장된 게임, 친구, 이벤트 등 | 사용 안 함 | 앱 내 업적은 기기에만 저장 |

양식 공통 답변(랭킹을 켠 빌드):

| 질문 | 답변 |
| --- | --- |
| 수집하거나 공유하나요? | 예(Play 게임즈 서비스 SDK) |
| 전송 중 암호화 | 예(HTTPS, Google 가이드 기준) |
| 사용자 삭제 요청 방법 | Play 게임즈 프로필 또는 Google 계정에서 삭제 |
| 개인정보처리방침 URL | `docs/privacy_policy.md`를 공개 웹 페이지로 올린 주소 |

Play Console 양식의 각 데이터 유형·목적에 어떻게 대응시킬지는 제출 시점의 Google 가이드를 다시 확인해 개발자가 최종 판단합니다. 이 표는 그 판단을 돕기 위한 기준입니다.

### 판단 근거

- 게임 진행, 내 기록, 주간 도전, 업적은 기기 SQLite에만 저장하며 전송하지 않습니다(기기 내 처리). 이전 버전의 초대 시험 기록이 저장에 남아 있어도 배포 빌드는 사용하지 않습니다.
- 게임 공유는 사용자가 버튼을 누르고 받는 앱을 직접 고릅니다. 앱이 서버로 보내지 않으며, 내용은 고정된 게임 소개 문구와 스토어 링크(`invite_config.dart`의 `storeUrl`)뿐입니다. 사용자·기기 식별자나 추적 파라미터는 붙이지 않습니다.
- 친구 초대 시뮬레이터·추천 코드·개발자 도구는 디버그 빌드(`kReleaseMode`가 false)에서만 열립니다.
- `share_plus`는 Android 공유 인텐트만 엽니다. `sqflite`·`path`는 네트워크를 쓰지 않습니다.
- Play 게임즈 서비스 v2는 Google Play 서비스 앱을 통해 통신하므로, 앱 자체 release 병합 매니페스트에는 INTERNET 권한이 없습니다(2026-10-05 빌드에서 확인). 광고 ID·결제·Firebase·Google 애널리틱스 항목도 없습니다.

## 출시 전 확인

- [x] `privacy_policy.md`의 연락처를 dlthdl321@gmail.com으로 채웠습니다.
- [ ] `privacy_policy.md`를 로그인 없이 열리는 공개 URL에 올립니다.
- [ ] 스토어 등록정보의 "광고 포함" 항목을 **아니요**로 둡니다.
- [ ] `flutter test`를 실행해 SDK 검사 테스트가 통과하는지 확인합니다.
- [ ] 출시용 AAB를 만든 뒤 병합된 release 매니페스트에 INTERNET 권한이 없는지 확인합니다.

## 다시 검토할 때

아래 중 하나라도 바뀌면 이 문서, 개인정보처리방침, Play Console 양식을 함께 고칩니다.

- `games-ids.xml`에 Play Console ID를 넣어 랭킹을 켤 때: 위 "예" 답변으로 양식을 바꿉니다.
- Play 게임즈의 업적·클라우드 저장·친구 기능을 추가로 쓸 때: 그 기능이 처리하는 데이터를 당시의 Google 공식 문서에서 확인해 반영합니다.
- 디버그 전용 초대 기능을 실제 서버에 연결해 배포할 때(README의 `InvitationRepository` 교체 지점).
- 공유 문구에 사용자별 값(추천 코드, 진행 정보 등)을 넣을 때.
- 네트워크를 쓰는 패키지나 INTERNET 권한을 추가할 때.
