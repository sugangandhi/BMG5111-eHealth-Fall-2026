import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/l10n.dart';
import '../../../ui/app_colors.dart';
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
  bool _obscurePassword = true;

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
          TextField(
            key: const Key('login_email_field'),
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            cursorColor: AppColors.primary,
            cursorWidth: 2.0,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
            decoration: LoginStyles.inputDecoration(
              hintText: l10n.emailAddressHint,
              prefixIcon: const Icon(
                Icons.mail_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password Input with Visibility Toggle
          TextField(
            key: const Key('login_password_field'),
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onSubmit(),
            cursorColor: AppColors.primary,
            cursorWidth: 2.0,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              fontWeight: FontWeight.w500,
            ),
            decoration: LoginStyles.inputDecoration(
              hintText: l10n.passwordHint,
              prefixIcon: const Icon(
                Icons.lock_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                tooltip: _obscurePassword ? "Show password" : "Hide password",
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Identity Dropdown Selector
          DropdownButtonFormField<String>(
            key: const Key('login_identity_dropdown'),
            initialValue: widget.selectedIdentity,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(
              Icons.unfold_more_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
            items: [
              for (final identity in widget.identityOptions)
                DropdownMenuItem(
                  value: identity,
                  child: Text(
                    identity,
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                ),
            ],
            onChanged: widget.loading
                ? null
                : (value) {
                    if (value != null) widget.onIdentityChanged(value);
                  },
            decoration: LoginStyles.inputDecoration(
              hintText: l10n.roleLabel,
              prefixIcon: const Icon(
                Icons.badge_rounded,
                color: AppColors.primaryAccent,
                size: 20,
              ),
            ),
          ),

          // Error Banner if present
          if (widget.error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: LoginStyles.errorDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.coralDark,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: const TextStyle(
                            color: AppColors.coralDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _showServerHostDialog(context),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_ethernet_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Tap to Change Server URL / Host",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Primary Sign In Pill Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.loading ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // Quick Demo Account Pill
          InkWell(
            onTap: () {
              widget.emailController.text = "normal@demo.com";
              widget.passwordController.text = "123456";
              widget.onIdentityChanged("Patient");
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tealSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: AppColors.tealDark,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Demo Patient: normal@demo.com / 123456 (Tap to fill)",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Server Host Link
          Center(
            child: GestureDetector(
              onTap: () => _showServerHostDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        "Server: ${ApiConfig.backendBaseUrl.replaceAll('http://', '').replaceAll('https://', '')}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit_rounded,
                      size: 11,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showServerHostDialog(BuildContext context) {
    final controller = TextEditingController(
      text: ApiConfig.backendBaseUrl,
    );
    bool checking = false;
    String? pingStatus;
    bool pingSuccess = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> testConnection() async {
            final normalized = ApiConfig.normalizeBaseUrl(controller.text);
            if (normalized.isEmpty) return;
            setDialogState(() {
              checking = true;
              pingStatus = null;
            });
            try {
              final client = ApiClient(baseUrl: normalized);
              await client
                  .getJson('/urgent-care/health')
                  .timeout(const Duration(seconds: 6));
              if (!ctx.mounted) return;
              setDialogState(() {
                checking = false;
                pingSuccess = true;
                pingStatus = 'Connected to $normalized';
              });
            } catch (e) {
              if (!ctx.mounted) return;
              setDialogState(() {
                checking = false;
                pingSuccess = false;
                pingStatus = 'Unreachable: $e';
              });
            }
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AppColors.border),
            ),
            title: const Text(
              "Backend Server Host",
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter your Render HTTPS URL or local host:",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: LoginStyles.softSurface,
                      hintText: 'https://bmg5111-ehealth-fall-2026-1.onrender.com',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: LoginStyles.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: checking ? null : testConnection,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: checking
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : const Icon(Icons.network_check_rounded, size: 16),
                        label: Text(
                          checking ? 'Checking...' : 'Test Connection',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (pingStatus != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      pingStatus!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pingSuccess
                            ? AppColors.tealDark
                            : AppColors.coralDark,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    "Quick Presets:",
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _presetButton(
                        "Render HTTPS",
                        "https://bmg5111-ehealth-fall-2026-1.onrender.com",
                        controller,
                      ),
                      _presetButton(
                        "LAN Wi-Fi",
                        "http://192.168.2.29:8080",
                        controller,
                      ),
                      _presetButton(
                        "USB Cable (adb reverse)",
                        "http://127.0.0.1:8080",
                        controller,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () async {
                  final newHost = controller.text.trim();
                  if (newHost.isNotEmpty) {
                    ApiConfig.setBackendHost(newHost);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('custom_backend_host', newHost);
                    if (mounted) setState(() {});
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text(
                  "Save",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _presetButton(
    String label,
    String value,
    TextEditingController controller,
  ) {
    return InkWell(
      onTap: () {
        controller.text = value;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
