import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/atmospheric_sky_background.dart';
import '../../../ui/app_colors.dart';
import '../data/dashboard_summary_service.dart';
import 'module_illustration_banner.dart';

/// Light Material 3 horizontal side-scrolling health module carousel with animated
/// procedural banners and icon-only bottom pager arrows.
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
  late final AnimationController _sceneController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.90,
      initialPage: 0,
    );
    _pageController.addListener(() {
      if (mounted) setState(() {});
    });

    // 12s continuous seamless loop shared across all animated banners
    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

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
    _sceneController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    final apps = _getAppsList();
    if (apps.isEmpty) return;
    final target = page.clamp(0, apps.length - 1);
    HapticFeedback.lightImpact();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
      );
    }
    widget.onActiveAccentChanged?.call(apps[target].accentColor);
  }

  void _jumpToKind(DashboardModuleKind kind) {
    final apps = _getAppsList();
    final idx = apps.indexWhere((a) => a.kind == kind);
    if (idx >= 0) {
      _goToPage(idx);
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
        final showQuickStrip = availableHeight >= 660;

        double currentPageValue = safeCurrentPage.toDouble();
        if (_pageController.hasClients && _pageController.page != null) {
          currentPageValue = _pageController.page!;
        }

        final isNarrow = availableWidth < 500;
        final deckWidth = isNarrow ? availableWidth : 480.0;
        final reservedHeight = showQuickStrip ? 148.0 : 84.0;
        final deckHeight = (availableHeight - reservedHeight).clamp(420.0, 620.0);
        final cardHeight = deckHeight - 16.0;

        return Container(
          width: availableWidth,
          height: availableHeight,
          color: AppColors.bg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showQuickStrip) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
                  child: _buildQuickSummaryStrip(),
                ),
              ],

              // Horizontal Side-Scrolling Deck
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
                        widget.onActiveAccentChanged?.call(apps[idx].accentColor);
                      }
                    },
                    itemBuilder: (context, index) {
                      final app = apps[index];
                      final delta = (currentPageValue - index).abs();
                      final scale = (1.0 - (delta * 0.05)).clamp(0.92, 1.0);
                      final opacity = (1.0 - (delta * 0.16)).clamp(0.80, 1.0);

                      return Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: _buildModuleCard(app, height: cardHeight),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Bottom Pager: Icon-only < and > arrows + compact pill indicators
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPagerArrowButton(
                        icon: Icons.chevron_left_rounded,
                        enabled: safeCurrentPage > 0,
                        onTap: () => _goToPage(safeCurrentPage - 1),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A16202C),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
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
                                      horizontal: 3.5,
                                      vertical: 6,
                                    ),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      width: isSelected ? 20 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? app.accentColor
                                            : const Color(0xFFCBD5E1),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildPagerArrowButton(
                        icon: Icons.chevron_right_rounded,
                        enabled: safeCurrentPage < apps.length - 1,
                        onTap: () => _goToPage(safeCurrentPage + 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickSummaryStrip() {
    final s = widget.summary;
    final steps = s?.stepsCount ?? 8420;
    final hr = s?.heartRateBpm;
    final sleep = s?.sleepHours;

    return Row(
      children: [
        Expanded(
          child: _buildQuickPill(
            label: 'Steps',
            value: '$steps',
            bgColor: AppColors.tealSoft,
            labelColor: AppColors.tealDark,
            onTap: () => _jumpToKind(DashboardModuleKind.goals),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickPill(
            label: 'Heart Rate',
            value: '${hr ?? 78} bpm',
            bgColor: AppColors.coralSoft,
            labelColor: AppColors.coralDark,
            onTap: () => _jumpToKind(DashboardModuleKind.vitals),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickPill(
            label: 'Sleep',
            value: sleep != null ? '${sleep.toStringAsFixed(1)} hrs' : '7.5 hrs',
            bgColor: AppColors.plumSoft,
            labelColor: AppColors.plumDark,
            onTap: () => _jumpToKind(DashboardModuleKind.sleep),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickPill({
    required String label,
    required String value,
    required Color bgColor,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagerArrowButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1.0 : 0.40,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D16202C),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppColors.textDark,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(_AppModuleItem app, {required double height}) {
    final bannerHeight = (height * 0.29).clamp(112.0, 162.0);
    final compact = height < 490;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onSelectApp(app.route);
              },
              child: Container(
                padding: EdgeInsets.all(compact ? 12 : 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D16202C),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animated Procedural Vector Header
                    AnimatedBuilder(
                      animation: _sceneController,
                      builder: (context, _) {
                        return ModuleIllustrationBanner(
                          kind: app.kind,
                          progress: _sceneController.value,
                          badgeText: app.statusText,
                          overlayValueText: app.overlayMetric,
                          accentColor: app.accentColor,
                          backgroundColor: app.softBackground,
                          height: bannerHeight,
                        );
                      },
                    ),

                    SizedBox(height: compact ? 10 : 14),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  app.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 17 : 19,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: app.softBackground,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  app.heroBadge,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: app.badgeTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            app.description,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.38,
                              color: AppColors.textMuted,
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 14),
                          Text(
                            app.heroMetric,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 26 : 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.6,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildLightStatTile(app.stat1Label, app.stat1Value),
                              const SizedBox(width: 8),
                              _buildLightStatTile(app.stat2Label, app.stat2Value),
                            ],
                          ),
                          SizedBox(height: compact ? 10 : 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                widget.onSelectApp(app.route);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: app.accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                  vertical: compact ? 11 : 13,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                app.actionLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLightStatTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AppModuleItem> _getAppsList() {
    final s = widget.summary;
    final synced = s?.isLiveSynced ?? false;
    final hrText = s?.heartRateBpm != null ? '${s!.heartRateBpm} BPM' : '78 BPM';
    final hrLower = s?.heartRateBpm != null ? '${s!.heartRateBpm} bpm' : '78 bpm';
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
        kind: DashboardModuleKind.vitals,
        title: "Wearable Vitals",
        heroMetric: hrText,
        heroBadge: ecgText,
        overlayMetric: hrLower,
        description:
            "Continuous live telemetry streaming heart rate, steps, blood pressure, and SpO2 directly from your wearable.",
        statusText: synced ? "Live Sync" : "Monitor",
        stat1Label: "DAILY STEPS",
        stat1Value: "$steps Steps",
        stat2Label: "BLOOD PRESSURE",
        stat2Value: bpText,
        route: "/vitals",
        actionLabel: "Open Wearable Vitals",
        accentColor: AppColors.primary,
        softBackground: AppColors.primarySoft,
        badgeTextColor: AppColors.primaryDark,
      ),

      // 2. Vitals History
      _AppModuleItem(
        kind: DashboardModuleKind.history,
        title: "Vitals History",
        heroMetric: synced ? "$histCount Logs" : "Archive Ready",
        heroBadge: synced ? "EHR Synced" : "Tap to Sync",
        description:
            "Browse time-stamped archives of past physiological monitoring sessions, ECG logs, and clinician reviews.",
        statusText: synced ? "$histCount Records" : "Ready",
        stat1Label: "TOTAL SESSIONS",
        stat1Value: synced ? "$histCount Records" : "Cloud EHR",
        stat2Label: "DATE RANGE",
        stat2Value: "Past 30 Days",
        route: "/history",
        actionLabel: "View Vitals History",
        accentColor: AppColors.primary,
        softBackground: AppColors.primarySoft,
        badgeTextColor: AppColors.primaryDark,
      ),

      // 3. Health Insights
      _AppModuleItem(
        kind: DashboardModuleKind.insights,
        title: "Health Insights",
        heroMetric: ecgText.toLowerCase().contains('abnormal')
            ? "Review Needed"
            : "Optimal Tier",
        heroBadge: ecgText,
        description:
            "Evaluates merged wearable telemetry and hospital records to highlight cardiovascular trends and anomalies.",
        statusText:
            ecgText.toLowerCase().contains('abnormal') ? "Alert" : "Optimal",
        stat1Label: "ECG STATUS",
        stat1Value: ecgText,
        stat2Label: "BLOOD PRESSURE",
        stat2Value: bpText,
        route: "/insights",
        actionLabel: "Explore Health Insights",
        accentColor: AppColors.primaryAccent,
        softBackground: AppColors.tealSoft,
        badgeTextColor: AppColors.tealDark,
      ),

      // 4. Trend Analysis
      const _AppModuleItem(
        kind: DashboardModuleKind.trends,
        title: "Trend Analysis",
        heroMetric: "±4% Variance",
        heroBadge: "Stable Baseline",
        description:
            "Charts multi-day blood pressure and resting heart rate trajectories benchmarked against AHA guidelines.",
        statusText: "Stable",
        stat1Label: "7-DAY TARGET",
        stat1Value: "Within Range",
        stat2Label: "VARIANCE",
        stat2Value: "±4% Normal",
        route: "/trends",
        actionLabel: "Analyze Health Trends",
        accentColor: AppColors.primaryAccent,
        softBackground: AppColors.tealSoft,
        badgeTextColor: AppColors.tealDark,
      ),

      // 5. Sleep Analysis
      _AppModuleItem(
        kind: DashboardModuleKind.sleep,
        title: "Sleep Analysis",
        heroMetric:
            sleepHours != null ? "${sleepHours.toStringAsFixed(1)} hrs" : "7.5 hrs",
        heroBadge: "Stage Breakdown",
        description:
            "Review nightly Deep, REM, and Core sleep architecture alongside nocturnal SpO2 and resting HR recovery.",
        statusText: sleepHours != null ? "Synced" : "Tracked",
        stat1Label: "NIGHTLY SLEEP",
        stat1Value:
            sleepHours != null ? "${sleepHours.toStringAsFixed(1)} Hours" : "7.5h Target",
        stat2Label: "FEEDBACK",
        stat2Value: "Sleep Coach",
        route: "/sleep",
        actionLabel: "Open Sleep Analysis",
        accentColor: AppColors.plum,
        softBackground: AppColors.plumSoft,
        badgeTextColor: AppColors.plumDark,
      ),

      // 6. Medications & Rx
      _AppModuleItem(
        kind: DashboardModuleKind.medications,
        title: "Medications & Rx",
        heroMetric: medsTotal > 0 ? "$medsTaken of $medsTotal Taken" : "No Rx Added",
        heroBadge: medsTotal > 0
            ? (s?.nextMedicationLabel ?? "Completed Today")
            : "Tap to Schedule",
        description:
            "Maintains your active prescription schedule with automated daily resets, adherence logs, and reminders.",
        statusText: "$medsTotal Active",
        stat1Label: "TAKEN TODAY",
        stat1Value: "$medsTaken / $medsTotal Doses",
        stat2Label: "NEXT DOSE",
        stat2Value: s?.nextMedicationLabel ?? (medsTotal > 0 ? "All Done" : "Not Set"),
        route: "/medications",
        actionLabel: "Manage Medications",
        accentColor: AppColors.amber,
        softBackground: AppColors.amberSoft,
        badgeTextColor: AppColors.amberDark,
      ),

      // 7. Symptom Logger
      _AppModuleItem(
        kind: DashboardModuleKind.symptoms,
        title: "Symptom Logger",
        heroMetric:
            symptomsCount > 0 ? "Severity $symptomSeverity/5" : "All Clear",
        heroBadge: s?.latestSymptomName ?? "Intake Log",
        description:
            "Record symptoms, severity levels, and onset notes to share clear clinical timelines with your care team.",
        statusText: "$symptomsCount Logs",
        stat1Label: "LATEST ENTRY",
        stat1Value: s?.latestSymptomName ?? "None Logged",
        stat2Label: "TOTAL LOGS",
        stat2Value: "$symptomsCount Recorded",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
        accentColor: AppColors.coral,
        softBackground: AppColors.coralSoft,
        badgeTextColor: AppColors.coralDark,
      ),

      // 8. Health Goals
      _AppModuleItem(
        kind: DashboardModuleKind.goals,
        title: "Health Goals",
        heroMetric: "$steps Steps",
        heroBadge: "$stepPct% of Goal",
        description:
            "Track daily step counts, active calorie burn, and activity milestones aligned with your personal care plan.",
        statusText: "$stepPct% Done",
        stat1Label: "STEP TARGET",
        stat1Value: "$steps / 10,000",
        stat2Label: "CALORIES",
        stat2Value: "$calories kcal",
        route: "/goals",
        actionLabel: "Track Health Goals",
        accentColor: AppColors.primaryAccent,
        softBackground: AppColors.tealSoft,
        badgeTextColor: AppColors.tealDark,
      ),

      // 9. BMI Calculator
      _AppModuleItem(
        kind: DashboardModuleKind.bmi,
        title: "BMI Calculator",
        heroMetric: bmi != null ? "${bmi.toStringAsFixed(1)} BMI" : "Calculate BMI",
        heroBadge: s?.latestBmiCategory ?? "Metabolic Check",
        description:
            "Calculates body mass index from height and weight and saves your latest measurement for quick clinical review.",
        statusText: s?.latestBmiCategory ?? "Ready",
        stat1Label: "LAST BMI",
        stat1Value: bmi != null ? "${bmi.toStringAsFixed(1)} kg/m²" : "Not Measured",
        stat2Label: "CATEGORY",
        stat2Value: s?.latestBmiCategory ?? "18.5 - 24.9",
        route: "/bmi",
        actionLabel: "Calculate BMI",
        accentColor: AppColors.plum,
        softBackground: AppColors.plumSoft,
        badgeTextColor: AppColors.plumDark,
      ),

      // 10. Urgent Care Clinic
      _AppModuleItem(
        kind: DashboardModuleKind.urgentCare,
        title: "Urgent Care Clinic",
        heroMetric: queuePos != null ? "#$queuePos in Queue" : "Walk-In Ready",
        heroBadge: s?.urgentCareWaitRange ?? "Fast Check-In",
        description:
            "Check into the urgent care queue before arrival, monitor wait times, and share real-time updates to triage.",
        statusText: s?.urgentCareStatus ?? "Open Now",
        stat1Label: "QUEUE STATUS",
        stat1Value: queuePos != null ? "#$queuePos in Line" : "Not Checked In",
        stat2Label: "EST. WAIT",
        stat2Value: s?.urgentCareWaitRange ?? "Fast Check-In",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
        accentColor: AppColors.coral,
        softBackground: AppColors.coralSoft,
        badgeTextColor: AppColors.coralDark,
      ),

      // 11. AI Health Assistant
      const _AppModuleItem(
        kind: DashboardModuleKind.clinicChat,
        title: "AI Health Assistant",
        heroMetric: "Care Assistant",
        heroBadge: "24/7 Ready",
        description:
            "Ask questions connected to your synced wearable vitals, lab PDF interpreter, nutrition monitor, and voice notes.",
        statusText: "Online",
        stat1Label: "VITALS CONTEXT",
        stat1Value: "Live Sync",
        stat2Label: "TRIAGE",
        stat2Value: "CTAS Guided",
        route: "/assistant",
        actionLabel: "Start Clinical Chat",
        accentColor: AppColors.primary,
        softBackground: AppColors.primarySoft,
        badgeTextColor: AppColors.primaryDark,
      ),

      // 12. Health App Hub
      _AppModuleItem(
        kind: DashboardModuleKind.devices,
        title: "Health App Hub",
        heroMetric: synced ? "Connected" : "Connect App",
        heroBadge: "Android • Wearables",
        description:
            "Manage Health Connect, Samsung Health, Google Fit, and wearable telemetry origins or import records cleanly.",
        statusText: synced ? "Active" : "Standby",
        stat1Label: "COMPATIBILITY",
        stat1Value: "Multi-App Sync",
        stat2Label: "TELEMETRY SYNC",
        stat2Value: synced ? "Up to Date" : "Tap to Connect",
        route: "/devices",
        actionLabel: "Connect Health Apps",
        accentColor: AppColors.primary,
        softBackground: AppColors.primarySoft,
        badgeTextColor: AppColors.primaryDark,
      ),
    ];
  }
}

class _AppModuleItem {
  final DashboardModuleKind kind;
  final String title;
  final String heroMetric;
  final String heroBadge;
  final String? overlayMetric;
  final String description;
  final String statusText;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String route;
  final String actionLabel;
  final Color accentColor;
  final Color softBackground;
  final Color badgeTextColor;

  const _AppModuleItem({
    required this.kind,
    required this.title,
    required this.heroMetric,
    required this.heroBadge,
    this.overlayMetric,
    required this.description,
    required this.statusText,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.route,
    required this.actionLabel,
    required this.accentColor,
    required this.softBackground,
    required this.badgeTextColor,
  });
}
