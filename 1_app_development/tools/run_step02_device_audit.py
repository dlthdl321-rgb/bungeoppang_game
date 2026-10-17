"""Isolated Android smoke + real force-stop/restart audit; never uninstalls a game."""
import argparse
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--app', default='C:/Temp/bungeoppang-step02-analysis')
parser.add_argument('--smoke-only', action='store_true')
parser.add_argument('--gradle-home', default='C:/GradleCache')
args = parser.parse_args()
app = Path(args.app).absolute()
if not app.joinpath('pubspec.yaml').is_file() or not str(app).isascii():
    raise SystemExit('Use the ASCII junction to this Flutter application.')
if not all(c.isalnum() or c in '._:-' for c in args.device):
    raise SystemExit('Invalid adb device identifier')
env = os.environ.copy()
env.update(PUB_CACHE='C:/PubCacheBungeoppang', GRADLE_USER_HOME=args.gradle_home,
           TEMP='C:/Temp/step02-tools', TMP='C:/Temp/step02-tools')
env['JAVA_TOOL_OPTIONS'] = env.get('JAVA_TOOL_OPTIONS', '') + ' -Dfile.encoding=UTF-8'
env['GRADLE_OPTS'] = env.get('GRADLE_OPTS', '') + ' -Dorg.gradle.jvmargs="-Xmx2g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m -Dfile.encoding=UTF-8" -Dorg.gradle.workers.max=2'
Path(env['TEMP']).mkdir(parents=True, exist_ok=True)
flutter = 'C:/flutter-sdk/bin/flutter.bat'
adb = 'C:/Android/sdk/platform-tools/adb.exe'
package = 'com.todaybungeoppang.todays_bungeoppang.step02audit'
run = time.strftime('%Y%m%d%H%M%S')
logs = Path('C:/Temp') / f'step02-device-{run}'
logs.mkdir()

def command(target, *defines):
    return [flutter, 'test', '--no-pub', target, '-d', args.device,
            '--dart-define=PRODUCTION_AUDIT=true', *defines]

def execute(name, cmd):
    with (logs / f'{name}.log').open('w', encoding='utf-8') as output:
        result = subprocess.run(cmd, cwd=app, env=env, stdout=output,
                                stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
    print(f'{name}: exit={result.returncode}; log={logs / (name + ".log")}', flush=True)
    if result.returncode:
        print((logs / f'{name}.log').read_text(encoding='utf-8', errors='replace')[-10000:], flush=True)
        raise SystemExit(result.returncode)

execute('smoke', command('integration_test/step02_android_test.dart'))
if args.smoke_only:
    raise SystemExit(0)

stage_log = logs / 'crash-stage.log'
with stage_log.open('w', encoding='utf-8') as output:
    stage = subprocess.Popen(command('integration_test/step02_crash_recovery_test.dart',
        '--dart-define=STEP02_PHASE=stage', f'--dart-define=STEP02_RUN={run}'),
        cwd=app, env=env, stdout=output, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW)
    deadline = time.monotonic() + 900
    while b'STEP02_KILL_READY' not in stage_log.read_bytes():
        if stage.poll() is not None or time.monotonic() >= deadline:
            raise SystemExit(f'Journal readiness was not reached; inspect {stage_log}')
        time.sleep(1)
    pid = subprocess.check_output([adb, '-s', args.device, 'shell', 'pidof', package], text=True).strip()
    if not pid:
        raise SystemExit('No audit process exists to force-stop')
    subprocess.run([adb, '-s', args.device, 'shell', 'am', 'force-stop', package], check=True)
    after = subprocess.run([adb, '-s', args.device, 'shell', 'pidof', package], capture_output=True, text=True)
    if after.stdout.strip():
        raise SystemExit('Audit process did not stop')
    print(f'force-stop: journal durable; process {pid} terminated', flush=True)
    stage.wait(timeout=90)  # A lost test VM here is the deliberate interruption.

execute('crash-recover', command('integration_test/step02_crash_recovery_test.dart',
    '--dart-define=STEP02_PHASE=recover', f'--dart-define=STEP02_RUN={run}'))
print(f'PASS: Android smoke + force-stop recovery; evidence={logs}', flush=True)
