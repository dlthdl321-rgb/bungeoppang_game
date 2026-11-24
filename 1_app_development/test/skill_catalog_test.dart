import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/balance.dart';
import 'package:todays_bungeoppang/models.dart';
import 'package:todays_bungeoppang/skill_catalog.dart';

/// 32번 0단계: the moved skill list is the old one, same order and names
/// (until balance.dart goes in 4단계; then this test goes with it).
void main() {
  test('스킬 목록은 예전 목록과 순서·이름·종류가 같다', () {
    expect([for (final s in skillCatalog) '${s.id}:${s.name}:${s.kind.name}'],
        [for (final u in upgrades) '${u.id}:${u.name}:${u.kind == UpgradeKind.tap ? 'tap' : 'auto'}']);
  });
}
