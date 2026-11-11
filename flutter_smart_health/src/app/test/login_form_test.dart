import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/core/widgets/atmospheric_sky_background.dart';
import 'package:smart_health_app/features/auth/screens/login_screen.dart';
import 'package:smart_health_app/features/auth/widgets/login_form.dart';
import 'package:smart_health_app/l10n/generated/app_localizations.dart';
import 'package:smart_health_app/ui/app_colors.dart';

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
    expect(scaffold.backgroundColor, AppColors.bg);
    expect(find.byType(AtmosphericSkyBackground), findsNothing);
    expect(find.text('INTELLIGENT DIGITAL SOLUTION'), findsNothing);
    expect(find.text('Welcome to eHospital'), findsOneWidget);
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
