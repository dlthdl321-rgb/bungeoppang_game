# 오늘의 붕어빵

## 자료 위치 안내

| 찾는 자료 | 폴더 | 내용 |
| --- | --- | --- |
| 게임 소스 | [lib/](lib/) | 게임 규칙, 저장, 온라인 기능 |
| 화면·UI | [lib/ui/](lib/ui/) | 게임 화면, 상점, 꾸미기, 효과 |
| 적용된 이미지 | [assets/images/](assets/images/) | 캐릭터, 붕어빵, 배경, 아이콘 |
| 음악·효과음 | [assets/audio/](assets/audio/) | 배경 음악과 효과음 |
| 글꼴·라이선스 | [assets/fonts/](assets/fonts/) | 글꼴과 이용 조건 |
| 이미지 원본·시안 | [이미지/](이미지/) | 생성 원본, 미리보기, 개발 에셋 |
| 이미지 작업 결과 | [output/imagegen/](output/imagegen/) | 생성·검토 결과 |
| 스토어 이미지 | [store/](store/) | 배너와 스플래시 |
| 개발·출시 문서 | [docs/](docs/) | 단계별 기록, 정책, 출시 설정 |
| 이미지 프롬프트 | [docs/prompts/](docs/prompts/) | 이미지 교체·생성 지시문 |
| 검증·비교 보고서 | [docs/reports/](docs/reports/) | 검증 결과와 차이 분석 |
| ZIP 보관 파일 | [archives/](archives/) | 날짜별 백업·APK 압축파일 |
| Firebase 서버 | [firebase/](firebase/) | 서버 함수, 보안 규칙, 배포 설정 |
| Android 설정 | [android/](android/) | 빌드와 플랫폼 연동 |
| iOS 설정 | [ios/](ios/) | 빌드와 플랫폼 연동 |
| 테스트 | [test/](test/) | 기능 테스트와 비교용 화면 |
| 개발 도구 | [tools/](tools/) | 이미지·사운드 제작, 실행 스크립트 |

**[마스터 문서](docs/MASTER.md)**: 기능·설정을 추가하기 전에 확인하는 기준 문서입니다(설정값, 화면 배치, 저장 규칙, 추가 작업 체크리스트).

**[자료 찾기 안내](docs/file_guide.md)**에서 하위 폴더와 문서·ZIP 목록을 확인하세요.
현재 게임은 `lib/`와 `assets/`, 과거 보관 파일은 `archives/`에서 찾을 수 있습니다.
APK, 빌드 캐시, 로컬 설정은 기존 `.gitignore`에 따라 Git에 포함되지 않습니다.

Flutter로 만든 세로형 붕어빵 클리커 게임입니다. 광고·별도 분석 SDK 없이 기기 안에서 동작합니다. 온라인 기능(랭킹, 친구, 황금 붕어빵)은 카카오 계정으로 로그인해 Firebase 서버를 씁니다. 현금·상품·포인트는 지급하지 않습니다.

## 게임 구성

설정값과 공식, 화면 좌표는 [마스터 문서](docs/MASTER.md)에 모아 두었습니다. 여기서는 전체 모습만 설명합니다.

- **홈 화면**: 야간 노점 배경 위에 굽는 판과 붕어빵이 있습니다.
  - 위쪽 HUD: 레벨 배지(누르면 레벨 미션), 보유 붕어빵, 초당·클릭당 생산, 메뉴·설정 버튼
  - 아래쪽 버튼 4개: 메뉴 · 스킬 · 꾸미기 · 상점
  - 일일 미션, 주간 도전, 업적·도감, 통계, 온라인 랭킹, 친구, 공유는 **메뉴** 안에 있습니다.
