import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../cosmetic_config.dart';
import '../feedback_config.dart';
import '../online_backend.dart';
import '../owner_account.dart';
import '../owner_profile.dart';
import '../owner_texts.dart';
import 'avatar_painter.dart';
import 'cozy_style.dart';
import 'pixel_sprites.dart';
import 'weather_layer.dart';

// 26번 2-1단계: the first-run screens before the game. ① required consent +
// login (Kakao or Google) → ② owner name → ③ 여자/남자 사장님 → ④ optional
// gender and age band, then the game and its first-run guide. Also the
// account part of the settings (name, optional info, logout, deletion).
//
// 26번 3차 H2~H5: every step sits on a winter stall picture
// ([firstRunBackground]) in one light card with small pill buttons; rules
// show only when broken, in small red text under the field.

/// The first-run look: a light card, small pill buttons, thin fields.
abstract final class FirstRunStyle {
  static const card = Color(0xf7fffaf1);
  static const cardShadow = Color(0x47000000);
  static const line = Color(0xffeedcc4);
  static const field = Colors.white;
  static const fieldEdge = Color(0xffe6cfb0);
  static const accent = Cozy.amber;
  static const onAccent = Colors.white;
  static const error = Cozy.brick;
  static const titleGlow = Color(0xcc1b1530);
  static const veil = Color(0x29000000);
  static const radius = 20.0;
  static const buttonHeight = 44.0;
}

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
  Widget build(BuildContext context) {
    final still = owner.game.state.settings.reduceMotion || MediaQuery.disableAnimationsOf(context);
    return Scaffold(
        backgroundColor: Cozy.woodDark,
        body: Stack(children: [
          Positioned.fill(child: FirstRunBackdrop(reduceMotion: still)),
          SafeArea(
              child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: (box.maxHeight - 36).clamp(0, double.infinity)),
                          child: Center(
                              child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  child: switch (owner.step) {
                                    OwnerStep.offline => _OfflineStep(owner: owner),
                                    OwnerStep.login => _LoginStep(owner: owner),
                                    OwnerStep.name => _NameStep(owner: owner),
                                    OwnerStep.character => _CharacterStep(owner: owner),
                                    OwnerStep.optional || OwnerStep.done => _OptionalStep(owner: owner),
                                  })))))),
        ]));
  }
}

/// The winter stall behind the first-run steps (26번 3차 H2): the
/// illustration `ui/first_run.png` (25번 37번) when it is in the app, else
/// the lowered home picture [firstRunBackground], filling the screen, its snow falling
/// (still with reduced motion) and a light veil so the card stands out.
class FirstRunBackdrop extends StatelessWidget {
  final bool reduceMotion;
  const FirstRunBackdrop({super.key, this.reduceMotion = false});
  @override
  Widget build(BuildContext context) {
    final picture =
        PixelSprites.screenArt('first_run') ?? PixelSprites.lowStallBackground(firstRunBackground, null).$1;
    return Stack(key: const Key('first-run-backdrop'), fit: StackFit.expand, children: [
      if (picture != null) CustomPaint(painter: _CoverPainter(picture)),
      WeatherLayer(background: firstRunBackground, reduceMotion: reduceMotion),
      const ColoredBox(color: FirstRunStyle.veil),
    ]);
  }
}

/// Pixel art scaled to cover the box, crisp (no smoothing).
class _CoverPainter extends CustomPainter {
  final ui.Image image;
  const _CoverPainter(this.image);
  @override
  void paint(Canvas canvas, Size size) => paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: image,
      fit: BoxFit.cover,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.none);
  @override
  bool shouldRepaint(_CoverPainter old) => old.image != image;
}

/// The light card every step sits in.
class FirstRunCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const FirstRunCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 18)});
  @override
  Widget build(BuildContext context) => Material(
      color: FirstRunStyle.card,
      elevation: 0,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FirstRunStyle.radius)),
      child: Padding(padding: padding, child: child));
}

/// A small pill button: filled for the main action, outlined otherwise.
/// Greyed while [onPressed] is null.
class FirstRunButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  /// Stretches to the width it gets instead of hugging the label.
  final bool expand;
  const FirstRunButton(
      {super.key, required this.label, required this.onPressed, this.filled = true, this.expand = false});
  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FirstRunStyle.buttonHeight / 2),
        side: filled ? BorderSide.none : const BorderSide(color: FirstRunStyle.fieldEdge, width: 1.2));
    final button = Opacity(
        opacity: on ? 1 : .45,
        child: Material(
            color: filled ? FirstRunStyle.accent : Colors.white,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onPressed,
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 132, minHeight: FirstRunStyle.buttonHeight),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                            widthFactor: 1,
                            child: Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, color: filled ? FirstRunStyle.onAccent : Cozy.ink))))))));
    return Semantics(button: true, enabled: on, child: expand ? button : Center(child: button));
  }
}

