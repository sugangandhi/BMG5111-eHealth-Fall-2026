import 'dart:ui';
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
      viewportFraction: 0.84,
      initialPage: 0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = _getAppsList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header with indicator and arrow buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    "Browse Sub-Apps",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Left Arrow
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 24,
                    color: _currentPage > 0
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1),
                    splashRadius: 18,
                    onPressed: _currentPage > 0
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                  ),
                  Text(
                    "${_currentPage + 1} / ${apps.length}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  // Right Arrow
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    iconSize: 24,
                    color: _currentPage < apps.length - 1
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFCBD5E1),
                    splashRadius: 18,
                    onPressed: _currentPage < apps.length - 1
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Carousel with mouse drag enabled
        SizedBox(
          height: 330,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
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
                    final scale = (1.0 - (diff * 0.08)).clamp(0.92, 1.0);
                    final opacity = (1.0 - (diff * 0.25)).clamp(0.80, 1.0);

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
        ),
        const SizedBox(height: 18),

        // Apple Watch Style Row Widget (Horizontal Dock)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Quick Dock • Tap to Select",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(apps.length, (idx) {
                    final app = apps[idx];
                    final isSelected = idx == _currentPage;

                    return GestureDetector(
                      onTap: () {
                        _goToPage(idx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.25)
                                  : const Color(0x06000000),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : app.iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                app.icon,
                                size: 16,
                                color: isSelected ? Colors.white : app.iconColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              app.shortLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppCard(_AppModuleItem app) {
    return GestureDetector(
      onTap: () => widget.onSelectApp(app.route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.all(20),
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
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: App Icon + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: app.iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    app.icon,
                    color: app.iconColor,
                    size: 26,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: app.statusBg,
                    borderRadius: BorderRadius.circular(20),
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
                          fontWeight: FontWeight.w700,
                          color: app.statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // App Identity
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  app.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  app.description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),

            // Key Highlights Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(app.highlightIcon, size: 15, color: app.iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.highlightText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () => widget.onSelectApp(app.route),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      app.actionLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 15),
                  ],
                ),
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
      const _AppModuleItem(
        title: "Apple Health Vitals",
        category: "Wearable Telemetry",
        shortLabel: "Vitals",
        description:
            "Continuous heart rate, blood pressure, steps, and sleep synchronized directly with AWS EHR.",
        icon: Icons.favorite_rounded,
        iconBg: Color(0xFFFEE2E2),
        iconColor: Color(0xFFDC2626),
        statusText: "AWS Synced",
        statusBg: Color(0xFFDCFCE7),
        statusColor: Color(0xFF16A34A),
        highlightIcon: Icons.cloud_done_rounded,
        highlightText: "HR: 78 bpm • BP: 120/80 • 55 AWS Records",
        route: "/vitals",
        actionLabel: "Open Vitals Dashboard",
      ),

      // 2. WhatsApp Clinical AI (Intelligent Digital Solution)
      const _AppModuleItem(
        title: "WhatsApp Clinical AI",
        category: "Intelligent Digital Solution",
        shortLabel: "Clinic AI",
        description:
            "Direct conversational triage, Whisper-1 voice dictation, and Canadian CTAS clinical assessment.",
        icon: Icons.chat_bubble_rounded,
        iconBg: Color(0xFFDCFCE7),
        iconColor: Color(0xFF16A34A),
        statusText: "Triage Active",
        statusBg: Color(0xFFDCFCE7),
        statusColor: Color(0xFF16A34A),
        highlightIcon: Icons.mic_rounded,
        highlightText: "Whisper Voice Scribe • CTAS SOAP Notes",
        route: "/assistant",
        actionLabel: "Launch Clinical Chat",
      ),

      // 3. Urgent Care Queue
      const _AppModuleItem(
        title: "Urgent Care & ER",
        category: "Priority Walk-In Queue",
        shortLabel: "Urgent Care",
        description:
            "Live clinic queue tracker with remote check-in and automated emergency physician alerts.",
        icon: Icons.local_hospital_rounded,
        iconBg: Color(0xFFE0F2FE),
        iconColor: Color(0xFF0284C7),
        statusText: "Open Now",
        statusBg: Color(0xFFE0F2FE),
        statusColor: Color(0xFF0284C7),
        highlightIcon: Icons.access_time_filled_rounded,
        highlightText: "Queue: Position #4 • Est. Wait 12 min",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
      ),

      // 4. Medications & Prescriptions
      const _AppModuleItem(
        title: "Medications & Rx",
        category: "Daily Adherence",
        shortLabel: "Medications",
        description:
            "Prescription tracker with dose reminders and automated electronic pharmacy renewals.",
        icon: Icons.medication_rounded,
        iconBg: Color(0xFFF3E8FF),
        iconColor: Color(0xFF9333EA),
        statusText: "2 Active",
        statusBg: Color(0xFFF3E8FF),
        statusColor: Color(0xFF9333EA),
        highlightIcon: Icons.check_circle_rounded,
        highlightText: "Metoprolol 50mg • Amlodipine 5mg",
        route: "/medications",
        actionLabel: "Manage Prescriptions",
      ),

      // 5. Health Trends & Analytics
      const _AppModuleItem(
        title: "Health Trends",
        category: "Longitudinal Analytics",
        shortLabel: "Trends",
        description:
            "Multiday telemetry graphs cross-referenced with Hypertension Canada Clinical Practice Guidelines.",
        icon: Icons.insights_rounded,
        iconBg: Color(0xFFFEF3C7),
        iconColor: Color(0xFFD97706),
        statusText: "Optimal",
        statusBg: Color(0xFFDCFCE7),
        statusColor: Color(0xFF16A34A),
        highlightIcon: Icons.show_chart_rounded,
        highlightText: "Resting HR baseline: 72 bpm (Normal Sinus)",
        route: "/trends",
        actionLabel: "Analyze Health Trends",
      ),

      // 6. Symptom Logger
      const _AppModuleItem(
        title: "Symptom Logger",
        category: "Clinical Assessment",
        shortLabel: "Symptoms",
        description:
            "Rapid SOCRATES symptom recording and triage classification for physician review.",
        icon: Icons.healing_rounded,
        iconBg: Color(0xFFFFEDD5),
        iconColor: Color(0xFFEA580C),
        statusText: "Ready",
        statusBg: Color(0xFFF1F5F9),
        statusColor: Color(0xFF64748B),
        highlightIcon: Icons.assignment_rounded,
        highlightText: "SOCRATES Intake • Severity Scoring",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
      ),
    ];
  }
}

class _AppModuleItem {
  final String title;
  final String category;
  final String shortLabel;
  final String description;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String statusText;
  final Color statusBg;
  final Color statusColor;
  final IconData highlightIcon;
  final String highlightText;
  final String route;
  final String actionLabel;

  const _AppModuleItem({
    required this.title,
    required this.category,
    required this.shortLabel,
    required this.description,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.statusText,
    required this.statusBg,
    required this.statusColor,
    required this.highlightIcon,
    required this.highlightText,
    required this.route,
    required this.actionLabel,
  });
}
