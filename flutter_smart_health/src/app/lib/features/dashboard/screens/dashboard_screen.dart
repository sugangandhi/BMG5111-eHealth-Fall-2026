import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_update_service.dart';
import '../data/dashboard_summary_service.dart';
import '../presentation/dashboard_styles.dart';
import '../widgets/app_switcher_carousel.dart';
import '../widgets/dashboard_featured_card.dart';
import '../widgets/dashboard_grid_card.dart';
import '../widgets/dashboard_grid_row.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/dashboard_settings_link.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with SingleTickerProviderStateMixin {
  bool _showAppSwitcher = true;
  Color _ambientAccent = const Color(0xFF00E5FF);
  SkyMood _skyMood = SkyMood.daylight;
  DashboardLiveSummary _summary = const DashboardLiveSummary();
  bool _syncingSummary = false;
  final DashboardSummaryService _summaryService = DashboardSummaryService();
  final AppUpdateService _updateService = AppUpdateService();
  AppUpdateCheckResult? _availableUpdate;
  late final AnimationController _heartTicker;

  @override
  void initState() {
    super.initState();
    _heartTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _loadSummary();
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    if (!_updateService.isAndroidNative) return;
    final check = await _updateService.checkForUpdate();
    if (!mounted || !check.isUpdateAvailable) return;
    setState(() => _availableUpdate = check);
  }

  @override
  void dispose() {
    _heartTicker.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    if (_syncingSummary) return;
    setState(() => _syncingSummary = true);
    final loaded = await _summaryService.load();
    if (!mounted) return;
    setState(() {
      _summary = loaded;
      _syncingSummary = false;
    });
  }

  Future<void> _open(String routeName) async {
    await Navigator.pushNamed(context, routeName);
    if (mounted) {
      await _loadSummary();
    }
  }

  void _cycleSkyMood() {
    setState(() => _skyMood = _skyMood.next());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Stack(
      children: [
        // Photorealistic Living Atmospheric Sky (Sunburst, Crepuscular Light Beams, Multi-Octave Parallax Clouds, Air Motes)
        AtmosphericSkyBackground(
          mood: _skyMood,
          ambientAccent: _ambientAccent,
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "INTELLIGENT DIGITAL SOLUTION",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6EE7B7), // Bright mint sky accent
                    letterSpacing: 1.1,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "eHospital",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Live physiological telemetry badge (tap to refresh backend summary)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _loadSummary();
                      },
                      child: AnimatedBuilder(
                        animation: _heartTicker,
                        builder: (context, _) {
                          final liveHr = _summary.heartRateBpm;
                          final bpm = liveHr ??
                              (74 +
                                  ((math.sin(_heartTicker.value * math.pi * 8) +
                                              1.0) *
                                          1.8)
                                      .round());
                          final pulseScale = 1.0 +
                              ((math.sin(_heartTicker.value * math.pi * 16) +
                                      1.0) *
                                  0.10);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.40),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_syncingSummary)
                                  const SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                      color: Color(0xFF10B981),
                                    ),
                                  )
                                else
                                  Transform.scale(
                                    scale: pulseScale,
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      size: 11,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  "$bpm BPM",
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (_availableUpdate?.isUpdateAvailable == true)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6EE7B7).withValues(alpha: 0.65),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.system_update_rounded, size: 18),
                    color: Colors.white,
                    tooltip:
                        'Update to v${_availableUpdate!.remoteVersionName}',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      showAppUpdateDialog(
                        context,
                        updateService: _updateService,
                        checkResult: _availableUpdate!,
                      );
                    },
                  ),
                ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14), // Apple frosted glass button
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    _showAppSwitcher
                        ? Icons.grid_view_rounded
                        : Icons.view_carousel_rounded,
                    size: 18,
                  ),
                  color: Colors.white,
                  tooltip: _showAppSwitcher
                      ? "Switch to Grid View"
                      : "Switch to App Switcher",
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _showAppSwitcher = !_showAppSwitcher);
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.50),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.emergency_rounded, size: 18),
                  color: const Color(0xFFFF6B6B),
                  tooltip: l10n.emergencySosTitle,
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    _open('/emergency');
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 4, right: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14), // Apple frosted glass button
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.person_rounded, size: 18),
                  color: Colors.white,
                  tooltip: l10n.profileTitle,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _open('/profile');
                  },
                ),
              ),
            ],
          ),
          body: _showAppSwitcher
              ? AppSwitcherCarousel(
                  summary: _summary,
                  skyMood: _skyMood,
                  onCycleSkyMood: _cycleSkyMood,
                  onSelectApp: _open,
                  onActiveAccentChanged: (accent) {
                    if (_ambientAccent != accent) {
                      setState(() => _ambientAccent = accent);
                    }
                  },
                )
              : SingleChildScrollView(
                  padding: DashboardStyles.bodyPadding,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const SizedBox(height: 12),
              DashboardSectionHeader(title: l10n.healthMonitoringSection),
              DashboardGridRow(
                left: DashboardGridCard(
                  icon: Icons.watch_outlined,
                  title: l10n.wearableVitalsTitle,
                  subtitle: l10n.wearableVitalsSubtitle,
                  onTap: () => _open('/vitals'),
                ),
                right: DashboardGridCard(
                  icon: Icons.history,
                  title: l10n.vitalsHistoryTitle,
                  subtitle: l10n.vitalsHistorySubtitle,
                  onTap: () => _open('/history'),
                ),
              ),
              const SizedBox(height: 14),
              DashboardGridRow(
                left: DashboardGridCard(
                  icon: Icons.insights,
                  title: l10n.healthInsightsTitle,
                  subtitle: l10n.healthInsightsSubtitle,
                  onTap: () => _open('/insights'),
                ),
                right: DashboardGridCard(
                  icon: Icons.trending_up,
                  title: l10n.trendAnalysisTitle,
                  subtitle: l10n.trendAnalysisSubtitle,
                  onTap: () => _open('/trends'),
                ),
              ),
              const SizedBox(height: 28),
              DashboardSectionHeader(title: l10n.healthManagementSection),
              DashboardGridRow(
                left: DashboardGridCard(
                  icon: Icons.medication_outlined,
                  title: l10n.medicationsTitle,
                  subtitle: l10n.medicationsSubtitle,
                  onTap: () => _open('/medications'),
                ),
                right: DashboardGridCard(
                  icon: Icons.sick_outlined,
                  title: l10n.symptomLogTitle,
                  subtitle: l10n.symptomLogSubtitle,
                  onTap: () => _open('/symptoms'),
                ),
              ),
              const SizedBox(height: 14),
              DashboardGridRow(
                left: DashboardGridCard(
                  icon: Icons.flag_outlined,
                  title: l10n.healthGoalsTitle,
                  subtitle: l10n.healthGoalsSubtitle,
                  onTap: () => _open('/goals'),
                ),
                right: DashboardGridCard(
                  icon: Icons.monitor_weight_outlined,
                  title: l10n.bmiCalculatorTitle,
                  subtitle: l10n.bmiCalculatorSubtitle,
                  onTap: () => _open('/bmi'),
                ),
              ),
              const SizedBox(height: 28),
              DashboardFeaturedCard(
                icon: Icons.local_hospital_outlined,
                title: 'Urgent Care',
                subtitle:
                    'Check in, view queue status, and send condition updates.',
                onTap: () => _open('/urgent-care'),
              ),
              const SizedBox(height: 20),
              DashboardFeaturedCard(
                icon: Icons.smart_toy_outlined,
                title: l10n.aiHealthAssistantTitle,
                subtitle: l10n.aiHealthAssistantSubtitle,
                onTap: () => _open('/assistant'),
              ),
              const SizedBox(height: 20),
              DashboardSettingsLink(
                title: l10n.settingsTitle,
                onTap: () => _open('/settings'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ],
  );
}
}
