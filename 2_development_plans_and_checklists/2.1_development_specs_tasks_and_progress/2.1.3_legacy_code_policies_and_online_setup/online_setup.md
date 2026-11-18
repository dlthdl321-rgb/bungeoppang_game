# 온라인 운영 설정 따라 하기 (Firebase·카카오·Play 결제)

작성 2026-11-17 (23번 7단계). 개발이 처음이어도 위에서부터 차례로 따라 하면 되도록 썼다. 업로드 키와 release 빌드는 [release_signing.md](release_signing.md)를 먼저 끝낸 상태를 전제로 한다.

이 문서는 [15단계 기록](stage15_release_online.md)·[16단계 기록](stage16_kakao_login_ranking.md)의 "직접 하셔야 하는 설정"을 대신한다. 두 문서와 다른 곳(서비스 계정 이름, 키 넣는 방법, App Check)은 이 문서가 맞다.

## 0. 먼저 알아 둘 것

### 0-1. 전체 순서

| 순서 | 할 일 | 어디서 | 걸리는 시간(대략) |
| --- | --- | --- | --- |
| 1 | Firebase 프로젝트 만들기, 값 4개 받기 | Firebase 콘솔 | 30분 |
| 2 | 카카오 앱 만들기, 키 2개 받기 | 카카오 개발자 콘솔 | 20분 |
| 3 | 키 파일 2개 만들기 | 내 PC(메모장·PowerShell) | 10분 |
| 4 | 서버 배포 | 내 PC(PowerShell) | 20분 |
| 5 | 서버 권한 2가지 | Google Cloud 콘솔 | 10분 |
| 6 | 휴대폰(debug)으로 로그인·환영 황금 확인 | 내 PC + 휴대폰 | 30분 |
| 7 | Play Console에 앱 올리기(내부 테스트) | Play Console | 1시간 + 처리 대기 |
| 8 | 앱 서명 키 지문을 Firebase·카카오에 등록, Play Integrity 연결 | 세 콘솔 | 20분 |
| 9 | 인앱 상품 5개 만들기, 구매 확인 권한 주기 | Play Console | 30분 + 권한 반영 대기(최대 하루) |
| 10 | 라이선스 테스터로 테스트 구매·복구 확인 | 휴대폰 | 30분 |
| 16 | (26번 2-1단계) 구글 로그인 켜기, SHA-1 등록, 웹 클라이언트 ID 넣기, 카카오 이메일 동의 항목, 서버 다시 배포 | Firebase·Google Cloud·카카오 콘솔 + 내 PC | 40분 |
| 17 | (26번 5단계) Google Analytics 켜기, 데이터 보존 14개월, DebugView로 이벤트 확인, 리텐션·이탈 보는 법, (선택) BigQuery 내보내기 | Firebase 콘솔·Google Analytics | 30분 |

**26번 2-1단계부터는 앱을 처음 켤 때 로그인이 꼭 필요하다.** 1~6장을 이미 끝냈다면 16장만 하면 된다. 아직이면 1~6장을 하면서 16장을 함께 한다(16장 순서대로).

**완료 기준(23번 7단계):** 10번에서 운영 Firebase로 테스트 구매 1건이 서버 확인·지급·복구까지 통과하면 끝이다. 결과는 13장 표에 적어서 알려 준다.

### 0-2. 돈이 드는 것

- Firebase 서버 함수(Cloud Functions)는 **Blaze 요금제(종량제)** 에서만 배포된다. 결제 카드 등록이 필요하다. 테스트 규모(테스터 20명 안팎)에서는 무료 사용량 안에 거의 들어가지만, 1-3에서 **예산 알림**을 꼭 건다.
- Play Console 개발자 계정 등록비(1회 25달러)는 이미 냈다고 가정한다.
- 라이선스 테스터의 테스트 구매는 **실제로 돈이 나가지 않는다**.

### 0-3. 이 PC에 이미 있는 도구

