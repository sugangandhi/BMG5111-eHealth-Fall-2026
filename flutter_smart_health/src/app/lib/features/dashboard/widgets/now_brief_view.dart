import 'package:flutter/material.dart';

class NowBriefView extends StatelessWidget {
  final void Function(String route) onOpenApp;

  const NowBriefView({
    super.key,
    required this.onOpenApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161824), // Authentic One UI Now Brief deep slate
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Weather Header with Ottawa scenic art backdrop
            _buildHeroWeatherHeader(context),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. "End of the day" Section
                  const Text(
                    "End of the day",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Enjoy a peaceful and restful night.",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Section: "Personalize your Now brief."
                  const Text(
                    "Personalize your Now brief.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Aurora Mesh Glass Card ("Create your own cards")
                  _buildAuroraMeshCard(context),

                  const SizedBox(height: 26),

                  // 4. Section: "Check out these special moments from today."
                  const Text(
                    "Check out these special moments from today.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Today's moments overlapping 3D deck card
                  _buildTodaysMomentsCard(context),

                  const SizedBox(height: 26),

                  // 5. Section: "Light rain early. Low 10C."
                  const Text(
                    "Light rain early. Low 10C.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Hourly Weather & Temperature Spline Forecast Card
                  _buildHourlyForecastCard(context),

                  const SizedBox(height: 16),

                  // 6. Precipitation & Liquid Hydration Chart Card
                  _buildPrecipitationCard(context),

                  const SizedBox(height: 26),

                  // 7. Clinical Health Quick-Access Dock
                  _buildClinicalAppsDock(context),

                  const SizedBox(height: 28),
                ],
              ),
            ),

            // 8. One UI Minimalist Bottom Navigation Bar
            _buildOneUiBottomBar(context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // 1. Hero Weather Header with Scenic Lake Artwork
  Widget _buildHeroWeatherHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 310,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        image: DecorationImage(
          image: AssetImage('assets/images/weather_hero_scenery.png'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.35),
              Colors.transparent,
              const Color(0xFF161824).withValues(alpha: 0.95),
            ],
            stops: const [0.0, 0.40, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                const Text(
                  "Ottawa",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "eHospital Active",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              "14°",
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                height: 1.05,
                letterSpacing: -2,
              ),
            ),
            const Text(
              "Showers in the Vicinity",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "↑ 20° / ↓ 10°  •  Feels like 13°",
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFCBD5E1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Aurora Mesh Card ("Create your own cards")
  Widget _buildAuroraMeshCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF224354), // Luminous teal/cyan ambient mesh glow
            Color(0xFF1B363E),
            Color(0xFF222B36),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          const BoxShadow(
            color: Color(0x40000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.auto_awesome,
                color: Color(0xFF38BDF8),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                "Create your own cards",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE0F2FE),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Design your own cards for your Now brief with information that's important to you.",
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // "Not now" button
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(21),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: () {},
                      child: const Center(
                        child: Text(
                          "Not now",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // "Get started" button
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262628),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(21),
                      onTap: () => onOpenApp('/vitals'),
                      child: const Center(
                        child: Text(
                          "Get started",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. "Today's moments" Overlapping Deck Card
  Widget _buildTodaysMomentsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF212536),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Today's moments",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // User's authentic moments photo deck cropped from screenshot
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/moments_deck.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Hourly Forecast Card with Golden Connected Spline Line
  Widget _buildHourlyForecastCard(BuildContext context) {
    const hours = ["12 a.m.", "1 a.m.", "2 a.m.", "3 a.m.", "4 a.m.", "5 a.m.", "6 a.m."];
    const rainChances = ["49%", "3%", "2%", "2%", "2%", "2%", "2%"];
    const temps = [14.0, 13.0, 12.0, 12.0, 11.0, 11.0, 11.0];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF212638),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hourly Forecast Items Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(hours.length, (idx) {
              return Column(
                children: [
                  Text(
                    hours[idx],
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    idx == 0
                        ? Icons.grain_rounded
                        : idx <= 2
                            ? Icons.nightlight_round
                            : Icons.cloud_rounded,
                    color: idx == 0 ? const Color(0xFF60A5FA) : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.umbrella_rounded,
                        color: Color(0xFF94A3B8),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rainChances[idx],
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }),
          ),

          const SizedBox(height: 12),

          // Golden Connecting Spline Temperature Curve
          SizedBox(
            height: 52,
            width: double.infinity,
            child: CustomPaint(
              painter: _TemperatureSplinePainter(temperatures: temps),
            ),
          ),

          const SizedBox(height: 10),

          // Bottom "48-hour forecast >" action
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {},
              icon: const Text(
                "48-hour forecast",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              label: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Precipitation & Liquid Level Bar Chart Card
  Widget _buildPrecipitationCard(BuildContext context) {
    const hours = ["11 p.m.", "12 a.m.", "1 a.m.", "2 a.m.", "3 a.m.", "4 a.m."];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF262A3C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Precipitation",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hourly timeline labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: hours.map((h) {
              return Text(
                h,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Liquid container bar simulation
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 4),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF60A5FA),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 14),
                // Liquid filled blue water column at 12 a.m.
                Container(
                  width: 44,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFBAE6FD),
                        Color(0xFF38BDF8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Row(
            children: const [
              Text(
                "mm",
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(width: 32),
              Text(
                "0.03",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. Clinical Health Apps Quick Launcher
  Widget _buildClinicalAppsDock(BuildContext context) {
    final apps = [
      {"name": "Vitals", "route": "/vitals", "icon": Icons.favorite_rounded, "color": const Color(0xFFEF4444)},
      {"name": "Clinic AI", "route": "/assistant", "icon": Icons.smart_toy_rounded, "color": const Color(0xFF10B981)},
      {"name": "Urgent Care", "route": "/urgent-care", "icon": Icons.local_hospital_rounded, "color": const Color(0xFF3B82F6)},
      {"name": "Medications", "route": "/medications", "icon": Icons.medication_rounded, "color": const Color(0xFF8B5CF6)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2030),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: apps.map((app) {
          final color = app["color"] as Color;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpenApp(app["route"] as String),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      app["icon"] as IconData,
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app["name"] as String,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 7. One UI Bottom Floating Navigation Bar
  Widget _buildOneUiBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white70, size: 24),
            onPressed: () {},
          ),
          Container(
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white70, size: 24),
            onPressed: () => onOpenApp('/assistant'),
          ),
        ],
      ),
    );
  }
}

// Connected Spline Temperature Painter
class _TemperatureSplinePainter extends CustomPainter {
  final List<double> temperatures;

  _TemperatureSplinePainter({required this.temperatures});

  @override
  void paint(Canvas canvas, Size size) {
    if (temperatures.isEmpty) return;

    final n = temperatures.length;
    final dx = size.width / (n - 1);

    // Temperature range
    const minT = 10.0;
    const maxT = 16.0;

    List<Offset> points = [];
    for (int i = 0; i < n; i++) {
      final x = i * dx;
      final normalized = (temperatures[i] - minT) / (maxT - minT);
      final y = size.height - (normalized * (size.height - 24)) - 10;
      points.add(Offset(x, y));
    }

    // Spline curve path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < n - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (dx * 0.45);
      final controlY1 = p0.dy;
      final controlX2 = p1.dx - (dx * 0.45);
      final controlY2 = p1.dy;
      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    // Glowing golden/yellow stroke
    final glowPaint = Paint()
      ..color = const Color(0xFFFACC15).withValues(alpha: 0.35)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Node circles and temperature text
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < n; i++) {
      final p = points[i];
      canvas.drawCircle(p, 3.2, dotPaint);

      // Temperature text
      final textSpan = TextSpan(
        text: "${temperatures[i].toInt()}°",
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(p.dx - (textPainter.width / 2), p.dy + 7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemperatureSplinePainter oldDelegate) => false;
}
