import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';

/// 저장 형식 고정 (28번 D, 2026-11-23).
///
/// 1. 형식: 지금 코드가 만드는 저장의 모양(키 이름·값 종류)이 견본과 같아야 한다.
///    저장 형식을 일부러 바꿨다면 schema/formatVersion과 옛 저장 이전을 함께
///    고친 뒤 `UPDATE_SAVE_FORMAT=1 flutter test test/save_format_test.dart`로
///    견본을 다시 쓴다.
/// 2. 읽기: 견본 저장을 읽었다가 다시 쓰면 같은 내용이어야 한다. 밸런스 설정이
///    바뀌어도 이미 있는 저장이 계속 읽히는지 함께 지킨다.
void main() {
  final update = Platform.environment['UPDATE_SAVE_FORMAT'] == '1';
  final config = DevelopmentBalance.fromJson(
      jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>);

  test('가게 저장(schema $workshopSchema): 형식이 견본과 같고 견본 저장을 그대로 다시 쓴다', () {
    final fixture = File('test/fixtures/save_format/workshop_schema$workshopSchema.json');
    final made = normalize(WorkshopState.initial(DateTime.utc(2026, 11, 23), config, 'save-format').toJson());
    if (update || !fixture.existsSync()) {
      writeFixture(fixture, made);
    }
    final saved = readFixture(fixture);
    expect(shape(made), saved['shape'],
        reason: '가게 저장 형식이 바뀌었습니다. 의도했다면 workshopSchema·옛 저장 이전을 고치고 UPDATE_SAVE_FORMAT=1로 견본을 다시 쓰세요.');
    final sample = saved['sample'] as Map<String, dynamic>;
    expect(normalize(WorkshopState.fromJson(sample, config).toJson()), sample,
        reason: '견본 가게 저장을 읽어 다시 쓰면 내용이 달라집니다(옛 저장 읽기가 깨졌을 수 있음).');
  });

  test('계정 저장(formatVersion ${GameState.formatVersion}): 형식이 견본과 같고 견본 저장을 그대로 다시 쓴다', () {
    final fixture = File('test/fixtures/save_format/account_format${GameState.formatVersion}.json');
    final made = normalize(GameState.initial(DateTime.utc(2026, 11, 23)).toJson());
    if (update || !fixture.existsSync()) {
      writeFixture(fixture, made);
    }
    final saved = readFixture(fixture);
    expect(shape(made), saved['shape'],
        reason: '계정 저장 형식이 바뀌었습니다. 의도했다면 formatVersion·옛 저장 이전을 고치고 UPDATE_SAVE_FORMAT=1로 견본을 다시 쓰세요.');
    final sample = saved['sample'] as Map<String, dynamic>;
    expect(normalize(GameState.fromJson(sample).toJson()), sample,
        reason: '견본 계정 저장을 읽어 다시 쓰면 내용이 달라집니다(옛 저장 읽기가 깨졌을 수 있음).');
  });
}

/// The JSON a save becomes on disk (BigInt and the like already strings).
Map<String, dynamic> normalize(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

/// Key names and value kinds, values left out. A list keeps its first item's shape.
Object? shape(Object? value) => switch (value) {
      Map() => {for (final e in value.entries) '${e.key}': shape(e.value)},
      List() => value.isEmpty ? <Object?>[] : [shape(value.first)],
      String() => 'string',
      bool() => 'bool',
      int() => 'int',
      double() => 'double',
      null => 'null',
      _ => value.runtimeType.toString(),
    };

void writeFixture(File file, Map<String, dynamic> sample) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'shape': shape(sample), 'sample': sample})}\n');
}

Map<String, dynamic> readFixture(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
