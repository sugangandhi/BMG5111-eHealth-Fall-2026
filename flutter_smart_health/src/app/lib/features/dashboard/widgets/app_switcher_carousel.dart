import 'dart:ui';
import 'package:flutter/material.dart';

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
    // 0.78 viewportFraction guarantees adjacent cards visibly peek in on left & right
    _pageController = PageController(
      viewportFraction: 0.78,
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
        duration: const Duration(milliseconds: 320),
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
        // Native Apple Watch / iOS Multitasking Card Deck
        SizedBox(
          height: 495,
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
                if (_pageController.hasClients && _pageController.page != null) {
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
                    // Apple Watch Multitasking depth and scale effect
                    final scale = (1.0 - (diff * 0.08)).clamp(0.90, 1.0);
                    final opacity = (1.0 - (diff * 0.22)).clamp(0.78, 1.0);

                    return Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: _buildAppleCard(app),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Apple Animated Page Indicator Dots (Tap to jump directly to any card)
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(apps.length, (idx) {
                final isSelected = idx == _currentPage;
                return GestureDetector(
                  onTap: () => _goToPage(idx),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: isSelected ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF007AFF)
                            : const Color(0xFFC7C7CC),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppleCard(_AppModuleItem app) {
    return GestureDetector(
      onTap: () => widget.onSelectApp(app.route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFE5E5EA),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0E000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Apple Watch App Header: Squircle Badge + Name + Live Status Pill
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: app.iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    app.icon,
                    color: app.iconColor,
                    size: 24,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: app.statusBg,
                    borderRadius: BorderRadius.circular(12),
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

            // "What this specific app will do" section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(app.highlightIcon, size: 15, color: app.iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          app.highlightText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1C1C1E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Hospital-grade dynamic visual element
                  if (app.type == _AppType.vitals) ...[
                    const _EcgSparkline(color: Color(0xFFFF2D55)),
                    const SizedBox(height: 4),
                  ] else if (app.type == _AppType.urgentCare) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 0.75,
                        minHeight: 4,
                        backgroundColor: Color(0xFFE5E5EA),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ] else if (app.type == _AppType.medications) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 0.50,
                        minHeight: 4,
                        backgroundColor: Color(0xFFE5E5EA),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFAF52DE)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ] else if (app.type == _AppType.goals) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 0.84,
                        minHeight: 4,
                        backgroundColor: Color(0xFFE5E5EA),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Clear, comprehensive description of what the specific app does
                  Text(
                    app.description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF3A3A3C),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Clinical metrics / Key features row
            Row(
              children: [
                _buildAppleMiniStat(app.stat1Label, app.stat1Value),
                const SizedBox(width: 8),
                _buildAppleMiniStat(app.stat2Label, app.stat2Value),
              ],
            ),

            // Apple Action Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                onPressed: () => widget.onSelectApp(app.route),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        app.actionLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildAppleMiniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1C1C1E),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // All 11 apps matching the Grid View 1-to-1
  List<_AppModuleItem> _getAppsList() {
    return [
      // 1. Wearable Vitals (Health Monitoring)
      const _AppModuleItem(
        type: _AppType.vitals,
        title: "Wearable Vitals",
        category: "HEALTH MONITORING",
        shortLabel: "Vitals",
        description:
            "Continuous live telemetry streaming heart rate, blood pressure, and SpO2 from your Apple Watch directly into the hospital EHR with automated arrhythmia alerts.",
        icon: Icons.watch_outlined,
        iconBg: Color(0xFFFFE5E5),
        iconColor: Color(0xFFFF2D55),
        statusText: "Connected",
        statusBg: Color(0xFFE8F5E9),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.favorite_rounded,
        highlightText: "Continuous Apple Watch EHR Telemetry",
        stat1Label: "HEART RATE",
        stat1Value: "78 BPM (Sinus)",
        stat2Label: "BLOOD PRESSURE",
        stat2Value: "120/80 mmHg",
        route: "/vitals",
        actionLabel: "Open Wearable Vitals",
      ),

      // 2. Vitals History (Health Monitoring)
      const _AppModuleItem(
        type: _AppType.history,
        title: "Vitals History",
        category: "HEALTH MONITORING",
        shortLabel: "History",
        description:
            "Browse longitudinal time-stamped archives of past physiological monitoring sessions, ECG recordings, and clinician review logs across customizable date ranges.",
        icon: Icons.history_rounded,
        iconBg: Color(0xFFEDE9FE),
        iconColor: Color(0xFF5856D6),
        statusText: "142 Records",
        statusBg: Color(0xFFEDE9FE),
        statusColor: Color(0xFF5856D6),
        highlightIcon: Icons.calendar_month_rounded,
        highlightText: "Longitudinal Physiological Logs",
        stat1Label: "TOTAL SESSIONS",
        stat1Value: "142 Records",
        stat2Label: "DATE RANGE",
        stat2Value: "Past 30 Days",
        route: "/history",
        actionLabel: "View Vitals History",
      ),

      // 3. Health Insights (Health Monitoring)
      const _AppModuleItem(
        type: _AppType.insights,
        title: "Health Insights",
        category: "HEALTH MONITORING",
        shortLabel: "Insights",
        description:
            "Evaluates merged wearable telemetry and hospital records with clinical reasoning algorithms to highlight early cardiovascular risks and vital anomalies.",
        icon: Icons.insights_rounded,
        iconBg: Color(0xFFFFF4E5),
        iconColor: Color(0xFFFF9500),
        statusText: "Optimal",
        statusBg: Color(0xFFE8F5E9),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.auto_graph_rounded,
        highlightText: "Clinical Risk Stratification",
        stat1Label: "RISK PROFILE",
        stat1Value: "Low / Normal",
        stat2Label: "CRITICAL ALERTS",
        stat2Value: "0 Flags",
        route: "/insights",
        actionLabel: "Explore Health Insights",
      ),

      // 4. Trend Analysis (Health Monitoring)
      const _AppModuleItem(
        type: _AppType.trends,
        title: "Trend Analysis",
        category: "HEALTH MONITORING",
        shortLabel: "Trends",
        description:
            "Charts multi-day blood pressure and resting heart rate trajectories benchmarked against Hypertension Canada and AHA medical guidelines.",
        icon: Icons.trending_up_rounded,
        iconBg: Color(0xFFE5F1FF),
        iconColor: Color(0xFF007AFF),
        statusText: "Stable",
        statusBg: Color(0xFFE5F1FF),
        statusColor: Color(0xFF007AFF),
        highlightIcon: Icons.show_chart_rounded,
        highlightText: "Multi-Day Predictive Trajectories",
        stat1Label: "7-DAY TARGET",
        stat1Value: "Within Range",
        stat2Label: "VARIANCE",
        stat2Value: "±4% Normal",
        route: "/trends",
        actionLabel: "Analyze Health Trends",
      ),

      // 5. Medications & Rx (Health Management)
      const _AppModuleItem(
        type: _AppType.medications,
        title: "Medications & Rx",
        category: "HEALTH MANAGEMENT",
        shortLabel: "Medications",
        description:
            "Maintains your active prescription regimen with automated dose reminders, taken-dose tracking, and electronic refills with your hospital pharmacy.",
        icon: Icons.medication_outlined,
        iconBg: Color(0xFFF3E8FF),
        iconColor: Color(0xFFAF52DE),
        statusText: "2 Active",
        statusBg: Color(0xFFF3E8FF),
        statusColor: Color(0xFFAF52DE),
        highlightIcon: Icons.check_circle_rounded,
        highlightText: "Prescription Adherence Tracker",
        stat1Label: "MORNING DOSE",
        stat1Value: "Taken 8:00 AM",
        stat2Label: "EVENING DOSE",
        stat2Value: "Due 8:00 PM",
        route: "/medications",
        actionLabel: "Manage Medications",
      ),

      // 6. Symptom Logger (Health Management)
      const _AppModuleItem(
        type: _AppType.symptoms,
        title: "Symptom Logger",
        category: "HEALTH MANAGEMENT",
        shortLabel: "Symptoms",
        description:
            "Quickly record pain location, onset, severity, and triggers using the standardized SOCRATES clinical method to send direct updates to your physician.",
        icon: Icons.sick_outlined,
        iconBg: Color(0xFFFFECE5),
        iconColor: Color(0xFFFF5E3A),
        statusText: "Ready",
        statusBg: Color(0xFFF2F2F7),
        statusColor: Color(0xFF8E8E93),
        highlightIcon: Icons.healing_rounded,
        highlightText: "SOCRATES Clinical Intake",
        stat1Label: "LAST LOG",
        stat1Value: "Yesterday",
        stat2Label: "SEVERITY",
        stat2Value: "Mild (1/10)",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
      ),

      // 7. Health Goals (Health Management)
      const _AppModuleItem(
        type: _AppType.goals,
        title: "Health Goals",
        category: "HEALTH MANAGEMENT",
        shortLabel: "Goals",
        description:
            "Track daily step counts, active calorie burn, and restorative sleep milestones to keep your lifestyle goals aligned with your medical treatment plan.",
        icon: Icons.flag_outlined,
        iconBg: Color(0xFFE8F8EE),
        iconColor: Color(0xFF34C759),
        statusText: "84% Done",
        statusBg: Color(0xFFE8F8EE),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.emoji_events_rounded,
        highlightText: "Daily Apple Activity Targets",
        stat1Label: "STEP TARGET",
        stat1Value: "8,420 / 10,000",
        stat2Label: "ACTIVE BURN",
        stat2Value: "480 kcal",
        route: "/goals",
        actionLabel: "Track Health Goals",
      ),

      // 8. BMI Calculator (Health Management)
      const _AppModuleItem(
        type: _AppType.bmi,
        title: "BMI Calculator",
        category: "HEALTH MANAGEMENT",
        shortLabel: "BMI",
        description:
            "Calculates body mass index from height and weight, categorizing metabolic tiers and delivering tailored dietary recommendations for cardiovascular health.",
        icon: Icons.monitor_weight_outlined,
        iconBg: Color(0xFFE0F7FA),
        iconColor: Color(0xFF009688),
        statusText: "Healthy",
        statusBg: Color(0xFFE8F5E9),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.calculate_rounded,
        highlightText: "Body Composition & Health Index",
        stat1Label: "CURRENT BMI",
        stat1Value: "22.4 (Normal)",
        stat2Label: "METABOLIC TIER",
        stat2Value: "Optimal Range",
        route: "/bmi",
        actionLabel: "Calculate BMI",
      ),

      // 9. Urgent Care Clinic (Clinical & Urgent)
      const _AppModuleItem(
        type: _AppType.urgentCare,
        title: "Urgent Care Clinic",
        category: "CLINICAL & URGENT",
        shortLabel: "Urgent Care",
        description:
            "Check into the hospital urgent care queue before arrival, monitor live wait times, and send real-time condition updates directly to the triage nurse.",
        icon: Icons.local_hospital_outlined,
        iconBg: Color(0xFFE5F1FF),
        iconColor: Color(0xFF007AFF),
        statusText: "Open Now",
        statusBg: Color(0xFFE5F1FF),
        statusColor: Color(0xFF007AFF),
        highlightIcon: Icons.access_time_filled_rounded,
        highlightText: "Live Queue & Virtual Check-In",
        stat1Label: "QUEUE POSITION",
        stat1Value: "#4 in Line",
        stat2Label: "EST. WAIT",
        stat2Value: "12 Minutes",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
      ),

      // 10. AI Health Assistant (Clinical & Urgent)
      const _AppModuleItem(
        type: _AppType.clinicChat,
        title: "AI Health Assistant",
        category: "CLINICAL & URGENT",
        shortLabel: "Clinic AI",
        description:
            "Consult with Intelligent Digital Solution care team via WhatsApp-style messaging and Whisper-1 voice dictation, backed by Canadian CTAS triage protocols.",
        icon: Icons.smart_toy_outlined,
        iconBg: Color(0xFFE8F8EE),
        iconColor: Color(0xFF34C759),
        statusText: "Online",
        statusBg: Color(0xFFE8F8EE),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.mic_rounded,
        highlightText: "Intelligent Digital Solution Care Team",
        stat1Label: "CARE TEAM",
        stat1Value: "IDS Clinic Online",
        stat2Label: "TRIAGE ENGINE",
        stat2Value: "CTAS Level 1-5",
        route: "/assistant",
        actionLabel: "Start Clinical Chat",
      ),

      // 11. Settings & Telemetry (System & Telemetry)
      const _AppModuleItem(
        type: _AppType.settings,
        title: "Settings & Telemetry",
        category: "SYSTEM & TELEMETRY",
        shortLabel: "Settings",
        description:
            "Configure Apple Watch HealthKit background syncing, verify AWS App Runner connectivity, manage AI provider keys, and update profile credentials.",
        icon: Icons.settings_outlined,
        iconBg: Color(0xFFF2F2F7),
        iconColor: Color(0xFF8E8E93),
        statusText: "Connected",
        statusBg: Color(0xFFF2F2F7),
        statusColor: Color(0xFF8E8E93),
        highlightIcon: Icons.cloud_sync_rounded,
        highlightText: "Device Connectivity & Privacy",
        stat1Label: "EHR ENDPOINT",
        stat1Value: "AWS App Runner",
        stat2Label: "SYSTEM HEALTH",
        stat2Value: "All Systems 100%",
        route: "/settings",
        actionLabel: "Open App Settings",
      ),
    ];
  }
}

enum _AppType {
  vitals,
  history,
  insights,
  trends,
  medications,
  symptoms,
  goals,
  bmi,
  urgentCare,
  clinicChat,
  settings,
}

class _AppModuleItem {
  final _AppType type;
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
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String route;
  final String actionLabel;

  const _AppModuleItem({
    required this.type,
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
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.route,
    required this.actionLabel,
  });
}

// Physiological Sinus Rhythm ECG Sparkline
class _EcgSparkline extends StatelessWidget {
  final Color color;

  const _EcgSparkline({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: CustomPaint(
        painter: _EcgPainter(color: color),
      ),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final Color color;

  const _EcgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;
    final mid = h * 0.52;

    path.moveTo(0, mid);
    path.lineTo(w * 0.18, mid);
    // P wave
    path.quadraticBezierTo(w * 0.23, mid - (h * 0.28), w * 0.28, mid);
    path.lineTo(w * 0.35, mid);
    // Q dip
    path.lineTo(w * 0.38, mid + (h * 0.18));
    // R spike
    path.lineTo(w * 0.43, mid - (h * 0.48));
    // S dip
    path.lineTo(w * 0.48, mid + (h * 0.28));
    path.lineTo(w * 0.51, mid);
    // ST segment
    path.lineTo(w * 0.60, mid);
    // T wave
    path.quadraticBezierTo(w * 0.68, mid - (h * 0.32), w * 0.76, mid);
    path.lineTo(w, mid);

    canvas.drawPath(path, paint);

    // Live telemetry leading pulse dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w, mid), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
