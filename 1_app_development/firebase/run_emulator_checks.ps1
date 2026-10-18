param(
  [Parameter(Mandatory=$true)][string]$Node22Path,
  [Parameter(Mandatory=$true)][string]$FirebaseCliPath,
  [Parameter(Mandatory=$true)][string]$Java21Bin,
  [ValidateRange(10,300)][int]$DiscoveryTimeoutSeconds = 120,
  [string]$EmulatorScratchRoot = (Join-Path $env:PUBLIC 'codex-workshop-step04-tools')
)
$ErrorActionPreference = 'Stop'
$taskNode = (Resolve-Path -LiteralPath $Node22Path).Path
$taskCli = (Resolve-Path -LiteralPath $FirebaseCliPath).Path
$taskJava = (Resolve-Path -LiteralPath $Java21Bin).Path
if ((& $taskNode -p 'process.versions.node') -notmatch '^22\.') { throw 'Node 22 is required' }
if (!(Test-Path -LiteralPath (Join-Path $taskJava 'java.exe'))) { throw 'Java 21 bin is required' }
$taskEnvironment = @{}
foreach ($taskName in @('PATH','WORKSHOP_ONLINE_ENABLED','WORKSHOP_AD_SSV_ENABLED','WORKSHOP_PROTECTION_ENABLED','GCLOUD_PROJECT','GOOGLE_CLOUD_PROJECT','CI','FUNCTIONS_DISCOVERY_TIMEOUT','DEBUG')) {
  $taskEnvironment[$taskName] = [Environment]::GetEnvironmentVariable($taskName, 'Process')
}
Push-Location $PSScriptRoot
$taskRules = $null
$taskConfig = $null
try {
  # Java's Windows launcher can lose non-ASCII rule paths. Keep the exact
  # repository rules, but pass Java an ASCII temporary copy; never relax rules.
  $taskScratch = [IO.Path]::GetFullPath($EmulatorScratchRoot)
  if ($taskScratch -match '[^\x20-\x7e]') { throw 'EmulatorScratchRoot must be an ASCII path' }
  [IO.Directory]::CreateDirectory($taskScratch) | Out-Null
  $taskRunId = [Guid]::NewGuid().ToString('N')
  $taskRules = Join-Path $taskScratch "firestore-step04-$taskRunId.rules"
  $taskConfig = Join-Path $PSScriptRoot ".firebase-step04-$taskRunId.json"
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'firestore.rules') -Destination $taskRules
  $taskConfigData = Get-Content -LiteralPath 'firebase.emulator.json' -Raw | ConvertFrom-Json
  $taskConfigData.firestore.rules = $taskRules
  [IO.File]::WriteAllText($taskConfig, ($taskConfigData | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
  $env:PATH = (Split-Path $taskNode) + ';' + $taskJava + ';' + $env:PATH
  $env:WORKSHOP_ONLINE_ENABLED = 'false'
  $env:WORKSHOP_AD_SSV_ENABLED = 'false'
  $env:WORKSHOP_PROTECTION_ENABLED = 'false'
  $env:CI = 'true'
  # Firebase debug mode prints the inherited process environment. Keep it local
  # and quiet even when launched from a parent editor with DEBUG configured.
  $env:DEBUG = $null
  $env:FUNCTIONS_DISCOVERY_TIMEOUT = [string]$DiscoveryTimeoutSeconds
  $env:GCLOUD_PROJECT = 'demo-workshop-step04'
  $env:GOOGLE_CLOUD_PROJECT = 'demo-workshop-step04'
  & $taskNode 'functions/node_modules/typescript/bin/tsc' -p 'functions/tsconfig.json'
  if ($LASTEXITCODE -ne 0) { throw 'TypeScript build failed' }
  & $taskNode --test 'functions/lib/test/*.test.js'
  if ($LASTEXITCODE -ne 0) { throw 'Node 22 unit tests failed' }
  & $taskNode $taskCli emulators:exec --only 'auth,firestore,functions' --project 'demo-workshop-step04' --config $taskConfig --non-interactive 'node --test functions/lib/test/emulator/*.js'
  if ($LASTEXITCODE -ne 0) { throw 'Emulator integration tests failed' }
} finally {
  if ($taskRules -and (Test-Path -LiteralPath $taskRules)) { Remove-Item -LiteralPath $taskRules }
  if ($taskConfig -and (Test-Path -LiteralPath $taskConfig)) { Remove-Item -LiteralPath $taskConfig }
  Pop-Location
  foreach ($taskName in $taskEnvironment.Keys) { [Environment]::SetEnvironmentVariable($taskName,$taskEnvironment[$taskName],'Process') }
}