/// Title and an optional lead line on the card, then the step's content.
/// The login step adds the app's emblem above the card.
class _StepPage extends StatelessWidget {
  final String title;
  final String? lead;
  final List<Widget> children;
  final bool emblem;
  const _StepPage({required this.title, this.lead, required this.children, this.emblem = false});
  @override
  Widget build(BuildContext context) {
    // Short screens (360x640) get a smaller emblem so the card fits.
    final short = MediaQuery.sizeOf(context).height < 700;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (emblem) ...[
          Center(child: PixelIcon('bun', size: short ? 48 : 72)),
          Text(OwnerTexts.appTitle,
              key: const Key('first-run-app-title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: short ? 26 : 32, color: Cozy.cream, shadows: const [
                Shadow(color: FirstRunStyle.titleGlow, blurRadius: 12),
                Shadow(color: FirstRunStyle.titleGlow, offset: Offset(0, 2), blurRadius: 2),
              ])),
          SizedBox(height: short ? 10 : 16),
        ],
        FirstRunCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, key: const Key('first-run-title'), textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, color: Cozy.ink)),
          if (lead != null) ...[
            const SizedBox(height: 4),
            Text(lead!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Cozy.inkSoft)),
          ],
          const SizedBox(height: 16),
          ...children,
        ])),
      ]);
  }
}

/// A problem in small red text (centered, under the content).
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
              style: const TextStyle(color: FirstRunStyle.error, fontSize: 12)));
}

class _OfflineStep extends StatelessWidget {
  final OwnerAccount owner;
  const _OfflineStep({required this.owner});
  @override
  Widget build(BuildContext context) => _StepPage(title: OwnerTexts.offlineTitle, emblem: true, children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: Cozy.taupe),
        const SizedBox(height: 8),
        const Text(OwnerTexts.offlineBody,
            key: Key('first-run-offline'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Cozy.ink)),
        const SizedBox(height: 16),
        FirstRunButton(key: const Key('first-run-retry'), onPressed: owner.busy ? null : owner.retry, label: OwnerTexts.retry),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: [
            Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: FirstRunStyle.accent,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: Cozy.taupe, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 16 : 14, color: Cozy.ink))),
            if (onView != null)
              TextButton(
                  onPressed: onView,
                  style: TextButton.styleFrom(
                      foregroundColor: Cozy.inkSoft,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text(OwnerTexts.view, style: TextStyle(fontSize: 13, decoration: TextDecoration.underline))),
          ])));
}

class _LoginStep extends StatefulWidget {
  final OwnerAccount owner;
  const _LoginStep({required this.owner});
  @override
  State<_LoginStep> createState() => _LoginStepState();
}

