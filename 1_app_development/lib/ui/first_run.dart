import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../online_backend.dart';
import '../owner_account.dart';
import '../owner_profile.dart';
import '../owner_texts.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';

// 26번 2-1단계: the first-run screens before the game. ① required consent +
// login (Kakao or Google) → ② owner name → ③ 여자/남자 사장님 → ④ optional
// gender and age band, then the game and its first-run guide. Also the
// account part of the settings (name, optional info, logout, deletion).

/// Shows the first-run screens until [OwnerAccount.step] is done, then
/// [game]. Logging out brings the login screen back over the same game.
class OwnerGate extends StatelessWidget {
  final OwnerAccount owner;
  final Widget Function() game;
  const OwnerGate({super.key, required this.owner, required this.game});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: owner,
      builder: (context, _) =>
          owner.step == OwnerStep.done ? game() : FirstRunFlow(owner: owner));
}

class FirstRunFlow extends StatelessWidget {
  final OwnerAccount owner;
  const FirstRunFlow({super.key, required this.owner});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Cozy.creamDeep,
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: switch (owner.step) {
                        OwnerStep.offline => _OfflineStep(owner: owner),
                        OwnerStep.login => _LoginStep(owner: owner),
                        OwnerStep.name => _NameStep(owner: owner),
                        OwnerStep.character => _CharacterStep(owner: owner),
                        OwnerStep.optional || OwnerStep.done => _OptionalStep(owner: owner),
                      })))));
}

/// Title, a step heading and the step's panel.
class _StepPage extends StatelessWidget {
  final String title;
  final String? lead;
  final List<Widget> children;
  final bool emblem;
  const _StepPage({required this.title, this.lead, required this.children, this.emblem = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (emblem) ...[
          const Center(child: PixelIcon('bun', size: 88)),
          const SizedBox(height: 4),
          const Text(OwnerTexts.appTitle,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 30, color: Cozy.wood)),
          const SizedBox(height: 12),
        ],
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Cozy.ink)),
        if (lead != null) ...[
          const SizedBox(height: 4),
          Text(lead!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Cozy.inkSoft)),
        ],
        const SizedBox(height: 14),
        CozyFrame(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))),
      ]);
}

class _Message extends StatelessWidget {
  final String? text;
  const _Message(this.text);
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(text!,
              key: const Key('first-run-message'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Cozy.brick, fontSize: 14)));
}

class _OfflineStep extends StatelessWidget {
  final OwnerAccount owner;
  const _OfflineStep({required this.owner});
  @override
  Widget build(BuildContext context) => _StepPage(title: OwnerTexts.offlineTitle, emblem: true, children: [
        const Icon(Icons.wifi_off_rounded, size: 56, color: Cozy.woodLight),
        const SizedBox(height: 8),
        const Text(OwnerTexts.offlineBody, key: Key('first-run-offline'), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        CozyPrimaryButton(
            key: const Key('first-run-retry'),
            onPressed: owner.busy ? null : owner.retry,
            label: OwnerTexts.retry),
      ]);
}

/// A consent line: checkbox, label and an optional '보기'.
class ConsentRow extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onView;
  final bool strong;
  const ConsentRow(
      {super.key, required this.value, required this.label, required this.onChanged, this.onView, this.strong = false});
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), activeColor: Cozy.amber),
            Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 18 : 15))),
            if (onView != null)
              TextButton(onPressed: onView, child: const Text(OwnerTexts.view, style: TextStyle(fontSize: 14))),
          ])));
}

