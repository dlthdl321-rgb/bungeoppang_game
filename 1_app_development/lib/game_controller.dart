import 'dart:async';
import 'package:flutter/foundation.dart';
import 'workshop_online.dart';
import 'models.dart';
import 'music_config.dart';
import 'repository.dart';
import 'time_service.dart';
import 'invite_reward_rules.dart';
import 'cosmetic_config.dart';
import 'billing_service.dart';
import 'online_backend.dart';
import 'online_texts.dart';
import 'premium_config.dart';
import 'online_ranking.dart';
import 'ranking_config.dart';
import 'usage_stats.dart';

part 'online_controller.dart';
part 'premium_controller.dart';
part 'menu_controller.dart';
part 'ranking_controller.dart';

/// The account side of the app (32번 2단계, 2026-11-25): settings, the
/// online account (sign-in, friends, visits, invitations, ranking), the
/// 황금 wallet with Google Play packs, usage stats and the old wardrobe's
/// worn look. The game itself is [WorkshopController]; the old clicker's
/// tapping, levels, missions, weekly goals, achievements, prestige, offline
/// reward, coin rewards and boosts are gone (DEC-155).
class GameController extends ChangeNotifier {
  final GameRepository repository;
  final TimeService clock;
  // The old wardrobe's catalog (worn look only). Injectable for tests.
  final List<CosmeticDefinition> cosmetics;
  final RankingService ranking;
  RankingStatus rankingStatus = RankingStatus.unavailable;
  bool _disposed = false;
  late GameState state;
  bool _away = false, busy = false;
  Timer? _ticker, _periodicSave;
  String? error;
  Completer<void>? _commitDone;

  /// Firebase backend (online_controller.dart): friends, visits, invites.
  final OnlineBackend online;
  bool _onlineSyncing = false, _levelOneReported = false, _signingIn = false;
  /// 29번 친구 초대: whether the NEW game (WorkshopController) reached the
  /// invitation's goal level ([InviteRewardRules.goalReached]); set by the
  /// app's wiring. Null: never report.
  bool Function()? inviteGoalReached;
  /// DEC-154: friends' visits go to the NEW game (its production boost),
  /// set by the app's wiring: the visits it has seen, and where to hand new
  /// ones. Null: visits are left on the server.
  Set<String> Function()? seenFriendVisits;
  Future<void> Function(List<ServerVisit> visits)? onFriendVisits;
  int _inviteRetryAtMs = 0;
  /// The owner name (사장님 이름) friends and rankings show, and how the
  /// player logs in; both set by OwnerAccount (26번 2-1단계).
  String? ownerName;
  LoginProvider? preferredLogin;
  int? _lastOnlineSyncMs;

  /// Google Play Billing for 황금 붕어빵 packs (premium_controller.dart).
  final BillingService billing;

  /// 사용 통계(26번 5단계). Follows the '사용 통계 보내기' setting.
  final UsageStats usage;
  StreamSubscription<BillingPurchase>? _billingSub;

  /// Last wallet message for the shop ('충전 완료', ...), or null.
  String? premiumNotice;
  GameController(this.repository, this.clock,
      {this.cosmetics = cosmeticDefinitions,
      this.ranking = const NoRankingService(),
      this.online = const NoOnlineBackend(),
      this.billing = const NoBillingService(),
      UsageStats? usage})
      : usage = usage ?? UsageStats.none;

