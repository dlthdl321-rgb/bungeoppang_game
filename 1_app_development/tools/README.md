# 개발 도구

Flutter 앱과 관련된 도구입니다. 원칙적으로 `1_app_development/`을 작업 디렉터리로 사용합니다.

| 작업 | 도구 | 실행·확인 방법 |
| --- | --- | --- |
| 기획 작업 조회 | `planning_tasks.py` | 저장소 루트에서 `python 1_app_development/tools/planning_tasks.py list` |
| 기획 상태 문서 생성 | `planning_tasks.py` | 저장소 루트에서 `python 1_app_development/tools/planning_tasks.py render` |
| 효과음·음악 생성 | `generate_sounds.py` | `1_app_development`에서 `python tools/generate_sounds.py` |
| 픽셀 그림 생성 | `draw_pixel_assets.py` | `1_app_development`에서 실행. 기존 에셋을 갱신하므로 변경 내용을 확인 |
| 아바타 조각·좌표 관리 | `avatar_layers.py` | `1_app_development`에서 `python tools/avatar_layers.py --help` |
| 원본 이미지 적용 | `apply_extra_art.py`, `concept_*.py` | `3_original_images_and_visual_references`의 원본을 읽고 앱 에셋을 갱신 |
| 화면 캡처 검증 | `preview_*_test.dart` | `1_app_development`에서 `flutter test tools/해당파일.dart` |
| Android 에뮬레이터 실행 | `run_android_emulator.ps1` | Windows 전용. `1_app_development` 기준 APK 경로 사용 |
| 추가 이미지 작업 목록 | `build_image_jobs_2.py` | `python tools/build_image_jobs_2.py --prompt 문서경로`로 입력 문서를 명시 |
| 생성 이미지 등록 | `record_image_2.py` | 인덱스와 이미지 경로를 입력하면 `3_original_images_and_visual_references`의 생성 기록을 갱신 |

기획 도구 외 이미지 제작 도구는 Pillow·numpy 등 각 파일의 import에 필요한 패키지를 사용합니다. 실행하면 그림·좌표·산출물이 바뀌는 도구가 있으므로 단순 조회 목적으로 실행하지 않습니다.

## 임시 수치 변경

저장소 루트에서 `python 1_app_development/tools/development_balance.py`로 단일 JSON 설정을 검증하고14번 문서를 생성합니다. `--check`는 문서 일치만 확인합니다. 게임 실행·밸런스 검수·실제 서버 상품 변경은 하지 않습니다.

굽기 루프 원본은 `python 1_app_development/tools/generate_cooking_sound.py`로 재생성합니다(저장소 루트 기준). 외부 샘플 없는 고정 seed 합성, CC0이며 실행하면 해당 WAV만 갱신합니다. 오디오 기본값 Dart도 development_balance.py의 생성물입니다.

손님 글/인물 원본은 config/customer_content.json, 숫자는 config/development_balance.json입니다. 저장소 루트에서 `python 1_app_development/tools/customer_content.py`로 Dart를 생성하고 `--check`로 일치를 검사합니다. 생성물은 직접 수정하지 않습니다. 앱/테스트 실행 도구가 아닙니다.
