import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Atmospheric sky moods inspired by Apple Weather on watchOS.
enum SkyMood {
  daylight('Daylight Sky', Icons.wb_sunny_rounded),
  goldenDusk('Golden Dusk', Icons.wb_twilight_rounded),
  starlight('Starlight Blue', Icons.nights_stay_rounded);

  const SkyMood(this.label, this.icon);
  final String label;
  final IconData icon;

  SkyMood next() {
    final values = SkyMood.values;
    return values[(index + 1) % values.length];
  }
}

class _SkyMoodPalette {
  const _SkyMoodPalette({
    required this.skyStops,
    required this.sunCenterRatio,
    required this.sunInnerColor,
    required this.sunMidColor,
    required this.sunOuterColor,
    required this.beamTint,
    required this.cloudAlphaScale,
    required this.showStars,
  });

  final List<Color> skyStops;
  final Offset sunCenterRatio;
  final Color sunInnerColor;
  final Color sunMidColor;
  final Color sunOuterColor;
  final Color beamTint;
  final double cloudAlphaScale;
  final bool showStars;

  static _SkyMoodPalette forMood(SkyMood mood) {
    switch (mood) {
      case SkyMood.daylight:
        return const _SkyMoodPalette(
          skyStops: [
            Color(0xFF1345B5), // Zenith: Radiant Royal Sky Azure
            Color(0xFF1852C8), // Upper atmosphere: Deep cerulean
            Color(0xFF0369A1), // Mid sky: Horizon oceanic blue
            Color(0xFF0B2668), // Twilight transition: Celestial sapphire
            Color(0xFF071946), // Nadir: Deep midnight blue (zero black)
          ],
          sunCenterRatio: Offset(0.76, 0.12),
          sunInnerColor: Color(0xFFBAE6FD),
          sunMidColor: Color(0xFF38BDF8),
          sunOuterColor: Color(0xFF1D4ED8),
          beamTint: Color(0xFF38BDF8),
          cloudAlphaScale: 1.0,
          showStars: false,
        );
      case SkyMood.goldenDusk:
        return const _SkyMoodPalette(
          skyStops: [
            Color(0xFF1D3F9E), // Upper twilight azure
            Color(0xFF3730A3), // Rich dusk indigo
            Color(0xFF5B21B6), // Atmospheric twilight violet
            Color(0xFF9D174D), // Horizon coral glow
            Color(0xFF1E1B4B), // Deep dusk indigo base
          ],
          sunCenterRatio: Offset(0.72, 0.24),
          sunInnerColor: Color(0xFFFDE68A),
          sunMidColor: Color(0xFFF59E0B),
          sunOuterColor: Color(0xFFEC4899),
          beamTint: Color(0xFFFBBF24),
          cloudAlphaScale: 0.95,
          showStars: false,
        );
      case SkyMood.starlight:
        return const _SkyMoodPalette(
          skyStops: [
            Color(0xFF0D2D7A), // Rich sapphire zenith (never pitch black)
            Color(0xFF143FA8), // Luminous celestial midnight blue
            Color(0xFF0F338A), // Deep starlight blue
            Color(0xFF0B2260), // Oceanic indigo
            Color(0xFF071742), // Saturated deep blue base
          ],
          sunCenterRatio: Offset(0.80, 0.14),
          sunInnerColor: Color(0xFFE0F2FE),
          sunMidColor: Color(0xFF7DD3FC),
          sunOuterColor: Color(0xFF1E40AF),
          beamTint: Color(0xFF7DD3FC),
          cloudAlphaScale: 0.72,
          showStars: true,
        );
    }
  }
}

/// Photorealistic living atmospheric sky background.
///
/// Renders multi-stop Rayleigh sky scattering, volumetric sun/moon corona,
/// diagonal crepuscular light shafts, multi-altitude drifting cloud billows,
/// sunlit micro-motes, optional twinkling starlight, and active module tint.
class AtmosphericSkyBackground extends StatefulWidget {
  final Color? ambientAccent;
  final SkyMood mood;

