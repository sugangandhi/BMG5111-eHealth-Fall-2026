import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_health_app/features/auth/auth.dart';
import 'package:smart_health_app/features/health_assistant/health_assistant.dart';

void main() {
  testWidgets('WhatsApp Login screen registers phone number as user ID and opens chats',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const LoginScreen(),
          '/chats': (_) => const HealthAssistantScreen(),
        },
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MaxAssist'), findsOneWidget);
    expect(find.text('Sign in with WhatsApp'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('whatsapp_name_field')), 'Dr. Sugan');
    await tester.enterText(find.byKey(const Key('whatsapp_phone_field')), '+1 613-404-5586');
    await tester.ensureVisible(find.byKey(const Key('whatsapp_login_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('whatsapp_login_button')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_id'), '16134045586');
    expect(prefs.getString('doctor_whatsapp_phone_v1'), '16134045586');
    expect(prefs.getBool('whatsapp_logged_in_v1'), isTrue);
  });
}
