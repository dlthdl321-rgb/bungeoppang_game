# 오늘의 붕어빵

Flutter 기반 붕어빵 게임 저장소입니다. 전체 자료를 아래 번호 폴더로 관리합니다. 하위 분류 번호는 점으로 연결합니다.

| 번호 | 폴더 | 내용 |
| --- | --- | --- |
| 1 | [1_game_app](1_game_app/README.md) | Flutter 소스·에셋·테스트·Android/iOS·Firebase 서버·개발 도구 |
| 2 | [2_design_docs](2_design_docs/README.md) | 기획·결정·검수·정책·보존 문서 전체 |
| 3 | [3_art_sources](3_art_sources/) | 이미지 원본·제작 자료 |
| 4 | [4_art_backups](4_art_backups/) | 이미지 생성 결과·수정 전 백업 |
| 5 | [5_store_assets](5_store_assets/) | 스토어 이미지 |
| 6 | [6_release_archives](6_release_archives/) | 과거 ZIP·APK 보관 자료 |

## 작업별로 어디부터 보는가

| 하려는 작업 | 먼저 볼 곳 |
| --- | --- |
| 게임 실행·기능 개발 | [게임 안내](1_game_app/README.md) → `1_game_app/lib/` |
| 목표 기능·규칙 확인 | [기획 안내](2_design_docs/2.1_planning/README.md) → 요약·상세·결정 문서 |
| 작업 진행 상황 확인 | [체크리스트](2_design_docs/2.1_planning/CHECKLIST.md)와 [진행현황](2_design_docs/2.1_planning/진행현황.md) |
| 저장·경제·UI 테스트 | `1_game_app/test/` |
| 서버 기능 개발 | [서버 안내](1_game_app/firebase/README.md) |
| 그림 수정·교체 | [이미지 원본 안내](3_art_sources/README.md) → [개발 도구](1_game_app/tools/README.md) → `1_game_app/assets/` |
| 과거 그림과 비교 | [작업 결과·백업](4_art_backups/README.md) |
| 출시 이미지 준비 | [스토어 자료](5_store_assets/README.md) |
| 과거 버전 확인 | [ZIP·APK 보관](6_release_archives/README.md) |

## 개발 시작

Flutter 명령은 저장소 루트가 아닌 `1_game_app`에서 실행합니다.

```bash
cd 1_game_app
flutter pub get
flutter test
flutter run
```

Firebase 함수 개발은 `1_game_app/firebase/functions`에서 Node.js 22로 `npm ci`, `npm test`를 실행합니다. 기획 작업 조회는 저장소 루트에서 `python 1_game_app/tools/planning_tasks.py list`로 실행합니다.

상세 실행·온라인 설정·기능 설명은 [게임 안내](1_game_app/README.md), 문서 전체 목록은 [문서 안내](2_design_docs/README.md)를 참고하세요. 과거 기록은 현재 구현 완료를 뜻하지 않습니다.

## 폴더 관리 기준

최상위 자료 분류는 `번호_이름`, 문서의 하위 분류는 `상위번호.번호_이름` 형식을 사용합니다. Flutter·Android·Xcode·Firebase가 정해진 경로로 읽는 `1_game_app` 내부의 `lib`, `assets`, `test`, `android`, `ios`, `firebase`와 도구 폴더는 호환성을 위해 이름을 유지합니다. 이미지 원본·백업 내부의 파일명과 폴더도 매니페스트와 대응하므로 보존합니다. `.git`은 Git 내부 관리 폴더입니다.
