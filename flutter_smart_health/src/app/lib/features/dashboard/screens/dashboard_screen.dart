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
      appBar: AppBar(
        title: Text(l10n.patientDashboardTitle),
        actions: [
          IconButton(
            icon: Icon(
              _showAppSwitcher ? Icons.grid_view_rounded : Icons.view_carousel_rounded,
            ),
            tooltip: _showAppSwitcher ? "Switch to Grid View" : "Switch to App Switcher",
            onPressed: () => setState(() => _showAppSwitcher = !_showAppSwitcher),
          ),
          IconButton(
            icon: const Icon(Icons.emergency_outlined),
            tooltip: l10n.emergencySosTitle,
            onPressed: () => _open('/emergency'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            tooltip: l10n.profileTitle,
            onPressed: () => _open('/profile'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: DashboardStyles.bodyPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardWelcomeHeader(
              title: greeting,
              subtitle: l10n.dashboardPrompt,
            ),
            const SizedBox(height: 20),

            if (_showAppSwitcher) ...[
              AppSwitcherCarousel(onSelectApp: _open),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionTile(
                        icon: Icons.emergency_rounded,
                        title: "Emergency SOS",
                        subtitle: "Direct 911 dispatch",
                        color: const Color(0xFFDC2626),
                        bgColor: const Color(0xFFFEE2E2),
                        onTap: () => _open('/emergency'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionTile(
                        icon: Icons.settings_rounded,
                        title: "Settings",
                        subtitle: "Telemetry & profile",
                        color: const Color(0xFF64748B),
                        bgColor: const Color(0xFFF1F5F9),
                        onTap: () => _open('/settings'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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

  Widget _buildQuickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