class _LoginStep extends StatefulWidget {
  final OwnerAccount owner;
  const _LoginStep({required this.owner});
  @override
  State<_LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends State<_LoginStep> {
  bool _terms = false, _privacy = false;
  bool get _agreed => _terms && _privacy;
  @override
  Widget build(BuildContext context) {
    final owner = widget.owner, online = owner.online;
    final signedIn = online.signedIn;
    final providers = online.loginProviders;
    VoidCallback? go(LoginProvider p) => owner.busy || !_agreed ? null : () => owner.signIn(p);
    return _StepPage(title: OwnerTexts.welcome, emblem: true, children: [
      ConsentRow(
          key: const Key('consent-all'),
          value: _agreed,
          strong: true,
          label: OwnerTexts.agreeAll,
          onChanged: (v) => setState(() => _terms = _privacy = v)),
      const Divider(height: 8),
      ConsentRow(
          key: const Key('consent-terms'),
          value: _terms,
          label: OwnerTexts.agreeTerms,
          onChanged: (v) => setState(() => _terms = v),
          onView: () => showLegalDocument(context, LegalDocument.terms)),
      ConsentRow(
          key: const Key('consent-privacy'),
          value: _privacy,
          label: OwnerTexts.agreePrivacy,
          onChanged: (v) => setState(() => _privacy = v),
          onView: () => showConsentSummary(context, OwnerTexts.privacySummaryTitle, OwnerTexts.privacySummary)),
      const SizedBox(height: 10),
      if (signedIn)
        CozyPrimaryButton(
            key: const Key('first-run-continue'),
            onPressed: owner.busy || !_agreed ? null : owner.acceptConsent,
            label: OwnerTexts.continueSignedIn)
      else ...[
        if (providers.contains(LoginProvider.kakao))
          _LoginButton(
              key: const Key('login-kakao'),
              label: OwnerTexts.loginKakao,
              color: const Color(0xfffee500),
              ink: const Color(0xff191600),
              icon: Icons.chat_bubble_rounded,
              onPressed: go(LoginProvider.kakao)),
        if (providers.contains(LoginProvider.google)) ...[
          const SizedBox(height: 8),
          _LoginButton(
              key: const Key('login-google'),
              label: OwnerTexts.loginGoogle,
              color: Colors.white,
              ink: const Color(0xff1f1f1f),
              icon: Icons.account_circle_outlined,
              onPressed: go(LoginProvider.google)),
        ],
      ],
      if (!_agreed)
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(OwnerTexts.needAgreement,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Cozy.inkSoft))),
      _Message(owner.message),
      const SizedBox(height: 10),
      const Text(OwnerTexts.oneWayNotice, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Cozy.inkSoft)),
      const SizedBox(height: 4),
      const Text(OwnerTexts.childNotice, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Cozy.inkSoft)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(
            key: const Key('first-run-terms'),
            onPressed: () => showLegalDocument(context, LegalDocument.terms),
            child: const Text(OwnerTexts.terms, style: TextStyle(fontSize: 13))),
        const Text('·', style: TextStyle(color: Cozy.inkSoft)),
        TextButton(
            key: const Key('first-run-privacy'),
            onPressed: () => showLegalDocument(context, LegalDocument.privacy),
            child: const Text(OwnerTexts.privacy, style: TextStyle(fontSize: 13))),
      ]),
    ]);
  }
}

/// A login button in its provider's colors (Kakao yellow, Google white).
class _LoginButton extends StatelessWidget {
  final String label;
  final Color color, ink;
  final IconData icon;
  final VoidCallback? onPressed;
  const _LoginButton(
      {super.key, required this.label, required this.color, required this.ink, required this.icon, this.onPressed});
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0x33000000))),
          child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: SizedBox(
                  height: 52,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: ink, size: 22),
                    const SizedBox(width: 10),
                    Text(label, style: TextStyle(color: ink, fontSize: 18)),
                  ])))));
}

class _NameStep extends StatefulWidget {
  final OwnerAccount owner;
  const _NameStep({required this.owner});
  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final _text = TextEditingController(text: widget.owner.profile.name ?? widget.owner.nameDraft);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() => widget.owner.setName(_text.text);

  @override
  Widget build(BuildContext context) => _StepPage(title: OwnerTexts.nameTitle, children: [
        OwnerNameField(controller: _text, rules: widget.owner.rules, onSubmitted: (_) => _submit()),
        const SizedBox(height: 6),
        const Text(OwnerTexts.nameHelp, style: TextStyle(fontSize: 13, color: Cozy.inkSoft)),
        _Message(widget.owner.message),
        const SizedBox(height: 12),
        CozyPrimaryButton(
            key: const Key('first-run-name-next'),
            onPressed: widget.owner.busy ? null : _submit,
            label: OwnerTexts.next),
      ]);
}