| 도구 | 위치 | 없으면 |
| --- | --- | --- |
| Flutter | `D:\DevMoved\flutter-sdk\bin\flutter.bat` | — |
| Node 22, Firebase CLI | `1_app_development\firebase\local_tools\` | PowerShell에서 `cd B:\1_app_development\firebase` → `powershell -ExecutionPolicy Bypass -File .\setup_local_tools.ps1` (10분 정도, 끝에 경로 3줄이 나오면 성공) |
| Firebase CLI 실행용 바로가기 | `1_app_development\firebase\firebase_local.cmd` | 저장소에 들어 있음 |
| adb | `C:\Android\sdk\platform-tools\adb.exe` | — |

**PowerShell 여는 법:** `Windows 키` → `powershell` 입력 → **Windows PowerShell** 클릭. 아래 명령을 한 줄씩 복사(Ctrl+C)해서 창에 붙여 넣고(마우스 오른쪽 클릭) `Enter`.

**B: 드라이브:** 저장소 경로에 한글이 있어 도구들이 실패하므로, 새 PowerShell 창을 열 때마다 먼저 아래 한 줄을 실행한다. "이미 연결됨"류 오류가 나오면 무시한다.

```powershell
subst B: "D:\Users\이소이\Desktop\Git\붕어빵 게임"
```

### 0-4. 비밀인 것과 아닌 것

| 값 | 비밀? | 넣는 곳 |
| --- | --- | --- |
| Firebase API 키·앱 ID·발신자 ID·프로젝트 ID | 아님(앱 안에 들어감). 그래도 저장소에는 안 올림 | `1_app_development\dart_defines\online.json` |
| 카카오 네이티브 앱 키 | 아님(앱 안에 들어감). 저장소에는 안 올림 | 같은 `online.json` |
| App Check 디버그 토큰 | **비밀**(이 토큰이 있으면 누구나 App Check를 통과) | 같은 `online.json` |
| 카카오 앱 ID(숫자) | 아님 | `1_app_development\firebase\functions\.env` |
| 판매 보상 추첨 키 | **비밀** | 같은 `.env`(스크립트가 자동으로 만듦) |
| SHA-1·SHA-256 지문, 카카오 키 해시 | 아님 | 각 콘솔 |

`online.json`과 `functions\.env`는 `.gitignore`로 커밋에서 빠지게 해 두었다(`git status`에 안 보이면 정상). 메신저·공개 클라우드에 올리지 않는다. 비밀번호 관리자에 사본을 두면 PC를 바꿔도 된다.

## 1. Firebase 프로젝트 만들기

**1-1. 프로젝트 만들기**
1. 브라우저에서 <https://console.firebase.google.com> 을 열고 Google 계정으로 로그인한다(Play Console과 같은 계정 권장).
2. `프로젝트 만들기`(또는 `Firebase 프로젝트 시작하기`) 클릭.
3. 이름: `todaybungeoppang` 처럼 영문으로 입력. 아래에 회색으로 **프로젝트 ID**(예: `todaybungeoppang-1a2b3`)가 보인다. 적어 둔다.
4. Google 애널리틱스는 이 화면에서 켜도 되고 꺼도 된다. **26번 5단계부터 사용 통계(Google Analytics)를 쓰므로**, 여기서 껐다면 나중에 17장에서 켠다. 켠다면 '애널리틱스 위치'는 `대한민국`, 데이터 공유 체크는 모두 해제한다.
5. `프로젝트 만들기` → 잠시 뒤 `계속`.

**1-2. Blaze 요금제로 바꾸기**
1. 왼쪽 아래 `Spark` 요금제 표시(또는 `업그레이드`) 클릭 → `Blaze` 선택.
2. 안내대로 결제 계정(카드)을 만들거나 고른다.

**1-3. 예산 알림 걸기(꼭)**
1. <https://console.cloud.google.com/billing> → 방금 쓴 결제 계정 → 왼쪽 `예산 및 알림` → `예산 만들기`.
2. 이름 `붕어빵 서버`, 금액 예: `10000`원(월), 알림 50%·90%·100% 그대로 → `완료`.
3. 예산은 알림만 보낸다(자동으로 멈추지 않는다). 메일이 오면 알려 준다.

**1-4. Android 앱 등록하고 값 4개 받기**
1. Firebase 콘솔 프로젝트 첫 화면에서 Android 아이콘(`앱 추가` → Android) 클릭.
2. **Android 패키지 이름**: `com.todaybungeoppang.app` (정확히).
3. 앱 닉네임: `오늘의 붕어빵`. 디버그 서명 인증서 SHA-1: 비워도 된다(8장에서 넣는다).
4. `앱 등록` → **`google-services.json 다운로드`** 를 눌러 `다운로드` 폴더에 받는다. 이 파일은 **프로젝트 폴더에 넣지 않는다**(이 게임은 이 파일 대신 3장 키 파일을 쓴다. Analytics가 필요한 앱 ID는 빌드 때 키 파일 값으로 자동으로 들어간다, 26번 5단계).
5. 나머지 단계(SDK 추가 등)는 `다음` → `콘솔로 이동`으로 넘긴다.
6. 탐색기에서 `다운로드\google-services.json`을 오른쪽 클릭 → `연결 프로그램` → `메모장`. 아래 4개 값을 찾아 메모해 둔다(3장에서 씀).

| 메모할 이름 | google-services.json에서 찾을 줄 | 예시 모양 |
| --- | --- | --- |
| FIREBASE_PROJECT_ID | `"project_id": "…"` | `todaybungeoppang-1a2b3` |
| FIREBASE_SENDER_ID | `"project_number": "…"` | 숫자 12자리쯤 |
| FIREBASE_APP_ID | `"mobilesdk_app_id": "…"` | `1:123456789012:android:abcdef…` |
| FIREBASE_API_KEY | `"current_key": "…"` | `AIza`로 시작 |

7. 다 적었으면 `google-services.json`은 지워도 된다(필요하면 Firebase 콘솔 → 톱니바퀴 `프로젝트 설정` → `내 앱`에서 다시 받을 수 있다).

**1-5. Authentication 켜기**
1. 왼쪽 메뉴 `빌드`(또는 `제품 카테고리`) → `Authentication` → `시작하기`.
2. 카카오 로그인만 쓸 때는 로그인 제공업체를 켜지 않아도 된다(카카오 로그인은 서버가 만든 토큰으로 들어간다). **구글 로그인(26번 2-1단계)은 16-1에서 `Google`을 켠다.**

**1-6. Firestore 데이터베이스 만들기**
1. 왼쪽 메뉴 `Firestore Database` → `데이터베이스 만들기`.
2. 위치: **`asia-northeast3 (Seoul)`** — 한 번 정하면 못 바꾼다.
3. 모드: `프로덕션 모드에서 시작` → `만들기`. (규칙은 4장 배포 때 저장소의 `firestore.rules`로 덮어쓴다. 앱은 Firestore를 직접 못 읽고 서버만 쓴다.)

## 2. 카카오 개발자 콘솔

카카오 콘솔은 화면 개편이 잦다. 메뉴 이름이 조금 다르면 같은 뜻의 메뉴를 찾는다.

**2-1. 앱 만들기**
1. <https://developers.kakao.com> → 오른쪽 위 `로그인` → `내 애플리케이션` → `애플리케이션 추가하기`.
2. 앱 이름 `오늘의 붕어빵`, 회사명(사업자명)은 개인이면 본인 이름, 카테고리 `게임` → 저장.

**2-2. 키 두 개 적기**
1. 만든 앱을 누르면 `앱 키`(또는 `앱 설정` → `앱 키`/`플랫폼 키`) 화면에 **네이티브 앱 키**가 있다 → `KAKAO_NATIVE_APP_KEY`로 메모(32글자 영문·숫자).
2. `앱 설정` → `요약 정보`(또는 `일반`)에 **앱 ID**(숫자)가 있다 → `KAKAO_APP_ID`로 메모. 네이티브 앱 키와 다르다.

**2-3. Android 플랫폼 등록**
1. `앱 설정` → `플랫폼` → `Android 플랫폼 등록`(새 화면에서는 `플랫폼 키` → 네이티브 앱 키 → `Android` 항목).
2. 패키지명: `com.todaybungeoppang.app`.
3. 키 해시: 아래 두 줄을 넣는다(한 줄에 하나, `+`로 칸 추가). 8장에서 한 줄을 더 넣는다.

| 키 | SHA-1 지문 | 카카오 키 해시 |
| --- | --- | --- |
| 이 PC의 debug 키(`flutter run`용) | `04:1A:06:46:C2:D5:37:58:6C:A1:C5:6E:EA:97:21:33:62:08:82:DB` | `BBoGRsLVN1hsocVu6pchM2IIgts=` |
| 업로드 키(`C:\keys\bungeoppang-upload.jks`, 직접 설치한 release APK용) | `17:17:AB:A9:DB:2D:31:40:06:0F:2D:4F:DE:48:89:16:3F:25:4C:42` | `FxerqdstMUAGDy1P3kiJFj8lTEI=` |
| Play 앱 서명 키(Play에서 받은 앱용) | 8장에서 확인 | 8장에서 계산 |

   위 값은 2026-11-17 이 PC의 debug APK와 업로드 키로 서명한 release APK에서 `apksigner`로 읽은 것이다. 다른 PC에서 `flutter run`을 하면 그 PC의 debug 키 해시를 따로 넣어야 한다.
4. 저장.

**2-4. 카카오 로그인 켜기**
1. `제품 설정` → `카카오 로그인` → `활성화 설정`을 `ON`.
2. `동의항목` → `닉네임` → `설정` → **선택 동의**, 동의 목적 `게임 안에서 이름으로 표시` → 저장. 이메일(`카카오계정(이메일)`, `account_email`)은 16-4에서 켠다. 이 둘 말고 다른 항목은 켜지 않는다.
3. Redirect URI는 Android 앱에서는 넣지 않아도 된다.

## 3. 키 파일 두 개 만들기

**3-1. 앱 키 파일 `online.json`**
1. 탐색기에서 `D:\Users\이소이\Desktop\Git\붕어빵 게임\1_app_development\dart_defines` 폴더를 연다.
2. `online.example.json`을 복사(Ctrl+C) → 같은 폴더에 붙여 넣기(Ctrl+V) → 생긴 `online.example - 복사본.json`을 오른쪽 클릭 → `이름 바꾸기` → `online.json`.
3. `online.json`을 오른쪽 클릭 → `연결 프로그램` → `메모장`. 따옴표 `""` 사이에 1-4·2-2에서 메모한 값을 넣는다. `APP_CHECK_DEBUG_TOKEN`은 5-3에서 채우니 지금은 비워 둔다.

```json
{
  "FIREBASE_API_KEY": "AIza로 시작하는 값",
  "FIREBASE_APP_ID": "1:숫자:android:영숫자",
  "FIREBASE_SENDER_ID": "숫자",
  "FIREBASE_PROJECT_ID": "프로젝트 ID",
  "KAKAO_NATIVE_APP_KEY": "32글자 네이티브 앱 키",
  "APP_CHECK_DEBUG_TOKEN": "",
  "GOOGLE_SERVER_CLIENT_ID": "16-2에서 넣음(…apps.googleusercontent.com)"
}
```

4. `파일` → `저장`. 따옴표·쉼표를 지우지 않게 조심한다. 마지막 줄 뒤에는 쉼표가 없다.
5. 확인: PowerShell에서 아래를 실행해 `True`가 나오면 형식이 맞다. 빨간 오류가 나오면 따옴표·쉼표를 다시 본다.
   ```powershell
   (Get-Content "B:\1_app_development\dart_defines\online.json" -Raw | ConvertFrom-Json) -ne $null
   ```

**3-2. 서버 설정 파일 `functions\.env`**

카카오 앱 ID만 물어보고, 비밀 추첨 키는 자동으로 만든다.

```powershell
cd B:\1_app_development\firebase
powershell -ExecutionPolicy Bypass -File .\make_server_env.ps1
```

`카카오 앱 ID(숫자)를 붙여 넣고 Enter`가 나오면 2-2의 앱 ID를 붙여 넣고 `Enter`. 초록색 `완료:`가 나오면 성공이다. 만들어지는 값:

| 이름 | 값 | 뜻 |
| --- | --- | --- |
| `KAKAO_APP_ID` | 입력한 숫자 | 다른 카카오 앱의 로그인 토큰을 거절하는 기준 |
| `WORKSHOP_ONLINE_ENABLED` | `true` | **운영값.** 서버 타당성 검증·환영 황금·스킬 구매·미션/판매 황금을 켠다(DEC-027 온라인 가출시). `true`가 아니면 스킬 구매와 황금 보상이 모두 막힌다 |
| `WORKSHOP_SALE_DRAW_KEY_BASE64` | 무작위 32바이트 | 판매 황금 추첨용 비밀 키. **한 번 정하면 바꾸지 않는다** |
| `WORKSHOP_AD_SSV_ENABLED` | `false` | 광고는 가출시 제외(DEC-028) |
| `WORKSHOP_PROTECTION_ENABLED` | `false` | 서명 스냅샷 검증은 쓰지 않음(타당성 검증 사용, 23번 2단계) |
| `APP_CHECK_ENFORCED` | `true` | App Check 없는 호출 거절(5장) |

이미 `.env`가 있으면 덮어쓰지 않고 멈춘다. 값을 고치려면 `B:\1_app_development\firebase\functions\.env`를 메모장으로 열어 직접 고친다.

## 4. 서버 배포

같은 PowerShell 창에서(`cd B:\1_app_development\firebase` 상태) 한 줄씩:

1. **로그인:** `.\firebase_local.cmd login` → 브라우저가 열리면 1장과 같은 Google 계정으로 `허용`. 창에 `Success! Logged in as …`가 나오면 성공. ("Gemini…"나 "오류 보고 허용?" 질문이 나오면 `n` Enter.)
2. **프로젝트 고르기:** `.\firebase_local.cmd use --add` → 화살표 키로 1-1의 프로젝트 ID 선택 → `Enter` → 별칭(alias)을 물으면 `default` 입력 → `Enter`. 같은 폴더에 `.firebaserc`가 생긴다(커밋하지 않는다).
3. **배포:** `.\firebase_local.cmd deploy --only "functions,firestore"`
   - 처음에는 필요한 Google Cloud API를 켜느라 오래 걸린다(10~20분). "API를 켤까요?"류 질문은 `Y`.
   - `How many days do you want to keep container images before they're deleted?`가 나오면 `1` Enter.
   - 마지막에 `✔ Deploy complete!`가 나오면 성공.
