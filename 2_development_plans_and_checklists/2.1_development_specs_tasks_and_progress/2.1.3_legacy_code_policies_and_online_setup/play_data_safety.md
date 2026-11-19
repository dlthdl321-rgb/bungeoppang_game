# Play Console 데이터 보안 양식 작성 기준

기준일: 2026-10-07. 15단계(온라인 기능)와 16단계(카카오 로그인, 자체 랭킹)를 반영했습니다. **2026-11-18 26번 2-1단계**: 첫 실행 로그인 필수(카카오·구글), 이메일·사장님 이름(필수), 성별·연령대(선택), 앱 안 계정 삭제를 반영했습니다. **2026-11-19 26번 5단계**: 사용 통계(Google Analytics for Firebase, 기본 켬·설정에서 끔, 광고 ID 미수집)를 반영했습니다. **2026-11-19 법률 확인 반영**: 만 14세 미만 가입 불가('만 14세 이상입니다' 필수 체크), 사용 통계는 첫 실행 필수 동의 뒤부터 수집(그 전에는 Analytics 수집 꺼짐 — 자동 `first_open` 포함), 개인정보처리방침 처리 근거·국외 이전 표 보완.

## 점검 결과

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| 광고 SDK | 없음 | `pubspec.lock`, Android Gradle 설정 |
| 분석 SDK (26번 5단계) | **Firebase Analytics(`firebase_analytics` 12.6.1)만**. 이벤트 7종(첫 굽기·첫 판매·안내 끝·Lv.3/5/10·상점 열기·충전 화면·결제 완료 상품 ID) + 자동 수집(first_open·session_start·앱 버전·기기 종류 등) + Firebase 앱 인스턴스 ID + 선택 동의한 성별·연령대(사용자 속성). 이름·이메일·계정 ID·광고 ID·SSAID 안 보냄, `setUserId` 안 씀. 보관 14개월. 설정 '사용 통계 보내기'로 끔. **첫 실행 필수 동의 전에는 수집 꺼짐**(매니페스트 기본 false, 동의 뒤 `setAnalyticsCollectionEnabled(true)`) | `test/no_tracking_sdk_test.dart`(허용 목록·매니페스트), `test/usage_stats_test.dart`, `test/owner_first_run_test.dart` |
| 오류 수집 SDK | 없음. Crashlytics·Sentry 금지 | `test/no_tracking_sdk_test.dart` |
| 인앱결제 | Google Play 결제(`in_app_purchase`) | 황금 붕어빵 5개 소비성 상품 |
| Firebase | Auth(카카오 로그인으로 만든 커스텀 토큰), Cloud Functions만 | Firestore는 서버(Functions)만 접근. 앱 직접 접근 차단(`firebase/firestore.rules`). 순위표도 서버에 저장 |
| 카카오 SDK | `kakao_flutter_sdk_user`(로그인만). 친구·메시지 API 안 씀 | 카카오 회원번호와(동의 시) 닉네임·이메일을 서버가 카카오 API로 확인 |
| 구글 로그인 (26번 2-1단계) | `google_sign_in` 7.2.0(Credential Manager 계정 선택만) → Firebase Auth Google 공급자 | 계정 ID·확인된 이메일. 광고·분석 기능 없음, 금지 단어에 걸리지 않아 `no_tracking_sdk_test` 허용 목록 변경 없음. release 병합 매니페스트(2026-11-19)에서 이 라이브러리가 `USE_BIOMETRIC`·`USE_FINGERPRINT`(일반 권한)를 더함, 광고·분석 항목 없음 |
| 네트워크 | INTERNET 권한 있음(Firebase) | release 병합 매니페스트에서 확인 |
| 광고 ID | 없음 | Analytics가 넣는 `AD_ID`·`ACCESS_ADSERVICES_AD_ID`·`_ATTRIBUTION`·`_TOPICS` 권한과 `android.ext.adservices` 라이브러리를 `tools:node="remove"`로 빼고, `google_analytics_adid_collection_enabled`·`ssaid`·개인화 광고 신호를 false로. 병합 매니페스트에 `AD_ID` 없음(테스트로 검사, 2026-11-19 profile 병합 매니페스트와 업로드 키 release 병합 매니페스트로 확인) |
| 그 밖의 권한 | `ACCESS_NETWORK_STATE`, `com.android.vending.BILLING`, `WAKE_LOCK`, `READ_GSERVICES`, `c2dm.permission.RECEIVE`, `POST_NOTIFICATIONS`·`RECEIVE_BOOT_COMPLETED`·`VIBRATE`(손님 알림), `BIND_GET_INSTALL_REFERRER_SERVICE`(Analytics), `USE_BIOMETRIC`·`USE_FINGERPRINT`(구글 로그인 라이브러리 androidx.credentials → androidx.biometric, 앱은 생체 인증을 쓰지 않음, DEC-120), `앱패키지.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`(androidx.core, 앱 내부 전용) — `INTERNET` 포함 13개 | 2026-11-19 업로드 키 release APK(`aapt dump badging`, 23번 6단계 '26번 반영 뒤 권한' 표와 같음). `WAKE_LOCK`·`READ_GSERVICES`·`c2dm.permission.RECEIVE`는 Firebase SDK(설치 ID·서버 통신·Analytics)가 넣음. 푸시 알림 기능은 쓰지 않음 |
| Firebase 설치 ID·앱 인스턴스 ID | Firebase SDK가 기기별 설치 ID를 만들어 서버 호출에 쓰고, Analytics가 앱 인스턴스 ID로 같은 기기의 통계를 이음 | 양식의 **'기기 또는 기타 ID'에 '예'**(26번 5단계부터, 분석 목적) |
| 새 권한 (26번 5단계) | `com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE`(Analytics 설치 경로, Play 스토어 설치 출처). 그 밖에 `AppMeasurement` 수신기·서비스 3개 | 2026-11-19 profile 병합 매니페스트(업로드 키 없이 같은 라이브러리 병합) |
| 손님 알림 (2026-11-18, 26번 5-1단계) | `flutter_local_notifications`로 **기기 안에서만** 예약. 서버 푸시·Firebase Messaging 없음, 수집·전송하는 데이터 없음 → **데이터 보안 양식 답변은 바뀌지 않음**. 새 권한 `POST_NOTIFICATIONS`·`RECEIVE_BOOT_COMPLETED`(플러그인이 `VIBRATE`도 넣음), 정확한 알람 권한 없음 | `test/no_tracking_sdk_test.dart`. release 병합 매니페스트 권한은 2026-11-19 업로드 키 release APK로 다시 확인(23번 6단계 표와 같음) |

