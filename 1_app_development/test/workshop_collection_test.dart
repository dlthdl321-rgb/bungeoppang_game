import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_griddle.dart';
import 'package:todays_bungeoppang/development_rules.dart';
import 'package:todays_bungeoppang/economy.dart' show compactNumber;
import 'package:todays_bungeoppang/workshop_collection_rules.dart';
import 'package:todays_bungeoppang/workshop_controller.dart';
import 'package:todays_bungeoppang/workshop_feature_unlocks.dart';
import 'step02_controller_test.dart' show MemoryRepository;

/// 4차 피드백 g6: 도감 칸마다 정해진 횟수를 구워 완성, 칸·맛 완성 보상,
/// 도감 완성으로 여는 숙련된 붕어빵 틀(6구)과 그 자동 준비·탭 타이밍 익힘.
void main() {
  final raw = jsonDecode(File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
  final config = DevelopmentBalance.fromJson(raw);
  Future<WorkshopController> open([MemoryRepository? repository]) async {
    final c = WorkshopController(config, repository ?? MemoryRepository(), now: () => DateTime.utc(2026, 10, 18));
    await c.initialize();
    return c;
  }
  var seq = 0;
  /// Records [n] finished special-mold bakes of [variant] (the ledger the
  /// 도감 counts), in one command.
  Future<bool> bake(WorkshopController c, String flavor, int variant, int n, {bool practice = true}) => c.command(() {
        var m = c.state.flavorMasteries[flavor]!;
        for (var i = 0; i < n; i++) {
          m = m.record(MasteryResult(id: 'bake-${seq++}', flavor: flavor, variant: variant,
              completed: true, practice: practice, techniquePassed: false));
        }
        c.state.flavorMasteries[flavor] = m;
      });
  /// A mastery award as an older save has it (the save checks its ledger):
  /// five practice bakes, one of each doneness, all with the technique.
  Future<bool> legacyAward(WorkshopController c) => c.command(() {
        var m = c.state.flavorMasteries['redbean']!;
        for (var v = 0; v < 5; v++) {
          m = m.record(MasteryResult(id: 'old-$v', flavor: 'redbean', variant: v,
              completed: true, practice: true, techniquePassed: true));
        }
        c.state.flavorMasteries['redbean'] = m;
        c.state.masteryAwards['redbean'] = {'revision': 'old', 'resultId': 'old-4', 'practiceRequired': 5, 'techniqueRequired': 3};
      });
  Future<void> collectRedbean(WorkshopController c) async {
    final need = collectionRequired(config, 'redbean');
    for (var v = 0; v < 5; v++) {
      expect(await bake(c, 'redbean', v, need[v]), isTrue, reason: '${c.notice}');
    }
  }

  group('설정', () {
    test('팥 2/3/5/3/2, 슈크림 10/20/30/20/10, 초코 10/25/40/25/10, 새 맛은 난이도 줄', () {
      expect(collectionRequired(config, 'redbean'), [2, 3, 5, 3, 2]);
      expect(collectionRequired(config, 'custard'), [10, 20, 30, 20, 10]);
      expect(collectionRequired(config, 'cocoa'), [10, 25, 40, 25, 10]);
      // A flavor without its own row (a future flavor) uses its difficulty's
      // row; one without its own title gets '<label> 장인'.
      final copy = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
      ((copy['collection_counts'] as Map)['required_by_flavor'] as Map).remove('redbean');
      ((copy['collection_rewards'] as Map)['titles'] as Map).remove('custard');
      final future = DevelopmentBalance.fromJson(copy);
      expect(collectionRequired(future, 'redbean'), [10, 15, 20, 15, 10]);
      expect(collectionTitle(future, 'custard'), '슈크림 장인');
      expect([for (final f in ['redbean', 'custard', 'cocoa']) collectionTitle(config, f)], ['팥 장인', '슈크림 장인', '초코 장인']);
    });
  });

  group('칸 세기와 보상', () {
    test('처음 한 번이면 발견, 횟수를 채우면 완성: 칸마다 붕어빵력 한 번, 맛 완성에 황금 신청·칭호', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await bake(c, 'redbean', 1, 1), isTrue);
      var p = c.state.collection(config, 'redbean');
      expect(p.found(1), isTrue);
      expect(p.complete(1), isFalse);
      expect(c.state.buns, BigInt.zero);
      expect(c.takeCollectionNews(), isEmpty);
      // The third 부드러움 completes it: one cell reward, one notice.
      final reward = c.collectionCellReward;
      expect(reward, collectionCellMinimum(config), reason: '자동 생산이 없으면 최소 보상');
      expect(await bake(c, 'redbean', 1, 2), isTrue);
      expect(c.state.collection(config, 'redbean').complete(1), isTrue);
      expect(c.state.buns, reward);
      expect(c.state.collectionClaims['redbean'], {1});
      expect(c.takeCollectionNews(), ['팥 · 부드러움 칸 완성! 붕어빵력 +${compactNumber(reward)}']);
      // More bakes of a complete cell pay nothing more.
      expect(await bake(c, 'redbean', 1, 4), isTrue);
      expect(c.state.buns, reward);
      expect(c.state.pendingGold.keys.where((k) => k.startsWith('collection:')), isEmpty);
      expect(c.featureIsOpen(WorkshopFeature.griddle), isFalse);
      // The rest: the flavor is collected.
      for (final v in [0, 2, 3, 4]) {
        expect(await bake(c, 'redbean', v, collectionRequired(config, 'redbean')[v]), isTrue);
      }
      p = c.state.collection(config, 'redbean');
      expect(p.collected, isTrue);
      expect(c.state.buns, reward * BigInt.from(5));
      final claim = jsonDecode(c.state.pendingGold['collection:redbean']!) as Map<String, dynamic>;
      expect(claim, {'scope': 'collection', 'goal': 'redbean', 'gold': collectionFlavorGold(config), 'revision': config.revision});
      expect(c.collectionTitles, ['팥 장인']);
      final news = c.takeCollectionNews();
      expect(news.sublist(news.length - 2), ['팥 도감 완성! 칭호 「팥 장인」', '황금붕어빵력 ${collectionFlavorGold(config)}개는 보상 확인 뒤 받아요']);
      expect(c.featureIsOpen(WorkshopFeature.griddle), isTrue);
      expect(c.featureLock(WorkshopFeature.griddle), isNull);
      // Saved and loaded again: nothing paid twice.
      final again = await open(c.repository as MemoryRepository);
      addTearDown(again.dispose);
      expect(await again.command(() {}), isTrue);
      expect(again.state.buns, reward * BigInt.from(5));
      expect(again.takeCollectionNews(), isEmpty);
    });

    test('주문 제작도 세고, 숙련된 붕어빵 틀(6구) 수확은 세지 않는다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await bake(c, 'redbean', 2, 2, practice: false), isTrue);
      expect(c.state.collection(config, 'redbean').counts, [0, 0, 2, 0, 0]);
      expect(await legacyAward(c), isTrue);
      expect(c.state.collection(config, 'redbean').counts, [1, 1, 3, 1, 1]);
      expect(await c.skipTutorial(), isTrue);
      expect(await c.openBusiness(), isTrue);
      expect(await c.startCell(0), isTrue);
      await c.command(() => c.state.grid = c.state.grid.advanceActive(GriddleProgress.prepMs(config) + 15000));
      expect(await c.harvestCell(0), isTrue);
      expect(c.state.collection(config, 'redbean').counts, [1, 1, 3, 1, 1]);
    });

    test('기존 저장(collectionClaims 없음): 이미 완성된 칸은 받은 것으로, 다 모은 맛은 황금 신청만', () async {
      final repository = MemoryRepository();
      final c = await open(repository);
      await collectRedbean(c);
      c.dispose();
      final old = jsonDecode(jsonEncode(repository.saved)) as Map<String, dynamic>;
      old.remove('collectionClaims');
      (old['pendingGold'] as Map).remove('collection:redbean');
      old['buns'] = '0';
      repository.saved = old;
      final loaded = await open(repository);
      addTearDown(loaded.dispose);
      expect(loaded.state.collectionClaims['redbean'], {0, 1, 2, 3, 4});
      expect(await loaded.command(() {}), isTrue);
      expect(loaded.state.buns, BigInt.zero, reason: '불러올 때 칸 보상을 한꺼번에 주지 않음');
      expect(loaded.state.pendingGold.containsKey('collection:redbean'), isTrue);
    });

    test('찾지 않은 칸의 보상 기록과 근거 없는 도감 황금 신청은 저장을 거절한다', () async {
      final repository = MemoryRepository();
      final c = await open(repository);
      addTearDown(c.dispose);
      expect(await bake(c, 'redbean', 2, 5), isTrue);
      final saved = c.state.toJson();
      expect(saved['collectionClaims'], {'redbean': [2]});
      final bad = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
      (bad['collectionClaims'] as Map)['redbean'] = [2, 4];
      expect(() => WorkshopState.fromJson(bad, config), throwsFormatException);
      final gold = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
      (gold['pendingGold'] as Map)['collection:redbean'] = collectionGoldClaim(config, 'redbean');
      expect(() => WorkshopState.fromJson(gold, config), throwsFormatException, reason: '다섯 익힘을 다 찾지 않음');
    });
  });

  group('숙련된 붕어빵 틀(6구)', () {
    test('도감을 다 채운 맛만 굽고, 예전 숙련(기존 저장)은 그대로 열어 둔다', () async {
      final c = await open();
      addTearDown(c.dispose);
      expect(await c.skipTutorial(), isTrue);
      expect(await c.openBusiness(), isTrue);
      expect(c.featureLock(WorkshopFeature.griddle), '팥 도감을 완성하면 열려요 (0/5)');
      expect(await c.startCell(0), isFalse);
      await collectRedbean(c);
      expect(c.state.griddleFlavors(config), {'redbean'});
      expect(await c.startCell(0), isTrue);
      expect(c.state.grid.cells[0].flavor, 'redbean');
      // An older save's mastery award keeps that flavor open too.
      final legacy = await open();
      addTearDown(legacy.dispose);
      expect(await legacyAward(legacy), isTrue);
      expect(legacy.state.collection(config, 'redbean').collected, isFalse);
      expect(legacy.state.griddleFlavors(config), {'redbean'});
      expect(featureOpen(legacy.state, config, WorkshopFeature.griddle), isTrue);
    });

    test('반죽·속·반죽이 저절로 들어간 뒤 익고, 누른 때가 익힘을 정한다(덜 익음~타버림)', () {
      final prep = GriddleProgress.prepMs(config);
      final target = DevelopmentBalance.integer(config.mastery(0), 'doneness_target_ms');
      final bounds = config.integers('doneness', 'boundary_permille');
      // Slot 3 runs at speed 1000: the special mold's thresholds exactly.
      expect(config.integers('griddle', 'slot_speed_permille')[3], 1000);
      GriddleProgress at(int ms) => GriddleProgress.empty('run-g6', config)
          .start(3, config, ownedAndMastered: {'redbean': 0}, choose: (ids) => ids.single)
          .advanceActive(ms);
      expect(at(0).prepStep(3, config), 0);
      expect(at(prep ~/ 3).prepStep(3, config), 1);
      expect(at(prep * 2 ~/ 3).prepStep(3, config), 2);
      expect(at(prep).prepStep(3, config), isNull);
      expect(() => at(prep - 1).harvest(3, config, businessIndex: 1), throwsFormatException);
      final edges = [for (final b in bounds) target * b ~/ 1000];
      expect(at(prep).doneness(3, config), 0);
      for (var stage = 0; stage < 4; stage++) {
        expect(at(prep + edges[stage] - 1).doneness(3, config), stage, reason: '경계 직전');
        expect(at(prep + edges[stage]).doneness(3, config), stage + 1, reason: '경계부터 다음 익힘');
        expect(at(prep + edges[stage]).cookPermille(3, config), bounds[stage], reason: '표시 막대와 판정이 같은 척도');
      }
      for (var v = 0; v < 4; v++) {
        final ms = prep + (v == 0 ? 1000 : (edges[v - 1] + edges[v]) ~/ 2);
        expect(at(ms).harvest(3, config, businessIndex: 1).product!.variant, v);
      }
      expect(at(prep + edges[3] + 1000).harvest(3, config, businessIndex: 1).product, isNull, reason: '타버림은 폐기');
      // A slower slot takes longer for the same doneness.
      final slow = GriddleProgress.empty('run-g6', config)
          .start(0, config, ownedAndMastered: {'redbean': 0}, choose: (ids) => ids.single)
          .advanceActive(prep + edges[1]);
      expect(slow.doneness(0, config), 1);
    });
  });
}
