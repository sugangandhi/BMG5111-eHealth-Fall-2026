import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../ui/app_colors.dart';

/// Identifies the animated health illustration drawn inside each Home module card.
enum DashboardModuleKind {
  vitals,
  history,
  insights,
  trends,
  sleep,
  medications,
  symptoms,
  goals,
  bmi,
  urgentCare,
  clinicChat,
  devices,
}

/// Pastel illustration header with 60fps procedural [CustomPainter] motion
/// driven by a shared periodic [progress] in `[0.0, 1.0)`.
class ModuleIllustrationBanner extends StatelessWidget {
  final DashboardModuleKind kind;
  final double progress;
  final String badgeText;
  final Color accentColor;
  final Color backgroundColor;
  final double height;

  const ModuleIllustrationBanner({
    super.key,
    required this.kind,
    required this.progress,
    required this.badgeText,
    required this.accentColor,
    required this.backgroundColor,
    this.height = 148,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _ModuleScenePainter(
                kind: kind,
                progress: progress,
                accentColor: accentColor,
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F16202C),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegPose {
  final Offset knee;
  final Offset ankle;
  final double footPitch;

  const _LegPose(this.knee, this.ankle, this.footPitch);
}

class _ModuleScenePainter extends CustomPainter {
  final DashboardModuleKind kind;
  final double progress;
  final Color accentColor;

  _ModuleScenePainter({
    required this.kind,
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Integer multiples of 2*pi ensure seamless loop wraparound at progress 1.0 -> 0.0
    switch (kind) {
      case DashboardModuleKind.vitals:
        _paintWalkingWatch(canvas, size);
      case DashboardModuleKind.history:
        _paintHistoryBars(canvas, size);
      case DashboardModuleKind.insights:
        _paintInsightsRings(canvas, size);
      case DashboardModuleKind.trends:
        _paintTrendCurve(canvas, size);
      case DashboardModuleKind.sleep:
        _paintSleepingScene(canvas, size);
      case DashboardModuleKind.medications:
        _paintMedicationCheck(canvas, size);
      case DashboardModuleKind.symptoms:
        _paintSymptomDial(canvas, size);
      case DashboardModuleKind.goals:
        _paintGoalsRings(canvas, size);
      case DashboardModuleKind.bmi:
        _paintBmiGauge(canvas, size);
      case DashboardModuleKind.urgentCare:
        _paintUrgentRadar(canvas, size);
      case DashboardModuleKind.clinicChat:
        _paintAssistantCompanion(canvas, size);
      case DashboardModuleKind.devices:
        _paintDevicesSync(canvas, size);
    }
  }

  /// Biomechanically accurate forward walking cycle glancing at smartwatch.
  void _paintWalkingWatch(Canvas canvas, Size size) {
    canvas.save();
    // Normalize onto a 310x162 logical stage centered cleanly in any banner aspect
    final scale = math.min(size.width / 310.0, size.height / 162.0) * 1.02;
    canvas.translate((size.width - 310.0 * scale) / 2, size.height - 162.0 * scale);
    canvas.scale(scale, scale);

    final walkFreq = progress * 2 * math.pi * 10;
    final glanceWave = 0.5 + 0.5 * math.sin(progress * 2 * math.pi * 3);
    final drift = progress * 2 * math.pi;

    // Distant warm sun & drifting clouds
    canvas.drawCircle(
      const Offset(264, 36),
      13,
      Paint()..color = const Color(0xFFFDE68A).withValues(alpha: 0.7),
    );
    _drawCloud(canvas, Offset(72 + math.sin(drift * 2) * 9, 44), 24, 10);
    _drawCloud(canvas, Offset(250 - math.sin(drift) * 8, 36), 30, 11);

    // Scrolling tree moving LEFT (-x) as person walks RIGHT (+x)
    final treeFrac = (progress * 2) % 1.0;
    final treeX = 335.0 - treeFrac * 380.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(treeX, 108, 5, 24), const Radius.circular(2.5)),
      Paint()..color = const Color(0xFF7B9AB8).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      Offset(treeX + 2.5, 98),
      15,
      Paint()..color = const Color(0xFF97D8CE).withValues(alpha: 0.6),
    );

    // Path surface + scrolling dashes moving LEFT (-x) at stance velocity
    canvas.drawRect(
      const Rect.fromLTWH(-40, 132, 390, 40),
      Paint()..color = const Color(0xFFC2DFF8),
    );
    final dashOffset = (progress * 10 * 96) % 48; // 960 % 48 == 0: seamless wrap
    final dashPaint = Paint()..color = Colors.white.withValues(alpha: 0.78);
    for (int i = -1; i < 8; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * 48.0 - dashOffset, 142, 24, 3.5),
          const Radius.circular(1.75),
        ),
        dashPaint,
      );
    }

