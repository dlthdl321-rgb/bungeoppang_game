import 'pantry_rules.dart';
import 'workshop_controller.dart';

/// 재료 준비 창의 명령 (재료 타이쿤 D, 2026-11-21): making tubs after a
/// mini-game and '모자란 재료 한 번에 사기'. Kept apart from
/// workshop_controller.dart (other 재료 타이쿤 packages edit it at the same
/// time); each one is a normal [WorkshopController.command], so it saves
/// once and rolls back on a `FormatException` (the Korean reason becomes
/// the notice line).
///
/// 재료 준비는 영업 준비 중에만 (사용자 결정 2026-11-21): both refuse while
/// the shop is open.
extension WorkshopPantryPrep on WorkshopController {
  /// Why the 재료 준비 window cannot open now (Korean), or null.
  String? get pantryPrepLock => state.business.open ? pantryPrepClosedText : null;

  int get _nowMs => now().millisecondsSinceEpoch;

  /// The mini-game ended (or the screen reader's '보통으로 만들기', with
  /// [success] false): uses the ingredients for [tubs] tubs of [kind] and
  /// adds them, with the bonus on [success]. Null if it did not go through
  /// ([notice] says why).
  Future<PantryMakeResult?> makePrepared(String kind, int tubs, {bool premium = false, required bool success}) async {
    PantryMakeResult? made;
    final ok = await command(() {
      if (pantryPrepLock case final lock?) throw FormatException(lock);
      // Tubs past their time were already thrown away by [command] (4차 병합 3).
      made = state.pantry.make(pantryConfig, kind, tubs, state.level, _nowMs, state.recipes,
          premium: premium, success: success);
    });
    return ok ? made : null;
  }

  /// What '모자란 재료 한 번에 사기' costs for [tubs] tubs of [kind] now
  /// (zero when nothing is missing).
  BigInt prepShortfallCost(String kind, int tubs) => state.pantry.shortfallCost(pantryConfig, kind, tubs, pantryRate);

  /// '모자란 재료 한 번에 사기' in the 재료 준비 window: buys the missing
  /// basic ingredients with 붕어빵력 in one save.
  Future<bool> buyPrepShortfall(String kind, int tubs) => command(() {
        if (pantryPrepLock case final lock?) throw FormatException(lock);
        final cost = prepShortfallCost(kind, tubs);
        if (cost > state.buns) throw const FormatException('붕어빵력이 모자라요.');
        state.pantry.buyShortfall(pantryConfig, kind, tubs, pantryRate, state.recipes);
        state.buns -= cost;
      });
}

/// The toast when 재료 준비 is tried in business.
const pantryPrepClosedText = '재료 준비는 영업 준비 중에만 할 수 있어요. 영업을 마친 뒤에 준비해 주세요.';
