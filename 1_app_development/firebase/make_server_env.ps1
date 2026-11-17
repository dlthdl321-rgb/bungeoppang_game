# 서버 함수 운영 설정 파일(functions\.env)을 만든다. 23번 7단계, online_setup.md 4장.
# - 카카오 앱 ID만 물어보고, 판매 보상 추첨 키(비밀)는 안전한 난수로 만든다.
# - 키 값은 화면에 보여 주지 않는다. 만든 파일은 .gitignore로 커밋되지 않는다.
# - 이미 functions\.env가 있으면 덮어쓰지 않고 멈춘다(추첨 키가 바뀌지 않게).
$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot 'functions\.env'
if (Test-Path -LiteralPath $envFile) {
  Write-Host '이미 functions\.env 파일이 있어서 멈춥니다. 고칠 것이 있으면 메모장으로 그 파일을 직접 고치세요.' -ForegroundColor Yellow
  exit 1
}
$kakao = (Read-Host '카카오 앱 ID(숫자)를 붙여 넣고 Enter').Trim()
if ($kakao -notmatch '^[0-9]+$') {
  Write-Host '카카오 앱 ID는 숫자로만 되어 있습니다(네이티브 앱 키와 다릅니다). 다시 실행하세요.' -ForegroundColor Red
  exit 1
}
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$lines = @(
  "KAKAO_APP_ID=$kakao",
  'WORKSHOP_ONLINE_ENABLED=true',
  ('WORKSHOP_SALE_DRAW_KEY_BASE64=' + [Convert]::ToBase64String($bytes)),
  'WORKSHOP_AD_SSV_ENABLED=false',
  'WORKSHOP_PROTECTION_ENABLED=false',
  'APP_CHECK_ENFORCED=true'
)
[IO.File]::WriteAllText($envFile, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
Write-Host "완료: $envFile 를 만들었습니다(카카오 앱 ID $kakao, 추첨 키 생성됨, 온라인 켬, 광고 끔, App Check 강제)." -ForegroundColor Green
Write-Host '이 파일은 다른 사람에게 보내거나 저장소에 올리지 마세요. 비밀번호 관리자 등에 사본을 두면 PC를 바꿔도 같은 키를 쓸 수 있습니다.'
