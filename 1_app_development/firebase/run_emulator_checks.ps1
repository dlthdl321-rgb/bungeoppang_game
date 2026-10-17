param(
  [Parameter(Mandatory=$true)][string]$Node22Path,
  [Parameter(Mandatory=$true)][string]$FirebaseCliPath,
  [Parameter(Mandatory=$true)][string]$Java21Bin,
  [ValidateRange(10,300)][int]$DiscoveryTimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$taskNode = (Resolve-Path -LiteralPath $Node22Path).Path
$taskCli = (Resolve-Path -LiteralPath $FirebaseCliPath).Path
$taskJava = (Resolve-Path -LiteralPath $Java21Bin).Path
if ((& $taskNode -p 'process.versions.node') -notmatch '^22\.') { throw 'Node 22 is required' }
if (!(Test-Path -LiteralPath (Join-Path $taskJava 'java.exe'))) { throw 'Java 21 bin is required' }
$taskEnvironment = @{}
foreach ($taskName in @('PATH','WORKSHOP_ONLINE_ENABLED','WORKSHOP_AD_SSV_ENABLED','WORKSHOP_PROTECTION_ENABLED','GCLOUD_PROJECT','GOOGLE_CLOUD_PROJECT','CI','FUNCTIONS_DISCOVERY_TIMEOUT')) {
  $taskEnvironment[$taskName] = [Environment]::GetEnvironmentVariable($taskName, 'Process')
}
Push-Location $PSScriptRoot
try {
  $env:PATH = (Split-Path $taskNode) + ';' + $taskJava + ';' + $env:PATH
  $env:WORKSHOP_ONLINE_ENABLED = 'false'
  $env:WORKSHOP_AD_SSV_ENABLED = 'false'
  $env:WORKSHOP_PROTECTION_ENABLED = 'false'
  $env:CI = 'true'
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = [string]$DiscoveryTimeoutSeconds
  $env:GCLOUD_PROJECT = 'demo-workshop-step04'
  $env:GOOGLE_CLOUD_PROJECT = 'demo-workshop-step04'
  & $taskNode 'functions/node_modules/typescript/bin/tsc' -p 'functions/tsconfig.json'
  if ($LASTEXITCODE -ne 0) { throw 'TypeScript build failed' }
  & $taskNode --test 'functions/lib/test/*.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'Node 22 unit tests failed' }
  & $taskNode $taskCli emulators:exec --only 'auth,firestore,functions' --project 'demo-workshop-step04' --config 'firebase.emulator.json' --non-interactive 'node --test functions/lib/test/emulator/*.js'
  if ($LASTEXITCODE -ne 0) { throw 'Emulator integration tests failed' }
} finally {
  Pop-Location
  foreach ($taskName in $taskEnvironment.Keys) { [Environment]::SetEnvironmentVariable($taskName,$taskEnvironment[$taskName],'Process') }
}
