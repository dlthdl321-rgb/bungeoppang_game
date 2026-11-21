# 개발 도구

Flutter 앱과 관련된 도구입니다. 원칙적으로 `1_app_development/`을 작업 디렉터리로 사용합니다.

| 작업 | 도구 | 실행·확인 방법 |
| --- | --- | --- |
| 기획 작업 조회 | `planning_tasks.py` | 저장소 루트에서 `python 1_app_development/tools/planning_tasks.py list` |
| 기획 상태 문서 생성 | `planning_tasks.py` | 저장소 루트에서 `python 1_app_development/tools/planning_tasks.py render` |
| 효과음 생성 | `generate_sounds.py` | `1_app_development`에서 `python tools/generate_sounds.py`. 효과음 8개(tap·purchase·reward·levelup·result_*)를 44.1kHz 한 계열로 합성하고 크기 차를 2dB 안으로 맞춤 |
| 배경음악 반복본 만들기 | `prepare_bgm.py` | `1_app_development`에서 `python tools/prepare_bgm.py`. `../7_music/Warm Bungeoppang Stall.mp3`(읽기만)를 끝 3초 교차 페이드·−6dB·OGG로 바꿔 `assets/audio/bgm_warm_stall.ogg`를 씀. `--check`는 이음매 측정(앞뒤 크기 차 ≤3dB, 샘플 차 ≤0.02, 이음매 근처 큰 틈 0). 필요: `pip install --user numpy imageio-ffmpeg` |
| 녹음 소리를 이음매 없는 반복으로 | `make_seamless_loop.py` | `1_app_development`에서 `python tools/make_seamless_loop.py <받은 파일> --seconds 20`(기본 출력 `assets/audio/sizzle_loop.wav`). 구간 고르기(`--start`·`--end`초)·앞뒤 무음 자르기·느린 크기 변화 고르기(`--flatten`초)·끝 2초 교차 페이드(이웃 샘플 차가 가장 작은 곳에서 이음)·크기 −25dB 맞춤·튀는 소리만 −3dBFS로 누름·태그 없는 WAV. `--check`로 이음매 검사. **지금 굽는 소리**는 `python tools/make_seamless_loop.py ../4_image_generation_results_and_backups/26_feedback_generated/sounds/crepe_making_117602_preview.mp3 --start 22.8 --end 41.3 --seconds 16.4 --flatten 2`로 만든 녹음본 |
| 픽셀 그림 생성 | `draw_pixel_assets.py` | `1_app_development`에서 실행. 기존 에셋을 갱신하므로 변경 내용을 확인 |
| 아바타 조각·좌표 관리 | `avatar_layers.py` | `1_app_development`에서 `python tools/avatar_layers.py --help` |
| 원본 이미지 적용 | `apply_extra_art.py`, `concept_*.py` | `3_original_images_and_visual_references`의 원본을 읽고 앱 에셋을 갱신 |
| 25번 그림 적용 | `apply_25_art.py` | `1_app_development`에서 `python tools/apply_25_art.py <25_generated 폴더> --preview`. 생성 원본(읽기만)을 줄여 `assets/images/stove_empty`(빈 굽는 판 4종, 원래 화로에 맞춘 배율·위치 `STOVE_FIT`, `--measure`로 다시 잼)·`stove_fish`(원래 화로의 붕어빵만)·`cook/piping_bag_*`·`fx/overflow_*`·`fx/flip_ring*`을 만듦. 미리보기 `build/apply_25_art_preview.png` 26번 4-5단계: `--only room --only title --only stall16`(26_feedback_generated 폴더)로 꾸미기 방 `ui/wardrobe_room`·제목 붕어빵 `ui/title_fish`·등불/밤낮 칸 그림. 25번 22번: `--only intro`로 기능 소개 카드 그림 `ui/intro_<id>` 8장(160×120, 64색) |
| 아바타 맨 바탕 정규화 | `normalize_avatar_base.py` | `1_app_development`에서 `python tools/normalize_avatar_base.py`. 25번 23번 생성 바탕(읽기만)을 성별마다 skin1 하나의 균일 배율 + 평행 이동으로 1120×2080·공통 좌표(발바닥 마지막 행 2079, 눈 중심 = 4배 앵커, 입 오차는 기록)에 놓고 skin2·3은 skin1 모양에 피부색만 다시 칠함. 결과 `../4_image_generation_results_and_backups/26_feedback_generated/23_avatar_base/normalized/<성별>/base_skin1~3.png`·`report.json`·비교 시트 `compare.png`. 그다음 `python tools/avatar_v2.py align trim atlas`가 이 정규화본을 게임 `assets/images/avatar_v2/`로 줄여 넣음 |
| 꾸미기 칸 임시 아이콘 | `make_cosmetic_icons.py` | `1_app_development`에서 `python tools/make_cosmetic_icons.py --preview`. 지금 아바타 레이어에서 아이템만 잘라 `assets/images/cosmetic_icons/<id>.png`(64×64) + `none.png`. 25번 31번 그림이 오면 쓰지 않음. 미리보기 `build/cosmetic_icons_preview.png` |
| 알림 아이콘 적용 | `notification_icon.py` | `1_app_development`에서 `python tools/notification_icon.py <원본 ic_stat_customer.png> --preview`. 25번 21번 생성 원본(읽기만)을 흰색·알파 0/255로 정리해 `android/app/src/main/res/drawable-<dpi>/ic_stat_customer.png`(24~96px)를 만듦. 미리보기 `build/notification_icon_check.png` |
| 임시 빈 굽는 판(예전) | `empty_griddle.py` | 그린 그림으로 대체됨. 실행하면 `build/stove_empty_temp`에만 씀(에셋을 덮어쓰지 않음). 붕어빵 마스크 함수는 `apply_25_art.py`가 씀 |
| 행주 윗변 측정 | `towel_top.py` | `1_app_development`에서 `python tools/towel_top.py`. 배경별 빨간 체크 행주 윗변 행을 출력, `NightStallPainter.towelTops`에 옮김. 새 생성 배경(빛·색이 그림마다 다름)은 자동 측정이 맞지 않아 `apply_26_home_art.py`의 `TOWEL_AT_335` 표(손으로 잰 값)를 씀 |
| 26번 홈 손님·낮춘 배경 적용 | `apply_26_home_art.py` | `1_app_development`에서 `python tools/apply_26_home_art.py ../4_image_generation_results_and_backups/26_feedback_generated --preview`(`--only customers`·`--only backgrounds`, `--measure`). 손님 36장 → `assets/images/customer/<id>_<normal·happy·sad>.png`(256×320, 세 표정 같은 자리), 배경 14장 → `assets/images/bg_low/<id>.png`(335×762, 행주 윗변 y524로 옮김). 미리보기 `build/apply_26_home_art_preview.png`. 25번 6번·20번, 26번 4-1단계 |
| 26번 6구 닫힌 판·열린 판 적용 | `apply_26_stoves.py` | `1_app_development`에서 `python tools/apply_26_stoves.py ../4_image_generation_results_and_backups/26_feedback_generated --preview`(`--measure`로 맞춤 값 다시 잼, 약 10분). 생성 원본(읽기만) → `assets/images/stove_closed/<화로>.png`(941×470, 생성본 전체를 기존 판의 바닥·경첩에 맞춤 `CLOSED_FIT`), `stove_open/<화로>.png`(941×700, 아래 941×470은 `stove_empty` 그대로, 생성본의 뚜껑만 위 230px에 `OPEN_FIT`). 미리보기 `build/apply_26_stove_preview.png`. 25번 7번, 26번 4-2단계 F8 |
| 25번 62번 재료 아이콘 적용 | `apply_62_ingredient_icons.py` | `1_app_development`에서 `python tools/apply_62_ingredient_icons.py ../4_image_generation_results_and_backups/26_feedback_generated --only shop`(상점 재료 탭: `ing_*` 7·`prem_*` 4·`tab_ingredients`) 또는 `--only prep`(통 4·`btn_prep`). 생성본이 이미 72×72 도트라 크기·알파(0/255)만 확인하고 그대로 `assets/images/icons/`에 복사. 새 이름은 `PixelSprites.iconNames`에 등록. 재료 타이쿤 C |
| 조리 컷 위치 맞추기 | `align_cook_cuts.py` | `1_app_development`에서 `python tools/align_cook_cuts.py`(`--check`는 보고만, 맞지 않으면 종료 코드 1). `assets/images/cook/girl_1~6.png`의 작업대(나무 상자)를 1번 자리로 정수 픽셀 이동 + 공통 (−24, −2), `avatar_layers.json` 얼굴 기준점도 같이 옮기고 `avatar_layers.py write`로 Dart 갱신. 결과 `tools/cook_cut_alignment.json`(남자 3.3 원본은 값만), 비교 `build/cook_cut_alignment_before_after.png`. 이미 맞춘 그림이면 아무것도 바꾸지 않음. 26번 4-2단계 F9 |
| 하단 메뉴 아이콘 여백 자르기 | `fit_nav_icons.py` | `1_app_development`에서 `python tools/fit_nav_icons.py --preview`. `icons/menu·skill·tab_outfit·shop.png`(원본 유지)의 여백을 잘라 긴 변 88로(2배 이상이면 정수배 최근접) `icons/nav_menu·nav_skill·nav_skins·nav_shop.png`(96×96). 미리보기 `build/fit_nav_icons_preview.png`. 25번 14번, 26번 4-2단계 F10 |
| 화면 캡처 검증 | `preview_*_test.dart` | `1_app_development`에서 `flutter test tools/해당파일.dart` |
| Android 에뮬레이터 실행 | `run_android_emulator.ps1` | Windows 전용. `1_app_development` 기준 APK 경로 사용 |
| 카카오 키 해시 계산 | `kakao_key_hash.ps1 -Sha1 "AA:BB:…"` | SHA-1 지문을 카카오 콘솔용 키 해시로 바꿈(23번 7단계, `online_setup.md` 8-2) |
| 녹화 영상 피드백 정리 | `video_feedback.py` | 저장소 루트에서 `python 1_app_development/tools/video_feedback.py <영상> [출력 폴더]`. 말 받아쓰기(시간 포함) `transcript.md`, 말한 구간 장면 사진 `frames/`, 10초 간격 사진 `overview/`를 만듦. 필요: `pip install --user faster-whisper imageio-ffmpeg`. 영상·결과물은 커밋하지 않음 |
| 추가 이미지 작업 목록 | `build_image_jobs_2.py` | `python tools/build_image_jobs_2.py --prompt 문서경로`로 입력 문서를 명시 |
| 생성 이미지 등록 | `record_image_2.py` | 인덱스와 이미지 경로를 입력하면 `3_original_images_and_visual_references`의 생성 기록을 갱신 |

