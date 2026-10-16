# 개발 임시 수치 원본

`development_balance.json`은 신규 기획의 임시 숫자를 한 곳에서 관리합니다. 오디오 기본값은 생성 Dart 상수로 연결했습니다. 신규 규칙은 명시적 로더/계산 모듈로 제공하고, 전체 신규 게임 흐름·서버 가격에는 아직 연결하지 않았습니다. 기존 앱의 economy_config.dart·유료 카탈로그·실제 IAP를 자동 변경하지 않습니다.

저장소 루트에서 다음을 실행합니다.

```bash
python 1_app_development/tools/development_balance.py
python 1_app_development/tools/development_balance.py --check
python 1_app_development/tools/planning_tasks.py render
```

일반 조정은 이 JSON의 값을 바꾸고 문서를 재생성합니다. 단위는 키의 ms/permille/basis_points를 따르며 금액은10진 문자열입니다. fixed_requirements는 사용자 확정으로 별도 계약 변경 없이 튜닝하지 않습니다. revision은 클라이언트/서버가 같은 구매 견적을 사용하는지 확인할 식별자로 함께 갱신합니다.

향후 신규 기능 구현 시 이 원본을 읽는 설정 계층을 연결하고 임의의 코드 상수로 복제하지 않습니다. 서버가 적용한 가격표/견적이 권위이며 클라이언트 JSON만으로 서버 가격을 변경하지 않습니다. 새 배포·새 견적이 필요한 변경과 단순 문서 생성을 구분합니다.

보상/가격표의 임시값 채움은 수치 아닌 정책 승인·런타임 연동·실제 테스트 통과를 뜻하지 않습니다. [설정 전체 표](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/14_개발용임시수치설정.md)를 확인하세요.

생성 파일 development_audio_defaults.dart는 직접 수정하지 않습니다. 생성·검증 명령으로14번 표와 함께 갱신합니다.

## 현재 신규 게임 소스

main.dart의 신규 Workshop은 초기 팥·추가 슈크림/초코 미션·영업/연습/숙련/6구/재고·손님 판매·수동50레벨·도감 저장 경로다. 구형 코인은 신규 개념이 아니며 실제 복합 결제·검증 황금/광고·친구 연동과 컴파일/실행 검수는 미완료다. 상세는 [18번 연결 범위](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/18_신규게임연결과사용자결정반영.md)를 따른다.


개발 설정 revision3은 기존 사장님 아바타51개 메타데이터/임시 해금과 두 재화 가격을 함께 관리합니다. 서버의 `firebase/functions/src/generated/development_balance.json`도 같은 생성 도구가 만들며 `--check`로 앱/문서/서버 사본을 대조합니다. 생성 파일을 직접 고치지 않습니다.