`test/no_tracking_sdk_test.dart`는 허용 목록 밖의 Firebase·결제 패키지와 광고·분석 SDK·광고 ID가 들어오면 실패합니다.

## 양식 답변 (온라인 기능을 켠 빌드)

온라인 기능을 켠 빌드는 Firebase 설정과 카카오 네이티브 앱 키(`--dart-define`)가 있는 빌드입니다. 설정이 없는 빌드는 온라인 기능이 꺼지지만, Firebase·카카오·결제 라이브러리 자체는 포함됩니다.

| 질문 | 답변 |
| --- | --- |
| 수집하거나 공유하나요? | **예** |
| 전송 중 암호화 | 예(HTTPS) |
| 삭제 요청 방법 | **앱 안: 설정 > 계정 > 계정 삭제**(바로 삭제, 26번 2-1단계). 앱을 쓸 수 없으면 개인정보처리방침의 이메일로 요청(30일 안에 삭제) |
| 계정 만들기 | 예(카카오 또는 구글 로그인으로 계정 생성, 첫 실행에 필수) |
| 개인정보처리방침 URL | `docs/privacy_policy.md`를 공개 웹 페이지로 올린 주소 |

| 데이터 유형(Play 분류) | 수집 | 공유 | 필수 여부 | 목적 |
| --- | --- | --- | --- | --- |
| 개인 정보 > 사용자 ID (카카오 회원번호·구글 계정의 Firebase 계정 ID) | 예 | 아니요 | **필수**(첫 실행 로그인) | 앱 기능, 계정 관리, 사기 방지 |
| 개인 정보 > 이름 (사장님 이름, 사용자가 정함) | 예 | 아니요 | **필수** | 앱 기능(친구·순위표 표시), 계정 관리 |
| 개인 정보 > 이메일 주소 (카카오: 동의한 경우, 구글: 계정 이메일) | 예 | 아니요 | 필수(구글)·선택(카카오 동의 항목) | 계정 관리(공지·계정 안내). 화면·분석에 쓰지 않음 |
| 개인 정보 > 기타 정보 (이용자 성별·연령대, 선택 동의한 경우) | 예 | 아니요 | **선택** | 분석(이용자 분석, 26번 5단계부터 Analytics 사용자 속성 `gender`·`age_band`로도 보냄), 계정 관리(공지). 광고·마케팅 아님 |
| 금융 정보 > 구매 내역 (주문 번호, 상품, 황금 붕어빵 사용 기록) | 예 | 아니요 | 선택(구매 시) | 앱 기능, 사기 방지 |
| 앱 활동 > 기타 사용자 생성 콘텐츠·앱 내 작업 (아바타 꾸미기, 친구·방문·초대 기록) | 예 | 아니요 | 선택 | 앱 기능 |
| 앱 활동 > 앱 상호작용·게임 점수 (순위표 3개, 자체 서버) | 예 | 아니요 | 선택 | 앱 기능 |
| 앱 활동 > 앱 상호작용 (사용 통계 이벤트, Google Analytics) | 예 | 아니요 | **선택**(설정에서 끌 수 있음. 첫 실행 동의 전에는 모으지 않음) | **분석** |
| 앱 정보 및 성능 > 기타 앱 성능 데이터 (Analytics 자동 수집: 앱 버전·세션·사용 시간) | 예 | 아니요 | 선택(첫 실행 동의 뒤부터, 설정에서 끔) | 분석 |
| 기기 또는 기타 ID (Firebase 앱 인스턴스 ID·설치 ID) | 예 | 아니요 | 선택(사용 통계), 필수(서버 호출의 설치 ID) | 분석, 앱 기능 |

