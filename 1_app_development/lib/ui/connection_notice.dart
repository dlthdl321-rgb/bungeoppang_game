import 'package:flutter/material.dart';
import '../online_texts.dart';
import '../owner_texts.dart';
import 'cozy_style.dart';
import 'first_run.dart';
import 'pixel_sprites.dart';

// 4차 피드백 IC10: the game is online-only. An online build that has no
// connection (at the start or while playing) shows [ConnectionLostNotice]
// over every screen and window until '다시 시도' finds it again; a release
// build made without the online settings shows only [OnlineSetupMissingApp].

/// Covers everything (GameApp puts it above the navigator, so sheets and
/// dialogs are covered too) and takes every touch.
class ConnectionLostNotice extends StatelessWidget {
  final bool checking;
  final VoidCallback onRetry;
  const ConnectionLostNotice({super.key, required this.checking, required this.onRetry});
  @override
  Widget build(BuildContext context) => Material(
      key: const Key('connection-lost'),
      color: const Color(0xcc1b1530),
      child: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _NoticeCard(
                          // 4차 피드백: a fainted bungeoppang with X eyes,
                          // large (25번 59번, icons/conn_fainted.png
                          // 192x192); until it is drawn, the bun icon.
                          emblem: PixelImage(PixelSprites.icon('conn_fainted') ?? PixelSprites.icon('bun'),
                              key: const Key('connection-lost-icon'), size: connectionLostIconSize),
                          title: OnlineTexts.lostTitle,
                          body: OnlineTexts.lostBody,
                          bodyKey: const Key('connection-lost-body'),
                          action: FirstRunButton(
                              key: const Key('connection-retry'),
                              label: checking ? OnlineTexts.checking : OnlineTexts.retry,
                              onPressed: checking ? null : onRetry)))))));
}

/// A thin band at the top of a debug build made without the online
/// settings, so its blocked level-ups and purchases are not mistaken for a
/// missing connection. Release builds without them do not start the game.
class DevBuildBand extends StatelessWidget {
  const DevBuildBand({super.key});
  @override
  // One thin line at the very top (in the status bar on a phone), so it
  // hides as little of the game as it can.
  Widget build(BuildContext context) => IgnorePointer(
      child: Align(
          alignment: Alignment.topCenter,
          child: Container(
              key: const Key('dev-build-band'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: const BoxDecoration(
                  color: Color(0xd9c0392b), borderRadius: BorderRadius.vertical(bottom: Radius.circular(6))),
              child: const Text(OnlineTexts.devBuild,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Jua',
                      fontFamilyFallback: Cozy.fontFallback,
                      fontSize: 10,
                      color: Colors.white,
                      height: 1.2,
                      decoration: TextDecoration.none)))));
}

/// The only screen of a release build made without the online settings.
class OnlineSetupMissingApp extends StatelessWidget {
  const OnlineSetupMissingApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: OwnerTexts.appTitle,
      theme: cozyTheme(),
      home: Scaffold(
          backgroundColor: Cozy.woodDark,
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: const _NoticeCard(
                              title: OnlineTexts.releaseNotSetUpTitle,
                              body: OnlineTexts.releaseNotSetUpBody,
                              bodyKey: Key('online-setup-missing'))))))));
}

/// The connection notice's picture size (logical px, 4차 피드백: about 104).
const connectionLostIconSize = 104.0;

class _NoticeCard extends StatelessWidget {
  final String title, body;
  final Key bodyKey;
  final Widget? action;
  final Widget emblem;
  const _NoticeCard(
      {required this.title, required this.body, required this.bodyKey, this.action,
      this.emblem = const PixelIcon('bun', size: 48)});
  @override
  Widget build(BuildContext context) => FirstRunCard(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: emblem),
        const SizedBox(height: 6),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Cozy.ink)),
        const SizedBox(height: 10),
        const Icon(Icons.wifi_off_rounded, size: 36, color: Cozy.taupe),
        const SizedBox(height: 8),
        Text(body, key: bodyKey, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Cozy.ink, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 16), Center(child: action!)],
      ]));
}