4. **확인:** Firebase 콘솔 → `Functions`에 `authKakao`, `walletRedeem`, `workshopProgressClaim` 등이 지역 `asia-northeast3`로 보이면 된다. Firestore → `규칙` 탭에 `allow read, write: if false`가 보이면 규칙도 올라간 것이다.

**나중에 서버 코드나 `.env`를 바꾸면** 3번 명령만 다시 실행한다(`.env`는 배포할 때 읽힌다).

## 5. 서버 권한 두 가지와 App Check 디버그 토큰

**5-1. 서버가 쓰는 서비스 계정 이메일 찾기**

서버 함수(2세대)는 보통 **Compute Engine 기본 서비스 계정**(`프로젝트번호-compute@developer.gserviceaccount.com`)으로 실행된다. 확실히 하려면:
1. <https://console.cloud.google.com/run> 을 연다(위쪽 프로젝트 선택이 1-1 프로젝트인지 확인).
2. 서비스 목록에서 `walletredeem` 클릭 → `보안`(또는 `개정 버전` → 오른쪽 상세) 탭 → **서비스 계정** 이메일을 메모한다. 아래에서 "서버 계정"이라고 부른다. (15단계 문서의 `@appspot.gserviceaccount.com`은 1세대 함수 기준이라 이 프로젝트에는 맞지 않는다.)

**5-2. 카카오 로그인용 권한(토큰 만들기)**
1. <https://console.cloud.google.com/iam-admin/iam> → 목록에서 서버 계정 줄의 연필(`주 구성원 수정`) 클릭.
2. `다른 역할 추가` → `서비스 계정 토큰 생성자`(Service Account Token Creator) 선택 → `저장`.
3. <https://console.cloud.google.com/apis/library/iamcredentials.googleapis.com> → `사용`(이미 `관리`로 보이면 켜진 것).
4. 확인은 6장 로그인에서 한다. 이 권한이 없으면 로그인 때 서버 로그에 `iam.serviceAccounts.signBlob` 오류가 남는다.

**5-3. App Check 켜기(debug용)**

서버는 App Check 토큰이 없는 호출을 모두 거절한다(`APP_CHECK_ENFORCED=true`). 휴대폰에서 `flutter run`으로 실행하는 debug 빌드는 **디버그 토큰**으로 통과한다.
1. Firebase 콘솔 → 왼쪽 `App Check`(안 보이면 `빌드` 아래) → `시작하기`.
2. `앱` 탭 → `오늘의 붕어빵`(Android) 줄 오른쪽 `⋮` → `디버그 토큰 관리` → `디버그 토큰 추가` → `생성`을 눌러 만들어진 값을 복사 → 이름 `내 PC debug` → `저장`.
3. 3-1의 `online.json`에서 `"APP_CHECK_DEBUG_TOKEN": ""`의 따옴표 사이에 붙여 넣고 저장.
4. Play Integrity 등록은 앱 서명 키 지문이 필요해서 8장에서 한다.
5. `API` 탭의 Firestore·Authentication `시행(Enforce)` 버튼은 **누르지 않는다**(앱이 Firestore를 직접 쓰지 않고, 함수 쪽 강제는 서버 코드가 한다).

## 6. 휴대폰(debug)으로 로그인 확인

**왜:** Play에 올리기 전에 운영 서버와 카카오 설정이 맞는지 먼저 본다.

