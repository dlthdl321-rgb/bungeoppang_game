import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'cosmetic_config.dart';
import 'game_controller.dart';
import 'online_backend.dart';
import 'owner_profile.dart';
import 'owner_repository.dart';
import 'owner_texts.dart';
import 'usage_stats.dart';
import 'workshop_controller.dart';

/// Where the first run stands (26번 2-1단계). The game shows once [done].
enum OwnerStep { offline, login, name, character, optional, done }

/// Where the optional gender and age band go as analytics user properties.
/// 26번 5단계 connects it to Firebase Analytics ([UsageOwnerAnalytics]).
/// Never the email or the name.
abstract class OwnerAnalytics {
  /// Null clears a property (no consent or skipped).
  void setUserProperties({String? gender, String? ageBand});
  /// The first-run required consent is done (DEC-126): usage
  /// statistics start only then.
  void setConsented(bool consented);
}

/// 26번 5단계: the optional info as the Analytics user properties gender and
/// age_band ('선택 안 함' sends nothing). The '사용 통계 보내기' switch stops
/// the whole Analytics collection, these included.
class UsageOwnerAnalytics implements OwnerAnalytics {
  final UsageStats usage;
  const UsageOwnerAnalytics(this.usage);
  @override
  void setUserProperties({String? gender, String? ageBand}) => usage.setUserProperties(
      gender: gender == PlayerGender.none.id ? null : gender,
      ageBand: ageBand == AgeBand.none.id ? null : ageBand);
  @override
  void setConsented(bool consented) => usage.setConsented(consented);
}

