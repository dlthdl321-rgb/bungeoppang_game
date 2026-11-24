# SHA-1 지문을 카카오 개발자 콘솔에 넣는 "키 해시"로 바꾼다(23번 7단계, online_setup.md 3장).
# 사용: powershell -ExecutionPolicy Bypass -File kakao_key_hash.ps1 -Sha1 "17:17:AB:..."
# 콜론(:)이 있든 없든, 대문자든 소문자든 된다. 지문은 비밀이 아니다.
param([Parameter(Mandatory=$true)][string]$Sha1)
$hex = ($Sha1 -replace '[^0-9A-Fa-f]', '')
if ($hex.Length -ne 40) {
  Write-Host "SHA-1 지문은 16진수 40글자(콜론 빼고)여야 합니다. 지금 $($hex.Length)글자입니다. SHA-256이 아닌 SHA-1을 넣었는지 확인하세요." -ForegroundColor Red
  exit 1
}
$bytes = New-Object byte[] 20
for ($i = 0; $i -lt 20; $i++) { $bytes[$i] = [Convert]::ToByte($hex.Substring($i * 2, 2), 16) }
Write-Host ('카카오 키 해시: ' + [Convert]::ToBase64String($bytes)) -ForegroundColor Green
