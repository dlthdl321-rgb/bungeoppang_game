# 1단계: 홈 화면 재현

## 공개 근거와 반영 범위

2026-09-29에 아래 공개 후기와 첫 번째 글의 홈 스크린샷을 열어 확인했다. 스크린샷은 관찰용으로만 사용했으며 앱·골든·에셋에 포함하지 않았다.

- [당메: 붕어빵 게임 후기 및 화면](https://d-dangme-b.tistory.com/entry/당근마켓-붕어빵-게임-공략-및-레벨-정보-현금-7000원-인출-가이드)
- [세종라이프 로그: 플레이 구조 기록](https://dailysejong.tistory.com/entry/당근마켓-붕어빵게임-공략-총정리레벨-10-달성)

홈 상단 생산 재화와 생산 속도, 중앙의 큰 황금 붕어빵, 오른쪽 상점·꾸미기·랭킹, 하단 레벨 진행이라는 정보 계층을 반영했다. 왼쪽 일일 미션과 친구 초대, 이벤트 안내는 사용자의 1단계 요구에 맞춰 배치했다. 그림과 문구·색상은 직접 작성했다. 원작과 픽셀 단위로 일치하는 복제는 아니다.

## 구현

- 하단 NavigationBar 제거. 기존 상점·꾸미기는 우측 메뉴에서 열리는 시트로 연결하며 실제 구매·장착을 유지한다.
- 상단 보유 재화, 누적 생산, 클릭당·초당 생산. 재화를 누르면 생략 없는 BigInt 생산 기록을 확인한다.
- CustomPainter로 야간 골목·전구·노점 및 황금 붕어빵을 렌더링한다.
- 탭에 반응하는 크기 변화·빛·상승/소멸 숫자. 단일 ticker, 최대 8개 숫자, 진동 최소 간격 80ms. 입력 생산량 자체는 생략하지 않는다.
- 효과가 끝나면 ticker를 정지한다. 길게 누르기 timer는 하나만 유지하고, 손을 떼거나 앱 비활성화·위젯 해제 시 취소한다.
- 앱 모션 줄이기 및 시스템 disableAnimations/accessibleNavigation을 적용한다. 모션을 줄일 때 위치·크기·빛 변화 없이 정적인 획득량을 표시한다.
- 기본 글자 크기에는 한 화면 구조, 확대 글자 및 작은 높이에는 세로 스크롤을 사용한다. 터치·키보드·접근성 굽기 동작을 제공한다.
- 레벨 진행은 기존 누적/자동생산 복합 목표 중 부족한 조건을 기준으로 표시한다. BigInt 정수 계산 뒤 화면 막대 비율만 double로 변환한다.
- 이벤트 카운트다운은 주입된 TimeService UTC를 사용하고 시작 전/진행 중/종료를 구분한다.
- 일일 미션·랭킹·초대는 명확히 표시된 모의 진입 화면이다. 보상 지급·전송·실제 순위는 이번 단계에 포함하지 않는다.
- 이벤트 일정·선착순 수량·보상 안내는 `lib/home_presentation.dart`의 모의 설정이다. 실제 이벤트가 진행 중이라는 의미가 아니다.

## 저장 및 후속 단계

이번 UI 단계에는 신규 영속 상태가 없으므로 기존 JSON formatVersion 1, SQLite 테이블 및 BigInt 문자열 저장을 유지한다. 일일 미션·초대·코인 등 신규 저장 필드를 도입하는 단계에서 스키마 버전 추가와 마이그레이션을 진행해야 한다. 홈 진입을 위해 기존 저장 데이터를 초기화하거나 변환하지 않는다. 기존 10초 주기 저장 정책도 유지한다.

경제 성장 수치·미션 정의·레벨 보상은 기존 시제품 값이다. 억·조 표시는 지원하지만 원작 경제 밸런스 재현은 이번 단계에서 완료하지 않았다.

## 변경 파일

- `lib/ui/game_app.dart`: 홈 연결, 우측 메뉴 시트, 모의 진입 안내, 스크롤 설정, 앱 복귀 다이얼로그의 Navigator 컨텍스트.
- `lib/ui/night_home.dart`: 반응형 홈 정보 계층과 세로 메뉴.
- `lib/ui/bake_target.dart`: 입력·제한된 탭 효과·접근성·생명주기 처리.
- `lib/ui/night_stall_painter.dart`, `lib/ui/fish_painter.dart`: 자체 제작 그림.
- `lib/home_presentation.dart`: 이벤트 설정·카운트다운·레벨 표시 계산.
- `test/widget_test.dart`, `test/home_presentation_test.dart`, `test/home_golden_test.dart`, `test/goldens/`: 위젯·시간 경계·진행률·골든 검증.
- `tools/preview_home_test.dart`: 로컬 한글 폰트를 이용한 미리보기 생성. 폰트는 앱으로 복사하지 않는다.
- `docs/stage1_home.md`, `README.md`: 범위·검증·실행 안내.

## 재현 명령

이 PC에서는 프로젝트의 영문 드라이브 매핑 `B:` 및 `C:\flutter-sdk\bin`을 사용한다.

```powershell
# B:에서 실행
& C:\flutter-sdk\bin\dart.bat format lib test tools\preview_home_test.dart
& C:\flutter-sdk\bin\flutter.bat analyze
& C:\flutter-sdk\bin\flutter.bat test
$env:GRADLE_USER_HOME = 'C:\GradleCache'
$env:JAVA_TOOL_OPTIONS = '-Dfile.encoding=UTF-8'
& C:\flutter-sdk\bin\flutter.bat build apk --debug
```

골든은 Flutter 테스트 기본 폰트로 UI 배치·자체 그림의 회귀를 검출한다. 실제 한글 글리프 모양을 검증하지는 않는다. 의도적으로 화면을 변경했을 때만 `flutter test --update-goldens test/home_golden_test.dart`로 재생성한다.

로컬 한글 미리보기:

```powershell
flutter test tools/preview_home_test.dart --dart-define=PREVIEW_FONT=C:/Windows/Fonts/malgun.ttf
```

결과는 `build/preview/home_390x844.png`이며 고정 시각·예시 재화의 위젯 렌더링이다. 실기기 스크린샷이 아니다.

## 검증 결과

- `dart format --output=none --set-exit-if-changed lib test tools/preview_home_test.dart`: 20개 파일, 변경 필요 0개.
- `flutter analyze`: No issues found.
- `flutter test`: 31/31 통과. 기존 경제·저장·컨트롤러 테스트 유지. 골든 3개는 생성 후 업데이트 옵션 없이 다시 비교해 통과했다.
- 360×800, 390×844, 412×915 및 각 크기의 텍스트 1.5배·2배에서 overflow 예외 없음. 기본 크기에서는 안전 영역 안에 이벤트 안내가 들어오고 모든 메뉴가 터치 가능함을 검사했다.
- 탭 200회 생산량 보존, 플로팅 효과 8개 상한·종료 후 제거, 프레임별 DB 저장 부재, 앱/시스템 모션 줄이기, 길게 누르기 생명주기 취소, 접근성 동작, 상점 구매→홈 갱신, TimeService 카운트다운 및 시작/종료 경계 통과.
- `flutter build apk --debug`: 성공. `build/app/outputs/flutter-apk/app-debug.apk`, 166,032,356 bytes.
- `apksigner verify --verbose`: APK Signature Scheme v2 검증 성공.
- APK SHA-256: `959B06F57741AF076FE3AE7BCFEDC218FC4C28E5108704C509413818762B1A9E`.
- `adb devices`: 연결된 기기 없음. 실기기 실행 결과로 간주하지 않는다.

## 잔여 위험

- Android 기기가 연결되지 않아 설치·실기기 FPS·장시간 메모리·진동·네이티브 SQLite 동작은 검증하지 못했다.
- 200회 빠른 입력 테스트는 재화 누락, 효과 수 상한, 프레임별 저장 부재를 확인하는 회귀 테스트이며 실제 기기의 60fps 보장은 아니다.
- 오프라인 정산, 저장 실패와 손상 복구의 기존 설계 한계는 별도 후속 검증 대상이다.