class _LoginStepState extends State<_LoginStep> {
  bool _terms = false, _privacy = false, _age = false;
  /// A login was tried before every required item was checked: only then
  /// the reminder shows (H4: rules only when broken).
  bool _tried = false;
  bool get _agreed => _terms && _privacy && _age;
  @override
  Widget build(BuildContext context) {
    final owner = widget.owner, online = owner.online;
    final signedIn = online.signedIn;
    final providers = online.loginProviders;
    VoidCallback? go(VoidCallback action) => owner.busy
        ? null
        : () {
            if (_agreed) {
              action();
            } else {
              setState(() => _tried = true);
            }
          };
    const small = TextStyle(fontSize: 12, color: Cozy.inkSoft);
    return _StepPage(title: OwnerTexts.welcome, emblem: true, children: [
      ConsentRow(
          key: const Key('consent-all'),
          value: _agreed,
          strong: true,
          label: OwnerTexts.agreeAll,
          onChanged: (v) => setState(() => _terms = _privacy = _age = v)),
      const Divider(height: 10, color: FirstRunStyle.line),
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
      // 만 14세 미만은 가입 불가(DEC-125): the notice stays while unchecked,
      // red once a login was tried without it.
      ConsentRow(
          key: const Key('consent-age'),
          value: _age,
          label: OwnerTexts.agreeAge,
          onChanged: (v) => setState(() => _age = v)),
      if (!_age)
        Text(OwnerTexts.childNotice,
            key: const Key('first-run-child-notice'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _tried ? FirstRunStyle.error : Cozy.inkSoft)),
      const SizedBox(height: 14),
      if (signedIn)
        FirstRunButton(
            key: const Key('first-run-continue'),
            expand: true,
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
              dimmed: !_agreed,
              onPressed: go(() => owner.signIn(LoginProvider.kakao))),
        if (providers.contains(LoginProvider.google)) ...[
          const SizedBox(height: 8),
          _LoginButton(
              key: const Key('login-google'),
              label: OwnerTexts.loginGoogle,
              color: Colors.white,
              ink: const Color(0xff1f1f1f),
              icon: Icons.account_circle_outlined,
              dimmed: !_agreed,
              onPressed: go(() => owner.signIn(LoginProvider.google))),
        ],
      ],
      if (_tried && !_agreed)
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(OwnerTexts.needAgreement,
                key: Key('first-run-need-agreement'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: FirstRunStyle.error))),
      _Message(owner.message),
      const SizedBox(height: 12),
      const Text(OwnerTexts.oneWayNotice, textAlign: TextAlign.center, style: small),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(
            key: const Key('first-run-terms'),
            style: TextButton.styleFrom(foregroundColor: Cozy.inkSoft, visualDensity: VisualDensity.compact),
            onPressed: () => showLegalDocument(context, LegalDocument.terms),
            child: const Text(OwnerTexts.terms, style: TextStyle(fontSize: 12))),
        const Text('·', style: small),
        TextButton(
            key: const Key('first-run-privacy'),
            style: TextButton.styleFrom(foregroundColor: Cozy.inkSoft, visualDensity: VisualDensity.compact),
            onPressed: () => showLegalDocument(context, LegalDocument.privacy),
            child: const Text(OwnerTexts.privacy, style: TextStyle(fontSize: 12))),
      ]),
    ]);
  }
}

/// A login button in its provider's colors (Kakao yellow, Google white).
/// [dimmed] while the required consents are missing; a tap then only
/// reminds (the login itself does not start).
class _LoginButton extends StatelessWidget {
  final String label;
  final Color color, ink;
  final IconData icon;
  final bool dimmed;
  final VoidCallback? onPressed;
  const _LoginButton(
      {super.key,
      required this.label,
      required this.color,
      required this.ink,
      required this.icon,
      this.dimmed = false,
      this.onPressed});
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: onPressed == null || dimmed ? 0.45 : 1,
      child: Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0x22000000))),
          child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: SizedBox(
                  height: 46,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icon, color: ink, size: 20),
                    const SizedBox(width: 8),
                    Text(label, style: TextStyle(color: ink, fontSize: 16)),
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
        // The broken rule shows under the box, only after '다음' (H4).
        OwnerNameField(
            controller: _text,
            rules: widget.owner.rules,
            errorText: widget.owner.message,
            onChanged: (_) {
              if (widget.owner.message != null) widget.owner.clearMessage();
            },
            onSubmitted: (_) => _submit()),
        const SizedBox(height: 6),
        const Text(OwnerTexts.nameHelp,
            key: Key('first-run-name-help'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Cozy.inkSoft)),
        const SizedBox(height: 16),
        FirstRunButton(
            key: const Key('first-run-name-next'),
            onPressed: widget.owner.busy ? null : _submit,
            label: OwnerTexts.next),
      ]);
}

