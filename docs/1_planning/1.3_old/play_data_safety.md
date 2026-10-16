# Play Console 데이터 보안 양식 작성 기준

기준일: 2026-10-07. 15단계(온라인 기능)와 16단계(카카오 로그인, 자체 랭킹)를 반영했습니다.

## 점검 결과

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| 광고 SDK | 없음 | `pubspec.lock`, Android Gradle 설정 |
| 분석·오류 수집 SDK | 별도 SDK 없음. Firebase Analytics·Crashlytics 미포함 | `test/no_tracking_sdk_test.dart`가 금지 |
| 인앱결제 | Google Play 결제(`in_app_purchase`) | 황금 붕어빵 5개 소비성 상품 |
| Firebase | Auth(카카오 로그인으로 만든 커스텀 토큰), Cloud Functions만 | Firestore는 서버(Functions)만 접근. 앱 직접 접근 차단(`firebase/firestore.rules`). 순위표도 서버에 저장 |
| 카카오 SDK | `kakao_flutter_sdk_user`(로그인만). 친구·메시지 API 안 씀 | 카카오 회원번호와(동의 시) 닉네임을 서버가 카카오 API로 확인 |
| 네트워크 | INTERNET 권한 있음(Firebase) | release 병합 매니페스트에서 확인 |
| 광고 ID | 없음 | 병합 매니페스트에 `AD_ID` 없음(테스트로 검사) |
| 그 밖의 권한 | `ACCESS_NETWORK_STATE`, `com.android.vending.BILLING`, `WAKE_LOCK`, `READ_GSERVICES`, `c2dm.permission.RECEIVE` | 2026-10-07 release 빌드 병합 매니페스트. 뒤의 세 개는 Firebase SDK(설치 ID·서버 통신)가 넣음. 푸시 알림 기능은 쓰지 않음 |
| Firebase 설치 ID | Firebase SDK가 기기별 설치 ID를 만들어 서버 호출에 씀 | 양식의 '기기 또는 기타 ID'에 해당하는지 제출 전 확인 |

`test/no_tracking_sdk_test.dart`는 허용 목록 밖의 Firebase·결제 패키지와 광고·분석 SDK·광고 ID가 들어오면 실패합니다.

## 양식 답변 (온라인 기능을 켠 빌드)

온라인 기능을 켠 빌드는 Firebase 설정과 카카오 네이티브 앱 키(`--dart-define`)가 있는 빌드입니다. 설정이 없는 빌드는 온라인 기능이 꺼지지만, Firebase·카카오·결제 라이브러리 자체는 포함됩니다.

| 질문 | 답변 |
| --- | --- |
| 수집하거나 공유하나요? | **예** |
| 전송 중 암호화 | 예(HTTPS) |
| 삭제 요청 방법 | 개인정보처리방침의 이메일로 요청(30일 안에 삭제) |
| 개인정보처리방침 URL | `docs/privacy_policy.md`를 공개 웹 페이지로 올린 주소 |

| 데이터 유형(Play 분류) | 수집 | 공유 | 필수 여부 | 목적 |
| --- | --- | --- | --- | --- |
| 개인 정보 > 사용자 ID (카카오 회원번호, 이를 담은 Firebase 계정 ID) | 예 | 아니요 | 선택(온라인 기능 사용 시) | 앱 기능, 계정 관리, 사기 방지 |
| 개인 정보 > 이름 (카카오 닉네임, 동의한 경우) | 예 | 아니요 | 선택 | 앱 기능(친구·순위표 표시) |
| 금융 정보 > 구매 내역 (주문 번호, 상품, 황금 붕어빵 사용 기록) | 예 | 아니요 | 선택(구매 시) | 앱 기능, 사기 방지 |
| 앱 활동 > 기타 사용자 생성 콘텐츠·앱 내 작업 (아바타 꾸미기, 친구·방문·초대 기록) | 예 | 아니요 | 선택 | 앱 기능 |
| 앱 활동 > 앱 상호작용·게임 점수 (순위표 3개, 자체 서버) | 예 | 아니요 | 선택 | 앱 기능 |

- Google(Firebase, Play)은 개발자를 대신해 처리하는 서비스 제공업체이므로 '공유'에 넣지 않습니다(Google 정의 기준).
- 카카오는 사용자가 직접 고른 로그인 수단이고, 개발자가 카카오에 게임 데이터를 보내지 않으므로 '공유'에 넣지 않습니다. 카카오 SDK가 로그인 요청에 함께 보내는 앱·OS 버전, 기기 모델이 '수집'에 해당하는지는 제출 시점의 Google 가이드로 다시 확인합니다.
- 순위표의 이름·점수가 다른 플레이어에게 보이는 것은 앱 기능이며, Google 정의상 '공유'(제3자 전송)가 아닙니다.
- 각 항목을 Play Console 분류에 어떻게 대응시킬지는 제출 시점의 Google 가이드를 다시 확인해 개발자가 최종 판단합니다.

## 출시 전 확인

- [x] `privacy_policy.md` 연락처
- [ ] `privacy_policy.md`를 로그인 없이 열리는 공개 URL에 올리기
- [ ] 스토어 등록정보 "광고 포함": **아니요**
- [ ] 스토어 등록정보 "인앱 구매 포함": **예**
- [ ] 콘텐츠 등급 설문: 사용자 간 상호작용(친구 방문), 디지털 구매 있음으로 답하기
- [ ] `flutter test` 통과(SDK 검사 포함)
- [ ] 출시용 AAB의 병합 매니페스트에 `AD_ID`·분석 항목이 없는지 확인(`no_tracking_sdk_test`의 release 검사가 빌드 후 자동 확인)
- [ ] 계정 삭제 요청 방법을 Play Console '데이터 삭제' 항목에 입력(앱 계정이 있는 앱은 필수)

## 다시 검토할 때

- 서버에 새 정보를 저장하는 기능을 추가할 때(`firebase/functions/src`)
- Firebase 다른 제품(Analytics, Crashlytics, Messaging 등)을 넣을 때: 테스트가 막으므로 의도한 경우에만 허용 목록과 이 문서를 함께 고칩니다.
- 공유 문구에 사용자별 값을 더 넣을 때
