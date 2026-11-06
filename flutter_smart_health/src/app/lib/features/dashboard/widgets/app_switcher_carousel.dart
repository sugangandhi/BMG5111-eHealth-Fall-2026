import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class AppSwitcherCarousel extends StatefulWidget {
  final void Function(String route) onSelectApp;

  const AppSwitcherCarousel({
    super.key,
    required this.onSelectApp,
  });

  @override
  State<AppSwitcherCarousel> createState() => _AppSwitcherCarouselState();
}

class _AppSwitcherCarouselState extends State<AppSwitcherCarousel>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _pulseController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // 0.58 viewportFraction allows cards above and below to peek in vertically
    _pageController = PageController(
      viewportFraction: 0.58,
      initialPage: 0,
    );

    _pageController.addListener(() {
      setState(() {});
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = _getAppsList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        double currentPageValue = _currentPage.toDouble();
        if (_pageController.hasClients && _pageController.page != null) {
          currentPageValue = _pageController.page!;
        }

        return Container(
          width: availableWidth,
          height: availableHeight,
          color: const Color(0xFF000000), // OLED pitch black Apple Watch backdrop
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Centered 3D Vertical Rolodex Deck (Constrained to authentic watch proportions)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                        PointerDeviceKind.stylus,
                      },
                      scrollbars: false,
                    ),
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      physics: const BouncingScrollPhysics(),
                      itemCount: apps.length,
                      onPageChanged: (idx) {
                        setState(() => _currentPage = idx);
                      },
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final delta = currentPageValue - index;

                        // 3D Rolodex Stack Transform calculations
                        double scale;
                        double opacity;
                        double rotateX;
                        double translateY;

                        if (delta > 0) {
                          // Card rolling UP and tucking into the distance
                          scale = (1.0 - (delta * 0.12)).clamp(0.84, 1.0);
                          opacity = (1.0 - (delta * 0.32)).clamp(0.55, 1.0);
                          rotateX = -delta * 0.12;
                          translateY = delta * 18.0;
                        } else {
                          // Card coming UP from bottom into center
                          final absDelta = delta.abs();
                          scale = (1.0 - (absDelta * 0.08)).clamp(0.88, 1.0);
                          opacity = (1.0 - (absDelta * 0.22)).clamp(0.68, 1.0);
                          rotateX = absDelta * 0.08;
                          translateY = -absDelta * 8.0;
                        }

                        final transformMatrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.0014) // 3D perspective
                          ..setTranslationRaw(0.0, translateY, 0.0)
                          ..rotateX(rotateX.clamp(-0.35, 0.35));

                        return Transform(
                          transform: transformMatrix,
                          alignment: Alignment.center,
                          child: Transform.scale(
                            scale: scale,
                            child: Opacity(
                              opacity: opacity,
                              child: _buildAppleWatchCard(app),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Apple Watch Vertical Scroll Indicator Track & Thumb (Right edge)
              Positioned(
                right: 8,
                top: 36,
                bottom: 36,
                child: Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: LayoutBuilder(
                    builder: (context, trackConstraints) {
                      final trackHeight = trackConstraints.maxHeight;
                      final thumbHeight =
                          (trackHeight / apps.length).clamp(24.0, 52.0);
                      final progress =
                          (currentPageValue / (apps.length - 1)).clamp(0.0, 1.0);
                      final topOffset = progress * (trackHeight - thumbHeight);

                      return Stack(
                        children: [
                          Positioned(
                            top: topOffset,
                            left: 0,
                            right: 0,
                            height: thumbHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Bottom Subtle App Index Indicator & Quick Next/Prev Controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141416).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: _currentPage > 0
                              ? () => _goToPage(_currentPage - 1)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${_currentPage + 1} of ${apps.length}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: _currentPage < apps.length - 1
                              ? () => _goToPage(_currentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Authentic Apple Watch Card with Independent Floating Circular App Icon
  Widget _buildAppleWatchCard(_AppModuleItem app) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Card Body (Deep Obsidian watchOS Material)
          GestureDetector(
            onTap: () => widget.onSelectApp(app.route),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              height: 295,
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.09),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: app.accentColor.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Space for Floating Icon + App Title + Category + Status Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Clearance for the floating circular icon badge
                      const SizedBox(width: 44),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              app.category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: app.accentColor,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // watchOS Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222225),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: app.accentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: app.accentColor.withValues(alpha: 0.6),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              app.statusText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Hero Glance Box: Hero Metric + Dynamic Visualizer + Description
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Metric Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              app.heroMetric,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: app.accentColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: app.accentColor.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                app.heroBadge,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: app.accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Live Complication Visualizer
                        _buildVisualizerForApp(app),
                        const SizedBox(height: 6),

                        // App summary description
                        Text(
                          app.description,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: Color(0xFF94A3B8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Mini Clinical Stats Row
                  Row(
                    children: [
                      _buildAppleMiniStat(app.stat1Label, app.stat1Value),
                      const SizedBox(width: 8),
                      _buildAppleMiniStat(app.stat2Label, app.stat2Value),
                    ],
                  ),

                  // Apple Watch Pill Action Button
                  Container(
                    width: double.infinity,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF242426),
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.09),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(19),
                        onTap: () => widget.onSelectApp(app.route),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              app.actionLabel,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: app.accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Independent Floating Circular App Icon (Signature 60fps Design Detail)
          Positioned(
            top: 2,
            left: 28,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: app.accentColor,
                boxShadow: [
                  BoxShadow(
                    color: app.accentColor.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  app.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mini stat pill
  Widget _buildAppleMiniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Live Complication Visualizer per App
  Widget _buildVisualizerForApp(_AppModuleItem app) {
    switch (app.type) {
      case _AppType.vitals:
        return _buildAnimatedEcg(app.accentColor);
      case _AppType.urgentCare:
        return _buildUrgentCareQueue(app.accentColor);
      case _AppType.medications:
        return _buildMedicationDoses(app.accentColor);
      case _AppType.history:
        return _buildHistoryTimeline(app.accentColor);
      case _AppType.insights:
        return _buildInsightsRing(app.accentColor);
      case _AppType.trends:
        return _buildTrendTrajectory(app.accentColor);
      case _AppType.goals:
        return _buildGoalsActivityBar(app.accentColor);
      case _AppType.bmi:
        return _buildBmiGauge(app.accentColor);
      case _AppType.clinicChat:
        return _buildClinicalChatSnippet(app.accentColor);
      case _AppType.symptoms:
        return _buildSymptomSeverityBar(app.accentColor);
      case _AppType.settings:
        return _buildSettingsSyncIndicator(app.accentColor);
    }
  }

  // 1. ECG Visualizer
  Widget _buildAnimatedEcg(Color accent) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          height: 34,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F11),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomPaint(
            painter: _EcgPainter(
              color: accent,
              progress: _pulseController.value,
            ),
          ),
        );
      },
    );
  }

  // 2. Urgent Care Queue Visualizer
  Widget _buildUrgentCareQueue(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_walk_rounded, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.65,
                backgroundColor: const Color(0xFF262628),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.local_hospital_rounded, size: 16, color: accent),
        ],
      ),
    );
  }

  // 3. Medication Doses
  Widget _buildMedicationDoses(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 15, color: accent),
              const SizedBox(width: 6),
              const Text(
                "Metformin 500mg (8 AM)",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Taken",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Vitals History Timeline
  Widget _buildHistoryTimeline(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          final heights = [14.0, 18.0, 22.0, 16.0, 26.0, 20.0, 28.0, 24.0, 19.0, 22.0, 25.0, 21.0];
          return Container(
            width: 8,
            height: heights[index % heights.length],
            decoration: BoxDecoration(
              color: index >= 9 ? accent : accent.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  // 5. Health Insights Ring
  Widget _buildInsightsRing(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: 0.98,
              strokeWidth: 3,
              backgroundColor: const Color(0xFF262628),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Normal Sinus Rhythm • 0 Clinical Alerts",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 6. Trend Trajectory
  Widget _buildTrendTrajectory(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 16, color: accent),
              const SizedBox(width: 6),
              const Text(
                "Resting HR 7-Day Curve",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            "±3.8% Stable",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // 7. Goals Activity Bar
  Widget _buildGoalsActivityBar(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_run_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.84,
                backgroundColor: const Color(0xFF262628),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "84%",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // 8. BMI Scale Gauge
  Widget _buildBmiGauge(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.fitness_center_rounded, size: 15, color: accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Optimal Body Mass Index Range (18.5 - 24.9)",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 9. Clinical Chat Snippet
  Widget _buildClinicalChatSnippet(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 15, color: accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Intelligent Digital Solution care team online",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // 10. Symptom Severity Bar
  Widget _buildSymptomSeverityBar(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.sentiment_satisfied_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 0.1,
                backgroundColor: const Color(0xFF262628),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Mild (1/10)",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // 11. Settings & Sync Indicator
  Widget _buildSettingsSyncIndicator(Color accent) {
    return Container(
      height: 34,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_done_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "AWS App Runner • 256-bit Encrypted",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // All 11 apps matching the Grid View with authentic Apple Watch accent cues
  List<_AppModuleItem> _getAppsList() {
    return [
      // 1. Wearable Vitals (Apple Health Crimson Red)
      const _AppModuleItem(
        type: _AppType.vitals,
        title: "Wearable Vitals",
        category: "HEALTH MONITORING",
        heroMetric: "78 BPM",
        heroBadge: "Sinus Rhythm",
        description:
            "Continuous live telemetry streaming heart rate, blood pressure, and SpO2 from your Apple Watch directly into the hospital EHR with automated arrhythmia alerts.",
        icon: Icons.favorite_rounded,
        statusText: "Live Sync",
        stat1Label: "HEART RATE",
        stat1Value: "78 BPM (Sinus)",
        stat2Label: "BLOOD PRESSURE",
        stat2Value: "120/80 mmHg",
        route: "/vitals",
        actionLabel: "Open Wearable Vitals",
        accentColor: Color(0xFFEF4444),
      ),

      // 2. Vitals History (Apple Sky Blue)
      const _AppModuleItem(
        type: _AppType.history,
        title: "Vitals History",
        category: "HEALTH MONITORING",
        heroMetric: "142 Logs",
        heroBadge: "Past 30 Days",
        description:
            "Browse longitudinal time-stamped archives of past physiological monitoring sessions, ECG recordings, and clinician review logs across customizable date ranges.",
        icon: Icons.history_rounded,
        statusText: "142 Records",
        stat1Label: "TOTAL SESSIONS",
        stat1Value: "142 Records",
        stat2Label: "DATE RANGE",
        stat2Value: "Past 30 Days",
        route: "/history",
        actionLabel: "View Vitals History",
        accentColor: Color(0xFF38BDF8),
      ),

      // 3. Health Insights (Apple Cyan)
      const _AppModuleItem(
        type: _AppType.insights,
        title: "Health Insights",
        category: "HEALTH MONITORING",
        heroMetric: "98% Normal",
        heroBadge: "Low Risk Tier",
        description:
            "Evaluates merged wearable telemetry and hospital records with clinical reasoning algorithms to highlight early cardiovascular risks and vital anomalies.",
        icon: Icons.insights_rounded,
        statusText: "Optimal",
        stat1Label: "RISK PROFILE",
        stat1Value: "Low / Normal",
        stat2Label: "CRITICAL ALERTS",
        stat2Value: "0 Flags",
        route: "/insights",
        actionLabel: "Explore Health Insights",
        accentColor: Color(0xFF06B6D4),
      ),

      // 4. Trend Analysis (Apple Teal)
      const _AppModuleItem(
        type: _AppType.trends,
        title: "Trend Analysis",
        category: "HEALTH MONITORING",
        heroMetric: "±4% Variance",
        heroBadge: "Stable Baseline",
        description:
            "Charts multi-day blood pressure and resting heart rate trajectories benchmarked against Hypertension Canada and AHA medical guidelines.",
        icon: Icons.trending_up_rounded,
        statusText: "Stable",
        stat1Label: "7-DAY TARGET",
        stat1Value: "Within Range",
        stat2Label: "VARIANCE",
        stat2Value: "±4% Normal",
        route: "/trends",
        actionLabel: "Analyze Health Trends",
        accentColor: Color(0xFF14B8A6),
      ),

      // 5. Medications & Rx (Apple Purple)
      const _AppModuleItem(
        type: _AppType.medications,
        title: "Medications & Rx",
        category: "HEALTH MANAGEMENT",
        heroMetric: "1 of 2 Taken",
        heroBadge: "Next: 8:00 PM",
        description:
            "Maintains your active prescription regimen with automated dose reminders, taken-dose tracking, and electronic refills with your hospital pharmacy.",
        icon: Icons.medication_rounded,
        statusText: "2 Active",
        stat1Label: "MORNING DOSE",
        stat1Value: "Taken 8:00 AM",
        stat2Label: "EVENING DOSE",
        stat2Value: "Due 8:00 PM",
        route: "/medications",
        actionLabel: "Manage Medications",
        accentColor: Color(0xFF8B5CF6),
      ),

      // 6. Symptom Logger (Apple Rose)
      const _AppModuleItem(
        type: _AppType.symptoms,
        title: "Symptom Logger",
        category: "HEALTH MANAGEMENT",
        heroMetric: "Mild (1/10)",
        heroBadge: "SOCRATES Intake",
        description:
            "Quickly record pain location, onset, severity, and triggers using the standardized SOCRATES clinical method to send direct updates to your physician.",
        icon: Icons.sick_rounded,
        statusText: "Ready",
        stat1Label: "LAST LOG",
        stat1Value: "Yesterday",
        stat2Label: "SEVERITY",
        stat2Value: "Mild (1/10)",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
        accentColor: Color(0xFFF43F5E),
      ),

      // 7. Health Goals (Apple Amber Activity)
      const _AppModuleItem(
        type: _AppType.goals,
        title: "Health Goals",
        category: "HEALTH MANAGEMENT",
        heroMetric: "8,420 Steps",
        heroBadge: "84% of Goal",
        description:
            "Track daily step counts, active calorie burn, and restorative sleep milestones to keep your lifestyle goals aligned with your medical treatment plan.",
        icon: Icons.flag_rounded,
        statusText: "84% Done",
        stat1Label: "STEP TARGET",
        stat1Value: "8,420 / 10,000",
        stat2Label: "ACTIVE BURN",
        stat2Value: "480 kcal",
        route: "/goals",
        actionLabel: "Track Health Goals",
        accentColor: Color(0xFFF59E0B),
      ),

      // 8. BMI Calculator (Apple Violet)
      const _AppModuleItem(
        type: _AppType.bmi,
        title: "BMI Calculator",
        category: "HEALTH MANAGEMENT",
        heroMetric: "22.4 BMI",
        heroBadge: "Healthy Weight",
        description:
            "Calculates body mass index from height and weight, categorizing metabolic tiers and delivering tailored dietary recommendations for cardiovascular health.",
        icon: Icons.monitor_weight_rounded,
        statusText: "Healthy",
        stat1Label: "CURRENT BMI",
        stat1Value: "22.4 (Normal)",
        stat2Label: "METABOLIC TIER",
        stat2Value: "Optimal Range",
        route: "/bmi",
        actionLabel: "Calculate BMI",
        accentColor: Color(0xFFA855F7),
      ),

      // 9. Urgent Care Clinic (Apple Hospital Blue)
      const _AppModuleItem(
        type: _AppType.urgentCare,
        title: "Urgent Care Clinic",
        category: "CLINICAL & URGENT",
        heroMetric: "#4 in Queue",
        heroBadge: "Est. 12m Wait",
        description:
            "Check into the hospital urgent care queue before arrival, monitor live wait times, and send real-time condition updates directly to the triage nurse.",
        icon: Icons.local_hospital_rounded,
        statusText: "Open Now",
        stat1Label: "QUEUE POSITION",
        stat1Value: "#4 in Line",
        stat2Label: "EST. WAIT",
        stat2Value: "12 Minutes",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
        accentColor: Color(0xFF3B82F6),
      ),

      // 10. AI Health Assistant (Apple Emerald / Mint)
      const _AppModuleItem(
        type: _AppType.clinicChat,
        title: "AI Health Assistant",
        category: "CLINICAL & URGENT",
        heroMetric: "CTAS Triage",
        heroBadge: "Care Team Online",
        description:
            "Consult with Intelligent Digital Solution care team via WhatsApp-style messaging and Whisper-1 voice dictation, backed by Canadian CTAS triage protocols.",
        icon: Icons.smart_toy_rounded,
        statusText: "Online",
        stat1Label: "CARE TEAM",
        stat1Value: "IDS Clinic Online",
        stat2Label: "TRIAGE ENGINE",
        stat2Value: "CTAS Level 1-5",
        route: "/assistant",
        actionLabel: "Start Clinical Chat",
        accentColor: Color(0xFF10B981),
      ),

      // 11. Settings & Telemetry (Apple Slate)
      const _AppModuleItem(
        type: _AppType.settings,
        title: "Settings & Telemetry",
        category: "SYSTEM & TELEMETRY",
        heroMetric: "AWS Synced",
        heroBadge: "App Runner Live",
        description:
            "Configure Apple Watch HealthKit background syncing, verify AWS App Runner connectivity, manage AI provider keys, and update profile credentials.",
        icon: Icons.settings_rounded,
        statusText: "Connected",
        stat1Label: "EHR ENDPOINT",
        stat1Value: "AWS App Runner",
        stat2Label: "SYSTEM HEALTH",
        stat2Value: "All Systems 100%",
        route: "/settings",
        actionLabel: "Open App Settings",
        accentColor: Color(0xFF94A3B8),
      ),
    ];
  }
}

enum _AppType {
  vitals,
  history,
  insights,
  trends,
  medications,
  symptoms,
  goals,
  bmi,
  urgentCare,
  clinicChat,
  settings,
}

class _AppModuleItem {
  final _AppType type;
  final String title;
  final String category;
  final String heroMetric;
  final String heroBadge;
  final String description;
  final IconData icon;
  final String statusText;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String route;
  final String actionLabel;
  final Color accentColor;

  const _AppModuleItem({
    required this.type,
    required this.title,
    required this.category,
    required this.heroMetric,
    required this.heroBadge,
    required this.description,
    required this.icon,
    required this.statusText,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.route,
    required this.actionLabel,
    required this.accentColor,
  });
}

// ECG Waveform Painter with smooth pulse animation
class _EcgPainter extends CustomPainter {
  final Color color;
  final double progress;

  _EcgPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final h = size.height;
    final w = size.width;
    final mid = h * 0.52;

    path.moveTo(0, mid);
    path.lineTo(w * 0.18, mid);
    // P wave
    path.quadraticBezierTo(w * 0.23, mid - (h * 0.22), w * 0.28, mid);
    path.lineTo(w * 0.35, mid);
    // QRS complex
    path.lineTo(w * 0.38, mid + (h * 0.18)); // Q
    path.lineTo(w * 0.44, h * 0.12); // R spike
    path.lineTo(w * 0.49, h * 0.88); // S dip
    path.lineTo(w * 0.54, mid); // back to baseline
    path.lineTo(w * 0.62, mid);
    // T wave
    path.quadraticBezierTo(w * 0.70, mid - (h * 0.32), w * 0.78, mid);
    path.lineTo(w, mid);

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Live glowing head indicator dot
    final dotX = (w * 0.44) + (math.sin(progress * 2 * math.pi) * 4);
    final dotY = (h * 0.12) + (math.cos(progress * 2 * math.pi) * 3);

    final dotGlow = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 4.5, dotGlow);

    final dotCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 2.2, dotCenter);
  }

  @override
  bool shouldRepaint(covariant _EcgPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
