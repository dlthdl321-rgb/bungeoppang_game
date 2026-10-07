# 자료 찾기 안내

[저장소 첫 화면](../README.md)

## 게임에 적용된 이미지

| 폴더 | 내용 |
| --- | --- |
| [app/](../assets/images/app/) | 앱 아이콘 |
| [avatar/](../assets/images/avatar/) | 사장님 캐릭터·꾸미기 |
| [bg/](../assets/images/bg/) | 배경·날씨·시간대 |
| [cook/](../assets/images/cook/) | 조리 장면 |
| [event/](../assets/images/event/) | 이벤트 |
| [fish/](../assets/images/fish/) | 붕어빵·무늬 |
| [fx/](../assets/images/fx/) | 시각 효과 |
| [icons/](../assets/images/icons/) | 메뉴·재화·상태 아이콘 |
| [skills/](../assets/images/skills/) | 스킬 |
| [stall/](../assets/images/stall/) | 노점·장식 |
| [stove/](../assets/images/stove/) | 화로·붕어빵 틀 |
| [topping/](../assets/images/topping/) | 토핑 |
| [ui/](../assets/images/ui/) | 화면 구성 |

## 이미지 원본과 작업 결과

`assets/images/`는 앱 적용 이미지이고, 아래 폴더는 제작·검토 자료입니다.

- [bungeoppang_raw_assets_261007_0114_01/](../이미지/bungeoppang_raw_assets_261007_0114_01/)
- [preview/](../이미지/preview/)
- [raw/](../이미지/raw/)
- [붕어빵게임_개발에셋_261006_1905_01/](../이미지/붕어빵게임_개발에셋_261006_1905_01/)
- [추가 생성 이미지/](../이미지/추가%20생성%20이미지/)
- [이미지 생성·검토 결과](../output/imagegen/)
- [스토어 배너·스플래시](../store/)

## 개발·출시 문서

단계별 문서는 작업 당시의 기록입니다. 출시·온라인 설정은 [15단계 문서](stage15_release_online.md)에서 확인하세요.

- [pixel_art_prompts.md](pixel_art_prompts.md)
- [play_data_safety.md](play_data_safety.md)
- [privacy_policy.md](privacy_policy.md)
- [stage10_feedback_sound.md](stage10_feedback_sound.md)
- [stage11_balance_endgame.md](stage11_balance_endgame.md)
- [stage12_avatar_fish_customization.md](stage12_avatar_fish_customization.md)
- [stage13_pastel_art.md](stage13_pastel_art.md)
- [stage14_concept_art.md](stage14_concept_art.md)
- [stage15_release_online.md](stage15_release_online.md)
- [stage1_home.md](stage1_home.md)
- [stage2_economy.md](stage2_economy.md)
- [stage3_missions.md](stage3_missions.md)
- [stage4_support.md](stage4_support.md)
- [stage7_baseline_bugfix.md](stage7_baseline_bugfix.md)
- [stage8_offline_content.md](stage8_offline_content.md)
- [stage9_play_games_ranking.md](stage9_play_games_ranking.md)

## 이미지 프롬프트

- [오늘의붕어빵_이미지교체프롬프트_261006_1937_01.md](prompts/오늘의붕어빵_이미지교체프롬프트_261006_1937_01.md)
- [오늘의붕어빵_이미지생성프롬프트_통합_261007_0223_01.md](prompts/오늘의붕어빵_이미지생성프롬프트_통합_261007_0223_01.md)

## 검증·비교 보고서

- [오늘의붕어빵_검증기록_260928_2224_01.md](reports/오늘의붕어빵_검증기록_260928_2224_01.md)
- [오늘의붕어빵_차이분석_260929_0146_01.md](reports/오늘의붕어빵_차이분석_260929_0146_01.md)

## ZIP 보관 파일

파일명의 날짜·시각으로 버전을 구분합니다. APK는 해당 압축파일의 내용을 확인하세요.

- [bungeoppang_261006.zip](../archives/bungeoppang_261006.zip)
- [오늘의붕어빵_261007_0040.zip](../archives/오늘의붕어빵_261007_0040.zip)
- [오늘의붕어빵_261007_0259.zip](../archives/오늘의붕어빵_261007_0259.zip)
- [오늘의붕어빵_APK_261005_2149_01.zip](../archives/오늘의붕어빵_APK_261005_2149_01.zip)
- [오늘의붕어빵_APK_261006_0110_01.zip](../archives/오늘의붕어빵_APK_261006_0110_01.zip)

## 개발자가 찾을 파일

- [앱 시작점](../lib/main.dart) · [게임 제어](../lib/game_controller.dart) · [화면 코드](../lib/ui/)
- [패키지·에셋 설정](../pubspec.yaml) · [Firebase 설정](../firebase/)
- [기능 테스트](../test/) · [비교용 화면](../test/goldens/) · [개발 도구](../tools/)

새 ZIP은 `archives/`, 검증 보고서는 `docs/reports/`, 이미지 프롬프트는 `docs/prompts/`에 추가합니다.
게임 코드와 앱 에셋은 기존 폴더에서 관리합니다.