  // For command extensions, which cannot call notifyListeners.
  void _notifyChanged() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      state = await repository.load() ?? GameState.initial(clock.utcNow);
    } on FormatException catch (e) {
      error = '저장 데이터 손상: ${e.message}';
      rethrow;
    }
    usage.setEnabled(state.settings.sendUsageStats);
    _away = false;
    unawaited(refreshRanking());
    _ticker?.cancel();
    _periodicSave?.cancel();
    _billingSub ??= billing.purchases.listen((p) => unawaited(_onPurchase(p)));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    _periodicSave = Timer.periodic(const Duration(seconds: 10), (_) => save());
  }

  /// The account clock: only the online sync when it is due.
  void tick() {
    if (_away || busy || _disposed) return;
    _syncOnlineIfDue(clock.monotonicMilliseconds);
  }

  Future<bool> _commit(GameState before) async {
    busy = true;
    _commitDone = Completer<void>();
    state.snapshotSequence++;
    try {
      await repository.save(state.copy());
      error = null;
      return true;
    } catch (_) {
      state = before;
      error = '저장 실패. 다시 시도해 주세요.';
      return false;
    } finally {
      busy = false;
      _commitDone!.complete();
      _commitDone = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> save() async {
    if (busy) return;
    state.snapshotSequence++;
    try {
      await repository.save(state.copy());
      error = null;
    } catch (_) {
      error = '저장 실패. 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// The app went to the background: save and stop syncing until [resume].
  Future<void> leaveActive() async {
    if (busy) await _commitDone?.future;
    if (_away) return;
    _away = true;
    await save();
  }

  /// The app came back.
  Future<void> resume() async {
    if (busy) await _commitDone?.future;
    if (!_away) return;
    _away = false;
    if (_ticker != null) unawaited(refreshRanking());
    notifyListeners();
  }

  /// Waits out in-flight commits: a change made mid-commit would miss that
  /// snapshot, be skipped by [save], and be erased if the commit rolls back.
  Future<void> _untilIdle() async {
    while (busy) {
      final done = _commitDone;
      if (done == null) return;
      await done.future;
    }
  }

  Future<void> _settingsQueue = Future<void>.value();

  /// One save per call: sliders should call this on release, not per frame.
  Future<void> updateSettings(
      {bool? vibration,
      bool? hold,
      bool? reduceMotion,
      bool? soundEffects,
      bool? music,
      int? sfxVolume,
      int? musicVolume,
      String? musicSelection,
      bool? cookingSound,
      int? cookingVolume,
      bool? notifyRegularGuests,
      bool? notifyNamedGuests,
      bool? quietNightNotices,
      bool? notificationPromptDone,
      bool? sendUsageStats}) async {
    final previous = _settingsQueue;
    final done = Completer<void>();
    _settingsQueue = done.future;
    try {
      await previous;
      if (musicSelection != null && !validMusicSelection(musicSelection)) {
        throw const FormatException('잘못된 배경음 선택');
      }
      await _untilIdle();
      if (_disposed) return;
      final before = state.copy();
      final s = state.settings;
      s.musicSelection = musicSelection ?? s.musicSelection;
      s.cookingSound = cookingSound ?? s.cookingSound;
      s.cookingVolume = (cookingVolume ?? s.cookingVolume).clamp(0, 100);
      s.vibration = vibration ?? s.vibration;
      s.holdToBake = hold ?? s.holdToBake;
      s.reduceMotion = reduceMotion ?? s.reduceMotion;
      s.soundEffects = soundEffects ?? s.soundEffects;
      s.music = music ?? s.music;
      s.sfxVolume = (sfxVolume ?? s.sfxVolume).clamp(0, 100);
      s.musicVolume = (musicVolume ?? s.musicVolume).clamp(0, 100);
      s.notifyRegularGuests = notifyRegularGuests ?? s.notifyRegularGuests;
      s.notifyNamedGuests = notifyNamedGuests ?? s.notifyNamedGuests;
      s.quietNightNotices = quietNightNotices ?? s.quietNightNotices;
      s.notificationPromptDone = notificationPromptDone ?? s.notificationPromptDone;
      s.sendUsageStats = sendUsageStats ?? s.sendUsageStats;
      // Restore the previous settings if this one-shot save fails.
      await _commit(before);
      // The kept value, also when the save failed and restored the old one.
      if (sendUsageStats != null) usage.setEnabled(state.settings.sendUsageStats);
    } finally {
      done.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _billingSub?.cancel();
    _ticker?.cancel();
    _periodicSave?.cancel();
    super.dispose();
  }
}