/// Is there a connection? A DNS lookup with a short timeout; tests pass a
/// fake.
Future<bool> lookupInternet() async {
  try {
    final found = await InternetAddress.lookup('firebase.google.com')
        .timeout(const Duration(seconds: 4));
    return found.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// The owner (사장님) behind the shop: the required login, the name, the
/// character question and the optional info, plus logout and account
/// deletion from the settings. The first-run screens and the settings call
/// these commands; [step] tells GameApp what to show.
class OwnerAccount extends ChangeNotifier {
  final OwnerProfileRepository repository;
  final OnlineBackend online;
  final OwnerNameRules rules;
  final GameController game;
  final WorkshopController? workshop;
  final Future<bool> Function() hasInternet;
  final OwnerAnalytics? analytics;
  final DateTime Function() now;
  /// After a deleted account: wipe this device's saves and start over
  /// (main.dart). Null in tests: the first-run screens simply come back.
  Future<void> Function()? onDeleted;

  OwnerAccount(
      {required this.repository,
      required this.online,
      required this.rules,
      required this.game,
      this.workshop,
      Future<bool> Function()? hasInternet,
      this.analytics,
      DateTime Function()? now,
      this.onDeleted})
      : hasInternet = hasInternet ?? lookupInternet,
        now = now ?? DateTime.now;

  OwnerProfile profile = OwnerProfile();
  bool busy = false, offline = false;
  /// The last problem to show on the current screen, or null.
  String? message;
  /// A first name to offer: the login nickname, cleaned up.
  String nameDraft = '';

  /// Reads the saved answers and hands the name to the online sync. A
  /// signed-in player whose server profile is behind gets it sent again.
  Future<void> load() async {
    try {
      profile = await repository.load() ?? OwnerProfile();
    } catch (_) {
      // An unreadable profile only means asking the first-run questions
      // again; the game progress is in the other saves.
      profile = OwnerProfile();
    }
    _apply();
    if (online.signedIn && !profile.serverSynced) unawaited(pushProfile());
  }

  void _apply() {
    game.ownerName = profile.name;
    game.preferredLogin = profile.provider;
    analytics?.setConsented(requiredConsentDone);
    final info = profile.optional;
    analytics?.setUserProperties(gender: info?.gender.id, ageBand: info?.ageBand.id);
  }

  /// The current required consent (terms, privacy, 만 14세 이상) was given on
  /// this device. Builds without the login do not ask it (and send no
  /// statistics either).
  bool get requiredConsentDone =>
      !loginRequired || profile.consentVersion == requiredConsentVersion;

  /// Builds without Firebase (development, tests of the old screens) skip
  /// the login and the server-only optional info.
  bool get loginRequired => online.configured;

  OwnerStep get step {
    if (loginRequired) {
      if (offline) return OwnerStep.offline;
      if (!online.signedIn || profile.account == null ||
          profile.account != online.accountId ||
          profile.consentVersion != requiredConsentVersion) {
        return OwnerStep.login;
      }
    }
    if (profile.name == null) return OwnerStep.name;
    if (!profile.characterChosen) return OwnerStep.character;
    if (loginRequired && !profile.optionalAsked) return OwnerStep.optional;
    return OwnerStep.done;
  }

  /// The character the picker starts on: what the shop already wears.
  String get currentCharacter =>
      workshop?.state.avatarEquipment[CosmeticSlot.character.name] ??
      game.state.equippedCosmetic(CosmeticSlot.character);

  Future<T?> _run<T>(Future<T> Function() work) async {
    if (busy) return null;
    busy = true;
    message = null;
    notifyListeners();
    try {
      return await work();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    await repository.save(profile);
    _apply();
  }

  /// The required consent was given and the player chose [provider].
  Future<void> signIn(LoginProvider provider) => _run(() async {
        if (!await hasInternet()) {
          offline = true;
          return;
        }
        final result = await online.signIn(provider);
        switch (result) {
          case SignInResult.canceled:
            return;
          case SignInResult.offline:
            offline = true;
            return;
          case SignInResult.failed:
            message = OwnerTexts.loginFailed;
            return;
          case SignInResult.success:
            await _bind(provider);
        }
      });

  /// Already signed in (a player from before this update): only the
  /// required consent is new.
  Future<void> acceptConsent() => _run(() async {
        if (!online.signedIn) return;
        await _bind(online.loginProvider ?? LoginProvider.kakao);
      });

  /// The account that already owns this device's shop: the profile's, or the
  /// one the workshop save sent its rewards and purchases with.
  String? get _boundAccount =>
      profile.account ?? workshop?.state.rewardAccount ?? workshop?.state.purchases.account;

  Future<void> _bind(LoginProvider provider) async {
    final id = online.accountId;
    final bound = _boundAccount;
    if (id == null) {
      message = OwnerTexts.loginFailed;
      return;
    }
    if (bound != null && bound != id) {
      // One shop per device: the progress stays with its first account.
      final owner = profile.provider ??
          (bound.startsWith('kakao:') ? LoginProvider.kakao : LoginProvider.google);
      await online.signOut();
      message = OwnerTexts.otherAccount(owner);
      return;
    }
    profile
      ..account = id
      ..provider = provider
      ..consentVersion = requiredConsentVersion
      ..consentAtMs = now().millisecondsSinceEpoch
      ..serverSynced = false;
    if (profile.name == null) nameDraft = rules.suggestion(online.displayName);
    await _save();
    if (profile.name != null) unawaited(pushProfile());
    // Friends, rankings and the wallet catch up in the background.
    unawaited(game.syncOnline());
  }

  /// Back from the offline screen: check the connection again.
  Future<void> retry() => _run(() async {
        offline = !await hasInternet();
      });

  /// Sets the owner name (first run and the settings). The problem, or null.
  Future<String?> setName(String raw) async {
    final problem = rules.problem(raw);
    if (problem != null) {
      message = problem;
      notifyListeners();
      return problem;
    }
    await _run(() async {
      profile
        ..name = raw.trim()
        ..serverSynced = false;
      await _save();
    });
    unawaited(pushProfile());
    unawaited(game.syncOnline());
    return null;
  }

  /// The 여자/남자 사장님 choice: worn in the shop at once and the shop's
  /// for good. The other one is bought in 꾸미기 (3차 피드백 H11); once the
  /// choice is made, this only wears what is owned.
  Future<String?> chooseCharacter(String id) async {
    final shop = workshop;
    if (shop != null &&
        !await (profile.characterChosen ? shop.equipAvatar(id) : shop.chooseStarterCharacter(id))) {
      return message = shop.notice ?? '사장님을 고르지 못했어요';
    }
    await _run(() async {
      profile.characterChosen = true;
      await _save();
    });
    return null;
  }

  /// The optional answers with their consent.
  Future<void> saveOptional({required PlayerGender gender, required AgeBand ageBand}) async {
    await _run(() async {
      profile
        ..optionalAsked = true
        ..optional = OptionalInfo(gender: gender, ageBand: ageBand, agreedAtMs: now().millisecondsSinceEpoch)
        ..serverSynced = false;
      await _save();
    });
    unawaited(pushProfile());
  }

  Future<void> skipOptional() => _run(() async {
        profile.optionalAsked = true;
        await _save();
      });

  /// Settings: forget the gender and age band (here and on the server).
  Future<void> clearOptional() async {
    await _run(() async {
      profile
        ..optional = null
        ..serverSynced = false;
      await _save();
    });
    unawaited(pushProfile());
  }

  /// Sends the name, consent and optional info to the server profile. A
  /// failure (offline) leaves [OwnerProfile.serverSynced] false for the next
  /// start or change.
  Future<void> pushProfile() async {
    final name = profile.name, consent = profile.consentVersion, info = profile.optional;
    if (!online.signedIn || name == null || consent == null || profile.account != online.accountId) return;
    try {
      await online.saveAccountProfile(AccountProfileUpdate(
          name: name,
          consentVersion: consent,
          // The current consent always comes with the 만 14세 이상 tick.
          over14Confirmed: consent == requiredConsentVersion,
          gender: info?.gender.id,
          ageBand: info?.ageBand.id));
      if (profile.name == name && profile.optional == info) {
        profile.serverSynced = true;
        await repository.save(profile);
      }
    } on OnlineException {
      // Offline or not set up: tried again later.
    }
  }

  /// Settings: log out. The device keeps its progress; the login screen
  /// comes back and the same account continues it.
  Future<void> signOut() => _run(() async {
        await game.signOutOnline();
        offline = false;
      });

  /// Settings: delete the account (Google Play: in the app). The server
  /// removes everything; then this device's saves go too. The problem, or
  /// null once deleted.
  Future<String?> deleteAccount() async {
    String? problem;
    var deleted = false;
    await _run(() async {
      if (!await hasInternet()) {
        problem = OwnerTexts.deleteOffline;
        return;
      }
      try {
        await online.deleteAccount();
      } on OnlineException {
        problem = OwnerTexts.deleteFailed;
        return;
      }
      await repository.clear();
      profile = OwnerProfile();
      nameDraft = '';
      _apply();
      deleted = true;
    });
    // Busy with something else (_run skipped the work): nothing was deleted,
    // so the device saves must stay.
    if (!deleted) return problem ?? OwnerTexts.deleteFailed;
    await onDeleted?.call();
    return null;
  }
}