- Google(Firebase, Play)은 개발자를 대신해 처리하는 서비스 제공업체이므로 '공유'에 넣지 않습니다(Google 정의 기준).
- 카카오는 사용자가 직접 고른 로그인 수단이고, 개발자가 카카오에 게임 데이터를 보내지 않으므로 '공유'에 넣지 않습니다. 카카오 SDK가 로그인 요청에 함께 보내는 앱·OS 버전, 기기 모델이 '수집'에 해당하는지는 제출 시점의 Google 가이드로 다시 확인합니다.
- 순위표의 이름·점수가 다른 플레이어에게 보이는 것은 앱 기능이며, Google 정의상 '공유'(제3자 전송)가 아닙니다.
- 각 항목을 Play Console 분류에 어떻게 대응시킬지는 제출 시점의 Google 가이드를 다시 확인해 개발자가 최종 판단합니다.
- **'선택'으로 적는 이유(법률 확인 반영):** Google 정의의 '선택'은 사용자가 수집을 거부할 수 있는 경우입니다. 이 앱은 첫 실행 필수 동의 전에는 Analytics 수집 자체를 꺼 두고(자동 `first_open` 포함), 그 뒤에는 설정 '사용 통계 보내기'로 언제든 끌 수 있어 '선택'으로 적습니다. 다만 기본값이 켬이라 동의 직후 끄기 전까지는 모이므로, 제출 시점 Google 가이드가 '기본 켬'을 '필수'로 보라고 하면 '앱 정보 및 성능'·'기기 또는 기타 ID'를 **필수**로 바꿔 적는 편이 안전합니다.
- 만 14세 미만은 가입할 수 없습니다(첫 화면 '만 14세 이상입니다' 필수 체크, 개인정보처리방침 8절). Play 대상 연령(지금 만 13세 이상, S9-Q4)을 올릴지는 사용자 결정으로 남아 있습니다(23번 8단계).

## 출시 전 확인

