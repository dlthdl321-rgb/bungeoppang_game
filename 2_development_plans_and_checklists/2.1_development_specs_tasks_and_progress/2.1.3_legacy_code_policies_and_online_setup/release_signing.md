# 업로드 키와 release 빌드 따라 하기

작성 2026-11-17 (23번 6단계). 개발이 처음이어도 위에서부터 차례로 따라 하면 되도록 썼다.

- 앱 패키지 이름(applicationId): `com.todaybungeoppang.app`. Google Play에 한 번 올리면 **바꿀 수 없다**.
- 키 파일 위치: `C:\keys\bungeoppang-upload.jks`, 키 별칭(alias): `upload`.
- 이 PC의 keytool: `C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe`.

## 0. 먼저 알아 둘 것

**왜 키가 필요한가:** Play 스토어는 "이 앱을 올린 사람이 매번 같은 사람인지"를 서명으로 확인한다. 우리가 만드는 키는 **업로드 키**다. Play 앱 서명(Play App Signing)을 쓰므로, 사용자 휴대폰에 설치되는 앱은 Google이 따로 보관하는 **앱 서명 키**로 다시 서명된다. 그래서 업로드 키를 잃어버려도 앱이 끝나지는 않지만, Play Console에 "업로드 키 재설정"을 요청해 며칠 기다려야 하고 그동안 새 버전을 올릴 수 없다.

**PowerShell 여는 법:** 키보드에서 `Windows 키`를 누르고 `powershell`을 입력한 뒤 **Windows PowerShell**을 클릭한다. 파란(또는 검은) 창이 뜨면 아래 명령을 한 줄씩 복사(Ctrl+C)해서 창에 붙여 넣고(마우스 오른쪽 클릭 또는 Ctrl+V) `Enter`를 누른다.

**절대 하지 말 것:** 키 파일(`.jks`)과 비밀번호를 저장소 폴더(`붕어빵 게임`) 안에 두거나, 메신저·공개 클라우드에 올리지 않는다. `.gitignore`가 `key.properties`, `*.jks`, `*.keystore`를 막아 두었지만, 처음부터 저장소 밖에 두는 것이 안전하다.

## 1. 업로드 키 만들기 (한 번만)

> 이미 `C:\keys\bungeoppang-upload.jks`를 만들었다면 1-4(확인)만 하고 2로 넘어간다.

**1-1. 폴더 만들기.** 키 파일을 둘 영문 폴더를 만든다. keytool은 **한글이 들어간 경로에서 `Bad pathname` 오류로 실패한다**(2026-11-17 이 PC에서 확인). 그래서 `C:\keys`를 쓴다.

```powershell
New-Item -ItemType Directory -Force C:\keys
```

- GUI로 하려면: 파일 탐색기 → `내 PC` → `로컬 디스크 (C:)` → 빈 곳 오른쪽 클릭 → `새로 만들기` → `폴더` → 이름 `keys`.

**1-2. 키 만들기.** 아래 한 줄을 그대로 붙여 넣는다(앞의 `&`까지 포함).

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" -genkeypair -v -keystore C:\keys\bungeoppang-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

화면에 질문이 차례로 나온다(Windows 언어에 따라 영어 또는 한국어).

| 화면에 나오는 질문 | 입력할 것 |
| --- | --- |
| 키 저장소 비밀번호 입력 / Enter keystore password | 새 비밀번호(6자 이상). **입력해도 화면에 글자가 안 보이는 것이 정상**이다 |
| 새 비밀번호 다시 입력 / Re-enter new password | 같은 비밀번호 |
| 이름과 성 / What is your first and last name? | 예: `Soi Lee` (영문 권장) |
| 조직 단위 / organizational unit? | 그냥 `Enter` (비워도 됨) |
| 조직 이름 / organization? | 그냥 `Enter` 또는 팀 이름 |
| 구/군/시 / City or Locality? | 예: `Seoul` |
| 시/도 / State or Province? | 예: `Seoul` |
| 국가 코드 / two-letter country code? | `KR` |
| 맞습니까? / Is CN=... correct? | 한국어면 `예`, 영어면 `yes` |
| (키 비밀번호를 따로 물으면) | 그냥 `Enter`를 누르면 저장소 비밀번호와 같게 된다 |

마지막에 `[C:\keys\bungeoppang-upload.jks을(를) 저장하는 중]` 또는 `[Storing C:\keys\bungeoppang-upload.jks]`가 나오면 성공이다.

**1-3. 비밀번호 적어 두기.** 키 저장소 비밀번호와 키 비밀번호(따로 안 정했다면 같은 값)를 비밀번호 관리자 등 안전한 곳에 적는다. 키 파일만 있고 비밀번호가 없으면 쓸 수 없다.