- **스킬**: 클릭 생산과 자동 생산이 각각 16단계입니다. 1개·10개·최대 구매를 지원하고, 가격·생산·보상은 BigInt로 계산합니다(`lib/economy_config.dart`).
- **레벨 미션**: Lv.1~10, 시즌 `offline-v1`. 조건을 모두 채우면 레벨업 보상을 직접 받습니다(`lib/mission_config.dart`).
- **일일 미션·주간 도전**: 일일 미션은 한국 시각 자정, 주간 도전은 월요일 00:00(KST)에 초기화합니다. 받지 않은 주간 보상은 주가 바뀌면 사라집니다.
- **업적 24개**: 보상은 코인 또는 칭호입니다. 도감에서 꾸미기와 칭호 수집 현황을 봅니다.
- **부스트**: 황금 찬스, 친구 방문, 초대 손님, 황금 부스트가 생산을 일정 시간 늘립니다. 가장 센 것 하나만 적용됩니다(`lib/support_config.dart`).
- **꾸미기**: 붕어빵(무늬·토핑), 사장님(캐릭터·피부·머리·옷·모자·소품·도구), 가게(배경·화로·장식·등불·시간대)를 코인으로 삽니다(`lib/cosmetic_config.dart`).
- **새 노점 열기(환생)**: Lv.10 이후 진행을 초기화하고 별을 받습니다. 별 1개당 생산 +5%입니다(`lib/prestige_config.dart`).
- **황금 붕어빵**: Google Play 결제로 사는 유료 재화입니다. 꾸미기, 스킬 조기 해금, 황금 부스트에 씁니다. 결제는 서버가 확인합니다(`lib/premium_config.dart`).
- **연출·소리**: +N 숫자, 부스러기, 콤보, 축하 배너, 효과음 4종, 배경별 음악이 있습니다. 모션 줄이기 설정을 지원합니다(`lib/feedback_config.dart`, `lib/music_config.dart`).

## 실행

필수 환경은 Flutter 3.47.5(Dart 3.13.4), JDK 17, Android SDK 36입니다.

```powershell
flutter pub get
flutter test
flutter run
```

이 Windows 환경에서는 한글 경로에서 Flutter 셰이더 도구와 Kotlin 데몬이 실패했으므로 영문 경로 또는 영문 드라이브 매핑에서 실행해야 합니다. 예: `subst B: "프로젝트 절대경로"` 후 `B:`에서 실행합니다. `android/gradle.properties`는 Kotlin 인프로세스 컴파일을 사용하도록 설정되어 있습니다. release 빌드는 Gradle·Pub 캐시도 영문 경로여야 합니다: `$env:GRADLE_USER_HOME='C:\GradleCache'; $env:PUB_CACHE='C:\PubCacheBungeoppang'` 후 `flutter pub get`, `flutter build apk --release`. 기본 Pub 캐시(한글 사용자 폴더)에서는 오디오 패키지가 가져오는 `jni`의 CMake 빌드가 실패합니다.

debug APK는 `flutter build apk --debug`로 다시 만들 수 있습니다. 생성 위치는 `build/app/outputs/flutter-apk/app-debug.apk`입니다.

Android 가상 기기는 `TodayBungeoppang_API35`입니다. 2026-10-05에는 AEHD 2.2가 사용 가능한 것으로 확인됐습니다. `tools/run_android_emulator.ps1`은 현재 빌드 경로의 APK만 선택하고 대상 AVD를 확인합니다. 부팅 제한 시간은 3분이며 사용자 기기에는 설치하지 않습니다. 설치/실행 검증의 실제 결과는 재현 감사 보고서를 참고하세요.


온라인 기능을 켜려면 키 5개를 dart-define으로 넘깁니다. 하나라도 없으면 랭킹·친구가 "준비 중"으로 표시되고 게임은 오프라인으로 동작합니다. 키는 저장소에 넣지 않습니다.

