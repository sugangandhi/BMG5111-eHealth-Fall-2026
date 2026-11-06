import 'package:flutter/material.dart';

class LoginStyles {
  static const headerPadding = EdgeInsets.fromLTRB(28, 36, 28, 8);
  static const formPadding = EdgeInsets.fromLTRB(24, 8, 24, 28);
  static const heroIconSize = 64.0;

  static const emeraldPrimary = Color(0xFF10B981);
  static const emeraldSecondary = Color(0xFF059669);

  static BoxDecoration get cardGlassDecoration => BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: emeraldPrimary.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: emeraldPrimary.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(
            color: Color(0x60000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get inputFieldDecoration => BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1.2,
        ),
      );

  // Backward compatibility alias
  static BoxDecoration get emailFieldDecoration => inputFieldDecoration;

  static BoxDecoration get errorDecoration => BoxDecoration(
        color: const Color(0xFF450A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      );
}
