# 개발 임시 수치 원본

`development_balance.json`은 신규 기획의 임시 숫자를 한 곳에서 관리합니다. 현재 게임·서버 런타임에는 아직 연결하지 않았습니다. 기존 앱의 economy_config.dart·유료 카탈로그·실제 IAP를 자동 변경하지 않습니다.

저장소 루트에서 다음을 실행합니다.

```bash
python 1_app_development/tools/development_balance.py
python 1_app_development/tools/development_balance.py --check
python 1_app_development/tools/planning_tasks.py render
```

일반 조정은 이 JSON의 값을 바꾸고 문서를 재생성합니다. 단위는 키의 ms/permille/basis_points를 따르며 금액은10진 문자열입니다. fixed_requirements는 사용자 확정으로 별도 계약 변경 없이 튜닝하지 않습니다. revision은 클라이언트/서버가 같은 구매 견적을 사용하는지 확인할 식별자로 함께 갱신합니다.

향후 신규 기능 구현 시 이 원본을 읽는 설정 계층을 연결하고 임의의 코드 상수로 복제하지 않습니다. 서버가 적용한 가격표/견적이 권위이며 클라이언트 JSON만으로 서버 가격을 변경하지 않습니다. 새 배포·새 견적이 필요한 변경과 단순 문서 생성을 구분합니다.

보상/가격표의 임시값 채움은 수치 아닌 정책 승인·런타임 연동·실제 테스트 통과를 뜻하지 않습니다. [설정 전체 표](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/14_개발용임시수치설정.md)를 확인하세요.