1. 휴대폰을 USB로 연결하고 USB 디버깅을 허용한다([release_signing.md](release_signing.md) 4장 1번).
2. 같은 패키지 이름의 release 앱이 깔려 있으면 서명이 달라 debug가 안 깔린다. 먼저 지운다(**그 휴대폰의 게임 진행이 지워진다**): `C:\Android\sdk\platform-tools\adb.exe uninstall com.todaybungeoppang.app`
3. PowerShell에서 한 줄씩:
   ```powershell
   cd B:\1_app_development
   $env:GRADLE_USER_HOME='D:\DevMoved\GradleCache'; $env:PUB_CACHE='C:\PubCacheBungeoppang'
   D:\DevMoved\flutter-sdk\bin\flutter.bat pub get
   D:\DevMoved\flutter-sdk\bin\flutter.bat run --dart-define-from-file=dart_defines/online.json
   ```
   (처음엔 10분 넘게 걸린다. 휴대폰에 게임이 뜨면 된다. 끝낼 때는 창에서 `q`.)
4. 게임에서 메뉴 → 로그인(카카오) → 카카오톡 또는 카카오계정으로 로그인 → 닉네임 동의.
5. **확인:** 상점에 황금붕어빵력 **10**(환영 황금)이 보이면 로그인·서버 검증·지급이 모두 된 것이다. Firebase 콘솔 → Firestore → `users` 아래 `kakao:숫자` 문서에 `gold: 10`이 보인다.
6. 끝나면 `Remove-Item Env:PUB_CACHE; D:\DevMoved\flutter-sdk\bin\flutter.bat pub get`으로 테스트 환경을 되돌린다.

안 되면 14장 문제 해결 표를 본다.

## 7. Play Console에 앱 올리기(내부 테스트)

인앱 상품은 **결제 권한이 들어 있는 AAB를 한 번 올린 뒤에야** 만들 수 있다. 그래서 먼저 내부 테스트 트랙에 올린다. (가출시 본 배포는 비공개 테스트, DEC-030. 이 업로드는 결제 확인용이다.)

**7-1. 온라인 AAB 만들기**
```powershell
cd B:\1_app_development
$env:GRADLE_USER_HOME='D:\DevMoved\GradleCache'; $env:PUB_CACHE='C:\PubCacheBungeoppang'
D:\DevMoved\flutter-sdk\bin\flutter.bat pub get
D:\DevMoved\flutter-sdk\bin\flutter.bat build appbundle --release --dart-define-from-file=dart_defines/online.json
Remove-Item Env:PUB_CACHE; D:\DevMoved\flutter-sdk\bin\flutter.bat pub get
```
`√ Built build\app\outputs\bundle\release\app-release.aab`가 나오면 성공. (release 빌드는 `APP_CHECK_DEBUG_TOKEN`을 쓰지 않는다. Play Integrity로 통과한다.)

**7-2. 앱 만들기와 결제 프로필**
1. <https://play.google.com/console> → `앱 만들기` → 앱 이름 `오늘의 붕어빵`, 기본 언어 `한국어`, `게임`, `무료`, 선언 체크 → `앱 만들기`. (이미 만들었으면 넘어간다.)
2. 인앱 상품을 팔려면 **결제 프로필(판매자 계정)** 이 필요하다. 왼쪽 `수익 창출` → `상품` → `인앱 상품`에 "결제 프로필을 설정하세요"가 보이면 안내대로 만든다(사업자 정보·은행 계좌).

**7-3. 내부 테스트에 올리기**
1. 왼쪽 `테스트 및 출시` → `테스트` → `내부 테스트` → `테스터` 탭 → `이메일 목록 만들기` → 이름 `붕어빵 내부`, 본인과 테스트할 Gmail 주소 입력 → 저장 → 목록 체크.
2. `버전` 탭 → `새 버전 만들기` → (처음이면 `Play 앱 서명` 안내에 `계속`/`동의`) → `app-release.aab` 끌어다 놓기 → 출시 이름은 자동(`1 (0.1.0)`), 출시 노트 `<ko-KR>결제 확인용 내부 테스트</ko-KR>` → `다음` → `저장 후 출시`(또는 `내부 테스트 트랙으로 출시 시작`).
3. Play Console이 "앱 콘텐츠를 먼저 입력하세요"처럼 막으면, 그 목록을 캡처해서 알려 준다(8단계 정책 문서에서 채운다).
4. 올라간 versionCode `1`은 다시 못 쓴다. 다음 업로드부터는 [release_signing.md](release_signing.md) 6장대로 `pubspec.yaml`의 `+1`을 `+2`로 올린다.

## 8. 앱 서명 키 지문 등록과 Play Integrity 연결

Play에서 받은 앱은 Google의 **앱 서명 키**로 다시 서명되므로, 그 지문을 따로 등록해야 한다.

**8-1. 지문 확인:** Play Console → `테스트 및 출시` → `설정` → `앱 무결성`(App integrity) → `앱 서명` 탭. **앱 서명 키 인증서**의 `SHA-1`과 `SHA-256`을 복사해 둔다. (같은 화면의 업로드 키 인증서 SHA-256이 `6A:17:CF:A1:…`이면 업로드 키가 맞다.)

**8-2. 카카오 키 해시 추가:** SHA-1을 키 해시로 바꾼다.
```powershell
cd B:\1_app_development\tools
powershell -ExecutionPolicy Bypass -File .\kakao_key_hash.ps1 -Sha1 "여기에 앱 서명 키 SHA-1 붙여 넣기"
```
초록색 `카카오 키 해시: …=` 값을 2-3의 키 해시 칸에 한 줄 더 넣고 저장.

**8-3. Firebase에 지문 등록:** Firebase 콘솔 → 톱니바퀴 `프로젝트 설정` → `일반` → `내 앱`의 Android 앱 → `디지털 지문 추가` → 앱 서명 키 **SHA-256** 붙여 넣기 → 저장. 같은 방법으로 업로드 키 SHA-256(`6A:17:CF:A1:1C:B5:EB:2E:97:C1:8F:E7:DB:3C:12:8B:24:BB:B3:91:ED:23:1D:78:8B:FB:D5:30:B6:BA:54:EA`)도 추가한다.

**8-4. Play Integrity를 Firebase 프로젝트에 연결:**
1. Play Console → `앱 무결성` → `Play Integrity API` → `Cloud 프로젝트 연결`(Link a Cloud project) → 1-1 프로젝트 선택 → 연결.
2. Firebase 콘솔 → `App Check` → `앱` 탭 → Android 앱 → `Play Integrity` → 이용약관 동의, SHA-256 확인(8-3에서 넣은 값이 보임) → `저장`.
3. 확인: `App Check` → `API` 탭(또는 `측정항목`)은 하루쯤 지나야 숫자가 쌓인다. 바로 확인은 10장 테스트로 한다.

## 9. 인앱 상품 5개와 구매 확인 권한

**9-1. 상품 만들기:** Play Console → `수익 창출` → `상품` → `인앱 상품`(새 화면에서는 `일회성 제품`) → `상품 만들기`. 아래 5개를 하나씩 만든다. **제품 ID는 한 글자도 틀리면 안 되고, 한 번 만들면 못 바꾼다.** 가격은 임시(DEC-029)이며 나중에 바꿀 수 있다.

| 제품 ID | 이름 | 설명 | 가격 |
| --- | --- | --- | --- |
| `gold_60` | 황금붕어빵력 60 | 황금붕어빵력 60개 | ₩1,200 |
| `gold_330` | 황금붕어빵력 330 | 황금붕어빵력 330개 | ₩5,900 |
| `gold_700` | 황금붕어빵력 700 | 황금붕어빵력 700개 | ₩11,000 |
| `gold_2200` | 황금붕어빵력 2200 | 황금붕어빵력 2,200개 | ₩33,000 |
| `gold_3800` | 황금붕어빵력 3800 | 황금붕어빵력 3,800개 | ₩55,000 |

