import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/atmospheric_sky_background.dart';
import '../data/dashboard_summary_service.dart';

class AppSwitcherCarousel extends StatefulWidget {
  final void Function(String route) onSelectApp;
  final void Function(Color accentColor)? onActiveAccentChanged;
  final DashboardLiveSummary? summary;
  final SkyMood skyMood;
  final VoidCallback? onCycleSkyMood;

  const AppSwitcherCarousel({
    super.key,
    required this.onSelectApp,
    this.onActiveAccentChanged,
    this.summary,
    this.skyMood = SkyMood.daylight,
    this.onCycleSkyMood,
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
    // 0.90 viewportFraction maximizes card width to match native mobile screen proportions
    _pageController = PageController(
      viewportFraction: 0.90,
      initialPage: 0,
    );

    _pageController.addListener(() {
      setState(() {});
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final apps = _getAppsList();
      if (apps.isNotEmpty) {
        widget.onActiveAccentChanged?.call(apps[0].accentColor);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    HapticFeedback.lightImpact();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
    final apps = _getAppsList();
    if (page >= 0 && page < apps.length) {
      widget.onActiveAccentChanged?.call(apps[page].accentColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = _getAppsList();
    final safeCurrentPage =
        apps.isEmpty ? 0 : _currentPage.clamp(0, apps.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        double currentPageValue = safeCurrentPage.toDouble();
        if (_pageController.hasClients && _pageController.page != null) {
          currentPageValue = _pageController.page!;
        }

        // Maximize card dimensions cleanly without a top name-tag/filter row
        final isNarrow = availableWidth < 500;
        final deckWidth = isNarrow ? availableWidth : 480.0;
        final deckHeight = (availableHeight - 72.0).clamp(440.0, 660.0);
        final cardHeight = deckHeight - 20.0;

        return Container(
          width: availableWidth,
          height: availableHeight,
          color: Colors.transparent, // Seamlessly inherits the Apple Weather sky gradient
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dynamic Atmospheric Accent Cloud Glow (Apple Weather Watch interactive ambient sky light)
              Positioned(
                top: (availableHeight - deckHeight) / 2 - 30,
                left: -30,
                right: -30,
                height: deckHeight + 60,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, _) {
                      double page = 0.0;
                      if (_pageController.hasClients && _pageController.page != null) {
                        page = _pageController.page!;
                      } else {
                        page = safeCurrentPage.toDouble();
                      }
                      final prevIdx = page.floor().clamp(0, apps.length - 1);
                      final nextIdx = page.ceil().clamp(0, apps.length - 1);
                      final fraction = page - page.floor();
                      final activeAccent = Color.lerp(
                        apps[prevIdx].accentColor,
                        apps[nextIdx].accentColor,
                        fraction,
                      ) ?? apps[prevIdx].accentColor;

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.72,
                            colors: [
                              activeAccent.withValues(alpha: 0.32),
                              activeAccent.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Main Expanded Carousel Interface (No name-tag bar above card)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),

                  // Horizontal 3D Carousel Deck
                  SizedBox(
                    width: deckWidth,
                    height: deckHeight,
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
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: apps.length,
                        onPageChanged: (idx) {
                          HapticFeedback.selectionClick();
                          setState(() => _currentPage = idx);
                          if (idx < apps.length) {
                            widget.onActiveAccentChanged
                                ?.call(apps[idx].accentColor);
                          }
                        },
                        itemBuilder: (context, index) {
                          final app = apps[index];
                          final delta = currentPageValue - index;

                          // 3D Horizontal Cylindrical Carousel Transform
                          final absDelta = delta.abs();
                          final scale = (1.0 - (absDelta * 0.07)).clamp(0.89, 1.0);
                          final opacity = (1.0 - (absDelta * 0.20)).clamp(0.74, 1.0);
                          final rotateY = (-delta * 0.11).clamp(-0.32, 0.32);

                          final transformMatrix = Matrix4.identity()
                            ..setEntry(3, 2, 0.0012) // 3D depth perspective
                            ..rotateY(rotateY);

                          return Transform(
                            transform: transformMatrix,
                            alignment: Alignment.center,
                            child: Transform.scale(
                              scale: scale,
                              child: Opacity(
                                opacity: opacity,
                                child: _buildAppleWatchCard(app, height: cardHeight),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bottom Row: Pagination Dots + Compact Sky Mood Toggle
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C244D)
                                    .withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(apps.length, (idx) {
                                    final isSelected = idx == safeCurrentPage;
                                    final app = apps[idx];
                                    return GestureDetector(
                                      onTap: () => _goToPage(idx),
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 6,
                                        ),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 240),
                                          curve: Curves.easeOutCubic,
                                          width: isSelected ? 22 : 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? app.accentColor
                                                : Colors.white
                                                    .withValues(alpha: 0.35),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: app.accentColor
                                                          .withValues(
                                                              alpha: 0.65),
                                                      blurRadius: 8,
                                                      offset:
                                                          const Offset(0, 1),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                          if (widget.onCycleSkyMood != null) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: widget.skyMood.label,
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onCycleSkyMood!();
                                },
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0C244D)
                                        .withValues(alpha: 0.48),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF38BDF8)
                                          .withValues(alpha: 0.50),
                                    ),
                                  ),
                                  child: Icon(
                                    widget.skyMood.icon,
                                    size: 15,
                                    color: const Color(0xFFBAE6FD),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Authentic Apple Watch Card with Independent Floating Circular App Icon (Apple Weather Glassmorphism)
  Widget _buildAppleWatchCard(_AppModuleItem app, {double? height}) {
    final cardHeight = height ?? 440.0;
    final isTall = cardHeight >= 520.0;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Card Body (Apple Weather Translucent Frosted Sky Glass)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onSelectApp(app.route);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTall ? 4 : 6,
                vertical: 6,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: isTall
                        ? const EdgeInsets.fromLTRB(20, 22, 20, 20)
                        : const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E2856).withValues(alpha: 0.48), // Apple Weather translucent frosted sky glass
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22), // Specular Apple glass reflection edge
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF041029).withValues(alpha: 0.35),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: app.accentColor.withValues(alpha: 0.16),
                          blurRadius: 22,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Row: Clearance for Floating Icon + App Title + Category + Status Pill
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Clearance for floating circular badge
                            SizedBox(width: isTall ? 54 : 48),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.title,
                                    style: TextStyle(
                                      fontSize: isTall ? 20.5 : 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    app.category,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: app.accentColor,
                                      letterSpacing: 0.8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // watchOS Frosted Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C244D).withValues(alpha: 0.52),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
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
                                      fontSize: 11.5,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: isTall ? 18 : 16,
                            vertical: isTall ? 24 : 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF071938).withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Metric Row (With Live Vitals BPM Oscillation)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, _) {
                                        final liveHr = widget.summary?.heartRateBpm;
                                        final dynamicMetric = app.type == _AppType.vitals
                                            ? (liveHr != null
                                                ? "$liveHr BPM"
                                                : "${76 + ((_pulseController.value * 3).round())} BPM")
                                            : app.heroMetric;
                                        return Text(
                                          dynamicMetric,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: isTall ? 29 : 22,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: -0.6,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: app.accentColor.withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: app.accentColor.withValues(alpha: 0.50),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        app.heroBadge,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: app.accentColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isTall ? 16 : 10),

                              // Live Complication Visualizer
                              _buildVisualizerForApp(app),
                              SizedBox(height: isTall ? 16 : 10),

                              // App summary description (full 3-4 lines with high readability)
                              Text(
                                app.description,
                                style: TextStyle(
                                  fontSize: isTall ? 14.0 : 12.5,
                                  height: isTall ? 1.48 : 1.42,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                                maxLines: isTall ? 4 : 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Mini Clinical Stats Row
                        Row(
                          children: [
                            _buildAppleMiniStat(
                              app.stat1Label,
                              app.stat1Value,
                              isTall: isTall,
                            ),
                            const SizedBox(width: 8),
                            _buildAppleMiniStat(
                              app.stat2Label,
                              app.stat2Value,
                              isTall: isTall,
                            ),
                          ],
                        ),

                        // Apple Watch Pill Action Button
                        Container(
                          width: double.infinity,
                          height: isTall ? 50 : 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                widget.onSelectApp(app.route);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        app.actionLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: app.accentColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Independent Floating Circular App Icon (Signature 60fps Design Detail with Pulsating Rhythm)
          Positioned(
            top: -2,
            left: isTall ? 22 : 20,
            child: Container(
              width: isTall ? 48 : 44,
              height: isTall ? 48 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: app.accentColor,
                boxShadow: [
                  BoxShadow(
                    color: app.accentColor.withValues(alpha: 0.50),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF041029).withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulseScale = app.type == _AppType.vitals
                        ? 1.0 + (_pulseController.value * 0.18)
                        : 1.0;
                    return Transform.scale(
                      scale: pulseScale,
                      child: Icon(
                        app.icon,
                        color: Colors.white,
                        size: 22,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mini stat pill
  Widget _buildAppleMiniStat(String label, String value, {bool isTall = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTall ? 12 : 10,
          vertical: isTall ? 10 : 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF071938).withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
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

  Widget _buildComplicationWell({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 10),
  }) {
    final wellHeight = MediaQuery.sizeOf(context).height >= 700 ? 54.0 : 38.0;
    return Container(
      height: wellHeight,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF06152F).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: child,
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
      case _AppType.sleep:
        return _buildSleepStagesBar(app.accentColor);
      case _AppType.clinicChat:
        return _buildClinicalChatSnippet(app.accentColor);
      case _AppType.symptoms:
        return _buildSymptomSeverityBar(app.accentColor);
      case _AppType.devices:
        return _buildDevicesSyncBar(app.accentColor);
    }
  }

  // 1. ECG Visualizer
  Widget _buildAnimatedEcg(Color accent) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return _buildComplicationWell(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
    final pos = widget.summary?.urgentCareQueuePosition;
    final progress = pos != null ? (1.0 / pos.clamp(1, 10)).clamp(0.2, 0.95) : 0.85;
    return _buildComplicationWell(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.directions_walk_rounded, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
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
    final s = widget.summary;
    final total = s?.medicationsTotal ?? 0;
    final taken = s?.medicationsTaken ?? 0;
    final label = total > 0
        ? (s?.nextMedicationLabel ?? 'All $total prescriptions completed')
        : 'Tap to add prescriptions & reminders';
    final badgeText = total > 0 ? '$taken/$total' : 'Setup';

    return _buildComplicationWell(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 15, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
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
    return _buildComplicationWell(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxBarH = (constraints.maxHeight - 2).clamp(24.0, 52.0);
          final ratios = [0.45, 0.58, 0.72, 0.52, 0.86, 0.65, 0.94, 0.80, 0.62, 0.72, 0.84, 0.68];
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (index) {
              return Container(
                width: 8,
                height: maxBarH * ratios[index % ratios.length],
                decoration: BoxDecoration(
                  color: index >= 9 ? accent : accent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // 5. Health Insights Ring
  Widget _buildInsightsRing(Color accent) {
    final ecg = widget.summary?.ecgStatus ?? 'Normal Sinus Rhythm';
    return _buildComplicationWell(
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              value: ecg.toLowerCase().contains('abnormal') ? 0.68 : 0.98,
              strokeWidth: 3,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$ecg • Clinical Insights Ready',
              style: const TextStyle(
                fontSize: 10.2,
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
    return _buildComplicationWell(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
    final steps = widget.summary?.stepsCount ?? 8420;
    final ratio = (steps / 10000).clamp(0.05, 1.0);
    final pct = (ratio * 100).round();
    return _buildComplicationWell(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.directions_run_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$pct%',
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
    final bmi = widget.summary?.latestBmi;
    final label = bmi != null
        ? 'Recorded BMI: ${bmi.toStringAsFixed(1)} (${widget.summary?.latestBmiCategory ?? 'Tracked'})'
        : 'Optimal Body Mass Index Range (18.5 - 24.9)';
    return _buildComplicationWell(
      child: Row(
        children: [
          Icon(Icons.fitness_center_rounded, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
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

  // 9. Sleep Stages Bar
  Widget _buildSleepStagesBar(Color accent) {
    return _buildComplicationWell(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const Row(
                  children: [
                    Expanded(flex: 25, child: ColoredBox(color: Color(0xFF4F46E5))),
                    Expanded(flex: 22, child: ColoredBox(color: Color(0xFF06B6D4))),
                    Expanded(flex: 45, child: ColoredBox(color: Color(0xFF3B82F6))),
                    Expanded(flex: 8, child: ColoredBox(color: Color(0xFFF59E0B))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Deep • REM',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // 10. Clinical Chat Snippet
  Widget _buildClinicalChatSnippet(Color accent) {
    return _buildComplicationWell(
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

  // 11. Symptom Severity Bar (Matches SymptomLoggerScreen 1-5 scale)
  Widget _buildSymptomSeverityBar(Color accent) {
    final severity = widget.summary?.latestSymptomSeverity ?? 0;
    final hasLogs = (widget.summary?.symptomsCount ?? 0) > 0;
    final ratio = hasLogs ? (severity / 5.0).clamp(0.15, 1.0) : 0.08;
    final label = hasLogs ? '${widget.summary?.latestSymptomName ?? 'Logged'} ($severity/5)' : 'Clear (0/5)';

    return _buildComplicationWell(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.sentiment_satisfied_rounded, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // 12. Wearable Devices Sync Bar
  Widget _buildDevicesSyncBar(Color accent) {
    final synced = widget.summary?.isLiveSynced ?? false;
    return _buildComplicationWell(
      child: Row(
        children: [
          Icon(Icons.watch_rounded, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              synced
                  ? 'Mobile health & wearable telemetry synced'
                  : 'Connect mobile health app or import CSV/XML',
              style: const TextStyle(
                fontSize: 10.8,
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

  List<_AppModuleItem> _getAppsList() {
    final s = widget.summary;
    final synced = s?.isLiveSynced ?? false;
    final hrText = s?.heartRateBpm != null ? '${s!.heartRateBpm} BPM' : '78 BPM';
    final bpText = s?.bloodPressure ?? '120/80 mmHg';
    final ecgText = s?.ecgStatus ?? 'Sinus Rhythm';
    final histCount = s?.vitalsHistoryCount ?? 0;
    final steps = s?.stepsCount ?? 8420;
    final calories = s?.caloriesCount ?? 480;
    final stepPct = ((steps / 10000) * 100).round().clamp(0, 100);
    final medsTotal = s?.medicationsTotal ?? 0;
    final medsTaken = s?.medicationsTaken ?? 0;
    final symptomsCount = s?.symptomsCount ?? 0;
    final symptomSeverity = s?.latestSymptomSeverity ?? 0;
    final sleepHours = s?.sleepHours;
    final bmi = s?.latestBmi;
    final queuePos = s?.urgentCareQueuePosition;

    return [
      // 1. Wearable Vitals
      _AppModuleItem(
        type: _AppType.vitals,
        title: "Wearable Vitals",
        category: "HEALTH MONITORING",
        heroMetric: hrText,
        heroBadge: ecgText,
        description:
            "Continuous live telemetry streaming heart rate, blood pressure, and SpO2 from your wearable directly into the hospital EHR with arrhythmia alerts.",
        icon: Icons.favorite_rounded,
        statusText: synced ? "Live Sync" : "Monitor",
        stat1Label: "HEART RATE",
        stat1Value: "$hrText ($ecgText)",
        stat2Label: "BLOOD PRESSURE",
        stat2Value: bpText,
        route: "/vitals",
        actionLabel: "Open Wearable Vitals",
        accentColor: const Color(0xFFEF4444),
      ),

      // 2. Vitals History
      _AppModuleItem(
        type: _AppType.history,
        title: "Vitals History",
        category: "HEALTH MONITORING",
        heroMetric: synced ? "$histCount Logs" : "Archive Ready",
        heroBadge: synced ? "EHR Synced" : "Tap to Sync",
        description:
            "Browse longitudinal time-stamped archives of past physiological monitoring sessions, ECG recordings, and clinician review logs across date ranges.",
        icon: Icons.history_rounded,
        statusText: synced ? "$histCount Records" : "Ready",
        stat1Label: "TOTAL SESSIONS",
        stat1Value: synced ? "$histCount Records" : "Cloud EHR",
        stat2Label: "DATE RANGE",
        stat2Value: "Past 30 Days",
        route: "/history",
        actionLabel: "View Vitals History",
        accentColor: const Color(0xFF38BDF8),
      ),

      // 3. Health Insights
      _AppModuleItem(
        type: _AppType.insights,
        title: "Health Insights",
        category: "HEALTH MONITORING",
        heroMetric: ecgText.toLowerCase().contains('abnormal') ? "Review Needed" : "Optimal Tier",
        heroBadge: ecgText,
        description:
            "Evaluates merged wearable telemetry and hospital records with clinical reasoning algorithms to highlight early cardiovascular risks and vital anomalies.",
        icon: Icons.insights_rounded,
        statusText: ecgText.toLowerCase().contains('abnormal') ? "Alert" : "Optimal",
        stat1Label: "ECG STATUS",
        stat1Value: ecgText,
        stat2Label: "BLOOD PRESSURE",
        stat2Value: bpText,
        route: "/insights",
        actionLabel: "Explore Health Insights",
        accentColor: const Color(0xFF06B6D4),
      ),

      // 4. Trend Analysis
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

      // 5. Sleep Analysis (newly exposed in carousel!)
      _AppModuleItem(
        type: _AppType.sleep,
        title: "Sleep Analysis",
        category: "HEALTH MONITORING",
        heroMetric: sleepHours != null ? "${sleepHours.toStringAsFixed(1)} hrs" : "7.5 hrs",
        heroBadge: "Stage Breakdown",
        description:
            "Review nightly Deep, REM, and Core sleep architecture alongside nocturnal SpO2 oxygen dips and resting heart rate recovery trends.",
        icon: Icons.bedtime_rounded,
        statusText: sleepHours != null ? "Synced" : "Tracked",
        stat1Label: "NIGHTLY SLEEP",
        stat1Value: sleepHours != null ? "${sleepHours.toStringAsFixed(1)} Hours" : "7.5h Target",
        stat2Label: "AI FEEDBACK",
        stat2Value: "Sleep Coach",
        route: "/sleep",
        actionLabel: "Open Sleep Analysis",
        accentColor: const Color(0xFF6366F1),
      ),

      // 6. Medications & Rx
      _AppModuleItem(
        type: _AppType.medications,
        title: "Medications & Rx",
        category: "HEALTH MANAGEMENT",
        heroMetric: medsTotal > 0 ? "$medsTaken of $medsTotal Taken" : "No Rx Added",
        heroBadge: medsTotal > 0
            ? (s?.nextMedicationLabel ?? "Completed Today")
            : "Tap to Schedule",
        description:
            "Maintains your active prescription regimen with automated daily dose reset, taken-dose tracking, and medication reminders.",
        icon: Icons.medication_rounded,
        statusText: "$medsTotal Active",
        stat1Label: "TAKEN TODAY",
        stat1Value: "$medsTaken / $medsTotal Doses",
        stat2Label: "NEXT DOSE",
        stat2Value: s?.nextMedicationLabel ?? (medsTotal > 0 ? "All Done" : "Not Set"),
        route: "/medications",
        actionLabel: "Manage Medications",
        accentColor: const Color(0xFF8B5CF6),
      ),

      // 7. Symptom Logger
      _AppModuleItem(
        type: _AppType.symptoms,
        title: "Symptom Logger",
        category: "HEALTH MANAGEMENT",
        heroMetric: symptomsCount > 0 ? "Severity $symptomSeverity/5" : "All Clear",
        heroBadge: s?.latestSymptomName ?? "SOCRATES Intake",
        description:
            "Quickly record symptoms, severity (1–5 scale), and onset notes so you can share accurate clinical timelines during telehealth consults.",
        icon: Icons.sick_rounded,
        statusText: "$symptomsCount Logs",
        stat1Label: "LATEST ENTRY",
        stat1Value: s?.latestSymptomName ?? "None Logged",
        stat2Label: "TOTAL LOGS",
        stat2Value: "$symptomsCount Recorded",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
        accentColor: const Color(0xFFF43F5E),
      ),

      // 8. Health Goals
      _AppModuleItem(
        type: _AppType.goals,
        title: "Health Goals",
        category: "HEALTH MANAGEMENT",
        heroMetric: "$steps Steps",
        heroBadge: "$stepPct% of Goal",
        description:
            "Track daily step counts, active calorie burn, and training milestones to keep lifestyle habits aligned with your care plan.",
        icon: Icons.flag_rounded,
        statusText: "$stepPct% Done",
        stat1Label: "STEP TARGET",
        stat1Value: "$steps / 10,000",
        stat2Label: "ACTIVE BURN",
        stat2Value: "$calories kcal",
        route: "/goals",
        actionLabel: "Track Health Goals",
        accentColor: const Color(0xFFF59E0B),
      ),

      // 9. BMI Calculator
      _AppModuleItem(
        type: _AppType.bmi,
        title: "BMI Calculator",
        category: "HEALTH MANAGEMENT",
        heroMetric: bmi != null ? "${bmi.toStringAsFixed(1)} BMI" : "Calculate BMI",
        heroBadge: s?.latestBmiCategory ?? "Metabolic Check",
        description:
            "Calculates body mass index from height and weight, categorizing metabolic tiers and saving your latest measurement for quick clinical reference.",
        icon: Icons.monitor_weight_rounded,
        statusText: s?.latestBmiCategory ?? "Ready",
        stat1Label: "LAST BMI",
        stat1Value: bmi != null ? "${bmi.toStringAsFixed(1)} kg/m²" : "Not Measured",
        stat2Label: "CATEGORY",
        stat2Value: s?.latestBmiCategory ?? "18.5 - 24.9",
        route: "/bmi",
        actionLabel: "Calculate BMI",
        accentColor: const Color(0xFFA855F7),
      ),

      // 10. Urgent Care Clinic
      _AppModuleItem(
        type: _AppType.urgentCare,
        title: "Urgent Care Clinic",
        category: "CLINICAL & URGENT",
        heroMetric: queuePos != null ? "#$queuePos in Queue" : "Walk-In Ready",
        heroBadge: s?.urgentCareWaitRange ?? "Instant Check-In",
        description:
            "Check into the hospital urgent care queue before arrival, monitor live wait times, and send real-time condition updates to triage.",
        icon: Icons.local_hospital_rounded,
        statusText: s?.urgentCareStatus ?? "Open Now",
        stat1Label: "QUEUE STATUS",
        stat1Value: queuePos != null ? "#$queuePos in Line" : "Not Checked In",
        stat2Label: "EST. WAIT",
        stat2Value: s?.urgentCareWaitRange ?? "Fast Check-In",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
        accentColor: const Color(0xFF3B82F6),
      ),

      // 11. AI Health Assistant
      const _AppModuleItem(
        type: _AppType.clinicChat,
        title: "AI Health Assistant",
        category: "CLINICAL & URGENT",
        heroMetric: "CTAS Triage",
        heroBadge: "Care Team Online",
        description:
            "Consult with Intelligent Digital Solution care team via WhatsApp messaging, lab report analysis, nutrition monitor, and Whisper voice dictation.",
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

      // 12. Wearable Devices (newly exposed in carousel!)
      _AppModuleItem(
        type: _AppType.devices,
        title: "Health App Hub",
        category: "MOBILE HEALTH & SYNC",
        heroMetric: synced ? "Connected" : "Connect App",
        heroBadge: "Android • iOS • Wearables",
        description:
            "Auto-detect Health Connect, Google Fit, Samsung Health, Apple Health, Fitbit, Garmin & more, or import health export files cleanly.",
        icon: Icons.watch_rounded,
        statusText: synced ? "Active" : "Standby",
        stat1Label: "COMPATIBLE APPS",
        stat1Value: "Multi-App Sync",
        stat2Label: "TELEMETRY SYNC",
        stat2Value: synced ? "Up to Date" : "Tap to Connect",
        route: "/devices",
        actionLabel: "Connect Health Apps",
        accentColor: const Color(0xFF0EA5E9),
      ),
    ];
  }
}

enum _AppType {
  vitals,
  history,
  insights,
  trends,
  sleep,
  medications,
  symptoms,
  goals,
  bmi,
  urgentCare,
  clinicChat,
  devices,
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
