import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings.dart';
import '../theme/theme.dart';

/// Inky's expressions.
enum InkyFace { happy, excited, neutral, meh, sad, sleepy, surprised, wink, covering }

InkyFace faceForMood(int? mood) => switch (mood) {
  5 => InkyFace.excited,
  4 => InkyFace.happy,
  3 => InkyFace.neutral,
  2 => InkyFace.meh,
  1 => InkyFace.sad,
  _ => InkyFace.happy,
};

/// Whether decorative motion is welcome: the system "remove animations"
/// setting wins, then Settings → Animated Inky. Call it from build or
/// didChangeDependencies; it subscribes to both.
bool playfulMotion(BuildContext context) {
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
  try {
    return Provider.of<SettingsController>(context).animatedInky;
  } on ProviderNotFoundException {
    return true;
  }
}

/// Inky, the ink-drop mascot. Blinks now and then, breathes for a few seconds
/// after appearing (then rests, to spare the battery) and hops on [hop] or
/// when its face changes.
class Inky extends StatefulWidget {
  const Inky({
    super.key,
    this.size = 72,
    this.face = InkyFace.happy,
    this.look = Offset.zero,
    this.onTap,
    this.shadow = true,
    this.semanticLabel = 'Inky the ink drop',
  });

  final double size;
  final InkyFace face;

  /// Where the pupils point, each axis -1..1.
  final Offset look;
  final VoidCallback? onTap;
  final bool shadow;
  final String semanticLabel;

  @override
  State<Inky> createState() => InkyState();
}

class InkyState extends State<Inky> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  final _random = Random();
  Timer? _blinkTimer;
  Timer? _restTimer;
  ValueListenable<TickerModeData>? _visible;
  bool? _motion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.getValuesNotifier(context);
    final motion = playfulMotion(context);
    if (motion == _motion) return;
    _motion = motion;
    if (motion) {
      _wake();
      _scheduleBlink();
    } else {
      _blinkTimer?.cancel();
      _restTimer?.cancel();
      _breath
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(Inky oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.face != widget.face) hop();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _restTimer?.cancel();
    _breath.dispose();
    _hop.dispose();
    _blink.dispose();
    super.dispose();
  }

  /// A happy little jump.
  void hop() {
    if (_motion != true) return;
    _hop.forward(from: 0);
    _wake();
  }

  void _wake() {
    if (!_breath.isAnimating) _breath.repeat();
    _restTimer?.cancel();
    _restTimer = Timer(const Duration(seconds: 7), () {
      // Finish the current breath, then hold still.
      if (mounted) _breath.forward().whenComplete(() => _breath.value = 0);
    });
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(Duration(milliseconds: 2200 + _random.nextInt(3600)), () {
      if (!mounted || _motion != true) return;
      if (_visible?.value.enabled ?? true) _blink.forward(from: 0);
      _scheduleBlink();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = inkColor(Theme.of(context).colorScheme);
    Widget child = TweenAnimationBuilder<Offset>(
      tween: Tween(end: widget.look),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, look, _) => AnimatedBuilder(
        animation: Listenable.merge([_breath, _hop, _blink]),
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: InkyPainter(
            body: body,
            face: widget.face,
            look: look,
            breath: _breath.value,
            hop: _hop.isAnimating ? _hop.value : 0,
            blink: _blink.isAnimating ? sin(pi * _blink.value) : 0,
            shadow: widget.shadow,
          ),
        ),
      ),
    );
    if (widget.onTap != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          hop();
          widget.onTap!();
        },
        child: child,
      );
    }
    return Semantics(label: widget.semanticLabel, button: widget.onTap != null, child: child);
  }
}

/// Draws Inky in a 100×100 box. The drop spans x 20..80, y 6..90.
class InkyPainter extends CustomPainter {
  InkyPainter({
    required this.body,
    required this.face,
    this.look = Offset.zero,
    this.breath = 0,
    this.hop = 0,
    this.blink = 0,
    this.shadow = true,
  });

  final Color body;
  final InkyFace face;
  final Offset look;
  final double breath;
  final double hop;
  final double blink;
  final bool shadow;

  static const _white = Color(0xFFFFFFFF);
  static const _blush = Color(0x8CFF8FB1);
  static const _gold = Color(0xFFFFD54F);

