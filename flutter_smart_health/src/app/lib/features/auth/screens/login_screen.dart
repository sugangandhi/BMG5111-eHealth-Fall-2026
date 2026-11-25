import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../config/api_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_update_dialog.dart';
import '../../../core/widgets/dual_wave_horizon_background.dart';
import '../../../data/models/ehospital_models.dart';
import '../../../l10n/l10n.dart';
import '../../../services/app_update_service.dart';
import '../../../services/e_hospital_auth_service.dart';
import '../../../ui/app_colors.dart';
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
  final _doctorNameController = TextEditingController();
  String _selectedIdentity = 'Patient';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final savedHost = prefs.getString('custom_backend_host');
      if (savedHost != null && savedHost.isNotEmpty) {
        ApiConfig.setBackendHost(savedHost);
      }
      final savedDocName = prefs.getString('doctor_custom_name_v1');
      if (savedDocName != null && savedDocName.isNotEmpty && mounted) {
        _doctorNameController.text = savedDocName;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPrivacyConsent();
      if (mounted) await _checkMedicalDisclaimer();
      if (mounted) _checkAlreadyLoggedIn();
      if (mounted) _checkAppUpdate();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _doctorNameController.dispose();
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
        iconColor: AppColors.primaryAccent,
        iconBackground: AppColors.tealSoft,
        title: ctx.l10n.privacyNoticeTitle,
        body: ctx.l10n.privacyNoticeBody,
        actionLabel: ctx.l10n.privacyAgreeButton,
        actionColor: AppColors.primaryAccent,
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
        iconColor: AppColors.amberDark,
        iconBackground: AppColors.amberSoft,
        title: ctx.l10n.medicalDisclaimerTitle,
        body: ctx.l10n.medicalDisclaimerBody,
        actionLabel: ctx.l10n.medicalDisclaimerConfirmButton,
        actionColor: AppColors.amber,
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

  Future<void> _checkAppUpdate() async {
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest || kIsWeb) return;
    try {
      final updateService = AppUpdateService();
      if (!updateService.isAndroidNative) return;
      final check = await updateService.checkForUpdate();
      if (check.isUpdateAvailable && mounted) {
        await showAppUpdateDialog(
          context,
          updateService: updateService,
          checkResult: check,
        );
      }
    } catch (_) {}
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

    if (email.contains("doctor") || email.contains("sugan")) {
      _selectedIdentity = "Doctor";
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
      if (_selectedIdentity == 'Doctor') {
        final rawDoc = _doctorNameController.text.trim();
        if (rawDoc.isNotEmpty) {
          final normalized = (rawDoc.startsWith('Dr.') || rawDoc.startsWith('Dr '))
              ? rawDoc
              : 'Dr. $rawDoc';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('doctor_custom_name_v1', normalized);
          await prefs.setString('patient_username', normalized);
        }
      }
      if (!mounted) return;
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

  Future<void> _handleDemoLogin([String? role]) async {
    final targetRole = role ?? _selectedIdentity;
    if (targetRole == 'Doctor') {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (!isTest && mounted) {
        final tempCtrl = TextEditingController(text: _doctorNameController.text.trim());
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text(
              "Doctor Login",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter your name so MaxAssist signs messages and schedules tasks under your name:",
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tempCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Doctor Name",
                    hintText: "e.g. Dr. Abbas",
                    prefixIcon: const Icon(Icons.medical_services_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Continue"),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        if (tempCtrl.text.trim().isNotEmpty) {
          _doctorNameController.text = tempCtrl.text.trim();
        }
      }
      _emailController.text = "doctor@demo.com";
      _passwordController.text = "123456";
      setState(() => _selectedIdentity = "Doctor");
    } else {
      _emailController.text = "normal@demo.com";
      _passwordController.text = "123456";
      setState(() => _selectedIdentity = "Patient");
    }
    await _handleLogin();
  }

  @override
  Widget build(BuildContext context) {
    return DualWaveHorizonBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: LoginStyles.cardDecoration,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const LoginHeader(),
                          LoginForm(
                            emailController: _emailController,
                            passwordController: _passwordController,
                            doctorNameController: _doctorNameController,
                            selectedIdentity: _selectedIdentity,
                            identityOptions:
                                EHospitalAuthService.supportedIdentities,
                            onIdentityChanged: (value) =>
                                setState(() => _selectedIdentity = value),
                            error: _error,
                            loading: _loading,
                            onSubmit: _handleLogin,
                            onDemoLogin: _handleDemoLogin,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Protected clinical health workspace",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
