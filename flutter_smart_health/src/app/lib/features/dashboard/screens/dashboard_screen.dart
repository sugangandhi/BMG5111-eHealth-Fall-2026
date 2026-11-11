import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_gradients.dart';
import '../data/dashboard_summary_service.dart';
import '../presentation/dashboard_styles.dart';
import '../widgets/app_switcher_carousel.dart';
import '../widgets/dashboard_featured_card.dart';
import '../widgets/dashboard_grid_card.dart';
import '../widgets/dashboard_grid_row.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/dashboard_settings_link.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key, this.summaryService});

  final DashboardSummaryService? summaryService;

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard>
    with WidgetsBindingObserver {
  bool _showAppSwitcher = true;
  DashboardLiveSummary _summary = const DashboardLiveSummary();
  bool _syncingSummary = false;
  late final DashboardSummaryService _summaryService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _summaryService = widget.summaryService ?? DashboardSummaryService();
    _loadSummary();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadSummary();
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        centerTitle: false,
        title: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _loadSummary();
          },
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x280F5C9C),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "eHospital",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_syncingSummary)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: AppColors.primaryAccent,
                            ),
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _summary.isLiveSynced
                                  ? AppColors.primaryAccent
                                  : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _syncingSummary
                                ? "Syncing health data..."
                                : (_summary.isLiveSynced
                                    ? "${_summary.wearableSourceLabel ?? 'Health Data'} Synced"
                                    : "Tap to sync telemetry"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _summary.isLiveSynced
                                  ? AppColors.tealDark
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A16202C),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _showAppSwitcher
                    ? Icons.grid_view_rounded
                    : Icons.view_carousel_rounded,
                size: 19,
              ),
              color: _showAppSwitcher ? AppColors.textDark : AppColors.primary,
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
            margin: const EdgeInsets.only(left: 4, right: 14),
            child: Tooltip(
              message: l10n.profileTitle,
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _open('/profile');
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    padding: const EdgeInsets.all(3.2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                        colors: [
                          Color(0xFF047857),
                          Color(0xFF10B981),
                          Color(0xFF6EE7B7),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x2810B981),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2.2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE6F9F2),
                              Color(0xFFDDF7F2),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _showAppSwitcher
          ? AppSwitcherCarousel(
              summary: _summary,
              onSelectApp: _open,
            )
          : SingleChildScrollView(
              padding: DashboardStyles.bodyPadding,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
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
    );
  }
}
