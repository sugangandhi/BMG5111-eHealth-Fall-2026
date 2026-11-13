import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n.dart';
import '../../../services/e_hospital_auth_service.dart';
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
  final VoidCallback? onDemoLogin;

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
    this.onDemoLogin,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _obscurePassword = true;
  bool _useWhatsAppAuth = true; // WhatsApp OTP is default
  bool _otpSent = false;
  bool _whatsappLoading = false;
  String? _whatsappError;
  String? _whatsappSuccessInfo;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendWhatsAppOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final phone = _phoneController.text.trim();
    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.length < 10) {
      setState(() {
        _whatsappError = "Please enter a valid mobile number with country code.";
      });
      return;
    }

    setState(() {
      _whatsappLoading = true;
      _whatsappError = null;
      _whatsappSuccessInfo = null;
    });

    try {
      final res = await EHospitalAuthService.sendWhatsAppOtp(phone);
      if (res['success'] == true) {
        setState(() {
          _otpSent = true;
          _whatsappLoading = false;
          _whatsappSuccessInfo = res['message']?.toString() ?? "Code sent to WhatsApp.";
        });
      } else {
        setState(() {
          _whatsappLoading = false;
          _whatsappError = res['error']?.toString() ?? "Failed to send code via WhatsApp.";
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _whatsappLoading = false;
        _whatsappError = e.message;
      });
    } catch (e) {
      setState(() {
        _whatsappLoading = false;
        _whatsappError = "Error connecting to server. Please check your network.";
      });
    }
  }

  Future<void> _handleVerifyWhatsAppOtp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final phone = _phoneController.text.trim();
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _whatsappError = "Please enter the 6-digit code received on WhatsApp.";
      });
      return;
    }

    setState(() {
      _whatsappLoading = true;
      _whatsappError = null;
    });

    try {
      final result = await EHospitalAuthService.loginWithWhatsAppOtp(
        phone,
        code,
        selectedOption: widget.selectedIdentity,
      );

      if (!mounted) return;

      if (result.authenticated) {
        Navigator.pushReplacementNamed(context, "/dashboard");
      } else {
        setState(() {
          _whatsappLoading = false;
          _whatsappError = "Invalid verification code. Please check your WhatsApp and try again.";
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _whatsappLoading = false;
        _whatsappError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _whatsappLoading = false;
        _whatsappError = "Verification error: $e";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: LoginStyles.formPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode Selector Toggle (WhatsApp OTP vs Institutional Email)
          Container(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: const Key('login_tab_whatsapp'),
                    onTap: () => setState(() {
                      _useWhatsAppAuth = true;
                      _whatsappError = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _useWhatsAppAuth ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _useWhatsAppAuth
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_android_rounded,
                            size: 16,
                            color: _useWhatsAppAuth
                                ? const Color(0xFF25D366)
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "WhatsApp OTP",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _useWhatsAppAuth
                                    ? AppColors.textDark
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    key: const Key('login_tab_email'),
                    onTap: () => setState(() {
                      _useWhatsAppAuth = false;
                      _whatsappError = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_useWhatsAppAuth ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_useWhatsAppAuth
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 16,
                            color: !_useWhatsAppAuth
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Email / Passcode",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: !_useWhatsAppAuth
                                    ? AppColors.textDark
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── WHATSAPP OTP VIEW ────────────────────────────────────────────
          if (_useWhatsAppAuth) ...[
            if (!_otpSent) ...[
              // Phone Input
              TextField(
                key: const Key('login_phone_field'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleSendWhatsAppOtp(),
                cursorColor: const Color(0xFF25D366),
                cursorWidth: 2.0,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w600,
                ),
                decoration: LoginStyles.inputDecoration(
                  hintText: "Enter WhatsApp Mobile (e.g. +1 613-261-6383)",
                  prefixIcon: const Icon(
                    Icons.phone_rounded,
                    color: Color(0xFF25D366),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Identity Dropdown Selector
              DropdownButtonFormField<String>(
                key: const Key('login_identity_dropdown_wa'),
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
                onChanged: _whatsappLoading
                    ? null
                    : (value) {
                        if (value != null) widget.onIdentityChanged(value);
                      },
                decoration: LoginStyles.inputDecoration(
                  hintText: l10n.roleLabel,
                  prefixIcon: const Icon(
                    Icons.badge_rounded,
                    color: Color(0xFF075E54),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Send Code via WhatsApp Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const Key('login_send_otp_button'),
                  onPressed: _whatsappLoading ? null : _handleSendWhatsAppOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _whatsappLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_rounded, size: 18, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                "Send Code via WhatsApp",
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ] else ...[
              // OTP Sent Confirmation Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCF8C6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF25D366).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_chat_read_rounded,
                      color: Color(0xFF075E54),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Code dispatched to ${_phoneController.text} on WhatsApp",
                            style: const TextStyle(
                              color: Color(0xFF075E54),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Valid for 10 minutes. Please enter the 6-digit code received on WhatsApp.",
                            style: TextStyle(
                              color: Color(0xFF128C7E),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 6-digit OTP Field
              TextField(
                key: const Key('login_otp_field'),
                controller: _otpController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _handleVerifyWhatsAppOtp(),
                cursorColor: const Color(0xFF075E54),
                cursorWidth: 2.0,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 6.0,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                ),
                decoration: LoginStyles.inputDecoration(
                  hintText: "· · · · · ·",
                  prefixIcon: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFF075E54),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Verify & Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const Key('login_verify_otp_button'),
                  onPressed: _whatsappLoading ? null : _handleVerifyWhatsAppOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF075E54),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _whatsappLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Verify & Enter Portal",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Change phone / resend row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _otpSent = false;
                      _otpController.clear();
                      _whatsappError = null;
                    }),
                    icon: const Icon(Icons.arrow_back_rounded, size: 14),
                    label: const Text(
                      "Change Number",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _whatsappLoading ? null : _handleSendWhatsAppOtp,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text(
                      "Resend Code",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            // ── EMAIL / PASSWORD VIEW ──────────────────────────────────────
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
            const SizedBox(height: 22),

            // Primary Sign In Pill Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('login_email_submit_button'),
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
          ],

          // Error Banner if present
          if ((_useWhatsAppAuth ? _whatsappError : widget.error) != null) ...[
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
                          (_useWhatsAppAuth ? _whatsappError : widget.error)!,
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

          const SizedBox(height: 16),

          // Divider
          const Row(
            children: [
              Expanded(child: Divider(color: AppColors.border, height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "or continue with",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.border, height: 1)),
            ],
          ),

          const SizedBox(height: 14),

          // Google Sign-In Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              key: const Key('login_google_button'),
              onPressed: widget.loading
                  ? null
                  : () => _showGoogleSignInNotice(context),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textDark,
                side: const BorderSide(color: LoginStyles.inputBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(painter: _GoogleLogoPainter()),
                  ),
                  SizedBox(width: 10),
                  Text(
                    "Continue with Google",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // One-Tap Quick Demo Patient Login Button (only in Email/Passcode view)
          if (!_useWhatsAppAuth && widget.onDemoLogin != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('login_demo_button'),
                onPressed: widget.loading ? null : _triggerDemoLogin,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.tealSoft,
                  foregroundColor: AppColors.tealDark,
                  side: BorderSide(
                    color: AppColors.primaryAccent.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(
                  Icons.bolt_rounded,
                  size: 19,
                  color: AppColors.tealDark,
                ),
                label: const Text(
                  "Quick Demo Login (normal@demo.com)",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

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

  void _triggerDemoLogin() {
    widget.emailController.text = "normal@demo.com";
    widget.passwordController.text = "123456";
    widget.onIdentityChanged("Patient");
    if (widget.onDemoLogin != null) {
      widget.onDemoLogin!();
    } else {
      widget.onSubmit();
    }
  }

  void _showGoogleSignInNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Continue with Google",
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          "Google OAuth needs a configured OAuth Client ID for this app build. Use Quick Demo Login to access the live demo patient workspace right now.",
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "Use Email",
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _triggerDemoLogin();
            },
            icon: const Icon(Icons.bolt_rounded, size: 17),
            label: const Text("Demo Patient Login"),
          ),
        ],
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42;
    final strokeW = radius * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Red top arc
    canvas.drawArc(rect, -2.55, 1.95, false, arcPaint(const Color(0xFFEA4335)));
    // Yellow bottom-left arc
    canvas.drawArc(rect, 2.55, 1.18, false, arcPaint(const Color(0xFFFBBC05)));
    // Green bottom arc
    canvas.drawArc(rect, 0.55, 2.0, false, arcPaint(const Color(0xFF34A853)));
    // Blue right-lower arc + horizontal G crossbar
    canvas.drawArc(rect, -0.15, 0.78, false, arcPaint(const Color(0xFF4285F4)));
    canvas.drawLine(
      Offset(center.dx, center.dy + strokeW * 0.05),
      Offset(center.dx + radius + strokeW * 0.35, center.dy + strokeW * 0.05),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = strokeW * 0.85
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
