import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cozy_style.dart';

/// Which startup read failed; decides what "처음부터 시작" sets aside.
enum SaveStage { account, config, workshop }

class SaveFailure {
  final SaveStage stage;
  final String error;
  final DateTime at;
  const SaveFailure(this.stage, this.error, this.at);
  String get place => switch (stage) {
        SaveStage.account => '설정과 꾸미기 저장',
        SaveStage.config => '게임 설정 파일',
        SaveStage.workshop => '가게 진행 저장',
      };
  /// Text for "오류 내용 복사", to paste into a support message.
  String report(int attempts) => '오늘의 붕어빵 저장 오류\n'
      '위치: $place (${stage.name})\n'
      '시각: ${at.toUtc().toIso8601String()}\n'
      '복구 시도: $attempts회\n'
      '내용: $error';
}

/// Startup screen when a save cannot be read (저장 손상 화면). Retry first;
/// after a failed retry "처음부터 시작" asks twice, then [onStartFresh] moves
/// the damaged file aside (never deletes it) and starts again.
class SaveRecoveryApp extends StatefulWidget {
  final SaveFailure failure;
  final int attempts;
  final Future<void> Function() onRetry;
  /// Null when starting over cannot help (a bundled file is broken).
  final Future<void> Function()? onStartFresh;
  const SaveRecoveryApp(
      {super.key, required this.failure, required this.attempts, required this.onRetry, this.onStartFresh});
  @override
  State<SaveRecoveryApp> createState() => _SaveRecoveryAppState();
}

class _SaveRecoveryAppState extends State<SaveRecoveryApp> {
  bool _working = false;
  String? _message;

  Future<void> _run(Future<void> Function() command) async {
    setState(() { _working = true; _message = null; });
    try {
      await command();
    } catch (e) {
      if (mounted) setState(() => _message = '진행하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirm(BuildContext context, {required Key key, required String title,
      required String body, required String action}) async =>
      await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(key: key, onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ])) == true;

  Future<void> _startFresh(BuildContext context) async {
    final lost = widget.failure.stage == SaveStage.account
        ? '이 기기의 설정과 꾸미기 착용 상태가'
        : '이 기기의 가게 진행(레벨, 붕어빵력, 재고, 손님 기록)이';
    if (!await _confirm(context, key: const Key('recovery-fresh-next'), title: '처음부터 시작할까요?',
        body: '$lost 처음으로 돌아가요. 손상된 저장은 지우지 않고 다른 이름으로 보관해요.', action: '다음')) {
      return;
    }
    if (!context.mounted) return;
    if (!await _confirm(context, key: const Key('recovery-fresh-confirm'), title: '정말 처음부터 시작할까요?',
        body: '시작하면 이 화면에서는 되돌릴 수 없어요. 문의가 필요하면 먼저 오류 내용을 복사해 두세요.',
        action: '처음부터 시작')) {
      return;
    }
    await _run(widget.onStartFresh!);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '오늘의 붕어빵',
      theme: cozyTheme(),
      home: Scaffold(
          backgroundColor: Cozy.creamDeep,
          body: SafeArea(child: Center(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Builder(builder: (context) => CozyPanel(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  radius: 16,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('저장을 열지 못했어요', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, color: Cozy.wood)),
                    const SizedBox(height: 8),
                    Text(widget.failure.stage == SaveStage.config
                        ? '게임 설정 파일을 읽지 못했어요. 앱을 업데이트하거나 다시 설치해 주세요.'
                        : '${widget.failure.place}을 읽는 중에 문제가 생겼어요. 먼저 복구를 시도해 주세요.',
                        textAlign: TextAlign.center),
                    if (widget.attempts > 0)
                      Text('복구를 ${widget.attempts}번 시도했지만 열리지 않았어요.', key: const Key('recovery-attempts'),
                          textAlign: TextAlign.center, style: const TextStyle(color: Cozy.brick)),
                    const SizedBox(height: 10),
                    Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Cozy.knob, borderRadius: BorderRadius.circular(8)),
                        child: SingleChildScrollView(child: SelectableText(widget.failure.error,
                            key: const Key('recovery-error'), style: const TextStyle(fontSize: 12, color: Cozy.inkSoft)))),
                    if (_message != null)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message!,
                          key: const Key('recovery-message'), textAlign: TextAlign.center,
                          style: const TextStyle(color: Cozy.brick))),
                    const SizedBox(height: 12),
                    if (_working) const Center(child: Padding(padding: EdgeInsets.only(bottom: 8),
                        child: CircularProgressIndicator())),
                    CozyPrimaryButton(key: const Key('recovery-retry'), label: '복구 시도',
                        onPressed: _working ? null : () => _run(widget.onRetry)),
                    const SizedBox(height: 8),
                    CozyButton(key: const Key('recovery-copy'), label: '오류 내용 복사', fontSize: 16,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: widget.failure.report(widget.attempts)));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오류 내용을 복사했어요.')));
                          }
                        }),
                    if (widget.attempts > 0 && widget.onStartFresh != null) ...[
                      const SizedBox(height: 8),
                      CozyButton(key: const Key('recovery-fresh'), label: '처음부터 시작', fontSize: 16,
                          onPressed: _working ? null : () => _startFresh(context)),
                    ],
                  ]))))))));
}
