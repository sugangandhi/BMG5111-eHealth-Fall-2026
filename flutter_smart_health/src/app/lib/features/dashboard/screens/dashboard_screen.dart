import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/l10n.dart';
import '../presentation/dashboard_styles.dart';
import '../widgets/app_switcher_carousel.dart';
import '../widgets/dashboard_featured_card.dart';
import '../widgets/dashboard_grid_card.dart';
import '../widgets/dashboard_grid_row.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/dashboard_settings_link.dart';
import '../widgets/dashboard_welcome_header.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  String? _username;
  bool _showAppSwitcher = true;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('patient_username');
    if (mounted) setState(() => _username = name);
  }

  void _open(String routeName) => Navigator.pushNamed(context, routeName);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final username = _username;
    final greeting = username != null && username.isNotEmpty
        ? l10n.dashboardHelloUser(username)
        : l10n.dashboardWelcome;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "eHospital",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFE5E5EA),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _showAppSwitcher
                    ? Icons.grid_view_rounded
                    : Icons.view_carousel_rounded,
                size: 18,
              ),
              color: const Color(0xFF1C1C1E),
              tooltip: _showAppSwitcher
                  ? "Switch to Grid View"
                  : "Switch to App Switcher",
              onPressed: () =>
                  setState(() => _showAppSwitcher = !_showAppSwitcher),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.emergency_rounded, size: 18),
              color: const Color(0xFFDC2626),
              tooltip: l10n.emergencySosTitle,
              onPressed: () => _open('/emergency'),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 4, right: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFE5E5EA),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.person_rounded, size: 18),
              color: const Color(0xFF1C1C1E),
              tooltip: l10n.profileTitle,
              onPressed: () => _open('/profile'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "INTELLIGENT DIGITAL SOLUTION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF007AFF),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            if (_showAppSwitcher) ...[
              AppSwitcherCarousel(onSelectApp: _open),
              const SizedBox(height: 24),
            ] else ...[
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
            ],
          ],
        ),
      ),
    );
  }
}
