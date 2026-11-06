import 'package:flutter/material.dart';

class LoginStyles {
  static const headerPadding = EdgeInsets.fromLTRB(28, 36, 28, 8);
  static const formPadding = EdgeInsets.fromLTRB(24, 8, 24, 28);
  static const heroIconSize = 64.0;

  static BoxDecoration get cardGlassDecoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get inputFieldDecoration => BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E5EA),
          width: 1.2,
        ),
      );

  // Backward compatibility alias
  static BoxDecoration get emailFieldDecoration => inputFieldDecoration;

  static BoxDecoration get errorDecoration => BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCCC7)),
      );
}
