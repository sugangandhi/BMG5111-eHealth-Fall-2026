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

  static const _emeraldPrimary = Color(0xFF10B981);
  static const _emeraldSecondary = Color(0xFF059669);
  static const _emeraldGlow = Color(0xFF34D399);

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
        // Obsidian & Emerald Multitasking Card Deck
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
                    // Multitasking depth and scale effect
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

        // Animated Page Indicator Dots (Tap to jump directly to any card)
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
                            ? _emeraldPrimary
                            : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _emeraldPrimary.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
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
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(28),
          // Obsidian black with subtle emerald ambient lighting
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _emeraldPrimary.withValues(alpha: 0.12),
              const Color(0xFF111827),
              const Color(0xFF0F172A),
            ],
            stops: const [0.0, 0.40, 1.0],
          ),
          border: Border.all(
            color: _emeraldPrimary.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _emeraldPrimary.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x60000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top App Bar: Emerald Squircle Badge + White App Name + Status Pill
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_emeraldSecondary, _emeraldPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: _emeraldPrimary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    app.icon,
                    color: Colors.white,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        app.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _emeraldPrimary,
                          letterSpacing: 0.8,
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
                    color: _emeraldPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _emeraldPrimary.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _emeraldPrimary,
                          boxShadow: [
                            BoxShadow(
                              color: _emeraldPrimary.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        app.statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _emeraldPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Hero Glance Box: Hero Metric + Dynamic Visualizer + Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Metric Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        app.heroMetric,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _emeraldGlow,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _emeraldPrimary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _emeraldPrimary.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          app.heroBadge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _emeraldGlow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Live Complication Visualizer in Emerald Green
                  _buildVisualizerForApp(app),
                  const SizedBox(height: 6),

                  // Clear description of what the specific app does
                  Text(
                    app.description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFFCBD5E1),
                    ),
                    maxLines: 2,
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

            // Full-Width Emerald Gradient Action Button
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_emeraldSecondary, _emeraldPrimary],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: _emeraldPrimary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
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
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualizerForApp(_AppModuleItem app) {
    switch (app.type) {
      case _AppType.vitals:
        return const _EcgSparkline(color: _emeraldPrimary);
      case _AppType.urgentCare:
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            value: 0.75,
            minHeight: 4,
            backgroundColor: Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(_emeraldPrimary),
          ),
        );
      case _AppType.medications:
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            value: 0.50,
            minHeight: 4,
            backgroundColor: Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(_emeraldPrimary),
          ),
        );
      case _AppType.goals:
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            value: 0.84,
            minHeight: 4,
            backgroundColor: Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(_emeraldPrimary),
          ),
        );
      case _AppType.bmi:
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            value: 0.65,
            minHeight: 4,
            backgroundColor: Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(_emeraldPrimary),
          ),
        );
      case _AppType.clinicChat:
        return const _AudioWaveformMini(color: _emeraldPrimary);
      case _AppType.trends:
      case _AppType.insights:
      case _AppType.history:
      case _AppType.symptoms:
      case _AppType.settings:
      default:
        return ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            value: 0.90,
            minHeight: 4,
            backgroundColor: Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(_emeraldPrimary),
          ),
        );
    }
  }

  Widget _buildAppleMiniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
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
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // All 11 apps matching the Grid View in Unified Obsidian & Emerald Palette
  List<_AppModuleItem> _getAppsList() {
    return [
      // 1. Wearable Vitals
      const _AppModuleItem(
        type: _AppType.vitals,
        title: "Wearable Vitals",
        category: "HEALTH MONITORING",
        heroMetric: "78 BPM",
        heroBadge: "Sinus Rhythm",
        description:
            "Continuous live telemetry streaming heart rate, blood pressure, and SpO2 from your Apple Watch directly into the hospital EHR with automated arrhythmia alerts.",
        icon: Icons.watch_outlined,
        statusText: "Connected",
        stat1Label: "HEART RATE",
        stat1Value: "78 BPM (Sinus)",
        stat2Label: "BLOOD PRESSURE",
        stat2Value: "120/80 mmHg",
        route: "/vitals",
        actionLabel: "Open Wearable Vitals",
      ),

      // 2. Vitals History
      const _AppModuleItem(
        type: _AppType.history,
        title: "Vitals History",
        category: "HEALTH MONITORING",
        heroMetric: "142 Logs",
        heroBadge: "Past 30 Days",
        description:
            "Browse longitudinal time-stamped archives of past physiological monitoring sessions, ECG recordings, and clinician review logs across customizable date ranges.",
        icon: Icons.history_rounded,
        statusText: "142 Records",
        stat1Label: "TOTAL SESSIONS",
        stat1Value: "142 Records",
        stat2Label: "DATE RANGE",
        stat2Value: "Past 30 Days",
        route: "/history",
        actionLabel: "View Vitals History",
      ),

      // 3. Health Insights
      const _AppModuleItem(
        type: _AppType.insights,
        title: "Health Insights",
        category: "HEALTH MONITORING",
        heroMetric: "98% Normal",
        heroBadge: "Low Risk Tier",
        description:
            "Evaluates merged wearable telemetry and hospital records with clinical reasoning algorithms to highlight early cardiovascular risks and vital anomalies.",
        icon: Icons.insights_rounded,
        statusText: "Optimal",
        stat1Label: "RISK PROFILE",
        stat1Value: "Low / Normal",
        stat2Label: "CRITICAL ALERTS",
        stat2Value: "0 Flags",
        route: "/insights",
        actionLabel: "Explore Health Insights",
      ),

      // 4. Trend Analysis
      const _AppModuleItem(
        type: _AppType.trends,
        title: "Trend Analysis",
        category: "HEALTH MONITORING",
        heroMetric: "±4% Variance",
        heroBadge: "Stable Baseline",
        description:
            "Charts multi-day blood pressure and resting heart rate trajectories benchmarked against Hypertension Canada and AHA medical guidelines.",
        icon: Icons.trending_up_rounded,
        statusText: "Stable",
        stat1Label: "7-DAY TARGET",
        stat1Value: "Within Range",
        stat2Label: "VARIANCE",
        stat2Value: "±4% Normal",
        route: "/trends",
        actionLabel: "Analyze Health Trends",
      ),

      // 5. Medications & Rx
      const _AppModuleItem(
        type: _AppType.medications,
        title: "Medications & Rx",
        category: "HEALTH MANAGEMENT",
        heroMetric: "1 of 2 Taken",
        heroBadge: "Next: 8:00 PM",
        description:
            "Maintains your active prescription regimen with automated dose reminders, taken-dose tracking, and electronic refills with your hospital pharmacy.",
        icon: Icons.medication_outlined,
        statusText: "2 Active",
        stat1Label: "MORNING DOSE",
        stat1Value: "Taken 8:00 AM",
        stat2Label: "EVENING DOSE",
        stat2Value: "Due 8:00 PM",
        route: "/medications",
        actionLabel: "Manage Medications",
      ),

      // 6. Symptom Logger
      const _AppModuleItem(
        type: _AppType.symptoms,
        title: "Symptom Logger",
        category: "HEALTH MANAGEMENT",
        heroMetric: "Mild (1/10)",
        heroBadge: "SOCRATES Intake",
        description:
            "Quickly record pain location, onset, severity, and triggers using the standardized SOCRATES clinical method to send direct updates to your physician.",
        icon: Icons.sick_outlined,
        statusText: "Ready",
        stat1Label: "LAST LOG",
        stat1Value: "Yesterday",
        stat2Label: "SEVERITY",
        stat2Value: "Mild (1/10)",
        route: "/symptoms",
        actionLabel: "Log New Symptom",
      ),

      // 7. Health Goals
      const _AppModuleItem(
        type: _AppType.goals,
        title: "Health Goals",
        category: "HEALTH MANAGEMENT",
        heroMetric: "8,420 Steps",
        heroBadge: "84% of Goal",
        description:
            "Track daily step counts, active calorie burn, and restorative sleep milestones to keep your lifestyle goals aligned with your medical treatment plan.",
        icon: Icons.flag_outlined,
        statusText: "84% Done",
        stat1Label: "STEP TARGET",
        stat1Value: "8,420 / 10,000",
        stat2Label: "ACTIVE BURN",
        stat2Value: "480 kcal",
        route: "/goals",
        actionLabel: "Track Health Goals",
      ),

      // 8. BMI Calculator
      const _AppModuleItem(
        type: _AppType.bmi,
        title: "BMI Calculator",
        category: "HEALTH MANAGEMENT",
        heroMetric: "22.4 BMI",
        heroBadge: "Healthy Weight",
        description:
            "Calculates body mass index from height and weight, categorizing metabolic tiers and delivering tailored dietary recommendations for cardiovascular health.",
        icon: Icons.monitor_weight_outlined,
        statusText: "Healthy",
        stat1Label: "CURRENT BMI",
        stat1Value: "22.4 (Normal)",
        stat2Label: "METABOLIC TIER",
        stat2Value: "Optimal Range",
        route: "/bmi",
        actionLabel: "Calculate BMI",
      ),

      // 9. Urgent Care Clinic
      const _AppModuleItem(
        type: _AppType.urgentCare,
        title: "Urgent Care Clinic",
        category: "CLINICAL & URGENT",
        heroMetric: "#4 in Queue",
        heroBadge: "Est. 12m Wait",
        description:
            "Check into the hospital urgent care queue before arrival, monitor live wait times, and send real-time condition updates directly to the triage nurse.",
        icon: Icons.local_hospital_outlined,
        statusText: "Open Now",
        stat1Label: "QUEUE POSITION",
        stat1Value: "#4 in Line",
        stat2Label: "EST. WAIT",
        stat2Value: "12 Minutes",
        route: "/urgent-care",
        actionLabel: "View Clinic Queue",
      ),

      // 10. AI Health Assistant
      const _AppModuleItem(
        type: _AppType.clinicChat,
        title: "AI Health Assistant",
        category: "CLINICAL & URGENT",
        heroMetric: "CTAS Triage",
        heroBadge: "Care Team Online",
        description:
            "Consult with Intelligent Digital Solution care team via WhatsApp-style messaging and Whisper-1 voice dictation, backed by Canadian CTAS triage protocols.",
        icon: Icons.smart_toy_outlined,
        statusText: "Online",
        stat1Label: "CARE TEAM",
        stat1Value: "IDS Clinic Online",
        stat2Label: "TRIAGE ENGINE",
        stat2Value: "CTAS Level 1-5",
        route: "/assistant",
        actionLabel: "Start Clinical Chat",
      ),

      // 11. Settings & Telemetry
      const _AppModuleItem(
        type: _AppType.settings,
        title: "Settings & Telemetry",
        category: "SYSTEM & TELEMETRY",
        heroMetric: "AWS Synced",
        heroBadge: "App Runner Live",
        description:
            "Configure Apple Watch HealthKit background syncing, verify AWS App Runner connectivity, manage AI provider keys, and update profile credentials.",
        icon: Icons.settings_outlined,
        statusText: "Connected",
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
  final String heroMetric;
  final String heroBadge;
  final String description;
  final IconData icon;
  final String statusText;
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
    required this.heroMetric,
    required this.heroBadge,
    required this.description,
    required this.icon,
    required this.statusText,
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
      height: 20,
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

// Mini Audio Waveform Visualizer for Clinical AI Dictation
class _AudioWaveformMini extends StatelessWidget {
  final Color color;

  const _AudioWaveformMini({required this.color});

  @override
  Widget build(BuildContext context) {
    final heights = [6.0, 14.0, 18.0, 10.0, 16.0, 20.0, 12.0, 8.0, 16.0, 14.0, 8.0];

    return SizedBox(
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: heights.map((h) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }).toList(),
      ),
    );
  }
}