- [x] `privacy_policy.md` 연락처
- [ ] `privacy_policy.md`를 로그인 없이 열리는 공개 URL에 올리기
- [ ] 스토어 등록정보 "광고 포함": **아니요**
- [ ] 스토어 등록정보 "인앱 구매 포함": **예**
- [ ] 콘텐츠 등급 설문: 사용자 간 상호작용(친구 방문), 디지털 구매 있음으로 답하기
- [ ] `flutter test` 통과(SDK 검사 포함)
- [ ] 출시용 AAB의 병합 매니페스트에 `AD_ID`·분석 항목이 없는지 확인(`no_tracking_sdk_test`의 release 검사가 빌드 후 자동 확인)
- [ ] 계정 삭제 요청 방법을 Play Console '데이터 삭제' 항목에 입력(앱 계정이 있는 앱은 필수). 앱 안 삭제: 설정 > 계정 > 계정 삭제(26번 2-1단계 구현). 웹 링크 칸에는 공개한 개인정보처리방침 주소
- [ ] `terms_of_service.md`(이용약관)도 공개 URL에 올리기(앱 안에는 `assets/legal/` 사본이 들어 있음)
- [x] 26번 5단계(Analytics): 성별·연령대는 Analytics 사용자 속성으로도 감 → '분석' 목적 유지. Google은 서비스 제공업체라 '공유' 아님
- [ ] Play Console 데이터 보안 양식을 아래 '26번 5단계에서 바꿀 칸'대로 고치기

## 다시 검토할 때

- 서버에 새 정보를 저장하는 기능을 추가할 때(`firebase/functions/src`)
- Firebase 다른 제품(Crashlytics, Messaging, Performance 등)을 넣을 때: 테스트가 막으므로 의도한 경우에만 허용 목록과 이 문서를 함께 고칩니다. Analytics는 26번 5단계에서 허용했습니다(이벤트를 더하면 개인정보처리방침 1-3절 표도 고침).
- 공유 문구에 사용자별 값을 더 넣을 때
- 손님 알림을 서버 푸시로 바꿀 때(지금은 기기 안 예약만이라 양식 변화 없음)

## 26번 5단계에서 바꿀 칸 (Play Console, 초보자용)

사용 통계(Google Analytics for Firebase)를 넣었으므로 앱을 올리기 전에 Play Console 양식을 아래처럼 고칩니다.

1. <https://play.google.com/console> → `오늘의 붕어빵` → 왼쪽 메뉴 맨 아래 `정책 및 프로그램`(또는 `앱 콘텐츠`) → `데이터 보안` → `시작` 또는 `수정`.
2. **데이터 수집 및 보안** 질문: '앱에서 필수 사용자 데이터 유형을 수집하거나 공유하나요?' → 그대로 **예**. '전송 중 암호화' → **예**. '사용자가 데이터 삭제를 요청할 수 있나요?' → 그대로 **예**.
3. **데이터 유형** 화면에서 아래를 새로 체크합니다(이미 체크한 것은 그대로).
   - `앱 활동` → **앱 상호작용**
   - `앱 정보 및 성능` → **기타 앱 성능 데이터**
   - `기기 또는 기타 ID` → **기기 또는 기타 ID**
4. 새로 체크한 세 항목마다 `다음`을 눌러 아래처럼 답합니다.
   - 수집됨: **예** / 공유됨: **아니요**(Google은 개발자를 대신해 처리하는 서비스 제공업체)
   - 일시적으로 처리되나요?: **아니요**
   - 필수인가요, 선택인가요?: **사용자가 이 데이터 수집을 사용 중지할 수 있음(선택)** — 설정의 '사용 통계 보내기' 스위치
   - 목적: **분석** 하나만(광고·마케팅·개인화는 체크하지 않음). '기기 또는 기타 ID'는 **앱 기능**도 체크(서버 호출의 Firebase 설치 ID)
5. `개인 정보` → `기타 정보`(성별·연령대) 항목을 열어 목적에 **분석**이 체크돼 있는지 확인합니다(2-1단계에서 이미 체크).
6. `광고 ID` 질문(앱 콘텐츠 → `광고 ID`): **'아니요, 광고 ID를 사용하지 않습니다'**. 병합 매니페스트에서 `AD_ID` 권한을 뺐으므로 이 답과 맞습니다.
7. 마지막 `미리보기` 화면에서 '데이터 공유: 없음', '수집: 앱 활동, 앱 정보 및 성능, 기기 또는 기타 ID, 개인 정보, 금융 정보'로 보이면 `저장` → `검토를 위해 변경사항 보내기`.
8. 개인정보처리방침 공개 주소의 문서도 2026-11-19 판(1-3절 사용 통계 추가, 법률 확인 반영: 1-0절 처리 근거·7-1절 국외 이전·8절 만 14세 미만 가입 불가)으로 바꿔 올립니다. 이용약관도 2026-11-19 판(2-1절 이용 자격)으로 바꿔 올립니다.