  Color get _dark => Color.lerp(body, Colors.black, 0.68)!;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas
      ..save()
      ..translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2)
      ..scale(s);

    // Breathing: a gentle bob with a hint of squash.
    final phase = breath * 2 * pi;
    var dy = -1.8 * sin(phase);
    var squash = 0.022 * cos(phase);
    // Hop: crouch, leap, land.
    if (hop > 0) {
      if (hop < 0.15) {
        squash += 0.14 * (hop / 0.15);
      } else if (hop < 0.75) {
        final u = (hop - 0.15) / 0.6;
        dy -= 20 * sin(u * pi);
        // Spring out of the crouch, stretch while airborne.
        squash += 0.14 * max(0.0, 1 - u / 0.15) - 0.08 * sin(u * pi);
      } else {
        final v = (hop - 0.75) / 0.25;
        squash += 0.12 * sin(v * pi) * (1 - v);
      }
    }

    if (shadow) {
      final lift = (-dy / 22).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 95), width: 44 * (1 - 0.45 * lift), height: 6 * (1 - 0.45 * lift)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.13 * (1 - 0.5 * lift))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    canvas
      ..translate(0, dy)
      ..translate(50, 90)
      ..scale(1 + squash, 1 - squash)
      ..translate(-50, -90);

    // Body and shine.
    final drop = Path()
      ..moveTo(50, 6)
      ..cubicTo(50, 6, 20, 38, 20, 60)
      ..arcToPoint(const Offset(80, 60), radius: const Radius.circular(30), clockwise: false)
      ..cubicTo(80, 38, 50, 6, 50, 6)
      ..close();
    canvas
      ..drawPath(
        drop,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(body, Colors.white, 0.3)!, Color.lerp(body, Colors.black, 0.14)!],
          ).createShader(const Rect.fromLTWH(20, 6, 60, 84)),
      )
      ..drawPath(
        Path()
          ..moveTo(31.5, 53)
          ..cubicTo(31.5, 46, 35.5, 39, 40.5, 33),
        _stroke(_white.withValues(alpha: 0.45), 4.2),
      );

    _paintFace(canvas);
    canvas.restore();
  }

  void _paintFace(Canvas canvas) {
    const left = Offset(40, 60);
    const right = Offset(60, 60);
    switch (face) {
      case InkyFace.happy:
        _openEye(canvas, left);
        _openEye(canvas, right);
        _smile(canvas);
        _cheeks(canvas);
      case InkyFace.excited:
        _arcEye(canvas, left, up: true);
        _arcEye(canvas, right, up: true);
        _bigMouth(canvas);
        _cheeks(canvas);
        _sparkles(canvas);
      case InkyFace.neutral:
        _openEye(canvas, left);
        _openEye(canvas, right);
        canvas.drawLine(const Offset(44.5, 72), const Offset(55.5, 72), _stroke(_white, 2.6));
      case InkyFace.meh:
        _openEye(canvas, left, lid: 0.45, lookOverride: const Offset(0.7, 0.2));
        _openEye(canvas, right, lid: 0.45, lookOverride: const Offset(0.7, 0.2));
        canvas.drawPath(
          Path()
            ..moveTo(42.5, 73)
            ..quadraticBezierTo(45, 70.5, 47.5, 73)
            ..quadraticBezierTo(50, 75.5, 52.5, 73)
            ..quadraticBezierTo(55, 70.5, 57.5, 73),
          _stroke(_white, 2.3),
        );
      case InkyFace.sad:
        _openEye(canvas, left, lookOverride: const Offset(0, 0.8));
        _openEye(canvas, right, lookOverride: const Offset(0, 0.8));
        final brow = _stroke(_white, 2.2);
        canvas
          ..drawLine(const Offset(34.5, 52.5), const Offset(43.5, 49.5), brow)
          ..drawLine(const Offset(56.5, 49.5), const Offset(65.5, 52.5), brow)
          ..drawPath(
            Path()
              ..moveTo(43.5, 76)
              ..quadraticBezierTo(50, 69, 56.5, 76),
            _stroke(_white, 2.6),
          )
          ..drawPath(
            Path()
              ..moveTo(65, 64)
              ..cubicTo(65, 64, 62.4, 67.6, 62.4, 69.2)
              ..arcToPoint(const Offset(67.6, 69.2), radius: const Radius.circular(2.6), clockwise: false)
              ..cubicTo(67.6, 67.6, 65, 64, 65, 64)
              ..close(),
            Paint()..color = const Color(0xFF9EDCFF),
          );
      case InkyFace.sleepy:
        _arcEye(canvas, left, up: false);
        _arcEye(canvas, right, up: false);
        _smallMouth(canvas);
        _zzz(canvas);
      case InkyFace.surprised:
        _openEye(canvas, left, scale: 1.18);
        _openEye(canvas, right, scale: 1.18);
        final brow = _stroke(_white, 2);
        canvas
          ..drawArc(Rect.fromCenter(center: left.translate(0, -9.5), width: 9, height: 5), pi * 1.15, pi * 0.7, false, brow)
          ..drawArc(Rect.fromCenter(center: right.translate(0, -9.5), width: 9, height: 5), pi * 1.15, pi * 0.7, false, brow);
        _smallMouth(canvas);
      case InkyFace.wink:
        _openEye(canvas, left);
        _arcEye(canvas, right, up: true);
        _smile(canvas);
        _cheeks(canvas);
      case InkyFace.covering:
        _smallMouth(canvas, smile: true);
        _cheeks(canvas);
        _mitten(canvas, left.translate(-1, 0), -0.25);
        _mitten(canvas, right.translate(1, 0), 0.25);
    }
  }

  void _openEye(Canvas canvas, Offset c, {double scale = 1, double lid = 0, Offset? lookOverride}) {
    final closed = blink.clamp(0.0, 1.0);
    if (closed > 0.65) {
      _arcEye(canvas, c, up: false);
      return;
    }
    final rx = 5.0 * scale;
    final ry = 6.2 * scale * (1 - closed);
    final eye = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas
      ..save()
      ..clipPath(Path()..addOval(eye))
      ..drawOval(eye, Paint()..color = _white);
    final l = lookOverride ?? look;
    final pupil = c + Offset(l.dx.clamp(-1.0, 1.0) * 1.9 * scale, l.dy.clamp(-1.0, 1.0) * 1.9 * scale + 0.6);
    canvas
      ..drawCircle(pupil, 2.9 * scale, Paint()..color = _dark)
      ..drawCircle(pupil + Offset(-1.0 * scale, -1.2 * scale), 1.0 * scale, Paint()..color = _white);
    if (lid > 0) {
      // A droopy eyelid in body colour.
      canvas.drawRect(Rect.fromLTRB(eye.left - 1, eye.top - 1, eye.right + 1, eye.top + eye.height * lid), Paint()..color = body);
    }
    canvas.restore();
  }

  /// Closed eye: "^" when [up] (happy), "‿" otherwise (asleep, blinking).
  void _arcEye(Canvas canvas, Offset c, {required bool up}) {
    final path = Path()..moveTo(c.dx - 4.6, c.dy + (up ? 1.5 : -0.5));
    path.quadraticBezierTo(c.dx, c.dy + (up ? -4.5 : 4), c.dx + 4.6, c.dy + (up ? 1.5 : -0.5));
    canvas.drawPath(path, _stroke(_white, 2.6));
  }

  void _smile(Canvas canvas) => canvas.drawPath(
    Path()
      ..moveTo(41.5, 70)
      ..quadraticBezierTo(50, 81.5, 58.5, 70)
      ..quadraticBezierTo(50, 75, 41.5, 70)
      ..close(),
    Paint()..color = _white,
  );

  void _bigMouth(Canvas canvas) {
    final mouth = Path()
      ..moveTo(40.5, 68.5)
      ..quadraticBezierTo(50, 87, 59.5, 68.5)
      ..close();
    canvas
      ..drawPath(mouth, Paint()..color = _dark)
      ..save()
      ..clipPath(mouth)
      ..drawCircle(const Offset(50, 81), 6, Paint()..color = const Color(0xFFFF7FA3))
      ..restore()
      ..drawPath(mouth, _stroke(_white, 1.8));
  }

  void _smallMouth(Canvas canvas, {bool smile = false}) {
    if (smile) {
      canvas.drawPath(
        Path()
          ..moveTo(45, 72)
          ..quadraticBezierTo(50, 77, 55, 72),
        _stroke(_white, 2.4),
      );
      return;
    }
    final o = Rect.fromCenter(center: const Offset(50, 73.5), width: 6, height: 7);
    canvas
      ..drawOval(o, Paint()..color = _dark)
      ..drawOval(o, _stroke(_white, 1.6));
  }

  void _cheeks(Canvas canvas) {
    final p = Paint()..color = _blush;
    canvas
      ..drawCircle(const Offset(31.5, 69), 4, p)
      ..drawCircle(const Offset(68.5, 69), 4, p);
  }

  void _sparkles(Canvas canvas) {
    void star(Offset c, double r, double offset) {
      final t = 0.65 + 0.35 * sin((breath + offset) * 2 * pi);
      final k = r * t;
      final path = Path()
        ..moveTo(c.dx, c.dy - k)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + k, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + k)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - k, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - k)
        ..close();
      canvas.drawPath(path, Paint()..color = _gold);
    }

    star(const Offset(15, 32), 7, 0);
    star(const Offset(86, 22), 6, 0.33);
    star(const Offset(90, 47), 4.5, 0.66);
  }

  void _zzz(Canvas canvas) {
    final ink = Color.lerp(body, Colors.white, 0.35)!;
    for (var i = 0; i < 3; i++) {
      final t = (breath + i / 3) % 1;
      final w = 5.0 + i * 2.5;
      final x = 72.0 + i * 8;
      final y = 32.0 - i * 11 - 3 * t;
      final paint = _stroke(ink.withValues(alpha: (breath == 0 ? 0.9 : 1 - t * 0.6)), 2);
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(x + w, y)
          ..lineTo(x, y + w)
          ..lineTo(x + w, y + w),
        paint,
      );
    }
  }

  void _mitten(Canvas canvas, Offset c, double angle) {
    final hand = Color.lerp(body, Colors.white, 0.62)!;
    final edge = Color.lerp(body, Colors.black, 0.3)!;
    // A little arm reaching up from the side of the body.
    final side = c.dx < 50 ? -1.0 : 1.0;
    canvas.drawPath(
      Path()
        ..moveTo(50 + side * 27, 78)
        ..quadraticBezierTo(50 + side * 31, 66, c.dx + side * 4, c.dy + 4),
      _stroke(hand, 5.5),
    );
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(angle);
    final mitt = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 16, height: 13.5), const Radius.circular(7));
    canvas
      ..drawRRect(mitt, Paint()..color = hand)
      ..drawRRect(mitt, _stroke(edge, 1.5))
      ..drawLine(const Offset(-2.7, -6), const Offset(-2.7, -1.5), _stroke(edge, 1.3))
      ..drawLine(const Offset(1.7, -6), const Offset(1.7, -1.5), _stroke(edge, 1.3))
      ..restore();
  }

  @override
  bool shouldRepaint(InkyPainter old) =>
      old.body != body ||
      old.face != face ||
      old.look != look ||
      old.breath != breath ||
      old.hop != hop ||
      old.blink != blink ||
      old.shadow != shadow;
}

