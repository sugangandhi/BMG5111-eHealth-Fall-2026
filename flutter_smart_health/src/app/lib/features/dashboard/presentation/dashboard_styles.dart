import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

class DashboardStyles {
  static const bodyPadding = EdgeInsets.fromLTRB(20, 24, 20, 32);
  static const cardPadding = EdgeInsets.symmetric(vertical: 24, horizontal: 16);
  static const featuredPadding = EdgeInsets.symmetric(vertical: 22, horizontal: 24);
  static const settingsPadding = EdgeInsets.symmetric(vertical: 14, horizontal: 18);

  static BoxDecoration get gridCardDecoration => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.primarySoft,
      );

  static BoxDecoration get iconBadgeDecoration => const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      );

  static BoxDecoration get featuredCardDecoration => BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F5C9C),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration get featuredIconDecoration => const BoxDecoration(
        color: Color(0x26FFFFFF),
        shape: BoxShape.circle,
      );

  static BoxDecoration get settingsLinkDecoration => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.primarySoft,
      );

  static const welcomeTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
  );

  static const gridTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  static const gridSubtitle = TextStyle(fontSize: 11, color: AppColors.textMuted);

  static const featuredTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const featuredSubtitle = TextStyle(fontSize: 12, color: Color(0xCCFFFFFF));

  static const settingsText = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
}
