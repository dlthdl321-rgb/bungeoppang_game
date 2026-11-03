param(
  [string]$NodeVersion = '22.23.3',
  [string]$FirebaseToolsVersion = '15.34.0',
  [string]$ToolsRoot = (Join-Path $PSScriptRoot 'local_tools')
)
# Prepares the local server-check tools used by run_emulator_checks.ps1:
# Node 22 (official nodejs.org zip, SHA256-checked) and Firebase CLI.
# Java 21 and the Firestore emulator jar stay in an ASCII path
# (C:\Users\Public\codex-workshop-step04-tools) because Java's Windows
# launcher fails under non-ASCII user paths.
$ErrorActionPreference = 'Stop'
[IO.Directory]::CreateDirectory($ToolsRoot) | Out-Null
$nodeName = "node-v$NodeVersion-win-x64"
$nodeDir = Join-Path $ToolsRoot $nodeName
if (!(Test-Path -LiteralPath (Join-Path $nodeDir 'node.exe'))) {
  $base = "https://nodejs.org/dist/v$NodeVersion"
  $zip = Join-Path $ToolsRoot "$nodeName.zip"
  Invoke-WebRequest -UseBasicParsing "$base/$nodeName.zip" -OutFile $zip
  $sums = (Invoke-WebRequest -UseBasicParsing "$base/SHASUMS256.txt").Content
  $expected = ($sums -split "`n" | Where-Object { $_ -match " $nodeName\.zip$" }) -replace '\s.*$', ''
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLower()
  if (!$expected -or $actual -ne $expected.Trim().ToLower()) { Remove-Item -LiteralPath $zip; throw "Node zip SHA256 mismatch" }
  Expand-Archive -LiteralPath $zip -DestinationPath $ToolsRoot
  Remove-Item -LiteralPath $zip
}
$node = Join-Path $nodeDir 'node.exe'
$cliDir = Join-Path $ToolsRoot 'firebase-cli'
$cli = Join-Path $cliDir 'node_modules\firebase-tools\lib\bin\firebase.js'
if (!(Test-Path -LiteralPath $cli)) {
  $env:PATH = $nodeDir + ';' + $env:PATH
  & (Join-Path $nodeDir 'npm.cmd') install --prefix $cliDir --no-audit --no-fund "firebase-tools@$FirebaseToolsVersion"
  if ($LASTEXITCODE -ne 0) { throw 'firebase-tools install failed' }
}
Write-Output "Node22Path      = $node ($(& $node -v))"
Write-Output "FirebaseCliPath = $cli"
Write-Output "Java21Bin       = C:\Users\Public\codex-workshop-step04-tools\java21\jdk-21.0.12.1+1-jre\bin"