**1-4. 잘 만들어졌는지 확인.**

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" -list -v -keystore C:\keys\bungeoppang-upload.jks -alias upload
```

비밀번호를 넣으면 `별칭 이름: upload`(Alias name: upload)와 `SHA1:`, `SHA256:`으로 시작하는 지문이 나온다. 이 지문은 7단계에서 Firebase·카카오에 등록할 때 쓴다. 탐색기에서 `C:\keys` 폴더를 열어 `bungeoppang-upload.jks` 파일이 보이는지도 확인한다.

## 2. key.properties 만들기

**왜:** 빌드 도구(Gradle)가 키 파일 위치와 비밀번호를 이 파일에서 읽는다. 이 파일이 없으면 release 빌드는 일부러 멈춘다(3장).

**위치:** `D:\Users\이소이\Desktop\Git\붕어빵 게임\1_app_development\android\key.properties` (`android` 폴더 안, `build.gradle.kts`·`settings.gradle.kts`가 있는 곳).

**내용:** 아래 네 줄. `키저장소비밀번호`, `키비밀번호` 자리에 1-3에서 적은 비밀번호를 넣는다. 등호(`=`) 앞뒤에 띄어쓰기를 넣지 않는다.

```properties
storePassword=키저장소비밀번호
keyPassword=키비밀번호
keyAlias=upload
storeFile=C:/keys/bungeoppang-upload.jks
```

- `storeFile` 경로는 **슬래시(`/`)** 로 쓴다. 이 파일 형식에서 역슬래시(`\`)는 특수 문자라 `C:\keys\...`로 쓰면 경로가 깨진다. 이 형식(`S:/.../temp.jks`처럼 드라이브+슬래시)이 실제 빌드에서 읽히는 것을 2026-11-17 임시 키로 확인했다.
- 비밀번호에 `\`가 들어 있으면 `\\`로 두 번 적는다.

**메모장으로 만드는 법 (.txt가 붙지 않게):**
1. 탐색기에서 `1_app_development\android` 폴더를 연다.
2. 시작 메뉴에서 `메모장`을 열고 위 네 줄을 붙여 넣은 뒤 비밀번호를 고친다.
3. `파일` → `다른 이름으로 저장` → 위의 `android` 폴더로 이동.
4. 아래쪽 **파일 형식**을 `모든 파일 (*.*)`로 바꾼다. (이걸 안 하면 `key.properties.txt`가 된다.)
5. 파일 이름에 `key.properties`를 입력하고, 인코딩은 `UTF-8`(기본값) 그대로 → `저장`.
6. 확인: 탐색기 상단 `보기` → `표시` → `파일 확장명`을 켜고, 파일 이름이 정확히 `key.properties`인지 본다. `key.properties.txt`로 보이면 파일을 오른쪽 클릭 → `이름 바꾸기`로 `.txt`를 지운다(확장명 변경 경고에 `예`).

PowerShell로 확인하려면:

```powershell
Test-Path "D:\Users\이소이\Desktop\Git\붕어빵 게임\1_app_development\android\key.properties"   # True가 나오면 있음
cd "D:\Users\이소이\Desktop\Git\붕어빵 게임"; git status --short   # key.properties가 목록에 안 나오면 커밋에서 제외된 것(정상)
```

## 3. AAB(Play 업로드 파일) 만들기

**왜:** Play Console에는 APK가 아니라 AAB(`.aab`) 파일을 올린다.

PowerShell을 새로 열고 아래를 **한 줄씩** 실행한다. 저장소 경로에 한글이 있어 빌드 도구가 실패하므로 `B:` 드라이브로 연결해서 쓴다.

```powershell
subst B: "D:\Users\이소이\Desktop\Git\붕어빵 게임"      # "이미 연결됨" 오류가 나면 무시
cd B:\1_app_development
$env:GRADLE_USER_HOME='D:\DevMoved\GradleCache'; $env:PUB_CACHE='C:\PubCacheBungeoppang'
D:\DevMoved\flutter-sdk\bin\flutter.bat pub get
D:\DevMoved\flutter-sdk\bin\flutter.bat build appbundle --release
```

- `GRADLE_USER_HOME`은 **`D:\DevMoved\GradleCache`(실제 폴더)** 로 쓴다. `C:\GradleCache`는 이 폴더로 연결된 바로가기(정션)인데, 그 경로로 쓰면 빌드 스크립트를 고친 뒤 `Unresolved reference 'println'` 같은 오류가 쏟아진다(2026-11-17 확인).
- 시간이 오래 걸린다(처음 10분 이상). `√ Built build\app\outputs\bundle\release\app-release.aab`가 나오면 성공.
- 결과 파일: 탐색기에서 `1_app_development\build\app\outputs\bundle\release\app-release.aab`.
- 위 명령은 온라인 기능이 꺼진 빌드다. Play에 올릴 온라인 빌드는 마지막 줄 끝에 ` --dart-define-from-file=dart_defines/online.json`을 붙인다(키 파일 만들기는 [online_setup.md](online_setup.md) 3장, 7-1).

**잘 됐는지 확인 (업로드 키로 서명됐는지):**

```powershell
& "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\keytool.exe" -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

나온 `SHA256:` 값이 1-4의 지문과 같으면 된다. `CN=Android Debug`가 보이면 잘못된 것이다(이 설정에서는 그렇게 될 수 없게 막아 두었다).

