import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/theme.dart';
import 'inky.dart';

/// Squashes its child while pressed and springs back with a little wobble.
/// Purely visual: taps still go to the child.
class Squishy extends StatefulWidget {
  const Squishy({super.key, required this.child, this.pressedScale = 0.93});

  final Widget child;
  final double pressedScale;

  @override
  State<Squishy> createState() => _SquishyState();
}

class _SquishyState extends State<Squishy> with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 520, damping: 13);

  // Unbounded so the spring can overshoot past "released".
  late final AnimationController _c = AnimationController.unbounded(vsync: this);
  Offset? _down;
  bool _motion = true;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _press(PointerDownEvent e) {
    if (!_motion) return;
    _down = e.position;
    _c.animateTo(1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut);
  }

  void _release() {
    if (_down == null) return;
    _down = null;
    _c.animateWith(SpringSimulation(_spring, _c.value, 0, 0));
  }

  @override
  Widget build(BuildContext context) {
    _motion = playfulMotion(context);
    return Listener(
      onPointerDown: _press,
      onPointerMove: (e) {
        // A scroll, not a tap.
        if (_down != null && (e.position - _down!).distance > kTouchSlop) _release();
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(scale: 1 - (1 - widget.pressedScale) * _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Gives its child a little shake every few seconds while [active].
class Wiggle extends StatefulWidget {
  const Wiggle({super.key, required this.child, this.active = true, this.every = const Duration(seconds: 6)});

  final Widget child;
  final bool active;
  final Duration every;

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  Timer? _timer;
  bool _motion = true;
  ValueListenable<TickerModeData>? _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.getValuesNotifier(context);
    _motion = playfulMotion(context);
    _schedule();
  }

  @override
  void didUpdateWidget(Wiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!widget.active || !_motion) return;
    _timer = Timer.periodic(widget.every, (_) {
      if (mounted && (_visible?.value.enabled ?? true)) _c.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final t = _c.value;
      final angle = _c.isAnimating ? sin(t * pi * 6) * (1 - t) * 0.09 : 0.0;
      return Transform.rotate(angle: angle, child: child);
    },
    child: widget.child,
  );
}

/// Fades and pops its child in once, after [delay].
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!playfulMotion(context)) {
      _c.value = 1;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      final scale = Curves.elasticOut.transform(_c.value).clamp(0.0, 1.2);
      return Opacity(
        opacity: Curves.easeOut.transform(_c.value),
        child: Transform.scale(scale: 0.85 + 0.15 * scale, child: child),
      );
    },
    child: widget.child,
  );
}

/// A hand-drawn wavy underline.
class Squiggle extends StatelessWidget {
  const Squiggle({super.key, this.width = 64, this.color, this.strokeWidth = 3});

  final double width;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, 10),
    painter: _SquigglePainter(color ?? Theme.of(context).colorScheme.primary, strokeWidth),
  );
}

class _SquigglePainter extends CustomPainter {
  _SquigglePainter(this.color, this.strokeWidth);

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(2, size.height / 2);
    const wave = 12.0;
    for (var x = 2.0; x < size.width - 2; x += wave) {
      path.relativeQuadraticBezierTo(wave / 4, -4, wave / 2, 0);
      path.relativeQuadraticBezierTo(wave / 4, 4, wave / 2, 0);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SquigglePainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// A handwritten section title with a squiggle underneath.
class HandHeader extends StatelessWidget {
  const HandHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, style: handStyle(28, color: scheme.onSurface)),
                Transform.translate(offset: const Offset(0, -4), child: Squiggle(width: 56, color: scheme.primary)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
