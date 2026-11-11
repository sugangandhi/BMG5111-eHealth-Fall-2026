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
    final stepsValue = s?.stepsCount != null ? '${s!.stepsCount}' : '--';
    final hrValue =
        s?.heartRateBpm != null ? '${s!.heartRateBpm} bpm' : '-- bpm';
    final sleepValue = s?.sleepHours != null
        ? '${s!.sleepHours!.toStringAsFixed(1)} hrs'
        : '-- hrs';

    return Row(
      children: [
        Expanded(
          child: _buildQuickPill(
            label: 'Steps',
            value: stepsValue,
            bgColor: AppColors.tealSoft,
            labelColor: AppColors.tealDark,
            onTap: () => _jumpToKind(DashboardModuleKind.goals),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickPill(
            label: 'Heart Rate',
            value: hrValue,
            bgColor: AppColors.coralSoft,
            labelColor: AppColors.coralDark,
            onTap: () => _jumpToKind(DashboardModuleKind.vitals),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickPill(
            label: 'Sleep',
            value: sleepValue,
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
    final bannerHeight = (height * 0.28).clamp(112.0, 166.0);
    final compact = height < 500;

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
                          accentColor: app.accentColor,
                          backgroundColor: app.softBackground,
                          height: bannerHeight,
                        );
                      },
                    ),

                    SizedBox(height: compact ? 10 : 12),

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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppColors.textMuted,
                            ),
                          ),
                          SizedBox(height: compact ? 8 : 10),
                          Text(
                            app.heroMetric,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 25 : 30,
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

                    if (!compact) ...[
                      const SizedBox(height: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _buildModuleDetailWell(app),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else
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

  Widget _buildModuleDetailWell(_AppModuleItem app) {
    final s = widget.summary;
    final synced = s?.isLiveSynced ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: _buildDetailBodyForKind(app, s, synced),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailBodyForKind(
    _AppModuleItem app,
    DashboardLiveSummary? s,
    bool synced,
  ) {
    switch (app.kind) {
      case DashboardModuleKind.vitals:
        final cal = s?.caloriesCount != null ? '${s!.caloriesCount} kcal' : '-- kcal';
        final sleep =
            s?.sleepHours != null ? '${s!.sleepHours!.toStringAsFixed(1)} hrs' : '-- hrs';
        return _buildTwoColumnDetail(
          heading: 'Live Telemetry Summary',
          trailing: synced ? 'Active' : 'Waiting',
          accent: app.accentColor,
          leftLabel: 'CALORIES BURNT',
          leftVal: cal,
          rightLabel: 'SLEEP LOGGED',
          rightVal: sleep,
        );

      case DashboardModuleKind.history:
        const ratios = [0.42, 0.58, 0.72, 0.50, 0.85, 0.68, 0.92, 0.78];
        return _buildLabeledVisualWell(
          title: 'Recent Check-In Activity',
          tag: '${s?.vitalsHistoryCount ?? 0} total',
          accent: app.accentColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(ratios.length, (i) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    height: 28 * ratios[i],
                    decoration: BoxDecoration(
                      color: i >= 6
                          ? app.accentColor
                          : app.accentColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
          ),
        );

      case DashboardModuleKind.insights:
        final ecg = s?.ecgStatus ?? (synced ? 'Sinus Rhythm' : 'Not Synced');
        return _buildLabeledVisualWell(
          title: 'Cardio & Risk Screening',
          tag: ecg,
          accent: app.accentColor,
          child: Row(
            children: [
              _miniChip('Guidelines', 'AHA Ready', app.softBackground, app.badgeTextColor),
              const SizedBox(width: 8),
              _miniChip('Sync Status', synced ? 'Verified' : 'Standby', Colors.white, AppColors.textDark),
            ],
          ),
        );

      case DashboardModuleKind.trends:
        return _buildLabeledVisualWell(
          title: '7-Day Physiological Curve',
          tag: 'Within Range',
          accent: app.accentColor,
          child: Row(
            children: [
              _miniChip('HR Drift', '±4% Stable', app.softBackground, app.badgeTextColor),
              const SizedBox(width: 8),
              _miniChip('BP Benchmark', 'Optimal Tier', Colors.white, AppColors.textDark),
            ],
          ),
        );

      case DashboardModuleKind.sleep:
        return _buildLabeledVisualWell(
          title: 'Sleep Stage Distribution',
          tag: 'Deep • REM • Core',
          accent: app.accentColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      Expanded(flex: 25, child: ColoredBox(color: Color(0xFF5139A8))),
                      Expanded(flex: 22, child: ColoredBox(color: Color(0xFF6E56CF))),
                      Expanded(flex: 45, child: ColoredBox(color: Color(0xFFA78BFA))),
                      Expanded(flex: 8, child: ColoredBox(color: Color(0xFFD97706))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Deep 25%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'REM 22%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'Core 45%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case DashboardModuleKind.medications:
        final total = s?.medicationsTotal ?? 0;
        final taken = s?.medicationsTaken ?? 0;
        final progress = total > 0 ? (taken / total).clamp(0.0, 1.0) : 0.0;
        return _buildProgressWell(
          title: 'Daily Dose Progress',
          tag: total > 0 ? '$taken of $total taken' : 'No Rx Scheduled',
          progress: progress,
          accent: app.accentColor,
        );

      case DashboardModuleKind.symptoms:
        final sev = s?.latestSymptomSeverity ?? 0;
        final hasLogs = (s?.symptomsCount ?? 0) > 0;
        final progress = hasLogs ? (sev / 5.0).clamp(0.1, 1.0) : 0.0;
        return _buildProgressWell(
          title: 'Comfort Severity Scale',
          tag: hasLogs ? '$sev / 5 Severity' : 'All Clear (0/5)',
          progress: progress,
          accent: app.accentColor,
        );

      case DashboardModuleKind.goals:
        final steps = s?.stepsCount ?? 0;
        final progress = (steps / 10000).clamp(0.0, 1.0);
        return _buildProgressWell(
          title: 'Daily 10,000-Step Goal',
          tag: '${(progress * 100).round()}% Complete',
          progress: progress,
          accent: app.accentColor,
        );

      case DashboardModuleKind.bmi:
        final bmi = s?.latestBmi;
        return _buildLabeledVisualWell(
          title: 'Metabolic Range Reference',
          tag: bmi != null ? '${bmi.toStringAsFixed(1)} kg/m²' : '18.5 - 24.9 Ideal',
          accent: app.accentColor,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(flex: 18, child: ColoredBox(color: AppColors.primary)),
                  Expanded(flex: 32, child: ColoredBox(color: AppColors.primaryAccent)),
                  Expanded(flex: 25, child: ColoredBox(color: AppColors.amber)),
                  Expanded(flex: 25, child: ColoredBox(color: AppColors.coral)),
                ],
              ),
            ),
          ),
        );

      case DashboardModuleKind.urgentCare:
        final pos = s?.urgentCareQueuePosition;
        final prog = pos != null ? (1.0 / pos.clamp(1, 10)).clamp(0.2, 0.95) : 0.0;
        return _buildProgressWell(
          title: 'Clinic Check-In Status',
          tag: pos != null ? '#$pos in Line' : 'Ready for Pre-Check-In',
          progress: prog,
          accent: app.accentColor,
        );

      case DashboardModuleKind.clinicChat:
        return _buildLabeledVisualWell(
          title: 'Suggested Prompts',
          tag: 'Voice + Text',
          accent: app.accentColor,
          child: Row(
            children: [
              _miniChip('Prompt 1', 'Analyze vitals', app.softBackground, app.badgeTextColor),
              const SizedBox(width: 8),
              _miniChip('Prompt 2', 'Read lab PDF', Colors.white, AppColors.textDark),
            ],
          ),
        );

      case DashboardModuleKind.devices:
        final activeSrc = s?.wearableSourceLabel ?? 'Auto Detect';
        return _buildLabeledVisualWell(
          title: 'Connected Platform Pipeline',
          tag: synced ? 'Live Origin Lock' : 'Standby',
          accent: app.accentColor,
          child: Row(
            children: [
              _miniChip('Primary', activeSrc, app.softBackground, app.badgeTextColor),
              const SizedBox(width: 8),
              _miniChip('Export', 'CSV • XML', Colors.white, AppColors.textDark),
            ],
          ),
        );
    }
  }

  Widget _buildTwoColumnDetail({
    required String heading,
    required String trailing,
    required Color accent,
    required String leftLabel,
    required String leftVal,
    required String rightLabel,
    required String rightVal,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailHeaderRow(heading, trailing, accent),
        const SizedBox(height: 6),
        Row(
          children: [
            _miniChip(leftLabel, leftVal, Colors.white, AppColors.textDark),
            const SizedBox(width: 8),
            _miniChip(rightLabel, rightVal, Colors.white, AppColors.textDark),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailHeaderRow(String title, String trailing, Color accent) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          trailing,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledVisualWell({
    required String title,
    required String tag,
    required Color accent,
    required Widget child,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDetailHeaderRow(title, tag, accent),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildProgressWell({
    required String title,
    required String tag,
    required double progress,
    required Color accent,
  }) {
    return _buildLabeledVisualWell(
      title: title,
      tag: tag,
      accent: accent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: AlwaysStoppedAnimation<Color>(accent),
        ),
      ),
    );
  }

  Widget _miniChip(String k, String v, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              k,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
            const SizedBox(height: 1),
            Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: fg),
            ),
          ],
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
    final sourceLabel = s?.wearableSourceLabel;
    final hrText = s?.heartRateBpm != null ? '${s!.heartRateBpm} BPM' : '-- BPM';
    final bpText = s?.bloodPressure ?? '--/--';
    final ecgText = s?.ecgStatus ?? (synced ? 'Sinus Rhythm' : 'Not Synced');
    final histCount = s?.vitalsHistoryCount ?? 0;
    final steps = s?.stepsCount;
    final stepsHero = steps != null ? '$steps Steps' : '-- Steps';
    final caloriesText =
        s?.caloriesCount != null ? '${s!.caloriesCount} kcal' : '-- kcal';
    final stepPct =
        steps != null ? ((steps / 10000) * 100).round().clamp(0, 100) : 0;
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
        description: sourceLabel != null
            ? "Continuous live telemetry synced from $sourceLabel, streaming heart rate, steps, and vitals."
            : "Continuous live telemetry streaming heart rate, steps, blood pressure, and SpO2 directly from your wearable.",
        statusText: sourceLabel ?? (synced ? "Live Sync" : "Connect App"),
        stat1Label: "DAILY STEPS",
        stat1Value: stepsHero,
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
            sleepHours != null ? "${sleepHours.toStringAsFixed(1)} hrs" : "-- hrs",
        heroBadge: "Stage Breakdown",
        description:
            "Review nightly Deep, REM, and Core sleep architecture alongside nocturnal SpO2 and resting HR recovery.",
        statusText: sleepHours != null ? (sourceLabel ?? "Synced") : "Not Synced",
        stat1Label: "NIGHTLY SLEEP",
        stat1Value:
            sleepHours != null ? "${sleepHours.toStringAsFixed(1)} Hours" : "Not Recorded",
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
        heroMetric: stepsHero,
        heroBadge: "$stepPct% of Goal",
        description:
            "Track daily step counts, active calorie burn, and activity milestones aligned with your personal care plan.",
        statusText: "$stepPct% Done",
        stat1Label: "STEP TARGET",
        stat1Value: steps != null ? "$steps / 10,000" : "-- / 10,000",
        stat2Label: "CALORIES",
        stat2Value: caloriesText,
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
        heroMetric: sourceLabel ?? (synced ? "Connected" : "Connect App"),
        heroBadge: "Android • Wearables",
        description:
            "Manage Health Connect, Samsung Health, Google Fit, and wearable telemetry origins or import records cleanly.",
        statusText: sourceLabel != null ? "Synced" : (synced ? "Active" : "Standby"),
        stat1Label: "ACTIVE SOURCE",
        stat1Value: sourceLabel ?? "Auto Detect",
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