enum BubbleTail { left, right }

/// A comic speech bubble.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.child, this.tail = BubbleTail.left, this.color});

  final Widget child;
  final BubbleTail tail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _BubblePainter(color ?? scheme.surfaceContainerHighest, scheme.outlineVariant, tail),
      child: Padding(
        padding: tail == BubbleTail.left
            ? const EdgeInsets.fromLTRB(26, 12, 16, 13)
            : const EdgeInsets.fromLTRB(16, 12, 26, 13),
        child: child,
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.fill, this.border, this.tail);

  final Color fill;
  final Color border;
  final BubbleTail tail;

  @override
  void paint(Canvas canvas, Size size) {
    const tailWidth = 10.0;
    final left = tail == BubbleTail.left;
    final box = Rect.fromLTRB(left ? tailWidth : 0, 0, size.width - (left ? 0 : tailWidth), size.height);
    final y = min(size.height * 0.62, size.height - 14);
    final tip = left ? Offset(0, y + 6) : Offset(size.width, y + 6);
    final edge = left ? box.left : box.right;
    final tailPath = Path()
      ..moveTo(edge, y - 9)
      ..quadraticBezierTo(edge + (left ? -2 : 2), y + 2, tip.dx, tip.dy)
      ..quadraticBezierTo(edge + (left ? 2 : -2), y + 4, edge + (left ? 2 : -2), y + 9)
      ..close();
    final shape = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(20))),
      tailPath,
    );
    canvas
      ..drawPath(shape, Paint()..color = fill)
      ..drawPath(
        shape,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.fill != fill || old.border != border || old.tail != tail;
}
