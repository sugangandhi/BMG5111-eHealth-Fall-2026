import 'package:flutter/material.dart';
import '../../../../ui/app_colors.dart';

class AppSwitcherCarousel extends StatefulWidget {
  final void Function(String route) onSelectApp;

  const AppSwitcherCarousel({
    super.key,
    required this.onSelectApp,
  });

  @override
  State<AppSwitcherCarousel> createState() => _AppSwitcherCarouselState();
}

class _AppSwitcherCarouselState extends State<AppSwitcherCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.86,
      initialPage: 0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _getAppsList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with swipe hint
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Active Apps & Modules",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.swipe_outlined,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${_currentPage + 1} of ${apps.length}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Native iOS Style Carousel
        SizedBox(
          height: 380,
          child: AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              double currentPageValue = _currentPage.toDouble();
              if (_pageController.position.haveDimensions &&
                  _pageController.page != null) {
                currentPageValue = _pageController.page!;
              }

              return PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: apps.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  final app = apps[index];
                  final diff = (currentPageValue - index).abs();
                  final scale = (1.0 - (diff * 0.08)).clamp(0.90, 1.0);
                  final opacity = (1.0 - (diff * 0.25)).clamp(0.75, 1.0);

                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: _buildAppCard(app),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Pagination Dots & Quick Mini-Dock
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(apps.length, (index) {
              final isSelected = index == _currentPage;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildAppCard(_AppModuleItem app) {
    return GestureDetector(
      onTap: () => widget.onSelectApp(app.route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top App Bar inside Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: app.iconBg,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      app.icon,
                      color: app.iconColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: app.statusBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: app.statusColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          app.statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: app.statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Body: Realistic Mini-Screen Content Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: app.previewWidget,
              ),
            ),

            // Bottom Action Bar: Open App Affordance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(21),
                ),
                border: Border(
                  top: BorderSide(
                    color: Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    app.actionLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_AppModuleItem> _getAppsList() {
    return [
      // 1. Apple Health Vitals
      _AppModuleItem(
        title: "Apple Health Vitals",
        category: "Continuous Wearable Telemetry",
        icon: Icons.favorite_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconColor: const Color(0xFFDC2626),
        statusText: "AWS Synced",
        statusBg: const Color(0xFFDCFCE7),
        statusColor: const Color(0xFF16A34A),
        route: "/vitals",
        actionLabel: "Open Vitals Dashboard",
        previewWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Latest Telemetry Snapshot",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatPill("Heart Rate", "78", "bpm", Icons.favorite,
                    const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                _buildStatPill("Blood Press.", "120/80", "mmHg",
                    Icons.speed_rounded, const Color(0xFF0284C7)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatPill("Activity", "8,500", "steps",
                    Icons.directions_walk_rounded, const Color(0xFF16A34A)),
                const SizedBox(width: 8),
                _buildStatPill("Sleep Time", "7.5", "hrs",
                    Icons.bedtime_rounded, const Color(0xFF7C3AED)),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "55 AWS App Runner records live",
                      style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 2. WhatsApp Clinic AI (Intelligent Digital Solution)
      _AppModuleItem(
        title: "Clinical Chat & Triage",
        category: "Intelligent Digital Solution",
        icon: Icons.chat_bubble_rounded,
        iconBg: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        statusText: "Triage Active",
        statusBg: const Color(0xFFDCFCE7),
        statusColor: const Color(0xFF16A34A),
        route: "/assistant",
        actionLabel: "Launch Clinical Chat",
        previewWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded,
                      size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Intelligent Digital Solution Care Team Ready",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Recent Capabilities:",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            _buildFeatureBullet(Icons.mic_rounded, "Whisper-1 Voice Scribe (In-Chatbox Mic)"),
            const SizedBox(height: 4),
            _buildFeatureBullet(Icons.assignment_turned_in_rounded, "Canadian CTAS Decision Engine & SOAP Notes"),
            const SizedBox(height: 4),
            _buildFeatureBullet(Icons.calendar_month_rounded, "1-Tap Priority Appointment Booking"),
            const Spacer(),
            const Text(
              "• Tap to speak or type symptoms directly",
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),

      // 3. Urgent Care Queue
      _AppModuleItem(
        title: "Urgent Care & ER",
        category: "Live Walk-In Queue",
        icon: Icons.local_hospital_rounded,
        iconBg: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0284C7),
        statusText: "Open Now",
        statusBg: const Color(0xFFE0F2FE),
        statusColor: const Color(0xFF0284C7),
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
        previewWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Queue Position",
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "#4",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Est. Wait Time",
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "12 min",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Automated STAT Notification to On-Call Physician",
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Text(
              "• Check in remotely before arriving",
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),

      // 4. Medications & Prescriptions
      _AppModuleItem(
        title: "Medications & Rx",
        category: "Daily Clinical Adherence",
        icon: Icons.medication_rounded,
        iconBg: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF9333EA),
        statusText: "2 Active",
        statusBg: const Color(0xFFF3E8FF),
        statusColor: const Color(0xFF9333EA),
        route: "/medications",
        actionLabel: "Manage Prescriptions",
        previewWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMedicationTile(
              "Metoprolol Tartrate",
              "50 mg • Oral Tablet",
              "Taken • 8:00 AM",
              const Color(0xFF16A34A),
            ),
            const SizedBox(height: 8),
            _buildMedicationTile(
              "Amlodipine Besylate",
              "5 mg • Oral Tablet",
              "Upcoming • 8:00 PM",
              const Color(0xFF9333EA),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.replay_rounded, size: 14, color: Color(0xFF9333EA)),
                  SizedBox(width: 6),
                  Text(
                    "Electronic pharmacy refill available",
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B21A8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 5. Health Trends & Analytics
      _AppModuleItem(
        title: "Health Trends",
        category: "Longitudinal Analytics",
        icon: Icons.insights_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        statusText: "Optimal",
        statusBg: const Color(0xFFDCFCE7),
        statusColor: const Color(0xFF16A34A),
        route: "/trends",
        actionLabel: "Analyze Health Trends",
        previewWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Clinical Vitals Stability",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.show_chart_rounded, size: 18, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Blood pressure variance within target guidelines",
                      style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Resting HR baseline: 72 bpm (Normal Sinus)",
                      style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Text(
              "• Cross-referenced with Hypertension Canada CPGs",
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildStatPill(
      String label, String value, String unit, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  RichText(
                    text: TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      children: [
                        TextSpan(
                          text: " $unit",
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF16A34A)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF334155),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationTile(
      String name, String dosage, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  dosage,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppModuleItem {
  final String title;
  final String category;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String statusText;
  final Color statusBg;
  final Color statusColor;
  final String route;
  final String actionLabel;
  final Widget previewWidget;

  const _AppModuleItem({
    required this.title,
    required this.category,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.statusText,
    required this.statusBg,
    required this.statusColor,
    required this.route,
    required this.actionLabel,
    required this.previewWidget,
  });
}
