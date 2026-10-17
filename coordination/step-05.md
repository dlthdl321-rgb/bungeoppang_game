# 5단계 — 실행 환경·오디오·1차 통합

2026-10-18 KST, 직원5. 기준 `9108513a89e83d4dd8f6c0772f6554c844d1e8a0`.
브랜치 `employee5/audio-integration`, worktree `C:/Users/이소이/Desktop/Git/bungeoppang-step-05`.
원본 main의 미커밋 결정 문서 및 android/build/firebase/ios는 이동·삭제·커밋하지 않았다.
CLAUDE.md와 MASTER.md를 적용했다. AGENTS.md는 발견하지 못했다.

## 통합 내역

| 담당 | 확인한 원본 커밋 | 이 브랜치의 적용 커밋 |
| --- | --- | --- |
| 5 오디오 | 자체 작업 | 063d218 |
| 1 저장·복구 | 73fa6a5 | 22e15a2 |
| 2 제작·6구 | 8ffac0b | 06b7ee3 |
| 3 주문·재고·손님 | d8ffe9a (최종 2503e41과 마지막 공백만 다름) | 97fddc6 |

MASTER.md 끝의 병렬 추가는 양쪽 설명을 보존했다. controller 저장 part/생명주기와 제작 캐시, 주문 ID 납품, UI 센서/판매 버튼을 함께 보존했다. 공통 controller 테스트의 Map fixture 타입 수정 충돌은 직원1의 명시 타입 리터럴을 유지했다. 직원2 브랜치가 이후 직원1 커밋을 적용한 것은 중복 적용하지 않는다.

## P2-001~003 오디오

기존 독립 BGM 선택/저장·실패 롤백, 자동 배경 연동, 굽기 전용 플레이어/직렬 큐를 재작성하지 않았다. 설정 기본값·음량·저장 스키마 변경 없음.

- WorkshopController.adPaused 읽기 getter만 추가했다. 광고 준비/서버 조회 전체가 아닌 실제 광고 표시 구간에만 출력 정지를 연결한다.
- GameApp이 앱 전경과 광고 표시를 함께 평가한다. 광고 종료가 백그라운드에서 발생하거나 광고 중 앱이 복귀해도 조기 재생하지 않는다. 현재 굽기 소스를 갱신한 뒤 재개한다.
- 스토리에서는 기존 gameplayPaused로 굽기 소스가 비워지며 BGM은 독립 설정을 유지한다. 일반 효과음은 전경/광고 차단을 따른다.
- 실제 굽기: 큰 틀 CookingPhase.cooking, 또는 큰 틀이 없고 6구 표시·영업 가능·실제 cookingSourceIds가 있는 경우다. 영업 가능 시계는 controller.now()를 사용한다.
- AudioplayersAudio는 중단 시 이미 재생 중인 효과음의 stop handle을 호출하고, 중단 전에 시작 요청했지만 늦게 반환된 효과음도 revision을 비교해 중단한다. BGM/굽기의 기존 단일 플레이어와 revision 큐는 유지한다.
- 새 step05_audio_test는 광고와 앱 inactive/resumed가 겹치는 두 순서 및 중단 중 SFX 차단을 검사한다. 실제 Android 청음과 다르다.

## 환경과 명령

앱 명령은 `1_app_development`, 서버는 `1_app_development/firebase/functions`, 기획 도구는 저장소 루트에서 실행한다.

- Flutter `C:/flutter-sdk/bin/flutter.bat` 3.47.5, Dart 3.13.4. PATH에 없으므로 전체 경로 사용.
- `PUB_CACHE=C:/PubCacheBungeoppang`; `flutter pub get --offline` 성공. 직원1 테스트용 sqflite_common_ffi 의존성을 통합했다.
- Android SDK `C:/Android/sdk`, platform/build-tools 36.0.0, JDK17.0.20. 일부 SDK 라이선스 미승인. Android 연결 기기 없음. Windows 빌드용 Visual Studio 없음.
- 한글 사용자 경로에서 Gradle wrapper 실행 경로가 `???`로 깨져 ClassNotFoundException 발생. `C:/Temp/bungeoppang-step05` junction을 앱 디렉터리에 연결해 재시도했다. junction은 저장소 산출물이 아니다.
- Node v24.19.0/npm11.17.0. 서버 package.json 요구 Node22와 다르며 npm 설치 시 EBADENGINE 경고. Node22 운영 검증과 구분한다.
- `flutter doctor -v`는 위 경고를 보고했다. 라이선스 동의/배포/운영 gate 활성화는 수행하지 않았다.

## 오류 구분

- 기준 커밋에 이미 있던 premium_controller.dart의 OnlineBackend/WorkshopTransport 교차 인터페이스 타입 승격 오류2개: nullable transport 참조를 명시적으로 만들어 수정. 인증 계정 재확인 동작 유지.
- 기존 development_rules_test.dart의 dynamic Map.addAll fixture 오류는 직원2·3 인계에 기록되어 있다. 전체 검증에서 재확인한다.
- 신규 step05 테스트의 void lifecycle 메서드 await는 이번 작업 오류였으며 제거했다.
- 한글 경로 분석/테스트 최초 실행은 로딩 지연으로 중단했으므로 통과 기록이 아니다.

## 검증 확정 기록

최종 명령·종료 코드·개수는 실행 완료 후 아래에 기록한다. 소스 존재를 실행 통과나 실기기 검수로 간주하지 않는다.

## 남은 외부 검수

Android 실제 청음, 전화/오디오 포커스 중단, Bluetooth 전환, 광고 SDK 표시·닫힘·실패, 앱 복귀/강제 종료 후 SQLite 디스크 검수는 미실행이다. 정책 단위/위젯 테스트로 대체 완료 판정하지 않는다. 실제 AdMob SDK는 미설치이며 운영 서비스는 기본 OFF다. Firebase/AdMob/서명 키 등 외부 연결은 직원4 인계와 승인 범위를 따라야 한다. 비밀값은 기록하지 않는다.

2차 공통 기준은 직원4 적용과 최종 검증 후 확정한다. 그 전까지 이 문서는 1~3단계 통합 중간 기록이다.
