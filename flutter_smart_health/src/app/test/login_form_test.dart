import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/core/widgets/atmospheric_sky_background.dart';
import 'package:smart_health_app/core/widgets/dual_wave_horizon_background.dart';
import 'package:smart_health_app/features/auth/screens/login_screen.dart';
import 'package:smart_health_app/features/auth/widgets/login_form.dart';
import 'package:smart_health_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('login form shows password field and eHospital identities', (
    tester,
  ) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var selectedIdentity = 'Patient';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  LoginForm(
                    emailController: emailController,
                    passwordController: passwordController,
                    selectedIdentity: selectedIdentity,
                    identityOptions: const [
                      'Admin',
                      'Patient',
                      'Doctor',
                      'Clinic',
                      'PharmaAdmin',
                      'Pharma',
                      'ClinicalReasoning',
                    ],
                    onIdentityChanged: (value) =>
                        setState(() => selectedIdentity = value),
                    error: null,
                    loading: false,
                    onSubmit: () {},
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // Default tab is WhatsApp OTP
    expect(find.byKey(const Key('login_phone_field')), findsOneWidget);
    expect(find.byKey(const Key('login_send_otp_button')), findsOneWidget);

    // Switch to Email / Passcode tab
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.text('Patient'), findsOneWidget);

    await tester.tap(find.byKey(const Key('login_identity_dropdown')));
    await tester.pumpAndSettle();

    for (final identity in const [
      'Admin',
      'Patient',
      'Doctor',
      'Clinic',
      'PharmaAdmin',
      'Pharma',
      'ClinicalReasoning',
    ]) {
      expect(find.text(identity), findsWidgets);
    }

    await tester.tap(find.text('Doctor').last);
    await tester.pumpAndSettle();

    expect(selectedIdentity, 'Doctor');
  });

  testWidgets('LoginScreen uses unified eHospital light surface matching dashboard', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'local_ai_privacy_consent': true,
      'medical_disclaimer_seen': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.transparent);
    expect(find.byType(DualWaveHorizonBackground), findsOneWidget);
    expect(find.byType(AtmosphericSkyBackground), findsNothing);
    expect(find.text('INTELLIGENT DIGITAL SOLUTION'), findsNothing);
    expect(find.text('Sign in to eHospital'), findsOneWidget);
    expect(find.byKey(const Key('login_phone_field')), findsOneWidget);

    // Switch to Email tab
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_google_button')), findsOneWidget);
    expect(find.byKey(const Key('login_demo_button')), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Demo Login fills demo credentials and submits immediately', (
    tester,
  ) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var selectedIdentity = 'Doctor';
    var demoSubmitted = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoginForm(
              emailController: emailController,
              passwordController: passwordController,
              selectedIdentity: selectedIdentity,
              identityOptions: const ['Patient', 'Doctor'],
              onIdentityChanged: (value) => selectedIdentity = value,
              error: null,
              loading: false,
              onSubmit: () {},
              onDemoLogin: () => demoSubmitted = true,
            ),
          ),
        ),
      ),
    );

    // Switch to Email tab to access Demo Login button
    await tester.tap(find.byKey(const Key('login_tab_email')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_demo_button')));
    await tester.pumpAndSettle();

    expect(emailController.text, 'normal@demo.com');
    expect(passwordController.text, '123456');
    expect(selectedIdentity, 'Patient');
    expect(demoSubmitted, isTrue);
  });
}