**확인된 업로드 키 지문 (2026-11-17 첫 서명 빌드, AAB·APK 같음):** 서명자 `CN=Soi Lee, C=KR`. 이 값은 비밀이 아니다. 7단계에서 Firebase·카카오에 등록할 때 이 값을 쓴다.

```
SHA-256: 6A:17:CF:A1:1C:B5:EB:2E:97:C1:8F:E7:DB:3C:12:8B:24:BB:B3:91:ED:23:1D:78:8B:FB:D5:30:B6:BA:54:EA
```

**이런 오류가 나오면:** `release 빌드 중단: android/key.properties 파일이 없습니다` → 2장의 파일 위치·이름(.txt) 확인. `…가 모두 있어야 합니다` → 네 줄 중 빠진 줄 확인. `…가리키는 키 파일이 없습니다` → `storeFile` 경로와 슬래시 확인. `Keystore was tampered with, or password was incorrect` → 비밀번호 확인.

**빌드 뒤 테스트 환경 되돌리기:**

```powershell
Remove-Item Env:PUB_CACHE; D:\DevMoved\flutter-sdk\bin\flutter.bat pub get
```

## 4. 휴대폰에 release 앱 설치해서 확인하기

**왜:** release 빌드는 코드 축소(R8)를 하므로, debug에서 되던 것이 release에서 깨질 수 있다. 올리기 전에 실제 휴대폰에서 한 번 켜 본다.

1. 휴대폰 `설정` → `휴대전화 정보` → `소프트웨어 정보` → `빌드번호`를 7번 눌러 개발자 옵션을 켠다. `설정` → `개발자 옵션` → `USB 디버깅` 켜기. USB로 PC에 연결하고 휴대폰에 뜨는 "USB 디버깅 허용"에 `허용`.
2. 설치용 APK를 만든다(3장과 같은 창에서):
   ```powershell
   D:\DevMoved\flutter-sdk\bin\flutter.bat build apk --release
   ```
3. 연결 확인: `adb devices` → 목록에 기기 번호와 `device`가 보이면 된다. (`adb`를 못 찾으면 `C:\Android\sdk\platform-tools\adb.exe`로 바꿔 쓴다.)
4. 같은 이름의 debug 앱이 깔려 있으면 서명이 달라 덮어 설치가 안 된다. 먼저 지운다(**그 휴대폰의 게임 진행이 지워진다**):
   ```powershell
   adb uninstall com.todaybungeoppang.app
   adb install B:\1_app_development\build\app\outputs\flutter-apk\app-release.apk
   ```
   `Success`가 나오면 설치 완료. GUI로 하려면 APK 파일을 휴대폰으로 복사해 파일 앱에서 눌러 설치해도 된다("출처를 알 수 없는 앱" 허용 필요).
5. 오류 기록을 보면서 앱을 켠다:
   ```powershell
   adb logcat -c
   adb shell am start -n com.todaybungeoppang.app/.MainActivity
   adb logcat *:E | Select-String "FATAL|ClassNotFound|NoSuchMethod|MissingPlugin"
   ```
   영업 시작 → 굽기 → 판매 → 상점(결제 창 열기) → 로그인 버튼까지 눌러 본다. 창에 아무것도 안 나오면 좋다. `FATAL EXCEPTION`, `ClassNotFoundException`, `NoSuchMethodError`, `MissingPluginException`이 나오면 그 줄을 복사해서 알려 준다. 끝내려면 `Ctrl+C`.

**옛 패키지 이름 앱:** 예전 debug 빌드는 `com.todaybungeoppang.todays_bungeoppang`이라는 다른 이름이었다. 휴대폰에 그 앱이 따로 남아 있고, 그 진행은 새 앱으로 옮겨지지 않는다. 필요 없으면 `adb uninstall com.todaybungeoppang.todays_bungeoppang` 또는 휴대폰에서 직접 삭제한다.

## 5. 백업과 분실 대비

- `C:\keys\bungeoppang-upload.jks`와 비밀번호를 **두 곳 이상**에 백업한다(예: 비밀번호 관리자 + USB 메모리). 탐색기에서 파일을 복사해 붙여 넣으면 된다.
- 잃어버렸을 때: Play Console → 앱 선택 → `테스트 및 출시` → `앱 무결성` → `앱 서명` → `업로드 키 재설정 요청`. 새 키를 1장대로 만들고, 안내에 따라 인증서(PEM)를 내보내 제출한다. Firebase·카카오에 등록한 업로드 키 지문도 새 것으로 바꾼다.

## 6. 버전 번호 규칙

`1_app_development/pubspec.yaml`의 `version: 0.1.0+1`에서 `+` 뒤 숫자(versionCode)는 **Play에 올릴 때마다 1씩 올린다**. 한 번 올린 번호는 다시 쓸 수 없다. 앞부분(versionName)은 가출시 동안 `0.1.x`(고친 빌드마다 x+1), 정식 출시는 `1.0.0`. 예: `0.1.0+1` → `0.1.1+2` → `0.1.2+3`.