```
flutter run --dart-define=KAKAO_NATIVE_APP_KEY=... --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

서버 설정과 배포는 [15단계 기록](docs/stage15_release_online.md)과 [16단계 기록](docs/stage16_kakao_login_ranking.md)을 참고하세요.

## 코드 구조

| 위치 | 내용 |
| --- | --- |
| `lib/*_config.dart` | 조정 가능한 값: 경제, 미션, 일일·부스트, 주간, 업적, 환생, 꾸미기, 프리미엄, 랭킹, 초대, 연출, 음악 |
| `lib/*_rules.dart`, `lib/economy.dart`, `lib/missions.dart` | 상태를 받아 계산하는 순수 함수 |
| `lib/models.dart`, `lib/*_state.dart` | 저장되는 상태, JSON 변환, 버전 이전, 검증 |
| `lib/game_controller.dart` | 단일 상태 원본과 명령·시간 정산. `boost_`, `online_`, `premium_`, `menu_`, `ranking_`, `invite_controller.dart`가 여기에 붙습니다 |
| `lib/repository.dart` | SQLite 현재/백업 스냅샷, 테스트용 메모리 저장소 |
| `lib/firebase_online_backend.dart`, `lib/online_backend.dart` | 카카오 로그인 → Firebase, 서버 함수 호출 |
| `lib/billing_service.dart`, `lib/play_billing_service.dart` | Google Play 결제 |
| `lib/ui/` | 화면. 홈은 `night_home.dart`, 패널 연결은 `game_app.dart`, 디자인 토큰은 `cozy_style.dart` |
| `firebase/functions/src/` | 서버 함수: 로그인, 지갑, 초대, 친구, 랭킹 |
| `firebase/firestore.rules` | 클라이언트 직접 접근을 모두 막고 서버 함수만 데이터를 다룹니다 |
| `test/` | 경제·저장·미션·꾸미기·온라인·화면 크기·골든 테스트 |

## 저장 및 한계

- 저장 형식은 **JSON v12**입니다. SQLite 테이블과 SQL 버전 1은 유지하고, v1부터의 저장 데이터를 모두 현재 형식으로 옮깁니다(버전별 내용은 마스터 문서 3장).
- 10초마다 저장하고, 구매·레벨업·보상 수령·부스트·꾸미기·설정 변경·앱 비활성화 때 즉시 저장합니다. 프레임이나 일반 탭마다 저장하지 않습니다.
- 현재/직전 스냅샷은 SQLite 트랜잭션으로 교체됩니다. 현재 저장을 읽지 못하면 복구 화면에서 직전 스냅샷을 올리거나(확인 후) 초기화합니다([7단계 기록](docs/stage7_baseline_bugfix.md)).
- 강제 종료 시 마지막 정기 저장 이후의 일반 터치가 일부 사라질 수 있습니다.
- 오프라인 보상은 최대 8시간, 접속 중 생산의 50%입니다. 기기 시계를 되돌려도 지난 날짜·주는 다시 열리지 않지만, 앞으로 돌리는 것은 서버 없이 완전히 막을 수 없습니다.
- 랭킹 점수는 기기에서 계산하므로 서버는 형식, 빈도, 증가 폭만 확인합니다. 조작을 줄일 뿐 완전히 막지는 못합니다.

## 개인정보와 Play 데이터 보안

게임 저장은 기기 안에서만 합니다. 온라인 기능에 로그인하면 카카오 회원번호와(동의 시) 카카오 닉네임, 아바타 꾸미기, 순위표 점수, 친구·초대·황금 붕어빵 기록이 개발자의 Firebase 서버(서울)에 저장됩니다. 카카오 친구 목록과 카카오톡 메시지는 쓰지 않습니다. [개인정보처리방침](docs/privacy_policy.md)과 [Play Console 데이터 보안 양식 기준](docs/play_data_safety.md)을 참고하세요.

`test/no_tracking_sdk_test.dart`는 허용 목록 밖의 광고·분석 SDK가 의존성에 들어오거나 Google Play 서비스 라이브러리가 추가되면 실패합니다. release 병합 매니페스트가 있으면 광고 ID·측정 항목도 검사합니다.

## 에셋과 라이선스

원작 로고·스크린샷·추출 에셋은 사용하지 않았습니다.

| 에셋 | 출처 | 라이선스 |
| --- | --- | --- |
| `assets/images/` | 이 프로젝트에서 제작한 도트 그림. 원본과 시안은 `이미지/`, 변환 스크립트는 `tools/` | 프로젝트 소유 |
| `assets/audio/` 효과음 4종, `bgm_*.wav` 6종, `bgm.wav`(현재 미사용) | `tools/generate_sounds.py`로 직접 합성(외부 샘플 없음, 고정 시드로 재현 가능) | CC0 1.0 |
| `assets/fonts/Jua-Regular.ttf` | Jua 글꼴 | SIL OFL 1.1 (`assets/fonts/Jua-OFL.txt`) |

소리를 다시 만들려면 `python tools/generate_sounds.py`(numpy 필요)를 실행합니다.

패키지 라이선스는 각 배포물의 라이선스를 따릅니다.

## 단계별 기록

- 1~16단계 작업 기록은 [docs/](docs/)의 `stage*_*.md`에 있습니다.
- 예전 README에 있던 단계별 설명(5·6·8·10·11·12단계, 초대 시제품 계약 포함)은 [README 단계별 기록](docs/readme_history.md)으로 옮겼습니다.
- 위 기록들은 작업 당시 상태입니다. 현재 기준은 [마스터 문서](docs/MASTER.md)입니다.
