# 오늘의 붕어빵

기능이나 설정을 추가·변경하기 전에 [MASTER_INDEX.md](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/2.1.3_legacy_code_policies_and_online_setup/MASTER_INDEX.md)(짧은 색인)를 먼저 읽고, 거기서 고른 [MASTER.md](2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/2.1.3_legacy_code_policies_and_online_setup/MASTER.md)의 **관련 장만** 읽어 그 원칙과 체크리스트를 따른다. MASTER.md(약 440KB)와 25번·26번·CHECKLIST 같은 대형 문서는 통째로 읽지 않는다. `grep`으로 장·단계 번호를 찾아 그 부분만 읽는다.

- 설정값·공식·화면 배치·저장 형식을 바꾸면 같은 작업에서 MASTER.md의 해당 부분도 고친다. 기능·파일 지도가 바뀌면 MASTER_INDEX.md도 고친다.
- 문서와 코드가 다르면 코드가 기준이다. 문서를 코드에 맞게 고친다.
- 사용자에게 보이는 글은 한국어로 쓴다.

- 저장소 전체 폴더 구조는 README.md를 따른다. Flutter·에셋 도구 명령은 `1_app_development/`, 서버 명령은 `1_app_development/firebase/functions/`에서 실행한다. 기획 관리 도구는 저장소 루트에서 `python 1_app_development/tools/planning_tasks.py`로 실행한다.

## 실행

- Flutter는 PATH에 없다: `D:\DevMoved\flutter-sdk\bin\flutter.bat` (Git Bash: `/d/DevMoved/flutter-sdk/bin/flutter.bat`).
- 고친 기능의 테스트만 먼저 돌린다(MASTER_INDEX.md 3절의 기능별 테스트). 느린 것을 뺀 `flutter test --exclude-tags slow`는 약 6분, 전체 `flutter test`는 약 20분 걸리므로(2026-11-24 측정, 970개·997개) 전체는 마무리 확인 때 한 번 돌린다.
- Python 도구가 한글 출력에서 실패하면 `PYTHONIOENCODING=utf-8`을 붙인다.

## 지킬 것

- 기준 이미지(`1_app_development/test/goldens/`)는 의도한 화면 변경이고 사용자가 확인했을 때만 다시 만든다. 다시 만들기 전에 실패한 테스트가 남긴 비교 이미지(`test/failures/*_maskedDiff.png`·`*_testImage.png`)를 직접 열어 보고, 바뀐 화면과 바뀐 이유를 사용자에게 보여 준다. 고치려던 화면 말고 다른 화면의 기준 이미지가 바뀌면 다시 만들지 말고 원인을 먼저 찾는다. 테스트 기대값·허용치를 낮추지 않는다.
- 자주 바뀌는 화면·중심 파일(`lib/ui/workshop_page.dart`, `lib/ui/night_home.dart`, `lib/ui/shop_panel.dart`, `lib/ui/public_menus.dart`, `lib/workshop_controller*.dart`, `lib/ui/pixel_sprites.dart`)은 **한 번에 한 작업(세션·브랜치)만** 고친다. 여러 작업을 나눠 돌릴 때는 이 파일들을 어느 작업이 맡는지 먼저 정하고, 맡지 않은 작업은 건드리지 않는다.
- 새 기능은 계산을 `*_rules.dart` 같은 순수 함수와 그 테스트로 먼저 만들고, 컨트롤러는 그것을 부르기만 한다.
- 저장 형식은 옛 버전 읽기를 유지한다(MASTER_INDEX.md 4절).
- 예전 클리커 코드(GameController 쪽)는 계정·온라인·결제를 아직 맡고 있다. 지우거나 옮기기 전에 승인을 받는다.
- `4_image_generation_results_and_backups/26_feedback_generated/`는 다른 세션이 쓰는 폴더라 커밋하지 않는다(.gitignore).
