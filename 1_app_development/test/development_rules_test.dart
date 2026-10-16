import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:todays_bungeoppang/development_balance.dart';
import 'package:todays_bungeoppang/development_rules.dart';

// Fixed arithmetic fixture: later tuning the real JSON does not change these
// scenario inputs. The real file still gets parsed and validated separately.
DevelopmentBalance load() {
  final raw = jsonDecode(File('config/development_balance.json').readAsStringSync())
      as Map<String, dynamic>;
  final skill = raw['skill_purchase']['entries']['tap_1'] as Map;
  skill.addAll({'buns': '15', 'gold': 1, 'ratio_numerator': 115, 'ratio_denominator': 100});
  (raw['skill_purchase'] as Map).addAll({'gold_step_purchase_count': 10, 'gold_step_amount': 1});
  (raw['mastery_difficulties'][0] as Map).addAll({
    'practice_required': 8, 'technique_passes_required': 3, 'doneness_target_ms': 15000});
  (raw['doneness'] as Map)['boundary_permille'] = [600, 900, 1100, 1400];
  return DevelopmentBalance.fromJson(raw);
}

void main() {
  late DevelopmentBalance config;
  setUp(() => config = load());

  test('실제 조정 원본도 형식과 확정 계약을 만족한다', () {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(DevelopmentBalance.fromJson(raw).revision, isNotEmpty);
  });

  test('두 재화 묶음과 최대구매는 경계 잔액을 함께 확인한다', () {
    final quote = quoteCompositeSkill(config, 'tap_1', owned: 0, quantity: 2);
    expect(quote.buns, BigInt.from(33));
    expect(quote.gold, BigInt.two);
    expect(quote.affordable(BigInt.from(33), BigInt.one), isFalse);
    final max = maximumCompositeSkill(config, 'tap_1', owned: 0,
        availableBuns: BigInt.from(33), availableGold: BigInt.two);
    expect(max.quantity, 2);
    expect(() => quoteCompositeSkill(config, 'tap_1', owned: -1, quantity: 1),
        throwsFormatException);
  });

  test('설정 숫자만 바꿔도 견적이 변하고 생성 후 외부 수정은 격리된다', () {
    final raw = jsonDecode(File('config/development_balance.json').readAsStringSync())
        as Map<String, dynamic>;
    (raw['skill_purchase']['entries']['tap_1'] as Map)['buns'] = '27';
    final changed = DevelopmentBalance.fromJson(raw);
    (raw['skill_purchase']['entries']['tap_1'] as Map)['buns'] = '1';
    expect(quoteCompositeSkill(changed, 'tap_1', owned: 0, quantity: 1).buns,
        BigInt.from(27));
  });

  test('익힘 경계는 다음 단계에 포함하고 신선도는 영업일5에서 소멸한다', () {
    expect(provisionalDoneness(config, elapsedMs: 8999, difficulty: 0), 0);
    expect(provisionalDoneness(config, elapsedMs: 9000, difficulty: 0), 1);
    expect(provisionalDoneness(config, elapsedMs: 21000, difficulty: 0), 4);
    expect(inventoryExpired(config, madeOnBusinessIndex: 2, currentBusinessIndex: 6), isFalse);
    expect(inventoryExpired(config, madeOnBusinessIndex: 2, currentBusinessIndex: 7), isTrue);
  });

  test('주문은 수집만, 실패 완주 연습은 카운트하고 같은 결과는1회다', () {
    final start = FlavorMasteryProgress(flavor: 'redbean', difficulty: 0);
    final order = MasteryResult(id: 'order', flavor: 'redbean', variant: 1,
        completed: true, practice: false, techniquePassed: true);
    final collected = start.record(order);
    expect(collected.discovered, contains(1));
    expect(collected.practiceDiscovered, isEmpty);
    expect(collected.practices, 0);
    final failed = MasteryResult(id: 'practice', flavor: 'redbean', variant: 4,
        completed: true, practice: true, techniquePassed: false);
    final practiced = collected.record(failed);
    expect(practiced.practices, 1);
    expect(practiced.techniquePasses, 0);
    expect(practiced.record(failed), same(practiced));
    expect(practiced.complete(config), isFalse);
    expect(() => practiced.record(const MasteryResult(id: 'practice',
        flavor: 'redbean', variant: 0, completed: true, practice: true,
        techniquePassed: true)), throwsFormatException);
  });

  test('연습5종과 요구량·손기술이 모두 있어야 숙련 완료다', () {
    var progress = FlavorMasteryProgress(flavor: 'redbean', difficulty: 0);
    for (var i = 0; i < 8; i++) {
      progress = progress.record(MasteryResult(id: '$i', flavor: 'redbean',
          variant: i % 5, completed: true, practice: true, techniquePassed: i < 3));
      if (i < 7) expect(progress.complete(config), isFalse);
    }
    expect(progress.complete(config), isTrue);
  });

  test('광고 날짜는 서버 시작 UTC를 KST 날짜로 포맷한다', () {
    expect(rewardedAdStartDay(config, DateTime.utc(2026, 10, 16, 14, 59)), '2026-10-16');
    expect(rewardedAdStartDay(config, DateTime.utc(2026, 10, 16, 15)), '2026-10-17');
  });

  test('서버 결과 불명은 환불하지 않고 증거 없는 확정 거래는 보류한다', () {
    expect(purchaseRecoveryAction(serverStatus: 'unknown',
        localDebitEvidence: true, localGrantApplied: false),
        PurchaseRecoveryAction.queryServer);
    expect(purchaseRecoveryAction(serverStatus: 'committed',
        localDebitEvidence: false, localGrantApplied: false),
        PurchaseRecoveryAction.needsEvidence);
    expect(purchaseRecoveryAction(serverStatus: 'canceled',
        localDebitEvidence: true, localGrantApplied: true),
        PurchaseRecoveryAction.needsEvidence);
    expect(purchaseRecoveryAction(serverStatus: 'canceled',
        localDebitEvidence: false, localGrantApplied: false),
        PurchaseRecoveryAction.releaseReservation);
    expect(purchaseRecoveryAction(serverStatus: 'committed',
        localDebitEvidence: true, localGrantApplied: true),
        PurchaseRecoveryAction.alreadyApplied);
  });
  test('회차 경계의 개별 올림과 금 증가·잔액0·보유 상한을 확인한다', () {
    final whole = quoteCompositeSkill(config, 'tap_1', owned: 9, quantity: 2);
    final first = quoteCompositeSkill(config, 'tap_1', owned: 9, quantity: 1);
    final second = quoteCompositeSkill(config, 'tap_1', owned: 10, quantity: 1);
    expect(whole.buns, first.buns + second.buns);
    expect(whole.gold, BigInt.from(3));
    expect(whole.affordable(whole.buns - BigInt.one, whole.gold), isFalse);
    expect(maximumCompositeSkill(config, 'tap_1', owned: 0,
        availableBuns: BigInt.zero, availableGold: BigInt.zero).quantity, 0);
    final cap = DevelopmentBalance.integer(config.section('skill_purchase'), 'max_owned_per_skill');
    expect(quoteCompositeSkill(config, 'tap_1', owned: cap, quantity: 0).buns, BigInt.zero);
    expect(() => quoteCompositeSkill(config, 'tap_1', owned: cap, quantity: 1), throwsFormatException);
  });

  test('광고 한도는 예약·검증대기도 포함하고 시작일 기준으로 분리한다', () {
    final beforeMidnight = DateTime.utc(2026, 10, 16, 14, 59);
    RewardedAdSlot slot(String id, RewardedAdSlotPhase phase) => RewardedAdSlot(
        accountId: 'a', attemptId: id, authorizedStart: beforeMidnight, phase: phase);
    final slots = [slot('one', RewardedAdSlotPhase.verifying),
      slot('two', RewardedAdSlotPhase.reserved)];
    expect(rewardedAdRemaining(config, accountId: 'a', serverNow: beforeMidnight,
        slots: slots), 0);
    expect(rewardedAdRemaining(config, accountId: 'a',
        serverNow: DateTime.utc(2026, 10, 16, 15), slots: slots), 2);
    expect(rewardedAdRemaining(config, accountId: 'b', serverNow: beforeMidnight,
        slots: slots), 2);
    expect(() => rewardedAdRemaining(config, accountId: 'a',
        serverNow: beforeMidnight, slots: [slots.first, slots.first]), throwsFormatException);
    expect(rewardedAdRemaining(config, accountId: 'a', serverNow: beforeMidnight,
        slots: [slot('no', RewardedAdSlotPhase.rejectedFinal)]), 2);
  });

  test('설정의 난이도 중복·금 증가량 손상·익힘 배율0은 거부한다', () {
    Map<String, dynamic> raw() => jsonDecode(
        File('config/development_balance.json').readAsStringSync()) as Map<String, dynamic>;
    final duplicate = raw();
    duplicate['mastery_difficulties'][1]['difficulty'] = 0;
    expect(() => DevelopmentBalance.fromJson(duplicate), throwsFormatException);
    final negative = raw();
    negative['skill_purchase']['gold_step_amount'] = -1;
    expect(() => DevelopmentBalance.fromJson(negative), throwsFormatException);
    final zero = raw();
    zero['doneness']['reference_scale'] = 0;
    expect(() => DevelopmentBalance.fromJson(zero), throwsFormatException);
  });

}
