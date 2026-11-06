import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../presentation/login_styles.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final String selectedIdentity;
  final ValueChanged<String> onIdentityChanged;
  final List<String> identityOptions;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.selectedIdentity,
    required this.onIdentityChanged,
    required this.identityOptions,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: LoginStyles.formPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email Address Input
          Container(
            decoration: LoginStyles.emailFieldDecoration,
            child: TextField(
              key: const Key('login_email_field'),
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: l10n.emailAddressHint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.mail_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Password Input
          Container(
            decoration: LoginStyles.emailFieldDecoration,
            child: TextField(
              key: const Key('login_password_field'),
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSubmit(),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: l10n.passwordHint,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.lock_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Identity Dropdown Selector
          Container(
            decoration: LoginStyles.emailFieldDecoration,
            child: DropdownButtonFormField<String>(
              key: const Key('login_identity_dropdown'),
              initialValue: selectedIdentity,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(16),
              icon: const Icon(
                Icons.unfold_more_rounded,
                color: Color(0xFF8E8E93),
                size: 20,
              ),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1C1C1E),
                fontWeight: FontWeight.w600,
              ),
              items: [
                for (final identity in identityOptions)
                  DropdownMenuItem(
                    value: identity,
                    child: Text(identity),
                  ),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null) onIdentityChanged(value);
                    },
              decoration: InputDecoration(
                hintText: l10n.roleLabel,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.badge_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          // Error Banner if present
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: LoginStyles.errorDecoration,
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFFF3B30),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFF3B30),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Apple Primary Action Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                shadowColor: const Color(0x33007AFF),
              ),
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Quick Demo Account Pill (Tap to fill)
          InkWell(
            onTap: () {
              emailController.text = "normal@demo.com";
              passwordController.text = "123456";
              onIdentityChanged("Patient");
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.25),
                  width: 1.1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: Color(0xFF007AFF),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Demo Patient: normal@demo.com / 123456 (Tap to fill)",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF007AFF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
