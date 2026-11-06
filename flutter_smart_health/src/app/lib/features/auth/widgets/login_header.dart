import 'package:flutter/material.dart';
import '../presentation/login_styles.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: LoginStyles.headerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Apple OS Glossy Bluish Squircle Badge with luminous glow
          Container(
            width: LoginStyles.heroIconSize,
            height: LoginStyles.heroIconSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF00C7BE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF00C7BE).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "INTELLIGENT DIGITAL SOLUTION",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF38BDF8),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "eHospital Portal",
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Secure Clinical & Telemetry Care",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF93C5FD),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
