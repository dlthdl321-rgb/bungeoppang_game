import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cooking_gestures.dart';
import '../cooking_input.dart';

enum FillingTool { spoon, chopsticks }

/// A fresh keyed instance owns one stage and one pointer. Buttons and gestures
/// emit exactly the same direction command; tool choice grants no bonus.
class CookingFillingControls extends StatefulWidget {
  final bool blocked;
  final FillingGestureRules rules;
  final int stageToken;
  final CookingDirection expected;
  final void Function(CookingDirection) onDirection;
  const CookingFillingControls(
      {super.key,
      required this.blocked,
      required this.rules,
      required this.stageToken,
      required this.expected,
      required this.onDirection});
  @override
  State<CookingFillingControls> createState() => _CookingFillingControlsState();
}

class _CookingFillingControlsState extends State<CookingFillingControls>
    with WidgetsBindingObserver {
  FillingTool _tool = FillingTool.spoon;
  final _clock = Stopwatch()..start();
  int? _pointer;
  FillingSwipe? _swipe;
  FillingRotation? _rotation;
  Offset _position = const Offset(150, 90);
  void _cancel() {
    _pointer = null;
    _swipe = null;
    _rotation = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant CookingFillingControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.blocked || oldWidget.stageToken != widget.stageToken) _cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      setState(_cancel);
    }
  }

  @override
  void dispose() {
    _cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _emit(CookingDirection direction) {
    if (widget.blocked) return;
    setState(_cancel);
    widget.onDirection(direction);
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.expected == CookingDirection.left;
    final rotationHint = widget.rules.rotationDegrees == 360
        ? '한 바퀴'
        : '${widget.rules.rotationDegrees}도';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SegmentedButton<FillingTool>(
          segments: const [
            ButtonSegment(
                value: FillingTool.spoon,
                label: Text('숟가락'),
                icon: Icon(Icons.soup_kitchen)),
            ButtonSegment(
                value: FillingTool.chopsticks,
                label: Text('젓가락'),
                icon: Icon(Icons.restaurant)),
          ],
          selected: {
            _tool
          },
          onSelectionChanged: widget.blocked
              ? null
              : (selection) {
                  setState(() {
                    _cancel();
                    _tool = selection.single;
                  });
                }),
      Text(_tool == FillingTool.spoon
          ? '${left ? '반시계' : '시계'} 방향으로 $rotationHint 그린 뒤 놓아 주세요.'
          : '${left ? '왼쪽' : '오른쪽'}으로 쓸어 넣어 주세요.'),
      SizedBox(
          width: 220,
          height: 180,
          child: Listener(
            key: const ValueKey('filling-gesture'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (widget.blocked || _pointer != null) return;
              setState(() {
                _pointer = event.pointer;
                _position = event.localPosition;
                _swipe = FillingSwipe(
                    _position.dx, _position.dy, _clock.elapsedMilliseconds,
                    rules: widget.rules);
                _rotation = FillingRotation(widget.rules)
                  ..sample(_position.dx - 110, _position.dy - 90);
              });
            },
            onPointerMove: (event) {
              if (_pointer != event.pointer || widget.blocked) return;
              if (!(const Rect.fromLTWH(0, 0, 220, 180))
                  .contains(event.localPosition)) {
                setState(_cancel);
                return;
              }
              setState(() {
                _position = event.localPosition;
                _rotation?.sample(_position.dx - 110, _position.dy - 90);
              });
            },
            onPointerCancel: (event) {
              if (_pointer == event.pointer) setState(_cancel);
            },
            onPointerUp: (event) {
              if (_pointer != event.pointer || widget.blocked) return;
              final direction = _tool == FillingTool.spoon
                  ? _rotation?.finish()
                  : _swipe?.finish(event.localPosition.dx,
                      event.localPosition.dy, _clock.elapsedMilliseconds);
              setState(_cancel);
              if (direction != null) _emit(direction);
            },
            child: CustomPaint(
                painter: _FillingPainter(
                    _tool,
                    _position,
                    _rotation?.progress ?? 0,
                    Theme.of(context).colorScheme.primary)),
          )),
      Wrap(spacing: 12, children: [
        for (final direction in CookingDirection.values)
          FilledButton(
              onPressed: widget.blocked ? null : () => _emit(direction),
              child: Text(
                  '${direction == CookingDirection.left ? '왼쪽' : '오른쪽'}으로 속 넣기'))
      ]),
    ]);
  }
}

class _FillingPainter extends CustomPainter {
  final FillingTool tool;
  final Offset position;
  final double progress;
  final Color color;
  _FillingPainter(this.tool, this.position, this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(110, 90);
    canvas.drawCircle(center, 66, Paint()..color = const Color(0xffedd6ae));
    canvas.drawCircle(center, 48, Paint()..color = const Color(0xff803e37));
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: 73),
        -math.pi / 2,
        progress * math.pi * 2,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    final handle = Paint()
      ..color = const Color(0xff68452c)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    if (tool == FillingTool.spoon) {
      canvas.drawLine(position, position + const Offset(30, -40), handle);
      canvas.drawOval(Rect.fromCenter(center: position, width: 21, height: 29),
          Paint()..color = const Color(0xffd8b775));
    } else {
      canvas.drawLine(
          position, position + const Offset(39, -48), handle..strokeWidth = 4);
      canvas.drawLine(position + const Offset(10, 3),
          position + const Offset(48, -43), handle);
    }
  }

  @override
  bool shouldRepaint(covariant _FillingPainter oldDelegate) =>
      tool != oldDelegate.tool ||
      position != oldDelegate.position ||
      progress != oldDelegate.progress ||
      color != oldDelegate.color;
}
