import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';

class LoginStyles {
  static const headerPadding = EdgeInsets.fromLTRB(26, 30, 26, 10);
  static const formPadding = EdgeInsets.fromLTRB(24, 10, 24, 26);
  static const heroIconSize = 62.0;

  static const primaryAction = AppColors.primary;
  static const secondaryTeal = AppColors.primaryAccent;
  static const softSurface = Color(0xFFF4F7FA);
  static const inputBorder = Color(0xFFCFD9E3);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F5C9C),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      );

  static InputDecoration inputDecoration({
    required String hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: softSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: inputBorder, width: 1.1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: inputBorder, width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  static BoxDecoration get errorDecoration => BoxDecoration(
        color: AppColors.coralSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
      );
}
