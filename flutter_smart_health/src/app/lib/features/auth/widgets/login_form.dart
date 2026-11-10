import 'package:flutter/material.dart';
import '../../../config/api_config.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/ui.dart';
import '../presentation/login_styles.dart';

class LoginForm extends StatefulWidget {
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
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  void _showServerConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiConfig.backendBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Backend Server URL', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the backend address (e.g. http://192.168.2.33:8080). Make sure your iPhone is connected to the same Wi-Fi as your Mac.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'http://192.168.2.33:8080',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              autocorrect: false,
              enableSuggestions: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiConfig.saveBackendBaseUrl(null);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('Reset Default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await ApiConfig.saveBackendBaseUrl(newUrl);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNetworkError = widget.error != null &&
        (widget.error!.contains('Unable to reach backend') ||
            widget.error!.contains('SocketException') ||
            widget.error!.contains('unreachable'));

    return Expanded(
      child: SingleChildScrollView(
        padding: LoginStyles.formPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.signInTitle, style: AppTypography.screenTitle),
            const SizedBox(height: 6),
            Text(l10n.signInSubtitle, style: AppTypography.bodyMuted),
            const SizedBox(height: 28),
            Container(
              decoration: LoginStyles.emailFieldDecoration,
              child: TextField(
                key: const Key('login_email_field'),
                controller: widget.emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: l10n.emailAddressHint,
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.radius(AppRadii.lg),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: LoginStyles.emailFieldDecoration,
              child: TextField(
                key: const Key('login_password_field'),
                controller: widget.passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => widget.loading ? null : widget.onSubmit(),
                decoration: InputDecoration(
                  hintText: l10n.passwordHint,
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.radius(AppRadii.lg),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: LoginStyles.emailFieldDecoration,
              child: DropdownButtonFormField<String>(
                key: const Key('login_identity_dropdown'),
                initialValue: widget.selectedIdentity,
                items: [
                  for (final identity in widget.identityOptions)
                    DropdownMenuItem(value: identity, child: Text(identity)),
                ],
                onChanged: widget.loading
                    ? null
                    : (value) {
                        if (value != null) widget.onIdentityChanged(value);
                      },
                decoration: InputDecoration(
                  hintText: l10n.roleLabel,
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.radius(AppRadii.lg),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: LoginStyles.errorDecoration,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                          if (isNetworkError) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _showServerConfigDialog(context),
                              child: const Text(
                                "💡 Tap here to verify or change the Server URL.",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: widget.loading ? null : widget.onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.radius(AppRadii.lg),
                  ),
                  elevation: 0,
                ),
                child: widget.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.signInButton, style: AppTypography.button),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                widget.emailController.text = "normal@demo.com";
                widget.passwordController.text = "123456";
                widget.onIdentityChanged("Patient");
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.key_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Demo Patient: normal@demo.com / 123456 (Tap to fill)",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showServerConfigDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings_ethernet, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Server: ${ApiConfig.backendBaseUrl}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
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
