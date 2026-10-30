import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/celebrations.dart';
import '../theme/moods.dart';
import '../theme/theme.dart';
import 'inky.dart';

/// Sits above every screen and shows the current [Cheer]: a banner that drops
/// in from the top, plus a burst of ink-drop confetti.
class CelebrationLayer extends StatelessWidget {
  const CelebrationLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final celebrations = context.watch<Celebrations>();
    final cheer = celebrations.current;
    final motion = playfulMotion(context);
    return Stack(
      children: [
        if (cheer != null && cheer.confetti && motion)
          Positioned.fill(child: IgnorePointer(child: InkConfetti(key: ValueKey(celebrations.serial)))),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: Duration(milliseconds: motion ? 650 : 200),
              reverseDuration: const Duration(milliseconds: 250),
              switchInCurve: motion ? Curves.elasticOut : Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation.drive(CurveTween(curve: const Interval(0, 0.4))),
                child: SlideTransition(
                  position: animation.drive(Tween(begin: const Offset(0, -0.6), end: Offset.zero)),
                  child: child,
                ),
              ),
              child: cheer == null
                  ? const SizedBox.shrink()
                  : _CheerCard(key: ValueKey(celebrations.serial), cheer: cheer, onTap: celebrations.dismiss),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheerCard extends StatefulWidget {
  const _CheerCard({super.key, required this.cheer, required this.onTap});

  final Cheer cheer;
  final VoidCallback onTap;

  @override
  State<_CheerCard> createState() => _CheerCardState();
}

class _CheerCardState extends State<_CheerCard> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cheer = widget.cheer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Semantics(
        liveRegion: true,
        label: '${cheer.title}. ${cheer.subtitle ?? ''}',
        child: Material(
          color: scheme.primaryContainer,
          elevation: 8,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: scheme.surface, width: 3),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Text(cheer.emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cheer.title,
                          style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer, fontSize: 20),
                        ),
                        if (cheer.subtitle case final subtitle?)
                          Text(subtitle, style: handStyle(20, color: scheme.onPrimaryContainer, weight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const Inky(size: 52, face: InkyFace.excited, shadow: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-shot burst of ink drops, dots, stars and squiggles.
class InkConfetti extends StatefulWidget {
  const InkConfetti({super.key});

  @override
  State<InkConfetti> createState() => _InkConfettiState();
}

class _InkConfettiState extends State<InkConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward();
  final _particles = <_Particle>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_particles.isNotEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      const Color(0xFFFFC94D),
      for (final m in moods) m.color,
    ];
    final random = Random();
    for (var i = 0; i < 70; i++) {
      // Sprays out sideways and down from under the banner.
      final angle = pi / 2 + (random.nextDouble() - 0.5) * pi * 1.4;
      final speed = 300 + random.nextDouble() * 650;
      _particles.add(
        _Particle(
          shape: _Shape.values[random.nextInt(_Shape.values.length)],
          color: colors[random.nextInt(colors.length)],
          velocity: Offset(cos(angle), sin(angle)) * speed,
          spin: (random.nextDouble() - 0.5) * 10,
          size: 6 + random.nextDouble() * 8,
          sway: random.nextDouble() * 2 * pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _ConfettiPainter(_particles, _c),
      size: Size.infinite,
    ),
  );
}

enum _Shape { drop, dot, star, squiggle, heart }

class _Particle {
  _Particle({
    required this.shape,
    required this.color,
    required this.velocity,
    required this.spin,
    required this.size,
    required this.sway,
  });

  final _Shape shape;
  final Color color;
  final Offset velocity;
  final double spin;
  final double size;
  final double sway;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.animation) : super(repaint: animation);

  final List<_Particle> particles;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2.4; // seconds
    final origin = Offset(size.width / 2, 110);
    const gravity = 900.0;
    final fade = animation.value < 0.7 ? 1.0 : (1 - (animation.value - 0.7) / 0.3);
    for (final p in particles) {
      // Air drag slows the burst; gravity and a little sway take over.
      final drag = (1 - exp(-1.6 * t)) / 1.6;
      final pos =
          origin +
          p.velocity * drag +
          Offset(sin(p.sway + t * 4) * 14, 0.5 * gravity * t * t * 0.55);
      if (pos.dy > size.height + 40) continue;
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(pos.dx, pos.dy)
        ..rotate(p.spin * t);
      final s = p.size;
      switch (p.shape) {
        case _Shape.drop:
          canvas.drawPath(
            Path()
              ..moveTo(0, -s)
              ..cubicTo(0, -s, -s * 0.6, -s * 0.1, -s * 0.6, s * 0.25)
              ..arcToPoint(Offset(s * 0.6, s * 0.25), radius: Radius.circular(s * 0.6), clockwise: false)
              ..cubicTo(s * 0.6, -s * 0.1, 0, -s, 0, -s)
              ..close(),
            paint,
          );
        case _Shape.dot:
          canvas.drawCircle(Offset.zero, s * 0.45, paint);
        case _Shape.star:
          final k = s * 0.7;
          canvas.drawPath(
            Path()
              ..moveTo(0, -k)
              ..quadraticBezierTo(0, 0, k, 0)
              ..quadraticBezierTo(0, 0, 0, k)
              ..quadraticBezierTo(0, 0, -k, 0)
              ..quadraticBezierTo(0, 0, 0, -k),
            paint,
          );
        case _Shape.squiggle:
          canvas.drawPath(
            Path()
              ..moveTo(-s, 0)
              ..quadraticBezierTo(-s / 2, -s / 2, 0, 0)
              ..quadraticBezierTo(s / 2, s / 2, s, 0),
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round,
          );
        case _Shape.heart:
          final h = s * 0.5;
          canvas.drawPath(
            Path()
              ..moveTo(0, h * 0.9)
              ..cubicTo(-h * 1.8, -h * 0.4, -h * 0.6, -h * 1.6, 0, -h * 0.5)
              ..cubicTo(h * 0.6, -h * 1.6, h * 1.8, -h * 0.4, 0, h * 0.9)
              ..close(),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
