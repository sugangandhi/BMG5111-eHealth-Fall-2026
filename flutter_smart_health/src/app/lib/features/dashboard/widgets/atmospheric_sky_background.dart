import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Photorealistic Living Atmospheric Sky Background
/// Inspired by Apple Weather on Apple Watch (60fps design benchmark).
/// Features:
/// - Volumetric Rayleigh sky scattering (Royal Azure to Deep Sapphire)
/// - Radiant volumetric sun source with expansive atmospheric bleed
/// - Soft crepuscular light shafts (diagonal sunbeams)
/// - Multi-altitude procedural organic drifting cloud billows with Gaussian blur
/// - Sunlit floating atmospheric micro-motes with Brownian drift
/// - Harmonic ambient tint sync with active module
class AtmosphericSkyBackground extends StatefulWidget {
  final Color? ambientAccent;

  const AtmosphericSkyBackground({
    super.key,
    this.ambientAccent,
  });

  @override
  State<AtmosphericSkyBackground> createState() =>
      _AtmosphericSkyBackgroundState();
}

class _AtmosphericSkyBackgroundState extends State<AtmosphericSkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 40-second continuous loop for majestic, serene atmospheric pacing
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _AtmosphericSkyPainter(
            time: _controller.value,
            ambientAccent: widget.ambientAccent,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AtmosphericSkyPainter extends CustomPainter {
  final double time; // 0.0 to 1.0 continuous loop
  final Color? ambientAccent;

  _AtmosphericSkyPainter({
    required this.time,
    this.ambientAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Volumetric Rayleigh Sky Dome Gradient (Zero Pitch-Black)
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1345B5), // Zenith: Radiant Royal Sky Azure
          Color(0xFF1852C8), // Upper atmosphere: Deep cerulean
          Color(0xFF0369A1), // Mid sky: Horizon oceanic blue
          Color(0xFF0B2668), // Twilight transition: Celestial sapphire
          Color(0xFF071946), // Nadir: Deep midnight blue base (fully saturated, 0 black)
        ],
        stops: [0.0, 0.26, 0.58, 0.82, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // 2. Volumetric Sun Source & Expansive Atmospheric Light Bleed
    final sunX = size.width * 0.76 + (math.sin(time * 2 * math.pi) * 22);
    final sunY = size.height * 0.12 + (math.cos(time * 2 * math.pi) * 14);
    final sunCenter = Offset(sunX, sunY);

    // Deep Atmospheric Sunlight Bleed (Soft Dome Bloom)
    final sunBleedPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          const Color(0xFFBAE6FD).withValues(alpha: 0.38), // Sun bleached cyan-white
          const Color(0xFF38BDF8).withValues(alpha: 0.22),
          const Color(0xFF1D4ED8).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(
        Rect.fromCircle(center: sunCenter, radius: size.width * 0.95),
      );
    canvas.drawCircle(sunCenter, size.width * 0.95, sunBleedPaint);

    // Brilliant Sun Core Halo (Gaussian Soft Bloom)
    final sunCorePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55);
    canvas.drawCircle(sunCenter, 80, sunCorePaint);

    // 3. Volumetric Crepuscular Sunbeams (Light Shafts Streaming Through Atmosphere)
    for (int i = 0; i < 3; i++) {
      final angle = (math.pi / 4.2) +
          (i * 0.14) +
          (math.sin((time + i * 0.2) * 2 * math.pi) * 0.04);
      final beamLength = size.height * 1.3;
      final beamWidth = 90.0 + (i * 35.0);

      final path = Path();
      path.moveTo(sunCenter.dx - 20, sunCenter.dy);
      path.lineTo(sunCenter.dx + beamWidth * 0.3, sunCenter.dy);
      path.lineTo(
        sunCenter.dx - 20 - math.cos(angle) * beamLength + beamWidth,
        sunCenter.dy + math.sin(angle) * beamLength,
      );
      path.lineTo(
        sunCenter.dx - 20 - math.cos(angle) * beamLength - beamWidth,
        sunCenter.dy + math.sin(angle) * beamLength,
      );
      path.close();

      final beamOpacity =
          (0.07 + (math.sin((time * 2 + i) * math.pi) * 0.025)).clamp(0.04, 0.12);
      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: beamOpacity),
            const Color(0xFF38BDF8).withValues(alpha: beamOpacity * 0.6),
            Colors.transparent,
          ],
        ).createShader(path.getBounds())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48);

      canvas.drawPath(path, beamPaint);
    }

    // 4. Multi-Octave Procedural Volumetric Cloud Billows (Layered Natural Parallax)
    // High-altitude slow cirrus mist
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      time: time,
      speed: 0.25,
      baseY: size.height * 0.20,
      scale: 1.1,
      opacity: 0.12,
      blurRadius: 52,
      seedOffset: 0.05,
    );

    // Mid-altitude organic cumulus billows
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      time: time,
      speed: 0.45,
      baseY: size.height * 0.48,
      scale: 1.35,
      opacity: 0.16,
      blurRadius: 64,
      seedOffset: 0.42,
    );

    // Low-altitude horizon atmospheric haze
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      time: time,
      speed: 0.70,
      baseY: size.height * 0.80,
      scale: 1.5,
      opacity: 0.13,
      blurRadius: 72,
      seedOffset: 0.78,
    );

    // 5. Harmonic Ambient Module Accent Glow
    if (ambientAccent != null) {
      final accentCenter = Offset(size.width * 0.5, size.height * 0.52);
      final accentPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            ambientAccent!.withValues(alpha: 0.24),
            ambientAccent!.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: accentCenter, radius: size.width * 0.75),
        );
      canvas.drawCircle(accentCenter, size.width * 0.75, accentPaint);
    }

    // 6. Atmospheric Sunlit Floating Micro-Motes (32 Particles with Brownian Drift)
    final motePaint = Paint();
    for (int i = 0; i < 32; i++) {
      final seed1 = math.sin(i * 12.9898) * 43758.5453;
      final seed2 = math.cos(i * 78.233) * 43758.5453;
      final seed3 = math.sin(i * 39.425) * 43758.5453;

      final randX = (seed1 - seed1.floor()).abs();
      final randY = (seed2 - seed2.floor()).abs();
      final randSpeed = 0.06 + (seed3 - seed3.floor()).abs() * 0.10;
      final randSize = 1.4 + ((seed1 + seed2) % 1.0).abs() * 2.0;

      final x = (randX * size.width + math.sin((time * 4 + i) * math.pi) * 14) %
          size.width;
      final y = ((randY - (time * randSpeed)) % 1.0) * size.height;
      final alpha =
          (0.18 + math.sin((time * 3 + i * 0.7) * math.pi) * 0.14).clamp(0.08, 0.42);

      motePaint.color = Colors.white.withValues(alpha: alpha);
      motePaint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), randSize, motePaint);
    }
  }

  /// Renders a multi-lobed organic cloud bank drifting smoothly across the sky
  void _drawVolumetricCloudLayer({
    required Canvas canvas,
    required Size size,
    required double time,
    required double speed,
    required double baseY,
    required double scale,
    required double opacity,
    required double blurRadius,
    required double seedOffset,
  }) {
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    // Continuous loop wrapping smoothly across horizontal width
    final loopCycle = (time * speed + seedOffset) % 1.0;
    final totalWidth = size.width * 1.8;
    final centerX = (loopCycle * totalWidth) - (size.width * 0.4);

    // Multi-lobed cloud cluster (Left lobe, center crown, right lobe, lower shelf)
    final baseRadius = 65.0 * scale;

    // Lobe 1 (Center crown)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, baseY),
        width: baseRadius * 2.2,
        height: baseRadius * 1.3,
      ),
      cloudPaint,
    );

    // Lobe 2 (Left billow)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - baseRadius * 0.7, baseY + baseRadius * 0.15),
        width: baseRadius * 1.6,
        height: baseRadius * 1.0,
      ),
      cloudPaint,
    );

    // Lobe 3 (Right billow)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + baseRadius * 0.8, baseY + baseRadius * 0.10),
        width: baseRadius * 1.7,
        height: baseRadius * 1.1,
      ),
      cloudPaint,
    );

    // Lobe 4 (Lower soft shelf)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + baseRadius * 0.1, baseY + baseRadius * 0.35),
        width: baseRadius * 2.4,
        height: baseRadius * 0.9,
      ),
      cloudPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AtmosphericSkyPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.ambientAccent != ambientAccent;
  }
}
