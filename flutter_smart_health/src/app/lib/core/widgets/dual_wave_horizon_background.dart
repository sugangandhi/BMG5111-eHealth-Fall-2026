import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the Mix C dual-wave translucent cerulean-seafoam horizon background
/// used behind the Home dashboard and Sign In screen.
class DualWaveHorizonBackground extends StatelessWidget {
  const DualWaveHorizonBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFDCEBFB),
                  Color(0xFFE8F3F6),
                  Color(0xFFEEF3FA),
                ],
                stops: [0.0, 0.36, 1.0],
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _DualWaveHorizonPainter(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _WaveLayerSpec {
  const _WaveLayerSpec({
    required this.rightY,
    required this.ctrl1X,
    required this.ctrl1Y,
    required this.midX,
    required this.midY,
    required this.ctrl2X,
    required this.ctrl2Y,
    required this.leftY,
    required this.opacity,
    required this.colors,
  });

  final double rightY;
  final double ctrl1X;
  final double ctrl1Y;
  final double midX;
  final double midY;
  final double ctrl2X;
  final double ctrl2Y;
  final double leftY;
  final double opacity;
  final List<Color> colors;
}

class _DualWaveHorizonPainter extends CustomPainter {
  const _DualWaveHorizonPainter();

  static const _refWidth = 392.0;
  static const _refHeight = 772.0;

  static const List<_WaveLayerSpec> _waves = [
    _WaveLayerSpec(
      rightY: 248,
      ctrl1X: 265,
      ctrl1Y: 205,
      midX: 160,
      midY: 242,
      ctrl2X: 68,
      ctrl2Y: 272,
      leftY: 224,
      opacity: 0.16,
      colors: [Color(0xFF0F9D8A), Color(0xFF0F5C9C)],
    ),
    _WaveLayerSpec(
      rightY: 188,
      ctrl1X: 290,
      ctrl1Y: 235,
      midX: 186,
      midY: 195,
      ctrl2X: 92,
      ctrl2Y: 160,
      leftY: 202,
      opacity: 0.26,
      colors: [Color(0xFF0F5C9C), Color(0xFF0E7C94), Color(0xFF1E88C7)],
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _refWidth;
    final sy = (size.height / _refHeight).clamp(0.92, 1.35);
    for (final wave in _waves) {
      _paintWave(canvas, size.width, sx, sy, wave);
    }

    // Soft emerald glow tucked on top-left so the top-right emerald ring pops.
    final glowCenter = Offset(96 * sx, 54 * sy);
    final glowPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.10);
    canvas.drawCircle(glowCenter, 88 * sx.clamp(0.85, 1.4), glowPaint);
  }

  void _paintWave(
    Canvas canvas,
    double width,
    double sx,
    double sy,
    _WaveLayerSpec wave,
  ) {
    final rightY = wave.rightY * sy;
    final ctrl1Y = wave.ctrl1Y * sy;
    final midY = wave.midY * sy;
    final ctrl2Y = wave.ctrl2Y * sy;
    final leftY = wave.leftY * sy;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(width, 0)
      ..lineTo(width, rightY)
      ..quadraticBezierTo(
        wave.ctrl1X * sx,
        ctrl1Y,
        wave.midX * sx,
        midY,
      )
      ..quadraticBezierTo(
        wave.ctrl2X * sx,
        ctrl2Y,
        0,
        leftY,
      )
      ..close();

    final rect = Rect.fromLTWH(0, 0, width, math.max(ctrl2Y, rightY));
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: wave.colors
            .map((c) => c.withValues(alpha: wave.opacity))
            .toList(),
      ).createShader(rect);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DualWaveHorizonPainter oldDelegate) => false;
}
