import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 23번 7단계: online keys reach the app only through a gitignored
// --dart-define-from-file JSON, the server's production settings only through
// a gitignored functions/.env, and both sides use App Check.

Future<bool> _ignored(String path) async =>
    (await Process.run('git', ['check-ignore', '-q', path])).exitCode == 0;

void main() {
  final backend = File('lib/firebase_online_backend.dart').readAsStringSync();

  test('online.example.json에는 앱이 읽는 키 이름만 빈 값으로 있다', () {
    final example = jsonDecode(
            File('dart_defines/online.example.json').readAsStringSync())
        as Map<String, dynamic>;
    final read = RegExp(r"String\.fromEnvironment\('([A-Z_]+)'\)")
        .allMatches(backend)
        .map((m) => m.group(1)!)
        .toSet();
    expect(read, containsAll(<String>[
      'FIREBASE_API_KEY',
      'FIREBASE_APP_ID',
      'FIREBASE_SENDER_ID',
      'FIREBASE_PROJECT_ID',
      'KAKAO_NATIVE_APP_KEY',
      'APP_CHECK_DEBUG_TOKEN',
    ]));
    expect(example.keys.toSet(), read);
    expect(example.values, everyElement(''));
  });

  test('실제 키 파일은 git에서 빠지고 견본만 올라간다', () async {
    expect(await _ignored('dart_defines/online.json'), isTrue);
    expect(await _ignored('dart_defines/online.example.json'), isFalse);
    expect(await _ignored('firebase/functions/.env'), isTrue);
    expect(await _ignored('firebase/functions/.env.local'), isTrue);
    expect(await _ignored('firebase/functions/.env.example'), isFalse);
  });

  test('서버 견본 설정은 온라인 켬·광고 끔·App Check 강제, 비밀 칸은 비어 있다', () {
    final lines = File('firebase/functions/.env.example')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .map((l) => l.split('='))
        .map((p) => MapEntry(p[0], p.sublist(1).join('=')));
    final env = Map.fromEntries(lines);
    expect(env, {
      'KAKAO_APP_ID': '',
      'WORKSHOP_ONLINE_ENABLED': 'true',
      'WORKSHOP_SALE_DRAW_KEY_BASE64': '',
      'WORKSHOP_AD_SSV_ENABLED': 'false',
      'WORKSHOP_PROTECTION_ENABLED': 'false',
      'APP_CHECK_ENFORCED': 'true',
    });
  });

  test('앱은 App Check를 켜고 서버는 끄지 않는다', () {
    expect(backend, contains('AndroidPlayIntegrityProvider'));
    expect(backend, contains('_activateAppCheck(app)'));
    final server = File('firebase/functions/src/index.ts').readAsStringSync();
    expect(server, isNot(contains('enforceAppCheck: false')));
    expect(server, contains('callableOptions()'));
  });
}
