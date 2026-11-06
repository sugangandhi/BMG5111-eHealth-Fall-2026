import 'package:flutter/material.dart';

class LoginStyles {
  static const headerPadding = EdgeInsets.fromLTRB(28, 36, 28, 8);
  static const formPadding = EdgeInsets.fromLTRB(24, 8, 24, 28);
  static const heroIconSize = 64.0;

  // Apple OS Glossy Bluish Palette
  static const appleBluePrimary = Color(0xFF007AFF);
  static const appleBlueSecondary = Color(0xFF0284C7);
  static const appleCyanGlow = Color(0xFF38BDF8);
  static const appleAzureSoft = Color(0xFF93C5FD);

  // Backward compatibility aliases
  static const emeraldPrimary = appleBluePrimary;
  static const emeraldSecondary = appleBlueSecondary;

  static BoxDecoration get cardGlassDecoration => BoxDecoration(
        color: const Color(0xFF141E33).withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x65060C1A),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: appleBluePrimary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get inputFieldDecoration => BoxDecoration(
        color: const Color(0xFF16233B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(0, 2),
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
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF16233B).withValues(alpha: 0.85),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF38BDF8),
          width: 1.6,
        ),
      ),
    );
  }

  // Backward compatibility alias
  static BoxDecoration get emailFieldDecoration => inputFieldDecoration;

  static BoxDecoration get errorDecoration => BoxDecoration(
        color: const Color(0xFF450A0A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.45),
        ),
      );
}