- `구매 옵션`을 물으면 기본값(구매, 한 번에 여러 개 구매 안 함) 그대로 두고 가격만 넣는다. `가격 설정` → 한국 원화 입력 → 다른 국가는 `환율로 자동 설정` 그대로.
- 저장 뒤 상태를 **`활성`** 으로 바꾼다(`활성화` 버튼). 비활성 상품은 앱에서 '구매할 수 없음'으로 보인다.
- 이 ID 목록은 앱(`lib/premium_config.dart`)과 서버(`firebase/functions/src/catalog.json`)에 이미 같은 값으로 들어 있다. 테스트(`test/premium_catalog_test.dart`)가 둘이 다르면 실패한다.

**9-2. 서버에 구매 확인 권한 주기:**
1. <https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com> (1-1 프로젝트 선택 상태) → **Google Play Android Developer API** `사용`.
2. Play Console **맨 처음 화면(앱 목록)** → 왼쪽 `사용자 및 권한` → `새 사용자 초대` → 이메일에 5-1의 **서버 계정** 이메일.
3. `앱 권한` 탭 → `앱 추가` → `오늘의 붕어빵` → 아래 두 개만 체크: **재무 데이터 보기**(View financial data…), **주문 및 구독 관리**(Manage orders and subscriptions) → `적용` → `사용자 초대` → `초대 보내기`.
4. 권한이 서버에 반영되기까지 **몇 시간~하루** 걸릴 수 있다. 10장 테스트 구매에서 "권한 없음"이 나오면 하루 뒤 다시 하거나, 9-1의 상품 하나를 열어 설명을 한 글자 고치고 저장하면 빨리 반영되는 경우가 많다.

## 10. 라이선스 테스터로 테스트 구매

**10-1. 라이선스 테스터 등록:** Play Console 맨 처음 화면 → `설정` → `라이선스 테스트` → 테스트할 Gmail 추가(7-3 목록과 같은 주소) → `라이선스 응답`은 `RESPOND_NORMALLY` → `변경사항 저장`.

**10-2. Play에서 설치:**
1. Play Console → `내부 테스트` → `테스터` 탭 아래 **테스터 참여 링크** `링크 복사`.
2. 휴대폰(테스터 Gmail로 Play 스토어에 로그인된 상태)에서 그 링크를 연다 → `테스터 되기` → `Google Play에서 다운로드` → 설치. (처음에는 몇 분~몇 시간 뒤에 보일 수 있다.)
3. 이 휴대폰에 6장의 debug 앱이 있으면 먼저 삭제한다(서명이 달라 설치가 안 됨).

**10-3. 확인 순서:** 11장 표를 위에서부터 따라 하고 결과를 적는다. 결제 창에서 결제 수단은 **`테스트 카드, 항상 승인됨`** 을 고른다(실제 청구 없음). 결제 창 위쪽에 "테스트 주문입니다" 비슷한 문구가 보이면 정상이다.

## 11. 실기기 확인 체크리스트 (운영 Firebase)

랭킹·친구·초대는 가출시에서 숨겼으므로(DEC-029) 확인하지 않는다. 각 줄의 "확인 방법"대로 보고, 결과 칸에 ○/✕와 메모를 적어서 알려 준다.

| # | 할 일 | 기대 결과 | 확인 방법 | 결과 |
| --- | --- | --- | --- | --- |
| 0 | (26번 2-1단계) 앱 데이터를 지우거나 새로 설치 → 실행 | 게임 대신 '따끈한 붕어빵 가게를 열어 볼까요?' 화면. 필수 동의 두 개를 체크해야 로그인 버튼이 켜짐 | 화면 | |
| 0-1 | 카카오로 시작하기 → 이름 → 여자/남자 사장님 → 선택 정보 '건너뛰기' | 첫 영업 안내(1/7)가 나옴. 메뉴 창 위에 '○○ 사장님의 가게' | 화면 + Firestore `accountProfiles/kakao:…`에 `name`·`email`(이메일 동의 시)·`requiredConsent` | |
| 0-2 | 다른 휴대폰(또는 앱 데이터 지운 뒤)에서 Google로 시작하기 → 이름 → 캐릭터 → 성별·연령대 입력, 선택 동의 체크 → 저장 | 첫 영업 안내가 나옴 | Firestore `accountProfiles/<영숫자 uid>`에 `email`·`gender`·`ageBand` | |
| 0-3 | 비행기 모드로 새 설치 첫 실행 → 로그인 버튼 | '인터넷 연결이 필요해요' 화면. 비행기 모드 끄고 '다시 시도' → 로그인 화면 | 화면 | |
| 0-4 | 로그인한 뒤 비행기 모드로 앱 다시 실행 | 로그인 화면 없이 바로 게임 | 화면 | |
| 1 | Play에서 받은 앱 실행 → (0-1에서 로그인함) 메뉴 '로그인·보상 확인' | 로그인 상태 유지, 이름 표시 | 화면 | |
| 2 | 상점 열기 | 황금붕어빵력 10(환영 황금, 계정당 1번) | 화면 + Firestore `users/kakao:…`의 `gold` | |
| 3 | 상점 충전 탭 | 상품 5개에 원화 가격이 보임('불러오는 중'/'구매할 수 없음'이 아님) | 화면 | |
| 4 | `gold_60` 테스트 구매(테스트 카드) | 결제 완료 뒤 황금 10 → 70 | 화면 + Firestore `gold: 70`, `purchases` 컬렉션에 1건 | |
| 5 | 같은 상품 한 번 더 구매 | 다시 살 수 있음(서버가 소모 처리함), 70 → 130 | 화면 | |
| 6 | 스킬 상점에서 황금이 드는 스킬 구매 | 황금이 가격만큼 줄고 스킬 보유 | 화면 + Firestore `users/kakao:…/compositeSkills` | |
| 7 | **복구 ①**: 구매 버튼 → 결제 완료 직후 홈 버튼 → 최근 앱에서 게임을 위로 밀어 강제 종료 → 다시 실행 | 다시 켠 뒤 1분 안에 황금이 늘어 있음(중복 지급 없음) | 화면 + Firestore `gold` | |
| 8 | **복구 ②**: 앱 삭제 → Play에서 다시 설치 → 같은 카카오 계정 로그인 | 황금 잔액이 서버 값 그대로(구워 둔 붕어빵 등 로컬 진행은 처음부터 — 정상) | 화면 | |
| 9 | 설정 → 계정 → 로그아웃 → **다른** 카카오 계정 로그인 | (26번 2-1단계) '이 기기의 가게는 다른 카카오 계정에 연결돼 있어요…'가 나오고 로그인되지 않음. 처음 계정으로 다시 로그인하면 바로 게임 | 화면 | |
| 9-1 | 설정 → 계정 → 계정 삭제 → '위 내용을 확인했어요' 체크 → 삭제하기 | 앱이 처음 화면(로그인)으로 돌아감 | 화면 + Firestore에서 그 uid의 `users`·`accountProfiles`·`inviteProfiles`가 사라짐(`purchases`만 남음), Authentication `사용자` 목록에서도 사라짐 | |
| 10 | Play Console → `주문 관리` | 테스트 주문이 보이고 환불·청구 없음 | Play Console | |

Firestore 보는 법: Firebase 콘솔 → `Firestore Database` → `데이터` 탭 → `users` → `kakao:숫자`.

