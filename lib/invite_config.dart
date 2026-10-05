import 'support_config.dart';

// Estimated prototype policy; not a claim about a particular public season.
const inviteEvidence = 'estimated';
// Reward item/count and daily reset are corroborated in a public review;
// identity, exact occurrence semantics and all server rules remain estimates.
const inviteRewardEvidence = 'public-review';
const inviteRewardSource =
    'https://dailysejong.tistory.com/entry/당근마켓-붕어빵게임-공략-총정리레벨-10-달성';
const inviteConfigVersion = 'invites-v1';
const newInviteReward = RewardDefinition('0', {'fairy': '1'});
const existingInviteReward = RewardDefinition('0', {'butter': '1'});
const inviteTicketLimit = 1000;
const inviteVisitLimit = 1000;
const inviteEventLimit = 5000;
// Reserved non-resolving domain: never send prototype referrals to a real host.
const mockInviteBaseUrl = 'https://example.invalid/todays-bungeoppang/invite';
