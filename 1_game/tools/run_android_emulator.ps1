$ErrorActionPreference = 'Stop'
$sdk = 'C:\Android\sdk'
$emulator = Join-Path $sdk 'emulator\emulator.exe'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$avd = 'TodayBungeoppang_API35'
$projectRoot = Split-Path $PSScriptRoot
$apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-debug.apk'
$apk = Get-Item -LiteralPath $apkPath -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $emulator)) {
  throw 'Android Emulator is not installed.'
}
if (-not (Test-Path -LiteralPath $adb)) {
  throw 'ADB is not installed.'
}
if (-not $apk) {
  throw 'Build the current APK first: flutter build apk --debug'
}

& $emulator -accel-check
$serial = 'emulator-5554'
$runningDevice = & $adb devices | Select-String '^emulator-5554\s+'
if ($runningDevice) {
  $runningName = & $adb -s $serial emu avd name
  if ($runningName -notcontains $avd) {
    throw 'Port 5554 belongs to another emulator; do not install on an unknown target.'
  }
} else {
  Start-Process -FilePath $emulator -ArgumentList '-avd', $avd, '-port', '5554', '-no-snapshot', '-gpu', 'swiftshader_indirect', '-cores', '2' -WindowStyle Hidden
}

$deadline = (Get-Date).AddMinutes(3)
do {
  Start-Sleep -Seconds 2
  $boot = & $adb -s $serial shell getprop sys.boot_completed 2>$null
} until ("$boot".Trim() -eq '1' -or (Get-Date) -ge $deadline)
if ("$boot".Trim() -ne '1') { throw 'Emulator did not finish booting within 3 minutes.' }

& $adb -s $serial install -r $apk.FullName
if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
& $adb -s $serial shell am force-stop com.todaybungeoppang.todays_bungeoppang
& $adb -s $serial shell am start -n com.todaybungeoppang.todays_bungeoppang/.MainActivity
if ($LASTEXITCODE -ne 0) { throw 'Activity launch failed.' }
Write-Host "Launch complete: $($apk.Name)"