## 12. 지금까지 넣은 값 정리표

| 값 | 어디서 나옴 | 어디에 넣음 |
| --- | --- | --- |
| Firebase 4개 값 | 1-4 `google-services.json` | `dart_defines/online.json` |
| 카카오 네이티브 앱 키 | 2-2 | `dart_defines/online.json` |
| 카카오 앱 ID | 2-2 | `firebase/functions/.env` (3-2 스크립트) |
| App Check 디버그 토큰 | 5-3 | `dart_defines/online.json`, Firebase App Check |
| debug·업로드 키 해시 | 2-3 표 | 카카오 Android 플랫폼 |
| 앱 서명 키 SHA-1 → 키 해시 | 8-1, 8-2 | 카카오 Android 플랫폼 |
| 앱 서명 키·업로드 키 SHA-256 | 8-1, 업로드 키는 release_signing.md 3장 | Firebase 프로젝트 설정, App Check Play Integrity |
| 서버 계정 이메일 | 5-1 | IAM(토큰 생성자), Play Console 사용자(재무·주문 권한) |
| 상품 ID 5개 | 9-1 표 | Play Console 인앱 상품 |
| debug·업로드·앱 서명 키 **SHA-1** | 16-1 표 | Firebase 프로젝트 설정 → 내 앱(구글 로그인용) |
| 구글 웹 클라이언트 ID | 16-2 | `dart_defines/online.json` `GOOGLE_SERVER_CLIENT_ID` |

## 13. 결과 알려 주기

아래를 채워서 알려 주면 23번 문서 7단계 결과에 기록하고 완료 처리한다.

- 6장 debug 로그인·환영 황금: ○/✕
- 11장 표 1~10번 결과
- 막힌 곳이 있으면: 그 단계 번호, 화면 캡처, 14장 확인 방법으로 본 서버 로그 한 줄

## 14. 문제 해결

**서버 로그 보는 법:** Firebase 콘솔 → `Functions` → 함수 이름(예: `authKakao`) 줄 오른쪽 `⋮` → `로그 보기`(Cloud Logging이 열림). 빨간 `Error` 줄을 펼쳐 메시지를 캡처한다.

| 증상 | 원인일 가능성 | 해결 |
| --- | --- | --- |
| 로그인 버튼을 눌러도 아무 일 없음, 앱 로그에 `invalid android_key_hash` | 카카오 키 해시 미등록 | 2-3(debug·업로드 키), 8-2(Play 앱) |
| 로그인 뒤 '지금은 온라인에 연결할 수 없어요', 서버 로그 `wrong-app`/`misconfigured` | `.env`의 `KAKAO_APP_ID`가 틀리거나 빔 | `.env` 확인 → 4장 3번 재배포 |
| 서버 로그 `iam.serviceAccounts.signBlob` 또는 `Permission 'iam.serviceAccounts.signBlob' denied` | 토큰 생성자 권한 없음 | 5-2 |
| 모든 기능이 실패, 서버 로그 `Unauthenticated`·`AppCheck token was rejected`/`missing` | App Check 미통과: debug는 디버그 토큰 미등록, Play 앱은 8-4 미완료, 직접 설치한 release APK는 Play Integrity 통과 못 함 | debug: 5-3. Play 앱: 8-3·8-4(반영까지 몇 분). 직접 설치 APK로 시험해야 하면 아래 "App Check 잠깐 끄기" |
| 상점 상품이 '구매할 수 없음' | 상품 비활성, 또는 Play에서 받지 않은 앱, 또는 테스터 아님 | 9-1 활성, 10-2로 설치, 10-1 |
| 결제는 됐는데 황금이 안 늘고 서버 로그 `insufficient permissions`/`401`/`403`(androidpublisher) | 구매 확인 권한 미반영 | 9-2, 하루 뒤 재시도. 결제는 서버 확인 전까지 앱이 마무리하지 않으므로 권한이 생긴 뒤 앱을 다시 켜면 지급된다. 단, Google은 확인(소모)되지 않은 결제를 일정 시간 뒤 자동 취소한다(실제 결제 3일, 테스트 구매는 몇 분). 테스트 구매가 취소돼도 돈은 나가지 않으니 권한 반영 뒤 새로 산다 |
| 서버 로그 `신규 게임 온라인 검증 연결을 준비 중` | `.env`의 `WORKSHOP_ONLINE_ENABLED`가 `true`가 아님 | `.env` 확인 → 재배포 |
| 서버 로그 `판매 보상 서버 설정 확인이 필요` | 추첨 키가 비었거나 잘림 | `.env`를 지우지 말고 메모장으로 `WORKSHOP_SALE_DRAW_KEY_BASE64=` 뒤 44글자 확인. 비었으면 `.env`를 다른 곳으로 옮기고 3-2 다시 실행 |
| 배포 중 `Billing account not configured` | Blaze 아님 | 1-2 |

**App Check 잠깐 끄기(문제 확인용):** `functions\.env`에서 `APP_CHECK_ENFORCED=true`를 `false`로 바꾸고 4장 3번 재배포. **확인이 끝나면 반드시 `true`로 되돌리고 다시 배포한다.** 꺼 둔 동안은 변조된 앱도 서버를 부를 수 있다.

## 15. 코드 쪽에서 준비해 둔 것 (참고)

| 항목 | 파일 |
| --- | --- |
| 앱 키 견본(빈 값), 실제 `online.json`은 커밋 제외 | `1_app_development/dart_defines/online.example.json`, 루트 `.gitignore` |
| 서버 설정 견본, 실제 `.env`는 커밋 제외 | `firebase/functions/.env.example`, `firebase/functions/.gitignore` |
| 서버 설정 만들기 스크립트(추첨 키 자동 생성, 화면에 안 보임) | `firebase/make_server_env.ps1` |
| Firebase CLI 바로가기(저장소 안 Node 22·CLI 사용) | `firebase/firebase_local.cmd` |
| 카카오 키 해시 계산 | `tools/kakao_key_hash.ps1` |
| 앱 App Check: debug 빌드는 디버그 토큰, 그 외 Play Integrity | `lib/firebase_online_backend.dart` (`_activateAppCheck`), `pubspec.yaml` `firebase_app_check` |
| 서버 App Check 강제(모든 callable, `APP_CHECK_ENFORCED=false`일 때만 끔) | `firebase/functions/src/callable_options.ts`, `index.ts` |
| 검사 | `test/online_setup_test.dart`, `test/no_tracking_sdk_test.dart`(허용 목록에 App Check 추가), `functions/test/callable_options.test.ts`, 에뮬레이터 `functions/test/emulator/workshop.integration.ts`(App Check 없는 호출 401) |

## 16. 구글 로그인·이메일 동의·계정 삭제 (26번 2-1단계)

2-1단계부터 앱을 처음 켜면 **약관 동의 + 카카오 또는 구글 로그인**을 마쳐야 게임이 시작된다. 아래를 하지 않으면 구글 버튼이 보이지 않거나(16-2), 눌러도 실패한다(16-1). 카카오 로그인은 1~6장 설정 그대로 된다.

> 참고: 이 앱은 `google-services.json` 파일을 쓰지 않는다(1-4). 그래서 "google-services.json 갱신"은 할 일이 아니고, 대신 16-2의 **웹 클라이언트 ID**를 `online.json`에 넣는다.

