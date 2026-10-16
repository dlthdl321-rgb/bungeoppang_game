# 온라인 서버

카카오 로그인·랭킹·친구·초대·유료 재화 서버입니다. 오프라인 앱 개발과 단위 테스트에는 실제 서비스 키가 필요하지 않습니다.

```bash
cd 1_app_development/firebase/functions
npm ci
npm test
```

Node.js 22를 사용합니다. `npm test`는 TypeScript 빌드와 서버 단위 테스트를 실행합니다. 함수 소스는 `functions/src`, 테스트는 `functions/test`, Firestore 규칙과 인덱스는 이 폴더에 있습니다.

실제 배포에는 별도 Firebase·카카오·Play 설정이 필요합니다. [보존한 온라인 설정 문서](../../2_development_plans_and_checklists/2.1_development_specs_tasks_and_progress/2.1.3_legacy_code_policies_and_online_setup/README.md)를 확인하세요. 문서 정리는 실제 서비스 배포를 뜻하지 않습니다.
