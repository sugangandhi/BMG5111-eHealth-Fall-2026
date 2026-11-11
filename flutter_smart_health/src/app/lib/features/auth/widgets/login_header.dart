import 'package:flutter/material.dart';
import '../../../ui/app_colors.dart';
import '../../../ui/app_gradients.dart';
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1.0),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: LoginStyles.heroIconSize,
              height: LoginStyles.heroIconSize,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F5C9C),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.monitor_heart_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Sign in to eHospital",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Connected care, wearable vitals & health records",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
