import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Top-bar shortcut pill opening the AI Health Assistant with three multi-color stars.
class AskAiShortcutPill extends StatelessWidget {
  const AskAiShortcutPill({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ask AI Health Assistant',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Ink(
            height: 38,
            padding: const EdgeInsets.only(left: 10, right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF9CE7C4)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEDFBF4),
                  Color(0xFFD7F5E8),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2410B981),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: Size(22, 21),
                  painter: _ThreeStarAiPainter(),
                ),
                SizedBox(width: 6),
                Text(
                  'Ask AI',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StarSpec {
  const _StarSpec({
    required this.center,
    required this.radius,
    required this.colors,
  });

  final Offset center;
  final double radius;
  final List<Color> colors;
}

class _ThreeStarAiPainter extends CustomPainter {
  const _ThreeStarAiPainter();

  // Big (Emerald), Small (Cerulean), and Smaller (Coral-Amber) 4-point stars.
  static const List<_StarSpec> _stars = [
    _StarSpec(
      center: Offset(9.5, 10.6),
      radius: 7.5,
      colors: [Color(0xFF047857), Color(0xFF10B981)],
    ),
    _StarSpec(
      center: Offset(19.2, 5.6),
      radius: 3.8,
      colors: [Color(0xFF0369A1), Color(0xFF38BDF8)],
    ),
    _StarSpec(
      center: Offset(21.0, 15.7),
      radius: 2.5,
      colors: [Color(0xFFE85D4A), Color(0xFFF59E0B)],
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26.0, size.height / 24.0);
    for (final star in _stars) {
      _paintFourPointStar(canvas, star);
    }
    canvas.restore();
  }

  void _paintFourPointStar(Canvas canvas, _StarSpec star) {
    final c = star.center;
    final r = star.radius;
    final waist = r * 0.24;

    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + waist, c.dy - waist, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + waist, c.dy + waist, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - waist, c.dy + waist, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - waist, c.dy - waist, c.dx, c.dy - r)
      ..close();

    final rect = Rect.fromCircle(center: c, radius: r);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: star.colors,
      ).createShader(rect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ThreeStarAiPainter oldDelegate) => false;
}
