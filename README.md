# 오늘의 붕어빵

Flutter 기반 붕어빵 게임 저장소입니다. 폴더명은 제품 이름보다 안에서 수행할 개발 작업·보관 자료를 기준으로 정합니다. 전체 자료를 아래 번호 폴더로 관리합니다. 하위 분류 번호는 점으로 연결합니다.

| 번호 | 폴더 | 내용 |
| --- | --- | --- |
| 1 | [1_app_development](1_app_development/README.md) | Flutter 소스·에셋·테스트·Android/iOS·Firebase 서버·개발 도구 |
| 2 | [2_development_plans_and_checklists](2_development_plans_and_checklists/README.md) | 기획·결정·검수·정책·보존 문서 전체 |
| 3 | [3_original_images_and_visual_references](3_original_images_and_visual_references/) | 이미지 원본·제작 자료 |
| 4 | [4_image_generation_results_and_backups](4_image_generation_results_and_backups/) | 이미지 생성 결과·수정 전 백업 |
| 5 | [5_app_store_submission_images](5_app_store_submission_images/) | 스토어 이미지 |
| 6 | [6_previous_builds_and_project_archives](6_previous_builds_and_project_archives/) | 과거 ZIP·APK 보관 자료 |

## 작업별로 어디부터 보는가

| 하려는 작업 | 먼저 볼 곳 |
| --- | --- |
| 게임 실행·기능 개발 | [게임 안내](1_app_development/README.md) → `1_app_development/lib/` |
| 목표 기능·규칙 확인 | [기획 안내](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/README.md) → 요약·상세·결정 문서 |
| 작업 진행 상황 확인 | [체크리스트](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/CHECKLIST.md)와 [진행현황](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/진행현황.md) |
| 저장·경제·UI 테스트 | `1_app_development/test/` |
| 서버 기능 개발 | [서버 안내](1_app_development/firebase/README.md) |
| 그림 수정·교체 | [이미지 원본 안내](3_original_images_and_visual_references/README.md) → [개발 도구](1_app_development/tools/README.md) → `1_app_development/assets/` |
| 과거 그림과 비교 | [작업 결과·백업](4_image_generation_results_and_backups/README.md) |
| 출시 이미지 준비 | [스토어 자료](5_app_store_submission_images/README.md) |
| 과거 버전 확인 | [ZIP·APK 보관](6_previous_builds_and_project_archives/README.md) |

## 개발 시작

Flutter 명령은 저장소 루트가 아닌 `1_app_development`에서 실행합니다.

```bash
cd 1_app_development
flutter pub get
flutter test
flutter run
```

Firebase 함수 개발은 `1_app_development/firebase/functions`에서 Node.js 22로 `npm ci`, `npm test`를 실행합니다. 기획 작업 조회는 저장소 루트에서 `python 1_app_development/tools/planning_tasks.py list`로 실행합니다.

상세 실행·온라인 설정·기능 설명은 [게임 안내](1_app_development/README.md), 문서 전체 목록은 [문서 안내](2_development_plans_and_checklists/README.md)를 참고하세요. 과거 기록은 현재 구현 완료를 뜻하지 않습니다.

## 폴더 관리 기준

최상위 자료 분류는 `번호_이름`, 문서의 하위 분류는 `상위번호.번호_이름` 형식을 사용합니다. Flutter·Android·Xcode·Firebase가 정해진 경로로 읽는 `1_app_development` 내부의 `lib`, `assets`, `test`, `android`, `ios`, `firebase`와 도구 폴더는 호환성을 위해 이름을 유지합니다. 이미지 원본·백업 내부의 파일명과 폴더도 매니페스트와 대응하므로 보존합니다. `.git`은 Git 내부 관리 폴더입니다.

## 현재 신규 게임 소스

main.dart의 신규 Workshop은 초기 팥·추가 슈크림/초코 미션·영업/연습/숙련/6구/재고·손님 판매·수동50레벨·도감 저장 경로다. 구형 코인은 신규 개념이 아니며 실제 복합 결제·검증 황금/광고·친구 연동과 컴파일/실행 검수는 미완료다. 상세는 [18번 연결 범위](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/18_신규게임연결과사용자결정반영.md)를 따른다.

최신 후속 소스·미연결 조건·잔여 작업 5개 묶음: [구매·복구 후속과 남은 양](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/19_구매원자저장과복구후속.md). 실제 실행 완료와 구분합니다.

최신 후속: [온라인·광고·꾸미기 연결과 검수 인계](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/20_온라인광고꾸미기연결과검수인계.md). callable은 소스에 연결했지만 기본 비활성이고 실제 서버 검증 파이프라인/광고 SDK·운영 설정과 실행 검수가 남습니다.
