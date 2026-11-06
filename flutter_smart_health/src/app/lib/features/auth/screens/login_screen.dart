import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/ehospital_models.dart';
import '../../../l10n/l10n.dart';
import '../../../services/e_hospital_auth_service.dart';
import '../presentation/login_styles.dart';
import '../widgets/auth_notice_dialog.dart';
import '../widgets/login_form.dart';
import '../widgets/login_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedIdentity = 'Patient';
  bool _loading = false;
  String? _error;

  static const _emeraldPrimary = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPrivacyConsent();
      if (mounted) await _checkMedicalDisclaimer();
      if (mounted) _checkAlreadyLoggedIn();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkPrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final consented = prefs.getBool('local_ai_privacy_consent') ?? false;
    if (consented || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AuthNoticeDialog(
        icon: Icons.privacy_tip_outlined,
        iconColor: _emeraldPrimary,
        iconBackground: _emeraldPrimary.withValues(alpha: 0.15),
        title: ctx.l10n.privacyNoticeTitle,
        body: ctx.l10n.privacyNoticeBody,
        actionLabel: ctx.l10n.privacyAgreeButton,
        actionColor: _emeraldPrimary,
        onAccepted: () async {
          await prefs.setBool('local_ai_privacy_consent', true);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _checkMedicalDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('medical_disclaimer_seen') ?? false;
    if (seen || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AuthNoticeDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange.shade700,
        iconBackground: Colors.orange.shade50,
        title: ctx.l10n.medicalDisclaimerTitle,
        body: ctx.l10n.medicalDisclaimerBody,
        actionLabel: ctx.l10n.medicalDisclaimerConfirmButton,
        actionColor: Colors.orange.shade700,
        onAccepted: () async {
          await prefs.setBool('medical_disclaimer_seen', true);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _checkAlreadyLoggedIn() async {
    final id = await EHospitalAuthService.getLoggedInPatientId();
    if (id != null && mounted) {
      Navigator.pushReplacementNamed(context, "/dashboard");
    }
  }

  Future<void> _handleLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (email.isEmpty) {
      setState(() => _error = context.l10n.emailRequiredError);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = context.l10n.passwordRequiredError);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    AuthLoginResult result;
    try {
      result = await EHospitalAuthService.loginWithEmail(
        email,
        password,
        selectedOption: _selectedIdentity,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
      return;
    }
    if (!mounted) return;

    if (result.authenticated && result.hasPatientSession) {
      Navigator.pushReplacementNamed(context, "/dashboard");
    } else if (result.authenticated) {
      setState(() {
        _loading = false;
        _error = context.l10n.unsupportedIdentityError;
      });
    } else {
      setState(() {
        _loading = false;
        _error = context.l10n.invalidCredentialsError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1220),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            // Atmospheric Apple OS Glossy Bluish Twilight Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1E2E4A), // Luminous twilight steel blue
                      Color(0xFF16233B), // Deep atmospheric navy
                      Color(0xFF111A2D), // Twilight slate
                      Color(0xFF0C1220), // Deep nocturnal foundation
                    ],
                    stops: [0.0, 0.35, 0.70, 1.0],
                  ),
                ),
              ),
            ),

            // Luminous Apple Sapphire Orb (Top-left)
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF007AFF).withValues(alpha: 0.35),
                      const Color(0xFF0284C7).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // Luminous Apple Cyan / Electric Azure Orb (Top-right)
            Positioned(
              top: 100,
              right: -80,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: 0.28),
                      const Color(0xFF38BDF8).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),

            // Subtle Deep Cobalt Ambient Glow (Bottom-center)
            Positioned(
              bottom: -100,
              left: 40,
              right: 40,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF1D4ED8).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
            ),

            // Center Frosted Glossy Bluish Glass Card
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                        child: Container(
                          decoration: LoginStyles.cardGlassDecoration,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const LoginHeader(),
                              LoginForm(
                                emailController: _emailController,
                                passwordController: _passwordController,
                                selectedIdentity: _selectedIdentity,
                                identityOptions:
                                    EHospitalAuthService.supportedIdentities,
                                onIdentityChanged: (value) =>
                                    setState(() => _selectedIdentity = value),
                                error: _error,
                                loading: _loading,
                                onSubmit: _handleLogin,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