    // Hip rises at mid-stance (cos = +-1) and drops at split support (cos = 0)
    final bob = math.cos(walkFreq).abs() * 3.8;
    final hx = 148.0 + math.sin(walkFreq) * 1.2;
    final hy = 90.0 - bob;

    // Dynamic ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(hx, 135),
        width: (22 + (1 - math.cos(walkFreq).abs()) * 4) * 2,
        height: 9,
      ),
      Paint()..color = const Color(0xFF8AB4DB).withValues(alpha: 0.55),
    );

    final sx = hx + 3.0;
    final sy = hy - 35.0;

    // Back / Left arm (swings forward in sync with Right leg stride)
    final bArmA = math.sin(walkFreq) * 0.42 - 0.08;
    final bShoulder = Offset(sx - 3, sy + 4);
    final bElbow = bShoulder + Offset(math.sin(bArmA) * 16, math.cos(bArmA) * 16);
    final bForeA = bArmA + 0.36 + math.max(0.0, math.sin(walkFreq)) * 0.35;
    final bHand = bElbow + Offset(math.sin(bForeA) * 15, math.cos(bForeA) * 15);
    _drawCapsuleLimb(canvas, bShoulder, bElbow, 10, const Color(0xFF0A487D));
    _drawCapsuleLimb(canvas, bElbow, bHand, 8.5, const Color(0xFF0A487D));
    canvas.drawCircle(bHand, 4.5, Paint()..color = const Color(0xFFDC9E7C));

    // Far leg (Left leg, opposite phase walkFreq + pi)
    final farLeg = _computeLeg(Offset(hx - 1, hy), walkFreq + math.pi);
    _drawLeg(canvas, Offset(hx - 1, hy), farLeg, const Color(0xFF1E293B), const Color(0xFF0F9D8A));

    // Torso
    final torsoPath = Path()
      ..moveTo(sx - 9, sy)
      ..cubicTo(sx - 9, sy - 7, sx + 9, sy - 7, sx + 10, sy)
      ..lineTo(hx + 10, hy + 4)
      ..lineTo(hx - 9, hy + 4)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = AppColors.primary);
    canvas.drawLine(
      Offset(sx + 4, sy - 1),
      Offset(hx + 4, hy + 1),
      Paint()
        ..color = AppColors.primaryAccent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Head tilted down looking comfortably at smartwatch
    final headCenter = Offset(sx + 2, sy - 18);
    final headTilt = (12.0 + glanceWave * 9.0) * math.pi / 180.0;
    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(headTilt);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-3.5, 7, 7, 9), const Radius.circular(3.5)),
      Paint()..color = const Color(0xFFE8B192),
    );
    canvas.drawCircle(Offset.zero, 11.5, Paint()..color = const Color(0xFFE8B192));
    final hair = Path()
      ..moveTo(-11, -2)
      ..cubicTo(-11, -12, 0, -15, 9, -10)
      ..cubicTo(13, -7, 13, -2, 10, 0)
      ..cubicTo(5, -5, -4, -6, -11, -2)
      ..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF16202C));
    canvas.drawCircle(const Offset(5.5, 1.5), 1.6, Paint()..color = const Color(0xFF16202C));
    final smile = Path()
      ..moveTo(4, 5.5)
      ..quadraticBezierTo(6.8, 7.5, 9, 5.5);
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF9E5D3D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Near leg (Right leg, phase walkFreq)
    final nearLeg = _computeLeg(Offset(hx + 1, hy), walkFreq);
    _drawLeg(canvas, Offset(hx + 1, hy), nearLeg, const Color(0xFF334155), AppColors.primary);

    // Watch-checking front arm raised clearly into gaze line
    final sh = Offset(sx + 4, sy + 5);
    final elb = Offset(sh.dx + 12, sh.dy + 14 - glanceWave * 2);
    final wrist = Offset(elb.dx + 16, elb.dy - 12 - glanceWave * 5);
    _drawCapsuleLimb(canvas, sh, elb, 10.5, const Color(0xFF1572BF));
    _drawCapsuleLimb(canvas, elb, wrist, 9.0, const Color(0xFF1572BF));
    canvas.drawCircle(wrist + const Offset(4, -2), 4.6, Paint()..color = const Color(0xFFE8B192));

    // Glowing smartwatch angled cleanly toward eyes
    final watchCenter = wrist + const Offset(-2, -4);
    canvas.save();
    canvas.translate(watchCenter.dx, watchCenter.dy);
    canvas.rotate(-32 * math.pi / 180.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -6.5, 10, 13), const Radius.circular(3.5)),
      Paint()..color = AppColors.coral,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-3.7, -4.7, 7.5, 9.5), const Radius.circular(2.2)),
      Paint()..color = Colors.white,
    );
    canvas.restore();
    canvas.drawCircle(watchCenter, 2.2, Paint()..color = AppColors.primaryAccent);

    // Expanding telemetry pulse waves radiating from watch face
    final pingFrac = (progress * 10) % 1.0;
    canvas.drawCircle(
      watchCenter,
      5.0 + pingFrac * 18.0,
      Paint()
        ..color = AppColors.primaryAccent.withValues(alpha: (1.0 - pingFrac).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    canvas.restore();
  }

  _LegPose _computeLeg(Offset hip, double phase) {
    final thighAngle = math.sin(phase) * 0.45 + 0.04;
    // Knee bends strictly while lifting & swinging forward (cos(phase) > 0)
    final swingLift = math.max(0.0, math.cos(phase));
    final kneeFlex = swingLift * 0.92 + 0.08;
    const thighLen = 21.5;
    const shinLen = 21.5;

    final knee = Offset(
      hip.dx + math.sin(thighAngle) * thighLen,
      hip.dy + math.cos(thighAngle) * thighLen,
    );
    final shinAngle = thighAngle - kneeFlex;
    final ankle = Offset(
      knee.dx + math.sin(shinAngle) * shinLen,
      knee.dy + math.cos(shinAngle) * shinLen,
    );
    final footPitch = -math.sin(phase) * 0.24;
    return _LegPose(knee, ankle, footPitch);
  }

  void _drawLeg(Canvas canvas, Offset hip, _LegPose pose, Color pantColor, Color shoeColor) {
    _drawCapsuleLimb(canvas, hip, pose.knee, 11.5, pantColor);
    _drawCapsuleLimb(canvas, pose.knee, pose.ankle, 10.0, pantColor);

    final cos = math.cos(pose.footPitch);
    final sin = math.sin(pose.footPitch);
    final tx = pose.ankle.dx + cos * 14 - sin * 2;
    final ty = pose.ankle.dy + sin * 14 + cos * 2;
    final hx = pose.ankle.dx - cos * 4;
    final hy = pose.ankle.dy - sin * 4 + 3;

    final shoe = Path()
      ..moveTo(hx, hy)
      ..lineTo(pose.ankle.dx + cos * 2, pose.ankle.dy - 4)
      ..lineTo(tx, ty - 1)
      ..quadraticBezierTo(tx + 3, ty + 4, tx - 2, ty + 4.5)
      ..lineTo(hx - 1, hy + 2)
      ..close();
    canvas.drawPath(shoe, Paint()..color = shoeColor);
    canvas.drawLine(
      Offset(hx - 0.5, hy + 2),
      Offset(tx - 1, ty + 4.5),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCapsuleLimb(Canvas canvas, Offset a, Offset b, double width, Color color) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawCloud(Canvas canvas, Offset center, double rx, double ry) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _paintHistoryBars(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi * 4;
    const heights = [0.42, 0.65, 0.52, 0.84, 0.72, 0.92, 0.64, 0.78, 0.56];
    final barW = 14.0;
    final gap = 12.0;
    final startX = (size.width - (heights.length * barW + (heights.length - 1) * gap)) / 2;
    final baseY = size.height * 0.82;
    final maxH = size.height * 0.48;
    final activeIndex = ((progress * 4 * heights.length).floor()) % heights.length;

    for (int i = 0; i < heights.length; i++) {
      final wave = 0.88 + 0.12 * math.sin(t + i * 0.7);
      final h = maxH * heights[i] * wave;
      final x = startX + i * (barW + gap);
      final isHighlighted = i == activeIndex;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, baseY - h, barW, h), const Radius.circular(7)),
        Paint()
          ..color = isHighlighted
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.25 + (i / heights.length) * 0.35),
      );
    }
  }

  void _paintInsightsRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.54);
    final angle = progress * 2 * math.pi * 4;
    canvas.drawCircle(
      center,
      36,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 36),
      angle,
      math.pi * 1.35,
      false,
      Paint()
        ..color = AppColors.primaryAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 22),
      -angle * 1.5,
      math.pi * 1.1,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    final pulseR = 6.0 + 2.0 * math.sin(progress * 2 * math.pi * 6);
    canvas.drawCircle(center, pulseR, Paint()..color = AppColors.primaryAccent);
  }

  void _paintTrendCurve(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi * 4;
    final left = size.width * 0.14;
    final right = size.width * 0.86;
    final midY = size.height * 0.56;

    final path = Path();
    for (int i = 0; i <= 40; i++) {
      final frac = i / 40.0;
      final x = left + (right - left) * frac;
      final y = midY - math.sin(frac * math.pi * 2.5 + t) * 16 - frac * 14;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primaryAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final dotFrac = (progress * 4) % 1.0;
    final dotX = left + (right - left) * dotFrac;
    final dotY = midY - math.sin(dotFrac * math.pi * 2.5 + t) * 16 - dotFrac * 14;
    canvas.drawCircle(Offset(dotX, dotY), 7, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(dotX, dotY), 4.5, Paint()..color = AppColors.primary);
  }

  void _paintSleepingScene(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final breath = 1.0 + math.sin(progress * 2 * math.pi * 3) * 0.06;

    // Crescent moon & twinkling stars
    final starAlpha = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi * 5));
    canvas.drawCircle(Offset(cx - 72, cy - 30), 3, Paint()..color = AppColors.plum.withValues(alpha: starAlpha));
    canvas.drawCircle(Offset(cx + 80, cy - 34), 3.2, Paint()..color = AppColors.plum.withValues(alpha: 1.2 - starAlpha));

    canvas.save();
    final moonRect = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: Offset(cx + 62, cy - 22), radius: 16)),
      Path()..addOval(Rect.fromCircle(center: Offset(cx + 55, cy - 27), radius: 13)),
    );
    canvas.drawPath(moonRect, Paint()..color = AppColors.plum);
    canvas.restore();

    // Bed frame + pillow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 32), width: 170, height: 14), const Radius.circular(7)),
      Paint()..color = const Color(0xFFC4B5FD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 80, cy + 12, 38, 18), const Radius.circular(9)),
      Paint()..color = Colors.white,
    );
    // Resting head
    canvas.drawCircle(Offset(cx - 60, cy + 9), 11, Paint()..color = const Color(0xFFE8B192));
    final hair = Path()
      ..addArc(Rect.fromCircle(center: Offset(cx - 60, cy + 9), radius: 11), math.pi, math.pi * 0.85);
    canvas.drawPath(hair, Paint()..color = const Color(0xFF2A2438));

    // Gently breathing blanket
    canvas.save();
    canvas.translate(cx, cy + 25);
    canvas.scale(1.0, breath);
    final blanket = Path()
      ..moveTo(-48, 0)
      ..lineTo(-48, -16)
      ..cubicTo(-26, -26, 22, -20, 74, 0)
      ..close();
    canvas.drawPath(blanket, Paint()..color = AppColors.plum);
    canvas.restore();

    // Floating Z
    final zFrac = (progress * 3) % 1.0;
    final zAlpha = math.sin(zFrac * math.pi).clamp(0.0, 1.0);
    final zPainter = TextPainter(
      text: TextSpan(
        text: 'Z',
        style: TextStyle(
          color: AppColors.plumDark.withValues(alpha: zAlpha),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    zPainter.paint(canvas, Offset(cx - 42 + zFrac * 16, cy - 8 - zFrac * 24));
  }

  void _paintMedicationCheck(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.56;
    final dropOffset = math.sin(progress * 2 * math.pi * 4) * 7.0;

    // Tray base
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 24), width: 132, height: 22), const Radius.circular(11)),
      Paint()..color = const Color(0xFFFDE1AE),
    );
    // Capsule gently hovering/settling
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx - 10, cy - 4 + dropOffset), width: 46, height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(pillRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - 10, cy - 15 + dropOffset, 23, 22),
        topRight: const Radius.circular(11),
        bottomRight: const Radius.circular(11),
      ),
      Paint()..color = AppColors.amber,
    );
    // Teal confirmation check
    final checkCenter = Offset(cx + 42, cy - 12);
    canvas.drawCircle(checkCenter, 16 + math.sin(progress * 2 * math.pi * 4).abs() * 1.5, Paint()..color = AppColors.primaryAccent);
    final tick = Path()
      ..moveTo(checkCenter.dx - 7, checkCenter.dy)
      ..lineTo(checkCenter.dx - 2, checkCenter.dy + 5)
      ..lineTo(checkCenter.dx + 8, checkCenter.dy - 5);
    canvas.drawPath(
      tick,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintSymptomDial(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.66);
    const r = 44.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    final sweep = (0.35 + 0.3 * math.sin(progress * 2 * math.pi * 3)) * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      math.pi,
      sweep,
      false,
      Paint()
        ..color = AppColors.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    final knobAngle = math.pi + sweep;
    final knobPos = center + Offset(math.cos(knobAngle) * r, math.sin(knobAngle) * r);
    canvas.drawCircle(knobPos, 8, Paint()..color = Colors.white);
    canvas.drawCircle(knobPos, 5, Paint()..color = AppColors.coralDark);
  }

  void _paintGoalsRings(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    final wave = 0.48 + 0.24 * math.sin(progress * 2 * math.pi * 4);

    canvas.drawCircle(
      center,
      44,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 44),
      -math.pi / 2,
      wave * 2 * math.pi,
      false,
      Paint()
        ..color = AppColors.primaryAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      29,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 29),
      -math.pi / 2,
      (wave * 0.72) * 2 * math.pi,
      false,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = AppColors.amber);
  }

  void _paintBmiGauge(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.70);
    const r = 48.0;
    final segments = [
      (math.pi, math.pi * 0.25, AppColors.primary),
      (math.pi * 1.25, math.pi * 0.35, AppColors.primaryAccent),
      (math.pi * 1.60, math.pi * 0.40, AppColors.amber),
    ];
    for (final seg in segments) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        seg.$1,
        seg.$2 - 0.04,
        false,
        Paint()
          ..color = seg.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      );
    }
    final needleAngle = math.pi * 1.42 + math.sin(progress * 2 * math.pi * 3) * 0.22;
    canvas.drawLine(
      center,
      center + Offset(math.cos(needleAngle) * (r - 12), math.sin(needleAngle) * (r - 12)),
      Paint()
        ..color = AppColors.textDark
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = AppColors.textDark);
  }

  void _paintUrgentRadar(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.56);
    for (int i = 0; i < 2; i++) {
      final frac = ((progress * 5) + i * 0.5) % 1.0;
      canvas.drawCircle(
        center,
        18 + frac * 38,
        Paint()
          ..color = AppColors.coral.withValues(alpha: (1.0 - frac).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }
    canvas.drawCircle(center, 24, Paint()..color = AppColors.coral);
    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + const Offset(0, -10), center + const Offset(0, 10), crossPaint);
    canvas.drawLine(center + const Offset(-10, 0), center + const Offset(10, 0), crossPaint);
  }

  void _paintAssistantCompanion(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45 + math.sin(progress * 2 * math.pi * 3) * 3.5;

    // Companion head
    canvas.drawLine(
      Offset(cx, cy - 26),
      Offset(cx, cy - 37),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy - 39), 4.5, Paint()..color = AppColors.primaryAccent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 68, height: 50), const Radius.circular(20)),
      Paint()..color = AppColors.primary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: 46, height: 22), const Radius.circular(11)),
      Paint()..color = AppColors.primarySoft,
    );
    // Natural blink once per cycle chunk
    final blinkWave = math.sin(progress * 2 * math.pi * 2);
    final eyeRy = blinkWave > 0.94 ? 0.6 : 3.8;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 9, cy), width: 7.6, height: eyeRy * 2), Paint()..color = AppColors.primaryAccent);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 9, cy), width: 7.6, height: eyeRy * 2), Paint()..color = AppColors.primaryAccent);

    // Soundwave bars beneath
    for (int i = 0; i < 4; i++) {
      final bh = 10.0 + (0.5 + 0.5 * math.sin(progress * 2 * math.pi * 6 + i * 1.1)) * 12.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 22 + i * 15, cy + 44), width: 6, height: bh), const Radius.circular(3)),
        Paint()..color = i.isEven ? AppColors.primaryAccent : AppColors.primary,
      );
    }
  }

  void _paintDevicesSync(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.56;
    // Watch left
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 46, cy), width: 28, height: 34), const Radius.circular(8)),
      Paint()..color = AppColors.primary,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 46, cy), width: 20, height: 24), const Radius.circular(5)),
      Paint()..color = Colors.white,
    );
    // Phone right
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 46, cy), width: 32, height: 52), const Radius.circular(8)),
      Paint()..color = AppColors.primaryAccent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 46, cy), width: 24, height: 40), const Radius.circular(4)),
      Paint()..color = Colors.white,
    );
    // Moving data packet dots synced left -> right
    for (int i = 0; i < 3; i++) {
      final f = ((progress * 5) + i * 0.33) % 1.0;
      final px = (cx - 22) + f * 44;
      final alpha = math.sin(f * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(px, cy), 4, Paint()..color = AppColors.primary.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _ModuleScenePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.kind != kind ||
        oldDelegate.accentColor != accentColor;
  }
}