**16-1. Firebase에서 구글 로그인 켜기 + SHA-1 등록**
1. <https://console.firebase.google.com> → 프로젝트 → 왼쪽 `빌드` → `Authentication` → 위쪽 `로그인 방법`(Sign-in method) 탭.
2. `새 제공업체 추가` → `Google` 클릭 → 오른쪽 위 `사용 설정` 스위치를 켠다.
3. `프로젝트의 공개용 이름`: `오늘의 붕어빵`, `프로젝트 지원 이메일`: 내 Gmail 선택 → `저장`.
4. 왼쪽 위 톱니바퀴 → `프로젝트 설정` → `일반` 탭 → 아래 `내 앱`의 Android 앱(`com.todaybungeoppang.app`) → `디지털 지문 추가`.
5. 아래 **SHA-1** 세 개를 하나씩 넣고 `저장`한다(8-3에서 넣은 SHA-256과 별개로 SHA-1이 꼭 있어야 구글 로그인이 된다).

| 키 | SHA-1 | 어디서 |
| --- | --- | --- |
| 이 PC의 debug 키(`flutter run`) | `04:1A:06:46:C2:D5:37:58:6C:A1:C5:6E:EA:97:21:33:62:08:82:DB` | 2-3 표와 같음 |
| 업로드 키 | `17:17:AB:A9:DB:2D:31:40:06:0F:2D:4F:DE:48:89:16:3F:25:4C:42` | 2-3 표와 같음 |
| Play 앱 서명 키(Play에서 받은 앱) | 8-1에서 복사한 SHA-1 | Play Console → 앱 무결성 → 앱 서명 |

   SHA-1을 넣으면 Firebase가 Google Cloud에 'Android 클라이언트'를 자동으로 만든다. Play 앱 서명 키 SHA-1을 빼먹으면 **Play에서 받은 앱만** 구글 로그인이 실패한다.

