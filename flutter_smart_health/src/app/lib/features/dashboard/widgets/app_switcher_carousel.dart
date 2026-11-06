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
    // 0.78 viewportFraction guarantees adjacent cards visibly peek in from left & right
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
        // Native Apple Multitasking Card Deck (Starts immediately, zero clutter)
        SizedBox(
          height: 490,
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
                    // Apple Multitasking depth and scale effect
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
        const SizedBox(height: 18),

        // Apple Animated Page Indicator Dots (Tap to jump)
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(apps.length, (idx) {
              final isSelected = idx == _currentPage;
              return GestureDetector(
                onTap: () => _goToPage(idx),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 24 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : const Color(0xFFC7C7CC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
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
            // Apple App Header: Squircle Icon + App Title + Live Status Pill
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
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93),
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

            // Apple Card Content Preview (with live visualizers)
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

                  // Hospital-grade dynamic visualizer
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
                  ],

                  Text(
                    app.description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF3A3A3C),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Metrics / Stats Row inside Card
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

  List<_AppModuleItem> _getAppsList() {
    return [
      // 1. Apple Health Vitals
      const _AppModuleItem(
        type: _AppType.vitals,
        title: "Apple Health Vitals",
        category: "Apple Watch Telemetry",
        shortLabel: "Vitals",
        description:
            "Live streaming telemetry from Apple Watch synced directly to Central AWS App Runner EHR.",
        icon: Icons.favorite_rounded,
        iconBg: Color(0xFFFFE5E5),
        iconColor: Color(0xFFFF2D55),
        statusText: "AWS Live",
        statusBg: Color(0xFFE8F5E9),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.cloud_done_rounded,
        highlightText: "55 Live AWS Cloud Telemetry Records",
        stat1Label: "HEART RATE",
        stat1Value: "78 BPM (Sinus)",
        stat2Label: "BLOOD PRESSURE",
        stat2Value: "120/80 mmHg",
        route: "/vitals",
        actionLabel: "Open Health Telemetry",
      ),

      // 2. WhatsApp Clinical AI (Intelligent Digital Solution)
      const _AppModuleItem(
        type: _AppType.clinicChat,
        title: "Intelligent Digital Solution",
        category: "Clinical WhatsApp & Voice",
        shortLabel: "Clinic AI",
        description:
            "Conversational clinical triage with OpenAI Whisper-1 mic dictation & Canadian CTAS guidance.",
        icon: Icons.chat_bubble_rounded,
        iconBg: Color(0xFFE8F8EE),
        iconColor: Color(0xFF34C759),
        statusText: "Triage Ready",
        statusBg: Color(0xFFE8F8EE),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.mic_rounded,
        highlightText: "Whisper-1 Mic • CTAS Decision Engine",
        stat1Label: "CARE TEAM",
        stat1Value: "IDS Clinic Online",
        stat2Label: "TRIAGE PROTOCOL",
        stat2Value: "CTAS Level 1-5",
        route: "/assistant",
        actionLabel: "Open Clinical Chat",
      ),

      // 3. Urgent Care Clinic
      const _AppModuleItem(
        type: _AppType.urgentCare,
        title: "Urgent Care Clinic",
        category: "Emergency & Walk-In",
        shortLabel: "Urgent Care",
        description:
            "Live clinic queue tracker with remote check-in and automated emergency physician alerts.",
        icon: Icons.local_hospital_rounded,
        iconBg: Color(0xFFE5F1FF),
        iconColor: Color(0xFF007AFF),
        statusText: "Open Now",
        statusBg: Color(0xFFE5F1FF),
        statusColor: Color(0xFF007AFF),
        highlightIcon: Icons.access_time_filled_rounded,
        highlightText: "Queue Position #4 • 12 Min Wait",
        stat1Label: "QUEUE POSITION",
        stat1Value: "#4 in Queue",
        stat2Label: "EST. WAIT",
        stat2Value: "12 Minutes",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
      ),

      // 4. Medications & Prescriptions
      const _AppModuleItem(
        type: _AppType.medications,
        title: "Medications & Rx",
        category: "Prescription Adherence",
        shortLabel: "Medications",
        description:
            "Active medications schedule with automatic dose logging and electronic pharmacy renewals.",
        icon: Icons.medication_rounded,
        iconBg: Color(0xFFF3E8FF),
        iconColor: Color(0xFFAF52DE),
        statusText: "2 Active",
        statusBg: Color(0xFFF3E8FF),
        statusColor: Color(0xFFAF52DE),
        highlightIcon: Icons.check_circle_rounded,
        highlightText: "Metoprolol 50mg • Amlodipine 5mg",
        stat1Label: "MORNING DOSE",
        stat1Value: "Taken 8:00 AM",
        stat2Label: "EVENING DOSE",
        stat2Value: "Due 8:00 PM",
        route: "/medications",
        actionLabel: "Manage Prescriptions",
      ),

      // 5. Health Trends & Analytics
      const _AppModuleItem(
        type: _AppType.trends,
        title: "Health Trends",
        category: "Longitudinal Analytics",
        shortLabel: "Trends",
        description:
            "Multi-day physiological trajectories cross-referenced with Hypertension Canada guidelines.",
        icon: Icons.insights_rounded,
        iconBg: Color(0xFFFFF4E5),
        iconColor: Color(0xFFFF9500),
        statusText: "Optimal",
        statusBg: Color(0xFFE8F5E9),
        statusColor: Color(0xFF34C759),
        highlightIcon: Icons.show_chart_rounded,
        highlightText: "Resting HR Baseline: 72 BPM Normal",
        stat1Label: "7-DAY STABILITY",
        stat1Value: "Optimal Target",
        stat2Label: "RISK PROFILE",
        stat2Value: "Low Variance",
        route: "/trends",
        actionLabel: "Analyze Health Trends",
      ),

      // 6. Symptom Logger
      const _AppModuleItem(
        type: _AppType.symptoms,
        title: "Symptom Logger",
        category: "Clinical Assessment",
        shortLabel: "Symptoms",
        description:
            "Rapid SOCRATES symptom recording and triage classification for physician review.",
        icon: Icons.healing_rounded,
        iconBg: Color(0xFFFFECE5),
        iconColor: Color(0xFFFF5E3A),
        statusText: "Ready",
        statusBg: Color(0xFFF2F2F7),
        statusColor: Color(0xFF8E8E93),
        highlightIcon: Icons.assignment_rounded,
        highlightText: "SOCRATES Intake • Severity Scoring",
        stat1Label: "LAST LOG",
        stat1Value: "Yesterday",
        stat2Label: "SEVERITY",
        stat2Value: "Mild (1/10)",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
      ),
    ];
  }
}

enum _AppType { vitals, clinicChat, urgentCare, medications, trends, symptoms }

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
