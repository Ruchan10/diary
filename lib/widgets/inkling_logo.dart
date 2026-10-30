import 'package:flutter/material.dart';

/// Inkling's mascot: a cheerful drop of ink. Drawn in a 100×100 box; the same
/// geometry is used for the launcher icon and the home-screen widget.
class InklingLogo extends StatelessWidget {
  const InklingLogo({super.key, this.size = 32, this.color, this.face = true, this.shadow = false});

  final double size;
  final Color? color;
  final bool face;
  final bool shadow;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: InkDropPainter(
        color: color ?? Theme.of(context).colorScheme.primary,
        face: face,
        shadow: shadow,
      ),
    ),
  );
}

class InkDropPainter extends CustomPainter {
  const InkDropPainter({required this.color, this.face = true, this.shadow = false});

  final Color color;
  final bool face;
  final bool shadow;

  static Path dropPath() => Path()
    ..moveTo(50, 6)
    ..cubicTo(50, 6, 20, 38, 20, 60)
    ..arcToPoint(const Offset(80, 60), radius: const Radius.circular(30), clockwise: false)
    ..cubicTo(80, 38, 50, 6, 50, 6)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas
      ..save()
      ..translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2 + 2 * s)
      ..scale(s);

    if (shadow) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(50, 94), width: 44, height: 6),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    final drop = dropPath();
    canvas.drawPath(
      drop,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.28)!, Color.lerp(color, Colors.black, 0.16)!],
        ).createShader(const Rect.fromLTWH(20, 6, 60, 84)),
    );

    // Glossy highlight.
    canvas.drawPath(
      Path()
        ..moveTo(32, 54)
        ..cubicTo(32, 47, 36, 40, 41, 34),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.2
        ..strokeCap = StrokeCap.round,
    );

    if (face) {
      final white = Paint()..color = Colors.white;
      canvas
        ..drawOval(Rect.fromCenter(center: const Offset(40.5, 61), width: 7.2, height: 9.6), white)
        ..drawOval(Rect.fromCenter(center: const Offset(59.5, 61), width: 7.2, height: 9.6), white)
        ..drawPath(
          Path()
            ..moveTo(41.5, 69.5)
            ..quadraticBezierTo(50, 81, 58.5, 69.5)
            ..quadraticBezierTo(50, 74, 41.5, 69.5)
            ..close(),
          white,
        );
      final blush = Paint()..color = const Color(0xFFFF8FB1).withValues(alpha: 0.55);
      canvas
        ..drawCircle(const Offset(32.5, 70), 3.6, blush)
        ..drawCircle(const Offset(67.5, 70), 3.6, blush);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(InkDropPainter old) => old.color != color || old.face != face || old.shadow != shadow;
}
