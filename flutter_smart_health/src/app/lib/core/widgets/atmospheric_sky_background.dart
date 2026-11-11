import 'package:flutter/material.dart';

/// Atmospheric sky moods kept for backwards compatibility with callers.
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
    required this.cloudAlphaScale,
  });

  final List<Color> skyStops;
  final double cloudAlphaScale;

  static _SkyMoodPalette forMood(SkyMood mood) {
    // Unified glare-free deep twilight navy gradient (no harsh bright sky spots).
    return const _SkyMoodPalette(
      skyStops: [
        Color(0xFF0C224E), // Deep calm zenith navy
        Color(0xFF0A1D42), // Upper midnight azure
        Color(0xFF081737), // Mid slate sapphire
        Color(0xFF07132E), // Lower oceanic navy
        Color(0xFF050E24), // Deep base
      ],
      cloudAlphaScale: 0.25,
    );
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

    // 1. Even Deep Twilight Navy Sky Gradient (No glare or bright hotspot)
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: palette.skyStops,
        stops: const [0.0, 0.26, 0.58, 0.82, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, skyPaint);

    // 2. Soft Ambient Depth Clouds (Muted subtle haze, zero bright spots)
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      speed: 0.25,
      baseY: size.height * 0.24,
      scale: 1.15,
      opacity: 0.04 * palette.cloudAlphaScale,
      blurRadius: 64,
      seedOffset: 0.05,
    );
    _drawVolumetricCloudLayer(
      canvas: canvas,
      size: size,
      speed: 0.45,
      baseY: size.height * 0.60,
      scale: 1.40,
      opacity: 0.045 * palette.cloudAlphaScale,
      blurRadius: 72,
      seedOffset: 0.42,
    );

    // 3. Very Faint Ambient Accent Wash (keeps background calm and uniform)
    if (ambientAccent != null) {
      final accentCenter = Offset(size.width * 0.5, size.height * 0.52);
      final accentPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            ambientAccent!.withValues(alpha: 0.06),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(center: accentCenter, radius: size.width * 0.85),
        );
      canvas.drawCircle(accentCenter, size.width * 0.85, accentPaint);
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
