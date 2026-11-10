import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../l10n/l10n.dart';
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

  static const _appleBlue = Color(0xFF007AFF);
  static const _appleCyan = Color(0xFF38BDF8);
  static const _appleAzureSoft = Color(0xFF93C5FD);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: LoginStyles.formPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email Address Input (Apple OS Frosted Glass Pill)
          TextField(
            key: const Key('login_email_field'),
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            cursorColor: _appleCyan,
            cursorWidth: 2.0,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: LoginStyles.inputDecoration(
              hintText: l10n.emailAddressHint,
              prefixIcon: const Icon(
                Icons.mail_rounded,
                color: _appleCyan,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password Input with Visibility Toggle (Apple OS Frosted Glass Pill)
          TextField(
            key: const Key('login_password_field'),
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => widget.onSubmit(),
            cursorColor: _appleCyan,
            cursorWidth: 2.0,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            decoration: LoginStyles.inputDecoration(
              hintText: l10n.passwordHint,
              prefixIcon: const Icon(
                Icons.lock_rounded,
                color: _appleCyan,
                size: 20,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _appleAzureSoft,
                  size: 20,
                ),
                tooltip: _obscurePassword ? "Show password" : "Hide password",
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Identity Dropdown Selector (Apple OS Frosted Glass Pill)
          DropdownButtonFormField<String>(
            key: const Key('login_identity_dropdown'),
            initialValue: widget.selectedIdentity,
            dropdownColor: const Color(0xFF162238),
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(
              Icons.unfold_more_rounded,
              color: _appleAzureSoft,
              size: 20,
            ),
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            items: [
              for (final identity in widget.identityOptions)
                DropdownMenuItem(
                  value: identity,
                  child: Text(
                    identity,
                    style: const TextStyle(color: Colors.white),
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
                color: _appleCyan,
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
                        color: Color(0xFFEF4444),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.error!,
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
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
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_ethernet_rounded,
                            size: 14,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "Tap to Change Server URL / Host",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF38BDF8),
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

          // Apple OS Glossy Bluish Action Button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF0284C7)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _appleBlue.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: widget.loading ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
                            letterSpacing: -0.3,
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

          // Quick Demo Account Pill (Tap to fill)
          InkWell(
            onTap: () {
              widget.emailController.text = "normal@demo.com";
              widget.passwordController.text = "123456";
              widget.onIdentityChanged("Patient");
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _appleCyan.withValues(alpha: 0.35),
                  width: 1.1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: _appleCyan,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Demo Patient: normal@demo.com / 123456 (Tap to fill)",
                      style: TextStyle(
                        fontSize: 12,
                        color: _appleCyan,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_rounded,
                      size: 13,
                      color: Color(0xFF93C5FD),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        "Server: ${ApiConfig.backendBaseUrl.replaceAll('http://', '').replaceAll('https://', '')}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit_rounded,
                      size: 11,
                      color: Color(0xFF93C5FD),
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
            backgroundColor: const Color(0xFF0E2856),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
            ),
            title: const Text(
              "Backend Server Host",
              style: TextStyle(
                color: Colors.white,
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
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF071938),
                      hintText: 'https://your-service.onrender.com',
                      hintStyle: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: checking ? null : testConnection,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: BorderSide(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: checking
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF38BDF8),
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: pingSuccess
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Text(
                    "Quick Presets:",
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _presetButton(
                        "Render HTTPS",
                        "https://",
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
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF38BDF8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
