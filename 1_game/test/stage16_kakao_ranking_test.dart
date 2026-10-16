import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/ranking_config.dart';

// The server (firebase/functions/src/ranking.ts) judges submissions with
// the same numbers as lib/ranking_config.dart. Read them from the source so
// the two cannot drift apart.

final _server = File('firebase/functions/src/ranking.ts').readAsStringSync();

BigInt _const(String name) {
  final m = RegExp('export const $name = ([0-9_]+)n?;').firstMatch(_server);
  expect(m, isNotNull, reason: name);
  return BigInt.parse(m!.group(1)!.replaceAll('_', ''));
}

BigInt _floor(String board) {
  final m = RegExp('$board: ([0-9]+)n').firstMatch(_server);
  expect(m, isNotNull, reason: board);
  return BigInt.parse(m!.group(1)!);
}

void main() {
  test('서버와 앱의 랭킹 기준이 같다', () {
    expect(_const('rankingScoreMax'), rankingScoreMax);
    expect(_const('rankingSubmitMinGapMs'), BigInt.from(rankingSubmitMinGapMs));
    expect(_const('rankingTopCount'), BigInt.from(rankingTopCount));
    expect(_const('rankingGrowthSlack'), BigInt.from(rankingGrowthSlack));
    expect(_const('rankingGrowthPerHour'), BigInt.from(rankingGrowthPerHour));
    for (final board in rankingBoards) {
      expect(_server, contains('"$board"'));
      expect(_floor(board), rankingGrowthFloor[board], reason: board);
    }
  });

  test('카카오 키와 시크릿은 저장소에 없다', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains(r'kakao${kakaoNativeAppKey}'));
    expect(File('lib/firebase_online_backend.dart').readAsStringSync(),
        contains("String.fromEnvironment('KAKAO_NATIVE_APP_KEY')"));
    expect(File('firebase/functions/.gitignore').readAsStringSync(),
        contains('.env'));
  });
}