/// The name box: one slim line, letters beyond the maximum cut as they are
/// typed (no counter). [errorText] shows below in small red text.
class OwnerNameField extends StatelessWidget {
  final TextEditingController controller;
  final OwnerNameRules rules;
  final String? errorText;
  final ValueChanged<String>? onChanged, onSubmitted;
  const OwnerNameField(
      {super.key, required this.controller, required this.rules, this.errorText, this.onChanged, this.onSubmitted});
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder edge(Color color, double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: width));
    return TextField(
        key: const Key('owner-name-field'),
        controller: controller,
        autofocus: false,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, color: Cozy.ink),
        maxLength: rules.maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
            hintText: OwnerTexts.nameHint,
            hintStyle: const TextStyle(fontSize: 18, color: Color(0xffc2b3a8)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            counterText: '',
            filled: true,
            fillColor: FirstRunStyle.field,
            enabledBorder: edge(FirstRunStyle.fieldEdge, 1.2),
            focusedBorder: edge(FirstRunStyle.accent, 1.6),
            errorBorder: edge(FirstRunStyle.error, 1.2),
            focusedErrorBorder: edge(FirstRunStyle.error, 1.6),
            // Centered under the box like the help line below it.
            error: errorText == null
                ? null
                : Center(
                    child: Text(errorText!,
                        key: const Key('owner-name-problem'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: FirstRunStyle.error))),
            suffixText: '사장님',
            suffixStyle: const TextStyle(fontSize: 14, color: Cozy.inkSoft)));
  }
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
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
                  decoration: BoxDecoration(
                      color: picked ? const Color(0xfffff1d6) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: picked ? FirstRunStyle.accent : FirstRunStyle.line, width: picked ? 2 : 1.2)),
                  child: Column(children: [
                    SizedBox(
                        height: 170,
                        child: CustomPaint(size: Size.infinite, painter: AvatarPainter(AvatarLook(character: id, hair: defaultHairOf(id))))),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(picked ? Icons.check_circle_rounded : Icons.circle_outlined,
                          color: picked ? FirstRunStyle.accent : FirstRunStyle.fieldEdge, size: 18),
                      const SizedBox(width: 4),
                      Flexible(
                          child: Text(label,
                              style: TextStyle(fontSize: 15, color: picked ? Cozy.ink : Cozy.inkSoft))),
                    ]),
                  ]))));
    }

    return _StepPage(title: OwnerTexts.characterTitle, lead: OwnerTexts.characterHelp, children: [
      Row(children: [card('girl', OwnerTexts.girl), const SizedBox(width: 10), card('boy', OwnerTexts.boy)]),
      _Message(widget.owner.message),
      const SizedBox(height: 16),
      FirstRunButton(
          key: const Key('first-run-character-start'),
          onPressed: widget.owner.busy ? null : () => widget.owner.chooseCharacter(_picked),
          label: OwnerTexts.startWith),
    ]);
  }
}

/// Gender, age band (no 만 14세 미만 band, DEC-125) and the optional
/// consent. Used by the first run and by the settings.
class OptionalInfoForm extends StatefulWidget {
  final OptionalInfo? initial;
  final bool busy;
  /// Called with the answers once the consent is given.
  final void Function(PlayerGender gender, AgeBand ageBand) onSave;
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
  late bool _consent = widget.initial != null;

  bool get _ready => _consent && _gender != null && _age != null;

  Widget _chips<T extends Enum>(String key, String label, List<T> values, T? selected, String Function(T) name,
          ValueChanged<T> pick) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Cozy.ink)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in values)
            ChoiceChip(
                key: Key('$key-${v.name}'),
                label: Text(name(v),
                    style: TextStyle(fontSize: 13, color: v == selected ? FirstRunStyle.onAccent : Cozy.ink)),
                selected: v == selected,
                selectedColor: FirstRunStyle.accent,
                backgroundColor: Colors.white,
                side: BorderSide(color: v == selected ? FirstRunStyle.accent : FirstRunStyle.fieldEdge),
                shape: const StadiumBorder(),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
                onSelected: (_) => pick(v)),
        ]),
      ]);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _chips<PlayerGender>('gender', OwnerTexts.genderLabel, PlayerGender.values, _gender, (v) => v.label,
            (v) => setState(() => _gender = v)),
        const SizedBox(height: 12),
        _chips<AgeBand>('age', OwnerTexts.ageLabel, AgeBand.values, _age, (v) => v.label, (v) => setState(() => _age = v)),
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xfffbf3e6), borderRadius: BorderRadius.circular(12)),
            child: const Text(OwnerTexts.optionalSummary, style: TextStyle(fontSize: 12, color: Cozy.inkSoft))),
        const SizedBox(height: 4),
        ConsentRow(
            key: const Key('consent-optional'),
            value: _consent,
            label: OwnerTexts.agreeOptional,
            onChanged: (v) => setState(() => _consent = v)),
        const SizedBox(height: 12),
        Row(children: [
          // The skip button is as big as the save button (easy to find).
          Expanded(
              child: FirstRunButton(
                  key: const Key('optional-skip'),
                  expand: true,
                  filled: false,
                  onPressed: widget.busy ? null : widget.onSkip,
                  label: widget.skipLabel)),
          const SizedBox(width: 10),
          Expanded(
              child: FirstRunButton(
                  key: const Key('optional-save'),
                  expand: true,
                  onPressed: widget.busy || !_ready ? null : () => widget.onSave(_gender!, _age!),
                  label: widget.saveLabel)),
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
            onSave: (gender, age) => owner.saveOptional(gender: gender, ageBand: age)),
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
