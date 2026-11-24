import 'package:flutter/foundation.dart';

import 'development_balance.dart';

/// 친구 초대는 정식 출시 때 연다 (DEC-150). Until then the new home's menu
/// keeps '친구' hidden (가출시: DEC-029); the server and the level report
/// already work. Turn on for the official launch build.
const inviteLaunched = false;
@visibleForTesting
bool? debugInviteLaunchedOverride;
bool get invitesLaunched => debugInviteLaunchedOverride ?? inviteLaunched;

/// 29번 친구 초대 보상 (DEC-151, `invite_rewards` in the shared balance).
/// The server pays every gold piece (`functions/src/invites.ts`); the app
/// only knows when to tell it that the invited player reached the goal and
/// what to say on screen.
class InviteRewardRules {
  final int inviterGold, inviteeGold, targetLevel, dailyLimit, lifetimeLimit;
  /// The new home's '친구' menu opens from this level.
  final int menuLevel;
  const InviteRewardRules({required this.inviterGold, required this.inviteeGold, required this.targetLevel,
      required this.dailyLimit, required this.lifetimeLimit, required this.menuLevel});
  factory InviteRewardRules.fromConfig(DevelopmentBalance config) {
    final row = config.section('invite_rewards');
    return InviteRewardRules(
        inviterGold: DevelopmentBalance.integer(row, 'inviter_gold'),
        inviteeGold: DevelopmentBalance.integer(row, 'invitee_gold'),
        targetLevel: DevelopmentBalance.integer(row, 'target_level'),
        dailyLimit: DevelopmentBalance.integer(row, 'inviter_daily_limit'),
        lifetimeLimit: DevelopmentBalance.integer(row, 'inviter_lifetime_limit'),
        menuLevel: DevelopmentBalance.integer(row, 'menu_unlock_level'));
  }

  /// The new game's level [workshopLevel] is the invitation's goal. The
  /// server checks its own record of the level before paying.
  bool goalReached(int workshopLevel) => workshopLevel >= targetLevel;

  /// How the friends window explains it (shown once invites launch).
  String get guide => '친구가 내 아이디를 입력하면 친구는 황금 $inviteeGold개를 받고, '
      '친구 가게가 Lv.$targetLevel이 되면 나도 황금 $inviterGold개를 받아요. '
      '(하루 $dailyLimit명, 모두 $lifetimeLimit명까지)';
}

/// How long the app waits before asking the server again when it answered
/// "not yet" (its record of the level is behind, or the inviter's day is full).
const inviteGoalRetryMs = 30 * 60 * 1000;