  const AtmosphericSkyBackground({
    super.key,
    this.ambientAccent,
    this.mood = SkyMood.daylight,
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
            palette: _SkyMoodPalette.forMood(widget.mood),
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AtmosphericSkyPainter extends CustomPainter {
  final double time;
  final Color? ambientAccent;
  final _SkyMoodPalette palette;

  _AtmosphericSkyPainter({
    required this.time,
    required this.ambientAccent,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Volumetric Rayleigh Sky Dome Gradient (Zero Pitch-Black)
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: palette.skyStops,
        stops: const [0.0, 0.26, 0.58, 0.82, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // 2. Twinkling Stars in Starlight Mood
    if (palette.showStars) {
      _drawStarfield(canvas, size);
    }

    // 3. Volumetric Sun / Moon Corona & Expansive Atmospheric Light Bleed
    final sunX = size.width * palette.sunCenterRatio.dx +
        (math.sin(time * 2 * math.pi) * 22);
    final sunY = size.height * palette.sunCenterRatio.dy +
        (math.cos(time * 2 * math.pi) * 14);
    final sunCenter = Offset(sunX, sunY);

    final sunBleedPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          palette.sunInnerColor.withValues(alpha: 0.38),
          palette.sunMidColor.withValues(alpha: 0.22),
          palette.sunOuterColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ).createShader(
        Rect.fromCircle(center: sunCenter, radius: size.width * 0.95),
      );
    canvas.drawCircle(sunCenter, size.width * 0.95, sunBleedPaint);

    final sunCorePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 55);
    canvas.drawCircle(sunCenter, 80, sunCorePaint);

    // 4. Volumetric Crepuscular Sunbeams
    for (int i = 0; i < 3; i++) {
      final angle = (math.pi / 4.2) +
          (i * 0.14) +
          (math.sin((time + i * 0.2) * 2 * math.pi) * 0.04);
      final beamLength = size.height * 1.3;
      final beamWidth = 90.0 + (i * 35.0);

      final path = Path()
        ..moveTo(sunCenter.dx - 20, sunCenter.dy)
        ..lineTo(sunCenter.dx + beamWidth * 0.3, sunCenter.dy)
        ..lineTo(
          sunCenter.dx - 20 - math.cos(angle) * beamLength + beamWidth,
          sunCenter.dy + math.sin(angle) * beamLength,
        )
        ..lineTo(
          sunCenter.dx - 20 - math.cos(angle) * beamLength - beamWidth,
          sunCenter.dy + math.sin(angle) * beamLength,
        )
        ..close();

      final beamOpacity =
          (0.07 + (math.sin((time * 2 + i) * math.pi) * 0.025)).clamp(0.04, 0.12);
      final beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: beamOpacity),
            palette.beamTint.withValues(alpha: beamOpacity * 0.6),
            Colors.transparent,
          ],
        ).createShader(path.getBounds())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 48);

      canvas.drawPath(path, beamPaint);
    }

    // 5. Multi-Octave Procedural Volumetric Cloud Billows (Layered Parallax)
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      speed: 0.25,
      baseY: size.height * 0.20,
      scale: 1.1,
      opacity: 0.12 * palette.cloudAlphaScale,
      blurRadius: 52,
      seedOffset: 0.05,
    );
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      speed: 0.45,
      baseY: size.height * 0.48,
      scale: 1.35,
      opacity: 0.16 * palette.cloudAlphaScale,
      blurRadius: 64,
      seedOffset: 0.42,
    );
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      speed: 0.70,
      baseY: size.height * 0.80,
      scale: 1.5,
      opacity: 0.13 * palette.cloudAlphaScale,
      blurRadius: 72,
      seedOffset: 0.78,
    );

    // 6. Harmonic Ambient Module Accent Glow
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

    // 7. Atmospheric Sunlit Floating Micro-Motes
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

  void _drawStarfield(Canvas canvas, Size size) {
    final starPaint = Paint();
    for (int i = 0; i < 42; i++) {
      final s1 = (math.sin(i * 91.7 + 1.3) * 43758.5453).abs();
      final s2 = (math.cos(i * 47.3 + 2.7) * 43758.5453).abs();
      final rx = s1 - s1.floor();
      final ry = (s2 - s2.floor()) * 0.65;
      final twinkle = 0.25 + 0.55 * (0.5 + 0.5 * math.sin((time * 6 + i) * math.pi));
      final radius = 0.7 + ((i % 3) * 0.45);
      starPaint.color = Colors.white.withValues(alpha: twinkle.clamp(0.18, 0.85));
      canvas.drawCircle(Offset(rx * size.width, ry * size.height), radius, starPaint);
    }
  }

  void _drawVolumetricCloudLayer({
    required Canvas canvas,
    required Size size,
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

    final loopCycle = (time * speed + seedOffset) % 1.0;
    final totalWidth = size.width * 1.8;
    final centerX = (loopCycle * totalWidth) - (size.width * 0.4);
    final baseRadius = 65.0 * scale;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, baseY),
        width: baseRadius * 2.2,
        height: baseRadius * 1.3,
      ),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX - baseRadius * 0.7, baseY + baseRadius * 0.15),
        width: baseRadius * 1.6,
        height: baseRadius * 1.0,
      ),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + baseRadius * 0.8, baseY + baseRadius * 0.10),
        width: baseRadius * 1.7,
        height: baseRadius * 1.1,
      ),
      cloudPaint,
    );
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
        oldDelegate.ambientAccent != ambientAccent ||
        oldDelegate.palette.skyStops != palette.skyStops;
  }
}
