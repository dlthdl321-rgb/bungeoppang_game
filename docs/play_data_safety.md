# Play Console 데이터 보안 양식 작성 기준

기준일: 2026-10-05 · 앱 버전 0.1.0+1

## 점검 결과

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| 광고 SDK | 없음 | `pubspec.yaml`/`pubspec.lock`, Android Gradle 설정 |
| 인앱결제 SDK | 없음 | 위와 같음 |
| 분석·오류 수집 SDK | 없음 | 위와 같음 |
| Google Play 게임즈 서비스 | 연동 안 함 | 의존성·Gradle·매니페스트에 `play_games`/`gms` 없음 |
| 네트워크 | 배포 빌드에 INTERNET 권한 없음 | 병합 매니페스트에서 INTERNET은 `src/debug/AndroidManifest.xml`에서만 들어옴 |
| 직접 의존성 | `sqflite`, `path`, `share_plus` | 기기 저장, 경로 처리, OS 공유 창 |

`test/no_tracking_sdk_test.dart`가 의존성 목록을 검사해, 금지 SDK가 들어오면 `flutter test`에서 실패합니다.

## 양식 답변

Google 정의상 "수집"은 앱(SDK 포함)이 기기 밖으로 데이터를 전송하는 것입니다. 기기 안에서만 처리하는 데이터는 공개 대상이 아닙니다. 사용자가 직접 시작한 전송은 "공유"에서 제외됩니다. 데이터를 수집하지 않는 앱도 양식을 작성하고 개인정보처리방침 링크를 제출해야 합니다. ([Google Play 고객센터: 데이터 보안 섹션](https://support.google.com/googleplay/android-developer/answer/10787469))

| 질문 | 답변 |
| --- | --- |
| 앱이 필수 사용자 데이터 유형을 수집하거나 공유하나요? | **아니요** |
| 개인정보처리방침 URL | `docs/privacy_policy.md`를 공개 웹 페이지로 올린 주소 |

"아니요"를 고르면 암호화·삭제 요청 문항은 나오지 않습니다. 스토어에는 "수집된 데이터 없음", "제3자와 공유된 데이터 없음"으로 표시됩니다.

### 판단 근거

- 게임 진행, 가상 플레이어 ID, 추천 코드는 기기 SQLite에만 저장하며 전송하지 않습니다(기기 내 처리).
- 초대 문구 복사·공유는 사용자가 버튼을 누르고 받는 앱을 직접 고릅니다. 앱이 서버로 보내지 않으며, 내용은 무작위 모의 코드와 연결되지 않는 `example.invalid` 링크뿐입니다.
- `share_plus`는 Android 공유 인텐트만 엽니다. `sqflite`·`path`는 네트워크를 쓰지 않습니다.

## 출시 전 확인

- [ ] `privacy_policy.md`의 `[연락처 이메일]`을 실제 연락처로 바꾸고, 로그인 없이 열리는 공개 URL에 올립니다.
- [ ] 스토어 등록정보의 "광고 포함" 항목을 **아니요**로 둡니다.
- [ ] `flutter test`를 실행해 SDK 검사 테스트가 통과하는지 확인합니다.
- [ ] 출시용 AAB를 만든 뒤 병합된 release 매니페스트에 INTERNET 권한이 없는지 확인합니다.

## 다시 검토할 때

아래 중 하나라도 바뀌면 이 문서, 개인정보처리방침, Play Console 양식을 함께 고칩니다.

- Google Play 게임즈 서비스, 로그인, 클라우드 저장, 리더보드를 추가할 때: 그 서비스가 처리하는 데이터를 당시의 Google 공식 문서에서 확인해 반영합니다.
- 초대 기능을 실제 서버에 연결할 때(README의 `InvitationRepository` 교체 지점).
- 네트워크를 쓰는 패키지나 INTERNET 권한을 추가할 때.
