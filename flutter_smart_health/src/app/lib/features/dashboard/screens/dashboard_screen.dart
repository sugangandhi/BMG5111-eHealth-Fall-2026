import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../widgets/app_switcher_carousel.dart';
import '../widgets/now_brief_view.dart';
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

enum DashboardViewMode {
  nowBrief,
  appSwitcher,
  grid,
}

class _PatientDashboardState extends State<PatientDashboard> {
  DashboardViewMode _viewMode = DashboardViewMode.nowBrief;

  void _open(String routeName) => Navigator.pushNamed(context, routeName);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F19),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "INTELLIGENT DIGITAL SOLUTION",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF10B981),
                letterSpacing: 1.1,
              ),
            ),
            Text(
              "eHospital",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: IconButton(
              icon: Icon(
                _viewMode == DashboardViewMode.nowBrief
                    ? Icons.view_carousel_rounded
                    : _viewMode == DashboardViewMode.appSwitcher
                        ? Icons.grid_view_rounded
                        : Icons.auto_awesome_mosaic_rounded,
                size: 18,
              ),
              color: Colors.white,
              tooltip: _viewMode == DashboardViewMode.nowBrief
                  ? "Switch to Apple Watch Switcher"
                  : _viewMode == DashboardViewMode.appSwitcher
                      ? "Switch to Grid View"
                      : "Switch to Now Brief",
              onPressed: () {
                setState(() {
                  if (_viewMode == DashboardViewMode.nowBrief) {
                    _viewMode = DashboardViewMode.appSwitcher;
                  } else if (_viewMode == DashboardViewMode.appSwitcher) {
                    _viewMode = DashboardViewMode.grid;
                  } else {
                    _viewMode = DashboardViewMode.nowBrief;
                  }
                });
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3F1116),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.emergency_rounded, size: 18),
              color: const Color(0xFFEF4444),
              tooltip: l10n.emergencySosTitle,
              onPressed: () => _open('/emergency'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 4, right: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.person_rounded, size: 18),
              color: Colors.white,
              tooltip: l10n.profileTitle,
              onPressed: () => _open('/profile'),
            ),
          ),
        ],
      ),
      body: _viewMode == DashboardViewMode.nowBrief
          ? NowBriefView(onOpenApp: _open)
          : _viewMode == DashboardViewMode.appSwitcher
              ? AppSwitcherCarousel(onSelectApp: _open)
              : SingleChildScrollView(
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
    );
  }
}