/// The name box: letters beyond the maximum are cut as they are typed.
class OwnerNameField extends StatelessWidget {
  final TextEditingController controller;
  final OwnerNameRules rules;
  final ValueChanged<String>? onSubmitted;
  const OwnerNameField({super.key, required this.controller, required this.rules, this.onSubmitted});
  @override
  Widget build(BuildContext context) => TextField(
      key: const Key('owner-name-field'),
      controller: controller,
      autofocus: false,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, color: Cozy.ink),
      maxLength: rules.maxLength,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
          hintText: OwnerTexts.nameHint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixText: '사장님',
          suffixStyle: const TextStyle(fontSize: 16, color: Cozy.inkSoft)));
}

class _CharacterStep extends StatefulWidget {
  final OwnerAccount owner;
  const _CharacterStep({required this.owner});
  @override
  State<_CharacterStep> createState() => _CharacterStepState();
}

class _CharacterStepState extends State<_CharacterStep> {
  late String _picked = widget.owner.currentCharacter;
  @override
  Widget build(BuildContext context) {
    Widget card(String id, String label) {
      final picked = _picked == id;
      return Expanded(
          child: GestureDetector(
              key: Key('character-$id'),
              onTap: () => setState(() => _picked = id),
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: picked ? Cozy.honeyLight : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: picked ? Cozy.amber : Cozy.tan, width: picked ? 4 : 2)),
                  child: Column(children: [
                    SizedBox(
                        height: 190,
                        child: CustomPaint(size: Size.infinite, painter: AvatarPainter(AvatarLook(character: id)))),
                    const SizedBox(height: 6),
                    Text(label, style: TextStyle(fontSize: 18, color: picked ? Cozy.wood : Cozy.ink)),
                    Icon(picked ? Icons.check_circle : Icons.circle_outlined,
                        color: picked ? Cozy.amber : Cozy.tan, size: 26),
                  ]))));
    }

    return _StepPage(title: OwnerTexts.characterTitle, lead: OwnerTexts.characterHelp, children: [
      Row(children: [card('girl', OwnerTexts.girl), const SizedBox(width: 10), card('boy', OwnerTexts.boy)]),
      _Message(widget.owner.message),
      const SizedBox(height: 12),
      CozyPrimaryButton(
          key: const Key('first-run-character-start'),
          onPressed: widget.owner.busy ? null : () => widget.owner.chooseCharacter(_picked),
          label: OwnerTexts.startWith),
    ]);
  }
}

/// Gender, age band, the optional consent and (under 14) the guardian's
/// consent. Used by the first run and by the settings.
class OptionalInfoForm extends StatefulWidget {
  final OptionalInfo? initial;
  final bool busy;
  /// Called with the answers once the consent is given.
  final void Function(PlayerGender gender, AgeBand ageBand, bool guardian) onSave;
  final VoidCallback onSkip;
  final String skipLabel, saveLabel;
  const OptionalInfoForm(
      {super.key,
      this.initial,
      this.busy = false,
      required this.onSave,
      required this.onSkip,
      this.skipLabel = OwnerTexts.skip,
      this.saveLabel = OwnerTexts.saveAndStart});
  @override
  State<OptionalInfoForm> createState() => _OptionalInfoFormState();
}

class _OptionalInfoFormState extends State<OptionalInfoForm> {
  late PlayerGender? _gender = widget.initial?.gender;
  late AgeBand? _age = widget.initial?.ageBand;
  late bool _consent = widget.initial != null, _guardian = widget.initial?.guardianConsent ?? false;

  bool get _ready => _consent && _gender != null && _age != null;

