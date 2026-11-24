import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 설정 원본(config/*.json)과 그 생성물이 어긋나지 않았는지 지킨다.
/// 앱과 서버가 같은 밸런스 값을 쓰는지(서버 복사본), 생성 문서·Dart 생성물이
/// 원본과 같은지를 생성 도구의 `--check`(파일을 바꾸지 않음)로 확인한다.
void main() {
  final noPython = Process.runSync('python', ['--version']).exitCode != 0;
  const env = {'PYTHONIOENCODING': 'utf-8'};

  test('앱 밸런스 설정과 서버 복사본(functions/src/generated)이 같은 값이다', () {
    final app = jsonDecode(File('config/development_balance.json').readAsStringSync());
    final server = jsonDecode(
        File('firebase/functions/src/generated/development_balance.json').readAsStringSync());
    expect(server, app,
        reason: '설정을 바꾼 뒤 `python tools/development_balance.py`로 서버 복사본을 다시 만드세요.');
  });

  test('밸런스 생성 도구 --check: 서버 복사본·14번 문서·오디오 기본값이 원본과 같다', () {
    final result = Process.runSync('python', ['tools/development_balance.py', '--check'],
        environment: env);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }, skip: noPython ? 'python 없음' : false);

  test('손님 콘텐츠 생성 도구 --check: lib/generated/customer_content.dart가 원본과 같다', () {
    final result = Process.runSync('python', ['tools/customer_content.py', '--check'],
        environment: env);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  }, skip: noPython ? 'python 없음' : false);
}