기획 도구 외 이미지 제작 도구는 Pillow·numpy 등 각 파일의 import에 필요한 패키지를 사용합니다. 실행하면 그림·좌표·산출물이 바뀌는 도구가 있으므로 단순 조회 목적으로 실행하지 않습니다.

## 임시 수치 변경

저장소 루트에서 `python 1_app_development/tools/development_balance.py`로 단일 JSON 설정을 검증하고14번 문서를 생성합니다. `--check`는 문서 일치만 확인합니다. 게임 실행·밸런스 검수·실제 서버 상품 변경은 하지 않습니다.

지금 굽기 루프(`assets/audio/sizzle_loop.wav`)는 **녹음본**입니다(Freesound 117602 'Crepe Making', CC0, 2026-11-18 적용, 위 `make_seamless_loop.py` 줄의 명령). `python 1_app_development/tools/generate_cooking_sound.py`는 예비용 합성(외부 샘플 없는 고정 seed, 20초 44.1kHz 원형 합성, 26번 4-6단계)으로 남겨 두었으며, 기본 출력으로 실행하면 녹음본을 덮어쓰므로 비교할 때는 `--output`을 다른 곳으로 줍니다. 오디오 기본값 Dart도 development_balance.py의 생성물입니다.

손님 글/인물 원본은 config/customer_content.json, 숫자는 config/development_balance.json입니다. 저장소 루트에서 `python 1_app_development/tools/customer_content.py`로 Dart를 생성하고 `--check`로 일치를 검사합니다. 생성물은 직접 수정하지 않습니다. 앱/테스트 실행 도구가 아닙니다.
