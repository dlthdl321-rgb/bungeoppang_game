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
| 25번 그림 적용 | `apply_25_art.py` | `1_app_development`에서 `python tools/apply_25_art.py <25_generated 폴더> --preview`. 생성 원본(읽기만)을 줄여 `assets/images/stove_empty`(빈 굽는 판 4종, 원래 화로에 맞춘 배율·위치 `STOVE_FIT`, `--measure`로 다시 잼)·`stove_fish`(원래 화로의 붕어빵만)·`cook/piping_bag_*`·`fx/overflow_*`·`fx/flip_ring*`을 만듦. 미리보기 `build/apply_25_art_preview.png` |
| 알림 아이콘 적용 | `notification_icon.py` | `1_app_development`에서 `python tools/notification_icon.py <원본 ic_stat_customer.png> --preview`. 25번 21번 생성 원본(읽기만)을 흰색·알파 0/255로 정리해 `android/app/src/main/res/drawable-<dpi>/ic_stat_customer.png`(24~96px)를 만듦. 미리보기 `build/notification_icon_check.png` |
| 임시 빈 굽는 판(예전) | `empty_griddle.py` | 그린 그림으로 대체됨. 실행하면 `build/stove_empty_temp`에만 씀(에셋을 덮어쓰지 않음). 붕어빵 마스크 함수는 `apply_25_art.py`가 씀 |
| 행주 윗변 측정 | `towel_top.py` | `1_app_development`에서 `python tools/towel_top.py`. 배경별 빨간 체크 행주 윗변 행을 출력, `NightStallPainter.towelTops`에 옮김 |
| 화면 캡처 검증 | `preview_*_test.dart` | `1_app_development`에서 `flutter test tools/해당파일.dart` |
| Android 에뮬레이터 실행 | `run_android_emulator.ps1` | Windows 전용. `1_app_development` 기준 APK 경로 사용 |
| 카카오 키 해시 계산 | `kakao_key_hash.ps1 -Sha1 "AA:BB:…"` | SHA-1 지문을 카카오 콘솔용 키 해시로 바꿈(23번 7단계, `online_setup.md` 8-2) |
| 녹화 영상 피드백 정리 | `video_feedback.py` | 저장소 루트에서 `python 1_app_development/tools/video_feedback.py <영상> [출력 폴더]`. 말 받아쓰기(시간 포함) `transcript.md`, 말한 구간 장면 사진 `frames/`, 10초 간격 사진 `overview/`를 만듦. 필요: `pip install --user faster-whisper imageio-ffmpeg`. 영상·결과물은 커밋하지 않음 |
| 추가 이미지 작업 목록 | `build_image_jobs_2.py` | `python tools/build_image_jobs_2.py --prompt 문서경로`로 입력 문서를 명시 |
| 생성 이미지 등록 | `record_image_2.py` | 인덱스와 이미지 경로를 입력하면 `3_original_images_and_visual_references`의 생성 기록을 갱신 |

기획 도구 외 이미지 제작 도구는 Pillow·numpy 등 각 파일의 import에 필요한 패키지를 사용합니다. 실행하면 그림·좌표·산출물이 바뀌는 도구가 있으므로 단순 조회 목적으로 실행하지 않습니다.

## 임시 수치 변경

저장소 루트에서 `python 1_app_development/tools/development_balance.py`로 단일 JSON 설정을 검증하고14번 문서를 생성합니다. `--check`는 문서 일치만 확인합니다. 게임 실행·밸런스 검수·실제 서버 상품 변경은 하지 않습니다.

굽기 루프 원본은 `python 1_app_development/tools/generate_cooking_sound.py`로 재생성합니다(저장소 루트 기준). 외부 샘플 없는 고정 seed 합성, CC0이며 실행하면 해당 WAV만 갱신합니다. 오디오 기본값 Dart도 development_balance.py의 생성물입니다.

손님 글/인물 원본은 config/customer_content.json, 숫자는 config/development_balance.json입니다. 저장소 루트에서 `python 1_app_development/tools/customer_content.py`로 Dart를 생성하고 `--check`로 일치를 검사합니다. 생성물은 직접 수정하지 않습니다. 앱/테스트 실행 도구가 아닙니다.