  Widget _chips<T extends Enum>(String key, String label, List<T> values, T? selected, String Function(T) name,
          ValueChanged<T> pick) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final v in values)
            ChoiceChip(
                key: Key('$key-${v.name}'),
                label: Text(name(v), style: const TextStyle(fontSize: 14)),
                selected: v == selected,
                selectedColor: Cozy.honey,
                backgroundColor: Colors.white,
                showCheckmark: false,
                onSelected: (_) => pick(v)),
        ]),
      ]);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _chips<PlayerGender>('gender', OwnerTexts.genderLabel, PlayerGender.values, _gender, (v) => v.label,
            (v) => setState(() => _gender = v)),
        const SizedBox(height: 10),
        _chips<AgeBand>('age', OwnerTexts.ageLabel, AgeBand.values, _age, (v) => v.label, (v) => setState(() => _age = v)),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Text(OwnerTexts.optionalSummary, style: TextStyle(fontSize: 13, color: Cozy.inkSoft))),
        ConsentRow(
            key: const Key('consent-optional'),
            value: _consent,
            label: OwnerTexts.agreeOptional,
            onChanged: (v) => setState(() => _consent = v)),
        if (_age == AgeBand.under14) ...[
          const Text(OwnerTexts.guardianNotice, style: TextStyle(fontSize: 13, color: Cozy.brick)),
          ConsentRow(
              key: const Key('consent-guardian'),
              value: _guardian,
              label: OwnerTexts.guardianAgree,
              onChanged: (v) => setState(() => _guardian = v)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          // The skip button is as big as the save button (easy to find).
          Expanded(
              child: CozyButton(
                  key: const Key('optional-skip'),
                  onPressed: widget.busy ? null : widget.onSkip,
                  label: widget.skipLabel,
                  minHeight: 50)),
          const SizedBox(width: 10),
          Expanded(
              child: CozyPrimaryButton(
                  key: const Key('optional-save'),
                  onPressed: widget.busy || !_ready ? null : () => widget.onSave(_gender!, _age!, _guardian),
                  label: widget.saveLabel,
                  minHeight: 50)),
        ]),
      ]);
}

class _OptionalStep extends StatelessWidget {
  final OwnerAccount owner;
  const _OptionalStep({required this.owner});
  @override
  Widget build(BuildContext context) => _StepPage(title: OwnerTexts.optionalTitle, lead: OwnerTexts.optionalLead, children: [
        OptionalInfoForm(
            busy: owner.busy,
            onSkip: owner.skipOptional,
            onSave: (gender, age, guardian) =>
                owner.saveOptional(gender: gender, ageBand: age, guardianConsent: guardian)),
      ]);
}

/// The full terms or privacy policy, bundled with the app
/// (assets/legal/, copies of the documents in 2.1.3_legacy_code_policies_and_online_setup).
enum LegalDocument {
  terms('assets/legal/terms_of_service.md', OwnerTexts.terms),
  privacy('assets/legal/privacy_policy.md', OwnerTexts.privacy);

  final String asset, title;
  const LegalDocument(this.asset, this.title);
}

Future<void> showConsentSummary(BuildContext context, String title, String body) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(body, style: const TextStyle(fontSize: 15))),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    showLegalDocument(context, LegalDocument.privacy);
                  },
                  child: const Text('${OwnerTexts.privacy} 전체')),
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
            ]));

Future<void> showLegalDocument(BuildContext context, LegalDocument document) => showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: CozyFrame(
            child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.8,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(children: [
                        Expanded(child: Text(document.title, style: const TextStyle(fontSize: 20))),
                        CozyCloseButton(onPressed: () => Navigator.pop(ctx)),
                      ])),
                  Expanded(
                      child: FutureBuilder<String>(
                          future: rootBundle.loadString(document.asset),
                          builder: (context, snap) => snap.hasData
                              ? ListView(
                                  key: Key('legal-${document.name}'),
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  children: markdownLines(snap.data!))
                              : Center(
                                  child: Text(snap.hasError ? '문서를 열 수 없어요' : '불러오는 중…')))),
                ])))));

/// A light reading of the policy markdown: headings, list items, table rows
/// (cells joined with ' · ') and paragraphs.
List<Widget> markdownLines(String source) {
  String plain(String s) => s.replaceAll('**', '').replaceAll('`', '').replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => '${m[1]} (${m[2]})');
  final out = <Widget>[];
  for (final raw in source.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty || RegExp(r'^\|?\s*-{3,}').hasMatch(line)) continue;
    if (line.startsWith('#')) {
      final level = line.indexOf(' ');
      out.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(plain(line.substring(level + 1)), style: TextStyle(fontSize: level <= 1 ? 22 : 18, color: Cozy.wood))));
    } else if (line.startsWith('|')) {
      final cells = line.split('|').map((c) => plain(c.trim())).where((c) => c.isNotEmpty);
      out.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(cells.join(' · '), style: const TextStyle(fontSize: 14))));
    } else {
      final item = RegExp(r'^(\s*)[-*] (.*)$').firstMatch(line);
      out.add(Padding(
          padding: EdgeInsets.only(bottom: 4, left: item == null ? 0 : 8.0 + item[1]!.length * 4),
          child: Text(item == null ? plain(line) : '• ${plain(item[2]!)}', style: const TextStyle(fontSize: 14))));
    }
  }
  return out;
}
