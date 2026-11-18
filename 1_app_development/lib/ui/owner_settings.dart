import 'package:flutter/material.dart';
import '../owner_account.dart';
import '../owner_texts.dart';
import 'cozy_style.dart';
import 'first_run.dart';

/// The 계정 part of the settings window (26번 2-1단계): owner name, login,
/// optional info, the policies, logout and account deletion. [closeWindow]
/// closes the settings window before logging out or deleting; [notify] shows
/// a short message on the page.
class OwnerSettingsSection extends StatelessWidget {
  final OwnerAccount owner;
  final VoidCallback closeWindow;
  final void Function(String message) notify;
  const OwnerSettingsSection({super.key, required this.owner, required this.closeWindow, required this.notify});

  Future<void> _rename(BuildContext context) =>
      showDialog<void>(context: context, builder: (_) => _RenameDialog(owner: owner));

  Future<void> _changeOptional(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
          key: const Key('optional-dialog'),
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text(OwnerTexts.optionalInfo, style: TextStyle(fontSize: 20)),
                const SizedBox(height: 8),
                OptionalInfoForm(
                    initial: owner.profile.optional,
                    skipLabel: OwnerTexts.cancel,
                    saveLabel: OwnerTexts.save,
                    onSkip: () => Navigator.pop(ctx),
                    onSave: (gender, age, guardian) async {
                      Navigator.pop(ctx);
                      await owner.saveOptional(gender: gender, ageBand: age, guardianConsent: guardian);
                      final message = owner.message;
                      if (message != null) {
                        owner.message = null;
                        notify(message);
                      }
                    }),
              ]))));

  Future<void> _logout(BuildContext context) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(content: const Text(OwnerTexts.logoutConfirm), actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(OwnerTexts.cancel)),
              FilledButton(
                  key: const Key('logout-confirm'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(OwnerTexts.logout)),
            ]));
    if (yes != true) return;
    closeWindow();
    await owner.signOut();
  }

  Future<void> _delete(BuildContext context) async {
    var checked = false;
    final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
                    key: const Key('delete-dialog'),
                    title: const Text(OwnerTexts.deleteTitle),
                    content: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(OwnerTexts.deleteBody, style: TextStyle(fontSize: 14)),
                      ConsentRow(
                          key: const Key('delete-check'),
                          value: checked,
                          label: OwnerTexts.deleteCheck,
                          onChanged: (v) => setState(() => checked = v)),
                    ])),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(OwnerTexts.cancel)),
                      FilledButton(
                          key: const Key('delete-confirm'),
                          style: FilledButton.styleFrom(backgroundColor: Cozy.brick),
                          onPressed: checked ? () => Navigator.pop(ctx, true) : null,
                          child: const Text(OwnerTexts.deleteConfirm)),
                    ])));
    if (yes != true) return;
    closeWindow();
    final problem = await owner.deleteAccount();
    if (problem != null) notify(problem);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: owner,
      builder: (context, _) {
        final info = owner.profile.optional;
        final online = owner.loginRequired;
        final optionalText = info == null ? OwnerTexts.optionalNone : '${info.gender.label} · ${info.ageBand.label}';
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(OwnerTexts.accountSection, style: TextStyle(fontSize: 18)),
          CozyPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text('${OwnerTexts.ownerName}: ${owner.profile.name ?? '-'}',
                      key: const Key('settings-owner-name'), style: const TextStyle(fontSize: 16))),
              TextButton(
                  key: const Key('settings-rename'),
                  onPressed: owner.busy ? null : () => _rename(context),
                  child: const Text(OwnerTexts.rename)),
            ]),
            if (online) ...[
              Text(OwnerTexts.loggedInWith(owner.online.loginProvider),
                  key: const Key('settings-login'), style: const TextStyle(fontSize: 14, color: Cozy.inkSoft)),
              const Divider(),
              Text('${OwnerTexts.optionalInfo}: $optionalText',
                  key: const Key('settings-optional'), style: const TextStyle(fontSize: 15)),
              Wrap(spacing: 4, children: [
                TextButton(
                    key: const Key('settings-optional-change'),
                    onPressed: owner.busy ? null : () => _changeOptional(context),
                    child: const Text(OwnerTexts.change)),
                if (info != null)
                  TextButton(
                      key: const Key('settings-optional-clear'),
                      onPressed: owner.busy
                          ? null
                          : () async {
                              await owner.clearOptional();
                              notify(OwnerTexts.optionalCleared);
                            },
                      child: const Text(OwnerTexts.clearOptional)),
              ]),
            ],
            const Divider(),
            Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
              TextButton(
                  onPressed: () => showLegalDocument(context, LegalDocument.terms),
                  child: const Text(OwnerTexts.terms)),
              TextButton(
                  onPressed: () => showLegalDocument(context, LegalDocument.privacy),
                  child: const Text(OwnerTexts.privacy)),
            ]),
            if (online && owner.online.signedIn)
              Row(children: [
                Expanded(
                    child: CozyButton(
                        key: const Key('settings-logout'),
                        onPressed: owner.busy ? null : () => _logout(context),
                        label: OwnerTexts.logout,
                        minHeight: 40,
                        fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextButton(
                        key: const Key('settings-delete-account'),
                        style: TextButton.styleFrom(foregroundColor: Cozy.brick),
                        onPressed: owner.busy ? null : () => _delete(context),
                        child: const Text(OwnerTexts.deleteAccount))),
              ]),
          ])),
          const SizedBox(height: 8),
        ]);
      });
}

/// Owns its text box so the box outlives the closing animation.
class _RenameDialog extends StatefulWidget {
  final OwnerAccount owner;
  const _RenameDialog({required this.owner});
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _text = TextEditingController(text: widget.owner.profile.name ?? '');
  String? _problem;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          key: const Key('rename-dialog'),
          title: const Text(OwnerTexts.rename),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            OwnerNameField(controller: _text, rules: widget.owner.rules),
            const Text(OwnerTexts.nameHelp, style: TextStyle(fontSize: 12, color: Cozy.inkSoft)),
            if (_problem != null)
              Text(_problem!, key: const Key('rename-problem'), style: const TextStyle(color: Cozy.brick)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text(OwnerTexts.cancel)),
            FilledButton(
                key: const Key('rename-save'),
                onPressed: () async {
                  final error = await widget.owner.setName(_text.text);
                  widget.owner.message = null;
                  if (!context.mounted) return;
                  if (error == null) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _problem = error);
                  }
                },
                child: const Text(OwnerTexts.save)),
          ]);
}