**16-2. 웹 클라이언트 ID를 `online.json`에 넣기**
1. 16-1의 `Authentication` → `로그인 방법` → `Google` 줄을 다시 클릭 → `웹 SDK 구성`을 펼친다.
2. `웹 클라이언트 ID`(`숫자-영문.apps.googleusercontent.com` 모양)를 복사한다. (보이지 않으면 <https://console.cloud.google.com/apis/credentials> → 같은 프로젝트 → `OAuth 2.0 클라이언트 ID` 목록의 `Web client (auto created by Google Service)` → `클라이언트 ID` 복사.)
3. 탐색기에서 `1_app_development\dart_defines\online.json`을 메모장으로 열고, 마지막 줄 위에 아래처럼 한 줄을 넣는다(위 줄 끝에 쉼표를 붙이는 것 잊지 말기).
   ```json
     "APP_CHECK_DEBUG_TOKEN": "…원래 값…",
     "GOOGLE_SERVER_CLIENT_ID": "복사한 웹 클라이언트 ID"
   }
   ```
4. 저장한 뒤 3-1의 5번 확인 명령으로 `True`가 나오는지 본다. 이 값은 비밀은 아니지만 다른 키와 같이 `online.json`에만 둔다(커밋되지 않음).
5. 앱을 다시 빌드해야 반영된다(`flutter run --dart-define-from-file=dart_defines/online.json`, 출시용은 `flutter build appbundle …`).

**16-3. Google 동의 화면(OAuth) 확인**
1. <https://console.cloud.google.com/apis/credentials/consent> → 같은 프로젝트.
2. `앱 이름` `오늘의 붕어빵`, `사용자 지원 이메일`이 들어 있는지 본다(16-1의 3번에서 자동으로 채워짐). 비어 있으면 채우고 저장.
3. `게시 상태`가 `테스트`면 `앱 게시`를 눌러 `프로덕션`으로 바꾼다(이 앱이 받는 범위는 이메일·프로필뿐이라 Google 심사가 필요 없다). `테스트`로 두면 `테스트 사용자`에 넣은 계정만 로그인된다.

**16-4. 카카오 이메일 동의 항목 (`account_email`)**
1. <https://developers.kakao.com> → 내 애플리케이션 → `오늘의 붕어빵` → `제품 설정` → `카카오 로그인` → `동의항목`.
2. `카카오계정(이메일)` 줄의 `설정` → **선택 동의**, 동의 목적 `공지·계정 안내` → 저장.
3. `설정` 버튼이 회색이라 누를 수 없으면 이메일은 '비즈 앱'만 받을 수 있는 경우다: `앱 설정` → `비즈니스`(또는 `앱 권한 신청`) → `개인 개발자 비즈 앱 전환` → 안내대로 본인 확인 → 다시 1~2.
4. 이메일 동의를 켜지 않아도 로그인은 된다(서버가 이메일을 비워 둔다).

**16-5. 서버 다시 배포 (꼭)**

구글 계정을 받는 검사, `accountProfileSet`(이름·동의·선택 정보 저장), `accountDelete`(계정 삭제) 함수가 새로 생겼다. 배포 전에는 구글 로그인한 사람이 서버를 부르면 거절되고, 계정 삭제도 실패한다.
1. PowerShell을 열고 0-3의 `subst B: …` 한 줄을 먼저 실행한 뒤 `cd B:\1_app_development\firebase`.
2. `.\firebase_local.cmd deploy --only "functions,firestore"` (4장 3번과 같음). `✔ Deploy complete!`가 나오면 성공.
3. 확인: Firebase 콘솔 → `Functions` 목록에 `accountProfileSet`·`accountDelete`가 `asia-northeast3`로 보이면 된다.
4. **서버를 먼저 배포하고 앱을 올린다.** (새 앱이 옛 서버를 부르면 구글 로그인 사용자가 막힌다.)

**16-6. Play Console 데이터 보안·계정 삭제 항목**
1. Play Console → `앱 콘텐츠` → `데이터 보안` → [play_data_safety.md](play_data_safety.md)의 '양식 답변' 표대로 고친다(이메일 주소·성별·연령대가 새로 들어감).
2. 같은 화면의 `데이터 삭제` 질문: '사용자가 앱 안에서 계정 삭제를 요청할 수 있음' 예, 웹 링크 칸에는 공개한 개인정보처리방침 주소(6절 '계정 삭제')를 넣는다.
3. 개인정보처리방침·이용약관(`privacy_policy.md`, `terms_of_service.md`)을 공개 웹 주소에 올리고 스토어 등록정보의 `개인정보처리방침` 칸에 넣는다.

**16-7. 확인**
11장 표 0~0-4·9·9-1번을 해 보고 결과를 13장처럼 알려 준다. 구글 로그인이 `로그인하지 못했어요`로 끝나면 대부분 16-1의 SHA-1(특히 Play 앱 서명 키) 누락이다.

## 17. 사용 통계 (Google Analytics, 26번 5단계)

26번 5단계부터 앱이 Firebase Analytics로 **이름 없는 사용 통계**를 보낸다(로그인과 상관없이 기본 켬, 설정 > '사용 통계 보내기'로 끔). 앱 쪽 준비는 끝났고, 콘솔에서 아래만 하면 된다. **서버 배포나 새 키는 필요 없다**(3장 `online.json`의 Firebase 값 4개를 그대로 쓴다).

보내는 이벤트: `first_bake`(첫 굽기), `first_sale`(첫 판매), `tutorial_done`(안내 끝, `result`=done/skipped), `level_reached`(`level`=3·5·10), `shop_open`(상점, 하루 1번), `pay_view`(황금 충전 화면, 하루 1번), `pay_done`(결제 완료, `product_id`만), `special_order_done`(오늘의 주문서 납품, `event`=행사 ID 또는 none, 26번 7단계), `event_join`(겨울 행사 기간 첫 접속, `event`=행사 ID). 첫 실행 `first_open`과 재방문 `session_start`는 Analytics가 스스로 모은다.

**17-1. Google Analytics 켜기(계정 연결)**
1. <https://console.firebase.google.com> → 프로젝트 → 왼쪽 위 톱니바퀴 → `프로젝트 설정` → 위쪽 `통합` 탭.
2. `Google Analytics` 카드의 `사용 설정`(이미 켜져 있으면 `관리`라고 보인다 → 17-2로).
3. `Google 애널리틱스 계정`: 처음이면 `새 계정 만들기` → 이름 `오늘의 붕어빵` → 저장. 있으면 그 계정을 고른다.
4. `애널리틱스 위치`: **대한민국**. 아래 데이터 공유 체크(Google 제품·서비스, 벤치마킹, 기술 지원 등)는 **모두 해제**한다(Google에 넘기는 범위를 줄임).
5. `Google 애널리틱스 사용 설정` → 끝나면 `완료`. 이제 Firebase 앱(`com.todaybungeoppang.app`)과 연결된 Analytics '속성'이 생긴다.

**17-2. 데이터 보존 14개월 + 광고 신호 끄기**
1. <https://analytics.google.com> 을 열고 왼쪽 아래 톱니바퀴 `관리`.
2. 가운데 `속성` 열(속성 이름이 `오늘의 붕어빵`인지 확인) → `데이터 수집 및 수정` → `데이터 보존`.
3. `이벤트 데이터 보존`을 **14개월**로 바꾸고 `저장`. (무료판에서 고를 수 있는 가장 긴 값이다. 원래 원하신 10년은 무료판으로는 안 되고, 17-5의 BigQuery 내보내기로만 오래 남길 수 있다.)
4. 같은 `데이터 수집 및 수정` → `데이터 수집` → `Google 신호 데이터 수집`이 **꺼져 있는지** 확인한다(켜져 있으면 끈다). 광고·맞춤 광고 연결은 하지 않는다.
5. `관리` → `제품 링크`에서 Google Ads·AdSense 같은 광고 연결이 **없는지** 확인한다.

**17-3. 맞춤 측정기준 등록(레벨·결과별로 나눠 보기)**
1. `관리` → `속성` 열 → `데이터 표시` → `맞춤 정의` → `맞춤 측정기준 만들기`.
2. 아래 5개를 하나씩 만든다(이름 = 이벤트 매개변수 이름 그대로 써도 된다).

| 측정기준 이름 | 범위 | 이벤트 매개변수 / 사용자 속성 |
| --- | --- | --- |
| level | 이벤트 | `level` |
| tutorial_result | 이벤트 | `result` |
| product_id | 이벤트 | `product_id` |
| gender | 사용자 | `gender` |
| age_band | 사용자 | `age_band` |

3. 등록 전 데이터에는 적용되지 않으니 앱을 올리기 전에 해 두면 좋다.

**17-4. DebugView로 이벤트가 오는지 확인 (휴대폰 1대, 10분)**
1. 6장처럼 휴대폰을 USB로 연결하고 PowerShell에서:
   ```powershell
   C:\Android\sdk\platform-tools\adb.exe shell setprop debug.firebase.analytics.app com.todaybungeoppang.app
   ```
2. 6장 3번 명령(`flutter run --dart-define-from-file=dart_defines/online.json`)으로 앱을 켠다. **앱 데이터를 지운 새 설치**면 `first_open`도 보인다.
3. Firebase 콘솔 → 왼쪽 `Analytics`(또는 `분석`) → `DebugView`. 1분쯤 안에 휴대폰 이름이 보이고 이벤트가 시간순으로 올라온다.
4. 게임에서 첫 굽기 → 보관 → 영업 → 첫 판매까지 해 보면 `first_bake` → `first_sale` → `tutorial_done`이 차례로 와야 한다. 상점을 열면 `shop_open`.
5. 설정 > '사용 통계 보내기'를 끄고 상점을 다시 열면(다음 날이 아니어도) 아무 이벤트도 오지 않아야 한다. 확인 뒤 다시 켠다.
6. 끝나면 디버그 모드를 끈다:
   ```powershell
   C:\Android\sdk\platform-tools\adb.exe shell setprop debug.firebase.analytics.app .none.
   ```
7. 이벤트가 하나도 안 오면 14장처럼 알려 준다(로그에 `Missing google_app_id`가 보이면 `online.json`의 `FIREBASE_APP_ID`가 빠진 것).

**17-5. 1일·7일 재방문과 어디서 그만두는지 보기**
- **재방문(리텐션):** <https://analytics.google.com> → 왼쪽 `탐색` → `동질 집단 탐색 분석`(Cohort) 템플릿 → `동질 집단 포함 조건` = `first_open`, `재방문 기준` = `session_start`(모든 이벤트도 됨), `동질 집단 세부사항` = `일별`. 표의 `1일`·`7일` 열이 1일·7일 뒤 다시 온 비율이다. 간단히 보려면 `보고서` → `참여도`/`유지`(Retention) 화면도 있다.
- **단계별 이탈(유입경로):** `탐색` → `유입경로 탐색 분석` → `단계` 연필 → 아래 순서로 단계를 만든다: ① `first_open` ② `first_bake` ③ `first_sale` ④ `tutorial_done` ⑤ `level_reached`(매개변수 조건 `level` = 3) ⑥ `level_reached`(`level` = 5) ⑦ `level_reached`(`level` = 10). `개방형 유입경로`는 끈다. 막대 사이 `이탈` 숫자가 그 단계에서 그만둔 사람 수다. 결제 쪽은 `shop_open` → `pay_view` → `pay_done` 3단계로 따로 만든다.
- 데이터는 보통 하루 안에 보고서에 나타난다(DebugView는 바로).

**17-6. (선택) BigQuery 내보내기 — 10년 보관하고 싶을 때**
- Analytics 무료판은 이벤트 원본을 **최대 14개월**만 둔다. 더 오래 남기려면 매일 원본을 BigQuery로 복사해 두면 된다(복사한 표는 지우기 전까지 남는다).
- 켜는 법: Firebase 콘솔 → 톱니바퀴 `프로젝트 설정` → `통합` → `BigQuery` → `연결` → `Google Analytics` 켜기, 내보내기 방식은 **일일**(스트리밍은 따로 돈이 듦) → 데이터 위치 `asia-northeast3 (서울)` → `BigQuery에 연결`. 프로젝트는 이미 Blaze 요금제라 따로 할 일은 없다.
- 비용(2026-11 기준 Google 공개 가격, 바뀔 수 있음): 일일 내보내기 자체는 무료. 저장은 매달 처음 10GB 무료, 그 뒤 GB당 월 약 0.02달러(90일 넘게 안 바뀐 표는 약 0.01달러). 조회는 매달 1TB 무료. 이벤트 1개를 약 1KB로 잡으면 하루 1,000명 × 30개 = 하루 약 30MB, 1년 약 11GB, 10년 약 110GB → 10년째에도 **한 달 1~2달러 안팎**. 1-3의 예산 알림이 그대로 지켜 준다.
- 개인정보처리방침은 지금 '14개월 보관'으로 적혀 있다. BigQuery로 더 오래 남기기로 하면 **방침의 보관 기간도 함께 고쳐야 한다**(고칠 때 알려 주면 문서를 바꿔 준다).
